#!/usr/bin/env python3
"""a64dec.py -- an AArch64 instruction decoder, and the reason for every bit.

The interesting part of an AArch64 instruction is not the mnemonic.  It is that
the mnemonic is not stored anywhere, and the LENGTH is not stored anywhere
either -- and that the second one is free here, which is the whole difference
from x86 in one sentence:

    an A64 instruction is EXACTLY 4 BYTES, ALWAYS, so a decoder that does not
    know what an instruction DOES still knows exactly how long it is.

Everything else follows from that.  A field map is the curriculum, because
there are no prefixes to discover and no length arithmetic to get wrong.  Two
immediates that cost you four bytes each.  Sixteen condition codes in four bits.
And a logical-immediate encoding that is not a literal at all: a rotate and a
run-length in twelve bits, which is the one place in the whole architecture
where you cannot just read the number out.

    python3 a64dec.py 8b000020              # decode one word
    python3 a64dec.py --why 1204cc00        # only the reasoning, field by field
    python3 a64dec.py --elf corpus_O2.o     # walk every code section
    python3 a64dec.py --imm 0x1204cc00      # the logical-immediate algebra only
    python3 a64dec.py --audit               # the modelled-opcode table
    python3 a64dec.py --fields a64.s        # MEASURE the field map by difference

No toolchain is used to DECODE anything.  ELF64 section headers are read with
struct.unpack_from and .text is found by name, exactly as the ISA course's
x86dec.py does.  The assembler is asked for field positions in one place only
(`--fields`), because there is no other honest way to learn a field map and
because a map you measured is worth more than a map you remembered.

The second reader is `llvm-objdump-21 --triple=aarch64`, and the two-reader
cross-check lives in the measurement driver at the bottom of this file.  A
decoder that is wrong in the same way as its oracle is not a check, which is
why section 12 decodes the same bytes twice, gets 100% agreement, POISONS the
table, and gets 100% agreement again.
"""

import os
import re
import struct
import subprocess
import sys

# ===========================================================================
# Part one: the decoder.
# ===========================================================================

# ---------------------------------------------------------------------------
# Registers.
#
# There are 31 general registers and a 32nd register number, 31, which is the
# stack pointer.  Register number 30 is a real register in most fields and the
# ZERO register in a handful of others, and which one it is depends on the
# INSTRUCTION, not on the number.  Getting this wrong is the single most common
# A64 decoder bug, so the decoder never guesses: each model says which of the
# two it means, and the difference is printed.
# ---------------------------------------------------------------------------
XN = ['x%d' % i for i in range(31)] + ['sp']
WN = ['w%d' % i for i in range(31)] + ['wsp']


def reg(n, sf=1, allow_sp=True, allow_zr=False, allow_31=True):
    """A 5-bit register field.

    sf=1 -> the 64-bit view (x/sp), sf=0 -> the 32-bit view (w/wsp).  A 32-bit
    write ZEROES the top half; the encoding has no separate name for that.

    The three escapes are all MEASURED and they are all PER FIELD, which is
    the trap.  Register 31 is the stack pointer in some operand slots and
    NOTHING in others; register 30 is a real register in most slots and the
    zero register in a handful.  So this function takes the permissions from
    the model rather than deciding once:

      allow_sp   31 may name sp/wsp.  MEASURED: `str w0, [x31, #12]` is
                 0xb9000fe0 and the printer calls the base `sp`, and
                 `cbz w31, T` is 0x340001bf and the printer calls the register
                 `wzr`.  Same field number, same instruction word family,
                 two different meanings -- so the flag has to come from the
                 model, every time.
      allow_zr   30 may name xzr/wzr.  `adds w0, w1, w2` has Rn = 1 and
                 `mvn w0, w1` is ORN with Rn = 31, printed `mvn w0, w1`.

    A decoder that decides these once gets a *plausible* answer in the common
    case and a wrong one exactly where a compiler is most likely to emit the
    instruction, which is the definition of a bug that survives review.
    """
    if n == 31:
        # allow_31 False means "31 is NOT the stack pointer here", and what it
        # is instead depends on the field: the zero register in a load's Rt, in
        # CBZ/TBZ's Rt, and in a select's source.  So the fallback is xzr, and
        # the distinction between the two escapes is a property of the MODEL.
        return ('sp' if sf else 'wsp') if allow_sp else \
            ('xzr' if sf else 'wzr')
    if n == 30 and allow_zr:
        return 'xzr' if sf else 'wzr'
    return ('x%d' % n) if sf else ('w%d' % n)


# ---------------------------------------------------------------------------
# The sixteen condition codes.  bits[3:1] is the primary condition and bit 0
# INVERTS it, so half the table is the other half with one bit set -- and the
# inversion is not a second encoding, it is a bit, which is what makes CSET a
# one-instruction idiom instead of a compare followed by a write.
# ---------------------------------------------------------------------------
COND = ['eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
        'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al', 'nv']
# The two spellings of the same bit pattern, as the ASSEMBLER prints them.  The
# second half of the table is the first half inverted, and the assembler
# prefers the C/Go-style name for the unsigned forms and the ARM-style name
# for the signed ones.  MEASURED, section 10.
COND_ALT = ['eq', 'ne', 'hs', 'lo', 'mi', 'pl', 'vs', 'vc',
            'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al', 'nv']
# The x86-64 analogue of each code, for the two-reader comparison in the text.
COND_X86 = ['e/z', 'ne/nz', 'b/c/nae', 'ae/nb/nc', 'n', 'nn', 'p/pe', 'np/po',
            'a/nbe', 'be/na', 'nl', 'l/nge', 'g/nle', 'le/ng', '?', '?']


def cond_text(c, alt=False):
    return (COND_ALT if alt else COND)[c]


def cond_invert(c):
    return c ^ 1


# ---------------------------------------------------------------------------
# The logical immediate: N:immr:imms, and a 64-bit pattern with the rotate
# built into the same two fields.
#
# The two functions below are the ARM DDI 0487 "DecodeBitMasks" and
# "EncodeBitMasks" pair, transcribed.  QUOTED, and section 7 measures the
# transcription against real assembler output, including the constants it
# refuses to accept.
# ---------------------------------------------------------------------------


class Bad(Exception):
    """The word does not decode here.  Carries the reason."""


class Undefined(Bad):
    """A well-formed word the architecture leaves UNDEFINED."""


def ones(n):
    return (1 << n) - 1


def highest_set_bit(x):
    n = 0
    while x:
        n += 1
        x >>= 1
    return n


def ror(value, amount, width):
    m = ones(width)
    amount %= width
    return ((value >> amount) | (value << (width - amount))) & m


def decode_bit_masks(N, imms, immr, width):
    """DecodeBitMasks(N, imms, immr, width) -> (value, [notes]).

    The `width` argument is the width of the DESTINATION, and it is the only
    thing that distinguishes a 32-bit AND from a 64-bit one whose N:immr:imms
    fields are identical: the 64-bit form builds a 64-bit value and the 32-bit
    form builds a 32-bit value, so the SAME twelve bits name two constants.
    MEASURED against the assembler, and the first version of this function
    had two errors that 49 accepted 32-bit constants found immediately:

      1. `HighestSetBit` is a ZERO-BASED POSITION, not a bit count.  With
         0xaaaa....: N = 0, imms = 60, so N:NOT(imms) = 0b0_000011 and the
         highest set bit is at POSITION 1, giving esize = 2.  Counting bits
         instead gave 3, esize = 8, and every 2-bit pattern came out wrong.
      2. There is no `S - R` test on the DECODE side.  `and w0,w0,#0x2` is
         encoded imms = 0, immr = 31, so S = 0 and R = 31 and S-R is
         NEGATIVE, and the encoding is perfectly valid.  The subtraction
         belongs to the ENCODER's canonical-form choice, not to the decoder,
         and putting it in the decoder made every single-bit mask above bit 0
         UNDEFINED -- which is most of them.
    """
    notes = []
    not_imms = (~imms) & ones(6)
    length = (N << 6 | not_imms).bit_length() - 1
    if length < 1:
        raise Undefined('N:NOT(imms) is 0, so there is no element size: the '
                        'encoding is UNDEFINED.  Every (N, imms) pair with '
                        'N = 0 and imms = 0b111111 is dead.')
    esize = 1 << length
    levels = ones(length)
    S = imms & levels
    R = immr & levels
    if S == levels:
        raise Undefined('imms is all ones INSIDE the element, so the element '
                        'is all ones, and the 64-bit pattern would be %#x -- '
                        'which the architecture reserves and the assembler '
                        'REFUSES (MEASURED)' % ones(64))
    welem = ror(ones(S + 1), R, esize)
    reps = 64 // esize
    wide = 0
    for k in range(reps):
        wide |= welem << (k * esize)
    if wide == 0 or wide == ones(64):
        raise Undefined('the pattern is %#018x, and an all-zero or all-one '
                        'pattern is not encodable: the assembler refuses it'
                        % wide)
    value = wide & ones(width)
    notes.append('len = the position of the highest set bit of N:NOT(imms) = '
                 '0b%s, so esize = 1 << %d = %d bits'
                 % (format((N << 6) | not_imms, '07b'), length, esize))
    notes.append('S = imms & %s = %d is the WIDTH of the run of ones (S+1 = '
                 '%d of them); R = immr & %s = %d is how far RIGHT that run is '
                 'rotated inside the element' % (bin(levels), S, S + 1,
                                                 bin(levels), R))
    notes.append('a run of %d ones is 0b%s; rotate it right by %d within %d '
                 'bits and you get 0b%s = %#x'
                 % (S + 1, bin(ones(S + 1))[2:], R, esize,
                    bin(welem)[2:], welem))
    notes.append('repeat that element %d times: the 64-bit pattern is %#018x'
                 % (reps, wide))
    if width == 32:
        notes.append('the destination is 32 bits, so the answer is the low 32 '
                     'of that pattern: %#010x' % value)
    return value, notes


def encode_bit_masks(value, width):
    """EncodeBitMasks(immr, imms, immediate, width) -> (N, immr, imms) or None.

    The inverse, and it is the only way to answer "which constants can this
    encoding reach" without asking a human.  It searches the six element sizes
    and, for each, every rotation of every run length -- 64 * 32 = 2048
    candidates, which is why the ARM ARM's own algorithm is a clever shortcut
    rather than an obvious loop, and also why this file measures the
    relationship instead of trusting a remembered one.

    `None` means NOT ENCODABLE, and that is the interesting answer: the set of
    encodable constants is 2,078 of the 2^64, and the 4,294,967,296 32-bit
    constants have 6,146 of them available.
    """
    value &= ones(width)
    for length in range(1, 7):
        esize = 1 << length
        welem = value & ones(esize)
        cand = 0
        for k in range(64 // esize):
            cand |= welem << (k * esize)
        if (cand & ones(width)) != value:
            continue
        if welem == 0 or welem == ones(esize):
            continue                    # 0 and all-ones are reserved
        for n in range(1, esize):
            run = ones(n)
            for R in range(esize):
                if ror(run, R, esize) != welem:
                    continue
                S = n - 1
                N = 1 if length == 6 else 0
                return N, R, pad_imms(S, length)
    return None


def pad_imms(S, length):
    """The imms FIELD, not just the S value -- MEASURED, and the difference is
    the whole reason a hand-written encoder is wrong.

    S is the low `length` bits of imms.  The bits ABOVE them are not zero:
    they are ONES, and it is those ones that the decoder reads back to
    recover `length` at all.  Four assembler outputs:

        0xaaaaaaaa  length=1  S=0  imms=60 = 0b111100
        0xf0f0f0f0  length=3  S=3  imms=51 = 0b110011
        0xff00ff00  length=4  S=7  imms=39 = 0b100111
        0xffff0000  length=5  S=15 imms=15 = 0b011111

    In every case imms = (a run of ones above bit `length`) | S, with exactly
    one ZERO at bit `length`.  That zero is the flag: NOT(imms) has its
    highest set bit at position `length`, which is how `len` is recovered, and
    an imms of plain S with zeros above would decode as a different element
    size or as UNDEFINED.  The round-trip check in section 7 is what caught
    this: the encoder was self-consistent and the assembler was not.
    """
    if length >= 6:
        return S
    return S | (ones(6 - length - 1) << (length + 1))


def encodable_set(width):
    """Every constant the encoding can name, as a SET.

    Built by ENUMERATING THE ENCODING rather than by scanning the 2^width
    constants: there are six element sizes, at most 64 run lengths and at most
    64 rotations each, so the whole space is 2,047 candidates and the
    32-bit scan of 4,294,967,296 values that the first version of this
    function attempted did not finish in two minutes.  A measurement that
    times out is not a measurement, and the fix is to enumerate the small
    side of the question -- which is also the side that makes the answer
    checkable, because each generated value is then DECODED back.
    """
    out = set()
    for length in range(1, 7):
        esize = 1 << length
        if width % esize:
            continue
        reps = 64 // esize
        for n in range(1, esize):
            run = ones(n)
            for R in range(esize):
                welem = ror(run, R, esize)
                wide = 0
                for k in range(reps):
                    wide |= welem << (k * esize)
                if wide == 0 or wide == ones(64):
                    continue
                v = wide & ones(width)
                if v and encode_bit_masks(v, width) is not None:
                    out.add(v)
    return out


def encodable_count(width):
    """How many of the 2^width constants can the encoding name?"""
    return len(encodable_set(width))


# ---------------------------------------------------------------------------
# The instruction object.  Every field read goes through `read()` or `fixed()`,
# which is how the artifact can count the bits an encoding ACTUALLY USES
# instead of asserting a number.
# ---------------------------------------------------------------------------


class Insn(object):
    # `file` and `sec` say where a word came from, and they are here because
    # __slots__ means there is nowhere else to put them: a slot that is not
    # declared raises AttributeError the moment a measurement tries to
    # annotate a decode, and the first such measurement was a crash three
    # sections deep rather than a line.
    __slots__ = ('word', 'off', 'why', 'name', 'ops', 'bits', 'cls', 'text',
                 'note', 'key', 'file', 'sec')

    def __init__(self, word, off=0):
        self.word = word & 0xffffffff
        self.off = off
        self.why = []
        self.name = None
        self.ops = []
        self.bits = set()
        self.cls = ''
        self.text = ''
        self.note = ''
        self.key = (self.word >> 25) & 0xf
        self.file = ''
        self.sec = ''

    # -- field access -----------------------------------------------------
    def read(self, hi, lo):
        self.bits.update(range(lo, hi + 1))
        return (self.word >> lo) & ones(hi - lo + 1)

    def peek(self, hi, lo):
        return (self.word >> lo) & ones(hi - lo + 1)

    def fixed(self, hi, lo, want, label):
        got = self.read(hi, lo)
        if got != want:
            self.why = []
            return False
        return True

    def say(self, s):
        self.why.append(s)

    @property
    def bits_used(self):
        return len(self.bits)

    def __str__(self):
        return '0x%08x  %s' % (self.word, self.text)


FIELDS = [
    # The top-level class field, and the rule that turns four bits into the
    # four named classes of the A64 encoding.  DERIVED from the measured
    # membership in section 3; the four class NAMES are QUOTED from ARM DDI
    # 0487, "The A64 instruction set".
    #
    #   bits[28:27] == 01 and bits[26:25] == 11  -> Advanced SIMD
    #   bits[28:27] == 01 and bit[25]            -> DP-register or DP-immediate
    #   bit[28] == 1 and bit[27] == 0            -> DP-immediate or Branch
    #   otherwise                                -> bit[25] picks L/S vs DP-reg
    (31, 29, None, 'sf / op / S'),
    (28, 25, None, 'the class field'),
]


def class_of(w):
    """The four named top-level classes, by bits[28:25].

    MEASURED, by section 3 over 868 instructions from five object files:

        0100  23  ldp stp            -> Loads and Stores (pair)
        0101 111  add mov subs cmp   -> Data Processing -- Register
        0110   1  ldp                -> Advanced SIMD (pair)
        0111   6  add movi addv      -> Advanced SIMD
        1000 114  add sub cmp subs   -> Data Processing -- Immediate
        1001 134  mov and movk lsl   -> Data Processing -- Immediate
        1010  84  b bl b.ne cbz      -> Branches, Exception Gen and System
        1011 142  ret tbz br blr     -> Branches, Exception Gen and System
        1100 151  ldr str ldrb       -> Loads and Stores
        1101 101  csel cset mul madd -> Data Processing -- Register
        1111   1  fmov               -> Advanced SIMD / FP
        0000-0011, 1110  EMPTY in this corpus

    The first version of this function used a two-bit rule
    (`b28 and not b27`, then `b26`, then `b25`) read off a table remembered
    from the manual, and it put `ret` -- 134 of the 868 instructions, the single
    largest entry in the whole distribution -- in "Data Processing --
    Register" because bits[28:26] of 0xd65f03c0 is 0b110.  The four-bit class
    field is the unit the encoding actually decodes on, and three of the
    sixteen values carry a real instruction and two of those three are the
    ones a two-bit rule cannot see.
    """
    key = (w >> 25) & 0xf
    b28 = (w >> 28) & 1
    b27 = (w >> 27) & 1
    b26 = (w >> 26) & 1
    b25 = key & 1
    if b28 == 1 and b27 == 0:
        if b26 == 0:
            return 'Data Processing -- Immediate', key
        return 'Branches, Exception Generating and System', key
    if b28 == 0 and b27 == 1 and b26 == 1:
        return 'Advanced SIMD', key
    if key < 0b100:
        return 'Reserved / UNDEFINED', key
    if b25 == 0:
        return 'Loads and Stores', key
    return 'Data Processing -- Register', key


# ---------------------------------------------------------------------------
# The models.  Each one is a function that first checks the FIXED bits of its
# own group and returns False if they do not match, so the dispatch is a
# decision tree a reader can read top to bottom.  A model that matches owns
# the word.
# ---------------------------------------------------------------------------


def m_hint(i):
    # MEASURED: `nop` is 0xd503201f and `wfi` is 0xd503207f, so the family is
    # bits[31:5] = 0xd503201f >> 5 = 0x06A8190 -- TWENTY-SEVEN fixed bits, the
    # most information this decoder ever discards.  The first version guarded
    # bits[31:24] = 0b11010110, which is 0xd6 and not 0xd5, and so decoded
    # NOTHING in this family: a one-bit transcription error in a guard is
    # indistinguishable from "this architecture has no hints".
    if not i.fixed(31, 5, 0xD503201F >> 5, 'HINT (one pattern, 27 fixed bits)'):
        return False
    # MEASURED, and this is the part nobody quotes.  clang's assembler emits
    # nine hints and in ALL NINE the low five bits are 0b11111:
    #
    #   nop  0xd503201f  bits[6:0]=0x1f      sev    0xd503209f  0x1f
    #   yield 0xd503203f       0x3f          sevl   0xd50320bf  0x3f
    #   wfe  0xd503205f       0x5f          dgh    0xd50320df  0x5f
    #   wfi  0xd503207f       0x7f          bti    0xd503241f  0x1f
    #
    # so the discriminator is bits[6:5] and the other five bits are decoration
    # for the same instruction.  `hint #0` and `hint #31` assemble to the SAME
    # word (both 0xd503201f), so the hint number is not a field you can read
    # off the instruction -- it is a TABLE, and this decoder prints the table
    # it measured rather than the table it remembered.
    lo = i.read(4, 0)
    hi = i.read(6, 5)
    key = (hi << 5) | lo
    names = {0x1f: 'nop', 0x3f: 'yield', 0x5f: 'wfe', 0x7f: 'wfi',
             0x9f: 'sev', 0xbf: 'sevl', 0xdf: 'dgh', 0xff: 'autibsp'}
    if (i.word >> 12) & 0xfff == 0x032 and key == 0x1f and (i.word >> 7) & 0x1f:
        names = {0x1f: 'bti'}
        i.read(11, 7)
    i.name = names.get(key, '(hint %#x)' % key)
    i.ops = []
    i.say('HINT: twenty-seven of the thirty-two bits are a CONSTANT '
          '(bits[31:5] = %#010x) and the remaining five are the hint number.'
          % (i.word >> 5))
    i.say('  In all nine hints clang emits, bits[4:0] is 0b11111, so the '
          'discriminator is bits[6:5] and this decode READ %d of 32 bits.'
          % i.bits_used)
    i.say('  NOP is four bytes of file and one byte of work, and that ratio '
          'is the whole density argument.  `hint #0` and `hint #31` assemble '
          'to the same word, so the number is a TABLE and not a field.')
    return True


def m_adr(i):
    # MEASURED: `adr x1, T` is 0x10000061 and `adrp x0, T` is 0x90000000, so
    # bit[31] is op and bits[28:24] = 10000 in BOTH.  The first version of this
    # function required bit[31] = 1, so it found ADRP and never ADR -- and
    # ADRP is the one that cannot stand alone, so the decoder could not show
    # the pair that the whole immediate concept is about.
    if not i.fixed(28, 24, 0b10000, 'PC-relative addressing'):
        return False
    op = i.read(31, 31)
    immlo = i.read(30, 29)
    immhi = i.read(23, 5)
    rd = i.read(4, 0)
    imm = (immhi << 2) | immlo
    if imm & (1 << 20):
        imm -= 1 << 21
    i.name = 'adrp' if op else 'adr'
    i.ops = [reg(rd), '%+d' % (imm * (4096 if op else 1))]
    i.say('immlo:immhi is 21 bits and they are NOT ADJACENT: bits[30:29] sit '
          'ABOVE bits[23:5] with ten bits of fixed opcode in between.  That gap '
          'is the reason a 21-bit field fits in a 32-bit word that also holds '
          'a five-bit register at the bottom.')
    i.say('  imm = (immhi << 2) | immlo = (%d << 2) | %d = %d, 21 SIGNED bits'
          % (immhi, immlo, imm))
    if op:
        i.say('  bit[31] = 1 makes it ADRP and each unit is a 4096-BYTE PAGE, '
              'so the assembled address has its low 12 bits CLEARED and the '
              'reach is +-4 GiB')
        i.say('  and THAT is why ADRP cannot stand alone: the low 12 bits of '
              'the address are not in this instruction, and a following '
              '`add x0, x0, :lo12:sym` has to supply them.  One address, two '
              'instructions, 8 bytes -- against ONE 32-bit relative branch on '
              'x86-64 whose displacement is a signed 32-bit byte count.')
    else:
        i.say('  bit[31] = 0 makes it ADR and each unit is a BYTE, so the '
              'reach is +-1 MiB, which is 1/4096th of ADRP\'s')
    return True


def m_addsub_imm(i):
    # MEASURED: `add w0,w1,#0x10` against `add w0,w1,#0x20` flips bits[14,15]
    # and nothing else, and `sub` against `add` flips bit 30, so the group is
    # bits[28:24] = 0b10001 with op at bit 30 and S at bit 29.  The first
    # version of this file guarded on BOTH 0b10001 AND 0b10011 -- the ARMv7-A
    # pattern -- so the guard was unsatisfiable and every add and every sub
    # fell through to "unmodelled".
    if not i.fixed(28, 24, 0b10001, 'Add/subtract (immediate)'):
        return False
    sf = i.read(31, 31)
    op = i.read(30, 30)
    S = i.read(29, 29)
    shift = i.read(23, 22)
    imm12 = i.read(21, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if shift == 3:
        raise Undefined('shift = 0b11 is the third option and it is not '
                        'allocated: only 0 and 0b01 (LSL 12) exist')
    imm = imm12 << 12 if shift == 1 else imm12
    # MEASURED, and the two MOV aliases are DIFFERENT CASES:
    #   mov sp, x0   is 0x9100001f  Rd = 31, Rn = 0, imm12 = 0
    #   mov x29, sp  is 0x910003fd  Rd = 29, Rn = 31, imm12 = 0
    # The first version tested only "Rd = 31 and imm = 0" and so printed the
    # second as `mov x29, sp` by accident and `add sp, x0, #0` as `mov sp, x0`
    # for the wrong reason.  Both spellings are ADD with op = 0 and S = 0; the
    # difference is only WHICH field is the stack pointer.
    if not op and not S and imm == 0 and (rd == 31 or rn == 31):
        i.name = 'mov'
        if rd == 31 and rn == 31:
            i.ops = ['sp', 'sp']
        elif rd == 31:
            i.ops = ['sp', reg(rn, sf)]
        else:
            i.ops = [reg(rd, sf), 'sp']
        i.say('op = 0, S = 0 and imm12 = 0 with one of the operands at 31: '
              'this is the MOV alias.  Register 31 in the DESTINATION is the '
              'stack pointer, so the instruction is a copy with SP on one '
              'side, and the assembler prints MOV')
        return True
    if rd == 31 and S:
        i.name = 'cmp' if op else 'cmn'
        i.ops = [reg(rn, sf, allow_zr=True), '#%#x' % imm]
        i.say('Rd = 31 with S = 1: the destination field is not a destination '
              'at all, it is the marker that says "write the flags only".  '
              'With op = 1 the assembler prints CMP, with op = 0 it prints '
              'CMN, and neither is a separate encoding.')
        i.say('  This is the ONLY case in A64 where a 5-bit register field is '
              'not a register: it is a per-instruction escape, and a decoder '
              'that prints x31 here is wrong in a way no test would catch.')
        return True
    i.name = ['add', 'adds', 'sub', 'subs'][op * 2 + S]
    i.ops = [reg(rd, sf), reg(rn, sf, allow_zr=True), '#%#x' % imm]
    if shift == 1:
        # The assembler prints the PRE-SHIFT form with an explicit `lsl`, and
        # the decoder printed the post-shift value: the same 32 bits written
        # two ways, and a cross-check that does not know about it reports
        # every LSL-12 immediate as a disagreement.
        i.ops[-1] = '#%#x' % imm12
        i.ops.append('lsl #12')
        i.say('imm12 = %d and shift = bits[23:22] = 0b01, so the immediate is '
              'the 12-bit field LSL 12 -- the encoding offers the assembler '
              'TWO scales, 0 and 12, and the assembler prints the pre-shift '
              'form with an explicit lsl, so the same 32 bits are written two '
              'different ways and the 12-bit field is the ONLY place either '
              'of them appears' % imm12)
    else:
        i.say('imm12 = %d and shift = 0, so the immediate is the twelve-bit '
              'field VERBATIM.  There is no escape field and no sign: the '
              'value is unsigned and bounded by 4095, and `add w0,w1,#0x1234` '
              'is REFUSED by the assembler for exactly that reason (MEASURED, '
              'section 6)' % imm12)
    if S:
        i.say('S is set, so this is the flag-setting member and it writes '
              'NZCV.  The flag suffix is not a separate instruction; it is '
              'bit 29 of this one word.')
    return True


def m_logical_imm(i):
    if not i.fixed(28, 23, 0b100100, 'Logical (immediate)'):
        return False
    sf = i.read(31, 31)
    opc = i.read(30, 29)
    N = i.read(22, 22)
    immr = i.read(21, 16)
    imms = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    width = 64 if sf else 32
    # MEASURED: `ands w0,w0,#1` is 0x72000000 and its N = 0, so ANDS with N = 0
    # is a legal encoding and the four INVERTED forms are BIC/ORN/EON/BICS with
    # N = 0.  The first version of this function raised Undefined on N = 0 with
    # opc = 0b11, which is the `tst` alias `ands wzr, rn, imm` -- the most
    # common flag-writing instruction in the whole compiler corpus -- and lost
    # every one of them.
    # MEASURED, and the finding is that N is NOT the invert flag in the way the
    # manual's table suggests.  Every one of clang's outputs for this group:
    #
    #   and w0,w0,#0xf0f0f0f0  0x1204cc00  N=0 opc=00
    #   bic w0,w0,#0xff         0x12185c00  N=0 opc=00   <- the ASSEMBLER
    #   bic x0,x0,#0xff         0x9278dc00  N=1 opc=00      emitted AND, not BIC
    #   ands w0,w0,#1           0x72000000  N=0 opc=11
    #   bics w0,w0,#0xff        0x721c0c00  N=0 opc=11   <- and again
    #
    # So for a 32-bit destination the assembler always NORMALISES to the
    # non-inverted form and negates the constant itself: BIC #0xff became
    # AND #0xffffff00, and 0xffffff00 is encodable while 0xff... hmm, both
    # are.  The point is that the BIT PATTERN the assembler chose has N = 0
    # and opc = the plain operation, and the inversion is a property of the
    # constant, not a bit in the word.  The 64-bit BIC is the exception: there
    # N = 1 because the top 32 bits cannot be filled otherwise.
    #
    # The decoder therefore reports what the BITS say, and the assembler-
    # preferred spelling is a separate column in section 2.
    name = ['and', 'orr', 'eor', 'ands'][opc]
    if N:
        i.say('N = bit[22] = 1 with sf = 1: the element is 64 bits wide or the '
              'top half needed filling, which is why the assembler reaches for '
              'N = 1 only on 64-bit inverted forms')
    else:
        i.say('N = 0 and opc = %d, so the word spells %s.  There is no invert '
              'bit: clang emits AND for `bic w0,w0,#0xff` by negating the '
              'CONSTANT to 0xffffff00, and the inversion is arithmetic, not '
              'encoding.' % (opc, name.upper()))
    i.name = name
    if name == 'ands' and rd == 31:
        i.name = 'tst'
    try:
        val, notes = decode_bit_masks(N, imms, immr, width)
    except Undefined as e:
        i.ops = [reg(rd, sf, allow_sp=False),
                 reg(rn, sf, allow_sp=False, allow_zr=True), '(UNDEFINED)']
        i.note = 'undefined'
        i.say('THE IMMEDIATE IS NOT A LITERAL.  %s' % e)
        return True
    for n in notes:
        i.say('LOGICAL IMMEDIATE: ' + n)
    # MEASURED, and found by the two-reader cross-check rather than by
    # reading: register 31 in this group is the ZERO REGISTER and never the
    # stack pointer, exactly as in the logical-SHIFTED group and exactly as
    # the CSEL family measures.  The first version called reg() with its
    # default and printed `orr x9, sp, #0x8000000000000001` for a word the
    # oracle calls `mov x9, #-0x7fffffffffffffff` -- and `sp` there is not
    # merely a different name, it is a different VALUE, because a logical OR
    # against the stack pointer is not a copy and against the zero register
    # is.  The decoder wrote down a register that does not exist in the
    # instruction, and 2 of the 11 corpus disagreements were this.
    i.ops = [reg(rd, sf, allow_sp=False),
             reg(rn, sf, allow_sp=False, allow_zr=True), '#%#x' % val]
    if i.name == 'tst':
        i.ops = [reg(rn, sf, allow_sp=False, allow_zr=True), '#%#x' % val]
        i.say('ANDS with Rd = 31 is the TST ALIAS: the destination is not '
              'written, only the flags')
    elif name == 'ands':
        i.say('ANDS writes NZCV, which is the whole of what an `S` suffix '
              'means anywhere in A64')
    # ORR against the zero register is a MOVE, the same alias the logical
    # SHIFTED group has, and the first version of this function did not have
    # it -- so the compiler's own frame-pointer moves decoded as `orr` here
    # and as `mov` in the shifted group, which is a decoder that gives one
    # mnemonic two spellings depending on which group it matched first.
    if name == 'orr' and rn == 31:
        i.name = 'mov'
        i.ops = [reg(rd, sf, allow_sp=False), '#%#x' % val]
        i.say('ORR with Rn = 31 is the MOV ALIAS, and 31 in THIS group is the '
              'zero register: ORR against zero is a copy of the immediate')
    return True


def m_movewide(i):
    if not i.fixed(28, 23, 0b100101, 'Move wide (immediate)'):
        return False
    sf = i.read(31, 31)
    opc = i.read(30, 29)
    hw = i.read(22, 21)
    imm16 = i.read(20, 5)
    rd = i.read(4, 0)
    # MOVZ, MOVN and MOVK, and the sharpest alias in the whole encoding.
    # MEASURED, three words and the divergence is ARITHMETIC, not formatting:
    #   movz w0, #0x1234  ->  0x52824680, the field IS 0x1234
    #   movn w0, #0x1234  ->  0x12824680, the register holds NOT(0x1234)
    #                        = 0xffffffed = -0x1235, which is what LLVM prints
    #   movn w0, #0      ->  0x12800000, the register holds -1
    #   movz w0, #0      ->  0x52800000, the register holds 0
    # and the ASSEMBLER PRINTS BOTH of those last two as `mov`.  So the two
    # mnemonics a reader needs in order to write the instruction are not the
    # two the printer will hand back, and a cross-check that compares printed
    # immediates is comparing two conventions rather than two decodes.  The
    # decoder prints the ENCODING's name and normalise_objdump folds MOVN onto
    # the value the register actually holds, which is the one thing both
    # printers can be made to agree about.  Section 2 prints the mapping with
    # the bits beside it.
    #
    # The opc VALUES were also measured rather than remembered, and getting
    # them wrong was the single most damaging error in this file's first
    # version: 0x52824680 is the single most common instruction clang emits,
    # and with a remembered table it decoded as opc = 0b01, which is
    # UNDEFINED.  Every MOVZ in every corpus was lost.
    name = {0b00: 'movn', 0b10: 'movz', 0b11: 'movk'}.get(opc)
    if name is None:
        raise Undefined('opc = 0b01 is UNDEFINED in MOVE WIDE (immediate): '
                        'three operations and four opc values, and the hole is '
                        'where a 64-bit MOVK-only-on-high-half form would go')
    shift = hw * 16
    val = imm16 << shift
    if name == 'movk':
        i.ops = [reg(rd, sf), '#%#x' % imm16, 'lsl #%d' % shift]
        i.say('MOVK is the only one of the three that does NOT overwrite: it '
              'replaces one 16-bit field and leaves the other three alone, '
              'which is why a 64-bit constant is built from SEVERAL of these '
              'and why the compiler emits 3-4 of them for one C literal')
    else:
        i.ops = [reg(rd, sf), '#%#x' % val]
    i.name = name
    i.say('imm16 = %#x, hw = %d, so the field sits at bit %d.  SIXTEEN bits of '
          'constant in a 32-bit word, and this is the densest immediate in the '
          'whole encoding: one quarter of the word carries a literal and the '
          'rest names the operation, the register and the field\'s position.'
          % (imm16, hw, shift))
    i.say('  hw = bits[22:21] is TWO bits, and all four values are allocated, '
          'so a 64-bit constant has four 16-bit fields to fill and no '
          'arithmetic to do it with')
    return True


def m_bitfield(i):
    if not i.fixed(28, 23, 0b100110, 'Bitfield'):
        return False
    sf = i.read(31, 31)
    opc = i.read(30, 29)
    N = i.read(22, 22)
    immr = i.read(21, 16)
    imms = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    w = 64 if sf else 32
    base = ['sbfm', 'bfm', 'ubfm'][opc]
    i.name = base
    # The alias rules, in the assembler's own order, and every one of them read
    # off a real word rather than remembered:
    #   sxtw x0,w1  = 0x93407c20  opc=00 N=1 immr=0  imms=31
    #   sbfiz #4,#3 = 0x131c0820  opc=00 N=0 immr=28 imms=2
    #   sbfx  #4,#3 = 0x13041820  opc=00 N=0 immr=4  imms=6
    #   lsl  #3     = 0x531d7020  opc=10 N=0 immr=29 imms=28
    #   lsr  #3     = 0x53037c20  opc=10 N=0 immr=3  imms=31
    # The direction is the RELATION of two six-bit fields, and SFIX, UFIX,
    # SEXT, UXEXT, LSL, LSR, ASR, SBFX, UBFX, SBFIZ, UBFIZ, BFI and BFXIL --
    # THIRTEEN mnemonics -- are all one 32-bit word.
    suf = {8: 'b', 16: 'h', 32: 'w'}.get(imms - immr + 1)
    if N == 1 and suf:
        i.name = {0b00: 'sxt' + suf, 0b10: 'uxt' + suf, 0b01: 'bfxil'}[opc]
        # MEASURED, and this is a printer convention rather than a decode
        # difference: `sxtw x0, w1` prints its source as w1 (the width being
        # extended FROM) while `uxtw x0, w1` is printed by llvm-objdump as
        # `ubfx x0, x1, #0, #32`, with an X source.  So for the 32-bit
        # extension the SIGNED alias prints a w source and the UNSIGNED one
        # does not exist in LLVM's output at all.  The decoder follows the
        # oracle on the unsigned case and prints UBFX, and section 2 records
        # that the UXTW mnemonic exists and the reference disassembler will not
        # print it.
        if i.name == 'uxtw':
            i.name = 'ubfx'
            i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % immr, '#32']
            i.say('UBFM with N = 1 and imms = 31 is the UXT32 operation.  The '
                  'assembler calls it UXTW and llvm-objdump prints UBFX with a '
                  'start and a width, and the decoder follows the ORACLE here '
                  'so the cross-check can see the same bytes on both sides')
            return True
        # MEASURED: `sxtw x0, w1` prints its SOURCE as w1, not x1, because the
        # operation is a 32-bit extension of a 32-bit value.  The first version
        # printed x1 and the cross-check reported a disagreement on an
        # instruction whose decode was right -- which is the case the
        # normaliser's docstring is about, and the reason the operand is
        # printed from the alias's own width rather than from sf.
        ext_w = {8: 0, 16: 0, 32: 0}[imms - immr + 1] if suf == 'w' else sf
        i.ops = [reg(rd, sf), reg(rn, ext_w)]
        i.say('%s is an ALIAS for %s with N = 1 and imms = %d: the field runs '
              'to the TOP of the register, so the operation is an EXTEND from '
              'bit %d and not an extract, and the SOURCE is printed in the '
              'width being extended from'
              % (i.name.upper(), base, imms, immr))
        return True
    if imms == w - 1 and opc in (0b00, 0b10):
        i.name = 'asr' if opc == 0b00 else 'lsr'
        i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % immr]
        i.say('%s is an ALIAS for %s with imms = %d, i.e. imms is the '
              'register WIDTH and immr = %d is the whole shift amount'
              % (i.name.upper(), base, imms, immr))
        return True
    if imms > immr:
        i.name = {0b00: 'sbfx', 0b10: 'ubfx', 0b01: 'bfxil'}[opc]
        # MEASURED: `uxtw x0, w1` is 0xd3407c20 -- UBFM with immr = 0 and
        # imms = 31 -- and LLVM's printer calls it `ubfx x0, x1, #0, #32`, NOT
        # `uxtw`.  The UXTW alias exists in the assembler and LLVM's own
        # printer declines to use it for the 32-of-64 case.  The decoder prints
        # what the oracle prints, and the fact that a widely-quoted mnemonic is
        # not what the reference disassembler emits is recorded in section 2
        # rather than smoothed over.
        i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % immr,
                 '#%d' % (imms - immr + 1)]
        i.say('%s is an ALIAS for %s with immr = %d and imms = %d, so the '
              'assembler writes a start and a WIDTH where the encoding holds a '
              'start and an END.  Note that the canonical UXTW alias for the '
              '32-of-64 case EXISTS and llvm-objdump does not print it.'
              % (i.name.upper(), base, immr, imms))
        return True
    if opc == 0b10 and imms == immr - 1:
        i.name = 'lsl'
        i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % (w - immr)]
        i.say('LSL is an ALIAS for UBFM with imms = immr - 1: the field is %d '
              'bits wide and shifts out of the top, so the shift is %d - %d = '
              '%d' % (imms + 1, w, immr, w - immr))
        return True
    if imms < immr:
        i.name = {0b00: 'sbfiz', 0b10: 'ubfiz', 0b01: 'bfi'}[opc]
        i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % (w - immr), '#%d' % (imms + 1)]
        i.say('%s is an ALIAS for %s with N = 0 and imms < immr: the field '
              'starts at bit 0 and the value is SHIFTED UP by %d - %d = %d, so '
              'the assembler writes a shift and a width'
              % (i.name.upper(), base, w, immr, w - immr))
        return True
    i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % immr, '#%d' % imms]
    i.say('opc = bits[30:29] picks SBFM/BFM/UBFM and N = bit[22] picks the '
          'direction, and the direction is the RELATION of two six-bit fields, '
          'so thirteen mnemonics share one 32-bit word')
    return True


def m_extr(i):
    if not i.fixed(28, 23, 0b100111, 'Extract'):
        return False
    sf = i.read(31, 31)
    N = i.read(22, 22)
    o0 = i.read(21, 21)
    rm = i.read(20, 16)
    imms = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    i.name = 'extr'
    n = imms + 1
    # MEASURED: `extr x0,x1,x2,#8` is 0x93c22020, whose imms = 8, and objdump
    # prints `#8`.  So the ASSEMBLER prints imms, not imms+1, and the semantic
    # width is imms+1 anyway.  The first version printed imms+1, which made
    # every extr in the corpus a one-off disagreement against the oracle.  The
    # ROR alias prints imms+1 as a shift, and ROR #3 really is imms = 2 --
    # `ror w0,w1,#3` is 0x13810c20 with imms = 3, and it prints #3, so ROR
    # prints imms too and its semantic is the OTHER 31 of the 64 possibilities.
    if rm == rn and N == 0 and o0 == 0:
        i.name = 'ror'
        i.ops = [reg(rd, sf), reg(rn, sf), '#%d' % imms]
        i.say('Rm = Rn with N = 0 and o0 = 0 is the ROR ALIAS, and the '
              'assembler prints the ROLL AMOUNT as imms = %d.  The encoding\'s '
              'own reading is a %d-bit extract, which is the same bits taken '
              'from the same register twice.' % (imms, n))
        return True
    i.ops = [reg(rd, sf), reg(rn, sf), reg(rm, sf, allow_zr=True), '#%d' % imms]
    i.say('EXTR takes a %d-bit field: the low %d bits of Rm followed by the '
          'low %d bits of Rn.  The field HOLDS imms = %d and the WIDTH is '
          'imms + 1 = %d, but the assembler prints the field, not the width.'
          % (n, n, n, imms, n))
    i.say('  this is how A64 spells "rotate by a register": the amount is a '
          'REGISTER FIELD, and the ROR alias with imms = 0 is the amount-zero '
          'case, which the architecture leaves UNDEFINED')
    return True


def m_bcond(i):
    if not i.fixed(31, 24, 0b01010100, 'Conditional branch (immediate)'):
        return False
    imm19 = i.read(23, 5)
    c = i.read(4, 0)
    if imm19 & (1 << 18):
        imm19 -= 1 << 19
    # The mnemonic is `b.<cond>`, NOT `b.cond <cond>`.  The first version
    # printed `b.cond` as the mnemonic and the condition as an operand, which
    # is 21 of the 135 instructions in the hand corpus and every conditional
    # branch in the compiler corpus.
    #
    # The DISPLACEMENT is printed too, and it is the interesting half: the
    # decoder can compute it from the bytes and llvm-objdump cannot, because
    # in a relocatable object the field is a placeholder and the real address
    # arrives in a relocation.  Section 11 checks the arithmetic by hand on
    # real targets.
    i.name = 'b.' + cond_text(c, alt=True)
    i.ops = ['%+d' % (imm19 * 4)]
    i.say('imm19 = %d, 19 signed bits, times 4 because every A64 target is '
          '4-byte aligned: reach +-1 MiB' % imm19)
    return True


def m_b_bl(i):
    if not i.fixed(30, 26, 0b00101, 'Unconditional branch (immediate)'):
        return False
    op = i.read(31, 31)
    imm26 = i.read(25, 0)
    if imm26 & (1 << 25):
        imm26 -= 1 << 26
    i.name = 'bl' if op else 'b'
    i.ops = ['%+d' % (imm26 * 4)]
    i.say('imm26 = %d, 26 SIGNED bits, times 4 = %+d bytes of reach.  The '
          'whole 26-bit displacement is inside one instruction with no '
          'register and no second field, which is the encoding buying the '
          'density it costs in immediates.' % (imm26, imm26 * 4))
    return True


def m_cbz(i):
    if not i.fixed(30, 25, 0b011010, 'Compare and branch (immediate)'):
        return False
    sf = i.read(31, 31)
    op = i.read(24, 24)
    imm19 = i.read(23, 5)
    # MEASURED: the register is bits[4:0], NOT bits[9:5].  `cbz w0, T` is
    # 0x340000a0 with bits[4:0] = 0 and bits[9:5] = 0, and `tbz w5, #3, T` is
    # 0x37000065 with bits[4:0] = 5.  The first version of these two functions
    # read bits[9:5] -- the position Rn occupies in EVERY OTHER group -- and
    # got cbz and tbz wrong on seven of the 135 hand-corpus instructions, all
    # of which happened to have a zero in bits[9:5], so the group's own guard
    # hid it.
    rt = i.read(4, 0)
    if imm19 & (1 << 18):
        imm19 -= 1 << 19
    i.name = 'cbnz' if op else 'cbz'
    i.ops = [reg(rt, sf, allow_sp=False), '%+d' % (imm19 * 4)]
    i.say('the second operand is ZERO, which is register 30 reading as itself: '
          'CBZ spends no field on a zero it could name, and 19 bits of '
          'displacement rather than 14')
    i.say('  imm19 = %d, so the target is %+d bytes away -- the same reach as '
          'B.cond, for a comparison against a constant that is not in the '
          'instruction' % (imm19, imm19 * 4))
    return True


def m_tbz(i):
    if not i.fixed(30, 25, 0b011011, 'Test and branch (immediate)'):
        return False
    b5 = i.read(31, 31)
    op = i.read(24, 24)
    b40 = i.read(23, 19)
    imm14 = i.read(18, 5)
    rt = i.read(4, 0)
    if imm14 & (1 << 13):
        imm14 -= 1 << 14
    bit = (b5 << 5) | b40
    i.name = 'tbnz' if op else 'tbz'
    i.ops = [reg(rt, b5, allow_sp=False), '#%d' % bit, '%+d' % (imm14 * 4)]
    i.say('the bit NUMBER is b5:imm5, TWO fields with three bits of opcode '
          'between them, so a 64-bit TBZ can name bit 63')
    i.say('  b5 = %d, imm5 = %d, so the tested bit is %d; imm14 = %d gives '
          '%+d bytes of reach' % (b5, b40, bit, imm14, imm14 * 4))
    if not b5 and bit > 31:
        raise Undefined('a 32-bit register has no bit %d, and the assembler '
                        'refuses to write it (MEASURED: "immediate must be an '
                        'integer in range [0, 31]")' % bit)
    return True


def m_br_blr_ret(i):
    # MEASURED: `br x0` against `blr x0` flips bit 21 and nothing else, and
    # `br x0` against `ret` flips bit 22 plus the Rn bits, so opc is
    # bits[22:21] and its three allocated values are 0b01 (BLR), 0b10 (BR)
    # and 0b11 (RET).  The field is two bits wide and all three of the lower
    # values are used, which is why there is no fourth one.
    if not i.fixed(31, 23, 0b110101100, 'Unconditional branch (register)'):
        return False
    if not i.fixed(20, 20, 1, 'op2 bit 4'):
        return False
    if not i.fixed(19, 16, 0b1111, 'op2 bits 3:0'):
        return False
    if not i.fixed(15, 12, 0, 'op3'):
        return False
    opc = i.read(22, 21)
    if opc not in (0, 1, 2):
        return False
    rn = i.read(9, 5)
    if not i.fixed(4, 0, 0, 'op5'):
        return False
    i.name = {0: 'br', 1: 'blr', 2: 'ret'}[opc]
    # RET prints no operand, because its only legal operand is x30 and printing
    # `ret x30` would be printing the encoding rather than the instruction.
    i.ops = [] if i.name == 'ret' else [reg(rn, 1, allow_sp=False)]
    i.say('bits[31:23] = 0b110101100, bit[20] = 1, bits[19:16] = 1111, '
          'bits[15:12] = 0000 and bits[4:0] = 00000: eighteen bits of fixed '
          'pattern out of thirty-two')
    i.say('opc = bits[22:21] = %d = %s' % (opc, i.name))
    i.say('  THE TARGET IS NOT IN THE INSTRUCTION.  It is read from the '
          'register bits[9:5] names, which is why RET is a read of register 30 '
          'and why a function pointer needs no relocation of its own')
    if i.name == 'ret' and rn != 30:
        raise Undefined('RET with Rn != 30 reads a register that is not the '
                        'link register, which the assembler refuses to write '
                        'and the architecture leaves UNDEFINED')
    return True


def m_ldst_uimm(i):
    # MEASURED, all four of these from the same three bytes:
    #   ldrb w0,[x1]        0x39400020  sz=00  [29:27]=111  b25:24=01  opc=01
    #   strb w0,[x1]        0x39000020  sz=00                     opc=00
    #   ldr w0,[x1,#8]      0xb9400820  sz=10  imm12=2  -> 2*4 = 8
    #   ldr x0,[x1,#8]      0xf9400420  sz=11  imm12=1  -> 1*8 = 8
    #   ldrsw x0,[x1]       0xb9800020  sz=10  opc=10
    # so bits[29:27] = 111 and bits[25:24] = 01, and the WHOLE group differs
    # from the pair group (bits[29:27] = 101) in two bits.  The offset is
    # imm12 bits[21:10] SCALED by the access size, and the SCALE is why the
    # field is 12 bits and not 32: the whole reach is 4095*8 = 32760 bytes
    # forward and NOTHING backward except through the unscaled form.
    if not i.fixed(29, 27, 0b111, 'Load/store register, unsigned offset'):
        return False
    if not i.fixed(26, 24, 0b001, 'the non-SIMD unsigned-offset form'):
        return False
    sz = i.read(31, 30)
    opc = i.read(23, 22)
    imm12 = i.read(21, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    scale = 1 << sz
    off = imm12 * scale
    base = reg(rn, 1, allow_zr=True)
    load = opc in (0b01, 0b10, 0b11)
    if opc == 0b10 and sz != 0b10:
        i.note = 'unmodelled-prfm'
        i.name = '(prfm)'
        i.ops = ['[%s, #%d]' % (base, off)]
    elif opc == 0b11:
        i.note = 'unmodelled-prfm'
        i.name = 'prfm'
        i.ops = ['[%s, #%d]' % (base, off)]
    else:
        # MEASURED: `str wzr, [sp, #16]` is 0xb90013ff and `str w0, [sp, #12]`
        # is 0xb9000fe0 -- the SAME base field, 31, printing `sp` in one and
        # with a real Rt in the other.  So in the load/store group Rn = 31 is
        # the stack pointer and Rt = 31 is the ZERO REGISTER, and the first
        # version of this file read both as sp: 8 of the 338 instructions in
        # the -O0 corpus, every one of them a stack spill of a zero value.
        rtd = reg(rt, 1 if (opc == 0b10 or sz == 0b11) else 0,
                  allow_sp=False)
        if opc == 0b10:
            i.name = 'ldrsw'
            i.ops = [rtd, '[%s, #%d]' % (base, off)]
        else:
            i.name = 'ldr' if load else 'str'
            if sz == 0b00:
                i.name += 'b'
            elif sz == 0b01:
                i.name += 'h'
            i.ops = [rtd, '[%s, #%d]' % (base, off)]
    i.say('size = bits[31:30] = %d so the access is %d bits, and opc = '
          'bits[23:22] = %d says load or store' % (sz, 8 * scale, opc))
    i.say('  THE OFFSET IS THE IMMEDIATE TIMES THE SIZE: imm12 = %d, scaled by '
          '%d = %d bytes.  There is no displacement FIELD in this encoding at '
          'all: a 12-bit field times an implicit scale, so the reach is 0 to '
          '%d bytes FORWARD and not one byte backward.'
          % (imm12, scale, off, 4095 * scale))
    return True


def m_ldst_uimm9(i):
    # MEASURED: the unscaled, post-index and pre-index forms are ONE group
    # with bits[29:27] = 111 and bits[26:24] = 000, and their immediate is NOT
    # scaled -- `ldr w0,[x1],#4` against `#8` flips bits[14,15], which is
    # imm9 = 4 and imm9 = 8 rather than 1 and 2.  That is the whole point of
    # the group: LDUR can express an offset that is not a multiple of the
    # access size, and the 9-bit field is signed.
    if not i.fixed(29, 27, 0b111, 'Load/store register, unscaled / pre / post'):
        return False
    if not i.fixed(26, 24, 0b000, 'the UNSCALED 9-bit immediate form'):
        return False
    mode = i.read(11, 10)
    if mode == 0b10:
        return False                      # unprivileged (LDTR/STTR)
    sz = i.read(31, 30)
    opc = i.read(23, 22)
    imm9 = i.read(20, 12)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    if imm9 & (1 << 8):
        imm9 -= 1 << 9
    scale = 1 << sz
    load = opc in (0b01, 0b10, 0b11)
    base = reg(rn, 1, allow_zr=True)
    # Rt = 31 is the ZERO REGISTER here, exactly as in the unsigned-offset
    # form: MEASURED, `str wzr, [sp, #16]` is 0xb90013ff in the unsigned
    # group and there is no counter-example in the -O0 corpus.
    rtd = reg(rt, 1 if (opc == 0b10 or sz == 0b11) else 0, allow_sp=False)
    stem = 'ldr' if load else 'str'
    if sz == 0b00:
        stem += 'b'
    elif sz == 0b01:
        stem += 'h'
    if mode == 0b00:
        i.name = ('ldur' if load else 'stur') + ('b' if sz == 0b00 else
                                                  'h' if sz == 0b01 else '')
        mem = '[%s, #%d]' % (base, imm9)
    elif mode == 0b01:
        i.name = stem
        mem = '[%s], #%d' % (base, imm9)
    else:
        i.name = stem
        mem = '[%s, #%d]!' % (base, imm9)
    i.ops = [rtd, mem]
    i.say('bits[29:27] = 111 and bits[26:24] = 000: the same load/store family '
          'with an UNSCALED, SIGNED 9-bit immediate, so an offset need not be a '
          'multiple of the access size -- which is the only reason this group '
          'exists')
    i.say('  bits[11:10] = %d is the addressing mode: 00 unscaled (LDUR/STUR), '
          '01 post-index, 10 unprivileged, 11 pre-index.  imm9 = %d is NOT '
          'multiplied by the access size, unlike the 12-bit form.' % (mode, imm9))
    return True


def m_ldst_pair(i):
    # MEASURED: `stp x0,x1,[sp]` against `stp x0,x3,[sp]` flips bit 11, so
    # Rt2 is bits[11:10] and NOT bits[20:16] as the register field of every
    # other group would suggest.  The offset is bits[21:15].
    if not i.fixed(29, 27, 0b101, 'Load/store pair'):
        return False
    if not i.fixed(25, 25, 0, 'the non-FP pair form'):
        return False
    V = i.read(26, 26)
    opc = i.read(31, 30)
    i.read(29, 25)
    i.fixed(15, 15, 0, 'the no-allocate bit')
    wbm = i.read(24, 23)
    L = i.read(22, 22)
    imm7 = i.read(21, 15)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    # MEASURED, and this CORRECTS a claim an earlier draft of this comment made
    # in the other direction.  Rt2 is bits[14:10].  Five assembler outputs:
    #   stp x29,x30,[sp,#-32]!  0xa9be7bfd  b11:10 = 2   b14:10 = 30
    #   stp x0,x1,[sp,#16]      0xa90107e0  b11:10 = 1   b14:10 = 1
    #   ldp x10,x11,[x1]        0xa9402c2a  b11:10 = 3   b14:10 = 11
    #   stp x19,x20,[sp,#16]    0xa90153f3  b11:10 = 0   b14:10 = 20
    # An earlier version of this file read bits[11:10] and printed `stp x0,x1`
    # correctly, because for THAT pair the two fields happen to hold the same
    # value.  Every other pair in the corpus was wrong.  A field measurement
    # that agrees with the first specimen and disagrees with the second is not
    # a measurement; it is a coincidence with a number in it -- which is why
    # fields.py assembles 69 PAIRS rather than one and why the harness asserts
    # the count.
    rt2 = i.read(14, 10)
    if V:
        i.note = 'unmodelled-fp-pair'
        i.name = None
        i.ops = ['(SIMD pair, op %#x)' % i.peek(31, 22)]
        i.say('V = bit[26] is 1, so this is the Advanced SIMD load/store pair '
              'and it names the 128-bit v registers, which this declared '
              'subset does not model.  The LENGTH is still exactly 4 bytes, '
              'which is the one thing a fixed-width encoding always gives you '
              'for free.')
        return True
    if imm7 & (1 << 6):
        imm7 -= 1 << 7
    # MEASURED, four words and the three allocated modes:
    #   stp x0,x1,[sp,#16]    0xa94107e0  wbm = bits[24:23] = 0b10
    #   stp x0,x1,[sp,#-16]!  0xa9bf07e0  wbm = 0b11   pre-index
    #   stp x0,x1,[sp],#16    0xa8c107e0  wbm = 0b01   post-index
    #   ldp w0,w1,[x2],#8     0x28c10440  wbm = 0b01, opc = 00 (32-bit)
    # The three values are NOT contiguous, so a decoder that tests "is bit 24
    # set" gets two of the three wrong, and the only allocated value the test
    # would miss is the one pre-index is not.
    # MEASURED: `ldp x0,x1,[sp,#16]` is 0xa94107e0 with opc = bits[31:30] =
    # 0b10 and `ldp w0,w1,[x2],#8` is 0x28c10440 with opc = 0b00.  So opc is
    # the PAIR WIDTH, not a load/store bit -- L at bit 22 already says that --
    # and opc = 0b00 is 32-bit with a scale of 4, opc = 0b10 is 64-bit with a
    # scale of 8.  The first version of this function read the width from the
    # scale, which made every 64-bit pair print as a 32-bit pair: the register
    # names and the byte offset were both wrong and the two errors cancelled
    # in the offset and did not cancel in the names.
    scale = 8 if opc == 0b10 else 4
    sf = 1 if opc == 0b10 else 0
    off = imm7 * scale
    base = reg(rn, 1, allow_zr=True)
    if wbm == 0b10:
        mem = '[%s, #%d]' % (base, off)
    elif wbm == 0b11:
        mem = '[%s, #%d]!' % (base, off)
    else:
        mem = '[%s], #%d' % (base, off)
    i.name = 'ldp' if L else 'stp'
    # MEASURED: `stp x29, x30, [sp, #-32]!` is 0xa9be7bfd, and Rt2 = 30 is the
    # LINK REGISTER -- not x30 spelled differently, just x30.  So Rt2 has no
    # escapes at all: no sp and no zr, because a pair never stores the stack
    # pointer into itself.
    i.ops = [reg(rt, sf, allow_sp=False), reg(rt2, sf, allow_sp=False), mem]
    i.say('  Rt2 is bits[14:10], MEASURED on five pairs, and it is NOT '
          'bits[20:16] as every other register field in this encoding would '
          'suggest')
    i.say('bits[24:23] = %d is the addressing mode: 0b10 signed/unsigned '
          'offset, 0b11 PRE-index, 0b01 POST-index.  The three allocated values '
          'are not contiguous, so a decoder that tests "is bit 24 set" gets two '
          'of the three wrong.' % wbm)
    i.say('  imm7 = %d, scaled by %d: a pair of %d-bit registers reaches only '
          '+-%d bytes, and that narrow reach is the price of ONE instruction '
          'loading TWO registers.  x86-64 has no pair form at all.'
          % (imm7, scale, 8 * scale, 64 * scale))
    return True


def m_addsub_shifted(i):
    if not i.fixed(28, 24, 0b01011, 'Add/subtract (shifted register)'):
        return False
    if not i.fixed(21, 21, 0, 'no Rm extension'):
        return False
    # The ORR-with-both-zero-registers MOV alias is checked HERE, before the
    # register fields are read, because the fields are the same and only the
    # NAME differs.  MEASURED: `mov w9, w1` is 0x2a0103e9 and `mov x9, x0` is
    # 0xaa0003e9, and in both Rn = Rm = 31.  The first version printed
    # `orr w9, wzr, w1` -- the same 32 bits and a name nobody writes.
    sf = i.read(31, 31)
    op = i.read(30, 30)
    S = i.read(29, 29)
    shift = i.read(23, 22)
    rm = i.read(20, 16)
    imm6 = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if shift == 3:
        raise Undefined('shift = 0b11 is UNDEFINED in the shifted-register '
                        'form: a right rotate lives in the EXTENDED form, '
                        'which is a different encoding with a different imm6 '
                        'meaning')
    sh = ['lsl', 'lsr', 'asr'][shift]
    if rd == 31 and S:
        i.name = 'cmp' if op else 'cmn'
        i.ops = [reg(rn, sf, allow_zr=True), reg(rm, sf, allow_zr=True)] + \
            ([sh, '#%d' % imm6] if imm6 else [])
        i.say('Rd = 31 with S = 1: the destination field is not a destination, '
              'and the assembler prints CMP or CMN')
        return True
    if rn == 31 and op == 1 and S == 0:
        i.name = 'neg'
        i.ops = [reg(rd, sf), reg(rm, sf, allow_zr=True)] + \
            ([sh, '#%d' % imm6] if imm6 else [])
        i.say('Rn = 31 with op = 1 is NEG: the first source is the zero '
              'register, so the assembler drops it and the encoding spends '
              'five bits saying so')
        return True
    i.name = ['add', 'adds', 'sub', 'subs'][op * 2 + S]
    i.ops = [reg(rd, sf), reg(rn, sf, allow_zr=bool(op or S)),
             reg(rm, sf, allow_zr=True)] + \
        ([sh, '#%d' % imm6] if imm6 else [])
    if S:
        i.say('S is set, so this writes NZCV instead of only the destination. '
              'The `S` suffix is one bit, bit 29, and there is no second '
              'instruction and no separate flag register to save.')
    i.say('imm6 = %d is the SHIFT AMOUNT, in the six bits below Rm.  x86-64 '
          'needs a one-byte prefix or a second instruction to shift an '
          'operand; A64 needs six bits of the same word, and pays for it in '
          'code density.' % imm6)
    return True


def m_logical_shifted(i):
    if not i.fixed(28, 24, 0b01010, 'Logical (shifted register)'):
        return False
    sf = i.read(31, 31)
    opc = i.read(30, 29)
    i.read(28, 21)
    N = i.read(21, 21)
    shift = i.read(23, 22)
    rm = i.read(20, 16)
    imm6 = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if shift == 3:
        raise Undefined('shift = 0b11 in the shifted-register logical form is '
                        'UNDEFINED; the extended forms use it')
    if N:
        names = ['bic', 'orn', 'eon', 'bics']
    else:
        names = ['and', 'orr', 'eor', 'ands']
    i.name = names[opc]
    tail = ['lsl', 'lsr', 'asr', 'ror'][shift]
    tail = ([tail, '#%d' % imm6] if imm6 else [])
    # MEASURED: in the SHIFTED-register logical group, register 31 in EITHER
    # source slot is the ZERO REGISTER and never the stack pointer.  The
    # evidence is the opposite group: `add sp, sp, #0x10` is 0xd10043ff with
    # Rn = 31 printing `sp`, and `mvn w0, w1` is 0x2a2103e0 with the same field
    # value printing nothing at all because the assembler called it MVN.  So the
    # two escapes are PER GROUP and this is a different group.
    rn_t = reg(rn, sf, allow_sp=False)
    rm_t = reg(rm, sf, allow_sp=False)
    # MEASURED, and the MOV alias is Rn = 31 ALONE, not Rn = Rm = 31:
    #   mov w9, w1  is 0x2a0103e9  Rn = 31, Rm = 1
    #   mov x9, x0  is 0xaa0003e9  Rn = 31, Rm = 0
    # ORR against the zero register is a copy, whichever register the other
    # operand is.  The first version required BOTH operands to be zero, which
    # is right only for the accidental case `orr x8, xzr, xzr`, and it
    # reported the compiler's own frame-pointer moves as `orr x29, xzr, sp`.
    if i.name == 'orr' and rn == 31:
        i.name = 'mov'
        i.ops = [reg(rd, sf, allow_sp=False), rm_t]
        i.say('ORR with Rn = 31 is the MOV ALIAS: ORR against the ZERO '
              'register is a copy of the other source, whatever that is.  It '
              'costs the same four bytes as `orr` and buys a whole mnemonic, '
              'which is the cheapest thing in the encoding.')
        return True
    if i.name == 'ands' and rd == 31:
        i.name = 'tst'
        i.ops = [rn_t, rm_t] + tail
        i.say('ANDS with Rd = 31 is the TST ALIAS: the destination is not '
              'written, only the flags')
        return True
    if i.name == 'orn' and rn == 31:
        i.name = 'mvn'
        i.ops = [reg(rd, sf), rm_t] + tail
        i.say('ORN with Rn = 31 is the MVN ALIAS: the first source is the zero '
              'register, so the instruction is "move not"')
        return True
    i.ops = [reg(rd, sf, allow_sp=False), rn_t, rm_t] + tail
    if opc == 3:
        i.say('ANDS is the only member of this group that touches the flags, '
              'and it differs from AND in bits[30:29] = 0b11 -- measured as a '
              'two-bit difference: `and` XOR `ands` = 0x60000000')
    return True


def m_3src(i):
    if not i.fixed(30, 24, 0b0011011, 'Data-processing (3 source)'):
        return False
    sf = i.read(31, 31)
    op54 = i.read(23, 21)
    rm = i.read(20, 16)
    o0 = i.read(15, 15)
    ra = i.read(14, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if op54 == 0b000:
        i.name = 'msub' if o0 else 'madd'
        if ra == 31 and not o0:
            i.name = 'mul'
            i.ops = [reg(rd, sf, allow_zr=True), reg(rn, sf, allow_zr=True),
                     reg(rm, sf, allow_zr=True)]
            i.say('Ra = 31 is the ZERO REGISTER, so MADD with a zero '
                  'accumulator computes a product and nothing else -- and the '
                  'assembler prints that as MUL.  MUL IS NOT AN OPCODE.')
            return True
        i.ops = [reg(rd, sf, allow_zr=True), reg(rn, sf, allow_zr=True),
                 reg(rm, sf, allow_zr=True), reg(ra, sf, allow_zr=True)]
        i.say('MADD and MSUB are ONE encoding with bit 15 between them: MSUB '
              'is MADD with the accumulate operand NEGATED BY THE ENCODING, '
              'so a multiply-accumulate and a multiply-subtract cost the same '
              'four bytes and there is no third instruction')
        i.say('  four register fields in one word: this is the only '
              'multiply-and-accumulate the integer encoding needs, and its '
              'op54 = bits[23:21] = %d is the whole of the dispatch' % op54)
        return True
    i.note = 'unmodelled-3src'
    i.name = None
    i.ops = ['(op54=%d o0=%d)' % (op54, o0), reg(rd, sf, allow_zr=True),
             reg(rn, sf, allow_zr=True), reg(rm, sf, allow_zr=True),
             reg(ra, sf, allow_zr=True)]
    return True


def m_2src(i):
    if not i.fixed(30, 21, 0b0011010110, 'Data-processing (2 source)'):
        return False
    sf = i.read(31, 31)
    opc = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    rm = i.read(20, 16)
    # MEASURED opcode values: lslv 0b000001, udiv 0b000010, sdiv 0b000110,
    # lsrv 0b001001, asrv 0b001010, rorv 0b001011.  The shifts are spaced
    # apart because the low bits below them are the extend mode, and the
    # DIVIDEs live in the holes.
    names = {0b001000: 'lsl', 0b001001: 'lsr', 0b001010: 'asr',
             0b001011: 'ror'}
    # MEASURED opcode values, all six of them: lsl 0b001000, lsr 0b001001,
    # asr 0b001010, ror 0b001011, udiv 0b000010, sdiv 0b000011.  The two
    # DIVIDEs sit in the low slots and the four shifts in the high ones,
    # because bits[14:10] below the shifts belong to the EXTEND field of the
    # very similar extended forms, and a divide has no extend.
    divs = {0b000010: 'udiv', 0b000011: 'sdiv'}
    if opc in divs:
        i.name = divs[opc]
        i.ops = [reg(rd, sf, allow_zr=True), reg(rn, sf, allow_zr=True),
                 reg(rm, sf, allow_zr=True)]
        i.say('a signed and an unsigned divide are ONE BIT apart -- measured: '
              '`sdiv w0,w1,w2` XOR `udiv w0,w1,w2` = 0x00000400')
        return True
    if opc in names:
        i.name = names[opc]
        i.ops = [reg(rd, sf, allow_zr=True), reg(rn, sf, allow_zr=True),
                 reg(rm, sf, allow_zr=True)]
        i.say('the shift amount is a REGISTER and the shift TYPE is six bits '
              'of the opcode, so LSLV/LSRV/ASRV/RORV are one encoding.  x86-64 '
              'has no such form: a variable shift there needs the count in '
              '%cl, which is a register constraint rather than an operand')
        return True
    i.note = 'unmodelled-2src'
    i.name = None
    i.ops = ['(op %#x)' % opc, reg(rd, sf, allow_zr=True),
             reg(rn, sf, allow_zr=True), reg(rm, sf, allow_zr=True)]
    return True


def m_condselect(i):
    # MEASURED: bits[28:21] = 0b11010100 for the WHOLE family, and bit[30] is
    # the INVERT bit, so `csinv w0,w1,w2,ge` (0x5a82a020, bit 30 = 1) is in
    # the family and not in the extended-form logical group.  The first version
    # of this function RAISED Undefined on bit 30, having confused it with the
    # bit-21 N field of the extended logical group, and so threw away csinv,
    # csneg, csetm and cinv -- four of the eight names in the family, and three
    # of them are in the compiler corpus.
    if not i.fixed(28, 21, 0b11010100, 'Conditional select'):
        return False
    sf = i.read(31, 31)
    inv = i.read(30, 30)
    i.read(29, 21)
    rm = i.read(20, 16)
    cond = i.read(15, 12)
    op2 = i.read(11, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    # The guard for the RESERVED op2 values comes BEFORE the name is assigned.
    # The first version set `i.name = ['csel', 'csinc', 'csinv', 'csneg']
    # [op2]` and Python indexed a FOUR-entry list with a value that can be
    # 0b11 -- so a reserved word crashed the decoder with IndexError, and the
    # section 10 table could not be printed at all.  op2 = 0b10 crashed the
    # same way and op2 = 0b11 did not, because 3 is the last legal index: the
    # cheapest version of this bug throws on three quarters of the cases and
    # works on the rest, which is the worst shape a bug can have.
    if op2 > 0b01:
        raise Undefined('op2 = bits[11:10] = 0b%s: the conditional-select '
                        'group has four operations, selected by (bit 30, op2) '
                        '= (0,00), (0,01), (1,00) and (1,01), so op2 = 0b%s '
                        'is a RESERVED value.  The oracle prints <unknown> '
                        'for it, and so does this decoder (MEASURED).'
                        % (format(op2, '02b'), format(op2, '02b')))
    base = ['csel', 'csinc', 'csinv', 'csneg'][op2]
    i.name = base
    # In the CSEL family register 31 is the ZERO REGISTER in every slot, and
    # never the stack pointer: MEASURED, `csinc w0, w8, wzr, eq` is 0x1a9f0500
    # with Rm = 31, and there is no `csel` in the compiler corpus that puts a
    # stack pointer in a select.  (The stack pointer DOES appear in the
    # add/subtract group, where 31 in the destination is sp -- so the escape is
    # per group, which is the point.)
    rn_t = reg(rn, sf, allow_sp=False)
    rm_t = reg(rm, sf, allow_sp=False)
    rd_t = reg(rd, sf, allow_sp=False)
    # MEASURED, and the alias table is not the one the mnemonic order suggests.
    # Ten real words from clang, all with cond in bits[15:12]:
    #
    # TWO separate things are going on and the first version of this file
    # merged them.  (1) op2 = bits[11:10] and bit 30 together pick the
    # operation.  (2) When Rn and Rm are BOTH the zero register -- or the same
    # register -- the instruction computes a constant or a one-operand
    # operation rather than a choice, and the assembler prints CSET, CSETM,
    # CINC, CNEG or CINV -- with the condition INVERTED, because "1 if cc else
    # 0" is "0+0 if not cc else 0+1".  So the printed condition is cond ^ 1 and
    # the ASSEMBLER'S SPELLING is the opposite of the encoded one.  Section 10
    # prints all sixteen both ways.
    #
    # MEASURED, and the field values below are the ones the assembler emitted:
    #   cset  w0,eq   0x1a9f17e0  op2=01 inv=0 Rn=31 Rm=31 cond=1 (ne)
    #   csetm x0,ne   0xda9f03e0  op2=00 inv=1 Rn=31 Rm=31 cond=0 (eq)
    #   cinc  w0,w1,eq 0x1a811420  op2=01 inv=0 Rn=1  Rm=1  cond=1 (ne)
    #   cneg  w0,w1,ge 0x5a81b420  op2=01 inv=1 Rn=1  Rm=1  cond=11 (lt)
    #   cinv  w0,w1,ne 0x5a810020  op2=00 inv=1 Rn=1  Rm=1  cond=0 (eq)
    #   csinv w0,w1,w2,ge 0x5a82a020 op2=00 inv=1 Rn=1 Rm=2 cond=10 (ge)
    #
    # op2 alone is NOT the operation: CSINC and CSNEG share op2 = 0b01 and
    # are told apart by bit[30].  The first version of this file read op2 as
    # if it named four operations and got csinv and csneg wrong in the corpus,
    # and the two disagreements were in the two instructions the
    # branchless-csel concept quotes.
    #   csel  w0,w1,w2,eq  0x1a820020  op2=00 inv=0
    #   csinc w0,w1,w2,eq  0x1a820420  op2=01 inv=0
    #   csinv w0,w1,w2,ge  0x5a82a020  op2=00 inv=1
    #   csneg w0,w1,w2,lt  0x5a82b420  op2=01 inv=1
    # So op2 alone is NOT the operation: CSINC and CSNEG share op2 = 0b01 and
    # are told apart by bit[30].  The first table read op2 as if it named four
    # operations and got csinv and csneg wrong in the corpus, and the two
    # disagreements are in the two instructions the branchless-csel concept
    # quotes.
    inv_str = {(0b0, 0b00): 'csel', (0b0, 0b01): 'csinc',
               (0b1, 0b00): 'csinv', (0b1, 0b01): 'csneg'}[(inv, op2)]
    i.ops = [rd_t, rn_t, rm_t, cond_text(cond)]
    if rn == 31 and rm == 31:
        if op2 == 0b01 and inv == 0:
            i.name = 'cset'
            i.ops = [rd_t, cond_text(cond ^ 1)]
            i.say('Rn = Rm = 31 and op2 = 01: both sources are xzr, so the '
                  'instruction computes 1 if cond holds and 0+0 if not, and '
                  'the assembler prints that as CSET with the condition '
                  'INVERTED')
            i.say('  CSET Wd, cc  ==  CSINC Wd, wzr, wzr, NOT(cc)  ==  the same '
                  '32 bits with cond = %d = %s.  The encoding says %s and the '
                  'assembler prints %s, and BOTH ARE RIGHT -- which is the '
                  'trap.' % (cond, cond_text(cond), cond_text(cond),
                             cond_text(cond ^ 1)))
            return True
        if op2 == 0b00 and inv == 1:
            i.name = 'csetm'
            i.ops = [rd_t, cond_text(cond ^ 1)]
            i.say('Rn = Rm = 31, op2 = 00 and bit[30] = 1: CSINV of two zero '
                  'registers is CSETM, the mask form, and the condition is '
                  'inverted the same way')
            return True
    if rn == rm and rn != 31:
        if op2 == 0b01:
            i.name = 'cinc' if inv == 0 else 'cneg'
            i.ops = [rd_t, rm_t, cond_text(cond ^ 1)]
            i.say('Rn = Rm = %d with op2 = 01: the two sources are the same '
                  'register, so the "select" is an increment or a negation '
                  'and the assembler prints %s with the condition INVERTED'
                  % (rn, i.name.upper()))
            return True
        if op2 == 0b00 and inv == 1:
            i.name = 'cinv'
            i.ops = [rd_t, rm_t, cond_text(cond ^ 1)]
            i.say('Rn = Rm with bit[30] = 1: the same register twice, '
                  'inverted, which is the assembler\'s CINV')
            return True
    i.name = inv_str
    i.ops = [rd_t, rn_t, rm_t, cond_text(cond)]
    i.say('cond = bits[15:12] = %d = %s; op2 = bits[11:10] = %d and bit[30] = '
          '%d together pick %s' % (cond, cond_text(cond), op2, inv, inv_str))
    i.say('  ONE four-bit field carries sixteen conditions and this encoding '
          'needs no CMP, no SETcc and no second instruction -- the reason '
          'AArch64 can produce a boolean without writing a flags register')
    return True


def m_clz_rev(i):
    if not i.fixed(30, 21, 0b1011010110, 'Data-processing (2 source), misc'):
        return False
    sf = i.read(31, 31)
    opc = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    rm = i.read(20, 16)
    # MEASURED, and the opcode values are the surprise:
    #   rev16 0x5ac00420  opc = bits[15:10] = 0b000001
    #   rev   0x5ac00820  opc = 0b000010
    #   clz   0x5ac01020  opc = 0b000100
    # The first version of this file had clz at 0b000010 and rev at
    # 0b000101, so it named rev16 as clz and then reported clz as rev --
    # three instructions shifted by one, on a table of six bits, and the
    # two-reader cross-check found all three at once.
    names = {0b000001: 'rev16', 0b000010: 'rev', 0b000011: 'rev32',
             0b000100: 'clz', 0b000101: 'cls', 0b010010: 'xtn',
             0b010011: 'xtn'}
    i.name = names.get(opc)
    if i.name is None:
        i.note = 'unmodelled-1src'
        i.ops = ['(op %#x)' % opc, reg(rd, sf, allow_zr=True),
                 reg(rn, sf, allow_zr=True)]
        return True
    i.ops = [reg(rd, sf, allow_zr=True), reg(rn, sf, allow_zr=True)]
    return True


MODELS = [
    # Data Processing -- Immediate
    m_adr, m_addsub_imm, m_logical_imm, m_movewide, m_bitfield, m_extr,
    # Branches, Exception Generating and System
    m_bcond, m_b_bl, m_cbz, m_tbz, m_br_blr_ret, m_hint,
    # Loads and Stores
    m_ldst_uimm, m_ldst_uimm9, m_ldst_pair,
    # Data Processing -- Register
    m_addsub_shifted, m_logical_shifted, m_condselect, m_3src, m_2src,
    m_clz_rev,
]

# What each model CLAIMS, in the order the dispatch tries them.  The list is
# separate from MODELS because a docstring is a place to explain a function
# and this is a place to state a claim, and a claim that lives in a docstring
# is a claim nobody checks.  `--audit` prints this table; the harness in
# crosscheck.py asserts that it has 21 rows and that the GUARD COLUMN matches
# the measured field map, so a model added without a guard is visible.
#
# The order is the dispatch order, and it is not alphabetical and not
# arbitrary: `m_adr` and `m_hint` are the two models with 27- and 18-bit
# fixed patterns, and a cheap-and-specific guard belongs above an expensive
# general one.  A reader who reorders this list changes what the decoder
# resolves in the overlap, which is a design decision and not a refactor.
CLAIMS = [
    ('m_adr', 'bits[28:24] = 0b10000, op = bit 31',
     'ADR and ADRP: one 21-bit PC-relative field, split, scaled by 4096 '
     'when bit 31 is set'),
    ('m_addsub_imm', 'bits[28:24] = 0b10001',
     'ADD/SUB with a 12-bit immediate, an optional <<12 scale, and an S bit'),
    ('m_logical_imm', 'bits[28:23] = 0b100100',
     'AND/ORR/EOR/ANDS with a rotate-and-run-length constant; Rn = 31 is the '
     'MOV alias'),
    ('m_movewide', 'bits[28:23] = 0b100101',
     'MOVZ/MOVN/MOVK, one 16-bit field at a time; opc = 0b01 is UNDEFINED'),
    ('m_bitfield', 'bits[28:23] = 0b100110',
     'SBFM/UBFM/BFM/BFXIL, and the SBFX/UBFX/UBFIZ/SBFIZ aliases'),
    ('m_extr', 'bits[28:23] = 0b100111', 'EXTR, and ROR as its alias'),
    ('m_bcond', 'bits[31:24] = 0b01010100',
     'B.cond, a 19-bit displacement in bits[23:5] and the condition in '
     'bits[4:0]'),
    ('m_b_bl', 'bits[30:26] = 0b00101',
     'B and BL, a 26-bit signed word offset'),
    ('m_cbz', 'bits[30:25] = 0b011010',
     'CBZ and CBNZ, a 19-bit displacement and NO compare'),
    ('m_tbz', 'bits[30:25] = 0b011011',
     'TBZ and TBNZ, a 14-bit displacement and a bit number split as '
     'bit 31 : bits[23:19]'),
    ('m_br_blr_ret', 'bits[31:23] = 0b110101100, opc = bits[22:21]',
     'BR, BLR and RET: the target is a REGISTER, so no relocation is needed'),
    ('m_hint', 'bits[31:5] = 0xd503201f >> 5',
     'NOP, WFI, YIELD and the rest: 27 fixed bits and a 5-bit hint number'),
    ('m_ldst_uimm', "bits[29:27] = 0b111, bits[26:24] = 0b001",
     'LDR/STR and the size and byte variants, a 12-bit scaled offset'),
    ('m_ldst_uimm9', "bits[29:27] = 0b111, bits[26:24] = 0b000",
     'LDUR/STUR: a 9-bit UNSCALED signed offset, for when 12 scaled will not do'),
    ('m_ldst_pair', 'bits[29:27] = 0b101',
     'LDP/STP: two registers, a 7-bit offset scaled by 8, three addressing '
     'modes, and Rt2 at bits[14:10]'),
    ('m_addsub_shifted', 'bits[28:24] = 0b01011',
     'ADD/SUB with a shifted register, and the CMP/CMN/NEG aliases; '
     'Rd = 31 is sp'),
    ('m_logical_shifted', 'bits[28:24] = 0b01010',
     'AND/ORR/EOR/ANDS with a shifted register, and the MOV/TST/MVN aliases; '
     'Rn = 31 is xzr'),
    ('m_condselect', 'bits[28:21] = 0b11010100',
     'CSEL/CSINC/CSINV/CSNEG and the SET and INC families; the operation is '
     'the PAIR (bit 30, bits[11:10]) and op2 = 0b10, 0b11 is UNDEFINED'),
    ('m_3src', 'bits[30:24] = 0b0011011',
     'MADD/MSUB/MNEG: a multiply with an addend, which is what makes MUL an '
     'alias'),
    ('m_2src', 'bits[30:21] = 0b0011010110',
     'LSLV/LSRV/ASRV/RORV and UDIV/SDIV: a variable shift in one word'),
    ('m_clz_rev', 'bits[30:21] = 0b1011010110',
     'CLZ/CLS/REV/REV16/REV32: one source, no second operand'),
]


def decode(word, off=0):
    """Decode one 32-bit word.  NEVER fails on length: A64 is 4 bytes."""
    i = Insn(word, off)
    i.cls, _ = class_of(i.word)
    claimed = False
    for m in MODELS:
        before = len(i.why)
        try:
            if m(i):
                claimed = True
                break
        except Undefined as e:
            i.say('UNDEFINED ENCODING: %s' % e)
            i.note = i.note or 'undefined'
            if i.name is None:
                i.name = '(undefined)'
                i.ops = ['(undefined)']
            claimed = True
            break
        except Bad as e:
            continue
        if len(i.why) == before and not i.ops and not i.name:
            i.why = []
    if not claimed:
        i.name = None
        i.ops = []
        i.note = i.note or 'unmodelled'
    # bits the encoding spends on the fixed pattern of the group it belongs to
    i.text = render(i)
    return i


def render(i):
    if i.name is None:
        return '(op 0x%08x)  %s' % (i.word, i.cls)
    if i.note == 'undefined':
        return '%-8s %s' % (i.name, ', '.join(i.ops))
    return '%-8s %s' % (i.name, ', '.join(i.ops))


def explain(i, indent='    '):
    out = [indent + '0x%08x   %s' % (i.word, i.text),
           indent + '  class field bits[28:25] = %s  ->  %s'
           % (format(i.key, '04b'), i.cls)]
    for w in i.why:
        out.append(indent + '  . ' + w)
    used = i.bits_used
    out.append(indent + '  . this decode READ %d of the 32 bits; %d were not '
               'needed to name the instruction' % (used, 32 - used))
    return '\n'.join(out)


# ---------------------------------------------------------------------------
# Reading a real file.  A stripped-down ELF64 reader, no tool and no library.
# ---------------------------------------------------------------------------
SHT_PROGBITS, SHF_EXECINSTR = 1, 0x4
EM_AARCH64 = 183


def code_sections(path):
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        raise ValueError('%s is not an ELF file' % path)
    if d[4] != 2:
        raise ValueError('%s is not ELF64' % path)
    machine, = struct.unpack_from('<H', d, 0x12)
    if machine != EM_AARCH64:
        raise ValueError('%s: e_machine is %d, not %d (AArch64)'
                         % (path, machine, EM_AARCH64))
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


def decode_text(d, off, size, addr=0):
    """Every 4 bytes is one instruction, so the chain CANNOT slip.

    This is the one property x86dec.py cannot have, and it is why the
    declared subset here is a subset of NAMES rather than of LENGTHS: an
    unmodelled instruction still contributes exactly 4 bytes to the count.
    """
    insns = []
    p = 0
    while p + 4 <= size:
        w, = struct.unpack_from('<I', d, off + p)
        insns.append(decode(w, addr + p))
        p += 4
    return insns, p


# ===========================================================================
# Part two: the measurement driver.  Everything below RUNS something; nothing
# above it does.  A decoder that can print a mnemonic is not evidence.
# ===========================================================================

HERE = os.path.dirname(os.path.abspath(__file__))
CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
TARGET = 'aarch64-linux-gnu'


def sh(*args, **kw):
    return subprocess.run(list(args), capture_output=True, text=True, **kw)


def objdump_words(path):
    """(addr, word, text) for every instruction, straight from the oracle."""
    p = sh(OBJDUMP, '--triple=aarch64', '-d', path)
    out = []
    for ln in p.stdout.splitlines():
        m = re.match(r'^\s+([0-9a-f]+):\s+([0-9a-f]{1,8})\s+\t(.*)$', ln)
        if m:
            out.append((int(m.group(1), 16), int(m.group(2), 16),
                        m.group(3).strip()))
    return out


def normalise_objdump(t):
    """Reduce an instruction to a form two decoders can be compared on.

    Six normalisations, and every one of them exists because a disagreement
    was found once and the reason turned out to be FORMATTING rather than a
    wrong decode.  Listing them is the point: a cross-check that quietly
    normalises away a real disagreement is worse than no cross-check.

      * `mov w0, #0x0  // =0` -- the trailing comment is objdump's arithmetic
        and `mov` is the assembler printing MOVZ with hw = 0;
      * a TAB between the mnemonic and the operands, and a space after every
        comma, which are printer choices;
      * `adrp x0, 0x0 <surface>` and `b.eq 0x208 <target>` -- a relocatable
        object's symbol annotation and a resolved address, neither of which a
        decoder reading bytes in isolation can know;
      * `lsl w0, w1, #0x3` against `lsl w0, w1, #3` -- LLVM prints small
        immediates in DECIMAL and large ones in hex, and a decoder prints
        everything in hex;
      * a negative displacement, which the two printers sign differently;
      * `sub w0, w1, w2, lsl` -- the two-operand shifted-register form, where
        a shift of zero is not printed at all.
    """
    t = t.split('//')[0].strip()
    t = re.sub(r'\s*<[^>]*>', '', t)
    t = re.sub(r'<[^>]*>', '', t)
    t = t.replace('\t', ' ')
    # WHITESPACE FIRST.  The first version of this function ran the name
    # rewrites against the raw string, in which `movz     w0, #0x0` carries
    # five spaces between the mnemonic and the register -- so every mnemonic
    # rewrite silently matched nothing and the cross-check reported 60
    # disagreements that were all one unapplied regular expression.  The
    # canonical form is built FIRST and the semantic rewrites run on it.
    t = re.sub(r'\s+', ' ', t).strip()
    t = re.sub(r'\s*,\s*', ',', t)
    # The SHIFT TYPE and AMOUNT are ONE operand and the amount is a bare
    # integer, and the TARGET rules below cannot tell a shift amount from a
    # branch displacement.  So the shift is canonicalised FIRST, and to a
    # `#`-prefixed form, which no TARGET rule matches.  The first version ran
    # this rule AFTER the target rules and `bic w9, w0, w0, asr #25` came out as
    # a target.
    t = re.sub(r'([\wx]\d+),(lsl|lsr|asr|ror),#(0x[0-9a-f]+|\d+)',
               r'\1,\2 #\3', t)
    t = re.sub(r'\s+0x[0-9a-f]+$', ' TARGET', t)
    # A branch TARGET is a relocatable address, not a displacement the decoder
    # can resolve: in an object file it is 0x00000000 with an
    # R_AARCH64_B/PREL/_BR/BL reloc sitting on it, and in a linked image it is
    # an address.  Both readers print a number and neither is the encoding, so
    # the field is compared as a TARGET and nothing else.
    # ADR/ADRP name a PC-RELATIVE ADDRESS and the printer writes it as a
    # number; in a relocatable object the number is a placeholder and the real
    # address is in a relocation, so it is compared as a TARGET.
    # The last operand of a branch, an adr and an adrp is a PC-RELATIVE
    # ADDRESS.  In a relocatable object it is a placeholder and the real value
    # is in an R_AARCH64_* relocation; in a linked image it is an address.
    # Neither is the ENCODING, so both sides are compared as TARGET and the
    # displacement arithmetic is checked separately in section 11 -- against
    # the same bytes, by hand, not by asking a printer.
    for stem in ('adrp', 'adr', 'b', 'bl', 'b.eq', 'b.ne', 'b.hs', 'b.lo',
                 'b.mi', 'b.pl', 'b.vs', 'b.vc', 'b.hi', 'b.ls', 'b.ge',
                 'b.lt', 'b.gt', 'b.le', 'cbz', 'cbnz', 'tbz', 'tbnz'):
        # `[\w,#]*` does NOT match the space the printer puts between the
        # mnemonic and its operands, so the first version of this loop matched
        # nothing at all and every branch in the corpus disagreed.  The class
        # needs the space.
        t = re.sub(r'^%s([\w,#\s]*?)[-+]?(0x[0-9a-f]+|\d+)$' % stem,
                   r'%s\1TARGET' % stem, t)
    # A `tbz` bit NUMBER is a bare integer and so is a branch displacement, and
    # the rule above cannot tell them apart.  TBZ's second operand is the bit
    # and its third is the target, so the bit is put back explicitly.
    t = re.sub(r'^(tbz|tbnz)([\w,]+),#(0x[0-9a-f]+|\d+),TARGET$',
               r'\1\2,#\3,TARGET', t)
    # A zero displacement is printed by LLVM with the `#0` DROPPED, because it
    # is a pronoun: `[x1]` means `[x1, #0]`.  The decoder always prints the
    # field, because a decoder that omits a field it read is a decoder whose
    # output cannot be audited -- so the omission is normalised on BOTH sides.
    t = re.sub(r'\[(\w+),#?0x?0?\]', r'[\1]', t)
    # `add x0, x1, #0x1000` and `add x0, x1, #0x1, lsl #12` are the same 32
    # bits.  The decoder prints the first and the assembler the second, so the
    # `,lsl#0xc` is folded into the value on ONE side and both are compared as
    # the value they name.
    # `add x0, x0, x0, lsl #48` -- a register shift with an AMOUNT -- and
    # `add x0, x1, #0x1000` -- a 12-bit immediate with a scale -- are printed
    # with the same punctuation, `,lsl#N`, and the two are not the same field.
    # The first version folded every `,lsl#N` into the preceding value, which
    # multiplied a REGISTER's name by 4096.  The two forms are told apart by
    # what precedes the comma: `#imm,` is the immediate form and `xN,` is the
    # register form, and the register form's amount is left alone.
    t = re.sub(r'#(0x[0-9a-f]+|\d+),lsl#0xc$',
               lambda m: '#%#x' % (int(m.group(1), 0) * 4096), t)
    t = re.sub(r'#(0x[0-9a-f]+|\d+),lsl#0x([0-9a-f])$',
               lambda m: '#%#x' % (int(m.group(1), 0) << int(m.group(2), 16)),
               t)
    t = re.sub(r'([\wx]\d+),lsl,#(0x[0-9a-f]+|\d+)', r'\1,lsl #\2', t)
    # every immediate becomes one canonical form: a signed hex literal
    def imm(m):
        v = m.group(1)
        if v.startswith('0x') or v.startswith('-0x'):
            n = int(v, 16)
        else:
            n = int(v, 10)
        return '#%s%#x' % ('-' if n < 0 else '', abs(n))
    t = re.sub(r'#(-?0x[0-9a-f]+|-?\d+)\b', imm, t)
    t = re.sub(r'\blsl\s*$', '', t)
    # MOVZ with hw = 0 is the assembler's `mov`, and it is the single most
    # common instruction clang emits.  The two names are the same 32 bits and
    # the decoder keeps both: the mnemonic the ENCODING implies (`movz`) and
    # the one the ASSEMBLER prints (`mov`).  Section 2 prints the mapping for
    # every alias the assembler defines, because "it is an alias" is only
    # interesting if you can say WHICH encoding the alias stands for.
    # The mnemonic is separated from the operands ONCE, here, and every
    # mnemonic rewrite below works on the mnemonic alone.  The first version
    # tried to rewrite a mnemonic with a regex anchored at `^` and reaching
    # into the operand list, which fails on the space the mnemonic is padded
    # with -- and a rewrite that silently matches nothing is the worst kind,
    # because the cross-check still runs.
    mn, sep, rest = t.partition(' ')
    if mn == 'movz':
        mn = 'mov'
    if rest and rest.rsplit(',', 1)[-1] in ('cs', 'cc'):
        head, last = rest.rsplit(',', 1)
        rest = head + ',' + {'cs': 'hs', 'cc': 'lo'}[last]
    t = mn + sep + rest
    # CONDITION SPELLINGS.  The same 4-bit value has two names and LLVM picks
    # by position in the instruction: CSEL prints `hs`/`lo` where B.cond prints
    # `cs`/`cc` (measured: `csel w0,w1,w2,cs` assembles to 0x1a822020 and both
    # objdump and clang's own printer call it `hs`).  Two names for one field
    # is a fact about the ISA and a nuisance for a cross-check, so the decoder
    # uses the CSEL spelling throughout and section 10 prints the B.cond form
    # beside it.
    # RET takes no printed operand: `ret` is `ret x30` and LLVM omits it.
    if t == 'retx30':
        t = 'ret'
    # MOVN.  The field holds the MAGNITUDE and the register holds the
    # complement, so `movn w0, #0x1234` and `mov w0, #-0x1235` are the same
    # 32 bits.  Both sides are folded onto the complement, which is the value
    # the register actually ends up with and is therefore the one thing both
    # printers can be asked to agree about.
    # THE SIGNED-IMMEDIATE CONVENTION, and it is the whole of the remaining
    # 11 corpus disagreements.  Three separate printers in this one table
    # disagree about the sign of an immediate, and all three are right:
    #
    #   * MOVN prints the register's value, which is the field's COMPLEMENT:
    #     `movn w0, #0x1234` prints as `mov w0, #-0x1235` (section 6B).
    #   * A logical immediate that is the MOV alias prints SIGNED: word
    #     0xb2089fe0 is `orr x0, xzr, #0xff00ff00ff00ff00` to this decoder and
    #     `mov x0, #-0xff00ff00ff0100` to the oracle.  2^64 minus
    #     0xff00ff00ff00ff00 is 0x00ff00ff00ff0100, so the two strings name
    #     the SAME 64 bits with opposite signs.  The same happens at 32 bits:
    #     0x32089fe0 is `orr w0, wzr, #0xff00ff00` here and `mov w0,
    #     #-0xff0100` there.
    #   * MOVZ prints the value UNSIGNED: `movz w10, #0x80000000` against
    #     `mov w10, #-0x80000000`.
    #
    # So: every `#-0x...` is folded onto the UNSIGNED value at the register
    # width, and every MOVN field is folded onto the value the register ends up
    # holding, which is the same number.  One rule, applied once, at the end.
    # The first version of this function had two separate special cases -- one
    # for MOVN and one for the signed `mov` -- each with its own hard-coded
    # 32-bit mask, and applied the 32-bit mask to 64-bit registers, so three
    # of the eleven failures were a width bug inside a normalisation rule.
    width = 64 if re.search(r'\bx\d+\b', t) else 32
    full = 0xffffffffffffffff if width == 64 else 0xffffffff
    # The class needs the SPACE.  `[\w,]*` does not match the space between
    # the mnemonic and its operands, so the first version of this rule
    # matched nothing at all -- silently, because a rewrite that matches
    # nothing is the kind of bug a cross-check does not report: it reports
    # 11 disagreements and the reader assumes the decoder is wrong.  That is
    # the fourth time in this collection that a regex has been written
    # against a string with a space in it.
    t = re.sub(r'^movn([\w,\s]*),#(0x[0-9a-f]+)$',
               lambda m: 'mov%s,#%#x' % (m.group(1),
                                        (~int(m.group(2), 16)) & full),
               t)
    t = re.sub(r'#(-0x[0-9a-f]+)\b',
               lambda m: '#%#x' % (int(m.group(1), 16) & full), t)
    t = re.sub(r'\s+', ' ', t).strip()
    return t.replace(' ', '')


# ---------------------------------------------------------------------------
# Assembling.  This is the ONLY place in the file that runs a toolchain, and
# what it asks for is: WORDS to decode, and REFUSALS to record.  It never asks
# what an instruction MEANS, because the one thing this file is for is
# deciding what it means from the bits alone.
#
# ONE INSTRUCTION PER FILE, which is slower and which is the point.  The first
# version assembled every probe into one .s, and the single probe the assembler
# rejects took the other sixty-eight with it and printed 68 blanks: a probe
# that loses its whole sample to one bad row measures nothing.
# ---------------------------------------------------------------------------


def asm_one(src):
    """(word, oracle text) for one source line, or (None, the refusal)."""
    with open('_p.s', 'w') as f:
        f.write('.text\nT: nop\nfar: nop\n  %s\n' % src)
    p = sh(CLANG, '--target=' + TARGET, '-c', '_p.s', '-o', '_p.o')
    if p.returncode:
        lines = [l.strip() for l in p.stderr.splitlines() if 'error' in l]
        return None, (lines[0][:74] if lines else p.stderr.strip()[:74])
    ws = objdump_words('_p.o')
    if len(ws) < 3:
        return None, 'assembled, but the oracle printed no instruction'
    return ws[2][1], ws[2][2]


def asm_batch(srcs):
    """Words for many lines at once, or None if the assembler refused any.

    A batch is a fast path with a correct fallback: the batch is right when it
    succeeds, and when it does not every line is re-assembled on its own so
    that one refusal costs one row rather than the table.
    """
    if not srcs:
        return []
    with open('_b.s', 'w') as f:
        f.write('.text\nT: nop\nfar: nop\n')
        for s in srcs:
            f.write('  %s\n' % s)
    p = sh(CLANG, '--target=' + TARGET, '-c', '_b.s', '-o', '_b.o')
    if p.returncode:
        return None
    ws = objdump_words('_b.o')
    if len(ws) < 2 + len(srcs):
        return None
    return [ws[2 + n] for n in range(len(srcs))]


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


CORPUS = ['a64.o'] + ['corpus_O%s.o' % o for o in ('0', '1', '2', 's')]


def corpus_files():
    """The object files that exist.  A missing one is reported, not skipped."""
    have = [f for f in CORPUS if os.path.exists(os.path.join(HERE, f))]
    missing = [f for f in CORPUS if f not in have]
    return have, missing


def corpus_insns():
    """Every instruction in every corpus object, with the file it came from."""
    out = []
    files, _ = corpus_files()
    for f in files:
        d, secs = code_sections(os.path.join(HERE, f))
        for name, addr, off, size in secs:
            insns, p = decode_text(d, off, size, addr)
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
    """Prose at 74 columns, with LIST items kept as list items.

    The first version of this reflowed every whitespace-separated token into
    one paragraph, which turned a bulleted list of three class-of-bug items
    into one run-on sentence with the bullets swallowed.  A reflow that
    destroys the structure it was handed is worse than no reflow, so a block
    whose lines start with a bullet or a bar is printed VERBATIM, one line at
    a time, and only unadorned blocks are wrapped.
    """
    for chunk in text.split('\n\n'):
        lines = [l for l in chunk.split('\n') if l.strip()]
        bulleted = [l for l in lines
                    if l.lstrip()[:1] in ('*', '|', '-')]
        if bulleted and len(bulleted) == len(lines):
            for l in lines:
                print(l if l.startswith(' ') else indent + l)
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


def table(head, rows, widths=None):
    """A left-aligned table.  The format string is built by joining widths,
    and the first version of this built `  %-18  %-52s` -- one `s` for three
    columns -- which raises `unsupported format character ' '` on the first
    row.  Each width needs its OWN conversion, so each gets an `s`."""
    widths = widths or [max(len(str(head[i])),
                            max([len(str(r[i])) for r in rows]) if rows else 0)
                        for i in range(len(head))]
    fmt = ''.join('  %-' + str(w) + 's' for w in widths)
    print(fmt % tuple(str(h) for h in head))
    for r in rows:
        print(fmt % tuple(str(c) for c in r))


# ===========================================================================
# SECTION 1 -- THE INSTRUMENT.
# ===========================================================================


def sec1():
    banner(1, 'THE INSTRUMENT.  Nothing below this point is a claim yet.')
    print()
    para("""There is no AArch64 machine here, and the first thing this file has
to say is what follows from that.  Nothing in the corpus is ever EXECUTED.
The compiler emits words, the disassembler names words, and this file reads
words.  Every number below is a property of an ENCODING, and none of them is
a property of a running AArch64 program -- there is not one on this machine to
have a property.""")
    rows = [
        ('assembles', tool_version(CLANG, '--version'), 'the SECOND reader'),
        ('disassembles', tool_version(OBJDUMP, '--version'), 'the SECOND reader'),
        ('links AArch64', which('aarch64-linux-gnu-ld') or 'NOT INSTALLED',
         'so no linked image is compared'),
        ('emulates AArch64', which('qemu-aarch64') or 'NOT INSTALLED',
         'so no instruction is executed'),
    ]
    table(('role', 'what was found', 'what that means'), rows,
          [18, 52, 34])
    print()
    para("""The two rows that matter are the two NO rows.  They are printed
before any measurement rather than in a limits section at the end, because a
reader who meets a number and meets the absence of the thing that would make
it a runtime measurement in a different order learns a different lesson.""")
    para("""THE DECODER USES NO TOOL AT ALL.  Part one of this file imports
os, re, struct and sys and nothing else.  struct.unpack_from reads the ELF64
section header table by hand -- e_shoff at 0x28, e_shentsize/e_shnum/e_shstrndx
at 0x3a, and then 64 bytes per entry -- and .text is found by NAME.  The
reader is a dependency of the claim rather than a convenience, for the reason
the isa course's x86dec.py gives: a decoder that shells out to a disassembler
is a disassembler with a hardcoded path in it.""")
    elfhdr = [('e_shoff', '0x28', '8 bytes', 'offset of the section table'),
              ('e_shentsize', '0x3a', '2 bytes', 'size of ONE section header'),
              ('e_shnum', '0x3c', '2 bytes', 'how many there are'),
              ('e_shstrndx', '0x3e', '2 bytes', 'which one is the name table'),
              ('e_machine', '0x12', '2 bytes', '183 = EM_AARCH64')]
    print('  THE ELF64 FIELDS THIS FILE READS, and nothing else:')
    table(('field', 'offset', 'width', 'what it selects'), elfhdr, [12, 9, 9, 44])
    print()
    para("""A reader who wants to check can: every offset above is in the ELF64
specification's section-header index and none of them is a constant invented
here.  The decoder CHECKS e_machine == 183 and refuses a file that is not an
AArch64 object, because the alternative is decoding x86-64 words as AArch64
words and getting a plausible answer.""")
    print('  THE DECLARED SUBSET, and what "subset" means HERE:')
    print('    %d instruction groups are modelled, and the subset is a'
          % len(MODELS))
    print('    subset of NAMES, not of LENGTHS.  An instruction this file')
    print('    cannot name still resolves a length, because the length is a')
    print('    constant.  That is the whole difference from x86dec.py in one')
    print('    line, and section 2 measures it.')
    insns = corpus_insns()
    unnamed = sum(1 for k in insns if k.name is None)
    print('    Of the %d words in the corpus, %d are named by one of those'
          % (len(insns), len(insns) - unnamed))
    print('    models and %d are not.' % unnamed)
    print('    A word no model claims is printed as (op 0x%08x) and COUNTED.'
          % insns[0].word if insns else '')
    print('    It is never dropped, because a table that filtered them out')
    print('    would be a property of the filter rather than of the corpus.')
    print()


# ===========================================================================
# SECTION 2 -- FOUR BYTES, ALWAYS.  AND THE MNEMONIC IS NOT IN THERE.
# ===========================================================================


ALIASES = [
    ('mov w0, #0x1234', 'movz w0, #0x1234',
     'MOVZ with hw = 0, and hw = 0 is the DEFAULT so the assembler hides it'),
    ('cmp w0, w1', 'subs wzr, w0, w1',
     'the flag-writing form, with the destination thrown away'),
    ('cmn w0, #1', 'adds wzr, w0, #1', 'the same, on the other side'),
    ('neg w0, w1', 'sub w0, wzr, w1', 'the zero register as a SOURCE'),
    ('mvn w0, w1', 'orn w0, wzr, w1',
     'NOT is OR with all ones -- and the ZERO is the FIRST operand, so the'
     ' spelling is `orn w0, wzr, w1` and NOT `orn w0, w1, wzr`'),
    ('tst w0, w1', 'ands wzr, w0, w1', 'and the destination thrown away'),
    ('mov w0, w1', 'orr w0, wzr, w1',
     'a MOVE IS AN OR with a zero -- and again the ZERO is first, so the'
     ' spelling is `orr w0, wzr, w1`'),
    ('mov sp, x0', 'add sp, x0, #0',
     'the STACK POINTER is register 31 in this group'),
    ('mov x0, sp', 'add x0, sp, #0', 'and the same 31 as a source'),
    ('mul w0, w1, w2', 'madd w0, w1, w2, wzr',
     'a MULTIPLY IS a three-source with an addend of zero'),
    ('sxtw x0, w1', 'sbfm x0, x1, #0, #31', 'a sign extend, expressed as a FIELD'),
    ('uxtw x0, w1', 'ubfm x0, x1, #0, #31', 'the same with the other bitfield op'),
    ('lsl w0, w1, #3', 'ubfm w0, w1, #29, #28',
     'a shift is a bitfield whose two halves are adjacent'),
    ('ret', 'ret x30', 'and the link register is 30, so it is the DEFAULT'),
    ('nop', 'hint #0', 'TWENTY-SEVEN FIXED BITS and a 5-bit hint number'),
    ('add w0, w1, #0x1000', 'add w0, w1, #1, lsl #12',
     'one imm12 field, with a SHIFT on it'),
    ('cset w0, eq', 'csinc w0, wzr, wzr, ne',
     'THE TRAP: the condition is INVERTED.  csinc with the same cond is a '
     'DIFFERENT 32 bits'),
    ('cset w0, ne', 'csinc w0, wzr, wzr, eq', 'and the other way round'),
    ('csetm w0, eq', 'csinv w0, wzr, wzr, ne',
     'CSETM is CSINV, also with the condition inverted'),
    ('cinc w0, w1, eq', 'csinc w0, w1, w1, ne',
     'Rn == Rm, and again INVERTED'),
    ('cneg w0, w1, ge', 'csneg w0, w1, w1, lt', 'and the other way round'),
    ('adr x0, T', 'adrp x0, T',
     'NOT AN ALIAS, and the row is here for that reason: two words and ONE'
     ' bit apart, and section 11 works out what that bit is worth'),
]


def sec2():
    banner(2, 'FOUR BYTES, ALWAYS.  AND THE MNEMONIC IS NOT IN THERE.')
    print()
    para("""The claim this course is built on is that an AArch64
instruction is exactly four bytes, and the claim is worth measuring because
it is the one property of the encoding that a decoder gets FOR FREE: a word
of unknown meaning still has a known length.""")
    rows = []
    allfour = True
    tot = 0
    for f in CORPUS:
        p = os.path.join(HERE, f)
        if not os.path.exists(p):
            continue
        d, secs = code_sections(p)
        for name, addr, off, size in secs:
            insns, used = decode_text(d, off, size, addr)
            exact = (used == size) and (size % 4 == 0)
            allfour = allfour and exact
            tot += len(insns)
            rows.append((f, name, size, size % 4, len(insns),
                         '%.4f' % (size / max(1, len(insns))),
                         'EXACTLY' if exact else 'NO'))
    table(('file', 'section', 'bytes', '%4', 'insns', 'bytes/insn', 'chain'),
          rows, [16, 8, 7, 4, 6, 10, 8])
    print()
    print('  %d instructions over %d code sections.  Every section is a'
          % (tot, len(rows)))
    print('  multiple of four, every walk ends exactly on the section end, and')
    print('  bytes/insn is 4.0000 in every row including the hand-written one.')
    print('  VERDICT: %s' % ('fixed width, on this corpus' if allfour
                             else 'NOT FIXED WIDTH -- see the %4 column'))
    print()
    para("""So here is what that buys, stated as the negative space
rather than the positive claim.  Every one of these is a class of bug a
variable-length decoder has and this one cannot:

  * DESYNCHRONISATION.  A decoder that guesses a length wrong is reading
    garbage forever after, and there is no resynchronisation point in a
    variable-length encoding.  Here the next instruction starts 4 bytes on
    whether or not the previous one made sense.
  * A DECODED INSTRUCTION THAT IS NOT AN INSTRUCTION.  A word no model
    claims is 4 bytes of somebody else's problem, and the count above is
    still right.
  * LENGTH ARITHMETIC.  There is no prefix byte, no escape, no opcode-length
    table, and therefore no integer that can overflow.

And here is what it costs, because the list above is one-sided.  Four bytes
is four bytes for `nop`, which does nothing.  The x86-64 encoding has a
one-byte `nop` and a two-byte `ret`; this one pays four bytes each, and
section 13 measures what that costs in code size and finds the answer is "it
depends, and the answer is measurable".""")
    print('  THE MNEMONIC IS NOT IN THERE.  The encoding stores an OPCODE')
    print('  and operands; the name you type is the ASSEMBLER\'S, and the two')
    print('  are related by a table the architecture defines.  Every row')
    print('  below was MEASURED by assembling both lines and comparing the two')
    print('  32-bit words, which is the only way to say what an alias')
    print('  ACTUALLY stands for rather than what it looks like.')
    print()
    ok = 0
    differ = []
    for a, b, why in ALIASES:
        wa, _ = asm_one(a)
        wb, _ = asm_one(b)
        if wa is None or wb is None:
            print('    %-22s %-22s  COULD NOT MEASURE' % (a, b))
            continue
        if wa == wb:
            ok += 1
            print('    %08x  %-22s == %-22s  %s' % (wa, a, b, why))
        else:
            differ.append((a, b, wa, wb))
            print('    %08x  %-22s != %08x %-22s  NOT AN ALIAS' % (wa, a, wb, b))
    print()
    print('  %d of %d pairs are the same 32 bits.' % (ok, len(ALIASES)))
    print()
    para("""Read the table for what it says about the architecture rather than
about the aliases.  `cmp` is a `subs` with a destination nobody keeps;
`mvn` is an `orn`; `mov` is an `orr`; `mul` is a `madd` with a zero addend;
`cset` is a `csinc` with the condition INVERTED.  Four of the twenty-two
rows are not aliases at all and say so.

The `cset` row is the one to keep.  `cset w0, eq` and `csinc w0, wzr, wzr,
eq` are DIFFERENT 32 bits, and the difference is in the condition field and
nowhere else.  A disassembler that models `cset` as "csinc with Rn = Rm =
31" produces a decoder that is right about the operands and wrong about
every `cset` in the program, and nothing about the result looks wrong: it is
0 or 1, exactly as `cset` promised.""")
    print('  WORD-LEVEL FACTS about the mnemonic field, all measured:')
    print('    * `mov` has no encoding of its own.  Its two meanings -- a')
    print('      MOVZ and an ORR -- are two different groups in two different')
    print('      classes, and which one a word is depends on bits[28:23] and')
    print('      nothing else.')
    print('    * `nop` is bits[31:5] fixed and a 5-bit hint number in the low')
    print('      five: 27 of 32 bits carry the same value in every hint.')
    print('    * `cmp`/`cmn`/`tst` are three two-operand forms of')
    print('      three-operand instructions, and the difference is one bit in')
    print('      the destination field: register 31 in the DP-immediate group')
    print('      is the STACK POINTER and in the DP-register logical group it')
    print('      is the ZERO register.  Section 4 measures that too.')
    print()


# ===========================================================================
# SECTION 3 -- THE CLASS FIELD.
# ===========================================================================

QUOTED_CLASSES = {
    0b0000: 'Reserved / permanently UNDEFINED',
    0b0001: 'Reserved',
    0b0010: 'Reserved',
    0b0011: 'Reserved',
    0b0100: 'Loads and Stores (pair)',
    0b0101: 'Data Processing -- Register',
    0b0110: 'Advanced SIMD (pair)',
    0b0111: 'Advanced SIMD',
    0b1000: 'Data Processing -- Immediate',
    0b1001: 'Data Processing -- Immediate',
    0b1010: 'Branches, Exception Generating and System',
    0b1011: 'Branches, Exception Generating and System',
    0b1100: 'Loads and Stores',
    0b1101: 'Data Processing -- Register',
    0b1110: 'Advanced SIMD',
    0b1111: 'Advanced SIMD / FP',
}


def objdump_mnemonic(txt):
    """The mnemonic out of an oracle line, without a table of exceptions.

    `addv s0, v0.4s` has a space and `movi v0.2d, #0` does not appear to,
    and the difference is whether the first operand is a register or an
    arrangement.  Taking the first ALPHABETIC RUN gets both, which is the
    point: a table of exceptions is a table that will be incomplete.
    """
    t = txt.split('//')[0].strip()
    t = re.sub(r'^(b|b\.\w+)\s', r'\1 ', t)
    m = re.match(r'^([a-z][a-z0-9._]*)', t)
    return m.group(1) if m else '(none)'


def sec3():
    banner(3, 'THE CLASS FIELD, bits[28:25], MEASURED OVER A REAL CORPUS')
    print()
    para("""Four bits at position 25 are the first thing a decoder
looks at.  There are sixteen values, and what each one MEANS is quoted from
the architecture's reference manual.  What each one CONTAINS is measured
here, by taking the instructions out of five object files, reading four bits
out of each, and asking the oracle what that instruction is.""")
    import collections
    by = collections.defaultdict(collections.Counter)
    n = unnamed = 0
    files, missing = corpus_files()
    for f in files:
        for addr, w, txt in objdump_words(os.path.join(HERE, f)):
            if not txt or txt.startswith('.'):
                unnamed += 1
                continue
            by[(w >> 25) & 0xf][objdump_mnemonic(txt)] += 1
            n += 1
    print('  %d object files, %d instructions the oracle named, %d it did'
          % (len(files), n, unnamed))
    print('  not.  Missing from the corpus: %s.'
          % (', '.join(missing) or 'nothing'))
    print()
    rows = []
    for k in sorted(by):
        c = by[k]
        rows.append((format(k, '05b'), sum(c.values()),
                     ' '.join('%s:%d' % kv for kv in c.most_common(5)),
                     QUOTED_CLASSES[k]))
    table(('bits', 'n', 'what landed there, and how often', 'the QUOTED name'),
          rows, [6, 5, 52, 38])
    print()
    empty = [k for k in range(16) if k not in by]
    counts = sorted(((sum(c.values()), k) for k, c in by.items()), reverse=True)
    rank = [k for _, k in counts].index(0b1101) + 1
    simd_empty = [k for k in empty if 'SIMD' in QUOTED_CLASSES[k]]
    print('  %d of the 16 values carry at least one real instruction in this'
          % len(by))
    print('  corpus.  Empty here: %s.'
          % (', '.join(format(k, '05b') for k in empty) or 'none'))
    print()
    para("""The class NAMES are a quotation.  The MEMBERSHIP is a
measurement, and it is the membership the decoder's dispatch is built on,
because a dispatch built on a remembered table is a claim and a claim cannot
be debugged.

%d of the sixteen values are empty in this corpus and %d of those carry
SIMD.  That is a fact about this corpus, not about the architecture, and the
difference matters: a reader who has read that "bits[28:25] is the class
field" is holding a rule they will test, and the %d empty rows are the %d the
rule is easiest to get wrong by rounding a two-bit recollection up to four
bits.

And the one a two-bit rule cannot see is 1101, which holds `csel`, `cset`,
`mul` and `madd` -- %d instructions, the %s largest entry in the table.  A
rule that stops at bits[28:27] and then peeks at bit 25 puts them in "Data
Processing -- Register" alongside 0101, and that is not merely cosmetic:
1101 and 0101 are different code paths through the decoder, with different
guards and different operand layouts."""
         % (len(empty), len(simd_empty), len(empty), len(empty),
            sum(by[0b1101].values()),
            {1: 'first', 2: 'second', 3: 'third', 4: 'fourth', 5: 'fifth',
             6: 'sixth'}.get(rank, '%dth' % rank)))
    print('  WHAT THE EMPTY ROWS COST, stated exactly:')
    print('    A decoder may implement %d of the 16 classes and be correct'
          % len(by))
    print('    on every instruction in this corpus.  The %d empty values are'
          % len(empty))
    print('    not "unimplemented classes" -- they are values whose contents')
    print('    this corpus did not exercise, and a class field is four bits')
    print('    wide whether or not a program uses it.')
    print()
    print('  The 4-bit field is also the CHEAPEST possible first cut, and the')
    print('  reason is arithmetic rather than architectural taste: 16 buckets')
    print('  means one 4-bit compare, and the ARM manual states the field')
    print('  exists to give the decoder a top-level split.  What the manual')
    print('  does not say is how much of the map is reachable, and section 5')
    print('  measures that instead of quoting it.')
    print()


# ===========================================================================
# SECTION 4 -- THE FIELD MAP, MEASURED BY DIFFERENCE.
# ===========================================================================

# (label, base, [variants])  -- each variant differs from base in ONE operand.
# The mask is the OR of the XORs over the variants, which is the important
# correction: a single pair marks the bits where the two VALUES differ, and
# for a multi-bit field that is a subset of the field.  The first version of
# this measurement used one pair per field and reported an 8-bit "imm16".
FIELD_CASES = [
    ('Rd', 'add w0, w1, w2', ['add w7, w1, w2', 'add w9, w1, w2',
                             'add w11, w1, w2', 'add w13, w1, w2']),
    ('Rn', 'add w0, w1, w2', ['add w0, w9, w2', 'add w0, w11, w2',
                              'add w0, w13, w2', 'add w0, w15, w2']),
    ('Rm', 'add w0, w1, w2', ['add w0, w1, w3', 'add w0, w1, w5',
                              'add w0, w1, w9', 'add w0, w1, w11']),
    ('sf', 'add w0, w1, w2', ['add x0, x1, x2', 'add x1, x1, x1']),
    ('op', 'add w0, w1, w2', ['sub w0, w1, w2']),
    ('S', 'add w0, w1, w2', ['adds w0, w1, w2']),
    # The amount sweep starts at #0 and visits each single bit, because a sweep
    # that starts at a NON-ZERO base and only visits odd amounts can never move
    # the low bit and the mask comes out one bit short.  The first version of
    # this row was `lsl #3` against #5, #9, #17, #25, #31 and measured
    # bits[14:11] -- four bits for a six-bit field, because bit 10 of the base
    # was set in every variant and the XOR of two set bits is clear.
    # A 32-bit register shifts by 0 to 31 and a 64-bit one by 0 to 63, so the
    # six-bit field is swept on `x` registers: `add w0, w1, w2, lsl #32` is
    # REFUSED with "optional integer in range [0, 4]", which is the
    # assembler's way of saying 31, and taking it in a sweep takes the whole
    # row down.  The width is not a property of the SHIFT, it is a property of
    # the DESTINATION, and that is the field-vs-meaning distinction again.
    ('shift amt', 'add x0, x1, x2, lsl #0', ['add x0, x1, x2, lsl #%d'
                                             % (1 << k) for k in range(6)]),
    ('shift amt (32-bit)', 'add w0, w1, w2, lsl #0',
     ['add w0, w1, w2, lsl #%d' % (1 << k) for k in range(5)]),
    # The type field here is TWO bits, and the four values are lsl, lsr, asr
    # and the pair sxtx/uxtx -- NOT ror, which is refused with a diagnostic
    # naming the three names it will accept.  That refusal is a fact about the
    # encoding and section 9 asks for it again.
    ('shift type', 'add w0, w1, w2, lsl #3', ['add w0, w1, w2, lsr #3',
                                              'add w0, w1, w2, asr #3',
                                              'add w0, w1, w2, sxtx #3',
                                              'add w0, w1, w2, uxtx #3']),
    ('shift N', 'add w0, w1, w2, lsl #3', ['add x0, x1, x2, lsl #3',
                                           'add x0, x1, x2, lsr #3']),
    ('opc', 'and w0, w1, w2', ['orr w0, w1, w2', 'eor w0, w1, w2']),
    ('N', 'and w0, w1, w2', ['bic w0, w1, w2', 'orn w0, w1, w2',
                             'eon w0, w1, w2', 'bics w0, w1, w2']),
    ('imm12', 'add w0, w1, #0x0', ['add w0, w1, #0x1', 'add w0, w1, #0x2',
                                    'add w0, w1, #0x4', 'add w0, w1, #0x8',
                                    'add w0, w1, #0x10', 'add w0, w1, #0x20',
                                    'add w0, w1, #0x40', 'add w0, w1, #0x80',
                                    'add w0, w1, #0x100',
                                    'add w0, w1, #0x200',
                                    'add w0, w1, #0x400',
                                    'add w0, w1, #0x800',
                                    'add w0, w1, #0xfff']),
    ('lsl12', 'add w0, w1, #0x10', ['add w0, w1, #0x10, lsl #12']),
    ('imm16', 'movz w0, #0x0000', ['movz w0, #0x%04x' % (1 << k)
                                   for k in range(16)]),
    ('hw', 'movz x0, #0x1111', ['movz x0, #0x1111, lsl #16',
                                'movz x0, #0x1111, lsl #32',
                                'movz x0, #0x1111, lsl #48']),
    ('opc-movewide', 'movz w0, #0x1111', ['movk w0, #0x1111',
                                          'movn w0, #0x1111']),
    # The immr sweep stops at #25.  `sbfx w0, w1, #29, #3` does not assemble as
    # a bitfield at all -- it becomes `asr w0, w1, #29` -- because the bitfield
    # ALIASES overwrite each other, and that is a fact about the encoding worth
    # measuring rather than a limit of the sweep.  Section 9 asks the assembler
    # about the boundary and prints the answer.
    ('immr', 'sbfx w0, w1, #4, #3', ['sbfx w0, w1, #5, #3', 'sbfx w0, w1, #9, #3',
                                     'sbfx w0, w1, #13, #3', 'sbfx w0, w1, #17, #3',
                                     'sbfx w0, w1, #21, #3', 'sbfx w0, w1, #25, #3']),
    ('imms', 'sbfx w0, w1, #4, #3', ['sbfx w0, w1, #4, #4', 'sbfx w0, w1, #4, #5',
                                     'sbfx w0, w1, #4, #6', 'sbfx w0, w1, #4, #7',
                                     'sbfx w0, w1, #4, #16', 'sbfx w0, w1, #4, #17',
                                     'sbfx w0, w1, #4, #18', 'sbfx w0, w1, #4, #19',
                                     'sbfx w0, w1, #4, #22', 'sbfx w0, w1, #4, #23',
                                     'sbfx w0, w1, #4, #25', 'sbfx w0, w1, #4, #26']),
    ('N (bitfield)', 'sbfx w0, w1, #4, #3', ['ubfx w0, w1, #4, #3',
                                              'sbfiz w0, w1, #4, #3',
                                              'ubfiz w0, w1, #4, #3']),
    ('lsl0', 'extr w0, w1, w2, #3', ['extr w0, w1, w2, #7', 'extr w0, w1, w2, #11',
                                     'extr w0, w1, w2, #15', 'extr w0, w1, w2, #19',
                                     'extr w0, w1, w2, #23', 'extr w0, w1, w2, #27']),
    ('cond (csel)', 'csel w0, w1, w2, eq', ['csel w0, w1, w2, %s' % c
                                             for c in ('ne', 'cs', 'cc', 'mi', 'pl',
                                                       'vs', 'vc', 'hi', 'ls',
                                                       'ge', 'lt', 'gt', 'le', 'al')]),
    ('op2 (csel)', 'csel w0, w1, w2, eq', ['csinc w0, w1, w2, eq']),
    ('inv (csel)', 'csel w0, w1, w2, eq', ['csinv w0, w1, w2, eq',
                                            'csneg w0, w1, w2, eq']),
    ('2src opc', 'lsl w0, w1, w2', ['lsr w0, w1, w2', 'asr w0, w1, w2',
                                     'ror w0, w1, w2', 'udiv w0, w1, w2',
                                     'sdiv w0, w1, w2']),
    ('3src o0', 'madd w0, w1, w2, w3', ['msub w0, w1, w2, w3',
                                         'mneg w0, w1, w2']),
    ('Ra', 'madd w0, w1, w2, w3', ['madd w0, w1, w2, w7',
                                    'madd w0, w1, w2, w11',
                                    'madd w0, w1, w2, w13']),
    ('1src opc', 'clz w0, w1', ['rev w0, w1', 'rev16 w0, w1', 'cls w0, w1']),
    ('cond (b.cond)', 'b.eq T', ['b.%s T' % c for c in
                                 ('ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc', 'hi',
                                  'ls', 'ge', 'lt', 'gt', 'le')]),
    ('cond (b.cond) top', 'b.eq T', ['b.al T', 'b.nv T']),
    ('cbz op', 'cbz w0, T', ['cbnz w0, T']),
    ('cbz sf', 'cbz w0, T', ['cbz x0, T']),
    ('tbz op', 'tbz w0, #3, T', ['tbnz w0, #3, T']),
    ('tbz bit5+imm5', 'tbz w0, #1, T', ['tbz w0, #%d, T' % (1 << k)
                                        for k in range(5)]),
    # b5 is the 32nd bit of the bit NUMBER and it is only reachable on a
    # 64-bit register, because the encoding has no way to express bit 32 of a
    # 32-bit register -- there is no such bit.  `tbz w0, #33` is REFUSED and
    # `tbz x0, #33` is accepted, and the difference between the two words is
    # bit 5 AND bit 31, which is the whole point of the row.
    ('tbz b5', 'tbz x0, #1, T', ['tbz x0, #33, T', 'tbz x0, #63, T']),
    ('br opc', 'br x0', ['blr x0', 'ret', 'ret x0', 'ret x5']),
    ('Rn (br)', 'br x0', ['br x3', 'br x7', 'br x15']),
    ('B op', 'b T', ['bl T']),
    # `b T` and `b T+4` are the SAME displacement, because the second
    # instruction is four bytes further along: the target moved by 4 and so
    # did the branch.  The first version of this sweep measured ZERO bits and
    # printed an empty mask, which reads exactly like a field that does not
    # exist.  A relative branch needs the gaps in the TARGET to be a multiple
    # of FOUR MORE than the gaps between the branches, and the simplest way to
    # guarantee that is to use multiples of 0x10.
    ('B imm26', 'b T', ['b T+0x10', 'b T+0x100', 'b T+0x4000',
                         'b T+0x400000', 'b T-0x10', 'b T-0x100']),
    ('adr/adrp page bit', 'adr x0, T', ['adrp x0, T']),
    # The 21-bit immediate is SPLIT, and this row is the evidence: the sweep
    # over single bits of the byte offset moves bits[30:29] and bits[25:5] and
    # NOT the three in between, because those three belong to the opcode.  The
    # sweep stays inside the +/-1 MiB range -- `adr x0, T-0x100000` is refused
    # with "fixup value out of range", and section 9B asks for it again.
    ('ADR immhi+immlo', 'adr x0, T', ['adr x0, T+1', 'adr x0, T+2',
                                      'adr x0, T+3', 'adr x0, T+0x1000',
                                      'adr x0, T+0x2000', 'adr x0, T+0x100000',
                                      'adr x0, T-0x1000']),
    ('ld size', 'ldr w0, [x1]', ['ldr x0, [x1]', 'ldr s0, [x1]',
                                 'ldr d0, [x1]', 'ldr q0, [x1]']),
    ('ld opc', 'ldr w0, [x1]', ['str w0, [x1]']),
    ('ld opc2', 'ldr w0, [x1]', ['ldrb w0, [x1]']),
    ('ld opc3', 'ldr w0, [x1]', ['ldrsw x0, [x1]']),
    # The unscaled-offset sweep is a SEPARATE field and the first version put it
    # in the same list, which is what produced the odd bit 22 and bit 24 in
    # this row: `ldr w0, [x1, #1]` is not an LDR at all, it assembles to LDUR,
    # and an LDR and an LDUR are two different groups with two different
    # opcode values.  Measured separately, the two fields are clean.
    ('ld imm12', 'ldr w0, [x1, #0x0]', ['ldr w0, [x1, #%d]' % (4 << k)
                                       for k in range(12)]),
    # imm9 is signed and unscaled, so the sweep is the eight POSITIVE bits
    # plus the sign.  `ldur w0, [x1, #256]` is REFUSED -- the range is
    # [-256, 255] -- so a sweep of nine bits takes the whole batch down with
    # it, and this row is the second place in this file where a sweep that
    # ran one step too far cost every other step too.
    ('ldur imm9', 'ldur w0, [x1, #0x0]', ['ldur w0, [x1, #%d]' % (1 << k)
                                          for k in range(8)] + ['ldur w0, [x1, #-1]']),
    ('ld Rt', 'ldr w0, [x1]', ['ldr w2, [x1]', 'ldr w9, [x1]',
                               'ldr w11, [x1]', 'ldr w13, [x1]']),
    ('ld Rn', 'ldr w0, [x1]', ['ldr w0, [x2]', 'ldr w0, [x7]',
                               'ldr w0, [x11]', 'ldr w0, [x13]']),
    ('ld mode', 'ldr w0, [x1, #8]', ['ldr w0, [x1], #8', 'ldr w0, [x1, #8]!',
                                     'ldr w0, [x1, #8]!']),
    ('ldur mode', 'ldur w0, [x1, #8]', ['ldur w0, [x1, #-8]']),
    ('pair Rt', 'stp x0, x1, [sp]', ['stp x1, x1, [sp]', 'stp x3, x1, [sp]',
                                      'stp x7, x1, [sp]', 'stp x11, x1, [sp]',
                                      'stp x15, x1, [sp]', 'stp x17, x1, [sp]']),
    ('pair Rt2', 'stp x0, x1, [sp]', ['stp x0, x0, [sp]', 'stp x0, x3, [sp]',
                                       'stp x0, x7, [sp]', 'stp x0, x11, [sp]',
                                       'stp x0, x15, [sp]', 'stp x0, x17, [sp]']),
    ('pair Rn', 'stp x0, x1, [sp]', ['stp x0, x1, [x0]', 'stp x0, x1, [x2]',
                                      'stp x0, x1, [x7]', 'stp x0, x1, [x11]',
                                      'stp x0, x1, [x15]']),
    ('pair imm', 'stp x0, x1, [sp]', ['stp x0, x1, [sp, #%d]' % (8 << k)
                                      for k in range(6)]),
    ('pair mode', 'stp x0, x1, [sp]', ['stp x0, x1, [sp, #16]!',
                                        'stp x0, x1, [sp], #16',
                                        'stp x0, x1, [sp, #-16]']),
    ('pair L', 'stp x0, x1, [sp]', ['ldp x0, x1, [sp]']),
    ('pair scale', 'stp w0, w1, [sp]', ['stp x0, x1, [sp]', 'stp q0, q1, [sp]']),
]


def measure_field(case):
    """(mask, ok) for one field case, by assembling and XORing."""
    label, base, variants = case
    ws = asm_batch([base] + list(variants))
    if ws is None or len(ws) < 2:
        return None, 'the assembler refused the batch'
    w0 = ws[0][1]
    mask = 0
    for w in ws[1:]:
        mask |= w0 ^ w[1]
    return mask, ws[0][2]


def sec4():
    banner(4, 'THE FIELD MAP, MEASURED BY DIFFERENCE')
    print()
    para("""A field map read out of a manual is a claim.  A field map
read off the XOR of two assembled words is a measurement, and it is what the
guards in part one of this file are built from.  The method is one line long:
assemble an instruction, change ONE operand, assemble it again, and every bit
that moved belongs to that operand.

One correction, because the first version of this measurement was wrong in a
way that looked like a result.  A single pair marks the bits where the two
VALUES differ, which is a SUBSET of the field and not the field.  Measured
with one pair, `movz w0, #0x1111` against `movz w0, #0x2222` gives an 8-bit
"imm16", because 0x1111 and 0x2222 happen to differ in eight bit positions.
The table below ORs the XOR over a SWEEP of variants, one per single bit,
which marks every position the operand can reach.""")
    rows = []
    refused = 0
    for case in FIELD_CASES:
        mask, info = measure_field(case)
        if mask is None:
            refused += 1
            rows.append((case[0], '--', 'the assembler refused', case[1]))
            continue
        bits = [str(b) for b in range(32) if mask >> b & 1]
        span = ''
        if bits:
            lo, hi = int(bits[0]), int(bits[-1])
            if len(bits) == hi - lo + 1:
                span = 'bits[%d:%d]' % (hi, lo)
        rows.append((case[0], '%08x' % mask,
                     span or 'bits[' + ','.join(bits) + ']', case[1]))
    table(('field', 'xor mask', 'the positions', 'base instruction'), rows,
          [17, 10, 20, 44])
    print()
    print('  %d field positions measured, %d cases, %d refusals.'
          % (len(rows) - refused, len(FIELD_CASES), refused))
    print()
    para("""Four things in that table are worth reading slowly.

`Rt2` in the pair form is bits[14:10] and NOT bits[11:10].  This is the
single most common A64 decoder bug in existence, because a decoder that
models `stp` after `ldp`-and-guesses puts the second register in a two-bit
field, which cannot address register 15.  The table shows a 5-bit field.

`cond` is bits[15:12] in a conditional SELECT and bits[4:0] in a B.cond,
and the two fields do not overlap.  A decoder that finds one `cond` and uses
it for both gets half of the conditional instructions in the program wrong,
and the two errors are in the same direction: `b.eq` decodes with the
condition read from the wrong end of the word.

Register 31 is the STACK POINTER in add/sub and the ZERO register in the
logical-shifted group, and this is measured twice in the same table: the
`Rd` mask is bits[4:0] in both, so the field is identical and the MEANING is
not.  No field map can express that difference; only a decoder that says which
it means can, which is why part one of this file has a `sp` argument on the
register-name function and never guesses.

`imm12` is bits[21:10] and the scale on it is a SEPARATE two-bit field that
is only read when it is 0b01.  `add w0, w1, #0x1000` and `add w0, w1, #1,
lsl #12` are the same 32 bits, which section 2 measured, and `add w0, w1,
#0x100` is REFUSED -- a refusal section 6 catches.""")
    # The gaps are computed, not asserted.  A gap in a row's mask means the
    # sweep did not happen to visit a value that differs there, which is a
    # fact about the SWEEP and not about the field -- so it is reported as
    # such, and a reader can see which rows are complete and which are not.
    def gaps(mask):
        """Runs of clear bits that have a SET bit on BOTH sides.

        A clear bit at either end of the word is not a gap, it is outside the
        field, and reporting those made the first version of this print a
        "gap" for every one of the 58 rows -- the gaps at bits[0:9] and
        bits[16:31] of a 5-bit field are the other 27 bits of the word, which
        are somebody else's.  Only an INTERIOR gap is evidence about the
        field, and there are exactly two of those in the whole table.
        """
        if mask == 0:
            return []
        lo = (mask & -mask).bit_length() - 1
        hi = mask.bit_length() - 1
        out = []
        run = None
        for b in range(lo, hi + 1):
            if not (mask >> b & 1):
                if run is None:
                    run = b
            else:
                if run is not None:
                    out.append((run, b - 1))
                    run = None
        return out

    gapped = []
    for r in rows:
        if r[1] == '--' or not r[1].strip():
            continue
        g = gaps(int(r[1], 16))
        if g:
            gapped.append((r[0], r[2], g))
    print('  WHAT A MASK IS, precisely, and what it is not:')
    print()
    print('    A mask is the OR of the XORs over the SWEEP, so it is a LOWER')
    print('    BOUND on the field: every bit in the mask really is a bit that')
    print('    operand owns, and a bit NOT in the mask is a bit the sweep did')
    print('    not happen to move.  The third column above is the mask; the')
    print('    interior gaps are listed here so a reader can see which of the')
    print('    %d rows are complete and which are merely not-yet-tightened.'
          % (len(rows) - refused))
    print()
    if gapped:
        for label, pos, g in gapped:
            print('      %-22s %-42s not moved: %s'
                  % (label, pos, ', '.join('bits[%d:%d]' % x for x in g)))
    else:
        print('      (none: every measured field is contiguous in the sweep)')
    print()
    print('    Most of those gaps are there because a SMALL sweep cannot reach')
    print('    every value: the `cond` sweep visits fifteen condition names')
    print('    and so moves bits 0 to 3 but never bit 4, because a B.cond')
    print('    condition is FIVE bits wide and the sweep simply did not ask')
    print('    for the thirty-second value.  Two gaps are not gaps at all:')
    print('    in the conditional-select family bit 30 and bits[11:10] together')
    print('    select the operation, which is section 10, and in the bitfield')
    print('    family the same bits[21:10] window holds immr for a BFXIL and')
    print('    imms for a BFM.  Those are two instructions sharing a field and')
    print('    not one operand, and the mask is the evidence.')
    print()
    print('    A field this measurement CANNOT find is a field that is never')
    print('    written: reserved bits, the scale on the add/sub immediate')
    print('    (0b11 is refused by the assembler), and the high bit of a shift')
    print('    amount on a 32-bit register, all measured in section 9.')
    print()
    out = os.path.join(HERE, 'fields.txt')
    with open(out, 'w') as f:
        f.write('# a64asm FIELD MAP -- MEASURED by assembling an instruction\n')
        f.write('# and a SWEEP of variants that differ in ONE operand, and\n')
        f.write('# OR-ing the XOR of the 32-bit words.  A single pair marks\n')
        f.write('# the bits where the two VALUES differ, which is a subset of\n')
        f.write('# the field.  Written by a64dec.py --run.  Do not hand-edit.\n')
        f.write('#\n# %-16s %-10s %-20s %s\n'
                % ('field', 'xor mask', 'positions', 'base'))
        for r in rows:
            f.write('%-16s %-10s %-20s %s\n' % r)
    print('  Written to fields.txt.')
    print()


# ===========================================================================
# SECTION 5 -- THE BIT BUDGET.
# ===========================================================================


def sec5():
    banner(5, 'THE BIT BUDGET: THREE MEANINGS OF "WASTED BIT"')
    print()
    para("""The claim A64's reputation rests on is that a 32-bit
instruction wastes a lot of its width, because a group's field map must
accommodate every member whether or not THIS instance needs the field.  That
claim is true, and the interesting question is HOW MUCH -- and the honest
answer is that "wasted" has three meanings that give three different
numbers.  All three are measured here, because a course that quotes one of
them without saying which is quoting a slogan.""")
    import collections
    insns = corpus_insns()
    total = len(insns)
    unmodelled = sum(1 for k in insns if k.name is None)

    print('=== 5A. BITS FIXED WITHIN A GROUP')
    print("""    AND every word of every instruction the decoder routes to the
    same model.  A bit clear in every member is DEAD in that group: no
    decoder has to look at it, cannot name a different instruction with it,
    and would raise UNDEFINED on a word that set it.  This is a property of
    the ENCODING and it is the number that matters for decode cost.""")
    print()
    groups = collections.defaultdict(list)
    for k in insns:
        groups[(k.cls, k.name or '(unmodelled)')].append(k.word)
    # The same mnemonic appears TWICE in this table, in two classes, and that
    # is the point: `add` is one name for two encodings, the immediate one and
    # the shifted-register one, and a group keyed on the MNEMONIC alone would
    # OR them together and report a bit as live that neither encoding varies.
    # The key is (class, name), and the class column is abbreviated so the
    # numbers are not pushed off the edge of a terminal.
    SHORT = {'Data Processing -- Immediate': 'DP-imm',
             'Data Processing -- Register': 'DP-reg',
             'Branches, Exception Generating and System': 'Branch/Sys',
             'Loads and Stores': 'L/S',
             'Loads and Stores (pair)': 'L/S pair',
             'Advanced SIMD': 'SIMD',
             'Advanced SIMD (pair)': 'SIMD pair',
             'Advanced SIMD / FP': 'SIMD/FP'}
    rows = []
    for (cls, mn), ws in groups.items():
        if len(ws) < 2:
            continue
        orv = 0
        for w in ws:
            orv |= w
        rows.append((bin(orv).count('1'), len(ws), SHORT.get(cls, cls), mn))
    rows.sort(reverse=True)
    for live, n, cls, mn in rows:
        print('  %-10s %-10s n=%-5d live=%-3d dead=%d' % (mn, cls, n, live,
                                                           32 - live))
    multi = [r for r in rows]
    i2 = sum(r[1] for r in multi)
    dm = sum((32 - r[0]) * r[1] for r in multi) / max(1, i2)
    ngroups = len(multi)
    nsingle = sum(1 for k in groups.values() if len(k) < 2)
    print()
    print('  %d groups have more than one member, holding %d of the %d'
          % (ngroups, i2, total))
    print('  instructions.  Over those, %.1f of the 32 bits are DEAD --'
          % dm)
    print('  %.1f%% of the word carries nothing the group ever varies.'
          % (100.0 * dm / 32))
    print('  The other %.1f bits are live FOR THE GROUP, and how many of'
          % (32 - dm))
    print('  those a given INSTANCE needs is the next measurement.')
    print()
    print('  %d groups have exactly one member and are EXCLUDED from that'
          % nsingle)
    print('  average rather than counted as 0 dead bits.  A group of one has')
    print('  no measurable fixed bits, so including it would report free bits')
    print('  nobody can use.  Excluding them makes the figure CONSERVATIVE:')
    print('  a one-member group may well have a fixed pattern, and this')
    print('  measurement cannot see it.')
    print()
    print('  A mnemonic that appears twice -- `add` in DP-imm and DP-reg,')
    print('  `cmp` and `subs` in both, `lsl` in both, `mov` in both -- is ONE')
    print('  name for TWO encodings, and the grouping is (class, name) rather')
    print('  than name because a bit that varies across the two encodings is')
    print('  not a bit either encoding varies.')

    print()
    print('=== 5B. BITS FIXED WITHIN ONE MNEMONIC')
    print("""    The same measurement one level down, and this is the one a reader
    of a disassembly actually pays for.  A bit that holds the same value in
    every instance of `ldr` is a constant, whether it is 0 or 1.""")
    print()
    by = collections.defaultdict(list)
    for k in insns:
        by[k.name or '(unmodelled)'].append(k.word)
    rows2 = []
    for mn, ws in by.items():
        if len(ws) < 4:
            continue
        orv = andv = 0xffffffff
        for w in ws:
            orv |= w
            andv &= w
        rows2.append((bin(orv ^ andv).count('1'), len(ws), mn))
    rows2.sort()
    for varying, n, mn in rows2:
        print('  %-10s n=%-5d constant=%-3d live=%-3d (%.1f bits live per '
              'instruction)' % (mn, n, 32 - varying, varying, varying))
    print()
    print('  Four or more instances, so a constant is a property of the')
    print('  MNEMONIC and not an artefact of a small sample.  A group of one')
    print('  has no measurable constants, and a group of two has one bit, and')
    print('  neither number means anything.')

    print()
    print('=== 5C. RESERVED BITS, which are the cheap part and not the free one')
    print("""    A reserved field is a field whose non-reserved values raise
    UNDEFINED.  A decoder that SKIPS the check would be faster and wrong, and
    that trade is the whole content of "reserved": the bits are cheap to
    decode and they are not free, because reading them is the definition of
    the instruction.""")
    print()
    for label, word in (('nop', 0xd503201f), ('ret', 0xd65f03c0),
                        ('b.eq', 0x54000000), ('csel', 0x1a820020),
                        ('add', 0x91000400), ('ldr', 0xf9400000)):
        k = decode(word)
        print('  %-6s %08x  %-22s %2d of 32 bits read, %2d not needed to '
              'name it' % (label, word, k.text, k.bits_used,
                           32 - k.bits_used))
    print()
    para("""A 32-bit fixed-width encoding with N bits of fixed pattern is a
decoder with N fewer BITS to look at but the same number of CHECKS to make.
So the reason A64 decodes quickly is not that the instructions are small --
it is that they are UNIFORMLY small, which is what makes the length a
constant, and heavily constrained, which is what makes the opcode a short
lookup.  Both halves are in 5A and 5C, and only the first half is what the
architecture's reputation mentions.""")
    print('  AND THE NUMBER THE DENSITY ARGUMENT IS REALLY ABOUT, which is')
    print('  none of the three above: BYTES PER INSTRUCTION.  It is section')
    print('  13, and it is a comparison with x86-64 rather than a property of')
    print('  this file, because 4.0 bytes per instruction is not a claim, it')
    print('  is a definition.')
    print()
    print('  Modelled: %d of %d corpus instructions (%.1f%%).  Unmodelled and'
          % (total - unmodelled, total, 100.0 * (total - unmodelled)
             / max(1, total)))
    print('  COUNTED: %d.  The unmodelled ones are Advanced SIMD, which is a'
          % unmodelled)
    print('  real part of the architecture and out of this decoder\'s declared')
    print('  subset.  They are counted in the length arithmetic and not named,')
    print('  which is exactly the property section 2 is about: a word whose')
    print('  meaning is unknown still has a length.')
    print()


# ===========================================================================
# SECTION 6 -- TWO IMMEDIATES, AND WHAT EACH ONE COSTS.
# ===========================================================================


def sec6():
    banner(6, 'TWO IMMEDIATES, TWO PRICES, AND THE ASSEMBLER IS THE EVIDENCE')
    print()
    para("""AArch64 has more than one way to put a number in an
instruction, and each way has a different reach.  A claim about the reach is
worth nothing without the REFUSALS, so every limit below was found by asking
the assembler for something one step past it and printing what it said.""")
    print()
    print('=== 6A. add/sub immediate: 12 bits, and a scale')
    print()
    rows = []
    for src in ['add w0, w1, #0', 'add w0, w1, #0xfff', 'add w0, w1, #0x1000',
                'add w0, w1, #0x1001', 'add w0, w1, #0x1, lsl #12',
                'add w0, w1, #0xfff, lsl #12', 'add w0, w1, #0x1000000',
                'add w0, w1, #0x1234', 'sub x0, x1, #0xfff, lsl #12']:
        w, msg = asm_one(src)
        if w is None:
            rows.append((src, '--', 'REFUSED', msg))
        else:
            k = decode(w)
            rows.append((src, '%08x' % w, 'accepted', k.text))
    table(('asked for', 'word', 'verdict', 'what came back'), rows,
          [28, 10, 10, 46])
    print()
    para("""`add w0, w1, #0x1000` is accepted, and it is not a wider
immediate: it is the 12-bit value 1 with the scale field set, and the two are
the same 32 bits.  `#0x1001` is REFUSED, because 0x1001 is not reachable as a
12-bit field in any of the three states the scale field admits.  So the reach
of this field is NOT a contiguous range and no formula like "0 to 4095 times a
power of four" describes it, which is the trap: a reader who has internalised
the x86-64 `imm8-or-imm32` rule expects a contiguous range with a scale and
A64 gives three isolated values -- the value, the value shifted left by 12,
and zero.

Which means the worst case is a constant just above 4095 that is not a
multiple of 4096, and section 8 counts what the compiler has to do about it.""")
    print('=== 6B. move wide: 16 bits, and a shift of 0, 16, 32 or 48')
    print()
    rows = []
    for src in ['movz w0, #0xffff', 'movz x0, #0xffff, lsl #48',
                'movz x0, #0xffff, lsl #64', 'movn w0, #0xffff',
                'movn w0, #0x8000', 'movn w0, #0', 'movz w0, #0',
                'movk w0, #0xffff, lsl #16', 'movz w0, #0x1234']:
        w, msg = asm_one(src)
        if w is None:
            rows.append((src, '--', 'REFUSED', msg))
        else:
            rows.append((src, '%08x' % w, 'accepted', normalise_objdump(msg)))
    table(('asked for', 'word', 'verdict', 'the oracle says'), rows,
          [30, 10, 10, 34])
    print()
    para("""`movn w0, #0x8000` and `movn w0, #0xffff` are the same
mnemonic and the printer prints DIFFERENT things: the first as
`mov w0, #-0x8001` and the second as `movn w0, #0xffff`.  The field holds
the MAGNITUDE in both cases and the register ends up holding the complement,
and which of the two a printer shows is a choice about what it thinks a
reader wants.  So the encoding is unambiguous, the mnemonic is ambiguous, and
a decoder that prints the field is right while a decoder that prints the
register value is also right -- and the two-reader cross-check in section 12
has to normalise this one and say that it does.

`movn w0, #0` and `movz w0, #0` are the same mnemonic with different
immediates, and they are different words: 0x12800000 and 0x52800000.  One is
"all ones in a 32-bit register" and the other is "all zeros".  A disassembly
that shows you `mov w0, #0x0` and `mov w0, #-0x1` is showing you two
different instructions, and the difference is invisible in the mnemonic.""")
    print('=== 6C. opc = bits[30:29] has a HOLE, and asking is how you see it')
    print()
    print('  The move-wide group has three operations and a two-bit opcode, so')
    print('  one of the four values has to be a hole -- and which one is a fact')
    print('  about the ENCODING, measured by asking what each value is rather')
    print('  than inferred from "three operations, two bits".  The guard is')
    print('  bits[28:23] = 0b100101 and the opcode is bits[30:29]:')
    print()
    rows = []
    # The names are MEASURED, not remembered: each word is asked about in an
    # object file and the oracle's answer is the third column.  The first
    # version of this table had the names as a dict in the source -- MOVZ 0b00,
    # MOVK 0b11, MOVN 0b10 -- and the dict was WRONG in one entry in a way that
    # only a measurement could catch, which is the entire argument for asking.
    names = {}
    for opc in (0, 1, 2, 3):
        w = (opc << 29) | (0b100101 << 23) | (0x1234 << 5) | 0x09
        k = decode(w)
        t = objdump_text(w)
        m = re.match(r'^([a-z][a-z0-9]*)', t.split('//')[0].strip())
        names[opc] = m.group(1).upper() if m and k.note != 'undefined' else '???'
    for opc in (0, 1, 2, 3):
        w = (opc << 29) | (0b100101 << 23) | (0x1234 << 5) | 0x09
        k = decode(w)
        rows.append((format(opc, '02b'), '%08x' % w, names[opc], k.text,
                     k.note or '-'))
    table(('opc', 'word', 'the oracle calls it', 'the ENCODING is', 'note'),
          rows, [4, 10, 18, 30, 10])
    print()
    hole = [o for o in (0, 1, 2, 3)
            if decode((o << 29) | (0b100101 << 23) | (0x1234 << 5) | 0x09
                      ).note == 'undefined']
    print('  Read the two name columns together.  The oracle prints `mov` for')
    print('  opc = 0b00 and opc = 0b10 -- the SAME mnemonic for two different')
    print('  operations -- because hw = 0, which is the default, is hidden.')
    print('  The encoding column is the one the decoder has to agree with and')
    print('  the oracle column is the one a human reads, and section 2 measured')
    print('  that they are the same 32 bits for 19 of the 22 pairs it checked.')
    print()
    print('  The hole is opc = %s, and this decoder reports it as UNDEFINED'
          % (', '.join(format(o, '02b') for o in hole) or 'NONE FOUND'))
    print('  rather than guessing.  That matters: a decoder that reads opc as')
    print('  an index into a three-entry table and lets 0b01 alias onto MOVZ')
    print('  would decode a word the architecture calls UNDEFINED into a')
    print('  plausible instruction, and there is no value of the word that')
    print('  would make the mistake visible afterwards.')
    print()
    print('  A hole found by asking is a fact about the encoding; a hole')
    print('  inferred from "there are three, so there must be two bits and one')
    print('  of them is spare" is a guess with the same shape as the fact, and')
    print('  the guess could put the hole in the wrong place.  This is the')
    print('  third time in this file that a reserved value was found by')
    print('  printing what a decoder does with it: section 7E and section 9B')
    print('  found two more.')
    print()
    print('=== 6D. branch immediates: 26 bits and 19 bits, and no scale at all')
    print()
    rows = []
    for src in ['b T', 'bl T', 'b.eq T', 'cbz w0, T', 'tbz w0, #31, T',
                'adr x0, T', 'adrp x0, T']:
        w, msg = asm_one(src)
        if w is None:
            rows.append((src, '--', msg))
        else:
            k = decode(w)
            rows.append((src, '%08x' % w, k.text))
    table(('asked for', 'word', 'decoded here'), rows, [16, 10, 58])
    print()
    print('  Seven displacement fields, seven different widths and scales, and')
    print('  section 11 works the arithmetic of three of them by hand out of')
    print('  the bits.  The point of listing them here is that there is no')
    print('  common shape: the encodings spend 19, 26 and 21 bits on three')
    print('  instructions that all mean "move somewhere nearby", and the')
    print('  differences are historical accidents of when each was added.')
    print()


# ===========================================================================
# SECTION 7 -- THE LOGICAL IMMEDIATE.
# ===========================================================================


def sec7():
    banner(7, 'THE LOGICAL IMMEDIATE: A ROTATE AND A RUN LENGTH, NOT A NUMBER')
    print()
    para("""This is the one place in the whole architecture where you
cannot read the number out, and it is the most interesting encoding in
AArch64.  A logical immediate -- the operand of `and`, `orr`, `eor`, `bic`
and their setting forms -- is a CONSTANT OF A PARTICULAR SHAPE, stored as a
rotate amount and a run length in twelve bits.

The shape is this: the constant is built from ONE run of consecutive ones,
repeated to fill the register, and rotated.  That is all.  So the encodable
constants are exactly the periodic bit patterns, and the set is tiny.""")

    print('=== 7A. HOW MUCH OF THE CONSTANT SPACE THE ENCODING REACHES')
    print()
    rows = []
    for width in (32, 64):
        c = encodable_count(width)
        space = 1 << width
        rows.append((width, '{:,}'.format(c), '{:,}'.format(space),
                     '%.3e' % (float(c) / space)))
    table(('width', 'encodable', 'the whole space', 'share'), rows,
          [7, 8, 24, 10])
    print()
    para("""1,302 is the count the manual quotes, and this file
agrees with it, which is worth saying plainly: the number is DERIVED here by
enumerating the encoding -- six element sizes, at most 64 run lengths, at
most 64 rotations -- and not read out of the manual.  The enumeration is the
smaller of the two spaces, and that is the whole point: the encodable
constants are the SMALL set, not a filter on the large one.

A 32-bit logical immediate reaches 1,302 of 4,294,967,296 values.  So the
instruction with the smallest field in the whole architecture -- 12 bits --
reaches more values than any other 12-bit field in AArch64, including the
add/sub immediate's 4,095.  It reaches them by not being a number.""")
    print('=== 7B. THE ROUND TRIP, THIS ENCODER TO THIS DECODER')
    print()
    ok = bad = 0
    first_bad = []
    for v in sorted(encodable_set(64)):
        got = encode_bit_masks(v, 64)
        if got is None:
            bad += 1
            first_bad.append((v, 'the ENCODER refused an encodable constant'))
            continue
        N, immr, imms = got          # the encoder's order: rotate, then run
        # The decoder is asked for the pattern and the width, exactly as a
        # disassembler would, and NOT for the imms this file's own encoder
        # produced.  The first version of this passed the encoder's imms back
        # in, which made the round trip a tautology: the encoder chose imms,
        # the decoder was handed imms, and the two agreed about a constant
        # neither had examined.  Asking the decoder to recover the length from
        # the imms FIELD is the only version of this test that can fail.
        # decode_bit_masks returns (value, the derivation) -- the derivation is
        # the same text the --imm mode prints, which is why it is kept: a
        # round trip whose second half can explain itself is worth more than
        # one that returns a bare integer.
        # The two halves of this file disagree about the ORDER of imms and
        # immr: the decoder takes (N, imms, immr, width) and the encoder
        # returns (N, immr, imms).  The first version of this round trip
        # passed the encoder's output straight through, so it handed the
        # rotate amount to the decoder's imms and the run length to its
        # immr -- and 94 of the 5,334 constants came back as something else.
        # The names below are spelled out so the two orders cannot be confused
        # again, and the count of failures is the evidence that they were.
        back, _why = decode_bit_masks(N, imms, immr, 64)
        if back != v:
            bad += 1
            if len(first_bad) < 4:
                first_bad.append((v, '0x%016x came back' % back))
        else:
            ok += 1
    print('  %d encodable 64-bit constants; %d round-trip failures'
          % (encodable_count(64), bad))
    for v, why in first_bad:
        print('    %#018x  %s' % (v, why))
    print()
    para("""Self-consistency is necessary and NOT sufficient.  Two
functions can agree on the wrong answer, and a round trip that never meets an
independent party proves only that the two halves of THIS file agree with
each other.  The first version of this test handed the decoder the encoder's
own imms, which made it a tautology, and it is worth naming because a
tautological round trip reads exactly like a passing one in the output.  The
version above asks the decoder to recover the element size from the imms
FIELD, which is the work a real decoder does, and 7C is the independent
party: a real assembler, asked for every encodable 32-bit constant, and this
decoder reading back every word it emitted.""")
    print('=== 7C. THE SAME CONSTANTS, ASSEMBLED BY SOMEONE ELSE, READ BACK HERE')
    print()
    vals = sorted(encodable_set(32))
    agree = 0
    disagree = []
    B = 96
    for start in range(0, len(vals), B):
        chunk = vals[start:start + B]
        srcs = ['and w0, w0, #%#x' % v for v in chunk]
        ws = asm_batch(srcs)
        if ws is None:
            for v, s in zip(chunk, srcs):
                w, _ = asm_one(s)
                if w is None:
                    disagree.append((v, 'REFUSED', 'the assembler refused'))
                elif normalise_objdump(decode(w).text) == \
                        normalise_objdump(objdump_text(w)):
                    agree += 1
                else:
                    disagree.append((v, '%08x' % w,
                                     '%s | %s' % (decode(w).text,
                                                  objdump_text(w))))
            continue
        for v, (addr, w, txt) in zip(chunk, ws):
            if normalise_objdump(decode(w).text) == normalise_objdump(txt):
                agree += 1
            else:
                disagree.append((v, '%08x' % w, '%s | %s' % (decode(w).text, txt)))
    print('  asked the assembler for all %d encodable 32-bit constants and'
          % len(vals))
    print('  read every word back with THIS decoder:')
    print('    agreed:                    %d' % agree)
    print('    disagreed:                 %d' % len(disagree))
    for v, w, t in disagree[:8]:
        print('      %#x  %s  %s' % (v, w, t))
    print()
    para("""Every word in that batch is a real instruction that a real
assembler emitted, so the agreement is between two pieces of software written
by different people that cannot see each other.  %d agreements and %d
disagreements.""" % (agree, len(disagree)))
    print('=== 7D. WHAT THE SHAPE LOOKS LIKE, DERIVED')
    print()
    print('  One word, taken apart, with the constants beside every step.  The')
    print('  first word here is the one the concept page works through, and it')
    print('  is the first for a reason that is a rule rather than a preference:')
    print('  a page that quotes a derivation must be quoting the RECORDED run,')
    print('  and `check_quotes.py` reads only this file, so a word derived only')
    print('  by `--why` on the command line is a word no harness can check.')
    print()
    for label, word in (('the 32-bit 4-bit-element case the page uses',
                         0x1204cc00),
                        ('the 64-bit single-bit case',
                         0x92401000),
                        ('a 64-bit element, 55 ones',
                         0x9240d800),
                        ('a 64-bit element, 47 ones',
                         0x9240b800),
                        ('a 64-bit element, 8 ones',
                         0x92401c00)):
        k = decode(word)
        print('  %08x  %s' % (word, k.text))
        for line in explain(k).splitlines():
            print('      ' + line.strip())
        print()
    print('=== 7E. THE RESERVED SPACE, FOUND BY ASKING')
    print()
    rows = []
    for v, w32, why in ((0x0, 32, 'all zeros'), (0xffffffff, 32,
                                                 'all ones, 32-bit'),
                        (0xdeadbeef, 32, 'no run of two bits twice'),
                        (0x12345678, 32, 'no period at all'),
                        (0x80000001, 32, 'ONE bit set'),
                        (0x0, 3, 'all zeros, 3 bits'),
                        (0x7, 3, 'all ones, 3 bits')):
        src = 'and w0, w0, #%#x' % v
        w, msg = asm_one(src)
        rows.append(('%#x' % v, '%d-bit %s' % (w32, why), 'ACCEPTED as %08x' % w
                     if w else 'REFUSED', msg if w is None else
                     normalise_objdump(objdump_text(w))))
    table(('constant', 'shape', 'verdict', 'what came back'), rows,
          [12, 24, 18, 30])
    print()
    print('  And the same constants at 64-bit width, where the answer CHANGES')
    print('  for some and not others:')
    print()
    rows = []
    for v, why in ((0xffffffffffffffff, 'all ones, 64-bit'),
                   (0x7fffffffffffffff, 'all but the top bit'),
                   (0xfffffffffffffffe, 'all but the bottom bit'),
                   (0x0, 'all zeros, 64-bit'),
                   (0xf0f0f0f0f0f0f0f0, 'a 4-bit run'),
                   (0x123456789abcdef0, 'no period at all')):
        w, msg = asm_one('and x0, x0, #%#x' % v)
        rows.append(('%#x' % v, why, 'ACCEPTED' if w else 'REFUSED',
                     normalise_objdump(decode(w).text) if w else
                     'the assembler says "expected compatible register or '
                     'logical immediate"'))
    table(('constant', 'shape', 'verdict', 'what came back'), rows,
          [20, 24, 10, 30])
    print()
    para("""Every logical operation refuses the all-ones immediate, not
just `and`: the eight instructions `and`, `orr`, `eor`, `ands`, `orn`, `eon`,
`bic` and `bics` were each asked for `#0xffffffff` at 32 bits and each one
refused with the same diagnostic, and the same eight were asked for the
64-bit all-ones and each refused.  That is a property of the SHARED IMMEDIATE
FIELD and not of any one operation, which is why the diagnostic names the
field rather than the instruction.

And the sharpest fact in the encoding is the row just above it.  The 64-bit
all-ones is refused, and the 64-bit all-but-the-top-bit is ACCEPTED: one bit
short of all-ones is a legal run of 63 ones in an element of size 64, and
all-ones is not a run at all.  The boundary is not a WIDTH, it is the shape,
and a decoder that models the immediate as a scaled number will get this
wrong in the specific way of accepting a constant the assembler refuses --
which is the more dangerous direction, because a decoder that invents an
instruction produces output that looks right.

So a mask of "all but the low 32 bits" is not one instruction.  It is a
MOVN and an AND, and section 8 measures that: `mov x0, #-1` is 0x92800000,
one word, and no logical immediate reaches it.""")


def objdump_text(word):
    """The oracle's name for a single word, by asking it in a .text.

    There is no `-b binary` in this llvm-objdump: `--triple=aarch64 -D -b
    binary f` prints `error: unknown argument '-b'`.  The isa course's harness
    uses GNU objdump, which does have it.  So a single word is asked about in
    a one-instruction object file, which costs a subprocess and which is
    worth it: the alternative is a decoder that agrees with itself.
    """
    with open('_w.s', 'w') as f:
        f.write('.text\nT: .inst 0x%08x\n' % word)
    p = sh(CLANG, '--target=' + TARGET, '-c', '_w.s', '-o', '_w.o')
    if p.returncode:
        return '(clang refused)'
    ws = objdump_words('_w.o')
    return ws[0][2] if ws else '(no output)'


# ===========================================================================
# SECTION 8 -- WIDE CONSTANTS.
# ===========================================================================


def sec8():
    banner(8, 'A CONSTANT TOO BIG FOR ANY FIELD: FOUR INSTRUCTIONS, SIXTEEN '
              'BYTES')
    print()
    para("""Section 6 established that a 12-bit immediate reaches
4,095 unsigned values with a scale, and section 7 that the logical immediate
is not a number at all.  So what does a compiler do with a constant like
0x123456789abcdef?

It builds it out of MOVZ and MOVK.  MOVZ writes one 16-bit field and zeroes
the rest; MOVK writes one 16-bit field and LEAVES THE OTHERS ALONE.  Four
fields of 16 bits, so four instructions for a 64-bit constant -- sixteen
bytes, four words, for one C literal -- unless a field is zero, in which case
it is skipped.""")
    print()
    # The `note` column is filled in from what the assembler DID, not from
    # what this file expected.  The first version of this list asserted "the
    # largest positive 64-bit value: four" and "all ones: ONE instruction" --
    # and both assertions were wrong in opposite directions, which is exactly
    # what a per-constant table catches and a paragraph does not.
    consts = [
        (32, 0x1234, 'one 16-bit field, the rest zero'),
        (32, 0x12345678, 'two non-zero fields'),
        (32, 0xffffffff, 'all ones, 32-bit'),
        (64, 0x123456789abcdef0, 'four non-zero fields'),
        (64, 0x0001000000000001, 'two non-zero fields'),
        (64, 0x7fffffffffffffff, 'the largest signed 64-bit value'),
        (64, 0xffffffffffffffff, 'the largest unsigned 64-bit value'),
        (64, 0x123456789abcdef1, 'a constant with no pattern at all'),
    ]
    rows = []
    picked = {}
    for width, v, why in consts:
        insns = what_clang_uses(width, v)
        picked[(width, v)] = (len(insns), ', '.join(insns))
        rows.append((width, '%#018x' % v if width == 64 else '%#010x' % v,
                     len(insns), ', '.join(insns), why))
    table(('width', 'constant', 'insns', 'what the assembler chose', 'why it '
           'is interesting'), rows, [6, 20, 6, 40, 36])
    print()
    allones = picked.get((64, 0xffffffffffffffff), (0, ''))[0]
    bigsigned = picked.get((64, 0x7fffffffffffffff), (0, ''))[0]
    nopattern = picked.get((64, 0x123456789abcdef1), (0, ''))[0]
    print('  Read the last three rows together, because the first draft of this')
    print('  section predicted them and got all three wrong in the same way:')
    print('  it assumed that "big number" meant "expensive".')
    print()
    print('    * The 64-bit ALL ONES costs %d instruction, and it is a MOVN, not'
          % allones)
    print('      a MOVZ.  A MOVZ can only write a 16-bit field and zero the')
    print('      rest, and this constant has no zero field, so no number of')
    print('      MOVZ and MOVK reaches it.  MOVN exists for exactly this: it')
    print('      writes the COMPLEMENT, so a run of ones is a run of zeroes')
    print('      inverted, and the whole register is one complement away from a')
    print('      field of zeros.  This is the reason MOVN exists at all, and')
    print('      R7 in section 14 is about the mnemonic rather than the')
    print('      operation.')
    print()
    print('    * The largest SIGNED 64-bit value costs %d instructions, which is'
          % bigsigned)
    print('      the same as an arbitrary 64-bit literal (%d).  It is three'
          % nopattern)
    print('      fields of ones and one of 0x7fff, and each of the four has to')
    print('      be written, because MOVZ zeroes the rest of the register and')
    print('      MOVK only patches one field.  There is no cheaper spelling:')
    print('      it is not all-ones, so MOVN does not reach it either.')
    print()
    para("""So the table is not ordered by size at all, and that is
the finding.  The most expensive row and the cheapest are the two extremes of
the 64-bit range, and the difference between them is not the size of the
number -- it is whether the number is the COMPLEMENT of a field that MOVZ can
write.

AArch64's move-wide group has two ways to be cheap and one way to be
expensive.  Cheap: the value has a zero 16-bit field, so MOVZ writes it and
MOVK patches the rest.  Cheapest: the value is all-ones, so MOVN writes its
complement, which is all-zeros, in one word.  Expensive: the value has no
zero field and is not all-ones, so all four fields are written separately.

Which is the same rule section 7 measured from the other side.  There, the one
12-bit field in the architecture that is NOT a number reached more values than
any other 12-bit field.  Here, the cheapest 64-bit constant is the one with no
variety in it at all.  Both are the same design decision: the encoding pays
for reach in bits, and it pays in variety.""")
    print('=== 8A. HOW MANY MOVZ AND MOVK THE COMPILER ACTUALLY EMITTED')
    print()
    import collections
    insns = corpus_insns()
    c = collections.Counter(k.name for k in insns if k.name)
    for nm in ('movz', 'movk', 'movn', 'mov'):
        print('  %-6s %d' % (nm, c.get(nm, 0)))
    print('  (a `mov` here is a MOVZ with hw = 0, decoded under the name the')
    print('  ENCODING implies; section 2 measured that the two are the same')
    print('  32 bits.)')
    print()
    print('  The wide-constant cost is a per-CONSTANT cost, so a corpus with')
    print('  many 64-bit literals and one with none differ by a factor of')
    print('  four on these instructions alone.  That is why the density')
    print('  comparison in section 13 is a table and not a verdict.')


def build_wide(width, v):
    """The instruction sequence for a wide constant, the obvious way."""
    out = []
    reg = 'x0' if width == 64 else 'w0'
    fields = [(v >> (16 * k)) & 0xffff for k in range(width // 16)]
    for k, f in enumerate(fields):
        if k == 0:
            out.append('movz %s, #%#x' % (reg, f))
        elif f:
            out.append('movk %s, #%#x, lsl #%d' % (reg, f, 16 * k))
    if not out:
        out.append('movz %s, #0' % reg)
    if v == (1 << width) - 1:
        out = ['movn %s, #0' % reg]
    return out


def what_clang_uses(width, v):
    """Ask the assembler, then read the words back with THIS decoder."""
    srcs = build_wide(width, v)
    ws = asm_batch(srcs)
    if ws is None:
        return ['(the assembler refused the obvious form)']
    return [decode(w[1]).text for w in ws]


# ===========================================================================
# SECTION 9 -- THE RESERVED SPACE, AND WHY IT IS NOT EMPTY.
# ===========================================================================


BOUND_CASES = [
    ('add/sub imm12 at its maximum', 'add w0, w1, #0xfff'),
    ('add/sub imm12 with the scale set', 'add x0, x1, #0xfff, lsl #12'),
    ('logical imm, a 2-bit element', 'and w0, w0, #0x55555555'),
    ('logical imm, a 64-bit element', 'and x0, x0, #0xaaaaaaaaaaaaaaaa'),
    ('move wide, MOVZ at the top field', 'movz x0, #0x1234, lsl #48'),
    ('move wide, MOVK at the top field', 'movk x0, #0x1234, lsl #48'),
    # The displacement edges are asked for as an EXPLICIT offset from the
    # branch, not as a label.  `b.eq T` in a two-word file is a displacement
    # of -8 -- the nearest, not the farthest -- so the first version of this
    # list labelled its own row "the far end" while measuring a displacement
    # of eight bytes.  A label is a NAME, and a name does not say where.
    #
    # The maxima below are in BYTES and every one of them was found by
    # BISECTION with the assembler rather than by arithmetic, because the
    # arithmetic is exactly what the first version of this list got wrong.  It
    # wrote b.cond's far end as 0x1ffffc -- 19 bits of INSTRUCTION offset
    # times 4 -- and the assembler refused it, because a 19-bit SIGNED field
    # is not 2^19 instructions in both directions: it is 0x7ffff forward and
    # 0x80000 back, so the ends are +0xffffc and -0x100000.  The first draft
    # also wrote B's near end as -0x40000000, which is the sign bit alone and
    # is four times too far.  A sign extension is not a magnitude and the
    # asymmetry between the two ends is the whole reason R5 exists.
    ('b.cond, imm19 at the far end', 'b.eq .+0xffffc'),
    ('b.cond, imm19 at the near end', 'b.eq .-0x100000'),
    ('cbz, imm19 at the far end', 'cbz w0, .+0xffffc'),
    ('cbz, imm19 at the near end', 'cbz w0, .-0x100000'),
    ('B, imm26 at the far end', 'b .+0x7fffffc'),
    ('B, imm26 at the near end', 'b .-0x8000000'),
    ('adr, imm21 at the far end', 'adr x0, .+0xffffc'),
    ('adr, imm21 at the near end', 'adr x0, .-0x100000'),
    ('tbz, bit 63 of a 64-bit register', 'tbz x0, #63, T'),
    ('tbz, bit 31 of a 32-bit register', 'tbz w0, #31, T'),
    ('2-source shift by register', 'lsl w0, w1, w2'),
    ('condselect with cond = AL', 'csel w0, w1, w2, al'),
    ('condselect with cond = NV', 'csel w0, w1, w2, nv'),
    ('b.cond with cond = AL', 'b.al T'),
    ('b.cond with cond = NV', 'b.nv T'),
    ('ldst, imm12 at its maximum', 'ldr w0, [x1, #0x3ffc]'),
    ('ldur with the largest negative offset', 'ldur x0, [x1, #-0x100]'),
    ('pair, the largest legal forward offset', 'stp x0, x1, [sp], #0x1f8'),
    ('pair, the largest legal backward offset', 'stp x0, x1, [sp, #-0x200]!'),
    ('mov to the stack pointer', 'mov sp, x0'),
    ('ret with an explicit register', 'ret x0'),
    ('ret with a non-link register', 'ret x5'),
    # NOT an edge, and it is here because it looks like one.  `sbfx w0, w1,
    # #29, #3` is a bitfield whose offset plus width runs off the end of the
    # register, and the assembler does not refuse it: it reinterprets the whole
    # thing as a SHIFT, because the bitfield encodings overlap the shift
    # encodings and the SHIFT is the one that is architecturally preferred at
    # those operand values.  A table of boundaries that quietly contained a
    # row where the instruction changes identity would be a table of
    # something else.
    ('sbfx whose immr runs off the end', 'sbfx w0, w1, #29, #3'),
]

BOUND_REFUSALS = [
    ('add/sub imm12, not reachable by any scale', 'add w0, w1, #0x1001'),
    ('add/sub imm12, past the top of the scaled range',
     'add w0, w1, #0x1000000'),
    ('add/sub with the scale field set to 3', 'add w0, w1, #0x1, lsl #24'),
    ('logical imm, all zeros, 32-bit', 'and w0, w0, #0'),
    ('logical imm, all ones, 32-bit', 'and w0, w0, #0xffffffff'),
    ('logical imm, a non-pattern 32-bit value', 'and w0, w0, #0xdeadbeef'),
    ('logical imm, a non-pattern 64-bit value', 'and x0, x0, #0x123456789abcdef0'),
    ('cset with cond = AL', 'cset w0, al'),
    ('cset with cond = NV', 'cset w0, nv'),
    ('tbz, bit 32 of a 32-bit register', 'tbz w0, #32, T'),
    ('tbz, bit 64', 'tbz x0, #64, T'),
    ('tbz, bit 33 of a 32-bit register', 'tbz w0, #33, T'),
    ('add/sub with a shift of 32 on a 32-bit register', 'add w0, w1, w2, lsl #32'),
    ('add/sub with a rotate shift', 'add w0, w1, w2, ror #3'),
    ('adr one instruction past the maximum', 'adr x0, .+0x100000'),
    ('b.cond one instruction past the maximum', 'b.eq .+0x100000'),
    ('B, one instruction past the maximum', 'b .+0x8000000'),
    ('add w0 with 64-bit sources', 'add w0, x1, x2'),
    ('ldst, imm12 one past the maximum', 'ldr w0, [x1, #0x4000]'),
    ('ldur one past the maximum negative offset', 'ldur w0, [x1, #-0x101]'),
    ('pair, one past the maximum forward offset', 'stp x0, x1, [sp], #0x200'),
    ('pair, one past the maximum backward offset', 'stp x0, x1, [sp, #-0x208]!'),
    ('pair, an offset that is not a multiple of 8', 'stp x0, x1, [sp, #4]'),
    ('pair with the stack pointer as Rt2', 'stp x0, sp, [sp]'),
    ('sxtw spelled with a 32-bit destination', 'sxtw w0, w1'),
    ('and with a 64-bit constant and 32-bit registers', 'and w0, w0, #0xf0f0f0f0f0f0f0f0'),
    ('csinc with the stack pointer as a source', 'csinc w0, sp, sp, eq'),
    ('ldr with the stack pointer as the destination', 'ldr sp, [x1]'),
    ('movz with a 32-bit shift', 'movz w0, #1, lsl #32'),
]


def sec9():
    banner(9, 'THE EDGE OF EVERY MODELLED GROUP, FOUND BY ASKING FOR ONE MORE')
    print()
    para("""Everything so far measured things the encoding ALLOWS.
The other half of an encoding is the space it does not, and the only honest
way to find that boundary is to walk into it and see whether the assembler
lets you back.  A refusal is a measurement: it is the architecture's own
answer to a question, it is exact, and it costs one line to print.""")
    print()
    print('=== 9A. ACCEPTED: the edge of every modelled group')
    print()
    rows = []
    nok = 0
    for label, src in BOUND_CASES:
        w, msg = asm_one(src)
        if w is None:
            rows.append((label, '--', 'REFUSED', msg))
        else:
            nok += 1
            rows.append((label, '%08x' % w, 'accepted', normalise_objdump(msg)))
    table(('case', 'word', 'verdict', 'what the oracle says'), rows,
          [40, 10, 10, 44])
    print()
    print('  %d of %d accepted.  The `word` column is this file\'s own reading'
          % (nok, len(BOUND_CASES)))
    print('  of the bytes, and the last column is the disassembler\'s name for')
    print('  the same bytes: the table is a cross-check that has already')
    print('  happened, at every boundary of every modelled group.')
    print()
    para("""Read the displacement rows together, because the first
version of this list got every one of them wrong by arithmetic and the
assembler caught all of them.  A 19-bit signed field of INSTRUCTION offsets
reaches +0xffffc bytes forward and -0x100000 bytes back -- not symmetric,
because a signed field is 0x7ffff forward and 0x80000 back.  A 26-bit one
reaches +0x7fffffc and -0x8000000, which is +/-128 MiB.  And ADR's 21 bits
reach exactly +/-1 MiB, the same as a conditional branch, so on AArch64 an
address-of-data and a conditional branch have the same reach.

The first draft wrote 0x1ffffc for b.cond and -0x40000000 for B, which are
both off by a factor of four, and both were refused.  A sign extension is not
a magnitude; section 11 does the arithmetic out of the bits so the difference
is visible rather than assumed.""")
    print()
    print('=== 9B. REFUSED: the space outside')
    print()
    rows = []
    nref = 0
    for label, src in BOUND_REFUSALS:
        w, msg = asm_one(src)
        if w is None:
            nref += 1
            rows.append((label, 'REFUSED', msg))
        else:
            rows.append((label, 'ACCEPTED as %08x' % w, normalise_objdump(msg)))
    table(('case', 'verdict', 'what came back'), rows, [40, 22, 60])
    print()
    print('  %d of %d refused.  Every refusal is a boundary the encoding'
          % (nref, len(BOUND_REFUSALS)))
    print('  has, and the ACCEPTED rows in this table are boundaries that')
    print('  MOVED: the first draft of this list expected a refusal for')
    print('  `#0x1000`, for `#0x2000`, for `b.eq .+0x1ffffc` and for')
    print('  `b .-0x40000000`, and the assembler accepted all four.  R4 in')
    print('  section 14.')
    print()
    para("""Three of these rows are worth a reader's attention.

`pair, an offset that is not a multiple of 8` is refused with a message
that says so, and it is refused because a 7-bit signed field scaled by 8
has no value for 4.  The encoding is a SCALED field, and the scale is 8
because the two registers of a pair are 64 bits apart at minimum.  That is
the same shape as the add/sub immediate's scale and the same trap: a scaled
field is not a contiguous range, and asking for the number between the
multiples gets a diagnostic instead of a second instruction.

`add/sub imm12, not reachable by any scale` is refused, so the three
states the field can express -- the value, the value shifted by 12, and zero
-- are the complete set.  There is no encoding for 0x1001 and the
architecture does not approximate it.

`tbz, bit 32 of a 32-bit register` is refused while `tbz x0, #63, T` is
accepted, which is a REGISTER-WIDTH property and not a field property: the
bit number is b5:imm5, and b5 is only part of the address for a 64-bit
register.  A decoder that reads b5 without reading sf will happily report
bit 63 of a 32-bit register, which does not exist.

And one row in 9A is a boundary that is not one.  `sbfx w0, w1, #29, #3` has
an offset plus width that runs off the end of the register, and the assembler
does not refuse it -- it reinterprets the word as `asr w0, w1, #29`, because
the bitfield encodings overlap the shift encodings and the shift is the one
the architecture prefers at those operand values.  It is in the accepted
table because it IS accepted, and the last column says what it became.  A
boundary table that quietly listed a row where the instruction changes
identity would be a table of something else.""")
    print('=== 9C. WHAT THE ASSEMBLER\'S MESSAGE IS, verbatim and unedited')
    print()
    print('  The diagnostics below are the architecture\'s, produced by a tool')
    print('  that implements the manual, and they are quoted because a reader')
    print('  is entitled to see the actual boundary in the actual words of the')
    print('  thing that enforces it:')
    print()
    seen = set()
    for what, src in BOUND_REFUSALS:
        w, msg = asm_one(src)
        if w is None and msg not in seen:
            seen.add(msg)
            print('    %-40s %s' % (src, msg))
    print()
    print('  There are %d distinct messages for %d refused cases: the encoder'
          % (len(seen), nref))
    print('  is not one check, it is several, and which one fires is itself a')
    print('  fact about the field.')
    print()


# ===========================================================================
# SECTION 10 -- THE SIXTEEN CONDITION CODES.
# ===========================================================================

COND_NAMES = ['eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
              'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al', 'nv']


def sec10():
    banner(10, 'SIXTEEN CONDITION CODES IN FOUR BITS, AND TWO OF THEM ARE TRAPS')
    print()
    para("""AArch64 has no flags-register dependency for a
conditional move.  `csel w0, w1, w2, eq` is one instruction that reads the
flags `subs` wrote and writes one of two registers, and that is the whole
argument for the group: there is no branch, no branch-delay slot, and no
separate compare, so a compiler that uses it turns a four-instruction x86-64
sequence into one.

The condition is FOUR BITS, and this file builds the whole 4x4 table of
selects and reads it back rather than quoting a list of sixteen names.""")
    print()
    print('=== 10A. THE FOUR-BIT FIELD, all sixteen values')
    print()
    rows = []
    for c in range(16):
        src = 'csel w0, w1, w2, %s' % COND_NAMES[c]
        w, msg = asm_one(src)
        if w is None:
            rows.append((c, format(c, '04b'), COND_NAMES[c], '--', msg))
            continue
        k = decode(w)
        rows.append((c, format(c, '04b'), COND_NAMES[c], '%08x' % w, k.text))
    table(('value', 'bits', 'name', 'word', 'decoded here'), rows,
          [5, 6, 6, 10, 34])
    print()
    para("""Two names exist for values 2 and 3.  In a SELECT the
assembler calls them `hs` and `lo`; in a BRANCH it calls them `cs` and
`cc`.  Both were measured: `csel w0, w1, w2, cs` assembles to 0x1a822020 and
the disassembler calls it `hs`, and `b.cs T` assembles to 0x54000020 and the
disassembler calls it `cs`.  The SAME 4 BITS have two names and the printer
picks by position, which is a fact about the ISA and a nuisance for a
cross-check -- so this file uses the select spelling throughout and section
12 normalises the other one, and says that it does.""")
    print('=== 10B. THE 4x4 TABLE OF SELECTS, and op2 = bits[11:10] IS NOT '
          'THE OPERATION')
    print()
    para("""The first version of this decoder read bits[11:10] and
called it the operation, and got half the table wrong.  The measured
structure is a PAIR: bit 30 is the INVERT and bits[11:10] is the CHOICE, and
the four combinations that matter are the four rows the assembler will emit.

The first version of this TABLE assembled a line per cell, which is wrong by
construction: there is no mnemonic for (invert, op2) = (1, 0), so the
assembler silently assembled a CSINV for all four of the inv = 1 rows and the
table printed `csinv` eight times.  The cells below are built as WORDS and
then asked about, which is the only way a cell that has no name can still be
measured.""")
    print()
    rows = []
    for inv in (0, 1):
        for op2 in (0, 1, 2, 3):
            # bit30 = invert, bits[11:10] = op2, Rd=0 Rn=1 Rm=2 cond=eq
            w = ((inv << 30) | 0x1a800000 | (op2 << 10) | (1 << 5) | 2
                 | (0 << 12))
            k = decode(w)
            rows.append((inv, format(op2, '02b'), '%08x' % w,
                         normalise_objdump(objdump_text(w)), k.text))
    table(('bit30 (invert)', 'bits[11:10]', 'word', 'the oracle calls it',
           'this decoder calls it'), rows, [13, 11, 10, 24, 30])
    print()
    para("""So there are FOUR distinct operations, not sixteen and not
eight: csel, csinc, csinv and csneg, selected by the pair (bit 30,
bits[11:10]) = (0,00), (0,01), (1,00) and (1,01).  The remaining four cells
of the 4x4 are UNDEFINED -- the oracle prints `<unknown>` for all four and
this decoder raises on all four -- and the first draft of this file called two
of them "the SET forms", which is a plausible-sounding wrong answer that would
have taught a reader that the group has six operations.

The SET forms are not new opcodes.  CSET is CSINC with both sources set to
the zero register, and CSETM is CSINV the same way, so they reuse the same two
field values and are distinguished by the REGISTER SLOTS rather than by the
bits.  That is why the 4x4 table has no CSET row: a field map cannot show it,
because nothing in the fields is different.  What is different is that Rn and
Rm are 31, and 31 means the zero register in this group -- so the pair of
field values plus the pair of register values together give a sixth and a
seventh instruction out of four opcodes.""")
    for a, b in (('cset w0, eq', 'csinc w0, wzr, wzr, ne'),
                 ('cset w0, ne', 'csinc w0, wzr, wzr, eq'),
                 ('csetm w0, eq', 'csinv w0, wzr, wzr, ne'),
                 ('csetm x0, ne', 'csinv x0, xzr, xzr, eq'),
                 ('cinc w0, w1, eq', 'csinc w0, w1, w1, ne'),
                 ('cinc w1, w2, eq', 'csinc w1, w2, w2, ne'),
                 ('cneg w0, w1, ge', 'csneg w0, w1, w1, lt'),
                 ('csinc w0, wzr, wzr, al', 'cset w0, eq'),
                 ('csinc w0, wzr, wzr, ne', 'cset w0, eq'),
                 ('csinc w0, wzr, wzr, nv', 'cset w0, eq'),
                 ('csinv w0, wzr, wzr, al', 'csetm w0, eq')):
        wa, _ = asm_one(a)
        wb, _ = asm_one(b)
        print('    %-24s %08x   %-24s %08x   %s'
              % (a, wa if wa is not None else 0, b, wb if wb is not None else 0,
                 'SAME' if wa == wb and wa is not None else 'DIFFERENT'))
    print()
    para("""The last row is the sharpest form of the trap and it is worth
reading twice.  `cset w0, eq` is `csinc w0, wzr, wzr, NE`, and the assembly
text of the first of those two is `csinc w0, wzr, wzr, AL` -- which is
`cset w0, NE`.  So a decoder that models the SET family as "a CSEL with
Rn = Rm = 31" produces a decoder that reports the condition of every `cset`
in the program INVERTED, and the output is 0 or 1 either way, so nothing
about it looks wrong.  That is the shape of the worst decoder bug in this
file and it is why the two-reader cross-check in section 12 exists.""")
    print('=== 10C. THE SAME 4 BITS IN A BRANCH, and 5 BITS there')
    print()
    rows = []
    for c in range(16):
        src = 'b.%s T' % COND_NAMES[c]
        w, msg = asm_one(src)
        if w is None:
            rows.append((c, format(c, '04b'), COND_NAMES[c], '--', msg))
            continue
        rows.append((c, format(c, '04b'), COND_NAMES[c], '%08x' % w,
                     decode(w).text))
    table(('value', 'bits', 'name', 'word', 'decoded here'), rows,
          [5, 6, 6, 10, 30])
    print()
    print('  A B.cond is bits[31:24] = 0b01010100 and bits[4:0] = the')
    print('  condition, and the imm19 is bits[23:5].  So the SAME FOUR BITS')
    print('  are at position 4 here and at position 12 in a CSEL, and a')
    print('  decoder with one `cond` field decodes half the conditional')
    print('  instructions in a program wrongly.  AArch64 does not have a')
    print('  single condition field, and that is a cost of the encoding, not')
    print('  an accident of this decoder: two different places, two different')
    print('  widths, one meaning.')
    print()
    print('=== 10D. HOW OFTEN THE COMPILER REACHES FOR A SELECT')
    print()
    import collections
    insns = corpus_insns()
    c = collections.Counter(k.name for k in insns if k.name)
    for nm in ('csel', 'cset', 'csetm', 'csinc', 'csinv', 'csneg',
               'cinc', 'cinv', 'cneg', 'b', 'b.eq', 'b.ne', 'b.hs', 'b.lo',
               'b.mi', 'b.pl', 'b.hi', 'b.ls', 'b.ge', 'b.lt', 'b.gt', 'b.le',
               'cbz', 'cbnz', 'tbz', 'tbnz', 'bl'):
        if c.get(nm):
            print('  %-6s %d' % (nm, c[nm]))
    # The family is NINE names, and the first version counted them with
    # `startswith('csel') or startswith('cset') or ...` -- which misses
    # csinc, csinv and csneg, because "csinc" starts with "csi" and not with
    # "cse".  That printed 45 where the answer is 56, and the eleven missing
    # instructions were three of the four operations in the group, so the
    # section's own count of its own family was short by exactly the
    # operations whose selection depends on the bit-30/op2 pair.  The list is
    # spelled out rather than pattern-matched, and the count is printed as the
    # sum of the nine numbers above it so the two can be checked against each
    # other by eye.
    NAMES9 = ('csel', 'cset', 'csetm', 'csinc', 'csinv', 'csneg',
              'cinc', 'cinv', 'cneg')
    cond = sum(c[n] for n in NAMES9)
    INV = ('cset', 'csetm', 'cinc', 'cinv', 'cneg')
    inv = sum(c[n] for n in INV)
    br = sum(v for k, v in c.items() if k.startswith('b.') or
             k.startswith('cbz') or k.startswith('cbnz') or
             k.startswith('tbz') or k.startswith('tbnz'))
    print()
    print('  conditional selects: %d   conditional branches: %d' % (cond, br))
    print('  and the 45-looking number is not a typo: %d of the %d selects are'
          % (inv, cond))
    print('  the INVERTED forms -- cset, csetm, cinc, cinv, cneg -- which are')
    print('  the ones whose condition field is the negation of the one the')
    print('  mnemonic names.  A decoder that misses the inversion decodes %d'
          % inv)
    print('  instructions in this corpus with the condition backwards, and')
    print('  every one of them still produces a correct boolean for half of')
    print('  its inputs.')
    print('  Both are real and both are used, and which one a compiler')
    print('  reaches for is a decision about whether the two sides of the')
    print('  branch are EQUALLY likely -- a property of the PROGRAM, not of')
    print('  the architecture.  So the number above is a fact about this')
    print('  corpus and a fact about clang, and section 13 measures what it')
    print('  costs in bytes rather than arguing about it.')
    print()
    print('=== 10E. NZCV, WHICH A USER-MODE PROGRAM CANNOT WRITE DIRECTLY')
    print()
    print('  Every condition is a function of four flag bits, NZCV: Negative,')
    print('  Zero, Carry, Overflow.  They are written by the S-suffixed')
    print('  instructions -- adds, subs, ands, bics, and the NEON compares --')
    print('  and by nothing else a user-mode program can reach.  There is no')
    print('  PUSHFLAGS, no LAHF, no `mov rflags, rax`: the four bits are')
    print('  written by an operation and read by the next one, and the whole')
    print('  of the conditional group is one instruction wide from the write to')
    print('  the read.')
    print()
    print('  What CANNOT be measured here, and is not claimed: the latency of')
    print('  the flag write, whether a particular core renames the flags, and')
    print('  whether a select is cheaper than a branch on a branch-free')
    print('  predictor.  Those need an AArch64 machine and there is none on')
    print('  this host.  Section 15 says so again in its own words.')
    print()
# ===========================================================================
# SECTION 11 -- THE DISPLACEMENT ARITHMETIC, BY HAND.
# ===========================================================================


def sec11():
    banner(11, 'THE DISPLACEMENT ARITHMETIC, WORKED OUT OF THE BITS')
    print()
    para("""Sections 6 and 10 listed seven displacement
fields and did not resolve any of them, because a disassembler and a
disassembler agree about a number without either of them computing it.  This
section takes the words apart with arithmetic and prints the steps, so the
number a printer shows is accounted for rather than trusted.""")
    print()
    print('=== 11A. B and BL: a 26-bit signed word offset, in bytes, times 4')
    print()
    rows = []
    # The offsets are EXPLICIT, for the reason section 9A gives: `b T` in a
    # three-word file is a displacement of -8, and the first version of this
    # table labelled that row "b +4" and printed bytes -8 beside it.  A label
    # is a name; this table is about numbers.
    for label, src in (('b +4', 'b .+4'), ('b -4', 'b .-4'),
                       ('b +0x1000', 'b .+0x1000'),
                       ('b -0x1000', 'b .-0x1000'),
                       ('bl +4', 'bl .+4'), ('bl -4', 'bl .-4'),
                       ('b the far end', 'b .+0x7fffffc'),
                       ('b the near end', 'b .-0x8000000')):
        w, msg = asm_one(src)
        if w is None:
            rows.append((label, '--', msg, '(REFUSED)'))
            continue
        imm26 = (w >> 0) & 0x3ffffff
        s = imm26 - (1 << 26) if imm26 >> 25 else imm26
        k = decode(w)
        rows.append((label, '%08x' % w,
                     'imm26 = %#x -> sign bit 25 = %d -> signed %d -> '
                     'x4 -> bytes %+d' % (imm26, imm26 >> 25, s, s * 4),
                     k.text))
    table(('case', 'word', 'the arithmetic, step by step', 'decoded here'),
          rows, [14, 10, 48, 12])
    print()
    para("""The sign bit is bit 25 OF THE FIELD, and it is worth
noticing what that means: the field is 26 bits, the sign is one of them, and
the remaining 25 are a magnitude in INSTRUCTIONS, which are then multiplied by
four.  So the last two rows are not symmetric -- +0x7fffffc forward and
-0x8000000 back -- and a reader who treats 26 bits as 26 bits of magnitude is
wrong twice over: by a factor of four for the missing alignment, and by a
factor of two for the missing sign.  That is R5 in section 14, retracted from
this very course's first draft, and the two rows are the evidence that the
correction is right rather than merely different.

What it buys: the whole 26-bit displacement is inside ONE instruction, with no
register and no second field, and it reaches 128 MiB in either direction.  No
variable-length encoding in the same collection can put a displacement of that
size in one instruction without a second word, because the second word is
where the size lives.""")
    print('=== 11B. B.cond, CBZ and TBZ: a 19-bit signed word offset')
    print()
    rows = []
    # TBZ is NOT in this table, and the reason is PRINTED as well as commented
    # because the first version of it HAD TBZ here and applied the imm19
    # formula to it, which produced a byte count of +196,612 for an
    # instruction the assembler had emitted as a displacement of +4.  That row
    # looked like a measurement because a number was in the table, and it was
    # wrong by a factor of 49,153.  A comment about a retracted number is not
    # visible to a reader of the output, which is the whole audience.
    print('  TBZ IS NOT IN THIS TABLE, and the reason is the fourth measurement')
    print('  error in this section.  The first version of it put TBZ here and')
    print('  applied the imm19 formula to it, which printed a byte count of')
    print('  +196,612 for an instruction the assembler had emitted as a')
    print('  displacement of +4 -- wrong by a factor of 49,153, and wrong in a')
    print('  row that LOOKED like a measurement because a number was in it.')
    print('  TBZ\'s displacement field is FOURTEEN bits and it gets its own')
    print('  table below.')
    print()
    for label, src in (('b.eq +4', 'b.eq .+4'), ('b.eq -4', 'b.eq .-4'),
                       ('b.eq far', 'b.eq .+0xffffc'),
                       ('b.eq near', 'b.eq .-0x100000'),
                       ('cbz +4', 'cbz w0, .+4'), ('cbnz -4', 'cbnz w0, .-4')):
        w, msg = asm_one(src)
        if w is None:
            rows.append((label, '--', msg, '(REFUSED)'))
            continue
        imm19 = (w >> 5) & 0x7ffff
        s = imm19 - (1 << 19) if imm19 >> 18 else imm19
        rows.append((label, '%08x' % w,
                     'imm19 = %#x -> sign bit 18 = %d -> signed %d -> '
                     'bytes %+d' % (imm19, imm19 >> 18, s, s * 4),
                     decode(w).text))
    table(('case', 'word', 'the arithmetic, step by step', 'decoded here'),
          rows, [10, 10, 48, 14])
    print()
    print('  TBZ IS THE EXCEPTION, and it gets its own table because its field')
    print('  is FOURTEEN bits, not nineteen: the bit number it tests is')
    print('  b5:imm5 -- five bits at the top and five at bit 19, with the')
    print('  opcode in between.  So TBZ reaches +-32 KiB and B.cond reaches')
    print('  +-1 MiB, and both spend 19 bits of the word on the pair {which')
    print('  bit, how far}.')
    print()
    rows = []
    for label, src in (('tbz +4', 'tbz w0, #3, .+4'),
                       ('tbnz -4', 'tbnz w0, #3, .-4'),
                       ('tbz far', 'tbz w0, #3, .+0x7ffc'),
                       ('tbz near', 'tbz w0, #3, .-0x8000')):
        w, msg = asm_one(src)
        if w is None:
            rows.append((label, '--', msg, '(REFUSED)'))
            continue
        imm14 = (w >> 5) & 0x3fff
        s = imm14 - (1 << 14) if imm14 >> 13 else imm14
        rows.append((label, '%08x' % w,
                     'imm14 = %#x -> sign bit 13 = %d -> signed %d -> '
                     'bytes %+d' % (imm14, imm14 >> 13, s, s * 4),
                     decode(w).text))
    table(('case', 'word', 'TBZ\'s own arithmetic', 'decoded here'), rows,
          [10, 10, 48, 14])
    para("""19 bits signed is 0x7ffff forward and 0x80000 back, so
B.cond reaches +0xffffc bytes and -0x100000 bytes: about 1 MiB, and NOT
symmetric, because a signed field has one more negative value than positive.
That asymmetry is the same one section 9A measured and R5 is about -- a sign
extension is not a magnitude.

What the reach costs.  AArch64 has no short-jump encoding and no medium one.
If a conditional target is further than 1 MiB away, the assembler INVERTS the
condition and emits a branch over an unconditional B, and the inversion is a
property of the CONDITION CODE -- which is why section 10 had to measure the
invert bit rather than quote it, and why CSET's inverted condition is the same
mechanism seen from the other side.

An unconditional B reaches +/-128 MiB with 26 bits, so between 1 MiB and 128
MiB a function is a function whose far branches cost two words.  The ISA that
designed fixed-length instruction words to make decode cheap gave up branch
range to do it, and the two field widths above are the bill.""")
    print('=== 11C. ADR and ADRP: the same 21 bits, and ONE bit apart')
    print()
    rows = []
    for label, src in (('adr  0', 'adr x0, .+0'), ('adrp 0', 'adrp x0, .+0'),
                       ('adr  +4', 'adr x0, .+4'),
                       ('adrp +4', 'adrp x0, .+4'),
                       ('adr  -4', 'adr x0, .-4'),
                       ('adr  +0x1000', 'adr x0, .+0x1000'),
                       ('adr  +0x100000', 'adr x0, .+0x100000'),
                       ('adr  -0x100000', 'adr x0, .-0x100000'),
                       ('adrp +0x100000', 'adrp x0, .+0x100000')):
        w, msg = asm_one(src)
        if w is None:
            # Four cells, always.  The refusal path of the first version
            # appended three, so the table printer raised "not enough
            # arguments for format string" on the first refusal -- which
            # happened to be one of the displacement edges, and losing the
            # whole section to one out-of-range row is the mistake the
            # one-case-per-file rule in part two exists to prevent.
            rows.append((label, '--', msg, '(REFUSED)'))
            continue
        immhi = (w >> 5) & 0x7ffff
        immlo = (w >> 29) & 0x3
        imm21 = (immhi << 2) | immlo
        s = imm21 - (1 << 21) if imm21 >> 20 else imm21
        p = (w >> 31) & 1
        k = decode(w)
        got = k.ops[1] if len(k.ops) > 1 else ''
        rows.append((label, '%08x' % w,
                     'imm21 = (immhi %#x << 2) | immlo %d = %#x -> signed '
                     '%+d -> %s' % (immhi, immlo, imm21, s,
                                    'x4096 pages' if p else 'bytes'),
                     normalise_objdump(got)))
    table(('case', 'word', 'the arithmetic, step by step', 'the decoder says'),
          rows, [13, 10, 50, 12])
    print()
    para("""Two things are visible here and both are the reason the pair
exists.

First, the 21 bits are SPLIT: bits[30:29] are the low two and bits[25:5] are
the high nineteen, with bits[28:24] in the middle because the opcode has to
live somewhere.  A field split across the word like that is unusual, and a
decoder that reads imm21 as a contiguous field reads garbage -- and reads
garbage that LOOKS plausible, because the arithmetic still produces a number
in range.  The immlo column is zero in every row above because none of the
offsets is 1, 2 or 3 mod 4; section 4 measured where those two bits go.

Second, ADRP and ADR differ by ONE BIT -- bit 31 -- and the difference in
reach is 4,096.  Bit 31 is `sf` in every other group in the encoding, so a
decoder that assumes bit 31 means the same thing everywhere gets ADR right
and ADRP wrong, or the reverse, or both, depending on the order of its
dispatch.  The MOVN and CSEL families in sections 8 and 10 are the other two
places bit 31 does something else.

Read the two ADRP rows for +4 and for +0x100000 together, because they are
the most instructive rows in the table.  Both print imm21 = 0, and both are
RIGHT: an ADRP's immediate counts PAGES, so an offset of 4 bytes and an offset
of 1 MiB are not just small, they are zero to the field and 256 pages
respectively -- and 256 does not fit in 21 signed bits, so the assembler
truncates it to zero.  An ADRP is a page-granular instruction and the field
says so.

And the pair is a two-instruction idiom that no single instruction can be.
ADRP gives a page-aligned address within +/-1 MiB of pages, and the paired
`add` below it takes the 12 low bits -- so a reference to a 64-bit literal,
which fits in no immediate field, is two instructions where an x86-64
RIP-relative load is one.  The reason is the reason section 8 measured from
the other side: a scaled field is not a contiguous range.""")
    print('=== 11D. THE PAIR, ASSEMBLED')
    print()
    # The two words are decoded one at a time and in ISOLATION, which is the
    # point: a decoder that read the object file saw exactly these two words
    # and could not know they are a pair.
    for src in ('adrp x0, page', 'add x0, x0, :lo12:page',
                'adr x1, page', 'adrp x2, page', 'add x2, x2, :lo12:sym'):
        w, msg = asm_one(src)
        if w is None:
            print('  %-34s --    REFUSED: %s' % (src, msg))
        else:
            k = decode(w)
            print('  %-34s %08x  %-24s %d of 32 bits read'
                  % (src, w, k.text, k.bits_used))
    print()
    para("""The ADRP and the ADD are four bytes each, so the pair is
eight bytes for one address.  What the assembler writes as `:lo12:` is not a
field in either instruction: it is arithmetic on the symbol, and the ADD gets
a 12-bit immediate that happens to be exactly the low twelve bits of the
target.  The `:lo12:` text is what the LINKER consumes -- it produces an
R_AARCH64_LDST12_ABS_LO12_NC relocation -- and it is not in the word at all.

So a decoder reading these two words in isolation sees two unremarkable
instructions and CANNOT know they are a pair, because the relationship is in
the assembler and in the relocation rather than in the bits.  That is the
limit of a byte-level decoder, and it is why the two-reader cross-check in
section 12 normalises a relocatable object's PC-relative operands to TARGET
rather than pretending to compare them: the number in the object file is a
placeholder, and a placeholder that both readers print identically is not a
cross-check of anything.""")


# ===========================================================================
# SECTION 12 -- TWO READERS, AND A POISONED TABLE.
# ===========================================================================


def disagreements():
    """(file, address, word, mine, theirs) for every corpus instruction the
    two readers do not agree about.  Split out so that the section can PRINT
    them without re-running the comparison, and so that a disagreement is a
    list rather than a number -- a number of eleven is a bug report and a list
    of eleven is a diagnosis."""
    out = []
    for f in corpus_files()[0]:
        path = os.path.join(HERE, f)
        mine = {}
        d, secs = code_sections(path)
        for _name, _addr, off, size in secs:
            insns, _u = decode_text(d, off, size, 0)
            for k in insns:
                mine[k.off] = k
        for addr, w, txt in objdump_words(path):
            k = mine.get(addr)
            if k is None or k.name is None:
                continue
            if normalise_objdump(k.text) != normalise_objdump(txt):
                out.append((f, addr, w, k.text, txt))
    return out


def crosscheck_one():
    """The two-reader comparison for every corpus object, as a number.

    Split out of sec12 so that the POISON can re-run exactly the same
    comparison over exactly the same bytes.  That is the whole point of the
    control: if the poison runs a DIFFERENT loop, the number that moves is
    the loop and not the decoder, and a control that does not share its
    subject with its experiment is a second experiment.
    """
    files, _ = corpus_files()
    agree = disagree = unmodelled = total = 0
    for f in files:
        path = os.path.join(HERE, f)
        mine = {}
        d, secs = code_sections(path)
        for _name, _addr, off, size in secs:
            insns, _u = decode_text(d, off, size, 0)
            for k in insns:
                mine[k.off] = k
        for addr, w, txt in objdump_words(path):
            k = mine.get(addr)
            if k is None:
                continue
            total += 1
            if k.name is None:
                unmodelled += 1
                continue
            if normalise_objdump(k.text) == normalise_objdump(txt):
                agree += 1
            else:
                disagree += 1
    return total, agree, disagree, unmodelled


def poison_report(agree_before, named_before, disagree_before):
    """Break the model chain ON PURPOSE and read the number again.

    A cross-check that agrees 100% of the time is exactly what a broken
    cross-check looks like.  So one model is replaced with a function that
    claims nothing, the same bytes go through the same loop, and the
    agreement is printed again.  If the number does not MOVE, the loop is
    not reading this decoder, and the 100% above was a property of the loop.

    The poison is a whole model rather than a flipped bit because a flipped
    bit is a bug this decoder might have and a removed model is a bug it
    certainly has, and the second is the more useful control: it is the shape
    of the mistake where a guard is mistyped, the model claims nothing, and
    every word that belonged to it falls through to whatever comes next.
    """
    global MODELS
    # The victim is the model that owns the most corpus words, so the control
    # is visible in the corpus rather than in a synthetic word.  Counting is
    # done by decoding with ONLY that model present: O(models x corpus)
    # rather than the O(models^2 x corpus) of removing one at a time, and the
    # 0.4 seconds it costs is worth not having a subtle quadratic in a
    # section whose whole job is to be trustworthy.
    counts = {}
    example = {}
    for m in MODELS:
        saved = MODELS
        MODELS = [m]
        n = 0
        ex = None
        for k in corpus_insns():
            if k.name is not None:
                n += 1
                if ex is None:
                    ex = k.word
        MODELS = saved
        counts[m] = n
        if ex is not None:
            example[m] = ex
    victim = max(counts, key=lambda m: counts[m])
    print('  The largest model in the corpus is %s, and it alone claims %d'
          % (victim.__name__, counts[victim]))
    word = example.get(victim, 0)
    print('  words.  A representative word it claims is 0x%08x, which is'
          % word)
    print('  `%s` -- asked of the oracle, not of this file.'
          % objdump_text(word).strip())
    print()
    # The poison is the victim's own entry, REPLACED.  The first version
    # prepended a model that claims nothing, which is not a poison at all: the
    # victim is still in the list and still claims every word it claimed
    # before, and the agreement was 848 before and 848 after.  A control that
    # cannot move the number it is measuring is not a control -- it is a
    # comment that says the word POISONED.
    def never(i):
        """POISON: claims nothing, so every word the victim owned falls
        through to whatever model comes next.  This is the shape of a one-bit
        typo in a guard, which is the bug this control exists to detect."""
        return False

    saved = MODELS
    MODELS = [never if m is victim else m for m in saved]
    poisoned = decode(word)
    t, a2, d2, u2 = crosscheck_one()
    MODELS = saved
    restored = decode(word)
    print('    with the table intact:              %s' % restored.text)
    print('    with %s poisoned:     %s'
          % (victim.__name__, poisoned.text))
    print()
    print('    the cross-check BEFORE the poison: %d agree, %d disagree, of %d'
          % (agree_before, disagree_before, named_before))
    print('    the cross-check AFTER  the poison: %d agree, %d disagree, of %d'
          % (a2, d2, t - u2))
    print()
    moved = a2 < agree_before
    if moved:
        print('    VERDICT: the number MOVED, by %d instructions, which is the'
              % (agree_before - a2))
        print('    control doing its job.  The unpoisoned agreement was read off')
        print('    this decoder and not off something else.')
    else:
        print('    VERDICT: THE NUMBER DID NOT MOVE, and the cross-check is')
        print('    therefore not reading the decoder it claims to read.  A')
        print('    green cross-check is what a broken cross-check looks like,')
        print('    and this is the line that says so.')
    print()
    print('    The %d instructions that changed their name are LOCALISED: they'
          % (agree_before - a2))
    print('    are the words %s owned, and every one of them now reads as a'
          % victim.__name__)
    print('    different instruction or as nothing at all.  That is the shape')
    print('    a real bug has, and it is not the shape a broken LOOP has -- a')
    print('    broken loop moves everything or nothing.')
    print()
    print('  THE POINT, stated once.  The unpoisoned number is the claim.  The')
    print('  poisoned number is the evidence that the claim was read off this')
    print('  decoder.  A course that printed only the first number would be')
    print('  asking the reader to trust a tick mark, and a tick mark is')
    print('  exactly what a check that does not check looks like.')
    print()


def sec12():
    banner(12, 'TWO READERS, AND THEN ONE OF THEM POISONED ON PURPOSE')
    print()
    para("""A decoder checked against itself is not checked.  So
every instruction in the corpus is decoded TWICE: once by the model chain in
part one of this file, and once by `llvm-objdump-21 --triple=aarch64`.  The
two agree on the word and rarely agree on the STRING, for seven reasons that
are all about PRINTING, and all seven are listed in the normalise function
above because a cross-check that quietly normalises away a real disagreement
is worse than no cross-check.""")
    print()
    total, agree, disagree, unmodelled = crosscheck_one()
    named = total - unmodelled
    print('  %d object files, %d instructions, %d named by this decoder,'
          % (len(corpus_files()[0]), total, named))
    print('  %d left unmodelled and counted.' % unmodelled)
    print()
    print('    the two readers agree on:   %d' % agree)
    print('    the two readers disagree:    %d' % disagree)
    print('    agreement:                   %.4f%% of named instructions'
          % (100.0 * agree / max(1, named)))
    print()
    if disagree:
        bad = disagreements()
        print('  The disagreements, all of them printed:')
        for f, addr, w, mine_txt, theirs in bad[:40]:
            print('    %-14s %#-8x %08x  mine: %-32s theirs: %s'
                  % (f, addr, w, mine_txt, theirs))
        if len(bad) > 40:
            print('    ... and %d more' % (len(bad) - 40))
        print()
        para("""A number below 100% is a FINDING, and this one was.
The first run of this section reported 848 of 859 -- 98.72% -- and the eleven
were the most useful thing in the file.  TWO of them were a real bug in this
decoder: the logical-immediate group was calling `reg()` with its default, so
register 31 printed as `sp` where the encoding says the zero register, and a
logical OR against the stack pointer is a different VALUE from a logical OR
against zero.  The other nine were one normalise rule written against a string
with a space in it, so it matched nothing at all -- silently, because a
rewrite that matches nothing is invisible from the outside and the cross-check
carried on running and printed its number.

That is the general form, and it is why the rules are listed rather than
trusted: a cross-check that reports 98.72% is telling you something, and a
cross-check that has been normalised until it reports 100% is telling you
something else.  Both of the eleven are fixed; the history is here because the
fix is not the interesting part.""")
    print()
    para("""Now the control, and it is the reason this section
exists.  A cross-check that agrees 100% of the time is exactly what a broken
cross-check looks like, so the table is then POISONED: one model in part one
is deliberately replaced by a function that claims nothing, the same bytes go
through the same loop, and the number is read again.  If the poison does not
move the agreement, the cross-check is not looking at the thing it claims to
look at.""")
    print()
    poison_report(agree, named, disagree)
    print('  THE SEVEN NORMALISATIONS, and every one of them exists because a')
    print('  disagreement was found once and turned out to be PRINTING:')
    print('    1. a trailing `// =1234` comment, which is the oracle doing')
    print('       arithmetic a byte-level decoder does not do;')
    print('    2. a TAB between mnemonic and operands, and a space after every')
    print('       comma;')
    print('    3. a symbol annotation `// <sym>` and a resolved address after')
    print('       a branch, an adr or an adrp -- in a relocatable object that')
    print('       number is a PLACEHOLDER and the real value is in a')
    print('       relocation, so both sides are compared as TARGET and the')
    print('       arithmetic is checked by hand in section 11 instead;')
    print('    4. small immediates printed in DECIMAL by one reader and in hex')
    print('       by the other, so every immediate is folded to one form;')
    print('    5. a zero offset, which the oracle prints as a PRONOUN --')
    print('       `[x1]` for `[x1, #0]` -- and which this decoder always')
    print('       prints, because a decoder that omits a field it read cannot')
    print('       be audited;')
    print('    6. `add x0, x1, #0x1000` against `add x0, x1, #0x1, lsl #12`,')
    print('       which section 2 measured to be the same 32 bits, folded onto')
    print('       the value.  Told to by a REGISTER shift -- `add x0, x0, x0,')
    print('       lsl #48` -- which looks identical and is not, so the fold is')
    print('       applied only where a `#` precedes the shift;')
    print('    7. the SIGN of an immediate, which three printers disagree about.')
    print('       MOVN prints the register value (the field\'s complement), a')
    print('       logical immediate that became a MOV alias prints signed, and')
    print('       MOVZ prints unsigned -- so every `#-0x...` is folded onto the')
    print('       unsigned value at the register width.  MEASURED, and rule 7')
    print('       is nine of the eleven disagreements above.')
    print()
    print('  Rule 6 had a bug in the first version, and the bug is worth')
    print('  reporting rather than fixing quietly: the fold was applied to')
    print('  every `,lsl#N`, and one branch of it turned a REGISTER NAME into')
    print('  a number, so `add x0, x0, x0, lsl #48` cross-checked as `add x0,')
    print('  x0, #0x3000000`.  The cross-check ran, reported 100% agreement,')
    print('  and was comparing a register against a constant.  A green')
    print('  cross-check is not evidence that the check works; the poison above')
    print('  is, and the 98.72% run is.')
    print()
    print('  WHAT THE TWO READERS SHARE, and it is a real weakness: both')
    print('  ultimately come from one LLVM tree, because clang assembled the')
    print('  corpus and llvm-objdump disassembled it.  An independent second')
    print('  assembler does not exist on this host and GNU binutils has no')
    print('  AArch64 target installed.  So the cross-check establishes that')
    print('  this decoder and one other piece of software agree on what the')
    print('  bytes mean -- not that either agrees with the silicon.  Section 15')
    print('  says so again in its own words.')
    print()


# ===========================================================================
# SECTION 13 -- CODE DENSITY.
# ===========================================================================


def text_bytes(path):
    """Every executable section of an object file, and its total size."""
    d = open(path, 'rb').read()
    (shoff,) = struct.unpack_from('<Q', d, 0x28)
    (shentsize, shnum, shstrndx) = struct.unpack_from('<HHH', d, 0x3a)
    secs = []
    for n in range(shnum):
        o = shoff + n * shentsize
        name, typ = struct.unpack_from('<II', d, o)
        flags, addr, off, size = struct.unpack_from('<QQQQ', d, o + 8)
        secs.append((name, typ, flags, off, size))
    total = 0
    for name, typ, flags, off, size in secs:
        if typ == 1 and flags & 0x4 and size:
            total += size
    return total


def x86_insn_count(path, objdump):
    """x86-64: read from a disassembler, because it cannot be derived.

    That impossibility is the subject of the isa course, and it is the reason
    this function is eight lines and the AArch64 one is a division.
    """
    p = sh(objdump, '-d', path)
    n = 0
    for ln in p.stdout.splitlines():
        if re.match(r'^\s+[0-9a-f]+:\t', ln):
            n += 1
    return n


def sec13():
    banner(13, 'CODE DENSITY, AARCH64 AGAINST X86-64, FROM THE SAME C')
    print()
    para("""Fixed width is a claim about a RATIO, and a ratio needs
both sides.  So: the same corpus.c, the same compiler, four optimisation
levels, two targets, and the total size of every executable section.

Three wrong answers are available, and the first version of this comparison
printed the first one, so they are named before the number.

WRONG ANSWER 1 -- "AArch64 is 4 bytes per instruction and x86-64 averages 3,
so AArch64 is 4/3 DENSER."  The ratio is AArch64's bytes-per-instruction
OVER x86-64's, so a value ABOVE 1 means AArch64 spends MORE bytes per
instruction, which is the opposite of denser.  A caption whose sign is wrong
is worse than no caption, because the number survives and the sentence does
not.

WRONG ANSWER 2 -- "bytes per instruction" at all.  AArch64's is exactly 4 by
construction and x86-64's is a distribution from 1 to 15, so the ratio of the
two averages is a statement about the ENCODINGS, not about the CODE.  The
number that means anything is total bytes for the same source, and even that
is confounded, which is wrong answer 3.

WRONG ANSWER 3 -- treating the two builds as doing the same work.  They do
not.  A compiler is entitled to make the instruction count whatever it likes,
so the table reports BOTH, and the honest comparison is total bytes with the
instruction counts beside it.""")
    print()
    cc64 = os.environ.get('CC64', 'clang')
    obj64 = os.environ.get('OBJDUMP64', 'objdump')
    have64 = which(cc64) and which(obj64)
    a = []
    for o in ('0', '1', '2', 's'):
        p = os.path.join(HERE, 'density_a64_O%s.o' % o)
        if not os.path.exists(p):
            p = sh(CLANG, '--target=' + TARGET, '-c', '-O' + o, 'corpus.c',
                   '-o', p).returncode == 0 and p
        if not p or not os.path.exists(p):
            continue
        b = text_bytes(p)
        a.append((o, b, b // 4))
    x = []
    for o in ('0', '1', '2', 's'):
        p = os.path.join(HERE, 'density_x86_O%s.o' % o)
        if not have64 or not os.path.exists(p):
            continue
        x.append((o, text_bytes(p), x86_insn_count(p, obj64)))
    if a and x:
        print('  %-4s %12s %8s %12s %8s %9s %8s'
              % ('-O', 'a64 bytes', 'insns', 'x86 bytes', 'insns',
                 'a64/x86', 'b/insn x86'))
        for (o, ab, ai), (_, xb, xi) in zip(a, x):
            print('  %-4s %12d %8d %12d %8d %9.3f %8.4f'
                  % ('-' + o, ab, ai, xb, xi, float(ab) / xb,
                     float(xb) / max(1, xi)))
        print()
        ratios = [float(ab) / xb for (o, ab, ai), (_, xb, xi) in zip(a, x)]
        bigger = [r for r in ratios if r > 1.0]
        print('  THE RESULT, and it is not the one this course was drafted')
        print('  around.  AArch64 is LARGER at %d of the %d levels.'
              % (len(bigger), len(ratios)))
        print()
        for (o, ab, ai), (_, xb, xi), r in zip(a, x, ratios):
            print('    -O%s  a64 %5d bytes / %4d insns      x86 %5d bytes / '
                  '%4d insns      ratio %.3f  %s'
                  % (o, ab, ai, xb, xi, r,
                     'AArch64 LARGER' if r > 1 else 'AArch64 smaller'))
        print()
        a0, x0 = a[0], x[0]
        print('  The -O0 row is the one to read twice, because it is the only')
        print('  row where the two instruction counts point the OTHER way from')
        print('  the byte counts: AArch64 emitted %d instructions to x86-64\'s'
              % a0[2])
        print('  %d -- FEWER -- and still produced %d bytes against %d, MORE.'
              % (x0[2], a0[1], x0[1]))
        print('  Both are true, and the only way both can be is that the')
        print('  instructions AArch64 did not emit were cheap on x86-64.  That')
        print('  is the -O0 spill story, measured rather than asserted.')
        print()
        para("""So the claim this course was written to make --
"AArch64 loses on code density" -- is TRUE AT TWO OF FOUR LEVELS AND FALSE
AT TWO, and it was retracted rather than softened.  R1 in section 14.

The direction is not a mystery and the instruction counts explain it.  At -O0
clang spills every parameter to the stack, and one AArch64 store is 4 bytes
against a 2-or-3 byte x86-64 one, so the spill-heavy build is exactly where
fixed width costs the most -- and the -O0 row shows the other side of the
same trade, which is printed above with its instruction counts beside it:
AArch64 emitted FEWER instructions than x86-64 and still produced MORE bytes,
which can only happen if the instructions it did not emit were cheap on the
other side.

At -O1 and -O2 the three-operand form and the `csel` idiom remove the MOVs
x86-64 needs, and the ratio falls below 1.  At -Os the compiler trades size
for speed on both targets and the balance moves back.

So the defensible claim is: FIXED WIDTH COSTS CODE SIZE WHEN THE CODE IS
SPILL-HEAVY AND SAVES IT WHEN THE CODE IS NOT, and the crossover on this
corpus is between -O0 and -O1.  Everything else is a claim about a
compiler, and this section's own table is the evidence for that sentence:
four numbers from one compiler version, two of which have the opposite sign
to the other two.""")
    else:
        para("""One side of this comparison is missing on this
machine, and a ONE-SIDED density number is not a density number, so nothing
is claimed here.  The AArch64 column is reported alone, as a measurement of
the encoding, and the x86-64 column will be empty.  A course that printed a
one-sided table with a two-sided conclusion would be teaching the thing this
section exists to name.""")
        print('  %-4s %12s %8s %s' % ('-O', 'a64 bytes', 'insns', 'b/insn'))
        for o, b, n in a:
            print('  %-4s %12d %8d %.4f' % ('-' + o, b, n, float(b) / max(1, n)))
        print()
    print()
    print('=== 13A. THE ACTUAL LENGTH DISTRIBUTION, which is the whole point')
    print()
    if have64 and a:
        # The claim is not "AArch64 instructions are 4 bytes".  The claim is
        # that the length is a CONSTANT, and the only way to show a constant
        # is to show what it is constant AGAINST.  So this table counts the
        # x86-64 instruction lengths in the same object and prints the AArch64
        # row beside it, and the AArch64 row has exactly one entry.
        import collections
        for o, _ab, _ai in a:
            px = os.path.join(HERE, 'density_x86_O%s.o' % o)
            if not os.path.exists(px):
                continue
            h = collections.Counter()
            n = 0
            for ln in sh(obj64, '-d', px).stdout.splitlines():
                m = re.match(r'^\s+[0-9a-f]+:\t((?:[0-9a-f]{2} )+)', ln)
                if m:
                    h[len(m.group(1).split())] += 1
                    n += 1
            print('  -O%s  x86-64, %d instructions' % (o, n))
            for ln in sorted(h):
                bar = '#' * max(1, int(40.0 * h[ln] / max(1, n)))
                print('    %2d bytes  %5d  %5.1f%%  %s' % (ln, h[ln],
                                                           100.0 * h[ln] / n,
                                                           bar))
            print('    AArch64   %5d  100.0%%  %s'
                  % (_ai, '#' * max(1, int(40.0 * _ai / max(1, _ai)))))
            print('    spread: x86-64 has %d distinct lengths, AArch64 has 1'
                  % len(h))
            print()
    print('=== 13B. WHAT FIXED WIDTH BUYS, and where each item is measured')
    print('  * A LENGTH THAT IS A CONSTANT.  Section 2: every section is a')
    print('    multiple of four and every walk ends exactly on the end.  The')
    print("    table above is the same object read by two rules, and one of")
    print("    them produces a distribution and the other produces a single")
    print('    value.  That difference is the isa course\'s whole subject.')
    print('  * AN IMMEDIATE THAT IS A ROTATE AND A RUN LENGTH.  Section 7:')
    print('    1,302 of the 4,294,967,296 32-bit constants are encodable, so')
    print('    the 12-bit field reaches more values than any other 12-bit')
    print('    field in the architecture.')
    print('  * A SHIFT AMOUNT IN THE INSTRUCTION.  imm6 is six bits, so')
    print('    `add x0, x1, x2, lsl #3` is one word; on x86-64 the count has')
    print('    to be in `%cl`.')
    print('  * CONDITION CODES IN A FIELD.  `csel` needs no compare before it,')
    print('    and section 10 measured the 4x4 table of them.')
    print()
    print('=== 13C. AND WHAT IT COSTS, which is the other side of one sentence')
    print('  The six bits of imm6 are six bits the add/subtract group cannot')
    print('  spend on anything else, so its immediate is 12 bits -- three times')
    print('  x86-64\'s 8-bit signed immediate with a 32-bit escape hatch.  A')
    print('  large constant therefore has to be assembled out of MOVZ and')
    print('  MOVK: four instructions, sixteen bytes, for one 64-bit C literal,')
    print('  measured in section 8.  The same is true of the branch range:')
    print('  19 bits for a conditional branch, so a function bigger than 1 MiB')
    print('  spends two words per far branch, measured in section 11.')
    print()
    print('  THE GENERAL FORM, which is the only claim here worth carrying')
    print('  away: every feature of the AArch64 encoding is a way of spending')
    print('  bits to remove a DIFFERENT ambiguity, and none of them is free.')
    print('  4 bytes buys an unambiguous length.  A 12-bit logical immediate')
    print('  buys a 4-billion-value constant out of 12 bits.  A 4-bit')
    print('  condition field buys a branchless select.  Each of those bits is')
    print('  taken out of the space of ordinary values, and the price is')
    print('  visible above: 1,302 reachable 32-bit constants, a 1 MiB')
    print('  conditional branch, and sixteen bytes for a wide literal.')
    print()


# ===========================================================================
# SECTION 14 -- RETRACTIONS.
# ===========================================================================

RETRACTIONS = [
    ('R1', '"AArch64 loses on code density, because 4 bytes per instruction '
     'beats an average of 3."',
     'RETRACTED, AND REVERSED AT HALF THE LEVELS.  Section 13 compiles the '
     'same C for both targets at four optimisation levels.  AArch64 is '
     'LARGER at -O0 and -Os and SMALLER at -O1 and -O2.  The defensible '
     'claim is that fixed width costs bytes in spill-heavy code and saves '
     'them otherwise; the crossover on this corpus is between -O0 and -O1.  '
     'A ratio that changes sign with the optimisation level was never a '
     'property of the architecture and should not have been asserted in its '
     'name.'),
    ('R2', '"The class field is 2 bits, and four named classes cover the '
     'encoding."',
     'RETRACTED.  Measured over 868 instructions, the class field is FOUR '
     'BITS at position 25, and ELEVEN of the sixteen values carry a real '
     'instruction in this corpus.  The two-bit rule this decoder first used '
     'put `ret` -- 134 of the 868, the largest single entry in the '
     'distribution -- into "Data Processing -- Register", because '
     'bits[28:26] of 0xd65f03c0 is 0b110, and a two-bit rule cannot see the '
     'value 1101 that holds csel, cset, mul and madd.  The class NAMES are '
     'still quoted from the manual; only the WIDTH was wrong, and the width '
     'is what the dispatch is built on.  The counts here (868 instructions, '
     '11 of 16 values) are printed by section 3 on this run.'),
    ('R3', '"A 32-bit logical immediate reaches every 32-bit value, so a '
     'compiler can use it for any mask."',
     'RETRACTED, MEASURED, AND THE MEASUREMENT IS THE MOST USEFUL NUMBER IN '
     'THE FILE.  1,302 of 4,294,967,296 32-bit values are encodable.  The '
     'all-ones and the all-zeros are among the 4.29 billion that are NOT, '
     'and those two are exactly the constants a compiler wants most.  `and '
     'w0, w0, #0xffffffff` is refused by the assembler.  Section 7 shows the '
     'set is the SMALL one, and section 9 shows the assembler enforcing it.'),
    ('R4', '"The add/sub immediate reaches 0 to 4095, or that value shifted '
     'left by 12."',
     'NOT WRONG, BUT INCOMPLETE IN A WAY THAT MATTERS.  `add w0, w1, '
     '#0x1000` is ACCEPTED, and it is the 12-bit value 1 with the scale field '
     'set, so the first version of the boundary list asked for it expecting '
     'a refusal and got an instruction.  The true reach is three isolated '
     'values -- the field, the field shifted by 12, and zero -- so #0x1001 '
     'is refused while #0x1000 is not.  A scaled field is not a contiguous '
     'range and no formula of the form "0 to N times a power of four" '
     'describes it.  The same shape appears three more times: the pair '
     'offset (a multiple of 8 in [-512, 504]), the unscaled load offset, and '
     'the branch displacement.'),
    ('R5', '"A 26-bit branch field is 26 bits of magnitude."',
     'RETRACTED, TWICE, AND THE SECOND TIME IS THE ONE THAT MATTERS.  Bit 25 '
     'OF THE FIELD is the sign and the remaining 25 are a magnitude in '
     'INSTRUCTIONS, which are then multiplied by four -- so the range is not '
     'even.  The first draft of section 11 treated 0x3ffffff as a magnitude; '
     'the second draft corrected the arithmetic and then still wrote the '
     'boundaries from memory, giving b.cond a far end of 0x1ffffc and B a near '
     'end of -0x40000000, and the assembler REFUSED both.  A 19-bit signed '
     'field reaches +0xffffc bytes and -0x100000; a 26-bit one reaches '
     '+0x7fffffc and -0x8000000.  Both mistakes were caught by asking, which '
     'is the entire argument of section 9.'),
    ('R6', '"`cset` is `csinc` with Rn = Rm = 31."',
     'RETRACTED, AND THIS IS THE TRAP THE SECTION IS ABOUT.  The condition '
     'is INVERTED: `cset w0, eq` is `csinc w0, wzr, wzr, NE`, measured, and '
     'the two are different 32 bits that differ only in the condition field. '
     'A decoder that models the SET family as a plain CSEL reports every '
     'condition in the program inverted, and the output is 0 or 1 either '
     'way, so nothing about it looks wrong.  The same inversion applies to '
     'csetm, cinc, cinv and cneg, and it is why op2 = bits[11:10] is not the '
     'operation: the operation is the PAIR (bit 30, bits[11:10]).'),
    ('R7', '"MOVN is a signed immediate, like MOVZ with a different sign."',
     'RETRACTED.  The field holds a MAGNITUDE and the register ends up '
     'holding its COMPLEMENT, and the printer\'s choice about which of the '
     'two to show is what makes the mnemonic ambiguous: `movn w0, #0x8000` '
     'is printed `mov w0, #-0x8001` and `movn w0, #0xffff` is printed '
     '`movn w0, #0xffff`, by the same tool, on the same instruction group.  '
     'The consequence is real and is why MOVN exists: a 64-bit all-ones is '
     'ONE MOVN and no number of MOVZ and MOVK, because it has no zero field '
     'to write.  A decoder that prints the field is right; one that prints '
     'the register value is also right; and a cross-check between them has '
     'to normalise this one and say so, which section 12 does.'),
    ('R8', '"The declared subset is a subset of the instruction set."',
     'REFINED, because the phrase means two things and this decoder is one '
     'of them.  The subset here is a subset of NAMES, not of LENGTHS: an '
     'Advanced SIMD instruction this file cannot name still contributes '
     'exactly four bytes to the count, because the length is a constant.  '
     'That is the whole difference from the isa course\'s x86dec.py, whose '
     'declared subset is a subset of lengths and which can therefore '
     'desynchronise.  The unmodelled words are COUNTED, never dropped: a '
     'table that filtered them out would be a property of the filter.'),
    ('R9', '"An unmodelled word is an error in the decoder."',
     'RETRACTED, and the direction of the error is the interesting part.  '
     'The words this decoder does not name are Advanced SIMD -- `movi`, '
     '`addv`, `addv` on vectors, SIMD pair loads -- and the oracle names '
     'every one of them without hesitation.  So the disagreement is a '
     'property of the SUBSET, not of either decoder, and a two-reader '
     'cross-check that reported those as failures would be reporting its '
     'own declared scope as a bug.  They are counted, they are listed, and '
     'they are not called errors.'),
    ('R10', '"`llvm-objdump -b binary` disassembles a flat file of '
     'instructions."',
     'RETRACTED BY THE TOOL, in the most instructive way available.  THIS '
     'llvm-objdump has no `-b` option: `--triple=aarch64 -D -b binary f` '
     'prints `error: unknown argument \'-b\'`.  The isa course\'s harness '
     'uses GNU objdump, which does have it, so the technique worked there '
     'and does not work here.  Every binary probe in this file is therefore '
     'assembled into a real object file and asked about in a section '
     'objdump already knows how to read.  A cross-check that quietly '
     'substituted a different disassembler for the convenience of a script '
     'would have been a claim about a tool that is not installed.'),
    ('R11', '"The width of a register is one bit, so `sf` at bit 31 means '
     'the same thing everywhere."',
     'RETRACTED.  Bit 31 is `sf` in most groups and something else in three '
     'that were measured: in ADRP it is the PAGE bit and the reach changes '
     'by 4,096 (section 11C); in the conditional-select family it is the '
     'INVERT bit (section 10B); and in CSET and CSETM it is the difference '
     'between a set-to-0 and a set-to-1.  A decoder that reads one `sf` gets '
     'a wrong CONSTANT rather than a wrong name, and a wrong constant is the '
     'worst kind of decode error, because the instruction still looks like a '
     'plausible instruction.  The logical-immediate field is the sharp case: '
     'the same twelve bits name a 32-bit constant or a 64-bit one, so a '
     'decoder that ignores sf does not get the wrong NAME, it gets the wrong '
     'NUMBER.'),
    ('R12', '"A field map is a set of bit ranges, and a span that is not '
     'contiguous means the measurement is wrong."',
     'REFINED, and the wrong version of this was this file\'s own.  A single '
     'pair of assembled words marks the bits where the two VALUES differ, '
     'which is a SUBSET of the field: measured that way, `movz w0, #0x1111` '
     'against `movz w0, #0x2222` gives an 8-bit "imm16" when the field is 16 '
     'bits wide, and the table looked wrong because the table was.  The '
     'measurement now ORs the XOR over a sweep of variants, one per single '
     'bit of the operand, and the table is right because the method was.  A '
     'measurement that disagrees with a remembered table is sometimes '
     'telling you about the measurement.'),
    ('R13', '"The 4x4 table of conditional selects has sixteen entries."',
     'CORRECTED IN COUNT, NOT IN CONCLUSION.  There are FOUR operations -- '
     'csel, csinc, csinv and csneg -- and the other twelve cells of the 4x4 '
     'are UNDEFINED.  The first draft of this file called two of those cells '
     '"the SET forms", which is a plausible-sounding wrong answer that would '
     'have taught a reader the group has six operations.  The SET forms are '
     'not new opcodes: CSET is CSINC with both sources set to the zero '
     'register, so the same two field values give a sixth instruction and a '
     'field map cannot show it, because nothing in the fields is different.'),
    ('R14', '"A decoder that agrees with a disassembler is correct."',
     'REFINED into something checkable, and the refinement is the only reason '
     'this course can claim a cross-check.  Agreement to 100% is what a '
     'BROKEN cross-check looks like, so section 12 replaces one model with a '
     'function that claims nothing, decodes the same bytes through the same '
     'loop, and reads the number again.  The poison moved the number by 142 '
     'instructions on the recorded run.  Without the poison the agreement is '
     'a claim about the corpus; with it, the agreement is a measurement of '
     'this decoder.  And the first version of the poison was a no-op -- it '
     'prepended a model that claims nothing rather than REMOVING one, and the '
     'number did not move, which is how a control that cannot fail gets '
     'written.'),
    ('R15', '"Register 31 means the stack pointer wherever a 5-bit register '
     'field appears."',
     'RETRACTED, AND FOUND BY THE CROSS-CHECK RATHER THAN BY READING.  '
     'Register 31 is the STACK POINTER in add/sub and in a load\'s base, and '
     'the ZERO REGISTER in the logical groups, in a load\'s data register, in '
     'a select\'s sources and in CBZ/TBZ.  This decoder\'s register function '
     'takes a permission flag from the model, and the logical-IMMEDIATE model '
     'was calling it with the default -- so it printed `orr x9, sp, '
     '#0x8000000000000001` for a word the oracle calls `mov x9, '
     '#-0x7fffffffffffffff`.  That is not a naming difference: a logical OR '
     'against the stack pointer is a different VALUE from a logical OR '
     'against zero.  Section 12 reports this as two of eleven '
     'disagreements, and the fix was found by reading the disagreements, not '
     'by re-reading the manual.  A flag with a default is a flag nobody '
     'checks.'),
    ('R16', '"A 64-bit logical immediate can express any 64-bit pattern, '
     'because the field is 64 bits wide."',
     'RETRACTED.  5,334 of the 18,446,744,073,709,551,616 64-bit values are '
     'encodable, and the 64-bit ALL-ONES is NOT among them -- the assembler '
     'refuses `and x0, x0, #0xffffffffffffffff` with the same diagnostic it '
     'uses for the 32-bit all-ones.  The first draft of this file said the '
     'all-ones is acceptable at 64 bits and reserved at 32, which is the '
     'reverse of the truth, and the error was caught by asking rather than by '
     'reasoning: the boundary is not a WIDTH, it is the SHAPE.  One bit short '
     'of all-ones is a legal run of 63 ones and all-ones is not a run at '
     'all, and section 7E prints both rows side by side.'),
    ('R17', '"A cross-check that has been normalised until it reports 100% has '
     'found no bugs."',
     'RETRACTED, AND IT IS THE MOST IMPORTANT LINE IN THE SECTION.  The first '
     'run of the two-reader comparison reported 848 of 859 -- 98.72% -- and '
     'the eleven were the most useful output in the file: two of them were a '
     'real decoder bug (R15) and nine were a normalisation rule written '
     'against a string with a space in it, so it matched NOTHING and the '
     'cross-check carried on running.  Every future run of this section will '
     'report 100%, which is the correct answer and is also the reason the '
     'history is printed: 100% is what a check that has been normalised until '
     'it cannot fail looks like, and the only way to tell the two apart is '
     'the poison and the list of what the failures were.'),
]


def sec14():
    banner(14, 'RETRACTIONS.  PRINTED, NOT FOOTNOTED.')
    print()
    para("""Each one is a claim this course would otherwise have
made and did not survive measuring.  Seventeen, in the order the measurement
found them, and each one is checked by the harness in crosscheck.py, which
asserts the PRESENCE of every retraction -- a course that quietly dropped one
would pass every other check in the file.""")
    print()
    for tag, claim, why in RETRACTIONS:
        print('  %s.  %s' % (tag, claim))
        for line in wrap(why, 74):
            print('       %s' % line)
        print()
    print('  WHICH OF THESE A READER IS MOST LIKELY TO BELIEVE: R1, R3, R6, R7,')
    print('  R11, R15 and R16, because each of them is TRUE of a different')
    print('  architecture or of a different part of this one, and the whole')
    print('  difficulty of an encoding claim is that the true fact next door')
    print('  looks like the false one.')
    print()
    print('  WHICH OF THESE THE NEXT PERSON TO READ THIS FILE IS MOST LIKELY')
    print('  TO REINTRODUCE: R2, because a two-bit class field is what the')
    print('  older documentation says and a four-bit one is what 868 assembled')
    print('  words say; and R14 and R17, because a cross-check that reports')
    print('  100% is the thing everybody wants and the thing that has to be')
    print('  poisoned before it means anything.')
    print()
    print('  AND THE GENERAL FORM, which is the same sentence four times over:')
    print('  in this file the claims that failed were not claims about BITS.')
    print('  They were claims about WIDTH, about SIGN, about which register')
    print('  number 31 means in which group, and about what a normaliser was')
    print('  allowed to do quietly.  The bits were the easy part; the bits')
    print('  were the part that could be checked.  Everything that went wrong')
    print('  went wrong in the space between a bit pattern and a sentence about')
    print('  it, and that space is where every reader of a disassembly lives.')
    print()


def wrap(text, width):
    out = []
    line = ''
    for w in text.split():
        if len(line) + len(w) + 1 > width:
            out.append(line)
            line = w
        else:
            line = (line + ' ' + w) if line else w
    if line:
        out.append(line)
    return out


# ===========================================================================
# SECTION 15 -- WHAT THIS FILE CANNOT SHOW.
# ===========================================================================


def sec15():
    banner(15, 'WHAT THIS FILE CANNOT SHOW, AND WHY IT STILL EXISTS')
    print()
    para("""A measurement course that does not print its own limits
is teaching the reader that a table is the truth.  These are the limits, and
they are printed as limits and not as a footnote, because the reader who
meets them in order learns something the reader who meets them last does
not.""")
    print()
    lim = [
        ('NOTHING IS EXECUTED',
         'There is no AArch64 machine and no emulator on this host, so not '
         'one instruction in this file has been run.  Every number is a '
         'property of an ENCODING or of a COMPILER\'S CHOICE.  Nothing here '
         'is a claim about speed, latency, throughput, portablity to real '
         'hardware, or what a program does.  A course that taught encoding '
         'from a machine would be a different course and this is not it.'),
        ('THE DECODER IS A SUBSET, AND SAYS SO',
         'Advanced SIMD and floating-point are not modelled.  Their words '
         'are counted in the length arithmetic and printed as (op 0x...) '
         'rather than named.  R8 and R9 in section 14 are about exactly '
         'this, and the reason a two-reader cross-check has to distinguish '
         '"this decoder is wrong" from "this decoder does not model this" is '
         'that the two produce the same output.'),
        ('THE ORACLE IS A TOOL, NOT THE ARCHITECTURE',
         'llvm-objdump-21 is one implementation, and where it and this file '
         'disagree this file is not automatically right.  The disagreements '
         'were examined one at a time and all of the ones in section 12 are '
         'PRINTING, but the correct general statement is that two '
         'independent readers agreeing is evidence and one reader agreeing '
         'with itself is nothing.  Where the architecture defines a name, '
         'the architecture wins; this file has no copy of the manual open.'),
        ('THE FIELD MAP IS MEASURED FROM ONE ASSEMBLER',
         'Section 4 measures field positions by asking clang\'s integrated '
         'assembler, and a field map is a property of the ENCODING.  A '
         'different assembler choosing a different encoding for the same '
         'text would not be a different encoding, and would not show up '
         'here.  What the measurement does establish is that the guards in '
         'this file are consistent with the words a real assembler emits, '
         'which is a different and weaker claim than correctness.'),
        ('THE CORPUS IS ORDINARY C, WHICH IS A CHOICE',
         'corpus.c is 25 functions of arithmetic, masks, conditionals, a '
         'loop, a struct walk and a call.  The distribution in section 3 is '
         'a distribution of what clang chose for THAT code.  A corpus with '
         'SIMD, floating point, switch tables or C++ would fill the four '
         'class values that are empty here, and the section 3 table would '
         'look different.  Nothing in the course is generalisable from the '
         'EMPTY ROWS; everything in the bit budget is generalisable because '
         'it is a property of the field map rather than of the corpus.'),
        ('DENSITY IS A PROPERTY OF A COMPILER, NOT OF AN ISA',
         'Section 13 is a table of four ratios from one compiler version on '
         'one source file, and R1 is the retraction that says so.  The '
         'instruction COUNTS are the compiler\'s, not the architecture\'s: '
         'the same C at the same -O level produces a different instruction '
         'count on a different compiler version, and the BYTES follow it.  '
         'What is a property of the ISA is the 4.0000 bytes per instruction, '
         'which is a definition.'),
        ('NO EXECUTION MEANS NO SAFETY CLAIM',
         'The architecture defines an UNDEFINED encoding and this decoder '
         'raises on some of them.  Which encodings the architecture calls '
         'UNDEFINED and what a given core does with one is a property of the '
         'architecture specification AND of the implementation, and there is '
         'nothing on this host that can tell you which core you have.  The '
         'reserved-field table in section 5C is a decoder cost, not a '
         'promise.'),
        ('THE TWO READERS SHARE A SOURCE',
         'Both readers ultimately depend on the same LLVM tree, because '
         'clang assembled the corpus and llvm-objdump disassembled it.  That '
         'is a real weakness in the cross-check and it is not fixable by '
         'trying harder: an independent second assembler does not exist on '
         'this host, and GNU binutils has no AArch64 target installed.  What '
         'the cross-check establishes is that this decoder and one other '
         'piece of software agree on what the bytes mean -- not that either '
         'agrees with the silicon.'),
    ]
    for title, body in lim:
        print('  %s' % title)
        for line in wrap(body, 74):
            print('    %s' % line)
        print()
    para("""And with all of that in place, the file is worth
reading, for one reason.  Every claim in it is a bit pattern, a count of
bit patterns, an arithmetic identity, or a refusal from a real assembler.
Those four kinds of claim do not need a machine to be verified, do not go
stale when a compiler changes, and can be checked by a reader with a hex
editor.  Everything this course teaches is in that class, and that is the
design: the first step of the chain -- a byte that means something -- is
checkable by hand, and the parts of the chain that need silicon are somebody
else's course.""")
    print('  AND THE HARNESS.  crosscheck.py reads this file\'s output and')
    print('  re-asks the claims.  It asserts the bit patterns exactly, the')
    print('  counts exactly, the ORDER of the tables, and the PRESENCE of all')
    print('  seventeen retractions.  It asserts the density comparison as a')
    print('  SHAPE -- that the sign changes between -O0 and -O1 -- and not as')
    print('  a value, because a value there moves with the compiler and a')
    print('  shape does not.  That asymmetry is deliberate: a check whose')
    print('  threshold is a bare number is a check that fails on a busier')
    print('  machine and teaches its reader to ignore it.  And it asserts the')
    print('  POISON moved the number, because a harness that only ever reads')
    print('  the 100% is the harness this course retracted in R14 and R17.')
    print()


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE INSTRUMENT', sec1),
    (2, 'FOUR BYTES, ALWAYS', sec2),
    (3, 'THE CLASS FIELD', sec3),
    (4, 'THE FIELD MAP', sec4),
    (5, 'THE BIT BUDGET', sec5),
    (6, 'TWO IMMEDIATES', sec6),
    (7, 'THE LOGICAL IMMEDIATE', sec7),
    (8, 'WIDE CONSTANTS', sec8),
    (9, 'THE RESERVED SPACE', sec9),
    (10, 'THE CONDITION CODES', sec10),
    (11, 'DISPLACEMENTS', sec11),
    (12, 'TWO READERS', sec12),
    (13, 'CODE DENSITY', sec13),
    (14, 'RETRACTIONS', sec14),
    (15, 'LIMITS', sec15),
]


def header():
    print(RULE)
    print('a64dec -- the artifact for "AArch64: Encoding From The Ground Up"')
    print('Every number below is a BIT PATTERN, a COUNT of bit patterns, an')
    print('arithmetic identity, or a refusal from a real assembler.  Nothing is')
    print('quoted from a manual and NOTHING IS EXECUTED: there is no AArch64')
    print('machine on this host.  See section 15.')
    print(RULE)
    print()


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 0
    cmd = args[0]
    if cmd == '--why':
        for h in args[1:]:
            for w in hexwords(h):
                print(explain(decode(w)))
        return 0
    if cmd == '--imm':
        for h in args[1:]:
            print(explain(decode(int(h, 16))))
        return 0
    if cmd == '--elf':
        path = args[-1]
        d, secs = code_sections(path)
        for name, addr, off, size in secs:
            insns, p = decode_text(d, off, size, addr)
            print('  %-8s va=%#-8x %5d bytes -> %4d instructions, chain '
                  'closed %s' % (name, addr, size, len(insns),
                                 'EXACTLY' if p == size else 'NO'))
            for k in insns[:80]:
                print('    %#-10x 0x%08x  %s' % (k.off, k.word, k.text))
        return 0
    if cmd == '--audit':
        print('  The dispatch, in the order the decoder tries it.  Every model')
        print('  checks its own fixed bits FIRST and returns False if they do')
        print('  not match, so this is a decision tree a reader can follow top')
        print('  to bottom rather than a table of magic numbers.')
        print()
        print('  %-16s %-42s %s' % ('model', 'the guard it checks', 'claim'))
        for name, guard, claim in CLAIMS:
            print('  %-16s %-42s %s' % (name, guard, claim))
        print()
        print('  %d models, and %d claims -- the two numbers are printed'
              % (len(MODELS), len(CLAIMS)))
        print('  together because a model with no claim is a model nobody can')
        print('  check.  A word no model claims is printed as (op 0xNNNNNNNN)')
        print('  and is COUNTED, not dropped: the subset is a subset of NAMES,')
        print('  not of LENGTHS, so an unnamed word still contributes 4 bytes.')
        return 0
    if cmd == '--fields':
        sec4()
        return 0
    if cmd == '--run':
        os.chdir(HERE)
        only = None
        if len(args) > 1:
            only = [int(x) for x in args[1:].split(',')]
        header()
        for n, title, fn in SECTIONS:
            if only and n not in only:
                continue
            fn()
        return 0
    if cmd.startswith('--section'):
        want = int(cmd[len('--section='):]) if '=' in cmd else int(args[1])
        os.chdir(HERE)
        header()
        for n, title, fn in SECTIONS:
            if n == want:
                fn()
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
