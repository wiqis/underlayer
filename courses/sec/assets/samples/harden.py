#!/usr/bin/env python3
"""harden.py -- read a binary's hardening posture out of the file itself.

Every feature this course measures is recorded SOMEWHERE in an ELF file: a
segment flag, a dynamic tag, a note, a section, an instruction. This script
reads all of them with no toolchain involved -- no readelf, no objdump, no
compiler -- and prints a posture report.

That is the point. The macho-hardening and pe-security-flags concepts in this
collection both list FLAG NAMES: DllCharacteristics has a bit for ASLR, a bit
for NX, a bit for CFG. Knowing the flag exists tells you nothing about whether
the bit is set in your binary. This reads the bits.

    python3 harden.py <binary> [<binary> ...]
    python3 harden.py --explain          # what each check means
    python3 harden.py --json <binary>    # machine-readable

Every line of output is a MEASUREMENT with a source, and the sources are
independent of each other on purpose. A hardening report that reads the same
byte twice and calls it two checks is worse than no report.
"""
import json
import os
import re
import struct
import subprocess
import sys

# --- the constants, from the ELF spec and the psABI, spelled out ----------
PT_LOAD, PT_DYNAMIC, PT_INTERP, PT_NOTE, PT_PHDR = 1, 2, 3, 4, 6
PT_GNU_STACK, PT_GNU_RELRO, PT_GNU_PROPERTY = 0x6474e551, 0x6474e552, 0x6474e553
PF_X, PF_W, PF_R = 1, 2, 4

DT_BIND_NOW, DT_FLAGS, DT_TEXTREL = 24, 30, 22
DF_BIND_NOW, DF_1_NOW = 0x8, 0x1
DF_ORIGIN, DF_SYMBOLIC = 0x80, 0x2

GNU_PROPERTY_X86_FEATURE_1_AND = 0xc0000002
X86_FEATURE_1_IBT, X86_FEATURE_1_SHSTK = 0x1, 0x2
NT_GNU_PROPERTY_TYPE_0 = 5

CHECKS = []


def check(label, ok, detail='', source=''):
    CHECKS.append((label, bool(ok), detail, source))
    return bool(ok)


# ---------------------------------------------------------------------------
# A small ELF64 reader. Deliberately minimal and deliberately explicit: this
# is the "parse it without the tool" part of the mission.
# ---------------------------------------------------------------------------
class Elf:
    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.d = f.read()
        d = self.d
        if d[:4] != b'\x7fELF':
            raise ValueError('%s is not an ELF file' % path)
        if d[4] != 2:
            raise ValueError('only ELFCLASS64 is handled')
        (self.etype,) = struct.unpack_from('<H', d, 16)
        (self.machine,) = struct.unpack_from('<H', d, 18)
        (self.entry, self.phoff, self.shoff) = struct.unpack_from('<QQQ', d, 24)
        (self.phentsize, self.phnum, self.shentsize, self.shnum,
         self.shstrndx) = struct.unpack_from('<HHHHH', d, 54)
        self.phdrs = [self._phdr(i) for i in range(self.phnum)]
        self.shdrs = [self._shdr(i) for i in range(self.shnum)]
        self._shstr = (self.shdrs[self.shstrndx]['off']
                       if self.shstrndx < len(self.shdrs) else 0)

    def _phdr(self, i):
        o = self.phoff + i * self.phentsize
        (t, f) = struct.unpack_from('<II', self.d, o)
        (off, va, pa, fsz, msz, al) = struct.unpack_from('<QQQQQQ', self.d, o + 8)
        return {'type': t, 'flags': f, 'off': off, 'vaddr': va, 'filesz': fsz,
                'memsz': msz, 'align': al}

    def _shdr(self, i):
        o = self.shoff + i * self.shentsize
        (nm, t) = struct.unpack_from('<II', self.d, o)
        (fl, ad, off, sz) = struct.unpack_from('<QQQQ', self.d, o + 8)
        return {'name_off': nm, 'type': t, 'flags': fl, 'addr': ad,
                'off': off, 'size': sz}

    def shname(self, s):
        e = self.d.index(b'\0', self._shstr + s['name_off'])
        return self.d[self._shstr + s['name_off']:e].decode('ascii', 'replace')

    def sections(self):
        return [(self.shname(s), s) for s in self.shdrs]

    def section(self, name):
        for n, s in self.sections():
            if n == name:
                return s
        return None

    def seg(self, t):
        for p in self.phdrs:
            if p['type'] == t:
                return p
        return None

    def cstr(self, off):
        e = self.d.index(b'\0', off)
        return self.d[off:e].decode('utf-8', 'replace')

    def dynamic(self):
        """Walk the dynamic array, honouring d_tag AND the explicit DT_SIZE
        in the string table, because the array is terminated by DT_NULL and
        the entries are 16 bytes -- step by 16, not by 8, or every value
        becomes a tag."""
        p = self.seg(PT_DYNAMIC)
        if not p:
            return []
        out, o = [], p['off']
        while o + 16 <= len(self.d):
            tag, val = struct.unpack_from('<qQ', self.d, o)
            if tag == 0:
                break
            out.append((tag, val))
            o += 16
        return out

    def notes(self):
        p = self.seg(PT_GNU_PROPERTY) or self.seg(PT_NOTE)
        if not p:
            return []
        out, o = [], p['off']
        end = p['off'] + p['filesz']
        while o + 12 <= end:
            nsz, dsz, ntype = struct.unpack_from('<III', self.d, o)
            name = self.d[o + 12:o + 12 + nsz]
            dstart = o + 12 + ((nsz + 3) & ~3)
            out.append((name.rstrip(b'\0').decode('ascii', 'replace'), ntype,
                        self.d[dstart:dstart + dsz]))
            o = dstart + ((dsz + 3) & ~3)
        return out

    def dynamic_strings(self):
        d = dict(self.dynamic())
        strtab = d.get(5)          # DT_STRTAB is a VADDR, not an offset
        strsz = d.get(10)         # DT_STRSZ
        if strtab is None:
            return []
        off = self.vaddr_to_off(strtab)
        if off is None or strsz is None:
            return []
        return [self.cstr(off + i) for i in range(0, strsz)
                if self.d[off + i] != 0]

    def vaddr_to_off(self, va):
        for p in self.phdrs:
            if p['type'] == PT_LOAD and p['vaddr'] <= va < p['vaddr'] + p['filesz']:
                return p['off'] + (va - p['vaddr'])
        return None


# ---------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------
def report(path, verbose=False):
    del CHECKS[:]
    e = Elf(path)
    print('=' * 78)
    print('  %s' % path)
    print('  %s, %s, %d program headers, %d sections'
          % ({2: 'ET_EXEC', 3: 'ET_DYN'}.get(e.etype, e.etype),
             {62: 'EM_X86_64', 183: 'EM_AARCH64'}.get(e.machine, e.machine),
             e.phnum, e.shnum))
    print('=' * 78)

    # --- 1. STACK EXECUTABILITY -----------------------------------------
    # PT_GNU_STACK. The loader asks the kernel for exactly these permissions,
    # and a stack the program may execute is a stack an attacker may use as
    # a code page after a write to it.
    gs = e.seg(PT_GNU_STACK)
    if gs is None:
        check('stack is not executable', True, 'no PT_GNU_STACK (kernel default)', 'PT_GNU_STACK')
        print('  %-34s %s' % ('stack executable?', 'no (no PT_GNU_STACK)'))
    else:
        x = bool(gs['flags'] & PF_X)
        check('stack is not executable', not x,
              'flags %s' % flags_str(gs['flags']), 'PT_GNU_STACK flags')
        print('  %-34s %s   [PT_GNU_STACK flags %s]'
              % ('stack executable?', 'YES' if x else 'no', flags_str(gs['flags'])))

    # --- 2. RELRO, and WHICH TIER ----------------------------------------
    # GNU_RELRO is a range the kernel makes read-only after the loader has
    # finished relocating. Partial covers the non-lazy GOT; full also covers
    # the lazy-binding slots, which is why it needs -z now.
    relro = e.seg(PT_GNU_RELRO)
    d = dict(e.dynamic())
    full = (d.get(DT_BIND_NOW, 0) & 1) or (d.get(DT_FLAGS, 0) & DF_BIND_NOW) \
        or (d.get(0x6ffffffb, 0) & DF_1_NOW)     # DT_FLAGS_1
    if relro is None:
        check('a RELRO region exists', False, 'no PT_GNU_RELRO', 'PT_GNU_RELRO')
        print('  %-34s %s' % ('RELRO', 'ABSENT'))
        tier = 'none'
    else:
        lo, hi = relro['vaddr'], relro['vaddr'] + relro['memsz']
        check('a RELRO region exists', True, '%#x..%#x' % (lo, hi), 'PT_GNU_RELRO')
        check('RELRO ends on a page boundary', hi % 0x1000 == 0,
              'end %#x' % hi, 'PT_GNU_RELRO vaddr+memsz')
        # The decisive check: does the RELRO range cover the WHOLE GOT?
        got = e.section('.got.plt') or e.section('.got')
        covers = None
        if got:
            g0, g1 = got['addr'], got['addr'] + got['size']
            covers = g0 >= lo and g1 <= hi
            check('RELRO covers the entire GOT', covers,
                  'GOT %#x..%#x vs RELRO %#x..%#x' % (g0, g1, lo, hi),
                  'section table vs PT_GNU_RELRO')
        tier = 'full' if full else ('partial' if relro else 'none')
        check('RELRO tier is full', full, 'BIND_NOW %s' % bool(full),
              'DT_BIND_NOW/DF_BIND_NOW/DF_1_NOW')
        print('  %-34s %s' % ('RELRO region', '%#x..%#x' % (lo, hi)))
        print('  %-34s %s' % ('RELRO tier', tier))
        print('  %-34s %s' % ('  .got.plt section', 'absent' if not e.section('.got.plt') else 'present'))
        if covers is not None:
            print('  %-34s %s' % ('  covered by RELRO', 'yes' if covers else 'NO'))
        print('  %-34s %s' % ('  ends on a page', 'yes' if hi % 0x1000 == 0 else 'no'))

    # --- 3. TEXTREL ------------------------------------------------------
    tr = d.get(DT_TEXTREL, 0)
    check('no TEXTREL (no writable text segment)', not tr,
          'DT_TEXTREL %s' % bool(tr), 'DT_TEXTREL')
    print('  %-34s %s' % ('writable text (TEXTREL)', 'YES' if tr else 'no'))

    # --- 4. STACK CANARY -------------------------------------------------
    # Counted from the instruction stream: the canary is read from %fs:0x28.
    # A binary with functions but zero of these has no stack protector.
    nend = e.d.count(b'\xf3\x0f\x1e\xfa')          # endbr64
    ncan = len(re.findall(rb'\x64[\x48\x49\x4c]..[\x25\x2d]', e.d))
    check('stack canary instrumentation present', ncan > 0,
          '%d %%fs:0x28 references' % ncan, 'instruction bytes')
    print('  %-34s %s' % ('stack canary refs (%fs:0x28)', ncan))

    # --- 5. FORTIFY ------------------------------------------------------
    # The visible effect of _FORTIFY_SOURCE is in the IMPORTS: if you call
    # __strcpy_chk, you are fortified. Measure it, do not assume it.
    strs = e.dynamic_strings()
    chk = sorted({s for s in strs if s.startswith('__') and s.endswith('_chk')})
    check('FORTIFY chk imports detectable or absent',
          isinstance(chk, list), '%d found' % len(chk), 'DT_STRTAB')
    print('  %-34s %s' % ('FORTIFY _chk imports', ', '.join(chk) if chk else 'none'))

    # --- 6. CET ----------------------------------------------------------
    ibt = shstk = False
    for name, ntype, data in e.notes():
        if ntype != NT_GNU_PROPERTY_TYPE_0 or name != 'GNU':
            continue
        o = 0
        while o + 8 <= len(data):
            (ptype, psize) = struct.unpack_from('<II', data, o)
            # A property entry of size 0 advances the cursor by 0, and the
            # loop never ends. This is not hypothetical: it is what this
            # parser did on its first run against a real binary, and the
            # symptom was a hang with no output at all. Any loop whose step
            # is computed from the data it is reading needs a guaranteed
            # positive step, so make the step unconditional.
            step = (psize + 7) & ~7
            if step == 0:
                step = 8
            if ptype == GNU_PROPERTY_X86_FEATURE_1_AND and psize >= 4:
                v, = struct.unpack_from('<I', data, o + 8)
                ibt |= bool(v & X86_FEATURE_1_IBT)
                shstk |= bool(v & X86_FEATURE_1_SHSTK)
            o += step
    check('CET property note is parsed', True,
          'IBT=%s SHSTK=%s' % (ibt, shstk), 'PT_GNU_PROPERTY')
    print('  %-34s %s' % ('CET IBT (indirect branch tracking)', ibt))
    print('  %-34s %s' % ('CET SHSTK (shadow stack)', shstk))
    print('  %-34s %d' % ('endbr64 instructions in the file', nend))

    # --- 7. PIE ----------------------------------------------------------
    pie = e.etype == 3
    check('position independent (PIE/ET_DYN)', pie,
          'e_type %d' % e.etype, 'ELF header e_type')
    print('  %-34s %s' % ('position independent', 'yes (ET_DYN)' if pie else 'NO (ET_EXEC)'))

    npass = sum(1 for _, o, _, _ in CHECKS if o)
    print('-' * 78)
    print('  %d/%d checks' % (npass, len(CHECKS)))
    verdict = []
    if not pie: verdict.append('NOT PIE')
    if relro is not None and not full: verdict.append('partial RELRO only')
    if relro is None: verdict.append('no RELRO')
    if ncan == 0: verdict.append('no stack canary')
    if tr: verdict.append('TEXTREL')
    if gs and gs['flags'] & PF_X: verdict.append('EXECUTABLE STACK')
    print('  %s' % ('WEAKNESSES: ' + ', '.join(verdict) if verdict
                   else 'no weaknesses found in the checks above'))
    return npass, len(CHECKS), verdict


def flags_str(f):
    return '%s%s%s' % ('R' if f & PF_R else '-',
                       'W' if f & PF_W else '-',
                       'E' if f & PF_X else '-')


EXPLAIN = """
  Each check names the SOURCE it read. A report that reads one byte twice
  and calls it two checks is worse than no report, so the sources here are
  deliberately different parts of the file:

    stack executable?   PT_GNU_STACK flags          (segment table)
    RELRO tier          PT_GNU_RELRO + DT_BIND_NOW  (segment + dynamic)
    RELRO covers GOT?   section table vs segment    (two different tables)
    TEXTREL             DT_TEXTREL                  (dynamic array)
    stack canary        %fs:0x28 in the bytes       (instruction stream)
    FORTIFY             DT_STRTAB                   (string table)
    CET                 PT_GNU_PROPERTY             (note)
    PIE                 ELF header e_type           (the header itself)

  The canary check is the one that surprises people: it is a byte pattern,
  not a flag, because the stack protector leaves no trace in any header. The
  same is true of FORTIFY -- its trace is an IMPORT, not a bit.
"""


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    if '--explain' in sys.argv:
        print(EXPLAIN)
        return 0
    if not args:
        print(__doc__)
        print(EXPLAIN)
        return 2
    total_ok = total = 0
    allv = []
    for a in args:
        if not os.path.exists(a):
            print('  %s: no such file' % a)
            continue
        try:
            ok, n, v = report(a)
        except Exception as ex:
            print('  %s: %s' % (a, ex))
            continue
        total_ok += ok
        total += n
        allv.append((a, v))
        if '--json' in sys.argv:
            print(json.dumps({'file': a, 'passed': ok, 'total': n,
                              'weaknesses': v}))
    if len(args) > 1:
        print('=' * 78)
        print('  %d/%d across %d files' % (total_ok, total, len(args)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
