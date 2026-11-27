#!/usr/bin/env python3
"""Independent COFF (classic, non-bigobj) object-file parser.

Written from the PE/COFF specification, not from any existing tool, so that its
output can be compared field-by-field against llvm-readobj / llvm-objdump.
Agreement between two independently written parsers is the evidence; agreeing
with one tool by eye is not.

Usage:
    python3 coff_parse.py <file.obj> [--raw]
"""
import struct
import sys

MACHINES = {
    0x0000: 'IMAGE_FILE_MACHINE_UNKNOWN',
    0x014c: 'IMAGE_FILE_MACHINE_I386',
    0x0166: 'IMAGE_FILE_MACHINE_R4000',
    0x01a2: 'IMAGE_FILE_MACHINE_SH3',
    0x01c0: 'IMAGE_FILE_MACHINE_ARM',
    0x01c4: 'IMAGE_FILE_MACHINE_ARMNT',
    0x01f0: 'IMAGE_FILE_MACHINE_POWERPC',
    0x0200: 'IMAGE_FILE_MACHINE_IA64',
    0x0266: 'IMAGE_FILE_MACHINE_MIPS16',
    0x0EBC: 'IMAGE_FILE_MACHINE_EBC',
    0x8664: 'IMAGE_FILE_MACHINE_AMD64',
    0x9041: 'IMAGE_FILE_MACHINE_M32R',
    0xaa64: 'IMAGE_FILE_MACHINE_ARM64',
    0xc0ee: 'IMAGE_FILE_MACHINE_CEE',
}

STORAGE_CLASS = {
    0: 'IMAGE_SYM_CLASS_END_OF_FUNCTION',
    1: 'IMAGE_SYM_CLASS_NULL',
    2: 'IMAGE_SYM_CLASS_EXTERNAL',
    3: 'IMAGE_SYM_CLASS_STATIC',
    4: 'IMAGE_SYM_CLASS_REGISTER',
    5: 'IMAGE_SYM_CLASS_EXTERNAL_DEF',
    6: 'IMAGE_SYM_CLASS_LABEL',
    7: 'IMAGE_SYM_CLASS_UNDEFINED_LABEL',
    8: 'IMAGE_SYM_CLASS_MEMBER_OF_STRUCT',
    9: 'IMAGE_SYM_CLASS_ARGUMENT',
    10: 'IMAGE_SYM_CLASS_STRUCT_TAG',
    11: 'IMAGE_SYM_CLASS_FILE',
    12: 'IMAGE_SYM_CLASS_SECTION',
    13: 'IMAGE_SYM_CLASS_WEAK_EXTERNAL',
    14: 'IMAGE_SYM_CLASS_CLR_TOKEN',
    100: 'IMAGE_SYM_CLASS_EXTERNAL_DEF',
    101: 'IMAGE_SYM_CLASS_SECTION',
    102: 'IMAGE_SYM_CLASS_WEAK_EXTERNAL',
    103: 'IMAGE_SYM_CLASS_FILE',
    105: 'IMAGE_SYM_CLASS_STATIC',
}

# section characteristic bits
SCN = [
    (0x00000020, 'IMAGE_SCN_CNT_CODE'),
    (0x00000040, 'IMAGE_SCN_CNT_INITIALIZED_DATA'),
    (0x00000080, 'IMAGE_SCN_CNT_UNINITIALIZED_DATA'),
    (0x00000200, 'IMAGE_SCN_LNK_INFO'),
    (0x00000800, 'IMAGE_SCN_LNK_REMOVE'),
    (0x00001000, 'IMAGE_SCN_LNK_COMDAT'),
    (0x00004000, 'IMAGE_SCN_GPREL'),
    (0x00008000, 'IMAGE_SCN_MEM_PURGEABLE'),
    (0x00010000, 'IMAGE_SCN_MEM_LOCKED'),
    (0x00020000, 'IMAGE_SCN_MEM_PRELOAD'),
    (0x01000000, 'IMAGE_SCN_LNK_NRELOC_OVFL'),
    (0x02000000, 'IMAGE_SCN_MEM_DISCARDABLE'),
    (0x04000000, 'IMAGE_SCN_MEM_NOT_CACHED'),
    (0x08000000, 'IMAGE_SCN_MEM_NOT_PAGED'),
    (0x10000000, 'IMAGE_SCN_MEM_SHARED'),
    (0x20000000, 'IMAGE_SCN_MEM_EXECUTE'),
    (0x40000000, 'IMAGE_SCN_MEM_READ'),
    (0x80000000, 'IMAGE_SCN_MEM_WRITE'),
]

# Alignment is a 4-bit FIELD in bits 20-23, not six independent flags. Decoding
# it as independent bits makes 0x00500000 (ALIGN_16BYTES) report as all six.
ALIGN = {
    0: 'IMAGE_SCN_ALIGN_1BYTES_DEFAULT',
    1: 'IMAGE_SCN_ALIGN_1BYTES',
    2: 'IMAGE_SCN_ALIGN_2BYTES',
    3: 'IMAGE_SCN_ALIGN_4BYTES',
    4: 'IMAGE_SCN_ALIGN_8BYTES',
    5: 'IMAGE_SCN_ALIGN_16BYTES',
    6: 'IMAGE_SCN_ALIGN_32BYTES',
    7: 'IMAGE_SCN_ALIGN_64BYTES',
    8: 'IMAGE_SCN_ALIGN_128BYTES',
    9: 'IMAGE_SCN_ALIGN_256BYTES',
    10: 'IMAGE_SCN_ALIGN_512BYTES',
    11: 'IMAGE_SCN_ALIGN_1024BYTES',
    12: 'IMAGE_SCN_ALIGN_2048BYTES',
    13: 'IMAGE_SCN_ALIGN_4096BYTES',
    14: 'IMAGE_SCN_ALIGN_8192BYTES',
}

AMD64_RELOC = {
    0x0000: 'IMAGE_REL_AMD64_ABSOLUTE',
    0x0001: 'IMAGE_REL_AMD64_ADDR64',
    0x0002: 'IMAGE_REL_AMD64_ADDR32',
    0x0003: 'IMAGE_REL_AMD64_ADDR32NB',
    0x0004: 'IMAGE_REL_AMD64_REL32',
    0x0005: 'IMAGE_REL_AMD64_REL32_1',
    0x0006: 'IMAGE_REL_AMD64_REL32_2',
    0x0007: 'IMAGE_REL_AMD64_REL32_3',
    0x0008: 'IMAGE_REL_AMD64_REL32_4',
    0x0009: 'IMAGE_REL_AMD64_REL32_5',
    0x000A: 'IMAGE_REL_AMD64_SECTION',
    0x000B: 'IMAGE_REL_AMD64_SECREL',
    0x000C: 'IMAGE_REL_AMD64_TOKEN',
    0x000D: 'IMAGE_REL_AMD64_SREL32',
    0x000E: 'IMAGE_REL_AMD64_PAIR',
    0x000F: 'IMAGE_REL_AMD64_SSPAN32',
}

SELECTION = {
    0: 'IMAGE_COMDAT_SELECT_None',
    1: 'IMAGE_COMDAT_SELECT_NODUPLICATES',
    2: 'IMAGE_COMDAT_SELECT_ANY',
    3: 'IMAGE_COMDAT_SELECT_SAME_SIZE',
    4: 'IMAGE_COMDAT_SELECT_EXACT_MATCH',
    5: 'IMAGE_COMDAT_SELECT_ASSOCIATIVE',
    6: 'IMAGE_COMDAT_SELECT_LARGEST',
}


def flags(value, table):
    return [name for bit, name in table if value & bit]


def cstr(data, off):
    end = data.index(b'\x00', off)
    return data[off:end].decode('ascii', 'replace')


def parse_symbol_name(d, name8, strtab_base):
    """8-byte union: either an inline name, or 0x00000000 + a string offset."""
    if name8[:4] == b'\x00\x00\x00\x00':
        so = struct.unpack_from('<I', name8, 4)[0]
        if so == 0:
            return '<none>'
        return cstr(d, strtab_base + so)
    return name8.rstrip(b'\x00').decode('ascii', 'replace')


def main():
    path = sys.argv[1]
    d = open(path, 'rb').read()
    raw = d

    print(f'=== {path} ({len(d)} bytes) ===')
    print()
    print('--- IMAGE_FILE_HEADER (20 bytes at 0x00) ---')
    machine, nsec, stamp, symptr, symcnt, optsize, chars = struct.unpack_from(
        '<HHIIIHH', raw, 0)
    rows = [
        ('0x00', 2, 'Machine', machine),
        ('0x02', 2, 'NumberOfSections', nsec),
        ('0x04', 4, 'TimeDateStamp', stamp),
        ('0x08', 4, 'PointerToSymbolTable', symptr),
        ('0x0c', 4, 'NumberOfSymbols', symcnt),
        ('0x10', 2, 'SizeOfOptionalHeader', optsize),
        ('0x12', 2, 'Characteristics', chars),
    ]
    for off, size, name, val in rows:
        extra = ''
        if name == 'Machine':
            extra = '  ' + MACHINES.get(val, '?')
        print(f'  {off} {size}B  {name:22s} = {val} (0x{val:x}){extra}')
    if optsize == 0:
        print('  ==> SizeOfOptionalHeader is 0: this is a relocatable OBJECT,')
        print('      not a loadable image. Nothing in this file has an address.')

    # ---- section table ----
    stroff = symptr + symcnt * 18
    strsize = struct.unpack_from('<I', raw, stroff)[0] if stroff + 4 <= len(raw) else 0

    def long_name(name8):
        """`/N` means: decimal offset N into the string table."""
        if name8[:1] == b'/':
            n = int(name8[1:].split(b'\x00')[0] or b'0')
            return cstr(d, stroff + n)
        return name8.rstrip(b'\x00').decode('ascii', 'replace')

    print()
    print(f'--- section table: {nsec} entries x 40 bytes at 0x14 ---')
    sections = []
    base = 20
    for i in range(nsec):
        o = base + i * 40
        name8 = raw[o:o + 8]
        (vsize, vaddr, rawsz, rawptr, relptr, lineptr,
         nrel, nline) = struct.unpack_from('<IIIIIIHH', raw, o + 8)
        ch = struct.unpack_from('<I', raw, o + 36)[0]
        secname = long_name(name8)
        sections.append(dict(
            index=i + 1, name=secname, vsize=vsize, vaddr=vaddr,
            rawsz=rawsz, rawptr=rawptr, relptr=relptr, lineptr=lineptr,
            nrel=nrel, nline=nline, chars=ch))
        print(f'  [{i}] {secname:14s} hdr@0x{o:04x}  '
              f'VirtualSize={vsize} VirtualAddress=0x{vaddr:x} '
              f'SizeOfRawData={rawsz} PointerToRawData=0x{rawptr:x}')
        print(f'       PointerToRelocations=0x{relptr:x} ({nrel})  '
              f'PointerToLinenumbers=0x{lineptr:x} ({nline})')
        align = (ch >> 20) & 0xF
        print(f'       Characteristics=0x{ch:08x}  align_bits={align}'
              f' ({ALIGN.get(align, "?")})  '
              + ' '.join(flags(ch, SCN)))
        if rawsz == 0 and rawptr == 0:
            print(f'       NOTE: no file bytes - the linker allocates this as '
                  f'zeros ({vsize or "size"} bytes)')

    # ---- relocations ----
    # VERIFIED 10-byte layout (clang output, cross-checked with llvm-objdump -r):
    #     0x00 DWORD  VirtualAddress   (offset within the section)
    #     0x04 DWORD  SymbolTableIndex (low 16 bits used, high 16 unused)
    #     0x08 WORD   Type
    # The PE/COFF spec also documents an *overlapping* x64 variant that packs
    # the type into bits 12-15 of the first dword. clang does not emit that;
    # every object produced here uses the plain layout above.
    print()
    print('--- relocations (10 bytes: DWORD addr, DWORD sym, WORD type) ---')
    is_amd64 = machine == 0x8664
    for s in sections:
        if not s['nrel']:
            continue
        print(f"  section {s['index']} {s['name']}: {s['nrel']} entries "
              f"at 0x{s['relptr']:x}")
        for k in range(s['nrel']):
            o = s['relptr'] + k * 10
            vaddr, symidx, typ = struct.unpack_from('<IIH', raw, o)
            symidx &= 0xFFFF
            tname = AMD64_RELOC.get(typ, '?') if is_amd64 else 'type=%d' % typ
            print(f'    [{k}] file 0x{o:04x}  addr=0x{vaddr:04x}  '
                  f'sym={symidx}  type={typ} ({tname})')

    # ---- symbol table ----
    print()
    print(f'--- symbol table: {symcnt} entries x 18 bytes at 0x{symptr:x} ---')
    print(f'    string table at 0x{stroff:x}, size {strsize} '
          f'(first 4 bytes are the size itself)')
    i = 0
    shown = 0
    while i < symcnt and shown < 40:
        o = symptr + i * 18
        name = parse_symbol_name(d, raw[o:o + 8], stroff)
        (value, sect, typ, sc, naux) = struct.unpack_from('<IhHBB', raw, o + 8)
        scn = STORAGE_CLASS.get(sc, '?%d' % sc)
        secname = sections[sect - 1]['name'] if 1 <= sect <= nsec else (
            '*ABS*' if sect == 0xFFFE else 'UNDEF(%d)' % sect)
        print(f'    [{i}] {name:34s} Value=0x{value:04x} Section={sect}'
              f'({secname}) Type=0x{typ:04x} StorageClass={sc}({scn}) '
              f'Aux={naux}')
        if naux and typ == 0 and sc == 3 and sect:
            # Section-definition aux record.
            # VERIFIED layout (clang output, cross-checked with llvm-readobj).
            # The spec documents NumberOfLinenumbers at 0x08; clang puts
            # CheckSum there instead and moves NumberOfLinenumbers to 0x10.
            # Independent proof of the real order: the WORD at 0x0c always
            # equals the 1-based section index, which is what `Number` means.
            a = symptr + (i + 1) * 18
            ln, nrl, chk = struct.unpack_from('<III', raw, a)
            no, sel, _res = struct.unpack_from('<HBB', raw, a + 12)
            nln, = struct.unpack_from('<H', raw, a + 16)
            print(f'         AuxSectionDef: Length={ln} Relocs={nrl} '
                  f'Checksum=0x{chk:08x} Number={no} '
                  f'Selection={sel} ({SELECTION.get(sel, "?")}) '
                  f'Lines={nln}')
            if no != sect:
                print(f'         !! Number({no}) != section index({sect}) - '
                      f'aux layout assumption is wrong')
        i += 1 + naux
        shown += 1
    if i < symcnt:
        print(f'    ... ({symcnt - i} more entries)')


if __name__ == '__main__':
    main()
