#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The x86-64 Data Path: Atomics, Ordering
and Vectors".

It reads the OUTPUT of vecdump and checks eleven groups of claims.  It does
not re-measure anything, and it asserts almost no numbers.

WHY SO LITTLE IS ASSERTED NUMERICALLY, in this file's own words: vecdump
section 1 measures the spread of its own estimator and prints it BEFORE
any claim, the machine is a virtualised guest with twelve logical CPUs and
other work on it, and three of this collection's harnesses have already
been broken by a threshold that was a bare number.  So:

  * STRUCTURAL claims are asserted EXACTLY, because they are exact: every
    vector-load encoding; every FENCE opcode and its ModRM reg field; the
    LOCK-implicit set; the encoder's thirty byte strings and the round
    trip; the EFLAGS bit positions; the presence of all twenty-four
    retractions and all eleven limits;
  * BOUNDARY claims are asserted as a SET and a PARTITION: which of the
    ten vector loads fault on a misaligned address, and the fact that
    the legacy and VEX forms agree about it;
  * ATOMICITY claims are asserted as a SET: which arms are exact and
    which lose updates, because that is a verdict and not a number, and
    the numbers move between runs;
  * the ONE timing-shaped claim in the file is asserted as an ORDERING and
    a RATIO, never as a value;
  * everything else in this file is a fault, a bit pattern, an exact
    arithmetic identity, or a string, and those do not move between runs.

The harness exists to catch a future edit that quietly changes a claim.
In particular it asserts the PRESENCE of all twenty-four retractions, it
asserts that the fence opcodes are the three the SDM names, and it
asserts that the ENCODER's thirty rows cross-checked against objdump --
because a round trip alone is a tautology and R9 is the retraction that
proves it.  It also asserts R23, which is the retraction about the
CROSS-CHECK: that check reported 28 disagreements out of 30 for a whole
run and was believed, because its reader was counting objdump's section
header as row 0 and so compared every row against its neighbour.  The
harness now pins the skip counts, so a loader that stops skipping is a
visible regression rather than a plausible-looking column of failures.

Usage:  python3 crosscheck.py [path/to/vecdump.out]
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
    before vecdump is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "vecdump.out")


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


def rows(text, pat, take=None):
    """Every line of a table that matches `pat`, as a token list.

    The ORDER matters: a table whose rows were reordered is a different
    table, and a check that only looked at the contents would not notice."""
    pat = re.compile(pat)
    out = []
    for ln in text.splitlines():
        m = pat.match(ln)
        if m:
            out.append(m.groups()[:take] if take is not None else ln.split())
    return out


def table(text, tag, first=None, last=None):
    """A PIPE-DELIMITED table, as a list of cell lists, header dropped.

    Why this exists, in this file's own words: a regex written against a
    column-aligned table is a regex written against the artifact's
    WHITESPACE, and the artifact is free to re-align a column without
    changing a single claim.  Three of the tables here have already been
    re-aligned at least once while fixing a typo two lines away.  Splitting
    on the pipe and stripping each cell is the only parse of these tables
    that does not encode the padding.

    `tag` is the two-space-indented leftmost column, e.g. "ALIGN".  `first`
    and `last`, when given, are substrings the first and last cell must
    contain; that is how the HEADER and the RULE lines are dropped, without
    a second regex and a second place to get it wrong."""
    out = []
    for ln in text.splitlines():
        if not re.match(r"^  %s\s*\|" % re.escape(tag), ln):
            continue
        cells = [c.strip() for c in ln.split("|")]
        cells = cells[1:]                       # drop the tag column
        if not cells or not cells[0]:
            continue
        if first is not None and first not in cells[0]:
            continue
        if last is not None and not (last in cells[-1]):
            continue
        out.append(cells)
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
    # The sign is OPTIONAL and the plus is accepted, because the artifact
    # prints the sign when the drift is positive and the first version of
    # this regex did not, so a run that happened to drift UP was reported
    # as "no drift line at all" -- which is a different and much worse
    # claim than the one the number supports.
    drift = one(r"drift\s+([-+]?[\d.]+) %", T)
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
    check(g, "and the consequence is stated: durations are not counts",
          "BOUNDS A COUNT WITHOUT MEASURING IT" in FLAT)
    check(g, "the CPUID census is printed, not assumed",
          "CPUID.1:ECX SSE2" in T and "CPUID.7.0:EBX AVX2" in T)
    av = one(r"CPUID\.7\.0:EBX AVX512F (\d) DQ (\d) CD (\d) BW (\d) VL (\d)", T)
    check(g, "all five AVX-512 feature bits are zero",
          av and set(av.split()) == {"0"}, " ".join(av.split()) if av else "?")
    xcr = re.findall(r"XCR0 opmask (\d)\s+zmm_hi256 (\d)\s+hi16_zmm (\d)", T)
    check(g, "and the XCR0 state bits for AVX-512 are zero as well",
          xcr == [("0", "0", "0")], " ".join("".join(t) for t in xcr))
    # XCR0 = 0x207 is bits 0, 1, 2 and 9.  Bits 0/1/2 are x87, SSE and AVX
    # and are the ones the vector sections depend on; bit 9 is PKRU, which
    # the kernel sets for reasons that have nothing to do with vectors.  The
    # exact set is asserted rather than allowed, because "no higher bit is
    # set" is not true on this machine and a harness that claimed it would
    # be asserting something the CPUID output contradicts.
    xv = one(r"XCR0 (0x[0-9a-f]{16})", T)
    xbits = set(b for b in range(32) if xv and (int(xv, 16) >> b) & 1)
    check(g, "and XCR0's set bits are exactly {0,1,2,9}, named",
          xv == "0x0000000000000207" and xbits == {0, 1, 2, 9},
          "%s = bits %s" % (xv, sorted(xbits)))
    check(g, "and bits 5, 6 and 7 -- the three this course is about -- are clear",
          not (xbits & {5, 6, 7}), "opmask/zmm_hi256/hi16_zmm clear")
    # The gate on XGETBV is CR4.OSXSAVE, and a direct CR4 read FAULTS in
    # this environment.  The artifact therefore INFERS it -- a returning
    # XGETBV proves OSXSAVE is set, because the alternative is #UD -- and
    # the harness accepts either the direct read or the inference.  What it
    # does NOT accept is silence, and it does not accept a value that was
    # never established by either route.
    check(g, "the OSXSAVE gate is established, directly or by inference",
          re.search(r"CR4\.OSXSAVE \(bit 18\) = (\d|\?)", T) is not None
          and ("XGETBV is #UD" in T),
          "OSXSAVE = %s" % (one(r"CR4\.OSXSAVE \(bit 18\) = (\d|\?)", T) or "?"))
    check(g, "the artifact says the vectors flags are load-bearing",
          "NOT ONE of the instructions this file executes" in FLAT
          and "NOT ONE of them needs bit 5, 6 or 7" in FLAT
          and "raises #UD" in FLAT)
    check(g, "and distinguishes CPUID (the silicon) from XCR0 (the OS's promise)",
          "CPUID is what the SILICON has" in FLAT
          and "XCR0 is what the" in FLAT
          and "can have the first without the second" in FLAT)
    check(g, "and says the #UD is not the #GP of section 2",
          "#GP\n  in section 2" in FLAT or "#GP in section 2" in FLAT)

    # ------------------------------------------------------------------
    # B. the oracle, and the FENCE encodings
    # ------------------------------------------------------------------
    g = "B oracle"
    print("  --- group B: the tables that are exact, or nothing")
    check(g, "the oracle is labelled as NOT measured",
          "PRINTED AND NOT\n     MEASURED" in T or "PRINTED AND NOT" in FLAT
          and "MEASURED" in T)
    # The SSE alignment table, parsed by the pipe and NOT by the padding.
    # The MOVE table's leftmost column is the MNEMONIC, which is also the
    # table's row tag, so it is kept rather than dropped the way table()
    # drops a single-token tag.
    mv = []
    for ln in T.splitlines():
        if re.match(r"^  (MOVAPS|MOVUPS|MOVDQA|MOVDQU|MOVSS|MOVSD|MOVLPD|LDDQU)\s*\|", ln):
            mv.append([c.strip() for c in ln.split("|")])
    check(g, "the SSE alignment table names MOVAPS and its three siblings",
          [r[0] for r in mv][:4] == ["MOVAPS", "MOVUPS", "MOVDQA", "MOVDQU"]
          and [r[1] for r in mv][:4] == ["28", "10", "6F", "6F"]
          and [r[3] for r in mv][:4] == ["16 byte", "none", "16 byte", "none"],
          " ".join("%s=%s/%s" % (r[0], r[1], r[3]) for r in mv[:4]))
    check(g, "and the four rows are in the order the table prints them",
          [r[0] for r in mv]
          == ["MOVAPS", "MOVUPS", "MOVDQA", "MOVDQU", "MOVSS", "MOVSD",
              "MOVLPD", "LDDQU"])
    check(g, "and LDDQU is the one LOAD that never faults, and says so",
          [r[3] for r in mv][-1] == "none"
          and "explicitly never faults" in [r[4] for r in mv][-1])
    check(g, "the VEX shapes are printed with their field tables",
          "VEX2  C5  R~ v~3 v~2 v~1 v~0 L p1 p0" in T
          and "VEX3  C4  R~ X~ B~ m4 m3 m2 m1 m0" in T
          and "EVEX  62  R~ X~ B~ R~' 0 m2 m1 m0" in T)
    check(g, "and the artifact says VEX2 has NO MAP FIELD",
          "NO MAP\n  FIELD in the two-byte form at all" in FLAT
          or "NO MAP FIELD" in FLAT.replace("  ", " "))
    # The operand map, asserted as a SET of three pairs rather than as one
    # column-aligned string, for the reason in table()'s docstring.
    opmap = {}
    for m in re.finditer(r"ModRM\.reg\s*=\s*(\S+)\s+vvvv\s*=\s*(\S+)\s+"
                         r"ModRM\.rm\s*=\s*(\S+)", FLAT):
        opmap = {"reg": m.group(1), "vvvv": m.group(2), "rm": m.group(3)}
    check(g, "the operand map is stated, because it is not in any table",
          opmap == {"reg": "DEST", "vvvv": "SRC1", "rm": "SRC2"},
          " ".join("%s=%s" % (k, v) for k, v in sorted(opmap.items())))
    # The three L'L values, asserted as a SET.  L'L = 00 is spelled in
    # words ("no vector length in this instruction") rather than as a bit
    # count, so the regex takes either.
    ll = {}
    for m in re.finditer(r"L'L = (\d\d)\s+(?:(\d+) bit|no vector length)", FLAT):
        ll[m.group(1)] = m.group(2) or "none"
    check(g, "and the EVEX L field is printed as TWO bits",
          ll == {"00": "none", "10": "128", "11": "512"}, str(ll))

    # the three fence opcodes, asserted to the byte
    check(g, "MFENCE is 0f ae f0 and its reg field is 7",
          re.search(r"MFENCE\| 0f ae f0\s+\| 111 = 7", T) is not None)
    check(g, "LFENCE is 0f ae e8 and its reg field is 5",
          re.search(r"LFENCE\| 0f ae e8\s+\| 101 = 5", T) is not None)
    check(g, "SFENCE is 0f ae f8 and its reg field is 7",
          re.search(r"SFENCE\| 0f ae f8\s+\| 111 = 7", T) is not None)
    check(g, "and the artifact says all three are the SAME opcode",
          "all three are the SAME opcode, 0F AE" in FLAT)
    check(g, "and that MFENCE and SFENCE COLLIDE in the reg field",
          "MFENCE and SFENCE share" in FLAT and "reg value 7" in FLAT)
    check(g, "and that the difference is TWO bits, not one",
          "reg field differs in TWO bit positions and not one" in FLAT)
    check(g, "the eighteen-instruction LOCK list is printed in full",
          all(w in FLAT for w in ["ADD ADC AND BTC BTR BTS CMPXCHG CMPXCHG8B",
                                 "CMPXCHG16B", "DEC INC NEG NOT OR SBB SUB XOR",
                                 "XADD XCHG"]))
    # NOTE the case.  The artifact SHOUTS this one, because the mistake is
    # so common that a quiet sentence would be missed by the reader who is
    # most likely to make it.  A needle that is shouted must be shouted.
    check(g, "and BT is named as the instruction that is NOT on it",
          "THE INSTRUCTION WITH NO LOCK IS 'BT'" in FLAT
          and "BTC, BTR and BTS are on" in FLAT)
    check(g, "and the XCHG sentence is quoted, not paraphrased",
          "regardless of the presence or" in FLAT
          and "absence of the LOCK prefix" in FLAT)

    # ------------------------------------------------------------------
    # C. the direction flag, and the correction
    # ------------------------------------------------------------------
    g = "C eflags"
    print("  --- group C: EFLAGS, and a bit number that was wrong")
    ef = one(r"EFLAGS as read by PUSHFQ\s+0x([0-9a-f]+)", T)
    check(g, "the flags were read out of the register here", ef is not None,
          "0x%s" % ef if ef else "?")
    for bit, name in [("10", "DF, THE DIRECTION"), ("21", "ID, NOT DIRECTION"),
                      ("0", "CF"), ("2", "PF"), ("6", "ZF"), ("9", "IF"),
                      ("11", "OF"), ("16", "RF"), ("18", "AC")]:
        check(g, "bit %s is printed and named %r" % (bit, name),
              re.search(r"bit\s+%s\s+%s\s+(\d)" % (bit, re.escape(name)), T)
              is not None)
    check(g, "the artifact retracts the draft's bit 21 in public",
          "The direction flag is EFLAGS bit 21" in FLAT
          and "Bit 10 is DF" in FLAT)
    check(g, "and says what bit 21 is actually for",
          "ID flag" in FLAT and "identification" in FLAT.lower() + FLAT)
    check(g, "and the ID flag's history is stated",
          "SETTING a bit it was not supposed" in FLAT
          and "The 8086 and 8088" in FLAT)
    check(g, "and the two flags are named as sharing nothing",
          "The two flags" in FLAT and "nothing in common" in FLAT)

    # ------------------------------------------------------------------
    # D. the alignment set, as a SET
    # ------------------------------------------------------------------
    g = "D alignment"
    print("  --- group D: which loads fault, and which do not")
    # The artifact prints this table TWICE: once as the result of section 2,
    # once inside retraction R15 where the claim it retracts is restated.
    # That is deliberate -- a retraction that only names the wrong claim and
    # not the measurement that replaces it is half a retraction -- so the
    # harness asserts the two copies are IDENTICAL rather than quietly
    # counting twenty rows and dividing by two.
    all_al = table(T, "ALIGN")
    check(g, "the table is printed twice, once in section 2 and once in R15",
          len(all_al) == 20, "%d rows" % len(all_al))
    half = len(all_al) // 2
    check(g, "and the two prints are the SAME table, row for row",
          len(all_al) == 2 * half and all_al[:half] == all_al[half:],
          "first row: %s" % (all_al[0][0] if all_al else "-"))
    al = all_al[:half]
    check(g, "ten probes were run, one instruction each", len(al) == 10,
          "%d rows" % len(al))
    check(g, "and every one of them returned on an ALIGNED address",
          all(r[1].endswith("returned") for r in al),
          ", ".join(r[0] for r in al if not r[1].endswith("returned")) or "10 of 10")
    want_segv = ["vmovapd load", "vmovapd store", "vmovdqa load",
                 "movaps load", "vmovaps load", "vmovdqa load"]
    got_segv = [r[0] for r in al if r[2].endswith("SIGSEGV")]
    check(g, "every ALIGNED form faults at +8 bytes, VEX and legacy alike",
          got_segv == want_segv,
          "faulting: " + ", ".join(got_segv))
    want_ret = ["vmovupd load", "vmovupd store", "vmovdqu load", "movups load"]
    got_ret = [r[0] for r in al if r[2].endswith("returned")]
    check(g, "and every UNALIGNED form returns",
          got_ret == want_ret, "returning: " + ", ".join(got_ret))
    # The partition is over ROWS, not over NAMES.  "vmovdqa load" appears
    # twice on purpose -- once with a legacy prefix and once with a VEX one
    # -- and those are two probes that happen to share a spelling.  A set of
    # names would collapse them to one and the count would be nine.
    check(g, "so the two sets PARTITION the ten probes",
          not (set(got_segv) & set(got_ret))
          and len(got_segv) + len(got_ret) == 10
          and sorted(got_segv + got_ret) == sorted(r[0] for r in al),
          "%d faulting + %d returning = %d" % (len(got_segv), len(got_ret),
                                               len(got_segv) + len(got_ret)))
    check(g, "and the duplicated name is the point: vmovdqa load, twice",
          [r[0] for r in al].count("vmovdqa load") == 2
          and [r[3] for r in al if r[0] == "vmovdqa load"]
          == ["legacy encoding", "VEX encoding"])
    check(g, "and the two VEX rows are labelled as VEX",
          [r[0] for r in al if r[3] == "VEX encoding"]
          == ["vmovaps load", "vmovdqa load"])
    check(g, "and the other eight are labelled legacy",
          len([r for r in al if r[3] == "legacy encoding"]) == 8)
    check(g, "the artifact retracts the 'VEX removed the requirement' claim",
          "THE VEX PREFIX WAS WRONG" in FLAT and "R15" in FLAT)
    check(g, "and quotes the SDM's own alignment sentence",
          "16-byte (128-bit version), 32-byte (VEX.256)" in FLAT
          and "or 64-byte (EVEX.512) boundary" in FLAT)
    check(g, "and says what AVX actually relaxed",
          "FUSED memory operands" in FLAT
          and "the move instructions were" in FLAT)
    check(g, "the limits of the probe are printed",
          "ONLY ONE MISALIGNMENT WAS MEASURED" in T
          or "ONE misalignment was measured" in FLAT)

    # ------------------------------------------------------------------
    # E. the dirty-upper-bits bit patterns
    # ------------------------------------------------------------------
    g = "E dirty"
    print("  --- group E: what a YMM register's upper half holds")
    # Split by the pipe, then split the trailing cell on its last word, so
    # the verdict is read as a VERDICT and the pattern as a 32-bit value
    # rather than as two halves of one padded column.
    dt = table(T, "DIRTY")
    check(g, "seven bit patterns were read", len(dt) == 7, "%d rows" % len(dt))
    by = {}
    pat = {}
    for r in dt:
        label = r[0]
        verdict = r[-1].split()[-1]
        by[label] = verdict
        m = re.search(r"0x([0-9a-f]{8})", r[-1])
        pat[label] = m.group(1) if m else None
    check(g, "the control PRESERVES the upper halves",
          by.get("no instruction (the control)") == "PRESERVED")
    check(g, "a LEGACY SSE instruction PRESERVES them, which is the finding",
          by.get("ONE legacy addps   0f 58") == "PRESERVED"
          and by.get("ONE legacy movaps  0f 28") == "PRESERVED")
    check(g, "a VEX-128 instruction ZEROES them",
          by.get("ONE VEX-128 vaddps c5 f8 58") == "ZEROED")
    check(g, "vzeroupper ZEROES them",
          by.get("vzeroupper         c5 f8 77") == "ZEROED")
    check(g, "and two of either do the same as one",
          by.get("TWO legacy addps") == "PRESERVED"
          and by.get("TWO vzeroupper") == "ZEROED")
    check(g, "so the DIRTY set is a PARTITION of the seven rows",
          set(by.values()) == {"PRESERVED", "ZEROED"}
          and len([v for v in by.values() if v == "ZEROED"]) == 3)
    # The PRESERVED rows must all show the SAME non-zero pattern.  That is
    # the whole finding: the bits were written, they are still there, and
    # the ZEROED rows are all 0x00000000.
    check(g, "and every PRESERVED row shows the SAME non-zero pattern",
          len(set(pat[k] for k, v in by.items() if v == "PRESERVED")) == 1
          and list(pat.values())[0] not in (None, "00000000"),
          " ".join(sorted(set(pat[k] for k, v in by.items()
                              if v == "PRESERVED"))))
    check(g, "and every ZEROED row is 0x00000000",
          all(pat[k] == "00000000" for k, v in by.items() if v == "ZEROED"))
    check(g, "the artifact says this CONTRADICTS the usual story",
          "CONTRADICTS THE STORY IN ITS USUAL FORM" in FLAT)

    # ------------------------------------------------------------------
    # F. the atomic set, as a SET OF VERDICTS
    # ------------------------------------------------------------------
    g = "F atomics"
    print("  --- group F: which arms are atomic, as a set and not a number")
    # A verdict column is what makes a row a data row here: the header ends
    # in "verdict", so `last="ATOMIC"` (which "NOT ATOMIC" also contains)
    # drops the header and the rule without naming either of them.
    at = table(T, "CNT", last="ATOMIC")
    check(g, "and the header and rule lines are NOT counted as arms",
          not any(r[0].lower() == "instruction" for r in at))
    check(g, "the CNT table has at least twenty arms", len(at) >= 20,
          "%d rows" % len(at))
    exact = set(r[0].strip() for r in at if r[4].strip() == "ATOMIC")
    lost = set(r[0].strip() for r in at if r[4].strip() == "NOT ATOMIC")
    check(g, "every row carries a verdict, and the two verdicts partition them",
          exact and lost and not (exact & lost)
          and len(exact) + len(lost) == len(at))
    for want in ["add $1,        LOCK", "inc,           LOCK",
                 "dec,           LOCK", "xadd $1,       LOCK",
                 "cmpxchg loop,  LOCK", "cmpxchg8b,     LOCK",
                 "cmpxchg16b,    LOCK"]:
        check(g, "%s is exact, and the harness checks it by NAME" % want.split(",")[0],
              want in exact, want)
    for want in ["add $1,        no LOCK", "inc,           no LOCK",
                 "xadd $1,       NO PREFIX", "cmpxchg loop,  NO PREFIX",
                 "cmpxchg8b,     NO PREFIX", "cmpxchg16b,    NO PREFIX"]:
        check(g, "%s loses updates" % want.split(",")[0].strip(),
              want in lost, want)
    # The target column must be PRINTED on every row, but it is not always
    # POSITIVE: `btc $0, TOGGLES` starts from a zero word and must end at
    # one, so its target is legitimately 0.  Asserting > 0 would be
    # asserting a fact about the bit-test group that is not true.
    check(g, "and the CNT table's target column is printed on every row",
          all(re.match(r"^\d+$", r[2]) for r in at),
          "%d rows, %d of them targeting zero"
          % (len(at), len([r for r in at if r[2] == "0"])))
    # the encodings, asserted to the byte
    for want, byt in [("add $1,        LOCK", "f0 83 00 01"),
                      ("inc,           LOCK", "f0 ff 00"),
                      ("dec,           LOCK", "f0 ff 08"),
                      ("xadd $1,       LOCK", "f0 0f c1 01"),
                      ("cmpxchg loop,  LOCK", "f0 0f b1 01"),
                      ("cmpxchg8b,     LOCK", "f0 0f c7 01"),
                      ("cmpxchg16b,    LOCK", "f0 48 0f c7 01"),
                      ("add $1,        no LOCK", "83 00 01"),
                      ("xadd $1,       NO PREFIX", "0f c1 01")]:
        row = [r for r in at if r[0].strip() == want]
        check(g, "the encoding of %s is %s" % (want.split(",")[0].strip(), byt),
              bool(row) and row[0][1] == byt,
              row[0][1] if row else "no row")

    pr = table(T, "PAIR", last="ATOMIC")
    check(g, "the PAIR table has at least ten arms", len(pr) >= 10,
          "%d rows" % len(pr))
    pex = set(r[0].strip() for r in pr if r[4].strip() == "ATOMIC")
    plot = set(r[0].strip() for r in pr if r[4].strip() == "NOT ATOMIC")
    check(g, "and the two verdicts partition it",
          pex and plot and not (pex & plot)
          and len(pex) + len(plot) == len(pr))
    for want in ["or  $0,        NO PREFIX", "and $0xffffffff,NO PREFIX",
                 "xor $0,        NO PREFIX", "sub $0,        NO PREFIX",
                 "xor $0x80000000,NO PREFIX", "adc $0,        NO PREFIX",
                 "sbb $0,        NO PREFIX"]:
        check(g, "%s LOSES INCREMENTS, which is the section's finding"
              % want.split(",")[0].strip(), want in plot, want)
    for want in ["or  $0,        LOCK", "and $0xffffffff,LOCK",
                 "xor $0,        LOCK", "sub $0,        LOCK",
                 "xor $0x80000000,LOCK"]:
        check(g, "%s is exact" % want.split(",")[0].strip(), want in pex, want)
    idn = table(T, "IDENT", last="RESTORED") + table(T, "IDENT", last="NOT ATOMIC")
    check(g, "the IDENT table has four arms", len(idn) == 4, "%d rows" % len(idn))
    ib = {r[0].strip(): r[3].strip() for r in idn}
    check(g, "the LOCKED not and neg both RESTORE",
          ib.get("not, twice,    LOCK") == "RESTORED"
          and ib.get("neg, twice,    LOCK") == "RESTORED")
    # NOT "at least one unprefixed arm fails to restore".  R3 is the
    # retraction that says a lost-update COUNT is not a test for
    # atomicity in general, and NOT/NEG are the two instructions where it
    # bites hardest: they are involutions, so an EVEN number of racing
    # applications returns the word to where it started whether or not
    # either was lost.  An unprefixed `not` reading RESTORED is therefore
    # the EXPECTED reading and not a pass, and a harness that required it
    # to fail would be asking the instrument to prove the retraction
    # wrong.  What is asserted is the honest thing: the table cannot
    # distinguish these two arms, and the artifact says so.
    check(g, "R3: the involution arms cannot be told apart by this "
             "instrument, and that is stated",
          "NOT and NEG are involutions" in FLAT
          and "returns the word to where it started WHETHER OR NOT the" in FLAT)
    check(g, "R3: and the IDENT table is labelled as unable to decide",
          "the only thing that can break it" in FLAT
          and "what this instrument can say" in FLAT)
    check(g, "and every IDENT arm prints a 32-bit final word",
          all(re.match(r"^0x[0-9a-f]{8}$", r[2]) for r in idn))
    check(g, "the CNT table's bit-test rows name the shape, not just the result",
          "TOGGLES" in T and "IDEMPOTENT" in T)
    check(g, "and the artifact says BTS and BTR are not testable here",
          "NOT TESTABLE with this instrument" in FLAT)
    check(g, "the four failed versions of the instrument are written out",
          all(v in FLAT for v in ["PER-THREAD hash set", "SHARED set needs",
                                  "counted CLOBBERS", "PAIRED COUNTER"]))

    # ------------------------------------------------------------------
    # G. the store buffer, as an ORDERING
    # ------------------------------------------------------------------
    g = "G ordering"
    print("  --- group G: the fences, asserted as orderings and ratios")
    # take=2 so the two CAPTURE GROUPS come back, not ln.split(): the row
    # key is a whole phrase with spaces in it and a whitespace split would
    # return the first word only, which is "store" for six of the seven.
    od = rows(T, r"^  ORD  \| (.+?)\s+([\d.]+) ticks/iter$", take=2)
    check(g, "seven arms were timed", len(od) == 7, "%d rows" % len(od))
    # The rows are written as a continuation list, so four of the seven
    # begin with "...with" or "THE FLOOR:" and their keys are the WHOLE
    # row, not a leading word.  Match on the distinctive phrase in each.
    v = {}
    for r in od:
        key = r[0]
        if "no flag" in key: v["plain"] = float(r[1])
        elif "SFENCE" in key: v["sfence"] = float(r[1])
        elif "MFENCE" in key: v["mfence"] = float(r[1])
        elif "LOCKED store" in key: v["locked"] = float(r[1])
        elif "ONE cache line" in key: v["same"] = float(r[1])
        elif "the store alone" in key: v["floor_store"] = float(r[1])
        elif "the peer load alone" in key: v["floor_load"] = float(r[1])
    check(g, "all seven are keyed and present", len(v) == 7, str(sorted(v)))
    if len(v) == 7:
        # NOT "MFENCE is the maximum".  MFENCE and the LOCKED store are
        # within a few percent of each other and which one wins moves
        # between runs, so that would be a bare number dressed as a
        # shape.  The shape is the ORDER: both full fences cost far more
        # than the store-ordering one, and both cost more than no fence.
        check(g, "both FULL fences cost more than the store-ordering one",
              v["mfence"] > v["sfence"] and v["locked"] > v["sfence"],
              "mfence %.1f, locked %.1f, sfence %.1f"
              % (v["mfence"], v["locked"], v["sfence"]))
        # NOT "the same-line arm is the maximum".  It and MFENCE are within
        # a factor of a few of each other and which one wins moves between
        # runs, so naming a winner would be a bare number dressed as a
        # shape -- the same mistake R24's broken table made.  What holds
        # every run is that the two COSTLY arms are the same-line arm and
        # MFENCE, and both dwarf the plain one.
        top2 = sorted(v, key=v.get, reverse=True)[:2]
        check(g, "the two expensive arms are the same-line one and MFENCE",
              set(top2) == {"same", "mfence"},
              "top two: %s" % ", ".join(top2))
        check(g, "and both dwarf the plain arm, by at least 1.5x each",
              v["same"] > 1.5 * v["plain"] and v["mfence"] > 1.5 * v["plain"],
              "same %.2fx, mfence %.2fx" % (v["same"] / v["plain"],
                                            v["mfence"] / v["plain"]))
        check(g, "an SFENCE costs more than no fence, and that is the result",
              v["sfence"] > v["plain"], "%.2fx" % (v["sfence"] / v["plain"]))
        # R24.  The broken instrument had the two words SHARING a line, so
        # the "two lines" arm was secretly the "one line" arm and the
        # "floor" was secretly a ping-pong.  What the fixed instrument
        # shows, and what is asserted here, is the OPPOSITE of what the
        # broken one showed: the same-line arm is the WORST by a wide
        # margin, and the two floors are the same size as each other and
        # the same size as the plain arm, because all three are L1 hits.
        # There is no "the floor is below" claim, because on this machine
        # there is not one to make, and a harness that invented a floor
        # would be asserting a measurement the artifact does not make.
        # 1.5x, not 2x.  Six runs of the fixed instrument put this ratio
        # between 2.0x and 3.4x, so 2x is inside the spread and would fail
        # a run that is merely unlucky.  1.5x is below every observed value
        # and still far above the 1.0x that the broken instrument's own
        # arithmetic produced, which is the only thing this check has to
        # distinguish.  A threshold is a CLAIM about where the number
        # cannot go, and it is written down here so a future reader knows
        # it was chosen rather than guessed.
        check(g, "R24: one cache line is far worse than two lines",
              v["same"] > 1.5 * v["plain"],
              "%.2fx over the two-line arm" % (v["same"] / v["plain"]))
        check(g, "R24: and it is worse than the no-flag arm as well",
              v["same"] > v["plain"],
              "%.1f vs %.1f" % (v["same"], v["plain"]))
        check(g, "R24: the two floors are within a factor of two of each "
                 "other, which is what an L1 hit looks like",
              0.5 < v["floor_store"] / v["floor_load"] < 2.0,
              "%.2fx" % (v["floor_store"] / v["floor_load"]))
        check(g, "R24: and neither floor is more than 2x the plain arm",
              v["floor_store"] < 2 * v["plain"] and v["floor_load"] < 2 * v["plain"],
              "%.1f, %.1f vs %.1f" % (v["floor_store"], v["floor_load"], v["plain"]))
        # The layout is PRINTED and checked, because two of the three parts
        # of R24 were layout bugs that produced plausible numbers.
        check(g, "R24: the layout is printed, not asserted in a comment",
              "THE LAYOUT, printed because R24 was a layout bug" in T)
        check(g, "R24: and the two 'mine' lines are 64 bytes apart",
              re.search(r"'mine' lines are\s+(\d+) bytes apart \(TWO lines\)", T)
              is not None)
        check(g, "R24: and so are the two 'both' lines",
              re.search(r"'both' lines are\s+(\d+) bytes apart \(TWO lines\)", T)
              is not None)
        check(g, "R24: and 'mine' and 'both' do not share a line",
              "'mine' and 'both' are in different lines: yes" in T)
    check(g, "the artifact says the shape did NOT appear",
          "does NOT turn it back into the textbook picture" in FLAT)
    check(g, "and it says the extension CONFIRMS the smp explanation",
          "extension CONFIRMS the explanation" in FLAT)
    check(g, "and it names the store buffer as the mechanism, INFERRED",
          "store buffer DRAINING" in FLAT
          and "no count of coherence traffic" in FLAT.lower())
    check(g, "and the mechanism is marked INFERRED, not measured",
          "A duration BOUNDS a count" in FLAT
          and "MECHANISM: INFERRED" in FLAT)

    # ------------------------------------------------------------------
    # H. the string direction, as an ORDERING
    # ------------------------------------------------------------------
    g = "H direction"
    print("  --- group H: the direction flag, as a growing ratio")
    # The DF table's rows are "  16 |  23 |  184 |  8.00 | ...", and the
    # rule under the header is a row of dashes and pipes whose LAST cell is
    # "--------------" -- so it is excluded by requiring a DECIMAL in the
    # ratio column.  A separator is a row with no number in it, and saying
    # so in the pattern is clearer than a second regex.
    df = rows(T, r"^\s+(\d+)\s+\|\s+(\d+)\s+\|\s+(\d+)\s+\|\s+(\d+\.\d+)\s+\|",
              take=4)
    check(g, "four string sizes were run", len(df) == 4, "%d rows" % len(df))
    if len(df) == 4:
        sizes = [int(r[0]) for r in df]
        ratios = [float(r[3]) for r in df]
        check(g, "and the sizes ascend", sizes == sorted(sizes), str(sizes))
        check(g, "the DF=1 arm is slower than DF=0 at EVERY size",
              all(b > a for a, b in
                  [(int(r[1]), int(r[2])) for r in df]))
        check(g, "and the ratio GROWS with size, which is the shape",
              ratios == sorted(ratios), " ".join("%.2f" % x for x in ratios))
        check(g, "and the largest is more than twice the smallest",
              ratios[-1] > 2 * ratios[0],
              "%.2f -> %.2f" % (ratios[0], ratios[-1]))
    check(g, "and the two arms copied the same bytes, checked on every row",
          "printed nothing, which is the result" in FLAT)
    check(g, "the artifact prints the checksums agree rather than asserting it",
          "the checksums agree" in FLAT)
    check(g, "the history is stated as HISTORY and not as a measurement",
          "STATED AS HISTORY AND NOT AS A MEASUREMENT" in FLAT)
    check(g, "and the limits of the measurement are printed",
          "MINIMUM over" in FLAT and "WHY the down direction is slower" in FLAT)

    # ------------------------------------------------------------------
    # I. the maps: the round trip AND the second reader
    # ------------------------------------------------------------------
    g = "I maps"
    print("  --- group I: thirty encodings, round-tripped AND cross-checked")
    mp = table(T, "MAP")
    check(g, "thirty cases were encoded", len(mp) == 30, "%d rows" % len(mp))
    rt = [r for r in mp if r[2] == "roundtrip"]
    check(g, "and all thirty round-trip through the decoder", len(rt) == 30,
          "%d round-tripped" % len(rt))
    # the encodings, asserted to the byte: these are the SDM's own tables
    want_bytes = [
        ("addps xmm0,xmm1", "0f 58 c1"),
        ("addpd xmm0,xmm1", "66 0f 58 c1"),
        ("movaps xmm0,xmm1", "0f 28 c1"),
        ("movups xmm0,xmm1", "0f 10 c1"),
        ("movdqa xmm0,xmm1", "66 0f 6f c1"),
        ("movdqu xmm0,xmm1", "f3 0f 6f c1"),
        ("pxor xmm0,xmm1", "66 0f ef c1"),
        ("mulps xmm0,xmm1", "0f 59 c1"),
        ("addps xmm0,[rbx]", "0f 58 03"),
        ("vaddps xmm2,xmm1,xmm0", "c5 f0 58 d0"),
        ("vaddps ymm2,ymm1,ymm0", "c5 f4 58 d0"),
        ("vaddpd ymm2,ymm1,ymm0", "c5 f5 58 d0"),
        ("vmovaps ymm0,[rbx]", "c5 fc 28 03"),
        ("vmovups ymm0,[rbx]", "c5 fc 10 03"),
        ("vmovdqa ymm0,[rbx]", "c5 fd 6f 03"),
        ("vmovdqu ymm0,[rbx]", "c5 fe 6f 03"),
        ("vpxor ymm2,ymm1,ymm0", "c5 f5 ef d0"),
        ("vpaddd ymm2,ymm1,ymm0", "c5 f5 fe d0"),
        ("vpsubd ymm2,ymm1,ymm0", "c5 f5 fa d0"),
        ("vpcmpeqd ymm2,ymm1,ymm0", "c5 f5 76 d0"),
        ("vbroadcastss ymm0,[rbx]", "c4 e2 7d 18 03"),
        ("vbroadcastsd ymm0,[rbx]", "c4 e2 7d 19 03"),
        ("vpbroadcastd ymm0,[rbx]", "c4 e2 7d 58 03"),
        ("vfmadd231pd ymm0,ymm1,ymm2", "c4 e2 f5 b8 c2"),
        ("vfmadd132ps xmm0,xmm1,xmm2", "c4 e2 71 98 c2"),
        ("vaddps zmm0,zmm1,zmm2", "62 f1 74 48 58 c2"),
        ("vaddpd zmm0,zmm1,zmm2", "62 f1 f5 48 58 c2"),
        ("vaddps zmm0{k2},zmm1,zmm2", "62 f1 74 4a 58 c2"),
        ("vaddps zmm0,zmm1,zmm2{ru-sae}", "62 f1 74 58 58 c2"),
    ]
    for name, byt in want_bytes:
        row = [r for r in mp if r[0].strip() == name]
        check(g, "%-32s is %s" % (name, byt),
              bool(row) and row[0][1] == byt,
              row[0][1] if row else "no row")
    # THE SECOND READER, which is the whole point of the section
    dis = one(r"vecmaps_dis\.txt\s+(loaded|ABSENT)", T)
    check(g, "the objdump input is reported by name and by state",
          dis in ("loaded", "ABSENT"), "vecmaps_dis.txt = %s" % dis)
    if dis == "loaded":
        xr = [r for r in mp if r[3].strip() == "objdump agrees"]
        check(g, "and every one of the thirty cross-checked against it",
              len(xr) == 30, "%d agreed" % len(xr))
        bad = [r[0] for r in mp if r[3].strip() == "OBJDUMP DISAGREES"]
        check(g, "and none disagreed", not bad, ", ".join(bad) or "0 of 30")
        check(g, "and the artifact says the two numbers are not the same claim",
              "THREE NUMBERS ARE NOT THE SAME CLAIM" in FLAT)
        # R23.  The cross-check reported 28 disagreements out of 30 for a
        # whole run, and BELIEVED them, because the reader of the
        # disassembly was counting objdump's section header as row 0 and
        # so compared every row against its NEIGHBOUR.  These three checks
        # are the ones that would have caught it: the loader must say how
        # many lines it skipped, a failing cross-check must be LOUD, and
        # the retraction must be present.
        # The loader's own skip counts.  This is the check that would have
        # caught R23 at the moment it happened: a header count of ZERO
        # means the section header is being counted as an instruction
        # again, which is the bug, and it is the ONLY way to tell a
        # correct loader from a wrong one that happens to produce thirty
        # rows.  A harness that only checked the row count would pass the
        # broken loader, because both loaders read thirty lines.
        skip = re.search(r"loaded, (\d+) rows\s+\((\d+) header, (\d+) padding"
                         r" skipped\)", T)
        check(g, "R23: the loader REPORTS the header and padding it skipped",
              skip is not None,
              " ".join(skip.groups()) if skip else "not reported")
        check(g, "R23: and it skipped at least ONE header, which is the bug",
              skip is not None and int(skip.group(2)) >= 1
              and int(skip.group(3)) > 0,
              "%s header, %s padding"
              % (skip.group(2), skip.group(3)) if skip else "?")
        check(g, "R23: and the padding it skipped is at least 9x the rows",
              skip is not None
              and int(skip.group(3)) >= 9 * int(skip.group(1)),
              "%s padding for %s rows"
              % (skip.group(3), skip.group(1)) if skip else "?")
        check(g, "R23: a zero header count is treated as a FAILURE, not a pass",
              "the loader counted it as row 0" in FLAT
              and "compared against its NEIGHBOUR's text" in FLAT
              and "of the DISASSEMBLY was off by one row" in FLAT)
        check(g, "R23: an all-disagree cross-check is called SUSPICIOUS too",
              "as SUSPICIOUS as one that agrees with" in FLAT)
        check(g, "R23: the retraction is printed in full",
              "The objdump cross-check agreed with the encoder on" in FLAT
              and "28 of 30 rows" in FLAT
              and "the encoder was broken" in FLAT.lower())
        check(g, "R23: and it says the two failure modes look different",
              "all-disagree and all-agree" in FLAT
              and "equally wrong" in FLAT)
    else:
        check(g, "and the artifact says the section runs either way",
              "cross-check NOT RUN" in T
              and "runs the 30" in FLAT.replace("  ", " ")
              or "does not" in FLAT)
    check(g, "the artifact says a round trip is a TAUTOLOGY",
          "A round trip is a" in FLAT and "tautology" in FLAT)
    check(g, "and that this file certified a broken encoder",
          "round-tripped 28 of 28 and was WRONG" in FLAT)
    # NOTE: these needles are written against FLAT, which has already had
    # every run of spaces collapsed.  A needle carrying the artifact's
    # column alignment can therefore never match, and did not; the fix is
    # to write the words and not the padding, which is what flat() is for.
    check(g, "and the eleven EVEX bits are printed",
          all(w in FLAT for w in ["R~ X~ B~ 16 more vector registers",
                                  "R~' a FOURTH bit", "MANDATORY 1",
                                  "V~' a fifth bit",
                                  "a2 a1 a0 WHICH OF EIGHT MASK"]))
    check(g, "and the mask register is explained as an OPERAND of the add",
          "an OPERAND of the arithmetic rather than an input" in FLAT)
    check(g, "and the tail-is-gone claim is credited to the simd course",
          "the SIMD course measured that" in FLAT
          and "remainder at 1.02x" in FLAT)
    check(g, "and what is QUOTED against what is MEASURED is itemised",
          "QUOTED that a ZMM is 512 bits" in FLAT
          and "MEASURED the five CPUID bits are zero" in FLAT
          and "NOT MEASURED that any of it is FASTER" in FLAT)

    # ------------------------------------------------------------------
    # J. the retractions, asserted as TEXT
    # ------------------------------------------------------------------
    g = "J retractions"
    print("  --- group J: the retractions, asserted as TEXT so they cannot be dropped")
    present = re.findall(r"^\s+(R\d+)\.", T, re.M)
    for r in ["R%d." % i for i in range(1, 25)]:
        check(g, "retraction %s is printed by the artifact" % r,
              re.search(r"^\s+%s" % re.escape(r), T, re.M) is not None)
    check(g, "and all twenty-four are present", len(set(present)) == 24,
          "%d distinct" % len(set(present)))
    check(g, "R1 is the direction flag bit, and the replacement is bit 10",
          "The direction flag is EFLAGS bit 21" in FLAT and "Bit 10 is DF" in FLAT)
    check(g, "R2 is the INC claim, and the real reason for the encoding",
          "INC and DEC are NOT atomic even with the LOCK prefix" in FLAT
          and "does not disturb the CARRY flag" in FLAT)
    check(g, "R3 is the counter instrument, and the involution is named",
          "A lost-update count is a test for atomicity" in FLAT
          and "NOT and NEG are involutions" in FLAT)
    check(g, "R4 is the value-preserving claim, and the instrument is named",
          "An operation that did not change the value cannot have" in FLAT
          and "THE PAIRED COUNTER" in FLAT)
    check(g, "R5 credits the assembly course rather than re-measuring it",
          "The three-operand VEX form removed an instruction" in FLAT
          and "The assembly\n        course measured it at 1.00x" in FLAT
          or "The assembly course measured it at 1.00x" in FLAT)
    check(g, "R6 is the transition penalty, and it says NOT OBSERVABLE",
          "The AVX-SSE transition penalty is what vzeroupper" in FLAT
          and "NOT\n          OBSERVABLE HERE" in FLAT
          or "NOT OBSERVABLE HERE" in FLAT)
    check(g, "R7 is the intrinsics-compiled-to-VEX experiment",
          "gcc compiled them to VEX" in FLAT or "compiled to VEX" in FLAT)
    check(g, "R8 is the static array, and the fix is mmap",
          "A static array is a safe place to probe a load" in FLAT
          and "The buffer is mmap'd now" in FLAT)
    check(g, "R9 is the round trip, and the second reader is named",
          "A round trip proves the encoder is right" in FLAT
          and "a second reader that" in FLAT.lower())
    check(g, "R10 is the operand map, and how it was established",
          "ModRM.r/m is the" in FLAT
          and "assembling three DISTINCT registers" in FLAT)
    check(g, "R11 is the probe that returned without running",
          "A probe that returns must have run" in FLAT
          and "the harness asserts the mnemonics" in FLAT)
    check(g, "R12 is the two-asm-block YMM probe",
          "Filling a YMM register, running one instruction and" in FLAT
          and "ONE asm block" in FLAT)
    check(g, "R13 is the negative claim that SURVIVED, and says so",
          "NOT RETRACTED" in T and "the copy is free" in FLAT)
    check(g, "R14 is the finding that replaced one",
          "A not-equal, not-0xFFFFFFFF" in FLAT
          and "toggles a bit and can" in FLAT)
    check(g, "R15 is the VEX alignment claim, and the SDM is quoted",
          "THE VEX PREFIX WAS WRONG" in FLAT
          and "16-byte (128-bit version)" in FLAT)
    check(g, "R16 is the duplicate test, and all four versions are named",
          "A duplicate-old-value test can decide whether a" in FLAT
          and "PER-THREAD hash set" in FLAT
          and "counted CLOBBERS" in FLAT)
    check(g, "R17 is the CMPXCHG accumulator pair, and it is I/O not input",
          "A CMPXCHG loop's accumulator pair is an input" in FLAT
          and "INPUT *AND AN OUTPUT*" in FLAT)
    check(g, "R18 is the three exact totals",
          "An arm is atomic when the total is exactly 2N" in FLAT
          and "2^32 - 2N" in FLAT and "TOGGLES a bit ends at 0" in FLAT)
    check(g, "R19 is the perfect table, and says what produced it",
          "A table with twenty perfect rows is evidence" in FLAT
          and "measured nothing reports no losses" in FLAT)
    check(g, "R20 is the idempotent bit-test group",
          "BTS and BTR are atomic when the final word is 1 and 0" in FLAT
          and "both are IDEMPOTENT" in FLAT)
    check(g, "R21 is the vectorised checksum",
          "safe to let the" in FLAT and "clean SIGSEGV" in FLAT)
    check(g, "R22 is the fence bit count, and the collision is named",
          "MFENCE and SFENCE differ in a single bit position" in FLAT
          and "TWO bit positions and not one" in FLAT)
    check(g, "R23 is the cross-check that was believed, and says so",
          "RETRACTED, and this is the worst of" in FLAT
          and "it was BELIEVED" in FLAT)
    check(g, "R24 is the ping-pong arm that never used its thread id",
          "took a THREAD ID and never used it" in FLAT
          and "were the SAME two words" in FLAT)
    check(g, "R24 says it took THREE attempts, and says what each was",
          "took THREE attempts to fix" in FLAT
          and "aligns the ARRAY and not each ELEMENT" in FLAT
          and "The fix is a STRIDE" in FLAT)
    check(g, "R24 names the tell: a floor that came out ABOVE the thing",
          "came out ABOVE the ping-pong in every" in FLAT
          and "impossible for a floor" in FLAT)
    check(g, "R24 says the artifact PRINTED the ratio instead of objecting",
          "PRINTED THE RATIO instead of" in FLAT
          and "a contradiction of its own vocabulary" in FLAT)
    check(g, "R24 states the lesson about names not being evidence",
          "a name is not evidence" in FLAT)
    check(g, "and the artifact counts them and classifies them",
          "Twenty-four of them" in FLAT
          and "about what an INSTRUMENT is" in FLAT
          and "R23 and R24" in FLAT)

    # ------------------------------------------------------------------
    # K. the limits, and the verdict
    # ------------------------------------------------------------------
    g = "K limits"
    print("  --- group K: the limits block, and the verdict")
    check(g, "the limits block is printed, not footnoted",
          "LIMITS -- what this artifact cannot tell you" in T
          or "7B. THE LIMITS." in T)
    for lim in ["NO EVENT COUNTER OF ANY KIND",
                "NO AVX-512",
                "ONLY ONE MISALIGNMENT WAS MEASURED",
                "WHETHER ANY LOCKED INSTRUCTION ASSERTED LOCK# ON THE BUS",
                "THE COST OF A LOCKED INSTRUCTION",
                "THE STORE-BUFFER DEPTH",
                "WHY THE DOWNWARD STRING DIRECTION IS SLOWER",
                "A SECOND RUN'S RATIOS",
                "AArch64, RISC-V"]:
        check(g, "limit present: %s" % lim[:44], lim in FLAT)
    check(g, "and the two absences are declared to be DIFFERENT KINDS",
          "Five of the eight CPUID bits" in FLAT
          or "CPUID.7.0:EBX F, DQ, CD, BW and VL are five" in FLAT
          or "are five\n  zeros" in FLAT)
    check(g, "the verdict says what the artifact CAN support",
          "7C. WHAT THIS ARTIFACT CAN SUPPORT" in T)
    check(g, "and what it cannot",
          "7D. WHAT IT CANNOT SUPPORT" in T)
    check(g, "and it says a decoder is not a benchmark",
          "A\n           decoder that works on bytes is a decoder; it is not a\n"
          "           benchmark" in FLAT
          or "decoder that works on bytes is a decoder" in FLAT)
    ck = one(r"checksums folded in: 0x([0-9a-f]+)", T)
    check(g, "a running checksum is printed, so a silent no-op cannot pass",
          ck is not None, "0x%s" % ck if ck else "?")
    rowsm = one(r"rows measured: (\d+)", T)
    check(g, "and a row count", rowsm is not None and int(rowsm) >= 60,
          "%s rows" % rowsm)

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
