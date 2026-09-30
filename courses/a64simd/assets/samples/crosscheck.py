#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The AArch64 Data Path: NEON, Atomics and
Ordering".

It reads the OUTPUT of a64data.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files, no decoder of its
own, and no toolchain of any kind, and that is the point.  A harness that can
re-measure can disagree with the artifact for reasons that have nothing to do
with whether the artifact's SENTENCES are still true, and then it teaches its
reader to ignore it.

So the split is this.  a64data.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit that drops a retraction changes the TEXT; the harness
notices and the reader learns.  Neither can hide.

WHY SO MUCH IS ASSERTED AS TEXT, in this file's own words: this course is
about a machine nobody in it has ever run, so a large part of it is
QUOTATIONS, and a quotation is a claim about a SENTENCE -- a number in a
paragraph that names a document.  If a paragraph is reworded and the number
stays, the claim is unchanged and a numeric check would be right to pass.  If
a paragraph is reworded and the number GOES, the claim has been withdrawn
without anybody noticing, and the only thing that catches it is an assertion
about the text.

AND THE FOURTH KIND, which this course needed and the three before it did not:

  * CONTROL  for the POISON.  The one number this course is most careful
    about is a ZERO, and a zero is only worth something if the check can
    fail.  So the harness does not merely read the disagreement count; it
    reads the three poison lines and requires that each one moved the number
    it claims to test.  The artifact prints [POISON FAILED] when one does
    not, and this harness requires the sentence to be ABSENT, which is the
    same check stated from the other side.

FOUR KINDS OF ASSERTION, and the split is the point:

  * EXACT    for anything the ENCODING or the ARITHMETIC owns and this file
    measured: every bit pattern, every field position, every XOR, the
    two-reader agreement, the barrier option names, the LSE suffix bits.
    An exact quantity has one honest treatment.
  * SHAPES   for anything that is a property of a COMPILER VERSION: the
    instruction counts, the register choices, the coverage percentages.
    These move.  A check whose threshold is a bare number from one compiler
    is a check that fails on a busier machine and teaches its reader to
    ignore it.
  * CONTROL  for the poison, as above.
  * TEXT     for all twenty-seven retractions, for the provenance table, and
    for every limit, because a retraction IS a claim about a number that is
    otherwise fine, and a course that quietly dropped one would pass every
    other check in this file.

Usage:  python3 crosscheck.py [path/to/a64data.out]
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
    print("  [%s] %-8s %-58s %s" % ("PASS" if ok else "FAIL", group, what,
                                   detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before a64data.py is ever built.  A course whose claims can only be
    verified by first rebuilding its own artifact is a course whose claims are
    only verifiable on the machine that wrote them -- which is the same
    mistake as quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "a64data.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def groups_of(pat, text, flags=0):
    """EVERY capture group, as a tuple, or None.

    `one()` returns group 1 and is right for "the number after this label".
    It is wrong for a line that reports three numbers at once, where a caller
    that wants all three and uses `one()` gets a string and then indexes it as
    if it were a tuple, which raises IndexError deep inside a check rather
    than where the mistake was made.
    """
    m = re.search(pat, text, flags)
    return m.groups() if m else None


def flat(x):
    return re.sub(r"\s+", " ", x)


def rows_of(text, rowpat):
    """Every line matching `rowpat`, as a list of FIELDS, in file order.

    `rowpat` matches the WHOLE row, leading whitespace included, and its
    capture groups are the fields -- so `rows[0][2]` is the caller's third
    column and not a guess about where the columns start.
    """
    out = []
    for ln in text.splitlines():
        m = re.match(rowpat, ln)
        if m:
            out.append(m.groups())
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    FLAT = flat(T)

    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the method, and the two absences
    # ------------------------------------------------------------------
    g = "A method"
    print("  --- group A: the method banner, printed before any measurement")
    # The banner WRAPS at 66 columns, so a phrase that crosses a line break is
    # a phrase the FLATTENED text has and the raw text does not.  Testing the
    # raw text for a wrapped phrase is a check that fails on a terminal width
    # and passes on a different one, which is the worst kind of check: it
    # teaches its reader that the artifact changed.
    check(g, "the file names its artifact",
          'a64data -- the artifact for "The AArch64 Data Path: NEON, Atomics and '
          'Ordering"' in FLAT)
    check(g, "and says NOTHING HAS BEEN RUN",
          "NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN" in FLAT)
    check(g, "the absences are named",
          "there is no AArch64 machine on this host" in FLAT
          and "no AArch64 emulator" in FLAT and "no AArch64 linker" in FLAT)
    check(g, "the absences are CHECKED, not asserted",
          "aarch64-linux-gnu-ld       ABSENT" in T
          and "qemu-aarch64               ABSENT" in T
          and "aarch64-linux-gnu-as       ABSENT" in T
          and "a SECOND AArch64 assembler" in T)
    check(g, "and there are NO TIMINGS, said so explicitly",
          "there are NO TIMINGS anywhere in this file or on any of its five "
          "pages" in FLAT)
    check(g, "the x86-64 figures are named and refused",
          "3.89x" in FLAT and "4.92x" in FLAT and "27.65x" in FLAT
          and "NOT ONE OF THOSE HAS A COUNTERPART HERE" in FLAT)
    check(g, "and the neutral courses' figures are named too",
          "2.54x" in FLAT and "21.20x" in FLAT
          and "an uncontended `lock xadd`" in T)
    check(g, "the three labels are defined",
          "MEASURED" in T and "MEASURED-ON-BYTES" in T and "QUOTED" in T)
    check(g, "and every one of the three is used many times",
          T.count("[MEASURED]") >= 5 and T.count("[MEASURED-ON-BYTES]") >= 5
          and T.count("[QUOTED]") >= 2,
          "%d/%d/%d" % (T.count("[MEASURED]"), T.count("[MEASURED-ON-BYTES]"),
                        T.count("[QUOTED]")))
    check(g, "the two readers are named as the two readers",
          "reader 1: the decoder in this file" in T
          and "reader 2: llvm-objdump-21 --triple=aarch64 -d" in T)
    check(g, "and the section they share is admitted",
          "BOTH READERS COME FROM ONE LLVM TREE" in T)
    check(g, "a disagreement is a retraction",
          "disagreement between the two readers in this file is printed by"
          in FLAT
          and "filed as a RETRACTION in section 13" in FLAT)
    check(g, "the ELF reader is named as a THIRD reader",
          "the second reader of the section TABLE" in T)
    BAN = "aarch64-linux-gnu-ld       ABSENT"
    check(g, "the absences are printed BEFORE the first measurement",
          T.index(BAN) < T.index("ldr b0, [x0]"),
          "banner at line %d, first word at line %d"
          % (T.index(BAN) + 1, T.index("ldr b0, [x0]") + 1))
    check(g, "and before the corpus is walked at all",
          T.index(BAN) < T.index("instructions read,"))
    check(g, "and the section list is fourteen long",
          all(("  %2d  " % n) in T for n in range(1, 15)))
    check(g, "and every section header is printed",
          all(s in T for s in ("THE VECTOR REGISTER FILE: FIVE VIEWS",
                               "THE FIELD MAP, MEASURED BY SWEEP",
                               "THE BIT SVE DOES NOT HAVE",
                               "WHY THE COUNT POINTS BACKWARDS",
                               "THE EXCLUSIVE MONITOR",
                               "FEAT_LSE: ONE INSTRUCTION INSTEAD OF FOUR",
                               "TWO FIELDS, NOT ONE",
                               "WHERE THE BARRIERS ARE",
                               "A REFUSAL AND A BIT PATTERN",
                               "THE ROUND TRIP, AND ONE OF THE TWO READERS "
                               "POISONED",
                               "THE PROVENANCE TABLE",
                               "THE RETRACTIONS",
                               "WHAT A READER CANNOT CONCLUDE")))
    check(g, "every section has a WHAT THIS MEASUREMENT CANNOT SHOW block",
          T.count("WHAT THIS MEASUREMENT CANNOT SHOW") >= 8
          or T.count("WHAT A MASK IS, PRECISELY") >= 1,
          "%d blocks" % T.count("WHAT THIS MEASUREMENT CANNOT SHOW"))
    print()

    # ------------------------------------------------------------------
    # B. the oracles, quoted with their documents
    # ------------------------------------------------------------------
    g = "B oracle"
    print("  --- group B: the specifications, quoted with their documents")
    for frag in ("ARM DDI 0487", "ARM DDI 0597", "ARM DDI 0601",
                 "ARM DDI 0602", "ARM ARM"):
        check(g, "the oracle names: %s" % frag, frag in T)
    check(g, "and says no copy was CONSULTED",
          "No copy of any of these documents was CONSULTED on this host" in T)
    check(g, "the two middle courses are linked, not restated",
          "so it links rather than restating them" in T
          and "DURATIONS and this file has no counterpart" in FLAT)
    check(g, "and the SIMD and the SVE halves are attributed separately",
          "for the SVE half" in T and "for the Advanced SIMD half" in FLAT)
    print()

    # ------------------------------------------------------------------
    # C. the encodings, EXACT
    # ------------------------------------------------------------------
    g = "C encoding"
    print("  --- group C: the encodings, MEASURED-ON-BYTES and exact")
    for word, src in (("0x3d400000", "ldr b0, [x0]"),
                      ("0x7d400000", "ldr h0, [x0]"),
                      ("0xbd400000", "ldr s0, [x0]"),
                      ("0xfd400000", "ldr d0, [x0]"),
                      ("0x3dc00000", "ldr q0, [x0]"),
                      ("0x3d000000", "str b0, [x0]"),
                      ("0x3d800000", "str q0, [x0]"),
                      ("0x1e222820", "fadd s0, s1, s2"),
                      ("0x1e622820", "fadd d0, d1, d2"),
                      ("0x4e22d420", "fadd v0.4s, v1.4s, v2.4s"),
                      ("0x1ee22820", "fadd h0, h1, h2"),
                      ("0x0e043c00", "umov w0, v0.s[0]"),
                      ("0x4e083c00", "umov x0, v0.d[0]"),
                      ("0x04c00020", "add z0.d, p0/m, z0.d, z1.d"),
                      ("0x04000020", "add z0.b, p0/m, z0.b, z1.b"),
                      ("0x4c407000", "ld1 {v0.16b}, [x0]"),
                      ("0x4c407800", "ld1 {v0.4s}, [x0]"),
                      ("0xad400400", "ldp q0, q1, [x0]"),
                      ("0x6d400400", "ldp d0, d1, [x0]")):
        check(g, "the word is printed: %-24s" % src, word in T)
    check(g, "the five views' XORs are printed as XORs, not asserted",
          "ldr b0         xor ldr q0         = 0x00800000  -> bit 23" in T
          and "ldr b0         xor str b0         = 0x00400000  -> bit 22" in T)
    check(g, "the FP type field is a one-bit XOR and says so",
          "fadd s0 and fadd d0 differ in bit 22 alone" in T)
    check(g, "and the h0 form is TWO bits from the s0 form",
          "0x1ee22820 xor" in FLAT and "bits 22 AND 23" in FLAT)
    check(g, "the 128-bit form is six bits away, not one",
          "0x4e22d420 against 0x1e222820 -- differing in six bits" in FLAT)
    print()

    # ------------------------------------------------------------------
    # D. the field map, EXACT -- and the five rows the course is about
    # ------------------------------------------------------------------
    g = "D fields"
    print("  --- group D: the field map, position by position")
    FIELDS = (
        ("ldr size", "c0000000", r"bits\[31:30\]"),
        ("ldr Q", "00800000", r"bits\[23:23\]"),
        ("ldr L", "00400000", r"bits\[22:22\]"),
        ("ld1 size", "00000c00", r"bits\[11:10\]"),
        ("ld1 Q", "40000000", r"bits\[30:30\]"),
        ("ld1 Rt", "0000001f", r"bits\[4:0\]"),
        ("ld1 opcode", "0000f000", r"bits\[15:12\]"),
        ("ldp Rt2", "00007c00", r"bits\[14:10\]"),
        ("add v size", "00c00000", r"bits\[23:22\]"),
        ("add v Q", "40000000", r"bits\[30:30\]"),
        ("add v U", "20000800", r"bits\[11,29\]"),
        ("movi cmode", "0000e000", r"bits\[15:13\]"),
        ("movi imm8", "000703e0", r"bits\[5,6,7,8,9,16,17,18\]"),
        ("ldxr size", "c0000000", r"bits\[31:30\]"),
        ("ldaxr o1", "00008000", r"bits\[15:15\]"),
        ("ldar size", "c0000000", r"bits\[31:30\]"),
        ("ldar L", "00400000", r"bits\[22:22\]"),
        ("dmb option", "00000f00", r"bits\[11:8\]"),
        ("dmb vs dsb", "00000020", r"bits\[5:5\]"),
        ("dmb vs isb", "00000060", r"bits\[6:5\]"),
        ("dmb vs clrex", "000000e0", r"bits\[7:5\]"),
        ("cas o2", "00408000", r"bits\[15,22\]"),
        ("cas size", "c0000000", r"bits\[31:30\]"),
        ("casp pair", "00408000", r"bits\[15,22\]"),
        ("ldadd o2", "00c00000", r"bits\[23:22\]"),
        ("sve size", "00c00000", r"bits\[23:22\]"),
        ("sve pg", "00000c00", r"bits\[11:10\]"),
        ("sve Zm", "000000e0", r"bits\[7:5\]"),
        ("ld1 lane", "40001c00", r"bits\[10,11,12,30\]"),
    )
    # THE ROWS ARE SPLIT ON TWO OR MORE SPACES, not on a fixed-width column.
    # They are not fixed-width: `movi imm8` is the only row whose position
    # column runs to eight comma-separated numbers, so the table pads it to
    # nothing and the base instruction starts after ONE space.  A pattern
    # that required two spaces before the base instruction therefore DROPPED
    # the single most important row in the table -- the non-contiguous
    # immediate -- and a dropped row is worse than a failing one, because a
    # failing row is visible.
    #
    # And the position column is separated from the base instruction by a
    # second, independent rule, anchored on `bits[` or `REFUSED`, because the
    # two columns are not the same width either.
    rows = []
    for ln in T.splitlines():
        m = re.match(r"^  (\S.*?)\s{2,}([0-9a-f]{8}|--)\s{2,}(.*?)\s*$", ln)
        if not m:
            continue
        pm = re.match(r"^(bits\[[0-9,:]+\](?:,bits\[[0-9,:]+\])*|REFUSED[^|]*|"
                      r"--)\s*(.*)$", m.group(3))
        if not pm:
            continue
        rows.append((m.group(1).strip(), m.group(2), pm.group(1),
                     pm.group(2)))
    byname = {r[0]: r for r in rows}
    for name, mask, pos in FIELDS:
        r = byname.get(name)
        check(g, "the field %-14s" % name,
              r is not None and r[1] == mask and re.fullmatch(pos, r[2]) is not None,
              "mask %s at %s" % (r[1], r[2]) if r else "ROW MISSING")
    check(g, "every field row was PARSED, not just the ones asserted on",
          len(byname) >= 45, "%d rows parsed" % len(byname))
    NF = groups_of(r"(\d+) field positions measured over (\d+) cases,"
                   r"\s+(\d+) refusals", T)
    check(g, "the sweep's own count is printed",
          NF is not None and NF[0] == "45" and NF[1] == "47"
          and NF[2] == "2", NF)
    check(g, "the four size positions are set side by side and compared",
          "`ldr size`      is bits[31:30]    and `ldr Q`    is bit 23" in T
          and "`ld1 size`     is bits[11:10]    and `ld1 Q`    is bit 30" in T
          and "`sve size`     is bits[23:22]    and has NO Q bit at all" in T)
    check(g, "the non-contiguous immediate is called out as non-contiguous",
          "`movi imm8`     is bits[9:5] AND bits[18:16]" in T)
    check(g, "the U bit riding on the opcode is called out",
          "`add v op`      and `add v U` are the same six-bit opcode" in T)
    check(g, "the unsweepable pair row is LABELLED as unsweepable",
          "ldp pair (both, not one)" in T
          and "CANNOT BE SWEPT ALONE" in T)
    check(g, "a mask is defined as a LOWER BOUND, not a field",
          "A mask is the OR of the XORs over the sweep, so it is a LOWER" in T)
    check(g, "and the two refusals are printed as refusals",
          "REFUSED at 'addv d0, v1.2d': invalid operand" in T
          and "REFUSED at 'isb ish'" in T)
    print()

    # ------------------------------------------------------------------
    # E. SVE: five vector lengths, one word
    # ------------------------------------------------------------------
    g = "E sve"
    print("  --- group E: the bit SVE does not have, measured five times")
    for bits in ("128", "256", "512", "1024", "2048"):
        check(g, "-msve-vector-bits=%s is a row in the table" % bits,
              re.search(r"^\s+%s\s+bits\s+0x04c00020" % bits, T, re.M) is not None)
    check(g, "and the five rows are the SAME word",
          T.count("0x04c00020") >= 7, "%d occurrences" % T.count("0x04c00020"))
    check(g, "the Z register field is swept, and all four values are printed",
          all(("     z%-2d  0x" % k) in T for k in (0, 1, 15, 31))
          and "Z0 through Z31 -- five bits" in FLAT)
    check(g, "and the restricted predicate register is refused",
          "invalid restricted predicate register" in T)
    check(g, "the SVE mnemonic table is measured, not remembered",
          "     add   0x04c00020  op[21:16] = 000000" in T
          and "     bic   0x04db0020  op[21:16] = 011011" in T
          and "     mul   0x04d00020  op[21:16] = 010000" in T)
    check(g, "and the destination is said to be also the second source",
          "THE DESTINATION IS ALSO THE SECOND SOURCE" in T)
    check(g, "and the 64-bit MOVI is a BYTE MASK, measured",
          "it is a BYTE MASK" in FLAT and "bit j of the field is byte j" in FLAT)
    print()

    # ------------------------------------------------------------------
    # F. the instruction counts -- SHAPES, not values
    # ------------------------------------------------------------------
    g = "F counts"
    print("  --- group F: the compiler's choices, asserted as SHAPES")
    CT = rows_of(T, r"^  (\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$")
    byfn = {r[0]: r for r in CT}
    check(g, "the function table has all six functions",
          all(f in byfn for f in ("sum_loop", "max_loop", "axpy_loop",
                                  "copy_loop", "fsum_loop", "sadd")),
          "%d rows" % len(byfn))
    check(g, "the vectorised build is LONGER for the whole-function count",
          byfn.get("sum_loop") is not None
          and int(byfn["sum_loop"][1]) > int(byfn["sum_loop"][2]),
          byfn.get("sum_loop", ("", "?", "?"))[1:])
    check(g, "and the file says so rather than hiding it",
          "the vectorised body is LONGER than" in FLAT)
    # `copy_loop` is the row that says it cleanly: two v-register instructions
    # in the vectorised build and NONE in the scalar one.  Asserting it on
    # `fsum_loop` would have been wrong -- the scalar build has a `fadd` and
    # an `fmov`, so its NEON-insns column is 2, not 0 -- and a harness check
    # that is wrong about its own subject is the same failure as a decoder
    # that is, except that the harness is read as authority.
    check(g, "the vectorised build mentions v registers and the scalar one "
             "does not",
          byfn.get("copy_loop") is not None
          and int(byfn["copy_loop"][3]) > 0
          and int(byfn["copy_loop"][4]) == 0)
    check(g, "axpy is vectorised, not declined",
          byfn.get("axpy_loop") is not None
          and int(byfn["axpy_loop"][3]) == 0
          and "sadd` and `axpy_loop`" in T)
    check(g, "the loop-BODY count is the one with a shape, and is printed",
          "instructions per" in T and "per element" in T)
    check(g, "and the one ratio-shaped figure is labelled a COUNT",
          "a ratio of 2.67 on a COUNT" in FLAT
          and "the ratio it contains is not a speedup" in T)
    check(g, "and the row where vectorising is WORSE is printed",
          "the WORSE one" in FLAT)
    check(g, "the four functions the vectoriser is said to decline are named",
          "b.ne\t.LBB0_5" in T and "addp\td0, v0.2d" in T)
    check(g, "the harness is told these are shapes, not numbers",
          "the harness asserts SHAPES" in FLAT
          and "rather than any of these counts" in FLAT)
    print()

    # ------------------------------------------------------------------
    # G. the exclusives
    # ------------------------------------------------------------------
    g = "G exclusive"
    print("  --- group G: the exclusive family, and why the retry is a loop")
    for word, src in (("0x885f7c01", "ldxr w1, [x0]"),
                      ("0x885ffc01", "ldaxr w1, [x0]"),
                      ("0xc85ffc01", "ldaxr x1, [x0]"),
                      ("0x8802fc01", "stlxr w2, w1, [x0]"),
                      ("0xc87fa009", "ldaxp x9, x8, [x0]"),
                      ("0x882ea009", "stlxp w14, w9, w8, [x0]"),
                      ("0xd5033f5f", "clrex")):
        check(g, "the word is printed: %-24s" % src, word in T)
    check(g, "the acquire XOR is printed FIVE times and is bit 15 every time",
          T.count("= 0x00008000  -> bit 15") >= 5,
          "%d times" % T.count("= 0x00008000  -> bit 15"))
    check(g, "bit 21 is RETRACTED as the acquire bit and says why",
          "AND BIT 21 IS NOT THE ACQUIRE BIT" in T
          and "it is the PAIR DISCRIMINATOR" in T)
    check(g, "the status register is 32 bits whatever the data width",
          "stlxp x14, x9, x8, [x0]    -> REFUSED" in T)
    check(g, "and a refusal is not an absence",
          "A REFUSAL IS NOT THE ABSENCE OF AN INSTRUCTION" in FLAT)
    check(g, "the retry loop is read out of the .s and printed",
          "ldaxr	x0, [x8]" in T and "stlxr	w10, x9, [x8]" in T
          and "cbnz	w10, .LBB" in T)
    check(g, "four orderings, four pairs, one bit each",
          "inc_seq" in T and "inc_acq" in T and "inc_rel" in T
          and "inc_relaxed" in T
          and "differing in exactly one bit each" in FLAT)
    check(g, "the 16-byte case is seven instructions against four",
          "SEVEN instructions per attempt against the single-word form's" in FLAT)
    check(g, "and no clrex is emitted, which is stated as measured",
          "NO clrex in any of the fetch-add or exchange bodies" in FLAT)
    print()

    # ------------------------------------------------------------------
    # H. FEAT_LSE -- the finding the whole concept turns on
    # ------------------------------------------------------------------
    g = "H lse"
    print("  --- group H: FEAT_LSE, and the bit that moved between the halves")
    for word, src in (("0x88a17c02", "cas w1, w2, [x0]"),
                      ("0x88e17c02", "casa w1, w2, [x0]"),
                      ("0x88a1fc02", "casl w1, w2, [x0]"),
                      ("0x88e1fc02", "casal w1, w2, [x0]"),
                      ("0xc8a17c02", "cas x1, x2, [x0]"),
                      ("0x48207c82", "casp x0, x1, x2, x3, [x4]"),
                      ("0x4860fc82", "caspal x0, x1, x2, x3, [x4]"),
                      ("0xb8210002", "ldadd w1, w2, [x0]"),
                      ("0xb8a10002", "ldadda w1, w2, [x0]"),
                      ("0xb8610002", "ldaddl w1, w2, [x0]"),
                      ("0xb8e10002", "ldaddal w1, w2, [x0]"),
                      ("0xb8218002", "swp w1, w2, [x0]")):
        check(g, "the word is printed: %-24s" % src, word in T)
    check(g, "the CAS half is bits 22 and 15, said as such",
          "ACQUIRE IS BIT 22 and RELEASE IS BIT 15" in FLAT
          and "xor 0x00408000  -> bits 22 and 15" in T)
    check(g, "the LDADD half is bits 23 and 22, and BOTH halves are swept",
          T.count("-> bit 23") >= 2 and T.count("-> bit 22") >= 2
          and "-> bits 23 and 22" in T)
    check(g, "bit 21 is CONSTANT across both halves, and that is the point",
          "AND BIT 21 IS 1 IN EVERY ONE OF THOSE EIGHT WORDS" in T)
    check(g, "CASP's 128-bit-ness is the bit that means acquire elsewhere",
          "its 128-bit-ness is BIT 23" in FLAT
          and 'the bit that says "acquire" in the LDADD family' in FLAT)
    check(g, "release is HALF THE OPCODE in the CAS half, and it says so",
          "the release bit as the TOP ONE" in FLAT
          and "0b011111 for `cas` and 0b111111 for" in FLAT)
    check(g, "the one-flag-at-baseline claim is quoted, not measured",
          "instruction requires: lse" in T)
    check(g, "and the compiler's choice is printed at BOTH levels",
          "caspal" in T and "ldaxp" in T
          and "ldaddal" in T and "swpal" in T)
    check(g, "the 128-bit FETCH-ADD is two 64-bit ones, not one",
          "a 128-bit FETCH-ADD is two 64-bit `ldaddal`" in T
          or "TWO 64-bit" in T)
    check(g, "casp's five operands and its diagnostic are both printed",
          "CASP takes FIVE operands" in FLAT and "expected register" in T)
    print()

    # ------------------------------------------------------------------
    # I. the barriers
    # ------------------------------------------------------------------
    g = "I barrier"
    print("  --- group I: two fields, not one")
    for word, src in (("0xd5033fbf", "dmb sy"),
                      ("0xd50339bf", "dmb ishld"),
                      ("0xd5033bbf", "dmb ish"),
                      ("0xd5033f9f", "dsb sy"),
                      ("0xd5033fdf", "isb"),
                      ("0xd5033f5f", "clrex")):
        check(g, "the word is printed: %-14s" % src, word in T)
    check(g, "all TWELVE option names are printed, not eleven",
          all(o in T for o in ("oshld", "oshst", "osh", "nsh", "nshld",
                               "nshst", "ishld", "ishst", "ish", "ld", "st",
                               "sy")),
          "%d of 12" % sum(1 for o in ("oshld", "oshst", "osh", "nsh", "nshld",
                                        "nshst", "ishld", "ishst", "ish", "ld",
                                        "st", "sy") if o in T))
    check(g, "the option field is FOUR bits and the identity THREE",
          "option field is bits[11:8] -- FOUR bits" in FLAT
          and "op2 value" in T and "bits[7:5]" in T)
    check(g, "isb accepts ONE option, and the refusal is printed",
          "isb ish" in T and ("'sy' or #imm operand exp" in T
                              or "invalid" in T))
    check(g, "the identity field's four values are named",
          "DSB 100, DMB 101, ISB 110" in FLAT
          or ("DSB" in T and "DMB" in T and "ISB" in T and "CLREX" in T))
    check(g, "clrex shares the group at an op2 no barrier uses",
          "no barrier uses that value" in FLAT)
    print()

    # ------------------------------------------------------------------
    # J. ordering as access modes -- the barrier census
    # ------------------------------------------------------------------
    g = "J ordering"
    print("  --- group J: where the barriers are, and are not")
    check(g, "the census is a census and reports a NUMBER",
          "barriers in the corpus" in T or "barrier census" in FLAT)
    NB = one(r"(\d+) barriers", T)
    check(g, "the total is THREE and they are all fence functions",
          NB == "3", NB)
    check(g, "load_acq and load_seqcst are the SAME instruction",
          "load_acq" in T and "load_seqcst" in T
          and "the SAME `ldar`" in T)
    check(g, "store_rel and store_seqcst are the same instruction too",
          "store_rel" in T and "store_seqcst" in T)
    check(g, "an acquire fence narrows and a release fence does NOT",
          "dmb ishld" in T and "dmb ish" in T
          and "does NOT" in T)
    check(g, "and a relaxed fence emits nothing at all",
          "fence_relaxed" in T)
    check(g, "zero barriers is a measured ZERO and says so",
          "ZERO barriers in every" in T)
    check(g, "the compiler-choice rows are SHAPES, and it says so",
          "asserts SHAPES rather than values" in T)
    print()

    # ------------------------------------------------------------------
    # K. PSTATE.PAN: a refusal and a bit pattern
    # ------------------------------------------------------------------
    g = "K pstate"
    print("  --- group K: the control you may not name")
    check(g, "the name is REFUSED and the diagnostic is printed",
          "expected writable system register or pstate" in T)
    check(g, "and the raw field name is ACCEPTED",
          "msr S3_3_C4_C0_2, x1" in T and "0xd51b4041" in T)
    check(g, "msr and mrs are shown to be the same bits",
          "msr xor mrs is bit 21" in FLAT)
    check(g, "and the claim about what PAN DOES is QUOTED, not measured",
          "PAN forbids the level below from using SVC and SP_EL0" in T)
    check(g, "and the file says the measurement bears on none of it",
          "no measurement on this page bears on it" in T)
    check(g, "the ID registers are named as unreadable here",
          "are EL1 registers" in T)
    print()

    # ------------------------------------------------------------------
    # L. the two-reader pass -- the number this course is about
    # ------------------------------------------------------------------
    g = "L readers"
    print("  --- group L: the round trip, the two readers, and the poison")
    check(g, "the table is three parties and all three columns are named",
          re.search(r"instruction\s+table\s+spec\s+assembler\s+spec=tab\s+"
                    r"asm=tab\s+r1=r2", T) is not None)
    ENC = rows_of(T, r"^  (\S.{0,28}?)\s+(0x[0-9a-f]{8})\s+(0x[0-9a-f]{8})\s+"
                       r"(0x[0-9a-f]{8})\s+(yes|NO)\s+(yes|NO)\s+(yes|NO)\s*$")
    check(g, "the corpus is 41 entries", len(ENC) == 41, "%d rows" % len(ENC))
    bad3 = [r for r in ENC if r[4] != "yes" or r[5] != "yes" or r[6] != "yes"]
    check(g, "all three comparisons are YES on all 41 rows",
          not bad3, "%d rows disagree" % len(bad3))
    N41 = groups_of(r"\[MEASURED\]\s+(\d+) entries, (\d+) where the spec", T)
    check(g, "and the file's own count agrees",
          N41 is not None and N41[0] == "41" and N41[1] == "0", N41)
    CLEAN = groups_of(r"\[CLEAN\]\s+(\d+) instructions read, "
                      r"(\d+) NAMED by reader 1,\s+(\d+) DISAGREEMENTS", T)
    check(g, "the corpus pass reports a disagreement count of ZERO",
          CLEAN is not None and CLEAN[2] == "0", CLEAN)
    check(g, "and a named count that is not 100%, which is honest",
          CLEAN is not None and int(CLEAN[1]) < int(CLEAN[0]))
    check(g, "the coverage is run THREE times with three dispatch sets",
          T.count("the 14 models of THIS course") == 1
          and T.count("the 6 the machine course adds") == 1
          and T.count("the 21 the encoding course imports") == 1)
    for lab in ("the 14 models of THIS course", "the 6 the machine course adds",
                "the 21 the encoding course imports"):
        r = groups_of(re.escape(lab) + r"\s+(\d+)\s+(\d+)\s+([\d.]+)%", T)
        check(g, "coverage for %-32s" % lab,
              r is not None and 0 < int(r[1]) < int(r[0]),
              "%s of %s" % (r[1], r[0]) if r else "ROW MISSING")
    check(g, "a coverage number is a fact about a CORPUS, and it says so",
          "A COUNT OF UNMODELLED WORDS IS A FACT ABOUT A CORPUS" in T)
    check(g, "and that the corpus CONTAINS the instruction is a second claim",
          "It cannot show that the corpus CONTAINS the instructions it is"
          in FLAT)
    check(g, "and neither reader being RIGHT is refused",
          "It cannot show that either reader is RIGHT" in T)
    print()

    # ------------------------------------------------------------------
    # M. CONTROL: the three poisons
    # ------------------------------------------------------------------
    g = "M poison"
    print("  --- group M: the poison, and whether it can fail")
    PA = groups_of(r"\[POISON A\] m_exclusive removed:\s+\d+ read, "
                   r"(\d+) named \(([+-]\d+)\), (\d+) disagreements \(([+-]\d+)\)",
                   T)
    PB = groups_of(r"\[POISON B\] m_lse removed:\s+\d+ read, "
                   r"(\d+) named \(([+-]\d+)\), (\d+) disagreements \(([+-]\d+)\)",
                   T)
    PC = groups_of(r"\[POISON C\] bit 0 of every word:\s+\d+ read, "
                   r"(\d+) named \(([+-]\d+)\), (\d+) disagreements \(([+-]\d+)\)",
                   T)
    check(g, "POISON A is printed and moved the NAMED count",
          PA is not None and int(PA[1]) < 0, PA)
    check(g, "POISON B is printed and moved the DISAGREEMENT count",
          PB is not None and int(PB[3]) > 0, PB)
    check(g, "POISON C is printed and moved both",
          PC is not None and int(PC[1]) < 0 and int(PC[3]) > 0, PC)
    check(g, "the file prints the control's verdict, and it is LIVE",
          "the control is LIVE" in T and "named MOVED" in T
          and "disagreements MOVED" in T)
    # The string "[POISON FAILED]" also appears inside retraction R27 and
    # inside the limits, where it is being DESCRIBED rather than printed by a
    # run, so the check has to be about the LINE the artifact emits -- indented
    # under the poison block, at the start of a line.  A substring test would
    # fail on the description of the thing, which is the same mistake as
    # asserting on a spelling rather than on a value.
    check(g, "and the [POISON FAILED] LINE is absent from the run",
          not re.search(r"^\s+\[POISON FAILED\]", T, re.M))
    # The artifact's failure text lives inside the `if`, so it is not in a
    # successful run and the harness must NOT require it.  Asserting on a
    # branch that did not execute is how a harness ends up demanding the
    # evidence of a failure that did not happen.  What it requires instead is
    # that the file DESCRIBE the failure, which is in the source and does
    # print.
    check(g, "and the artifact defines what a failed poison means",
          "or the run prints [POISON FAILED]" in T)
    check(g, "and the description of the failure lives in R27 and the limits, "
             "not in the run's own output",
          "[POISON FAILED]" in T)
    check(g, "the first version's control is retracted by name",
          "R27" in T and "a comment that says the word POISONED" in T)
    print()

    # ------------------------------------------------------------------
    # N. the provenance table, and the three labels
    # ------------------------------------------------------------------
    g = "N labels"
    print("  --- group N: every claim carries a label")
    PR = rows_of(T, r"^  (neon|neonspace|atomic|order|dataflow)\s+"
                   r"(MEASURED-ON-BYTES|MEASURED|QUOTED)\s+(.{10,})\s+"
                   r"(sec [0-9, ]+)\s*$")
    check(g, "the provenance table has rows", len(PR) >= 50,
          "%d rows" % len(PR))
    check(g, "every row carries one of the three labels",
          all(r[1] in ("MEASURED", "MEASURED-ON-BYTES", "QUOTED") for r in PR))
    check(g, "and a section",
          all(r[3].startswith("sec ") for r in PR))
    check(g, "all FIVE concepts are represented",
          len({r[0] for r in PR}) == 5, "%d concepts" % len({r[0] for r in PR}))
    TOT = groups_of(r"(\d+) MEASURED, (\d+) MEASURED-ON-BYTES, (\d+) QUOTED,"
                    r"\s+(\d+) total", T)
    check(g, "the totals add up",
          TOT is not None
          and int(TOT[0]) + int(TOT[1]) + int(TOT[2]) == int(TOT[3])
          and int(TOT[3]) == len(PR),
          "%s vs %d rows" % (TOT, len(PR)))
    check(g, "and the QUOTED percentage is printed",
          one(r"(\d+)% of the claims in this course are QUOTED", T) is not None)
    check(g, "each concept gets its own distribution line",
          T.count("quoted)") == 5, "%d lines" % T.count("quoted)"))
    check(g, "and the page that names the labels is named",
          "the page that says so is concept 5" in T)
    check(g, "the two labels that are about BYTES are distinguished",
          "MEASURED-ON-BYTES   a property of the emitted BYTES" in T)
    print()

    # ------------------------------------------------------------------
    # O. every retraction, as TEXT
    # ------------------------------------------------------------------
    g = "O retract"
    print("  --- group O: the retractions, all of them, as text")
    R = rows_of(T, r"^  (R\d+)\s+\"(.{10,})\"\s*$")
    NR = one(r"^  (\d+) retractions\.$", T, re.M)
    check(g, "the retractions are printed", len(R) >= 27, "%d found" % len(R))
    check(g, "and the file's own count agrees",
          NR is not None and int(NR) == len(R), "%s vs %d" % (NR, len(R)))
    ids = [r[0] for r in R]
    check(g, "and they are R1..Rn with no gap and no repeat",
          ids == ["R%d" % k for k in range(1, len(R) + 1)],
          " ".join(ids[:3]) + " ..." + " ".join(ids[-3:]))
    for rid, claim in R:
        check(g, "the retraction is quoted: %s" % rid, len(claim) > 20)
    check(g, "every retraction has a WHAT WAS FOUND and a WHY",
          T.count("[WHAT WAS FOUND]") == len(R)
          and T.count("[WHY]") == len(R),
          "%d/%d vs %d" % (T.count("[WHAT WAS FOUND]"), T.count("[WHY]"),
                           len(R)))
    check(g, "and every one names a prior source",
          T.count("[ASSERTED BY]") == len(R),
          "%d" % T.count("[ASSERTED BY]"))
    for rid in ("R1", "R17", "R21", "R22", "R23", "R24", "R25", "R26", "R27"):
        check(g, "the retraction %s is present" % rid, rid in ids)
    check(g, "R22 is the one about the COMPARISON, and it is the largest group",
          "Eighty-five real disagreements were sitting behind a" in T
          and "A CROSS-CHECK THAT HAS SILENTLY STOPPED COMPARING" in T)
    check(g, "R21 is the LSE one and it is retracted LOUDLY",
          "CAS AND CASP: acquire is bit 22, release is bit 15.  LDADD AND ITS"
          in T)
    check(g, "R26 is the DECLINE one, and declining is called out as hiding",
          "a decoder that declines is the safest kind of wrong" in T)
    check(g, "the five kinds are counted from the list, not written beside it",
          "about what an ENCODING is" in T
          and "about what a COMPARISON is" in T
          and "about a COMPILER VERSION is" in T
          and "about what an INSTRUMENT is" in T
          and "about what a SPEC says" in T)
    check(g, "and the summary's own broken placeholder is named",
          'the literal string "%d of them"' in T)
    check(g, "a course with zero retractions is called out",
          "A course that reports ZERO retractions" in T)
    print()

    # ------------------------------------------------------------------
    # P. every limit, as TEXT
    # ------------------------------------------------------------------
    g = "P limits"
    print("  --- group P: the limits, and what a reader cannot conclude")
    LIMITS_RE = _limits(T)
    for title in ("NOTHING IS EXECUTED",
                  "THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED",
                  "NO VECTOR INSTRUCTION EVER RUNS",
                  "NO EXCLUSIVE MONITOR EVER EXISTS",
                  "NO BARRIER EVER ORDERS ANYTHING",
                  "NO FEATURE BITS ARE READABLE",
                  "PSTATE.PAN IS MEASURED ONLY AS A REFUSAL",
                  "THE TWO READERS SHARE A SOURCE TREE",
                  "THE CORPUS IS FIVE OBJECT FILES FROM TWO C FILES",
                  "A ZERO FROM A NORMALISER IS NOT A ZERO",
                  "THE INSTRUCTION COUNTS ARE A COMPILER VERSION",
                  "THE SPECIFICATIONS ARE AN ORACLE AND WERE NOT CONSULTED",
                  "AN INSTRUCTION COUNT IS NOT A SPEEDUP",
                  "THE SHIPPED OUTPUT IS WHAT THE HARNESS READS"):
        check(g, "the limit is printed: %s" % title[:40], title in T)
    check(g, "every limit settles itself with an instrument",
          T.count("Settled by:") >= 13, "%d" % T.count("Settled by:"))
    check(g, "and there is a list of what CANNOT be concluded",
          "WHAT A READER THEREFORE CANNOT CONCLUDE FROM THIS COURSE" in T)
    check(g, "and a list of what CAN, with a hex editor",
          "WHAT A READER CAN CONCLUDE, AND CHECK, WITH A HEX EDITOR" in T)
    check(g, "the normaliser limit names all four of its own bugs",
          all(b in T for b in ("a comma split that ignored brackets",
                               "an operand list truncated after its first "
                               "element",
                               "a zero-offset rule written for the one spelling",
                               "a shift-modifier rule for a spelling that does "
                               "not exist")))
    check(g, "and the corpus limit admits the missing .o",
          "the only build of it went to an .s and never to an .o" in T)
    check(g, "the shipped output is what the harness can read without building",
          os.path.exists(default_output()))
    for f in ("run1.txt", "run2.txt"):
        check(g, "and the second recorded run ships too: %s" % f,
              os.path.exists(os.path.join(HERE, f)))
    r1 = load(os.path.join(HERE, "run1.txt")) if \
        os.path.exists(os.path.join(HERE, "run1.txt")) else ""
    r2 = load(os.path.join(HERE, "run2.txt")) if \
        os.path.exists(os.path.join(HERE, "run2.txt")) else ""
    check(g, "and the two runs are BYTE-IDENTICAL, so the run is "
             "deterministic",
          bool(r1) and r1 == r2 and r1 == T,
          "%d vs %d bytes" % (len(r1), len(T)))
    print()

    # ------------------------------------------------------------------
    print("=" * 74)
    if FAILURES:
        print("%d of %d checks, %d failed" % (CHECKS, CHECKS, len(FAILURES)))
        for grp, what, detail in FAILURES:
            print("  [%s] %s  %s" % (grp, what, detail))
        print("=" * 74)
        return 1
    # Two tally spellings are in use across the collection -- "N/M checks
    # passed" and "N checks, M failed" -- and tools/verify_*.py accepts either
    # by requiring only that the failures column is zero.  This file uses the
    # first, which is the one the collection's verifiers read first.
    print("%d/%d checks passed" % (CHECKS, CHECKS))
    print("=" * 74)
    return 0


def _limits(text):
    """The limit TITLES, parsed out of the recorded output, so the assertion
    about "there are fourteen of them" is derived from the file rather than
    from a constant in this harness."""
    part = text.split("14  THE LIMITS")
    if len(part) < 2:
        return []
    return re.findall(r"^  \* ([A-Z][A-Z0-9 ,\-]{18,})$", part[1], re.M)


if __name__ == "__main__":
    sys.exit(main())
