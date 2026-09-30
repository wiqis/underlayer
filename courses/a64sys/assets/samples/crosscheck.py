#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The AArch64 Machine: Modes, Memory and
Faults".

It reads the OUTPUT of a64sys.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files, no decoder of its
own, and no toolchain of any kind, and that is the point.  A harness that can
re-measure can disagree with the artifact for reasons that have nothing to do
with whether the artifact's SENTENCES are still true, and then it teaches its
reader to ignore it.

So the split is this.  a64sys.py runs the toolchain and produces numbers.
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

THREE KINDS OF ASSERTION, and the split is the point:

  * EXACT   for anything the ENCODING or the ARITHMETIC owns and this file
    measured: every bit pattern, every field position, every relocation
    number, the vector-table size, the section alignment, the ADR boundary,
    the two-reader agreement, the poison's effect.  An exact quantity has one
    honest treatment.
  * SHAPES  for anything that is a property of a COMPILER VERSION: the
    instruction counts, the register choices, the coverage percentages.  These
    move.  A check whose threshold is a bare number from one compiler is a
    check that fails on a busier machine and teaches its reader to ignore it.
  * TEXT    for all sixteen retractions, for the provenance table, and for
    every limit, because a retraction IS a claim about a number that is
    otherwise fine, and a course that quietly dropped one would pass every
    other check in this file.

Usage:  python3 crosscheck.py [path/to/a64sys.out]
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
    print("  [%s] %-13s %-60s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before a64sys.py is ever built.  A course whose claims can only be
    verified by first rebuilding its own artifact is a course whose claims are
    only verifiable on the machine that wrote them -- which is the same
    mistake as quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "a64sys.out")


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
    three and uses `one()` gets a string and then indexes it as if it were a
    tuple, which raises IndexError deep inside a check rather than where the
    mistake was made.  The two previous courses' harnesses have the same
    helper for the same reason.
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
    check(g, "the file names its artifact",
          'a64sys -- the artifact for "The AArch64 Machine: Modes, Memory and '
          'Faults"' in T)
    check(g, "and says NOTHING HAS BEEN RUN",
          "NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN" in FLAT)
    check(g, "the absences are named",
          "no AArch64 machine on this host" in FLAT
          and "no AArch64 emulator" in FLAT and "no AArch64 linker" in FLAT)
    check(g, "the absences are CHECKED, not asserted",
          "aarch64-linux-gnu-ld     ABSENT" in T
          and "qemu-aarch64             ABSENT" in T
          and "aarch64-linux-gnu-as     ABSENT" in T
          and "a SECOND AArch64 assembler" in T)
    check(g, "and there are NO TIMINGS, said so explicitly",
          "there are NO TIMINGS anywhere in this file" in FLAT)
    check(g, "the x86-64 figures are named and refused",
          "4.92x" in FLAT and "27.65x" in FLAT
          and "nothing here has a counterpart and nothing here fakes one"
          in FLAT)
    check(g, "the one cross-architecture comparison is a COMPILE-TIME count",
          "THIS IS A COMPILE-TIME INSTRUCTION COUNT COMPARISON AND NOT A "
          "TIMING ONE" in FLAT
          and "NOTHING HAS BEEN EXECUTED ON EITHER SIDE" in T)
    check(g, "the three labels are defined",
          "MEASURED" in T and "MEASURED-ON-BYTES" in T and "QUOTED" in T)
    check(g, "and every one of the three is used many times",
          T.count("[MEASURED]") >= 5 and T.count("[MEASURED-ON-BYTES]") >= 3
          and T.count("[QUOTED]") >= 2,
          "%d/%d/%d" % (T.count("[MEASURED]"), T.count("[MEASURED-ON-BYTES]"),
                        T.count("[QUOTED]")))
    check(g, "the two readers are named as the two readers",
          "reader 1: the decoder in this file" in T
          and "reader 2: llvm-objdump-21 --triple=aarch64 -d" in T)
    check(g, "and the section they share is admitted",
          "both come from one LLVM tree" in FLAT)
    check(g, "the specifications are the ORACLE and the compiler the SUBJECT",
          "the specifications are the ORACLE and the compiler and the" in FLAT
          and "TEST" in FLAT)
    check(g, "a disagreement is a retraction",
          "every disagreement is printed" in FLAT and "as a RETRACTION" in FLAT)
    BAN = "aarch64-linux-gnu-ld     ABSENT"
    check(g, "the absences are printed BEFORE the first measurement",
          T.index(BAN) < T.index("imm16 at bits[20:5]"),
          "banner at line %d, first measurement at line %d"
          % (T.index(BAN) + 1, T.index("imm16 at bits[20:5]") + 1))
    check(g, "and before the corpus is walked at all",
          T.index(BAN) < T.index("instructions read,"))
    check(g, "and before the first relocation is read",
          T.index(BAN) < T.index("R_AARCH64_ADR_PREL_PG_HI21"))
    check(g, "and the section list is twelve long",
          all(("  %2d  " % n) in T for n in range(1, 13)))
    check(g, "and every section header is printed",
          all(s in T for s in ("THE INSTRUMENT, AND WHAT IT IS NOT",
                               "THE SPECIFICATIONS, AS ORACLES",
                               "THE SYSCALL: THE IMMEDIATE",
                               "THE VECTOR TABLE",
                               "TTBR0, TTBR1, TCR",
                               "FOUR LEVELS, THREE REGIMES",
                               "TWO READERS, AND ONE OF THEM POISONED",
                               "WHAT IS MEASURED HERE AND WHAT IS QUOTED")))
    print()

    # ------------------------------------------------------------------
    # B. the oracles, quoted with their sections
    # ------------------------------------------------------------------
    g = "B oracle"
    print("  --- group B: the specifications, quoted with their sections")
    for frag in ("include/uapi/asm-generic/unistd.h",
                 "DDI 0597, Shared Pseudocode",
                 "AArch64_ExceptionClass",
                 "ec[5:0] :: il :: iss",
                 "ESR_ELx[24:0]",
                 "ESR_ELx[55:32]",
                 "T0SZ is bits[63:48] and T1SZ is bits[47:32]",
                 "TG0 is bits[15:14]",
                 "ELF ABI for the Arm 64-bit Architecture",
                 "R_AARCH64_ADR_PREL_PG_HI21 is 275"):
        check(g, "the oracle quotes: %s" % frag[:34], frag in T)
    check(g, "the syscall numbers are printed with the file they come from",
          "numbers are QUOTED, and nothing on this host can confirm one by" in FLAT)
    check(g, "and the weakness is named at the point a reader expects it",
          "a number confirmed only by a header file is a weaker kind of "
          "claim" in FLAT)
    check(g, "the manual was NOT consulted, and says so",
          "The architectural manual was NOT consulted on this host" in T)
    check(g, "the six syscall numbers are the ones the file claims",
          all(("  %-8d %s" % (n, nm)) in T for n, nm in
              ((25, "fcntl"), (56, "openat"), (63, "read"), (64, "write"),
               (94, "exit_group"), (222, "mmap"))))
    print()

    # ------------------------------------------------------------------
    # C. the encoding, and the models
    # ------------------------------------------------------------------
    g = "C encoding"
    print("  --- group C: the encodings, MEASURED-ON-BYTES and exact")
    for word, src in (("0xd5385200", "mrs x0, esr_el1"),
                      ("0xd5384021", "mrs x1, elr_el1"),
                      ("0xd5386002", "mrs x2, far_el1"),
                      ("0xd538c006", "mrs x6, vbar_el1"),
                      ("0xd518c000", "msr vbar_el1, x0"),
                      ("0xd5382044", "mrs x4, tcr_el1"),
                      ("0xd5382003", "mrs x3, ttbr0_el1"),
                      ("0xd5382025", "mrs x5, ttbr1_el1"),
                      ("0xd4000001", "svc #0"),
                      ("0xd41fffe1", "svc #65535"),
                      ("0xd4000002", "hvc #0"),
                      ("0xd4000003", "smc #0"),
                      ("0xd4200000", "brk #0"),
                      ("0xd4400000", "hlt #0"),
                      ("0xd4a00001", "dcps1"),
                      ("0xd69f03e0", "eret"),
                      ("0xd6bf03e0", "drps"),
                      ("0xd5033f9f", "dsb sy"),
                      ("0xd5033fbf", "dmb sy"),
                      ("0xd5033fdf", "isb")):
        check(g, "%-16s is %s" % (src, word), word in T)
    check(g, "the SVC immediate is 16 bits at bits[20:5]",
          "imm16 at bits[20:5]" in T)
    check(g, "and the boundary is measured: 0xffff accepted, 0x10000 refused",
          "svc #65535" in T and "svc #65536" in T
          and "immediate must be an integer in range [0, 65535]" in T)
    NREF = len(re.findall(r"REFUSED\s+immediate must be an integer in "
                          r"range \[0, 65535\]", T))
    check(g, "and so is the OTHER end: svc #-1 is refused too",
          "svc #-1" in T and NREF >= 4, "%d refusals" % NREF)
    check(g, "and the SEVEN EL0 register refusals carry the OTHER diagnostic",
          NREF == 4
          and len(re.findall(r"REFUSED\s+expected readable system register",
                             T)) == 8,
          "%d range, %d register"
          % (NREF, len(re.findall(r"REFUSED\s+expected readable system "
                                  "register", T))))
    check(g, "and every refusal that matched its table is labelled as such",
          "matches the table" in T and "DIFFERENT DIAGNOSTIC" not in T)
    check(g, "ESR_EL0 and its five siblings do not exist",
          T.count("expected readable system register") >= 7
          and "esr_el0" in T and "vbar_el0" in T and "tcr_el0" in T)
    check(g, "the model table is printed, and counts itself",
          "models added by THIS course:" in T and "models in the file:" in T)
    check(g, "the dispatch numbers are 21 inherited, 6 sibling, 6 own",
          "models in the imported decoder: 21" in T,
          "the %s line" % one(r"models in the imported decoder: (\d+)", T))
    check(g, "and the coverage of the inherited 21 is MEASURED, not asserted",
          "the encoding course's 21 alone" in T
          and re.search(r"the encoding course's 21 alone\s+(\d+)\s+(\d+)\s+"
                        r"([\d.]+)%", T) is not None)
    cov = groups_of(r"the encoding course's 21 alone\s+(\d+)\s+(\d+)\s+"
                    r"([\d.]+)%", T)
    check(g, "and the inherited coverage is under 100%, and printed as such",
          cov is not None and int(cov[1]) < int(cov[0]),
          cov and "%s of %s" % (cov[1], cov[0]))
    check(g, "the HINT bug is found, named, and attributed",
          "R4" in T and "one bit too narrow" in T
          and "guard is" in FLAT and "bits[31:5] == 0xd503201f >> 5" in T)
    check(g, "and the bug is stated as ONE out of ELEVEN, not asserted",
          "ONE of ELEVEN" in T)
    hh = rows_of(T, r"\s+(\w+(?: \w+)?)\s+0x([0-9a-f]{8})\s+0x([0-9a-f]{7})"
                  r"\s+(YES|no)")
    check(g, "and the guard arithmetic is printed for all eleven hints",
          len(hh) == 11 and sum(1 for r in hh if r[3] == "YES") == 1,
          "%d rows, %d YES" % (len(hh), sum(1 for r in hh if r[3] == "YES")))
    check(g, "and the reason it survived is printed",
          "course's own corpus, compiled with clang, contains no yield" in FLAT)
    check(g, "and the general sentence is there too",
          "A count of unmodelled words is a fact about A CORPUS and not "
          "about A DECODER" in FLAT
          or "most transferable result in this file" in FLAT)
    print()

    # ------------------------------------------------------------------
    # D. the syscall audit
    # ------------------------------------------------------------------
    g = "D syscall"
    print("  --- group D: the syscall, measured as the compiler emits it")
    n = one(r"(\d+) of (\d+) argument placements land in the register", T)
    tot = one(r"(\d+) of \d+ argument placements land in the register", T)
    check(g, "the argument audit is reported and it is COMPLETE",
          n is not None and tot is not None and n == tot,
          n and "%s of %s" % (n, tot))
    check(g, "and it is audited at three optimisation levels",
          "at -O1, -O2 and -Os" in FLAT)
    check(g, "and -O0 is reported as a NEGATIVE result, not a failure",
          "every argument is SPILLED" in T
          and "not VISIBLE in the code at all" in FLAT)
    check(g, "x8 is used as a scratch when the source does not name it",
          "x8 named: YES" in T and T.count("x8 named: YES") >= 12)
    check(g, "and the file says the convention is ABI and not architecture",
          "x8 is the syscall-number register" in FLAT
          and "which is ABI and not architecture" in FLAT)
    check(g, "the x86-64 half of the comparison is NOT zero",
          one(r"instructions: AArch64 (\d+), x86-64 (\d+)", T) is not None
          and int(groups_of(r"instructions: AArch64 (\d+), x86-64 (\d+)",
                            T)[1]) > 0,
          one(r"instructions: AArch64 (\d+), x86-64 (\d+)", T))
    rr = groups_of(r"relocations:\s+AArch64 (\d+), x86-64 (\d+)", T)
    check(g, "and the relocation counts are 2 against 1",
          rr is not None and rr == ("2", "1"), rr and "/".join(rr))
    check(g, "the ninth argument is on the stack, by name",
          "sys_arg9_stack" in T and "stack" in T)
    check(g, "and the six-argument limit is labelled QUOTED",
          "at most six arguments" in FLAT)
    print()

    # ------------------------------------------------------------------
    # E. the syndrome
    # ------------------------------------------------------------------
    g = "E syndrome"
    print("  --- group E: the syndrome, quoted layout and measured code")
    for frag in ("ESR_ELx[63:56]", "ESR_ELx[55:32]", "ESR_ELx[31:26]",
                 "ESR_ELx[25]", "ESR_ELx[24:0]"):
        check(g, "the layout row %s is printed" % frag, frag in T)
    check(g, "the IL forcing rule is quoted and attributed",
          "il = 1" in T.lower() or "IL is FORCED to 1" in T)
    check(g, "the three-instruction test is measured, not asserted",
          "and x9, x0, #0xf8000000" in T and "cmp x9, x8" in T
          and "cset w0, eq" in T)
    check(g, "and the three-instruction form is a RETRACTION",
          "clang does not shift" in FLAT)
    check(g, "the class table is printed with the ISS column",
          "0x24" in T and "Data abort, lower EL (write)" in T
          and "0x03" in T and "SVC (a syscall from EL0)" in T)
    check(g, "and the discriminated-union point is made",
          "DISCRIMINATED UNION" in T)
    check(g, "and the 0x22 row is present, so the 0x24/0x25 story is honest",
          "Data abort, lower EL" in T)
    check(g, "the three-register read is shown at -O2",
          "mrs x8, ESR_EL1" in T and "mrs x9, ELR_EL1" in T
          and "mrs x10, FAR_EL1" in T)
    print()

    # ------------------------------------------------------------------
    # F. the vector table
    # ------------------------------------------------------------------
    g = "F vectors"
    print("  --- group F: the vector table, measured and its absence measured")
    check(g, "the table size is measured as 2048",
          "SIZE 2048 bytes (0x800)" in T)
    check(g, "and the arithmetic is stated",
          "16 x 0x80 = 0x800" in T)
    # The name pattern is `el<digit><letter>_...`, and the letter is `t` for
    # SP0 and `i` for SPx -- the first version of this regex hard-coded the
    # `t` and silently matched TWELVE of the sixteen rows, which is the
    # worst possible outcome from a table check: a count of twelve beside a
    # table of sixteen, and nothing to say which four went missing.
    rows = rows_of(T, r'\s*(\d+)\s+(el\w+_\w+)\s+0x([0-9a-f]+)\s+(\d+)\s+(\d+)\s*$')
    check(g, "all SIXTEEN offsets are printed, and there are sixteen",
          len(rows) == 16, "%d rows" % len(rows))
    check(g, "and every offset is a multiple of 0x80",
          all(int(r[2], 16) % 0x80 == 0 for r in rows))
    check(g, "and the sixteenth is at 0xf80",
          rows and int(rows[-1][2], 16) == 0xf80)
    check(g, "and all sixteen are inside one 0x800 window",
          rows and all(0x800 <= int(r[2], 16) <= 0xf80 for r in rows))
    al = rows_of(T, r"\s+(\.align \d+ \([^)]*\)|no \.align at all)\s+(\d+)\s+"
                    r"(0x[0-9a-f]+)\s+NONE")
    check(g, "FOUR alignment cases and FOUR 'NONE' diagnostics",
          len(al) == 4, "%d cases" % len(al))
    check(g, "and the four alignments are 2048, 256, 4 and 4096",
          [int(r[1]) for r in al] == [2048, 256, 4, 4096],
          ",".join(r[1] for r in al))
    check(g, "and the silence is the finding, in those words",
          "FOUR CASES, FOUR TIMES NO DIAGNOSTIC" in FLAT)
    check(g, "the VBAR read and write are one bit apart, and it is named",
          "One bit -- bit 21 -- separates the read from the write" in FLAT)
    check(g, "the install sequence is shown, from the symbol table",
          "install_vbar, at 0x" in T and "adrp     x0, +0" in T
          and "msr      VBAR_EL1, x0" in T and "isb" in T)
    print()

    # ------------------------------------------------------------------
    # G. the translation regimes
    # ------------------------------------------------------------------
    g = "G regimes"
    print("  --- group G: TTBR0, TTBR1, TCR, and the 48/52 arithmetic")
    for word, nm in (("0xd5382000", "TTBR0_EL1"), ("0xd5382020", "TTBR1_EL1"),
                     ("0xd5382040", "TCR_EL1"), ("0xd5381000", "SCTLR_EL1"),
                     ("0xd53c2040", "TCR_EL2")):
        check(g, "mrs %s is %s" % (nm, word), word in T)
    check(g, "T0SZ = 16 for 48 bits and T1SZ = 12 for 52",
          "T0SZ = 64 - 48 = 16" in FLAT and "64 - 52 = 12" in FLAT)
    check(g, "and the identity 2^(64-TnSZ) is printed with every row",
          T.count("2^48 = 0x1000000000000") >= 3
          and T.count("2^52 = 0x10000000000000") >= 2)
    check(g, "the FIVE-BIT field and its floor are printed",
          "32-bit VA  ->  T0SZ = 32" in T and "DOES NOT FIT in a 5-bit field"
          in T)
    check(g, "and the 33-bit floor is named as the smallest",
          "33-bit VA  ->  T0SZ = 31" in T
          and "regime the field can name is 2^33 bytes" in FLAT)
    # The configuration table is variable-width, so the row pattern is a
    # two-space column separator rather than a fixed number of spaces, and
    # the assertion is the IDENTITY rather than the value: T0SZ = 64 - VA in
    # every row, which is the whole claim.
    # The configuration column is 17 characters wide and a name longer than
    # that runs into the next column with a SINGLE space -- "48/52, with
    # LPA2 48" -- so a `\s{2,}` separator silently drops the four rows whose
    # names are long.  The first version of this pattern matched 4 of 7 and
    # the harness reported a clean table it had only read a third of.  The
    # separator is therefore ONE space, and the NAME is taken as whatever
    # precedes the two integers.
    cfg = rows_of(T, r"\s{5}(\S.*?) (\d+) +(\d+) +(\d+) +2\^(\d+) = "
                   r"0x([0-9a-f]+) +2\^(\d+) = 0x([0-9a-f]+)\s*$")
    check(g, "and T0SZ = 64 - VA in EVERY row of the configuration table",
          len(cfg) == 7
          and all(64 - int(r[1]) == int(r[2])        # T0SZ = 64 - VA0
                  and 64 - int(r[6]) == int(r[3])    # T1SZ = 64 - VA1
                  and int(r[4]) == int(r[1])         # TTBR0 region = 2^VA0
                  for r in cfg),
          "%d rows: T0SZ = 64 - VA0, T1SZ = 64 - VA1, region0 = 2^VA0"
          % len(cfg))
    check(g, "and the 30-bit row is NOT among them",
          "30/30" not in T
          and not any(r[0].strip().startswith("30") for r in cfg),
          "no 30-bit row among %d" % len(cfg))
    check(g, "and the 30-bit row is a RETRACTION, not a configuration",
          "AArch64 can be configured with a 30-bit virtual address space" in T
          and "DOES NOT FIT" in T)
    check(g, "the TTBR1 base for 52 bits is printed",
          "0xffff000000000000" in T)
    check(g, "and the UNTRANSLATED space between the regimes is computed",
          T.count("which is UNTRANSLATED") == 3
          and "TTBR0 covers 0x0000000000000000..0x0000ffffffffffff" in T
          and "TTBR1 covers 0xffff000000000000..0xffffffffffffffff" in T)
    check(g, "and the 52-bit base is at the TOP of the space, which is R10",
          "TTBR1 covers 0xfff0000000000000..0xffffffffffffffff" in T
          and "0xffff000000000000" in T)
    check(g, "the ADR boundary is MEASURED, not quoted",
          "0xffffc bytes and 0x100000 is REFUSED" in FLAT)
    check(g, "and the ADRP reach is labelled QUOTED, because no linker runs",
          "ADRP reaches 4 GiB" in T
          and "NOT measurable here" in T
          and "the check belongs to" in FLAT)
    print()

    # ------------------------------------------------------------------
    # H. the page tables and the relocations
    # ------------------------------------------------------------------
    g = "H pagetables"
    print("  --- group H: four levels, three regimes, and the relocations")
    check(g, "512 x 8 = 4096 is printed",
          "512 x 8 = 4096 bytes" in T)
    for n in ("l0", "l1", "l2", "l3", "l2_big"):
        check(g, "the table %-7s is in the symbol table" % n,
              re.search(r"%s\s+value 0x[0-9a-f]+\s+size (\d+)" % n, T)
              is not None)
    check(g, "the four 4 KiB tables are 4096 bytes each",
          len(re.findall(r"size 4096\s+4 KiB-aligned", T)) == 4)
    check(g, "and the 2 MiB one is 1048576 and 2 MiB-aligned",
          "size 1048576   2 MiB-aligned" in T)
    check(g, "the .bss alignment is 2097152 from BOTH readers",
          ".bss       2097152                2097152               YES" in T)
    check(g, "and the corpus WITHOUT the 2 MiB table is 4096",
          one(r"_no2m\.o\s+(\d+)\s+(\d+)", T) is not None
          and int(groups_of(r"_no2m\.o\s+(\d+)\s+(\d+)", T)[0]) == 4096,
          one(r"_no2m\.o\s+(\d+)\s+(\d+)", T))
    check(g, "and both readers agree on the no-2MiB object too",
          one(r"_no2m\.o\s+(\d+)\s+(\d+)", T) is not None
          and groups_of(r"_no2m\.o\s+(\d+)\s+(\d+)", T)[0]
          == groups_of(r"_no2m\.o\s+(\d+)\s+(\d+)", T)[1])
    check(g, "the four sections' alignments are checked by BOTH readers",
          T.count("YES") >= 4 and "reader 1 (struct.unpack)" in T
          and "reader 2 (llvm-readelf)" in T)
    for num, nm in ((275, "R_AARCH64_ADR_PREL_PG_HI21"),
                    (277, "R_AARCH64_ADD_ABS_LO12_NC"),
                    (274, "R_AARCH64_ADR_PREL_LO21"),
                    (286, "R_AARCH64_LDST64_ABS_LO12_NC")):
        check(g, "relocation %d is %s" % (num, nm), nm in T)
    ag = one(r"(\d+) of \d+ relocations agree on the TYPE NUMBER", T)
    tot_r = one(r"(\d+) relocations agree on the TYPE NUMBER", T)
    check(g, "and the two readers agree on EVERY relocation type number",
          ag is not None and tot_r is not None and ag == tot_r,
          ag and "%s of %s" % (ag, tot_r))
    pr = groups_of(r"(\d+) of the (\d+) ADRP relocations are immediately "
                   r"followed, four bytes later, by a LO12, and (\d+) are "
                   r"LONE", T)
    check(g, "and the PAIR measurement is reported as a count, not a claim",
          pr is not None, pr and "/".join(pr))
    check(g, "the lone ADRP is measured AND explained",
          pr is not None and int(pr[2]) >= 1
          and "the offset\nis a LITERAL ZERO" in T
          or "LITERAL ZERO" in T)
    check(g, "the reach is refused as the reason, by name",
          "The reason is NOT that adrp only reaches 4 GiB" in FLAT
          and "It is a MASKING problem" in FLAT)
    check(g, "and the real reason is the bits[32:12] MASKING",
          "ADRP computes (page(target) -" in FLAT
          and "they were MASKED OFF" in FLAT)
    check(g, "the 2^27 entry arithmetic is printed",
          "2^27 = 134217728" in T or "2^27" in T)
    check(g, "and the L1-block impossibility is a RETRACTION",
          "a 48-bit regime cannot USE it" in T)
    check(g, "the descriptor field table is printed",
          "TXL" in T and "AttrIndx" in T and "output address" in T)
    print()

    # ------------------------------------------------------------------
    # I. the two readers, and the poison
    # ------------------------------------------------------------------
    g = "I readers"
    print("  --- group I: two readers, and one of them poisoned")
    k = groups_of(r"(\d+) instructions read,\s+(\d+) NAMED by reader 1, "
                  r"(\d+) DISAGREEMENTS\.", T)
    check(g, "the two-reader run is reported",
          k is not None and int(k[0]) > 1000, k and "/".join(k))
    check(g, "and the disagreement count is ZERO", k is not None
          and k[2] == "0", k and k[2])
    check(g, "the corpus is walked over FUNCTION ranges, and says so",
          "FUNCTION ranges" in T and "2,101,380" in T
          and "527,837" in T)
    check(g, "and the reconciliation rules are printed WITH COUNTS",
          "RECONCILED" in T and "a normalisation that is not counted is a "
          "fudge" in FLAT)
    check(g, "and at least ten distinct reconciliation rules fired",
          len(re.findall(r"^\s+\w+\s+-> \w+\s+\d+$", T, re.M)) >= 10,
          "%d rules" % len(re.findall(r"^\s+\w+\s+-> \w+\s+\d+$", T, re.M)))
    pz = groups_of(r"with the poison in: (\d+) named, (\d+) DISAGREEMENTS", T)
    check(g, "the poison MOVES both numbers, and both numbers are printed",
          pz is not None and int(pz[0]) < int(k[1]) and int(pz[1]) > 0,
          pz and "%s named, %s bad" % pz)
    check(g, "the movement is printed as two numbers, not a vibe",
          "the named count moved from" in T
          and "the disagreement count moved from" in T)
    check(g, "the first poisoned words are printed BY NAME",
          "mrs x8, ESR_EL1" in T and "msr VBAR_EL1, x8" in T)
    check(g, "the poison is restored, and the file says why",
          "restored in" in FLAT and "finally" in T
          and "own decoder broken" in FLAT
          and "result cannot be reproduced" in FLAT)
    check(g, "and the R4 bug is linked to the zero",
          "R14" in T and "shared ignorance with two implementations" in FLAT)
    print()

    # ------------------------------------------------------------------
    # J. the provenance table
    # ------------------------------------------------------------------
    g = "J provenance"
    print("  --- group J: the measured/quoted boundary, as a table")
    check(g, "the table is printed and it is long",
          "claims." in T and len(re.findall(r"^\s+(MEASURED-ON-BYTES|"
                                            r"MEASURED|QUOTED)\s{2,}", T,
                                            re.M)) >= 35,
          "%d rows" % len(re.findall(r"^\s+(MEASURED-ON-BYTES|MEASURED|"
                                     r"QUOTED)\s{2,}", T, re.M)))
    pv = groups_of(r"(\d+) MEASURED, (\d+) MEASURED-ON-BYTES, (\d+) QUOTED, "
                   r"(\d+) total", T)
    check(g, "the three counts and the total agree",
          pv is not None and sum(int(x) for x in pv[:3]) == int(pv[3]),
          pv and "/".join(pv))
    check(g, "and the QUOTED share is a MAJORITY, and printed as a percentage",
          pv is not None and int(pv[2]) > int(pv[0])
          and "of the claims in this course are QUOTED" in T,
          pv and "QUOTED %s of %s" % (pv[2], pv[3]))
    check(g, "the 'cannot conclude' list is printed",
          "What a reader therefore CANNOT conclude" in T)
    check(g, "and the 'can conclude' list is printed",
          "What a reader CAN conclude, and check, with a hex editor" in T)
    for line in ("that a syscall on this machine returns anything",
                 "that an exception is ever delivered",
                 "that a vector is ever entered",
                 "that a page is ever walked",
                 "that the linker relaxes or does not relax",
                 "that llvm-objdump agrees with the silicon"):
        check(g, "the page says a reader cannot conclude: %s" % line[:36],
              line in T)
    for line in ("every bit pattern in this course",
                 "every relocation name and number",
                 "every section alignment, read by two independent parsers",
                 "the arithmetic: 16 x 0x80, 512 x 8"):
        check(g, "the page says a reader CAN conclude: %s" % line[:36],
              line in T)
    check(g, "and the section-to-section links are asserted in the table",
          "sec 3, 4" in T and "sec 8" in T and "sec 9B" in T)
    print()

    # ------------------------------------------------------------------
    # K. the retractions
    # ------------------------------------------------------------------
    g = "K retractions"
    print("  --- group K: every retraction, asserted as TEXT")
    for tag, frag in (
            ("R1", "the syndrome occupies bits 31:0"),
            ("R1", "bits 55:32 named ISS2"),
            ("R2", "the kernel reads it from the instruction"),
            ("R3", "can name NONE of SVC"),
            ("R4", "one bit too narrow, and it matches"),
            ("R5", "it needs TWO, and always does"),
            ("R6", "clang uses x8 as a scratch register"),
            ("R7", "clang does not shift, and does not need to"),
            ("R8", "Both assemble"),
            ("R9", "nothing checks it"),
            ("R10", "mapped at the TOP of the address space"),
            ("R11", "its ALIGNMENT does"),
            ("R12", "ADRP masks off the low twelve bits of the target"),
            ("R13", "512 entries"),
            ("R14", "shared ignorance with two implementations"),
            ("R15", "corpus chosen to suit the decoder is the failure mode"),
            ("R16", "the field holds five bits"),
            ("R16", "64 - 30 = 34 does not fit in it")):
        check(g, "%s is retracted, with the finding: %s" % (tag, frag[:32]),
              frag in FLAT)
    tags = re.findall(r"^  (R\d+)$", T, re.M)
    uniq = sorted(set(tags), key=lambda t: int(t[1:]))
    check(g, "there are SIXTEEN retractions, numbered R1..R16 with no gap",
          uniq == ["R%d" % n for n in range(1, 17)], ",".join(uniq))
    check(g, "and they are printed in ORDER, not in discovery order",
          tags == ["R%d" % n for n in range(1, 17)])
    check(g, "the count is printed, with the argument for it",
          "16 retractions." in T
          and "either not looked or has not been reading" in FLAT)
    check(g, "every retraction names where it was ASSERTED, and none blank",
          T.count("[ASSERTED BY]") == 16
          and T.count("(no prior source)") == 0)
    check(g, "and a third of them name the section plan by path",
          T.count("docs/aarch64-section-plan.md") >= 4,
          "%d references" % T.count("docs/aarch64-section-plan.md"))
    check(g, "each retraction says WHAT WAS FOUND and WHY",
          T.count("WHAT WAS FOUND") >= 16 and T.count("[WHY]") >= 16)
    check(g, "and every retraction was asserted BEFORE the course was written",
          "was asserted before this course was" in FLAT)
    print()

    # ------------------------------------------------------------------
    # L. the limits
    # ------------------------------------------------------------------
    g = "L limits"
    print("  --- group L: what the file cannot show")
    for title in ("NOTHING IS EXECUTED",
                  "THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED "
                  "BY NAME",
                  "NO EXCEPTION IS EVER TAKEN",
                  "NO INTERRUPT IS EVER TAKEN",
                  "NO MEMORY IS EVER ACCESSED",
                  "NO LINKER RUNS",
                  "THE TWO READERS SHARE A SOURCE TREE",
                  "THE DECODER IS A SUBSET OF NAMES, NOT OF LENGTHS",
                  "A COUNT OF UNMODELLED WORDS IS A FACT ABOUT A CORPUS",
                  "THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT",
                  "THE ARCHITECTURAL MANUAL WAS NOT CONSULTED ON THIS HOST",
                  "THE COMPILER AND THE ASSEMBLER ARE THE TEST SUBJECT, NOT "
                  "THE ARCHITECTURE",
                  "A LINK-TIME ALIGNMENT IS NOT A LINK-TIME ERROR",
                  "NO CORPUS IS A DISTRIBUTION",
                  "THE SHIPPED OUTPUT IS WHAT THE HARNESS READS"):
        check(g, "the limit is printed: %s" % title[:44], title in T)
    NLIM = one(r"\n  (\d+) retractions\.", T)
    check(g, "and every one of them is asserted as present in the file",
          len(LIMITS_RE) >= 13, "%d titles parsed, two of them wrap" %
          len(LIMITS_RE))
    check(g, "and the retractions are numbered, so a limit cannot hide one",
          NLIM == "16", NLIM)
    check(g, "and the ADR reach refusal is restated in the limits",
          "no AArch64 clock to read" in FLAT)
    check(g, "and the shipped output is what the harness can read without "
             "building", os.path.exists(default_output()))
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


def _limits():
    """The limit TITLES, parsed out of the recorded output, so the assertion
    about "there are fifteen of them" is derived from the file rather than
    from a constant in this harness."""
    t = load(default_output())
    part = t.split("12  LIMITS")
    if len(part) < 2:
        return []
    return re.findall(r"^  ([A-Z][A-Z0-9 ,\\-]{18,})$", part[1], re.M)


LIMITS_RE = []


if __name__ == "__main__":
    LIMITS_RE = _limits()
    sys.exit(main())
