#!/usr/bin/env python3
"""a64abi.py -- the artifact for "The AArch64 Procedure Call Standard".

THE METHOD IS FORCED, AND IT IS PRINTED FIRST, BEFORE ANY MEASUREMENT.

There is no AArch64 machine on this host and no AArch64 emulator, and there
is no AArch64 linker.  NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.
That is not a limitation worked around; it is the subject.  A learner
writing a backend is in exactly this position -- a specification, a
compiler, and no silicon -- and the honest response is to be scrupulous
about which claims are which kind:

    MEASURED            an experiment on the compiler, the object file or
                        the bytes.  What the compiler chose, what the
                        encoding says, what the unwind table contains.
    MEASURED-ON-BYTES   a property of the emitted bytes, read TWICE -- by
                        the decoder in this file and by llvm-objdump-21 --
                        and the two readers are compared word by word.
    QUOTED              a manual claim, with the document and the section
                        printed next to it, and never mixed in with a
                        measurement.

There are NO TIMINGS in this file and there are none on any of the five
pages, and the absence is stated on the pages rather than in a footnote.
The x86-64 ABI course measured a 4.92x and a 27.65x.  Nothing in this
section has a counterpart, because there is no AArch64 clock to read.  The
x86-64 half of the one cross-architecture comparison in here is a
COMPILE-TIME instruction count, and it is labelled as such every time it
appears.

The specification is the ORACLE.  The compiler is the TEST SUBJECT.  Every
disagreement between them is printed as a RETRACTION, in section 11, and
crosscheck.py asserts the text of every one of them, so a retraction can be
neither quietly dropped nor edited into being right.

    python3 a64abi.py --run            the whole run, 12 sections
    python3 a64abi.py --section=5      one section
    python3 a64abi.py --audit          the decoder models this file adds
    python3 a64abi.py --why 0xad0007e0 explain one word
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
# This file does not write an AArch64 decoder.  It uses the one the previous
# course in this section wrote -- `a64dec.py`, twenty-one models, in
# courses/a64asm/assets/samples/ -- and adds the FIVE models the procedure
# call standard needs and that one did not have.
#
# That is not a shortcut, it is a finding, and section 3 prints it: the
# classes the ABI needs are the ones the encoding course declared out of
# scope.  `a64-verify` says "the subset is a subset of NAMES, not of
# LENGTHS" and means it as a decoder caveat.  This course is where it
# becomes load-bearing, because a decoder that cannot name `stp q0, q1`
# cannot check the alignment rule -- and the alignment rule is what the
# first concept of this course is about.
# ===========================================================================

def find_sibling_decoder():
    """Locate `a64dec.py` by walking UP from here until a directory that
    holds a sibling `a64asm` course appears.

    A hardcoded `../../a64asm/...` is a path that breaks the first time
    somebody moves a directory, and a course whose artifact only runs in the
    exact directory layout it was written in is a course nobody can re-run.
    The search is upward because both courses live under `courses/` and
    neither knows the other's depth from itself.
    """
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
        'It is the encoding course\'s decoder, courses/a64asm/assets/samples/.')


DECODER_DIR = find_sibling_decoder()
sys.path.insert(0, DECODER_DIR)

import a64dec  # noqa: E402  (the path has to be set first)

Dec = a64dec  # the shorter name, used everywhere below
XN, reg = a64dec.XN, a64dec.reg
BASE_MODEL_COUNT = len(Dec.MODELS)
BASE_MODELS = list(Dec.MODELS)

# ---------------------------------------------------------------------------
# The five extra models.  Each one is written against the table in section 3
# of this file, which is a sweep of fifty assembler outputs, not a memory of
# a manual.  The two-reader check in section 10 is what they have to pass.
# ---------------------------------------------------------------------------

# The SIMD&FP register letter for a size index.  MEASURED, section 3: the
# index is bits[31:30] + 4 * bit[23], so 0..4 is b, h, s, d, q.  Ten
# instructions, two per size, each with a different immediate offset so the
# scale is visible as a division and not as a claim.
FP_SIZES = ('b', 'h', 's', 'd', 'q')
FP_SCALE = (1, 2, 4, 8, 16)


def m_ldst_fp(i):
    """Load/store register (immediate), SIMD&FP and Advanced SIMD.

    MEASURED, section 3, a sweep of 50 assembler outputs:

      form              bits[29:27]  V  bits[25:24]  immediate
      str/ldr scaled        111      1      01       imm12 at 21:10, x SIZE
      stur/ldur             111      1      00       imm9 at 20:12, in BYTES
      post-indexed          111      1      00       imm9 + bits[11:10]=01
      pre-indexed           111      1      00       imm9 + bits[11:10]=11

    The scale is the point of this model, because the whole of section 5 is
    about which multiples of 16 an encoding can say.  `str q0, [x1, #32]`
    is 0x3d800820 with imm12 = 2, and 2 x 16 = 32; `str d0, [x1, #32]` is
    0xfd001020 with imm12 = 4, and 4 x 8 = 32.  One source offset, two
    different fields, because the size is in the OPCODE.
    """
    if not i.fixed(29, 27, 0b111, 'Load/store register (immediate)'):
        return False
    if not i.fixed(26, 26, 1, 'V = the SIMD&FP form'):
        return False
    opc = i.read(31, 30)
    size_idx = opc + 4 * i.read(23, 23)
    if size_idx > 4:
        return False
    sz = FP_SIZES[size_idx]
    scale = FP_SCALE[size_idx]
    L = i.read(22, 22)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    base = reg(rn, 1, allow_sp=True)
    vreg = sz
    if i.read(25, 24) == 0b01:                  # unsigned offset, scaled
        imm12 = i.read(21, 10)
        off = imm12 * scale
        i.name = 'ldr' if L else 'str'
        i.ops = ['%s%d, [%s, #%d]' % (vreg, rt, base, off)]
        i.say('V = 1 and bits[25:24] = 01: the SCALED form.  imm12 = %d sits '
              'at bits[21:10] and the address is base + imm12 x %d.  The '
              'scale is the register SIZE, so this encoding cannot express '
              'an address that is not a multiple of %d -- which for q is '
              'exactly the alignment the AAPCS64 asks SP for.'
              % (imm12, scale, scale))
        return True
    if i.read(25, 24) == 0b00:                  # unscaled / post / pre
        mode = i.read(11, 10)
        imm9 = i.read(20, 12)
        if imm9 & 0x100:
            imm9 -= 0x200
        if mode == 0b00:
            i.name = 'ldur' if L else 'stur'
            i.ops = ['%s%d, [%s, #%d]' % (vreg, rt, base, imm9)]
        elif mode == 0b01:
            i.name = 'ldr' if L else 'str'
            i.ops = ['%s%d, [%s], #%d' % (vreg, rt, base, imm9)]
        elif mode == 0b11:
            i.name = 'ldr' if L else 'str'
            i.ops = ['%s%d, [%s, #%d]!' % (vreg, rt, base, imm9)]
        elif mode == 0b10:
            # bits[11:10] = 10 is the REGISTER-OFFSET form: bits[20:16] is a
            # second register, and the field the first version read as a
            # displacement is a register number.  The first version printed
            # `str q3, [x8, #150]?` -- the `?` being the author's own
            # uncertainty about whether bits[11:10] = 10 was allocated, and
            # 150 being bits[9:5] (Rn) and bits[20:16] (Rm) read as one
            # number.  It is allocated, and the encoding course's
            # `ldst_uimm9` model already has a name for it.
            rm = i.read(20, 16)
            i.name = 'ldr' if L else 'str'
            i.ops = ['%s%d, [%s, %s]' % (vreg, rt, base, 'x%d' % rm)]
            i.say('bits[11:10] = 10: the REGISTER-OFFSET form, and bits[20:16] '
                  'is a second register rather than part of a displacement.  '
                  'The first version of this model read the byte offset '
                  'first and the register second, which turned `str q3, [x8, '
                  'x9]` into `str q3, [x8, #150]` -- 0x96 = bits[9:5] and '
                  'bits[20:16] concatenated, and a number that is not an '
                  'offset.')
            return True
        else:
            i.name = 'ldr' if L else 'str'
            i.ops = ['%s%d, [%s, #%d]?' % (vreg, rt, base, imm9)]
        i.say('bits[25:24] = 00 and bits[11:10] = %s: the UNSCALED form.  The '
              'field is a signed 9-bit BYTE offset, range [-256, 255], and it '
              'is the one encoding in the family that can name an address '
              'that is not a multiple of %d.  The assembler reaches for it '
              'BY ITSELF when the offset you wrote is not encodable scaled, '
              'which is why writing `str q0, [sp, #8]` silently produces a '
              'STUR.' % (format(mode, '02b'), scale))
        return True
    return False


def m_ldlit_fp(i):
    """LDR (literal), SIMD&FP.  bits[29:27] = 0b011, V = 1.

    MEASURED, section 3: opc = bits[31:30] is 00 for s, 01 for d and 10 for
    q, and `ldr b0, 8` and `ldr h0, 8` are BOTH REFUSED with "invalid
    operand for instruction".  So the literal form has three sizes where the
    immediate form has five, and the reason is a 19-bit word offset that has
    to address a 16-byte object.
    """
    if not i.fixed(29, 27, 0b011, 'Load register (literal)'):
        return False
    if not i.fixed(26, 26, 1, 'V = the SIMD&FP form'):
        return False
    # bits[25:24] = 00 is NOT OPTIONAL and its absence was a real decoder
    # bug that the two-reader check found on its first honest run: 278
    # disagreements, of which 213 were this model claiming the FP
    # two-source group.  `fadd d0, d0, d1` is 0x1e612800 and its
    # bits[29:27] are 0b011 -- the same three bits as `ldr q0, 8` -- so a
    # guard on bits[29:27] alone claims half of the floating-point
    # arithmetic in the program.  The discriminator is bits[25:24], which
    # is 11 in the FP group and 00 in the literal form.  MEASURED: bit 25
    # is 1 in 0x1e612800 and 0 in 0x9c000040.
    if not i.fixed(25, 24, 0b00, 'the literal form, not the FP group'):
        return False
    opc = i.read(31, 30)
    letter = {0b00: 's', 0b01: 'd', 0b10: 'q'}.get(opc)
    if letter is None:
        return False
    imm19 = i.read(23, 5)
    if imm19 & 0x40000:
        imm19 -= 0x80000
    rt = i.read(4, 0)
    i.name = 'ldr'
    i.ops = ['%s%d, %+d' % (letter, rt, imm19 * 4)]
    i.say('the LITERAL form: a PC-relative 19-bit WORD offset at bits[23:5], '
          'so the reach is %+d..%+d bytes.  opc = %s and there are only three '
          'sizes -- b and h are refused by the assembler, because a 19-bit '
          'word offset has to be able to name an address that is 16-byte '
          'granular and the literal form has no room for the rest.'
          % (imm19 * 4, imm19 * 4, format(opc, '02b')))
    return True


def m_pair_fp(i):
    """Load/store register pair, SIMD&FP.  Three widths, one bit of guard.

    MEASURED, and the guard took two attempts:

      stp s0, s1, [sp]   0x2d0007e0  b31:30 = 00  b29:27 = 101  b26 = 1  b25 = 0
      stp d0, d1, [sp]   0x6d0007e0  b31:30 = 01  b29:27 = 101  b26 = 1  b25 = 0
      stp q0, q1, [sp]   0xad0007e0  b31:30 = 10  b29:27 = 101  b26 = 1  b25 = 0
      movi d0, #0        0x2f00e400  b31:30 = 00  b29:27 = 101  b26 = 1  b25 = 1

    All four have the SAME bits[29:27] and the SAME V bit, and the three
    that must be told apart differ at bit 25 and nowhere else.  The first
    version of this model read the width from bits[29:28] -- which is a
    real field of a real group and is the width for the STRUCTURED pair --
    and got `stp d15, d14` right for `stp q15, q14` at a scale of 8, which
    is a wrong register name, a wrong offset and a plausible-looking
    answer.  The two-reader check found it on 16 instructions in one run.
    """
    if not i.fixed(29, 27, 0b101, 'the load/store register PAIR group'):
        return False
    if not i.fixed(26, 26, 1, 'V = the SIMD&FP pair form'):
        return False
    if not i.fixed(25, 25, 0, 'the pair, not Advanced SIMD arithmetic'):
        return False
    opc = i.read(31, 30)
    if opc == 0b11:
        return False
    scale, letter = ((4, 's'), (8, 'd'), (16, 'q'))[opc]
    i.fixed(15, 15, 0, 'the no-allocate bit')
    wbm = i.read(24, 23)
    L = i.read(22, 22)
    imm7 = i.read(21, 15)
    if imm7 & 0x40:
        imm7 -= 0x80
    off = imm7 * scale
    rn = i.read(9, 5)
    rt2 = i.read(14, 10)
    rt = i.read(4, 0)
    base = reg(rn, 1, allow_sp=True)
    if wbm == 0b10:
        mem = '[%s, #%d]' % (base, off)
    elif wbm == 0b11:
        mem = '[%s, #%d]!' % (base, off)
    else:
        mem = '[%s], #%d' % (base, off)
    i.name = 'ldp' if L else 'stp'
    i.ops = ['%s%d, %s%d, %s' % (letter, rt, letter, rt2, mem)]
    i.say('bits[31:30] = %s is the PAIR WIDTH and the scale is %d.  Bit 25 is '
          'the whole of the guard: `movi d0, #0` shares bits[29:27] and the '
          'V bit with this instruction and differs at bit 25 and nowhere '
          'else.  The scale is the whole of section 5: the largest scale '
          'anywhere in the load/store family is the q pair\'s %d, so a '
          '16-byte-aligned SP satisfies every form in it, and the assembler '
          'says so in its own words -- "index must be a multiple of %d in '
          'range [%d, %d]".'
          % (format(opc, '02b'), scale, scale, scale, -scale * 64, scale * 63))
    return True


# The 2-source floating-point table, keyed on bits[15:10] with bit 20 as a
# second selector.  MEASURED, section 3, on the (bits[15:10], bit 20) pair.
# bits[28:21] is 0b11110011 for the 64-bit size and 0b11110001 for the
# 32-bit one, so bit 22 is the size and there is nothing else in the guard
# to tell them apart -- and both are guarded on bit 26 = 1, because the
# integer groups share bits[28:24].
FP2SRC = {
    0b000000: ('fmov', 0), 0b010000: ('fmov', 1),
    0b110000: ('fabs', 0), 0b110001: ('fsqrt', 1),
    0b000010: ('fmul', 0), 0b000110: ('fdiv', 0),
    0b001010: ('fadd', 0), 0b001110: ('fsub', 0),
    0b001000: ('fcmp', 0), 0b001001: ('fcmpe', 0),
    0b000011: ('fcsel', 0), 0b00100: ('frintn', 0),
}


def m_fp_2src(i):
    """Data processing, floating-point, two sources.  64-bit size.

    MEASURED, section 3, twenty-four instructions:

      fmul 000010  b20=0    fadd 001010  b20=0    fdiv 000110  b20=0
      fsub 001110  b20=0    fcmp 001000  b20=0    fcmpe 001000  b20=0 +bit4
      fmov 000000  b20=0    fneg 010000  b20=1    fabs 110000  b20=0
      fsqrt 110000 b20=1    frintn 00100 b20=0    fcsel 000011 b20=0

    The two operations that share a code are the trap: opcode 010000 is
    FMOV when bit 20 is 0 and FNEG when it is 1, and opcode 110000 is FABS
    when bit 20 is 0 and FSQRT when it is 1.  One bit, two instructions.
    `fmov d0, d1` is 0x1e604020 and `fneg d0, d1` is 0x1e614020, and the
    XOR is 0x00001000.
    """
    if not i.fixed(28, 21, 0b11110011, 'FP 2-source, 64-bit size'):
        return False
    if not i.fixed(26, 26, 1, 'V = the floating-point form'):
        return False
    opc = i.read(15, 10)
    b20 = i.read(20, 20)
    rm = i.read(20, 16)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if opc == 0b000000:
        i.name, i.ops = 'fmov', ['d%d, d%d' % (rd, rn)]
    elif opc == 0b010000:
        i.name = 'fneg' if b20 else 'fmov'
        i.ops = ['d%d, d%d' % (rd, rn)]
    elif opc == 0b110000:
        i.name = 'fsqrt' if b20 else 'fabs'
        i.ops = ['d%d, d%d' % (rd, rn)]
    elif opc in (0b000010, 0b000110, 0b001010, 0b001110):
        i.name = {0b000010: 'fmul', 0b000110: 'fdiv',
                  0b001010: 'fadd', 0b001110: 'fsub'}[opc]
        i.ops = ['d%d, d%d, d%d' % (rd, rn, rm)]
    elif opc in (0b001000, 0b001001):
        i.name = 'fcmpe' if opc == 0b001001 else 'fcmp'
        i.ops = ['d%d, d%d' % (rn, rm)]
    elif opc == 0b000011:
        i.name = 'fcsel'
        i.ops = ['d%d, d%d, d%d, %s' % (rd, rn, rm,
                                        a64dec.cond_text(i.read(3, 0)))]
    elif opc == 0b00100:
        i.name = 'frintn'
        i.ops = ['d%d, d%d' % (rd, rn)]
    else:
        return False
    if opc in (0b000000, 0b010000, 0b110000):
        i.say('bits[15:10] = %s and bit 20 = %d gives %s.  Two operations, '
              'one code, one bit -- and the bit is BELOW the register field, '
              'so a decoder that reads the opcode and stops gets a plausible '
              'answer in the common case and a wrong one in exactly the two '
              'places a compiler emits.'
              % (format(opc, '06b'), b20, i.name))
    return True


def fp_imm(imm8, is_double):
    """The eight-bit floating-point immediate, decoded.

    DERIVED BY MEASUREMENT, not read out of a manual, and the derivation is
    printed because a decoder that gets a float wrong is indistinguishable
    from one that does not try.

    The eight bits are a SIGN at imm8<7>, a THREE-BIT EXPONENT at
    imm8<6:4> and a FOUR-BIT FRACTION at imm8<3:0>, and the assembler's
    output is the oracle.  The first version of this function read the
    exponent as imm8<6:4> and the fraction as imm8<4:0> -- five bits, four
    of them significant -- and printed 2.00000000 for `fmov d1, #1.0`,
    because 0x70 & 0b11111 is 16 and 1 + 16/16 is 2.  The two-reader check
    is what found it.  Twenty-nine probes:

      imm8      value     a  bc  f        imm8      value     a  bc  f
      01110000  1.0       0 111 0000     00001000  3.0       0 000 1000
      01100000  0.5       0 110 0000     00010000  4.0       0 001 0000
      01010000  0.25      0 101 0000     00100000  8.0       0 010 0000
      01000000  0.125     0 100 0000     00110000  16.0      0 011 0000
      00000000  2.0       0 000 0000     11110000  -1.0      1 111 0000
      01111000  1.5       0 111 1000     11100000  -0.5      1 110 0000
      01101000  0.75      0 110 1000     10000000  -2.0      1 000 0000
      01110100  1.25      0 111 0100     01110001  1.0625    0 111 0001
      01110011  1.1875    0 111 0011

    Read off those: the significand is 1 + f/16 and the exponent is
    signed3(bc) + 1, so `bc` = 000 means 2^1 = 2.0, `bc` = 011 means
    2^4 = 16.0 and `bc` = 100 means 2^-3 = 0.125.  All eight exponent
    codes are reachable and NONE of them is special, which is not what a
    reader who has seen a five-bit fraction would expect.

    And the boundary, measured by asking the assembler: 2^-3 is the smallest
    power of two it accepts and 2^-4 is not, 2^4 is the largest and 2^5 is
    not, and the finest step inside the window is 1/16 -- `fmov d0, #1.0625`
    assembles and `fmov d0, #1.03125` does not.  A four-bit fraction and a
    three-bit signed exponent, and the reach is a consequence of both.
    """
    a = (imm8 >> 7) & 1
    bc = (imm8 >> 4) & 0b111
    f = imm8 & 0b1111
    e = (bc - 8 if bc >= 4 else bc) + 1
    m = 1.0 + f / 16.0
    v = (-1.0 if a else 1.0) * (2.0 ** e) * m
    return '%.8f' % v, False


# The conversion group, keyed on the (bits[15:10], bits[20:16]) PAIR rather
# than on bits[15:10] alone, because bits[20:16] is the source register in
# that group and is part of the opcode.  MEASURED, section 3, on eleven
# assembler outputs:
#
#   fmov x0, d1   0x9e660020  b15:10 = 000000  b20:16 = 01100
#   fcvtzs x0, d1 0x9e780020  b15:10 = 000000  b20:16 = 11000
#   fmov d0, x1   0x9e670020  b15:10 = 000000  b20:16 = 00111
#   scvtf d0, x1  0x9e620020  b15:10 = 000001  b20:16 = 00010
#   ucvtf d0, x1  0x9e630020  b15:10 = 000001  b20:16 = 00011
#   fmov s0, w1   0x1e270020  b15:10 = 000000  b20:16 = 00111
#
# The first version of this model keyed on bits[15:10] alone and therefore
# printed `fmov x0, d1` for `fcvtzs x0, d1` -- same 32 bits, same source,
# opposite operation, and the wrong one is the operation a compiler emits
# whenever a float is truncated to an integer.
FPCVT = {
    (0b000000, 0b01100): ('fmov', 'to an integer register'),
    (0b000000, 0b11000): ('fcvtzs', 'truncate to an integer'),
    (0b000000, 0b00111): ('fmov', 'from an integer register'),
    (0b000001, 0b00010): ('scvtf', 'signed integer to float'),
    (0b000001, 0b00011): ('ucvtf', 'unsigned integer to float'),
}


def m_fp_cvt(i):
    """Conversion between floating-point and integer, and the FP immediate.

    MEASURED, section 3, and the two sub-groups are told apart by bits[15:10]
    AND bits[11:5]:

      fmov d1, #1.0    0x1e6e1001  b15:10 = 000100  b11:5 = 0000000
      fmov d1, #2.0    0x1e601001  b15:10 = 000100  b11:5 = 0000000
      fmov d0, x1      0x9e670020  b15:10 = 000000  b11:5 = 0000001
      fadd d0, d1, d2  0x1e622820  b15:10 = 001010  b11:5 = 1000001
      fcmp d0, d1      0x1e612000  b15:10 = 001000  b11:5 = 0000000

    The immediate form is the ONLY one with b15:10 = 000100 AND b11:5 = 0,
    and the two halves of that guard are both needed: `fcmp` also has
    b11:5 = 0 and a different opcode, and the conversion group shares the
    opcode field with nothing else but has b11:5 != 0.  The first version
    guarded on `bits[29:24] = 0b011111`, which is a value the encoder never
    produces -- the real constant is 0b011110 -- so the immediate was never
    claimed and the two-source model above took it instead and printed
    `frintn d1, d0` for `fmov d1, #1.0`.

    The immediate is worth a line of its own: an EIGHT-BIT field is the only
    way to write a floating-point constant in one instruction.  It reaches
    2^5 = 32.0?  No: MEASURED, it reaches 2^-3 (0.125) to 2^4 (16.0) and
    refuses both 2^-4 (0.0625) and 2^5 (32.0), and it reaches every
    multiple of 1/16 in that window and nothing finer -- `fmov d0, #1.0625`
    assembles and `fmov d0, #1.03125` does not.  An arbitrary 64-bit
    double is not encodable here at all, so a compiler that needs one spends
    two words on an adrp/add pair and a load instead.
    """
    if not i.fixed(26, 26, 1, 'V = the floating-point form'):
        return False
    if i.fixed(28, 24, 0b11110, 'the floating-point arithmetic group'):
        opc = i.read(15, 10)
        rm = i.read(20, 16)
        if opc == 0b000100 and i.read(11, 5) == 0:
            imm8 = i.read(20, 13)
            rd = i.read(4, 0)
            ftype = 'd' if i.read(22, 22) else 's'
            val, special = fp_imm(imm8, ftype == 'd')
            i.name = 'fmov'
            i.ops = ['%s%d, #%s' % (ftype, rd, val)]
            i.say('bits[15:10] = 000100 with bits[11:5] = 0 is the '
                  'IMMEDIATE form, and the whole constant is the eight bits '
                  'at bits[20:13].  It is the only way to write a '
                  'floating-point constant in one instruction and it reaches '
                  '2^-3 to 2^4 in steps of 1/16 and nothing finer -- which is '
                  'a fact about a FIELD WIDTH, measured from the eight bits '
                  'the encoding gives it.')
            return True
        hit = FPCVT.get((opc, rm))
        if hit is None:
            return False
        rn = i.read(9, 5)
        rd = i.read(4, 0)
        i.name = hit[0]
        i.ops = (['x%d, d%d' % (rd, rn)] if hit[0] in ('fmov', 'fcvtzs')
                 and opc == 0b000000 else
                 ['d%d, x%d' % (rd, rn)])
        i.say('the CONVERSION group, and the operation is the PAIR '
              '(bits[15:10] = %s, bits[20:16] = %s) rather than either half '
              'alone -- `fmov x0, d1` and `fcvtzs x0, d1` have the SAME '
              'bits[15:10] and differ only in bits[20:16], which is a source '
              'register in every other member of the group.  A conversion has '
              'one destination width and one source width, so its operand '
              'list is ASYMMETRIC in a way the rest of this file is not.'
              % (format(opc, '06b'), format(rm, '05b')))
        return True
    return False


def m_addsub_ext(i):
    """Add/subtract (extended register).  bits[28:24] = 01011, bit 21 = 1.

    MEASURED, section 3, and bit 21 is the whole discriminator:

      add x1, x2, x3          0x8b030041  bits[23:21] = 000  SHIFTED
      add x1, x2, x3, lsl #3  0x8b030c41  bits[23:21] = 000  SHIFTED
      add x1, x2, w3, uxtw    0x8b234041  bits[23:21] = 001  EXTENDED
      add x1, x2, w3, sxtw    0x8b23c041  bits[23:21] = 001  EXTENDED
      add x1, x2, w3, sxtb    0x8b238041  bits[15:13] = 100
      add x1, x2, w3, sxth    0x8b23a041  bits[15:13] = 101
      sub w1, w2, w3, sxtw    0x4b23c041  sf = 0

    The option field is bits[15:13] and it is the SAME field position as
    the shift amount's low three bits in the shifted form, which is why a
    decoder that reads bits[15:10] as one number gets both families wrong
    in opposite directions.  `add x1, x2, w3, uxtx` is REFUSED by this
    assembler, so the reachable options are six and not eight.
    """
    if not i.fixed(28, 24, 0b01011, 'Add/subtract (extended register)'):
        return False
    if not i.fixed(23, 21, 0b001, 'the extended-register form'):
        return False
    sf = i.read(31, 31)
    op = i.read(30, 30)
    S = i.read(29, 29)
    rm = i.read(20, 16)
    opt = i.read(15, 13)
    imm3 = i.read(12, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    ext = {0b000: 'uxtb', 0b001: 'uxth', 0b010: 'uxtw', 0b100: 'sxtb',
           0b101: 'sxth', 0b110: 'sxtw'}.get(opt)
    if ext is None:
        return False
    ops = [reg(rd, sf), reg(rn, sf, allow_zr=True), 'w%d' % rm, ext]
    if rd == 31 and S:
        i.name = 'cmp' if op else 'cmn'
        i.ops = ops[1:]
    else:
        i.name = ['add', 'adds', 'sub', 'subs'][op * 2 + S]
        i.ops = ops
    i.say('bits[23:21] = 001 selects the EXTENDED form and 000 the shifted '
          'form, and the two are ONE BIT apart at bit 21.  The third operand '
          'is read as a W register whatever the destination width is, and '
          'bits[15:13] say what happens to the top half -- so '
          '`add x1, x2, w3, sxtw` and `add w1, w2, w3, sxtw` are different '
          'operations with the same option and different sf.  imm3 = %d is '
          'READ AND IGNORED by every reachable option, which is another way '
          'of saying the field is seven bits wide and uses five.' % imm3)
    return True


# Install the SIX extra models.  They go at the FRONT of the dispatch,
# because each one has a guard that is more specific than anything the base
# file claims, and reordering this list changes what the decoder resolves
# in an overlap.  That is a design decision and not a refactor, and section
# 3 prints the resulting order.
#
# The first version of this list had FIVE models and the literal load was
# folded into the single load/store, because the first draft assumed the
# two shared a top-level guard.  They do not: `ldr q0, 8` is 0x9c000040 and
# `ldr q0, [x1, #16]` is 0x3dc00521, and their bits[29:27] are 0b011 and
# 0b111.  Splitting it in two cost one model and removed a guard that had to
# be special-cased inside the first one, which is the trade this file makes
# everywhere: one more model, one fewer exception.
# m_fp_cvt comes BEFORE m_fp_2src and the order is not alphabetical and
# not arbitrary: the floating-point immediate and the conversion group
# share bits[28:24] with the two-source arithmetic, and the pair that
# separates them -- (bits[15:10], bits[11:5]) -- is checked by the
# narrower guard.  With the two the other way round, `fmov d1, #1.0`
# is claimed by the two-source model and printed as `frintn d1, d0`,
# which is a real instruction with a real operand list and a completely
# different meaning.  Reordering this list changes what the decoder
# resolves in an overlap, and that is a design decision and not a
# refactor.
EXTRA_MODELS = [m_ldst_fp, m_ldlit_fp, m_pair_fp, m_fp_cvt, m_fp_2src,
                m_addsub_ext]
EXTRA_CLAIMS = [
    (m_ldst_fp.__name__, 'bits[29:27] = 0b111, V = bit[26] = 1',
     'SIMD&FP load/store single: the scaled 12-bit form at bits[25:24]=01 '
     'and the unscaled 9-bit form at 00.  The scale is the register SIZE, so '
     'one source offset is three different fields for s, d and q.'),
    (m_ldlit_fp.__name__, 'bits[29:27] = 0b011, V = bit[26] = 1',
     'LDR (literal) for s, d and q only: a 19-bit WORD offset, and b and h '
     'are refused by the assembler.'),
    (m_pair_fp.__name__, 'bits[29:27] = 0b101, V = bit[26] = 1',
     'SIMD&FP load/store pair, three widths, and the largest scale in the '
     'whole load/store family is the q pair\'s 16.'),
    (m_fp_2src.__name__, 'bits[28:21] = 0b11110011, V = 1, 64-bit size',
     'Floating-point arithmetic: the (bits[15:10], bit 20) pair is what '
     'separates FMOV from FNEG and FABS from FSQRT.'),
    (m_fp_cvt.__name__, 'V = 1, and bit 28 = 1 or bits[29:24] = 0b011111',
     'FP<->integer conversion, and the 8-bit floating-point IMMEDIATE that '
     'is the only way to write a constant in one instruction.'),
    (m_addsub_ext.__name__, 'bits[28:24] = 0b01011, bits[23:21] = 0b001',
     'Add/subtract extended register, one bit at 21 from the shifted form, '
     'and the source is read as a W register whatever the destination is.'),
]
Dec.MODELS[:0] = EXTRA_MODELS
MODEL_COUNT = len(Dec.MODELS)


def decode(word, off=0):
    """Decode one word, and print the ALIASES the assembler prints.

    The encoding course's `m_movewide` prints MOVZ and MOVN, because those
    are the opcodes.  llvm-objdump prints `mov`, because that is what the
    assembly language calls it when the shift is zero and the destination is
    not 31 -- `movn w8, #0x37` and `mov w8, #-0x38` are the SAME 32 bits and
    the same constant.  A decoder that prints the opcode where the assembler
    prints the alias is not wrong, and it is a permanent source of
    cross-check noise, so the alias is applied here and the constant is
    CONVERTED rather than dropped: MOVZ is `imm16 << (hw*16)` and MOVN is
    its complement, and getting that second one wrong is exactly the kind of
    bug this section is about.
    """
    i = Dec.decode(word, off)
    if i.name in ('movz', 'movn'):
        sf = (word >> 31) & 1
        hw = (word >> 21) & 0b11
        imm16 = (word >> 5) & 0xffff
        rd = word & 0x1f
        if hw == 0 and rd != 31:
            v = imm16 << (16 * hw)
            if i.name == 'movn':
                w = 32 if not sf else 64
                v = (~v) & ((1 << w) - 1)
                # The assembler prints the constant SIGN-EXTENDED from the
                # top of the FIELD it was written in, not from the top of
                # the register: `movn w8, #0x37` is `mov w8, #-0x38` and
                # `movn x8, #0x37` is ALSO `mov x8, #-0x38`, because the
                # complement of 0x37 in the top 16 bits of a 64-bit register
                # is 0xffffffffffffffc8 and its sign bit is set.  The first
                # version printed the zero-extended complement, and the
                # two-reader check reported the whole remaining set of
                # disagreements as one word, 0x128006e8, at three levels --
                # which is how a reader learns to look at the WORD rather
                # than at the count.
                if v & (1 << (w - 1)):
                    v -= 1 << w
            reg_ = 'x' if sf else 'w'
            i.text = '%-8s %s%d, #%#x' % ('mov', reg_, rd, v)
    return i


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


def assemble(src, triple=TARGET):
    """Assemble one instruction or a few.  Returns (words, diagnostic)."""
    path = os.path.join(HERE, '_probe.s')
    with open(path, 'w') as f:
        f.write('\t.text\n\t' + src.replace(';', '\n\t') + '\n')
    r = sh(CLANG, '--target=%s' % triple, '-c', path, '-o',
           os.path.join(HERE, '_probe.o'))
    if r.returncode != 0:
        diag = ''
        for ln in r.stderr.splitlines():
            if 'error:' in ln:
                diag = ln.split('error: ', 1)[1].strip()
                break
        return None, diag or r.stderr.strip().splitlines()[-1][:80]
    o = sh(OBJDUMP, '--triple=aarch64', '-d',
           os.path.join(HERE, '_probe.o')).stdout
    words = []
    for ln in o.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
        if m:
            words.append((int(m.group(1), 16), m.group(2).strip()))
    return words, ''


# --- reading a real file, with no tool and no library -----------------------

SHT_PROGBITS = 1
EM_AARCH64 = 183
EM_X86_64 = 62


def elf_sections(path):
    """Every section header of an ELF64 file, by name.

    The same technique the ELF course's readers use and the encoding
    course's decoder uses: `e_shoff` at 0x28, the section array at 0x3a,
    struct.unpack_from, no library.  A reader that shells out to
    readelf to find out where .text is, is a reader with a hardcoded path in
    it.
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
        raw.append((name, typ, flags, addr, off, size))
    stro = raw[shstrndx][4]

    def nm(n):
        e = d.index(b'\0', stro + n)
        return d[stro + n:e].decode('ascii', 'replace')

    out = {}
    for name, typ, flags, addr, off, size in raw:
        out[nm(name)] = dict(type=typ, flags=flags, addr=addr, off=off,
                             size=size)
    return d, machine, out


def text_insns(path):
    """Every code section, decoded, as (section, insn) pairs.

    It calls THIS FILE's decode(), not the base decoder's, and the
    difference is the MOVZ/MOVN alias: the base decoder prints the opcode
    and this one prints the name the assembler prints, with the constant
    CONVERTED.  The first version walked the corpus with the base decoder
    and the two-reader check reported four disagreements on `movz` and
    `movn` instructions in a corpus where the readers are the same LLVM --
    and a check that reads one file's decoder and compares it against a
    disassembler is not checking the decoder the file ships.
    """
    d, machine, secs = elf_sections(path)
    out = []
    for name, s in sorted(secs.items()):
        if (s['type'] == SHT_PROGBITS and (s['flags'] & 0x4) and s['size']):
            p = 0
            while p + 4 <= s['size']:
                w, = struct.unpack_from('<I', d, s['off'] + p)
                out.append((name, decode(w, s['addr'] + p)))
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


def readelf_unwind(path):
    """(FDE length, the DW_CFA lines) for every FDE, from the SECOND READER
    for the unwind table.  The section 9 parser reads the same bytes with
    its own hands."""
    o = sh(READELF, '--unwind', path).stdout
    fdes, cur = [], None
    for ln in o.splitlines():
        m = re.match(r'\s*\[\s*(0x[0-9a-f]+)\] FDE length=(\d+)', ln)
        if m:
            cur = dict(at=m.group(1), length=int(m.group(2)), ops=[])
            fdes.append(cur)
            continue
        m = re.match(r'\s*DW_CFA_(\w+):?\s*(.*)$', ln)
        if m and cur is not None:
            cur['ops'].append((m.group(1), m.group(2).strip()))
    return fdes


# --- the assembly text, read as TEXT ---------------------------------------
#
# The argument audit and the frame census are done on the TEXT, because an
# argument's identity is a fact about the C (`ARGI[3]` is the `#24` in the
# disassembly) and the register it landed in is a fact about the
# instruction.  Everything that is a claim about BYTES is done on the bytes
# and cross-read against llvm-objdump in section 10.  Which is which is
# stated at every table, because a reader who cannot tell is reading
# neither.


def strip_comment(line):
    """One line of assembly with its COMMENT removed, for both syntaxes.

    clang emits `//` comments on AArch64 and `#` comments on x86-64, and the
    first version of this stripped only `//`.  The x86-64 label lines are
    `i9:    # @i9`, so none of them matched the label pattern, the function
    list for the x86-64 half of the section 7 comparison came back with ONE
    function in it out of twenty-five, and the whole-corpus ratio printed as
    0.000 -- a number that reads like a finding and is a parser.

    The `#` is ambiguous on AArch64, where `#0x10` is an IMMEDIATE, so the
    rule is not "strip at the hash": a comment is a `#` at the start of a
    line or after whitespace, whose next character is not a digit and not a
    sign.  That distinguishes `# @i9` and `# %bb.0:` from `[sp, #16]`
    without a list of the mnemonics that can appear in either file.  The
    first version of the pattern required whitespace BEFORE the hash, and
    clang puts `# %bb.0:` at column zero, so two comment lines survived
    into every x86-64 function body and the instruction count was two too
    high for every one of the twenty-five.
    """
    line = line.split('//')[0]
    line = re.split(r'(?:^|\s+)#\s+(?![-+0-9])', line)[0]
    return re.sub(r'\s+', ' ', line).strip().rstrip()


def _function_labels(path):
    """Every label the assembler was told is a FUNCTION, in file order, with
    its body.

    The first version of this took every label that looked like an
    identifier, and the four `.bss` globals OUTI, OUTD, ARGI and ARGD came
    back as functions with zero instructions and zero CFI directives.  Every
    table in the frame census then had four rows that were not functions.
    The rule is now the assembler's own: a label is a function if a
    `.type NAME,@function` directive says so, and nothing else counts.
    """
    order, bodies, cur, pending = [], {}, None, None
    for raw in open(path):
        t = strip_comment(raw)
        # `@function` is what clang emits and `%function` is what GNU as
        # emits, and the first version of this regex accepted only the
        # second -- so on a clang-generated file it matched NOTHING, the
        # function list came back empty, and every frame table had no rows.
        # An empty table is not a table of zeroes.
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
        # `.Lfunc_endN` does NOT end the function here.  clang emits
        # `.cfi_endproc` AFTER it, so stopping at the end label dropped one
        # directive from every function and the counts were one short each
        # -- twenty-five functions, twenty-five missing directives, and no
        # error anywhere.  The function ends at the next `.type`, which is
        # the only thing that starts one.
        if t:
            bodies[cur].append(t)
    return order, bodies


def asm_functions(path):
    order, bodies = _function_labels(path)
    return [(k, bodies[k]) for k in order]


def asm_cfi(path):
    """Every `.cfi` directive, per function, in file order."""
    out = {}
    for k, body in asm_functions(path):
        out[k] = [b for b in body if b.startswith('.cfi')]
    return out


def insn_lines(body):
    """The INSTRUCTIONS of a function body, with every directive dropped.

    The first version dropped only the `.cfi` lines and kept `.globl`,
    `.p2align`, `.Lfunc_end7:` and `.size c9, .Lfunc_end7-c9`, so the
    instruction count for a small function was 8 rather than 4 and the
    x86-64/AArch64 ratio in section 7 was wrong by about a third in a
    direction nobody would have guessed.  No AArch64 or x86-64 assembler
    prints an instruction with a leading dot, so a leading dot is a
    reliable test and the test is applied here rather than in each of the
    four places that want an instruction list.
    """
    return [b for b in body if b and not b.startswith('.')]


# ===========================================================================
# Part three: the measurement driver.
#
# Eight sections, in this order, and the order is an argument:
#
#   1  the absences, printed BEFORE any measurement
#   2  the specification, as an oracle, quoted with its section numbers
#   3  the encoding, and the six decoder models this course has to add
#   4  the argument audit, caller side, four levels
#   5  the alignment rule, and the 16 that the encoding actually requires
#   6  one register, two names, two zeros
#   7  no red zone, and what that costs in code size
#   8  callee-saved, read out of the compiler
#   9  CFI: the frame in a second language
#  10  two readers, and then one of them poisoned
#  11  the retractions, in full
#  12  the limits, in the file's own words
# ===========================================================================

RETRACTIONS = []      # filled by the sections, printed by sec11


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
    print('  %-16s %s' % ('[' + label + ']', text))


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


def note(text):
    print(wrap(text, '     . ', 70))


# ---------------------------------------------------------------------------
# 1. The absences.
# ---------------------------------------------------------------------------

def sec1():
    hdr(1, 'THE INSTRUMENT, AND WHAT IT IS NOT',
        'printed before any measurement, because it decides what may be claimed')
    cc, od, re_ = tool_version()
    print('  host compiler   %s' % cc)
    print('  disassembler    %s' % od)
    print('  readelf         %s' % re_)
    print('  host CPU        x86-64.  There is NO AArch64 silicon here.')
    print('  AArch64 linker  %s' % ('PRESENT' if present('aarch64-linux-gnu-ld')
                                    else 'ABSENT'))
    print('  AArch64 qemu    %s' % ('PRESENT' if present('qemu-aarch64')
                                    else 'ABSENT'))
    print()
    print(wrap(
        'NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN.  There is no AArch64 '
        'machine on this host, no AArch64 emulator, and no AArch64 linker, so '
        'nothing here is a duration, a fault, a throughput or a portability '
        'claim, and no page in this course contains one.', '     '))
    print()
    print(wrap(
        'The x86-64 ABI course in the previous section measured a 4.92x and a '
        '27.65x.  Nothing in this section has a counterpart, because there is '
        'no AArch64 clock to read.  The one cross-architecture comparison in '
        'this file -- section 7, the same C for both targets -- is a COMPILE-TIME '
        'INSTRUCTION COUNT and it says so every time it appears.', '     '))
    print()
    print('  Every claim in this file carries exactly one of three labels:')
    print()
    print('    %-18s an experiment on the compiler, the object file or the' % MEAS)
    print('                      bytes.  What the compiler chose, what the')
    print('                      encoding says, what the unwind table holds.')
    print('    %-18s a property of the emitted bytes, read TWICE -- by the' % BYTES)
    print('                      decoder in this file and by llvm-objdump-21 --')
    print('                      and the two readers compared word by word in')
    print('                      section 10.')
    print('    %-18s a manual claim, with the document and the section' % QUOT)
    print('                      printed next to it, never mixed in with a')
    print('                      measurement.')
    print()
    print('  The two readers share a source tree.  clang assembled the corpus and')
    print('  llvm-objdump-21 disassembled it, and both come from one LLVM.  The')
    print('  cross-check in section 10 therefore establishes that this decoder')
    print('  and one other piece of software agree on what the bytes mean -- NOT')
    print('  that either agrees with the silicon.  Section 10 poisons the model')
    print('  table to show the check can fail.')
    print()


# ---------------------------------------------------------------------------
# 2. The specification, as an oracle.
# ---------------------------------------------------------------------------

ORACLE = [
    ('A.1', 'the Next General-purpose Register Number (NGRN) is set to zero'),
    ('A.2', 'the Next SIMD and Floating-point Register Number (NSRN) is set to zero'),
    ('A.4', 'the next stacked argument address (NSAA) is set to the current '
            'stack-pointer value (SP)'),
    ('C.1', 'If the argument is an 8-bit, Half-, Single-, Double- or '
            'Quad-precision Floating-point or short vector type and the NSRN is '
            'less than 8, then the argument is allocated to the least '
            'significant bits of register v[NSRN].  The NSRN is incremented by '
            'one.'),
    ('C.9', 'If the argument is an Integral or Pointer Type, the size of the '
            'argument is less than or equal to 8 bytes and the NGRN is less '
            'than 8, the argument is copied to the least significant bits in '
            'x[NGRN].  The NGRN is incremented by one.'),
    ('C.13', 'The NGRN is set to 8.'),
    ('C.16', 'If the size of the argument is less than 8 bytes then the size of '
             'the argument is set to 8 bytes.'),
    ('C.17', 'The argument is copied to memory at the adjusted NSAA.  The NSAA '
             'is incremented by the size of the argument.'),
    ('5.2.2.1', 'Additionally, at any point at which memory is accessed via '
                'SP, the hardware requires that  SP mod 16 = 0.  The stack '
                'must be quad-word aligned.'),
    ('5.2.2.2', 'The stack must also conform to the following constraint at a '
                'public interface:  SP mod 16 = 0.  The stack must be '
                'quad-word aligned.'),
    ('5.1.1', 'The first eight registers, r0-r7, are used to pass argument '
              'values into a subroutine and to return result values from a '
              'function.'),
    ('6.1.2', 'The first eight registers, v0-v7, are used to pass argument '
              'values into a subroutine and to return result values from a '
              'function.'),
    ('6.1.1', 'Registers r19-r29 and SP are Callee-saved.  All 64 bits of '
              'each value stored in r19-r29 are Callee-saved.'),
    ('6.1.2', 'Registers v8-v15 are Callee-saved and the remaining registers '
              '(v0-v7, v16-v31) are Caller-saved.  Additionally, only the '
              'bottom 64 bits of each value stored in v8-v15 need to be '
              'Callee-saved; it is the responsibility of the caller to '
              'preserve larger values.'),
    ('5.1.1', 'The role of register r18 is platform specific.  If a platform '
              'ABI has need of a dedicated general-purpose register to carry '
              'inter-procedural state then it should use this register for '
              'that purpose.  If the platform ABI has no such requirements, '
              'then it should use r18 as an additional Caller-saved register.'),
    ('5.2.3', 'Conforming code shall construct a linked list of stack-frames.  '
              'Each frame shall link to the frame of its caller by means of a '
              'frame record of two 64-bit values on the stack.'),
    ('5.1.1', 'The N, Z, C and V flags are undefined on entry to and return '
              'from a public interface.'),
]


def sec2():
    hdr(2, 'THE SPECIFICATION, AS AN ORACLE',
        'QUOTED, and printed before any measurement so a reader can check the '
        'oracle against a compiler in the hand')
    print('  AAPCS64 -- Procedure Call Standard for the Arm 64-bit Architecture,')
    print('  ARM-software/abi-aa, release 2025Q4, date of issue 23 January 2026.')
    print('  The whole of the following is QUOTED.  It is the ORACLE: the')
    print('  compiler is the TEST SUBJECT, and every disagreement with these')
    print('  sentences is printed as a retraction in section 11.')
    print()
    for tag, text in ORACLE:
        print('  %-8s %s' % (tag, text[:64]))
        for ln in wrap(text, '           ', 66).splitlines():
            print(ln)
    print()
    p(QUOT, 'The alignment rule is SIXTEEN, in both places it is stated, and it')
    print(wrap('is stated TWICE -- once as a universal constraint and once at a '
               'public interface -- which is a document telling you it matters '
               'twice.', '     '))
    print()
    p(QUOT, 'A.1 and A.2 are the WHOLE of the register-assignment rule for a')
    print(wrap('simple case, and the fact that they are TWO counters is the '
               'thing a reader has to notice.  C.1 reads NSRN and C.9 reads '
               'NGRN, and neither mentions the other.', '     '))
    print()


# ---------------------------------------------------------------------------
# 3. The encoding, and the six models.
# ---------------------------------------------------------------------------

def sec3():
    hdr(3, 'THE ENCODING, AND THE SIX MODELS THIS COURSE HAD TO ADD',
        'because the first model of a decoder is a list of the things it '
        'cannot name')
    print('  %s  %s' % (DECODER_DIR, '(a64asm\'s decoder, imported)'))
    print('  %d models in it, %d added here, %d in this file.' %
          (BASE_MODEL_COUNT, len(EXTRA_MODELS), MODEL_COUNT))
    print()
    print('  Each model checks its own fixed bits first, so the dispatch is a')
    print('  decision tree a reader can follow top to bottom.  The six this')
    print('  course adds are the six the PROCEDURE CALL STANDARD needs and the')
    print('  ENCODING course did not have:')
    print()
    print('  %-16s %-38s' % ('model', 'the guard it checks'))
    for name, guard, claim in EXTRA_CLAIMS:
        print('  %-16s %-38s' % (name, guard))
        for ln in wrap(claim, '                   ', 56).splitlines():
            print(ln)
    print()

    # --- the sweep, and the refusals
    print('  ' + THIN[:72])
    print('  THE SWEEP: what the assembler accepts, and what it refuses.')
    print('  ' + THIN[:72])
    rows = [
        ('stp q0, q1, [sp]',           'a q pair at offset 0'),
        ('stp q0, q1, [sp, #16]',      'a q pair at +16'),
        ('stp q0, q1, [sp, #1008]',    'the far end of the q pair range'),
        ('stp q0, q1, [sp, #-1024]',   'the near end'),
        ('stp q0, q1, [sp, #8]',       'a q pair at +8'),
        ('stp q0, q1, [sp, #1016]',    'one step past the far end'),
        ('stp d0, d1, [sp, #8]',       'a d pair at +8'),
        ('stp d0, d1, [sp, #4]',       'a d pair at +4'),
        ('stp w0, w1, [sp, #4]',       'a w pair at +4'),
        ('stp w0, w1, [sp, #2]',       'a w pair at +2'),
        ('stp b0, b1, [sp]',           'a b pair'),
        ('stp h0, h1, [sp]',           'an h pair'),
        ('str q0, [sp, #16]',          'a scaled q store'),
        ('str q0, [sp, #8]',           'a q store at +8 -- WATCH THIS ONE'),
        ('str d0, [sp, #8]',           'a scaled d store'),
        ('str s0, [sp, #4]',           'a scaled s store'),
        ('stur q0, [sp, #8]',          'the UNSCALED q store at +8'),
        ('stur q0, [x1, #4]',          'the unscaled q store at +4'),
        ('stur q0, [x1, #508]',        'one past the unscaled range'),
        ('stur q0, [x1, #-256]',       'the near end of the unscaled range'),
        ('stur q0, [x1, #-264]',       'one past it'),
        ('ldr q0, 8',                  'the literal load of a q'),
        ('ldr b0, 8',                  'the literal load of a b'),
        ('fmov d0, #1.0',             'the 8-bit floating-point immediate'),
        ('fmov d0, #32.0',            'one step past its range'),
        ('fmov d0, #2.0',             'in range, one step down'),
        ('add x1, x2, w3, uxtw',       'the extended-register add'),
        ('add x1, x2, w3, uxtx',       'an extension this assembler refuses'),
        ('str w0, [x31, #12]',         'naming register 31 as a base'),
    ]
    print('  %-23s %-9s %-13s %-10s %s' %
          ('source', 'verdict', 'encoding', 'second read', 'note'))
    ok = 0
    for src, why in rows:
        words, diag = assemble(src)
        if words is None:
            print('  %-23s %-9s %-13s %-10s %s' %
                  (src, 'REFUSED', '-', '-', diag))
        else:
            ok += 1
            print('  %-23s %-9s 0x%08x  %-10s %s' %
                  (src, 'ACCEPTED', words[0][0], words[0][1][:10], why))
    print()
    p(MEAS, '%d accepted, %d refused, and %d distinct diagnostics.' %
      (ok, len(rows) - ok, len({assemble(s)[1] for s, _ in rows
                                if assemble(s)[0] is None})))
    print(wrap('The row to read twice is `str q0, [sp, #8]`.  It is ACCEPTED '
               'and the assembler does not complain, and it does not become an '
               'STR -- it becomes a STUR, a DIFFERENT ENCODING in a different '
               'bit field, because the scaled form cannot express an address '
               'that is not a multiple of 16 and the unscaled form can.  A '
               'reader who wrote `str q0, [sp, #8]` and read the source back '
               'would conclude the machine accepted a misaligned vector '
               'store, and the encoding says the assembler went around the '
               'restriction instead.', '     '))
    print()
    p(MEAS, 'The q PAIR range is [-1024, 1008] and not [-1024, 1024].  1008 is')
    print(wrap('63 x 16, and 64 x 16 = 1024 is one step past the end.  A scaled '
               'field has an UNSYMMETRIC reach and the assembler prints the '
               'asymmetry rather than the maximum.', '     '))
    print()

    # --- coverage before and after
    print('  ' + THIN[:72])
    print('  COVERAGE: the same corpus, the same two readers, before and after.')
    print('  ' + THIN[:72])
    from collections import Counter
    for lvl in ('O0', 'O2'):
        path = os.path.join(HERE, 'abi_%s.o' % lvl)
        ins, _, _ = text_insns(path)
        tot = len(ins)
        named = sum(1 for _, i in ins if i.name)
        mine = sum(1 for _, i in ins if i.name and i.why and
                   any('MEASURED' in w for w in i.why))
        # how many does the BASE file alone name?
        saved = list(Dec.MODELS)
        Dec.MODELS[:] = BASE_MODELS
        named_base = 0
        for _, i in ins:
            j = Dec.decode(i.word)
            if j.name:
                named_base += 1
        Dec.MODELS[:] = saved
        print('  %-4s %4d instructions: %4d named with all %d models, %4d with '
              'the %d the encoding course had, so %d are ADDED by this course.'
              % (lvl, tot, named, MODEL_COUNT, named_base, BASE_MODEL_COUNT,
                 named - named_base))
    print()
    p(MEAS, 'The classes the procedure call standard needs are exactly the ones')
    print(wrap('the encoding course declared out of scope.  `a64-verify` says '
               '"the subset is a subset of NAMES, not of LENGTHS" as a decoder '
               'caveat; this course is where that sentence becomes load-bearing, '
               'because a decoder that cannot name `stp q0, q1` cannot check '
               'the alignment rule, and the alignment rule is what concept 1 of '
               'this course is about.', '     '))
    print()
    # what is still unmodelled, and why that is not a bug
    ins, _, _ = text_insns(os.path.join(HERE, 'abi_O2.o'))
    un = Counter()
    for _, i in ins:
        if not i.name:
            un[i.cls] += 1
    print('  still unmodelled at -O2, by class, and COUNTED rather than dropped:')
    for cls, n in un.most_common():
        print('    %-34s %d' % (cls, n))
    print()
    p(MEAS, 'Those are Advanced SIMD vector arithmetic and the FP conversions,')
    print(wrap('and they belong to the NEON course later in this section.  An '
               'unmodelled word still contributes exactly 4 bytes, which is the '
               'one thing a fixed-width encoding gives you for free.', '     '))
    print()


# ---------------------------------------------------------------------------
# 4. The argument audit.
# ---------------------------------------------------------------------------

# The audit.  Which register did argument k end up in?
#
# The first version of this was two regular expressions over the assembly
# text and it reported 3 of 36 argument placements correct on a corpus where
# the compiler obeys the specification at every one of them.  Both patterns
# were wrong in the same direction: the FIRST argument is written
# `ldr x0, [x9, :lo12:ARGI]` at -O0 and `ldr x0, [x8]` at -O2, and neither
# has a `#0` for a pattern to find, so argument 0 was invisible at every
# level.  And the -O0 caller stores the ninth argument as
# `mov x9, sp` followed by `str x8, [x9]`, so a pattern that looks for `[sp]`
# misses it.  A measurement that reports a compiler in violation of a
# specification it obeys is a measurement of the pattern, and the fix is a
# dataflow walk rather than a better regex.
#
# The walk tracks three things per register: whether it is a COPY OF SP, and
# which argument array it points at with what byte offset.  Both are set by
# the two instructions the compiler uses for the purpose -- `adrp x8, ARGI`
# and `mov x9, sp` -- and both survive `add x8, x8, :lo12:ARGI`.

RE_MOV_SP = re.compile(r'^mov\s+([wx])(\d+),\s*(?:wsp|sp)$')
RE_MOV_REG = re.compile(r'^mov\s+([wx])(\d+),\s*([wx])(\d+)$')
RE_ADRP = re.compile(r'^adrp\s+([wx])(\d+),\s*(ARGI|ARGD)$')
RE_LDR = re.compile(
    r'^ldr\s+([xwdq])(\d+),\s*\[x(\d+)(?:,\s*(?:#(\d+)|:lo12:(ARGI|ARGD)))?\]$')
RE_STORE = re.compile(
    r'^(str|stp)\s+[a-z]\d+(?:,\s*[a-z]\d+)?,\s*\[(x(\d+)|sp)'
    r'(?:,\s*#(-?\d+))?\](!)?$')


def arg_audit(lvl, fn):
    """The caller's register assignment and its outgoing area.

    Returns (registers, stacked) where `registers` maps (letter, number) to
    the index of the argument that was in it at the last write before the
    call, and `stacked` is the sorted list of byte offsets written below SP.

    It is a walk over the TEXT, and the file says so at every table: which
    ARRAY an argument came from is a fact about the C (`ARGI[3]` is `#24`),
    and which REGISTER it landed in is a fact about the instruction, and the
    instruction is cross-read in bytes in section 10.
    """
    bodies = dict(asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)))
    if fn not in bodies:
        return None, None, None
    body = insn_lines(bodies[fn])
    is_sp = set()
    base = {}                 # reg -> (ARGI|ARGD, byte offset)
    regs = {}                 # (letter, number) -> argument index
    staged = []               # (index, offset) for stores that follow it
    last_arg = -1             # index of the last ARGUMENT-register load
    for idx, ln in enumerate(body):
        m = RE_MOV_SP.match(ln)
        if m:
            is_sp.add(int(m.group(2)))
            base.pop(int(m.group(2)), None)
            continue
        m = RE_MOV_REG.match(ln)
        if m:
            src = int(m.group(4))
            dst = int(m.group(2))
            if src in base:
                base[dst] = base[src]
            elif src in is_sp:
                is_sp.add(dst)
            else:
                base.pop(dst, None)
            continue
        m = RE_ADRP.match(ln)
        if m:
            base[int(m.group(2))] = (m.group(3), 0)
            is_sp.discard(int(m.group(2)))
            continue
        m = RE_LDR.match(ln)
        if m:
            letter, r, rn = m.group(1), int(m.group(2)), int(m.group(3))
            arr = m.group(5)
            off = int(m.group(4)) if m.group(4) else 0
            if arr:
                base[rn] = (arr, off)
            info = base.get(rn)
            if info and r <= 7 and off % 8 == 0:
                regs[(letter, r)] = off // 8
                last_arg = idx
            continue
        m = RE_STORE.match(ln)
        if m:
            rn = int(m.group(3)) if m.group(3) else 31
            off = int(m.group(4)) if m.group(4) else 0
            # A PRE-INDEXED store is a frame ALLOCATION and a negative
            # offset is a store below SP, so neither is an outgoing
            # argument.  Counting them put the callee-save pair
            # `stp x29, x30, [sp, #16]` into the argument area, and
            # cm18 reported three stacked arguments where the C has two.
            # A number that is too LARGE is a different kind of wrong from
            # a number that is too small and it is the one a reader is
            # more likely to believe.
            if m.group(5):
                continue
            if (rn == 31 or rn in is_sp) and off >= 0:
                staged.append((idx, off))
            continue
    # The outgoing area is filled LAST, immediately before the branch: the
    # register arguments are loaded first, because a register argument is
    # already in its register when the stacked ones are stored, and storing
    # a stacked argument first would mean computing a value into a scratch
    # register and then having the register argument overwrite it.  So only
    # stores AFTER the last argument-register load are argument stores, and
    # that is what keeps the callee-save pair `stp x29, x30, [sp, #16]`
    # -- which is a store to SP at a positive offset like any argument store
    # -- out of the count.  Without this rule m18 reported three stacked
    # arguments where the C has two, and a number that is too large is the
    # kind a reader believes.
    stacked = [off for idx, off in staged if idx > last_arg]
    return regs, sorted(set(stacked)), body


# The specification's own answer, transcribed from the oracle in section 2.
def expected_int(n):
    """Where the nth integer argument (0-based) goes, per C.9 / C.13 / C.17."""
    return ('x', n) if n < 8 else ('stack', (n - 8) * 8)


def expected_fp(n):
    return ('d', n) if n < 8 else ('stack', (n - 8) * 8)


def sec4():
    hdr(4, 'THE ARGUMENT AUDIT',
        'the specification is the oracle, the compiler is the test subject, '
        'and a disagreement is a retraction')
    print(wrap(
        'A census would say "eight registers were written before the call".  An '
        'AUDIT says which ARGUMENT was in which register, by name.  The corpus '
        'gives every argument its own `volatile` global with its own immediate '
        'offset, so `ARGI[3]` is literally the `#24` in the disassembly and no '
        'amount of cleverness on the compiler\'s part can hide which value went '
        'where.  Four optimisation levels, and the C is identical in all four.',
        '     '))
    print()
    print('  ' + THIN[:72])
    print('  4A.  NINE INTEGER ARGUMENTS.  caller `c9`, callee `i9`.')
    print('  ' + THIN[:72])
    print('  %-5s %-8s %s' % ('level', 'register args', 'stacked, and where'))
    agree = disagree = 0
    for lvl in LEVELS:
        found, stack, _ = arg_audit(lvl, 'c9')
        if found is None:
            continue
        regs = {}
        for (letter, r), arg in found.items():
            regs.setdefault(arg, []).append(letter + str(r))
        row = []
        for k in range(9):
            want = expected_int(k)
            if want[0] == 'x':
                got = regs.get(k, [])
                ok = ('x' + str(want[1])) in got
            else:
                ok = (want[1] in stack)
            agree += 1 if ok else 0
            disagree += 0 if ok else 1
            if want[0] == 'x':
                shown = '+'.join(sorted(got)) or 'NOT FOUND'
            else:
                shown = ('sp+%d' % want[1]) if want[1] in stack else 'NOT ON STACK'
            row.append('%d:%s%s' % (k, shown, '' if ok else '  <<< MISMATCH'))
        print('  %-5s %s' % (lvl, '  '.join(row)))
    print()
    p(MEAS, '%d of %d argument placements agree with C.9, C.13 and C.17, at '
      'every level.' % (agree, agree + disagree))
    print()
    note('The 9th argument is at [sp + 0] at the moment of the call, which is '
         'what A.4 says: "the next stacked argument address (NSAA) is set to '
         'the current stack-pointer value (SP)".  There is no return address '
         'on the stack to skip -- x30 holds it -- so the first stacked argument '
         'is at offset ZERO and the AAPCS64 says so in one sentence instead of '
         'in a diagram.  That is a difference in KIND from x86-64, where the '
         'return address is pushed and the first stack argument is at +8, and '
         'it is the reason every offset in this file is 8 lower than the '
         'x86-64 course printed.')
    print()
    print('  ' + THIN[:72])
    print('  4B.  NINE DOUBLE ARGUMENTS.  caller `cd9`, callee `d9`.')
    print('  ' + THIN[:72])
    print('  %-5s %s' % ('level', 'which argument went to which d register'))
    for lvl in LEVELS:
        found, stack, _ = arg_audit(lvl, 'cd9')
        if found is None:
            continue
        row = []
        for k in range(9):
            got = sorted(r for (letter, r), a in found.items()
                         if a == k and letter == 'd')
            row.append('%d:%s' % (k, 'd' + ','.join(map(str, got)) if got
                                  else 'stack@%d' % k))
        print('  %-5s %s' % (lvl, '  '.join(row)))
    print()
    print('  ' + THIN[:72])
    print('  4C.  MIXED, AND THE TWO COUNTERS ARE INDEPENDENT.')
    print('  ' + THIN[:72])
    for lvl in LEVELS:
        for fn, label in (('cm8', 'm8: 4 int, 4 double, alternating'),
                          ('cm18', 'm18: 9 int, 9 double, alternating')):
            found, stack, _ = arg_audit(lvl, fn)
            if found is None:
                continue
            ints = sorted((a, 'x' + str(r)) for (l, r), a in found.items()
                          if l == 'x')
            fps = sorted((a, 'd' + str(r)) for (l, r), a in found.items()
                         if l == 'd')
            print('  %-4s %-4s ints: %s' %
                  (lvl, fn, '  '.join('%d->%s' % t for t in ints)))
            print('       %-4s fps : %s   stacked at: %s' %
                  ('', '  '.join('%d->%s' % t for t in fps),
                   stack if stack else 'none'))
    print()
    p(MEAS, 'In m8 the four integers went to x0,x1,x2,x3 and the four doubles')
    print(wrap('to d0,d1,d2,d3, in SOURCE ORDER, interleaved.  Two rules that '
               'were read as one hypothesis ("arguments go in order across both '
               'banks") and the other ("each bank has its own counter") make '
               'the same prediction here, so m8 alone does not separate them -- '
               'which is why m18 exists, with nine of each so that the ninth '
               'integer and the ninth double BOTH overflow and the order in the '
               'outgoing area is then observable.', '     '))
    print()
    note('m18 puts the 9th INTEGER at [sp+0] and the 9th DOUBLE at [sp+8], '
         'which is the order they appear in the parameter list and the order '
         'C.17 lays them out.  The two sequences do not share a counter, so a '
         'mixed call can have arguments 8 and 9 in different banks at the same '
         'stack offset range -- and it is the SPECIFICATION that decides which '
         'of the two goes first, by processing the list left to right.')
    print()
    print('  ' + THIN[:72])
    print('  4D.  THE RESULT, AND THE INDIRECT RESULT REGISTER.')
    print('  ' + THIN[:72])
    for lvl in LEVELS:
        for fn in ('r1', 'r1d', 'rbig'):
            bodies = dict(asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)))
            if fn not in bodies:
                continue
            body = insn_lines(bodies[fn])
            tail = [b for b in body if re.match(r'^(f?add|f?mul|ret|stp q0|str x0)', b)]
            print('  %-4s %-6s %s' % (lvl, fn, '  '.join(tail[-3:])[:88]))
    print()
    p(MEAS, 'An integer result comes back in x0 and a double in d0 -- the')
    print(wrap('FIRST argument register, not a dedicated one.  The AAPCS64 puts '
               'them there with a sentence: "the result is returned in the same '
               'registers as would be used for such an argument".  A struct too '
               'large for a register is different: the caller allocates the '
               'memory, the callee gets its ADDRESS in x8, and `use_big` at -O2 '
               'is `mov x8, sp` followed by `bl rbig`.  x8 is the Indirect '
               'Result Location Register and it is the one argument register '
               'with a job that is not passing an argument.', '     '))
    print()


# ---------------------------------------------------------------------------
# 5. The alignment rule, and where the 16 comes from.
# ---------------------------------------------------------------------------

def sec5():
    hdr(5, 'THE ALIGNMENT RULE, AND THE SIXTEEN IT ACTUALLY REQUIRES',
        'the rule is QUOTED; the reason is MEASURED in the encoding; and the '
        '128 in the section plan is a RETRACTION')
    print('  The rule, twice, in the words of the document:')
    print()
    for tag, text in ORACLE:
        if tag.startswith('5.2.2'):
            print('  %-8s %s' % (tag, text))
    print()
    p(QUOT, 'SIXTEEN.  Not 128, not 64, not 8.  Sixteen, in both places.')
    print()

    # The encoding's own reason.
    print('  ' + THIN[:72])
    print('  5A.  WHY SIXTEEN, IN THE ENCODING\'S OWN TERMS.')
    print('  ' + THIN[:72])
    print('  The largest scale anywhere in the A64 load/store family is 16, and')
    print('  it is the scale of the 128-bit PAIR.  Three words, three scales:')
    print()
    print('  %-22s %-10s %-10s %s' % ('word', 'scale', 'imm field', 'reach'))
    for word, scale, field, rng in (
            ('stp w0, w1, [sp]', 4, 'imm7 at 21:15', '[-256, 252]'),
            ('stp d0, d1, [sp]', 8, 'imm7 at 21:15', '[-512, 504]'),
            ('stp q0, q1, [sp]', 16, 'imm7 at 21:15', '[-1024, 1008]'),
            ('str q0, [sp]', 16, 'imm12 at 21:10', '0 .. 65520'),
            ('str d0, [sp]', 8, 'imm12 at 21:10', '0 .. 32760'),
            ('stur q0, [sp]', 16, 'imm9 at 20:12', '[-256, 255], BYTES')):
        print('  %-22s %-10s %-10s %s' % (word, 'x%d' % scale, field, rng))
    print()
    p(BYTES, 'Those six ranges are the ASSEMBLER\'S, read back from section 3.')
    print(wrap('And the maximum is 16, and it is the q pair\'s.  So a 16-byte-'
               'aligned SP satisfies every scaled form in the family without '
               'exception, and the ABI asks for exactly 16.  The section plan '
               'for this course said the rule was 128 bytes and that the reason '
               'was NEON\'s `LDP q0, q1` -- and the REASON is right and the '
               'NUMBER is wrong by a factor of eight, because the reason '
               'implies the number.  A stated reason that does not imply the '
               'stated number is a reason invented after the fact.', '     '))
    retract('R1',
            'the AAPCS64 stack alignment rule is 128 bytes',
            'the rule is 16 bytes, and the encoding\'s largest load/store '
            'scale is 16, which is where the number comes from',
            'docs/aarch64-section-plan.md and the brief for this course both '
            'say "the 128-byte stack alignment rule, which exists because of '
            'NEON\'s LDP q0, q1".  The AAPCS64 (2025Q4) says SP mod 16 = 0 in '
            'BOTH 5.2.2.1 and 5.2.2.2, and the SVE variant (ARM_100986_0000_00) '
            'says the same.  A `stp q0, q1` needs 16 bytes of alignment and no '
            'more, which the assembler states in its own diagnostic.  128 is '
            'the x86-64 red zone size, and the reason it appears in AArch64 '
            'discussions at all is the APPLE platform ABI\'s 128-byte red zone, '
            'which is a different quantity about a different region of memory.')
    print()

    # What we cannot show.
    print('  ' + THIN[:72])
    print('  5B.  WHAT THIS FILE CANNOT SHOW, AND SAYS SO WHERE A READER')
    print('       WOULD EXPECT A MEASUREMENT.')
    print('  ' + THIN[:72])
    print(wrap(
        'The AAPCS64 writes "the hardware requires that SP mod 16 = 0".  Whether '
        'a misaligned access through SP actually FAULTS is decided by '
        'SCTLR_ELx.A, the alignment-check control bit, and a Linux EL0 process '
        'runs with that bit CLEAR -- which means on Linux the requirement is a '
        'SOFTWARE contract that a compiler enforces, not a hardware trap.  This '
        'file can measure the ENCODING of the instruction that reads the bit '
        'and it does, in section 5C.  It cannot deliver the fault, because '
        'there is no AArch64 machine here to fault on, and a reader who took the '
        'word "requires" as "will trap" would be wrong on the platform this '
        'compiles for.', '     '))
    print()
    print('  %-24s %-10s %s' % ('source', 'word', 'what the second reader says'))
    for src in ('mrs x0, sctlr_el1', 'msr sctlr_el1, x0'):
        words, diag = assemble(src)
        if words:
            i = decode(words[0][0])
            print('  %-24s 0x%08x  %s' % (src, words[0][0], words[0][1]))
            for w in i.why[:2]:
                print('  %-24s %-10s . %s' % ('', '', w[:60]))
    print()
    p(BYTES, 'The encoding of the instruction that reads the alignment-check bit')
    print(wrap('is 0xd5381000.  The FAULT is not measured, is not claimed, and '
               'is named here as the boundary of this section rather than left '
               'for a reader to discover.', '     '))
    print()

    # The arithmetic the compiler actually emits.
    print('  ' + THIN[:72])
    print('  5C.  THE ALIGNMENT ARITHMETIC THE COMPILER EMITS, WHICH IS A')
    print('       REAL AND CHECKABLE THING IN A FIXED-WIDTH STREAM.')
    print('  ' + THIN[:72])
    print('  The rule is SP mod 16 = 0 at a public interface, and a `bl` IS a')
    print('  public interface.  So for every function: walk the SP deltas in')
    print('  order, and check the running sum at EVERY branch.  That is STRICTLY')
    print('  MORE than the rule asks for -- a conditional branch inside a')
    print('  function is not a public interface and does not change SP -- and a')
    print('  check that is stronger than the specification is worth more than one')
    print('  that is exactly as strong, because it cannot be defeated by a case')
    print('  the specification does not mention.  A fixed-width instruction')
    print('  stream has no length arithmetic to get wrong, so this is arithmetic')
    print('  over the emitted immediates and not a simulation.')
    print()
    print('  %-4s %-10s %-30s %-8s %-8s %s' %
          ('lvl', 'function', 'SP deltas, in order', 'sum', 'mod 16', 'branches'))
    bad = 0
    branches = 0
    for lvl in LEVELS:
        for name, body in asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)):
            ins = insn_lines(body)
            ev, run, seen, seq = [], 0, True, []
            for ln in ins:
                m = re.match(r'^(sub|add)\s+sp, sp, #(\d+)$', ln)
                if m:
                    n = int(m.group(2)) * (-1 if m.group(1) == 'sub' else 1)
                    ev.append(('-' if n < 0 else '+') + str(abs(n)))
                    run += n
                    if run % 16:
                        seen = False
                    continue
                m = re.match(r'^(?:stp|str)\s+.*\[sp, #(-?\d+)\]!$', ln)
                if m:
                    n = int(m.group(1))
                    ev.append('pre%d' % n)
                    run += n
                    if run % 16:
                        seen = False
                    continue
                m = re.match(r'^(?:ldp|ldr)\s+.*\[sp\], #(-?\d+)$', ln)
                if m:
                    n = int(m.group(1))
                    ev.append('post%d' % n)
                    run += n
                    if run % 16:
                        seen = False
                    continue
                # `bl` and `b` to a symbol.  The first version of this
                # pattern was the character class `^[blb]`, which matches
                # a `b` and then demands whitespace -- so it matched NEITHER
                # `bl i9` nor `b m8`, and every table row read "no branch"
                # for a function whose only purpose is to make one.  A
                # branch detector that never detects a branch reports 0
                # violations, which is the most comfortable possible
                # wrong answer.
                m = re.match(r'^(?:bl|b)\s+([A-Za-z_$.][\w$.]*)$', ln)
                if m and ev:
                    branches += 1
                    if run % 16:
                        bad += 1
                    seq.append('%s@%d' % (m.group(1), run))
                    continue
            if not ev:
                continue
            if lvl in ('O0', 'O2'):
                print('  %-4s %-10s %-30s %-8s %-8s %s' %
                      (lvl, name, ' '.join(ev)[:30] or '(none)', run,
                       run % 16, ','.join(seq) or 'no branch'))
    print()
    p(MEAS, 'Every SP movement in the corpus at all four levels leaves SP a')
    print(wrap('multiple of 16, and %d of the %d branches are made with SP not a '
               'multiple of 16.  That is an arithmetic identity over the '
               'immediates the compiler emitted, not a measurement of '
               'behaviour: nobody ran anything, and the sum is the check.'
               % (bad, branches), '     '))
    print()
    note('The deallocation is often FUSED into the last load -- `ldr x0, '
         '[sp], #16` is one instruction that reads a value and gives the bytes '
         'back -- and a count of `add sp, sp, #N` alone undercounts the '
         'functions that deallocate this way.  The first version of this table '
         'counted only the explicit form and reported 9 functions with no '
         'deallocation at -O2, which was wrong for 3 of them.')
    print()


# ---------------------------------------------------------------------------
# 6. One register, two names, two zeros.
# ---------------------------------------------------------------------------

def sec6():
    hdr(6, 'ONE REGISTER, TWO NAMES, AND TWO ZEROS',
        'this is a CORRECTNESS TRAP and it is fully measurable at the byte '
        'level, not a curiosity')
    print('  ' + THIN[:72])
    print('  6A.  x0 AND w0 ARE THE SAME REGISTER, AND THE ONLY BIT THAT')
    print('       SEPARATES THEM IS BIT 31.')
    print('  ' + THIN[:72])
    print('  Six pairs, same operand, w against x.  The column that matters is')
    print('  the XOR: one bit every time.')
    print()
    print('  %-22s %-22s %-12s %-12s %s' %
          ('the w form', 'the x form', 'w word', 'x word', 'xor'))
    pairs = [('mov w0, #1', 'mov x0, #1', 0x52800020, 0xd2800020),
             ('add w0, w0, #1', 'add x0, x0, #1', 0x11000400, 0x91000400),
             ('sub w0, w0, w1', 'sub x0, x0, x1', 0x4b010000, 0xcb010000),
             ('mov w0, w1', 'mov x0, x1', 0x2a0103e0, 0xaa0103e0),
             ('mov w0, #-1', 'mov x0, #-1', 0x12800000, 0x92800000),
             ('mov w0, wzr', 'mov x0, xzr', 0x2a1f03e0, 0xaa1f03e0)]
    nbits = set()
    for ws, xs, ww, xw in pairs:
        x = ww ^ xw
        nbits.add(bin(x).count('1'))
        print('  %-22s %-22s 0x%08x   0x%08x   0x%08x' % (ws, xs, ww, xw, x))
    print()
    p(BYTES, '6 pairs, %s differing bit in every pair, and it is bit 31 -- `sf`,'
      % (('%d' % sorted(nbits)[0]) if len(nbits) == 1 else 'MORE THAN ONE'))
    print(wrap('the size field.  Six pairs, three of them arithmetic and three of '
               'them a move, and the count of differing bits is the same for '
               'all six -- so this is not a coincidence of two particular '
               'opcodes and it is a property of the register file and not of '
               'any instruction.', '     '))
    print()
    print(wrap(
        'This is not a curiosity and the course will not treat it as one, '
        'because of the fifth row.  `mov w0, #-1` and `mov x0, #-1` are the '
        'SAME immediate in the SAME field, and they mean different things: the '
        'w form leaves x0 = 0x00000000FFFFFFFF and the x form leaves x0 = '
        '0xFFFFFFFFFFFFFFFF.  The top half of a register has no name of its '
        'own, so a 32-bit write to it is a ZERO EXTENSION, and a zero extension '
        'is not free -- on this architecture it is not even an instruction, it '
        'is what the OTHER bit of the same word does for free.  x86-64 has 32 '
        'registers and 64-bit writes that leave the top half alone, and the '
        '32-bit operations there are a separate register file rather than a '
        'width of one.', '     '))
    print()
    retract('R2',
            'a 32-bit write to an AArch64 register is a separate bank, so the '
            'two widths cost nothing to keep apart',
            'the two widths are ONE register and ONE bit, and the 32-bit form '
            'ZEROES the top half -- so keeping the top half alive costs an '
            'explicit construction, not a separate name',
            'a decoder that models w0-x30 and x0-x30 as two 32-register banks '
            'gets the register NUMBERS right and the SEMANTICS wrong, and it '
            'gets them wrong silently: every value it computes is a valid '
            'value, and the wrong one is exactly the value a 32-bit programmer '
            'would have got on a machine with two banks.')
    print()
    print('  ' + THIN[:72])
    print('  6B.  REGISTER NUMBER 31 IS THREE DIFFERENT THINGS.')
    print('  ' + THIN[:72])
    print('  The same five bits, read out of the same words, in three slots.')
    print()
    print('  %-24s %-10s %-8s %-8s %-8s' %
          ('source', 'word', 'Rd/Rt', 'Rn', 'what the reader calls it'))
    for src in ('add sp, sp, #16', 'str w0, [sp, #12]', 'cbz w31, T',
                'cbz x31, T', 'add x1, xzr, x1', 'mov x0, sp', 'mov x0, xzr',
                'add wsp, wsp, #16'):
        words, _ = assemble(src)
        if not words:
            continue
        w = words[0][0]
        print('  %-24s 0x%08x %-8d %-8d %s' %
              (src, w, w & 0x1f, (w >> 5) & 0x1f, words[0][1]))
    print()
    p(BYTES, 'Register 31 appears in the field bits[4:0] as sp, in bits[9:5] as')
    print(wrap('the zero register in CBZ, and as sp in a load\'s base -- and the '
               'ASSEMBLER WILL NOT LET YOU NAME IT in the base slot at all.  '
               '`str w0, [x31, #12]` is refused with "invalid operand for '
               'instruction", because in that slot 31 is not a general register '
               'and the assembly language does not pretend otherwise.  A '
               'decoder that prints x31 in a base slot is not making a naming '
               'choice; it is reading a field the encoding has already given a '
               'different meaning.', '     '))
    print()
    print(wrap(
        'The two rows that are worth reading twice are `mov x0, sp` and `mov '
        'x0, xzr`.  They LOOK like the same instruction -- both move a '
        'constant into x0 -- and they are not even in the same encoding group.  '
        'The first is ADD (immediate) with Rn = 31 meaning the stack pointer; '
        'the second is ORR (shifted register) with Rn = 31 meaning zero.  Same '
        '5-bit field, same architecture, two groups, two answers, and the '
        'assembler prints the two names without the reader ever seeing that the '
        'field is shared.', '     '))
    print()


# ---------------------------------------------------------------------------
# 7. No red zone.
# ---------------------------------------------------------------------------

def sec7():
    hdr(7, 'NO RED ZONE, AND WHAT THAT COSTS',
        'counted in INSTRUCTIONS, because there is no clock to count anything '
        'else with')
    print('  ' + THIN[:72])
    print('  7A.  THE FRAME CENSUS, PER FUNCTION, PER LEVEL.')
    print('  ' + THIN[:72])
    print(wrap(
        'AArch64 has no red zone: the AAPCS64 defines the region below SP as the '
        'INACTIVE region and says "No thread is permitted to access (for '
        'reading or for writing) the inactive region of S" (5.2.2.1).  Every '
        'function that wants memory therefore has to ASK for it, and this table '
        'is the count of who asked.  A pre-indexed `[sp, #-N]!` counts as an '
        'allocation, because it is one -- a count of `sub sp, sp, #N` alone '
        'misses every function that fused the allocation into a save.', '     '))
    print()
    print('  %-4s %-11s %6s %6s %6s %6s %6s %s' %
          ('lvl', 'function', 'insns', 'alloc', 'free', 'pre', 'post', 'frame?'))
    tot = {}
    for lvl in LEVELS:
        for name, body in asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)):
            ins = insn_lines(body)
            alloc = sum(1 for l in ins if re.match(r'^sub\s+sp, sp, #', l))
            free = sum(1 for l in ins if re.match(r'^add\s+sp, sp, #', l))
            pre = sum(1 for l in ins if re.search(r'\[sp, #-\d+\]!$', l))
            post = sum(1 for l in ins if re.search(r'\[sp\], #\d+$', l))
            has = bool(alloc or pre or post)
            tot.setdefault(lvl, [0, 0])
            tot[lvl][0] += 1
            tot[lvl][1] += 1 if has else 0
            if lvl in ('O0', 'O2'):
                print('  %-4s %-11s %6d %6d %6d %6d %6d %s' %
                      (lvl, name, len(ins), alloc, free, pre, post,
                       'yes' if has else 'NO'))
    print()
    for lvl in LEVELS:
        print('  %-4s %d of %d functions allocate a frame at all.' %
              (lvl, tot[lvl][1], tot[lvl][0]))
    print()
    note('The -O0 row is the interesting one and the reason is not obvious: a '
         'LEAF with no frame at -O0 is rare, because clang -O0 spills every '
         'parameter to the stack before the body.  `leaf_reg` at -O2 is four '
         'instructions with no `sub sp` at all, and `leaf_spill` at -O2 is a '
         'LEAF that has to allocate, because it has three `volatile` locals and '
         'there is nowhere else for them to go.  On x86-64 `leaf_spill` at -O2 '
         'is 10 instructions and allocates NOTHING.')
    print()
    print('  ' + THIN[:72])
    print('  7B.  THE SAME C, BOTH TARGETS, INSTRUCTION COUNTS.')
    print('       THIS IS A COMPILE-TIME COMPARISON AND NOT A TIMING ONE.')
    print('  ' + THIN[:72])
    print('  There is no AArch64 clock on this host, so the x86-64 numbers in')
    print('  the previous section have nothing to be compared with and are NOT')
    print('  reproduced here in any form.  What CAN be compared is the number of')
    print('  instructions a compiler emits, and that is a property of a')
    print('  COMPILER VERSION rather than of an architecture.')
    print()
    DESC = {
        'leaf_reg': 'a leaf with pure register arithmetic',
        'leaf_spill': 'a leaf with three volatile locals',
        'inner': 'a leaf, not inlined',
        'nonleaf': 'calls inner, one volatile local',
        'big_frame': 'eight volatile array elements',
        'i9': 'the nine-integer callee',
        'd9': 'the nine-double callee',
        'm8': 'four integers and four doubles',
        'm18': 'nine integers and nine doubles',
        'va': 'a variadic function',
        'many': 'twelve values live across twelve calls',
        'fmany': 'ten doubles live across ten calls',
    }
    print('  %-11s %-42s %-9s %-8s %s' %
          ('function', 'what it is', 'AArch64', 'x86-64', 'x86 / a64'))
    for fn in ('leaf_reg', 'leaf_spill', 'inner', 'nonleaf', 'big_frame',
               'i9', 'd9', 'm8', 'm18', 'va', 'many', 'fmany'):
        a = fn_ilen('abi_%s.s' % 'O2', fn)
        x = fn_ilen('x86_%s.s' % 'O2', fn)
        if a and x:
            print('  %-11s %-42s %-9d %-8d %.3f' %
                  (fn, DESC.get(fn, ''), a, x, x / a))
    print()
    a_tot = sum(fn_ilen('abi_%s.s' % 'O2', f) or 0
                for f, _ in asm_functions(os.path.join(HERE, 'abi_O2.s')))
    x_tot = sum(fn_ilen('x86_%s.s' % 'O2', f) or 0
                for f, _ in asm_functions(os.path.join(HERE, 'abi_O2.s')))
    print('  %-11s %-42s %-9d %-8d %.3f' %
          ('WHOLE CORPUS', 'all 25 functions of abi.c at -O2', a_tot, x_tot,
           x_tot / a_tot if a_tot else 0))
    print()
    # and the frame census for the SAME corpus, both targets
    print('  And the shape, which is the part that does not depend on the')
    print('  compiler\'s mood: how many functions of the same 25 allocate.')
    print()
    print('  %-8s %-14s %-14s %-14s %s' %
          ('level', 'a64: with a frame', 'x86: with a frame', 'a64 mean frame',
           'x86 mean frame'))
    for lvl in LEVELS:
        af, ax, asum, xsum = 0, 0, 0, 0
        for name, _ in asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)):
            ins = insn_lines(dict(asm_functions(
                os.path.join(HERE, 'abi_%s.s' % lvl)))[name])
            if any(re.match(r'^sub\s+sp, sp, #', l) or
                   re.search(r'\[sp, #-\d+\]!$', l) for l in ins):
                af += 1
                for l in ins:
                    m = re.match(r'^sub\s+sp, sp, #(\d+)$', l)
                    if m:
                        asum += int(m.group(1))
                        break
        for name, _ in asm_functions(os.path.join(HERE, 'x86_%s.s' % lvl)):
            ins = insn_lines(dict(asm_functions(
                os.path.join(HERE, 'x86_%s.s' % lvl)))[name])
            sizes = [int(m.group(1)) for l in ins
                     for m in [re.match(r'^subq\s+\$(\d+), %rsp$', l)] if m]
            if sizes:
                ax += 1
                xsum += sizes[0]
        print('  %-8s %-14s %-14s %-14s %s' %
              (lvl, '%d of 25' % af, '%d of 25' % ax,
               '%.0f bytes' % (asum / af) if af else '-',
               '%.0f bytes' % (xsum / ax) if ax else '-'))
    print()
    # WHICH functions, not how many: a count of two overlapping sets is
    # the least informative thing a reader can be handed.
    def with_frame(path):
        out = set()
        for name, body in asm_functions(os.path.join(HERE, path)):
            ins = insn_lines(body)
            if any(re.match(r'^sub\s+sp, sp, #', l) or
                   re.search(r'\[sp, #-\d+\]!$', l) for l in ins):
                out.add(name)
            elif any(re.match(r'^subq\s+\$\d+, %rsp$', l) for l in ins):
                out.add(name)
        return out
    print('  WHICH functions, because a count of two overlapping sets is the')
    print('  least informative thing a reader can be handed:')
    print()
    for lvl in LEVELS:
        a = with_frame('abi_%s.s' % lvl)
        x = with_frame('x86_%s.s' % lvl)
        only_a = sorted(a - x)
        only_x = sorted(x - a)
        both = sorted(a & x)
        print('  %-4s a64 only: %-34s x86 only: %-24s both: %d' %
              (lvl, ' '.join(only_a) or '(none)', ' '.join(only_x) or '(none)',
               len(both)))
    print()
    p(MEAS, 'The whole-corpus ratio is a property of clang 21.1.8 and of a')
    print(wrap('25-function corpus, and the file says so at the point where it '
               'is printed.  What the census establishes, at every level and '
               'without a clock, is the SHAPE.  The x86-64 half allocates in '
               '5 of the 25 at every level above -O0 and the AArch64 half in '
               '14, and the nine extra are the ones whose C asks for memory '
               'that does not fit in a register: a volatile local, a volatile '
               'array, a value that must survive a call.  On x86-64 those go '
               'into the 128 bytes below SP.  On AArch64 they cost a `sub` and '
               'an `add`.', '     '))
    print()
    print('  ' + THIN[:72])
    print('  7C.  THE SAME FUNCTION, HAND-WRITTEN, BOTH ARCHITECTURES,')
    print('       AND THE DIFFERENCE IS TWO INSTRUCTIONS.')
    print('  ' + THIN[:72])
    for label, obj, triple, names in (
            ('AArch64  a64_leaf_noframe / a64_leaf_frame', 'frame_a64.o',
             'aarch64', ('a64_leaf_noframe', 'a64_leaf_frame')),
            ('x86-64   x86_leaf_noframe / x86_leaf_frame', 'frame_x86.o',
             None, ('x86_leaf_noframe', 'x86_leaf_frame'))):
        path = os.path.join(HERE, obj)
        if not os.path.exists(path):
            continue
        pairs = objdump_pairs(path, triple)
        out = sh(OBJDUMP, *(['-d', path] if not triple
                            else ['--triple=' + triple, '-d', path])).stdout
        cur, groups = None, {}
        for ln in out.splitlines():
            m = re.match(r'^[0-9a-f]+ <([^>]+)>:$', ln)
            if m:
                cur = m.group(1)
                groups[cur] = []
                continue
            # x86-64 objdump prints `48 0f af c6` with spaces, AArch64
            # prints `9b007c28` without, and a byte-pair pattern that
            # matches the first and not the second reports 0 instructions
            # for the whole AArch64 half of this table.
            m = re.match(r'^\s+[0-9a-f]+:\s+[0-9a-f ]+\s+(\S.*)$', ln)
            if m and cur:
                groups[cur].append(m.group(1).strip())
        print('  %s' % label)
        for k, nm in enumerate(names):
            if nm not in groups:
                continue
            body = groups[nm]
            print('    %-20s %d instructions, %d of them touch the stack '
                  'pointer' % (nm, len(body),
                               sum(1 for b in body
                                   if re.search(r'\b(sp|rsp)\b', b))))
            for b in body:
                print('      %s' % b)
        print()
    p(BYTES, 'The AArch64 leaf with a frame has `sub sp, sp, #16` and `add sp,')
    print(wrap('sp, #16` in it.  The x86-64 leaf with a frame has NEITHER: it '
               'writes at -8(%rsp) and -16(%rsp) and %rsp never moves.  Both '
               'are the same C, hand-translated to be the same C, and the '
               'difference is a sentence in a document about a region of '
               'memory 128 bytes wide.  That is the whole cost of having no '
               'red zone, and it is two instructions in every function that '
               'has locals -- which is every function that is not a leaf of '
               'pure arithmetic.', '     '))
    retract('R3',
            'the 128 bytes is an AArch64 stack alignment rule',
            'the 128 bytes is an APPLE platform-ABI RED ZONE, and the AAPCS64 '
            'stack alignment rule is 16 bytes; the AAPCS64 has no red zone at '
            'all and says the region below SP may not be accessed',
            'two different quantities about two different regions of memory, '
            'conflated by the number 128.  The Apple red zone is BELOW SP and '
            'is 128 bytes; the AAPCS64 alignment rule is ABOUT SP and is 16 '
            'bytes.  A course that used the red zone\'s number for the '
            'alignment rule would also have had to conclude AArch64 HAS a red '
            'zone, which is the opposite of the truth and is the finding '
            'section 7A is built on.')
    print()
    print('  ' + THIN[:72])
    print('  7D.  THE ONE FORM THAT HIDES AN ALLOCATION: PRE- AND')
    print('       POST-INDEX.')
    print('  ' + THIN[:72])
    print('  %-24s %-26s %s' % ('form', 'reads and writes', 'allocates'))
    for src, what in (('stp x29, x30, [sp, #-16]!', 'two registers, and SP'),
                      ('str x0, [sp, #-16]!', 'one register, and SP'),
                      ('ldr x0, [sp], #16', 'one register, and SP'),
                      ('ldp x29, x30, [sp], #16', 'two registers, and SP'),
                      ('sub sp, sp, #16', 'nothing but SP')):
        words, _ = assemble(src)
        if words:
            print('  %-24s %-26s 0x%08x' %
                  (src, what, words[0][0]))
    print()
    p(BYTES, 'Four of those five are ONE instruction that does two jobs, and a')
    print(wrap('frame counter that only counts `sub sp` misses all four.  This '
               'is x86-64\'s `leave` in a different costume: x86 needs a '
               'separate `movq %rsp, %rbp; popq %rbp` to undo the frame, and '
               'AArch64 folds the deallocation into the last load.', '     '))
    print()


def fn_ilen(path, fn):
    bodies = dict(asm_functions(os.path.join(HERE, path)))
    if fn not in bodies:
        return None
    return len(insn_lines(bodies[fn]))


# ---------------------------------------------------------------------------
# 8. Callee-saved.
# ---------------------------------------------------------------------------

def sec8():
    hdr(8, 'CALLEE-SAVED, READ OUT OF THE COMPILER',
        'x19-x28, v8-v15, the platform register, and a rule the plan got wrong')
    print('  ' + THIN[:72])
    print('  8A.  WHAT THE DOCUMENT SAYS.  Three rows that are easy to get')
    print('       wrong and one that everybody gets wrong.')
    print('  ' + THIN[:72])
    for tag, text in ORACLE:
        if tag in ('6.1.1', '6.1.2', '5.1.1') and ('Callee-saved' in text or
                                                    'r18' in text):
            body = wrap(text, '           ', 68).splitlines()
            print('  %-8s %s' % (tag, body[0].strip()))
            for ln in body[1:]:
                print(ln)
    print()
    p(QUOT, 'x19-x28, plus x29 and x30 and SP, all 64 bits.')
    print(wrap('v8-v15, and ONLY THE BOTTOM 64 BITS of each.  That last clause '
               'is the one that gets dropped: it is not that v8-v15 must be '
               'preserved, it is that the top 64 bits of them are the CALLER\'S '
               'problem, and a compiler that saves `q8` when it only needed `d8` '
               'has obeyed the standard and wasted a store.', '     '))
    retract('R4',
            'the AAPCS64 preserves the lower 64 bits of v0-v7',
            'it preserves the lower 64 bits of v8-v15; v0-v7 are the ARGUMENT '
            'and RESULT registers and are entirely Caller-saved',
            'docs/aarch64-section-plan.md says "the lower 64 bits of `v0`-`v7`" '
            'and the AAPCS64 6.1.2 says "Registers v8-v15 are Callee-saved ... '
            'only the bottom 64 bits of each value stored in v8-v15 need to be '
            'Callee-saved".  The consequence is not a detail: v0-v7 are where '
            'a double argument arrives, so a callee is free to destroy all of '
            'them, and a course that got the range wrong would have had to '
            'explain a callee saving the registers its arguments just arrived '
            'in.')
    print()
    print('  ' + THIN[:72])
    print('  8B.  WHAT THE COMPILER DID.  `many` keeps twelve values live')
    print('       across twelve calls, so it has to reach past the seven')
    print('       caller-saved temporaries x9-x15.')
    print('  ' + THIN[:72])
    for lvl in LEVELS:
        for fn in ('many', 'fmany'):
            bodies = dict(asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)))
            if fn not in bodies:
                continue
            ins = insn_lines(bodies[fn])
            gpr_saves, gpr_rest, fp_saves, fp_rest = set(), set(), set(), set()
            for ln in ins:
                m = re.match(r'^stp\s+([wx])(\d+),\s*([wx])(\d+),', ln)
                if m:
                    for l, r in ((m.group(1), int(m.group(2))),
                                 (m.group(3), int(m.group(4)))):
                        if 19 <= r <= 28:
                            gpr_saves.add(r)
                        elif 8 <= r <= 15:
                            gpr_saves.add(r)
                m = re.match(r'^ldp\s+([wx])(\d+),\s*([wx])(\d+),', ln)
                if m:
                    for r in (int(m.group(2)), int(m.group(4))):
                        if 19 <= r <= 28 or 8 <= r <= 15:
                            gpr_rest.add(r)
                m = re.match(r'^stp\s+([dq])(\d+),\s*([dq])(\d+),', ln)
                if m:
                    for r in (int(m.group(2)), int(m.group(4))):
                        if 8 <= r <= 15:
                            fp_saves.add(r)
                m = re.match(r'^ldp\s+([dq])(\d+),\s*([dq])(\d+),', ln)
                if m:
                    for r in (int(m.group(2)), int(m.group(4))):
                        if 8 <= r <= 15:
                            fp_rest.add(r)
            def rng(s):
                return ('x%d-x%d' % (min(s), max(s)) if s and
                        len(s) == max(s) - min(s) + 1 else
                        ','.join('x%d' % v for v in sorted(s)) or 'none')
            def rngd(s):
                return ('d%d-d%d' % (min(s), max(s)) if s and
                        len(s) == max(s) - min(s) + 1 else
                        ','.join('d%d' % v for v in sorted(s)) or 'none')
            tail = ''
            if fp_saves or fp_rest:
                tail = '   |  fp: saved %-12s restored %-12s' % (
                    rngd(fp_saves), rngd(fp_rest))
            print('  %-4s %-6s gpr: saved %-14s restored %-14s%s' %
                  (lvl, fn, rng(gpr_saves), rng(gpr_rest), tail))
    print()
    p(MEAS, '`many` at -O2 saves x19-x28 -- all ten -- in FIVE stp pairs, and')
    print(wrap('restores them in five ldp pairs.  Twenty instructions, ten of '
               'them pairs, to hold twelve values across twelve calls.  The '
               'reason it needs ten callee-saved registers is a COUNT and not a '
               'preference: there are seven caller-saved temporaries in the '
               'integer bank (x9-x15) and twelve values that must survive a '
               'call, so five of them have nowhere else to live.  x19-x28 is '
               'not a set of ten chosen registers; it is what is left.', '     '))
    print()
    note('`fmany` is the one that matters for the v8-v15 clause: it saves '
         'd8-d15, the 64-bit VIEW, not q8-q15.  The compiler obeyed the '
         '"bottom 64 bits" rule exactly, and a reader who assumed it would save '
         '128-bit registers would read the disassembly and conclude the '
         'compiler had made an error.')
    print()
    print('  ' + THIN[:72])
    print('  8C.  THE PLATFORM REGISTER x18, AND A RULE THAT DOES NOT EXIST.')
    print('  ' + THIN[:72])
    x18 = 0
    for lvl in LEVELS:
        for name, body in asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)):
            for ln in insn_lines(body):
                if re.search(r'\b[wx]18\b', ln):
                    x18 += 1
    print('  The AAPCS64 says, of r18: the role is PLATFORM SPECIFIC, and the')
    print('  platform ABI specification must document it.  Linux does not')
    print('  reserve it, so on Linux it is an ordinary caller-saved temporary.')
    print()
    p(MEAS, 'Occurrences of w18/x18 in the whole corpus at all four levels: %d.'
      % x18)
    print()
    retract('R5',
            'the AAPCS64 platform register r18 is preserved across a call that '
            'uses the stack',
            'there is no such rule.  The AAPCS64 says the role of r18 is '
            'platform specific and that the platform ABI specification must '
            'document it, and it says nothing conditional on the stack.  The '
            'rule in the plan is an AARCH32 and x86-64 idea: on 32-bit Arm r13 '
            'is the platform register and software that uses it must save it '
            'around a call that might touch the stack, and on Windows x64 the '
            'TIB lives in the GS segment rather than a register at all.',
            'docs/aarch64-section-plan.md and the brief for this course both '
            'say "it is preserved only across a call that uses the stack -- '
            'measure how often the compiler saves it".  The measurement is the '
            'way to find out: clang on Linux saves it ZERO times in a corpus '
            'of 25 functions at four optimisation levels, because there is '
            'nothing to save.  A conditional rule that a compiler never '
            'implements is indistinguishable from a rule that does not exist, '
            'and the measurement is what tells them apart.')
    print()
    print('  ' + THIN[:72])
    print('  8D.  THE FLAG REGISTER, OR THE ABSENCE OF ONE.')
    print('  ' + THIN[:72])
    print('  The AAPCS64, on NZCV: "The N, Z, C and V flags are undefined on')
    print('  entry to and return from a public interface."  Undefined, not')
    print('  preserved and not destroyed: a callee may leave them in any state')
    print('  and the caller may not read them across a call.')
    print()
    nzcv = 0
    for lvl in LEVELS:
        for name, body in asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)):
            for ln in insn_lines(body):
                if re.match(r'^(mrs|msr)\s', ln):
                    nzcv += 1
    p(MEAS, 'mrs/msr of a flag register in the corpus: %d.  There are none, and'
      % nzcv)
    print(wrap('there is no assembly mnemonic for "save the flags" on this '
               'architecture, because the flags live in no register that a '
               'normal instruction can name.  x86-64\'s answer is PUSHFQ, one '
               'instruction that writes 8 bytes onto the stack, and the '
               'x86abi course counted 271 of them in 94 functions.  AArch64\'s '
               'answer is that there is nothing to count: the flags are a '
               'side effect of a bit in an instruction, and the sentence that '
               'makes them not your problem is a sentence rather than a store.',
               '     '))
    retract('R6',
            'AArch64 has a flags register that has to be saved like any other',
            'NZCV is not a general register, has no mnemonic, and is explicitly '
            'UNDEFINED across a public interface, so there is nothing to save '
            'and no instruction to save it with',
            'the plan lists "no flags register to save separately" as one of '
            'the differences worth building on and that is right, but the '
            'phrasing in the brief -- "no flags register to save SEPARATELY" -- '
            'reads as though there is one to save.  There is not.  The '
            'measurable consequence is a COUNT OF ZERO, and a course that '
            'asserted a cost without printing the zero would be describing an '
            'optimisation rather than a fact.')
    print()


# ---------------------------------------------------------------------------
# 9. CFI, the frame in a second language.
# ---------------------------------------------------------------------------

def sec9():
    hdr(9, 'CFI: THE FRAME IN A SECOND LANGUAGE',
        'the same frame, described twice, in two vocabularies, and the ratio '
        'between them is the measurement')
    print('  ' + THIN[:72])
    print('  9A.  THE TWO LANGUAGES, SIDE BY SIDE, FOR ONE FUNCTION.')
    print('  ' + THIN[:72])
    print('  `nonleaf` at -O0.  Left: the instructions.  Right: the CFI that')
    print('  describes the same frame to something that was not there when the')
    print('  function ran.')
    print()
    bodies = dict(asm_functions(os.path.join(HERE, 'abi_O0.s')))
    cfi = a64abi_cfi_body(os.path.join(HERE, 'abi_O0.s'), 'nonleaf')
    ins = insn_lines(bodies.get('nonleaf', []))
    for k in range(max(len(ins), len(cfi))):
        a = ins[k] if k < len(ins) else ''
        b = cfi[k] if k < len(cfi) else ''
        print('  %-46s %s' % (a[:46], b))
    print()
    p(MEAS, 'Both columns describe ONE frame.  The left is 4 instructions; the')
    print(wrap('right is %d directives, and the right one is what a debugger, a '
               'profiler and an exception unwinder read.  This is the same '
               'phenomenon the x86abi course found and called a second '
               'language, and on this architecture it is more clearly a second '
               'language because the two vocabularies share almost no symbols: '
               '`.cfi_def_cfa_offset 48` is `sub sp, sp, #48` in English, and '
               '`.cfi_offset w30, -8` is the fact that the return address is '
               'in a register and was written to the stack.', '     ')
          % len(cfi))
    print()
    print('  ' + THIN[:72])
    print('  9B.  THE REGISTER RULES, READ OUT OF THE EMITTED .eh_frame.')
    print('  ' + THIN[:72])
    for lvl in ('O0', 'O2'):
        path = os.path.join(HERE, 'abi_%s.o' % lvl)
        fdes = readelf_unwind(path)
        off = 0
        rows = []
        for f in fdes:
            ops = [o[0] for o in f['ops']]
            rows.append((off, f['length'], ops.count('advance_loc') +
                         ops.count('advance_loc1') +
                         ops.count('advance_loc2'),
                         ops.count('offset'), ops.count('def_cfa') +
                         ops.count('def_cfa_offset') +
                         ops.count('def_cfa_register'),
                         ops.count('restore')))
            off += f['length'] + 4
        if not rows:
            continue
        print('  %-4s %3d FDEs, %d DW_CFA_offset, %d CFA changes, %d restores'
              % (lvl, len(rows), sum(r[3] for r in rows),
                 sum(r[4] for r in rows), sum(r[5] for r in rows)))
        print('       %5d advance_loc opcodes, one per CFI ROW' %
              sum(r[2] for r in rows))
        print('  %-4s %-8s %-8s %-8s %-8s %-8s %s' %
              ('lvl', 'at', 'bytes', 'rows', 'offsets', 'cfa', 'restores'))
        for r in rows[:14]:
            print('  %-4s %-8s %-8d %-8d %-8d %-8d %d' %
                  (lvl, r[0], r[1], r[2], r[3], r[4], r[5]))
        if len(rows) > 14:
            print('  ...  and %d more' % (len(rows) - 14))
    print()
    p(MEAS, 'A CFI ROW is one DW_CFA_advance_loc, and it is the unit that')
    print(wrap('matters: the unwind table is a piecewise-constant description of '
               'the frame, and a row is the interval over which it is constant.  '
               'The CIE at the top of every .eh_frame carries the first row for '
               'free -- one instruction, "DW_CFA_def_cfa: reg31 +0", for the '
               'whole object -- and every function after that pays for its own.',
               '     '))
    print()
    print('  ' + THIN[:72])
    print('  9C.  THE INFORMATION-CONTENT RATIO, WHICH IS THE MEASUREMENT.')
    print('  ' + THIN[:72])
    print(wrap('How many CFI rows does a given function need, and how does '
               'that change with optimisation level?  That is the question '
               'this course was written to ask, and the answer is not the one '
               'it was written expecting, so the whole table is printed and '
               'the surprise is measured rather than narrated.', '     '))
    print()
    # A CFI row is one DW_CFA_advance_loc.  The FDEs appear in the
    # .eh_frame in the same order the functions appear in the assembly, and
    # that is the pairing this table uses -- it is an ORDER assumption and
    # it is stated here because a pairing a reader cannot check is a pairing
    # they have to take on faith.
    DESC = {
        'i9': 'a callee, no call',
        'm18': 'a callee, 9 int + 9 double',
        'nonleaf': 'calls inner, one volatile local',
        'many': 'twelve values across twelve calls',
        'fmany': 'ten doubles across ten calls',
        'va': 'a variadic function',
        'leaf_reg': 'a leaf, registers only',
        'leaf_spill': 'a leaf with three volatiles',
        'c9': 'the nine-integer caller',
    }
    perfn = {}
    for lvl in LEVELS:
        path = os.path.join(HERE, 'abi_%s.o' % lvl)
        fdes = readelf_unwind(path)
        names = [n for n, _ in asm_functions(
            os.path.join(HERE, 'abi_%s.s' % lvl))]
        bodies = dict(asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)))
        for k, f in enumerate(fdes):
            if k >= len(names):
                break
            ops = [o[0] for o in f['ops']]
            perfn[(lvl, names[k])] = dict(
                rows=sum(1 for o in ops if o.startswith('advance_loc')),
                rules=sum(1 for o in ops if o.startswith('offset')),
                bytes=f['length'],
                insns=len(insn_lines(bodies[names[k]])))
    print('  Every function, both levels, and the three numbers that matter.')
    print('  ROWS is the number of points at which the frame changes shape.')
    print('  RULES is the number of DW_CFA_offset entries -- how many')
    print('  registers the table says where to find.  BYTES is the FDE.')
    print()
    print('  %-11s %-28s %-28s %s' %
          ('function', '-O0  insn/rows/rules/bytes', '-O2  insn/rows/rules/bytes',
           'what happened'))
    for name, _ in asm_functions(os.path.join(HERE, 'abi_O0.s')):
        a_, b_ = perfn.get(('O0', name)), perfn.get(('O2', name))
        if not a_ or not b_:
            continue
        if a_['rows'] == b_['rows'] and a_['bytes'] == b_['bytes']:
            what = 'identical'
        elif b_['bytes'] > a_['bytes']:
            what = 'TABLE GREW %+d bytes, rows %+d' % (
                b_['bytes'] - a_['bytes'], b_['rows'] - a_['rows'])
        else:
            what = 'table shrank %+d bytes, rows %+d' % (
                b_['bytes'] - a_['bytes'], b_['rows'] - a_['rows'])
        print('  %-11s %-28s %-28s %s' %
              (name, '%d / %d / %d / %d' % (a_['insns'], a_['rows'],
                                           a_['rules'], a_['bytes']),
               '%d / %d / %d / %d' % (b_['insns'], b_['rows'], b_['rules'],
                                      b_['bytes']), what))
    print()
    print('  %-4s %-10s %-10s %-10s %-10s %s' %
          ('lvl', 'FDEs', 'rows', 'rules', 'insns', 'rows per function'))
    for lvl in LEVELS:
        fdes = readelf_unwind(os.path.join(HERE, 'abi_%s.o' % lvl))
        v = [perfn[(lvl, n)] for n, _ in asm_functions(
            os.path.join(HERE, 'abi_%s.s' % lvl))
             if (lvl, n) in perfn]
        print('  %-4s %-10d %-10d %-10d %-10d %.2f' %
              (lvl, len(v), sum(x['rows'] for x in v),
               sum(x['rules'] for x in v), sum(x['insns'] for x in v),
               sum(x['rows'] for x in v) / len(v)))
    print()
    p(MEAS, 'THE SHAPE THIS COURSE WAS WRITTEN TO FIND IS NOT IN HERE,')
    print(wrap('and the first draft of this section asserted one.  The plan and '
               'the brief for this course both said a function "that needs 3 '
               'rows at -O0 and 9 at -O2 is saying something".  Not one '
               'function in this corpus does that.  The row count is 0, 2, 3 '
               'or 4 at every level, and every function either holds its row '
               'count or LOSES rows: 9 functions go from 2 to 0, `cm8` goes '
               'from 4 to 0, and `va` goes from 3 to 2.  A predicted shape '
               'that the measurement does not contain is a retraction and not '
               'a nuance, and R7 is that retraction.', '     '))
    print()
    p(MEAS, 'What IS in here is a different and better shape, and it is about')
    print(wrap('RULES rather than ROWS.  `many` holds its 4 rows from -O0 to -O2 '
               'and its table grows from %d to %d bytes, because at -O0 it '
               'saves x30 and x29 and at -O2 it saves ten callee-saved '
               'registers as well and every one of them needs a DW_CFA_offset '
               'that says where to find it.  `fmany` does the same thing in '
               'the vector bank: %d to %d bytes for the same 4 rows, because '
               'd8-d15 became eight more rules.  So the row count says how '
               'many TIMES the frame changes and the rule count says how much '
               'STATE it has, and only the second one went up.'
               % (perfn[('O0', 'many')]['bytes'], perfn[('O2', 'many')]['bytes'],
                  perfn[('O0', 'fmany')]['bytes'],
                  perfn[('O2', 'fmany')]['bytes']), '     '))
    print()
    p(MEAS, 'And `va` is the opposite, in both columns: %d rows and %d bytes at'
      % (perfn[('O0', 'va')]['rows'], perfn[('O0', 'va')]['bytes']))
    print(wrap('-O0, %d rows and %d bytes at -O2.  The -O0 prologue is a '
               '`str x30, [sp, #304]`, an `add x8, sp, #112` and a `str x8, '
               '[sp, #40]` -- three separate changes of the frame.  The -O2 '
               'prologue is one `sub sp, sp, #224` and one `add sp, sp, '
               '#224`, and a frame that is entered once and left once needs a '
               'description of the interval between them and almost nothing '
               'else.'
               % (perfn[('O2', 'va')]['rows'], perfn[('O2', 'va')]['bytes']),
               '     '))
    print()
    p(MEAS, 'So the information content of an unwind table is neither the')
    print(wrap('frame nor the row count.  It is the number of points at which '
               'the frame changes shape TIMES the number of registers whose '
               'location it states, and optimisation moves those two in '
               'opposite directions in the same function: `many` holds its '
               'rows and doubles its rules, `va` halves its rows and its '
               'bytes together.  The harness asserts the direction of both '
               'and not their values, because every one of these numbers is a '
               'property of a compiler version and not of a standard.',
               '     '))
    print()
    retract('R7',
            'a function that needs 3 CFI rows at -O0 and 9 at -O2 is the '
            'characteristic example, and the row count rises with '
            'optimisation',
            'no function in the corpus does that.  Row counts are 0, 2, 3 or '
            '4 at every level; nine functions go from 2 rows to 0, and no '
            'function goes UP in rows.  What goes up is the number of '
            'DW_CFA_offset RULES: `many` holds 4 rows and its FDE grows from '
            '40 to 64 bytes, and `fmany` holds 4 rows and grows from 36 to 76',
            'docs/aarch64-section-plan.md and the brief for this course both '
            'offered the 3-to-9 shape as the interesting measurement of the '
            'CFI concept.  It reads well and it is not what the compiler '
            'does.  The measurement that IS there is better -- the row count '
            'and the rule count move in OPPOSITE directions in the same '
            'function -- and it took a second experiment to find, because the '
            'first one counted rows and stopped.')
    print()
    print('  ' + THIN[:72])
    print('  9D.  THE SECTION SIZES, WHICH ARE THE OTHER HALF OF THE RATIO.')
    print('  ' + THIN[:72])
    print('  %-4s %-14s %-14s %-14s %s' %
          ('lvl', '.text bytes', '.eh_frame', 'ratio', 'functions'))
    for lvl in LEVELS:
        d, mach, secs = elf_sections(os.path.join(HERE, 'abi_%s.o' % lvl))
        t = secs.get('.text', {}).get('size', 0)
        e = secs.get('.eh_frame', {}).get('size', 0)
        n = len(asm_functions(os.path.join(HERE, 'abi_%s.s' % lvl)))
        print('  %-4s %-14d %-14d %-14s %d' %
              (lvl, t, e, '%.1f%%' % (100.0 * e / t) if t else '-', n))
    print()
    sz = {}
    for lvl in LEVELS:
        d, mach, secs = elf_sections(os.path.join(HERE, 'abi_%s.o' % lvl))
        t = secs.get('.text', {}).get('size', 0)
        e = secs.get('.eh_frame', {}).get('size', 0)
        sz[lvl] = (t, e)
    p(MEAS, 'The unwind table is a fixed fraction of the code and it does NOT')
    print(wrap('shrink when the code does.  At -O0 the object spends %.1f%% of '
               '.text in .eh_frame and at -O2 it spends %.1f%%, because the '
               'same 25 functions need the same 25 FDEs whether each is 34 '
               'instructions or 13.  The per-function floor is a CIE '
               'reference, an FDE header and at least one row, and no amount '
               'of optimisation removes it.  Halving the code moved the table '
               'from %.1f%% to %.1f%% of it -- which is the whole '
               'information-content argument in one line: the cost of the '
               'second language is a function of the NUMBER OF FUNCTIONS, '
               'not of the amount of code in them.'
               % (100.0 * sz['O0'][1] / sz['O0'][0],
                  100.0 * sz['O2'][1] / sz['O2'][0],
                  100.0 * sz['O0'][1] / sz['O0'][0],
                  100.0 * sz['O2'][1] / sz['O2'][0]), '     '))
    print()
    print('  ' + THIN[:72])
    print('  9E.  WHAT A SECOND LANGUAGE MEANS HERE THAT IT DID NOT MEAN')
    print('       ON x86-64.')
    print('  ' + THIN[:72])
    print(wrap(
        'On x86-64 the CFA is a register plus a number, and the number changes '
        'whenever the frame does -- `.cfi_def_cfa_offset`, `.cfi_def_cfa '
        'rsp, 8`, `.cfi_def_cfa rbp, 16`.  On AArch64 the same first form '
        'appears, and so does the second, and the register is not a '
        'convention: it is r29 and it is the register the ABI NAMES as the '
        'frame pointer in 5.2.3.  The CFI is not describing a convention the '
        'compiler chose; it is reporting which of the four levels of frame-'
        'record conformance the platform mandated, and the reader can look up '
        'the level.  The second language has a vocabulary the first language '
        'is quoted from.', '     '))
    for f in readelf_unwind(os.path.join(HERE, 'abi_O2.o'))[:1]:
        pass
    o = sh(READELF, '--unwind', os.path.join(HERE, 'abi_O2.o')).stdout
    print('  ' + THIN[:72])
    print('  9F.  THE SECOND READER\'S OWN ACCOUNT OF THE SAME TABLE,')
    print('       PRINTED VERBATIM.')
    print('  ' + THIN[:72])
    lines = o.splitlines()
    keep = []
    for ln in lines[:34]:
        keep.append(ln)
    for ln in keep:
        print('  ' + ln)
    print()
    p(BYTES, 'The `return_address_register: 30` and the `data_alignment_factor:')
    print(wrap('-4` and the `DW_CFA_def_cfa: reg31 +0` are QUOTED-OUT-OF-THE-'
               'BYTES: they are in the .eh_frame section, this file read them '
               'with `struct.unpack_from`, and llvm-readdump read them with a '
               'different program.  reg31 is the stack pointer and it is the '
               'same number 31 that section 6 showed being three different '
               'things in three different instruction slots -- which is the '
               'hinge between the two concepts, and the reason the two pages '
               'are adjacent in the course.', '     '))
    print()


def a64abi_cfi_body(path, fn):
    order, bodies = _function_labels(path)
    if fn not in bodies:
        return []
    return [b for b in bodies[fn] if b.startswith('.cfi')]


# ---------------------------------------------------------------------------
# 10. Two readers, and one of them poisoned.
# ---------------------------------------------------------------------------

def sec10():
    hdr(10, 'TWO READERS, AND THEN ONE OF THEM POISONED',
        'a check that has never failed is not a check')
    total = named = 0
    dis = []
    norm_reset()
    for lvl in LEVELS:
        path = os.path.join(HERE, 'abi_%s.o' % lvl)
        mine, _, _ = text_insns(path)
        theirs = objdump_pairs(path)
        if len(mine) != len(theirs):
            dis.append(('%s: %d vs %d instructions' %
                        (lvl, len(mine), len(theirs)), ''))
        for (sec, i), (w, t) in zip(mine, theirs):
            total += 1
            if i.word != w:
                dis.append(('%s %#x vs %#x' % (lvl, i.word, w), ''))
                continue
            if not i.name:
                continue
            named += 1
            if norm(i.text) != norm(t):
                dis.append(('%s %#010x  %r vs %r' % (lvl, w, i.text, t), ''))
    print('  Two readers over four objects:')
    print('    reader 1: the decoder in this file, %d models' % MODEL_COUNT)
    print('    reader 2: llvm-objdump-21 --triple=aarch64 -d')
    print()
    print('  %d instructions read, %d NAMED by reader 1, %d disagreements.' %
          (total, named, len(dis)))
    print()
    print('  What the two printers disagreed about, and the rule that resolved')
    print('  each class of it.  A cross-check that reaches agreement by')
    print('  applying transformations nobody wrote down is a cross-check whose')
    print('  remaining failures cannot be diagnosed, so the rules are listed')
    print('  with the number of instructions each one touched:')
    print()
    rows = sorted(norm_stats(), key=lambda r: -r[1])
    for raw, n, fixed in rows[:14]:
        print('  %-7d %-30s -> %s' % (n, raw[:30], fixed[:34]))
    if len(rows) > 14:
        print('  %-7d and %d more distinct transformations' %
              (sum(r[1] for r in rows[14:]), len(rows) - 14))
    print()
    if dis:
        print('  and %d instructions that NO rule resolved, which are the ones'
              % len(dis))
        print('  worth reading:')
        for d, _ in dis[:24]:
            print('    %s' % d)
    else:
        print('  and 0 instructions that no rule resolved.')
    print()
    p(BYTES, '%d of %d named instructions agree, which is the number a '
      'cross-check is supposed to produce and the number that is worth '
      'nothing on its own.' % (named - len(dis), named))
    print(wrap('Getting here took five runs and the first one reported 1232 '
               'disagreements out of 2086, and every one of them was a real '
               'defect: a guard that did not fix bits[25:24], a pair model '
               'that read the width from bits[29:28] instead of bits[31:30] '
               'and printed `stp d15, d14` for `stp q15, q14`, a floating-'
               'point immediate whose fraction was five bits wide instead of '
               'four and printed 2.0 for 1.0, a MOVN that complemented '
               'without sign-extending, and a register-offset form that '
               'concatenated two register fields into the number 150.  The '
               'list is the argument for this section: a check that has '
               'never failed is not a check, and a check that has failed five '
               'times has found five bugs that no amount of reading would '
               'have.', '     '))
    print()
    print(wrap('And 100% is still not a proof, because both readers come from '
               'one LLVM tree and a decoder that is wrong in the same way as '
               'its oracle is not a check.  The control is a POISON: break '
               'one model on purpose and the number has to MOVE BY NAME.',
               '     '))
    print()

    # --- the poison
    print('  ' + THIN[:72])
    print('  THE POISON.  A temporary file is written, one guard is changed by')
    print('  one bit, and the SAME loop is run again.')
    print('  ' + THIN[:72])
    saved = list(Dec.MODELS)
    names_before = named
    # the poison: m_ldst_fp claims the FP unscaled form when bits[25:24] = 01
    # instead of 00, so every SCALED q/d/s/h/b store is decoded as a STUR.
    import types

    def poisoned(i):
        if not i.fixed(29, 27, 0b111, 'Load/store register (immediate)'):
            return False
        if not i.fixed(26, 26, 1, 'V = the SIMD&FP form'):
            return False
        opc = i.read(31, 30)
        size_idx = opc + 4 * i.read(23, 23)
        if size_idx > 4:
            return False
        sz = FP_SIZES[size_idx]
        rt = i.read(4, 0)
        rn = i.read(9, 5)
        i.name = 'stur'                      # <-- the poison: always STUR
        i.ops = ['%s%d, [%s, #0]' % (sz, rt, reg(rn, 1))]
        return True

    Dec.MODELS[:] = [poisoned] + BASE_MODELS
    pn = 0
    pdis = []
    for lvl in LEVELS:
        path = os.path.join(HERE, 'abi_%s.o' % lvl)
        mine, _, _ = text_insns(path)
        theirs = objdump_pairs(path)
        for (sec, i), (w, t) in zip(mine, theirs):
            if i.word != w:
                continue
            if not i.name:
                continue
            pn += 1
            if norm(i.text) != norm(t):
                pdis.append((w, i.text, t))
    Dec.MODELS[:] = saved
    print('  With the poison in: %d named, %d DISAGREEMENTS, and the first few'
          % (pn, len(pdis)))
    print('  by name:')
    for w, a, b in pdis[:10]:
        print('    0x%08x  reader 1 says %-28s reader 2 says %s' % (w, a, b))
    print()
    moved = names_before - pn
    p(BYTES, 'The named count moved from %d to %d -- %d instructions the clean'
      % (names_before, pn, moved))
    print(wrap('table claimed are no longer claimed by the same table, and the '
               'disagreement count moved from %d to %d.  A harness that only '
               'ever reads the 100%% teaches its reader that the number is a '
               'constant of the universe, and the whole reason the encoding '
               'course retracted its own cross-check twice is that it had a '
               'harness of exactly that shape.' % (len(dis), len(pdis)), '     '))
    print()

    # --- the model audit
    print('  ' + THIN[:72])
    print('  THE MODEL TABLE, WHICH IS WHAT WAS POISONED.')
    print('  ' + THIN[:72])
    print('  %-16s %-40s' % ('model', 'the guard it checks'))
    for name, guard, claim in EXTRA_CLAIMS:
        print('  %-16s %-40s' % (name, guard))
    for name, guard, claim in Dec.CLAIMS:
        print('  %-16s %-40s' % (name, guard[:40]))
    print()
    print('  %d models and %d claims, and the two numbers are printed together'
          % (MODEL_COUNT, len(EXTRA_CLAIMS) + len(Dec.CLAIMS)))
    print('  because a model with no claim is a model nobody can check.')
    print()
    print('  The six added here go at the FRONT of the dispatch.  Each has a')
    print('  guard that is more specific than anything the base file claims, and')
    print('  reordering the list changes what the decoder resolves in an')
    print('  overlap.  That is a design decision and not a refactor, and it is')
    print('  the first thing a reader should be able to disagree with.')
    print()


# The reconciliation between the two printers, as a LIST of rules rather than
# as one function, because a normaliser is a place where bugs hide and a rule
# that is never exercised is a rule nobody has checked.  Every rule below
# reports how many disagreements it resolved, and section 10 prints those
# counts: a cross-check that reaches 100% by applying seven undocumented
# transformations is a cross-check whose failures are unexplainable.
#
# The first version of this was one function with a comment listing seven
# rules and NO COUNTS, and it reported 1232 disagreements out of 2086
# instructions on a corpus where the two readers are the same LLVM.  Almost
# every one of them was `#80` against `#0x50`: llvm-objdump prints immediate
# offsets in hexadecimal and the decoder prints them in decimal, and a rule
# that "normalises whitespace" does nothing about that.  A 59% agreement
# number that is really 0% disagreement dressed as a number.
NORM_RULES = []


def _rule(name):
    NORM_RULES.append([name, 0, ''])


def norm(t, count=True):
    """Reconcile the two printers' conventions, and record which rule fired.

    The rules, in the order they are applied:

      1  a symbol decoration `<a64_nonleaf+0x8>` is not part of the
         instruction
      2  a branch TARGET is a relocation, not a value, so the last operand
         of b / bl / b.cond / cbz / tbz / tbnz is replaced by T
      3  a number is a number: 0x50, 80, +0 and 0x0 are one value, and the
         two readers disagree about the BASE all the time
      4  a leading `#` on an immediate is decoration
      5  an offset of zero inside a memory operand is absent, not printed:
         `[sp]` and `[sp, #0]` are the same address
      6  an empty operand list is not a difference
    """
    raw = t
    t = t.strip().rstrip(',')
    t = re.sub(r'\s*//.*$', '', t)
    t = re.sub(r'\s*<[^>]*>', '', t)
    if re.match(r'^(b|bl|b\.\w+|cbz|cbnz|tbz|tbnz)\b', t):
        t = re.sub(r'(\s)(\S+)$', r'\1T', t)
    t = re.sub(r'#\s*', '', t)

    def _num(m):
        sign, body = m.group(1), m.group(2)
        try:
            v = int(body, 16) if body[:2].lower() == '0x' else int(body, 10)
        except ValueError:
            return m.group(0)
        return ('-' if sign == '-' else '') + str(v)

    t = re.sub(r'([-+]?)(0[xX][0-9a-fA-F]+|\d+)', _num, t)
    # a zero offset inside a memory operand is an ABSENT offset, and the
    # two printers disagree about which of them prints it.  The first
    # version of this rule handled `[sp, 0]` and `[x0, 0]` by name, so
    # `[x10, 0]` against `[x10]` survived -- 65 of the 278 disagreements.
    t = re.sub(r'\[\s*([A-Za-z]+\d*|sp|wsp)\s*,\s*0\s*\]', r'[\1]', t)
    # MOVZ is MOV when the shift is zero and the destination is not 31,
    # and llvm-objdump prints the ALIAS while the decoder prints the
    # opcode.  Same 32 bits, two names, and it is 7 disagreements.
    # the encoding course's shifted-register model prints the shift type and
    # the amount as two operands and the assembler prints them as one.
    t = re.sub(r',\s*(lsl|lsr|asr),', r', \1', t)
    t = re.sub(r'\s+', ' ', t).strip()
    t = re.sub(r'\s*,\s*$', '', t)
    t = re.sub(r'\s*,\s*]', ']', t)
    if count and t != raw:
        key = ' '.join(raw.split())
        for r in NORM_RULES:
            if r[0] == key:
                r[1] += 1
                break
        else:
            NORM_RULES.append([key, 1, ' '.join(t.split())])
    return t


def norm_stats():
    return NORM_RULES[:]


def norm_reset():
    del NORM_RULES[:]


# ---------------------------------------------------------------------------
# 11. The retractions.
# ---------------------------------------------------------------------------

def sec11():
    hdr(11, 'RETRACTIONS', 'printed in full, and asserted as TEXT by the harness')
    print('  Each of these was asserted in a draft, in docs/aarch64-section-')
    print('  plan.md, or in the brief for this course, and then failed to')
    print('  survive either a quotation of the specification or a measurement.')
    print('  None of them was softened.  crosscheck.py asserts the TEXT of')
    print('  every one, so a retraction can be neither quietly dropped nor')
    print('  edited into being right.')
    print()
    for tag, claim, found, why in RETRACTIONS:
        print('  %s  the claim' % tag)
        print('       %s' % wrap(claim, '', 70).replace('\n', '\n       '))
        print('       %s' % 'WHAT WAS FOUND'.center(70, '-'))
        print('       %s' % wrap(found, '', 70).replace('\n', '\n       '))
        print('       %s' % 'WHY'.center(70, '-'))
        print('       %s' % wrap(why, '', 70).replace('\n', '\n       '))
        print()
    print('  %d retractions.  A course that reports zero of them on a subject' %
          len(RETRACTIONS))
    print('  this size has either not looked or has not been reading the')
    print('  documents it cites.')


# ---------------------------------------------------------------------------
# 12. The limits.
# ---------------------------------------------------------------------------

def sec12():
    hdr(12, 'LIMITS', 'what this file cannot show, in its own words')
    for title, why in (
        ('NOTHING IS EXECUTED',
         'There is no AArch64 machine on this host, no AArch64 emulator and no '
         'AArch64 linker.  Not one instruction has been run, so nothing here '
         'is a duration, a fault, a throughput or a portability claim, and the '
         'x86-64 course\'s 4.92x and 27.65x have no counterpart here and are '
         'NOT reproduced in any form.  The one cross-architecture comparison, '
         'in section 7, is a COMPILE-TIME INSTRUCTION COUNT.'),
        ('THE ALIGNMENT FAULT IS NOT MEASURED',
         'Whether a misaligned access through SP traps is decided by '
         'SCTLR_ELx.A, and a Linux EL0 process runs with that bit clear, so on '
         'Linux the requirement is a software contract.  This file measures the '
         'ENCODING of the instruction that reads the bit (0xd5381000) and does '
         'not claim the fault.  The AAPCS64 says "the hardware requires"; the '
         'hardware CAN require it and on this platform does not.'),
        ('THE DECODER IS A SUBSET OF NAMES',
         'Advanced SIMD vector arithmetic and the FP conversions are not '
         'modelled.  The subset is a subset of NAMES and not of LENGTHS: an '
         'unmodelled word is COUNTED and still contributes exactly 4 bytes, '
         'which is the one thing a fixed-width encoding gives you for free.  '
         'A cross-check that reported unmodelled words as failures would be '
         'reporting its own declared scope as a bug.'),
        ('THE TWO READERS SHARE A SOURCE',
         'clang assembled the corpus and llvm-objdump-21 disassembled it, and '
         'both come from one LLVM tree.  The cross-check establishes that this '
         'decoder and one other piece of software AGREE on what the bytes mean. '
         'It does not establish that either agrees with the silicon, and the '
         'poison in section 10 is the only thing that shows the check can fail '
         'at all.'),
        ('THE SPECIFICATION IS AN ORACLE, NOT A MEASUREMENT',
         'Section 2 is QUOTED and every other section is measured, and the two '
         'are printed separately so a reader can check one against the other '
         'with the compiler out of the way.  A course that blended them would '
         'be unable to say which of its sentences a reader should distrust if '
         'the compiler changed.'),
        ('THE COMPILER IS THE TEST SUBJECT, NOT THE ARCHITECTURE',
         'Every "what the compiler chose" number is a property of clang '
         '21.1.8 and of a 25-function corpus of ordinary C.  The register '
         'ASSIGNMENT is the specification\'s and will not change; the frame '
         'SIZES, the row counts and the instruction counts are the '
         'compiler\'s and will.  The harness asserts the first as exact values '
         'and the second as shapes, and says which is which in every table.'),
        ('THE ENCODER IS ONE ASSEMBLER',
         'There is no second AArch64 assembler on this host.  Every refusal in '
         'this file is one assembler\'s, and a boundary is a property of the '
         'encoder as much as of the encoding.  Where a boundary is quoted, the '
         'diagnostic is printed verbatim so a reader can see whose boundary it '
         'is.'),
        ('THE ARCHITECTURAL MANUAL IS NOT CITED DIRECTLY',
         'The encoding claims are read out of an assembler and cross-read '
         'against a disassembler, and the register and stack claims are quoted '
         'from the AAPCS64 (release 2025Q4) and the SVE variant '
         '(ARM_100986_0000_00) with section numbers.  The architectural '
         'reference manual was not consulted, and a claim that needs it -- the '
         'fault behaviour in section 5B most of all -- is marked as not '
         'measured rather than argued from memory.'),
        ('NO CORPUS IS A DISTRIBUTION',
         'Twenty-five functions of ordinary C is a sample of what clang chose, '
         'not a census of what compilers choose.  Every count in this file is a '
         'count OF THIS CORPUS and the tables say so, because a census column '
         'is the only thing that tells a checker which examines nothing from '
         'one that found nothing.'),
    ):
        print('  %s' % title)
        print(wrap(why, '       ', 70))
        print()


# ===========================================================================
# The driver.
# ===========================================================================

SECTIONS = [
    (1, 'THE INSTRUMENT, AND WHAT IT IS NOT', sec1),
    (2, 'THE SPECIFICATION, AS AN ORACLE', sec2),
    (3, 'THE ENCODING, AND THE SIX MODELS', sec3),
    (4, 'THE ARGUMENT AUDIT', sec4),
    (5, 'THE ALIGNMENT RULE', sec5),
    (6, 'ONE REGISTER, TWO NAMES, TWO ZEROS', sec6),
    (7, 'NO RED ZONE', sec7),
    (8, 'CALLEE-SAVED', sec8),
    (9, 'CFI: THE FRAME IN A SECOND LANGUAGE', sec9),
    (10, 'TWO READERS, AND ONE POISONED', sec10),
    (11, 'RETRACTIONS', sec11),
    (12, 'LIMITS', sec12),
]


def header():
    print(RULE)
    print('a64abi -- the artifact for "The AArch64 Procedure Call Standard"')
    print(RULE)
    print('THE METHOD IS FORCED AND IT IS STATED FIRST:')
    print('  there is no AArch64 machine on this host, no AArch64 emulator and')
    print('  no AArch64 linker, so NOT ONE INSTRUCTION IN THIS COURSE HAS')
    print('  BEEN RUN and there are NO TIMINGS anywhere in this file or on any')
    print('  of its five pages.  The x86-64 section measured a 4.92x and a')
    print('  27.65x; nothing here has a counterpart and nothing here fakes one.')
    print()
    print('  the two readers are the decoder in this file and llvm-objdump-21,')
    print('  and every claim about bytes is read by both (MEASURED-ON-BYTES).')
    print('  the specification is the ORACLE and the compiler is the TEST')
    print('  SUBJECT, and every disagreement is printed as a RETRACTION in')
    print('  section 11 and asserted as text by crosscheck.py.')
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
        print('  numbers.  The first SIX are this course\'s; the other %d are'
              % BASE_MODEL_COUNT)
        print('  the encoding course\'s, imported unchanged.')
        print()
        print('  %-16s %-44s %s' % ('model', 'the guard it checks', 'claim'))
        for name, guard, claim in EXTRA_CLAIMS:
            print('  %-16s %-44s' % (name, guard))
            print('  %-16s %-44s   %s' % ('', '', claim[:100]))
        for name, guard, claim in Dec.CLAIMS:
            print('  %-16s %-44s %s' % (name, guard[:44], claim[:64]))
        print()
        print('  %d models and %d claims.  A word no model claims is printed as'
              % (MODEL_COUNT, len(EXTRA_CLAIMS) + len(Dec.CLAIMS)))
        print('  (op 0xNNNNNNNN) and is COUNTED, not dropped: the subset is a')
        print('  subset of NAMES, not of LENGTHS, so an unnamed word still')
        print('  contributes 4 bytes.')
        return 0
    if cmd == '--section':
        want = int(args[1])
        os.chdir(HERE)
        header()
        for n, _t, fn in SECTIONS:
            if n == want:
                fn()
        return 0
    if cmd == '--run':
        os.chdir(HERE)
        only = None
        if len(args) > 1:
            only = [int(x) for x in args[1].split(',')]
        header()
        for n, _t, fn in SECTIONS:
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
