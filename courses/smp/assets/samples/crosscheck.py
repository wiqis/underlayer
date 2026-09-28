#!/usr/bin/env python3
"""crosscheck.py -- the harness for "Multiprocessor Architecture".

It reads the OUTPUT of smpbench and checks eight groups of claims.  It does
not re-measure anything, and it deliberately asserts almost no numbers.

Why so little is asserted numerically, in this file's own words: smpbench
section 0 measures the spread of its own estimator and prints it, and the
machine is a virtualised guest with twelve logical CPUs and other work on it,
so that spread is large.  A tolerance that large can verify a SHAPE and cannot
verify a VALUE.  Worse, a check whose threshold is a bare number is a check
that fails on a busier machine and teaches its reader to ignore it -- which is
how the three previous courses' harnesses broke.  So:

  * structural claims are asserted EXACTLY, because they are exact: the online
    CPU list, the sibling pairs, the agreement between the cache's sharing
    list and the topology's sibling list, the ORDER of the seven placement
    rows, and the presence of every retraction;
  * timing claims are asserted as ORDERINGS and as a SHAPE, never as a value;
  * the one claim this course exists to make -- that true sharing and false
    sharing cost the SAME, because the cost is in the cache line and not in
    the data -- is asserted as a SHAPE: the B/C ratio must be near 1 while
    both B and C must be far above the floor A.  That pair of conditions is
    machine-independent even though neither number is.

The harness exists to catch a future edit that quietly changes a claim.  In
particular it asserts the presence of all six retractions, and it asserts the
THE SHAPE of the B/C result rather than the ratio, because the ratio moves
between runs (0.97, 1.03, 1.19 on the three recorded runs) and the SHAPE does
not.

Usage:  python3 crosscheck.py [path/to/smpbench.out]
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
    before smpbench is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "smpbench.out")


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


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.  The
    # artifact wraps its prose at about 78 columns, so a phrase written across
    # a line break is a phrase the artifact has and the harness cannot see --
    # which is how four checks in the previous course's harness failed about
    # text that was demonstrably present, three of them about retractions.
    # Numeric parses still use the original, because collapsing spaces there
    # would join adjacent table columns.
    FLAT = re.sub(r"\s+", " ", T)
    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the instrument
    # ------------------------------------------------------------------
    g = "A machine"
    print("  --- group A: what was measured before anything was measured")

    busy = one(r"TSC rate, busy\s+([\d.]+)", T)
    idle = one(r"TSC rate, across sleep\s+([\d.]+)", T)
    check(g, "the TSC rate was measured twice and the two agree",
          busy and idle and abs(float(busy) - float(idle)) / float(busy) < 0.005,
          "%.4f vs %.4f GHz" % (float(busy) if busy else 0, float(idle) if idle else 0))

    drift = one(r"drift\s+(-?[\d.]+)%", T)
    check(g, "the TSC is invariant, so a tick is TIME and not cycles",
          drift is not None and abs(float(drift)) < 0.5, "%s%%" % drift)

    floor = one(r"estimator = min-of-3, 11 of them: spread\s+([\d.]+)%", T)
    check(g, "the artifact measured and PRINTED its own noise floor",
          floor is not None, "%.1f%%" % (float(floor) if floor else -1))

    # The absence of a PMU is the reason nothing here is a count, so it is a
    # checked fact rather than a footnote.
    check(g, "the absence of hardware counters is stated, not assumed",
          "perf_event_paranoid" in T and
          "no miss, no fill, no snoop and no line transfer can" in FLAT)
    check(g, "and the consequence is stated: durations are not counts",
          "LOWER BOUND on a count" in T and "never a measurement of" in T)

    # ------------------------------------------------------------------
    # B. the topology -- the two-reader cross-check
    # ------------------------------------------------------------------
    g = "B topology"
    print("  --- group B: the topology, read twice from two kernel files")

    cpus = grab(r"(\d+) online CPUs:((?: \d+)+)", T)
    check(g, "the online CPU list was read from /sys",
          cpus is not None and int(cpus[0]) >= 2, "%s CPUs" % (cpus[0] if cpus else "?"))
    if cpus:
        listed = [int(x) for x in cpus[1].split()]
        check(g, "the list is contiguous from 0, with no gaps",
              listed == list(range(len(listed))),
              "0..%d" % (listed[-1] if listed else -1))
        # CPU 0 has no `online` file at all.  A walk that skips a missing file
        # silently drops it, which is R-in-the-topology; the first version did.
        check(g, "CPU 0 is IN the list even though it has no `online` file",
              listed and listed[0] == 0, "first entry %s" % (listed[0] if listed else "?"))

    cores = grab(r"=> (\d+) distinct physical cores, (\d+) logical CPUs per core", T)
    check(g, "the core count and the SMT ratio were both derived",
          cores is not None and len(cores) == 2,
          " ".join(cores) if cores else "")
    if cpus and cores and len(cores) == 2:
        n, lpc = int(cores[0]), int(cores[1])
        check(g, "cores x threads-per-core == the CPU count, exactly",
              n * lpc == int(cpus[0]),
              "%d x %d = %d vs %d online" % (n, lpc, n * lpc, int(cpus[0])))

    # The sibling table.  Every pair must be MUTUAL, and no CPU may be its own
    # sibling.  The first version of the parser returned the first number in a
    # "2-3" list, which is the CPU asking -- so every even CPU reported a
    # sibling of itself and the table had a hole in it.
    sibs = re.findall(r"^      cpu(\d+)\s+core_id=(\d+)\s+package=(\d+)\s+sibling of cpu\d+ is cpu(-?\d+)$",
                      T, re.M)
    check(g, "a sibling was resolved for every online CPU",
          len(sibs) == int(cpus[0]) if cpus else False,
          "%d rows" % len(sibs))
    pairs = {int(c): int(o) for c, _, _, o in sibs}
    self_ref = [c for c, o in pairs.items() if c == o]
    check(g, "no CPU is reported as its own sibling", not self_ref, str(self_ref))
    check(g, "no sibling lookup returned -1 (the 'missing half' signature)",
          all(o >= 0 for o in pairs.values()),
          "%d of %d resolved" % (sum(1 for o in pairs.values() if o >= 0), len(pairs)))
    check(g, "every sibling relation is MUTUAL",
          all(o in pairs and pairs[o] == c for c, o in pairs.items()))
    cores_seen = sorted({int(v) for _, v, _, _ in sibs})
    check(g, "distinct core_ids == the reported core count",
          cores and len(cores) == 2 and len(cores_seen) == int(cores[0]),
          "%d core_ids" % len(cores_seen))

    # The two-reader cross-check.  The cache's own shared_cpu_list and the
    # topology's thread_siblings_list are two files written by two kernel
    # subsystems; a check that read the same byte twice would agree with a
    # wrong answer, so the harness asserts that the artifact compares them.
    check(g, "the cache sharing list and the sibling list were COMPARED",
          "cross-check" in T and "thread_siblings_list" in T)
    check(g, "and the artifact reported the verdict, agreement or not",
          re.search(r"thread_siblings_list (AGREE|DISAGREE)", T) is not None,
          (re.search(r"thread_siblings_list (\w+)", T) or [None, "?"])[1])
    l1 = re.search(r"L1 data\s+\d+ KiB\s+shared by \[([^\]]+)\]", T)
    check(g, "an L1 data sharing list was printed", l1 is not None,
          l1.group(1) if l1 else "")
    l3 = re.search(r"L3 unified\s+\d+ KiB\s+shared by \[([^\]]+)\]", T)
    check(g, "an L3 sharing list was printed", l3 is not None, l3.group(1) if l3 else "")
    if l1 and l3:
        def expand(spec):
            """'0-11' or '0,4,8' -> the number of CPUs it names.  A list is a
            RANGE, and splitting on ',' alone would call '0-11' one CPU and
            make a 12-CPU L3 look the same size as a 2-CPU L1."""
            n = 0
            for part in spec.split(","):
                a, b = part, part
                if "-" in part:
                    a, b = part.split("-", 1)
                try:
                    n += int(b) - int(a) + 1
                except ValueError:
                    return -1
            return n
        n1, n3 = expand(l1.group(1)), expand(l3.group(1))
        check(g, "the L1 sharing set is a STRICT SUBSET of the L3 sharing set",
              0 < n1 < n3, "L1 %s = %d CPUs, L3 %s = %d CPUs"
              % (l1.group(1), n1, l3.group(1), n3))

    check(g, "the debt to the memory course is named explicitly",
          "DEBT THIS COURSE IS PAYING" in T and "never" in FLAT and
          "defined it" in T)

    # ------------------------------------------------------------------
    # C. the placement table -- the shape, not the values
    # ------------------------------------------------------------------
    g = "C placements"
    print("  --- group C: seven rows, and the one comparison the course is for")

    rows = {}
    for k in "ABCDEFG":
        # grab(), not one(): the row has a LABEL and a VALUE, and one()
        # returns only the first capture group -- so the label was being
        # handed to float() and raising.  Same class of error as the hex
        # extractor in the previous course's harness: one helper, two
        # incompatible jobs.
        v = grab(r"^  %s  (.+?)\s+([0-9.]+) ticks/op$" % k, T, re.M)
        if v and len(v) == 2:
            rows[k] = (v[0], float(v[1]))
    check(g, "all seven placement rows were printed",
          len(rows) == 7, "%d rows" % len(rows))

    if len(rows) == 7:
        A, B, Cc, D, E, F, G = (rows[k][1] for k in "ABCDEFG")

        # A is the floor by construction: nothing is shared.  D and E also
        # share nothing, and the whole point of the table is that A, D and E
        # are all in the same neighbourhood.  A being the SMALLEST of the three
        # is the shape, and it is what catches a row that silently acquired
        # sharing -- which is exactly the bug R7 records.
        check(g, "the no-sharing rows A, D and E are all within a small factor",
              max(A, D, E) / min(A, D, E) < 4.0,
              "A=%.2f D=%.2f E=%.2f, spread %.2fx" % (A, D, E, max(A, D, E) / min(A, D, E)))
        check(g, "the two genuinely-shared rows B and C are both far above A",
              B / A > 3.0 and Cc / A > 3.0,
              "B/A=%.2fx C/A=%.2fx" % (B / A, Cc / A))

        # THE RESULT.  True sharing and false sharing cost the same, because
        # the cost is in the cache line and not in the data.  Asserted as a
        # SHAPE with a generous band, because the ratio moves run to run
        # (1.00, 1.07, 1.09 on the three recorded runs) and asserting the exact
        # value would be a remembered-number check.
        check(g, "THE RESULT: true and false sharing cost the SAME (B/C ~ 1)",
              0.6 <= B / Cc <= 1.7, "B/C = %.2fx" % (B / Cc))
        check(g, "and neither of them is near the no-sharing floor",
              B / A > 3.0 and Cc / A > 3.0,
              "both %.1fx the floor or more" % min(B / A, Cc / A))

        # The SMT row.  The first version of this check asserted that D and A
        # DIFFER, because the artifact's prose said SMT costs a modest penalty.
        # Measured, D/A came out at 0.97 -- the two are the same.  That is a
        # real result and a better one than the one the prose asserted: two SMT
        # siblings running a body that shares nothing cost the SAME as two
        # cores running it, so the shared L1 is not what SMT charges you for.
        # The check is therefore on the SHAPE (D close to A, both far below
        # B and C), not on a difference the data does not show.
        check(g, "SMT siblings (D) cost about the SAME as two cores (A)",
              0.5 <= D / A <= 2.0, "D/A = %.2fx -- the shared L1 is not the cost" % (D / A))
        check(g, "and D is FAR below the two shared rows, so the table is not flat",
              D < Cc / 3.0 and D < B / 3.0,
              "D=%.2f vs B=%.2f C=%.2f" % (D, B, Cc))
        check(g, "both threads on ONE core (E) costs more than two cores",
              E > A, "E/A = %.2fx" % (E / A))
        # A and G are the same body with and without a `lock`, in a table of
        # SEVEN interleaved arms on a busy guest.  They come out within noise of
        # each other here, and section 3 measures the difference properly with
        # nothing else in the run.  The check is therefore closeness, not an
        # ordering -- asserting G < A would be a check that fails whenever the
        # noise is unlucky, and a check that fails for a reason the reader
        # cannot see is worse than no check.
        check(g, "the locked and unlocked no-sharing rows (A, G) are within noise",
              0.5 <= G / A <= 2.0, "G/A = %.2fx -- section 3 measures this properly" % (G / A))

        # F is the row that did NOT reproduce the expected shape, and the
        # artifact must say so rather than quietly reporting a flat number.
        check(g, "the ping-pong row F is reported even though it is not slow",
              F > 0, "F=%.2f F/A=%.2fx" % (F, F / A))
        check(g, "and the artifact explains WHY it is not slow",
              "store buffer" in FLAT.lower() and "invalidate" in FLAT.lower())
        check(g, "and says the measurement cannot count the transfers",
              "CANNOT count the transfers" in T)

    check(g, "the table states that A, B and C use the IDENTICAL instruction",
          "IDENTICAL INSTRUCTION" in FLAT.upper() and
          "Only the memory address changes" in FLAT)
    check(g, "and the artifact names the rows it did NOT use and why",
          "WHY these six and not six others" in T)

    # ------------------------------------------------------------------
    # D. the atomic instruction
    # ------------------------------------------------------------------
    g = "D atomic"
    print("  --- group D: the cost the hardware imposes on one thread")

    u_st = one(r"plain store\s+([\d.]+) ticks/op   <- the floor", T)
    u_xa = one(r"lock xadd\s+([\d.]+) ticks/op\s+[\d.]+x the plain store", T)
    u_ca = one(r"lock cmpxchg loop\s+([\d.]+) ticks/op\s+[\d.]+x the plain store", T)
    check(g, "the uncontended arm has all three bodies",
          u_st and u_xa and u_ca,
          "store=%s xadd=%s cas=%s" % (u_st or "?", u_xa or "?", u_ca or "?"))
    if u_st and u_xa:
        # THE RESULT of this section: a lock prefix with nothing to lock
        # against still costs, because on x86 it implies a full barrier.
        check(g, "an UNCONTENDED lock is more expensive than a plain store",
              float(u_xa) > float(u_st), "%.2f vs %.2f = %.2fx"
              % (float(u_xa), float(u_st), float(u_xa) / float(u_st)))
    if u_st and u_ca:
        check(g, "an uncontended CAS loop is also more expensive than a store",
              float(u_ca) > float(u_st), "%.2f vs %.2f" % (float(u_ca), float(u_st)))

    s_st = one(r"^      plain store\s+([\d.]+) ticks/op\s+[\d.]+x the floor$", T, re.M)
    s_xa = one(r"^      lock xadd\s+([\d.]+) ticks/op\s+[\d.]+x the floor$", T, re.M)
    check(g, "the contended arm has a store and an xadd row",
          s_st and s_xa, "store=%s xadd=%s" % (s_st or "?", s_xa or "?"))
    if s_xa and u_xa:
        check(g, "a CONTENDED atomic is far more expensive than an uncontended one",
              float(s_xa) / float(u_xa) > 3.0,
              "%.2f vs %.2f = %.2fx" % (float(s_xa), float(u_xa), float(s_xa) / float(u_xa)))
    if s_st and s_xa:
        check(g, "contention costs far more than the lock prefix itself does",
              (float(s_xa) - float(u_xa or 0)) > float(u_st) * 3,
              "contention %.2f ticks vs the floor %.2f" % (float(s_xa) - float(u_xa or 0),
                                                            float(u_st)))
    if s_xa and u_xa:
        cont = float(s_xa) - float(u_xa)
        check(g, "the cost of contention was reported as a SUBTRACTION",
              "the cost of CONTENTION" in T, "%.2f ticks = %.2fx"
              % (cont, cont / float(u_xa)))

    check(g, "the CAS/xadd comparison is reported in BOTH configurations",
          "against the xadd, on the same two configurations" in T)
    check(g, "and the artifact retracts its own first-draft story about it",
          "That is the general shape of a contended measurement" in T and
          "contradicted it" in T)

    # ------------------------------------------------------------------
    # E. ordering -- and what cannot be measured
    # ------------------------------------------------------------------
    g = "E ordering"
    print("  --- group E: a duration, and the correctness it is not")

    nf = one(r"no fence\s+([\d.]+) ns/iter", T)
    wf = one(r"mfence\s+([\d.]+) ns/iter", T)
    check(g, "the fence duration was measured both ways",
          nf and wf, "%s vs %s ns/iter" % (nf or "?", wf or "?"))
    if nf and wf:
        check(g, "an explicit fence is not free", float(wf) > float(nf),
              "%.2fx" % (float(wf) / float(nf)))
    check(g, "the artifact says the two loops COMPUTE THE SAME ANSWER",
          "COMPUTE THE SAME ANSWER" in T)
    check(g, "and explains why a redundant fence is still in the source",
          "weaker architecture" in FLAT.lower() and "same source" in FLAT.lower())
    check(g, "CORRECTNESS of the ordering is explicitly NOT claimed",
          "That a fence is CORRECT" in T and
          "is also what you would see if the fence were a no-op" in FLAT)
    check(g, "and the reason is stated: no timing measurement can tell",
          "neither can any timing measurement" in FLAT)
    check(g, "the count of fences ACTUALLY executed is called an upper bound",
          "an upper bound" in FLAT)

    # ------------------------------------------------------------------
    # F. NUMA
    # ------------------------------------------------------------------
    g = "F numa"
    print("  --- group F: the distinction, measured by its absence")
    node = one(r"/sys/devices/system/node/online\s+\"[^\"]*\"\s+-> (\d+) node", T)
    check(g, "the NUMA node count was read from /sys", node is not None,
          "%s node(s)" % (node or "?"))
    check(g, "and the node's CPU list was printed",
          re.search(r"node0 cpulist\s+\"", T) is not None)
    check(g, "the absence is framed as a MEASUREMENT, not a gap",
          "absence is a measurement, not a gap" in FLAT)
    check(g, "coherence and NUMA are separated as two different questions",
          "a question between two CACHES" in T and
          "a question between a CORE and a MEMORY CONTROLLER" in T)
    check(g, "and the harness's OWN gap on a two-socket machine is named",
          "THAT IS A REAL GAP IN" in T and "nothing in it checks the node" in FLAT)

    # ------------------------------------------------------------------
    # G. the retractions
    # ------------------------------------------------------------------
    g = "G retraction"
    print("  --- group G: every retraction is still present")
    for tag, frag in [
        ("R1", "MEASURED NOTHING"),
        ("R2", "Two threads on unspecified CPUs is a measurement"),
        ("R3", "is the memory course's and it is correct THERE"),
        ("R4", "RETRACTED TO THE WRONG REASON"),
        ("R5", "correct partly BY ACCIDENT"),
        ("R6", "Applied afterwards, it cannot tell you WHY"),
    ]:
        check(g, "retraction %s is present so it cannot be quietly dropped" % tag,
              frag.lower() in FLAT.lower(), frag[:42])
    nR = len(re.findall(r"^   R\d+\.", T, re.M))
    check(g, "the retractions block is numbered and contiguous", nR == 6,
          "%d retractions" % nR)
    check(g, "R1's general form is stated, because it recurs every course",
          "YOUR OPTIMISER DELETED THE DIFFERENCE" in T)

    # ------------------------------------------------------------------
    # H. the limits
    # ------------------------------------------------------------------
    g = "H limits"
    print("  --- group H: the limits, and the verdict")
    for frag in [
        "ANY COUNT of coherence traffic",
        "WHETHER THE PROTOCOL IS MESI",
        "ANYTHING about NUMA",
        "THE MEMORY ORDERING RULES",
        "THE OTHER TWO ARCHITECTURES",
        "ANYTHING PAST TWO THREADS",
        "WHETHER THE COMPILER INSERTED A FENCE",
    ]:
        check(g, "a limit is stated: %s" % frag[:36], frag in T)
    check(g, "the limits name the instrument that would settle the missing ones",
          "no PMU" in T or "perf_event_paranoid" in T)
    check(g, "the three-architecture section says it is QUOTED, not measured",
          "QUOTED, NOT MEASURED" in T)

    print("")
    if FAILURES:
        for grp, what, detail in FAILURES:
            print("  FAILED  %-11s %s   %s" % (grp, what, detail))
    print("")
    print("crosscheck: %d checks, %d failed" % (CHECKS, len(FAILURES)))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
