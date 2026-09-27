#!/usr/bin/env python3
"""apply_relocs.py -- read a real relocatable object, apply its relocations
at an address you choose, and check the result.

    python3 apply_relocs.py                 # defaults to sum8_nopic.o
    python3 apply_relocs.py --obj x.o --base 0x400000
    python3 apply_relocs.py --obj x.o --all-bases   # try many, find overflow

This is the exercise from the course concept "Applying Them Yourself". It is
short on purpose: the whole point is that a relocation applier is not a large
program. What it takes is a section-header table, a symbol table, a .rela
section, and three arithmetic rules.

Run build_samples.sh first.
"""

import argparse
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

# The three rules, in one place. Everything else in this file is plumbing.
#
#   PC-RELATIVE : value = S + A - P          (a DISTANCE; survives translation)
#   ABSOLUTE    : value = S + A              (an ADDRESS; dies on translation)
#   WIDTH       : how many bytes to store it in
#
# S = the symbol's value (st_value, section-relative for ET_REL)
# A = the addend (r_addend)
# P = the ADDRESS OF THE FIELD BEING PATCHED, not the section offset

# The three rules, in one place, keyed by the on-disk TYPE NUMBER (not the
# name -- a reader of this file should have to look the number up, because
# that is what the linker does). Numbers verified against /usr/include/elf.h.
#
#   PC-RELATIVE : value = S + A - P          (a DISTANCE; survives translation)
#   ABSOLUTE    : value = S + A              (an ADDRESS; dies on translation)
#   WIDTH       : how many bytes to store it in
#
# S = the symbol's value (st_value, section-relative for ET_REL)
# A = the addend (r_addend)
# P = the ADDRESS OF THE FIELD BEING PATCHED, not the section offset
#
#   type number -> (name, width, pc_relative)
RELOCS = {
    0:  ('R_X86_64_NONE',          0, False),
    1:  ('R_X86_64_64',            8, False),
    2:  ('R_X86_64_PC32',          4, True),
    4:  ('R_X86_64_PLT32',         4, True),
    10: ('R_X86_64_32',            4, False),
    11: ('R_X86_64_32S',           4, False),
    19: ('R_X86_64_TLSGD',         4, True),
    22: ('R_X86_64_GOTTPOFF',      4, True),
    23: ('R_X86_64_TPOFF32',       4, False),
    24: ('R_X86_64_PC64',          8, True),
    25: ('R_X86_64_GOTOFF64',      8, False),
    26: ('R_X86_64_GOTPC32',       4, True),
    41: ('R_X86_64_GOTPCRELX',     4, True),
    42: ('R_X86_64_REX_GOTPCRELX', 4, True),
    # loader's job, not the linker's: a patcher that meets one of these is
    # being asked to do something no arithmetic can express. See tls-model.
    6:  ('R_X86_64_GLOB_DAT',      8, False),
    7:  ('R_X86_64_JUMP_SLOT',     8, False),
    8:  ('R_X86_64_RELATIVE',      8, False),
    37: ('R_X86_64_IRELATIVE',     8, False),
}

SHN_UNDEF, SHN_ABS, SHN_COMMON, SHN_XINDEX = 0, 0xfff1, 0xfff2, 0xffff


class Elf:
    """Enough of ELF64 little-endian to do this job. No libelf."""

    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.buf = f.read()
        self._headers()
        self._sections()
        self._symbols()

    def _headers(self):
        b = self.buf
        if b[:4] != b'\x7fELF':
            sys.exit('%s: not an ELF file' % self.path)
        if b[4] != 2 or b[5] != 1:
            sys.exit('%s: this script handles 64-bit little-endian only' % self.path)
        (self.e_type, self.e_machine) = struct.unpack_from('<HH', b, 16)
        (self.e_entry, self.e_phoff, self.e_shoff) = struct.unpack_from('<QQQ', b, 24)
        (self.e_flags, self.e_ehsize, self.e_phentsize, self.e_phnum) = \
            struct.unpack_from('<IHHH', b, 48)
        (self.e_shentsize, self.e_shnum, self.e_shstrndx) = \
            struct.unpack_from('<HHH', b, 58)

    def _sections(self):
        b, n, off = self.buf, self.e_shnum, self.e_shoff
        self.shdrs = []
        for i in range(n):
            base = off + i * 64
            (name, typ, flags, addr, offset, size, link, info,
             align, entsize) = struct.unpack_from('<IIQQQQIIQQ', b, base)
            self.shdrs.append(dict(
                index=i, name=name, type=typ, flags=flags, addr=addr,
                offset=offset, size=size, link=link, info=info, align=align,
                entsize=entsize))
        strtab = self.shdrs[self.e_shstrndx]
        self.shnames = self.buf[strtab['offset']:strtab['offset'] + strtab['size']]

    def name_of(self, sh):
        end = self.shnames.index(b'\0', sh['name'])
        return self.shnames[sh['name']:end].decode()

    def section_by_name(self, want):
        for i, sh in enumerate(self.shdrs):
            if self.name_of(sh) == want:
                return i
        return None

    def section_data(self, idx):
        sh = self.shdrs[idx]
        return self.buf[sh['offset']:sh['offset'] + sh['size']]

    def _symbols(self):
        b = self.buf
        self.syms = []
        for i, sh in enumerate(self.shdrs):
            if sh['type'] not in (2, 11):          # SYMTAB, DYNSYM
                continue
            strtab = self.section_data(sh['link'])
            data = self.section_data(i)
            for k in range(len(data) // 24):
                (nm, info, other, shndx, value, size) = \
                    struct.unpack_from('<IBBHQQ', data, k * 24)
                end = strtab.index(b'\0', nm)
                self.syms.append(dict(
                    index=k, name=strtab[nm:end].decode(), info=info,
                    shndx=shndx, value=value, size=size, table=i))

    def sym_name(self, idx):
        return self.syms[idx]['name']

    def relocs_in(self, secname):
        """Every (offset, type, symbol, addend) in one .rela section."""
        idx = self.section_by_name(secname)
        if idx is None:
            return None
        sh = self.shdrs[idx]
        # .rela.<sec>'s sh_link is the SYMBOL TABLE it indexes; that table's
        # own sh_link is the string table. Two hops, and skipping either one
        # is how you end up with a reloc list full of anonymous symbols.
        symtab_index = sh['link']
        strtab = self.section_data(self.shdrs[symtab_index]['link'])
        symdata = self.section_data(symtab_index)
        data = self.section_data(idx)
        out = []
        for k in range(len(data) // 24):
            r_offset, r_info, r_addend = struct.unpack_from('<QQq', data, k * 24)
            rtype = r_info & 0xffffffff
            rsym = r_info >> 32
            name = ''
            if rsym * 24 + 24 <= len(symdata):
                nm = struct.unpack_from('<I', symdata, rsym * 24)[0]
                name = strtab[nm:strtab.index(b'\0', nm)].decode()
            out.append(dict(offset=r_offset, type=rtype, sym=rsym,
                            addend=r_addend, name=name))
        return out

    # -- the three rules ---------------------------------------------------

    def symbol_address(self, sym, layout):
        """Resolve a symbol to an address under a given section layout."""
        s = self.syms[sym] if isinstance(sym, int) else sym
        if s['shndx'] in (SHN_UNDEF, SHN_ABS, SHN_COMMON):
            return 0                      # undefined: the caller must supply it
        sh = self.shdrs[s['shndx']]
        return layout.get(s['shndx'], 0) + s['value']

    def apply(self, rel, secname, layout, extern_addrs):
        """Return (value, note) for one relocation, or (None, reason)."""
        entry = RELOCS.get(rel['type'])
        if entry is None:
            return None, 'unknown type number %d' % rel['type']
        rname, width, pc_rel = entry
        if rel['name']:
            addr = extern_addrs.get(rel['name'])
            if addr is None:
                addr = self.symbol_address(rel['sym'], layout)
        else:
            addr = self.symbol_address(rel['sym'], layout)
        P = layout.get('field', 0) + rel['offset']     # the FIELD's address
        val = addr + rel['addend']
        if pc_rel:
            val -= P
        if width == 4:
            lo, hi = -(1 << 31), (1 << 31) - 1
            if not (lo <= val <= hi):
                return None, ('%s overflow: %d does not fit in 32 signed bits'
                              ' (P=%#x, S=%#x, A=%d, %s)'
                              % (rname, val, P, addr, rel['addend'],
                                 'distance' if pc_rel else 'ADDRESS'))
        return val, None

    def patch(self, secname, relocs, layout, extern_addrs):
        """Apply every relocation into a copy of the section. Returns bytes."""
        idx = self.section_by_name(secname)
        data = bytearray(self.section_data(idx))
        applied = []
        for rel in relocs:
            rel = dict(rel, name=rel['name'])
            rel['_'] = None
            val, why = self.apply(rel, secname, layout, extern_addrs)
            if val is None:
                raise OverflowError('offset %#x: %s' % (rel['offset'], why))
            rname, width, pc_rel = RELOCS[rel['type']]
            fmt = '<q' if width == 8 else '<i'
            struct.pack_into(fmt, data, rel['offset'], val)
            applied.append((rel, val))
        return bytes(data), applied


def build_layout(elf, base):
    """Assign every allocated section an address under `base`.

    A real linker has a whole algorithm for this (file offsets, alignment,
    segments). This is the minimum a relocation applier needs: a place to put
    each section so that a PC-relative field has something to be relative TO.
    """
    layout, addr = {}, base
    for i, sh in enumerate(elf.shdrs):
        if sh['type'] == 8:                       # NOBITS = .bss
            continue
        if not sh['size']:
            continue
        align = max(sh['align'], 1)
        addr = (addr + align - 1) & ~(align - 1)
        layout[i] = addr
        addr += sh['size']
    layout['field'] = layout.get(
        elf.section_by_name('.text'), base)
    return layout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--obj', default='closed.o')
    ap.add_argument('--sec', default='.text')
    ap.add_argument('--base', default='0x400000',
                    help='address the first section is loaded at')
    ap.add_argument('--all-bases', action='store_true',
                    help='sweep the base and report where PC32 overflows')
    ap.add_argument('--show', action='store_true',
                    help='disassemble the patched section with objdump')
    a = ap.parse_args()

    if not os.path.exists(a.obj):
        sys.exit('%s not found -- run ./build_samples.sh first' % a.obj)

    elf = Elf(a.obj)
    rels = elf.relocs_in('.rela' + a.sec)
    if rels is None:
        sys.exit('no .rela%s in %s' % (a.sec, a.obj))

    if a.all_bases:
        # Find the base at which a PC32 stops fitting, by trying rather than
        # by reasoning. 64MB steps: 4GB / 64MB is 64 attempts, which is
        # instant, and the answer it finds is a real base, not a formula.
        print('sweeping the load base until a 4-byte field stops fitting '
              '(64MB steps, 0..4GB)...\n')
        print('  watch WHICH relocation breaks first: it is the absolute')
        print('  one, not the PC-relative one. A distance cannot be broken')
        print('  by translating the image; an ADDRESS can.\n')
        step = 64 << 20
        base = 0
        first_fail = None
        while base <= (4 << 30):
            try:
                elf.patch(a.sec, rels, build_layout(elf, base), {})
                status = 'ok'
            except OverflowError as e:
                status = 'OVERFLOW: %s' % e
                if first_fail is None:
                    first_fail = (base, str(e))
            if base % (1 << 30) == 0 or status != 'ok':
                print('  base=%#012x  %s' % (base, status))
            base += step
        if first_fail is None:
            print('\n  no 4-byte field overflowed anywhere in 0..4GB. The '
                  'limit is real; this layout is small.')
            return 0
        print('\n  first failure at base=%#x  (== 2^31 exactly)' % first_fail[0])
        print('  %s' % first_fail[1])
        print('\n  The last base that worked was %#x. The boundary is 2^31,'
              % (first_fail[0] - step))
        print('  which is what a SIGNED 32-bit field holds -- and note the')
        print('  breaker is the ABSOLUTE relocation. Move the image and a')
        print('  distance is unchanged, so R_X86_64_PLT32 here kept working at')
        print('  every base in the sweep. That is why the vocabulary has a')
        print('  PC-relative form at all.')
        return 0

    base = int(a.base, 16)
    layout = build_layout(elf, base)

    print('%s  e_type=%d  %d relocations in .rela%s'
          % (a.obj, elf.e_type, len(rels), a.sec))
    print('base = %#x\n' % base)

    try:
        data, applied = elf.patch(a.sec, rels, layout, {})
    except OverflowError as e:
        print('PATCH FAILED: %s' % e)
        return 1

    for rel, val in applied:
        rname = RELOCS[rel['type']][0]
        symval = elf.syms[rel['sym']]['value'] if not rel['name'] else 0
        print('  %#06x  %-24s %-8s S=%#010x A=%+d  ->  value=%#x'
              % (rel['offset'], rname, rel['name'] or '-', symval,
                 rel['addend'], val))
    print('\nall %d relocations applied; %d bytes of .text' % (len(applied), len(data)))

    if a.show:
        open('/tmp/opencode_patched.bin', 'wb').write(data)
        print('\n$ objdump -D -b binary -m i386:x86-64 '
              '-M intel /tmp/opencode_patched.bin')
        subprocess.run(['objdump', '-D', '-b', 'binary', '-m', 'i386:x86-64',
                        '-M', 'intel', '/tmp/opencode_patched.bin'])

    return 0


if __name__ == '__main__':
    sys.exit(main())
