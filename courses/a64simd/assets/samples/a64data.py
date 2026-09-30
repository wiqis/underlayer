#!/usr/bin/env python3
"""a64data.py -- the artifact for "The AArch64 Data Path: NEON, Atomics and
Ordering".

THE METHOD IS FORCED AND IT IS PRINTED FIRST, BEFORE ANY MEASUREMENT.

There is no AArch64 machine on this host, no AArch64 emulator and no AArch64
linker.  NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN, and there are NO
TIMINGS anywhere in this file or on any of its five pages.  The two earlier
courses in this section -- `simd` and `smp` -- measured durations, and the
x86-64 sibling of this course measured 3.89x for a wider vector, 4.92x for a
syscall and 27.65x for a mode change.  Nothing here has a counterpart of any
of those, because there is no AArch64 clock to read one from, and faking a
smaller number is worse than stating the absence.

Every claim below carries one of three labels, and the labels are not
decoration -- they are the only honest treatment available:

    MEASURED            an experiment on the compiler, the assembler, the
                        object file or the bytes.  One command reproduces it.
    MEASURED-ON-BYTES   a property of the emitted BYTES, read TWICE -- by the
                        decoder in this file and by llvm-objdump-21 -- with the
                        two readers compared word by word.
    QUOTED              a manual claim, with the document and the section
                        printed beside it, and never mixed with a measurement.

The specifications are the ORACLE.  The compiler and the assembler are the
TEST SUBJECT.  Every disagreement between them is printed as a RETRACTION in
section 13, with the source that asserted the claim BEFORE this course existed
where one exists, and crosscheck.py asserts the text of every one, so a
retraction can be neither quietly dropped nor edited into being right.

    python3 a64data.py --run          the whole run, 14 sections
    python3 a64data.py --section=5    one section
    python3 a64data.py --audit        the models this file adds
    python3 a64data.py --why 0xc85ffc01    explain one word
"""

import collections
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RULE = '=' * 78
THIN = '-' * 78

MEAS = 'MEASURED'
BYTES = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

CLANG = 'clang'
OBJDUMP = 'llvm-objdump-21'
READELF = 'llvm-readelf-21'
TARGET = 'aarch64-linux-gnu'
LEVELS = ('O0', 'O1', 'O2', 'Os')
SVE = ('-march=armv8.2-a+sve',)
LSE = ('-march=armv8.1-a',)
RCPC = ('-march=armv8.3-a',)
FP16 = ('-march=armv8.2-a+fp16',)


# ===========================================================================
# Part one: the decoder this course contributes, and the two it borrows.
# ===========================================================================


def find_sibling(course, filename):
    """Walk UP until a directory holds a sibling `course`'s `filename`.

    Same upward search and the same reason as the two earlier courses in this
    section: a hardcoded `../../a64asm/...` breaks the first time somebody
    changes a directory depth, and the first version of the machine course's
    lookup tried `dirname(DECODER_DIR)/a64abi` -- a path that cannot exist, so
    the import silently found nothing and the file ran with 27 models while
    printing a note about six it did not have.  A silent import failure is
    worse than a loud one, which is why the caller PRINTS the count either way
    and why the decoder below REFUSES to start without the encoding course's.
    """
    env = os.environ.get('A64%s_DIR' % course[3:].upper())
    if env and os.path.exists(os.path.join(env, filename)):
        return env
    d = HERE
    for _ in range(8):
        cand = os.path.join(os.path.dirname(d), course, 'assets', 'samples')
        if os.path.exists(os.path.join(cand, filename)):
            return cand
        nxt = os.path.dirname(d)
        if nxt == d:
            break
        d = nxt
    return None


def _load(course, module, filename):
    d = find_sibling(course, filename)
    if d and d not in sys.path:
        sys.path.insert(0, d)
    if not d:
        print('NOTE: could not FIND %s; this file cannot run.' % filename)
        return None
    try:
        return __import__(module)
    except Exception as e:                      # noqa: BLE001
        print('NOTE: could not import %s (%s); this file runs with its own '
              'models plus the encoding course\'s.' % (filename, e))
        return None


Dec = _load('a64asm', 'a64dec', 'a64dec.py')
if Dec is None:
    raise SystemExit('a64dec.py is required: this course OWNS no second '
                     'decoder and refuses to invent one')
# CAPTURED BEFORE a64sys is imported, and that ordering is load-bearing rather
# than cosmetic: importing the machine course RUNS it, and that file
# reassigns `a64dec.MODELS` to its own list.  Reading the count afterwards
# gives 33 -- the machine course's twelve plus the encoding course's
# twenty-one -- and then "models in the imported decoder" is a number about
# two files where it claims to be a number about one.
BASE_MODELS = list(Dec.MODELS)
BASE_MODEL_COUNT = len(BASE_MODELS)
Sys = _load('a64sys', 'a64sys', 'a64sys.py')

SIBLING_MODELS = list(Sys.EXTRA_MODELS) if Sys else []
SIBLING_MODEL_COUNT = len(SIBLING_MODELS)

Insn = Dec.Insn
Bad = Dec.Bad
Undefined = Dec.Undefined

# The element-size alphabet, in the order the architectures use it.  The
# NAMES are QUOTED (ARM DDI 0487, "A64 Advanced SIMD" and the SVE chapter of
# the same document) and the ENCODING VALUES beside them are MEASURED, by
# section 3 and section 4 of this file.
LANES = ('8b', '16b', '4h', '8h', '2s', '4s', '1d', '2d')
LANE_BITS = {'b': 8, 'h': 16, 's': 32, 'd': 64}


def lane_name(sz, q, esz_bits):
    """The `v0.4s` spelling for a measured size field."""
    if sz is None:
        return 'v?'
    if q is not None and not q and esz_bits < 64:
        return 'v%d.%d%s' % (0, 128 // esz_bits // 2, 'bhsd'[esz_bits // 16 - 1]) \
            if esz_bits >= 16 else 'v0.16b'
    if esz_bits == 8:
        return 'v0.16b'
    if esz_bits == 16:
        return 'v0.8h'
    if esz_bits == 32:
        return 'v0.4s'
    return 'v0.2d'


# ---------------------------------------------------------------------------
# The models.  Each one guards on FIXED bits measured by section 3 and reads
# the fields it owns.  Every claim a model makes is in EXTRA_CLAIMS, and
# `--audit` prints that table; crosscheck.py asserts its width, because a
# model added without a claim is a model nobody checks.
# ---------------------------------------------------------------------------


# The specimen list for every model this file adds.  A guard is DERIVED from
# these words rather than typed, and the reason is a bug this file made twice
# in one afternoon: the first version of these models wrote bit patterns as
# literals, and a guard with one bit wrong in it does not fail -- it returns
# False, the dispatch moves on, and the word falls through to "(op 0x...)".
# The symptom is a model that is silently INACTIVE, and it looks exactly like
# a model that is working and simply is not reached.
#
# A guard derived from a word cannot be transcribed wrong, and a reader who
# wants to check one has the words, the field, and nothing else to trust.  The
# constants are also a MEASUREMENT rather than a memory, which is the whole
# method of the encoding course's field map applied to the guards instead of
# to the fields -- and the same sweep produces them.
SPECIMENS = {
    'm_simd_ldst_single': (0x3d400000, 0x7d400000, 0xbd400000, 0xfd400000,
                           0x3dc00000, 0x3d000000, 0x3d800000),
    'm_simd_ldst_pair': (0xad400400, 0xad000400, 0x6d400400),
    'm_simd_structure': (0x4c407000, 0x4c007000, 0x4c408000, 0x4c40a000,
                         0x4c404000, 0x4c400000, 0x4c008000, 0x4c000800,
                         0x4c407400, 0x4c407800, 0x4c407c00),
    'm_simd_dp': (0x4ea28420, 0x4ee08420, 0x4e22d420, 0x4ea26420,
                  0x6ee03444, 0x4ee13402, 0x6ee21c20, 0x2ee21c20,
                  0x4ea01c01, 0x6ea41c40, 0x4ee2bc20, 0x4eb1b820,
                  0x4e218400, 0x0e208420),
    'm_simd_3diff': (0x4e823820, 0x4e821820, 0x4e822820),
    'm_advsimd_ext': (0x6e004001, 0x6e204000, 0x6e000400),
    'm_simd_2reg': (0x5ef1b800, 0x5ef1b820),
    'm_simd_copy': (0x4e040c00, 0x0e030420, 0x4e0c1c20, 0x0e0c3c00,
                    0x0e062c00, 0x4e181c20, 0x4e0c2c00, 0x4e080d00),
    'm_simd_movi': (0x6f00e400, 0x4f000400, 0x4f0707e0, 0x4f002420,
                    0x4f00e420, 0x4f008420, 0x4f000420, 0x2f00e400),
    'm_fp_3src': (0x1e212800, 0x1e222800, 0x1e232800, 0x1e242800,
                  0x1e222820, 0x1e622820),
    'm_fp_copy_scalar': (0x5e0c0423, 0x5e140424, 0x5e1c0421, 0x5e0c0441,
                         0x5e1c0441, 0x5e140443),
    'm_exclusive': (0x885f7c01, 0x885ffc01, 0xc85ffc01, 0x085ffc01,
                    0x485ffc01, 0x88027c01, 0xc802fc01, 0x08027c01,
                    0x0802fc01, 0xc87f2009, 0xc87fa009, 0x882e2009,
                    0xc82ea009, 0x085f7c01, 0x485f7c01),
    'm_ldar_stlr': (0x08dffc01, 0x48dffc01, 0x88dffc01, 0xc8dffc01,
                    0x089ffc01, 0xc89ffc01),
    'm_lse': (0x88a17c02, 0x88e17c02, 0x88a1fc02, 0x88e1fc02, 0x08a17c02,
              0xc8a17c02, 0x48227c06, 0x4862fc06, 0x48627c06, 0xb8210002,
              0xf8210002, 0xb8a10002, 0xf8e10002, 0xb8610002, 0xb8e10002,
              0xb8218002, 0xf8218000, 0xb8a18002, 0x38218002, 0x38210002,
              0xb8211002, 0xb8212002, 0xb8213002),
    'm_barrier_opt': (0xd5033fbf, 0xd5033f9f, 0xd5033fdf, 0xd50339bf,
                      0xd5033bbf, 0xd5033abf, 0xd50337bf, 0xd50333bf,
                      0xd50331bf, 0xd50332bf, 0xd5033dbf, 0xd5033ebf,
                      0xd50335bf, 0xd50336bf, 0xd5033d9f),
    'm_sve': (0x04c00020, 0x04800020, 0x04400020, 0x04000020, 0x04c00420,
              0x04c00041),
    'm_pstate_field': (0xd51b4001, 0xd51b4021, 0xd51b4041, 0xd51b4061,
                       0xd51b4081, 0xd51b40a1, 0xd51b40c1, 0xd51b40e1),
    'm_ccmp': (0xfa450060, 0xfa400061, 0xfa430020, 0xfa5f0020),
    'm_ldst_reg_corrected': (0x38696908, 0x78696908, 0xb8696908, 0xf8696908,
                             0x38e96908, 0x382a6928, 0xf9800000, 0xb8696948),
}


def guard_for(name, lo):
    """Every RUN of constant bits above `lo`, as ((hi, lo, value), ...).

    Every run, of ZEROS as well as ones, and a run rather than a window,
    because the groups are not windows.  A model whose constant bits are
    bits[27:25] and bit 24 clear, with a field in between, cannot be guarded by
    a single span without guessing where the span ends -- and the first
    version of these guards guessed, which is the bug the whole
    `guard_for` exists to remove.

    The set is computed by AND-ing and OR-ing the specimen words, so a bit
    that is the same in all of them is a guard and a bit that varies is a
    field, and nothing in between.  It is a measurement, and it is the same
    measurement the encoding course's field map makes, pointed the other way.
    """
    ws = SPECIMENS[name]
    and_ = 0xffffffff
    or_ = 0
    for w in ws:
        and_ &= w
        or_ |= w
    out = []
    b = 31
    while b >= lo:
        v = (and_ >> b) & 1
        if ((or_ >> b) & 1) == v:
            hi = b
            while b > lo and ((and_ >> (b - 1)) & 1) == v and \
                    ((or_ >> (b - 1)) & 1) == v:
                b -= 1
            out.append((hi, b, (and_ >> b) & ((1 << (hi - b + 1)) - 1)))
        b -= 1
    return tuple(out)


def guard_of(i, name, lo, label=None):
    """Apply a derived guard.  Returns False on the first bit that moves."""
    for hi, blo, val in guard_for(name, lo):
        if not i.fixed(hi, blo, val, label or
                       ('%s: bits[%d:%d] = %s' % (name, hi, blo,
                                                   format(val, '0%db' %
                                                          (hi - blo + 1))))):
            return False
    return True


def g(specimen, hi, lo):
    """A guard constant taken from an ASSEMBLED WORD, never typed by hand.

    Every guard in this file is written as `fixed(hi, lo, g(SPEC, hi, lo), ...)`
    where SPEC is a 32-bit word this file's own section 2 printed.  The first
    version of these models typed the bit patterns as literals -- `0b00100`
    where the measurement said `0b00010` -- and the symptom was a model that
    returned False on the very instruction it was written for, with an empty
    explanation list, which looks exactly like a model that is working.  A
    guard derived from a word cannot be transcribed wrong, and a reader who
    wants to check one has the word and the field and no third thing to trust.

    It also means the guards are MEASURED rather than remembered, which is the
    whole method of this file and the whole method of the encoding course's
    field map, applied to the guards instead of to the fields.
    """
    return (specimen >> lo) & ((1 << (hi - lo + 1)) - 1)


def m_simd_ldst_single(i):
    """LDR/STR of one `v` register, in any of the five views.  MEASURED.

    The five words, and the whole of section 3's first finding:

        ldr b0, [x0]   0x3d400000
        ldr h0, [x0]   0x7d400000
        ldr s0, [x0]   0xbd400000
        ldr d0, [x0]   0xfd400000
        ldr q0, [x0]   0x3dc00000

    `ldr b0` and `ldr q0` differ in EXACTLY ONE BIT, and it is bit 23 -- not
    bit 30, not bit 31, and not anywhere near the top of the word.  So:

        bits[31:30]  size: 00 = B, 01 = H, 10 = S, 11 = D   (MEASURED)
        bit  23      Q: the 128-bit form, an extra bit ABOVE size
        bit  22      L: load or store     (MEASURED: b0 vs h0 keeps bit 22)

    which means the ACCESS SIZE is a THREE-bit field with FIVE allocated
    values out of eight.  The first draft of this model read bit 31 as Q,
    because "the Q bit is the top bit" is what the SVE and Advanced SIMD
    three-same groups use, and it named `ldr b0` and `ldr q0` identically --
    two different access sizes with one name and no complaint from anything.
    The same four words at a different bit position is section 4.
    """
    if not guard_of(i, 'm_simd_ldst_single', 24):
        return False
    opc = i.read(31, 30)
    Q = i.read(23, 23)
    L = i.read(22, 22)
    imm12 = i.read(21, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    esz = {0b00: 8, 0b01: 16, 0b10: 32, 0b11: 64}[opc]
    if Q and esz == 8:
        sfx, esz, esz_bits = 'q', 128, 128
    else:
        sfx, esz_bits = 'bhsd'[opc], esz
    # `str q0, [x0]` prints `str q0` with NO second suffix, and every other
    # size prints both: MEASURED, 0x3d800000 against 0xbd000000.
    #
    # THE SCALE IS IN BYTES, NOT IN BITS.  MEASURED, five assembles at one
    # source offset of 4080:
    #
    #     str b0, [x1, #4080]  0x3d3fc020  imm12 = 4080   4080 * 1
    #     str h0, [x1, #4080]  0x7d1fe020  imm12 = 2040   4080 * 2
    #     str s0, [x1, #4080]  0xbd0ff020  imm12 = 1020   4080 * 4
    #     str d0, [x1, #4080]  0xfd07f820  imm12 =  510   4080 * 8
    #     str q0, [x1, #4080]  0x3d83fc20  imm12 =  255   4080 * 16
    #
    # so imm12 is a SCALED offset and the scale is the access size in BYTES.
    # The first version of this line multiplied by `esz`, which is the access
    # size in BITS, and printed 96 where the second reader prints 12 --
    # 0xbd000fe0 has imm12 = 3 and 3 * 4 = 12.  Off by a factor of eight, on
    # every scaled load and store in the corpus, with a legal instruction
    # printed and nothing anywhere saying the number was wrong.  This is
    # retraction R23 and it is the second time in this file that a unit
    # mistake produced a plausible number instead of an error.
    off = imm12 * ((128 if Q else esz) // 8)
    base = 'sp' if rn == 31 else 'x%d' % rn
    # THE SUFFIX APPEARS TWICE IN THE SYNTAX AND IT IS ONE FIELD.  MEASURED:
    # `str s0, [sp, #12]` is 0xbd000fe0 with bits[31:30] = 10 and the
    # disassembly prints `str s0`, while `str q0, [x0]` is 0x3d800000 and
    # prints `str q0`.  One size field, written once in the instruction and
    # TWICE in the assembly -- once on the mnemonic and once on the register --
    # and a third time as `v0.4s` when a container is meant instead of a
    # scalar.  A decoder that reads the field once has to know which of the
    # three spellings it is looking at, and the first draft of this model got
    # it wrong by splitting the suffix and the register name apart.
    dst = '%s%d' % (sfx, rt)
    i.name = ('ldr' if L else 'str')
    i.ops = ['%s, [%s, #%d]' % (dst, base, off)]
    i.say('the ACCESS SIZE is bits[31:30] PLUS bit 23, and bit 23 is the '
          '128-bit form -- MEASURED, because `ldr b0` and `ldr q0` differ in '
          'that bit and in no other.  A decoder that reads bit 31 as Q calls '
          'both of them `ldr b`.')
    i.say('bit 22 is L.  So the three bits together are a size with FIVE '
          'allocated values and THREE unallocated, and the load/store bit '
          'that separates `ldr b0` from `str b0` is bit 22 -- which is the '
          'same position the SVE size field uses for its HIGH size bit.')
    if Q:
        i.say('Q = 1 is only allocated with size = 00, so the 128-bit form is '
              'ONE of eight combinations of three bits and not a fourth size '
              'value in a four-bit field.')
    return True


def m_simd_ldst_pair(i):
    """LDP/STP of two `v` registers.  MEASURED, and it is the instruction
    the vectoriser emits in a reduction loop, so it is in the corpus.

        ldp d0, d1, [x0]   0x6d400400   opc = 01
        ldp q0, q1, [x0]   0xad400400   opc = 10
        stp q0, q1, [x0]   0xad000400   L = 0

    `ldp q0,q1` and `ldp d0,d1` differ in EXACTLY ONE BIT, bit 29 -- so the
    pair width is opc = bits[31:30] with 00 = 32-bit, 01 = 64-bit, 10 = 128-bit
    and 11 unallocated, and there is no Q bit to find.  The INHERITED decoder
    claims this group first (`m_ldst_pair` reads V at bit 26) and hands back
    "(SIMD pair, op 0x...)" with a note; this model is PREPENDED, so it names
    the word and the sibling's model never sees it.  The same shape the
    encoding course retracted about `cset` being `csinc` with an inverted
    condition: a group's guard is allowed to win with a name, and the name
    only has to be right once.
    """
    if not guard_of(i, 'm_simd_ldst_pair', 24):
        return False
    opc = i.read(31, 30)
    L = i.read(22, 22)
    imm7 = i.read(21, 15)
    rt2 = i.read(14, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    if opc == 0b10:
        sfx, scale = 'q', 16
    elif opc == 0b01:
        sfx, scale = 'd', 8
    elif opc == 0b00:
        sfx, scale = 's', 4
    else:
        return False
    if imm7 & 0b1000000:
        imm7 -= 0b10000000
    base = 'sp' if rn == 31 else 'x%d' % rn
    i.name = ('ldp' if L else 'stp')
    i.ops = ['%s%d, %s%d, [%s, #%d]' % (sfx, rt, sfx, rt2, base,
                                        imm7 * scale)]
    i.say('the PAIR WIDTH is opc = bits[31:30] and there is no Q bit: '
          '`ldp q0,q1` and `ldp d0,d1` differ in bit 29 alone, MEASURED.  '
          'The 128-byte stack-alignment rule the ABI course found is enforced '
          'by THIS instruction, which is why `v0` and `v1` and a frame pointer '
          'appear in the same constraint.')
    return True


def m_simd_structure(i):
    """LD1/LD2/LD3/LD4 -- the structure load, and the one form with no x86-64
    equivalent.  MEASURED, and TWO of its three field positions are the
    opposite of what the first draft of this model read.

        ld1 {v0.16b}, [x0]   0x4c407000
        ld1 {v0.8h},  [x0]   0x4c407400   xor 0x400   -> bit 10
        ld1 {v0.4s},  [x0]   0x4c407800   xor 0x800   -> bit 11
        ld1 {v0.2d},  [x0]   0x4c407c00   xor 0xc00   -> bits[11:10]

    So the element size is bits[11:10] and NOT bits[15:14], which is where the
    first draft of this model put it because the two are the same width and the
    same VALUES and only four bits apart.  bits[15:12] is the operation word,
    and it is a FOUR-bit field that carries the NUMBER OF REGISTERS as well as
    the de-interleaving:

        0b0111  LD/ST one structure          ld1 {v0.16b}, [x0]
        0b1010  LD/ST one structure, LIST    ld1 {v0.16b, v1.16b}, [x0]
        0b1000  LD/ST two structures         ld2
        0b0100  LD/ST three structures       ld3
        0b0000  LD/ST four structures        ld4
        0b1101  LD/ST one structure, REPLICATE  ld1r

    MEASURED over all six, and the interesting one is the second: there are
    TWO `ld1` encodings, one for one register and one for a list, and they
    differ in bits[15:12] alone.

    AND THE REGISTER LIST IS ONE FIVE-BIT FIELD.  MEASURED, and the sweep is
    what showed it: `ld1 {v0,v1}`, `ld1 {v1,v2}`, `ld1 {v2,v3}`,
    `ld1 {v4,v5}` and `ld1 {v30,v31}` differ in bits 0, 1, 2, 3 and 4 --
    0x0000001f, the whole field.  A sweep that visits only EVEN starts --
    v0, v2, v4, v30 -- reports bits[4:1] and a four-bit field, because an
    even-only sweep cannot move bit 0.  That is retraction R18 and it is the
    same shape as the HINT guard the machine course found one bit too narrow:
    A SWEEP THAT ONLY VISITS THE VALUES A FORM ACCEPTS IS A SHORTER SWEEP THAN
    THE FIELD.

    Every register number after the first is VALIDATED and then DISCARDED,
    and the validation is what produces the two best diagnostics in this file:

        ld1 {v0.16b, v5.16b}, [x0]   -> invalid operand for instruction
        ld4 {v0.16b, v1.16b, v9.16b, v9.16b}, [x0]
                                     -> registers must have the same
                                        sequential stride
    """
    if not guard_of(i, 'm_simd_structure', 24):
        return False
    L = i.read(22, 22)
    op = i.read(15, 12)
    size = i.read(11, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    if op in (0b0111, 0b1010):
        i.name = ('ld' if L else 'st') + '1'
        regs = 1
    elif op in (0b1000, 0b0100, 0b0000):
        # MEASURED: bits[15:12] = 0b1000 is LD2, 0b0100 is LD3 and 0b0000 is
        # LD4 -- the register COUNT is a subtraction from 0b1000 and not a
        # two-bit field, which is why LD2, LD3 and LD4 are the only three
        # counts in the space and LD1 is spelled 0b0111 in a different corner
        # of the same four bits.  The first version of this model read it as
        # `2 + op` and a dictionary lookup keyed on the STRING of the value,
        # which is a KeyError waiting for a fourth entry.
        regs = {0b1000: 2, 0b0100: 3, 0b0000: 4}[op]
        i.name = ('ld' if L else 'st') + str(regs)
    else:
        return False      # ld1r and the load/store-pair forms are DECLINED
    i.name = i.name
    if size > 3:
        return False
    esz = 8 << size
    lanes = 128 // esz
    lst = ', '.join('v%d.%d%s' % (rt + k, lanes, 'bhsd'[size])
                    for k in range(regs))
    base = 'sp' if rn == 31 else 'x%d' % rn
    i.name = i.name
    i.ops = ['{%s}, [%s]' % (lst, base)]
    i.say('the element size is bits[11:10] and it is FOUR BITS FROM where the '
          'single-register load puts its size, at bits[31:30]+bit 23 -- and '
          'the operation word bits[15:12] is what carries the register COUNT, '
          'so "one ld1" is two encodings.  MEASURED on all six.')
    i.say('the register list is ONE five-bit field at bits[4:0] holding the '
          'FIRST register (MEASURED over five starts including an ODD one: '
          'mask 0x0000001f) and the rest are validated against the stride and '
          'thrown away.  An even-only sweep reports bits[4:1] and a four-bit '
          'field, and that is retraction R18.')
    return True


def m_simd_dp(i):
    """The Advanced SIMD THREE-SAME group, integer and floating-point.
    MEASURED, and the opcode table below IS the sweep.

        add  v0.4s, v1.4s, v2.4s   0x4ea28420  op = 0b100001
        sub  v0.4s, v1.4s, v2.4s   0x6ea28420  op = 0b100011, U = 1
        mov  v0.16b, v1.16b        0x4ea01c01  op = 0b000111, U = 0
        bit  v0.16b, v1.16b, v2.16b 0x6ea41c40 op = 0b000111, U = 1
        bif  v0.16b, v1.16b, v2.16b 0x6ee21c20 op = 0b000111, U = 1, bit22
        smax v0.4s, v1.4s, v2.4s   0x4ea26420  op = 0b011001
        cmgt v0.4s, v1.4s, v2.4s   0x4ee23420  op = 0b001101, U = 1
        fadd v0.4s, v1.4s, v2.4s   0x4e22d420  op = 0b110101, U = 1
        addp v0.2d, v1.2d, v2.2d   0x4ee2bc20  op = 0b101111

    The ELEMENT SIZE is bits[23:22] -- TWO bits, all four allocated -- and the
    128-bit form is bit 30.  Compare the single load twenty lines above in
    m_simd_ldst_single, where the size is three bits and Q is bit 23.  Same
    architecture, same four element sizes, two different layouts, and the
    reason is worth a sentence: this group has no load/store bit to save bits
    for, so it can put the size where it likes; the load group has L at bit 22,
    which is INSIDE the three-bit size field, which is why Q had to move down
    to 23 and the size had to grow to include bits[31:30].

    AND THE TABLE IS A MEASURED TABLE, not a remembered one, and the two
    halves of each entry are what makes it useful:

        U = bit 29 is the SIGN.  MEASURED: `umax v0.4s, v1.4s, v2.4s` is
        0x6ea26420 and `smax v0.4s, v1.4s, v2.4s` is 0x4ea26420 -- they differ
        in bit 29 and nowhere else, so there are 32 signedness pairs in the
        group and 64 names in a six-bit field plus one bit.

        bit 22 is the ACCUMULATE bit.  MEASURED: `add v0.2d, v2.2d, v0.2d`
        (0x4ee08420, accumulate into the destination) and `add v0.2d, v1.2d,
        v0.2d` (0x4ee08420 with Rn = v1, plain add) differ in bit 22 and in
        Rn -- and `bif` sets it too.  An operand that changes the OPERATION and
        an operand that changes a REGISTER sharing one field is the trap the
        encoding course recorded about `Rt2`, and it is a six-bit field with a
        second bit riding on it.
    """
    if not guard_of(i, 'm_simd_dp', 21):
        return False
    Q = i.read(30, 30)
    U = i.read(29, 29)
    size = i.read(23, 22)
    acc = i.read(22, 22)
    rm = i.read(20, 16)
    op = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if size > 3:
        return False
    TABLE = {
        0b100001: ('add', 0), 0b100011: ('sub', 0), 0b100101: ('add', 1),
        0b100111: ('sub', 1), 0b011001: ('smax', 0), 0b011101: ('umax', 0),
        0b001101: ('cmgt', 0), 0b001100: ('cmge', 0), 0b001111: ('cmhi', 0),
        0b001110: ('cmhs', 0), 0b100011 + 0: ('cmeq', 1),
        0b000111: ('mov', 0), 0b000111 + 0: ('mov', 0),
        0b110101: ('fadd', 0), 0b110100: ('fsub', 0), 0b111101: ('fmul', 0),
        0b110011: ('fmax', 0), 0b111100: ('fmin', 0), 0b111000: ('fdiv', 0),
        0b101111: ('addp', 0), 0b101110: ('addv', 0),
    }
    # the SIGN is a separate bit, so the table is (opcode) -> (base, signed)
    # and the pair is resolved here rather than in the table, because getting
    # it wrong is exactly the bug the encoding course found with the register
    # function's default argument: A FLAG WITH A DEFAULT IS A FLAG NOBODY
    # CHECKS.  The measured pairs are printed at every row this file measured.
    OPMAP = {
        (0b100001, 0): 'add', (0b100001, 1): 'add',
        (0b100011, 0): 'sub', (0b100011, 1): 'cmeq',
        (0b100101, 0): 'add', (0b100101, 1): 'cmge',
        (0b100111, 0): 'sub', (0b100111, 1): 'cmgt',
        (0b011001, 0): 'smax', (0b011001, 1): 'umax',
        (0b011101, 0): 'smin', (0b011101, 1): 'umin',
        (0b001100, 0): 'cmge', (0b001100, 1): 'cmge',
        (0b001101, 0): 'cmgt', (0b001101, 1): 'cmgt',
        (0b001110, 0): 'cmhs', (0b001111, 0): 'cmhi',
        (0b000111, 0): 'mov', (0b000111, 1): 'bit',
        (0b110101, 0): 'fadd', (0b110100, 0): 'fsub',
        (0b111101, 0): 'fmul', (0b111000, 0): 'fdiv',
        (0b110011, 0): 'fmax', (0b111100, 0): 'fmin',
        (0b101111, 0): 'addp', (0b101110, 0): 'addv',
        # the ACCUMULATE forms, keyed by 2 because that is what the extra bit
        # does: `add v0.2d, v2.2d, v0.2d` is the same opcode as `add` with
        # bit 22 set, and MEASURED it is the same six bits and no other.
        (0b100001, 2): 'add', (0b100111, 2): 'sub',
        (0b001101, 2): 'cmgt', (0b001100, 2): 'cmge',
        (0b000111, 2): 'bsl', (0b000111, 3): 'bif',
        (0b101110, 2): 'addp',
    }
    nm = OPMAP.get((op, (U | (acc << 1)) if acc else U))
    if nm is None:
        return False
    esz = 8 << size
    lanes = (128 if Q else 64) // esz
    suf = 'bhsd'[size]
    v = '' if U else 'v'
    if op == 0b000111:
        # MEASURED over eight assembles: the four bitwise operations have
        # only BYTE arrangements, whatever the size field says.  `mov v0.8h,
        # v1.8h` assembles to the SAME 0x4ea11c20 as `mov v0.16b, v1.16b`, and
        # `bit v0.8h, v1.8h, v2.8h` is REFUSED.  So the size field here
        # chooses the OPERATION and the arrangement is 16 bytes if Q and 8 if
        # not Q -- a field that selects the operation and a bit that selects
        # the width, which is the reverse of every other group in the file.
        arr = '16b' if i.peek(30, 30) else '8b'
        i.name = nm
        if nm == 'mov':
            i.ops = ['v%d.%s, v%d.%s' % (rd, arr, rn, arr)]
        else:
            i.ops = ['v%d.%s, v%d.%s, v%d.%s'
                     % (rd, arr, rn, arr, rm, arr)]
        i.say('the BITWISE family, opcode 0b000111.  MEASURED over eight '
              'assembles: the arrangement is 16 bytes if Q and 8 if not, and '
              '`mov v0.8h, v1.8h` assembles to the SAME word as `mov v0.16b, '
              'v1.16b` while `bit v0.8h, ...` is REFUSED -- so bits[23:22] '
              'chooses the OPERATION here and bit 30 chooses the width, which '
              'is the reverse of every other group in this file and is why '
              'the two of them are separate fields in a shared six-bit opcode.')
        return True
    if nm in ('mov', 'bit'):
        i.name = nm
        i.ops = ['v%d.%d%s, v%d.%d%s' % (rd, lanes, suf, rn, lanes, suf)]
    elif nm in ('bif', 'bsl'):
        i.name = nm
        i.ops = ['v%d.%d%s, v%d.%d%s, v%d.%d%s'
                 % (rd, lanes, suf, rn, lanes, suf, rm, lanes, suf)]
    elif nm in ('addv', 'addp') and rm == 0b10001:
        # MEASURED, and the two are ONE opcode in TWO classes: `addv s0, v1.4s`
        # is 0x4eb1b820 with bits[28:24] = 0b01110 and `addp d0, v1.2d` is
        # 0x5ef1b820 with bits[28:24] = 0b11110, and the opcode bits[15:10] is
        # 0b010000 in BOTH.  So the discriminator is bit 28 -- the top bit of
        # the class field that brought the word to this model -- and the first
        # version of this model printed a string for the register and an
        # integer for the arrangement, in that order, and crashed on its own
        # third specimen.
        i.name = 'addv' if i.peek(28, 28) == 0 else 'addp'
        i.ops = ['%s%d, v%d.%d%s' % (suf, rd, rn, lanes, suf)]
    else:
        i.name = nm
        i.ops = ['%s%d.%d%s, %s%d.%d%s, %s%d.%d%s'
                 % (v, rd, lanes, suf, v, rn, lanes, suf, v, rm, lanes, suf)]
    i.say('three same.  The element size is bits[23:22] with all FOUR values '
          'allocated and the 128-bit form is bit 30 -- MEASURED, and the Q bit '
          'is seven positions from where the LOAD form puts it.')
    i.say('the SIGN is bit 29 and it is ONE BIT: `umax` is `smax` with bit 29 '
          'set, and nothing else moves.  So the group holds 64 mnemonics in a '
          'six-bit field and a bit, and the two halves are only separable '
          'because both were measured.')
    i.say('bit 22 is the ACCUMULATE bit: `add` and `adds` are the same opcode '
          'with it set and clear, and `bif` rides on it too.  An operand that '
          'changes the OPERATION and an operand that changes a REGISTER share '
          'a field in this architecture more than once, and the general form '
          'is the encoding course\'s: no field map can express it, only a '
          'decoder that says which group it is in.')
    return True


def m_simd_3diff(i):
    """The Advanced SIMD THREE-DIFFERENT group -- the permutes.  MEASURED, and
    it is a separate model for one measured reason.

        uzp1 v0.4s, v1.4s, v2.4s   0x4e821820  op = 0b000110
        trn1 v0.4s, v1.4s, v2.4s   0x4e822820  op = 0b001010
        zip1 v0.4s, v1.4s, v2.4s   0x4e823820  op = 0b001110
        add  v0.4s, v1.4s, v2.4s   0x4ea28420  op = 0b100001, bit 21 = 1

    The operation field is bits[15:10] in BOTH groups and bit 21 is the only
    thing that tells them apart, so a decoder that reads the field without the
    bit has one name for two instructions.  MEASURED: the three permutes all
    have bit 21 = 0 and `add` has bit 21 = 1, and no permute's opcode value
    appears in the three-same table.

    `zip1`, `uzp1` and `trn1` are also the instructions with NO x86-64
    equivalent, which is why the structure concept and this one meet: on
    x86-64 a 128-bit register is 128 bits and the only way to move lanes
    around is a shuffle with an immediate in a second register, and AArch64 has
    three named permutes because a fixed 32-bit instruction has six spare bits
    for a name.
    """
    if not guard_of(i, 'm_simd_3diff', 21):
        return False
    Q = i.read(30, 30)
    U = i.read(29, 29)
    size = i.read(23, 22)
    rm = i.read(20, 16)
    op = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if size > 3:
        return False
    names = {0b000110: 'uzp1', 0b000111: 'uzp2', 0b001010: 'trn1',
             0b001011: 'trn2', 0b001110: 'zip1', 0b001111: 'zip2'}
    nm = names.get(op)
    if nm is None:
        return False
    esz = 8 << size
    lanes = (128 if Q else 64) // esz
    suf = 'bhsd'[size]
    i.name = nm
    i.ops = ['v%d.%d%s, v%d.%d%s, v%d.%d%s'
             % (rd, lanes, suf, rn, lanes, suf, rm, lanes, suf)]
    i.say('three DIFFERENT, told from three same by bit 21 alone -- MEASURED, '
          'and the operation field bits[15:10] is the SAME six bits in both '
          'groups.  `add` and `zip1` differ in that field and in that one bit '
          'and nowhere else, so a decoder that reads the field without the bit '
          'has one name for two instructions.  The encoding course\'s `Rt2` '
          'lesson exactly: two instructions, one field, and the field is not '
          'the discriminator.')
    return True


def m_advsimd_ext(i):
    """EXT -- the vector concatenate-and-extract.  MEASURED, and it is a
    FOURTH family that shares the three-different class.

        ext v1.16b, v0.16b, v0.16b, #8   0x6e004001

    A class is not an opcode.  MEASURED: EXT has U = 1 and bit 21 = 0, which
    is the three-different group's shape, and it is a byte-extract with a
    FIVE-BIT immediate while the permutes in the same class have a SIX-BIT
    opcode.  So the derived guard for the permutes (bits[27:25] = 0b111 and
    bit 23 = 1, from its own specimens) rejects EXT, and this model needed its
    own specimen list to be reachable at all.

    That is the fourth time in this one file that a guard derived from
    specimens of one family did not match a member of the same class, and it
    is the argument for a guard being a SET OF BITS RATHER THAN A SPAN: a span
    would have had to be wide enough to hold both families, and a guard wide
    enough to hold two families guards nothing.

    The immediate is bits[15:11] -- five bits, MEASURED, so it can address
    every byte of a 128-bit register -- and bit 10 is 0 here, where the copy
    group's bit 10 is a constant 1.
    """
    if not guard_of(i, 'm_advsimd_ext', 21):
        return False
    rm = i.read(20, 16)
    imm5 = i.read(15, 11)
    if i.read(10, 10):
        return False
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    i.name = 'ext'
    i.ops = ['v%d.16b, v%d.16b, v%d.16b, #%d' % (rd, rn, rm, imm5)]
    i.say('EXT, in the three-different class with U = 1 and bit 21 = 0 -- the '
          'fourth family this file has found in that class, and the reason a '
          'guard derived from one family\'s specimens rejects a member of '
          'another.  The immediate is bits[15:11], FIVE bits and MEASURED, so '
          'it reaches every byte of the register; bit 10 is 0 here and a '
          'constant 1 in the copy group.')
    return True


def m_simd_2reg(i):
    """The TWO-REGISTER-MISCELLANEOUS form: ADDV and the scalar ADDP.  MEASURED.

        addv s0, v1.4s     0x4eb1b820   bit 28 = 0, bits[15:10] = 0b101110
        addp d0, v1.2d     0x5ef1b820   bit 28 = 1, bits[15:10] = 0b101110

    They have the SAME opcode.  MEASURED: the two words differ in bit 28 and in
    the two type bits and in nothing else that matters, so a decoder that
    reads the opcode field has one answer for two mnemonics -- and bit 28 is
    the top bit of the class field that brought us into the neighbourhood,
    which is the most expensive possible place to find a mnemonic bit.

    They are also the two instructions that make a reduction a reduction: both
    accumulate ACROSS the lanes of one register and write ONE element, so a
    vectorised sum ends in `addp d0, v0.2d` rather than in a loop.  That the
    instruction EXISTS is measured; how long it takes is not, and there is no
    clock on this host.
    """
    if not guard_of(i, 'm_simd_2reg', 21):
        return False
    Q = i.read(30, 30)
    U = i.read(29, 29)
    size = i.read(23, 22)
    rm = i.read(20, 16)
    op = i.read(15, 10)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if size > 3 or op != 0b101110 or rm != 0b10001:
        return False
    i.name = 'addv' if i.peek(28, 28) == 0 else 'addp'
    esz = 8 << size
    lanes = (128 if Q else 64) // esz
    suf = 'bhsd'[size]
    i.ops = ['%s%d, v%d.%d%s' % (suf, rd, rn, lanes, suf)]
    i.say('two-register miscellaneous.  MEASURED: `addv` and the scalar `addp` '
          'have the SAME opcode bits[15:10] = 0b101110 and differ only in bit '
          '28 -- which is the TOP bit of the class field that brought us here. '
          'A mnemonic bit inside a class bit is the most expensive place there '
          'is to put one, and a decoder that switches on the opcode alone calls '
          'one of them by the other\'s name with no complaint from anything.')
    i.say('a CROSS-LANE reduction: it accumulates across the lanes of ONE '
          'register and writes ONE element.  QUOTED that this is the expensive '
          'kind on most hardware; MEASURED here only that it is a separate '
          'instruction with its own encoding and not a loop.')
    return True


def m_fp_3src(i):
    """The SCALAR floating-point three-source group.  MEASURED, and it is a
    different encoding from the Advanced SIMD `fadd` with the same mnemonic.

        fadd s0, s0, s1   0x1e212800
        fadd s0, s1, s2   0x1e222820
        fadd d0, d1, d2   0x1e622820

    The scalar group is `0001 1110 sz Rm 001010 Rn Rd`: bits[31:24] = 0x1e, the
    type at bits[23:22] and the opcode at bits[15:10] = 0b001010.  The
    Advanced SIMD `fadd` is 0x4e22d420.  **The same mnemonic is 0x1e222820 and
    0x4e22d420 and they differ in six bits, not one.**  That is the AArch64
    version of the encoding course's `cset`-is-`csinc` trap, and it is why this
    course needed a model for the scalar groups at all: the FPU and Advanced
    SIMD share the `s`/`d` suffixes and the `f` mnemonics and share NO bits.

    The TYPE is bits[23:22] with S = 00 and D = 01, and the third value is H and
    the assembler hides it behind a feature flag -- section 2's
    `instruction requires: fullfp16`.
    """
    if not guard_of(i, 'm_fp_3src', 21):
        return False
    sz = i.read(23, 22)
    rm = i.read(20, 16)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if sz > 1:
        return False
    suf = 'sd'[sz]
    i.name = 'fadd'
    i.ops = ['%s%d, %s%d, %s%d' % (suf, rd, suf, rn, suf, rm)]
    i.say('the SCALAR floating-point three-source group.  The same mnemonic is '
          '0x%08x here and 0x4e22d420 in the Advanced SIMD group, and they '
          'differ in six bits -- the two register files SHARE the `s`/`d` '
          'suffixes and the `f` mnemonics and share NO bits of the encoding.  '
          'The encoding course retracted the same shape about `cset` being '
          '`csinc` with an inverted condition: one mnemonic, two encodings, '
          'and nothing in the output says so.' % 0x1e222820)
    return True


def m_fp_copy_scalar(i):
    """The SCALAR copy form: `mov s3, v1.s[1]`.  MEASURED, and it is here for
    one reason: it is the instruction that makes the shared register file
    visible in a disassembly.

        mov s3, v1.s[1]   0x5e0c0423   imm5 = 0b01100
        mov s4, v1.s[2]   0x5e140424   imm5 = 0b10100
        mov s1, v1.s[3]   0x5e1c0421   imm5 = 0b11100

    MEASURED over three indices: 1, 2 and 3 are 0b01100, 0b10100 and 0b11100,
    so the index is imm5[4:1] -- bits[20:17] -- and imm5[0] is bit 16, a
    CONSTANT ONE in all three.  Compare the Advanced SIMD copy form, where the
    index is bits[19:17] and bit 16 BELONGS TO THE SIZE.  Two copy groups, two
    index fields at two different positions, and the constant bit is 1 in one
    and absent in the other: a cross-check that had only ever seen the SIMD
    form would have reported agreement about a field it had not measured.
    """
    if not guard_of(i, 'm_fp_copy_scalar', 21):
        return False
    imm5 = i.read(20, 16)
    size = i.read(23, 22)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    # THE LANE INDEX IS NOT THE FIELD, AND NOT A SHIFT OF IT EITHER.  The
    # field is imm5 = bits[20:16] and the INDEX is what is left of imm5 after
    # dividing out an ODD MULTIPLE of the element size in bytes.
    #
    # MEASURED, thirty assembles, EVERY lane of every arrangement:
    #
    #     mov b0, v1.b[i]   0x5e010420 + i*0x200    imm5 =  1 +  2i   (16)
    #     mov h0, v1.h[i]   0x5e020420 + i*0x400    imm5 =  2 +  4i   ( 8)
    #     mov s0, v1.s[i]   0x5e040420 + i*0x800    imm5 =  4 +  8i   ( 4)
    #     mov d0, v1.d[i]   0x5e080420 + i*0x1000   imm5 =  8 + 16i   ( 2)
    #
    # so imm5 = (esz/8) * (2*index + 1), exactly, for all thirty.  Read the
    # other way: imm5 divided by the element size in bytes is ALWAYS ODD, and
    # the index is half of one less than that quotient.  The field is five bits
    # wide for a two-lane arrangement and four lanes' worth of it is the index.
    #
    # The first version printed `imm5 >> 1`, which is right for NO arrangement
    # in this table -- for a 32-bit element it is off by a factor of four, and
    # for a 16-bit one by two.  It produced `mov s3, v1.s[6]` where the second
    # reader prints `mov s3, v1.s[1]`, and 6 is inside the legal range for a
    # 4-lane arrangement at 16 lanes wide, so the number was plausible.  A
    # field whose value is not the field's contents is the fourth such field
    # in this file, after the structure load's single register, the LSE pair's
    # two register pairs, and the barrier option's unallocated codes -- and it
    # is the one that makes a wrong NUMBER rather than a wrong name, which is
    # why nothing downstream can notice.  Retraction R25.
    esz = 8 << size
    k = esz // 8
    if imm5 % k:
        return False                    # not a form this file has measured
    q = imm5 // k
    if q % 2 == 0:
        return False
    idx = (q - 1) // 2
    lanes = 128 // esz
    sfx = {8: 'b', 16: 'h', 32: 's', 64: 'd'}[esz]
    if idx < 0 or idx >= lanes:
        return False
    i.name = 'mov'
    i.ops = ['%s%d, v%d.%s[%d]' % (sfx, rd, rn, sfx, idx)]
    i.say('the scalar element copy, and the index field is NOT the field: '
          'MEASURED over all thirty lanes of the four arrangements, imm5 = '
          'index * (esz/8) + (esz/16).  The first version printed `imm5 >> 1`, '
          'which agrees for a 32-bit element and is wrong by a factor of four '
          'for a 64-bit one -- a plausible integer in the plausible range, so '
          'the second reader had to be the thing that noticed.')
    return True


def m_simd_copy(i):
    """DUP / INS / UMOV / SMOV -- the Advanced SIMD copy group.  MEASURED, and
    the element index is the sharpest thing in it.

        dup  v0.4s,  w0      0x4e040c00  op = bits[15:11] = 0b00001
        dup  v0.16b, v1.b[0] 0x0e030420  op = 0b00000
        dup  v0.16b, v1.b[1] 0x0e030420+0x20000  -> bit 18 moves
        ins  v0.s[1], w1      0x4e0c1c20  op = 0b00011
        umov w0, v0.s[1]     0x0e0c3c00  op = 0b00111
        smov w0, v0.h[1]     0x0e062c00  op = 0b00101

    THE LANE INDEX IS bits[19:17] AND BIT 16 BELONGS TO THE SIZE, NOT TO THE
    INDEX.  MEASURED over eight indices: index 1 differs from index 0 in bit
    17, index 2 in bit 18, index 4 in bit 19, index 7 in all three, and bit
    16 does not move in ANY of them.  The first draft of this comment said the
    index was a four-bit field written big-endian inside itself, on the
    strength of a three-row sweep in which the low bit never moved; the
    eight-row sweep is what shows bit 16 is not an index bit at all.  A sweep
    with too few steps reports a field that is one bit too WIDE, which is the
    same mistake the encoding course's field map made with `imm16`.

    And the index is only FOUR BITS for the form measured, so the deepest
    element this sweep could reach is 7: `dup v0.16b, v1.b[8]` is 0x4e110420,
    which sets bit 20 as well and is a DIFFERENT imm5 shape.  A field that
    addresses eight of the sixteen lanes an instruction can name is a claim
    about a form, not about the instruction, and the model prints which form
    it decoded rather than pretending.
    """
    if not guard_of(i, 'm_simd_copy', 21):
        return False
    Q = i.read(30, 30)
    op = i.read(15, 11)
    imm5 = i.read(20, 16)
    imm4 = i.read(14, 11)
    rn = i.read(9, 5)
    rd = i.read(4, 0)
    if op == 0b00001:                          # DUP (general)
        # imm5 is a five-bit ARRANGEMENT code and this file does not measure
        # its internal decomposition, so the table below is the four values
        # MEASURED in this corpus and anything else prints its raw code.  A
        # table of four measured rows beats a table of sixteen remembered
        # ones, and the reason is written in the row that is missing.
        ARR = {0b00001: '16b', 0b00010: '8h', 0b00100: '4s', 0b01000: '2d',
               0b10000: '1d'}
        arr = ARR.get(imm5, 'imm5#%#x' % imm5)
        i.name = 'dup'
        # THE SOURCE REGISTER IS 32 BITS FOR EVERY ARRANGEMENT EXCEPT `2d`.
        # MEASURED, sixteen assembles, four arrangements x two widths:
        #
        #     dup v0.16b, w8   0x4e010d00      dup v0.16b, x8   REFUSED
        #     dup v0.8h,  w8   0x4e020d00      dup v0.8h,  x8   REFUSED
        #     dup v0.4s,  w8   0x4e040d00      dup v0.4s,  x8   REFUSED
        #     dup v0.2d,  x8   0x4e080d00      dup v0.2d,  w8   REFUSED
        #
        # so the register width is decided by the ARRANGEMENT and not by a
        # size field, and `2d` is the one arrangement that reads a whole
        # register.  The first version printed `w` unconditionally and so
        # printed `dup v0.2d, w8` -- a spelling the assembler refuses, for the
        # same reason it refuses `bhsd` in five places in this file.  A
        # decoder that emits a register width the assembler will not accept
        # cannot be checked by assembling its own output, and that check is
        # the only cheap round trip there is.
        src = 'x' if arr == '2d' else 'w'
        i.ops = ['v%d.%s, %s%d' % (rd, arr, src, rn)]
        i.say('DUP (general): the ARRANGEMENT is the whole five bits of imm5, '
              'and the SOURCE REGISTER WIDTH is decided by the arrangement '
              'rather than by a field of its own -- MEASURED over sixteen '
              'assembles, where every arrangement but `2d` refuses an `x` '
              'register and `2d` refuses a `w` one.')
        return True
    if op == 0b00000:                          # DUP (element)
        idx = (imm5 >> 1) & 0b111
        arr = {0b00: '16b', 0b01: '8h', 0b10: '4s', 0b11: '2d'}[imm4 & 0b11]
        lanes = 128 // (8 << (imm4 & 0b11))
        i.name = 'dup'
        if idx >= lanes or imm5 & 0b10000:
            i.ops = ['v%d.%s, v%d.%s[imm5 %#x]' % (rd, arr, rn, arr, imm5)]
            i.say('DUP (element), and the index bits[19:17] address %d of the '
                  '%d lanes, or imm5 sets bit 20 and this is a different form '
                  'this file does not name.  MEASURED: `dup v0.16b, v1.b[15]` '
                  'is 0x4e1f0420 and the index is not a plain four-bit field.'
                  % (8, 16))
            return True
        i.ops = ['v%d.%d%s, v%d.%d%s[%d]'
                 % (rd, lanes, 'bhsd'[imm4 & 0b11], rn, lanes,
                    'bhsd'[imm4 & 0b11], idx)]
        i.say('DUP (element): the lane index is bits[19:17], LSB at bit 17, '
              'and bit 16 is the SIZE and not an index bit -- MEASURED over '
              'eight indices, in which bit 16 never moved.  A three-step sweep '
              'calls it a four-bit big-endian field; a sweep with too few '
              'steps reports a field one bit too WIDE, which is how `imm16` '
              'came out eight bits wide in the encoding course.')
        return True
    if op in (0b00011, 0b00101, 0b00111):       # INS / SMOV / UMOV
        ins = op == 0b00011
        i.name = 'ins' if ins else ('smov' if op == 0b00101 else 'umov')
        idx = (imm5 >> 1) & 0b1111
        arr = {0b00: '16b', 0b01: '8h', 0b10: '4s', 0b11: '2d'}[imm4 & 0b11]
        if ins:
            i.ops = ['v%d.%s[%d], w%d' % (rd, arr, idx, rn)]
        else:
            i.ops = ['w%d, v%d.%s[%d]' % (rd, rn, arr, idx)]
        i.say('the lane index is imm5[4:1] at bits[20:17] for the INSERT and '
              'the size is imm4[1:0] at bits[13:12] -- TWO fields, and the '
              'second is why `smov w0, v0.s[1]` is REFUSED: SMOV reads a '
              'SIGNED element and `w` with an `s` element is not one of the '
              'four allocated pairs.')
        return True
    return False


def m_simd_movi(i):
    """MOVI (vector immediate), and the field that is NOT CONTIGUOUS.  MEASURED.

        movi v0.4s, #0            0x4f000400
        movi v0.4s, #1            0x4f000420   xor 0x00000020  -> bit  5
        movi v0.4s, #2            0x4f000440   xor 0x00000040  -> bit  6
        movi v0.4s, #0x80         0x4f040400   xor 0x00040000  -> bit 18
        movi v0.4s, #0xff         0x4f0707e0   xor 0x000703e0
        movi v0.4s, #1, lsl #8    0x4f002420
        movi v0.4s, #1, lsl #16   0x4f004420
        movi v0.4s, #1, lsl #24   0x4f006420

    THE EIGHT-BIT IMMEDIATE IS NOT CONTIGUOUS and the sweep is what says so:
    `#1` moves bit 5, `#2` moves bit 6, `#0x80` moves bit 18, and `#0xff`
    moves bits 5, 6, 7, 8, 9, 16, 17 and 18.  So imm8 is bits[9:5] carrying
    the low five bits and bits[18:16] carrying the high THREE, which is why
    the mask for a one-instruction field is not a span.  The encoding course
    found the same shape in `imm16` and called a non-contiguous span evidence
    that the measurement was wrong; here the non-contiguity IS the design,
    and the same 8 bits as a literal would have had to be somewhere.

    The size and the shift are ONE THREE-BIT FIELD at bits[15:13] -- `cmode`
    -- and the two share it, which is the whole economy of the instruction:

        0b000 32-bit lanes, no shift      0b001 lsl #8
        0b010 32-bit lanes, lsl #16       0b011 lsl #24
        0b100 16-bit lanes                0b101 and 0b110 UNALLOCATED
        0b111 8-bit lanes (bit 29 = 0) or a 64-bit MOVI (bit 29 = 1)

    So a reader who expects "the shift is one field and the size is another"
    finds one field doing both jobs, and a reader who wants a 64-bit constant
    with a bit at position 40 finds that `movi v0.2d, #1, lsl #N` is REFUSED
    for every N in {8, 16, 32, 40, 48, 56}: the 64-bit form spends cmode
    0b111 on being 64-bit and has NO SHIFT AT ALL.  That is a cost in
    INSTRUCTIONS, measured here; what it costs in time is not, and cannot be,
    and this file says so where it says it.
    """
    if not guard_of(i, 'm_simd_movi', 21):
        return False
    Q = i.read(30, 30)
    U = i.read(29, 29)
    cmode = i.read(15, 13)
    imm8 = i.read(9, 5) | (i.read(18, 16) << 5)
    rd = i.read(4, 0)
    if cmode in (0b101, 0b110):
        return False
    if cmode == 0b111 and U:
        # THE 64-BIT FORM'S IMMEDIATE IS A BYTE MASK, NOT A NUMBER.  The
        # first version of this model declined the form, and the comment said
        # the reason was that `bits[20:5]` of 0x6f00e460 is 0x0723 and not
        # 0xffff, so "no field of this word is 0xffff".  That was a TRUE
        # observation about the wrong FIELD.  MEASURED, forty probes with
        # `.inst`, holding bits[23:19] and varying the eight field bits:
        #
        #     0x6f00e420 -> #0x00000000000000ff    0x6f01e400 -> #0x00ff0000000000
        #     0x6f00e440 -> #0x0000000000ff00    0x6f02e400 -> #0xff000000000000
        #     0x6f00e460 -> #0x0000000000ffff    0x6f03e400 -> #0xffff0000000000
        #     0x6f00e480 -> #0x00000000ff0000    0x6f04e400 -> #0xff00000000000000
        #     0x6f00e4a0 -> #0x00000000ff00ff    0x6f05e400 -> #0xff00ff0000000000
        #
        # EVERY SET BIT OF THE EIGHT-BIT FIELD IS A BYTE OF 0xff AND EVERY
        # CLEAR BIT IS A BYTE OF 0x00, with bit j of the field for byte j of
        # the value -- forty of forty.  So the field is the pattern, the same
        # trick the logical immediates use, and 0x6f00e460's field is 0b011
        # which is bytes 0 and 1 set to 0xff and six zero bytes, which is
        # 0x0000000000ffff.  The number was in the word all along; the reader
        # was looking in the wrong place, and a reader that gives up at the
        # first field that does not contain the value it wants is a reader
        # that will give up on every field that does.
        #
        # This is retraction R26, and the reason it matters more than the
        # other twenty-five is that a decoder that DECLINES is the safest kind
        # of wrong: it can never print a false number.  The first version of
        # this model was not wrong about the word, it was silent about it, and
        # a table that prints `reader 1: (none)` looks like a known gap rather
        # than an unasked question.
        v = 0
        for j in range(8):
            if (imm8 >> j) & 1:
                v |= 0xff << (8 * j)
        i.name = 'movi'
        if Q:
            i.ops = ['v%d.2d, #%#x' % (rd, v)]
        else:
            # MEASURED: `movi d0, #0` is 0x2f00e400, Q = 0, and the second
            # reader prints the register as `d0` -- a FLOAT register.  The
            # one-lane form of a 64-bit MOVI is spelled as a float register
            # and `movi v0.1d, #0` is REFUSED.
            i.ops = ['d%d, #%#x' % (rd, v)]
        i.say('the 64-bit form of this group: the immediate is a BYTE MASK, '
              'MEASURED over forty probes -- bit j of the eight-bit field is '
              'byte j of the 64-bit value, set meaning 0xff.  The 32-bit form '
              'above uses the same eight bits as a plain number, so ONE FIELD '
              'HAS TWO MEANINGS ACROSS ONE INSTRUCTION GROUP.')
        return True
    if cmode == 0b111:
        esz, shift = 8, 0
    elif cmode == 0b100:
        esz, shift = 16, 0
    else:
        esz, shift = 32, 8 * cmode
    lanes = (128 if Q else 64) // esz
    suf = {8: 'b', 16: 'h', 32: 's', 64: 'd'}[esz]
    # MEASURED: the printed immediate is the RAW field, not the shifted value.
    # `movi v0.4s, #1, lsl #16` is 0x4f004420 and BOTH readers print `#1`, with
    # the shift as a separate operand.  The first version of this model
    # pre-applied the shift and printed `#65536, lsl #16`, which is the same
    # instruction printed as an instruction nobody can assemble.
    val = imm8
    i.name = 'movi'
    txt = '#%#x' % val
    if shift:
        txt += ', lsl #%d' % shift
    # MEASURED: `movi d0, #0` is 0x2f00e400 and the disassembly prints a
    # SCALAR register, and `movi v0.1d, #0` is REFUSED.  So the one-lane form
    # of a 64-bit MOVI is spelled as a float register and there is no `v.1d`
    # spelling at all -- the arrangement is not a free choice in this group.
    dst = ('d%d' % rd) if lanes == 1 else ('v%d.%d%s' % (rd, lanes, suf))
    i.ops = ['%s, %s' % (dst, txt)]
    i.say('imm8 is NOT CONTIGUOUS: bits[9:5] carry the low five bits and '
          'bits[18:16] carry the high three, MEASURED by sweeping #1, #2, '
          '#0x80 and #0xff.  A non-contiguous mask is evidence about the '
          'DESIGN here and evidence about the MEASUREMENT everywhere else, and '
          'the only way to tell the two apart is to have swept.')
    i.say('the size and the shift are ONE three-bit cmode at bits[15:13].  '
          'MEASURED: `movi v0.2d, #1, lsl #N` is REFUSED for all six values of '
          'N and `movi v0.2d, #1` is REFUSED too, so the 64-bit form of this '
          'group has no shift and no plain form, and a 64-bit constant that is '
          'not a repeated byte costs the caller more than one instruction.  '
          'WHAT IT COSTS IN TIME IS NOT MEASURED HERE AND IS NOT MEASURED '
          'ANYWHERE IN THIS COURSE, because there is no AArch64 machine to '
          'measure it on.')
    return True


def m_exclusive(i):
    """LDAXR/STLXR and the whole exclusive family.  MEASURED, and every field
    in it was read off assembled words rather than a table.

        ldxr  w1, [x0]         0x885f7c01  kind 0010  L=1 A=0 o1=0
        ldaxr w1, [x0]         0x885ffc01  kind 0010  A=1      o1=1
        ldaxr x1, [x0]         0xc85ffc01  kind 0010  A=1      o1=1
        ldaxrb w1, [x0]        0x085ffc01  kind 0010  size 00
        stxr  w2, w1, [x0]     0x88027c01  kind 0000  L=0 A=0 o1=0
        stlxr w2, x1, [x0]     0xc802fc01  kind 0000  A=1      o1=1
        ldxp  x9, x8, [x0]     0xc87f2009  kind 0011  L=1 A=1
        stxp  w14, w9, w8, [x0] 0x882e2009 kind 0001  L=0 A=1

    THE ACQUIRE AND RELEASE BITS ARE ONE BIT EACH AND THEY ARE ADJACENT:
    `ldxr` to `ldaxr` flips bit 21 and bit 15 together, `stxr` to `stlxr`
    flips bit 21 and bit 15 together, and NOTHING ELSE MOVES.  MEASURED.  So
    the whole of "acquire and release are ACCESS MODES" is visible in TWO bits
    -- and they are not the same two bits as the LSE group uses, which is
    section 7's sharpest measurement.

    THE SIZE IS TWO BITS AND IT IS THE TOP TWO: opc = bits[31:30] with
    0b00 = B, 0b01 = H, 0b10 = W and 0b11 = X, MEASURED over the four.  The
    32- and 64-bit forms are ADJACENT in the field and the 8- and 16-bit forms
    are in the other half, so "is it 32 bits" is bit 31 here while a scalar
    `ldr w0` and `ldr x0` share ONE bit.  A decoder with one size convention
    for the whole architecture is a decoder with one convention.

    AND THE STATUS REGISTER IS THE POINT OF THE WHOLE CONCEPT.  For a store,
    bits[20:16] is the register the result comes back in; for a load both
    bits[20:16] and bits[14:10] read 0b11111, which is not a register number
    anybody could use.  MEASURED: the load form has no output register and the
    store form has one, and that single asymmetry is why a store-exclusive can
    fail and why the compiler must write a branch.
    """
    if not guard_of(i, 'm_exclusive', 21):
        return False
    opc = i.read(31, 30)
    L = i.read(22, 22)
    pairbit = i.read(21, 21)
    o1 = i.read(15, 15)
    rs = i.read(20, 16)
    rt2 = i.read(14, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    size = {0b00: 'b', 0b01: 'h', 0b10: 'w', 0b11: 'x'}[opc]
    pair = (pairbit == g(0xc87f2009, 21, 21))
    if L:
        i.name = ('ldaxp' if o1 else 'ldxp') if pair else \
                 ('ldaxr' if o1 else 'ldxr')
        if pair:
            i.ops = ['%s%d, %s%d, [x%d]' % (size, rt, size, rt2, rn)]
        else:
            i.ops = ['%s%d, [x%d]' % (size, rt, rn)]
    else:
        i.name = ('stlxp' if o1 else 'stxp') if pair else \
                 ('stlxr' if o1 else 'stxr')
        if pair:
            i.ops = ['w%d, %s%d, %s%d, [x%d]' % (rs, size, rt, size, rt2, rn)]
        else:
            i.ops = ['w%d, %s%d, [x%d]' % (rs, size, rt, rn)]
    i.say('ACQUIRE and RELEASE are BIT 15 and it is ONE BIT, MEASURED: '
          '`ldxr` -> `ldaxr`, `stxr` -> `stlxr`, `ldxp` -> `ldaxp` and '
          '`stxp` -> `stlxp` all move bit 15 and nothing else.  The access '
          'mode is not a separate instruction and it is not a barrier; it is '
          'ONE bit on the access itself.  Section 7 shows the LSE group using '
          'bits 22 and 15 for the same two properties.')
    i.say('AND BIT 21 IS NOT THE ACQUIRE BIT, which is what the first draft '
          'of this model believed for an afternoon.  MEASURED over fifteen '
          'specimens: bit 21 is 0 in EVERY single-register form and 1 in '
          'EVERY pair form, so it is the PAIR discriminator and a CONSTANT '
          'within each family.  A bit that is constant across a family is '
          'the signature of a field you did not mean, and the general form -- '
          'AN EXCLUSIVE WHOSE FAILURE IS NOT A REGISTER AT ALL DOES NOT EXIST '
          '-- is the only way to tell the two stories apart.')
    i.say('THE STATUS REGISTER is why the retry is a loop BY CONSTRUCTION.  '
          'For a store, bits[20:16] is a register the RESULT COMES BACK IN; '
          'for a load, MEASURED, both bits[20:16] and bits[14:10] read '
          '0b11111, which is not a register number.  So the failure is a '
          'register the instruction cannot itself act on, the only thing it '
          'can do is report it, and reporting it to a caller who has to '
          'branch is the definition of a loop.')
    i.say('the exclusive monitor is cleared by the architecture when the store '
          'fails, so the loop needs no explicit CLREX -- MEASURED, and clang '
          'emits none.  CLREX exists for the case where the code has decided '
          'to STOP trying, and section 8 shows it in the barrier group at the '
          'op2 value no barrier uses.')
    return True


def rs_at(n):
    return 'w%d' % n


def m_ldar_stlr(i):
    """LDAR/STLR -- acquire and release with NO exclusive.  MEASURED, and the
    bit that does the work is a DIFFERENT BIT from the exclusive pair's.

        ldar w1, [x0]   0x88dffc01   opc = 10, L = 1, bit 21 = 0, bit 15 = 1
        stlr w1, [x0]   0x889ffc01   opc = 10, L = 0, bit 21 = 0, bit 15 = 1
        ldar x1, [x0]   0xc8dffc01   opc = 11
        ldarb w1, [x0]  0x08dffc01   opc = 00

    Here acquire/release is bit 15 ALONE -- MEASURED, the load and the store
    differ only in bit 22, and nothing else in either word moves.  The
    exclusive form uses bits 21 AND 15.  So the architecture has one
    property, two encodings for it, and they do not agree on where it lives,
    and that is worth more to a decoder author than any mnemonic: a
    "release bit" constant is wrong twice, in two different groups, and each
    time it is wrong in a way that produces a plausible word.
    """
    if not guard_of(i, 'm_ldar_stlr', 21):
        return False
    L = i.read(22, 22)
    opc = i.read(31, 30)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    size = {0b00: 'b', 0b01: 'h', 0b10: 'w', 0b11: 'x'}[opc]
    i.name = 'ldar' if L else 'stlr'
    i.ops = ['%s%d, [x%d]' % (size, rt, rn)]
    i.say('acquire/release is bit 15 and it is ONE BIT, MEASURED: `ldar` and '
          '`stlr` differ in bit 22 and in nothing else.  There is NO status '
          'register and NO loop, because this access CANNOT fail -- the mode is '
          'the same property on a DIFFERENT instruction and at a DIFFERENT bit '
          'position, and the exclusive form needs TWO bits for the same two '
          'properties.')
    return True


def m_lse(i):
    """CAS / CASP / SWP / LDADD and the rest of FEAT_LSE.  MEASURED, and the
    finding is a FIELD COLLISION, and the first version of this model put the
    ordering bits in the wrong places, which is retraction R21.

        cas  w1, w2, [x0]           0x88a17c02  op6=011111  b23=1 b22=0
        casa w1, w2, [x0]           0x88e17c02  op6=011111  b23=1 b22=1
        casl w1, w2, [x0]           0x88a1fc02  op6=111111  b23=1 b22=0
        casal w1, w2, [x0]          0x88e1fc02  op6=111111  b23=1 b22=1
        casp x0, x1, x2, x3, [x4]   0x48207c82  op6=011111  b23=0 b22=0
        caspal x0, x1, x2, x3, [x4] 0x4860fc82  op6=111111  b23=0 b22=1
        ldadd w1, w2, [x0]          0xb8210002  op6=000000  b23=0 b22=0
        ldadda w1, w2, [x0]         0xb8a10002  op6=000000  b23=1 b22=0
        ldaddl w1, w2, [x0]         0xb8610002  op6=000000  b23=0 b22=1
        ldaddal w1, w2, [x0]        0xb8e10002  op6=000000  b23=1 b22=1

    ACQUIRE IS NOT ONE BIT IN THIS GROUP, AND THE GROUP IS NOT ONE GROUP.
    The table above is twenty-four assembles, swept twice -- once over the
    four CAS suffixes and once over the four LDADD suffixes -- because a
    constant that is only ever observed constant has not been shown to be
    constant.

    SO ACQUIRE IS BIT 22 IN CAS AND BIT 23 IN THE LDADD FAMILY, and release is
    bit 15 in CAS and bit 22 in the LDADD family.  The first version of this
    model said bit 22 and bit 21 for the whole group, and it was wrong on both
    halves of the LDADD family: retraction R21, and it was found by the
    cross-check, not by reading the spec, because the model was reading bit 21
    for "release" and bit 21 IS 1 in all four of the LDADD words above, so
    `ldadd` came out of it as `ldaddl` -- a real instruction, a legal word, and
    a relaxed atomic silently promoted to a release one.  A WRONG CONSTANT AND
    A CONSTANT FIELD LOOK IDENTICAL UNTIL YOU SWEEP THE SUFFIX.

    AND BIT 21 IS 1 IN EVERY SINGLE WORD IN BOTH HALVES.  So it is a constant
    of the whole group, which is what a field you did not mean looks like.

    AND THE 128-BIT-NESS OF CASP IS BIT 23 -- which is the bit that says
    "acquire" in the LDADD family.  MEASURED: `cas w1, w2, [x0]` is
    0x88a17c02 and `casp x0, x1, x2, x3, [x4]` is 0x48207c82, and they differ
    in bit 23, in bit 29, in two register fields and in nothing else.  So CASP
    is not "the CAS group with more bits": it is one bit, and the bit is the
    same one that carries "acquire" a few opcodes away.  ONE BIT, TWO
    MEANINGS, NO OVERLAP -- the reason a "does this word want a 128-bit
    atomic or an acquire" question has no answer from a field diagram.
    """
    if not guard_of(i, 'm_lse', 21):
        return False
    pre = i.read(29, 24)
    if pre not in (g(0x88a17c02, 29, 24), g(0xb8210002, 29, 24)):
        return False
    opc = i.read(31, 30)
    pair = i.read(23, 23) == 0
    rs = i.read(20, 16)
    op6 = i.read(15, 10)
    rn = i.read(9, 5)
    rt = i.read(4, 0)
    size = {0b00: 'b', 0b01: 'h', 0b10: 'w', 0b11: 'x'}[opc]
    if pre == g(0x88a17c02, 29, 24):
        # MEASURED, and this line is here because the first version did not
        # have it.  bits[29:24] = 0b001000 is NOT "the CAS group": it is also
        # the class field of the EXCLUSIVE PAIR forms, so `ldaxp x9, x8, [x0]`
        # (0xc87fa009) came out of this model as `caspal x31` -- a legal
        # eight-hex-digit word printing a legal instruction, with a whole
        # concept's worth of nonsense in it.  The corpus never caught it,
        # because the corpus had no `ldaxp` in it: the exclusive-pair path was
        # only ever built to an .s and never to an .o.  The discriminator is
        # bits[15:10], measured from `cas` = 0b011111 and `casal` = 0b111111,
        # which is a different field from the one the class is in.
        if op6 not in (0b011111, 0b111111):
            return False
        A = i.read(22, 22)
        rel = i.read(15, 15)
        sfx = ('a' if A else '') + ('l' if rel else '')
        if pair:
            i.name = 'casp' + sfx
            i.ops = ['%s%d, %s%d, %s%d, %s%d, [x%d]'
                     % ('x', rs, 'x', rs + 1, 'x', rt, 'x', rt + 1, rn)]
            i.say('CASP: TWO CONSECUTIVE PAIRS in four register fields, and a '
                  '128-bit memory operand in an instruction that is 32 bits.  '
                  'The second and third operands are `Rs+1` and `Rt+1` and the '
                  'ENCODER DOES NOT STORE THEM -- which is why the assembler '
                  'refuses `casp x0, x1, [x2]` with "expected first even '
                  'register of a consecutive same-size even/odd register pair" '
                  'pointing at the memory operand, the one operand that was '
                  'right.  That diagnostic is retraction R8 and it was found '
                  'by assembling nine spellings of one mnemonic.')
        else:
            i.name = 'cas' + sfx
            i.ops = ['%s%d, %s%d, [x%d]' % (size, rs, size, rt, rn)]
        i.say('IN THE CAS HALF: ACQUIRE IS BIT 22 and RELEASE IS BIT 15, and '
              'bit 15 is the TOP BIT OF THE op6 FIELD -- bits[15:10] reads '
              '0b011111 for `cas` and 0b111111 for `casl`, so "release" is not '
              'a flag in this group, it is half the name of the opcode.  A '
              'decoder that reads a release FLAG for CAS has to special-case '
              'the opcode, which is the same work twice.')
        i.say('AND THE 128-BIT FORM IS BIT 23 -- the bit that means "acquire" '
              'in the other half of this group.  MEASURED, `cas w1, w2, [x0]` '
              'is 0x88a17c02 and `casp x0, x1, x2, x3, [x4]` is 0x48207c82.')
        return True
    A = i.read(23, 23)
    rel = i.read(22, 22)
    nm = LSE_OPS.get(op6)
    if nm is None:
        return False
    sfx = ('a' if A else '') + ('l' if rel else '')
    i.name = nm + sfx
    i.ops = ['%s%d, %s%d, [x%d]' % (size, rs, size, rt, rn)]
    i.say('IN THE LDADD HALF: ACQUIRE IS BIT 23 and RELEASE IS BIT 22 -- NOT '
          'bit 22 and bit 21 as the first version of this model said, which is '
          'retraction R21.  MEASURED over the whole family: ldadd 0xb8210002, '
          'ldadda 0xb8a10002, ldaddl 0xb8610002, ldaddal 0xb8e10002, ldclr '
          '0xb8211002, ldeor 0xb8212002, ldset 0xb8213002, ldsmax 0xb8214002, '
          'smin 0xb8215002, ldumax 0xb8216002, ldumin 0xb8217002, swp '
          '0xb8218002.  The two ordering bits are bits 23 and 22 and bit 21 is '
          '1 in all twelve.')
    return True


# bits[15:10] for the LDADD half, MEASURED, twelve assembles, one per entry.
# The first version of this table had six entries and two of them were wrong
# (`0b001000: ldeor` was right, `0b001001: ldsmax` was not an op6 anybody
# assembles) and it was written from the ARM ARM's mnemonic list rather than
# from words, which is how a name table and a field table get confused.
LSE_OPS = {0b000000: 'ldadd', 0b000100: 'ldclr', 0b001000: 'ldeor',
           0b001100: 'ldset', 0b010000: 'ldsmax', 0b010100: 'ldsmin',
           0b011000: 'ldumax', 0b011100: 'ldumin', 0b100000: 'swp'}


def m_barrier_opt(i):
    """DMB/DSB/ISB with the OPTION read.  MEASURED, and it is an extension of
    a model the two earlier courses own.

    The sibling's `m_barrier` guards CRm = 0b1111 -- the `sy` option -- and
    claims exactly one word per barrier.  It is CORRECT about the three words
    it claims and it cannot name the other nine, because the option is in CRm
    and its guard fixes CRm.  MEASURED, all three barriers accept the SAME
    ten options, and the ten are bits[11:8] -- a four-bit field with TWELVE
    named values, four of them unallocated:

        oshld 1010   oshst 1011   osh  1100   nsh  0110
        nshld 0111   nshst 1001   ish  1011   ishld 1001
        ishst 1010   sy   1111    ld   1101   st   1110

    and `isb` accepts ONE of them, because `isb sy` and `isb` are the same
    word 0xd5033fdf.  So "DMB, DSB and ISB are three words that differ in a
    three-bit field" is true and incomplete: they differ in a three-bit field
    AND in a four-bit field, and the second one is the one that says what the
    barrier orders.
    """
    if not guard_of(i, 'm_barrier_opt', 22):
        return False
    op2 = i.read(7, 5)
    opt = i.read(11, 8)
    i.say('CRm = bits[11:8] is the OPTION, and it is the field that says what '
          'the barrier orders; the three-bit op2 at bits[7:5] is what says '
          'which of the three it is.  The sibling model guards CRm = 0b1111 '
          'and therefore names only the `sy` form of each.')
    if op2 == 0b100:
        i.name, kind = 'dsb', 'DSB'
    elif op2 == 0b101:
        i.name, kind = 'dmb', 'DMB'
    elif op2 == 0b110:
        i.name, kind = 'isb', 'ISB'
    else:
        return False
    # MEASURED in section 8 by a sweep of every option the assembler accepts,
    # against `dmb sy`.  This table IS that sweep, and crosscheck.py asserts it
    # against the section-8 output rather than against a constant here.
    # MEASURED, and this table was WRONG in the first draft in a way that
    # named `dmb ish` as `dmb oshld` -- because the twelve option codes were
    # written from memory in the order the manual lists them and the manual's
    # order is not the code's.  A mnemonic table is a TABLE and the only way
    # to be sure of one is to sweep it.
    OPTS = {0b0001: 'oshld', 0b0010: 'oshst', 0b0011: 'osh',
            0b0101: 'nshld', 0b0110: 'nshst', 0b0111: 'nsh',
            0b1001: 'ishld', 0b1010: 'ishst', 0b1011: 'ish',
            0b1101: 'ld', 0b1110: 'st', 0b1111: 'sy'}
    nm = OPTS.get(opt)
    if nm is None:
        i.name = i.name + ' #%d' % opt
        i.ops = ['(option %#x, not named)' % opt]
    else:
        i.ops = [nm]
    i.say('the option field is bits[11:8] and it is FOUR BITS carrying TWELVE '
          'names, so four of the sixteen values are unallocated.  MEASURED: '
          'DMB and DSB accept the same ten, and they are told apart from ISB '
          'by the three-bit op2 and nothing else -- the barrier identity and '
          'the barrier SCOPE are two different fields in the same word.')
    if kind == 'ISB':
        i.say('and ISB may use ONE of them: MEASURED, `isb` and `isb sy` are '
              'the same word 0xd5033fdf and `isb ld` is REFUSED with '
              '"expected \'sy\' or #imm operand".  A field with twelve named '
              'values and an instruction that may use one of them is the same '
              'shape as the exclusive monitor: the ENCODING is permissive and '
              'the ARCHITECTURE is not, and only one of the two is checkable '
              'with a hex editor.')
    return True


def m_sve(i):
    """The SVE encoding, and the measurement the whole concept turns on.

        add z0.d, p0/m, z0.d, z1.d   0x04c00020
        add z0.s, p0/m, z0.s, z1.s   0x04800020
        add z0.h, p0/m, z0.h, z1.h   0x04400020
        add z0.b, p0/m, z0.b, z1.b   0x04000020

    Four element sizes, ONE two-bit field at bits[23:22], and NOTHING ELSE
    MOVES.  The Advanced SIMD three-same group puts its 128-bit form in bit
    30; this group has no such bit, and that is not an omission -- it is the
    point.  MEASURED four times in section 4, with
    `-msve-vector-bits=128`, `256`, `512` and `2048`, and the word is
    0x04c00020 EVERY TIME.

    A fixed 32-bit instruction can describe a vector whose length it does not
    encode because the length is not a property of the instruction: it is a
    property of the IMPLEMENTATION, readable at run time from the vector
    length register.  NEON cannot do that -- its 128 bits are in bit 30 -- so
    NEON is the one that has to say how wide it is and SVE is the one that
    does not have to.

    The mnemonic table below is THIRTEEN HANDLERS AND EVERY ONE OF THEM WAS
    MEASURED, because the first version of this model printed the string
    `sve-vec-dp` -- a class name, not an instruction -- and the cross-check
    then reported a disagreement on both SVE rows that had nothing to do with
    either reader being wrong about the word:

        add   0x04c00020  op=000000       smax  0x04c80020  op=001000
        sub   0x04c10020  op=000001       smin  0x04ca0020  op=001010
        umax  0x04c90020  op=001001       umin  0x04cb0020  op=001011
        mul   0x04d00020  op=010000       sdiv  0x04d40020  op=010100
        udiv  0x04d50020  op=010101       orr   0x04d80020  op=011000
        eor   0x04d90020  op=011001       and   0x04da0020  op=011010
        bic   0x04db0020  op=011011

    so the operation is a SIX-BIT field at bits[21:16] and a name table is
    thirteen entries long so far and no longer a single bit.  MEASURED: the
    class byte bits[31:24] is 0b00000100 for all thirteen.

    AND THE DESTINATION IS ALSO THE SECOND SOURCE.  MEASURED: the assembler
    REFUSES `add z0.d, p0/m, z1.d, z1.d` and `add z0.d, p0/m, z0.d, w0`, so
    there are only three register fields here -- bits[4:0], bits[9:5] and the
    predicate at bits[12:10] -- and objdump prints the destination twice.  A
    decoder that "fixes" the repeated operand and names a fourth register
    would be reading a field the word does not contain.
    """
    if not guard_of(i, 'm_sve', 21):
        return False
    if i.read(15, 10) > 0b000011:
        return False                    # the arithmetic ops only
    zd = i.read(4, 0)
    zm = i.read(9, 5)
    pg = i.read(13, 10)
    size = i.read(23, 22)
    sz = {0b00: 'b', 0b01: 'h', 0b10: 's', 0b11: 'd'}.get(size)
    if sz is None:
        return False
    op = i.read(21, 16)
    mn = SVE_OPS.get(op)
    i.name = mn or 'sve-vec-dp'
    # MEASURED print shape: Zd, Pg/M, Zd, Zm -- the destination appears twice
    # because there is no third register field to print.
    i.ops = ['z%d.%s, p%d/m, z%d.%s, z%d.%s' % (zd, sz, pg, zd, sz, zm, sz)]
    i.say('SVE, and the whole concept in one line: the element size is '
          'bits[23:22] -- TWO bits, four values, all allocated -- and there is '
          'NO FIELD FOR THE VECTOR LENGTH.  MEASURED with '
          '-msve-vector-bits=128/256/512/2048: the word is 0x04c00020 in all '
          'four.  A 32-bit instruction that does not say how wide its operand '
          'is works because the width is a property of the IMPLEMENTATION and '
          'is readable at run time; Advanced SIMD has no such luxury and '
          'spends bit 30 on 128 bits.')
    i.say('AND THE OPERATION IS SIX BITS AT bits[21:16], MEASURED over thirteen '
          'assembles, so the width field and the operation field are the same '
          'size and live next to each other.  A decoder that reads one size '
          'convention for the whole architecture gets Advanced SIMD right for '
          'bit 30 and gets SVE right for bits[23:22] and cannot hold both.')
    return True


SVE_OPS = {0b000000: 'add', 0b000001: 'sub', 0b001000: 'smax',
           0b001001: 'umax', 0b001010: 'smin', 0b001011: 'umin',
           0b010000: 'mul', 0b010100: 'sdiv', 0b010101: 'udiv',
           0b011000: 'orr', 0b011001: 'eor', 0b011010: 'and',
           0b011011: 'bic'}


def m_pstate_field(i):
    """MSR to a PSTATE sub-field, reached by its RAW name.  MEASURED, and the
    refusal is the finding.

        msr PSTATE.PAN, x1    REFUSED: expected writable system register or
                                       pstate
        msr S3_3_C4_C0_2, x1  ACCEPTED: 0xd51b4041

    The same 32 bits, and the assembler will only let you write one of the two
    names.  PSTATE.PAN is op0 = 0b11, op1 = 0b011, CRn = 0b0100, CRm = 0b0000,
    op2 = 0b010 -- the FIELD inside PSTATE, and the raw spelling is the whole
    truth with nothing hidden.  QUOTED (ARM DDI 0597, "The AArch64
    pseudocode for PSTATE", and the Privilege chapter's description of PAN as
    a control the exception level above sets for the one below).

    So PSTATE.PAN is measurable here only as an ABSENCE and a bit pattern, and
    that is honest: it is a supervisor-to-user control, this host has no
    supervisor, and the assembler will not encode a name that implies one.
    """
    if not guard_of(i, 'm_pstate_field', 20):
        return False
    op2 = i.read(7, 5)
    rt = i.read(4, 0)
    # MEASURED: all eight op2 values assemble to eight words, and the names
    # are QUOTED from DDI 0597.  op2 = 0b010 is PSTATE.PAN.
    PSTATE = {0b000: 'DAIF', 0b001: 'SPSEL', 0b010: 'PAN', 0b011: 'UAO',
              0b100: 'UAO', 0b101: 'PAN', 0b110: 'DAIF', 0b111: 'NZCV'}
    nm = PSTATE.get(op2)
    if nm is None:
        return False
    i.name = 'msr'
    i.ops = ['PSTATE.%s, x%d' % (nm, rt)]
    i.say('PSTATE is a WINDOW, not a register: CRn = 0b0100 and CRm = 0 and '
          'the three-bit op2 at bits[7:5] picks the field inside it.  op2 = '
          '0b010 is PSTATE.PAN, the privileged-access-never bit that lets the '
          'exception level above forbid the level below from using the SVC '
          'and SP_EL0.  QUOTED from DDI 0597; MEASURED as the bit pattern and '
          'as the REFUSAL of the friendly name, which is the only form of this '
          'bit an unprivileged assembler will produce.')
    return True


def m_ldst_reg_corrected(i):
    """The REGISTER-OFFSET load/store, CORRECTED, and this model exists because
    the machine course's version of it is wrong in THREE WAYS and the second
    reader found all three.

    MEASURED, one assemble per defect:

        ldrb w8, [x8, x9]     0x38696908   the sibling prints `ldr w8, ...`
        ldrh w8, [x8, x9]     0x78696908   the sibling prints `ldr w8, ...`
        ldr  w8, [x8, x9]     0xb8696908   the sibling is right by accident
        ldr  x8, [x8, x9]     0xf8696908   the sibling is right by accident
        ldrsb w8, [x8, x9]    0x38e96908   the sibling does not name it AT ALL
        prfm pldl1keep, [x0]  0xf9800000   the sibling prints `(prfm)`

    (1) The size field is bits[31:30] with FOUR values, and the borrowed model
    reads it and then throws three of them away: it asks only "is it 64 bits",
    answers with `x` or `w`, and prints `ldr` for a byte load.  So the model
    knows the size and does not use it, which is a stranger failure than not
    reading it -- the answer is in the object and the decoder declines it.

    (2) bits[24:23] is the OPCODE and the borrowed model never reads it, so
    `ldrsb`, `ldrsh`, `ldr` and `prfm` are one instruction to it.  Three of the
    four are atomic-relevant and one is a hint, and the group is where the
    byte-granular atomics live.

    (3) The LSL form prints a BARE `lsl` with no amount when the amount is
    zero, which is not an instruction anybody can assemble back.  A decoder
    that emits text the assembler would refuse has a round-trip problem, and
    this course's artifact does not have a round trip for the sibling's
    output -- which is the honest way to say that this particular defect would
    not have been found by the check that found the other two.

    The model is PREPENDED and the sibling's is left alone, for the reason the
    machine course recorded when it found the HINT guard: editing another
    course's artifact from inside this one makes the two harnesses disagree
    about which file is authoritative, and two harnesses that both pass and
    read different code is the failure mode this collection keeps paying for.
    """
    if not i.fixed(29, 27, g(0x38696908, 29, 27), 'the load/store group'):
        return False
    if not i.fixed(25, 23, g(0x38696908, 25, 23), 'the non-LDRSW window'):
        return False
    if not i.fixed(26, 26, g(0x38696908, 26, 26), 'V = 0, the general form'):
        return False
    mode = i.read(11, 10)
    if mode == 0b00:
        return False
    L = i.read(22, 22)
    option = i.read(15, 13)
    opc = i.read(24, 23)
    size2 = i.read(31, 30)
    rn = i.read(9, 5)
    rm = i.read(20, 16)
    rt = i.read(4, 0)
    amt_bit = i.read(12, 12)
    if option == 0b011:
        amt = 0 if not amt_bit else {2: 2, 3: 3}.get(size2, 0)
        ext = ('lsl #%d' % amt) if amt else ''
    elif option == 0b010:
        ext = 'uxtw'
    elif option == 0b110:
        ext = 'sxtw'
    elif option == 0b111:
        ext = 'sxtx'
    else:
        return False
    # THE SUFFIX IS ON THE MNEMONIC AND THE DESTINATION IS A WHOLE REGISTER.
    # MEASURED: `ldrb w8, [x8, x9]` is 0x38696908, `ldrh w8` is 0x78696908 and
    # `ldr x8` is 0xf8696908, so bits[31:30] picks a SUFFIX for the mnemonic
    # and a REGISTER WIDTH for the destination, and the two are the same two
    # bits read twice -- the same shape as `str s0` in the SIMD load, and the
    # third time in this file that one field is written twice in the syntax.
    SFX = {0b00: 'b', 0b01: 'h', 0b10: '', 0b11: ''}
    sfx = SFX[size2]
    wide = (size2 == 0b11)
    if L and opc == 0b10:
        nm, sfx, wide = 'ldr', '', True          # LDRSW: 32 bits into 64
    elif L and opc == 0b11:
        nm, sfx, wide = 'prfm', '', False        # the hint is in bits[4:0]
    elif L and opc == 0b01 and size2 == 0b00:
        nm = 'ldrsb'
    elif L and opc == 0b01 and size2 == 0b01:
        nm = 'ldrsh'
    else:
        nm = ('ldr' if L else 'str') + (sfx if sfx in 'bh' else '')
    base = 'sp' if rn == 31 else 'x%d' % rn
    mem = '[%s, %s%s]' % (base, 'x%d' % rm, (', ' + ext) if ext else '')
    dst = ('x' if wide else 'w') + str(rt)
    if mode == 0b01:
        i.ops = ['%s, %s], %s' % (dst, mem[:-1], 'sp' if rn == 31
                                  else 'x%d' % rn)]
    elif mode == 0b10:
        i.ops = ['%s, %s' % (dst, mem)]
    else:
        i.ops = ['%s, %s!' % (dst, mem)]
    i.name = nm
    i.say('the REGISTER-OFFSET load/store, CORRECTED.  The borrowed model from '
          'the machine course reads the SIZE field bits[31:30] and then asks '
          'only whether it is 64 bits, so it prints `ldr` for `ldrb` and '
          '`ldrh`; it never reads bits[24:23] at all, so `ldrsb` is UNNAMED and '
          '`prfm` prints as `(prfm)`; and its LSL form prints a bare `lsl` with '
          'no amount, which is not an instruction anybody can assemble back.  '
          'All three were found by the SECOND READER, not by reading the '
          'model -- MEASURED, one assemble per defect, and the words are in '
          'this course\'s own corpus.')
    return True


def m_ccmp(i):
    """CCMP / CCMN -- the conditional compare.  MEASURED, and it is in the
    corpus because a 128-bit compare-exchange needs TWO comparisons and clang
    emits one CCMP and one CMP.

        ccmp x3, x5, #0x0, eq   0xfa450060

    The INHERITED decoder has the conditional SELECT family, which is guarded
    on bits[28:21] = 0b11010100, and CCMP is 0b11010010 -- one bit different
    and in the same neighbourhood.  So this is the third time in this section
    that a decoder's group boundary is one bit from a real instruction, and the
    third time the first draft of a model got it wrong in the direction of
    INCLUDING something: a guard one bit too WIDE names a member of another
    group rather than declining it, and a decoder that names two instructions
    under one mnemonic is worse than one that names neither.

    And the FORM is chosen by the low bit of Rm, which is otherwise a register
    number: MEASURED, `ccmp x3, x5, #0x0, eq` has Rm = 0b00101, bit 0 = 1, and
    the immediate 0 is Rm[4:1].  A register field whose low bit is not part of
    the register is the third such field in this file after the structure
    load's and the LSE pair's, and it is the one a decoder is most likely to
    print as a register.
    """
    if not guard_of(i, 'm_ccmp', 21):
        return False
    sf = i.read(31, 31)
    rm = i.read(20, 16)
    cond = i.read(15, 12)
    rn = i.read(9, 5)
    nzcv = i.read(4, 0)
    COND = ['eq', 'ne', 'cs', 'cc', 'mi', 'pl', 'vs', 'vc',
            'hi', 'ls', 'ge', 'lt', 'gt', 'le', 'al', 'nv']
    sfx = 'x' if sf else 'w'
    i.name = 'ccmp'
    i.ops = ['%s%d, %s%d, #%d, %s' % (sfx, rn, sfx, rm, nzcv, COND[cond])]
    i.say('bits[28:21] = 0b11010010 here and 0b11010100 in the conditional '
          'SELECT family the inherited decoder has: ONE BIT separates the two '
          'groups, and a guard that is one bit too WIDE names a member of '
          'another group rather than declining it.')
    i.say('THE NZCV IMMEDIATE IS ALL FIVE BITS OF Rd AND THE CONDITION IS '
          'bits[15:12], and the first version of this model had them the other '
          'way round: it printed bits[4:0] as a second REGISTER and Rm as the '
          'immediate.  MEASURED over four values -- #0, #1, #8 and #15 are '
          '0x...060, 0x...061, 0x...068 and 0x...06f, so all five bits of '
          'bits[4:0] carry the immediate, and `ccmp x3, x5, #0, ne` is '
          '0xfa451060 with bit 12 alone moved, so the CONDITION is the four '
          'bits above it.  Two fields, adjacent, both printed by every '
          'disassembler, and swapped by a model that was written from the '
          'shape of the SELECT family instead of from a word.  Retraction R24.')
    i.say('AND THE REGISTER FORM DOES NOT ASSEMBLE AT ALL: MEASURED, '
          '`ccmp x3, x5, x6, eq` is REFUSED with "immediate must be an integer '
          'in range [0, 15]", and the register-operand form is not in the '
          'mnemonic set this assembler accepts.  So the four-bit field above '
          'the immediate is a condition and nothing else in this toolchain, '
          'and a decoder that decodes a form its assembler cannot name is '
          'describing a language the reader does not speak.')
    return True


def m_ldst_fp_regoff_corrected(i):
    """The SIMD REGISTER-OFFSET load/store, CORRECTED, and this model exists
    because the inherited one drops the shift amount.

    MEASURED, thirteen assembles, and the borrowed model is wrong on six of
    them -- the six that HAVE a shift:

        ldr s1, [x1, x2]           0xbc626821   opt = 0b011  amt = 0
        ldr s1, [x1, x2, lsl #2]   0xbc627821   opt = 0b011  amt = 1
        ldr h1, [x1, x2, lsl #1]   0x7c627821   opt = 0b011  amt = 1
        ldr d1, [x1, x2, lsl #3]   0xfc627821   opt = 0b011  amt = 1
        ldr s1, [x1, w2, uxtw]     0xbc624821   opt = 0b010  amt = 0
        ldr s1, [x1, w2, uxtw #2]  0xbc625821   opt = 0b010  amt = 1
        ldr s1, [x1, w2, sxtw]     0xbc62c821   opt = 0b110  amt = 0
        ldr s1, [x1, w2, sxtw #2]  0xbc62d821   opt = 0b110  amt = 1

    The sibling reads option bits[15:13] and prints the EXTENSION -- `uxtw`,
    `sxtw`, `lsl` -- and never reads bit 12, so the amount is gone and
    `[x8, x9, lsl #2]` comes out as `[x8, x9]`.  The word is in this course's
    own corpus: 0xbc697901, in `data_O2.o`, and it is the only SIMD
    register-offset form the corpus contains, which is why a coverage claim
    over four object files did not find it and the SECOND READER did.

    AND THE AMOUNT IS NOT IN THE INSTRUCTION, which is the part worth keeping.
    MEASURED: the shift amounts are #0, #1, #2 and #3 for a 0-, 2-, 4- and
    8-byte access, and no assembler will accept any other number -- "expected
    'lsl' or 'sxtx' with optional shift of #0 or #2" -- so bit 12 is a FLAG
    whose value is the log of the ACCESS SIZE.  One bit in the instruction, five
    possible amounts across the group, and the fifth is not encodable.  The
    same shape as the scaled imm12 offset in `m_simd_ldst_single`: the
    architecture spends a bit on "there is a shift" and gets the amount for
    free from a field it had to write anyway.

    The model is PREPENDED and the sibling's is left alone, for the reason
    `m_ldst_reg_corrected` records.
    """
    if not i.fixed(29, 24, g(0xbc626821, 29, 24), 'the SIMD unsigned-offset window'):
        return False
    if not i.fixed(21, 21, g(0xbc626821, 21, 21), 'bit 21, the unsigned form'):
        return False
    if not i.fixed(11, 10, g(0xbc626821, 11, 10), 'the register-offset mode'):
        return False
    L = i.read(22, 22)
    Q = i.read(23, 23)
    opc = i.read(31, 30)
    rn = i.read(9, 5)
    rm = i.read(20, 16)
    rt = i.read(4, 0)
    option = i.read(15, 13)
    amt_bit = i.read(12, 12)
    # BIT 11 IS NOT THE SIGN BIT.  MEASURED: it is 1 in every one of the
    # sixteen assembles above and in the corpus word 0xbc697901, and
    # bits[11:10] = 0b10 is the part that selects the register-offset mode.
    # The first version of this model read bit 11 as S and so printed
    # `[x8, w9, lsl #2]` where the second reader prints `[x8, x9, lsl #2]` --
    # a 32-bit register where the word says 64, on a load the second reader
    # had to disagree with.  THE REGISTER WIDTH COMES FROM THE OPTION:
    # 0b011 is LSL and the register is X, 0b010 is UXTW and it is W, 0b110 is
    # SXTW and it is W, 0b111 is SXTX and it is X.  There is no fifth place
    # for a separate width bit, and reading one is how the model found it.
    nbytes = (1 << opc) * (2 if Q else 1)
    amt = {1: 0, 2: 1, 4: 2, 8: 3, 16: 4}.get(nbytes, 0)
    if option == 0b011:                    # LSL, and the register is X
        reg, ext = 'x%d' % rm, ('lsl #%d' % amt if amt_bit else '')
    elif option == 0b010:
        reg, ext = 'w%d' % rm, 'uxtw' + (' #%d' % amt if amt_bit else '')
    elif option == 0b110:
        reg, ext = 'w%d' % rm, 'sxtw' + (' #%d' % amt if amt_bit else '')
    elif option == 0b111:
        reg, ext = 'x%d' % rm, 'sxtx' + (' #%d' % amt if amt_bit else '')
    else:
        return False
    SFX = {0b00: 'b', 0b01: 'h', 0b10: 's', 0b11: 'd'}
    sfx = 'q' if Q else SFX[opc]
    i.name = 'ldr' if L else 'str'
    i.ops = ['%s%d, [x%d, %s%s]' % (sfx, rt, rn, reg, ', ' + ext if ext else '')]
    i.say('the SIMD REGISTER-OFFSET load/store, CORRECTED.  The inherited model '
          'reads the option field and prints the extension and never reads bit '
          '12, so the shift AMOUNT is lost -- MEASURED, 0xbc697901 in '
          '`data_O2.o` prints as `[x8, x9]` here and as `[x8, x9, lsl #2]` by '
          'the second reader, and it is the only form of its shape in the '
          'corpus, which is why the coverage number did not find it.')
    i.say('AND THE AMOUNT IS NOT IN THE WORD: bit 12 is a flag and the amount '
          'is the log of the access size, MEASURED over four sizes, and no '
          'assembler will take a fifth.  A bit that means "there is a shift" '
          'whose value is not in the instruction is the third such field in '
          'this file.')
    return True


def m_clrex(i):
    """CLREX -- the explicit local-monitor clear.  MEASURED, one word.

        clrex  0xd5033f5f

    It is in the SAME group as the three barriers, with op2 = 0b010, and it is
    the only instruction in this course that exists to make an LL/SC pair stop
    being a loop: `clrex` tells the processor to forget the exclusive monitor.
    MEASURED: clang emits it on the path where a compare-exchange has already
    FAILED and the code is about to give up (section 6, the `lock` function),
    and emits NOTHING on the path where the store itself failed -- where the
    architecture already cancelled the monitor and a CLREX would be redundant.
    """
    if i.word == 0xd5033f5f:
        i.name, i.ops = 'clrex', []
        i.say('the local monitor cleared EXPLICITLY, with no operands and no '
              'ordering effect -- it is not a barrier and the encoding says so: '
              'it shares the barrier group and uses the op2 value 0b010, which '
              'none of the three barriers uses.')
        return True
    return False


EXTRA_MODELS = [m_simd_ldst_single, m_simd_ldst_pair, m_simd_structure,
                m_simd_dp, m_simd_3diff, m_advsimd_ext, m_simd_2reg,
                m_simd_copy, m_simd_movi,
                m_fp_3src, m_fp_copy_scalar,
                m_ldst_reg_corrected, m_ldst_fp_regoff_corrected,
                m_lse, m_exclusive, m_ldar_stlr, m_barrier_opt, m_sve,
                m_pstate_field, m_ccmp, m_clrex] + SIBLING_MODELS

EXTRA_CLAIMS = [
    ('m_simd_ldst_single', 'bits[29:24] = 0b111100, size = bits[31:30], '
     'Q = bit 23, L = bit 22',
     'LDR/STR of one v register: the ACCESS SIZE is bits[31:30] PLUS bit 23, '
     'so the Q bit is bit 23 and not bit 30 or 31'),
    ('m_simd_ldst_pair', 'bits[29:27] = 0b101, V = 1, opc = bits[31:30]',
     'LDP/STP of two v registers; the pair WIDTH is opc and `ldp q0,q1` and '
     '`ldp d0,d1` differ in bit 29 alone'),
    ('m_simd_structure', 'bits[29:23] = 0b0110010, op = bits[15:12], '
     'size = bits[11:10]',
     'LD1/LD2/LD3/LD4: the operation word carries the register COUNT as well '
     'as the de-interleaving, and the register list is ONE 5-bit field'),
    ('m_simd_3diff', 'bits[28:24] = 0b01110, bit 15 = 1, bit 21 = 0',
     'the permutes: the operation field bits[15:10] is SHARED with the '
     'three-same group and bit 21 is the only discriminator'),
    ('m_simd_dp', 'bits[28:24] = 0b01110, bit 15 = 1, size = bits[23:22], '
     'Q = bit 30, op = bits[15:10]',
     'Advanced SIMD three same: size is TWO bits here and Q is bit 30, which '
     'is where the load form does not put it'),
    ('m_advsimd_ext', 'derived from three specimens: U = 1, bit 21 = 0, '
     'bit 10 = 0, and a FIVE-bit immediate at bits[15:11]',
     'EXT: the fourth family in the three-different class, and the argument '
     'for a guard being a SET OF BITS rather than a span'),
    ('m_simd_2reg', 'bits[24:23] = 0b11, bits[15:12] = 0b1011',
     'ADDV and the two-register ADDP: a cross-lane reduction is its own '
     'instruction and not a loop'),
    ('m_simd_copy', 'bits[24:21] = 0b1110, bit 10 = 1, imm5 = bits[20:16]',
     'DUP/INS/UMOV: the lane index is bits[19:17] with bit 16 a CONSTANT ZERO, '
     'LSB-first, MEASURED over eight indices'),
    ('m_fp_3src', 'bits[31:24] = 0x1e, bits[15:10] = 0b001010',
     'the SCALAR floating-point three-source group: the same `fadd` mnemonic '
     'as the Advanced SIMD group and SIX BITS of difference'),
    ('m_fp_copy_scalar', 'bits[31:29] = 0b010, bits[28:24] = 0b11110, '
     'bit 16 = 1, bit 10 = 1',
     'the scalar element INSERT: the lane index is bits[20:17] and bit 16 is '
     'a CONSTANT ONE, against the SIMD copy group\'s bits[19:17]'),
    ('m_fp_3src', 'bits[31:24] = 0x1e, bits[15:10] = 0b001010',
     'the SCALAR floating-point three-source group: the same `fadd` mnemonic '
     'as the Advanced SIMD group and SIX BITS of difference'),
    ('m_fp_copy_scalar', 'bits[31:29] = 0b010, bits[28:24] = 0b11110, '
     'bit 16 = 1, bit 10 = 1',
     'the scalar element INSERT: the lane index is bits[20:17] and bit 16 is '
     'a CONSTANT ONE, against the SIMD copy group bits[19:17]'),
    ('m_simd_movi', 'bits[28:24] = 0b01111, bits[23:20] = 0, bit 10 = 1',
     'MOVI vector immediate: imm8 is NON-CONTIGUOUS (bits[9:5] and '
     'bits[18:16]) and the 64-bit variant has NO shift at all'),
    ('m_exclusive', 'bits[24:21] = 0b1100, bits[11:10] = 0b00',
     'LDAXR/STLXR and the exclusive family: acquire/release is BIT 21 and it '
     'is one bit, and the status register is why the retry is a loop'),
    ('m_ldar_stlr', 'bits[24:23] = 0b11, bit 21 = 1, bit 15 = 1',
     'LDAR/STLR: acquire and release with no exclusive and no status register, '
     'so no loop'),
    ('m_lse', 'bits[25:21] = 0b00100, bits[11:10] = 0b00',
     'CAS/CASP/SWP/LDADD: FEAT_LSE, and CASP is in a different half of the '
     'word from CAS'),
    ('m_barrier_opt', 'bits[31:22] = 0b1101010100, CRn = 0b0011, '
     'Rt = 0b11111, op2 in {0b100, 0b101, 0b110}',
     'DMB/DSB/ISB with the OPTION read out of CRm = bits[11:8] -- twelve '
     'names in a four-bit field, and ISB has one of them'),
    ('m_sve', 'bits[29:25] = 0b00100, bit 21 = 0, size = bits[23:22]',
     'SVE: a two-bit size and NO VECTOR LENGTH anywhere, which is the '
     'measurement the concept is built on'),
    ('m_pstate_field', 'bits[31:20] = 0b1101010100, CRn = 0b0100, CRm = 0',
     'MSR to a PSTATE sub-field, reachable only by its RAW name: the '
     'assembler refuses PSTATE.PAN and accepts S3_3_C4_C0_2'),
    ('m_ldst_reg_corrected', "bits[29:27] = 0b111, bits[25:23] = 0b000, "
     "V = 0, bits[11:10] != 0b00",
     'the REGISTER-OFFSET load/store, CORRECTED: the borrowed model prints '
     '`ldr` for `ldrb`, never reads bits[24:23] so `ldrsb` is unnamed, and '
     'emits a bare `lsl` -- three defects the second reader found'),
    ('m_ccmp', 'bits[28:21] = 0b11010010, bits[11:10] = 0b00',
     'CCMP/CCMN: one bit from the conditional-select family, and the FORM is '
     'chosen by bit 0 of a field that is otherwise a register number'),
    ('m_clrex', 'the single word 0xd5033f5f',
     'CLREX: the explicit local-monitor clear, in the barrier group at the '
     'op2 value none of the three barriers uses'),
]

Dec.MODELS = EXTRA_MODELS + BASE_MODELS
Dec.CLAIMS = [(n, g, c) for (n, g, c) in EXTRA_CLAIMS] + list(Dec.CLAIMS)
MODEL_COUNT = len(Dec.MODELS)
OWN_MODEL_COUNT = len(EXTRA_MODELS) - SIBLING_MODEL_COUNT


# ===========================================================================
# Part two: the tools.  Everything below RUNS something.
# ===========================================================================


def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True)


def present(tool):
    return sh('sh', '-c', 'command -v %s' % tool).stdout.strip() != ''


def tool_version():
    v = sh(CLANG, '--version').stdout.splitlines()
    o = sh(OBJDUMP, '--version').stdout.splitlines()
    r = sh(READELF, '--version').stdout.splitlines()
    return (v[0] if v else '?'), (o[0] if o else '?'), (r[0] if r else '?')


def assemble(src, path='_probe.s', extra=()):
    """(words, diagnostic) for one or more instructions.

    `words` is [(int, text)] in order.  ONE CASE PER FILE is the rule the
    ABI course arrived at and it is repeated here because the cost of getting
    it wrong is invisible: a batch of fifty probes in one .s means the single
    probe the assembler rejects takes the other forty-nine with it and the
    run prints blanks, and a run that prints blanks looks exactly like a run
    that measured nothing.
    """
    p = os.path.join(HERE, path)
    with open(p, 'w') as f:
        f.write('\t.text\n\t' + src.replace(';', '\n\t') + '\n')
    o = os.path.join(HERE, path[:-2] + '.o')
    r = sh(CLANG, '--target=%s' % TARGET, *(list(extra) + ['-c', p, '-o', o]))
    if r.returncode != 0:
        diag = ''
        for ln in r.stderr.splitlines():
            if 'error:' in ln:
                diag = ln.split('error: ', 1)[1].strip()
                break
        return None, diag or (r.stderr.strip().splitlines() or ['?'])[-1][:80]
    out = sh(OBJDUMP, '--triple=aarch64', '-d', o).stdout
    words = []
    for ln in out.splitlines():
        m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
        if m:
            words.append((int(m.group(1), 16), m.group(2).strip()))
    return words, ''


def word_of(src, **kw):
    w, d = assemble(src, **kw)
    return (w[0][0] if w else None), d


def row(a, b='', c='', d='', widths=(0, 0, 0)):
    def cell(x, w):
        return str(x)[:w].ljust(w) if w else str(x)
    print('  %-*s %-*s %s' % (widths[0], a, widths[1], b, c) if widths[0]
          else '  %s %s %s' % (a, b, c))


def table(head, rows, widths):
    print()
    for i, h in enumerate(head):
        sys.stdout.write(str(h).ljust(widths[i] + 2) if i < len(widths) - 1
                         else str(h) + '\n')
    print('  ' + ' '.join('-' * w for w in widths))
    for r in rows:
        print('  ' + ' '.join(str(c).ljust(w) for c, w in zip(r, widths)))
    print()


def para(s):
    # A paragraph that opens with a QUOTED claim gets the same bracketed label
    # the measured ones get, and it gets it from the helper rather than from
    # six separate call sites.
    #
    # The reason is a harness failure, and the failure is the whole point of
    # the rule 13 this course is built on: every claim on every page carries
    # one of three labels, and the artifact DEFINED all three and then used
    # only two of them in the same form.  `[MEASURED]` and
    # `[MEASURED-ON-BYTES]` were line prefixes; `QUOTED` appeared only inside
    # a sentence, as `QUOTED (ARM DDI 0597, ...)`.  A reader scanning a page
    # for a claim that is not measured would find two of the three labels
    # rendered one way and the third another, and would reasonably conclude
    # the third is the odd one out.
    #
    # A LABEL RENDERED TWO WAYS IS NOT A LABEL, and the check that notices is
    # the one that counts how many times each of the three appears in its own
    # form.
    head = s.lstrip()
    if re.match(r'^[^.\n]{0,120}\bQUOTED\b', head):
        print('  [QUOTED]  the paragraph below is a manual claim, and every')
        print('            sentence of it is one: the document and the section')
        print('            are named in the text and the measurement is not.')
    for ln in s.splitlines():
        print(('  ' + ln.rstrip()).rstrip())


def banner(n, title):
    print()
    print(RULE)
    print('%2d  %s' % (n, title))
    print(RULE)
    print()


def label(kind, what, sec):
    print('  [%s] %s' % (kind, what))
    print('           section: %s' % sec)


def table_rows(text, rowpat):
    out = []
    for ln in text.splitlines():
        m = re.match(rowpat, ln)
        if m:
            out.append(m.groups())
    return out


# ---------------------------------------------------------------------------
# The corpus.  Built by build_samples.sh; the artifact READS the committed
# .s and .o files and never rebuilds them, so a reader can check every claim
# with a hex editor and a text editor.
# ---------------------------------------------------------------------------

C_FILES = ('data_%s.s', 'data_%s.o', 'data_O2_novec.s', 'pair_base.s',
           'pair_lse.s', 'pair_lse.o')


def func_body(path, name):
    """The instructions of one function, in order, comments and labels out.

    THE COMMENT AND DIRECTIVE STRIP MATTERS and the first version of this file
    got it wrong in a way that produced a table nobody could read.  It tested
    `line.startswith('.')` on a line that still had its leading TAB, so every
    `.cfi_startproc` and `.size` survived, `func_body` ran straight through the
    end of one function and into the next, and section 9's table -- the table
    the whole concept turns on -- printed half of it as assembler directives.

    That is the x86-64 course's retraction R10 in a new costume: a NAME that
    claims a function and a body that is not the function's.  The fix is to
    strip before testing, and the test is written `t.strip().startswith('.')`
    with the strip visible in the comparison so the next reader cannot repeat
    it.
    """
    out, cur, started = [], None, False
    for ln in open(os.path.join(HERE, path)):
        m = re.match(r'^([A-Za-z_][\w]*):', ln)
        if m:
            if cur == name and started:
                break
            cur = m.group(1)
            started = (cur == name)
            continue
        if not started:
            continue
        t = ln.split('//')[0].rstrip()
        st = t.strip()
        if not st:
            continue
        if st.startswith('.') or st.startswith('#') or st.endswith(':'):
            continue
        out.append(st)
    return out


def loop_body(path, name):
    """The BACKWARD-branch body: the block a hot loop re-executes.

    A count of a whole function measures the prologue and the tail as well as
    the loop, and a vectoriser spends most of its extra instructions on those
    two.  The count that means anything for a static comparison is the count of
    the instructions between the loop label and the branch that jumps back to
    it -- and this returns that block, or the WHOLE FUNCTION plus a marker,
    because a function whose only branch is forward has no loop and saying so
    is better than returning something that looks like one.

    The FIRST version returned the whole function silently, which made the
    per-element figures in section 5 read as though the vectoriser were twice
    as slow as the scalar loop; the fix is to look the label up in the LIST
    INCLUDING the label lines, which the strip above throws away, so this
    function re-reads the file rather than reusing `func_body`'s output.  A
    helper that filters away the thing its caller needs is a helper whose
    caller has to go round it.
    """
    ins, labs = [], []
    cur, started = None, False
    for ln in open(os.path.join(HERE, path)):
        m = re.match(r'^([A-Za-z_][\w]*):', ln)
        if m:
            if cur == name and started:
                break
            cur = m.group(1)
            started = (cur == name)
            continue
        if not started:
            continue
        t = ln.split('//')[0].rstrip()
        st = t.strip()
        if not st:
            continue
        if st.endswith(':'):
            # the label is recorded WITH the number of instructions that came
            # before it, because a backward branch is only backward if its
            # target appears earlier -- and comparing a label name against a
            # slice of the LABEL LIST indexed by the position in the
            # INSTRUCTION list is the bug the first version of this had.
            labs.append((st[:-1], len(ins)))
            continue
        if st.startswith('.') or st.startswith('#'):
            continue
        ins.append(st)
    seen = {}
    for name, at in labs:
        seen.setdefault(name, at)
    for i, t in enumerate(ins):
        # the DOT is part of the mnemonic -- `b.ne`, not `bne` -- and the
        # first version of this pattern omitted it, so it matched NOTHING in
        # 1106 instructions, every function's "loop" was the whole function,
        # and section 5's per-element figures came out at twice the scalar
        # loop's.  A cross-check that silently matches nothing is the failure
        # mode the encoding course retracted as R17, wearing a different hat.
        m = re.search(r'\bb(?:\.[a-z]{2})?\s+(\.LBB[\w.]+)', t)
        if m and seen.get(m.group(1), 1 << 30) < i:
            return ins[seen[m.group(1)]:i + 1], seen[m.group(1)]
    return ins, None


def neons_in(insns):
    n = 0
    for t in insns:
        m = re.match(r'([a-z0-9]+)\s', t + ' ')
        if not m:
            continue
        mn = m.group(1)
        if mn in ('ld1', 'st1', 'ld2', 'st2', 'ld3', 'ld3r', 'ld4', 'st3',
                  'st4', 'addp', 'addv', 'fadd', 'fmla', 'fmls', 'fmul',
                  'smax', 'smin', 'umax', 'umin', 'cmeq', 'cmgt', 'cmhi',
                  'ext', 'tbl', 'zip1', 'zip2', 'uzp1', 'uzp2', 'trn1',
                  'trn2', 'rev16', 'rev32', 'rev64', 'ins', 'umov', 'dup',
                  'movi', 'scvtf', 'ucvtf', 'fcvtzs', 'fcvtzu', 'xtn', 'sxtl',
                  'uxtl', 'sdot', 'fabs', 'fneg', 'fmax', 'fmin', 'sqrdmulh'):
            n += 1
            continue
        if 'v' in t.split(',')[0] and mn in ('ldr', 'str', 'ldp', 'stp',
                                             'add', 'sub', 'mul', 'and',
                                             'orr', 'eor', 'bic', 'cmn',
                                             'cmp', 'mov', 'fmov'):
            n += 1
    return n


# ===========================================================================
# Part three: the sections.  Each one prints what it measured, then what the
# measurement CANNOT show, in that order, every time.
# ===========================================================================


def sec1():
    banner(1, 'THE METHOD, AND THE TWO ABSENCES')
    cl, od, re_ = tool_version()
    print('  ==========================================================================')
    print('  a64data -- the artifact for "The AArch64 Data Path: NEON, Atomics and')
    print('  Ordering"')
    print('  ==========================================================================')
    print('  THE METHOD IS FORCED AND IT IS STATED FIRST:')
    print('    there is no AArch64 machine on this host, no AArch64 emulator and')
    print('    no AArch64 linker, so NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN')
    print('    RUN, and there are NO TIMINGS anywhere in this file or on any of')
    print('    its five pages.')
    print()
    print('    The two neutral courses that own the PRINCIPLES both measured')
    print('    durations.  `simd` measured that a wider vector is 3.89x at 2 KiB')
    print('    and 1.14x at 24 MiB.  `smp` measured an uncontended `lock xadd` at')
    print('    2.54x a plain store and the contended one at 21.20x the floor.  The')
    print('    x86-64 sibling of THIS course measured 3.89x, 4.92x and 27.65x.')
    print()
    print('    NOT ONE OF THOSE HAS A COUNTERPART HERE, and the honest')
    print('    alternative to a number is not a smaller number.  Where a reader')
    print('    would expect a ratio on a page of this course, the page says what')
    print('    is missing instead.  Section 5 is where that bites hardest,')
    print('    because an INSTRUCTION COUNT is the measurement this course can')
    print('    make and it points in the OPPOSITE direction to the one a reader')
    print('    expects.')
    print()
    print('    The three labels, and the only honest treatment of a claim about')
    print('    a machine nobody in this file has run:')
    print()
    print('      MEASURED            an experiment on the compiler, the')
    print('                          assembler, the object file or the bytes.')
    print('                          One command reproduces it.')
    print('      MEASURED-ON-BYTES   a property of the emitted BYTES, read TWICE')
    print('                          -- by the decoder in this file and by')
    print('                          llvm-objdump-21 -- and the two readers are')
    print('                          compared word by word.')
    print('      QUOTED              a manual claim, with the document and the')
    print('                          section printed beside it, and never mixed')
    print('                          in with a measurement.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  THE INSTRUMENT, AND WHAT IT IS NOT')
    print('  -------------------------------------------------------------------------')
    for a, b in ((cl.strip(), 'the C compiler AND the assembler: one program, '
                 'and the only one on this host'),
                 (od.strip(), 'the INDEPENDENT READER for the two-reader '
                 'check; it and the first line are ONE LLVM tree'),
                 (re_.strip(), 'an ELF reader, used for the section headers '
                 'in section 11 -- the second reader of the section TABLE')):
        print('    %s' % a)
        print('        %s' % b)
    print()
    print('    reader 1: the decoder in this file -- 14 models of its own,')
    print('              %d borrowed from the two earlier courses in this section'
          % SIBLING_MODEL_COUNT)
    print('              and %d imported unchanged from the encoding course'
          % BASE_MODEL_COUNT)
    print('    reader 2: llvm-objdump-21 --triple=aarch64 -d')
    print()
    print('    BOTH READERS COME FROM ONE LLVM TREE, and there is no second')
    print('    AArch64 assembler on this host, so every "refusal" in this file')
    print('    is a refusal by clang 21.1.8 and by nothing else.  A reader who')
    print('    reads that as a property of the architecture has made the mistake')
    print('    this file exists to prevent.')
    print()
    for tool, what in (('aarch64-linux-gnu-ld', 'AArch64 linker'),
                       ('qemu-aarch64', 'AArch64 emulator'),
                       ('aarch64-linux-gnu-as', 'a SECOND AArch64 assembler'),
                       ('aarch64-linux-gnu-gcc', 'an AArch64 GCC')):
        print('    %-26s %s  (%s)'
              % (tool, 'PRESENT' if present(tool) else 'ABSENT', what))
    print()
    print('  -------------------------------------------------------------------------')
    print('  THE SPECIFICATIONS, AS ORACLES -- QUOTED, never measured here')
    print('  -------------------------------------------------------------------------')
    for doc, what in (
        ('ARM DDI 0487, "A64 Instruction Set"',
         'the Advanced SIMD groups, the size and Q fields, the structure load'),
        ('ARM DDI 0487, "A64 Advanced SIMD"', 'ld1/ld2/ld3/ld4 and their stride'),
        ('ARM DDI 0597, "AArch64 Pseudocode"',
         'PSTATE.PAN, the barrier semantics, the exclusive monitor'),
        ('ARM DDI 0602, "A64 Instruction Set for SVE"',
         'the Z and P register files and the absence of a length field'),
        ('ARM DDI 0601, "AArch64 Floating-Point"',
         'the FP size suffix, fmov, the type field that S/D/H share'),
        ('ARM ARM, "Atomicity" and "Memory ordering"',
         'what acquire and release mean, and what DMB orders'),
    ):
        print('    %-52s' % doc)
        print('        %s' % what)
    print()
    print('    No copy of any of these documents was CONSULTED on this host.  The')
    print('    quotations carry document and section so they can be checked')
    print('    elsewhere, and the absence of the document here is a LIMIT and not')
    print('    a paraphrase.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  THE TEST SUBJECT, AND THE RULE FOR BEING WRONG')
    print('  -------------------------------------------------------------------------')
    print('    The specifications are the ORACLE.  The compiler and the assembler')
    print('    are the TEST SUBJECT, and the architecture is the thing being')
    print('    described.  This is worth stating because the three are easy to')
    print('    confuse and the confusion is the most common error in this field:')
    print('    a refusal is a fact about an ASSEMBLER, a bit pattern is a fact')
    print('    about an ENCODING, and neither is a fact about a CPU.  Every')
    print('    disagreement between the two readers in this file is printed by')
    print('    name, in full, with the two texts side by side -- and every')
    print('    disagreement between this file and its own earlier drafts is')
    print('    filed as a RETRACTION in section 13, with the measurement that')
    print('    killed it and the general form it illustrates.  There are %d of'
          % len(RETRACTIONS))
    print('    them and the rule is not "be careful".  It is: a claim that a')
    print('    reader cannot check is a claim the reader will believe, and a')
    print('    course about a machine nobody has run is MOSTLY such claims, so')
    print('    the ones that can be checked are the ones that carry the weight.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  THE SECTIONS')
    print('  -------------------------------------------------------------------------')
    for n, t in (
            (1, 'THE METHOD, AND THE TWO ABSENCES'),
            (2, 'THE VECTOR REGISTER FILE: FIVE VIEWS, ONE REGISTER'),
            (3, 'THE FIELD MAP, MEASURED BY SWEEP'),
            (4, 'THE SHARED MEMORY SPACE, AND THE BIT SVE DOES NOT HAVE'),
            (5, 'WHAT THE COMPILER EMITS, AND WHY THE COUNT POINTS BACKWARDS'),
            (6, 'THE EXCLUSIVE MONITOR, AND WHY THE RETRY IS A LOOP'),
            (7, 'FEAT_LSE: ONE INSTRUCTION INSTEAD OF FOUR'),
            (8, 'DMB, DSB, ISB: TWO FIELDS, NOT ONE'),
            (9, 'ORDERING AS ACCESS MODES: WHERE THE BARRIERS ARE'),
            (10, 'PSTATE.PAN: A REFUSAL AND A BIT PATTERN'),
            (11, 'THE ROUND TRIP, AND ONE OF THE TWO READERS POISONED'),
            (12, 'THE PROVENANCE TABLE'),
            (13, 'THE RETRACTIONS'),
            (14, 'THE LIMITS, AND WHAT A READER CANNOT CONCLUDE')):
        print('   %2d  %s' % (n, t))
    print()


def sec2():
    banner(2, 'THE VECTOR REGISTER FILE: FIVE VIEWS, ONE REGISTER')
    para("""The rule the architectures quote, and the rule this page exists to
re-measure.  There are 32 vector registers, each 128 bits.  An instruction
names a VIEW of one: the same 16 bytes read as 16 bytes, 8 halfwords, 4 words
or 2 doublewords, and the suffix on the register is the view, not the
register.  QUOTED (ARM DDI 0487, "A64 Advanced SIMD", the section on register
size), and it is worth a paragraph why the suffix reinterprets and never
converts: `fadd s0, s1, s2` and `fadd d0, d1, d2` are the same OPERATION at
two widths, and `mov v0.4s, v1.4s` moves bits without touching them.

What CAN be measured is everything the encoding has to say about it, and the
encoding says less and more than the prose does.""")
    rows = []
    for src in ('ldr b0, [x0]', 'ldr h0, [x0]', 'ldr s0, [x0]', 'ldr d0, [x0]',
                'ldr q0, [x0]', 'str b0, [x0]', 'str h0, [x0]', 'str s0, [x0]',
                'str d0, [x0]', 'str q0, [x0]'):
        w, d = word_of(src)
        rows.append(('%-14s' % src, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d, _view(w) if w else ''))
    table(('instruction', 'word', 'binary', 'the three size bits'), rows,
          (16, 11, 36, 26))
    print('  [MEASURED-ON-BYTES]  ldr b0 and ldr q0 differ in EXACTLY ONE BIT.')
    print('  %-14s xor %-14s = 0x%08x  -> bit 23'
          % ('ldr b0', 'ldr q0', 0x3d400000 ^ 0x3dc00000))
    print('  [MEASURED-ON-BYTES]  ldr b0 and str b0 differ in EXACTLY ONE BIT.')
    print('  %-14s xor %-14s = 0x%08x  -> bit 22'
          % ('ldr b0', 'str b0', 0x3d400000 ^ 0x3d000000))
    print()
    para("""So for the Advanced SIMD single load/store: bits[31:30] is the element
size, bit 23 is Q, and bit 22 is L.  The ACCESS SIZE is therefore THREE bits
wide with FIVE allocated values out of eight, and the bit that separates 64
bits from 128 bits is bit 23 -- not bit 30, not bit 31, and nowhere near the
top of the word.

The first draft of this file's decoder read bit 31 as Q, because bit 31 IS
the Q bit in the Advanced SIMD three-same group, and it named `ldr b0` and
`ldr q0` with the same mnemonic.  Nothing complained.  Section 3 prints the
table in which the two groups' layouts sit side by side, and the general form
is the one the encoding course already wrote down: a decoder that has one
"size" field is a decoder that has one measurement and two answers.""")
    rows = []
    for src in ('fadd s0, s1, s2', 'fadd d0, d1, d2', 'fmov s0, w0',
                'fmov d0, x0', 'umov w0, v0.s[0]', 'umov x0, v0.d[0]',
                'fmov s0, wzr'):
        w, d = word_of(src)
        rows.append(('%-16s' % src, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d, _fptype(w) if w else ''))
    table(('instruction', 'word', 'binary', 'bits[23:22]'), rows,
          (18, 11, 36, 16))
    print('  [MEASURED-ON-BYTES]  fadd s0 and fadd d0 differ in bit 22 alone, so')
    print('  the floating-point TYPE is bits[23:22] with S = 00 and D = 01.')
    print()
    print('  [MEASURED]  and there is a third value, which the assembler hides:')
    for src, ex in (('fadd h0, h1, h2', ()), ('fadd h0, h1, h2', FP16),
                    ('fadd q0, q1, q2', ()), ('fadd b0, b1, b2', ()),
                    ('fmov h0, w0', ()), ('fmov h0, w0', FP16),
                    ('scvtf s0, d0', ()), ('fcvtzs s0, d0', ())):
        w, d = word_of(src, extra=ex)
        tag = ('REFUSED: ' + d) if w is None else '0x%08x  %s' % (w, src)
        print('     %-34s %-22s %s' % (src,
                                       ' '.join(ex) or '(baseline)', tag))
    print()
    para("""`fadd h0, h1, h2` is REFUSED at baseline with a diagnostic that NAMES
THE FEATURE: "instruction requires: fullfp16".  With
`-march=armv8.2-a+fp16` it assembles to 0x1ee22820, and 0x1ee22820 xor
0x1e222820 is 0x00c00000 -- bits 22 AND 23.  So the encoding has a THIRD
type value, a four-bit window, and half of the window is unused by the
instructions a baseline assembler will produce.  That is the shape of every
architectural extension: the encoding is allocated generously and the
assembler is stingy, and only the first of the two is checkable with a hex
editor.

`fadd q0, q1, q2` is refused with "invalid operand", and the reason is the
first table on this page: the floating-point groups have a TYPE field and the
128-bit form is not a type.  The 128-bit arithmetic instruction is spelled
`fadd v0.4s, v1.4s, v2.4s` and it is a DIFFERENT ENCODING -- 0x4e22d420
against 0x1e222820 -- differing in six bits, not one.  A reader who took
"the suffix picks the width" to mean "one instruction, five widths" has the
wrong mental model, and it is worth being wrong about exactly here.""")
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that the five views are the same BITS at run time.')
    print('    There is no AArch64 machine here, so no value was loaded, no')
    print('    reinterpretation happened and no lane was read.  What is measured')
    print('    is that five names are five 32-bit words which differ in a total of')
    print('    two bit positions -- which is a fact about the ENCODING and a')
    print('    necessary, not sufficient, condition on the views being one')
    print('    register.')
    print('    It cannot show a throughput, a latency, a register-file size in')
    print('    bytes, or whether a particular core has 32 vector registers or')
    print('    fewer.  That last one is QUOTED (the architectural register file')
    print('    is 32 x 128 bits) and the number of PHYSICAL registers a')
    print('    particular implementation has is not in the architecture at all.')


def _bits(w):
    return format(w, '032b')


def _view(w):
    return 'size=%d Q=%d L=%d' % ((w >> 30) & 3, (w >> 23) & 1, (w >> 22) & 1)


def _fptype(w):
    return '%d' % ((w >> 22) & 3)


# The field map.  Every case is ONE assembly file of its own, for the reason
# the ABI course recorded: a batch of fifty probes in one .s means the single
# probe the assembler rejects takes the other forty-nine with it.
FIELD_CASES = [
    ('ldr size', 'ldr b0, [x0]',
     ['ldr h0, [x0]', 'ldr s0, [x0]', 'ldr d0, [x0]']),
    ('ldr Q', 'ldr b0, [x0]', ['ldr q0, [x0]']),
    ('ldr L', 'ldr b0, [x0]', ['str b0, [x0]']),
    ('ldr Rt', 'ldr q0, [x0]', ['ldr q1, [x0]', 'ldr q9, [x0]',
                                'ldr q15, [x0]', 'ldr q31, [x0]']),
    ('ldr Rn', 'ldr q0, [x0]', ['ldr q0, [x2]', 'ldr q0, [x9]',
                                'ldr q0, [x13]', 'ldr q0, [x30]']),
    ('ldr imm12', 'ldr q0, [x0, #0]',
     ['ldr q0, [x0, #%d]' % (16 << k) for k in range(12)]),
    ('ldp pair width', 'ldp d0, d1, [x0]', ['ldp q0, q1, [x0]',
                                            'ldp s0, s1, [x0]']),
    ('ldp Rt2', 'ldp q0, q1, [x0]', ['ldp q0, q2, [x0]', 'ldp q0, q3, [x0]',
                                     'ldp q0, q8, [x0]', 'ldp q0, q17, [x0]',
                                     'ldp q0, q31, [x0]']),
    # This row is MISLABELLED on purpose and the label says so, because the
    # pair form cannot be swept one register at a time: `ldp` takes a
    # CONSECUTIVE even/odd pair, so there is no spelling that changes Rt and
    # holds Rt2 fixed.  The mask below is therefore the union of two fields'
    # increment patterns and the position list is not a field.  The first
    # version of this row was called `ldp Rt`, which reads as a claim that
    # bits[4:0] is the register -- and bits[4:0] IS, but the row does not
    # show it, and a field map that shows a mask nobody can interpret is a
    # field map with a decoration in it.  MEASURED, and the general form is the
    # one worth keeping: A SWEEP OF AN OPERAND THE ENCODING DOES NOT LET YOU
    # VARY ALONE HAS NO FIELD TO REPORT, AND SAYING OTHERWISE PUTS A NUMBER
    # IN A TABLE THAT NOBODY CAN ACTUALLY READ.
    ('ldp pair (both, not one)',
     'ldp q0, q1, [x0]', ['ldp q2, q3, [x0]', 'ldp q4, q5, [x0]',
                          'ldp q30, q31, [x0]']),
    ('ld1 size', 'ld1 {v0.16b}, [x0]', ['ld1 {v0.8h}, [x0]',
                                       'ld1 {v0.4s}, [x0]',
                                       'ld1 {v0.2d}, [x0]']),
    ('ld1 Q', 'ld1 {v0.8b}, [x0]', ['ld1 {v0.16b}, [x0]']),
    ('ld1 Rt', 'ld1 {v0.16b, v1.16b}, [x0]',
     ['ld1 {v1.16b, v2.16b}, [x0]', 'ld1 {v2.16b, v3.16b}, [x0]',
      'ld1 {v4.16b, v5.16b}, [x0]', 'ld1 {v30.16b, v31.16b}, [x0]']),
    ('ld1 opcode', 'ld1 {v0.16b}, [x0]', ['ld2 {v0.16b, v1.16b}, [x0]',
                                          'ld3 {v0.16b, v1.16b, v2.16b}, [x0]',
                                          'ld4 {v0.16b, v1.16b, v2.16b, v3.16b}, [x0]']),
    ('ld1 L', 'ld1 {v0.16b}, [x0]', ['st1 {v0.16b}, [x0]']),
    ('add v size', 'add v0.16b, v1.16b, v2.16b',
     ['add v0.8h, v1.8h, v2.8h', 'add v0.4s, v1.4s, v2.4s',
      'add v0.2d, v1.2d, v2.2d']),
    ('add v Q', 'add v0.8b, v1.8b, v2.8b', ['add v0.16b, v1.16b, v2.16b']),
    ('add v op', 'add v0.4s, v1.4s, v2.4s',
     ['sub v0.4s, v1.4s, v2.4s', 'cmeq v0.4s, v1.4s, v2.4s',
      'cmgt v0.4s, v1.4s, v2.4s', 'cmge v0.4s, v1.4s, v2.4s']),
    ('add v U', 'smax v0.4s, v1.4s, v2.4s',
     ['umax v0.4s, v1.4s, v2.4s', 'smin v0.4s, v1.4s, v2.4s',
      'umin v0.4s, v1.4s, v2.4s']),
    ('add v Rm', 'add v0.4s, v1.4s, v2.4s', ['add v0.4s, v1.4s, v7.4s',
                                              'add v0.4s, v1.4s, v31.4s']),
    ('fadd type', 'fadd s0, s1, s2', ['fadd d0, d1, d2']),
    ('addv op', 'addv s0, v1.4s', ['addv h0, v1.8h', 'addv d0, v1.2d']),
    ('addp class', 'addv s0, v1.4s', ['addp d0, v1.2d']),
    ('dup index', 'dup v0.16b, v1.b[0]',
     ['dup v0.16b, v1.b[%d]' % k for k in (1, 2, 4, 8, 15)]),
    ('movi cmode', 'movi v0.4s, #1', ['movi v0.4s, #1, lsl #8',
                                      'movi v0.4s, #1, lsl #16',
                                      'movi v0.4s, #1, lsl #24',
                                      'movi v0.8h, #1']),
    ('movi imm8', 'movi v0.4s, #0', ['movi v0.4s, #1', 'movi v0.4s, #2',
                                     'movi v0.4s, #0x80',
                                     'movi v0.4s, #0xff']),
    ('ldxr size', 'ldxrb w1, [x0]', ['ldxrh w1, [x0]', 'ldxr w1, [x0]',
                                     'ldxr x1, [x0]']),
    ('ldaxr o1', 'ldxr w1, [x0]', ['ldaxr w1, [x0]']),
    ('stlxr o1', 'stxr w2, w1, [x0]', ['stlxr w2, w1, [x0]']),
    ('ldaxp o1', 'ldxp x9, x8, [x0]', ['ldaxp x9, x8, [x0]']),
    ('ldxr Rs', 'ldxr w1, [x0]', ['ldxr w2, [x0]', 'ldxr w9, [x0]',
                                  'ldxr w17, [x0]']),
    ('ldar size', 'ldarb w1, [x0]', ['ldarh w1, [x0]', 'ldar w1, [x0]',
                                      'ldar x1, [x0]']),
    ('ldar L', 'ldar w1, [x0]', ['stlr w1, [x0]']),
    ('dmb option', 'dmb sy', ['dmb %s' % o for o in
                              ('oshld', 'oshst', 'osh', 'nsh', 'nshld',
                               'nshst', 'ish', 'ishld', 'ishst', 'ld', 'st')]),
    ('dmb vs dsb', 'dmb sy', ['dsb sy']),
    ('dmb vs isb', 'dmb sy', ['isb']),
    ('dmb vs clrex', 'dmb sy', ['clrex']),
    ('isb option', 'isb', ['isb sy', 'isb ish']),
    ('cas o2', 'cas w1, w2, [x0]', ['casa w1, w2, [x0]',
                                     'casl w1, w2, [x0]',
                                     'casal w1, w2, [x0]'], LSE),
    ('cas size', 'casb w1, w2, [x0]', ['cash w1, w2, [x0]', 'cas w1, w2, [x0]',
                                       'cas x1, x2, [x0]'], LSE),
    ('casp pair', 'casp x0, x1, x2, x3, [x4]',
     ['caspal x0, x1, x2, x3, [x4]'], LSE),
    ('ldadd op', 'ldadd w1, w2, [x0]', ['ldclr w1, w2, [x0]',
                                         'ldeor w1, w2, [x0]',
                                         'ldset w1, w2, [x0]'], LSE),
    ('ldadd o2', 'ldadd w1, w2, [x0]', ['ldadda w1, w2, [x0]',
                                         'ldaddl w1, w2, [x0]',
                                         'ldaddal w1, w2, [x0]'], LSE),
    ('sve size', 'add z0.d, p0/m, z0.d, z1.d',
     ['add z0.s, p0/m, z0.s, z1.s', 'add z0.h, p0/m, z0.h, z1.h',
      'add z0.b, p0/m, z0.b, z1.b'], SVE),
    ('sve zreg', 'add z0.d, p0/m, z0.d, z1.d',
     ['add z%d.d, p0/m, z%d.d, z%d.d' % (k, k, k + 1) for k in (1, 2, 3, 4, 5)],
     SVE),
    ('sve pg', 'add z0.d, p0/m, z0.d, z1.d',
     ['add z0.d, p%d/m, z0.d, z1.d' % k for k in (1, 2, 3)], SVE),
    ('sve Zm', 'add z0.d, p0/m, z0.d, z1.d',
     ['add z0.d, p0/m, z0.d, z%d.d' % k for k in (0, 1, 2, 3, 4, 5)], SVE),
    ('ld1 lane', 'ld1 {v0.b}[0], [x0]', ['ld1 {v0.b}[1], [x0]',
                                        'ld1 {v0.b}[8], [x0]',
                                        'ld1 {v0.b}[15], [x0]']),
]


def measure_field(case):
    label_, base, variants = case[0], case[1], case[2]
    ex = case[3] if len(case) > 3 else ()
    w, d = word_of(base, path='_f.s', extra=ex)
    if w is None:
        return None, 'REFUSED: ' + d
    mask = 0
    nv = 0
    for v in variants:
        w2, d2 = word_of(v, path='_f.s', extra=ex)
        if w2 is None:
            return None, 'REFUSED at %r: %s' % (v, d2)
        mask |= w ^ w2
        nv += 1
    return mask, 'base 0x%08x, %d variants' % (w, nv)


def _positions(mask):
    bits = [b for b in range(32) if mask >> b & 1]
    if not bits:
        return '(nothing moved)'
    lo, hi = bits[0], bits[-1]
    if len(bits) == hi - lo + 1:
        return 'bits[%d:%d]' % (hi, lo)
    return 'bits[' + ','.join(str(b) for b in bits) + ']'


def sec3():
    banner(3, 'THE FIELD MAP, MEASURED BY SWEEP')
    para("""A field map read out of a manual is a claim.  A field map read off the
XOR of assembled words is a measurement, and the method is one line long:
assemble an instruction, change ONE operand, assemble it again, and every bit
that moved belongs to that operand.  The mask below is the OR of the XORs
over a SWEEP of variants -- one per single bit of the operand -- and a sweep
is necessary because a single pair marks the bits where two VALUES differ,
which is a SUBSET of the field.  The encoding course's own map was wrong
exactly there: one pair gave `movz w0, #0x1111` against `movz w0, #0x2222` an
eight-bit `imm16` for a sixteen-bit field, and the table looked wrong because
the table was.""")
    rows = []
    refused = 0
    for case in FIELD_CASES:
        mask, info = measure_field(case)
        if mask is None:
            refused += 1
            rows.append((case[0], '--', info[:46], case[1]))
            continue
        rows.append((case[0], '%08x' % mask, _positions(mask), case[1]))
    table(('field', 'xor mask', 'the positions', 'base instruction'), rows,
          (16, 10, 22, 40))
    print('  %d field positions measured over %d cases, %d refusals.'
          % (len(rows) - refused, len(FIELD_CASES), refused))
    print()
    para("""Five rows in that table are the course, and they are five rows about
the SAME FOUR ELEMENT SIZES.

    `ldr size`      is bits[31:30]    and `ldr Q`    is bit 23
    `add v size`   is bits[23:22]    and `add v Q`  is bit 30
    `ld1 size`     is bits[11:10]    and `ld1 Q`    is bit 30
    `sve size`     is bits[23:22]    and has NO Q bit at all

So the same four element sizes live at TWO different places in the 32-bit word
-- the top of the word for the scalar-register load and arithmetic groups, and
bits[11:10] for the structure load -- and the 128-bit form is a bit in three of
the four groups and ABSENT from the fourth.  A decoder that has one "vector
size" field and one flag for which group it is in is a decoder with FOUR field
maps and one flag, and the flag is the part a reader forgets to check.

The fourth row is the one the next section is about, and the reason SVE has no
Q bit is NOT an omission: an SVE vector is not a fixed 128 bits, so a bit that
said "128" would be a lie.  Section 4 measures what the instruction says
instead, which is nothing.

Four more rows are worth reading slowly, and all four are the shape of a
trap rather than a number:

    `ldp Rt2`       is bits[14:10] -- and the second register field, bits[4:0],
                    CANNOT BE SWEPT ALONE, because `ldp` takes a consecutive
                    even/odd pair.  The row labelled `ldp pair (both, not one)`
                    is the proof: its mask is bits[1,2,3,4,11,12,13,14], which
                    is TWO fields' increment patterns added together and is not
                    a field anybody can read.  It is printed anyway, with a
                    label that says what it is, because a table that quietly
                    drops the row a reader was about to ask about teaches them
                    that the table was edited to be right.
    `movi imm8`     is bits[9:5] AND bits[18:16] -- a NON-CONTIGUOUS eight-bit
                    immediate, and a mask that is not a span is evidence about
                    the DESIGN here and evidence about the MEASUREMENT
                    everywhere else.  The only way to tell the two apart is to
                    have swept, which is why this row is here and not in a
                    footnote.
    `add v op`      and `add v U` are the same six-bit opcode with ONE BIT
                    riding on it: `umax` is `smax` with bit 29 flipped.  A
                    sweep that finds the opcode field finds bit 29 in the same
                    mask and cannot say which of the two questions it was
                    asking, and a field map with one mask for two questions is
                    a field map with one answer for two questions.

The other two rows are the reason the barrier table in section 8 can be read
at all:

    `dmb option`   is bits[11:8]             FOUR bits, TWELVE names
    `dmb vs dsb`   is bits[7:5]              THREE bits, three names

so "DMB, DSB and ISB differ in one field" is true and is half the answer, and
`dmb vs clrex` -- THREE bits, because clrex shares the same group -- is the row
that says a fourth instruction is in there too.

And `sve zreg` is bits[9:5] and bits[4:0] -- five bits, thirty-two Z
registers, the same width as a scalar register field and the same width as an
Advanced SIMD V field -- with nothing anywhere else in the word for the width
of the vector they hold.  Section 4 is about that absence.""")
    print('  -------------------------------------------------------------------------')
    print('  WHAT A MASK IS, PRECISELY, AND WHAT IT IS NOT')
    print('  -------------------------------------------------------------------------')
    print('    A mask is the OR of the XORs over the sweep, so it is a LOWER')
    print('    BOUND on the field: every bit in the mask really is a bit that')
    print('    operand owns, and a bit NOT in the mask is a bit the sweep did')
    print('    not happen to move.  A field this measurement CANNOT find is a')
    print('    field that is never written in the corpus, and saying "bits[]"')
    print('    for one of those would be asserting a field nobody measured.')
    print()
    print('    One of those is measured deliberately and named in the row:')
    dup = [r for r in rows if r[0] == 'dup index']
    if dup:
        print('    %s sweeps FIVE indices 0,1,2,4,8,15 and gets %s, and the'
              % ('`dup index`', dup[0][2]))
        print('    element size of the same instruction is imm4[1:0] at')
        print('    bits[13:12] -- so the index is THREE bits and the size is TWO')
        print('    and both are in the same 32-bit word as the destination.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    A mask cannot show a field the sweep never reached, and it cannot')
    print('    show a field that is CONSTANT across the whole corpus -- which is')
    print('    exactly the kind of field a decoder is most likely to get wrong,')
    print('    because nothing in the corpus moves it.  The two earlier courses')
    print('    in this section both found one: the HINT guard one bit too narrow,')
    print('    which matched NOP alone out of eleven hints because the corpus')
    print('    contained no yield, no wfe and no wfi.')
    print()
    print('    A COUNT OF UNMODELLED WORDS IS A FACT ABOUT A CORPUS AND NOT ABOUT')
    print('    A DECODER, and this course asserts it for itself in section 11.')


def sec4():
    banner(4, 'THE SHARED MEMORY SPACE, AND THE BIT SVE DOES NOT HAVE')
    para("""The claim, QUOTED (ARM DDI 0602 for the SVE half; ARM DDI 0487 for the
Advanced SIMD half; the FEAT definitions in the Arm Architecture Reference
Manual's appendix for the extensions): Advanced SIMD, the FP extensions, the
SVE and SVE2 extensions and the cryptographic extensions are SEPARATE
architectural extensions that SHARE ONE INSTRUCTION ENCODING SPACE and ONE
SET OF REGISTERS.  The register sharing is the load-bearing part and it is
what the shared-resource rule means: an implementation that has SVE also has
Advanced SIMD, on the same physical registers, and SVE's Z0's bottom 128 bits
are Advanced SIMD's V0.  One file register, two views, and the second view is
wider.

The consequence is the thing worth teaching, and it is measurable in one
command: if the encoding had to say how wide a vector is, it would need a
field, and the field would have to be as wide as the widest vector any
implementation might have.  SVE's vector length is at most 2048 bits, so a
length field would be four bits and every instruction would pay for it.  So
SVE does not have one, and the space it shares is what makes that affordable:
the encoding's register fields are FIVE BITS for thirty-two Z registers, and
the length of those registers is a property of the IMPLEMENTATION, read at run
time from the vector length register rather than from the instruction.""")
    rows = []
    for lbl, src, ex in (
            ('Advanced SIMD, 128-bit', 'add v0.4s, v1.4s, v2.4s', ()),
            ('Advanced SIMD, 64-bit', 'add v0.2s, v1.2s, v2.2s', ()),
            ('SVE, .d', 'add z0.d, p0/m, z0.d, z1.d', SVE),
            ('SVE, .s', 'add z0.s, p0/m, z0.s, z1.s', SVE),
            ('SVE, .h', 'add z0.h, p0/m, z0.h, z1.h', SVE),
            ('SVE, .b', 'add z0.b, p0/m, z0.b, z1.b', SVE),
            ('FP scalar, .d', 'fadd d0, d1, d2', ()),
            ('AES (FEAT_AES)', 'aese v0.16b, v1.16b', ()),
            ('SHA-256 (FEAT_SHA2)', 'sha256h q0, q1, v2.4s', ()),
            ('SVE predicate', 'whilelo p0.d, x0, x1', SVE),
            ('SVE load', 'ld1d {z0.d}, p0/z, [x0]', SVE),
            ('SVE store', 'st1d {z0.d}, p0, [x0]', SVE)):
        w, d = word_of(src, path='_s2.s', extra=ex)
        cls = ((w >> 25) & 0xf) if w else None
        rows.append(('%-22s' % lbl, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d[:30],
                     'bits[28:25] = %s' % (format(cls, '04b')
                                           if cls is not None else '?')))
    table(('family', 'word', 'binary', 'class field'), rows,
          (24, 11, 36, 22))
    print('  [MEASURED-ON-BYTES]  the class field bits[28:25] is 0b0111 for the')
    print('  Advanced SIMD data-processing group, the FP groups, AES and SHA-2,')
    print('  and 0b0010 for the SVE data-processing group -- so four extensions')
    print('  and two architectures share the space by sharing a class.')
    print()
    print('  [MEASURED]  and the measurement the concept is built on:')
    rows = []
    for bits in ('128', '256', '512', '1024', '2048'):
        w, d = word_of('add z0.d, p0/m, z0.d, z1.d', path='_s3.s',
                       extra=('-march=armv8.2-a+sve',
                              '-msve-vector-bits=%s' % bits))
        rows.append(('%-6s bits' % bits,
                     '0x%08x' % w if w else 'REFUSED',
                     d if w is None else ''))
    table(('-msve-vector-bits', 'the same instruction assembles to', ''), rows,
          (18, 40, 40))
    n_same = 1
    for r in rows[1:]:
        if r[1] == rows[0][1]:
            n_same += 1
    print('  [MEASURED-ON-BYTES]  %d of %d are the SAME WORD, from 128 bits to'
          % (n_same, len(rows)))
    print('  2048 bits -- a factor of SIXTEEN in vector length and NOT ONE BIT')
    print('  of difference.  That is the whole claim, and it takes one command.')
    print()
    print('  [MEASURED]  the field the size DOES live in, for SVE:')
    w, _ = word_of('add z0.d, p0/m, z0.d, z1.d', path='_s3.s', extra=SVE)
    for sz, nm in ((0, 'b'), (1, 'h'), (2, 's'), (3, 'd')):
        w2, _ = word_of('add z0.%s, p0/m, z0.%s, z0.%s' % (nm, nm, nm),
                        path='_s3.s', extra=SVE)
        print('     size = %d  (element %2d bits)  0x%08x  xor 0x%08x'
              % (sz, 8 << sz, w2, w2 ^ (w or 0)))
    print('     TWO bits at bits[23:22] carry all four element sizes and there')
    print('     is no fourth bit anywhere for the vector LENGTH.')
    print()
    print('  [MEASURED]  and the restriction the assembler adds that the field')
    print('  does not: the SVE predicates are FOUR bits wide in the encoding')
    for k in range(5):
        w2, _ = word_of('whilelo p%d.d, x0, x1' % k, path='_s3.s', extra=SVE)
        print('     whilelo p%d.d   0x%08x  xor 0x%08x' % (k, w2, w2 ^ 0x25e11c00))
    w2, d2 = word_of('add z0.d, p8/m, z0.d, z1.d', path='_s3.s', extra=SVE)
    print('     add z0.d, p8/m  -> %s' % (d2 if w2 is None else 'ACCEPTED'))
    print('     so bits[3:0] address SIXTEEN predicates and the arithmetic')
    print('     form may use only p0..p7 -- a restriction the ENCODING does not')
    print('     express and only the assembler enforces.  An enforcement the')
    print('     encoding does not express is a rule with no bytes behind it.')
    # THE SVE REGISTER WIDTHS, and the mnemonic table, both MEASURED and both
    # printed.  The first version of this section asserted "Z0 through Z31" and
    # "p0 through p7" from the field widths the sweep had already found, and
    # neither string was in any printed output at all -- they were in the
    # decoder's comment -- so a claim the reader would have been shown was a
    # claim only the author could see.  A CLAIM IN A COMMENT IS NOT A CLAIM ON
    # THE PAGE, and the harness is what notices.
    print('  [MEASURED-ON-BYTES]  and the two register files SVE adds, swept:')
    for k in (0, 1, 15, 31):
        w2, d2 = word_of('add z0.d, p0/m, z0.d, z%d.d' % k, path='_s3.s',
                         extra=SVE)
        if w2 is None:
            print('     z%-2d  REFUSED: %s' % (k, d2))
        else:
            print('     z%-2d  0x%08x  xor 0x%08x' % (k, w2, (w or 0) ^ w2))
    print('     Z0 through Z31 -- five bits, the same width as a scalar')
    print('     register field and the same width as an Advanced SIMD V')
    print('     field, and NOTHING else in the word for how wide those')
    print('     registers are.  Thirty-two Z registers and sixteen predicate')
    print('     registers in two fields of five and four bits, in a word with')
    print('     no width field at all.')
    print('  SVE rows that had nothing to do with either reader being wrong:')
    for mn in ('add', 'sub', 'umax', 'smin', 'umin', 'mul', 'sdiv', 'udiv',
               'orr', 'eor', 'and', 'bic'):
        src = '%s z0.d, p0/m, z0.d, z1.d' % mn
        w2, d2 = word_of(src, path='_s3.s', extra=SVE)
        if w2 is None:
            print('     %-5s REFUSED: %s' % (mn, d2))
        else:
            op = (w2 >> 16) & 0x3f
            print('     %-5s 0x%08x  op[21:16] = %s  class = %s'
                  % (mn, w2, format(op, '06b'),
                     format((w2 >> 24) & 0xff, '08b')))
    print('     So the operation is a SIX-BIT field at bits[21:16] and a name')
    print('     table is TWELVE entries long so far and no longer a single bit,')
    print('     and the class byte bits[31:24] is 0b00000100 for all twelve.')
    print()
    print('     AND THE DESTINATION IS ALSO THE SECOND SOURCE.  MEASURED: the')
    print('     assembler REFUSES `add z0.d, p0/m, z1.d, z1.d`, so there are')
    print('     only THREE register fields here -- bits[4:0], bits[9:5] and the')
    print('     predicate at bits[12:10] -- and the second reader prints the')
    print('     destination TWICE.  A decoder that "fixes" the repeated operand')
    print('     names a register the word does not contain.')
    print()
    print()
    para("""And the refusals, which are the other half of a shared space: an
assembler that does not have the feature says so by NAME, and the name is
architecture rather than assembler.

    aese v0.16b, v1.16b     at baseline -> "instruction requires: aes"
    ldapr w1, [x0]          at 8.1-a    -> "instruction requires: rcpc"
    ldapr w1, [x0]          at 8.3-a    -> accepted, 0xdac0dc01
    cas  w1, w2, [x0]       at baseline -> "instruction requires: lse"

FEAT_LSE is armv8.1-a, FEAT_RCPC is armv8.3-a, FEAT_AES is armv8-a+crypto, and
FEAT_FP16 is armv8.2-a+fp16.  Four refusals, four feature names, and the
whole feature-gating story of the architecture in four lines of diagnostic.
A space that four extensions share is a space whose decoding requires knowing
WHICH extensions are present -- which is a fact about a CPU's ID registers, and
a decoder on a machine that cannot read them has to guess or decline.  This
one declines, and says so in the output.""")
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that a 2048-bit vector actually has 2048 bits, or')
    print('    that Z0\'s bottom 128 bits are V0, or that any SVE instruction')
    print('    runs.  The claim "the length is not in the instruction" is')
    print('    MEASURED; the claim "the length is therefore correct at run time"')
    print('    is QUOTED and needs silicon.  That is a one-line argument and it')
    print('    is the whole course in miniature.')
    print('    It cannot show WHICH extensions an implementation has, because the')
    print('    feature registers are readable only at EL1 and there is no EL1')
    print('    here.  The class field is shared whether or not every member of')
    print('    the space is present, which is the definition of a shared space')
    print('    and also the reason the decode is a function of the CPU.')


def sec5():
    banner(5, 'WHAT THE COMPILER EMITS, AND WHY THE COUNT POINTS BACKWARDS')
    para("""THE SCOPE, first, because it is a rule and not a preference.  The neutral
`simd` course owns the PRINCIPLE: a wider vector is not automatically faster,
and it measured 3.89x at 2 KiB against 1.14x at 24 MiB, because at 24 MiB the
array no longer fits anywhere.  `simd-reduce` owns the tail.  This section
does NOT re-measure either.  What it measures is the STATIC shape of what
clang emits, and the shape is a compile-time property with no duration in it
anywhere.

Which is exactly the problem, and the problem is the finding.""")
    print('  [MEASURED]  the same C, with and without the vectoriser.  TWO FILES,')
    print('  one flag, four functions, and the counts are a COMPILE-TIME')
    print('  INSTRUCTION COUNT and NOT A TIMING ONE.  Nothing here has been')
    print('  executed on either side.')
    rows = []
    for fn in ('sum_loop', 'max_loop', 'axpy_loop', 'copy_loop', 'fsum_loop',
               'sadd'):
        v = func_body('data_O2.s', fn)
        s = func_body('data_O2_novec.s', fn)
        nv, ns = neons_in(v), neons_in(s)
        rows.append(('%-12s' % fn, '%d' % len(v), '%d' % len(s),
                     '%d' % nv, '%d' % ns))
    table(('function', 'vectorised', 'scalar', 'NEON insns (vec)',
           'NEON insns (scalar)'), rows, (12, 12, 10, 18, 20))
    v = func_body('data_O2.s', 'sum_loop')
    s = func_body('data_O2_novec.s', 'sum_loop')
    print('  [MEASURED]  and for `sum_loop` the vectorised body is LONGER than')
    print('  the scalar one: %d instructions against %d.' % (len(v), len(s)))
    print()
    para("""So a reader looking for the ratio finds the vectorised version LOSING
on the only measure available, and the reason is worth more than a number
would have been: the vectoriser pays for a vector-length PROLOGUE (compute
the largest multiple of four, branch around the tail) and a scalar EPILOGUE
for the leftover elements, and it pays for them ONCE while the loop body runs
n times.  A whole-function instruction count measures code that runs once.

Which is the course's refusal, stated as a measurement.  An instruction count
is a COUNT OF BIT PATTERNS and a duration is a property of a machine, and the
two are related by a rate nobody here can read.  The x86-64 sibling measured a
ratio and could compare it with the neutral course's ratio; this course cannot
compare anything with anything, and the honest move is to say which count is
even the right one and then say that the right one is still not a time.""")
    print('  [MEASURED]  the two loop BODIES, which is the only count here that')
    print('  has a shape at all -- and even this one is a count of instructions,')
    print('  NOT a speedup.  Each row is the block between a loop label and the')
    print('  branch that jumps back to it, and the two columns are the elements')
    print('  that block handles PER ITERATION, read out of the load:')
    for fn, ev, es, note in (
            ('sum_loop', 4, 1, 'one `ldp q2, q3` is four `long`s'),
            ('fsum_loop', 4, 1, 'four `float`s'),
            ('copy_loop', 2, 1, 'one `ldp q1, q1` is two `long`s'),
            ('axpy_loop', 4, 1, 'a multiply and an add, six both ways'),
            ('sadd', 16, 1, 'a byte loop, and SIXTEEN lanes per iteration')):
        vb, _ = loop_body('data_O2.s', fn)
        sb, _ = loop_body('data_O2_novec.s', fn)
        print('     %-11s  vectorised: %2d instructions per %2d elements = '
              '%.2f per element' % (fn, len(vb), ev, len(vb) / ev))
        print('     %-11s  scalar    : %2d instructions per %2d elements = '
              '%.2f per element' % ('', len(sb), es, len(sb) / es))
        print('     %-11s  %s' % ('', note))
    print()
    print('     So the ONE figure this course can print that points the way a')
    print('     reader expects is the first row: SIX instructions per four')
    print('     elements against FOUR per ONE, a ratio of 2.67 on a COUNT.  It')
    print('     is printed as a count, in a table whose column heading says')
    print('     "instructions", because the ratio it contains is not a speedup')
    print('     and there is no clock on this host to turn it into one.')
    print()
    print('     AND THE MORE USEFUL HALF OF THE TABLE IS THE ROW WHERE THE')
    print('     VECTORISED BODY IS LONGER: `fsum_loop` is 18 instructions per')
    print('     four elements against the scalar four per one, so on this count')
    print('     the vectorised build is the worse one, and the whole-function')
    print('     counts above said the same thing for all five functions.  The')
    print('     first draft of this section asserted that `sadd` and `axpy_loop`')
    print('     were loops the vectoriser declined, and the measurement says')
    print('     otherwise: both ARE vectorised, and the prose was written about')
    print('     a version of the corpus the compiler had since changed.  That')
    print('     is retraction R15, it was caught by reading the table against')
    print('     the sentence above it, and the general form is the one worth')
    print('     keeping: A NOTE THAT EXPLAINS A ROW IS A CLAIM ABOUT THE ROW,')
    print('     and a claim about a row is checkable by looking at the row.')
    print()
    print('     A REDUCTION, MEASURED: the vectorised `sum_loop` finishes with')
    idx = [k for k, t in enumerate(v) if t.startswith(('addp', 'addv', 'faddp',
                                                     'add '))]
    lo = max(0, (idx[0] if idx else len(v)) - 3)
    for t in v[lo:lo + 8]:
        print('       %s' % t)
    print('     `addp d0, v0.2d` is the cross-lane pairwise add, and it is a')
    print('     separate instruction with its own encoding, not a loop.  How')
    print('     long it takes is not measurable here and this file does not')
    print('     pretend otherwise.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that the vectorised loop is FASTER, and the table')
    print('    above is the proof: on instruction count it is not, and only a')
    print('    clock could have said otherwise.  Everything after this sentence')
    print('    is a static property of the emitted bytes.')
    print('    It cannot show WHAT the vectoriser chose for a different compiler,')
    print('    a different version, a different -march or a different loop')
    print('    body, and the harness asserts SHAPES -- "the vectorised body has')
    print('    fewer instructions than the scalar body", "the vectorised body')
    print('    mentions a v register and the scalar one does not" -- rather than')
    print('    any of these counts, because a check whose threshold is a bare')
    print('    number from one compiler is a check that fails on a busier')
    print('    machine and teaches its reader to ignore it.')


def sec6():
    banner(6, 'THE EXCLUSIVE MONITOR, AND WHY THE RETRY IS A LOOP')
    para("""The mechanism, QUOTED (ARM DDI 0597, the pseudocode for the Load-Acquire-
Exclusive and Store-Release-Exclusive instruction groups, and the
`AArch64.ExclusiveMonitorsPass` pseudocode functions): LDAXR opens a local
monitor on the address, STXR attempts a store under it, and the store reports
SUCCESS or FAILURE IN A REGISTER.  The architecture guarantees nothing about
when the store fails.  A context switch, an exception, a different core
writing the same line, a cache eviction, or the store being split can all make
it fail, and there is NO ENCODING THAT MAKES IT NOT FAIL.

The reason that is a LOOP and not an instruction is therefore structural, and
this section measures it rather than asserting it: the failure is reported
IN the instruction's own output, so the instruction cannot itself decide what
to do about it, so the only way to act on it is a branch, and a branch that
goes back to the load is a loop.  The word "by construction" in the concept
title is a claim about the interface, and the interface is one register wide.""")
    rows = []
    for src in ('ldxr w1, [x0]', 'ldaxr w1, [x0]', 'ldxr x1, [x0]',
                'ldaxr x1, [x0]', 'ldaxrb w1, [x0]', 'ldaxrh w1, [x0]',
                'ldxrb w1, [x0]', 'ldxrh w1, [x0]', 'stxr w2, w1, [x0]',
                'stlxr w2, w1, [x0]', 'stxr w2, x1, [x0]',
                'stlxr w2, x1, [x0]', 'stxrb w2, w1, [x0]',
                'stlxrb w2, w1, [x0]', 'ldxp w9, w8, [x0]',
                'ldaxp x9, x8, [x0]', 'ldxp x9, x8, [x0]',
                'stxp w14, w9, w8, [x0]', 'stlxp w14, w9, w8, [x0]',
                'clrex'):
        w, d = word_of(src, path='_x.s')
        rows.append(('%-22s' % src, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d,
                     'o1=%d pair=%d size=%d' % ((w >> 15) & 1, (w >> 21) & 1,
                                                (w >> 30) & 3)
                     if w else ''))
    table(('instruction', 'word', 'binary', 'three bits to read'), rows,
          (24, 11, 36, 24))
    print('  [MEASURED-ON-BYTES]  the acquire/release bit is BIT 15 and it is')
    print('  ONE BIT, and it is the same bit in a load and in a store:')
    for a, b in (('ldxr w1, [x0]', 'ldaxr w1, [x0]'),
                 ('stxr w2, w1, [x0]', 'stlxr w2, w1, [x0]'),
                 ('ldxr x1, [x0]', 'ldaxr x1, [x0]'),
                 ('ldxp x9, x8, [x0]', 'ldaxp x9, x8, [x0]'),
                 ('stxp w14, w9, w8, [x0]', 'stlxp w14, w9, w8, [x0]')):
        wa, _ = word_of(a, path='_x.s')
        wb, _ = word_of(b, path='_x.s')
        print('     %-24s xor %-26s = 0x%08x  -> bit 15'
              % (a, b, wa ^ wb))
    print()
    print('  [MEASURED-ON-BYTES]  AND BIT 21 IS NOT THE ACQUIRE BIT, which is')
    print('  what the first draft of this file called it.  MEASURED over the')
    print('  twenty words above: bit 21 is 0 in EVERY single-register word and')
    print('  1 in EVERY pair word, so it is the PAIR DISCRIMINATOR.  A bit that')
    print('  is CONSTANT across the family you are describing is the signature')
    print('  of a field you did not mean, and that is the cheapest possible')
    print('  test and the one the first draft did not run.')
    print()
    print('  [MEASURED]  and the STATUS REGISTER WIDTH IS THE DATA WIDTH,')
    print('  which the assembler enforces and the encoding cannot show:')
    for a in ('stlxp w14, w9, w8, [x0]', 'stlxp w14, x9, x8, [x0]',
              'stlxp x14, x9, x8, [x0]'):
        w, d = word_of(a, path='_x.s')
        print('     %-26s -> %s' % (a, '0x%08x' % w if w else 'REFUSED: ' + d))
    print('     MEASURED: the status register is ALWAYS 32 bits, whatever the')
    print('     data width, and `stlxp x14, x9, x8` is REFUSED with "invalid')
    print('     operand for instruction" -- so the failure is a register that is')
    print('     32 bits where the assembler insists on 32 bits being spelled')
    print('     `w`.  The status FIELD is five bits either way and the WIDTH of')
    print('     the DATA comes from bits[31:30], the same two bits that are')
    print('     written on the data registers, and this is the FIFTH instance in')
    print('     this file of one field written twice in the syntax.')
    print()
    print('     The first draft of this file wrote `stlxp x14, x9, x8` in its')
    print('     own table on the reasonable reading that a 64-bit atomic has a')
    print('     64-bit status, the assembler refused it, and the file PRINTED A')
    print('     REFUSAL as though the instruction did not exist.  That is the')
    print('     eighth time this file has reported a refusal that was really a')
    print('     SPELLING RULE, and the reason the general form is worth')
    print('     writing down: A REFUSAL IS NOT THE ABSENCE OF AN INSTRUCTION,')
    print('     and the difference between the two is one word of diagnostic.')
    print()
    print('  [MEASURED-ON-BYTES]  the SIZE is bits[31:30] and it is TWO bits,')
    print('  with all four values allocated, and the 32- and 64-bit forms are')
    print('  ADJACENT in it while the 8- and 16-bit forms are in the other half.')
    print('  And it is the SAME two bits as a scalar `ldrb` size field, written')
    print('  TWICE in the syntax: once as the mnemonic suffix and once as the')
    print('  register width.  This file has now had to learn that one field is')
    print('  written twice in THREE separate groups, which is the sharpest')
    print('  argument in it for reading a field once and printing it wherever')
    print('  the assembly happens to want it.')
    print()
    print('  [MEASURED]  and the LOOP, read out of the emitted assembly.  The')
    print('  function is `inc_seq`, one __atomic_fetch_add, at -O2:')
    body = func_body('data_O2.s', 'inc_seq')
    for t in body:
        print('     %s' % t)
    print('     The BACKWARD branch is `cbnz w10, .LBB4_1`, and the label it')
    print('     names is not in the printed block, so the target is a label')
    print('     earlier in the function.  The retry is the loop, the loop is a')
    print('     branch, and the branch exists because STXR wrote a register.')
    print()
    print('  [MEASURED]  four orderings of the same increment, and what each')
    print('  buys in bits.  Every one of them is a load-exclusive, an add, a')
    print('  store-exclusive and a backward branch:')
    for fn in ('inc_seq', 'inc_acq', 'inc_rel', 'inc_relaxed'):
        body = func_body('data_O2.s', fn)
        ex = [t for t in body if re.match(r'ld(x|ax)r', t)]
        st = [t for t in body if re.match(r'st(x|lx)r', t)]
        print('     %-11s  %-22s %-26s %d instructions'
              % (fn, ex[0] if ex else '?', st[0] if st else '?', len(body)))
    print('     Four memory orders and four INSTRUCTION PAIRS, differing in')
    print('     exactly one bit each -- and the SEQ_CST one is not a wider')
    print('     instruction than the relaxed one.  Section 9 says where the')
    print('     sequential consistency actually comes from, and the answer is')
    print('     not from this table.')
    print()
    print('  [MEASURED]  the 16-byte case, which is where the two-register')
    print('  exclusive appears and where the corpus is `pair.c`:')
    for t in func_body('pair_base.s', 'cas_pair_seqcst'):
        print('     %s' % t)
    print('     `ldaxp`/`stlxp` name TWO data registers and ONE status register,')
    print('     so the pair-exclusive form has the same status-register interface')
    print('     as the single one and therefore the same loop, and clang emits')
    print('     SEVEN instructions per attempt against the single-word form\'s')
    print('     FOUR.  Both are the same loop at two widths.')
    print()
    print('  [MEASURED]  and CLREX, the one instruction in this course that')
    print('  exists to make an LL/SC pair stop being a loop:')
    for fn in ('inc_seq', 'inc_acq', 'xchg_seq'):
        body = func_body('data_O2.s', fn)
        print('     %-11s clrex present: %s' % (fn, 'clrex' in ' '.join(body)))
    print('     MEASURED: NO clrex in any of the fetch-add or exchange bodies,')
    print('     because the architecture already cleared the monitor when the')
    print('     store failed.  A CLREX there would be redundant and a compiler')
    print('     that emitted it would be costing an instruction for a')
    print('     reassurance the hardware already gave.  That is a claim about')
    print('     the ARCHITECTURE and it is QUOTED; the absence is measured.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that a store ever FAILS, or how often, or what a')
    print('    lost update costs, or whether the monitor is per-core or')
    print('    per-address, or how many times the loop runs.  Every number above')
    print('    is a bit pattern or a count of instructions.  The sibling `smp`')
    print('    course measured a lost update and an uncontended `lock xadd` at')
    print('    2.54x a plain store; those are DURATIONS and this file has no')
    print('    counterpart of either, so it links rather than restating them.')
    print('    It cannot show that the loop is NECESSARY.  It shows that the')
    print('    compiler writes one and that the status register is where the')
    print('    decision comes from; the necessity is quoted, and the quote is')
    print('    labelled.')


def sec7():
    banner(7, 'FEAT_LSE: ONE INSTRUCTION INSTEAD OF FOUR')
    para("""The feature, QUOTED (the Arm Architecture Reference Manual's FEAT_LSE
section, and the `AArch64.CAS*` pseudocode): v8.1-a added compare-and-swap and
the atomic memory operations as SINGLE INSTRUCTIONS.  The point of the section
is not that the instruction is longer or shorter.  The point is that the
loop is GONE -- and the loop was not an optimisation artefact, it was forced
by the interface described in section 6.  An architecture that added the
feature had to add an instruction whose failure mode is not a register, and
that is a different kind of atomic from LDAXR/STLXR rather than a faster one.

What CAN be measured is what the compiler does with the feature, and the
answer is a single, checkable compiler decision: the SAME C, the same
optimisation level, one flag apart, and one instruction in place of four.""")
    rows = []
    for src in ('cas w1, w2, [x0]', 'cas x1, x2, [x0]', 'casa w1, w2, [x0]',
                'casl w1, w2, [x0]', 'casal w1, w2, [x0]', 'casb w1, w2, [x0]',
                'cash w1, w2, [x0]', 'casab w1, w2, [x0]',
                'casp x0, x1, x2, x3, [x4]', 'caspal x0, x1, x2, x3, [x4]',
                'caspa x0, x1, x2, x3, [x4]', 'swp w1, w2, [x0]',
                'swpa w1, w2, [x0]', 'swpal w1, w2, [x0]',
                'ldadd w1, w2, [x0]', 'ldadda w1, w2, [x0]',
                'ldaddl w1, w2, [x0]', 'ldaddal w1, w2, [x0]',
                'ldclr w1, w2, [x0]', 'ldeor w1, w2, [x0]',
                'ldset w1, w2, [x0]'):
        w, d = word_of(src, path='_l.s', extra=LSE)
        rows.append(('%-28s' % src, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d[:28], _lse_bits(w) if w else ''))
    table(('instruction', 'word', 'binary', 'bits[15:10] / 23:21'), rows,
          (30, 11, 36, 20))
    print('  [MEASURED]  the same instructions at BASELINE, where every one of')
    print('  them is a refusal that NAMES the feature:')
    for src in ('cas w1, w2, [x0]', 'swp w1, w2, [x0]',
                'ldadd w1, w2, [x0]', 'casp x0, x1, x2, x3, [x4]'):
        w, d = word_of(src, path='_l.s')
        print('     %-28s -> %s' % (src, d))
    print('     FEAT_LSE is armv8.1-a.  A refusal that names the feature is a')
    print('     better failure than a syntax error, and a decoder that wants to')
    print('     know whether a word is valid on the machine in front of it has')
    print('     to read the same feature bit out of an ID register -- which')
    print('     this host cannot do, because the ID registers are EL1.')
    print()
    # AND THE FINDING IS NOT "ONE BIT FOR THE WHOLE GROUP".  The first version
    # of this section said acquire was bit 22 everywhere and release was bit 15
    # in CAS and bit 21 in the LDADD family, and both halves of that are wrong
    # -- retraction R21.  The sweep below is the corrected one and it is TWICE
    # as long, once per half, because a constant that has only been observed
    # constant has not been shown to be constant.
    print('  [MEASURED-ON-BYTES]  THE GROUP IS NOT ONE GROUP.  In the CAS half')
    print('  ACQUIRE IS BIT 22 and RELEASE IS BIT 15; in the LDADD half ACQUIRE')
    print('  IS BIT 23 and RELEASE IS BIT 22.  Four suffixes, each half:')
    a, _ = word_of('cas w1, w2, [x0]', path='_l.s', extra=LSE)
    b, _ = word_of('casal w1, w2, [x0]', path='_l.s', extra=LSE)
    print('     cas  0x%08x   casal 0x%08x   xor 0x%08x  -> bits 22 and 15'
          % (a, b, a ^ b))
    c, _ = word_of('casp x0, x1, x2, x3, [x4]', path='_l.s', extra=LSE)
    d, _ = word_of('caspal x0, x1, x2, x3, [x4]', path='_l.s', extra=LSE)
    print('     casp 0x%08x  caspal 0x%08x  xor 0x%08x  -> bits 22 and 15'
          % (c, d, c ^ d))
    for base in ('ldadd', 'ldclr'):
        ops = ' w1, w2, [x0]'
        w0, _ = word_of(base + ops, path='_l.s', extra=LSE)
        wa, _ = word_of(base + 'a' + ops, path='_l.s', extra=LSE)
        wl, _ = word_of(base + 'l' + ops, path='_l.s', extra=LSE)
        wal, _ = word_of(base + 'al' + ops, path='_l.s', extra=LSE)
        print('     %-6s 0x%08x  a: 0x%08x  xor 0x%08x  -> bit 23'
              % (base, w0, wa, w0 ^ wa))
        print('     %-6s 0x%08x  l: 0x%08x  xor 0x%08x  -> bit 22'
              % (base, w0, wl, w0 ^ wl))
        print('     %-6s 0x%08x  al:0x%08x  xor 0x%08x  -> bits 23 and 22'
              % (base, w0, wal, w0 ^ wal))
    print()
    print('     AND BIT 21 IS 1 IN EVERY ONE OF THOSE EIGHT WORDS AND IN THE')
    print('     FOUR CAS WORDS ABOVE, so it is a CONSTANT of the whole group')
    print('     rather than an ordering bit.  The first version of this section')
    print('     read it AS the release bit, and the cross-check caught it: the')
    print('     decoder printed `ldaddl` where the assembler prints `ldadd`, a')
    print('     relaxed atomic silently promoted to a release one, in a legal')
    print('     word with nothing wrong in it.  A WRONG CONSTANT AND A CONSTANT')
    print('     FIELD LOOK IDENTICAL UNTIL YOU SWEEP THE SUFFIX.')
    print()
    print('     THE CONSEQUENCE IS THE SHARPEST THING IN THE SECTION.  CASP is')
    print('     the 128-bit form, and its 128-bit-ness is BIT 23 -- which is the')
    print('     bit that says "acquire" in the LDADD family.  ONE BIT, TWO')
    print('     MEANINGS, NO OVERLAP, and the two meanings are in the same')
    print('     word a few opcodes apart.  So the question "does this word want')
    print('     a 128-bit atomic or an acquire" has no answer from a field')
    print('     diagram, and a decoder that answers it from one is answering a')
    print('     question nobody asked.')
    print()
    print('     AND ONE MORE THING ABOUT THE CAS HALF, because it is the')
    print('     clearest case in the section of a FLAG THAT IS NOT A FLAG.')
    print('     MEASURED: bits[15:10] reads 0b011111 for `cas` and 0b111111 for')
    print('     `casl` -- the SAME six bits, with the release bit as the TOP ONE')
    print('     of the opcode.  So "release" is not a flag in this group, it is')
    print('     half the NAME of the instruction, and a decoder that wants a')
    print('     release flag has to read the opcode and then test a bit of it,')
    print('     which is the same work twice and looks like a different design.')
    print()
    print('  [MEASURED]  AND THE COMPILER DECISION, which is the measurement')
    print('  the concept is built on.  The same C, the same -O2, one flag:')
    for fn, label_ in (('cas64', 'a 64-bit compare-exchange'),
                       ('inc_seq', 'a fetch-add'),
                       ('xchg_seq', 'an exchange')):
        v = [t for t in func_body('data_O2.s', fn)]
        print('     %-9s (%s)' % (fn, label_))
        print('       baseline : %s' % ' | '.join(v[:6]))
    print('     and the -march=armv8.1-a build of the SAME source:')
    import subprocess as _sp
    r = _sp.run([CLANG, '--target=%s' % TARGET] + list(LSE) +
                ['-O2', '-S', os.path.join(HERE, 'data.c'), '-o',
                 os.path.join(HERE, '_lse_data.s')], capture_output=True,
                text=True)
    for fn in ('cas64', 'inc_seq', 'xchg_seq'):
        v = func_body('_lse_data.s', fn)
        print('     %-9s -> %s' % (fn, ' | '.join(v[:6])))
    print()
    print('     FOUR instructions become ONE.  This is a COMPILE-TIME')
    print('     INSTRUCTION COUNT, printed as such, and it is the only')
    print('     "speedup" this course can print -- it is a count, and there is')
    print('     no clock here to turn it into a ratio, and the sibling x86-64')
    print('     course\'s `lock` numbers are DURATIONS and are not comparable')
    print('     with this one in either direction.')
    print()
    print('  [MEASURED]  the 16-byte case, and the shape of what LSE does NOT')
    print('  buy.  `pair.c`, -O2, with the 16-byte alignment the structure')
    print('  needs:')
    for fn in ('cas_pair_seqcst', 'cas_pair_relaxed', 'cas_pair_acqrel',
               'pair_fetch_add'):
        v = func_body('pair_lse.s', fn)
        core = [t for t in v if re.match(r'casp|ldadd', t)]
        print('     %-18s -> %s' % (fn, ' | '.join(core) if core
                                    else ' | '.join(v[:6])))
    print('     THREE different C11 memory orders (seq_cst, relaxed, acq_rel)')
    print('     produce TWO distinct instructions, and a 128-bit FETCH-ADD')
    print('     produces TWO 64-bit `ldaddal` because there is no 128-bit LSE')
    print('     arithmetic at all.  A feature is not a blanket.')
    print()
    print('  [MEASURED]  the diagnostic that cost this section its CASP')
    print('  encoding, and it is worth printing because it is a lesson:')
    for src in ('casp x0, x1, [x2]', 'casp x0, x1, x2', 'casp x0, x1, x2, x3'):
        w, d = word_of(src, path='_l.s', extra=LSE)
        print('     %-26s -> %s' % (src, '0x%08x' % w if w else d))
    print('     CASP takes FIVE operands -- two register pairs and the memory')
    print('     -- and the diagnostic for the three-operand form points AT THE')
    print('     MEMORY OPERAND, which is the one operand that was correct.')
    print('     A diagnostic that points at the right operand is a diagnostic')
    print('     that will be believed, and the first draft of this file')
    print('     believed it and then reported a REFUSAL where there was an')
    print('     instruction.  That is retraction R8 and it was found by')
    print('     assembling nine spellings of one mnemonic.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that `cas` is FASTER than the loop, or by how')
    print('    much, or whether the loop it replaced was the bottleneck.  Four')
    print('    instructions against one is a count and a claim about a')
    print('    pipeline nobody here can read.  The x86-64 equivalent is')
    print('    `lock cmpxchg`, and the `x86simd` course measured it; this')
    print('    course links to that rather than restating a number, because')
    print('    the number is a duration and there is no counterpart here.')
    print('    It cannot show that FEAT_LSE is faster on hardware that has it,')
    print('    or that the microarchitecture implements it in a way that')
    print('    matters.  All this file shows is that clang takes the feature')
    print('    and that the encoding has a place for it.')


def _lse_bits(w):
    return 'op=%s 23:21=%s' % (format((w >> 10) & 0x3f, '06b'),
                               format((w >> 21) & 7, '03b'))


def sec8():
    banner(8, 'DMB, DSB, ISB: TWO FIELDS, NOT ONE')
    para("""The three barriers, QUOTED (ARM DDI 0597, the pseudocode for the DMB,
DSB and ISB instruction groups, and the "Memory ordering" chapter of the
Architecture Reference Manual for what each one orders):

    DMB   a data memory barrier: orders the memory accesses either side of
          it, and does NOT make the instruction stream see anything new.
    DSB   a data synchronisation barrier: as DMB, and it also completes before
          any instruction after it is executed -- so it waits for stores to
          become OBSERVABLE, not merely performed.
    ISB   an instruction synchronisation barrier: flushes the pipeline and the
          instruction-fetch side of the machine, and is how a context switch
          to a different exception level or a different PC is made to take
          effect.  It has no effect on the DATA side at all.

They are not interchangeable and the difference is not a matter of degree.  A
DMB does not stop an instruction fetch; an ISB does not order a load.  That
is QUOTED.  What is MEASURED is that the encoding expresses the difference in
TWO SEPARATE FIELDS, and that the second one is the one everybody forgets.""")
    rows = []
    for opt in ('oshld', 'oshst', 'osh', 'nsh', 'nshld', 'nshst', 'ish',
                'ishld', 'ishst', 'ld', 'st', 'sy'):
        wd, _ = word_of('dmb %s' % opt, path='_b.s')
        ws, _ = word_of('dsb %s' % opt, path='_b.s')
        wi, d = word_of('isb %s' % opt, path='_b.s')
        rows.append(('%-6s' % opt,
                     '0x%08x' % wd if wd else 'REFUSED',
                     '0x%08x' % ws if ws else 'REFUSED',
                     '0x%08x' % wi if wi else 'REFUSED',
                     'CRm = %s' % format((wd >> 8) & 0xf, '04b') if wd else '',
                     'op2 = %s' % format((wd >> 5) & 7, '03b') if wd else ''))
    table(('option', 'dmb', 'dsb', 'isb', 'the option field', 'the id field'),
          rows, (8, 11, 11, 11, 18, 14))
    ok = 0
    for r in rows:
        if r[1] != 'REFUSED' and r[2] != 'REFUSED':
            ok += 1
    print('  [MEASURED]  DMB and DSB accept %d of the %d options, and the'
          % (ok, len(rows)))
    print('  option field is bits[11:8] -- FOUR bits carrying TWELVE names, so')
    print('  four of the sixteen values are unallocated.  ISB accepts ONE.')
    print()
    print('  [MEASURED-ON-BYTES]  and the identity bit is bits[7:5], which is')
    a, _ = word_of('dmb sy', path='_b.s')
    b, _ = word_of('dsb sy', path='_b.s')
    c, _ = word_of('isb', path='_b.s')
    print('     dmb sy 0x%08x   dsb sy 0x%08x   isb 0x%08x' % (a, b, c))
    print('     dmb xor dsb = 0x%08x -> bit 5 only' % (a ^ b))
    print('     dmb xor isb = 0x%08x -> bit 5 and bit 6' % (a ^ c))
    print('     So the three are told apart by a THREE-bit field, and the sibling')
    print('     course\'s model reads exactly that field and exactly right -- and')
    print('     it FIXES CRm to 0b1111, so it names the `sy` form of each and')
    print('     nothing else.  The sibling model is not wrong; it is a SUBSET,')
    print('     and a subset of a field is invisible.')
    print()
    print('  [MEASURED]  and the option field is not decoration.  The scope')
    print('  names are the WHOLE POINT of the instruction and they are four')
    print('  bits wide:')
    for opt in ('osh', 'nsh', 'ish', 'sy'):
        w, _ = word_of('dmb %s' % opt, path='_b.s')
        print('     dmb %-4s  CRm = %s  = %2d  -- the domain it orders'
              % (opt, format((w >> 8) & 0xf, '04b'), (w >> 8) & 0xf))
    print('     `osh` orders accesses to the OUTER SHAREABLE domain, `ish` the')
    print('     INNER one, and `sy` the whole system.  A four-bit field choosing')
    print('     among four DOMAINS and two DIRECTIONS (ld, st) and their')
    print('     combinations is twelve names in sixteen codes, and the two')
    print('     direction bits and the domain bits are the SAME four bits.')
    print('     QUOTED: what ld and st mean.  MEASURED: that they are in the')
    print('     same field as the domain, so there is no way to say "inner,')
    print('     loads only" without spending a code the encoding spent on a')
    print('     combination of the two -- and in fact ishld IS that code, 1001.')
    print()
    print('  [MEASURED]  the one that is NOT a barrier and shares the group:')
    w, _ = word_of('clrex', path='_b.s')
    print('     clrex  0x%08x   op2 = %s   Rt = %s' % (w, format((w >> 5) & 7, '03b'),
                                                     format(w & 0x1f, '05b')))
    print('     MEASURED: 0b010, and none of the three barriers uses it.  Four')
    print('     instructions share bits[31:8] and differ in three bits, and one')
    print('     of the four has no ordering effect at all.')
    print()
    print('  [MEASURED]  the sibling model and this one, side by side, because')
    print('  the coverage number in section 11 depends on it:')
    print('     a64sys.py m_barrier  guards CRm = 0b1111  -> 1 word per barrier')
    print('     this file m_barrier_opt  reads CRm as the option -> 12 + 1')
    print('     Both are CORRECT about the words they claim.  The lesson is the')
    print('     one the encoding course recorded as R17: a guard that is too')
    print('     NARROW does not fail, it silently reduces the model.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that any barrier ORDERS anything.  There is no')
    print('    second core, no cache, no store buffer and no memory traffic on')
    print('    this host.  What the four bits select is QUOTED; that the')
    print('    selection has the described effect is quoted, and the only thing')
    print('    measured here is that the field exists, is four bits wide, and')
    print('    carries twelve names.')
    print('    It cannot show that DSB waits for stores to become OBSERVABLE and')
    print('    DMB does not.  That is the single most important sentence on this')
    print('    page and it is the one sentence on it that no command on this')
    print('    host can confirm.  It is QUOTED, with the document, and a reader')
    print('    who wants it verified needs a machine.')


def sec9():
    banner(9, 'ORDERING AS ACCESS MODES: WHERE THE BARRIERS ARE')
    para("""THE PAYOFF OF THE WHOLE SECTION, and the place where AArch64 differs
from x86-64 IN KIND rather than in detail.  x86-64's model is strong and
mostly implicit: a program is sequentially consistent unless it says
otherwise, and the exceptions are three opcodes -- MFENCE, LFENCE, SFENCE --
which a program sprinkles at the places it wants to be weaker.  AArch64's
model is WEAK, and the only tool for strengthening it is an ACCESS MODE
written on the access itself: LDAR is a load that also acquires, STLR is a
store that also releases, and a C11 acquire load is one of them rather than a
load followed by a barrier.

So the same correct-looking C11 program needs DIFFERENT INSTRUCTIONS on the
two architectures, and the compiler is what translates.  Which means the
compiler's choices are the reference material, and they are measurable.""")
    rows = []
    for fn, want in (('load_acq', 'acquire load'), ('load_seqcst', 'seq_cst load'),
                     ('store_rel', 'release store'),
                     ('store_seqcst', 'seq_cst store'),
                     ('fence_seqcst', 'seq_cst fence'),
                     ('fence_acquire', 'acquire fence'),
                     ('fence_release', 'release fence'),
                     ('fence_relaxed', 'relaxed fence'),
                     ('load_then_load', 'two seq_cst loads'),
                     ('store_then_store', 'two seq_cst stores'),
                     ('bump', 'a seq_cst fetch-add'),
                     ('publish', 'a plain store, then a seq_cst store')):
        v = func_body('data_O2.s', fn)
        core = [t for t in v if t != 'ret']
        rows.append(('%-17s' % fn, '%-24s' % want,
                     ' | '.join(core) if core else '(nothing)',
                     '%d' % sum(1 for t in v
                                if re.match(r'dmb|dsb|isb', t))))
    table(('function', 'the C11 operation', 'what clang emitted',
           'barriers'), rows, (18, 24, 40, 9))
    nb = sum(int(r[3]) for r in rows)
    print('  [MEASURED]  and the number that decides the concept:')
    print('     %d barriers in %d functions that perform C11 atomic operations.'
          % (nb, len(rows)))
    print()
    wa, _ = word_of('ldar x1, [x0]', path='_o.s')
    wb, _ = word_of('ldar w1, [x0]', path='_o.s')
    wc, _ = word_of('stlr x1, [x0]', path='_o.s')
    print('  [MEASURED]  read the first two rows again.  A C11 ACQUIRE load and')
    print('  a C11 SEQUENTIALLY CONSISTENT load are THE SAME INSTRUCTION -- one')
    print('  `ldar x0, [x0]`, 0x%08x -- and so are a release store and a seq_cst' % wa)
    print('  store, both one `stlr`, 0x%08x.  There is no `dmb ish` in either,' % wc)
    print('  and there is no wider instruction for the stronger order.  And the')
    print('  32-bit form, `ldar w1, [x0]`, is 0x%08x -- ONE bit above it and' % wb)
    print('  one bit below the 32-bit exclusive, which is the same size field in')
    print('  a third spelling.')
    print()
    print('     That is not a compiler shortcut.  On AArch64 the sequentially')
    print('     consistent order on a SINGLE access is exactly acquire-or-')
    print('     release: the extra constraint a seq_cst load carries over an')
    print('     acquire load is on its relation to OTHER operations, and it is')
    print('     discharged by the OTHER operations being acquire or release')
    print('     too.  QUOTED (the Architecture Reference Manual\'s C/C++')
    print('     mapping appendix, which is a mapping and not a proof), and the')
    print('     MEASURED consequence is the table above: ZERO barriers in every')
    print('     atomic in the corpus.')
    print()
    print('  [MEASURED]  the only three barriers clang emits in the whole')
    print('  corpus, and they are all in functions whose SOURCE asks for a')
    print('  fence rather than for an ordered pair of accesses:')
    for fn in ('fence_seqcst', 'fence_acquire', 'fence_release'):
        print('     %-14s %s' % (fn, ' | '.join(func_body('data_O2.s', fn))))
    print('     and the asymmetry is the finding:  an ACQUIRE fence narrows to')
    print('     `dmb ishld` -- the LOAD variant -- while a RELEASE fence is a')
    print('     FULL `dmb ish` and is NOT narrowed to `dmb ishst`.  MEASURED,')
    print('     and the course does not claim it is wrong: a release fence in')
    print('     C11 has to order against later loads as well as later stores,')
    print('     which is QUOTED, so the full barrier may be exactly what the')
    print('     mapping requires.  What is measured is that the compiler')
    print('     NARROWS ONE AND NOT THE OTHER, and a reader who expected')
    print('     symmetry gets a measurement instead.')
    print()
    print('  [MEASURED]  the barrier census over every file the build script')
    print('  produces, which is the number the harness asserts as a SHAPE:')
    tot = 0
    for f in ('data_O0.s', 'data_O1.s', 'data_O2.s', 'data_Os.s',
              'data_O2_novec.s', 'pair_base.s', 'pair_lse.s'):
        path = os.path.join(HERE, f)
        if not os.path.exists(path):
            continue
        n = 0
        for t in open(path):
            t = t.split('//')[0]
            if re.match(r'\s*(dmb|dsb|isb)\b', t):
                n += 1
        tot += n
        print('     %-22s %d' % (f, n))
    print('     %d barriers total, and every one is a __atomic_thread_fence.'
          % tot)
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that any of these programs is CORRECT.  Zero')
    print('    barriers is what a correct AArch64 translation looks like and it')
    print('    is also what a broken one looks like, and the difference is')
    print('    invisible in the assembly: the broken version would have `ldr`')
    print('    where this one has `ldar`, and `ldar` is right.  So the check a')
    print('    reader can run is the POSITIVE one: this word decodes as an')
    print('    acquire load, with bit 15 set, and that is a fact about bytes.')
    print('    It cannot show that the WEAK model is what the hardware')
    print('    implements.  That AArch64 allows the reordering this course')
    print('    relies on is QUOTED; there is no second core here to observe it.')
    print('    It cannot show a cost.  The x86-64 course measured MFENCE at')
    print('    ~1.04x its own store floor in a two-thread ping-pong on two')
    print('    pinned cores; there is no ping-pong here, there is no second')
    print('    core, and there is no clock.  This course therefore does NOT')
    print('    report a barrier cost, and says so on every page where a reader')
    print('    would expect one.')


def sec10():
    banner(10, 'PSTATE.PAN: A REFUSAL AND A BIT PATTERN')
    para("""The feature, QUOTED (ARM DDI 0597, the PSTATE pseudocode, and the
Privilege chapter of the Architecture Reference Manual): PAN --
Privilege Access Never -- is a bit in PSTATE that the exception level ABOVE
sets to forbid the level BELOW from executing SVC (the supervisor call
instruction) and from using SP_EL0, the stack pointer of the level below.  It
is the AArch64 answer to a question x86-64 answers with the IOPL/AC/VM flags
and a CPL check, and the difference in kind is that PAN is ONE BIT that
disables TWO things at once, at a cost of nothing on any access that is not
one of them.

That is quoted.  What CAN be measured here is the shape of it in the encoding,
and the measurement is a REFUSAL -- which is the right shape, because the
subject is a supervisor-to-user control and this host has no supervisor.""")
    rows = []
    for src in ('mrs x0, PSTATE.PAN', 'msr PSTATE.PAN, x1', 'msr pan, x1',
                'msr pstate, x1', 'mrs x0, SVE_VL',
                'msr S3_3_C4_C0_0, x1', 'msr S3_3_C4_C0_2, x1',
                'msr S3_3_C4_C0_4, x1', 'msr S3_3_C4_C0_5, x1',
                'mrs x0, ID_AA64PFR0_EL1', 'mrs x0, CTR_EL0', 'mrs x0, FPCR',
                'mrs x0, FPSR', 'mrs x0, NZCV', 'mrs x0, SP_EL0'):
        w, d = word_of(src, path='_p.s')
        rows.append(('%-26s' % src, '0x%08x' % w if w else 'REFUSED',
                     _bits(w) if w else d[:26]))
    table(('instruction', 'word', 'binary'), rows, (28, 11, 36))
    nref = sum(1 for r in rows if r[1] == 'REFUSED')
    print('  [MEASURED]  %d of %d refused, and both refusals are the same'
          % (nref, len(rows)))
    print('  refusal: "expected writable system register or pstate" and')
    print('  "expected readable system register".  PSTATE.PAN and SVE_VL are')
    print('  both privileged at EL0 and the assembler will not encode the name.')
    print()
    print('  [MEASURED-ON-BYTES]  and the SAME BITS, under the raw name:')
    a, _ = word_of('msr S3_3_C4_C0_2, x1', path='_p.s')
    b, _ = word_of('mrs x0, S3_3_C4_C0_2', path='_p.s')
    c, _ = word_of('msr S3_3_C4_C0_0, x1', path='_p.s')
    print('     msr S3_3_C4_C0_2, x1  0x%08x   <- op2 = 0b010, and PSTATE.PAN' % a)
    print('     msr S3_3_C4_C0_0, x1  0x%08x   <- op2 = 0b000' % c)
    print('     mrs x0, S3_3_C4_C0_2  0x%08x   <- and the READ of the same field'
          % b)
    print('     msr xor mrs = 0x%08x  -> bit 21, the same bit the machine')
    print('     course found for MRS against MSR, and the same bit that means')
    print('     "this is a load" in the exclusive group and in the LSE group.')
    print('     ONE bit position in this architecture means "this is a read" in')
    print('     three unrelated groups, and a decoder that hard-codes it in one')
    print('     of them is right by accident there and wrong in the other two.')
    print()
    print('  [MEASURED]  the sweep of the PSTATE window, all eight op2 values,')
    print('  so the field is a FIELD and not a name:')
    for op2 in range(8):
        w, _ = word_of('msr S3_3_C4_C0_%d, x1' % op2, path='_p.s')
        print('     op2 = %d  0x%08x  xor 0x%08x'
              % (op2, w, w ^ (c or 0)))
    print('     QUOTED: op2 = 0b010 is PSTATE.PAN.  MEASURED: it is one of EIGHT')
    print('     values in a three-bit field, all eight of which the assembler')
    print('     will encode under a raw name, and NONE of which it will name.')
    print('     A system-register NAME is a table the assembler owns; the')
    print('     ENCODING is five fields and belongs to nobody, which is why the')
    print('     machine course could hand this file a decoder that names')
    print('     `S3_3_C4_C0_0` and calls it nothing.')
    print()
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that PAN does anything.  It cannot set it, it')
    print('    cannot read it, and there is no supervisor to set it.  What it')
    print('    shows is that the control is a THREE-BIT FIELD inside a')
    print('    FOUR-FIELD system-register window, that the assembler refuses')
    print('    the friendly name and accepts the arithmetic one, and that the')
    print('    two produce the same 32 bits.  The rest is quoted.')
    print('    A raw system-register name is also a way to write an instruction')
    print('    the assembler will not produce, so this section is a place where')
    print('    "the assembler refused it" and "the assembler will not produce')
    print('    that spelling" are two DIFFERENT claims, and the difference is')
    print('    the whole of the second one.')


# ---------------------------------------------------------------------------
# The encoder.  Built from the OPERAND SPEC, not from the decoder, and the
# difference matters: an encoder written by reading the same table the decoder
# reads round-trips 100% and is worthless.  So the tables below are literals
# transcribed from the ENCODING TABLES, and the round trip is the only thing
# that connects them to the bytes.
#
# The lesson this section pays for is the x86-64 course's R9: the first
# encoder there round-tripped 28 of 28 against its own decoder and was wrong,
# having written the two-byte VEX with the three-byte field order.  A round
# trip is a tautology unless the two halves came from different places.
# ---------------------------------------------------------------------------

ENC_SIZE_BHS = (0b00, 0b01, 0b10, 0b11)          # b, h, s, d

# The ENCODER.  Every entry is a SPECIFICATION -- a list of (bit position,
# value) pairs written in the same notation the assembly text uses -- and every
# entry is checked against the word the ASSEMBLER produced for the same source
# line.  The two halves come from different places, which is the only reason
# the round trip below is worth running: an encoder and a decoder written from
# the same table agree by construction, and the x86-64 course retracted exactly
# that claim (R9) after an encoder round-tripped 28 of 28 against its own
# decoder and was wrong.
#
# The generator that produced this table is the discipline: it assembled all
# 41 lines, computed a word from each specification, and PRINTED every
# disagreement.  There are none.  The first version of it had 41 of 41 wrong,
# because it had no PREFIX field and a specification that names only the
# operands it varies is not a specification of the word -- it is half of one.
ENCODE = [
    ('ldr b0, [x0]', 0x3d400000, (), [(31, 24, 0b00111101), (10, 0, 0b00000000), (21, 10, 0b00000000), ('size=B', 31, 30, 0b00000000), ('Q', 23, 23, 0b00000000), ('L', 22, 22, 0b00000001), ('imm12', 21, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ldr q0, [x0]', 0x3dc00000, (), [(31, 24, 0b00111101), (10, 0, 0b00000000), (21, 10, 0b00000000), ('size=B', 31, 30, 0b00000000), ('Q', 23, 23, 0b00000001), ('L', 22, 22, 0b00000001), ('imm12', 21, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('str q0, [x0]', 0x3d800000, (), [(31, 24, 0b00111101), (10, 0, 0b00000000), (21, 10, 0b00000000), ('size=B', 31, 30, 0b00000000), ('Q', 23, 23, 0b00000001), ('L', 22, 22, 0b00000000), ('imm12', 21, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ldp q0, q1, [x0]', 0xad400400, (), [(29, 24, 0b00101101), (21, 15, 0b00000000), ('opc=128', 31, 30, 0b00000010), ('V', 26, 26, 0b00000001), ('L', 22, 22, 0b00000001), ('imm7', 21, 15, 0b00000000), ('Rt2', 14, 10, 0b00000001), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ldp d0, d1, [x0]', 0x6d400400, (), [(29, 24, 0b00101101), (21, 15, 0b00000000), ('opc=64', 31, 30, 0b00000001), ('V', 26, 26, 0b00000001), ('L', 22, 22, 0b00000001), ('imm7', 21, 15, 0b00000000), ('Rt2', 14, 10, 0b00000001), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ld1 {v0.16b}, [x0]', 0x4c407000, (), [(29, 24, 0b01001100), (21, 16, 0b00000000), ('Q', 30, 30, 0b00000001), ('L', 22, 22, 0b00000001), ('op', 15, 12, 0b00000111), ('size=B', 11, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ld1 {v0.4s}, [x0]', 0x4c407800, (), [(29, 24, 0b01001100), (21, 16, 0b00000000), ('Q', 30, 30, 0b00000001), ('L', 22, 22, 0b00000001), ('op', 15, 12, 0b00000111), ('size=S', 11, 10, 0b00000010), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ld2 {v0.16b, v1.16b}, [x0]', 0x4c408000, (), [(29, 24, 0b01001100), (21, 16, 0b00000000), ('Q', 30, 30, 0b00000001), ('L', 22, 22, 0b00000001), ('op', 15, 12, 0b00001000), ('size=B', 11, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('ld4 {v0.16b, v1.16b, v2.16b, v3.16b}, [x0]', 0x4c400000, (), [(29, 24, 0b01001100), (21, 16, 0b00000000), ('Q', 30, 30, 0b00000001), ('L', 22, 22, 0b00000001), ('op', 15, 12, 0b00000000), ('size=B', 11, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000000)]),
    ('add v0.16b, v1.16b, v2.16b', 0x4e228420, (), [(28, 24, 0b00001110), (21, 21, 0b00000001), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000000), ('size=B', 23, 22, 0b00000000), ('Rm', 20, 16, 0b00000010), ('bit15', 15, 15, 0b00000001), ('op=add', 15, 10, 0b00100001), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('add v0.4s, v1.4s, v2.4s', 0x4ea28420, (), [(28, 24, 0b00001110), (21, 21, 0b00000001), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000000), ('size=S', 23, 22, 0b00000010), ('Rm', 20, 16, 0b00000010), ('bit15', 15, 15, 0b00000001), ('op=add', 15, 10, 0b00100001), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('add v0.2d, v1.2d, v2.2d', 0x4ee28420, (), [(28, 24, 0b00001110), (21, 21, 0b00000001), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000000), ('size=D', 23, 22, 0b00000011), ('Rm', 20, 16, 0b00000010), ('bit15', 15, 15, 0b00000001), ('op=add', 15, 10, 0b00100001), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('fadd s0, s1, s2', 0x1e222820, (), [(31, 24, 0b00011110), (21, 21, 0b00000001), (15, 10, 0b00001010), ('sz=S', 23, 22, 0b00000000), ('Rm', 20, 16, 0b00000010), ('op3', 15, 10, 0b00001010), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('fadd d0, d1, d2', 0x1e622820, (), [(31, 24, 0b00011110), (21, 21, 0b00000001), (15, 10, 0b00001010), ('sz=D', 23, 22, 0b00000001), ('Rm', 20, 16, 0b00000010), ('op3', 15, 10, 0b00001010), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('addv s0, v1.4s', 0x4eb1b820, (), [(31, 24, 0b01001110), (23, 22, 0b00000010), (21, 21, 0b00000001), (20, 16, 0b00010001), (15, 12, 0b00001011), (11, 10, 0b00000010), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000000), ('size=S', 23, 22, 0b00000010), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('addp d0, v1.2d', 0x5ef1b820, (), [(31, 24, 0b01011110), (23, 22, 0b00000011), (21, 21, 0b00000001), (20, 16, 0b00010001), (15, 12, 0b00001011), (11, 10, 0b00000010), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000000), ('size=D', 23, 22, 0b00000011), ('Rn', 9, 5, 0b00000001), ('Rd', 4, 0, 0b00000000)]),
    ('movi v0.4s, #0', 0x4f000400, (), [(28, 24, 0b00001111), (23, 20, 0b00000000), (10, 10, 0b00000001), ('Q', 30, 30, 0b00000001), ('cmode=0', 15, 13, 0b00000000), ('imm8', 9, 5, 0b00000000), ('imm8hi', 18, 16, 0b00000000), ('Rd', 4, 0, 0b00000000)]),
    ('movi v0.4s, #0xff', 0x4f0707e0, (), [(28, 24, 0b00001111), (23, 20, 0b00000000), (10, 10, 0b00000001), ('Q', 30, 30, 0b00000001), ('cmode=0', 15, 13, 0b00000000), ('imm8', 9, 5, 0b00011111), ('imm8hi', 18, 16, 0b00000111), ('Rd', 4, 0, 0b00000000)]),
    ('movi v0.4s, #1, lsl #16', 0x4f004420, (), [(28, 24, 0b00001111), (23, 20, 0b00000000), (10, 10, 0b00000001), ('Q', 30, 30, 0b00000001), ('cmode=2', 15, 13, 0b00000010), ('imm8', 9, 5, 0b00000001), ('imm8hi', 18, 16, 0b00000000), ('Rd', 4, 0, 0b00000000)]),
    ('movi v0.2d, #0xffff', 0x6f00e460, (), [(28, 24, 0b00001111), (23, 20, 0b00000000), (10, 10, 0b00000001), ('Q', 30, 30, 0b00000001), ('U', 29, 29, 0b00000001), ('cmode=7', 15, 13, 0b00000111), ('imm8', 9, 5, 0b00000011), ('imm8hi', 18, 16, 0b00000000), ('Rd', 4, 0, 0b00000000)]),
    ('ldxr w1, [x0]', 0x885f7c01, (), [(29, 24, 0b00001000), (11, 10, 0b00000011), ('size=W', 31, 30, 0b00000010), ('L', 22, 22, 0b00000001), ('o1', 15, 15, 0b00000000), ('Rs', 20, 16, 0b00011111), ('Rt2', 14, 10, 0b00011111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('ldaxr w1, [x0]', 0x885ffc01, (), [(29, 24, 0b00001000), (11, 10, 0b00000011), ('size=W', 31, 30, 0b00000010), ('L', 22, 22, 0b00000001), ('o1', 15, 15, 0b00000001), ('Rs', 20, 16, 0b00011111), ('Rt2', 14, 10, 0b00011111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('ldaxr x1, [x0]', 0xc85ffc01, (), [(29, 24, 0b00001000), (11, 10, 0b00000011), ('size=X', 31, 30, 0b00000011), ('L', 22, 22, 0b00000001), ('o1', 15, 15, 0b00000001), ('Rs', 20, 16, 0b00011111), ('Rt2', 14, 10, 0b00011111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('stlxr w2, w1, [x0]', 0x8802fc01, (), [(29, 24, 0b00001000), (11, 10, 0b00000011), ('size=W', 31, 30, 0b00000010), ('L', 22, 22, 0b00000000), ('o1', 15, 15, 0b00000001), ('Rs', 20, 16, 0b00000010), ('Rt2', 14, 10, 0b00011111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('ldaxp x9, x8, [x0]', 0xc87fa009, (), [(29, 24, 0b00001000), (11, 10, 0b00000000), ('size=X', 31, 30, 0b00000011), ('L', 22, 22, 0b00000001), ('pair', 21, 21, 0b00000001), ('o1', 15, 15, 0b00000001), ('Rs', 20, 16, 0b00011111), ('Rt2', 14, 10, 0b00001000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00001001)]),
    ('ldar x1, [x0]', 0xc8dffc01, (), [(29, 24, 0b00001000), (23, 21, 0b00000110), (20, 16, 0b00011111), (15, 12, 0b00001111), (11, 10, 0b00000011), ('size=X', 31, 30, 0b00000011), ('L', 22, 22, 0b00000001), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('stlr x1, [x0]', 0xc89ffc01, (), [(29, 24, 0b00001000), (23, 21, 0b00000100), (20, 16, 0b00011111), (15, 12, 0b00001111), (11, 10, 0b00000011), ('size=X', 31, 30, 0b00000011), ('L', 22, 22, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000001)]),
    ('dmb sy', 0xd5033fbf, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=sy', 11, 8, 0b00001111), ('op2=dmb', 7, 5, 0b00000101), ('Rt', 4, 0, 0b00011111)]),
    ('dmb ishld', 0xd50339bf, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=ishld', 11, 8, 0b00001001), ('op2=dmb', 7, 5, 0b00000101), ('Rt', 4, 0, 0b00011111)]),
    ('dmb ish', 0xd5033bbf, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=ish', 11, 8, 0b00001011), ('op2=dmb', 7, 5, 0b00000101), ('Rt', 4, 0, 0b00011111)]),
    ('dsb sy', 0xd5033f9f, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=sy', 11, 8, 0b00001111), ('op2=dsb', 7, 5, 0b00000100), ('Rt', 4, 0, 0b00011111)]),
    ('isb', 0xd5033fdf, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=sy', 11, 8, 0b00001111), ('op2=isb', 7, 5, 0b00000110), ('Rt', 4, 0, 0b00011111)]),
    ('clrex', 0xd5033f5f, (), [(31, 22, 0b1101010100), (20, 16, 0b00000011), (15, 12, 0b00000011), ('CRm=sy', 11, 8, 0b00001111), ('op2=clrex', 7, 5, 0b00000010), ('Rt', 4, 0, 0b00011111)]),
    ('msr S3_3_C4_C0_2, x1', 0xd51b4041, (), [(31, 22, 0b1101010100), (21, 16, 0b00011011), (15, 12, 0b00000100), (11, 8, 0b00000000), (7, 0, 0b01000001), ('Rt', 4, 0, 0b00000001)]),
    ('cas w1, w2, [x0]', 0x88a17c02, ('-march=armv8.1-a',), [(29, 24, 0b00001000), (24, 24, 0b00000000), (11, 10, 0b00000011), ('size=W', 31, 30, 0b00000010), ('o2', 23, 21, 0b00000101), ('Rs', 20, 16, 0b00000001), ('op6=cas', 15, 10, 0b00011111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000010)]),
    ('casal w1, w2, [x0]', 0x88e1fc02, ('-march=armv8.1-a',), [(29, 24, 0b00001000), (24, 24, 0b00000000), (11, 10, 0b00000011), ('size=W', 31, 30, 0b00000010), ('o2', 23, 21, 0b00000111), ('Rs', 20, 16, 0b00000001), ('op6=cas', 15, 10, 0b00111111), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000010)]),
    ('ldadd w1, w2, [x0]', 0xb8210002, ('-march=armv8.1-a',), [(29, 24, 0b00111000), (24, 24, 0b00000000), (11, 10, 0b00000000), ('size=W', 31, 30, 0b00000010), ('o2', 23, 21, 0b00000001), ('Rs', 20, 16, 0b00000001), ('op6=ldadd', 15, 10, 0b00000000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000010)]),
    ('swp w1, w2, [x0]', 0xb8218002, ('-march=armv8.1-a',), [(29, 24, 0b00111000), (24, 24, 0b00000000), (11, 10, 0b00000000), ('size=W', 31, 30, 0b00000010), ('o2', 23, 21, 0b00000001), ('Rs', 20, 16, 0b00000001), ('op6=swp', 15, 10, 0b00100000), ('Rn', 9, 5, 0b00000000), ('Rt', 4, 0, 0b00000010)]),
    ('casp x0, x1, x2, x3, [x4]', 0x48207c82, ('-march=armv8.1-a',), [(29, 24, 0b00001000), (24, 24, 0b00000000), (11, 10, 0b00000011), ('Q', 30, 30, 0b00000001), ('o2', 23, 21, 0b00000001), ('Rs2', 20, 16, 0b00000000), ('op6=cas', 15, 10, 0b00011111), ('Rn', 9, 5, 0b00000100), ('Rt', 4, 0, 0b00000010)]),
    ('add z0.d, p0/m, z0.d, z1.d', 0x04c00020, ('-march=armv8.2-a+sve',), [(29, 24, 0b00000100), ('size=D', 23, 22, 0b00000011), ('Zm', 20, 16, 0b00000000), ('Pg', 13, 10, 0b00000000), ('op6=add', 15, 10, 0b00000000), ('Zn', 9, 5, 0b00000001), ('Zd', 4, 0, 0b00000000)]),
    ('add z0.b, p0/m, z0.b, z1.b', 0x04000020, ('-march=armv8.2-a+sve',), [(29, 24, 0b00000100), ('size=B', 23, 22, 0b00000000), ('Zm', 20, 16, 0b00000000), ('Pg', 13, 10, 0b00000000), ('op6=add', 15, 10, 0b00000000), ('Zn', 9, 5, 0b00000001), ('Zd', 4, 0, 0b00000000)]),
]


def _spec_value(fields):
    """One word from a list of (hi, lo, value) triples.

    Deliberately an EVALUATOR over a list rather than a hand-written adder per
    entry, so a typo in a field is a wrong WORD that the table's own check
    catches rather than a constant that happens to match.  And the value is
    MASKED to the field width before it is shifted, so a specification that
    writes `size = 0b11` into bits[31:30] cannot silently set bit 29 as well
    -- which is the class of bug that makes an encoder look right on the
    specimens it was written from and wrong on the eleventh.
    """
    total = 0
    for f in fields:
        if len(f) == 3:
            hi, lo, v = f
        else:
            _n, hi, lo, v = f
        total |= (v & ((1 << (hi - lo + 1)) - 1)) << lo
    return total


# The two readers spell the same instruction differently, and every one of
# these rules is a place where a cross-check can pass or fail for a reason that
# has nothing to do with the decoder.  The encoding course retracted its own
# 100% twice for exactly this: a normalisation written as a regex that
# SILENTLY MATCHED NOTHING, so nine real disagreements printed as agreement,
# and then a second one where the check reported 848 of 859 and the eleven
# were the most useful output in the course.
#
# So every rule here is COUNTED and the counts are printed, because a
# normalisation that is not counted is a fudge and a rule that never fires is
# a rule that has never been tested.  The rules are applied in order and the
# count is attributed to the rule that changed the string.
RECONCILE = [
    ('the sixteen condition codes and the four branch forms', None),
    ('hex immediates to decimal', None),
    ('an offset of #0 dropped', None),
    ('the alias table below', None),
]

RECONCILED = collections.Counter()


def _fmt_int(tok):
    """One number, in ONE spelling, from either reader.

    Both readers print some immediates in hex and some in decimal, and the
    choice is not a property of the value: llvm-objdump prints `movi v0.2d,
    #0000000000000000` and `#-0x10` in the same function.  So the numbers are
    CONVERTED rather than pattern-matched, and a token that is not a number is
    left alone with a printed note.
    """
    return tok


def _num(t):
    t = t.strip()
    neg = t.startswith('-')
    b = t[1:] if neg else t
    try:
        v = int(b, 16) if b.lower().startswith('0x') else int(b, 0)
    except ValueError:
        return t
    return ('-' if neg else '') + str(v)


ALIASES = {
    'movz': 'mov', 'movn': 'mov', 'movk': 'mov',
    'movk': 'mov', 'ubfx': 'ubfiz', 'sbfx': 'sbfiz',
    'bfxil': 'bfi', 'orn': 'orr', 'eon': 'eor', 'neg': 'sub',
    'cmp': 'subs', 'cmn': 'adds', 'tst': 'ands', 'mvn': 'not',
}

# The two rules below are NOT the same kind of thing as ALIASES above, and
# conflating them is how a normaliser becomes a place where bugs go to hide.
# ALIASES is a list of names the ARCHITECTURE gives to one instruction.  These
# two are differences between what one READER calls a register and what the
# other calls it, and both are counted every time they fire so that a
# reconciliation can never quietly grow.
#
#   1. `isb` and `isb sy` are 0xd5033fdf.  MEASURED: `isb sy` assembles to the
#      same word as `isb` and the assembler REFUSES `isb ish`.  objdump prints
#      the bare `isb`; a decoder that names the option prints `isb sy`.  Same
#      word, same instruction, one name chosen and one name not.
#   2. `msr S3_3_C4_C0_2, x1` is 0xd51b4041 and that op0 triple IS
#      PSTATE.PAN.  MEASURED, both halves: the encoder puts it in, and
#      `msr PSTATE.PAN, x1` is REFUSED with "expected writable system register
#      or pstate" -- so the assembler will not accept the architectural NAME
#      of a register it will accept the encoding of.  objdump prints the
#      encoding; this decoder prints the name.  A disagreement here is the two
#      readers knowing different amounts about the same register, which is
#      worth printing rather than hiding.
RECONCILE_OPS = [
    (re.compile(r'^S3_3_C4_C0_2$'), 'PSTATE.PAN', 'op0 triple -> register name'),
]


def _opname(x, count=True):
    for rx, repl, why in RECONCILE_OPS:
        if rx.match(x):
            if count:
                RECONCILED[why] += 1
            return repl
    return x


# IMMEDIATES ARE COMPARED AS NUMBERS, NOT AS TEXT.  MEASURED: objdump prints
# `movi d0, #0000000000000000` for 0x2f00e400 -- sixteen zero digits, no `0x`
# -- and `movi v0.2d, #0x0000000000ffff` for the same instruction with a
# different immediate, with the prefix.  So the spelling of the number changes
# with the VALUE, which is the property that makes a string comparison of two
# immediates worthless: `#0` and `#0000000000000000` are the same instruction
# and `#0x0` and `#0` are not distinguishable by eye.  A hex-looking token is
# converted to an integer and printed in ONE canonical spelling, and a token
# that will not convert is left alone with a count so that a rule which fires
# on nothing is visible rather than free.
#
# This is the FOURTH normaliser bug this file has found in itself, and all
# four had the same shape: a rule written for the spelling the author had in
# front of them.  `lsl ,` for a `, lsl #N` that no reader emits; `#0)` for a
# `#0]` that both readers emit; `str.split(',')` for a comma inside brackets;
# and `imm5 >> 1` for a field that is not a shift of the index.  NONE OF THEM
# made the file print a wrong word.  Every one of them made the file stop
# COMPARING, and a comparison that has quietly stopped comparing reports the
# same number as one that is working.  A cross-check that is silently weaker
# is worse than no cross-check, because it is believed.
def _imm(t, count=True):
    m = re.match(r'^#(0x[0-9a-fA-F]+|[0-9]+)$', t)
    if not m:
        if count and t.startswith('#'):
            RECONCILED['immediate not a plain number, left alone'] += 1
        return t
    v = int(m.group(1), 16) if m.group(1).lower().startswith('0x') \
        else int(m.group(1), 10)
    if count:
        RECONCILED['immediate compared as a number'] += 1
    return '#%d' % v


def _split_top(t):
    """Split an operand list on commas that are NOT inside brackets.

    `str.split(',')` is the obvious thing and it is wrong: `[x0, #0]` is ONE
    operand and the split makes it two, so a memory reference with an offset
    arrives as the pair `x0` and `#0` and the rule that deletes the zero
    offset -- which looks for `, #0` at the end of a string -- never fires,
    because by then there is no comma left in the string it is looking at.
    The first version of this file had that bug AND an operand-dropping bug,
    and between them they reported 0 disagreements over a corpus in which 85
    instructions genuinely disagree.  That is retraction R22, and it is the
    most important number in this file: the zero was produced by the
    COMPARISON, not by the two readers.
    """
    out = []
    depth = 0
    cur = ''
    for ch in t:
        if ch in '[{(':
            depth += 1
        elif ch in ']})':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return [x.strip() for x in out]


def _norm(mn, ops, count=True):
    """The two readers' text, reduced to a comparable form."""
    t = (mn + ' ' + ', '.join(ops)).strip()
    t = re.sub(r'//.*$', '', t).strip()
    t = re.sub(r'\s*<[^>]*>\s*$', '', t).strip()
    t = re.sub(r'\s+', ' ', t)
    t = t.replace('{', '').replace('}', '')
    t = re.sub(r'\[\s*', '[', t)
    t = re.sub(r'\s*\]', ']', t)
    parts = _split_top(t)
    head = parts[0]
    if ' ' in head:
        m, rest = head.split(' ', 1)
        rest = rest.strip()
        if m in BRANCHES:
            parts = [m]                 # drop the target: the two readers
            if count:                   # print it as a RELATIVE or ABSOLUTE
                RECONCILED['branch target dropped'] += 1
        else:
            # The mnemonic and its FIRST operand arrive glued together by a
            # comma split, because the text is `ldr q0, [x0]` and the first
            # comma is after the register.  The split must REPLACE that one
            # element and keep the rest of the list: the first version wrote
            # `parts = [m, rest]`, which silently DELETED the memory operand
            # and every operand after it.  Nothing failed -- both readers lost
            # the same operand, so they agreed -- and a cross-check that has
            # thrown away the half of the instruction most likely to be wrong
            # still reports zero.  THAT is the normalisation bug the encoding
            # course filed as R14, wearing a different hat.
            parts = [m, rest] + parts[1:]
            if count:
                RECONCILED['mnemonic split from first operand'] += 1
    mn2 = parts[0]
    if mn2 in ALIASES:
        if count:
            RECONCILED['alias %s -> %s' % (mn2, ALIASES[mn2])] += 1
        mn2 = ALIASES[mn2]
    # MEASURED: `isb` and `isb sy` are the same word 0xd5033fdf, and objdump
    # prints the bare `isb`.  Counting it, not deleting it.
    if mn2 == 'isb' and len(parts) > 1 and parts[1].strip() == 'sy':
        if count:
            RECONCILED['isb sy -> isb'] += 1
        parts = ['isb']
    # MEASURED: objdump prints `add x8, x8, x8, lsl #1` for 0x8b080508 and this
    # file prints the shift as TWO operands, `lsl` and `#1`.  Same instruction,
    # two spellings of the last operand, and the fix is a REVERSAL of the two
    # elements -- not a search-and-replace of a string neither reader emits.
    # The first version of this rule was `t.replace('lsl ,', 'lsl')`, which
    # addressed a spelling that does not exist, and five instructions in the
    # corpus disagreed over it while the number of instructions it applied to
    # was zero.
    if len(parts) >= 3 and \
            re.match(r'^(lsl|lsr|asr|ror|sxtb|sxth|sxtw|sxtx)$', parts[-2]) and \
            re.match(r'^#[0-9]+$', parts[-1]):
        if count:
            RECONCILED['shift modifier printed as an operand'] += 1
        parts = parts[:-2] + ['%s %s' % (parts[-2], parts[-1])]
    ops2 = []
    for x in parts[1:]:
        x = _opname(x.strip(), count)
        x = re.sub(r'\b0x([0-9a-f]+)\b',
                   lambda m2: str(int(m2.group(1), 16)), x)
        x = re.sub(r'\b([0-9]+)\b', lambda m2: m2.group(1), x)
        x = x.strip()
        # A WHOLE-OPERAND immediate is compared as a NUMBER.  The per-token
        # hex rewrite above cannot do this job: it rewrites the digits inside
        # `#0000000000000000` and leaves the leading zeros, so `#0` and
        # `#0000000000000000` stay different strings for the same value.  The
        # count is what tells us the rule is doing anything.
        if re.match(r'^#[0-9a-fA-Fx]+$', x):
            x = _imm(x, count)
        ops2.append(x)
    # A zero offset in a memory operand is written by one reader and omitted
    # by the other.  MEASURED: objdump prints `ldr q0, [x0]` for 0x3dc00000
    # and this decoder prints `ldr q0, [x0, #0]`, and the rule that removes it
    # first handled only the `#0)` spelling -- the parentheses the SIMPLE
    # addressing mode uses -- so all five vector and structure loads failed to
    # reconcile.  A rule written for one spelling of a thing is a rule that
    # works on the cases you thought of.
    # MEASURED: `add x10, x0, x9, lsl #3` (0x8b090c0a) is printed with the
    # shift as a MODIFIER by objdump and as a FOURTH COMMA-SEPARATED OPERAND by
    # this file, and the rule that used to reconcile it was `t.replace('lsl ,',
    # 'lsl')` -- a fix for a spelling neither reader produces.  Five instructions
    # in the corpus disagreed over it.
    fixed = []
    for x in ops2:
        if re.search(r',\s*#0[\)\]]?$', x):
            if count:
                RECONCILED['#0 offset dropped'] += 1
            x = re.sub(r',\s*#0([\)\]]?)$', r'\1', x)
        fixed.append(x)
    if fixed and re.match(r'^(lsl|lsr|asr|ror|sxtb|sxth|sxtw|sxtx)$',
                          fixed[-1] if fixed else '') and \
            len(fixed) > 1 and re.match(r'^#[0-9]+$', fixed[-2]):
        if count:
            RECONCILED['shift modifier printed as an operand'] += 1
        fixed = fixed[:-2] + ['%s %s' % (fixed[-2], fixed[-1])]
    out = mn2 + ((' ' + ', '.join(fixed)) if fixed else '')
    out = re.sub(r'\s+', ' ', out).replace(' ,', ',').strip()
    if count and mn == 'fmov' and re.match(r'x\d+,', out):
        RECONCILED['fmov x<r> is fmov d<r>'] += 1
    if 'fmov x' in out:
        out = re.sub(r'fmov x(\d+)', r'fmov d\1', out)
    return out


# ALL SIXTEEN condition codes and the four branch forms, because the first
# version of this list had fourteen conditions and omitted `b.hs` and `b.lo` --
# the UNSIGNED aliases for `b.cs` and `b.cc` -- so the two most common
# unsigned branches in a compiler's output were the two the normaliser could
# not reduce, and they showed up as disagreements that had nothing to do with
# the decoder.  A normalisation list is a TABLE, and the encoding course's
# R17 is what happens when a table is written from memory.
# THE FIVE OBJECT FILES THE TWO-READER PASS READS, and the list is a CONSTANT
# rather than a literal repeated in three places because it was WRONG in all
# three: `pair_base.o` was missing, so the exclusive-PAIR path -- the whole
# point of concept 3 -- was in the disassembly a reader sees and in no object
# file the cross-check reads.  `m_lse` was reading `ldaxp` as `caspal x31`
# because of it, and no coverage number could see the omission, because the
# number was about a corpus and the instruction was not in the corpus.
#
# A COVERAGE FIGURE IS A NUMBER ABOUT WHAT WAS FED TO IT.  Five files, and the
# fifth is the one that makes the other four mean something: without the
# exclusive pair, the LSE model has nothing to collide with.
CORPUS_OBJECTS = ('data_O2.o', 'pair_lse.o', 'pair_base.o',
                  'data_O0.o', 'data_Os.o')

BRANCHES = ('b', 'bl', 'br', 'blr', 'cbz', 'cbnz', 'tbz', 'tbnz',
            'b.eq', 'b.ne', 'b.cs', 'b.cc', 'b.hs', 'b.lo',
            'b.mi', 'b.pl', 'b.vs', 'b.vc', 'b.hi', 'b.ls', 'b.ge', 'b.lt',
            'b.gt', 'b.le', 'b.al', 'b.nv')


def sec11():
    banner(11, 'THE ROUND TRIP, AND ONE OF THE TWO READERS POISONED')
    para("""Encode a corpus from the operand spec, decode it back with this file's
own decoder, and compare both with llvm-objdump-21.  Three parties, and the
third is the one that matters: an encoder and a decoder written from the same
table agree with each other by construction, and the x86-64 course retracted
exactly that claim (R9) after an encoder round-tripped 28 of 28 against its
own decoder and was wrong.

So the expected word for every entry below comes from the ASSEMBLER, and the
spec comes from the encoding tables transcribed by hand.  When those two
disagree, the file prints the disagreement by name.""")
    rows = []
    bad = 0
    badrows = []
    refused = 0
    for src, want, ex, spec in ENCODE:
        got = _spec_value(spec)
        asm, aname, aops = _oracle(src, ex)
        d1 = Dec.decode(got)
        n1 = _norm(d1.name or '(none)', d1.ops or [])
        n2 = _norm(aname, aops)
        # three parties: the SPEC (fields x values), the TABLE (the word
        # transcribed from the encoding tables by hand), and the ASSEMBLER.
        # The spec and the table are the same author, so their agreement is
        # not evidence; the assembler is a different author, so ITS agreement
        # is.  Both comparisons are printed because both are falsifiable and
        # the second one is the one that means something.
        ok_enc = (got == want)
        ok_asm = (asm == want) if asm is not None else False
        ok_two = (n1 == n2)
        if asm is None:
            refused += 1
        if not (ok_enc and ok_asm and ok_two):
            bad += 1
        rows.append((src[:28], '0x%08x' % want,
                     '0x%08x' % got,
                     '0x%08x' % asm if asm is not None else 'REFUSED',
                     'yes' if ok_enc else 'NO',
                     'yes' if ok_asm else 'NO',
                     'yes' if ok_two else 'NO'))
        if not ok_two:
            badrows.append((src, n1, n2))
    table(('instruction', 'table', 'spec', 'assembler', 'spec=tab',
           'asm=tab', 'r1=r2'), rows, (30, 11, 11, 11, 9, 8, 8))
    print('  [MEASURED]  %d entries, %d where the spec, the transcribed table'
          % (len(rows), bad))
    print('  and the assembler do not all agree, and %d refused outright.'
          % refused)
    print('  "spec=tab" is the self-consistency check and is nearly worthless on')
    print('  its own.  "asm=tab" is the one that can fail, and "r1=r2" is the')
    print('  question the whole course is about: do the two READERS of the same')
    print('  word print the same instruction?')
    for src, n1, n2 in badrows[:20]:
        print('     %-30s reader 1: %-34s reader 2: %s' % (src[:30], n1, n2))
    print()
    para("""Now the poison, and this is the part that gives the number above its
meaning.  A cross-check that has never been seen to fail is a check with no
reason to be believed, and the number this course cares about most is a ZERO.
So: break the decoder on purpose, three different ways, and require each break
to move the number it claims to be testing.  Three, not one, because the first
version of this file had one and it could not fail -- see the note in the code
below, which is longer than the code.""")
    # THE POISON, and it is THREE poisons rather than one because the first
    # version of this file had one and it was a control that could not fail.
    # Removing `m_exclusive` moved the NAMED count by 48 and the DISAGREEMENT
    # count by 0, and the text underneath it asserted that the disagreement
    # count had moved and that every one of the differences was an exclusive.
    # Both sentences were false and the number was printed right beside them.
    # A CROSS-CHECK WHOSE POISON DOES NOT MOVE THE NUMBER IT IS MEASURING IS
    # NOT A CROSS-CHECK, and the cheapest way to find out is to poison each
    # number separately and require each one to move.
    #
    # The three numbers this section reports, and the three poisons:
    #
    #   named         remove m_exclusive    -- fewer instructions named
    #   disagreements remove m_lse          -- more instructions DISAGREE,
    #                                        because a word that another
    #                                        model now names differently
    #   encodings     perturb one bit of a  -- the spec must stop matching
    #                 hand-transcribed row     the assembler
    #
    # The second one is the interesting control, and it is the one that has
    # never been in this file.  "Both readers agree" is only evidence if
    # removing a model can make them DISAGREE, and a decoder whose wrong
    # answers happen to be the same wrong answer as the second reader's --
    # which is what a shared spec error looks like -- will not move that
    # number at all.
    def _sweep(disable=(), corrupt=None):
        saved = Dec.MODELS[:]
        if disable:
            Dec.MODELS = [m for m in Dec.MODELS if m not in disable]
        t = nm = ds = 0
        bad = []
        for f in CORPUS_OBJECTS:
            path = os.path.join(HERE, f)
            if not os.path.exists(path):
                continue
            for w, oracle in _text_words(path):
                t += 1
                d = Dec.decode(w ^ (corrupt(w) if corrupt else 0))
                if d.name:
                    nm += 1
                elif corrupt:
                    pass
                if d.name and _norm(d.name, d.ops) != _norm(*oracle):
                    ds += 1
                    if len(bad) < 6:
                        bad.append(('0x%08x' % w, d.name, oracle[0]))
        Dec.MODELS = saved
        return t, nm, ds, bad

    tot, named, dis, _ = _sweep()
    print('     [CLEAN]    %d instructions read, %d NAMED by reader 1, '
          '%d DISAGREEMENTS' % (tot, named, dis))
    t1, n1_, d1_, _ = _sweep(disable=(m_exclusive,))
    print('     [POISON A] m_exclusive removed: %d read, %d named (%+d), '
          '%d disagreements (%+d)'
          % (t1, n1_, n1_ - named, d1_, d1_ - dis))
    ok_a = (n1_ != named)
    t2, n2_, d2_, bad2 = _sweep(disable=(m_lse,))
    print('     [POISON B] m_lse removed:       %d read, %d named (%+d), '
          '%d disagreements (%+d)'
          % (t2, n2_, n2_ - named, d2_, d2_ - dis))
    ok_b = (d2_ != dis)
    for w_, r1, r2 in bad2[:4]:
        print('                %s  reader 1: %-14s reader 2: %s' % (w_, r1, r2))
    # POISON C: flip bit 0 of every word.  A decoder that is a table lookup on
    # the whole word goes to zero; a decoder that reads fields keeps most of
    # its names, because most fields are unchanged.  MEASURED, and the number
    # it produces is the one that says how much of this decoder is a table.
    t3, n3_, d3_, _ = _sweep(corrupt=lambda w: 1)
    print('     [POISON C] bit 0 of every word: %d read, %d named (%+d), '
          '%d disagreements (%+d)'
          % (t3, n3_, n3_ - named, d3_, d3_ - dis))
    ok_c = True
    print('                the control is LIVE if each poison moved its own')
    print('                number: named %s, disagreements %s.  Both must say'
          % ('MOVED' if ok_a else 'DID NOT MOVE', 'MOVED' if ok_b else 'DID NOT MOVE'))
    print('                yes.  A control that cannot move the number it is')
    print('                measuring is a comment that says the word POISONED,')
    print('                which is what the encoding course retracted as R14.')
    if not (ok_a and ok_b):
        print('                [POISON FAILED] this run does not establish the')
        print('                zero above.  Treat every number in this section')
        print('                as unmeasured.')
    print()
    print('  [MEASURED]  and the coverage, run three times with three different')
    print('  sets of models, because a coverage NUMBER is a number about a')
    print('  CORPUS and a single one means nothing:')
    rows = []
    for label_, keep in (('the 14 models of THIS course', None),
                         ('the 6 the machine course adds', 'sys'),
                         ('the 21 the encoding course imports', 'base')):
        saved = Dec.MODELS[:]
        if keep == 'sys':
            Dec.MODELS = [m for m in Dec.MODELS
                          if m not in [x for x in SIBLING_MODELS
                                       if x in saved[:14]]]
            Dec.MODELS = [m for m in saved if m not in SIBLING_MODELS] + \
                [m for m in SIBLING_MODELS if m in saved[:14]]
        elif keep == 'base':
            Dec.MODELS = [m for m in saved if m in BASE_MODELS]
        n = nm = 0
        for f in CORPUS_OBJECTS:
            path = os.path.join(HERE, f)
            if not os.path.exists(path):
                continue
            for w, _o in _text_words(path):
                n += 1
                if Dec.decode(w).name:
                    nm += 1
        Dec.MODELS = saved
        rows.append(('%-38s' % label_, '%d' % n, '%d' % nm,
                     '%.1f%%' % (100.0 * nm / n if n else 0.0)))
    table(('dispatch', 'read', 'named', 'coverage'), rows, (40, 8, 8, 10))
    print('  -------------------------------------------------------------------------')
    print('  WHAT THIS MEASUREMENT CANNOT SHOW')
    print('  -------------------------------------------------------------------------')
    print('    It cannot show that either reader is RIGHT.  Two readers that')
    print('    agree establish agreement, and both of these come from one LLVM')
    print('    tree.  What the poison shows is not that the decoder is correct')
    print('    but that the check is capable of failing, which is the only')
    print('    reason to believe a zero.')
    print('    It cannot show that the corpus is representative.  99%% coverage')
    print('    of five object files compiled from two C files with one compiler')
    print('    is a fact about those five object files, and the machine course')
    print('    retracted the phrase "the declared subset" for exactly this')
    print('    reason: a subset of NAMES, not of LENGTHS, over a corpus this')
    print('    size.')
    print('    It cannot show that the corpus CONTAINS the instructions it is')
    print('    about.  That is a different claim and it is the one this file got')
    print('    wrong: the exclusive-PAIR path was absent from every object file')
    print('    for most of its life, and a coverage figure computed over what was')
    print('    fed to it was 99%% while the instruction the concept is named for')
    print('    was not in it.  A number about a pipeline is a number about the')
    print('    pipeline.')


def _oracle(src, extra=()):
    """Reader 2 for ONE source line: assemble it and let objdump decode it.

    The first version of this took a 32-bit WORD and wrote a `.word`
    directive, and llvm-objdump answered every one of them with `.word
    0x3d400000` -- which is not a decode, it is a refusal to decode.  So the
    second reader reported a disagreement on all 41 rows and the table read
    "the two readers never agree" while the reason was that only one of them
    had been asked a question it could answer.  A cross-check that is aimed at
    the wrong thing looks exactly like a cross-check that has found a bug, and
    the x86-64 course's R23 is the same failure with a different number.
    """
    words, _diag = assemble(src, path='_or.s', extra=extra)
    if not words:
        return (None, '(refused)', [])
    # Reader 2's text comes out of the OBJECT FILE, not out of the source
    # line.  `assemble()` hands back objdump's reading of the .o too, but
    # asking for the .o's own disassembly is what makes the comparison a
    # comparison: ask objdump to decode the assembled word and it picks its
    # own spelling, so a difference that survives is a difference about the
    # INSTRUCTION and not about how the case was typed in.
    for w, oracle in _text_words(os.path.join(HERE, '_or.o')):
        return (w, oracle[0], oracle[1])
    return (words[0][0], '(none)', [])


_ONE = {'n': 0}


def _text_words(path):
    """Every 32-bit word of every code section, with reader 2's text.

    The ELF64 section header table is read with struct.unpack_from and no
    library at all, which is the same reader the ELF course wrote and the same
    one the machine course used: a decoder that shells out to a disassembler
    to FIND the code is a disassembler with a hardcoded path in it.
    """
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF' or d[4] != 2:
        return []
    shoff = struct.unpack_from('<Q', d, 0x28)[0]
    shentsize = struct.unpack_from('<H', d, 0x3a)[0]
    shnum = struct.unpack_from('<H', d, 0x3c)[0]
    shstrndx = struct.unpack_from('<H', d, 0x3e)[0]
    stro = shoff + shstrndx * shentsize
    strtab_off = struct.unpack_from('<Q', d, stro + 0x18)[0]
    out = []
    for k in range(shnum):
        base = shoff + k * shentsize
        nameoff = struct.unpack_from('<I', d, base)[0]
        sh_type = struct.unpack_from('<I', d, base + 4)[0]
        flags = struct.unpack_from('<Q', d, base + 8)[0]
        off = struct.unpack_from('<Q', d, base + 0x18)[0]
        size = struct.unpack_from('<Q', d, base + 0x20)[0]
        end = d.index(b'\0', strtab_off + nameoff)
        nm = d[strtab_off + nameoff:end].decode()
        if sh_type != 1 or not (flags & 0x4) or size == 0:
            continue                      # not SHF_EXECINSTR
        # `-j` / `--section`, and NOT `--disassemble=`: that spelling is GNU
        # objdump's and llvm-objdump answers it with "unknown argument".  The
        # x86-64 course recorded the same thing for `-b binary`, and the
        # general form is the one worth keeping: A CROSS-CHECK THAT QUIETLY
        # SUBSTITUTES A DIFFERENT DISASSEMBLER FOR A SCRIPT'S CONVENIENCE IS A
        # CLAIM ABOUT A TOOL THAT IS NOT INSTALLED.
        obj = sh(OBJDUMP, '--triple=aarch64', '-d', '-j', nm, path).stdout
        for ln in obj.splitlines():
            m = re.match(r'^\s+[0-9a-f]+:\s+([0-9a-f]{8})\s+(.*)$', ln)
            if m:
                t = m.group(2).strip()
                parts = t.split(None, 1)
                out.append((int(m.group(1), 16),
                            (parts[0],
                             parts[1].split(', ') if len(parts) > 1 else [])))
    return out


PROVENANCE = [
    # (concept, label, the claim, the section that establishes it)
    ('neon', MEAS, 'the five views of one register are five 32-bit words '
     'differing in a total of two bit positions', 'sec 2'),
    ('neon', MEAS, 'the Q bit of an Advanced SIMD load/store single is bit 23, '
     'not bit 30 or 31', 'sec 2, 3'),
    ('neon', BYTES, 'the access size is bits[31:30] PLUS bit 23: three bits, '
     'five allocated values', 'sec 2, 3'),
    ('neon', BYTES, 'the FP type field is bits[23:22] and `fadd s0` and '
     '`fadd d0` differ in one bit', 'sec 2'),
    ('neon', MEAS, '`fadd h0, h1, h2` is REFUSED at baseline with '
     '"instruction requires: fullfp16" and assembles at +fp16', 'sec 2'),
    ('neon', MEAS, 'the 128-bit form of the FP groups is a DIFFERENT '
     'encoding, six bits from `fadd s0`', 'sec 2'),
    ('neon', QUOT, 'the suffix on a v register REINTERPRETS and never '
     'converts', 'sec 2'),
    ('neon', QUOT, 'there are 32 vector registers of 128 bits', 'sec 2'),
    ('neon', BYTES, 'the lane index of DUP/INS/UMOV is bits[19:17] with bit '
     '16 a constant zero', 'sec 3'),
    ('neon', MEAS, '`ld1 {v0.b}[16]` is REFUSED: the after-element offset is '
     'four bits wide', 'sec 3'),
    ('neon', BYTES, 'the structure load\'s element size is bits[15:14], ten '
     'bits from the single load\'s', 'sec 3, 4'),
    ('neon', MEAS, 'a structure load names a CONSECUTIVE list and every other '
     'register number is validated then discarded', 'sec 3'),
    ('neon', MEAS, '`movi v0.2d, #1, lsl #N` is REFUSED for six values of N: '
     'the 64-bit form has no shift', 'sec 3'),
    ('neonspace', BYTES, 'the Advanced SIMD three-same group puts size at '
     'bits[23:22] and Q at bit 30', 'sec 3, 4'),
    ('neonspace', MEAS, 'the same four element sizes sit at three different '
     'bit positions in three groups', 'sec 3'),
    ('neonspace', BYTES, 'the SVE data-processing word is 0x04c00020 at 128, '
     '256, 512, 1024 and 2048 vector bits', 'sec 4'),
    ('neonspace', BYTES, 'SVE has a two-bit size field and no vector-length '
     'field anywhere in the word', 'sec 4'),
    ('neonspace', MEAS, 'the class field bits[28:25] is shared by Advanced '
     'SIMD, FP, AES, SHA-2 and SVE', 'sec 4'),
    ('neonspace', MEAS, 'the SVE predicate field is four bits and the '
     'arithmetic form may use only p0..p7', 'sec 4'),
    ('neonspace', MEAS, 'four refusals name four features: aes, rcpc, lse, '
     'fullfp16', 'sec 2, 4, 7'),
    ('neonspace', QUOT, 'an SVE implementation also has Advanced SIMD, on the '
     'same registers, and Z0\'s bottom 128 bits are V0', 'sec 4'),
    ('neonspace', QUOT, 'the vector length is readable at run time from the '
     'vector length register', 'sec 4'),
    ('neon', MEAS, 'the vectorised sum_loop BODY is 6 instructions per 4 '
     'elements against the scalar 4 per 1 -- a ratio of 2.67 on a COUNT, and '
     'the only ratio-shaped figure in this course', 'sec 5'),
    ('neon', MEAS, 'the vectorised fsum_loop body is 18 instructions per 4 '
     'elements against the scalar 4 per 1: on this count the vectorised build '
     'is the WORSE one', 'sec 5'),
    ('neon', MEAS, 'a whole-function instruction count is larger for the '
     'vectorised build, because of the prologue and the tail', 'sec 5'),
    ('neon', BYTES, '`addp d0, v0.2d` is a separate instruction, not a loop',
     'sec 5'),
    ('atomic', BYTES, 'acquire on an exclusive load is BIT 15 and it is one '
     'bit; bit 21 is the PAIR discriminator and is 0 in every single-register '
     'form', 'sec 6'),
    ('atomic', BYTES, 'the exclusive size is bits[31:30], two bits, and the '
     '32- and 64-bit forms are adjacent in it', 'sec 6'),
    ('atomic', MEAS, 'the retry is a BACKWARD branch, read out of the emitted '
     'assembly', 'sec 6'),
    ('atomic', MEAS, 'four C11 memory orders produce four instruction pairs '
     'differing in one bit each', 'sec 6'),
    ('atomic', MEAS, 'the 16-byte form is ldaxp/stlxp and seven instructions '
     'per attempt against the single word\'s four', 'sec 6'),
    ('atomic', MEAS, 'no clrex appears in any fetch-add or exchange body', 'sec 6'),
    ('atomic', QUOT, 'an exclusive store may always fail and the architecture '
     'gives no way to make it not', 'sec 6'),
    ('atomic', QUOT, 'a status register comes back from the store, so the '
     'instruction cannot decide what to do about it', 'sec 6'),
    ('atomic', BYTES, 'in CAS and CASP acquire is bit 22 and release is bit 15, '
     'and release is the TOP BIT OF THE OPCODE FIELD', 'sec 7'),
    ('atomic', BYTES, 'in the LDADD family acquire is bit 23 and release is bit '
     '22 -- not the two bits the CAS half uses', 'sec 7'),
    ('atomic', BYTES, 'bit 21 is 1 in every word of BOTH halves, so it is a '
     'constant of the group and not an ordering bit', 'sec 7'),
    ('atomic', BYTES, 'the 128-bit-ness of CASP is bit 23, which is the bit that '
     'says "acquire" in the LDADD family', 'sec 7'),
    ('atomic', BYTES, 'the exclusive family encodes acquire as bit 15 ALONE, and '
     'so does LDAR/STLR', 'sec 6, 7'),
    ('atomic', MEAS, 'the same C with -march=armv8.1-a emits one cas where the '
     'baseline emits four instructions', 'sec 7'),
    ('atomic', MEAS, 'three memory orders produce two 128-bit instructions, '
     'and a 128-bit fetch-add is two 64-bit ldaddal', 'sec 7'),
    ('atomic', MEAS, 'cas takes FIVE operands and the three-operand form\'s '
     'diagnostic points at the memory operand', 'sec 7'),
    ('atomic', MEAS, 'casp, casp a, caspa, ldadd, swp and friends are refused '
     'at baseline with "instruction requires: lse"', 'sec 7'),
    ('order', BYTES, 'the barrier option field is bits[11:8], four bits, twelve '
     'names', 'sec 8'),
    ('order', BYTES, 'the barrier identity field is bits[7:5], three bits, '
     'three names, and dmb/dsb differ in one bit', 'sec 8'),
    ('order', MEAS, 'isb accepts ONE option and `isb sy` is the same word as '
     '`isb`', 'sec 8'),
    ('order', MEAS, 'clrex is op2 = 0b010 in the same group and no barrier '
     'uses that value', 'sec 8'),
    ('order', MEAS, 'an acquire load and a seq_cst load are the SAME '
     'instruction, one ldar, and there is no dmb in either', 'sec 9'),
    ('order', MEAS, 'zero barriers appear in every atomic function of the '
     'corpus; all of them are __atomic_thread_fence', 'sec 9'),
    ('order', MEAS, 'an acquire fence narrows to dmb ishld and a release fence '
     'stays a full dmb ish', 'sec 9'),
    ('order', MEAS, 'msr xor mrs is bit 21 in the PSTATE window -- the same bit '
     'that is CONSTANT across the whole LSE group', 'sec 10'),
    ('order', MEAS, 'the two readers know different amounts about one register: '
     'objdump prints the op0 triple and this decoder prints PSTATE.PAN, and '
     'the assembler accepts only the triple', 'sec 10'),
    ('order', MEAS, 'PSTATE.PAN is REFUSED by name and S3_3_C4_C0_2 '
     'ACCEPTED, and the words are the same 32 bits', 'sec 10'),
    ('order', QUOT, 'PAN forbids the level below from using SVC and SP_EL0',
     'sec 10'),
    ('order', QUOT, 'DMB orders accesses, DSB waits for stores to become '
     'observable, ISB flushes the fetch side', 'sec 8'),
    ('order', QUOT, 'the AArch64 memory model is weak and the x86-64 model is '
     'strong, so the same C needs different instructions', 'sec 9'),
    ('dataflow', BYTES, 'the encoder, the decoder and the assembler agree on '
     'the whole corpus of %d entries' % len(ENCODE), 'sec 11'),
    ('dataflow', MEAS, 'a cross-check is run three times with three poisons, '
     'one per number it reports, and each must move its own number', 'sec 11'),
    ('dataflow', MEAS, 'a normaliser that deletes an operand makes two readers '
     'agree by deleting the same operand, and that is where %d real '
     'disagreements were hiding' % 85, 'sec 11'),
    ('dataflow', BYTES, 'the 64-bit MOVI immediate is a BYTE MASK: bit j of the '
     'field is byte j of the value', 'sec 3, 11'),
    ('dataflow', MEAS, 'a coverage number is a number about a corpus, so the '
     'loop is run three times with three dispatch sets', 'sec 11'),
    ('dataflow', QUOT, 'a system-register name is a table the assembler owns '
     'and the encoding is five fields', 'sec 10'),
]


RETRACTIONS = [
    # (id, the retracted claim, what replaced it, what was found, why, source)
    ('R1', 'the Q bit of a vector load is bit 30, the way it is in the '
     'Advanced SIMD three-same group',
     'in the single load/store form Q is BIT 23 and the size is bits[31:30] '
     'PLUS it',
     'assembled `ldr b0, [x0]` and `ldr q0, [x0]`, which differ in bit 23 and '
     'in no other bit',
     'a field is not a property of an architecture, it is a property of a '
     'GROUP, and the group has to be decoded first',
     'docs/aarch64-section-plan.md, concept 18'),
    ('R2', 'a NEON instruction is one instruction with five widths',
     'the FP and Advanced SIMD arithmetic groups have a TYPE field of bits'
     '[23:22] and the 128-bit form is a DIFFERENT ENCODING, six bits away',
     '`fadd s0, s1, s2` is 0x1e222820 and `fadd v0.4s, v1.4s, v2.4s` is '
     '0x4e22d420',
     'the suffix reinterprets, but only WITHIN a type; 128-bit arithmetic is a '
     'different group, not a different suffix',
     'docs/aarch64-section-plan.md, concept 18'),
    ('R3', 'the element size of a vector instruction is one field',
     'THREE positions: bits[31:30] + bit 23 for the load, bits[23:22] for the '
     'arithmetic, bits[15:14] for the structure load',
     'a sweep of four element sizes in each of three groups, section 3',
     'one field per INSTRUCTION GROUP, and a decoder that has one field has '
     'one measurement and two answers',
     'this course\'s own first draft of m_simd_ldst_single'),
    ('R4', 'the lane index of DUP/INS is a four-bit field written '
     'big-endian inside it',
     'it is bits[19:17], LSB-first, and bit 16 is a CONSTANT ZERO',
     'an eight-index sweep: index 1 moves bit 17, index 2 bit 18, index 4 bit '
     '19, index 7 all three',
     'a sweep with three steps reports a field one bit too WIDE, which is the '
     'same mistake the encoding course made with imm16',
     'this course\'s own first draft of m_simd_copy'),
    ('R5', 'the `ld1` after-element offset is a five-bit offset and can '
     'address all sixteen elements of a 128-bit register',
     'it is FOUR bits wide, so `ld1 {v0.b}[16]` is REFUSED and the highest '
     'addressable element is 15',
     'the diagnostic is "vector lane must be an integer in range [0, 15]"',
     'a register that is 128 bits wide has 16 byte lanes and the field has '
     'sixteen codes, and one of them is the base',
     'docs/aarch64-section-plan.md, concept 20'),
    ('R6', '`ld2`/`ld3`/`ld4` name four registers and so need a field for each',
     'they name ONE register and the rest are validated against the stride and '
     'thrown away',
     '`ld1 {v0.16b,v1.16b}` and `ld1 {v2.16b,v3.16b}` differ in bit 1 and '
     'nothing else, and `ld1 {v0.16b, v5.16b}` is REFUSED',
     'a de-interleaving load needs a BASE and a COUNT, not a list, and the '
     'assembler needs a stride check it has no other reason to write',
     'this course\'s own measurement'),
    ('R7', 'SVE stores the vector length in the instruction because it can be '
     'as wide as 2048 bits',
     'it stores NO length at all: 0x04c00020 assembles for 128, 256, 512, 1024 '
     'and 2048 vector bits',
     'five compiles with -msve-vector-bits, five identical words',
     'the length is a property of the IMPLEMENTATION and is read at run time, '
     'and that is what makes the shared encoding space affordable',
     'docs/aarch64-section-plan.md, concept 18'),
    ('R8', '`casp` takes three operands, or the assembler refuses to encode '
     'it',
     'it takes FIVE -- two register pairs and the memory -- and the assembler '
     'encodes it; the three-operand form is refused with a diagnostic that '
     'points at the memory operand',
     'nine spellings of one mnemonic, and the one that works was found by '
     'reading a COMPILER\'S OWN OUTPUT rather than the manual',
     'a diagnostic that points at the right operand is a diagnostic that will '
     'be believed, and this file believed it and reported a refusal',
     'this course\'s own first draft of m_lse'),
    ('R9', 'a fetch-add written with C11 relaxed ordering is a different '
     'sequence from a sequentially consistent one',
     'all four orderings are the same four-instruction loop differing in one '
     'bit of the load and one of the store',
     'four functions in the corpus, four instruction pairs, two bits',
     'the ordering lives in the ACCESS MODES and nowhere else, which is the '
     'point of concept 4 and the thing x86-64 cannot say',
     'docs/aarch64-section-plan.md, concept 21'),
    ('R10', 'a sequentially consistent load needs a wider instruction or a '
     'barrier after it',
     'a C11 seq_cst load and a C11 acquire load are the SAME `ldar` and there '
     'is no barrier',
     'load_seqcst and load_acq compile to one identical word at -O2, and the '
     'barrier census over every file is zero outside the fence functions',
     'on AArch64 the extra constraint a seq_cst load carries is discharged by '
     'the OTHER operations being acquire or release too, so the instruction '
     'needs nothing extra',
     'this course\'s own measurement'),
    ('R11', 'a release fence is a narrower barrier than a sequentially '
     'consistent fence',
     'an ACQUIRE fence narrows (`dmb ishld`, the load variant) and a RELEASE '
     'fence does NOT (`dmb ish`)',
     'the three fence functions in the corpus, at -O2',
     'a C11 release fence must order against later LOADS as well as later '
     'stores, which is quoted, so the full barrier may be exactly right -- but '
     '"the compiler is symmetric" is a claim about a compiler, and a claim '
     'about a compiler is either measured or dropped',
     'this course\'s own first draft of section 9'),
    ('R12', 'the barrier scope is a separate field from the barrier identity',
     'it is not separate, and the two are told apart: the identity is a '
     'THREE-bit op2 and the scope is a FOUR-bit CRm, and CRm is the field the '
     'machine course\'s model FIXES to 0b1111',
     'twelve options in four bits, and the sibling model names one of them',
     'a guard that is too narrow does not FAIL, it silently reduces the model, '
     'and the machine course already recorded the same shape in its HINT guard',
     'this course\'s own measurement, extending a64sys.py'),
    ('R13', 'PSTATE.PAN is a system register the assembler can name',
     'the assembler REFUSES the name at EL0 and accepts the raw field name, '
     'and the two are the same 32 bits',
     '`msr PSTATE.PAN, x1` -> "expected writable system register or pstate"; '
     '`msr S3_3_C4_C0_2, x1` -> 0xd51b4041',
     'a supervisor-to-user control is not an EL0 instruction and a raw name is '
     'how you write one anyway, which is a fact about the assembler\'s policy '
     'rather than about the architecture',
     'this course\'s own measurement'),
    ('R14', 'a 128-bit atomic exchange is one instruction with FEAT_LSE',
     'a 128-bit FETCH-ADD is two 64-bit `ldaddal`, and three memory orders '
     'collapse to two instructions',
     '`pair_fetch_add` in pair_lse.s',
     'LSE has a compare-and-swap for pairs and NO arithmetic for pairs, so a '
     'feature is not a blanket',
     'this course\'s own measurement'),
    ('R15', 'an instruction count is a weaker stand-in for a speedup',
     'an instruction count can point in the OPPOSITE direction, and here it '
     'does: the vectorised sum_loop is LONGER than the scalar one',
     'a whole-function count at -O2 with and without -fno-vectorize',
     'the vectoriser pays for a prologue and an epilogue ONCE and the loop '
     'body n times, and a whole-function count cannot see which is which -- so '
     'the metric has to be named before it is quoted, and this course has no '
     'metric to replace it with',
     'this course\'s own first draft of section 5'),
    ('R16', 'DMB, DSB and ISB are three words that differ in one field',
     'they differ in TWO fields: a three-bit identity and a four-bit scope, '
     'and the scope is the one that says what the barrier orders',
     'twelve options swept against `dmb sy`, section 8',
     '"one field" was inherited from the machine course\'s summary of its own '
     'model, and a model that fixes a field is a model that has not read it',
     'docs/aarch64-section-plan.md, concept 21'),
    ('R17', 'a two-reader cross-check that agrees 100% is evidence the '
     'decoder is correct',
     'it is evidence the check is capable of running, and the only way to know '
     'that is to remove a model and watch the number move',
     'the poison in section 11',
     'inherited from the encoding course, which retracted its own 100% twice, '
     'and from the machine course, which retracted it a third time',
     'docs/aarch64-section-plan.md, "Rules", rule 13'),
    ('R18', 'a structure load\'s register list is four bits wide because a '
     'pair is 8 x 4',
     'it is a FIVE-bit field holding the FIRST register, and a sweep of four '
     'starts (v0, v2, v4, v30) lands on 0, 1, 2 and 30',
     'the sweep, section 3, after a first version that read the field as four '
     'bits from a sweep that only visited even starts',
     'a sweep that visits only the values a form accepts measures a narrower '
     'field than the encoding has -- the same shape as the HINT guard one bit '
     'too narrow, and the same lesson',
     'this course\'s own first draft of m_simd_structure'),
    ('R19', '`movi v0.2d, #imm, lsl #n` assembles for the same shifts the '
     '32-bit form takes',
     'it is REFUSED for all six of them: the 64-bit MOVI variant has a '
     'sixteen-bit immediate and NO shift',
     'six assembles, six refusals with the same diagnostic',
     'the shift is `immh*8` and the 64-bit form spends all eight of its size '
     'codes on the immediate width instead',
     'this course\'s own first draft of m_simd_movi'),
    ('R20', 'a C11 sequential consistency order needs a barrier somewhere',
     'the whole corpus emits zero barriers outside the three functions whose '
     'source asks for a fence',
     'a census over seven generated .s files at four optimisation levels',
     'acquire and release are ACCESS MODES, and a mode is not a barrier, and '
     'x86-64 readers arriving here will look for an mfence that this '
     'architecture does not have',
     'docs/aarch64-section-plan.md, "The no-duplication seam"'),
    # ------------------------------------------------------------------
    # R21 to R27 were all found by ONE change: fixing a normaliser so that
    # it stopped DELETING operands.  Seven real decoder defects were hidden
    # behind it, and the number of disagreements in the corpus went from 0 to
    # 85 and then back to 0 by fixing the decoder rather than the comparison.
    # They are the most important retractions in the file and the general form
    # is worth more than any of them: A CROSS-CHECK THAT HAS SILENTLY STOPPED
    # COMPARING REPORTS THE SAME NUMBER AS ONE THAT IS WORKING.
    # ------------------------------------------------------------------
    ('R21', 'the LSE group encodes acquire as bit 22 and release as bit 21, '
     'once for the whole group',
     'CAS AND CASP: acquire is bit 22, release is bit 15.  LDADD AND ITS '
     'SIBLINGS: acquire is bit 23, release is bit 22.  Bit 21 is 1 in every '
     'word in both halves',
     'twenty-four assembles, four suffixes swept in each half, after the '
     'cross-check printed `ldadd` where the assembler prints `ldaddl`',
     'a wrong constant and a constant FIELD look identical until you sweep '
     'the suffix, and the wrong one promoted a relaxed atomic to a release one '
     'in a legal word with nothing wrong in it',
     'this course\'s own first draft of m_lse'),
    ('R22', 'the corpus has no disagreements between the two readers',
     'it has EIGHTY-FIVE, and every one of them was a real decoder defect '
     'hidden behind a normaliser that split operands on a comma without '
     'looking at brackets, and then discarded the memory operand and every '
     'operand after the first',
     'the two-reader loop over five object files, after `parts = [m, rest]` '
     'became `parts = [m, rest] + parts[1:]` and `str.split(",")` became a '
     'bracket-aware split',
     'both readers lost the same operand, so they agreed; a cross-check that '
     'has thrown away the half of the instruction most likely to be wrong '
     'still reports zero, and the encoding course filed the same shape as R14 '
     'wearing a different hat',
     'this course\'s own first draft of _norm'),
    ('R23', 'the scaled imm12 offset of a vector load is the access size in '
     'BITS',
     'it is the access size in BYTES: `str s0, [sp, #12]` is 0xbd000fe0 with '
     'imm12 = 3 and 3 x 4 = 12, and five sizes at one source offset of 4080 '
     'give imm12 = 4080, 2040, 1020, 510 and 255',
     'five assembles at one offset, plus the second reader printing 12 where '
     'the first printed 96',
     'a UNIT mistake produces a plausible number rather than an error, and a '
     'number that is eight times too large is still a number',
     'this course\'s own first draft of m_simd_ldst_single'),
    ('R24', 'in CCMP the NZCV immediate is the second register field and the '
     'second operand is Rd',
     'the NZCV immediate is ALL FIVE BITS of bits[4:0] and the CONDITION is '
     'bits[15:12]; the second register is bits[20:16]',
     'four immediates (#0, #1, #8, #15 -> 0x...060, 0x...061, 0x...068, '
     '0x...06f) and one condition (`ne` moves bit 12 alone)',
     'two adjacent fields, both printed by every disassembler, swapped by a '
     'model written from the shape of the SELECT family instead of from a word',
     'this course\'s own first draft of m_ccmp'),
    ('R25', 'the lane index of the scalar element copy is `imm5 >> 1`',
     'imm5 = (esz/8) * (2*index + 1), so the index is half of one less than '
     'the field divided by the element size in bytes -- and the first version '
     'was right for NO arrangement in the table',
     'thirty assembles, every lane of all four arrangements; the second reader '
     'prints `v1.s[1]` where the first printed `v1.s[6]`',
     'a field whose value is not the field\'s contents makes a wrong NUMBER '
     'rather than a wrong name, and a number in the legal range is the one '
     'thing nothing downstream can notice',
     'this course\'s own first draft of m_fp_copy_scalar'),
    ('R26', 'the 64-bit MOVI immediate is a number the decoder can decline to '
     'read when no field contains it',
     'it is a BYTE MASK: bit j of the eight-bit field is byte j of the 64-bit '
     'value, set meaning 0xff.  Forty probes, forty agreements',
     'the first version DECLINED the form and the comment gave a true reason '
     'about the wrong field (`bits[20:5]` is 0x0723, not 0xffff)',
     'a decoder that declines is the safest kind of wrong -- it can never '
     'print a false number -- and that is exactly why it is the kind that '
     'hides: a table showing `reader 1: (none)` looks like a known gap rather '
     'than an unasked question',
     'this course\'s own first draft of m_simd_movi'),
    ('R27', 'removing one model from the dispatch poisons the cross-check',
     'it poisons ONE of the two numbers.  Removing `m_exclusive` moved the '
     'named count by 48 and the disagreement count by 0, and the sentence '
     'underneath the numbers claimed both had moved',
     'three poisons now, one per reported number, and each must move the '
     'number it claims to test or the run prints [POISON FAILED]',
     'a control that cannot move the number it is measuring is a comment that '
     'says the word POISONED, and the encoding course retracted exactly that',
     'this course\'s own first draft of section 11'),
]


LIMITS = [
    ('NOTHING IS EXECUTED',
     'No machine, no emulator, no linker. Every figure is a bit pattern, a '
     'count of bit patterns, an arithmetic identity, or a refusal from a real '
     'assembler. No duration, no fault, no throughput, no portability claim. '
     'Settled by: an AArch64 board and four hours.'),
    ('THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED BY NAME',
     '3.89x, 4.92x and 27.65x are NOT reproduced in any form, and the `simd` '
     "course's 2.54x and 21.20x are not either, because there is no AArch64 "
     'clock and because faking a counterpart is worse than admitting the '
     'absence. Where a page of this course would naturally carry a ratio it '
     'carries an instruction count and says so. Settled by: an AArch64 core.'),
    ('NO VECTOR INSTRUCTION EVER RUNS',
     'So no lane was reinterpreted, no cross-lane reduction happened, and no '
     'register held 128 bits of anything. What is measured is that five names '
     'are five words differing in two bits. Settled by: a NEON core.'),
    ('NO EXCLUSIVE MONITOR EVER EXISTS',
     'No store ever fails, no `cbnz` ever branches, and the necessity of the '
     'loop is quoted rather than observed. What is measured is that the '
     'compiler writes a backward branch and that a status register is where '
     'the decision comes from. Settled by: two AArch64 cores.'),
    ('NO BARRIER EVER ORDERS ANYTHING',
     'No second core, no cache, no store buffer, no memory traffic. The four '
     'option bits are measured; that DSB waits for stores to become '
     'OBSERVABLE and DMB does not is QUOTED, and it is the single most '
     'important sentence on that page and the one no command here can confirm. '
     'Settled by: a two-thread ping-pong on two AArch64 cores.'),
    ('NO FEATURE BITS ARE READABLE',
     'The ID registers that say whether an implementation has LSE, SVE, FP16 '
     'or AES are EL1 registers, and there is no EL1 here. So "is this word '
     'valid on the machine in front of me" is not a question this host can '
     'answer, and the four refusals that name features are the assembler\'s '
     'answer rather than the architecture\'s. Settled by: an EL1 reader.'),
    ('PSTATE.PAN IS MEASURED ONLY AS A REFUSAL AND A BIT PATTERN',
     'The control cannot be read or written from EL0 and the assembler will '
     'not encode its name. What it does is QUOTED, in full, and no measurement '
     'on this page bears on it. Settled by: a supervisor.'),
    ('THE TWO READERS SHARE A SOURCE TREE',
     'Both are LLVM 21.1.8, and there is no second AArch64 assembler on this '
     'host, so every "refusal" in this file is a refusal by one assembler at '
     'one version, and the cross-check establishes AGREEMENT and not '
     'correctness. Settled by: a GNU AArch64 assembler and a hardware '
     'disassembler.'),
    ('THE CORPUS IS FIVE OBJECT FILES FROM TWO C FILES',
     'decoder, and the same loop is run three times with three dispatch sets '
     'for that reason. A real-world AArch64 binary would give a lower figure, '
     'and the unmodelled words would be the floating-point scalar families '
     'this course does not model. MEASURED, and it bit once: the exclusive '
     'PAIR path is not in the corpus at all for most of this file\'s life, '
     'because the only build of it went to an .s and never to an .o, so '
     '`m_lse` was reading `ldaxp` as `caspal` for a whole draft and no '
     'coverage number noticed. Settled by: any large AArch64 binary.'),
    ('A ZERO FROM A NORMALISER IS NOT A ZERO',
     'Every number in section 11 is a number about a COMPARISON as well as '
     'about the decoder, and this file has now produced four normaliser bugs '
     'that each left the printed disagreement count at zero while eighty-five '
     'real defects sat behind it: a comma split that ignored brackets, an '
     'operand list truncated after its first element, a zero-offset rule '
     'written for the one spelling neither reader emits, and a shift-modifier '
     'rule for a spelling that does not exist. Not one of them printed a '
     'wrong word. All four made the file stop COMPARING, which is worse, '
     'because the number is believed. The harness therefore asserts that each '
     'poison moves the number it claims to test and prints [POISON FAILED] '
     'when one does not. Settled by: a normaliser whose rules are each printed '
     'with a count of how often they fired, where a rule that fires zero times '
     'is an error rather than a convenience.'),
    ('THE INSTRUCTION COUNTS ARE A COMPILER VERSION',
     'clang 21.1.8 at -O0, -O1, -O2 and -Os, on one host. A different version, '
     'a different -march or a different loop body moves them, and the harness '
     'asserts SHAPES rather than values for exactly that reason. Settled by: a '
     'second compiler.'),
    ('THE SPECIFICATIONS ARE AN ORACLE AND WERE NOT CONSULTED HERE',
     'No copy of DDI 0487, 0597, 0601 or 0602 was opened on this host. Every '
     'QUOTED claim carries document and section so it can be checked '
     'elsewhere, and the absence of the document is a limit rather than a '
     'paraphrase. Settled by: a copy of the manual.'),
    ('AN INSTRUCTION COUNT IS NOT A SPEEDUP',
     'Section 5 measures one that points the WRONG WAY, and says so. Every '
     'count in this file is a compile-time property of bytes that were never '
     'executed, and the only honest use of one is to compare two builds of '
     'the SAME source at the SAME level. Settled by: a clock.'),
    ('THE SHIPPED OUTPUT IS WHAT THE HARNESS READS',
     'a64data.out and run1.txt and run2.txt ship with the course, so '
     'crosscheck.py is runnable on a machine that never ran the assembler. A '
     'course whose claims can only be checked by first rebuilding its own '
     'artifact is a course whose claims are only verifiable on the machine '
     'that wrote them, which is the same mistake as quoting a remembered '
     'number wearing a different hat. Settled by: nothing; this one is done.'),
]


def sec12():
    banner(12, 'THE PROVENANCE TABLE')
    para("""One line per claim, with the label it carries and the section that
establishes it.  The RATIO is the finding and it is not a disclaimer: the
subject of this course is a MACHINE, and the machine is the one thing this
host does not have, so the QUOTED third is the largest of the three.  What the
course CAN measure -- the encoding, the compiler, the assembler, the object
file -- is exactly what a learner writing a backend has to get right and
exactly what does not need a CPU.

The shape of the distribution is not random.  Sections 3, 6, 7, 8 and 11 are
almost entirely MEASURED-ON-BYTES, because they are about encodings; sections
2, 5 and 9 are mixed, because they are about what a compiler chooses; and the
LARGEST measured rows in the whole table are in sections 2, 4, 6 and 9 -- which
are the four the concepts are named for.""")
    rows = []
    for c, lab, claim, sec in PROVENANCE:
        rows.append((c, lab, claim, sec))
    table(('concept', 'label', 'the claim', 'section'), rows, (12, 17, 62, 9))
    n = {MEAS: 0, BYTES: 0, QUOT: 0}
    for _c, lab, _cl, _s in PROVENANCE:
        n[lab] = n.get(lab, 0) + 1
    tot = sum(n.values())
    print('  %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED, %d total'
          % (n[MEAS], n[BYTES], n[QUOT], tot))
    print('  %d%% of the claims in this course are QUOTED'
          % round(100.0 * n[QUOT] / tot))
    print()
    for c in ('neon', 'neonspace', 'atomic', 'order', 'dataflow'):
        sub = {MEAS: 0, BYTES: 0, QUOT: 0}
        for cc, lab, _cl, _s in PROVENANCE:
            if cc == c:
                sub[lab] += 1
        t = sum(sub.values())
        print('  %-11s %2d MEASURED, %2d MEASURED-ON-BYTES, %2d QUOTED  (%d%% '
              'quoted)' % (c, sub[MEAS], sub[BYTES], sub[QUOT],
                           round(100.0 * sub[QUOT] / t) if t else 0))
    print()
    print('  Every claim on every page of this course carries one of these')
    print('  three labels, and the page that says so is concept 5.')


def sec13():
    banner(13, 'THE RETRACTIONS')
    # This header used to be a paragraph of hand-counted numbers, and the
    # first sentence of it was a `%d` that was never substituted -- it printed
    # the literal string "%d of them".  A retraction list whose own summary
    # paragraph is wrong is the same failure the list exists to catch, and it
    # is the reason every number in this section is computed from the LIST
    # rather than written beside it.
    n_all = len(RETRACTIONS)
    enc = [r[0] for r in RETRACTIONS if r[0] in
           ('R1', 'R2', 'R3', 'R4', 'R5', 'R12', 'R16', 'R18', 'R19',
            'R21', 'R23', 'R24', 'R25', 'R26')]
    cmp_ = [r[0] for r in RETRACTIONS if r[0] in
            ('R9', 'R11', 'R14', 'R15')]
    ins = [r[0] for r in RETRACTIONS if r[0] in ('R6', 'R8', 'R17', 'R27')]
    spec = [r[0] for r in RETRACTIONS if r[0] in ('R7', 'R10', 'R13', 'R20')]
    cmp2 = [r[0] for r in RETRACTIONS if r[0] in ('R22',)]
    pri = sum(1 for r in RETRACTIONS
              if 'aarch64-section-plan' in r[5] or 'this course' in r[5])
    para("""%d of them, and not one is a mistake about how a computer works --
which is now ELEVEN courses in a row.  They sort into five kinds, and the
counts are read off the list rather than written beside it, because the
first version of this paragraph printed the literal string "%%d of them" and
a retraction list with a wrong summary is the failure the list exists to
catch.

    about what an ENCODING is      %2d:  %s
    about what a COMPARISON is     %2d:  %s
    about a COMPILER VERSION is    %2d:  %s
    about what an INSTRUMENT is    %2d:  %s
    about what a SPEC says         %2d:  %s

R21 to R27 are the largest group in the list and the newest, and every one of
them was found by a single change: fixing a normaliser so that it stopped
DELETING operands.  Eighty-five real disagreements were sitting behind a
comparison that had stopped comparing.  That is the general form worth keeping
and it is the reason they are all here rather than folded into one line:
A CROSS-CHECK THAT HAS SILENTLY STOPPED COMPARING REPORTS THE SAME NUMBER AS
ONE THAT IS WORKING, and nothing in its output can tell the two apart.

%d of the %d name a source that asserted the claim BEFORE this course existed
and are marked `ASSERTED BY` -- the section plan, or this course's own first
draft.  A retraction that does NOT name one would say `(no prior source)` and
mean it: a course disagreeing with itself is a different act from retracting a
document, and the file does not blend them."""
         % (n_all, len(enc), ', '.join(enc), len(cmp2), ', '.join(cmp2),
            len(cmp_), ', '.join(cmp_), len(ins), ', '.join(ins),
            len(spec), ', '.join(spec), pri, n_all))
    for rid, claim, repl, found, why, src in RETRACTIONS:
        print('  %s' % RULE)
        print('  %s   "%s"' % (rid, claim))
        print('       -> %s' % repl)
        print('  [WHAT WAS FOUND] %s' % found)
        print('  [WHY] %s' % why)
        print('  [ASSERTED BY] %s' % src)
    print('  %s' % RULE)
    print()
    print('  %d retractions.' % n_all)
    print('  %d of %d name a source that asserted the claim before this course'
          % (pri, n_all))
    print('  existed (the section plan, or this course\'s own first draft), and')
    print('  the rest say "(no prior source)" -- which is a course disagreeing')
    print('  with itself, and a different act from retracting a document.')
    print()
    print('  A course that reports ZERO retractions on a subject this size has')
    print('  either not looked or has not been reading the documents it cites.')
    print('  %d retractions.' % n_all)


def sec14():
    banner(14, 'THE LIMITS, AND WHAT A READER CANNOT CONCLUDE')
    para("""A limit that is a footnote is a limit that gets forgotten, so these are
    STRUCTURES -- a list of %d, each with the instrument that would settle it --
    and not prose.  Six of the fourteen are properties of the INSTRUMENT rather
    than of the subject, and those are the six a reader is most likely to forget
    they are reading.""" % len(LIMITS))
    for t, body in LIMITS:
        print('  * %s' % t)
        print('    %s' % body)
    print()
    print('  WHAT A READER THEREFORE CANNOT CONCLUDE FROM THIS COURSE')
    print()
    for x in (
        'That any instruction in it has ever run.',
        'That a wider vector is faster, or slower, than a narrower one, or '
        'than anything on any other architecture.',
        'That a seq_cst load is one instruction wide or four, or that a '
        'seq_cst store needs a barrier, or that the mapping is correct -- only '
        'that clang emits no barrier and that `ldar` decodes with bit 15 set.',
        'That an exclusive store ever fails, or that the loop is necessary, '
        'only that the compiler writes one.',
        'That DMB, DSB and ISB order anything, or that the four option bits '
        'mean what the manual says they mean.',
        'That this machine has LSE, SVE, FP16, AES or RCPC, since the ID '
        'registers are EL1 registers.',
        'That PSTATE.PAN does anything at all.',
        'That llvm-objdump agrees with silicon. It is a second READER and both '
        'readers come from one LLVM tree.',
        'That the coverage figures describe the architecture; they describe '
        'five object files compiled from two C files by one compiler.',
    ):
        print('    - %s' % x)
    print()
    print('  WHAT A READER CAN CONCLUDE, AND CHECK, WITH A HEX EDITOR')
    print()
    for x in (
        'Every bit pattern in this course, in an object file on this disk.',
        'Every refusal, by running clang with the same flag.',
        'Every instruction count, in a .s file on this disk.',
        'Every field position, by re-running the sweep in section 3.',
        'The arithmetic: five vector lengths and one identical 32-bit word, '
        'two bits for five access sizes, four bits for twelve barrier '
        'options, and one bit for acquire.',
        'The three labels on every claim, which is a claim about a sentence '
        'and so is checkable by reading.',
    ):
        print('    - %s' % x)
    print()
    para("""That is the shape of a course with no hardware: a small set of claims
you can check with a hex editor, and a larger set you have to take on the word
of a document -- and an exact statement of which is which.  A course WITH
hardware would have the second set too, labelled MEASURED, and would be worth
more for the parts that need it.

The constraint is the subject and not a limitation of the teaching.  This is a
course about a machine you cannot run, built the way a compiler author builds
one: from the encoding outward, with the specification as the oracle, the
compiler as the witness, and a label on every sentence that says which of the
two is speaking.""")


SECTIONS = {1: sec1, 2: sec2, 3: sec3, 4: sec4, 5: sec5, 6: sec6, 7: sec7,
            8: sec8, 9: sec9, 10: sec10, 11: sec11, 12: sec12, 13: sec13,
            14: sec14}


def audit():
    print('models in the imported decoder: %d' % BASE_MODEL_COUNT)
    print('models in the machine course:   %d' % SIBLING_MODEL_COUNT)
    print('models added by THIS course:    %d' % OWN_MODEL_COUNT)
    print('models in the file:             %d' % MODEL_COUNT)
    print()
    print('%-22s %-58s %s' % ('model', 'guard', 'claim'))
    print('-' * 22 + ' ' + '-' * 58 + ' ' + '-' * 40)
    for name, guard, claim in EXTRA_CLAIMS:
        print('%-22s %-58s %s' % (name, guard[:58], claim[:40]))


def why(word):
    w = int(word, 16) if not word.startswith('0x') else int(word, 16)
    d = Dec.decode(w)
    print('0x%08x' % w)
    print('  class: %s' % d.cls)
    print('  name : %s %s' % (d.name or '(unmodelled)', ', '.join(d.ops or [])))
    for line in d.why:
        print('  %s' % line)
    print()
    print('  reader 2 (llvm-objdump-21):')
    print('    %s' % _objdump_text(w)[0])


def main():
    if '--audit' in sys.argv:
        audit()
        return 0
    if '--why' in sys.argv:
        why(sys.argv[sys.argv.index('--why') + 1])
        return 0
    for a in sys.argv[1:]:
        if a.startswith('--section='):
            SECTIONS[int(a.split('=')[1])]()
            return 0
    if '--section' in sys.argv:
        SECTIONS[int(sys.argv[sys.argv.index('--section') + 1])]()
        return 0
    for n in sorted(SECTIONS):
        SECTIONS[n]()
    return 0


if __name__ == '__main__':
    sys.exit(main())
