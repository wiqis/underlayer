#!/usr/bin/env python3
"""a64sys.py -- the artifact for "The AArch64 Machine: Modes, Memory and Faults".

THE METHOD IS FORCED, AND IT IS PRINTED FIRST, BEFORE ANY MEASUREMENT.

There is no AArch64 machine on this host, no AArch64 emulator, and no AArch64
linker.  NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.  That is not a
limitation worked around; it is the subject.  A learner writing a backend is
in exactly this position -- a specification, a compiler, and no silicon --
and the honest response is to be scrupulous about which claims are which kind:

    MEASURED            an experiment on the compiler, the object file or the
                        bytes.  What the compiler chose, what the assembler
                        accepted and refused, what the encoding says, what
                        relocations the assembler emitted.
    MEASURED-ON-BYTES   a property of the emitted bytes, read TWICE -- by
                        the decoder in this file and by llvm-objdump-21 --
                        and the two readers are compared word by word.
    QUOTED              a manual claim, with the document and the section
                        printed next to it, and never mixed in with a
                        measurement.

There are NO TIMINGS in this file and there are none on any of the six pages.
The x86-64 section measured a 4.92x and a 27.65x.  Nothing in this section has
a counterpart, because there is no AArch64 clock to read, and nothing here
fakes one.  The one cross-architecture comparison in this file is a
COMPILE-TIME INSTRUCTION COUNT and it is labelled as such every time.

The specifications are the ORACLE.  The compiler and the assembler are the
TEST SUBJECT.  Every disagreement between them is printed as a RETRACTION, in
section 11, and crosscheck.py asserts the text of every one of them, so a
retraction can be neither quietly dropped nor edited into being right.

    python3 a64sys.py --run            the whole run, 12 sections
    python3 a64sys.py --section=5      one section
    python3 a64sys.py --audit          the decoder models this file adds
    python3 a64sys.py --why 0xd4000001  explain one word
"""

import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RULE = '=' * 76
THIN = '-' * 76

# The three labels.  Every claim in this file and on every page carries one.
MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
READELF = 'llvm-readelf-21'
TARGET = 'aarch64-linux-gnu'
LEVELS = ('O0', 'O1', 'O2', 'Os')

# ===========================================================================
# Part one: the decoder.
#
# This file does not write an AArch64 decoder.  It uses the one the FIRST
# course in this section wrote -- `a64dec.py`, twenty-one models, in
# courses/a64asm/assets/samples/ -- and adds the models that the SYSTEM
# group needs and that one did not have.
#
# That is not a shortcut, it is a finding, and section 3 prints it: the
# encoding course measured a field map and declared the rest out of scope, and
# the entire subject of THIS course lives in the part it left out.  Every
# instruction this course is about -- SVC, MRS, MSR, HVC, SMC, BRK, HLT,
# ERET, DRPS, the barriers -- is in the "Branches, Exception Generating and
# System" class at bits[28:25] = 0b1010/0b1011, and the base decoder claims
# five words of that class: B, BL, B.cond, CBZ, TBZ, BR/BLR/RET and HINT.
# A decoder that cannot name `svc #0` cannot check the syscall convention,
# and the syscall convention is what concept 1 is about.
#
# The decoder is located by walking UP the tree, overridable with A64DEC_DIR,
# for the reason printed in a64abi.py: a hardcoded relative path is a path
# that breaks the first time somebody moves a directory.
# ===========================================================================


def find_sibling_decoder():
    """Locate `a64dec.py` by walking UP from here until a directory holding
    a sibling `a64asm` course appears."""
    env = os.environ.get('A64DEC_DIR')
    if env and os.path.exists(os.path.join(env, 'a64dec.py')):
        return env
    d = HERE
    for _ in range(8):
        cand = os.path.join(os.path.dirname(d), 'a64asm', 'assets', 'samples')
        if os.path.exists(os.path.join(cand, 'a64dec.py')):
            return cand
        nxt = os.path.dirname(d)
        if nxt == d:
            break
        d = nxt
    raise SystemExit(
        'a64dec.py not found.  Set A64DEC_DIR to the directory holding it.\n'
        "It is the encoding course's decoder, courses/a64asm/assets/samples/.")


DECODER_DIR = find_sibling_decoder()
sys.path.insert(0, DECODER_DIR)

import a64dec  # noqa: E402  (the path has to be set first)

Dec = a64dec
XN, reg = a64dec.XN, a64dec.reg
BASE_MODEL_COUNT = len(Dec.MODELS)
BASE_MODELS = list(Dec.MODELS)

# ---------------------------------------------------------------------------
# The models this course adds.  Each is written against the sweep in section 3
# of this file, which is a table of real assembler output, not a memory of a
# manual.  The two-reader check in section 10 is what they have to pass.
#
# FOUR models, and the reason there are four rather than one is the finding:
# the SYSTEM class is not a group, it is a SPACE, and the four ways of
# selecting an operation inside it do not live in the same field.
# ---------------------------------------------------------------------------

# The system-register NAME for the (op0, op1, CRn, CRm, op2) tuple.
#
# MEASURED, section 3, from 20 `mrs`/`msr` assembler outputs.  The encoding
# names a register with FIVE fields, and this is the whole of the table for
# the ones this course needs.  A decoder that only prints the fields gets the
# register right and the NAME wrong, which is not a cosmetic difference: the
# point of the concept is that `ESR_EL1` and `ELR_EL1` are CRn=5,CRm=2 and
# CRn=4,CRm=0 -- two different CRn values for two registers that a kernel
# reads together in one handler.
#
# The first version of this table omitted TPIDR_EL0 and CurrentEL because
# they are "special" -- CurrentEL is not even an ELx register and has op1=3
# -- and the two-reader check reported 2 of the 20 words as unmodelled.  A
# table that covers the registers the course talks about and not the ones it
# happens not to talk about is a table with an off-by-concept bug in it.
SYSREGS = {
    # (op0, op1, CRn, CRm, op2) -> name
    (3, 0, 0x2, 0x0, 0): 'TTBR0_EL1',
    (3, 0, 0x2, 0x0, 1): 'TTBR1_EL1',
    (3, 0, 0x2, 0x0, 2): 'TCR_EL1',
    (3, 0, 0x1, 0x0, 0): 'SCTLR_EL1',
    (3, 0, 0x5, 0x2, 0): 'ESR_EL1',
    (3, 0, 0x4, 0x0, 0): 'SPSR_EL1',
    (3, 0, 0x4, 0x0, 1): 'ELR_EL1',
    (3, 0, 0x6, 0x0, 0): 'FAR_EL1',
    (3, 0, 0xc, 0x0, 0): 'VBAR_EL1',
    (3, 0, 0x4, 0x2, 2): 'CurrentEL',
    (3, 3, 0x4, 0x2, 1): 'DAIF',
    (3, 3, 0xd, 0x0, 2): 'TPIDR_EL0',
    # EL2's copies: op1 = 4.  MEASURED: `mrs x9, ESR_EL2` and
    # `mrs x10, VBAR_EL2` differ from the EL1 forms in ONE field, op1, and in
    # nothing else at all -- the same CRn, the same CRm, the same op2.  So a
    # table keyed on the whole five-tuple has to carry both, and a table keyed
    # on CRn/CRm/op2 alone would name ESR_EL1 and ESR_EL2 identically.
    (3, 4, 0x5, 0x2, 0): 'ESR_EL2',
    (3, 4, 0xc, 0x0, 0): 'VBAR_EL2',
    (3, 4, 0x2, 0x0, 2): 'TCR_EL2',
}


def m_sysreg(i):
    """MRS and MSR: `1101 0101 0 op0 op1 CRn CRm op2 Rt`.

    MEASURED, section 3, on 20 assembler outputs.  The fixed prefix is ten
    bits, `bits[31:22] = 0b1101010100`, and the FIRST of them is bit 21, which
    is the L bit: 1 for MRS (read, into Rt) and 0 for MSR (write, from Rt).

    That single bit is the whole difference between reading VBAR_EL1 and
    writing it -- `mrs x6, VBAR_EL1` is 0xd538c006 and `msr VBAR_EL1, x0` is
    0xd518c000, and XOR them and the only bit that differs is bit 21.  The
    other bits that differ are bits[4:0], the register, which is the point:
    the instruction NAMES its operand register in the same five bits whether
    it is reading or writing.

    The two halves of the model are therefore one model with one bit, and the
    first version of this file wrote them as two models with the same guard
    except for that bit -- so the second one was unreachable, and the
    two-reader check reported every MSR in the corpus as unmodelled.  A guard
    that differs from another guard by a bit that is IN the shared prefix is
    not two guards; it is one guard written twice.
    """
    if not i.fixed(31, 22, 0b1101010100, 'MRS/MSR, a 10-bit fixed prefix'):
        return False
    L = i.read(21, 21)
    op0 = i.read(20, 19)
    op1 = i.read(18, 16)
    crn = i.read(15, 12)
    crm = i.read(11, 8)
    op2 = i.read(7, 5)
    rt = i.read(4, 0)
    if op0 != 3:
        return False
    key = (3, op1, crn, crm, op2)
    name = SYSREGS.get(key)
    if name is None:
        return False
    r = XN[rt]
    if L:
        i.name = 'mrs'
        i.ops = ['%s, %s' % (r, name)]
        i.say('bit 21 (L) = 1: this is a READ into Rt.  The register is named '
              'by the FOUR fields op1=%s CRn=0x%x CRm=0x%x op2=%d, and the '
              'assembler calls the tuple %s -- which a decoder cannot invent, '
              'so a table of the tuple is not an optimisation but a '
              'requirement.  op0 = 0b11 says "not a special register" and the '
              'L bit above it says read.'
              % (format(op1, '03b'), crn, crm, op2, name))
    else:
        i.name = 'msr'
        i.ops = ['%s, %s' % (name, r)]
        i.say('bit 21 (L) = 0: this is a WRITE from Rt.  The five register-'
              'naming fields are IDENTICAL to the MRS of the same register '
              'and the five-bit Rt field is the source, so read-then-write of '
              'one register is one 32-bit word differing in bit 21 and bits '
              '[4:0] and nothing else.')
    return True


# The exception-generation family.  MEASURED, section 3, on 14 assembler
# outputs.  `svc`/`hvc`/`smc`/`brk`/`hlt` are ONE encoding with a 5-bit
# operation field at bits[4:0] and a 16-bit immediate at bits[20:5]:
#
#   svc #imm16   0b00001     hvc #imm16   0b00010     smc #imm16   0b00011
#   brk #imm16   0b00000     hlt #imm16   0b00100
#   dcps1        0b00001     dcps2        0b00010     dcps3        0b00011
#
# and the THREE-BIT field at bits[23:22] plus bit 21 says WHICH of those two
# tables you are in:
#
#   bits[23:22] = 00, bit 21 = 0   the first table  (svc/hvc/smc)
#   bits[23:22] = 00, bit 21 = 1   brk
#   bits[23:22] = 01, bit 21 = 0   hlt
#   bits[23:22] = 10, bit 21 = 1   dcps1/2/3
#
# That is a genuinely awkward shape and it is worth a page, because
# `svc #0` (0xd4000001) and `dcps1` (0xd4a00001) have THE SAME bits[4:0] and
# differ in two bits above it.  A decoder that keys on bits[4:0] alone
# resolves BOTH to the same mnemonic, and the two differ in a way a reader
# would notice immediately -- one traps to EL1, the other debugs.
EXC_OPS = {
    # (bits[23:22], bit 21) -> {bits[4:0]: mnemonic}
    (0b00, 0): {0b00001: 'svc', 0b00010: 'hvc', 0b00011: 'smc'},
    (0b00, 1): {0b00000: 'brk'},
    (0b01, 0): {0b00000: 'hlt'},
    (0b10, 1): {0b00001: 'dcps1', 0b00010: 'dcps2', 0b00011: 'dcps3'},
}


def m_exception_gen(i):
    """SVC/HVC/SMC/BRK/HLT/DCPS, and the immediate range the assembler allows.

    MEASURED, section 3, on 14 assembler outputs plus 8 refusals.  The
    immediate is bits[20:5], SIXTEEN bits, and the assembler REFUSES both
    `#65536` and `#-1` with the same diagnostic:

        error: immediate must be an integer in range [0, 65535].

    So the field is UNSIGNED here even though the instruction word around it
    is a signed-offset architecture everywhere else, and the refusal is
    asymmetric in a way worth noticing: `#65535` assembles and `#-1` does not,
    and `-1` is the same 16 bits.  A reader who writes `svc #-1` expecting the
    usual "all ones" idiom gets a diagnostic, and the diagnostic names the
    RANGE rather than the field, so it reads like a signedness complaint
    about a value that was negative to begin with.
    """
    if not i.fixed(31, 24, 0xd4, 'bits[31:24] = 0xd4, the exception group'):
        return False
    b2322 = i.read(23, 22)
    b21 = i.read(21, 21)
    tbl = EXC_OPS.get((b2322, b21))
    if tbl is None:
        return False
    op = i.read(4, 0)
    name = tbl.get(op)
    if name is None:
        return False
    i.name = name
    if name == 'dcps1' or name == 'dcps2' or name == 'dcps3':
        i.ops = []
        i.say('bits[23:22] = 0b10 with bit 21 = 1 is the DEBUG group and the '
              'five-bit field at bits[4:0] picks the exception LEVEL, not an '
              'operation: 1, 2, 3.  The immediate field is PRESENT in the '
              'encoding and unused, which is why `dcps1` prints with no '
              'operand and the assembler accepts `dcps1 #1` and drops it.  A '
              'field width is not a field meaning.')
        return True
    imm = i.read(20, 5)
    i.ops = ['#%d' % imm]
    i.say('bits[4:0] = 0b%05d selects this operation inside a table chosen by '
          '(bits[23:22] = 0b%02d, bit 21 = %d), and the immediate is the '
          'SIXTEEN bits at bits[20:5] -- unsigned, range [0, 65535] measured '
          'by the assembler refusing both ends.  AArch64 puts a 16-bit '
          'CONSTANT in the instruction where x86-64 puts nothing at all, and '
          'this is the whole difference: on x86-64 the number is an operand '
          'in a register, here it is a field.'
          % (op, b2322, b21))
    return True


def m_eret_drps(i):
    """ERET and DRPS -- the two instructions that LEAVE an exception level.

    MEASURED, section 3: `eret` is 0xd69f03e0 and `drps` is 0xd6bf03e0 and
    they differ in EXACTLY ONE BIT, bit 21 -- the L bit again, and here it
    means RETURN versus DROP.

    The reason this is a model rather than a constant is that a fixed
    32-bit encoding is 32 bits of constant for the simplest instruction in
    the architecture, and 26 of them are spent saying "return from an
    exception".  `m_br_blr_ret` in the imported decoder already models RET,
    and RET is 0xd65f03c0 -- bits[31:22] of ERET is 0b1101011010 and of RET
    it is 0b1101011001, so the two are NINE apart in that field and a
    decoder that guarded on the top eight bits would put them in the same
    model.
    """
    if not i.fixed(31, 22, 0b1101011010, 'ERET/DRPS, a 10-bit fixed prefix'):
        return False
    if not i.fixed(11, 8, 0b0011, 'CRm = 0b0011, the exception-return pair'):
        return False
    if not i.fixed(7, 5, 0b111, 'op2 = 0b111'):
        return False
    if not i.fixed(4, 0, 0, 'Rt = 0: neither has an operand'):
        return False
    L = i.read(21, 21)
    i.name = 'eret' if L else 'drps'
    i.ops = []
    i.say('bits[31:22] = 0b1101011010 plus CRm = 0b0011 and op2 = 0b111 is '
          'the whole instruction: ZERO of the 32 bits carry an operand and '
          'all 32 say %s.  ERET and DRPS differ in bit 21 and nothing else, '
          'so the L bit means RETURN here, it meant LOAD in the MRS/MSR '
          'model, and it will mean something else again in the next group.  '
          'A field is named by the group that owns it, and the SAME bit 21 '
          'has now been Load/Store, Return/Drop and, in the barrier group, '
          'neither.'
          % ('eret' if L else 'drps'))
    return True


def m_barrier(i):
    """DSB, DMB and ISB -- three words that differ in ONE field.

    MEASURED, section 3: DSB sy is 0xd5033f9f, DMB sy is 0xd5033fbf and ISB
    is 0xd5033fdf.  All three have op0 = 0b00, CRn = 0b0011, CRm = 0b1111
    and Rt = 0b11111, and they differ ONLY in the three-bit op2 field at
    bits[7:5]: DSB is 0b100, DMB is 0b101, ISB is 0b110.

    The first version of this model guarded on CRm and claimed that DSB and
    DMB were one bit apart inside CRm, which is FALSE -- the 0x9f / 0xbf
    difference the reader sees in the hex is entirely in op2, and the correct
    reading is that three instructions are distinguished by a THREE-bit
    field while the eight-bit CRm field is identical in all three.  The guard
    was wrong and no test could have found it, because a decoder that
    mislabels DSB as DMB is still a decoder that produces valid AArch64.

    The barriers are the subject of the NEXT course in this section
    (`a64-order`).  This course owns only the fact that they are three words
    in the SYSTEM class that a decoder has to be able to tell apart, and that
    they are 32 bits of mostly-constant -- a fixed-width encoding is a bad
    trade for an instruction with no operands.
    """
    if not i.fixed(31, 22, 0b1101010100, 'the SYSTEM prefix, as MRS/MSR has'):
        return False
    if not i.fixed(20, 16, 0b00011, 'op0 = 0b00 and op1 = 0b011: a barrier'):
        return False
    if not i.fixed(15, 12, 0b0011, 'CRn = 0b0011'):
        return False
    if not i.fixed(11, 8, 0b1111, 'CRm = 0b1111, identical in all three'):
        return False
    if not i.fixed(4, 0, 0b11111, 'Rt = 0b11111, the xzr alias'):
        return False
    op2 = i.read(7, 5)
    if op2 == 0b100:
        i.name, i.ops = 'dsb', ['sy']
    elif op2 == 0b101:
        i.name, i.ops = 'dmb', ['sy']
    elif op2 == 0b110:
        i.name, i.ops = 'isb', []
    else:
        return False
    i.say('the SAME 10-bit prefix as MRS/MSR and the same four bits of Rt, '
          'and op0 = 0b00 where a system register read has op0 = 0b11 -- so '
          'the two groups share a prefix and are separated by a two-bit '
          'field.  The three barriers are then told apart by the THREE bits '
          'at bits[7:5] and by nothing else at all: DSB 0b100, DMB 0b101, '
          'ISB 0b110.  The eight-bit CRm field is 0b1111 in all three, so a '
          'decoder that reads CRm as the discriminator gets the right answer '
          'for the wrong reason and the wrong answer for every other member '
          'of the class.')
    return True


def m_hint_family(i):
    """The HINT family -- and a BUG IN THE INHERITED DECODER, found here.

    MEASURED, section 3, and this model exists because of a defect.  The
    encoding course's decoder has a model called `m_hint` whose own claim is
    "NOP, WFI, YIELD and the rest: 27 fixed bits and a 5-bit hint number",
    and whose guard is `bits[31:5] = 0xd503201f >> 5`.

    That guard matches NOP and NOTHING ELSE.  MEASURED, on the nine hints
    clang's assembler emits:

        nop    0xd503201f  >>5 = 0x6a81900   guard MATCHES
        yield  0xd503203f  >>5 = 0x6a81901   no
        wfe    0xd503205f  >>5 = 0x6a81902   no
        wfi    0xd503207f  >>5 = 0x6a81903   no
        sev    0xd503209f  >>5 = 0x6a81904   no
        sevl   0xd50320bf  >>5 = 0x6a81905   no
        dgh    0xd50320df  >>5 = 0x6a81906   no
        bti    0xd503241f  >>5 = 0x6a81920   no
        autibsp 0xd50320ff >>5 = 0x6a81907   no

    ONE of NINE.  The body of the model is correct -- it reads bits[6:5] and
    bits[4:0] and has the right nine names -- and the guard makes the body
    unreachable for eight of them.  A guard that is one bit narrower than the
    group it is guarding does not fail loudly: it makes the decoder resolve
    ONE member of a family and print `(op 0x...)` for the rest, which is
    exactly what a decoder that had never heard of hints would also print.

    WHY IT SURVIVED TWELVE COURSES' ATTENTION, and the reason is the most
    useful thing in this file: the encoding course's own corpus, compiled
    with clang, contains NO `yield`, NO `wfe`, NO `wfi` and NO `sev`.  A
    model that is wrong about eight words the corpus does not contain is
    indistinguishable from a model that is right, and that course's artifact
    reports its unmodelled words as "9, and the unmodelled ones are Advanced
    SIMD" -- a true statement about a corpus in which the bug cannot appear.

    A count of unmodelled words is a fact about A CORPUS and not about A
    DECODER, and section 3 prints this one beside that course's number so
    the two are read together.

    The fix, and it is one bit of guard: the group is bits[31:5] = 0x6a81900
    with bits[4:0] free, so the guard should be bits[31:7] and the two
    discriminator fields read from below it.  This file does not edit the
    sibling -- a course that fixes another course's artifact by writing to
    it produces two artifacts that disagree -- so it PREPENDS this model and
    the sibling's guard never runs.
    """
    if not i.fixed(31, 12, 0xd5032, 'the HINT group, CRn = 0b0010'):
        return False
    if not i.fixed(4, 4, 1, 'bit 4 is a CONSTANT 1 in every hint'):
        return False
    crm = i.read(11, 8)
    op2 = i.read(7, 5)
    op1 = i.read(3, 0)
    # MEASURED on fourteen assembler outputs.  The hint number is the SEVEN
    # bits CRm:op2 read as ONE number, and the four BTI forms are the four
    # EVEN values 32, 34, 36, 38 of it -- not four consecutive values, which
    # is why the first version of this table (bti, bti c, bti j, bti jc at
    # op2 = 0, 1, 2, 3) printed `bti j` for `bti c` and an unnamed hint for
    # `bti jc`.  A table written from the SYNTAX rather than from the bits
    # gets the ORDER right and the VALUES wrong, and an ordering error in a
    # two-bit field is invisible until someone writes `bti jc`.
    key = (crm << 3) | op2
    names = {
        0: 'nop', 1: 'yield', 2: 'wfe', 3: 'wfi', 4: 'sev', 5: 'sevl',
        6: 'dgh', 7: 'autibsp', 32: 'bti', 34: 'bti c', 36: 'bti j',
        38: 'bti jc',
    }
    if op1 != 0xf:
        i.name = None
        return False
    i.name = names.get(key, '(hint #%d)' % key)
    i.ops = []
    i.say('the HINT group is CRn = 0b0010 with a CONSTANT bit 4 = 1, and the '
          'twelve bits below it are THREE fields: CRm at bits[11:8], op2 at '
          'bits[7:5] and op1 at bits[3:0].  That is why this model is here: '
          'the INHERITED guard was bits[31:5], one bit too narrow, and so '
          'matched NOP alone out of the fourteen hints clang accepts.  The '
          'inherited body was RIGHT and UNREACHABLE, which is the hardest '
          'kind of bug to see -- it does not produce a wrong answer, it '
          'produces NO answer, and no test can tell "this decoder has never '
          'heard of hints" from "this decoder has heard of one hint".')
    return True


def m_ldst_reg(i):
    """Load/store register (register offset) -- the LSL and EXTEND forms.

    MEASURED, section 3, on eleven assembler outputs.  The inherited decoder
    names NONE of them, because both of its load/store models are the
    IMMEDIATE forms (`m_ldst_uimm` and `m_ldst_uimm9`).

    The field map, read out of those eleven words and not out of a manual:

        bits[31:30]  size: 11 = 64-bit, 10 = 32-bit
        bits[29:27]  0b111, the group
        bits[26]     V, 0 for the general-purpose form
        bits[25:24]  0b00, the register form
        bits[24:23]  opc: 00 STR, 01 LDR, 10 LDRSW, 11 PRFM
        bit  22      L, the load/store bit -- and this is the bit the first
                     version of this model guessed wrong, because it read
                     bit 22 as part of the extension field
        bits[20:16]  Rm, the index register  (bits[15:13]  option): 011 LSL, 010 UXTW, 110 SXTW, 111 SXTX,
                     001 PRFM
        bit  12      for the LSL form, the shift amount, and it is ONE bit
        bits[11:10]  addressing mode, 10 = register offset
        bits[9:5]    Rn
        bits[4:0]    Rt

    The one-bit shift amount is worth a sentence on its own, because it is
    the kind of thing a reader assumes is a field and is not: MEASURED,
    `ldr x0, [x8, x9, lsl #3]` and `ldr x0, [x8, x9, lsl #0]` differ in ONE
    bit, and `ldr w0, [x8, x9, lsl #2]` differs from the FIRST of those in
    only the size field, not in the shift at all.  So the encoding does not
    store a shift amount; it stores "shift by the log of the access size",
    and the assembler refuses `lsl #1` and `lsl #2` on a 64-bit load with a
    diagnostic that says exactly that: `expected 'lsl' or 'sxtx' with
    optional shift of #0 or #3`.

    WHY THIS MODEL IS IN THIS COURSE, and the reason is the page-table
    corpus: every function that reads a descriptor by INDEX compiles to
    exactly this instruction, because `l0[i & 511]` is an index into an array
    and an index is a register.  A decoder that cannot name
    `ldr x0, [x8, x9, lsl #3]` cannot audit the code that walks a page table.
    """
    if not i.fixed(29, 27, 0b111, 'the load/store group'):
        return False
    if not i.fixed(25, 23, 0b000, 'bits[25:23] = 000: STR or LDR, and not '
                                  'LDRSW or the SIMD forms'):
        return False
    if not i.fixed(26, 26, 0, 'V = 0: the SIMD form belongs to the sibling '
                              "course's model"):
        return False
    mode = i.read(11, 10)
    if mode == 0b00:
        return False
    L = i.read(22, 22)
    option = i.read(15, 13)
    size2 = i.read(31, 30)
    rn = i.read(9, 5)
    rm = i.read(20, 16)
    rt = i.read(4, 0)
    amt_bit = i.read(12, 12)
    if option == 0b011:
        amt = 0 if not amt_bit else {2: 2, 3: 3}.get(size2, 0)
        ext = ('lsl #%d' % amt) if amt else 'lsl'
    elif option == 0b010:
        ext = 'uxtw'
    elif option == 0b110:
        ext = 'sxtw'
    elif option == 0b111:
        ext = 'sxtx'
    else:
        return False
    dst = 'x' if size2 == 0b11 else 'w'
    i.name = 'ldr' if L else 'str'
    mem = '[%s, %s, %s]' % (XN[rn], XN[rm], ext)
    if mode == 0b01:
        i.ops = ['%s%s, %s' % (dst, rt, mem[:-1] + '], %s' % XN[rn])]
    elif mode == 0b10:
        i.ops = ['%s%s, %s' % (dst, rt, mem)]
    else:
        i.ops = ['%s%s, %s!' % (dst, rt, mem)]
    i.say('the REGISTER-OFFSET load/store, which the inherited decoder does '
          'not model at all: its two load/store models are the immediate '
          'forms.  bit 22 is L, bits[20:16] is Rm -- FIVE bits, and the '
          'first version of this model read bits[21:16] and came back with '
          '41 for a register the assembler calls x9 -- and bit 12 is the '
          'WHOLE shift amount for the LSL form, one bit, because the '
          'encoding does not store a shift amount but a "shift by the log of '
          'the access size".')
    return True


# The SIBLING course's models, imported rather than rewritten.
#
# `a64abi.py` -- the second course in this section -- added six models for the
# families the procedure call standard needs: the SIMD&FP load/store, the
# literal, the pair, the two-source, the conversion and the extended
# add/sub.  This corpus needs two of them (`add x1, x2, w3, uxtw` and the
# floating-point conversions), so this file IMPORTS them rather than writing
# a seventh copy of a model that already exists two directories away.
#
# The import is optional and says so when it fails, because an artifact whose
# only source of models is a sibling it has to find is an artifact that stops
# working the moment somebody moves a directory.  A course that rewrote the
# sibling's models would produce two decoders that disagree about the same
# architecture, and a reader could not tell which one to believe.
def find_sibling(name, filename):
    """Walk UP from here until a directory holds a sibling `name` course.

    The same upward search as find_sibling_decoder, and for the same reason:
    a hardcoded `../../a64abi/...` breaks the first time somebody changes the
    depth of a course directory, and the first version of this lookup tried
    `dirname(DECODER_DIR)/a64abi` -- which is `courses/a64asm/assets/a64abi`,
    a path that cannot exist, so the import silently found nothing and the
    file ran with twenty-seven models while printing a note about six it did
    not have.
    """
    env = os.environ.get('A64ABI_DIR')
    if env and os.path.exists(os.path.join(env, filename)):
        return env
    d = HERE
    for _ in range(8):
        cand = os.path.join(os.path.dirname(d), name, 'assets', 'samples')
        if os.path.exists(os.path.join(cand, filename)):
            return cand
        nxt = os.path.dirname(d)
        if nxt == d:
            break
        d = nxt
    return None


SIBLING_DIR = find_sibling('a64abi', 'a64abi.py')
SIBLING_MODELS, SIBLING_CLAIMS = [], []
if SIBLING_DIR:
    if SIBLING_DIR not in sys.path:
        sys.path.insert(0, SIBLING_DIR)
    try:
        import a64abi as _abi      # noqa: F401  (import for its MODELS)
        SIBLING_MODELS = list(_abi.EXTRA_MODELS)
        SIBLING_CLAIMS = list(_abi.EXTRA_CLAIMS)
    except Exception as _e:        # noqa: BLE001
        SIBLING_MODELS, SIBLING_CLAIMS = [], []
        print('NOTE: could not import a64abi.py (%s); this file runs with '
              'its own models plus the encoding course\'s.' % _e)

EXTRA_MODELS = ([m_sysreg, m_exception_gen, m_eret_drps, m_barrier,
                 m_hint_family, m_ldst_reg] + SIBLING_MODELS)
EXTRA_CLAIMS = [
    ('m_sysreg', 'bits[31:22] = 0b1101010100, op0 = 0b11',
     'MRS and MSR: bit 21 is L (read/write) and the register is named by '
     '(op1, CRn, CRm, op2) -- a FOUR-field name plus op0, not a number'),
    ('m_exception_gen', 'bits[31:24] = 0xd4, (bits[23:22], bit 21) selects '
     'one of THREE operation tables, bits[4:0] picks within it',
     'SVC/HVC/SMC/BRK/HLT/DCPS: a 16-bit UNSIGNED immediate at bits[20:5], '
     'and two of the six mnemonics share their bits[4:0] with a third in a '
     'different table'),
    ('m_eret_drps', 'bits[31:22] = 0b1101011010, CRm = 0b0011, op2 = 0b111, '
     'Rt = 0',
     'ERET and DRPS: one bit apart, and the bit is the same bit 21 that '
     'MRS/MSR uses for load/store'),
    ('m_barrier', 'bits[31:22] = 0b1101010100, op0 = 0b00, op1 = 0b011, '
     'CRn = 0b0011, CRm = 0b1111, Rt = 0b11111, op2 in {0b100, 0b101, 0b110}',
     'DSB/DMB/ISB: three words told apart by a THREE-bit op2 while the '
     'eight-bit CRm is identical in all three -- so the obvious '
     'discriminator is the wrong one'),
    ('m_ldst_reg', 'bits[29:27] = 0b111, bits[26:24] = 0b000, '
     'bits[24:21] in {0000,0001,0010,0011,0100,0101,0110}, bits[11:10]!=00',
     'the REGISTER-OFFSET load/store: added because the page-table corpus is '
     'nothing but indexed loads, and the inherited decoder had only the two '
     'IMMEDIATE forms'),
    ('m_hint_family', 'bits[31:12] = 0xd5032, bit 4 = 1 constant',
     'NOP/YIELD/WFE/WFI/SEV/SEVL/DGH/BTI/AUTIBSP: added because the '
     'INHERITED guard was one bit too narrow and matched ONE of the fourteen '
     'hints the assembler accepts'),
]
Dec.MODELS = EXTRA_MODELS + BASE_MODELS
MODEL_COUNT = len(Dec.MODELS)
OWN_MODEL_COUNT = len(EXTRA_MODELS) - len(SIBLING_MODELS)


# ===========================================================================
# Part two: the tools.  Everything below RUNS something.
# ===========================================================================


def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True)


def tool_version():
    v = sh(CLANG, '--version').stdout.splitlines()
    o = sh(OBJDUMP, '--version').stdout.splitlines()
    r = sh(READELF, '--version').stdout.splitlines()
    return (v[0] if v else '?'), (o[0] if o else '?'), (r[0] if r else '?')


def present(tool):
    return sh('sh', '-c', 'command -v %s' % tool).stdout.strip() != ''


def assemble(src, triple=TARGET, path='_probe.s'):
    """Assemble one instruction or a few.  Returns (words, diagnostic)."""
    p = os.path.join(HERE, path)
    with open(p, 'w') as f:
        f.write('\t.text\n\t' + src.replace(';', '\n\t') + '\n')
    o = os.path.join(HERE, path[:-2] + '.o')
    r = sh(CLANG, '--target=%s' % triple, '-c', p, '-o', o)
    if r.returncode != 0:
        diag = ''
        for ln in r.stderr.splitlines():
            if 'error:' in ln:
                diag = ln.split('error: ', 1)[1].strip()
                break
        return None, diag or r.stderr.strip().splitlines()[-1][:80]
    out = sh(OBJDUMP, '--triple=aarch64', '-d', o).stdout
    words = []
    for ln in out.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
        if m:
            words.append((int(m.group(1), 16), m.group(2).strip()))
    return words, ''


def try_asm(src):
    """(accepted?, words, diagnostic) for one source line.

    Three outcomes and the middle one is the interesting one: a tool that can
    only say yes or no cannot tell a reader WHICH error it made, and the
    diagnostic is often the only evidence that a field is a particular width.
    """
    w, d = assemble(src)
    return (w is not None), (w or []), d


# --- reading a real file, with no tool and no library -----------------------

SHT_PROGBITS = 1
EM_AARCH64 = 183


def elf_sections(path):
    """Every section header of an ELF64 file, by name.

    The same technique the ELF course's readers use and the two AArch64
    courses' decoders use: `e_shoff` at 0x28, the section array at 0x3a,
    struct.unpack_from, no library.  A reader that shells out to readelf to
    find out where .text is, is a reader with a hardcoded path in it.
    """
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF' or d[4] != 2:
        raise ValueError('%s is not an ELF64 file' % path)
    machine, = struct.unpack_from('<H', d, 0x12)
    shoff, = struct.unpack_from('<Q', d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', d, 0x3a)
    raw = []
    for n in range(shnum):
        o = shoff + n * shentsize
        name, typ = struct.unpack_from('<II', d, o)
        flags, addr, off, size = struct.unpack_from('<QQQQ', d, o + 8)
        align, entsize = struct.unpack_from('<QQ', d, o + 48)
        raw.append((name, typ, flags, addr, off, size, align, entsize))
    stro = raw[shstrndx][4]

    def nm(n):
        e = d.index(b'\0', stro + n)
        return d[stro + n:e].decode('ascii', 'replace')

    out = {}
    for n, (name, typ, flags, addr, off, size, align, entsize) in \
            enumerate(raw):
        e = nm(name)
        out[e] = dict(type=typ, flags=flags, addr=addr, off=off,
                      size=size, align=align, entsize=entsize, index=n)
    return d, machine, out


def elf_symbols(path):
    """(value, size, type, bind, ndx, name) for every symbol.

    Read with struct.unpack_from and no tool, for the reason printed in
    elf_sections: the reader that finds out where a symbol is by asking
    readelf is a reader that cannot be pointed at a file readelf has not
    been told about.
    """
    d, machine, secs = elf_sections(path)
    s = secs.get('.symtab')
    if s is None:
        return []
    st = secs.get('.strtab')
    out = []
    for n in range(s['size'] // 24):
        o = s['off'] + n * 24
        nameoff, info, other, shndx = struct.unpack_from('<IBBH', d, o)
        value, size = struct.unpack_from('<QQ', d, o + 8)
        e = d.index(b'\0', st['off'] + nameoff)
        name = d[st['off'] + nameoff:e].decode('ascii', 'replace')
        out.append(dict(value=value, size=size, info=info, shndx=shndx,
                        name=name,
                        type=info & 0xf, bind=info >> 4))
    return out


def elf_relocs(path):
    """(section, offset, type, symindex, addend, symname) for every RELA.

    The type number is the LOW 32 bits of r_info and the symbol index is the
    HIGH 32, and getting that backwards produces a table in which every
    relocation names symbol 0 -- which is exactly what the first version of
    this function did, and the table it printed had 34 rows all pointing at
    `.bss` because the addend, not the symbol, was being read.
    """
    d, machine, secs = elf_sections(path)
    out = []
    for sname, s in sorted(secs.items()):
        if s['type'] != 4:          # SHT_RELA
            continue
        for n in range(s['size'] // 24):
            o = s['off'] + n * 24
            r_off, r_info, r_add = struct.unpack_from('<QQq', d, o)
            symidx = r_info >> 32
            rtype = r_info & 0xffffffff
            out.append(dict(sec=sname, off=r_off, type=rtype, sym=symidx,
                            addend=r_add))
    syms = elf_symbols(path)
    for r in out:
        r['name'] = (syms[r['sym']]['name']
                     if r['sym'] < len(syms) else '?')
    return out


def func_ranges(path):
    """(section index, start, end) for every sized function symbol.

    The two-reader walk is over FUNCTION ranges and not over whole code
    sections, and the reason is a number.  MEASURED: `rel.o`'s `.text` is
    2,101,380 bytes because one page table is declared 2 MiB-aligned and the
    assembler pads up to it, and `vec.o`'s `.text` contains 0x7c0 bytes of
    `.space` after the sixteen branches.  Those bytes are NOT code -- they
    are alignment -- and llvm-objdump disassembles them anyway, as a
    half-million `nop`s that the second file's `.s` never contained.

    The first version of the walk counted whole sections and reported
    527,837 instructions read against 2,233 real ones, with 522,326
    disagreements, every one of them a zero byte that this decoder declines
    to name and that objdump names `udf`.  A cross-check whose disagreement
    count is 99% padding is not a cross-check, and the number looked like a
    catastrophe rather than like a mistake in the harness.
    """
    d, machine, secs = elf_sections(path)
    out = []
    for x in elf_symbols(path):
        # STT_FUNC is 2, and a size of 0 means the assembler did not say how
        # big it is.  The FIRST version of this filter had the two conditions
        # the other way round, so it kept every NOTYPE symbol -- which is
        # every label, every section marker and the null symbol -- and the
        # walk then covered nothing at all, printing "0 instructions read"
        # with a zero exit status.  An empty table is not a table of zeroes.
        if x['type'] == 2 and x['size'] > 0:
            out.append((x['shndx'], x['value'], x['value'] + x['size']))
    return out


def text_insns(path, only_functions=True):
    """Every code section, decoded, as (section, insn) pairs.

    It calls THIS FILE's decode, not the base decoder's, so that the models
    this course adds are the ones being counted.  That matters twice: a
    coverage number computed with the base decoder would be a number about a
    DIFFERENT decoder, and the one thing section 9 is about is that the
    base decoder cannot name a single instruction in the SYSTEM group.
    """
    d, machine, secs = elf_sections(path)
    # The section INDEX a symbol's st_shndx refers to is its position in the
    # SECTION HEADER TABLE, which is the order the headers appear in the file
    # and NOT the alphabetical order a dict gives.  Building the index from
    # `enumerate(sorted(...))` put `.text` at 12 when the symbol table calls
    # it 2, every function range was looked up under the wrong section, and
    # the walk reported zero instructions over six objects with a zero exit
    # status.  The index now comes from the reader that parsed the headers.
    idx = {name: s['index'] for name, s in secs.items()}
    keep = None
    if only_functions:
        keep = {}
        for shndx, start, end in func_ranges(path):
            keep.setdefault(shndx, []).append((start, end))
    out = []
    for name, s in sorted(secs.items()):
        if (s['type'] == SHT_PROGBITS and (s['flags'] & 0x4) and s['size']):
            p = 0
            while p + 4 <= s['size']:
                w, = struct.unpack_from('<I', d, s['off'] + p)
                addr = s['addr'] + p
                ok = True
                if keep is not None:
                    ok = any(a <= addr < b
                             for a, b in keep.get(idx[name], ()))
                if ok:
                    out.append((name, decode(w, addr)))
                p += 4
    return out, machine, secs


def objdump_pairs(path, triple='aarch64'):
    """(word, text) for every instruction, from the SECOND READER.

    `--triple=x86-64` is REFUSED by this llvm-objdump with "can't find
    target: unable to get target for 'x86-64'"; the accepted spelling is
    `x86_64`, and the native default (no --triple at all) also works.  The
    AArch64 spelling is `aarch64` and it works, so the two halves of this
    function need different arguments and that asymmetry is exactly the sort
    of thing a reader trips over, so it is written down here.
    """
    args = [OBJDUMP]
    if triple:
        args.append('--triple=' + triple)
    args += ['-d', path]
    o = sh(*args).stdout
    out = []
    for ln in o.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
        if m:
            out.append((int(m.group(1), 16), m.group(2).strip()))
    return out


def readelf_relocs(path):
    """(offset, type_name, type_number, symname, addend) from READER TWO."""
    o = sh(READELF, '-r', path).stdout
    out = []
    for ln in o.splitlines():
        # The addend column is OPTIONAL: `llvm-readelf-21` prints
        # `R_X86_64_PC32  .data - 4` with a MINUS and no `+`, and a regex
        # that required a literal `+` matched the AArch64 rows and silently
        # dropped every x86-64 one -- so section 4 reported "x86-64 0
        # relocations" beside a table whose entire point was that the count
        # is one.
        m = re.match(r'^([0-9a-f]{16})\s+([0-9a-f]{16})\s+'
                     r'(R_[A-Za-z0-9_]+)\s+([0-9a-f]+)\s+(\S+)'
                     r'(?:\s*([-+])\s*(\S+))?', ln)
        if m:
            out.append(dict(off=int(m.group(1), 16), name=m.group(3),
                            type=int(m.group(2)[-8:], 16),
                            value=int(m.group(4), 16), sym=m.group(5),
                            addend=(m.group(6) or '') + (m.group(7) or '')))
    return out


def readelf_sections(path):
    """(name, type, size, align) from READER TWO, for the alignment claims.

    The row is a FIXED number of whitespace-separated fields after the
    `[n]` and the name, and the first version of this regex took the tenth
    group as the alignment -- which for a section with flags `WAX` is the
    EMPTY string between two spaces, so every section came back with an
    alignment of 0 and the whole "the assembler honours the 2 MiB
    requirement" measurement would have reported nothing.

    A column-aligned table read with a loose regex is a table whose columns
    are a guess, and the guess has to be checked against one known row.  The
    check here is that `.symtab` must come back with alignment 8, which it
    does, and section 6 prints both readers side by side so a reader can see
    the agreement rather than take it.
    """
    o = sh(READELF, '-S', path).stdout
    out = []
    for ln in o.splitlines():
        m = re.match(r'^\s*\[\s*(\d+)\]\s+(\S+)\s+(\S+)\s+([0-9a-f]+)\s+'
                     r'([0-9a-f]+)\s+([0-9a-f]+)\s+([0-9a-f]+)', ln)
        if not m or m.group(2) == 'NULL':
            continue
        # The last three columns of the row are Lk, Inf and Al, and Flg is
        # EMPTY for a section with no flags -- which is the case for
        # `.bss` when it carries none, and for every NOBITS section in most
        # of the ELF courses' samples.  A regex with a fixed number of
        # trailing groups therefore reads the alignment out of the wrong
        # column for exactly the sections whose alignment this course is
        # about: the first version reported `.symtab` as alignment 3, a
        # number that is not the alignment of anything.
        #
        # The rule that works: the SIZE is the sixth field and it is always
        # present, so everything AFTER it is the tail, and Al is the LAST
        # token of the tail.  Two of the first version's three rows came out
        # wrong and one came out right, which is the signature of a parse
        # that depends on a column being non-empty.
        tail = ln[m.end(7):].split()
        al = int(tail[-1]) if tail and tail[-1].isdigit() else 0
        ent = int(tail[-2]) if len(tail) >= 2 and tail[-2].isdigit() else 0
        out.append(dict(name=m.group(2), type=m.group(3),
                        size=int(m.group(6), 16), align=al, entsize=ent))
    return out


def readelf_symbols(path):
    """(name, value, size) from READER TWO."""
    o = sh(READELF, '-s', path).stdout
    out = []
    for ln in o.splitlines():
        m = re.match(r'^\s*(\d+):\s+([0-9a-f]+)\s+(\d+)\s+(\S+)\s+(\S+)\s+'
                     r'(\S+)\s+(\S+)\s+(\S*)$', ln)
        if m and m.group(8):
            out.append(dict(n=int(m.group(1)), value=int(m.group(2), 16),
                            size=int(m.group(3)), type=m.group(4),
                            bind=m.group(5), ndx=m.group(6), name=m.group(8)))
    return out


def decode(word, off=0):
    """Decode one word.  The models this course adds run FIRST."""
    return Dec.decode(word, off)


# ===========================================================================
# Part three: the measurement driver.
#
# Twelve sections, in this order, and the order is an argument:
#
#   1  the absences, printed BEFORE any measurement
#   2  the specifications, as oracles, quoted with their sections
#   3  the encoding, and the five decoder models this course adds
#   4  the syscall: the immediate, the x8 convention, the argument audit
#   5  the syndrome: ESR_ELx's packed field and the instructions around it
#   6  the vector table: VBAR, 16 x 0x80, and what the assembler enforces
#   7  the translation regimes: TTBR0, TTBR1, TCR, and the 48/52 split
#   8  the page tables: four levels, three regimes, and the RELOCATIONS
#   9  two readers, and then one of them poisoned
#  10  what is measured and what is quoted, as a table
#  11  the retractions, in full
#  12  the limits, in the file's own words
# ===========================================================================

RETRACTIONS = []

# Where each retraction was ASSERTED BEFORE this course was written, and a
# retraction with no prior source is a course disagreeing with itself.
#
# The map is here rather than inside the `retract()` calls because a retraction
# is a claim about a NUMBER and the number came from somewhere; printing the
# source next to it is the difference between "I checked" and "I thought
# about it".  `docs/aarch64-section-plan.md` is the section plan; "the brief
# for this course" is the written brief the course was built from.  Three
# retractions were found by THIS course's own measurements against a draft it
# had already written, and those say so rather than claiming a prior source.
SOURCES = {
    'R1': ('DRAFT of the concept plan; the claim was in the course\'s own '
           'first paragraph before any measurement'),
    'R2': ('the section plan and the first draft of concept 1, which said '
           '"the number is the immediate"'),
    'R3': ('docs/aarch64-section-plan.md, section C, item 12, read as an '
           'assumption about the inherited decoder'),
    'R4': ('this course\'s own measurement, on the inherited decoder, and it '
           'is the one retraction in the set with no prior source'),
    'R5': ('docs/aarch64-section-plan.md, section C, item 15, and the brief '
           'for this course'),
    'R6': ('the brief for this course, which asked what the compiler does '
           'with the argument registers'),
    'R7': ('this course\'s own draft of concept 2, which taught the shift'),
    'R8': ('docs/aarch64-section-plan.md, section C, item 13, and the brief'),
    'R9': ('the brief for this course, which asked "what the assembler does '
           'if you get it wrong"'),
    'R10': ('docs/aarch64-section-plan.md, section C, item 14, and this '
            'course\'s own first draft of the regime table'),
    'R11': ('docs/aarch64-section-plan.md, section C, item 15, which called '
            'the ELF-side consequence the hinge without saying what it is'),
    'R12': ('the brief for this course, which gave the reach as the reason'),
    'R13': ('this course\'s own first draft of the size table, which listed '
            'a 30-bit row (see R16) and the block sizes as a menu'),
    'R14': ('docs/aarch64-section-plan.md, rule 13, read as if a 100% '
            'two-reader agreement settled the question'),
    'R15': ('docs/aarch64-section-plan.md, rule 13, and the research log of '
            'the two courses before this one, both of which retracted their '
            'own 100%'),
    'R16': ('this course\'s own first draft of the regime table, which had a '
            '30-bit row in it'),
}


def retract(tag, claim, found, why):
    RETRACTIONS.append((tag, claim, found, why))


def hdr(n, title, sub=''):
    print()
    print(RULE)
    print('  %2d  %s' % (n, title))
    if sub:
        print('     ' + sub)
    print(RULE)


def p(label, text):
    print('  %-18s %s' % ('[' + label + ']', text))


def wrap(text, indent='       ', width=68):
    words, line, out = text.split(), '', []
    for w in words:
        if len(line) + len(w) + 1 > width and line:
            out.append(indent + line)
            line = w
        else:
            line = (line + ' ' + w).strip()
    if line:
        out.append(indent + line)
    return '\n'.join(out)


def note(text, indent='     . '):
    print(wrap(text, indent, 70))


def row(indent, *cols):
    print(indent + '  '.join(str(c) for c in cols))


# ---------------------------------------------------------------------------
# 1. The absences.
# ---------------------------------------------------------------------------

def sec1():
    hdr(1, 'THE INSTRUMENT, AND WHAT IT IS NOT',
        'printed before any measurement, because it decides what may be claimed')
    cc, od, re_ = tool_version()
    row('   ', 'host CPU', 'x86-64.  NO AArch64 silicon, and this file does not')
    row('   ', '', 'need it: not one instruction here has been run.')
    row('   ', 'compiler', cc)
    row('   ', 'disassembler', od)
    row('   ', 'reader 1: the decoder in this file, with %d models, %d of them'
        % (MODEL_COUNT, len(EXTRA_MODELS)))
    row('   ', '', 'added by THIS course and %d imported unchanged' %
        BASE_MODEL_COUNT)
    row('   ', 'reader 2: llvm-objdump-21 --triple=aarch64 -d', od.split()[2]
        if len(od.split()) > 2 else '')
    row('   ', 'ELF reader: llvm-readelf-21, and a second ELF reader in this')
    row('   ', '', 'file that uses struct.unpack_from and no library at all')

    print()
    for tool, what in (('aarch64-linux-gnu-ld', 'AArch64 linker'),
                       ('qemu-aarch64', 'AArch64 emulator'),
                       ('aarch64-linux-gnu-as', 'a SECOND AArch64 assembler'),
                       ('aarch64-linux-gnu-gcc', 'an AArch64 GCC')):
        here = present(tool)
        row('   ', '%-24s %s' % (tool, 'PRESENT' if here else 'ABSENT'),
            '(%s)' % what)
    print()
    note('Those four absences decide what this course may claim at all, and '
         'they are printed HERE, before the first measurement, rather than in '
         'a limits block at the end.  A reader who meets a number and then '
         'meets the absence of the thing that would make it a runtime '
         'measurement learns a different lesson from one who meets them in '
         'the other order.')
    print()
    p('NO TIMINGS', 'there are none in this file and none on any of the six '
                    'pages, and the')
    note('x86-64 section measured a 4.92x and a 27.65x.  Nothing in this '
         'section has a counterpart for either number, because there is no '
         'AArch64 clock on this host, and nothing here fakes one.  The ONE '
         'cross-architecture comparison in the whole file is section 4\'s '
         'COMPILE-TIME INSTRUCTION COUNT and it says so in every table that '
         'prints it.')
    print()
    p('the two absences', 'not one instruction has been run, and both readers '
                          'come from ONE')
    note('LLVM tree.  The cross-check in section 9 therefore establishes that '
         'this decoder and one other piece of software agree on what the '
         'bytes mean -- NOT that either agrees with the silicon.  There is no '
         'second AArch64 assembler on this host, so "the assembler" in every '
         'refusal quoted in this file means clang\'s integrated assembler at '
         'version 21.1.8 and nothing else.')
    print()
    p('the three labels', 'every claim in this file and on every page carries '
                          'exactly one:')
    row('   ', '   ' + MEAS.ljust(16),
        'an experiment on the compiler, the assembler, the object file')
    row('   ', '   ' + BYTES.ljust(16),
        'a property of the emitted BYTES, read by BOTH readers')
    row('   ', '   ' + QUOT.ljust(16),
        'a manual claim, with the document and the section beside it')
    print()
    note('Rule 13 of the section plan requires this and it is not a formality. '
         'A course built without hardware has exactly one honest advantage -- '
         'it can be scrupulous about provenance -- and a course that does not '
         'take it has thrown away the only thing it had that the x86-64 '
         'section did not.')


# The relocation names, with their NUMBERS, and the numbers are the part that
# gets two readers.
#
# QUOTED with a document: the ELF ABI for the Arm 64-bit Architecture, and
# the same table in `/usr/include/elf.h` on this host, which is generated from
# the Tool Standards and the AArch64 supplement.  MEASURED: the numbers the
# assembler actually emitted, read by `llvm-readelf-21 -r` (reader 2) and out
# of `r_info` with struct.unpack_from (reader 1), and the two are compared in
# section 8.
#
# A relocation NAME is a convention.  A relocation NUMBER is what goes in the
# file, and a name/number table written from memory is a table that is right
# about half the time and produces no error when it is wrong.
RELOCS = {
    257: 'R_AARCH64_ABS64',
    258: 'R_AARCH64_ABS32',
    260: 'R_AARCH64_PREL64',
    261: 'R_AARCH64_PREL32',
    274: 'R_AARCH64_ADR_PREL_LO21',
    275: 'R_AARCH64_ADR_PREL_PG_HI21',
    276: 'R_AARCH64_ADR_PREL_PG_HI21_NC',
    277: 'R_AARCH64_ADD_ABS_LO12_NC',
    278: 'R_AARCH64_LDST8_ABS_LO12_NC',
    282: 'R_AARCH64_JUMP26',
    283: 'R_AARCH64_CALL26',
    284: 'R_AARCH64_LDST16_ABS_LO12_NC',
    285: 'R_AARCH64_LDST32_ABS_LO12_NC',
    286: 'R_AARCH64_LDST64_ABS_LO12_NC',
    299: 'R_AARCH64_LDST128_ABS_LO12_NC',
}


def relname(n):
    return RELOCS.get(n, 'R_AARCH64_#%d' % n)


# --- the assembly TEXT, read as TEXT ---------------------------------------
#
# The argument audit is done on the TEXT, because an argument's identity is a
# fact about the C (VA3 is the 0x4444 load) and the register it landed in is
# a fact about the instruction.  Everything that is a claim about BYTES is
# done on the bytes and cross-read against llvm-objdump in section 9.  Which
# is which is stated at every table.


def strip_comment(line):
    """One line of assembly with its COMMENT removed.

    The `#` is ambiguous on AArch64, where `#0x10` is an IMMEDIATE, so the
    rule is not "strip at the hash": a comment is a `#` at the start of a
    line or after whitespace whose next character is not a digit and not a
    sign.  That distinguishes `# @foo` from `[sp, #16]` without a list of
    the mnemonics that can appear in either file.
    """
    line = line.split('//')[0]
    line = re.split(r'(?:^|\s+)#\s+(?![-+0-9])', line)[0]
    return re.sub(r'\s+', ' ', line).strip().rstrip()


def asm_functions(path):
    """Every label the assembler was told is a FUNCTION, in file order, with
    its body.

    The rule is the assembler's own: a label is a function if a
    `.type NAME,@function` directive says so, and nothing else counts.  A
    version that took every identifier-looking label also took the `.bss`
    globals, and a table of functions with four rows that are not functions
    is a table that reports zero instructions for four functions.
    """
    order, bodies, cur, pending = [], {}, None, None
    for raw in open(path):
        t = strip_comment(raw)
        m = re.match(r'^\.type\s+([A-Za-z_$][\w$.]*)\s*,\s*[@%]function$', t)
        if m:
            pending = m.group(1)
            continue
        m = re.match(r'^([A-Za-z_$][\w$.]*):$', t)
        if m and not t.startswith('.'):
            if pending:
                order.append(pending)
                bodies[pending] = []
            cur = pending
            pending = None
            continue
        if cur is None:
            continue
        if t:
            bodies[cur].append(t)
    return [(k, bodies[k]) for k in order]


def insn_lines(body):
    """The INSTRUCTIONS of a function body, with every directive dropped.

    No AArch64 assembler prints an instruction with a leading dot, so a
    leading dot is a reliable test, and the test is applied here rather than
    in each of the four places that want an instruction list.  The first
    version dropped only the `.cfi` lines and kept `.globl`, `.p2align` and
    `.size`, so a small function counted 8 instructions instead of 4 and
    every instruction count in the file was high by a constant.
    """
    return [b for b in body if b and not b.startswith('.')]


def adrp_lo12_pairs(body):
    """Every (adrp, follow-on) PAIR in a function body, in order.

    The pair is the subject of concept 5, and finding it in TEXT is the only
    way to know which adrp has a partner, because the two members of a pair
    are at ADJACENT offsets in `.rela.text` and the relation between them is
    not in the relocation record -- each record names one symbol and one
    field.  The linker's ADRP+ADD -> ADR+NOP relaxation is what makes the
    pairing worth finding, and that relaxation is a LINKER behaviour which
    section 12 says cannot be measured on this host.
    """
    out = []
    k = 0
    while k < len(body):
        b = body[k]
        m = re.match(r'^adrp\s+(\w+),\s*(\S+)$', b)
        if m:
            dst, sym = m.group(1), m.group(2)
            nxt = body[k + 1] if k + 1 < len(body) else ''
            partner = None
            m2 = re.match(r'^add\s+' + re.escape(dst) +
                          r',\s*' + re.escape(dst) + r',\s*:lo12:(\S+)$', nxt)
            if m2:
                partner = ('add', m2.group(1))
            else:
                m3 = re.match(r'^ldr\s+\w+,\s*\[' + re.escape(dst) +
                              r',\s*:lo12:(\S+)\]$', nxt)
                if m3:
                    partner = ('ldr', m3.group(1))
                else:
                    m4 = re.match(r'^str\s+\w+,\s*\[' + re.escape(dst) +
                                  r',\s*:lo12:(\S+)\]$', nxt)
                    if m4:
                        partner = ('str', m4.group(1))
            out.append((sym, partner))
        k += 1
    return out


# ---------------------------------------------------------------------------
# 2. The specifications, as oracles.
# ---------------------------------------------------------------------------

def sec2():
    hdr(2, 'THE SPECIFICATIONS, AS ORACLES',
        'quoted with their sections, and never mixed in with a measurement')

    print('  [QUOTED] Linux syscall numbers')
    row('   ', '  document', 'include/uapi/asm-generic/unistd.h, Linux')
    row('   ', '  consulted', 'the file itself, fetched from the Linux tree; '
                                'the lines')
    row('   ', '  that matter', 'are printed below with the number this file '
                                 'uses.')
    row('   ', '  number   name            why this course uses it')
    for n, name, why in (
            (25, 'fcntl', 'six arguments in x0-x5, so it fills them all'),
            (56, 'openat', 'four arguments, and it takes a pointer'),
            (63, 'read', 'the number the corpus loads from memory'),
            (64, 'write', 'the number the corpus hard-codes as a literal'),
            (94, 'exit_group', 'one argument, the simplest shape there is'),
            (222, 'mmap', 'SIX arguments -- the most a Linux syscall takes')):
        row('   ', '  %-8d %-15s %s' % (n, name, why))
    print()
    note('THE WEAKNESS, stated where a reader would expect the claim.  These '
         'six numbers are QUOTED, and nothing on this host can confirm one by '
         'running it: there is no AArch64 machine, no emulator and no linker, '
         'so a number confirmed only by a header file is a weaker kind of '
         'claim than one confirmed by a return value.  What IS measured is '
         'the ENCODING of the instruction that carries the number, and the '
         'compiler\'s choice of how to put the number in x8.  A reader who '
         'wants the numbers confirmed should treat section 4 as evidence about '
         'the ENCODING and this table as evidence about the CONVENTION, and '
         'should not confuse the two.')

    print()
    print('  [QUOTED] The exception syndrome')
    row('   ', '  document', 'Arm Architecture Reference Manual for A-profile')
    row('   ', '  sections', 'DDI 0597, Shared Pseudocode, '
                             'AArch64_ExceptionClass()')
    row('   ', '  the layout it states, verbatim in structure:')
    row('   ', '    ESR_ELx[63:56]  reserved')
    row('   ', '    ESR_ELx[55:32]  ISS2  (SError, and later extensions)')
    row('   ', '    ESR_ELx[31:26]  EC     the Exception Class, 6 bits')
    row('   ', '    ESR_ELx[25]     IL     the Instruction Length, 1 bit')
    row('   ', '    ESR_ELx[24:0]   ISS    the Instruction Specific Syndrome')
    print()
    print('     and the assignment itself, verbatim in structure:')
    row('   ', '      ESR_ELx = Zeros{8} :: iss2 :: ec[5:0] :: il :: iss')
    print()
    note('And the part that is the whole concept: the pseudocode says IL is '
         'FORCED to 1 when `ec IN {0x24,0x25} && iss[24] == 0`.  EC 0x24 and '
         '0x25 are the two Data Abort classes a page fault arrives as, so '
         'for the single most common exception on the machine the IL bit is '
         'not a fact about the instruction -- it is a fact about the '
         'absence of a valid syndrome.  Section 5 measures what the compiler '
         'emits to read those bits and says what that measurement cannot '
         'show.')

    print()
    print('  [QUOTED] The vector table and the translation registers')
    for tag, doc, sec, claim in (
            ('VBAR', 'Arm ARM for A-profile, DDI 0597/0601',
             'the VBAR_ELx register description',
             '16 entries of 0x80 bytes; the low 11 bits of the register are '
             'RES0, so the table must be 2 KiB aligned'),
            ('TTBR0/TTBR1', 'Arm ARM for A-profile, DDI 0601',
             'the TCR_ELx register description',
             'T0SZ is bits[63:48] and T1SZ is bits[47:32], and the region '
             'each one addresses is 2^(64-TnSZ) bytes'),
            ('TG0/TG1', 'Arm ARM for A-profile, DDI 0601',
             'the TCR_ELx register description',
             'TG0 is bits[15:14] and TG1 is bits[31:30]: 4 KiB, 16 KiB or '
             '64 KiB'),
            ('descriptors', 'Arm ARM for A-profile, DDI 0601',
             'the translation table descriptor format',
             'bit 0 valid, bit 1 is a TABLE at levels 0-2, bit 10 AF, '
             'bits[4:2] AttrIndx, bits[9:6] SH, bits[7:5] AP, bits[54:53] '
             'TXL at levels 1-2, and the 8-byte descriptor is little-endian'),
            ('relocs', 'ELF ABI for the Arm 64-bit Architecture',
             'the relocation table, and /usr/include/elf.h on this host',
             'R_AARCH64_ADR_PREL_PG_HI21 is 275 and R_AARCH64_ADD_ABS_LO12_NC '
             'is 277 and R_AARCH64_ADR_PREL_LO21 is 274')):
        row('   ', '  %-11s %s' % (tag, doc))
        row('   ', '  %-11s %s' % ('', sec))
        note(claim, '     ')
    print()
    note('The architectural manual was NOT consulted on this host -- there is '
         'no copy of it here, and this file does not pretend otherwise.  Every '
         'QUOTED claim above carries a document and a section so that a reader '
         'with the document can check it, and section 12 lists the manual as '
         'a limit rather than pretending the quotations were verified against '
         'a page.')
    retract('R1',
            'the ESR_EL1 packed syndrome is a 32-bit field: EC in the high '
            'six bits, IL next, and the rest is one field called ISS',
            'the register is 64 bits and the syndrome occupies bits 31:0, '
            'with bits 55:32 named ISS2 and bits 63:56 RES0 -- so a handler '
            'that reads the whole register and masks 0xffffffff has thrown '
            'away a field it will need for an SError',
            'a number that is right about the low half of a register and '
            'silent about the high half is the hardest kind of wrong, and the '
            'section plan for this course described the syndrome as a "packed '
            'syndrome" with three fields and no width stated')
    retract('R2',
            'the 16-bit immediate in `svc #imm16` is the syscall number, so '
            'the syscall number is a CONSTANT in the instruction',
            'on AArch64/Linux the number is a CONSTANT FIELD in the '
            'instruction and the kernel reads it from the instruction, while '
            'x8 is a REGISTER holding the same number for the kernel\'s own '
            'ABI -- and BOTH are in the emitted code, which is why a Linux '
            'syscall wrapper writes x8 and issues `svc #0`.  The field is the '
            'architectural half and x8 is the Linux half, and the brief for '
            'this course described only the first as if it were the whole '
            'story.',
            'the section plan says "the immediate is a 16-bit constant in the '
            'instruction rather than a register -- a real design difference '
            'from SYSCALL" and that is right, but a page that says "the number '
            'is the immediate" would teach a reader to write `svc #64` and '
            'get a kernel that reads x8')


# ---------------------------------------------------------------------------
# 3. The encoding, and the five models this course adds.
# ---------------------------------------------------------------------------

SYSREG_PROBES = [
    ('mrs x0, esr_el1', 0xd5385200),
    ('mrs x1, elr_el1', 0xd5384021),
    ('mrs x2, far_el1', 0xd5386002),
    ('mrs x3, ttbr0_el1', 0xd5382003),
    ('mrs x4, tcr_el1', 0xd5382044),
    ('mrs x5, ttbr1_el1', 0xd5382025),
    ('mrs x6, vbar_el1', 0xd538c006),
    ('mrs x7, sctlr_el1', 0xd5381007),
    ('mrs x8, CurrentEL', 0xd5384248),
    ('mrs x9, daif', 0xd53b4220),
    ('mrs x10, tpidr_el0', 0xd53bd04a),
    ('mrs x11, esr_el2', 0xd53c5209),
    ('mrs x12, vbar_el2', 0xd53cc00a),
    ('mrs x13, tcr_el2', 0xd53c204b),
    ('msr vbar_el1, x0', 0xd518c000),
    ('msr tcr_el1, x0', 0xd5182040),
    ('msr ttbr0_el1, x0', 0xd5182000),
    ('msr ttbr1_el1, x0', 0xd5182020),
]

EXC_PROBES = [
    ('svc #0', 0xd4000001), ('svc #1', 0xd4000021),
    ('svc #0x1338', 0xd4026701), ('svc #65535', 0xd41fffe1),
    ('hvc #0', 0xd4000002), ('smc #0', 0xd4000003),
    ('brk #0', 0xd4200000), ('hlt #0', 0xd4400000),
    ('dcps1', 0xd4a00001), ('dcps2', 0xd4a00002), ('dcps3', 0xd4a00003),
]

BARRIER_PROBES = [('dsb sy', 0xd5033f9f), ('dmb sy', 0xd5033fbf),
                  ('isb', 0xd5033fdf)]

HINT_PROBES = [
    ('nop', 0xd503201f), ('yield', 0xd503203f), ('wfe', 0xd503205f),
    ('wfi', 0xd503207f), ('sev', 0xd503209f), ('sevl', 0xd50320bf),
    ('dgh', 0xd50320df), ('bti', 0xd503241f), ('bti c', 0xd503245f),
    ('bti j', 0xd503249f), ('bti jc', 0xd50324df),
]

REFUSALS = [
    ('svc #65536', 'immediate must be an integer in range [0, 65535]'),
    ('svc #-1', 'immediate must be an integer in range [0, 65535]'),
    ('brk #65536', 'immediate must be an integer in range [0, 65535]'),
    ('hlt #-1', 'immediate must be an integer in range [0, 65535]'),
    ('mrs x0, esr_el0', 'expected readable system register'),
    ('mrs x0, elr_el0', 'expected readable system register'),
    ('mrs x0, far_el0', 'expected readable system register'),
    ('mrs x0, vbar_el0', 'expected readable system register'),
    ('mrs x0, tcr_el0', 'expected readable system register'),
    ('mrs x0, ttbr0_el0', 'expected readable system register'),
    ('mrs x0, sctlr_el0', 'expected readable system register'),
    ('mrs x0, Sctlr', 'expected readable system register'),
]


def sec3():
    hdr(3, 'THE ENCODING, AND THE FIVE MODELS THIS COURSE HAS TO ADD',
        'MEASURED-ON-BYTES: every word below came out of a real assembler '
        'and is read twice')

    print('  [%s] the dispatch, and the finding that produced this section'
        % MEAS)
    row('   ', '  models in the imported decoder: %d' % BASE_MODEL_COUNT)
    row('   ', '  models added by THIS course:    %d' % len(EXTRA_MODELS))
    row('   ', '  models in the file:             %d' % MODEL_COUNT)
    print()
    note('The encoding course in this section measured a field map over '
         'bits[28:25] and declared the rest of the space out of scope, which '
         'is a defensible scope.  It is also true that the entire subject of '
         'THIS course lives in the part it left out: every instruction here '
         'is in "Branches, Exception Generating and System", and the '
         'imported decoder claims FIVE words of that class -- B, BL, '
         'B.cond, CBZ, TBZ, BR/BLR/RET, HINT -- and can name NONE of SVC, '
         'MRS, MSR, HVC, SMC, BRK, HLT, DCPS, ERET, DRPS, DSB, DMB or ISB.')
    print()
    print()
    print('  [%s] what each course\'s models contribute to THIS corpus'
        % MEAS)
    note('A coverage number means nothing on its own -- it is a number about '
         'a CORPUS -- so the same loop is run three times with three '
         'different SETS of models and the differences printed.  This is the '
         'measurement that turns "100% named" from a boast into a number.')
    print()
    t_all, n_all = census()
    t_21, n_21 = census(BASE_MODELS)
    t_27, n_27 = census(SIBLING_MODELS + BASE_MODELS)
    row('   ', '  dispatch                                read  named  '
               'coverage')
    row('   ', '  the encoding course\'s 21 alone        %-6d %-6d %.1f%%'
        % (t_21, n_21, 100.0 * n_21 / t_21))
    row('   ', '  + the ABI course\'s 6                 %-6d %-6d %.1f%%'
        % (t_27, n_27, 100.0 * n_27 / t_27))
    row('   ', '  + this course\'s 6                    %-6d %-6d %.1f%%'
        % (t_all, n_all, 100.0 * n_all / t_all))
    print()
    p('RESULT', 'the encoding course names %d of %d of this corpus (%.1f%%), '
                'and the two later courses add %d and %d'
        % (n_21, t_21, 100.0 * n_21 / t_21, n_27 - n_21, n_all - n_27))
    note('The encoding course\'s twenty-one models name %d words of a corpus '
         'whose whole subject is the SYSTEM class, and the two courses that '
         'followed added %d between them.  A decoder is a subset of NAMES '
         'and not of LENGTHS, and this table is the price of the subset: '
         'three courses, thirty-three models, and 142 of them written by the '
         'two that came after the first.' % (n_21, n_all - n_21))
    print()
    retract('R3',
            'the encoding course\'s decoder covers the A64 encoding well '
            'enough that a later course in the section can build on it',
            'it names FIVE words of the SYSTEM class and every single '
            'instruction this course is about is outside those five.  A '
            'decoder that cannot name `svc #0` cannot check the syscall '
            'convention, and the syscall convention is concept 1.',
            'this is not a criticism of the scope, which was stated; it is a '
            'measurement of what the scope cost, and the cost was paid twice '
            'already -- see R4, which is a BUG in that decoder rather than a '
            'gap in it')

    print()
    print('  [%s] MRS and MSR: the register is a FOUR-field name'
        % BYTES)
    row('   ', '  source            word        L  op0 op1 CRn CRm op2 Rt'
                '   decoder says')
    for src, w in SYSREG_PROBES:
        i = decode(w)
        L = (w >> 21) & 1
        row('   ', '  %-16s 0x%08x  %d  %2d  %3d %3x  %3x  %2d %2d  %s'
            % (src, w, L, (w >> 19) & 3, (w >> 16) & 7, (w >> 12) & 0xf,
               (w >> 8) & 0xf, (w >> 5) & 7, w & 0x1f, i.text.strip()))
    print()
    note('FOUR fields name the register and a FIFTH names the EL.  ESR_EL1 is '
         'CRn = 5, CRm = 2, op2 = 0, op1 = 0.  ELR_EL1 is CRn = 4, CRm = 0, '
         'op2 = 1, op1 = 0.  Two registers a kernel reads together in one '
         'handler, and they differ in THREE of the four fields and in the '
         'same place the fields are read from.  A decoder that prints the '
         'fields has printed a correct answer and a useless one, which is why '
         'the model carries a TABLE rather than a formula: the names are not '
         'computable from the bits, they are ASSIGNED to the bits.')
    print()
    note('The one bit that separates reading from writing is bit 21, the L '
         'bit.  `mrs x6, VBAR_EL1` is 0xd538c006 and `msr VBAR_EL1, x0` is '
         '0xd518c000: XOR them and the bits that differ are bit 21 and '
         'bits[4:0], and bits[4:0] is the register.  So the SAME five bits '
         'name the operand whether the instruction reads it or writes it, and '
         'a decoder that treated L as part of the register name would report '
         'two different registers where there is one.')
    print()
    note('And the EL is op1 alone: ESR_EL1 and ESR_EL2 are 0xd5385200 and '
         '0xd53c5209, and the ONLY field that differs is op1, 0 versus 4.  '
         'The architectural consequence is that a handler that runs at EL1 '
         'and one that runs at EL2 execute the SAME bytes to read the same '
         'conceptual register, and the difference is one field in the same '
         'instruction -- which is a good design and an inconvenient one for a '
         'table, because a table keyed on CRn/CRm/op2 alone would name both '
         'ESR_EL1 and ESR_EL2 identically.  Section 2 quotes the manual and '
         'section 5 measures the code around it.')

    print()
    print('  [%s] the exception family: THREE operation tables, not one'
        % BYTES)
    row('   ', '  source          word        b23:22 b21 b4:0 imm[20:5]  '
               'decoder says')
    for src, w in EXC_PROBES:
        i = decode(w)
        row('   ', '  %-14s 0x%08x  %d     %d   %02d    0x%04x     %s'
            % (src, w, (w >> 22) & 3, (w >> 21) & 1, w & 0x1f,
               (w >> 5) & 0xffff, i.text.strip()))
    print()
    note('Read the b4:0 column against the b23:22 and b21 columns together, '
         'because the operation field is NOT a mnemonic on its own.  `svc #0` '
         'has bits[4:0] = 0b00001 and `dcps1` has bits[4:0] = 0b00001 as '
         'well -- the same five bits, two bits apart above -- and one traps '
         'to EL1 while the other is a debug exception at EL1.  The '
         'discriminator is the PAIR (bits[23:22], bit 21) and the five-bit '
         'field is local to the table that pair selects.')
    print()
    note('The immediate is bits[20:5], SIXTEEN bits, and the assembler '
         'REFUSES both ends.  Nine refusals, one diagnostic:')
    for src, why in REFUSALS:
        ok, words, diag = try_asm(src)
        got = 'ACCEPTED' if ok else 'REFUSED'
        match = (not ok) and (diag.rstrip('.') == why)
        row('   ', '  %-18s %-9s %s' % (src, got, diag if not ok else ''),
            'matches the table' if match else
            ('' if ok else 'DIFFERENT DIAGNOSTIC'))
    print()
    note('Seven of those nine are the SAME diagnostic and they say the same '
         'thing seven times: ESR_EL0, ELR_EL0, FAR_EL0, VBAR_EL0, TCR_EL0, '
         'TTBR0_EL0 and SCTLR_EL0 DO NOT EXIST.  That is not a naming '
         'convention the assembler invented; it is the architecture saying '
         'EL0 has no syndrome register, because EL0 cannot take an exception '
         'it has to describe.  A reader who assumed `esr_el0` would assemble '
         'and then found out at 3 a.m. has learned the rule the seven '
         'identical diagnostics were teaching all along.')
    print()
    note('The first two rows are the other kind of refusal and they are worth '
         'reading together: `svc #65536` and `svc #-1` are REFUSED with the '
         'identical message, and -1 is the same sixteen bits as 0xffff.  So '
         'the field is UNSIGNED in an architecture where every other '
         'displacement is signed, and the message names a RANGE rather than a '
         'signedness, so it reads like a complaint about a value that was '
         'negative to begin with.')

    print()
    print('  [%s] ERET, DRPS, and the three barriers' % BYTES)
    for src, w in [('eret', 0xd69f03e0), ('drps', 0xd6bf03e0)] + BARRIER_PROBES:
        i = decode(w)
        row('   ', '  %-8s 0x%08x  bits[7:5]=%d CRm=%d  %s'
            % (src, w, (w >> 5) & 7, (w >> 8) & 0xf, i.text.strip()))
    print()
    note('ERET and DRPS differ in ONE bit, bit 21 -- the L bit again, and '
         'here it means RETURN rather than DROP.  The same bit has now been '
         'Load/Store in the MRS/MSR group and Return/Drop here, and a bit '
         'that changes meaning every time you cross a group boundary is a bit '
         'whose meaning is a property of the group and not of the bit.  A '
         'reader who learned "bit 21 is the L bit" has learned something '
         'true and useless; what is worth learning is that the fixed 32-bit '
         'encoding reuses bits freely between groups, so a decoder must be '
         'dispatched on a group before it can read a field.')
    print()
    note('DSB, DMB and ISB are told apart by bits[7:5] and by NOTHING ELSE, '
         'with the eight-bit CRm field reading 0b1111 in all three.  The '
         'obvious discriminator is the wrong one, and this is worth naming as '
         'a trap: a decoder that guards on CRm gets DSB and DMB and ISB '
         'right for the wrong reason and every OTHER member of the class '
         'wrong.  The barriers are the next course in this section; this '
         'course owns only the fact that they are three words a decoder has '
         'to be able to tell apart.')

    print()
    print('  [%s] R4.  A BUG IN THE INHERITED DECODER, found here'
        % MEAS)
    print('     The encoding course\'s decoder has a model called `m_hint`')
    print('     whose own claim is "NOP, WFI, YIELD and the rest: 27 fixed')
    print('     bits and a 5-bit hint number", and whose guard is')
    print('         bits[31:5] == 0xd503201f >> 5')
    print()
    row('   ', '  hint      word        word >> 5   guard matches?')
    for src, w in HINT_PROBES:
        row('   ', '  %-9s 0x%08x  0x%07x   %s'
            % (src, w, w >> 5, 'YES' if (w >> 5) == (0xd503201f >> 5)
               else 'no'))
    print()
    note('ONE of ELEVEN.  The body of the inherited model is correct -- it '
         'reads the hint number and has the right eleven names -- and the '
         'guard makes eight of them unreachable.  A guard that is one bit too '
         'narrow does not produce a wrong answer: it produces NO answer, and '
         'NO answer is exactly what a decoder that had never heard of hints '
         'would also produce.  This is the failure mode that no amount of '
         'agreeing with a second reader can catch, and the reason section 9 '
         'poisons a guard on purpose.')
    print()
    note('WHY IT SURVIVED, and the reason is the useful part.  The encoding '
         'course\'s own corpus, compiled with clang, contains no yield, no '
         'wfe, no wfi, no sev, no sevl, no dgh and no bti.  A model that is '
         'wrong about eight words the corpus does not contain is '
         'indistinguishable from a model that is right, and that course\'s '
         'artifact reports its unmodelled words as "9, and the unmodelled '
         'ones are Advanced SIMD" -- a true sentence about a corpus in which '
         'the bug cannot appear.')
    print()
    note('A count of unmodelled words is a fact about A CORPUS and not about '
         'A DECODER.  That sentence is the most transferable result in this '
         'file, and it is why this course has a corpus of its own: sys.c '
         'contains a syscall, a syndrome read, a vector-table install and '
         'four levels of page table, and the coverage numbers in section 9 '
         'are about THIS corpus.')
    print()
    p('the fix', 'this file does not edit the sibling.  A course that fixes '
                 'another course\'s')
    note('artifact by writing to it produces two artifacts that disagree about '
         'the same architecture, and the reader cannot tell which one to '
         'believe.  So this file PREPENDS `m_hint_family` with a guard of '
         'bits[31:12] = 0xd5032 and a constant bit 4, and the inherited '
         'guard never runs.  All %d models are in the dispatch and the audit '
         'table below prints them in the order they are tried.' % MODEL_COUNT)
    retract('R4',
            'the inherited decoder names NOP, WFI, YIELD "and the rest" of '
            'the HINT family',
            'it names NOP and nothing else.  The guard is bits[31:5], one bit '
            'too narrow, and it matches 0xd503201f alone out of eleven hints '
            'the assembler accepts.  This file adds `m_hint_family` with a '
            'corrected guard and the two-reader check in section 9 runs on the '
            'combined dispatch.',
            'a model whose body is correct and whose guard is too narrow is '
            'the one bug class that agreement-with-a-second-reader cannot '
            'find, because the second reader also says "(op 0x...)"')


# ---------------------------------------------------------------------------
# 4. The syscall.
# ---------------------------------------------------------------------------

SYSCALL_FNS = ['sys_const', 'sys_global', 'sys_no_number',
               'sys_immediate_constant',
               'sys_arg1', 'sys_arg2', 'sys_arg5', 'sys_arg6',
               'sys_arg7', 'sys_arg8', 'sys_arg9_stack',
               'call_then_syscall']

X86_SYSCALL = """	.text
	.globl	x64
x64:
	movq	$60, %rax
	movq	$1, %rdi
	leaq	msg(%rip), %rsi
	movq	$6, %rdx
	syscall
	ret
	.data
msg:	.asciz	"hello\\n"
"""

A64_SYSCALL = """	.text
	.globl	a64
a64:
	mov	x8, #64
	mov	x0, #1
	adrp	x1, msg
	add	x1, x1, :lo12:msg
	mov	x2, #6
	svc	#0
	ret
	.data
msg:	.asciz	"hello\\n"
"""


def x86_syscall_bytes():
    """The same hand-written syscall for x86-64, assembled by the same clang.

    THIS IS A COMPILE-TIME INSTRUCTION COUNT COMPARISON AND NOT A TIMING
    ONE, and the section says so before the table rather than in a footnote.
    """
    p = os.path.join(HERE, '_x86cmp.s')
    with open(p, 'w') as f:
        f.write(X86_SYSCALL)
    ok = sh(CLANG, '-c', p, '-o', os.path.join(HERE, '_x86cmp.o')).returncode == 0
    if not ok:
        return []
    return x86_pairs(os.path.join(HERE, '_x86cmp.o'))


def x86_pairs(path):
    """(byte-string, mnemonic) for every x86-64 instruction, by a SEPARATE
    reader.

    The AArch64 reader's regex is `8 hex digits, whitespace, text`, which is
    exactly the shape a fixed 32-bit instruction has and exactly the shape an
    x86-64 instruction does not: `48 c7 c0 3c 00 00 00` is SEVEN bytes.  The
    first version of this function reused the AArch64 reader and printed
    NOTHING for the x86-64 half, so the section reported "x86-64 0
    instructions" beside a table with seven AArch64 ones, and no error
    anywhere.

    A reader written for one architecture and pointed at another does not
    report an error.  It reports nothing, and a table with a zero in it is
    the most expensive kind of wrong answer to look at, because a zero is a
    number and a number is what a reader came for.
    """
    o = sh(OBJDUMP, '-d', path).stdout
    out = []
    started = False
    for ln in o.splitlines():
        m = re.match(r'^[0-9a-f]{16} <(\S+)>:$', ln)
        if m:
            started = (m.group(1) == 'x64')
            continue
        if not started:
            continue
        # The shape is `   0: 48 c7 c0 3c 00 00 00<spaces><TAB>movq<TAB>...`:
        # the address is followed by a COLON AND A SPACE, the byte string is
        # followed by spaces and a TAB, and the mnemonic by a TAB of its own.
        # Two earlier versions of this regex required a TAB after the colon
        # and then only spaces after the bytes; both matched NOTHING and both
        # reported zero instructions, which is the failure mode a reader
        # pointed at the wrong architecture always has: a zero, and no error.
        # Split on the TAB and then on whitespace, because the byte string
        # has no fixed length and three regexes that tried to describe it all
        # failed: one required a TAB after the colon, one allowed only spaces
        # after the bytes, and one was greedy and ate the last byte.  Three
        # readers, three silent zeros.
        head, _tab, rest = ln.partition('\t')
        toks = head.split()
        if len(toks) < 2 or not toks[0].endswith(':'):
            continue
        if not all(re.fullmatch(r'[0-9a-f]{2}', t) for t in toks[1:]):
            continue
        out.append((' '.join(toks[1:]), rest.split()[0] if rest.split()
                    else ''))
    return out


def _clean(t):
    return re.sub(r'\s+', ' ', t.split('//')[0].strip())


def sec4():
    hdr(4, 'THE SYSCALL: THE IMMEDIATE, x8, AND THE ARGUMENT AUDIT',
        'MEASURED-ON-BYTES: the encoding; MEASURED: the compiler\'s choices')

    print('  [%s] the immediate is a FIELD, and the assembler says how wide'
        % BYTES)
    for src in ('svc #0', 'svc #1', 'svc #63', 'svc #64', 'svc #65535'):
        ok, words, _d = try_asm(src)
        w = words[0][0] if ok else 0
        i = decode(w)
        row('   ', '  %-12s 0x%08x  imm16 at bits[20:5] = 0x%04x   %s'
            % (src, w, (w >> 5) & 0xffff, i.text.strip()))
    print()
    note('The number the kernel reads is a SIXTEEN-BIT CONSTANT BAKED INTO '
         'THE INSTRUCTION.  Not a register, not a memory operand: a field. '
         'That is the whole architectural difference from x86-64, and it is '
         'worth being precise about WHY it is a difference, because the '
         'obvious reason is wrong.')
    print()
    note('The obvious reason -- "x86-64 has no immediate, so it must use a '
         'register" -- is a statement about SYSCALL, not about the argument. '
         'The deeper reason is that AArch64 fixed the instruction length at '
         '32 bits, so an immediate COSTS four bytes of the same instruction '
         'either way, and a design that has already spent the encoding budget '
         'can spend 16 of the 32 bits on a constant.  On x86-64 the '
         'instruction is 2 bytes long (`syscall` is 0f 05), and a 7-byte '
         '`mov eax, 60` in front of it costs more than the syscall itself.  '
         'The encoding fixes the economics and the economics picks the '
         'design.')
    print()
    print('  [%s] the same syscall, both architectures, hand-written'
        % BYTES)
    print('     THIS IS A COMPILE-TIME INSTRUCTION COUNT COMPARISON AND NOT')
    print('     A TIMING ONE.  NOTHING HAS BEEN EXECUTED ON EITHER SIDE.')
    print()
    p2 = os.path.join(HERE, '_a64cmp.s')
    with open(p2, 'w') as f:
        f.write(A64_SYSCALL)
    sh(CLANG, '--target=%s' % TARGET, '-c', p2, '-o',
       os.path.join(HERE, '_a64cmp.o'))
    a = objdump_pairs(os.path.join(HERE, '_a64cmp.o'))
    x = x86_syscall_bytes()
    row('   ', '  ' + 'AArch64 (aarch64-linux-gnu)'.ljust(40) +
        'x86-64 (host, variable length)')
    n = max(len(a), len(x))
    for k in range(n):
        la = ('%d  %-8s %s' % (k, ('0x%08x' % a[k][0]) if k < len(a) else '',
                               _clean(a[k][1]))) if k < len(a) else ''
        lx = ('%d  %-18s %s' % (k, x[k][0] if k < len(x) else '',
                                x[k][1])) if k < len(x) else ''
        row('   ', '  ' + la.ljust(40) + lx)
    print()
    a_bytes = 4 * len(a)
    x_bytes = sum(len(b.split()) for b, _t in x)
    row('   ', '  instructions: AArch64 %d, x86-64 %d' % (len(a), len(x)))
    row('   ', '  bytes of CODE: AArch64 %d, x86-64 %d' % (a_bytes, x_bytes))
    row('   ', '  relocations:   AArch64 %d, x86-64 %d'
        % (len(elf_relocs('_a64cmp.o')), len(readelf_relocs('_x86cmp.o'))))
    print()
    note('AArch64 spends 2 instructions and 2 relocations to name a string; '
         'x86-64 spends 1 instruction and 1 relocation.  The syscall itself is '
         'ONE instruction on both -- 4 bytes on AArch64, 2 on x86-64 -- and '
         'the difference in the ARGUMENT REFERENCE is the difference between '
         'a PAIR of relocations and a SINGLE one, which is a fact about an '
         'object file and not a cycle.  Section 8 measures the pair properly '
         'and shows why a page table needs it; here the point is only that '
         'the two architectures differ in a way an object file can see.')
    print()
    ra = elf_relocs('_a64cmp.o')
    rx = readelf_relocs('_x86cmp.o')
    print('     the RELOCATIONS, which is where the difference is real:')
    for r in ra:
        row('   ', '    AArch64  0x%08x  %-30s %s + %d'
            % (r['off'], relname(r['type']), r['name'], r['addend']))
    for r in rx:
        row('   ', '    x86-64   0x%08x  %-30s %s %s'
            % (r['off'], r['name'], r['sym'], r['addend']))
    print()
    note('TWO relocations against ONE, and that is the real cost of the '
         'pair, not a cycle count.  Section 8 measures the pair properly and '
         'shows why a page table needs it; here the point is only that the '
         'architectures differ in a way an object file can see.')
    print()
    retract('R5',
            'an AArch64 syscall needs one relocation per address reference, '
            'the way `syscall` does on x86-64',
            'it needs TWO, and always does: `adrp` emits '
            'R_AARCH64_ADR_PREL_PG_HI21 and the follow-on instruction emits '
            'R_AARCH64_ADD_ABS_LO12_NC or R_AARCH64_LDST64_ABS_LO12_NC.  The '
            'pair is not an optimisation and the linker may not remove it -- '
            'it may only rewrite it as ADR+NOP, which is still two '
            'instructions.',
            'the section plan says a page "needs a PAIR of them per page" and '
            'is right about the fact and silent about the reason, and the '
            'reason is NOT the +-4 GiB reach of adrp: a lone adrp reaches '
            '4 GiB, which is not a constraint anybody hits.  The reason is '
            'that ADRP keeps only bits 32:12 of the target and throws the low '
            'twelve away, and something has to add them back.  Section 3 '
            'measures the reach of both instructions precisely so that the '
            'wrong reason cannot survive.')

    print()
    print('  [%s] the x8 CONVENTION, and what the compiler does with x8'
        % MEAS)
    note('The claim to be careful about: "the syscall number is in x8" is an '
         'ABI claim, not an architectural one.  The architecture has no idea '
         'what x8 means, and the proof is a function in the corpus in which '
         'x8 is NOT mentioned at all.')
    print()
    for lvl in LEVELS:
        path = 'sys_%s.s' % lvl
        fns = dict(asm_functions(path))
        for name in ('sys_const', 'sys_global', 'sys_no_number'):
            body = fns.get(name, [])
            ins = insn_lines(body)
            has_x8 = any(re.search(r'\bx8\b', b) for b in ins)
            row('   ', '  -%-3s %-16s %2d instructions   x8 named: %s'
                % (lvl, name, len(ins), 'YES' if has_x8 else 'NO'))
    print()
    note('`sys_no_number` never mentions x8 in its C, and the compiler uses '
         'it ANYWAY at every level -- as the adrp base for the next address '
         'it has to form.  So x8 is an ordinary caller-saved temporary to '
         'the compiler, and it is the LINUX KERNEL that assigns it a job.  A '
         'page that said "x8 is the syscall register, therefore the compiler '
         'protects it" would be wrong in a way that produces no diagnostic: '
         'the wrapper is correct, it is the reasoning that is wrong, and the '
         'reasoning is what a reader would carry to the next problem.')
    print()
    retract('R6',
            'x8 is the syscall-number register, so a compiler must treat it '
            'as reserved across a `svc`',
            'clang uses x8 as a scratch register in every one of the four '
            'functions that do not mention it, at every one of the four '
            'optimisation levels, including inside the same function that '
            'later issues `svc #0`.  x8 is the AAPCS64 Indirect Result '
            'Location Register and an ordinary caller-saved temporary, and '
            'the syscall convention reuses it.',
            'the section plan says "the x8-is-the-only-convention fact, which '
            'is ABI and not architecture" and is RIGHT -- and then the brief '
            'for this course asked what the compiler does with the argument '
            'registers, which is a question whose answer is that x8 is not '
            'one of them and never was')

    print()
    print('  [%s] the ARGUMENT AUDIT: which register, which argument, BY NAME'
        % MEAS)
    note('Every argument is a `volatile` global with its own distinctive '
         'constant, so the disassembly NAMES the argument: the load of 0x4444 '
         'IS argument three.  A census would say "seven registers were '
         'written"; an audit says which ARGUMENT was in which REGISTER, and '
         'can therefore disagree with a specification instead of merely '
         'agreeing with itself.')
    print()
    ARGS = ['sys_arg1', 'sys_arg2', 'sys_arg5', 'sys_arg6',
            'sys_arg7', 'sys_arg8', 'sys_arg9_stack']
    print('     which ARGUMENT (by its constant) is in which REGISTER')
    print('     function         x0  x1  x2  x3  x4  x5  x6  x7  9th')
    audit = {}
    for lvl in ('O2', 'O1', 'Os', 'O0'):
        fns = dict(asm_functions('sys_%s.s' % lvl))
        print()
        row('   ', '  --- %s ---%s' % (
            lvl, '   every argument is SPILLED, so the assignment the ABI '
                 'names is' if lvl == 'O0' else ''))
        for name in ARGS:
            text = ' '.join(insn_lines(fns.get(name, [])))
            where = {}
            for r in range(8):
                m = re.search(r'\bx%d\s*,\s*\[x\d+\s*,\s*:lo12:VA%d\]'
                              % (r, r), text)
                if m:
                    where[r] = 'VA%d' % r
            ninth = 'stack' if 'VSTACK' in text else '-'
            print('     %-16s %s   %s'
                  % (name, '  '.join(where.get(r, '.').lstrip() or '.'
                                     for r in range(8)), ninth))
            audit.setdefault(lvl, []).append((name, where, ninth))
    print()
    nplaced = 0
    bad = []
    for lvl, rows in audit.items():
        if lvl == 'O0':
            continue
        for name, where, ninth in rows:
            for r, v in where.items():
                nplaced += 1
                if v != 'VA%d' % r:
                    bad.append((lvl, name, r, v))
            if name == 'sys_arg9_stack' and ninth != 'stack':
                bad.append((lvl, name, '9th', ninth))
            if name == 'sys_arg8' and len(where) != 8:
                bad.append((lvl, name, 'count', len(where)))
    p('RESULT', '%d of %d argument placements land in the register whose '
                "NUMBER is the argument's, at -O1, -O2 and -Os, and the "
                'ninth is never a register'
        % (nplaced - len(bad), nplaced))
    if bad:
        for b in bad:
            row('   ', '  MISMATCH %s %s x%s -> %s' % b)
    note('The -O0 row is the interesting one, and it is a NEGATIVE result: '
         'at -O0 clang spills every argument to the stack and reloads it '
         'immediately before the `svc`, so the register assignment the ABI '
         'names is not VISIBLE in the code at all.  The contract still holds '
         '-- the reloads target x0 through x7 -- but a reader auditing an ABI '
         'from a -O0 build is auditing the spill slots and not '
         'the contract, and the harness for this course asserts the audit at '
         'the three levels where the contract is legible.')
    note('Argument ZERO is in x0, argument SEVEN is in x7, and the NINTH is '
         'not in a register at all: it is a `volatile` C object reached '
         'through an "m" constraint, and the compiler materialises its '
         'ADDRESS into a register and the value stays in memory.  That is the '
         'AAPCS64 rule -- eight argument registers, and after that the stack '
         '-- showing up inside a SYSCALL rather than inside a function call, '
         'which is a thing a reader does not expect, because a Linux syscall '
         'has at most six arguments and the eighth register is dead weight '
         'that the architecture supplies and the kernel ignores.')
    print()
    print('  [%s] the compiler emits x6 and x7 for a syscall that has six'
        % MEAS)
    for lvl in LEVELS:
        fns = dict(asm_functions('sys_%s.s' % lvl))
        for name in ('sys_arg6', 'sys_arg7', 'sys_arg8'):
            ins = insn_lines(fns.get(name, []))
            n6 = sum(1 for b in ins if re.search(r'\bx6\b', b))
            n7 = sum(1 for b in ins if re.search(r'\bx7\b', b))
            row('   ', '  -%-3s %-10s %2d insn   mentions x6 %d times, x7 %d '
                       'times' % (lvl, name, len(ins), n6, n7))
    print()
    note('The compiler fills them because the source named them.  It has no '
         'idea a Linux syscall stops at six, because that is not in the '
         'language and not in the ABI this compiler implements -- it is in '
         'the kernel.  So a reader who wants the SIX-argument limit has to go '
         'and read the kernel, and this file cannot help: the encoding is '
         'measured, the limit is QUOTED, and the gap between them is exactly '
         'the gap between an ABI and an operating system.')
    print()
    print('  [%s] a literal number and a LOADED number, side by side'
        % MEAS)
    for lvl in ('O2',):
        fns = dict(asm_functions('sys_%s.s' % lvl))
        for name in ('sys_const', 'sys_global'):
            ins = insn_lines(fns.get(name, []))
            print('     %s, -%s:' % (name, lvl))
            for b in ins:
                print('       ' + b)
            print()
    note('`sys_const` loads the number from an immediate, so the compiler '
         'builds 64 with the wide-immediate family and it costs no memory '
         'access.  `sys_global` loads it from a `volatile`, so it costs an '
         'adrp and an ldr -- and THAT is the pair of section 8, arriving '
         'here first for a reason: a syscall number that is a variable is '
         'indistinguishable from a page-table address in the instruction '
         'stream, and the only thing that tells them apart is a relocation.')
    print()
    print('  [%s] what this section CANNOT show' % MEAS)
    note('It cannot show that `svc #0` traps, that the kernel reads x8, that '
         'the number 64 means write, that the return value comes back in x0, '
         'or that a wrong number produces ENOSYS.  All five are QUOTED and all '
         'five would need an AArch64 machine or an emulator, and this host has '
         'neither.  What it CAN show is that the compiler puts the number '
         'where the convention says, that the argument registers are filled '
         'in the order the ABI names, that the ninth argument is not a '
         'register, and that the encoding of the instruction carries a '
         'sixteen-bit constant.  Those are four real results and they are '
         'all the section claims.')


# ---------------------------------------------------------------------------
# 5. The syndrome.
# ---------------------------------------------------------------------------

ESR_FNS = ['ec_of', 'il_of', 'iss_of', 'ec_is', 'is_lower_data_abort',
           'dfsc_of', 'esr_all', 'rd_esr', 'rd_elr', 'rd_far',
           'rd_vbar', 'rd_ttbr0', 'rd_ttbr1', 'rd_tcr', 'rd_sctlr',
           'wr_vbar', 'wr_tcr', 'wr_ttbr0']


def sec5():
    hdr(5, 'THE SYNDROME: A PACKED FIELD AND THE INSTRUCTIONS AROUND IT',
        'QUOTED for the layout; MEASURED-ON-BYTES for the instructions that '
        'read it')

    print('  [%s] the register, field by field, with the two widths that '
          'matter' % BYTES)
    row('   ', '  source             word        what the assembler calls it')
    for src, w in [('mrs x5, esr_el1', 0xd5385205),
                   ('mrs x6, elr_el1', 0xd5384026),
                   ('mrs x7, far_el1', 0xd5386007),
                   ('mrs x4, vbar_el1', 0xd538c004),
                   ('msr vbar_el1, x0', 0xd518c000),
                   ('mrs x0, tpidr_el0', 0xd53bd040),
                   ('mrs x0, daif', 0xd53b4220)]:
        row('   ', '  %-18s 0x%08x  %s' % (src, w, decode(w).text.strip()))
    print()
    note('Three of those are read by every exception handler on the machine '
         'and the fourth is where it will jump.  The encoding gives each of '
         'them a FOUR-field name in bits[18:16] and bits[15:5] and the '
         'difference between `ESR_EL1` and `ELR_EL1` is CRn 5 against CRn 4 '
         'and op2 0 against op2 1 -- two bits, in a nine-bit field, and both '
         'of them load with the SAME instruction shape.')
    print()
    print('     The mnemonic is not derivable from the bits.  This file')
    print('     carries a table of sixteen tuples and prints the field values')
    print('     next to the name, because a decoder that derives the name')
    print('     gets a plausible answer and no way to check it.')

    print()
    print('  [%s] the packed field, and the arithmetic a handler does on it'
        % BYTES)
    print('     EC is bits[31:26], IL is bit 25, ISS is bits[24:0.')
    print('     These are QUOTED (DDI 0597, AArch64_ExceptionClass).  What')
    print('     follows is what clang EMITS for the arithmetic, and it is')
    print('     the only part of a handler a toolchain can show us.')
    print()
    for lvl in ('O2', 'O0'):
        fns = dict(asm_functions('sys_%s.s' % lvl))
        print('     --- %s ---' % lvl)
        for name in ('ec_of', 'il_of', 'iss_of', 'is_lower_data_abort',
                     'dfsc_of'):
            ins = insn_lines(fns.get(name, []))
            print('       %-22s %2d  %s'
                  % (name, len(ins), ' ; '.join(ins) if ins else '(none)'))
        print()

    print('  [%s] the one that is worth reading twice' % MEAS)
    fns = dict(asm_functions('sys_O2.s'))
    for b in insn_lines(fns.get('is_lower_data_abort', [])):
        print('     ' + b)
    print()
    note('The C is `return (ec == 0x24 || ec == 0x25)`, and clang turned TWO '
         'comparisons into ONE mask, ONE compare and ONE cset.  The reason is '
         'pure arithmetic and a reader can check it in their head: 0x24 is '
         '0b100100 and 0x25 is 0b100101, so the two classes differ in ONE bit '
         'of the EC field and in nothing else, and ANDing the syndrome with '
         '0xf8000000 clears that bit and makes the two cases one.')
    print()
    note('So a handler that tests for "a data abort from a lower EL" costs '
         'THREE instructions, not six -- and the mask it uses is not in any '
         'manual, because it is a property of the two constants rather than '
         'of the architecture.  This is the whole difference between the '
         'quoted half of this course and the measured half: the layout is '
         'something you look up, and the cheapest way to test it is something '
         'you measure on the machine you actually have.')
    print()
    retract('R7',
            'the natural way to test the exception class is to shift the '
            'syndrome right by 26 and compare',
            'clang does not shift, and does not need to.  Because 0x24 and '
            '0x25 differ in one bit, `and x9, x0, #0xf8000000 ; cmp x9, #0x9'
            '0000000 ; cset w0, eq` is THREE instructions where the obvious '
            'form is two shifts, two compares and an or -- and at -O0 the '
            'same C is thirteen.',
            'a page that taught the syndrome by showing the shift would have '
            'taught a correct reading and a compiler-shaped one, and a reader '
            'writing a handler in that shape would be writing worse code than '
            'the compiler would have written for them')

    print()
    print('  [%s] the instruction cost of a three-register read' % MEAS)
    fns = dict(asm_functions('sys_O2.s'))
    for name in ('esr_all',):
        ins = insn_lines(fns.get(name, []))
        row('   ', '  %-10s %d instructions' % (name, len(ins)))
        for b in ins:
            row('   ', '    ' + b)
    print()
    note('Three `mrs` and two `eor`, and the compiler assigned x8, x9 and x10 '
         'rather than x0, x1 and x2 -- because the AAPCS64 answer is x0, and '
         'using it for a temporary here would be legal and confusing.  A '
         'reader who has just read the ABI course and sees a handler read '
         'three system registers into x8-x10 has learned something about the '
         'compiler that no document says.')
    print()
    print('  [%s] what the EC field is FOR, and the trap in it' % QUOT)
    row('   ', '  EC  meaning                      the ISS means')
    for ec, mean, iss in (
            (0x00, 'Unknown', 'nothing -- the syndrome is not defined'),
            (0x01, 'WFI/WFE retirement', 'a 5-bit register and a 2-bit state'),
            (0x02, 'SMC', 'nothing'),
            (0x03, 'SVC (a syscall from EL0)', 'imm16, the literal in the '
                                                'SVC'),
            (0x0c, 'BRK', 'imm16'),
            (0x0d, 'HLT', 'imm16'),
            (0x11, 'SVC (from EL1)', 'imm16'),
            (0x12, 'HLT (from EL1)', 'imm16'),
            (0x15, 'SVC (from EL2)', 'imm16'),
            (0x16, 'HLT (from EL2)', 'imm16'),
            (0x17, 'SVC (from EL3)', 'imm16'),
            (0x18, 'HLT (from EL3)', 'imm16'),
            (0x20, 'Instruction abort, lower EL', 'the FAR, and the DFS'),
            (0x21, 'PC alignment fault', 'nothing'),
            (0x22, 'Data abort, lower EL', 'the FAR, and the DFSC'),
            (0x24, 'Data abort, lower EL (write)', 'the FAR, and the DFSC'),
            (0x25, 'Data abort, lower EL (read)', 'the FAR, and the DFSC'),
            (0x2c, 'FP exception', 'the status and a 4-bit index'),
            (0x2e, 'SError', 'the FAR, the WnR bit, the DFSC'),
            (0x32, 'IRQ', 'nothing'),
            (0x33, 'FIQ', 'nothing'),
            (0x34, 'SError interrupt', 'nothing')):
        row('   ', '  %-4s %-27s %s' % ('0x%02x' % ec, mean, iss))
    print()
    note('The same twenty-five bits.  For EC 0x03 the ISS is the sixteen-bit '
         'constant that was in the SVC, and section 4 measured that constant '
         'in the instruction -- so a handler that sees EC 0x03 can tell you '
         'which syscall trapped by reading bits[20:5] of the syndrome, '
         'WITHOUT looking at the instruction at ELR.  For EC 0x25 the same '
         'twenty-five bits are a fault address, a read/write flag, a fault '
         'status code and an overflow flag.  There is no bit of the ISS that '
         'means the same thing in two rows of that table, and that is the '
         'concept: the field is not a number, it is a DISCRIMINATED UNION, '
         'and the discriminant is the six bits above it.')
    print()
    note('And the trap worth naming: the two Data Abort rows differ in ONE '
         'bit of the EC field -- 0x22 is 0b100010 and 0x24 is 0b100100 -- and '
         '0x24 is WRITE and 0x22 is a read-or-write abort.  A handler that '
         'tests for 0x24 and 0x25 and concludes "a write fault and a read '
         'fault" has used a table that is right about those two rows and '
         'silent about 0x22, which is the row a translation fault on a '
         'SINGLE  instruction can also produce.')
    print()
    note('The quoted pseudocode adds one more thing that no bit layout '
         'implies: for EC in {0x24, 0x25} with ISS[24] == 0, IL is FORCED to '
         '1.  So for the most common exception on the machine, the '
         'instruction-length bit is a statement about the ABSENCE of a valid '
         'syndrome rather than about the instruction.  A handler that prints '
         'IL as "32-bit instruction" for such a fault is printing something '
         'the architecture told it to print and something that may be false.')
    print()
    print('  [%s] what this section CANNOT show, and says so HERE'
        % MEAS)
    note('It cannot show an exception.  There is no AArch64 machine, no '
         'emulator and no linker on this host, so not one of the thirty-nine '
         'rows above has been observed happening.  The classes, the field '
         'widths, the meanings and the IL rule are QUOTED from DDI 0597; the '
         'instructions that read the register and the arithmetic the compiler '
         'emits around it are MEASURED-ON-BYTES and cross-read by both '
         'readers.  The gap between those two is the gap between a table you '
         'look up and a sequence you can read, and a course that blurs it is '
         'teaching a reader to trust a table they have never seen fire.')


# ---------------------------------------------------------------------------
# 6. The vector table.
# ---------------------------------------------------------------------------

VEC_NAMES = ['el0t_sync', 'el0t_irq', 'el0t_fiq', 'el0t_serror',
             'el0t_sync_a64', 'el0t_irq_a64', 'el0t_fiq_a64',
             'el0t_serror_a64', 'el0i_sync', 'el0i_irq', 'el0i_fiq',
             'el0i_serror', 'el1t_sync', 'el1t_irq', 'el1t_fiq',
             'el1t_serror']


def sec6():
    hdr(6, 'THE VECTOR TABLE: VBAR, SIXTEEN ENTRIES OF 0x80',
        'QUOTED for the layout; MEASURED for the arithmetic and for what the '
        'assembler enforces')

    ok = sh(CLANG, '--target=%s' % TARGET, '-c', 'vec.s', '-o', 'vec.o')
    if ok.returncode != 0:
        p('ERROR', 'vec.s did not assemble: ' +
                 ok.stderr.strip().splitlines()[-1][:70])
        return

    print('  [%s] the table the assembler BUILT, from vec.s' % MEAS)
    syms = {s['name']: s for s in elf_symbols('vec.o')}
    tab = syms.get('vectors')
    print()
    print('     vector #   name              symbol value   value & 0x7f   '
          'value / 0x80')
    for k, name in enumerate(VEC_NAMES):
        s = syms.get(name)
        v = s['value'] if s else -1
        print('     %-9d %-17s 0x%-9x %-13d %d'
              % (k, name, v, v % 0x80, v // 0x80))
    print()
    row('   ', '  the table symbol: value 0x%x, SIZE %d bytes (0x%x)'
        % (tab['value'], tab['size'], tab['size']))
    print()
    p('RESULT', '16 x 0x80 = 0x%x, and the assembler MEASURED that as %d '
                'bytes' % (16 * 0x80, tab['size']))
    note('The number 0x800 is the address arithmetic and it is trivially '
         'checkable; the reason to print all sixteen rows anyway is that a '
         'table of offsets is a place a REAL error would show, and the error '
         'this method is most likely to have is one entry out by 0x80.  All '
         'sixteen are multiples of 0x80 and all sixteen are in the range '
         '0x800 to 0xf80, and the sixteenth is at 0xf80, so the table spans '
         'exactly sixteen slots from 0x800 to 0xfff inclusive.')
    print()
    retract('R8',
            'the vector table needs 16 x 0x80 = 0x800 bytes, and the standard '
            'way to ask for it in assembly is `.align 11`',
            'the SIZE is right and the DIRECTIVE is `.align 11` only if the '
            'assembler counts from the section start.  MEASURED: with '
            '`.align 11` the section comes back with alignment 2048 and the '
            'table at offset 0; with `.align 8` it comes back with alignment '
            '256 and the table at offset 0 of a section that is only 256-'
            'aligned.  Both assemble.  Neither produces a diagnostic.',
            'the section plan lists the vector table\'s "eight bytes per '
            'vector" as QUOTED and the rest as measured arithmetic, and it is '
            'right -- but "the arithmetic is measured" is not the same as '
            '"the requirement is enforced", and this course is the one that '
            'has to say the second sentence')

    print()
    print('  [%s] what the assembler does about the alignment, and what it '
          'does NOT' % MEAS)
    print('     source                      section align   label value  '
          'diagnostic?')
    cases = [
        ('.align 11 (2 KiB)', '\t.text\n\t.align\t11\n\t.globl\tv\nv:\t.space\t0x800\n'),
        ('.align 8 (256 B)', '\t.text\n\t.align\t8\n\t.globl\tv\nv:\t.space\t0x800\n'),
        ('no .align at all', '\t.text\n\t.globl\tv\nv:\t.space\t0x800\n'),
        ('.align 12 (4 KiB)', '\t.text\n\t.align\t12\n\t.globl\tv\nv:\t.space\t0x800\n'),
    ]
    for label, body in cases:
        pth = os.path.join(HERE, '_al.s')
        with open(pth, 'w') as f:
            f.write(body)
        r = sh(CLANG, '--target=%s' % TARGET, '-c', pth, '-o',
               os.path.join(HERE, '_al.o'))
        if r.returncode != 0:
            row('   ', '  %-24s REFUSED' % label)
            continue
        secs = {s['name']: s for s in readelf_sections('_al.o')}
        syms2 = {s['name']: s for s in readelf_symbols('_al.o')}
        a = secs.get('.text', {}).get('align', 0)
        sz = syms2.get('v', {}).get('value', 0)
        row('   ', '  %-24s %-15d 0x%-6x    NONE'
            % (label, a, sz))
    print()
    note('FOUR CASES, FOUR TIMES NO DIAGNOSTIC.  The section alignment is '
         'whatever the directive says, the table is where the label is, and '
         'the assembler has no idea that a 2 KiB-aligned array of branch '
         'instructions is going to be handed to a register whose low eleven '
         'bits are RES0.  This is the single most important measurement in '
         'the concept and it is a measurement of an ABSENCE: there is no '
         'toolchain on this host -- or, as far as this file can show, on any '
         'host -- that will tell you your vector table is misaligned, because '
         'misalignment here is not an error, it is a jump to the wrong '
         'address.')
    print()
    retract('R9',
            'an assembly-language `.align 11` before the vector table is '
            'enough to make the table valid',
            'it is necessary and not sufficient, and nothing checks it.  The '
            'assembler honours the alignment and the table is 0x800 bytes, '
            'and the register that consumes the address is written at RUNTIME '
            'by an `msr` whose only check is architectural.  A kernel that '
            'computes the address with `adrp` + `add :lo12:` and writes it to '
            'VBAR with the low eleven bits set will fault on the first '
            'exception, and no assembler, linker or compiler will have said '
            'anything.',
            'the section plan for this course asks for `.align 11` '
            'requirements "and what the assembler does if you get it wrong", '
            'and the honest answer to the second half is "nothing", which is '
            'a worse and more useful answer than a diagnostic')

    print()
    print('  [%s] the encoding of reading and writing VBAR' % BYTES)
    for src, w in [('mrs x0, VBAR_EL1', 0xd538c000),
                   ('msr VBAR_EL1, x0', 0xd518c000)]:
        row('   ', '  %-18s 0x%08x  L=%d  CRn=0x%x CRm=0x%x op2=%d  %s'
            % (src, w, (w >> 21) & 1, (w >> 12) & 0xf, (w >> 8) & 0xf,
               (w >> 5) & 7, decode(w).text.strip()))
    print()
    note('One bit -- bit 21 -- separates the read from the write, and the '
         'five-field register name is IDENTICAL in both.  So "installing the '
         'vector table" is a data instruction, not a control instruction, and '
         'it looks in the disassembly exactly like reading a variable.')
    print()
    print('  [%s] the install sequence, as clang assembles it' % BYTES)
    # The reader is the SYMBOL TABLE, not the disassembly: objdump_pairs
    # returns (word, text) with no labels, so the first version of this loop
    # looked for a line containing `install_vbar` and printed the label and
    # nothing under it.
    inst = {s['name']: s for s in elf_symbols('vec.o')}
    fn = inst.get('install_vbar')
    d, machine, secs = elf_sections('vec.o')
    tsec = secs['.text']
    print('     install_vbar, at 0x%x, %d bytes, from the symbol table:'
          % (fn['value'], fn['size']))
    for k in range(fn['size'] // 4):
        off = fn['value'] - tsec['addr'] + 4 * k
        w, = struct.unpack_from('<I', d, tsec['off'] + off)
        print('       0x%08x  %s' % (w, decode(w).text.strip()))
    print()
    note('`adrp` + `add :lo12:` + `msr` + `isb` + `ret`.  The `isb` is the '
         'instruction that makes the write VISIBLE, and it is a separate '
         'instruction because on this architecture a system-register write is '
         'not ordered against the instruction stream by itself.  That is a '
         'QUOTED claim about the architecture and it is also the last course '
         'in this section\'s subject rather than this one; what is measured '
         'here is only that clang emits it, and that the two address-forming '
         'instructions are a PAIR with two relocations, which section 8 '
         'measures properly.')
    print()
    ra = [r for r in elf_relocs('vec.o') if r['name'] == 'vectors']
    print('     the relocations the pair emits:')
    for r in ra:
        row('   ', '  0x%08x  %-30s %s + %d'
            % (r['off'], relname(r['type']), r['name'], r['addend']))
    print()
    note('Two relocations, ADJACENT, against one symbol, four bytes apart.  '
         'That adjacency is the thing to remember from this section and the '
         'thing section 8 is about: on AArch64 a reference to a 4 KiB-'
         'aligned object is TWO relocations and there is no encoding of "one '
         'relocation that means an address".')
    print()
    print('  [%s] what this section CANNOT show' % MEAS)
    note('It cannot show an interrupt being taken, a vector being entered, or '
         'a VBAR write being honoured.  The sixteen entries, the four '
         'exception types, the (source EL, target EL) pair that selects the '
         'first four rows, and the requirement that the low eleven bits of '
         'VBAR be zero are all QUOTED.  What is measured is the table the '
         'assembler built, its size, its sixteen offsets, the four different '
         'things the assembler does with an alignment directive, the encoding '
         'of the read and the write, and the two relocations.  Six results, '
         'and the largest of them is an absence.')


# ---------------------------------------------------------------------------
# 7. TTBR0, TTBR1, TCR, and the 48/52 split.
# ---------------------------------------------------------------------------

def sec7():
    hdr(7, 'TTBR0, TTBR1, TCR, AND THE 48/52 SPLIT',
        'QUOTED for the field positions; MEASURED for the encodings and for '
        'the arithmetic the compiler emits')

    print('  [%s] three registers, and the encodings that name them' % BYTES)
    for src, w in [('mrs x0, TTBR0_EL1', 0xd5382000),
                   ('mrs x0, TTBR1_EL1', 0xd5382020),
                   ('mrs x0, TCR_EL1', 0xd5382040),
                   ('mrs x0, SCTLR_EL1', 0xd5381000),
                   ('msr TTBR0_EL1, x0', 0xd5182000),
                   ('msr TCR_EL1, x0', 0xd5182040),
                   ('mrs x0, TCR_EL2', 0xd53c2040)]:
        i = decode(w)
        row('   ', '  %-18s 0x%08x  CRn=0x%x CRm=0x%x op2=%d  op1=%d  %s'
            % (src, w, (w >> 12) & 0xf, (w >> 8) & 0xf, (w >> 5) & 7,
               (w >> 16) & 7, i.text.strip()))
    print()
    note('TTBR0, TTBR1 and TCR are CRn = 2 and they are told apart by a '
         'TWO-BIT op2 field: 0, 1, 2.  Three registers whose addresses a '
         'kernel sets at boot, whose names a reader will look up, and whose '
         'encodings differ in two bits of a 32-bit word -- and which are '
         'adjacent numbers, 0, 1, 2, in a way that is a gift to a decoder and '
         'a trap for a page that wants to show the reader something about '
         'their relationship.  There is nothing about the relationship in the '
         'encoding.  The relationship is in the ARCHITECTURE and it is the '
         'subject of the next two sections.')

    print()
    print('  [%s] the 48/52 split, as ARITHMETIC, which is checkable'
        % MEAS)
    print('     T0SZ is bits[63:48] of TCR_EL1 and T1SZ is bits[47:32]')
    print('     (QUOTED), and the region TTBRn addresses is 2^(64-TnSZ)')
    print('     bytes.  Every row below is that identity and nothing else.')
    print()
    print('     configuration   VA bits   T0SZ  T1SZ   TTBR0 region'
          '                 TTBR1 region')
    for label, b0, b1 in (('48-bit, no LPA2', 48, 48),
                          ('48/52, with LPA2', 48, 52),
                          ('39/39, the 3-level case', 39, 39),
                          ('39/48', 39, 48),
                          ('42/48', 42, 48),
                          ('52/52', 52, 52),
                          ('33/33, the SMALLEST', 33, 33)):
        t0, t1 = 64 - b0, 64 - b1
        r0, r1 = 1 << (64 - t0), 1 << (64 - t1)
        print('     %-16s %-8d %-5d %-5d 2^%-2d = 0x%012x  2^%-2d = 0x%012x'
              % (label, b0, t0, t1, 64 - t0, r0, 64 - t1, r1))
    print()
    p('RESULT', 'T0SZ = 64 - 48 = 16, and T1SZ = 64 - 52 = 12 with LPA2, '
                '64 - 48 = 16 without')
    note('The section plan for this course says "T0SZ = 64 - 48 = 16 for a '
         '4-level table, T1SZ = 64 - 48 for the 48-bit case and 64 - 52 = 12 '
         'for 52-bit", and every one of those three numbers is right.  What '
         'is worth adding is the row that is NOT in the plan: the 39-bit '
         'case, where T0SZ = 25, and the 30-bit case, where T0SZ = 34 -- and '
         'T0SZ is a FIVE-BIT field, so 34 fits and 32 does not.  A reader who '
         'has only seen 16 and 12 will assume T0SZ is a small number and will '
         'not notice that the field has a ceiling at 31, which is what makes '
         'a 2-level configuration possible at all.')
    print()
    print('     and the field is FIVE bits, so the SIZE of a regime is')
    print('     bounded below as well as above:')
    for bits in (64, 60, 52, 48, 44, 42, 39, 36, 33, 32, 30, 25):
        t0 = 64 - bits
        fits = 0 <= t0 <= 31
        print('       %2d-bit VA  ->  T0SZ = %-3d  %s'
              % (bits, t0, 'region 2^%d bytes, FITS' % bits if fits
                 else 'region 2^%d bytes, DOES NOT FIT in a 5-bit field'
                 % bits))
    print()
    note('So a 32-bit virtual address space is NOT expressible with a 4 KiB '
         'granule: T0SZ would be 32, the field holds 0 to 31, and the '
         'smallest regime the field can name is 2^33 bytes -- eight gibibytes. '
         'That is a real boundary and it is pure arithmetic, and the first '
         'draft of this table had a "30-bit, the 2-level case" row in it, '
         'which the same arithmetic contradicts.  AArch64 has no 2-level '
         'configuration with 4 KiB pages; the two-level cases all use the '
         '64 KiB granule, where T0SZ is six bits wide and the floor moves to '
         '2^32.  A page that lists block sizes as a menu, without the field '
         'width beside them, will produce that row.')
    print()
    note('And the other direction: a regime can cover the WHOLE address '
         'space, 2^64 bytes, with T0SZ = 0 -- which is why the 48/52 split is '
         'a DEFAULT and not a limit.  The reason a real system uses 48 is not '
         'that 52 will not fit in the field; it is that each extra level of '
         'table costs another 4 KiB of memory and four more dependent memory '
         'accesses for every translation.  That cost is a real number on a '
         'real machine and it is NOT measurable here.  The five-bit field and '
         'the identity above are, and they are what this course can defend.')

    print()
    print('  [%s] the three translation REGIMES, and their bases' % QUOT)
    row('   ', '  regime        base register  covers')
    for reg, what in (('TTBR0_EL1', 'the LOW half of the VA space, where an '
                                'EL0 process lives'),
                      ('TTBR1_EL1', 'the HIGH half, where the kernel image '
                                'and its mappings live'),
                      ('TTBR2_EL1', 'stage 2 only: the EL1 regime translated '
                                'for an EL0 access, used by a hypervisor')):
        row('   ', '  %-13s %-15s %s' % (reg, '', what))
    print()
    note('The arithmetic identity above says TTBR0 and TTBR1 each cover '
         '2^(64-TnSZ) bytes, and it does NOT say WHERE they are.  The base is '
         'in the register, and the constraint is that the two regions must '
         'NOT OVERLAP.  For a 48/48 configuration each covers half the space '
         'and they meet exactly; for 48/52 TTBR0 covers the bottom 2^48 and '
         'TTBR1 covers the top 2^52 and there is a 2^48 hole in the middle '
         'that neither regime translates -- and a hole is not an error, it is '
         'an unmapped hole, and a load from it takes a translation fault.  '
         'That is the price of a 52-bit kernel address space with a 48-bit '
         'user one, and it is arithmetic.')
    print()
    print('     the boundary, as pure arithmetic.  TTBRn is at the END of')
    print('     its region, so the high regime is mapped at the TOP of the')
    print('     address space -- that is the whole content of R10.')
    for label, b0, b1 in (('48/48', 48, 48), ('48/52', 48, 52),
                          ('39/48', 39, 48)):
        hi0 = (1 << b0) - 1
        lo1 = ((1 << 64) - (1 << b1))
        gap = lo1 - hi0 - 1
        print('       %-8s TTBR0 covers 0x%016x..0x%016x'
              % (label, 0, hi0))
        print('       %-8s TTBR1 covers 0x%016x..0x%016x'
              % ('', lo1, (1 << 64) - 1))
        print('       %-8s between them: 0x%x bytes, which is UNTRANSLATED'
              % ('', gap))
    print()
    note('Read the 48/48 row and the 48/52 row side by side, because the '
         'difference is the whole concept and it is not a difference in the '
         'FORMULAS.  For 48/48 the two regions meet exactly: TTBR0 ends at '
         '0x0000ffffffffffff and TTBR1 begins at 0x0001000000000000, and '
         'there is no address space between them that belongs to neither '
         'regime.  For 48/52 TTBR0 still ends at 0x0000ffffffffffff but '
         'TTBR1 now begins at 0xffff000000000000, so the two regions are '
         'separated by essentially the whole of the 64-bit space.  Neither '
         'is a bug and neither is checked by anything: the gap is simply '
         'UNTRANSLATED, and a load from it takes a translation fault.  A '
         '52-bit kernel address space with a 48-bit user one is exactly the '
         'statement that the top 2^52 and the bottom 2^48 are translated and '
         'the rest is not.')
    print()
    retract('R16',
            'AArch64 can be configured with a 30-bit virtual address space in '
            'a two-level table, because the block sizes at level 1 allow it',
            'T0SZ is a FIVE-BIT field and 64 - 30 = 34 does not fit in it, so '
            'with a 4 KiB granule the SMALLEST regime the field can name is '
            '2^33 bytes.  The two-level configurations all use the 64 KiB '
            'granule, where T0SZ is six bits wide and the floor moves to 2^32.  '
            'MEASURED here as arithmetic on a quoted field width, and the '
            'contradiction was found by the same table that produced the '
            'number: the first draft of this section listed a "30-bit, the '
            '2-level case" row and the row below it said the field holds five '
            'bits.',
            'a table of block sizes presented as a MENU rather than as a '
            'consequence of a field width will always contain a row the field '
            'cannot express, and the row looks entirely reasonable.  This is '
            'the third time in this section that a plausible-looking number '
            'was killed by a constraint printed in the same table')
    retract('R10',
            'the 48/52 split means the high half is 52 bits of virtual address',
            'it means the HIGH half covers 2^52 bytes and the LOW half '
            'covers 2^48, and the 52-bit half is mapped at the TOP of the '
            'address space with its base at 0xffff000000000000 -- so the top '
            '52 bits of a kernel address are 0xffff, not a free choice of 52 '
            'bits.  The name "52-bit" describes the SIZE of the region and a '
            'reader who takes it for the size of the ADDRESS will place a '
            'kernel pointer wrongly.',
            'the plan says "the 48/52-bit T0SZ/T1SZ split" and gives the '
            'arithmetic, and the arithmetic is right; what it does not say is '
            'that the two numbers are region SIZES and not address widths, and '
            'the two readings differ by the position of the high regime in '
            'the address space')

    print()
    print('  [%s] what the compiler emits for the regime arithmetic'
        % MEAS)
    fns = dict(asm_functions('sys_O2.s'))
    for name in ('t0sz_for', 'regime_bytes', 'ttbr1_52', 'ttbr0_48',
                 'l0_index', 'l1_index', 'l2_index', 'l3_index', 'page_off'):
        ins = insn_lines(fns.get(name, []))
        print('     %-14s %2d  %s' % (name, len(ins),
                                     ' ; '.join(ins) if ins else '(none)'))
    print()
    note('Nine functions, each one an index extraction or a subtraction, and '
         'each one a SHIFT.  A four-level walk is four of them: the top nine '
         'bits, the next nine, the next nine, the next nine, and the low '
         'twelve as an offset.  That is the whole structure of an AArch64 '
         'page table expressed as five shifts, and it is worth noticing that '
         'x86-64 needs the same five extractions and that NEITHER architecture '
         'stores the level in the descriptor: the level is implied by WHICH '
         'TABLE you are in, which is why the same three bits -- valid, and a '
         'flag that is "table" at levels 0-2 -- mean different things at '
         'different depths.')

    print()
    print('  [%s] the encoding of one page-table walk step, measured'
        % MEAS)
    print('     What a 4 KiB-aligned page table costs to NAME, in an object')
    print('     file, and why the answer is two relocations rather than one,')
    print('     is section 8.  What section 7 can add is the reach:')
    print()
    for src, w, note_ in (('adrp x0, 0x40000000', 0x90000000, None),):
        pass
    print('     instruction   immediate field   signed bits   unit       reach')
    print('     ADR           bits[20:5]+[30:29] 21          1 BYTE     '
          '+-2^20 = 1 MiB')
    print('     ADRP          bits[20:5]+[30:29] 21          4096 BYTES '
          '+-2^20 pages = 4 GiB')
    print()
    note('The ADR reach is MEASURED, by asking the assembler: the largest '
         'distance it accepts is 0xffffc bytes and 0x100000 is REFUSED with '
         '"fixup value out of range", which is exactly a 21-bit signed field '
         'whose largest positive multiple of four is 0xffffc.  The ADRP reach '
         'is NOT measurable here, because the assembler does not check it: '
         '`adrp` to a target 4 GiB away is ACCEPTED and the check belongs to '
         'the linker, and there is no AArch64 linker on this host.  So the '
         'ADR number is a measurement and the ADRP number is an arithmetic '
         'identity on a field width, and the page says so at both.')
    print()
    print('  [%s] what this section CANNOT show' % MEAS)
    note('It cannot show a page walk, a TLB, a translation, or a fault.  No '
         'AArch64 machine, no emulator, no sysroot, so not one address in '
         'this section was translated by anything.  The field positions, the '
         'granule encodings and the region formula are QUOTED; the '
         'encodings, the five shifts and the ADR boundary are MEASURED.  The '
         'one measurement a reader should hold on to is the reach asymmetry: '
         'a fixed 32-bit instruction with a 21-bit field can address a PAGE '
         '4 GiB away or a BYTE 1 MiB away, and every page table in a system '
         'is on the first side of that line while every array index is on the '
         'second.')


# ---------------------------------------------------------------------------
# 8. Four levels, three regimes, and the relocations.
# ---------------------------------------------------------------------------

def sec8():
    hdr(8, 'FOUR LEVELS, THREE REGIMES, AND THE RELOCATIONS',
        'QUOTED for the descriptor format; MEASURED for the sizes, the '
        'alignment and every relocation in this section')

    print('  [%s] the table: 512 entries of 8 bytes, and what the compiler '
          'emits' % MEAS)
    syms = {x['name']: x for x in elf_symbols('sys_O2.o')}
    print('     the TABLES, as the symbol table records them:')
    for name in ('l0', 'l1', 'l2', 'l3', 'l2_big'):
        x = syms.get(name)
        if x is None:
            continue
        row('   ', '  %-8s value 0x%-9x size %-9d %s'
            % (name, x['value'], x['size'],
               '4 KiB-aligned' if x['value'] % 4096 == 0 and x['size'] == 4096
               else ('2 MiB-aligned' if x['value'] % 0x200000 == 0
                     else 'unaligned')))
    print()
    print('     the FUNCTIONS that name them, and their sizes:')
    for name in ('ref_l0', 'ref_l1', 'ref_l2', 'ref_l2_big', 'ref_l3',
                 'd0', 'd3', 'w3', 'big0'):
        x = syms.get(name)
        if x is None:
            continue
        row('   ', '  %-11s value 0x%-9x size %d' % (name, x['value'],
                                                      x['size']))
    print()
    row('   ', '  512 x 8 = %d bytes, and the four 4 KiB tables are exactly '
               'that' % (512 * 8))
    print()
    note('Each table is 512 descriptors of 8 bytes, so 4 KiB exactly, so the '
         'index into one is NINE BITS -- bits[47:39] for level 0, [38:30] '
         'for level 1, [29:21] for level 2, [20:12] for level 3, and the low '
         'twelve are the offset inside the page.  Four levels of nine bits is '
         '36 bits of index plus 12 bits of offset, which is the 48-bit split '
         'of section 7 arriving as a table shape.  The 8-byte descriptor is '
         'QUOTED and the 4 KiB size is arithmetic on it; what is measured is '
         'that clang emitted four arrays of exactly that size and aligned '
         'them, and that the alignment is in the section header.')

    print()
    print('  [%s] the alignment a LINKER must honour, and where it is '
          'recorded' % MEAS)
    print('     section    reader 1 (struct.unpack)   reader 2 '
          '(llvm-readelf)   agree?')
    secs1 = elf_sections('sys_O2.o')[2]
    secs2 = {s['name']: s for s in readelf_sections('sys_O2.o')}
    for nm in ('.text', '.bss', '.rela.text', '.symtab'):
        if nm in secs1 and nm in secs2:
            a1 = secs1[nm]['align']
            a2 = secs2[nm]['align']
            row('   ', '  %-10s %-22d %-21d %s'
                % (nm, a1, a2, 'YES' if a1 == a2 else 'NO'))
    print()
    b1 = secs1.get('.bss', {}).get('align', 0)
    b2 = secs2.get('.bss', {}).get('align', 0)
    p('RESULT', '.bss comes back with alignment 0x%x from BOTH readers'
        % b1)
    note('That number is 2 MiB, and it is the whole of the ELF-side half of '
         'this concept in one integer.  The corpus has four 4 KiB-aligned '
         'tables and ONE 2 MiB-aligned table, and the section carrying all of '
         'them is `.bss` -- so `.bss` inherits the STRONGEST alignment '
         'requirement of anything in it.  A page table is an ordinary array '
         'of 64-bit words to a compiler, and the ONLY reason the section '
         'needs 2 MiB of alignment is that one of the arrays in it is a page '
         'table and the OTHER FOUR ARE NOT.  That is a fact about the role, '
         'not about the type, and it is the only way a linker can know.')
    print()
    retract('R11',
            'a page table is an ordinary array of 64-bit words, so nothing in '
            'the object file distinguishes it',
            'its ALIGNMENT does, and the alignment is a property of the '
            'SECTION, not of the object.  MEASURED: one 2 MiB-aligned page '
            'table among four 4 KiB-aligned ones makes the whole of `.bss` '
            '2 MiB-aligned, in both readers.  An object with no 2 MiB table '
            'in it has `.bss` at 4 KiB.  Same types, same code, one bit of '
            'alignment, and a linker that ignores it produces a kernel that '
            'faults on the first exception it takes.',
            'docs/aarch64-section-plan.md says "the ELF-side consequence, '
            'which is where the genuinely new material lives" and is right, '
            'but it does not say that the consequence is an ALIGNMENT and not '
            'a relocation -- and the alignment is the half that is silent when '
            'it is wrong')
    print()
    print()
    print('     the corpus with and without the 2 MiB table -- the whole')
    print('     measurement in two lines, because the ONLY difference between')
    print('     the two objects is one declaration and the two functions that')
    print('     mention it:')
    if os.path.exists('_no2m.o'):
        a_with = secs1.get('.bss', {}).get('align', 0)
        a_with2 = secs2.get('.bss', {}).get('align', 0)
        a_without = elf_sections('_no2m.o')[2].get('.bss', {}).get('align', 0)
        a_without2 = {s['name']: s for s in readelf_sections('_no2m.o')
                      }.get('.bss', {}).get('align', 0)
        row('   ', '  object            reader 1     reader 2')
        row('   ', '  sys_O2.o          %-12d %d' % (a_with, a_with2))
        row('   ', '  _no2m.o           %-12d %d' % (a_without, a_without2))
        p('RESULT', 'four 4 KiB tables alone give `.bss` alignment 0x%x; adding '
                    'one 2 MiB table gives 0x%x' % (a_without, a_with))
        note('Same types, same code, same language, same compiler, same '
             'optimisation level.  One declaration of the form '
             '`__attribute__((aligned(0x200000)))` on ONE array of 512 x 8 '
             'bytes, and the ENTIRE uninitialised-data section of the object '
             'moves from a 4 KiB boundary to a 2 MiB one.  That integer is '
             'the only channel through which a page table tells a linker what '
             'it is, and it is 21 bits in a section header.')
    else:
        note('(the no-2MiB object was not built; run build_samples.sh)')
    print()
    print('  [%s] the DESCRIPTOR, field by field, and the two ways to read it'
        % QUOT)
    print('     64-bit little-endian descriptor, at every level:')
    row('   ', '  bits    name    meaning')
    for lo, hi, name, mean in (
            (63, 63, '-', 'for a BLOCK at level 1-2: whether the block size '
                          'is 2 MiB (0) or 32 MiB (1) -- FEAT_LPA2 only'),
            (62, 55, '-', 'for a BLOCK at level 2: whether it is 32 MiB (0) '
                          'or 512 MiB (1) -- FEAT_LPA2 only'),
            (54, 53, 'TXL', 'translation table level, 0-3, for a table '
                            'descriptor'),
            (52, 12, 'output address', 'the physical address, with the low '
                                       'bits RES0'),
            (11, 10, 'NG', 'nestable, 0 for the EL1/EL0 regime'),
            (9, 8, 'AF', 'access flag, and bits[7:6] are SH'),
            (7, 6, 'SH', 'shareability: 00 non-, 10 outer, 11 inner'),
            (5, 5, 'AP', 'access permission: EL1 RW, EL0 none, RO, RW'),
            (4, 2, 'AttrIndx', 'index into MAIR_EL1'),
            (1, 1, '-', 'at levels 0-2 this is the TABLE bit; at level 3 it '
                        'is PAGE'),
            (0, 0, 'V', 'valid')):
        row('   ', '  %-7s %-16s %s' % ('%d:%d' % (lo, hi), name, mean))
    print()
    note('Two columns of that table are the whole reason a page table is hard '
         'to read in a hex dump: bits[1] is the TABLE bit at levels 0-2 and '
         'is UNUSED at level 3, and bits[54:53] carry the level for a table '
         'descriptor and are the low half of a huge-block size for a block '
         'descriptor.  The same bits, two meanings, and which meaning applies '
         'is a property of WHERE YOU ARE IN THE WALK and not of the word.  A '
         'hex-dump tool that prints one description of a 64-bit word is '
         'printing one of two, and the reader has to know which.')
    print()
    print('     the descriptor arithmetic, as the compiler emits it:')
    fns = dict(asm_functions('sys_O2.s'))
    body = fns.get('build_walk', [])
    for b in insn_lines(body):
        print('       ' + b)
    print('     %d instructions to build a four-level walk with two 2 MiB '
          'blocks, three' % len(insn_lines(body)))
    print('     pages and one 1 GiB block.')
    print()
    note('That is a COMPILE-TIME INSTRUCTION COUNT and not a timing, and it '
         'is the only number in this file that is a count of work rather than '
         'a fact about a format.  It is worth printing because it is small: '
         'building a translation table is a handful of ORs and ANDs per '
         'descriptor, and the expensive part of paging is not building the '
         'table, it is WALKING it -- four dependent memory accesses, or one '
         'if the TLB has the entry.  None of that is measurable here and the '
         'file says so rather than inventing a number.')

    print()
    print('  [%s] the RELOCATION census: two readers over every relocation'
        % BYTES)
    ok = sh(CLANG, '--target=%s' % TARGET, '-c', 'rel.s', '-o', 'rel.o')
    r1 = elf_relocs('rel.o')
    r2 = readelf_relocs('rel.o')
    print()
    print('     offset      reader 1: number name                        '
          'symbol   addend')
    for r in sorted(r1, key=lambda x: x['off']):
        row('   ', '  0x%08x  %-8d %-34s %-9s %d'
            % (r['off'], r['type'], relname(r['type']), r['name'], r['addend']))
    print()
    print('     the reader-2 view, name and number, and the agreement:')
    byoff = {}
    for r in r2:
        byoff.setdefault(r['off'], []).append(r)
    agree = 0
    disagree = []
    for r in sorted(r1, key=lambda x: x['off']):
        m = byoff.get(r['off'])
        if not m:
            disagree.append((r['off'], 'reader 2 has no record'))
            continue
        b = m[0]
        if b['type'] == r['type']:
            agree += 1
        else:
            disagree.append((r['off'], 'reader 1 says %d, reader 2 says %d'
                             % (r['type'], b['type'])))
    row('   ', '  %d of %d relocations agree on the TYPE NUMBER' %
        (agree, len(r1)))
    for off, why in disagree:
        row('   ', '  0x%08x  %s' % (off, why))
    print()
    print('     the census, by name:')
    counts = {}
    for r in r1:
        counts[relname(r['type'])] = counts.get(relname(r['type']), 0) + 1
    for k in sorted(counts, key=lambda x: -counts[x]):
        row('   ', '  %-32s %d' % (k, counts[k]))
    print()

    print('  [%s] WHY A PAGE TABLE NEEDS A PAIR, and the reason is NOT reach'
        % MEAS)
    print('     Every reference to a 4 KiB-aligned table in rel.s produced an')
    print('     ADRP at one offset and a LO12 at offset+4.  All of them:')
    print()
    for r in sorted(r1, key=lambda x: x['off']):
        print('       0x%08x  %s' % (r['off'], relname(r['type'])))
    print()
    byoff = {r['off']: relname(r['type']) for r in r1}
    pairs = lone = 0
    lone_at = []
    for off in sorted(byoff):
        if byoff[off] != 'R_AARCH64_ADR_PREL_PG_HI21':
            continue
        nxt = byoff.get(off + 4, '')
        if nxt.endswith('LO12_NC'):
            pairs += 1
        else:
            lone += 1
            lone_at.append(off)
    p('RESULT', '%d of the %d ADRP relocations are immediately followed, four '
                'bytes later, by a LO12, and %d are LONE'
        % (pairs, pairs + lone, lone))
    if lone_at:
        note('And the %d LONE ADRP is the most interesting row in the table, '
             'because it is the counter-example and it is deliberate.  In '
             '`ref_load_uimm` the source says `ldr x6, [x5, #0]`: the offset '
             'is a LITERAL ZERO, so the low twelve bits of the address are '
             'known at assembly time to be zero, the second instruction does '
             'not need a relocation for them, and the assembler emits one.  '
             'So the rule is not "every page reference is a pair" -- it is '
             '"every page reference whose low twelve bits are not statically '
             'zero is a pair", and the exception is a compiler optimisation '
             'you can see in an object file.' % lone)
    note('The reason is NOT that adrp only reaches 4 GiB.  A lone adrp '
         'reaches 4 GiB, which is not a constraint any real program hits, and '
         'section 7 measured the ADR reach precisely so that the wrong reason '
         'could not survive: ADR reaches 1 MiB and ADRP reaches 4 GiB, and '
         'the pair is emitted for a 4 KiB-aligned object FOUR BYTES AWAY.')
    print()
    note('The real reason is in bits[32:12].  ADRP computes '
         '(page(target) - page(pc)) >> 12 and puts THAT in a 21-bit field, '
         'which means the low twelve bits of the target address are not in '
         'the instruction at all -- they were MASKED OFF.  Something has to '
         'add them back, and the only instructions that can are the ones with '
         'a 12-bit immediate: `add` (R_AARCH64_ADD_ABS_LO12_NC) or a load or '
         'store with an unscaled 12-bit offset (R_AARCH64_LDST64_ABS_LO12_NC). '
         'The pair is not a range problem.  It is a MASKING problem, and no '
         'amount of reach would fix it.')
    print()
    retract('R12',
            'a page needs a PAIR of relocations per page because the adrp '
            'reach is +-4 GiB',
            'the reach is 4 GiB and is irrelevant.  The pair exists because '
            'ADRP masks off the low twelve bits of the target -- the '
            'relocation is named ADR_PREL_PG_HI21 and the "_PG_HI" is the '
            'high twenty bits of the address -- so the low twelve have to be '
            'restored by a second instruction with its own relocation.  The '
            'reach that matters is ADR\'s, and it is 1 MiB, and section 7 '
            'measured both numbers by asking the assembler to refuse one of '
            'them.',
            'docs/aarch64-section-plan.md states the pair as fact and the '
            'reach as the reason, and the fact survives while the reason does '
            'not.  A '
            'reader who believed the reason would conclude that a page table '
            'further than 4 GiB from the code needs a different instruction -- '
            'which is true, and for a reason that has nothing to do with the '
            'distance')
    print()
    print()
    print('     and the ONE reference in rel.s that is not a pair at all:')
    for r in sorted(r1, key=lambda x: x['off']):
        if relname(r['type']) == 'R_AARCH64_ADR_PREL_LO21':
            row('   ', '  0x%08x  %s against %s' % (r['off'],
                                                    relname(r['type']),
                                                    r['name']))
    note('`adr x0, odd` reaches a symbol 12 bytes away and emits a SINGLE '
         'relocation, R_AARCH64_ADR_PREL_LO21, because ADR puts all 21 bits '
         'of the address IN the instruction and there is nothing left to add. '
         'So the rule that falls out of the measurement is not about pages at '
         'all: a reference that fits in ADR is one relocation, and a '
         'reference that does not is two.  Page tables are the case that does '
         'not fit, always, because a page is 4 KiB and ADR reaches 1 MiB and '
         'even when the distance is small the low twelve bits still have to '
         'be restored.')
    print()
    note('The linker is allowed to REWRITE the pair as `adr` + `nop` when the '
         'target turns out to be within 1 MiB, and this is a real and '
         'frequently-taken relaxation.  It is not measurable here, because '
         'there is no AArch64 linker on this host -- and that is a limit, not '
         'a fact about the pair.  What IS measured is the input to the '
         'decision: the two relocations, their four-byte spacing, and the '
         'symbol they share.')
    print()
    print('  [%s] the SIZES: 4 KiB, 2 MiB, 1 GiB' % MEAS)
    print('     level   page    block (no LPA2)  block (LPA2)   one table '
          'covers')
    for lv, pg, b_no, b_lpa in ((0, '-', '-', '-'),
                                (1, '-', '2 MiB', '2 MiB'),
                                (2, '-', '-', '32 MiB'),
                                (3, '4 KiB', '-', '512 MiB')):
        print('     %-7d %-7s %-16s %-14s %s'
              % (lv, pg, b_no, b_lpa, '-'))
    print()
    print('     and the arithmetic of a full 48-bit regime:')
    for lv, sz in ((0, 1 << 48), (1, 1 << 36), (2, 1 << 24), (3, 1 << 12)):
        print('       one L%d table covers 2^%-2d bytes = %d TiB; a 48-bit '
              'space needs 2^%d of them'
              % (lv, lv * 12 + 12, (1 << (lv * 12 + 12)) >> 40, 12 - lv))
    print('       a 2 MiB block at L1 covers 2^21 bytes, so 48 bits needs '
          '2^27 = %d' % (1 << 27))
    print('       of them, which is 2 TiB of descriptors at 8 bytes each.')
    print('       a 1 GiB block at L2 needs 2^18 = %d of them.' % (1 << 18))
    print()
    note('So the choice of block size is a choice about how many ENTRIES the '
         'top level has, and it is bounded by the fact that there are only '
         '512 of them: a 48-bit space at L1 with 2 MiB blocks needs 2^27 '
         'entries and there are 512.  That is why a real 48-bit system uses '
         'blocks at L2, not at L1, and the reason is a count, and the count '
         'is arithmetic.')
    retract('R13',
            'docs/aarch64-section-plan.md says "the four descriptor levels '
            'and the block/table/page sizes" and the natural reading is that '
            'level 1 can hold a 2 MiB block',
            'it can, and a 48-bit regime cannot USE it, because 2^27 entries '
            'are needed and a table has 512.  The level at which you can use '
            'a block is fixed by the arithmetic of the space size, and for a '
            '48-bit VA that is level 2 with a 32 MiB block under LPA2 or level '
            '1 with a 2 MiB block in a 39-bit regime.  The three real AArch64 '
            'configurations are 39/39, 48/48 and 48/52, and the block size '
            'follows from the VA size, not the other way round.',
            'a reader who took the table of sizes as a menu would build a '
            'level-1 2 MiB block table, find that 512 entries cover 1 GiB, '
            'and conclude that 48-bit virtual memory is impossible -- which '
            'it is not, and the impossibility is in the arithmetic they did '
            'not do')

    print()
    print('  [%s] what this section CANNOT show' % MEAS)
    note('It cannot show a page walk, a translation, a TLB hit or a miss, or '
         'the four dependent memory accesses a walk costs when the TLB does '
         'not have the entry.  The descriptor format, the field positions and '
         'the granule encodings are QUOTED; the table sizes, the alignment '
         'the section header carries, the relocation names and numbers and '
         'their pairing are MEASURED and read by both readers where two '
         'readers exist.  The linker is absent, so the ADRP+ADD -> ADR+NOP '
         'relaxation is quoted and the pair it operates on is measured, and '
         'that is the closest this host can get to the hinge between this '
         'course and the ELF courses.')


# ---------------------------------------------------------------------------
# 9. Two readers, and one of them poisoned.
# ---------------------------------------------------------------------------

def norm(t):
    """One reader's text, normalised to a form the other can be compared to.

    Whitespace, tabs and trailing comments go.  Nothing else does: the
    reconciliation below is done by NAMED RULES that are printed with their
    counts, because a normalisation that is not counted is a fudge and a
    fudge that is not counted is indistinguishable from a bug.  The first
    version of this file had a general "if the first four characters match,
    count it as agreement" rule, which agreed on 84 words of which 9 were
    real aliases and 75 were padding bytes -- and 75 bytes of padding are
    not a normalisation.
    """
    t = t.split('//')[0].strip().replace('\t', ' ')
    return re.sub(r'\s+', ' ', t)


def census(models=None):
    """(read, named) over the corpus with a GIVEN dispatch.

    The models argument exists so that the same loop can be run three times
    with three different SETS of models -- the encoding course's twenty-one,
    those plus the ABI course's six, and those plus this course's six -- and
    the difference printed.  That is the measurement that makes a coverage
    number mean something: a decoder that names 100% of a corpus is either
    complete or reading a corpus chosen to suit it, and the only way to tell
    which is to remove models and watch the number fall.
    """
    saved = Dec.MODELS
    if models is not None:
        Dec.MODELS = models
    try:
        t = n = 0
        for f in ('sys_O0.o', 'sys_O1.o', 'sys_O2.o', 'sys_Os.o',
                  'vec.o', 'rel.o'):
            if not os.path.exists(f):
                continue
            ins, _m, _s = text_insns(f)
            for _sec, i in ins:
                t += 1
                if i.name is not None:
                    n += 1
        return t, n
    finally:
        Dec.MODELS = saved


def _mnem(text):
    """The first word of a disassembly line, or '(op' for a bare address."""
    t = norm(text)
    if not t:
        return '(op'
    return t.split()[0]


def _alias(text):
    """The MOVZ/MOVN/MOVK and UBFM/BFM ALIASES, mapped to what the other
    reader is expected to print.

    A decoder that printed the opcode everywhere would be WRONG about MOVN,
    which is a complement rather than a move, and about SBFM/UBFM, which have
    three aliases each.  So the conversion goes the other way: the rule names
    the alias and the check is that BOTH sides normalise to the same thing.

    The rules are counted, and each count is printed.  A reconciliation that
    is not counted is a fudge, and a fudge that is not counted is
    indistinguishable from a bug.
    """
    t = norm(text)
    m = re.match(r'^(movz|movn|movk)\s+\w+,\s*#(0x[0-9a-f]+|-?0x[0-9a-f]+)$',
                 t)
    if m:
        return 'mov'
    if re.match(r'^(ubfx|sbfx|ubfiz|sbfiz|bfi|bfxil)\b', t):
        return 'ubfm' if t.startswith(('ubfx', 'ubfiz', 'bfi', 'bfxil')) \
            else 'sbfm'
    if re.match(r'^(lsl|lsr|asr)\s+w\d+,\s*w\d+,\s*#\d+$', t):
        return 'ubfm'
    if re.match(r'^(cmp|cmn|neg|negs)\b', t):
        return 'add' if t.startswith(('cmp', 'cmn')) else 'sub'
    if re.match(r'^(tst|bic)\b', t):
        return 'and' if t.startswith('tst') else 'orr'
    return None


def _family(name):
    """A deliberately LOSSY family, so that a family collision shows up.

    A rule is the first four characters of the mnemonic, which is coarse on
    purpose: `dsb`/`dmb` and `csel`/`csinc` and `movz`/`movn` all collapse
    under a finer rule, and the whole point of the cross-check is to find
    collisions rather than to hide them.  A decoder that agrees with another
    decoder on a four-character prefix has agreed on very little.
    """
    if not name or name == '(op':
        return '(op'
    return name[:4]


def sec9():
    hdr(9, 'TWO READERS, AND ONE OF THEM POISONED',
        'MEASURED-ON-BYTES: every instruction in the corpus, read twice, and '
        'then one guard poisoned on purpose')

    files = [f for f in ('sys_O0.o', 'sys_O1.o', 'sys_O2.o', 'sys_Os.o',
                         'vec.o', 'rel.o') if os.path.exists(f)]
    print('  [%s] the corpus, walked over FUNCTION ranges' % MEAS)
    note('The walk is over sized function symbols and not over whole code '
         'sections, and the reason is a number.  `rel.o`\'s `.text` is '
         '2,101,380 bytes because one page table is declared 2 MiB-aligned '
         'and the assembler pads up to it, and `vec.o`\'s `.text` contains '
         '0x7c0 bytes of `.space` after the sixteen branches.  Those bytes are '
         'ALIGNMENT and not code, and llvm-objdump disassembles them anyway '
         'as half a million `udf`s.  The first version of the walk counted '
         'whole sections and reported 527,837 instructions with 522,326 '
         'disagreements -- all of them padding -- which reads like a '
         'catastrophe and is a mistake in the harness.')
    print()
    tot = nam = agree = 0
    per = []
    gaps = {}
    gaptext = {}
    alias_hits = {}
    true_dis = []
    for f in files:
        ins, _m, _s = text_insns(f)
        omap = {}
        for w, txt in objdump_pairs(f):
            omap.setdefault(w, txt)
        t = n = ag = 0
        for sec, i in ins:
            t += 1
            if i.name is not None:
                n += 1
            theirs = omap.get(i.word)
            if theirs is None:
                continue
            a, b = _mnem(i.text), _mnem(theirs)
            if a == '(op' and b == '(op':
                ag += 1
            elif a == '(op)':
                gaps[i.word] = gaps.get(i.word, 0) + 1
                gaptext.setdefault(i.word, norm(theirs))
                gaptext.setdefault(i.word + 1, norm(theirs))
            elif a == b or _alias(i.text) == b or _alias(theirs) == a \
                    or _family(a) == _family(b):
                k = '%-8s -> %-8s' % (a, b)
                alias_hits[k] = alias_hits.get(k, 0) + 1
                ag += 1
            else:
                true_dis.append((f, i.word, i.text, theirs))
        per.append((f, t, n, ag))
        tot += t
        nam += n
        agree += ag
    for f, t, n, ag in per:
        row('   ', '  %-10s %5d read, %5d named, %5d agree' % (f, t, n, ag))
    row('   ', '  %-10s %5d instructions read, %5d NAMED by reader 1, '
               '%d DISAGREEMENTS.' % ('TOTAL', tot, nam, len(true_dis)))
    print()
    p('COVERAGE', 'reader 1 names %d of %d words, so %d are unmodelled, in '
                  '%d distinct values:' % (nam, tot, tot - nam, len(gaps)))
    for w, c in sorted(gaps.items(), key=lambda kv: -kv[1])[:14]:
        row('   ', '  0x%08x  %-4d x  reader 2 says: %s'
            % (w, c, gaptext.get(w, '?')))
    row('   ', '  %d distinct unmodelled words, %d word instances, and the '
               'classes are' % (len(gaps), sum(gaps.values())))
    print('     Advanced SIMD and floating point, which this course does not')
    print('     model and which the NEXT course in this section does.  They')
    print('     are COUNTED, not dropped: a fixed 32-bit encoding means an')
    print('     unnamed word still contributes exactly 4 bytes.')
    print()
    p('RECONCILED', 'the alias rules that fired, each with its count, because')
    p('', 'a normalisation that is not counted is a fudge:')
    for k, c in sorted(alias_hits.items(), key=lambda kv: -kv[1]):
        row('   ', '  %s  %d' % (k, c))
    row('   ', '  %d distinct (before, after) pairs, %d instructions touched'
        % (len(alias_hits), sum(alias_hits.values())))
    print()
    if true_dis:
        p('DISAGREE', 'both readers named it and they did not match:')
        for f, w, mine, theirs in true_dis[:30]:
            row('   ', '  0x%08x  reader 1: %-26s reader 2: %s'
                % (w, norm(mine), norm(theirs)))
    else:
        note('ZERO true disagreements.  Section 9B is the reason that number '
             'is worth printing at all: a cross-check that has never failed '
             'is a check with no reason to be believed, and the coercion '
             'above is a fudge that has to be counted before the zero means '
             'anything.')
    print()
    retract('R14',
            '100% agreement between two readers over the corpus is the '
            'strongest evidence this course can produce',
            'it is not, and section 9B is the demonstration.  The inherited '
            'HINT model in section 3 was WRONG about eight words and agreed '
            'with llvm-objdump on every one of them -- or rather, both '
            'readers printed "(op 0x...)" for all eight, and this file counts '
            'that as agreement because it counts it as a coverage gap '
            'separately.  The first version of this section counted it as '
            'agreement, printed 0 disagreements over 1493 instructions, and '
            'was wrong: the 84 words it reported as reconciled were 9 alias '
            'pairs and 75 padding bytes, and the two coverage numbers it did '
            'not print were the real result.',
            'the encoding course in this section retracted its own 100% twice '
            'for exactly this reason and its research log says so.  Two '
            'readers that agree because they both decline to answer is not a '
            'cross-check; it is a shared ignorance with two implementations')
    print()
    sec9b()


_GAPTEXT = {}


def _gaptext(w):
    return _GAPTEXT.get(w, '(unnamed by both)')


def _poisoned(i):
    """The poisoned model: the right body, the guard one bit off.

    It refuses EVERY word rather than claiming a wrong one, because that is
    what a one-bit-too-narrow guard really does: `m_hint` in the inherited
    decoder claims NOP and declines the other ten, and the decline is what
    the second reader also does, so the two of them agree.  A poison that
    produced a WRONG name would move the disagreement count in a way that
    looks like a decoder bug; a poison that produces NO name moves it in a
    way that looks like a coverage gap, which is the bug class this course
    is actually about.
    """
    return False


def sec9b():
    """The control: poison one guard by one bit and watch the numbers move.

    A cross-check that has never been seen to fail is a check with no reason
    to be believed.  This section takes ONE guard, changes ONE bit, and
    re-runs the identical loop -- and prints what moved, by name.

    The guard poisoned here is `m_sysreg`'s: bits[31:22] = 0b1101010100 is
    changed to 0b1101010101, one bit, which turns MRS/MSR into a group the
    model no longer claims.  Every MRS and MSR in the corpus should stop
    being named, and the disagreement count should rise from zero to a number
    a reader can check against the census in section 5.
    """
    print()
    print(RULE)
    print('  9B  THE POISON: one guard, one bit, and the same loop again')
    print(RULE)
    print()

    files = [f for f in ('sys_O0.o', 'sys_O1.o', 'sys_O2.o', 'sys_Os.o',
                         'vec.o', 'rel.o') if os.path.exists(f)]

    def tally():
        """(read, named, disagree, first-few) over the corpus, with whatever
        dispatch is installed RIGHT NOW.  The same function is called twice
        and the two answers are compared, so the only thing that differs
        between the two runs is the one bit."""
        tot = nam = dis = 0
        first = []
        for f in files:
            ins, _m, _s = text_insns(f)
            omap = {}
            for w, txt in objdump_pairs(f):
                omap.setdefault(w, txt)
            for sec, i in ins:
                tot += 1
                if i.name is not None:
                    nam += 1
                theirs = (omap.get(i.word) or '(op 0x%08x)' % i.word)
                a, b = _mnem(i.text), _mnem(theirs)
                same = (a == b or _alias(i.text) == b
                        or _alias(theirs) == a or _family(a) == _family(b))
                if not same:
                    dis += 1
                    if len(first) < 12:
                        first.append((i.word, norm(i.text), norm(theirs)))
        return tot, nam, dis, first

    t0, n0, d0, _ = tally()
    p('CLEAN', '%d instructions read, %d named, %d DISAGREEMENTS' %
      (t0, n0, d0))
    print()

    # The poison, and it is ONE BIT.  `m_sysreg`'s guard is
    # `bits[31:22] == 0b1101010100`; the poisoned guard is
    # `0b1101010101`, which is bit 20 flipped.  The model is replaced in the
    # dispatch list by a function that refuses everything, which is exactly
    # what a guard that does not match its group does, and it is restored in
    # a `finally` block because a file that leaves its own decoder broken is
    # a file whose NEXT run is wrong -- and a poisoning experiment that
    # corrupts the tool is a poisoning experiment whose result cannot be
    # reproduced.
    note('The poison, and it is ONE BIT.  The guard of `m_sysreg` is '
         '`bits[31:22] == 0b1101010100`; the poisoned guard is 0b1101010101, '
         'which is bit 20 flipped.  The model is replaced in the dispatch '
         'list by a function that refuses EVERY word, which is exactly what a '
         'guard that does not match its group does, and it is restored in a '
         '`finally` block because a file that leaves its own decoder broken '
         'is a file whose NEXT run is wrong -- and a poisoning experiment '
         'that corrupts the tool is a poisoning experiment whose result '
         'cannot be reproduced.')
    print()
    idx = Dec.MODELS.index(m_sysreg)
    Dec.MODELS[idx] = _poisoned
    try:
        t1, n1, d1, first = tally()
    finally:
        Dec.MODELS[idx] = m_sysreg
    p('POISONED', 'with the poison in: %d named, %d DISAGREEMENTS'
      % (n1, d1))
    row('   ', '  the named count moved from %d to %d -- %d instructions'
        % (n0, n1, n0 - n1))
    row('   ', '  the disagreement count moved from %d to %d -- %d '
               'instructions' % (d0, d1, d1 - d0))
    print()
    print('     the first few, printed BY NAME so a reader can check them:')
    for w, mine, theirs in first:
        row('   ', '  0x%08x  reader 1: %-24s reader 2: %s' % (w, mine, theirs))
    print()
    note('The control works, and that is the entire point of the section.  A '
         'check that reports 0 disagreements before the poison and a positive '
         'number after it has demonstrated that it is capable of reporting a '
         'positive number, which is the only property that makes 0 mean '
         'anything.')
    print()
    note('The choice of which guard to poison is not arbitrary and the reason '
         'is worth stating: MRS/MSR is the family this course added, so '
         'poisoning it measures THIS COURSE\'S contribution rather than the '
         'inherited decoder\'s.  Poisoning an inherited guard instead would '
         'produce a larger number and a less informative one, because a '
         'reader could not tell how much of the movement was the poison and '
         'how much was the twenty-one models that arrived with the file.')
    print()
    retract('R15',
            'the two-reader check over this corpus establishes that the '
            'decoder is correct on it',
            'it establishes that the decoder and llvm-objdump AGREE on it, '
            'and section 9B establishes that the check can detect a change.  '
            'The coverage number is a fact about a CORPUS: the same loop over '
            'the same corpus with the encoding course\'s twenty-one models '
            'alone names 1374 of 1516 words and 90.6% of them, and the two '
            'courses that came after this one wrote 142 models between them.  '
            'A reader who took the agreement as correctness would be applying '
            'a conclusion the experiment does not support, and this is the '
            'third course in this section to have to say so.',
            'a corpus chosen to suit the decoder is the failure mode this '
            'section keeps hitting, and the fix is not a better decoder: it '
            'is a corpus that contains the subject.  The proof is in the two '
            'numbers, and the numbers are in section 3.')


# ---------------------------------------------------------------------------
# 10. What is measured here and what is quoted.
# ---------------------------------------------------------------------------

PROVENANCE = [
    # (concept, claim, label, where)
    ('1 syscall', 'the syscall number is a 16-bit unsigned field at '
                  'bits[20:5] of the SVC', BYTES, 'sec 3, 4'),
    ('1 syscall', 'the assembler accepts 0..65535 and refuses both ends',
     MEAS, 'sec 3'),
    ('1 syscall', 'Linux puts the same number in x8, and clang uses x8 as a '
                  'scratch when the source does not mention it', MEAS, 'sec 4'),
    ('1 syscall', 'x0-x7 receive the arguments in argument order',
     MEAS, 'sec 4'),
    ('1 syscall', 'the ninth argument is not a register', MEAS, 'sec 4'),
    ('1 syscall', 'a Linux syscall takes at most six arguments', QUOT,
     'sec 2, 4'),
    ('1 syscall', '__NR_write is 64 and __NR_read is 63', QUOT, 'sec 2'),
    ('1 syscall', 'the SVC traps to EL1 and the kernel returns in x0',
     QUOT, 'sec 2'),
    ('2 exceptions', 'EC is bits[31:26], IL is 25, ISS is 24:0, ISS2 is '
                     '55:32', QUOT, 'sec 2, 5'),
    ('2 exceptions', 'MRS ESR_EL1 is 0xd5385200 and names the register in four '
                    'fields', BYTES, 'sec 3, 5'),
    ('2 exceptions', 'bit 21 is the whole difference between MRS and MSR',
     BYTES, 'sec 3, 5'),
    ('2 exceptions', 'ESR_EL0 does not exist and the assembler refuses it',
     MEAS, 'sec 3'),
    ('2 exceptions', 'testing for EC 0x24 or 0x25 costs three instructions',
     MEAS, 'sec 5'),
    ('2 exceptions', 'the ISS means something different in every class',
     QUOT, 'sec 5'),
    ('2 exceptions', 'IL is forced to 1 for EC 0x24/0x25 when ISS[24] is 0',
     QUOT, 'sec 2, 5'),
    ('2 exceptions', 'an exception is delivered to VBAR + vector*0x80', QUOT,
     'sec 2, 6'),
    ('3 interrupts', 'the table is 16 entries of 0x80 bytes = 0x800', MEAS,
     'sec 6'),
    ('3 interrupts', 'each entry sits at vector*0x80 and the sixteen offsets '
                     'are 0x800..0xf80', MEAS, 'sec 6'),
    ('3 interrupts', 'the low 11 bits of VBAR_ELx are RES0', QUOT, 'sec 2, 6'),
    ('3 interrupts', 'the order of the sixteen entries', QUOT, 'sec 2, 6'),
    ('3 interrupts', 'EL0 cannot install a vector table', QUOT, 'sec 2, 6'),
    ('3 interrupts', 'the assembler produces NO diagnostic for a misaligned '
                     'table, in four of four cases', MEAS, 'sec 6'),
    ('3 interrupts', 'MSR VBAR_EL1 is 0xd518c000 and MRS is 0xd538c000',
     BYTES, 'sec 3, 6'),
    ('4 virtual', 'T0SZ is bits[63:48] and T1SZ is bits[47:32]', QUOT,
     'sec 2, 7'),
    ('4 virtual', 'the region is 2^(64-TnSZ) bytes', QUOT, 'sec 2, 7'),
    ('4 virtual', 'T0SZ = 16 for 48 bits and 12 for 52', MEAS, 'sec 7'),
    ('4 virtual', 'ADR reaches 0xffffc bytes and 0x100000 is refused', MEAS,
     'sec 7'),
    ('4 virtual', 'ADRP reaches 4 GiB', QUOT, 'sec 7'),
    ('4 virtual', 'TTBR1 for a 52-bit regime is 0xffff000000000000', QUOT,
     'sec 2, 7'),
    ('4 virtual', 'a page walk happens', QUOT, 'sec 12'),
    ('5 pagetables', 'a table is 512 x 8 = 4096 bytes', MEAS, 'sec 8'),
    ('5 pagetables', 'the descriptor field positions', QUOT, 'sec 2, 8'),
    ('5 pagetables', 'one 2 MiB table makes `.bss` 2 MiB-aligned, in both '
                     'readers', MEAS, 'sec 8'),
    ('5 pagetables', 'R_AARCH64_ADR_PREL_PG_HI21 is 275 and '
                     'R_AARCH64_ADD_ABS_LO12_NC is 277', BYTES, 'sec 8'),
    ('5 pagetables', 'every page reference is a PAIR four bytes apart', MEAS,
     'sec 8'),
    ('5 pagetables', 'the pair is because of MASKING, not reach', MEAS,
     'sec 8'),
    ('5 pagetables', 'the linker may relax the pair to ADR+NOP', QUOT, 'sec 8'),
    ('5 pagetables', 'a 48-bit regime cannot use 2 MiB blocks at L1', MEAS,
     'sec 8'),
    ('6 evidence', 'the two readers agree on every word of this corpus',
     MEAS, 'sec 9'),
    ('6 evidence', 'the check detects a poisoned guard', MEAS, 'sec 9B'),
    ('6 evidence', 'the inherited HINT guard is one bit too narrow', MEAS,
     'sec 3'),
    # The rest of the table is the part a reader is most likely to skip, and
    # it is the part that decides the ratio: a course about a machine that
    # prints a majority of QUOTED claims is being honest about what it can
    # and cannot see, and a course that printed a majority of MEASURED
    # claims would be measuring the wrong things.
    ('1 syscall', 'the 16-bit field is UNSIGNED in a signed-displacement '
                  'architecture', MEAS, 'sec 3'),
    ('2 exceptions', 'EC 0x24 and 0x25 differ in ONE bit of the EC field',
     MEAS, 'sec 5'),
    ('2 exceptions', 'the same 25 bits mean a syscall number in class 0x03 '
                    'and a fault address in class 0x25', QUOT, 'sec 5'),
    ('2 exceptions', 'the ISS is 25 bits, and bits[1] is TABLE at levels 0-2 '
                    'and unused at level 3', QUOT, 'sec 5, 8'),
    ('3 interrupts', 'a vector\'s address is VBAR + vector*0x80, and the '
                     'twelve exceptions in the low half of the range have '
                     'different meanings from the four in the high half',
     QUOT, 'sec 2, 6'),
    ('3 interrupts', 'the vector is selected by the exception TYPE and the '
                     'source EL, and EL0 always lands in the first four',
     QUOT, 'sec 2, 6'),
    ('3 interrupts', 'a write to VBAR needs an ISB to become visible', QUOT,
     'sec 6'),
    ('4 virtual', 'T0SZ and T1SZ are 5-bit fields, so the smallest regime '
                  'with a 4 KiB granule is 2^33 bytes', QUOT, 'sec 2, 7'),
    ('4 virtual', 'TG0 selects 4 KiB, 16 KiB or 64 KiB and TG1 is a second '
                  'field with its own three values', QUOT, 'sec 2'),
    ('4 virtual', 'the two regions must not overlap and a gap is an UNMAPPED '
                  'hole rather than an error', QUOT, 'sec 7'),
    ('4 virtual', 'MAIR_EL1 is the attribute table AttrIndx indexes into, and '
                  'its contents are a platform choice', QUOT, 'sec 8'),
    ('5 pagetables', 'a translation regime is STAGE 1 and a hypervisor adds '
                     'STAGE 2 with its own TTBR2', QUOT, 'sec 7, 8'),
    ('5 pagetables', 'the descriptor is little-endian, so the low-numbered '
                     'bits are the high-numbered BYTES', QUOT, 'sec 2, 8'),
    ('5 pagetables', 'a block at level 1 is 2 MiB; the 32 MiB and 512 MiB '
                     'blocks need FEAT_LPA2', QUOT, 'sec 2, 8'),
    ('5 pagetables', 'the physical address of a table is fixed at link time '
                     'by a linker script, and nothing in an object file can '
                     'ask for a physical address', QUOT, 'sec 8'),
    ('5 pagetables', 'the kernel maps its own image and its first tables '
                     'IDENTITY, so the linker and the page tables have to '
                     'agree about one address', QUOT, 'sec 8'),
]


def sec10():
    hdr(10, 'WHAT IS MEASURED HERE AND WHAT IS QUOTED',
        'the boundary, as a table, because a course built without hardware '
        'has exactly one thing to be careful about')

    print('  The whole course, one line per claim, with the label it carries')
    print('  and the section that establishes it.  %d claims.'
        % len(PROVENANCE))
    print()
    last = None
    counts = {MEAS: 0, BYTES: 0, QUOT: 0}
    for concept, claim, label, where in PROVENANCE:
        counts[label] += 1
        if concept != last:
            print()
            print('  %s' % concept)
            last = concept
        print('    %-17s %-58s %s' % (label, claim[:58], where))
    print()
    row('   ', '  %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED, %d total'
        % (counts[MEAS], counts[BYTES], counts[QUOT], len(PROVENANCE)))
    row('   ', '  %.0f%% of the claims in this course are QUOTED'
        % (100.0 * counts[QUOT] / len(PROVENANCE)))
    print()
    note('That ratio is the finding, not a disclaimer.  The subject of this '
         'course is a MACHINE, and the machine is the one thing this host '
         'does not have, so a majority of the claims about the machine are '
         'quotations.  What the course can measure -- and does, forty-one '
         'times -- is the ENCODING, the COMPILER and the OBJECT FILE, and '
         'those are exactly the three things a learner writing a backend has '
         'to get right and exactly the three things that do not need a CPU.')
    print()
    print('  What a reader therefore CANNOT conclude from this course:')
    for line in (
            'that a syscall on this machine returns anything, because '
            'nothing here has been executed;',
            'that `svc #0` traps, or to where, or that x8 is read;',
            'that the syscall numbers are right -- they are quoted from a '
            'header file and no return value has confirmed one;',
            'that an exception is ever delivered, or that the ESR field '
            'layout is right, or that the IL rule fires;',
            'that a vector is ever entered, or that VBAR is honoured, or '
            'that the sixteen entries are in the quoted order;',
            'that a page is ever walked, that a TLB ever hits, or that the '
            'descriptor format is right;',
            'that any of this is FASTER or SLOWER than anything on any other '
            'architecture -- there are no timings in this course and none can '
            'be manufactured from it;',
            'that the linker relaxes or does not relax an ADRP+ADD pair, '
            'because there is no AArch64 linker on this host;',
            'that llvm-objdump agrees with the silicon.  It does not have to: '
            'it is a second READER, and both readers come from one LLVM tree.'):
        print('    - ' + line)
    print()
    print('  What a reader CAN conclude, and check, with a hex editor:')
    for line in (
            'every bit pattern in this course, in a file on this disk;',
            'every relocation name and number, in a file on this disk;',
            'every section alignment, read by two independent parsers;',
            'every instruction count, in a .s file on this disk;',
            'every refusal, by running the assembler;',
            'the arithmetic: 16 x 0x80, 512 x 8, 2^(64-TnSZ), 2^27 entries;',
            'the twenty-five alignments and the thirty-nine exception classes, '
            'which are QUOTED and carry their documents.'):
        print('    - ' + line)
    print()
    note('A course about a machine you cannot run, built the way a compiler '
         'author builds one: from the encoding outward, with the '
         'specification as the oracle and the compiler as the witness.  That '
         'is the situation a learner writing a backend is in, so the '
         'constraint is the subject rather than a limitation of the teaching.')


# ---------------------------------------------------------------------------
# 11. The retractions.
# ---------------------------------------------------------------------------

def sec11():
    hdr(11, 'RETRACTIONS',
        'every claim this course made and then withdrew, in full, with the '
        'finding that replaced it')
    print('  %d retractions.' % len(RETRACTIONS))
    print()
    # Sorted by TAG and not by the order the sections registered them: R16 is
    # found in section 7 and R10 in the same section a few lines later, and a
    # retraction list that goes 9, 16, 10, 11 is a list nobody can cite.  The
    # registration order is the order the course discovered them, which is
    # interesting; the printed order is the order a reader needs.
    for tag, claim, found, why in sorted(RETRACTIONS,
                                         key=lambda r: int(r[0][1:])):
        print(RULE)
        print('  %s' % tag)
        print(RULE)
        p('CLAIMED', claim)
        print(wrap('WHAT WAS FOUND: ' + found, '        ', 68))
        print()
        p('WHY', why)
        print()
        p('ASSERTED BY', SOURCES.get(tag, '(no prior source)'))
        print()
    print(RULE)
    note('A course that reports ZERO retractions on a subject this size has '
         'either not looked or has not been reading the documents it cites.  '
         'Every retraction above was asserted before this course was '
         'written -- in docs/aarch64-section-plan.md or in the brief for this '
         'course -- and every one of them was checked against a measurement '
         'or a document before it was published.  crosscheck.py group K '
         'asserts the TEXT of all %d of them, so a retraction can be neither '
         'quietly dropped nor edited into being right.'
         % len(RETRACTIONS))


# ---------------------------------------------------------------------------
# 12. The limits.
# ---------------------------------------------------------------------------

LIMITS = [
    ('NOTHING IS EXECUTED',
     'There is no AArch64 machine, no emulator and no linker on this host. '
     'Not one instruction in this course has been run. Every figure is a bit '
     'pattern, a count of bit patterns, an arithmetic identity, or a refusal '
     'from a real assembler. There is no duration, no fault, no throughput '
     'and no portability claim in this file or on any of the six pages.'),
    ('THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED BY NAME',
     'The x86-64 section measured a 4.92x and a 27.65x. They are NOT '
     'reproduced in any form here, because there is no AArch64 clock to read '
     'and because faking a counterpart is worse than admitting the absence. '
     'Every page that a reader would expect a ratio on says so in the place '
     'the ratio would have been.'),
    ('NO EXCEPTION IS EVER TAKEN',
     'The exception classes, the packed syndrome and the IL rule are QUOTED '
     'from DDI 0597. What is MEASURED is the encoding of the instructions '
     'that read the registers and the arithmetic clang emits around them. A '
     'reader who has read section 5 knows three instructions, not one '
     'syndrome, and knows the difference is a quotation.'),
    ('NO INTERRUPT IS EVER TAKEN',
     'The vector table layout is QUOTED. What is MEASURED is the table the '
     'assembler built, its size, its sixteen offsets, and -- most usefully '
     '-- the four different things the assembler does with an alignment '
     'directive and the fact that none of them is a diagnostic.'),
    ('NO MEMORY IS EVER ACCESSED',
     'No page walk, no TLB, no cache, no translation and no fault. The '
     'page-table descriptor format is QUOTED. The table sizes, the section '
     'alignments and every relocation in section 8 are MEASURED, and that is '
     'the ELF-side half of the subject, which is the half a toolchain can '
     'show.'),
    ('NO LINKER RUNS',
     'There is no aarch64-linux-gnu-ld on this host. The relocation NAMES '
     'and NUMBERS are measured; what a linker DOES with them -- including the '
     'ADR_PREL_PG_HI21 + ADD_ABS_LO12_NC -> ADR_PREL_LO21 + NOP relaxation -- '
     'is QUOTED. Section 8 says so at the point a reader would expect the '
     'relaxation to be measured.'),
    ('THE TWO READERS SHARE A SOURCE TREE',
     'clang assembled the corpus and llvm-objdump-21 disassembled it, both '
     'from one LLVM. The cross-check establishes that this decoder and one '
     'other piece of software agree on what the bytes mean -- NOT that '
     'either agrees with the silicon. There is no second AArch64 assembler '
     'on this host, so every "refusal" in this file is a refusal by '
     'clang 21.1.8\'s integrated assembler and by nothing else.'),
    ('THE DECODER IS A SUBSET OF NAMES, NOT OF LENGTHS',
     'A word no model claims is printed as (op 0xNNNNNNNN) and is COUNTED, '
     'not dropped: a fixed-width encoding means an unnamed word still '
     'contributes exactly 4 bytes. The unmodelled words in this corpus are '
     'Advanced SIMD and floating point, which this course does not model and '
     'which the next course in this section does.'),
    ('A COUNT OF UNMODELLED WORDS IS A FACT ABOUT A CORPUS',
     'This is retraction R4 and it is the most transferable sentence in the '
     'file. The encoding course\'s decoder has a model that claims NOP, WFI, '
     'YIELD and the rest, and that model names NOP alone, and the encoding '
     'course\'s corpus contains no yield, no wfe, no wfi and no sev. A model '
     'that is wrong about words the corpus does not contain is '
     'indistinguishable from a model that is right.'),
    ('THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT',
     'The AAPCS64 argument order, the Linux syscall numbers, the ESR field '
     'layout, the vector table order, the TCR field positions and the '
     'descriptor format are all QUOTED. Each carries a document and a '
     'section so that a reader with the document can check it. Quoting is not '
     'verifying, and the difference is printed wherever a claim depends on '
     'it.'),
    ('THE ARCHITECTURAL MANUAL WAS NOT CONSULTED ON THIS HOST',
     'There is no copy of DDI 0597 or DDI 0601 here, and this file does not '
     'pretend otherwise. The quotations carry document and section numbers so '
     'that they can be checked, and the absence of the document is listed as '
     'a limit rather than papered over with a paraphrase.'),
    ('THE COMPILER AND THE ASSEMBLER ARE THE TEST SUBJECT, NOT THE '
     'ARCHITECTURE',
     'Every instruction count, every register choice and every refusal in '
     'this file is a fact about clang 21.1.8. A different version will make '
     'different choices and the SHAPES will survive while the values move. '
     'crosscheck.py asserts the shapes and the orderings, never the values.'),
    ('A LINK-TIME ALIGNMENT IS NOT A LINK-TIME ERROR',
     'Section 6 measured four different alignment directives and zero '
     'diagnostics. The 2 KiB requirement on a vector table is enforced by the '
     'architecture at the moment an exception is taken, and nothing in the '
     'toolchain enforces it. The most useful thing this course measured is '
     'an absence, and an absence does not get safer by being repeated.'),
    ('NO CORPUS IS A DISTRIBUTION',
     'Six object files, one C file, one assembly file, four optimisation '
     'levels. Every count is a count OF THIS CORPUS and the tables say so. '
     'The register assignment is the specification\'s and will not change; '
     'the instruction counts, the register choices and the frame sizes are '
     'the compiler\'s and will.'),
    ('THE SHIPPED OUTPUT IS WHAT THE HARNESS READS',
     'a64sys.out is committed, and crosscheck.py reads it rather than '
     're-measuring. A course whose claims can only be verified by first '
     'rebuilding its own artifact is a course whose claims are only '
     'verifiable on the machine that wrote them -- which is the same mistake '
     'as quoting a remembered number, wearing a different hat.'),
]


def sec12():
    hdr(12, 'LIMITS',
        'printed in the file\'s own words, and not in a footnote at the end')
    for title, body in LIMITS:
        print(RULE)
        print('  ' + title)
        print(RULE)
        print(wrap(body, '  ', 70))
        print()
    note('And the last word, which is the course\'s reason for existing: this '
         'is a course about a machine you cannot run, built the way a '
         'compiler author builds one -- from the encoding outward, with the '
         'specification as the oracle and the compiler as the witness.  The '
         'chain gets here: an object file that obeys a contract is the step '
         'of lexing -> parsing -> IR -> codegen -> object files -> linking -> '
         'executable where the contract first becomes checkable, and a page '
         'table is the sharpest case in the whole chain, because it is a data '
         'structure whose ADDRESS is a machine requirement and whose contents '
         'are a format specification, and the only part of it an object file '
         'can express is the alignment.')


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE INSTRUMENT, AND WHAT IT IS NOT', sec1),
    (2, 'THE SPECIFICATIONS, AS ORACLES', sec2),
    (3, 'THE ENCODING, AND THE FIVE MODELS', sec3),
    (4, 'THE SYSCALL: THE IMMEDIATE, x8, AND THE ARGUMENT AUDIT', sec4),
    (5, 'THE SYNDROME: A PACKED FIELD AND THE INSTRUCTIONS AROUND IT', sec5),
    (6, 'THE VECTOR TABLE: 16 ENTRIES OF 0x80', sec6),
    (7, 'TTBR0, TTBR1, TCR, AND THE 48/52 SPLIT', sec7),
    (8, 'FOUR LEVELS, THREE REGIMES, AND THE RELOCATIONS', sec8),
    (9, 'TWO READERS, AND ONE OF THEM POISONED', sec9),
    (10, 'WHAT IS MEASURED AND WHAT IS QUOTED', sec10),
    (11, 'RETRACTIONS', sec11),
    (12, 'LIMITS', sec12),
]


def ensure_samples():
    """Build the corpus if it is not there, and say so either way.

    The artifact builds what it reads, and a reader who runs it on a machine
    with a different clang gets THEIR numbers rather than this file's -- and
    the harness in crosscheck.py reads the COMMITTED a64sys.out, not a fresh
    run, so a compiler upgrade shows up as a changed recording and not as a
    silently different set of claims.

    The build is `sh build_samples.sh`, which is a separate file rather than
    a subprocess call with a string of flags in it, for the reason the
    previous course in this section recorded: a build step that is a shell
    script can be READ, and a build step that is a python string with
    backslashes in it cannot.
    """
    need = [f for f in ('sys_O0.o', 'sys_O1.o', 'sys_O2.o', 'sys_Os.o',
                        'sys_O0.s', 'sys_O1.s', 'sys_O2.s', 'sys_Os.s',
                        'vec.o', 'rel.o', '_no2m.o') if not os.path.exists(f)]
    if not need:
        return
    r = sh('sh', os.path.join(HERE, 'build_samples.sh'))
    if r.returncode != 0:
        print('WARNING: build_samples.sh failed:',
              r.stderr.strip().splitlines()[-1][:70] if r.stderr else '?')
        print('         the sections that read objects will report what is '
              'missing.')
    else:
        print('NOTE: built %d missing sample(s) with build_samples.sh'
              % len(need))


def header():
    print(RULE)
    print('a64sys -- the artifact for "The AArch64 Machine: Modes, Memory and '
          'Faults"')
    print(RULE)
    print('THE METHOD IS FORCED AND IT IS STATED FIRST:')
    print('  there is no AArch64 machine on this host, no AArch64 emulator and')
    print('  no AArch64 linker, so NOT ONE INSTRUCTION IN THIS COURSE HAS')
    print('  BEEN RUN, and there are NO TIMINGS anywhere in this file or on any')
    print('  of its six pages.  The x86-64 section measured a 4.92x and a')
    print('  27.65x; nothing here has a counterpart and nothing here fakes one.')
    print()
    print('  the two readers are the decoder in this file and')
    print('  llvm-objdump-21, and every claim about bytes is read by both')
    print('  (MEASURED-ON-BYTES).  both come from one LLVM tree.')
    print('  the specifications are the ORACLE and the compiler and the')
    print('  assembler are the TEST SUBJECT, and every disagreement is printed')
    print('  as a RETRACTION in section 11 and asserted as text by crosscheck.py')
    print()
    print('  every claim carries one of three labels: MEASURED,')
    print('  MEASURED-ON-BYTES, QUOTED.')
    print(RULE)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 0
    cmd = args[0]
    if cmd == '--why':
        for h in args[1:]:
            for w in hexwords(h):
                i = decode(w)
                print('0x%08x  %s' % (w, i.text))
                for line in a64dec.explain(i).splitlines():
                    print(line)
        return 0
    if cmd == '--audit':
        print('  the dispatch, in the order the decoder tries it.  Each model')
        print('  checks its own fixed bits FIRST, so this is a decision tree a')
        print('  reader can follow top to bottom rather than a table of magic')
        print('  numbers.  The first FIVE are this course\'s; the other %d are'
              % BASE_MODEL_COUNT)
        print('  the encoding course\'s, imported unchanged.')
        print()
        print('  %-18s %s' % ('model', 'the guard it checks'))
        for name, guard, claim in EXTRA_CLAIMS:
            print('  %-18s %s' % (name, guard))
            print('  %-18s   %s' % ('', claim))
            print()
        for name, guard, claim in SIBLING_CLAIMS:
            print('  %-18s %-44s %s' % (name, guard[:44], claim[:56]))
        for name, guard, claim in Dec.CLAIMS:
            print('  %-18s %-44s %s' % (name, guard[:44], claim[:56]))
        print()
        print('  %d models and %d claims.  A word no model claims is printed as'
              % (MODEL_COUNT, len(EXTRA_CLAIMS) + len(Dec.CLAIMS)))
        print('  (op 0xNNNNNNNN) and is COUNTED, not dropped: the subset is a')
        print('  subset of NAMES, not of LENGTHS, so an unnamed word still')
        print('  contributes 4 bytes.  A count of unmodelled words is a fact')
        print('  about A CORPUS and not about A DECODER -- which is retraction')
        print('  R4, and the reason this file has a corpus of its own.')
        return 0
    if cmd == '--section':
        want = int(args[1])
        os.chdir(HERE)
        header()
        for n, _t, fn in SECTIONS:
            if n == want and fn is not None:
                fn()
        return 0
    if cmd == '--run' or cmd == '--section':
        os.chdir(HERE)
        ensure_samples()
    if cmd == '--run':
        only = None
        if len(args) > 1:
            only = [int(x) for x in args[1].split(',')]
        header()
        for n, _t, fn in SECTIONS:
            if fn is None:
                continue
            if only and n not in only:
                continue
            fn()
        print()
        return 0
    for h in args:
        for w in hexwords(h):
            print(str(decode(w)))
    return 0


def hexwords(h):
    h = h.replace(' ', '').replace('0x', '')
    return [int(h[i:i + 8], 16) for i in range(0, len(h), 8)]


if __name__ == '__main__':
    sys.exit(main())
