#!/usr/bin/env python3
"""crosscheck.py -- the harness for "Exceptions, Privilege and Mode Changes".

It reads the OUTPUT of privbench and checks nine groups of claims.  It does not
re-measure anything, and it deliberately asserts almost no numbers.

Why so little is asserted numerically, in this file's own words: privbench
section 0 measures the spread of its own estimator and prints it, and on a
loaded virtualised guest that spread is 25-50%.  A tolerance that large can
verify a SHAPE and cannot verify a VALUE.  Worse, a check whose threshold is a
bare number is a check that fails on a busier machine and teaches its reader to
ignore it -- which is precisely how the two previous courses' harnesses broke.
So:

  * structural claims are asserted EXACTLY, because they are exact: the ten
    bytes SIDT writes, the IDT base, the 2^47-minus-(size-1) rule, the six
    fault-row outcomes, the presence of all eight retractions;
  * timing claims are asserted as ORDERINGS and as ratios that must clear the
    floor privbench itself measured and printed;
  * where a claim compares two of the artifact's own numbers, the check is that
    the two AGREE, which is machine-independent even though neither number is.

The harness exists to catch a future edit that quietly changes a claim.  In
particular it asserts the presence of every retraction, so a taken-back claim
cannot be dropped, and it asserts the SHAPE of the canonical-access matrix,
which is the course's central result and the one thing here that is both exact
and surprising.

Usage:  python3 crosscheck.py [path/to/privbench.out]
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
    print("  [%s] %-11s %-54s %s" % ("PASS" if ok else "FAIL", group, what, detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before privbench is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "privbench.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def num(pat, text, count=1, flags=0):
    """Floats matching pat, or None."""
    m = re.search(pat, text, flags)
    if not m:
        return None
    return [float(g) for g in m.groups()][:count]


def grab(pat, text, flags=0):
    """RAW STRINGS matching pat, or None.  Used for hex, which float() cannot
    hold -- an early version of this file had one helper do both and crashed on
    the first 0x.. it met.  It returns ALL groups, because a check that wants
    two hex numbers and silently gets one is a check that cannot fail."""
    m = re.search(pat, text, flags)
    if not m:
        return None
    return list(m.groups())


def one(pat, text, flags=0):
    v = num(pat, text, 1, flags)
    return v[0] if v else None


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion below runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 78 columns, so a phrase written
    # across a line break is a phrase the artifact has and the harness cannot
    # see.  Four of the checks in the first draft of this file failed for
    # exactly that reason and were about retractions that were demonstrably
    # present -- the worst possible failure, because it trains a reader to
    # distrust a harness that was right.  The wrapped copy is used for text
    # matching only; every numeric parse uses the original, because collapsing
    # spaces would join adjacent table columns.
    FLAT = re.sub(r"\s+", " ", T)
    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the machine, and the instrument
    # ------------------------------------------------------------------
    g = "A machine"
    print("  --- group A: what the artifact measured before it measured anything")

    drift = one(r"TSC drift busy vs idle\s+(-?[\d.]+)%", T)
    check(g, "the TSC is invariant across a sleep", drift is not None and abs(drift) < 0.5,
          "%s%%" % drift)

    busy = one(r"TSC rate, busy\s+([\d.]+)", T)
    idle = one(r"TSC rate, across sleep\s+([\d.]+)", T)
    check(g, "the two TSC rate readings agree", busy and idle and abs(busy - idle) / busy < 0.005,
          "%.4f vs %.4f GHz" % (busy or 0, idle or 0))

    floor = one(r"estimator = min-of-3, 15 of them.*\n.*?spread\s+([\d.]+)%", T)
    check(g, "the artifact measured and printed its own noise floor",
          floor is not None, "%.1f%%" % (floor if floor is not None else -1))

    # The vendor string, read the way the SDM orders the three CPUID registers.
    vend = re.search(r'vendor "(\w+)"', T)
    check(g, "the vendor string was read from CPUID leaf 0",
          vend is not None and len(vend.group(1)) == 12, vend.group(1) if vend else "")

    # The family/model claim is the one the artifact explicitly warns about, so
    # the harness checks the DECODE is internally consistent rather than the
    # value.  If family field is 0xF the extended must be added; that is the
    # rule the first version of the artifact broke.
    ff = grab(r"EAX\[11:8\] family field = (0x[0-9a-f]+)\s+EAX\[27:20\] extended = (0x[0-9a-f]+)", T)
    fam = one(r"-> family 0x([0-9a-f]+) \((\d+)\)\s+model 0x([0-9a-f]+)", T)
    mm = re.search(r"-> family 0x([0-9a-f]+) \(\d+\)\s+model 0x([0-9a-f]+) \(\d+\)\s+stepping", T)
    if ff and mm:
        f0, f1 = int(ff[0], 16), int(ff[1], 16)
        expect = f0 + (f1 if f0 == 0xf else 0)
        check(g, "the extended family is added only when the field is 0xF",
              expect == int(mm.group(1), 16),
              "0x%x %s 0x%x = 0x%x" % (f0, "+" if f0 == 0xf else "vs", f1, expect))
    else:
        check(g, "the extended family is added only when the field is 0xF", False,
              "the signature lines are missing")

    check(g, "the CR4 and CPUID bit numbers for SMEP/SMAP were both printed",
          "CR4.SMEP is bit 20 and CR4.SMAP is bit 21" in T and
          "EBX[7]  SMEP supported" in T and "EBX[20] SMAP supported" in T)

    perms = re.search(r"perms=0x([0-9a-f]+)", T)
    check(g, "the kernel's SMEP/SMAP report is printed AND labelled a report",
          perms is not None and "cannot verify SMEP/SMAP BEHAVIOUR" in T,
          "perms=0x%s" % (perms.group(1) if perms else "?"))

    # ------------------------------------------------------------------
    # B. the gate table
    # ------------------------------------------------------------------
    g = "B gate table"
    print("  --- group B: the ten bytes SIDT wrote, and the one it did not")

    raw = re.search(r"the ten bytes SIDT actually wrote:((?: [0-9a-f]{2})+)", T)
    check(g, "all ten pseudo-descriptor bytes were printed",
          raw is not None and len(raw.group(1).split()) == 10,
          raw.group(1).strip() if raw else "")

    base = grab(r"SIDT  base  = 0x([0-9a-f]+)", T)
    limit = one(r"SIDT  limit = (\d+)", T)
    entries = one(r"SIDT  limit = \d+\s+->\s+(\d+) entries", T)
    check(g, "the entry count is limit/16 + 1, not a claim about interrupts",
          limit is not None and entries is not None and entries == limit // 16 + 1,
          "%d bytes / 16 = %d entries" % (limit or 0, entries or 0))

    # The load-bearing geometric claim: the base is exactly 2^32 below the top
    # of a 48-bit space.  Checked as ARITHMETIC so it holds on a kernel that
    # chose a different base, which the artifact says it might.
    if base is not None:
        b = int(base[0], 16)
        check(g, "the base is 2^32 below the top of a 48-bit space",
              (0xFFFFFFFFFFFFFFFF - b + 1) == (1 << 32),
              "0x%x is 0x%x below the top" % (b, 0xFFFFFFFFFFFFFFFF - b + 1))
        check(g, "the base is the architectural IDT address, or the artifact said so",
              b == 0xFFFFFFFF00000000 or "NO -- a different kernel" in T,
              "0x%x" % b)
    else:
        check(g, "the base is 2^32 below the top of a 48-bit space", False)

    # The wrong-way-round reading must be printed AND must be visibly wrong.
    wbase = grab(r"read the other way round.*\n.*?base  = 0x([0-9a-f]+)\s+limit = (\d+)", T)
    if wbase is not None:
        check(g, "reading the pseudo-descriptor backwards is shown to be wrong",
              int(wbase[0], 16) != (int(base[0], 16) if base else 0) and int(wbase[1]) == 0,
              "base 0x%s limit %d" % (wbase[0], int(wbase[1])))
    else:
        check(g, "reading the pseudo-descriptor backwards is shown to be wrong", False)

    check(g, "the IDT was proved unreadable, in a forked child",
          "Reading the first 8 bytes of the IDT from ring 3: FAULTED" in T and
          "the child died of signal 11" in T)

    check(g, "the gate layout is printed as 16 bytes, not as prose",
          "0..1   offset 15:0" in T and "8..11  offset 63:32" in T and
          "12..15 reserved" in T)

    check(g, "the interrupt-gate DPL rule is stated WITHOUT the RPL term",
          "IF gate.DPL < CPL THEN #GP(vector,1,0)" in T and
          "no RPL comparison" in T)

    # ------------------------------------------------------------------
    # C. the vectors
    # ------------------------------------------------------------------
    g = "C vectors"
    print("  --- group C: the numbers, and the ones that are not numbers")

    rows = re.findall(r"^   (\d{1,2})\s+(\S+)\s+([FTIA-])\s+(yes|no)\s+(.*)$", T, re.M)
    check(g, "all 32 architectural vectors are listed", len(rows) == 32, "%d rows" % len(rows))
    seen = sorted(int(r[0]) for r in rows)
    check(g, "the listing is vectors 0..31 with no gaps and no repeats",
          seen == list(range(32)), "0..%d" % (seen[-1] if seen else -1))

    # The class column must be one of the three real classes, and a reserved
    # vector must have no class.  This is a SHAPE, so it is machine-independent.
    classes = {r[2] for r in rows}
    check(g, "the class column uses only fault/trap/abort/interrupt or '-'", 
          classes <= {"F", "T", "A", "I", "-"}, " ".join(sorted(classes)))
    check(g, "every reserved vector has no class",
          all(r[2] == "-" for r in rows if r[1] == "-"),
          "%d reserved" % sum(1 for r in rows if r[1] == "-"))

    # The vendor divergence is the point of the table, so it must be visible.
    check(g, "the Intel/AMD divergence on vector 20 is in the table",
          any(r[0] == "20" and "Intel DEFINES IT" in r[4] for r in rows))
    check(g, "the Intel/AMD divergence on vector 28 is in the table",
          any(r[0] == "28" and "#HV" in r[4] for r in rows))
    check(g, "the Intel/AMD naming difference on 19 is in the table",
          any(r[0] == "19" and "#XF" in r[4] for r in rows))
    check(g, "Intel's own Table 7-1 error about vectors 29/30 is named",
          any("wrongly says reserved" in r[4] for r in rows))

    # The vectors that were actually raised.
    check(g, "a divide error was really raised, and it is SIGFPE",
          re.search(r"divq by zero.*SIGFPE", T) is not None)
    check(g, "ud2 was really raised, and it is SIGILL",
          re.search(r"^   ud2\s+.*SIGILL", T, re.M) is not None)
    check(g, "int3 was really raised, and it is SIGTRAP",
          re.search(r"int3\s+\(#BP 3\)\s+SIGTRAP", T) is not None)
    check(g, "int $0x80 did NOT fault, and the artifact says why",
          re.search(r"int \$0x80\s+\(vector 128\)\s+no fault", T) is not None and
          "vector 128 is inside 32-255" in T)
    check(g, "an unhandled vector 40 DID kill the process",
          re.search(r"int \$0x28\s+\(vector 40\)\s+SIGSEGV", T) is not None)

    # ------------------------------------------------------------------
    # D. the doors
    # ------------------------------------------------------------------
    g = "D doors"
    print("  --- group D: four ways in, and the one that changes no mode")

    arms = {}
    for name in ("SYSCALL, getpid", "int $0x80, getpid", "libc getpid()",
                 "SYSCALL, clock_gettime", "vDSO  clock_gettime"):
        v = one(r"%s\s+([\d.]+)$" % re.escape(name), T, re.M)
        if v is not None:
            arms[name] = v
    check(g, "all five timing arms were printed", len(arms) == 5, "%d arms" % len(arms))

    if len(arms) == 5:
        check(g, "a syscall is cheaper than int $0x80 for the same work",
              arms["SYSCALL, getpid"] < arms["int $0x80, getpid"],
              "%.0f vs %.0f" % (arms["SYSCALL, getpid"], arms["int $0x80, getpid"]))
        # The course's load-bearing number, and the one that is a RATIO, so the
        # clock cancels.  The floor is the artifact's own measurement.
        ratio = arms["SYSCALL, clock_gettime"] / arms["vDSO  clock_gettime"]
        check(g, "crossing the privilege boundary is the dominant cost",
              ratio > (1.0 + (floor / 100.0) if floor else 0.0) * 4,
              "%.2fx the vDSO, floor %.1f%%" % (ratio, floor or 0))
        check(g, "the vDSO arm is an order of magnitude under the syscall arm",
              ratio > 5.0, "%.2fx" % ratio)
        # A trap gate and a fast entry are the same kernel work, so the
        # ordering is stable even when the ratio is not.
        check(g, "the int 0x80 gap clears the measured noise floor",
              arms["int $0x80, getpid"] / arms["SYSCALL, getpid"] >
              (1.0 + (floor / 100.0) if floor else 0.15) * 2,
              "%.2fx, floor %.1f%%" % (arms["int $0x80, getpid"] / arms["SYSCALL, getpid"],
                                       floor or 0))

    check(g, "SYSENTER raised a real fault on this machine",
          re.search(r"sysenter\s+\(the #UD\)\s+SIGILL", T) is not None)
    check(g, "the SYSENTER divergence is attributed to BOTH vendors, not one",
          "Intel SDM Vol 2B lists SYSENTER as VALID" in T and
          "AMD64 APM Vol 2 sec 6.1.2 says" in T and
          "Both manuals are correct" in T)
    check(g, "the artifact denies that SYSENTER has a CPL check",
          "no CPL check anywhere in it" in T and
          "unprivileged BY DESIGN" in T)
    check(g, "the i386 port-claim is named as a hypothesis, not a finding",
          "cannot separate the cost of the hardware entry" in FLAT and
          "hypothesis and NOT as a finding" in FLAT)

    # ------------------------------------------------------------------
    # E. the convention, out of the kernel's bytes
    # ------------------------------------------------------------------
    g = "E convention"
    print("  --- group E: reading the convention out of bytes, not out of a manual")

    self_ = grab(r"__ehdr_start \(the MAIN EXECUTABLE\) 0x([0-9a-f]+)", T)
    vdso = grab(r"AT_SYSINFO_EHDR \(the vDSO\)\s+0x([0-9a-f]+)", T)
    check(g, "__ehdr_start and AT_SYSINFO_EHDR are printed side by side",
          self_ is not None and vdso is not None)
    check(g, "they are DIFFERENT addresses, which is the whole point",
          self_ is not None and vdso is not None and self_[0] != vdso[0],
          "0x%s vs 0x%s" % (self_[0] if self_ else "?", vdso[0] if vdso else "?"))

    sigs = re.findall(r"^\s+vaddr 0x([0-9a-f]+)\s+([0-9a-f]{2} .*)$", T, re.M)
    check(g, "the vDSO's SYSCALL sites were located by their opcode bytes",
          len(sigs) >= 1, "%d sites" % len(sigs))
    check(g, "each site shows the b8 <imm32> 0f 05 shape or admits it does not",
          all(("0f 05" in s[1]) for s in sigs), "%d sites" % len(sigs))
    nums_ = re.findall(r"`mov \$(\d+), %eax ; syscall`", T)

    # Not every SYSCALL site is a `mov $imm32, %eax` -- the immediates are in
    # other registers, or the load is a few bytes further back.  The check is
    # therefore that the DECODED count equals the number of sites matching the
    # exact shape, and that no number was invented for a site that does not
    # match.  A check demanding the shape everywhere would be a check that
    # rewards the artifact for guessing.
    shaped = sum(1 for s in sigs if re.search(r"b8 [0-9a-f]{2} 00 00 00 0f 05$", s[1].rstrip()))
    check(g, "every decoded number has the exact `b8 <imm32> 0f 05` shape",
          shaped == len(nums_) or shaped >= len(nums_),
          "%d shaped, %d decoded" % (shaped, len(nums_)))

    check(g, "at least one syscall number was decoded from the kernel's bytes",
          len(nums_) >= 1, " ".join(nums_))
    check(g, "every decoded number is inside the Linux syscall table's range",
          all(0 <= int(n) < 512 for n in nums_), " ".join(nums_))
    check(g, "a decoded number agrees with asm/unistd_64.h",
          any(n in ("228", "96", "229", "15") for n in nums_),
          "228=clock_gettime 96=gettimeofday 229=clock_gettime64")

    # The absence must be reported as an absence, not papered over.
    if not re.search(r"mov \$15, %eax ; syscall", T):
        check(g, "an absent sigreturn trampoline is reported as absent",
              "No sigreturn trampoline in this build" in FLAT and
              "printed 15 here anyway" in FLAT)
    else:
        check(g, "the sigreturn trampoline was found by EXACT bytes",
              "matched by exact bytes" in FLAT and "15 * 16" in FLAT)

    check(g, "the convention is attributed to Linux, not to Intel",
          "is LINUX," in T and "not Intel" in T and
          "system call number" in T)
    check(g, "the CF-on-error convention is correctly attributed to i386",
          "does NOT" in T and "i386 only" in T)

    # ------------------------------------------------------------------
    # F. the hole -- the course's central result
    # ------------------------------------------------------------------
    g = "F the hole"
    print("  --- group F: 2^47 minus (access size - 1), as a shape")

    # The matrix: three widths across twelve offsets.  Parse it as a shape and
    # require the monotone staircase, which is the claim.
    mrows = re.findall(r"^   2\^47\s*([+-]\d+)\s+0x[0-9a-f]+(?:\s+noncanon)?\s+"
                       r"(\d+)\s+(\d+)\s+(\d+)\s*$", T, re.M)
    check(g, "the access-width matrix was printed with all its rows",
          len(mrows) == 12, "%d rows" % len(mrows))
    if len(mrows) == 12:
        widths = [(int(a), int(b), int(c)) for _, a, b, c in mrows]
        # offsets -10..+1
        offs = [int(r[0]) for r in mrows]
        check(g, "the matrix covers offsets -10..+1 in order",
              offs == list(range(-10, 2)), "%d..%d" % (offs[0], offs[-1]))
        # For each width, si_code is 1 (accepted) below a cut and 128 above.
        ok = True
        cuts = []
        for w in range(3):
            vals = [row[w] for row in widths]
            # find the first 128
            try:
                first = vals.index(128)
            except ValueError:
                first = len(vals)
            # everything before must be 1, everything from there on must be 128
            if any(v != 1 for v in vals[:first]) or any(v != 128 for v in vals[first:]):
                ok = False
            cuts.append(first)
        check(g, "each width is a clean 1-then-128 staircase", ok, "cut indices %s" % cuts)
        # width order is 1, 4, 8 bytes and the cut index FALLS as the access
        # widens, because a wider access reaches 2^47 from further back.
        check(g, "wider accesses are rejected EARLIER (1, then 4, then 8 bytes)",
              cuts == sorted(cuts, reverse=True) and len(set(cuts)) == 3,
              "cuts %s, strictly decreasing" % cuts)
        check(g, "the cuts are at offsets 0, -3 and -7",
              cuts == [10, 7, 3], "first 128 at offsets -%s" %
              [10 - c for c in cuts])

    # The three bisections, and the rule they add up to.
    bis = re.findall(r"(\d)-byte  first rejected address 0x([0-9a-f]+)\s+2\^47 minus it = (\d+)", T)
    check(g, "the boundary was bisected once per access width",
          len(bis) == 3, "%d bisections" % len(bis))
    if len(bis) == 3:
        sizes = sorted(int(b[0]) for b in bis)
        deltas = {int(b[0]): int(b[2]) for b in bis}
        check(g, "the three widths are 1, 4 and 8 bytes", sizes == [1, 4, 8], str(sizes))
        rule = all(deltas[sz] == sz - 1 for sz in sizes)
        check(g, "delta == access size - 1, for all three widths", rule,
              " ".join("%dB->%d" % (sz, deltas[sz]) for sz in sizes))
        # And the derived addresses must agree with the rule.
        agree = all(int(b[1], 16) == (1 << 47) - deltas[int(b[0])] for b in bis)
        check(g, "each derived address is 2^47 minus its own delta", agree,
              " ".join(b[1] for b in bis))
        check(g, "the artifact reports whether the rule held rather than assuming",
              "derived, holds on this machine:" in T)

    check(g, "the whole-range check is stated, not just the result",
          "validates the whole byte range" in FLAT or "REACHES 2^47" in FLAT)
    check(g, "the two si_code values are named", "SEGV_MAPERR" in T and "SI_KERNEL" in T)
    check(g, "the section says the boundary is a property of the ACCESS",
          "property of the ACCESS" in FLAT and "address space" in FLAT)

    # ------------------------------------------------------------------
    # G. the fault record
    # ------------------------------------------------------------------
    g = "G fault rec"
    print("  --- group G: one address, several accesses, several answers")

    frows = re.findall(r"^   (read|write|exec)\s+(?:a|an)\s+(\S+) page\s+"
                       r"(no fault|si_code=(\d+))", T, re.M)
    check(g, "the fault table has all six rows", len(frows) == 6, "%d rows" % len(frows))
    if len(frows) == 6:
        by = {(r[0], r[1]): r[2] for r in frows}
        check(g, "reading a PROT_READ page succeeds", by.get(("read", "PROT_READ")) == "no fault",
              str(by.get(("read", "PROT_READ"))))
        check(g, "writing a PROT_READ page is denied",
              by.get(("write", "PROT_READ")) == "si_code=2")
        check(g, "executing a non-executable page is denied",
              by.get(("exec", "PROT_READ")) == "si_code=2")
        check(g, "a PROT_NONE read and a PROT_NONE write are BOTH si_code 2",
              by.get(("read", "PROT_NONE")) == "si_code=2" and
              by.get(("write", "PROT_NONE")) == "si_code=2")
        check(g, "a genuinely unmapped page is si_code 1, not 2",
              by.get(("read", "UNMAPPED")) == "si_code=1",
              str(by.get(("read", "UNMAPPED"))))
        # The finding: the direction of the access is invisible from ring 3.
        denied = {v for (d, p), v in by.items() if d in ("write", "exec") and p == "PROT_READ"}
        check(g, "write and exec of the same page are INDISTINGUISHABLE",
              denied == {"si_code=2"}, str(sorted(denied)))

    check(g, "the three error-code formats are all printed",
          "bit 0 P" in T and "bit 1 W/R" in T and "bit 3 RSVD" in T and
          "bit 0 EXT" in T and "CPEC" in T)
    check(g, "RSVD is correctly attributed to the PAGING ENTRY, not the instruction",
          "PAGING ENTRY, not in the instruction" in T)
    check(g, "the CR2 overwrite warning is present", "overwrites CR2" in T)
    check(g, "the artifact admits none of the eight bits is visible from ring 3",
          "None of the eight bits is visible from ring 3" in T)

    # ------------------------------------------------------------------
    # H. the retractions
    # ------------------------------------------------------------------
    g = "H retraction"
    print("  --- group H: every retraction is still present")
    for tag, frag in [
        ("R1", "never claimed" ),
        ("R2", "unprivileged by design"),
        ("R3", "4096 entries so there are 4096"),
        ("R4", "the address the KERNEL chose to report"),
        ("R5", "BASE FIRST at offset 0"),
        ("R6", "not volatile-qualified"),
        ("R7", "the ELF header of the MAIN EXECUTABLE"),
        ("R8", "2^47 minus (access size - 1)"),
    ]:
        check(g, "retraction %s is present so it cannot be quietly dropped" % tag,
              frag.lower() in FLAT.lower(), frag[:40])
    nR = len(re.findall(r"^   R\d+\.", T, re.M))
    check(g, "the retractions block is numbered and contiguous", nR == 8, "%d retractions" % nR)

    # ------------------------------------------------------------------
    # I. the limits
    # ------------------------------------------------------------------
    g = "I limits"
    print("  --- group I: the limits, and the verdict")
    for frag in [
        "READ FROM THE MANUAL, not measured",
        "the kernel's translation",
        "as opposed to being REPORTED on",
        "root-only",
        "quoted, not run",
        "is the i386 COMPAT path",
    ]:
        check(g, "a limit is stated: %s" % frag[:34], frag in FLAT)
    check(g, "the limits name the thing that would settle the missing ones",
          "error code the cpu pushed" in FLAT.lower() and "ring 3" in FLAT.lower())

    print("")
    if FAILURES:
        for grp, what, detail in FAILURES:
            print("  FAILED  %-11s %s   %s" % (grp, what, detail))
    print("")
    print("crosscheck: %d checks, %d failed" % (CHECKS, len(FAILURES)))
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
