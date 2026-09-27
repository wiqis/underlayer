#!/usr/bin/env python3
"""emit_elf.py -- write a relocatable ELF64 x86-64 object file byte by byte.

No library writes any part of this. Every field is computed here and packed
with struct, and the output is checked by handing it to a real linker.

The object it produces is the equivalent of:

    extern int helper(int);        /* defined elsewhere            */
    int   answer = 41;             /* .data, needs no relocation    */
    int  *answer_ptr = &answer;    /* .data, needs an 8-byte abs    */

    int compute(int x) { return helper(x) + 1; }   /* calls out      */
    int start(int x)   { return compute(x); }       /* calls in       */

    -> .text   2 functions, 2 relocations (1 internal PC32, 1 external PLT32)
    -> .data   8 bytes + 1 R_X86_64_64 relocation
    -> .rela.text, .rela.data, .symtab, .strtab, .shstrtab, 8 section headers

    $ python3 emit_elf.py hand.o
    $ ld -r hand.o -o /dev/null          # a real linker accepts it
    $ ld hand.o helper.o main.o -o app   # and it runs
"""
import struct
import sys

# ---------------------------------------------------------------- constants
EI_NIDENT = 16
ET_REL = 1
EM_X86_64 = 62
EV_CURRENT = 1

SHT_PROGBITS = 1
SHT_SYMTAB = 2
SHT_STRTAB = 3
SHT_RELA = 4

SHF_WRITE = 0x1
SHF_ALLOC = 0x2
SHF_EXECINSTR = 0x4

STB_LOCAL = 0
STB_GLOBAL = 1
STT_NOTYPE = 0
STT_FUNC = 2
STT_OBJECT = 1
SHN_UNDEF = 0

R_X86_64_64 = 1
R_X86_64_PC32 = 2
R_X86_64_PLT32 = 4


class StrTab:
    """An ELF string table: byte 0 is NUL, so offset 0 always means 'no name'."""

    def __init__(self):
        self.b = bytearray(b'\x00')

    def add(self, s):
        off = len(self.b)
        self.b += s.encode() + b'\x00'
        return off


def emit(path, out=sys.stdout):
    # ------------------------------------------------------ section payloads
    #
    # start(x)  : movl 4(%esp),%eax ; call compute ; ret
    #   8b 44 24 04          movl 4(%esp),%eax
    #   e8 <rel32 @+2>       call compute   -> PC32 against `compute`
    #   c3                   ret
    start_code = bytes([0x8b, 0x44, 0x24, 0x04, 0xe8, 0, 0, 0, 0, 0xc3])
    # compute(x): movl 4(%esp),%eax ; call helper ; addl $1,%eax ; ret
    #   8b 44 24 04          movl 4(%esp),%eax
    #   e8 <rel32 @+5>       call helper    -> PLT32 against `helper`
    #   83 c0 01             addl $1,%eax
    #   c3                   ret
    compute_code = bytes([0x8b, 0x44, 0x24, 0x04, 0xe8, 0, 0, 0, 0,
                          0x83, 0xc0, 0x01, 0xc3])

    text = start_code + compute_code          # 10 + 13 = 23 bytes
    START_OFF = 0
    COMPUTE_OFF = len(start_code)             # 10
    # `call` in start() is at text offset 4, so its rel32 field is at 5.
    START_CALL_FIELD = 5
    # `call` in compute() is at COMPUTE_OFF + 4, so its rel32 field is at +5.
    COMPUTE_CALL_FIELD = COMPUTE_OFF + 5

    # .data: `int answer = 41;` at offset 0, then `int *answer_ptr = &answer;`
    # at offset 4.  The two objects MUST NOT overlap -- a 4-byte int and an
    # 8-byte pointer sharing offset 0 links cleanly and reads the address
    # back out of `answer`.  Overlap is not a format error, which is exactly
    # what makes it dangerous.
    ANSWER_OFF = 0
    ANSWER_PTR_OFF = 4
    DATA_ABS_FIELD = ANSWER_PTR_OFF
    data = struct.pack('<iQ', 41, 0)          # 12 bytes

    # ---------------------------------------------------------- string tables
    strtab = StrTab()
    s_null = 0
    s_helper = strtab.add('helper')            # UND, global
    s_answer = strtab.add('answer')            # .data, global
    s_answer_ptr = strtab.add('answer_ptr')    # .data, global
    s_start = strtab.add('start')              # .text, global
    s_compute = strtab.add('compute')          # .text, global

    shstrtab = StrTab()
    sh = {}
    sh['text'] = shstrtab.add('.text')
    sh['data'] = shstrtab.add('.data')
    sh['rela_text'] = shstrtab.add('.rela.text')
    sh['rela_data'] = shstrtab.add('.rela.data')
    sh['symtab'] = shstrtab.add('.symtab')
    sh['strtab'] = shstrtab.add('.strtab')
    sh['shstrtab'] = shstrtab.add('.shstrtab')

    # ------------------------------------------------------------- symtab
    # 24-byte Elf64_Sym: name(4) info(1) other(1) shndx(2) value(8) size(8)
    #
    # SECTION INDICES, fixed for the whole file. Get one of these wrong and
    # every reader silently reports the wrong answer -- there is no checksum.
    IDX_TEXT = 1
    IDX_DATA = 2
    IDX_RELA_TEXT = 3
    IDX_RELA_DATA = 4
    IDX_SYMTAB = 5
    IDX_STRTAB = 6
    IDX_SHSTRTAB = 7

    def sym(name, info, shndx, value=0, size=0):
        return struct.pack('<IBBHQQ', name, info, 0, shndx, value, size)

    STB_GLOBAL = 1
    # index 0 is the reserved UND entry, and it is not a local symbol: ELF
    # requires sh_info of a symtab to be the index of its first non-local.
    symtab = sym(0, 0, SHN_UNDEF)
    # locals must precede globals; this file has no locals, so index 1 is
    # already the first global and sh_info = 1.
    i_helper = 1
    symtab += sym(s_helper, (STB_GLOBAL << 4) | STT_NOTYPE, SHN_UNDEF, 0, 0)
    i_answer = 2
    symtab += sym(s_answer, (STB_GLOBAL << 4) | STT_OBJECT, IDX_DATA,
                  ANSWER_OFF, 4)
    i_answer_ptr = 3
    symtab += sym(s_answer_ptr, (STB_GLOBAL << 4) | STT_OBJECT, IDX_DATA,
                  ANSWER_PTR_OFF, 8)
    i_start = 4
    symtab += sym(s_start, (STB_GLOBAL << 4) | STT_FUNC, IDX_TEXT,
                  START_OFF, len(start_code))
    i_compute = 5
    symtab += sym(s_compute, (STB_GLOBAL << 4) | STT_FUNC, IDX_TEXT,
                  COMPUTE_OFF, len(compute_code))
    NSYM = 6

    # ------------------------------------------------------------- relocations
    # 24-byte Elf64_Rela: offset(8) info(8) addend(8, SIGNED)
    def rela(off, symidx, rtype, addend):
        return struct.pack('<QQq', off, (symidx << 32) | rtype, addend)

    # Both calls are 5-byte `e8 rel32`, so the displacement is measured from the
    # END of the instruction: the addend is -4.  The addend LIVES HERE, in the
    # record -- the four bytes in .text are left at zero.
    rela_text = (rela(START_CALL_FIELD, i_compute, R_X86_64_PC32, -4) +
                 rela(COMPUTE_CALL_FIELD, i_helper, R_X86_64_PLT32, -4))
    rela_data = rela(DATA_ABS_FIELD, i_answer, R_X86_64_64, 0)

    # ------------------------------------------------------------- layout
    bodies = [text, data, rela_text, rela_data, symtab,
              bytes(strtab.b), bytes(shstrtab.b)]
    offsets = []
    cur = 64                                # the ELF header comes first
    for b in bodies:
        # keep every section 8-byte aligned; nothing here requires it, but a
        # real producer does it and it makes the layout easier to eyeball
        while cur % 8 != 0:
            cur += 1
        offsets.append(cur)
        cur += len(b)
    shoff = cur
    while shoff % 8 != 0:
        shoff += 1

    # ---------------------------------------------------------- ELF header
    e_ident = bytes([0x7f]) + b'ELF' + bytes([
        2,      # EI_CLASS = ELFCLASS64
        1,      # EI_DATA  = ELFDATA2LSB
        1,      # EI_VERSION
        0,      # EI_OSABI = SYSV
        0, 0, 0, 0, 0, 0, 0, 0,   # EI_ABIVERSION + 8 bytes of padding
    ])
    assert len(e_ident) == EI_NIDENT
    ehdr = e_ident + struct.pack(
        '<HHIQQQIHHHHHH',
        ET_REL,          # e_type
        EM_X86_64,       # e_machine
        EV_CURRENT,      # e_version
        0,               # e_entry      -- meaningless in a relocatable file
        0,               # e_phoff      -- there are NO program headers
        shoff,           # e_shoff
        0,               # e_flags
        64,              # e_ehsize
        0,               # e_phentsize
        0,               # e_phnum
        64,              # e_shentsize
        8,               # e_shnum  (index 0 is the null section)
        7,               # e_shstrndx
    )
    assert len(ehdr) == 64, len(ehdr)

    # ------------------------------------------------------ section headers
    def shdr(name, stype, flags, addr, off, size, link=0, info=0,
             align=1, entsize=0):
        return struct.pack('<IIQQQQIIQQ', name, stype, flags, addr, off,
                           size, link, info, align, entsize)

    sh_null = shdr(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    sh_text = shdr(sh['text'], SHT_PROGBITS, SHF_ALLOC | SHF_EXECINSTR,
                   0, offsets[0], len(text), 0, 0, 16, 0)
    sh_data = shdr(sh['data'], SHT_PROGBITS, SHF_ALLOC | SHF_WRITE,
                   0, offsets[1], len(data), 0, 0, 8, 0)
    # A relocation section's sh_link is the SYMTAB it indexes, and its sh_info
    # is the section the offsets are relative TO. Getting these backwards is
    # the classic hand-rolled-ELF bug: the file still parses, and every
    # relocation then resolves against the wrong thing.
    sh_rela_text = shdr(sh['rela_text'], SHT_RELA, 0, 0, offsets[2],
                        len(rela_text), IDX_SYMTAB, IDX_TEXT, 8, 24)
    sh_rela_data = shdr(sh['rela_data'], SHT_RELA, 0, 0, offsets[3],
                        len(rela_data), IDX_SYMTAB, IDX_DATA, 8, 24)
    # A symtab's sh_link is the string table, and its sh_info is the index of
    # the first symbol whose binding is not LOCAL.
    sh_symtab = shdr(sh['symtab'], SHT_SYMTAB, 0, 0, offsets[4], len(symtab),
                     IDX_STRTAB, 1, 8, 24)
    sh_strtab = shdr(sh['strtab'], SHT_STRTAB, 0, 0, offsets[5], len(strtab.b),
                     0, 0, 1, 0)
    sh_shstrtab = shdr(sh['shstrtab'], SHT_STRTAB, 0, 0, offsets[6],
                       len(shstrtab.b), 0, 0, 1, 0)

    shdrs = (sh_null + sh_text + sh_data + sh_rela_text + sh_rela_data +
             sh_symtab + sh_strtab + sh_shstrtab)
    assert len(shdrs) == 8 * 64

    # ------------------------------------------------------------- assemble
    img = bytearray(shoff)
    img[0:64] = ehdr
    for b, o in zip(bodies, offsets):
        img[o:o + len(b)] = b
    img += shdrs
    # the gap between the last body and shoff must be zero; bytearray() is
    data = bytes(img)

    with open(path, 'wb') as fh:
        fh.write(data)

    out.write('wrote %s  (%d bytes)\n' % (path, len(data)))
    out.write('  ELF header      0x%04x .. 0x%04x\n' % (0, 64))
    for name, b, o in zip(
            ['.text', '.data', '.rela.text', '.rela.data', '.symtab',
             '.strtab', '.shstrtab'], bodies, offsets):
        out.write('  %-12s   0x%04x .. 0x%04x  (%d bytes)\n'
                  % (name, o, o + len(b), len(b)))
    out.write('  section headers 0x%04x .. 0x%04x  (%d x 64)\n'
              % (shoff, shoff + len(shdrs), 8))
    out.write('  e_phnum = 0   (no program headers: this is a relocatable file)\n')
    out.write('  relocation addends are in the RECORDS, not in the bytes\n')
    return data


if __name__ == '__main__':
    emit(sys.argv[1] if len(sys.argv) > 1 else 'hand.o')
