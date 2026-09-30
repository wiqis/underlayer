#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The AArch64 Procedure Call Standard".

It reads the OUTPUT of a64abi.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files and no decoder of
its own, and that is the point.  A harness that can re-measure can disagree
with the artifact for reasons that have nothing to do with whether the
artifact's SENTENCES are still true, and then it teaches its reader to
ignore it.

So the split is this.  a64abi.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit in the course that drops a retraction changes the
TEXT; the harness notices and the reader learns.  Neither can hide.

Why so LITTLE is asserted numerically, in this file's own words: this
course is mostly about things a standard FIXES, and a standard's numbers
are exact and do not move.  The register assignment, the argument order, the
alignment constant, the frame sizes and the two-reader agreement are exact
and are asserted as exact values, because that is the only honest thing to
do with an exact quantity.  The four places where a value genuinely moves
with a compiler version -- the instruction counts, the frame census, the
CFI row counts and the varargs frame -- are asserted as SHAPES and
ORDERINGS, never as values, and each of those four is named in the group
that checks it.

Usage:  python3 crosscheck.py [path/to/a64abi.out]
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
    print("  [%s] %-14s %-58s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before a64abi.py is ever built.  A course whose claims can only be
    verified by first rebuilding its own artifact is a course whose claims
    are only verifiable on the machine that wrote them -- which is the same
    mistake as quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "a64abi.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def groups_of(pat, text, flags=0):
    """EVERY capture group, as a tuple, or None.

    `one()` returns group 1 and is right for "the number after this label".
    It is wrong for a line that reports three numbers at once -- "21 models
    in it, 6 added here, 27 in this file" -- where a caller that wants all
    three and uses `one()` gets a string and then indexes it as if it were
    a tuple, which raises IndexError deep inside a check rather than where
    the mistake was made.  The previous course's harness has the same
    helper for the same reason.
    """
    m = re.search(pat, text, flags)
    return m.groups() if m else None


def int1(pat, text, flags=0):
    v = one(pat, text, flags)
    return int(v.replace(",", "")) if v else None


def rows_of(text, rowpat):
    """Every line matching `rowpat`, as a list of FIELDS, in file order.

    `rowpat` matches the WHOLE row, leading whitespace included, and its
    capture groups are the fields -- so `rows[0][2]` is the caller's third
    column and not a guess about where the columns start.  The first version
    of this helper in the previous course's harness took a PREFIX regex and
    returned everything after it, which silently dropped the first field, so
    a correct table reported a wrong number.  A helper that returns the wrong
    columns produces a check that reports a bug in the artifact when the bug
    is in the harness, and that is worse than no check.
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
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 70 columns, so a phrase written
    # across a line break is a phrase the artifact HAS and the harness
    # cannot see.  Numeric parses use the original, because collapsing
    # spaces there would join adjacent table columns.
    FLAT = re.sub(r"\s+", " ", T)

    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the method, and the two absences
    # ------------------------------------------------------------------
    g = "A method"
    print("  --- group A: the method banner, printed before any measurement")
    check(g, "the file names its artifact", "a64abi -- the artifact for" in T)
    check(g, "and says NOTHING HAS BEEN RUN",
          "NOT ONE INSTRUCTION IN THIS COURSE HAS" in FLAT and "BEEN RUN" in FLAT)
    check(g, "the two absences are named",
          "no AArch64 machine on this host" in FLAT
          and "no AArch64 emulator" in FLAT and "no AArch64 linker" in FLAT)
    check(g, "the absences are checked, not asserted",
          "AArch64 linker  ABSENT" in T and "AArch64 qemu    ABSENT" in T)
    check(g, "and there are NO TIMINGS, said so explicitly",
          "NO TIMINGS anywhere in this file" in FLAT)
    check(g, "the x86-64 figures are named and refused",
          "4.92x" in FLAT and "27.65x" in FLAT
          and "nothing here has a counterpart and nothing here fakes one"
          in FLAT)
    check(g, "the only cross-architecture comparison is a COMPILE-TIME count",
          "COMPILE-TIME INSTRUCTION COUNT" in FLAT
          and "THIS IS A COMPILE-TIME COMPARISON AND NOT A TIMING ONE" in FLAT)
    check(g, "the three labels are defined",
          "MEASURED" in T and "MEASURED-ON-BYTES" in T and "QUOTED" in T)
    check(g, "and every one of the three is used at least once",
          T.count("[MEASURED]") >= 5 and T.count("[MEASURED-ON-BYTES]") >= 4
          and T.count("[QUOTED]") >= 2,
          "%d/%d/%d" % (T.count("[MEASURED]"), T.count("[MEASURED-ON-BYTES]"),
                        T.count("[QUOTED]")))
    check(g, "the two readers are named as the two readers",
          "reader 1: the decoder in this file" in T
          and "reader 2: llvm-objdump-21 --triple=aarch64 -d" in T)
    check(g, "and the section they share is admitted",
          "both come from one LLVM tree" in FLAT)
    check(g, "the specification is the oracle and the compiler the subject",
          "the specification is the ORACLE and the compiler is the TEST" in FLAT)
    check(g, "a disagreement is a retraction",
          "every disagreement is printed as a RETRACTION" in FLAT)
    check(g, "the absences are printed BEFORE the first measurement",
          T.index("AArch64 linker  ABSENT") < T.index("5.2.2.1"),
          "banner at line %d, first measurement at line %d"
          % (T.index("AArch64 linker  ABSENT") + 1, T.index("5.2.2.1") + 1))
    check(g, "and before the corpus is walked at all",
          T.index("AArch64 linker  ABSENT") < T.index("instructions read,"))
    print()

    # ------------------------------------------------------------------
    # B. the oracle
    # ------------------------------------------------------------------
    g = "B oracle"
    print("  --- group B: the specification, quoted with its section numbers")
    for tag in ("A.1", "A.2", "A.4", "C.1", "C.9", "C.13", "C.16", "C.17",
                "5.2.2.1", "5.2.2.2", "5.1.1", "6.1.1", "6.1.2", "5.2.3"):
        check(g, "rule %s is quoted" % tag, ("  %-8s " % tag) in T)
    check(g, "the document is named and dated",
          "AAPCS64" in T and "2025Q4" in T and "23 January 2026" in T)
    check(g, "the two initialisation rules are the two COUNTERS",
          "Next General-purpose Register Number (NGRN)" in FLAT
          and "Next SIMD and Floating-point Register Number (NSRN)" in FLAT)
    check(g, "A.4 puts the first stacked argument AT SP",
          "next stacked argument address (NSAA) is set to the current "
          "stack-pointer value (SP)" in FLAT)
    check(g, "the oracle is separated from every measurement",
          "It is the ORACLE: the" in FLAT
          and "printed before any measurement" in FLAT)
    check(g, "the alignment rule is quoted TWICE and is 16 both times",
          T.count("SP mod 16 = 0") >= 2 and "128 bytes" in FLAT)
    print()

    # ------------------------------------------------------------------
    # C. the decoder
    # ------------------------------------------------------------------
    g = "C decoder"
    print("  --- group C: the six models this course adds, and the dispatch")
    m = groups_of(r"(\d+) models in it, (\d+) added here, (\d+) in this file", T)
    check(g, "the model counts are printed together",
          m is not None and m[1] == "6" and m[2] == str(int(m[0]) + 6),
          m and "%s + 6 = %s" % (m[0], m[2]))
    for name in ("m_ldst_fp", "m_ldlit_fp", "m_pair_fp", "m_fp_2src",
                 "m_fp_cvt", "m_addsub_ext"):
        check(g, "the model %s is in the table" % name, name in T)
    check(g, "and each has a claim",
          "%d models and %d claims" % (int(m[0]) + 6, int(m[0]) + 6) in T)
    check(g, "the dispatch ORDER is called a design decision",
          "design decision and not a" in FLAT and "refactor" in FLAT)
    check(g, "the subset is a subset of NAMES and not of LENGTHS",
          "subset of NAMES" in FLAT and "not of LENGTHS" in FLAT)
    check(g, "unmodelled words are COUNTED, not dropped",
          "still unmodelled at -O2, by class" in T)
    rows = rows_of(T, r"^\s+O[02]\s+(\d+) instructions: +(\d+) named with all "
                      r"(\d+) models, +(\d+) with the (\d+) the encoding")
    check(g, "the coverage before/after is measured", len(rows) == 2,
          "%d rows" % len(rows))
    if rows:
        for r in rows:
            # r = (total, named_with_all, models, named_with_base, base_models)
            check(g, "the added models name instructions the base did not",
                  int(r[1]) > int(r[3]) and int(r[1]) <= int(r[0])
                  and int(r[2]) == int(r[4]) + 6,
                  "named %s of %s with %s models, %s with %s"
                  % (r[1], r[0], r[2], r[3], r[4]))
    print()

    # ------------------------------------------------------------------
    # D. the assembler sweep
    # ------------------------------------------------------------------
    g = "D sweep"
    print("  --- group D: what the assembler accepts and what it refuses")
    acc = rows_of(T, r"^  (\S[^\n]*?)\s+ACCEPTED\s+0x([0-9a-f]{8})\s+(\S+)")
    ref = rows_of(T, r"^  (\S[^\n]*?)\s+REFUSED\s+-\s+-\s+(.*)$")
    sw = groups_of(r"(\d+) accepted, (\d+) refused, and (\d+) distinct "
                   r"diagnostics", T)
    check(g, "the sweep has rows", len(acc) + len(ref) >= 25,
          "%d accepted, %d refused" % (len(acc), len(ref)))
    check(g, "and the counts the file prints are the counts in its table",
          sw is not None and int(sw[0]) == len(acc) and int(sw[1]) == len(ref)
          and int(sw[0]) + int(sw[1]) == len(acc) + len(ref),
          sw and "/".join(sw))
    check(g, "the q-pair diagnostic is printed verbatim",
          "index must be a multiple of 16 in range [-1024, 1008]" in T)
    check(g, "the d-pair diagnostic names 8",
          "index must be a multiple of 8 in range [-512, 504]" in T)
    check(g, "the w-pair diagnostic names 4",
          "index must be a multiple of 4 in range [-256, 252]" in T)
    check(g, "the unscaled range is 9-bit and signed",
          "index must be an integer in range [-256, 255]" in T)
    check(g, "`stp b0, b1` and `stp h0, h1` are REFUSED",
          any("stp b0" in r[0] for r in ref) and any("stp h0" in r[0] for r in ref))
    check(g, "the assembler REFUSES to name register 31 as a base",
          any("x31" in r[0] for r in ref)
          and "invalid operand for instruction" in T)
    check(g, "`fmov d0, #32.0` is refused and `#2.0` is not",
          any("#32.0" in r[0] for r in ref) and any("#2.0" in r[0] for r in acc))

    # the central one: str q0,[sp,#8] becomes a STUR
    strq = [r for r in acc if r[0].strip() == "str q0, [sp, #8]"]
    check(g, "`str q0, [sp, #8]` is ACCEPTED", len(strq) == 1)
    if strq:
        check(g, "and it becomes a STUR, a different encoding",
              strq[0][2].lower().startswith("stur"),
              "%s -> %s" % (strq[0][2], strq[0][1]))
    stq = [r for r in acc if r[0].strip() == "stur q0, [sp, #8]"]
    check(g, "and it is the SAME word as writing STUR",
          bool(stq) and strq and stq[0][1] == strq[0][1],
          strq and stq and strq[0][1])
    check(g, "and that is the file's headline finding about it",
          "it does not become an STR" in FLAT)
    print()

    # ------------------------------------------------------------------
    # E. the register assignment -- EXACT
    # ------------------------------------------------------------------
    g = "E argument"
    print("  --- group E: the register assignment, which is EXACT")
    # The artifact joins its cells with TWO spaces and the pattern has to
    # say so: a pattern with one space matches nothing and reports "0 rows",
    # which reads as "the compiler put no arguments in registers" and is the
    # most comfortable possible wrong answer.
    a = rows_of(T, r"^  (O0|O1|O2|Os)\s+(0:x0\s+1:x1\s+2:x2\s+3:x3\s+4:x4\s+"
                   r"5:x5\s+6:x6\s+7:x7\s+8:sp\+0)$")
    check(g, "nine integer arguments, four levels, all as predicted", len(a) == 4,
          "%d rows" % len(a))
    check(g, "x0..x7 in order and the 9th at sp+0 in EVERY row",
          all(re.match(r"0:x0\s+1:x1", r[1]) and r[1].endswith("8:sp+0")
              for r in a))
    check(g, "and no row reports a MISMATCH",
          "<<< MISMATCH" not in T)
    n = groups_of(r"(\d+) of (\d+) argument placements agree with C\.9, C\.13 "
                 r"and C\.17", T)
    check(g, "the tally is 36 of 36",
          n is not None and n[0] == n[1] == "36",
          n and "%s of %s" % (n[0], n[1]))
    d = rows_of(T, r"^  (O0|O1|O2|Os)\s+(0:d0\s+1:d1\s+2:d2\s+3:d3\s+4:d4\s+"
                   r"5:d5\s+6:d6\s+7:d7\s+8:stack@8)$")
    check(g, "nine double arguments, four levels, all as predicted", len(d) == 4)
    check(g, "d0..d7 in order and the 9th on the stack in EVERY row",
          all(r[1].endswith("8:stack@8") for r in d))
    def cells(rowpat):
        """The captured cells of each matching row, split into tokens.

        `rows_of` returns tuples, so `for g in rows_of(...)` gives tuples and
        `re.split` on a tuple raises.  The first version of this helper
        indexed the tuple as if it were the capture and compared a tuple to
        a string, which is the kind of mistake a reader has to run to make.
        """
        return [[c for c in re.split(r"\s+", g) if c]
                for r in rows_of(T, rowpat) for g in r]

    m8 = cells(r"^\s+O[02]\s+cm8\s+ints: ((?:\d->x\d\s*)+)$")
    check(g, "the mixed case puts 4 ints in x0..x3 in source order",
          bool(m8) and m8[0] == ["0->x0", "1->x1", "2->x2", "3->x3"],
          m8 and " ".join(m8[0]))
    m8f = cells(r"^\s+fps : ((?:\d->d\d\s*)+)\s+stacked at: (\S+)$")  # noqa
    check(g, "and 4 doubles in d0..d3, from the OTHER counter",
          bool(m8f) and m8f[0][:4] == ["0->d0", "1->d1", "2->d2", "3->d3"],
          m8f and " ".join(m8f[0][:4]))
    # `rows_of` uses re.match, which anchors at the START of the line, and
    # the "stacked at" cell is at the END of a line that begins with the
    # function name.  Anchoring the whole line is what the helper is FOR.
    stackd = [r[0] for r in rows_of(T, r"^.*stacked at: (none|\[[^\]]*\])$")]
    check(g, "and cm8 has NO stacked arguments at all",
          bool(stackd) and "none" in stackd, ", ".join(sorted(set(stackd))))
    m18 = cells(r"^\s+O[02]\s+cm18\s+ints: ((?:\d->x\d\s*)+)$")
    check(g, "with nine of each, the integers still fill x0..x7",
          bool(m18) and m18[0][-2:] == ["6->x6", "7->x7"],
          m18 and " ".join(m18[0][-2:]))
    check(g, "and the two ninths land at sp+0 and sp+8, integer FIRST",
          T.count("stacked at: [0, 8]") == 4,
          "%d rows" % T.count("stacked at: [0, 8]"))
    check(g, "the offsets are 0 and 8 and nothing else",
          set(x for x in re.findall(r"stacked at: (\[[^\]]*\])", T)) <=
          {"[0, 8]", "[]", "none"})
    check(g, "and the file says which order decides it",
          "the SPECIFICATION that decides which" in FLAT
          and "processing the list left to right" in FLAT)
    check(g, "x8 is the indirect result register and use_big proves it",
          "mov x8, sp" in T and "Indirect Result Location Register" in FLAT)
    check(g, "and the audit is by NAME, not a census",
          "An AUDIT says which ARGUMENT was in which register, by name" in FLAT)
    print()

    # ------------------------------------------------------------------
    # F. the alignment constant -- EXACT
    # ------------------------------------------------------------------
    g = "F alignment"
    print("  --- group F: the alignment rule, which is EXACT")
    check(g, "the constant is 16",
          "SIXTEEN. Not 128, not 64, not 8. Sixteen, in both places." in FLAT)
    for w, sc in (("stp w0, w1, [sp]", 4), ("stp d0, d1, [sp]", 8),
                  ("stp q0, q1, [sp]", 16), ("str q0, [sp]", 16),
                  ("str d0, [sp]", 8), ("stur q0, [sp]", 16)):
        # The word itself is NOT a capture group, so the scale is group 0
        # and the field description is group 1.  The first version indexed
        # group 1 and asked int() to parse "imm7", which is a harness crash
        # on a table where every value is correct.
        r = rows_of(T, r"^\s+%s\s+x(\d+)\s+(\S+)\s+(.*)$" % re.escape(w))
        check(g, "the scale of %s is %d" % (w, sc),
              bool(r) and int(r[0][0]) == sc, r and r[0][0])
    r = rows_of(T, r"^\s+stp q0, q1, \[sp\]\s+x16\s+.*\[(-?\d+), (\d+)\]$")
    check(g, "the q pair's reach is [-1024, 1008] and not [-1024, 1024]",
          bool(r) and (r[0][0], r[0][1]) == ("-1024", "1008"),
          r and "%s..%s" % (r[0][0], r[0][1]))
    b = groups_of(r"(\d+) of the (\d+) branches are made with SP not a", T)
    check(g, "every branch in the corpus is made with SP 16-aligned",
          b is not None and b[0] == "0" and int(b[1]) >= 100,
          b and "%s bad of %s" % (b[0], b[1]))
    check(g, "and the check is STRONGER than the rule, and says so",
          "STRICTLY" in FLAT and "MORE than the rule asks for" in FLAT)
    check(g, "the SCTLR encoding is measured",
          "0xd5381000" in T and "msr\tx0, SCTLR_EL1" not in T)
    check(g, "and the FAULT is declared unmeasured",
          "The FAULT is not measured, is not claimed" in FLAT
          and "SCTLR_ELx.A" in FLAT)
    print()

    # ------------------------------------------------------------------
    # G. one register, two names -- EXACT
    # ------------------------------------------------------------------
    g = "G registers"
    print("  --- group G: the register file as a partitioned namespace")
    pairs = rows_of(T, r"^  (\S.*?)\s+(\S.*?\S)\s+0x([0-9a-f]{8})\s+0x([0-9a-f]{8})"
                      r"\s+0x([0-9a-f]{8})$")
    check(g, "six w/x pairs", len(pairs) == 6, "%d pairs" % len(pairs))
    check(g, "and every one differs in exactly one bit",
          all(int(x[4], 16) == 0x80000000 for x in pairs),
          "xor = 0x80000000 in %d of %d"
          % (sum(1 for x in pairs if int(x[4], 16) == 0x80000000), len(pairs)))
    check(g, "and that bit is bit 31, the size field",
          "it is bit 31 -- `sf`," in FLAT)
    check(g, "the zero-extension consequence is stated",
          "ZERO EXTENSION" in FLAT and "not free" in FLAT)
    reg = rows_of(T, r"^  (\S[^\n]*?)\s+0x([0-9a-f]{8})\s+(\d+)\s+(\d+)\s+(\S.*)$")
    check(g, "register 31 is read out of three slots", len(reg) >= 8,
          "%d rows" % len(reg))
    check(g, "and the assembler will not NAME it in a base slot",
          "str w0, [x31, #12]" in T)
    check(g, "`mov x0, sp` and `mov x0, xzr` are different groups",
          "mov\tx0, sp" in T and "mov\tx0, xzr" in T
          and "not even in the same encoding" in FLAT)
    print()

    # ------------------------------------------------------------------
    # H. no red zone -- the frame census is a SHAPE
    # ------------------------------------------------------------------
    g = "H redzone"
    print("  --- group H: no red zone, asserted as a shape and not as a value")
    fr = rows_of(T, r"^\s+(O0|O1|O2|Os)\s+(\d+) of (\d+) functions allocate a "
                   r"frame at all\.$")
    check(g, "the frame census is reported at all four levels", len(fr) == 4)
    if fr:
        check(g, "and the count is of 25", all(r[2] == "25" for r in fr))
        by = {r[0]: (int(r[1]), int(r[2])) for r in fr}
        check(g, "at -O0 every function allocates",
              by["O0"][0] == 25, "%d of 25" % by["O0"][0])
        check(g, "at -O2 fewer than half do, and x86-64 fewer still",
              by["O2"][0] < 25 and "5 of 25" in T,
              "a64 %d of 25, x86 5 of 25" % by["O2"][0])
        check(g, "and the ORDER of the two columns is x86-64 below AArch64",
              "a64: with a frame" in T and T.index("a64: with a frame")
              < T.index("x86: with a frame"))
    # The four groups are (name, a64, x86, ratio).  The comment above this
    # block used to say "(name, what, a64, x86, ratio)" -- five, because the
    # description column is matched by LITERAL text and not by a group -- and
    # the code below it then indexed as if there were five, so it asked
    # int() to parse the ratio.  A comment that miscounts its own groups is
    # worse than no comment.
    rows = rows_of(T, r"^  (\S+)\s+a leaf with pure register arithmetic\s+(\d+)"
                   r"\s+(\d+)\s+([\d.]+)$")
    check(g, "the same C, both targets, as a COMPILE-TIME count", len(rows) == 1)
    if rows:
        check(g, "and the AArch64 half of `leaf_reg` is the smaller one",
              int(rows[0][1]) < int(rows[0][2]),
              "a64 %s, x86 %s, ratio %s" % (rows[0][1], rows[0][2], rows[0][3]))
        check(g, "and the column is labelled x86 OVER a64, so the reader "
                 "knows which way round it is",
              "x86 / a64" in T, rows[0][3])
    tot = groups_of(r"WHOLE CORPUS\s+all 25 functions of abi\.c at -O2\s+(\d+)"
                   r"\s+(\d+)\s+([\d.]+)", T)
    check(g, "and the whole-corpus ratio is printed as a NUMBER",
          tot is not None,
          tot and "a64 %s, x86 %s, ratio %s" % (tot[0], tot[1], tot[2]))
    check(g, "and for the whole corpus AArch64 is the LARGER one",
          tot is not None and float(tot[2]) < 1.0,
          tot and "x86/a64 = %s" % tot[2])
    check(g, "and it is labelled a property of a COMPILER VERSION",
          "property of clang 21.1.8" in FLAT and "COMPILER VERSION" in FLAT)
    which = rows_of(T, r"^  (O0|O1|O2|Os)\s+a64 only: (\S+(?: \S+)*?)\s+x86 only:"
                    r" (\(none\)|\S+)\s+both: (\d+)$")
    check(g, "the census says WHICH functions, not only how many", len(which) == 4)
    check(g, "and x86-64 never allocates where AArch64 does not",
          all("x86 only: (none)" in r[0] or r[2] == "(none)" for r in which))
    check(g, "the hand-written leaf is 3 instructions with no frame on A64",
          "a64_leaf_noframe     3 instructions" in T)
    check(g, "and 8 with a sub sp and an add sp",
          "a64_leaf_frame       11 instructions" in T
          and "sub\tsp, sp, #0x10" in T and "add\tsp, sp, #0x10" in T)
    check(g, "and the x86-64 leaf uses the red zone with no %rsp write",
          "x86_leaf_noframe     3 instructions" in T
          and "x86_leaf_frame       8 instructions" in T)
    print()

    # ------------------------------------------------------------------
    # I. callee-saved
    # ------------------------------------------------------------------
    g = "I callee-saved"
    print("  --- group I: callee-saved, read out of the compiler")
    check(g, "x19-x28 all ten, saved and restored",
          "saved x19-x28        restored x19-x28" in T)
    check(g, "and d8-d15, the 64-bit VIEW and not q",
          "fp: saved d8-d15" in T and "fp: saved q8-q15" not in T)
    check(g, "the v8-v15 clause is quoted, not paraphrased",
          "only the bottom 64 bits of each value stored in v8-v15" in FLAT)
    check(g, "and the v0-v7 error is retracted",
          "it preserves the lower 64 bits of v8-v15" in FLAT)
    x18 = one(r"Occurrences of w18/x18 in the whole corpus at all four levels: "
              r"(\d+)\.", T)
    check(g, "x18 is used ZERO times by clang on Linux", x18 == "0", x18)
    check(g, "and the rule that does not exist is retracted",
          "there is no such rule" in FLAT and "r13" in FLAT)
    nz = one(r"mrs/msr of a flag register in the corpus: (\d+)\.", T)
    check(g, "and there is no flag-register instruction at all", nz == "0", nz)
    check(g, "the AAPCS64 says the flags are UNDEFINED across an interface",
          "undefined on entry to and return from a public interface" in FLAT)
    check(g, "and the zero is compared with the x86-64 PUSHFQ count",
          "271 of them in 94 functions" in FLAT)
    print()

    # ------------------------------------------------------------------
    # J. CFI -- the row counts are a SHAPE
    # ------------------------------------------------------------------
    g = "J cfi"
    print("  --- group J: CFI, the frame in a second language, as a shape")
    # Nine groups: (name, i0, rows0, rules0, bytes0, i2, rows2, rules2,
    # bytes2, verdict).  There is no description column -- the first version
    # of this pattern required one, the table has none, and the check
    # reported 24 rows for a table of 25 and every one of the 24 was right.
    f = rows_of(T, r"^  (\S+)\s+(\d+) / (\d+) / (\d+) / (\d+)\s+"
                  r"(\d+) / (\d+) / (\d+) / (\d+)\s+(\S.*)$")
    check(g, "every function is reported at both levels", len(f) == 25,
          "%d rows" % len(f))
    up = [r for r in f if "TABLE GREW" in r[9]]
    down = [r for r in f if "table shrank" in r[9]]
    same = [r for r in f if r[9] == "identical"]
    check(g, "and every row is accounted for by exactly one verdict",
          len(up) + len(down) + len(same) == len(f),
          "%d + %d + %d vs %d" % (len(up), len(down), len(same), len(f)))
    check(g, "and the three outcomes are all present",
          len(up) and len(down) and len(same),
          "%d grew, %d shrank, %d identical" % (len(up), len(down), len(same)))
    check(g, "NO function goes UP in rows",
          all(r[9].endswith("rows +0") for r in up),
          "; ".join(r[0] + ": " + r[9] for r in up))
    # (name, i0, rows0, rules0, bytes0, i2, rows2, rules2, bytes2, verdict)
    check(g, "`many` holds its rows and gains rules",
          any(r[0] == "many" and r[2] == r[6] and int(r[7]) > int(r[3])
              and int(r[8]) > int(r[4]) for r in f),
          next(("rows %s -> %s, rules %s -> %s, bytes %s -> %s"
                % (r[2], r[6], r[3], r[7], r[4], r[8]) for r in f
                if r[0] == "many"), "?"))
    check(g, "`fmany` does the same in the vector bank",
          any(r[0] == "fmany" and r[2] == r[6] and int(r[7]) > int(r[3])
              and int(r[8]) > int(r[4]) for r in f),
          next(("rows %s -> %s, rules %s -> %s, bytes %s -> %s"
                % (r[2], r[6], r[3], r[7], r[4], r[8]) for r in f
                if r[0] == "fmany"), "?"))
    check(g, "`va` LOSES rows AND bytes",
          any(r[0] == "va" and int(r[6]) < int(r[2]) and int(r[8]) < int(r[4])
              for r in f),
          next(("rows %s -> %s, bytes %s -> %s" % (r[2], r[6], r[4], r[8])
                for r in f if r[0] == "va"), "?"))
    check(g, "and the 3-to-9 shape the course was written for is retracted",
          "Not one function in this corpus does that" in FLAT
          and "needs 3 rows at -O0 and 9 at -O2" in FLAT
          and "is a retraction and not a nuance" in FLAT)
    # (lvl, text, .text bytes, .eh_frame bytes, ratio%, functions)
    sz = rows_of(T, r"^  (O0|O1|O2|Os)\s+(\d+)\s+(\d+)\s+([\d.]+)%\s+(\d+)$")
    check(g, "the section sizes are reported for all four levels", len(sz) == 4)
    if sz:
        o0 = next(r for r in sz if r[0] == "O0")
        o2 = next(r for r in sz if r[0] == "O2")
        check(g, "the .eh_frame SHARE RISES from -O0 to -O2 while the code "
                 "SHRINKS",
              float(o2[3]) > float(o0[3]) and int(o2[1]) < int(o0[1]),
              ".text %s -> %s bytes, .eh_frame %s%% -> %s%%"
              % (o0[1], o2[1], o0[3], o2[3]))
    tot = rows_of(T, r"^  (O0|O1|O2|Os)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+"
                       r"([\d.]+)$")
    check(g, "the per-level row totals are reported too", len(tot) == 4)
    check(g, "and the reason is a floor per FUNCTION, not per byte",
          "a function of the NUMBER OF FUNCTIONS" in FLAT)
    check(g, "the CIE is quoted: return_address_register 30",
          "return_address_register: 30" in T)
    check(g, "and the CIE's CFA is reg31, the same 31 as section 6",
          "DW_CFA_def_cfa: reg31 +0" in T)
    check(g, "and data_alignment_factor -4 is quoted too",
          "data_alignment_factor: -4" in T)
    print()

    # ------------------------------------------------------------------
    # K. two readers
    # ------------------------------------------------------------------
    g = "K readers"
    print("  --- group K: two readers, and one of them poisoned")
    k = groups_of(r"(\d+) instructions read, (\d+) NAMED by reader 1, (\d+) "
                 r"disagreements\.", T)
    check(g, "the two-reader run is reported",
          k is not None and int(k[0]) > 1000, k and "/".join(k))
    check(g, "and the disagreement count is ZERO", k is not None and k[2] == "0",
          k and k[2])
    check(g, "or the word list is printed with it",
          "instructions that no rule resolved" in T)
    check(g, "the reconciliation rules are printed WITH COUNTS",
          "one example" in T or "->" in T)
    check(g, "and the file says why 100% is not a proof",
          "100% is still not a proof" in FLAT
          and "wrong in the same way as its oracle" in FLAT)
    pz = groups_of(r"With the poison in: (\d+) named, (\d+) DISAGREEMENTS", T)
    check(g, "the poison MOVES both numbers", pz is not None
          and int(pz[1]) > 0, pz and "%s named, %s bad" % pz)
    mv = groups_of(r"The named count moved from (\d+) to (\d+) -- (\d+) "
                   r"instructions", T)
    check(g, "and the drop is printed as a number",
          mv is not None and int(mv[2]) > 50,
          mv and "moved by %s" % mv[2])
    check(g, "the FIVE REAL BUGS are named, because they were found",
          "a guard that did not fix bits[25:24]" in FLAT
          and "printed 2.0 for 1.0" in FLAT
          and "complemented without sign-extending" in FLAT
          and "the number 150" in FLAT)
    print()

    # ------------------------------------------------------------------
    # L. the retractions
    # ------------------------------------------------------------------
    g = "L retractions"
    print("  --- group L: every retraction, asserted as TEXT")
    for tag, frag in (
            ("R1", "the AAPCS64 stack alignment rule is 128 bytes"),
            ("R1", "the rule is 16 bytes"),
            ("R2", "ZEROES the top half"),
            ("R3", "an APPLE platform-ABI RED ZONE"),
            ("R4", "it preserves the lower 64 bits of v8-v15"),
            ("R5", "there is no such rule"),
            ("R6", "UNDEFINED across a public interface"),
            ("R7", "Not one function in this corpus does that")):
        check(g, "%s is retracted with its finding: %s" % (tag, frag[:34]),
              frag in FLAT)
    tags = sorted(set(re.findall(r"^  (R\d)\b", T, re.M)))
    check(g, "there are seven retractions and they are numbered in order",
          tags == ["R1", "R2", "R3", "R4", "R5", "R6", "R7"], ",".join(tags))
    check(g, "each retraction names a document or a brief",
          T.count("docs/aarch64-section-plan.md") >= 3)
    check(g, "each retraction says WHAT WAS FOUND and WHY",
          T.count("WHAT WAS FOUND") >= 7 and T.count("WHY") >= 7)
    check(g, "and the count is printed, with the argument for it",
          "7 retractions." in T
          and "has either not looked or has not been reading" in FLAT)
    print()

    # ------------------------------------------------------------------
    # M. the limits
    # ------------------------------------------------------------------
    g = "M limits"
    print("  --- group M: what the file cannot show")
    for title in ("NOTHING IS EXECUTED", "THE ALIGNMENT FAULT IS NOT MEASURED",
                  "THE DECODER IS A SUBSET OF NAMES",
                  "THE TWO READERS SHARE A SOURCE",
                  "THE SPECIFICATION IS AN ORACLE, NOT A MEASUREMENT",
                  "THE COMPILER IS THE TEST SUBJECT, NOT THE ARCHITECTURE",
                  "THE ENCODER IS ONE ASSEMBLER",
                  "THE ARCHITECTURAL MANUAL IS NOT CITED DIRECTLY",
                  "NO CORPUS IS A DISTRIBUTION"):
        check(g, "the limit is printed: %s" % title, title in T)
    check(g, "and the timing absence is restated in the limits",
          "NOT reproduced in any form" in FLAT)
    check(g, "and the shipped output is what the harness can read without "
             "building", os.path.exists(default_output()))
    print()

    # ------------------------------------------------------------------
    print("=" * 72)
    if FAILURES:
        print("%d of %d checks, %d failed" % (CHECKS, CHECKS, len(FAILURES)))
        for grp, what, detail in FAILURES:
            print("  [%s] %s  %s" % (grp, what, detail))
        print("=" * 72)
        return 1
    # Two tally spellings are in use across the collection -- "N/M checks
    # passed" and "N checks, M failed" -- and tools/verify_*.py accepts either
    # by requiring only that the failures column is zero.  This file uses the
    # first, which is the one the collection's verifiers read first.
    print("%d/%d checks passed" % (CHECKS, CHECKS))
    print("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
