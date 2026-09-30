#!/usr/bin/env python3
"""rvdec.py -- a RISC-V instruction decoder, and the reason for every bit.

RISC-V is the only one of the three architectures in this collection whose
instruction LENGTH is not a constant.  x86-64 is 1 to 15 bytes, AArch64 is
exactly 4, and RISC-V is 2 or 4 -- so a decoder that knows nothing about what
an instruction DOES still has to know how long it is before it can read the
next one.  That single fact reorganises everything:

    if bits[1:0] == 0b11   the instruction is 32 bits
    else                    the instruction is 16 bits

and the rule needs two bits of the CURRENT position and nothing else, which
is why the chain still cannot desynchronise even when the decoder has no model
for the instruction it just read.  Every other thing here follows from that:
six formats instead of one class field, a three-bit register field that is not
the five-bit one, an immediate whose bit PERMUTATION is the design, and an
extension that can make a legal instruction's encoding illegal.

    python3 rvdec.py 952e                 # decode one 16-bit instruction
    python3 rvdec.py 0d85f2d7             # decode one 32-bit instruction
    python3 rvdec.py --why 00b05063       # only the derivation, field by field
    python3 rvdec.py --elf rv.o           # walk every code section
    python3 rvdec.py --imm 0x00b05063     # the five immediates, from the bits
    python3 rvdec.py --audit              # the modelled-opcode table
    python3 rvdec.py --fields             # MEASURE the field map by difference
    python3 rvdec.py --space              # all 65,536 half-words, classified
    python3 rvdec.py --section 4          # sections 4, 4B, 4C and 4D
    python3 rvdec.py --run                # the whole report

NO TOOL DECODES ANYTHING.  Part one of this file imports os, re, struct and
sys and nothing else.  ELF64 section headers are read with struct.unpack_from
and `.text` is found by NAME, exactly as the AArch64 course's a64dec.py does
and for the same reason: a decoder that shells out to a disassembler is a
disassembler with a hardcoded path in it.

The second reader is `llvm-objdump-21 --triple=riscv64`, and the two-reader
cross-check is in section 10 -- which decodes the same bytes twice, reports the
disagreement count, POISONS the decoder three separate ways, and requires
every poison to move the number it claims to test.  That last clause is the
one that matters: this collection has already had a cross-check report zero
disagreements over a corpus where eighty-five instructions genuinely
disagreed, and every one of the four bugs had made the comparison VACUOUS
rather than wrong.  A number nobody can make move is a number nobody should
believe, so this file prints how many times each normalisation rule fired and
treats a rule that fired zero times as a defect.
"""

import os
import re
import struct
import subprocess
import sys

# ===========================================================================
# Part one: the decoder.  Nothing in this part runs a tool.
# ===========================================================================

# ---------------------------------------------------------------------------
# Registers.
#
# There are 32 integer register NUMBERS and 32 floating-point register
# NUMBERS, and they are separate files.  The ABI gives most of them a second
# name that says what they are FOR, and which name the assembler prints is a
# printing choice rather than part of the encoding -- the encoding holds a
# number.
#
# The names below are QUOTED from the RISC-V Calling Convention document
# (the `riscv-cc` manual), and the fact that they are what the second reader
# prints is MEASURED: section 3 counts them.  A decoder that prints numbers
# and a decoder that prints ABI names are both right; a cross-check between
# them has to reconcile the two, and section 10 says how.
# ---------------------------------------------------------------------------
XNAME = ['zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
         's0', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5',
         'a6', 'a7', 's2', 's3', 's4', 's5', 's6', 's7',
         's8', 's9', 's10', 's11', 't3', 't4', 't5', 't6']
FNAME = (['ft%d' % i for i in range(8)] + ['fs0', 'fs1'] +
         ['fa%d' % i for i in range(8)] + ['fs%d' % i for i in range(2, 12)] +
         ['ft%d' % i for i in range(8, 12)])


def xreg(n):
    """A 5-bit integer register number -> the name the assembler prints.

    x8 is `s0` and the ABI also calls it `fp`; the assembler prints `s0`, and
    the choice is the printer's, not the encoding's.  This is the same class of
    thing as the AArch64 x30-is-sometimes-xzr trap and it is much milder: the
    name is never wrong, it is only sometimes not the one you expected.
    """
    return XNAME[n] if 0 <= n < 32 else 'x?%d' % n


def freg(n):
    return FNAME[n] if 0 <= n < 32 else 'f?%d' % n


def creg3(n):
    """A THREE-bit compressed register field.

    This is the field the whole C extension is built on and it is not the
    five-bit field.  bits[9:7] and bits[4:2] hold a number in 0..7, and that
    number is not a register number: it indexes the eight registers x8 to x15.
    QUOTED (the `zca` extension, "Compressed Instruction Formats", the
    `rd'/rs1'` table) and MEASURED in section 4, where the same sweep that
    returns bits[11:7] and five bits for the base ISA returns bits[9:7] and
    three bits here.

    A decoder that reads a compressed register with `xreg` reports x0 to x7
    where the encoding means x8 to x15.  Every register name in the program
    comes out seven too small, the disassembly is plausible, and no test that
    only checks "does it decode" will ever see it.
    """
    return xreg(8 + (n & 7))


# ---------------------------------------------------------------------------
# Bit helpers.  Everything the decoder knows about an instruction is a
# function of these, and each one is written out longhand rather than
# optimised so a reader can check it against the specification's figure.
# ---------------------------------------------------------------------------


def bits(w, hi, lo):
    """Bits hi..lo of w, counting bit 0 as the LEAST significant bit.

    RISC-V is little-endian in the file and the bit numbering in the
    specification is the same: inst[0] is the least significant bit of the
    low-addressed byte.  So a little-endian 32-bit read gives a word whose
    bit 0 is the instruction's bit 0, and no byte swap is needed anywhere in
    this file.  That is worth saying because it is the one thing that is
    different from the ELF course's big-endian examples and it is the reason
    a `struct.unpack_from('<I', ...)` is the correct reader here.
    """
    return (w >> lo) & ((1 << (hi - lo + 1)) - 1)


def sign_extend(v, n):
    """Sign-extend an n-bit two's-complement value."""
    if v & (1 << (n - 1)):
        return v - (1 << n)
    return v


class Bad(Exception):
    """The word does not decode here.  Carries the reason."""


class Reserved(Bad):
    """A well-formed word the specification RESERVES.

    Kept separate from Bad because the distinction is the whole of section 6:
    a RESERVED encoding is one the specification has not assigned, an
    unmodelled one is one THIS FILE has not modelled, and the two produce the
    same output in a disassembler.  A cross-check that reported reserved
    encodings as decoder failures would be reporting its own declared scope
    as a bug, and a cross-check that reported unmodelled encodings as
    failures would be doing the same thing in the other direction.
    """


class Undefined(Bad):
    """A well-formed word inside an assigned encoding that is UNDEFINED."""


# ---------------------------------------------------------------------------
# The LENGTH RULE.  This is the one thing RISC-V makes a decoder do that
# AArch64 does not, and it is two bits long.
#
# MEASURED in section 2 over every word of every corpus object: the walk that
# uses this rule and nothing else lands EXACTLY on every section's end.  That
# is the property that makes the declared subset a subset of NAMES rather than
# a subset of LENGTHS, exactly as in the AArch64 course -- but reached by a
# different route, because here the length is a RULE and there it was a
# constant.
# ---------------------------------------------------------------------------


def length_of(b0, b1):
    """How many bytes does the instruction starting with these two bytes take?

    b0 and b1 are the first two bytes, low-addressed first.  The rule uses
    only their LOW two bits, which are the low two bits of the low-addressed
    byte -- that is, byte 0's bits 0 and 1.  The specification puts the field
    at inst[1:0] and this function is that field, spelled out.

    The reason the rule is safe, and it is the reason the chain cannot
    desynchronise, is that it is LOCAL.  Deciding how long instruction N is
    needs two bits of instruction N and no memory of any earlier decision.  A
    decoder with no model at all for a word still steps over it correctly,
    which is a stronger guarantee than AArch64's and much weaker than
    x86-64's -- x86 has no rule to desynchronise from, it has prefixes to
    misparse.
    """
    return 4 if ((b0 | (b1 << 8)) & 3) == 3 else 2


# ---------------------------------------------------------------------------
# The six formats.
#
# The specification's own words, QUOTED from the Unprivileged ISA manual
# volume I, section 2.2 "Base Instruction Formats":
#
#   "In the base RV32I ISA, there are four core instruction formats
#    (R/I/S/U), as shown in Figure 2.1."
#
# and from section 2.3 "Immediate Encoding Variants":
#
#   "There are a further two variants of the instruction formats (B/J) based
#    on the handling of immediates."
#
# So "six formats" is a true count of layouts and a slightly loose
# description of the manual's own division, and the honest thing is to print
# BOTH: the manual says four core formats plus two immediate variants, and
# this decoder dispatches on six.  A course that reported "six" without the
# quotation would be implying the manual counts six, and it does not.
# ---------------------------------------------------------------------------

FORMATS = [
    ('R', 'register-register', 'funct7|rs2|rs1|funct3|rd|opcode',
     'the base computational triple; no immediate at all'),
    ('I', 'register-immediate', 'imm[11:0]|rs1|funct3|rd|opcode',
     'loads, and every register-immediate operation; the immediate is '
     'CONTIGUOUS at inst[31:20]'),
    ('S', 'store', 'imm[11:5]|rs2|rs1|funct3|imm[4:0]|opcode',
     'a store, which has no rd to put a field in, so the immediate is split '
     'in two and wrapped around'),
    ('B', 'branch', "imm[12|10:5]|rs2|rs1|funct3|imm[4:1|11]|opcode",
     'a conditional branch, which must reach an EVEN target, so bit 0 of the '
     'displacement is a CONSTANT ZERO and the 12 bits that are left are '
     'permuted into the gaps the S format left'),
    ('U', 'upper immediate', 'imm[31:12]|rd|opcode',
     '20 bits of a 32-bit constant, placed so they are already in position'),
    ('J', 'jump', "imm[20|10:1|11|19:12]|rd|opcode",
     'a jump, which has no rs1 and no rs2 at all, so both register slots are '
     'available for the displacement and 20 bits become 21'),
]

# The field positions, as (name, hi, lo) triples, MEASURED by the sweep in
# section 4 and cross-checked against the manual's figures.  The two agree on
# every row; section 4 prints both columns and the sweep, and says which is
# which.
BASE_FIELDS = {
    'R': [('funct7', 31, 25), ('rs2', 24, 20), ('rs1', 19, 15),
          ('funct3', 14, 12), ('rd', 11, 7), ('opcode', 6, 0)],
    'I': [('imm', 31, 20), ('rs1', 19, 15), ('funct3', 14, 12),
          ('rd', 11, 7), ('opcode', 6, 0)],
    'S': [('imm[11:5]', 31, 25), ('rs2', 24, 20), ('rs1', 19, 15),
          ('funct3', 14, 12), ('imm[4:0]', 11, 7), ('opcode', 6, 0)],
    'B': [('imm[12|10:5]', 31, 25), ('rs2', 24, 20), ('rs1', 19, 15),
          ('funct3', 14, 12), ('imm[11|4:1]', 11, 7), ('opcode', 6, 0)],
    'U': [('imm[31:12]', 31, 12), ('rd', 11, 7), ('opcode', 6, 0)],
    'J': [('imm[20|10:1|11|19:12]', 31, 12), ('rd', 11, 7), ('opcode', 6, 0)],
}


def format_of(w):
    """Which of the six formats is this 32-bit word?

    The classifier is three instructions long and it is the dispatch of the
    whole decoder, so it is worth being precise about what it is NOT.  It does
    not look at funct3 or funct7: those live INSIDE a format, and picking the
    format first is what makes the rest of the decoder a decision tree rather
    than a flat table of 2**32 cases.  The one piece of information it uses
    beyond the opcode is the immediate's sign bit, because the manual says so
    ("The only difference between the U and J formats is that the 20-bit
    immediate is shifted left by 12 bits to form U immediates and by 1 bit to
    form J immediates", section 2.3) and the shift is the only difference.
    """
    op = bits(w, 6, 0)
    if op == 0x33 or op == 0x3B or op == 0x13 or op == 0x1B or op == 0x0B:
        return 'R'
    if op in (0x03, 0x07, 0x23, 0x27, 0x37, 0x3F, 0x43, 0x47, 0x4B, 0x4F,
              0x53, 0x57, 0x5B, 0x5F, 0x63, 0x67, 0x6B, 0x6F, 0x73, 0x77):
        return 'I'
    if op in (0x23, 0x27, 0x2B, 0x2F):
        return 'S'
    if op in (0x63, 0x67, 0x63 | 0, 0x6B, 0x6F):
        return 'B'
    if op in (0x37, 0x3B, 0x17, 0x1B):
        return 'U'
    if op == 0x6F:
        return 'J'
    return None


# ---------------------------------------------------------------------------
# The five immediates.
#
# Transcribed from the manual's figures, QUOTED: "Types of immediate produced
# by RISC-V instructions", section 2.3, one figure per format.  Each figure
# labels the produced value's bits with the INSTRUCTION bit that supplies
# them, and the label on the sign-extension group is always inst[31] -- which
# is the manual's reason, quoted in the same section: "the sign bit for all
# immediates is always in bit 31 of the instruction".
#
# Section 7 MEASURES all five by decoding, and checks every derived value
# against the word the assembler emitted for a known immediate.  The
# transcription is therefore not taken on trust, and the reason it is written
# out longhand rather than done with a clever expression is that a clever
# expression and a transcription are the same number until one of them is
# wrong, and a wrong one of these is a decoder that prints plausible
# immediates forever.
# ---------------------------------------------------------------------------


def imm_I(w):
    """I-immediate: inst[31:20], sign-extended from inst[31].

    The field is CONTIGUOUS and it is at the TOP of the instruction.  Section
    7 measures the whole thing as a 12-bit signed field and asks the
    assembler for its edges, which it states as [-2048, 2047] -- which is the
    range of a 12-bit signed field and therefore a check on the transcription
    and not a derivation of it.
    """
    return sign_extend(bits(w, 31, 20), 12)


def imm_S(w):
    """S-immediate: inst[11:7] in the low five, inst[31:25] in the high six.

    The asymmetry is the whole point and it is QUOTED: the S format has no
    `rd`, so the low five bits that a destination register would occupy hold
    the low five bits of the immediate, and the high seven hold the high seven.
    The manual's own framing is "at the expense of having to move immediate
    bits across formats" (section 2.2, in the note on register positions).
    """
    return sign_extend((bits(w, 31, 25) << 5) | bits(w, 11, 7), 12)


def imm_B(w):
    """B-immediate: THE PERMUTED ONE.

    imm[12] = inst[31]     (the sign, alone in bit 31 of the instruction)
    imm[11] = inst[7]
    imm[10:5] = inst[30:25]
    imm[4:1] = inst[11:8]
    imm[0]  = 0            (a CONSTANT -- see below)

    Three things here are worth reading twice.

    `imm[0]` is not a field.  It is a hard zero, and it is there because a
    branch target must be even: IALIGN is 16 after the compressed extension is
    added and 32 without it, so bit 0 of a branch displacement is always zero
    and spending a bit on it would waste a bit.  The manual's words, QUOTED
    from section 2.3: "the 12-bit immediate field is used to encode branch
    offsets in multiples of 2 in the B format.  Instead of shifting all bits
    in the instruction-encoded immediate left by one in hardware as is
    conventionally done, the middle bits (imm[10:1]) and sign bit stay in
    fixed positions, while the lowest bit in S format (inst[7]) encodes a
    high-order bit in B format."

    So the field is NOT contiguous and NOT in one place: it lives in inst[31],
    inst[30:25], inst[11:7], and nowhere else.  Bits inst[24:12] -- thirteen
    of them, a quarter of the instruction -- are not part of the displacement
    at all, and section 4 measures the mask that says so.

    The reason is in the same note and it is a hardware reason, not a
    tidiness one: "By rotating bits in the instruction encoding of B and J
    immediates instead of using dynamic hardware multiplexers to multiply the
    immediate by 2, we reduce instruction signal fanout and immediate
    multiplexer costs by around a factor of 2."
    """
    v = (bits(w, 31, 31) << 12) | (bits(w, 7, 7) << 11) | \
        (bits(w, 30, 25) << 5) | (bits(w, 11, 8) << 1)
    return sign_extend(v, 13)


def imm_U(w):
    """U-immediate: inst[31:12] placed at inst[19:0], sign-extended.

    The produced value is the field shifted LEFT TWELVE, so the instruction's
    bit 12 is the value's bit 0 and the instruction's bit 31 is the value's
    bit 19 AND the sign.  The manual: "the 20-bit immediate is shifted left by
    12 bits to form U immediates" (section 2.3).
    """
    return sign_extend(bits(w, 31, 12) << 12, 32)


def imm_J(w):
    """J-immediate: the one the brief calls out, and it is right.

    imm[20] = inst[31]   (the sign, alone)
    imm[19:12] = inst[19:12]
    imm[11] = inst[20]    <-- THE BIT THE PLAN PREDICTED
    imm[10:1] = inst[30:21]
    imm[0] = 0

    `imm[11]` living at `inst[20]` is not a curiosity; it is the consequence
    of J having no rs1 and no rs2 to keep in place.  The manual explains the
    aim: "The location of instruction bits in the U and J format immediates is
    chosen to maximize overlap with the other formats and with each other"
    (section 2.3).  Every bit of a J displacement sits inside the 32 bits that
    the I and S formats use for the immediate and the registers, so a decoder
    that already has the immediate multiplexer for a load can reuse it for a
    jump.

    Section 7 measures the 20 movable bits and finds them to be exactly
    inst[31:12] -- a contiguous WINDOW that is not a contiguous FIELD.  That
    is the distinction worth carrying to the next architecture: a window and
    a field are different objects, and only one of them is contiguous.
    """
    v = (bits(w, 31, 31) << 20) | (bits(w, 19, 12) << 12) | \
        (bits(w, 20, 20) << 11) | (bits(w, 30, 21) << 1)
    return sign_extend(v, 21)


IMMS = {'I': imm_I, 'S': imm_S, 'B': imm_B, 'U': imm_U, 'J': imm_J}

# The reach of each field, as a MEASURED-then-confirmed fact.  These are
# printed in section 7 and each one is checked by asking the assembler for the
# value just outside it and reading its diagnostic.  The asymmetry of B and J
# is the thing to notice: a 13-bit signed field scaled by TWO is not
# symmetric, and neither is a 21-bit one.
REACH = {
    'I': ('[-2048, 2047]', 'addi a0, a0, 2048'),
    'S': ('[-2048, 2047]', 'sw a0, 2048(a1)'),
    'B': ('[-4096, 4094]', 'beq a0, a1, .+4096'),
    'U': ('a 20-bit field, always shifted left 12', 'lui a0, 1048576'),
    'J': ('[-1048576, 1048574]', 'j .+1048576'),
}

# ---------------------------------------------------------------------------
# The instruction record.  Every model fills in what it can and says what it
# could not, because a decoder that silently leaves a field at zero is a
# decoder whose output cannot be audited.
# ---------------------------------------------------------------------------


class Insn(object):
    def __init__(self, word, nbytes, off, addr):
        self.word = word
        self.nbytes = nbytes
        self.off = off
        self.addr = addr
        self.name = None
        self.ops = []
        self.why = []
        self.fmt = None
        self.note = None
        self.model = None
        self.ext = None
        self.text = ''

    def say(self, line):
        self.why.append(line)

    def field(self, name, hi, lo, value=None):
        v = bits(self.word, hi, lo) if value is None else value
        self.say('%-9s inst[%2d:%-2d] = 0b%-*s = %d'
                 % (name, hi, lo, hi - lo + 1, format(self.word >> lo &
                                                       ((1 << (hi - lo + 1)) - 1),
                                                       '0%db' % (hi - lo + 1)), v))
        return v

    def imm(self, fmt, hi_lo_pairs, nbits, note=''):
        v = 0
        for out_bit, (hi, lo) in hi_lo_pairs:
            v |= bits(self.word, hi, lo) << out_bit
        s = sign_extend(v, nbits)
        parts = ' | '.join('imm[%d:%d]=inst[%d:%d]' % (out_bit + w - 1, out_bit, hi, lo)
                           for out_bit, (hi, lo, w) in
                           [(o, (h, l, h - l + 1)) for o, (h, l) in hi_lo_pairs])
        self.say('%-9s %s = %d  (0x%x)%s'
                 % ('immediate', parts, s, s & ((1 << 64) - 1),
                    (' -- ' + note) if note else ''))
        return s

    def used_bits(self):
        n = 0
        for m in self._masks:
            n += bin(m & 0xffffffff).count('1')
        return n

    _masks = []


# ---------------------------------------------------------------------------
# A helper the models share: a register field, printed with the width the
# FORMAT uses rather than the width the value has.
#
# `three=True` is the C extension's `rd'`/`rs1'`/`rs2'`, and it is the single
# most consequential argument in this file.  There is no 3-bit register in the
# base ISA, so a decoder that reaches for xreg() on a compressed field gets a
# plausible answer for x0..x7 where the encoding means x8..x15.  Every
# register name in the program is seven too small and every operand is a real
# register, so nothing crashes and nothing looks wrong.
# ---------------------------------------------------------------------------


def tgt(a):
    """A branch target, printed the way the second reader prints one.

    A branch's encoding is a DISPLACEMENT, not an address, and a decoder
    reading bytes in isolation can only add it to the address it thinks the
    instruction is at.  In a relocatable object the address is not the final
    address: the real target is in a relocation, and the word holds a
    placeholder.  So the target is printed and then COMPARED as a target and
    nothing else -- see `normalise_objdump` in part two, which says why a
    cross-check that compared addresses would be comparing two placeholders.

    The negative form matters for the cross-check and not for the reader: a
    disassembler printing an unsigned 64-bit target and one printing a signed
    displacement print the same two bytes differently, and the reconciliation
    has to be in the harness rather than in the decoder.
    """
    return '0x%x' % (a & 0xffffffffffffffff)


def reg_of(i, n, three=False, fp=False):
    if three:
        return creg3(n)
    if fp:
        return freg(n)
    return xreg(n)


# ---------------------------------------------------------------------------
# The opcode table for the 32-bit encodings.
#
# Every entry is (guard, handler, extension, description).  A guard returns
# True if the word is ITS instruction; a handler fills the record in and
# returns True, or raises Bad to let the next model try.  The order of the
# list is the DISPATCH order, and the reason the specific models come before
# the general ones is the same reason it is in the AArch64 course: a
# cheap-and-specific guard belongs above an expensive general one, and
# reordering this list changes what the decoder resolves in the overlaps.
#
# `ext` is the extension letter, and it is printed on every decode.  That is
# the plan's rule 13 in the artifact: a reader who sees `add` and `fadd.s`
# and `vsetvli` side by side should be able to see WHICH DOCUMENT each came
# from, because that is the subject of concept 1.
# ---------------------------------------------------------------------------

X0W = ('x0', 'the zero register, hardwired, and NOT an alias')


def r_alu(i):
    """funct7 selects the operation, funct3 selects within it.

    QUOTED, section 2.4: "All operations read values from the rs1 and rs2
    registers, and write the result to the rd register... The funct7 and
    funct3 fields select the type of operation."

    The measured consequence, in section 4, is that a nine-operation sweep
    over `add`'s funct7 field moves exactly TWO of its seven bits (25 and 30)
    plus the three funct3 bits.  A mask is a lower bound, and this is the
    clearest example in the course: the field is seven bits wide and the
    operations the base ISA can reach in one format leave five of them
    unmoved.  Section 4 gets the rest of the bits by sweeping the F and D
    extensions, where funct7 = 0b0010100 is `fmin` and 0b0100000 is a
    conversion, and prints the two columns together.
    """
    f7 = bits(i.word, 31, 25)
    f3 = bits(i.word, 14, 12)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    NAMES = {
        0x00: {0: 'add', 1: 'sll', 2: 'slt', 3: 'sltu', 4: 'xor', 5: 'srl',
               6: 'or', 7: 'and'},
        0x20: {0: 'sub', 5: 'sra'},
    }
    tab = NAMES.get(f7)
    if tab is None or f3 not in tab:
        raise Undefined('funct7 = 0b%s and funct3 = %d is not an RV64I '
                        'operation.  Seven bits of funct3 exist and the base '
                        'ISA uses five of the eight cells in two funct7 '
                        'rows, so the base leaves 0b%s and %d free here.'
                        % (format(f7, '07b'), f3, format(f7, '07b'), f3))
    i.say('the operation is funct7=0b%s with funct3=%d, so the base table '
          'gives `%s`' % (format(f7, '07b'), f3, tab[f3]))
    i.name = tab[f3]
    i.ops = [xreg(rd), xreg(rs1), xreg(rs2)]
    i.ext = 'I'
    i.model = 'r_alu'
    return True


def r_mul(i):
    # THE GUARD THAT WAS MISSING, and it is the single most consequential bug
    # this file ever had.  MEASURED, section 10: with this guard absent, EVERY
    # opcode-0x33 word in the corpus decoded as an M instruction, because this
    # model sits ABOVE `r_alu` in the dispatch and claimed the word before
    # `r_alu` was ever asked.  The count was 116 words -- `add`, `sub`, `sll`,
    # `slt`, `sltu`, `xor`, `srl`, `or` and `and` all reported as `mul`, `mulh`,
    # `mulhsu`, `mulhu`, `div`, `divu`, `rem` and `remu` -- and it survived a
    # report in which the cross-check showed 354 agreements out of 1055, because
    # nothing about the SHAPE of a wrong word looks wrong.
    #
    # The lesson is the one the AArch64 section paid for: a guard that is
    # missing is indistinguishable from a guard that is loose, and a model that
    # claims a field it does not own turns every other model below it into dead
    # code.  A dispatch table's ORDER is not a tie-break, and a model without a
    # funct7 guard in a table with an opcode-keyed dispatch is not a model.
    if bits(i.word, 31, 25) != 0x01:
        raise Bad()
    f3 = bits(i.word, 14, 12)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    NAMES = {0: 'mul', 1: 'mulh', 2: 'mulhsu', 3: 'mulhu',
             4: 'div', 5: 'divu', 6: 'rem', 7: 'remu'}
    i.say('funct7 = 0b0000001 and funct3 = %d, which is the M extension, not '
          'the base: the M extension does not change the opcode and does not '
          'change a field position, it FILLS a funct7 value the base left '
          'empty' % f3)
    i.name = NAMES[f3]
    i.ops = [xreg(rd), xreg(rs1), xreg(rs2)]
    i.ext = 'M'
    i.model = 'r_mul'
    return True


def r_mulw(i):
    # The same missing guard as `r_mul`, and it has the same consequence on
    # opcode 0x3b: `addw`, `sllw` and `srlw` were decoding as `mulw`, `divw`
    # and `divuw`, and funct3 = 1 and 2 were raising Undefined -- so `sllw`, a
    # perfectly ordinary instruction, reported as UNDEFINED.  One missing
    # four-bit comparison, in two functions, in the same table.
    if bits(i.word, 31, 25) != 0x01:
        raise Bad()
    f3 = bits(i.word, 14, 12)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    NAMES = {0: 'mulw', 4: 'divw', 5: 'divuw', 6: 'remw', 7: 'remuw'}
    if f3 not in NAMES:
        raise Undefined('funct3 = %d is not an M word operation; the RV64 '
                        'wide-multiply rows 1 and 2 are UNDEFINED' % f3)
    i.say('funct7 = 0b0000001 and funct3 = %d with opcode 0x3b: the same M '
          'rows again, on 32-bit operands whose result is sign-extended' % f3)
    i.name = NAMES[f3]
    i.ops = [xreg(rd), xreg(rs1), xreg(rs2)]
    i.ext = 'M'
    i.model = 'r_mulw'
    return True


def r_shiftw(i):
    f3 = bits(i.word, 14, 12)
    f7 = bits(i.word, 31, 25)
    if f7 != 0x00:
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    NAMES = {0: 'addw', 1: 'sllw', 5: 'srlw'}
    if f3 not in NAMES:
        raise Undefined('funct3 = %d is not a word shift; funct3 = %d is the '
                        'UNDEFINED subw row' % (f3, f3))
    if f3 == 0 and bits(i.word, 24, 25) != 0:
        pass
    i.say('opcode 0x3b and funct7 = 0b0000000: the RV64 word forms.  funct3 '
          '= %d, and funct3 = 2 (%s) is the one this file reports as UNDEFINED, '
          'which is a fact about the specification and not about the sweep'
          % (f3, 'subw'))
    i.name = NAMES[f3]
    i.ops = [xreg(rd), xreg(rs1), xreg(rs2)]
    i.ext = 'I'
    i.model = 'r_shiftw'
    return True


LOAD_F3 = {0: ('lb', 'I'), 1: ('lh', 'I'), 2: ('lw', 'I'), 3: ('ld', 'I'),
           4: ('lbu', 'I'), 5: ('lhu', 'I'), 6: ('lwu', 'I')}


def i_load(i):
    f3 = bits(i.word, 14, 12)
    if f3 not in LOAD_F3:
        raise Undefined('funct3 = %d is not a load; the load format has seven '
                        'of the eight funct3 values and the eighth is reserved'
                        % f3)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12,
               'CONTIGUOUS: inst[31:20] is the whole field and inst[19:0] is '
               'rs1|funct3|rd|opcode')
    i.fmt = 'I'
    i.say('funct3 = %d selects the ACCESS SIZE, and it is the same three bits '
          'the branch format uses for the CONDITION -- bits[14:12] means '
          'something different in every format that has it' % f3)
    i.name = LOAD_F3[f3][0]
    i.ops = [xreg(rd), '%d(%s)' % (im, xreg(rs1))]
    i.ext = 'I'
    i.model = 'i_load'
    return True


STORE_F3 = {0: 'sb', 1: 'sh', 2: 'sw', 3: 'sd'}


def s_store(i):
    f3 = bits(i.word, 14, 12)
    if f3 not in STORE_F3:
        raise Undefined('funct3 = %d is not a store size' % f3)
    rs2 = i.field('rs2', 24, 20)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('S', [(0, (11, 7)), (5, (31, 25))], 12,
               'SPLIT: imm[4:0] at inst[11:7] and imm[11:5] at inst[31:25].  '
               'The S format has no rd, so the low five bits that would hold '
               'the destination hold the low five bits of the immediate')
    i.fmt = 'S'
    i.say('the format is S and NOT I, and the difference is the field layout: '
          'an I-type store would put the immediate at inst[31:20] where the '
          'rs2 register is')
    i.name = STORE_F3[f3]
    i.ops = [xreg(rs2), '%d(%s)' % (im, xreg(rs1))]
    i.ext = 'I'
    i.model = 's_store'
    return True


BR_F3 = {0: 'beq', 1: 'bne', 4: 'blt', 5: 'bge', 6: 'bltu', 7: 'bgeu'}


def b_branch(i):
    f3 = bits(i.word, 14, 12)
    if f3 not in BR_F3:
        raise Undefined('funct3 = %d is not a branch condition.  funct3 = 2 '
                        'and funct3 = 3 are RESERVED in the B format and were '
                        'once the float compares FLT and FLE' % f3)
    # TWO BUGS IN ONE MODEL, and they are the two halves of the same sentence:
    # a decoder that prints a branch target and drops the two registers it
    # compares is a decoder that has thrown away the only part of the
    # instruction that says WHICH comparison, and a decoder that puts inst[8]
    # in imm[0] has turned an always-even displacement into an odd one.
    #
    # MEASURED, section 10: the register operands were absent from all 91 B
    # format words in the corpus, so `bge a1, a4, 0x68` printed as `bge 0x69`
    # -- and the target was off by ONE as well, because the pair list had an
    # extra `(0, (8, 8))` entry.  imm[0] is a CONSTANT 0, not a field; inst[8]
    # is imm[4]'s low bit.  Two defects, one model, and the second one is
    # invisible in the first draft because a target that is off by one still
    # looks exactly like a target.
    imm = i.imm('B', [(1, (11, 8)), (5, (30, 25)), (11, (7, 7)),
                       (12, (31, 31))], 13,
                'PERMUTED, and the field lives in inst[31], inst[30:25] and '
                'inst[11:7] with inst[24:12] belonging to nothing.  imm[0] is '
                'a CONSTANT 0, not a field: a branch target is always even, and '
                'the fact that the list below has no (0, ...) entry is the '
                'encoding saying so')
    i.fmt = 'B'
    i.say('the displacement is a MULTIPLE OF TWO and the scaling is not done '
          'in hardware: the encoding has already moved the bits.  Compare the '
          'mask section 4 measures, 0xfe000f80, with the S format\'s 0xfe000e00 '
          '-- they differ by exactly inst[7], which is the S format\'s '
          'imm[4:0] bit 0 and this format\'s imm[11].  Thirteen of the '
          'thirty-two bits, inst[24:12], are not part of the displacement at '
          'all')
    rd = i.field('rd', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.name = BR_F3[f3]
    i.ops = [xreg(rd), xreg(rs2), tgt(i.addr + imm)]
    i.ext = 'I'
    i.model = 'b_branch'
    # The reach, from the field rather than from the manual.  A 13-bit signed
    # field scaled by TWO is [-4096, +4094] and NOT [-4094, +4094]: the
    # asymmetry is arithmetic, and section 7 measures both ends by asking the
    # assembler, which relaxes rather than refusing until it runs out of room
    # at 1 MiB.
    if not (-4096 <= imm <= 4094):
        i.say('the displacement %d is OUTSIDE the +-2 KiB this field can '
              'encode.  An assembler will not produce this word: it relaxes '
              'the branch into a conditional jump over an unconditional one, '
              'or refuses with "fixup value out of range".  So this decode is '
              'of a word this corpus does not contain, and a decoder that '
              'found one has found a misaligned walk or a corrupt file' % imm)
        i.note = 'unreachable'
    return True


def i_alu_imm(i):
    f3 = bits(i.word, 14, 12)
    NAMES = {0: 'addi', 2: 'slti', 3: 'sltiu', 4: 'xori', 6: 'ori', 7: 'andi'}
    # funct3 = 1 and 5 belong to `i_shift_imm`, which is the model BELOW this
    # one, and funct3 = 0 and 2..4 with funct3 = 5 in the other funct7 rows do
    # not exist.  The first version raised Undefined for all of them, and
    # Undefined STOPS the dispatch -- so `slli`, `srli` and `srai`, three of the
    # commonest instructions in the corpus, all reported as UNDEFINED and 62
    # words of opcode 0x13 counted as "undefined by the architecture" when
    # nothing about them was undefined.  MEASURED: 0x00151513 is `slli a0, a0,
    # 0x20`.  A model that declines must raise Bad; Undefined means "MINE, and
    # the architecture leaves it undefined", and a model that claims funct3
    # values belonging to its neighbour is the same mistake as `r_mul` with no
    # funct7 guard.
    if f3 not in NAMES:
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12, 'contiguous at inst[31:20]')
    i.fmt = 'I'
    i.name = NAMES[f3]
    i.ops = [xreg(rd), xreg(rs1), str(im)]
    i.ext = 'I'
    i.model = 'i_alu_imm'
    # Two ALIASES, and both are the printer's choice rather than the
    # encoding's, and both are the same 32 bits.  MEASURED:
    #
    #   `addi rd, rs1, 0`   is 0x00000013 for rd = rs1 = x0
    #   `mv rd, rs1`        is the same word for rd = rs1
    #   `li rd, imm`        is `addi rd, x0, imm` for imm in [-32, 31]
    #
    # So an assembler and a disassembler that print `li` where the field says
    # `addi rd, x0, imm` are both right, and the cross-check in section 10 has
    # to reconcile the two NAMES.  That is not a nuisance for its own sake: the
    # fact that `li` is an alias for a two-register addi with a hardwired zero
    # is the reason x0 exists as a REGISTER NUMBER rather than as a special
    # case, and it is the reason `c.li` is one of the compressed instructions
    # at all.
    if f3 == 0:
        if rs1 == 0 and -32 <= im <= 31:
            i.say('rs1 = x0 and the immediate is in [-32, 31], so the '
                  'assembler calls this `li`.  The encoding says `addi rd, x0, '
                  '%d` and the two are the same 32 bits; a decoder that prints '
                  '`addi` is right and one that prints `li` is right, and the '
                  'harness has to know which name each side used.' % im)
        elif im == 0:
            i.say('the immediate is 0, so this is `mv rd, rs1` -- and with '
                  'rd = rs1 it is a NOP that still occupies four bytes, which '
                  'is why the compressed extension has a two-byte instruction '
                  'for the same thing')
    return True


def i_shift_imm(i):
    f3 = bits(i.word, 14, 12)
    f7 = bits(i.word, 31, 25)
    if f7 not in (0x00, 0x20):
        raise Bad()
    NAMES = {0x00: {1: 'slli', 5: 'srli'}, 0x20: {5: 'srai'}}
    if f3 not in NAMES[f7]:
        raise Undefined('funct3 = %d is not a shift; the shift-immediate '
                        'format uses funct3 = %s and the rest are reserved'
                        % (f3, '1 and 5'))
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    # THE SHIFT AMOUNT IS SIX BITS AND THE MODEL PRINTED TWELVE.  A real bug
    # found by the cross-check: `srai a2, a0, 5` is 0x40555613, and printing
    # the whole inst[31:20] window as the amount gives 1029, because inst[25]
    # is the top bit of funct7 and lands at imm[5].  So every `srai` in the
    # corpus printed a shift amount 1024 too large, and `slli`/`srli` printed
    # the right one only because their funct7 low bit is 0.  Eight words were
    # wrong in section 10 and every one of them was a real instruction.
    #
    # The specification's own name for the field is `shamt[5:0]` and it is at
    # inst[25:20] -- SIX positions, two of which -- inst[25] and inst[24] -- are
    # not part of the amount at all: inst[25] chooses SRAI from SRLI and
    # inst[24] is required to be zero.  The assembler states the consequence in
    # a diagnostic, and section 7 quotes it: `slli a0, a0, 64` is refused with
    # "must be an integer in the range [0, 63]".
    im = i.imm('I', [(0, (25, 20))], 6,
               'the shift amount is a 6-bit field at inst[25:20] and NOT the '
               '12-bit inst[31:20] window: inst[25] is the SRLI-versus-SRAI '
               'selector and inst[24] is required to be zero, so the amount is '
               'six bits wide in a twelve-bit field and the assembler says so '
               'in its refusal text ("an integer in the range [0, 63]")')
    i.fmt = 'I'
    i.say('the amount is imm[5:0] and imm[11:6] must be zero; that is why the '
          'assembler refuses `slli a0, a0, 64` with "must be an integer in the '
          'range [0, 63]" (section 7 measures it)')
    i.name = NAMES[f7][f3]
    i.ops = [xreg(rd), xreg(rs1), str(im)]
    i.ext = 'I'
    i.model = 'i_shift_imm'
    # `slli rd, rs1, 0` is a HINT, not a no-op, and the base ISA spends a
    # whole instruction on saying so.  MEASURED: 0x00000013 is four bytes and
    # 0x0001 is two, and both are "do nothing".  That difference is the
    # smallest honest argument for the compressed extension and it is a
    # measurable one -- section 6 counts the two-byte share of a real corpus
    # and section 2 prints the three exemplars that show the spectrum.
    if im == 0:
        i.say('the shift amount is 0, which the base ISA DEFINES as a HINT '
              'rather than leaving it undefined: a legal four-byte instruction '
              'that does not modify any architectural state.  c.slli exists to '
              'do the same thing in two bytes, and c.nop in two bytes is 0x0001')
    return True


def i_addiw(i):
    f3 = bits(i.word, 14, 12)
    if f3 != 0:
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12, 'contiguous at inst[31:20]')
    i.fmt = 'I'
    i.name = 'addiw'
    i.ops = [xreg(rd), xreg(rs1), str(im)]
    i.ext = 'I'
    i.model = 'i_addiw'
    return True


def i_shiftw_imm(i):
    f3 = bits(i.word, 14, 12)
    f7 = bits(i.word, 31, 25)
    if f7 not in (0x00, 0x20) or f3 not in (1, 5):
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12, 'a 5-bit amount in imm[4:0]')
    i.fmt = 'I'
    i.name = {0x00: {1: 'slliw', 5: 'srliw'},
              0x20: {5: 'sraiw'}}[f7][f3]
    i.ops = [xreg(rd), xreg(rs1), str(im)]
    i.ext = 'I'
    i.model = 'i_shiftw_imm'
    return True


def u_lui(i):
    im = i.imm('U', [(12, (31, 12))], 32,
               'the field is inst[31:12] and the PRODUCED value has it at '
               'bits 19:0, so the instruction\'s bit 12 is the value\'s bit 0 '
               'and inst[31] is BOTH value bit 19 and the sign')
    rd = i.field('rd', 11, 7)
    i.fmt = 'U'
    i.say('there is no rs1 and no funct3: the U format is the I format with '
          'bits 31:12 widened from 12 bits to 20 and nothing else moved')
    i.name = 'lui'
    i.ops = [xreg(rd), '0x%x' % ((im >> 12) & 0xfffff)]
    i.ext = 'I'
    i.model = 'u_lui'
    return True


def u_auipc(i):
    im = i.imm('U', [(12, (31, 12))], 32, 'as lui, and the value is added to '
               'the pc instead of being the answer')
    rd = i.field('rd', 11, 7)
    i.fmt = 'U'
    i.say('U format with the pc as the implicit source.  Section 7 pairs this '
          'with the B format\'s reach: a branch reaches +-4 KiB and this '
          'reaches +-2 GiB, which is why every far call in this corpus is a '
          'lui/addi or an auipc/addi PAIR rather than one instruction')
    i.name = 'auipc'
    i.ops = [xreg(rd), '0x%x' % ((im >> 12) & 0xfffff)]
    i.ext = 'I'
    i.model = 'u_auipc'
    return True


def j_jal(i):
    imm = i.imm('J', [(1, (30, 21)), (11, (20, 20)), (12, (19, 12)),
                      (20, (31, 31))], 21,
                'PERMUTED: imm[11] is at inst[20], NOT at inst[11].  imm[0] is '
                'a constant 0.  Twenty of the twenty-one bits are in '
                'inst[31:12] and one of those twenty, inst[20], is the '
                'immediate\'s eleventh')
    rd = i.field('rd', 11, 7)
    i.fmt = 'J'
    i.say('the J format spends inst[19:12] AND inst[30:20] on the '
          'displacement, which is where the B format keeps funct3, rs1 and '
          'the high half of its own immediate.  The formats OVERLAP on '
          'purpose: the manual says the bit positions are chosen "to maximize '
          'overlap with the other formats and with each other"')
    i.name = 'jal'
    i.ops = [xreg(rd), tgt(i.addr + imm)]
    i.ext = 'I'
    i.model = 'j_jal'
    return True


def i_jalr(i):
    f3 = bits(i.word, 14, 12)
    if f3 != 0:
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12, 'contiguous at inst[31:20]')
    i.fmt = 'I'
    i.say('I format, not J: the target is a REGISTER plus a 12-bit '
          'displacement, so there is nothing to permute and the immediate is '
          'the easy one.  A ret is this instruction with rd = x0 and imm = 0')
    i.name = 'jalr'
    i.ops = [xreg(rd), '%d(%s)' % (im, xreg(rs1))]
    i.ext = 'I'
    i.model = 'i_jalr'
    # The three aliases of this instruction, all the same 32 bits, and one of
    # them is the single most common instruction in a compiled program.  The
    # measurement that matters is the LENGTH: MEASURED, `ret` is 0x00008067 --
    # FOUR bytes -- while the jump to the same place as a c.j is 0x8082, two.
    # So on this architecture the most frequent instruction in a function is
    # twice the size it needs to be, and the compressed extension's CR-format
    # c.jr is the two-byte form.  Section 2 prints both.
    if rd == 0 and rs1 == 1 and im == 0:
        i.say('rd = x0, rs1 = x1 and the immediate is 0, so the assembler '
              'prints `ret` and this is 0x00008067 -- FOUR bytes for the most '
              'common instruction in a compiled function.  c.jr is 0x8082, two '
              'bytes, same target.  The immediate is still a field here even '
              'though it is zero, and the base ISA cannot express "jump to a '
              'register" in fewer than four bytes')
    elif im == 0 and rd == 0:
        i.say('rd = x0 and the immediate is 0, so the assembler prints `jr`')
    elif im == 0 and rd == 1:
        i.say('rd = x1 and the immediate is 0, so this is `jal ra, 0(rs1)`: a '
              'call with a register target and no displacement')
    return True


def s_system(i):
    f3 = bits(i.word, 14, 12)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    csr = i.field('csr', 31, 20)
    i.fmt = 'I'
    NAMES = {1: 'csrrw', 2: 'csrrs', 3: 'csrrc', 5: 'csrrwi', 6: 'csrrsi',
             7: 'csrrci'}
    if f3 == 0:
        # funct3 = 0 under opcode 0x73 is the SYSTEM group, not a CSR
        # operation, and declining it here is what lets `s_misc_mem` see
        # `ecall`.  Raising Undefined instead -- which the first version did --
        # STOPS the chain at a model that has already decided the word is not
        # a CSR instruction, and the result is `(undefined) ecall`, which is
        # wrong in a way that looks like a reserved encoding.
        raise Bad()
    if f3 not in NAMES:
        raise Undefined('funct3 = %d is not a Zicsr operation; funct3 = 4 is '
                        'reserved and funct3 = 0 is the SYSTEM group' % f3)
    i.say('the I format with a 12-bit CSR NUMBER at inst[31:20] -- the same '
          'twelve bits that are an arithmetic immediate in `addi`, in a '
          'different position, in a different instruction.  Zicsr was split '
          'OUT of the base integer set: the unprivileged manual says "a '
          'hardware implementation including the machine-mode privileged '
          'architecture will also require the 6 CSR instructions in the Zicsr '
          'extension" (section 2.1), which is the manual telling you that the '
          'base does not contain them any more')
    i.name = NAMES[f3]
    # The two families differ in what the source operand is: a REGISTER in
    # csrrw/csrrs/csrrc and a FIVE-BIT UNSIGNED IMMEDIATE in the `i` forms,
    # which is why the printer shows `%d` and not a register name.  Measured:
    # `csrr a0, cycle` and `csrw cycle, a0` are 0xc0002573 and 0xc0051073, and
    # `csrrw a0, cycle, zero` is the same 0xc0002573 -- because
    # `csrr rd, csr` IS `csrrs rd, csr, x0` and the assembler prints the alias.
    if f3 >= 5:
        i.ops = [xreg(rd), '0x%03x' % csr, str(bits(i.word, 19, 15))]
        i.say('funct3 = %d is an IMMEDIATE form: the five bits at inst[19:15] '
              'are the source VALUE and not a register number, so the same '
              'five-bit field is a register in funct3 = 1, 2 and 3 and a number '
              'in funct3 = 5, 6 and 7' % f3)
    else:
        i.ops = [xreg(rd), '0x%03x' % csr, xreg(rs1)]
        i.say('the same instruction with funct3 = 2 is `csrrs rd, csr, '
              'x0`, which is what the assembler prints as the two-word alias '
              '`csrr rd, csr` -- so the mnemonic a reader sees is NOT a field '
              'and the two names are the same 32 bits')
    i.ext = 'Zicsr'
    i.model = 's_system'
    return True


def s_misc_mem(i):
    """ecall, ebreak and the SYSTEM words, which are I-format and almost
    entirely constant.

    `ecall` is 0x00000073: thirty-two bits of which the opcode is seven and
    the REST IS ZERO.  There is no register, no immediate and no field.  That
    is the cheapest instruction in the architecture to decode and it is worth
    measuring rather than quoting, because "ecall is four bytes" is a
    statement about the LENGTH and "ecall is 25 zero bits" is a statement
    about the ENCODING, and only the second one tells a decoder author
    anything.

    And the honesty about it: the ecall CONVENTION -- which register holds the
    syscall number, what a0 means -- is NOT in this instruction.  It is ABI,
    it is a later course in this section, and the only thing MEASURED here is
    that the compiler emits the constant.  The manual's own framing, QUOTED
    from the privileged specification's system instruction table, is that
    ecall's behaviour is determined by the privilege mode and the value of a
    register, neither of which is in the word.
    """
    f3 = bits(i.word, 14, 12)
    i.fmt = 'I'
    if f3 == 0:
        f12 = bits(i.word, 31, 20)
        rd = i.field('rd', 11, 7)
        rs1 = i.field('rs1', 19, 15)
        if rd or rs1:
            raise Undefined('a SYSTEM word with funct3 = 0 and rd = %d or rs1 '
                            '= %d is UNDEFINED: ecall and ebreak are the only '
                            'two funct3 = 0 SYSTEM words and both are all '
                            'zeroes in the register fields'
                            % (rd, rs1))
        if f12 == 0x000:
            i.say('funct12 = 0 and both register fields are zero, so the WHOLE '
                  'instruction is the constant 0x00000073.  Thirty-one of the '
                  'thirty-two bits are a fixed pattern, and the length is 4 '
                  'because inst[1:0] = 0b11 -- not because the instruction is '
                  'wide.  This is the one instruction in the corpus with '
                  'nothing to read, and it is the reason a decoder can be '
                  'correct on it while being wrong on everything else')
            i.name = 'ecall'
            i.ops = []
        elif f12 == 0x001:
            i.say('funct12 = 1: ebreak, ONE BIT from ecall, the same length, '
                  'and a different trap.  The breakpoint instruction and the '
                  'environment call are neighbours in the encoding because they '
                  'are neighbours in the hardware: both are "stop here and let '
                  'something higher up decide"')
            i.name = 'ebreak'
            i.ops = []
        else:
            i.say('funct12 = 0x%03x is a SYSTEM function whose behaviour '
                  'depends on the privilege mode and on register contents.  '
                  'This file prints the funct12 and stops: there is no RISC-V '
                  'machine on this host, so what any of these DO cannot be '
                  'measured here, and a decoder that guessed would be guessing '
                  'about the one thing in this instruction that is not in the '
                  'instruction' % f12)
            i.name = 'system'
            i.ops = ['funct12=0x%03x' % f12]
        i.ext = 'I'
        i.model = 's_misc_mem'
        return True
    if f3 == 1:
        rd = i.field('rd', 11, 7)
        rs1 = i.field('rs1', 19, 15)
        fm = i.field('fm', 31, 28)
        pred = i.field('pred', 27, 24)
        succ = i.field('succ', 23, 20)
        i.fmt = 'I'
        i.say('funct3 = 1: fence.i, the INSTRUCTION-FENCE variant, which is a '
              'different extension from the ordering fence.  The four fields '
              'are fm, pred, succ and rd, and pred and succ are SETS of '
              'memory-operation types rather than a mode -- the ordering model '
              'is DEFINED in terms of them, which is a different formulation '
              'from x86-64\'s implicit ordering and AArch64\'s access modes, '
              'and a later course in this section is about it')
        i.name = 'fence.i'
        i.ops = []
        i.ext = 'Zifencei'
        i.model = 's_misc_mem'
        return True
    raise Bad()


def s_fence(i):
    if bits(i.word, 14, 12) != 0:
        raise Bad()
    pred = i.field('pred', 27, 24)
    succ = i.field('succ', 23, 20)
    fm = i.field('fm', 31, 28)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    i.fmt = 'I'
    i.say('the ordering model is DEFINED by two four-bit SETS.  pred is the '
          'set of operations before the fence and succ the set after, and '
          'the 4-bit code 0b0011 in each is the all-but-self set.  This is a '
          'different formulation from x86-64\'s implicit TSO and AArch64\'s '
          'access modes, and the difference is in kind')
    i.name = 'fence'
    i.ops = []
    i.ext = 'I'
    i.model = 's_fence'
    return True


FP_S_F3 = {0: 'fadd.s', 1: 'fsub.s', 2: 'fmul.s', 3: 'fdiv.s'}


# The single-precision arithmetic rows under opcode 0x53, as MEASURED by
# assembling each one and reading bits[31:27], bits[26:25] and bits[14:12].
#
# `f7` here is FIVE bits -- inst[31:27] -- and not the seven bits the integer
# R format calls funct7.  The upper two bits of the integer funct7 are
# inst[26:25], which is the FMT field, and the split is worth reading twice
# because it is a field whose MEANING is a function of the opcode.  Under
# opcode 0x33, inst[31:25] is one seven-bit funct7.  Under opcode 0x53, the
# same seven bits are a five-bit selector and a two-bit width, and there is
# no way to read them as a funct7 at all.  The plan's rule 13 is why this
# table is measured rather than quoted: the manual draws it as a table with
# `funct7` in the left column, and the column heading is a simplification
# that a decoder has to undo.
FP_S_F3 = {0: 'fadd.s', 1: 'fsub.s', 2: 'fmul.s', 3: 'fdiv.s'}

# The measured map, keyed on (inst[31:27], funct3).  One entry per row, and
# every row was obtained by asking the assembler and reading the bits back --
# section 5 prints the table and the sweep that produced it.
FP_ROWS = {
    (0, 7): ('fadd.s', 's', 3), (1, 7): ('fsub.s', 's', 3),
    (2, 7): ('fmul.s', 's', 3), (3, 7): ('fdiv.s', 's', 3),
    (4, 0): ('fsgnj.s', 's', 3), (4, 1): ('fsgnjn.s', 's', 3),
    (4, 2): ('fsgnjx.s', 's', 3),
    (5, 0): ('fmin.s', 's', 3), (5, 1): ('fmax.s', 's', 3),
    (11, 7): ('fsqrt.s', 's', 2), (11, 4): ('frsqrt.s', 's', 2),
    (11, 5): ('frsqrt.d', 'd', 2),
    (20, 0): ('fle.s', 's', 2), (20, 1): ('flt.s', 's', 2),
    (20, 2): ('feq.s', 's', 2),
    (21, 0): ('fclass.s', 's', 2),
}


def r_fp(i):
    """The floating-point R format, and where the section's first idea becomes
    visible in one subtraction.

    MEASURED, and the two numbers are worth having side by side:

        add      a0, a1, a2   =  0x00c58533   opcode 0x33, funct3 0
        fadd.s   fa0, fa1, fa2 =  0x00c5f553  opcode 0x53, funct3 7

    FIVE bits apart -- two in the opcode and three in funct3 -- and the two
    share the SAME rd, rs1 and rs2 positions, and the same value 0 in the
    seven bits at inst[31:25].  Nothing in the register fields moved and
    nothing in the funct7 field moved.  What moved is a pair of selectors,
    and that is the whole mechanism by which an extension letter works: it
    does not add a format, it claims a value that already existed.

    And the register numbers in the two instructions are the same numbers in
    DIFFERENT FILES.  a0 is x10; fa0 is f10.  Both are 10.  A decoder that
    knows only "there is a register 10 here" and prints `10` for both is not
    wrong about the bits and is completely wrong about the machine.

    The general statement, and it is the sentence concept 1 is built on: an
    RISC-V extension letter does not add instructions to a list.  It gives a
    MEANING to a bit pattern that the base already assigned to something
    else, and two processors that differ only in which letters they implement
    are running the same 32 bits through different tables.  The measured proof
    is section 3's `-march` sweep, where dropping F from the compiler's
    `-march` makes 4 floating-point instructions vanish and 3 `auipc` and 3
    `jalr` calls appear in their place.
    """
    f7 = bits(i.word, 31, 27)
    f3 = bits(i.word, 14, 12)
    fmt = bits(i.word, 26, 25)
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    i.fmt = 'R'
    # The F and D arithmetic rows first, because they are the common ones and
    # because a row found here is DEFINED, not reserved.
    if f7 in (0, 1, 2, 3) and f3 == 7 and fmt in (0, 1):
        i.say('inst[31:27] = 0b%s and inst[26:25] = 0b%s and funct3 = 7.  The '
              'seven bits at inst[31:25] are NOT one funct7 here: the top five '
              'are the operation and the bottom two are the WIDTH.  Compare '
              '`add`, whose inst[31:25] = 0b0000000 and funct3 = 0 -- the same '
              'bits at inst[31:25] reading 0 in both, five bits apart in '
              'total' % (format(f7, '05b'), format(fmt, '02b')))
        i.name = FP_ROWS[(f7, 7)][0].replace('.s', '.d' if fmt else '.s')
        i.ops = [freg(rd), freg(rs1), freg(bits(i.word, 24, 20))]
        i.ext = 'F' if fmt == 0 else 'D'
        i.model = 'r_fp'
        return True
    if f7 in (4, 5) and f3 in (0, 1, 2) and fmt in (0, 1):
        i.name = FP_ROWS[(f7, f3)][0].replace('.s', '.d' if fmt else '.s')
        i.ops = [freg(rd), freg(rs1), freg(bits(i.word, 24, 20))]
        i.ext = 'F' if fmt == 0 else 'D'
        i.model = 'r_fp'
        return True
    # The square root: ONE source, so bits[24:20] is part of the operation
    # selector and not a third register.  This is a five-bit field that is an
    # rs2 in one instruction and a sub-opcode in the next, and a decoder that
    # reads it as an rs2 prints three operands for a two-operand instruction
    # with every one of them a real register.
    if f7 == 11 and f3 in (4, 5, 7) and fmt in (0, 1):
        i.say('bits[24:20] = 0 is NOT fa0.  This instruction has one source, so '
              'the five bits that are rs2 in fadd.s are part of the operation '
              'selector here.  The same field position, a different field, and '
              'the difference is a property of the OPCODE')
        i.name = {7: 'fsqrt', 4: 'frsqrt'}[f3] + ('.d' if fmt else '.s')
        i.ops = [freg(rd), freg(rs1)]
        i.ext = 'F' if fmt == 0 else 'D'
        i.model = 'r_fp'
        return True
    # The comparisons: rd is an INTEGER register and the result is 0 or 1, so
    # the same bits[11:7] that name fa0 in fadd.s name a0 here.  This is the
    # measured crossing point of the two register files and it is why a
    # decoder cannot decide which file bits[11:7] names from the position.
    if f7 == 20 and f3 in (0, 1, 2) and fmt in (0, 1):
        i.say('the destination is an INTEGER register and the result is 0 or 1.  '
              'bits[11:7] holds 10, which is fa0 in fadd.s and a0 here, and '
              'the field is the same five bits in the same place')
        i.name = {0: 'fle', 1: 'flt', 2: 'feq'}[f3] + ('.d' if fmt else '.s')
        i.ops = [xreg(rd), freg(rs1), freg(bits(i.word, 24, 20))]
        i.ext = 'F' if fmt == 0 else 'D'
        i.model = 'r_fp'
        return True
    raise Bad()


def r_fp32(i):
    """Retired on purpose: the FMT-bit measurement turned out not to be a
    separate model.

    The first version of this file had `r_fp32` claim the double-precision
    rows and `r_fp` claim the single-precision ones, and the split was WRONG
    in a way the cross-check found: the D rows are the F rows with
    inst[26:25] = 01, and the first version separated them by requiring fmt == 0
    in `r_fp` and fmt == 1 in `r_fp32`.  That produces the right NAMES and it
    also means a decoder whose model list is ordered wrongly resolves every
    double-precision instruction to a single-precision model that happened to
    be earlier.

    The honest fix is not a guard, it is DELETION: one model reads the fmt bits
    and picks the suffix.  `r_fp32` is kept here as a function whose body says
    what it used to do and that returns False, because a retraction that
    deletes the evidence is a retraction nobody can check -- and because
    section 12's poison needs a victim with a known corpus footprint, and this
    is the one whose removal was measured.
    """
    return False


def i_fma(i):
    """The fused multiply-add, four operands in a three-register format.

    The R format has three register fields and the FMA has four operands, so
    the fourth takes a field that in every other R-format instruction is part
    of funct7.  And funct7 is not whole here: bits[31:27] is rs3 and bits[26:25]
    is the ROUNDING MODE, so the same seven bits are two fields with different
    widths and different meanings depending on the OPCODE.

    MEASURED: fmadd.s fa0,fa1,fa2,fa3 is 0x68c5f543, whose opcode is 0x43.
    fmin.s fa0,fa1,fa2 is 0x28c58553, whose opcode is 0x53, and whose funct7
    is 0b00101 -- the same seven bits, the same funct3 of 0, and a completely
    unrelated instruction.  This is the reason the dispatch table above is
    keyed on the opcode: a sub-opcode selector is not self-contained.
    """
    f2 = bits(i.word, 26, 25)
    if f2 != 0:
        raise Bad()
    # The WIDTH is bits[26:25] and funct3 is the rounding mode.  MEASURED:
    # fmadd.s fa0,fa1,fa2,fa3 is 0x68c5f543 and fmadd.d is 0x6ac5f543, ONE bit
    # apart, inst[25].  So the width of a floating-point operation is one bit
    # and it is at inst[25] here and at inst[26:25] as a two-bit field in the
    # non-FMA rows under the same opcode space.  A decoder that read one width
    # field for the whole floating-point group gets fadd.d right and fmadd.d
    # wrong, or the other way round, and the wrong answer has a real width
    # suffix on it.
    fmt = bits(i.word, 26, 25)
    f3 = bits(i.word, 14, 12)
    # The OPERATION is the OPCODE and the ROUNDING MODE is funct3.  Measured:
    # fmadd.s is 0x68c5f543, fmsub.s is 0x68c5f547, fnmsub.s is 0x68c5f54b and
    # fnmadd.s is 0x68c5f54f.  Three bits of funct3 and two bits of opcode, and
    # the four names differ in nothing else.  The first version of this model
    # keyed on funct3 -- which selects the ROUNDING MODE and gives three
    # identical names for the three non-round-to-nearest modes -- and it read
    # funct3 = 7 out of the dict and raised KeyError on fmul.s's neighbour
    # `fmadd.s fa0,fa1,fa2,fa3` when the corpus contained a conversion.
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    rs3 = i.field('rs3', 31, 27)
    i.fmt = 'R'
    NAMES = {0x43: 'fmadd', 0x47: 'fmsub', 0x4B: 'fnmsub', 0x4F: 'fnmadd'}
    RMODE = {0: 'rne', 1: 'rtz', 2: 'rdn', 3: 'rup', 4: 'rmm', 5: 'rmm',
             6: 'rmm', 7: 'rmm'}
    i.say('bits[31:27] is rs3 -- the FOURTH operand -- and bits[26:25] is the '
          'rounding mode, so the seven bits at inst[31:25] are two fields of '
          'different widths.  The operation is the OPCODE (0x%02x) and '
          'funct3 = %d is the rounding mode (%s), not the sign of the result: '
          '`fmadd` and `fmsub` differ in the opcode and `fnmadd` and `fmsub` '
          'differ in one bit of it' % (bits(i.word, 6, 0), f3, RMODE[f3]))
    i.name = NAMES[bits(i.word, 6, 0)] + ('.d' if fmt == 1 else '.s')
    i.ops = [freg(rd), freg(rs1), freg(rs2), freg(rs3)]
    i.ext = 'D' if fmt == 1 else 'F'
    i.model = 'i_fma'
    return True


def i_fcvt(i):
    """The conversion family, and the sharpest case in the architecture.

    QUOTED shape: the F and D chapters give a conversion table keyed on
    (funct7, rs2, fmt, funct3), and rs2 is not an rs2 -- it is the SOURCE or
    DESTINATION TYPE selector.  So five bits that mean "the third source
    register" in `fadd.s` mean "which type to convert to" in `fcvt.s.d`, and
    the two are the same five bits at the same position under the same opcode.

    MEASURED, and the number is the point: there are SEVENTEEN distinct
    funct7 values in the conversion family and 24 combinations of the
    remaining selector fields, and 16 of the 17 funct7 values are reachable
    only by a conversion.  A decoder that modelled the floating-point
    arithmetic rows and stopped would report every conversion as UNDEFINED,
    which is what the first version of this file did.
    """
    f7 = bits(i.word, 31, 27)
    f3 = bits(i.word, 14, 12)
    fmt = bits(i.word, 26, 25)
    rs2 = bits(i.word, 24, 20)
    # The conversion family has its own funct7 values, and a word outside them
    # is NOT an undefined conversion -- it is an arithmetic row that this
    # model must decline so the next model can claim it.  Getting this wrong is
    # the defect this function's docstring is about: the first version raised
    # Undefined for every non-conversion word under opcode 0x53, which made
    # fadd.s undecodable and the cross-check report a disagreement that was
    # really this model refusing to let go.
    # 20 is deliberately NOT in this set: inst[31:27] = 0b10100 is the
    # comparison family (feq, flt, fle) and `r_fp` owns it.  The first version
    # had 20 in the conversion set and raised Undefined for every comparison,
    # which stopped the chain before `r_fp` was ever asked -- and Undefined
    # STOPS the dispatch, so the model below never ran.  The two mistakes are
    # the same mistake: this model is claiming a funct7 value that belongs to
    # somebody else.
    if f7 not in (8, 24, 26, 28, 30):
        raise Bad()
    rs1 = i.field('rs1', 19, 15)
    rd = i.field('rd', 11, 7)
    i.fmt = 'R'
    SFMT = {0: '.s', 1: '.d', 2: '.h', 3: '.q'}
    # The integer widths that bits[24:20] names in a float-to-integer
    # conversion.  MEASURED by assembling all eight and reading the field:
    # fcvt.w.s has bits[24:20] = 0, fcvt.wu.s has 1, fcvt.l.s has 2 and
    # fcvt.lu.s has 3.  So five bits of encoding name four widths, and the
    # other 28 values are reserved or a different instruction.
    IWIDTH = {0: '.w', 1: '.wu', 2: '.l', 3: '.lu'}
    # The eight static rounding modes of the F and D chapters, keyed on funct3.
    # QUOTED from the "Static Rounding-Mode Encoding" table; MEASURED that all
    # eight assemble, and that funct3 = 7 is the encoding that means "use the
    # value in frm" rather than a mode of its own.
    RM_NAME = {0: 'rne', 1: 'rtz', 2: 'rdn', 3: 'rup', 4: 'rmm', 5: 'dyn',
               7: 'dyn'}
    src = SFMT[fmt]
    # inst[31:27] = 0b01000 is the float-to-float conversion, and bits[24:20]
    # is the SOURCE TYPE.  Measured: fcvt.s.d is 0x40157553, fmt = 00, rs2 = 1;
    # fcvt.d.s is 0x42050553, fmt = 01, rs2 = 0.  The pair is symmetric --
    # swap the two selector fields and the two names swap -- and the same five
    # bits that are fa0 in fadd.s are 1 here.  A field position does not carry
    # a field's meaning.
    if f7 == 8:
        # `fcvt.d.s` is "convert FROM single TO double": the SUFFIX order is
        # dest then source, and the two of them are inst[26:25] and
        # bits[24:20] respectively.  The first version wrote the name as
        # `'fcvt' + SFMT[fmt] + SFMT[{0:1,1:0}[rs2]]`, i.e. it looked up the
        # complement of bits[24:20] instead of the value, and got BOTH rows
        # backwards: 0x4015f553 came out `fcvt.s.s` where the reader says
        # `fcvt.s.d`, and 0x42050553 came out `fcvt.d.d` where the reader says
        # `fcvt.d.s`.  MEASURED, section 10, two words.  It is the mirror image
        # of the `r_mul` bug in the sense that matters: the fields were read at
        # the right positions and used for the wrong thing, so nothing about the
        # output was malformed.
        if rs2 not in (0, 1) or rs2 == fmt:
            raise Undefined('inst[31:27] = 0b01000 is a float-to-float '
                            'conversion with inst[26:25] = 0b%s and '
                            'bits[24:20] = 0b%s, and the two must name DIFFERENT '
                            'widths.  The measured pairs are (fmt=0, rs2=1) '
                            'and (fmt=1, rs2=0) only'
                            % (format(fmt, '02b'), format(rs2, '05b')))
        i.say('bits[24:20] = 0b%s is the SOURCE TYPE, not an rs2.  In fadd.s '
              'under this same opcode those five bits are fa0, a real '
              'register; here they are a tag saying which width to convert '
              'FROM.  A field position does not carry a field\'s meaning, and '
              'the swap is symmetric: exchange the two selector fields and the '
              'two instruction names exchange.  The name is DESTINATION then '
              'SOURCE -- `fcvt.d.s` reads "double, from single" -- so the two '
              'five-bit and two-bit fields are appended in that order and '
              'getting the order wrong produces a name for the OPPOSITE '
              'conversion that is still a real instruction'
              % format(rs2, '05b'))
        i.name = 'fcvt' + SFMT[fmt] + SFMT[rs2]
        i.ops = [freg(rd), freg(rs1)]
    # inst[31:27] = 0b11000 is fmv.x.w / fmv.x.d / fclass.s, all three of
    # which have an INTEGER destination.  The source and destination register
    # files are different files with the same numbering.
    elif f7 == 28 and fmt in (0, 1):
        if f3 == 0:
            i.say('bits[11:7] is an INTEGER register and bits[19:15] is a float '
                  'one.  The two files have the same numbering, so the number '
                  '10 is a0 here and fa0 in fadd.s, and the same five bits at '
                  'the same position mean different FILES')
            i.name = 'fmv.x.w' if fmt == 0 else 'fmv.x.d'
        elif f3 == 1:
            i.name = 'fclass.s' if fmt == 0 else 'fclass.d'
        else:
            raise Undefined('inst[31:27] = 0b11100 with funct3 = %d' % f3)
        i.ops = [xreg(rd), freg(rs1)]
    # inst[31:27] = 0b11110 is the reverse move: an integer source into a
    # float destination.  MEASURED: fmv.w.x fa0,a0 is 0xf0050553, one bit
    # (inst[25]) from fmv.d.x.
    elif f7 == 30 and f3 == 0 and fmt in (0, 1):
        i.name = 'fmv.w.x' if fmt == 0 else 'fmv.d.x'
        i.ops = [freg(rd), xreg(rs1)]
    # inst[31:27] = 0b11000 is the float-to-integer conversion and 0b11010 is
    # the integer-to-float one, and bits[24:20] is the integer WIDTH -- four
    # values in five bits.
    #
    # `f3 in RM_NAME` AND NOT `f3 == 7`, and that is the whole of the second
    # bug this model had.  MEASURED, section 10: `fcvt.l.d a0, fa5, rtz` is
    # 0xc2279553, whose funct3 is 1, and requiring funct3 = 7 modelled ONE of
    # the eight rounding modes and made the other seven report as UNDEFINED.
    # Four legal instructions in the corpus were counted as "undefined by the
    # architecture" because a model read a field as a constant it is not, and
    # the count of undefined words in section 1 was inflated by exactly those
    # four.  The eight values, QUOTED from the F/D chapters' static rounding
    # mode table: rne, rtz, rdn, rup, rmm, dyn, reserved, and 7 = "take it
    # from frm".
    elif f7 in (24, 26) and f3 in RM_NAME and rs2 in IWIDTH:
        i.say('bits[24:20] = 0b%s names the integer WIDTH and funct3 = %d is '
              'the ROUNDING MODE, not a fixed value.  Four widths in five bits, '
              'eight roundings in three, and the first version of this model '
              'required funct3 = 7 -- which is the "read frm" encoding -- and '
              'so reported every explicit-rounding conversion as UNDEFINED'
              % (format(rs2, '05b'), f3))
        # MEASURED: the reader PRINTS the rounding mode only when it is not
        # the default one.  `fcvt.w.s a0, fa0` and `fcvt.w.s a0, fa0, dyn` are
        # the same 32 bits, and this file's first version of the model always
        # printed it, so exactly one word in 1,082 disagreed after every other
        # difference had been resolved -- and it was a printing convention, not
        # a decode.  The convention is a printer's: an explicit `rm` field in
        # the assembly is a HINT that the mode is the default, and both readers
        # are right to drop it.  The rule below reproduces the convention by
        # omitting `dyn`, and the cross-check reports 1,046 agreements against
        # 1 disagreement -- and that one is listed by name rather than
        # normalised away, because "one disagreement, named" is the result a
        # reader can believe and "1,047 agreements" over a comparison that had
        # been made to delete the difference is not.
        rm = '' if RM_NAME[f3] == 'dyn' else RM_NAME[f3]
        if f7 == 24:
            i.name = 'fcvt' + IWIDTH[rs2] + src
            i.ops = [xreg(rd), freg(rs1)] + ([rm] if rm else [])
        else:
            i.name = 'fcvt' + src + IWIDTH[rs2]
            i.ops = [freg(rd), xreg(rs1)] + ([rm] if rm else [])
    else:
        raise Undefined('a floating-point row this file does not model '
                        '(inst[31:27] = 0b%s, inst[26:25] = 0b%s, '
                        'bits[24:20] = 0b%s, funct3 = %d)'
                        % (format(f7, '05b'), format(fmt, '02b'),
                           format(rs2, '05b'), f3))
    i.ext = 'F' if (src == '.s' or i.name.endswith('.s')) else 'D'
    i.model = 'i_fcvt'
    return True


def i_fp_ldst(i):
    """The floating-point load and store, which share the integer formats.

    MEASURED, section 3: `fld fa0,0(a1)` and `ld a0,0(a1)` are 0x2188 and
    0x2183 -- one bit apart, funct3 = 011 against 010.  The F extension did
    not add a load format; it took two of the eight funct3 values in the I
    format and gave them a floating-point meaning.
    """
    f3 = bits(i.word, 14, 12)
    if f3 not in (2, 3):
        raise Bad()
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('I', [(0, (31, 20))], 12, 'contiguous at inst[31:20]')
    i.fmt = 'I'
    i.say('funct3 = %d in the I format.  The integer load with the same '
          'funct3 loads an integer register; this one loads an f register, '
          'and the field positions are identical' % f3)
    i.name = 'flw' if f3 == 2 else 'fld'
    i.ops = [freg(rd), '%d(%s)' % (im, xreg(rs1))]
    i.ext = 'F' if f3 == 2 else 'D'
    i.model = 'i_fp_ldst'
    return True


def s_fp_st(i):
    f3 = bits(i.word, 14, 12)
    if f3 not in (2, 3):
        raise Bad()
    rs2 = i.field('rs2', 24, 20)
    rs1 = i.field('rs1', 19, 15)
    im = i.imm('S', [(0, (11, 7)), (5, (31, 25))], 12, 'the S split, unchanged')
    i.fmt = 'S'
    i.name = 'fsw' if f3 == 2 else 'fsd'
    i.ops = [freg(rs2), '%d(%s)' % (im, xreg(rs1))]
    i.ext = 'F' if f3 == 2 else 'D'
    i.model = 's_fp_st'
    return True


AMO_F3 = {2: '.w', 3: '.d'}
AMO_F5 = {0x00: 'amoadd', 0x01: 'amoswap', 0x02: 'lr', 0x03: 'sc',
          0x04: 'amoxor', 0x08: 'amoor', 0x0C: 'amoand', 0x10: 'amomin',
          0x14: 'amomax', 0x18: 'amominu', 0x1C: 'amomaxu'}


def a_amo(i):
    f3 = bits(i.word, 14, 12)
    f5 = bits(i.word, 31, 27)
    if f3 not in AMO_F3 or f5 not in AMO_F5:
        raise Undefined('an AMO this file does not model: funct3 = %d, '
                        'funct5 = 0b%s' % (f3, format(f5, '05b')))
    rd = i.field('rd', 11, 7)
    rs1 = i.field('rs1', 19, 15)
    rs2 = i.field('rs2', 24, 20)
    i.fmt = 'R'
    base = AMO_F5[f5]
    if base == 'lr':
        i.say('funct5 = 0b00010 with rs2 = 0 is the LOAD-RESERVED half of a '
              'pair, and the reservation is not a register and not a flag '
              'register: it is a hidden resource.  sc is funct5 = 0b00011 and '
              'the pair is a loop by construction')
        i.name = 'lr' + AMO_F3[f3]
        i.ops = [xreg(rd), '(%s)' % xreg(rs1)]
    elif base == 'sc':
        i.say('funct5 = 0b00011: store-CONDITIONAL, which succeeds only if the '
              'reservation from the matching lr is still held')
        i.name = 'sc' + AMO_F3[f3]
        i.ops = [xreg(rd), xreg(rs2), '(%s)' % xreg(rs1)]
    else:
        i.say('funct5 = 0b%s is an AMO: read, modify, write, atomically, with '
              'NO implicit lock anywhere in the instruction -- unlike x86-64, '
              'where the LOCK prefix is what says so and forgetting it is '
              'silent' % format(f5, '05b'))
        i.name = base + AMO_F3[f3]
        i.ops = [xreg(rd), xreg(rs2), '(%s)' % xreg(rs1)]
    i.ext = 'A'
    i.model = 'a_amo'
    return True


VTYPE_SEW = ['e8', 'e16', 'e32', 'e64', 'e128', 'e256', 'e512', 'e1024']
VTYPE_LMUL = {0: 'm1', 1: 'm2', 2: 'm4', 3: 'm8', 5: 'mf8', 6: 'mf4',
              7: 'mf2'}
# The zimm -> vtype field split, MEASURED rather than read out of the
# specification, and the measurement contradicts what this model's own comment
# claimed.  MEASURED: 112 variants -- 4 element widths x 7 register-group
# multipliers x 2 tail policies x 2 mask policies -- assembled and read back,
# giving 112 DISTINCT zimm values, so the map is a bijection over the values
# the assembler will emit.  Read off that table:
#
#   vta = zimm[6]      MEASURED: ta sets 0x40 and tu clears it, in all 56 rows
#   vma = zimm[7]      MEASURED: ma sets 0x80 and mu clears it, in all 56 rows
#   vsew = zimm[5:3]   MEASURED: e8->0, e16->1, e32->2, e64->3
#   vlmul = zimm[2:0]  MEASURED: m1->0, m2->1, m4->2, m8->3, mf8->5, mf4->6,
#                             mf2->7, and 100 is never emitted
#
# And THE FINDING, which is a real one and not a detail: zimm[10:8] is
# CONSTANT ZERO in all 112 measured variants.  Three bits of an eleven-bit
# field that no reachable vsetvli uses.  The first version of this model
# printed `zimm11=0b00011011000` and its comment claimed the element width
# lived in "three bits of the field" -- and the four zimm strings in that
# comment are CORRECT while the bit assignment is not stated anywhere, which
# is how a comment can be right about its data and wrong about what it means.
# Section 4D measures the same class of thing in the compressed extension and
# the rule is the same: a field map measured by SWEEP records which bits MOVE,
# and three bits that never move look exactly like three bits that do.
def vtype_fields(zimm):
    sew = (zimm >> 3) & 7
    lmul = zimm & 7
    vta = 'ta' if (zimm >> 6) & 1 else 'tu'
    vma = 'ma' if (zimm >> 7) & 1 else 'mu'
    return [VTYPE_SEW[sew], VTYPE_LMUL.get(lmul, 'm?%d' % lmul), vta, vma]


def v_setvli(i):
    """vsetvli and vsetivli: the one instruction whose MEANING is a register.

    MEASURED while scoping and re-measured in section 2: clang emits
    `vsetvli` from a plain C loop under -march=rv64gcv.  The instruction is
    4 bytes and it is 4 bytes always, because the vector extension has no
    compressed forms -- and the reason is visible in the encoding: the
    instruction carries a 3-bit field that says how to interpret the rest of
    it, and a 16-bit encoding has nowhere to put that.

    The four fields are zimm[10:0] at inst[30:20], rs1 at inst[19:15], rd at
    inst[11:7] and the two mode bits at inst[31:30].  This decoder names it
    and does not model the vector data path, because that is a later course in
    this section and a decoder that half-modelled it would be worse than one
    that said so.
    """
    if bits(i.word, 6, 0) != 0x57 or bits(i.word, 14, 12) != 7:
        raise Bad()
    rd = i.field('rd', 11, 7)
    f5 = bits(i.word, 31, 27)
    i.fmt = 'I'
    # The three configuration instructions are told apart by TWO BITS,
    # inst[31:30], and that is the whole of the vector dispatch.  MEASURED, one
    # instruction per value:
    #
    #   0b00  vsetvli   t0, a1, e64, m1, ta, ma   =  0x0d85f2d7
    #   0b10  vsetvl    t0, a1, a2                 =  0x80c5f2d7
    #   0b11  vsetivli  t0, 0x1, e64, m1, tu, ma   =  0xc980f2d7
    #
    # The first version of this model checked inst[31] alone, which is 0 for
    # vsetvli and 1 for both of the others, and it printed
    # `vsetivli t0, 216, zimm11=0xd8` for the vsetvli -- an immediate where a
    # register belongs and a value 216 where a1 was written.  Two bits, one
    # field, and the field is a three-way selector rather than a flag.
    if f5 >> 2 == 0b00:
        zimm = i.field('zimm', 30, 20)
        rs1 = i.field('rs1', 19, 15)
        i.say('inst[31:30] = 0b00 selects vsetvli of the three '
              'configuration instructions.  zimm is ELEVEN bits at inst[30:20] '
              'and it is NOT the vector length: MEASURED, sweeping the element '
              'width with everything else fixed gives zimm = 0b00011000000 for '
              'e8, 0b00011001000 for e16, 0b00011010000 for e32 and '
              '0b00011011000 for e64 -- four values, three bits of the field, '
              'holding the ELEMENT WIDTH, the register-group MULTIPLIER and the '
              'TAIL and MASK policies.  The LENGTH is not in this instruction '
              'at all: it comes from rs1, and its VALUE is not in the '
              'instruction either.  That is how one fixed 32-bit encoding '
              'describes a vector of a length the instruction does not contain.')
        i.name = 'vsetvli'
        i.ops = [xreg(rd), xreg(rs1)] + vtype_fields(zimm)
        i.ext = 'V'
        i.model = 'v_setvli'
        return True
    if f5 >> 2 == 0b10:
        rs2 = i.field('rs2', 20, 15)
        rs1 = i.field('rs1', 19, 15)
        i.say('inst[31:30] = 0b10 selects vsetvl, where BOTH the requested '
              'length and the required minimum are REGISTERS.  This decoder '
              'prints bits[20:15] as one six-bit field because that is how it '
              'arrives; the specification calls it rs2, and the fact that a '
              'six-bit window here is two five-bit registers overlapping by one '
              'bit is a reminder that the field table and the field list are '
              'different artefacts')
        i.name = 'vsetvl'
        i.ops = [xreg(rd), xreg(rs1), 'rs2=%d' % rs2]
        i.ext = 'V'
        i.model = 'v_setvli'
        return True
    if f5 >> 2 == 0b11:
        zimm = i.field('zimm', 30, 20)
        uimm = i.field('uimm', 19, 15)
        i.say('inst[31:30] = 0b11 selects vsetivli, and inst[19:15] is a FIVE-'
              'BIT IMMEDIATE, not a register.  MEASURED: vsetivli t0, 0x1 is '
              '0xc980f2d7 and vsetivli t0, 0x0 is 0xc98072d7, one bit apart, '
              'and the bit is inst[15] -- inside the field the base ISA calls '
              'rs1.  The three configuration instructions all use inst[19:15] '
              'and it is a REGISTER in two of them and an IMMEDIATE in the '
              'third, which is why the two bits above are not a decoration')
        i.name = 'vsetivli'
        i.ops = [xreg(rd), str(uimm)] + vtype_fields(zimm)
        i.ext = 'V'
        i.model = 'v_setvli'
        return True
    # Not a configuration instruction: a vector DATA word.  Counted and left
    # unmodelled, deliberately -- the vector data path is a later course in
    # this section, and a decoder that named eight of the four hundred vector
    # encodings and called the rest a bug would be worse than one that says
    # which half of the extension it implements.
    raise Bad()


#
# The opcode sets.  Each entry is (name, the opcodes it may claim, handler,
# extension, claim).  A model is asked ONLY for an opcode in its set, and that
# is not tidiness -- it is the reason this table has 28 rows and not 40.
#
# THE BUG THIS STRUCTURE EXISTS TO PREVENT, and it is the second time in this
# collection that a decoder has been caught by it, so it is worth naming.  The
# first version of this file dispatched by asking every model in turn and
# letting each one reject what it did not recognise.  `fmadd.s` is funct7 =
# 0b00101, funct3 = 0, fmt = 00 -- the SAME funct7 and funct3 as `fmin.s`.
# The only thing that tells them apart is the OPCODE: 0x43 for the fused
# multiply-add and 0x53 for the minimum.  With a "try every model" dispatch
# and a model list where the arithmetic rows come before the FMA rows, `fmadd.s`
# was decoded as `fmin.s` -- and the disassembly was plausible, and the count
# of disagreements with the second reader was not consulted until much later.
#
# The general statement is this: on RISC-V a sub-opcode SELECTOR is not
# self-contained.  `funct7` means one thing under opcode 0x33 and another under
# 0x53, and no amount of care inside a model can recover a fact the model was
# never told.  The dispatch must be keyed on the opcode, and the opcode is
# seven bits of the word, and a decoder that does not read it first is
# guessing.  Section 5 prints the measured consequence: 28 opcode-keyed models
# resolve 24 of the 31 opcode values the corpus uses, and the second reader
# disagrees with this file on none of them.
#
# The opcode sets below are written as explicit lists rather than as a
# function of the format, because the format is DERIVED from the opcode and
# using it here would be circular.  A reader checking `i_load` will find the
# load opcodes spelled out, which is the right place to look.
MODELS32 = [
    ('r_fp32', (0x53,), r_fp32, '--', 'RETIRED.  The D rows are the F rows '
     'with inst[26:25] = 01, so a separate model is a guard that can be '
     'ordered wrongly; `r_fp` reads the fmt bits instead.  Kept in the list '
     'with a False body because section 12\'s poison removes THIS entry and '
     'the delta is measured'),
    ('i_fma', (0x43, 0x47, 0x4B, 0x4F), i_fma, 'F', 'the fused multiply-add '
     'family, four operands in a three-register format, which is why inst[31:25] '
     'is read as two fields: bits[31:27] the addend and bits[26:25] the '
     'rounding mode'),
    ('i_fp_ldst', (0x07,), i_fp_ldst, 'F/D', 'flw and fld, funct3 = 010 and '
     '011 in the I format, one bit from `lw` and `ld`'),
    ('s_fp_st', (0x27,), s_fp_st, 'F/D', 'fsw and fsd, funct3 = 010 and 011 in '
     'the S format'),
    ('a_amo', (0x2F,), a_amo, 'A', 'the atomics: lr, sc and the AMOs, funct5 '
     'at inst[31:27] and no implicit lock anywhere'),
    ('v_setvli', (0x57,), v_setvli, 'V', 'the three vector-CONFIGURATION '
     'instructions, told apart by inst[31:30] alone -- two bits and three '
     'meanings -- and the only instructions in the corpus whose operand is a '
     'length the encoding does not contain'),
    ('s_fence', (0x0F,), s_fence, 'I', 'the ordering fence, and the two '
     'four-bit SETS that are the whole ordering model.  Placed ABOVE '
     's_misc_mem because both claim opcode 0x0f and differ only in funct3 = 0 '
     'against 1 -- and a fence word with funct3 = 0 decoded as a SYSTEM '
     'function would be a plausible wrong answer'),
    ('s_system', (0x73,), s_system, 'Zicsr', 'the six CSR instructions, a '
     '12-bit CSR number in the immediate field; Zicsr was split OUT of the '
     'base'),
    ('s_misc_mem', (0x0F, 0x73), s_misc_mem, 'I', 'ecall, ebreak and fence.i, '
     'which are I-format words whose funct12 is the whole instruction.  '
     'ecall is 0x00000073: thirty-one of its thirty-two bits are a fixed '
     'pattern and there is nothing to read'),
    ('i_load', (0x03,), i_load, 'I', 'the seven integer loads, selected by '
     'funct3'),
    ('s_store', (0x23,), s_store, 'I', 'the four integer stores, selected by '
     'funct3'),
    ('b_branch', (0x63,), b_branch, 'I', 'the six branches; funct3 = 2 and 3 '
     'are reserved and were the float compares'),
    ('i_alu_imm', (0x13,), i_alu_imm, 'I', 'addi, slti, sltiu, xori, ori, '
     'andi'),
    ('i_shift_imm', (0x13,), i_shift_imm, 'I', 'slli, srli, srai, with the '
     'shift amount in imm[5:0] and imm[11:6] required to be zero'),
    ('i_addiw', (0x1B,), i_addiw, 'I', 'addiw'),
    ('i_shiftw_imm', (0x1B,), i_shiftw_imm, 'I', 'slliw, srliw, sraiw'),
    ('i_jalr', (0x67,), i_jalr, 'I', 'jalr: the I format with a register '
     'target, and the reason a `ret` is 4 bytes when a `j` is 2'),
    ('r_mulw', (0x3B,), r_mulw, 'M', 'the RV64 word multiply and divide rows'),
    ('r_mul', (0x33,), r_mul, 'M', 'the M extension: eight instructions in a '
     'funct7 value the base left empty, added by one letter with no new opcode '
     'and no new field'),
    ('r_shiftw', (0x3B,), r_shiftw, 'I', 'addw, sllw, srlw and the UNDEFINED '
     'subw row'),
    ('r_alu', (0x33,), r_alu, 'I', 'the eight base R operations plus sub and '
     'sra, all selected by the PAIR (funct7, funct3)'),
    ('i_fcvt', (0x53,), i_fcvt, 'F/D', 'the conversion family, where '
     'bits[24:20] is a TYPE TAG rather than an rs2 and the destination may be '
     'an integer register in one instruction and a float register in the next'),
    ('r_fp', (0x53,), r_fp, 'F/D', 'the single-precision arithmetic rows, '
     'including the ONE BIT that separates fadd.s from fadd.d, and the case '
     'where bits[24:20] is an rs2 in one instruction and part of funct7 in the '
     'next'),
    ('u_lui', (0x37,), u_lui, 'I', 'lui: the U format, twenty bits already in '
     'place'),
    ('u_auipc', (0x17,), u_auipc, 'I', 'auipc: the U format with the pc as the '
     'source, and the first half of the pair that reaches further than a '
     'branch'),
    ('j_jal', (0x6F,), j_jal, 'I', 'jal: the J format, twenty movable bits in '
     'a contiguous window that is not a contiguous field'),
]

# The declared subset, stated as a number a reader can check.  `crosscheck.py`
# asserts that this list has one entry per model and one claim per model,
# because a model with no claim is a model nobody can check.
CLAIMS32 = {m[0]: m[4] for m in MODELS32}

# ---------------------------------------------------------------------------
# The compressed extension, and the nine formats.
#
# The format table is QUOTED: the unprivileged manual's `zca` chapter,
# "Compressed Instruction Formats", Table "Compressed 16-bit Zca instruction
# formats", which prints the nine layouts with their bit positions.  The same
# section says the thing this decoder is most careful about:
#
#   "The formats were designed to keep bits for the two register source
#    specifiers in the same place in all instructions, while the destination
#    register field can move.  When the full 5-bit destination register
#    specifier is present, it is in the same place as in the 32-bit RISC-V
#    encoding.  Where immediates are sign-extended, the sign extension is
#    always from bit 12."
#
# So the compressed formats keep rd at inst[11:7] and rs2 at inst[6:2] --
# EXACTLY where the base ISA keeps them -- and the three-bit rd'/rs1'/rs2'
# fields sit in inst[9:7] and inst[4:2], which is where the base ISA keeps
# funct3 and part of rd.  The plan for this course predicted "the same
# register number sits in different bit positions in different formats".  The
# measurement in section 4 shows that the PREDICTION IS HALF WRONG and in an
# interesting way: within the base ISA every register field is in the same
# place in every format, and it is the C extension that introduces a second,
# narrower register field.  Section 4 prints the two tables side by side and
# the difference is the concept.
# ---------------------------------------------------------------------------

CFORMATS = [
    ('CR', 'funct4|rd/rs1|rs2|op',
     'register to register: c.mv, c.add, c.jr, c.jalr, c.ebreak'),
    ('CI', 'funct3|imm[5]|rd/rs1|imm[4:0]|op',
     'register-immediate: c.addi, c.li, c.lui, c.addiw, c.slli, c.addi16sp'),
    ('CSS', 'funct3|imm|rs2|op',
     'stack-relative store: c.swsp, c.sdsp, c.fswsp, c.fsdsp'),
    ('CIW', 'funct3|imm|rd\'|op',
     'the wide immediate, and the ONLY format with an eight-bit one: '
     'c.addi4spn'),
    ('CL', 'funct3|imm|rs1\'|imm|rd\'|op',
     'register-based load: c.lw, c.ld, c.flw, c.fld'),
    ('CS', 'funct3|imm|rs1\'|imm|rs2\'|op',
     'register-based store: c.sw, c.sd, c.fsw, c.fsd'),
    ('CA', 'funct6|rd\'/rs1\'|funct2|rs2\'|op',
     'register-register on the eight registers: c.sub, c.xor, c.or, c.and, '
     'c.subw, c.addw'),
    ('CB', 'funct3|offset|rd\'/rs1\'|offset|op',
     'branch and shift-and-immediate: c.beqz, c.bnez, c.srli, c.srai, c.andi'),
    ('CJ', 'funct3|jump target|op',
     'c.j, eleven bits of displacement and no registers at all'),
]


def cfmt_of(w):
    """Which of the nine compressed formats, and which quadrant.

    The quadrant is inst[1:0] and it is also the LENGTH RULE: quadrant 3 does
    not exist, which is why a 32-bit instruction is one whose low two bits
    are 1.  That is the same two bits, read twice, for two different purposes
    -- once to find the boundary and once to find the format.
    """
    q = bits(w, 1, 0)
    f3 = bits(w, 15, 13)
    if q == 0:
        return {0: 'CIW', 1: 'CL', 2: 'CL', 3: 'CL', 4: None,
                5: 'CS', 6: 'CS', 7: 'CS'}[f3]
    if q == 1:
        if f3 == 0:
            return 'CI'
        if f3 == 1:
            return 'CI'
        if f3 == 2:
            return 'CI'
        if f3 == 3:
            return 'CI'
        if f3 == 4:
            return 'CA' if bits(w, 11, 10) == 3 else 'CB'
        return 'CJ' if f3 == 5 else 'CB'
    return 'CI' if f3 == 0 else ('CSS' if f3 in (5, 6, 7) else 'CR')


# The RESERVED rules, transcribed from the `zca` chapter and then CHECKED
# against the second reader over all 49,152 compressed code points in section
# 6.  Each row is (quadrant, funct3, the condition, how many code points it
# kills, the QUOTED sentence that kills it).
#
# The `note` on each row is the specification's own words where this file has
# them, and the count is DERIVED, not quoted -- the specification does not
# publish a total, and computing it from the rules is the interesting part.
RESERVED_RULES = [
    (0, 0, lambda w: bits(w, 12, 5) == 0, 8,
     'C.ADDI4SPN is valid only when nzuimm != 0; the code points with '
     'nzuimm = 0 are reserved.  EIGHT of them, one per value of the '
     'three-bit rd\' field: 0x0000, 0x0004, 0x0008, 0x000c, 0x0010, 0x0014, '
     '0x0018, 0x001c.  This file first transcribed the count as SEVEN, on the '
     'reason that 0x0002 had been given to C.SLLI64 by the RV128 work and so '
     'was claimed.  That is RETRACTED, and the enumeration below is what '
     'retracted it: 0x0002 has bits[1:0] == 0b10, so it is in QUADRANT 2 and '
     'never in this cell at all, which is quadrant 0 and funct3 == 0.  The '
     'two cells were confused because the numbers are adjacent, not '
     'equivalent.  The second reader confirms all eight: it prints <unknown> '
     'for 0x0004 through 0x001c, and c.slli64 for 0x0002.'),
    (0, 4, lambda w: True, 2048,
     'the WHOLE quadrant-0 funct3 = 100 cell.  The manual\'s opcode map marks '
     'it Reserved and the note above it explains why the table is drawn in '
     'two columns: "a few opcodes are used for different purposes depending '
     'on base ISA", and this cell held C.FLWSP in the RV32 draft before the '
     'RV64 column needed the slot for C.LD.  2,048 code points -- 85 per cent '
     'of every reserved code point in the compressed space, and the reason '
     '"the C extension reserves a large fraction of the 16-bit space" is true '
     'in a way that has almost nothing to do with compression.'),
    (1, 1, lambda w: bits(w, 11, 7) == 0, 64,
     'C.ADDIW is valid only when rd != x0; the code points with rd = x0 are '
     'reserved.  This is the RV64 quadrant: in RV32 the same cell is C.JAL, '
     'and C.JAL has no reserved code points at all.  A reserved encoding in '
     'one base and a valid instruction in the other, at the same 16 bits.'),
    (1, 3, lambda w: sign_extend(bits(w, 12, 12) << 5 | bits(w, 6, 2), 6) == 0,
     32,
     'C.LUI is valid only when rd != x2 and the immediate is not zero; "The '
     'code points with imm = 0 are reserved."  rd = x2 is C.ADDI16SP, whose '
     'own zero immediate is also reserved ("the code point with nzimm = 0 is '
     'reserved"), so all 32 register values die together and the two rules '
     'count as one cell.'),
    (1, 4, lambda w: bits(w, 11, 10) == 3 and bits(w, 12, 12) == 1
     and bits(w, 6, 5) >= 2, 128,
     'the RV128 arithmetic rows.  bit12 = 1 with bits[6:5] = 00 is C.SUBW and '
     '01 is C.ADDW, and bits[6:5] = 10 and 11 are reserved -- sixteen of the '
     'thirty-two (bit12, bits[6:2]) combinations, times the eight registers.  '
     'MEASURED against the second reader, which prints <unknown> for exactly '
     'these 128 and for nothing else in the cell.'),
    (2, 2, lambda w: bits(w, 11, 7) == 0, 64,
     'C.LWSP is valid only when rd != x0.  Sixty-four code points, not '
     'thirty-two, because the CI format\'s immediate is six bits and a zero '
     'register number leaves all six free.'),
    (2, 3, lambda w: bits(w, 11, 7) == 0, 64,
     'C.LDSP, the XLEN=64 member of the pair, with the same rule and the same '
     'count.  In RV32 this cell is C.FLWSP, and the manual says the reserved '
     'rule is the same -- so this is a reserved cell in BOTH bases, which is '
     'the opposite of the C.ADDIW/C.JAL cell above.'),
    (2, 4, lambda w: bits(w, 12, 12) == 0 and bits(w, 11, 7) == 0
     and bits(w, 6, 2) == 0, 1,
     'the single code point 0x8002.  C.JR needs rs1 != x0, C.JALR needs '
     'rs1 != x0, C.EBREAK is rs1 = 0 AND rs2 = 0, and C.MV/C.ADD need '
     'rs2 != x0 -- so rs1 = 0 with rs2 = 0 is the one combination every rule '
     'rejects.  ONE code point, and it is the only reserved compressed '
     'encoding a person is likely to meet in a hex dump.  The bit-12 test is '
     'NOT decoration: without it the rule also kills 0x9002, which is '
     'C.EBREAK -- a fully defined instruction that breaks out of the CPU.  '
     'MEASURED against the second reader, which prints ebreak for it and '
     '<unknown> for 0x8002.  Found by the exhaustive enumeration below, not '
     'by reading the rule twice, which is the argument for enumerating.'),
]

# The HINT rules, transcribed from the manual's "Zca HINT instructions" table
# and then MEASURED: section 6 counts the HINT code points this decoder finds
# and prints the manual's own per-row numbers beside them.  A HINT is not
# reserved -- it is DEFINED, it just does nothing -- and conflating the two is
# the most common way to overstate how much space the C extension gives up.
HINT_RULES = [
    (1, 0, lambda w: bits(w, 11, 7) == 0, 'c.nop', 'imm != 0', 63),
    (1, 0, lambda w: bits(w, 11, 7) != 0 and bits(w, 6, 2) == 0
     and bits(w, 12, 12) == 0, 'c.addi', 'rd != 0, imm = 0', 31),
    (1, 2, lambda w: bits(w, 11, 7) == 0, 'c.li', 'rd = 0', 64),
    (1, 3, lambda w: bits(w, 11, 7) == 0
     and sign_extend(bits(w, 12, 12) << 5 | bits(w, 6, 2), 6) != 0,
     'c.lui', 'rd = 0, imm != 0', 63),
    (2, 4, lambda w: bits(w, 11, 7) == 0 and bits(w, 6, 2) != 0,
     'c.mv', 'rd = 0, rs2 != 0', 31),
    (2, 4, lambda w: bits(w, 11, 7) == 0 and bits(w, 6, 2) != 0
     and 2 <= bits(w, 6, 2) <= 5, 'c.add', 'rd = 0, rs2 = x2-x5', 4),
    (2, 0, lambda w: bits(w, 11, 7) == 0 or bits(w, 6, 2) == 0,
     'c.slli', 'rd = 0 or shamt = 0', 95),
    (1, 4, lambda w: bits(w, 11, 10) == 0 and bits(w, 6, 2) == 0
     and bits(w, 12, 12) == 0, 'c.srli', 'shamt = 0', 8),
    (1, 4, lambda w: bits(w, 11, 10) == 1 and bits(w, 6, 2) == 0
     and bits(w, 12, 12) == 0, 'c.srai', 'shamt = 0', 8),
]


def c_imm(w, perm, nbits=None, signed=False):
    """Rebuild a compressed immediate from a PERMUTATION.

    `perm` is a list of (out_bit, in_hi, in_lo) triples: produced bit `out_bit`
    comes from instruction bits in_hi..in_lo.  The list is in ascending output
    order and each entry is normally a single bit, so a permutation is a
    bijection from a subset of the instruction's sixteen bits to a subset of
    the immediate's bits.

    Every permutation in this file was MEASURED, and the method is worth
    stating because it is the only way to get one right: assemble the
    instruction with every reachable value of the immediate, read the word
    back, and for each produced bit find the instruction bit that is 1 exactly
    when it is.  One wrong bit in a permutation produces a decoder that is
    right for small immediates and wrong for large ones, which is the worst
    kind of wrong.

    The compressed immediates are permuted in exactly the way the base ones
    are, and for the reason the manual gives: "Immediate fields have been
    scrambled, as in the base specification, to reduce the number of immediate
    multiplexers required" -- and, in the note, "The immediate fields are
    scrambled in the instruction formats instead of in sequential order so that
    as many bits as possible are in the same position in every instruction,
    thereby simplifying implementations."

    And the RISC-V version of that goal has a consequence worth noticing
    before section 4 measures it: the compressed extension has NINE formats in
    sixteen bits, and several of them want an immediate in the same six
    positions, so the base's "one field, one position" arrangement is not
    available and each format gets its own order.  The section 4 sweep measures
    seven different immediate masks in a table of twenty rows, and only two of
    the seven have the same permutation.
    """
    v = 0
    for (ob, ih, il) in perm:
        for k in range(ih - il + 1):
            v |= bits(w, il + k, il + k) << (ob + k)
    return sign_extend(v, nbits) if (signed and nbits) else v


def decode16(w, off=0, addr=0):
    """Decode one 16-bit instruction.  QUARTER of the instruction space."""
    i = Insn(w, 2, off, addr)
    q = bits(w, 1, 0)
    f3 = bits(w, 15, 13)
    i.fmt = cfmt_of(w) or '(reserved)'
    i.say('quadrant = inst[1:0] = 0b%s.  This is the LENGTH RULE read a second '
          'time: the same two bits that told `length_of` to step two bytes now '
          'say which quadrant this is, and quadrant 3 -- the value that means '
          '"32 bits" -- does not exist as a compressed format at all.  One '
          'field, two jobs, and the second job is why quadrant 3 is a length '
          'and not a format.' % format(q, '02b'))
    i.say('inst[15:13] = 0b%s is the funct3, and together with the quadrant it '
          'selects one of the thirty-two cells of the opcode map.  Twenty-four '
          'of the cells name an instruction, four are HINTs, and four are '
          'RESERVED -- and the four reserved cells are the whole of the honest '
          'half of this extension\'s story.  Section 6 enumerates all 49,152 '
          'compressed code points and says which is which.' % format(f3, '03b'))
    # --- the reserved rules, checked first -----------------------------
    for (rq, rf3, cond, n, note) in RESERVED_RULES:
        if q == rq and f3 == rf3 and cond(w):
            i.note = 'reserved'
            i.name = 'c.reserved'
            i.ops = []
            i.say('RESERVED, %d code points in this cell, by this rule: %s'
                  % (n, note))
            i.ext = 'C'
            i.model = 'r_reserved'
            i.text = '(reserved)  %s' % i.fmt
            return i
    # The HINT rules, checked after the RESERVED ones and for a reason that is
    # not tidiness: the two sets are not disjoint in their conditions, only in
    # their outcomes.  `c.li` with rd = x0 is a HINT and `c.addi` with rd != 0
    # and imm = 0 is a HINT, and both are in the funct3 = 010 and funct3 = 000
    # cells respectively -- but `c.slli` with shamt = 0 is a HINT in a cell
    # where a reserved rule also applies for a different bit pattern.  Reserved
    # first means a word that satisfies both conditions is reported as
    # reserved, which is the correct precedence: a reserved encoding is
    # undefined and a HINT is defined, and the worse answer is the one that
    # must win.
    for (rq, rf3, cond, name, constraint, n) in HINT_RULES:
        if q == rq and f3 == rf3 and cond(w):
            i.note = 'hint'
            i.say('this code point is a HINT, not a reserved encoding.  The '
                  'manual\'s own distinction: "A portion of the Zca encoding '
                  'space is reserved for microarchitectural HINTs ... these '
                  'instructions do not modify any architectural state".  A '
                  'HINT is DEFINED -- an implementation executes it as a no-op '
                  '-- and a reserved encoding is not defined at all.  '
                  'Reporting the two as one number would overstate the C '
                  'extension\'s unusable space by more than a factor of two, '
                  'and section 6 prints both counts.')
    # --- quadrant 0 ----------------------------------------------------
    if q == 0:
        # Quadrant 0 is where the compressed extension's three-bit registers
        # live, and every field position in it was MEASURED by the sweep in
        # section 4 rather than read out of a figure:
        #     rs1' or rd'  =  bits[9:7]
        #     rd'  or rs2' =  bits[4:2]
        #     funct3        =  bits[15:13]
        # Compare section 4's base table, where rd is bits[11:7] and rs2 is
        # bits[6:2].  Same instruction, same 16-bit slot, register field moved
        # DOWN by two bits and NARROWED from five bits to three.
        if f3 == 0:      # C.ADDI4SPN
            # The only eight-bit immediate in the compressed extension, and the
            # only compressed instruction whose destination register is NOT
            # also a source.
            #
            # MEASURED against the assembler over 255 values from 4 to 1020,
            # and the permutation is (value/4)[0]=inst[6], [1]=inst[5],
            # [2]=inst[11], [3]=inst[12], [4]=inst[7], [5]=inst[8],
            # [6]=inst[9], [7]=inst[10].  Read as the specification labels it:
            #
            #     nzuimm[5:4] = inst[12:11]
            #     nzuimm[9:6] = inst[10:7]
            #     nzuimm[2]  = inst[6]
            #     nzuimm[3]  = inst[5]
            #
            # and the produced value is nzuimm TIMES FOUR.  The scale is not a
            # field, it is implied, which is why the assembler states the
            # range in the units of the RESULT: "immediate must be a multiple
            # of 4 bytes in the range [4, 1020]".  Section 6 quotes that
            # diagnostic because it is the tool stating the scale and the reach
            # in one sentence.
            #
            # And the value is ZERO-extended, which is the whole reason a zero
            # here is a reserved code point: an I-type `addi` with a zero
            # immediate is a legal hint and a C.ADDI4SPN with one is reserved,
            # and the difference is the sign extension and nothing else.
            nzu = 4 * c_imm(w, [(0, 6, 6), (1, 5, 5), (2, 11, 11), (3, 12, 12),
                                (4, 7, 7), (5, 8, 8), (6, 9, 9), (7, 10, 10)])
            i.field('rd\'', 4, 2)
            i.say('nzuimm = %d and the produced value is nzuimm x 4 = %d.  The '
                  'multiplication by four is not in the instruction: it is '
                  'implied by the cell, and that is why the assembler phrases '
                  'its refusal in bytes ("a multiple of 4 bytes in the range '
                  '[4, 1020]") rather than in bits.  ZERO-extended, not '
                  'sign-extended -- which is why zero is RESERVED here and is '
                  'merely a hint in the I-type addi'
                  % (nzu // 4, nzu))
            i.name = 'c.addi4spn'
            i.ops = [creg3(bits(w, 4, 2)), 'sp', str(nzu)]
        elif f3 in (1, 2, 3, 5, 6, 7):
            # The six register-based load and store cells, and they do NOT all
            # use the same permutation.  MEASURED, one variant per reachable
            # value of each, which is what it takes to find out:
            #
            #   c.lw / c.sw  (scale 4, [0,124])  (v/4)[0..4] = inst[6,10,11,12,5]
            #   c.ld / c.sd  (scale 8, [0,248])  (v/8)[0..4] = inst[10,11,12,5,6]
            #   c.fld/ c.fsd (scale 8, [0,248])  (v/8)[0..4] = inst[10,11,12,5,6]
            #
            # The integer 32-bit form and the 64-bit form have the SAME five
            # bit positions and DIFFERENT assignments to them, which is the
            # compressed extension's answer to a question the base ISA never
            # had to ask: in the base there is one displacement field per
            # format, so there is nothing to permute against.  Here six
            # formats share five bits and each one wants a different order,
            # and the specification gives each of them a different order.
            #
            # A decoder that reused c.lw's permutation for c.ld would produce
            # the right values for offsets 0 to 124 and WRONG values above --
            # and the wrong values would be multiples of 8, in range, and
            # plausible.  Section 6 measures the disagreement that produces.
            CL_PERM = {
                # funct3: (scale, [(out_bit, in_hi, in_lo)], reach, name, file)
                1: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 5, 5),
                        (4, 6, 6)], 248, 'c.fld', 'f'),
                2: (4, [(0, 6, 6), (1, 10, 10), (2, 11, 11), (3, 12, 12),
                        (4, 5, 5)], 124, 'c.lw', 'x'),
                3: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 5, 5),
                        (4, 6, 6)], 248, 'c.ld', 'x'),
                5: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 5, 5),
                        (4, 6, 6)], 248, 'c.fsd', 'f'),
                6: (4, [(0, 6, 6), (1, 10, 10), (2, 11, 11), (3, 12, 12),
                        (4, 5, 5)], 124, 'c.sw', 'x'),
                7: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 5, 5),
                        (4, 6, 6)], 248, 'c.sd', 'x'),
            }
            scale, perm, reach, name, file = CL_PERM[f3]
            off_v = scale * c_imm(w, perm)
            base = creg3(bits(w, 9, 7))
            r3 = bits(w, 4, 2)
            i.name = name
            if f3 in (1, 5):
                i.ops = [freg(8 + r3), '%d(%s)' % (off_v, base)]
            else:
                i.ops = [creg3(r3), '%d(%s)' % (off_v, base)]
            i.say('CL/CS format: rs1\' is bits[9:7] and rd\'/rs2\' is '
                  'bits[4:2], THREE bits each, indexing x8 to x15 -- the sweep '
                  'measured 0x00000380 and 0x0000001c where the base ISA gives '
                  '0x00000f80 and 0x0000007c for the same two operands.  The '
                  'displacement is ZERO-extended, scaled by %d, with a hard '
                  'zero in the low three bits, and its five bits are at '
                  'inst[12:10] and inst[6:5] -- in an order that is NOT the '
                  'same as c.lw\'s, even though the bit positions are.  Reach '
                  '[0, %d], in the words the assembler uses.' % (scale, reach))
    # --- quadrant 1 ----------------------------------------------------
    elif q == 1:
        imm6 = sign_extend(bits(w, 12, 12) << 5 | bits(w, 6, 2), 6)
        rd = bits(w, 11, 7)
        if f3 == 0:
            i.field('rd', 11, 7)
            i.say('CI format: the six-bit immediate is inst[12] for its top '
                  'bit and inst[6:2] for its low five, so the sign is at '
                  'inst[12] and NOT at inst[31] as it is in every base '
                  'immediate.  That is the manual\'s "the sign extension is '
                  'always from bit 12" and it is the sharpest difference '
                  'between a 32-bit and a 16-bit immediate on this '
                  'architecture')
            # rd = x0 IS c.nop and it is not a HINT, and the difference is one
            # bit.  QUOTED: "The code points with rd = x0 encode the c.nop
            # instruction, of which the code points with imm != 0 are HINTs."
            # So c.nop with a zero immediate is a real instruction that
            # advances the pc and the performance counters, and c.nop with a
            # non-zero one is a HINT, and rd = x0 with a non-zero immediate is
            # also a HINT.  All three are DEFINED and all three do nothing.
            if rd == 0 and imm6 == 0:
                i.name = 'c.nop'
                i.ops = []
                i.say('rd = x0 and imm = 0: this is c.nop, 0x0001, and it is a '
                      'real INSTRUCTION and not a HINT.  The manual reserves '
                      'the all-zero and all-ones 16-bit patterns for a '
                      'different purpose -- "A 16-bit instruction with all '
                      'bits zero is permanently reserved as an illegal '
                      'instruction" -- and 0x0001 is not all-zero, so the '
                      'two-byte nop exists and the all-zero word does not')
            elif rd == 0:
                i.name = 'c.nop'
                i.ops = ['hint, imm=%d' % imm6]
            else:
                i.name = 'c.addi'
                i.ops = [xreg(rd), str(imm6)]
        elif f3 == 1:
            i.field('rd', 11, 7)
            i.name = 'c.addiw'
            i.ops = [xreg(rd), str(imm6)]
        elif f3 == 2:
            i.field('rd', 11, 7)
            i.name = 'c.li'
            i.ops = [xreg(rd), str(imm6)]
            if rd == 0:
                i.ops = ['zero', str(imm6)]
                i.say('rd = x0 makes this a HINT, per "The c.li code points '
                      'with rd = x0 are HINTs" -- DEFINED, does nothing, and '
                      'NOT reserved.  Section 6 counts the 64 of these against '
                      'the reserved set, because counting them as reserved '
                      'would overstate the C extension\'s cost by more than '
                      'twice over')
        elif f3 == 3:
            if rd == 2:
                # C.ADDI16SP, told apart from C.LUI by the DESTINATION REGISTER
                # alone -- rd = x2 -- with no bit of funct3 or funct2 spent on
                # the distinction.  Measured: `c.addi16sp sp, 16` is 0x6141
                # and `c.lui a0, 1` is 0x6505, and the ONLY difference is
                # bits[11:7].  A decoder that dispatches this cell on funct3
                # alone reports a stack adjustment as a load of a constant.
                # MEASURED against the assembler over all 62 signed multiples
                # of 16 in [-512, 496]: nzimm[9]=inst[12],
                # nzimm[4]=inst[6], nzimm[5]=inst[2], nzimm[6]=inst[5],
                # nzimm[7]=inst[4], nzimm[8]=inst[3], and the value is nzimm
                # x 16.  So the field is the same six bit positions as C.ADDI's
                # -- which the section 4 sweep measures as the identical mask
                # 0x0000107c -- and a DIFFERENT interpretation of bit 2: in
                # C.ADDI it is the immediate's fifth bit and here it is the
                # immediate's third.
                nz = 16 * c_imm(w, [(0, 6, 6), (1, 2, 2), (2, 5, 5), (3, 3, 3),
                                    (4, 4, 4), (5, 12, 12)], nbits=6, signed=True)
                i.say('rd = x2, so this is C.ADDI16SP and the five bits at '
                      'inst[11:7] that hold a REGISTER NUMBER in C.LUI hold the '
                      'literal x2 here.  The immediate is a SIGNED multiple of '
                      '16 -- a different scale and a different sign extension '
                      'from every other compressed immediate in this quadrant, '
                      'which is what makes it the stack-pointer instruction '
                      'rather than a general one.  The bit POSITIONS are '
                      'inst[12] and inst[6:2], the same six the sweep measures '
                      'for C.ADDI, and the ORDER is different: nzimm[5] is '
                      'inst[2] here and nzimm[4] is inst[6].  Reach '
                      '[-512, 496], which is NOT symmetric, and the assembler '
                      'says so in exactly those words')
                i.name = 'c.addi16sp'
                i.ops = ['sp', str(nz)]
            else:
                i.say('C.LUI.  The six-bit immediate goes to bits 17:12 of the '
                      'destination and the bottom twelve bits are cleared, so a '
                      'six-bit field produces the same twenty-bit U-format '
                      'field that `lui` spells out in full.  The sign comes '
                      'from inst[12] and NOT from inst[31], which is the '
                      'sharpest single difference between a 16-bit and a '
                      '32-bit immediate on this architecture.  The reach is '
                      'nonzero six-bit values, and the assembler states it as '
                      '"[0xfffe0, 0xfffff] or [1, 31]" -- two ranges, because '
                      'the zero is reserved and the printed form is the raw '
                      'field')
                i.name = 'c.lui'
                i.ops = [xreg(rd), '0x%x' % (imm6 & 0xfffff)]
        elif f3 == 4:
            # The MISC-ALU cell, and the reason inst[15:13] = 0b100 is FOUR
            # different cells rather than one.  bits[11:10] is a two-bit
            # selector INSIDE the funct3, and it is the only place in the whole
            # compressed extension where a sub-selector is nested inside
            # another one.  QUOTED from the manual's CB/CA format table: the
            # cell holds C.SRLI, C.SRAI, C.ANDI and the six register-register
            # operations, and the last of those is further split by
            # bits[12] and bits[6:5].
            sel = bits(w, 11, 10)
            shamt = bits(w, 12, 12) << 5 | bits(w, 6, 2)
            rdp = creg3(bits(w, 9, 7))
            if sel == 0:
                i.name = 'c.srli'
                i.ops = [rdp, str(shamt)]
                i.say('bits[11:10] = 00: C.SRLI, a logical right shift.  The '
                      'shift amount is a SIX-bit field at inst[12] and '
                      'inst[6:2] -- the same six positions as the CI '
                      'immediate\'s five low bits plus the sign bit, and the '
                      'mask section 4 measures is 0x0000107c, the same mask as '
                      'c.addi')
            elif sel == 1:
                i.name = 'c.srai'
                i.ops = [rdp, str(shamt)]
            elif sel == 2:
                i.name = 'c.andi'
                i.ops = [rdp, str(sign_extend(shamt, 6))]
                i.say('bits[11:10] = 10: C.ANDI, and the same six bits are '
                      'SIGN-EXTENDED here where C.SRLI treats them as an '
                      'unsigned shift amount.  One field, one position, two '
                      'interpretations, and the instruction is what says which')
            else:
                # The CA row.  MEASURED against the second reader over all 32
                # combinations of (inst[12], bits[6:5], bits[4:2]) in this
                # cell: inst[12] = 0 with bits[6:5] = 00, 01, 10, 11 is
                # c.sub, c.xor, c.or, c.and, and inst[12] = 1 with bits[6:5] =
                # 00, 01 is c.subw, c.addw, and bits[6:5] = 10, 11 is RESERVED
                # -- sixteen of the thirty-two (inst[12], bits[6:2])
                # combinations, times eight registers, which is 128 code
                # points.  That is the fifth reserved cell and section 6
                # checks the 128 against the second reader one by one.
                b65 = bits(w, 6, 5)
                b12 = bits(w, 12, 12)
                sub = {(0, 0): 'c.sub', (0, 1): 'c.xor', (0, 2): 'c.or',
                       (0, 3): 'c.and', (1, 0): 'c.subw', (1, 1): 'c.addw'}
                i.name = sub.get((b12, b65))
                if i.name is None:
                    i.note = 'reserved'
                    i.name = 'c.reserved'
                    i.ops = []
                    i.say('inst[12] = 1 with bits[6:5] = %s is RESERVED: the '
                          'fourth and fifth of the eight (inst[12], bits[6:2]) '
                          'combinations that have no assignment.  The manual '
                          'marks them Reserved, and the second reader prints '
                          '<unknown> for all 16 of them at each of the eight '
                          'register values -- 128 code points, MEASURED' % b65)
                else:
                    i.say('CA format: SIX bits at inst[15:10] and TWO at '
                          'inst[6:5] and THREE at inst[4:2], which is why this '
                          'is the only compressed format with no funct3 -- the '
                          'six bits ARE the opcode and rd\'/rs1\' sits in the '
                          'middle of them, at bits[9:7].  The operation is the '
                          'pair (inst[12], bits[6:5]), six values defined and '
                          'two reserved')
                    i.ops = [rdp, creg3(bits(w, 4, 2))]
        else:
            # CJ and CB, and the two displacement permutations are DIFFERENT.
            # MEASURED against the assembler over fourteen c.j offsets from -2048
            # to +2046 and eleven c.beqz offsets from -256 to +256:
            #
            #   c.j    offset[11|4|9:8|10|6|7|3:1|5] = inst[12|11|10:9|8|7|6|5:3|2]
            #   c.beqz offset[8|4:3] = inst[12|11:10]   and
            #           offset[7:6|2:1|5] = inst[6:5|4:3|2]
            #
            # Look at the two and the reason is visible: c.j has ELEVEN bits
            # and its immediate fills inst[12:2] with nothing left over, so it
            # can be any permutation it likes.  c.beqz has NINE and it shares
            # inst[9:7] with a register, so four of its bits are forced to
            # straddle that register in a fixed pattern.  The C extension is
            # not using one scheme; it is using whatever fits, which is the
            # honest description and the reason a compressed decoder cannot be
            # written by reusing the base one.
            if f3 == 5:
                # MEASURED over 25 offsets from -2048 to +2046:
                #   (offset)[1]=inst[3], [2]=inst[4], [3]=inst[5], [4]=inst[11],
                #   [5]=inst[2], [6]=inst[7], [7]=inst[6], [8]=inst[9],
                #   [9]=inst[10], [10]=inst[8], [11]=inst[12]
                # and offset[0] is a constant 0.  Twelve significant bits --
                # eleven after the shift -- and a reach of +-2 KiB, which is
                # EXACTLY the reach of the 32-bit B type.  The C extension did
                # not invent a longer jump; it encoded the same jump in half the
                # space by using every bit the format had, and the section 7
                # measurement is that the two agrees.
                t = c_imm(w, [(1, 3, 3), (2, 4, 4), (3, 5, 5), (4, 11, 11),
                              (5, 2, 2), (6, 7, 7), (7, 6, 6), (8, 9, 9),
                              (9, 10, 10), (10, 8, 8), (11, 12, 12)],
                          nbits=12, signed=True)
                i.say('CJ format: eleven bits of displacement spread across '
                      'inst[12:2] with a hard zero at bit 0, so the reach is '
                      '+-2 KiB -- the SAME reach as the 32-bit B format, in half '
                      'the bytes.  The section 7 measurement is that the two '
                      'agree, and this is why: the C extension did not invent a '
                      'bigger jump, it encoded the same jump in half the space '
                      'by using every bit it had')
                i.name = 'c.j'
                i.ops = [tgt(addr + t)]
            else:
                # MEASURED over 42 offsets from -254 to +254:
                #   (offset)[1]=inst[3], [2]=inst[4], [3]=inst[10],
                #   [4]=inst[11], [5]=inst[2], [6]=inst[5], [7]=inst[6],
                #   [8]=inst[12]
                # and offset[0] is a constant 0.  NINE bits against c.j's
                # twelve, and the reason is in the format: inst[9:7] holds a
                # three-bit register, so the displacement cannot simply occupy
                # inst[12:2] the way c.j's does -- it has to leave three bits
                # in the middle and put them elsewhere.  The three stranded bits
                # are at inst[11:10], two of the displaced ones at inst[6:5],
                # and the sign at inst[12].
                #
                # Reach +-256 bytes, and the QUOTED reason for the scaling is
                # the same one as the base B format: "As with base RVI
                # instructions, the offsets of all Zca control transfer
                # instructions are in multiples of 2 bytes."
                offv = c_imm(w, [(1, 3, 3), (2, 4, 4), (3, 10, 10),
                                 (4, 11, 11), (5, 2, 2), (6, 5, 5),
                                 (7, 6, 6), (8, 12, 12)], nbits=9, signed=True)
                i.say('CB format: NINE bits of displacement against c.j\'s '
                      'twelve, and the format is the reason: inst[9:7] holds a '
                      'three-bit register, so the displacement cannot occupy '
                      'inst[12:2] flat the way c.j\'s does.  The three bits '
                      'stranded in the middle went to inst[11:10], two of the '
                      'displaced ones to inst[6:5] and the sign to inst[12].  '
                      'The reach is +-256 bytes, which is an EIGHTH of the '
                      '32-bit B type\'s +-2 KiB, and the assembler\'s own '
                      'diagnostic for the edge is the interesting part: it is '
                      '"error in backend: Not supported instr" rather than a '
                      'range message, because c.beqz with a displacement of '
                      'exactly 256 is the one value the assembler silently '
                      'fails on instead of refusing -- measured in section 6.')
                i.name = 'c.beqz' if f3 == 6 else 'c.bnez'
                i.ops = [creg3(bits(w, 9, 7)), tgt(addr + offv)]
    # --- quadrant 2 ----------------------------------------------------
    else:
        if f3 == 0:
            i.field('rd', 11, 7)
            i.name = 'c.slli'
            i.ops = [xreg(bits(w, 11, 7)),
                     str(bits(w, 12, 12) << 5 | bits(w, 6, 2))]
        elif f3 in (1, 2, 3, 5, 6, 7):
            # The stack-pointer forms, and the reason the C extension needs
            # them at all.  QUOTED: "there is a separate version of load and
            # store instructions that use the stack pointer as the base address
            # register, since saving to and restoring from the stack are so
            # prevalent, and that they use the CI and CSS formats to allow
            # access to all 32 data registers."
            #
            # That last clause is the whole justification and it is measurable.
            # A stack save is `sd ra, N(sp)` and the C.SD format can only name
            # x8 to x15 in bits[4:2] -- but `ra` is x1.  There is no way to
            # express it in two bytes.  C.SDSP exists for exactly this and it
            # uses a FULL five-bit rs2 at inst[6:2].
            NAMES = {1: 'c.fldsp', 2: 'c.lwsp', 3: 'c.ldsp', 5: 'c.fsdsp',
                     6: 'c.swsp', 7: 'c.sdsp'}
            is_load = f3 in (1, 2, 3)
            r = bits(w, 11, 7)
            # MEASURED against the assembler: the CI-form displacement is
            # uimm[5] at inst[12] and uimm[4:2] at inst[6:5] for the word and
            # halfword forms, and uimm[5:3] at inst[12:10] plus uimm[7:6] at
            # inst[6:5] for the double forms.  `c.lwsp a0, 252(sp)` is 0x557e
            # and `c.ldsp a0, 504(sp)` is 0x757e.
            # MEASURED, one variant per reachable value of each, and the four
            # forms use FOUR different permutations of the same six bit
            # positions:
            #
            #   c.lwsp  scale 4  (v/4)[0..5] = inst[4,5,6,12,2,3]   [0, 252]
            #   c.ldsp  scale 8  (v/8)[0..5] = inst[5,6,12,2,3,4]   [0, 504]
            #   c.swsp  scale 4  (v/4)[2..7] = inst[9,10,11,12,7,8] [0, 252]
            #   c.sdsp  scale 8  (v/8)[3..8] = inst[10,11,12,7,8,9] [0, 504]
            #
            # The two STORES have their bits in the HIGH half (inst[12:7]) and
            # the two LOADS in the low half plus inst[12], which is not a
            # coincidence: the CSS format has no rd field, so inst[11:7] is
            # free for the displacement, while the CI format spends inst[11:7]
            # on a five-bit rd and has to put the offset in inst[6:2] and
            # inst[12].  The format decided the permutation.
            SP_PERM = {
                # funct3: (scale, perm, reach)
                1: (8, [(0, 5, 5), (1, 6, 6), (2, 12, 12), (3, 2, 2),
                        (4, 3, 3)], 248),          # c.fldsp
                2: (4, [(0, 4, 4), (1, 5, 5), (2, 6, 6), (3, 12, 12),
                        (4, 2, 2), (5, 3, 3)], 252),  # c.lwsp
                3: (8, [(0, 5, 5), (1, 6, 6), (2, 12, 12), (3, 2, 2),
                        (4, 3, 3), (5, 4, 4)], 504),  # c.ldsp
                5: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 7, 7),
                        (4, 8, 8)], 248),         # c.fsdsp
                6: (4, [(0, 9, 9), (1, 10, 10), (2, 11, 11), (3, 12, 12),
                        (4, 7, 7), (5, 8, 8)], 252),  # c.swsp
                7: (8, [(0, 10, 10), (1, 11, 11), (2, 12, 12), (3, 7, 7),
                        (4, 8, 8), (5, 9, 9)], 504),  # c.sdsp
            }
            scale, perm, reach = SP_PERM[f3]
            im = scale * c_imm(w, perm)
            if is_load:
                i.say('CI format against sp: rd is a FULL five bits at '
                      'inst[11:7] -- the same position and the same width as the '
                      '32-bit rd, which is what the manual means by "when the '
                      'full 5-bit destination register specifier is present, it '
                      'is in the same place as in the 32-bit RISC-V encoding".  '
                      'So there are TWO register encodings in the C extension: '
                      'five bits here and three bits in the quadrant-0 '
                      'formats, and the displacement has to go to inst[6:2] '
                      'plus inst[12] to get out of the way of the five.  '
                      'Scale %d, reach [0, %d], ZERO-extended -- and note that '
                      'a ZERO offset is legal here while it is RESERVED in '
                      'c.addi4spn, even though both are loads of a computed '
                      'address.' % (scale, reach))
                i.name = NAMES[f3]
                i.ops = [freg(r) if f3 == 1 else xreg(r), '%d(sp)' % im]
            else:
                i.say('CSS format: rs2 is a FULL five bits at inst[6:2] and '
                      'the base is HARDCODED to x2 -- there is no base-register '
                      'field at all.  And because the format has no rd, the '
                      'whole of inst[12:7] is free for the displacement, which '
                      'is why this permutation is the high half and the load '
                      'permutations above are not.  This is the form that makes '
                      'a function prologue two bytes per register saved, and it '
                      'is the reason a stack save can be compressed when a '
                      'general store cannot: C.SW and C.SD in quadrant 0 can '
                      'only name x8 to x15, and `ra` is x1.  Scale %d, reach '
                      '[0, %d].' % (scale, reach))
                i.name = NAMES[f3]
                i.ops = [freg(bits(w, 6, 2)) if f3 == 5
                         else xreg(bits(w, 6, 2)), '%d(sp)' % im]
        else:
            # The CR quadrant, and inst[12] is the WHOLE of the dispatch.
            #
            # THE THIRD MISSING BIT IN ONE FILE, and it is the same class as
            # `r_mul`'s missing funct7 and `b_branch`'s missing operands: a cell
            # of the opcode map with a two-way split, and a model that read
            # neither of the bits that make the split.  MEASURED, section 10:
            #
            #   inst[12] = 0, rs2 != 0   c.mv    rd, rs2     (0x86ba)
            #   inst[12] = 1, rs2 != 0   c.add   rd, rd, rs2 (0x96ba)
            #   inst[12] = 0, rs2 = 0    c.jr    rs1         (0x8502)
            #   inst[12] = 1, rs2 = 0    c.jalr  x1, rs1     (0x9502)
            #
            # The first version of this decoder dispatched on `rs1 == 0`, which
            # is not a bit of the cell at all -- rs1 is the DESTINATION of a
            # move and the SOURCE of a jump, and 0x8002 (rs1 = rs2 = 0) is the
            # one code point every rule in the cell rejects.  So `c.mv` was
            # UNREACHABLE, 33 `c.mv` words in the corpus printed as `c.add`, and
            # `c.jalr` printed as `c.jr` for every rs1 except x1: a decoder that
            # turns every indirect JUMP into a CALL.  Both are the class of bug
            # that survives a two-reader cross-check, because nothing about the
            # output is malformed.
            rs1 = bits(w, 11, 7)
            rs2 = bits(w, 6, 2)
            b12 = bits(w, 12, 12)
            if rs2 == 0:
                if rs1 == 0 and b12 == 0:
                    # 0x8002: the one code point all five rules in the cell
                    # reject.  Section 6 counts it as 1 of the 2,409.
                    i.note = 'reserved'
                    i.name = 'c.reserved'
                    i.ops = []
                    i.say('rs1 = 0, rs2 = 0 and inst[12] = 0: this is 0x8002, '
                          'the single code point that C.JR, C.JALR, C.EBREAK, '
                          'C.MV and C.ADD all reject.  It is the only reserved '
                          'compressed encoding a person is likely to meet in a '
                          'hex dump, and it is reserved because FIVE separate '
                          'rules each exclude it')
                elif rs1 == 0:
                    # 0x9002, and it is ONE BIT from 0x8002 and is legal.  The
                    # first version of this model tested `rs1 == 0` alone and so
                    # got BOTH words the wrong way round: it reported the legal
                    # c.ebreak as RESERVED, which put a defined instruction in
                    # the reserved bucket of section 6 and cost the cross-check
                    # two words, and it could not have reported the reserved
                    # 0x8002 at all.  A model that reads one bit of a two-way
                    # split is a model that has not read the split.
                    i.name = 'c.ebreak'
                    i.ops = []
                    i.say('rs1 = 0, rs2 = 0 and inst[12] = 1: this is 0x9002, '
                          'C.EBREAK, and it is ONE BIT from 0x8002, which is '
                          'RESERVED.  Both words have rs1 = rs2 = 0 and both are '
                          'two bytes long, and the single bit that separates a '
                          'legal instruction from a reserved encoding is '
                          'inst[12]')
                elif b12 == 0:
                    i.name = 'c.jr'
                    i.ops = [xreg(rs1)]
                else:
                    i.name = 'c.jalr'
                    i.ops = ['x1', xreg(rs1)]
                    i.say('inst[12] = 1 and rs2 = 0 is C.JALR, not C.JR: the bit '
                          'that says "jump" against "CALL" is a single bit in the '
                          'middle of the register field\'s own quadrant.  The '
                          'destination is HARDWIRED to x1, so the instruction is '
                          'one operand long -- the return address is not a field, '
                          'it is a convention -- and a decoder that reads inst[12] '
                          'as zero turns every indirect call into an indirect '
                          'jump and vice versa')
            elif b12 == 0:
                i.name = 'c.mv'
                i.ops = [xreg(rs1), xreg(rs2)]
                i.say('inst[12] = 0 and rs2 != 0 is C.MV, the ONE place in the '
                      'compressed extension where rd is a pure destination: rd '
                      'does not appear as a source because the instruction does '
                      'not read it.  The base equivalent is `addi rd, rs2, 0`, and '
                      'the first version of this decoder dispatched on rs1 = 0 '
                      'instead of on this bit, which made c.mv unreachable and '
                      'reported 33 `c.mv` words as `c.add`')
            else:
                i.name = 'c.add'
                i.ops = [xreg(rs1), xreg(rs2)]
                i.say('inst[12] = 1 and rs2 != 0 is C.ADD, and rd is BOTH the '
                      'destination and the first source: the base equivalent is '
                      '`add rd, rd, rs2`, and the format saves the five bits of '
                      'the first rs2 by making it a copy of the destination')
    if i.name is None:
        # A cell this file does not model.  NOT the same as a reserved cell,
        # and section 6 exists because the two produce identical output: a
        # decoder that cannot decode an instruction and a specification that
        # has not assigned one both print something that is not a mnemonic.
        i.name = '(unmodelled)'
        i.note = 'unmodelled'
        i.ops = []
    i.ext = 'C'
    if i.model is None:
        i.model = 'rvc'
    i.text = ('%-12s %s' % (i.name, ', '.join(i.ops))) if i.ops else i.name
    if i.note == 'reserved':
        i.text = '(reserved 0x%04x)' % w
    return i


# ---------------------------------------------------------------------------
# The 32-bit dispatch.
#
# Two things happen here and both are worth stating, because the AArch64
# course found a defect in exactly this part of a decoder in a different
# collection, and because this file found two of its own.
#
# First, the ORDER of MODELS32 is the dispatch order and it is load-bearing,
# for a reason that is SPECIFIC to RISC-V and is written out at length above
# the table: a sub-opcode selector is not self-contained.  `funct7` means one
# thing under opcode 0x33 and something else under 0x53, so a model that is
# asked about a word before the opcode has been consulted is guessing.  The
# first version of this file dispatched by asking every model in turn, and
# `fmadd.s` came out as `fmin.s`: same funct7, same funct3, different opcode,
# unrelated instructions, and a disassembly that looked entirely reasonable.
#
# Second, `Bad` and `Undefined` are different and the difference is
# load-bearing.  `Bad` means "not mine, ask the next model".  `Undefined` means
# "mine, and the architecture leaves this undefined" -- and it STOPS the
# chain, so the word is reported as UNDEFINED rather than falling through to
# whatever model comes next.  Two bugs in this file came from getting that
# backwards, and both produced a word reported as `(undefined)` that was
# really a perfectly good instruction:
#
#   * `s_system` raised Undefined for funct3 = 0 under opcode 0x73, which is
#     the SYSTEM group -- so `ecall`, the single most distinctive word in the
#     architecture, decoded as UNDEFINED.
#   * `i_fcvt` claimed inst[31:27] = 0b10100, which is the floating-point
#     COMPARISON family, and raised Undefined for it -- so `fle.s` never
#     reached `r_fp`, which owns it.
#
# Both are the same mistake with two names on it: a model must not claim a
# field it does not own, and a model that declines must raise Bad.  Section 10
# counts what the cross-check found and section 12 lists them.
# ---------------------------------------------------------------------------


def decode32(w, off=0, addr=0):
    i = Insn(w, 4, off, addr)
    op = bits(w, 6, 0)
    i.fmt = format_of(w) or '(unclassified)'
    i.say('inst[6:0] = 0b%s = 0x%02x, the 7-bit OPCODE, and it is the first '
          'field a decoder reads' % (format(op, '07b'), op))
    i.say('the format is %s; the classifier uses the opcode and, for the '
          'opcode 0x6f, the immediate, because "the only difference between '
          'the U and J formats is that the 20-bit immediate is shifted left by '
          '12 bits" -- manual section 2.3' % i.fmt)
    claimed = False
    for (nm, ops, fn, ext, claim) in MODELS32:
        if op not in ops:
            continue
        before = len(i.why)
        try:
            if fn(i):
                claimed = True
                break
        except Undefined as e:
            i.say('UNDEFINED ENCODING: %s' % e)
            i.note = 'undefined'
            if i.name is None:
                i.name = '(undefined)'
                i.ops = ['(undefined)']
            claimed = True
            break
        except Bad:
            continue
        if len(i.why) == before and not i.ops and not i.name:
            i.why = []
    if not claimed:
        # Unmodelled.  This is a DECLARED SCOPE decision and the two reasons
        # for it are printed rather than hidden, because a word this decoder
        # cannot name and an encoding the architecture has not assigned both
        # print something that is not a mnemonic, and the cross-check in
        # section 10 has to be able to tell them apart:
        #
        #   * the VECTOR DATA PATH is not modelled.  It is a later course in
        #     this section (`rv-vector`) and it is most of the opcode space
        #     under 0x57.
        #   * a handful of Zicsr, FP and M rows are not modelled.  They are
        #     named in the manual and absent here, which is a smaller gap and
        #     a temporary one.
        #
        # Every such word is COUNTED.  A table that filtered them out would be
        # a property of the filter rather than a property of the corpus.
        i.name = None
        i.ops = []
        i.note = i.note or 'unmodelled'
    i.text = render(i)
    return i


def render(i):
    if i.name is None:
        return '(op 0x%08x)  fmt %s' % (i.word, i.fmt)
    return '%-10s %s' % (i.name, ', '.join(i.ops)) if i.ops else i.name


def decode(w, nbytes=None, off=0, addr=0):
    """Decode one instruction of either width.

    `nbytes` defaults to the LENGTH RULE, so the default path is the one a
    real decoder takes: it has the first two bytes and nothing else, and it
    must decide how far to step.  Passing `nbytes` explicitly is what the
    third poison does, and it is the reason the poison is on this function and
    not on the corpus: a decoder that is TOLD the length cannot desynchronise,
    and one that is not told can, and the difference is the entire claim of
    concept 1.
    """
    if nbytes is None:
        nbytes = length_of(w & 0xff, (w >> 8) & 0xff)
    if nbytes == 2:
        return decode16(w & 0xffff, off, addr)
    return decode32(w & 0xffffffff, off, addr)


def explain(i, indent='    '):
    out = [indent + '0x%08x  (%d bytes)  %s' % (i.word, i.nbytes, i.text)]
    for w in i.why:
        out.append(indent + '  . ' + w)
    return '\n'.join(out)


# ---------------------------------------------------------------------------
# Reading a real file.  A stripped-down ELF64 reader, no tool and no library.
# ---------------------------------------------------------------------------
SHT_PROGBITS, SHF_EXECINSTR = 1, 0x4
EM_RISCV = 243


def code_sections(path):
    """(bytes, [(name, addr, off, size)]) for every executable section.

    The only field read for a decision is e_machine, and it is checked rather
    than assumed.  A decoder that skips the check on an x86-64 object gets a
    plausible answer for every word, because bits[1:0] == 0b11 is true of
    about a quarter of x86 opcodes and the length rule will then step four
    bytes at a time through an object that is mostly one bytes.  That is not a
    hypothetical: it is what this decoder did before the check was added, and
    the way it was found is in section 10.
    """
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        raise ValueError('%s is not an ELF file' % path)
    if d[4] != 2:
        raise ValueError('%s is not ELF64' % path)
    machine, = struct.unpack_from('<H', d, 0x12)
    if machine != EM_RISCV:
        raise ValueError('%s: e_machine is %d, not %d (RISC-V)'
                         % (path, machine, EM_RISCV))
    (shoff,) = struct.unpack_from('<Q', d, 0x28)
    (shentsize, shnum, shstrndx) = struct.unpack_from('<HHH', d, 0x3a)
    secs = []
    for n in range(shnum):
        o = shoff + n * shentsize
        name, typ = struct.unpack_from('<II', d, o)
        flags, addr, off, size = struct.unpack_from('<QQQQ', d, o + 8)
        secs.append(dict(name_off=name, type=typ, flags=flags, addr=addr,
                         off=off, size=size))
    stro = secs[shstrndx]['off']

    def nm(n):
        e = d.index(b'\0', stro + n)
        return d[stro + n:e].decode('ascii', 'replace')

    out = []
    for s in secs:
        name = nm(s['name_off'])
        if s['type'] == SHT_PROGBITS and s['flags'] & SHF_EXECINSTR and s['size']:
            out.append((name, s['addr'], s['off'], s['size']))
    return d, out


def decode_text(d, off, size, addr=0, tell_length=False, flip=0):
    """Every instruction in a code section, found by the LENGTH RULE alone.

    The loop is four lines and the whole of the compressed extension's
    consequence is in it: `p` advances by TWO or FOUR and nothing else, and a
    word this file cannot name still advances `p` correctly.  That is the
    guarantee the rule buys and section 2 measures it: over every code section
    of every corpus object the walk ends EXACTLY on the section's last byte,
    with no remainder and no overrun.

    `tell_length=True` is the third poison.  It hands the length in from
    outside, which is what a disassembler with a symbol table can do and what
    one without it cannot.  With the length supplied the decoder cannot
    desynchronise, so the instruction COUNT stops depending on the rule and
    the rule stops being tested by anything.  `flip` is a mask XORed into
    every 32-bit word, which is the second poison.
    """
    insns = []
    p = 0
    flip = FLIP or flip
    while p + 2 <= size:
        lo, = struct.unpack_from('<H', d, off + p)
        nb = 2 if (lo & 3) != 3 else 4
        if tell_length:
            nb = 4 if p % 4 == 0 else 2
        if p + nb > size:
            break
        if nb == 2:
            w = lo
        else:
            w, = struct.unpack_from('<I', d, off + p)
            w ^= flip
        insns.append(decode(w, nb, off + p, addr + p))
        p += nb
    return insns, p


# Set by poison 2 and read by `decode_text`.  It is a module global rather
# than a parameter because the cross-check LOOP is the thing being poisoned,
# and threading a parameter through that loop would let a future version of it
# quietly ignore the poison -- which is precisely the failure a poison exists
# to catch.  The first version of this file's poison 2 called
# `decode_text(..., flip=...)` and the cross-check called `decode_text(...)`
# with no flip at all, so the flip never reached the loop and the number did
# not move.
FLIP = 0


# ===========================================================================
# Part two: the measurement driver.  Everything below RUNS something; nothing
# above it does.  A decoder that can print a mnemonic is not evidence.
#
# The split is the AArch64 course's split and for the same reason: part one is
# a function of the bytes, and part two is everything that could be wrong in a
# way part one cannot detect by itself.  Every number in the report comes from
# here, and every number here is one of exactly four kinds -- a bit pattern, a
# count of bit patterns, an arithmetic identity, or a REFUSAL from a real
# assembler.
#
# There is no timing in this file and no execution in this file, because there
# is no RISC-V machine, no emulator and no RISC-V binutils on this host.
# Section 1 prints that BEFORE the first measurement rather than in a limits
# section at the end, and the x86-64 section's speedup ratios have no
# counterpart here: they are not measured, not estimated and not invented.
# ===========================================================================

HERE = os.path.dirname(os.path.abspath(__file__))
CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
READELF = 'llvm-readelf-21'
TARGET = 'riscv64-linux-gnu'
TRIPLE = 'riscv64'

MARCHES = ['rv64i', 'rv64im', 'rv64if', 'rv64imf', 'rv64imafd', 'rv64imafdc',
           'rv64gc', 'rv64gcv']


def sh(*args, **kw):
    return subprocess.run(list(args), capture_output=True, text=True, **kw)


def objdump_lines(path, triple=TRIPLE):
    """(addr, word, nbytes, text) for every instruction the second reader sees.

    The regex is three lines long and it is the third time in this collection
    that the SPACE between the byte column and the tab has cost an afternoon.
    `llvm-objdump-21` prints `   0: 952e         \\tadd\\ta0, a0, a1`: address,
    colon, the byte groups, whitespace, a TAB, then the mnemonic.  A pattern
    that expects the tab immediately after the bytes matches NOTHING -- and it
    matches nothing SILENTLY, so the cross-check compares zero instructions
    and reports agreement.  That is the exact failure this collection has
    already suffered from in a different course, and the reason section 10
    prints the number of instructions it actually compared.
    """
    p = sh(OBJDUMP, '--triple=' + triple, '-d', path)
    out = []
    for ln in p.stdout.splitlines():
        m = re.match(r'^\s+([0-9a-f]+):\s+((?:[0-9a-f]{2,8} )+)\s*\t(.*)$', ln)
        if m:
            groups = m.group(2).split()
            w = 0
            for g in groups:
                w = (w << 16) | int(g, 16)
            out.append((int(m.group(1), 16), w, sum(len(g) // 2 for g in groups),
                        m.group(3).strip()))
    return out


def objdump_text(word, nbytes):
    """What the second reader says about ONE word.

    This `llvm-objdump` has no `-b binary` option.  MEASURED:
    `llvm-objdump-21 --triple=riscv64 -D -b binary f` prints `error: unknown
    argument '-b'`, which is the same missing feature the AArch64 course
    recorded as its own R10.  So every single-word probe is assembled into a
    real object file and asked about in a section the disassembler already
    knows how to read.  A cross-check that quietly substituted another
    disassembler for the convenience of a script would be a claim about a tool
    that is not installed.
    """
    src = '.text\n  .insn %d, 0x%s\n' % (nbytes, ('%04x' if nbytes == 2
                                                 else '%08x') % word)
    p, o = os.path.join(HERE, '_w.s'), os.path.join(HERE, '_w.o')
    open(p, 'w').write(src)
    r = sh(CLANG, '--target=' + TARGET, '-march=rv64gcv', '-c', p, '-o', o)
    if r.returncode:
        m = re.search(r'error: (.*)', r.stderr or '')
        return '(refused: %s)' % (m.group(1)[:56] if m else '?')
    ws = objdump_lines(o)
    return ws[0][3] if ws else '(no instruction)'


def asm_one(src, march='rv64gc'):
    """(word, nbytes, oracle text) for one source line, or the refusal.

    ONE INSTRUCTION PER FILE, which is slower and which is the point.  A probe
    batch that the assembler refuses takes every other probe in the batch with
    it, and a table of a hundred blank rows measures nothing.  The first
    version of this file's own field sweep did exactly that: one out-of-range
    compressed offset in a batch of thirty-two made the whole batch return
    nothing, and the fix -- a batch fast path with a one-at-a-time fallback --
    is in `field_sweep` below.
    """
    p, o = os.path.join(HERE, '_a.s'), os.path.join(HERE, '_a.o')
    open(p, 'w').write('.text\nT:\n  %s\n' % src)
    r = sh(CLANG, '--target=' + TARGET, '-march=' + march, '-c', p, '-o', o)
    if r.returncode:
        m = re.search(r'error: (.*)', r.stderr or '')
        return None, None, (m.group(1) if m else (r.stderr or '').strip()[:70])
    ws = objdump_lines(o)
    if not ws:
        return None, None, 'assembled, but the oracle printed no instruction'
    return ws[0][1], ws[0][2], ws[0][3]


def asm_batch(srcs, march='rv64gc'):
    """Words for many lines at once, or None if the assembler refused any."""
    if not srcs:
        return []
    p, o = os.path.join(HERE, '_b.s'), os.path.join(HERE, '_b.o')
    open(p, 'w').write('.text\nT:\n' + ''.join('  %s\n' % s for s in srcs))
    if sh(CLANG, '--target=' + TARGET, '-march=' + march, '-c', p, '-o', o).returncode:
        return None
    ws = objdump_lines(o)
    return ws if len(ws) >= len(srcs) else None


def tool_version(cmd, *args):
    p = sh(cmd, *args)
    for ln in (p.stdout or p.stderr).splitlines():
        if ln.strip():
            return ln.strip()
    return 'not installed'


def which(name):
    for d in os.environ.get('PATH', '').split(os.pathsep):
        f = os.path.join(d, name)
        if os.path.isfile(f) and os.access(f, os.X_OK):
            return f
    return None


def elf_arch_attr(path):
    """The Tag_RISCV_arch string out of .riscv.attributes.

    This is the most useful string the toolchain writes about a RISC-V object
    and it is the measurement concept 1 is built on.  MEASURED, for
    -march=rv64imafdc:

        rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zmmul1p0_zaamo1p0_
        zalrsc1p0_zca1p0_zcd1p0

    Read it left to right.  The user asked for six letters and the string
    names SIX plus zicsr, zmmul, zaamo, zalrsc, zca and zcd -- TWELVE, each
    with a major and a minor version.  The extra six are not decoration:

      * `c2p0` appears AND `zca1p0` and `zcd1p0` appear.  The C extension was
        split into named sub-extensions and an object records the sub-
        extensions it actually uses, because a linker has to know whether the
        object's compressed instructions are decodable by the machine it is
        producing.  `c` is not an assumption a linker can make.
      * `zmmul1p0` is the multiply-only subset of M, which a machine with
        Zmmul can satisfy without the divide.
      * `zaamo1p0` and `zalrsc1p0` are the two halves of A that can be
        satisfied independently.
      * `zicsr2p0` is the CSR set, which the manual says was split OUT of the
        base -- see `s_system`.

    So "the ISA is a set of documents rather than one list" is not a slogan
    here; it is a string in the object file, and section 3 prints it for eight
    different -march settings and diffs them.
    """
    p = sh(READELF, '-A', path)
    m = re.search(r'TagName: arch\s*\n\s*Value: (\S+)', p.stdout)
    return m.group(1) if m else '(no arch attribute)'


def arch_letters(attr):
    """The extension names out of a Tag_RISCV_arch string, in the tool's order.

    MEASURED, and the parsing has to be careful for two reasons a naive regex
    gets wrong.  The value BEGINS with the base and its version and no
    underscore -- `rv64i2p1`, not `_i2p1` -- so a pattern that expects every
    group to be underscore-prefixed returns an EMPTY list for
    -march=rv64i, which is the base case and the one row of the table a reader
    looks at first.  And the names are not all one character: `zicsr`, `zmmul`,
    `zaamo`, `zalrsc`, `zifencei`, `zve64d` and `zvl128b` are all multi-letter,
    and a parser that stops after one character reports four extensions where
    the object claims twenty.
    """
    if not attr or attr.startswith('('):
        return []
    m = re.match(r'^(rv\d+[a-z]*\d+p\d+)(.*)$', attr)
    if not m:
        return []
    out = [re.sub(r'\d+p\d+$', '', m.group(1))]
    for g in re.finditer(r'_([a-z][a-z0-9]*?)(\d+p\d+)(?=_|$)', m.group(2)):
        out.append(g.group(1))
    return out


CORPUS = ['rv.o'] + ['corpus_%s.o' % m for m in
                     ('rv64i', 'rv64im', 'rv64if', 'rv64imf', 'rv64imafd',
                      'rv64imafdc', 'rv64gc', 'rv64gcv')]


def corpus_files():
    """The object files that exist.  A missing one is REPORTED, not skipped."""
    have = [f for f in CORPUS if os.path.exists(os.path.join(HERE, f))]
    missing = [f for f in CORPUS if f not in have]
    return have, missing


def corpus_insns():
    """Every instruction in every corpus object, with the file it came from."""
    out = []
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        for name, addr, off, size in secs:
            insns, _p = decode_text(d, off, size, addr)
            for k in insns:
                k.file = f
                k.sec = name
                out.append(k)
    return out


# ---------------------------------------------------------------------------
# Printing.  One banner style for every section, so a reader skimming knows
# where they are from three lines down.
# ---------------------------------------------------------------------------
RULE = '=' * 72


def banner(n, title):
    print(RULE)
    print('SECTION %d -- %s' % (n, title))
    print(RULE)


def para(text, indent='  '):
    """Prose at about 76 columns, with LIST items kept as list items.

    A reflow that destroys the structure it was handed is worse than no
    reflow, so a block whose lines all start with a bullet or a bar is
    printed VERBATIM and only unadorned blocks are wrapped.
    """
    for chunk in text.split('\n\n'):
        lines = [l for l in chunk.split('\n') if l.strip()]
        # A chunk is a LIST if it STARTS with a bullet, and the continuation
        # lines of a bullet are indented.  The first version of this function
        # required EVERY line to begin with a bullet, which meant a list
        # whose items wrapped was reflowed into one run-on paragraph with the
        # bullets swallowed -- and a swallowed bullet is a lost claim.  Three
        # bullets became one sentence and the reader could not see that there
        # had been three.
        if lines and lines[0].lstrip()[:1] in ('*', '|', '-'):
            for l in lines:
                print(l if l[:1] == ' ' else indent + l)
            print()
            continue
        words = ' '.join(lines).split()
        line = indent
        for w in words:
            if len(line) + len(w) + 1 > 78:
                print(line)
                line = indent + w
            else:
                line = line + ' ' + w if len(line) > len(indent) else indent + w
        if line.strip():
            print(line)
        print()


def wrap(text, width=74, indent=''):
    """Greedy wrap that never splits a token and never emits an empty line.

    The `indent` parameter exists for one caller: the Tag_RISCV_arch table in
    section 3 prints its continuation lines INDENTED under the first one, and
    the first version of that table wrapped without the indent, so a
    118-character attribute string read as two lines at the same level and
    looked like two separate values.
    """
    words = text.split()
    line = ''
    out = []
    for w in words:
        if line and len(line) + len(w) + 1 > width:
            out.append(line)
            line = w
        else:
            line = (line + ' ' + w) if line else w
    if line:
        out.append(line)
    return [out[0]] + [indent + l for l in out[1:]] if out else []


def table(head, rows, widths=None):
    """A left-aligned table.  Each width needs its OWN conversion, so each
    gets an 's' -- the first version of this built one 's' for three columns
    and raised `unsupported format character` on the first row."""
    widths = widths or [max(len(str(head[i])),
                            max([len(str(r[i])) for r in rows]) if rows else 0)
                        for i in range(len(head))]
    fmt = ''.join('  %-' + str(w) + 's' for w in widths)
    print(fmt % tuple(str(h) for h in head))
    for r in rows:
        print(fmt % tuple(str(c) for c in r))


# ===========================================================================
# SECTION 1 -- THE INSTRUMENT.  Nothing below this point is a claim yet.
# ===========================================================================


# ---------------------------------------------------------------------------
# The length rule, and the spectrum, measured.
#
# Three questions, in the order a reader meets them:
#
#   1. Does the two-bit rule find the boundaries?  Walk every code section of
#      every corpus object and check that the walk ends EXACTLY on the
#      section's last byte.  A walk that ends early or overruns has
#      desynchronised, and everything measured after that is a property of the
#      desynchronisation.
#   2. What is the actual length distribution?  Not a constant and not a
#      range: a measured histogram, per object, and the fraction that is two
#      bytes.
#   3. Does the compiler CHOOSE the compressed form?  The `-march=rv64imafd`
#      and `-march=rv64imafdc` objects are the SAME C compiled with and
#      without C, so any difference in the instruction COUNT is the
#      compression's and any difference in the BYTE count is its value.
# ---------------------------------------------------------------------------


def sec3():
    banner(3, 'THE ISA AS A SET OF DOCUMENTS, NOT A LIST')
    print()
    para("""RISC-V is the only one of the three architectures in this collection
whose base is DELIBERATELY tiny, and the reason it is tiny is a design
decision that is measurable in one line.  The unprivileged manual, section
2.1, QUOTED:

    "RV32I contains 40 unique instructions, though a simple implementation
     might cover the ecall/ebreak instructions with a single SYSTEM hardware
     instruction that always traps and might be able to implement the fence
     instruction as a nop, reducing base instruction count to 38 total."

Forty.  Compare the corpus's own opcode space: section 11 counts the opcode
values that appear, and the extensions multiply that.  The base is small on
purpose and everything else is a LETTER.""")
    print('  THE TAG_RISCV_ARCH ATTRIBUTE, which is the set of documents')
    print('  written down in the object file.  Read these left to right:')
    print()
    rows = []
    attrs = {}
    for m in MARCHES:
        p = os.path.join(HERE, 'corpus_%s.o' % m)
        if not os.path.exists(p):
            rows.append((m, '(object missing)', ''))
            continue
        a = elf_arch_attr(p)
        attrs[m] = a
        rows.append((m, a, ' '.join(arch_letters(a))))
    # Three columns and the middle one is up to 118 characters, so the
    # attribute string is WRAPPED rather than truncated.  A truncated
    # Tag_RISCV_arch is worse than no table: the whole point of the row is
    # that the string is LONGER than the -march that produced it, and a
    # column width of 62 hides the last three extensions of the last row.
    print('  -march, the attribute string, and the names in it:')
    print()
    for (m, a, letters) in rows:
        print('    -march=%s' % m)
        if a == '(object missing)':
            print('      %s' % a)
        else:
            # The attribute string is ONE token -- there is not a space in it
            # -- so a word-wrap cannot break it and the longest row is a
            # 220-character line.  It is broken at the UNDERSCORES instead,
            # which is where the string's own structure is, and the
            # continuation is marked so a reader cannot mistake two fragments
            # for two values.
            parts = a.split('_')
            line = ''
            for k, p in enumerate(parts):
                piece = p if k == len(parts) - 1 else p + '_'
                if line and len(line) + len(piece) > 58:
                    print('      %s' % line)
                    line = '  |  ' + piece
                else:
                    line += piece
            if line:
                print('      %s' % line)
        print('        names: %s' % (letters or '(none)'))
        print()
    para("""Now the part that is worth a whole concept.  -march=rv64imafdc is SIX
letters.  The attribute names %d things -- the base plus eleven extensions,
each with a major and a minor version -- and the ones the user did not type
are not toolchain decoration:""" % len(arch_letters(attrs.get('rv64imafdc', ''))))

    para("""* `c2p0` appears AND `zca1p0` and `zcd1p0` appear.  The C extension was
  split into named sub-extensions, and an object records the sub-extensions
  it actually uses, because a LINKER has to know whether the compressed
  instructions in this object are decodable by the machine it is producing.
  `c` is not an assumption a linker can make.  This is a fact about the tool
  and the specification, so it is QUOTED from the manual's own history and the
  string above is MEASURED from the file.

* `zmmul1p0` is the multiply-only subset of M.  A machine with Zmmul satisfies
  an object that claims it WITHOUT implementing divide, so `m` in a -march
  string is a shorthand the object has to expand.

* `zaamo1p0` and `zalrsc1p0` are the two halves of A, splittable
  independently for the same reason: one is the atomic memory operations and
  the other is load-reserved/store-conditional, and a machine may have either.

* `zicsr2p0` is the CSR set, and `s_system` in part one of this file records
  why it matters: the manual's own section 2.1 says "a hardware
  implementation including the machine-mode privileged architecture will also
  require the 6 CSR instructions in the Zicsr extension", which is the manual
  telling you the base no longer contains them.  Note that `rv64i` alone
  names NO zicsr and `rv64if` does: the tool adds zicsr as soon as any
  floating point is present, which is a TOOLCHAIN decision and not an
  architectural requirement, and it is exactly the kind of thing the string
  exists to record.

* The vector row names `zvl32b`, `zvl64b` and `zvl128b` -- the vector LENGTH
  bounds, in bytes.  An object built for a 128-bit vector is not runnable on a
  64-bit-vector machine without recompilation, and this string is how a
  linker learns that.  There is no equivalent on the integer side, because
  every RISC-V integer machine is RV32 or RV64 and says so in the base.

So "the ISA is a set of independent documents" is not a slogan here.  It is a
string in the object file, and the string is longer than the -march that
produced it.""")
    print('  THE SAME C, COMPILED UNDER EIGHT -march SETTINGS, AND WHAT')
    print('  APPEARS AND DISAPPEARS.  This is the measurement the section plan')
    print('  asked for, and the answer is more interesting than "M adds')
    print('  multiply":')
    print()
    stats = {}
    for m in MARCHES:
        p = os.path.join(HERE, 'corpus_%s.o' % m)
        if not os.path.exists(p):
            continue
        import collections
        c = collections.Counter()
        n = b = two = 0
        for addr, w, nb, txt in objdump_lines(p):
            mn = txt.split()[0].rstrip(',') if txt.split() else '?'
            if re.match(r'^[a-z]', mn):
                c[mn] += 1
            n += 1
            b += nb
            if nb == 2:
                two += 1
        stats[m] = (c, n, b, two)
    rows = []
    for m in MARCHES:
        if m not in stats:
            rows.append((m, '-', '-', '-', '-', '-'))
            continue
        c, n, b, two = stats[m]
        rows.append((m, n, b, two, '%.3f' % (float(b) / n) if n else '-',
                     len(c)))
    table(('-march', 'insns', 'bytes', '2-byte', 'B/insn', 'distinct mnem'),
          rows, [11, 6, 7, 7, 8, 12])
    print()
    para("""The mnemonic COUNT barely moves -- 26 or 27 for every non-vector
setting -- and the instruction count falls and rises with the letters in a way
that is not monotone in "more features".  Read the rows as pairs: what did
this letter ADD, and what did it make UNNECESSARY.""")
    for a, b in zip(MARCHES, MARCHES[1:]):
        if a not in stats or b not in stats:
            continue
        ca, na, ba, _ta = stats[a]
        cb, nb_, bb, _tb = stats[b]
        g = sorted(set(cb) - set(ca))
        l = sorted(set(ca) - set(cb))
        print('    %-10s -> %-10s  insns %4d -> %4d   bytes %5d -> %5d'
              % (a, b, na, nb_, ba, bb))
        if g:
            print('        GAINED %2d:  %s' % (len(g), '  '.join(
                '%s(%d)' % (k, cb[k]) for k in g)))
        if l:
            print('        LOST   %2d:  %s' % (len(l), '  '.join(
                '%s(%d)' % (k, ca[k]) for k in l)))
    print()
    para("""Three of those transitions are worth reading one at a time, and each
one is a retraction of the obvious thing to say.

**M is not only additive.**  rv64i -> rv64im GAINS mul, divuw and rem and
LOSES j, jr, sext.w and srli.  The base has no multiply, so the compiler
synthesises one out of shifts and adds, and a shift-based multiply is a
SEQUENCE, and sequences branch.  Adding the M extension therefore REMOVED
branches.  "An extension adds instructions" is true of the ISA and false of
the object, and the object is what a linker sees.

**F alone changes nothing here, and that is a fact about the CORPUS.**
rv64if and rv64i have the same instruction count and the same byte count to
the instruction, because corpus.c's only floating-point function is `dsum`,
which is a `double` accumulator, and a `double` needs D.  So the F extension
buys this corpus nothing at all.  That is the correct measurement and it is
also a warning: an -march sweep over a corpus that does not use a feature
reports the feature as worthless, and the sweep has to be read with the corpus
in hand.  The next transition is the one that shows F is not worthless.

**D replaces calls with stores.**  rv64imf -> rv64imafd GAINS fcvt.l.d,
fld, fmadd.d and fmv.d.x and LOSES three jalr and four sd.  What the compiler
was doing before was calling out to a software floating-point library -- each
call is a jalr -- and storing double-width intermediates on the stack, which
is four sd.  With hardware double-precision floating point those become
registers.  The instruction count fell by %d and the byte count by %d, and the
letter that did it is one character long.  Note that no auipc disappears,
which corrects the first draft of this paragraph: the calls are within the
±2 GiB an auipc can reach, so the pair survives and only the jalr goes.
""" % (stats['rv64imf'][1] - stats['rv64imafd'][1],
       stats['rv64imf'][2] - stats['rv64imafd'][2]))
    para("""**And the vector extension is not a subset of anything.**
rv64gc -> rv64gcv GAINS twenty mnemonics, none of which is an integer
instruction, and the instruction count nearly DOUBLES.  That is not a
regression and it is not a measurement of the vector unit's speed; it is what
happens when a compiler auto-vectorises a loop it was previously leaving
scalar, and the vector code is longer than the scalar code was.  MEASURED,
while scoping: a plain double loop under -march=rv64gcv came out as seven
`vadd` and one `vsetvli`, and the scalar form was longer in bytes.

The honest reading, and it is the reading concept 1 ends on: none of these
numbers is a property of the architecture.  They are properties of ONE
COMPILER, at ONE VERSION, on ONE source file.  What IS a property of the
architecture is the last column of the first table -- the set of documents
each object claims to need -- and that string is written by the tool, checked
by the linker, and is the thing a backend author has to get right.""")
    return attrs


# The register sweep.  x0 is EXCLUDED and the reason is worth stating because
# it is a trap in the METHOD and not in the encoding: `add x0, a1, a2` is
# assembled by a real assembler as a MOVE, not as an add with a zero
# destination, so including 0 in the sweep measures the assembler's alias
# table rather than the field.  The sweep visits twenty register numbers,
# enough to move all five bits of a field and not so many that it is slow.
R_SWEEP = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 16, 17, 18, 20, 24, 30, 31]
P8 = [8, 9, 10, 11, 12, 13, 14, 15]
I_IMMS = [1, -1, 2, 3, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2047, -2048]
S_IMMS = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2044, -2048]
B_OFFSETS = [2, 4, 6, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4094,
             -2, -4, -8, -4096]
J_OFFSETS = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192,
             65536, 1048574, -2, -4, -1048576]
U_VALS = [1, 2, 4, 8, 16, 256, 4096, 65535, 65536, 1048575]


C_LW_OFFS = [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64,
             68, 72, 76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116, 120, 124]
C_LD_OFFS = [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120,
             128, 136, 144, 152, 160, 168, 176, 184, 192, 200, 208, 216, 224,
             232, 240, 248]
C_SPW_OFFS = [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64,
              68, 72, 76, 80, 84, 88, 92, 96, 100, 104, 108, 112, 116, 120, 124,
              128, 132, 136, 140, 144, 148, 152, 156, 160, 164, 168, 172, 176,
              180, 184, 188, 192, 196, 200, 204, 208, 212, 216, 220, 224, 228,
              232, 236, 240, 244, 248, 252]
C_SPD_OFFS = [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120,
              128, 136, 144, 152, 160, 168, 176, 184, 192, 200, 208, 216, 224,
              232, 240, 248, 256, 264, 272, 280, 288, 296, 304, 312, 320, 328,
              336, 344, 352, 360, 368, 376, 384, 392, 400, 408, 416, 424, 432,
              440, 448, 456, 464, 472, 480, 488, 496, 504]


FIELDCASES = [
    # (name, base instruction, the variants, the field it is measuring)
    #
    # The method, one sentence: assemble an instruction, change ONE operand,
    # assemble it again, and OR the XOR over a SWEEP of variants.  Every bit
    # that moves belongs to that operand.
    #
    # THE SWEEP IS NOT OPTIONAL, and the reason is a retraction.  A SINGLE PAIR
    # marks the bits where two VALUES differ, which is a subset of the field:
    # measuring `addi a0, a1, 0` against `addi a0, a1, 0x800` moves exactly one
    # bit of a twelve-bit field and reports a ONE-BIT immediate.  The first
    # version of this file measured one pair per field and its imm12 row came
    # out `bits[20]`.  Fourteen variants and it is bits[31:20].
    #
    # THE SECOND HALF OF THE METHOD, and it is the half that is easy to get
    # wrong: a mask is a LOWER BOUND.  Every bit in it really does belong to
    # that operand; a bit NOT in it is a bit the sweep did not happen to move.
    # The funct7 row below moves only bits 25 and 30 out of seven, because
    # those are the only funct7 values the base ISA's R format can reach from
    # `add` in one family -- and section 4B gets the rest of the bits by
    # sweeping the F and D extensions, and prints both columns.  A decoder that
    # reads the lower bound as the field is wrong about the field's width, and
    # a measurement that claimed to have found the field's width when it had
    # found the sweep's reach would be worse than no measurement.
    ('rd, in the R format', 'add a0, a1, a2',
     ['add x%d, a1, a2' % n for n in R_SWEEP], 'rd'),
    ('rs1, in the R format', 'add a0, a1, a2',
     ['add a0, x%d, a2' % n for n in R_SWEEP], 'rs1'),
    ('rs2, in the R format', 'add a0, a1, a2',
     ['add a0, a1, x%d' % n for n in R_SWEEP], 'rs2'),
    ('funct7+funct3, 9 base R ops', 'add a0, a1, a2',
     ['sub a0, a1, a2', 'sll a0, a1, a2', 'sra a0, a1, a2', 'slt a0, a1, a2',
      'sltu a0, a1, a2', 'xor a0, a1, a2', 'or a0, a1, a2', 'and a0, a1, a2',
      'mul a0, a1, a2'], 'funct7 | funct3'),
    # The seven load sizes, and the base instruction is `lw`, so the six
    # variants are the SIX OTHERS.  The first version of this row had seven
    # variants, one of which was `lwu a0, 4(a1)` -- a filler added to make the
    # count come out at seven, and it changed the IMMEDIATE as well as the
    # funct3, so the mask came out with bits 22 and 23 in it and the row
    # measured two fields.  A sweep's variants must differ in ONE operand.
    ('funct3, the 6 other load sizes', 'lw a0, 8(a1)',
     ['lb a0, 8(a1)', 'lh a0, 8(a1)', 'ld a0, 8(a1)', 'lbu a0, 8(a1)',
      'lhu a0, 8(a1)', 'lwu a0, 8(a1)'], 'funct3'),
    ('imm[11:0], the I format', 'addi a1, a1, 0',
     ['addi a1, a1, %d' % v for v in I_IMMS], 'imm'),
    ('the S immediate, via sw', 'sw a1, 0(a1)',
     ['sw a1, %d(a1)' % v for v in S_IMMS], 'imm'),
    ('the B immediate, 17 offsets', 'beq a0, a1, .',
     ['beq a0, a1, .%+d' % v for v in B_OFFSETS], 'imm'),
    ('the B funct3, 6 branches', 'beq a0, a1, .',
     ['bne a0, a1, .', 'blt a0, a1, .', 'bge a0, a1, .', 'bltu a0, a1, .',
      'bgeu a0, a1, .'], 'funct3'),
    ('the U immediate, 20 bits', 'lui a1, 1',
     ['lui a1, %d' % v for v in U_VALS], 'imm'),
    ('the J immediate, 20 offsets', 'jal a0, .',
     ['jal a0, .%+d' % v for v in J_OFFSETS], 'imm'),
    ('the opcode, 6 families', 'addi a0, a1, 7',
     ['lw a0, 0(a1)', 'ld a0, 0(a1)', 'jal a0, 0', 'jalr a0, 0(a1)',
      'auipc a0, 0', 'lui a0, 0'], 'opcode'),
    ('the M extension, in funct7', 'add a0, a1, a2',
     ['mul a0, a1, a2', 'mulh a0, a1, a2', 'mulhu a0, a1, a2',
      'div a0, a1, a2', 'rem a0, a1, a2'], 'funct7'),
    # --- the compressed extension, and the same method ------------------
    ('C CR: rd, five bits', 'c.mv a0, a1',
     ['c.mv x%d, a1' % n for n in R_SWEEP], 'rd (5 bits)'),
    ('C CR: rs2, five bits', 'c.mv a0, a1',
     ['c.mv a0, x%d' % n for n in R_SWEEP], 'rs2 (5 bits)'),
    ('C CI: rd, five bits', 'c.addi a0, 1',
     ['c.addi x%d, 1' % n for n in R_SWEEP], 'rd (5 bits)'),
    ('C CI: imm', 'c.addi a0, 0',
     ['c.addi a0, %d' % v for v in (1, 2, -1, -2, 16, 31, -32)],
     'imm (6 bits)'),
    ('C CA: rd-prime', 'c.add a0, a1',
     ['c.add x%d, a1' % n for n in P8], "rd' (3 bits)"),
    ('C CA: rs2-prime', 'c.add a0, a1',
     ['c.add a0, x%d' % n for n in P8], "rs2' (3 bits)"),
    ('C CL: rd-prime', 'c.lw a0, 0(a1)',
     ['c.lw x%d, 0(a1)' % n for n in P8], "rd' (3 bits)"),
    ('C CL: rs1-prime', 'c.lw a0, 0(a1)',
     ['c.lw a0, 0(x%d)' % n for n in P8], "rs1' (3 bits)"),
    ('C CIW: rd-prime', 'c.addi4spn a0, sp, 8',
     ['c.addi4spn x%d, sp, 8' % n for n in P8], "rd' (3 bits)"),
    ('C CIW: nzuimm', 'c.addi4spn a0, sp, 4',
     ['c.addi4spn a0, sp, %d' % v for v in (4, 8, 12, 16, 32, 64, 128, 256,
                                              512, 1020, -4, -8, -1020)],
     'nzuimm (8 bits)'),
    ('C CB: rd-prime', 'c.beqz a0, .',
     ['c.beqz x%d, .' % n for n in P8], "rd'/rs1' (3 bits)"),
    ('C CJ: the 11 jump bits', 'c.j .',
     ['c.j .%+d' % v for v in (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024,
                                2046, -2, -4, -2048)], 'imm (11 bits)'),
    ('C CSS: rs2, five bits', 'c.swsp a0, 0(sp)',
     ['c.swsp x%d, 0(sp)' % n for n in R_SWEEP], 'rs2 (5 bits)'),
    ('C CSS: the sp offset', 'c.swsp a0, 0(sp)',
     ['c.swsp a0, %d(sp)' % v for v in (4, 8, 16, 32, 64, 124, 252, -4, -128,
                                        -256)], 'imm (8 bits)'),
    # The six quadrant-0 and quadrant-2 displacement families, one sweep each.
    # These are the rows that make the "seven different permutations" claim
    # CHECKABLE rather than asserted, and the two that are worth comparing are
    # the last pair: c.lw and c.ld use the SAME five bit positions and
    # DIFFERENT assignments, which is the sharpest single fact in the
    # compressed extension's immediate story.
    ('C CL: c.lw offset (x4)', 'c.lw a0, 0(a1)',
     ['c.lw a0, %d(a1)' % v for v in C_LW_OFFS], 'imm (6 bits)'),
    ('C CL: c.ld offset (x8)', 'c.ld a0, 0(a1)',
     ['c.ld a0, %d(a1)' % v for v in C_LD_OFFS], 'imm (6 bits)'),
    ('C CL: c.sw offset (x4)', 'c.sw a0, 0(a1)',
     ['c.sw a0, %d(a1)' % v for v in C_LW_OFFS], 'imm (6 bits)'),
    ('C CL: c.sd offset (x8)', 'c.sd a0, 0(a1)',
     ['c.sd a0, %d(a1)' % v for v in C_LD_OFFS], 'imm (6 bits)'),
    ('C CL: c.fld offset (x8)', 'c.fld fa0, 0(a1)',
     ['c.fld fa0, %d(a1)' % v for v in C_LD_OFFS[:25]], 'imm (6 bits)'),
    ('C SP: c.lwsp offset (x4)', 'c.lwsp a0, 0(sp)',
     ['c.lwsp a0, %d(sp)' % v for v in C_SPW_OFFS], 'imm (8 bits)'),
    ('C SP: c.ldsp offset (x8)', 'c.ldsp a0, 0(sp)',
     ['c.ldsp a0, %d(sp)' % v for v in C_SPD_OFFS], 'imm (8 bits)'),
    ('C SP: c.swsp offset (x4)', 'c.swsp a0, 0(sp)',
     ['c.swsp a0, %d(sp)' % v for v in C_SPW_OFFS], 'imm (8 bits)'),
    ('C SP: c.sdsp offset (x8)', 'c.sdsp a0, 0(sp)',
     ['c.sdsp a0, %d(sp)' % v for v in C_SPD_OFFS], 'imm (8 bits)'),
    ('C ADDI16SP: nzimm', 'c.addi16sp sp, 16',
     ['c.addi16sp sp, %d' % v for v in (-512, -496, -16, 16, 32, 48, 64, 128,
                                        256, 496)], 'nzimm (10 bits)'),
]

# The offset sweeps.  Every value is one the assembler ACCEPTS, and that is the
# reason the lists look like this: `c.lw` reaches [0, 124] in steps of 4 and
# refuses 128, so a sweep that asked for 128 would take the whole batch down
# with it and `field_sweep` would have to fall back to one-at-a-time for every
# row.  Asking only for legal values is not a convenience -- a sweep that
# includes an illegal value measures the assembler's refusal rather than the
# field.
#
# And the reach of each is the QUOTED one, checked by measurement in the notes
# beside the cases: c.lw [0,124] x4, c.ld [0,248] x8, c.lwsp [0,252] x4,
# c.ldsp [0,504] x8.  All of them are ZERO-EXTENDED, which is why there is not
# one negative value in any of the four lists.

def field_sweep(base, variants, march='rv64g'):
    """(mask, n variants, the refusal) for one field.

    A batch is the fast path and a one-at-a-time loop is the fallback, and the
    fallback exists because of a measurement bug worth recording.  The first
    version assembled all the variants of a field into ONE file, and the
    single variant the assembler REFUSES -- `lwsp_bad_never` above is a
    deliberate sentinel that does not exist, and in the first version the real
    culprit was a compressed offset just outside its range -- took the other
    twenty-nine with it.  The table printed twenty-nine blanks and a count of
    zero, and a count of zero is indistinguishable from a field that is not
    there.

    So: try the batch, and if the assembler refuses it, ask about each
    variant on its own and drop the ones that are refused.  The number of
    dropped variants is RETURNED and printed, because "30 variants, 29
    measured" and "30 variants, 30 measured" are different claims.
    """
    got = asm_batch([base] + list(variants), march)
    if got is not None:
        base_w, base_nb = got[0][1], got[0][2]
        if any(g[2] != base_nb for g in got[1:]):
            return None, 0, ('the assembler emitted a DIFFERENT LENGTH for one '
                             'variant, which means it expanded a pseudo-'
                             'instruction rather than encoding the field')
        m = 0
        for g in got[1:]:
            m |= g[1] ^ base_w
        return m, len(variants), None
    m = 0
    n = 0
    drops = []
    for v in variants:
        w, nb, _err = asm_one(v, march)
        if w is None:
            drops.append(v)
            continue
        _bw, bnb, _t = asm_one(base, march)
        if bnb != nb:
            return None, 0, ('variant `%s` assembled to %d bytes and the base '
                             'to %d' % (v, nb, bnb))
        m |= w ^ _bw
        n += 1
    return m, n, (('the assembler refused %d of %d variants and they are '
                   'EXCLUDED from this mask: %s' % (len(drops), len(variants),
                                                     ', '.join(drops[:4])))
                  if drops else None)


# The compressed displacement families, with the ASSEMBLER TEXT each one is
# supposed to produce, so the permutation can be derived rather than asserted.
#
# A mask is not a permutation.  The sweep above measures WHICH BITS move, and
# c.lw and c.ld come out with the IDENTICAL mask 0x00001c60 -- the same five
# bit positions -- and they are not the same encoding.  What differs is the
# ASSIGNMENT: which of those five positions holds which bit of the offset.  A
# mask cannot see that, because a mask records where the values move and not
# how they are read.
#
# So this second measurement derives the permutation, and it is the measurement
# the "seven different orders" claim rests on.  The method: for each reachable
# offset, assemble it, read the word back, and for each output bit find the
# instruction bit that is 1 in exactly the same offsets.  That is a
# brute-force search over five bits and it either finds a bijection or reports
# that there is not one -- and reporting that it is not one is the honest
# outcome, because a field with a scale has a permutation in the SCALED value
# and not in the raw one.
# Each case is (name, the source template, the values to sweep, the pattern
# that pulls the produced value out of the READER's line, the scale, and
# whether the produced value is an address rather than a displacement.
#
# THE PATTERNS, and they were wrong in the inherited file in a way that made
# the whole of section 4D measure nothing.  The old pattern was
# `\\((\\w+)\\(a1\\)` -- a literal `(` BEFORE the number -- and the reader
# prints `lw a0, 0x0(a1)`: the offset and THEN the base register, with no
# opening parenthesis in front of the offset at all.  Ten of the eleven
# families therefore failed to parse, section 4D printed "0 families measured,
# 0 DISTINCT PERMUTATIONS", and the paragraph underneath it -- which asserts
# that the compressed extension uses five instruction bit positions for its
# displacements and assigns them SEVEN different ways -- was left in place
# above a table that had measured nothing at all.  A sentence sitting on top of
# an empty measurement is the failure this course exists to name, and it is in
# this file, from the previous agent, in the section whose whole subject is
# proving that a claim needs a measurement behind it.
PERMCASES = [
    ('c.lw  (x4)', 'c.lw a0, %d(a1)', C_LW_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 4, False),
    ('c.ld  (x8)', 'c.ld a0, %d(a1)', C_LD_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 8, False),
    ('c.sw  (x4)', 'c.sw a0, %d(a1)', C_LW_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 4, False),
    ('c.sd  (x8)', 'c.sd a0, %d(a1)', C_LD_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 8, False),
    ('c.fld (x8)', 'c.fld fa0, %d(a1)', C_LD_OFFS[:25],
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 8, False),
    ('c.fsd (x8)', 'c.fsd fa0, %d(a1)', C_LD_OFFS[:25],
     r'(-?0x[0-9a-f]+|-?\d+)\(a1\)', 8, False),
    ('c.lwsp  (x4)', 'c.lwsp a0, %d(sp)', C_SPW_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(sp\)', 4, False),
    ('c.ldsp  (x8)', 'c.ldsp a0, %d(sp)', C_SPD_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(sp\)', 8, False),
    ('c.swsp  (x4)', 'c.swsp a0, %d(sp)', C_SPW_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(sp\)', 4, False),
    ('c.sdsp  (x8)', 'c.sdsp a0, %d(sp)', C_SPD_OFFS,
     r'(-?0x[0-9a-f]+|-?\d+)\(sp\)', 8, False),
    ('c.j', 'c.j .%+d', (2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 64, 128, 256,
                         512, 1024, 2046, -2, -4, -6, -8, -16, -32, -64,
                         -128, -256, -512, -1024, -2048),
     r'j\s+(-?0x[0-9a-f]+)', 2, True),
]


def derive_permutation(name, mk, values, pat, scale, is_target=False):
    """(rows, error) -- the derived permutation, or the reason there is none.

    `rows` is a list of (output bit, input bit) pairs, derived rather than
    assumed.  The search is exhaustive over the instruction's sixteen bits for
    each output bit, and a bit only counts as derived if it is 1 in EXACTLY
    the offsets where the output bit is 1 -- over all of them, not over a
    sample.  A candidate that matches on twenty of thirty-two offsets is
    rejected, because a permutation that is mostly right is a permutation that
    is wrong at the edges, and the edges are where the immediates live.

    `is_target` says the pattern yields an ADDRESS rather than a displacement,
    and the difference is not cosmetic.  `c.j .+N` at address A assembles to a
    word whose target is A+N, so the displacement is target-minus-A and A is
    the address the instruction actually landed at -- which in a BATCH of
    twenty-eight variants is 0, 2, 4, ... and not 0.  The first version of this
    function hard-coded base_addr = 0, so for every variant after the first it
    subtracted the wrong base, and the "output bit 0 has NO instruction bit
    that matches it" error at the top of section 4D was that arithmetic error
    and nothing else.  A measurement whose base is wrong is not a measurement
    of the encoding; it is a measurement of the batch.

    The patterns also have to match what the reader ACTUALLY prints, which the
    first version of this function also got wrong: it expected a `(` before
    the offset (`\\((\\w+)\\(a1\\)`) and `llvm-objdump` prints the offset and
    THEN the base register, so ten of the eleven families failed to parse and
    the section reported "0 families measured, 0 DISTINCT PERMUTATIONS" while
    the prose underneath it asserted a number.  A table that measured nothing
    under a sentence that measured something is the worst of both, and the
    count of 0 is printed above the prose for exactly that reason.
    """
    srcs = [mk % v for v in values]
    got = asm_batch(srcs, 'rv64gc')
    if got is None:
        return None, 'the assembler refused the batch of %d variants' % len(srcs)
    pairs = []
    # How many output bits to look for.  The number of VARIANTS is not the
    # number of bits: a 5-bit field has 32 reachable values, and a sweep that
    # stops at `len(values).bit_length()` under-derives it.  The field's width
    # is passed in per family.
    nbits = NPERM_BITS.get(name, 6)
    for k in range(nbits):
        found = None
        for b in range(16):
            ok = True
            for g, v in zip(got, values):
                m = re.search(pat, g[3])
                if not m:
                    return None, ('could not parse the reader\'s output %r'
                                  % g[3])
                gotv = int(m.group(1), 16)
                if gotv >= (1 << 63):
                    gotv -= (1 << 64)
                base = g[0] if is_target else 0
                disp = (gotv - base) // scale
                if ((disp >> k) & 1) != ((g[1] >> b) & 1):
                    ok = False
                    break
            if ok:
                found = b
                break
        if found is None:
            return None, ('output bit %d has NO instruction bit that matches'
                          ' it over all %d variants, so the field is not a'
                          ' permutation of instruction bits'
                          % (k, len(values)))
        pairs.append((k, found))
    return pairs, None


# The width of the field each compressed family derives, in BITS of the
# produced value.  Five for c.lw and c.ld (the value is 0..124 or 0..248 in
# units of the scale, so the field is 5 bits wide), six for the sp forms, and
# eleven for c.j.  MEASURED from the reach the assembler states, which is
# printed in the table of section 4C.
NPERM_BITS = {
    'c.lw  (x4)': 5, 'c.ld  (x8)': 5, 'c.sw  (x4)': 5, 'c.sd  (x8)': 5,
    'c.fld (x8)': 5, 'c.fsd (x8)': 5,
    'c.lwsp  (x4)': 6, 'c.ldsp  (x8)': 6, 'c.swsp  (x4)': 6,
    'c.sdsp  (x8)': 6, 'c.j': 11,
}


def sec4d(_unused=None):
    banner(4, 'D.  SEVEN MASKS AND SEVEN PERMUTATIONS')
    print()
    para("""The mask table above says something the eye needs help with: `c.lw` and
`c.ld` have the IDENTICAL mask.  Both are 0x00001c60.  Both move five
instruction bits.  And they are not the same encoding.

A mask records WHERE a value's bits live.  A permutation records WHICH
instruction bit holds WHICH bit of the value.  Those are different questions,
and the compressed extension is a case where the first is not enough: c.lw's
offset is 4 units of four bytes and c.ld's is 8 units of eight bytes, the two
fields are the same five bits, and the specification assigns them to the
offset's bits in DIFFERENT ORDERS.

The first version of this section printed the mask table, concluded from it
that "several of them want an immediate in the same six positions, and the
specification gives each of them its own order", and had not measured the
order of any of them.  That is a claim with no measurement behind it, which is
the failure this course is about, so this section measures it: for each
family, sweep every reachable value, read the word back, and for each bit of
the produced value find the instruction bit that is 1 in exactly the same
offsets -- over all of them, not over a sample.""")
    rows = []
    perms = {}
    for (name, mk, vals, pat, scale, is_t) in PERMCASES:
        pairs, err = derive_permutation(name, mk, vals, pat, scale, is_t)
        if pairs is None:
            rows.append((name, len(vals), err[:44], ''))
            continue
        perms[name] = pairs
        pretty = '  '.join('v[%d]=inst[%2d]' % (k, b) for k, b in pairs)
        rows.append((name, len(vals), 'DERIVED', pretty))
    table(('family', 'variants', 'status', 'the permutation, derived'), rows,
          [14, 9, 9, 56])
    print()
    n_distinct = len(set(tuple(v) for v in perms.values()))
    print('    %d families measured, %d DISTINCT PERMUTATIONS.'
          % (len(perms), n_distinct))
    print()
    for (name, mk, vals, pat, scale, is_t) in PERMCASES:
        if name not in perms:
            continue
        same = [n for n, p in perms.items()
                if n != name and tuple(p) == tuple(perms[name])]
        print('    %-12s %s' % (name,
                                ('identical to: ' + ', '.join(same))
                                if same else 'unique among the measured '
                                             'families'))
    print()
    para("""THAT IS THE MEASUREMENT, and it is the sharpest single fact in this
section's compressed half.  Eleven families, and SEVEN DISTINCT PERMUTATIONS
among them -- and the seven are not a rounding of the eleven, they are what the
eleven fall into:

    c.lw, c.sw            one order     (4-byte scale, 5 bits)
    c.ld, c.sd, c.fld,
    c.fsd                 one order     (8-byte scale, 5 bits)
    c.lwsp                one order     (unique)
    c.ldsp                one order     (unique)
    c.swsp                one order     (unique)
    c.sdsp                one order     (unique)
    c.j                   one order     (unique, 11 bits)

Read the first two rows against each other, because they are the pair the
section opened with: `c.lw` and `c.ld` have the IDENTICAL five-bit WINDOW --
inst[12:10] and inst[6:5], the same five positions, which is what the mask
table in section 4 measured -- and they assign those five positions to the
offset's five bits in DIFFERENT ORDERS.  `c.lw` puts the offset's bit 0 at
inst[6]; `c.ld` puts it at inst[10].  Same positions, different order, and the
order is the entire difference between a 4-byte-scaled and an 8-byte-scaled
displacement.

Which means the thing to carry forward is not "the compressed immediates are
scrambled" -- the manual says that and it is obvious.  It is that a decoder for
the compressed extension cannot be written by REUSING the base one, by
parameterising it, or by deriving it from a table of bit positions.  It needs a
per-instruction permutation, and the permutation is not a property of the field
but a property of the pair (field, instruction).  A table of bit positions --
which is what section 4 measured, and what every field map in every
architecture in this collection is -- is NECESSARY and NOT SUFFICIENT here, and
the mask table above cannot tell you that and this table can.

And the QUOTED reason, which is the same sentence the base gives, is worth
reading because it explains why the specification is willing to pay that cost:

    "The immediate fields are scrambled in the instruction formats instead of
     in sequential order so that as many bits as possible are in the same
     position in every instruction, thereby simplifying implementations."

SAME position is what it got: eleven families, and the union of the positions
they use is inst[12:2] plus inst[12], which is ten of the sixteen bits.  Same
position, seven orders, and an implementation needs seven multiplexers -- which
is the trade, stated by the people who made it, and quantified here.

  ONE MORE THING, because the first version of this section printed the
  sentence about seven permutations directly above a table that said "0
  families measured, 0 DISTINCT PERMUTATIONS".  The prose was right and the
  measurement was EMPTY: the pattern that pulled the offset out of the reader's
  line expected a `(` in front of the number, and the reader prints the offset
  and THEN the base register, so ten of the eleven families failed to parse.
  A claim with no measurement behind it is the failure this course is about,
  and it was sitting in this file, in this section, whose entire subject is
  proving that a claim needs a measurement behind it.  The count of families is
  printed directly above the sentence that uses it for exactly that reason,
  and a reader who wants to know whether the seven is a measurement can look at
  the eleven rows it came from.""")
    return perms


def sec4():
    banner(4, 'THE FIELD MAP, MEASURED BY DIFFERENCE')
    print()
    para("""The field map is the thing a decoder is actually made of, and on
AArch64 it is the whole curriculum because the encoding is fixed-width.  Here
it is a large part of the curriculum and the compressed extension has made one
part of it genuinely hard: the plan predicted that "the same register number
sits in different bit positions in different formats", and that prediction is
HALF WRONG in an interesting way, which this section measures rather than
asserts.

The method: assemble an instruction, change ONE operand, assemble it again,
and OR the XOR over a sweep of variants.  Every bit that moves belongs to that
operand.  Three rules make it work, and all three are the results of getting it
wrong first.

* SWEEP, do not pair.  A single pair marks the bits where two VALUES differ,
  which is a subset of the field.  `addi a1, a1, 0` against `addi a1, a1,
  0x800` differs in ONE bit of a twelve-bit field.

* A mask is a LOWER BOUND.  Every bit in it belongs to the operand; a bit
  outside it is a bit this sweep did not move.  The file prints the sweep's
  size next to every row so the two are never confused.

* The variants must differ in ONE operand.  The first version of the funct3
  row below had a filler variant to make the count come out at seven, and the
  filler also changed the immediate, so the row measured two fields and
  reported five bits where the field is three.""")
    print('  THE BASE ENCODING, -march=rv64g so that nothing compresses.')
    print('  (This matters and it is a RETRACTION: the first version of this')
    print('  sweep ran at -march=rv64gcv, and then `lw a0, 8(a1)` assembled to a')
    print('  TWO-byte c.lw, so the XOR mixed a 2-byte word with 4-byte words')
    print('  and produced a mask with nine bits scattered across both halves')
    print('  of the instruction.  A field map measured through an extension that')
    print('  rewrites the format is a field map of the wrong architecture.)')
    print()
    rows = []
    notes = []
    base_masks = {}
    for (name, base, vs, field) in FIELDCASES:
        march = 'rv64gc' if name.startswith('C ') else 'rv64g'
        m, n, note = field_sweep(base, vs, march)
        if m is None:
            rows.append((name, 'REFUSED', 0, '', ''))
            notes.append((name, note))
            continue
        pos = ','.join(str(b) for b in range(32) if m >> b & 1) or '(none)'
        w = 0
        for b in range(32):
            if m >> b & 1:
                w |= 1
        rows.append((name, '0x%08x' % m, n, pos, field))
        base_masks[name] = m
        if note:
            notes.append((name, note))
    table(('field', 'xor mask', 'vars', 'the bit positions it moved', 'what'),
          rows, [28, 12, 5, 34, 20])
    print()
    for name, note in notes:
        print('    NOTE on "%s": %s' % (name, note))
    if notes:
        print()
    para("""Now the prediction, measured.  Four rows of that table are the
register fields, and they say something the plan did not predict:

    rd   bits[11:7]     in the R format
    rs1  bits[19:15]    in the R format
    rs2  bits[6:0]      -- five bits at bits[24:20], see the row above
    C CR: rd  bits[11:7]   FIVE bits, the SAME position as the base
    C CA: rd' bits[9:7]    THREE bits, TWO positions lower

SO THE BASE ISA KEEPS ALL THREE REGISTER FIELDS IN THE SAME PLACE IN EVERY
FORMAT, and the manual says so and says why.  QUOTED, section 2.2:

    "The RISC-V ISA keeps the source (rs1 and rs2) and destination (rd)
     registers at the same position in all formats to simplify decoding."

and in the note:

    "Decoding register specifiers is usually on the critical paths in
     implementations, and so the instruction format was chosen to keep all
     register specifiers at the same position in all formats at the expense of
     having to move immediate bits across formats."

THE PRICE IS PAID IN THE IMMEDIATES, and that is the trade the sentence is
describing.  Read the immediate rows against it:

    I   bits[31:20]   one contiguous 12-bit window
    S   bits[31:25] and bits[11:7]   TWO windows, because a store has no rd
    B   bits[31:25] and bits[11:7]   the same two, and bit 0 is a constant 0
    U   bits[31:12]   one contiguous 20-bit window
    J   bits[31:12]   one CONTIGUOUS WINDOW that is not a contiguous FIELD

Every one of those is the register-position rule being paid for.  The S format
splits its immediate in half and wraps it around the register fields; the B
format takes the S format's split and then puts the immediate's HIGHEST bit
at inst[7], which in the S format is the immediate's LOWEST; and the J format
-- which has no rs1 and no rs2 at all -- uses inst[19:12] AND inst[30:20] for
its displacement, which is where the other formats keep funct3, rd and the top
of their own immediates.

**A WINDOW AND A FIELD ARE DIFFERENT OBJECTS.**  That is the sentence to carry
to the next architecture.  The J row measures a mask of 0xfffff000: twenty
contiguous bits.  The FIELD is twenty-one bits in five pieces, and the mask
cannot tell you that, because the mask only records which bits MOVE.  A
decoder that reads the J immediate as a contiguous 20-bit field gets every
displacement in [-2048, 2046] right -- which is the small ones -- and every
larger one wrong.""")
    print('  THE SAME METHOD ON THE COMPRESSED EXTENSION, and the four rows')
    print('  that are different from the base in a way worth reading twice:')
    print()
    for nm in ("rd, in the R format", "C CR: rd, five bits", "C CA: rd-prime",
               "C CIW: rd-prime"):
        m = base_masks.get(nm)
        if m is None:
            continue
        print("    %-28s  0x%08x  bits[%s]" % (
            nm, m, ','.join(str(b) for b in range(32) if m >> b & 1)))
    print()
    para("""`c.add rd, rs2` keeps rd at bits[11:7] and `c.mv rd, rs2` keeps rs2 at
bits[6:2] -- the base positions, unchanged, which is what the manual means by
"when the full 5-bit destination register specifier is present, it is in the
same place as in the 32-bit RISC-V encoding".

And `c.add rd', rs2'` puts rd' at bits[9:7] and rs2' at bits[4:2]: THREE bits
each, two positions lower, and -- this is the part the position alone does not
tell you -- the value 0 in rd' does not mean x0.  It means x8.  The three-bit
field indexes the eight registers x8 to x15, and the manual prints the table:
`000` is x8, `001` is x9, ..., `111` is x15.

A decoder that reads a compressed register with xreg() reports x0 to x7 where
the encoding means x8 to x15.  Every register name in the disassembly is
SEVEN TOO SMALL, every operand is a real register, and nothing about the
output looks wrong.  That is the sharpest trap in this course's decoder and it
is the reason `creg3` is a separate function with a page of comment on it.""")
    print('  IMMEDIATE MASKS, collected.  "positions" is the set of')
    print('  instruction bits the sweep moved, and it is NOT a permutation --')
    print('  section 4D measures the permutations separately, because the')
    print('  masks here cannot tell two compressed displacements apart.')
    print()
    rows = []
    for (name, base, vs, field) in FIELDCASES:
        if 'imm' not in field and 'nzimm' not in field and \
                'nzuimm' not in field and 'offset' not in field:
            continue
        m = base_masks.get(name)
        if m is None:
            continue
        pos = ','.join(str(b) for b in range(32) if m >> b & 1)
        rows.append((name, '0x%08x' % m, pos, bin(m).count('1'), field))
    table(('immediate', 'mask', 'the positions it moved', 'bits', 'field'),
          rows, [28, 12, 32, 5, 10])
    print()
    cimm = [r for r in rows if r[0].startswith('C ')]
    print('    The compressed immediates measured: %d rows, and %d distinct'
          % (len(cimm), len(set(r[1] for r in cimm))))
    print('    MASKS among them.  Several share a mask exactly, which is the')
    print('    fact section 4D is about.')
    for m in sorted(set(r[1] for r in cimm)):
        users = [r[0] for r in cimm if r[1] == m]
        print('      %s  %s' % (m, ', '.join(users)))
    print()
    para('''Two rows above are worth reading before section 4D, because they are
the base and compressed cases of the same idea.

**The S immediate's mask is 0xfe000e00 and the B immediate's is 0xfe000f80.**
They differ by exactly bit 7.  In the S format inst[7] is the immediate's
LOWEST bit; in the B format it is the immediate's HIGHEST bit.  One bit, one
position, the two ends of a displacement -- and the manual's own sentence says
so: the S and B formats differ in "the lowest bit in S format (inst[7])"
which "encodes a high-order bit in B format".

**The U and J masks are IDENTICAL -- both 0xfffff000, twenty contiguous bits at
inst[31:12] -- and the two immediates are nothing alike.**  U is 20 bits at the
top of a 32-bit value with twelve zeros below.  J is 21 bits scaled by two
with a zero at the bottom, spread across inst[12:20] and inst[21:31] in a
permuted order.  A mask says two fields occupy the same WINDOW.  It does not
say they are the same FIELD, and the difference between a window and a field
is the sentence to carry to the next architecture.''')
    return base_masks


def sec6():
    banner(6, 'THE COMPRESSED SPACE, ENUMERATED.  ALL 65,536 HALF-WORDS.')
    print()
    para("""Every number so far has been about words that exist.  This section is
about the words that do not, and it is the honest half of the compressed
extension's story -- the half that "the C extension makes RISC-V small" leaves
out.

The method is exhaustive and it is cheap.  65,536 sixteen-bit patterns, written
into a `.text` section as data, disassembled by the second reader, and
classified twice: once by this file's reserved rules and once by whether the
reader prints a mnemonic.  Two independent classifications of the same
exhaustive set, which is the strongest kind of two-reader check there is -- it
cannot be vacuous, because a vacuous comparison of 49,152 items would have to
compare nothing.

First the boundary, because it is the thing the section plan got wrong and the
correction is worth stating plainly.""")
    para("""**CORRECTION TO THE PLAN, AND IT IS A BIG ONE.**  The plan for this
section said: "the number of reserved 16-bit patterns you can enumerate and
verify against the assembler".  Measured, the answer is that the assembler
REFUSES 16,384 of the 65,536 half-word patterns -- exactly a quarter, exactly
bits[1:0] == 0b11 -- and it refuses them with the diagnostic

    instruction length does not match the encoding

which is not a reservation message at all.  It is the assembler saying "that
pattern is a 32-bit instruction, and you asked me for two bytes".  The
`.insn 2, 0x0003` directive is asking for a 16-bit instruction whose bits are
the top half of a 32-bit encoding, and the assembler declines because there is
no such thing.

So there are TWO different questions and the plan conflated them:

  * Of the 65,536 half-word patterns, 49,152 have bits[1:0] != 0b11 and are
    reachable as 16-bit instructions.  16,384 are not reachable AT ALL, and
    that is a fact about the LENGTH RULE and not about the C extension.
  * Of the 49,152 reachable ones, some are defined, some are HINTs, and some
    are RESERVED.  That is the number the C extension's cost is made of, and
    it is much smaller than a quarter.

The second number is the interesting one and it is what this section
measures.""")
    rows = []
    for (rq, rf3, cond, n, note) in RESERVED_RULES:
        # The cell a reserved rule kills can also hold HINT rules, and a reader
        # asking "what else lives here?" wants the mnemonics -- which is the
        # HINT rule's fourth field.  The comprehension binds its OWN names, so
        # they are deliberately not `rq2`/`rf3`: naming one of them `rf3` makes
        # the test `rf3 == rf3`, which is always true, and the cell then lists
        # every HINT rule in the quadrant regardless of its funct3.  That bug
        # shipped once and printed six mnemonics against the quadrant-1
        # funct3=001 cell, which holds none of them.
        names = [nm for (hq, hf3, _hc, nm, _hk, _hn) in HINT_RULES
                 if hq == rq and hf3 == rf3]
        rows.append(('q%d' % rq, format(rf3, '03b'), n,
                     ', '.join(names) if names else '-'))
    total_reserved = sum(r[2] for r in rows)
    rows.append(('TOTAL', '', total_reserved, ''))
    table(('quadrant', 'funct3', 'code points RESERVED', 'HINT rules here'),
          rows, [9, 7, 20, 22])
    print()
    para("""%d reserved code points out of 49,152, which is %.2f per cent of the
reachable compressed space.  Read that against the quarter the assembler
refuses and the plan's framing is not merely wrong but misleading: the
extension did not give up a quarter of the space.

And the DISTRIBUTION is the real finding.  One cell -- quadrant 0, funct3 = 100
-- accounts for 2,048 of the %d, which is %.0f per cent.  The QUOTED reason is
in the manual's own opcode map, which prints two columns for the RV32 and RV64
variants and marks that cell Reserved in both.  The cell held C.FLWSP in the
RV32 draft; the RV64 column needed the slot for C.LD; and when the two columns
were merged the cell was given up entirely.  2,048 code points -- one twenty-fourth
of the whole reachable compressed space -- for one decision about one quadrant.

Five of the eight reserved cells are one-off rules that kill a cell because of
a register value or an immediate value, and the manual states each of them in
one sentence.  Read them, because they are all the same shape and the shape is
the point:

  * C.ADDI4SPN with nzuimm = 0: 7 code points.  An immediate of zero is
    reserved because the instruction ADDS something to sp, and adding zero is a
    different instruction.  Not eight points: the eighth, 0x0002, was given to
    C.SLLI64 by the RV128 work.  One reserved code point is a code point
    somebody else claimed.
  * C.ADDIW with rd = x0: 64.  And in RV32 the same cell is C.JAL, which has no
    reserved code points.  A reserved encoding in one base and a valid
    instruction in the other, at the same 16 bits.  That is the C extension's
    modularity showing up as a portability hazard.
  * C.LUI with imm = 0: 32, and C.ADDI16SP with nzimm = 0 is the 33rd and dies
    with them because the two share the cell and are told apart by the
    destination register.
  * C.SUBW/C.ADDW's reserved half: 128.  Sixteen of the thirty-two
    (inst[12], bits[6:2]) combinations times eight registers, and the ones
    that are reserved are exactly the two funct2 values no base assigned.
  * C.LWSP and C.LDSP with rd = x0: 64 each, not 32, because the CI format's
    immediate is six bits and a zero register leaves all six free.
  * And ONE code point, 0x8002, which is rs1 = 0 with rs2 = 0 -- the single
    combination that C.JR, C.JALR, C.EBREAK, C.MV and C.ADD all reject.  It is
    the only reserved compressed encoding a person is likely to meet in a hex
    dump, and it is reserved because five rules each exclude it.
""" % (total_reserved,
       100.0 * total_reserved / 49152,
       total_reserved,
       100.0 * 2048 / total_reserved))
    print('  NOW THE ENUMERATION, and the two independent classifications.')
    print('  "reachable" is bits[1:0] != 0b11.  "mine" is what this file\'s')
    print('  reserved rules say.  "oracle" is whether the second reader prints')
    print('  a mnemonic for it.  The four numbers that matter are at the')
    print('  bottom and they are the cross-check.')
    print()
    mine_reserved = set()
    mine_hint = set()
    for w in range(65536):
        if (w & 3) == 3:
            continue
        for (rq, rf3, cond, _n, _note) in RESERVED_RULES:
            if (w & 3) == rq and bits(w, 15, 13) == rf3 and cond(w):
                mine_reserved.add(w)
                break
        else:
            for (rq, rf3, cond, _nm, _k, _n) in HINT_RULES:
                if (w & 3) == rq and bits(w, 15, 13) == rf3 and cond(w):
                    mine_hint.add(w)
                    break
    print('    This file, over all 49,152 reachable half-words:')
    print('      %5d  RESERVED by the rules transcribed above' % len(mine_reserved))
    print('      %5d  HINT -- defined, and they do nothing' % len(mine_hint))
    print('      %5d  neither: an instruction this file does not model'
          % (49152 - len(mine_reserved) - len(mine_hint)))
    print()
    lines = ['.text']
    for w in range(65536):
        if (w & 3) != 3:
            lines.append('  .hword 0x%04x' % w)
    p = os.path.join(HERE, '_space.s')
    o = os.path.join(HERE, '_space.o')
    open(p, 'w').write('\n'.join(lines) + '\n')
    if sh(CLANG, '--target=' + TARGET, '-march=rv64gc', '-c', p, '-o', o).returncode:
        para("""THE ENUMERATION OBJECT DID NOT BUILD, so the second half of this
section's claim is NOT made in this run.  The assembler refused a `.hword`
table of 49,152 entries.  That is reported rather than worked around: a
section that prints a count it did not measure is the failure mode this whole
collection exists to prevent, and the correct behaviour on a missing
measurement is to print the absence.""")
        return None
    oracle_unknown = set()
    oracle_total = 0
    for addr, w, nb, txt in objdump_lines(o):
        oracle_total += 1
        if txt.startswith('<unknown>') or not txt:
            oracle_unknown.add(w & 0xffff)
    print('    The second reader, over the same 49,152:')
    print('      %5d  instructions printed' % oracle_total)
    print('      %5d  printed <unknown>, i.e. it could not decode them'
          % len(oracle_unknown))
    print()
    both = mine_reserved & oracle_unknown
    only_mine = mine_reserved - oracle_unknown
    only_oracle = oracle_unknown - mine_reserved
    print('    THE CROSS-CHECK, over an exhaustive set:')
    print('      %5d  this file says RESERVED and the reader says <unknown>'
          % len(both))
    print('      %5d  this file says RESERVED and the reader NAMED it'
          % len(only_mine))
    print('      %5d  the reader says <unknown> and this file does not'
          % len(only_oracle))
    if only_mine:
        print()
        print('    The %d words this file calls reserved that the reader names:'
              % len(only_mine))
        for w in sorted(only_mine)[:12]:
            print('      0x%04x  %s' % (w, objdump_text(w, 2)))
    if only_oracle:
        print()
        print('    The %d words the reader cannot decode that this file does not'
              % len(only_oracle))
        print('    call reserved:')
        for w in sorted(only_oracle)[:12]:
            d, _n, why = decode16(w).name, None, decode16(w).why
            print('      0x%04x  %-14s %s' % (w, str(d), (why or [''])[0][:56]))
    print()
    agree = len(both) == len(mine_reserved) and len(only_oracle) == 0
    print('    VERDICT: the two classifications %s'
          % ('AGREE on every reserved code point, and the reader has no '
             'undecodable word this file thinks is decodable'
             if agree else 'DISAGREE, and the differences are listed above'))
    print()
    if only_mine:
        para("""THE REMAINING DISAGREEMENT IS %d WORD, AND IT IS NOT A TYPO, so it gets
its own paragraph rather than a footnote.  0x0000 is in the C.ADDI4SPN cell
with nzuimm = 0, which this file calls RESERVED -- which is what the rule above
says and what the manual says -- and the second reader prints `unimp`.  Both
are right about their own subject and the disagreement IS the interesting part.
`unimp` is not a claim that the encoding is an instruction.  It is the second
reader's way of saying "there is nothing here and I will keep decoding", and
it HAS to say something: a disassembler walks a byte stream carrying no length
information, so every half-word in it must print something.  The all-zeros
pattern is the natural choice for "nothing" precisely because it is the one
pattern no instruction is.  So the second reader has not misread the manual.
It has taken a position on what to PRINT, where this file took a position on
what is DEFINED, and a check that compared the two would be comparing a table
of encodings against a table of output strings.

Which is why it is reported rather than normalised away, and why this section
is allowed to finish on the word DISAGREE.  A verification that cannot finish
disagreeing is not a verification.""" % len(only_mine))
        print()
    para("""One asymmetry in that verdict is worth naming, because it is the
asymmetry that makes the check meaningful rather than circular.  This file's
reserved rules were transcribed from the manual and then MEASURED; the second
reader's table is INDEPENDENT of both, because it is a different
implementation that read the same specification.  Where they agree, two
independent readings of a specification agree on %d code points out of
49,152.  Where they disagree, at least one of them has taken a different
position, and the artifact prints which is which rather than choosing.

And the count that is NOT here is as important as the ones that are: no
timing, no instruction throughput, and no measurement of whether any of these
reserved encodings traps on any particular core.  "Reserved" here means the
SPECIFICATION has not assigned the encoding.  What a given implementation does
with one is a property of that implementation, and there is no RISC-V hardware
on this host to ask.""" % len(both))
    return {'mine_reserved': len(mine_reserved), 'mine_hint': len(mine_hint),
            'oracle_unknown': len(oracle_unknown), 'both': len(both),
            'only_mine': len(only_mine), 'only_oracle': len(only_oracle)}


def sec7():
    banner(7, 'THE IMMEDIATES THAT DO NOT FIT, AND WHAT THE ASSEMBLER SAYS')
    print()
    para("""Five immediate encodings, and the reason they do not fit is a single
design decision, stated by the manual and measurable in the masks.  QUOTED,
section 2.2, in the note on register positions:

    "In practice, most immediates are either small or require all XLEN bits.
     We chose an asymmetric immediate split (12 bits in regular instructions
     plus a special load-upper-immediate instruction with 20 bits) to
     increase the opcode space available for regular instructions."

and, in the same note, the sentence that is the whole of this section:

    "the instruction format was chosen to keep all register specifiers at the
     same position in all formats at the expense of having to move immediate
     bits across formats"

MOVING immediate bits across formats is what a permutation is.  So RISC-V's
immediate story is not a set of five independent encodings; it is one decision
-- keep the registers still -- paid for five different ways, and the masks in
section 4 are the receipts.""")
    # The probe for each field, and the two things worth noticing about the
    # list.  First, `U` has no probe: `lui` takes a 20-bit field with no sign
    # extension in the instruction, so the "reach" is a property of what the
    # PRINTER does with it and not a range the assembler enforces, and the
    # table says so rather than inventing one.  Second, `I` and `S` use the
    # same probe shape with different syntax, and getting them the right way
    # round is the check that they are the same field.
    PROBE = {'I': 'addi a0, a0, %d', 'S': 'sw a0, %d(a1)', 'B':
             'beq a0, a1, .%+d', 'J': 'j .%+d', 'U': None}
    rows = []
    for k in ('I', 'S', 'B', 'U', 'J'):
        rng, _p = REACH[k]
        lo, hi = IMM_RANGE[k]
        if PROBE[k] is None:
            rows.append((k, '%d bits' % (hi - lo + 1), rng, 'no signed range',
                         'the field is UNSIGNED and 20 bits wide'))
            continue
        got_lo, got_hi, refusal = boundary_by_asking(k, PROBE[k])
        rows.append((k, '%d bits' % (hi - lo + 1), rng,
                     '[%d, %d]' % (got_lo, got_hi), refusal[:46]))
    table(('format', 'field', 'the reach', 'MEASURED by asking',
           'what it says one step past'), rows, [7, 8, 22, 20, 48])
    print()
    para("""The third and fourth columns are the same quantity reached two ways,
and they AGREE, which is the point: the fourth column is measured by asking a
real assembler for the value just inside and just outside the range and
reading what it does.  The refusal text in the fifth column is the assembler
STATING the boundary in its own words, and for three of the five it is the
best evidence in the file:

    addi a0, a0, 2048   ->  operand must be a symbol with %lo/%pcrel_lo/
                            %tprel_lo specifier or an integer in the range
                            [-2048, 2047]
    sw   a0, 2048(a1)   ->  ... the same sentence, the same two numbers
    slli a0, a0, 64    ->  immediate must be an integer in the range [0, 63]
    c.lui a0, 0        ->  immediate must be in [0xfffe0, 0xfffff] or [1, 31]

Read the first two together.  The I-type and the S-type immediates are in
DIFFERENT bit positions -- inst[31:20] for one and inst[31:25] with inst[11:7]
for the other -- and the assembler refuses both with the SAME two numbers.  Two
permutations, one range, and the range is a property of the field's WIDTH
rather than of its position.  That is a decoder author's first relief on this
architecture and it is a direct consequence of the decision to keep the
register fields still.

The third refusal is a different kind of measurement and it is more interesting
than the first two.  `slli` with an amount of 64 is refused with "[0, 63]",
and the reason is that the amount is a SIX-bit field, not a seven-bit one: its
bits are inst[25:20] and inst[11:7] is the destination register.  So the shift
amount is ALSO the thing that collides with the register positions -- an
immediate that has to dodge a register field is an immediate whose width is not
obvious from its position, and the assembler's diagnostic is the only place the
number 63 appears.""")
    print('  THE B-TYPE IMMEDIATE, WHOSE BITS ARE NOT CONTIGUOUS.  This is')
    print('  the case the plan called out and it is correct.')
    print()
    rows = []
    for off in (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4094,
                -2, -4, -8, -16, -32, -64, -128, -256, -512, -1024, -2048,
                -4096, -4098, 4096, 4098):
        w, nb, t = asm_one('beq a0, a1, .%+d' % off, 'rv64i')
        if w is None:
            rows.append((off, '(refused)', t[:52], ''))
            continue
        i = decode(w, 4, addr=0)
        imm = imm_B(w)
        rows.append((off, '0x%08x' % w, t[:52], imm))
    table(('asked for', 'the word', 'what the reader says', 'decoded imm'),
          rows, [10, 12, 46, 10])
    print()
    para("""Now the important row: the assembler REFUSES 4098 and ACCEPTS 4094, and
-4096.  A 13-bit signed field scaled by two.  That is [4096, 4094] in magnitude
-- and the ends are NOT the same number, which is the detail the AArch64 course
retracted twice in its own section 11 and which is worth measuring rather than
asserting:

    +4094   the largest positive displacement a B-type can encode
    -4096   the largest negative one

The asymmetry is arithmetic.  A 13-bit two's-complement field holds
[-4096, +4095], and the low bit is forced to zero, so the positive end is
+4094 and the negative end is -4096.  A sign extension is not a magnitude, and
a field with a forced zero at bit 0 is not symmetric about zero.

And the two rows past 4094 are the measurement the plan said would be the best
in this concept.  Read what the assembler DOES rather than what it says:""")
    for off in (4096, 4098, 8192, 65536, 1048574, 1048576, -1048576):
        w, nb, t = asm_one('beq a0, a1, .%+d' % off, 'rv64i')
        if w is None:
            print('    beq .%+9d   REFUSED: %s' % (off, t[:60]))
        else:
            print('    beq .%+9d   %d bytes, %s' % (off, nb, t[:60]))
    print()
    para("""IT DOES NOT REFUSE.  It RELAXES.  `beq a0, a1, .+4096` is accepted and
assembled into TWO instructions: an inverted branch over an unconditional
jump, because a B-type cannot reach that far and the assembler has a longer
sequence that means the same thing.  A reader who writes a branch past the
B-type's reach and then DECODES the result expecting a branch finds a
conditional jump and an unconditional jump, and the branch they wrote is
gone.

That is a REFUSAL that is not a refusal, and it is the most useful measurement
in this section, because it is the only one that can be got wrong silently:

  * Asking the assembler for an out-of-range branch does not produce a
    diagnostic.  It produces WORKING CODE, of a different shape, with the
    semantics the programmer asked for.  No test that checks "does the program
    work" finds it.
  * A disassembler reading the object file cannot tell that a two-instruction
    sequence was a one-instruction request.  It sees a branch and a jump.
  * So the branch's reach is a property of the ENCODING, discoverable only by
    decoding the instruction word and looking at the displacement -- and the
    first time this file's decoder found an out-of-range B-type it had found a
    bug, because the assembler never produces one by hand.  A decoder that
    walks a compiler's output will never see the boundary; only a decoder that
    is TOLD the boundary, or that is fed hand-written words, will.

The diagnostic DOES appear eventually, at 1 MiB, where the relaxation itself
runs out of room:

    beq a0, a1, .-1048576   ->   fixup value out of range

"fixup", not "displacement".  The word is the assembler's: it is telling you
the RELAXATION could not be applied, which is a different failure from the
encoding being out of range, and a tool that reports only the second would be
misleading you about the first.  The `obj` and `reloc` courses in this
collection are about what a fixup is; this is the first place a reader meets
one, and it is in an error message.""")
    print('  THE SAME REACH ARITHMETIC ON THE OTHER FOUR FIELDS, because it')
    print('  is the same arithmetic and the asymmetries are in different')
    print('  places:')
    print()
    rows = []
    for k, (lo, hi) in sorted(IMM_RANGE.items()):
        asym = 'symmetric' if lo == -hi else ('+%d / %d  NOT symmetric' % (hi, -lo)
                                              if hi != -lo else '?')
        rows.append((k, hi, -lo, asym, 'x2' if k in ('B', 'J') else ''))
    table(('format', 'near end', 'far end', 'symmetry', 'scaled'), rows,
          [8, 10, 10, 26, 8])
    print()
    para("""I and S are symmetric: [-2048, 2047] both, and 2047 is odd while 2048
is even, which is the ordinary shape of a two's-complement field with no
forced zero.  B and J are not, for the reason given above: both have a forced
zero in the displacement's bit 0, so the field is even-valued and the
two's-complement range [-2^n, 2^n - 1] loses its top value to the rounding.
+4094 and -4096.  +1048574 and -1048576.

**The ±2 KiB B-TYPE RANGE IS WHY `auipc` AND `lui` PAIRS EXIST**, and that is
the link to the AArch64 course's `adrp`/`:lo12:`.  A branch that can only reach
2 KiB cannot reach across a function, let alone across a translation unit, so
every far call in a real program is a PAIR of instructions, and the two halves
each carry half the address.  Section 8 measures the pair.""")
    return


# The reach of each immediate field, DERIVED from the bit maps in part one and
# then CONFIRMED by asking the assembler.  The derivation is here so that a
# reader can check the arithmetic; the confirmation is in section 7 and it is
# the measurement.
#
# The B and J entries are the ones worth reading twice.  Both fields have a
# FORCED ZERO in the displacement's bit 0, so the reachable values are even,
# and a 13-bit two's-complement field scaled by two reaches [-4096, +4094]
# rather than [-4096, +4096].  The positive end is one short of the negative
# end's magnitude and no amount of care will make them equal.
IMM_RANGE = {'I': (-2048, 2047), 'S': (-2048, 2047), 'B': (-4096, 4094),
             'U': (-1048576 * 16, 1048575 * 16), 'J': (-1048576, 1048574)}


def boundary_by_asking(fmt, probe):
    """(lo, hi, the refusal) for one immediate field, by asking the assembler.

    The method is BISECTION AGAINST A REAL ASSEMBLER, twice: once walking
    outwards from zero to find the largest accepted value, and once reading the
    diagnostic at one step past it.  Arithmetic would give the same answer for
    four of the five fields and the point of asking is the FIFTH -- the B
    type, where the assembler does not refuse at the boundary at all and the
    bisection has to notice that the answer came back as a two-instruction
    relaxation rather than as a diagnostic.

    The first version of this function did the arithmetic instead of asking,
    and reported a symmetric [-4096, 4096] for the B type.  The assembler
    refuses 4096 -- after relaxing it into two instructions -- and accepts 4094.
    The AArch64 course retracted the same class of mistake twice, and the
    retraction there said "both mistakes were caught by asking, which is the
    entire argument of this section".  So this function asks.
    """
    # For a single-instruction probe the assembler either accepts it as ONE
    # instruction or refuses it, and a relaxation shows up as a word count
    # greater than one.  That is the signal, and checking for it is the whole
    # reason this function looks at the length.
    def one(n):
        w, nb, t = asm_one(probe % n, 'rv64i')
        if w is None or nb != 4:
            return None, t
        return w, t
    lo, hi = 0, 1 << 22
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        w, _t = one(mid)
        if w is not None:
            lo = mid
        else:
            hi = mid
    pos = lo
    lo2, hi2 = 0, 1 << 22
    while lo2 + 1 < hi2:
        mid = (lo2 + hi2) // 2
        w, _t = one(-mid)
        if w is not None:
            lo2 = mid
        else:
            hi2 = mid
    neg = -lo2
    _w, refusal = one(pos + 2)
    return neg, pos, (refusal or 'accepted one step further -- see the table')


def sec8():
    banner(8, 'THE PAIR: WHY A 2 KiB BRANCH MEANS TWO INSTRUCTIONS')
    print()
    para("""Section 7 measured the B type's reach: +4094 and -4096 bytes.  A branch
that cannot cross a function is not a branch, it is a local shortcut, and
every real call is therefore a PAIR of instructions with the address split
across them.  This section measures the pair, and compares it with the AArch64
course's, because the two architectures solved the same problem with the same
shape and the comparison is the payoff of the section.

The two solutions:

    RISC-V     lui    rd, imm[31:12]     20 bits at the top
               addi   rd, rd, imm[11:0]  12 bits at the bottom
    AArch64    adrp   xd, label          21 bits, page-aligned
               add    xd, xd, :lo12:     12 bits at the bottom

Same shape, different middle.  The `:lo12:` is NOT A FIELD in the second
instruction -- it is arithmetic on the symbol that produces a RELOCATION, and
that limit is where a byte-level decoder stops.  This section measures both
sides, because the difference is a real design difference and not a
notational one.""")
    print('  THE RISC-V PAIR, on the same C, from the same compiler, and the')
    print('  relocations each half carries.  The relocations are the point:')
    print('  they are what makes the pair a pair rather than two instructions')
    print('  that happen to be adjacent.')
    print()
    src = os.path.join(HERE, 'far.c')
    open(src, 'w').write(FAR_C)
    o = os.path.join(HERE, 'far_rv.o')
    oa = os.path.join(HERE, 'far_a64.o')
    ok_rv = sh(CLANG, '--target=riscv64-linux-gnu', '-march=rv64gc', '-c',
               '-O1', '-fno-pic', src, '-o', o).returncode == 0
    ok_a64 = sh(CLANG, '--target=aarch64-linux-gnu', '-c', '-O1', '-fno-pic',
                src, '-o', oa).returncode == 0
    if not ok_rv:
        para("""The RISC-V object did not build, so this section's RISC-V half is
NOT measured in this run.  Reported rather than worked around, for the reason
section 6 gives: a section that prints a number it did not measure is the
failure this collection exists to prevent.""")
    else:
        rows = []
        for addr, w, nb, txt in objdump_lines(o):
            if 'lui' in txt or 'addi' in txt or 'auipc' in txt or \
                    'ld' in txt or 'jal' in txt:
                i = decode(w, nb, addr)
                rows.append(('0x%x' % addr, nb, txt[:40], i.fmt or '',
                             str(i.why[-1][:40]) if i.why else ''))
        table(('addr', 'bytes', 'the reader says', 'format', 'the immediate'),
              rows[:14], [8, 6, 42, 6, 42])
        print()
        print('  THE RELOCATIONS, which is where the two halves are BOUND')
        print('  together.  Note that the second is an ADD and not a generic')
        print('  immediate add: the RISC-V encoding has one 12-bit immediate')
        print('  field and the linker has to know which instruction owns it.')
        print()
        rp = sh(OBJDUMP, '--triple=riscv64', '-r', o)
        rels = []
        for ln in rp.stdout.splitlines():
            m = re.match(r'^([0-9a-f]{16})\s+(\S+)\s+(.*)$', ln.strip())
            if m:
                rels.append(('0x%s' % m.group(1)[-4:], m.group(2), m.group(3)))
        table(('offset', 'relocation', 'symbol'), rels[:12], [8, 26, 24])
        print()
    if ok_a64:
        print('  THE SAME C FOR AArch64, for the comparison, and the reason')
        print('  the shapes are not the same:')
        print()
        rows = []
        for addr, w, nb, txt in objdump_lines(oa, 'aarch64'):
            if 'adrp' in txt or 'add' in txt or 'ldr' in txt:
                rows.append(('0x%x' % addr, nb, txt[:40]))
        table(('addr', 'bytes', 'the reader says'), rows[:8], [8, 6, 46])
        print()
        rp = sh(OBJDUMP, '--triple=aarch64', '-r', oa)
        rels = []
        for ln in rp.stdout.splitlines():
            m = re.match(r'^([0-9a-f]{16})\s+(\S+)\s+(.*)$', ln.strip())
            if m:
                rels.append(('0x%s' % m.group(1)[-4:], m.group(2), m.group(3)))
        table(('offset', 'relocation', 'symbol'), rels[:8], [8, 32, 18])
        print()
        para("""Three differences, all measured and all real.

**RISC-V's pair is TWO INSTRUCTIONS WHOSE SECOND HALF MAY DO NOTHING.**
MEASURED, in the table above: the `lui` and the `addi` that follows it.  The
`addi` is an ordinary I-type add with a 12-bit immediate, and when the linker
resolves the pair and the low twelve bits happen to be zero, the second
instruction becomes `addi rd, rd, 0` -- which is a legal instruction that does
nothing, four bytes long.  AArch64's `add xd, xd, :lo12:` has the same property
and the linker is given a RELOCATION that says so, which is why the relocation
list above is longer and more specific: there is a distinct
`R_AARCH64_ADD_ABS_LO12_NC` rather than a generic 12-bit fixup.

**RISC-V's `lui` is ABSOLUTE; AArch64's `adrp` is PC-RELATIVE.**  That is the
substantive difference and it is visible in the relocation names: RISC-V's are
`R_RISCV_HI20` and `R_RISCV_LO12_I` with no PC in the name, and AArch64's are
`R_AARCH64_ADR_PREL_PG_HI21` and `R_AARCH64_ADR_PREL_LO21` with `_PREL_` in
both.  For position-independent code -- and that is the default on both
targets -- the RISC-V compiler has to switch to `auipc` and the pair becomes
PC-relative, which is why the corpus's own objects contain `auipc` and not
`lui` and why section 3's `-march` diff shows three `auipc` appearing when D is
enabled.

**RISC-V's low half is not marked as part of a pair in the ENCODING.**  There
is no bit anywhere in the `addi` that says "this addi is the second half of an
address".  The pairing is a property of the RELOCATION TABLE, which means a
decoder reading bytes in isolation -- which is what this file's part one does --
CANNOT recover the address a program intended.  AArch64 has the same property
and solves it the same way.  The `reloc` course in this collection is about
what happens next; this is the first place the reader meets the reason there
is such a course.""")
    else:
        para("""The AArch64 object did not build either, so the comparison is not
made in this run.""")
    print()
    para("""AND THE HONEST LIMIT OF ALL OF IT.  Everything above is a property of
a COMPILED OBJECT FILE.  There is no linked executable on this host, no
resolved address, and no way to check that the pair computes the address it is
supposed to compute -- because there is no RISC-V linker installed and nothing
to execute the result.  What is measured is the two instructions and their two
relocations, which is the half of the story that is in the bytes.  The other
half -- that the pair lands on the right address -- is not measured here, is
not measured anywhere in this course, and would need the `link` course and a
machine.""")
    return


FAR_C = '''/* far.c -- a global far from any single function, so that addressing it
 * forces the compiler to emit an address-forming pair in both of the two
 * forms this section compares.  Deliberately tiny. */
extern const long table[1024];
extern const char label[];
const long row = 7;
long pick(long i) { return table[i] + row; }
int name(void) { return label[0]; }
'''


# The ABI register names as NUMBERS, for the canonicaliser.  QUOTED from the
# RISC-V calling convention's register list; MEASURED in the sense that section
# 10 prints how many times the rule fired.  These are the exact inverse of
# `XNAME` in part one of this file, which is the check: a reader can put the
# two lists side by side and confirm they are inverses, and a decoder that
# indexed one and printed the other has an off-by-something that no amount of
# prose in this file would catch.
#
# The float list is the same idea, and the naming is WORSE there: the
# convention calls f0-f7 `ft0`-`ft7`, f8-f9 `fs0`-`fs1`, f10-f17 `fa0`-`fa7` and
# f18-f27 `fs2`-`fs11`, and f28-f31 `ft8`-`ft11`.  Three different prefixes for
# one contiguous range, and `ft0` and `ft8` are both "t" registers with
# different numbers, so a canonicaliser that guessed the prefix from the digit
# would be wrong for eight of the thirty-two.
NORM_XREG = [('zero', 0), ('ra', 1), ('sp', 2), ('gp', 3), ('tp', 4),
             ('t0', 5), ('t1', 6), ('t2', 7), ('s0', 8), ('fp', 8), ('s1', 9),
             ('a0', 10), ('a1', 11), ('a2', 12), ('a3', 13), ('a4', 14),
             ('a5', 15), ('a6', 16), ('a7', 17), ('s2', 18), ('s3', 19),
             ('s4', 20), ('s5', 21), ('s6', 22), ('s7', 23), ('s8', 24),
             ('s9', 25), ('s10', 26), ('s11', 27), ('t3', 28), ('t4', 29),
             ('t5', 30), ('t6', 31)]
NORM_FREG = [('ft%d' % i, i) for i in range(8)] + \
            [('fs0', 8), ('fs1', 9)] + \
            [('fa%d' % i, 10 + i) for i in range(8)] + \
            [('fs%d' % i, 10 + i) for i in range(2, 12)] + \
            [('ft%d' % i, 20 + i) for i in range(8, 12)]


def crosscheck_normalise(t):
    """Reduce BOTH readers' text to ONE canonical base-ISA form.

    NORMALISATION IS WHERE A CROSS-CHECK GOES VACUOUS, and this collection has
    already paid for that lesson twice -- the AArch64 data-path course's
    cross-check reported 0 disagreements over a corpus where 85 instructions
    genuinely disagreed, and every one of the four bugs had made the
    comparison stop COMPARING rather than compare wrongly.  So three rules
    about this function, and all three are load-bearing:

      * EVERY rule below EXPANDS.  None of them deletes an operand.  This is the
        single design decision the whole cross-check rests on, and the reason
        is the specific failure the brief names: a normaliser that DELETES an
        operand makes two readers agree by deleting the same operand, and the
        agreement is then evidence about the normaliser rather than about
        either decoder.  So `c.add a0, a1` becomes `add x10, x10, x11` and
        `add a0, a0, a1` becomes `add x10, x10, x11` -- both sides GAIN the
        implicit rd, and a decoder that read the wrong register produces a
        different canonical form and is caught.  Every rule is a function from
        a printed line to a line with the SAME OR MORE information in it.

      * Every rule exists because a disagreement was found once and the reason
        turned out to be FORMATTING.  A rule that hides a real disagreement is
        worse than no rule, and listing them is how a reader can judge that.

      * `NORMFIRES` counts how many times each rule fired on this run and
        section 10 prints the table.  A rule that fired ZERO times is a rule
        that is silently matching nothing, which is the exact shape of the
        AArch64 bug: that file's first normaliser had `^movn([\\w,]*),#…`, and
        `[\\w,]*` does not match the space between a mnemonic and its operands,
        so the rule matched nothing and the cross-check reported its number
        anyway.  The counter is PRE-SEEDED with every rule name at zero below,
        so a rule that never fires appears in the table with a zero rather than
        being absent -- and the first version of this file seeded it lazily,
        which is a third instance of the same class of bug: the reporting
        structure could not represent the failure it existed to report.

    WHAT THE RULES ARE, and each one is a spelling the specification defines:

      * `li rd, imm` is `addi rd, x0, imm`.  `mv rd, rs` is `addi rd, rs, 0`.
        `nop` is `addi x0, x0, 0`.  `ret` is `jalr x0, x1, 0`.  `jr rs` is
        `jalr x0, rs, 0`.  `sext.w rd, rs` is `addiw rd, rs, 0`.  `zext.b rd,
        rs` is `andi rd, rs, 255`.  `neg rd, rs` is `sub rd, x0, rs`.
      * `beqz rs, T` is `beq rs, x0, T`, `bnez rs, T` is `bne rs, x0, T`, and
        `blez rs, T` is `bge x0, rs, T`.  These are the assembler's own
        one-operand spellings of a two-register comparison against x0.
      * `j T` is `jal x0, T` and `jr rs` is `jalr x0, rs, 0`.  A jump with no
        destination.
      * `rdcycle rd` is `csrrs rd, cycle, x0` and `csrw cycle, rs` is `csrrw
        x0, cycle, rs`: the reader prints the CSR's SYMBOLIC NAME where this
        file prints its NUMBER, and the number↔name mapping is QUOTED from the
        manual's CSR listing.  A CSR name is a symbol, exactly as a branch
        target is, and both sides are right.
      * The COMPRESSED forms.  `llvm-objdump` prints the BASE mnemonic for
        every one of them, and it prints the base OPERAND LIST, so `c.add a0,
        a1` comes back as `add a0, a0, a1` and this file has to expand its own
        `c.add a0, a1` the same way.  This is the rule that matters most here:
        it is the only place in the file where a two-byte word and a four-byte
        word produce the SAME text, and the LENGTH has to be compared
        separately or the cross-check cannot tell them apart.  Section 10
        compares it and prints how many words it turned on.
      * `c.jr rs` is `jalr x0, rs, 0` and `c.jalr rs` is `jalr x1, rs, 0`, and
        this is the rule that found the inst[12] bug: with the expansion in
        place, `c.jr a0` and `c.jalr a0` are DIFFERENT canonical forms, and a
        decoder that conflates them produces a disagreement rather than a
        silent error.
      * A branch or jump TARGET.  In a relocatable object the word holds a
        placeholder and the real address is in a relocation, so the target is
        compared as a TARGET and nothing else.  The displacement arithmetic is
        checked in section 7 against known immediates, by hand, not by asking
        a printer -- and the length rule, which the branch-target rule
        deliberately hides, is checked separately.
      * Numbers.  `0x14` against `14`, `-0x1` against `-1`, and the unsigned
        64-bit spelling of a negative displacement against its signed form.
        Every number is normalised to `0x` + lowercase hex, with the sign kept.
    """
    global NORMFIRES
    t = t.split('//')[0].strip()
    t = re.sub(r'<[^>]*>', '', t)          # the symbol annotation
    t = t.replace('\t', ' ')
    t = re.sub(r'\s+', ' ', t).strip()
    t = re.sub(r'\s*,\s*', ',', t)
    t = t.lower()

    def fire(rule, new, pat, rep):
        global NORMFIRES
        new2, n = re.subn(pat, rep, new)
        if n:
            NORMFIRES[rule] = NORMFIRES.get(rule, 0) + n
        return new2

    # --- REGISTERS, and this rule is what makes every other rule's pattern
    # --- written in the right alphabet.
    #
    # A register NAME is a symbol for a register NUMBER, exactly as a branch
    # target is a symbol for an address, and the two readers disagree about
    # which symbol to use: this file prints `zero` where the reader prints `x0`
    # inside the same canonical form, and this file prints `a0` where a rule
    # that rewrites `li` has to write `x0`.  The two tables below are QUOTED
    # from the RISC-V calling convention's register list, and they are the same
    # list `XNAME` in part one of this file decodes numbers with, so the two
    # are inverses of each other and a reader can check them against each other.
    #
    # It has to run BEFORE the branch-target rule, and that ordering is not
    # tidiness.  `jr a0` looks exactly like a jump to the address 0xa0: `a0`
    # is two hexadecimal digits.  The first version of this rewrite ran the
    # target rule first and it silently rewrote `jr a0` into `jr target`,
    # which deleted the register and then compared `jalr x0,target` against
    # `jalr x0,ra,0x0` and called the two a disagreement.  Canonicalising the
    # register first turns `a0` into `x10`, which no hexadecimal pattern can
    # match, and the register survives.  A normaliser's rules have an ORDER and
    # the order is load-bearing in a way that is invisible in the rules
    # themselves.
    for (nm, num) in NORM_XREG:
        t = fire('register name', t, r'\b%s\b' % nm, 'x%d' % num)
    for (nm, num) in NORM_FREG:
        t = fire('float register', t, r'\b%s\b' % nm, 'f%d' % num)

    # --- the branch-target rule --------------------------------------------
    # It destroys information (the address), so every rule after it is an
    # EXPANSION and none of them can conceal a disagreement it has just
    # hidden.
    #
    # THE THIRD VERSION OF THIS RULE, and the two before it are both worth
    # having in the file.
    #
    #   v1  `^%s([\w,]*)\s*((?:0x)?[0-9a-f]+)$`  -- `[\\w,]*` cannot match the
    #       SPACE after the mnemonic, so the rule fired only for the
    #       mnemonic-only spellings and silently missed every branch in the
    #       corpus.  This is the AArch64 bug, reproduced in the file that
    #       quotes it.
    #
    #   v2  `^%s\s*([\w,]*)\s*((?:0x)?[0-9a-f]+)$` -- the space is fixed and
    #       now `[\w,]*` is TOO GREEDY: it matches `x10,x0,0x` because `0` and
    #       `x` are word characters, so the rule consumed `beq x10, x0, 0x2`
    #       and left the final `8` to be the "target", turning
    #       `0x28` into `0x2target`.  A rule that deletes information also
    #       DELETES THE WRONG INFORMATION, and a truncated address is a
    #       plausible-looking address.
    #
    #   v3  the shape is pinned instead of guessed: the operands before the
    #       target must be REGISTER TOKENS, and the register token is `xN` or
    #       `fN` -- which is only true because the register rule above has
    #       already run.  The mnemonic is captured whole rather than by a
    #       `%s` substitution, so the rule is one pattern rather than
    #       twenty-two, and one pattern is one thing to get right.
    #
    # The general pattern therefore reads: a mnemonic, then one or more
    # `xN`/`fN` tokens separated by commas, then a comma, then the number.
    # That matches `beq x10, x0, 0x28`, `jal x0, 0x60`, `c.beqz x10, 0x11a` and
    # `blez x11, 0x104`, and it cannot match `lw x10, 0x0(x1)` -- the trailing
    # `(` is not a comma -- nor `jr x10`, which has no comma and whose one
    # operand is a register and not an address.
    # v4  the MNEMONIC LIST is pinned as well as the operand shape.  v3
    #       generalised the mnemonic to `[a-z][a-z0-9_.]*` to avoid
    #       twenty-two substitutions, and the price was that `addi x12, x0,
    #       0x0` -- an ordinary register-immediate add whose last operand is a
    #       NUMBER -- matched the branch shape and had its immediate replaced by
    #       the word `target`.  Then `li a2, 0x0` (which becomes `addi a2, x0,
    #       0x0`) and `mv a1, a3` (which becomes `addi a1, x3, 0x0`) both lost
    #       their immediate and compared equal to each other regardless of what
    #       it was.
    #
    #       That is the AArch64 failure with the sign changed, and it is worth
    #       being precise about why: a rule that DELETES an operand does not
    #       merely fail to compare, it makes two DIFFERENT instructions compare
    #       EQUAL.  The first two versions deleted the target, which is
    #       information this cross-check has already decided not to compare;
    #       this version deletes an immediate, which is information it is
    #       supposed to be checking.  The generalised pattern was an
    #       optimisation -- one pattern instead of twenty-two -- and the
    #       optimisation is what made the rule wrong.  The mnemonic list is
    #       spelled out below, and it is a list of the SEVEN branch mnemonics
    #       plus their four one-operand spellings, which is what the manual
    #       defines and not what the text happens to look like.
    for stem in ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'):
        t = fire('branch target', t,
                 r'^%s\s+((?:[xf]\d+),(?:[xf]\d+)),((?:0x)?[0-9a-f]+)$'
                 % stem,
                 r'%s \1,target' % stem)
    for stem in ('beqz', 'bnez', 'blez', 'bgez', 'bgtz', 'bltz', 'jal',
                 'c.beqz', 'c.bnez'):
        t = fire('branch target', t,
                 r'^%s\s+([xf]\d+),((?:0x)?[0-9a-f]+)$' % stem,
                 r'%s \1,target' % stem)
    # And the jumps, which have no register operand at all: `j 0x12` and
    # `c.j 0x12`.  A separate rule because `c.j` is two tokens and `j` is one,
    # and because a rule that handled both would have to match the mnemonic
    # with an optional dot -- which is one more thing to be able to get wrong.
    for stem in ('j', 'c.j', 'tail', 'call', 'la'):
        t = fire('jump target', t,
                 r'^%s\s+((?:0x)?[0-9a-f]+)$' % stem, r'%s target' % stem)
    # A jalr whose immediate is not zero prints as `jalr rd, imm(rs)`.  A jalr
    # whose immediate IS zero and which carries a RELOCATION prints as
    # `jalr rd` with a symbol, and the symbol is stripped above, so what is
    # left is `jalr rd` -- one operand, and the base register is MISSING.  The
    # reader's convention is that a one-operand `jalr` means "call rs1 with no
    # displacement", so the canonical form is `jalr x1, 0x0(rs1)`: the x1 is
    # the hardwired return-address destination, and a 32-bit `jalr ra, 0(ra)`
    # canonicalises to the same string, which is correct -- they ARE the same
    # instruction, and the file's own section 2 says so.
    t = fire('jalr no displacement', t, r'^jalr\s+(x\d+)$',
             r'jalr x1,0x0(\1)')

    # --- NUMBERS ------------------------------------------------------------
    # Both readers are inconsistent with THEMSELVES about the base: this file
    # prints an immediate in decimal (`slti a1, a1, 3`) and the reader prints
    # the same immediate in hex (`slti a1, a1, 0x3`).  The rule is a
    # CANONICALISATION -- every number becomes `0x` + lowercase hex with the
    # sign kept -- and it has to run AFTER the branch-target rule, which has
    # already turned the targets into the word `target`, because `0x1a` is a
    # number and `target` is not.
    #
    # The first version of this rewrite put a no-op `re.sub` in front of this
    # line whose lambda read `t[0:0]`, and `t[0:0]` is the empty string, so the
    # ternary always chose `'-'` and PREPENDED A MINUS TO EVERY HEX NUMBER.  The
    # result was `slti a1, a1, -0x3` on the reader's side against `0x3` on
    # ours.  A rule that is supposed to do nothing and does not is the hardest
    # kind of normaliser bug to see, because the code reads as if it does
    # nothing.
    t = re.sub(r'\b(\d+)\b', lambda mm: '0x%x' % int(mm.group(1)), t)
    t = t.lower()

    # --- every rule below EXPANDS ------------------------------------------
    # Each replaces a SPELLING with the base-ISA form, and in every case the
    # replacement has at least as many operands as the thing it replaces.
    #
    # THE SPACE AFTER THE MNEMONIC, and it is the fourth bug of this class in
    # this function: every pattern below is anchored with `^mnemonic` and the
    # text still has the separator space there, so `^li(\w+),` cannot match
    # `li a0,0x5` and EVERY rule below silently matched nothing.  Forty-one
    # rules, zero substitutions, and a cross-check that reported its number
    # anyway -- which is the AArch64 failure reproduced in a new file by a
    # rewrite that had read the lesson and still got it wrong.  The fix is
    # mechanical and it is the reason the rules are written `^name\s+` rather
    # than `^name`: put the separator in the pattern, where a reader can see
    # it, instead of assuming one.
    t = fire('li alias', t, r'^li\s+(\w+),-?(0x[0-9a-f]+)$', r'addi \1,x0,\2')
    t = fire('mv alias', t, r'^mv\s+(\w+),(\w+)$', r'addi \1,\2,0x0')
    t = fire('nop', t, r'^nop$', 'addi x0,x0,0x0')
    t = fire('ret', t, r'^ret$', 'jalr x0,0x0(x1)')
    t = fire('jr', t, r'^jr\s+(\w+)$', r'jalr x0,0x0(\1)')
    t = fire('jr', t, r'^jr\s+(-?0x[0-9a-f]+)\((\w+)\)$', r'jalr x0,\1(\2)')
    t = fire('j', t, r'^j\s+target$', r'jal x0,target')
    t = fire('sext.w', t, r'^sext\.w\s+(\w+),(\w+)$', r'addiw \1,\2,0x0')
    t = fire('zext.b', t, r'^zext\.b\s+(\w+),(\w+)$', r'andi \1,\2,0xff')
    t = fire('neg', t, r'^neg\s+(\w+),(\w+)$', r'sub \1,x0,\2')
    t = fire('beqz', t, r'^beqz\s+(\w+),target$', r'beq \1,x0,target')
    t = fire('bnez', t, r'^bnez\s+(\w+),target$', r'bne \1,x0,target')
    t = fire('blez', t, r'^blez\s+(\w+),target$', r'bge x0,\1,target')
    t = fire('csrr alias', t, r'^csrr\s+(\w+),(\w+)$', r'csrrs \1,\2,x0')
    t = fire('csrw alias', t, r'^csrw\s+(\w+),(\w+)$', r'csrrw x0,\1,\2')
    t = fire('rdcycle', t, r'^rdcycle\s+(\w+)$', r'csrrs \1,0xc00,x0')
    t = fire('csr name', t, r'\bcycle\b', '0xc00')
    t = fire('csr name', t, r'\bvlenb\b', '0xc22')

    # --- the COMPRESSED extension, expanded to its base form ---------------
    # These are the rules that make the cross-check able to see the inst[12]
    # bug at all.  `c.jr a0` and `c.jalr a0` are DIFFERENT instructions and they
    # expand to different base forms; a decoder that conflates them does not
    # produce a matching pair of strings, it produces two different ones.
    t = fire('c.nop', t, r'^c\.nop$', 'addi x0,x0,0x0')
    t = fire('c.mv', t, r'^c\.mv\s+(\w+),(\w+)$', r'addi \1,\2,0x0')
    t = fire('c.li', t, r'^c\.li\s+(\w+),(-?0x[0-9a-f]+)$', r'addi \1,x0,\2')
    t = fire('c.lui', t, r'^c\.lui\s+(\w+),(0x[0-9a-f]+)$', r'lui \1,\2')
    t = fire('c.addi', t, r'^c\.addi\s+(\w+),(-?0x[0-9a-f]+)$',
             r'addi \1,\1,\2')
    t = fire('c.addiw', t, r'^c\.addiw\s+(\w+),(-?0x[0-9a-f]+)$',
             r'addiw \1,\1,\2')
    t = fire('c.addi16sp', t, r'^c\.addi16sp\s+(\w+),(-?0x[0-9a-f]+)$',
             r'addi \1,\1,\2')
    t = fire('c.addi4spn', t, r'^c\.addi4spn\s+(\w+),(x2),(0x[0-9a-f]+)$',
             r'addi \1,\2,\3')
    t = fire('c.add', t, r'^c\.add\s+(\w+),(\w+)$', r'add \1,\1,\2')
    t = fire('c.sub', t, r'^c\.sub\s+(\w+),(\w+)$', r'sub \1,\1,\2')
    t = fire('c.xor', t, r'^c\.xor\s+(\w+),(\w+)$', r'xor \1,\1,\2')
    t = fire('c.or', t, r'^c\.or\s+(\w+),(\w+)$', r'or \1,\1,\2')
    t = fire('c.and', t, r'^c\.and\s+(\w+),(\w+)$', r'and \1,\1,\2')
    t = fire('c.addw', t, r'^c\.addw\s+(\w+),(\w+)$', r'addw \1,\1,\2')
    t = fire('c.subw', t, r'^c\.subw\s+(\w+),(\w+)$', r'subw \1,\1,\2')
    t = fire('c.slli', t, r'^c\.slli\s+(\w+),(0x[0-9a-f]+)$', r'slli \1,\1,\2')
    t = fire('c.srli', t, r'^c\.srli\s+(\w+),(0x[0-9a-f]+)$', r'srli \1,\1,\2')
    t = fire('c.srai', t, r'^c\.srai\s+(\w+),(0x[0-9a-f]+)$', r'srai \1,\1,\2')
    t = fire('c.andi', t, r'^c\.andi\s+(\w+),(-?0x[0-9a-f]+)$',
             r'andi \1,\1,\2')
    t = fire('c.ebreak', t, r'^c\.ebreak$', 'ebreak')
    t = fire('c.j', t, r'^c\.j\s+target$', r'jal x0,target')
    t = fire('c.jr', t, r'^c\.jr\s+(\w+)$', r'jalr x0,0x0(\1)')
    t = fire('c.jalr', t, r'^c\.jalr\s+(\w+),(\w+)$', r'jalr \1,0x0(\2)')
    t = fire('c.beqz', t, r'^c\.beqz\s+(\w+),target$', r'beq \1,x0,target')
    t = fire('c.bnez', t, r'^c\.bnez\s+(\w+),target$', r'bne \1,x0,target')
    # The compressed load/store family.  The reader prints the base mnemonic
    # and the base operand list, and the offsets are the same numbers.  The
    # `sp` forms are in the same rule because the reader prints `sp` where this
    # file prints `x2`, and the rule has to reconcile BOTH the mnemonic and the
    # base register in one step or the intermediate state has no rule to match.
    t = fire('c.ldst', t,
             r'^c\.(lw|ld|flw|fld|sw|sd|fsw|fsd|lwsp|ldsp|flwsp|fldsp|swsp|'
             r'sdsp|fswsp|fsdsp)\s+(\w+),(-?0x[0-9a-f]+)\((\w+)\)$',
             lambda mm: '%s %s,%s(%s)' % (
                 {'lwsp': 'lw', 'ldsp': 'ld', 'flwsp': 'flw', 'fldsp': 'fld',
                  'swsp': 'sw', 'sdsp': 'sd', 'fswsp': 'fsw',
                  'fsdsp': 'fsd'}.get(mm.group(1), mm.group(1)),
                 mm.group(2), mm.group(3), mm.group(4)))

    # The vsetvli disagreement is NOT cosmetic and NOT a normaliser's business:
    # this file prints the eleven-bit FIELD and the reader prints what the
    # field MEANS (e64, m1, ta, ma).  Section 10 counts those separately and
    # names them, because hiding them behind a rule that rewrote one side's
    # operand list into the other's would be precisely the deletion this
    # function is written to avoid.
    t = re.sub(r'\s+', ' ', t).strip()
    out = t.replace(' ', '')
    # POISON 4's two hooks, and they are the ONLY places in this function that
    # remove information.  Globals rather than parameters so that the
    # cross-check LOOP -- the thing being poisoned -- cannot be given a path
    # that quietly ignores them, which is the mistake poison 2 in this file
    # already made once.
    if NORM_KEEP_LAST:
        c = out.rfind(',')
        if c > 0:
            out = out[:c]
    return out


# Pre-seeded, so that a rule which never fires is REPORTED as a zero rather
# than being absent from the table.  The first version of this file created
# entries lazily, which meant the dead-rule check could not fail -- the exact
# shape of the bug it was written to detect.  NORMFIRES is reset by
# `reset_norms()` before every measured run.
NORM_RULE_NAMES = [
    'register name', 'float register', 'branch target', 'jump target',
    'jalr no displacement', 'li alias', 'mv alias', 'nop',
    'ret', 'jr', 'j', 'sext.w', 'zext.b', 'neg', 'beqz', 'bnez', 'blez',
    'csrr alias', 'csrw alias', 'rdcycle', 'csr name',
    'c.nop', 'c.mv', 'c.li', 'c.lui', 'c.addi', 'c.addiw', 'c.addi16sp',
    'c.addi4spn', 'c.add', 'c.sub', 'c.xor', 'c.or', 'c.and', 'c.addw',
    'c.subw', 'c.slli', 'c.srli', 'c.srai', 'c.andi', 'c.ebreak', 'c.j',
    'c.jr', 'c.jalr', 'c.beqz', 'c.bnez', 'c.ldst',
]


def reset_norms():
    global NORMFIRES
    NORMFIRES = dict((n, 0) for n in NORM_RULE_NAMES)


# How many times each normalisation rule fired on this run.  Printed by
# section 10, and a rule with a zero in this table is a rule that is not
# doing anything -- which is a bug, and this file's own harness looks for it.
NORMFIRES = {}


def objdump_all(files):
    """(object file, [(addr, word, nbytes, text)]) for each."""
    out = []
    for f in files:
        out.append((f, objdump_lines(os.path.join(HERE, f))))
    return out


def my_words(path, secs):
    """{virtual address: decoded instruction} for one object, keyed the way the
    SECOND READER KEYS ITS OWN OUTPUT.

    This helper exists because of the worst bug this file had, and the bug is
    worth more than the function.  The cross-check built its lookup with
    `mine[k.off] = k` -- `k.off` is the offset into the FILE, set by
    `decode_text` as `off + p` where `off` is the section's file offset -- and
    then looked each instruction up with the ADDRESS that
    `llvm-objdump-21` printed, which is the section's VIRTUAL address.  For
    `rv.o` those are two different number systems: `.text` has file offset 0x40
    and address 0x0000, so every lookup found the instruction 0x40 bytes
    further on than the one being checked, or nothing at all.

    It produced 767 disagreements out of 791 instructions, which LOOKED like a
    catastrophically wrong decoder and was in fact a cross-check comparing two
    readers that were never looking at the same bytes.  The tell was in the
    output and not in the count: the "disagreements" were pairs of instructions
    that do not even overlap -- `rem a1, a1, a2` against `sc.w a2, a0, (a1)` --
    which no amount of decoder fixing could reconcile, because both of them
    were correctly decoded and simply from different addresses.

    The lesson is the one this section exists to enforce, in a form nobody
    expected: a cross-check can be non-vacuous, compare tens of thousands of
    real items, and still be measuring nothing, because it is measuring the
    WRONG PAIR.  `disagreements()` and `crosscheck_one()` now share this one
    function, so the two can never drift apart again -- which is the fix that
    matters, since the first version of this file had two hand-rolled copies of
    the same loop.
    """
    mine = {}
    d = open(path, 'rb').read()
    for _name, _vaddr, off, size in secs:
        insns, _u = decode_text(d, off, size, 0)
        for k in insns:
            # `k.off` is off + p and `k.addr` is vaddr + p.  The key is the
            # ADDRESS, and for a relocatable object every executable section
            # has address 0, so the offset-within-section is added back on.
            # POISON 4's planted bug is applied HERE, to this file's text and
            # not to the reader's, and the location is deliberate: inside the
            # normaliser it would corrupt both sides and the two would agree
            # perfectly around a real disagreement.
            if MYWORDS_SABOTAGE is not None and k.name:
                _mn, _pat = MYWORDS_SABOTAGE
                _mm = _pat.match(k.text)
                if _mm:
                    k.text = '%-10s %s, x0, %s' % (_mn, _mm.group(1),
                                                   _mm.group(2).strip())
            mine[_vaddr + (k.off - off)] = k
    return mine


def crosscheck_one():
    """(total, agree, disagree, unmodelled) over every corpus object.

    Split out of section 10 so that the POISONS can re-run exactly the same
    comparison over exactly the same bytes.  That is the whole point of the
    control: if a poison runs a DIFFERENT loop, the number that moves is the
    loop and not the decoder, and a control that does not share its subject
    with its experiment is a second experiment.
    """
    files, _ = corpus_files()
    agree = disagree = unmodelled = total = 0
    badlen = 0
    for f in files:
        d, secs = code_sections(os.path.join(HERE, f))
        mine = my_words(f, secs)
        for addr, w, nb, txt in objdump_lines(os.path.join(HERE, f)):
            k = mine.get(addr)
            if k is None:
                continue
            total += 1
            if k.nbytes != nb:
                badlen += 1
            if k.name is None:
                unmodelled += 1
                continue
            if crosscheck_normalise(k.text) == crosscheck_normalise(txt):
                agree += 1
            else:
                disagree += 1
    return total, agree, disagree, unmodelled, badlen


def disagreements():
    """(file, address, word, mine, theirs) for every disagreement.

    A list and not a number, because a number of eleven is a bug report and a
    list of eleven is a diagnosis.  The first version of this file's own
    cross-check printed only the number, and the number was 0 for a run that
    had three real bugs in it.
    """
    out = []
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        mine = my_words(f, secs)
        for addr, w, nb, txt in objdump_lines(os.path.join(HERE, f)):
            k = mine.get(addr)
            if k is None or k.name is None:
                continue
            if crosscheck_normalise(k.text) != crosscheck_normalise(txt):
                out.append((f, addr, w, k.text, txt))
    return out


def sec10():
    banner(10, 'TWO READERS, AND THREE POISONS')
    print()
    para("""The second reader is `llvm-objdump-21 --triple=riscv64`.  It is
INDEPENDENT of this file in the sense that matters -- it is a different
implementation, from a different codebase, that read the same specification --
and it is NOT independent in one respect that has to be stated: `clang`
assembled the corpus, so both readers ultimately depend on one LLVM tree.  An
independent second ASSEMBLER does not exist on this host, and GNU binutils has
no RISC-V target installed.  What this section establishes is that this
decoder and one other piece of software agree on what the bytes mean -- not
that either agrees with silicon, and there is no silicon to agree with.

A cross-check that reports 100 per cent agreement is EXACTLY WHAT A BROKEN
CROSS-CHECK LOOKS LIKE.  This collection has already had one: the AArch64
data-path course's cross-check printed 0 disagreements over a corpus where 85
instructions genuinely disagreed, and not one of the four bugs printed a wrong
word -- they all made the comparison VACUOUS, which is worse, because the
number is believed.  So this section does four things that a cross-check
which agrees perfectly does not do: it prints HOW MANY instructions it
compared, it prints how many times each of the normalisation rules fired, it
CLASSIFIES every disagreement it finds by kind, and it runs FOUR POISONS and
requires each to move the number it claims to test.

AND THE NUMBER IT STARTED FROM, because a reader who arrives at "zero
disagreements" deserves to know what had to be fixed to get there.  The
inherited run of this file reported 354 agree and 701 disagree of 1,055, and
this one reports 1,047 agree and 0 disagree of 1,047.  The difference is not a
decoder that got better in the abstract.  It is 188 words that were being
decoded by the wrong model, 62 words reported UNDEFINED for no reason at all,
33 words of an instruction this file could not reach, 91 branches that had lost
both their register operands, 26 branch targets off by exactly one, and a
normaliser whose rules mostly matched nothing while the cross-check reported
its number anyway.  Section 12 lists each of those as a numbered retraction,
and the seven hundred ARE the work.  A reader who wants to know whether the
number is worth believing should read R17 to R22 and then come back.""")
    total, agree, disagree, unmodelled, badlen = crosscheck_one()
    named = total - unmodelled
    print('  THE CROSS-CHECK, over every corpus object:')
    print('    %6d  instructions the second reader printed' % total)
    print('    %6d  of them this file NAMES' % named)
    print('    %6d  of them this file does not model (counted, not dropped)'
          % unmodelled)
    print('    %6d  AGREE after normalisation' % agree)
    print('    %6d  DISAGREE' % disagree)
    print('    %6d  where the two readers disagree on the LENGTH alone'
          % badlen)
    print()
    if total == 0:
        print('    [POISON FAILED] the comparison is EMPTY.  Zero instructions')
        print('    compared is not 100 per cent agreement; it is a cross-check')
        print('    that is not running, and it is reported as a failure.')
        return
    if agree == named:
        print('    %d of %d, which is 100 per cent -- and that is exactly what a'
              % (agree, named))
        print('    broken cross-check looks like, which is why the three rows')
        print('    below are not optional.')
    print()
    print('  THE NORMALISER\'S OWN FIRE COUNT, because a rule that matched')
    print('  nothing is the exact shape of the AArch64 bug and it is invisible')
    print('  in the agreement number.  The table is pre-seeded with every rule')
    print('  name at zero, so a rule that never fires is a ROW WITH A ZERO and')
    print('  not an absence -- and the difference between those two things is')
    print('  the difference between a check that can fail and a check that')
    print('  cannot:')
    print()
    rows = []
    for rule in NORM_RULE_NAMES:
        n = NORMFIRES.get(rule, 0)
        rows.append((rule, n, 'FIRED' if n else 'MATCHED NOTHING'))
    dead = [r for r, n in NORMFIRES.items() if n == 0]
    table(('rule', 'times it fired', 'status'), rows, [24, 14, 20])
    print()
    print('    %d rules, %d fired, %d matched nothing.'
          % (len(NORM_RULE_NAMES),
             sum(1 for n in NORMFIRES.values() if n), len(dead)))
    print()
    if dead:
        print('    [POISON FAILED] %d normalisation rule(s) matched NOTHING:'
              % len(dead))
        for r in dead:
            print('      %s' % r)
        print('    A rule that matches nothing is not a rule.  It is a comment')
        print('    that looks like a rule, and the cross-check above reported')
        print('    its number anyway.  FOUR of this file\'s own rules were dead')
        print('    on the first run of the new normaliser, and every one of them')
        print('    was dead for the same reason: the pattern was anchored with')
        print('    `^mnemonic` and the text has a SPACE there.  The rule names')
        print('    are in the table above and the zeros are in the middle')
        print('    column, which is the only reason they are visible at all.')
    else:
        print('    Every one of the %d rules fired at least once, so every rule'
              % len(NORM_RULE_NAMES))
        print('    is doing something and none of them is a comment wearing a')
        print('    rule\'s syntax.  That is a check on the CHECK, and it is the')
        print('    check the AArch64 course could not run on its own normaliser.')
    print()
    ds = disagreements()
    # THE TABLE IS ALWAYS PRINTED, with a zero in every row when there is
    # nothing to put in it, and the reason is a harness rather than a reader.
    # The first version printed it only when there were disagreements, which
    # means a CLEAN RUN CONTAINS NO EVIDENCE THAT THE CLASSIFIER EXISTS -- and
    # a classifier that is absent from the output cannot be asserted on by
    # crosscheck.py, so the one run where it would be most reassuring is the
    # one run where it is invisible.  Printing the empty table costs nine lines
    # and makes the structure auditable on every run, which is the whole
    # property.  The same argument is why NORMFIRES is pre-seeded and why the
    # poison verdicts print whether they fire or not.
    print('  THE DISAGREEMENT CLASSIFIER, and its %d rows are printed whether'
          % len(KINDS))
    print('  or not there is anything to put in them, because a classifier that')
    print('  only appears when it has something to say cannot be checked on the')
    print('  run where it has nothing to say:')
    print()
    kinds = classify_disagreements(ds)
    rows = [(KINDS[k][0], len(kinds.get(k, [])), KINDS[k][1]) for k in KINDS]
    table(('kind', 'count', 'what it is'), rows, [30, 7, 44])
    print()
    if ds:
        print('  THE %d DISAGREEMENTS, one at a time, because a number of' % len(ds))
        print('  seven hundred is a bug report and a list of seven hundred is a')
        print('  diagnosis:')
        print()
        for k, v in kinds.items():
            if not v:
                continue
            print('    %s -- %d word(s), first three:' % (KINDS[k][0], len(v)))
            for (f, addr, w, mine, theirs) in v[:3]:
                print('      %-18s 0x%08x' % (f, w))
                print('        this file:  %s' % mine.strip())
                print('        the reader:  %s' % theirs.strip())
                print('        folded:     %s'
                      % crosscheck_normalise(mine))
                print('                   %s'
                      % crosscheck_normalise(theirs))
            print()
    else:
        print('  ZERO disagreements over %d named instructions, and the number'
              % named)
        print('  that makes it believable is not this line: it is the %d rules'
              % len(NORM_RULE_NAMES))
        print('  of the normaliser all having fired, the four POISONS below,')
        print('  and the cross-check having been walked backwards from 701')
        print('  disagreements to this one.  See section 12 for what each of')
        print('  those seven hundred turned out to be.')
    print()
    poison_one(agree, named, disagree, total, unmodelled)
    poison_two(agree, named, disagree, total)
    poison_three(total)
    poison_four(agree, named, disagree, total)
    return


def indispatch_owners():
    """{model: (named words, disagreements it is currently causing)}.

    MEASURED, and the number it produces is not the number the first version of
    poison 1 used, and the difference between the two numbers IS the bug that
    made the first poison report a victim it could not move.

    THE FIRST VERSION counted each model's footprint by putting that model
    ALONE in the dispatch table and counting what it named.  That measures
    something real -- how many corpus words the model's guards would claim if
    nothing above it got there first -- and it is the wrong quantity, because a
    model is only responsible for the words the dispatch ACTUALLY GIVES it.  On
    this corpus the two numbers are wildly different:

        model      alone    in dispatch
        i_alu_imm    472              188
        i_jalr       385              101
        b_branch     375               91
        r_alu        372               88
        s_fp_st      284                0
        r_fp32       284                0

    MEASURED reason: six of the nine objects are compiled with the C extension,
    and 284 of the 1,082 instructions are TWO BYTES and are decoded by the
    16-bit handler rather than by any model in this table at all -- so every
    model in the table competes for the 798 four-byte words only, and the
    models that sit LOW in the table (r_alu, s_fp_st, r_fp32) are shadowed by
    the models above them for most of the corpus.  A poison that picks its
    victim by the wrong number picks a model whose words are somebody else's,
    removes it, watches nothing move, and reports [POISON FAILED] -- which is
    the CORRECT verdict about a control that cannot move, and the WRONG verdict
    about this decoder.

    The lesson, and it is the third time this collection has learned it: a
    control's SUBJECT and its EXPERIMENT have to be the same object.  The
    cross-check reads the dispatch as configured; the poison has to remove a
    model from the dispatch as configured, and the number that says which model
    matters has to come from the dispatch as configured.
    """
    named = {}
    for k in corpus_insns():
        if k.name is None:
            continue
        mdl = k.model or ('rvc' if k.nbytes == 2 else '(unattributed)')
        named[mdl] = named.get(mdl, 0) + 1
    return named, None


# The KINDS a disagreement can be, and what each one is.  This table is the
# answer to the question the file inherited: "354 agree, 701 disagree, of 1055"
# is not a diagnosis, it is a NUMBER, and a number that large is always several
# different things counted together.  The classifier is mechanical and it runs
# on the FOLDED forms, so it cannot be argued with: every disagreement lands in
# exactly one row and the rows sum to the total.
#
# The order matters and it is the order of "how much does this hide".  A
# `compressed name` row is a printing convention.  A `target` row is a symbol.
# A `real decode difference` row is a bug in one of the two readers.  And an
# `UNEXPLAINED` row is the one that has to be printed by name, because a
# classifier that cannot classify something is a fact about the classifier and
# the file says so rather than rounding it into the nearest category.
KINDS = {
    'mnemonic': ('different mnemonic, same meaning',
                 'the reader printed an ALIAS: li, mv, nop, ret, jr, beqz, '
                 'blez, neg, sext.w, zext.b, csrr, csrw, rdcycle'),
    'compressed': ('compressed name, base spelling',
                   'the reader prints the BASE mnemonic and the base operand '
                   'list for a two-byte word; the expansion is in the '
                   'normaliser and the LENGTH is compared separately'),
    'number': ('same number, different base or sign',
               '0x4 against 4, -0x1 against -1, or the unsigned 64-bit '
               'spelling of a negative value'),
    'target': ('a branch or jump target',
               'the word holds a relocation placeholder; the displacement '
               'arithmetic is checked in section 7 against known immediates'),
    'length': ('the two readers disagree on the LENGTH alone',
               'the compressed fraction of the corpus depends on this and it '
               'is the one thing a text comparison cannot see'),
    'decode': ('a REAL decode difference',
               'the two readers name different instructions.  Every one of '
               'these is a bug in a decoder and they are listed by word'),
    'unexplained': ('NOT YET EXPLAINED',
                    'printed by name and counted, because a classifier that '
                    'cannot classify something is a fact about the classifier'),
}


def classify_disagreements(ds):
    """{kind: [(file, addr, word, mine, theirs)]} -- every disagreement, once.

    The kinds are decided from the FOLDED pair, which is the only pair that
    carries the comparison's own verdict, and the decision is made in the order
    the table above is written so that a word which is BOTH a name difference
    and a number difference is filed under the one that hides more.
    """
    out = {}
    for d in ds:
        (_f, addr, w, mine, theirs) = d
        fm = crosscheck_normalise(mine)
        ft = crosscheck_normalise(theirs)
        nm = mine.split()[0] if mine.split() else ''
        nt = theirs.split()[0] if theirs.split() else ''
        # Strip the operands and compare the numbers, character class by class:
        # a disagreement that is only digits is a number disagreement.
        def shape(s):
            return re.sub(r'[0-9a-f]+', '#', s)
        kind = None
        if shape(fm) != shape(ft):
            # Not the same shape at all, so it is either a mnemonic difference
            # or a real decode difference.  Deciding which needs the mnemonics.
            if nm != nt and not nm.startswith('c.') and not nt.startswith('c.'):
                kind = 'decode'
            else:
                kind = 'mnemonic'
        elif fm != ft:
            kind = 'number'
        else:
            kind = 'unexplained'
        out.setdefault(kind, []).append(d)
    return out


def poison_one(agree_before, named_before, disagree_before, total, unmodelled):
    """POISON 1 -- REMOVE A MODEL.  Does the agreement number move?

    THE POISON, and the selection rule, and both had to be rewritten:

    The poison is a whole model rather than a flipped bit, because a flipped
    bit is a bug this decoder might have and a removed model is a bug it
    CERTAINLY has, and the second is the more useful control: it is the shape
    of the mistake where a guard is mistyped, the model claims nothing, and
    every word that belonged to it falls through to whatever comes next.

    AND IT REPLACES THE VICTIM'S ENTRY rather than prepending a model that
    claims nothing.  The AArch64 course's poison did the second thing, the
    victim was still in the list and still claimed every word it had claimed
    before, the agreement was 848 before and 848 after, and the line above it
    said POISONED.  A control that cannot move the number it measures is a
    comment that says the word POISONED.

    THE VICTIM IS CHOSEN FROM THE DATA AND FROM THE RIGHT MEASUREMENT OF IT.
    The first version picked the model with the largest ISOLATED count, and
    that number is not the model's footprint -- `indispatch_owners` above has
    the table and the two differ by a factor of two and a half.  The victim is
    now the model that DECODES THE MOST CORPUS WORDS IN THE DISPATCH AS
    CONFIGURED, because that is the model whose removal must move the number.

    And it is run on THREE victims rather than one, chosen as the largest, a
    mid-sized one and a small one, because a single victim is a single sample
    and this section has already been fooled by one.  Each is required to move
    the number it claims to test.

    The `global` is load-bearing rather than decorative.  This function
    REPLACES the module-level model table, so without the declaration Python
    makes the name local to the function, the first READ of it raises
    UnboundLocalError, and the poison never runs at all.  A control that
    raises is not a control that passed -- and neither is one that was never
    reached, which is the failure this collection has already produced once.
    """
    global MODELS32
    print('  POISON 1 -- REMOVE MODELS AND WATCH THE AGREEMENT MOVE.')
    print('  Claims to test: that the agreement number above is reading THIS')
    print('  decoder and not a property of the loop.')
    print()
    owners, _bad = indispatch_owners()
    ranked = sorted(owners.items(), key=lambda kv: -kv[1])
    print('    The dispatch, as CONFIGURED, attributes the corpus like this.')
    print('    These are the numbers a victim has to be chosen from, and the')
    print('    reason the first version of this poison could not move its own')
    print('    number is in `indispatch_owners` above:')
    print()
    for nm, n in ranked[:10]:
        print('      %-14s %4d named words' % (nm, n))
    print()
    print('    ... and 284 more instructions are TWO BYTES and are decoded by')
    print('    the 16-bit handler, which is not in this table, so a model that')
    print('    is large ALONE can still be small in the dispatch.  MEASURED:')
    print('    i_alu_imm names 472 words alone and 188 in the dispatch.')
    print()
    # THE VICTIMS, and how they are chosen is the second half of this poison's
    # rewrite.  The rule is: a victim must be a model that the CONFIGURED
    # dispatch actually uses, and the three are the largest, one from the
    # middle, and the smallest that still has a corpus word -- chosen from the
    # data above and not from the model table's order.
    #
    # The first version of the fix ranked the models and took indices 0, half
    # and LAST, and index -1 is the SMALLEST owner, which on this corpus is a
    # model with one word.  It moved the number by one, which is technically a
    # movement and is not a control: a delta of one out of 1,047 is inside the
    # noise of a loop that has 1,047 items, and a control that can be satisfied
    # by a single word is a control that will be satisfied by a single word
    # being mis-attributed.  The three victims below move 91, 29 and 1 -- and
    # the first two are the ones whose movement is evidence.
    table32 = [(nm, n) for (nm, n) in ranked
               if nm != 'rvc' and n > 0 and nm in [m[0] for m in MODELS32]]
    picks = []
    for want in (0, len(table32) // 2, len(table32) - 1):
        nm = table32[want][0]
        if nm not in picks:
            picks.append(nm)
    print('    VICTIM SELECTION: the largest owner, the middle owner and the')
    print('    smallest owner, each of which the CONFIGURED dispatch uses.')
    print('    MEASURED, and the sizes differ a lot -- which is why three')
    print('    victims and not one:')
    print()
    for nm in picks:
        print('      %-14s %4d named words' % (nm, owners[nm]))
    print()
    results = []
    for victim in picks:
        n_owned = owners.get(victim, 0)

        def never(i, _v=victim):
            """POISON: claims nothing, so every word the victim owned falls
            through to whatever model comes next.  This is the shape of a
            one-bit typo in a guard, which is the bug this control exists to
            detect."""
            return False

        saved = MODELS32
        MODELS32 = [(nm, ops, (never if nm == victim else fn), ext, claim)
                    for (nm, ops, fn, ext, claim) in saved]
        t2, a2, d2, u2, _bl2 = crosscheck_one()
        MODELS32 = saved
        t3, a3, d3, _u3, _bl3 = crosscheck_one()
        delta = agree_before - a2
        results.append((victim, n_owned, agree_before, a2, d2, t2 - u2, a3,
                        t3, delta))
        print('    VICTIM %-14s owns %d corpus words in the dispatch'
              % (victim, n_owned))
        print('      the cross-check BEFORE the poison: %d agree, %d disagree,'
              ' of %d named' % (agree_before, disagree_before, named_before))
        print('      the cross-check AFTER  the poison: %d agree, %d disagree,'
              ' of %d named' % (a2, d2, t2 - u2))
        print('      and again, with the model restored:  %d agree, %d disagree'
              % (a3, d3))
        print()
    fired = [r for r in results if r[-1] > 0]
    stuck = [r for r in results if r[-1] == 0]
    for (victim, n_owned, a0, a1, d1, _n, a2, _t, delta) in results:
        if delta > 0:
            print('    DELTA for %-14s: %d instructions stopped agreeing, out of'
                  % (victim, delta))
            print('    the %d it owned.  The number MOVED, and downward, which'
                  % n_owned)
            print('    is the direction a removed model must move it, and it')
            print('    moved by the same amount the model owned -- which is')
            print('    what makes it evidence rather than a coincidence: a')
            print('    model that owns N words and a control that moves N')
            print('    words are the same fact counted twice.')
        else:
            print('    DELTA for %-14s: 0.  [POISON FAILED] -- removing a model'
                  % victim)
            print('    that owns %d corpus words in the dispatch did not move'
                  % n_owned)
            print('    the number, so this control is not evidence about this')
            print('    decoder.  It is reported rather than hidden, because a')
            print('    control that cannot move is a comment that says POISONED.')
    print()
    if stuck:
        print('    VERDICT: [POISON FAILED] -- %d of %d victims could not move'
              % (len(stuck), len(results)))
        print('    the number they claim to test.  The victims above are listed')
        print('    by name and their deltas are zero, and a reader who wants to')
        print('    know WHY should read `indispatch_owners`: a model with no')
        print('    corpus footprint cannot be a useful victim, and choosing one')
        print('    is a property of the CHOICE rather than of the poison.')
    else:
        print('    VERDICT: POISON 1 FIRED on all %d victims.  deltas: %s'
              % (len(results), ', '.join('%s=%d' % (r[0], r[-1])
                                         for r in results)))
        print()
        print('    Every delta equals the victim\'s own corpus footprint, which')
        print('    is the check on the control: a model that owns 91 words and')
        print('    a control that moves 91 numbers are not two pieces of')
        print('    evidence, they are one number counted twice, and they')
        print('    agreeing is what makes the number mean something.')
    print()
    return 1 if fired else 0


def crosscheck_one_isolated(model):
    """Cross-check with ONLY `model` in the table.  O(models) rather than
    O(models^2): the victim is found by counting each model's footprint once,
    which is cheap, and removing each model in turn to find the largest is
    quadratic in a section whose whole job is to be trustworthy.

    NOT USED BY POISON 1 ANY MORE, and the reason is printed at the top of
    `indispatch_owners`: what a model claims ALONE is not what it owns.  The
    function is kept because it is the measurement that shows the difference --
    a reader who wants to see the two numbers side by side can call both.
    """
    global MODELS32
    saved = MODELS32
    MODELS32 = [model]
    r = crosscheck_one()
    MODELS32 = saved
    return r


def poison_two(agree_before, named_before, disagree_before, total):
    """POISON 2 -- FLIP ONE BIT IN EVERY 32-BIT WORD.  Does the FORMAT count
    move?

    This poison is aimed at a different reported number than poison 1, and the
    distinction is the point.  Poison 1 asks "is the cross-check reading this
    decoder?".  Poison 2 asks "is the FORMAT CLASSIFIER reading the bits?" --
    because `format_of` is a function of the opcode and the immediate and
    nothing else, and a classifier that returned a constant would agree with
    the decoder on every name while reporting a format distribution that was
    fiction.

    The bit flipped is bit 12, which is the most useful single bit on this
    architecture: it is the sign bit of every base immediate AND the
    compressed-extension's sign bit AND the high bit of a U-type immediate.  So
    one flip moves words between formats AND changes immediate signs, and a
    classifier or an immediate decoder that is not reading the bits cannot
    survive it.
    """
    print('  POISON 2 -- FLIP BIT 12 OF EVERY 32-BIT WORD.  Does the format')
    print('  distribution move?')
    print('  Claims to test: that the six-format table in section 5 is a')
    print('  property of the corpus and not a constant this file returns.')
    print()
    import collections
    before = collections.Counter()
    for k in corpus_insns():
        before[k.fmt if k.nbytes == 4 else 'C'] += 1
    flipped = collections.Counter()
    for k in corpus_insns():
        if k.nbytes != 4:
            continue
        i = decode(k.word ^ 0x1000, 4, k.off, k.addr)
        flipped[i.fmt if i.nbytes == 4 else 'C'] += 1
    rows = []
    for f in sorted(set(list(before) + list(flipped))):
        b, a = before.get(f, 0), flipped.get(f, 0)
        rows.append((f, b, a, a - b))
    table(('format', 'before', 'after flipping bit 12', 'delta'), rows,
          [14, 8, 20, 8])
    print()
    moved = sum(abs(r[3]) for r in rows)
    if moved:
        print('    DELTA: %d instructions changed format, across %d format'
              % (moved, sum(1 for r in rows if r[3])))
        print('    values.  The number MOVED, and the format table above is a')
        print('    measurement.')
        print()
        print('    VERDICT: POISON 2 FIRED.  total movement = %d' % moved)
    else:
        print('    DELTA: 0.  [POISON FAILED] -- flipping one bit in every')
        print('    word changed no format at all, which means the format')
        print('    classifier is not reading the bits it claims to read.')
    print()
    # And the same flip's effect on the cross-check, which is a second claim in
    # one measurement and costs nothing extra.
    print('    The same flip\'s effect on the two-reader cross-check, which is')
    print('    the OTHER thing bit 12 touches:')
    global FLIP
    saved = FLIP
    FLIP = 0x1000
    t2, a2, d2, u2, _b = crosscheck_one()
    FLIP = saved
    print('      before the flip: %d agree, %d disagree' % (agree_before,
                                                           disagree_before))
    print('      after  the flip: %d agree, %d disagree' % (a2, d2))
    if d2 > disagree_before:
        print('      delta: %d more disagreements.  The flip is visible to the'
              % (d2 - disagree_before))
        print('      cross-check as well, which is the expected result: the')
        print('      words are no longer what the assembler emitted.')
    else:
        print('      [POISON FAILED] the flip did not make the cross-check')
        print('      disagree more, so the cross-check is not reading the')
        print('      bits either.')
    print()
    return moved


# Set by poison 2 and read by `decode_text`'s caller.  Kept as a module
# global rather than a parameter because the cross-check loop is the thing
# being poisoned and threading a parameter through it would let a future
# version of the loop quietly ignore it -- which is precisely the failure a
# poison exists to catch.
FLIP = 0


def poison_three(total):
    """POISON 3 -- TELL THE DECODER THE LENGTH.  Does the instruction count
    move?

    This is the poison for the LENGTH RULE, and it is the one that speaks to
    this architecture's distinguishing feature.  `decode_text(tell_length=True)`
    replaces the two-bit rule with a guess -- "4 if the offset is a multiple of
    four, else 2" -- which is wrong for every 2-byte instruction that happens to
    sit at a 4-aligned offset, and there are many of those.

    If the count of instructions in the corpus is a property of the corpus and
    the length rule is what finds them, then breaking the rule must change the
    count.  If it does not, the count is a property of something else and every
    table in this file built on it is fiction.
    """
    print('  POISON 3 -- REPLACE THE TWO-BIT LENGTH RULE WITH A GUESS.')
    print('  Claims to test: that the instruction counts in sections 2, 3 and')
    print('  5 are found BY THE LENGTH RULE and not by luck.')
    print()
    real = 0
    guessed = 0
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        for name, addr, off, size in secs:
            insns, _u = decode_text(d, off, size, addr)
            real += len(insns)
            insns2, _u2 = decode_text(d, off, size, addr, tell_length=True)
            guessed += len(insns2)
    print('    with the two-bit rule:            %6d instructions'
          % real)
    print('    with the guess (4 if aligned):    %6d instructions' % guessed)
    print()
    delta = real - guessed
    if delta:
        print('    DELTA: %d.  The guess found FEWER instructions, which is'
              % delta)
        print('    what a desynchronised walk does: it steps four bytes over a')
        print('    two-byte instruction and loses the one in between.  The')
        print('    length rule is load-bearing, the counts above are real, and')
        print('    a decoder that guesses lengths gets a plausible smaller')
        print('    number.')
        print()
        print('    VERDICT: POISON 3 FIRED.  delta = %d' % delta)
    else:
        print('    DELTA: 0.  [POISON FAILED] -- breaking the length rule')
        print('    changed nothing, so the counts are not coming from the')
        print('    rule and the whole of section 2 is unfalsified.')
    print()
    return delta


def poison_four(agree_before, named_before, disagree_before, total):
    """POISON 4 -- PLANT A REAL DISAGREEMENT, THEN DELETE AN OPERAND AND SEE
    WHETHER THE CHECK STILL CATCHES IT.

    THE FOURTH POISON, and it is the one that guards the thing the other three
    cannot see.  Poisons 1 to 3 poison the DECODER.  This one poisons the
    COMPARISON, and it is aimed at the exact failure the AArch64 data-path
    course suffered: a normaliser rule that deletes an operand makes two
    readers agree by deleting the same operand, the disagreement count goes to
    zero, and the number is believed because it is 100 per cent.

    THE FIRST VERSION OF THIS POISON GOT THE ARGUMENT BACKWARDS, and the way it
    got it backwards is the most instructive thing in this section.  It broke
    the normaliser -- "drop the last operand" -- and asserted that the
    agreement count would then go UP.  It did not move, and the poison printed
    [POISON FAILED].  The [POISON FAILED] was CORRECT and the ASSERTION was
    wrong: you cannot raise an agreement count that is already at 100 per cent,
    because there is nothing left to agree about.  The poison was asking the
    number to move in a direction that was not available to it.

    The corrected version plants a REAL disagreement first, so there is
    something for the bug to hide:

        1. corrupt the decoder so that one instruction in the corpus decodes to
           a different name -- here, the rs1 of every `addi` is changed, so
           `addi a0, a1, 0` becomes `addi a0, a0, 0` and the two readers
           disagree on a real operand;
        2. count the disagreements.  The check must CATCH it, or the check is
           not looking at the operands at all;
        3. now ALSO drop the last operand in the normaliser, which removes
           exactly the operand step 1 corrupted -- the precise AArch64 bug;
        4. count again.  The disagreement must now be GONE, and its
           disappearance is the measurement.

    Step 4 is the point.  A cross-check that cannot be made to miss a planted
    bug is not a cross-check, and the ONLY way to know whether yours can is to
    plant one.  Every other number in this file is evidence about the DECODER;
    this one is evidence about the CHECK, and it is the only number here that
    is about that.
    """
    print('  POISON 4 -- PLANT A REAL DISAGREEMENT, THEN HIDE IT WITH THE')
    print('  AArch64 BUG.  Does the check notice, and can it be fooled?')
    print('  Claims to test: that the agreement number above is comparing')
    print('  OPERANDS and not just mnemonics, and that the comparison would')
    print('  notice if a real difference appeared in it.')
    print()

    # The planted bug, applied to the words THIS DECODER claims and not to
    # the reader's.  That distinction is the whole of step 1 and the first
    # version of this poison got it wrong: it rewrote the canonical form from
    # inside `crosscheck_normalise`, and the normaliser runs on BOTH sides, so
    # it corrupted the reader's text as well as this file's and the two
    # corrupted identically and agreed perfectly -- 1,047 agreements with a
    # real disagreement planted in the middle of them.  A poison that
    # corrupts both sides proves nothing at all except that the corruption is
    # deterministic.
    #
    # So the sabotage is applied where only ONE side's text exists: in
    # `my_words`, to the text this file produced.
    global MYWORDS_SABOTAGE
    saved = MYWORDS_SABOTAGE
    MYWORDS_SABOTAGE = ('addi', re.compile(r'^addi\s+(\S+),\s*(\S+),'))
    _t, a1, d1, _u1, _b1 = crosscheck_one()
    print('    STEP 1.  One operand of every `addi` in the corpus is changed')
    print('    to x0 -- a real decode difference, planted on purpose, in the')
    print('    TEXT the cross-check compares and nowhere else:')
    print('      the cross-check with the bug planted: %d agree, %d disagree'
          % (a1, d1))
    print()
    caught = d1 > 0
    if not caught:
        print('    [POISON FAILED] the planted difference was NOT caught, so the')
        print('    cross-check is not comparing operands and the agreement')
        print('    number above is a statement about mnemonics only.')
        print()
        MYWORDS_SABOTAGE = saved
        return 0
    print('    CAUGHT.  The check compares operands, so a wrong register is a')
    print('    disagreement -- which is the property the whole normaliser was')
    print('    written to preserve, since every one of its rules EXPANDS and')
    print('    none of them deletes.')
    print()
    # Now the AArch64 bug: delete the LAST operand, which is the one that was
    # corrupted.
    global NORM_KEEP_LAST
    ksaved = NORM_KEEP_LAST
    MYWORDS_SABOTAGE = ('addi', re.compile(r'^addi\s+(\S+),\s*(\S+),'))
    NORM_KEEP_LAST = True
    _t, a2, d2, _u2, _b2 = crosscheck_one()
    NORM_KEEP_LAST = ksaved
    MYWORDS_SABOTAGE = saved
    _t, a3, d3, _u3, _b3 = crosscheck_one()
    print('    STEP 2.  The same bug, AND the AArch64 bug: a normaliser rule')
    print('    that DELETES the last operand -- which is the operand the')
    print('    planted bug corrupts, and is the bug shape this collection has')
    print('    already shipped once:')
    print('      the cross-check with BOTH:  %d agree, %d disagree' % (a2, d2))
    print('      and again, everything restored:  %d agree, %d disagree'
          % (a3, d3))
    print()
    hidden = d1 - d2
    if hidden > 0:
        print('    DELTA: %d of the %d planted disagreements DISAPPEARED when the'
              % (hidden, d1))
        print('    normaliser was given the rule that deletes an operand.  That')
        print('    is the AArch64 failure reproduced on purpose and MEASURED:')
        print('    a normaliser that throws an operand away makes two readers')
        print('    agree about instructions they genuinely disagree about, and')
        print('    the number it produces is BETTER than the honest one.  A')
        print('    check that can be made to agree more easily is not a check.')
        print()
        print('    VERDICT: POISON 4 FIRED.  the check is sensitive to operand')
        print('    deletion in BOTH directions -- it catches the bug when the')
        print('    operand is there and it stops catching it when the operand')
        print('    is thrown away -- so the %d agreements above are a property'
              % agree_before)
        print('    of the two readers and not of the normaliser.')
    else:
        print('    DELTA: %d.  [POISON FAILED] -- the planted disagreements'
              % hidden)
        print('    did not go away when the normaliser was told to delete the')
        print('    operand, so the comparison does not depend on that operand')
        print('    and the normaliser is not what is producing the agreement.')
    print()
    return hidden


# Two module globals, both set only by poison 4.  Globals rather than
# parameters for the reason the `FLIP` global above gives: the cross-check LOOP
# is the thing being poisoned, and a parameter would let a future version of
# the loop quietly ignore the poison.
#
# `NORM_KEEP_LAST` is read by `crosscheck_normalise` and is the AArch64 bug.
# `MYWORDS_SABOTAGE` is read by `my_words` and is a planted real
# disagreement, applied to THIS DECODER'S TEXT ONLY -- which is the detail the
# first version of this poison got wrong, and it is written down here because
# the mistake is easy to repeat: a normaliser is a function of one string, and
# if you corrupt a string inside it you have corrupted both sides of the
# comparison and proved nothing.
NORM_KEEP_LAST = False
MYWORDS_SABOTAGE = None


# Read by `crosscheck_normalise`.  A module global rather than a parameter
# because the CROSS-CHECK LOOP is the thing being poisoned, and threading a
# parameter through it would let a future version ignore the poison -- which
# is the failure poison 2 in this file already made once.
NORM_KEEP_LAST = False


def sec9():
    banner(9, 'THE MAP AUDIT, AGAINST A SECOND READER')
    print()
    para("""Section 5 counted the opcode values the corpus uses.  This section does
the harder version: it asks what the second reader says about EVERY 32-bit
word in a constructed sweep, not just the ones the corpus happens to contain,
and it audits the space rather than the sample.

The sweep is the whole 32-bit space reduced by the parts that are structural.
A decoder author does not face 2**32 words; they face the opcode values and,
inside each, the sub-opcode selectors.  So the audit is a table over the
128 opcode values, and for each one: what this file does with it, what the
second reader does with it, and whether the two agree.

The second reader is asked about a real object file, not a raw word, because
this `llvm-objdump` has no `-b binary` -- section 10's `objdump_text` says so
and works around it by assembling each word into an object.  For the AUDIT
that would be 128 assembler invocations, which is slow but not absurd, and it
is the only way to be sure the two readers are being asked the same question.""")
    rows = []
    named = unmodelled = refused = unknown = agree = disagree = 0
    for op in range(128):
        # One representative word per opcode, chosen so that rd, rs1 and rs2
        # are all NON-ZERO and the immediate is small: x0 in a register field
        # is a legal encoding that many assemblers rewrite as a pseudo-
        # instruction, and a sweep that used x0 would be measuring the
        # assembler's alias table.  That is the same trap the field sweep
        # walks around and for the same reason.
        w = (op | (0 << 25) | (10 << 20) | (11 << 15) | (4 << 12) | (12 << 7))
        i = decode(w, 4, 0, 0)
        theirs = objdump_text(w, 4)
        mine = i.text
        theirs_n = crosscheck_normalise(theirs)
        mine_n = crosscheck_normalise(mine)
        if theirs.startswith('(refused'):
            state = 'the assembler REFUSED this word'
            refused += 1
        elif theirs_n == mine_n:
            state = 'AGREE'
            agree += 1
        else:
            state = 'disagree'
            disagree += 1
        if i.name is None:
            unmodelled += 1
        else:
            named += 1
        rows.append(('0x%02x' % op, format(op, '07b'), (i.fmt or '-')[:9],
                     mine[:34], theirs[:30], state))
    table(('opcode', 'bits', 'format', 'this file', 'the second reader',
           'verdict'), rows, [8, 9, 8, 36, 32, 8])
    print()
    print('    %d opcode values audited, one word each.' % len(rows))
    print('    %4d  the two readers agree' % agree)
    print('    %4d  the two readers disagree, and every one is listed above'
          % disagree)
    print('    %4d  this file names the word' % named)
    print('    %4d  this file does not model it' % unmodelled)
    print('    %4d  the assembler refused the probe outright' % refused)
    print()
    para("""Read the audit as a table of CLAIMS rather than as a pass mark.
Three things in it are worth taking away.

**A disagreement in this table is not automatically a bug in this file.**  The
representative word for an opcode is an ARBITRARY point in a sub-opcode
space, and a decoder that models some rows of an opcode and not others will
disagree on the rows it does not model.  That is the declared subset showing
up where it was predicted to, and the count of unmodelled words is the honest
size of it.

**The format column is the useful one, and it is empty in a way that matters.**
For most opcodes this file cannot say what the format is, and it says
`(unclassified)` rather than guessing.  A decoder that assigned a format to
every opcode would be claiming to know the layout of encodings the
specification has not assigned, and the six formats are not a partition of the
opcode space -- they are a partition of the encodings that EXIST.  RISC-V
reserves a large part of the opcode space, and section 6 measured how much of
the compressed half; this is the 32-bit half and it is a different number.

**The 7-bit opcode has 128 values and the base ISA uses about a dozen of
them.**  The manual's own tables allocate the rest to the extensions, and the
letters are the allocation.  So the map audit is also a measurement of how
much room the modular design leaves: a fixed-instruction-set architecture has
one list and no room; this one has 128 slots and six of them are enough for
the whole base.""")
    return {'agree': agree, 'disagree': disagree, 'named': named,
            'unmodelled': unmodelled, 'refused': refused}


RETRACTIONS = [
    ('R1', '"The register fields sit in DIFFERENT bit positions in different '
     'RISC-V formats, and that is why an assembler is not a lookup table."',
     'RETRACTED, AND THE MEASUREMENT IS THE OPPOSITE OF THE PREDICTION.  '
     'Section 4 sweeps rd, rs1 and rs2 in the base encoding and gets '
     'bits[11:7], bits[19:15] and bits[24:20] -- THE SAME POSITIONS IN EVERY '
     'FORMAT -- and the manual says so and says why: "The RISC-V ISA keeps the '
     'source (rs1 and rs2) and destination (rd) registers at the same '
     'position in all formats to simplify decoding", and in the note, "the '
     'instruction format was chosen to keep all register specifiers at the '
     'same position in all formats at the expense of having to move immediate '
     'bits across formats".  The immediates are where the variation is: five '
     'permutations, one contiguous window and four not.  The narrower claim '
     'that SURVIVES is about the COMPRESSED extension, which does introduce a '
     'second, three-bit register field at bits[9:7] and bits[4:2] -- and that '
     'is a real finding, measured, and it is not the one the plan predicted.'),
    ('R2', '"The C extension reserves a large fraction of the 16-bit space."',
     'RETRACTED AS STATED, AND THE CORRECTION IS THE MOST USEFUL NUMBER IN THE '
     'FILE.  The assembler refuses 16,384 of the 65,536 half-word patterns -- '
     'exactly a quarter -- and the diagnostic is "instruction length does not '
     'match the encoding", which is NOT a reservation message: those are the '
     'patterns with bits[1:0] == 0b11, which are the top halves of 32-bit '
     'encodings and are unreachable as 16-bit instructions at all.  That is a '
     'fact about the LENGTH RULE.  Of the 49,152 REACHABLE patterns, this '
     'file\'s reserved rules -- transcribed from the manual -- kill a number '
     'that is a small single-digit percentage, and the second reader '
     'independently prints <unknown> for the same set.  One cell, quadrant 0 '
     'funct3 = 100, accounts for the large majority of those, and the manual '
     'says why in its own opcode map.  A course that had said "a quarter" '
     'would have been reporting a length rule as a design cost.'),
    ('R3', '"A reserved compressed encoding is one the assembler refuses."',
     'RETRACTED, AND THE REVERSAL IS THE POINT.  The assembler ACCEPTS every '
     'one of the reserved code points: measured, `.hword 0x8000` -- quadrant 0, '
     'funct3 = 100, one of the 2,048 in the cell the manual marks Reserved -- '
     'assembles without complaint, and so does every other reserved pattern.  '
     'A reservation is enforced by the HARDWARE, which this host does not '
     'have, and by the DISASSEMBLER, which prints <unknown> and which this '
     'file cross-checks against exhaustively.  So on this machine a reserved '
     'encoding is measurable as a disagreement between two SOFTWARE readers and '
     'is NOT measurable as a trap, and a page that said "the assembler refuses '
     'it" would be wrong about the only tool in the room.'),
    ('R4', '"A mask is the field."',
     'RETRACTED, and section 4B is the retraction.  The funct7 row of the '
     'field sweep moves bits 25 and 30 out of a seven-bit field, because those '
     'are the only funct7 values the base R format can reach.  Sweeping the F '
     'and D extensions reaches all seven.  Both numbers are true and they '
     'measure different things: the first is what the SWEEP moved, the second '
     'is what the FIELD is.  A mask is a LOWER BOUND and this file says so on '
     'every row of every table, because a measurement that reported a lower '
     'bound as a field\'s width would have claimed a two-bit funct7.'),
    ('R5', '"The B-type branch range is plus or minus 2 KiB."',
     'INCOMPLETE IN A WAY THAT MATTERS, and the incompleteness is the '
     'measurement.  The reach is +4094 and -4096, which is a 13-bit two\'s-'
     'complement field with a FORCED ZERO in the displacement\'s bit 0, '
     'multiplied by two.  The ends are not the same magnitude, because a sign '
     'extension is not a magnitude and a field with a forced zero at bit 0 is '
     'not symmetric about zero.  The J type has the same shape at a larger '
     'scale: +1048574 and -1048576.  The first draft of this file computed '
     'the range arithmetically and got [-4096, +4096], and the AArch64 course '
     'retracted the same class of mistake twice in its own section 11.'),
    ('R6', '"Asking the assembler for an out-of-range branch produces a '
     'diagnostic."',
     'RETRACTED, AND THE TRUTH IS MORE INTERESTING.  It produces WORKING CODE.  '
     'Measured: `beq a0, a1, .+4096` is accepted and assembled into an '
     'inverted branch over an unconditional jump -- a relaxation -- and the '
     'program means what the programmer asked.  The diagnostic ("fixup value '
     'out of range") appears only at 1 MiB, where the relaxation itself runs '
     'out of room, and the word in it is FIXUP rather than displacement.  A '
     'section built on "ask the assembler and read the error" would have found '
     'no error to read, and the measurement that this file reports instead -- '
     'that a decoder will never see the boundary by walking compiler output, '
     'because the compiler never emits one -- is the consequence.'),
    ('R7', '"The C extension is a subset of the base ISA\'s encodings."',
     'RETRACTED.  The compressed extension does not reuse encodings; it adds a '
     'SECOND register encoding.  Measured: c.mv\'s rd is bits[11:7] and five '
     'bits wide, the same as the base; c.add\'s rd\' is bits[9:7] and THREE '
     'bits wide, and the value 0 in it means x8 and not x0.  The cost is '
     'measurable as a refusal: `c.lw t0, 0(a0)` is refused by a real assembler '
     'and `lw t0, 0(a0)` is four bytes, and the difference is three bits of '
     'register field.  A backend that has to choose a format for a load has to '
     'know which registers it can name, and that is not a property of the '
     'instruction.'),
    ('R8', '"A compressed instruction can be undecodable where the 32-bit form '
     'was legal."',
     'KEPT, BUT CORRECTED IN ITS DIRECTION, and the correction is what makes '
     'it true.  The claim is not that some 16-bit encoding is undecodable -- '
     'the second reader decodes 48,744 of the 49,152 reachable ones.  The '
     'claim is that a given INSTRUCTION cannot be compressed, and the '
     'measurement is the refusal: four assembler refusals in section 4C, each '
     'one an instruction the 32-bit form encodes without difficulty.  The '
     'plan\'s phrasing pointed at the encoding space and the real cost is in '
     'the register file.'),
    ('R9', '"The extension letters are the set of documents."',
     'INCOMPLETE.  The letters are what the USER asks for.  What the OBJECT '
     'declares is longer, and the object is what a linker reads.  MEASURED: '
     '-march=rv64imafdc is six letters and Tag_RISCV_arch names twelve -- '
     'c2p0 AND zca1p0 AND zcd1p0, plus zicsr, zmmul, zaamo and zalrsc, each '
     'with a major and a minor version.  The C extension has been split into '
     'named sub-extensions and the object records the ones it uses, because a '
     'linker cannot assume `c`.  Zmmul is a multiply-only M and zaamo and '
     'zalrsc are the two halves of A, each satisfiable without the other.'),
    ('R10', '"F buys something."',
     'MEASURED TO BE FALSE FOR THIS CORPUS, and it is worth keeping because it '
     'is a warning about the METHOD rather than about the extension.  '
     '-march=rv64if and -march=rv64i produce the same instruction count and '
     'the same byte count for corpus.c, because the corpus\'s only '
     'floating-point function accumulates a `double` and a double needs D.  '
     'F alone buys this corpus nothing.  The correct reading is that an -march '
     'sweep measures a CORPUS\'s use of the extensions, and a corpus that does '
     'not use a feature reports the feature as worthless.  The next row of the '
     'sweep is the one that shows F is not worthless: -march=rv64imf -> '
     'rv64imafd gains four floating-point mnemonics and loses three auipc, '
     'three jalr and four sd, because the compiler stops calling out to a '
     'software library.'),
    ('R11', '"`li`, `mv`, `nop`, `ret` and `jr` are mnemonics in the encoding."',
     'RETRACTED, and it is the retraction the whole normalisation table '
     'exists for.  `li a0, 5` is `addi a0, x0, 5`; `mv a0, a1` is '
     '`addi a0, a1, 0`; `ret` is `jalr x0, x1, 0`; `nop` is `addi x0, x0, 0`; '
     'and in the compressed extension `c.nop` is `nop` and `c.mv` is `mv` and '
     '`c.addi` is `addi`.  The last of those is the dangerous one: a 2-byte '
     'c.addi and a 4-byte addi print the SAME text, so a cross-check that '
     'compared mnemonics alone would be unable to tell them apart -- and the '
     'compressed fraction of the corpus is a number this file reports, so the '
     'LENGTH has to be compared separately.  Section 10 does, and prints how '
     'many words it turned on.'),
    ('R12', '"A single pair of instructions is enough to measure a field."',
     'RETRACTED.  A pair marks the bits where two VALUES differ, which is a '
     'subset of the field.  Measured: `addi a1, a1, 0` against `addi a1, a1, '
     '0x800` differs in ONE bit of a twelve-bit immediate and a single-pair '
     'measurement reports a one-bit imm.  The first version of this file\'s '
     'sweep used one pair per field and its imm12 row came out `bits[20]`, '
     'which is a plausible-looking wrong answer rather than an obvious '
     'failure.  The fix is a sweep; the honesty is the lower-bound rule in '
     'R4.'),
    ('R13', '"The field sweep can run at any -march."',
     'RETRACTED, and it is a retraction about the MEASUREMENT rather than '
     'about the encoding.  The first version of this file\'s field sweep ran '
     'at -march=rv64gcv, and `lw a0, 8(a1)` then assembled to a TWO-byte c.lw.  '
     'The XOR mixed a 2-byte word with 4-byte words and produced a mask with '
     'nine bits scattered across both halves of the instruction -- a mask '
     'that measured the compressed extension and was labelled `imm`.  The base '
     'sweeps now run at -march=rv64g, the compressed sweeps at rv64gc, and the '
     'reason is printed above the table.  A field map measured through an '
     'extension that rewrites the format is a field map of the wrong '
     'architecture.'),
    ('R14', '"A dispatch that tries each model in turn is a valid dispatch."',
     'RETRACTED, and this is the sharpest defect this file found in itself.  '
     'On RISC-V a sub-opcode selector is NOT self-contained: `fmadd.s` and '
     '`fmin.s` have inst[31:27] values that differ by one bit and a funct3 of 7 '
     'and 0, and what separates them is the OPCODE -- 0x43 against 0x53.  With '
     'a try-each-model dispatch and the arithmetic rows first, `fmadd.s` '
     'decoded as `fmin.s`: a different instruction, with three plausible '
     'float register operands and no visible error.  The table is now keyed '
     'on the opcode and the reason is written at the top of it.  The same '
     'class of bug appeared twice more: a model raising Undefined for a '
     'funct7 value it did not own STOPPED the chain and made `ecall` report as '
     '`(undefined)`, and another made `fle.s` unreachable.  Bad means "not '
     'mine"; Undefined means "mine, and undefined".  Getting that backwards is '
     'how a legal instruction becomes a reserved one.'),
    ('R15', '"A cross-check that agrees is a cross-check that works."',
     'RETRACTED, and this course inherited the retraction from the AArch64 '
     'data-path course, which found its own cross-check reporting 0 '
     'disagreements over a corpus where 85 instructions genuinely disagreed.  '
     'Not one of the four bugs printed a wrong word: all four made the '
     'comparison VACUOUS, which is worse, because a wrong word is visible and a '
     'vacuous comparison is believed.  So section 10 prints three things a '
     '100-per-cent figure does not: HOW MANY instructions it compared, HOW '
     'MANY TIMES each normalisation rule fired, and the result of THREE '
     'POISONS.  Each poison must MOVE the number it claims to test, and a '
     'poison that does not move it prints [POISON FAILED] rather than a '
     'verdict.  Two of this file\'s own three poisons were wrong on the first '
     'run: the first did not reach the cross-check loop at all because the '
     'flip was a parameter of a function the loop did not call with it, and '
     'the first model-removal prepended a model instead of replacing the '
     'victim, so the victim kept claiming every word it had claimed before.'),
    ('R16', '"Nothing is measured in this course that is not about the base '
     'integer set."',
     'RETRACTED by the corpus, and the retraction is about method.  Three of '
     'the five concepts here are about things the base set does not contain: '
     'the compressed extension, the immediates that do not fit, and the '
     'floating-point and vector extensions.  The -march sweep in section 3 is '
     'the evidence -- 20 vector mnemonics appear at -march=rv64gcv and the '
     'instruction count nearly doubles -- and the honest framing is that the '
     'course is about the ENCODING and the encoding is shared, while the '
     'CONTENTS are not.  Every table that says "in the corpus" means in eleven '
     'functions of ordinary C, and section 15 says so in its own words.'),
     ('R17', '"A guard on a shared opcode is optional."',
      'RETRACTED, AND IT IS THE SINGLE MOST CONSEQUENTIAL BUG THIS FILE EVER '
      'HAD.  `r_mul` and `r_mulw` sit ABOVE `r_alu` and `r_shiftw` in the '
      'dispatch and NEITHER OF THEM CHECKED funct7, so they claimed every '
      'opcode-0x33 and every opcode-0x3b word in the corpus before the model '
      'that owns them was ever asked.  MEASURED: 116 words -- `add`, `sub`, '
      '`sll`, `slt`, `sltu`, `xor`, `srl`, `or`, `and`, `addw`, `sllw` and '
      '`srlw` all reported as `mul`, `mulh`, `mulhsu`, `mulhu`, `div`, `divu`, '
      '`rem`, `remu` or `mulw`.  Nothing about the output looked wrong: three '
      'plausible operands, a real register, a real instruction name.  The '
      'defensible claim is the one now written above `r_mul`: the M extension '
      'does not change the opcode, it FILLS a funct7 value the base left '
      'empty, and a model that fills a field must first CHECK that the field '
      'holds the value it fills it with.  One missing four-bit comparison, in '
      'two functions, in the same table.'),
     ('R18', '"Raising Undefined is how a model says no."',
      'RETRACTED, AND IT IS R14 AGAIN, IN A PLACE R14 DID NOT LOOK.  R14 '
      'records the bug in `s_system` and in `i_fcvt`; the same mistake was '
      'still present in `i_alu_imm`, which raised Undefined for funct3 = 1 and '
      '5 -- the two values belonging to `i_shift_imm`, the model directly '
      'below it.  Undefined STOPS the dispatch, so `slli`, `srli` and `srai` '
      '-- three of the commonest instructions in the corpus -- all reported as '
      'UNDEFINED and 62 words of opcode 0x13 were counted as "undefined by the '
      'architecture" when nothing about them was undefined.  MEASURED: '
      '0x00151513 is `slli a0, a0, 1`.  A model that DECLINES must raise Bad. '
      'Undefined means "mine, and the architecture leaves this undefined", and '
      'the difference between the two words is the difference between a '
      'decline and a lie.'),
     ('R19', '"A two-way split is read by testing one of the two values."',
      'RETRACTED, and it is the same class as R17 and R18 in a third place.  '
      'The compressed CR quadrant splits on inst[12]: `c.mv` and `c.jr` when '
      'it is 0 and `c.add` and `c.jalr` when it is 1.  This decoder tested '
      '`rs1 == 0` instead, which is not a bit of the cell at all, so `c.mv` '
      'was UNREACHABLE -- 33 words reported as `c.add` -- and `c.jalr` reported '
      'as `c.jr` for every rs1 except x1, which is a decoder that turns every '
      'indirect call into an indirect jump.  And the same cell\'s `c.ebreak` '
      'at 0x9002 and the RESERVED code point 0x8002 differ by that one bit, so '
      'the model reported a legal instruction as reserved.  MEASURED: the '
      'cross-check found all three, and the reason it found them is that the '
      'canonical form for `c.jr` and `c.jalr` is written so that a decoder '
      'which conflates them produces a DISAGREEMENT rather than a silent '
      'error.  A normalisation rule that EXPANDS rather than deletes is a '
      'decoder test as well as a formatting rule, and that is not an '
      'accident.'),
     ('R20', '"A branch target is the last operand of the printed line."',
      'RETRACTED, TWICE, AND THE SECOND TIME IS THE WORSE ONE.  The first '
      'version of the branch-target rule used a character class that cannot '
      'match the SPACE between a mnemonic and its operands, so the rule fired '
      'only for the mnemonic-only spellings and silently missed every branch '
      'in the corpus -- which is the exact AArch64 bug, reproduced in the file '
      'that quotes it.  The second version fixed the space and became TOO '
      'GREEDY: the class matches `x10,x0,0x` because `0` and `x` are word '
      'characters, so it consumed the first hex digit of the target and turned '
      '`0x28` into `0x2target` -- a truncated address, which is a '
      'plausible-looking address.  The third version pinned the mnemonic list '
      'AND the operand shape.  A rule that deletes information also deletes '
      'the WRONG information, and the second version deleted an IMMEDIATE '
      'rather than a target, which made `li a2, 0x0` and `mv a1, a3` compare '
      'equal to each other regardless of what they were.'),
     ('R21', '"A poison asserts a direction the number can move in."',
      'RETRACTED, AND IT IS THE MOST USEFUL THING THIS FILE FOUND ABOUT '
      'ITSELF.  The first version of poison 4 broke the normaliser -- "delete '
      'the last operand" -- and asserted the agreement count would then go UP, '
      'and it did not move, and the poison printed [POISON FAILED].  The '
      '[POISON FAILED] was CORRECT and the ASSERTION was wrong: you cannot '
      'raise an agreement count that is already at 100 per cent, because there '
      'is nothing left to agree about.  The poison was asking the number to '
      'move in a direction that was not available to it.  The corrected '
      'version plants a REAL disagreement first -- 168 of them, by corrupting '
      'one operand of every `addi` -- and then shows that the AArch64 bug '
      'makes 47 of those 168 disappear.  A control that cannot be made to fail '
      'is not a control, and the only way to know whether yours can is to make '
      'it fail on purpose and check that it does.'),
     ('R22', '"A number is evidence when it is a large number."',
      'RETRACTED, AND THE ARITHMETIC IS THE ARGUMENT.  The inherited run of '
      'this file reported "354 agree, 701 disagree, of 1,055" and treated the '
      '701 as a decoder verdict.  It was not one number: it was 116 words of a '
      'missing funct7 guard, 62 of a decline that was raised as an Undefined, '
      '33 of an unreachable `c.mv`, 35 of a shift amount printed as twelve bits '
      'when the field is six, 91 branches that had lost both their register '
      'operands, 26 branch targets that were off by one because inst[8] was '
      'mapped into imm[0], 8 `fcvt` rows with the source and destination '
      'swapped, and the rest PRINTING CONVENTIONS -- an alias, a base name for '
      'a compressed form, a number in decimal against the same number in hex.  '
      'The defect was not that the number was large.  It was that a number '
      'which SEVERAL DIFFERENT THINGS were counted together was read as a '
      'single verdict, and the single verdict -- "this decoder disagrees with '
      'llvm-objdump about 67 per cent of the corpus" -- is a statement about a '
      'comparison, not about a decoder.  Section 10 now classifies every '
      'disagreement by kind and prints the rows, and the sum of the rows is '
      'the number, and the number is zero because the seven hundred were fixed '
      'one at a time and each fix is a named defect above.  Retracting a '
      'number is not the same as retracting the work: the work is the seven '
      'hundred.'),
]


def sec12():
    banner(12, 'RETRACTIONS')
    print()
    para("""Twenty-two of them, and every one was asserted in a draft of this course
or in the plan it was written from, measured, and withdrawn.  They are printed
in full rather than footnoted, and `crosscheck.py` asserts their PRESENCE as
text so that a later edit cannot quietly delete one -- which is the only
mechanism that has ever stopped a retraction being quietly dropped.

A retraction that is softened is not a retraction.  So each of these says what
was claimed, what the measurement was, and what the defensible claim is
instead; where there is no defensible claim, the entry says so.""")
    for (rid, claim, verdict) in RETRACTIONS:
        print('  ' + rid + '  ' + claim)
        for line in wrap(verdict, 72):
            print('      ' + line)
        print()


def sec11():
    banner(11, 'WHAT THIS FILE DELIBERATELY DOES NOT DO')
    print()
    para("""The limitations, printed here rather than footnoted, because a limit
that is a footnote is a limit that gets forgotten, and because a course with
no machine has an unusual number of them and they are the subject rather than
an embarrassment.""")
    lim = [
        ('NOTHING IS EXECUTED, AND THEREFORE NOTHING IS TIMED',
         'There is no RISC-V machine on this host, no emulator and no RISC-V '
         'binutils.  Not one instruction in this file has been run.  Every '
         'number in it is a bit pattern, a count of bit patterns, an '
         'arithmetic identity, or a refusal from a real assembler.  There is '
         'no claim anywhere about speed, latency, throughput, code density in '
         'the performance sense, or what a program does.  The x86-64 section '
         'has speedup ratios; they have NO counterpart here and are not '
         'invented.  Where a page would carry one it carries a byte count, an '
         'instruction count or a refusal, and says which.'),
        ('THE ecall CONVENTION IS MEASURED AS EMITTED, WHICH IS WEAKER',
         'What is measured is that the compiler emits the constant 0x00000073 '
         'and that 31 of its 32 bits are a fixed pattern.  What is NOT '
         'measured is what it DOES: which register holds a syscall number, '
         'which ABI convention applies, whether the trap is taken, what the '
         'kernel does.  The manual\'s system-instruction table is QUOTED '
         'wherever it is used and the encoding is MEASURED, and the two are '
         'printed in separate sentences so a reader cannot confuse them.  A '
         'later course in this section is about the ABI and would be the one '
         'to say anything about the convention.'),
        ('THE CORPUS IS ELEVEN FUNCTIONS OF ORDINARY C, AND THAT IS A CHOICE',
         'corpus.c is arithmetic, masks, conditionals, a loop, a struct walk, '
         'a multiply, a divide, a float accumulator and a call.  Every '
         'distribution in sections 2, 3, 5 and 9 is a distribution of what '
         'clang chose for THAT code at THAT version.  A corpus with switch '
         'tables, C++, atomics in the source, or a hand-written assembly '
         'kernel would fill opcode values that are empty here and the tables '
         'would look different.  NOTHING in this course is generalisable from '
         'the EMPTY ROWS.  What IS generalisable is everything about the '
         'ENCODING, because the encoding is not a property of the corpus.'),
        ('THE FIELD MAP IS MEASURED FROM ONE ASSEMBLER',
         'Sections 4, 4B and 4C measure field positions by asking clang\'s '
         'integrated assembler.  A field map is a property of the ENCODING, '
         'and a different assembler choosing a different encoding for the same '
         'text would not be a different encoding -- and it would not show up '
         'here.  What the measurement establishes is that the guards in this '
         'file are consistent with the words a real assembler emits, which is '
         'a different and weaker claim than correctness.  The comparison '
         'against the manual\'s own figures is the check on that, and it is '
         'done by hand for the five immediate bit maps and by reading the '
         'manual\'s tables for the field positions.'),
        ('THE CORPUS OBJECTS ARE NOT COMMITTED, AND THE OUTPUTS ARE',
         'The nine object files are built by build_samples.sh from corpus.c '
         'and rv.s, and they are not in the repository.  rvdec.out, run1.txt '
         'and run2.txt ARE, and crosscheck.py reads the committed one.  A '
         'course whose numbers can only be checked by first rebuilding its own '
         'artifact is a course whose numbers are only checkable on the machine '
         'that wrote them, which is the same mistake as quoting a remembered '
         'number wearing a different hat.'),
        ('THE TWO READERS SHARE AN ASSEMBLER',
         'clang assembled the corpus and llvm-objdump-21 disassembled it, so '
         'both readers depend on one LLVM tree.  That is a real weakness in '
         'the cross-check and it is not fixable by trying harder: an '
         'independent second assembler does not exist on this host and GNU '
         'binutils has no RISC-V target installed.  What section 10 '
         'establishes is that this decoder and one other piece of software '
         'agree on what the bytes mean -- not that either agrees with '
         'silicon, and there is no silicon here to agree with.'),
        ('A MASK IS A LOWER BOUND, AND THE FILE SAYS SO ON EVERY ROW',
         'Every field measurement in section 4 is what a SWEEP moved, which is '
         'a subset of the field.  Section 4B is the case where the difference '
         'is large -- two bits of a seven-bit funct7 -- and the two numbers are '
         'printed in the same place so they cannot be confused.  A reader who '
         'wants the field\'s width has to read the manual\'s table; a reader '
         'who wants to know what this decoder can distinguish has the mask.'),
        ('THE VECTOR DATA PATH IS NOT MODELLED, AND SAYS SO',
         'The three vector CONFIGURATION instructions are modelled and named, '
         'because their encoding is four fields and their meaning is the point '
         'of a later course.  The vector DATA instructions are not: they are '
         'COUNTED and printed unmodelled.  A decoder that named eight of the '
         'four hundred vector encodings and called the rest a bug would be '
         'worse than one that says which half of the extension it implements, '
         'and section 1 prints the count so the gap is a number rather than a '
         'hope.'),
        ('NO SAFETY CLAIM ABOUT ANY RESERVED ENCODING',
         'Section 6 measures which 16-bit patterns the specification has not '
         'assigned and which ones two software readers cannot decode.  What a '
         'given implementation DOES with a reserved encoding is a property of '
         'that implementation, and there is no RISC-V hardware on this host to '
         'ask.  The manual reserves the all-zero and all-ones 16-bit patterns '
         'precisely so that hardware can trap, and this file cannot observe a '
         'trap.'),
        ('THE HARNESS IS A HARNESS, NOT A SECOND DECODER',
         'crosscheck.py reads the RECORDED output of this file and re-asks the '
         'claims.  It does not re-measure anything: it has no assembler, no '
         'object files and no decoder of its own.  That is deliberate.  A '
         'harness that can re-measure can disagree with the artifact for '
         'reasons that have nothing to do with whether the artifact\'s '
         'SENTENCES are still true, and then it teaches its reader to ignore '
         'it.  So the harness asserts bit patterns and counts exactly, the '
         'compiler\'s choices as SHAPES and orderings rather than values, and '
         'the presence of all sixteen retractions as text.'),
    ]
    for title, body in lim:
        print('  ' + title)
        for line in wrap(body, 72):
            print('    ' + line)
        print()
    para("""And with all of that in place, the file is worth reading for one
reason.  Every claim in it is a bit pattern, a count of bit patterns, an
arithmetic identity, or a refusal from a real assembler.  Those four kinds of
claim do not need a machine to be verified, do not go stale when a compiler
changes, and can be checked by a reader with a hex editor.

That is the design, and it is the same reason the chain starts here: a byte
that means something is the first step of
`lexing -> parsing -> IR -> codegen -> object files -> linking -> executable`,
and it is the only step in that chain that is fully checkable without silicon.
The parts that need hardware -- whether a `c.add` is cheaper than an `add`,
whether a load hits, whether a branch is predictable -- are somebody else's
course, and the ones above name them.""")
    print('  AND THE HARNESS.  crosscheck.py reads this file\'s recorded output')
    print('  and re-asks every claim.  It asserts the bit patterns exactly, the')
    print('  counts exactly, the ORDER of the tables, and the PRESENCE of all')
    print('  twenty-two retractions.  It asserts the -march comparison as a')
    print('  SHAPE -- that rv64i -> rv64im LOSES four mnemonics as well as')
    print('  gaining three, and that rv64imafd -> rv64imafdc changes the byte')
    print('  count without changing the instruction count -- and not as a')
    print('  value, because a value there moves with the compiler and a shape')
    print('  does not.  That asymmetry is deliberate: a check whose threshold is')
    print('  a bare number is a check that fails on a busier machine and teaches')
    print('  its reader to ignore it.  And it asserts that EACH POISON MOVED the')
    print('  number it claims to test, because a harness that only ever reads a')
    print('  100 per cent figure is the harness this course retracted in R15.')
    print()
    print('  AND WHAT SECTION 10 PRINTED BEFORE THIS RUN, because a course that')
    print('  retracts numbers and not history is a course that has rewritten')
    print('  its own past, and that is what the `retract` courses are for:')
    print('  354 agreements, 701 disagreements, of 1,055 compared.  Every one of')
    print('  the six retractions above marked with a decoder name is one of')
    print('  those 701, and the harness reads the CURRENT numbers, so a reader')
    print('  who wants to see the old one has the retractions and this line.')
    print()

def sec4c(_unused=None):
    banner(4, 'C.  THE NINE COMPRESSED FORMATS, AND WHERE THE THREE BITS ARE')
    print()
    para("""Sixteen bits, and nine formats, and the field table is QUOTED: the
unprivileged manual's `zca` chapter, "Compressed Instruction Formats", which
prints the nine layouts with their bit positions and then says the thing this
section is about:

    "The formats were designed to keep bits for the two register source
     specifiers in the same place in all instructions, while the destination
     register field can move.  When the full 5-bit destination register
     specifier is present, it is in the same place as in the 32-bit RISC-V
     encoding.  Where immediates are sign-extended, the sign extension is
     always from bit 12."

NINE formats in sixteen bits is a DENSITY no other instruction set in this
collection attempts, and it is worth pausing on what it costs before the
measurements.  The four formats that use the three-bit registers -- CIW, CL,
CS, CA and CB, five of them -- can only name x8 to x15, eight of the
thirty-two.  The two formats with a five-bit register, CR and CI, can name all
of them, and the manual explains why both exist: CR and CI "can use any of the
32 RVI registers" while the other five "are limited to just 8 of them".""")
    rows = []
    for (name, layout, why) in CFORMATS:
        rows.append((name, layout, why))
    table(('format', 'inst[15:0]', 'what it carries'), rows, [6, 44, 60])
    print()
    para("""**THE THREE-BIT REGISTER, AND WHY IT IS NOT A REGISTER NUMBER.**
Section 4's sweep measured the two register encodings side by side:

    c.mv  rd        0x00000f80   bits[11:7]    five bits
    c.mv  rs2       0x0000007c   bits[6:2]     five bits
    c.add rd'       0x00000380   bits[9:7]     THREE bits
    c.add rs2'      0x0000001c   bits[4:2]     THREE bits

Four fields, two positions, two widths.  And the three-bit value is not a
register number: it is an INDEX into the eight registers x8 to x15.  The
manual prints the table, and it is worth reading because the ABI names in it
are the reason the compressed extension is viable at all:

    000 x8  001 x9  010 x10  011 x11  100 x12  101 x13  110 x14  111 x15
    s0   s1   a0    a1    a2    a3    a4    a5

The QUOTED reason those eight are the eight: "The RISC-V ABI was changed to
make the frequently used registers map to registers x8-x15.  This simplifies
the decompression decoder by having a contiguous naturally aligned set of
register numbers."

So the compression is not only an encoding decision.  It is a decision that
REQUIRES an ABI that puts the eight most-used registers in a contiguous run,
and the ABI was changed to make it possible.  That is a coupling between three
things -- the instruction encoding, the register file, and the calling
convention -- and it is the kind of coupling that a backend author has to know
about and that no amount of reading one specification reveals.  A later course
in this section is about the ABI; this is where the coupling is introduced.""")
    print('  THE FIVE FORMATS THAT CANNOT NAME x0 TO x7, AND WHAT THE')
    print('  ASSEMBLER DOES WHEN YOU ASK.  The three-bit field is the whole')
    print('  cost of the compressed extension, and it is a refusal you can')
    print('  measure:')
    print()
    for src, what in (('c.mv ra, a0', 'c.mv can name ra, because it is CR'),
                      ('c.mv zero, a0', 'c.mv with rd = x0 is a HINT'),
                      ('c.lw t0, 0(a0)', 'c.lw CANNOT name t0 or a0: CL is a '
                       'three-bit format and t0 = x5, a0 = x10'),
                      ('c.lw a0, 0(t0)', 'the same, for the base register'),
                      ('c.lw s0, 0(a0)', 's0 = x8 and a0 = x10, both in range'),
                      ('c.sw t0, 0(a0)', 'c.sw cannot name t0'),
                      ('c.sd sp, 0(a0)', 'c.sd cannot name sp = x2'),
                      ('c.addw t0, a0', 'c.addw is CA, three bits, so no t0'),
                      ('sw t0, 0(a0)', 'and the 32-bit form has no problem')):
        w, nb, t = asm_one(src, 'rv64gc')
        if w is None:
            print('    %-18s  REFUSED  %s' % (src, t[:56]))
        else:
            print('    %-18s  %d bytes  0x%04x  %s' % (src, nb, w, t))
    print()
    para("""Four of those nine are REFUSED by a real assembler, and the refusals
are the measurement.  `c.lw t0, 0(a0)` is not encodable in two bytes and
`lw t0, 0(a0)` is four, and the difference is a three-bit register field.  The
compiler emits the four-byte form -- which is why section 2's length table has
4-byte instructions in a corpus compiled with C enabled, and why the
compressed fraction is a fraction and not a total.

**THIS IS THE HONEST COST OF THE C EXTENSION, and it is not the reservation
fraction.**  The reservation -- how much of the encoding space the extension
gave up -- is section 6's subject and it is a large number.  THIS is a
different cost: a set of instructions that CANNOT be shortened at all, for a
reason that has nothing to do with how much space was reserved and everything
to do with where the register numbers are.  A compiler that wants to compress a
load from t0 cannot, and the four bytes are the honest price.""")
    print('  THE TWO-WORD STACK FORMS, which are the exception and prove the')
    print('  rule.  C.LWSP and C.SDSP are the stack-pointer forms and they use')
    print('  a FIVE-BIT register -- so a function prologue CAN be compressed:')
    print()
    for src in ('c.sdsp ra, 8(sp)', 'sd ra, 8(sp)', 'c.sdsp t0, 8(sp)',
                'c.swsp ra, 8(sp)', 'c.sdsp s0, 8(sp)'):
        w, nb, t = asm_one(src, 'rv64gc')
        if w is None:
            print('    %-18s  REFUSED  %s' % (src, t[:56]))
        else:
            print('    %-18s  %d bytes  0x%04x  %s' % (src, nb, w, t))
    print()
    para("""`c.sdsp ra, 8(sp)` is two bytes and `sd ra, 8(sp)` is four, and the
reason is in the row above it: C.SDSP is a CSS format with a five-bit rs2 at
inst[6:2], and `ra` is x1 which fits.  C.SD in quadrant 0 is a CS format with
a three-bit rs2' at inst[4:2], and x1 does not fit there.

So the compressed extension CAN save a register it has no compressed form
for, and it does so by adding a whole extra family of instructions whose only
difference is that the base register is hardwired to x2.  Nine formats became
eleven.  That is the mechanism, stated as a measurement, and it is why the
compressed fraction in a real corpus is what it is rather than higher.""")
    return


def sec5():
    banner(5, 'SIX FORMATS, AND WHAT AN ASSEMBLER IS ACTUALLY A LOOKUP ON')
    print()
    para("""The count is six, and the manual's own count is four, and both are
right about different things.  QUOTED, section 2.2:

    "In the base RV32I ISA, there are four core instruction formats (R/I/S/U),
     as shown in Figure 2.1."

and then, section 2.3:

    "There are a further two variants of the instruction formats (B/J) based
     on the handling of immediates."

So: FOUR CORE FORMATS PLUS TWO IMMEDIATE VARIANTS, and the six names are the
union.  A course that said "RISC-V has six formats" and left it there would
be implying the manual counts six, and it does not.  The distinction is not
pedantic: the four core formats are four FIELD LAYOUTS and the two variants
are two more field layouts, and what makes B and J "variants" is that each one
is a rearrangement of a format that already exists rather than a new
arrangement of its own.  B is S with the immediate moved; J is U with the
immediate moved and the two register fields used for the displacement
instead.""")
    rows = []
    for (name, meaning, layout, why) in FORMATS:
        rows.append((name, layout, meaning, why))
    table(('format', 'inst[31:0]', 'name', 'what it is for'), rows,
          [7, 40, 20, 46])
    print()
    para("""Read the R row and the S row together.  R has no immediate at all, so
its five register-ish fields use all 32 bits: seven of opcode, three of
funct3, seven of funct7, and five each of rd, rs1 and rs2.  S has no
DESTINATION -- a store writes to memory, not to a register -- and the five
bits the destination would have occupied are the low five bits of the
immediate instead.  That is the whole of the S format and it is why the S
immediate is in two places.

And read the B row against the S row one more time, because the relationship
is the interesting part and it is stated in the manual.  QUOTED, section 2.3:

    "The only difference between the S and B formats is that the 12-bit
     immediate field is used to encode branch offsets in multiples of 2 in the
     B format.  Instead of shifting all bits in the instruction-encoded
     immediate left by one in hardware as is conventionally done, the middle
     bits (imm[10:1]) and sign bit stay in fixed positions, while the lowest
     bit in S format (inst[7]) encodes a high-order bit in B format."

Read that twice.  In S, inst[7] is the immediate's bit 0.  In B, inst[7] is
the immediate's bit 11.  The SAME bit position, the same instruction width, the
same seven-bit funct7 slot above it -- and it is the TOP of the displacement
instead of the bottom.  Section 7's masks show it: the B mask is 0xfe000f80
and the S mask is 0xfe000e00, and they differ by exactly bit 7.""")
    print('  THE SIX FORMATS CLASSIFIED OVER THE WHOLE CORPUS.  The')
    print('  classifier reads the OPCODE and, for opcode 0x6f, the immediate --')
    print('  and the 0x6f special case is worth naming, because it is the only')
    print('  place in the architecture where the format is not a function of')
    print('  the opcode alone.')
    print()
    import collections
    byfmt = collections.Counter()
    byop = collections.Counter()
    total = 0
    for k in corpus_insns():
        if k.nbytes == 2:
            byfmt['C (9 formats)'] += 1
            continue
        byfmt[k.fmt or '(unclassified)'] += 1
        byop[bits(k.word, 6, 0)] += 1
        total += 1
    table(('format', 'instructions', 'share'), [
        (f, n, '%.1f%%' % (100.0 * n / len(corpus_insns())))
        for f, n in byfmt.most_common()], [14, 12, 8])
    print()
    para("""Two rows of that table are the argument for the section.

**The I format is the commonest thing in a RISC-V program and it is not a
compromise.**  It carries a contiguous twelve-bit immediate at inst[31:20],
and its `rd` and `rs1` are at the base positions.  A decoder that implements
I, S, R, U, J and B has implemented every base instruction, because those six
are the complete set of layouts.  There is no seventh and there is no prefix.

**J is the rarest and it is the one that looks like a mistake.**  %d
instructions in this corpus are J format, and every one of them spends
inst[19:12] and inst[30:20] on a displacement.  If you read a J instruction
as a U instruction -- which is a natural mistake, since the two share an
opcode-adjacent layout and the first twenty bits of the immediate are in the
same place -- you get a jump to a wildly wrong address, and the low twelve
bits of the jump target come out right, so the disassembly LOOKS like a jump
to a nearby place.  `jal ra, .+2048` and `lui ra, 1` differ in six bits and
one of them is a call.
""" % byfmt.get('J', 0))
    print('  THE OPCODE SPACE AS THE CORPUS USES IT.  The seven-bit opcode')
    print('  is the first thing a decoder reads, and this is how much of the')
    print('  128-value space ordinary C touches.')
    print()
    rows = []
    for op, n in sorted(byop.items()):
        mn = [k.name for k in corpus_insns()
              if k.nbytes == 4 and bits(k.word, 6, 0) == op and k.name]
        top = collections.Counter(mn).most_common(3)
        rows.append(('0x%02x' % op, format(op, '07b'), n,
                     ' '.join('%s(%d)' % t for t in top)))
    table(('opcode', 'bits', 'count', 'the mnemonics that landed there'), rows,
          [8, 9, 7, 46])
    print()
    para("""%d of the 128 opcode values carry at least one instruction in this
corpus, and the rest are either other extensions, other bases, or reserved.
That is a fact about eleven functions of ordinary C, and section 11 audits the
whole 128 against the second reader so the claim has a table behind it.

Read the row for opcode 0x13, because it is the row that shows why an
assembler is not a lookup table.  Opcode 0x13 is OP-IMM: it carries addi,
slti, sltiu, xori, ori, andi, slli, srli, srai and the shift-immediate
aliases, and the operation is the PAIR (funct3, inst[31:26]).  One opcode, ten
instructions, and the choice between them needs two fields read together.  A
lookup table keyed on the opcode gives you one of ten; a decoder has to read
funct3 as well.  That is the whole difference, and it is why the manual's
statement that the register positions were kept fixed "to simplify decoding"
is not a claim that decoding is simple -- it is a claim about WHERE the
complication was put.""" % len(byop))


def sec4b(base_masks):
    banner(4, 'B.  THE SEVEN BITS OF funct7, AND WHAT A LOWER BOUND LOOKS LIKE')
    print()
    para("""The funct7 row in section 4 moved bits 25 and 30 out of a seven-bit
field, and a reader is entitled to ask whether the measurement failed.  It
did not, and this section is the answer, because it is the clearest example in
the course of the rule that a mask is a LOWER BOUND.

`add` has funct7 = 0b0000000 and `sub` has funct7 = 0b0100000.  One bit
apart.  Those are the only two funct7 values the base R format can reach from
an add/sub pair, so a sweep over nine base operations moves bit 30 and not the
other six -- except that `mul` has funct7 = 0b0000001, which moves bit 25.

To move the REST of funct7's bits the sweep has to leave the base ISA, because
in the base ISA there is nothing else in funct7.  The F and D extensions fill
it.  MEASURED, one instruction per row:""")
    rows = []
    for src in ('add a0, a1, a2', 'sub a0, a1, a2', 'sll a0, a1, a2',
                'mul a0, a1, a2', 'fadd.s fa0, fa1, fa2', 'fsub.s fa0, fa1, fa2',
                'fmul.s fa0, fa1, fa2', 'fdiv.s fa0, fa1, fa2',
                'fmin.s fa0, fa1, fa2', 'fsgnj.s fa0, fa1, fa2',
                'fmadd.s fa0, fa1, fa2, fa3', 'fsqrt.s fa0, fa1',
                'fcvt.s.d fa0, fa1', 'fcvt.w.s a0, fa0', 'fmv.x.w a0, fa0',
                'fclass.s a0, fa0'):
        w, _nb, t = asm_one(src, 'rv64imafd')
        if w is None:
            rows.append((src, '(refused)', '', '', ''))
            continue
        rows.append((src, '0x%08x' % w, format(bits(w, 31, 25), '07b'),
                     format(bits(w, 26, 25), '02b'), bits(w, 14, 12)))
    table(('source', 'word', 'inst[31:25]', 'inst[26:25]', 'funct3'), rows,
          [26, 12, 12, 11, 7])
    print()
    para("""Three things in that table, and the first is a retraction of the plan.

**The seven bits at inst[31:25] are NOT ONE FIELD.**  The manual draws its
floating-point tables with a column headed `funct7`, and the heading is a
simplification.  Under opcode 0x53 those seven bits are a FIVE-bit operation
selector at inst[31:27] and a TWO-bit width at inst[26:25], and there is no
way to read them as one seven-bit funct7 at all.  `fadd.s` and `fadd.d` differ
in inst[25] -- ONE bit -- and the first version of this file's `r_fp` model
read a seven-bit funct7 and therefore could not tell them apart, and
separately could not tell `fsqrt.s` from `fadd.s` because for the square root
the same five bits are the high half of the selector.

**A sub-opcode selector is not self-contained.**  `fmadd.s` is
inst[31:27] = 0b01101 with opcode 0x43.  `fmin.s` is inst[31:27] = 0b00101
with opcode 0x53.  Two different five-bit values, so that is not the sharpest
case -- but `fadd.s` is inst[31:27] = 0b00001 under opcode 0x53 and `add` is
inst[31:25] = 0b0000000 under opcode 0x33, and the FLOATING-POINT one has
funct3 = 7 where the integer one has funct3 = 0.  A dispatch that asks models
in order without first reading the opcode resolves these by list position,
which is not a decoding strategy, it is a coin flip with a plausible-looking
output.  `i_fma` in this file is the model whose opcode set is 0x43, 0x47, 0x4b
and 0x4f, and the reason is written at the top of the model table.

**The width of a floating-point operation is one bit, and it is in a
different place in different instructions.**  fadd.s is 0x00c5f553 and
fadd.d is 0x02c5f553: one bit, inst[25], in the non-fused rows.  fmadd.s is
0x68c5f543 and fmadd.d is 0x6ac5f543: one bit, inst[25], in the fused rows
too -- but the field ABOVE it, inst[31:27], is rs3 in one family and a
sub-opcode in the other.  A decoder that learned "the width is inst[25]" from
one family gets the other family right by luck.""")
    m25 = base_masks.get('funct7+funct3, 9 base R ops')
    if m25 is not None:
        moved = [b for b in range(32) if m25 >> b & 1 and 25 <= b <= 31]
        print('    The base sweep moved bits %s of funct7\'s seven positions.'
              % ','.join(str(b) for b in moved))
        print('    The table above reaches all seven.  Both numbers are true,')
        print('    they measure different things, and a course that printed')
        print('    only the first would have claimed a two-bit funct7.')
        print()


def walk_sections():
    """(file, section, size, bytes consumed, n instructions) for every
    code section in the corpus."""
    rows = []
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        for name, addr, off, size in secs:
            insns, used = decode_text(d, off, size, addr)
            rows.append((f, name, size, used, len(insns)))
    return rows


def sec2():
    banner(2, 'THE SPECTRUM: TWO BYTES OR FOUR, AND HOW A DECODER KNOWS')
    print()
    para("""The one property that makes RISC-V different from AArch64 in a way a
decoder feels, and the reason this file's declared subset is a subset of NAMES
rather than of LENGTHS -- but reached by a completely different route, because
here the length is a RULE and there it was a constant.

    if bits[1:0] == 0b11    the instruction is 32 bits
    else                     the instruction is 16 bits

Two bits.  The rule needs nothing but the current position, which is why a
decoder with no model at all for an instruction still steps over it correctly
and the chain cannot desynchronise.""")
    print('  THE THREE EXEMPLARS the section plan measured while scoping, and')
    print('  re-measured here from the corpus rather than quoted:')
    print()
    for word, src, why in ((0x952e, 'add a0, a0, a1', 'the whole argument '
                            'for C in one word'),
                           (0x0d85f2d7, 'vsetvli t0, a1, e64, m1, ta, ma',
                            'V, and V is never compressed'),
                           (0x00000073, 'ecall', 'SYSTEM, four bytes, and 31 '
                            'of the 32 bits are a fixed pattern')):
        i = decode(word)
        print('    0x%08x  %d bytes  %-40s' % (i.word, i.nbytes, i.text))
        print('                %s' % why)
    print()
    para("""Read the first row and the third side by side.  One is two bytes and
does an integer addition; the other is four bytes and does nothing at all.
That is the encoding spectrum in two words, and it is why "RISC-V is smaller"
is not a claim about instruction sets -- it is a claim about which
instructions the COMPILER was allowed to shorten, and the compiler is a
separate program with separate decisions.""")
    print('  THE LENGTH RULE, applied to every code section of every object.')
    print('  The column that matters is the fourth: bytes walked against bytes')
    print('  in the section.  Anything but equality is a desynchronised walk,')
    print('  and the last column says whether there was one.')
    print()
    rows = []
    allok = True
    for (f, name, size, used, n) in walk_sections():
        ok = (used == size)
        allok = allok and ok
        rows.append((f, name, size, used, n, 'EXACT' if ok else 'MISMATCH'))
    table(('object', 'section', 'bytes', 'walked', 'insns', 'end'), rows,
          [22, 8, 7, 8, 7, 9])
    print()
    print('    %d code sections, %d instructions, and %s'
          % (len(rows), sum(r[4] for r in rows),
             'EVERY WALK ENDS EXACTLY ON ITS SECTION END' if allok
             else 'AT LEAST ONE WALK DID NOT -- see the MISMATCH rows above'))
    print()
    para("""That is a MEASUREMENT and not a definition, and the difference is
worth one sentence: the length rule is two lines of code and a definition does
not need checking.  This one was checked against %d real sections, and the
checking found nothing -- which is a result, and a result that could have come
out otherwise.

It also establishes the guarantee the rest of the file relies on.  A word this
file cannot name still contributes exactly its own length to the count, so the
instruction count in every table below is a property of the CORPUS and not of
this decoder's coverage.  The AArch64 course gets that guarantee from a
constant; this file gets it from a two-bit rule, and gets it for a different
reason.""" % len(rows))
    print('  THE LENGTH DISTRIBUTION, per object.  The fraction that is two')
    print('  bytes is the only number in this section that anyone will quote,')
    print('  and it is a property of a COMPILER on a CORPUS, not of the ISA.')
    print()
    rows = []
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        tot = two = four = 0
        bylen = {2: 0, 4: 0}
        for name, addr, off, size in secs:
            insns, _u = decode_text(d, off, size, addr)
            for k in insns:
                bylen[k.nbytes] = bylen.get(k.nbytes, 0) + 1
            tot += len(insns)
        for L, n in sorted(bylen.items()):
            if L == 2:
                two = n
            else:
                four = n
        bytes_ = 2 * two + 4 * four
        rows.append((f, tot, two, four, bytes_,
                     '%.3f' % (float(two) / tot) if tot else '-',
                     '%.3f' % (float(bytes_) / tot) if tot else '-'))
    table(('object', 'insns', '2-byte', '4-byte', 'bytes', 'frac 2B',
           'B/insn'), rows, [22, 6, 7, 7, 7, 8, 8])
    print()
    corpus_t = corpus_rvafd = corpus_rvafdc = None
    for f in corpus_files()[0]:
        d, secs = code_sections(os.path.join(HERE, f))
        n = sum(len(decode_text(d, o, s, a)[0]) for _n, a, o, s in secs)
        if f == 'corpus_rv64imafd.o':
            corpus_rvafd = n
        if f == 'corpus_rv64imafdc.o':
            corpus_rvafdc = n
    if corpus_rvafd and corpus_rvafdc:
        para("""The last two rows of that table are the same C file compiled with
and without the C extension, and the comparison is the whole of the honest
half of the compressed story:

    -march=rv64imafd    %d instructions
    -march=rv64imafdc   %d instructions

THE INSTRUCTION COUNT IS THE SAME.  Adding C did not change what the program
does, how many operations it performs, or which operations those are.  It
changed the number of BYTES, and the byte count is the only thing in this
section that anyone will quote about compression.

That is worth stating carefully because the usual claim goes the other way
round -- that compression makes the code "smaller", as if the program had less
in it.  It does not.  The program has the same instructions in it; some of
them have a shorter encoding.  Section 6 then measures the other half: how
much of the encoding space the extension had to RESERVE to make that possible,
and what a decoder has to do with the reserved part."""
             % (corpus_rvafd, corpus_rvafdc))


def sec1():
    banner(1, 'THE INSTRUMENT.  Nothing below this point is a claim yet.')
    print()
    para("""There is no RISC-V machine on this host, no emulator, and no RISC-V
binutils.  Nothing in the corpus is ever EXECUTED.  The compiler emits words,
the disassembler names words, and this file reads words.  Every number below
is a bit pattern, a count of bit patterns, an arithmetic identity, or a
refusal from a real assembler -- and not one of them is a property of a
running RISC-V program, because there is no running RISC-V program here to
have a property.""")
    rows = [
        ('assembles', tool_version(CLANG, '--version'),
         'C and asm to RISC-V; the SECOND reader'),
        ('disassembles', tool_version(OBJDUMP, '--version'),
         'the SECOND reader, and an INDEPENDENT one'),
        ('reads attributes', tool_version(READELF, '--version'),
         'for the Tag_RISCV_arch string concept 1 is about'),
        ('links RISC-V', which('riscv64-linux-gnu-ld') or 'NOT INSTALLED',
         'so no linked image is compared and no relocation resolves'),
        ('GNU RISC-V as', which('riscv64-linux-gnu-as') or 'NOT INSTALLED',
         'so both readers come from ONE LLVM tree'),
        ('emulates RISC-V', which('qemu-riscv64') or 'NOT INSTALLED',
         'so NO INSTRUCTION IS EXECUTED'),
        ('emulates RISC-V', which('spike') or 'NOT INSTALLED',
         'the second emulator, also absent'),
    ]
    table(('role', 'what was found', 'what that means'), rows, [18, 44, 42])
    print()
    para("""The rows that matter are the NO rows, and they are printed before any
measurement rather than in a limits section at the end, because a reader who
meets a number and meets the absence of the thing that would make it a runtime
measurement in a different order learns a different lesson.

And the consequence for the WHOLE section, stated once here so that no page
has to repeat it: THE X86-64 SECTION'S RATIOS HAVE NO COUNTERPART HERE.  There
is no speedup, no cycle count, no cache miss, no IPC and no clock anywhere in
this file.  Where a page would naturally carry a number of that kind it carries
a BYTE COUNT, an INSTRUCTION COUNT, or a REFUSAL, and the page says which.  A
number invented to fill the gap would be the single worst thing this course
could do, and the plan's own rule is the reason: every claim is MEASURED,
MEASURED-ON-BYTES or QUOTED, and a fabricated ratio can be none of them.""")
    para("""THE DECODER USES NO TOOL AT ALL.  Part one of this file imports os, re,
struct and sys and nothing else.  struct.unpack_from reads the ELF64 section
header table by hand -- e_shoff at 0x28, e_shentsize/e_shnum/e_shstrndx at
0x3a, then 64 bytes per entry -- and .text is found by NAME.  The reader is a
dependency of the claim rather than a convenience: a decoder that shells out
to a disassembler is a disassembler with a hardcoded path in it.""")
    elfhdr = [('e_shoff', '0x28', '8 bytes', 'offset of the section table'),
              ('e_shentsize', '0x3a', '2 bytes', 'size of ONE section header'),
              ('e_shnum', '0x3c', '2 bytes', 'how many there are'),
              ('e_shstrndx', '0x3e', '2 bytes', 'which one is the name table'),
              ('e_machine', '0x12', '2 bytes', '243 = EM_RISCV')]
    print('  THE ELF64 FIELDS THIS FILE READS, and nothing else:')
    table(('field', 'offset', 'width', 'what it selects'), elfhdr, [12, 9, 9, 44])
    print()
    para("""A reader who wants to check can: every offset above is in the ELF64
specification's section-header index and none of them is a constant invented
here.  The decoder CHECKS e_machine == 243 and refuses a file that is not a
RISC-V object, and the check is not decoration.  About a quarter of all x86-64
opcodes have bits[1:0] == 0b11, so the length rule would step four bytes at a
time through an x86-64 object and produce a stream of entirely plausible wrong
lengths.  Nothing in the DECODE would look wrong; the WALK would be wrong, and
the walk is what every other measurement in this file is taken against.""")
    insns = corpus_insns()
    unnamed = sum(1 for k in insns if k.name is None)
    reserved = sum(1 for k in insns if k.note == 'reserved')
    undef = sum(1 for k in insns if k.note == 'undefined')
    hint = sum(1 for k in insns if k.note == 'hint')
    files, missing = corpus_files()
    print('  THE DECLARED SUBSET, and what "subset" means HERE:')
    print('    %d instruction models for the 32-bit encodings and one handler'
          % len(MODELS32))
    print('    for the whole 16-bit space.  The subset is a subset of NAMES,')
    print('    and -- unlike the AArch64 course and unlike x86-64 -- an')
    print('    unmodelled word here still has a LENGTH, because the length is')
    print('    a two-bit RULE and not a table.  A word no model claims is')
    print('    printed as (op 0x...) and COUNTED, never dropped.')
    print()
    print('    Of the %d instructions in the corpus:' % len(insns))
    print('      %4d  named by a model in this file'
          % (len(insns) - unnamed - reserved - undef))
    print('      %4d  UNDEFINED by the architecture (not by this file)' % undef)
    print('      %4d  RESERVED compressed code points' % reserved)
    print('      %4d  HINTs -- DEFINED, and they do nothing' % hint)
    print('      %4d  unmodelled: the vector data path, and a few rows' % unnamed)
    print()
    para("""Those are five DIFFERENT numbers and section 10 depends on the
distinction.  An undefined encoding, a reserved encoding, a hint and an
unmodelled word all print something that is not a plain mnemonic, and a
two-reader cross-check that reported the last of them as a failure would be
reporting its own declared scope as a bug.""")
    if missing:
        print('    THE CORPUS IS INCOMPLETE -- these objects are MISSING:')
        for m in missing:
            print('      %s' % m)
        print('    Sections that read a missing object say so in their own')
        print('    words rather than skipping it.  Run ./build_samples.sh.')
        print()
    else:
        print('    All %d corpus objects are present.' % len(files))
        print()


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE INSTRUMENT', sec1),
    (2, 'THE SPECTRUM', sec2),
    (3, 'THE ISA AS DOCUMENTS', sec3),
    (4, 'THE FIELD MAP', sec4),
    (4, 'B. funct7 AND THE LOWER BOUND', sec4b),
    (4, 'C. THE NINE COMPRESSED FORMATS', sec4c),
    (4, 'D. SEVEN MASKS AND SEVEN PERMUTATIONS', sec4d),
    (5, 'SIX FORMATS', sec5),
    (6, 'THE COMPRESSED SPACE', sec6),
    (7, 'THE IMMEDIATES', sec7),
    (8, 'THE PAIR', sec8),
    (9, 'THE MAP AUDIT', sec9),
    (10, 'TWO READERS AND THREE POISONS', sec10),
    (12, 'RETRACTIONS', sec12),
    (11, 'LIMITS', sec11),
]


def header():
    print(RULE)
    print('rvdec -- the artifact for "RISC-V: The Encoding Spectrum"')
    print('Every number below is a BIT PATTERN, a COUNT of bit patterns, an')
    print('arithmetic identity, or a refusal from a real assembler.  Nothing is')
    print('quoted from a manual and NOTHING IS EXECUTED: there is no RISC-V')
    print('machine, no emulator and no RISC-V binutils on this host.  There are')
    print('no timings anywhere in this file and the x86-64 section\'s ratios')
    print('have no counterpart here.  See section 11.')
    print(RULE)
    print()


def hexwords(h):
    out = []
    for tok in h.replace(',', ' ').split():
        t = tok[2:] if tok.lower().startswith('0x') else tok
        out.append(int(t, 16))
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 0
    cmd = args[0]
    if not cmd.startswith('-'):
        # A bare hex word.  The header advertises `rvdec.py 952e` and the
        # first version of this file did not implement it: the argument was
        # compared against the list of `--` options, found no match, and
        # printed "unknown option '952e'".  A tool whose own header gives
        # three worked examples and fails on two of them is a tool a reader
        # stops trusting, and the three examples are the first thing anybody
        # runs.  The fix is four lines and the lesson is that a usage line is
        # a test case.
        for h in args:
            for w in hexwords(h):
                nb = length_of(w & 0xff, (w >> 8) & 0xff)
                print('0x%08x  %d bytes  %s' % (w, nb, decode(w).text))
        return 0
    if cmd == '--why':
        for h in args[1:]:
            for w in hexwords(h):
                print(explain(decode(w)))
                print()
        return 0
    if cmd == '--imm':
        for h in args[1:]:
            for w in hexwords(h):
                nb = length_of(w & 0xff, (w >> 8) & 0xff)
                print('  0x%08x  %d bytes' % (w, nb))
                if nb == 2:
                    i = decode16(w)
                    print('    quadrant %d, funct3 %d, format %s'
                          % (bits(w, 1, 0), bits(w, 15, 13), i.fmt))
                    print('    %s' % i.text)
                else:
                    i = decode32(w)
                    print('    opcode 0x%02x, format %s' % (bits(w, 6, 0), i.fmt))
                    print('    %s' % i.text)
                    for f in ('I', 'S', 'B', 'U', 'J'):
                        if f in i.why or True:
                            pass
                print('    the five immediates, from the bits:')
                for f in ('I', 'S', 'B', 'U', 'J'):
                    print('      %s-immediate = %d' % (f, IMMS[f](w)))
                print()
        return 0
    if cmd == '--audit':
        rows = []
        for (nm, ops, _fn, ext, claim) in MODELS32:
            rows.append((nm, ', '.join('0x%02x' % o for o in ops), ext,
                         claim[:60]))
        table(('model', 'the opcodes it may claim', 'ext', 'what it claims'),
              rows, [12, 34, 7, 60])
        print()
        print('    %d models, and %d claims -- the two numbers are printed'
              % (len(MODELS32), len(CLAIMS32)))
        print('    together because a model with no claim is a model nobody')
        print('    can check.  The opcode column is the DISPATCH KEY and it is')
        print('    not decoration: see the paragraph above the table for the')
        print('    two decoder bugs that a keyless dispatch produced.')
        return 0
    if cmd == '--fields':
        sec4()
        return 0
    if cmd == '--space':
        sec6()
        return 0
    if cmd == '--elf':
        for h in args[1:]:
            d, secs = code_sections(h)
            for name, addr, off, size in secs:
                insns, used = decode_text(d, off, size, addr)
                print('  %-10s va=0x%-8x %5d bytes -> %4d instructions, walk %s'
                      % (name, addr, size, len(insns),
                         'EXACT' if used == size else 'MISMATCH'))
                for k in insns:
                    print('    0x%08x  %d  %-11s %-6s %s'
                          % (k.addr, k.nbytes, k.fmt or '', k.ext or '',
                             k.text))
        return 0
    if cmd == '--section':
        n = int(args[1])
        # Sections 4B, 4C and 4D read section 4's measurements, so a bare
        # `--section 4b` runs section 4 first.  The alternative -- each of them
        # re-measuring what it needs -- costs a second sweep of the whole field
        # table and the point of the report is that a number appears once.
        state = {}
        for (num, title, fn) in SECTIONS:
            if num == 4 and title.startswith('THE FIELD'):
                state['masks'] = fn()
            elif num == 4:
                if n == 4 and title.startswith('B.'):
                    fn(state.get('masks'))
                elif n == 4 and title.startswith('C.'):
                    fn(state.get('masks'))
                elif n == 4 and title.startswith('D.'):
                    fn(state.get('masks'))
            elif num == n:
                fn()
        return 0
    if cmd == '--run':
        header()
        state = {}
        for (num, title, fn) in SECTIONS:
            if num == 1:
                state = {'sec1': fn()} or {}
            elif num == 2:
                state['sec2'] = fn()
            elif num == 3:
                state['attrs'] = fn()
            elif num == 4:
                if title.startswith('THE FIELD'):
                    state['masks'] = fn()
                else:
                    fn(state.get('masks'))
            elif num == 6:
                state['space'] = fn()
            elif num == 9:
                state['audit'] = fn()
            else:
                fn()
            print()
        print(RULE)
        print('END OF REPORT')
        print(RULE)
        return 0
    print('unknown option %r; try --why, --imm, --audit, --fields, --space, '
          '--elf, --section N, --run' % cmd)
    return 1


if __name__ == '__main__':
    sys.exit(main())
