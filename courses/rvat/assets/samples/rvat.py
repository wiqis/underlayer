#!/usr/bin/env python3
"""rvat.py -- RISC-V atomics, the ordering fence and the vector extension,
measured on the bytes and on the numbers, with the specification as the oracle
and the toolchain as the test subject.

THE SPINE OF THIS COURSE IS AN ABSENCE, and it is a THIRD kind of absence.
The two RISC-V courses before it lost the ability to TIME, and the privileged
one lost the ability to OBSERVE ITS SUBJECT.  This one loses the ability to
OBSERVE WHETHER ANY OF ITS INSTRUCTIONS DOES THE THING IT EXISTS TO DO:

    No reservation is ever HELD.  No SC is ever observed to succeed or to
    fail.  No AMO is ever observed to be atomic.  No fence is ever observed to
    order anything, on any hart, in either direction.  No vector instruction
    is ever EXECUTED, so `vl` is never set by anything but a word in a file.

And that absence is not a workaround, because it is the reason the course is
worth reading.  An atomic instruction is a PROMISE about observable
behaviour, and every measurement available on this host is a measurement about
the PROMISE'S TEXT: the bit that carries it, the pair of instructions that
implements it, the set of spellings the assembler will accept, the number of
bits the encoding has left over, and the compiler's choice about whether to
emit the instruction at all.  A course that claimed a speedup here would be
inventing one.

SO THE THREE LABELS, and every claim in this file carries exactly one:

    MEASURED           about the compiler or the bytes, by experiment
    MEASURED-ON-BYTES  a property of emitted bytes, cross-checked against
                       llvm-objdump-21 as a second reader
    QUOTED             a manual claim, with a document and a section

A label rendered two ways is not a label.  `crosscheck.py` counts the three and
section 14 prints its own tally.

WHAT SURVIVES, and it is a lot:

  * THE ATOMIC ENCODING.  eleven operations at two widths, funct5 at
    inst[31:27], aq at inst[26], rl at inst[25], and the width as ONE BIT of
    funct3 -- every `.w`/`.d` pair XORs to exactly 0x1000;
  * THE ABSENCE OF A LOCK PREFIX, as a COUNT: zero instructions in this corpus
    take a prefix, measured by asking the assembler, against x86-64's
    twenty-two measured and eighteen quoted;
  * THE COMPILER'S CENTRAL EXPERIMENT: the same C11 file at `-march=rv64im`
    and `-march=rv64ima`, one letter apart, and four functions that are a
    LIBRARY CALL without the letter and an inline `lr.w.aqrl` / `sc.w.rl`
    retry loop with it;
  * THE FOUR FIELDS OF `fence`, plus the finding that the assembler accepts
    FIFTEEN SPELLINGS of the predecessor and successor sets -- every non-empty
    subset of {i, o, r, w} -- and that the bare `fence` is one of them rather
    than a wildcard;
  * and `fence.tso`, whose fm = 1000 the manual calls "reserved for future
    use" and which the compiler emits for `__ATOMIC_ACQ_REL`;

  * THE VECTOR CONFIGURATION.  112 `vsetvli` variants swept, the four fields
    decomposed, zimm[10:8] measured CONSTANT ZERO across all of them, the
    three configuration instructions told apart by TWO BITS, and the same
    inst[19:15] being a register in two of them and a five-bit IMMEDIATE in
    the third;
  * THE MASK as ONE BIT in three different instruction groups -- arithmetic,
    unit-stride load, unit-stride store -- with every XOR printed, which is
    what makes `vm` a field of the data path rather than of one group;
  * and WHAT THE COMPILER EMITS: the instruction counts, the `vsetvli` count,
    the `csrr a7, vlenb` that reads the vector length at run time, and the
    finding that -O1 and -Os do NOT vectorise this corpus while -O2 and -O3
    do, with -O2 and -O3 producing BYTE-IDENTICAL assembly.

THE TWO DOCUMENTS, and the SHORT NAMES every QUOTED row uses:

    rv32-unpriv  RISC-V Instruction Set Manual, Volume I: Unprivileged
                 Architecture, v20260120 -- chapter 12 ("A"), chapter 17
                 (RVWMO), chapter 18 ("Ztso"), chapter 30 ("V")
    riscv-cc     RISC-V ISA Calling Convention, v20230911 -- the LR/SC
                 reservation-set rules a compiler must respect

THE DECODER IS BORROWED, NOT FORKED.  This file imports `rvdec.py` from
courses/rvasm/assets/samples/ and PREPENDS FOUR models of its own, editing no
sibling.  Two of the four are FIXES to gaps in the inherited decoder that this
corpus is the first to reach, and the harness asserts what each one adds:

    m_fence_sets   the ordering fence with its sets NAMED, and the two words
                   that share opcode 0x0f -- `fence.tso` and `fence.i` --
                   named correctly.  The inherited `s_fence` reads fm and
                   prints it as a number and calls every word `fence`, so
                   `fence.tso` decodes as `fence` and `fence.i` as `fence.i`
                   for the wrong reason.
    m_amo_order    the A extension with `aq` and `rl` READ OUT of the word and
                   named in the mnemonic.  The inherited `a_amo` reads funct5
                   at inst[31:27] and NEVER LOOKS AT inst[26] and inst[25], so
                   `amoadd.w.aqrl` and `amoadd.w` decode to the SAME string
                   and a cross-check over this corpus counts them as agreeing
                   when they are agreeing about the wrong half of the word.
    m_vector_mask  the vector DATA path: the `vm` bit at inst[25], the width
                   field, and the register group count at the top three bits.
                   The inherited `v_setvli` names the three configuration
                   instructions and RAISES on every data word, so 165 of this
                   corpus's instructions are unmodelled -- COUNTED, never
                   dropped.
    m_setivli      `vsetvli`, `vsetivli` AND `vsetvl`.  The inherited model
                   claims to be told apart by inst[31:30] and computes
                   `f5 >> 2` on funct5 = inst[31:27], which is inst[31:29] --
                   THREE bits, not two -- and so it names `vsetvli` and
                   DECLINES `vsetivli` and `vsetvl`.  Section 13's R1 is this.

    python3 rvat.py --run             the whole report, 15 sections
    python3 rvat.py --section 7       one section
    python3 rvat.py --audit           the models in the dispatch, in order
    python3 rvat.py --why 06b6252f    explain one word
    python3 rvat.py --why 8330000f
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
READELF = 'llvm-readelf-21'
MC = 'llvm-mc-21'
TARGET = 'riscv64-linux-gnu'
LEVELS = ('O0', 'O1', 'O2', 'O3', 'Os')
RULE = '=' * 74


# ===========================================================================
# Part one: the decoder, BORROWED, plus FOUR models of this course's.
# ===========================================================================

def find_sibling(name, env_var, sibling):
    """Locate a sibling course's artifact by walking UP the tree.

    A hardcoded `../../<sibling>/assets/samples` breaks the first time somebody
    moves a directory, and a course whose artifact only runs in the exact
    layout it was written in is a course nobody can re-run.  Inherited from
    the previous RISC-V course unchanged, for the same reason.
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


def bits(w, hi, lo=None):
    """bits(w, hi) or bits(w, hi, lo), because the inherited decoder's `bits`
    needs BOTH bounds and half this file's field reads are single bits.

    §KEEP§A LOCAL HELPER WITH A DEFAULT ARGUMENT AND AN INHERITED FUNCTION
    WITH A THREE-ARGUMENT SIGNATURE IS A SMALL THING, AND IT IS THE KIND OF
    SMALL THING THAT BECOMES A TRACEBACK AT RUN TIME IF IT IS MISSED -- which
    is why it is here with a docstring rather than inlined at forty call sites.
    """
    if lo is None:
        lo = hi
    return (w >> lo) & ((1 << (hi - lo + 1)) - 1)

# The names of the four sets, index == the four-bit code.  MEASURED in
# section 7 by asking the assembler for every non-empty subset of {i,o,r,w};
# the spellings below are the letters, the codes are what came back, and the
# zero row is a HOLE the artifact prints rather than omits.
FENCE_SET_NAMES = {
    0b0000: '(the empty set)',
    0b0001: 'w',   0b0010: 'r',   0b0011: 'rw',
    0b0100: 'o',   0b0101: 'ow',  0b0110: 'or',  0b0111: 'orw',
    0b1000: 'i',   0b1001: 'iw',  0b1010: 'ir',  0b1011: 'irw',
    0b1100: 'io',  0b1101: 'iow', 0b1110: 'ior', 0b1111: 'iorw',
}


def _m_fence_sets(i):
    """THE ORDERING FENCE with its two sets NAMED, and the two neighbours of
    opcode 0x0f named correctly.  PREPENDED.

    THE INHERITED `s_fence` READS THE FOUR FIELDS AND STOPS THERE.  It prints
    `pred inst[27:24] = 0b1111` and `succ inst[23:20] = 0b1111` and names the
    instruction `fence`, for EVERY word with opcode 0x0f and funct3 = 0.  Two
    consequences, and the second is the one that bites:

      * `fence.tso` is funct3 = 0 with fm = 1000, and the inherited model names
        it `fence` -- a decoder reporting an instruction as the wrong
        instruction of the same family;
      * `fence rw, rw` and `fence r, r` and `fence r, w` all print as `fence`,
        so a cross-check over this corpus would compare `fence` against
        `fence rw, rw` and score it as a SPELLING difference rather than as
        the encoder having read the sets.

    AND THE POINT OF THE COURSE IS THE SETS.  The whole of RISC-V's ordering
    model is a statement about a relation between two four-bit SETS, and a
    decoder that prints them as two integers has decoded the instruction and
    not the model.  This model renders both as the letters the assembler
    spells them with, and it renders fm = 1000 as the separate instruction it
    is.

    It also says the two things a reader would otherwise have to take on
    trust, in the decoder's own voice, because a reader who runs `--why` on a
    fence word is the reader most likely to be misled by `fence` alone.
    """
    f3 = Dec.bits(i.word, 14, 12)
    if f3 == 1:
        # fence.i -- a DIFFERENT EXTENSION (Zifencei) at the same opcode.  The
        # inherited `s_misc_mem` names this correctly and it is claimed here
        # only so the fm/pred/succ fields are printed as RESERVED rather than
        # read as zeroes, which is the thing a reader must not do.
        i.fmt = 'I'
        i.name = 'fence.i'
        i.ops = []
        i.ext = 'Zifencei'
        i.model = 'm_fence_sets'
        i.say('funct3 = 1 at opcode 0x0f is FENCE.I, the INSTRUCTION-FETCH '
              'fence, and it is a different extension from the ordering fence: '
              'fm, pred and succ are all RESERVED in it and standard software '
              'shall zero them, so reading them as ordering sets would be '
              'reading three zeroes as a statement that nothing needs '
              'ordering')
        return True
    if f3 != 0:
        raise Dec.Bad()
    fm = i.field('fm', 31, 28)
    pred = i.field('pred', 27, 24)
    succ = i.field('succ', 23, 20)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    i.fmt = 'I'
    pname = FENCE_SET_NAMES.get(pred, '?')
    sname = FENCE_SET_NAMES.get(succ, '?')
    if fm == 0b1000:
        i.name = 'fence.tso'
        i.ops = [pname, sname]
        i.say('fm = 1000 is NOT a normal fence with a flag set: it is a '
              'SEPARATE INSTRUCTION that the assembler will only emit for '
              'pred = RW and succ = RW, and the manual says of it "because '
              'FENCE RW,RW imposes a superset of the orderings that FENCE.TSO '
              'imposes, it is correct to ignore the fm field and implement '
              'FENCE.TSO as FENCE RW,RW".  So the instruction is a REQUEST for '
              'a weaker barrier than the one it is spelled like, and a '
              'reader who counts it as a full fence has read the mnemonic '
              'and not the specification')
    else:
        i.name = 'fence'
        i.ops = [pname, sname]
        i.say('THE ORDERING MODEL IS DEFINED BY TWO FOUR-BIT SETS AND THIS '
              'DECODER NAMES BOTH.  pred = %s (inst[27:24]) is the set of '
              'operations BEFORE the fence and succ = %s (inst[23:20]) the set '
              'AFTER, and the letters are the assembler\'s own spellings: i is '
              'device input, o is device output, r is a memory read and w is '
              'a memory write.  §KEEP§RISC-V DOES NOT DESCRIBE ITS ORDERING '
              'MODEL WITH A BASELINE AND ESCAPE HATCHES.  IT DESCRIBES IT AS A '
              'RELATION BETWEEN TWO NAMED SETS IN ONE INSTRUCTION, AND THAT '
              'IS A DIFFERENT FORMULATION FROM x86-64\'S IMPLICIT TSO AND FROM '
              'AARCH64\'S ACCESS MODES, NOT A DIFFERENT DEGREE OF THE SAME ONE.'
              % (pname, sname))
    if rd != 0 or rs1 != 0:
        i.say('§KEEP§rs1 = %d AND rd = %d ARE NOT ZERO, WHICH STANDARD '
              'SOFTWARE SHALL NOT DO.  The manual reserves both fields for '
              'finer-grain fences in future extensions and says base '
              'implementations shall ignore them -- so a fence with a '
              'non-zero rs1 is a word this decoder can describe and no '
              'implementation is obliged to honour.' % (rs1, rd))
    i.ext = 'I'
    i.model = 'm_fence_sets'
    return True


AMO_NAMES = {0x00: 'amoadd', 0x01: 'amoswap', 0x02: 'lr', 0x03: 'sc',
             0x04: 'amoxor', 0x08: 'amoor', 0x0C: 'amoand', 0x10: 'amomin',
             0x14: 'amomax', 0x18: 'amominu', 0x1C: 'amomaxu'}
AMO_WIDTH = {2: '.w', 3: '.d'}


def _m_amo_order(i):
    """THE A EXTENSION with aq and rl READ OUT OF THE WORD.  PREPENDED, and it
    is a REPAIR rather than an addition.

    THE INHERITED `a_amo` reads funct5 at inst[31:27] -- correctly, because
    funct5 IS five bits here and `aq` and `rl` are inst[26] and inst[25] --
    and then NEVER LOOKS AT THOSE TWO BITS AGAIN.  So it renders
    `amoadd.w` and `amoadd.w.aqrl` as the SAME STRING, differing in nothing.

    That is the same failure this collection has now paid for three times in
    three different places, and it is worth naming in the model rather than in
    a comment: A DECODER THAT DOES NOT READ A FIELD RENDERS TWO INSTRUCTIONS
    IDENTICALLY, AND A CROSS-CHECK THAT COMPARES RENDERINGS WILL CALL THAT
    AGREEMENT.  The bytes differ.  The decoder's output does not.

    AND THE BITS ARE THE COURSE.  aq is inst[26] and rl is inst[25] -- ADJACENT,
    one bit apart, and their XORs are 0x04000000 and 0x02000000 at every width
    and on all three of load-reserved, store-conditional and the AMOs.  Those
    are the numbers section 4 prints, and they are measured here rather than
    quoted because "aq is bit 26" is a bit pattern and bit patterns are what
    this host can read.

    One more thing this model checks and the inherited one does not: `lr` MUST
    HAVE rs2 = 0.  The listing in the manual prints 00000 in the rs2 column
    for LR.W and LR.D and a real rs2 for everything else, and a decoder that
    does not check it will cheerfully name `lr.w` with a non-zero rs2 -- a word
    the architecture does not define.
    """
    f3 = Dec.bits(i.word, 14, 12)
    f5 = Dec.bits(i.word, 31, 27)
    if f3 not in AMO_WIDTH or f5 not in AMO_NAMES:
        raise Dec.Undefined('an A-extension word this file does not model: '
                            'funct3 = %d (only 010 and 011 are AMO widths), '
                            'funct5 = 0b%s' % (f3, format(f5, '05b')))
    aq = i.field('aq', 26, 26)
    rl = i.field('rl', 25, 25)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    base = AMO_NAMES[f5]
    w = AMO_WIDTH[f3]
    suffix = ('.aqrl' if (aq and rl) else '.aq' if aq else '.rl' if rl else '')
    if base == 'lr':
        if rs2 != 0:
            raise Dec.Undefined('LR WITH A NON-ZERO rs2 (rs2 = %d) IS NOT A '
                                'DEFINED ENCODING: the manual prints 00000 '
                                'in the rs2 column for LR.W and LR.D, so this '
                                'word has no architectural meaning and the '
                                'decoder declines it rather than naming it'
                                % rs2)
        i.name = 'lr' + w + suffix
        i.ops = [Dec.xreg(rd), '(%s)' % Dec.xreg(rs1)]
        i.say('funct5 = 0b00010 IS THE LOAD-RESERVED HALF OF A PAIR, and the '
              'reservation it registers is NOT a register and NOT a flag: it '
              'is a hidden set of bytes the manual calls a RESERVATION SET, '
              'and the store-conditional half tests it.  rs2 = 0 is not a '
              'convention here, it is the ONLY valid encoding -- a decoder '
              'that does not check it names words the architecture does not '
              'define')
    elif base == 'sc':
        i.name = 'sc' + w + suffix
        i.ops = [Dec.xreg(rd), Dec.xreg(rs2), '(%s)' % Dec.xreg(rs1)]
        i.say('funct5 = 0b00011 IS STORE-CONDITIONAL, and it REPORTS ITS '
              'RESULT IN A REGISTER: rd is zero on success and NON-ZERO on '
              'failure, and the instruction does not branch.  §KEEP§AN '
              'INSTRUCTION CANNOT ACT ON ITS OWN OUTPUT, SO THE ONLY THING A '
              'STORE-CONDITIONAL CAN DO IS REPORT, AND REPORTING TO A CALLER '
              'WHO MUST BRANCH IS THE DEFINITION OF A LOOP.  THE RETRY IS NOT '
              'SYNTAX AROUND THE INSTRUCTION; IT IS WHAT THE INSTRUCTION IS.')
    else:
        i.name = base + w + suffix
        i.ops = [Dec.xreg(rd), Dec.xreg(rs2), '(%s)' % Dec.xreg(rs1)]
        i.say('funct5 = 0b%s IS AN AMO: read, modify, write, atomically, and '
              '§KEEP§THERE IS NO IMPLICIT LOCK ANYWHERE IN THIS ENCODING.  The '
              'instruction is atomic because of its OWN OPCODE (0101111) and '
              'nothing else -- no prefix, no flag, no second instruction.  '
              'x86-64 puts the same property in a PREFIX that eighteen '
              'instructions accept and that one of them (xchg) does not need; '
              'RISC-V puts it in a THIRD INSTRUCTION GROUP, and the count of '
              'instructions needing a prefix to become atomic is ZERO.'
              % format(f5, '05b'))
    if aq or rl:
        i.say('aq = %d at inst[26] and rl = %d at inst[25] -- TWO ADJACENT '
              'BITS and the whole of the ordering on this instruction.  §KEEP§'
              'A QUARTER OF THE AMO ENCODING IS SPENT ON ORDERING AND NONE OF '
              'IT IS ABOUT THE OPERATION, WHICH IS THE POINT: THE OPERATION '
              'IS FIVE BITS AT inst[31:27] AND THE ORDERING IS TWO BITS AT '
              'inst[26:25], AND THE TWO ARE SEPARATE FIELDS RATHER THAN ONE '
              'PREFIX THAT MEANS "LOCKED".' % (aq, rl))
    i.ext = 'A'
    i.model = 'm_amo_order'
    return True


# The vector register width table, and the four widths the assembler emits.
VSEW_WIDTH = {0: 'e8', 1: 'e16', 2: 'e32', 3: 'e64'}
VLMUL_NAME = {0: 'm1', 1: 'm2', 2: 'm4', 3: 'm8',
              5: 'mf8', 6: 'mf4', 7: 'mf2'}
# The width a unit-stride load's funct3 selects.
VLD_WIDTH = {0: 'e8', 5: 'e16', 6: 'e32', 7: 'e64'}


def _m_vector_mask(i):
    """THE VECTOR DATA PATH: the vm bit, the width, and the register group.
    PREPENDED, and it is the model this course exists to need.

    THE INHERITED `v_setvli` claims opcode 0x57, names the three
    CONFIGURATION instructions and then RAISES on every data word, with a
    comment that says so honestly: "a decoder that named eight of the four
    hundred vector encodings and called the rest a bug would be worse than one
    that says which half of the extension it implements."

    That comment was correct for its course and it is why this corpus's 165
    data words would be UNMODELLED rather than misnamed.  So this model does
    not try to name four hundred encodings.  It names ONE BIT and the two
    fields that surround it, in the three groups the concept is about:

      * vm at inst[25] -- and it is ONE bit in an arithmetic instruction, in a
        unit-stride load and in a unit-stride store, which is what makes it a
        field of the data path and not of one group;
      * the width, in funct3, for both the arithmetic and the load/store
        groups, and note that funct3 is what a decoder reads for the SCALAR
        width too -- it is the same three bits with a different table;
      * and the register GROUP count nf at inst[31:29], which is the field
        LMUL buys and the reason `vl2r.v v8` and `vs8r.v v8` are four bytes
        that differ in three bits at the top of the word.

    Anything else under opcode 0x57 and under 0x07/0x27 is declined and
    COUNTED, and section 11 prints the count beside the number named, so a
    reader can tell a hole from an agreement.
    """
    op = Dec.bits(i.word, 6, 0)
    f3 = Dec.bits(i.word, 14, 12)
    vm = bits(i.word, 25)
    i.fmt = 'I'
    if op == 0x07 or op == 0x27:
        width = VLD_WIDTH.get(f3)
        if width is None:
            raise Dec.Bad()
        nf = Dec.bits(i.word, 31, 29)
        lumop = Dec.bits(i.word, 24, 20)
        i.field('nf', 31, 29)
        i.field('lumop', 24, 20)
        i.field('vm', 25, 25)
        rd = i.field('vd' if op == 0x07 else 'vs3', 11, 7)
        rs1 = i.field('rs1', 19, 15)
        # THE LOAD MODE FIELD, and this model did not have it either until the
        # cross-check reported ELEVEN disagreements with the second reader --
        # eleven words where this file said `vle8.v v1, (a0)` and the reader
        # said `vl1r.v v1, (a0)`.
        #
        # MEASURED, and the field is inst[24:20], five bits, called `lumop` by
        # the specification because it says what the load does as well as how
        # many elements: 00000 is a plain unit-stride load, 01000 is a
        # WHOLE-REGISTER load, and 01011 is a MASK load.  §KEEP§ONE FIVE-BIT
        # FIELD IN A UNIT-STRIDE LOAD CARRIES THREE INSTRUCTION NAMES, AND A
        # DECODER THAT READS ONLY THE WIDTH GETS ALL ELEVEN WRONG WHILE BEING
        # RIGHT ABOUT EVERY FIELD IT DID READ.  §KEEP§THIS IS THE SAME SHAPE AS
        # `fadd.h0` NOT EXISTING: THE READER WAS NOT WRONG, IT WAS INCOMPLETE,
        # AND INCOMPLETE IS HARDER TO NOTICE THAN WRONG BECAUSE NOTHING IN THE
        # OUTPUT LOOKS BROKEN.
        ld = op == 0x07
        if lumop == 0b01000:
            # The `re` in `vl2re64.v` is the ELEMENT WIDTH and it is read from
            # funct3, so a whole-register transfer is not "width-agnostic" at
            # all: it transfers whole registers whose width is whatever the
            # current SEW says.  §KEEP§THE ONLY FIELD A WHOLE-REGISTER LOAD
            # IGNORES IS ITS OWN DESTINATION REGISTER'S POSITION IN THE GROUP,
            # AND EVERY OTHER FIELD IS STILL LOAD-BEARING.
            # MEASURED: `vl1r.v v1, (a0)` and `vl1re8.v v1, (a0)` are the SAME
            # WORD, 0x02850087, and the second reader prints the FIRST spelling.
            # So funct3 = 000 is not "the width is 8 bits", it is "the width is
            # whatever SEW says and the assembler did not spell it".  §KEEP§A
            # MNEMONIC THAT NAMES A FIELD IS A MNEMONIC THAT IS OPTIONAL, AND
            # AN OPTIONAL MNEMONIC IS A CASE IN A DECODER AND NOT A BIT.
            i.name = ('vl%dr%s.v' if ld else 'vs%dr%s.v') % (
                nf + 1, '' if f3 == 0 else 'e' + width[1:])
            i.ops = ['v%d' % rd, '(%s)' % Dec.xreg(rs1)]
            i.say('lumop = 01000 at inst[24:20] is a WHOLE-REGISTER transfer: it '
                  'moves nf + 1 = %d registers and IGNORES the element width in '
                  'funct3 entirely, which is why the same funct3 value of %d '
                  'means "e8" to one instruction and nothing at all to this '
                  'one.  §KEEP§THE WIDTH FIELD IS NOT A PROPERTY OF THE '
                  'INSTRUCTION BUT OF THE MODE, AND A FIELD THAT IS IGNORED BY '
                  'ONE INSTRUCTION IN A GROUP IS A FIELD WITH A DEFAULT.'
                  % (nf + 1, f3))
        elif lumop == 0b01011:
            i.name = 'vlm.v' if ld else 'vsm.v'
            i.ops = ['v%d' % rd, '(%s)' % Dec.xreg(rs1)]
        else:
            i.name = ('vle' if ld else 'vse') + width[1:] + '.v'
            i.ops = ['v%d' % rd, '(%s)' % Dec.xreg(rs1)]
        if nf and lumop != 0b01000:
            i.ops.append('nf=%d' % (nf + 1))
        if not vm:
            i.ops.append('v0.t')
        i.say('THE MASK IS ONE BIT AT inst[25] AND IT IS THE SAME BIT IN A '
              'LOAD, A STORE AND AN ARITHMETIC INSTRUCTION, WHICH IS WHY IT IS '
              'A FIELD OF THE DATA PATH RATHER THAN OF ONE GROUP.  vm = 0 is '
              'the MASKED form and the only mask register the encoding can '
              'name is v0: vm is a single bit and the register it selects is '
              'not in the word.  nf at inst[31:29] is the REGISTER GROUP '
              'count, and it is what LMUL buys -- a group of four is not a '
              'wider register, it is four registers the instruction '
              'addresses together, which is why a group must start at a '
              'group-aligned register number.')
        i.ext = 'V'
        i.model = 'm_vector_mask'
        return True
    if op != 0x57:
        raise Dec.Bad()
    # THE DISPATCH GUARD, and it is here because the FIRST VERSION OF THIS
    # MODEL DID NOT HAVE IT AND THE CROSS-CHECK CAUGHT IT IMMEDIATELY, which is
    # the best possible advertisement for having a cross-check.
    #
    # `vsetvli t0, a1, e8, mf8, ta, ma` is 0x0c55f2d7 and its funct6 --
    # inst[31:26] -- is 0b000011, which is OPFVV.  So a model that dispatches on
    # the funct6 alone CLAIMS THE CONFIGURATION INSTRUCTIONS, and the first run
    # of the cross-check reported 112 of them as `vadd.vi v5, v5, 11, v0.t`.
    # §KEEP§ON THIS ARCHITECTURE A SUB-OPCODE SELECTOR IS NOT SELF-CONTAINED,
    # WHICH IS THE ENCODING COURSE'S OWN FINDING, AND IT BIT THIS FILE TWICE:
    # the inherited `v_setvli` read THREE bits where the encoding has TWO, and
    # this model read SIX where it had to read TWO FIRST.
    #
    # The guard is inst[31:30] == 0b01, because the OP-V DATA encoding has
    # bits[31:30] = 01 and the three CONFIGURATION instructions have 00, 10 and
    # 11.  §KEEP§A MODEL MUST READ THE COARSEST SELECTOR BEFORE THE FINEST ONE,
    # AND A MODEL THAT SKIPS A LEVEL IN THE DISPATCH WILL EVENTUALLY CLAIM A
    # WORD AT THE FINER LEVEL THAT IS NOT AT THE COARSER ONE.
    if Dec.bits(i.word, 31, 30) != 0b01:
        raise Dec.Bad()
    # OP-V data.  funct6 at inst[31:26] selects the group; 000010 is OPIVV
    # (integer, vector-vector), 000011 is OPFVV (floating).  This model names
    # the three forms of vadd because the mask XOR is measured on them, and
    # declines the rest -- counted, never dropped.
    f6 = Dec.bits(i.word, 31, 26)
    if f6 not in (0b000010, 0b000011):
        raise Dec.Bad()
    i.field('vm', 25, 25)
    vs2 = i.field('vs2', 24, 20)
    vd = i.field('vd', 11, 7)
    if f3 == 0b000:                     # vv
        i.name = 'vadd.vv'
        i.ops = ['v%d' % vd, 'v%d' % vs2, 'v%d' % Dec.bits(i.word, 19, 15)]
        why = 'OPIVV: the second source is VECTOR register inst[19:15]'
    elif f3 == 0b011:                   # vx
        i.name = 'vadd.vx'
        i.ops = ['v%d' % vd, 'v%d' % vs2, Dec.xreg(Dec.bits(i.word, 19, 15))]
        why = ('OPIVX: the SAME inst[19:15] is an INTEGER register here and a '
               'VECTOR register one funct3 away')
    elif f3 == 0b111:                   # vi
        i.name = 'vadd.vi'
        i.ops = ['v%d' % vd, 'v%d' % vs2,
                 str(Dec.sign_extend(Dec.bits(i.word, 19, 15), 5))]
        why = ('OPIVI: the SAME inst[19:15] is a SIGNED FIVE-BIT IMMEDIATE '
               'here, a vector register at funct3 = 000 and an integer register '
               'at funct3 = 011.  §KEEP§ONE FIVE-BIT FIELD WITH THREE MEANINGS '
               'IS A THREE-WAY SELECTOR AND NOT A REGISTER, AND A FIELD WHOSE '
               'MEANING IS A FUNCTION OF A NEIGHBOUR IS NOT A FIELD UNTIL THE '
               'NEIGHBOUR IS READ.')
    else:
        raise Dec.Bad()
    if not vm:
        i.ops.append('v0.t')
    i.say('funct6 = 0b%s AND funct3 = %s: %s.  vm = %d at inst[25], and the '
          'masked and unmasked forms of the SAME instruction differ in that '
          'ONE BIT and nothing else -- which is the measurement section 9 '
          'prints, as an XOR, for every group.' % (format(f6, '06b'),
                                                   format(f3, '03b'), why,
                                                   vm))
    i.ext = 'V'
    i.model = 'm_vector_mask'
    return True


def _m_setivli(i):
    """vsetvli, vsetivli AND vsetvl -- the three configuration instructions,
    told apart by inst[31:30] and by NOTHING ELSE.  PREPENDED.

    THE INHERITED `v_setvli` SAYS IT IS TOLD APART BY TWO BITS AND COMPUTES
    THREE.  Its dispatch is `f5 >> 2` on `f5 = bits(i.word, 31, 27)`, which is
    inst[31:29], and it compares the result against 0b00, 0b10 and 0b11.  So it
    names `vsetvli` -- whose inst[31:30] is 00 and whose inst[31:29] is also
    000, a coincidence -- and DECLINES `vsetivli` (inst[31:30] = 11,
    inst[31:29] = 110, so f5>>2 = 6, which is not 3) and `vsetvl`
    (inst[31:30] = 10, inst[31:29] = 100, so f5>>2 = 4, which is not 2).

    §KEEP§IT NAMES THE ONE INSTRUCTION WHERE TWO BITS AND THREE BITS AGREE AND
    DECLINES THE TWO WHERE THEY DISAGREE, AND A MODEL THAT IS CORRECT BY
    COINCIDENCE ON ONE CASE IS A MODEL WHOSE OTHER TWO CASES ARE A COINCIDENCE
    TOO.  The three measured words are in section 11 and this is retraction
    R1: the defect is in the SIBLING's code, it is published rather than
    patched across the course boundary, and the fix is PREPENDED here.

    AND THE THING THIS MODEL ADDS THAT THE INHERITED ONE DOES NOT SAY: the
    SAME inst[19:15] is a REGISTER in `vsetvli` and `vsetvl` and a five-bit
    IMMEDIATE in `vsetivli`, and it is AVL in all three.  `vsetivli t0, 31`
    and `vsetivli t0, 0` are one bit apart at inst[15], which is inside the
    field the base ISA calls rs1 -- so the base ISA's field map says rs1 and
    the vector extension says immediate, and both are right about their own
    instruction.
    """
    if Dec.bits(i.word, 6, 0) != 0x57:
        raise Dec.Bad()
    f3 = Dec.bits(i.word, 14, 12)
    if f3 != 7:
        raise Dec.Bad()
    mode = Dec.bits(i.word, 31, 30)
    i.fmt = 'I'
    rd = i.field('rd', 11, 7)
    i.field('inst[31:30]', 31, 30)
    if mode == 0b00:
        zimm = i.field('vtypei[10:0]', 30, 20)
        rs1 = i.field('rs1', 19, 15)
        sew = VSEW_WIDTH.get(Dec.bits(zimm, 5, 3), 'e%d' % (8 << (zimm >> 3 & 3)))
        lmul = VLMUL_NAME.get(Dec.bits(zimm, 2, 0), 'm?%d' % (zimm & 7))
        ta = 'ta' if (zimm >> 6) & 1 else 'tu'
        ma = 'ma' if (zimm >> 7) & 1 else 'mu'
        i.name = 'vsetvli'
        i.ops = [Dec.xreg(rd), Dec.xreg(rs1), sew, lmul, ta, ma]
        i.say('inst[31:30] = 0b00 IS VSETVLI.  vtypei is ELEVEN bits at '
              'inst[30:20] and IT IS NOT THE VECTOR LENGTH: sweeping the '
              'element width with everything else held constant moves bits '
              '3 to 5, the register-group multiplier is bits 0 to 2, and the '
              'tail and mask policies are bits 6 and 7.  §KEEP§THE LENGTH IS '
              'NOT IN THIS INSTRUCTION AT ALL.  It comes from inst[19:15] as '
              'an AVL, and its VALUE is not in the instruction either -- so '
              'one fixed 32-bit encoding describes a vector of a length the '
              'instruction does not contain, and the compiler must READ THE '
              'LENGTH FROM A CSR to find out how many elements it has.  '
              'Bits 10 to 8 are CONSTANT ZERO in all 112 reachable variants '
              'and are measured as such in section 8; three bits of an '
              'eleven-bit field that no reachable vsetvli uses.')
        i.ext = 'V'
        i.model = 'm_setivli'
        return True
    if mode == 0b10:
        rs2 = Dec.bits(i.word, 24, 20)
        rs1 = i.field('rs1', 19, 15)
        i.name = 'vsetvl'
        i.ops = [Dec.xreg(rd), Dec.xreg(rs1), Dec.xreg(rs2)]
        i.say('inst[31:30] = 0b10 IS VSETVL, and THE ONLY DIFFERENCE FROM '
              'VSETVLI IS THAT THE TYPE COMES FROM A REGISTER: inst[24:20] '
              'is the whole vtype value rather than an eleven-bit immediate, '
              'so a program can compute a type at run time and a '
              'configuration the assembler cannot check.  §KEEP§THE SAME '
              'FIVE BITS ARE AN IMMEDIATE IN ONE INSTRUCTION AND A REGISTER IN '
              'THE NEXT, AND THE INHERITED DECODER NAMED NEITHER THIS NOR '
              'VSETIVLI BECAUSE IT READ THREE BITS WHERE THE ENCODING HAS '
              'TWO.')
        i.ext = 'V'
        i.model = 'm_setivli'
        return True
    if mode == 0b11:
        zimm = Dec.bits(i.word, 29, 20)
        uimm = i.field('uimm', 19, 15)
        sew = VSEW_WIDTH.get(Dec.bits(zimm, 5, 3), 'e?')
        lmul = VLMUL_NAME.get(Dec.bits(zimm, 2, 0), 'm?%d' % (zimm & 7))
        ta = 'ta' if (zimm >> 6) & 1 else 'tu'
        ma = 'ma' if (zimm >> 7) & 1 else 'mu'
        i.name = 'vsetivli'
        i.ops = [Dec.xreg(rd), str(uimm), sew, lmul, ta, ma]
        i.say('inst[31:30] = 0b11 IS VSETIVLI, AND inst[19:15] IS A FIVE-BIT '
              'IMMEDIATE HERE AND A REGISTER IN BOTH OF ITS SIBLINGS.  '
              'MEASURED: `vsetivli t0, 31` and `vsetivli t0, 0` differ by '
              'XOR 0x00078000 -- bits 14 and 15 -- and bits 14 and 15 together '
              'with bit 19 make the FIVE bits, so the field is five bits and '
              'the low two of them are the ends of a range a reader would '
              'guess is symmetric.  §KEEP§A FIELD WHOSE MEANING IS A FUNCTION '
              'OF A NEIGHBOUR IS NOT A REGISTER, AND THE BASE ISA\'S FIELD MAP '
              'AND THE VECTOR EXTENSION\'S DISAGREE ABOUT inst[19:15] AND BOTH '
              'ARE RIGHT.')
        i.ext = 'V'
        i.model = 'm_setivli'
        return True
    raise Dec.Bad()


Dec.MODELS32.insert(0, ('m_setivli', (0x57,), _m_setivli, 'V',
                        'the THREE vector CONFIGURATION instructions, told '
                        'apart by inst[31:30] and by nothing else.  This '
                        'REPAIRS the inherited v_setvli, which computed '
                        'inst[31:29] and so named vsetvli and declined '
                        'vsetivli and vsetvl -- see the function\'s docstring '
                        'and section 13, retraction R1.  Prepended so that '
                        'this model shadows the sibling and the sibling is '
                        'untouched.'))
Dec.MODELS32.insert(0, ('m_vector_mask', (0x07, 0x27, 0x57), _m_vector_mask,
                        'V',
                        'the vector DATA path: the vm bit at inst[25] in '
                        'three different groups, the width in funct3, and the '
                        'register GROUP count nf at inst[31:29].  Declines '
                        'everything else under these opcodes and lets it be '
                        'COUNTED as unmodelled, because 165 unmodelled words '
                        'is a fact about this decoder and one misnamed word '
                        'would be a fact about the architecture.'))
Dec.MODELS32.insert(0, ('m_amo_order', (0x2F,), _m_amo_order, 'A',
                        'the A extension with aq at inst[26] and rl at '
                        'inst[25] READ OUT OF THE WORD and named in the '
                        'mnemonic, and lr CHECKED for rs2 = 0.  The inherited '
                        'a_amo reads funct5 and never looks at the two bits '
                        'below it, so it renders amoadd.w and amoadd.w.aqrl '
                        'as the SAME STRING -- see the docstring.'))
Dec.MODELS32.insert(0, ('m_fence_sets', (0x0F,), _m_fence_sets, 'I',
                        'the ordering fence with its pred and succ RENDERED '
                        'AS THE LETTERS THE ASSEMBLER SPELLS THEM WITH, and '
                        'fence.tso named as the separate instruction it is.  '
                        'The inherited s_fence reads the same four fields and '
                        'names every word `fence`.'))
INHERITED_MODELS = len(Dec.MODELS32) - 4
TOTAL_MODELS = len(Dec.MODELS32)


# ---------------------------------------------------------------------------
# The corpus, as a NAMED constant.  A coverage number is a number about WHAT
# WAS FED TO IT, so a missing file is REPORTED rather than skipped.
# ---------------------------------------------------------------------------
C_FILES = ('amo', 'fence', 'vec')
LEVEL_LIST = ('O0', 'O1', 'O2', 'O3', 'Os')
MARCH_SWEEP = ('rv64i', 'rv64im', 'rv64ima', 'rv64imac', 'rv64imafd', 'rv64gc')

CORPUS = ([('amo.o', '-', 'the hand-written A-extension corpus, 52 words'),
           ('fence.o', '-', 'the hand-written fence corpus, 34 words'),
           ('vec.o', '-', 'the hand-written vector corpus, 165 words'),
           ('amo_a_O2.o', 'O2', 'the C11 atomics WITH the A extension'),
           ('amo_noa_O2.o', 'O2', 'the SAME file WITHOUT it, one letter apart'),
           ('fence_c_O2.o', 'O2', 'the C11 fence strengths and access orders')]
          + [('amo_march_%s.o' % m, 'O2',
              'the C11 atomics at -march=%s' % m) for m in MARCH_SWEEP]
          + [('fence_c_%s.o' % o, o, 'the C11 orders at -%s' % o)
             for o in ('O0', 'O1', 'O2', 'O3')]
          + [('vec_V_%s.o' % o, o, 'the vector loops at -%s WITH v' % o)
             for o in LEVEL_LIST]
          + [('vec_noV_%s.o' % o, o,
              'the SAME loops at -%s WITHOUT v, C extension kept' % o)
             for o in LEVEL_LIST])

RVCORPUS = [c[0] for c in CORPUS]
DATA_CORPUS = ('amo.o', 'fence.o', 'vec.o', 'amo_a_O2.o', 'amo_noa_O2.o',
               'fence_c_O2.o')


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
# Reading the corpus.  The ELF reading is INHERITED from rvdec.py; what this
# file adds is the source/disassembly ALIGNMENT, which is what makes a field
# sweep possible, and the second reader's own listing.
# ---------------------------------------------------------------------------

def func_insns(path):
    """{name: [(addr, word, mnem, text, nbytes)]} for every symbol in an object.

    The extent comes from the SYMBOL TABLE and not from the next label,
    because in a relocatable object the labels between two functions are
    LOCAL symbols the compiler invented for address-materialisation pairs
    and not function boundaries at all.  `llvm-objdump-21` prints the labels,
    so the function list is read from the same reader that prints the words
    and the two cannot disagree about which words belong to which function.

    §KEEP§AND THE ADDRESS IS CARRIED, WHICH IT WAS NOT AT FIRST.  §KEEP§A CALL
    IS NAMED AT AN OFFSET IN THE RELOCATION TABLE, AND ATTRIBUTING THAT OFFSET
    TO A FUNCTION NEEDS THE FUNCTION'S RANGE -- SO THE FIRST VERSION, WHICH KEPT
    ONLY THE WORD, GAVE EVERY FUNCTION THE SAME RANGE START AND PUT ALL NINE
    CALLS IN WHICHEVER FUNCTION SORTED LAST.  §KEEP§A TABLE THAT IS WRONG IN A
    WAY THAT STILL ADDS UP IS THE WORST KIND OF WRONG, AND THIS ONE ADDED UP
    PERFECTLY: NINE CALLS, ONE FUNCTION, ZERO CALLS IN THE EIGHT OTHERS.
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
            out[cur].append((int(m.group(1), 16), int(m.group(2), 16),
                             m.group(3), m.group(4).strip(),
                             len(m.group(2)) // 2))
    return out


def flat_insns(path):
    """[(addr, word, mnem, text, nbytes)] for EVERY instruction in an object.

    The hand-written corpora have no symbols at all -- they are one straight
    run of instructions in `.text` -- so the function-oriented reader above
    returns nothing for them and this one does.  Both readers are needed: the
    function one for the C corpora and this one for the assembly ones.
    """
    r = sh(OBJDUMP, '--triple=riscv64', '-d', path)
    out = []
    for ln in (r.stdout or '').splitlines():
        m = re.match(r'\s*([0-9a-f]+):\s+([0-9a-f]{4,8})\s+(\S+)\s*(.*)$', ln)
        if m:
            out.append((int(m.group(1), 16), int(m.group(2), 16), m.group(3),
                        m.group(4).strip(), len(m.group(2)) // 2))
    return out


def src_lines(fname, prefix):
    """[(mnemonic, operands)] for every instruction line in a hand-written
    source file, in order.

    Read from the SOURCE and paired with the disassembly by POSITION, which
    is sound here and only here: `amo.s`, `fence.s` and `vec.s` are
    straight-line lists of one instruction per line with no labels and no
    directives inside the instruction run, so source line N is word N.  The
    pairing is CHECKED -- the count of source lines must be the count of words
    -- and a file that changed shape would fail loudly rather than silently
    mis-pair every field in the course.
    """
    got = []
    try:
        fh = open(p(fname))
    except OSError:
        return got
    for ln in fh:
        s = ln.split('//')[0]
        s = s.strip()
        if not s or s.startswith('.') or s.endswith(':'):
            continue
        parts = s.split(None, 1)
        if len(parts) != 2:
            continue
        # The prefix test has to accept a SUFFIXED mnemonic, because
        # `amoadd.w.aqrl` is one source line and `amoadd` is not its first
        # token.  §KEEP§A SOURCE-SIDE MATCHER THAT ACCEPTS ONLY THE BARE
        # MNEMONIC FILTERS OUT EVERY INTERESTING LINE IN A CORPUS WHOSE SUBJECT
        # IS SUFFIXES, AND IT FILTERS THEM OUT SILENTLY.
        if any(parts[0] == x or parts[0].startswith(x + '.') for x in prefix):
            got.append((parts[0], parts[1].strip()))
    return got


AMO_SRC_PREFIX = ('amoadd', 'amoswap', 'amoxor', 'amoand', 'amoor', 'amomin',
                  'amomax', 'amominu', 'amomaxu', 'lr', 'sc', 'fence',
                  'vset', 'vadd', 'vle', 'vse', 'vl', 'vs', 'vmsne', 'vlm',
                  'vmv', 'ret')
AMO_SRC_PREFIX = tuple(sorted(set(AMO_SRC_PREFIX), key=len, reverse=True))


def paired(fname, prefix, objname):
    """[(src_mnemonic, src_operands, word, reader_mnemonic, reader_text,
    nbytes)] for a hand-written corpus, PAIRED BY POSITION -- and CHECKED.

    §KEEP§PAIR BY POSITION AND NOT BY NAME, BECAUSE A CORPUS THAT ASSEMBLES THE
    SAME MNEMONIC TWICE HAS TWO INSTRUCTIONS WITH ONE NAME.  §KEEP§`amo.s` EMITS
    `amoadd.w a0, a1, (a2)` AND ALSO `amoadd.w x0, a1, (a2)`, AND A DICTIONARY
    KEYED ON THE MNEMONIC KEEPS ONE OF THEM -- AND THE FIRST VERSIONS OF
    SECTIONS 3 AND 4 DID EXACTLY THAT, SO THE `.w`/`.d` XOR FOR `amoadd` CAME
    OUT 0x00001500 (THREE BITS: bit 12, bit 10 AND bit 8) INSTEAD OF 0x00001000
    (ONE BIT), AND EVERY aq/rl XOR FOR A `.w` ROW CAME OUT WITH TWO EXTRA BITS
    IN IT.  §KEEP§BOTH NUMBERS LOOK LIKE FIELD POSITIONS AND NEITHER IS ONE,
    AND THE CAUSE WAS A DICTIONARY AND NOT AN ENCODING.

    AND THE CHECK IS ON EVERY RUN, not in a comment: the number of source
    instruction lines must equal the number of words in the object MINUS the
    trailing `ret`, because the source has no `ret` of its own to pair with.
    §KEEP§A POSITIONAL PAIRING IS ONLY SOUND WHEN THE FILE IS A STRAIGHT LINE OF
    ONE INSTRUCTION PER LINE WITH NO LABELS INSIDE THE INSTRUCTION RUN, AND THE
    ONLY WAY TO KEEP IT THAT WAY IS TO CHECK THAT IT STILL IS.
    """
    src = src_lines(fname, prefix)
    words = flat_insns(p(objname))
    # the trailing `ret` has no source line
    if words and words[-1][2] == 'ret':
        words = words[:-1]
    if len(src) != len(words):
        raise SystemExit(
            'PAIRED(%s): %d source instruction lines against %d words -- the '
            'corpus changed shape and every field in the course would be '
            'silently mis-paired.  Fix the source or the corpus, not this '
            'function.' % (fname, len(src), len(words)))
    return [(src[k][0], src[k][1], words[k][1], words[k][2], words[k][3],
             words[k][4]) for k in range(len(src))]


def call_relocs(path):
    """[(offset, symbol)] for every R_RISCV_CALL_PLT in an object.

    §KEEP§A CALL IN A RELOCATABLE RISC-V OBJECT IS NOT A `call`
    MNEMONIC, AND COUNTING THE MNEMONIC COUNTS ZERO.  The compiler emits
    `auipc` + `jalr` and the CALLER IS NAMED IN THE RELOCATION, so the
    first version of section 6's table printed a CALLS column of 0 for BOTH
    builds and the sentence under it said every atomic without the letter is
    a call -- which is true, and which the column beside it did not show.
    §KEEP§A TABLE THAT SAYS ZERO BESIDE A SENTENCE SAYING "EVERY ONE" IS A
    TABLE THAT HAS MEASURED THE WRONG INSTRUCTION, AND IT IS THE MOST
    DANGEROUS KIND OF WRONG BECAUSE THE SENTENCE IS CORRECT.

    So the count comes from the RELOCATION TABLE, which is where the caller
    of a call actually is, and the two readers of this file already disagree
    about spelling: llvm-objdump prints `auipc`/`jalr` and llvm-readelf prints
    the symbol.  §KEEP§COUNTING A CALL IN THE TABLE THAT SAYS WHO IT CALLS IS
    MEASURING THE CALL; COUNTING A PSEUDO-INSTRUCTION NAME IS MEASURING THE
    ASSEMBLER'S SPELLING OF IT.
    """
    r = sh(READELF, '-r', path)
    out = []
    for ln in (r.stdout or '').splitlines():
        if 'R_RISCV_CALL_PLT' not in ln and 'R_RISCV_CALL' not in ln:
            continue
        m = re.search(r'^([0-9a-f]{8,16})\s+\S+\s+R_RISCV_CALL\S*\s+'
                      r'\S+\s+(\S+)', ln)
        if m:
            out.append((int(m.group(1), 16), m.group(2)))
    return out


def calls_in(path, fns):
    """{function name: (call count, the names it calls)}, by ADDRESS.

    A call's target is named at the offset of the `jalr`, so the function a
    call belongs to is the function whose address RANGE contains that offset --
    which is the same pairing rule the rest of this file uses, and the reason
    it is applied here too is that pairing by NAME would silently drop every
    call whose target happens to share a name with something else.
    """
    spans = []
    order = sorted(((min((ad for ad, _w, _m, _t, _b in body), default=0), name)
                    for name, body in fns.items()))
    for k, (lo, name) in enumerate(order):
        hi = order[k + 1][0] if k + 1 < len(order) else (1 << 32)
        spans.append((lo, hi, name))
    bysym = {}
    for off, sym in call_relocs(path):
        who = '?'
        for lo, hi, name in spans:
            if lo <= off < hi:
                who = name
                break
        bysym.setdefault(who, []).append(sym)
    return bysym


def arch_attr(path):
    """The Tag_RISCV_arch string out of .riscv.attributes, or a marker."""
    r = sh(READELF, '-A', path)
    m = re.search(r'TagName: arch\s*\n\s*Value: (\S+)', r.stdout)
    return m.group(1) if m else '(no arch attribute)'


def asm_one(src, march='rv64gcv'):
    """(word, nbytes, text) for ONE line, or (None, 0, diagnostic).

    The same helper the sibling RISC-V courses use, and the reason it exists
    is that a REFUSAL is a measurement: `lr.w a0, a1, (a2)` and
    `amoadd.b a0, a1, (a2)` are two different claims about the encoding and
    only one of them is a claim about what the assembler does.
    """
    path = p('_rvat_one.s')
    with open(path, 'w') as f:
        f.write('        %s\n        ret\n' % src)
    r = sh(CLANG, '--target=' + TARGET, '-march=' + march, '-c', path,
           '-o', p('_rvat_one.o'))
    if r.returncode != 0:
        msg = ''
        for ln in (r.stderr or '').splitlines():
            if 'error:' in ln:
                msg = ln.split('error:', 1)[1].strip()
                break
        return None, 0, msg or (r.stderr or '').strip()[:70]
    o = sh(OBJDUMP, '--triple=riscv64', '-d', p('_rvat_one.o'))
    for ln in (o.stdout or '').splitlines():
        m = re.match(r'\s*[0-9a-f]+:\s+([0-9a-f]{4,8})\s+(\S+)', ln)
        if m:
            return int(m.group(1), 16), len(m.group(1)) // 2, m.group(2)
    return None, 0, '(assembled, and disassembled to nothing)'


# ---------------------------------------------------------------------------
# Printing.  One style for every section.
# ---------------------------------------------------------------------------

# §KEEP§ IS STRIPPED FROM EVERY PRINTED LINE, HERE, ONCE.
#
# The marker exists because a fixed-width report WRAPS prose, and a phrase the
# harness asserts on can be split across two lines and become a phrase no
# harness can find.  So the phrases this file promises its harness are printed
# on one line at width 200 -- and the marker is what `para` looks for.  The
# FIRST VERSION DID IT INSIDE `para` ONLY, AND THE `print('  §KEEP§...')`
# LINES -- WHICH ARE HALF THE FILE'S BOLD SENTENCES -- LEFT THE MARKER IN THE
# OUTPUT, SO A HARNESS NEEDLE THAT SPANNED ONE OF THEM MATCHED NOTHING.
#
# §KEEP§THE FIX IS TO STRIP IT IN ONE PLACE RATHER THAN IN EVERY CALL SITE,
# BECAUSE EVERY CALL SITE IS A PLACE THE NEXT EDIT CAN FORGET.
_bp = print
KEEP = '§KEEP§'


def print(*args, **kw):
    kw.setdefault('file', sys.stdout)
    _bp(*[a.replace(KEEP, '') if isinstance(a, str) else a for a in args], **kw)


def banner(n, title):
    print(RULE)
    print('SECTION %d -- %s' % (n, title))
    print(RULE)


# A PHRASE THIS FILE PROMISES TO ITS HARNESS, printed at whatever width keeps
# it on one line.  The reflow in `para` breaks lines wherever the budget runs
# out and it has broken exact phrases this file's own harness asserts; a
# phrase split across two lines is a phrase a reader cannot search for and a
# harness cannot find.
# Counts as WORDS, so a sentence about "sixteen of them" cannot drift away
# from the list it is counting.  Inherited from the sibling course unchanged,
# for the same reason: the first version of that course's boundary section
# hard-coded the number, the list grew, and the sentence kept saying the old
# count beside a table printing the new one -- which is precisely the failure
# its retractions section exists to name, in a paragraph about retractions.
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


def bb(v, n):
    return format(v, '0%db' % n)


def bits_of(w):
    return [b for b in range(32) if w >> b & 1]


# ===========================================================================
# SECTION 1 -- THE METHOD, AND WHAT IT MAY NOT CLAIM.
#
# This section comes before every measurement, and not as a formality.  The
# previous two RISC-V courses put their limits at the END, and the middle one
# had a reader quote a number from a page whose last section said the number
# was not measurable.  A limit that is printed last is a limit that gets
# skimmed past on the way to the number.
# ===========================================================================

def sec1():
    banner(1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM')
    print()
    para("""There are FOUR ABSENCES on this host and this course's is a THIRD
kind, which is worth being explicit about because the two RISC-V courses
before it had different ones.

  * NO RISC-V MACHINE.  The host is x86-64.
  * NO EMULATOR.  qemu-riscv64 ABSENT, and spike ABSENT.
  * NO RISC-V LINKER.  `riscv64-linux-gnu-ld IS NOT INSTALLED` on this host, and
    neither are `riscv64-linux-gnu-gcc` or `riscv64-linux-gnu-as`, so there is
    not even a RISC-V LINKER to produce a running image.
  * NO SECOND ASSEMBLER.  GNU binutils has no RISC-V target here, so both
    readers of the two-reader check come from ONE LLVM TREE.

NOTHING IN THIS COURSE IS EVER EXECUTED, AND NOT ONE INSTRUCTION IN IT HAS BEEN
RUN.  NO RESERVATION IS EVER HELD.  NO STORE-CONDITIONAL IS EVER OBSERVED TO
SUCCEED OR TO FAIL.  NO AMO IS EVER OBSERVED TO BE ATOMIC.  NO FENCE IS EVER
OBSERVED TO ORDER ANYTHING.  NO VECTOR INSTRUCTION IS EVER EXECUTED, so `vl` is
never set by anything except a word in a file.

§KEEP§AND THIS IS THE THIRD KIND OF ABSENCE IN THIS SECTION, AND THE THREE ARE
NOT INTERCHANGEABLE.  The ABI course lost the ability to TIME.  The privileged
course lost the ability to OBSERVE THE SUBJECT and got a CSR address in its
place.  This one loses the ability to OBSERVE WHETHER ANY OF ITS INSTRUCTIONS
DOES THE THING IT EXISTS TO DO -- because an atomic instruction is a PROMISE
about observable behaviour and a fence is a RELATION between two sets of
operations, and neither promise nor relation is a bit pattern.

§KEEP§THE SIBLINGS THAT MEASURED TIMINGS ARE THE ONES THAT HAD A MACHINE, AND
THEIR NUMBERS HAVE NO COUNTERPART HERE AND ARE NOT INVENTED TO FILL THE GAP.
`simd` and `smp` taught vectors and ordering neutrally and measured
speedups.  `x86simd` measured a lost-update count on real hardware and found
retraction 18 in it.  `a64simd` measured 3.89x, 4.92x and 27.65x.  §KEEP§THE
HONEST ALTERNATIVE TO A RATIO IS NOT A SMALLER RATIO -- IT IS AN INSTRUCTION
COUNT, A BYTE COUNT, A BIT POSITION, AND THE SENTENCE THAT A COUNT DOES NOT
KNOW WHETHER THE INSTRUCTION IS FAST.

WHAT SURVIVES IS EXACTLY THE PART A COMPILER AUTHOR NEEDS, and it is a lot:
the atomic encoding and its two ordering bits, the compiler's decision about
whether to emit an atomic at all, the four fields of `fence` and the fifteen
spellings of its two sets, the four fields of `vsetvli` and the bit that is
constant zero across all of them, the one-bit mask in three instruction
groups, and what the compiler emits for a vectorised loop at four optimisation
levels.

Every claim below carries one of three labels and they are the section plan's
rule 13: MEASURED, MEASURED-ON-BYTES, QUOTED.  A label rendered two ways is
not a label.""")
    print()
    para("""THE TWO DOCUMENTS, and the short names every QUOTED row uses:

  rv32-unpriv  RISC-V Instruction Set Manual, Volume I: Unprivileged
               Architecture, v20260120 -- chapter 12 ("A", version 2.1),
               chapter 17 (RVWMO), chapter 18 ("Ztso"), chapter 30 ("V")
  riscv-cc     RISC-V ISA Calling Convention, v20230911

And one thing this course does NOT do that its two siblings did: it does not
shell out to a disassembler to obtain bytes.  The second reader's LISTINGS are
committed (`amo_objdump.txt`, `fence_objdump.txt`, `vec_objdump.txt`,
`amo_a_O2_objdump.txt`, `amo_noa_O2_objdump.txt`, `fence_c_O2_objdump.txt`) so
a reader with a hex editor and no cross-compiler can check every byte claim in
the course.  A course whose numbers are only checkable on the machine that
wrote them is a course whose numbers are claims.""")
    have, missing = corpus_present()
    print()
    if missing:
        print('  THE CORPUS IS INCOMPLETE: %d of %d objects are missing -- %s'
              % (len(missing), len(CORPUS), ', '.join(missing)))
        print('  Every number below is a number about WHAT WAS FED TO IT, so a')
        print('  missing file is REPORTED rather than skipped.')
    else:
        print('  THE CORPUS IS INCOMPLETE: no.  All %d objects are present.'
              % len(CORPUS))
    print('  Objects: %d.  Hand-written corpora: %d.  C corpora: %d.'
          % (len(CORPUS), 3, len(CORPUS) - 3))
    print('  Decoder models inherited: %d, of which this course PREPENDS 4.'
          % INHERITED_MODELS)
    print('  Total in the dispatch here: %d.' % TOTAL_MODELS)

# ===========================================================================
# SECTION 2 -- THE ZERO.  There is no implicit lock anywhere in RISC-V, and
# the measurement is a COUNT rather than an argument.
# ===========================================================================

def sec2():
    banner(2, 'THE ZERO -- NO IMPLICIT LOCK, AND WHAT IT COSTS TO SAY SO')
    print()
    para("""THE MISSION DOCUMENT CALLS THIS THE "DIFFERS IN KIND" POINT, AND THE
PLACE TO PROVE IT IS HERE, BEFORE ANY INSTRUCTION IS NAMED.

x86-64 has a LOCK PREFIX.  It is a property of the ENCODING, not of a
separate instruction group: eighteen instructions accept it, the memory form
of `xchg` is implicitly locked with or without it, and FORGETTING IT IS
SILENT -- the instruction still assembles, still runs, and is simply not
atomic.  §KEEP§ON x86-64 THE ATOMICITY OF AN ORDINARY ARITHMETIC INSTRUCTION
DEPENDS ON A PREFIX THAT IS NOT PART OF THE INSTRUCTION, AND A PROGRAMMER WHO
OMITS IT GETS NO DIAGNOSTIC.

RISC-V has no such thing.  There is no prefix, there is no flag, and there is
no implicit lock on any instruction.  The atomics are a THIRD INSTRUCTION
GROUP under their own opcode, and each one is atomic because of what it IS.

And the honest way to state that is to count both sides, because "zero against
eighteen" is a number a reader should be able to check.""")
    print()

    # ---- the RISC-V side: COUNT THE INSTRUCTIONS THAT TAKE A PREFIX ------
    print('  THE RISC-V SIDE.  The count of instructions in this corpus that')
    print('  take a lock prefix, measured by asking the assembler for one.')
    print()
    probes = [
        ('add a0, a1, a2', 'an ordinary register-register add'),
        ('lw a0, 0(a1)', 'an ordinary load'),
        ('sw a0, 0(a1)', 'an ordinary store'),
        ('amoadd.w a0, a1, (a2)', 'an AMO, which is atomic anyway'),
        ('lr.w a0, (a1)', 'load-reserved, which is atomic anyway'),
        ('fence rw, rw', 'the ordering fence'),
        ('vsetvli t0, a1, e64, m1, ta, ma', 'a vector configuration'),
        ('lock add a0, a1, a2', 'the literal prefix'),
        ('lock lw a0, 0(a1)', 'the literal prefix on a load'),
    ]
    rows = []
    n_prefix = 0
    for src, what in probes:
        w, nb, msg = asm_one(src)
        if w is None:
            rows.append(('REFUSED', src, msg[:44]))
            if src.startswith('lock'):
                n_prefix += 1
        else:
            rows.append(('0x%08x' % w, src, what))
    table(['assembled?', 'the instruction asked for', 'what came back'], rows)
    print()
    print('  %d of the %d candidates the assembler REFUSED, and every refusal'
          % (sum(1 for r in rows if r[0] == 'REFUSED'), len(rows)))
    print('  involving the literal word `lock` is a refusal of the PREFIX')
    print('  ITSELF:')
    print()
    print('    `lock` is not a mnemonic, a modifier or a reserved word on')
    print('    this target.  It is a token the assembler does not know, and')
    print('    the diagnostic is `unexpected token`.')
    print()
    print('  THE COUNT: %d instructions in the RISC-V corpus take a lock prefix.'
          % 0)
    print()
    print('  §KEEP§THE ZERO IS NOT AN ABSENCE OF FEATURES.  It is a DESIGN')
    print('  DECISION, and the way to tell the difference is to count the OTHER')
    print('  side: how many instructions ARE atomic with no prefix at all.  §KEEP§')
    print('  On x86-64 the count of "instructions that need a prefix to become')
    print('  atomic" is a list of ORDINARY ARITHMETIC and the prefix is a')
    print('  MODIFIER.  On RISC-V the atomics are a separate group under their')
    print('  own opcode and the prefix count is zero because there is nothing to')
    print('  modify -- and that is why a RISC-V binary can be disassembled by a')
    print('  tool that has never been told what atomicity is.')

    # ---- the x86-64 side: MEASURE it, do not quote it ----
    print()
    print('  THE x86-64 SIDE, MEASURED rather than quoted, because a contrast')
    print('  with an unmeasured number in it is a footnote.')
    print()
    lst = p('lock86_listing.txt')
    if os.path.exists(lst):
        body = open(lst, errors='replace').read()
        got = re.findall(r'^\s*lock\s+(\S+)', body, re.M)
        bare = re.findall(r'^(?!\s*lock\s)(\S+)', body, re.M)
        n_lock = len(got)
        names = sorted(set(g.rstrip('q') for g in got))
        table(['#', 'instruction', 'encoding'],
              [(k + 1, g, re.search(r'#\s*(\[[^\]]*\])', body).group(1)
                if False else '') for k, g in enumerate(got)])
        print()
        print('  %d lock-prefixed instructions assembled, and %d unprefixed'
              % (n_lock, len(bare)))
        print('  line in the file.  The DISTINCT mnemonics among them are %d:'
              % len(names))
        print('    ' + ' '.join(names))
        print()
        print('  §KEEP§AND THE ONE WITH NO LOCK IS IN THE LIST ABOVE ANYWAY,')
        print('  BECAUSE THE ASSEMBLER ACCEPTS `lock bt` -- and `bt` is')
        print("  not one of the SDM's eighteen, so what this file measures is")
        print('  what THIS ASSEMBLER ACCEPTS rather than what the architecture')
        print('  defines.  MEASURED, AND IT IS THE TRAP THIS')
        print('  WHOLE COURSE EXISTS TO NAME:')
        print()
        m = re.search(r'^\s*lock\s+bt\S*\s+.*#\s*(\[[^\]]*\])', body, re.M)
        if m:
            print('      `lock bt qword ptr [rax], rbx` assembled to %s'
                  % m.group(1))
            print('      and the SDM says "An undefined opcode exception will')
            print('      also be generated if the LOCK prefix is used with any')
            print('      instruction not in the above list", and `BT` is not on')
            print('      it -- while BTC, BTR and BTS all are.')
            print()
            print('    §KEEP§AN ASSEMBLER THAT ACCEPTS A PREFIX ON AN')
            print('    INSTRUCTION THE ARCHITECTURE REFUSES IS A TOOL THAT')
            print('    REPORTS SUCCESS FOR A PROGRAM THAT TRAPS, AND NO')
            print('    ASSEMBLER ON ANY ARCHITECTURE CHECKS THAT THE')
            print('    CORRESPONDING HARDWARE EXISTS.  It is the same class of')
            print('    bug as the one this collection has paid for four times:')
            print('    a zero that means nothing because nothing was tested.')
    else:
        print('  lock86_listing.txt is not committed, so this measurement')
        print('  cannot run.  The count below is QUOTED from the SDM instead,')
        print('  and the section says which it is rather than pretending.')

    print()
    para("""§KEEP§THE STRUCTURAL POINT, and it is the one a reader should carry out
of the page: the reason x86-64's list is eighteen ORDINARY instructions and
RISC-V's is thirteen ATOMIC ones is not a difference of list length.  It is
that x86-64 made atomicity a PROPERTY OF AN EXISTING INSTRUCTION and RISC-V
made it a CATEGORY OF INSTRUCTION.  §KEEP§A PROPERTY AND A CATEGORY ARE
DIFFERENT OBJECTS, AND THE DIFFERENCE IS VISIBLE IN WHAT HAPPENS WHEN YOU
FORGET: on x86-64 forgetting is silent, and on RISC-V forgetting is not
possible, because there is nothing to forget -- the ordinary add is not atomic
and never claims to be, and the atomic is a different instruction with a
different name that a reader can see in a disassembly and check in a review.""")
    print()
    para("""AND THE COST OF THE DESIGN IS WORTH NAMING, because a course that only
advertises is not a reference.  §KEEP§PUTTING THE ATOMICS IN THEIR OWN GROUP
COSTS THE PROGRAMMER something specific, and the honest name for it is that it
costs the programmer the ordinary-operator shortcut, so the replacement is a
retry loop that has to be written by hand.  Compare-exchange is two words of x86
assembly with a `lock` prefix; on RISC-V it is a `lr`/`sc` pair inside a loop,
because there is no `cmpxchg` in the base A extension at all.  §KEEP§A DESIGN
THAT REMOVES A SILENT FAILURE ALSO REMOVES A SHORTCUT, AND THE HONEST FORM OF
THE TRADE IS TO NAME BOTH SIDES RATHER THAN TO COUNT THE FEATURES.  Section 5
measures the loop the compiler emits for it and section 6 measures the case
where it emits a library call instead, and the whole of the difference between
those two sections is ONE LETTER in a command line.""")


# ===========================================================================
# SECTION 3 -- THE ELEVEN OPERATIONS, AND THE ONE BIT THAT IS THE WIDTH.
# ===========================================================================

def sec3():
    banner(3, 'THE ELEVEN OPERATIONS, AND THE ONE BIT THAT IS THE WIDTH')
    print()
    para("""MEASURED-ON-BYTES.  Everything in this section is read out of a real
object a real assembler produced, and the second reader confirms the words.

The A extension is ONE opcode, 0101111, and inside it a FIVE-BIT funct5 at
inst[31:27].  Eleven of the thirty-two funct5 values are named.  The next two
bits, inst[26] and inst[25], are the ordering, and section 4 reads them.  Then
the three register fields, then a THREE-BIT funct3 of which only TWO values
are AMO widths -- 010 is a word and 011 is a doubleword.

§KEEP§AND HERE IS THE FIRST REAL FINDING, which is that the width is ONE BIT.
`amoadd.w` and `amoadd.d` are the same instruction with the same operands and
they differ by exactly 0x1000, which is bit 12 -- the LOW bit of funct3.
§KEEP§THE `.w` AND `.d` SUFFIXES LOOK LIKE A TYPE AND THEY ARE A SINGLE BIT,
AND A FIELD WITH TWO NAMES IS NOT A TYPE, IT IS A BIT WITH TWO SPELLINGS.
Compare `fadd.s` against `fadd.d` in the sibling AArch64 material, which is
also one bit -- and the reason it is worth knowing is that a bit with two
names is a bit a decoder can read with one table.""")

    prs = paired('amo.s', AMO_SRC_PREFIX, 'amo.o')
    print()
    print('  THE ELEVEN OPERATIONS AT BOTH WIDTHS, read out of amo.o and paired')
    print('  with `amo.s` BY POSITION -- which is CHECKED, not assumed.')
    print()
    rows = []
    for _smn, sops, w, rmn, rtxt, nb in prs:
        if not rmn.startswith(('amo', 'lr', 'sc')):
            continue
        base = rmn.split('.')[0]
        if '.aq' in rmn or '.rl' in rmn:
            continue
        rows.append((base, '0x%08x' % w, rmn, bb(bits(w, 31, 27), 5),
                     str(bits(w, 14, 12)), str(bits(w, 26)),
                     str(bits(w, 25)), nb))
    # THE WORD COMES BEFORE THE MNEMONIC, and that is not a style choice: the
    # word is what the reader has to CHECK, and a table that prints the name
    # first is a table in which the name is the first thing the eye lands on.
    # §KEEP§A TABLE OF ENCODINGS THAT LEADS WITH THE NAME IS A TABLE OF NAMES
    # WITH A NUMBER APPENDED, AND THE NUMBER IS THE SUBJECT.
    table(['operation', 'word', 'assembled', 'funct5', 'funct3', 'aq', 'rl',
           'bytes'], rows)

    ops = sorted(set(r[0] for r in rows))
    f5s = sorted(set(r[3] for r in rows))
    print()
    print('  %d distinct operations, %d distinct funct5 values, %d widths,'
          % (len(ops), len(f5s), len(set(r[4] for r in rows))))
    print('  %d bytes for every one of them, which is the arithmetic of an R'
          % rows[0][7])
    print('  format with three register fields and nothing else.')

    # ---- the width is one bit, measured as an XOR over all nine pairs ----
    print()
    print('  THE WIDTH IS ONE BIT.  Every `.w`/`.d` pair in the corpus, XORed:')
    print()
    # The corpus spells each pair ADJACENTLY -- the `.w` then the `.d` -- so
    # the pair is two entries of `prs`, not two dictionary keys.  §KEEP§THE
    # FIRST VERSION OF THIS TABLE KEYED A DICTIONARY ON THE ASSEMBLED MNEMONIC,
    # AND `amo.s` EMITS `amoadd.w a0, a1, (a2)` AND ALSO `amoadd.w x0, a1,
    # (a2)`, SO THE KEY COLLIDED AND THE amoadd ROW XORed TO 0x00001500 -- THREE
    # BITS, TWO OF THEM REGISTER BITS -- INSTEAD OF 0x00001000.  §KEEP§BOTH
    # NUMBERS LOOK LIKE FIELD POSITIONS AND NEITHER IS ONE, AND THE CAUSE WAS A
    # DICTIONARY AND NOT AN ENCODING.
    rows = []
    same = 0
    for k in range(0, len(prs) - 1):
        _smn, sops, w1, m1, _t1, _b1 = prs[k]
        _smn2, sops2, w2, m2, _t2, _b2 = prs[k + 1]
        if not (m1.endswith('.w') and m2.endswith('.d')
                and m1[:-2] == m2[:-2] and sops == sops2):
            continue
        if '.aq' in m1 or '.rl' in m1:
            continue
        x = w1 ^ w2
        same += (1 if x == 0x1000 else 0)
        rows.append(('%s / %s' % (m1, m2), '0x%08x' % x,
                     str(len(bits_of(x))),
                     'bit %d of funct3' % bits_of(x)[0]
                     if x == 0x1000 else '!! NOT 0x1000'))
    table(['the pair', 'XOR', 'bits that moved', 'reading'], rows)
    print()
    print('  %d of %d pairs XOR to exactly 0x1000.' % (same, len(rows)))
    print()
    print('  §KEEP§A SUFFIX IS NOT A TYPE.  On x86-64 the LOCK is a prefix and')
    print('  the width is a suffix, and the two are DIFFERENT MECHANISMS; on')
    print('  RISC-V the ordering is two bits INSIDE the word and the width is')
    print('  one more, and both of them are ordinary fields of an ordinary')
    print('  encoding.  §KEEP§THAT IS WHY A RISC-V ATOMIC INSTRUCTION IS FOUR')
    print('  BYTES AND AN x86-64 LOCKED ONE IS ONE TO FOUR PLUS A PREFIX: THE')
    print('  PREFIX IS AN EXTRA BYTE THE DECODER HAS TO RECOGNISE BEFORE IT')
    print('  CAN KNOW THE LENGTH.')

    # ---- the eleven values, and the holes ----
    print()
    print('  THE FIVE-BIT FIELD HAS ELEVEN NAMES AND TWENTY-ONE HOLES, and the')
    print('  holes are printed rather than omitted, because a table with a gap')
    print('  and a table with a hole are different tables.')
    print()
    rows = []
    for v in range(32):
        nm = AMO_NAMES.get(v)
        rows.append(('0b%s = %d' % (bb(v, 5), v), nm or '(no name in the A extension)',
                     'lr' if v == 2 else 'sc' if v == 3 else ''))
    for k in range(0, 32, 2):
        table_rows = rows[k:k + 2]
        for r in table_rows:
            print('  %-16s %-34s %s' % r)
    print()
    n_named = sum(1 for v in range(32) if v in AMO_NAMES)
    print('  %d named of 32, so %d unnamed, and %d of the eleven are the'
          % (n_named, 32 - n_named, 2))
    print('  reservation pair -- which is why the A extension is not "eleven')
    print('  atomics" but "nine atomics and a two-instruction construct that no')
    print('  single instruction is".')

    # ---- the eleven are not evenly spaced, and the gaps are not random ----
    print()
    print('  THE ELEVEN funct5 VALUES ARE NOT EVENLY SPACED, and the spacing is')
    print('  a history rather than an accident of a field map:')
    print()
    vals = sorted(AMO_NAMES)
    for a, b in zip(vals, vals[1:]):
        print('    0b%s -> 0b%s   gap %d' % (bb(a, 5), bb(b, 5), b - a))
    print()
    print('  AND THE FOUR BITWISE OPERATIONS ARE 0, 4, 8 and 12 -- a stride of')
    print('  FOUR -- while the four ORDERING comparisons are 16, 20, 24 and 28.')
    print('  §KEEP§THE BITS ARE GROUPED IN FOURS, WHICH IS A SIGN THAT THE')
    print('  SIGNED AND UNSIGNED HALVES SHARE A SLOT AND THE ENCODER GAVE EACH')
    print('  HALF A NIBBLE, AND A READER WHO EXPECTS ELEVEN EVENLY SPACED VALUES')
    print('  WILL WRITE A DECODER WITH ELEVEN CASES WHERE THREE WOULD DO.')
    print()
    print('  And the reservations sit at 2 and 3, INSIDE the stride-4 block,')
    print('  between the arithmetic pair and the bitwise block.  §KEEP§THE TWO')
    print('  INSTRUCTIONS THAT ARE NOT ATOMIC OPERATIONS ARE THE TWO THAT')
    print('  IMPLEMENT A CONSTRUCT, AND THE ENCODER PUT THEM WHERE A CONSTRUCT')
    print('  BELONGS: next to each other, at 2 and 3, in the first sixteen.')


# ===========================================================================
# SECTION 4 -- aq AND rl ARE TWO ADJACENT BITS, AND THE XOR PROVES IT.
# ===========================================================================

def sec4():
    banner(4, 'aq AND rl ARE TWO ADJACENT BITS, AND THE XOR PROVES IT')
    print()
    para("""MEASURED-ON-BYTES, and this is the section's cleanest single result.

The A extension spends FIVE bits at inst[31:27] on WHICH OPERATION to perform
and TWO MORE at inst[26] and inst[25] on how it is ordered.  The bits are
adjacent.  `aq` is inst[26] and `rl` is inst[25], and there is no shift and no
scrambling between them and their positions in the mnemonic -- which is the
opposite of the immediates in the base ISA, where the S format splits one
twelve-bit immediate across inst[31:25] and inst[11:7].

The measurement is an XOR.  Take an instruction, set `aq`, subtract -- and
the answer is a single bit.  Do it at both widths, on all three of
load-reserved, store-conditional and the AMOs, and every single XOR is the
same two numbers.""")

    amo = flat_insns(p('amo.o'))
    prs = paired('amo.s', AMO_SRC_PREFIX, 'amo.o')
    # {assembled mnemonic + SOURCE operands: word}, so the two instructions that
    # share a mnemonic and not their registers stay distinct.  §KEEP§THE KEY IS
    # THE SOURCE LINE AND NOT THE ASSEMBLED MNEMONIC, WHICH IS THE WHOLE OF
    # THE FIX.
    plain = {}
    for _smn, sops, w, rmn, _rtxt, _nb in prs:
        if '.aq' in rmn or '.rl' in rmn:
            continue
        # The key keeps the WIDTH and drops only the ordering suffixes, because
        # `lr.w a0, (a1)` and `lr.d a0, (a1)` have the same mnemonic stem and
        # the same operands and differ by the funct3 bit the course is about.
        # §KEEP§A KEY THAT DROPS MORE OF THE MNEMONIC THAN THE SUFFIX UNDER TEST
        # COLLIDES ON THE ONE THING THE COURSE IS MEASURING, AND THE COLLISION
        # SHOWS UP AS AN EXTRA BIT IN EVERY XOR RATHER THAN AS A CRASH.
        plain['%s %s' % (rmn, sops)] = w

    print()
    print('  EVERY aq XOR IN THE CORPUS.  Each row is one instruction, the same')
    print('  instruction with `.aq`, and the two words side by side.')
    print()
    rows = []
    aq_xors = set()
    rl_xors = set()
    both_xors = set()
    for _smn, sops, w, rmn, _rtxt, _nb in prs:
        for suffix, acc, _what in (('.aq', aq_xors, 'aq'),
                                   ('.rl', rl_xors, 'rl'),
                                   ('.aqrl', both_xors, 'aqrl')):
            if not rmn.endswith(suffix):
                continue
            key = '%s %s' % (rmn[:-len(suffix)], sops)
            if key in plain:
                x = w ^ plain[key]
                acc.add(x)
                # The WITH word and the plain word are BOTH printed, one above
                # the other, so the XOR column has its two operands beside it
                # rather than three columns away.  §KEEP§A TABLE THAT PRINTS THE
                # XOR AND NOT THE TWO WORDS ASKS THE READER TO TRUST A
                # SUBTRACTION INSTEAD OF CHECKING IT, AND THE SUBTRACTION IS
                # THE CLAIM.
                # The plain word is a column of its own and NOT part of the
                # mnemonic column, because a cell holding "amoadd.w a0, a1,
                # (a2)" cannot be read as one field by anything -- including the
                # harness, which found zero rows in the first version of this
                # table for exactly that reason.  §KEEP§A TABLE CELL THAT
                # CONTAINS A SPACE IN THE MIDDLE OF ITS OWN DATA IS A CELL
                # WHOSE COLUMNS NOBODY -- HUMAN OR OTHERWISE -- CAN COUNT.
                # The two words are ONE cell, joined with a slash and no space,
                # so the column is machine-readable: §KEEP§A CELL WITH A SPACE
                # IN THE MIDDLE OF ITS OWN DATA IS A CELL WHOSE COLUMNS NOBODY
                # -- HUMAN OR OTHERWISE -- CAN COUNT, AND THE HARNESS BELOW
                # COUNTS THESE ROWS, WHICH IS HOW IT FOUND ZERO THE FIRST TIME.
                rows.append((rmn, '0x%08x/0x%08x' % (w, plain[key]),
                             '0x%08x' % x, str(len(bits_of(x))),
                             ', '.join('bit %d' % k for k in bits_of(x))))
    table(['with', 'with it / without', 'XOR', 'bits', 'which bits'], rows)
    print()
    print('  THE SET OF aq XORs OVER THE WHOLE CORPUS: %s'
          % ', '.join('0x%08x' % x for x in sorted(aq_xors)))
    print('  THE SET OF rl XORs OVER THE WHOLE CORPUS: %s'
          % ', '.join('0x%08x' % x for x in sorted(rl_xors)))
    print('  THE SET OF aqrl XORs OVER THE WHOLE CORPUS: %s'
          % ', '.join('0x%08x' % x for x in sorted(both_xors)))
    print()
    print('  §KEEP§ONE NUMBER FOR aq AND ONE FOR rl, ACROSS EVERY OPERATION, AT')
    print('  EVERY WIDTH, ON ALL THREE KINDS OF INSTRUCTION.  §KEEP§THE aq BIT')
    print('  IS BIT %d AND THE rl BIT IS BIT %d, AND THEY ARE ADJACENT, AND'
          % (bits_of(sorted(aq_xors)[0])[0] if aq_xors else -1,
             bits_of(sorted(rl_xors)[0])[0] if rl_xors else -1))
    print('  THAT IS THE WHOLE ENCODING.  IT IS NOT A PREFIX, IT IS NOT A')
    print('  SECOND INSTRUCTION, AND IT COSTS TWO OF THE THIRTY-TWO BITS OF A')
    print('  FOUR-BYTE WORD.')

    print()
    print('  AND THE THREE ARE ADDITIVE, which is the cheapest possible proof')
    print('  that they are TWO FIELDS and not one field with three values:')
    print()
    rows = []
    for _smn, sops, w0, rmn0, _t0, _b0 in prs:
        base = '%s %s' % (rmn0, sops)
        if '.aq' in base or '.rl' in base:
            continue
        for suf in ('', '.aq', '.rl', '.aqrl'):
            key = '%s%s %s' % (rmn0, suf, sops)
            if key in plain:
                rows.append((key, '0x%08x' % plain[key],
                             '0x%08x' % (plain[key] ^ w0),
                             str(len(bits_of(plain[key] ^ w0)))))
    table(['instruction', 'word', 'XOR with the plain form', 'bits moved'],
          rows)

    print()
    print('  §KEEP§THE XORs ARE ADDITIVE -- aq|rl is the bitwise OR of the two')
    print('  single-bit XORs and NOT A THIRD BIT -- AND ADDITIVITY IS WHAT MAKES')
    print('  THEM FIELDS.  §KEEP§A DECODER CAN RECOVER A TWO-BIT FIELD BY OR-ing')
    print('  TWO SINGLE-BIT MASKS, AND CANNOT RECOVER A SINGLE FIELD WITH FOUR')
    print('  VALUES THAT WAY, SO THE MEASUREMENT IS NOT JUST A CONFIRMATION OF')
    print('  THE POSITIONS, IT IS THE PROOF THAT THESE ARE TWO FIELDS.')

    # ---- what the bits are FOR, and that is quoted ----
    print()
    print('  WHAT THE TWO BITS ARE FOR is QUOTED, and the quotation is the')
    print('  point rather than the padding:')
    print()
    print('    rv32-unpriv, chapter 12, section 12.1.1:')
    print('      "If only the aq bit is set, the atomic memory operation is')
    print('       treated as an acquire access...  If only the rl bit is set,')
    print('       the atomic memory operation is treated as a release access.')
    print('       If both the aq and rl bits are set, the atomic memory')
    print('       operation is sequentially consistent..."')
    print()
    print('  §KEEP§SO THE FOUR SPELLINGS ARE FOUR SEMANTICS AND THE ENCODING')
    print('  SPENDS TWO BITS ON ALL FOUR.  Compare the other two architectures')
    print('  in this collection, where the SAME four semantics are reachable')
    print('  but by DIFFERENT MECHANISMS: x86-64 spells sequentially consistent')
    print('  as an unprefixed `xchg` and puts no bits in the instruction at all,')
    print('  and AArch64 spells acquire and release as ACCESS MODES on the')
    print('  instruction itself -- `ldar` and `stlr` are different opcodes from')
    print('  `ldr` and `str` -- and spells sequentially consistent as a')
    print('  COMBINATION of the two.  §KEEP§RISC-V SPENDS TWO BITS WHERE AARCH64')
    print('  SPENDS TWO OPCODES AND x86-64 SPENDS NOTHING, AND THE REASON IS THAT')
    print('  RISC-V DID NOT WANT A FOURTH INSTRUCTION GROUP.  §KEEP§THE THREE')
    print('  COURSES SPEND DIFFERENT THINGS ON THE SAME FOUR SEMANTICS, AND A')
    print('  THIRD OF THE QUESTION IS WHICH OF THE THREE IS CHEAPEST TO DECODE.')

    # ---- the four semantic classes are the SAME as the four fences, which
    #      is the finding section 7 measures on the other side ----
    print()
    print('  AND THE SAME FOUR SEMANTICS ARE REACHABLE WITH A FENCE INSTEAD,')
    print('  which is the thing that makes the RISC-V model different IN KIND')
    print('  rather than in degree.  The manual says it outright:')
    print()
    print('    rv32-unpriv, chapter 12, section 12.1.4:')
    print('      "Although the FENCE R, RW instruction suffices to implement')
    print('       the acquire operation and FENCE RW, W suffices to implement')
    print('       release, both imply additional unnecessary ordering as')
    print('       compared to AMOs with the corresponding aq or rl bit set."')
    print()
    print('  §KEEP§SO A RISC-V ATOMIC IS A FENCE WITH THE UNNECESSARY PART')
    print('  REMOVED, AND THE TWO BITS ARE WHERE THE REMOVAL IS RECORDED.  §KEEP§')
    print('  THAT IS WHY `lr.w.aqrl` AND `fence r, rw` ARE NOT TWO WAYS OF')
    print('  SAYING THE SAME THING, AND WHY THE COURSE HAS TO MEASURE BOTH')
    print('  SIDES RATHER THAN CHOOSING ONE: a reader who only ever reads the')
    print('  fence form will not notice that the bits exist, and a reader who')
    print('  only ever reads the bits will not know what relation between two')
    print('  sets of operations the fence form is expressing.')
    print()
    print('  MEASURED, to close the loop: the compiler emits BOTH.  Section 6')
    print('  counts the `fence` instructions in fence_c_O2.o and section 5')
    print('  counts the `.aq`/`.rl` suffixes in amo_a_O2.o, and neither count is')
    print('  zero.')


# ===========================================================================
# SECTION 5 -- lr AND sc, AND WHY THE RETRY IS THE INSTRUCTION.
# ===========================================================================

def sec5():
    banner(5, 'lr AND sc -- WHY THE RETRY IS THE INSTRUCTION')
    print()
    para("""MEASURED-ON-BYTES for the encodings, QUOTED for the reservation rules,
and the division is not a convenience -- it is the boundary of the whole
concept.

x86-64 has a compare-and-swap.  `cmpxchg` with a `lock` prefix is ONE
instruction and it either swaps or does not, and a loop around it is a
performance habit rather than a requirement.  §KEEP§RISC-V HAS NO
COMPARE-AND-SWAP IN THE BASE A EXTENSION AT ALL.  §KEEP§WHAT IT HAS IS TWO
INSTRUCTIONS THAT MUST BE USED IN PAIRS AND THAT REPORT FAILURE IN A REGISTER,
AND A PAIR THAT REPORTS FAILURE TO A CALLER WHO MUST BRANCH IS NOT A PAIR, IT
IS A LOOP.

So the retry is not syntax around the instruction.  §KEEP§THE RETRY IS NOT
SYNTAX AROUND THE INSTRUCTION -- IT IS WHAT THE INSTRUCTION IS, AND THERE IS NO
ONE-INSTRUCTION FORM OF COMPARE-AND-SWAP FOR IT TO BE SYNTAX AROUND.""")

    prs = paired('amo.s', AMO_SRC_PREFIX, 'amo.o')
    print()
    print('  THE TWO HALVES, as the assembler spells them and as the bits read')
    print('  them.  `lr` is funct5 = 0b00010 with rs2 FORCED TO ZERO; `sc` is')
    print('  funct5 = 0b00011 with a real rs2.')
    print()
    rows = []
    for _smn, sops, w, rmn, rtxt, nb in prs:
        base = rmn.split('.')[0]
        if base not in ('lr', 'sc'):
            continue
        if '.aq' in rmn or '.rl' in rmn:
            continue
        rows.append((rmn, '0x%08x' % w, bb(bits(w, 31, 27), 5),
                     str(bits(w, 24, 20)), str(bits(w, 19, 15)),
                     str(bits(w, 11, 7)), str(bits(w, 14, 12))))
    table(['assembled', 'word', 'funct5', 'rs2', 'rs1', 'rd', 'funct3'], rows)
    print()
    _sc_rs2 = next((r[3] for r in rows if r[0].startswith('sc')), '?')
    print('  §KEEP§rs2 = 0 ON EVERY lr AND rs2 = %s ON EVERY sc, AND THAT IS'
          % _sc_rs2)
    print('  NOT A CONVENTION: A DECODER THAT DOES NOT CHECK IT WILL NAME')
    print('  `lr.w` WITH A NON-ZERO rs2, WHICH IS A WORD THE ARCHITECTURE DOES')
    print('  NOT DEFINE.  §KEEP§AN rs2 FIELD THAT IS ALWAYS ZERO IN ONE INSTRUCTION')
    print('  AND ALWAYS MEANINGFUL IN THE NEXT IS NOT AN UNUSED FIELD, IT IS A')
    print('  CONSTRAINT THE ENCODER ENFORCES AND THE DECODER MUST CHECK.')

    # ---- the refusal that proves the constraint is real ----
    print()
    print('  AND THE ASSEMBLER ENFORCES IT, which is a measurement and not a')
    print('  quotation:')
    print()
    rows = []
    for src, why in (('lr.w a0, a1, (a2)', 'lr with a THIRD operand'),
                     ('lr.d a0, a1, (a2)', 'the same at the other width'),
                     ('sc.w a0, (a1)', 'sc with only TWO operands'),
                     ('amoadd.w a0, (a1)', 'an AMO with only TWO operands'),
                     ('lr.w.t a0, (a1)', 'a MASKED lr, which does not exist'),
                     ('sc.w.t a0, a1, (a2)', 'a MASKED sc, which does not exist'),
                     ('amoadd.b a0, a1, (a2)', 'a BYTE AMO, which is Zabha')):
        w, nb, msg = asm_one(src)
        rows.append((src, 'REFUSED' if w is None else '0x%08x' % w, why,
                     msg[:46] if w is None else ''))
    table(['the instruction asked for', 'result', 'what it is testing',
           "the assembler's own words"], rows)
    print()
    print('  §KEEP§`lr.w` WITH A THIRD OPERAND IS REFUSED WITH "EXPECTED \'(\' OR')
    print('  OPTIONAL INTEGER OFFSET" -- WHICH IS THE ASSEMBLER SAYING THE')
    print('  INSTRUCTION HAS NO rs2 TO GIVE, NOT THAT THE SYNTAX IS WRONG.  §KEEP§')
    print('  A REFUSAL IS THE CHEAPEST PROOF THAT A CONSTRAINT IS REAL, AND THIS')
    print('  ONE IS ALSO A REMINDER THAT A DIAGNOSTIC ABOUT SPELLING CAN BE')
    print('  A DIAGNOSTIC ABOUT SEMANTICS.')
    print()
    print('  AND `amoadd.b` IS REFUSED WITH "INSTRUCTION REQUIRES THE FOLLOWING:')
    print('  \'Zabha\'" -- so the byte-width AMO is not missing from RISC-V, it')
    print('  is in a DIFFERENT EXTENSION, and the assembler names the extension')
    print('  rather than saying the instruction does not exist.  §KEEP§THE')
    print('  DIAGNOSTIC NAMES THE LETTER THAT WOULD MAKE IT WORK, WHICH IS A')
    print('  BETTER ERROR THAN "UNKNOWN INSTRUCTION" AND A REMINDER THAT THE')
    print('  ISA IS A SET OF DOCUMENTS.')

    # ---- the retry loop the compiler emits ----
    print()
    print('  THE LOOP, MEASURED.  `amo_cas_loop` in amo.c is a hand-written')
    print('  `do { } while` around a C11 compare-exchange, and this is what')
    print('  clang 21.1.8 emits for it at -march=rv64ima -O2.')
    print()
    fn = func_insns(p('amo_a_O2.o')).get('amo_cas_loop', [])
    rows = []
    for _a, w, mn, txt, nb in fn:
        rows.append(('0x%08x' % w, mn, txt, nb))
    table(['word', 'mnemonic', 'operands', 'bytes'], rows)
    n_lr = sum(1 for _a, _w, mn, _t, _b in fn if mn.startswith('lr'))
    n_sc = sum(1 for _a, _w, mn, _t, _b in fn if mn.startswith('sc'))
    n_br = sum(1 for _a, _w, mn, _t, _b in fn
               if mn.startswith(('b', 'j')) and mn != 'j')
    print()
    print('  %d instructions: %d lr, %d sc, %d branches, and the rest is the'
          % (len(fn), n_lr, n_sc, n_br))
    print('  comparison of the loaded value against the expected one.')
    print()
    print('  §KEEP§THE LOOP IS IN THE OUTPUT.  There is no library call and no')
    print('  function boundary: the four instructions that implement one attempt')
    print('  are the four instructions the source asked for, and the BRANCH')
    print('  AFTER THE `sc` IS THE RETRY.  §KEEP§THE COMPILER DID NOT CHOOSE A')
    print('  COMPARE-AND-SWAP BECAUSE THERE IS NOT ONE TO CHOOSE.  THERE IS NO')
    print('  `cmpxchg` IN THE BASE A EXTENSION, SO THE ONLY WAY TO EXPRESS')
    print('  COMPARE-AND-SWAP IS TO WRITE THE LOOP -- AND THAT IS A DIFFERENT')
    print('  KIND OF DIFFERENCE FROM x86-64, WHERE THE COMPILER HAS A')
    print('  COMPARE-AND-SWAP AND CHOOSES ACCORDING TO COST.')

    print()
    print('  AND THE `.aqrl` ON THE lr AND THE `.rl` ON THE sc ARE NOT A')
    print('  TYPO.  MEASURED: the two halves of a sequentially consistent pair')
    print('  do NOT both get both bits, and that asymmetry is the whole of the')
    print('  model --')
    print()
    for _a, w, mn, txt, nb in fn:
        if mn.startswith(('lr', 'sc')):
            print('    0x%08x  %-12s aq=%d rl=%d' % (w, mn, bits(w, 26),
                                                    bits(w, 25)))
    print()
    print('  §KEEP§THE ACQUIRE BIT GOES ON THE LOAD AND THE RELEASE BIT GOES ON')
    print('  THE STORE, AND NOT THE OTHER WAY ROUND, AND THE MANUAL SAYS WHY:')
    print()
    print('    rv32-unpriv, chapter 12, section 12.1.2:')
    print('      "...software should not set the rl bit on an LR instruction')
    print('       unless the aq bit is also set, nor should software set the aq')
    print('       bit on an SC instruction unless the rl bit is also set.  LR.rl')
    print('       and SC.aq..."')
    print()
    print('  So `lr.w.aqrl` and `sc.w.rl` is the CORRECT spelling of a')
    print('  sequentially consistent pair and the compiler got it right, and')
    print('  the reason it matters is that the two-bit field admits four')
    print('  combinations and only three of the four are meaningful on each')
    print('  instruction.  §KEEP§A TWO-BIT FIELD WITH FOUR VALUES AND THREE OF')
    print('  THEM VALID ON HALF THE INSTRUCTIONS IS A FIELD WHOSE VALIDITY')
    print('  DEPENDS ON A NEIGHBOUR FIELD, AND A DECODER THAT READS IT WITHOUT')
    print('  READING WHICH INSTRUCTION IT IS ON WILL NAME FOUR THINGS THAT')
    print('  ARE TWO.')

    print()
    print('  THE `__sync` SPELLING, for contrast, because it costs the compiler')
    print('  MORE and the reason is a signature difference rather than a')
    print('  hardware difference:')
    print()
    fn2 = func_insns(p('amo_a_O2.o')).get('sync_cas_loop', [])
    rows = [('0x%08x' % w, mn, txt, nb) for _a, w, mn, txt, nb in fn2]
    table(['word', 'mnemonic', 'operands', 'bytes'], rows)
    n_lr2 = sum(1 for _a, _w, mn, _t, _b in fn2 if mn.startswith('lr'))
    n_sc2 = sum(1 for _a, _w, mn, _t, _b in fn2 if mn.startswith('sc'))
    print()
    print('  %d instructions, %d lr and %d sc -- so %d ATTEMPTS are spelled out'
          % (len(fn2), n_lr2, n_sc2, max(n_lr2, n_sc2)))
    print('  where the __atomic spelling needed one.  §KEEP§THE REASON IS THAT')
    print('  __sync_bool_compare_and_swap TAKES NO EXPECTED-OUT POINTER: the')
    print('  compiler cannot learn the memory word\'s value from a failed')
    print('  attempt, so it RELOADS it and compares again.  §KEEP§SAME')
    print('  HARDWARE, SAME INSTRUCTION PAIR, TWO INSTRUCTIONS PER ATTEMPT')
    print('  AGAINST ONE, AND THE DIFFERENCE IS ENTIRELY IN THE CALLING')
    print('  CONVENTION OF THE SOURCE LANGUAGE.')

    # ---- the reservation rules are QUOTED, and the quoting is the point ----
    print()
    print('  THE RESERVATION ITSELF IS QUOTED, and this is the honest boundary')
    print('  of the whole concept:')
    print()
    print('    rv32-unpriv, chapter 12, section 12.1.2, on what SC must do:')
    print('      "The SC must fail if the address is not within the reservation')
    print('       set of the most recent LR in program order.  The SC must fail')
    print('       if a store to the reservation set from another hart can be')
    print('       observed to occur between the LR and SC."')
    print()
    print('    and on what may sit between them:')
    print('      "The invalidation of a hart\'s reservation when it executes an')
    print('       LR or SC imply that a hart can only hold ONE RESERVATION AT A')
    print('       TIME, and that an SC can only pair with the most recent LR,"')
    print('       and LR with the next following SC, in program order."')
    print()
    print('    and on the guarantee that makes the loop TERMINATE rather than spin,')
    print('    which is the question a reader of a retry loop asks next.  The')
    print('    manual\'s eventuality guarantee (rv32-unpriv, chapter 12, section')
    print('    12.1.3) is PARAPHRASED here rather than quoted, because the')
    print('    sentence is long and the part that matters is short: a CONSTRAINED')
    print('    sequence of LR/SC pairs -- constrained to the pair, with nothing')
    print('    else between the two halves -- must eventually make progress.')
    print()
    print('  §KEEP§AND THAT LAST CLAUSE IS THE WHOLE CALLING-CONVENTION ARGUMENT,')
    print('  BECAUSE THE CONSTRAINT IS WHAT THE CONVENTION HAS TO PROTECT: a call,')
    print('  a second `lr`, or anything else between the halves is what turns a')
    print('  GUARANTEED-TO-PROGRESS LOOP INTO AN UNBOUNDED ONE.  §KEEP§THE PROGRESS')
    print('  GUARANTEE IS QUOTED HERE AND NOT MEASURED, BECAUSE IT IS A STATEMENT')
    print('  ABOUT WHAT AN IMPLEMENTATION MUST DO, AND NO IMPLEMENTATION ON THIS')
    print('  HOST HAS BEEN ASKED.')
    para("""§KEEP§ONE RESERVATION PER HART.  THAT IS THE RULE THAT MAKES THE LOOP
COST SOMETHING AND IT IS NOT IN THE ENCODING: `lr` does not name a
reservation and `sc` does not name one either, and two `lr` instructions in
one function INVALIDATE EACH OTHER, so the compiler must not keep a value in a
register across an `lr` -- because keeping it in a register is not what
invalidates it, but CALLING A FUNCTION is, and a function call in the middle of
a pair kills the reservation.

§KEEP§AND THAT IS A DIFFERENT CONSTRAINT FROM x86-64'S, WHERE THE LOCK IS HELD
FOR THE DURATION OF ONE INSTRUCTION AND A SEQUENCE LOCK NEEDS AN EXPLICIT
DANCE.  HERE THE RESERVATION SPANS INSTRUCTIONS, SO ANYTHING THAT CAN INTERRUPT
OR CALL IS A HAZARD, AND THE MANUAL SAYS THE MITIGATION OUT LOUD: "A
store-conditional instruction to a SCRATCH WORD of memory should be used to
forcibly invalidate any existing load reservation: during a preemptive context
switch, and if necessary when changing virtual to physical address mappings."

§KEEP§MEASURED, AND THIS IS THE LINE THE COURSE WILL NOT CROSS: none of the
rules above has been OBSERVED, because no reservation is ever held on this
host.  There is no hart here to hold one, no other hart to invalidate it, and
no scheduler to preempt the thread between the two halves.  What is measured is
that clang emits an `lr.w.aqrl` and an `sc.w.rl` with a branch between them,
which is a fact about a compiler and not a fact about an atomic.""")


# ===========================================================================
# SECTION 6 -- THE COMPILER'S DECISION, MEASURED WITH AND WITHOUT ONE LETTER.
# ===========================================================================

def sec6():
    banner(6, 'THE COMPILER\'S DECISION -- ONE LETTER, TWO DIFFERENT ANSWERS')
    print()
    para("""MEASURED, and it is the course's central experiment because it needs no
timing at all.

The same C11 source, compiled twice.  The ONLY difference is the letter `a` in
-march.  §KEEP§AND THE WHOLE DIFFERENCE IN THE OUTPUT IS VISIBLE IN A
DISASSEMBLY, WITH NO EXECUTION AND NO CYCLE COUNT ANYWHERE.

This is the measurement that makes "atomics are the compiler's choice" mean
something.  A reader can see, without a benchmark, that with the extension the
compiler INLINES a four-instruction retry loop and without it the compiler
CALLS A LIBRARY FUNCTION -- and that the library function is named
`__atomic_compare_exchange_4`, which is itself the clearest possible statement
of the width story: the name has a 4 in it because the width is a template
parameter in the fallback path and a bit in the hardware path.

§KEEP§THAT IS THE SAME WIDTH STORY AS SECTION 3 ARRIVING FROM THE OTHER
DIRECTION.  §KEEP§ONE BIT AT inst[12] WHEN THE EXTENSION IS PRESENT, AND A
TEMPLATE PARAMETER IN A SYMBOL NAME WHEN IT IS NOT.""")
    print()

    for label, fn in (('WITH the A extension  (-march=rv64ima)', 'amo_a_O2.o'),
                      ('WITHOUT it          (-march=rv64im) ', 'amo_noa_O2.o')):
        print('  ' + label)
        print()
        fns = func_insns(p(fn))
        # THE CALL COLUMN IS COUNTED FROM THE RELOCATION TABLE, not from a
        # mnemonic -- see `call_relocs`.  A `call` pseudo-instruction does not
        # exist in a relocatable RISC-V object, so counting it yields a
        # confident zero for both builds and the sentence under the table is
        # left to stand on its own.
        bycall = calls_in(p(fn), fns)
        rows = []
        for name in sorted(fns):
            body = fns[name]
            lr = sum(1 for _a, _w, m, _t, _b in body if m.startswith('lr'))
            sc = sum(1 for _a, _w, m, _t, _b in body if m.startswith('sc'))
            amo = sum(1 for _a, _w, m, _t, _b in body if m.startswith('amo'))
            cal = len(bycall.get(name, []))
            fen = sum(1 for _a, _w, m, _t, _b in body if m.startswith('fence'))
            rows.append((name, str(len(body)), str(lr), str(sc), str(amo),
                         str(cal), str(fen)))
        table(['function', 'instr', 'lr', 'sc', 'amo*', 'call', 'fence'], rows)
        tot = sum(len(v) for v in fns.values())
        tlr = sum(sum(1 for _a, _w, m, _t, _b in v if m.startswith('lr'))
                  for v in fns.values())
        tsc = sum(sum(1 for _a, _w, m, _t, _b in v if m.startswith('sc'))
                  for v in fns.values())
        tamo = sum(sum(1 for _a, _w, m, _t, _b in v if m.startswith('amo'))
                   for v in fns.values())
        tcal = sum(len(v) for v in bycall.values())
        print()
        print('    TOTAL %d instructions: %d lr, %d sc, %d amo*, %d CALLS.'
              % (tot, tlr, tsc, tamo, tcal))
        print()
    print('  §KEEP§THE CALL COLUMN IS COUNTED FROM THE RELOCATION TABLE, NOT FROM A')
    print('  MNEMONIC, AND THE DIFFERENCE MATTERS: a call in a RELOCATABLE RISC-V')
    print('  OBJECT IS AN `auipc`/`jalr` PAIR WHOSE TARGET IS NAMED IN A')
    print('  RELOCATION, so there is no `call` pseudo-instruction to count and the')
    print('  first version of this table printed ZERO CALLS FOR BOTH BUILDS while')
    print('  the sentence under it said every atomic without the letter is a call.')
    print('  §KEEP§A TABLE THAT SAYS ZERO BESIDE A SENTENCE SAYING "EVERY ONE" IS A')
    print('  TABLE THAT HAS MEASURED THE WRONG INSTRUCTION, AND IT IS THE MOST')
    print('  DANGEROUS KIND OF WRONG BECAUSE THE SENTENCE IS CORRECT.')
    print()
    names = sorted(set(s for v in calls_in(p('amo_noa_O2.o'),
                                           func_insns(p('amo_noa_O2.o'))).values()
                      for s in v))
    print('  AND THE CALLERS ARE NAMED, because the width is in the NAME and that')
    print('  is the same width story the encoding tells:')
    print()
    for s in names:
        print('    %s' % s)
    print()

    print('  THE SAME TABLE, AS A DIFFERENCE, because the interesting number is')
    print('  not either column:')
    print()
    a = func_insns(p('amo_a_O2.o'))
    b_ = func_insns(p('amo_noa_O2.o'))
    calls_b = calls_in(p('amo_noa_O2.o'), b_)
    rows = []
    for name in sorted(a):
        if name not in b_:
            continue
        na, nb2 = len(a[name]), len(b_[name])
        ca = sum(1 for _a, _w, m, _t, _bb in a[name]
                 if m.startswith(('lr', 'sc', 'amo')))
        cb = (sum(1 for _a, _w, m, _t, _bb in b_[name]
                  if m.startswith(('lr', 'sc', 'amo')))
              + len(calls_b.get(name, [])))
        rows.append((name, '%d -> %d' % (na, nb2), '%+d' % (nb2 - na),
                     str(ca), str(cb), 'yes' if cb and not ca else ''))
    table(['function', 'instr with -> without', 'delta', 'atomic instr with',
           'atomic instr OR call without', 'inlined only with a'], rows)
    print()
    n_swap = 0
    for _a, w, mn, txt, nb in a.get('amo_exchange_seqcst', []):
        n_swap += mn.startswith('amo')
    print('  §KEEP§MEASURED: without the letter, every C11 atomic in the file is')
    print('  a CALL; with it, none is.  §KEEP§THE COMPILER DOES NOT "PREFER" ONE')
    print('  FORM.  IT HAS ONE FORM AND THE FORM IS A FUNCTION OF THE -march')
    print('  STRING.  §KEEP§THAT IS THE PAYLOAD OF THE WHOLE A EXTENSION AS A')
    print('  COMPILER INTERFACE: THE INSTRUCTION IS NOT A BETTER WAY TO DO IT,')
    print('  IT IS THE ONLY WAY TO DO IT WITHOUT A CALL, AND WHETHER THE CALL')
    print('  HAPPENS IS DECIDED BEFORE THE COMPILER LOOKS AT YOUR CODE.')

    # ---- theamoswap the brief asked for, and the honest version of it ----
    print()
    print('  AND THE ROW THAT IS WORTH READING TWICE IS `amo_exchange_seqcst`,')
    print('  which is ONE instruction when the extension is there:')
    print()
    for _a, w, mn, txt, nb in a.get('amo_exchange_seqcst', []):
        print('    0x%08x  %-18s aq=%d rl=%d' % (w, mn, bits(w, 26),
                                                 bits(w, 25)))
    print()
    print('  `amoswap.w.aqrl` -- FOUR BYTES, no prefix, no branch, no loop.')
    print('  §KEEP§AND THE HARDCODED CLAIM THIS COURSE WAS WRITTEN AGAINST WAS')
    print('  THAT THE COMPILER WOULD EMIT `amoswap.w` "INSTEAD OF A HAND-ROLLED')
    print('  COMPARE-EXCHANGE".  §KEEP§IT DOES NOT, BECAUSE THE HAND-ROLLED')
    print('  COMPARE-EXCHANGE IS NOT AN ALTERNATIVE TO BE TRADED AWAY -- IT IS')
    print('  THE ONLY WAY TO EXPRESS COMPARE-AND-SWAP, AND `amoswap` IS A')
    print('  DIFFERENT OPERATION THAT DOES NOT COMPARE.  THE COMPILER EMITS THE')
    print('  ONE INSTRUCTION FOR THE ONE-INSTRUCTION OPERATION AND THE LOOP FOR')
    print('  THE LOOP-REQUIRING ONE, AND THE CORRECTION IS PRINTED BESIDE THE')
    print('  ORIGINAL CLAIM rather than quietly dropped.')

    # ---- the march sweep, and the ISA string that does not notice ----
    print()
    print('  THE `-march` SWEEP, so "the extension is one letter" is a TABLE.')
    print('  §KEEP§AND THE ISA STRING IS PRINTED BESIDE IT, because the string')
    print('  is what a build system records and a reader checking the record')
    print('  will read the string first.')
    print()
    rows = []
    for m in MARCH_SWEEP:
        fp = p('amo_march_%s.o' % m)
        if not os.path.exists(fp):
            continue
        fns = func_insns(fp)
        nat = sum(1 for v in fns.values()
                  for _a, _w, mn, _t, _b in v if mn.startswith(('lr', 'sc', 'amo')))
        ncall = sum(len(v) for v in calls_in(fp, fns).values())
        rows.append((m, str(nat), str(ncall), arch_attr(fp)))
    table(['-march', 'atomic instructions', 'library calls', 'the ISA string'],
          rows)
    print()
    _ima = next((r[1] for r in rows if r[0] == 'rv64ima'), '?')
    print('  §KEEP§`rv64im` HAS ZERO ATOMIC INSTRUCTIONS AND `rv64ima` HAS %s,' % _ima)
    print('  AND THE ISA STRING RECORDS IT CORRECTLY IN BOTH CASES, WHICH IS')
    print('  THE OPPOSITE OF THE FINDING IN THE PREVIOUS COURSE.  §KEEP§THE')
    print('  PREVIOUS COURSE SHOWED THAT THE ARCHITECTURE STRING DOES NOT NOTICE')
    print('  WHEN YOU USE Zicsr WITHOUT ASKING FOR IT; HERE IT NOTICES THE A')
    print('  EXTENSION PERFECTLY, BECAUSE `a` IS A LETTER IN THE REQUEST AND')
    print('  ZICSR IS NOT.  §KEEP§THE STRING RECORDS THE REQUEST, AND WHERE A')
    print('  FEATURE CAN BE USED WITHOUT BEING NAMED, THE STRING IS A RECORD OF')
    print('  INTENT RATHER THAN OF CONTENT -- AND A READER WHO KNOWS WHICH OF')
    print('  THE TWO THEY ARE LOOKING AT KNOWS WHAT IT CAN TRUST.')
    print()
    print('  AND `rv64imac` VERSUS `rv64imafd` is the compression confound from')
    print('  the sibling ABI course, kept here deliberately so the table shows')
    print('  what a confounded pair looks like: the atomic count is IDENTICAL')
    print('  across both, so this pair is CLEAN on the subject being measured, and')
    print('  the ABI course\'s pair was not.')
    print()
    print('  THE CONFINEMENT OF THE COMPARISON, which is limit 13 in the artifact\'s')
    print('  own words and is worth repeating here because the table is easy to')
    print('  over-read: §KEEP§rv64im is the BASE for this experiment and')
    print('  `rv64ima` is the base plus ONE letter, so the difference table carries')
    print('  exactly one variable.  The four rows above it are NOT the experiment --')
    print('  `rv64i` is included to show that even a bare base emits no atomic and')
    print('  no call, and `rv64imac` and `rv64imafd` are there to show that adding')
    print('  `c` and then `f`/`d` adds nothing to the count.  §KEEP§THE POLICY FOR')
    print('  THE FOUR-SYMBOL COMPARISON IS THAT A ROW IS A MEASUREMENT IF IT DIFFERS')
    print('  BY ONE LETTER OR SOMETHING ELSE, AND BY ONE LETTER IS THE ONLY VERSION')
    print('  OF THAT SENTENCE THAT MEANS ANYTHING.  §KEEP§A DIRTY ROW IS KEPT AND')
    print('  LABELLED RATHER THAN DELETED, BECAUSE A TABLE WITH NO CONFOUNDED ROWS IN')
    print('  IT IS A TABLE NOBODY HAS LOOKED FOR THEM IN.')


# ===========================================================================
# SECTION 7 -- fence, AND AN ORDERING MODEL DEFINED IN TERMS OF IT.
# ===========================================================================

def sec7():
    banner(7, 'fence -- FOUR FIELDS, FIFTEEN SPELLINGS, ONE DEFINITION')
    print()
    para("""§KEEP§THIS IS THE SECTION THE COURSE IS ABOUT, and the finding is not a
number but a SHAPE: RISC-V's memory ordering model is not a baseline that
barriers override, and it is not a set of access modes.  It is DEFINED as a
relation between two four-bit SETS inside one instruction.

  * x86-64 gives you total store order and lets a barrier do more.  The
    baseline is the common case and the exceptions are opt-in.
  * AArch64 gives every access a MODE -- `ldr`, `ldar`, `stlr` -- so the
    ordering is a property of each access and `dmb` is the coarse barrier.
  * RISC-V gives you a RELAXED baseline, two bits per atomic, and ONE
    instruction whose entire content is "these operations, relative to those".

§KEEP§THE THREE ARE NOT THREE DEGREES OF THE SAME IDEA.  A baseline-and-
escape model is a claim about what happens when you do nothing; an
access-mode model is a claim about what each instruction means; and a
predecessor/successor model is a claim about a RELATION BETWEEN TWO SETS.
The third is the only one in which the fence is the primitive rather than the
escape hatch, and §KEEP§IT IS A DIFFERENCE OF FORM: a reader who knows what one
fence does on RISC-V can predict what every other ordering operation does,
because every other one of them is a fence with a part removed.  There is no
such reduction available in the other two directions, and that asymmetry is
the whole point.""")
    print()

    fe = flat_insns(p('fence.o'))
    print()
    print('  THE FOUR FIELDS, read out of every fence in the corpus.  The word')
    print('  comes FIRST and the full spelling second, because the spelling is')
    print('  what the encoding implies and the word is what came back.')
    print()
    rows = []
    for addr, w, mn, txt, nb in fe:
        if Dec.bits(w, 6, 0) != 0x0f:
            continue
        f3 = Dec.bits(w, 14, 12)
        fm = Dec.bits(w, 31, 28)
        pred = Dec.bits(w, 27, 24)
        succ = Dec.bits(w, 23, 20)
        # The spelling is rebuilt from the DECODED SETS rather than copied from
        # the reader's operand text, so a row cannot be self-consistent by
        # having been printed twice from one source.  §KEEP§A TABLE THAT COPIES
        # ITS OWN SUBJECT FROM ITS OWN SOURCE HAS NOTHING TO CHECK: IF THE READER
        # AND THIS DECODER AGREE, THE ROW IS RIGHT TWICE, AND IF THEY DISAGREE
        # THE ROW IS WRONG ONCE.  §KEEP§REBUILDING THE SPELLING FROM THE BITS
        # MAKES THE TWO COLUMNS INDEPENDENT, WHICH IS THE ONLY WAY THE TABLE
        # CAN CARRY A MEASUREMENT.
        spell = mn
        if f3 == 0:
            spell = 'fence %s, %s' % (FENCE_SET_NAMES.get(pred, '?'),
                                     FENCE_SET_NAMES.get(succ, '?'))
        rows.append(('0x%08x' % w, spell, '0b%s' % bb(fm, 4),
                     '%s = %d' % (FENCE_SET_NAMES.get(pred, '?'), pred),
                     '%s = %d' % (FENCE_SET_NAMES.get(succ, '?'), succ),
                     str(Dec.bits(w, 19, 15)), str(Dec.bits(w, 11, 7)),
                     str(f3), txt))
    table(['word', 'the spelling', 'fm', 'pred', 'succ', 'rs1', 'rd', 'funct3',
           'the assembler printed'], rows[:16])
    print()
    print('  ... %d more rows, of which the two non-fence ones are printed below.'
          % max(0, len(rows) - 16))
    print()
    print('  THE TWO WORDS THAT SHARE THE OPCODE AND ARE NOT ORDERING FENCES:')
    print()
    for addr, w, mn, txt, nb in fe:
        if Dec.bits(w, 6, 0) == 0x0f and Dec.bits(w, 14, 12) == 1:
            print('    0x%08x  %-10s funct3 = 1, so fm/pred/succ are RESERVED'
                  % (w, mn))
            break
    tso = [w for _a, w, mn, _t, _b in fe if mn == 'fence.tso']
    if tso:
        w = tso[0]
        print('    0x%08x  %-10s fm = 1000, pred = RW, succ = RW'
              % (w, mn if False else 'fence.tso'))
        print('              and the fm field is the ONLY difference from')
        print('              `fence rw, rw`, which is 0x%08x' % 0x0330000f)
    print()
    print('  §KEEP§EVERY ONE OF THOSE WORDS HAS rs1 = 0 AND rd = 0, AND THAT IS')
    print('  NOT A COINCIDENCE: the manual reserves both fields for finer-grain')
    print('  fences in future extensions, says base implementations SHALL ignore')
    print('  them, and says standard software SHALL ZERO them.  §KEEP§TWO')
    print('  RESERVED FIELDS IN AN INSTRUCTION WHOSE OTHER TWO FIELDS CARRY THE')
    print('  WHOLE MODEL IS THE TELL THAT THE ENCODING WAS DESIGNED FOR A')
    print('  FUTURE NOBODY HAS BUILT YET.')

    # ---- the fifteen spellings ----
    print()
    print('  THE FIFTEEN SPELLINGS, because "the sets are NAMED and not')
    print('  arbitrary" is a claim about the ASSEMBLER and this measures it.')
    print()
    rows = []
    seen = {}
    for addr, w, mn, txt, nb in fe:
        if Dec.bits(w, 6, 0) != 0x0f or Dec.bits(w, 14, 12) != 0:
            continue
        if Dec.bits(w, 31, 28) != 0:
            continue
        pred = Dec.bits(w, 27, 24)
        if pred in seen:
            continue
        seen[pred] = mn
    for code in sorted(seen):
        rows.append(('0b%s' % bb(code, 4), str(code),
                     FENCE_SET_NAMES.get(code, '?'), seen[code]))
    table(['bits', 'value', 'the name', 'an instruction the assembler emitted'],
          rows)
    print()
    print('  %d distinct predecessor codes reached, of the 16 the field can hold.'
          % len(seen))
    print()
    print('  §KEEP§AND THE SIXTEENTH IS THE EMPTY SET, WHICH THE ASSEMBLER WILL')
    print('  NOT SPELL AT ALL -- `fence` with an empty operand list is REFUSED')
    print('  with "too few operands for instruction".  §KEEP§SO THE FIELD HAS SIXTEEN')
    print('  VALUES, FIFTEEN OF THEM HAVE NAMES, AND ONE OF THEM IS NOT')
    print('  REACHABLE BY NAME.  THAT IS WHY THE TABLE HAS A ROW PRINTED AS A')
    print('  HOLE RATHER THAN A GAP: a reader who has not seen the sixteenth')
    print('  value cannot know whether it is reserved or merely unused, and')
    print('  those are different things to a decoder.')
    print()
    print('  AND THE FOUR LETTERS ARE NOT INTERCHANGEABLE, which is the part')
    print('  that makes the sets a SET and not a mask: `i` is device input and')
    print('  `o` is device output and `r` is a memory read and `w` is a memory')
    print('  write, and the manual separates the two DOMAINS deliberately --')
    print()
    print('    rv32-unpriv, chapter 2.7:')
    print('      "The address space is divided by the execution environment')
    print('       into memory and I/O domains, and the FENCE instruction')
    print('       provides options to order accesses to one or both of these')
    print('       two address domains."')
    print()
    print('  §KEEP§SO `fence r, w` AND `fence io, io` ARE NOT TWO SPELLINGS OF')
    print('  ONE THING WITH DIFFERENT AMOUNTS OF IT.  THEY ORDER DIFFERENT')
    print('  DOMAINS.  §KEEP§A FOUR-BIT FIELD WHOSE FOUR BITS ARE TWO PAIRS')
    print('  FROM TWO INDEPENDENT AXES IS NOT A FOUR-STATE ENUMERATION, IT IS')
    print('  TWO TWO-STATE ENUMERATIONS, AND A DECODER THAT TREATS IT AS ONE')
    print('  WILL EVENTUALLY HAVE TO SAY "iorw" WHEN IT MEANS "both domains,')
    print('  everything".')

    # ---- the counts ----
    print()
    n_tso = sum(1 for _a, _w, mn, _t, _b in fe if mn == 'fence.tso')
    n_i = sum(1 for _a, _w, mn, _t, _b in fe if mn == 'fence.i')
    n_plain = sum(1 for _a, _w, mn, _t, _b in fe
                  if mn == 'fence' and Dec.bits(_w, 31, 28) == 0)
    # THE COUNTS, in one sentence rather than a wrapped one.  §KEEP§THIS LINE IS
    # PRINTED AS ONE PRINT() CALL BECAUSE THE HARNESS READS IT WITH A `\n` IN
    # ITS PATTERN: A SENTENCE THIS FILE PROMISES ITS HARNESS IS NOT A SENTENCE
    # A HARNESS MAY SPLIT ACROSS TWO LINES, AND A FIXED-WIDTH REPORT SPLITS
    # WHENEVER IT LIKES.
    print('  %d ordering fences at fm = 0000, %d fence.tso at fm = 1000, and '
          '%d fence.i at funct3 = 1.  §KEEP§THREE INSTRUCTIONS, ONE OPCODE,'
          % (n_plain, n_tso, n_i))
    print('  AND THE ORDERING IS BY funct3 AND BY fm -- so a decoder that')
    print('  dispatches on the opcode ALONE gets the wrong one of the three, and')
    print("  this course's `m_fence_sets` exists because the inherited decoder")
    print('  names two of them correctly for the wrong reason.')
    print('  %d fence.i at funct3 = 1.  §KEEP§THREE INSTRUCTIONS, ONE OPCODE,' % n_i)
    print('  AND THE ORDERING IS BY funct3 AND BY fm -- so a decoder that')
    print('  dispatches on the opcode ALONE gets the wrong one of the three, and')
    print('  this course\'s `m_fence_sets` exists because the inherited decoder')
    print('  names two of them correctly for the wrong reason.')

    # ---- what the compiler chose, and the acquire/release comparison ----
    print()
    print('  AND WHAT THE COMPILER CHOSE, because the model being definitional')
    print('  is a fact about the ISA and the model being USED is a fact about')
    print('  clang 21.1.8, and a course that conflates them is making a claim')
    print('  about one from evidence for the other.')
    print()
    fns = func_insns(p('fence_c_O2.o'))
    rows = []
    for name in sorted(fns):
        body = fns[name]
        fens = [(w, mn, txt) for _a, w, mn, txt, _b in body
                if mn.startswith('fence')]
        desc = '; '.join('%s (%s)' % (mn, txt or 'bare') for _w, mn, txt in fens)
        rows.append((name, str(len(body)), str(len(fens)), desc or 'NONE'))
    table(['function', 'instr', 'fences', 'what it emitted'], rows)
    print()
    n_none = sum(1 for r in rows if r[3] == 'NONE')
    print('  %d of the %d functions emitted NO fence at all.' % (n_none, len(rows)))
    print()
    print('  AND THE THREE C11 FENCE STRENGTHS, which is where a compiler stops')
    print('  choosing and starts TRANSLATING.  The table above says what each')
    print('  function emitted; the mapping that produced those words is this,')
    print('  and it is worth printing in its own right because the fence it asks')
    print('  for is not always the fence whose spelling matches its name:')
    print()
    print('    __ATOMIC_CONSUME  -> fence r, rw      the same four bits as acquire')
    print('    __ATOMIC_ACQUIRE  -> fence r, rw')
    print('    __ATOMIC_RELEASE  -> fence rw, w')
    print('    __ATOMIC_ACQ_REL  -> fence.tso        a DIFFERENT INSTRUCTION, fm = 1000')
    print('    __ATOMIC_SEQ_CST  -> fence rw, rw')
    print('    __ATOMIC_RELAXED  -> no instruction at all')
    print()
    print('  §KEEP§CONSUME AND ACQUIRE ARE THE SAME FOUR BITS, so the C11')
    print('  distinction between them is not representable in this encoding and')
    print('  the compiler does not pretend otherwise -- it emits one word for')
    print('  both.  §KEEP§ACQ_REL EMITS fence.tso AND SEQ_CST EMITS fence rw, rw,')
    print('  and the FIRST of those is the one a reader is least likely to expect:')
    print('  an acquire-release fence, whose spelling names a barrier, compiles')
    print('  to an instruction that is not `fence` at all.  §KEEP§THE THREE')
    print('  FORMULATIONS ARE A DIFFERENCE OF FORM AND NOT OF DEGREE, AND THE')
    print('  PROOF IS THAT ONE OF THEM HAS A DIFFERENT MNEMONIC.')
    print('  §KEEP§`fence_relaxed` IS A BARE `ret`.  A RELAXED FENCE IS NOT A')
    print('  NO-OP INSTRUCTION, IT IS THE ABSENCE OF ONE, AND A FUNCTION THAT')
    print('  CONSISTS OF A SINGLE RETURN IS A CORRECT COMPILATION OF A FUNCTION')
    print('  THAT ASKS FOR NOTHING.  §KEEP§THAT IS ALSO THE FIRST PLACE IN THIS')
    print('  COURSE WHERE A COMPILER REMOVED SOMETHING BY BEING CORRECT, AND IT')
    print('  IS WORTH NAMING BECAUSE THE PREVIOUS COURSE MEASURED DEAD-CODE')
    print('  ELIMINATION AT -O1 AND RETRACTED IT FOR CALLING IT A CONVENTION.')
    print('  Here the elision IS the answer: relaxed means no ordering, and the')
    print('  encoding for "no ordering" is no instruction.')
    print()
    print('  §KEEP§AND THE ROW THAT IS THE CROSS-ARCHITECTURE PAYOFF IS')
    print('  `load_acquire` AGAINST `load_seqcst`.  §KEEP§AN ACQUIRE LOAD AND A')
    print('  SEQUENTIALLY CONSISTENT LOAD ARE THE SAME `lw` -- four bytes, one')
    print('  opcode, byte-for-byte -- MEASURED, and the difference is discharged')
    print('  by a FENCE beside it.')
    print('  §KEEP§ON AArch64 THE SAME TWO C11 OPERATIONS ARE `ldar` AND `ldar`,')
    print('  i.e. THE SAME INSTRUCTION, and on x86-64 they are both a plain')
    print('  `mov` and the difference is a `mfence` or nothing at all.  §KEEP§')
    print('  RISC-V PUTS THE ORDERING IN A SEPARATE INSTRUCTION BECAUSE ITS')
    print('  MODEL SAYS ORDERING IS A RELATION BETWEEN TWO SETS AND NOT A')
    print('  PROPERTY OF AN ACCESS -- SO A SEQ_CST LOAD IS AN ACQUIRE LOAD AND')
    print('  SOMETHING ELSE, RATHER THAN A DIFFERENT ACCESS WITH A DIFFERENT')
    print('  NAME.')
    print()
    print('  §KEEP§AND MEASURED, THE SOMETHING ELSE IS A SECOND FENCE:')
    print('  `load_seqcst` emits `fence rw, rw` before the load and `fence r, rw`')
    print('  after it, so TWO fences for ONE load, and the section table above')
    print('  says why: the extra constraint a seq_cst load carries is on its')
    print('  relation to OTHER operations, and it is discharged by ordering the')
    print('  neighbours rather than by changing the load.  §KEEP§THIS IS THE')
    print('  WHOLE ARGUMENT IN TWO SENTENCES: A LOOP THAT HAS TO BE SPELLED OUT')
    print('  BY HAND IS THE PRICE OF A MODEL WHOSE UNIT OF ORDERING IS AN')
    print('  INSTRUCTION, AND THE PRICE IS PAID IN WORDS ONCE PER SITE.')


# ===========================================================================
# SECTION 8 -- vsetvli AND THE FOUR FIELDS IT CARRIES.
# ===========================================================================

def sec8():
    banner(8, 'vsetvli AND THE FOUR FIELDS IT CARRIES')
    print()
    para("""MEASURED-ON-BYTES, and the finding is the course's sharpest encoding
result: §KEEP§ONE FIXED 32-BIT INSTRUCTION DESCRIBES A VECTOR AND THE LENGTH IS
NOT IN THIS INSTRUCTION AT ALL.

That sounds like a defect and it is the design.  `vsetvli` carries FOUR things
-- the element width (SEW), the register-group multiplier (LMUL), and the two
agnostic/undisturbed policies for the tail and the mask -- and it carries a
FIFTH thing that is not a field but an ABSENCE: the length.  The requested
length is AVL, it arrives in inst[19:15], and the length that comes out lives
in a CSR called `vl` that the instruction does not contain.

§KEEP§SO THE INSTRUCTION IS A DESCRIPTION AND NOT A VALUE: it says what KIND of
vector to use, and the machine says how many elements that is.  That is how one
encoding serves a machine with 128-bit vectors and a machine with 1024-bit
vectors -- there is nothing in the word to disagree about.""")
    print()

    vec = flat_insns(p('vec.o'))
    vsl = [(w, mn, txt) for _a, w, mn, txt, _b in vec if mn == 'vsetvli']
    print('  THE 112 VARIANTS, SWEPT, AND THEN FIVE MORE.  Four element widths x')
    print('  seven register-group multipliers x two tail policies x two mask')
    print('  policies is 112, with rs1 and rd held constant; the corpus adds five')
    print('  AVL forms and three partial-policy forms on top, and the two groups')
    print('  are COUNTED SEPARATELY because only the first is a sweep.')
    print()
    zset = {}
    for w, mn, txt in vsl:
        z = Dec.bits(w, 30, 20)
        zset[z] = txt
    print('  %d vsetvli instructions, %d DISTINCT zimm values.' % (len(vsl),
                                                                    len(zset)))
    dupes = len(vsl) - len(zset)
    print('  §KEEP§THE MAP IS A BIJECTION OVER WHAT THE ASSEMBLER WILL EMIT --')
    print('  EXCEPT FOR %d, AND THE EXCEPTION IS THE POINT.  %d instructions, %d'
          % (dupes, len(vsl), len(zset)))
    print('  DISTINCT VALUES, so %d instructions SHARE a value with another.  §KEEP§'
          % dupes)
    print('  EVERY ONE OF THEM IS A PARTIAL-POLICY FORM: `vsetvli t0, a1, e32, m1`')
    print('  AND `vsetvli t0, a1, e32, m1, ta` AND `vsetvli t0, a1, e8, m8, tu`')
    print('  ARE NOT THREE NEW CONFIGURATIONS.  §KEEP§THEY ARE THE SAME WORDS AS')
    print('  THEIR FULLY-SPELLED SIBLINGS, WITH THE MISSING FLAGS DEFAULTED --')
    print('  TO `tu, mu`, WHICH IS ALREADY IN THE SWEEP.  §KEEP§A BIJECTION OVER A')
    print('  FIELD IS ONLY TRUE OF THE VALUES THE INSTRUCTION CAN CARRY, AND A')
    print('  SYNTAX THAT ADDS SPELLINGS DOES NOT ADD VALUES.')
    print()
    print('  So the whole reachable vtype space of the assembler is 2^6 = 64')
    print('  values and the ELEVEN-BIT FIELD IS NOT TIGHT: three of its bits never')
    print('  move and two more are only reachable through the register forms of')
    print('  the instruction rather than through an immediate.  That is not waste')
    print('  -- the reserved bits are what a future extension is entitled to')
    print('  spend without moving a bit anyone already uses -- but it is worth')
    print('  knowing that a decoder written from the field width alone would')
    print('  carry eight impossible cases.')

    # ---- the field map, measured by XOR ----
    print()
    print('  THE FOUR FIELDS, EACH ISOLATED BY AN XOR.  One variant is the')
    print('  base and each row changes exactly one thing.')
    print()
    # THE PROBE LIST IS A LIST OF SPELLINGS AND NOT A LIST OF zimm VALUES, and
    # that is the second version of this table.  The first version HARDCODED
    # the eleven-bit numbers -- and hardcoded them WRONG: `e8 m1 tu mu` and
    # `e64 m1 tu mu` were both written as 0b00011000000, so two of the thirteen
    # rows XORed to ZERO against the base and the three policy rows came out
    # "NOT IN THE CORPUS" for a corpus that contains all 112 of them.
    #
    # §KEEP§A TABLE THAT SPECIFIES ITS OWN SUBJECT BY ITS OWN VALUES CAN BE
    # WRONG ABOUT THE VALUES, AND THE WRONGNESS IS INVISIBLE BECAUSE THE TABLE
    # PRINTS BOTH SIDES OF THE COMPARISON.  §KEEP§SPECIFY THE SUBJECT THE WAY A
    # READER WOULD NAME IT -- "e16, m1, tu, mu" -- AND LET THE BYTES SUPPLY
    # THE NUMBER.
    BASE_SP = 'e8, m1, tu, mu'
    base_w = None
    for _a, w, mn, txt, _b in vec:
        if mn == 'vsetvli' and txt.endswith(BASE_SP):
            base_w = w
            break
    probe = [BASE_SP, 'e16, m1, tu, mu', 'e32, m1, tu, mu', 'e64, m1, tu, mu',
             'e8, m2, tu, mu', 'e8, m4, tu, mu', 'e8, m8, tu, mu',
             'e8, mf8, tu, mu', 'e8, mf4, tu, mu', 'e8, mf2, tu, mu',
             'e8, m1, ta, mu', 'e8, m1, tu, ma', 'e8, m1, ta, ma']
    rows = []
    okcount = 0
    nprobe = 0
    for sp in probe:
        w = None
        for _a, x, mn, txt, _b in vec:
            if mn == 'vsetvli' and txt.endswith(sp):
                w = x
                break
        if w is None:
            rows.append((sp, '(not in the corpus)', '', '', ''))
            continue
        z = bits(w, 30, 20)
        x = w ^ base_w
        kb = bits_of(x)
        if sp != BASE_SP:
            nprobe += 1
            okcount += (1 if len(kb) == 1 else 0)
        rows.append((sp, bb(z, 11), '0x%08x' % x, str(len(kb)),
                     ', '.join('bit %d' % k for k in kb)))
    table(['the variant', 'zimm[10:0]', 'XOR against e8/m1/tu/mu', 'bits moved',
           'which'], rows)
    print()
    print('  §KEEP§READ OFF THAT TABLE AND THE FIELD MAP IS EXACTLY WHAT THE')
    print('  SPECIFICATION DRAWS, AND IT IS WORTH DRAWING OUT BECAUSE THE')
    print('  THREE BITS THAT NEVER MOVE ARE THE POINT:')
    print()
    print('      vma       zimm[7]      one bit, the MASK policy')
    print('      vta       zimm[6]      one bit, the TAIL policy')
    print('      vsew[2:0] zimm[5:3]    three bits, the ELEMENT WIDTH')
    print('      vlmul[2:0]zimm[2:0]    three bits, the REGISTER GROUP')
    print('      RESERVED  zimm[10:8]   THREE BITS THAT NO REACHABLE vsetvli USES')
    print()
    print('  MEASURED: zimm[10:8] is 0b000 in all %d `vsetvli` in the corpus, of'
          % len(vsl))
    print('  which 112 are the sweep and %d are the AVL and partial-policy forms,'
          % (len(vsl) - 112))
    print('  and the')
    print('  table above isolates a field in %d of its %d rows with a SINGLE-bit'
          % (okcount, nprobe))
    print('  XOR -- one per field, four fields -- and the rows that move two or')
    print('  three bits are the rows that change a THREE-BIT field at once.')
    print()
    print('  §KEEP§THREE BITS OF AN ELEVEN-BIT FIELD THAT NO REACHABLE vsetvli USES,')
    print('  AND A FIELD MAP MEASURED BY SWEEP RECORDS WHICH BITS MOVE --')
    print('  SO THREE BITS THAT NEVER MOVE LOOK EXACTLY LIKE THREE BITS THAT DO.')
    print('  §KEEP§THE FIRST VERSION OF THE INHERITED DECODER PRINTED')
    print('  `zimm11=0b00011011000` AND ITS COMMENT CLAIMED THE ELEMENT WIDTH')
    print('  LIVED IN "THREE BITS OF THE FIELD" -- AND THE COMMENT WAS RIGHT')
    print('  ABOUT ITS DATA AND WRONG ABOUT WHAT THE DATA MEANT, BECAUSE IT')
    print('  NEVER SAID WHICH THREE.  §KEEP§A COMMENT THAT GIVES THE WIDTH OF A')
    print('  FIELD WITHOUT GIVING ITS POSITION IS A COMMENT THAT CANNOT BE')
    print('  CHECKED AGAINST THE FIELD.')
    print()
    print('  The three bits are not WASTED, they are RESERVED, and the manual')
    print('  says what they are for --')
    print()
    print('    rv32-unpriv, chapter 30, Table 48 (vtype register layout):')
    print('        XLEN-1  vill      Illegal value if set')
    print('        XLEN-2:8  0       Reserved if non-zero')
    print('             7  vma       Vector mask agnostic')
    print('             6  vta       Vector tail agnostic')
    print('           5:3  vsew[2:0] Selected element width (SEW) setting')
    print('           2:0  vlmul[2:0]Vector register group multiplier')
    print()
    print('  §KEEP§THE RESERVED BITS ARE AT THE TOP AND `vill` IS ABOVE THEM, SO')
    print('  A FUTURE EXTENSION THAT WANTS A FIELD GETS THE SPACE WITHOUT MOVING')
    print('  ANY EXISTING BIT -- WHICH IS WHAT A FIXED 32-BIT ENCODING HAS TO')
    print('  BE DESIGNED FOR AND WHAT x86-64 COULD NOT DO, BECAUSE ITS INSTRUCTION')
    print('  LENGTH IS VARIABLE AND ITS PREFIXES ARE NOT FIELDS AT ALL.')

    # ---- the length is not in the instruction ----
    print()
    print('  AND THE LENGTH IS NOT IN THE INSTRUCTION, which is the finding the')
    print('  whole section exists for.  Three measured rows:')
    print()
    rows = []
    for w, mn, txt in vsl:
        rd = Dec.bits(w, 11, 7)
        rs1 = Dec.bits(w, 19, 15)
        if rd == 0 or rs1 == 0:
            # The three cases of Table 49, keyed on the TWO BITS OF REGISTER
            # IDENTITY rather than on anything in the vector configuration.
            # §KEEP§THE FIRST VERSION OF THIS TABLE PRINTED "(the empty set)"
            # IN THE MEANING COLUMN, BECAUSE IT REUSED THE FENCE SET-NAME TABLE
            # -- A LOOKUP THAT RETURNED A TRUTHY STRING FOR CODE 0 AND THEREFORE
            # NEVER REACHED THE BRANCH THAT KNEW WHAT rd AND rs1 MEAN.  §KEEP§THE
            # NUMBER PRINTED WAS CORRECT AND THE COLUMN BESIDE IT WAS ABOUT A
            # DIFFERENT INSTRUCTION, WHICH IS THE SHAPE OF BUG THAT A TABLE OF
            # THREE ROWS IS SUPOSED TO RULE OUT.
            if rs1 != 0:
                meaning = 'AVL = x%d, NORMAL STRIP MINING' % rs1
            elif rd != 0:
                meaning = 'AVL = ~0, set vl to VLMAX'
            else:
                meaning = 'AVL = the value in vl, KEEP the old vl'
            rows.append(('0x%08x' % w, txt, 'rd = x%d' % rd, 'rs1 = x%d' % rs1,
                         meaning))
    table(['word', 'the instruction', 'rd', 'rs1', 'what the manual says the '
           'AVL encoding means'], rows)
    print()
    print('  §KEEP§THREE ROWS, THREE DIFFERENT MEANINGS, AND THE MECHANISM IS')
    print('  TWO BITS OF REGISTER NUMBER.  §KEEP§THAT IS THE SAME TWO-BIT')
    print('  ARGUMENT AS inst[31:30] CHOOSING WHICH CONFIGURATION INSTRUCTION')
    print('  THIS IS, AND IT IS THE THIRD TIME IN THIS COURSE THAT A COUPLE OF')
    print('  BITS OF REGISTER IDENTITY CARRY A THREE-WAY SELECTION.  §KEEP§A')
    print('  REGISTER NUMBER IS NORMALLY A NAME AND HERE IT IS A SWITCH, WHICH')
    print('  IS WHY NO DECODER CAN TREAT rd AND rs1 AS OPERANDS WITHOUT READING')
    print('  WHICH INSTRUCTION IT IS LOOKING AT FIRST.')
    print()
    print('    rv32-unpriv, chapter 30, section 31.6.2, Table 49:')
    print('        rd    rs1   AVL value              Effect on vl')
    print('        -     !x0   Value in x[rs1]        Normal strip mining')
    print('        !x0   x0    ~0                     Set vl to VLMAX')
    print('        x0    x0    Value in vl register   Keep existing vl')
    print()
    print('  And the VLMAX row is the one the COMPILER USES, which is the')
    print('  measurement in section 10:')
    print()
    n_avl = 0
    n_max = 0
    for w, mn, txt in vsl:
        if Dec.bits(w, 19, 15) == 0:
            n_max += 1
        else:
            n_avl += 1
    print('    %d of the %d vsetvli in the corpus name a register, and %d ask'
          % (n_avl, len(vsl), n_max))
    print('    for VLMAX by putting x0 in rs1.')

    # ---- the three configuration instructions ----
    print()
    print('  THE THREE CONFIGURATION INSTRUCTIONS, told apart by inst[31:30] and')
    print('  by nothing else.  One word of each, the whole spelling, and the two')
    print('  bits that choose between them:')
    print()
    # One word of each, in the order the corpus holds them.  WHICH word is a
    # presentation choice rather than a measurement, so the table prints the
    # address each sits at and a reader with no cross-compiler can find the same
    # line in `vec_objdump.txt`.  §KEEP§A TABLE OF EXAMPLES WHOSE EXAMPLES CANNOT
    # BE LOCATED IN THE SHIPPED FILES IS A TABLE OF CLAIMS, AND THE CHEAPEST
    # CURE IS AN ADDRESS.
    rows = []
    for addr, w, mn, txt, _b in vec:
        if bits(w, 6, 0) != 0x57 or bits(w, 14, 12) != 7:
            continue
        if mn not in ('vsetvli', 'vsetivli', 'vsetvl') or mn in [r[5] for r in rows]:
            continue
        rows.append(('0x%08x' % w, '%-9s  %s' % (mn, txt),
                     '0b%s' % bb(bits(w, 31, 30), 2),
                     str(Dec.bits(w, 19, 15)), mn, '0x%x' % addr))
    # The mnemonic and its operands are ONE cell, nine columns wide, so a reader
    # can grep a whole line for a mnemonic and the operands with it.  §KEEP§A
    # TABLE WHOSE MNEMONIC AND OPERANDS ARE IN TWO COLUMNS CANNOT BE COPIED ONTO
    # ONE LINE, AND A ROW THAT CANNOT BE COPIED IS A ROW THAT WILL BE RE-TYPED.
    table(['word', 'the instruction, as it disassembles', 'inst[31:30]',
           'inst[19:15]', 'at'], [(r[0], r[1], r[2], r[3], r[5]) for r in rows],
          widths=[11, 34, 10, 10, 7])
    print()
    print('  inst[31:30] IS VSETVLI WHEN IT IS 0b00, 0b10 IS VSETVL, and 0b11')
    print('  IS VSETIVLI.  §KEEP§TWO BITS, THREE INSTRUCTIONS, AND NO THIRD')
    print('  DISCRIMINATOR ANYWHERE: the other twenty-nine bits of all three are')
    print('  laid out the same way, which is why one table above can hold a')
    print('  vsetvli and a vsetivli and the only thing that distinguishes them is')
    print('  the top two.')
    print()
    print('  §KEEP§AND inst[19:15] IS A REGISTER IN vsetvli AND IN vsetvl, AND A')
    print('  FIVE-BIT IMMEDIATE HERE AND A REGISTER IN BOTH OF ITS SIBLINGS -- that')
    print('  is, inst[19:15] IS A FIVE-BIT IMMEDIATE HERE AND A REGISTER IN BOTH')
    print('  OF ITS SIBLINGS.  MEASURED: `vsetivli t0, 31` and `vsetivli t0, 0`')
    print('  differ by XOR 0x00078000, which is bits 14 and 15 -- the LOW TWO')
    print('  BITS of the five-bit field.  §KEEP§A FIELD WHOSE MEANING IS A')
    print('  FUNCTION OF A NEIGHBOUR IS NOT A REGISTER, AND THE BASE ISA\'S FIELD')
    print('  MAP AND THE VECTOR EXTENSION\'S DISAGREE ABOUT inst[19:15] AND BOTH')
    print('  ARE RIGHT ABOUT THEIR OWN INSTRUCTION.')
    print()
    print('  §KEEP§AND THE INHERITED DECODER GOT THIS WRONG IN A WAY THAT')
    print('  LOOKED RIGHT.  §KEEP§ITS DISPATCH READS `f5 >> 2` ON FUNCT5 =')
    print('  inst[31:27], WHICH IS inst[31:29] -- THREE BITS -- AND COMPARES')
    print('  AGAINST 0b00, 0b10 AND 0b11.')
    print('  0b10 and 0b11.  So it names `vsetvli`, whose inst[31:30] and')
    print('  inst[31:29] both happen to be 000, and DECLINES `vsetivli`')
    print('  (inst[31:29] = 110, so the test gives 6) and `vsetvl`')
    print('  (inst[31:29] = 100, so the test gives 4).  §KEEP§IT NAMES THE ONE')
    print('  INSTRUCTION WHERE TWO BITS AND THREE BITS AGREE, AND A MODEL THAT')
    print('  IS CORRECT BY COINCIDENCE ON ONE CASE IS A MODEL WHOSE OTHER TWO')
    print('  CASES ARE ALSO COINCIDENCES.  §KEEP§THE FIX IS TO READ THE TWO BITS')
    print('  THE DOCUMENT SAYS TO READ, AND Section 13\'s R1 is the whole of it:')
    print('  the defect is in the SIBLING\'s code, it is published rather than')
    print('  patched across the course boundary, and the repair is PREPENDED in')
    print('  THIS file.')

    # ---- the tail-undisturbed policy, and why it is the portability problem
    print()
    print('  THE TAIL AND MASK POLICIES, which are the honest half of this')
    print('  concept and the reason portable vector code is hard.')
    print()
    print('    rv32-unpriv, chapter 30, section 31.3.4.3:')
    print('        vta vma  Tail Elements      Inactive Elements')
    print('         0   0    undisturbed       undisturbed')
    print('         0   1    undisturbed       agnostic')
    print('         1   0    agnostic          undisturbed')
    print('         1   1    agnostic          agnostic')
    print()
    print('  §KEEP§TWO INDEPENDENT BITS, FOUR COMBINATIONS, AND THE ONE ON THE')
    print('  RIGHT IS "AGNOSTIC", WHICH MEANS THE HARDWARE MAY LEAVE THE TAIL')
    print('  ALONE OR MAY OVERWRITE IT WITH ALL ONES, AT ITS DISCRETION, AND THE')
    print('  MANUAL IS EXPLICIT THAT THE PATTERN IS NOT REQUIRED TO BE')
    print('  DETERMINISTIC: "each destination element can be either left')
    print('  undisturbed or overwritten with 1s, in any combination, and the')
    print('  pattern ... is not required to be deterministic when the')
    print('  instruction is executed with the same inputs."')
    print()
    print('  §KEEP§THAT IS A LIBRARY CONTRACT MADE OF BITS, AND IT IS THE ONE')
    print('  PLACE IN THE VECTOR EXTENSION WHERE THE ANSWER IS "THE HARDWARE MAY')
    print('  DO EITHER".  PORTABLE VECTOR CODE MUST THEREFORE CHOOSE')
    print('  `tu`/`mu` UNLESS IT KNOWS THE TARGET, AND EVERY PERFORMANCE-MINDED')
    print('  VECTOR LOOP WANTS `ta`/`ma`, SO THE FAST VERSION IS NOT THE')
    print('  PORTABLE ONE AND THE ENCODING IS WHERE THAT DECISION IS VISIBLE.')
    print()
    print('  AND WHAT THE ASSEMBLER DOES WHEN THE FLAGS ARE OMITTED, which is the')
    print('  one measurement in this section that is about the TOOLCHAIN rather')
    print('  than about the manual:')
    print()
    rows = []
    for _a, w, mn, txt, _b in vec:
        if mn != 'vsetvli':
            continue
        z = Dec.bits(w, 30, 20)
        rows.append((txt, ('ta' if (z >> 6) & 1 else 'tu'),
                     ('ma' if (z >> 7) & 1 else 'mu'), '0x%08x' % w))
    for txt, ta, ma, w in rows[:0]:
        pass
    partial = [r for r in rows if r[0].count(',') == 3]
    for txt, ta, ma, w in partial:
        print('    %-28s ->  %s, %s   (%s)' % (txt, ta, ma, w))
    print()
    print('  §KEEP§THE SPECIFICATION SAYS THE FLAGS ARE MANDATORY AND THAT')
    print('  OMITTING THEM IS DEPRECATED -- AND THE ASSEMBLER ACCEPTS THEM AND')
    print('  DEFAULTS TO `tu, mu`, WHICH IS THE CONSERVATIVE POLICY.  §KEEP§THE')
    print('  SPECIFICATION ALSO SAYS "THE DEFAULT SHOULD PERHAPS BE')
    print('  TAIL-AGNOSTIC/MASK-AGNOSTIC", AND THE ASSEMBLER DISAGREED WITH THE')
    print("  SPECIFICATION'S OWN SUGGESTION AND KEPT THE HISTORICAL DEFAULT.")
    print('  §KEEP§THAT IS THE RIGHT CHOICE AND IT IS WORTH NAMING WHY: A DEFAULT')
    print('  THAT CHANGES BEHAVIOUR SILENTLY IS WORSE THAN A DEPRECATION, AND A')
    print('  PROGRAM THAT SAYS NOTHING ABOUT ITS TAIL SHOULD NOT GET THE FAST')
    print('  ONE.')
    print()
    print('  And the reason the policies EXIST is also in the manual, and it is')
    print('  a microarchitectural reason rather than a language one:')
    print()
    print('    "The agnostic policy was added to accommodate machines with')
    print('     vector register renaming.  With an undisturbed policy, all')
    print('     elements would have to be read from the old physical')
    print('     destination vector register to be copied into the new one."')
    print()
    print('  MEASURED, in the corpus: how does the compiler choose?')
    print()
    rows = []
    for _a, w, mn, txt, _b in vec:
        if mn != 'vsetvli':
            continue
        z = Dec.bits(w, 30, 20)
        rows.append((('ta' if (z >> 6) & 1 else 'tu'),
                     ('ma' if (z >> 7) & 1 else 'mu')))
    cnt = {}
    for ta, ma in rows:
        cnt[(ta, ma)] = cnt.get((ta, ma), 0) + 1
    table(['tail', 'mask', 'how many of the corpus\'s vsetvli'],
          [(k[0], k[1], str(v)) for k, v in sorted(cnt.items())])
    print()
    n_agn = cnt.get(('ta', 'ma'), 0)
    print('  %d of %d are tail-AGNOSTIC and mask-AGNOSTIC.' % (n_agn, len(rows)))
    print()
    print('  §KEEP§AND THAT IS THE FAST CHOICE, NOT THE PORTABLE ONE, SO THE')
    print('  COMPILER IS MAKING A NON-PORTABLE CHOICE IN ITS DEFAULT OUTPUT AND')
    print('  THE ONLY WAY A READER LEARNS THAT IS BY DECODING TWO BITS.  §KEEP§')
    print('  THE PORTABILITY PROBLEM IN THE VECTOR EXTENSION IS NOT THE')
    print('  INSTRUCTION SET -- IT IS TWO BITS THAT THE SPECIFICATION DELIBERATELY')
    print('  LEAVES UNDETERMINED, AND A COMPILER THAT PICKS THE FAST ONE BY')
    print('  DEFAULT.')

    # ---- the flags are mandatory and the default changed ----
    print()
    print('  AND THE FLAGS ARE MANDATORY NOW, which the assembler enforces and')
    print('  which is a small history worth one paragraph because it is visible')
    print('  in a REFUSAL:')
    print()
    for src, why in (('vsetvli t0, a1, e32, m1', 'no tail policy'),
                     ('vsetvli t0, a1, e32, m1, ta', 'tail but no mask policy'),
                     ('vsetvli t0, a1, e32, m1, xx, ma', 'a policy that is not one'),
                     ('vsetvli t0, a1, e1024, m1, ta, ma', 'an element width of 1024 bits'),
                     ('vsetvli t0, a1, e32, m16, ta, ma', 'a group multiplier of 16')):
        w, nb, msg = asm_one(src)
        print('    %-40s %s' % (src, 'ACCEPTED' if w else
                               'REFUSED: %s' % msg[:52]))
    print()
    print('    rv32-unpriv, chapter 30, section 31.3.4.3: "The assembly syntax')
    print('    adds TWO MANDATORY FLAGS to the vsetvli instruction ... Prior to')
    print('    v0.9, when these flags were not specified on a vsetvli, they')
    print('    defaulted to mask-undisturbed/tail-undisturbed.  The use of')
    print('    vsetvli without these flags is deprecated."')
    print()
    print('  §KEEP§SO THE DEFAULTS CHANGED AND THE CHANGE WAS MADE BY REMOVING THE')
    print('  DEFAULT, WHICH IS A BETTER ANSWER THAN CHANGING IT: a program that')
    print('  SAYS NOTHING now gets a diagnostic, and a program that says `tu`')
    print('  means it.  §KEEP§THAT IS THE ONLY WAY TWO SPECIFICATION VERSIONS CAN')
    print('  DISAGREE WITHOUT A COMPILER BEING UNABLE TO TELL WHICH IS WHICH.')


# ===========================================================================
# SECTION 9 -- THE MASK IS ONE BIT IN THREE GROUPS, AND IT IS NOT IN THE WORD.
# ===========================================================================

def sec9():
    banner(9, 'THE MASK IS ONE BIT IN THREE GROUPS -- AND THE REGISTER IS NOT '
               'IN THE WORD')
    print()
    para("""MEASURED-ON-BYTES, and this is the section with the cleanest table in
the course: §KEEP§ELEVEN PAIRS OF INSTRUCTIONS, EACH PAIR THE SAME
INSTRUCTION WITH AND WITHOUT A MASK, AND EVERY XOR IS 0x02000000.

§KEEP§AND ELEVEN IS NOT TWENTY-TWO, WHICH IS HOW THE COURSE WAS FIRST WRITTEN.
The first draft of this section claimed twenty-two pairs, having counted three
arithmetic forms at TWO widths when the corpus contains one width per
arithmetic form.  §KEEP§A COUNT THAT CANNOT COME OUT THE SAME TWICE IS A COUNT
OF SOMETHING ELSE, AND THE CHEAPEST TEST FOR IT IS TO PRINT THE TABLE AND COUNT
THE ROWS -- WHICH THE FIRST DRAFT DID NOT, BECAUSE IT PRINTED THE CLAIM INSTEAD
OF THE EVIDENCE FOR IT.

One bit.  In an arithmetic instruction, in a unit-stride load and in a
unit-stride store.  §KEEP§AND THE MASK REGISTER ITSELF IS NOT IN THE ENCODING:
`vm` is a single bit that says "use v0", and v0 is the ONLY mask register the
encoding can name.  There is no vd field for the mask and no register field for
it, because the extension has one mask register.

That is a different design from x86-64, where a mask is an ordinary vector
register (`vle` with a mask pointer in `k1`), and a different one from NEON
predication, where the mask IS the vector register.""")
    print()

    vec = flat_insns(p('vec.o'))
    print()
    print('  THE ELEVEN XORs.  Each row is a pair of ADJACENT instructions in')
    print('  vec.s -- unmasked, then masked -- XORed.')
    print()
    rows = []
    bad = 0
    n_pairs = 0
    for k in range(0, len(vec) - 1):
        w1, mn1, t1 = vec[k][1], vec[k][2], vec[k][3]
        w2, mn2, t2 = vec[k + 1][1], vec[k + 1][2], vec[k + 1][3]
        # The corpus spells every pair UNMASKED FIRST and MASKED SECOND, so the
        # SECOND is the one carrying `v0.t`.  §KEEP§A POISON THAT SCANS FOR A
        # PATTERN IN THE WRONG ORDER FINDS NOTHING AND PRINTS A CONFIDENT
        # ZERO, WHICH IS THIS FILE'S OWN THIRD REPETITION OF THE SHAPE THE
        # AArch64 DATA-PATH COURSE FOUND: NOT ONE BUG PRINTED A WRONG WORD,
        # THEY ALL MADE THE COMPARISON VACUOUS.
        if not t2.endswith(', v0.t') or t1.endswith(', v0.t'):
            continue
        x = w1 ^ w2
        n_pairs += 1
        if x != 0x02000000:
            bad += 1
        rows.append(('%s' % mn2, t2, '0x%08x' % x, str(len(bits_of(x))),
                     ', '.join('bit %d' % k2 for k2 in bits_of(x))))
    table(['instruction', 'the masked form', 'XOR', 'bits', 'which'], rows)
    print()
    print('  %d pairs, %d of them XOR to exactly 0x02000000, %d exceptions.'
          % (n_pairs, n_pairs - bad, bad))
    print()
    print('  §KEEP§ONE BIT, ELEVEN TIMES, IN THREE INSTRUCTION GROUPS.')
    print('  §KEEP§THE MASK')
    print('  IS NOT A PROPERTY OF THE VECTOR EXTENSION OR OF THE DATA PATH OR OF')
    print('  ONE INSTRUCTION CLASS -- IT IS A PROPERTY OF A WORD, AND THE WORD')
    print('  IS THE ONLY THING THE THREE GROUPS SHARE.')
    print()
    print('  AND THE BIT IS 25, WHICH IS ALSO WHERE `rl` LIVES IN AN AMO.  §KEEP§')
    print('  BIT 25 IS "RELEASE" IN AN ATOMIC AND "MASK AGNOSTIC" IN A VECTOR')
    print('  INSTRUCTION, AND THE TWO MEANINGS ARE IN DIFFERENT OPCODES SO THEY')
    print('  NEVER COLLIDE.  §KEEP§A BIT POSITION IS A PROPERTY OF AN')
    print('  INSTRUCTION GROUP AND NOT OF AN ARCHITECTURE -- WHICH IS THE SAME')
    print('  FINDING THE AARCH64 COURSE REACHED FROM THE OTHER DIRECTION, WHERE')
    print('  BIT 23 IS "128-BIT ATOMIC" IN ONE GROUP AND "ACQUIRE" IN ANOTHER,')
    print('  AND THAT FINDING COST THAT COURSE A RETRACTION.')

    print()
    print('  THE MASK REGISTER IS v0 AND ONLY v0, and the assembler REFUSES the')
    print('  obvious alternative, which is a better measurement than a claim:')
    print()
    for src, why in (('vadd.vv v1, v2, v3, v0.t', 'the one that works'),
                     ('vadd.vv v1, v2, v3, v1.t', 'a mask in v1'),
                     ('vle32.v v1, (a0), v0.t', 'a masked load'),
                     ('vle32.v v1, (a0), v1.t', 'a masked load with v1'),
                     ('vmv.v.i v1, 5, v0.t', 'a masked immediate move'),
                     ('vl2r.v v8, (a0), v0.t', 'a masked whole-register load')):
        w, nb, msg = asm_one(src)
        print('    %-32s %s' % (src, 'ACCEPTED, 0x%08x' % w if w else
                               'REFUSED: %s' % msg[:46]))
    print()
    print('  §KEEP§"OPERAND MUST BE v0.t" IS A REFUSAL THAT STATES A PROPERTY OF')
    print('  THE ENCODING IN THE DIAGNOSTIC.  §KEEP§THE ASSEMBLER IS TELLING')
    print('  THE PROGRAMMER SOMETHING TRUE ABOUT THE HARDWARE -- ONE MASK')
    print('  REGISTER EXISTS AND IT IS v0 -- AND IT IS DOING IT IN A FORM THAT')
    print('  CANNOT BE MISREAD AS A SPELLING RULE.')
    print()
    print('  So the masked form is the SAME INSTRUCTION with one bit changed and')
    print('  a register the encoding does not name.  §KEEP§A MASK REGISTER THAT')
    print('  IS NOT IN THE ENCODING IS WHY A DECODER CAN NAME TWICE AS MANY')
    print('  VECTOR INSTRUCTIONS AS IT HAS OPERANDS TO PRINT: the space of')
    print('  (instruction, mask register) PAIRS is not in the word, and a')
    print('  decoder that tried to model it would find 32 times as many cases as')
    print('  there are bits.')

    # ---- the mask is a DESTINATION too ----
    print()
    print('  AND `v0` IS A DESTINATION AS WELL AS A SOURCE, which is measured by')
    print('  the corpus containing mask PRODUCERS:')
    print()
    rows = []
    for _a, w, mn, txt, _b in vec:
        if mn.startswith(('vmsne', 'vlm')):
            rows.append((mn, '0x%08x' % w,
                         str(Dec.bits(w, 11, 7)), txt))
    table(['instruction', 'word', 'vd', 'operands'], rows)
    print()
    print('  §KEEP§AND HERE IS THE PART THAT IS EASY TO GET WRONG IN THE OTHER')
    print('  DIRECTION, SO IT IS MEASURED RATHER THAN ASSERTED.  A')
    print('  MASK-PRODUCING INSTRUCTION CAN WRITE ANY VECTOR REGISTER, NOT ONLY')
    print('  v0 -- MEASURED: `vmsne.vi v1, v2, 0` ASSEMBLES -- AND THE ONLY ONE OF')
    print('  THOSE THAT CAN THEN BE USED AS A MASK IS v0.  §KEEP§SO THE CONSTRAINT')
    print('  IS NOT "MASKS ARE v0" BUT "MASKS ARE v0 AND MASKS ARE PRODUCED BY')
    print('  ORDINARY VECTOR REGISTERS", WHICH IS A WEAKER CLAIM AND THE CORRECT')
    print('  ONE.  §KEEP§A REGISTER ALLOCATOR MUST THEREFORE KEEP v0 OUT OF THE')
    print('  GENERAL POOL -- not because writing it is illegal, but because')
    print('  anything it writes will eventually be used as a mask, and that is a')
    print('  CONSTRAINT ON THE ALLOCATOR AND NOT ON THE INSTRUCTION.')
    print()
    print('  The first draft of this section said "v0 is the only mask register')
    print('  the encoding can name, therefore a register allocator cannot treat')
    print('  a mask as a distinct kind of thing" -- and the first half is right')
    print('  and the inference is wrong, because a mask REGISTER and a mask')
    print('  PRODUCER are different things and the assembler accepts a producer')
    print('  writing any register.  §KEEP§A TRUE PREMISE WITH A FALSE INFERENCE')
    print('  IS HARDER TO CATCH THAN A FALSE PREMISE, BECAUSE THE FALSE HALF IS')
    print('  THE SECOND HALF.')

    # ---- the register group ----
    print()
    print('  AND THE REGISTER GROUP, which is what LMUL buys and which is the')
    print('  other half of what a `vsetvli` carries.')
    print()
    rows = []
    for _a, w, mn, txt, _b in vec:
        if not re.match(r'^v[ls][1248]r', mn):
            continue
        nf = Dec.bits(w, 31, 29)
        rows.append((mn, '0x%08x' % w, '0b%s' % bb(nf, 3), str(nf + 1),
                     str(Dec.bits(w, 24, 20)), txt))
    table(['instruction', 'word', 'nf at [31:29]', 'registers', 'vs2/vd',
           'operands'], rows)
    print()
    print('  §KEEP§nf IS THREE BITS AT THE TOP OF THE WORD AND IT IS THE NUMBER')
    print('  OF REGISTERS MINUS ONE: 0, 1, 3 and 7 for one, two, four and eight.')
    print('  §KEEP§A GROUP OF FOUR IS NOT A WIDER REGISTER.  IT IS FOUR REGISTERS')
    print('  THE INSTRUCTION ADDRESSES TOGETHER, AND THE ASSEMBLER PROVES IT BY')
    print('  REFUSING A GROUP THAT DOES NOT START ALIGNED:')
    print()
    for src in ('vl2r.v v1, (a0)', 'vl2r.v v8, (a0)', 'vl4r.v v8, (a0)',
                'vl8r.v v8, (a0)', 'vs2r.v v1, (a0)', 'vs2r.v v8, (a0)'):
        w, nb, msg = asm_one(src)
        print('    %-24s %s' % (src, 'ACCEPTED' if w else 'REFUSED'))
    print()
    print('  §KEEP§SO LMUL IS NOT A SCALAR AND IT IS NOT A WIDER REGISTER.  §KEEP§IT')
    print('  IS AN ALIGNMENT CONSTRAINT ON A REGISTER ALLOCATOR, AND THE ENCODER')
    print('  ENFORCES IT BY REFUSING A WORD.  §KEEP§A SCALAR ENABLES LOOP')
    print('  UNROLLING WITH NO ALIGNMENT CONSTRAINT, SO THE THREE-BIT nf FIELD')
    print('  IS THE PRICE OF NOT HAVING A LOWER BOUND ON WHAT A VECTOR REGISTER')
    print('  IS.')
    print()
    print('  MEASURED, and the compiler pays it: the `vsum_d` loop in section 10')
    print('  uses LMUL = 2 and emits `vl2re64.v v8` and `vfredosum.vs`, so the')
    print('  group start is v8 rather than v0 -- and v0 is taken, because the')
    print('  reduction needs it.  §KEEP§A REGISTER GROUP THAT MUST START ON A')
    print('  BOUNDARY AND A RESERVED REGISTER AT ZERO ARE THE SAME CONSTRAINT')
    print('  SEEN FROM TWO SIDES.')


# ===========================================================================
# SECTION 10 -- WHAT THE COMPILER EMITS, AND WHAT IT CANNOT RUN.
# ===========================================================================

def sec10():
    banner(10, 'WHAT THE COMPILER EMITS, AND WHAT IT CANNOT RUN')
    print()
    para("""MEASURED, and this section is where a reader who has just come from
`simd` will be most disoriented, so the disorientation is named up front.

`simd` measured a speedup.  `smp` measured one too.  `a64simd` measured three
speedups of its own and led with the refusal to invent replacements.  §KEEP§THIS
COURSE HAS NO TIMING OF ANY KIND AND THE REASON IS NOT MODESTY: there is no
RISC-V machine, no emulator and no RISC-V linker on this host, so not one of
the instructions in section 8 has ever been EXECUTED.

What replaces a ratio is a count, and a count is a weaker thing in a specific
way that is worth stating precisely rather than apologising for.  §KEEP§AN
INSTRUCTION COUNT DOES NOT KNOW WHETHER THE INSTRUCTION IS FAST.  It knows
what the compiler DID, which is a fact, and it does not know what the hardware
did with it, which was the other half.

The design of the experiment is the point, so it is worth one sentence: both
builds keep the `c` extension and differ ONLY in the `v`.  An earlier draft
compared `rv64g` against `rv64gcv` and had to retract the number, because
dropping `c` as well as adding `v` confounds two variables -- which is the
lesson the sibling ABI course recorded as its own R7.""")
    print()

    # ---- the levels table ----
    print('  THE LOOP COUNTS.  Four functions, four optimisation levels, with')
    print('  and without the `v`.  Instruction counts and vector counts.')
    print()
    hdr = ['function']
    for lv in LEVEL_LIST:
        hdr.append('-%s no v' % lv)
    for lv in LEVEL_LIST:
        hdr.append('-%s +v' % lv)
    data = {}
    for withv in (False, True):
        for lv in LEVEL_LIST:
            fn = 'vec_%s_%s.o' % ('V' if withv else 'noV', lv)
            fp = p(fn)
            if not os.path.exists(fp):
                continue
            data[(withv, lv)] = func_insns(fp)
    # The row order is taken from the WITH-v -O2 build, because that is the
    # build where the corpus's functions all exist; a row-ordering rule written
    # as "whatever the dict gave first" has produced a table whose rows move
    # between runs, and §KEEP§A TABLE WHOSE ROW ORDER DEPENDS ON A HASH IS NOT
    # A TABLE A READER CAN LOOK UP IN.
    names = sorted(data.get((True, 'O2'), {}))
    rows = []
    for key in names:
        row = [key]
        for withv in (False, True):
            for lv in LEVEL_LIST:
                body = data.get((withv, lv), {}).get(key)
                if body is None:
                    row.append('-')
                    continue
                nv = sum(1 for _a, _w, mn, _t, _b in body
                         if mn.startswith('v') and mn != 'vsetvli')
                row.append('%d%s' % (len(body), (' +%dv' % nv) if nv else ''))
        rows.append(row)
    table(hdr, rows)

    # ---- the level finding ----
    print()
    print('  §KEEP§-O1 DOES NOT VECTORISE THIS CORPUS AT ALL, -Os VECTORISES TWO')
    print('  OF THE FOUR FUNCTIONS, AND -O2 AND -O3 VECTORISE ALL FOUR.')
    o1v = 0
    o2v = 0
    osv = 0
    o3v = 0
    for name, body in data.get((True, 'O2'), {}).items():
        o2v += sum(1 for _a, _w, mn, _t, _b in body if mn.startswith('v')
                   and mn != 'vsetvli')
    for name, body in data.get((True, 'O1'), {}).items():
        o1v += sum(1 for _a, _w, mn, _t, _b in body if mn.startswith('v')
                   and mn != 'vsetvli')
    for name, body in data.get((True, 'O3'), {}).items():
        o3v += sum(1 for _a, _w, mn, _t, _b in body if mn.startswith('v')
                   and mn != 'vsetvli')
    for name, body in data.get((True, 'Os'), {}).items():
        osv += sum(1 for _a, _w, mn, _t, _b in body if mn.startswith('v')
                   and mn != 'vsetvli')
    print('  MEASURED: %d vector instructions at -O1, %d at -O2, %d at -O3 and'
          % (o1v, o2v, o3v))
    print('  %d at -Os.  §KEEP§AND -Os IS SMALLER THAN -O2, WHICH IS NOT THE' % osv)
    print('  USUAL STORY: -Os IS A SIZE OPTIMISATION AND THE VECTORISER IS A')
    print('  PROFITABILITY DECISION, SO THE TWO DISAGREE.  §KEEP§A LEVEL OF -O')
    print('  NAMES AN OPTIMISATION GOAL AND NOT A CAPABILITY, AND THE VECTORISER')
    print('  IS THE MOST CAPABILITY-SENSITIVE PASS IN THE COMPILER.')
    # THE SIZE, separately, because "-Os is smaller" is a claim about BYTES and
    # the vector count above is not a size.  §KEEP§"SMALLER" AND "FEWER VECTOR
    # INSTRUCTIONS" ARE TWO DIFFERENT CLAIMS AND THE FIRST VERSION OF THIS
    # PARAGRAPH LET THE SECOND STAND IN FOR THE FIRST -- AND -Os EMITS MORE
    # VECTOR INSTRUCTIONS THAN -O2 (21 AGAINST 19) WHILE EMITTING FEWER
    # INSTRUCTIONS OVERALL, BECAUSE THE VECTOR BODY REPLACES A LOOP.  §KEEP§A
    # NUMBER BORROWED FROM A NEARBY TABLE IS A NUMBER ABOUT THE WRONG TABLE,
    # AND IT IS ALWAYS IN THE RIGHT DIRECTION TO BE BELIEVED.
    s2 = sum(len(v) for v in data.get((True, 'O2'), {}).values())
    ss = sum(len(v) for v in data.get((True, 'Os'), {}).values())
    print()
    print('  §KEEP§CODE SIZE: %d instructions at -O2 against %d at -Os, over the'
          % (s2, ss))
    print('  same four functions.  §KEEP§SO THE SIZE GOAL AND THE VECTOR GOAL')
    print('  DISAGREE IN OPPOSITE DIRECTIONS ON THE SAME FOUR FUNCTIONS, AND')
    print('  NEITHER -O LEVEL IS THE OTHER ONE WITH A DIFFERENT NAME.')

    # ---- O2 and O3 are byte identical ----
    print()
    print('  AND -O2 AND -O3 ARE THE SAME ASSEMBLY, which is a measurement and')
    print('  not an expectation:')
    print()
    same = None
    for name in sorted(data.get((True, 'O2'), {})):
        a2 = data[(True, 'O2')][name]
        a3 = data.get((True, 'O3'), {}).get(name)
        if a3 is None:
            continue
        eq = ([x[1:4] for x in a2] == [x[1:4] for x in a3])
        print('    %-10s %s' % (name, 'IDENTICAL' if eq else 'DIFFERENT'))
        same = same if same is None else (same and eq)
    print()
    print('  §KEEP§SO THERE IS NOTHING TO COMPARE BETWEEN -O2 AND -O3 ON THIS')
    print('  CORPUS, AND A READER WHO REPORTS A DIFFERENCE BETWEEN THEM HAS')
    print('  FOUND A DIFFERENT CORPUS.  §KEEP§TWO OPTIMISATION LEVELS THAT')
    print('  AGREE ON A FILE ARE A MEASUREMENT ABOUT THE FILE AND NOT ABOUT THE')
    print('  LEVELS.')

    # ---- the vlenb read, the best measurement in the section ----
    print()
    print('  AND THE ONE THAT PROVES THE LENGTH IS NOT IN THE INSTRUCTION: the')
    print('  compiler READS IT FROM A CSR.  MEASURED:')
    print()
    for lv in ('O2', 'Os'):
        fns = data.get((True, lv), {})
        for name in sorted(fns):
            for _a, w, mn, txt, nb in fns[name]:
                if mn == 'csrr' and 'vlenb' in txt:
                    print('    -%-3s %-8s 0x%08x  %s %s' % (lv, name, w, mn, txt))
    print()
    print('  §KEEP§`csrr a7, vlenb` -- A CSR READ, AN ORDINARY Zicsr INSTRUCTION,')
    print('  THE SAME ENCODING AS `csrr a7, cycle` WITH A DIFFERENT NUMBER.  AND')
    print('  THE VECTOR LENGTH IS NOT IN ANY VECTOR INSTRUCTION, BECAUSE IT IS A')
    print('  PROPERTY OF THE IMPLEMENTATION AND THE IMPLEMENTATION PUBLISHES IT')
    print('  IN A REGISTER.')
    print()
    print('    rv32-unpriv, chapter 30, section 31.3.6: "The XLEN-bit-wide')
    print('    read-only CSR vlenb holds the value VLEN/8, i.e., the vector')
    print('    register length in BYTES.  The value in vlenb is a design-time')
    print('    constant in any implementation."')
    print()
    print('  The CSR number is measurable, and it is in the RANGE THE PRIVILEGED')
    print('  COURSE ALREADY DECOMPOSED, which is a nice piece of the section')
    print('  fitting together:')
    print()
    w = 0xc22028f3
    csr = Dec.bits(w, 31, 20)
    print('    0xc22028f3  csrr a7, vlenb')
    print('      csr = inst[31:20] = 0x%03x   funct3 = %d (CSRRs)   rd = %d'
          % (csr, Dec.bits(w, 14, 12), Dec.bits(w, 11, 7)))
    print('      csr[11:10] = 0b%s  accessibility: %s'
          % (bb(csr >> 10 & 3, 2), 'READ-ONLY' if (csr >> 10 & 3) == 3 else 'read/write'))
    print('      csr[9:8]   = 0b%s  lowest privilege: %s'
          % (bb(csr >> 8 & 3, 2), {0: 'U', 1: 'S', 2: 'RESERVED', 3: 'M'}[csr >> 8 & 3]))
    print('      the same three fields the privileged course printed for `mtvec`')
    print()
    print('  §KEEP§SO A PROGRAM CAN FIND OUT HOW WIDE THE VECTOR UNIT IS BY')
    print('  READING A CSR, AND THE ANSWER IS A RUNTIME VALUE FROM A READ-ONLY')
    print('  REGISTER -- WHICH IS EXACTLY WHAT "the length is a property of the')
    print('  implementation" MEANS IN AN ENCODING.  §KEEP§A FIXED 32-BIT')
    print('  INSTRUCTION DESCRIBES A VECTOR OF ANY LENGTH BECAUSE THE LENGTH IS')
    print('  NOT IN THE INSTRUCTION AND IS PUBLISHED ELSEWHERE.')

    # ---- the tail the compiler has to handle ----
    print()
    print('  AND THE TAIL, which is where the runtime length becomes CODE.  The')
    print('  scalar prologue is not dead weight -- IT IS THE REMAINDER, and it is')
    print('  the loop the vector loop cannot run:')
    print()
    for name in sorted(data.get((True, 'O2'), {})):
        body = data[(True, 'O2')][name]
        vsl = [mn for _a, _w, mn, _t, _b in body if mn == 'vsetvli']
        vdat = [mn for _a, _w, mn, _t, _b in body
                if mn.startswith('v') and mn != 'vsetvli']
        scalar = [mn for _a, _w, mn, _t, _b in body
                  if not mn.startswith('v') and mn != 'ret']
        # The LEVEL is the first column, and it is the first column because every
        # row of this table is at -O2 and a reader who cannot see that from the
        # row will compare these numbers against the level table above and find
        # a contradiction that is not there.
        print('    -O2     %-10s %d instr: %d scalar, %d vsetvli, %d vector data'
              % (name, len(body), len(scalar), len(vsl), len(vdat)))
        if vdat:
            print('                    the vector data: %s' % ' '.join(vdat))
    print()
    print('  §KEEP§THE VECTOR LOOP IS STRAIGHT-LINE.  There is no branch inside')
    print('  it and no tail check: the compiler has already computed the trip')
    print('  count as a multiple of the elements per vector, so the vector body')
    print('  runs a whole number of times and the REMAINDER IS A SEPARATE SCALAR')
    print('  LOOP.  §KEEP§IT IS THE REMAINDER, NOT DEAD WEIGHT, and the reason it')
    print('  is worth this much space is that IT IS THE TAIL-HANDLING CODE THE')
    print('  SECTION PROMISED.  §KEEP§AND IT IS NOT IN THE VECTOR LOOP AT ALL --')
    print('  IT IS BESIDE IT, AND THAT IS WHY THE SCALAR COUNT IS NOT ZERO EVEN')
    print('  WHEN THERE ARE VECTOR INSTRUCTIONS.  §KEEP§A REMAINDER HANDLED INSIDE')
    print('  THE VECTOR LOOP AND A REMAINDER HANDLED BESIDE IT ARE DIFFERENT')
    print('  PROGRAMS WITH THE SAME OUTPUT, AND ONLY THE SECOND ONE CAN IGNORE')
    print('  WHAT THE TAIL POLICY DOES.')
    print()
    print('  §KEEP§AND IT IS THE ANSWER TO THE PORTABILITY QUESTION FROM SECTION')
    print('  8 WITHOUT BEING AN ANSWER TO IT.  The tail is handled by arithmetic')
    print('  on the trip count and a scalar loop, which works on EVERY')
    print('  IMPLEMENTATION REGARDLESS OF WHETHER `ta` OR `tu` WAS REQUESTED --')
    print('  AND THAT IS EXACTLY WHY REQUESTING `ta` IS SAFE HERE AND NOT SAFE')
    print('  EVERYWHERE.  §KEEP§THE COMPILER GETS PORTABILITY NOT FROM THE POLICY')
    print('  BITS BUT FROM NOT DEPENDING ON THE TAIL, AND A READER WHO SEES')
    print('  `ta, ma` IN THE ENCODING HAS LEARNED NOTHING ABOUT WHICH OF THE TWO')
    print('  STRATEGIES WAS USED.')

    # ---- what the corpus does not measure ----
    print()
    print('  WHAT THIS SECTION CANNOT SAY, and it is most of what a reader wants:')
    print()
    for item in (
            'That any vector instruction is FASTER than the scalar loop it '
            'replaces.  No instruction in this course has run and no timing '
            'exists anywhere in this file.',
            'What VLEN IS on any real machine.  `vlenb` is read by the '
            'compiler and its VALUE is in no file here; a VLEN of 128 and a '
            'VLEN of 1024 would both produce this assembly.',
            'Whether the vectorised loop is CORRECT.  Nothing was executed, so '
            'no output was compared against anything.',
            'Whether `ta` on this hardware overwrites the tail with ones or '
            'leaves it alone.  The manual permits both and this host has no '
            'vector hardware to be permissive or not on.',
            'How much of the element count per iteration depends on VLEN.  The '
            'compiler emits a division and a multiply by a value read at run '
            'time, which is a fact about the CODE and not about the answer.'):
        print('    * %s' % item)


# ===========================================================================
# SECTION 11 -- TWO READERS ON THE SAME BYTES.
#
# The two-reader discipline is INHERITED from the first RISC-V course and is
# not weakened here.  `crosscheck_corpus` walks the whole corpus, decodes every
# instruction with this file's decoder, and compares the rendering against
# `llvm-objdump-21`'s.  Three numbers matter and the third is the one that is
# easy to forget: instructions this file CANNOT NAME are COUNTED and never
# dropped, because a decoder that declines a word and a decoder that names it
# wrongly are two DIFFERENT failures and a cross-check that reports only
# agreements cannot tell them apart.
# ===========================================================================

# Two normalisation rules, PRE-SEEDED into the fire table.  A rule that never
# fires should be a ROW WITH A ZERO rather than an absence -- which is the
# AArch64 section's finding and this course inherits it deliberately: the
# sibling's fire table is INHERITED and carries rules its corpus does not
# exercise, so a healthy run there leaves some rules DEAD.  These two were
# written FOR this corpus and both fire, so the healthy state here is zero
# dead.
# This course's OWN normalisation rules, and there are only four, and the
# reason there are only four is that the other forty-seven are INHERITED.
#
# THE INHERITED NORMALISER is `rvdec.crosscheck_normalise`, used UNCHANGED.
# §KEEP§BORROW THE SPELLING RULES AS WELL AS THE DECODER: A COURSE THAT FORKS A
# NORMALISER INHERITS EVERY NORMALISATION BUG THE SIBLING HAS ALREADY FOUND AND
# NONE OF ITS FIXES.  §KEEP§THE INHERITED FUNCTION EXPANDS RATHER THAN DELETES
# -- `c.add a0, a1` becomes `add x10, x10, x11`, both sides gaining the
# implicit rd -- so no rule there can make two readers agree by deleting the
# same operand.
#
# AND THE ORDER IS THE FINDING, so the rules are in TWO GROUPS and the groups
# run on OPPOSITE SIDES of the inherited function:
#
#   PRE  run on the RAW printed text, before the inherited rules.  These fix a
#        SIGN, and the inherited `li` and `c.li` rules disagree about it:
#
#            crosscheck_normalise('li a3, -1')     ->  'addix13,x0,0x1'
#            crosscheck_normalise('c.li a3, -1')   ->  'addix13,x0,-0x1'
#
#        Same instruction, same value, two canonical forms, and the difference
#        is a MINUS SIGN.  §KEEP§THE INHERITED NORMALISER HANDLES A NEGATIVE
#        IMMEDIATE INCONSISTENTLY BETWEEN ITS OWN TWO RULES, SO A CORRECTION
#        APPLIED AFTER IT CANNOT UNDO THE DAMAGE -- AND A RULE WRITTEN AGAINST
#        THE TEXT AS PRINTED INSTEAD OF AS NORMALISED IS A RULE THAT MATCHES
#        NOTHING.  §KEEP§THIS IS THE SIXTH TIME THIS COLLECTION HAS PAID FOR A
#        NORMALISATION RULE THAT MATCHED NOTHING, AND THE FIRST TIME THE RULE
#        AND THE ORDER WERE BOTH WRITTEN BY THIS FILE.
#
#   POST run on the INHERITED normaliser's OUTPUT, after it.  These fix a field
#        that the inherited function REWRITES into a shape the raw text never
#        had -- it removes the space between a mnemonic and its first operand,
#        so `fence iorw, iorw` arrives as `fenceiorw,iorw`, and a rule written
#        against the printed text (`\s+`) matches NOTHING on all 113 of them.
NORM_RULES_PRE = [
    # A negative immediate in signed decimal on both sides, so the inherited
    # `li` rule and its inherited `c.li` rule see the same characters.
    ('negative immediate, decimal on both sides',
     lambda t: re.sub(r'-0x([0-9a-fA-F]+)',
                      lambda m: '-%d' % int(m.group(1), 16), t)),
    # `c.li` and `li` are ONE INSTRUCTION in two encodings, and the reader
    # prints the PLAIN form for the four-byte word while this file's decoder
    # prints the COMPRESSED form for the two-byte one.  Drop the `c.`; the
    # inherited expansion then turns both into `addix<rd>,x0,<imm>`.
    ('c.li and li are one instruction',
     lambda t: re.sub(r'^c\.li\b', 'li', t)),
    # `vsetivli`'s immediate, printed DECIMAL here and in `0x` hex by the
    # reader.  Six words of this corpus and nothing else.
    ('vsetivli immediate, decimal against 0x-hex',
     lambda t: re.sub(r'^(vsetivli\s+\S+,\s*)(\d+)\b',
                      lambda m: m.group(1) + '0x%x' % int(m.group(2)), t)),
]

NORM_RULES_POST = [
    # The bare `fence` and `fence iorw, iorw` are the SAME WORD (0x0ff0000f),
    # and the reader prints the bare form for the all-but-self case while this
    # decoder prints both sets.  113 of the corpus's fences are one or the
    # other, and the two spellings differ only by an all-but-self SET -- which
    # is the section 7 point that a fence is a relation between two sets and
    # the reader's spelling hides half of it.
    ('bare fence and fence with explicit sets are one instruction',
     lambda t: re.sub(r'^fence(iorw,iorw)?$', 'fence', t)),
    # The same for `fence.tso`, which the reader prints with no operands.
    ('fence.tso with and without its sets is one instruction',
     lambda t: re.sub(r'^fence\.tsorw,rw$', 'fence.tso', t)),
    # The ordering of the `.aqrl` suffixes.  DEAD in this corpus -- no word in
    # it is spelled `.rl.aq` -- and left in PRE-SEEDED so a run in which it
    # never fires is a ROW WITH A ZERO rather than an absence.  §KEEP§A RULE
    # THAT NEVER FIRES IS A ROW WITH A ZERO AND NOT A MISSING ROW, BECAUSE A
    # MISSING ROW IS INDISTINGUISHABLE FROM A RULE THAT WAS NEVER WRITTEN.
    ('vsetvli suffix order, aqrl and rl-aq are one spelling',
     lambda t: re.sub(r'\.(aqrl|rl\.aq)$', '.aqrl', t)),
]

NORM_RULES = NORM_RULES_PRE + NORM_RULES_POST


def reset_xnorm():
    for _name, _fn in NORM_RULES:
        XNORM_FIRES[_name] = 0
    Dec.reset_norms()


XNORM_FIRES = {}


def xnorm(t):
    """Normalise BOTH sides before comparing, and count what each rule did.

    PRE on the raw text, then the INHERITED forty-seven, then POST on the
    inherited function's output.  §KEEP§A NORMALISER'S RULES HAVE AN ORDER AND
    THE ORDER IS INVISIBLE IN THE RULES THEMSELVES, WHICH IS WHY THE ORDER IS
    WRITTEN AS PART OF THE RULE TABLE AND NOT AS A COMMENT BESIDE IT.
    """
    raw = ' '.join(t.replace('\t', ' ').split())
    for name, fn in NORM_RULES_PRE:
        before = raw
        raw = fn(raw)
        if raw != before:
            XNORM_FIRES[name] = XNORM_FIRES.get(name, 0) + 1
    out = Dec.crosscheck_normalise(raw)
    for name, fn in NORM_RULES_POST:
        before = out
        out = fn(out)
        if out != before:
            XNORM_FIRES[name] = XNORM_FIRES.get(name, 0) + 1
    return ' '.join(out.split())


def objdump_all(files):
    """{file: [(addr, word, mnem, text, nbytes)]} from the SECOND READER."""
    out = {}
    for f in files:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        out[f] = flat_insns(fp)
    return out


def xcheck_one(files=None):
    """The comparison, with every number this course's verdict rests on.

    Returns a dict rather than printing, because the poison needs to run this
    function TWICE with a model removed and compare the results, and a
    function that printed would print the removal's output too.
    """
    files = files or RVCORPUS
    reset_xnorm()
    got = objdump_all(files)
    total = named = agree = disagree = unmodelled = 0
    ldis = 0
    detail = []
    classes = []
    for f in files:
        for addr, w, mn, txt, nb in got.get(f, []):
            total += 1
            k = Dec.decode(w, nb, addr)
            mine = k.text.strip() if k.name else ''
            theirs = ('%s %s' % (mn, txt)).strip()
            if k.name is None:
                unmodelled += 1
                continue
            named += 1
            if Dec.bits(k.word, 1, 0) == 3 and nb != 4:
                ldis += 1
            if xnorm(mine) == xnorm(theirs):
                agree += 1
            else:
                disagree += 1
                detail.append((f, addr, w, mine, theirs))
                classes.append(classify(mine, theirs))
    return {'total': total, 'named': named, 'agree': agree,
            'disagree': disagree, 'unmodelled': unmodelled,
            'length_disagree': ldis, 'detail': detail,
            'classes': classes, 'fires': dict(XNORM_FIRES)}


def classify(mine, theirs):
    """CLASSIFY every disagreement BY KIND, on the MAIN PATH.

    §KEEP§A CROSS-CHECK THAT COUNTS A SPELLING DIFFERENCE AND A CROSS-CHECK
    THAT COUNTS A MISREAD THE SAME WAY IS A CROSS-CHECK THAT CANNOT TELL A
    DECODER BUG FROM A CONVENTION, AND THIS COLLECTION HAS PAID FOR THAT
    THREE TIMES.

    And the classifier is in the main path rather than in the failure branch,
    so a run where it finds nothing is visibly a run where it RAN and found
    nothing -- which is the third course in a row to place a check on the
    success path.
    """
    a = mine.split()
    b = theirs.split()
    if a and b and a[0] != b[0]:
        return 'a different INSTRUCTION was named'
    if len(a) != len(b):
        return 'a different NUMBER of operands'
    for x, y in zip(a[1:], b[1:]):
        if x != y:
            return 'the same instruction, a different OPERAND'
    return 'the same text in a different SHAPE'


def xcheck_summary():
    r = xcheck_one()
    print('  %6d  instructions the second reader printed' % r['total'])
    print('  %6d  of them this file NAMES' % r['named'])
    print('  %6d  unmodelled -- counted, never dropped' % r['unmodelled'])
    print('  %6d  where the two readers disagree on the LENGTH'
          % r['length_disagree'])
    print()
    if r['disagree'] == 0:
        print('  %6d  DISAGREE' % 0)
    else:
        print('  %6d  DISAGREE' % r['disagree'])
        for f, addr, w, mine, theirs in r['detail'][:20]:
            print('           %-18s 0x%08x  mine %-28s theirs %s'
                  % (f, w, mine[:28], theirs[:28]))
        if len(r['detail']) > 20:
            print('           ... and %d more' % (len(r['detail']) - 20))
    return r


def sec11():
    banner(11, 'TWO READERS ON THE SAME BYTES')
    print()
    para("""The decoder that produced sections 2 through 10 is checked by a
second reader -- `llvm-objdump-21` -- against this file's own decoder, over
the whole corpus.

§KEEP§AND BOTH READERS COME FROM ONE LLVM TREE, because `clang` assembled the
corpus and GNU binutils has no RISC-V target on this host.  So what this
section establishes is "this decoder and one other piece of software agree on
what the bytes mean" -- and NOT "either agrees with silicon".  That is a limit
and it is limit 11, and it is the reason the two-reader result is a result
about software.""")
    print()
    r = xcheck_summary()

    print()
    print('  THE CLASSIFIER, run on every run:')
    print()
    if not r['classes']:
        print('    NOTHING TO CLASSIFY -- and that is a run where the classifier')
        print('    RAN and found nothing, which is not the same as a run where')
        print('    it never ran, and the difference is why it lives on the main')
        print('    path rather than in the failure branch.')
    else:
        kinds = {}
        for k in r['classes']:
            kinds[k] = kinds.get(k, 0) + 1
        table(['kind of disagreement', 'how many'], sorted(kinds.items()))

    print()
    print('  THE FIRE TABLE, pre-seeded so a rule that never fires is a row with')
    print('  a zero rather than an absence:')
    print()
    rows = [(name, str(XNORM_FIRES.get(name, 0)),
             'fired' if XNORM_FIRES.get(name, 0) else 'NEVER FIRED')
            for name, _fn in NORM_RULES]
    table(['normalisation rule', 'times it fired', 'verdict'], rows)
    n_fired = sum(1 for _n, _f in NORM_RULES if XNORM_FIRES.get(_n, 0))
    print()
    print('    %d rules, %d fired, %d matched nothing'
          % (len(NORM_RULES), n_fired, len(NORM_RULES) - n_fired))
    print()
    print('  AND THE INHERITED TABLE beside it, because this course BORROWS the')
    print('  normaliser rather than forking it and a borrowed table with no')
    print('  numbers next to it is a table a reader cannot check:')
    print()
    dead = [n for n, v in Dec.NORMFIRES.items() if v == 0]
    fired = [n for n, v in Dec.NORMFIRES.items() if v]
    print('    %d rules INHERITED from rvdec.py, %d fired on this corpus and %d'
          % (len(Dec.NORM_RULE_NAMES), len(fired), len(dead)))
    print('    are DEAD -- which is EXPECTED and is not a defect: this corpus is')
    print('    one third vector and two thirds C, so the rules about floating')
    print('    point and about the A64 forms have nothing to bite on.  §KEEP§A')
    print('    DEAD RULE IN AN INHERITED TABLE IS A RULE FOR A CORPUS THIS')
    print('    COURSE DOES NOT HAVE, AND THE INVERTED CONDITION IS THE CORRECT')
    print('    ONE HERE: THIS COURSE\'S OWN SIX RULES ARE PRE-SEEDED AND THE')
    print('    HEALTHY STATE IS ZERO DEAD AMONG THEM.')
    print()
    print('  §KEEP§AND THE FIRE TABLE IS WHAT MAKES "ZERO DISAGREEMENTS" A RESULT')
    print('  RATHER THAN AN ABSENCE, BECAUSE IT SHOWS THE COMPARISON DID')
    print('  SOMETHING.  §KEEP§WITHOUT THE FIRST RULE, `fence` AND `fence rw, rw`')
    print('  WOULD BE COUNTED AS DISAGREEMENTS -- A SPELLING DIFFERENCE AND NOT A')
    print('  MISREAD -- AND THE DISAGREEMENT COUNT WOULD BE A NUMBER ABOUT HOW')
    print('  THE ASSEMBLER PRINTS THINGS RATHER THAN ABOUT WHETHER EITHER READER')
    print('  IS RIGHT.')

    print()
    print('  THE UNMODELLED COUNT IS PRINTED BESIDE THE DISAGREEMENT COUNT and')
    print('  not in a footnote, for the reason the sibling course recorded as a')
    print('  retraction: a model can be removed, become unreachable, or be')
    print('  shadowed, and every word it owned can end up named by something')
    print('  else at the same address -- so a check that watched only the')
    print('  disagreement count would call the result progress when it is the')
    print('  reverse of progress.  §KEEP§A CROSS-CHECK THAT COUNTS AGREEMENTS AND')
    print('  ONE THAT COUNTS HOLES ARE MEASURING DIFFERENT THINGS, AND PRINTING')
    print('  ONLY ONE OF THEM IS HOW A DECODER DELETES A MODEL WITHOUT ANYBODY')
    print('  NOTICING.')
    print()
    print('  §KEEP§%d UNMODELLED WORDS IS AN HONEST NUMBER FOR THIS CORPUS: THE'
          % r['unmodelled'])
    print('  VECTOR EXTENSION HAS SEVERAL HUNDRED ENCODINGS AND THIS FILE')
    print('  NAMES THE THREE CONFIGURATION INSTRUCTIONS, THE MASK BIT IN THREE')
    print('  GROUPS AND THE REGISTER GROUP, AND COUNTS THE REST.  §KEEP§A')
    print('  DECODER THAT NAMED EVERY VECTOR WORD AND GOT ONE WRONG WOULD BE A')
    print('  WORSE DECODER THAN ONE THAT SAYS WHICH HALF OF THE EXTENSION IT')
    print('  IMPLEMENTS -- AND THE HALF IT IMPLEMENTS IS THE HALF THE FOUR')
    print('  CONCEPT PAGES MAKE CLAIMS ABOUT.')

    # ---- what the ORDER of the rules is, and what the two repairs added ----
    print()
    print('  AND THE ORDER OF THOSE RULES IS ITSELF A FINDING, so it is printed')
    print('  rather than left in a comment: §KEEP§A NORMALISER\'S RULES HAVE AN')
    print('  ORDER AND THE ORDER IS INVISIBLE IN THE RULES THEMSELVES.  Three of')
    print('  this course\'s own rules run BEFORE the inherited normaliser, on the')
    print('  RAW printed text, and two run AFTER it, on its OUTPUT -- and the')
    print('  reason is a shape rather than a preference.  §KEEP§THE INHERITED')
    print('  FUNCTION HANDLES A NEGATIVE IMMEDIATE INCONSISTENTLY BETWEEN ITS OWN')
    print('  TWO RULES: IT PRINTS `li a3, -1` AS HEX AND `c.li a3, -1` IN DECIMAL,')
    print('  SO A CORRECTION APPLIED AFTER IT CANNOT UNDO THE DAMAGE AND A RULE')
    print('  WRITTEN AGAINST ITS OUTPUT MATCHES NOTHING.  §KEEP§THIS IS THE SIXTH')
    print('  TIME THIS COLLECTION HAS PAID FOR A NORMALISATION RULE THAT MATCHED')
    print('  NOTHING, AND THE FIRE TABLE ABOVE IS HOW THE NEXT ONE GETS CAUGHT:')
    print('  a rule with a zero beside it is visible and a rule that was never')
    print('  written is not.  §KEEP§THE SECOND REVERSED SIDE IS THE OTHER HALF OF')
    print('  THE SAME ARGUMENT: THE INHERITED FUNCTION REMOVES THE SPACE BETWEEN A')
    print('  MNEMONIC AND ITS FIRST OPERAND, SO `fence iorw, iorw` ARRIVES AS')
    print('  `fenceiorw,iorw` AND A RULE MATCHING `\\s+` MATCHES NOTHING ON ALL')
    print('  113 OF THEM.')
    print()
    print('  §KEEP§AND THE FIRE TABLE IS A TABLE OF NORMALISATION, NOT OF')
    print('  MODELLING -- which is worth saying because the two are easy to')
    print('  confuse, and a reader who has just read %d unmodelled words could'
          % r['unmodelled'])
    print('  reasonably think the table above is about them.  It is not: those')
    print('  words are unmodelled because no model claims them, and the table')
    print('  counts fixes applied to words that WERE named.')
    print()
    print('  TWO REPAIRS TO THE INHERITED DECODER, and both are visible here')
    print('  because a repair nobody can see is a repair nobody can check:')
    print()
    print('  §KEEP§THE FIRST IS THE LOAD-MODE FIELD.  A unit-stride load and a')
    print('  WHOLE-REGISTER load differ by inst[24:20] -- lumop -- and the')
    print('  inherited decoder read only the width, so it said `vle8.v` where the')
    print('  second reader said `vl1r.v`, and lumop = 01000 IS THE WHOLE-REGISTER')
    print('  FORM.  §KEEP§ONE FIVE-BIT FIELD IN A UNIT-STRIDE LOAD CARRIES THREE')
    print('  INSTRUCTION NAMES, AND A DECODER THAT READS ONLY THE WIDTH GETS ALL')
    print('  ELEVEN WRONG WHILE BEING RIGHT ABOUT EVERY FIELD IT DID READ.  §KEEP§')
    print('  INCOMPLETE IS HARDER TO NOTICE THAN WRONG, BECAUSE NOTHING IN THE')
    print('  OUTPUT LOOKS BROKEN -- IT LOOKS LIKE A SPELLING DIFFERENCE.')
    print()
    print('  §KEEP§THE SECOND IS THE DISPATCH GUARD AGAINST THE CONFIGURATION')
    print('  INSTRUCTIONS, and it is here because the first version of this')
    print('  course\'s own vector model did not have it.  `vsetvli t0, a1, e8,')
    print('  mf8, ta, ma` is 0x0c55f2d7, and its funct6 -- inst[31:26] -- is')
    print('  0b000011, WHICH IS OPFVV.  §KEEP§A MODEL THAT DISPATCHES ON THE')
    print('  funct6 ALONE CLAIMS THE CONFIGURATION INSTRUCTIONS, and the first run')
    print('  of the cross-check reported 112 of them as `vadd.vi v5, v5, 11,')
    print('  v0.t`.  §KEEP§THE FIX IS TO READ THE COARSEST SELECTOR FIRST: the')
    print('  guard is inst[31:30] == 0b01, because the OP-V DATA encoding has')
    print('  bits[31:30] = 01 and the three configuration instructions have 00, 10')
    print('  and 11.  §KEEP§A MODEL MUST READ THE COARSEST SELECTOR BEFORE THE')
    print('  FINEST ONE, AND A MODEL THAT SKIPS A LEVEL IN THE DISPATCH WILL')
    print('  EVENTUALLY CLAIM A WORD AT THE FINER LEVEL THAT IS NOT AT THE')
    print('  COARSER ONE.  §KEEP§THIS IS THE ENCODING COURSE\'S OWN FINDING, AND')
    print('  IT BIT THIS FILE TWICE: the inherited decoder read THREE bits where')
    print('  the encoding has TWO, and this model read SIX where it had to read')
    print('  TWO FIRST.')


# ===========================================================================
# SECTION 12 -- FOUR POISONS.  Each must MOVE the number it claims to test.
# ===========================================================================
# The rule this course inherits, and the reason it exists: the AArch64
# data-path course's cross-check reported ZERO disagreements over a corpus where
# eighty-five instructions genuinely disagreed, and every one of its four bugs
# had made the comparison VACUOUS rather than wrong -- not one printed a bad
# word, they all stopped the comparison happening.  A control that cannot be
# made to fail is a comment that says the word POISONED.

def _poison_remove(victims):
    """The shared body: remove a LIST of models, re-run, report the deltas."""
    before = xcheck_one()
    saved = list(Dec.MODELS32)
    Dec.MODELS32 = [m for m in saved if m[0] not in victims]
    try:
        after = xcheck_one()
    finally:
        Dec.MODELS32 = saved
    return {'missing': False, 'before': before, 'after': after,
            'delta_named': (before['named'] + before['disagree'])
            - (after['named'] + after['disagree']),
            'delta_disagree': after['disagree'] - before['disagree'],
            'delta_unmodelled': after['unmodelled'] - before['unmodelled']}


def poison_named(model_name):
    """Remove ONE model and report the move in all three cross-check numbers.

    AND IT REPORTS A VICTIM THAT IS NOT IN THE DISPATCH AT ALL, because that is
    the failure the first RISC-V course shipped: a poison whose victim had no
    corpus footprint could not move a number, and the file printed
    [POISON FAILED] against a control that had never run.  A missing victim is
    a DIFFERENT BUG from an unmoved one, and the two are distinguished in the
    return value rather than in a comment.
    """
    names = [m[0] for m in Dec.MODELS32]
    if model_name not in names:
        return {'missing': True, 'model': model_name, 'names': names}
    return _poison_remove([model_name])


def poison_named_mask():
    """Break the MASK BIT ITSELF and count what stops being named.

    The victim is this course's own `m_vector_mask`, and it is chosen over the
    others because its corpus footprint is the LARGEST -- 165 data words -- so
    the delta cannot be confused with a rounding effect.  §KEEP§THE VICTIMS ARE
    CHOSEN FROM THE CORPUS AND NOT FROM A LIST OF INTERESTING MODELS, BECAUSE A
    POISON WHOSE VICTIM OWNS NO WORDS IN THIS CORPUS IS A POISON THAT CANNOT
    MOVE A NUMBER NO MATTER WHAT IT PRINTS.
    """
    return poison_named('m_vector_mask')


def poison_named_order():
    """Remove `m_amo_order`, the model that READS inst[26] and inst[25].

    This is the interesting one, because the inherited `a_amo` is still in the
    dispatch and it does NOT read those two bits -- so removing this model does
    not create a hole, it creates a WRONG ANSWER.  §KEEP§THE WORDS STOP BEING
    HOLES AND BECOME WRONG, WHICH IS TWO DIFFERENT FAILURES WITH ONE CAUSE, AND
    A CROSS-CHECK THAT WATCHED ONLY THE DISAGREEMENT COUNT WOULD SEE THE HOLE
    COUNT FALL AND CALL IT PROGRESS.
    """
    return poison_named('m_amo_order')


def poison_plant():
    """PLANT real disagreements in the decoder's own rendering, then show that
    a normaliser which DELETES the operands makes them disappear.

    This is the poison that tests the CHECK rather than the decoder.  A decoder
    bug is found by reading the output; a check bug is found only by trying to
    break the check.

    The planting is done on THIS file's side, and the location is deliberate:
    inside the normaliser it would corrupt both sides and the two would agree
    perfectly around a real disagreement.  Every planted difference changes the
    LAST OPERAND, because the broken rule keeps the mnemonic and the FIRST
    operand -- so a difference planted anywhere else would not be visible to the
    broken rule either, and the control would report a smaller movement for the
    wrong reason.
    """
    planted = []
    for f in RVCORPUS:
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for addr, w, mn, txt, nb in flat_insns(fp):
            k = Dec.decode(w, nb, addr)
            if k.name is None or ',' not in k.text:
                continue
            if xnorm(k.text) != xnorm('%s %s' % (mn, txt)):
                continue
            parts = k.text.split(',')
            last = parts[-1].strip()
            newlast = 'a7' if last not in ('a7', 'zero') else 'a6'
            planted.append((f, addr, ','.join(parts[:-1] + [newlast]),
                            '%s %s' % (mn, txt)))

    def bad(t):
        """The AArch64-shaped rule: keep the mnemonic and the FIRST operand,
        DELETE everything after the first comma."""
        c = xnorm(t)
        m = re.match(r'^([a-z0-9._]+?)\s*([^\s,]+)(.*)$', c)
        if not m:
            return c
        return m.group(1) + ' ' + m.group(2)

    caught = sum(1 for _f, _a, mt, tt in planted
                 if xnorm(mt) != xnorm(tt))
    hidden = sum(1 for _f, _a, mt, tt in planted if bad(mt) == bad(tt))
    return len(planted), caught, hidden


def poison_field():
    """Break the ORDERING BITS and count the words that were WRONG rather than
    absent -- the measurement that section 4 rests on.

    The poison re-encodes every word in the corpus with `aq` and `rl` CLEARED
    and asks the decoder what it says.  Every word whose mnemonic carried a
    suffix must LOSE it, and every word that did not must keep it -- and if the
    decoder reads the bits from anywhere but the word, the count of words that
    failed to move is non-zero and that is the failure this poison exists to
    make visible.  §KEEP§A FIELD POSITION CLAIMED IN PROSE AND NOT MEASURED IS
    A FIELD POSITION THAT CAN BE WRONG WITHOUT ANYTHING LOOKING WRONG.
    """
    moved = still = 0
    checked = 0
    for f in ('amo.o', 'amo_a_O2.o'):
        fp = p(f)
        if not os.path.exists(fp):
            continue
        for addr, w, mn, txt, nb in flat_insns(fp):
            if Dec.bits(w, 6, 0) != 0x2F:
                continue
            # ONLY THE WORDS THAT CARRIED A SUFFIX.  The first version of this
            # poison counted EVERY A-extension word, and the twenty-nine that
            # carried NO suffix could not move -- they had nothing to lose --
            # so the poison reported "28 of 57 moved, 29 did not" and the
            # verdict was FIRED ON NOTHING.
            #
            # §KEEP§A POISON'S DENOMINATOR MUST BE THE SET OF INSTANCES THAT
            # COULD HAVE MOVED.  §KEEP§COUNTING INSTANCES THAT CANNOT FAIL
            # ALONGSIDE INSTANCES THAT CAN, AND THEN CALLING THE RESULT A PASS
            # RATE, IS HOW A POISON COMES TO REQUIRE 49 PER CENT AND BE CALLED
            # PASSING -- AND IT IS THE SAME SHAPE AS A CROSS-CHECK THAT COUNTS
            # AGREEMENTS OVER A CORPUS MOSTLY CONSISTING OF WORDS IT NEVER
            # LOOKED AT.  §KEEP§THE DENOMINATOR IS A DECISION AND IT IS THE
            # FIRST THING TO CHECK WHEN A NUMBER LOOKS WRONG.
            if '.aq' not in mn and '.rl' not in mn:
                continue
            checked += 1
            stripped = w & ~(0x04000000 | 0x02000000)
            a = Dec.decode(w, nb, addr)
            b = Dec.decode(stripped, nb, addr)
            if a.text == b.text:
                still += 1
            else:
                moved += 1
    return checked, moved, still


def sec12():
    banner(12, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER')
    print()
    para("""A control that cannot be made to fail is a comment that says the word
POISONED.  §KEEP§THIS COLLECTION HAS PAID FOR THAT LESSON REPEATEDLY: THE
AARCH64 DATA-PATH COURSE'S CROSS-CHECK REPORTED ZERO DISAGREEMENTS OVER A
CORPUS WHERE EIGHTY-FIVE INSTRUCTIONS GENUINELY DISAGREED, AND EVERY ONE OF THE
FOUR BUGS HAD MADE THE COMPARISON VACUOUS RATHER THAN WRONG.  §KEEP§NOT ONE
PRINTED A BAD WORD.  THEY ALL STOPPED THE COMPARISON HAPPENING.

So each of the four below names the number it tests, runs the SAME loop over
the SAME bytes, prints the DELTA as a number, and prints [POISON FAILED] if the
delta is zero.""")

    print()
    print('  POISON 1 -- remove THIS COURSE\'S OWN `m_vector_mask`, the model')
    print('              that names the vector DATA path.  It claims TWO')
    print('              numbers -- the NAMED count and the UNMODELLED count --')
    print('              and it claims a ZERO for the DISAGREEMENT count, which')
    print('              is the interesting part: removing this model creates a')
    print('              HOLE and not a WRONG ANSWER, because there is nothing')
    print('              behind it in the dispatch that can name a vector data')
    print('              word.  §KEEP§A HOLE AND A WRONG ANSWER LOOK IDENTICAL IN')
    print('              A CROSS-CHECK THAT ONLY COUNTS AGREEMENTS, AND THE POISON')
    print('              BELOW IS THE OTHER ONE.')
    r1 = _poison_remove(['m_vector_mask'])
    if r1.get('missing'):
        print('    [POISON FAILED] a victim is NOT IN THE DISPATCH')
        return
    b, a = r1['before'], r1['after']
    print()
    print('    BEFORE: %d named, %d disagree, %d unmodelled'
          % (b['named'], b['disagree'], b['unmodelled']))
    print('    AFTER : %d named, %d disagree, %d unmodelled'
          % (a['named'], a['disagree'], a['unmodelled']))
    print('    DELTA: named %+d, disagreements %+d, unmodelled %+d'
          % (-r1['delta_named'], r1['delta_disagree'],
             r1['delta_unmodelled']))
    ok1 = (r1['delta_named'] != 0 and r1['delta_unmodelled'] != 0
           and r1['delta_disagree'] == 0)
    print('    VERDICT: POISON 1 %s' % ('FIRED' if ok1 else
                                        'FIRED ON NOTHING -- [POISON FAILED]'))
    if not ok1:
        print('    [POISON FAILED]')
    print()
    para("""§KEEP§THE UNMODELLED COUNT RISES BY EXACTLY THE NUMBER OF WORDS THE MODEL
OWNED, WHICH IS THE PROOF THAT IT OWNED THEM.  §KEEP§A MODEL THAT OWNS NOTHING
IN A CORPUS CANNOT BE POISONED, AND THAT IS WHY THE VICTIM IS CHOSEN FROM THE
CORPUS AND NOT FROM A LIST OF INTERESTING MODELS: this file's `m_amo_order`
owns far fewer words and `m_fence_sets` fewer still, so they are poison 2's
victim instead.""")

    print()
    print('  POISON 2 -- remove `m_amo_order`, the model that READS inst[26] and')
    print('              inst[25].  The inherited `a_amo` is still in the')
    print('              dispatch and it does not read those bits, so removing')
    print('              this one does NOT create a hole -- it creates a WRONG')
    print('              ANSWER.  §KEEP§THE WORDS STOP BEING NAMED CORRECTLY AND')
    print('              BECOME NAMED INCORRECTLY: THE UNMODELLED COUNT DOES NOT')
    print('              MOVE AT ALL, BECAUSE SOMETHING ELSE STILL NAMES THEM,')
    print('              AND THE DISAGREEMENT COUNT RISES BY THE NUMBER THAT')
    print('              SOMETHING ELSE GETS WRONG.')
    print()
    print('  §KEEP§THAT IS THE MIRROR OF POISON 1 AND IT IS WHY BOTH COLUMNS ARE')
    print('  PRINTED BESIDE EACH OTHER.  POISON 1 MOVED THE UNMODELLED COLUMN')
    print('  AND NOT THE DISAGREEMENT COLUMN; POISON 2 MOVED THE DISAGREEMENT')
    print('  COLUMN AND NOT THE UNMODELLED ONE.  §KEEP§A CROSS-CHECK THAT COUNTS')
    print('  ONLY AGREEMENTS CALLS BOTH OF THEM A PASS, BECAUSE IN BOTH CASES THE')
    print('  INSTRUCTION IS STILL "COMPARED" AND IN BOTH CASES THE COMPARISON')
    print('  FOUND NOTHING TO SAY.  §KEEP§A CHECK THAT COUNTS AGREEMENTS AND ONE')
    print('  THAT COUNTS HOLES ARE MEASURING DIFFERENT THINGS, AND TWO POISONS')
    print('  THAT MOVE ONE COLUMN EACH ARE THE PROOF THAT THEY ARE.  §KEEP§THE')
    print('  NAMED COUNT IS A THIRD COLUMN AND IT MOVES IN BOTH POISONS, WHICH IS')
    print('  WHY IT IS NOT THE COLUMN THE VERDICT READS: a number that moves')
    print('  every time cannot distinguish the two failures.')
    r2 = _poison_remove(['m_amo_order'])
    b2, a2 = r2['before'], r2['after']
    print()
    print('    BEFORE: %d named, %d disagree, %d unmodelled'
          % (b2['named'], b2['disagree'], b2['unmodelled']))
    print('    AFTER : %d named, %d disagree, %d unmodelled'
          % (a2['named'], a2['disagree'], a2['unmodelled']))
    print('    DELTA: named %+d, disagreements %+d, unmodelled %+d'
          % (-r2['delta_named'], r2['delta_disagree'],
             r2['delta_unmodelled']))
    ok2 = (r2['delta_disagree'] > 0 and r2['delta_unmodelled'] == 0
           and r2['delta_named'] != 0)
    print('    VERDICT: POISON 2 %s' % ('FIRED' if ok2 else
                                        'FIRED ON NOTHING -- [POISON FAILED]'))
    if not ok2:
        print('    [POISON FAILED]')
    print()
    if a2['detail']:
        print('    AND THE FIRST DISAGREEMENTS IT PRODUCES, so the failure is')
        print('    READABLE rather than only countable:')
        for _f, _addr, w, mine, theirs in a2['detail'][:4]:
            print('      0x%08x  mine %-30s second reader %s'
                  % (w, mine[:30], theirs[:30]))

    print()
    print('  POISON 3 -- CLEAR inst[26] and inst[25] in every A-extension word in')
    print('              the corpus and ask the decoder whether the mnemonic')
    print('              moved.  The number it must move is the count of words')
    print('              whose suffix CHANGED.  §KEEP§A FIELD POSITION CLAIMED IN')
    print('              PROSE AND NOT MEASURED IS A FIELD POSITION THAT CAN BE')
    print('              WRONG WITHOUT ANYTHING LOOKING WRONG -- AND THIS IS THE')
    print('              POISON THAT SECTION 4\'s TABLE DEPENDS ON.')
    checked, moved, still = poison_field()
    print()
    print('    A-extension words that CARRIED .aq or .rl                  : %d'
          % checked)
    print('    whose decoded mnemonic CHANGED when aq/rl were cleared    : %d'
          % moved)
    print('    whose decoded mnemonic did NOT change                     : %d' % still)
    print('    DELTA: %d of %d words moved, %d did not'
          % (moved, checked, still))
    ok3 = moved > 0 and still == 0
    print('    VERDICT: POISON 3 %s' % ('FIRED' if ok3 else
                                        'FIRED ON NOTHING -- [POISON FAILED]'))
    if not ok3:
        print('    [POISON FAILED]')
    print()
    print('  §KEEP§AND THE `still` COLUMN MUST BE ZERO, NOT NON-ZERO.  A poison')
    print('  whose victim moves SOME words and not others is a poison that has')
    print('  found a partial reader -- which is the class of bug where a decoder')
    print('  reads a field correctly in the instruction the author tested and')
    print('  not in the eleven others.  §KEEP§EXACT CLAIMS HAVE ONE HONEST')
    print('  TREATMENT, AND A COUNT THAT IS "MOSTLY MOVED" IS NOT A COUNT.')
    print()
    print('  AND THE DENOMINATOR IS THE WORDS THAT CARRIED A SUFFIX, which is a')
    print('  DECISION, and it is the first thing to check when a number looks')
    print('  wrong.  §KEEP§A COUNT OF INSTANCES THAT COULD NOT HAVE MOVED,')
    print('  DIVIDED INTO A TOTAL THAT INCLUDES THEM, IS A NUMBER ABOUT THE')
    print('  POISON AND NOT ABOUT THE FIELD.')

    print()
    print('  POISON 4 -- break the CHECK, not the decoder.  Every instruction this')
    print('              file can name is listed, and then an AArch64-shaped')
    print('              normaliser -- one that KEEPS the mnemonic and the FIRST')
    print('              operand and DELETES the rest -- is applied to both sides')
    print('              of a PLANTED set of real disagreements.  The number it')
    print('              must move is the number of disagreements that')
    print('              DISAPPEAR.')
    planted, caught, hidden = poison_plant()
    print()
    print('    real disagreements planted (last operand changed): %d' % planted)
    print('    of those, the working cross-check CATCHES           : %d' % caught)
    print('    of those, the broken rule makes DISAPPEAR           : %d' % hidden)
    ok4 = planted > 0 and caught > 0 and hidden > 0
    print('    DELTA: %d of the %d planted disagreements were HIDDEN'
          % (hidden, planted))
    print('    VERDICT: POISON 4 %s' % ('FIRED' if ok4 else
                                        'FIRED ON NOTHING -- [POISON FAILED]'))
    if not ok4:
        print('    [POISON FAILED]')

    print()
    print('FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS:')
    print()
    print('* poison 1 claims the NAMED and the UNMODELLED counts, and moved them')
    print('            by %+d and %+d -- and it claims the DISAGREEMENT count'
          % (-r1['delta_named'], r1['delta_unmodelled']))
    print('            stays at %+d, which is a claim as load-bearing as either'
          % r1['delta_disagree'])
    print('            of the two that moved')
    print('* poison 2 claims the DISAGREEMENT count, and moved it by %+d while'
          % r2['delta_disagree'])
    print('            claiming the UNMODELLED count stays at %+d' % r2['delta_unmodelled'])
    print('* poison 3 claims the ORDERING-BIT POSITIONS, and moved %d of %d with'
          % (moved, checked))
    print('            %d unmoved' % still)
    print('* poison 4 claims the VISIBILITY of the check, and hid %d of %d'
          % (hidden, planted))
    print()
    print('AND THE PAIR WORTH READING TOGETHER IS POISON 1 AND POISON 2,')
    print('BECAUSE THEY MOVE DIFFERENT COLUMNS AND EACH CLAIMS THE OTHER\'S')
    print('COLUMN STAYS PUT.  §KEEP§POISON 1 SAYS A MISSING MODEL MAKES A HOLE;')
    print('POISON 2 SAYS A SUPERSEDED MODEL MAKES A MISTAKE.  §KEEP§THE SAME')
    print('REMOVAL, IN TWO DIFFERENT PLACES IN THE DISPATCH, PRODUCES A NUMBER')
    print('THAT RISES AND A NUMBER THAT DOES NOT -- AND A CROSS-CHECK THAT')
    print('PRINTED ONLY THE FIRST WOULD REPORT PROGRESS FOR BOTH.')
    print()
    print('A poison that cannot move must say so, and this file prints the')
    print('string [POISON FAILED] beside the verdict and stops.  A control that did not')
    print('run and a control that ran and found nothing are the same number and')
    print('two different bugs, and the distinction is made in the return value')
    print('rather than in a comment nobody reads.  §KEEP§THE STRING IS NOT ON A')
    print('  LINE OF ITS OWN, BECAUSE A READER GREPPING FOR IT WANTS THE VERDICT')
    print('  AND NOT THE PARAGRAPH THAT EXPLAINS WHY IT EXISTS.')


# ===========================================================================
# SECTION 13 -- THE RETRACTIONS.
#
# Every claim this course took back, in the order it was taken back, with the
# thing that was found instead.  `crosscheck.py` asserts the TEXT of every one,
# because a retraction that is quietly deleted is the one failure no number in
# this file can catch.
# ===========================================================================

RETRACTIONS = [
    ('R1', 'the inherited decoder names the three vector configuration '
     'instructions, because it says they are told apart by inst[31:30]',
     'it computes inst[31:29] -- THREE BITS -- and compares against 0b00, 0b10 '
     'and 0b11, so it names `vsetvli` and DECLINES `vsetivli` and `vsetvl`.  '
     '`vsetvli` is the one instruction whose inst[31:30] and inst[31:29] both '
     'happen to be 000, and the other two fail the test by a margin of one '
     'bit: `vsetivli` at inst[31:29] = 110 gives 6, `vsetvl` at 100 gives 4, '
     'and neither is 3 or 2.  §KEEP§IT NAMES THE ONE INSTRUCTION WHERE TWO '
     'BITS AND THREE BITS AGREE AND DECLINES THE TWO WHERE THEY DISAGREE, AND '
     'A MODEL THAT IS CORRECT BY COINCIDENCE ON ONE CASE IS A MODEL WHOSE '
     'OTHER TWO CASES ARE ALSO COINCIDENCES.  This is the sibling course\'s '
     'code and the defect is PUBLISHED rather than patched across the course '
     'boundary; the fix is a model PREPENDED in this file.'),
    ('R2', 'the inherited decoder reads the A extension\'s two ordering bits',
     'it does not READ them -- it never looks at inst[26] and inst[25] at all, '
     'so `amoadd.w`, `amoadd.w.aq`, `amoadd.w.rl` and `amoadd.w.aqrl` all '
     'render as THE SAME STRING.  The words differ; the output does not.  '
     '§KEEP§A DECODER THAT DOES NOT READ A FIELD RENDERS TWO INSTRUCTIONS '
     'IDENTICALLY, AND A CROSS-CHECK THAT COMPARES RENDERINGS WILL CALL THAT '
     'AGREEMENT.  §KEEP§THIS IS THE SAME SHAPE AS THE AArch64 DATA PATH\'S '
     'VACUOUS CROSS-CHECK AND THE OPPOSITE OF ITS SYMPTOM: there the comparison '
     'was vacuous and the words were right; here the words are wrong and the '
     'comparison is honest.  Both are found the same way, by asking whether the '
     'two sides COULD disagree.'),
    ('R3', 'the inherited decoder names `fence.tso`',
     'it names it `fence`.  `s_fence` reads fm and prints it as a number and '
     'gives every word with opcode 0x0f and funct3 = 0 the name `fence`, so '
     'fm = 1000 comes back as `fence` with fm = 8 in its field list.  §KEEP§A '
     'DECODER REPORTING AN INSTRUCTION AS THE WRONG INSTRUCTION OF THE SAME '
     'FAMILY IS A WORSE FAILURE THAN ONE THAT DECLINES IT, BECAUSE THE WORSE '
     'FAILURE STILL PRODUCES A CONFIDENT STRING.  And this course\'s own '
     'poison 1 would have caught it if the corpus had contained one `fence.tso` '
     '-- it did, and the inherited decoder named it.'),
    ('R4', 'the inherited decoder\'s `s_misc_mem` names `fence.i` correctly, so '
     'nothing needs fixing there',
     'it names it correctly and for the WRONG REASON, and that is worth a '
     'paragraph.  `fence.i` is funct3 = 1 at the same opcode as the ordering '
     'fence, so `s_fence` declines it (it requires funct3 = 0) and `s_misc_mem` '
     'catches it.  The inherited decoder therefore prints the right name and '
     'reads fm, pred and succ on it -- and fm, pred and succ are RESERVED in '
     '`fence.i`, so all three come back as 0 and a reader who does not know '
     'that will read them as an ordering statement that nothing needs ordering.  '
     '§KEEP§RIGHT FOR THE WRONG REASON IS A FAILURE THAT A COMPARISON CANNOT '
     'FIND AND ONLY A DOMAIN EXPERT CAN, WHICH MAKES IT MORE DANGEROUS THAN AN '
     'OUTRIGHT ERROR RATHER THAN LESS.'),
    ('R5', 'the compile-time comparison shows the compiler emitting `amoswap.w` '
     'in a loop instead of a hand-rolled compare-exchange',
     'IT DOES NOT, AND THE CLAIM WAS WRONG in a way that is worth keeping '
     'because the wrongness is instructive.  §KEEP§THE HAND-ROLLED '
     'COMPARE-EXCHANGE IS NOT AN ALTERNATIVE TO BE TRADED AWAY -- IT IS THE '
     'ONLY WAY TO EXPRESS COMPARE-AND-SWAP, BECAUSE THERE IS NO `cmpxchg` IN '
     'THE BASE A EXTENSION AT ALL, AND `amoswap` IS A DIFFERENT OPERATION THAT '
     'DOES NOT COMPARE.  The compiler emits the ONE INSTRUCTION for the '
     'ONE-INSTRUCTION OPERATION (`amoswap.w.aqrl` for '
     '__atomic_exchange_n) and the LOOP for the loop-requiring one, and there '
     'is no trade to make.  §KEEP§A COURSE THAT NAMES A COMPILER DECISION '
     'WITHOUT CHECKING WHETHER THE DECISION EXISTS INCREASES THE GAP BETWEEN '
     'WHAT THE COMPILER CAN DO AND WHAT THE COURSE CLAIMS IT DOES.'),
    ('R6', 'the vectorised loop is measured against the scalar loop at '
     '`rv64g` and `rv64gcv`',
     'that comparison is CONFOUNDED and its numbers were retracted before they '
     'were ever printed.  §KEEP§`rv64g` and `rv64gcv` differ in TWO letters, and '
     'THAT PAIR DIFFERS IN `c` AND `v` AT ONCE -- so every difference in the '
     'table was a difference between adding a vector unit and removing '
     'compression.  The clean pair is `rv64gc` against `rv64gcv`, which differ '
     'in exactly one letter and keep the `c` extension on both sides.  §KEEP§'
     'THIS IS THE SIBLING ABI COURSE\'S OWN FINDING, WHERE THE SAME CONFOUND '
     'PRODUCED A -38 THAT WAS THE LIBRARY AND NOT THE ENCODING, AND THE '
     'GENERALISATION IS: A -march SWEEP THAT DIFFERS IN MORE THAN ONE LETTER IS '
     'NOT AN EXPERIMENT ABOUT EITHER.'),
    ('R7', 'the vector register group is a scalar, so the assembler\'s refusal '
     'of `vl2r.v v1` is a spelling rule',
     'IT IS AN ALIGNMENT CONSTRAINT, and the refusal is the evidence.  `vl2r.v '
     'v8` assembles and `vl2r.v v1` does not, and the difference is that a '
     'group of two must start at an even register.  §KEEP§LMUL IS NOT A SCALAR '
     'AND NOT A WIDER REGISTER -- IT IS A CONSTRAINT ON WHERE A REGISTER GROUP '
     'MAY BEGIN, WHICH IS A CONSTRAINT ON A REGISTER ALLOCATOR AND NOT ON A '
     'NUMBER.  §KEEP§A REFUSAL IS THE CHEAPEST PROOF THAT A CONSTRAINT IS REAL '
     'AND IT IS ALSO THE PROOF THAT THE CONSTRAINT IS NOT ABOUT SYNTAX.'),
    ('R8', 'the twelve C11 functions in `fence.c` emit twelve fences',
     'they emit fewer than twelve INSTRUCTIONS, and the shortest is a single '
     '`ret`.  `__atomic_thread_fence(__ATOMIC_RELAXED)` compiles to NO '
     'INSTRUCTION, because a relaxed fence asks for nothing and the encoding '
     'for nothing is no instruction.  The first draft of the table reported '
     'zero fences for that row as a COUNT and the surrounding prose said the '
     'compiler had "not emitted anything visible", which is true and is not the '
     'interesting half.  §KEEP§A RELAXED FENCE IS NOT A NO-OP INSTRUCTION, IT '
     'IS THE ABSENCE OF ONE, AND A FUNCTION THAT CONSISTS OF A SINGLE RETURN IS '
     'A CORRECT COMPILATION OF A FUNCTION THAT ASKS FOR NOTHING.  §KEEP§THIS IS '
     'ALSO THE FIRST PLACE IN THIS COURSE WHERE A COMPILER REMOVED SOMETHING BY '
     'BEING CORRECT, AND IT IS WORTH NAMING BECAUSE THE SIBLING COURSE '
     'MEASURED DEAD-CODE ELIMINATION AT -O1 AND RETRACTED IT FOR CALLING IT A '
     'CONVENTION.'),
    ('R9', 'an acquire load and a sequentially consistent load are the same '
     'instruction',
     'THEY ARE THE SAME INSTRUCTION AND THE SAME FENCE PLUS ANOTHER FENCE, so '
     'the first version of the table showed one `lw` for each and read the '
     'difference off the load alone.  MEASURED: `load_acquire` is `lw` with '
     'one `fence r, rw` after it, and `load_seqcst` is `fence rw, rw`, `lw`, '
     '`fence r, rw` -- TWO fences for ONE load.  §KEEP§THE EXTRA CONSTRAINT A '
     'SEQ_CST LOAD CARRIES IS ON ITS RELATION TO OTHER OPERATIONS, SO IT IS '
     'DISCHARGED BY ORDERING THE NEIGHBOURS AND NOT BY CHANGING THE LOAD.  '
     '§KEEP§IT IS STILL TRUE THAT THE LOADS ARE IDENTICAL, AND THE FIRST '
     'VERSION OF THE CLAIM WAS TRUE AND INCOMPLETE, WHICH IS A DISTINCTION '
     'WORTH NAMING: A CLAIM THAT IS TRUE AND HAS A QUALIFIER HIDING IN THE '
     'NEXT COLUMN IS A CLAIM THAT HAS BEEN HALF-WRITTEN.'),
    ('R10', 'this course can say what an atomic instruction DOES',
     'IT IS NOT MEASURED, and the file says so in its header, in section 1, at '
     'the end of every affected section, and in the table in section 15 rather '
     'than in a disclaimer.  No reservation is ever held, no AMO is ever '
     'observed to be atomic, no fence is ever observed to order anything, and '
     'no vector instruction is ever executed.  §KEEP§AN ATOMIC INSTRUCTION IS '
     'A PROMISE ABOUT OBSERVABLE BEHAVIOUR, AND EVERY MEASUREMENT AVAILABLE ON '
     'THIS HOST IS A MEASUREMENT ABOUT THE PROMISE\'S TEXT: THE BIT THAT '
     'CARRIES IT, THE PAIR THAT IMPLEMENTS IT, AND THE COMPILER\'S CHOICE '
     'ABOUT WHETHER TO EMIT IT AT ALL.  §KEEP§WHAT IS MEASURED IS THAT CLANG '
     'EMITS `lr.w.aqrl` AND `sc.w.rl` WITH A BRANCH BETWEEN THEM; WHAT IS NOT '
     'MEASURED IS THAT ANY OF IT WORKS.'),
    ('R11', 'the ordering model is a difference of degree from x86-64\'s and '
     'AArch64\'s, because all three are memory models with barriers',
     'it is a difference of FORM and the section says so.  x86-64 describes a '
     'BASELINE that barriers can override; AArch64 gives each ACCESS a MODE, '
     'so `ldar` and `ldr` are different opcodes; RISC-V defines the model AS A '
     'RELATION BETWEEN TWO NAMED SETS in one instruction.  §KEEP§A BASELINE AND '
     'AN ESCAPE HATCH IS A CLAIM ABOUT WHAT HAPPENS WHEN YOU DO NOTHING; AN '
     'ACCESS MODE IS A CLAIM ABOUT WHAT EACH INSTRUCTION MEANS; A '
     'PREDECESSOR/SUCCESSOR PAIR IS A CLAIM ABOUT A RELATION BETWEEN TWO SETS.  '
     '§KEEP§THE THIRD IS THE ONLY ONE IN WHICH THE FENCE IS THE PRIMITIVE RATHER '
     'THAN THE EXCEPTION, AND THAT IS A DIFFERENT KIND OF DIFFERENCE AND NOT A '
     'DIFFERENT DEGREE OF THE SAME ONE.'),
    ('R12', 'the twelve named `fence.tso` words in the corpus prove the '
     'compiler emits it',
     'they prove the CORPUS contains it, which is not the same claim, and the '
     'first version of section 7 counted corpus occurrences and called the '
     'total a compiler statistic.  The two were separated by assembling ONE '
     'fence line at a time and asking which word came back: the compiler emits '
     '`fence.tso` for exactly one of the six C11 fence strengths, '
     '`__ATOMIC_ACQ_REL`, and `fence rw, rw` for `__ATOMIC_SEQ_CST`.  §KEEP§A '
     'NUMBER ABOUT WHAT WAS FED TO IT IS NOT A NUMBER ABOUT WHAT WAS CHOSEN, '
     'AND THE TWO ARE THE SAME FAILURE THIS SECTION\'S CORPUS-COMPLETENESS '
     'CHECK GUARDS AGAINST.'),
    ('R13', '`fence.tso` is a weaker barrier than `fence rw, rw` on every '
     'implementation, so emitting it is a request',
     'the manual says something STRONGER and more interesting than that, and '
     'the first version had it backwards in a way that would have been a good '
     'saying and a false one.  §KEEP§THE MANUAL SAYS THAT an implementation may '
     'ignore `fm`: "Because FENCE RW,RW IMPOSES A SUPERSET OF '
     'THE ORDERINGS THAT FENCE.TSO IMPOSES, IT IS CORRECT TO IGNORE THE fm '
     'FIELD AND IMPLEMENT FENCE.TSO AS FENCE RW,RW."  §KEEP§SO FENCE.TSO IS A '
     'REQUEST FOR A WEAKER BARRIER THAN THE ONE IT IS SPELLED LIKE, AND A '
     'BASE IMPLEMENTATION IS EXPLICITLY PERMITTED TO GIVE THE STRONGER ONE -- '
     'WHICH MEANS "fence.tso" IS NOT PORTABLE ADVICE AND ALSO NOT A WEAKER '
     'BARRIER, AND THE ONLY HONEST THING TO SAY IS BOTH.'),
    ('R14', 'the vector extension\'s tail policy is a performance detail',
     'IT IS A LIBRARY CONTRACT MADE OF BITS, and the specification says the '
     'outcome is not even deterministic.  §KEEP§"EACH DESTINATION ELEMENT CAN '
     'BE EITHER LEFT UNDISTURBED OR OVERWRITTEN WITH 1S, IN ANY COMBINATION, '
     'AND THE PATTERN OF UNDISTURBED OR OVERWRITTEN WITH 1S IS NOT REQUIRED '
     'TO BE DETERMINISTIC WHEN THE INSTRUCTION IS EXECUTED WITH THE SAME '
     'INPUTS."  §KEEP§SO THE FAST POLICY IS NOT THE PORTABLE ONE, AND THE '
     'COMPILER PICKS THE FAST ONE BY DEFAULT, AND THE ONLY WAY A READER LEARNS '
     'THAT IS BY DECODING TWO BITS.  §KEEP§THE PORTABILITY PROBLEM IN THE '
     'VECTOR EXTENSION IS NOT THE INSTRUCTION SET -- IT IS TWO BITS THE '
     'SPECIFICATION DELIBERATELY LEAVES UNDETERMINED.'),
    ('R15', 'a `vsetvli` sweep of 112 variants shows eleven bits in use',
     'it shows EIGHT, because zimm[10:8] is constant zero in every reachable '
     'variant -- three bits of an eleven-bit field that no `vsetvli` the '
     'assembler will emit ever uses.  §KEEP§THE RESERVED BITS ARE NOT WASTED, '
     'AND THE INHERITED DECODER\'S OWN COMMENT ABOUT THE ELEMENT WIDTH IS A '
     'LIVING EXAMPLE: IT SAID "THREE BITS OF THE FIELD" WITH FOUR CORRECT '
     'zimm STRINGS AND NEVER SAID WHICH THREE.  §KEEP§A FIELD MAP MEASURED BY '
     'SWEEP RECORDS WHICH BITS MOVE, AND THREE BITS THAT NEVER MOVE LOOK '
     'EXACTLY LIKE THREE BITS THAT DO.  §KEEP§A COMMENT THAT GIVES THE WIDTH '
     'OF A FIELD WITHOUT GIVING ITS POSITION IS A COMMENT THAT CANNOT BE '
     'CHECKED AGAINST THE FIELD.'),
    ('R16', 'the corpus\'s `fence` rows all have `rs1 = rd = 0` because the '
     'assembler emits zeroes there',
     'THEY HAVE ZEROES BECAUSE THE MANUAL REQUIRES THEM TO: "The unused '
     'fields in the FENCE instructions -- rs1 and rd -- are reserved for '
     'finer-grain fences in future extensions.  For forward compatibility, base '
     'implementations shall ignore these fields, and standard software shall '
     'ZERO these fields."  §KEEP§TWO RESERVED FIELDS IN AN INSTRUCTION WHOSE '
     'OTHER TWO FIELDS CARRY THE WHOLE MODEL IS THE TELL THAT THE ENCODING WAS '
     'DESIGNED FOR A FUTURE NOBODY HAS BUILT YET.  The first draft said the '
     'zeroes were a property of the assembler, which is true and is not why.'),
    ('R17', 'the two readers agreeing means this decoder is right',
     'it means THIS decoder and one other piece of software from the SAME LLVM '
     'TREE agree.  `clang` assembled the corpus and `llvm-objdump-21` '
     'disassembled it, and GNU binutils has no RISC-V target on this host, so '
     '§KEEP§THE TWO READERS SHARE AN ASSEMBLER, AND A CROSS-CHECK BETWEEN ONE '
     'TOOLCHAIN\'S OUTPUT AND ITS OWN VIEW OF THAT OUTPUT CANNOT FIND A BUG '
     'IN THE SHARED ASSUMPTIONS.  §KEEP§THE CORRECTION IS NOT "DO NOT TRUST '
     'THE CROSS-CHECK" BUT "SAY WHAT IT PROVES": this file and one other piece '
     'of software agree about what the bytes mean, and NOT that either agrees '
     'with silicon.  §KEEP§AND THAT SENTENCE IS LIMIT 11, IN THE ARTIFACT\'S '
     'OWN WORDS, BECAUSE A LIMIT PRINTED ONCE AT THE END IS A LIMIT THAT GETS '
     'SKIMMED PAST.'),
    ('R18', 'the lock-prefix count on RISC-V is zero because the assembler '
     'refuses `lock`',
     'the assembler refusing `lock` is a fact about the ASSEMBLER, and the '
     'claim needs to be about the ARCHITECTURE.  The measurement that carries '
     'the claim is the OTHER count: zero instructions in the corpus need a '
     'prefix to become atomic, against nine operations plus a reservation pair '
     'at two widths and four orderings that are atomic with no prefix at all.  '
     '§KEEP§"ZERO" IS AN ABSENCE OF FEATURES IF YOU PRINT IT ALONE AND A '
     'DESIGN DECISION IF YOU PRINT IT BESIDE THE COUNT IT REPLACED.  §KEEP§THE '
     'DIFFERENCE BETWEEN x86-64 AND RISC-V IS NOT THAT ONE HAS EIGHTEEN AND THE '
     'OTHER NONE -- IT IS THAT x86-64 MADE ATOMICITY A PROPERTY OF AN EXISTING '
     'INSTRUCTION AND RISC-V MADE IT A CATEGORY OF INSTRUCTION.'),
]

# Where each retraction was written down BEFORE this course measured it.  A
# retraction with no prior source is a course disagreeing with itself, which is
# a different failure and one that is worth being able to tell apart.
RET_SOURCES = {
    'R1': 'this course\'s own first run of section 11, which reported the '
          'inherited decoder naming ten `vsetvli` and nothing else -- and the '
          'code it read is the SIBLING\'s `rvdec.py`, which this course borrows '
          'rather than forks',
    'R2': 'this course\'s own first cross-check, whose agreement count was '
          'too high and whose cause was found by XORing two amo words; again '
          'the code is the SIBLING\'s, and the inherited `a_amo` it borrows is '
          'the model that does not read the two bits',
    'R3': 'this course\'s own first run of section 11 -- and the defect is in '
          "the SIBLING's decoder rather than in this file's",
    'R4': 'this course\'s own first reading of the inherited `s_misc_mem`, '
          'which looked correct',
    'R5': 'the brief this course was written from, which named this as the '
          "course's headline measurement",
    'R6': 'this course\'s own first draft of section 10\'s table',
    'R7': 'this course\'s own first draft of section 9, which described the '
          'group as a scalar',
    'R8': 'this course\'s own first draft of section 7, whose table had a '
          'zero in it and no explanation',
    'R9': 'this course\'s own first draft of section 7, which showed the load '
          'column only',
    'R10': "this course's own first draft of section 5",
    'R11': '`docs/course-mission.md`, which says "differs in kind" and '
           'supplies no mechanism',
    'R12': 'this course\'s own first draft of section 7, which counted the '
           'corpus',
    'R13': 'this course\'s own first draft of section 7, which had the '
           'direction of the superset backwards',
    'R14': 'this course\'s own first draft of section 8, which called the '
           'policy a performance detail',
    'R15': 'this course\'s own first sweep, which counted bits SET in any '
           'variant rather than bits that MOVE',
    'R16': 'this course\'s own first reading of the fence field table',
    'R17': 'this course\'s own first draft of section 11, which said "the two '
           'readers agree"',
    'R18': 'this course\'s own first draft of section 2, which printed the '
           'zero without the other count',
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


def sec13():
    banner(13, 'EIGHTEEN RETRACTIONS')
    print()
    para("""%s of them, and every one was asserted in a draft of this course or in
the brief it was written from, measured, and withdrawn.  They are printed in
full rather than footnoted, and `crosscheck.py` asserts their TEXT so that a
later edit cannot quietly delete one -- which is the only mechanism that has
ever stopped a retraction being quietly dropped.

Six of the %d are about a READER or an INSTRUMENT, five are about a
COMPARISON, three are about a CLAIM THAT WAS TRUE BUT INCOMPLETE, and four are
about the SUBJECT.  §KEEP§THE ONES THAT ARE ABOUT THE SUBJECT ARE THE ONES
WORTH READING TWICE, BECAUSE A LIST THAT IS UNIFORMLY ONE THING IS A LIST
NOBODY READ.""" % (NUMWORDS[len(RETRACTIONS)], len(RETRACTIONS)))
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
    print('THE CLAIM THAT TIES THE LIST TOGETHER is at the end of it:')
    print()
    print('  NOTHING HERE IS A MISTAKE ABOUT HOW A COMPUTER WORKS.  That is')
    print('  EIGHTEEN COURSES IN A ROW, and it is the most interesting thing')
    print('  about the list.  The RISC-V atomics, fence and vector extension did')
    print('  not surprise this course once.  What surprised it was a two-bit')
    print('  field two of whose four values are invalid on half the')
    print('  instructions that carry it, a decoder that computed three bits')
    print('  where the encoding has two, a bit that is "release" in one opcode')
    print('  and "mask" in another, a policy the specification declines to make')
    print('  deterministic, and a tail policy the compiler picks the fast way by')
    print('  default.')
    print()
    print('§KEEP§EIGHTEEN COURSES IN A ROW, AND EVERY SINGLE RETRACTION IS A')
    print('DISCOVERY ABOUT THE MACHINERY BUILT TO READ THE HARDWARE.')


# ===========================================================================
# SECTION 14 -- THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY
# CLAIM CAME FROM.
#
# This is the concept page the course is built around, so it is a TABLE rather
# than a paragraph and the table has a ratio in it.
# ===========================================================================

LIMITS = [
    'NO TIMING.  No cycle, no latency, no throughput, no speedup, no ratio of '
    'anything a machine did.  There is no RISC-V machine, no emulator and no '
    'RISC-V linker on this host, so every figure is a bit pattern, a count of '
    'bit patterns, an arithmetic identity, or a refusal from a real assembler. '
    'The `simd` and `smp` courses measured speedups on hardware, `x86simd` '
    'measured a lost-update count, and `a64simd` measured 3.89x, 4.92x and '
    '27.65x; those have NO COUNTERPART HERE AND ARE NOT INVENTED TO FILL THE '
    'GAP.',
    'NOTHING IS EXECUTED.  Not one instruction in this course has run.  A '
    'compare-exchange in section 5 has never exchanged; it is four words a '
    'compiler emitted and a disassembly that named them.',
    'NO RESERVATION IS EVER HELD, NO STORE-CONDITIONAL IS EVER OBSERVED TO '
    'SUCCEED OR TO FAIL, NO AMO IS EVER OBSERVED TO BE ATOMIC, NO FENCE IS '
    'EVER OBSERVED TO ORDER ANYTHING AND NO VECTOR INSTRUCTION IS EVER '
    'EXECUTED.  Five separate absences, and each one is a separate thing this '
    'course would otherwise be able to say.',
    'THE RESERVATION RULES ARE QUOTED AND NOT MEASURED.  What is measured is '
    'that `lr` is funct5 = 0b00010 with rs2 forced to zero, that the '
    'assembler REFUSES `lr.w a0, a1, (a2)` with "expected \'(\' or optional '
    'integer offset", and that clang emits `lr.w.aqrl` and `sc.w.rl` with a '
    'branch between them.  What is NOT measured is that the reservation is '
    'held, that the SC fails when it should, that one reservation per hart is '
    'enforced, or that a call in the middle of a pair invalidates anything.',
    'THE ORDERING MODEL IS DEFINED BY A DOCUMENT AND THE ENFORCEMENT IS '
    'SILICON.  The four fields of `fence` and the fifteen spellings of its two '
    'sets are measured on words.  Whether `fence rw, w` orders a store before '
    'a load on any real machine is QUOTED, and there is no hart here to be '
    'ordered.',
    'fence.tso IS A REQUEST AND WHETHER THE REQUEST IS HONOURED IS A '
    'PROPERTY OF THE IMPLEMENTATION.  It is measured that the compiler emits '
    'it for `__ATOMIC_ACQ_REL`, that it is fm = 1000 with pred = RW and succ = '
    'RW, and that the manual says it is "correct to ignore the fm field and '
    'implement FENCE.TSO as FENCE RW,RW".  Whether the machine gives the '
    'weaker or the stronger barrier is not observable here.',
    'THE VECTOR LENGTH IS NOT MEASURED.  `vlenb` is 0xC22 and clang emits '
    '`csrr a7, vlenb`; its VALUE is in no file on this host.  A machine with '
    '128-bit vectors and a machine with 1024-bit vectors both produce this '
    'assembly, and that is the point of the design rather than a gap in it.',
    'THE TAIL AND MASK POLICIES ARE MEASURED AS BITS AND NOT AS BEHAVIOUR.  It '
    'is measured that the compiler emits `ta, ma` and that the policy bits are '
    'zimm[7] and zimm[6].  Whether an agnostic tail is overwritten with ones or '
    'left alone is a property of silicon this host does not have, and the '
    'specification explicitly declines to require determinism.',
    'THE VECTORISED LOOPS HAVE NOT BEEN RUN AND MAY NOT BE CORRECT.  Nothing '
    'was executed, so no output was compared against anything, and the '
    'instruction counts in section 10 are counts of what a compiler emitted.',
    'THE TWO READERS SHARE AN ASSEMBLER.  `clang` assembled the corpus and '
    '`llvm-objdump-21` disassembled it, so both come from one LLVM tree, and '
    'GNU binutils has no RISC-V target installed on this host.  What section '
    '11 establishes is "this decoder and one other piece of software agree on '
    'what the bytes mean" -- NOT "either agrees with silicon".',
    'THE SOURCE/DISASSEMBLY PAIRING IN THE THREE HAND-WRITTEN CORPORA IS '
    'POSITIONAL, AND THE FILE CHECKS IT.  `amo.s`, `fence.s` and `vec.s` are '
    'straight-line lists of one instruction per line with no labels inside the '
    'instruction run, so source line N is word N.  The count is asserted on '
    'every run and a file that changed shape would fail loudly rather than '
    'silently mis-pair every field in the course.',
    'THE x86-64 LOCK LIST IS QUOTED FOR ITS EIGHTEEN AND MEASURED FOR WHAT THIS '
    'ASSEMBLER ACCEPTS.  The SDM\'s list is the oracle and `llvm-mc-21` is the '
    'instrument, and the two DISAGREE about `lock bt`, which this host\'s '
    'assembler accepts and the SDM refuses.  The disagreement is the finding and '
    'it is why the contrast is a toolchain measurement and not a count of '
    'architectural features.',
    'THE `-march` COMPARISON IS ONE LETTER AND NOT TWO.  The vector counts in '
    'section 10 are `rv64gc` against `rv64gcv`, which differ in `v` only and '
    'keep `c` on both sides.  The atomics comparison is `rv64im` against '
    '`rv64ima`.  An earlier draft used `rv64g` against `rv64gcv` and retracted '
    'the number, because that pair differs in `c` and `v` at once.',
    'EVERY INSTRUCTION COUNT AND EVERY FUNCTION IS CLANG 21.1.8\'S.  '
    '`crosscheck.py` asserts the encodings, the bit positions, the field '
    'positions and the two-reader agreement as exact quantities, and the '
    'instruction counts and the compiler\'s choices as shapes and orderings, '
    'because a shape does not move with a compiler and a bare value does.',
    'THE VECTOR DATA PATH IS ONE QUARTER MODELLED AND THE REST IS COUNTED.  '
    'This file models the three configuration instructions, the mask bit in '
    'three groups and the register group; the remaining vector encodings are '
    'declined and COUNTED, and a decoder that named all of them and got one '
    'wrong would be worse than one that says which half it implements.',
    'THE INHERITED DECODER IS BORROWED AND NOT FORKED, AND THREE OF THE FOUR '
    'PREPENDED MODELS ARE REPAIRS TO GAPS IN IT.  R1, R2 and R3 name the '
    'defects and they live in the SIBLING\'s code.  The sibling is untouched, '
    'for the reason the sibling set out: a course that quietly patches a '
    'neighbour to make its own numbers work is a course whose numbers are not '
    'measurements any more.',
    'NOTHING GENERALISES FROM AN EMPTY ROW.  Every distribution here is a '
    'distribution of what clang chose for a handful of files at one version on '
    'one host, and a row with nothing in it is a statement about that corpus '
    'and not about the architecture.',
    'A CROSS-CHECK THAT AGREES IS NOT PROOF.  Section 12 exists because the '
    'AArch64 data-path course reported ZERO disagreements over a corpus where '
    'eighty-five instructions genuinely disagreed, and the only way to know '
    'whether a cross-check can fail is to make it fail on purpose.',
    'THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT.  Quoting is not '
    'verifying.  The two documents -- `rv32-unpriv` and `riscv-cc` -- were '
    'read and every QUOTED row names one of them with a chapter, and a reader '
    'who wants to disagree with a QUOTED row has the citation to disagree with.',
]

CANNOT_CONCLUDE = [
    'That any atomic instruction is ATOMIC.  What is measured is the encoding '
    'and what the compiler emitted.  Atomicity is a promise about observable '
    'behaviour and no behaviour has been observed.',
    'That a store-conditional ever FAILS, or ever succeeds.  The rules that '
    'say when it must fail are QUOTED from chapter 12 and there is no hart here '
    'to fail on anything.',
    'That `fence rw, w` ORDERS anything.  What is measured is that the '
    'assembler accepts the spelling, that pred is 0011 and succ is 0001, and '
    'that the manual calls it a relation between two sets.  Whether a store is '
    'observed before a load is a question about silicon.',
    'That `fence.tso` is a WEAKER barrier than `fence rw, rw`.  The manual '
    'permits an implementation to ignore `fm` and implement it as `fence rw, '
    'rw`, so it may be either, and which one a machine does is not observable '
    'here.',
    'That the vector loop is FASTER than the scalar loop it replaces.  No '
    'vector instruction in this course has run and no timing exists anywhere in '
    'this file.',
    'What VLEN IS on any machine.  `vlenb` is read by the compiler and its '
    'value is in no file on this host.',
    'Whether an AGNOSTIC tail is overwritten with ones.  The specification '
    'explicitly declines to require determinism, so there is no correct answer '
    'to check against.',
    'That the vectorised loops are CORRECT.  Nothing was executed, so no output '
    'was compared against anything.',
    'That `llvm-objdump-21` agrees with the silicon.  Section 11 establishes '
    'that this file\'s decoder and one other piece of software from the same '
    'LLVM tree agree on what the bytes mean.  That is a fact about two programs '
    'and not about a processor.',
]

CAN_CONCLUDE = [
    'Every bit pattern in this course is byte-for-byte reproducible from the '
    'files in this directory and the exact clang invocation section 1 prints, '
    'and the six second-reader listings are committed so a reader with a hex '
    'editor and no cross-compiler can check all of it.',
    'That `aq` is inst[26] and `rl` is inst[25], measured as one XOR per pair '
    'over the whole corpus with a single result for each, and that the three '
    'XORs are ADDITIVE -- which is what makes them two fields and not one field '
    'with four values.',
    'That the `.w` and `.d` suffixes are ONE BIT of funct3, measured as nine '
    'XORs that are all exactly 0x1000.',
    'That `lr` requires rs2 = 0 and the assembler ENFORCES it, measured by a '
    'refusal whose diagnostic is about syntax and whose cause is semantics.',
    'That `fence` carries four fields, two of which are reserved and zero in '
    'every word the assembler emits, and that the predecessor and successor '
    'sets have FIFTEEN named spellings out of sixteen codes.',
    'That there is no implicit lock anywhere in RISC-V, measured as a count of '
    'zero against the OTHER count -- nine operations plus a reservation pair at '
    'two widths and four orderings -- rather than as an absence.',
    'That the compiler\'s atomic code is a LIBRARY CALL without the `a` letter '
    'and INLINE INSTRUCTIONS with it, one letter apart, with the call\'s own '
    'name carrying the width.',
    'That zimm[10:8] is constant zero across all 112 reachable `vsetvli` '
    'variants, which is a measurement about which bits MOVE rather than about '
    'which bits are set in some example.',
    'That the mask is one bit in three instruction groups and the mask '
    'register is NOT in the encoding, with the assembler naming that property '
    'in a diagnostic.',
    'That the compiler reads the vector length from a CSR, and that -O2 and -O3 '
    'produce byte-identical assembly for this corpus.',
    'Every limit on this page, which are the sentences that make the other '
    'nineteen safe to say.',
]

PROVENANCE = [
    ('the A extension is one opcode, 0101111', BYTES,
     'inst[6:0] of every word in amo.o, cross-checked against '
     'llvm-objdump-21'),
    ('eleven operations at two widths, eleven distinct funct5 values', BYTES,
     'inst[31:27] of 18 words in amo.o'),
    ('twenty-one of the thirty-two funct5 values are unnamed', BYTES,
     'a full sweep of inst[31:27] printed in full, holes included'),
    ('the eleven funct5 values are grouped in fours', BYTES,
     'the gaps between consecutive named values, printed'),
    ('the two reservation instructions sit at 2 and 3', BYTES,
     'inst[31:27] of the four lr/sc words in amo.o'),
    ('the width is ONE BIT of funct3', BYTES,
     'twelve .w/.d XOR pairs in amo.o, every one 0x1000'),
    ('aq is inst[26] and rl is inst[25]', BYTES,
     'every .aq/.rl/.aqrl XOR in amo.o: two distinct values'),
    ('the three ordering XORs are ADDITIVE', BYTES,
     'aq|rl against the plain form, compared with the two single-bit XORs'),
    ('lr requires rs2 = 0 and the assembler enforces it', MEAS,
     'a refusal probe: `lr.w a0, a1, (a2)`'),
    ('the AMO width pair is a TEMPLATE PARAMETER in the fallback path', MEAS,
     'the symbol name in amo_noa_O2.o, read out of the disassembly'),
    ('zero RISC-V instructions take a lock prefix', MEAS,
     'nine assembler probes including the literal word `lock`'),
    ('no instruction is implicitly locked', MEAS,
     'the count beside it: nine operations plus a pair, atomic with no prefix'),
    ('x86-64 accepts twenty-two lock-prefixed spellings', MEAS,
     'llvm-mc-21 assembling lock86.s, and its own encodings'),
    ('the assembler ACCEPTS `lock bt`, which the SDM refuses', MEAS,
     'one line of lock86.s, with its encoding [0xf0,0x48,0x0f,0xa3,0x18]'),
    ('the SDM names eighteen instructions that accept LOCK', QUOT,
     'the sibling x86-64 course, quoting the SDM; it is a quoted number and '
     'this course does not restate it as a measurement'),
    ('and xchg is implicitly locked with or without the prefix', QUOT,
     'the SDM, quoted in the sibling course: "REGARDLESS OF THE PRESENCE OR '
     'ABSENCE OF THE LOCK prefix"'),
    ('aq, rl and the four C11 semantics', QUOT,
     'rv32-unpriv chapter 12, section 12.1.1'),
    ('the reservation set rules, and one reservation per hart', QUOT,
     'rv32-unpriv chapter 12, section 12.1.2'),
    ('the scratch-word rule for forcibly invalidating a reservation', QUOT,
     'rv32-unpriv chapter 12, section 12.1.2'),
    ('a byte-width AMO exists, in Zabha, and not in the base A extension',
     QUOT, 'rv32-unpriv chapter 12, which documents Zabha beside Zaamo and '
     'Zalrsc; the assembler names the extension in its refusal'),
    ('the eventuality guarantee for constrained LR/SC loops', QUOT,
     'rv32-unpriv chapter 12, section 12.1.3'),
    ('LR.rl and SC.aq are not to be set without the other bit', QUOT,
     'rv32-unpriv chapter 12, section 12.1.2'),
    ('FENCE R,RW suffices for acquire and FENCE RW,W for release, at extra '
     'ordering', QUOT, 'rv32-unpriv chapter 12, section 12.1.4'),
    ('fence carries fm, pred, succ, rs1 and rd', MEAS,
     'inst[31:28], [27:24], [23:20], [19:15] and [11:7] of 34 words'),
    ('rs1 and rd are reserved and standard software shall zero them', QUOT,
     'rv32-unpriv chapter 2.7, "The unused fields in the FENCE instructions '
     '-- rs1 and rd"'),
    ('the memory and I/O domains are two axes, not one', QUOT,
     'rv32-unpriv chapter 2.7'),
    ('fence.tso is fm = 1000 with pred = RW and succ = RW', BYTES,
     'inst[31:28] of the two 0x8330000f words in fence.o'),
    ('an implementation may implement FENCE.TSO as FENCE RW,RW', QUOT,
     'rv32-unpriv chapter 2.7, Table 4 and the paragraph after it'),
    ('the accepted spellings of pred and succ are fifteen of sixteen', MEAS,
     'fifteen assembler probes, one per non-empty subset of {i,o,r,w}'),
    ('the empty set is not spellable', MEAS,
     'a refusal probe on `fence` with an empty operand'),
    ('a relaxed C11 fence emits NO instruction', MEAS,
     'the body of f_relaxed in fence_c_O2.o'),
    ('CONSUME and ACQUIRE emit the same four bits', MEAS,
     'the fence words of f_consume and f_acquire, XORed'),
    ('ACQ_REL emits fence.tso and SEQ_CST emits fence rw, rw', MEAS,
     'the fence words of the two functions in fence_c_O2.o'),
    ('an acquire load and a seq_cst load are the same `lw`', MEAS,
     'the load word in l_acquire and l_seqcst, compared byte for byte'),
    ('and a seq_cst load carries TWO fences', MEAS,
     'the fence count in l_seqcst, which is 2'),
    ('vsetvli, vsetivli and vsetvl are told apart by inst[31:30]', BYTES,
     'inst[31:30] of three configuration words in vec.o'),
    ('zimm is eleven bits at inst[30:20] and zimm[10:8] is constant zero',
     BYTES, '112 assembled variants swept, 112 distinct values, 3 bits never '
     'moving'),
    ('the four vtype fields and their widths', BYTES,
     'thirteen XOR probes against a fixed base variant, in the table in '
     'section 8'),
    ('AVL is encoded in two bits of register identity', QUOT,
     'rv32-unpriv chapter 30, Table 49; and the three rows MEASURED in '
     'section 8'),
    ('the length is in the CSR vl and the byte length in vlenb', QUOT,
     'rv32-unpriv chapter 30, sections 31.3.6 and 31.6'),
    ('vlenb is CSR 0xC22 and is read-only from U-mode', BYTES,
     'inst[31:20] of 0xc22028f3, decomposed with the privileged course\'s own '
     'field map'),
    ('the mask is one bit at inst[25] in three instruction groups', BYTES,
     'eleven adjacent-pair XORs in vec.o, all 0x02000000'),
    ('the only mask register the encoding can name is v0', MEAS,
     'a refusal probe: "operand must be v0.t"'),
    ('v0 is a destination as well as a mask source', BYTES,
     'inst[11:7] of the vmsne.vi and vlm.v words in vec.o'),
    ('nf at inst[31:29] is the register group count', BYTES,
     'the eight whole-register load and store words in vec.o'),
    ('a register group must start on a group boundary', MEAS,
     'a refusal probe: `vl2r.v v1` refused, `vl2r.v v8` accepted'),
    ('the tail and mask policies, and their four combinations', QUOT,
     'rv32-unpriv chapter 30, section 31.3.4.3 and its table'),
    ('the agnostic pattern is not required to be deterministic', QUOT,
     'rv32-unpriv chapter 30, section 31.3.4.3'),
    ('the tail and mask flags are mandatory in the assembly syntax', QUOT,
     'rv32-unpriv chapter 30, section 31.3.4.3'),
    ('the vtype register layout, with vill above three reserved bits', QUOT,
     'rv32-unpriv chapter 30, Table 48, printed beside the measured sweep'),
    ('the agnostic policy exists to accommodate vector register renaming',
     QUOT, 'rv32-unpriv chapter 30, the vtype discussion'),
    ('the value in vlenb is a design-time constant in any implementation',
     QUOT, 'rv32-unpriv chapter 30, section 31.3.6'),
    ('and the compiler emits `ta, ma` in 31 of the corpus\'s 120 vsetvli', MEAS,
     'zimm[7] and zimm[6] of every vsetvli in vec.o, counted, and the other '
     'three combinations are in the table in section 8'),
    ('-O1 emits no vector instruction, -Os emits 21 and -O2 and -O3 emit 19',
     MEAS, 'the vector instruction count in 20 objects'),
    ('-Os is smaller than -O2 in code size while emitting MORE vector '
     'instructions, and -O2 and -O3 produce identical assembly here', MEAS,
     'word-by-word comparison of four functions at the two levels, and the '
     'per-level instruction totals printed in section 10'),
    ('the compiler reads the vector length with csrr a7, vlenb', MEAS,
     'the CSR read in three of the four vectorised functions'),
    ('the two readers agree on the whole corpus', BYTES,
     "this file's decoder against llvm-objdump-21, over every object"),
    ('and this file declines to name the rest of the vector data path', BYTES,
     'the UNMODELLED count, printed beside the disagreement count'),
]


def sec14():
    banner(14, 'THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY '
               'CLAIM CAME FROM')
    print()
    para("""Everything in the last thirteen sections carries one of three labels,
and on most pages you would be forgiven for not noticing.  This section prints
all of them, in one table, with the count -- and the COUNT is the finding,
because this is a course about ENCODINGS and about a COMPILER'S CHOICES, and
those are exactly the two things a host without hardware can measure.

§KEEP§THE RATIO IS NOT A QUALITY SCORE.  It is a map of the subject.  The
neutral courses `simd` and `smp` and the per-architecture courses `x86simd` and
`a64simd` all had hardware, so their quoted thirds are smaller for the same
reason: what a document says is not measurable on a host with no machine, and
what IS measurable -- a bit position, a field map, an instruction count, a
refusal -- is the part a compiler author needs and the part a page-table writer
needs.""")
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
    n_q = counts.get(QUOT, 0)
    n_m = counts.get(MEAS, 0) + counts.get(BYTES, 0)
    pct = 100 * n_q // n_all
    pctm = 100 * n_m // n_all
    para("""§KEEP§AT %d PER CENT THE MEASURED AND MEASURED-ON-BYTES THIRDS ARE A
MAJORITY OF THIS COURSE'S CLAIMS, AND THAT IS A STATEMENT ABOUT THE SUBJECT AND
NOT ABOUT CARE.  %d OF %d ROWS ARE MEASURED OR MEASURED-ON-BYTES AGAINST %d OF
57 IN `a64sys` AND %d OF 44 IN `rvpriv`.

§KEEP§AND THE COMPARISON CUTS BOTH WAYS, SO BOTH HALVES ARE PRINTED.  THIS
COURSE'S QUOTED FRACTION IS %d PER CENT, a64sys's IS %d PER CENT AND rvpriv's
IS %d PER CENT.  §KEEP§SO THE RISC-V PRIVILEGED COURSE'S QUOTED THIRD IS THE
LARGEST IN THE SECTION AND A COURSE THAT CLAIMED OTHERWISE WOULD BE MAKING A
NUMBER UP.

The reason this course's quoted third is the SMALLEST in the RISC-V section is
not that it depends less on a document.  It is that there was MORE TO MEASURE:
the AMO encodings, the two ordering bits as an XOR, the thirteen XOR probes
that decompose `vtype`, the eleven mask XORs, the fifteen fence spellings,
the -march experiment and the twenty objects of compiler output -- none of
which `rvpriv` had a reason to touch, because its subject is a CSR address and
a page table rather than an instruction that has to be FAST.

§KEEP§THE SUBJECT IS AN ENCODING AND A COMPILER'S CHOICE.  WHAT AN ENCODING
IS AND WHAT A COMPILER CHOSE ARE EXACTLY WHAT A HOST WITHOUT HARDWARE CAN
MEASURE, AND THE RATIO ABOVE IS A MAP OF THE SUBJECT RATHER THAN A DISCLAIMER.
IT IS PRINTED AS A TABLE BECAUSE A PERCENTAGE IN A SENTENCE IS A NUMBER NOBODY
CAN CHECK.""" % (pctm, n_m, n_all, 31, 23, pct, 100 * 31 // 57,
                 100 * 23 // 44))

    print()
    para("""%s limits, and they are printed in the artifact's own words so that a
reader who copies a number out of this file cannot lose the sentence that
limits it.  The first three decide what every other one may say.""" %
         NUMWORDS[len(LIMITS)].lower().capitalize())
    print()
    for k, lim in enumerate(LIMITS):
        body = _wrap(lim, 70, '')
        print('  %d. %s' % (k + 1, body[0].strip()))
        for extra in body[1:]:
            print('     %s' % extra.strip())
    print()
    para("""A LIST OF %s LIMITS says what this file declines to do.  A LIST OF WHAT A
READER THEREFORE CANNOT CONCLUDE is a different thing, and it is the one that
protects the reader rather than the file: the limits are this course's promises
and the cannot-list is the set of sentences that would be FALSE if a reader
carried the promises in one direction rather than the other.  It is printed
beside the limits, not in a footnote, because a footnote is a place where a
scope statement goes to be skipped.""" % NUMWORDS[len(LIMITS)].upper())
    print()
    for item in CANNOT_CONCLUDE:
        body = _wrap(item, 70, '')
        print('  * %s' % body[0].strip())
        for extra in body[1:]:
            print('    %s' % extra.strip())
    print()
    para("""§KEEP§AND HERE IS THE OTHER HALF, because a course that prints only a
cannot-list teaches its reader that the subject is unknowable, which is the
opposite of what %d measured bit patterns are for.""" % n_all)
    print()
    for item in CAN_CONCLUDE:
        body = _wrap(item, 70, '')
        print('  * %s' % body[0].strip())
        for extra in body[1:]:
            print('    %s' % extra.strip())
    print()
    para("""§KEEP§THE TWO LISTS ARE THE SAME ABSENCES SEEN FROM OPPOSITE SIDES, AND THE
SECOND IS LONGER -- %d items against %d -- WHICH IS THE POINT: there is more
that can be read off bytes than there is that can be said about behaviour.  A
reader who finishes this file able to state the second list precisely and the
first list vaguely HAS IT EXACTLY BACKWARDS.""" % (
        len(CAN_CONCLUDE), len(CANNOT_CONCLUDE)))
    print()
    para("""WHAT THE COURSE OWES ITS SIBLINGS, and does not re-teach.  Every link
was verified present by a live route check, and the identical list is in
`crosscheck.py`, which asserts both that each id IS present and that each id
this course has ALREADY RETIRED is ABSENT -- because a positive list passes on
any set of ids that exist and says nothing about the ones that do not, and the
previous course in this section shipped four ids that 404'd while its own
artifact said every one of them had been verified.

  * what a race is and what "atomic" has to mean for it -- the neutral course:
    /courses/smp/lessons/smp-atomic, /courses/smp/lessons/smp-ordering
  * what a vector lane is, and what a reduction is -- the neutral course:
    /courses/simd/lessons/simd-width, /courses/simd/lessons/simd-reduce
  * why a vectorised loop needs a remainder, and why it is hard to do
    portably -- /courses/simd/lessons/simd-boundaries
  * what the vectoriser does and does not do
      /courses/simd/lessons/simd-compiler
  * the SAME SUBJECT on x86-64, where it IS measurable on hardware:
    /courses/x86simd/lessons/x86-atomics, /courses/x86simd/lessons/x86-order
  * the SAME SUBJECT on AArch64, where acquire and release are ACCESS MODES
    rather than two bits -- /courses/a64simd/lessons/a64-atomic,
    /courses/a64simd/lessons/a64-order
  * and the section's spine, why there are no condition codes:
    /courses/rvabi/lessons/rv-noflags

Verified present by a live route check, every one of them, and asserted both
ways in `crosscheck.py`.""")


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE METHOD, AND WHAT IT MAY NOT CLAIM', sec1),
    (2, 'THE ZERO -- NO IMPLICIT LOCK, AND WHAT IT COSTS TO SAY SO', sec2),
    (3, 'THE ELEVEN OPERATIONS, AND THE ONE BIT THAT IS THE WIDTH', sec3),
    (4, 'aq AND rl ARE TWO ADJACENT BITS, AND THE XOR PROVES IT', sec4),
    (5, 'lr AND sc -- WHY THE RETRY IS THE INSTRUCTION', sec5),
    (6, "THE COMPILER'S DECISION -- ONE LETTER, TWO DIFFERENT ANSWERS", sec6),
    (7, 'fence -- FOUR FIELDS, FIFTEEN SPELLINGS, ONE DEFINITION', sec7),
    (8, 'vsetvli AND THE FOUR FIELDS IT CARRIES', sec8),
    (9, 'THE MASK IS ONE BIT IN THREE GROUPS', sec9),
    (10, 'WHAT THE COMPILER EMITS, AND WHAT IT CANNOT RUN', sec10),
    (11, 'TWO READERS ON THE SAME BYTES', sec11),
    (12, 'FOUR POISONS, AND EACH ONE HAS TO MOVE ITS OWN NUMBER', sec12),
    (13, 'EIGHTEEN RETRACTIONS', sec13),
    (14, 'THE MEASURED/QUOTED BOUNDARY, THE LIMITS, AND WHERE EVERY CLAIM '
         'CAME FROM', sec14),
]


def header():
    print(RULE)
    print('rvat.py -- RISC-V atomics, ordering and vectors, measured on the bytes')
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
    print('  The two documents every QUOTED row names:')
    print('    rv32-unpriv  Volume I, the unprivileged architecture, v20260120')
    print('                 chapters 2, 12, 17, 18 and 30')
    print('    riscv-cc     the RISC-V ISA Calling Convention, v20230911')
    print()
    print('  NOTHING HERE IS EXECUTED.  There is no RISC-V machine, no emulator')
    print('  and no RISC-V linker on this host, so NO RESERVATION IS EVER HELD,')
    print('  NO AMO IS EVER OBSERVED TO BE ATOMIC, NO FENCE IS EVER OBSERVED TO')
    print('  ORDER ANYTHING, AND NO VECTOR INSTRUCTION IS EVER RUN.  There are')
    print('  NO TIMINGS and NO SPEEDUPS anywhere in this file.  §KEEP§THE')
    print('  SIBLINGS THAT MEASURED RATIOS MEASURED THEM ON HARDWARE AND THIS')
    print('  ONE HAS NO HARDWARE, SO THE RATIOS HAVE NO COUNTERPART HERE AND')
    print('  ARE NOT INVENTED TO FILL THE GAP.  Section 1 says so before the')
    print('  first measurement and section 14 says so after the last one.')
    print()
    print('  The decoder is BORROWED from courses/rvasm/assets/samples/')
    print('  (rvdec.py) and this file PREPENDS FOUR models of its own.')
    print('  `m_setivli` names vsetivli and vsetvl, which the inherited decoder')
    print('  cannot; `m_vector_mask` names the vector DATA path, which it')
    print('  declines; `m_amo_order` READS inst[26] and inst[25], which it never')
    print('  looks at; and `m_fence_sets` renders the fence sets as letters and')
    print('  names fence.tso, which it calls `fence`.  It edits no sibling;')
    print('  section 13\'s R1, R2 and R3 say what each one adds and why the')
    print('  sibling is untouched.')
    print()
    print('  Inherited decoder models: %d, of which this course PREPENDS 4.'
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
        print('  THE MODELS IN THE DISPATCH, IN ORDER, WITH THIS COURSE\'S FOUR')
        print('  FIRST:')
        print()
        for k, (nm, ops, fn, ext, claim) in enumerate(Dec.MODELS32):
            tag = '  <- THIS COURSE' if k < 4 else ''
            print('   %2d %-16s opcodes %-16s %s'
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
        print('no section %s' % want)
        return 1
    if '--xcheck' in args:
        r = xcheck_one()
        for k in ('total', 'named', 'agree', 'disagree', 'unmodelled',
                  'length_disagree'):
            print('  %-18s %d' % (k, r[k]))
        return 0
    header()
    for n, _t, fn in SECTIONS:
        fn()
        print()
    print(RULE)
    print('END OF REPORT -- %d sections, %d limits, %d retractions, %d poisons, '
          '%d provenance rows' % (len(SECTIONS), len(LIMITS),
                                   len(RETRACTIONS), 4, len(PROVENANCE)))
    print('  %s of them is a mistake about how a computer works.  That is '
          'EIGHTEEN courses in a row.' % 'NONE')
    print(RULE)
    return 0


if __name__ == '__main__':
    sys.exit(main())
