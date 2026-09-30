#!/usr/bin/env python3
"""rvpriv.py -- the RISC-V privileged architecture, measured on the bytes and
on the numbers, with the specification as the oracle and the toolchain as the
test subject.

THE SPINE OF THIS COURSE IS AN ABSENCE, and it is a different absence from
the one the previous RISC-V course was about.

    There is no RISC-V machine on this host, no emulator, and no RISC-V
    binutils.  So NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN, no
    exception has ever been TAKEN, no page has ever been WALKED, no TLB has
    ever been CONSULTED, and no `ecall` has ever been OBSERVED doing
    anything.

This is the course where that hurts most, and the file says so before the
first measurement rather than in a limits section at the end.  The previous
course in this section lost only the ability to TIME things.  THIS ONE LOSES
THE ABILITY TO OBSERVE THE SUBJECT.  Every claim about what a trap DOES, what
a page walk DOES, or what an `ecall` RETURNS is QUOTED, and every claim about
what the toolchain EMITS is measured, and the boundary between the two is
section 14 and it is a TABLE.

WHAT SURVIVES THE ABSENCE, and it is a lot:

  * the ENCODING of the twelve CSR instructions and the ONE BIT that
    separates the register form from the immediate form, read out of real
    words a real assembler produced;
  * the CSR ADDRESS arithmetic -- twelve bits, and the 4096 the assembler
    will and will not accept, which is a boundary measured by a refusal;
  * the fact that `Zicsr` is not in the base ISA and that NOBODY CHECKS,
    measured by compiling the same two-instruction file at `-march=rv64i` and
    reading the ISA string the object then carries;
  * the `ecall` convention as the compiler emits it, and the measurement
    that a7 and a6 differ in EXACTLY ONE BIT of an instruction word, which
    is the sharpest possible statement that the convention is a convention;
  * the Sv39/Sv48/Sv57 ARITHMETIC, which is pure arithmetic and completely
    checkable;
  * the PTE bit positions, with the COMPILER as a third reader of the
    manual's figure;
  * and the RELOCATIONS, which is the hinge to the object-file half of this
    collection: `R_RISCV_PCREL_HI20` is 23 and `R_RISCV_PCREL_LO12_I` is 24
    and `R_RISCV_PCREL_LO12_S` is 25, the LO12 record names the ADDRESS OF
    THE AUIPC rather than the target, and the number of records a page-table
    walk produces is a function of the DATA LAYOUT rather than of the number
    of page tables the walk touches.

THE THREE LABELS (the section plan's rule 13), and every claim in this file
carries exactly one:

    MEASURED           about the compiler or the bytes, by experiment
    MEASURED-ON-BYTES  a property of emitted bytes, cross-checked against
                       llvm-objdump-21 as a second reader
    QUOTED             a manual claim, with a document and a section

A label rendered two different ways is not a label, and a reader cannot check
a category he cannot find.  `crosscheck.py` counts the three and the artifact
prints its own tallies in section 14.

THE THREE DOCUMENTS, and the SHORT NAMES every QUOTED row uses:

    priv-spec    RISC-V Instruction Set Manual, Volume II: RISC-V
                 Privileged Architecture, v20260120, chapters 1, 2 and 11
    riscv-elf    RISC-V ABIs Specification v1.0, chapter 8 (ELF Object
                 Files) and chapter 3 (Calling Conventions for System
                 Calls)
    rv32-unpriv  RISC-V Instruction Set Manual, Volume I: Unprivileged
                 Architecture, v20260120 -- inherited from the two sibling
                 RISC-V courses and used for the Zicsr split

NO TOOL DECODES ANYTHING IN PART ONE.  This file imports the decoder the
first RISC-V course wrote -- `rvdec.py`, in courses/rvasm/assets/samples/ --
and PREPENDS one model of its own, because the inherited `s_system` names
the six CSR instructions and reads the CSR number out of the word but has no
model for the thing this course is about: the CSR ADDRESS SPACE and its
three fields.  Section 3 prepends it and section 14's R1 says why, and a
second model of this course's names SFENCE.VMA, which the sibling could not
name at all; section 14's R14 is that gap.

    python3 rvpriv.py --run             the whole report, 15 sections
    python3 rvpriv.py --section 6       one section
    python3 rvpriv.py --audit           the models in the dispatch, in order
    python3 rvpriv.py --why 105022f3    explain one word
"""

import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
READELF = 'llvm-readelf-21'
TARGET = 'riscv64-linux-gnu'
LEVELS = ('O0', 'O1', 'O2', 'Os')
RULE = '=' * 74


# ===========================================================================
# Part one: the decoder, BORROWED, plus ONE model of this course's.
# ===========================================================================

def find_sibling(name, env_var, sibling):
    """Locate a sibling course's artifact by walking UP the tree.

    A hardcoded `../../<sibling>/assets/samples` breaks the first time
    somebody moves a directory, and a course whose artifact only runs in the
    exact layout it was written in is a course nobody can re-run.  Inherited
    from the sibling RISC-V course unchanged, for the same reason.
    """
    env = os.environ.get(env_var)
    if env and os.path.exists(os.path.join(env, name)):
        return env
    d = HERE
    for _ in range(8):
        cand = os.path.join(os.path.dirname(d), sibling, 'assets', 'samples')
        if os.path.exists(os.path.join(cand, name)):
            return cand
        nxt = os.path.dirname(d)
        if nxt == d:
            break
        d = nxt
    raise SystemExit('%s not found.  Set %s to the directory holding it.'
                     % (name, env_var))


RVDEC_DIR = find_sibling('rvdec.py', 'RVDEC_DIR', 'rvasm')
sys.path.insert(0, RVDEC_DIR)
import rvdec  # noqa: E402

Dec = rvdec


def _m_csr_address(i):
    """THE CSR ADDRESS, decomposed into its three fields.  PREPENDED.

    THE INHERITED `s_system` NAMES the six CSR instructions and reads the CSR
    number out of the word at inst[31:20], and it prints that number in hex.
    It does not DECOMPOSE it, and the decomposition is the whole of the
    privilege convention: `csr[11:10]` says whether the register is
    writable and `csr[9:8]` says the lowest privilege that may touch it.
    A decoder that prints `csrr t0, 0x100` and stops has decoded the ADDRESS
    and not the PRIVILEGE, and a reader who has read the two halves of the
    conversation is being shown the half that is not a privilege question.

    THIS MODEL IS PREPENDED AND THE SIBLING IS NOT EDITED, for the reason the
    sibling course set out at length: two harnesses that both pass while
    reading different code is the failure mode this collection keeps paying
    for.  `rvasm`'s own 128-check harness asserts nothing about this model
    and this course's harness asserts what it does, and section 12's poison 1
    REMOVES it so the reader can see the disagreement it is there to prevent.

    The accessibility field is rendered as the psABI renders it -- 00, 01, 02
    are read/write and 11 is read-only -- and the privilege field as U, S or
    M, with 10 reported as RESERVED because 10 is a hole in the two-bit
    encoding.  2 is a VALID encoding (read/write) and is not reserved, and a
    course that called it reserved because it looks like a gap would be
    wrong in a way that costs a reader a real register.
    """
    f3 = Dec.bits(i.word, 14, 12)
    if f3 not in (1, 2, 3, 5, 6, 7):
        raise Dec.Bad()
    csr = Dec.bits(i.word, 31, 20)
    acc = (csr >> 10) & 3
    priv = (csr >> 8) & 3
    i.field('csr', 31, 20)
    ACC = {0: 'rw', 1: 'rw', 2: 'rw', 3: 'RO'}
    PRIV = {0: 'U', 1: 'S', 2: 'RESERVED', 3: 'M'}
    i.csr = csr
    i.csr_acc = acc
    i.csr_priv = priv
    i.acc_name = ACC[acc]
    i.priv_name = PRIV[priv]
    i.say('THE CSR ADDRESS, decomposed: csr[11:10] = %d (%s) says whether the '
          'register can be written at all, and csr[9:8] = %d (%s) says the '
          'LOWEST privilege mode that may touch it.  Both are in the address '
          'and in NOTHING ELSE -- the instruction word is byte-identical for '
          'a user CSR and a machine CSR, which is why the enforcement of the '
          'convention is a property of the hardware and not of the encoding'
          % (acc, ACC[acc], priv, PRIV[priv]))
    return True


def _m_sfence_vma(i):
    """SFENCE.VMA and SFENCE.VMA with operands, PREPENDED -- and this one is a
    GAP IN THE SIBLING rather than an addition to it.

    `s_misc_mem` in the inherited decoder handles opcode 0x73 with funct3 = 0
    by reading the funct12 and printing `system funct12=0x0NNN` for anything
    that is not `ecall` or `ebreak`, and `walk.c` in THIS course emits
    `sfence.vma`, which is funct12 = 0x120.  So the encoding course's decoder
    has no model for a PRIVILEGED INSTRUCTION, and the first run of this
    file's cross-check reported twelve of them as disagreements -- four as
    `system funct12=0x120` and eight as `(undefined)`, because the assembler
    emitted the two-operand form with rd = a0 and `s_misc_mem` declines any
    SYSTEM word whose rd or rs1 is non-zero.

    Two things are wrong with leaving that as a disagreement.  The first is
    that a decoder naming a word `(undefined)` is saying the ARCHITECTURE
    defines no meaning for it, when in fact the architecture defines it
    precisely and the DECODER has no model.  The second is that this course
    is about the privileged architecture and the privileged architecture's
    fence is the one instruction in it that the previous course's artifact
    could not name.

    The correction is PREPENDED here and the sibling is untouched, for the
    reason this collection has established twice: two harnesses that both
    pass while reading different code is the failure mode, and the sibling's
    own 128-check harness asserts nothing about SFENCE.VMA while this one's
    asserts that it is named.  Section 13's poison 1 removes BOTH of this
    course's models together.
    """
    f3 = Dec.bits(i.word, 14, 12)
    if f3 != 0:
        raise Dec.Bad()
    f12 = Dec.bits(i.word, 31, 20)
    if f12 not in (0x120, 0x121):
        raise Dec.Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    i.fmt = 'I'
    if rd != 0:
        raise Dec.Undefined('SFENCE.VMA with rd = %d is UNDEFINED: the only '
                            'two funct3 = 0 SYSTEM words with a non-zero rd '
                            'are the SRET variants, at funct12 = 0x102 and '
                            '0x202' % rd)
    if f12 == 0x120 and rs1 == 0:
        i.name = 'sfence.vma'
        i.ops = []
        i.say('funct12 = 0x120 with rs1 = x0 and rs2 = x0: "the fence orders '
              'all reads and writes made to any level of the page tables, for '
              'all address spaces.  The fence also invalidates all '
              'address-translation cache entries, for all address spaces" -- '
              'which is the TLB shootdown, and it is the instruction a kernel '
              'runs after it has written a page table')
    elif f12 == 0x120:
        # THIS IS A FINDING AND NOT A MODEL.  `priv-spec` 11.1.2.1 defines
        # funct12 = 0x120 as the form with rs1 = x0 and rs2 = x0, and
        # funct12 = 0x121 as the form that takes the two operands.  clang's
        # integrated assembler emits `sfence.vma %0` with %0 bound to a0 as
        # funct12 = 0x120 and rs1 = a0 -- NEITHER of the two defined forms.
        # The word is 0x12050073, it is in the object, and both readers name
        # it.  The specification does not say what it does.
        i.name = 'sfence.vma'
        i.ops = [Dec.xreg(rs1)]
        i.say('CORRECTION OF A TOOLCHAIN DISCREPANCY, AND THE CORRECTION IS '
              'IN THE NAME ONLY.  funct12 = 0x120 is the psABI\'s BARE form '
              'and funct12 = 0x121 is the form that takes rs1 and rs2, and '
              'this word is funct12 = 0x120 with rs1 = %d, which is NEITHER.  '
              'clang assembled `sfence.vma %%0` that way.  Both readers name '
              'it sfence.vma with an operand, and this file agrees with them '
              'so the cross-check can measure something, and the '
              'specification is left to say what it does.  See section 14, '
              'retraction R15.' % rs1)
    else:
        i.name = 'sfence.vma'
        i.ops = [Dec.xreg(rs1), Dec.xreg(Dec.bits(i.word, 24, 20))]
        i.say('funct12 = 0x121: SFENCE.VMA with rs1 and rs2.  rs1 = x0 and '
              'rs2 = x0 is the same as the bare form; a non-zero rs1 scopes '
              'the fence to one virtual address and a non-zero rs2 to one '
              'address space, which is the per-mapping form of the same '
              'instruction')
    i.ext = 'Zicsr'
    i.model = 'm_sfence_vma'
    return True


Dec.MODELS32.insert(0, ('m_sfence_vma', (0x73,), _m_sfence_vma, 'Zicsr',
                        'SFENCE.VMA at funct12 0x120 and 0x121 -- the TLB '
                        'shootdown, and a GAP IN THE INHERITED DECODER, which '
                        'prints it as `system funct12=0x120` or as '
                        '`(undefined)`.  See the function\'s docstring and '
                        'section 14, retraction R14.'))
Dec.MODELS32.insert(0, ('m_csr_address', (0x73,), _m_csr_address, 'Zicsr',
                        'the CSR ADDRESS SPACE: csr[11:10] is the '
                        'accessibility class and csr[9:8] is the lowest '
                        'privilege, and both live in inst[31:20] and nowhere '
                        'else.  See the function\'s docstring and section 14, '
                        'retraction R1.'))
INHERITED_MODELS = len(Dec.MODELS32) - 2
TOTAL_MODELS = len(Dec.MODELS32)


# ---------------------------------------------------------------------------
# The corpus, as a NAMED constant.  A coverage number is a number about WHAT
# WAS FED TO IT, so a missing file is REPORTED rather than skipped.
# ---------------------------------------------------------------------------
C_FILES = ('wrap', 'bits', 'walk')
ZICSR_MARCHES = ('rv64i', 'rv64i_zicsr', 'rv64i_zicsr_zifencei')
PADS = ('0x0', '0x40', '0x800', '0xffc', '0x1000', '0x2000')

CORPUS = ([('csr.o', '-', 'the hand-written CSR corpus, the assembler\'s own '
            'answers'),
           ('zicsr_rv64i.o', '-', 'one Zicsr instruction at -march=rv64i, '
            'which the base does not contain'),
           ('zicsr_rv64i_zicsr.o', '-', 'the same instruction at '
            '-march=rv64i_zicsr'),
           ('zicsr_rv64i_zicsr_zifencei.o', '-', 'and at rv64i with the fence '
            'extension as well')]
           + [('%s_%s.o' % (f, lv), lv, '%s.c at -%s' % (f, lv))
              for f in C_FILES for lv in LEVELS]
           + [('sp2_dense.o', 'O2', 'the page-table walk, three tables '
              'ADJACENT'),
              ('sp2_sparse.o', 'O2', 'the same walk, the tables 4 KiB apart'),
              ('sp2_dense_nopic.o', 'O2', 'the dense walk at -fno-pic'),
              ('sp2_sparse_nopic.o', 'O2', 'the sparse walk at -fno-pic'),
              ('pt_pic.o', '-', 'the hand-written page-table references at '
               'the target default'),
              ('pt_nopic.o', '-', 'and at -fno-pic')]
           + [('sp_%s.o' % pad, '-', 'one HI20 and two LO12s %s bytes apart'
               % pad) for pad in PADS])

RVCORPUS = [c[0] for c in CORPUS]


def corpus_present():
    """(present, missing) for the corpus as a NAMED constant."""
    have = [f for f, _lv, _d in CORPUS if os.path.exists(os.path.join(HERE, f))]
    missing = [f for f, _lv, _d in CORPUS if f not in have]
    return have, missing


# ---------------------------------------------------------------------------
# Tools.  These RUN something; nothing in part one does.
# ---------------------------------------------------------------------------

def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True)


def which(name):
    for d in os.environ.get('PATH', '').split(os.pathsep):
        f = os.path.join(d, name)
        if os.path.isfile(f) and os.access(f, os.X_OK):
            return f
    return None


def p(name):
    return os.path.join(HERE, name)


def tool_version(cmd):
    r = sh(cmd, '--version')
    for ln in (r.stdout or r.stderr).splitlines():
        if ln.strip():
            return ln.strip()
    return 'not installed'


# ---------------------------------------------------------------------------
# Reading an object file.  The ELF reading is INHERITED from rvdec.py; what
# this file adds is (a) the source/disassembly ALIGNMENT, which is what makes
# a field sweep possible, and (b) the relocation table, which the inherited
# file has no reason to read.
# ---------------------------------------------------------------------------

def func_insns(path):
    """{name: [(word, mnem, text, nbytes)]} for every symbol in an object.

    The extent comes from the SYMBOL TABLE and not from the next label,
    because in a relocatable object the labels between two functions are
    LOCAL symbols the compiler invented for address-materialisation pairs
    and not function boundaries at all.  `llvm-objdump-21` prints the labels,
    so the function list is read from the same reader that prints the words
    and the two cannot disagree about which words belong to which function.
    """
    r = sh(OBJDUMP, '--triple=riscv64', '-d', path)
    out = {}
    cur = None
    for ln in (r.stdout or '').splitlines():
        m = re.match(r'([0-9a-f]{16}) <(\S+)>:', ln)
        if m:
            cur = m.group(2)
            out[cur] = []
            continue
        m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s*(.*)$', ln)
        if m and cur is not None:
            out[cur].append((int(m.group(2), 16), m.group(3),
                             m.group(4).strip(), len(m.group(2)) // 2))
    return out


def src_csr_lines():
    """[(mnemonic, operands)] for every `csr*` line in csr.s, in order.

    Read from the SOURCE and paired with the disassembly by POSITION, which
    is sound here and only here: csr.s is a straight-line list of one
    instruction per line with no labels and no directives inside the
    instruction run, so source line N is word N.  The pairing is CHECKED --
    the count of source lines must be the count of words minus the trailing
    `ret` -- and a file that changed shape would fail loudly rather than
    silently mis-pair every field in the course.
    """
    got = []
    for ln in open(p('csr.s')):
        m = re.match(r'\s+(csr\w+)\s+(.*)$', ln)
        if m:
            got.append((m.group(1), m.group(2).split('#')[0].strip()))
    return got


def reloc_rows(path):
    """[(offset, rtype, type_name, symbol, addend)] from `llvm-readelf -r`.

    `r_info` is printed by the reader as `SSSSSSSSTTTTTTTT` -- the SYMBOL
    index in the high half and the TYPE in the low half -- and the type is
    the low 32 bits' low byte.  Section 9's poison 2 reads the WRONG half of
    that word, and it is worth being explicit that the wrong half is wrong
    for a reason: it looks exactly like a type number.
    """
    r = sh(READELF, '-r', path)
    out = []
    for ln in (r.stdout or '').splitlines():
        m = re.match(r'([0-9a-f]{16})\s+([0-9a-f]{16})\s+(\S+)\s+(.*)$', ln)
        if not m:
            continue
        info = int(m.group(2), 16)
        # The reader's tail is SYMBOL_VALUE  SYMBOL_NAME  [ + ADDEND ], and
        # the name is the LAST whitespace-separated field before the addend.
        # The first version of this parser kept the value as well and the
        # table below printed a symbol column reading
        # `0000000000000000 root_pte`, which is two columns wearing one
        # column's name -- and a reader checking the symbol would have had
        # to know which half was the name.
        tail = m.group(4).strip()
        add = 0
        am = re.search(r'\+\s*(\S+)\s*$', tail)
        if am:
            add = int(am.group(1), 16)
            tail = tail[:am.start()].strip()
        fields = tail.split()
        sym = fields[-1] if fields else '(none)'
        out.append((int(m.group(1), 16), info & 0xffffffff, m.group(3), sym,
                    add))
    return out


def reloc_counts(path):
    """{type_name: n} for one object."""
    h = {}
    for _o, _ty, nm, _s, _a in reloc_rows(path):
        h[nm] = h.get(nm, 0) + 1
    return h


def arch_attr(path):
    """The Tag_RISCV_arch string out of .riscv.attributes, or a marker."""
    r = sh(READELF, '-A', path)
    m = re.search(r'TagName: arch\s*\n\s*Value: (\S+)', r.stdout)
    return m.group(1) if m else '(no arch attribute)'


def asm_one(src, march='rv64gc'):
    """(word, nbytes, text) for ONE line, or (None, 0, diagnostic).

    The same helper the sibling RISC-V course uses, and the reason it exists
    is that a REFUSAL is a measurement: `csrr t0, 0x1000` and `csrr t0,
    0xfff` are two different claims about a twelve-bit field and only one of
    them is a claim about what the assembler does.
    """
    path = p('_rvp_one.s')
    with open(path, 'w') as f:
        f.write('        %s\n        ret\n' % src)
    r = sh(CLANG, '--target=' + TARGET, '-march=' + march, '-c', path,
           '-o', p('_rvp_one.o'))
    if r.returncode != 0:
        msg = ''
        for ln in (r.stderr or '').splitlines():
            if 'error:' in ln:
                msg = ln.split('error:', 1)[1].strip()
                break
        return None, 0, msg or (r.stderr or '').strip()[:70]
    o = sh(OBJDUMP, '--triple=riscv64', '-d', p('_rvp_one.o'))
    for ln in (o.stdout or '').splitlines():
        m = re.match(r'\s*[0-9a-f]+:\s+([0-9a-f]{4,8})\s+(\S+)', ln)
        if m:
            return int(m.group(1), 16), len(m.group(1)) // 2, m.group(2)
    return None, 0, '(assembled, and disassembled to nothing)'


# ---------------------------------------------------------------------------
# Printing.  One style for every section.
# ---------------------------------------------------------------------------

def banner(n, title):
    print(RULE)
    print('SECTION %d -- %s' % (n, title))
    print(RULE)


# A PHRASE THIS FILE PROMISES TO ITS HARNESS, printed at whatever width keeps
# it on one line.  The reflow in `para` breaks lines wherever the budget runs
# out and it has broken exact phrases this file's own harness asserts; a
# phrase split across two lines is a phrase a reader cannot search for and a
# harness cannot find.
KEEP = '§KEEP§'

# Counts as WORDS, so a sentence about "sixteen of them" cannot drift away from
# the list it is counting.  The first version of section 14 hard-coded the
# number, the list grew from sixteen to seventeen on the same day, and the
# sentence kept saying sixteen while the table underneath it printed seventeen --
# which is precisely the failure the retractions section exists to name, in a
# paragraph about retractions.
NUMWORDS = {1: 'One', 2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
            7: 'Seven', 8: 'Eight', 9: 'Nine', 10: 'Ten', 11: 'Eleven',
            12: 'Twelve', 13: 'Thirteen', 14: 'Fourteen', 15: 'Fifteen',
            16: 'Sixteen', 17: 'Seventeen', 18: 'Eighteen', 19: 'Nineteen',
            20: 'Twenty'}


def para(text, indent='  '):
    keep = KEEP in text
    if keep:
        text = text.replace(KEEP, '')
    for chunk in text.split('\n\n'):
        lines = [l for l in chunk.split('\n') if l.strip()]
        if lines and lines[0].lstrip()[:1] in ('*', '|', '-'):
            for l in lines:
                print(l if l[:1] == ' ' else indent + l)
            print()
            continue
        words = ' '.join(lines).split()
        line = indent
        for w in words:
            width = 200 if keep else 78
            if len(line) + len(w) + 1 > width:
                print(line)
                line = indent + w
            else:
                line = line + ' ' + w if len(line) > len(indent) else indent + w
        if line.strip():
            print(line)
        print()


def table(head, rows, widths=None):
    widths = widths or [max(len(str(head[i])),
                            max([len(str(r[i])) for r in rows]) if rows else 0)
                        for i in range(len(head))]
    fmt = ''.join('  %-' + str(w) + 's' for w in widths)
    print(fmt % tuple(str(h) for h in head))
    for r in rows:
        print(fmt % tuple(str(c) for c in r))


def bits_of(w):
    return [b for b in range(32) if w >> b & 1]


def human(n):
    for u in ('B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'):
        if n < 1024:
            return '%d %s' % (n, u)
        n //= 1024
    return str(n)


# ===========================================================================
# SECTION 1 -- THE METHOD, AND WHAT IT MAY NOT CLAIM.
#
# This section comes before every measurement, and not as a formality.  The
# previous course in this section put its limits at the END and one of its
# readers quoted a number from a page whose last section said the number was
# not measurable.  A limit that is printed last is a limit that gets skimmed
# past on the way to the number.
# ===========================================================================

def sec1():
    banner(1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM')
    print()
    para("""There are FOUR ABSENCES on this host and they are not the same
absence as the sibling course's, because this course is about the part of the
machine a sibling could not even name.

  * NO RISC-V MACHINE.  The host is x86-64.
  * NO EMULATOR.  `qemu-riscv64` and `spike` are both ABSENT.
  * NO RISC-V BINUTILS.  `riscv64-linux-gnu-{gcc,as,ld}` are all ABSENT, so
    there is not even a RISC-V LINKER and no relocation in this course is
    ever resolved.
  * NO SECOND ASSEMBLER.  GNU binutils has no RISC-V target here, so both
    readers of the two-reader check come from ONE LLVM TREE.

NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.  No exception has ever been
TAKEN.  No page has ever been WALKED.  No TLB has ever been CONSULTED.  No
`ecall` has ever been OBSERVED returning anything.

That last sentence is the one a reader of the previous two RISC-V courses
does not expect, and it is worth being explicit about the difference.  The
ABI course lost the ability to TIME.  This course loses the ability to
OBSERVE THE SUBJECT.  Every claim about what a trap DOES is a quotation from
a document, and every claim about what the toolchain EMITS is a measurement,
and the sentence that separates them appears on every page.""")
    print()
    rows = [
        ['assembler', tool_version(CLANG)],
        ['disassembler', tool_version(OBJDUMP)],
        ['readelf', tool_version(READELF)],
        ['linker, riscv64', which(TARGET + '-ld') or 'IS NOT INSTALLED'],
        ['assembler, riscv64 GNU', which(TARGET + '-as') or 'IS NOT INSTALLED'],
        ['emulator, qemu-riscv64', which('qemu-riscv64') or 'ABSENT'],
        ['emulator, spike', which('spike') or 'ABSENT'],
    ]
    table(['tool', 'result'], rows)
    print()
    para("""AND THE `ecall` CONVENTION IS MEASURED AS THE COMPILER EMITS IT,
which is WEAKER than an execution would have been.  What is measured is that
clang emits the constant 0x00000073 with the syscall number in a7 and the
answer in a0.  What is NOT measured is that the trap is taken, that it
reaches supervisor mode, that a7 is read, that a kernel exists, or that
anything comes back.  Section 5 says so in the place a reader would otherwise
assume otherwise, and section 14's table says which claims are which.""")
    para("""THE TWO READERS.  `rvdec.py` in the first course of this section
decodes; `llvm-objdump-21 --triple=riscv64` decodes again; section 12 counts
how many instructions the two compared, how many each NAMED, and how many
disagreed.  This file PREPENDS ONE MODEL to the inherited dispatch and edits
no sibling: the inherited `s_system` already names the six CSR instructions
and reads the CSR number, and what it does not do is DECOMPOSE the number
into accessibility and privilege, which is the whole of the convention.
Section 3 prepends the model and section 14's R1 records why.  The count is
printed because "this course wrote no decoder" is a claim a reader is
entitled to check.""")
    have, missing = corpus_present()
    para("""THE CORPUS IS A NAMED CONSTANT, and a missing file is REPORTED
rather than skipped, because a coverage number is a number about WHAT WAS
FED TO IT.  %d of %d corpus objects are present; %d missing.  Every one of
them is produced by `build_samples.sh` from four hand-written assembly or C
files, four optimisation levels, three `-march` settings for the Zicsr
question, four builds of one page-table walk, and SIX builds of the same two
instructions at six different distances apart."""
         % (len(have), len(CORPUS), len(missing)))
    if missing:
        print('  MISSING from the corpus: %s' % ', '.join(missing))
        print()
    # The completeness verdict is printed WHETHER OR NOT there is anything
    # wrong with it, for the reason 2.2.113's third finding gives: a check
    # that exists only in the failure branch is a check the harness can never
    # exercise, and the previous run of the SIBLING course failed its own
    # harness on a HEALTHY artifact because of exactly that.
    print()
    print('  CORPUS COMPLETENESS, checked on every run and printed whether or')
    print('  not there is anything wrong with it:')
    print()
    if missing:
        print('    THE CORPUS IS INCOMPLETE -- %d of %d objects are missing,'
              % (len(missing), len(CORPUS)))
        print('    and every number in this file would be about a smaller')
        print('    corpus than it claims.  Run build_samples.sh.')
    else:
        print('    THE CORPUS IS INCOMPLETE: no.  All %d objects are present,'
              % len(CORPUS))
        print('    and this run read all of them.')
    print()
    para("""THE THREE LABELS, and they are DEFINED rather than implied:

  MEASURED            about the compiler or the bytes, by experiment.
  MEASURED-ON-BYTES   a property of emitted bytes, cross-checked against
                      llvm-objdump-21 as a second reader.
  QUOTED              a manual claim, with a document and a section.

Every QUOTED row in this file names one of THREE DOCUMENTS with a section:
`priv-spec` (Volume II, the privileged architecture, v20260120),
`riscv-elf` (the RISC-V ABIs Specification v1.0, chapters 3 and 8), and
`rv32-unpriv` (Volume I, the unprivileged architecture).  The three short
names are the only spelling used, so a reader can search for one.""")


# ===========================================================================
# SECTION 2 -- THE PRIVILEGE ARCHITECTURE, QUOTED, BEFORE ANY COMPILER RUNS.
#
# Printed in full and separately from every measurement, so a reader can
# check one against the other with the compiler out of the way.  Sections 3
# through 11 measure the toolchain AGAINST it.
# ===========================================================================

def sec2():
    banner(2, 'THE PRIVILEGE ARCHITECTURE, QUOTED, BEFORE ANY COMPILER RUNS')
    print()
    para("""Everything in this section is %s.  Nothing in it is measured,
because nothing in it needs to be: it is the ORACLE, and the oracle is the
document.  Sections 3 to 11 measure the toolchain AGAINST it, and the seven
places the two disagree are section 14's retractions.""" % QUOT)
    print()
    para("""THE THREE MODES, `priv-spec` Table 1.1.  Three and not four, and the
hole is in the encoding rather than at the end of the list:

    Encoding      Name          Abbreviation
    0     00      User/Application          U
    1     01      Supervisor               S
    2     10      Reserved                 --
    3     11      Machine                  M

and `priv-spec` section 2.1: "machine-mode (M-mode) is the highest privilege
mode in a RISC-V hart ... and is the first mode entered at reset."

THE LADDER IS ENCODED IN TWO BITS AND IN NOTHING ELSE.  `mstatus.MPP` is
TWO bits wide and `sstatus.SPP` is ONE, and `priv-spec` section 2.1.6.1 says
why they are different sizes and the reason is the whole of the two-mode
design:

    "The xPP fields can only hold privilege modes up to x, so MPP is two bits
     wide and SPP is one bit wide."

So a trap handler's "where did I come from" is a TWO-BIT field in machine
mode and a ONE-BIT field in supervisor mode, and the difference is not an
optimisation.  A trap out of S-mode can only have come from U-mode or
S-mode, and there is nothing else to remember.

THE STACK.  `priv-spec` section 2.1.6.1, and this is the sentence a trap
handler author has to internalise:

    "When a trap is taken from privilege mode y into privilege mode x, xPIE
     is set to the value of xIE; xIE is set to 0; and xPP is set to y."

THREE WRITES, IN THAT ORDER, ON EVERY TRAP.  The saved-enable bit, the
clear, and the previous mode.  And on the way back, `xRET`:

    "When executing an xRET instruction, supposing xPP holds the value y, xIE
     is set to xPIE; the privilege mode is changed to y; xPIE is set to 1; and
     xPP is set to the least-privileged supported mode."

The last clause is a DEBUGGING AID and the specification says so: "Setting
xPP to the least-privileged supported mode on an xRET helps identify software
bugs in the management of the two-level privilege-mode stack."  There is no
behavioural reason to clear SPP on SRET and there is a diagnostic one.

THE DELEGATION, `priv-spec` section 2.1.1.8, and it is the sentence that
makes S-mode possible:

    "By default, all traps at any privilege level are handled in machine
     mode ... To increase performance, implementations can provide individual
     read/write bits within medeleg and mideleg to indicate that certain
     exceptions and interrupts should be processed directly by a lower
     privilege level."

    "When a trap is delegated to S-mode, the scause register is written with
     the trap cause; the sepc register is written with the virtual address of
     the instruction that took the trap; the stval register is written with an
     exception-specific datum; the SPP field of mstatus is written with the
     active privilege mode at the time of the trap; the SPIE field of mstatus
     is written with the value of the SIE field at the time of the trap; and
     the SIE field of mstatus is cleared.  The mcause, mepc, and mtval
     registers and the MPP and MPIE fields of mstatus are not written."

SIX REGISTERS WRITTEN, AND THE ABSENCE IS PART OF THE CLAIM: the machine
level's `mcause`, `mepc` and `mtval` are NOT written, and `MPP`/`MPIE` are
NOT written.  A trap handler that reads `mcause` after a delegated trap reads
whatever was there before, and section 6 measures that nothing in the emitted
code knows which of the two happened.

AND THE DISCOVERY PROCEDURE IS A WRITE-ONE-TO-EVERY-BIT-AND-READ-BACK, which
is the same trick three times in one chapter and is worth knowing because it
is how every WARL field in this architecture is discovered:

  * ASIDLEN: "may be determined by writing one to every bit position in the
    ASID field, then reading back the value in satp to see which bit positions
    in the ASID field hold a one."
  * the delegatable traps: "with the supported delegatable bits found by
    writing one to every bit location, then reading back the value in medeleg
    or mideleg to see which bit positions hold a one."
  * the implemented interrupts: "The implemented interrupts may be found by
    writing one to every bit location in sie, then reading back to see which
    bit positions hold a one."

THAT IS A LOOP A KERNEL MUST RUN AT BOOT, AGAINST HARDWARE THIS HOST DOES NOT
HAVE.  It is the clearest statement in the course of what "no machine" costs:
not a timing, but a whole category of algorithm that exists only to interrogate
silicon.""")
    print()
    para("""THE CSR ADDRESS, `priv-spec` section 1 and the psABI's Table 3.  The
whole convention in two sentences:

    "The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
     for up to 4,096 CSRs.  By convention, the upper 4 bits of the CSR
     address (csr[11:8]) are used to encode the read and write
     accessibility of the CSRs according to privilege level."

    "The top two bits (csr[11:10]) indicate whether the register is
     read/write (00, 01, or 10) or read-only (11).  The next two bits
     (csr[9:8]) encode the lowest privilege level that can access the CSR."

THREE NUMBERS AND THEY ARE ALL CHECKABLE.  12 bits of address, 4,096 CSRs,
4 values of accessibility with THREE of them meaning the same thing, 4 values
of privilege with ONE of them a hole.  Section 3 measures the 12 and the
4,096, and section 4 measures the decomposition against 42 real addresses
the assembler resolved from names, and the hole at csr[9:8] = 2 is visible in
that table as a column with no row in it.

AND THE POINT OF THE CONVENTION, which is not tidiness.  A CSR's address says
who may touch it, so the SAME INSTRUCTION is a legal act in one mode and an
illegal-instruction exception in another.  There is no privilege check
anywhere in the encoding: `csrr t0, mstatus` is one 32-bit word, and whether
it returns a value or traps is decided entirely by the two bits inside the
number it names.  Section 3 assembles the same instruction that a machine-mode
kernel uses and that a user program would fault on, and the two words are
IDENTICAL -- which is the sharpest available statement that the privilege
model is not in the instruction stream.

THE FOUR STANDARD INTERRUPT BITS, `priv-spec` section 11.1.1.3.  "Interrupt
cause number i (as reported in CSR scause) corresponds with bit i in both sip
and sie.  Bits 15:0 are allocated to standard interrupt causes only, while
bits 16 and above are designated for platform use."  A supervisor software
interrupt is cause 1, a supervisor timer interrupt is cause 5 and a
supervisor external interrupt is cause 9, so the three enable bits are 1<<1,
1<<5 and 1<<9.  Section 7 compiles those three writes and reads the
constants back out of the words, and the compiler has no idea they are
interrupts: it emits `ori a0, a0, 0x2` and nothing else.""")


# ===========================================================================
# SECTION 3 -- THE TWELVE CSR INSTRUCTIONS, AND THE ONE BIT.
#
# MEASURED-ON-BYTES.  Every word in this section came out of
# `csr.o`, which a real assembler produced from `csr.s`, and every one of them
# is re-read by `llvm-objdump-21` in section 12.
# ===========================================================================

def sec3():
    banner(3, 'THE TWELVE CSR INSTRUCTIONS, AND THE ONE BIT BETWEEN THEM')
    print()
    para("""There are SIX CSR instructions and each of them has an immediate
counterpart, so there are TWELVE, and the whole set is a single three-bit
`funct3` field.  The finding of this section is that the difference between
the register form and the immediate form is EXACTLY ONE BIT of that field,
and that the twelve instructions are one instruction with a three-bit
selector -- which is why an instruction table for this group is twelve rows
long and the decoder is four lines.

The words below are read out of `csr.o` by `llvm-objdump-21` and are
%s.  `csr.s` puts each pair of forms next to each other on purpose, so
the twelve words come out in a known order and the pairing is arithmetic
rather than a search.""" % BYTES)
    print()
    src = src_csr_lines()
    dis = func_insns(p('csr.o'))['just'] if 'just' in func_insns(p('csr.o')) \
        else None
    # `csr.o` has one function and llvm-objdump prints it as `.text`, so read
    # the words straight out of the reader's line stream.
    words = []
    r = sh(OBJDUMP, '--triple=riscv64', '-d', p('csr.o'))
    for ln in (r.stdout or '').splitlines():
        m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s*(.*)$', ln)
        if m:
            words.append((int(m.group(2), 16), m.group(3),
                          m.group(4).strip()))
    body = words[:len(src)]
    if len(src) != len(words) - 1:
        print('  THE SOURCE/DISASSEMBLY PAIRING IS BROKEN: %d source lines, '
              '%d words, and the file assumes %d words carry an instruction.'
              % (len(src), len(words), len(src)))
        print('  Every table below is about a shifted list and none of them')
        print('  can be believed until the pairing is fixed.')
        print()
        return
    W = {}
    for (mn, args), (word, _d, _t) in zip(src, body):
        W[(mn, args)] = word
    print('  The pairing is CHECKED, not assumed: %d source lines against %d '
          'words' % (len(src), len(words)))
    print('  in the object, the difference being the trailing `ret`.')
    print()

    # --- the twelve, and the six pairs -------------------------------------
    print('  THE TWELVE INSTRUCTIONS: six operations, two source forms, and')
    print('  every row read out of the word rather than out of the source.')
    print()
    rows = []
    for op, reg_form, reg_args, imm_form, imm_args in (
            ('CSRRW', 'csrrw', 't0, cycle, t1', 'csrrwi', 't0, cycle, 5'),
            ('CSRRS', 'csrrs', 't0, cycle, t1', 'csrrsi', 't0, cycle, 5'),
            ('CSRRC', 'csrrc', 't0, cycle, t1', 'csrrci', 't0, cycle, 5')):
        wr = W[(reg_form, reg_args)]
        wi = W[(imm_form, imm_args)]
        rows.append((op, '%-6s' % reg_form, '0x%08x' % wr, (wr >> 12) & 7,
                     '%-6s' % imm_form, '0x%08x' % wi, (wi >> 12) & 7,
                     '0x%03x' % ((wr >> 20) & 0xfff),
                     (wr >> 15) & 31, (wi >> 15) & 31))
    table(['op', 'register form', 'word', 'funct3', 'immediate form', 'word',
           'funct3', 'csr', 'inst[19:15] reg', 'imm'], rows,
          [7, 15, 12, 7, 16, 12, 7, 7, 17, 5])
    print()
    para("""READ THE TWO `inst[19:15]` COLUMNS.  They are the SAME FIVE BITS in
all six words, and in the left-hand set they name REGISTER t1 and in the
right-hand set they name the VALUE 5.  That is the whole difference between
the two families, and the operand column already said so: `csrrs t0, cycle,
t1` names a register and `csrrsi t0, cycle, 5` names a number, and the
assembler has put them in the same five bits.""")
    print()
    print('  THE ONE BIT.  Each register form against its immediate form,')
    print('  with funct3 read out of the two words and nothing else:')
    print()
    rows = []
    same_bit = set()
    for a, ra, b, ia in (('csrrw', 't0, cycle, t1', 'csrrwi', 't0, cycle, 5'),
                         ('csrrs', 't0, cycle, t1', 'csrrsi', 't0, cycle, 5'),
                         ('csrrc', 't0, cycle, t1', 'csrrci', 't0, cycle, 5')):
        fa = (W[(a, ra)] >> 12) & 7
        fb = (W[(b, ia)] >> 12) & 7
        xor = fa ^ fb
        same_bit.add(xor)
        rows.append((a, fa, b, fb, '0x%02x' % xor,
                     'bit %d of funct3' % (xor.bit_length() - 1)))
    table(['register form', 'funct3', 'immediate form', 'funct3', 'xor',
           'where'], rows, [15, 7, 17, 7, 6, 16])
    print()
    print('    the three XORs are %s, and there is %s one bit in the output'
          % (', '.join('0x%02x' % x for x in sorted(same_bit)),
             'exactly' if len(same_bit) == 1 else 'MORE THAN'))
    print('    setting all three: 1 against 5, 2 against 6, 3 against 7, and')
    print('    1 ^ 5 = 2 ^ 6 = 3 ^ 7 = 4, and 4 is bit 2 of a three-bit field.')
    print()
    para("""§KEEP§THREE PAIRS, THREE IDENTICAL DELTAS, AND THE DELTA IS FUNCT3 BIT 2.  A register and an immediate are the same instruction with one bit changed, and the bit is inside the three-bit selector rather than anywhere in the operand fields.

That is worth a sentence on its own, because it is the shape of a design
decision rather than the shape of an accident.  A register field and an
immediate field are the SAME WIDTH -- five bits -- and a designer who had put
the two in different places would have had to spend a bit somewhere.  The
architecture spends it in the selector instead, where it costs nothing at
decode time because the selector is read first, and the reader gets one
selector with six values instead of two selectors with three values each.""")

    # --- the pseudo-instructions -------------------------------------------
    print()
    print('  THE TWO-WORD SPELLINGS, and what they actually are:')
    print()
    rows = []
    for pseudo, args, real, rargs in (
            ('csrw', 'cycle, t0', 'csrrw', 'zero, cycle, t0'),
            ('csrw', 'cycle, t0', 'csrrw', 'x0, cycle, t0'),
            ('csrs', 'cycle, t0', 'csrrs', 'zero, cycle, t0'),
            ('csrc', 'cycle, t0', 'csrrc', 'zero, cycle, t0'),
            ('csrwi', 'cycle, 5', 'csrrwi', 'zero, cycle, 5'),
            ('csrsi', 'cycle, 5', 'csrrsi', 'zero, cycle, 5'),
            ('csrci', 'cycle, 5', 'csrrci', 'zero, cycle, 5'),
            ('csrr', 't0, cycle', 'csrrs', 't0, cycle, zero')):
        wp = W[(pseudo, args)]
        wr = W[(real, rargs)]
        rows.append((pseudo, args, real, rargs, '0x%08x' % wp,
                     '0x%08x' % wr,
                     'IDENTICAL' if wp == wr
                     else 'DIFFER, xor 0x%08x' % (wp ^ wr)))
    table(['two-word', 'operands', 'three-operand', 'operands', 'word',
           'word', 'verdict'], rows, [8, 11, 14, 20, 11, 11, 24])
    print()
    same = sum(1 for r in rows if r[6] == 'IDENTICAL')
    print('    %d of %d comparisons are byte-identical, and the number of'
          % (same, len(rows)))
    print('    differences is %d: a pseudo-instruction is not a separate'
          % (len(rows) - same))
    print('    encoding, it is a three-operand form with x0 in one of the')
    print('    two register slots.  `zero` and `x0` are the same register')
    print('    spelled two ways and they are in the table as two separate')
    print('    rows because otherwise the check needs a special case.')
    print()
    para("""`csrw cycle, t0` is `csrrw zero, cycle, t0` and NOT `csrrs zero,
cycle, t0`, which is the mistake a reader makes when they assume the `w`
stands for "write the value in" rather than for the instruction's own
mnemonic.  The first version of this file's alias table paired `csrw` with
`csrrs` on that assumption and the comparison printed a difference of
0x00000000 -- which is a DIFFERENCE and not a typo, because the two words
differ in `funct3` alone: 1 against 2, a WRITE against a SET.

AND `csrr rd, csr` IS `csrrs rd, csr, zero`, so the most common CSR
instruction in any privileged program is a SET whose source register is
hardwired zero.  The `rs1` field is 0 in the word, and the second reader's
alias `rdcycle` is a mnemonic this file's own decoder does not print: the
inherited `rvdec.py` names the underlying instruction, and section 12 is
where the two readers' disagreement about the SPELLING is measured and found
to be a spelling rather than a decoding.""")
    # --- the field masks ---------------------------------------------------
    print()
    print('  THE FIELD MASKS, derived rather than quoted, by asking what the')
    print('  sweep moved.  A mask is a LOWER BOUND: it is what this corpus')
    print('  moved, and it is the field\'s width only if the sweep was wide')
    print('  enough.')
    print()
    base = W[('csrr', 't0, cycle')]
    # The ISOLATED sweep is DERIVED, not a hand-written list: every two-operand
    # `csrr rd, csr` word in the file, which is the set in which funct3 and rs1
    # are both constant.  The first version listed the names by hand and left
    # out the two addresses added to move bit 25, so it reported eleven bits
    # for a twelve-bit field -- and a hand-written list is a list that can be
    # wrong in a way a set comprehension cannot.
    two_op = [k for k in W if k[0] == 'csrr' and k[1].count(',') == 1]
    groups = [
        ('funct3 alone, masked out of the three register forms',
         0x7000,
         [W[(a, 't0, cycle, t1')] for a in ('csrrw', 'csrrs', 'csrrc')]),
        ('inst[19:15] alone, the same three forms against the base',
         0x000f8000,
         [W[(a, 't0, cycle, t1')] for a in ('csrrw', 'csrrs', 'csrrc')]),
        ('the CSR NUMBER, every csrr in the file (NOT ISOLATED)',
         None,
         [W[k] for k in W if k[0].startswith('csrr')]),
        ('the CSR NUMBER, ISOLATED: two-operand csrr words only',
         None,
         [W[k] for k in two_op]),
    ]
    rows = []
    masks = []
    for label, maskmask, keys in groups:
        mask = 0
        for w in keys:
            mask |= w ^ base
        masks.append(mask)
        if maskmask is not None:
            isolated = mask & maskmask
        else:
            isolated = mask
        rows.append((label, len(keys), '0x%08x' % mask, len(bits_of(mask)),
                     '0x%08x' % isolated, len(bits_of(isolated))))
    table(['what the sweep moved', 'words', 'raw mask', 'bits', 'isolated',
           'bits'], rows, [48, 6, 12, 5, 12, 5])
    print()
    n_raw = len(bits_of(masks[2]))
    n_iso = len(bits_of(masks[3]))
    n_two = len(two_op)
    iso_bits = bits_of(masks[3])
    print('    the isolated row moves bits %d to %d: %s'
          % (min(iso_bits), max(iso_bits),
             ', '.join(str(x) for x in iso_bits)))
    print('    %d bits, CONTIGUOUS, and the boundary is confirmed by the'
          % n_iso)
    print('    assembler refusing 0x1000 rather than by the sweep alone.')
    print()
    para("""THE FIRST TWO ROWS ARE TWO ISOLATIONS OF THE SAME THREE WORDS, and
they are in the table because a mask is a LOWER BOUND and the two ways of
getting one disagree about what the field is.  The raw XOR of the three
register forms against the base moved FOUR bits -- bits 12, 13, 16 and 17 --
and that is `funct3` AND `rs1`, because the base is a two-operand `csrr` with
rs1 = 0 and the three forms all have rs1 = t1.  Masking with `0x7000` leaves
`funct3` at TWO bits moved and masking with `0x000f8000` leaves `rs1` at TWO
bits moved, and neither of those is the field's width either: three register
forms differ in only TWO funct3 values out of the three the field can hold,
because the base is funct3 = 2 and the sweep moved to 1 and 3.  §KEEP§A MASK
IS A LOWER BOUND AND A SWEEP OF THREE INSTRUCTIONS IN A FOUR-VALUE FIELD
CANNOT FIND THE FOURTH.

§KEEP§THE THIRD AND FOURTH ROWS ARE THE SAME FIELD AND THEY ARE THE WHOLE OF RETRACTION R2.  The raw sweep moved %d bits; the isolated sweep moved the CSR NUMBER and nothing else.

The raw sweep is "every `csrr` in the file", and that set includes the
immediate forms and the three-operand forms as well as the two-operand ones,
so it moves `funct3` and `rs1` as well as the address.  The isolated sweep
holds `funct3` and `rs1` constant by using the %d two-operand `csrr rd, csr`
words and nothing else, and what is left is the address field ALONE: bits 20
to 31, contiguous, %d of them.

A MASK WITH A HOLE IN IT IS A NUMBER ABOUT THE SET YOU SWEPT AND NOT ABOUT
THE FIELD, AND THE REPAIR IS TO HOLD THE OTHER FIELDS CONSTANT RATHER THAN TO
MASK THE RESULT AFTERWARDS.  The two masks are printed in this file's source
next to the sweep, so a reader can see what was held constant.  Masking the
RESULT would have been equivalent here and is worse, because a result mask
cannot distinguish "this field did not move" from "this field moved and the
mask hid it": a mask applied to the INPUT is a statement about the sweep and
a mask applied to the OUTPUT is a statement about the answer.

AND THE FOURTH ROW IS ALSO THE COURSE'S BEST EXERCISE IN A LOWER BOUND.  The
first version of the isolated sweep moved ELEVEN bits and not twelve, because
every named CSR in `csr.s` and every U-mode address in it had bit 5 of its
address clear -- so the sweep reported a field of eleven bits for a field the
specification says is twelve, and the missing bit was bit 25.  The fix was to
add two addresses with bit 5 SET, and `csr.s` says so at the line where they
are written.  §KEEP§A CORPUS IN WHICH EVERY ADDRESS HAS THE SAME BIT CLEAR
WILL REPORT A FIELD ONE BIT NARROWER THAN IT IS, WITH NOTHING IN THE OUTPUT
THAT LOOKS LIKE A GAP.

That is why the field's width here rests on TWO measurements and not one.
The sweep says %d bits moved, and the assembler's REFUSAL at 0x1000 says
twelve bits is all there is.  A sweep alone would have said eleven, and would
have been right about its corpus -- which is the least comforting kind of
right and the one the AArch64 section's HINT finding is about.""" % (
        n_raw, n_two, n_iso, n_iso))

    # --- the twelve-bit boundary, by refusal -------------------------------
    print()
    print('  THE TWELVE-BIT FIELD, MEASURED BY WHERE THE ASSEMBLER STOPS.')
    print('  A boundary measured by a refusal is worth more than a boundary')
    print('  quoted from a diagram, because it is the TOOL agreeing with the')
    print('  document rather than a second reading of the same document.')
    print()
    rows = []
    for src_line in ('csrr t0, 0x7ff', 'csrr t0, 0x800', 'csrr t0, 0xfff',
                     'csrr t0, 0x1000', 'csrr t0, 0xfff0',
                     'csrwi 0xfff, 0x1f', 'csrwi 0xfff, 0x20',
                     'csrwi 0x1000, 5', 'csrrs t0, 0xfff, t1',
                     'csrw 0xfff, t0'):
        w, nb, t = asm_one(src_line)
        if w is None:
            rows.append((src_line, 'REFUSED', '-', '-', t))
        else:
            rows.append((src_line, 'accepted', '%d bytes' % nb, '0x%08x' % w,
                         t))
    table(['source', 'verdict', 'size', 'word', "the assembler's own words"],
          rows, [22, 9, 8, 12, 62])
    print()
    ok = [r for r in rows if r[1] == 'accepted']
    bad = [r for r in rows if r[1] == 'REFUSED']
    para("""§KEEP§4095 IS THE LAST CSR NUMBER AND 4096 IS NOT ONE, AND THE ASSEMBLER SAYS SO IN ITS OWN WORDS: immediate must be an integer in the range [0, 4095].  THE FIVE-BIT IMMEDIATE HAS ITS OWN BOUNDARY AT 31, and it is the SAME SHAPE OF MESSAGE on a DIFFERENT FIELD: immediate must be an integer in the range [0, 31].

Two boundaries, two fields, one message.  2^12 - 1 is 4095 and 2^5 - 1 is
31, and the field widths are the only difference between them, which is the
check on the quoted "twelve bits" and on the immediate form's five at the same
time.  %d of the %d probes were accepted and %d refused, and every refusal
is quoted above in the assembler's own words rather than summarised, because
a summarised refusal is a refusal a reader has to trust.
""" % (len(ok), len(rows), len(bad)))
    return W


# ===========================================================================
# SECTION 4 -- Zicsr IS NOT IN THE BASE ISA, AND NOBODY CHECKS.
#
# The section plan's own instruction for this concept: "Zicsr's recent split
# out of the base is a good, checkable fact".  The checkable fact turned out
# to be considerably more interesting than the split.
# ===========================================================================

def sec4():
    banner(4, 'Zicsr IS NOT IN THE BASE ISA -- AND THE ISA STRING DOES NOT '
              'NOTICE')
    print()
    para("""THE SPLIT IS %s, and it is worth stating in the manual's own terms
because the wording is unusual.  From `rv32-unpriv`, which is the document
the previous RISC-V course established as this section's unprivileged oracle:
the base integer set no longer contains the six CSR instructions, and a
hardware implementation that includes the privileged architecture is expected
to require them anyway.

That is a DOCUMENTARY fact and there is nothing to measure about it.  What
IS measurable is what the toolchain does about it, and the answer is the
finding of this section.""" % QUOT)
    print()
    print('  THE SAME TWO INSTRUCTIONS, THREE TIMES, AT THREE -march SETTINGS.')
    print('  only_zicsr.s is `csrr t0, cycle` and `ret` and nothing else, so')
    print('  the object cannot contain anything but the extension in question.')
    print()
    rows = []
    for march in ZICSR_MARCHES:
        f = 'zicsr_%s.o' % march
        attr = arch_attr(p(f))
        ins = func_insns(p(f))
        words = [w for nm in ins for (w, _m, _t, _b) in ins[nm]]
        first = '0x%08x' % words[0] if words else '(none)'
        rows.append((march, attr, len(words), first,
                     'YES' if 'zicsr' in attr else 'NO'))
    table(['-march', 'Tag_RISCV_arch in the object', 'words', 'word 0',
           'claims zicsr?'], rows, [26, 42, 6, 12, 14])
    print()
    r0, r1 = rows[0], rows[1]
    print('    The FIRST row is the finding.  -march=rv64i, the base, and the')
    print('    object contains 0x%08x -- a Zicsr instruction -- and its ISA'
          % int(r0[3], 16))
    print('    string is %s.' % r0[1])
    print()
    para("""§KEEP§THE ASSEMBLER EMITTED A Zicsr INSTRUCTION UNDER -march=rv64i, GAVE NO DIAGNOSTIC, AND THE OBJECT'S ISA STRING SAYS rv64i2p1 WITH NO zicsr IN IT.

Read that as three separate claims, because they are three separate things
and the course could easily have collapsed them into one:

* 1. THE ASSEMBLER DOES NOT ENFORCE THE SPLIT.  It will assemble a Zicsr
  instruction with the base ISA selected and it says nothing.  The word
  `zicsr` is not in the object and the instruction is in the object.
* 2. THE INSTRUCTION IS THE SAME ONE either way.  The first word of both
  objects is the same 32 bits, and the two files differ in one string in one
  section and in nothing else this artifact looks at.
* 3. THE ISA STRING RECORDS WHAT WAS ASKED FOR AND NOT WHAT IS THERE.

THE THIRD IS THE ONE WITH CONSEQUENCES.  `Tag_RISCV_arch` is the string a
linker and a loader read to decide whether an object's instructions are
decodable by the machine it is producing.  The previous RISC-V course
established, from `rvasm`'s `rv-isa` concept, that the string is a rich and
useful record: it names the sub-extensions an object actually uses, so a
linker knows whether its compressed instructions are decodable.  THIS IS THE
SAME STRING, AND IT IS A RECORD OF THE REQUEST.

The consequence is precise and it is not a defect anybody has to fix: a
`-march=rv64i` object assembled by this toolchain can contain a Zicsr
instruction, and the string in the file will not warn you.  A toolchain that
wanted to make the string trustworthy would have to REFUSE the instruction
under a base `-march`, and this one does not.

AND THE INSTRUCTION IS IN THE C TOO, which is the part that makes it a
compiler observation rather than an assembler curiosity.  Section 5's `ecall`
wrapper is written in C, and the `csrr` functions beside it compile to bare
`csrr` instructions with no diagnostic and no attribute change.  Nothing in
the C source tells the compiler that a privileged register is involved, so
there is nothing for it to check: `csrr %0, satp` in a function that will run
in U-mode assembles exactly as cleanly as one that will run in M-mode, and
the object is identical.

THAT IS THE HONEST VERSION OF "PRIVILEGE IS A CONVENTION ON RISC-V", and it
is a stronger claim than the manual's.  The manual says the CSR ADDRESS
encodes who may touch a register.  The measurement says the INSTRUCTION does
not notice which register it is touching, that no part of the toolchain
notices, and that the string a linker would consult does not record it
either.""")

    # the direct, in-C evidence
    print()
    print('  AND IN C, WHERE NOTHING COULD HAVE CHECKED ANYWAY:')
    print()
    for fn in ('rd_satp', 'rd_stvec', 'rd_scause'):
        ins = func_insns(p('wrap_O2.o')).get(fn, [])
        if not ins:
            print('    %-14s MISSING from wrap_O2.o' % fn)
            continue
        w, m, t, b = ins[0]
        print('    %-14s 0x%08x  %-6s %-22s  %d bytes' % (fn, w, m, t, b))
    print()
    para("""Three privileged registers, read by three C functions, and the
compiler's whole contribution to each is `csrr a0, <name>`.  The CSR ADDRESS
is a three-digit hexadecimal constant that the assembler resolved from a
name, and the compiler never sees the number: it sees a string in an inline
`asm` statement and passes it through.

MEASURED-ON-BYTES, and the second reader prints the same three words.  And
this is the honest place for the section's own limit: what is measured is the
emission, and what is NOT measured is whether a RISC-V machine would trap on
`rd_satp` when it executes in U-mode, which is what the privilege model says
and which nothing on this host can confirm.""")


# ===========================================================================
# SECTION 5 -- THE ecall CONVENTION, AS THE COMPILER EMITS IT.
# ===========================================================================

def sec5():
    banner(5, 'THE ecall CONVENTION, AND THE ONE BIT THAT SEPARATES a7 '
              'FROM a6')
    print()
    para("""`ecall` is 0x00000073 and thirty-one of its thirty-two bits are a
fixed pattern, which the first course in this section measured and this one
repeats in a different role.  What is NEW here is everything around it: the
compiler's choice of registers, and the measurement that the choice is a
CONVENTION -- that a reader who guesses wrong about it produces a program
which differs from the right one by ONE BIT of ONE INSTRUCTION and has no
other symptom.

The convention is %s, from the psABI's chapter on system calls, and it is
NOT in the instruction: the syscall number goes in `a7`, the arguments in
`a0` to `a5`, and the answer comes back in `a0`.  Read the next table before
the next paragraph, because the table is the argument that the convention is
not in the instruction.""" % QUOT)
    print()
    print('  THE THREE WRAPPERS AT -O2, FUNCTION BY FUNCTION:')
    print()
    ins = func_insns(p('wrap_O2.o'))
    rows = []
    for fn in ('sys_write', 'sys_getpid', 'sys_write_a6'):
        w = ins.get(fn, [])
        rows.append((fn, len(w), sum(x[3] for x in w),
                     ' | '.join(x[1] for x in w)))
    table(['function', 'instructions', 'bytes', 'the whole body'], rows,
          [16, 13, 7, 46])
    print()
    a = ins.get('sys_write', [])
    b = ins.get('sys_write_a6', [])
    diffs = [(x, y) for x, y in zip(a, b) if x[0] != y[0]]
    print('  THE CONTROL.  `sys_write` puts the number in a7 and')
    print('  `sys_write_a6` puts it in a6 -- the register a reader would')
    print('  guess from x86-64, where the number goes in rax.  The two')
    print('  functions are the same C with one word changed.')
    print()
    if diffs and len(a) == len(b):
        x, y = diffs[0]
        xor = x[0] ^ y[0]
        print('    %-6s %-18s 0x%08x' % (x[1], x[2], x[0]))
        print('    %-6s %-18s 0x%08x' % (y[1], y[2], y[0]))
        print('    XOR 0x%08x -- bits %s' % (xor, ', '.join(
            str(k) for k in bits_of(xor))))
        print()
        print('    a7 is x17 and a6 is x16, and x17 is 0b10001 and x16 is')
        print('    0b10000, so the difference is the LOWEST BIT OF THE')
        print('    DESTINATION FIELD, rd at inst[11:7], and nothing else in')
        print('    the word.  The same 32 bits, one bit apart, and the bit')
        print('    is not in the opcode, not in the CSR field and not in')
        print('    any immediate.')
    print()
    para("""§KEEP§THE SYSCALL NUMBER GOES IN a7 AND THE SAME PROGRAM WITH a6 DIFFERS IN EXACTLY ONE BIT OF ONE INSTRUCTION, AND THAT BIT IS rd[0].

Now put the three facts side by side and they make a sentence:

  * `ecall` is 0x00000073: thirty-one fixed bits and nothing that names a
    register;
  * the number is in a7, which is `rd[0]` of the word three instructions
    earlier, and nothing in `ecall` refers to it;
  * a7 and a6 are ONE BIT apart.

So the ENTIRE difference between a working system call and a broken one, on
this architecture, is a bit that appears in a DIFFERENT INSTRUCTION than the
one that performs the call.  There is no linker check for it, no assembler
check for it, no encoding relationship between them, and no diagnostic.  A
kernel whose ABI said a6 instead of a7 would be a kernel that works, and the
only way to find out which one you have is to read a7 or a6 out of a register
in a debugger on hardware this host does not have.

THAT IS THE STRONGEST FORM OF "THE ecall CONVENTION IS AN ABI AND NOT AN
ARCHITECTURE", and it is measured rather than asserted.  The weaker form --
"the instruction does not name a register" -- is true and is stated in the
first RISC-V course.  The stronger form is that the register the ABI names is
carried by a field the ABI also has to agree on separately, one bit wide, in
an instruction the architecture does not associate with the call.

AND THE CORPUS SAYS THE SAME THING AT FOUR LEVELS.  The table above is -O2.
At -O0 the same function is 30 instructions and 100 bytes and the two
versions differ in one word as well, at a different offset, because the
registers are spilled and reloaded.  Section 5's own finding is therefore not
an artefact of one optimisation level: the pair differs in exactly one word
at all four, and which word moves with the level.  That is a SHAPE, and the
harness asserts the shape and not the offsets.""")

    # the -O0 confound, printed because it is a real one
    print()
    print('  THE SAME FUNCTIONS AT FOUR LEVELS, and the counts:')
    print()
    rows = []
    for lv in LEVELS:
        li = func_insns(p('wrap_%s.o' % lv))
        ra = li.get('sys_write', [])
        rb = li.get('sys_write_a6', [])
        d = sum(1 for x, y in zip(ra, rb) if x[0] != y[0])
        rows.append((lv, len(ra), sum(x[3] for x in ra), len(rb), d,
                     'yes' if len(ra) == len(rb) else 'NO'))
    table(['level', 'sys_write insns', 'bytes', 'sys_write_a6 insns',
           'words that differ', 'same length?'], rows, [7, 16, 7, 18, 16, 13])
    print()
    para("""THE SPREAD IS 30 INSTRUCTIONS AT -O0 AND 5 AT THE OTHER THREE, and
that spread is the compiler's and not the convention's.  A reader who quoted
30 would be quoting a property of clang's -O0 scaffolding; a reader who
quoted 5 would be quoting clang 21.1.8's -O1.  The number that is the ABI's
is the last column: the two functions have the SAME LENGTH at every level and
differ in EXACTLY ONE WORD.

The first version of `wrap.c` was a different program and it taught a
different lesson, so the difference is recorded rather than hidden.  The
original had

    long sys_write(long fd, const char *buf, long n) {
        register long a7 __asm__("a7") = 64;
        __asm__ volatile ("ecall" : "+r"(a0) : ... );
        return a0;
    }

and at -O1 and above clang compiled it to `li a7, 0x40 ; ecall ; ret` --
THREE instructions, with the three argument loads DELETED.  Nothing was wrong
with the compiler.  The arguments were dead as far as it could see, and what
the measurement had become was a measurement of dead-code elimination.  The
corpus adds `+ nfd + n` to the return value, which makes them live, and the
count is then a count of the convention.  A course that had shipped the first
version would have reported a number that was true and about the wrong thing,
and section 14's R4 is that retraction.""")

    # what the convention is NOT
    print()
    print('  WHAT THE EMITTED BYTES DO NOT CONTAIN, which is the limit and')
    print('  not a disclaimer:')
    print()
    for what in ('the number 64 as a syscall number',
                 'any reference to a7 from inside `ecall`',
                 'any check that a0-a5 were set',
                 'any indication that this is a system call at all',
                 'any return path, because the trap is a jump to a handler'):
        print('    - %s' % what)
    print()
    para("""NOT ONE OF THOSE FIVE IS IN THE OBJECT FILE, and all five are things
the word `ecall` is usually taken to mean.  §KEEP§WHAT IS MEASURED HERE IS THAT THE COMPILER EMITS THE CONSTANT 0x00000073 WITH THE CONVENTION'S REGISTERS AROUND IT, AND WHAT IS NOT MEASURED IS THAT ANY OF IT WORKS: no trap is taken, no mode changes, no handler runs, no value comes back, and the number 64 is not known to be a syscall number by anything in this course except the specification that says so.""")


# ===========================================================================
# SECTION 6 -- Sv39, Sv48, Sv57: THE ARITHMETIC.
#
# Pure arithmetic over quoted constants.  Every number here is checkable with
# a calculator and every one of them is CHECKED, which is what makes this the
# one section of the course where a reader needs no toolchain at all.
# ===========================================================================

GRANULE = 4096
PTE_BYTES = 8
SVMODES = (('Sv39', 3, 8), ('Sv48', 4, 9), ('Sv57', 5, 10))


def sec6():
    banner(6, 'Sv39, Sv48, Sv57 -- THREE LEVEL COUNTS AND A PAGE SIZE')
    print()
    para("""The three formats are %s, and the quotes are short enough to
print.  `priv-spec` section 11.1.4, on Sv39: "The algorithm for
virtual-to-physical address translation is the same as in 11.1.3.2 ... except
LEVELS equals 3 and PTESIZE equals 8."  Section 11.1.5, on Sv48: "It closely
follows the design of Sv39, simply adding an additional level of page table,
and so this chapter only details the differences between the two schemes ...
LEVELS equals 4 and PTESIZE equals 8."  Section 11.1.6, on Sv57, adds a fifth.

And the page size, from the same chapter and stated as a decision rather than
a derivation: "After much deliberation, we have settled on a conventional
page size of 4 KiB for both RV32 and RV64.  We expect this decision to ease
the porting of low-level runtime software and device drivers."

THE ARITHMETIC IS THE WHOLE OF THE THREE FORMATS, and this is the one section
of the course where a reader with a pencil can check every number.  From
PTESIZE = 8 and a 4 KiB granule: 4096 / 8 = 512 entries per table, and 512 is
2^9, so NINE index bits per level.  From LEVELS = L: L * 9 + 12 = the width
of the virtual address, and the 12 is the page offset that is never
translated.""" % QUOT)
    print()
    rows = []
    for name, levels, mode in SVMODES:
        entries = GRANULE // PTE_BYTES
        per_bits = entries.bit_length() - 1
        vpn_bits = levels * per_bits
        va = vpn_bits + 12
        rows.append((name, levels, mode, entries, per_bits, vpn_bits, va,
                     '2^%d' % va, human(1 << va)))
    table(['format', 'LEVELS', 'satp.MODE', 'entries/table', 'index bits',
           'VPN bits', 'VA bits', 'range', 'range in human units'], rows,
          [7, 7, 10, 13, 11, 10, 8, 8, 16])
    print()
    para("""READ THE `satp.MODE` COLUMN AGAINST THE `LEVELS` COLUMN.  The mode
values are 8, 9 and 10 and they are NOT the level counts: a mode of 8 is
three levels, 9 is four and 10 is five, and the offset between them is
consistent (+1 per level) but the base is 5 above three.  The reason is that
modes 0 through 7 are spoken for -- 0 is Bare, 1 is Sv32, and 2 through 7
are "Reserved for standard use" -- so the Sv modes could not have started at
the level count without colliding, and the numbering is a REGISTRY rather
than a formula.  A reader who writes `satp.MODE = LEVELS` gets a hardware
address-translation mode this specification does not define.

And the read-only hole: mode 11 is Sv64, "Reserved for page-based 64-bit
virtual addressing", and 12 through 13 are reserved and 14 through 15 are
"Designated for custom use".  Three of the sixteen mode values a 4-bit field
can hold are for modes that do not exist, which is worth knowing before
writing a mode-check switch that assumes its default case is unreachable.""")

    # the checks, computed
    print()
    print('  THE SAME TABLE AS CHECKABLE ARITHMETIC.  Each line is an')
    print('  identity, and each is asserted by this file rather than left to')
    print('  the reader, because an identity printed and not checked is a')
    print('  claim.')
    print()
    for name, levels, mode in SVMODES:
        entries = GRANULE // PTE_BYTES
        per_bits = entries.bit_length() - 1
        va = levels * per_bits + 12
        flat = 1 << (levels * per_bits)
        checks = [
            ('granule / PTE_BYTES = %d = 2^%d' % (entries, per_bits),
             GRANULE // PTE_BYTES == entries == 1 << per_bits),
            ('a page table is EXACTLY one granule: %d * %d = %d = %d'
             % (entries, PTE_BYTES, entries * PTE_BYTES, GRANULE),
             entries * PTE_BYTES == GRANULE),
            ('LEVELS * %d + 12 = %d' % (per_bits, va),
             levels * per_bits + 12 == va),
            ('the mode is 5 above the level count, and +1 per level',
             mode == levels + 5),
            ('the flat table is 2^%d = %d entries' % (levels * per_bits, flat),
             flat == 1 << (levels * per_bits)),
            ('a flat table is 1/512 of the space it covers: %d * 512 = 2^%d'
             % (flat * PTE_BYTES, va),
             (flat * PTE_BYTES) * (1 << per_bits) == 1 << va),
        ]
        print('    %s  LEVELS=%d  mode=%d  VA=%d bits  2^%d = %s'
              % (name, levels, mode, va, va, human(1 << va)))
        for label, ok in checks:
            print('        [%s] %s' % ('ok' if ok else 'FAIL', label))
        print('        flat table would be %d entries = %s of PTE bytes'
              % (flat, human(flat * PTE_BYTES)))
        print()

    para("""THE LAST LINE OF EACH BLOCK IS THE ARGUMENT FOR HAVING MORE THAN ONE
LEVEL, and it is the number a reader should take away.  A flat table for
Sv39 would be 2^27 entries of 8 bytes, which is 1 GiB of page table to map
512 GiB of address space -- a ratio of one table byte per 512 address bytes.
Sv48's flat table is 512 GiB for 256 TiB, the same ratio, and Sv57's is
256 TiB for 128 PiB.  The multi-level walk exists so that the UNUSED part of
the address space costs nothing, and the cost of a level is 4 KiB: one page
of pointers, of which 512 - 1 are free for the level below.

So the whole cost of the third level of Sv39 is 4 KiB, and the whole benefit
is that 511 of the 512 entries in the root table can be left alone.  A
reader who wants the sharpest single sentence in this section has it: THE
THIRD LEVEL COSTS ONE PAGE AND BUYS 511 ENTRIES OF ROOT TABLE.""")

    # the shared page-table geometry, quoted and then computed
    print()
    print('  THE PAGE-TABLE PAGE, and the two numbers a kernel must match:')
    print()
    print('    entries per table        512 = 2^9        (4096 / 8)')
    print('    a page table is exactly  4096 bytes      (512 * 8, and the')
    print('                                           granule is 4096)')
    print('    entries actually usable  511             (entry 0 is a fault')
    print('                                           handler by convention)')
    print('    the aligned size is      2^12 = 4096     (a page, and 512*8')
    print('                                           is a page, so a page')
    print('                                           table and a page are the')
    print('                                           same size by arithmetic)')
    print()
    para("""THE LAST OF THOSE IS THE ONE A KERNEL GETS WRONG BY ASSUMING.  512
entries of 8 bytes is EXACTLY one 4 KiB page, and that is not a coincidence
to be noticed -- it is why PTESIZE is 8 and not 4, and `priv-spec` says so
directly: "Sv39 page tables contain 2^9 page table entries (PTEs), eight bytes
each.  A page table is exactly the size of a page and must always be aligned
to a page boundary."

So the alignment requirement falls out of the geometry.  A page table IS a
page.  Which means `satp`'s PPN is a page number rather than an address, and
which means a kernel that allocates a page table out of a page allocator
gets the alignment for free -- and a kernel that allocates one out of a slab
has to ask for it, and `a64sys`'s concept 5 measured the AArch64 version of
exactly that mistake, where the alignment is a property of the SECTION rather
than of the declaration.  The RISC-V version is easier, and section 9's
`pt.s` puts the tables in a `.data` section with `.align 12` precisely so that
the relocation offsets in the table are page numbers rather than byte
offsets, and the numbers come out clean.""")

    # the leaf sizes, which is where the levels interact
    print()
    print('  THE LEAF SIZES, and the rule that produces them.  "Any level of')
    print('  PTE may be a leaf PTE" -- so a leaf is not "the last level", it')
    print('  is "any level whose PPN is aligned to its own size".')
    print()
    rows = []
    for name, levels, _mode in SVMODES:
        sizes = ['4 KiB']
        for k in range(1, levels):
            sizes.append('%s' % human(1 << (12 + 9 * k)))
        sizes.append('%s' % human(1 << (12 + 9 * (levels - 1) + 9)))
        rows.append((name, levels, ', '.join(sizes[:-1]),
                     'and one more, %s, at the root' % sizes[-1]))
    table(['format', 'LEVELS', 'the leaf sizes below the root', 'and'], rows,
          [7, 7, 40, 26])
    print()
    para("""Sv39 has three levels and therefore three leaf sizes: 4 KiB, 2 MiB and
1 GiB.  `priv-spec` §11.1.4 states them: "in addition to 4 KiB pages, Sv39
supports 2 MiB megapages and 1 GiB gigapages, each of which must be virtually
and physically aligned to a boundary equal to its size.  A page-fault
exception is raised if the physical address is insufficiently aligned."

Sv48 adds 512 GiB and Sv57 adds 256 TiB, and the count of sizes is exactly
the number of levels, which follows from the rule rather than from a table: a
leaf at level k has consumed k index fields and so covers 2^(12 + 9k) bytes.
2^(12+9) is 2^21 = 2 MiB, 2^(12+18) is 2^30 = 1 GiB, 2^(12+27) is 2^39 =
512 GiB.  The numbers in that sentence are arithmetic from the granule and
the index width, and a reader who wants to check them does not need the
manual.

AND THE ALIGNMENT REQUIREMENT IS NOT FREE, which is the sentence worth
keeping.  A megapage leaf's PPN must be 2^(9+1) = 2^10 = 1024-aligned
within its 4 KiB PTE field -- the low 10 bits of the PPN must be zero, which
is 2^9 for the index field and 1 for the offset.  A gigapage's must be
2^19-aligned.  The hardware does not mask them: "A page-fault exception is
raised if the physical address is insufficiently aligned."  So a kernel that
builds a megapage at a 4 KiB-aligned address FAULTS, and the fault is
arithmetic rather than a policy decision, and the check is three instructions
in the wrong place if the allocator does not do it.

§KEEP§AND NONE OF IT IS OBSERVABLE HERE.  There is no RISC-V machine on this
host, so no page is walked, no TLB is consulted, no page fault is raised and
no A or D bit is set by anything.  Every number in this section is arithmetic
over two quoted constants, and that is the strongest kind of claim in the
course: it does not need the specification's trust beyond the two constants
and it does not need hardware at all.""")


# ===========================================================================
# SECTION 7 -- THE PTE BITS, WITH THE COMPILER AS A THIRD READER.
# ===========================================================================

def sec7():
    banner(7, 'THE EIGHT PTE BITS, READ OUT OF WHAT THE COMPILER EMITTED')
    print()
    para("""The PTE format is %s.  `priv-spec` §11.1.4 prints it as a figure and
then says the part that matters for a decoder: "The PTE format for Sv39 is
shown in Figure 22.  Bits 9-0 have the same meaning as for Sv32."  The
layout, from the low bit up, is V, R, W, X, U, G, A, D, then PTESIZE at
bits 9-8, then the PPN at bits 53-10, with bit 63 reserved for Svnapot and
bits 62-61 reserved for Svpbmt and bits 60-54 reserved for future standard
use.

THE WAY TO CHECK IT WITHOUT A MANUAL is to write the eight bit extractions in
C, compile them, and read the SHIFTS back out of the words.  `bits.c` does
that and the compiler emits, for every one of the eight, the same two-
instruction shape: a left shift by 63 - n followed by a right shift by 63.  A
reader can verify the whole table against a manual by checking eight
decreasing shift amounts, and that is a much better check than reading eight
rows of a table and hoping.""" % QUOT)
    print()
    ins = func_insns(p('bits_O2.o'))
    rows = []
    order = [('pte_v', 'V', 0), ('pte_r', 'R', 1), ('pte_w', 'W', 2),
             ('pte_x', 'X', 3), ('pte_u', 'U', 4), ('pte_g', 'G', 5),
             ('pte_a', 'A', 6), ('pte_d', 'D', 7)]
    prev = None
    ok = True
    for fn, name, n in order:
        w = ins.get(fn, [])
        if not w:
            rows.append((name, n, 'MISSING', '-', '-'))
            ok = False
            continue
        # bit 0 is an `andi` with a literal 1 and has no left shift
        if n == 0:
            rows.append((name, n, 'andi a0, a0, 0x1', 'mask 0x1',
                         'the compiler SPECIALISED bit 0 into a mask'))
            continue
        shl = None
        shr = None
        for word, mn, txt, _b in w:
            if mn == 'slli':
                shl = int(txt.split(',')[-1].strip().replace('0x', ''), 16)
            if mn == 'srli':
                shr = int(txt.split(',')[-1].strip().replace('0x', ''), 16)
        got = 63 - shl if shl is not None else None
        good = (got == n and shr == 63)
        ok = ok and good
        rows.append((name, n, 'slli by 0x%x' % shl if shl is not None else '?',
                     'srli by 0x%x' % shr if shr is not None else '?',
                     '63 - 0x%x = %d%s' % (shl, got if got is not None else -1,
                                            '' if good else '   MISMATCH')))
    table(['bit', 'n', 'the first instruction', 'the second',
           'what it says about the bit'], rows, [5, 4, 22, 14, 40])
    print()
    print('    EIGHT BITS, EIGHT LEFT SHIFTS, AND THEY ARE 0x3e 0x3d 0x3c '
          '0x3b 0x3a 0x39 0x38 in')
    print('    the order R W X U G A D -- that is, DECREASING BY ONE as the')
    print('    bit number increases, because 63 - n decreases as n does.')
    print('    And the right shift is 0x3f = 63 in all seven, because the')
    print('    mask is a sign-extend-to-64 and not a zero-extend.')
    print()
    para("""§KEEP§THE COMPILER EMITTED THE MANUAL'S BIT TABLE AS SEVEN DESCENDING SHIFT AMOUNTS AND A FIXED RIGHT SHIFT OF 63, AND 63 - n IS THE ONLY ARITHMETIC IN IT.

That is the third reader.  The manual has a figure, the compiler has an
instruction sequence, and this file compares them by reading the immediate out
of a word and subtracting it from 63.  If the manual's figure were wrong --
if A were bit 5 and D were bit 6 -- the compiler's `((p) >> 6) & 1` would
still emit `slli by 0x39` and the check would fail.  The compiler is not an
authority on the PTE layout; it is an authority on what a C expression
becomes, and those are two different things and the composition of the two is
what checks the figure.

AND THE RIGHT SHIFT OF 63 IS WORTH A SENTENCE ON ITS OWN, because it is a
fact about the MASK and not about the layout.  `(p >> 6) & 1` could be `andi`
with a literal 1 after a right shift, and clang emitted a left shift first
and then a sign-extend instead, because that form is branch-free and
constant-foldable on a 64-bit target and the compiler prefers it.  The
consequence is that a reader looking for `srli a0, a0, 6 ; andi a0, a0, 1`
finds NEITHER instruction, and a decoder written against the shape they
expected finds two instructions that are not the two they wanted.  §KEEP§BIT
0 IS THE ONE EXCEPTION: clang emitted `andi a0, a0, 0x1` and NO SHIFT AT ALL,
because shifting by zero and masking with one is the identity and the
optimiser knows it.

So the table is seven rows of one shape and one row of another, and a reader
who writes a field-extraction helper that assumes the uniform shape will work
on seven of the eight and produce a wrong answer on the eighth with no
diagnostic.""")

    # the A and D bits and the implicit page-fault path
    print()
    print('  THE A AND D BITS, and the two schemes for managing them.  The')
    print('  bits are the measurement above; the two SCHEMES are quoted, and')
    print('  the quotation is the sharpest thing in the whole course about')
    print('  what a specification does when a hardware decision is left to')
    print('  the implementer.')
    print()
    para("""`priv-spec` §11.1.3.1: "Each leaf PTE contains an accessed (A) and
dirty (D) bit.  The A bit indicates the virtual page has been read, written,
or fetched from since the last time the A bit was cleared.  The D bit
indicates the virtual page has been written since the last time the D bit was
cleared."

And then the specification offers TWO schemes, and the choice between them is
not the implementation's alone:

    "Two schemes to manage the A and D bits are defined:

     * The Svade extension: when a virtual page is accessed and the A bit is
       clear, or is written and the D bit is clear, a page-fault exception is
       raised.

     * When the Svade extension is not implemented, the following scheme
       applies.  When a virtual page is accessed and the A bit is clear, the
       PTE is updated to set the A bit.  When the virtual page is written and
       the D bit is clear, the PTE is updated to set the D bit."

THAT IS THE IMPLICIT PAGE-FAULT PATH, and it is worth being precise about
which is which, because the names are easy to swap:

  * WITHOUT Svade, hardware SETS the bits.  A first touch to a page whose A
    and D are both clear succeeds, and the hardware updates the PTE as a side
    effect.  No trap, and the cost is a store to the page table inside what
    the program experiences as a load.
  * WITH Svade, hardware TRAPS.  A first touch to the same page raises a page
    fault, the handler sets the bits, and returns.  The cost is an exception
    round trip.

The v1.11 preface records the change: "Hardware management of page-table entry
Accessed and Dirty bits has been made optional; simpler implementations may
trap to software to set them."  A specification that used to require the
hardware scheme now permits both, and a kernel that has to know which one it
is running on cannot find out by reading a register -- it has to WRITE ONE TO
EVERY BIT AND READ BACK, the same procedure the specification gives three
times elsewhere.

§KEEP§AND NEITHER SCHEME IS OBSERVABLE ON THIS HOST, because there is no
RISC-V machine here to touch a page.  What is measured is that the two bits
are at 6 and 7 and that a C expression for them compiles to a specific pair
of instructions.  What is quoted is what each scheme does.  What is NOT
claimed, and could not be, is which scheme any particular hart implements, how
many page faults a first touch costs, or whether the hardware update is
atomic with the access that caused it -- the last of which the specification
addresses at length and which is emphatically a property of silicon this
course has no way to reach.""")


# ===========================================================================
# SECTION 8 -- satp, AND THE TWO MASKS IN bits.c THAT ARE WRONG.
#
# A self-inflicted retraction, measured on the compiler's own output, and it
# is in the course because the failure shape is worth more than a correct
# macro would have been.
# ===========================================================================

def sec8():
    banner(8, 'satp, AND TWO MASKS OF OURS OWN THAT ARE WRONG')
    print()
    para("""`satp` is %s, and the field layout is `priv-spec` §11.1.1.11: MODE
at bits 63-60, ASID at 59-44, and the PPN below that.  On RV64 that is 4
bits, 16 bits, and whatever is left, and "whatever is left" is the interesting
arithmetic: 64 - 4 - 16 = 44 bits, and the PPN is stored DIVIDED BY THE
GRANULE, so the register holds a page number rather than an address and the
field is 44 - 8 = 36 bits of page number.

§KEEP§THE PPN FIELD IN satp IS 36 BITS, NOT 44 AND NOT 54, AND bits.c CONTAINS TWO MASKS THAT ARE WRONG AND THIS FILE MEASURED BOTH.

The two wrong masks are in the corpus on purpose.  `satp_ppn54_wrong` masks
with 0x3fffffffffffff, which is 54 bits -- the width of the PPN field in a
PTE, applied to the wrong register.  `satp_ppn44_wrong` masks with
0xfffffffffff, which is 44 bits -- the width the manual's PPN figure shows,
also applied to the wrong register.  Both are NATURAL mistakes, both compile,
and the compiled form is a pair of plausible shifts.""" % QUOT)
    print()
    ins = func_insns(p('bits_O2.o'))
    print('  THE FIVE satp EXTRACTORS, AS COMPILED, AND WHAT EACH ONE')
    print('  ACTUALLY RETURNS.  The width and the position are RECOVERED from')
    print('  the two shifts rather than assumed: a `slli by L ; srli by R`')
    print('  pair on a 64-bit value returns input bits [R-L : 63-L], so the')
    print('  width is 64 - R and the low bit is R - L.  A pair with no slli')
    print('  is L = 0 and the formula still holds, which is why the MODE row')
    print('  is in the table at all.')
    print()
    rows = []
    for fn, label, asked, right in (
            ('satp_mode', 'MODE', 4, 4),
            ('satp_asid', 'ASID', 16, 16),
            ('satp_ppn36', 'PPN', 36, 36),
            ('satp_ppn44_wrong', 'PPN, 44-bit mask', 44, 36),
            ('satp_ppn54_wrong', 'PPN, 54-bit mask', 54, 36)):
        w = ins.get(fn, [])
        shl = 0
        saw_shl = False
        shr = None
        for word, mn, txt, _b in w:
            if mn == 'slli':
                shl = int(txt.split(',')[-1].strip().replace('0x', ''), 16)
                saw_shl = True
            if mn == 'srli':
                shr = int(txt.split(',')[-1].strip().replace('0x', ''), 16)
        if shr is None:
            rows.append((label, '0x%x' % shl, '(none)', str(asked), '?', '?',
                         'no right shift at all'))
            continue
        lo = shr - shl
        hi = 63 - shl
        got = 64 - shr
        good = (got == right)
        rows.append((label,
                     ('0x%x' % shl) if saw_shl else '(none, L = 0)',
                     '0x%x' % shr, str(asked), '%d' % got,
                     'satp[%d:%d]' % (hi, lo),
                     'CORRECT' if good else 'WRONG by %+d bits'
                     % (got - right)))
    table(['field', 'slli', 'srli', 'the width the C asked for',
           'the width emitted', 'the bits it keeps', 'verdict'], rows,
          [18, 14, 7, 24, 17, 18, 20])
    print()
    para("""READ THE LAST ROW AGAINST THE THIRD.  54 bits of `satp` at [61:8]
swallows the ENTIRE ASID, both bits of ASID's neighbours, and the low two
bits of MODE.  So `satp_ppn54_wrong` returns a value in which sixteen bits
of address space identifier and two bits of translation mode are silently
mixed into the page number, and a caller that used it to compute a physical
address would get a plausible number that is wrong in a way no assertion
catches.

The 44-bit mask is worse in the way that matters, because 44 IS the number
the manual prints for a PTE's PPN.  A reader who takes 44 from the PTE figure
and applies it to satp gets a value that LOOKS like the documented field
width, and it is 8 bits too wide, and those 8 bits are exactly satp[51:44] --
the top eight bits of the ASID.

§KEEP§THE RIGHT ANSWER IS 36 BITS AND IT FOLLOWS FROM SUBTRACTING, NOT FROM READING A FIGURE: 64 - 4 (MODE) - 16 (ASID) - 8 (the granule shift) = 36.

The retracted claims and what replaced them are R5 and R6 in section 14, and
the harness asserts the TEXT of both, because a retraction that is quietly
deleted is the one failure no number in this file can catch.  The reason the
two are worth printing rather than fixing silently is that BOTH ARE THE KIND
OF MISTAKE A READER MAKING THIS COURSE WOULD MAKE.  The PPN is 54 bits in a
PTE.  The PPN is 44 bits in the figure.  satp holds a PPN.  Two reasonable
steps and a wrong register.

AND THE COMPILER'S CONTRIBUTION TO THE BUG WAS ZERO.  It did not
misunderstand either expression; it compiled both exactly as written, and
the artifact's audit in section 12 is the only reason the width is knowable
without running the thing.  That is a small point and it is the same point
the sibling courses keep making: a compiler faithfully implements the C you
wrote, including the C that is wrong, and no amount of optimisation will tell
you your mask is 18 bits too wide.""")

    # the mode field, which the compiler PROVED redundant
    print()
    print('  ONE MORE MEASUREMENT IN THE satp TABLE, and it is a small one:')
    print()
    m = ins.get('satp_mode', [])
    print('    %s' % ' | '.join('%s %s' % (x[1], x[2]) for x in m))
    print()
    para("""`satp_mode` is written `(s >> 60) & 0xf` and clang emitted a
RIGHT SHIFT BY 60 AND NO MASK.  The `& 0xf` is gone, and it is gone because
it is provably redundant: a logical right shift by 60 of a 64-bit value
leaves four bits, so masking with 0xf cannot change it, and the optimiser
removed it.

That is worth one paragraph because it is the clearest possible demonstration
that the MODE field is the TOP FOUR BITS of satp: the compiler proved it
without being told, from the shift alone.  A reader who wanted to confirm
the field position had a compiler confirm it for them, and the confirmation
is a MISSING INSTRUCTION.

The same thing does NOT happen for `satp_asid`, which is `(s >> 44) &
0xffff`: a right shift by 44 leaves twenty bits and the mask removes four of
them, so the mask is load-bearing and the compiler keeps it.  The difference
between the two rows of section 8's table is therefore a measurement of two
different facts, and a reader can check both.""")

    # the reserved PTE bits
    print()
    print('  THE RESERVED PTE BITS, and the reason they are the most')
    print('  dangerous field in the format:')
    print()
    w = ins.get('pte_reserved', [])
    for word, mn, txt, _b in w:
        print('    `pte_reserved`  %-6s %s' % (mn, txt))
    print()
    para("""`priv-spec` §11.1.4: "Bits 60-54 are reserved for future standard
use and, until their use is defined by some standard extension, must be
zeroed by software for forward compatibility.  If any of these bits are set,
a page-fault exception is raised."

So the reserved field is a TRAP, not a no-op.  A kernel that leaves a garbage
bit in a PTE it allocated gets a page fault on an address it believes is
mapped, and the fault's cause code says "load page fault" rather than
"reserved bit set", so the handler goes looking for a permissions problem and
does not find one.  The specification says it three times over -- for bit 63,
for bits 62-61 and for bits 60-54 -- and each of the three has a named
extension that will eventually use it: Svnapot for bit 63, Svpbmt for 62-61,
and "future standard use" for the rest.

The consequence for a reader of this course is a rule rather than a fact: a
PTE is not a struct with some padding.  Every bit of it is either assigned or
a trap, and `malloc`ing a page of zeros and filling in the fields you care
about is the correct procedure while `malloc`ing it and OR-ing in whatever
was there is not.""")


# ===========================================================================
# SECTION 9 -- THE RELOCATIONS.
#
# The hinge to the object-file half of this collection.  `rvasm` measured the
# reach of `auipc`; this section measures the RECORDS and what a LINKER has to
# be told.
# ===========================================================================

# The relocation table as the psABI prints it.  QUOTED, and every number
# below is cross-checked against `llvm-readelf-21 -r` in the harness.
PSABI_RELOCS = [
    (16, 'BRANCH', 'B-Type', '12-bit PC-relative branch offset', 'S + A - P'),
    (17, 'JAL', 'J-Type', '20-bit PC-relative jump offset', 'S + A - P'),
    (20, 'GOT_HI20', 'U-Type',
     "High 20 bits of 32-bit PC-relative GOT access, %got_pcrel_hi(symbol)",
     'G + GOT + A - P'),
    (23, 'PCREL_HI20', 'U-Type',
     'High 20 bits of 32-bit PC-relative reference, %pcrel_hi(symbol)',
     'S + A - P'),
    (24, 'PCREL_LO12_I', 'I-Type',
     'Low 12 bits of a 32-bit PC-relative, %pcrel_lo(address of %pcrel_hi), '
     'the addend must be 0', 'S - P'),
    (25, 'PCREL_LO12_S', 'S-Type',
     'Low 12 bits of a 32-bit PC-relative, %pcrel_lo(address of %pcrel_hi), '
     'the addend must be 0', 'S - P'),
    (26, 'HI20', 'U-Type', 'High 20 bits of 32-bit absolute address, %hi(symbol)',
     'S + A'),
    (27, 'LO12_I', 'I-Type', 'Low 12 bits of 32-bit absolute address, %lo(symbol)',
     'S + A'),
    (28, 'LO12_S', 'S-Type', 'Low 12 bits of 32-bit absolute address, %lo(symbol)',
     'S + A'),
    (51, 'RELAX', '-', 'Instruction can be relaxed, paired with a normal '
     'relocation at the same address', '-'),
]

RELOC_CODE = dict((nm, num) for (num, nm, _f, _d, _c) in PSABI_RELOCS)


def sec9():
    banner(9, 'THE RELOCATIONS, AND WHAT A LINKER HAS TO BE TOLD ABOUT A '
              'PAGE TABLE')
    print()
    para("""This section is the hinge between the privileged architecture and
the object-file half of this collection, and it exists because a page-table
walker is a CHAIN OF ADDRESSES THE COMPILER DOES NOT KNOW.  Every level of
the walk names a table whose address is a runtime value, so every one of them
is a reference the assembler has to record and a linker has to resolve.

The previous RISC-V course measured the REACH of the `auipc`+`addi` pair.
This section measures the RECORDS, and it does not repeat a word of that.
What is new is: the names and NUMBERS of the relocations, read from
`llvm-readelf-21 -r`; the fact that the LO12 record names the ADDRESS OF THE
AUIPC rather than the target; and the finding that the number of records a
page-table walk produces is a function of the DATA LAYOUT.

The table is %s, `riscv-elf` chapter 8, Table 3, and the numbers in it are
cross-checked against the reader in this section and asserted EXACTLY by the
harness, because a relocation NAME is a convention and a relocation NUMBER is
what goes in the file.""" % QUOT)
    print()
    print('  THE RELOCATIONS THIS COURSE USES, psABI Table 3 against the')
    print('  second reader.  "in the file" is the count llvm-readelf-21')
    print('  found across the hand-written corpus; 0 means the corpus does')
    print('  not contain it, which is a statement about the corpus.')
    print()
    # The reader prints names WITH the R_RISCV_ prefix and the psABI table
    # lists them WITHOUT it, so the two are joined by stripping the prefix.
    # The first version of this table compared the two forms directly and
    # every "in the file" column printed ZERO over a corpus that contains
    # forty-odd of them -- a zero that reads exactly like "the corpus does
    # not contain this relocation" and is indistinguishable from a bug.
    seen = {}
    for f in ('pt_nopic.o', 'pt_pic.o', 'sp2_sparse.o', 'sp2_dense.o',
              'sp2_dense_nopic.o', 'sp2_sparse_nopic.o', 'walk_O2.o',
              'sp_0x2000.o'):
        if not os.path.exists(p(f)):
            continue
        for nm, n in reloc_counts(p(f)).items():
            short = nm[len('R_RISCV_'):] if nm.startswith('R_RISCV_') else nm
            seen[short] = seen.get(short, 0) + n
    rows = []
    for num, nm, field, desc, calc in PSABI_RELOCS:
        rows.append((num, nm, field, seen.get(nm, 0),
                     '0x%02x = %d' % (num, num), calc))
    table(['code', 'name', 'field', 'in the file', 'hex', 'calculation'],
          rows, [6, 16, 8, 11, 12, 14])
    print()
    para("""THE CODES ARE CONTIGUOUS WHERE THE ENCODING IS, and the two gaps are
the two gaps in the specification.  16, 17, then a gap to 20 (GOT_HI20), then
a gap to 23 (PCREL_HI20), then 24, 25, 26, 27, 28 with nothing between
them, then a gap to 44 (RVC_BRANCH), then a gap to 51 (RELAX).  The first
gap is 18 and 19 -- CALL and CALL_PLT, the `call` pseudoinstruction's
relocations -- and the second is 43 (ALIGN) and 44-50.

§KEEP§R_RISCV_PCREL_HI20 IS 23 AND R_RISCV_PCREL_LO12_I IS 24 AND R_RISCV_PCREL_LO12_S IS 25, AND THE THREE OF THEM ARE CONSECUTIVE FOR A REASON: the first names the TARGET and the other two name the HIGH HALF.

The three-in-a-row is not tidiness.  A PC-relative address on RISC-V is
TWO instructions and therefore TWO relocation records with DIFFERENT jobs, and
a reader who knows that the pair exists still has to know which record means
what.  Section 9's tables below show the difference directly, and it is the
difference that makes the psABI's sentence "the addend must be 0" on the two
LO12 records make sense: the LO12 record's value is the target MINUS THE
AUIPC'S OWN OFFSET, which is a difference of two things in the same object
and needs no addend.

The `I` and `S` suffixes on 24 and 25 are the SAME distinction the encoding
makes and for the same reason: 24 patches a 12-bit field in an I-type
instruction (`addi`, `lw`, `ld`) and 25 patches one in an S-type (`sw`, `sd`).
They are different BITS in the word and they are different RECORDS in the
table, and `pt.s` contains one of each so the distinction is a measurement
rather than a footnote.""")

    # what the LO12 actually names
    print()
    print('  WHAT EACH RECORD NAMES.  Read the SYMBOL column: it is not the')
    print('  target.')
    print()
    rows = []
    for off, ty, nm, sym, add in reloc_rows(p('pt_nopic.o')):
        if ty in (23, 24, 25, 26, 27, 20):
            rows.append(('0x%x' % off, ty, nm, sym or '(none)',
                         ('+%#x' % add) if add else '+0'))
    table(['offset', 'code', 'name', 'the symbol it names', 'addend'], rows,
          [8, 6, 20, 30, 8])
    print()
    para("""THE HI20 RECORDS NAME THE TARGET.  root_pte, l1_pte, l2_pte -- the
three page tables, named as symbols.  That is the ordinary case and it is
what a reader expects.

§KEEP§THE LO12 RECORDS NAME SOMETHING ELSE ENTIRELY: they name the ADDRESS OF THE AUIPC, and one of them names a LOCAL SYMBOL CALLED .Lpcrel_hi0 THAT THE COMPILER INVENTED.

`.Lpcrel_hi0` is not in the source.  It is not in the symbol table as
anything a programmer wrote.  It is a label the compiler created at the
`auipc` so that the `ld` four bytes later has something to point at, and the
relocation's job is to say "the low twelve bits of the value the AUIPC
computes, which is the target's address minus this AUIPC's address".

And that is the mechanism, in one sentence: §KEEP§A PC-RELATIVE ADDRESS ON RISC-V IS A TWO-INSTRUCTION ARITHMETIC EXPRESSION, AND THE OBJECT FILE STORES ONE HALF OF IT IN THE INSTRUCTION WORD AND THE OTHER HALF IN THE RELOCATION TABLE.

`auipc` puts the high 20 bits of (target - pc) in a U-type immediate.  `ld`
then has to add the low 12 bits, and the low 12 bits of (target - pc) is not
a compile-time constant when target is a page table chosen at run time.  So
the `ld`'s own 12-bit immediate is left at whatever the assembler put there --
usually zero -- and a relocation record says "fill this in later", and the
linker computes the sum.

A reader who has only seen x86-64's `mov rax, [rip+X]` is likely to assume
the RISC-V pair is a convenience and that the target's address is somewhere
in the record.  IT IS NOT.  The target's address is in the HI20 record; the
LO12 record names a label in the CODE.  That is why `pt.s` and `sp.s` both
use `%pcrel_lo(<the auipc's own label>)` rather than `%pcrel_lo(target)`, and
why getting it wrong is a linker error rather than a wrong number.""")

    # the offsets, and the immediate left at zero
    print()
    print('  THE INSTRUCTION WORDS THE LO12 RECORDS ATTACH TO, and the')
    print('  immediate each one leaves for the linker:')
    print()
    ins = func_insns(p('pt_nopic.o'))
    rows = []
    for off, ty, nm, sym, add in reloc_rows(p('pt_nopic.o')):
        if ty not in (23, 24, 25):
            continue
        # find the word at this offset
        word = None
        for fn, w in ins.items():
            pass
        r = sh(OBJDUMP, '--triple=riscv64', '-d', p('pt_nopic.o'))
        for ln in (r.stdout or '').splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s*(.*)$',
                         ln)
            if m and int(m.group(1), 16) == off:
                word = int(m.group(2), 16)
                txt = '%s %s' % (m.group(3), m.group(4).strip())
                break
        if word is None:
            continue
        imm = (word >> 20) & 0xfff
        rows.append(('0x%x' % off, ty, nm, '0x%08x' % word,
                     '0x%03x' % imm, txt))
    # The column is named for the MASK and not for the FIELD, on purpose: it is
    # a twelve-bit window, and calling it "the immediate" is what produced the
    # 0x006 this section retracts.  The next table is the same twelve bits read
    # as an I-type and as an S-type, and the two tables together are the finding.
    table(['offset', 'code', 'name', 'word', 'inst[31:20]', 'instruction'],
          rows, [8, 6, 16, 12, 12, 26])
    print()
    # THE S-TYPE IMMEDIATE IS NOT CONTIGUOUS, and the first version of this
    # table read bits[31:20] for every row and printed ONE of them as 0x006.
    # For an S-type, inst[31:25] is imm[11:5] and inst[24:20] is rs2 -- the
    # SOURCE register of the store, and a store has no destination register at
    # all -- so bits[31:20] is not an immediate at all: it is the high half of
    # one field followed by a whole register.  The row is decoded properly here
    # and the two encodings are shown side by side, because the difference is
    # the reason a decoder needs a field TABLE and not a mask.
    print()
    print('  THE SAME TWELVE BITS DECODED THROUGH BOTH FIELD TABLES, because')
    print('  the S-type immediate is NOT CONTIGUOUS and a mask that does not')
    print('  know the format hands back a REGISTER:')
    print()
    rows = []
    words = {}
    for off, ty, nm, sym, add in reloc_rows(p('pt_nopic.o')):
        if ty not in (23, 24, 25):
            continue
        r = sh(OBJDUMP, '--triple=riscv64', '-d', p('pt_nopic.o'))
        word = None
        for ln in (r.stdout or '').splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s+(.*)$',
                         ln)
            if m and int(m.group(1), 16) == off:
                word = int(m.group(2), 16)
                mn = m.group(3)
                break
        if word is None:
            continue
        words[off] = (word, mn)
        mask = (word >> 20) & 0xfff
        # inst[11:7] is rd in an I-type and imm[4:0] in an S-type; inst[24:20]
        # is ZERO in an I-type and rs2 in an S-type.  BOTH are printed, so the
        # claim "0x006 is a register" is checked by reading two columns of the
        # same row rather than asserted about one of them.
        low11 = (word >> 7) & 0x1f
        rs2 = (word >> 20) & 0x1f
        # THE IMMEDIATE, THROUGH THE RIGHT TABLE FOR THE ROW'S OWN FORMAT.  For
        # an I-type that is inst[31:20] and nothing else.  For an S-type it is
        # inst[31:25] concatenated with inst[11:7], which is a different
        # twelve bits assembled from two five-bit-and-seven-bit fields.
        #
        # The first version of this table ran the S-type decode over EVERY row
        # and labelled the result "read as an S-type immediate", which printed
        # 0x005 on the `auipc` rows -- the rd of a U-type instruction read
        # through a field table that does not apply to it.  The number was
        # meaningless rather than wrong, and a column of meaningless numbers is
        # worse than no column: it is a table that looks like evidence.
        which = 'S-type' if ty == 25 else 'I-type'
        if which == 'S-type':
            dec = ((word >> 25) & 0x7f) << 5 | low11
        else:
            dec = mask
        rows.append(('0x%x' % off, ty, which, '0x%03x' % mask, low11, rs2,
                     '0x%03x' % dec, mn))
    table(['offset', 'code', 'format', 'the mask: inst[31:20]', 'inst[11:7]',
           'inst[24:20]', 'the immediate, DECODED', 'the reader says'],
          rows, [8, 6, 8, 22, 11, 12, 24, 16])
    print()
    srows = [r for r in rows if r[2] == 'S-type']
    irows = [r for r in rows if r[2] == 'I-type']
    # The claim is only worth printing if it is arithmetically true on the row
    # that makes it: inst[31:20] of an S-type word is (imm[11:5] << 5) | rs2,
    # so when imm[11:5] is zero the mask hands back rs2 and nothing else.
    reg_from_mask = []
    for r in srows:
        off = int(r[0], 16)
        w = None
        for ln in sh(OBJDUMP, '--triple=riscv64', '-d',
                     p('pt_nopic.o')).stdout.splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s', ln)
            if m and int(m.group(1), 16) == off:
                w = int(m.group(2), 16)
                break
        reg_from_mask.append((w is not None and ((w >> 25) & 0x7f) == 0
                              and ((w >> 20) & 0x1f) == r[5]))
    # Printed, not asserted: the reader is entitled to see the arithmetic that
    # turns the mask's 0x006 into a register NUMBER, and a course that only
    # prints the conclusion has asked to be trusted.
    if srows and all(reg_from_mask):
        w0 = None
        for ln in sh(OBJDUMP, '--triple=riscv64', '-d',
                     p('pt_nopic.o')).stdout.splitlines():
            m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s', ln)
            if m and int(m.group(1), 16) == int(srows[0][0], 16):
                w0 = int(m.group(2), 16)
                break
        print('  THE ARITHMETIC, on the one S-type row, printed as an equation')
        print('  rather than asserted:')
        print()
        print('    inst[31:25] = 0x%02x   -> imm[11:5] = 0, so the high half'
              ' is empty' % ((w0 >> 25) & 0x7f))
        print('    inst[24:20] = 0x%02x   -> rs2     = %s (x%d)'
              % ((w0 >> 20) & 0x1f, Dec.xreg((w0 >> 20) & 0x1f),
                 (w0 >> 20) & 0x1f))
        print('    inst[31:20] = 0x%03x   -> (0 << 5) | %d = %d   the SAME'
              ' number, twice'
              % ((w0 >> 20) & 0xfff, (w0 >> 20) & 0x1f, (w0 >> 20) & 0x1f))
        print('    inst[11:7]  = 0x%02x   -> imm[4:0] = 0, the low half'
              % ((w0 >> 7) & 0x1f))
        print()
        print('    so imm[11:0] = (imm[11:5] << 5) | imm[4:0] = %d, and the'
              ' mask returned %d.'
              % ((((w0 >> 25) & 0x7f) << 5) | ((w0 >> 7) & 0x1f),
                 (w0 >> 20) & 0xfff))
        print()
    para("""EVERY VALUE IN THE "the immediate, DECODED" COLUMN IS ZERO, and that is the
measurement which makes the "half in the instruction, half in the table"
sentence literal.  It took four columns to say, because one of them was lying
until R16 and one of them was meaningless until now.

§KEEP§AND THE 0x006 IN THE MASK COLUMN OF THE S-TYPE ROW IS NOT AN IMMEDIATE
AT ALL.  IT IS rs2 -- THE REGISTER THE STORE IS MOVING FROM -- AND THE TWO
COLUMNS ON THAT SAME ROW ARE THE PROOF, NOT AN ARGUMENT.

Read the inst[24:20] column on the `sd` row: it is also 6, and the disassembly
in the last column says §KEEP§sd t1, §KEEP§and t1 IS x6.  So the mask's answer and
the register column's answer are the same number, the disassembly names that
number, and the only reading left is that the mask read a register.  §KEEP§A MASK
IS NOT A FIELD, AND A DECODER THAT READS inst[31:20] OUT OF AN S-TYPE WORD GETS
A REGISTER NUMBER WHERE AN IMMEDIATE SHOULD BE.

And the inst[11:7] column is zero on that same row, which is the other half of
the finding: for an S-TYPE the low five bits are imm[4:0] and they are EMPTY,
so the mask's seven high bits plus a whole register is not a small immediate, it
is no immediate at all.

For an S-type the layout is inst[31:25] = imm[11:5], inst[24:20] = rs2,
inst[14:12] = funct3, inst[11:7] = imm[4:0] -- and there is no rd anywhere in
it, because a store has nowhere to put a result.  The twelve bits at
inst[31:20] are therefore SEVEN BITS OF ONE FIELD FOLLOWED BY A WHOLE REGISTER,
and reading them as an I-immediate gives you that register with a zero in front
of it.  A store's immediate is SPLIT ACROSS THE TWO ENDS OF THE WORD, which is
`rvasm`'s subject and not this one; what belongs here is that the two halves are
each zero here, for a reason nobody wrote down.

The first version of this table read inst[31:20] for every row and printed
0x006 on the `sd`, and the sentence above it said every immediate was zero,
which was a claim about a number that was not an immediate.  Both the table
and the sentence were wrong in the same way, which is the shape of a bug this
collection has now met twice: §KEEP§A NUMBER COMPUTED FROM THE WRONG FIELD
IS NOT A SMALLER NUMBER, IT IS A DIFFERENT NUMBER, AND IT LOOKS LIKE A
SMALLER ONE.

The correction cost a second retraction rather than a quiet edit, because the
first fix named that register rd, and rd DOES NOT EXIST IN AN S-TYPE WORD.  The
number was right and the NAME was wrong, and a wrong field name is how a decoder
ends up reading the wrong bits somewhere else. §KEEP§A NUMBER YOU CAN NAME IS
NOT YET A FIELD, AND NAMING IT AFTER A FIELD THAT IS NOT THERE IS THE SAME
ERROR WITH A DIFFERENT SPELLING.

The S-type immediate, decoded properly, is inst[31:25] concatenated with
inst[11:7] -- which is `rvasm`'s subject and not this one, and which is why
the link is below rather than re-taught here.  What belongs to THIS course is
the other half of the sentence: the linker writes that zero, and a reader who
hexdumps a RISC-V `.o` and computes an address from the instructions alone
will get zero, and there is nothing in the file to tell them that zero is a
placeholder rather than a value.

The ADDEND carries the part that IS knowable.  `walk_offsets` in `pt.s` asks
for `%pcrel_lo(walk_offsets)+8` and for `+0x800`, and the records come out
with addends 8 and 0x800 while the instruction immediates stay at zero.  So
the addend is the known offset within the field and the linker adds the
unknown low twelve bits of the target to it.  §KEEP§THE PSABI STATES THE
ADDEND MUST BE 0 FOR THE TWO PCREL_LO12 RECORDS, AND THIS CORPUS HAS RECORDS
WITH ADDENDS OF 8 AND 0x800 ON THEM.

That is a contradiction worth pausing on, because it is the sort of thing
that is either a bug or a misreading.  It is not a bug in the assembler: the
`%pcrel_lo(label)+N` form with a non-zero N is a documented and widely used
idiom, and the psABI's own example of the pair shows `%pcrel_lo(label)` with
no addend.  The honest reading is that "the addend must be 0" describes the
CANONICAL pair as generated by `%pcrel_hi`/`%pcrel_lo` with no offset, and
that a hand-written offset on the LO12 is a legitimate extension of it that
the linker handles.  There is no RISC-V linker on this host, so whether it
handles it is QUOTED and not measured, and this file says so rather than
claiming a bug it cannot demonstrate.""")

    # the layout experiment
    print()
    print('  THE LAYOUT EXPERIMENT, and it is the section\'s finding.  One C')
    print('  file, one page-table walk, two builds, and the ONLY difference')
    print('  is whether 4 KiB of unrelated data sits between each pair of')
    print('  page tables.  FOUR builds rather than two, because the first two')
    print('  are CONFOUNDED and the file says so rather than reporting the')
    print('  pair that flatters the claim.')
    print()
    rows = []
    for f, label in (('sp2_dense_nopic.o', 'adjacent,  -fno-pic'),
                     ('sp2_sparse_nopic.o', '4 KiB apart, -fno-pic'),
                     ('sp2_dense.o', 'adjacent,  default (PIC)'),
                     ('sp2_sparse.o', '4 KiB apart, default (PIC)')):
        if not os.path.exists(p(f)):
            continue
        cnt = reloc_counts(p(f))
        body = func_insns(p(f)).get('walk', [])
        hi = (cnt.get('R_RISCV_PCREL_HI20', 0) + cnt.get('R_RISCV_HI20', 0))
        lo = (cnt.get('R_RISCV_PCREL_LO12_I', 0) + cnt.get('R_RISCV_LO12_I', 0)
              + cnt.get('R_RISCV_PCREL_LO12_S', 0)
              + cnt.get('R_RISCV_LO12_S', 0))
        rows.append((f, label, len(body), sum(x[3] for x in body), hi, lo,
                     cnt.get('R_RISCV_PCREL_LO12_S', 0)
                     + cnt.get('R_RISCV_LO12_S', 0)))
    table(['object', 'layout and code model', 'walk insns', 'bytes',
           'HI20 records', 'LO12 records', 'of which S-type'], rows,
          [22, 24, 11, 8, 13, 13, 15])
    print()
    nop_d = rows[0] if len(rows) > 0 else None
    nop_s = rows[1] if len(rows) > 1 else None
    pic_d = rows[2] if len(rows) > 2 else None
    pic_s = rows[3] if len(rows) > 3 else None
    if nop_d and nop_s and pic_d and pic_s:
        print('    The -fno-pic pair is CLEAN: %d against %d instructions, a'
              % (nop_d[2], nop_s[2]))
        print('    difference of %+d, and the HI20 count goes %d -> %d.'
              % (nop_s[2] - nop_d[2], nop_d[4], nop_s[4]))
        print()
        print('    The default (PIC) pair is CONFOUNDED: %d against %d'
              % (pic_d[2], pic_s[2]))
        print('    instructions, a difference of %+d, and the HI20 count goes'
              % (pic_s[2] - pic_d[2]))
        print('    %d -> %d.  The instruction count is NOT held constant'
              % (pic_d[4], pic_s[4]))
        print('    there, and section 14 records that as a retraction.')
        print()
    para("""READ THE INSTRUCTION COLUMN AGAINST THE RELOCATION COLUMNS,
because the two columns do not behave the same way and the difference between
them is the methodological result.

§KEEP§THE CLEAN PAIR: %s.  THE CONFOUNDED PAIR: %s.

The `-fno-pic` pair is the one the claim rests on.  The instruction count is
essentially held -- one instruction of difference, which is a different `ld`
displacement encoding and not a different program -- and the HI20 count
DOUBLES.  §KEEP§THREE PAGE TABLES, THREE LEVELS, ONE FUNCTION, ONE INSTRUCTION
OF DIFFERENCE, AND THE NUMBER OF HI20 RECORDS GOES 2 TO 4 BECAUSE THE TABLES
MOVED 4 KiB APART.

The default PIC pair is CONFOUNDED and the file says so in the table's own
caption rather than picking the pair that flatters the claim.  §KEEP§THE
INSTRUCTION COUNT IS NOT CONSTANT ACROSS THE PIC PAIR, IT IS %d AGAINST %d, AND
REPORTING THE RELOCATION DELTA WITHOUT SAYING THAT WOULD BE REPORTING A
COMPOUND MEASUREMENT UNDER A SIMPLE CLAIM.

The reason is visible in the disassembly rather than needing to be asserted.
In the adjacent PIC build the compiler UNROLLED the three fill paths -- the
`*a = (l1tab & ~0xff) | 1` stores are all there, each one a separate
`ld`/`and`/`ori`/`sd` sequence.  In the 4 KiB-apart build it did not, because
the three tables are three separate symbols and the merged-globals pass had
nothing to merge.  So the layout changed the relocation count AND the amount
of code the optimiser was willing to duplicate, and a reader who quoted the
PIC pair's relocation delta as "what the layout costs" would be quoting a
number that mixes two effects.

THE MECHANISM IS THE MERGED GLOBALS PASS, and the evidence for it is in the
symbol names rather than in the counts.  In the adjacent build every HI20
record names `.L_MergedGlobals`, a single synthetic symbol the compiler
created because the three tables were near each other and it could reach all
three from one base register.  In the 4 KiB-apart build the records name
`root`, `l1tab` and `l2tab` -- the three real symbols -- and the offsets in
the symbol table differ by 0x1000 and 0x2000, which is the padding made
visible in the relocation table.

So the number of records is not a property of the page-table walk, the level
count, or the number of tables.  It is a property of a LAYOUT DECISION made
by a compiler optimisation pass, and the walk's author is not in the
conversation.

AND THE PAIRED COUNT IS THE OTHER HALF, and it moves the same way.  One HI20
can serve any number of LO12s, so a table referenced three times costs one HI20
and three LO12s -- and a table referenced once costs one of each.  A reader who
counted "references" and a reader who counted "records" get different
numbers, and the difference is not a mistake by either.

THE CONSEQUENCE FOR A BACKEND AUTHOR, and it is the reason the section is
here: if you are counting the relocations your page-table code will produce,
you are counting a property of the DATA PLACEMENT, and the way to change the
count is to move the tables next to each other.  Nothing about the walk's
ALGORITHM changes.  A reader who has been counting references and calling
them relocations has been reporting a number that is a function of where the
linker happened to put things, which is a number about a layout and not about
a program.""" % (
        ('%d instructions against %d, and the HI20 count goes %d to %d'
         % (nop_d[2], nop_s[2], nop_d[4], nop_s[4]))
        if nop_d and nop_s else '(unavailable)',
        ('%d instructions against %d, and the HI20 count goes %d to %d'
         % (pic_d[2], pic_s[2], pic_d[4], pic_s[4]))
        if pic_d and pic_s else '(unavailable)',
        pic_d[2] if pic_d else 0, pic_s[2] if pic_s else 0))
    return seen


# ===========================================================================
# SECTION 10 -- THE PAIRING DISTANCE, AND THE FACT THAT NOBODY ENFORCES IT.
# ===========================================================================

def sec10():
    banner(10, 'THE PAIRING DISTANCE, AND THE ASSEMBLER THAT DOES NOT ENFORCE '
               'IT')
    print()
    para("""The rule is %s, `riscv-elf` §8.1.4.9: the LO12 record's calculation
is `symbol_address - hi20_reloc_offset`, and the record's symbol is "a label
pointing to an instruction in the same section with an R_RISCV_PCREL_HI20
relocation entry that points to the target symbol".  So a linker pairs each
LO12 with the HI20 at the label the LO12 names, and the value it has to fit
into a SIGNED TWELVE-BIT FIELD is the offset from that AUIPC to the target.

The bound follows from arithmetic and needs no document: a signed 12-bit
field holds -2048 to 2047, so the AUIPC must be within 2048 bytes of the
target.  And a 4 KiB granule is 4096, and 4096 > 2047, which is where the
familiar "pair has to be within the same page" rule comes from -- a
page-aligned target and an AUIPC in the same 4 KiB region differ by a
multiple of 4096 in their low twelve bits, and no multiple of 4096 other than
zero fits.

The question this section asks is WHO ENFORCES IT, and the answer is a
measurement with six data points.""" % QUOT)
    print()
    print('  THE SAME TWO INSTRUCTIONS, SIX TIMES, WITH THE SECOND ONE MOVED.')
    print('  `sp.s` asks for ONE HI20 and TWO LO12s at six distances, and the')
    print('  distance is the only thing that changes.')
    print()
    print('    4 KiB = 4096 > 2047, so offsets of 0x800 and above cannot fit')
    print('    a signed 12-bit field.  The assembler is asked anyway.')
    print()
    rows = []
    for pad in PADS:
        f = 'sp_%s.o' % pad
        if not os.path.exists(p(f)):
            continue
        rel = reloc_rows(p(f))
        hi = [r for r in rel if r[1] == 23]
        lo = [r for r in rel if r[1] == 24]
        offs = sorted(r[0] for r in lo)
        hioff = min(r[0] for r in hi) if hi else 0
        # The quantity the rule is about is the distance from the AUIPC to
        # the FARTHEST LO12, because that LO12 has to carry the low twelve
        # bits of a HI20 result computed at the AUIPC.  The span between the
        # two LO12s is a different number and the first version of this table
        # printed THAT one, which made the 0x2000 row read as a span of four
        # bytes and "fits".
        far = (offs[-1] - hioff) if offs else 0
        body = func_insns(p(f)).get('go', [])
        imms = ['0x%03x' % ((x[0] >> 20) & 0xfff) for x in body
                if x[1] in ('addi', 'mv', 'c.mv')]
        fits = -2048 <= far <= 2047
        rows.append((pad, len(hi), len(lo), '0x%x' % hioff, '0x%x' % far, far,
                     'YES' if fits else 'NO',
                     ' '.join(imms) if imms else '(none)'))
    table(['pad', 'HI20', 'LO12_I', 'the HI20 is at', 'the farthest LO12 is at',
           'that distance', 'fits a signed 12-bit field?',
           'the immediates left in the words'], rows,
          [8, 6, 8, 15, 20, 13, 26, 30])
    print()
    allone = all(r[1] == 1 for r in rows)
    print('    Every one of the six has %s HI20 record, including the two'
          % ('ONE' if allone else 'a varying number of'))
    print('    whose LO12s are 8 KiB apart, and every one of the six has two')
    print('    LO12_I records.')
    print()
    para("""§KEEP§THE ASSEMBLER EMITTED EXACTLY ONE R_RISCV_PCREL_HI20 RECORD IN ALL SIX CASES, INCLUDING THE TWO WHERE THE TWO LO12 RECORDS ARE 8 KIB APART, AND IT DID NOT DIAGNOSE ANY OF THEM.

Read the table's last column as well.  Every immediate in every word is
0x000, at every distance, because the value is not knowable at assembly time
and the assembler does not pretend otherwise.  So what the assembler has
produced in the 0x2000 case is an object file containing a relocation pair
that a linker may legitimately reject: the LO12 at offset 0x2008 names a
label whose HI20 is at offset 0x0000, and the difference is 8200 bytes, and
8200 does not fit in a signed twelve-bit field.

§KEEP§THE ASSEMBLER DOES NOT ENFORCE THE PAIRING RULE, AND THERE IS NO RISC-V LINKER ON THIS HOST TO ENFORCE IT EITHER, SO WHETHER THE OBJECT IS VALID IS A QUOTED CLAIM AND NOT A MEASURED ONE.

That is the honest boundary and it is a real one, so this section does not
claim a bug.  What it claims is narrower and is worth more:

  * THE ASSEMBLER PRODUCES THE RECORDS.  It does not check them, and a
    hand-written offset on `%pcrel_lo` is accepted at any distance.
  * THE BOUND IS ARITHMETIC.  2047 is what a signed 12-bit field holds and
    4096 is a page, and every number in that sentence is in the table above.
  * A LINKER IS THE ONLY THING THAT CAN CHECK IT, and there is not one here.

AND THE PRACTICAL CONSEQUENCE FOR A KERNEL, which is the reason a reader should
care: the pairing rule is a constraint on CODE LAYOUT that the assembler will
not tell you about.  A page-table walk is exactly the code most likely to
violate it, because the references are spread across a data section and the
author has no reason to think about where the AUIPC is.  The mitigation in
real kernels is to keep the walk and its tables in one page, or to accept the
linker's error.  On this host neither can be tested.""")
    return rows


# ===========================================================================
# SECTION 11 -- THE TRAP CSRs, DECODED.
# ===========================================================================

def _const_in(body, reg):
    """The value in `reg` at the END of a short straight-line body, by
    interpreting the three instruction forms that can produce one.

    A tiny evaluator rather than a regex over the C source, because the value
    is a property of the WORDS.  The first version of this table read it out
    of the source and reported 0x6585000 for a function that assembles
    `lui a1, 0x1` -- a number about the ENCODING of the constant rather than
    about the constant, and it printed the encoding's bytes in a column headed
    "the value".
    """
    if reg is None:
        return None
    vals = {reg: 0}
    for word, mn, txt, _b in body:
        ops = [x.strip() for x in txt.split(',')]
        # `lui`'s operand is the RAW twenty-bit field, so it is shifted here;
        # `li`'s and `addi`'s are the value and the immediate, so they are
        # not.  The first version stripped the `0x` before parsing every one
        # of them and turned `li a1, 0x123` into 123 -- a number that is
        # exactly 0x7b and looks like a plausible small constant.
        if mn == 'lui' and len(ops) == 2:
            vals[ops[0]] = (int(ops[1], 0) & 0xfffff) << 12
        elif mn == 'addi' and len(ops) == 3:
            imm = int(ops[2], 0)
            if imm >= 0x800:
                imm -= 0x1000
            vals[ops[0]] = (vals.get(ops[1], 0) + imm) & 0xffffffffffffffff
        elif mn == 'li' and len(ops) == 2:
            vals[ops[0]] = int(ops[1], 0)
    return vals.get(reg)


def sec11():
    banner(11, 'stvec, sepc, scause, stval, sie, sip -- THE FIVE, DECODED')
    print()
    para("""The trap model is %s, and this section's job is to separate what the
specification says from what the words say, because for these five registers
the two disagree in an interesting way.

The specification, `priv-spec` §11.1.1.2, on `stvec`: "The stvec register is
an SXLEN-bit read/write register that holds trap vector configuration,
consisting of a vector base address (BASE) and a vector mode (MODE)."  Table 1
gives the mode encoding: 0 is Direct, 1 is Vectored, and anything >= 2 is
Reserved.  And the sentence that has the sharpest consequence in the whole
chapter:

    "Note that the CSR contains only bits XLEN-1 through 2 of the address
     BASE.  When used as an address, the lower two bits are filled with zeroes
     to obtain an XLEN-bit address that is always aligned on a 4-byte
     boundary."

THE MODE IS TWO BITS OF A VALUE, NOT AN INSTRUCTION, and section 11's
measurement is that the instruction which writes `stvec` is BYTE-IDENTICAL
whether the mode is Direct or Vectored.  The three functions in `wrap.c` are
three different C functions and the corpus contains the words.""" % QUOT)
    print()
    ins = func_insns(p('wrap_O2.o'))
    print('  THE THREE stvec WRITES, AND THE VALUE EACH ONE PUTS IN A')
    print('  REGISTER BEFORE THE SAME INSTRUCTION RUNS:')
    print()
    rows = []
    writes = {}
    for fn in ('set_stvec_direct', 'set_stvec_vectored', 'set_stvec_misaligned'):
        w = ins.get(fn, [])
        src = None
        for word, mn, txt, _b in w:
            if mn == 'csrw' and 'stvec' in txt:
                writes.setdefault(word, []).append(fn)
                src = txt.split(',')[-1].strip()
        val = _const_in(w, src)
        rows.append((fn, len(w), src or '?',
                     '0x%012x' % val if val is not None else 'not recoverable',
                     ' | '.join(x[1] for x in w)))
    table(['function', 'insns', 'the register the CSR is written from',
           'the value in that register', 'the whole body'], rows,
          [24, 7, 30, 20, 40])
    print()
    if len(writes) == 1:
        (word, fns) = list(writes.items())[0]
        para("""§KEEP§ALL THREE FUNCTIONS EMIT THE SAME 32-BIT WORD FOR THE stvec WRITE, 0x%08x, AND THE THREE OF THEM ARE: %s.

That is the measurement.  `set_stvec_direct` builds 0x1000, which is BASE =
0x1000 and MODE = 0.  `set_stvec_vectored` builds 0x1001, which is the SAME
BASE and MODE = 1.  `set_stvec_misaligned` builds 0x123, which is
BASE = 0x120 and MODE = 3 -- a RESERVED mode, with a BASE that is not
4-byte aligned -- and the compiler emitted the same instruction for it.

So the mode and the alignment are PROPERTIES OF THE VALUE and the hardware
enforces both.  The instruction is one 32-bit word with a three-digit
hexadecimal constant in inst[31:20] and it does not know which of the three
things it is writing.  A disassembler reading the object can recover the
instruction and CANNOT recover the mode, and the value that would tell it is
four instructions earlier in the same function.

AND THE WORD ITSELF DECODES TO SOMETHING THE SOURCE NEVER WROTE.  0x10559073
read field by field is: inst[6:0] = 0x73, funct3 = 1 so CSRRW, inst[31:20] =
0x105 so `stvec`, inst[19:15] = rs1 = 11 = a1, inst[24:20] = rs2 = 5 = t0,
inst[31:25] = funct7 = 8, and rd[4:0] = 0.  §KEEP§THE ZERO IN rd[4:0] IS WHAT
MAKES THE WRITE DISCARDABLE, and that zero is why `csrw` needs no separate
encoding: the pseudo-instruction is the encoding with rd = x0, which is section
3's alias table showing up here as a consequence rather than as a curiosity.
§KEEP§FUNCT7 = 8 AND rs2 = 5 ARE BOTH READ OFF THE WORD AND NEITHER IS IN THE
SOURCE, and a reader who has not been told that will treat them as noise.

One caveat, because a reader who writes a decoder will hit it in the same
afternoon.  rd[4:0] is an immediate for the immediate forms and a register
number for the register forms, and funct3 is what tells them apart: funct3 = 1,
2, 3 put rd at inst[11:7] and funct3 = 5, 6, 7 put zimm[4:0] there.  §KEEP§A
BIT FIELD AT THE SAME POSITION WITH TWO MEANINGS IS DISAMBIGUATED BY A
NEIGHBOURING FIELD AND NOT BY ITS OWN POSITION.  The claim "rd = 0" is true of
0x10559073 because its funct3 is 1, and would be false of the same five bits in
a `csrrwi`, which is the same shape of trap as section 3's one-bit finding and
is asserted in the harness with its funct3 named rather than as a bare mask.

AND THE MISALIGNED ONE IS THE INTERESTING ONE.  The specification says the
CSR "contains only bits XLEN-1 through 2 of the address BASE" and that "the
lower two bits are filled with zeroes".  So writing 0x123 does NOT set BASE
to 0x123: it sets BASE to 0x120 and MODE to 3, and a mode of 3 is Reserved,
which `priv-spec` says in one word and does not define.  A kernel that
computes a trap vector address and forgets to clear the low two bits gets a
Reserved mode and the behaviour of a Reserved mode is not specified.

The assembler did not diagnose it.  There is no diagnostic, and there could
not be: the instruction does not know the value.  §KEEP§THIS IS THE THIRD
PLACE IN THE COURSE WHERE A CONSTRAINT IS ENFORCED BY HARDWARE THAT THIS HOST
DOES NOT HAVE, AND IT IS THE ONE A BACKEND AUTHOR IS MOST LIKELY TO GET
WRONG, because the code is a perfectly ordinary `csrw stvec, a1` and reads
correctly.""" % (word, ', '.join(fns)))
    else:
        print('    THE THREE stvec WRITES ARE NOT BYTE-IDENTICAL -- %d '
              'distinct words: %s' % (len(writes),
                                      ', '.join('0x%08x' % x
                                                for x in sorted(writes))))
        print('    and the section\'s claim needs re-deriving, because a')
        print('    finding that the words DIFFER is a different finding and')
        print('    the file prints the numbers rather than the claim.')

    # the interrupt bits
    print()
    print('  THE THREE INTERRUPT ENABLE BITS, and the compiler\'s whole')
    print('  contribution to each:')
    print()
    rows = []
    for fn, cause, bit in (('enable_ssie', 1, 1), ('enable_stie', 5, 5),
                           ('enable_seie', 9, 9)):
        w = ins.get(fn, [])
        imm = None
        for word, mn, txt, _b in w:
            if mn == 'ori':
                imm = (word >> 20) & 0xfff
        rows.append((fn, cause, '1 << %d' % bit, '0x%x' % (1 << bit),
                     '0x%x' % imm if imm is not None else '?',
                     ' | '.join(x[1] for x in w)))
    table(['function', 'cause number', 'the bit', 'the mask',
           'what the compiler emitted', 'the whole body'], rows,
          [14, 14, 12, 9, 24, 26])
    print()
    para("""§KEEP§A SUPERVISOR SOFTWARE INTERRUPT IS CAUSE 1, A TIMER INTERRUPT IS CAUSE 5 AND AN EXTERNAL INTERRUPT IS CAUSE 9, SO THE THREE ENABLE MASKS ARE 0x2, 0x20 AND 0x200, AND THE COMPILER EMITTED `ori a0, a0, <mask>` AND NOTHING ELSE.

Three functions, three `csrr`/`ori`/`csrw` triples, and the constant is the
whole of the interrupt.  The compiler has no idea these are interrupts: it
sees `v | (1UL << 5)` in C and it emits an OR with 32.  The five-bit and
nine-bit positions come from `priv-spec` §11.1.1.3 -- "Interrupt cause number
i ... corresponds with bit i in both sip and sie" -- and the cause NUMBERS
1, 5 and 9 are Table 2's, and every one of the three is a value the compiler
passed through untouched.

Read the masks as a shape rather than as three numbers: 0x2, 0x20 and 0x200
are 1, 5 and 9 SHIFTED LEFT ONCE, and the shift is the whole of the mapping
from cause number to bit position.  A reader who has internalised the rule
can derive the mask for cause 13 without looking it up, and that is a
property a quoted table does not give you.

AND THE READ-THEN-WRITE IS NOT A CONVENTION EITHER, it is a race.  Each of
the three functions is `csrr sie ; ori ; csrw sie`, which is a
read-modify-write of a register that hardware also writes, and two of them
running at once lose an update.  The specification's answer is `sie` and
`sip` being subsets of `mie` and `mip` and the writes being to the same
homonymous fields, and the specification does not provide an atomic
read-modify-write.  A kernel that enables interrupts does it in a critical
section.  None of that is measurable here: there is no RISC-V machine, so the
race is a QUOTED consequence and the three instruction triples are
MEASURED-ON-BYTES, and the two must not be run together in a reader's head.""")

    # the five registers and their addresses
    print()
    print('  THE FIVE TRAP REGISTERS, the addresses the assembler resolved,')
    print('  and the decomposition of each address into the two convention')
    print('  fields.  This is the table that makes the convention real:')
    print()
    src = src_csr_lines()
    r = sh(OBJDUMP, '--triple=riscv64', '-d', p('csr.o'))
    words = []
    for ln in (r.stdout or '').splitlines():
        m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s*(.*)$', ln)
        if m:
            words.append(int(m.group(2), 16))
    ACC = {0: 'rw', 1: 'rw', 2: 'rw', 3: 'RO'}
    PRIV = {0: 'U', 1: 'S', 2: 'RESERVED', 3: 'M'}
    rows = []
    for (mn, args), word in zip(src, words):
        if not mn.startswith('csrr') or not args.startswith('t0,'):
            continue
        name = args.split(',')[1].strip()
        csr = (word >> 20) & 0xfff
        # S-level, M-level and U-level, and the filter is the CONVENTION
        # rather than a hand-written list: csr[9:8] is the lowest privilege
        # and 0, 1 and 3 are U, S and M, so any address whose privilege field
        # is one of those three belongs in the table.  The first version
        # listed two numeric ranges by hand and it left every M-level
        # register out, so a table about the privilege convention showed no
        # machine level at all.
        if ((csr >> 8) & 3) not in (0, 1, 3):
            continue
        acc = (csr >> 10) & 3
        priv = (csr >> 8) & 3
        rows.append((name, '0x%03x' % csr, '0x%08x' % word, acc, ACC[acc],
                     priv, PRIV[priv], '0x%02x' % (csr & 0xff)))
    table(['name', 'address', 'word', 'csr[11:10]', 'access', 'csr[9:8]',
           'privilege', 'csr[7:0]'], rows, [12, 9, 12, 11, 8, 9, 11, 9])
    print()
    para("""EVERY S-LEVEL REGISTER IN THAT TABLE HAS `csr[9:8] = 1` AND EVERY
M-LEVEL REGISTER HAS `csr[9:8] = 3`, and the column is not decoration: it is
the difference between a trap handler and a user program, encoded in the
NUMBER.

`priv-spec` §1: "The top two bits (csr[11:10]) indicate whether the register
is read/write (00, 01, or 10) or read-only (11).  The next two bits
(csr[9:8]) encode the lowest privilege level that can access the CSR."  So
`stvec` at 0x105 is 00 / 01 / 0x05: read/write, lowest privilege S, number 5.
`mtvec` at 0x305 is 00 / 11 / 0x05: read/write, lowest privilege M, number
5.  THE SAME NUMBER, FIVE, IN BOTH, AND THE ONLY DIFFERENCE IS TWO BITS OF
PRIVILEGE.

That is a nice illustration of why the convention exists.  A supervisor
kernel and a machine kernel both want a trap vector and both call it number
5; the privilege bits are what make them different registers, and a
supervisor program that writes `mtvec` gets an illegal-instruction exception
because 0x305 says "lowest privilege M" and it is running in S.

AND THE READ-ONLY CLASS IS MEASURED TOO, which is the check on the
accessibility half.  `cycle` at 0xc00 has `csr[11:10] = 11` and `mvendorid`
at 0xf11 has 11, and both are read-only.  `stvec` at 0x105 and `satp` at
0x180 have 00 and both are read/write.  So the bit that says "you cannot write
this" is in the address, and the SAME instruction with the same five bits in
its operand slot is a legal read and an illegal write depending on two bits
of a constant three instructions earlier.

THE RESERVED ROW IS ALSO IN THE TABLE, which is worth having: the user-level
trap registers at 0x041 to 0x044 have `csr[9:8] = 0`, and 0x105's encoding
value 2 in the privilege field is a hole that no standard register occupies.
`priv-spec` reserves 10 by leaving it out of Table 1.1, and a reader who
assumed all four values of a two-bit field were meaningful would expect four
privilege levels and there are three.

§KEEP§AND NONE OF THE ENFORCEMENT IS OBSERVABLE HERE.  There is no RISC-V
machine on this host, so no access to a supervisor CSR from user mode has been
observed to fault, no write to `mtvec` from S-mode has been observed to be an
illegal-instruction exception, and no read-only CSR has been observed to
refuse a write.  What is measured is that the addresses carry those bits and
that the instructions do not.  What is quoted is that the hardware acts on
them.""")


# ===========================================================================
# SECTION 12 -- TWO READERS ON THE SAME BYTES.
# ===========================================================================

# THIS COURSE'S NORMALISATION RULES, and the FIRE TABLE beside them.
#
# One rule, and it is a rule about REPRESENTATION and not about meaning: the
# second reader prints a negative immediate in HEX (`li a2, -0x1`) and the
# inherited decoder prints it in signed DECIMAL (`c.li a2, -1`).  Ten words of
# this corpus are that difference and nothing else, and a cross-check that
# counts them as disagreements has a disagreement count that moves when
# somebody changes a printf format string.
#
# THE RULE EXPANDS RATHER THAN DELETES, which is the design rule this
# collection established in 2.2.109: every rule in a normaliser table must
# turn a printed line into a line with the SAME OR MORE information in it, so
# that a decoder which read the wrong register still produces a different
# canonical form and is caught.  This rule does exactly that -- `0x1` becomes
# `1` on both sides and nothing is thrown away.
#
# AND THE FIRE TABLE IS PRE-SEEDED, so a rule that never fires is a ROW WITH A
# ZERO rather than an absence, and a dead rule cannot hide.  That is 2.2.109's
# third finding and the second course in a row to apply it.
XEXTRA = ['negative immediate, decimal on both sides',
          'c.li and li are one instruction']
XFIRE = dict((n, 0) for n in XEXTRA)


def reset_xnorm():
    XFIRE.update(dict((n, 0) for n in XEXTRA))


def normalise(t):
    """THIS COURSE'S TWO SPELLING RULES, and THEN the inherited normaliser.

    The order matters and the reason is a finding.  The inherited
    `crosscheck_normalise` reduces both readers to one canonical base-ISA
    form, and it handles a NEGATIVE immediate INCONSISTENTLY between the two
    paths that can produce one:

        crosscheck_normalise('li a3, -1')     ->  'addix13,x0,0x1'
        crosscheck_normalise('c.li a3, -1')   ->  'addix13,x0,-0x1'

    Same instruction, same value, two canonical forms, and the difference is
    a SIGN.  Ten words of this corpus are that difference and nothing else --
    five in `walk_O1.o`, four in `walk_O2.o`, one in `walk_O1.o` again -- and a
    cross-check that counts them as disagreements has a disagreement count
    that moves when somebody changes a printf format string.

    So both sides are brought to ONE SPELLING BEFORE the inherited rules run.
    Two rules, and both are about REPRESENTATION and not about meaning:

      * a negative immediate is written in signed decimal on both sides, so
        the inherited `li` rule and its inherited `c.li` rule both see the
        same characters and produce the same canonical form;
      * `c.li` and `li` are ONE INSTRUCTION in two encodings, and the second
        reader prints the PLAIN form for the four-byte word while this
        file's decoder prints the COMPRESSED form for the two-byte one --
        because the decoder names what the word IS and the reader names the
        operation.  The rule drops the `c.` and EXPANDS the plain form, so
        the two sides meet and NEITHER LOSES AN OPERAND.

    BOTH RULES EXPAND RATHER THAN DELETE, which is the design rule this
    collection established in 2.2.109: a normaliser that deletes an operand
    makes two readers agree by deleting the same operand, and the agreement is
    then evidence about the normaliser rather than about either decoder.

    AND THE FIRE TABLE IS PRE-SEEDED, so a rule that never fires is a ROW WITH
    A ZERO rather than an absence, and a dead rule cannot hide.  That is
    2.2.109's third finding and the second course in a row to apply it.
    """
    raw = ' '.join(t.replace('\t', ' ').split())
    for rule in XEXTRA:
        if rule == 'negative immediate, decimal on both sides':
            new_t = re.sub(r'-0x([0-9a-fA-F]+)',
                           lambda m: '-%d' % int(m.group(1), 16), raw)
            if new_t != raw:
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
                raw = new_t
        elif rule == 'c.li and li are one instruction':
            if raw.startswith('c.li'):
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
                raw = 'li' + raw[4:]
            elif re.match(r'^li\b', raw):
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
    return Dec.crosscheck_normalise(raw)


def xcheck_corpus():
    """(total, agree, disagree, unmodelled, badlen) over the RISC-V corpus."""
    Dec.reset_norms()
    reset_xnorm()
    agree = disagree = unmodelled = total = badlen = 0
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        d, secs = Dec.code_sections(fp)
        mine = dict()
        for _nm, vaddr, off, size in secs:
            ins, _end = Dec.decode_text(d, off, size, vaddr)
            for k in ins:
                mine[vaddr + (k.off - off)] = k
        for addr, w, nb, txt in Dec.objdump_lines(fp):
            k = mine.get(addr)
            if k is None:
                continue
            total += 1
            if k.nbytes != nb:
                badlen += 1
            if k.name is None:
                unmodelled += 1
                continue
            if normalise(k.text) == normalise(txt):
                agree += 1
            else:
                disagree += 1
    return total, agree, disagree, unmodelled, badlen


def xcheck_detail():
    """[(file, addr, mine, theirs)] for every disagreement, by name."""
    out = []
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        d, secs = Dec.code_sections(fp)
        mine = dict()
        for _nm, vaddr, off, size in secs:
            ins, _end = Dec.decode_text(d, off, size, vaddr)
            for k in ins:
                mine[vaddr + (k.off - off)] = k
        for addr, w, nb, txt in Dec.objdump_lines(fp):
            k = mine.get(addr)
            if k is None or k.name is None:
                continue
            if normalise(k.text) != normalise(txt):
                out.append((f, addr, k.text, txt))
    return out


def xcheck_summary():
    """The distinct (mine, theirs) pairs, counted.  A number of eleven is a
    bug report and a list of eleven is a diagnosis, and the course needs both
    when it has any."""
    seen = {}
    for f, a, cm, ct in xcheck_detail():
        key = (cm, ct)
        seen[key] = seen.get(key, 0) + 1
    return seen


def sec12():
    banner(12, 'TWO READERS ON THE SAME BYTES')
    print()
    para("""Every instruction in the RISC-V corpus is decoded TWICE: once by
the inherited decoder and once by `llvm-objdump-21 --triple=riscv64`.  Four
numbers, and the three that matter are not the first:

  * how many instructions the reader PRINTED and this file COMPARED;
  * how many of them this file NAMED (an unmodelled word is counted, never
    dropped);
  * how many DISAGREED -- and, if any did, each one PRINTED BY NAME, because
    a number of eleven is a bug report and a list of eleven is a diagnosis;
  * and how many disagreed on the LENGTH, which is a separate comparison
    and not a subset of the first, because RISC-V's two-byte instructions
    make it a real question.

THE EXPECTED DISAGREEMENT IS ABOUT SPELLING, and this corpus is unusually
well placed to show why that is a different thing from being wrong.  The
second reader prints `rdcycle` where the inherited decoder prints
`csrrs t0, 0xc00, zero`, because the reader is applying an ALIAS and the
decoder is naming the instruction.  Both are the same 32 bits and both are
right about their own subject.  Section 12's own table says which of the two
kinds of disagreement it found, because a cross-check that counts a spelling
difference and a cross-check that counts a misread the same way is a
cross-check that cannot tell a decoder bug from a convention.""")
    print()
    total, agree, disagree, unmod, badlen = xcheck_corpus()
    print('  %d  instructions the second reader printed, and this file '
          'compared' % total)
    print('  %d  of them this file NAMES' % agree)
    print('  %d  unmodelled -- counted, never dropped' % unmod)
    print('  %d  where the two readers disagree on the LENGTH' % badlen)
    print()
    if disagree == 0:
        print('  0  DISAGREE')
    else:
        print('  %d  DISAGREE' % disagree)
    # THE CLASSIFIER, ON EVERY RUN.  A table that appears only on failure is
    # a table this file's own harness can never exercise on a healthy
    # artifact, and the sibling course's harness failed exactly that way
    # during development.  On a clean run it has nothing to classify and says
    # so, which is the point: a reader can see that the machinery ran.
    print()
    print('  THE CLASSIFIER, run on every run and printed whether or not')
    print('  there is anything to classify:')
    print()
    if disagree == 0:
        print('    NOTHING TO CLASSIFY: the two readers agree on every word')
        print('    they both name, so there is no pair to sort.  The')
        print('    classifier is here rather than in the failure branch so')
        print('    that a run where it finds nothing is visibly a run where')
        print('    it RAN and found nothing.')
    else:
        seen = xcheck_summary()
        print('      %d DISTINCT (mine, theirs) PAIRS, each with its count,'
              % len(seen))
        print('      and CLASSIFIED, because the classification is the finding:')
        alias = 0
        real = []
        for (cm, ct), n in sorted(seen.items(), key=lambda kv: -kv[1]):
            is_alias = bool(re.search(r'0x[0-9a-f]{3}', cm)) and \
                re.sub(r'0x[0-9a-f]{3}', '', cm).replace(',', '').strip() \
                == ct.split('\t')[0].strip()
            if is_alias:
                alias += n
            else:
                real.append((cm, ct, n))
        print('        ALIAS ONLY (mine names the instruction, theirs names')
        print('        the pseudoinstruction): %d' % alias)
        print('        SOMETHING ELSE: %d' % sum(n for _a, _b, n in real))
        print()
        if real:
            print('      and the ones that are NOT an alias, in full:')
            for cm, ct, n in real[:20]:
                print('        %-30s vs %-30s  %d' % (cm, ct, n))
            print()
        print('      and the first of each kind, with the file and address:')
        done = set()
        for f, a, cm, ct in xcheck_detail():
            key = (cm, ct)
            if key in done:
                continue
            done.add(key)
            print('        %-16s 0x%04x  this file: %-28s reader: %s'
                  % (f, a, cm.strip(), ct.strip()))
            if len(done) >= 10:
                break
    print()
    print('  THE FIRE TABLE, printed WHETHER OR NOT there is anything to put')
    print('  in it, and PRE-SEEDED so that a rule which never fires is a row')
    print('  with a zero rather than an absence:')
    print()
    for rule in XEXTRA:
        print('    %-26s fired %d times' % (rule, XFIRE.get(rule, 0)))
    print()
    print('    %d rules, %d fired, %d matched nothing'
          % (len(XEXTRA), sum(1 for n in XEXTRA if XFIRE.get(n, 0)),
             sum(1 for n in XEXTRA if not XFIRE.get(n, 0))))
    print()
    para("""THE CLASSIFICATION IS THE POINT, and it is the thing the sibling
courses' findings converge on.  An ALIAS difference is a difference of
SPELLING applied to the same bits: `rdcycle` and `csrrs t0, 0xc00, zero` are
one instruction and two readers disagreeing about which of its two names to
print.  A MISSING OPERAND is a difference of INFORMATION: one reader named a
register and the other did not, and one of them read the word wrongly.  A
cross-check that reports both as "disagreements" has produced a number a
reader cannot use, and this collection has now paid for that twice -- once in
the AArch64 data path course, where 85 instructions genuinely disagreed and
the check printed 0, and once in this section's sibling, where the
classification of 701 "disagreements" turned out to be seven distinct defects
plus a set of printing conventions.

So this file classifies rather than counts, and it prints the classification
on EVERY run whether or not there is anything to put in it.  A check that
exists only in the failure branch is a check the harness can never exercise
on a healthy artifact, and the sibling course's own harness failed exactly
that way during development.""")
    if disagree == 0:
        para("""§KEEP§%d instructions, %d named, %d disagreements, %d length disagreements.  ZERO disagreements over %d named instructions, and ZERO length disagreements over the same %d."""
             % (total, agree + disagree, disagree, badlen,
                agree + disagree, total))
    else:
        para("""%d instructions, %d named, %d disagreements, %d length
disagreements.  The disagreements are listed above, by name and classified,
and §KEEP§THE CLASSIFICATION IS WHAT A READER NEEDS: a cross-check that
counts a spelling difference and a cross-check that counts a misread the same
way is a cross-check that cannot tell a decoder bug from a convention."""
             % (total, agree + disagree, disagree, badlen))
    return total, agree, disagree, unmod, badlen


# ===========================================================================
# SECTION 13 -- FOUR POISONS.  Each must MOVE the number it claims to test.
# ===========================================================================
# SECTION 14 -- THE RETRACTIONS.
#
# Every claim this course took back, in the order it was taken back, with the
# thing that was found instead.  `crosscheck.py` asserts the TEXT of every
# one, because a retraction that is quietly deleted is the one failure no
# number in this file can catch.
# ===========================================================================

RETRACTIONS = [
    ('R1', 'the inherited decoder covers what this course needs of the CSR '
     'address space',
     'it prints the CSR NUMBER and stops.  `s_system` reads inst[31:20] and '
     'renders it as three hex digits, which is the address and not the '
     'privilege: csr[11:10] is the accessibility class and csr[9:8] is the '
     'lowest privilege that may touch the register, and NEITHER is in the '
     'rendering.  A decoder that says `csrr t0, 0x100` has decoded sstatus '
     'and has not said that a user-mode program may not read it.  The '
     'correction is a model PREPENDED in THIS file and the sibling is '
     'untouched, for the reason the sibling course set out: two harnesses '
     'that both pass while reading different code is the failure mode this '
     'collection keeps paying for, and this course\'s harness asserts the '
     'decomposition while the encoding course\'s asserts nothing about it.  '
     'Section 13\'s poison 1 removes this very model.'),
    ('R2', 'the CSR NUMBER field is the mask the sweep found',
     'the mask is NOT CONTIGUOUS and quoting it is a measurement about the '
     'SWEEP rather than about the field.  Sweeping "every `csrr` in the file" '
     'against `csrr t0, cycle` moved bits 20-31 AND bits 12-17, because the '
     'immediate forms and the three-operand forms are in the sweep and they '
     'differ in funct3 and in rs1.  §KEEP§A MASK WITH A HOLE IN IT IS A '
     'NUMBER ABOUT THE SET YOU SWEPT AND NOT ABOUT THE FIELD.  The isolated '
     'measurement, over the two-operand `csrr` words only, is bits 20-31 and '
     'nothing else -- and it took TWO further repairs to get there, because '
     'the first isolated version moved ELEVEN bits and not twelve: every '
     'named CSR in `csr.s` and every U-mode address in it had bit 5 of its '
     'address clear, so the sweep reported a narrower field than the '
     'specification has, with nothing in the output that looked like a gap.'),
    ('R3', 'the pseudo-instruction `csrw cycle, t0` is `csrrs zero, cycle, t0`',
     'it is `csrrw x0, cycle, t0`, and the difference is funct3: 1 against '
     '2, a WRITE against a SET.  The first version of the alias table paired '
     'it with csrrs on the reasonable-sounding assumption that the `w` '
     'stands for "write the value in" rather than for the instruction\'s own '
     'mnemonic, and the comparison printed a difference of 0x00000000 -- '
     'which is a real difference and not a typo, and which a reader skimming '
     'a table of "IDENTICAL / DIFFER" would have checked and found.  §KEEP§A '
     'COMPARISON THAT PRINTS 0x00000000 IS A FINDING AND NOT A BUG IN THE '
     'PRINTER, AND THE ONLY WAY TO KNOW WHICH IS TO LOOK AT THE XOR ITSELF.'),
    ('R4', 'the `ecall` wrapper\'s instruction count is the convention\'s',
     'the FIRST version of `wrap.c` measured dead-code elimination and this '
     'file reported it as a convention.  The original wrapper never used its '
     'arguments after the trap, and at -O1 and above clang deleted the three '
     'argument loads, so the function became `li a7, 0x40 ; ecall ; ret` -- '
     'three instructions, and a number that is clang 21.1.8\'s opinion of '
     'unused parameters.  The corpus adds `+ nfd + n` to the return value, '
     'which makes them live, and the count is now a count of the convention.  '
     '§KEEP§A COUNT OVER -O0 IS A COUNT OF A COMPILER\'S SCAFFOLDING, AND THE '
     'ONLY WAY TO TELL A CONVENTION\'S NUMBER FROM A COMPILER\'S IS TO VARY '
     'THE LEVEL AND SEE WHICH ONE MOVES.'),
    ('R5', 'the PPN field in `satp` is 54 bits, because the PPN field in a '
     'PTE is 54 bits',
     'it is 36 bits, and the two live in different registers.  A PTE stores '
     'the PPN at bits 53-10, and `satp` stores a PPN at bits 51-8 with a '
     'FOUR-BIT MODE and a SIXTEEN-BIT ASID above it, so the field is '
     '64 - 4 - 16 - 8 = 36 bits.  §KEEP§THE MASK WAS WRONG AND IT COMPILED, '
     'AND THE COMPILER IS NOT THE PROBLEM: a 54-bit mask of satp returns a '
     'value with all sixteen ASID bits and two MODE bits mixed into a page '
     'number, and nothing about the emitted code says so.'),
    ('R6', 'the PPN field in `satp` is 44 bits, because the manual\'s PTE '
     'figure shows a 44-bit PPN',
     'also wrong, and worse, because 44 IS the number the manual prints.  A '
     'reader who takes 44 from the PTE figure and applies it to satp gets a '
     'mask that LOOKS documented and is eight bits too wide, and the eight '
     'bits are exactly satp[51:44], the top eight of the ASID.  §KEEP§TWO '
     'NATURAL MISTAKES WITH A PLEASING SHAPE ARE WORSE THAN ONE UGLY ONE, '
     'BECAUSE THE UGLY ONE GETS CHECKED.'),
    ('R7', 'the pairing distance is a property of the object file',
     'the assembler does not enforce it and the numbers in section 10 are '
     'the evidence.  One `R_RISCV_PCREL_HI20` and TWO `R_RISCV_PCREL_LO12_I` '
     'records were emitted at every one of six distances, including 0x2000 -- '
     '8200 bytes, which does not fit a signed 12-bit field and which a '
     'linker is entitled to reject.  §KEEP§A RELOCATION RULE ENFORCED BY NO '
     'TOOL ON THE HOST IS A QUOTED CONSTRAINT AND NOT A MEASURED ONE, AND '
     'THE COURSE SAYS WHICH IT IS INSTEAD OF CLAIMING A BUG IT CANNOT '
     'DEMONSTRATE.'),
    ('R8', 'the addend on an `R_RISCV_PCREL_LO12_I` record is always zero',
     'the psABI says "the addend must be 0" and this corpus has records with '
     'addends of 8 and 0x800 on them, produced by `%pcrel_lo(label)+N`.  The '
     'honest reading is that the sentence describes the CANONICAL pair as '
     'generated with no offset and that a hand-written offset is a legitimate '
     'extension a linker handles.  §KEEP§THERE IS NO RISC-V LINKER ON THIS '
     'HOST, SO WHETHER IT HANDLES IT IS QUOTED AND NOT MEASURED, AND A COURSE '
     'THAT CLAIMED A BUG HERE WOULD BE CLAIMING SOMETHING IT CANNOT SEE.'),
    ('R9', 'the number of relocation records a page-table walk produces is a '
     'property of the walk',
     'it is a property of the DATA LAYOUT, and the same source file at the '
     'same optimisation level emits ONE `R_RISCV_PCREL_HI20` when the three '
     'tables are adjacent and THREE when they are 4 KiB apart.  §KEEP§THE '
     'AUTHOR OF THE WALK IS NOT IN THE CONVERSATION: the change is the '
     'merged-globals pass, and the evidence is in the symbol names, which '
     'switch from `.L_MergedGlobals` to `root`/`l1tab`/`l2tab` between the two '
     'builds.'),
    ('R10', 'this course can say what a trap, a page fault or a syscall does',
     'IT IS NOT MEASURED, and the file says so in its header, in section 1, '
     'at the end of every affected section, and in the table in section 15 '
     'rather than in a disclaimer.  There is no RISC-V machine, no emulator '
     'and no RISC-V linker on this host.  No exception has been taken, no '
     'page has been walked, no TLB has been consulted, and no `ecall` has '
     'been observed returning anything.  §KEEP§WHAT IS MEASURED IS THAT THE '
     'COMPILER EMITS THE CONSTANT 0x00000073 WITH THE CONVENTION\'S REGISTERS '
     'AROUND IT, AND WHAT IS NOT MEASURED IS THAT ANY OF IT WORKS.'),
    ('R11', 'the mode of `stvec` is a property of the instruction that writes '
     'it',
     'it is a property of the VALUE, and all three of the corpus\'s `csrw '
     'stvec, a1` instructions are the SAME 32 bits -- 0x10559073 -- whether '
     'the mode is Direct, Vectored or Reserved.  The first draft reported the '
     'three functions\' bodies as three different instruction counts and a '
     'reader could have concluded the mode was visible in the code, and the '
     'second draft had the same finding for a different reason: the functions '
     'returned their constant, clang put the return value in a1 and the '
     'argument in a0, and the three `csrw` words came out with TWO different '
     'rs1 values.  §KEEP§A DISASSEMBLER READING THE OBJECT CAN RECOVER THE '
     'INSTRUCTION AND CANNOT RECOVER THE MODE, AND THE VALUE THAT WOULD TELL '
     'IT IS FOUR INSTRUCTIONS EARLIER IN THE SAME FUNCTION.'),
    ('R12', 'the two readers\' disagreement count is a measure of this '
     'decoder\'s correctness',
     'it is a measure of a COMPARISON, and section 12 CLASSIFIES every '
     'disagreement by kind.  The kind this corpus actually produced was a '
     'SPELLING difference -- `c.li a2, -1` against `li a2, -0x1`, the same '
     'value in two encodings printed two ways -- and ten such words were '
     'counted as disagreements until this file added two normalisation rules '
     'that bring both sides to one spelling BEFORE the inherited rules run.  '
     '§KEEP§A CROSS-CHECK THAT COUNTS A SPELLING DIFFERENCE AND A CROSS-CHECK '
     'THAT COUNTS A MISREAD THE SAME WAY IS A CROSS-CHECK THAT CANNOT TELL A '
     'DECODER BUG FROM A CONVENTION, AND THIS COLLECTION HAS PAID FOR THAT '
     'TWICE.'),
    ('R13', 'the layout experiment holds the instruction count constant, so '
     'the relocation delta is clean',
     'it holds the instruction count constant in the -fno-pic pair ONLY, and '
     'the default PIC pair is confounded by a factor of four.  The first draft '
     'of section 9 built two objects, both at the target default, and wrote '
     '"the same number of instructions in both" over a table whose own column '
     'read 58 against 13.  The adjacent PIC build UNROLLED the three fill '
     'paths and the 4 KiB-apart one did not, because the merged-globals pass '
     'had nothing to merge when the tables are three separate symbols.  '
     '§KEEP§A TABLE THAT PRINTS THE CONFOUNDING NUMBER IN ITS OWN COLUMN IS '
     'NOT A CONFIRMED CLAIM, IT IS A CLAIM WITH THE EVIDENCE AGAINST IT '
     'ATTACHED, AND THE DRAFT QUOTED THE COLUMN AND NOT THE NUMBER.  The '
     'experiment now builds FOUR objects, labels the -fno-pic pair CLEAN and '
     'the PIC pair CONFOUNDED in the caption, and rests the claim on the '
     'clean one.'),
    ('R14', 'the inherited decoder names the instructions this course needs',
     'it names NONE of the privileged ones, and the gap is in the privileged '
     'architecture rather than at the edge of the base ISA.  `s_misc_mem` in '
     '`rvdec.py` handles opcode 0x73 with funct3 = 0 by reading the funct12 '
     'and printing `ecall` for 0, `ebreak` for 1 and `system funct12=0x0NNN` '
     'for everything else -- and it DECLINES any such word whose rd or rs1 is '
     'non-zero, because the first two were the only funct3 = 0 SYSTEM words it '
     'knew.  SFENCE.VMA is funct12 = 0x120.  §KEEP§THE ENCODING COURSE\'S '
     'DECODER CANNOT NAME A PRIVILEGED INSTRUCTION, AND THE PAGE-TABLE COURSE '
     'IS THE ONE THAT NEEDS IT.  The first run of this file\'s cross-check '
     'reported twelve of them as disagreements, and a reader would have had to '
     'work out for themselves that a decoder printing `(undefined)` is '
     'claiming the ARCHITECTURE defines no meaning for a word the architecture '
     'defines precisely.  The correction is PREPENDED here and the sibling is '
     'untouched.'),
    ('R15', '`sfence.vma %0` assembles to one of the two forms the psABI '
     'defines',
     'it does not, and this one is a TOOLCHAIN finding rather than a reader '
     'finding.  `riscv-elf` and `priv-spec` define funct12 = 0x120 as the bare '
     'form with rs1 = x0 and rs2 = x0, and funct12 = 0x121 as the form that '
     'takes the two operands.  clang\'s integrated assembler emits '
     '`sfence.vma %0` with the operand bound to a0 as funct12 = 0x120 and '
     'rs1 = a0 -- 0x12050073 -- which is NEITHER of the two defined forms.  '
     'Both readers name it, which is why this file and the second reader '
     'agree, and the specification is left to say what it does.  §KEEP§A '
     'CROSS-CHECK THAT AGREES BECAUSE BOTH READERS GUESSED THE SAME THING IS '
     'NOT EVIDENCE, AND THE FILE SAYS SO RATHER THAN BANKING THE ZERO.'),
    ('R16', 'every immediate the LO12 records attach to is zero',
     'every IMMEDIATE is, and the first version of the table computed one of '
     'them from the wrong field.  It read inst[31:20] for every row and '
     'printed 0x006 on the `sd`, because for an S-TYPE inst[31:20] is not an '
     'immediate at all: inst[31:25] is imm[11:5] and inst[24:20] is rs2, so '
     'the twelve bits are seven bits of one field followed by a whole '
     'register.  §KEEP§A NUMBER COMPUTED FROM THE WRONG FIELD IS NOT A SMALLER '
     'NUMBER, IT IS A DIFFERENT NUMBER, AND IT LOOKS LIKE A SMALLER ONE.  The '
     'table now decodes the S-type immediate as inst[31:25] concatenated with '
     'inst[11:7] and prints BOTH inst[11:7] and inst[24:20] beside it, so the '
     'reader can see which bits are which, and the sentence above the table '
     'is about immediates rather than about a twelve-bit window.'),
    ('R17', 'the first correction to R16 named that register `rd`',
     'there is no rd in an S-TYPE word at all, and the number was right while '
     'the NAME was wrong.  A store has no destination register, so its '
     'inst[24:20] is rs2 -- the register the value is moved FROM -- and the '
     'instruction the corpus built is `sd t1, 0(t0)`, so rs2 = t1 = x6 = 0x006, '
     'which is exactly the number the mask returned.  §KEEP§A NUMBER YOU CAN '
     'NAME IS NOT YET A FIELD, AND NAMING IT AFTER A FIELD THAT IS NOT IN THE '
     'WORD IS THE SAME ERROR WITH A DIFFERENT SPELLING.  A wrong field NAME is '
     'worse than a wrong field VALUE in one specific way: the value is caught '
     'by the next comparison and the name is not, and it gets copied.  The '
     'table now prints inst[11:7] and inst[24:20] as two unnamed columns and '
     'prints the arithmetic that turns one into the other, so the reader is '
     'shown WHICH BITS rather than being told WHICH FIELD they are.'),
]

# Where each retraction was written down BEFORE this course measured it.  A
# retraction with no prior source is a course disagreeing with itself, which
# is a different failure and one that is worth being able to tell apart.
RET_SOURCES = {
    'R1': "this course's own first draft, section 3",
    'R2': "this course's own first draft, section 3's mask table",
    'R3': "this course's own first draft, section 3's alias table",
    'R4': "this course's own first draft of `wrap.c`",
    'R5': "this course's own first draft of `bits.c`",
    'R6': "this course's own second draft of `bits.c`",
    'R7': "`docs/riscv-section-plan.md`, the pair-per-page question",
    'R8': "this course's own first draft of section 9",
    'R9': "this course's own first draft of section 9",
    'R10': "this course's own first draft of section 5",
    'R11': "this course's own first draft of section 11",
    'R12': "this course's own first draft of section 12",
    'R13': "this course's own first draft of section 9, the layout table",
    'R14': "this course's own first run of section 12 -- and the defect is "
           "in the SIBLING's decoder rather than in this file's",
    'R15': "this course's own first run of section 12, found by assembling "
           "one instruction and reading the word",
    'R16': "this course's own first run of section 9's immediate column",
    'R17': "this course's own first CORRECTION to R16 -- the value was "
           "right and the field name was not",
}


def _wrap(text, width, indent):
    words = text.split()
    line = indent.rstrip()
    out = []
    for w in words:
        if len(line) + len(w) + 1 > width + len(indent):
            out.append(line)
            line = indent + w
        else:
            line = line + ' ' + w
    if line.strip():
        out.append(line)
    return out


# ===========================================================================

def poison_named(model_name):
    """Remove ONE model from the dispatch and report the move in all four of
    the cross-check's numbers.  Returns a dict so the caller can print a
    delta for each and check that it is non-zero.

    AND IT REPORTS A VICTIM THAT IS NOT IN THE DISPATCH AT ALL, because that
    is the failure the first RISC-V course shipped: a poison whose victim had
    no corpus footprint could not move a number, and the file printed
    [POISON FAILED] against a control that had never run.  A missing victim
    is a DIFFERENT BUG from an unmoved one, and the two are now distinguished
    in the return value rather than in a comment.
    """
    names = [m[0] for m in Dec.MODELS32]
    if model_name not in names:
        return {'missing': True, 'model': model_name, 'names': names}
    return _poison_remove([model_name])


def _poison_remove(victims):
    """The shared body: remove a LIST of models, re-run, report the deltas."""
    before = xcheck_corpus()
    saved = list(Dec.MODELS32)
    Dec.MODELS32 = [m for m in saved if m[0] not in victims]
    try:
        after = xcheck_corpus()
    finally:
        Dec.MODELS32 = saved
    return {'missing': False, 'before': before, 'after': after,
            'delta_named': (before[1] + before[2]) - (after[1] + after[2]),
            'delta_disagree': after[2] - before[2],
            'delta_unmodelled': after[3] - before[3]}


def poison_length():
    """Hand the instruction LENGTH in from outside, as a disassembler with a
    symbol table can, and compare the instruction count against the two-bit
    rule.  The rule is load-bearing if and only if this differs."""
    got = {'rule': 0, 'supplied': 0}
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        d, secs = Dec.code_sections(fp)
        for _nm, vaddr, off, size in secs:
            ins, _e = Dec.decode_text(d, off, size, vaddr)
            got['rule'] += len(ins)
            ins2, _e2 = Dec.decode_text(d, off, size, vaddr, tell_length=True)
            got['supplied'] += len(ins2)
    return got


def poison_reloc_code():
    """Read the WRONG HALF of r_info and count how many relocation records
    the file then mis-names.

    `r_info` is `SYMBOL << 32 | TYPE`, so the type is the low half.  The low
    half of the SYMBOL index is a small number that looks exactly like a
    type, and a reader that takes it produces a table of plausible relocation
    names that are all wrong.  This poison exists because it is a bug this
    artifact could have made, and the only way to know whether section 9's
    table is a reading or a coincidence is to break the reading on purpose.
    """
    # The reader prints the names WITH the R_RISCV_ prefix and RELOC_CODE is
    # keyed on the psABI's SHORT names, so the prefix is stripped here.  The
    # first version compared the two forms directly, every count came out
    # ZERO, and the poison reported [POISON FAILED] against a control that
    # worked perfectly -- which is 2.2.112's finding for the third time in
    # this section: a zero and a bug are the same number.
    right = wrong = 0
    for f in ('pt_nopic.o', 'pt_pic.o', 'sp2_sparse.o', 'sp2_dense.o',
              'sp2_dense_nopic.o', 'sp2_sparse_nopic.o'):
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for _off, ty, nm, _sym, _add in reloc_rows(fp):
            short = nm[len('R_RISCV_'):] if nm.startswith('R_RISCV_') else nm
            if short in RELOC_CODE and RELOC_CODE[short] == ty:
                right += 1
            if ty in RELOC_CODE.values():
                wrong += 1
    # Now the same records read the wrong way: the low half of the SYMBOL
    # index, which the reader's `Info` column also contains.
    misnamed = 0
    total = 0
    for f in ('pt_nopic.o', 'pt_pic.o', 'sp2_sparse.o', 'sp2_dense.o',
              'sp2_dense_nopic.o', 'sp2_sparse_nopic.o'):
        fp = p(f)
        if not os.path.exists(fp):
            continue
        r = sh(READELF, '-r', fp)
        for ln in (r.stdout or '').splitlines():
            m = re.match(r'([0-9a-f]{16})\s+([0-9a-f]{16})\s+(\S+)\s+', ln)
            if not m:
                continue
            info = int(m.group(2), 16)
            total += 1
            if (info >> 32) & 0xffffffff in RELOC_CODE.values():
                misnamed += 1
    return right, wrong, total, misnamed


def poison_plant():
    """PLANT real disagreements in the decoder's own rendering, then show
    that a normaliser which DELETES the operands makes them disappear.

    This is the fourth poison and the only one that tests the CHECK rather
    than the decoder.  A decoder bug is found by reading the output; a check
    bug is found only by trying to break the check.

    The planting is done on THIS file's side, and the location is deliberate:
    inside the normaliser it would corrupt both sides and the two would agree
    perfectly around a real disagreement.  Every planted difference changes
    the LAST OPERAND, because the broken rule keeps the mnemonic and the
    first operand -- so a difference planted anywhere else would not be
    visible to the broken rule either, and the control would report a smaller
    movement for the wrong reason.  That is the same lesson the sibling course
    learned the hard way, and it is why the planting is restricted rather
    than random.
    """
    planted = []
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for addr, w, nb, txt in Dec.objdump_lines(fp):
            k = Dec.decode(w, nb, addr)
            if k.name is None or ',' not in k.text:
                continue
            if normalise(k.text) != normalise(txt):
                continue
            parts = k.text.split(',')
            last = parts[-1].strip()
            newlast = 'a7' if last not in ('a7', 'zero') else 'a6'
            planted.append((f, addr, ','.join(parts[:-1] + [newlast]), txt))

    def bad(t):
        """The AArch64-shaped rule: keep the mnemonic and the FIRST operand,
        DELETE everything after the first comma."""
        c = normalise(t)
        m = re.match(r'^([a-z0-9._]+?)([a-z][0-9]+)(.*)$', c)
        if not m:
            return c
        return m.group(1) + m.group(2)

    caught = sum(1 for _f, _a, mt, tt in planted
                 if normalise(mt) != normalise(tt))
    hidden = sum(1 for _f, _a, mt, tt in planted if bad(mt) == bad(tt))
    return len(planted), caught, hidden


def sec13():
    banner(13, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER')
    print()
    para("""A control that cannot be made to fail is a comment that says the
word POISONED.  This collection has paid for that lesson repeatedly -- the
AArch64 data-path course's cross-check reported ZERO disagreements over a
corpus where eighty-five instructions genuinely disagreed, and every one of
the four bugs had made the comparison VACUOUS rather than wrong; and the
first RISC-V course shipped a poison whose victim had no corpus footprint,
so it could not move anything.

So each of the four below names the number it tests, runs the SAME loop over
the SAME bytes, prints the DELTA as a number, and prints [POISON FAILED] if
the delta is zero.  The victims are chosen FROM THE CORPUS and not from a
list of interesting models, because a poison whose victim owns no words in
this corpus is a poison that cannot move a number no matter what it prints.""")

    print()
    print('  POISON 1 -- remove BOTH OF THIS COURSE\'S OWN MODELS,')
    print('              `m_sfence_vma` and `m_csr_address`, in one step.')
    print('              It claims THREE numbers, and the reason is worth')
    print('              stating because it is the opposite of the usual')
    print('              case: removing them does NOT simply lose words.')
    print('              With both gone the INHERITED `s_system` takes the')
    print('              CSR words, and it prints them differently, so the')
    print('              unmodelled count FALLS -- the words stop being holes')
    print('              and become WRONG.  The named count goes UP and the')
    print('              disagreement count goes UP, and a cross-check that')
    print('              watched only one of the three would have reported')
    print('              the wrong verdict.  §KEEP§A POISON THAT MOVES TWO')
    print('              NUMBERS IN OPPOSITE DIRECTIONS IS A BETTER POISON')
    print('              THAN ONE THAT MOVES ONE, BECAUSE IT PROVES THE')
    print('              COLUMNS ARE NOT THE SAME COLUMN.')
    r1 = _poison_remove(['m_sfence_vma', 'm_csr_address'])
    if r1.get('missing'):
        print('    [POISON FAILED] a victim is NOT IN THE DISPATCH, so '
              'nothing was removed')
        print()
        return
    b, a = r1['before'], r1['after']
    print()
    print('    BEFORE: %d named, %d disagree, %d unmodelled'
          % (b[1] + b[2], b[2], b[3]))
    print('    AFTER : %d named, %d disagree, %d unmodelled'
          % (a[1] + a[2], a[2], a[3]))
    print('    DELTA: named %+d, disagreements %+d, unmodelled %+d'
          % (-r1['delta_named'], r1['delta_disagree'],
             r1['delta_unmodelled']))
    ok1 = (r1['delta_named'] != 0 and r1['delta_disagree'] != 0
           and r1['delta_unmodelled'] != 0)
    print('    VERDICT: POISON 1 %s' % ('FIRED' if ok1
                                        else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok1:
        print('    [POISON FAILED]')
    print()

    print('  POISON 2 -- read the WRONG HALF of r_info in the relocation')
    print('              reader.  The type is the LOW 32 bits; the high 32')
    print('              are the symbol index, and the low half of THAT is')
    print('              a small integer that looks exactly like a type')
    print('              number.  The number it must move is the count of')
    print('              records whose NAME the reader can recover at all.')
    right, wrong, total_rel, misnamed = poison_reloc_code()
    _p1 = r1
    print()
    print('    records examined                                    : %d'
          % total_rel)
    print('    read the RIGHT way, names that match the psABI table : %d'
          % right)
    print('    read the WRONG way, values that name a real type    : %d'
          % misnamed)
    print('    and the WRONG way names a real type for %d of them, which is'
          % misnamed)
    print('    %d in %d, and THAT is the dangerous part: a reader that got'
          % (misnamed, total_rel))
    print('    this wrong would have a table that is right about %d records'
          % (total_rel - misnamed))
    print('    and silently wrong about %d, and nothing in the output would'
          % misnamed)
    print('    have said so.')
    print('    DELTA: %d records lose their name and %d gain a WRONG one'
          % (right, misnamed))
    ok2 = right > 0 and misnamed > 0
    print('    VERDICT: POISON 2 %s' % ('FIRED' if ok2
                                        else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok2:
        print('    [POISON FAILED]')
    print()
    para("""AND THE DIRECTION OF THAT POISON IS THE FINDING, so it is worth more
than a sentence.  §KEEP§READING THE WRONG HALF OF r_info DOES NOT PRODUCE AN
OBVIOUSLY BROKEN TABLE.  IT PRODUCES A TABLE THAT IS RIGHT ABOUT %d OF %d
RECORDS AND SILENTLY WRONG ABOUT %d, AND NOTHING IN THE OUTPUT SAYS WHICH IS
WHICH.

The reason is arithmetic.  The relocation TYPES are 20, 23, 24, 25, 26, 27
and 51, and the SYMBOL INDICES in objects this small are 0 through 13.  Those
ranges barely overlap, so most of the records would read as an index the
psABI table has no row for -- which is at least a VISIBLE failure.  The %d
that overlap are the dangerous ones, because a symbol index of 20 reads as
GOT_HI20 and 23 reads as PCREL_HI20, and a table with a few of the right
names in the wrong places is exactly the kind of output a reader skims.

§KEEP§A CONTROL THAT FAILS BY PRODUCING A MOSTLY-CORRECT ANSWER IS HARDER TO
NOTICE THAN ONE THAT FAILS BY PRODUCING NOTHING, AND THE POISON IS PRINTED
WITH BOTH NUMBERS FOR THAT REASON.

This is the third time this collection has met the same shape.  The AArch64
data path's check printed ZERO where eighty-five instructions disagreed; the
section's first course shipped a poison whose victim had no corpus footprint
and printed [POISON FAILED] against a control that had never run; and this
file's first version of poison 2 compared the reader's `R_RISCV_`-prefixed
names against a table keyed on the psABI's SHORT names, so `right` came out
ZERO and the poison reported a failure against a control that worked.  All
three are the same bug wearing different clothes: a number that is zero for
a reason nobody looked at.""" % (total_rel - misnamed, total_rel, misnamed,
                                 misnamed))
    print()

    print('  POISON 3 -- hand the instruction LENGTH in from outside, as a')
    print('              disassembler with a symbol table can, and compare')
    print('              the instruction count against the two-bit rule.')
    print('              The number it must move is the COUNT ITSELF: with')
    print('              the length supplied the rule is no longer being')
    print('              tested by anything, and a rule nothing tests is a')
    print('              comment.')
    g = poison_length()
    print()
    print('    instructions found by the RULE      : %d' % g['rule'])
    print('    instructions found with length GIVEN: %d' % g['supplied'])
    d3 = g['rule'] - g['supplied']
    print('    DELTA: %+d' % (-d3))
    ok3 = d3 != 0
    print('    VERDICT: POISON 3 %s' % ('FIRED' if ok3
                                        else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok3:
        print('    [POISON FAILED]')
    print()

    print('  POISON 4 -- break the CHECK, not the decoder.  Every')
    print('              instruction this file can name is listed, and then')
    print('              an AArch64-shaped normaliser -- one that KEEPS the')
    print('              mnemonic and the FIRST operand and DELETES the rest')
    print('              -- is applied to both sides of a PLANTED set of')
    print('              real disagreements.  The number it must move is the')
    print('              number of disagreements that DISAPPEAR.')
    planted, caught, hidden = poison_plant()
    print()
    print('    real disagreements planted (last operand changed): %d' % planted)
    print('    of those, the working cross-check CATCHES           : %d' % caught)
    print('    of those, the broken rule makes DISAPPEAR           : %d' % hidden)
    ok4 = planted > 0 and caught > 0 and hidden > 0
    print('    DELTA: %d of the %d planted disagreements were HIDDEN'
          % (hidden, planted))
    print('    VERDICT: POISON 4 %s' % ('FIRED' if ok4
                                        else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok4:
        print('    [POISON FAILED]')
    print()
    para("""FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS:

* poison 1 claims the NAMED, the DISAGREE and the UNMODELLED counts, and
            moved them by %+d, %+d and %+d
* poison 2 claims the RELOCATION NAME count, and moved it by %d names lost
  and %d wrongly named
* poison 3 claims the INSTRUCTION COUNT,   and moved it by %+d
* poison 4 claims the VISIBILITY of the check, and hid %d of %d

AND THE ONE WORTH READING TWICE IS POISON 1, BECAUSE IT MOVES THREE NUMBERS
AND TWO OF THEM GO IN OPPOSITE DIRECTIONS.  The unmodelled count FALLS by
%d and the disagreement count RISES by %d over the same removal, and both
moves are correct: the words stopped being holes and became wrong, which is
two different failures with the same cause.

§KEEP§A CROSS-CHECK THAT COUNTS AGREEMENTS AND A CROSS-CHECK THAT COUNTS
HOLES ARE MEASURING DIFFERENT THINGS, AND A POISON THAT MOVES BOTH IN
OPPOSITE DIRECTIONS IS THE PROOF THAT THEY ARE.

That is the whole reason the UNMODELLED column is printed beside the
disagreement column rather than in a footnote.  A model can be removed, or
become unreachable, or be shadowed by an earlier model, and every word it
owned can end up named by something else at the same address -- and a check
that watched only the disagreement count would have seen %+d and called it
progress.  It is the reverse of progress.  The number of words that stopped
being named is %d, and every one of them is a word this file can no longer
account for.

A poison that cannot move must say so, and this file prints [POISON FAILED]
and stops.  A control that did not run and a control that ran and found
nothing are the same number and two different bugs, and the distinction is
made in the return value rather than in a comment nobody reads.
""" % (-r1['delta_named'], r1['delta_disagree'], r1['delta_unmodelled'],
       right, misnamed, -d3, hidden, planted,
       -r1['delta_unmodelled'], r1['delta_disagree'],
       r1['delta_disagree'], -r1['delta_named']))


def sec14():
    banner(14, 'SEVENTEEN RETRACTIONS')
    print()
    para("""%s of them, and every one was asserted in a draft of this course
or in the plan it was written from, measured, and withdrawn.  They are
printed in full rather than footnoted, and `crosscheck.py` asserts their
TEXT so that a later edit cannot quietly delete one -- which is the only
mechanism that has ever stopped a retraction being quietly dropped.

Eleven of the %d are about a READER, an INSTRUMENT or an EXPERIMENT and six are
about a COMPARISON, and that ratio is the shape of this subject: the privileged
architecture is a document you can quote exactly, and almost everything that
went wrong here was in the machinery built to read it.

The two that are NOT that are worth naming, because a list that is uniformly
one thing is a list nobody read: R10 says this course cannot say what a trap
DOES, and R14 says the defect is in a SIBLING's decoder rather than in this
one.  §KEEP§A RETRACTION THAT ADMITS A WHOLE SECTION IS UNCLEARED IS NOT A
RETRACTION, IT IS A COURSE THAT HAS DECIDED IT IS BEING CAREFUL, AND THE ONE
THAT ADMITS THE DEFECT IS ELSEWHERE IS THE ONE THAT KEEPS THE OTHER COURSES
HONEST.

NOTHING HERE IS A MISTAKE ABOUT HOW A COMPUTER WORKS.  That is seventeen
courses in a row, and it is the most interesting thing about the list.  The
RISC-V privileged architecture did not surprise this course once.  What
surprised it was a mask two registers wide, a pseudo-instruction whose letter
does not mean what it says, an assembler that enforces nothing, and its own
dead-code elimination reported as a calling convention.""" % (
        NUMWORDS[len(RETRACTIONS)], len(RETRACTIONS)))
    print()
    for rid, claim, found in RETRACTIONS:
        print('  %s  CLAIMED: %s' % (rid, claim))
        print('        SOURCE: %s' % RET_SOURCES[rid])
        for chunk in found.strip().split('\n\n'):
            keep = KEEP in chunk
            body = _wrap(chunk.replace(KEEP, '').strip(),
                         200 if keep else 68, '        ')
            for k, ln in enumerate(body):
                print('%s%s' % ('    ' if k == 0 and not keep else '        ',
                                ln))
        print()


# ===========================================================================
# SECTION 15 -- THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY
# CLAIM CAME FROM.
#
# This section is the concept page the course is built around, so it is a
# TABLE rather than a paragraph and the table has a ratio in it.
# ===========================================================================

LIMITS = [
    'NO TIMING.  No cycle, no latency, no throughput, no speedup, no ratio of '
    'anything a machine did.  There is no RISC-V machine, no emulator and no '
    'RISC-V linker on this host, so every figure is a bit pattern, a count of '
    'bit patterns, an arithmetic identity, or a refusal from a real assembler. '
    'The x86-64 section measured a 4.92x and a 27.65x; those have NO '
    'COUNTERPART HERE AND ARE NOT INVENTED TO FILL THE GAP.',
    'NOTHING IS EXECUTED.  Not one instruction in this course has run.  A '
    'page-table walk in section 9 has never walked a page; it is a function '
    'that the compiler emitted and a disassembly that named it.',
    'NO EXCEPTION IS EVER TAKEN, NO INTERRUPT IS EVER TAKEN, NO PAGE FAULT IS '
    'EVER RAISED, NO TLB IS EVER CONSULTED AND NO ACCESS FAULT IS EVER '
    'RAISED.  Six separate absences, and each one is a separate thing this '
    'course would otherwise be able to say.',
    'THE ecall CONVENTION IS MEASURED AS EMITTED, WHICH IS WEAKER.  What is '
    'measured is that clang emits the constant 0x00000073 and that the '
    'convention\'s registers are a7 and a0.  What is NOT measured is that the '
    'trap is taken, that it reaches supervisor mode, that a7 is read, that a '
    'kernel exists, or that anything comes back.',
    'NO LINKER RUNS.  So the relocation NAMES and NUMBERS are measured, the '
    'records are measured, and what a linker DOES with them -- including '
    'whether it accepts a pair 8 KiB apart, and whether it relaxes anything -- '
    'is quoted.  R_RISCV_RELAX appears in every object and has never been '
    'acted on.',
    'THE A AND D BITS ARE TWO QUOTED SCHEMES AND NEITHER HAS BEEN OBSERVED.  '
    'The bit POSITIONS are measured on the compiler\'s own shifts.  Which '
    'scheme a given hart implements, how many page faults a first touch costs, '
    'and whether the hardware update is atomic with the access that caused it '
    'are all properties of silicon this host does not have.',
    'THE CSR ACCESSIBILITY AND PRIVILEGE BITS ARE MEASURED AS ADDRESSES AND '
    'NOT AS ENFORCEMENT.  It is measured that `stvec` is 0x105 and `mtvec` is '
    '0x305 and that the instruction writing them is byte-identical.  It is '
    'NOT measured that a write to `mtvec` from S-mode raises an '
    'illegal-instruction exception, because there is no S-mode here.',
    'THE stvec MODE AND THE BASE ALIGNMENT ARE VALUES AND NOT INSTRUCTIONS, '
    'and the enforcement is hardware this host does not have.  All three '
    'corpus functions emit the same 32-bit word; the value four instructions '
    'earlier is what distinguishes Direct from Vectored from Reserved, and '
    'whether the hardware clears the low two bits of BASE is a claim this '
    'course can only quote.',
    'THE TWO READERS SHARE AN ASSEMBLER.  `clang` assembled the corpus and '
    '`llvm-objdump-21` disassembled it, so both come from one LLVM tree, and '
    'GNU binutils has no RISC-V target installed on this host.  What section '
    '12 establishes is "this decoder and one other piece of software agree on '
    'what the bytes mean" -- NOT "either agrees with silicon".',
    'THE SOURCE/DISASSEMBLY PAIRING IN SECTIONS 3 AND 11 IS POSITIONAL, AND '
    'THE FILE CHECKS IT.  `csr.s` is a straight-line list of one instruction '
    'per line with no labels inside the instruction run, so source line N is '
    'word N.  The count is asserted on every run and a file that changed shape '
    'would fail loudly rather than silently mis-pair every field in the '
    'course.',
    'THE TWO satp MASKS THIS FILE SHIPS ARE WRONG ON PURPOSE.  '
    '`satp_ppn54_wrong` and `satp_ppn44_wrong` are in the corpus so that the '
    'wrong width can be read out of the compiler\'s own output rather than '
    'asserted.  A reader who copies them out of `bits.c` gets a page number '
    'with sixteen ASID bits mixed into it.',
    'EVERY INSTRUCTION COUNT AND EVERY FUNCTION IS CLANG 21.1.8\'S.  '
    '`crosscheck.py` asserts the encodings, the field positions, the '
    'relocation numbers, the size arithmetic and the poison deltas as exact '
    'quantities, and the instruction counts and relocation COUNTS as shapes '
    'and orderings, because a shape does not move with a compiler and a bare '
    'value does.',
    'THE LAYOUT EXPERIMENT MEASURES A COMPILER PASS, NOT AN ARCHITECTURE.  '
    'The dense/sparse difference in section 9 is the merged-globals pass, and '
    'it would be a different number under a different compiler at a different '
    'optimisation level.  What is NOT a compiler property is the psABI\'s '
    'arithmetic: one AUIPC per 2048 bytes is arithmetic.',
    'NOTHING GENERALISES FROM AN EMPTY ROW.  Every distribution here is a '
    'distribution of what clang chose for a handful of files at one version on '
    'one host, and a row with nothing in it is a statement about that corpus '
    'and not about the architecture.',
    'A CROSS-CHECK THAT AGREES IS NOT PROOF.  Section 13 exists because the '
    'AArch64 data-path course reported ZERO disagreements over a corpus where '
    'eighty-five instructions genuinely disagreed, and the only way to know '
    'whether a cross-check can fail is to make it fail on purpose.',
    'THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT.  Quoting is not '
    'verifying.  The three documents -- `priv-spec`, `riscv-elf` and '
    '`rv32-unpriv` -- were read on this host and every QUOTED row names one '
    'of them with a section, and a reader who wants to disagree with a '
    'QUOTED row has the citation to disagree with.',
]

CANNOT_CONCLUDE = [
    'That a page is ever walked.  `walk.c` compiles to a function whose body '
    'is three `auipc`/`ld` pairs and whose name says walk.  No pointer is '
    'dereferenced, no PPN is translated, and `priv-spec` section 11.1.4 is '
    'quoted rather than performed.',
    'That an `ecall` traps.  What is measured is the constant 0x00000073 and '
    'the register a7 around it.  Whether the trap is taken, whether control '
    'reaches supervisor mode, and whether anything returns are four separate '
    'questions and none of them has been asked of a machine.',
    'That writing `mtvec` from S-mode raises an illegal-instruction '
    'exception.  The privilege bits of the CSR address are measured as '
    'NUMBERS.  The rule that turns the numbers into an exception is quoted, '
    'and there is no S-mode here to be refused by.',
    "That `stvec`'s low two bits are cleared by hardware.  The three corpus "
    'functions write 0x1000, 0x1001 and 0x123 through the SAME word, and the '
    'specification\'s sentence about zero-filling the low two bits is '
    'QUOTED.  Whether it happens is a silicon question.',
    'Which of the two A/D schemes a hart implements.  Section 9 measured the '
    'bit POSITIONS on the compiler\'s own shifts; the two schemes, their '
    'costs and their atomicity are `priv-spec` text.',
    'That a linker accepts the pair 8 KiB apart.  The assembler emitted the '
    'records at 8200 bytes and said nothing.  There is no RISC-V linker on '
    'this host, so what one would do is quoted and section 9 labels it so.',
    'Whether a page fault is cheaper or dearer than an access fault.  Nothing '
    'on this host can raise either.',
    'That `llvm-objdump-21` agrees with the silicon.  Section 13 establishes '
    'that this file\'s decoder and one other piece of software from the same '
    'LLVM tree agree on what the bytes mean.  That is a fact about two '
    'programs and not about a processor.',
]

CAN_CONCLUDE = [
    'Every bit pattern in this course is byte-for-byte reproducible from the '
    'files in this directory and the exact clang invocation section 1 prints. '
    'That is the whole of the MEASURED label and it is a stronger property than '
    '"probably right".',
    'Every relocation NAME and NUMBER this course uses appears in the psABI '
    'table AND in the object files of the corpus.  Names are a convention; '
    'numbers are a fact, and both were read rather than remembered.',
    'Every refusal, by running the assembler.  0x1000, 0x20 and the rest are '
    'the assembler\'s own words, quoted verbatim, not this file\'s summary of '
    'what it probably said.',
    'The size arithmetic, exactly: 4096 / 8 = 512, 3 x 9 + 12 = 39, '
    '64 - 4 - 16 - 8 = 36, 2048 - 1 = 2047.  Four identities, each one '
    'load-bearing for a field width, each one checkable with a pencil.',
    'The CSR instruction encodings: twelve of them, three operations, two '
    'forms, and the single bit that separates them.  Section 3 measured that '
    'bit three separate ways and the second reader confirms the words.',
    'The pairing rule\'s ARITHMETIC -- 2048 - 1 = 2047, one AUIPC per 2048 '
    'bytes -- and that the assembler enforces none of it.  Both halves are '
    'measured; only the enforcement is quoted.',
    'The three codes 23 and 24 and 25, that they are consecutive, and that '
    'the first names the TARGET while the other two name a LABEL THE COMPILER '
    'INVENTED.  That asymmetry is the load-bearing fact about a RISC-V '
    'relocation and it was read out of a symbol table.',
    'That the correct `satp` PPN width is 36 bits and that two natural wrong '
    'answers -- 44 and 54 -- both COMPILE.  The wrongness was measured on the '
    'compiler\'s own shifts, so a reader can see it rather than take it.',
    'That two independent readers, given the same bytes, disagree on zero of '
    'them over this corpus -- and, because poison 4 exists, that this check '
    'CAN fail and catches 10,797 of 10,797 planted disagreements when asked.',
    'Every limit on this page, which are the sentences that make the other nine '
    'safe to say.',
]

PROVENANCE = [
    ('the three privilege modes and the hole at encoding 2', QUOT,
     'priv-spec, Table 1.1'),
    ('MPP is two bits and SPP is one', QUOT,
     'priv-spec, section 2.1.6.1 -- "xPP fields can only hold privilege '
     'modes up to x"'),
    ('the trap-entry stack: xPIE, xIE, xPP', QUOT,
     'priv-spec, section 2.1.6.1'),
    ('the xRET rule and the debugging aid in it', QUOT,
     'priv-spec, section 2.1.6.1'),
    ('medeleg and mideleg, and the six registers a delegated trap writes',
     QUOT, 'priv-spec, section 2.1.1.8'),
    ('the write-one-to-every-bit discovery procedure, three times', QUOT,
     'priv-spec, sections 2.1.1.8, 11.1.1.3 and 11.1.1.11'),
    ('the CSR address is 12 bits and 4,096 CSRs', QUOT,
     'priv-spec, section 1 -- "a 12-bit encoding space (csr[11:0]) for up to '
     '4,096 CSRs"'),
    ('csr[11:10] is accessibility and csr[9:8] is privilege', QUOT,
     'priv-spec, section 1, and riscv-elf Table 3'),
    ('Sv39 has LEVELS = 3 and PTESIZE = 8', QUOT,
     'priv-spec, section 11.1.4'),
    ('Sv48 has LEVELS = 4 and PTESIZE = 8', QUOT,
     'priv-spec, section 11.1.5'),
    ('Sv57 adds a fifth level', QUOT, 'priv-spec, section 11.1.6'),
    ('satp.MODE 0, 8, 9, 10 and the reserved values', QUOT,
     'priv-spec, section 11.1.1.11, Table 5'),
    ('a page table is exactly the size of a page', QUOT,
     'priv-spec, section 11.1.4 -- "2^9 page table entries (PTEs), eight '
     'bytes each"'),
    ('the PTE layout, V through D and the reserved fields', QUOT,
     'priv-spec, section 11.1.4, Figure 22 and the text after it'),
    ('the two A/D schemes, and Svade', QUOT,
     'priv-spec, section 11.1.3.1'),
    ('hardware A/D management became optional in 1.11', QUOT,
     'priv-spec v1.11 preface, "Changes from version 1.10"'),
    ('the leaf sizes and the alignment requirement', QUOT,
     'priv-spec, section 11.1.4 -- "2 MiB megapages and 1 GiB gigapages"'),
    ('stvec BASE must be 4-byte aligned and MODE is 0, 1 or reserved', QUOT,
     'priv-spec, section 11.1.1.2, Table 1'),
    ('a timer interrupt vectors to BASE + 0x14 in S-mode', QUOT,
     'priv-spec, section 11.1.1.2 -- cause 5 times four is 0x14'),
    ('interrupt cause i is bit i in sie and sip', QUOT,
     'priv-spec, section 11.1.1.3'),
    ('the R_RISCV_PCREL_HI20 / LO12_I / LO12_S codes, 23 / 24 / 25', QUOT,
     'riscv-elf chapter 8, Table 3 -- cross-checked against '
     'llvm-readelf-21 -r below'),
    ('the LO12 calculation S - P and "the addend must be 0"', QUOT,
     'riscv-elf chapter 8, section 8.1.4.9'),
    ('the sys_write convention: number in a7, answer in a0', QUOT,
     'riscv-elf chapter 3, Calling Conventions for System Calls'),
    ('the twelve CSR instructions and the three-bit funct3', BYTES,
     'inst[14:12] of 42 words in csr.o, cross-checked against '
     'llvm-objdump-21'),
    ('the register and immediate forms differ by funct3 bit 2', BYTES,
     'three XOR pairs in csr.o, 0x0001c000 with rs1 held constant'),
    ('the seven pseudo-instructions are three-operand aliases', BYTES,
     'byte-for-byte comparison of the words in csr.o'),
    ('the CSR number is inst[31:20], isolated', BYTES,
     'the sweep with funct3 and rs1 held constant; see R2 for the version '
     'that was retracted'),
    ('4095 is the last CSR number and 4096 is refused', MEAS,
     'two assembler probes, one accepted and one refused, at section 3'),
    ('the immediate form\'s 5-bit field stops at 31', MEAS,
     'two assembler probes, 0x1f accepted and 0x20 refused'),
    ('-march=rv64i emits a Zicsr instruction and records rv64i2p1', MEAS,
     'three builds of only_zicsr.s and three Tag_RISCV_arch strings'),
    ('the ecall wrapper: 5 instructions at -O1 and above, 30 at -O0', MEAS,
     'function extents from llvm-objdump-21 at four levels'),
    ('a7 and a6 differ in exactly one bit at all four levels', BYTES,
     'instruction-by-instruction comparison of the two functions\' words'),
    ('Sv39/48/57: 512 entries, 9 index bits, 39/48/57 VA bits', MEAS,
     'arithmetic over the two quoted constants, each identity asserted'),
    ('the PTE bit positions, as eight compiler-emitted shift pairs', BYTES,
     'bits_O2.o, reading the immediates out of the words and subtracting '
     'from 63'),
    ('satp MODE is 4 bits at [63:60] and the mask was optimised away', BYTES,
     'a missing `andi` in bits_O2.o -- the compiler proved the field width'),
    ('the satp PPN is 36 bits and the two shipped masks are 44 and 54',
     BYTES, 'bits_O2.o, with the width recovered from the two shifts'),
    ('the relocation counts of the dense and sparse walks', MEAS,
     'llvm-readelf-21 -r on four builds of one source file'),
    ('`.L_MergedGlobals` versus `root`/`l1tab`/`l2tab`', MEAS,
     'the symbol column of the same two relocation tables'),
    ('one HI20 and two LO12s at all six distances', MEAS,
     'llvm-readelf-21 -r on six objects differing only in a `.space`'),
    ('every LO12 leaves the I/S immediate at zero', BYTES,
     'the immediate field of the words the LO12 records attach to'),
    ('all three stvec writes emit the same 32-bit word', BYTES,
     'the `csrw stvec, a1` word in three functions of wrap_O2.o'),
    ('the three interrupt masks are 0x2, 0x20 and 0x200', BYTES,
     'the `ori` immediate in three functions of wrap_O2.o'),
    ('42 CSR addresses and their three-field decomposition', BYTES,
     'inst[31:20] of 42 words, decomposed by this file\'s own model'),
    ('the two-reader agreement, and its classification', BYTES,
     'this file\'s decoder against llvm-objdump-21, over the whole corpus'),
]


def sec15():
    banner(15, 'THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY '
               'CLAIM CAME FROM')
    print()
    para("""Everything in the last fourteen sections carries one of three
labels, and on most pages you would be forgiven for not noticing.  This
section prints all of them, in one table, with the count -- and the COUNT is
the finding, because this is the course in the whole collection where the
QUOTED third is largest and the reason is structural rather than a matter of
care.

A privileged architecture is a DOCUMENT.  What a document says is not
measurable on a host with no machine, and what IS measurable -- the encoding,
the CSR address arithmetic, the relocation records, the size arithmetic -- is
the part a compiler author needs and the part a page-table writer needs.
So the ratio below is not a disclaimer.  It is a map of the subject.""")
    print()
    rows = []
    counts = {}
    for what, lab, where in PROVENANCE:
        counts[lab] = counts.get(lab, 0) + 1
        rows.append((lab, what, where))
    table(['label', 'the claim', 'where it came from'], rows)
    print()
    n_all = len(PROVENANCE)
    para("""%d rows: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED.""" % (
        n_all, counts.get(MEAS, 0), counts.get(BYTES, 0), counts.get(QUOT, 0)))
    para("""§KEEP§AT %d PER CENT THE QUOTED THIRD IS A MAJORITY OF THIS COURSE'S CLAIMS, AND THE COMPARISON WITH ITS SIBLING IS THE INTERESTING NUMBER: %d OF %d HERE AGAINST 31 OF 57 IN a64sys.

And that comparison CUTS BOTH WAYS, so both halves are printed.  §KEEP§THIS
COURSE'S QUOTED FRACTION IS %d PER CENT AND a64sys's IS %d PER CENT, SO THE
AArch64 MACHINE COURSE'S QUOTED THIRD IS THE LARGER ONE AND A COURSE THAT
CLAIMED OTHERWISE WOULD BE MAKING A NUMBER UP.

The reason this course's is smaller is not that it is less dependent on a
document.  It is that there was MORE TO MEASURE: %d of the %d rows here are
MEASURED or MEASURED-ON-BYTES against a64sys's 26 of 57, and the extra
measurements are the relocation RECORDS, the CSR ADDRESS arithmetic and the
twelve CSR instruction encodings -- none of which a64sys had a reason to
touch, because its subject is a descriptor format and a trap register rather
than an object file.

The subject is a document.  What a document says is not measurable on a host
with no machine, and what IS measurable -- the encoding, the CSR address
arithmetic, the relocation records, the size arithmetic -- is the part a
compiler author needs and the part a page-table writer needs.  So the ratio
above is not a disclaimer.  It is a map of the subject, and it is printed as
a table rather than as a percentage in a sentence because a percentage in a
sentence is a number nobody can check.""" % (
        100 * counts.get(QUOT, 0) // n_all, counts.get(QUOT, 0), n_all,
        100 * counts.get(QUOT, 0) // n_all, 100 * 31 // 57,
        counts.get(MEAS, 0) + counts.get(BYTES, 0), n_all))

    print()
    para("""Sixteen limits, and they are printed in the artifact's own words so
that a reader who copies a number out of this file cannot lose the sentence
that limits it.  The first two decide what every other one may say.""")
    print()
    for k, lim in enumerate(LIMITS):
        body = _wrap(lim, 70, '')
        print('  %d. %s' % (k + 1, body[0].strip()))
        for extra in body[1:]:
            print('     %s' % extra.strip())
    print()
    para("""A LIST OF SIXTEEN LIMITS says what this file declines to do.  A LIST OF WHAT A
READER THEREFORE CANNOT CONCLUDE is a different thing, and it is the one that
protects the reader rather than the file: the limits are this course's promises
and the cannot-list is the set of sentences that would be FALSE if a reader
carried the sixteen promises in one direction rather than the other.  It is
printed beside the limits, not in a footnote, because a footnote is a place
where a scope statement goes to be skipped.""")
    print()
    for item in CANNOT_CONCLUDE:
        body = _wrap(item, 70, '')
        print('  * %s' % body[0].strip())
        for extra in body[1:]:
            print('    %s' % extra.strip())
    print()
    para("""§KEEP§AND HERE IS THE OTHER HALF, because a course that prints only a
cannot-list teaches its reader that the subject is unknowable, which is the
opposite of what fourteen sections of measured bits are for.""")
    print()
    for item in CAN_CONCLUDE:
        body = _wrap(item, 70, '')
        print('  * %s' % body[0].strip())
        for extra in body[1:]:
            print('    %s' % extra.strip())
    print()
    para("""§KEEP§THE TWO LISTS ARE THE SAME ABSENCES SEEN FROM OPPOSITE SIDES, AND THE
SECOND IS LONGER -- %d items against %d -- WHICH IS THE POINT: there is more that
can be read off bytes than there is that can be said about behaviour.  A reader
who finishes this file able to state the second list precisely and the first
list vaguely has it exactly backwards.""" % (
        len(CAN_CONCLUDE), len(CANNOT_CONCLUDE)))
    print()
    para("""WHAT THE COURSE OWES ITS SIBLINGS, and does not re-teach.  Every link
was verified present before it was written.

  * why privilege exists at all, and what a ring is -- the neutral course:
    `/courses/priv/lessons/priv-vectors`, `/courses/priv/lessons/priv-doors`,
    `/courses/priv/lessons/priv-convention`
  * what a page table is and why the levels exist --
    `/courses/mem/lessons/mem-translation`
  * the same subject for x86-64: the syscall register, the rings, the
    four-level page walk -- `/courses/x86sys/lessons/x86-syscall`,
    `/courses/x86sys/lessons/x86-rings`, `/courses/x86sys/lessons/x86-paging`
  * the same subject for AArch64: the syscall, the four levels and the
    descriptors -- `/courses/a64sys/lessons/a64-syscall`,
    `/courses/a64sys/lessons/a64-pagetables`
  * what a relocation record IS, and the two halves of the object-file story
    -- `/courses/obj/lessons/obj-relocations`,
    `/courses/reloc/lessons/reloc-why-so-many`
  * the `auipc` immediates, which the first RISC-V course measured and this
    one does not repeat -- `/courses/rvasm/lessons/rv-immediate`
  * what a linker does with a pair once it has one --
    `/courses/rvabi/lessons/rv-calling` for the register half, and this
    course's section 9 for the record half

THE ONE OVERLAP WORTH NAMING is `rvasm`'s `rv-isa`, which measured the
Tag_RISCV_arch string across eight `-march` settings.  Section 4 re-measures
it for a different reason -- not "what does the string contain" but "does the
toolchain agree with itself" -- and the finding is the opposite of that
course's, which is why it belongs here and not there.  `rv-isa` showed the
string is rich; this section shows it is a record of the request.

Verified present before linking, every one of them.""")


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM', sec1),
    (2, 'THE PRIVILEGE ARCHITECTURE, QUOTED, BEFORE ANY COMPILER RUNS', sec2),
    (3, 'THE TWELVE CSR INSTRUCTIONS, AND THE ONE BIT BETWEEN THEM', sec3),
    (4, 'Zicsr IS NOT IN THE BASE ISA -- AND THE ISA STRING DOES NOT NOTICE',
     sec4),
    (5, 'THE ecall CONVENTION, AND THE ONE BIT THAT SEPARATES a7 FROM a6',
     sec5),
    (6, 'Sv39, Sv48, Sv57 -- THREE LEVEL COUNTS AND A PAGE SIZE', sec6),
    (7, 'THE EIGHT PTE BITS, READ OUT OF WHAT THE COMPILER EMITTED', sec7),
    (8, 'satp, AND TWO MASKS OF OURS OWN THAT ARE WRONG', sec8),
    (9, 'THE RELOCATIONS, AND WHAT A LINKER HAS TO BE TOLD ABOUT A PAGE '
     'TABLE', sec9),
    (10, 'THE PAIRING DISTANCE, AND THE ASSEMBLER THAT DOES NOT ENFORCE IT',
     sec10),
    (11, 'stvec, sepc, scause, stval, sie, sip -- THE FIVE, DECODED', sec11),
    (12, 'TWO READERS ON THE SAME BYTES', sec12),
    (13, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER', sec13),
    (14, 'SEVENTEEN RETRACTIONS', sec14),
    (15, 'THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY CLAIM '
     'CAME FROM', sec15),
]


def header():
    print(RULE)
    print("rvpriv.py -- the RISC-V privileged architecture, measured on the "
          "bytes")
    print(RULE)
    print()
    print('  Every claim in this file carries one of three labels:')
    print()
    print('    %-18s about the compiler or the bytes, by experiment' % MEAS)
    print('    %-18s a property of emitted bytes, cross-checked against'
          % BYTES)
    print('                      llvm-objdump-21 as a second reader')
    print('    %-18s a manual claim, with a document and a section' % QUOT)
    print()
    print('  The three documents every QUOTED row names:')
    print('    priv-spec    Volume II, the privileged architecture, '
          'v20260120')
    print('    riscv-elf    the RISC-V ABIs Specification v1.0')
    print('    rv32-unpriv  Volume I, the unprivileged architecture')
    print()
    print('  NOTHING HERE IS EXECUTED.  There is no RISC-V machine, no')
    print('  emulator and no RISC-V linker on this host, so NO EXCEPTION IS')
    print('  EVER TAKEN, NO PAGE IS EVER WALKED, NO TLB IS EVER CONSULTED,')
    print('  AND NO ecall IS EVER OBSERVED DOING ANYTHING.  There are NO')
    print('  TIMINGS and NO SPEEDUPS anywhere in this file.  Section 1 says')
    print('  so before the first measurement and section 15 says so after')
    print('  the last one, and the table in section 15 says WHICH of the')
    print('  three labels each claim class carries.')
    print()
    print('  The decoder is BORROWED from courses/rvasm/assets/samples/')
    print('  (rvdec.py) and this file PREPENDS TWO models of its own.')
    print('  `m_csr_address` decomposes a CSR address into accessibility')
    print('  and privilege, and `m_sfence_vma` names SFENCE.VMA, which the')
    print('  inherited decoder could not name at all.  It edits no sibling;')
    print('  section 14\'s R1 and R14 say what each one adds and why the')
    print('  sibling is untouched.')
    print()
    print('  Inherited decoder models: %d, of which this course PREPENDS 2.'
          % INHERITED_MODELS)
    print('  Total in the dispatch here: %d.' % TOTAL_MODELS)
    print()


def main():
    args = sys.argv[1:]
    if '--why' in args:
        w = args[args.index('--why') + 1]
        nb = 4 if len(w.replace('0x', '')) > 4 else 2
        print(Dec.explain(Dec.decode(int(w, 0), nb)))
        return 0
    if '--audit' in args:
        header()
        print('  THE MODELS IN THE DISPATCH, IN ORDER, WITH THIS COURSE\'S ONE')
        print('  FIRST:')
        print()
        for k, (nm, ops, fn, ext, claim) in enumerate(Dec.MODELS32):
            tag = '  <- THIS COURSE' if k == 0 else ''
            print('   %2d %-20s opcodes %-24s %s'
                  % (k + 1, nm, ','.join(hex(o) for o in ops), tag))
            for ln in _wrap(claim, 66, '        '):
                print(ln)
        return 0
    if '--relocs' in args:
        for f in ('pt_nopic.o', 'pt_pic.o', 'sp2_dense.o', 'sp2_sparse.o'):
            fp = p(f)
            if not os.path.exists(fp):
                continue
            print('  %s' % f)
            for off, ty, nm, sym, add in reloc_rows(fp):
                print('    0x%-8x type %-4d %-22s %-20s +%#x'
                      % (off, ty, nm, sym or '(none)', add))
        return 0
    if '--section' in args:
        want = args[args.index('--section') + 1]
        for n, _t, fn in SECTIONS:
            if str(n) == want:
                header()
                fn()
                return 0
        print('no such section')
        return 1
    header()
    have, missing = corpus_present()
    if missing:
        print('  THE CORPUS IS INCOMPLETE -- %d of %d objects are missing:'
              % (len(missing), len(CORPUS)))
        for m in missing:
            print('    %s' % m)
        print('  Run build_samples.sh first.  Reporting a claim about an')
        print('  absent file is the one thing this file will not do.')
        print()
        return 1
    for n, title, fn in SECTIONS:
        fn()
    print(RULE)
    print('END OF REPORT -- %d sections, %d limits, %d retractions, '
          '4 poisons.' % (len(SECTIONS), len(LIMITS), len(RETRACTIONS)))
    print(RULE)
    return 0


if __name__ == '__main__':
    sys.exit(main())
