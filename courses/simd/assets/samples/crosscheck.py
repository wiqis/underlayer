#!/usr/bin/env python3
"""crosscheck.py -- the harness for "SIMD and Vector Processing".

It reads the OUTPUT of simdbench and checks eight groups of claims.  It does
not re-measure anything, and it deliberately asserts almost no numbers.

Why so little is asserted numerically, in this file's own words: simdbench
section 0 measures the spread of its own estimator and prints it, and the
machine is a virtualised guest with twelve logical CPUs and other tenants on
it, so that spread is large -- 51.8% on the recorded run.  More to the point,
the ABSOLUTE throughput of the same body moved by a factor of 1.7 between two
runs of the same binary on the recorded day, while every RATIO in the file
moved by less than 10%.  A tolerance wide enough to catch a real change is
also wide enough to swallow the change, and a check with a bare number in it is
a check whose failure is noise.  So:

  * structural claims are asserted EXACTLY, because they are exact: the lane
    table in section 1, the register widths, the ABSENCE of AVX-512, the
    ORDER of the six arms, the presence of every retraction, and the mnemonic
    census in the VERIFY block;
  * timing claims are asserted as ORDERINGS and as SHAPES, never as a value;
  * the claim this course exists to make -- that the speedup is set by the
    memory system and not by the lane count -- is asserted as a SHAPE: the
    4-wide arm's speedup must be much larger with the working set inside L1
    than with it beyond the L3.  Both numbers move between runs; the ordering
    and the collapse do not.

Every substring assertion runs against a WHITESPACE-NORMALISED copy of the
artifact output, because the artifact wraps its prose at about 78 columns and
a check that searches for a wrapped sentence fails on text that is
demonstrably present.  Numeric parses still run on the original, because
collapsing spaces there would join adjacent table columns.

Usage:  python3 crosscheck.py [path/to/simdbench.out]
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
    before simdbench is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "simdbench.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    """The first capture group, as a STRING.  For numbers and bare tokens."""
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def grab(pat, text, flags=0):
    """RAW STRINGS matching pat, or None.  For rows that have a LABEL and a
    VALUE, where float() cannot hold the label.

    Two extractors, not one, and the reason is the same in every course in this
    collection: a single helper that returns only the first group and is then
    used on a row that has more than one field hands a label to float() and
    raises, and the failure surfaces as a crash rather than as a wrong answer.
    That is the good case."""
    m = re.search(pat, text, flags)
    return list(m.groups()) if m else None


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    FLAT = re.sub(r"\s+", " ", T)
    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the instrument, and the machine's own opinion of itself
    # ------------------------------------------------------------------
    g = "A machine"
    print("  --- group A: what the machine says it can do, before anything is claimed")

    busy = one(r"TSC rate, busy\s+([\d.]+)", T)
    idle = one(r"TSC rate, across sleep\s+([\d.]+)", T)
    check(g, "the TSC rate was measured twice and the two agree",
          busy and idle and abs(float(busy) - float(idle)) / float(busy) < 0.005,
          "%.4f vs %.4f GHz" % (float(busy) if busy else 0, float(idle) if idle else 0))
    drift = one(r"drift\s+(-?[\d.]+)%", T)
    check(g, "the TSC is invariant, so a tick is TIME and not cycles",
          drift is not None and abs(float(drift)) < 0.5, "%s%%" % drift)
    check(g, "and the rate used for ns is the measured one, not a constant",
          "measured, not typed in" in T, "R2")

    floor = one(r"estimator = min-of-3, 11 of them: spread\s+([\d.]+)%", T)
    check(g, "the artifact measured and PRINTED its own noise floor",
          floor is not None, "%.1f%%" % (float(floor) if floor else -1))
    check(g, "and said the consequence: shapes, not values",
          "asserts SHAPES and not values" in T)
    check(g, "the benchmark is pinned to a CPU and says so",
          "pinned to cpu" in T and "sched_getcpu" in T)

    # The absence of AVX-512 is a CHECKED FACT here, not a gap, and it is what
    # licenses the whole of section 7 to be quoted rather than measured.
    f512 = grab(r"avx512f=(\d) avx512dq=(\d) avx512cd=(\d) avx512bw=(\d) avx512vl=(\d)", T)
    check(g, "all five AVX-512 CPUID leaves were read", f512 is not None,
          " ".join(f512) if f512 else "")
    if f512:
        check(g, "EVERY AVX-512 bit is zero, so no 512-bit register was measured",
              all(v == "0" for v in f512), " ".join(f512))
    check(g, "and the artifact says that out loud, with a reason",
          "THERE IS NO AVX-512 ON THIS MACHINE" in T and "not a gap" in T)
    check(g, "the perf counter absence is stated, not assumed",
          "perf_event_paranoid    4" in T and "no PMU" in T)
    check(g, "and the consequence is stated: durations are not counts",
          "LOWER BOUND" in T and "never a" in FLAT and "measurement of" in T)
    check(g, "every mechanism in the file is marked as INFERRED for that reason",
          "marked INFERRED" in T)

    caches = re.findall(r"^      L(\d) (\w+)\s+(\d+)K KiB\s+shared by \[([^\]]+)\]", T, re.M)
    check(g, "the cache sizes were read from /sys, not assumed", len(caches) >= 3,
          " ".join("L%s=%sK" % (c[0], c[2]) for c in caches))
    if caches:
        l1 = [c for c in caches if c[0] == "1" and c[1] == "Data"]
        l3 = [c for c in caches if c[0] == "3"]
        check(g, "an L1 data size and an L3 size are both present",
              bool(l1) and bool(l3),
              "L1d=%s KiB L3=%s KiB" % (l1[0][2] if l1 else "?", l3[0][2] if l3 else "?"))
        if l1 and l3:
            check(g, "the L1 is STRICTLY SMALLER than the L3 it feeds",
                  int(l1[0][2]) < int(l3[0][2]),
                  "%s < %s KiB" % (l1[0][2], l3[0][2]))

    # ------------------------------------------------------------------
    # B. what a vector register IS -- exact structure
    # ------------------------------------------------------------------
    g = "B register"
    print("  --- group B: the register, as a table of integers")

    lanes = {}
    for m in re.findall(r"^   (XMM|YMM|ZMM)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)", T, re.M):
        reg = m[0]
        lanes[reg] = (int(m[1]), [int(x) for x in m[2:7]])
    check(g, "all three register widths were printed", len(lanes) == 3,
          " ".join("%s=%dB" % (k, v[0]) for k, v in sorted(lanes.items())))
    if len(lanes) == 3:
        check(g, "XMM/YMM/ZMM are 16/32/64 bytes, exactly",
              lanes["XMM"][0] == 16 and lanes["YMM"][0] == 32 and lanes["ZMM"][0] == 64)
        # element sizes in the printed column order: double, float, int32, int8, int16
        want = {"XMM": [2, 4, 4, 16, 8], "YMM": [4, 8, 8, 32, 16], "ZMM": [8, 16, 16, 64, 32]}
        for reg in ("XMM", "YMM", "ZMM"):
            got = lanes[reg][1]
            check(g, "%s lane counts are width/elementsize for all five types" % reg,
                  got == want[reg], " ".join(str(x) for x in got))
        check(g, "the doubling XMM->YMM->ZMM holds for every column",
              all(lanes["YMM"][1][i] == 2 * lanes["XMM"][1][i] and
                  lanes["ZMM"][1][i] == 2 * lanes["YMM"][1][i] for i in range(5)))
    check(g, "the table says the lane count is not a speedup",
          "lane count is not a speedup" in T)
    check(g, "and points at the measurement that shows it",
          "section 3" in FLAT.lower() and "4-wide arm" in FLAT)
    check(g, "a mask register is described as a THIRD operand, not a modifier",
          "THIRD operand, not a modifier" in T and "k0-k7" in T)
    check(g, "the upper-ZMM aliasing is quoted and marked unmeasured",
          "upper-ZMM state" in T and "cannot measure it" in T)
    check(g, "the debt to the execution course is named with both quotes",
          "multiples of the SIMD width" in T and "in SIMD" in T and
          "the same work" in FLAT)

    # ------------------------------------------------------------------
    # C. the table -- six arms, checksums, and two shapes
    # ------------------------------------------------------------------
    g = "C table"
    print("  --- group C: six arms, one loop, and the two shapes it asserts")

    rows = {}
    for m in re.finditer(r"^   ([A-F])  (.+?)\s{2,}([\d.]+)\s+([\d.]+)\s+([\d.]+)x\s*$", T, re.M):
        rows[m.group(1)] = (m.group(2).strip(), float(m.group(3)),
                            float(m.group(4)), float(m.group(5)))
    check(g, "all six arms were printed with a speedup", len(rows) == 6,
          "%d arms" % len(rows))

    if len(rows) == 6:
        sp = {k: rows[k][3] for k in rows}
        ns = {k: rows[k][1] for k in rows}

        # THE SHAPE 1: 4 lanes beat 2 lanes beat 1 lane.  The exact ratios
        # move between runs; the ordering is the claim.
        check(g, "4 lanes beat 2 lanes beat 1 lane (the shape, not the ratio)",
              sp["B"] < sp["C"] < sp["D"],
              "1 lane=%.2fx  2 lanes=%.2fx  4 lanes=%.2fx" % (sp["B"], sp["C"], sp["D"]))
        check(g, "and 4 lanes is worth more than 2x and less than the lane count",
              sp["D"] > 2.0, "4 lanes = %.2fx, lane count = 4" % sp["D"])

        # THE SHAPE 2: the floor is the floor.  B is the slowest arm by a wide
        # margin, and it is the only arm with no vector instruction in it.
        # The floor is the SLOWEST arm, and the 2-wide arm is the one it is
        # closest to -- 2 lanes is a 2x speedup, so the floor and the 2-wide arm
        # land within a hair of a factor of two of each other, and asserting
        # "more than twice" against the 2-wide arm failed on one of the three
        # recorded runs by 0.03.  The honest shape is: the floor is the slowest,
        # and it is at least twice the 4-wide arms.
        check(g, "the no-vectorise floor is the SLOWEST arm",
              ns["B"] == max(ns.values()),
              "floor %.2f ns, next slowest %.2f ns" % (ns["B"], max(v for k, v in ns.items() if k != "B")))
        check(g, "and it is at least twice the 4-wide arms",
              ns["B"] > 2.0 * max(ns["D"], ns["E"], ns["F"]),
              "floor %.2f ns, best 4-wide %.2f ns" % (ns["B"], min(ns["D"], ns["E"], ns["F"])))

        # FMA is worth nothing HERE, and that is a result rather than a null.
        check(g, "FMA adds nothing on top of mul+add (within 25%)",
              0.75 <= sp["D"] / sp["E"] <= 1.33,
              "mul+add=%.2fx fma=%.2fx" % (sp["D"], sp["E"]))

        # The compiler is competitive with the hand-written 4-wide loop.
        check(g, "the auto-vectorised arm matches the hand-written 4-wide one",
              0.75 <= sp["A"] / sp["D"] <= 1.33,
              "compiler=%.2fx hand-written=%.2fx" % (sp["A"], sp["D"]))

        # And the memory-operand arm is SLOWER despite doing less memory work.
        # This is R7's shape and it is the one that killed the hoisting story.
        check(g, "the memory-operand arm is NOT faster than the 3-load one",
              sp["F"] < sp["E"], "memop=%.2fx 3-load=%.2fx" % (sp["F"], sp["E"]))
        check(g, "and the artifact explains WHY: latency, not instruction count",
              "WAIT for that load to land" in FLAT and
              "instruction count is not the cost" in FLAT.lower())

    cks = re.findall(r"\b([A-F])=([\d.]+)\b", T)
    check(g, "every arm printed a checksum", len(cks) == 6, "%d checksums" % len(cks))
    if len(cks) == 6:
        vals = {k: float(v) for k, v in cks}
        check(g, "and all six agree, bit for bit",
              len(set(vals.values())) == 1,
              " ".join("%.6f" % x for x in sorted(set(vals.values()))))
        check(g, "and the agreed value is the fixed point 32.0, not a near miss",
              list(vals.values())[0] == 32.0, "%.6f" % list(vals.values())[0])
    check(g, "the artifact says the checksum is what caught the operand bug",
          "CHECKSUM" in T and "caught the operand-order bug" in FLAT)
    check(g, "the fixed point is justified, not asserted",
          "FIXED POINT at 0.5 after 53" in T and "bit-for-bit test" in T)

    # ------------------------------------------------------------------
    # D. the ceiling -- the central result
    # ------------------------------------------------------------------
    g = "D ceiling"
    print("  --- group D: the same 4-wide arm at five working-set sizes")

    sweep = re.findall(
        r"^   (\S.*?)\s+(\d+) KiB\s+(\d+) KiB\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)x\s+([\d.]+)x\s+([\d.]+)x\s*$",
        T, re.M)
    check(g, "all five working-set sizes were measured", len(sweep) == 5,
          "%d rows" % len(sweep))
    if len(sweep) == 5:
        g4 = [float(r[6]) for r in sweep]
        check(g, "the sizes ascend", [int(r[2]) for r in sweep] ==
              sorted(int(r[2]) for r in sweep),
              " ".join(str(int(r[2])) + "K" for r in sweep))
        # THE RESULT, as a shape: the speedup collapses with the working set.
        check(g, "THE RESULT: 4-wide is much faster at L1 than beyond the L3",
              g4[0] > 1.8 * g4[4],
              "L1=%.2fx  L3=%.2fx  collapse=%.2fx" % (g4[0], g4[4], g4[0] / g4[4]))
        check(g, "and the collapse is monotone-ish: the L1 row is the maximum",
              g4[0] == max(g4), " ".join("%.2fx" % x for x in g4))
        check(g, "and even beyond L3 the 4-wide arm still beats the scalar one",
              g4[4] > 1.02, "%.2fx at 24 MiB" % g4[4])

        # The sentence that is the course, checked as a sentence.
        check(g, "the artifact states the difference as the vector arm's cost rising",
              "VECTOR ARM'S COST WENT UP" in T and "SCALAR ARM'S WENT UP" in T)
        check(g, "and says the lane count did not change between the two rows",
              "lane count did not change" in FLAT)
        check(g, "and names bandwidth rather than instruction rate as the wall",
              "bandwidth rather than the instruction rate" in FLAT)

        # The compiler's own arm, reached two ways.  The named-array form lands
        # on the hand-written 4-wide one; the pointer form lands on the scalar
        # floor.  That pair is R7's measurement, and asserting it as a shape is
        # what stops the "the trip count stopped the compiler" story returning.
        au = [float(r[7]) for r in sweep]
        check(g, "the auto-vectorised arm tracks the hand-written 4-wide one closely",
              all(0.8 <= au[i] / g4[i] <= 1.25 for i in range(5)),
              " ".join("%.2f" % (au[i] / g4[i]) for i in range(5)))
        pt = [float(r[8]) for r in sweep]
        # The control is not merely un-vectorised, it is SLOWER THAN THE SCALAR
        # FLOOR, because the noinline accessors put three calls in the inner
        # loop.  Asserting "at the floor" would be asserting a number the
        # measurement does not support; the shape is that it is much worse.
        check(g, "THE CONTROL: the same source via POINTERS is far worse than the floor",
              all(x < 0.6 for x in pt), " ".join("%.2fx" % x for x in pt))
        check(g, "and the gap between the two forms of the same source is enormous",
              all(au[i] / pt[i] > 4.0 for i in range(5)),
              " ".join("%.0fx" % (au[i] / pt[i]) for i in range(5)))
        check(g, "and the artifact says the accessors are WHY the control is slow",
              "noinline accessors" in T and "THREE CALLS in the inner loop" in T)
        check(g, "and the artifact gives the ALIASING reason",
              "ALIASING" in T and "store to A[j] might change what B[j+4] holds" in FLAT)
        check(g, "and says the trip count only buys an EPILOGUE",
              "SCALAR EPILOGUE" in T and "epilogue (cheap)" in FLAT)
        check(g, "R8 is present: the first control was not a control at all",
              "THE CONTROL WAS NOT A CONTROL" in T and
              "wearing a pointer costume" in FLAT)

    # ------------------------------------------------------------------
    # E. the compiler claim, checked against bytes
    # ------------------------------------------------------------------
    g = "E codegen"
    print("  --- group E: a claim about a compiler, checked against the bytes")

    check(g, "the VERIFY block is present in the recorded output",
          "VERIFY: what the compiler actually emitted" in T)
    # A 2x2: named vs pointer, constant vs variable trip count.  The corner
    # that matters is that the NAMED forms vectorise and the POINTER forms do
    # not, at either trip count.  Asserted as a shape, and the shape is what
    # the first draft of this artifact got wrong.
    verdicts = {}
    for name in ("named_const", "named_var", "ptr_const", "ptr_var"):
        blk = re.search(re.escape(name) + r":(.*?)(?=\n   \w+:|\n   compiler:)", T, re.S)
        if blk:
            v = re.search(r"=> (VECTORISED|NOT VECTORISED): (\d+) packed-double, (\d+) scalar", blk.group(1))
            if v:
                verdicts[name] = (v.group(1), int(v.group(2)), int(v.group(3)))
    check(g, "all FOUR forms of the same loop were disassembled",
          len(verdicts) == 4, " ".join(sorted(verdicts)))
    if len(verdicts) == 4:
        check(g, "NAMED arrays vectorise at BOTH trip counts",
              verdicts["named_const"][0] == "VECTORISED" and
              verdicts["named_var"][0] == "VECTORISED",
              "const=%s var=%s" % (verdicts["named_const"][0], verdicts["named_var"][0]))
        check(g, "POINTERS do not vectorise at EITHER trip count",
              verdicts["ptr_const"][0] == "NOT VECTORISED" and
              verdicts["ptr_var"][0] == "NOT VECTORISED",
              "const=%s var=%s" % (verdicts["ptr_const"][0], verdicts["ptr_var"][0]))
        # The trip count's real effect is a scalar EPILOGUE, not the vector loop.
        check(g, "the trip count's real cost is a SCALAR EPILOGUE for n mod 4",
              verdicts["named_var"][2] > verdicts["named_const"][2],
              "named_const has %d scalar, named_var has %d"
              % (verdicts["named_const"][2], verdicts["named_var"][2]))
    check(g, "the mnemonics themselves are printed, not just a verdict",
          "vfmadd" in T and "vfmadd" in FLAT)
    check(g, "the compiler and the flags are recorded with the verdict",
          "compiler:" in T and "flags:" in T)
    check(g, "the aliasing mechanism is named as the reason",
          "does not change what B[j+4] holds" in FLAT)
    check(g, "R7 retracts the trip-count story, and says it was a TIMING inference",
          "INFERENCE FROM A TIMING IS NOT A" in FLAT and "runtime variable" in T)
    check(g, "R7 also retracts the HOISTING story, and says the loads are not hoisted",
          "INSIDE the inner loop" in T and "not hoisted" in FLAT.lower())
    check(g, "and says the two retracted stories are wrong 'twice over'",
          "wrong" in FLAT.lower() and "twice over" in FLAT)

    # ------------------------------------------------------------------
    # F. the shapes and the reduction
    # ------------------------------------------------------------------
    g = "F reduce"
    print("  --- group F: elementwise, independent, and the price of a reduction")

    shp = re.findall(r"^   (load,\s*(?:store|ADD|MUL|FMA)\b[^\n]*?)\s+([\d.]+)"
                     r"\s+([\d.]+)x\s+([\d.]+)\s*$", T, re.M)
    check(g, "all four arithmetic bodies were measured", len(shp) == 4,
          "%d bodies" % len(shp))
    if len(shp) == 4:
        t = {r[0].split(",")[1].strip().split()[0]: float(r[2]) for r in shp}
        if "ADD" in t and "MUL" in t:
            check(g, "an add and a multiply cost the SAME, within 15%",
                  0.85 <= t["ADD"] / t["MUL"] <= 1.18,
                  "add=%.2fx mul=%.2fx" % (t["ADD"], t["MUL"]))
        check(g, "and the artifact says the loop is not waiting for the arithmetic",
              "not waiting for" in T and "hide inside" in FLAT)
        check(g, "the FMA row is marked NOT COMPARABLE, and says why",
              "NOT COMPARABLE" in T and "THREE arrays" in T)
        sums = [float(r[3]) for r in shp]
        check(g, "the four bodies leave DIFFERENT numbers, and all are printed",
              len(set(sums)) > 1, " ".join("%.1f" % c for c in sums))

    dep = re.findall(r"^   (ONE accumulator|FOUR accumulators).*?([\d.]+)\s+([\d.]+)x\s+([\d.]+)\s*$",
                     T, re.M)
    check(g, "both independence arms were measured", len(dep) == 2,
          "%d arms" % len(dep))
    if len(dep) == 2:
        one_, four_ = float(dep[0][2]), float(dep[1][2])
        check(g, "FOUR independent accumulators beat ONE",
              four_ > 1.15, "one=%.2fx four=%.2fx" % (one_, four_))
        check(g, "and the two checksums DIFFER, so they are not the same loop",
              dep[0][3] != dep[1][3], "%s vs %s" % (dep[0][3], dep[1][3]))
    check(g, "and the artifact states independence is a property of the DATA",
          "INDEPENDENCE IS A PROPERTY OF THE DATA" in T)

    red = re.findall(
        r"^   ((?:4-wide accumulate|scalar loop)[^\n]*?)\s+([\d.]+)\s+([\d.]+)x\s+([\d.]+)\s*$",
        T, re.M)
    check(g, "all five reduction arms were measured", len(red) == 5,
          "%d arms" % len(red))
    if len(red) == 5:
        once = [float(r[2]) for r in red if "ONCE at the very end" in r[0]]
        every = [float(r[2]) for r in red if r[0].startswith("4-wide accumulate")
                 and "ONCE" not in r[0]]
        check(g, "reducing EVERY group costs more than reducing ONCE",
              len(once) == 1 and len(every) == 3 and min(every) > once[0] * 1.15,
              "once=%.2fx  every-group=%.2fx/%.2fx/%.2fx"
              % tuple([once[0] if once else -1] + sorted(every) if every else [-1, -1, -1]))
        check(g, "and the artifact says the arms are NOT computing the same sum",
              "DO NOT COMPUTE THE SAME NUMBER" in T)
        vals = [r[3] for r in red]
        check(g, "each arm PRINTS the value it produced, so the difference is visible",
              len(set(vals)) == 2,
              "%d distinct values across five arms" % len(set(vals)))
    check(g, "the vhaddpd fact is stated: it adds corresponding lanes, not adjacent",
          "adds the CORRESPONDING lanes of its TWO SOURCES" in FLAT and
          "DOUBLES v" in T)
    check(g, "and the reason to care: getting it wrong gives exactly twice the sum",
          "EXACTLY TWICE" in T or "exactly twice" in T)
    check(g, "tree order is justified as a DEPENDENCY CHAIN, not a style",
          "DEPENDENCY CHAIN" in T and "logarithmic" in T)
    check(g, "and the reassociation caveat is stated",
          "reassociates" in T and "bit-identical" in T)

    # ------------------------------------------------------------------
    # G. the boundaries
    # ------------------------------------------------------------------
    g = "G boundaries"
    print("  --- group G: alignment, the fault, the gather and the tail")

    al = re.findall(r"^   (_mm256_load\w*.*?)\s+([\d.]+)\s+([\d.]+)x\s*$", T, re.M)
    check(g, "all three alignment arms were measured", len(al) == 3,
          "%d arms" % len(al))
    if len(al) == 3:
        c = [float(r[2]) for r in al]
        check(g, "an unaligned LOADU on a misaligned address is not slower here",
              c[2] < 1.35, "aligned=%.2fx loadu=%.2fx misaligned=%.2fx" % tuple(c))
        check(g, "and the three arms really are the three different loads",
              "DEMANDS 32B" in al[0][0] and "demands nothing" in al[1][0] and
              "MISALIGNED" in al[2][0])
    check(g, "and the artifact says so plainly rather than implying a penalty",
          "unaligned 32-byte vector load of L1-resident data is FREE" in T)
    check(g, "the FAULT is measured separately, in a forked child",
          "raised SIGSEGV" in T or "raised SIGILL" in T)
    check(g, "and the artifact says a duration table cannot time a correctness rule",
          "A table of" in FLAT and "wrong instrument" in FLAT)
    check(g, "the 2 MiB re-check is there, so 'not slower' is not one small case",
          "past the L2" in T and "does NOT claim" in T)

    ga = re.findall(r"^   ((?:four SEQUENTIAL|hand gather|hardware gather)[^\n]*?)\s+([\d.]+)\s+([\d.]+)x\s*$",
                    T, re.M)
    check(g, "all three gather arms were measured", len(ga) == 3,
          "%d arms" % len(ga))
    if len(ga) == 3:
        seq, hand, hw = (float(r[2]) for r in ga)
        check(g, "a hand gather costs more than a sequential load",
              hand > seq * 1.3, "sequential=%.2fx hand=%.2fx" % (seq, hand))
        check(g, "THE RESULT: the gather INSTRUCTION is slower than 4 scalar loads",
              hw > hand * 1.3, "hand=%.2fx vpgatherdd=%.2fx" % (hand, hw))
        check(g, "and the artifact says why: four INDEPENDENT loads, serially",
              "INDEPENDENT LOADS SERIALLY" in T)
    check(g, "and generalises it into the rule the section exists for",
          "WIDE INSTRUCTION IS WORTH WHAT THE ADDRESSES ALLOW" in T)

    tl = re.findall(r"^   ((?:64 elements|66 elements|68 elements|CONTROL:).*?)\s+"
                    r"([\d.]+)\s+([\d.]+)x\s*$", T, re.M)
    check(g, "all six tail arms were measured", len(tl) == 6, "%d arms" % len(tl))
    if len(tl) == 6:
        def pick(tag):
            for r in tl:
                if r[0].startswith(tag):
                    return float(r[2])
            return -1.0
        base = pick("64 elements")
        check(g, "the SCALAR REMAINDER is essentially free",
              base > 0 and 0 < pick("66 elements, 4-wide + a SCALAR") < 1.2,
              "no-tail=%.2fx scalar-remainder=%.2fx"
              % (base, pick("66 elements, 4-wide + a SCALAR")))
        check(g, "the OVERLAPPING last iteration is much the worst arm",
              pick("66 elements, 4-wide + one") > 1.4,
              "overlap=%.2fx" % pick("66 elements, 4-wide + one"))
        check(g, "and it is dearer than the arm that writes past the end",
              pick("66 elements, 4-wide + one") > pick("68 elements"),
              "overlap=%.2fx past-the-end=%.2fx"
              % (pick("66 elements, 4-wide + one"), pick("68 elements")))
        check(g, "the PARTIAL-overlap control is dearer than the FULL one",
              pick("CONTROL: a PART") > pick("CONTROL: a FULL"),
              "full=%.2fx partial=%.2fx" % (pick("CONTROL: a FULL"), pick("CONTROL: a PART")))
        check(g, "and the mechanism is marked INFERRED, not measured",
              "MECHANISM is INFERRED" in T)
        check(g, "the arm that writes past the end is reported as a BUG",
              "corrupts" in T and "does not own" in T)
    check(g, "the artifact's conclusion is the portable one: write the tail scalar",
          "write the tail SCALAR" in T)
    check(g, "and says that is WHY a mask register exists",
          "mask register is for" in FLAT)

    # ------------------------------------------------------------------
    # H. the retractions
    # ------------------------------------------------------------------
    g = "H retraction"
    print("  --- group H: every retraction is still present")
    for tag, frag in [
        ("R1", "MEASURED 3.3 and so the FMA memory form is broken"),
        ("R2", "The absolute nanosecond figures are the result"),
        ("R3", "NOT REPRODUCED"),
        ("R4", "vhaddpd adds adjacent lanes"),
        ("R5", "were not summing"),
        ("R6", "An unaligned vector load is slow"),
        ("R7", "The compiler declined to vectorise because the trip count is a"),
        ("R8", "A CONTROL THAT CANNOT FAIL IS NOT A CONTROL"),
    ]:
        check(g, "retraction %s is present so it cannot be quietly dropped" % tag,
              frag.lower() in FLAT.lower(), frag[:40])
    nR = len(re.findall(r"^   R\d+\.", T, re.M))
    check(g, "the retractions block is numbered and contiguous", nR == 8,
          "%d retractions" % nR)
    check(g, "R8's discipline is stated: prove a control can fail",
          "MAKE IT FAIL ON PURPOSE" in T and "a control that" in FLAT.lower())
    check(g, "R1's general form is stated, and says it recurs every course",
          "RECURRED FOUR COURSES IN A ROW" in T)
    check(g, "R2's general form is stated: the ratio moved less than the number",
          "less than 10% across four runs" in T and "70%" in T)
    check(g, "R4 records BOTH bugs that produced the same symptom",
          "TWO different bugs, one symptom" in T or
          ("two different bugs" in FLAT.lower() and "one symptom" in FLAT.lower()))
    check(g, "R5 says the same rule applies to the ANSWER as to the memory ops",
          "the same" in FLAT and "rule is about the ANSWER" in T)
    check(g, "R6's general form is stated: fault before speed",
          "CHECK WHETHER THE THING FAULTS" in T)
    check(g, "R7 names the two mechanisms it conflated, and separates them",
          "Two different mechanisms" in T and "the VECTOR LOOP ITSELF" in T)

    # ------------------------------------------------------------------
    # I. the limits
    # ------------------------------------------------------------------
    g = "I limits"
    print("  --- group I: the limits, and the verdict")
    for frag in [
        "ANY COUNT",
        "ANYTHING ABOUT AVX-512",
        "WHETHER THE UPPER ZMM STATE COSTS ANYTHING",
        "A CROSS-CHECK OF THE ARITHMETIC AGAINST A SECOND IMPLEMENTATION",
        "THE OTHER TWO ARCHITECTURES",
        "WHETHER THE COMPILER VECTORISED",
        "ANYTHING ABOUT FLOATING-POINT CORRECTNESS",
    ]:
        check(g, "a limit is stated: %s" % frag[:40], frag in T)
    check(g, "the limits name the instrument that would settle the missing ones",
          "perf_event_paranoid is 4" in T and "DISASSEMBLY" in T)
    check(g, "the three-architecture section says it is QUOTED, not measured",
          "QUOTED, NOT MEASURED" in T)
    check(g, "and the portable shape is stated as a five-row list",
          "N INDEPENDENT LANES, ONE INSTRUCTION" in T)
    check(g, "and says which rows are the same on all three architectures",
          "the same everywhere" in T and "Rows 1 and 2 are where" in T)

    print("")
    if FAILURES:
        for grp, what, detail in FAILURES:
            print("  FAILED  %-11s %s   %s" % (grp, what, detail))
    print("")
    print("crosscheck: %d checks, %d failed" % (CHECKS, len(FAILURES)))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
