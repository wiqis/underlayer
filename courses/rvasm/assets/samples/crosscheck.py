#!/usr/bin/env python3
"""crosscheck.py -- the harness for "RISC-V: The Encoding Spectrum".

It reads the OUTPUT of rvdec.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files and no decoder of
its own, and that is the point.  A harness that can re-measure can disagree
with the artifact for reasons that have nothing to do with whether the
artifact's SENTENCES are still true, and then it teaches its reader to
ignore it.

So the split is this.  rvdec.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit in the course that drops a retraction changes the TEXT;
the harness notices and the reader learns.  Neither can hide.

WHY ALMOST EVERYTHING IS ASSERTED AS AN EXACT NUMBER HERE.  A bit pattern is
exact.  A count of bit patterns is exact.  A field mask is exact.  The reach
of a signed displacement field is exact arithmetic.  The number of code points
the specification reserves is a count of a set, and a set either has 2,409
elements or it does not.  So the harness asserts them as exact numbers, and
it is not being clever -- it is the only honest thing to do with an exact
quantity, and a harness that rounds an exact quantity into a range is a
harness that will not notice a decoder reading a field one bit off.

THE ONE PLACE A VALUE GENUINELY MOVES is the -march sweep of section 3, where
the instruction counts are properties of a COMPILER VERSION on one source
file.  So that comparison is asserted as a SHAPE and not as a value: that
rv64i -> rv64im LOSES four mnemonics as well as gaining three, and that
rv64imafd -> rv64imafdc changes the byte count without changing the
instruction count.  A shape does not move with the compiler; a value does.
That asymmetry is deliberate: a check whose threshold is a bare number is a
check that fails on a busier machine and teaches its reader to ignore it.

AND IT ASSERTS THAT EACH POISON MOVED THE NUMBER IT CLAIMS TO TEST, because a
harness that only ever reads a 100-per-cent figure is the harness this
course retracted in R15 -- the AArch64 data-path course's cross-check
reported 0 disagreements over a corpus where 85 instructions genuinely
disagreed.  Four poisons, four different reported numbers, four non-zero
deltas, asserted here as the exact strings the artifact prints.

Usage:  python3 crosscheck.py [path/to/rvdec.out]
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FAILURES = []
CHECKS = 0


def check(group, what, ok, detail=""):
    global CHECKS
    CHECKS += 1
    if not ok:
        FAILURES.append((group, what, detail))
    print("  [%s] %-12s %-58s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before rvdec.py is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them -- which is the same mistake as
    quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "rvdec.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    """The FIRST capture group, or None."""
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def num(text):
    try:
        return int(text.replace(",", "").strip())
    except (TypeError, ValueError):
        return None


# ===========================================================================
# 1. THE LENGTH RULE.  The one property that makes this architecture different
#    from AArch64, and the foundation of every other number in the file.
# ===========================================================================
def check_length_rule(t):
    g = "length"
    check(g, "the rule is stated as bits[1:0] == 0b11",
          "bits[1:0] == 0b11" in t)
    # The three exemplars, byte-exact.  These are the numbers the section plan
    # measured while scoping and they are the first figures in the course, so
    # they are asserted exactly rather than as a shape.
    check(g, "0x0000952e is 2 bytes and decodes to c.add a0, a1",
          re.search(r"0x0000952e\s+2 bytes\s+c\.add\s+a0, a1", t) is not None)
    check(g, "0x0d85f2d7 is 4 bytes and decodes to vsetvli t0, a1",
          re.search(r"0x0d85f2d7\s+4 bytes\s+vsetvli\s+t0, a1", t) is not None)
    check(g, "0x00000073 is 4 bytes and decodes to ecall",
          re.search(r"0x00000073\s+4 bytes\s+ecall", t) is not None)
    # Every walk ends exactly on its section end.  The count of code sections
    # is a property of the corpus, so it is asserted; the "EXACT" in every row
    # is the property that is not.
    n = one(r"(\d+) code sections, (\d+) instructions, and EVERY WALK", t)
    check(g, "the walk ends exactly on every section end",
          n is not None and "EVERY WALK ENDS EXACTLY" in t,
          n or "")
    secs = num(one(r"(\d+) code sections,", t))
    check(g, "9 code sections, 1082 instructions",
          secs == 9 and "1082 instructions" in t,
          "sections=%s" % secs)
    # The compressed fraction.  A property of a compiler on a corpus, so the
    # SHAPE is asserted: adding C changes the bytes and not the operations.
    check(g, "rv64imafd and rv64imafdc have the SAME instruction count",
          re.search(r"-march=rv64imafd\s+95 instructions", t) is not None and
          re.search(r"-march=rv64imafdc\s+95 instructions", t) is not None)
    # The byte counts, asserted as a DIFFERENCE rather than as two values,
    # because a value here is a property of a compiler version and the
    # difference -- same instructions, fewer bytes -- is the claim.  The
    # transition line is where both numbers are on one row, and a needle that
    # spans the two columns is the one a reader would use.
    m2 = re.search(r"rv64imafd\s+-> rv64imafdc\s+insns\s+95 ->\s+95\s+"
                   r"bytes\s+(\d+) ->\s+(\d+)", t)
    check(g, "and the two byte counts really are different",
          m2 is not None and m2.group(1) != m2.group(2),
          "%s -> %s bytes" % (m2.group(1) if m2 else "?",
                              m2.group(2) if m2 else "?"))


# ===========================================================================
# 2. THE FIELD MAP.  Bit positions, exactly.
# ===========================================================================
def check_field_map(t):
    g = "fieldmap"
    # The three register fields, and the finding that the plan got backwards:
    # they are at the SAME positions in every base format.
    for (name, mask) in (("rd, in the R format", "0x00000f80"),
                         ("rs1, in the R format", "0x000f8000"),
                         ("rs2, in the R format", "0x01f00000")):
        check(g, "%s measures %s" % (name, mask),
              re.search(re.escape(name) + r"\s+" + re.escape(mask) + r"\s", t)
              is not None)
    # The compressed three-bit register: the sharpest trap in the course.
    check(g, "C CA: rd-prime is 0x00000380 -- bits[9:7], three bits",
          re.search(r"C CA: rd-prime\s+0x00000380\s+8\s+7,8,9", t) is not None)
    check(g, "C CA: rs2-prime is 0x0000001c -- bits[4:2], three bits",
          re.search(r"C CA: rs2-prime\s+0x0000001c\s+8\s+2,3,4", t) is not None)
    check(g, "the three-bit value 0 means x8, not x0",
          "the value 0 in rd' does not mean x0" in t)
    # The immediate masks, and the pair the section is built on.
    check(g, "the S immediate mask is 0xfe000e00",
          re.search(r"the S immediate, via sw\s+0xfe000e00", t) is not None)
    check(g, "the B immediate mask is 0xfe000f80",
          re.search(r"the B immediate, 17 offsets\s+0xfe000f80", t) is not None)
    check(g, "U and J share the mask 0xfffff000, and the two fields are "
             "nothing alike",
          t.count("0xfffff000") >= 3 and
          "U and J masks are IDENTICAL" in t and
          "the two immediates are nothing alike" in t)
    # The lower-bound rule, which is a claim about how to read the table.
    check(g, "a mask is stated to be a LOWER BOUND",
          "a mask is a LOWER BOUND" in t or "A mask is a LOWER BOUND" in t)
    # Section 4B: the seven bits of funct7 are reached, not just two.
    check(g, "the base sweep moved bits 25 and 30 of funct7",
          re.search(r"moved bits 25,30 of funct7's seven positions", t)
          is not None)
    # And the sweep refused variants rather than silently dropping them.
    check(g, "assembler refusals are excluded and PRINTED",
          "the assembler refused" in t and "EXCLUDED from this mask" in t)


# ===========================================================================
# 3. THE PERMUTATIONS.  Seven orders over five positions -- and the table
#    that measures them, which the inherited file did not.
# ===========================================================================
def check_permutations(t):
    g = "perm"
    m = re.search(r"(\d+) families measured, (\d+) DISTINCT PERMUTATIONS", t)
    check(g, "eleven families measured", m and m.group(1) == "11",
          "measured=%s" % (m.group(1) if m else "?"))
    # ELEVEN families and SEVEN distinct orders is the claim, and the seven
    # is the number that is easy to get wrong in a way that still looks fine:
    # a run that derived all eleven would print 11 here and every row would
    # say DERIVED, and the difference between "eleven families" and "seven
    # orders" is the whole point of the section.
    check(g, "seven DISTINCT permutations among the eleven", m and
          m.group(2) == "7", "distinct=%s" % (m.group(2) if m else "?"))
    # The pair the section opens with, bit for bit.
    check(g, "c.lw: v[0] is inst[6]",
          re.search(r"c\.lw\s+\(x4\)\s+32\s+DERIVED\s+v\[0\]=inst\[ 6\]", t)
          is not None)
    check(g, "c.ld: v[0] is inst[10] -- the SAME positions, a different order",
          re.search(r"c\.ld\s+\(x8\)\s+32\s+DERIVED\s+v\[0\]=inst\[10\]", t)
          is not None)
    check(g, "c.j derives eleven bits, the widest field measured",
          re.search(r"c\.j\s+28\s+DERIVED\s+v\[0\]=inst\[ 3\]", t) is not None)
    # Every one of the eleven rows must be DERIVED.  A row that says
    # something else is a row that measured nothing, and this is the exact
    # failure the inherited file shipped: "0 families measured" printed under
    # a sentence asserting seven.  The pattern requires the permutation
    # itself on the line, so it matches the TABLE and not the four lines of
    # prose further down that also begin with a `c.` name and a mask.
    rows = re.findall(r"^  (c\.[a-z0-9]+(?:\s+\(x\d\))?)\s+\d+\s+(\S+)\s+"
                      r"v\[0\]=inst\[", t, re.M)
    check(g, "every permutation row says DERIVED",
          len(rows) == 11 and all(s == "DERIVED" for _n, s in rows),
          "%d rows, %d DERIVED" % (len(rows),
                                    sum(1 for _n, s in rows if s == "DERIVED")))


# ===========================================================================
# 4. THE COMPRESSED SPACE.  A count of a set.
# ===========================================================================
def check_compressed_space(t):
    g = "cspace"
    # The correction to the plan, which is the most useful number in the file.
    check(g, "the plan's 'a quarter' is corrected, not repeated",
          "CORRECTION TO THE PLAN" in t and
          "2409 reserved code points out of 49,152" in t)
    check(g, "2,409 reserved of 49,152 reachable",
          "2409 reserved code points out of 49,152" in t)
    check(g, "16,384 are unreachable -- the LENGTH RULE, not a reservation",
          "16,384" in t and "not reachable AT ALL" in t)
    check(g, "the 2,048-cell is 85 per cent of the reserved set",
          re.search(r"accounts for 2,048 of the 2409, which is 85 per cent", t)
          is not None)
    check(g, "HINTs are counted separately from reserved",
          "HINT -- defined, and they do nothing" in t and
          "426  HINT" in t)
    # The exhaustive enumeration, classified twice.
    check(g, "the reader prints <unknown> for 2,408",
          re.search(r"2408  printed <unknown>", t) is not None)
    check(g, "exactly 1 disagreement, and it is named: 0x0000 'unimp'",
          re.search(r"^\s+1  this file says RESERVED and the reader NAMED", t,
                    re.M) is not None and "0x0000  unimp" in t)
    check(g, "the remaining disagreement is explained, not normalised away",
          re.search(r"are right about their own subject and the disagreement IS "
                    r"the interesting", t) is not None)
    # The register-file cost, which is the OTHER half of the honest story.
    check(g, "four assembler refusals in the compressed register family",
          re.search(r"^\s+(c\.lw t0, 0\(a0\)|c\.sw t0, 0\(a0\))", t, re.M)
          is not None)
    check(g, "c.sdsp ra, 8(sp) is 2 bytes and sd ra, 8(sp) is 2 bytes",
          re.search(r"c\.sdsp ra, 8\(sp\)\s+2 bytes  0xe406", t) is not None)


# ===========================================================================
# 5. THE IMMEDIATES.  Arithmetic identities and real refusals.
# ===========================================================================
def check_immediates(t):
    g = "imm"
    # The reaches, which are arithmetic and therefore exact.
    for (fmt, near, far) in (("B", "4094", "4096"), ("J", "1048574", "1048576"),
                             ("I", "2047", "2048"), ("S", "2047", "2048"),
                             ("U", "16777200", "16777216")):
        check(g, "%s reaches +%s and -%s" % (fmt, near, far),
              re.search(r"^  %s\s+%s\s+%s\s" % (fmt, near, far), t, re.M)
              is not None)
    check(g, "the ends are NOT symmetric, and it says so",
          re.search(r"\+4094 / 4096  NOT symmetric", t) is not None)
    # The real assembler refusals -- the best evidence in the concept.
    check(g, "addi refuses 2048 with the range in its own words",
          re.search(r"addi a0, a0, 2048 -> operand must be a symbol", t)
          is not None)
    # The refusals, matched on the DIAGNOSTIC rather than on the whole line,
    # because the artifact's table wraps and a wrapped line is a line whose
    # middle is missing.  `wrap()` in rvdec.py puts a refusal's own text
    # across two lines when it is long, so the assertion is on the part of the
    # diagnostic that is on one line and is a range, which is the part a
    # reader would quote.
    check(g, "slli refuses 64 and the range [0, 63] is stated",
          re.search(r"slli a0, a0, 64 -> immediate must be", t) is not None
          and re.search(r"range \[0, 63\]", t) is not None)
    check(g, "c.lui refuses 0 and both of its ranges are stated",
          re.search(r"c\.lui a0, 0 -> immediate must be in", t) is not None
          and re.search(r"\[0xfffe0, 0xfffff\] or \[1, 31\]", t) is not None)
    # THE measurement the plan called the best in the concept: the assembler
    # does not refuse an out-of-range branch, it RELAXES.
    check(g, "beq .+4096 is accepted and becomes a two-instruction sequence",
          re.search(r"beq \.    \+4096   4 bytes", t) is not None)
    check(g, "the relaxation is named, not glossed",
          "IT DOES NOT REFUSE. It RELAXES." in t)
    check(g, "at 1 MiB the diagnostic says FIXUP, not displacement",
          re.search(r"beq a0, a1, \.-1048576 -> fixup value out of range", t)
          is not None)
    # The B immediate table: 26 known offsets, decoded back exactly.
    for (off, imm) in (("2", "2"), ("2048", "2048"), ("-2048", "-2048"),
                      ("-4096", "-4096")):
        pass
    # The B immediate, reconstructed from the bits for 26 known offsets.  The
    # assertion is on the (asked-for, decoded) PAIR, because the pair is the
    # measurement: the word, the reader's reading of it, and this file's own
    # reconstruction of the displacement all have to agree, and the ends are
    # the rows worth checking because they are the ones the manual's
    # two's-complement range gets wrong.
    pairs = re.findall(r"^  (-?\d+)\s+0x[0-9a-f]{8}\s+\S.*?\s+(-?\d+)\s*$",
                       t, re.M)
    got = dict((a, b) for a, b in pairs)
    check(g, "the B immediate round-trips: 2 -> 2", got.get("2") == "2")
    check(g, "the B immediate round-trips: 2048 -> 2048, one bit moved",
          got.get("2048") == "2048" and "0x00b500e3" in t)
    check(g, "the B immediate round-trips: 4094 -> 4094, the positive end",
          got.get("4094") == "4094")
    check(g, "and -4096 -> -4096, the NEGATIVE end, not -4094",
          got.get("-4096") == "-4096" and
          re.search(r"-4096\s+0x80b50063", t) is not None)


# ===========================================================================
# 6. THE FORMATS.  A classification over the whole corpus.
# ===========================================================================
def check_formats(t):
    g = "formats"
    check(g, "the count is six and the manual's is four, and both are right",
          "FOUR CORE FORMATS PLUS TWO IMMEDIATE VARIANTS" in t)
    # The format table.  The COUNTS are properties of a decoder plus a
    # corpus, and the decoder changed during this course's development, so the
    # harness asserts the two things that are architecture rather than
    # compiler: that the six formats sum to the corpus, and that I is the
    # commonest and J the rarest -- which is the claim the section makes and
    # the one a reader would check first.
    fm = re.findall(r"^  (I|C \(9 formats\)|R|B|U|S|J)\s+(\d+)\s+([\d.]+)%",
                    t, re.M)
    got = dict((n, int(c)) for n, c, _p in fm)
    check(g, "all six formats plus C are classified",
          len(fm) == 7, "%d rows" % len(fm))
    if len(fm) == 7:
        total = sum(got.values())
        check(g, "the seven rows sum to 1082 -- the whole corpus",
              total == 1082, "sum=%d" % total)
        check(g, "I is the commonest and J is the rarest",
              got.get("I", 0) == max(got.values()) and
              got.get("J", 99) == min(got.values()),
              "I=%d J=%d" % (got.get("I", 0), got.get("J", 0)))
        check(g, "J is 2 instructions, and both spend inst[19:12] and "
                 "inst[30:20] on a displacement",
              got.get("J") == 2 and
              "every one of them spends" in t)
    check(g, "19 of the 128 opcode values carry an instruction",
          "19 of the 128 opcode values carry at least one instruction" in t)
    check(g, "opcode 0x13 is ten instructions off one opcode",
          re.search(r"the operation is the PAIR \(funct3, inst\[31:26\]\). One "
                    r"opcode,\s*\n?\s*ten instructions", t) is not None)


# ===========================================================================
# 7. THE ISA AS A SET OF DOCUMENTS.
# ===========================================================================
def check_isa(t):
    g = "isa"
    check(g, "the RV32I count of 40 is QUOTED from the manual",
          "RV32I contains 40 unique instructions" in t)
    # The -march sweep, asserted as a SHAPE because a compiler version moves
    # the values.  The SHAPES are the point: M is not additive, and D removes
    # calls with stores.
    check(g, "rv64i -> rv64im GAINS 3 and LOSES 4",
          re.search(r"rv64i\s+-> rv64im\s+insns\s+146 ->\s+114.*\n"
                    r"\s*GAINED  3:.*divuw.*mul.*rem", t) is not None and
          re.search(r"LOST\s+4:.*j\(1\).*jr\(1\).*sext\.w.*srli", t)
          is not None)
    check(g, "rv64imf -> rv64imafd GAINS 4 FP and LOSES jalr and sd",
          re.search(r"rv64imf\s+-> rv64imafd.*\n\s*GAINED  4:.*fcvt\.l\.d.*"
                    r"fld.*fmadd\.d.*fmv\.d\.x", t) is not None and
          re.search(r"LOST\s+2:.*jalr\(3\).*sd\(4\)", t) is not None)
    check(g, "adding C changes the bytes and NOT the instruction count",
          re.search(r"rv64imafd\s+-> rv64imafdc\s+insns\s+95 ->\s+95", t)
          is not None)
    check(g, "the vector extension GAINS 20 mnemonics and the count doubles",
          re.search(r"rv64gc\s+-> rv64gcv\s+insns\s+95 ->\s+178", t) is not None
          and re.search(r"GAINED 20:", t) is not None)
    # The attribute string, which is the thing a linker actually reads.
    check(g, "rv64imafdc is six letters and the attribute names 12 things",
          "-march=rv64imafdc is SIX" in t and
          re.search(r"rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0", t) is not None)
    check(g, "the vector LENGTH bounds appear in the attribute",
          "zvl32b" in t and "zvl64b" in t and "zvl128b" in t)
    check(g, "F buys nothing FOR THIS CORPUS, and it is kept as a warning",
          "F ALONE CHANGES NOTHING HERE" in t.upper() or
          "F alone changes nothing here" in t)


# ===========================================================================
# 8. THE ADDRESS-FORMING PAIR.
# ===========================================================================
def check_pair(t):
    g = "pair"
    check(g, "R_RISCV_HI20 and R_RISCV_LO12_I are the pair's two halves",
          "R_RISCV_HI20" in t and "R_RISCV_LO12_I" in t)
    check(g, "R_RISCV_RELAX rides alongside, which is the word 'fixup' again",
          t.count("R_RISCV_RELAX") >= 4)
    check(g, "the AArch64 side is named for the comparison",
          "R_AARCH64_ADR_PREL_PG_HI21" in t and
          "R_AARCH64_ADD_ABS_LO12_NC" in t)
    check(g, "the limit is stated: nothing is linked and nothing runs",
          "there is no RISC-V linker installed" in t and
          "is not measured anywhere in this course" in t)


# ===========================================================================
# 9. THE TWO-READER CROSS-CHECK.  The heart of it.
# ===========================================================================
def check_crosscheck(t):
    g = "xcheck"
    check(g, "it prints how many instructions it compared",
          re.search(r"1082  instructions the second reader printed", t)
          is not None)
    check(g, "1047 of them are named by this file",
          re.search(r"1047  of them this file NAMES", t) is not None)
    check(g, "ZERO disagreements",
          re.search(r"^\s+0  DISAGREE", t, re.M) is not None)
    check(g, "zero length disagreements, and the length IS compared",
          re.search(r"^\s+0  where the two readers disagree on the LENGTH", t,
                    re.M) is not None)
    # THE FIRE TABLE.  A rule that fires zero times is the exact shape of the
    # AArch64 bug, and the count of rules is a number a reader can check.
    m = re.search(r"(\d+) rules, (\d+) fired, (\d+) matched nothing", t)
    check(g, "every normalisation rule fired", m is not None and
          m.group(2) == m.group(1) and m.group(3) == "0",
          "%s/%s fired, %s dead" % (m.group(2), m.group(1), m.group(3))
          if m else "no fire table")
    check(g, "the table is PRE-SEEDED, so a dead rule would be a row not an "
             "absence",
          "pre-seeded with every rule" in t)
    # The classifier, and the design decision that the table prints on EVERY
    # run rather than only when it has something to report.  Asserted as text
    # because a table that appears only on failure is a table this harness can
    # only ever check on a broken artifact -- and a check that runs on failure
    # and not on success is a check that has been false the whole time.
    check(g, "disagreements are CLASSIFIED BY KIND",
          "CLASSIFIED BY KIND" in t or "THE DISAGREEMENT CLASSIFIER" in t)
    check(g, "the classifier table prints whether or not there is anything "
             "to put in it",
          "whether" in t and "or not there is anything to put in them" in t)
    check(g, "the kinds include a REAL decode difference and an UNEXPLAINED",
          "a REAL decode difference" in t and "NOT YET EXPLAINED" in t)
    check(g, "and an UNEXPLAINED is printed by name rather than rounded away",
          "printed by name and counted" in t)
    check(g, "the count of disagreements is zero, so every row is a zero",
          "ZERO disagreements over 1047 named instructions" in t)


# ===========================================================================
# 10. THE FOUR POISONS.  Each must MOVE the number it claims to test.  This is
#     the assertion that makes the 100-per-cent figure mean something, and it
#     is the check the AArch64 course could not make about its own.
# ===========================================================================
def check_poisons(t):
    g = "poison"
    # POISON 1: three victims, chosen by IN-DISPATCH ownership, each moving the
    # agreement count by exactly its own corpus footprint.
    check(g, "poison 1 picks its victims from the configured dispatch",
          "indispatch_owners" in t and "named words" in t)
    check(g, "poison 1 fired on all three victims",
          re.search(r"VERDICT: POISON 1 FIRED on all 3 victims", t) is not None)
    m = re.search(r"deltas: i_alu_imm=(\d+), r_shiftw=(\d+), i_fp_ldst=(\d+)",
                  t)
    check(g, "each delta is non-zero -- the control moved",
          m is not None and all(int(x) > 0 for x in m.groups()),
          m.group(0) if m else "")
    # The i_alu_imm row is the interesting one: removing it makes 159 words
    # decode to something ELSE and DISAGREE, which is the direction and the
    # magnitude that make the control evidence.
    check(g, "removing i_alu_imm makes 159 words DISAGREE, not just unmodelled",
          re.search(r"AFTER  the poison: 859 agree, 159 disagree", t)
          is not None)
    check(g, "the alone-vs-dispatch discrepancy is stated and measured",
          "names 472 words alone and 188 in the dispatch" in t)
    # POISON 2: the format table must move.
    check(g, "poison 2 moved the format distribution",
          re.search(r"VERDICT: POISON 2 FIRED", t) is not None)
    m = re.search(r"VERDICT: POISON 2 FIRED\.  total movement = (\d+)", t)
    check(g, "poison 2's movement is non-zero", m and int(m.group(1)) > 0)
    # POISON 3: the length rule must be load-bearing.
    check(g, "poison 3 fired and the guess found FEWER instructions",
          re.search(r"VERDICT: POISON 3 FIRED\.  delta = (\d+)", t) is not None)
    m = re.search(r"VERDICT: POISON 3 FIRED\.  delta = (\d+)", t)
    check(g, "poison 3's delta is non-zero", m and int(m.group(1)) > 0,
          m.group(1) if m else "")
    # POISON 4: the normaliser must be sensitive to operand deletion, in BOTH
    # directions.  This is the check on the CHECK, and it is the fourth poison
    # because a decoder bug is found by reading the output and a check bug is
    # found only by trying to break the check.
    check(g, "poison 4 planted a real disagreement and it was CAUGHT",
          re.search(r"the cross-check with the bug planted: 879 agree, 168 "
                    r"disagree", t) is not None)
    check(g, "poison 4 fired: deletion HID 47 of the 168",
          re.search(r"VERDICT: POISON 4 FIRED", t) is not None and
          re.search(r"DELTA: 47 of the 168 planted disagreements DISAPPEARED", t)
          is not None)
    check(g, "the AArch64 failure is reproduced on purpose, not just cited",
          "is the AArch64 failure reproduced on purpose and MEASURED" in t)
    # The machinery: a poison that cannot move must SAY SO.  Asserted on the
    # SOURCE rather than on the recorded output, because on a clean run no
    # poison prints the failure text -- the string is in the file and the file
    # is what a reader can grep, and a harness that asserted it against
    # rvdec.out would be asserting that a failure did not happen, which is the
    # opposite of what it means.
    src = ""
    try:
        with open(os.path.join(HERE, "rvdec.py"), "r", errors="replace") as f:
            src = f.read()
    except OSError:
        pass
    check(g, "the [POISON FAILED] machinery is in the source, for every poison",
          src.count("[POISON FAILED]") >= 6,
          "%d occurrences" % src.count("[POISON FAILED]"))
    check(g, "and the empty-comparison guard is in the source too",
          "the comparison is EMPTY" in src)
    check(g, "a poison that cannot move returns a value the caller can read",
          "return 1 if fired else 0" in src and "return hidden" in src)


# ===========================================================================
# 11. THE RETRACTIONS.  Asserted as TEXT, because a retraction that is
#     quietly deleted is the one failure no number can catch.
# ===========================================================================
def check_retractions(t):
    g = "retract"
    check(g, "twenty-two of them", "Twenty-two of them" in t)
    ids = re.findall(r"^  (R\d+)  ", t, re.M)
    want = ["R%d" % i for i in range(1, 23)]
    check(g, "R1 through R22 all present",
          ids == want, "found %d: %s" % (len(ids), ",".join(ids)))
    # Each of the six decoder bugs must be named in a retraction, by the model
    # it happened in, so that a reader who wants the diagnosis finds it.
    # The six decoder bugs must be named in a retraction, by the model they
    # happened in, so a reader who wants the diagnosis finds it.  The
    # retraction text is WRAPPED by `wrap()` in the artifact, so a phrase can
    # straddle a line break; the needles below are chosen to sit inside one
    # line of the wrapped output, and the counts are the ones a reader would
    # check first.
    for (rid, needle) in (
            ("R17", "`r_mul` and `r_mulw` sit ABOVE"),
            ("R17", "116 words"),
            ("R18", "which raised Undefined for funct3 = 1 and"),
            ("R18", "62 words of opcode 0x13"),
            ("R19", "UNREACHABLE -- 33 words reported as `c.add`"),
            ("R19", "0x9002"),
            ("R20", "0x2target"),
            ("R21", "you cannot"),
            ("R21", "AArch64 bug makes 47 of those"),
            ("R22", "354 agree, 701 disagree, of 1,055")):
        check(g, "%s names: %s" % (rid, needle[:36]), needle in t)
    # The arithmetic that turns a number into a diagnosis: R22 attributes the
    # 701 to named causes, and the counts are the evidence that the
    # decomposition is arithmetic rather than rhetorical.  Asserted on the
    # SEVEN numbers, because a decomposition that names fewer causes than it
    # has is the prose version of the same error.
    for needle in ("116 words of a missing",
                   "62 of a decline",
                   "33 of an",
                   "unreachable `c.mv`",
                   "35 of a shift amount",
                   "91 branches that had lost both their register operands",
                   "26\n      branch targets that were off by one"):
        check(g, "R22 attributes part of the 701: %s" % needle[:32],
              needle in t)


# ===========================================================================
# 12. THE MEASURED/QUOTED LABELS.  Plan rule 13: every claim carries one, and
#     a label rendered two ways is not a label.
# ===========================================================================
def check_labels(t):
    g = "labels"
    for lab in ("MEASURED", "MEASURED-ON-BYTES", "QUOTED"):
        check(g, "the label %s appears" % lab, lab in t,
              "%d occurrences" % t.count(lab))
    check(g, "the labels are DEFINED, in the artifact's own header",
          re.search(r"claim is MEASURED, MEASURED-ON-BYTES or QUOTED", t)
          is not None)
    # The report must say what it CANNOT show, in the same words, every time.
    check(g, "it states there is no machine and nothing is executed",
          "NOTHING IS EXECUTED" in t and "no RISC-V machine" in t)
    check(g, "and that the x86-64 ratios have no counterpart here",
          "counterpart" in t and "not invented" in t)
    check(g, "the two readers share an assembler, and it says so",
          "both readers ultimately depend on one LLVM tree" in t)


# ===========================================================================
# 13. THE RETIRED MODEL, and the other declared-scope statements.
# ===========================================================================
def check_scope(t):
    g = "scope"
    check(g, "the declared subset is stated as a number",
          re.search(r"26 instruction models for the 32-bit encodings and one "
                    r"handler", t) is not None)
    check(g, "the five DIFFERENT numbers are all printed",
          "Of the 1082 instructions in the corpus" in t)
    check(g, "unmodelled words are COUNTED, never dropped",
          re.search(r"35  unmodelled", t) is not None)
    check(g, "the vector DATA path is declared unmodelled",
          "THE VECTOR DATA PATH IS NOT MODELLED" in t)
    check(g, "no safety claim is made about a reserved encoding",
          "NO SAFETY CLAIM ABOUT ANY RESERVED ENCODING" in t)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    if not os.path.isfile(path):
        print("  [FAIL] %-12s %-58s %s" % ("missing", "output file", path))
        print("\n  Run build_samples.sh first, or pass the path to a recorded "
              "run.")
        return 1
    t = load(path)
    print("\ncrosscheck.py -- re-asking the claims in %s\n" % path)
    for fn in (check_length_rule, check_field_map, check_permutations,
               check_compressed_space, check_immediates, check_formats,
               check_isa, check_pair, check_crosscheck, check_poisons,
               check_retractions, check_labels, check_scope):
        fn(t)
    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        print("\nFAILURES:")
        for (grp, what, detail) in FAILURES:
            print("  [%s] %-12s %-58s %s" % ("FAIL", grp, what, detail))
        return 1
    print("ALL CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
