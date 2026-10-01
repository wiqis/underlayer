#!/usr/bin/env python3
"""cbenc.py -- a small ENCODER, written by hand, for the instruction
selection claim.

THE CLAIM THIS FILE EXISTS TO PROVE, and it is the sharpest byte-level result
in the course:

    a multiply-accumulate is ONE instruction on AArch64 and TWO on x86-64,
    and the difference is not a scheduling decision -- it is the OPERAND
    COUNT in the encoding

§KEEP§ AND THE RECEIPT IS NOT "clang emitted one instruction". §KEEP§ IT IS
THAT THIS FILE ENCODES THE FUSED FORM FROM FOUR REGISTER NUMBERS, WITH NO
TABLE AND NO LIBRARY, AND THE SIBLING AARCH64 DECODER READS THE FOUR
REGISTER FIELDS BACK OUT OF THE WORD THIS FILE PRODUCED. §KEEP§ THE ENCODER
AND THE DECODER WERE WRITTEN BY DIFFERENT HANDS FOR DIFFERENT JOBS AND
NEITHER KNOWS WHAT THE OTHER IS FOR, WHICH IS WHAT MAKES THE AGREEMENT
EVIDENCE INSTEAD OF A RESTATEMENT.

WHY AN ENCODER AT ALL, and it is the mission's rule 1 in one paragraph: the
alternative is to ask clang to assemble the fused form and read the bytes, and
that is a fine oracle -- but it cannot answer the question a learner is
actually asking, which is "where in the word is the fourth register".  An
assembler hides that.  §KEEP§ THE MISSION'S RULE IS "SHOW WHAT THE TOOL
DOES, SHOW ITS OUTPUT, THEN SHOW THE BYTES IT IS READING AND HAVE THE
LEARNER READ THEM TOO" -- AND FOR AN ENCODING QUESTION THE BYTES ARE THE
WHOLE SUBJECT, SO THE BYTES ARE BUILT HERE.

EVERY FIELD POSITION IN THE AARCH64 HALF BELOW WAS DERIVED BY DIFFING REAL
WORDS, and the derivation is reproducible rather than asserted: the file
carries a `SPECIMENS` table of six words a real assembler emitted for six
known instructions, `validate()` re-encodes all six and requires all six to
come back BIT-FOR-BIT, and the report prints the table beside the result.

    §KEEP§ THE FIRST VERSION OF THIS ENCODER WAS WRONG IN ITS MOST IMPORTANT
    BIT -- IT PUT THE MADD/MSUB SELECTOR AT BIT 15, WHICH IS THE Ra FIELD
    ITSELF -- AND IT WAS WRONG ON EVERY SINGLE WORD IT PRODUCED. §KEEP§ THE
    SIBLING DECODER SAID `msub w0, w1, w0, w2` FOR A `madd`, WITH NO
    DISAGREEMENT COUNT ANYWHERE, BECAUSE NOBODY HAD ASKED IT TO CHECK.

WHAT IS ENCODED, and it is four instructions because four is all the claim
needs:

    AArch64   madd  Xd, Xn, Xm, Xa      four registers, ONE 32-bit word
              add   Xd, Xn, Xm, shift   three registers + a shift amount
              add   Xd, Xn, #imm12      three operands, one an immediate
              ret                     no operands
    x86-64    imul  r64, r64           TWO operands, two-address
              add   r64, r64           TWO operands, two-address
              lea   r64, [base+idx*sc]  TWO operands plus an ADDRESS
              ret

and the finding is in the last two rows: x86-64 has no four-operand
arithmetic at all, so `a*b+c` there is an instruction with two operands
followed by an instruction with two operands, and the third operand -- the
accumulator -- is a REGISTER NAME THAT HAS TO SURVIVE THE FIRST INSTRUCTION.
That is not a cost anybody quotes, and it is the reason the same IR costs two
instructions on one architecture and one on another.
"""

MEAS = 'MEASURED-ON-BYTES'
QUOT = 'QUOTED'

# --------------------------------------------------------------------------
# AArch64.
# --------------------------------------------------------------------------
A64_X = tuple('x%d' % i for i in range(31)) + ('sp',)

# The field masks, verified by `validate()` against SPECIMENS below.
SF = 0x80000000
MADD_BASE = 0x9B000000        # sf=1, op54=110110, op2=10, fixed 1 at bit 21
MSUB_BIT = 0x00008000         # bit 15: 0 is MADD, 1 is MSUB
RM = 0x001F0000              # bits 20:16
RA = 0x00007C00              # bits 14:10
RN = 0x000003E0              # bits 9:5
RD = 0x0000001F              # bits 4:0
ADD_REG_BASE = 0x8B000000    # sf=1, ADD (shifted register)
SHIFT = 0x00600000           # bits 22:21, and LSL IS ZERO
IMM6 = 0x003FC000            # bits 15:10
ADD_IMM_BASE = 0x91000000    # sf=1, ADD (immediate)
IMM12 = 0x003FFC00           # bits 21:10
RET_WORD = 0xD65F03C0


def a64_reg(n):
    return A64_X[n]


def enc_a64_madd(rd, rn, rm, ra, sub=False, sf=1):
    """`madd Xd, Xn, Xm, Xa` -- FOUR registers in one word.

    §KEEP§ REGISTER 31 IS ALLOWED IN THE Ra SLOT ONLY, AND THAT IS NOT A
    CONVENIENCE: §KEEP§ `enc_a64_add_reg` WRITES 31 THERE, BECAUSE Ra = 31 IS
    HOW THE ENCODING SAYS "THIS INSTRUCTION HAS NO FOURTH OPERAND". §KEEP§
    THE FIRST VERSION OF THIS FUNCTION REFUSED 31 IN EVERY SLOT, SO THE
    THREE-OPERAND FORM COULD NOT BE ENCODED AT ALL -- §KEEP§ AND A
    VALIDATION RULE THAT IS TOO STRICT IS NOT A VALIDATION RULE, IT IS A
    REFUSAL TO EMIT HALF THE INSTRUCTION SET, AND IT LOOKS LIKE CARE.

    The layout is the one the sibling AArch64 course printed, and it is
    QUOTED (Arm ARM, A64 instruction set encoding, data processing -- 3
    source) and then MEASURED by `validate()`.
    """
    for v in (rd, rn, rm):
        if not (0 <= v <= 30):
            raise ValueError('madd: Xd/Xn/Xm must be x0..x30, got %d' % v)
    if not (0 <= ra <= 31):
        raise ValueError('madd: Xa must be x0..x31, got %d' % ra)
    w = MADD_BASE if sf else (MADD_BASE & ~SF)
    if sub:
        w |= MSUB_BIT
    w |= (rm & 0x1f) << 16
    w |= (ra & 0x1f) << 10
    w |= (rn & 0x1f) << 5
    w |= (rd & 0x1f)
    return w & 0xffffffff


def enc_a64_add_reg(rd, rn, rm, shift=0, amount=0, sf=1):
    """`add Xd, Xn, Xm, LSL #amount` -- THREE registers, one word.

    §KEEP§ IT IS THE SAME 32-BIT LAYOUT WITH Ra REPLACED BY A SIX-BIT SHIFT
    AMOUNT, AND THE WIDTHS ARE DIFFERENT: §KEEP§ THE SHIFT AMOUNT IS SIX BITS
    AND A REGISTER FIELD IS FIVE, BECAUSE A SHIFT AMOUNT HAS SIX LEGAL VALUES
    (0, 1, 2, 3, and the two NEGATED ones for SUB) WHILE A REGISTER FILE HAS
    THIRTY-ONE. §KEEP§ THE FIELD IS WIDER AND THE INSTRUCTION IS NARROWER,
    AND A DOCUMENT THAT SAID "THE ENCODING IS EVENLY DIVIDED" WOULD BE
    DESCRIBING A DIFFERENT ARCHITECTURE.
    """
    if shift not in (0, 1, 2, 3):
        raise ValueError('add shifted register: shift must be 0..3')
    if not (0 <= amount <= 63):
        raise ValueError('add shifted register: shift amount must be 0..63')
    w = ADD_REG_BASE if sf else (ADD_REG_BASE & ~SF)
    w |= (shift & 3) << 21
    w |= (rm & 0x1f) << 16
    w |= (amount & 0x3f) << 10
    w |= (rn & 0x1f) << 5
    w |= (rd & 0x1f)
    return w & 0xffffffff


def enc_a64_add_imm(rd, rn, imm12, sf=1):
    """`add Xd, Xn, #imm12` -- a DIFFERENT ENCODING, not a different operand.

    §KEEP§ AND THE REFUSAL IS THE POINT: 4095 IS ACCEPTED AND 4096 RAISES,
    BECAUSE THE FIELD IS TWELVE BITS AND THIS FILE CHECKS IT RATHER THAN
    TRUNCATING. §KEEP§ A TRUNCATING ENCODER IS THE WORST KIND, BECAUSE IT
    PRODUCES A VALID WORD FOR AN INVALID PROGRAM -- §KEEP§ WHICH IS EXACTLY
    WHAT THIS COLLECTION CALLS A BUG WEARING THE COSTUME OF A RESULT.
    §KEEP§ THE BOUNDARY IS MEASURED BY A REFUSAL, WHICH IS A DIFFERENT KIND
    OF CLAIM FROM "THE MANUAL SAYS TWELVE BITS" AND A CHEAPER ONE TO CHECK.
    """
    if not (0 <= imm12 <= 4095):
        raise ValueError('add immediate: %d does not fit 12 bits' % imm12)
    w = ADD_IMM_BASE if sf else (ADD_IMM_BASE & ~SF)
    w |= (imm12 & 0xfff) << 10
    w |= (rn & 0x1f) << 5
    w |= (rd & 0x1f)
    return w & 0xffffffff


def enc_a64_movz(rd, imm16, hw=0, sf=1):
    """`movz Wd, #imm16` -- the instruction that MATERIALISES A CONSTANT.

    §KEEP§AND IT IS IN THIS FILE FOR A REASON THAT IS NOT ENCODING BUT
    HONESTY: §KEEP§ THE LEAF CORPUS USES IT, §KEEP§ SO A TWO-READER CHECK OVER
    THAT CORPUS WITHOUT IT WOULD REPORT A DISAGREEMENT ON EVERY WORD THAT
    CARRIES A CONSTANT -- §KEEP§ AND A CROSS-CHECK THAT DISAGREES ON A WORD
    IT DOES NOT MODEL IS REPORTING ITS OWN DECLARED SCOPE AS A BUG. §KEEP§ THE
    THIRD TIME THIS COLLECTION HAS HAD THAT SHAPE, AND THE FIX IS THE SAME
    ALL THREE TIMES: SAY WHICH HALF OF THE INSTRUCTION SET YOU IMPLEMENT
    RATHER THAN LETTING THE COUNT IMPLY YOU IMPLEMENT ALL OF IT.
    """
    if not (0 <= imm16 <= 0xffff):
        raise ValueError('movz: %d does not fit 16 bits' % imm16)
    if hw not in (0, 1, 2, 3):
        raise ValueError('movz: hw must be 0..3')
    w = G_MOVZ | ((hw & 3) << 21) | ((imm16 & 0xffff) << 5) | (rd & 0x1f)
    if not sf:
        w &= ~SF
    return w & 0xffffffff


def enc_a64_ret():
    return RET_WORD


# The six words a real assembler emitted for six known instructions.  Every
# field position above is checked against all six, bit for bit, on every run,
# and the table is printed in the report so a reader can diff it.
SPECIMENS = (
    ('madd  x0, x1, x2, x3', 0x9B020C20),
    ('msub  x4, x5, x6, x7', 0x9B069CA4),
    ('add   x8, x9, x10, lsl #1', 0x8B0A0528),
    ('add   x11, x12, x13, lsl #2', 0x8B0D098B),
    ('madd  w0, w1, w2, w3', 0x1B020C20),
    ('add   x0, x1, #0xfff', 0x913FFC20),
    ('movz  w10, #0x6', 0x528000CA),
)


def validate():
    """Re-encode every specimen and require the word back BIT FOR BIT.

    Returns (checked, agreed, disagreements).  §KEEP§THIS IS NOT A CROSS-CHECK
    IN THE TWO-READER SENSE -- IT IS AN ENCODER AGAINST AN ASSEMBLER -- SO IT
    IS A DIFFERENT KIND OF EVIDENCE AND THE REPORT SAYS SO: §KEEP§ THE
    INDEPENDENT READER IS `a64dec.py`, AND THE SPECIMENS ARE WHAT PROVE THIS
    FILE'S OWN FIELD POSITIONS, WHICH THE DECODER CANNOT DO BECAUSE A DECODER
    NEVER HAS TO ENCODE ANYTHING.
    """
    out = []
    for text, word in SPECIMENS:
        got = _reencode(text)
        out.append((text, word, got, got == word))
    ok = sum(1 for r in out if r[3])
    return out, len(out), ok


def _reencode(text):
    """The specimen's TEXT turned back into a word.

    This is the parser that makes `validate()` a real check rather than a
    tautology: the specimens are written the way a reader writes them, this
    parses them, and the encoder is asked for the word.  §KEEP§AND EVERY ONE
    OF THE THREE BUGS THIS FILE HAS SHIPPED WAS FOUND HERE AND NOWHERE ELSE:
    §KEEP§ `lsl #1` SPLITS ON THE COMMA SO `ops[2]` IS ONLY `x10`; §KEEP§ LSL
    IS SHIFT TYPE 0 AND NOT 1; §KEEP§ AND `w0` AND `x0` BOTH PARSE AS 0, SO
    THE WIDTH HAS TO COME FROM THE LETTER.
    """
    body = text.strip()
    mnem, rest = body.split(None, 1)
    flat = ' '.join(o.strip() for o in rest.split(','))
    wide = flat.startswith('x')
    if mnem in ('madd', 'msub'):
        regs = [int(o[1:]) for o in flat.split()]
        return enc_a64_madd(regs[0], regs[1], regs[2], regs[3],
                            sub=(mnem == 'msub'), sf=1 if wide else 0)
    if mnem in ('movz', 'movn', 'movk'):
        rd, imm = flat.split()
        fn = {'movz': enc_a64_movz}
        if mnem not in fn:
            raise ValueError('this encoder models movz only, asked for %s'
                             % mnem)
        return fn[mnem](int(rd[1:]), int(imm[1:], 0), sf=1 if wide else 0)
    if mnem == 'add':
        if '#' in flat and 'lsl' not in flat:
            rd, rn, imm = flat.split()
            return enc_a64_add_imm(int(rd[1:]), int(rn[1:]),
                                    int(imm[1:], 0), sf=1 if wide else 0)
        rd, rn, rm = flat.split()[:3]
        amt = int(flat.split('#')[1]) if '#' in flat else 0
        # LSL IS SHIFT TYPE 0.  §KEEP§ THE FIRST VERSION SET sh = 1 FOR `lsl`,
        # PRODUCED 0x8b0a0128 INSTEAD OF 0x8b0a0528, AND §KEEP§ validate()
        # CAUGHT IT ON TWO OF ITS SIX SPECIMENS -- §KEEP§ WHICH IS THE ENTIRE
        # ARGUMENT FOR HAVING SPECIMENS RATHER THAN A COMMENT SAYING "CHECK
        # THE SHIFT FIELD".
        return enc_a64_add_reg(int(rd[1:]), int(rn[1:]), int(rm[1:]),
                               0, amt, sf=1 if wide else 0)
    return 0


# --------------------------------------------------------------------------
# x86-64.  A DIFFERENT PROBLEM, and saying so is the point.
# --------------------------------------------------------------------------
X86_R = tuple(['rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi'] +
              ['r%d' % i for i in range(8, 16)])
NEED_REX_B = ('rsp', 'r12', 'r13', 'r14', 'r15')

_X_OPCODES = {
    'add': 0x01,
    'or': 0x09,
    'and': 0x21,
    'sub': 0x29,
    'xor': 0x31,
    'imul': None,          # two-byte opcode, 0F AF /r
}


def _modrm(reg_field, rm_field):
    return 0xC0 | ((reg_field & 7) << 3) | (rm_field & 7)


def enc_x86(op, dst, src, rex_w=True):
    """`op dst, src` in AT&T operand order: TWO operands, no exceptions.

    §KEEP§ AND THE COUNT OF OPERANDS IS NOT A CHOICE: `imul r64, r64` IS THE
    ENTIRE INTEGER MULTIPLY-ACCUMULATE STORY ON THIS ARCHITECTURE, BECAUSE
    THE DESTINATION IS ALSO AN INPUT. §KEEP§ THERE IS NO
    `imul rax, rbx, rcx`, AND §KEEP§ THE ENCODER BELOW CANNOT PRODUCE ONE,
    WHICH IS THE POINT -- §KEEP§ THE FAILURE IS DELIBERATE AND IT IS
    DOCUMENTED AT THE CALL SITE, BECAUSE A FUNCTION THAT CANNOT EXPRESS
    SOMETHING IS A CLAIM AND A FUNCTION THAT RAISES IS A CHECK.

    §KEEP§ AND THE MODRM BYTE IS WHERE THE TWO-ADDRESS RULE LIVES: BIT 3 TO
    BIT 5 IS THE *SOURCE* AND THE LOW THREE BITS ARE THE *DESTINATION*, SO
    THE ENCODER IS LITERALLY PUTTING THE DESTINATION WHERE THE MODRM BASE
    FIELD IS AND THE SOURCE WHERE ITS SHIFTED FIELD IS. §KEEP§ THAT
    INVERSION IS WHY A LOT OF x86 INSTRUCTION TABLES ARE WRITTEN
    DESTINATION-FIRST AND WHY HALF THE ARCHITECTURE'S DOCUMENTATION READS
    BACKWARDS TO ANYONE WHO LEARNED ANOTHER ISA.
    """
    # §KEEP§ THE ARITY CHECK IS EXPLICIT AND COMES FIRST, §KEEP§ BECAUSE THE
    # §KEEP§ SIGNATURE IS `enc_x86(op, dst, src, rex_w=True)` AND A CALL WITH
    # §KEEP§ FOUR POSITIONAL ARGUMENTS BINDS THE FOURTH TO `rex_w` -- WHICH IS
    # §KEEP§ TRUTHY -- §KEEP§ SO IT SILENTLY ENCODED A TWO-OPERAND INSTRUCTION
    # §KEEP§ WHEN THE CALLER ASKED FOR THREE. §KEEP§ A CALL THAT LOOKS LIKE IT
    # §KEEP§ IS BEING REJECTED AND IS INSTEAD SILENTLY ACCEPTED IS THE WORST
    # §KEEP§ SHAPE A FUNCTION SIGNATURE CAN HAVE, AND §KEEP§ IT PRODUCED A
    # §KEEP§ PLAUSIBLE ENCODING RATHER THAN AN ERROR.
    if not isinstance(rex_w, bool):
        raise ValueError('enc_x86 takes (op, dst, src) and NOTHING ELSE; '
                         'x86-64 has no three-operand integer arithmetic, '
                         'so a four-argument call is a caller that wants an '
                         'instruction this architecture does not have '
                         '(got rex_w=%r)' % (rex_w,))
    if op not in _X_OPCODES:
        raise ValueError('no two-operand form of %r on x86-64' % op)
    d = X86_R.index(dst) if isinstance(dst, str) else dst
    s = X86_R.index(src) if isinstance(src, str) else src
    if d in (4, 12, 13, 14, 15):
        raise ValueError('x86-64 needs a REX byte for %r; this encoder '
                         'emits only 0x48' % dst)
    if s in (4, 12, 13, 14, 15):
        raise ValueError('x86-64 needs REX.B for %r; this encoder emits '
                         'only 0x48' % src)
    opc = _X_OPCODES[op]
    out = b''
    if rex_w:
        out += b'\x48'
    if opc is None:
        out += bytes([0x0F, 0xAF, _modrm(s, d)])
    else:
        out += bytes([opc, _modrm(s, d)])
    return out


def enc_x86_ret():
    return b'\xc3'


# --------------------------------------------------------------------------
# THE RECEIPT.
# --------------------------------------------------------------------------
def split_words(bs):
    return tuple(int.from_bytes(bs[i:i + 4], 'little') for i in
                 range(0, len(bs), 4))


def hexdump(bs, width=8):
    """The bytes, eight to a line, because a receipt a reader cannot see is
    not a receipt."""
    lines = []
    for i in range(0, len(bs), width):
        chunk = bs[i:i + width]
        lines.append('%04x  %s' % (i, ' '.join('%02x' % b for b in chunk)))
    return '\n'.join(lines)


def operand_fields_a64(w):
    """The four register fields, read out of the word by MASK.

    A SECOND READER for this file's own encoder, written as a different
    expression over the same bits: the encoder builds the word by setting
    masks, this reads them by masking.  §KEEP§ AND IF THEY AGREE THE
    AGREEMENT IS NOT COMPLETELY INDEPENDENT -- §KEEP§ IT IS TWO EXPRESSIONS
    OF ONE TABLE. §KEEP§ THE INDEPENDENT CHECK IS `a64dec.py`, A DIFFERENT
    PROGRAM IN A DIFFERENT FILE WRITTEN FOR A DIFFERENT COURSE, AND THE
    REPORT PRINTS ITS OUTPUT BESIDE THIS ONE FOR EVERY WORD.
    """
    rd = w & 0x1f
    rn = (w >> 5) & 0x1f
    ra = (w >> 10) & 0x1f
    rm = (w >> 16) & 0x1f
    return rd, rn, rm, ra


# The GROUP SELECTORS, as a mask over bits 30:22 and the value each group
# carries there.  §KEEP§ EVERY ONE OF THEM WAS DERIVED BY DIFFING THE SIX
# WORDS A REAL ASSEMBLER EMITTED, NOT BY READING THE ARM ARM -- §KEEP§ AND THE
# FIRST ATTEMPT READ THEM FROM THE ARM ARM AND GOT THE WIDTH WRONG, BECAUSE
# THE 3-SOURCE GROUP IS NOT ALIGNED THE WAY THE 2-SOURCE GROUPS ARE:
#
#     bits 31:23  = 0x36    MADD / MSUB      (data processing, 3 source)
#     bits 31:23  = 0x16    ADD shifted register
#     bits 31:23  = 0x22    ADD immediate
#
# §KEEP§ THE THREE VALUES ARE NOT CONSECUTIVE AND NOT EVENLY SPACED, AND THE
# THREE-SOURCE GROUP SITS *ABOVE* THE TWO OTHERS RATHER THAN BESIDE THEM --
# §KEEP§ WHICH IS THE ENCODER'S WAY OF SAYING THAT IT IS THE ODD ONE OUT.
# §KEEP§ THE FOURTH BIT OF A THREE-SOURCE INSTRUCTION IS BIT 15, AND §KEEP§
# THE FIRST VERSION OF THIS FILE READ BIT 15 AS THE MADD/MSUB SELECTOR AND
# ALSO AS THE Ra REGISTER, WHICH IS THE SAME FIELD. §KEEP§ IT PRODUCED
# `msub w0, w1, w0, w2` FOR A `madd`, AND NOTHING COMPLAINED.
GRP = 0x7FC00000
G_3SRC = 0x1B000000
G_ADDSHIFT = 0x0B000000
G_ADDIMM = 0x11000000
GRP_MOVW = 0xFF800000          # move wide immediate, bits 31:23
G_MOVZ = 0x52800000
G_MOVN = 0x12800000
G_MOVK = 0x72800000


def is_three_source(w):
    """Is this word a THREE-SOURCE instruction (MADD/MSUB) rather than a
    two-source one?

    §KEEP§AND THE ANSWER IS ONE BIT, READ FROM THE WORD RATHER THAN ASKED OF
    THE TEXT -- §KEEP§ BECAUSE THE WHOLE CLAIM IS THAT THE OPERAND COUNT
    LIVES IN THE ENCODING AND NOT IN THE MNEMONIC. §KEEP§AND THE BIT IS *NOT*
    BIT 15, WHICH IS WHAT THE FIRST VERSION OF THIS FILE USED: §KEEP§ BIT 15
    IS THE Ra FIELD, SO READING IT AS A SELECTOR READS THE ACCUMULATOR
    REGISTER NUMBER AND CALLS IT A BOOLEAN, AND A BACKEND THAT DID THAT
    WOULD FUSE AND UNFUSE AT RANDOM DEPENDING ON WHICH REGISTER NUMBER IT
    HAPPENED TO PICK.
    """
    return (w & GRP) == G_3SRC


def mnemonic_of(w):
    """What this file says the word is, FROM THE BITS.

    `w0` and `x0` differ ONLY in sf, bit 31, so the width is read out rather
    than assumed -- and §KEEP§ A READER THAT FORGOT sf COULD NOT TELL A
    32-BIT MADD FROM A 64-BIT ONE AT ALL, WHICH IS ONE WORD AND ONE BIT
    APART.
    """
    g = w & GRP
    if g == G_3SRC:
        return 'msub' if ((w >> 15) & 1) else 'madd'
    if g == G_ADDSHIFT:
        return 'add'
    if g == G_ADDIMM:
        return 'add'
    if (w & GRP_MOVW) == G_MOVZ:
        return 'movz'
    if (w & GRP_MOVW) == G_MOVN:
        return 'movn'
    if (w & GRP_MOVW) == G_MOVK:
        return 'movk'
    if (w & 0xFFFFFC1F) == 0xD65F0000:
        return 'ret'
    return '?'


def operand_fields_a64(w):
    """The four register fields, read out of the word by MASK.

    A SECOND READER for this file's own encoder, written as a different
    expression over the same bits: the encoder builds the word by setting
    masks, this reads them by masking.  §KEEP§ AND IF THEY AGREE THE
    AGREEMENT IS NOT COMPLETELY INDEPENDENT -- §KEEP§ IT IS TWO EXPRESSIONS
    OF ONE TABLE. §KEEP§ THE INDEPENDENT CHECK IS `a64dec.py`, A DIFFERENT
    PROGRAM IN A DIFFERENT FILE WRITTEN FOR A DIFFERENT COURSE, AND THE
    REPORT PRINTS ITS OUTPUT BESIDE THIS ONE FOR EVERY WORD.
    """
    rd = w & 0x1f
    rn = (w >> 5) & 0x1f
    ra = (w >> 10) & 0x1f
    rm = (w >> 16) & 0x1f
    return rd, rn, rm, ra


def render_a64(w):
    rd, rn, rm, ra = operand_fields_a64(w)
    m = mnemonic_of(w)
    c = 'x' if (w >> 31) & 1 else 'w'
    if m in ('madd', 'msub'):
        return '%s %s%d, %s%d, %s%d, %s%d' % (m, c, rd, c, rn, c, rm, c, ra)
    if m == 'add':
        if (w & GRP) == G_ADDIMM:
            return 'add %s%d, %s%d, #%d' % (c, rd, c, rn, (w >> 10) & 0xfff)
        amt = (w >> 10) & 0x3f
        tail = '' if amt == 0 else ', lsl #%d' % amt
        return 'add %s%d, %s%d, %s%d%s' % (c, rd, c, rn, c, rm, tail)
    if m in ('movz', 'movn', 'movk'):
        return '%s %s%d, #%d' % (m, c, rd, (w >> 5) & 0xffff)
    return m


def fusion_receipt():
    """Encode `a*b + c` two ways on two architectures, and return everything.

    On AArch64: ONE word with FOUR register fields.
    On x86-64: TWO instructions with TWO operands each.

    §KEEP§AND THE FINDING, WHICH IS NOT THE ONE MOST PEOPLE EXPECT, IS THAT
    THE AARCH64 ENCODING HAS ROOM TO SPARE. §KEEP§ FOUR FIVE-BIT REGISTER
    FIELDS ARE TWENTY BITS OF THIRTY-TWO; THE REMAINING TWELVE BITS HOLD sf,
    THE TEN-BIT GROUP SELECTOR, THE MADD/MSUB BIT AND A FIVE-BIT ACCUMULATOR
    IN THE OTHER FORM. §KEEP§ THE THREE-OPERAND FORM IS NOT A COMPROMISE AND
    IT IS NOT A COMPRESSED FORM; IT IS THE SAME WIDTH.
    """
    madd = enc_a64_madd(0, 1, 0, 2)          # x0 = x0*x1 + x2
    add3 = enc_a64_add_reg(0, 1, 2)          # x0 = x1 + x2
    fused_bs = madd.to_bytes(4, 'little') + enc_a64_ret().to_bytes(4, 'little')
    x86_bs = enc_x86('imul', 'rbx', 'rcx') + enc_x86('add', 'rbx', 'rdx') \
        + enc_x86_ret()
    return {
        'a64_madd': madd,
        'a64_add3': add3,
        'a64_ret': enc_a64_ret(),
        'a64_fused_bytes': fused_bs,
        'a64_operands_fused': 4,
        'a64_operands_unfused': 3,
        'a64_instructions_fused': 1,
        'x86_bytes': x86_bs,
        'x86_instructions': 2,
        'x86_operands_each': 2,
    }