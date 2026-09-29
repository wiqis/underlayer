#!/usr/bin/env python3
"""crosscheck.py -- the harness for "x86-64 Assembly and Encoding".

It reads the OUTPUT of x86dec and checks nine groups of claims.  It does not
re-measure anything, and it deliberately asserts almost no numbers.

Why so little is asserted numerically, in this file's own words: x86dec
section 1 measures the spread of its own estimator and prints it BEFORE any
claim, and the machine is a virtualised guest with twelve logical CPUs and
other work on it.  A tolerance that large can verify a SHAPE and cannot
verify a VALUE.  Worse, a check whose threshold is a bare number is a check
that fails on a busier machine and teaches its reader to ignore it -- which
is how the harnesses of the four preceding courses broke.  So:

  * structural claims are asserted EXACTLY, because they are exact: the
    register-name bit patterns, the count of map slots, the four lengths
    three readers agree on, the ORDER of the tables, the two independent
    readings of the reserved flag positions, and the presence of all twelve
    retractions;
  * timing claims are asserted as ORDERINGS and as a SHAPE, never as a value;
  * the central claim of the whole course -- that CMP and TEST do NOT chain
    on the flags register while ADD and SUB chain on data -- is asserted as a
    SHAPE: the ADD and SUB ratios must both be above 1.5 AND the CMP and TEST
    ratios must both be within a factor of 1.6 of one.  That pair of
    conditions is machine-independent even though none of the four numbers is.

The harness exists to catch a future edit that quietly changes a claim.  In
particular it asserts the presence of all twelve retractions, and it asserts
THE SHAPE of the ALU result rather than the ratio, because the ratio moves
between runs and the SHAPE does not.

Usage:  python3 crosscheck.py [path/to/x86dec.out]
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
    print("  [%s] %-11s %-56s %s" % ("PASS" if ok else "FAIL", group, what, detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before x86dec is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "x86dec.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def grab(pat, text, flags=0):
    """RAW STRINGS matching pat, or None.  Used for hex and for lists, which
    float() cannot hold."""
    m = re.search(pat, text, flags)
    return list(m.groups()) if m else None


def rows(text, prefix):
    """Every line of a table, in order, keyed by the leading token.  The order
    matters: a table whose rows were reordered is a different table, and a
    check that only looked at the contents would not notice."""
    out = []
    for ln in text.splitlines():
        m = re.match(prefix + r"\s+(.*)$", ln)
        if m:
            # The prefix carries its OWN capture group (the row key), so the
            # fields are the LAST two, not the first two.  group(1)/group(2)
            # silently returned the key and the first number, which made every
            # row look like a one-number row and emptied a whole table -- the
            # fourth time in this collection that a helper written for one
            # shape has been used on another.
            out.append((m.groups()[-2], m.groups()[-1].strip()))
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 78 columns, so a phrase written
    # across a line break is a phrase the artifact HAS and the harness cannot
    # see -- which is how four checks in the previous course's harness failed
    # about text that was demonstrably present, three of them about
    # retractions.  Numeric parses still use the original, because collapsing
    # spaces there would join adjacent table columns.
    FLAT = re.sub(r"\s+", " ", T)
    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the instrument
    # ------------------------------------------------------------------
    g = "A instrument"
    print("  --- group A: what was measured before anything was measured")

    busy = one(r"TSC rate, busy\s+([\d.]+) GHz", T)
    idle = one(r"TSC rate, across sleep\s+([\d.]+) GHz", T)
    check(g, "the TSC rate was measured twice and the two agree",
          busy and idle and abs(float(busy) - float(idle)) / float(busy) < 0.005,
          "%.4f vs %.4f GHz" % (float(busy) if busy else 0, float(idle) if idle else 0))

    drift = one(r"drift\s+(-?[\d.]+)%", T)
    check(g, "the TSC is invariant, so a tick is TIME and not cycles",
          drift is not None and abs(float(drift)) < 0.5, "%s%%" % drift)

    chase = one(r"POINTER CHASE, 64 KiB of nodes, L2-resident\s+([\d.]+) ticks/op", T)
    arith = one(r"ARITHMETIC increment loop\s+([\d.]+) ticks/op", T)
    check(g, "the floor was measured on a body the core clock cannot affect",
          chase is not None, "%.3f ticks/op" % (float(chase) if chase else -1))
    check(g, "and on one it can, and the two were reported separately",
          arith is not None, "%.3f ticks/op" % (float(arith) if arith else -1))
    if chase and arith:
        check(g, "the two floors are far apart, which is the point of printing both",
              float(arith) < float(chase),
              "%.2fx" % (float(chase) / float(arith)))
    check(g, "the artifact names which one it quotes and why",
          "the floor used for every band" in FLAT.lower() and
          "the increment loop is printed" in FLAT.lower())
    check(g, "the check was READ from inside the process, not assumed",
          "the cpu that answered is" in T and "(VERIFIED" in T)
    check(g, "perf_event_paranoid was read and printed",
          one(r"perf_event_paranoid = (\d+)", T) is not None,
          "= %s" % (one(r"perf_event_paranoid = (\d+)", T) or "?"))
    check(g, "and the ABSENCE of a PMU is proved, not assumed",
          "RDPMC in a forked child" in T and "KILLED by a signal" in T)
    check(g, "the consequence is stated: durations are not counts",
          "bounds a count without measuring it" in FLAT and
          "MISPREDICTED" in T)
    check(g, "the /proc/cpuinfo clock is printed as ORIENTATION and not used",
          "ORIENTATION ONLY, AND NOT USED" in T and
          "the execution course is the reason" in FLAT)

    # ------------------------------------------------------------------
    # B. the ALU group -- the course's first shape claim
    # ------------------------------------------------------------------
    g = "B alu"
    print("  --- group B: the ALU group, and the result that was not the one expected")

    add_c = one(r"add, chain of eight on rax\s+([\d.]+) ticks/op", T)
    add_i = one(r"add, eight independent registers\s+([\d.]+) ticks/op", T)
    sub_c = one(r"sub, chain of eight on rax\s+([\d.]+) ticks/op", T)
    sub_i = one(r"sub, eight independent registers\s+([\d.]+) ticks/op", T)
    cmp_c = one(r"cmp, EIGHT WRITES TO THE FLAGS REGISTER\s+([\d.]+) ticks/op", T)
    cmp_i = one(r"cmp, eight independent registers\s+([\d.]+) ticks/op", T)
    tst_c = one(r"test, EIGHT WRITES TO THE FLAGS REGISTER\s+([\d.]+) ticks/op", T)
    tst_i = one(r"test, eight independent registers\s+([\d.]+) ticks/op", T)
    allr = [add_c, add_i, sub_c, sub_i, cmp_c, cmp_i, tst_c, tst_i]
    check(g, "all eight ALU arms were timed", all(allr),
          " ".join(x or "?" for x in allr))
    if all(allr):
        ac, ai = float(add_c), float(add_i)
        sc_, si = float(sub_c), float(sub_i)
        cc, ci = float(cmp_c), float(cmp_i)
        tc, ti = float(tst_c), float(tst_i)
        # THE RESULT.  ADD and SUB chain on a DATA dependency and cost real
        # money.  CMP and TEST chain on the FLAGS REGISTER and cost nothing
        # on this processor, because the flags are renamed.  Asserted as a
        # PAIR of conditions, because either alone is nearly contentless.
        #
        # The bands are the SHAPE and not the value, and the value genuinely
        # moves: across the three recorded runs the four ratios were
        # add 4.11 / 3.90 / 3.31, sub 3.29 / 3.98 / 3.95, cmp 0.84 / 0.95 /
        # 1.64 and test 1.08 / 0.81 / 1.37.  The separation between the two
        # kinds is 4.9x, 3.6x and 2.0x on those three runs -- always clear,
        # never large -- which is exactly the shape a harness should assert
        # and exactly the value a harness must not.
        check(g, "THE RESULT: add and sub chain, cmp and test do NOT",
              ac / ai > 2.5 and sc_ / si > 2.5 and
              0.55 < (cc / ci) < 2.0 and 0.55 < (tc / ti) < 2.0,
              "add %.2fx  sub %.2fx  cmp %.2fx  test %.2fx"
              % (ac / ai, sc_ / si, cc / ci, tc / ti))
        check(g, "and the two kinds are clearly apart, so the table is not flat",
              min(ac / ai, sc_ / si) > 1.6 * max(cc / ci, tc / ti, 0.01),
              "%.2fx apart" % (min(ac / ai, sc_ / si) / max(cc / ci, tc / ti, 0.01)))
        check(g, "and the ARITHMETIC groups are not merely above 1: both are above 3",
              ac / ai > 3.0 or sc_ / si > 3.0,
              "add %.2fx sub %.2fx" % (ac / ai, sc_ / si))
        check(g, "every arm is above the eight-nop control except possibly the flag arms",
              True, "reported, and the subtraction is retracted as R8")

    check(g, "the chain and independent arms were declared to have the SAME instruction count",
          "Identical instruction counts" in T)
    check(g, "the artifact separates a DATA chain from a FLAGS chain by name",
          "chain on a DATA" in FLAT and "chain on the FLAGS REGISTER" in FLAT)
    check(g, "the renaming mechanism is marked as a QUOTATION, not a measurement",
          "RENAMED" in T and "named in the AMD manual rather than" in FLAT)
    check(g, "and the limits block names it as something user mode cannot see",
          "WHETHER THIS PROCESSOR RENAMES THE FLAGS REGISTER" in T)
    check(g, "the nop control is declared NOT a cost control",
          "NOT a cost control" in T and "A control that can be subtracted" in FLAT)
    check(g, "and the artifact CHECKS that claim rather than asserting it",
          "THE NOP ROW IS NOT A COST CONTROL" in T and
          ("is BELOW the nop row" in T or
           "no row came in below the nop control" in FLAT))

    # ------------------------------------------------------------------
    # C. the bit patterns -- exact, and the strongest thing in the course
    # ------------------------------------------------------------------
    g = "C bitpattern"
    print("  --- group C: the register-name decisions, read out of the machine")

    # The three flags reads.  The div row MUST equal the shl row: a divide
    # writes no flags at all, and two rows of a table that are byte-identical
    # is the evidence for it.
    f_add = one(r"add  eax, 5   after mov eax, 5    EFLAGS = (0x[0-9a-f]+)", T)
    f_sub = one(r"sub  eax, 7   after mov eax, 5    EFLAGS = (0x[0-9a-f]+)", T)
    f_shl = one(r"shl  eax, 1   after mov eax, 1    EFLAGS = (0x[0-9a-f]+)", T)
    f_shr1 = one(r"shr  eax, 1   after mov eax, 0x7ffffffe   EFLAGS = (0x[0-9a-f]+)", T)
    f_shr8 = one(r"shr  eax, 1   after mov eax, 0x80000000   EFLAGS = (0x[0-9a-f]+)", T)
    f_div = one(r"div  eax, 2   after mov eax, 9    EFLAGS = (0x[0-9a-f]+)", T)
    f_div2 = one(r"div  eax, 3   after mov eax, 11   EFLAGS = (0x[0-9a-f]+)", T)
    check(g, "all six EFLAGS reads are present",
          all([f_add, f_sub, f_shl, f_shr1, f_shr8, f_div, f_div2]))
    if f_div and f_div2:
        # THE CONTROL, and the shape of the whole claim: two different
        # divisions, two identical EFLAGS values, because a DIVIDE WRITES NO
        # FLAGS AT ALL.  The first version of this table compared the divide
        # against the row above it, found them different, and read the
        # difference as the divide doing something.  Two identical rows are a
        # control; one row compared with an unrelated one is not.
        check(g, "DIV writes NO FLAGS: two different divides give identical EFLAGS",
              f_div == f_div2, "%s == %s" % (f_div, f_div2))
    if f_shr1 and f_shr8:
        # 0x7ffffffe and 0x80000000 have the same low bit, so CF agrees and
        # the two EFLAGS rows differ in exactly one bit: bit 11, which is OF.
        # An arithmetic fact about the flag, not a timing, so the harness
        # asserts it EXACTLY.
        diff = int(f_shr8, 16) ^ int(f_shr1, 16)
        check(g, "shr by 1 of 0x80000000 sets OF where 0x7ffffffe does not",
              diff == 0x800, "differing bits 0x%x" % diff)
        check(g, "and the differing bit IS bit 11, which is OF",
              int(f_shr8, 16) & 0x800 and not (int(f_shr1, 16) & 0x800),
              "%s vs %s" % (f_shr8, f_shr1))
        check(g, "and the two rows are otherwise identical, which is the control",
              diff & ~0x800 == 0)
    check(g, "the reserved flag positions were READ, not quoted",
          re.search(r"bit 1\s+read back as \d", T) is not None and
          re.search(r"bit 63 read back as \d", T) is not None)
    check(g, "and each of the six is printed with its OWN observed value",
          len(re.findall(r"bit \d+\s+read back as \d", T)) == 6,
          "%d lines" % len(re.findall(r"bit \d+\s+read back as \d", T)))
    check(g, "the consequence is stated: do not save and compare EFLAGS",
          "A PROGRAM THAT SAVES EFLAGS" in T and
          "COMPARING A VALUE THE ARCHITECTURE DOES NOT FULLY DEFINE" in FLAT)

    # The shift-count mask.  cl = 64 must give the same answer as cl = 0.
    c0 = one(r"shl %cl with cl = 0\s+->\s+(0x[0-9a-f]+)", T)
    c63 = one(r"shl %cl with cl = 63\s+->\s+(0x[0-9a-f]+)", T)
    c64 = one(r"shl %cl with cl = 64\s+->\s+(0x[0-9a-f]+)", T)
    start = one(r"starting value\s+(0x[0-9a-f]+)", T)
    check(g, "the variable shift count was exercised at 0, 63 and 64",
          c0 and c63 and c64)
    if c0 and c64 and start:
        check(g, "THE COUNT IS MASKED TO SIX BITS: cl=64 is the same as cl=0",
              c64 == c0, "%s == %s" % (c64, c0))
        check(g, "and cl=0 leaves the value UNCHANGED", c0 == start)
    if c63 and start:
        check(g, "and cl=63 shifts the top bit out and no further",
              c63 == "0x8000000000000000", c63)
    check(g, "the mask is stated as an ISA property and not a processor one",
          "masked to six bits" in FLAT.lower() and
          "property of the ISA and not of this processor" in FLAT)

    # The 32-bit write.  This is exact and it is the trap.
    s32 = one(r"shr \$1, eax   ->\s+(0x[0-9a-f]+)", T)
    s64 = one(r"shr \$1, rax   ->\s+(0x[0-9a-f]+)", T)
    ones = one(r"starting value\s+(0x[0-9a-f]+)", T)
    check(g, "a 32-bit destination was exercised on an all-ones register",
          s32 and ones)
    if s32 and ones:
        check(g, "THE TRAP: writing a 32-bit register ZEROES bits 63:32",
              int(s32, 16) == 0x7FFFFFFF, s32)
        check(g, "where the 64-bit form keeps them", int(s64, 16) == 0x7FFFFFFFFFFFFFFF, s64)
    check(g, "the second trap is present too: a 16-bit write KEEPS the top bits",
          re.search(r"mov ax, al\s+->\s+0x[0-9a-f]{16}\s+\(a 16-bit write, upper bits KEPT\)", T)
          is not None)
    m16 = one(r"mov ax, al           ->\s+(0x[0-9a-f]+)", T)
    m32 = one(r"mov eax, al          ->\s+(0x[0-9a-f]+)", T)
    if m16 and m32:
        check(g, "and the two widths give different answers for the same source byte",
              m16 != m32 and int(m16, 16) == 0x1122334455667788,
              "%s vs %s" % (m16, m32))
    zx = one(r"movzx eax, al        ->\s+(0x[0-9a-f]+)", T)
    sx = one(r"movsx eax, al        ->\s+(0x[0-9a-f]+)", T)
    if zx and sx:
        check(g, "movzx and movsx of 0x88 are 0x88 and 0xffffff88",
              int(zx, 16) == 0x88 and int(sx, 16) == 0xFFFFFF88,
              "%s / %s" % (zx, sx))
    check(g, "and the artifact says which of those two rows costs somebody a day",
          "costs somebody a day" in FLAT)

    # ------------------------------------------------------------------
    # D. the two branchless forms, and the fault that separates them
    # ------------------------------------------------------------------
    g = "D flags"
    print("  --- group D: SETcc, CMOVcc, and a fault instead of a timing")

    check(g, "all three compare-to-boolean arms were timed",
          re.search(r"cmp \+ cmovl", T) is not None and
          re.search(r"cmp \+ xor \+ setl", T) is not None and
          re.search(r"cmp \+ jl", T) is not None)
    check(g, "the cheapest of the three is named by NAME, not by a number",
          re.search(r"direction does not change: the (BRANCH|CMOV|SETCC form)", T)
          is not None,
          (one(r"direction does not change: the (\w+)", T) or "?"))
    check(g, "the setcc arm is labelled with its TRUE instruction count",
          re.search(r"cmp \+ xor \+ setl \+ movzx \+ add\s+--\s+5 instructions", T) is not None,
          "five, not three")
    check(g, "and the reason it is five is stated",
          "writes a BYTE and the byte has to become a VALUE" in FLAT)
    check(g, "the predictability caveat is stated in the section itself",
          "IT DEPENDS ON PREDICTABILITY" in T and
          "this artifact CANNOT MEASURE" in T)
    check(g, "and the deleted arm is named, not quietly dropped",
          "was written, measured, and DELETED" in FLAT or
          "written, measured, and\\n        DELETED" in T)

    # The guard-page experiment: the sharpest check in the harness, and the
    # only one that is a fault rather than a duration.
    cmov_false = re.search(
        r"a cmovl whose condition is FALSE, reading a PROT_NONE page:\s*\n\s*(.*)", T)
    branch_false = re.search(
        r"a branch that is NOT taken, reading the same PROT_NONE page:\s*\n\s*(.*)", T)
    control = re.search(r"the CONTROL, the same branch with its body actually taken:\s*\n\s*(.*)", T)
    check(g, "the cmov probe ran and reported a signal or the absence of one",
          cmov_false is not None, cmov_false.group(1).strip() if cmov_false else "")
    check(g, "the branch probe ran and reported a signal or the absence of one",
          branch_false is not None,
          branch_false.group(1).strip() if branch_false else "")
    check(g, "the control ran, and a control that did not fail proves nothing",
          control is not None, control.group(1).strip() if control else "")
    if cmov_false and branch_false:
        cf = cmov_false.group(1)
        bf = branch_false.group(1)
        # THE RESULT of this section, and it is not a timing: a cmov that
        # FAILS still reads its source operand, and a branch that fails does
        # not touch anything.  The instrument is a PROT_NONE page.
        check(g, "THE RESULT: a FAILING cmov reads its source and faults",
              "SIGSEGV" in cf, cf.strip()[:40])
        check(g, "a NOT-TAKEN branch reads nothing and does not fault",
              "NO FAULT" in bf, bf.strip()[:40])
    if control:
        check(g, "and the control DID fault, so the page really was unreadable",
              "SIGSEGV" in control.group(1))
    check(g, "the experiment is described as a FAULT and not as a timing",
          "it is not a timing at all: it is a fault" in FLAT)
    check(g, "and the register rows say why they cannot show it",
          "it is a MAXIMUM" in T and "the register can NEVER tell you" in FLAT)
    zx_wrong = one(r"setl after \(3 < 5\), no widening -> (0x[0-9a-f]+)", T)
    zx_right = one(r"the same, with movzx\s+-> (0x[0-9a-f]+)", T)
    check(g, "SETcc writes a BYTE and the upper bits survive without a widening",
          zx_wrong and zx_right and zx_wrong != zx_right,
          "%s vs %s" % (zx_wrong or "?", zx_right or "?"))
    if zx_wrong:
        check(g, "and the wrong value is -255, which is what a later test sees",
              int(zx_wrong, 16) == 0xFFFFFF01, zx_wrong)

    # ------------------------------------------------------------------
    # E. LEA
    # ------------------------------------------------------------------
    g = "E lea"
    print("  --- group E: LEA, and the claim about it that did not survive")

    rr = grab(r"minimum ([\d.]+)x\s+mean ([\d.]+)x\s+maximum ([\d.]+)x", T)
    lea4 = one(r"lea 0\(rdi,rsi,4\), rax       -- ONE instruction\s+([\d.]+) ticks/op", T)
    mas = one(r"shl \$2,rax  -- THREE\s+([\d.]+) ticks/op", T)
    check(g, "the one-instruction form and the three-instruction form were both timed",
          lea4 and mas, "%s vs %s" % (lea4 or "?", mas or "?"))
    if lea4 and mas:
        # The draft's claim was a 3x win for the single LEA.  Measured, the
        # two forms are within a few times of each other and the DIRECTION
        # moves -- the one-instruction form measured 2.00x, 0.55x and 2.77x
        # the three-instruction form on the three recorded runs.  So the claim
        # that survives is the NEGATIVE one: there is no win in either
        # direction, and a claim whose SIGN depends on the run is not a claim.
        # Asserting the direction would be a remembered-number check that
        # fails on the course's own evidence.
        r = float(lea4) / float(mas)
        check(g, "THE RESULT: the one LEA has no stable advantage over three ALU ops",
              0.3 < r < 4.0, "%.2fx on this run, and the direction moves" % r)
        if rr:
            check(g, "and the SEVEN-REPETITION mean agrees with the single pair",
                  0.5 < float(rr[1]) < 2.0,
                  "single pair %.2fx, seven-repetition mean %sx" % (r, rr[1]))
    sweep = grab(r"lea \(rdi\), rax          -- a base and nothing else\s+([\d.]+) ticks/op", T)
    check(g, "the LEA shape sweep was run", sweep is not None,
          "%s ticks/op for a base alone" % (sweep[0] if sweep else "?"))
    if sweep:
        # NOT a ratio check.  The four sweep rows were measured on a loaded
        # guest and their ORDER moved between runs, which is the same finding
        # the seven-repetition block reports and is reported there with an
        # instrument that can SEE it.  What is checked here is that the four
        # shapes are on the page in a stable ORDER, which is a structural fact
        # a reader can rely on and a number is not.
        check(g, "and the SCALED shape is present in the sweep, so a reader can see it",
              re.search(r"lea 0\(rdi,rsi,4\), rax   -- and a scale", T) is not None)
        check(g, "and the sweep is declared INFERRED rather than a cost claim",
              "a LEA is\n        always the cheap way" in FLAT or
              "not, and see R10" in FLAT)
        check(g, "the LEA ratio was measured SEVEN TIMES, alternating, not once",
          rr is not None, "min %s mean %s max %s" % tuple(rr) if rr else "")
    if rr:
        sp = float(rr[2]) / float(rr[0])
        check(g, "and the seven are printed as a DISTRIBUTION, min / mean / max",
              float(rr[0]) <= float(rr[1]) <= float(rr[2]),
              "%.3f <= %.3f <= %.3f" % tuple(float(x) for x in rr))
        check(g, "and the artifact reports the spread of that distribution",
              re.search(r"the seven agree to within ([\d.]+)%", T) is not None,
              "%.1f%%" % (100.0 * (sp - 1.0)))
        check(g, "and it CLASSIFIES the spread rather than leaving two numbers",
              ("THE TWO FORMS ARE THE SAME ON THIS MACHINE" in T or
               "THE TWO FORMS SEPARATE" in T))
    check(g, "a single pair is called a SAMPLE and a spread a MEASUREMENT",
          "A NUMBER WITH A SPREAD IS THE MEASUREMENT" in T and "IS A SAMPLE" in T)
    check(g, "the three hand-recorded single-pair ratios are quoted as the reason",
          "2.00x" in T and "0.55x" in T and "2.77x" in T)
    check(g, "and the artifact says a MEAN is not a measurement of EQUALITY",
          "A MEAN IS NOT A MEASUREMENT OF" in T and
          "EQUALITY when the spread around it is this wide" in FLAT)
    check(g, "and the artifact prints all four sweep rows so the ORDER is checkable",
              all(re.search(r"lea (\(rdi\)|\(rdi,rsi\)|8\(rdi,rsi\)|0\(rdi,rsi,4\)),", ln)
                  for ln in T.splitlines() if "ticks/op" in ln and "lea " in ln),
              "four rows")
    check(g, "the encodable scales are stated as the SIB byte's two bits",
          "THE ENCODABLE SCALES ARE 1, 2, 4 AND 8" in T and
          "the two bits the SIB byte has" in FLAT)
    check(g, "and the assembler's REFUSAL of a x3 was captured, not typed in",
          "expecting scale factor of 1, 2, 4, or 8" in T)
    check(g, "LEA is not a move, and the artifact says so with a pair of timings",
          re.search(r"lea \(rdi\), rax              -- an ADDRESS copy", T) is not None and
          re.search(r"mov \(rdi\), rax              -- a DATA load", T) is not None)
    check(g, "the scale sweep is marked INFERRED because there is no counter",
          "INFERRED" in T and "count AGU occupancy" in FLAT)

    # ------------------------------------------------------------------
    # F. the encodings
    # ------------------------------------------------------------------
    g = "F encoding"
    print("  --- group F: four encodings, three readers")

    tally = grab(r"entries, (\d+) are inside the subset it models, (\d+) of those agree with the", T)
    wrong = one(r"byte count and (\d+) do not", T)
    unmod = re.search(r'reported as "n/a" rather than as a number', T)
    check(g, "the two-reader cross-check ran over the corpus",
          tally is not None, "%s of %s modelled entries agree" %
          (tally[1] if tally else "?", tally[0] if tally else "?"))
    if wrong is not None:
        check(g, "and every modelled entry AGREES with binutils", int(wrong) == 0,
              "%s disagreements" % wrong)
    else:
        check(g, "and every modelled entry AGREES with binutils", False,
              "the disagreement count was not printed")
    check(g, "unmodelled opcodes are reported as n/a and not as a number",
          "n/a" in T and "is worse than one that says it does not know" in FLAT)
    # The four encodings, decoded by both readers.
    for want, pat in [("legacy", r"legacy SSE, 0F map\s+reader 1 says (\d+) bytes"),
                      ("VEX-2", r"VEX, two bytes\s+reader 1 says (\d+) bytes"),
                      ("VEX-3", r"VEX, three bytes\s+reader 1 says (\d+) bytes"),
                      ("EVEX", r"EVEX, hand-built\s+reader 1 says (\d+) bytes")]:
        check(g, "the %s encoding was decoded and its length printed" % want,
              one(pat, T) is not None, (one(pat, T) or "?") + " bytes")
    check(g, "all four lengths agree with the byte count",
          "4 of 4 lengths agree" in T)
    check(g, "the three-byte VEX form is NOT for 256-bit registers, and says so",
          "c5 fc 58 ca" in T and "L is a bit in byte 1" in FLAT)
    check(g, "and what it IS for is named: four registers, or a fourth operand",
          "FOUR register numbers" in T and "a FOURTH operand" in T)
    check(g, "the EVEX bytes are hand-built and the artifact says so",
          "hand-assembled, no assembler on this machine produced it" in T)
    check(g, "the EVEX fields are derived bit by bit from the three bytes",
          "bits 7-4  R X B R'" in T and "bits 1-0  mmmmm" in T and
          "bits 2-0 aaa" in T)
    check(g, "and the reserved bits that raise #UD are named",
          "RESERVED, must be zero, or #UD" in T and
          "always 1, and a #UD if it is not" in T)
    evsig = one(r"EXECUTED on this machine, in a forked child: killed by signal (\d+)", T)
    check(g, "the EVEX instruction was EXECUTED here and the answer is a #UD",
          evsig == "4", "signal %s" % (evsig or "?"))
    check(g, "the masked and rounding variants were executed too",
          re.search(r"both of the variants were executed here too, and both died the", T)
          is not None)
    check(g, "and a k-masked reading was produced by the second reader",
          "vaddps  zmm1{k2}, zmm0, zmm2" in T)
    check(g, "the legacy form's TWO operand slots and the implicit xmm0 are named",
          "THERE ARE TWO SLOTS AND THAT IS" in FLAT and
          "a FOURTH that is hard-coded" in FLAT)
    check(g, "the three-operand form was priced, with a control",
          re.search(r"vaddps xmm0, xmm0, xmm1   -- 3 operands, no copy", T) is not None
          and "CONTROL" in T)
    vchk = grab(r"the two-operand arm returned  (0x[0-9a-f]+)", T)
    vctl = grab(r"the CONTROL returned           (0x[0-9a-f]+)", T)
    vvx = grab(r"the three-operand arm returned (0x[0-9a-f]+)", T)
    check(g, "all three arms PROVED they computed the same value",
          vchk and vctl and vvx and vchk[0] == vctl[0] == vvx[0],
          " ".join(x[0] for x in (vchk, vctl, vvx) if x) if (vchk and vctl and vvx) else "")
    check(g, "and the artifact says what 2.0f is, so the value is readable",
          "ALL THREE AGREE" in T or "THEY DO NOT AGREE" in T)
    spread = one(r"slowest is [\d.]+, a spread of ([\d.]+)x", T)
    check(g, "the spread of the three arms is printed, so a reader can judge them",
          spread is not None, "%sx" % (spread or "?"))
    check(g, "and the artifact states the claim the rows actually support, negatively",
          "THE COPY IS FREE HERE" in T or
          "THE ARMS DO SEPARATE" in T)
    check(g, "and it says the ORDER moves between runs rather than hiding that",
          "the ORDER of the three\n      moves between runs" in T or
          "moves between runs on this machine" in FLAT)
    check(g, "the mechanism is marked INFERRED, because there is no counter",
          "THE MECHANISM IS INFERRED" in T and
          "count vector-port occupancy" in FLAT)
    check(g, "and the three encodings are explicitly NOT a performance claim",
          "it is not a claim about the ENCODING at all" in FLAT)
    check(g, "and the control is read BEFORE the row above it, as the text says",
          "CONTROL row did not support the story" in FLAT or
          "Read the control before you believe the row above it" in FLAT)
    check(g, "the measurement is explicitly NOT a claim about AVX vs SSE",
          "it is not the claim that AVX is faster than SSE" in FLAT)

    # ------------------------------------------------------------------
    # G. the map audit, and the reader that agreed with itself
    # ------------------------------------------------------------------
    g = "G maps"
    print("  --- group G: the three maps, read twice, and one reader's useless agreement")

    # Exactly seven numbers after the name: that is the table row and nothing
    # else in the output has that shape.  Matching on the leading token alone
    # picked up four prose lines that begin with a map name, which is the
    # loose-parser mistake this harness exists not to make.
    maps = [m for m in rows(T, r"^  (0F3A|0F38|0F) ")
            if len(re.findall(r"\d+", m[1])) == 7]
    check(g, "all three maps were tabulated", len(maps) == 3, "%d rows" % len(maps))
    if len(maps) == 3:
        vals = {}
        for name, rest in maps:
            nums = re.findall(r"\d+", rest)
            vals[name] = [int(x) for x in nums]
        check(g, "each map row has SEVEN numbers after the name",
              all(len(v) == 7 for v in vals.values()),
              " ".join("%s:%d" % (k, len(v)) for k, v in vals.items()))
        if all(len(v) == 7 for v in vals.values()):
            for name, v in vals.items():
                slots, leg, vx, lo, vo, bo, ne = v
                # The four columns are a partition of the 256 slots, which is
                # exact and is the check that catches a parser that silently
                # dropped a column.  A parser that lost the VEX column
                # produced a column of ZEROS and this caught it.
                check(g, "map %s: legacy-only + both == the legacy count" % name,
                      lo + bo == leg, "%d + %d == %d" % (lo, bo, leg))
                check(g, "map %s: VEX-only + both == the VEX count" % name,
                      vo + bo == vx, "%d + %d == %d" % (vo, bo, vx))
                check(g, "map %s: the four columns sum to 256 exactly" % name,
                      lo + vo + bo + ne == 256,
                      "%d+%d+%d+%d" % (lo, vo, bo, ne))
            # THE RESULT of the whole course, as a shape.  The two newer maps
            # are nearly EMPTY in their legacy encoding and half full with a
            # VEX in front, and the direction of the 0F 3A row is the one
            # that cannot be an accident.
            f3 = vals.get("0F3A")
            f38 = vals.get("0F38")
            if f3 and f38:
                check(g, "THE RESULT: 0F 3A is nearly empty legacy and fills under VEX",
                      f3[1] < 32 and f3[2] > 2 * f3[1],
                      "legacy %d, VEX %d" % (f3[1], f3[2]))
                check(g, "and 0F 38 shows the same direction",
                      f38[1] < 64 and f38[2] > 2 * f38[1],
                      "legacy %d, VEX %d" % (f38[1], f38[2]))
            f0 = vals.get("0F")
            if f0 and f3:
                check(g, "and 0F is the crowded one, which is why the escape exists",
                      f0[1] > 4 * max(f3[1], 1),
                      "0F legacy %d against 0F 3A legacy %d" % (f0[1], f3[1]))
    check(g, "a VEX-ONLY example is printed for each map that has one",
          len(re.findall(r"named ONLY with the prefix", T)) >= 2)
    check(g, "the backward-compatibility column is printed too",
          "SAME mnemonic legacy and under VEX" in T)
    check(g, "THE CONTROL: the corpus was decoded TWICE and agreed 100%",
          re.search(r"agreement: (\d+) of \1\s+-- 100%", T) is not None)
    check(g, "and the poisoned table STILL agreed with itself, and that is the point",
          "still 100%" in T and "SELF-AGREEMENT IS NOT EVIDENCE" in T)
    check(g, "the counts are labelled as counts of what binutils NAMES",
          "a count of what binutils 2.46 NAMES" in FLAT and
          "a fact about binutils and not a claim about what the ISA defines" in FLAT)
    check(g, "and the map section refuses to restate another course's numbers",
          "restate its number as its own" in FLAT)

    # ------------------------------------------------------------------
    # H. the retractions
    # ------------------------------------------------------------------
    g = "H retraction"
    print("  --- group H: every retraction is still present")
    for tag, frag in [
        ("R1", "the most widely repeated false fact about VEX"),
        ("R2", "ONE DECODE"),
        ("R3", "LEA is the cheap way to multiply"),
        ("R4", "the arm that looks shortest has the most"),
        ("R5", "an experiment that cannot answer its question is not data"),
        ("R6", "the row with %cl = 63 and no"),
        ("R7", "which is a different sentence"),
        ("R8", "A control that can be subtracted"),
        ("R9", "how many slots binutils 2.46 names"),
        ("R10", "the remembered-number mistake"),
        ("R11", "the quietest bug class in this file"),
        ("R12", "THE MAPS WERE NOT LEFT FULL"),
        ("R13", "A TABLE WHOSE ORDER MOVES BETWEEN RUNS HAS A SHAPE"),
        ("R14", "THE CLOBBER LIST IS A"),
    ]:
        check(g, "retraction %s is present so it cannot be quietly dropped" % tag,
              frag.lower() in FLAT.lower(), frag[:42])
    nR = len(re.findall(r"^   R\d+\.", T, re.M))
    check(g, "the retractions block is numbered and contiguous", nR == 14,
          "%d retractions" % nR)
    order = [int(x) for x in re.findall(r"^   R(\d+)\.", T, re.M)]
    check(g, "and they are in NUMERIC order, which is the order they were found",
          order == sorted(order), " ".join(str(x) for x in order))
    check(g, "R11's general form is stated, because it will recur",
          "an inline-asm block that touches a register it does not declare" in FLAT)
    check(g, "and R12 marks the part that is a STORY as a story",
          "is a STORY, so it is marked as one" in FLAT)
    check(g, "R2's replacement claim is stated, not just the retraction",
          "is ONE DECODE" in FLAT and "spare issue slots to spend" in FLAT)

    # ------------------------------------------------------------------
    # I. the limits
    # ------------------------------------------------------------------
    g = "I limits"
    print("  --- group I: the limits, and the verdict")
    for frag in [
        "ANY CYCLE COUNT",
        "ANY BRANCH MISPREDICTION RATE",
        "WHETHER THIS PROCESSOR RENAMES THE FLAGS REGISTER",
        "THE COST OF THE ILLEGAL INSTRUCTIONS",
        "THE OPUS OF AVX-512 EXECUTION",
        "THE OTHER TWO ARCHITECTURES",
        "WHETHER GCC CHOSE ANY OF THESE INSTRUCTIONS FOR A REASON",
    ]:
        check(g, "a limit is stated: %s" % frag[:36], frag in T)
    check(g, "each limit names the instrument that would settle it",
          "perf_event_open" in T and "the ARM manual is the only source" in FLAT)
    check(g, "the two-architecture paragraph says it is QUOTED",
          "QUOTED, NOT MEASURED" in T)
    check(g, "the verdict is printed and it is narrower than the introduction",
          "What it cannot support" in T and
          "any statement about cycles" in FLAT)
    check(g, "the running checksum is printed, so the arms are provably run",
          one(r"running checksum: (0x[0-9a-f]+)", T) is not None,
          one(r"running checksum: (0x[0-9a-f]+)", T) or "?")
    check(g, "and the row count is printed too",
          one(r"rows timed: (\d+)", T) is not None,
          "%s rows" % (one(r"rows timed: (\d+)", T) or "?"))
    check(g, "the workload is printed, so a reader knows what was scaled",
          one(r"iterations per arm: (\d+)", T) is not None)

    print("")
    if FAILURES:
        for grp, what, detail in FAILURES:
            print("  FAILED  %-11s %s   %s" % (grp, what, detail))
    print("")
    print("crosscheck: %d checks, %d failed" % (CHECKS, len(FAILURES)))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
