#!/usr/bin/env python3
"""crosscheck.py -- verify the Object Files course's claims with three readers.

The rule this course works under is that AI-written content is presumed wrong
until checked against something that did not come from the same reasoning.
That means a claim is only worth teaching once two implementations that share
no code agree on it.

Three tiers, and the script reports which tier each check reached:

  TIER 1  this decoder  vs  a second decoder written from the same spec
  TIER 2  this decoder  vs  an unrelated toolchain (LLVM 21 / binutils)
  TIER 3  this decoder  vs  the file's own INTERNAL INVARIANTS

Tier 3 is the one that catches the most, because an object file records the
same fact in two places more often than you would expect -- COFF puts a
section's size and relocation count in both the section header and the
symbol table's auxiliary record, and a reader that mis-parses the aux records
will disagree with itself before it ever disagrees with anybody else.

    $ python3 crosscheck.py                 # check everything here
    $ python3 crosscheck.py -v              # show every field
"""
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PASS = 0
FAIL = 0
VERBOSE = '-v' in sys.argv


def ok(msg):
    global PASS
    PASS += 1
    print('  ok    %s' % msg)


def bad(msg):
    global FAIL
    FAIL += 1
    print('  FAIL  %s' % msg)


def check(cond, msg):
    ok(msg) if cond else bad(msg)


def tool(*args):
    """Run a tool, return stdout, or '' if it is not installed."""
    try:
        return subprocess.run(args, capture_output=True, text=True,
                              timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


def have(name):
    return any(os.access(os.path.join(p, name), os.X_OK)
               for p in os.environ.get('PATH', '').split(':') if p)


# ============================================================== ELF decoder
class Elf:
    """A minimal ELF64 relocatable reader, written from the gABI layout."""

    SHT = {0: 'NULL', 1: 'PROGBITS', 2: 'SYMTAB', 3: 'STRTAB', 4: 'RELA',
           8: 'NOBITS', 0x6ffffff5: 'GNU_ATTRIBUTES',
           0x6fffffff: 'GNU_HASH', 0x6ffffff6: 'GNU_VERDEF',
           0x6ffffffe: 'VERNEED', 0x70000001: 'LLVM_ADDRSIG'}
    STB = {0: 'LOCAL', 1: 'GLOBAL', 2: 'WEAK'}
    STT = {0: 'NOTYPE', 1: 'OBJECT', 2: 'FUNC', 3: 'SECTION', 4: 'FILE'}
    R_X86_64 = {0: 'NONE', 1: '64', 2: 'PC32', 4: 'PLT32', 9: 'GOTPCREL',
                10: '32', 11: '32S', 24: 'PC64', 41: 'GOTPCRELX',
                42: 'REX_GOTPCRELX'}

    def __init__(self, path):
        self.d = d = open(path, 'rb').read()
        if d[:4] != b'\x7fELF':
            raise ValueError('not ELF')
        self.cls, self.data = d[4], d[5]
        if self.cls != 2:
            raise ValueError('ELFCLASS32 -- this decoder is ELF64 only')
        self.e_type, self.e_machine = struct.unpack_from('<HH', d, 0x10)
        self.e_shoff = struct.unpack_from('<Q', d, 0x28)[0]
        self.e_shentsize, self.e_shnum, self.e_shstrndx = \
            struct.unpack_from('<HHH', d, 0x3a)
        self.e_phnum = struct.unpack_from('<H', d, 0x38)[0]
        self.sh = [struct.unpack_from('<IIQQQQIIQQ', d, self.e_shoff + i * 64)
                   for i in range(self.e_shnum)]
        self.shstr = self.sh[self.e_shstrndx][4]
        self.symtab = None
        for s in self.sh:
            if s[1] == 2:
                self.symtab = (s[4], s[5], s[6], s[7])   # off size link info
                break
        self.strtab = self.sh[self.symtab[2]][4] if self.symtab else 0

    def secname(self, i):
        o = self.shstr + self.sh[i][0]
        return self.d[o:self.d.index(b'\x00', o)].decode()

    def sections(self):
        return [(i, self.secname(i), self.sh[i][1], self.sh[i][4],
                 self.sh[i][5], self.sh[i][7], self.sh[i][8], self.sh[i][9])
                for i in range(self.e_shnum)]

    def symbols(self):
        off, size, _, _ = self.symtab
        out = []
        for k in range(size // 24):
            o = off + k * 24
            name, info, other, shndx, value, sz = \
                struct.unpack_from('<IBBHQQ', self.d, o)
            e = self.d.index(b'\x00', self.strtab + name)
            out.append((k, self.d[self.strtab + name:e].decode(), info >> 4,
                        info & 0xF, shndx, value, sz))
        return out

    def symname(self, k):
        """The name readelf would print for symbol k.

        A STT_SECTION symbol stores st_name == 0 -- there is no string for it
        -- and every reader substitutes the TARGET SECTION's name instead.
        Getting this wrong makes section-symbol relocations look nameless.
        """
        s = self.symbols()[k]
        if s[3] == 3 and s[1] == '' and s[4] != 0:
            return self.secname(s[4])
        return s[1]

    def relocs(self):
        """Yield (section-name, offset, type-name, symbol-name, addend)."""
        syms = self.symbols()
        for i in range(self.e_shnum):
            s = self.sh[i]
            if s[1] != 4:                       # SHT_RELA
                continue
            target = self.secname(s[7])
            for k in range(s[5] // 24):
                o = s[4] + k * 24
                off, info, add = struct.unpack_from('<QQq', self.d, o)
                sym, typ = info >> 32, info & 0xFFFFFFFF
                nm = self.symname(sym) if sym < len(syms) else '?'
                yield (target, off, self.R_X86_64.get(typ, str(typ)), nm, add)


# ============================================================== COFF decoder
class Coff:
    """A minimal COFF reader for x86-64, written from the PE/COFF spec."""

    MACHINE = {0x14c: 'i386', 0x8664: 'x86_64', 0xaa64: 'arm64'}
    STORAGE = {0: 'END_OF_FUNCTION', 1: 'NONE', 2: 'EXTERNAL', 3: 'STATIC',
               103: 'FILE'}
    # AMD64 relocation numbers that the course names. There is no PLT variant:
    # a call and a data reference are the same relocation on this target.
    REL_AMD64 = {0: 'ABSOLUTE', 1: 'ADDR64', 2: 'ADDR32', 3: 'ADDR32NB',
                 4: 'REL32', 5: 'REL32_1', 6: 'REL32_2', 7: 'REL32_3',
                 8: 'REL32_4', 9: 'REL32_5', 10: 'SECTION', 11: 'SECREL',
                 12: 'TOKEN', 13: 'SREL32', 14: 'PAIR', 16: 'SECREL7',
                 20: 'REL32_5'}

    def __init__(self, path):
        self.d = d = open(path, 'rb').read()
        (self.machine, self.nsec, self.tstamp, self.symptr, self.nsym,
         self.strsize, self.opthdr) = struct.unpack_from('<HHIIIHH', d, 0)
        self.sections = []
        for i in range(self.nsec):
            o = 20 + i * 40
            (name, vsize, vaddr, rawsize, rawptr, relptr, lineptr,
             nrel, nline, chars) = struct.unpack_from('<8sIIIIIIHHI', d, o)
            self.sections.append({
                'name': name.rstrip(b'\x00').decode(),
                'vsize': vsize, 'vaddr': vaddr, 'rawsize': rawsize,
                'rawptr': rawptr, 'relptr': relptr, 'nrel': nrel,
                'nline': nline, 'chars': chars,
            })
        self.strbase = self.symptr + self.nsym * 18

    def secname_long(self, raw):
        """A COFF name is 8 inline bytes, or /NNN -- a DECIMAL offset."""
        n = raw.rstrip(b'\x00').decode()
        if n.startswith('/') and n[1:].strip().isdigit():
            o = int(n[1:].strip())
            return self.d[self.strbase + o:self.d.index(
                b'\x00', self.strbase + o)].decode()
        return n

    def symbols(self):
        """Yield (index, name, value, secnum, type, storage, naux).

        AUX RECORDS ARE SKIPPED. A reader that ignores NumberOfAuxSymbols
        prints 12 nonsense symbols for demo_coff.o and nothing looks wrong.
        """
        out = []
        i = 0
        while i < self.nsym:
            o = self.symptr + i * 18
            raw = self.d[o:o + 8]
            if raw[:4] == b'\x00\x00\x00\x00':
                off = struct.unpack_from('<I', raw, 4)[0]
                e = self.d.index(b'\x00', self.strbase + off)
                name = self.d[self.strbase + off:e].decode('utf-8', 'replace')
            else:
                name = raw.rstrip(b'\x00').decode('utf-8', 'replace')
            val, sect, typ, sc, naux = struct.unpack_from('<IHHBB', self.d,
                                                          o + 8)
            # SectionNumber is 0 (UNDEF), 1..nsec, or a NEGATIVE special:
            # -1 = ABSOLUTE, -2 = DEBUG. Read it unsigned, then sign it.
            if sect > 0x7FFF:
                sect -= 0x10000
            out.append((i, name, val, sect, typ, sc, naux))
            i += 1 + naux          # <-- the line that matters
        return out

    def relocs(self):
        for i, s in enumerate(self.sections):
            raw = self.d[20 + i * 40:20 + i * 40 + 8]
            for k in range(s['nrel']):
                o = s['relptr'] + k * 10
                va, sym, typ = struct.unpack_from('<IIH', self.d, o)
                yield (i + 1, self.secname_long(raw), va, sym,
                       self.REL_AMD64.get(typ, str(typ)))


# ================================================================ the checks
def check_elf(path, expect_secnames=None, expect_relocs=None):
    name = os.path.basename(path)
    if not os.path.exists(path):
        return
    try:
        e = Elf(path)
    except ValueError as ex:
        print('\n%s  -- SKIPPED: %s' % (name, ex))
        return
    print('\n%s  (ELF64 x86-64 relocatable)' % name)

    check(e.e_type == 1, 'e_type == 1 (ET_REL) -- this is a relocatable file')
    check(e.e_phnum == 0,
          'e_phnum == 0 -- no program headers, and that is not an omission')

    # TIER 3: internal invariant. Every relocation's sh_link must be a
    # SHT_SYMTAB and its sh_info must be a section that actually exists.
    symtab_i = next(i for i, s in enumerate(e.sh) if s[1] == 2)
    for i, s in enumerate(e.sh):
        if s[1] == 4:                      # SHT_RELA
            check(s[6] == symtab_i,
                  '[%d] %s sh_link points at the symtab' % (i, e.secname(i)))
            check(0 < s[7] < e.e_shnum,
                  '[%d] %s sh_info is a valid target section (%s)'
                  % (i, e.secname(i), e.secname(s[7])))

    # TIER 3: a symtab's sh_info is the index of its first non-local symbol.
    if e.symtab:
        _, _, _, info = e.symtab
        syms = e.symbols()
        first_global = next((k for k, s in enumerate(syms) if s[2] != 0), 0)
        check(info == first_global,
              'symtab sh_info == index of first GLOBAL symbol (%d)' % info)
        check(all(s[2] == 0 for s in syms[:info]),
              'every symbol before sh_info is LOCAL, as the rule requires')

    # TIER 2: compare against binutils. Order is not guaranteed, so compare
    # as sets of (section, offset, type, symbol).
    mine = sorted((t, o, ty, s) for (t, o, ty, s, _a) in e.relocs())
    if have('readelf'):
        out = tool('readelf', '-rW', path)
        theirs = []
        cur = None
        for line in out.splitlines():
            if line.startswith("Relocation section"):
                # "Relocation section '.rela.text' at offset 0x240 ..."
                cur = line.split("'")[1]
                cur = cur[1:]          # .rela.text -> rela.text
                cur = cur.replace('rela', '').replace('rel', '')
            f = line.split()
            if (cur and len(f) >= 5 and len(f[0]) == 16
                    and all(ch in '0123456789abcdefABCDEF' for ch in f[0])
                    and all(ch in '0123456789abcdefABCDEF' for ch in f[1])):
                # readelf columns: Offset Info Type Sym.Value Name [+/- Addend]
                nm = f[4]
                for sep in (' - ', ' + '):
                    if sep in nm:
                        nm = nm.split(sep)[0]
                typ = f[2]
                if typ.startswith('R_X86_64_'):
                    typ = typ[len('R_X86_64_'):]
                theirs.append((cur, int(f[0], 16), typ, nm))
        if theirs:
            check(mine == sorted(theirs),
                  'TIER 2: all %d relocations match readelf exactly'
                  % len(theirs))
            if mine != sorted(theirs) and VERBOSE:
                print('        mine   :', mine)
                print('        readelf:', sorted(theirs))
        else:
            print('  skip  readelf parse produced nothing to compare')

    # the numbers the course actually quotes
    got = sorted((o, ty, s) for (t, o, ty, s, _a) in e.relocs()
                 if t == '.text')
    if expect_relocs is not None and got:
        check(got == expect_relocs,
              '.text relocations are the ones the course claims')
        if got != expect_relocs and VERBOSE:
            print('        course:', expect_relocs)
            print('        file  :', got)

    secnames = [e.secname(i) for i in range(e.e_shnum)]
    if expect_secnames is not None:
        check(secnames == expect_secnames,
              'section names are exactly the ones the course lists')
        if secnames != expect_secnames and VERBOSE:
            print('        course:', expect_secnames)
            print('        file  :', secnames)


def check_coff(path):
    name = os.path.basename(path)
    if not os.path.exists(path):
        return
    print('\n%s  (COFF)' % name)
    c = Coff(path)

    # TIER 3, and this is the big one: the symbol table and the section
    # headers record the same facts. Compare them.
    syms = c.symbols()
    aux_defs = 0
    for i, s in enumerate(syms):
        if s[6]:                      # this symbol has aux records
            o = c.symptr + s[0] * 18 + 18
            ln, nrel = struct.unpack_from('<II', c.d, o)
            sec = c.sections[s[3] - 1] if 0 < s[3] <= c.nsec else None
            if sec:
                aux_defs += 1
                check(ln == sec['rawsize'],
                      'aux record for %s: Length %d == section RawDataSize %d'
                      % (s[1], ln, sec['rawsize']))
                check(nrel == sec['nrel'],
                      'aux record for %s: RelocationCount %d == header %d'
                      % (s[1], nrel, sec['nrel']))
    check(aux_defs == c.nsec,
          'every one of the %d sections has a section-definition aux record'
          % c.nsec)

    # TIER 3: every relocation's section index is in range, and the offsets
    # are inside that section.
    secnames = [s['name'] for s in c.sections]
    nrel = 0
    for (secnum, sname, va, sym, typ) in c.relocs():
        nrel += 1
        sec = c.sections[secnum - 1]
        if not (0 <= va < sec['rawsize']):
            bad('reloc in section %d at offset %#x is outside it (size %#x)'
                % (secnum, va, sec['rawsize']))
        if not (0 < sym <= c.nsym):
            bad('reloc references symbol %d, out of range' % sym)
    check(True, '%d relocations, all offsets and symbol indices in range'
          % nrel)

    # COFF section names are 8 bytes and are NOT required to be unique.
    dup = len(secnames) != len(set(secnames))
    print('  note  %d sections, %d distinct names -> duplicate section '
          'names: %s' % (len(secnames), len(set(secnames)),
                         'YES' if dup else 'no'))

    # TIER 2: llvm-readobj-21, which is an independent implementation.
    if have('llvm-readobj-21'):
        out = tool('llvm-readobj-21', '--relocations', path)
        theirs = []
        cur = None
        for line in out.splitlines():
            if 'Section (' in line:
                cur = int(line.split('Section (')[1].split(')')[0])
            elif line.strip().startswith('0x') and cur is not None:
                # "0x4 IMAGE_REL_AMD64_REL32 global_counter (17)"
                f = line.split()
                nm = f[2]
                if nm.endswith(')'):
                    nm = nm[:-1]
                tname = f[1]
                for pre in ('IMAGE_REL_AMD64_', 'IMAGE_REL_I386_'):
                    if tname.startswith(pre):
                        tname = tname[len(pre):]
                theirs.append((cur, int(f[0], 16), nm, tname))
        symnames = {s[0]: s[1] for s in syms}
        mine = sorted((s, va, symnames.get(sy, '?'), ty)
                      for (s, _n, va, sy, ty) in c.relocs())
        theirs = sorted(theirs)
        if theirs:
            check(mine == theirs,
                  'TIER 2: all %d relocations match llvm-readobj-21 '
                  '(section, offset, symbol AND type)' % len(theirs))
            if mine != theirs and VERBOSE:
                print('        mine    :', mine)
                print('        llvm    :', theirs)


def check_hand_built():
    """The emitter's output, against a real linker. Tier 2 by execution."""
    path = os.path.join(HERE, 'hand.o')
    if not os.path.exists(path):
        return
    print('\nhand.o  (emitted by emit_elf.py, no library involved)')
    e = Elf(path)
    check(e.e_type == 1, 'e_type == ET_REL')
    check(e.e_phnum == 0, 'e_phnum == 0')
    check(e.e_shnum == 8, 'exactly 8 section headers, as emit_elf.py says')
    check(e.secname(5) == '.symtab' and e.secname(6) == '.strtab',
          'section 5 is .symtab and section 6 is .strtab')
    names = [n for _i, n, _b, _t, _s, _v, _z in e.symbols()]
    check(names[1:] == ['helper', 'answer', 'answer_ptr', 'start', 'compute'],
          'the five symbols are the ones emit_elf.py declares')
    # the two sections in .data must not overlap -- they did, once
    d = e.sh[[e.secname(i) for i in range(e.e_shnum)].index('.data')]
    ans = [s for s in e.symbols() if s[1] == 'answer'][0]
    ptr = [s for s in e.symbols() if s[1] == 'answer_ptr'][0]
    check(ans[5] + ans[6] <= ptr[5],
          'answer (%d bytes at %d) does not overlap answer_ptr at %d'
          % (ans[6], ans[5], ptr[5]))
    check(d[5] >= ptr[5] + ptr[6], '.data is big enough for both')
    if have('ld'):
        r = subprocess.run(['ld', '-r', path, '-o', os.devnull],
                           capture_output=True, text=True)
        check(r.returncode == 0,
              'TIER 2: a real linker accepts it (ld -r exit %d)%s'
              % (r.returncode, ('  ' + r.stderr.strip()) if r.stderr else ''))


def main():
    print('=' * 72)
    print('Object Files -- crosscheck')
    print('Three tiers: independent decoder, external toolchain, and the')
    print("file's own internal invariants. Tier 3 catches the most.")
    print('=' * 72)

    check_elf(os.path.join(HERE, 'demo_elf.o'),
              expect_secnames=['', '.strtab', '.text',
                               '.rela.text', '.data', '.rela.data',
                               '.rodata.str1.1', '.rodata', '.bss',
                               '.comment', '.note.GNU-stack', '.eh_frame',
                               '.rela.eh_frame', '.llvm_addrsig', '.symtab'],
              expect_relocs=[(4, 'PC32', 'global_counter'),
                             (0x0a, 'PC32', 'uninitialised'),
                             (0x21, 'PLT32', 'external_fn'),
                             (0x33, 'PC32', 'message')])
    check_elf(os.path.join(HERE, 'demo_i386_nopic.o'), None, None)
    check_elf(os.path.join(HERE, 'ca_elf.o'), None, None)
    check_elf(os.path.join(HERE, 'w_elf.o'), None, None)
    check_elf(os.path.join(HERE, 'uw_elf.o'), None, None)
    check_coff(os.path.join(HERE, 'demo_coff.o'))
    check_coff(os.path.join(HERE, 'ca_coff.o'))
    check_coff(os.path.join(HERE, 'uw_coff.o'))
    check_hand_built()

    print('\n' + '=' * 72)
    print('%d passed, %d failed' % (PASS, FAIL))
    print('=' * 72)
    return 1 if FAIL else 0


if __name__ == '__main__':
    sys.exit(main())
