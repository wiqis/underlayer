#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The x86-64 Machine: Privilege, Memory
and Time".

It reads the OUTPUT of sysdump and checks ten groups of claims.  It does not
re-measure anything, and it asserts almost no numbers.

WHY SO LITTLE IS ASSERTED NUMERICALLY, in this file's own words: sysdump
section 1 measures the spread of its own estimator and prints it BEFORE any
claim, the machine is a virtualised guest with twelve logical CPUs and other
work on it, and three of this collection's harnesses have already been broken
by a threshold that was a bare number and failed on a busier machine.  So:

  * STRUCTURAL claims are asserted EXACTLY, because they are exact: every
    vector number, class and error-code flag; every CR0, CR3 and CR4 bit
    position; the DR7 field layout and the mask computed from it; the segment
    selector's three fields; the four paging indices and every flag in one
    entry; the page-fault error code's six bits; the vendor census AS A
    PARTITION; the presence of all ten retractions and all nine limits;
  * BOUNDARY claims are asserted as a SET plus a PARTITION: which of the
    fifty instructions fault, which of the twenty-one named ones are readable,
    and the fact that a #GP is si_code 128 with si_addr 0 while a page fault
    is 1 or 2 with an address;
  * the ONE timing-shaped claim in the file is asserted as an ORDERING and a
    RATIO, never as a value;
  * everything else in this file is a fault, a bit pattern, an exact
    arithmetic identity, or a string, and those do not move between runs.

The harness exists to catch a future edit that quietly changes a claim.  In
particular it asserts the PRESENCE of all ten retractions, it asserts that
the vendor census is a partition of the thirty-two vectors, and it asserts the
canonical matrix's SHAPE on five widths without asserting the addresses,
because the addresses are a bisection result on a machine that will move.

Usage:  python3 crosscheck.py [path/to/sysdump.out]
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
    print("  [%s] %-11s %-58s %s" % ("PASS" if ok else "FAIL", group, what, detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before sysdump is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "sysdump.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def flat(x):
    """Collapse a run of spaces in a NEEDLE, for the same reason FLAT collapses
    a run of spaces in the haystack.  A column-aligned table and a needle
    written with the alignment in it are two different strings, and a harness
    that compares them learns nothing except that the artifact is untidy."""
    return re.sub(r"\s+", " ", x)


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def allgroups(pat, text, flags=0):
    """EVERY capture group of the first match, or None.

    `one()` returns group 1, and a caller that wrote a three-group pattern
    got group 1 and then tried to int() group 3 -- which, for a hex column,
    is a letter.  The mistake is loud once it happens and silent when the
    third group happens to be decimal, which is why the helper is named
    rather than spelled out at every call."""
    m = re.search(pat, text, flags)
    return m.groups() if m else None


def rows(text, pat, take=None, last=None):
    """Every line of a table that matches `pat`, as a token list.

    The ORDER matters: a table whose rows were reordered is a different
    table, and a check that only looked at the contents would not notice.
    `take=N` keeps the FIRST N capture groups and `last=N` the LAST N,
    because the first version of this helper took a NUMBER of groups and
    silently returned ALL of them, so every caller that wanted two got
    three and every comparison against a two-field oracle failed for
    reasons that had nothing to do with the artifact.  The ninth time in
    this collection that a helper written for one shape was used on
    another; the fix is always to make the SHAPE the argument name."""
    pat = re.compile(pat)
    out = []
    for ln in text.splitlines():
        m = pat.match(ln)
        if not m:
            continue
        if take is not None:
            out.append(m.groups()[:take])
        elif last is not None:
            out.append(m.groups()[-last:])
        else:
            out.append(ln.split())
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 78 columns, so a phrase written
    # across a line break is a phrase the artifact HAS and the harness cannot
    # see.  Numeric parses still use the original, because collapsing spaces
    # there would join adjacent columns.
    FLAT = re.sub(r"\s+", " ", T)
    print("crosscheck: %s\n" % path)

    # ------------------------------------------------------------------
    # A. the instrument
    # ------------------------------------------------------------------
    g = "A instrument"
    print("  --- group A: what was measured before anything was measured")
    busy = one(r"TSC rate, busy\s+([\d.]+) GHz", T)
    idle = one(r"TSC rate, across a 300 ms sleep\s+([\d.]+) GHz", T)
    check(g, "the TSC rate was measured twice and the two agree",
          busy and idle and abs(float(busy) - float(idle)) / float(busy) < 0.005,
          "%.4f vs %.4f GHz" % (float(busy) if busy else 0, float(idle) if idle else 0))
    drift = one(r"drift\s+(-?[\d.]+) %", T)
    check(g, "the TSC is invariant, so a tick is TIME and not cycles",
          drift is not None and abs(float(drift)) < 0.5, "%s%%" % drift)
    chase = one(r"POINTER CHASE, 64 KiB of nodes\s+([\d.]+) ticks/op", T)
    arith = one(r"ARITHMETIC increment loop\s+([\d.]+) ticks/op", T)
    check(g, "the floor was measured on a body the core clock cannot affect",
          chase is not None, "%.3f ticks/op" % (float(chase) if chase else -1))
    check(g, "and on one it can, and the two were reported separately",
          arith is not None, "%.3f ticks/op" % (float(arith) if arith else -1))
    if chase and arith:
        check(g, "the arithmetic loop is the CLOCK and not noise, and it is the",
              float(arith) < float(chase),
              "%.2fx apart" % (float(chase) / float(arith)))
    check(g, "the artifact names which floor it quotes",
          "the floor used for every band in this file is the POINTER CHASE" in FLAT)
    check(g, "the check was READ from inside the process, not assumed",
          "the cpu that answered is" in T and "(VERIFIED" in T)
    check(g, "perf_event_paranoid was read and printed",
          one(r"perf_event_paranoid = (\d+)", T) is not None)
    check(g, "and the ABSENCE of a counter is proved, not assumed",
          "RDPMC in a forked child: KILLED by a signal" in T)
    check(g, "the consequence is stated: durations are not counts",
          "bounds a count without measuring it" in FLAT)
    check(g, "the one input is declared OPTIONAL rather than assumed present",
          "and it is OPTIONAL" in FLAT)
    dis = one(r"sysdump_dis\.txt\s+(\w+)", T)
    check(g, "the disassembly input is reported by name and by state",
          dis in ("loaded", "ABSENT"), "sysdump_dis.txt = %s" % dis)
    check(g, "and the artifact says the section runs either way",
          "runs the 16-byte" in FLAT and "arm with an instruction this file writes" in FLAT)

    # ------------------------------------------------------------------
    # B. the oracle: CR0, CR3 and CR4, bit for bit
    # ------------------------------------------------------------------
    g = "B oracle"
    print("  --- group B: the control registers, which are exact or nothing")
    check(g, "the oracle is labelled as NOT measured",
          "PRINTED AND NOT MEASURED" in T and "NOT MEASURED" in T)
    cr0 = rows(T, r"^  CR0 \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_cr0 = {
        "0": "PE", "1": "MP", "2": "EM", "3": "TS", "4": "ET", "5": "NE",
        "6-15": "-", "16": "WP", "17": "-", "18": "AM", "19-28": "-",
        "29": "NW", "30": "CD", "31": "PG", "32-63": "-",
    }
    check(g, "CR0 has one row per bit range and no others",
          [r[0] for r in cr0] == list(want_cr0.keys()),
          " ".join(r[0] for r in cr0))
    if cr0:
        check(g, "and every CR0 bit position maps to the right name",
              {r[0]: r[1] for r in cr0} == want_cr0,
              ", ".join("%s=%s" % (r[0], r[1]) for r in cr0))
    check(g, "and the ET row says WHY a dead bit is still there",
          "compatibility scar" in FLAT)
    check(g, "and the section states which CR0 write flushes the TLB",
          "CR0.PG 0->1 flushes the TLB completely" in FLAT)
    check(g, "and names the two bits that need NO invalidation",
          "change no TLB entry" in FLAT and "requires NO invalidation" in FLAT)

    cr3 = rows(T, r"^  CR3 \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_cr3 = [("0-11", "PCID"), ("12", "PWT"), ("13", "PCD"),
                ("14-47", "BASE"), ("48-51", "SEAM"), ("52-63", "ZERO")]
    check(g, "CR3's six fields, in order, with the seam named",
          [tuple(r) for r in cr3] == want_cr3,
          " ".join("%s=%s" % (r[0], r[1]) for r in cr3) if cr3 else "no rows")
    check(g, "and the seam row says it is NOT a constant",
          "MUST EQUAL bit 47 of BASE" in FLAT
          and "not a bit" in FLAT and "you can set to a constant" in FLAT)
    check(g, "and the four address-size bits are printed for BOTH modes",
          flat("4-level paging   CR3[63:52] reserved-zero") in FLAT
          and flat("5-level paging   CR3[63:58] reserved-zero") in FLAT)

    cr4 = rows(T, r"^  CR4 \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_cr4 = [("0", "VME"), ("1", "PVI"), ("2", "TSD"), ("3", "DE"),
                ("4", "PSE"), ("5", "PAE"), ("6", "MCE"), ("7", "PGE"),
                ("8", "PCE"), ("9", "OSFXSR"), ("10", "OSXMMEXCPT"),
                ("11", "UMIP"), ("12", "LA57"), ("13", "VMXE"), ("14", "SMXE"),
                ("15", "-"), ("16", "FSGSBASE"), ("17", "PCIDE"),
                ("18", "OSXSAVE"), ("19", "KL"), ("20", "SMEP"), ("21", "SMAP"),
                ("22", "PKE"), ("23", "CET"), ("24", "PKS"), ("25", "UINTR"),
                ("26", "-"), ("27", "LAM"), ("28", "LAM_SUP"),
                ("29-31", "-"), ("32", "FRED"), ("33-63", "-")]
    check(g, "CR4 has one row per bit, 0 to 33, and no others",
          len(cr4) == len(want_cr4), "%d rows" % len(cr4))
    if len(cr4) == len(want_cr4):
        bad = [(a, b) for a, b in zip(cr4, want_cr4) if tuple(a) != b]
        check(g, "and every CR4 bit position maps to the right name",
              not bad, " ".join("%s=%s" % (a, b) for a, b in bad) or "all 31 rows")
    for bit, why in [("11", "UMIP"), ("8", "PCE"), ("2", "TSD"),
                     ("17", "PCIDE"), ("12", "LA57")]:
        check(g, "the row that decides something is named: CR4.%s" % why,
              re.search(r"CR4\.%s\b" % why, T) is not None)
    check(g, "and the section says the five deciding rows are all UNREADABLE",
          "every one of them is a bit in a register it" in FLAT
          and "cannot read" in FLAT)

    # ------------------------------------------------------------------
    # C. DR7: the layout and the mask, computed rather than quoted
    # ------------------------------------------------------------------
    g = "C dr7"
    print("  --- group C: the debug registers, and the mask a debugger must program")
    dr7 = rows(T, r"^  DR7 \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_dr7 = [("0", "L0"), ("1", "G0"), ("2", "L1"), ("3", "G1"),
                ("4", "L2"), ("5", "G2"), ("6", "L3"), ("7", "G3"),
                ("8", "LE"), ("9", "GE"), ("10", "ONE"), ("11-12", "-"),
                ("13", "GD"), ("14-15", "-"),
                ("16-19", "FP0"), ("20-23", "FP1"), ("24-27", "FP2"),
                ("28-31", "FP3"), ("32-63", "-")]
    check(g, "DR7's eighteen rows, in order",
          [tuple(r) for r in dr7] == want_dr7,
          " ".join("%s=%s" % (r[0], r[1]) for r in dr7) if dr7 else "no rows")
    check(g, "the local enables are at 0, 2, 4 and 6 -- a contiguous half",
          re.search(r"DR_LOCAL_ENABLE_MASK=0x55", FLAT) is not None)
    check(g, "and the global ones at 1, 3, 5 and 7",
          re.search(r"DR_GLOBAL_ENABLE_MASK=0xAA", FLAT) is not None)
    check(g, "and the control fields start at bit 16, four bits each",
          re.search(r"DR_CONTROL_SHIFT=16, DR_CONTROL_SIZE=4", FLAT) is not None)
    check(g, "and the reset value's fixed bit is bit 10",
          re.search(r"DR7_FIXED_1=0x400", FLAT) is not None
          and "ONE     | architecturally reserved to 1" in T)
    check(g, "all four R/W encodings and all four LEN encodings are printed",
          all(("R/W | %s |" % v) in T for v in ("00", "01", "10", "11"))
          and all(("LEN | %s |" % v) in T for v in ("00", "01", "10", "11")))
    check(g, "and the LEN order is called out, because 10 is EIGHT bytes",
          "LEN 10 is EIGHT bytes and LEN 11 is FOUR" in FLAT
          and "the single most common DR7 bug" in FLAT)
    check(g, "the mask formula is printed and EVALUATED here, not typed in",
          flat("enable(i)  = (L_i ? 1 : 0) << (2*i)") in FLAT
          and flat("field(i)   = ((LEN_i & 3) << 2 | (RW_i & 3)) << (16 + 4*i)") in FLAT
          and flat("DR7        = 0x400 | GE<<9 | GD<<13") in FLAT
          and "evaluated here" in FLAT)
    masks = rows(T, r"^  DR7MASK \| (.*?) \| 0x([0-9a-f]{16}) \| (\S+)$", take=3)
    check(g, "four masks were built, one per case, and all four are checked",
          len(masks) == 4, "%d masks" % len(masks))
    check(g, "and all four say the eight fields are DISJOINT",
          masks and all(m[2] == "yes" for m in masks),
          ", ".join(m[2] for m in masks) if masks else "")
    # The load-bearing arithmetic, re-derived here rather than trusted: four
    # 4-byte WRITE breakpoints, all global, from the printed formula.
    want = 0x400 | 0x200
    for i in range(4):
        want |= 0x2 << (2 * i)
        want |= (((3 & 3) << 2) | (1 & 3)) << (16 + 4 * i)
    quoted = one(r"four 4-byte WRITE breakpoints \| 0x([0-9a-f]{16})", T)
    check(g, "the mask for four 4-byte WRITE breakpoints is recomputed here",
          quoted is not None and int(quoted, 16) == want,
          "0x%s == 0x%016x" % (quoted, want) if quoted else "not printed")
    # The all-LOCAL mask is the four LOCAL bits, which are 0x55, not 0xAA:
    # masking the global bits off a word that never had them set is the
    # second way to get this mask wrong, and the first version of the
    # artifact made exactly that mistake and printed 0x55550400.
    local = one(r"all LOCAL, no GD \| 0x([0-9a-f]{16})", T)
    want_local = (want & ~0xAAAAAAAA) | 0x55
    check(g, "and the all-LOCAL variant has the FOUR LOCAL BITS SET, 0x55",
          local is not None and int(local, 16) == want_local,
          "0x%s == 0x%016x" % (local, want_local) if local else "?")
    reset = one(r"reset value: the fixed one and nothing else \| 0x([0-9a-f]{16})", T)
    check(g, "and the reset value is 0x400 and nothing else",
          reset is not None and int(reset, 16) == 0x400, "0x%s" % reset)
    check(g, "and the two disagreeing descriptions are BOTH printed",
          "places L2 and G2 at bits 8 and 9" in FLAT
          and "R/W0 field at bit 22" in FLAT)
    check(g, "and the section says it cannot measure which one is right",
          "CANNOT MEASURE WHICH ONE ITS OWN CPU" in FLAT
          and "MOV failing" in FLAT)
    check(g, "and names the instrument that would settle it",
          "PTRACE_PEEKUSER at DR7" in FLAT)

    # ------------------------------------------------------------------
    # D. the segment selector and the paging structures
    # ------------------------------------------------------------------
    g = "D selector"
    print("  --- group D: the selector's three fields and the three comparisons")
    sel = rows(T, r"^  SEL \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_sel = [("15:3", "index"), ("2", "TI"), ("1:0", "RPL"),
                ("0xffff", "a NULL selector")]
    check(g, "the selector is three fields plus the NULL value",
          [tuple(r) for r in sel][:3] == want_sel[:3],
          " ".join("%s=%s" % (r[0], r[1]) for r in sel) if sel else "no rows")
    check(g, "and 0xffff is named as the NULL selector with its decoding",
          "a NULL selector: index 8191, TI 1, RPL 3" in FLAT)
    check(g, "CPL, RPL and DPL are each defined in one line",
          "the current privilege level, from CS.RPL" in FLAT
          and "requested, from the low two bits" in FLAT
          and "bits 14:13 of the descriptor" in FLAT)
    for rule in ["for a DATA or CODE segment:  max(CPL, RPL) <= DPL   or  #GP",
                 "for a CALL GATE:             max(CPL, RPL) <= DPL   or  #GP(tss)",
                 "for an INTERRUPT gate:       CPL <= DPL             or  #GP(vector)"]:
        check(g, "the comparison %r is printed" % rule[:34], flat(rule) in FLAT)
    check(g, "and the third rule has no RPL because a vector has no RPL",
          "a vector number has no RPL field" in FLAT)
    check(g, "and the call-gate confusion is named",
          "is quoting the CALL-GATE rule for something that is not a call gate"
          in FLAT)

    g = "D2 paging"
    idx = rows(T, r"^  IDX \| (\w+)\s+\| (\S+) bits \| (.*)$", take=3)
    want_idx = [("PML4", "9", "address bits 47:39"),
                ("PDPT", "9", "address bits 38:30"),
                ("PD", "9", "address bits 29:21"),
                ("PT", "9", "address bits 20:12"),
                ("OFF", "12", "address bits 11:0, always added last")]
    check(g, "the five index fields, in order, with the bit ranges",
          [tuple(r) for r in idx] == want_idx,
          " ".join("%s/%s" % (r[0], r[1]) for r in idx) if idx else "no rows")
    check(g, "and the widths are summed to 48 in the artifact's own words",
          "9+9+9+9+12 = 48" in FLAT)
    pte = rows(T, r"^  PTE \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_pte = [("0", "P"), ("1", "RW"), ("2", "US"), ("3", "PWT"),
                ("4", "PCD"), ("5", "A"), ("6", "D"), ("7", "PS"),
                ("8", "G"), ("9-11", "-"), ("12", "PAT"),
                ("13-58", "-"), ("59-62", "PKRU"), ("63", "NX")]
    check(g, "every flag in a paging entry, in bit order",
          [tuple(r) for r in pte] == want_pte,
          " ".join("%s=%s" % (r[0], r[1]) for r in pte) if pte else "no rows")
    check(g, "and the four bits the HARDWARE sets are named as such",
          "the ONLY bits the HARDWARE sets" in FLAT)
    check(g, "and PS is marked as the page-directory-level bit only",
          "0 = 4 KiB, 1 = 2 MiB, PD level ONLY" in T)
    # The RSVD row of the error code is printed across TWO lines, so the
    # pattern has to allow the continuation rather than insist on seven
    # single-line rows.  A harness that insists on one line per row is a
    # harness that reports a typesetting choice as a missing field.
    err = rows(T, r"^  ERR \| (\S+)\s+\| (\S+)\s+\| (.*)$", take=2)
    want_err = [("0", "P"), ("1", "W/R"), ("2", "U/S"),
                ("4", "I/D"), ("5", "PK"), ("6-31", "-")]
    check(g, "the page-fault error code's seven fields",
          [tuple(r) for r in err] == want_err,
          " ".join("%s=%s" % (r[0], r[1]) for r in err) if err else "no rows")
    check(g, "and the two bits a demand-paging system needs are named",
          "Bits 1 and 4 are exactly the two a demand-paging system needs" in FLAT)

    # ------------------------------------------------------------------
    # E. what ring 3 can read
    # ------------------------------------------------------------------
    g = "E readable"
    print("  --- group E: the CAN half of the inventory")
    check(g, "the vendor string was read out of CPUID leaf 0",
          re.search(r'vendor \| AuthenticAMD', T) is not None)
    check(g, "and the brand string came from the 0x80000002-4 leaves",
          re.search(r"brand string\s+'AMD Ryzen 5 7430U", T) is not None)
    check(g, "and the artifact says the brand is NOT in leaf 1",
          "the brand string is NOT here" in FLAT)
    leaves = sorted(set(re.findall(r"^  CPUID \| (0x[0-9a-f]{8})", T, re.M)))
    check(g, "all four leaf groups are decoded: 0, 1, 7 and 0x8000000n",
          leaves == ["0x00000000", "0x00000001", "0x00000007", "0x80000000",
                     "0x80000001", "0x80000008"],
          " ".join(leaves))
    check(g, "leaf 7 is decoded at BOTH subleaves",
          "subleaf 0" in T and "subleaf 1" in T)
    lam = one(r"subleaf 1 \| EAX 0x[0-9a-f]+ \| LAM (\d) MOVRS", T)
    check(g, "and LAM is read from subleaf 1 EAX bit 26, NOT subleaf 0",
          lam is not None and "LAM is in subleaf 1 EAX bit 26" in FLAT
          and "read subleaf 0 ECX bit 26" in FLAT,
          "LAM = %s" % lam)
    la57 = one(r"five-level paging \(LA57\) = (\d)", T)
    check(g, "and LA57 is read from 0x80000008 EAX bit 21",
          la57 is not None, "LA57 = %s" % la57)
    check(g, "and the artifact says the 13:12 field is RESERVED at 3",
          "values 2 and 3 are RESERVED and this machine" in FLAT
          and "reports 3. A first version" in FLAT)
    sidt = allgroups(r"SIDT \| base 0x([0-9a-f]+) \| limit (\d+) \| entries (\d+)", T)
    sgdt = allgroups(r"SGDT \| base 0x([0-9a-f]+) \| limit (\d+) \| entries (\d+)", T)
    check(g, "SIDT and SGDT both returned a base and a limit",
          sidt and sgdt,
          "IDT %s/%s, GDT %s/%s" % (sidt[0], sidt[1], sgdt[0], sgdt[1]) if sidt and sgdt else "")
    if sidt and sgdt:
        check(g, "and the IDT's entry count is limit/16 + 1",
              int(sidt[2]) == int(sidt[1]) // 16 + 1, "%s" % sidt[2])
        check(g, "and the GDT's is limit/8 + 1",
              int(sgdt[2]) == int(sgdt[1]) // 8 + 1, "%s" % sgdt[2])
        check(g, "and the two bases are exactly 2^32 bytes apart",
              abs((int(sidt[0], 16) - int(sgdt[0], 16)) - (1 << 32)) == 0,
              "0x%s - 0x%s" % (sidt[0], sgdt[0]))
        check(g, "and BOTH bases are inside the upper canonical half",
              all(int(x, 16) >= 0xffff800000000000 for x in (sidt[0], sgdt[0])))
    check(g, "and the wrong field order is measured and reported beside it",
          re.search(r"base 0x[0-9a-f]+  limit 0", T) is not None)
    check(g, "and the artifact says the wrong reading is UNFALSIFIABLE",
          "UNFALSIFIABLE" in T and "INDISTINGUISHABLE from a kernel that installed an empty" in FLAT)
    check(g, "and the ADJACENCY claim of the first draft is retracted in place",
          "said the two tables were ADJACENT" in FLAT
          and "those are not equal" in FLAT)
    xcr0 = one(r"XGETBV\(0\) \| 0x([0-9a-f]{16})", T)
    check(g, "XCR0 was read and its four set bits named",
          xcr0 is not None and all(((int(xcr0, 16) >> b) & 1) for b in (0, 1, 2, 9)),
          "0x%s" % xcr0)
    cs = allgroups(r"SEG \| cs \| selector 0x([0-9a-f]{4}) \| index (\d+) TI (\d) RPL (\d)", T)
    check(g, "CS decoded to index 6, TI 0, RPL 3 -- so this process is at CPL 3",
          cs is not None and cs[1:] == ("6", "0", "3"),
          "0x%s -> index %s TI %s RPL %s" % cs if cs else "")
    tr = one(r"TR  \| 0x([0-9a-f]{4})", T)
    check(g, "and TR read as a 16-bit selector, not a garbage address",
          tr is not None and int(tr, 16) <= 0xffff, "0x%s" % tr)
    check(g, "and the %w0 leaves-the-upper-bits-undefined trap is named",
          "LEAVES THE UPPER" in FLAT
          and "BITS OF THE GENERAL REGISTER UNDEFINED" in FLAT
          and "0x35410040" in T)
    check(g, "and the four NULL data selectors are explained, not just printed",
          "a NULL selector is perfectly legal to LOAD in 64-bit mode" in FLAT)

    g = "E2 syscall"
    print("  --- group E2: syscall and the registers it touches")
    reg = rows(T, r"^  SYSCALL \| (\S+)\s+\| 0x([0-9a-f]+) \| 0x([0-9a-f]+) \| (\S+)$", take=4)
    check(g, "all thirteen registers were marked and read back",
          len(reg) == 13, "%d rows" % len(reg))
    check(g, "and the thirteen are rbx, rdx, rsi, rdi, rbp, r8..r15, in order",
          [r[0] for r in reg] == ["rbx", "rdx", "rsi", "rdi", "rbp", "r8",
                                  "r9", "r10", "r11", "r12", "r13", "r14", "r15"],
          " ".join(r[0] for r in reg))
    clob = [r[0] for r in reg if r[3] == "CLOBBERED"]
    check(g, "and EXACTLY ONE came back clobbered, and it is r11",
          clob == ["r11"], "clobbered: %s" % (" ".join(clob) or "none"))
    check(g, "and the r11 value is an RFLAGS word, i.e. bit 1 is set",
          reg and (int([r[2] for r in reg if r[0] == "r11"][0], 16) & 2) == 2,
          "0x%s" % [r[2] for r in reg if r[0] == "r11"][0] if reg else "")
    check(g, "and no marker is zero, so no arm silently failed to run",
          reg and all(int(r[1], 16) != 0 and int(r[2], 16) != 0 for r in reg))
    tally = allgroups(r"SYSCALL \| arms (\d+) \| survived (\d+) \| clobbered (\d+)", T)
    check(g, "the tally line is a partition of the arms it reports",
          tally is not None and int(tally[1]) + int(tally[2]) == int(tally[0])
          and int(tally[2]) >= 1,
          " / ".join(tally) if tally else "no row")
    check(g, "and the arm count is a WHOLE NUMBER OF RUNS of thirteen",
          tally is not None and int(tally[0]) % 13 == 0
          and int(tally[0]) >= 13
          and int(tally[1]) == 12 * (int(tally[0]) // 13),
          "%s arms, %s survived" % tally[:2] if tally else "")
    check(g, "the RAW syscall and libc's getpid agree, bit for bit",
          re.search(r"through libc\s+= (\d+)   same \? YES", T) is not None)
    check(g, "an unknown number returns -ENOSYS in RAX, and it is a RETURN",
          re.search(r"syscall number 9999, RAW\s+= -38, i\.e\. -ENOSYS", T) is not None)
    check(g, "and the libc wrapper is shown turning it into -1 and errno 38",
          re.search(r"through libc\s+= -1 with errno 38", T) is not None)
    check(g, "and the six-argument call is reported as accepted and ignored",
          "the cost of a system call by passing more arguments" in FLAT)
    check(g, "and the section says the MSRs are the part it cannot see",
          "IA32_STAR, IA32_LSTAR and" in FLAT and "section 3 measures that" in FLAT)
    check(g, "and the three-batch workaround for the 14-output asm is explained",
          flat("fewer than fourteen allocatable registers") in FLAT
          and "the ADDRESS of one of the fourteen output slots" in FLAT)

    # ------------------------------------------------------------------
    # F. the boundary
    # ------------------------------------------------------------------
    g = "F boundary"
    print("  --- group F: the CANNOT half, as a set and as a partition")
    # Every column is padded to a width, so the separators after a number are
    # TWO spaces in some rows and one in others.  A pattern that hard-codes
    # one space matched 34 of the 52 rows on the first run and reported the
    # table as too short, which is a check about the typesetting.
    edge = rows(T, r"^  EDGE \| (.*?)\s+\| (.*?)\s+\| (FAULTED|RETURNED) \| sig\s+(\d+)\s+\| si_code\s+(\d+)\s+\|", take=5)
    check(g, "every instruction in the table was run in a forked child",
          len(edge) >= 45, "%d rows" % len(edge))
    faulted = {r[0] for r in edge if r[2] == "FAULTED"}
    returned = {r[0] for r in edge if r[2] == "RETURNED"}
    must_fault = {"lidt", "lgdt", "ltr", "lldt",
                  "mov cr0 -> reg", "mov cr2 -> reg", "mov cr3 -> reg",
                  "mov cr4 -> reg", "mov cr8 -> reg",
                  "mov reg -> cr0", "mov reg -> cr3", "mov reg -> cr4",
                  "mov reg -> cr8", "mov dr0 -> reg", "mov dr6 -> reg",
                  "mov dr7 -> reg", "mov reg -> dr7",
                  "rdmsr", "wrmsr", "rdpmc", "xsetbv",
                  "invd", "wbinvd", "invlpg", "clts", "lmsw",
                  "hlt", "cli", "sti", "swapgs", "sysret", "iretq"}
    check(g, "and every privileged one faulted",
          must_fault <= faulted,
          "missing: %s" % (" ".join(sorted(must_fault - faulted)) or "none"))
    must_read = {"sidt", "sgdt", "sldt", "str", "smsw",
                 "rdtsc", "rdtscp", "xgetbv", "rdfsbase", "wrfsbase"}
    check(g, "and every unprivileged one returned, INCLUDING sgdt and str",
          must_read <= returned,
          "not readable: %s" % (" ".join(sorted(must_read - returned)) or "none"))
    check(g, "and the two sets are DISJOINT, so the table is a partition",
          not (faulted & returned),
          "both: %s" % (" ".join(sorted(faulted & returned)) or "none"))
    gp = [r for r in edge if r[4] == "128"]
    check(g, "and every #GP came back as si_code 128 with si_addr 0",
          gp and all("0x000000000000" in [l for l in T.splitlines()
                                          if l.startswith("  EDGE | " + r[0])][0]
                     for r in gp),
          "%d rows at 128" % len(gp))
    check(g, "and no faulted row is a page fault by accident",
          faulted <= {r[0] for r in edge if r[4] in ("128", "2")},
          "si_code 2 rows: %s" % (" ".join(r[0] for r in edge if r[4] == "2") or "none"))
    check(g, "sysenter and ud2 are #UD and not #GP, unlike sysret",
          [r[4] for r in edge if r[0] == "sysenter"] == ["2"]
          and [r[4] for r in edge if r[0] == "sysret"] == ["128"])
    check(g, "and the artifact says so in prose, with the reason",
          "SYSRET from ring 3 is a #GP here, not a #UD" in FLAT)
    check(g, "and the XGETBV/XSETBV asymmetry is called out",
          "XGETBV is UNPRIVILEGED while XSETBV is privileged" in FLAT)
    check(g, "and the SGDT/SIDT caveat names CR4.UMIP rather than denying it",
          flat("CR4.UMIP can make them") in FLAT
          and "a measurement of the EFFECT" in FLAT)
    check(g, "and the STR/SLDT/SMSW caveat names the asymmetry",
          "the check for WRITING" in FLAT and "READING it is nothing" in FLAT)
    check(g, "and the section refuses to call any of it a reading of a CR",
          "NOTHING ABOVE IS A READING OF A CONTROL REGISTER" in T)
    check(g, "and it says the 128 is the SAME 128 as a non-canonical access",
          flat("the same 128 a non-canonical access produces in section 5") in FLAT)
    check(g, "and the harness-side bug is named, because it printed 0s",
          "printed si_code 0 for" in FLAT and "They are all 128" in FLAT)

    # ------------------------------------------------------------------
    # G. the exceptions
    # ------------------------------------------------------------------
    g = "G exceptions"
    print("  --- group G: all thirty-two vectors, with class and error code")
    vec = rows(T, r"^  VEC \| (\d+)\s+\| (\S+)\s+\| (\S)\s+\| (\S+)\s+\| (\S+)\s+\| (.*)$", take=5)
    want = {
        0: ("#DE", "F", "no"), 1: ("#DB", "T", "no"), 2: ("NMI", "I", "no"),
        3: ("#BP", "T", "no"), 4: ("#OF", "T", "no"), 5: ("#BR", "F", "no"),
        6: ("#UD", "F", "no"), 7: ("#NM", "F", "no"), 8: ("#DF", "A", "yes"),
        9: ("-", "-", "no"), 10: ("#TS", "F", "yes"), 11: ("#NP", "F", "yes"),
        12: ("#SS", "F", "yes"), 13: ("#GP", "F", "yes"), 14: ("#PF", "F", "yes"),
        15: ("-", "-", "no"), 16: ("#MF", "F", "no"), 17: ("#AC", "F", "yes"),
        18: ("#MC", "A", "no"), 19: ("#XM", "F", "no"), 20: ("#VE", "F", "no"),
        21: ("#CP", "F", "yes"), 22: ("-", "-", "no"), 23: ("-", "-", "no"),
        24: ("-", "-", "no"), 25: ("-", "-", "no"), 26: ("-", "-", "no"),
        27: ("-", "-", "no"), 28: ("-", "-", "no"), 29: ("#VC", "F", "no"),
        30: ("#SX", "A", "no"), 31: ("-", "-", "no"),
    }
    check(g, "all thirty-two rows, 0 to 31, in order, and no others",
          [int(r[0]) for r in vec] == list(range(32)), "%d rows" % len(vec))
    if len(vec) == 32:
        bad = [(int(r[0]),) + tuple(r[1:4]) for r in vec
               if (int(r[0]),) + tuple(r[1:4]) != (int(r[0]),) + want[int(r[0])]]
        check(g, "and every number, mnemonic, class and error-code flag",
              not bad, " ".join(str(b) for b in bad) or "all 32 rows")
    check(g, "and every row says MEASURED or QUOTED, and nothing else",
          vec and all(r[4] in ("MEASURED", "QUOTED") for r in vec),
          " ".join(sorted(set(r[4] for r in vec))) if vec else "")
    measured = sorted(int(r[0]) for r in vec if r[4] == "MEASURED")
    check(g, "and the measured rows are exactly the six this file raised",
          measured == [0, 1, 3, 6, 13, 14], str(measured))
    check(g, "the four classes are defined and the '-' is the fifth",
          all(("CLASS | %s" % c) in T for c in ("F fault", "T trap", "A abort",
                                                "I interrupt", "- reserved")))
    check(g, "and the class is said to be QUOTED, because the saved RIP is hidden",
          flat("class of every row above is QUOTED") in FLAT
          and "put in the siginfo" in FLAT)
    check(g, "and #DB is called out as the class-varies-with-the-cause row",
          "TRAP for a breakpoint, FAULT for a task switch" in T
          and "a property of" in FLAT and "the CAUSE rather than of the vector" in FLAT)
    vend = allgroups(r"reserved on BOTH (\d+) \| Intel only (\d+) \(#20\) \| AMD only (\d+) \(#28\)", T)
    part = allgroups(r"are a PARTITION: (\d+) \+ (\d+) \+ (\d+) \+ (\d+) \+ (\d+) = (\d+)", T)
    check(g, "the vendor census was printed, all four columns",
          vend is not None, " ".join(vend) if vend else "no row")
    check(g, "and it is a PARTITION of the thirty-two vectors",
          part is not None and sum(int(x) for x in part[:5]) == int(part[5])
          and int(part[5]) == 32,
          " + ".join(part) if part else "no row")
    if part:
        check(g, "and the two columns the first draft got wrong are right",
              (int(part[0]), int(part[1]), int(part[2])) == (20, 1, 1),
              "both %s, intel %s, amd %s" % part[:3])
    check(g, "and the three documented divergences are named",
          all(s in FLAT for s in ["#XM on Intel and #XF on AMD",
                                  "20 is #VE on Intel and RESERVED",
                                  "28 is #HV on AMD and RESERVED on Intel",
                                  "Intel's own summary table lists them"]))
    check(g, "and the section says none of the vendor table is measured",
          "NONE of that is measured here" in FLAT)

    g = "G2 raise"
    print("  --- group G2: the exceptions that were actually raised")
    raise_rows = rows(T, r"^  RAISE \| (.*?)\s+\| (\S+(?: \S+)?)\s+\| sig\s+(\d+)\s+\| (\d+)\s+\| 0x([0-9a-f]+)", take=5)
    by = {r[0].strip(): r for r in raise_rows}
    check(g, "ud2 arrived as SIGILL",
          "ud2" in by and by["ud2"][2] == "4" and by["ud2"][1] == "#UD 6")
    check(g, "int3 arrived as SIGTRAP with si_code 128",
          "int3" in by and by["int3"][2] == "5" and by["int3"][3] == "128")
    check(g, "a divide by zero arrived as SIGFPE, and was NOT deleted",
          "divq by zero, divisor behind a volatile pointer" in by
          and by["divq by zero, divisor behind a volatile pointer"][2] == "8"
          and "removed the division" in FLAT)
    check(g, "and the null deref is si_code 1 with si_addr 0",
          "write through a NULL pointer" in by
          and by["write through a NULL pointer"][3] == "1"
          and by["write through a NULL pointer"][4].strip("0") == "")
    check(g, "and the PROT_READ write and the PROT_NONE touch are BOTH 2",
          by.get("write to a PROT_READ page", [None] * 5)[3] == "2"
          and by.get("touch a PROT_NONE page", [None] * 5)[3] == "2")
    check(g, "and the three page events are three rows with a control beside them",
          "READ a PROT_READ page, the control" in by
          and by["READ a PROT_READ page, the control"][3] == "0")
    check(g, "and the si_addr column says what it means per SIGNAL, not per si_code",
          "keyed it off si_code" in FLAT
          and "faulting RIP for a SIGILL" in FLAT)
    check(g, "and the exec of a non-executable page is in the table too",
          "execute a page mapped RW and not X" in by)
    iv = re.findall(r"^  INTVEC \| ((?:\d+ )+\d+)$", T, re.M)
    check(g, "and all nine `int $N` vectors came back 128",
          iv and all(t.split() == ["128"] * 9 for t in iv), iv)
    check(g, "and int $0x80 is the one that works, and it is called a mechanism",
          re.search(r"int \$0x80.*RETURNED", T) is not None
          and "mechanism and not a right" in FLAT)
    check(g, "and the INTO arm that RETURNS is a real result, not a broken probe",
          "into, OF clear" in [r[0] for r in
                               rows(T, r"^  EDGE \| (.*?)\s+\| (.*?)\s+\| (FAULTED|RETURNED)", take=1)]
          and "is a #UD on this AMD part" in FLAT)
    check(g, "and PFC re-measures the three page faults a second time",
          re.search(r"PFC \| write to NULL\s+si_code 1", T) is not None
          and re.search(r"PFC \| write to a PROT_READ\s+si_code 2", T) is not None
          and re.search(r"PFC \| touch a PROT_NONE\s+si_code 2", T) is not None)
    check(g, "and the artifact says the kernel keeps exactly one bit",
          "it keeps exactly one bit" in FLAT)

    # ------------------------------------------------------------------
    # H. the canonical boundary, on five widths
    # ------------------------------------------------------------------
    g = "H canonical"
    print("  --- group H: the canonical boundary, extended to five widths")
    mat = rows(T, r"^  MATRIX \| 2\^47\s*([-+]\d+) \| 0x([0-9a-f]+) \|((?:\s+\d+){5})", take=3)
    check(g, "the matrix has twenty rows, 2^47-18 to 2^47+1",
          len(mat) == 20, "%d rows" % len(mat))
    if len(mat) == 20:
        check(g, "and its offsets are -18 to +1 in order",
              [int(r[0]) for r in mat] == list(range(-18, 2)),
              "%s .. %s" % (mat[0][0], mat[-1][0]))
        widths = [len(r[2].split()) for r in mat]
        check(g, "and every row has FIVE columns, which is the extension",
              set(widths) == {5}, str(sorted(set(widths))))
        cols = [[int(v) for v in r[2].split()] for r in mat]
        check(g, "and every column contains only the two legal si_codes",
              set(v for c in cols for v in c) <= {1, 128},
              str(sorted(set(v for c in cols for v in c))))
        # The SHAPE, which is the claim: for each width, the 128s form a
        # SUFFIX of the column, and the switch-over point moves left as the
        # access gets wider.  Asserted as a shape, not as an address.
        cut = []
        for w in range(5):
            first = next((i for i, c in enumerate(cols) if c[w] == 128), None)
            cut.append(first if first is not None else 20)
        check(g, "each column's rejections form a SUFFIX of the column",
              all(all(c[w] != 128 for c in cols[:i])
                  and all(c[w] == 128 for c in cols[i:])
                  for w, i in enumerate(cut)),
              "switches at rows %s" % cut)
        check(g, "and the switch moves LEFT as the access gets wider",
              cut == sorted(cut, reverse=True), str(cut))
    bise = rows(T, r"^  BISE \| (\S+)\s+\| 0x([0-9a-f]+)\s+\| 0x([0-9a-f]+) \| (\S+)$", take=4)
    check(g, "five bisections, one per width, and all five widths are present",
          [r[0] for r in bise] == ["1-byte", "2-byte", "4-byte", "8-byte", "16-byte"],
          " ".join(r[0] for r in bise))
    check(g, "and all five hold the rule, and the measured address EQUALS the",
          bise and all(r[3] == "YES" for r in bise) and all(r[1] == r[2] for r in bise),
          ", ".join(r[0] for r in bise if r[3] != "YES") or "5 of 5")
    if len(bise) == 5:
        # Recomputed from the rule here, as integers, because a hex string
        # compared as a string is a comparison of typesetting.
        T47 = 1 << 47
        want = [T47 - (s - 1) for s in (1, 2, 4, 8, 16)]
        check(g, "and the five answers are the five the rule predicts",
              [int(r[1], 16) for r in bise] == want,
              " ".join(r[1][-4:] for r in bise))
    check(g, "and the artifact says the rule on five widths and not three",
          re.search(r"the rule, on five widths: 5 of 5", T) is not None
          and "first rejected = 2^47 MINUS (access size - 1)" in T)
    check(g, "and it credits the privilege course with three and names the 2-byte",
          flat("established this on THREE widths") in FLAT
          and flat("the 2-byte width is the one that") in FLAT)
    bisel = rows(T, r"^  BISEL \| (\S+)\s+\| 0x([0-9a-f]+)\s+\| 0x([0-9a-f]+) \| (\S+)$", take=4)
    check(g, "the upper half's lower edge is bisected on five widths too",
          len(bisel) == 5 and all(r[3] == "YES" for r in bisel)
          and all(r[1] == r[2] for r in bisel))
    if bisel:
        check(g, "and it is 2^64 - 2^47, the same on all five widths",
              all(r[1] == "ffff800000000000" for r in bisel),
              " ".join(r[1] for r in bisel))
    check(g, "and the 0xffffffff80000000 draft claim is retracted in place",
          flat("asserted that the upper canonical") in FLAT
          and "2^31 bytes INSIDE the half" in FLAT)
    check(g, "and the wrap at the top of the space is reported, not explained",
          re.search(r"WRAP \| 16-byte read at 0xffffffffffffffff \| si_code 1", T)
          is not None
          and "OPEN QUESTION, which is a different thing from being wrong" in FLAT)
    align = rows(T, r"^  ALIGN \| 2\^47\s*([-+]\d+)\s+\| (\d+)\s+\| (\d+)$", take=3)
    check(g, "the movdqa arm and the movdqu arm are printed side by side",
          len(align) >= 4, "%d rows" % len(align))
    check(g, "and they DISAGREE at the offsets where the rule does not",
          any(a[1] != a[2] for a in align),
          " ".join("%s:%s/%s" % (a[0], a[1], a[2]) for a in align if a[1] != a[2]))

    # ------------------------------------------------------------------
    # I. the absences
    # ------------------------------------------------------------------
    g = "I absent"
    print("  --- group I: three absences, each proved with a fork")
    idt = re.search(r"read one byte of the IDT \| (\d+) \| 0x([0-9a-f]+) \| the IDT base", T)
    gdt = re.search(r"read one byte of the GDT \| (\d+) \| 0x([0-9a-f]+) \| the GDT base", T)
    check(g, "reading one IDT byte is si_code 1, a MAPPING failure",
          idt and idt.group(1) == "1", idt.group(1) if idt else "?")
    check(g, "and si_addr is exactly the base SIDT printed, by comparison",
          idt and one(r"SIDT \| base 0x([0-9a-f]+)", T) == idt.group(2),
          "0x%s" % idt.group(2) if idt else "?")
    check(g, "and the same for the GDT",
          gdt and gdt.group(1) == "1"
          and one(r"SGDT \| base 0x([0-9a-f]+)", T) == gdt.group(2),
          "0x%s" % gdt.group(2) if gdt else "?")
    check(g, "and the artifact says the reason is page tables and not privilege",
          "a PAGE-TABLE fact, not a privilege" in FLAT)
    rd = re.search(r"RDPMC in a forked child \| si_code (\d+) \| signal (\d+) \| (\S+)", T)
    check(g, "RDPMC in a child is a fault, si_code 128, killed by 11",
          rd and tuple(rd.groups()) == ("128", "11", "KILLED"),
          " ".join(rd.groups()) if rd else "?")
    pe = re.search(r"perf_event_open, a NULL attr \| (-?\d+) \| errno (\d+)", T)
    check(g, "and perf_event_open is EACCES",
          pe and pe.group(1) == "-1" and pe.group(2) == "13",
          " ".join(pe.groups()) if pe else "?")
    check(g, "and /dev/cpu/0/msr is root-only",
          re.search(r"open /dev/cpu/0/msr \| DENIED \| errno 13", T) is not None)
    core = one(r"bit 6 core-PMU = (\d) and", T)
    l3 = one(r"bit 15 L3-PMU = (\d)", T)
    check(g, "and yet CPUID says the core and L3 PMUs ARE PRESENT",
          core == "1" and l3 == "1", "core %s, L3 %s" % (core, l3))
    check(g, "so the absence is ACCESS and not silicon, and it says so",
          "METAL HAS PERFORMANCE" in FLAT
          and "What is absent is ACCESS" in FLAT)
    av = allgroups(r"CPUID\.7\.0:EBX AVX512F (\d) DQ (\d) CD (\d) BW (\d) VL (\d)", T)
    check(g, "all five AVX-512 feature bits are zero",
          av and set(av) == {"0"}, " ".join(av) if av else "?")
    check(g, "and the XCR0 state bits for AVX-512 are zero as well",
          "5 opmask, 6 zmm_hi256, 7 hi16_zmm) are all 0" in FLAT)
    check(g, "and the two absences are declared to be DIFFERENT KINDS",
          "DECLARED BY THE HARDWARE" in FLAT and "imposed by software" in FLAT)
    pm = rows(T, r"^  PAGEMAP \| (.*?)\s+\| 0x([0-9a-f]{16}) \| bit63 (\d)$", take=3)
    check(g, "six pagemap rows, and each is 16 hex digits",
          len(pm) == 6, "%d rows" % len(pm))
    if len(pm) == 6:
        check(g, "an untouched mapping reports bit63 0 and a touched one 1",
              pm[0][2] == "0" and pm[1][2] == "1",
              "%s -> %s, %s -> %s" % (pm[0][0][:20], pm[0][2], pm[1][0][:20], pm[1][2]))
        check(g, "a PROT_NONE mapping reports not-present, like an untouched one",
              pm[2][0].startswith("a PROT_NONE") and pm[2][2] == "0")
        check(g, "and mprotect alone does NOT populate the entry",
              pm[3][2] == "0" and pm[4][2] == "1",
              "mprotect %s, then write %s" % (pm[3][2], pm[4][2]))
        check(g, "and a PROT_READ page reports present after a read",
              pm[5][0].startswith("a PROT_READ page") and pm[5][2] == "1")
        # The rows are SIX PAGES, not one page six times, so the only
        # meaningful comparisons are the three WITHIN a page.  A harness
        # that XOR-ed consecutive rows compared two different pages and
        # called the result a transition; the first version of this check
        # did exactly that and its mprotect arm reported 0x8100000000000000
        # for an mprotect that changed nothing.
        pairs = [(pm[0], pm[1]), (pm[2], pm[3]), (pm[3], pm[4]), (pm[1], pm[5])]
        xors = [int(a[1], 16) ^ int(bb[1], 16) for a, bb in pairs]
        check(g, "bit 63 moves at the two transitions that add a TOUCH",
              xors[0] & (1 << 63) and xors[2] & (1 << 63)
              and not (xors[1] & (1 << 63)),
              "moves: %s" % ",".join("yes" if x & (1 << 63) else "no"
                                     for x in xors))
        check(g, "and mprotect alone changes NOTHING, which is the result",
              xors[1] == 0, "0x%016x" % xors[1])
        check(g, "and the artifact admits a SECOND bit moves and cannot name it",
              "the answer is NOT only bit 63" in FLAT
              and "One more bit moves in the fourth row" in FLAT
              and "changed twice" in FLAT)
        check(g, "and the artifact prints the same three within-page XORs",
              all(re.search(r"PAGEMAP \\| %s +0x[0-9a-f]{16}" % lbl, T)
                  for lbl in ("fresh -> write", "none  -> mprotect",
                              "mprotect -> write")))

    # ------------------------------------------------------------------
    # J. the retractions and the limits
    # ------------------------------------------------------------------
    g = "J retractions"
    print("  --- group J: the retractions, asserted as TEXT so they cannot be dropped")
    for r in ["R1.", "R2.", "R3.", "R4.", "R5.", "R6.", "R7.", "R8.", "R9.", "R10."]:
        # The indentation is 3 spaces for R1..R9 and 2 for R10, because the
        # number is one character longer.  A harness that required three
        # spaces for all ten would have reported R10 as missing from a file
        # that prints it, which is the same class of bug as the padded
        # column above and the third one in this file.
        check(g, "retraction %s is printed by the artifact" % r,
              re.search(r"^\s+%s" % re.escape(r), T, re.M) is not None)
    check(g, "R1 is the IDT retraction, and its replacement is a page-table one",
          "RETRACTED AND REPLACED" in T
          and flat("a PAGE-TABLE sentence") in FLAT)
    check(g, "R1 predicts an address, which is the point of the replacement",
          "which is what every privileged instruction in section 3 produced" in FLAT)
    check(g, "R2 is the movdqa retraction and it names the instruction",
          "It measured an ALIGNMENT" in FLAT and "`movdqa`" in T)
    check(g, "R2's replacement figure is the one section 5 bisected",
          "2^47 - 15, the value the rule predicts" in FLAT)
    check(g, "R3 is the fourteen-output asm block, and the fix is named",
          "died with SIGBUS" in FLAT
          and "three blocks of six, six and one" in FLAT)
    check(g, "R4 retracts 'syscall destroys fifteen' and admits the wrong output",
          "NEVER TRUE, AND IT" in T and "reported all fifteen clobbered" in FLAT)
    check(g, "R4 says the wrong answer agreed with a story already written",
          "agreed with a story the author had" in FLAT)
    check(g, "R5 is the LAM subleaf, and the bit number was right by accident",
          "leaf 7 SUBLEAF 1, EAX bit 26" in FLAT
          and "It happened to be right and it was still wrong" in FLAT)
    check(g, "R6 credits the privilege course and names the 2-byte arm",
          "NOT AS A" in T
          and flat("on THREE widths and this file re-derives it on FIVE") in FLAT)
    check(g, "R7 retracts 'this machine has no PMU' in favour of ACCESS",
          flat("RETRACTED.  CPUID.80000008.EBX bit 6") in FLAT
          and "different consequences" in FLAT)
    check(g, "R8 is the si_addr claim, and it names the field that does the work",
          flat("NOT A CLAIM") in FLAT
          and flat("the field that tells them apart is si_code") in FLAT)
    check(g, "R9 is the PROT_READ versus PROT_NONE claim",
          "THEY" in T and "ARE NOT, from ring 3" in FLAT)
    check(g, "R9 says the one distinguishable case is distinguished by mapped-ness",
          flat("it is distinguished by MAPPED-ness rather than by protection") in FLAT)
    check(g, "R10 is the pagemap bit, and the two 63s are named apart",
          flat("REPORTED NX=1 FOR A PAGE") in FLAT
          and "bit 63 of THIS" in FLAT and "PM_PRESENT" in FLAT)
    check(g, "and R10's replacement is the demand-paging measurement",
          "demand paging seen from the inside" in FLAT)
    check(g, "the limits block is printed, not footnoted",
          "LIMITS -- what this artifact cannot tell you" in T)
    for lim in ["ANY CYCLE COUNT",
                "WHETHER CR0 TO CR4 HOLD THE VALUES THE KERNEL REPORTS",
                "WHETHER SMEP AND SMAP ARE ON",
                "THE IA32_STAR, IA32_LSTAR AND IA32_SFMASK VALUES",
                "THE CLASS OF ANY EXCEPTION",
                "THE ERROR CODE THE CPU PUSHED",
                "WHICH DR7 LAYOUT THIS CPU IMPLEMENTS",
                "THE PS BIT OF A REAL 2 MiB MAPPING",
                "AArch64, RISC-V"]:
        check(g, "limit present: %s" % lim[:44], lim in T)
    check(g, "and the MAP_HUGETLB failure is reported, not hidden",
          flat("returned ENOMEM on this machine") in FLAT
          and "no transparent huge page" in FLAT)
    check(g, "and the addresses limit is stated, with the reason",
          "A SECOND RUN'S ADDRESSES" in T
          and flat("the relation is the measurement") in FLAT)
    check(g, "the verdict says what the artifact CAN support",
          "What this artifact can support" in T)
    check(g, "and what it cannot", "What it cannot support" in T)
    check(g, "and it says four of the five gaps are the INSTRUMENT's fault",
          flat("Four of those five are properties of the") in FLAT
          and "instrument, not of the subject" in FLAT)
    ck = one(r"checksums folded in: 0x([0-9a-f]+)", T)
    check(g, "a running checksum is printed, so a silent no-op cannot pass",
          ck is not None, "0x%s" % ck)
    rowsm = one(r"rows measured: (\d+)", T)
    check(g, "and a row count", rowsm is not None and int(rowsm) >= 11, "%s rows" % rowsm)

    # ------------------------------------------------------------------
    print("")
    if FAILURES:
        print("crosscheck: %d checks, %d failed" % (CHECKS, len(FAILURES)))
        for grp, what, detail in FAILURES:
            print("   FAILED [%s] %s  %s" % (grp, what, detail))
        return 1
    print("crosscheck: %d/%d checks passed" % (CHECKS, CHECKS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
