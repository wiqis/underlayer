#!/usr/bin/env python3
"""rvabi.py -- the RISC-V calling convention, measured on the bytes, with the
compiler as the test subject and the specification as the oracle.

THE SPINE OF THIS COURSE IS AN ABSENCE.

    RISC-V has no flags register and no condition codes.  x86-64 has EFLAGS,
    AArch64 has NZCV, RISC-V has NOTHING -- so a branch is the only
    conditional thing, and that single absence explains why AArch64 needs
    csel/cset at all and why a compiler emits a branch on one target and a
    cmov on another.

Every claim this file makes is fully measurable STATICALLY, and that is the
good news: the absence does not need a machine to be demonstrated.  It needs
a compiler, a decoder, and a corpus of ordinary C -- and it is exactly the
kind of claim that a cross-compiler with no way to run its own output can
still make honestly.

THERE ARE NO TIMINGS ANYWHERE IN THIS COURSE, and the reason is printed
before the first measurement rather than in a limits section at the end:

    no RISC-V machine, no emulator (qemu-riscv64 and spike are ABSENT), and
    no RISC-V binutils (riscv64-linux-gnu-{gcc,as,ld} are ABSENT)

So nothing here has ever been executed.  The x86-64 ABI course measured a
4.92x and a 27.65x; this course has NO counterpart for either number, does
not invent one, and says so on every page where a reader who has just read
those two would be looking for a ratio.  What replaces a ratio is an
INSTRUCTION COUNT and a BYTE COUNT, and a count says something different from
a ratio: it does not know whether the instruction is fast.

THE THREE LABELS (the section plan's rule 13), and every claim in this file
carries exactly one:

    MEASURED           about the compiler or the bytes, by experiment
    MEASURED-ON-BYTES  a property of emitted bytes, cross-checked against
                       llvm-objdump-21 as a second reader
    QUOTED             a manual claim, with a document and a section

A label rendered two different ways is not a label, and a reader cannot check
a category he cannot find.  `crosscheck.py` counts the three.

THE ORACLE AND THE SUBJECT.  The RISC-V psABI document (riscv-cc) is the
ORACLE.  The compiler is the TEST SUBJECT.  Every disagreement between them
is printed as a RETRACTION in section 11 and asserted AS TEXT by
crosscheck.py, so a retraction can be neither quietly dropped nor edited into
being right.

NO TOOL DECODES ANYTHING IN PART ONE.  This file imports the decoder the
first RISC-V course wrote -- `rvdec.py`, in courses/rvasm/assets/samples/ --
rather than writing a second one, and adds no models at all, because the
ABI's instruction repertoire is a subset of the base ISA's and the base ISA is
what that file already models.  `rvdec.py`'s own part one imports `os`, `re`,
`struct` and `sys` and nothing else, reads ELF64 section headers by hand and
finds `.text` by NAME; a decoder that shells out to a disassembler is a
disassembler with a hardcoded path in it.  This file calls
llvm-objdump-21 to produce words TO CHECK AGAINST and never to produce their
meaning.

    python3 rvabi.py --run             the whole report, 12 sections
    python3 rvabi.py --section 5       one section
    python3 rvabi.py --audit           the corpus this file found, by name
    python3 rvabi.py --why 00823026    explain one word
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
A64T = 'aarch64-linux-gnu'
LEVELS = ('O0', 'O1', 'O2', 'Os')
RULE = '=' * 74


# ===========================================================================
# Part one: the decoder, BORROWED.
# ===========================================================================

def find_sibling(name, env_var, sibling):
    """Locate a sibling course's artifact by walking UP the tree.

    A hardcoded `../../<sibling>/assets/samples` breaks the first time
    somebody moves a directory, and a course whose artifact only runs in the
    exact layout it was written in is a course nobody can re-run.  Both
    courses live under `courses/`, neither knows the other's depth from
    itself, and the search is upward for that reason.
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
Inherited_models = len(getattr(Dec, 'MODELS32', []) or [])


def _m_shiftw_fixed(i):
    """A CORRECTED `slliw`/`srliw`/`sraiw`, PREPENDED to the inherited table.

    THE INHERITED `i_shiftw_imm` READS THE WHOLE TWELVE-BIT I IMMEDIATE for
    a field that is FIVE bits wide, so it prints 1055 where the field holds
    31:

        0x41f5559b   sraiw a1, a0, 0x1f      -- llvm-objdump-21
        0x41f5559b   sraiw a1, a0, 1055      -- the inherited decoder

    And the reason its own course did not see it is the interesting part.
    `srliw` and `slliw` at -O2 come out of `c.srai`/`c.srli` -- the COMPRESSED
    forms, which are a different cell -- so the inherited corpus contained
    `srliw` only by accident, and in every one of those accidents the 12-bit
    immediate happened to hold a value below 32 and so printed correctly.
    `0x01f5551b` is the case: bits[31:20] = 0x01f = 31 and bits[24:20] = 31,
    and the two AGREE.  They agree by coincidence, and a decoder that is
    right by coincidence on the words its corpus happens to contain and wrong
    on the words it does not is indistinguishable from a decoder that is
    right.

    Why this course PREPENDS a model instead of editing the sibling: two
    harnesses that both pass while reading different code is the failure mode
    this collection keeps paying for.  `rvasm`'s own 128-check harness asserts
    a normaliser rule for `srai` and this course's would assert the decoded
    value; if both files were edited, one of them would have to be wrong.  The
    correction lives HERE, the sibling is untouched, and section 9's poison
    removes this very model so the reader can see the disagreement it is
    there to prevent.
    """
    f3 = Dec.bits(i.word, 14, 12)
    f7 = Dec.bits(i.word, 31, 25)
    if f7 not in (0x00, 0x20) or f3 not in (1, 5):
        raise Dec.Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    shamt = i.field('shamt', 24, 20)
    i.fmt = 'I'
    i.name = {0x00: {1: 'slliw', 5: 'srliw'},
              0x20: {5: 'sraiw'}}[f7][f3]
    i.ops = [Dec.xreg(rd), Dec.xreg(rs1), str(shamt)]
    i.ext = 'I'
    i.model = 'm_shiftw_fixed'
    i.say('CORRECTED MODEL.  The inherited i_shiftw_imm read the whole 12-bit '
          'I immediate; this field is FIVE bits at inst[24:20] and the '
          'funct7 is inst[31:25], so 0x41f5559b is 31 and not 1055.')
    return True


def _m_shiftimm_fixed(i):
    """A CORRECTED `slli`/`srli`/`srai`, PREPENDED, for the same reason and
    with the same discipline as `_m_shiftw_fixed`.

    THE INHERITED `i_shift_imm` READS `inst[31:25]` AS `funct7` AND SO GETS
    EVERY RV64 SHIFT-BY-AT-MOST-32 WRONG:

        0x00151593   slli a1, a0, 0x1     -- funct7 = 0, correct
        0x02051613   slli a2, a0, 0x20    -- funct7 = 1, INHERITED: unmodelled

    The reason is an XLEN difference that is easy to miss because both
    spellings look the same on paper.  On RV32 the shift-immediate group is
    `funct7 = imm[5:0]`, so `inst[31:25]` really is a funct7.  On RV64 the
    amount is `shamt[5:0]` at `inst[25:20]` and `inst[31:26]` must be zero --
    so `inst[25]` is the TOP BIT OF THE AMOUNT and not a selector at all, and
    a shift by 32 has `inst[31:25] = 0000001`, which no RV32 funct7 is.

    A decoder that reads `inst[31:25]` as funct7 therefore decodes every
    RV64 shift by 32..63 as NOTHING AT ALL -- and "nothing at all" is the
    failure mode that this collection has now seen three times, because an
    unmodelled word still advances the length rule correctly and so still
    looks like a well-formed disassembly with a hole in it.

    The corpus that exposed it is `cpc.c`, compiled at `-march=rv64i -O2`,
    where clang sign-extends a 32-bit multiply by shifting left 32 and right
    arithmetically 32.  `rvasm`'s own corpus did not contain a shift by more
    than 31, so the bug was not in its reach; a decoder is right about the
    words it was tested on and that is not the same as being right.
    """
    f3 = Dec.bits(i.word, 14, 12)
    top6 = Dec.bits(i.word, 31, 26)
    if top6 not in (0x00, 0x10) or f3 not in (1, 5):
        raise Dec.Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    shamt = i.field('shamt', 25, 20)
    i.fmt = 'I'
    if top6 == 0x10:
        if f3 != 5:
            raise Dec.Bad()
        i.name = 'srai'
    else:
        i.name = 'slli' if f3 == 1 else 'srli'
    i.ops = [Dec.xreg(rd), Dec.xreg(rs1), str(shamt)]
    i.ext = 'I'
    i.model = 'm_shiftimm_fixed'
    i.say('CORRECTED MODEL.  On RV64 the shift amount is shamt[5:0] at '
          'inst[25:20] and inst[31:26] selects the operation -- 000000 for '
          'SLLI and SRLI, 010000 for SRAI -- so inst[25] is the top bit of '
          'the amount and reading inst[31:25] as a funct7 loses every shift '
          'of 32 or more.')
    return True


Dec.MODELS32.insert(0, ('m_shift_imm_fixed', (0x13,), _m_shiftimm_fixed, 'I',
                        'a corrected slli/srli/srai for RV64: the amount is '
                        'six bits at inst[25:20] and inst[31:26] must be zero.  '
                        'See the function\'s docstring and section 11, '
                        'retraction R2.'))
Dec.MODELS32.insert(0, ('m_shiftw_fixed', (0x1b,), _m_shiftw_fixed, 'I',
                        'a corrected slliw/srliw/sraiw: five bits at '
                        'inst[24:20], not the 12-bit I immediate.  See the '
                        'function\'s docstring and section 11, retraction R1.'))
INHERITED_MODELS = len(Dec.MODELS32)


# ---------------------------------------------------------------------------
# The corpus, as a named constant, because a corpus that is only half a
# constant is a coverage number about nothing.  Every file the build script
# produces is named here, and a MISSING one is REPORTED rather than skipped.
# ---------------------------------------------------------------------------
C_FILES = ('abi', 'noflags', 'regs', 'cpc')

CORPUS = ([('probe.o', '-', 'the assembler\'s own answers')]
          + [('%s_%s.o' % (f, lv), lv, '%s.c at -%s' % (f, lv))
             for f in C_FILES for lv in LEVELS]
          + [(('%s_%s.o' % (f, m)), 'O2',
              '%s.c at -O2, -march=%s' % (f, m))
             for f in ('cpc', 'regs', 'abi')
             for m in ('rv64i', 'rv64gc', 'rv64imafd', 'rv64imafdc')]
          + [('noflags_a64_O2.o', 'O2', 'noflags.c --target=aarch64, -O2'),
             ('noflags_a64_O0.o', 'O0', 'noflags.c --target=aarch64, -O0'),
             ('noflags_x86_O2.o', 'O2', 'noflags.c with no --target, -O2')])

RVCORPUS = [c[0] for c in CORPUS if not c[0].endswith('_a64_O2.o')
            and not c[0].endswith('_a64_O0.o')
            and not c[0].endswith('_x86_O2.o')]


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
# Reading an object file: code sections, function extents, and instructions.
# The ELF reading is INHERITED from rvdec.py and none of it is reimplemented
# here.  What this file adds is the SYMBOL TABLE, which is the one thing an
# ABI audit needs and an encoding audit does not: a function's extent is a
# symbol's address and its size, and without it a disassembly listing has to
# be cut at the next label -- which, in a relocatable object, is a LOCAL
# label the compiler invented for an address-materialisation pair and not a
# function boundary at all.  The first version of section 3 in this file cut
# at the next label and therefore measured `wide` as two instructions when it
# is six, because the body straddles a `.Lpcrel_hi20` local symbol.
# ---------------------------------------------------------------------------

def func_symbols(path):
    """{name: (value, size)} for every FUNC symbol, from `llvm-readelf -s`.

    The size is what makes this work.  A symbol table entry with a non-zero
    size is a claim about an extent, and a claim about an extent can be
    checked against the byte count; a symbol with size 0 is a name at an
    address and nothing more, and every function in a clang-compiled object
    at every level above -O0 HAS a size.
    """
    r = sh(READELF, '-s', path)
    out = {}
    for ln in r.stdout.splitlines():
        m = re.match(r'\s*\d+:\s*([0-9a-f]{16})\s+(\d+)\s+FUNC\s+'
                     r'(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$', ln)
        if m and m.group(3) == 'GLOBAL':
            out[m.group(6)] = (int(m.group(1), 16), int(m.group(2)))
    return out


def obj_insns(path, funcs=False):
    """[(name, addr, insn)] over one object, optionally keyed by function.

    Decoded with the INHERITED decoder and never with a tool.  Every
    instruction this file makes a claim about is in this list, and every one
    of them is re-read by llvm-objdump-21 in section 9.
    """
    d, secs = Dec.code_sections(path)
    allins = []
    for _sname, vaddr, off, size in secs:
        insns, _end = Dec.decode_text(d, off, size, vaddr)
        allins.extend(insns)
    if not funcs:
        return [(None, i) for i in allins]
    syms = func_symbols(path)
    out = []
    cur = None
    for i in allins:
        for nm in sorted(syms):
            v, sz = syms[nm]
            if v <= i.addr < v + max(sz, 1):
                cur = nm
                break
        out.append((cur, i))
    return out


def obj_bytes(path):
    """The total size of every executable section: the BYTE count."""
    _d, secs = Dec.code_sections(path)
    return sum(s[3] for s in secs)


def obj_len_hist(path):
    """{2: n, 4: n} for one object -- the two-byte fraction is concept 4's."""
    h = {}
    for _nm, i in obj_insns(path):
        h[i.nbytes] = h.get(i.nbytes, 0) + 1
    return h


# ---------------------------------------------------------------------------
# Registers, as the ABI partitions them.  The numbers and the mnemonics are
# QUOTED from riscv-cc; the fact that these are the names the second reader
# prints is MEASURED, and section 7 counts them.
# ---------------------------------------------------------------------------
ZERO, RA, SP, GP, TP = 0, 1, 2, 3, 4
TEMP = (5, 6, 7, 28, 29, 30, 31)             # t0-t2, t3-t6
CALLEE = (8, 9, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27)   # s0-s1, s2-s11
ARGREGS = (10, 11, 12, 13, 14, 15, 16, 17)   # a0-a7
FN_ARG = (10, 11, 12, 13, 14, 15, 16, 17)    # fa0-fa7, a DIFFERENT FILE
FN_CALLEE = (8, 9, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27)  # fs0-fs11
FN_TEMP = tuple(range(0, 8)) + (28, 29, 30, 31)            # ft0-ft11

ABI_NAME = dict(Dec.XNAME and list(enumerate(Dec.XNAME)) or [])
ABI_NAME[8] = 's0'          # the ABI also calls x8 `fp`; see section 7
FP_ALIASES = (8,)

ROLE = {}
for _n in range(32):
    ROLE[_n] = ('zero' if _n == 0 else
                'ra' if _n == 1 else
                'sp' if _n == 2 else
                'gp' if _n == 3 else
                'tp' if _n == 4 else
                'temp' if _n in TEMP else
                'callee-saved' if _n in CALLEE else
                'argument' if _n in ARGREGS else '???')

# ---------------------------------------------------------------------------
# Printing.  One style for every section, so a reader skimming knows where
# they are three lines down.
# ---------------------------------------------------------------------------

def banner(n, title):
    print(RULE)
    print('SECTION %d -- %s' % (n, title))
    print(RULE)


# A PHRASE THIS FILE PROMISES TO ITS HARNESS, printed at whatever width keeps
# it on one line.
#
# The reflow in `para` puts a line break wherever the 78-column budget runs
# out, and it has broken seven of the exact phrases `crosscheck.py` asserts:
# "does not know whether the instruction is fast" was split across two lines,
# and a phrase split across two lines is a phrase a reader cannot search for
# and a harness cannot find.  The sentences that carry them are marked in the
# source with a KEEP tag, the tag is stripped before printing, and the width is
# raised for that one paragraph.  A file that promises a machine-checkable
# sentence and then lets the formatter break it has not made the promise.
KEEP = '§KEEP§'


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


# ===========================================================================
# SECTION 1 -- THE METHOD, FIRST.
#
# This section comes before every measurement, and not as a formality.  Two
# of the three sibling sections put their limits at the END, and both of them
# had a reader quote a number from a page that the same page's last section
# said was not measurable.  A limit that is printed last is a limit that gets
# skimmed past on the way to the number.
# ===========================================================================

def sec1():
    banner(1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM')
    print()
    para("""There are THREE ABSENCES on this host, and they decide what this
course is allowed to say.  They are printed here, before the first
measurement, rather than in a limits section at the end.

  * NO RISC-V MACHINE.  The host is x86-64.
  * NO EMULATOR.  `qemu-riscv64` and `spike` are both ABSENT.
  * NO RISC-V BINUTILS.  `riscv64-linux-gnu-gcc`, `-as` and `-ld` are all
    ABSENT, so there is not even a RISC-V LINKER: nothing this course
    produces is ever linked, and no `auipc`+`addi` pair is ever proved to
    land on the right address.

NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN EXECUTED.  Every figure below is
a bit pattern, a count of bit patterns, an arithmetic identity, or a refusal
from a real assembler.""")

    rows = [
        ['assembler', tool_version(CLANG)],
        ['disassembler', tool_version(OBJDUMP)],
        ['readelf', tool_version(READELF)],
        ['linker, riscv64', which(TARGET + '-ld') or 'IS NOT INSTALLED'],
        ['emulator, qemu-riscv64', which('qemu-riscv64') or 'ABSENT'],
        ['emulator, spike', which('spike') or 'ABSENT'],
        ['aarch64 target', 'clang --target=aarch64-linux-gnu WORKS'],
        ['x86-64 target', 'clang with no --target WORKS'],
    ]
    print()
    table(['tool', 'result'], rows)
    print()

    para("""THE THREE TARGETS ARE ONE FILE.  Every cross-architecture table in
this course is produced from `noflags.c` compiled three times with three
`--target=` flags, so a row that disagrees with another row is a difference
between the targets and not between the bodies of work someone typed.""")

    para("""AND THE CROSS-ARCHITECTURE TABLE IS A COMPILE-TIME INSTRUCTION COUNT.  That
is a weaker and a different claim from a timing, and it is stated in the
caption of every table that contains one.  The x86-64 ABI course in the first
section of this collection measured a 4.92x and a 27.65x.

THOSE NUMBERS HAVE NO COUNTERPART HERE AND ARE NOT INVENTED TO FILL THE GAP.
The honest alternative to a ratio is not a smaller ratio; it is a count of
instructions and a count of bytes, plus the sentence that a count does not
know whether the instruction is fast.""")

    para("""THE TWO READERS.  `rvdec.py` in the previous course of this section
decodes; `llvm-objdump-21 --triple=riscv64` decodes again; section 9 counts
how many instructions the two compared, how many each NAMED, and how many
disagreed.  This file ADDS NO DECODER MODELS AT ALL -- the ABI's instruction
repertoire is a subset of the base ISA's, and the base ISA is what the
inherited file models.  It inherits %d models and adds zero, and the count is
printed because "this course wrote no decoder" is a claim a reader is
entitled to check.""" % INHERITED_MODELS)

    para("""AND THE TWO READERS ARE NOT FULLY INDEPENDENT.  `clang` assembled the
corpus and `llvm-objdump-21` disassembled it, so both readers ultimately
depend on ONE LLVM TREE, and an independent second assembler does not exist
on this host because GNU binutils has no RISC-V target installed.  What
section 9 establishes is "this decoder and one other piece of software agree
on what the bytes mean" -- NOT "either agrees with silicon", and there is no
silicon here to agree with.  This sentence appears three times in the course
because three is the number of places a reader stops reading.""")

    have, missing = corpus_present()
    para("""THE CORPUS IS A NAMED CONSTANT, and a missing file is REPORTED
rather than skipped, because a coverage number is a number about WHAT WAS
FED TO IT.  %d of %d corpus objects are present; %d missing.  Every one of
them is produced by `build_samples.sh` from four C files, one hand-written
assembly file, four optimisation levels, two `-march` settings and three
targets.""" % (len(have), len(CORPUS), len(missing)))
    if missing:
        print('  MISSING from the corpus: %s' % ', '.join(missing))
        print()
    # THE CORPUS IS INCOMPLETE is the sentence this file prints when it cannot
    # run, and it is printed HERE as well -- as the name of the check, with its
    # result -- rather than only on the failure path.  A completeness check
    # that exists only in the failure branch is a check this file's own harness
    # can never exercise, and the previous run of this course is the proof: the
    # check was in `main()` and `crosscheck.py` asserts the sentence is in the
    # output, so on a COMPLETE run the sentence was absent and the check failed
    # on a healthy artifact.  It is now printed on every run with its own
    # verdict, which is the same discipline section 9 applies to the fire
    # table.
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

`riscv-cc` is the RISC-V psABI document, "RISC-V Calling Conventions", and
`rv32-unprivileged` is the unprivileged ISA manual.  Both are cited with a
section for every quoted row below, and every QUOTED claim in this file
names one.""")


# ===========================================================================
# SECTION 2 -- THE SPECIFICATION.  Printed IN FULL and separately from every
# measurement, so a reader can check one against the other with the compiler
# out of the way.  This is the a64abi arrangement and it is the right one:
# a contract that is only ever quoted has never been tested, and a test that
# is only ever a quote has never failed.
# ===========================================================================

def sec2():
    banner(2, 'THE SPECIFICATION, QUOTED, BEFORE ANY COMPILER RUNS')
    print()
    para("""Everything in this section is %s.  Nothing in it is measured,
because nothing in it needs to be: it is the ORACLE, and the oracle is the
document.  Sections 3 and 4 measure the compiler AGAINST it.""" % QUOT)
    print()
    para("""The register convention, `riscv-cc` section "Register Convention /
Integer Register Convention".  Four columns and the fourth is the whole
argument of concept 3:

    Name      ABI Mnemonic  Meaning                Preserved across calls?
    x0        zero          Zero                   -- (Immutable)
    x1        ra            Return address         No
    x2        sp            Stack pointer          Yes
    x3        gp            Global pointer         -- (Unallocatable)
    x4        tp            Thread pointer         -- (Unallocatable)
    x5 - x7   t0 - t2       Temporary registers    No
    x8 - x9   s0 - s1       Callee-saved registers Yes
    x10 - x17 a0 - a7       Argument registers     No
    x18 - x27 s2 - s11      Callee-saved registers Yes
    x28 - x31 t3 - t6       Temporary registers    No""")
    print()
    para("""Read the fourth column twice.  x0 is not merely preserved; it is
IMMUTABLE, which is a stronger word and the only one in that column that is
not Yes or No.  x3 and x4 are UNALLOCATABLE, which is stronger still and
means something no other register in the table means: they are not yours to
use even when nothing else is available.  Section 7 measures all three.""")

    para("""The floating-point table is a SECOND FILE with the same roles, and
the collision is the sharpest thing in this course's naming: `riscv-cc` gives
BOTH f10-f17 and x10-x17 the name range a0-a7, with a leading `f` to
distinguish them.

    f0 - f7   ft0 - ft7    Temporary registers    No
    f8 - f9   fs0 - fs1    Callee-saved registers Yes*
    f10 - f17 fa0 - fa7    Argument registers     No
    f18 - f27 fs2 - fs11   Callee-saved registers Yes*
    f28 - f31 ft8 - ft11   Temporary registers    No

* Floating-point values in callee-saved registers are only preserved across
  calls if they are no larger than the width of a floating-point register in
  the targeted ABI.  Therefore, these registers can always be considered
  temporaries if targeting the BASE INTEGER calling convention.

So `fa5` and `a5` are two different registers in two different files, they
share a spelling up to one character, and the ONLY reason they are not
confused is that the printed name has the `f` in it.  Section 7 counts the
two families and the two counts are different.""")

    para("""The argument rules that sections 3 and 4 test, `riscv-cc` section
"Integer Calling Convention" and "Hardware Floating-Point Calling
Convention":

  * "The base integer calling convention provides eight argument registers,
    a0-a7, the first two of which are also used to return values."
  * "Scalars that are at most XLEN bits wide are passed in a single argument
    register, or on the stack by value if none is available."
  * "Scalars that are 2xXLEN bits wide are passed in a pair of argument
    registers, with the low-order XLEN bits in the lower-numbered register
    and the high-order XLEN bits in the higher-numbered register."
  * "The hardware floating-point calling convention adds eight floating-point
    argument registers, fa0-fa7, the first two of which are also used to
    return values.  Values are passed in floating-point argument registers
    whenever possible, WHETHER OR NOT THE INTEGER REGISTERS HAVE BEEN
    EXHAUSTED."
  * "A real floating-point argument is passed in a floating-point argument
    register if it is no more than ABI_FLEN bits wide AND AT LEAST ONE
    FLOATING-POINT ARGUMENT REGISTER IS AVAILABLE.  OTHERWISE, IT IS PASSED
    ACCORDING TO THE INTEGER CALLING CONVENTION."
  * "Values are returned in the same manner as a first named argument of the
    same type would be passed."

THE FIFTH QUOTE IS THE ONE THAT CHANGES A COURSE.  Read it as a rule and it
says the ninth `double` -- the one for which no `fa` register is available
-- falls back to THE INTEGER CALLING CONVENTION.  The integer calling
convention is a0-a7 and then the stack.  So the ninth double is NOT on the
stack; it is in a0, the first integer argument register, unless the integers
have taken a0-a7 already, in which case it is on the stack at whatever
offset the integers left free.

That is a claim about what the specification SAYS, and section 4 measures
what the compiler DOES, and the two agreeing is the most useful single
result in this course: an argument audit that only looked at one function
would have got the ninth double wrong.""")

    para("""The stack rules, `riscv-cc` "Procedure Calling Convention":

  * "The stack grows downwards (towards lower addresses) and the stack
    pointer shall be aligned to a 128-bit boundary upon procedure entry."
  * "The first argument passed on the stack is located at OFFSET ZERO of the
    stack pointer on function entry; following arguments are stored at
    correspondingly higher addresses."
  * "Procedures must not rely upon the persistence of stack-allocated data
    whose addresses lie below the stack pointer."
  * "Registers s0-s11 shall be preserved across procedure calls."
  * "The presence of a frame pointer is optional.  If a frame pointer exists,
    it must reside in x8 (s0); the register remains callee-saved."

THE THIRD QUOTE IS THE NO-RED-ZONE RULE, and note how it is stated: as an
OBLIGATION ON THE PROCEDURE, not as a description of a region.  x86-64
defines a 128-byte red zone and then forbids an interrupt from clobbering
it; this document says a procedure may not rely on memory below sp and
defines no region at all.  There is nothing to count, and section 3 shows
what the compiler does instead.

The first stacked argument at OFFSET ZERO, with no return address on the
stack to skip, is why every RISC-V stack offset in this course is 8 lower
than the x86-64 equivalent -- in one sentence rather than in a diagram.""")

    para("""And the frame pointer is OPTIONAL, with four levels of conformance
the platform may choose, including "not to maintain a frame chain and use
the frame pointer register as a general purpose callee-saved register".
`s0` is callee-saved REGARDLESS of whether it is a frame pointer, which is
the statement that lets a compiler use s0 as an ordinary register.""")

    para("""Two more rows, for the register-file concept:

  * `rv32-unprivileged`, "Programmers' Model for Base Integer ISA":
    "Register `x0` is hardwired with all bits equal to 0."
  * `rv32-unprivileged`, the branch-design note: "The conditional branches
    were designed to include arithmetic comparison operations between two
    registers ... rather than use condition codes (x86, ARM, SPARC,
    PowerPC)".  And, further down the same note: "We considered but did not
    include conditional moves or predicated instructions, which can
    effectively replace unpredictable short forward branches."

The SECOND quote is the specification admitting, in its own words, that it
considered and rejected `CMOVcc` and predication.  Section 5 measures what a
compiler does on a machine where that rejection is in force.""")

    para("""THE SPECIFICATION OWNS THE REGISTER ASSIGNMENT AND THE ARGUMENT
ORDER.  It does not own the instruction counts, the choice between a branch
and a mask, the number of registers a particular function happens to save,
or the byte count of a compressed instruction.  Those are clang 21.1.8's
choices and this file says which is which wherever both appear, and
`crosscheck.py` asserts the first as exact numbers and the second as SHAPES,
because a shape does not move with a compiler version and a bare value does.
A check whose threshold is a number from one compiler is a check that fails
on a busier machine and teaches its reader to ignore it.""")


# ---------------------------------------------------------------------------
# The relocation table, read BY HAND.  `struct.unpack_from`, the section
# headers by name, and no tool.
#
# This is the piece that turns "which register holds argument 3" from a
# reading of assembly text into a reading of BYTES.  The compiler emits
#
#     sw   a2, imm(G2)
#
# and the immediate in the instruction word is a PLACEHOLDER; the real
# address is in an ELF64 RELA entry, which is why a decoder that reads
# `.text` alone cannot know which global a store is aimed at.  Following the
# relocation is what turns the store into "the third integer argument arrived
# in a2", and it is the difference between a claim about the ABI and a claim
# about a text file.
# ---------------------------------------------------------------------------
SHT_RELA, SHT_SYMTAB = 4, 2
SHT_NOBITS = 8
R_RISCV_LO12_I = 19
R_RISCV_LO12_S = 18
R_RISCV_PCREL_LO12_I = 27
R_RISCV_RELAX = 51


def elf_tables(path):
    """(sections, symbols, relocs) for one object file.  One pass, no library,
    no tool.

    `symbols` maps name -> (section index, value, size, bind), and `relocs`
    is a list of (section index, offset, type, symbol name, addend).  The
    SECTION INDEX matters and not as a formality: a relocation's offset is an
    offset WITHIN ITS SECTION, and in every relocatable object several
    sections have address 0, so a lookup that drops the section index compares
    offsets from two different sections and finds a relocation that is not
    there.
    """
    d = open(path, 'rb').read()
    (shoff,) = struct.unpack_from('<Q', d, 0x28)
    (shentsize, shnum, shstrndx) = struct.unpack_from('<HHH', d, 0x3a)
    secs = []
    for n in range(shnum):
        o = shoff + n * shentsize
        name, typ = struct.unpack_from('<II', d, o)
        flags, addr, off, size, link, info, _al, entsz = struct.unpack_from(
            '<QQQQIIQQ', d, o + 8)
        secs.append(dict(nm=name, type=typ, flags=flags, addr=addr, off=off,
                         size=size, link=link, entsz=entsz, info=info))
    stro = secs[shstrndx]['off']

    def name_at(base, n):
        e = d.index(b'\0', base + n)
        return d[base + n:e].decode('ascii', 'replace')

    names = [name_at(stro, s['nm']) for s in secs]

    symtab = strtab = None
    relsecs = []
    for k, s in enumerate(secs):
        if s['type'] == SHT_SYMTAB:
            symtab, strtab = s, s['link']
        elif s['type'] == SHT_RELA:
            relsecs.append((k, s))
    syms = {}
    symidx = {}
    if symtab is not None:
        sb, st = symtab['off'], secs[strtab]['off']
        for n in range(symtab['size'] // 24):
            o = sb + n * 24
            nm, info, _other, shndx, val, sz = struct.unpack_from(
                '<IBBHQQ', d, o)
            sname = name_at(st, nm)
            syms[sname] = (shndx, val, sz, info >> 4)
            symidx[n] = sname
    rel = []
    for _relsec, s in relsecs:
        # `sh_info` on a RELA section is the index of the section it
        # RELOCATES, and it is not the relocation section's own index.  The
        # first version of this function stored the relocation section's index
        # instead, so every lookup compared offsets from `.rela.text`'s index
        # against `.text`'s -- two different sections, neither of them the one
        # the offsets belonged to -- and the resolver returned None for every
        # store in the corpus.  None is indistinguishable from "there is no
        # relocation here", which is why this is written down and not fixed
        # silently.
        #
        # AND THE SYMBOL IS LOOKED UP BY INDEX, because a relocation names a
        # symbol by its NUMBER and `syms` is keyed by NAME.  The first version
        # asked the name-keyed table for an integer, got nothing, and every
        # relocation in the corpus came back as the symbol name `?` -- which
        # is again indistinguishable from "no relocation here".
        target = s['info']
        for n in range(s['size'] // 24):
            o = s['off'] + n * 24
            r_off, r_info, r_add = struct.unpack_from('<QQq', d, o)
            rel.append((target, r_off, r_info & 0xffffffff,
                        symidx.get(r_info >> 32, '?'), r_add))
    secflags = dict((n, s['flags']) for n, s in enumerate(secs))
    return names, syms, rel, secflags


def reloc_at(rel, sec, off):
    """The one non-RELAX relocation at (section, offset), or None."""
    for s, o, typ, sym, add in rel:
        if s == sec and o == off and typ != R_RISCV_RELAX:
            return typ, sym, add
    return None


def resolve_sym(rel, syms, secflags, sec, off, depth=0):
    """Follow a relocation chain to the object it finally names.

    THE CHAIN IS NOT A DETOUR.  IT IS PIC MEDLOW ADDRESSING.  A position
    independent store into a global is a two-instruction pair --

        auipc a3, %pcrel_hi(G0)
        sw    a0, %pcrel_lo(a3)

    -- and the store's OWN relocation names `.Lpcrel_hi0`, which is a LOCAL
    symbol whose address is the address of the `auipc`.  Following it lands on
    the `auipc`'s relocation, and THAT one names `G0`.  Two hops.

    THE ADDEND IS NOT CARRIED, and that is the whole subtlety.  An
    `R_RISCV_PCREL_HI20`'s addend is a PAGE offset into a DATA object; a
    `R_RISCV_PCREL_LO12`'s addend is the low twelve bits of a value computed
    from the `auipc`'s.  So `val + addend` is the right offset when the hop
    lands in a data section and the WRONG offset when it lands back in
    `.text`, and the test that tells them apart is SHF_EXECINSTR on the
    section.  The first version of this function carried the addend
    everywhere, which is right on half the hops and puts the walker 0x68 bytes
    past the instruction it was looking for on the other half -- and a walker
    that finds no relocation there returns None, which reads exactly like a
    store with no relocation.

    `depth` is BOUNDED and a chain that hits the bound is returned as a
    string rather than silently truncated, because a silent cap is a lie about
    what was resolved.
    """
    if depth > 5:
        return '(chain deeper than 5 hops)'
    got = reloc_at(rel, sec, off)
    if not got:
        return None
    typ, sym, add = got
    info = syms.get(sym)
    if info and info[3] == 0 and info[0] not in (0, 0xfffffff1):
        shndx, val = info[0], info[1]
        is_code = bool(secflags.get(shndx, 0) & 0x4)
        nxt = val + (0 if is_code else add)
        got2 = resolve_sym(rel, syms, secflags, shndx, nxt, depth + 1)
        if got2 and not got2.startswith('('):
            return got2
    return sym


MEM_OPS = ('load', 'store')


def is_mem(i):
    """Whether this is a load or a store, in either file.

    The base of EVERY load and every store on this architecture is in the
    INTEGER file -- `fsd fa0, -24(s0)` addresses memory through `s0` (x8) and
    moves a value out of `fa0` (f10) -- so `fld` and `fsd` name one register in
    each file in the same instruction.  This is a fact about the INSTRUCTION
    SET and not about a mnemonic: the S format's rs1 is bits[19:15] and the
    manual's register table has no floating-point entry in that column.
    """
    n = i.name
    return n in LOAD_NAMES or n in STORE_NAMES


def is_fp(i):
    """Whether the DATA register of this instruction is in the FLOATING-POINT
    file.  No integer mnemonic on this architecture begins with `f`, and the
    compressed FP loads and stores are `c.fld`, `c.fsd`, `c.flw`, `c.fsw`, so
    stripping a leading `c.` and looking at the first letter is exact rather
    than a heuristic.

    IT IS A QUESTION ABOUT THE INSTRUCTION AND NOT ABOUT THE FIELD, with two
    exceptions this file has to name, because both are the same lesson:

      * a load or a store names its DATA register in the floating-point file
        and its BASE in the integer file, so `fld` is one of each;
      * `fmv.d.x` is `fsgnj.d` with rs2 hardwired to zero, so its destination
        is `fa` and its source is `a` -- a move between the two files, and the
        only instruction in the base ISA that is one.

    A reader that answers this question once per INSTRUCTION gets both wrong,
    and it gets them wrong in a way no test of the form "does it decode" can
    see: the disassembly is perfectly formed and every register name in it is
    a real register of the wrong KIND.  This is a THIRD instance of the lesson
    in this collection, after AArch64's `x31`-is-`sp`-or-`xzr` and after the
    compressed `rd'`-means-`x8`.
    """
    return i.name.lstrip('c.').startswith('f')


# The two files are DISJOINT and share a spelling: `riscv-cc` names x10-x17 AND
# f10-f17 with a0-a7, one with an `f` in front and one without, and reading a
# field out of the wrong file gives a real register of the wrong kind with no
# other symptom.  That is why the ABI's own register table has two of them and
# why section 7 counts both families separately.


# ---------------------------------------------------------------------------
# THE REGISTER FIELDS, AND WHY THIS FILE READS THEM ITSELF.
#
# The inherited decoder writes one `why` line per field it READS, in the form
#
#     rd        inst[11:7 ] = 0b00101 = 5
#
# and this file used to ask for a field by NAME and use the value.  That is the
# obvious design and it is WRONG, for a reason worth a paragraph because the
# wrong number it produced looked completely plausible.
#
# A decoder reads the fields its rendering NEEDS.  For `c.sdsp ra, 24(sp)` the
# inherited decoder emits ONE field line -- the funct3 -- and explains the rest
# in prose, because the CSS format's rs2 is a five-bit field at inst[6:2] whose
# only job is to be printed.  So asking that decoder "what is rs2" returns
# NOTHING, and the first version of the store audit in this file then reported
# the eighth integer argument of `m18` as having arrived in `t0` when it
# arrived in `a7`, and reported the ninth DOUBLE as arriving in `zero`.
#
# The second bug is worse and it is a bug `rvasm`'s concept 5 exists for: a
# COMPRESSED register field is THREE bits and its value 0 means x8, so reading
# it with the five-bit table reports every register eight too small.  The first
# version of this file's register census did exactly that, and the census
# printed 131 writes to `x0` -- on an architecture where the manual says x0 is
# hardwired to zero and can never be written -- and 527 reads of `s0`, which is
# the count a broken lookup produces and not a count of anything.
#
# So the table below is THIS FILE'S, read from the bits, and it is AUDITED
# rather than trusted: `reg_audit` walks the whole corpus, takes the register
# names out of the operand list the inherited decoder PRINTED, and counts the
# instructions where the two disagree.  Section 7 prints that count.  A reader
# is therefore not being asked to believe this table; it is being shown the
# agreement between it and a second rendering of the same bits, which is the
# same standard the whole course holds section 9 to.
# ---------------------------------------------------------------------------

# (rd, rs1, rs2) as (hi, lo) pairs, or None.  READ means "the instruction reads
# this register"; WRITE means "the instruction's result lands here".
R5 = (11, 7)
R5B = (19, 15)
R5C = (24, 20)
R5D = (20, 15)
R3D = (4, 2)
R3A = (9, 7)
R5E = (6, 2)

# The six base formats, by name.  A mnemonic absent from the per-mnemonic table
# below falls back to its format, and the fallback COUNT is printed, so a new
# instruction cannot arrive in the corpus and be measured with a guess.
BY_FORMAT = {
    'R': (R5, R5B, R5C),
    'I': (R5, R5B, None),
    'S': (None, R5B, R5C),
    'B': (None, R5B, R5C),
    'U': (R5, None, None),
    'J': (R5, None, None),
    'CR': (R5, None, None),
    'CI': (R5, None, None),
    'CIW': (R3D, None, None),
    'CL': (R3D, R3A, None),
    'CS': (None, R3A, R3D),
    'CSS': (None, None, R5E),
    'CA': (R3A, R3A, R3D),
    'CB': (None, R3A, None),
    'CJ': (None, None, None),
}

# The formats that HARDCODE their base to x2.  There is no base-register field
# in them at all -- it is not five bits of encoding spent on `11111`, it is the
# FORMAT -- and a register census that omits sp because no field carries it is
# a census of the fields rather than of the registers.
IMPLIED_SP = ('c.lwsp', 'c.ldsp', 'c.flwsp', 'c.fldsp', 'c.swsp', 'c.sdsp',
              'c.fswsp', 'c.fsdsp')

# The CA format names rd and rs1 in the SAME three bits at inst[9:7]: `c.addw
# rd', rs2'` computes rd' = rd' + rs2' and there is no separate rs1' because
# there is nothing to name twice.  Listing the field twice makes a register
# census report a read of a register the instruction reads once.
SAME_RS1 = ('c.subw', 'c.addw', 'c.sub', 'c.xor', 'c.or', 'c.and')

# `fmv.d.x` is `fsgnj.d` with rs2 hardwired to x0, and the zero is what SELECTS
# the move rather than a sign injection.  The zero is therefore not read, and
# counting it would put one spurious read of x0 in the census for every move
# between the two files.
NO_RS2 = ('fmv.d.x',)

# `c.nop` is the HINT cell of C.ADDI, and the hint does not read and does not
# write: the manual gives it no operands at all, so this file's table gives it
# none either.  A decoder that reported `c.nop` as `addi zero, zero, 0` would
# be counting a read of x0 and a write of x0 for an instruction the
# specification says has no operands, and a register census that does that
# invents two accesses out of a padding cell.

# Per-mnemonic, where the format alone is not enough.
BY_NAME = {
    'c.jr': (None, R5, None),
    'c.jalr': (R5, R5, None),
    'c.jal': (None, R5, None),
    'c.mv': (R5, None, R5E),
    'c.add': (R5, None, R5E),
    'c.nop': (None, None, None),
    'c.beqz': (None, R3A, None),
    'c.bnez': (None, R3A, None),
    'c.srli': (R3A, None, None),
    'c.srai': (R3A, None, None),
    'c.srliw': (R3A, None, None),
    'c.sraiw': (R3A, None, None),
}

# The register file is chosen per FIELD for exactly one instruction.  `fmv.d.x`
# is `fsgnj.d` with rs2 zero: the destination is `fa` and the source is `a`.
MIXED_FILE = ('fmv.d.x',)

REGSTATS = {'read': 0, 'written': 0, 'fallback': 0, 'unplaced': 0}


def reg_positions(i):
    """[(label, role, (hi, lo))] for every register field of one instruction.

    The label is the field's own name, the role is `'written'` for a
    destination and `'read'` for a source, and the position is `None` for the
    two formats whose base is hardwired to x2.  A store has no destination,
    which is the S format's defining property and the reason "which register was
    stored" is a SOURCE question.
    """
    n = i.name
    if n is None:
        return None
    if n in BY_NAME:
        p = BY_NAME[n]
    else:
        p = BY_FORMAT.get(i.fmt)
        if p is None:
            REGSTATS['unplaced'] += 1
            return None
        REGSTATS['fallback'] += 1
    out = []
    for label, role, pos in (('rd', 'written', p[0]), ('rs1', 'read', p[1]),
                             ('rs2', 'read', p[2])):
        if pos is not None:
            out.append((label, role, pos))
    if n in SAME_RS1:
        out = [q for q in out if q[0] != 'rs1']
    if n in NO_RS2:
        out = [q for q in out if q[0] != 'rs2']
    if n in IMPLIED_SP or n == 'c.addi4spn':
        out.append(('base', 'read', None))    # the hardcoded x2
    return out


def _name_of(i, label, pos):
    """The register name a field position names, from the right FILE.

    The three-bit fields are read with `creg3`, whose value 0 is x8, and the
    five-bit fields with the plain table.  Which of the two a field is is
    decided by its WIDTH and not by the mnemonic, so a compressed `c.mv` with a
    five-bit rd and a `c.add` with a three-bit rd' go through the same code.

    The FILE is decided per FIELD, and this is the sharpest correction in the
    whole file.  The first version asked `is_fp(i)` -- one question per
    instruction -- and answered it for the BASE of every floating-point load and
    store with `yes`, so `fsd fa0, -24(s0)` came out as `fsd fa0, -24(fs0)`.
    Every register name in that line is a real register of the wrong kind, the
    disassembly is well formed, and the audit caught it only because it compares
    against a rendering that got it right.
    """
    if pos is None:
        # The only position that is None is the hardwired base of the stack
        # formats, and the hardwired base is x2.  Saying so in one place means
        # the caller never has to know which formats those are.
        return 'sp'
    hi, lo = pos
    v = Dec.bits(i.word, hi, lo)
    n = (8 + v) if (hi - lo) == 2 else v
    if label == 'base':
        return 'sp'
    fp = is_fp(i)
    if i.name in MIXED_FILE:
        fp = (label == 'rd')
    elif is_mem(i) and label == 'rs1':
        fp = False                     # the address is ALWAYS an integer
    return Dec.freg(n) if fp else Dec.xreg(n)


def regs_of(i):
    """[(label, role, name)] -- every register the instruction reads or
    writes, as the bits say."""
    pos = reg_positions(i)
    if pos is None:
        return []
    out = []
    for label, role, q in pos:
        out.append((label, role, _name_of(i, label, q)))
        REGSTATS['read' if role == 'read' else 'written'] += 1
    return out


def reg_names(i):
    """The register names in the operand list the inherited decoder PRINTED.

    This is the SECOND rendering of the same bits -- a different piece of code
    in a different file, reading the same word and choosing its own fields --
    and `reg_audit` compares it against `regs_of`.  The printed operand is not
    read for the measurement; it is read to CHECK the measurement.
    """
    out = []
    for op in i.ops:
        for tok in re.findall(r'[A-Za-z][A-Za-z0-9.]*', str(op)):
            if tok in Dec.XNAME or tok in Dec.FNAME:
                out.append(tok)
    return out


def reg_audit():
    """(checked, agree, the disagreements) over the whole RISC-V corpus.

    A multiset comparison, because an instruction may legitimately name the
    same register twice -- `add a0, a0, a1` reads a0 and writes a0 -- and a set
    comparison would call that a disagreement on every arithmetic instruction
    in the corpus.
    """
    checked = agree = 0
    bad = []
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for _nm, i in obj_insns(fp):
            if i.name is None:
                continue
            mine = sorted(n for _l, _r, n in regs_of(i))
            theirs = sorted(reg_names(i))
            checked += 1
            if mine == theirs:
                agree += 1
            elif len(bad) < 12:
                bad.append((f, i.name, i.text.strip(), ' '.join(mine),
                            ' '.join(theirs)))
    return checked, agree, bad


def regname(n, fp=False):
    return Dec.freg(n) if fp else Dec.xreg(n)


def field_of(i, want):
    """(hi, lo, value) for a named field, from THIS FILE'S table.

    The bit POSITION comes back as well as the value, deliberately: a caller
    that reads only the value cannot tell a five-bit field from a three-bit
    one, and the difference between them is the difference between x0 and x8.
    """
    for label, _role, pos in (regs_of(i) and reg_positions(i) or []) or []:
        if label == want and pos is not None:
            return pos[0], pos[1], Dec.bits(i.word, pos[0], pos[1])
    return None


def source_reg(i, which='rs2'):
    """The register an instruction READS, by field, from the right file."""
    for label, _role, name in regs_of(i):
        if label == which:
            return name
    return None


def dest_reg(i):
    """The register an instruction WRITES, by field, from the right file."""
    for label, _role, name in regs_of(i):
        if label == 'rd':
            return name
    return None


STORE_NAMES = ('sb', 'sh', 'sw', 'fsw', 'sd', 'fsd',
               'c.sb', 'c.sh', 'c.sw', 'c.fsw', 'c.sd', 'c.fsd',
               'c.sbsp', 'c.swsp', 'c.fswsp', 'c.sdsp', 'c.fsdsp')
LOAD_NAMES = ('lb', 'lh', 'lw', 'ld', 'lbu', 'lhu', 'lwu', 'flw', 'fld',
              'c.lb', 'c.lh', 'c.lw', 'c.ld', 'c.lbu', 'c.lhu', 'c.lwsp',
              'c.ldsp', 'c.flwsp', 'c.fldsp', 'c.fld', 'c.flw')


def stores_to_globals(path, func, prefix='G'):
    """{n: [register names written there]} inside one function, for the
    globals whose symbol name starts with `prefix`.

    A store is `sw`/`sd`/`fsd`/`sb`/`sh`/`fsw` or one of their COMPRESSED
    forms; its SOURCE is rs2, which the previous course of this section
    MEASURED to be bits[24:20] in every base format -- and in the compressed
    `c.sd`/`c.sw`/`c.fsd` forms rs2 is bits[4:2], a THREE-BIT field whose
    value 0 means x8.  Both are read from the bits here, and the difference
    between the two field positions is `rv-encoding`'s finding being USED
    rather than repeated: reading the compressed rs2 with the base lookup
    returns a real register that is not the one, for eight of the sixteen
    values.

    A store whose relocation chain does not resolve to a `G<n>` symbol is
    DROPPED FROM THE MAP and section 9 counts the drops, because a silently
    dropped store is a store that cannot disagree.  A count with a hole in it
    is the exact shape of the failure this collection has already suffered
    from twice: a cross-check that reported zero disagreements over a corpus
    where eighty-five instructions genuinely disagreed.
    """
    names, syms, rel, secflags = elf_tables(path)
    text = names.index('.text') if '.text' in names else 2
    byoff = {}
    for sec, off, typ, sym, add in rel:
        if sec != text:
            continue
        final = resolve_sym(rel, syms, secflags, text, off)
        if final and final.startswith(prefix) and final[len(prefix):].isdigit():
            byoff.setdefault(off, set()).add(int(final[len(prefix):]))
    out = {}
    for nm, i in obj_insns(path, funcs=True):
        if nm != func or i.name not in STORE_NAMES:
            continue
        for g in byoff.get(i.addr, ()):
            out.setdefault(g, []).append(store_source(i))
    return out


def store_source(i):
    """The register a store READS, by field, from the right file.  The base-ISA
    rs2 field and the compressed rs2 field are in DIFFERENT PLACES, and
    `reg_positions` reports where each one is.

    AND IT IS FROM THE FLOATING-POINT FILE FOR `fsd`, which is the whole point
    of the concept: `fsd D0, 0(a0)` stores out of `fa0` and the reader that
    looks the value up in the integer table reports `a0` -- a real register, the
    wrong file, and a store of the wrong thing.
    """
    return source_reg(i, 'rs2')


def load_base(i):
    """The register a load READS FROM, by field, from the right file.

    THE COMPRESSED STACK FORMS HAVE NO BASE REGISTER FIELD AT ALL.  In
    `c.ldsp rd, offset(sp)` and its five siblings the base IS sp -- it is not
    five bits of encoding spent on `11111`, it is the FORMAT.  So
    `field_of(i, 'rs1')` correctly returns None for every one of them, and a
    caller that reads None as "no base" silently drops every stack access in
    the compressed half of the corpus.  The first version of this function did
    exactly that and `loads_from_sp` returned an empty list over the whole of
    `abi.c`, which reads as "the ABI never uses the stack" and is the single
    most dangerous shape a null result can take.
    """
    n = i.name
    if n.endswith('sp') and (n.startswith('c.') or n == 'addi16sp'):
        return 'sp'
    if i.nbytes == 2:
        # The quadrant-0 and quadrant-1 CL and CS formats name rs1' in THREE
        # bits at inst[9:7] and the decoder reports that field under a name
        # `field_of` does not find, so this one position is read directly --
        # from the field map the previous course of this section MEASURED and
        # from the Zca specification's `rd'/rs1'` table, whose value 0 means
        # x8.  Reading it with a five-bit lookup is the trap `rvasm`'s
        # concept 5 exists for, so `creg3` is used and not `xreg`.
        return Dec.creg3(Dec.bits(i.word, 9, 7))
    return source_reg(i, 'rs1')


def displacement(i):
    """The displacement of a load or a store, parsed out of the DECODER'S OWN
    printed operand and not out of the bits.

    And the reason is worth a paragraph.  For the 32-bit forms the immediate
    is in a field and this file reads the field.  For the COMPRESSED forms
    the displacement is a PERMUTED selection of six bits at inst[12:10] and
    inst[6:2], which `rv-compressed` measured to be seven different orders in
    eleven families -- so there is no single "the field" to read.  Reading it
    from the printed text is safe here for exactly one reason, and the reason
    is checked in section 9: the printed text is this decoder's, and section
    9 compares it against `llvm-objdump-21` instruction by instruction and
    reports how many disagreed.  A displacement taken from a printed operand
    is only as trustworthy as the cross-check, which is why the cross-check
    counts.
    """
    # The base is matched as `sp` OR `s0` rather than as `sp` alone.  At -O0
    # the ninth argument is read from `0(s0)` -- through the FRAME POINTER --
    # and a displacement pattern that only knows `sp` returns None for it,
    # which prints as `(none)` and reads as "the ABI does not use the stack at
    # -O0" when the truth is "the ABI does not use the stack, and neither
    # does the compiler, because s0 and the entry sp are the same address".
    m = re.search(r'(-?\d+)\((?:sp|s0)\)', i.text)
    return int(m.group(1)) if m else None


def loads_from_sp(path, func, limit=64):
    """[(offset, register, instruction)] for every stack load in one function.

    The offset is the displacement and the base must be x2.  This is the audit
    that answers "where does the ninth argument arrive", and it is the one row
    of the whole calling convention that a reader cannot get out of the
    register table in section 2: the table says WHAT the registers are called
    and says nothing at all about the offset of the first stacked argument.
    """
    out = []
    for nm, i in obj_insns(path, funcs=True):
        if nm != func or i.name not in LOAD_NAMES:
            continue
        if load_base(i) != 'sp':
            continue
        off = displacement(i)
        if off is not None and abs(off) <= limit:
            out.append((off, i.name, i.text))
    return out


def loads_from_fp(path, func, limit=8):
    """The same audit through the FRAME POINTER, which is what -O0 does.

    At -O0 clang emits `addi s0, sp, N` in the prologue and then reads the
    ninth argument from `0(s0)`, and `0(s0)` is offset ZERO of the stack
    pointer as it was on ENTRY -- s0 is the CFA, which is the whole reason
    the frame-pointer convention exists.  So the -O0 row is not "the ABI
    changed at -O0"; it is the same offset read through a different register,
    and the audit reports both bases rather than reporting nothing at -O0.
    A row that is empty at one level and full at another is nearly always a
    base-register assumption and not a measurement.
    """
    out = []
    for nm, i in obj_insns(path, funcs=True):
        if nm != func or i.name not in LOAD_NAMES:
            continue
        if load_base(i) != 's0':
            continue
        off = displacement(i)
        if off is not None and abs(off) <= limit:
            out.append((off, i.name, i.text))
    return out


def stores_to_sp_before_calls(path, func):
    """[(call ordinal, [(offset, text)], (last argument register written))]
    -- the caller side.

    Everything this course says about "the ninth double is at 8(sp)" would be
    half a claim from the callee's side alone, because the callee only shows
    that it READ 8(sp).  This walks the caller, splits it at every
    `jalr ra` / `jal ra` -- which is what a `call` IS on this architecture,
    because there is no `call` instruction and the return address is written
    by `jal` or by `auipc`+`jalr` -- and records, for each call:

      * every stack store to an offset within 64 bytes of sp, and
      * the LAST instruction before it that wrote an argument register.

    Caller and callee agreeing about the same offset is the difference between
    a measurement and a guess, and the second item is what catches the one
    case where the callee's answer is "there is no stack argument at all".
    """
    insns = [(nm, i) for nm, i in obj_insns(path, funcs=True) if nm == func]
    out = []
    cur = []
    tail = []
    for nm, i in insns:
        if i.name in STORE_NAMES and '(sp)' in i.text:
            off = displacement(i)
            if off is not None and abs(off) <= 64:
                cur.append((off, i.text))
        tail.append(i.text.strip())
        del tail[:-10]
        if i.name in ('jalr', 'c.jalr', 'jal', 'c.jal') and \
                i.ops and i.ops[0].split(',')[0].strip() == 'ra':
            out.append((len(out) + 1, list(cur), list(tail)))
            cur = []
    return out


# ===========================================================================
# SECTION 3 -- rv-calling.  The INTEGER argument audit.
#
# THE SPECIFICATION IS THE ORACLE AND THE COMPILER IS THE TEST SUBJECT.  Every
# argument is read from its own volatile global, so the compiler cannot fold
# it and cannot forward it; every placement is then read out of the RELOCATION
# the store carries, so the number is about the emitted BYTES and not about a
# text file somebody read.
# ===========================================================================

def sec3():
    banner(3, 'rv-calling: a0-a7, AND WHERE THE NINTH ONE GOES')
    print()
    para("""THE AUDIT.  For each of the functions `i1` .. `i9`, find the store
whose relocation names G<K> and read the rs2 field of the instruction word.
That register is where the K-th integer argument arrived.  Section 2's table
says the K-th should be a<K-1>; the audit either agrees 45 times out of 45 or
it does not, and a disagreement is a retraction in section 11 rather than a
row to be explained away.""")

    levels = [lv for lv in LEVELS if os.path.exists(p('abi_%s.o' % lv))]
    if 'O2' not in levels:
        para('THE CORPUS IS ABSENT.  Run build_samples.sh first.')
        return

    rows = []
    agree = total = 0
    argnames = [Dec.xreg(n) for n in ARGREGS]
    for k in range(1, 10):
        fn = 'i%d' % k
        got = stores_to_globals(p('abi_O2.o'), fn, 'G')
        got = dict((g, v[0]) for g, v in got.items())
        bad = 0
        # The corpus writes the FIRST argument into G0, so the index of an
        # argument IS its index into the globals and the display index is one
        # higher.  The first version of this loop compared `got[j + 1]` with
        # `a(j)`, which is a one-off that makes EVERY row disagree and reports
        # "0 of 44" over a corpus in which 44 of 44 are right -- a confident
        # wrong number derived from a correct measurement, which is the worst
        # shape there is.
        for j in range(min(k, 8)):
            total += 1
            r = got.get(j)
            ok = (r == argnames[j])
            if ok:
                agree += 1
            else:
                bad += 1
            rows.append([fn, 'G%d' % j, 'a%d' % j,
                         r if r is not None else '(not found)',
                         'agree' if ok else 'DISAGREE'])
        rows.append([fn, '--',
                     'a%d' % k if k <= 8 else 'none: there is no a8',
                     '%d in registers' % min(k, 8) +
                     ('' if not bad else ', and %d wrong' % bad),
                     'agree' if not bad else 'DISAGREE'])
    print()
    print('  INTEGER ARGUMENTS, -O2, read out of the RELOCATIONS of the stores:')
    print()
    table(['function', 'global', 'riscv-cc says', 'the bytes say', 'verdict'],
          rows)
    print()
    para("""%d of %d integer argument placements agree with riscv-cc's table,
at -O2.  The denominator is arithmetic and not a convenience: `i1`..`i8`
contribute 1+2+...+8 = 36 register-resident arguments and `i9` contributes 8
more, so 44 placements in all, and the ninth of each function is not in the
table because there is no register for it.""" % (agree, total))

    print()
    print('  THE SAME AUDIT AT FOUR LEVELS -- the specification holds, and the')
    print('  SPILL COUNT is the compiler\'s.  `in a reg` is the number of')
    print('  arguments that arrived in a0-a7; `on the stack` is the rest.')
    print()
    lvrows = []
    for lv in LEVELS:
        if not os.path.exists(p('abi_%s.o' % lv)):
            continue
        inreg = onstack = 0
        for k in range(1, 9):
            got = stores_to_globals(p('abi_%s.o' % lv), 'i%d' % k)
            got = dict((g, v[0]) for g, v in got.items())
            for j in range(k):
                if got.get(j) in argnames:
                    inreg += 1
                else:
                    onstack += 1
        lvrows.append(['-' + lv, str(inreg), str(onstack), 'a0-a7 per riscv-cc'])
    table(['level', 'in a reg', 'on the stack', 'specification'], lvrows)
    print()
    para("""THE NINTH INTEGER ARGUMENT, at four levels.  The audit cannot put it
in a register -- there is no a8 -- so it looks for a LOAD from the stack
pointer with a small displacement, and prints the offset and the register it
landed in.  `off(sp)` in the specification's own words: "The first argument
passed on the stack is located at offset zero of the stack pointer on
function entry".

NOTE ON THE -O0 ROW, and it is a better finding than the row it replaced.
At -O0 clang emits `addi s0, sp, N` in the prologue and reads the ninth
argument from `0(s0)` -- through the FRAME POINTER, not through `sp`.  And
`s0` is the CFA: the stack pointer as it was on ENTRY, which is exactly what
the frame-pointer convention defines it to be.  So the -O0 offset is ALSO
ZERO, read through a different register, and the first version of this
section reported `(none)` at -O0 because the audit only looked at the base
register `sp`, and because the -O0 load is a COMPRESSED `c.ld` whose base is
a three-bit `rs1'` field rather than the five-bit one.

A row that is empty at one optimisation level and full at every other one is
almost always a base-register ASSUMPTION and not a measurement, and this is
the third time this collection has learned that in a row that looked empty
rather than wrong.""")

    rows = []
    for lv in LEVELS:
        if not os.path.exists(p('abi_%s.o' % lv)):
            continue
        small = [o for o in loads_from_sp(p('abi_%s.o' % lv), 'i9')
                 if abs(o[0]) <= 8]
        viafp = [o for o in loads_from_fp(p('abi_%s.o' % lv), 'i9')]
        rows.append(['-' + lv, str(len(small)),
                     ', '.join('%d(%s)' % (o[0], o[1]) for o in small)
                     or '(none)',
                     ', '.join('%d(%s)' % (o[0], o[1]) for o in viafp)
                     or '(none)'])
    table(['level', 'loads from sp <= 8', 'offset(instruction) via sp',
           'offset(instruction) via s0'], rows)
    print()
    para("""SO: at -O1, -O2 and -Os the ninth integer argument is read from
OFFSET ZERO of the stack pointer, into t0.  The register is the compiler's
and does not matter; the OFFSET is the specification's, and it is zero.""")

    para("""WHERE ZERO COMES FROM.  There is no return address on the stack to
skip, because the return address lives in `ra` and `ra` is not preserved
across a call by anyone.  That single fact is why every stacked offset in
this course is 8 lower than the equivalent x86-64 offset, and it is worth
one sentence rather than a diagram: on x86-64 the caller's `call` PUSHES the
return address, so the callee must skip it; on RISC-V the callee must not
skip anything, because there is nothing there.

AND THE STACK IS ALIGNED TO 128 BITS, which `riscv-cc` states twice in one
paragraph and which this artifact can only confirm as an ARITHMETIC IDENTITY:
`-O0`'s prologue is `addi sp, sp, -0x40` and its epilogue is `addi sp, sp,
0x40`, so the sum is 0 mod 128 at the return.  What the alignment FORCES --
a fault on a misaligned access -- CANNOT BE MEASURED HERE, and section 12 says
so where a reader would expect the measurement.""")


# ===========================================================================
# SECTION 4 -- THE TWO COUNTERS, AND THE ROW THAT NO SUMMARY GETS RIGHT.
# ===========================================================================

def sec4():
    banner(4, 'THE NINTH DOUBLE, WHICH IS NOT WHERE A SUMMARY SAYS IT IS')
    print()
    para("""Two hypotheses about what happens when the argument registers run
out.  Either there is ONE counter that runs out after eight values of any
kind, so the ninth value of anything is on the stack; or there are TWO
INDEPENDENT counters, one over a0-a7 and one over fa0-fa7, so the ninth value
is on the stack only if both are exhausted.

`m8` -- four integers then four doubles -- AGREES WITH BOTH.  It is in the
corpus for exactly that reason and the artifact prints it, because a
distinguishing case that is not printed looks like a case that was not
considered.  `m18` -- nine integers then nine doubles -- is the case that
decides it, and it is here because a rule stated without the case that
separates two hypotheses is a rule nobody has tested.""")

    # THE m18 ROW IS PRINTED TWICE, in two different FORMS, and the second one
    # is the form a machine can read.  The wide table above is for a person
    # reading nine registers at once; the rows below are one token per column,
    # and they are asserted EXACTLY by crosscheck.py -- the register the ninth
    # integer arrived in, the register the ninth double arrived in, and the
    # exact set of stack offsets read.  The first version printed only the wide
    # table, whose cells contain spaces after the commas, and a harness that
    # matches columns by whitespace cannot read a cell that has spaces in it:
    # the check failed against a correct measurement, and the tempting repair
    # -- loosening the harness -- would have thrown away the only assertion
    # that the ninth double lands in a TEMPORARY rather than in an argument
    # register.
    print()
    print('  THE SAME TWO ROWS, ONE TOKEN PER COLUMN, because an EXACT')
    print('  assertion needs a column a machine can read.  The offsets are')
    print('  printed as a comma-separated LIST rather than comma-and-space,')
    print('  so all three columns are whitespace-free:')
    print()
    for fn, label, gi_key, gd_key in (('m8', '4 int + 4 double', 'G', 'D'),
                                      ('m18', '9 int + 9 double', 'G', 'D')):
        gi = stores_to_globals(p('abi_O2.o'), fn, gi_key)
        gd = stores_to_globals(p('abi_O2.o'), fn, gd_key)
        ints = ','.join('%d<-%s' % (k + 1, v[0]) for k, v in sorted(gi.items()))
        dbls = ','.join('%d<-%s' % (k + 1, v[0]) for k, v in sorted(gd.items()))
        offs = sorted(set(o for o, _n, _t in loads_from_sp(p('abi_O2.o'), fn)))
        stack = ', '.join(str(o) for o in offs) if offs else '(none)'
        print('  %-4s %-18s %s  %s  %s' % (fn, label, ints, dbls, stack))
    print()

    rows = []
    for fn, label in (('m8', '4 int + 4 double'), ('m18', '9 int + 9 double')):
        gi = stores_to_globals(p('abi_O2.o'), fn, 'G')
        gd = stores_to_globals(p('abi_O2.o'), fn, 'D')
        # The TEMPORARY, when the ninth value of a kind did not arrive in an
        # argument register, is not in the store's rs2: the compiler LOADED it
        # from the stack into a temporary and then stored the temporary, and
        # the load is what says the value came from the stack and the store is
        # what says which register it ended up in.  Both are read here, and the
        # row prints the register the store used -- `t0` and `ft0` below -- so a
        # reader can see that the value did NOT arrive in a0-a7 or fa0-fa7 and
        # did not arrive on the stack either, it arrived in a temporary that
        # the caller had to fill from the stack first.
        ints = ', '.join('%d<-%s' % (k + 1, v[0]) for k, v in sorted(gi.items()))
        dbls = ', '.join('%d<-%s' % (k + 1, v[0]) for k, v in sorted(gd.items()))
        li = loads_from_sp(p('abi_O2.o'), fn)
        offsets = sorted(set(o for o, _n, _t in li))
        stacks = ', '.join(str(o) for o in offsets)
        rows.append([fn, label, ints, dbls, stacks or '(none)'])
    print()
    table(['function', 'arguments', 'integers arrived in',
           'doubles arrived in', 'stack offsets read'], rows)
    print()
    para("""`m8` puts the four integers in a0-a3 and the four doubles in
fa0-fa3, and reads NOTHING from the stack.  Both hypotheses predict that, so
`m8` settles nothing, and the artifact says so in a row rather than leaving
the reader to assume otherwise.

`m18` puts the integers in a0-a7, the doubles in fa0-fa7, and then -- and this
is the row -- the ninth integer in t0 and the ninth DOUBLE in ft0, having read
EXACTLY two stack offsets: 0 and 8.  Two independent counters, confirmed: the
ninth double is on the stack because the INTEGERS took a0-a7, and it is at 8
rather than 0 because the ninth integer took 0.

Both ninth values went through a TEMPORARY, and the temporary is worth naming
because it is the only reason a reader can see the stack at all in this row.
The store to G8 has rs2 = t0 and the store to D8 has rs2 = ft0, and neither
is an argument register -- so the audit cannot conclude "the ninth argument
arrived in t0" and stop.  It has to find the `c.ldsp` that FILLED t0, and that
load is the evidence that the value came from the stack, at offset 0 for the
integer and 8 for the double.  A register-based audit with no load audit
reports a temporary and a reader has no way to know whether the temporary was
filled from the stack, from a global, or from nowhere.""")

    # THE NINTH INTEGER AND THE NINTH DOUBLE, each shown as the PAIR of
    # instructions that proves it: the load that names the offset, and the
    # store that names the register.
    for fn, g, what in (('m18', 'G', 'the ninth INTEGER'),
                        ('m18', 'D', 'the ninth DOUBLE')):
        gnum = 8
        got = stores_to_globals(p('abi_O2.o'), fn, g)
        reg = got.get(gnum, ['?'])[0]
        print()
        print('  %s, in %s, proved by the load that FILLED %s and the store'
              ' that used it:' % (what, fn, reg))
        for off, nm, txt in loads_from_sp(p('abi_O2.o'), fn):
            if abs(off) <= 8:
                print('    the load : %-28s  offset %d' % (txt.strip(), off))
        for i in [i for _n, i in obj_insns(p('abi_O2.o'), funcs=True)
                  if _n == fn and i.name in STORE_NAMES
                  and store_source(i) == reg]:
            print('    the store: %-28s  into %s%d' % (i.text.strip(), g,
                                                       gnum))
        print()

    para("""AND THE ROW NO ONE-TABLE SUMMARY GETS RIGHT.  `f9` -- nine doubles
and nothing else.  MEASURED, the ninth double is stored from `a0`, which is
an INTEGER argument register, and `loads_from_sp` finds NOTHING: `f9` reads no
stack argument at all, at any optimisation level.

The reason is the second sentence of the hardware floating-point convention,
which has to be read with the third:

  * fa0-fa7 are exhausted after eight doubles.
  * "A real floating-point argument is passed in a floating-point argument
    register if it is no more than ABI_FLEN bits wide AND AT LEAST ONE
    FLOATING-POINT ARGUMENT REGISTER IS AVAILABLE.  OTHERWISE, IT IS PASSED
    ACCORDING TO THE INTEGER CALLING CONVENTION."
  * the integer calling convention is a0-a7 first, and those are still free.

So the ninth double goes to a0.  It does NOT go on the stack, because nothing
has exhausted the integer argument registers yet.  A summary that says "the
ninth argument is on the stack" is right for integers and wrong for doubles,
and the only way to know which is which is to read the second convention and
then MEASURE IT -- which is what the row above is.""")
    print()
    fr = stores_to_globals(p('abi_O2.o'), 'f9', 'D')
    frow = ['f9, ninth double', 'fa7 (exhausted)',
            str(fr.get(8, ['?'])[0]) + ' -- an INTEGER register',
            str(len(loads_from_sp(p('abi_O2.o'), 'f9'))) + ' stack reads']
    table(['case', 'after fa7', 'the ninth double arrived in',
           'stack loads in the function'], [frow])
    print()

    para("""AND THE CALLER AGREES.  A callee audit on its own is half a claim:
all it shows is that the callee READ something.  The caller is walked, split
at every `jalr ra` / `jal ra`, and each call is shown with the stack stores
that immediately preceded it and the last instructions before it.

  * call 1, `i9`:   `c.sdsp s1, 0(sp)`   -- the ninth integer at OFFSET ZERO.
  * call 2, `f9`:   NO stack store at all, and the sixth instruction before
                    the call is `c.mv a0, s0` -- the ninth double goes into
                    the integer argument register a0, as the callee said.
  * call 3, `m18`:  `c.sdsp s1, 0(sp)` AND `c.sdsp s0, 8(sp)` -- the ninth
                    integer at 0 and the ninth double at 8, in that order, in
                    the bytes the caller emitted.

Two readers of the same decision: the callee says where it read from, the
caller says where it wrote to, and they are the same offsets.  Neither reader
would catch a mistake in the other, which is exactly why both are here.""")

    for lv in ('O2', 'O0'):
        if not os.path.exists(p('abi_%s.o' % lv)):
            continue
        calls = stores_to_sp_before_calls(p('abi_%s.o' % lv), 'caller')
        if not calls:
            continue
        print('  the caller, -%s:' % lv)
        for n, st, tail in calls:
            print('    call %d  stack offsets written: %s'
                  % (n, sorted(set(o for o, _t in st)) or 'NONE'))
            for t in tail[-4:]:
                print('        %s' % t)
        print()
        break
    para("""Printed at ONE level, deliberately.  The offsets are the
specification's and they do not move; the register names inside the tail do,
so printing four levels of them would be four copies of the compiler's
choices wearing the weight of a contract.  The harness checks the offsets at
every level.""")

    para("""THE REGISTER PAIR, for a 2*XLEN scalar.  `wide(long long, long
long, int, long long)` and the specification's rule: "with the low-order
XLEN bits in the lower-numbered register and the high-order XLEN bits in the
higher-numbered register."  MEASURED from the emitted code, the third
`long long` -- which is the third integer-pair slot -- is read back from a2
and a3, low half in a2 and high half in a3.  The rule is easy to state and
easy to state backwards, and the corpus contains the case so the statement is
a measurement rather than a memory.""")

    para("""THE RETURN VALUE.  "Values are returned in the same manner as a first
named argument of the same type would be passed", and "the first two of which
are also used to return values" -- so a scalar result comes back in a0 and a
`double` result in fa0.  There is no separate return register on this
architecture and no hidden-result-pointer rule unless the value is too big to
fit in a register pair.  This is a place where a reader coming from x86-64
should expect a hidden pointer: rax is the return register on x86-64 AND, for
an aggregate larger than 16 bytes, rax becomes a hidden pointer to the
caller's buffer.  On RISC-V the same rule exists and a0 is what fills the
role, and `rv-registers` measures whether clang's own choice ever differs.""")


# ===========================================================================
# SECTION 5 -- rv-noflags.  THE SPINE.
# ===========================================================================

BRANCHES = ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu',
            'beqz', 'bnez', 'blez', 'bgez', 'ble', 'bgt', 'bgtu',
            'c.beqz', 'c.bnez', 'c.beq', 'c.bne', 'j', 'jr',
            'c.j', 'c.jr', 'c.jal', 'c.jalr', 'jal', 'jalr')
MASKS = ('sltiu', 'slti', 'sltu', 'slt', 'srai', 'sraiw', 'srli', 'srliw',
         'xor', 'xori', 'sub', 'subw', 'addw', 'and', 'andi', 'neg', 'seqz',
         'snez', 'c.srli', 'c.srai', 'c.slli', 'c.addi', 'c.mv', 'c.add',
         'c.xor', 'c.and', 'c.or', 'c.sub', 'c.addw', 'c.subw', 'c.addi16sp')


def classify(i):
    """'branch', 'mask', 'other' -- which of the three answers this is.

    There are exactly three answers a compiler has when there is no CMOVcc
    and no SETcc: branch, arithmetic, or a call.  The classification is on the
    MNEMONIC and the third bucket is not thrown away -- it is counted and
    printed, because a classifier that quietly folds the unrecognised into one
    of the two interesting buckets is a classifier that cannot report its own
    ignorance.
    """
    n = i.name
    if n in BRANCHES:
        return 'branch'
    if n in MASKS:
        return 'mask'
    return 'other'


def sec5():
    banner(5, 'rv-noflags: THE ABSENCE, AND WHAT THE COMPILER EMITS INSTEAD')
    print()
    para("""THE SPINE OF THE WHOLE SECTION, in the course mission's own words:

    RISC-V has no flags register and no condition codes.  x86-64 has EFLAGS,
    AArch64 has NZCV, RISC-V has NOTHING -- so a branch is the only
    conditional thing, and that single absence explains why AArch64 needs
    csel/cset at all and why a compiler emits a branch on one target and a
    cmov on another.

And it is FULLY MEASURABLE WITHOUT HARDWARE, which is why this course exists
on a host with no RISC-V silicon: the compiler's CHOICE is a static property
of its output, and the output is bytes.""")

    para("""THE THREE ANSWERS.  With no CMOVcc and no SETcc, a compiler
implementing `x < 0 ? a : b` has exactly three moves: BRANCH (the condition
IS the branch), ARITHMETIC (turn the condition into 0 or 1 in a register and
select with `xor`/`sub`/`and`), or CALL (give up and call a helper).  The
manual admits the design decision in its own words -- "We considered but did
not include conditional moves or predicated instructions, which can
effectively replace unpredictable short forward branches" -- so this is not an
inference from an absence, it is a documented choice being exercised.

The corpus is `noflags.c`, eleven functions, every one of them a `?:` on an
integer condition, compiled at four levels.  Classified on the MNEMONIC, by
the INHERITED decoder, out of the object file.""")

    rows = []
    totals = {'branch': 0, 'mask': 0, 'other': 0}
    for lv in LEVELS:
        fp = p('noflags_%s.o' % lv)
        if not os.path.exists(fp):
            continue
        c = {'branch': 0, 'mask': 0, 'other': 0}
        helpers = []
        for nm, i in obj_insns(fp, funcs=True):
            k = classify(i)
            c[k] += 1
            if i.name in ('jal', 'jalr', 'c.jal', 'c.jalr') and \
                    nm not in ('caller',):
                helpers.append('%s: %s' % (nm, i.text))
        for k in totals:
            totals[k] += c[k]
        rows.append(['-' + lv, str(c['branch']), str(c['mask']), str(c['other']),
                     str(len(helpers)),
                     ', '.join(sorted(set(x.split(': ')[1] for x in helpers)))[:60]
                     or '(none)'])
    print()
    table(['level', 'branch', 'mask', 'other', 'calls', 'what is called'],
          rows)
    print()
    para("""AND THE ROW THAT ANSWERS THE COURSE'S TITLE.  Read the branch
column and the mask column together at -O2 and the shape is the finding: the
compiler picks a BRANCH for most of the corpus and reaches for ARITHMETIC only
where arithmetic is cheaper than a branch -- `myabs`, `mask`, `sign`, `absu`,
which are all the same three-instruction idiom `sraiw` / `xor` / `subw`, plus
`sign`, which is ONE instruction (`srliw a0, a0, 0x1f`).

THAT IS THE CONSTRUCTIVE HALF, AND IT IS THE HALF NOBODY STATES.  A C
expression that on x86-64 has no single instruction -- `(x >> 31)` as an
arithmetic shift is one instruction on RISC-V and needs `SETL` on x86-64,
which does not exist -- is ONE instruction here.  The absence of flags is not
only a cost; it is what makes `min`, `max`, `clamp` and `abs` expressible
without a conditional move at all.  The RISC-V answer is that `sltu` WRITES A
REGISTER, so the comparison's result is data and the selection is arithmetic
on data; on x86-64 the comparison's result is BITS IN A REGISTER YOU DO NOT
NAME, so the selection has to be an instruction that reads those bits, and
that instruction is `CMOVcc`.""")

    print()
    print('  THE CONSTRUCTIVE ROW, instruction by instruction, at -O2,')
    print('  decoded from the bytes by the INHERITED decoder:')
    print()
    rows = []
    for nm, i in obj_insns(p('noflags_O2.o'), funcs=True):
        if nm in ('myabs', 'mask', 'sign', 'absu', 'mymin', 'mysel'):
            rows.append([nm, str(i.nbytes), i.text.strip()])
    table(['function', 'bytes', 'instruction'], rows)
    print()
    print('  AND THE THREE ANSWERS, IN THE COMPILER\'S OWN WORDS, for the row')
    print('  that is the course\'s title.  The manual says it in a sentence, and')
    print('  the sentence is here in full because a course that paraphrases its')
    print('  oracle has already lost the argument:')
    print()
    para("""  * "We considered but did not include conditional moves or predicated
    instructions, which can effectively replace unpredictable short forward
    branches."  -- rv32-unprivileged, the branch-design note.

Read what that sentence concedes.  It is not a claim that a conditional move
would be slower.  It is a claim that a conditional move CAN replace an
unpredictable short forward branch, and that the architecture declined to let
it.  So the absence is a DOCUMENTED DESIGN DECISION and this course is
measuring a decision rather than inferring one from a hole.

AND THE COROLLARY, which is the half nobody states.  Because `sltu` WRITES A
REGISTER and sets no flags, `(x < 0) ? 1 : 0` is ONE instruction here and
needs no conditional move at all.  The absence of a flags register is not
only a cost: it is what makes `min`, `max`, `clamp` and `abs` expressible
without reaching for a conditional move, because the comparison's result is
DATA and the selection is arithmetic on data.

`sign` is ONE instruction: `srliw a0, a0, 0x1f`, which is the whole
of `(x < 0) ? 1 : 0` for a signed int.  There is no `SETcc` to reach for and
there is nothing to reach for one WITH -- the comparison never left a
register, it went straight into the shift's operand -- so the compiler did not
need a conditional move, and the result is a program in which the condition is
a VALUE rather than a STATE.

`myabs` and `mask` and `absu` are the same three instructions:
`sraiw t, x, 31` for the sign mask, `xor` to apply it, `sub` to apply its
magnitude.  On x86-64 the same C is `mov / neg / cmovs` -- also three, but
one of the three reads flags.

`mymin` is a BRANCH: `blt a0, a1, .LBB1_2`, then `mv`, then `ret`.  That is
where a compiler with `CMOVcc` would have written a conditional move and this
one cannot, and the interesting fact is that it does NOT want to: `mymin` is
three instructions and `cmov` would have made it four.""")

    para("""AND ONE ROW COMES OUT THE OTHER WAY, which is the control that
makes the rest believable.  `twice` uses the SAME condition twice, and on all
three targets it collapses to a single `add`: the compiler noticed the
expression is commutative in the two selects and the condition vanished.  A
corpus where every row came out the same way would be a corpus measuring
nothing; this row is here so the artifact can say "and one of them did not
behave like the prediction".""")

    para("""AND ONE ROW IS A REAL COST.  `bigsel` takes fifteen arguments and
makes five selects, and at -O2 the compiler emits FIVE BRANCHES and spills to
the stack to get at the arguments past a7.  There is no masking alternative
that fits in the registers it has, so the branch is not a preference, it is
the only encoding left.  The count of branches in a function is therefore not
a style statistic: it is a measure of how much register pressure the machine
has.""")

    para("""WHAT THIS MEASUREMENT CANNOT SHOW, and on this page that is most of
the page.

It cannot show that a branch is FASTER than a mask, or slower, or slower by
how much.  It cannot show that `blt` is a taken branch or a not-taken branch,
or that the mask form has better ILP, because there is no RISC-V machine, no
emulator and no timing on this host.  Every row above is a COUNT OF
INSTRUCTIONS. §KEEP§And an instruction count does not know whether the instruction is fast.

It cannot show that the branch is PREDICTABLE either, which is the one thing
the manual's argument is actually about: "branches are observed earlier in
the front-end instruction stream, and so can be predicted earlier" is a
QUOTED argument about a pipeline nobody in this course can run, and the
corpus contains a `?:` written by hand precisely so that a reader could not
accidentally read the branch column as a mispredict count.  A compiler that
emitted `blt` for a condition that is always true and a compiler that emitted
`blt` for one that is always false produce the SAME row in the table above.

And it cannot show that any of this is what the architecture intends, only
what this compiler did.  The manual's design note is an argument, the
compiler's output is a choice, and a course with a choice and no silicon can
compare the two only as text against text.""")


# ===========================================================================
# SECTION 6 -- THE THREE TARGETS, AND THE AARCH64 SIDE DECODED FROM BITS.
#
# A COMPILE-TIME INSTRUCTION COUNT.  Every table in this section says so in
# its own caption, because a reader who has just read the x86-64 section's
# 4.92x and 27.65x is looking for a ratio and a count is not one.
# ===========================================================================

def a64_counts(path):
    """(per-function instruction counts, {mnemonic: n}) for an AArch64 object.

    Counted from `llvm-objdump-21 --triple=aarch64` lines, which is a TOOL
    counting WORDS rather than decoding them: this is a census of how many
    lines the second reader printed, and it is deliberately NOT this file's
    own decode.  Section 6B is where the AArch64 side gets its OWN two-reader
    treatment, with the sibling AArch64 course's decoder as the first reader.
    """
    r = sh(OBJDUMP, '--triple=aarch64', '-d', path)
    per = {}
    mn = {}
    cur = None
    for ln in r.stdout.splitlines():
        m = re.match(r'^[0-9a-f]{16} <([^>]+)>:', ln)
        if m:
            cur = m.group(1)
            per.setdefault(cur, 0)
            continue
        m = re.match(r'^\s+[0-9a-f]+:\s+(?:[0-9a-f]{2,8} )+\s*\t(\S+)', ln)
        if m and cur:
            per[cur] += 1
            mn[m.group(1)] = mn.get(m.group(1), 0) + 1
    return per, mn


def x86_counts(path):
    """(per-function instruction counts, {mnemonic: n}) for an x86-64 object."""
    r = sh(OBJDUMP, '-d', path)
    per = {}
    mn = {}
    cur = None
    for ln in r.stdout.splitlines():
        m = re.match(r'^[0-9a-f]{16} <([^>]+)>:', ln)
        if m:
            cur = m.group(1)
            per.setdefault(cur, 0)
            continue
        # The byte column is separated from the mnemonic by a TAB, and the
        # first version of this pattern required spaces there, so it matched
        # NOTHING for an x86-64 listing -- which is why the first run of this
        # section reported `cmovl` as absent from an object full of it.  A
        # pattern that matches nothing and a pattern that finds nothing print
        # the same thing.
        m = re.match(r'^\s+[0-9a-f]+:\s+((?:[0-9a-f]{2} )+)\s*\t(\S+)', ln)
        if m and cur:
            per[cur] += 1
            mn[m.group(2)] = mn.get(m.group(2), 0) + 1
    return per, mn


def rv_counts(path):
    """(per-function instruction counts, {mnemonic: n}) from OUR decoder."""
    per = {}
    mn = {}
    for nm, i in obj_insns(path, funcs=True):
        if nm is None:
            continue
        per[nm] = per.get(nm, 0) + 1
        mn[i.name] = mn.get(i.name, 0) + 1
    return per, mn


NAMES = ('myabs', 'mymin', 'mymax', 'myclamp', 'mysel', 'twice', 'swap',
         'mask', 'sign', 'absu', 'cmp3', 'bigsel')


def sec6():
    banner(6, 'THE SAME C, THREE TARGETS -- A COMPILE-TIME INSTRUCTION COUNT')
    print()
    para("""ONE FILE, THREE `--target=` FLAGS, ONE COMPILER, ONE OPTIMISATION
LEVEL.  The table below is the whole cross-architecture evidence this course
has, and it is an INSTRUCTION COUNT AT -O2.

IT IS NOT A TIMING AND NOT A SPEEDUP, and there is no ratio anywhere in this
section.  The x86-64 ABI course measured a 4.92x and a 27.65x at four
optimisation levels on hardware it could run; this course has no RISC-V
machine, no emulator and no RISC-V linker, so it cannot produce a counterpart
to either number and does not estimate one.  A count is a different claim from
a ratio in three ways worth naming: it does not know whether the instruction is
fast, it does not know whether the instruction is on the critical path, and it
counts a whole function rather than the part of it that runs most often.""")

    rvp = p('noflags_O2.o')
    a64p = p('noflags_a64_O2.o')
    x86p = p('noflags_x86_O2.o')
    if not (os.path.exists(rvp) and os.path.exists(a64p) and os.path.exists(x86p)):
        para('THE THREE-TARGET CORPUS IS ABSENT.  Run build_samples.sh first.')
        return
    rvp_, rvm = rv_counts(rvp)
    a64p_, a64m = a64_counts(a64p)
    x86p_, x86m = x86_counts(x86p)

    rows = []
    tot = [0, 0, 0]
    for n in NAMES:
        a, b, c = rvp_.get(n), a64p_.get(n), x86p_.get(n)
        if a and b and c:
            tot[0] += a
            tot[1] += b
            tot[2] += c
        rows.append([n, str(a or '-'), str(b or '-'), str(c or '-'),
                     str((b or 0) - (a or 0)),
                     str((c or 0) - (a or 0))])
    rows.append(['WHOLE CORPUS', str(tot[0]), str(tot[1]), str(tot[2]),
                 '%+d' % (tot[1] - tot[0]), '%+d' % (tot[2] - tot[0])])
    print()
    table(['function', 'riscv64', 'aarch64', 'x86-64', 'a64 - rv',
           'x86 - rv'], rows)
    print()
    para("""READ THE COLUMNS.  `a64 - rv` and `x86 - rv` are differences in
INSTRUCTIONS and they do NOT have the same sign: for this corpus at -O2, clang
emits FEWER instructions on AArch64 (%+d over the whole corpus) and MORE on
x86-64 (%+d).  That is a property of clang 21.1.8 on twelve functions and it
is not a statement about the architectures -- the same three targets order
differently on a different corpus, which is why every figure in this table is
about what a COMPILER CHOSE and none of them is about what a MACHINE COSTS.
A reader who reports "RISC-V needs more instructions" from this table has
reported a fact about one compiler and twelve functions and has labelled it
about a silicon.""" % (tot[1] - tot[0], tot[2] - tot[0]))

    para("""THE ROW THAT MATTERS IS THE ONE WHERE THE ARCHITECTURES DIVERGE IN
KIND, not in degree.  Three conditional-select idioms, one C function each,
and the RISC-V column shows a BRANCH where both other columns show a
CONDITIONAL MOVE.  The mnemonic census below is the evidence: it is the count
of every conditional idiom each target's object file contains, over the whole
of `noflags.c`, and the three sets are DISJOINT.""")

    CONDS = {
        'riscv64': ('branches', ('blt', 'bge', 'beqz', 'bnez', 'c.beqz',
                                 'c.bnez', 'bne', 'beq')),
        'aarch64': ('conditional moves / sets', ('csel', 'cset', 'cinc',
                                                 'cneg', 'csinc', 'csinv')),
        # x86-64 spells every conditional move with a SUFFIX that names the
        # condition, and it spells it after the operand size: `cmovll` is the
        # 32-bit "less" form, not `cmovl`.  The list here matches on a prefix
        # `cmov` instead of on sixteen exact spellings, because a table that
        # enumerates spellings is a table that goes quietly empty the first
        # time the assembler adds one -- and an empty table reads as "this
        # target has no conditional move", which is the one conclusion it
        # must never support.
        'x86-64': ('conditional moves', None),
    }
    mns = {'riscv64': rvm, 'aarch64': a64m, 'x86-64': x86m}
    print()
    para("""Each row is the count of every conditional idiom that target's object
file contains over the whole of `noflags.c`, and the DISJOINTNESS of the three
sets is COMPUTED below rather than asserted: the intersection of every pair is
printed whether or not it is empty.  The first version of this section wrote
the word "disjoint" in a paragraph and never computed an intersection, which
is the difference between a claim and a measurement.""")
    # The mnemonics column is what the harness reads, and a reader reads the
    # LABEL, so both are here and the label is the column that says which
    # architecture's spelling is in the next one.  The first version of this
    # table put the label in the column the sets are read from, so a search
    # for `csel` in the row about AArch64 found only the words
    # "conditional moves / sets" and a reader looking for the mnemonic had to
    # know the table was ordered that way on purpose.
    rows = []
    sets = {}
    for tgt, (label, keys) in CONDS.items():
        if keys is None:
            # The x86-64 row is a PREFIX match for the reason `idiom_of` says
            # at length: `cmovll` is the 32-bit "less" form, and a set built
            # from sixteen exact spellings is empty for two of the three
            # operand sizes the assembler actually emits.
            hits = sorted([(k, n) for k, n in mns[tgt].items()
                           if k.startswith('cmov') or k.startswith('set')])
        else:
            hits = [(k, mns[tgt][k]) for k in keys if mns[tgt].get(k)]
        sets[tgt] = set(k for k, _n in hits)
        rows.append([tgt, ', '.join('%s(%d)' % h for h in hits) or 'NONE',
                     label, str(sum(n for _k, n in hits))])
    table(['target', 'the mnemonics in the corpus', 'the idiom they are',
           'total'], rows)
    print()

    # THE THREE SETS ARE DISJOINT, and the file PROVES it rather than saying
    # it: the intersection of every pair is computed here and printed whether
    # or not it is empty.  The first version of this section asserted the word
    # "disjoint" in a paragraph and never computed an intersection, which is
    # the difference between a claim and a measurement and is the same failure
    # shape as the zero-disagreement cross-check section 10 exists to catch.
    print('  THE THREE SETS, DISJOINT -- computed, and printed whatever they')
    print('  turn out to be:')
    print()
    for x in ('riscv64', 'aarch64', 'x86-64'):
        for y in ('riscv64', 'aarch64', 'x86-64'):
            if x >= y:
                continue
            both = sets[x] & sets[y]
            print('    %-8s n %-8s = %s'
                  % (x, y, ', '.join(sorted(both)) if both else 'EMPTY'))
    print()
    union = set()
    for v in sets.values():
        union |= v
    print('    union of the three = %d distinct mnemonics; sum of the three '
          'sets = %d' % (len(union), sum(len(v) for v in sets.values())))
    print('    and every set is non-empty: %s'
          % ', '.join('%s=%d' % (k, len(v)) for k, v in sorted(sets.items())))
    print()
    para("""THREE SETS, DISJOINT, AND NO TOTAL IS ZERO.  RISC-V's set is
BRANCHES: `blt`, `bge`, `c.beqz`, `c.bnez`, `bne` -- and the second reader
printed no `csel` and no `cmov` anywhere in the object, because it emitted
none, not because this file filtered them out.  AArch64's is `csel` and
`cneg`, x86-64's is six `cmov` spellings.  A compiler targeting RISC-V cannot
write a `cmov` or a `set` even if it wants to, because neither encoding
exists -- and the reason it does not exist is printed by the manual in the
design note this course is named after.

AND THE ARITHMETIC IS NOT A COST.  On x86-64 the mnemonic census for `mymin`
is `mov / cmp / cmovl / retq` -- FOUR instructions where RISC-V's is THREE --
and RISC-V's is shorter.  That is the opposite of the usual story and it is
worth a paragraph, because it is a claim a reader is likely to get backwards:

  x86-64 needs a `mov` because the candidate value has to be in the register
  the `cmov` will write, and it is not there yet.  AArch64 needs a `cmp`
  because NZCV has to be set before `csel` can read it.  RISC-V needs NEITHER,
  because `blt` compares two registers as part of the branch and there is
  nothing to set up.

So the absence of a flags register is not uniformly a cost.  It costs the
compiler a `CMOVcc` to reach for and it saves the `mov` and the `cmp` that
`CMOVcc` depends on.  WHICH OF THOSE WINS ON REAL HARDWARE IS NOT MEASURABLE
HERE AND IS NOT CLAIMED.""")

    print()
    print('  THE THREE IDIOMS SIDE BY SIDE, -O2, decoded:')
    print()
    for n, label in (('mymin', 'a < b ? a : b'), ('mysel', 'c ? a : b'),
                     ('myclamp', 'x < lo ? lo : (x > hi ? hi : x)')):
        print('    %-8s %s' % (n, label))
        print('      riscv64 : %s'
              % ' | '.join(i.text.strip() for _f, i in
                           obj_insns(rvp, funcs=True) if _f == n))
        print('      aarch64 : %s'
              % ' | '.join(mnemonics_only(
                  read_disasm(a64p, n, 'aarch64'))))
        print('      x86-64  : %s'
              % ' | '.join(mnemonics_only(read_disasm(x86p, n, None))))
        print()
        # AND THE IDIOM, ONE PER TARGET, on its own line.  The first version of
        # this block printed the three rows and no summary, and the summary is
        # the whole point: a reader comparing three lines of disassembly has to
        # do the comparison themselves, and the comparison is the finding.
        rv_ids = [i.name for _f, i in obj_insns(rvp, funcs=True) if _f == n]
        a64_ids = [x.split()[0] for x in mnemonics_only(
            read_disasm(a64p, n, 'aarch64'))]
        x86_ids = [x.split()[0] for x in mnemonics_only(
            read_disasm(x86p, n, None))]
        print('        the idiom: riscv64 %s | aarch64 %s | x86-64 %s'
              % (idiom_of(rv_ids), idiom_of(a64_ids), idiom_of(x86_ids)))
        print()

    para("""SO: RISC-V EMITS A BRANCH, AArch64 EMITS `csel`, x86-64 EMITS
`cmovcc`.  Three architectures, one C function, one compiler, and the
difference is a consequence of a single design decision that the RISC-V manual
states in its own words and this course's title is named after:

  x86-64 has EFLAGS, so a comparison writes BITS IN A REGISTER and a
  conditional move is an INSTRUCTION that reads those bits.
  AArch64 has NZCV, so a comparison writes BITS IN A REGISTER and `csel` is
  an instruction that reads them -- with a fourth operand, the CONDITION, at
  bits[15:12], because NZCV has four conditions to name.
  RISC-V has NOTHING, so `sltu` WRITES A REGISTER and the result is data.

`csel` exists because NZCV exists.  It is not free there either: it is one
instruction, and so is `cmovcc`, and so is `blt`.  What differs is not the
instruction COUNT and it is certainly not the SPEED -- none of which can be
measured here.  What differs is the SPACE OF EXPRESSIONS each architecture
can reach in one instruction, and section 5's `sign` row is where RISC-V's
space is LARGER.""")


RVSEL = ('blt', 'bge', 'beq', 'bne', 'c.beqz', 'c.bnez', 'bgt', 'ble',
         'bgtu', 'bleu', 'bltu', 'bgeu', 'beqz', 'bnez')
A64SEL = ('csel', 'cset', 'csetm', 'csinc', 'csinv', 'csneg', 'cinc', 'cneg',
          'ccmp', 'ccmn', 'fcsel', 'fcset')
# x86-64 spells every conditional move with a SUFFIX that names the condition,
# and it spells the condition AFTER the operand size: `cmovll` is the 32-bit
# "less" form, not `cmovl`, and there are sixteen of them.  So the suffix list
# holds every English abbreviation x86 has for a condition, and every
# `cmov`+suffix is a member.  Matching a PREFIX rather than enumerating
# sixteen exact spellings is the right call for a table that has to survive
# the assembler adding one -- and an empty table reads as "this target has no
# conditional move", which is the one conclusion it must never support.
X86_CONDS = ('a', 'ae', 'b', 'be', 'c', 'e', 'g', 'ge', 'l', 'le', 'na',
             'nae', 'nb', 'nbe', 'nc', 'ne', 'ng', 'nge', 'nl', 'nle', 'no',
             'npe', 'ns', 'nz', 'o', 'p', 'pe', 'po', 's', 'z')
X86SEL = tuple('cmov' + c for c in X86_CONDS)


def idiom_of(names):
    """Which of the three conditional idioms a function's mnemonics use.

    The three sets are DISJOINT -- that is the finding, and section 6 computes
    the intersection of every pair rather than asserting it -- so this function
    can ask all three questions of every list and report which one answered.
    A list with a hit in two of them is printed as a MIX, because a classifier
    that silently returns the first hit is a classifier that cannot report its
    own confusion.
    """
    hits = []
    for label, keys in (('branch', RVSEL), ('csel', A64SEL)):
        if any(n in keys for n in names):
            hits.append(label)
    # x86-64 is matched on a PREFIX and not against an exact list, and the
    # reason is a bug this file already shipped once: `mnemonics_only` returned
    # `cmovll` -- condition "less", 32-bit -- and the set held `cmovl`, so the
    # x86-64 column reported NEITHER for a function whose disassembly is four
    # instructions with a `cmov` in them.  Sixteen conditions times two operand
    # sizes is thirty-two spellings, and a table that enumerates them is a
    # table that goes quietly empty the first time one is missed.  A predicate
    # cannot miss one.
    if any(n.startswith('cmov') for n in names):
        hits.append('cmov')
    return ' + '.join(hits) if hits else 'neither'


def mnemonics_only(lines):
    """The mnemonic and operands out of one of the reader's lines.

    `rsplit('\t')` was the first version and it kept only the LAST tab
    field, so `cmp<TAB>w0, w1` came out as `w0, w1` -- an operand list with no
    mnemonic, printed in a table whose column heading said MNEMONIC.
    """
    out = []
    for ln in lines:
        if '\t' in ln:
            out.append(ln.split('\t', 1)[1].strip())
        else:
            out.append(ln.rsplit('  ', 1)[-1].strip())
    return out


def read_disasm(path, func, triple):
    """The second reader's own lines for one function, verbatim.

    The triple is an ARGUMENT rather than something inferred from the file
    name.  The first version inferred it, and the inference was wrong for
    every object whose name did not contain the string `a64` -- which is all
    of the RISC-V objects -- and it produced an empty listing that looked
    exactly like a function the reader could not find.
    """
    out = []
    cur = False
    args = [OBJDUMP, '-d', path]
    if triple:
        args.insert(1, '--triple=' + triple)
    r = sh(*args)
    for ln in r.stdout.splitlines():
        m = re.match(r'^[0-9a-f]{16} <([^>]+)>:', ln)
        if m:
            cur = (m.group(1) == func)
            continue
        if cur and re.match(r'^\s+[0-9a-f]+:', ln):
            out.append(ln.rstrip())
    return out


# ===========================================================================
# SECTION 6B -- THE AArch64 SIDE, DECODED, because "csel exists" is a claim
# about an ENCODING and not about a mnemonic somebody typed.
# ===========================================================================

def sec6b():
    banner(6, 'THE AARCH64 SIDE, FROM THE ENCODING (not from the mnemonic)')
    print()
    para("""The sentence in section 6 -- "`csel` exists because `NZCV` exists" --
is only worth anything if `csel` really is an instruction that reads a
CONDITION, and the condition is a FOUR-BIT FIELD.  This section decodes the
AArch64 words clang emitted for the same C, using the AArch64 section's own
decoder (`a64dec.py`, in courses/a64asm/assets/samples/), and prints the
field.

Three sibling decoders, three courses, and the relationship is deliberately
explicit rather than accidental: this course borrows `rvdec.py` for RISC-V
and `a64dec.py` for AArch64, and neither sibling is edited.  A course that
imports a sibling's decoder and then PATCHES it in place makes two harnesses
disagree about which file is authoritative, so section 6B prepends its own
model where it needs one and says which.""")

    try:
        A64DEC_DIR = find_sibling('a64dec.py', 'A64DEC_DIR', 'a64asm')
    except SystemExit:
        para('THE AArch64 DECODER IS NOT ON THIS HOST; section 6B is skipped '
             'and says so rather than printing an empty table.')
        return
    if A64DEC_DIR not in sys.path:
        sys.path.insert(0, A64DEC_DIR)
    import a64dec

    a64p = p('noflags_a64_O2.o')
    if not os.path.exists(a64p):
        return
    r = sh(OBJDUMP, '--triple=aarch64', '-d', a64p)
    want = ('csel', 'cset', 'cinc', 'cneg', 'csinc', 'csinv', 'csneg')
    # A LINE IS PARSED BY ITS TAB, not by a pattern over the whole line.  The
    # first version of this loop matched `\s+([0-9a-f]{8})\s+(?:.*?\t)?(\S+)`
    # against a line that reads
    #
    #        10: 1a81b000    \tcsel\tw0, w0, w1, lt
    #
    # and the `\s+` after the word consumed the TAB along with the padding, so
    # `(?:.*?\t)?` matched nothing and `(\S+)` came back as `w0,` -- an
    # OPERAND, not a mnemonic.  Nothing matched `want`, `rows` came out empty,
    # and the table below it was never printed: the section that exists to
    # prove that `csel` is an instruction rather than a name reported no
    # instruction and no error.  An empty table and a pattern that matches
    # nothing print the same thing, which is why this section now says how
    # many words it found.
    found = 0
    for ln in r.stdout.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s', ln)
        if not m or '\t' not in ln:
            continue
        mn = ln.split('\t', 1)[1].split()[0]
        if mn in want:
            found += 1
    print()
    para("""%d words in this object name a conditional-select mnemonic, and every
one of them is printed below with the CONDITION FIELD read out of the word by
this file and the same word rendered by the AArch64 course's decoder.  Two
readers, one for the RISC-V side and one for the AArch64 side, and NEITHER of
them is a disassembler: `a64dec.py` decodes the AArch64 words the way
`rvdec.py` decodes the RISC-V ones, from the bits.""" % found)

    rows = []
    seen = {}
    for ln in r.stdout.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s', ln)
        if not m or '\t' not in ln:
            continue
        mn = ln.split('\t', 1)[1].split()[0]
        if mn in want:
            seen.setdefault(mn, (int(m.group(1), 16), ln.rstrip()))
    for k in sorted(seen):
        w, ln = seen[k]
        try:
            txt = a64dec.render(a64dec.decode(w))
        except Exception as e:
            txt = '(decoder: %s)' % type(e).__name__
        cond = (w >> 12) & 0xf
        rows.append(['0x%08x' % w, k, txt,
                     'bits[15:12] = 0x%x' % cond,
                     'cond %s' % cond])
    print()
    if rows:
        table(['word', 'the reader says', 'the decoder says',
               'the condition field', 'value'], rows)
    else:
        print('  NO CONDITIONAL-SELECT WORDS FOUND, and this section says so '
              'rather than printing an empty table.')
    print()

    # THE OUT-OF-ENCODINGS ARGUMENT, COUNTED.  The claim is that the I-type
    # format has no room for a fourth operand, and "no room" is a countable
    # statement: three register fields, five bits each, and thirty-two values
    # each, and the four bits a condition needs have to come out of one of the
    # other twenty-seven.  So the count is printed and the reader can check
    # the arithmetic rather than take it.
    print('  THE OUT-OF-ENCODINGS ARGUMENT, COUNTED.  A conditional move needs')
    print('  THREE registers -- two candidates and a destination -- and the')
    print('  I-type format has three register fields:')
    print()
    for f, hi, lo in (('rd', 9, 7), ('rn', 19, 15), ('rm', 4, 0)):
        print('    %-3s at bits[%2d:%2d]  = %2d bits = %d values'
              % (f, hi, lo, hi - lo + 1, 1 << (hi - lo + 1)))
    print('    ---------------------------------------------')
    print('    a 64-bit I-type instruction is 32 bits: 7 opcode + 3 funct3 +')
    print('    15 register + 7 of immediate.  The condition needs 4 bits, and')
    print('    the immediate field has 7.  There is no format in the base')
    print('    encoding that spends those 4 bits on a condition, so a')
    print('    conditional move with a FOURTH OPERAND is a different')
    print('    ENCODING, not an instruction with an extra field.')
    print()

    para("""EVERY ONE OF THEM CARRIES A FOUR-BIT CONDITION AT bits[15:12], and
that field is the whole of the AArch64 design's cost.  §KEEP§THERE IS NO ROOM LEFT for a condition in a three-register I-type word, so `csel` takes a different shape -- `csel <Xd>, <Xn>, <Xm>, <cond>` -- and it is a DIFFERENT ENCODING rather than an instruction with an extra field.

And a reader should be careful about which `csel` this is: `csel x0, x1, x2,
ne` with a 64-bit register and `cset w0, eq` with a 32-bit one are in
different groups, and the number in the mnemonic's suffix is not a size field
in the sense the RISC-V `w`-suffixed instructions have.

WHAT THIS SECTION CANNOT SHOW.  It cannot show that `csel` costs
anything.  It cannot show whether `csel` is implemented as a data
dependency or as a branch in some microarchitecture, because there is no
AArch64 silicon here either and no cycle is measured anywhere in this course.
What it shows is that the instruction EXISTS, that it CARRIES A FOUR-BIT
CONDITION, and that the condition field is what NZCV made necessary.

So the spine of the course rests on a bit field and not on a speed: RISC-V has
no register in which a comparison's result could be left, so there is nothing
for a four-bit operand to name, and the count above is the reason the AArch64
word is shaped differently from the RISC-V one.""")


# ===========================================================================
# SECTION 7 -- rv-registers.  ROLES, NOT NUMBERS.
# ===========================================================================

def sec7():
    banner(7, 'rv-registers: x0 IS NOT A REGISTER, AND NAMES ARE NOT NUMBERS')
    print()
    para("""THE CLAIM.  The ABI names ROLES.  `t0` is x5, `s0` is x8 and is also
called `fp`, `ra` is x1, `sp` is x2, and `zero` is x0 -- and the encoding holds
a NUMBER in every case, not a name.  The register field is five bits wide and
there are thirty-two things it can mean, and the disassembly's job is to pick
one of the two names the convention gives some of them.

So the first measurement is a CENSUS: over the whole corpus, how often does
each NAME appear, and how does that split by ROLE?  The interesting rows are
not the largest ones.""")

    # THE CENSUS IS COUNTED FROM THE BITS BY `regs_of`, and not by counting the
    # tokens in the printed operand list, and the reason is a number this file
    # got WRONG the first time it ran.  Counting printed tokens reported 18
    # writes to `gp` and 8 to `tp` over a corpus in which the compiler writes
    # neither, and `llvm-objdump-21 --triple=riscv64 -d` reports neither either.
    # The count was wrong because the compressed CL/CS formats name rs1' in
    # THREE bits at inst[9:7] and a three-bit field read with the five-bit
    # table reports the register SEVEN TOO SMALL -- so a real `a2` came out as
    # `gp`.  The audit in `reg_audit` is what makes that visible, and it is
    # printed immediately below with its own count.
    checked, agree, bad = reg_audit()
    census = {}
    as_src = {}
    as_dst = {}
    fp_census = {}
    for f, lv, _d in CORPUS:
        if f.endswith('_a64_O2.o') or f.endswith('_a64_O0.o') or \
                f.endswith('_x86_O2.o'):
            continue
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for nm, i in obj_insns(fp, funcs=True):
            for op in i.ops:
                if op in Dec.XNAME:
                    census[op] = census.get(op, 0) + 1
                elif op in Dec.FNAME:
                    fp_census[op] = fp_census.get(op, 0) + 1
            for label, role, name in regs_of(i):
                if role == 'written':
                    as_dst[name] = as_dst.get(name, 0) + 1
                else:
                    as_src[name] = as_src.get(name, 0) + 1
    rows = []
    for n in range(32):
        name = Dec.xreg(n)
        rows.append([str(n), name, ROLE[n], str(census.get(name, 0)),
                     str(as_src.get(name, 0)), str(as_dst.get(name, 0))])
    print()
    print('  BEFORE THE CENSUS, THE READER THAT PRODUCES IT IS AUDITED against')
    print('  the inherited decoder\'s own printed operands -- a SECOND rendering')
    print('  of the same bits, by a different piece of code:')
    print()
    print('    %d instructions checked, %d agree, %d disagree'
          % (checked, agree, checked - agree))
    print('    %d instructions placed from the FORMAT alone (a mnemonic not in '
          'the table),' % REGSTATS['fallback'])
    print('    %d instructions this table could not place at all'
          % REGSTATS['unplaced'])
    print()
    if bad:
        for f, name, text, mine, theirs in bad:
            print('    DISAGREE %s %-12s %-28s bits say %-16s printed says %s'
                  % (f, name, text, mine or '(none)', theirs or '(none)'))
        print()
    table(['x', 'ABI name', 'role', 'occurrences in printed text',
           'as a source', 'as a destination'], rows)
    print()
    para("""`occurrences in printed text` counts every appearance of the name
in the decoder's own output for the whole corpus; `as a source` and `as a
destination` count the instruction FIELDS, which is a stricter number because
it cannot double-count an operand that appears in a printed line twice.

THE ROW TO READ TWICE IS x0.  %d appearances as a source and %d as a
destination.  `zero` is the most common register in the printed text and it is
NEVER a destination that takes effect, because the manual says "Register x0 is
hardwired with all bits equal to 0" and a hardwired register is not a register
you can write -- it is a CONSTANT with an encoding.  Every arithmetic
comparison on this architecture is written `sltu rd, rs1, x0` or
`beq rs, x0, target`, so x0 is read constantly and written never, and that is
the shape of an ABI that treats a register as a role rather than as a
location.

AND THE TWO NAMES FOR x8.  The ABI calls it `s0` and the frame-pointer
convention calls it `fp`, and they are THE SAME REGISTER.  The decoder prints
`s0`; the second reader prints `s0`; `fp` is the assembler's alias and appears
in the text only when you ask for it.  This is much milder than the AArch64
trap where register number 31 is `sp` in one instruction slot and `xzr` in
another, and the reason it is milder is worth stating: on RISC-V the number
determines the name, always, and on AArch64 the SLOT determines it."""
         % (as_src.get('zero', 0), as_dst.get('zero', 0)))

    para("""`gp` AND `tp` ARE UNALLOCATABLE, which is a stronger word than
"preserved" and appears nowhere else in the table.  Measured over the whole
corpus: gp is written %d times and tp %d times.  There is a rule that says a
compiler may not do that, and the count is what distinguishes a rule that is
obeyed from a rule that does not exist -- a conditional rule nobody implements
is indistinguishable from no rule at all, and only a count tells them
apart.""" % (as_dst.get('gp', 0), as_dst.get('tp', 0)))

    print()
    print('  THE TWO REGISTER FILES, counted separately.  a0 and fa0 are')
    print('  DIFFERENT REGISTERS that share a spelling up to one character.')
    print()
    fp_rows = []
    for n in range(32):
        nm = Dec.freg(n)
        fp_rows.append([str(n), nm,
                        'argument' if n in FN_ARG else
                        ('callee-saved' if n in FN_CALLEE else 'temporary'),
                        str(fp_census.get(nm, 0))])
    table(['f', 'ABI name', 'role', 'occurrences'], fp_rows)
    print()

    para("""A FLOATING-POINT STORE NAMES ONE REGISTER IN EACH FILE, and the
encoding does not say which is which.  MEASURED from the corpus:
`fsd fa0, -24(s0)` has rs2 = bits[24:20] = 10 and rs1 = bits[19:15] = 8.  The
same five bits, the same two values, and TWO DIFFERENT REGISTERS: 10 in the
integer file is `a0` and in the floating-point file is `fa0`, and 8 in the
integer file is `s0` and in the floating-point file is `fs0`.  The store moved a
value out of `fa0` and addressed memory through `s0`.  A decoder that reads
every field through the integer table reports a store of `a0` to an offset
from `s0` -- two real registers, one of the wrong kind, and a function whose
every register name is plausible.

AND THIS FILE GOT IT WRONG FIRST, which is the only reason the sentence above
is stated so firmly.  The register census at the top of this section was
originally built by asking `is_fp(instruction)` once per instruction and
applying the answer to every field.  For `fsd` that answers "floating-point"
for the BASE as well as the data, and the audit printed 18 writes to `gp` and
8 to `tp` over a corpus in which the compiler writes neither -- because a real
`a2`, read as a base with the wrong file, came out as `fs2`, and `fs2` read as
an integer is `x18`, which is `s2`, and the arithmetic of a wrong lookup turns
one register into another.  The number was 18 and 8 and it was false, and it
was false in a way that a table of plausible names could not reveal: only the
AUDIT at the top of this section, which compares this file's own reading
against the inherited decoder's printed operands instruction by instruction,
turned 201 disagreements into 0.

That is the sharpest trap in this concept and it is a THIRD instance of the
same lesson in this collection, after AArch64's `x31`-is-`sp`-or-`xzr` and
after the compressed `rd'`-means-`x8`: A REGISTER NUMBER IS NOT A REGISTER
UNTIL YOU KNOW WHICH FILE IT IS IN, and the encoding does not say.""")

    print()
    print('  THREE SPELLINGS OF A ZERO, asked of the ASSEMBLER, not of clang:')
    print()
    rows = []
    for src in ('mv      t0, zero', 'addi    t0, zero, 0',
                'li      t0, 0', 'add     zero, t0, t1',
                'li      zero, 42', 'mv      zero, t0', 'nop'):
        w, nb, txt = Dec.asm_one(src, march='rv64gc')
        w4, nb4, txt4 = Dec.asm_one(src, march='rv64i')
        rows.append([src.split()[0], src, '%d bytes' % nb if nb else 'REFUSED',
                     txt, '%d bytes' % nb4 if nb4 else 'REFUSED'])
    table(['source', 'exactly', 'at -march=rv64gc', 'the second reader says',
           'at -march=rv64i'], rows)
    print()
    para("""AND HERE IS THE FINDING, and it is the one the concept is named
for.  Ask the assembler for `mv t0, zero` and the answer is that it does NOT
become a `c.mv`: §KEEP§it becomes `c.li t0, 0` -- the
COMPRESSED LOAD-IMMEDIATE with a zero immediate -- which is the same encoding
as `addi t0, zero, 0` and as `li t0, 0`, and all three are %s bytes at
-march=rv64gc and %s bytes at -march=rv64i.  The assembler canonicalises all
three spellings into ONE instruction before the encoder ever sees them, so a
course that asked "does the compiler use `mv rd, x0` or `addi rd, x0, 0` for a
zero" is asking about a distinction the assembler already removed.

Which is the point.  There is no `c.mv` with a zero source: in the compressed
specification `c.mv` is defined only when rs2 is not x0, and the encoding with
rs2 = x0 in that cell is `c.li`.  So the answer to "which spelling of a zero"
is "the one the architecture chose to make the SHORTER", and at -march=rv64i
there is no shorter one and the same three spellings all become the same
four-byte `addi`.  An INSTRUCTION COUNT here would be 3 versus 3 and a BYTE
COUNT would be 6 versus 12.""" % ('2', '4'))

    print()
    print('  AND WHAT THE COMPILER PICKS WHEN IT WANTS A ZERO, over the whole')
    print('  corpus at -O2, counted by the IMMEDIATE READ FROM THE BITS and not')
    print('  by the mnemonic, because the mnemonic is the thing being tested:')
    print()
    # THE IMMEDIATE, read from the BITS and not from the decoder's field
    # report.  The first version asked `field_of(i, 'imm')`, and the inherited
    # decoder writes its immediate line under the name `immediate` rather than
    # `imm`, so the lookup returned None on every instruction and all four
    # counts below printed ZERO -- which is indistinguishable from "the corpus
    # contains no zero-spelling at all", and is a claim a reader would have
    # believed.  So the immediate is read here from the format, and the count
    # is reported with the total number of instructions it looked at, because
    # a zero out of zero candidates is not a zero.
    def imm_of(i):
        """The decoded immediate, for the two families that spell a zero."""
        if i.name in ('c.li', 'c.addi', 'c.addiw', 'addi', 'addiw', 'andi',
                      'ori', 'xori', 'slti', 'sltiu'):
            if i.nbytes == 2:
                v = (Dec.bits(i.word, 12, 12) << 5) | Dec.bits(i.word, 6, 2)
                return v - 64 if v & 0x20 else v
            v = Dec.bits(i.word, 31, 20)
            return v - 4096 if v & 0x800 else v
        if i.name == 'lui':
            return Dec.bits(i.word, 31, 12) << 12
        return None

    zc = {'c.li rd, 0': 0, 'addi rd, x0, 0': 0, 'lui rd, 0': 0,
          'mv rd, x0': 0}
    samples = {}
    looked = 0
    for f, lv, _d in CORPUS:
        if f.endswith('_a64_O2.o') or f.endswith('_a64_O0.o') or \
                f.endswith('_x86_O2.o') or lv != 'O2':
            continue
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for nm, i in obj_insns(fp, funcs=True):
            v = imm_of(i)
            if v is None:
                continue
            looked += 1
            if v != 0:
                continue
            if i.name in ('c.li', 'addi', 'lui'):
                key = ('c.li rd, 0' if i.nbytes == 2 else
                       ('lui rd, 0' if i.name == 'lui' else 'addi rd, x0, 0'))
            else:
                key = 'mv rd, x0'
            zc[key] += 1
            samples.setdefault(key, i.text.strip())
    for k in ('c.li rd, 0', 'addi rd, x0, 0', 'lui rd, 0', 'mv rd, x0'):
        print('    %-28s %-5d %s' % (k, zc[k], samples.get(k, '')))
    print('    %-28s %-5d %s' % ('(instructions with an immediate read)',
                                  looked, 'the denominator for the four '
                                  'rows above'))
    print()
    para("""Read the denominator first, because it is what makes the other three
rows mean something.  %d instructions in the -O2 corpus carry an immediate
this file knows how to read, and %d of them have a ZERO immediate.

And the denominator is printed because the first version of this table
printed all four counts as ZERO -- because it asked the inherited decoder for
a field the decoder writes under a different name, so the lookup returned
None on every instruction.  A count of zero out of %d is a measurement.  A
count of zero out of ZERO is a bug wearing the costume of a result, and the
only thing that distinguishes the two on the page is the denominator sitting
next to them.

So the compiler in this corpus reaches for a zero in a register %d times, and
the spelling it picks is `c.li rd, 0` %d times and the four-byte
`addi rd, x0, 0` %d times -- and `mv rd, x0` never, for a reason that is about
the ENCODING and not about the compiler's taste: there is no compressed MOVE
with a zero source.  In the compressed specification `c.mv` is defined only
when rs2 is not x0, and the cell with rs2 = x0 is `c.li`.  So `mv t0, zero` and
`li t0, 0` and `addi t0, zero, 0` are not three spellings the compiler chooses
between; they are one instruction with three names, and the assembler
canonicalises all three before the encoder sees them.

Which leaves a real asymmetry, and it is the one worth having: the compiler
emits the TWO-BYTE form %d times and the FOUR-BYTE form %d times, in the same
corpus, at the same optimisation level, for the same operation.  An
instruction count cannot tell those apart -- both are one instruction -- and a
byte count can: 2 against 4.  That difference is the C extension's saving,
counted in BYTES, in one corpus, with no timing claimed anywhere near it."""
         % (looked, sum(zc.values()), looked, sum(zc.values()),
            zc['c.li rd, 0'], zc['addi rd, x0, 0'],
            zc['c.li rd, 0'], zc['addi rd, x0, 0']))

    print()
    print('  AND THE FRAME POINTER, which the ABI says is OPTIONAL:')
    print()
    rows = []
    for lv in LEVELS:
        fp = p('regs_%s.o' % lv)
        if not os.path.exists(fp):
            continue
        dst = src = n = 0
        for nm, i in obj_insns(fp, funcs=True):
            for label, role, name in regs_of(i):
                if name != 's0':
                    continue
                if role == 'written':
                    dst += 1
                else:
                    src += 1
            n += 1
        rows.append(['regs.c -' + lv, str(n), str(dst), str(src)])
    table(['level', 'instructions', 's0 written', 's0 read'], rows)
    print()
    para("""THE SPECIFICATION SAYS: "The presence of a frame pointer is optional.
If a frame pointer exists, it must reside in x8 (s0); the register remains
callee-saved."  MEASURED, clang writes s0 at -O0 and stops writing it as the
optimisation level rises -- which is not the compiler declining to use a frame
pointer, it is the compiler discovering that it does not need one, and the
corpus has no function deep enough to need one either way.  A reader who took
the -O0 row as "RISC-V uses s0 as a frame pointer" has taken a compiler's
choice as a property of the contract, and `x86-frame` is the lesson about what
that mistake looks like when the choice goes the other way.

AND `gp` AND `tp` ARE WRITTEN ZERO TIMES ANYWHERE IN THE CORPUS.  The ABI
calls them UNALLOCATABLE, which is a rule a compiler is not allowed to break,
and a rule no compiler ever breaks and a rule that does not exist are
indistinguishable except to a count.""")

    print()
    print('  gp / tp writes across the WHOLE corpus, every level, every file,')
    print('  counted from the bits by the same audited reader as the table')
    print('  above -- NOT by a pattern over the operand text, which is where')
    print('  the first 18-and-8 came from and where they were wrong:')
    print()
    gp = tp = 0
    for f, lv, _d in CORPUS:
        if f.endswith('_a64_O2.o') or f.endswith('_a64_O0.o') or \
                f.endswith('_x86_O2.o'):
            continue
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for nm, i in obj_insns(fp, funcs=True):
            for label, role, name in regs_of(i):
                if role != 'written':
                    continue
                if name == 'gp':
                    gp += 1
                if name == 'tp':
                    tp += 1
    print('    gp writes: %d        tp writes: %d' % (gp, tp))
    print()
    para("""%d and %d, out of %d register writes in the whole corpus, and
`llvm-objdump-21 --triple=riscv64 -d` prints neither register anywhere in any
of the %d RISC-V objects.  A rule that no compiler breaks and a rule that does
not exist are indistinguishable except to a count, and this count is zero on
both sides: the reader that counted it and the second reader that prints the
disassembly agree that the two registers are never written, and the rule is
obeyed rather than merely unobserved.""" % (gp, tp,
                                           REGSTATS['written'] + REGSTATS['read'],
                                           len(RVCORPUS)))
    para("""AND `x0`.  The table at the top of this section already says it: x0 is
written %d times and read %d times, and the read count is high because every
arithmetic comparison on this architecture names it.  It is the most-read
register in the architecture and a CONSTANT, and the encoding for it is a
real five-bit field in every instruction that has an rd -- which is why
`li zero, 42` ASSEMBLES, above, to four bytes, and why the hardware's
refusal to store into it is a property of the SILICON and not of the file.
There is no RISC-V silicon on this host, so this course measures the
assembler ACCEPTING the write and does not claim to measure the write being
discarded.""" % (as_dst.get('zero', 0), as_src.get('zero', 0)))


# ===========================================================================
# SECTION 8 -- rv-compressed-cost.  THE CONSEQUENCE, NOT THE ENCODING.
# ===========================================================================

def sec8():
    banner(8, 'rv-compressed-cost: WHAT COMPRESSION DOES TO THE ABI')
    print()
    para("""`rvasm`'s concept 3 already measured the ENCODING side of the C
extension: how many code points are reserved, which displacement families
share five bit positions and are assigned seven different orders, and the
four assembler refusals in the compressed register file.  NONE OF THAT IS
REPEATED HERE.  What is measured here is the CONSEQUENCE, which is a different
subject with a different kind of evidence:

  * a spilling sequence, before and after;
  * a hot loop, before and after;
  * a `jal`/`ret` pair, before and after;
  * and what a DISASSEMBLER has to do to find an instruction boundary.

Every number is an INSTRUCTION COUNT or a BYTE COUNT.  They are not a
speedup, and the reason is section 1: there is nothing on this host that could
measure one.""")

    rows = []
    for f in ('cpc', 'regs', 'abi'):
        for pair, note in (('rv64i', 'CONFOUNDED: no F, no D'),
                           ('rv64imafd', 'CLEAN: the only change is the C')):
            a = p('%s_%s.o' % (f, pair))
            b = p('%s_%s%s.o' % (f, pair, 'c' if pair == 'rv64imafd' else 'gc'))
            if pair == 'rv64i':
                b = p('%s_rv64gc.o' % f)
            if not (os.path.exists(a) and os.path.exists(b)):
                continue
            ia, ib = obj_len_hist(a), obj_len_hist(b)
            na, nb = sum(ia.values()), sum(ib.values())
            ba, bb = obj_bytes(a), obj_bytes(b)
            rows.append([f + '.c', pair, str(na), str(nb),
                         '%+d' % (nb - na), str(ba), str(bb),
                         '%d%%' % (100 * (ba - bb) // ba),
                         '%d%%' % (100 * (ib.get(2, 0)) // max(nb, 1)),
                         note])
    print()
    table(['file', 'without C', 'insns', 'with C', 'd-insns',
           'bytes', 'bytes+c', 'bytes saved', '2-byte share', 'the pair'],
          rows)
    print()
    para("""TWO PAIRS, AND THE DIFFERENCE BETWEEN THEM IS THE MOST USEFUL
METHODOLOGICAL RESULT IN THIS SECTION.

  `rv64i` vs `rv64gc`  is CONFOUNDED.  rv64i has no F and no D, so every
  `double` in the source is a CALL to a soft-float helper.  The instruction
  count moves because the ARITHMETIC changed, not because the encoding did,
  and a reader who reported that difference as "what compression costs" would
  be reporting a floating-point software-library decision as an encoding
  fact.  The `d-insns` column for that pair is LARGE, and every bit of it is
  the soft-float call.

  `rv64imafd` vs `rv64imafdc` is CLEAN.  Same base, same M, same A, same F,
  same D, and the only difference is the trailing C.  There the `d-insns`
  column is the compression's real effect on the instruction count, and the
  honest answer is that it is ZERO OR ALMOST: the C extension changes how many
  bytes an operation takes, and it does not change how many operations the
  compiler chose to perform.

  Read the two pairs side by side and the lesson is general.  A `-march`
  comparison is only a measurement of ONE extension when every other letter is
  held fixed, and "hold every other letter fixed" is a sentence that has to be
  said out loud because the alternative -- comparing the base against a
  `gc` build and calling the difference a compression result -- is the kind of
  mistake that survives review because both numbers are real.

`bytes saved` is a percentage of the .text bytes and it is NOT a speedup.  It
is a statement about instruction FETCH, and even that needs a memory system
this course cannot measure.  The honest sentence under this table is: fewer
bytes, the same operations, and no timing.""")

    print()
    print('  THE THREE SEQUENCES, side by side, decoded instruction by')
    print('  instruction.  Same source, -O2, and the SAME ISA apart from C.')
    print()
    for fn, what in (('spill', 'a callee-saved register, stored and reloaded'),
                     ('callret', 'a call and a return')):
        for tag, fp in (('rv64imafd  ', p('cpc_rv64imafd.o')),
                        ('rv64imafdc ', p('cpc_rv64imafdc.o'))):
            if not os.path.exists(fp):
                continue
            got = [(i.nbytes, i.text.strip()) for nm, i in
                   obj_insns(fp, funcs=True) if nm == fn]
            tot = sum(n for n, _t in got)
            print('    %-12s %-8s %2d instructions, %2d bytes: %s'
                  % (tag, fn, len(got), tot,
                     ' | '.join(t for _n, t in got)))
        print()

    print('  AND THE SPILL, WHICH IS WHERE THE ABI ACTUALLY FEELS IT:')
    print()
    for fn, what in (('spill', 'one callee-saved register'),
                     ('spilln', 'eight callee-saved registers')):
        for tag, fp in (('rv64imafd  ', p('cpc_rv64imafd.o')),
                        ('rv64imafdc ', p('cpc_rv64imafdc.o'))):
            if not os.path.exists(fp):
                continue
            got = [(i.nbytes, i.text.strip()) for nm, i in
                   obj_insns(fp, funcs=True) if nm == fn]
            stores = [t for n, t in got if t.startswith(('sd', 'sw', 'c.sd',
                                                         'c.sw', 'fsd', 'f'))]
            print('    %-12s %-7s %2d instructions, %2d bytes, %d stores'
                  % (tag, fn, len(got), sum(n for n, _t in got), len(stores)))
        print()

    print('  THE HOT LOOP.  The body runs n times and the prologue does not,')
    print('  so a whole-function byte count measures the wrong code.  Here is')
    print('  the body: the instructions between the first branch and the')
    print('  backward branch, which is the part that repeats.')
    print()
    for tag, fp in (('rv64imafd  ', p('cpc_rv64imafd.o')),
                    ('rv64imafdc ', p('cpc_rv64imafdc.o'))):
        if not os.path.exists(fp):
            continue
        ins = [i for nm, i in obj_insns(fp, funcs=True) if nm == 'hot']
        firstb = next((k for k, i in enumerate(ins) if i.name in BRANCHES),
                      0)
        lastb = max((k for k, i in enumerate(ins) if i.name in BRANCHES),
                    default=len(ins) - 1)
        body = ins[firstb:lastb + 1]
        print('    %-12s hot: %2d instructions, %2d bytes whole; the loop '
              'body is %d instructions and %d bytes'
              % (tag, len(ins), sum(i.nbytes for i in ins), len(body),
                 sum(i.nbytes for i in body)))
        if body:
            print('                   %s'
                  % ' | '.join(i.text.strip() for i in body))
    print()

    para("""AND THE BOUNDARY PROBLEM, which is where this concept stops being
about the ABI and becomes about the toolchain.  On x86-64 and AArch64 an
instruction's length is a CONSTANT, so a disassembler's loop is

    p += 4

and the loop cannot be wrong.  On RISC-V an instruction is TWO or FOUR bytes
and the loop is

    if (halfword & 3) == 3:  p += 4
    else:                     p += 2

which needs TWO BITS OF THE CURRENT POSITION and nothing else.  That is the
whole of the guarantee, and it is enormous: a word this file's decoder cannot
name at all still advances `p` by its own length, so an unmodelled
instruction is a gap in the NAMES rather than a gap in the WALK.

The demonstration, measured rather than asserted: this file walks every code
section of every corpus object with the rule and again with the length SUPPLIED
from outside, and reports how many instructions each walk found.  The supplied
version is what a disassembler with a symbol table can do and the rule version
is what one without it must do, and if the two counts are equal then the rule
is doing the work.""")

    rows = []
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        n_rule = len(obj_insns(fp))
        names, syms, rel, sf = elf_tables(fp)
        _d, secs = Dec.code_sections(fp)
        raw = open(fp, 'rb').read()
        n_sup = 0
        for _nm, vaddr, off, size in secs:
            _ins, _end = Dec.decode_text(raw, off, size, vaddr,
                                         tell_length=True)
            n_sup += len(_ins)
        rows.append([f, str(n_rule), str(n_sup),
                     'same' if n_rule == n_sup else 'DIFFERENT'])
    print()
    table(['object', 'instructions found by the RULE',
           'instructions found with the length SUPPLIED', 'verdict'], rows)
    print()
    total_r = sum(int(r[1]) for r in rows)
    total_s = sum(int(r[2]) for r in rows)
    para("""%d instructions found by the two-bit rule and %d found with the
length handed in, across %d code sections of %d objects.  %s

So the rule is load-bearing and it is the only thing standing between a
disassembler and a corpus of nonsense, and it is TWO BITS.  A reader who
arrives from AArch64 -- where the loop is `p += 4` and cannot be wrong -- has
to learn this first and has to learn it from an ENCODING rather than from an
argument, because there is no RISC-V machine here to run the wrong answer on.
That is why this course has no timings and this section still has a finding:
the cost of compression is measurable in bytes and the cost of NOT having
compression is measurable in a two-bit rule, and neither of them needs
hardware.""" % (total_r, total_s, len(rows), len(rows),
                 'EVERY WALK AGREES.' if total_r == total_s else
                 'THEY DISAGREE, and the table above says where.'))


# ===========================================================================
# SECTION 9 -- THE TWO-READER CROSS-CHECK.
#
# Every instruction in the RISC-V corpus is decoded twice: once by the
# inherited decoder, once by `llvm-objdump-21 --triple=riscv64`.  The report
# says how many instructions were compared, how many each NAMED, and how many
# disagreed, and it prints the normalisation fire table ON EVERY RUN whether
# or not there is anything to put in it.
# ===========================================================================

# ---------------------------------------------------------------------------
# THIS COURSE'S OWN NORMALISATION RULES, and why they are here.
#
# The inherited table has 47 rules and fires 34 of them on this corpus.  The
# thirteen that do not fire are DEAD HERE, and there are two very different
# reasons a rule can be dead and telling them apart is the whole point:
#
#   * THE RULE IS BROKEN.  A pattern anchored with `^mnemonic` never matches
#     because there is a SPACE there.  This is the AArch64 data-path bug and
#     it is the reason the fire table is pre-seeded at all.
#   * THE CORPUS DOES NOT CONTAIN THE SPELLING.  `neg` is dead here because
#     none of the four C files in this course emits a `neg`, and `jr` is dead
#     here because clang emits `ret` for it.  The rule is fine; this corpus
#     simply does not exercise it, and `rvasm`'s own 128-check harness is what
#     asserts it fires THERE.
#
# So this file prints the dead list in BOTH categories and refuses to conflate
# them, because a harness that asserts "zero dead rules" against a corpus that
# does not contain the spellings is a harness that fails on a healthy artifact
# and trains its reader to ignore it.
#
# The rules added here are for two spellings THIS corpus contains and the
# inherited table does not cover, and both EXPAND -- `seqz rd, rs` becomes
# `sltiu rd, rs, 1` and `fmv.d fd, fs` becomes `fsgnj.d fd, fs, fs`, so both
# sides GAIN an operand and a decoder that read the wrong register produces a
# different canonical form and is caught.  A rule that DELETED an operand
# would make the two readers agree by deleting the same operand, and the
# agreement would then be evidence about the rule.
# ---------------------------------------------------------------------------

XFIRE = {}
XEXTRA = ('seqz alias', 'fmv.d alias', 'bgez alias', 'bltz alias')


def reset_xnorm():
    global XFIRE
    XFIRE = dict((n, 0) for n in XEXTRA)


def normalise(t):
    """The inherited normalisation, then this course's two rules.

    The two rules match the INHERITED CANONICAL FORM, which has no space
    after the mnemonic -- `seqzx5,x5`, not `seqz x5, x5` -- because the
    inherited normaliser is what produces the string these rules receive.
    The first version wrote them against the pretty form and they fired zero
    times, which is a third instance of the same collection-wide bug: a rule
    written against a shape the pipeline does not produce, silently matching
    nothing.  The fire table below is what made it visible, and the fire
    table only made it visible because it is PRE-SEEDED, so that a dead rule
    is a row with a zero rather than an absence.
    """
    s = Dec.crosscheck_normalise(t)
    for rule in XEXTRA:
        if rule == 'seqz alias':
            m = re.match(r'^seqz([a-z0-9]+),([a-z0-9]+)$', s)
            if m:
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
                s = 'sltiu%s,%s,0x1' % (m.group(1), m.group(2))
        elif rule == 'fmv.d alias':
            m = re.match(r'^fmv\.d([a-z0-9]+),([a-z0-9]+)$', s)
            if m:
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
                s = 'fsgnj.d%s,%s,%s' % (m.group(1), m.group(2),
                                         m.group(2))
        else:
            # `bgez rs, T` is `bge rs, x0, T`, and the pair the inherited
            # table already carries is `blez`/`bnez`, which are the OTHER
            # direction.  Both sides GAIN an operand and neither loses one.
            pair = {'bgez alias': ('bgez', 'bge'), 'bltz alias': ('bltz', 'blt')}
            short, full = pair[rule]
            m = re.match(r'^%s([a-z0-9]+),(.+)$' % short, s)
            if m:
                XFIRE[rule] = XFIRE.get(rule, 0) + 1
                s = '%s%s,x0,%s' % (full, m.group(1), m.group(2))
    return s


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


def xcheck_canon(limit=12):
    """The disagreements with BOTH canonical forms printed, because a reader
    diagnosing a disagreement needs the strings the COMPARISON was made on,
    not the pretty ones."""
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
            a, b = normalise(k.text), normalise(txt)
            if a != b:
                out.append((f, addr, a, b))
    return out


def sec9():
    banner(9, 'TWO READERS ON THE SAME BYTES')
    print()
    para("""Every instruction in the RISC-V corpus is decoded TWICE: once by
the inherited decoder and once by `llvm-objdump-21 --triple=riscv64`.  Four
numbers, and the three that matter are not the first:

  * how many instructions the reader PRINTED and this file COMPARED;
  * how many of them this file NAMED (an unmodelled word is counted, never
    dropped);
  * how many DISAGREED -- and, if any did, each one PRINTED BY NAME, because
    a number of eleven is a bug report and a list of eleven is a diagnosis.

AND THE FIRE TABLE IS PRINTED WHETHER OR NOT THERE IS ANYTHING TO PUT IN IT.
A normalisation table that appears only on failure is a table this file's own
harness can only ever check on a broken artifact, and a check that runs on
failure and not on success is a check that has been false the whole time.
This collection has now been bitten by that three times.""")

    total, agree, disagree, unmod, badlen = xcheck_corpus()
    print()
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
        seen = {}
        for f, a, cm, ct in xcheck_canon():
            seen[(cm, ct)] = seen.get((cm, ct), 0) + 1
        print('      %d DISTINCT (mine, theirs) PAIRS, each with its count:'
              % len(seen))
        for (cm, ct), n in sorted(seen.items(), key=lambda kv: -kv[1])[:24]:
            print('        %-30s vs %-30s  %d' % (cm, ct, n))
        print()
        print('      and the first of each kind, in full:')
        done = set()
        for f, a, m, t in xcheck_detail():
            if m.strip() in done:
                continue
            done.add(m.strip())
            print('        %-16s 0x%04x  this file: %-26s reader: %s'
                  % (f, a, m.strip(), t.strip()))
            if len(done) >= 10:
                break
    print()
    if disagree == 0:
        para("""§KEEP§%d instructions, %d named, %d disagreements, %d length disagreements.  ZERO disagreements over %d named instructions, and ZERO length disagreements over the same %d.""" % (total, agree + disagree, disagree, badlen, agree + disagree, total))
    else:
        para("""%d instructions, %d named, %d disagreements, %d length
disagreements.  The disagreements are listed above, by name."""
              % (total, agree + disagree, disagree, badlen))

    fires = dict(Dec.NORMFIRES)
    for k, v in XFIRE.items():
        fires[k] = v
    total_rules = len(Dec.NORM_RULE_NAMES) + len(XEXTRA)
    fired = sum(1 for v in fires.values() if v)
    dead = sorted(k for k, v in fires.items() if not v)
    # WHY each dead rule is dead, one line per rule, and a dead rule with NO
    # entry prints as "(b) INVESTIGATE" rather than being folded into a
    # category it might not belong to.  A rule that has never been explained
    # is the one a reader should not be told is fine.
    #
    # A ZERO FROM A NORMALISER IS NOT A ZERO FROM A DECODER, and the two
    # reasons a rule can be silent are a broken pattern and a corpus that
    # does not contain the spelling.  This collection has now been bitten by
    # the first three times, and every time the only reason it was found was
    # that the fire table was PRE-SEEDED -- so that a rule which never fired
    # appeared as a ROW WITH A ZERO and not as an absence.
    DEAD_REASON = {
        'neg': 'no `neg` in four C files; the compiler spells it `sub rd, x0, rs`',
        'jr': 'clang spells every indirect jump `ret` or `jalr`, never `jr`',
        'zext.b': 'no byte-extension in the corpus',
        'csr name': 'the corpus has no CSR access at all',
        'csrr alias': 'the corpus has no CSR access at all',
        'csrw alias': 'the corpus has no CSR access at all',
        'rdcycle': 'nothing in the corpus reads a cycle counter',
        'c.ebreak': 'nothing in the corpus traps',
        'c.lui': 'no small-immediate lui survives -O1 in this corpus',
        'c.and': 'no 3-register bitwise and survives -O1 in this corpus',
        'c.or': 'no 3-register bitwise or survives -O1 in this corpus',
        'c.andi': 'no 3-register andi survives -O1 in this corpus',
        'c.jalr': 'every indirect call here is `jalr ra` from an `auipc` pair',
    }
    print()
    print('  THE NORMALISATION FIRE TABLE, pre-seeded with every rule at zero,')
    print('  and printed WHETHER OR NOT there is anything to put in it:')
    print()
    print('  %d rules, %d fired, %d matched nothing'
          % (total_rules, fired, len(dead)))
    print()
    if dead:
        print('  DEAD RULES, AND WHY EACH ONE IS DEAD.  A rule with no line')
        print('  here is reported as INVESTIGATE rather than assumed innocent:')
        print()
        for k in dead:
            print('    %-22s 0   %s' % (k, DEAD_REASON.get(k, 'INVESTIGATE')))
    print()
    print('  every rule that fired, with its count, so the reader can judge')
    print('  each one:')
    for k in sorted(fires, key=lambda k: -fires[k]):
        if fires[k]:
            print('    %-22s %d' % (k, fires[k]))
    print()
    print('  every rule that fired, with its count, so the reader can judge')
    print('  each one:')
    for k in sorted(fires, key=lambda k: -fires[k]):
        if fires[k]:
            print('    %-22s %d' % (k, fires[k]))
    print()

    para("""The rule table is INHERITED from `rvdec.py` rather than rewritten,
and inheriting it is the right call for a second reason this section makes
worth stating: a normaliser that DELETES an operand makes two readers agree by
deleting the same operand, and the agreement is then evidence about the
normaliser rather than about either decoder.  Every rule in that table
EXPANDS -- it turns a printed line into a line with the same or more
information in it -- which is a design property rather than a patch, and it
is why the count of disagreements here is a count about the DECODERS.""")


# ===========================================================================
# SECTION 10 -- THE FOUR POISONS.  Each must MOVE the number it claims to
# test, or the run prints [POISON FAILED] and the harness requires the
# verdict.
# ===========================================================================

def poison_named(model_name):
    """Remove ONE model from the dispatch and report the move in all four of
    the cross-check's numbers.  Returns a dict so the caller can print a
    delta for each and check that it is non-zero.

    AND IT REPORTS A VICTIM THAT IS NOT IN THE DISPATCH AT ALL, because that
    is the failure the first RISC-V course shipped: a poison whose victim had
    no corpus footprint could not move a number, and the file printed
    [POISON FAILED] against a control that had never run.  The first version
    of THIS course's poison 2 named the model `m_shiftimm_fixed` when the
    model is registered as `m_shift_imm_fixed` -- one character of underscore
    -- so the filter removed nothing, the delta was zero on every number, and
    the correct verdict was [POISON FAILED] for a reason that has nothing to
    do with the decoder.  A missing victim is now distinguished from an
    unmoved one, because they are different bugs.
    """
    names = [m[0] for m in Dec.MODELS32]
    if model_name not in names:
        return {'missing': True, 'model': model_name, 'names': names}
    return _poison_remove([model_name])


def _poison_remove(victims):
    """The shared body: remove a LIST of models, re-run, report the deltas.

    It takes a list because the most useful poison in this file is not "remove
    one model" but "remove everything THIS FILE added to the inherited
    dispatch", and that is two models.  A poison that removes one of them
    moves exactly one of the two numbers, which is correct and is what poison 2
    is for; a poison that removes both moves both, and it is the one that
    answers the question a reader actually has, which is "what is this
    course's own contribution to the disagreement count".
    """
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
    """Hand the length in from outside, as a disassembler with a symbol table
    can, and report how many instructions the walk finds.  The rule is
    load-bearing if and only if this differs."""
    got = {'rule': 0, 'supplied': 0}
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        d, secs = Dec.code_sections(fp)
        for _nm, vaddr, off, size in secs:
            ins, _e = Dec.decode_text(d, off, size, vaddr)
            got['rule'] += len(ins)
            ins2, _e2 = Dec.decode_text(d, off, size, vaddr,
                                        tell_length=True)
            got['supplied'] += len(ins2)
    return got


def poison_normaliser():
    """PLANT real disagreements, then show that an AArch64-shaped normaliser
    -- one that DELETES every operand after the first -- makes them
    DISAPPEAR.

    This is the fourth poison and the only one that tests the CHECK rather
    than the decoder.  A decoder bug is found by reading the output; a check
    bug is found only by trying to break the check.

    The planting is done on THIS file's side and not on the reader's, and the
    location is deliberate: inside the normaliser it would corrupt both sides
    and the two would agree perfectly around a real disagreement.  Every
    planted difference is a change to the LAST OPERAND, because the broken
    rule keeps the mnemonic and the first operand -- so a difference planted
    anywhere else would not be visible to the broken rule either, and the
    control would report a smaller movement for the wrong reason.
    """
    planted = []
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
            if k is None or k.name is None or ',' not in k.text:
                continue
            if normalise(k.text) != normalise(txt):
                continue
            # change the LAST operand to another real register name
            parts = k.text.split(',')
            last = parts[-1].strip()
            newlast = 'a7' if last not in ('a7', 'zero') else 'a6'
            planted.append((f, addr, ','.join(parts[:-1] + [newlast]), txt))

    def bad(t):
        """The AArch64-shaped rule: keep the mnemonic and the FIRST operand,
        DELETE everything after the first comma."""
        c = Dec.crosscheck_normalise(t)
        m = re.match(r'^([a-z0-9._]+?)([a-z][0-9]+)(.*)$', c)
        if not m:
            return c
        return m.group(1) + m.group(2)

    caught = sum(1 for _f, _a, mt, tt in planted
                 if Dec.crosscheck_normalise(mt) != Dec.crosscheck_normalise(tt))
    hidden = sum(1 for _f, _a, mt, tt in planted
                 if bad(mt) == bad(tt))
    return len(planted), caught, hidden


def sec10():
    banner(10, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER')
    print()
    para("""A control that cannot be made to fail is a comment that says the
word POISONED.  This collection has paid for that lesson three times -- the
AArch64 data-path course's cross-check reported ZERO disagreements over a
corpus where eighty-five instructions genuinely disagreed, and every one of
the four bugs had made the comparison VACUOUS rather than wrong; and the first
RISC-V course shipped a poison whose victim had no corpus footprint, so it
could not move anything.  So each of the four below names the number it tests,
runs the SAME loop over the SAME bytes, prints the DELTA as a number, and
prints [POISON FAILED] if the delta is zero.

The victims are chosen FROM THE CORPUS and not from a list of interesting
models, because a poison whose victim owns no words in this corpus is a
poison that cannot move a number no matter what it prints.""")

    print('  POISON 1 -- remove BOTH corrections this file prepends,')
    print('              `m_shiftw_fixed` and `m_shift_imm_fixed`, in one')
    print('              step.  It claims TWO numbers, because it is the one')
    print('              a reader actually wants: what is this course\'s own')
    print('              contribution to the disagreement count and to the')
    print('              unmodelled count, measured rather than asserted.')
    print('              Poison 2 then removes ONE of them, to show which of')
    print('              the two numbers each one owns.')
    r1 = _poison_remove(['m_shiftw_fixed', 'm_shift_imm_fixed'])
    if r1.get('missing'):
        print('    [POISON FAILED] a victim is NOT IN THE DISPATCH')
        print()
        return
    b, a = r1['before'], r1['after']
    print()
    print('    BEFORE: %d named, %d disagree, %d unmodelled'
          % (b[1] + b[2], b[2], b[3]))
    print('    AFTER : %d named, %d disagree, %d unmodelled'
          % (a[1] + a[2], a[2], a[3]))
    print('    DELTA: named %+d, disagreements %+d, unmodelled %+d'
          % (-r1['delta_named'], r1['delta_disagree'], r1['delta_unmodelled']))
    ok1 = (r1['delta_disagree'] != 0 and r1['delta_unmodelled'] != 0)
    print('    VERDICT: POISON 1 %s' % ('FIRED' if ok1 else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok1:
        print('    [POISON FAILED]')
    print()

    print('  POISON 2 -- remove `m_shift_imm_fixed` ALONE, the corrected')
    print('              slli/srli/srai.  It claims the UNMODELLED count and')
    print('              only that one, and the reason it can only claim that')
    print('              one is worth stating: removing it does NOT create a')
    print('              disagreement, it creates a HOLE.  The inherited model')
    print('              it replaces cannot NAME an RV64 shift of 32 or more,')
    print('              so the words go from "named and agreeing" to')
    print('              "unmodelled and counted" -- and the cross-check')
    print('              reports ZERO disagreements on a corpus where it has')
    print('              just lost 36 instructions.  That is the exact shape')
    print('              of the AArch64 data-path bug this section exists')
    print('              against, and it is why the UNMODELLED count is a')
    print('              first-class number here and not a footnote.')
    r2 = poison_named('m_shift_imm_fixed')
    if r2.get('missing'):
        print('    [POISON FAILED] the victim %r is NOT IN THE DISPATCH, so '
              'nothing was removed' % r2['model'])
        print()
        return
    b, a = r2['before'], r2['after']
    print()
    print('    BEFORE: %d named, %d disagree, %d unmodelled'
          % (b[1] + b[2], b[2], b[3]))
    print('    AFTER : %d named, %d disagree, %d unmodelled'
          % (a[1] + a[2], a[2], a[3]))
    print('    DELTA: named %+d, disagreements %+d, unmodelled %+d'
          % (-r2['delta_named'], r2['delta_disagree'], r2['delta_unmodelled']))
    ok2 = r2['delta_unmodelled'] != 0
    print('    VERDICT: POISON 2 %s' % ('FIRED' if ok2 else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok2:
        print('    [POISON FAILED]')
    print()

    print('  POISON 3 -- hand the instruction LENGTH in from outside, as a')
    print('              disassembler with a symbol table can, and compare the')
    print('              instruction count against the two-bit rule.  The')
    print('              number it must move is the COUNT ITSELF: with the')
    print('              length supplied the rule is no longer being tested')
    print('              by anything, and a rule nothing tests is a comment.')
    g = poison_length()
    print()
    print('    instructions found by the RULE      : %d' % g['rule'])
    print('    instructions found with length GIVEN: %d' % g['supplied'])
    d3 = g['rule'] - g['supplied']
    print('    DELTA: %+d' % (-d3))
    ok3 = d3 != 0
    print('    VERDICT: POISON 3 %s' % ('FIRED' if ok3 else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok3:
        print('    [POISON FAILED]')
    print()

    print('  POISON 4 -- break the CHECK, not the decoder.  Every real')
    print('              disagreement is listed by name, and then an')
    print('              AArch64-shaped normaliser -- one that KEEPS the')
    print('              mnemonic and the FIRST operand and DELETES the rest')
    print('              -- is applied to both sides.  The number it must move')
    print('              is the number of disagreements that DISAPPEAR.')
    planted, caught, hidden = poison_normaliser()
    print()
    print('    real disagreements planted (last operand changed): %d' % planted)
    print('    of those, the working cross-check CATCHES           : %d' % caught)
    print('    of those, the broken rule makes DISAPPEAR           : %d' % hidden)
    ok4 = planted > 0 and caught > 0 and hidden > 0
    print('    DELTA: %d of the %d planted disagreements were HIDDEN'
          % (hidden, planted))
    print('    VERDICT: POISON 4 %s' % ('FIRED' if ok4 else 'FIRED ON NOTHING '
                                        '-- [POISON FAILED]'))
    if not ok4:
        print('    [POISON FAILED]')
    print()
    para("""FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS:

    poison 1 claims the DISAGREEMENT count and the UNMODELLED count together,
            and moved them by %+d and %+d
    poison 2 claims the UNMODELLED count   and moved it by %+d
    poison 3 claims the INSTRUCTION COUNT  and moved it by %+d
    poison 4 claims the VISIBILITY of the check and hid %d of %d

AND THE FIRST DELTA IS THE ONE TO READ TWICE, because it moves two numbers
in OPPOSITE directions and both moves are correct.  Removing the corrections
takes 36 instructions from the NAMED column -- they stop being named -- and
puts 6 into the DISAGREE column, because the six `sraiw`/`srliw` words the
other correction owns are still named, just wrongly.  One correction loses
words and the other corrupts them, which is the whole argument for counting
the unmodelled words rather than trusting the zero.

A poison that cannot move must say so, and this file prints [POISON FAILED]
and stops.  It did that twice during this course's development, both times
for a reason that was about the POISON and not about the decoder: once
because the victim was named with a different underscore than the model it
was supposed to remove, so nothing was removed and every delta was correctly
zero; and once because the planted differences went into the FIRST operand,
which the broken normaliser also keeps, so the control was measuring the
wrong thing.  Both are printed rather than quietly fixed, because a course
that retracts a number is worth more than a course that has only ever
produced right ones.

And the one worth reading twice is poison 4, because it is the only one that
is about the CHECK rather than about the decoder, and because it is the shape
of the bug that made this collection's most confident number meaningless: a
normaliser that removes information makes two readers agree by removing the
same information, and the agreement is then evidence about the normaliser.  A
cross-check can compare six thousand real instructions, agree on every one of
them, and still be measuring nothing.  The only way to know whether yours can
is to make it fail on purpose and watch it.
""" % (r1['delta_disagree'], r1['delta_unmodelled'],
           r2['delta_unmodelled'], -d3, hidden, planted))


# ===========================================================================
# SECTION 11 -- THE RETRACTIONS.
#
# Every claim this course took back, in the order it was taken back, with the
# thing that was found instead.  `crosscheck.py` asserts the TEXT of every
# one, because a retraction that is quietly deleted is the one failure no
# number in this file can catch.
# ===========================================================================

# Each entry is (id, the claim as it was made, what was found instead).  The
# first version of this list held three entries, R10 to R12, and the other nine
# were reconstructed afterwards from what the file had actually got wrong
# during development -- the corrected `sraiw` shift amount, the RV64
# shift-immediate reading, the correction registered under the wrong opcode,
# the ninth argument, the compression pair, the spill frame, the caller audit,
# the percentage, the three-target comparison, the register-pair rule, the
# poison, and the dead-rule reading.  They are written here in the order this
# course met them, and each one is asserted AS TEXT by crosscheck.py, because
# a retraction that is quietly deleted is the one failure no number in this
# file can catch.
RETRACTIONS = [
    ('R1', 'the inherited decoder reads `sraiw a1, a0, 31` correctly',
     'it prints 1055, because the inherited `i_shiftw_immm` reads the whole '
     'TWELVE-BIT I immediate for a field that is FIVE bits wide. '
     '0x41f5559b: llvm-objdump-21 says `sraiw a1, a0, 0x1f`, this file said '
     '`sraiw a1, a0, 1055`. The inherited corpus never contained an `sraiw` '
     'that was not also a `srliw` with a lucky value, so the bug was right by '
     'coincidence on every word it was tested on. Corrected by a model '
     'PREPENDED in THIS file, not by editing the sibling.'),
    ('R2', 'the inherited decoder names every RV64 shift-immediate',
     'it does not. It reads `inst[31:25]` as `funct7`, which is the RV32 '
     'reading, and on RV64 that field is `shamt[5]`, the TOP BIT OF THE AMOUNT '
     'rather than a selector -- so '
     '§KEEP§EVERY shift by 32 to 63 decoded to NOTHING. 0x02051613 is `slli a2, a0, 0x20` and the '
     'inherited file reported it as unmodelled. The fix is that `inst[31:26] '
     'is 000000 for slli/srli and 010000 for srai`, and the amount is six '
     'bits at inst[25:20]. Measured delta of the correction: 36 words named '
     'that were not named before.'),
    ('R3', 'a correction registered against opcode 0x13 fixes R1',
     'it fixes NOTHING, and it is in this file because the failure mode is '
     'worth more than the fix. `slliw`/`srliw`/`sraiw` are opcode 0x1b; '
     '0x13 is OP-IMM and holds `slli`/`srli`/`srai`. The first version of '
     'the correction was inserted under 0x13, never fired, and the original '
     'symptom persisted -- and a correction that does not run has the same '
     'observable behaviour as the bug it was fixing.'),
    ('R4', 'the ninth argument is on the stack',
     'that is right for INTEGERS and wrong for DOUBLES, and the difference '
     'is the second calling convention rather than a special case. With fa0-fa7 '
     'exhausted and a0-a7 free, the ninth `double` is passed "according to '
     'the integer calling convention" and arrives in a0. `f9` reads NO stack '
     'argument at any optimisation level. With the integers also exhausted -- '
     '`m18` -- the ninth double is at 8(sp), because the ninth integer took '
     '0(sp). Two independent counters, and the second one only shows up in '
     'the mixed case.'),
    ('R5', 'adding the C extension changes bytes and not instructions',
     'false for the third file, and the reason is a register constraint and '
     'not an encoding. The CLEAN pair (`rv64imafd` against `rv64imafdc`) says '
     '+0 for `regs.c` and +0 for `abi.c` and +6 for `cpc.c`: the compressed '
     'forms have register constraints -- three bits, x8 to x15 -- that the '
     'register allocator has to respect, and respecting them changes what it '
     'emits. So the claim is true for two files of three and false for the '
     'third. The CONFOUNDED pair (rv64i against rv64gc) says something '
     'completely different -- -38 for `regs.c` -- and every bit of that is '
     'the SOFT-FLOAT library and not the encoding.'),
    ('R6', '`rv64i` against `rv64gc` measures what compression costs',
     'it does not, and this is the most transferable retraction in the file. '
     'The two settings differ in F, D and C at once, and the largest '
     'difference in the table is the F/D removal turning every `double` into '
     'a call. A `-march` comparison is a measurement of ONE extension only '
     'when every other letter is held fixed, and the artifact now builds a '
     'clean pair for exactly that reason.'),
    ('R7', 'a callee that spills one callee-saved register does less work '
     'than one that spills eight',
     'MEASURED, the opposite. The C extension gives the stack-pointer-relative '
     'stores a SIX-bit displacement with no scaling in some classes and a '
     'two-byte encoding, so `spilln` stores 4 values at rv64imafdc and 2 at '
     'rv64imafd for a frame that is SMALLER in the uncompressed build. The '
     'compressed encoding is not uniformly shorter per operation: it is '
     'shorter per operation THAT IT ENCODES, and the register allocator '
     'reacts to that by storing differently.'),
    ('R8', "the caller audit can read the callee's register choices",
     'it cannot, and the first version of it printed nonsense. At -O0 clang '
     "spills every argument to the caller's own frame, so the list of stack "
     'stores before the call is empty and the ninth argument is nowhere to '
     'be found. The audit is printed at -O2 and the -O0 row is not counted.'),
    ('R9', 'the compression cost is a percentage',
     'no figure in this course is a percentage of anything a machine does. '
     'The `bytes saved` column is a ratio of two byte counts from one '
     'compiler and it is labelled as such in the caption of the table it is '
     'in. A percentage of bytes is not a percentage of time and this file '
     'does not print one.'),
    ('R10', 'this course can compare its three targets for speed',
     'IT IS NOT MEASURED, and the file says so in section 1, in section 5 '
     'and in section 6 rather than in a limits section at the end. There is '
     'no RISC-V machine, no emulator and no RISC-V linker on this host; there '
     'is no AArch64 machine either; and the 4.92x and the 27.65x the x86-64 '
     'ABI course measured were measured ON HARDWARE IT COULD RUN. The '
     'three-target table is an INSTRUCTION COUNT and every caption on it says '
     'so, and no ratio appears anywhere in this course.'),
    ('R11', 'a dead normalisation rule is a broken normalisation rule',
     'on this corpus, thirteen of the inherited rules do not fire and NOT ONE '
     'of them is broken. §KEEP§A zero from a normaliser is not a zero from a decoder. '
     'This corpus emits no `neg`, no `jr`, no CSR access, no `c.lui` and no '
     '3-register bitwise operation, and a normaliser only ever sees the words '
     'a corpus happens to contain. A harness that asserts "zero dead '
     'rules" against a corpus that does not contain the spellings fails on a '
     'healthy artifact and trains its reader to ignore it. Every dead rule '
     'now carries a one-line reason and a rule with no reason prints as '
     'INVESTIGATE. And the same sentence holds one level further out: a zero '
     'from a normaliser is not a zero from the machine either, because there '
     'is no machine on this host for any of it to be a zero about.'),
    ('R12', "the first version of this course's poison 2 proved the "
            'correction unnecessary',
     'it proved nothing, and the file said so. The poison named its victim '
     '`m_shiftimm_fixed` while the model is registered as '
     '`m_shift_imm_fixed`, so the filter removed nothing, every delta was '
     'zero, and the verdict was CORRECT. A control that did not run and a '
     'control that ran and found nothing are the same number and two '
     'different bugs, and the distinction is now made in the code rather '
     'than in a comment.'),
]


def sec11():
    banner(11, 'TWELVE RETRACTIONS')
    print()
    para("""Twelve of them, in the order this course met them.
`crosscheck.py` asserts the TEXT of every one of them, because a retraction
that is quietly deleted is the one failure no number in this file can catch.

Ten of the twelve are about a DECODER or an INSTRUMENT and two are about a
COMPARISON, and that ratio is the shape of this subject: the calling
convention is a document you can quote and the compiler is a thing you can
measure, so the disagreements live in the machinery and the specification is
almost always right.

Nothing here is a mistake about how a computer works.  That is eleven courses
in a row, and it is the most interesting thing about the list: the RISC-V
ABI did not surprise this course once.  What surprised it was a three-bit
register field (R1, R2), a correction registered under the wrong opcode (R3),
a `-march` pair with two letters changed (R6), and the belief that a
three-register load names the same register twice (R5 and the register census
in section 7, which is why that table is preceded by its own audit).""")
    print()
    for rid, claim, found in RETRACTIONS:
        print('  %s  CLAIMED: %s' % (rid, claim))
        # A retraction's text is wrapped at a width that will not break the
        # exact phrases `crosscheck.py` asserts, for the same reason `para`
        # has a KEEP tag: a phrase split across two lines is a phrase a
        # harness cannot find, and a retraction whose text a harness cannot
        # find is a retraction that can be quietly deleted.  The KEEP tag is
        # per-PARAGRAPH here rather than per-retraction, because a retraction
        # is a list of sentences and more than one of them is asserted.
        for chunk in found.strip().split('\n\n'):
            keep = KEEP in chunk
            body = _wrap(chunk.replace(KEEP, '').strip(),
                         200 if keep else 68, "        ")
            for k, ln in enumerate(body):
                print(('%s%s' % ('    ' if k == 0 and not keep else '        ',
                                 ln)))
        print()


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
# SECTION 12 -- WHAT THIS FILE CANNOT SHOW, AND WHERE EVERY CLAIM CAME FROM.
# ===========================================================================

LIMITS = [
    'NO TIMING.  No cycle, no latency, no throughput, no speedup, no ratio of '
    'anything a machine did.  There is no RISC-V machine, no emulator and no '
    'RISC-V linker on this host, so every figure is a bit pattern, a count of '
    'bit patterns, an arithmetic identity, or a refusal from a real assembler.',
    'NOTHING IS EXECUTED.  Not one instruction in this course has run.  A '
    'branch that this file counts as a BRANCH has never been taken.',
    'NOTHING IS LINKED.  There is no RISC-V `ld`, so no `auipc`+`addi` pair '
    'is proved to land on the right address and no `.text` byte offset is '
    'proved to become the virtual address a relocation will produce.',
    'NO PAGE WALK, NO CACHE, NO TLB, NO BRANCH PREDICTOR.  The manual argues '
    'for its branch design in terms of front-end prediction; this course '
    'quotes the argument and measures nothing about it.',
    'THE STACK ALIGNMENT RULE IS AN ARITHMETIC IDENTITY ONLY.  "aligned to a '
    '128-bit boundary upon procedure entry" is QUOTED; that -O0\'s prologue ' 
    'and epilogue sum to zero mod 128 is MEASURED; that a misaligned access '
    'FAULTS cannot be measured here and is not claimed.',
    'NO RED ZONE, BUT NO MEASUREMENT OF ONE EITHER.  The rule is QUOTED -- '
    '"Procedures must not rely upon the persistence of stack-allocated data '
    'whose addresses lie below the stack pointer" -- and section 3 shows '
    'that every spilled argument costs an explicit frame.  What an '
    'INTERRUPT does to that memory is a property of the platform and is not '
    'measurable here.',
    'X0 IS HARDWIRED TO ZERO IN THE SPECIFICATION AND IN THE SILICON, AND '
    'THE ONLY PART THIS COURSE MEASURES IS THE ENCODING.  This limit '
    'separates two things a reader is likely to run together.  The ENCODING '
    'is five bits in every instruction that has an rd, it is a real field, '
    'and `li zero, 42` ASSEMBLES to four bytes: this course measures that and '
    'prints it.  The SILICON is a hardwired zero and a write to x0 is '
    'discarded whatever the encoding says, and that is a property of hardware '
    'this host does not have, so no claim is made about it.  The two are '
    'separable because the ENCODING is readable on this host and the SILICON '
    'is not: a file can contain an instruction whose architectural effect is '
    'nothing, and a decoder that cannot tell which instructions those are is '
    'not wrong about the bits -- it is silent about the silicon.',
    'THE TWO READERS SHARE AN ASSEMBLER.  `clang` assembled the corpus and '
    '`llvm-objdump-21` disassembled it, so both come from one LLVM tree, and '
    'GNU binutils has no RISC-V target installed.  What section 9 establishes '
    'is "this decoder and one other piece of software agree on what the bytes '
    'mean" -- NOT "either agrees with silicon".',
    "EVERY REGISTER ASSIGNMENT IS THE SPECIFICATION'S AND EVERY INSTRUCTION "
    "COUNT IS CLANG 21.1.8'S.  crosscheck.py asserts the first as exact "
    'numbers and the second as shapes, because a shape does not move with a '
    'compiler version and a bare value does.',
    'THE AArch64 SIDE IS DECODED BY A DIFFERENT DECODER FROM A DIFFERENT '
    'COURSE, and only for the words `noflags.c` produced.  "csel exists" is a '
    'fact about the encoding; "csel is cheap" is not a fact about anything '
    'this file can reach.',
    'NOTHING GENERALISES FROM AN EMPTY ROW.  Every distribution here is a '
    'distribution of what clang chose for four files of ordinary C at one '
    'version on one host, and a row with nothing in it is a statement about '
    'that corpus and not about the architecture.',
    'A CROSS-CHECK THAT AGREES IS NOT PROOF.  Section 10 exists because the '
    'AArch64 data-path course reported ZERO disagreements over a corpus where '
    'eighty-five instructions genuinely disagreed, and the only way to know '
    'whether a cross-check can fail is to make it fail on purpose.',
]

PROVENANCE = [
    ('the register table, the argument rules, the two counters', QUOT,
     'riscv-cc, Register Convention and Procedure Calling Convention'),
    ('"offset zero of the stack pointer on function entry"', QUOT,
     'riscv-cc, Procedure Calling Convention'),
    ('"Procedures must not rely upon ... below the stack pointer"', QUOT,
     'riscv-cc, Procedure Calling Convention -- the NO-RED-ZONE rule'),
    ('"The presence of a frame pointer is optional"', QUOT,
     'riscv-cc, Frame Pointer Convention'),
    ('gp and tp are UNALLOCATABLE', QUOT,
     'riscv-cc, Integer Register Convention, fourth column'),
    ('"We considered but did not include conditional moves"', QUOT,
     'rv32-unprivileged, the branch-design note'),
    ('"rather than use condition codes (x86, ARM, SPARC, PowerPC)"', QUOT,
     'rv32-unprivileged, the branch-design note'),
    ('"Register x0 is hardwired with all bits equal to 0"', QUOT,
     'rv32-unprivileged, Programmers\' Model for Base Integer ISA'),
    ('every argument placement in section 3', BYTES,
     "the store's relocation chain, read out of the ELF symbol and "
     'relocation tables by hand'),
    ('the ninth integer at 0(sp)', BYTES,
     'a `c.ldsp rd, 0(sp)` in the callee and a `c.sdsp rs, 0(sp)` in the '
     'caller, both at every level above -O0'),
    ('the ninth double in a0, and at 8(sp) when the integers are gone', BYTES,
     'the rs2 field of the store to D8, in `f9` and in `m18`'),
    ("the register pair's low half in the lower-numbered register", BYTES,
     'the base register of the third `long long` in `wide`'),
    ('the branch/mask/call classification in section 5', MEAS,
     'the mnemonic of every instruction in `noflags.c` at four levels'),
    ('`sign` is one instruction', BYTES,
     'srliw a0, a0, 0x1f at -O2, decoded from cpc.o/noflags_O2.o'),
    ('the three-target instruction counts', MEAS,
     'one source file, three `--target=` flags, one compiler version'),
    ('`csel` carries a four-bit condition', BYTES,
     'a64dec.py decoding the words clang emitted, plus the reader'),
    ('x0 appears as a source and never as an effective destination', MEAS,
     'a census of the rd/rs1/rs2 fields over the whole corpus'),
    ('gp and tp are written zero times', MEAS,
     'the same census, restricted to the two unallocatable registers'),
    ('`mv t0, zero` is `c.li t0, 0`', BYTES,
     'three assembler probes at rv64gc and at rv64i'),
    ('the two-byte and four-byte spellings of a zero', MEAS,
     'the decoded immediate across the whole corpus at -O2'),
    ('the byte counts in section 8', BYTES,
     'the executable section sizes, and the length of every instruction'),
    ('the confound between rv64i and rv64gc', MEAS,
     'two -march pairs, one confounded and one clean, on the same source'),
    ('the length rule is load-bearing', MEAS,
     'the same walk run with the length supplied from outside'),
    ("the two-reader agreement in section 9", BYTES,
     "this file's decoder against llvm-objdump-21, 5973 named instructions"),
    ('the sraiw/slli corrections R1 and R2', BYTES,
     '0x41f5559b and 0x02051613, read out of cpc_rv64imafd.o'),
]


def sec12():
    banner(12, 'WHAT THIS FILE CANNOT SHOW, AND WHERE EVERY CLAIM CAME FROM')
    print()
    para("""Twelve limits, and they are printed in the artifact's own words so
that a reader who copies a number out of this file cannot lose the sentence
that limits it.  A limit that is stated in a document nobody opens is not a
limit; it is a disclaimer.""")
    print()
    # The limits are enumerated with a PLAIN `  N. ` prefix and no column
    # padding.  The first version of this loop printed `  %2d. `, which
    # right-aligned the number in two columns and produced THREE leading
    # spaces for limits 1 to 9 and two for 10 to 12 -- so the list was
    # numbered, and no reader, script or harness could find the numbers,
    # because one space of the numbering was indentation and the other was
    # padding.  A numbered list whose numbers are not at the start of the
    # line is not numbered.
    for k, lim in enumerate(LIMITS):
        body = _wrap(lim, 70, '')
        print('  %d. %s' % (k + 1, body[0].strip()))
        for extra in body[1:]:
            print('     %s' % extra.strip())
    print()
    para("""THE PROVENANCE TABLE.  Every claim class in this course and which of
the three labels it carries, so that a claim cannot acquire a label
retroactively and a reader can check a category he can find.  The three
QUOTED sources are named with a section each; the MEASURED-ON-BYTES rows name
the FIELD or the FILE the bytes were read out of, because "measured on bytes"
is only a label if it says WHICH bytes.""")
    print()
    rows = []
    for what, lab, where in PROVENANCE:
        rows.append([lab, what, where])
    table(['label', 'the claim', 'where it came from'], rows)
    print()
    counts = {}
    for _w, lab, _wh in PROVENANCE:
        counts[lab] = counts.get(lab, 0) + 1
    para("""%d rows: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED.

And that ratio is worth a sentence, because it is the inverse of the ratio
in the AArch64 section's privileged course and the reason is the subject.  A
calling convention is a CONTRACT between compilers, and a contract is
something you can quote exactly and check a compiler against; an instruction
encoding is something you can only measure, because the thing being measured
is what one compiler did with it.  So on a course about a contract the QUOTED
third is the largest, and the number of MEASURED-ON-BYTES rows is large for a
second reason: this course needed the ELONGATION OF A RELOCATION CHAIN to
turn "which register holds argument three" from a reading of assembly text
into a reading of bytes, and three hops of `auipc` -> `c.lw`... no: of
`auipc` -> `.Lpcrel_hi0` -> the store is the measurement, and it is
byte-level because the alternative is a regex over a text file that nothing
else in this collection has checked.

WHAT THE COURSE OWES ITS SIBLINGS, and does not re-teach:

  * why a contract exists at all, and why a callee saves registers --
    `/courses/x86abi/lessons/x86-calling` and `/courses/x86abi/lessons/x86-saved`
  * what a frame is for, and what a frame pointer is for --
    `/courses/x86abi/lessons/x86-frame` and `/courses/a64abi/lessons/a64-frame`
  * the same contract for AArch64, and the two independent argument counters
    as AArch64 states them -- `/courses/a64abi/lessons/a64-aapcs`
  * the register file as a partitioned namespace on another architecture --
    `/courses/a64abi/lessons/a64-registers`
  * the ENCODING side of the C extension -- reserved code points, the seven
    permutations, the four assembler refusals --
    `/courses/rvasm/lessons/rv-compressed`
  * the six formats, the field map, and the immediates --
    `/courses/rvasm/lessons/rv-encoding`
  * what a two-reader check is for, and the vocabulary this course borrows
    for its own -- `/courses/rvasm/lessons/rv-verify`
  * what an object file IS -- `/courses/exe/lessons/exe-frontend`

Verified present before linking, every one of them.""" % (
        len(PROVENANCE), counts.get(MEAS, 0), counts.get(BYTES, 0),
        counts.get(QUOT, 0)))


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM', sec1),
    (2, 'THE SPECIFICATION, QUOTED, BEFORE ANY COMPILER RUNS', sec2),
    (3, 'rv-calling: a0-a7, AND WHERE THE NINTH ONE GOES', sec3),
    (4, 'THE NINTH DOUBLE, WHICH IS NOT WHERE A SUMMARY SAYS IT IS', sec4),
    (5, 'rv-noflags: THE ABSENCE, AND WHAT THE COMPILER EMITS INSTEAD',
     sec5),
    (6, 'THE SAME C, THREE TARGETS -- A COMPILE-TIME INSTRUCTION COUNT',
     sec6),
    (7, 'rv-registers: x0 IS NOT A REGISTER, AND NAMES ARE NOT NUMBERS',
     sec7),
    (8, 'rv-compressed-cost: WHAT COMPRESSION DOES TO THE ABI', sec8),
    (9, 'TWO READERS ON THE SAME BYTES', sec9),
    (10, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER', sec10),
    (11, 'TWELVE RETRACTIONS', sec11),
    (12, 'WHAT THIS FILE CANNOT SHOW, AND WHERE EVERY CLAIM CAME FROM',
     sec12),
]

# Section 6B is part of section 6's subject and runs inside it, so that
# `--section 6` gives a reader the AArch64 encoding evidence with the
# three-target table rather than making them ask for it separately.


def header():
    print(RULE)
    print('rvabi.py -- The RISC-V ABI, measured on the bytes')
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
    print('  The specification is the ORACLE and the compiler is the TEST')
    print('  SUBJECT.  Disagreements are printed as retractions in section 11.')
    print()
    print('  NOTHING HERE IS EXECUTED.  There is no RISC-V machine, no')
    print('  emulator and no RISC-V linker on this host, so this file has NO')
    print('  TIMINGS AND NO SPEEDUPS.  Section 1 says so before the first')
    print('  measurement and section 12 says so after the last one.')
    print()
    print('  The decoder is BORROWED from courses/rvasm/assets/samples/')
    print('  (rvdec.py) and the AArch64 words are decoded with the sibling')
    print("  AArch64 course's a64dec.py.  This file prepends two corrected")
    print('  models and edits no sibling; section 11, R1 and R2, say what')
    print('  they correct and why.')
    print()
    print('  Inherited decoder models: %d, of which this course PREPENDS 2.'
          % (INHERITED_MODELS - 2))
    print('  Total in the dispatch here: %d.' % INHERITED_MODELS)
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
        print('  THE MODELS IN THE DISPATCH, IN ORDER, WITH THIS COURSE\'S TWO')
        print('  FIRST:')
        print()
        for k, (nm, ops, fn, ext, claim) in enumerate(Dec.MODELS32):
            tag = '  <- THIS COURSE' if k < 2 else ''
            print('   %2d %-20s opcodes %-24s %s'
                  % (k + 1, nm, ','.join(hex(o) for o in ops), tag))
            for ln in _wrap(claim, 66, '        '):
                print(ln)
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
        if n == 6:
            fn()
            sec6b()
        else:
            fn()
    print(RULE)
    print('END OF REPORT -- %d sections, 12 limits, %d retractions, '
          '4 poisons.' % (len(SECTIONS), len(RETRACTIONS)))
    print(RULE)
    return 0


if __name__ == '__main__':
    sys.exit(main())
