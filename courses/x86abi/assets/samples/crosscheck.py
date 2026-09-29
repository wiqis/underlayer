#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The x86-64 ABI".

It reads the OUTPUT of abidump and checks nine groups of claims.  It does not
re-measure anything, and it asserts almost no numbers.

Why so little is asserted numerically, in this file's own words: abidump
section 1 measures the spread of its own estimator and prints it BEFORE any
claim, and the machine is a virtualised guest with twelve logical CPUs and
other work on it.  A tolerance that large can verify a SHAPE and cannot
verify a VALUE.  Worse, a check whose threshold is a bare number is a check
that fails on a busier machine and teaches its reader to ignore it -- which is
how the harnesses of the four preceding courses broke.  So:

  * STRUCTURAL claims are asserted EXACTLY, because they are exact: the
    register-name bit patterns, the register NUMBERS, the argument order, the
    alignment constant, the red-zone size 128, the save-area size 176, the
    CFI opcode numbers, the ORDER of the audit table, the census as a
    partition, and the presence of all eight retractions;
  * the ONE duration-shaped claim in the file (the noise floor) is asserted
    as an ORDERING and a RATIO, never as a value;
  * everything else in this file is a fault, a bit pattern or a string, and
    those do not move between runs.

The harness exists to catch a future edit that quietly changes a claim.  In
particular it asserts the presence of all eight retractions, and it asserts
THE AUDIT rather than a remembered number: every caller, at every one of the
four optimisation levels, must be reported as matching the specification.

Usage:  python3 crosscheck.py [path/to/abidump.out]
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
    before abidump is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them."""
    return os.path.join(HERE, "abidump.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


def two(pat, text, flags=0):
    """Both capture groups of a pattern, or None."""
    m = re.search(pat, text, flags)
    return m.groups() if m else None


def rows(text, pat):
    """Every line of a table that matches `pat` IN ORDER, as a token list.

    The order matters: a table whose rows were reordered is a different table,
    and a check that only looked at the contents would not notice.  The
    WHOLE line is returned as tokens rather than one capture group, because
    the first version of this helper returned group(1) -- the row key -- and
    the caller then asked for fields 1, 2 and 3 of a one-element list.  That
    is the seventh time in this collection that a helper written for one shape
    has been used on another, and the fix is always the same: return the
    shape the caller wants and let the caller index it."""
    out = []
    for ln in text.splitlines():
        if re.match(pat, ln):
            out.append(ln.split())
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    T = load(path)
    # Every substring assertion runs against a WHITESPACE-NORMALISED copy.
    # The artifact wraps its prose at about 78 columns, so a phrase written
    # across a line break is a phrase the artifact HAS and the harness cannot
    # see -- which is how four checks in the previous course's harness failed
    # about text that was demonstrably present.  Numeric parses still use the
    # original, because collapsing spaces there would join adjacent columns.
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
    check(g, "and the ABSENCE of a PMU is proved, not assumed",
          "RDPMC in a forked child" in T and "KILLED by a signal" in T)
    check(g, "the consequence is stated: durations are not counts",
          "bounds a count without measuring it" in FLAT)
    check(g, "every input is declared OPTIONAL rather than assumed present",
          "and each of the four is OPTIONAL" in FLAT)
    dis = one(r"abi_dis\.txt\s+(\w+)", T)
    cfi = one(r"abi_cfi\.txt\s+(\w+)", T)
    check(g, "the disassembly input is reported by name and by state",
          dis in ("loaded", "ABSENT"), "abi_dis.txt = %s" % dis)
    check(g, "the unwind input is reported by name and by state",
          cfi in ("loaded", "ABSENT"), "abi_cfi.txt = %s" % cfi)

    # ------------------------------------------------------------------
    # B. the specification, printed as the oracle
    # ------------------------------------------------------------------
    g = "B spec"
    print("  --- group B: the specification, which is the ORACLE and not a measurement")
    spec = re.search(r"1B\. THE SPECIFICATION(.*?)\n2\.  THE AUDIT", T, re.S)
    S = spec.group(1) if spec else ""
    # The table is column-aligned with runs of spaces, so every check against
    # it runs on a whitespace-collapsed copy.  A check that has to know how
    # many spaces the author typed is a check about the typesetting.
    SF = re.sub(r"[ \t]+", " ", S)
    check(g, "the oracle table is present", bool(S))
    if S:
        check(g, "the six integer argument registers, in order",
              "integer argument registers rdi rsi rdx rcx r8 r9" in SF is not None)
        check(g, "their REGISTER NUMBERS, which is the part nobody memorises",
              "their register numbers 7 6 2 1 8 9" in SF is not None,
              "7 6 2 1 8 9")
        check(g, "the stack alignment constant is 16",
              "the stack alignment constant 16 bytes" in SF)
        check(g, "the red zone is 128 bytes and is for LEAF functions only",
              "the red zone 128 bytes below %rsp, LEAF functions" in SF)
        check(g, "the varargs save area is 176 = 48 + 128",
              "the varargs save area 176 bytes = 48 integer + 128 SSE" in SF)
        check(g, "the initial gp_offset is 8 and fp_offset is 48",
              "the initial gp_offset 8" in SF and "the initial fp_offset 48" in SF)
        check(g, "the callee-saved and caller-saved sets are BOTH printed",
              "callee-saved GPRs rbx rbp r12 r13 r14 r15" in SF and
              "caller-saved GPRs rax rcx rdx rsi rdi r8 r9 r10 r11" in SF)
        check(g, "the two register sequences are declared INDEPENDENT",
              "INDEPENDENT" in SF)
        check(g, "and it is said that the oracle is not a measurement",
              "NOT MEASURED" in spec.group(0) if spec else False)

    # ------------------------------------------------------------------
    # C. the audit: the compiler against the specification
    # ------------------------------------------------------------------
    g = "C audit"
    print("  --- group C: the audit, which is the course's distinctive idea")
    aud = rows(T, r"^  (-O[012s])\s+(\d+)\s+(\d+)\s+(\d+)$")
    check(g, "all four optimisation levels reported", len(aud) == 4,
          "%d rows" % len(aud))
    if len(aud) == 4:
        check(g, "and they are in the manifest's order, -O0 -O1 -O2 -Os",
              [r[0] for r in aud] == ["-O0", "-O1", "-O2", "-Os"],
              " ".join(r[0] for r in aud))
        nums = [(int(r[1]), int(r[2]), int(r[3])) for r in aud]
        check(g, "every level audited the SAME number of callers",
              len(set(n[0] for n in nums)) == 1, "%d callers" % nums[0][0])
        check(g, "and match + differ is a PARTITION of the callers at every level",
              all(n[1] + n[2] == n[0] for n in nums),
              "; ".join("%d+%d=%d" % n for n in nums))
        check(g, "and NO caller differs from the specification at any level",
              all(n[2] == 0 for n in nums),
              "%d differ in total" % sum(n[2] for n in nums))
    check(g, "the mapping recovered is which SOURCE went into which REGISTER",
          "which SOURCE went into which REGISTER, by name" in FLAT)
    check(g, "the fourth integer argument is named as %rcx, in the artifact's prose",
          "v14=rcx" in FLAT)
    check(g, "and the 7th argument is on the stack at +0x10 from the entry rsp",
          "stack=0x10" in T or "at [rsp+0x10]" in FLAT)
    check(g, "the two register sequences are shown INDEPENDENT by measurement",
          re.search(r"^\s*mx\s+rsi rdx rcx rdi xmm0 xmm1 xmm2 xmm3", T, re.M) is not None,
          "mx: rsi rdx rcx rdi xmm0 xmm1 xmm2 xmm3")
    check(g, "a six-integer-argument callee reads all six, in order",
          re.search(r"CALLEE \| O2 \| f6 \| rdi rsi rdx rcx r8 r9", T) is not None)
    check(g, "and a four-double callee reads xmm0 through xmm3, in order",
          re.search(r"CALLEE \| O2 \| mx \| rsi rdx rcx rdi xmm0 xmm1 xmm2 xmm3", T)
          is not None)

    # ------------------------------------------------------------------
    # D. the return address, and the one instruction that takes a register
    # ------------------------------------------------------------------
    g = "D retaddr"
    print("  --- group D: where the return address is, and the %rcx claim")
    conf = one(r"kept %rsp 16-byte aligned\s+(\d+)", T)
    viol = one(r"with the `subq \$8,%rsp` deleted\s+(\d+)", T)
    check(g, "a conforming call leaves %rsp at 8 (mod 16) at the callee's entry",
          conf == "8", "got %s" % conf)
    check(g, "and a non-conforming one leaves it at 0", viol == "0", "got %s" % viol)
    stack = one(r"%rsp at that point\s+0x([0-9a-f]+)", T)
    text_addr = one(r"0\(%rsp\) at that point\s+0x([0-9a-f]+)", T)
    check(g, "the word at 0(%rsp) was read and it is NOT zero",
          text_addr is not None and int(text_addr, 16) != 0)
    check(g, "and %rsp itself was read in the SAME call, which is the only way",
          stack is not None and "BOTH READINGS COME FROM ONE CALL" in FLAT)
    check(g, "the conclusion drawn is that `call` PUSHES the return address",
          "THE RETURN ADDRESS IS ON THE STACK" in T and
          "`call` PUSHES it and `ret`" in FLAT)
    rcx = one(r"%rcx AFTER\s+the syscall.*?= 0x([0-9a-f]+)", T)
    nxt = one(r"the instruction right after it.*?= 0x([0-9a-f]+)", T)
    check(g, "after a bare `syscall`, %rcx holds the return RIP, bit for bit",
          rcx is not None and nxt is not None and rcx == nxt,
          "%s == %s" % (rcx, nxt))
    check(g, "and the artifact says so as an equality, not as a resemblance",
          "%rcx == the address of the NEXT INSTRUCTION ?   YES" in T)
    r11 = one(r"%r11 after it, the RFLAGS `syscall` saved = (0x[0-9a-f]+)", T)
    check(g, "%r11 holds the saved RFLAGS, and bit 1 is set as the ISA requires",
          r11 is not None and (int(r11, 16) & 2) == 2, "0x%s" % r11)
    check(g, "and %r10 came back untouched, which is the whole of the reason",
          "0xfeedfacecafebeef  survived ? YES" in T)
    check(g, "the %rax result was checked against libc's getpid, not assumed",
          re.search(r"%rax after the bare `syscall`\s+=\s+(-?\d+)\s+match \? YES", T)
          is not None)
    check(g, "and the section states the LIMIT: it measures the instruction",
          "this measures the INSTRUCTION" in FLAT and
          "cannot observe a decision" in FLAT)

    # ------------------------------------------------------------------
    # E. alignment, the red zone, and their faults
    # ------------------------------------------------------------------
    g = "E frames"
    print("  --- group E: the alignment fault, the tail call, and the red zone")
    tail_plain = one(r"a TAIL `jmp`, no adjustment at all\s+(\d+)", T)
    tail_adj = one(r"a tail `jmp` after `subq \$8,%rsp`\s+(\d+)", T)
    check(g, "a plain tail `jmp` needs NO adjustment, and the measurement is 8",
          tail_plain == "8", "got %s" % tail_plain)
    check(g, "a tail `jmp` after the adjustment sees 0, i.e. the OPPOSITE rule",
          tail_adj == "0", "got %s" % tail_adj)
    check(g, "and leaving that adjustment in place KILLS the process",
          "kills the process: KILLED by a signal" in FLAT)
    check(g, "the artifact says the rule is TWO rules and not one",
          "THE RULE IS TWO RULES AND NOT ONE" in T)
    check(g, "movaps through a conforming call RETURNED",
          re.search(r"movaps 16-byte store, CONFORMING call\s+-> returned", T) is not None)
    check(g, "movaps through a violating call was KILLED by SIGSEGV",
          re.search(r"movaps 16-byte store, VIOLATING call\s+-> KILLED by a signal", T)
          is not None and "signal 11" in T)
    check(g, "and movups through the SAME violating call survived",
          re.search(r"movups 16-byte store, VIOLATING call\s+-> returned", T) is not None)
    check(g, "both surviving arms read the SAME value back, so the work happened",
          T.count("0x3ff8000000000000") >= 2,
          "%d occurrences" % T.count("0x3ff8000000000000"))
    check(g, "the artifact says this is a FAULT and not a timing",
          "THIS IS NOT A TIMING" in T)
    check(g, "and it says WHY the psABI says 16 and not 8 is not measurable here",
          "WHY THE psABI SAYS 16 AND NOT 8" in FLAT)
    leaf = re.search(r"leaf, no call, 2 slots written\s+every slot intact: (\S+)", T)
    callz = re.search(r"the same leaf, plus ONE `call`\s+every slot intact: (\S+)", T)
    frame = re.search(r"plus a FRAMED callee\s+every slot intact: (\S+)", T)
    check(g, "a leaf that uses the red zone and calls nothing KEEPS it",
          leaf is not None and leaf.group(1) == "YES", leaf and leaf.group(1))
    check(g, "the same leaf plus ONE `call` LOSES it",
          callz is not None and callz.group(1) == "NO", callz and callz.group(1))
    check(g, "and a framed callee loses all four slots",
          frame is not None and frame.group(1) == "NO", frame and frame.group(1))
    check(g, "the clobbering word was READ, and it is a TEXT address",
          re.search(r"the callee's 0\(%rsp\)\s+= 0x[0-9a-f]+", T) is not None and
          "a TEXT address" in T)
    check(g, "and the conclusion is stated as the return-address slot",
          "RETURN-ADDRESS SLOT, AND `call` WRITES THEM" in FLAT)
    check(g, "the psABI's own reason for the red zone is declared UNMEASURABLE",
          "WHETHER A SIGNAL RESPECTOR RESPECTS THE RED ZONE RESERVATION" in FLAT)

    # ------------------------------------------------------------------
    # F. callee-saved, by experiment
    # ------------------------------------------------------------------
    g = "F saved"
    print("  --- group F: callee-saved and caller-saved, established by experiment")
    a1 = re.search(r"the caller's %r12 after the call = 0x([0-9a-f]+)\s+(\S+)", T)
    check(g, "a callee that tramples r12 CLOBBERS the caller's r12",
          a1 is not None and a1.group(2) == "CLOBBERED",
          "0x%s %s" % (a1.group(1), a1.group(2)) if a1 else "?")
    a2 = re.search(r"after the call %r12 = 0x([0-9a-f]+)\s+(\S+)", T)
    check(g, "and the SAME register SURVIVES a conforming callee",
          a2 is not None and a2.group(2) == "SURVIVED",
          "0x%s %s" % (a2.group(1), a2.group(2)) if a2 else "?")
    check(g, "and the two values are DIFFERENT, so the arms are not the same arm",
          a1 and a2 and a1.group(1) != a2.group(1))
    a3 = two(r"0x100 \+ 0x9999999999999999 = 0x([0-9a-f]+)\s+(\S+)", T)
    check(g, "a conforming callee that USES %rbx gets push/mov/add/pop right",
          a3 is not None and a3[0] == "9999999999999a99" and a3[1] == "EXACT",
          "0x%s %s" % a3 if a3 else "? ?")
    a4 = two(r"the same for %r12\s+= 0x([0-9a-f]+)\s+(\S+)", T)
    check(g, "and the same for %r12", a4 is not None and a4[1] == "EXACT",
          "0x%s %s" % a4 if a4 else "? ?")
    check(g, "the DIRECTION FLAG is 0 inside a conforming callee",
          re.search(r"inside a conforming callee\s+0x([0-9a-f]+), and bit 10 \(DF\) = 0",
                    T) is not None)
    check(g, "and is 1 after a non-conforming one",
          re.search(r"by a NON-conforming callee\s+0x([0-9a-f]+), and bit 10 \(DF\) = 1",
                    T) is not None)
    check(g, "a callee that clobbers %rbp kills the caller with SIGBUS",
          re.search(r"clobbered %rbp\s+-> KILLED by a signal 7", T) is not None)
    check(g, "and a conforming callee does not",
          re.search(r"a conforming callee\s+-> returned normally", T) is not None)
    m0 = two(r"MXCSR before the call\s+0x([0-9a-f]+)\s+rounding control (\d+)", T)
    m1 = two(r"MXCSR after\s+the call\s+0x([0-9a-f]+)\s+rounding control (\d+)", T)
    check(g, "MXCSR's rounding control CHANGED across a call, i.e. caller-saved",
          m0 is not None and m1 is not None and m0[1] != m1[1],
          "RC %s -> %s" % (m0[1] if m0 else "?", m1[1] if m1 else "?"))
    c0 = two(r"x87 control word before 0x([0-9a-f]+)\s+PC (\d+), RC (\d+)", T)
    c1 = two(r"x87 control word after\s+0x([0-9a-f]+)\s+PC (\d+), RC (\d+)", T)
    check(g, "and the x87 PRECISION control changed too, so the two disagree",
          c0 is not None and c1 is not None and c0[1] != c1[1],
          "PC %s -> %s" % (c0[1] if c0 else "?", c1[1] if c1 else "?"))
    check(g, "and the CALLER can restore MXCSR, which is the whole obligation",
          re.search(r"MXCSR after the CALLER restored it\s+0x[0-9a-f]+", T) is not None)
    check(g, "the section says the DIRECTION IS REVERSED and that it is measured",
          "WHERE THE DIRECTION IS REVERSED, AND IT IS MEASURED" in T)

    # ------------------------------------------------------------------
    # G. varargs: the one place the ABI describes itself
    # ------------------------------------------------------------------
    g = "G varargs"
    print("  --- group G: the varargs save area and the %al lie")
    check(g, "the save area size 176 = 48 + 128 is stated in the section",
          "176-byte block of stack" in FLAT)
    arms = re.findall(r"al=(\d)\s+a=0x([0-9a-f]+) \(([\d.]+)\)\s+b=0x([0-9a-f]+)", T)
    check(g, "all four arms reported, with %al 2 2 0 1 IN THAT ORDER",
          [a[0] for a in arms] == ["2", "2", "0", "1"],
          " ".join(a[0] for a in arms))
    if len(arms) == 4:
        check(g, "the two honest arms returned exactly what was passed",
              arms[0][1] == "3ff8000000000000" and arms[0][3] == "4004000000000000" and
              arms[1][1] == "4059500000000000" and arms[1][3] == "4069500000000000")
        check(g, "THE RESULT: the lying arm returned the PREVIOUS call's first value",
              arms[2][1] == arms[1][1] and arms[2][1] != arms[3][1],
              "al=0 gave 0x%s and al=1 gave 0x%s" % (arms[2][1], arms[3][1]))
        check(g, "and it is a value the caller in that arm did NOT pass",
              float(arms[2][2]) == 101.25 and float(arms[3][2]) == 3.5,
              "al=0 -> %s, al=1 -> %s" % (arms[2][2], arms[3][2]))
        check(g, "and the SECOND slot is not anybody's number either",
              arms[2][3] != arms[1][3] and arms[2][3] != arms[3][3],
              "0x%s" % arms[2][3])
        check(g, "which is the shape: al=0 loses, al>=1 recovers, on THIS compiler",
              arms[3][1] == "400c000000000000" and arms[3][3] == "4012000000000000")
    check(g, "the same failure is reproduced through glibc's printf",
          re.search(r"glibc printf, al=0: 101\.250000 0\.000000", T) is not None)
    check(g, "and the honest printf arms are right, as a control",
          re.search(r"glibc printf, al=2: 101\.250000 202\.500000", T) is not None)
    check(g, "the artifact says %al is TESTED for zero, which is not the spec",
          "gcc TESTS it for zero and spills all EIGHT" in FLAT)
    check(g, "and that a self-describing convention is still a convention",
          "nothing checks it" in FLAT)

    # ------------------------------------------------------------------
    # H. unwinding, and the audit of a real library
    # ------------------------------------------------------------------
    g = "H unwind"
    print("  --- group H: the second description of the frame, and the linter")
    fde_with = one(r"^  FDE \| with \| (\d+)", T, re.M)
    fde_without = one(r"^  FDE \| without \| (\d+)", T, re.M)
    check(g, "gcc emits FDEs by default and none with -fno-asynchronous-unwind-tables",
          fde_with is not None and fde_without is not None and
          int(fde_with) > 0 and int(fde_without) == 0,
          "%s with, %s without" % (fde_with, fde_without))
    dco = one(r"^  DIRECTIVE \| cfi_def_cfa_offset \| (\d+)", T, re.M)
    check(g, "and the .cfi_def_cfa_offset directives were counted",
          dco is not None and int(dco) > 0, "%s" % dco)
    fr_yes = one(r"unwind tables present:\s+FRAMES (-?\d+)", T)
    fr_no = one(r"unwind tables REMOVED:\s+FRAMES (-?\d+)", T)
    check(g, "a real unwinder sees more than one frame WITH the tables",
          fr_yes is not None and int(fr_yes) > 1, "FRAMES %s" % fr_yes)
    check(g, "and no number in that pair is the -1 that means NOT MEASURED",
          fr_yes != "-1" and fr_no != "-1")
    check(g, "and exactly ONE without them, which is the whole of the result",
          fr_no == "1", "FRAMES %s" % fr_no)
    check(g, "the instrument is named as a real unwinder, not a simulation",
          "backtrace() from glibc's" in FLAT and "execinfo" in FLAT)
    check(g, "and the artifact says the frame is not unwound AT ALL rather than wrong",
          "not unwound AT ALL" in FLAT)

    # The cost of a frame description, in bytes.  The first draft of the
    # course asserted "about ELEVEN bytes without a frame pointer and about
    # FORTY with one".  The first half was measured; the second half was an
    # estimate, and the estimate is retracted here with the real number
    # beside it.  These checks exist so that a future reader who is tempted
    # to write the estimate again sees it already written down and refuted.
    eh_def = one(r"^  EHSIZE \| with \| (\d+)", T, re.M)
    eh_omit = one(r"^  EHSIZE \| fp_omitted \| (\d+)", T, re.M)
    eh_kept = one(r"^  EHSIZE \| fp_kept \| (\d+)", T, re.M)
    check(g, "the .eh_frame size was measured in all three builds",
          None not in (eh_def, eh_omit, eh_kept),
          "default %s, -fomit %s, -fno-omit %s" % (eh_def, eh_omit, eh_kept))
    check(g, "the default and -fomit-frame-pointer are BYTE-IDENTICAL",
          eh_def is not None and eh_omit is not None and int(eh_def) == int(eh_omit),
          "%s == %s" % (eh_def, eh_omit))
    check(g, "and -fno-omit-frame-pointer is LARGER, as it has to be",
          eh_def is not None and eh_kept is not None and int(eh_kept) > int(eh_def),
          "%s > %s" % (eh_kept, eh_def))
    per_kept = (float(eh_kept) / float(fde_with)) if (eh_kept and fde_with) else 0.0
    check(g, "and the retracted FORTY-bytes estimate is refuted, not restated",
          "FORTY when" in FLAT and "RETRACTED" in FLAT and per_kept < 20.0,
          "%.1f bytes per FDE, so the estimate was high by about %.1fx"
          % (per_kept, 40.0 / per_kept) if per_kept else "?")
    check(g, "and the artifact says the estimate was made before anything was compiled",
          "before anything had been\n    compiled" in T or
          "before anything had been compiled" in FLAT)

    g = "H2 linter"
    lib = one(r"^  FUNCTIONS \| (\d+)", T, re.M)
    check(g, "the real library was audited and the function count is reported",
          lib is not None and int(lib) > 1000, "%s functions" % lib)
    cens = re.findall(r"^  CENSUS \| (r(?:bx|bp|1[2-5])) \| (\d+) \| (\d+)", T, re.M)
    check(g, "all six callee-saved registers have a census, in order",
          [c[0] for c in cens] == ["rbx", "rbp", "r12", "r13", "r14", "r15"],
          " ".join(c[0] for c in cens))
    check(g, "and every census is NON-ZERO, which is what makes a zero meaningful",
          cens and all(int(c[1]) > 0 for c in cens),
          "min %d uses" % min(int(c[1]) for c in cens) if cens else "?")
    check(g, "and saved <= used for every register, i.e. the count is sane",
          cens and all(int(c[2]) <= int(c[1]) for c in cens))
    flags = two(r"^  CLOBBERFLAGS \| (\d+) \| (\d+) functions", T, re.M)
    check(g, "the flags are reported with both a count and a function count",
          flags is not None and int(flags[1]) > 0,
          "%s flags in %s functions" % flags if flags else "?")
    ctx = two(r"^  CLAPPERCONTEXT \| (\d+) \| (\d+)", T, re.M)
    check(g, "and the flags are SPLIT into the context-restoring kind and the rest",
          ctx is not None, "%s context, %s other" % ctx if ctx else "?")
    check(g, "and the two exemptions are named, because they are the honest limit",
          "install a previously saved register context" in FLAT and
          "legal only if the compiler knows no caller had a live value" in FLAT)
    # The two exemptions are counted independently, so "the rest" is only
    # well defined if the OVERLAP is reported.  A function can be both a
    # leaf and a context restorer -- setjmp is both -- and a page that
    # subtracts one count from the other without knowing the overlap is
    # doing arithmetic that happens to work.
    both = two(r"^  CLAPPERBOTH \| (\d+) \| (\d+) unclassified", T, re.M)
    check(g, "the OVERLAP of the two exemptions is reported, not assumed away",
          both is not None, "%s flagged as both, %s unclassified" % (both[0], both[1])
          if both else "no CLAPPERBOTH row")
    if both:
        check(g, "and the reported remainder is the flags minus BOTH exemptions, plus the overlap",
              int(both[1]) == int(flags[0]) - 26 - int(ctx[0]) + int(both[0]),
              "%d = %d - 26 - %d + %d" % (int(both[1]), int(flags[0]),
                                          int(ctx[0]), int(both[0])))
        check(g, "and the artifact says the two exemptions are counted independently",
              "is not flags - leaves - context" in FLAT)
    ctl = [x.strip() for x in re.findall(r"^    FLAGGED  (\S+)", T, re.M)]
    check(g, "THE POSITIVE CONTROL flagged exactly the three intended functions",
          sorted(ctl) == ["ct_clobber_r12", "ct_clobber_r13", "ct_clobber_rbx"],
          " ".join(ctl))
    check(g, "and the two CONFORMING control functions are NOT in that list",
          "ct_ok_leaf" not in ctl and "ct_ok_leaf4" not in ctl)
    check(g, "and the one intended alignment violation was found too",
          re.search(r"^    ALIGNCALLS \| 5 \| 1", T, re.M) is not None)

    # ------------------------------------------------------------------
    # I. the retractions
    # ------------------------------------------------------------------
    g = "I retractions"
    print("  --- group I: the retractions, asserted as TEXT so they cannot be dropped")
    for r in ["R1.", "R2.", "R3.", "R4.", "R5.", "R6.", "R7.", "R8.", "R9.", "R10."]:
        check(g, "retraction %s is printed by the artifact" % r, ("   " + r) in T)
    check(g, "R1 is the correction of the fourth-argument claim, and it is the",
          "RETRACTED, and" in T and "the sentence is" in FLAT)
    check(g, "  correction of THIS COURSE's own draft rather than of a rival's",
          "this course's own first draft" in FLAT)
    check(g, "R4 retracts the single alignment rule in favour of two",
          "TWO RULES AND NOT ONE" in T and "want OPPOSITE adjustments" in FLAT)
    check(g, "R6 retracts the glibc alignment claim and blames the CHECKER",
          "a fact about the CHECKER rather than about" in FLAT)
    check(g, "R8 retracts the clean audit and names the ternary that caused it",
          "ternary in its register normaliser was the wrong way round" in FLAT)
    check(g, "R8 records that the linter had never recognised a callee-saved register",
          "had never once recognised a callee-saved register" in FLAT)
    check(g, "and the positive control exists because of it",
          "control.s exists because" in FLAT)
    check(g, "R9 retracts the guessed half of the .eh_frame cost, not the measured half",
          "HALF MEASURED" in T and "high by a factor of about" in FLAT)
    check(g, "R9's replacement figure is the one section 8 measured",
          "428" in T and "about TWO bytes of table" in FLAT)
    check(g, "R10 retracts the 148 as ARITHMETIC and names the overlap",
          "RETRACTED AS ARITHMETIC" in FLAT)
    r10 = re.search(r"overlap rather than assuming it: (\d+) of the flags", FLAT)
    check(g, "and R10's overlap is the number section 9 measured, not a literal",
          r10 is not None and both is not None and r10.group(1) == both[0],
          "R10 says %s, CLAPPERBOTH says %s" % (r10.group(1) if r10 else "?",
                                                both[0] if both else "?"))
    if r10 and both:
        check(g, "and the true remainder follows from the measured overlap",
              str(int(both[0]) + int(flags[0]) - 26 - int(ctx[0])) in T,
              "%d + %d - 26 - %d" % (int(both[0]), int(flags[0]), int(ctx[0])))
    check(g, "and the artifact's own direction-flag arm is repaired in place",
          "DF after the `cld`" in T and "bit 10 = 0" in FLAT)
    check(g, "and it says WHY, because the symptom was a silent hang",
          "scans backwards" in FLAT and "hung" in FLAT)
    check(g, "the limits block is printed, not footnoted",
          "LIMITS, and each one names the thing that would settle it" in T)
    for lim in ["ANY CYCLE COUNT", "WHETHER A SIGNAL RESPECTOR RESPECTS THE RED ZONE",
                "WHY THE psABI SAYS 16 AND NOT 8", "WINDOWS x64"]:
        check(g, "limit present: %s" % lim[:40], lim in T)
    check(g, "the verdict says what the artifact CAN support",
          "What this artifact can support" in T)
    check(g, "and what it cannot", "What it cannot support" in T)
    ck = one(r"checksums folded in: 0x([0-9a-f]+)", T)
    check(g, "a running checksum is printed, so a silent no-op cannot pass",
          ck is not None, "0x%s" % ck)
    rowsm = one(r"rows measured: (\d+)", T)
    check(g, "and a row count", rowsm is not None and int(rowsm) > 20, "%s rows" % rowsm)

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
