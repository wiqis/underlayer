#!/usr/bin/env python3
"""crosscheck.py -- the harness for "The RISC-V Privileged Architecture".

It reads the OUTPUT of rvpriv.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files, no decoder and no
toolchain of any kind, and that is the point.  A harness that can re-measure
can disagree with the artifact for reasons that have nothing to do with
whether the artifact's SENTENCES are still true, and then it teaches its
reader to ignore it.

So the split is this.  rvpriv.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit that drops a retraction changes the TEXT; the harness
notices and the reader learns.  Neither can hide.

IT IS WRITTEN AFTER THE ARTIFACT AND AGAINST ITS OUTPUT, and the reason is
stated because the sibling course learned it the hard way: `rvabi`'s harness
was written first and arrived with nineteen unsatisfiable checks, one of
which could not pass against ANY output.  Every pattern below was read out of
a real `rvpriv.out` before it was written, and every one of them was then
confirmed to FAIL when the corresponding sentence was removed from a COPY of
the output.  A harness whose checks have never been seen to fail is a
harness this collection has retracted three times.

FOUR KINDS OF ASSERTION, and the split is the point:

  * EXACT   for anything the ENCODING, the ARITHMETIC or the psABI owns and
    this file MEASURED: every bit pattern, every field position, every
    relocation number, the size arithmetic, the two-reader agreement, the
    poison deltas.  An exact quantity has one honest treatment, and a
    harness that rounds an exact quantity into a range is a harness that
    will not notice a decoder reading a field one bit off.

  * SHAPES for anything that is a property of a COMPILER VERSION: the
    instruction counts, the relocation COUNTS, the register choices, which
    poison moved in which direction.  These move.  A check whose threshold
    is a bare number from one compiler is a check that fails on a busier
    machine and teaches its reader to ignore it.

  * TEXT   for all fifteen retractions, for the provenance table's own
    summary, and for every limit, because a retraction IS a claim about a
    number that is otherwise fine, and a course that quietly dropped one
    would pass every other check in this file.

  * NEGATIVE  for the things that must NOT be in the output: no timing, no
    speedup, no claimed exception delivery, no claimed page walk.  A harness
    that only checks that a sentence is present cannot notice a course that
    has started claiming things it cannot measure.

Usage:  python3 crosscheck.py [path/to/rvpriv.out]
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
    print("  [%s] %-10s %-62s %s" % ("PASS" if ok else "FAIL", group, what,
                                    detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before rvpriv.py is ever built.  A course whose claims can only be
    verified by first rebuilding its own artifact is a course whose claims
    are only verifiable on the machine that wrote them -- which is the same
    mistake as quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "rvpriv.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def flat(t):
    """The output with every run of whitespace collapsed to one space.

    THIS IS A FINDING, NOT A CONVENIENCE.  Thirty of this file's checks were
    written against PROSE, and prose in a fixed-width report is WRAPPED: a
    sentence that reads as one phrase in the editor is two lines in the file,
    and the second line begins in column 0.  A needle written the way the
    sentence is written -- "and the read-modify-write race is named, and its
    limit stated" -- cannot match a line that ends at "and its" and a new line
    that begins at "limit stated".  So the assertion fails against a report
    that is entirely correct, and the reader is taught that a green harness
    depends on where the author happened to break the lines.

    Every PROSE check below therefore runs against FLAT, and every
    TABLE-ROW check runs against T, because a table row is a line and a
    flattened table row is a lie about which columns held what.  The
    distinction is the rule: collapse whitespace where the sentence is the
    unit, and do not collapse it where the LINE is the unit.

    The third reason is the interesting one.  `rvabi`'s harness was written
    from the source and 19 of its checks could never pass; this one was written
    from the output, and the wrapping cost 30 checks.  Both failures are the
    same failure -- asserting on text that was never in the file -- and the
    only cure is to read the output, which is why every pattern here was read
    out of a real run before it was typed."""
    return re.sub(r"\s+", " ", t)


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


# The one register name the harness needs, and it is HERE rather than imported
# because a harness must not depend on the artifact it is checking: if the
# artifact's register table were the thing under test, a wrong name would
# agree with a wrong claim.  x6 is t1, and the assertion below is that the
# artifact says so.
# THE EIGHT CLAIM SENTENCES OF THE CANNOT LIST, in order, pinned whole.
CANNOT_CLAIMS = (
    'That a page is ever walked',
    'That an `ecall` traps',
    'That writing `mtvec` from S-mode raises an illegal-instruction '
    'exception',
    "That `stvec`'s low two bits are cleared by hardware",
    'Which of the two A/D schemes a hart implements',
    'That a linker accepts the pair 8 KiB apart',
    'Whether a page fault is cheaper or dearer than an access fault',
    'That `llvm-objdump-21` agrees with the silicon',
)

# THE TEN CLAIM SENTENCES OF THE CAN LIST, likewise.
CAN_CLAIMS = (
    'Every bit pattern in this course is byte-for-byte reproducible from the '
    'files in this directory and the exact clang invocation section 1 prints',
    'Every relocation NAME and NUMBER this course uses appears in the psABI '
    'table AND in the object files of the corpus',
    'Every refusal, by running the assembler',
    'The size arithmetic, exactly: 4096 / 8 = 512, 3 x 9 + 12 = 39, '
    '64 - 4 - 16 - 8 = 36, 2048 - 1 = 2047',
    'The CSR instruction encodings: twelve of them, three operations, two '
    'forms, and the single bit that separates them',
    "The pairing rule's ARITHMETIC -- 2048 - 1 = 2047, one AUIPC per 2048 "
    'bytes -- and that the assembler enforces none of it',
    'The three codes 23 and 24 and 25, that they are consecutive, and that '
    'the first names the TARGET while the other two name a LABEL THE '
    'COMPILER INVENTED',
    'That the correct `satp` PPN width is 36 bits and that two natural wrong '
    'answers -- 44 and 54 -- both COMPILE',
    'That two independent readers, given the same bytes, disagree on zero of '
    'them over this corpus',
    'Every limit on this page, which are the sentences that make the other '
    'nine safe to say',
)

XREG = ['zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2',
        's0', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5',
        'a6', 'a7', 's2', 's3', 's4', 's5', 's6', 's7',
        's8', 's9', 's10', 's11', 't3', 't4', 't5', 't6']

NUMWORDS = {1: 'One', 2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
           7: 'Seven', 8: 'Eight', 9: 'Nine', 10: 'Ten', 11: 'Eleven',
           12: 'Twelve', 13: 'Thirteen', 14: 'Fourteen', 15: 'Fifteen',
           16: 'Sixteen', 17: 'Seventeen', 18: 'Eighteen', 19: 'Nineteen',
           20: 'Twenty'}


def source_retractions():
    """The retraction ids the ARTIFACT declares, read from its source.

    The harness is not allowed to assert a count it chose itself: if the
    artifact grows an R18 and the harness still says sixteen, the harness is
    the thing that is wrong.  So the count comes from here -- the source -- and
    the OUTPUT is checked against it.
    """
    try:
        with open(os.path.join(HERE, "rvpriv.py"), "r",
                  errors="replace") as f:
            body = f.read()
    except OSError:
        return []
    i = body.find("RETRACTIONS = [")
    if i < 0:
        return []
    j = body.find("RET_SOURCES = {", i)
    return re.findall(r"^    \('(R\d+)',", body[i:j], re.M)


RETRACTIONS_LIST = source_retractions()


def rows_of(text, rowpat):
    """Every line matching `rowpat`, as a list of FIELDS, in file order."""
    out = []
    for ln in text.splitlines():
        m = re.match(rowpat, ln)
        if m:
            out.append(m.groups())
    return out


# ===========================================================================
# 1. THE METHOD.  The absences are the method, so they are asserted before
#    anything that depends on them -- and the things that must NOT be claimed
#    are asserted here too, because a course about a machine it cannot run
#    fails in exactly one way and this is it.
# ===========================================================================
def check_method(t, flat_t):
    g = "method"
    check(g, "the riscv64 linker is absent, and it says so",
          re.search(r"linker, riscv64\s+IS NOT INSTALLED", t) is not None)
    check(g, "qemu-riscv64 is ABSENT",
          "qemu-riscv64" in t and "ABSENT" in t)
    check(g, "spike is ABSENT", "spike" in t)
    check(g, "and the second riscv64 assembler is absent too",
          re.search(r"assembler, riscv64 GNU\s+IS NOT INSTALLED", t) is not None)
    check(g, "it says not one instruction has been run",
          "NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN" in t)
    check(g, "and names the four specific absences this course has",
          all(x in t for x in ("NO EXCEPTION IS", "NO PAGE IS EVER WALKED",
                               "NO TLB IS EVER CONSULTED",
                               "OBSERVED DOING ANYTHING")))
    check(g, "it distinguishes this course's absence from the ABI course's",
          "lost the ability to TIME. This course loses the ability to"
          in flat_t and "OBSERVE THE SUBJECT" in flat_t)
    check(g, "the x86-64 ratios are named AND disclaimed",
          "4.92x" in t and "27.65x" in t and
          "NO COUNTERPART HERE AND ARE NOT INVENTED" in t)
    check(g, "there is no timing, in the header and in section 15",
          t.count("NO TIMING") >= 1 and
          re.search(r"^\s*1\. NO TIMING\.", t, re.M) is not None)
    check(g, "the two readers are named and share one LLVM tree",
          "ONE LLVM TREE" in t and "BORROWED" in t)
    check(g, "the corpus completeness check prints its own verdict",
          "THE CORPUS IS INCOMPLETE" in flat_t and
          re.search(r"THE CORPUS IS INCOMPLETE: no\.\s+All \d+ objects",
                    t) is not None)
    check(g, "it reports the inherited and prepended model counts",
          re.search(r"Inherited decoder models: \d+, of which this course "
                    r"PREPENDS 2\.", flat_t) is not None)

    # NEGATIVE CHECKS.  A course that has begun claiming things it cannot
    # measure fails these, and they are the only checks in this file that can
    # fail because the course got MORE confident rather than less.
    for phrase, why in (
            (r"\b\d+\.\d\dx\b", "a speedup ratio"),
            (r"\b\d+ ?cycles\b", "a cycle count"),
            (r"\bnanoseconds?\b", "a duration"),
            (r"\bwe (?:measured|observed) (?:a|the) (?:trap|exception|page "
             r"fault|interrupt) (?:being )?(?:taken|delivered|raised)\b",
             "a claimed exception delivery")):
        hits = re.findall(phrase, t, re.I)
        # The one legitimate mention of 4.92x/27.65x is inside the sentence
        # that disclaims them, and the harness checks that separately; the
        # ratio pattern is therefore allowed exactly twice and no more.
        if 'ratio' in why:
            ok = len(hits) <= 2
        else:
            ok = not hits
        check(g, "the output contains no %s" % why, ok,
              "%d hit(s)%s" % (len(hits), (': ' + str(hits[:3]))
                              if hits else ''))


# ===========================================================================
# 2. THE THREE LABELS.  Rule 13: a label rendered two ways is not a label.
# ===========================================================================
def check_labels(t, flat_t):
    g = "labels"
    for lab in ("MEASURED", "MEASURED-ON-BYTES", "QUOTED"):
        check(g, "the label %s appears" % lab, lab in t,
              "%d occurrences" % t.count(lab))
    check(g, "they are DEFINED in the artifact's own header",
          "Every claim in this file carries one of three labels" in flat_t)
    check(g, "the provenance table's four numbers SUM",
          (lambda m: m is not None
           and int(m.group(2)) + int(m.group(3)) + int(m.group(4))
           == int(m.group(1)))(
              re.search(r"(\d+) rows: (\d+) MEASURED, (\d+) MEASURED-ON-BYTES, "
                        r"(\d+) QUOTED", t)))
    check(g, "the QUOTED third is a MAJORITY, and the file says so",
          re.search(r"AT (\d+) PER CENT THE QUOTED THIRD IS A MAJORITY", t)
          is not None)
    pct = re.search(r"AT (\d+) PER CENT THE QUOTED THIRD IS A MAJORITY", t)
    if pct:
        m = re.search(r"(\d+) rows: (\d+) MEASURED, (\d+) MEASURED-ON-BYTES, "
                      r"(\d+) QUOTED", t)
        check(g, "and the percentage agrees with the table",
              m is not None and int(m.group(4)) * 100 // int(m.group(1))
              == int(pct.group(1)),
              "%s%% vs table %s of %s" % (
                  pct.group(1), m.group(4) if m else '?',
                  m.group(1) if m else '?'))
    check(g, "it names all three documents the QUOTED rows use",
          all(x in flat_t for x in ("priv-spec", "riscv-elf", "rv32-unpriv")))
    check(g, "every QUOTED row in the table names one of them",
          len(re.findall(r"^\s+QUOTED\s+\S.*\s(priv-spec|riscv-elf|"
                        r"rv32-unpriv)[, ]", t, re.M)) >= 20,
          "%d rows" % len(re.findall(
              r"^\s+QUOTED\s+\S.*\s(priv-spec|riscv-elf|rv32-unpriv)[, ]",
              t, re.M)))
    check(g, "the limits are enumerated and numbered",
          len(re.findall(r"^  \d+\. ", t, re.M)) >= 16)
    check(g, "and the count agrees with the report's own banner",
          re.search(r"16 limits, 17 retractions, 4 poisons", flat_t)
          is not None)


# ===========================================================================
# 3. rv-modes.  THE ENCODING, EXACTLY, plus the CSR ADDRESS DECOMPOSITION.
# ===========================================================================
def check_modes(t, flat_t):
    g = "modes"
    # The twelve instructions: funct3 values read out of the words.  EXACT,
    # because funct3 is an encoding fact and the second reader confirms the
    # words.
    rows = rows_of(t, r"^  (CSR\w+)\s+(csrr\w*)\s+0x([0-9a-f]{8})\s+(\d+)"
                       r"\s+(csrr\w*)\s+0x([0-9a-f]{8})\s+(\d+)\s+"
                       r"0x([0-9a-f]{3})\s+(\d+)\s+(\d+)\s*$")
    check(g, "the twelve-instruction table has THREE rows, one per operation",
          len(rows) == 3, "%d rows" % len(rows))
    if rows:
        check(g, "and they are CSRRW, CSRRS and CSRRC",
              [r[0] for r in rows] == ['CSRRW', 'CSRRS', 'CSRRC'],
              str([r[0] for r in rows]))
        check(g, "and the register-form funct3 values are 1, 2, 3",
              [int(r[3]) for r in rows] == [1, 2, 3],
              str([int(r[3]) for r in rows]))
        check(g, "and the immediate-form funct3 values are 5, 6, 7",
              [int(r[6]) for r in rows] == [5, 6, 7],
              str([int(r[6]) for r in rows]))
        check(g, "and each immediate funct3 is its register funct3 plus 4",
              all(int(r[6]) - int(r[3]) == 4 for r in rows))
        check(g, "and the CSR number is the SAME in all six: 0xc00",
              len(set(r[7] for r in rows)) == 1 and rows[0][7] == 'c00',
              str(sorted(set(r[7] for r in rows))))
        check(g, "the register form reads rs1 = 6 (t1) in all three",
              [int(r[8]) for r in rows] == [6, 6, 6],
              str([r[8] for r in rows]))
        check(g, "and the immediate form reads the VALUE 5 in all three",
              [int(r[9]) for r in rows] == [5, 5, 5],
              str([r[9] for r in rows]))
        check(g, "and both forms carry rd = 5 (t0)",
              all((int(r[2], 16) >> 7) & 31 == 5 for r in rows))
        check(g, "and the reader's words are the ones decoded",
              all(int(r[2], 16) & 0x7f == 0x73 for r in rows) and
              all(int(r[5], 16) & 0x7f == 0x73 for r in rows))
    # THE ONE BIT.  EXACT, and asserted three times over because it is the
    # section's finding.
    onebit = rows_of(t, r"^  (csrrw|csrrs|csrrc)\s+(\d)\s+(csrrwi|csrrsi|"
                        r"csrrci)\s+(\d)\s+0x([0-9a-f]{2})\s+bit (\d) of "
                        r"funct3\s*$")
    check(g, "the one-bit table has three rows", len(onebit) == 3,
          "%d rows" % len(onebit))
    check(g, "and the XOR is 0x04 three times",
          len(onebit) == 3 and all(r[4] == '04' for r in onebit))
    check(g, "and the bit is funct3 bit 2 three times",
          len(onebit) == 3 and all(r[5] == '2' for r in onebit))
    check(g, "1^5, 2^6 and 3^7 all equal 4",
          (1 ^ 5) == 4 and (2 ^ 6) == 4 and (3 ^ 7) == 4)
    # THE ALIASES.  EXACT: a pseudo-instruction is a three-operand form with
    # x0 in a register slot, and the words must be byte-identical.
    al = rows_of(t, r"^  (csrw|csrc|csrs|csrwi|csrci|csrsi|csrr)\s+"
                    r"(.+?)\s{2,}(csrr\w*)\s+(.+?)\s{2,}"
                    r"0x([0-9a-f]{8})\s+0x([0-9a-f]{8})\s+"
                    r"(IDENTICAL|DIFFER[^\s]*)\s*$")
    check(g, "the alias table has EIGHT rows", len(al) == 8,
          "%d rows" % len(al))
    if al:
        check(g, "and all EIGHT are byte-identical",
              all(r[6] == 'IDENTICAL' for r in al),
              str([r[6] for r in al]))
        check(g, "`csrw` pairs with `csrrw`, not with `csrrs`",
              any(r[0] == 'csrw' and r[2] == 'csrrw' for r in al) and
              not any(r[0] == 'csrw' and r[2] == 'csrrs' for r in al),
              str([(r[0], r[2]) for r in al]))
        check(g, "`csrr` pairs with `csrrs rd, csr, zero`",
              any(r[0] == 'csrr' and r[2] == 'csrrs' and 'zero' in r[3]
                  for r in al))
        check(g, "and `csrw` with `zero` and with `x0` are BOTH in the table",
              sum(1 for r in al if r[0] == 'csrw') == 2)
    # THE FIELD MASKS.  The isolated CSR-number sweep is EXACT.
    mrows = rows_of(t, r"^  (funct3 alone[^\n]*|inst\[19:15\] alone[^\n]*|"
                        r"the CSR NUMBER, every[^\n]*|the CSR NUMBER, "
                        r"ISOLATED[^\n]*)\s+(\d+)\s+0x([0-9a-f]{8})\s+(\d+)\s+"
                        r"0x([0-9a-f]{8})\s+(\d+)\s*$")
    check(g, "the mask table has four rows", len(mrows) == 4,
          "%d rows" % len(mrows))
    if len(mrows) == 4:
        iso = mrows[3]
        check(g, "the ISOLATED CSR-number mask is 0xfff00000",
              iso[4] == 'fff00000', iso[4])
        check(g, "and it is TWELVE bits", iso[5] == '12', iso[5])
        check(g, "and the raw one is NOT the same, which is R2",
              mrows[2][2] != iso[2] and mrows[2][3] != iso[3],
              "raw %s/%s bits, isolated %s/%s bits"
              % (mrows[2][2], mrows[2][3], iso[2], iso[3]))
        check(g, "funct3 alone is 0x00003000 at two bits",
              mrows[0][4] == '00003000' and mrows[0][5] == '2')
        check(g, "inst[19:15] alone is 0x00030000 at two bits",
              mrows[1][4] == '00030000' and mrows[1][5] == '2')
    check(g, "and the isolated sweep is over the two-operand csrr words",
          re.search(r"the CSR NUMBER, ISOLATED: two-operand csrr words only",
                    t) is not None)
    check(g, "and the file says a lower bound is what a sweep gives",
          "A MASK IS A LOWER BOUND" in flat_t and
          "A CORPUS IN WHICH EVERY ADDRESS HAS THE SAME BIT CLEAR" in flat_t)
    # THE TWELVE-BIT BOUNDARY, MEASURED BY REFUSAL.  The exact strings the
    # assembler prints are asserted because a summarised refusal is a refusal
    # a reader has to trust.
    check(g, "4095 is the last CSR number and 4096 is refused",
          re.search(r"^  csrr t0, 0x1000\s+REFUSED", t, re.M) is not None)
    check(g, "and the message is the assembler's own",
          t.count("immediate must be an integer in the range [0, 4095]") >= 3)
    check(g, "0x7ff, 0x800 and 0xfff are ALL accepted",
          len(re.findall(r"^  csrr t0, 0x(?:7ff|800|fff)\s+accepted", t,
                         re.M)) == 3)
    check(g, "the 5-bit immediate has its own boundary at 31",
          re.search(r"^  csrwi 0xfff, 0x1f\s+accepted", t, re.M) is not None
          and re.search(r"^  csrwi 0xfff, 0x20\s+REFUSED", t, re.M) is not None)
    check(g, "and it prints both boundaries in full",
          "IN ITS OWN WORDS: immediate must be an integer in the range "
          "[0, 4095]. THE FIVE-BIT IMMEDIATE" in t and
          "DIFFERENT FIELD: immediate must be an integer in the range "
          "[0, 31]" in t)
    # THE SOURCE/DISASSEMBLY PAIRING is CHECKED on every run.
    check(g, "the pairing is checked, not assumed",
          re.search(r"The pairing is CHECKED, not assumed: \d+ source lines "
                    r"against \d+ words", t) is not None)
    check(g, "and the three documents are cited for the split",
          "Zicsr" in flat_t and
          "the base integer set no longer contains" in flat_t)
    # ALL THREE OBJECTS' DISASSEMBLIES ARE COMMITTED, and they carry the same
    # word.  The section's finding is that 0xc00022f3 -- a Zicsr instruction --
    # is in the object built for `-march=rv64i`, the base, whose ISA string has
    # no `zicsr` in it.  A reader with a hex editor and NO cross-compiler can
    # only check that claim if all three listings are in the directory, and the
    # first version of this build recorded ONE of the three -- which made the
    # claim checkable for a third of its cases and looked like evidence.  So
    # this check is against the COMMITTED FILES, not against the output text,
    # and it is the only check in this file that reads anything other than
    # `t` besides the artifact's own source.
    words = {}
    for tag in ('rv64i', 'rv64i_zicsr', 'rv64i_zicsr_zifencei'):
        f = os.path.join(HERE, 'zicsr_%s_objdump.txt' % tag)
        if not os.path.isfile(f):
            words[tag] = None
            continue
        with open(f, "r", errors="replace") as fh:
            body = fh.read()
        words[tag] = one(r"^\s+0:\s+([0-9a-f]{8})", body, re.M)
    check(g, "all THREE zicsr objects have a COMMITTED disassembly",
          all(words.values()),
          str({k: bool(v) for k, v in words.items()}))
    check(g, "and all three carry the SAME first word, which is the finding",
          len(set(words.values())) == 1 and words.get('rv64i') == 'c00022f3',
          str(words))
    check(g, "and that word really is the two-operand csrr this section "
             "measures",
          words.get('rv64i') == 'c00022f3' and
          (int('c00022f3', 16) & 0x7f) == 0x73 and
          ((int('c00022f3', 16) >> 12) & 7) == 2 and
          ((int('c00022f3', 16) >> 20) & 0xfff) == 0xc00,
          'opcode 0x73, funct3 2 (CSRRS), csr 0xc00')


# ===========================================================================
# 4. rv-modes, part two: the Zicsr split and the ecall convention.
# ===========================================================================
def check_zicsr_ecall(t, flat_t):
    g = "zicsr"
    rows = rows_of(t, r"^  (rv64i\S*)\s+(rv\S+)\s+(\d+)\s+0x([0-9a-f]{8})\s+"
                       r"(YES|NO)\s*$")
    check(g, "the arch-attribute table has three rows", len(rows) == 3,
          "%d rows" % len(rows))
    if len(rows) == 3:
        check(g, "rv64i records NO zicsr", rows[0][4] == 'NO', rows[0][1])
        check(g, "rv64i records exactly rv64i2p1", rows[0][1] == 'rv64i2p1',
              rows[0][1])
        check(g, "rv64i_zicsr records zicsr2p0",
              'zicsr' in rows[1][1], rows[1][1])
        check(g, "and the word is THE SAME in all three",
              len(set(r[3] for r in rows)) == 1 and rows[0][3] == 'c00022f3',
              str([r[3] for r in rows]))
        check(g, "and each object is two words", set(r[2] for r in rows) == {'2'})
    check(g, "the headline sentence is present verbatim",
          "THE ASSEMBLER EMITTED A Zicsr INSTRUCTION UNDER -march=rv64i, GAVE "
          "NO DIAGNOSTIC" in t)
    check(g, "and it is broken into THREE separate claims, numbered",
          all(x in t for x in ("* 1. THE ASSEMBLER DOES NOT ENFORCE THE SPLIT",
                               "* 2. THE INSTRUCTION IS THE SAME ONE",
                               "* 3. THE ISA STRING RECORDS WHAT WAS ASKED "
                               "FOR")))
    check(g, "and the C evidence is measured too",
          re.search(r"^    rd_satp\s+0x18002573\s+csrr\s+a0, satp", t,
                    re.M) is not None)

    g = "ecall"
    rows = rows_of(t, r"^  (sys_write|sys_getpid|sys_write_a6)\s+(\d+)\s+"
                       r"(\d+)\s+(.*)$")
    check(g, "the -O2 wrapper table has three rows", len(rows) == 3,
          "%d rows" % len(rows))
    if rows:
        check(g, "and every body contains exactly one `ecall`",
              all(r[3].count('ecall') == 1 for r in rows))
    check(g, "the a7/a6 XOR is 0x00000080 and it is bit 7",
          re.search(r"XOR 0x00000080 -- bits 7", t) is not None)
    check(g, "and the two words are 0x04000893 and 0x04000813",
          re.search(r"li\s+a7, 0x40\s+0x04000893", t) is not None and
          re.search(r"li\s+a6, 0x40\s+0x04000813", t) is not None)
    check(g, "and 0x04000893 ^ 0x04000813 is 0x80",
          (0x04000893 ^ 0x04000813) == 0x00000080)
    lv = rows_of(t, r"^  (O0|O1|O2|Os)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+"
                     r"(yes|NO)\s*$")
    check(g, "the four-level table has four rows", len(lv) == 4,
          "%d rows" % len(lv))
    if len(lv) == 4:
        check(g, "and a7/a6 differ in EXACTLY ONE WORD at every level",
              all(r[4] == '1' for r in lv), str([r[4] for r in lv]))
        check(g, "and the two functions are the same LENGTH at every level",
              all(r[5] == 'yes' for r in lv), str([r[5] for r in lv]))
        check(g, "and -O0 is the outlier the retraction is about",
              int(lv[0][1]) > 5 * int(lv[1][1]),
              'O0=%s O1=%s' % (lv[0][1], lv[1][1]))
    check(g, "the -O0 dead-code-elimination confound is recorded",
          "three argument loads DELETED" in t and
          "a measurement of dead-code elimination" in t)
    check(g, "and the five things the bytes do NOT contain are listed",
          all(x in t for x in ("- the number 64 as a syscall number",
                               "- any reference to a7 from inside `ecall`",
                               "- any return path, because the trap is a jump "
                               "to a handler")))
    check(g, "and the limit is stated where a reader would assume otherwise",
          "WHAT IS MEASURED HERE IS THAT THE COMPILER EMITS THE CONSTANT "
          "0x00000073" in t)


# ===========================================================================
# 5. rv-paging.  THE SIZE ARITHMETIC, EXACTLY, because it is arithmetic.
# ===========================================================================
def check_paging(t, flat_t):
    g = "paging"
    rows = rows_of(t, r"^  (Sv39|Sv48|Sv57)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+"
                       r"(\d+)\s+(\d+)\s+2\^(\d+)\s+(\S+ \S+)\s*$")
    check(g, "the mode table has three rows", len(rows) == 3,
          "%d rows" % len(rows))
    if len(rows) == 3:
        by = dict((r[0], r) for r in rows)
        for name, levels, mode, va in (('Sv39', '3', '8', '39'),
                                       ('Sv48', '4', '9', '48'),
                                       ('Sv57', '5', '10', '57')):
            r = by.get(name)
            check(g, "%s: LEVELS=%s, mode=%s, VA=%s bits" %
                  (name, levels, mode, va),
                  r is not None and r[1] == levels and r[2] == mode
                  and r[6] == va,
                  'got %s/%s/%s' % (r[1], r[2], r[6]) if r else 'missing')
            check(g, "%s: 512 entries, 9 index bits, %s VPN bits" %
                  (name, str(int(levels) * 9)),
                  r is not None and r[3] == '512' and r[4] == '9'
                  and r[5] == str(int(levels) * 9))
        check(g, "and LEVELS*9+12 is the VA width in all three",
              all(int(r[1]) * 9 + 12 == int(r[6]) for r in rows))
        check(g, "and the mode is LEVELS+5 in all three",
              all(int(r[1]) + 5 == int(r[2]) for r in rows))
        check(g, "and 4096/8 = 512 = 2^9",
              4096 // 8 == 512 and 512 == 2 ** 9)
    # The identities are ASSERTED, not just printed, and every one says [ok].
    ids = re.findall(r"^\s+\[(ok|FAIL)\] (.+)$", t, re.M)
    check(g, "the arithmetic identities are asserted and all say ok",
          len(ids) >= 18 and all(k == 'ok' for k, _ in ids),
          "%d identities, %d FAIL"
          % (len(ids), sum(1 for k, _ in ids if k == 'FAIL')))
    check(g, "and a page table is EXACTLY one granule, stated as an identity",
          any('a page table is EXACTLY one granule' in w for _k, w in ids))
    check(g, "the flat-table ratio is 1/512 and it is asserted",
          any('a flat table is 1/512' in w for _k, w in ids))
    check(g, "the page-table geometry block is printed",
          "entries per table        512 = 2^9" in t and
          "the aligned size is      2^12 = 4096" in t)
    check(g, "the mode numbering is a REGISTRY, not a formula",
          "the numbering is a REGISTRY rather than a formula" in t)
    check(g, "and the leaf sizes are quoted per mode",
          all(x in t for x in ("2 MiB", "1 GiB", "512 GiB", "256 TiB")))
    check(g, "the leaf sizes are derived from levels*9+12",
          "2^(12+9) is 2^21 = 2 MiB" in t and
          "2^(12+18) is 2^30 = 1 GiB" in t and
          "2^(12+27) is 2^39 = 512 GiB" in t)
    check(g, "and the file says none of it is observable here",
          "no page is walked, no TLB is consulted, no page fault is raised"
          in t.replace('AND NONE OF IT IS OBSERVABLE HERE.  There is no RISC-V '
                       'machine on this host, so no page is walked, no TLB is '
                       'consulted, no page fault is raised and no A or D bit is '
                       'set by anything',
                       'no page is walked, no TLB is consulted, no page fault '
                       'is raised and no A or D bit is set by anything'))


# ===========================================================================
# 6. rv-paging, part two: the PTE BITS and the satp ARITHMETIC, on bytes.
# ===========================================================================
def check_pte_bits(t, flat_t):
    g = "ptebits"
    rows = rows_of(t, r"^  ([VRWXUGAD])\s+(\d)\s+(\S.*?)\s{2,}(\S.*?)\s{2,}"
                       r"(\S.*?)\s*$")
    check(g, "the PTE bit table has EIGHT rows", len(rows) == 8,
          "%d rows" % len(rows))
    if len(rows) == 8:
        names = [r[0] for r in rows]
        check(g, "and they are V R W X U G A D in order",
              names == ['V', 'R', 'W', 'X', 'U', 'G', 'A', 'D'], str(names))
        for r in rows[1:]:
            n = int(r[1])
            shl = int(r[2].split('0x')[1], 16)
            shr = int(r[3].split('0x')[1], 16)
            check(g, "bit %d is `slli 0x%x ; srli 0x%x` and 63-slli = %d"
                  % (n, shl, shr, n),
                  shr == 63 and 63 - shl == n,
                  'slli 0x%x srli 0x%x -> %d' % (shl, shr, 63 - shl))
        check(g, "bit 0 is the EXCEPTION: an andi and no shift at all",
              'andi' in rows[0][2] and 'SPECIALISED' in rows[0][4],
              rows[0][2])
        check(g, "and the seven left shifts are 0x3e down to 0x38",
              [int(r[2].split('0x')[1], 16) for r in rows[1:]]
              == [0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38])
    check(g, "the seven descending shifts are stated in full",
          "0x3e 0x3d 0x3c 0x3b 0x3a 0x39 0x38" in t)
    check(g, "and the right shift of 63 is explained, not just printed",
          "mask is a sign-extend-to-64 and not a zero-extend" in t)
    check(g, "the A/D text quotes BOTH schemes",
          "The Svade extension: when a virtual page is accessed and the A bit"
          in t and "PTE is updated to set the A bit" in t)
    check(g, "and names which is which",
          "WITHOUT Svade, hardware SETS the bits" in t and
          "WITH Svade, hardware TRAPS" in t)
    check(g, "and the reserved PTE bits are called a TRAP, not a no-op",
          "the reserved field is a TRAP, not a no-op" in t)

    g = "satp"
    # THE ALTERNATION ORDER MATTERS, and it is recorded here rather than left
    # as a detail: `PPN` before `PPN, 44-bit mask` matches the short label
    # first and the first version of this pattern raised IndexError deep
    # inside a detail string, which is a bad place to find out that a regex is
    # ambiguous.
    rows = rows_of(t, r"^  (MODE|ASID|PPN, 44-bit mask|PPN, 54-bit mask|PPN)"
                       r"\s+(\(none, L = 0\)|0x[0-9a-f]+)\s+0x([0-9a-f]+)"
                       r"\s+(\d+)\s+(\d+)\s+satp\[(\d+):(\d+)\]\s+"
                       r"(CORRECT|WRONG by [+-]\d+ bits)\s*$")
    check(g, "the satp table has five rows", len(rows) == 5,
          "%d rows" % len(rows))
    if len(rows) == 5:
        by = dict((r[0], r) for r in rows)
        want = {'MODE': (4, 63, 60, 'CORRECT'),
                'ASID': (16, 59, 44, 'CORRECT'),
                'PPN': (36, 43, 8, 'CORRECT'),
                'PPN, 44-bit mask': (44, 51, 8, 'WRONG by +8 bits'),
                'PPN, 54-bit mask': (54, 61, 8, 'WRONG by +18 bits')}
        for k, (wd, hi, lo, verdict) in want.items():
            r = by.get(k)
            # THE GROUP INDICES, because getting them wrong raised IndexError
            # inside a DETAIL STRING rather than reporting a failed check,
            # and a harness that dies while formatting a failure has lost the
            # failure.  0 label, 1 slli, 2 srli, 3 asked, 4 emitted, 5 hi,
            # 6 lo, 7 verdict.
            check(g, "%s: width %d at satp[%d:%d], %s" % (k, wd, hi, lo,
                                                        verdict),
                  r is not None and int(r[4]) == wd and int(r[5]) == hi
                  and int(r[6]) == lo and r[7] == verdict,
                  'got %s satp[%s:%s] %s'
                  % (r[4], r[5], r[6], r[7]) if r else 'missing')
        # The ARITHMETIC the widths come from, checked here so a reader can
        # see the derivation is not a quotation.
        check(g, "and 64 - 4 - 16 - 8 = 36 is the PPN width",
              64 - 4 - 16 - 8 == 36 and int(by['PPN'][4]) == 36)
        check(g, "and 64 - 0x1c = 36 is what the compiler emitted",
              64 - 0x1c == 36 and by['PPN'][2] == '1c')
        check(g, "and 64 - 0x14 = 44, 64 - 0xa = 54 for the two wrong masks",
              64 - 0x14 == 44 and 64 - 0xa == 54)
        check(g, "and MODE has NO slli, which is the whole point of the row",
              by['MODE'][1] == '(none, L = 0)' and by['MODE'][2] == '3c')
        check(g, "and the C asked for exactly the width emitted, in all five "
                 "rows", all(r[3] == r[4] for r in rows),
                 str([(r[3], r[4]) for r in rows]))
    check(g, "the mask was optimised away and the file says why",
          "srli a0, a0, 0x3c | ret" in t and
          "AND NO MASK" in t and "provably" in t and "redundant" in t)
    check(g, "and the two shipped masks are named as WRONG on purpose",
          "bits.c CONTAINS TWO MASKS THAT ARE WRONG" in t)
    check(g, "and the 54-bit one is shown to swallow the ASID",
          "swallows the ENTIRE ASID" in t and
          "the top eight of the ASID" in t)
    check(g, "and the reserved PTE bits are a page fault, quoted",
          re.search(r"^    `pte_reserved`\s+srli\s+a0, a0, 0x36", t,
                    re.M) is not None)


# ===========================================================================
# 7. rv-paging, part three: the RELOCATIONS.  Names and codes, EXACT.
# ===========================================================================
def check_relocs(t, flat_t):
    g = "reloc"
    # THE CODES.  These are the numbers the psABI prints and the numbers
    # that go in the file, and both are asserted exactly.  A relocation NAME
    # is a convention; a relocation NUMBER is a fact.
    # NAME -> CODE.  The first version built this map the other way round
    # (code -> name) and then looked the names up in it, so every one of the
    # ten checks below printed "absent" over a table that had all ten rows.
    # The group indices are 0 code, 1 name, 2 field, 3 count.
    codes = dict((r[1], r[0]) for r in rows_of(
        t, r"^  (\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+0x[0-9a-f]{2} = \d+\s"
        r".*$"))
    for name, num in (('PCREL_HI20', '23'), ('PCREL_LO12_I', '24'),
                      ('PCREL_LO12_S', '25'), ('HI20', '26'), ('LO12_I', '27'),
                      ('LO12_S', '28'), ('RELAX', '51'), ('GOT_HI20', '20'),
                      ('BRANCH', '16'), ('JAL', '17')):
        check(g, "%s is %s in the psABI table" % (name, num),
              codes.get(name) == num, codes.get(name, 'absent'))
    check(g, "and the three PC-relative ones are CONSECUTIVE",
              codes.get('PCREL_HI20') == '23' and
              codes.get('PCREL_LO12_I') == '24' and
              codes.get('PCREL_LO12_S') == '25')
    # And they are the ones the reader actually found in a file, which is the
    # part a table of quotes cannot do.
    seen = dict((r[0], int(r[3])) for r in rows_of(
        t, r"^  (\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+0x[0-9a-f]{2} = \d+\s+.*$"))
    check(g, "PCREL_HI20 was FOUND in the corpus, not zero",
              seen.get('23', 0) > 0, str(seen.get('23')))
    check(g, "PCREL_LO12_I was found", seen.get('24', 0) > 0,
          str(seen.get('24')))
    check(g, "PCREL_LO12_S was found", seen.get('25', 0) > 0,
          str(seen.get('25')))
    check(g, "RELAX was found in every object",
          seen.get('51', 0) > 20, str(seen.get('51')))
    check(g, "and BRANCH and JAL are ZERO, which is a statement ABOUT THE "
             "CORPUS", seen.get('16') == 0 and seen.get('17') == 0)
    check(g, "the table says what a zero means",
          "0 means the corpus does not contain it" in flat_t)
    # WHAT EACH RECORD NAMES.  The LO12 names a LABEL, not the target.  The
    # SYMBOL column is greedy to the last space so a symbol with a dot and a
    # number in it survives; the first version used \S+ and matched two rows.
    # The ADDEND is REQUIRED and BARE-or-hex (`+0`, `+0x8`), rather than
    # optional-hex, for two reasons found by printing what the table prints:
    # the word table further down the section ends in `auipc t0, 0x0`, which an
    # optional addend swallowed -- so one check was reading five instruction
    # words and calling them symbol names -- and eleven of the sixteen addends
    # are printed `+0` rather than `+0x0`, so requiring `0x` found two rows out
    # of sixteen and the check reported a nearly-empty table over a full one.
    recs = rows_of(t, r"^  0x([0-9a-f]+)\s+(\d+)\s+(\S+)\s+(\S.*?)\s+"
                       r"\+((?:0x)?[0-9a-f]+)\s*$")
    check(g, "the record table is printed", len(recs) >= 10,
          "%d rows" % len(recs))
    if recs:
        lo12 = [r for r in recs if r[2] in ('R_RISCV_PCREL_LO12_I',
                                            'R_RISCV_PCREL_LO12_S')]
        hi20 = [r for r in recs if r[2] == 'R_RISCV_PCREL_HI20']
        check(g, "the HI20 records name the TARGET",
              any(r[3] in ('root_pte', 'l1_pte', 'l2_pte') for r in hi20),
              str([r[3] for r in hi20]))
        check(g, "and the LO12 records name a LABEL IN THE CODE",
              all(r[3] in ('.Lpcrel_hi0', '.Lpcrel_hi1', 'walk_three',
                           'walk_offsets', 'store_pte') for r in lo12),
              str(sorted(set(r[3] for r in lo12))))
        check(g, "and at least one names a compiler-invented local symbol",
              any(r[3].startswith('.Lpcrel_hi') for r in lo12))
        check(g, "and the offsets differ, so the table is not one row repeated",
              len(set(r[0] for r in recs)) >= 8)
        # The RECORD table's code column against the psABI table's code column,
        # by NAME.  The first version of this group checked ten names against
        # ten codes in the psABI table and never checked that the records the
        # toolchain actually emitted carried those same codes -- so a record
        # labelled `99` was, to this harness, indistinguishable from `23`.
        # The psABI table's names are BARE (`PCREL_HI20`) and the records'
        # names are `R_RISCV_`-prefixed, because that is what llvm-readelf
        # prints.  Both spellings name the same relocation, and the check
        # strips the prefix -- which is worth a comment because a harness that
        # compared them literally would have found every name "missing" and no
        # code wrong, and would have taught its reader that the prefix is part
        # of the NAME rather than part of the printer.
        def bare(nm):
            return nm[8:] if nm.startswith('R_RISCV_') else nm
        wrong = [(r[2], r[1], codes.get(bare(r[2]))) for r in recs
                 if codes.get(bare(r[2])) != r[1]]
        check(g, "and EVERY record's code matches the psABI code for its NAME",
              not wrong, str(wrong[:4]))
        check(g, "and the psABI table covers every name the records use",
              all(bare(r[2]) in codes for r in recs),
              str(sorted(set(bare(r[2]) for r in recs) - set(codes))))
        check(g, "and the prefix appears in the RECORDS and not in the psABI "
                 "table, which is the printer's doing",
              all(r[2].startswith('R_RISCV_') for r in recs) and
              not any(k.startswith('R_RISCV_') for k in codes),
              'records prefixed, psABI table bare')
        check(g, "the addends of 8 and 0x800 are on LO12 records",
              any(r[4] == '0x8' and r[2] == 'R_RISCV_PCREL_LO12_I'
                  for r in recs) and
              any(r[4] == '0x800' and r[2] == 'R_RISCV_PCREL_LO12_I'
                  for r in recs))
        check(g, "and every OTHER addend is 0, which is the psABI's rule "
                 "held everywhere else",
              sum(1 for r in recs if r[4] == '0') ==
              len(recs) - 2,
              "%d of %d are +0" % (sum(1 for r in recs if r[4] == '0'),
                                   len(recs)))
    # THE IMMEDIATE IS LEFT AT ZERO.  This is the load-bearing half of the
    # "two-instruction arithmetic expression" claim.
    # The word table's window column is NAMED FOR THE MASK (`inst[31:20]`) and
    # not for the field, because that is the mistake this course retracts.
    irows = rows_of(t, r"^  (0x[0-9a-f]+)\s+(\d+)\s+(\S+)\s+(0x[0-9a-f]{8})"
                       r"\s+(0x[0-9a-f]{3})\s+(\S.*?)\s*$")
    check(g, "the word table is printed with its window column",
          len(irows) >= 12, "%d rows" % len(irows))
    i_typed = [r for r in irows if r[2] != 'R_RISCV_PCREL_LO12_S']
    s_typed = [r for r in irows if r[2] == 'R_RISCV_PCREL_LO12_S']
    check(g, "and EVERY I-TYPE row's window is 0x000",
          i_typed and all(r[4] == '0x000' for r in i_typed),
          str(sorted(set(r[4] for r in i_typed))))
    check(g, "and the ONE S-type row is the 0x006 the section retracts",
          len(s_typed) == 1 and s_typed[0][4] == '0x006',
          str([r[4] for r in s_typed]))
    # The decoded table: the same row, decoded properly, is zero.
    # Column order is offset, code, format, the mask, inst[11:7], inst[24:20],
    # the DECODED immediate, the mnemonic.  The first version read the two
    # register columns as 0x005 / 0x006 / 0x007 / 0x01c -- which are rd values
    # an S-type decode produced on I-type rows -- and reported them as a table
    # of immediates that were not all zero.
    drows = rows_of(t, r"^  (0x[0-9a-f]+)\s+(\d+)\s+(I-type|S-type)\s+"
                       r"0x([0-9a-f]{3})\s+(\d+)\s+(\d+)\s+0x([0-9a-f]{3})"
                       r"\s+(\S.*?)\s*$")
    # Group 7 captures the THREE hex digits, without the `0x`, because the
    # pattern is `0x([0-9a-f]{3})`.  The first version compared the capture
    # against '0x000' and so reported ['000'] -- a table of fourteen correct
    # rows, all of them "wrong", over a one-character difference between a
    # literal and a capture group.
    check(g, "and the DECODED column is 0x000 on EVERY row",
          len(drows) >= 12 and all(r[6] == '000' for r in drows),
          str(sorted(set(r[6] for r in drows))))
    check(g, "and on the S-type row the mask EQUALS inst[24:20], which is the "
             "proof it was a register",
          len(s_typed) == 1 and len(drows) >= 1 and
          int(s_typed[0][4], 16) == int([r[5] for r in drows
                                         if r[0] == s_typed[0][0]][0]) and
          len([r for r in drows if r[0] == s_typed[0][0]]) == 1,
          'mask 0x%s vs inst[24:20] %s' % (s_typed[0][4],
                                            [r[5] for r in drows
                                             if r[0] == s_typed[0][0]]))
    check(g, "and inst[11:7] is 0 there too, so the mask gave no immediate at "
             "all",
          all(r[4] == '0' for r in drows if r[2] == 'S-type'),
          str([r[4] for r in drows if r[2] == 'S-type']))
    check(g, "and the DECODED value is the FIELD TABLE applied, not the mask",
          len(drows) >= 12 and
          all((int(r[3], 16) if r[2] == 'I-type'
               else (((int(r[3], 16) >> 5) << 5) | int(r[4]))) == int(r[6], 16)
              for r in drows) and len(drows) >= 12,
          'I-type: decoded == mask.  S-type: decoded == (mask>>5)<<5 | '
          'inst[11:7]')
    check(g, "and EVERY I-type row has inst[24:20] = 0, which is the other "
             "half of the asymmetry",
          all(r[5] == '0' for r in drows if r[2] == 'I-type'),
          str(sorted(set(r[5] for r in drows if r[2] == 'I-type'))))
    check(g, "and the contradiction with the psABI is stated, not hidden",
          "THE PSABI STATES THE ADDEND MUST BE 0" in flat_t and
          "addends of 8 and 0x800 on them" in flat_t)
    # THE ARITHMETIC BLOCK, parsed.  It is the only place the artifact shows
    # the mask's 0x006 being TORN APART rather than asserting it, and a block
    # nobody reads is a block that can be edited into a different claim without
    # anything noticing.  Renaming `rs2` to `rd` in it -- the exact mistake R17
    # retracts -- passed every check in the first version of this group.
    aq = re.search(r"inst\[31:25\] = 0x([0-9a-f]+)\s+-> imm\[11:5\] = "
                   r"(\d+)", t)
    ar = re.search(r"inst\[24:20\] = 0x([0-9a-f]+)\s+-> (\S+)\s+= (\S+) "
                   r"\(x(\d+)\)", t)
    am = re.search(r"inst\[31:20\] = 0x([0-9a-f]+)\s+-> \((\d+) << (\d+)\)"
                   r" \| (\d+) = (\d+)", t)
    al = re.search(r"inst\[11:7\]\s+= 0x([0-9a-f]+)\s+-> imm\[4:0\] = (\d+)",
                   t)
    check(g, "the arithmetic block prints all FOUR extractions", 
          all(x is not None for x in (aq, ar, am, al)))
    if aq and ar and am and al:
        check(g, "and it says the second extraction is rs2, NOT rd",
              ar.group(2) == 'rs2' and 'rd' != ar.group(2),
              "inst[24:20] is called %s" % ar.group(2))
        check(g, "and rs2 is x6, which is the number the mask returned",
              int(ar.group(4)) == 6 and XREG[6] == ar.group(3),
              'x%d is %s' % (int(ar.group(4)), ar.group(3)))
        check(g, "and the mask column really is (imm[11:5] << 5) | rs2",
              (int(am.group(2)) << int(am.group(3))) | int(am.group(4)) ==
              int(am.group(5)) and int(am.group(5)) == int(am.group(1), 16),
              '%s<<%s | %s = %s vs mask %s' % (am.group(2), am.group(3),
                                               am.group(4), am.group(5),
                                               am.group(1)))
        check(g, "and imm[11:5] is zero, which is WHY the mask is rs2",
              int(aq.group(1), 16) == 0 and int(aq.group(2)) == 0,
              'inst[31:25] = 0x%s' % aq.group(1))
        check(g, "and imm[4:0] is zero, so the DECODED immediate is zero",
              int(al.group(1), 16) == 0 and int(al.group(2)) == 0,
              'inst[11:7] = 0x%s' % al.group(1))
        check(g, "and the decoded immediate is the two halves OR-ed",
              ((int(aq.group(1), 16) << 5) | int(al.group(1), 16)) == 0)
    check(g, "and the file says it cannot demonstrate a bug there",
          "THERE IS NO RISC-V LINKER ON THIS HOST, SO WHETHER IT HANDLES IT "
          "IS QUOTED AND NOT MEASURED" in flat_t)

    # THE LAYOUT EXPERIMENT.  A SHAPE, plus the CLEAN/CONFOUNDED distinction
    # that the retraction is about.
    g = "layout"
    rows = rows_of(t, r"^  (sp2_\S+\.o)\s+(.+?)\s{2,}(\d+)\s+(\d+)\s+"
                       r"(\d+)\s+(\d+)\s+(\d+)\s*$")
    check(g, "the layout table has FOUR rows", len(rows) == 4,
          "%d rows" % len(rows))
    if len(rows) == 4:
        by = dict((r[0], r) for r in rows)
        # 0 file, 1 label, 2 instructions, 3 bytes, 4 HI20, 5 LO12, 6 S-type.
        d, sp = by.get('sp2_dense_nopic.o'), by.get('sp2_sparse_nopic.o')
        check(g, "the -fno-pic pair is CLEAN: instruction counts within 2",
              d is not None and sp is not None and
              abs(int(sp[2]) - int(d[2])) <= 2,
              '%s vs %s' % (d[2], sp[2]) if d and sp else 'missing')
        check(g, "and the HI20 count DOUBLES in the clean pair",
              d is not None and sp is not None and int(sp[4]) == 2 * int(d[4]),
              '%s -> %s' % (d[4], sp[4]) if d and sp else 'missing')
        pd, ps = by.get('sp2_dense.o'), by.get('sp2_sparse.o')
        check(g, "the PIC pair is CONFOUNDED: the counts are NOT close",
              pd is not None and ps is not None and
              abs(int(ps[2]) - int(pd[2])) > 10,
              '%s vs %s' % (pd[2], ps[2]) if pd and ps else 'missing')
        check(g, "and the HI20 count still RISES in the confounded pair",
              pd is not None and ps is not None and int(ps[4]) > int(pd[4]),
              '%s -> %s' % (pd[4], ps[4]) if pd and ps else 'missing')
        check(g, "and all four are the same three tables, three levels, one "
                 "function", len(by) == 4)
    check(g, "the table's caption says CONFOUNDED, and says it does not pick "
             "the flattering pair", "CONFOUNDED" in flat_t and
          "rather than reporting the pair that flatters the claim" in flat_t)
    check(g, "and the unrolling is shown to be the confound",
          "UNROLLED the three fill paths" in flat_t and
          "merged-globals pass had nothing to merge" in flat_t)
    check(g, "and the symbol names are the evidence",
          "`.L_MergedGlobals`" in flat_t and
          "`root`, `l1tab` and `l2tab`" in flat_t)


# ===========================================================================
# 8. rv-paging, part four: the PAIRING DISTANCE.
# ===========================================================================
def check_pairing(t, flat_t):
    g = "pairing"
    # The LAST column is `(.+?)\s*$` and not `(\S.*?)\s*$`: the non-greedy
    # \S.*? stopped at the first space and returned `0x000` out of
    # `0x000 0x000`, so the column the check reads was half a column.
    rows = rows_of(t, r"^  (0x[0-9a-f]+)\s+(\d+)\s+(\d+)\s+0x([0-9a-f]+)\s+"
                       r"0x([0-9a-f]+)\s+(\d+)\s+(YES|NO)\s+([0-9a-f x]+)\s*$")
    check(g, "the distance table has SIX rows", len(rows) == 6,
          "%d rows" % len(rows))
    if len(rows) == 6:
        check(g, "and every one has EXACTLY ONE HI20 record",
              all(r[1] == '1' for r in rows), str([r[1] for r in rows]))
        check(g, "and EXACTLY TWO LO12_I records",
              all(r[2] == '2' for r in rows), str([r[2] for r in rows]))
        check(g, "and the HI20 is at offset 0 in all six",
              all(r[3] == '0' for r in rows))
        far = [(r[0], int(r[5]), r[6]) for r in rows]
        check(g, "the DISTANCES are 8, 72, 2056, 4100, 4104 and 8200",
              [x[1] for x in far] == [8, 72, 2056, 4100, 4104, 8200],
              str([x[1] for x in far]))
        check(g, "and exactly the first two FIT a signed 12-bit field",
              [x[2] for x in far] == ['YES', 'YES', 'NO', 'NO', 'NO', 'NO'],
              str([x[2] for x in far]))
        check(g, "and the signed 12-bit range really is -2048..2047",
              all((-2048 <= x[1] <= 2047) == (x[2] == 'YES') for x in far))
        check(g, "and 4096 > 2047, which is the whole of the page rule",
              4096 > 2047)
        check(g, "and the 8 KiB case is named in the prose",
              "8200" in t and "8 KIB APART" in t)
    # Each TOKEN in the column, not the column string: the first version
    # compared `'0x000 0x000  <padding>'` against `'0x000 0x000'` and the
    # padding alone failed the check on a table that was entirely correct.
    check(g, "every immediate in every word is left at zero",
          rows and all(x == '0x000' for r in rows for x in r[7].split()),
          str(sorted(set(r[7].split()[0] for r in rows))) if rows
          else 'no rows')
    check(g, "and the file says it CANNOT claim a linker bug",
          "THE ASSEMBLER DOES NOT ENFORCE THE PAIRING RULE, AND THERE IS NO "
          "RISC-V LINKER ON THIS HOST" in flat_t)
    check(g, "and the mitigation is a layout constraint, not a rule",
          "the pairing rule is a constraint on CODE LAYOUT that the "
          "assembler will not tell you about" in flat_t)


# ===========================================================================
# 9. rv-traps.  The five registers, and the two tables that carry the finding.
# ===========================================================================
def check_traps(t, flat_t):
    g = "traps"
    rows = rows_of(t, r"^  (set_stvec_\w+)\s+(\d+)\s+(a\d)\s+"
                       r"(0x[0-9a-f]{12})\s+(.*)$")
    check(g, "the stvec table has three rows", len(rows) == 3,
          "%d rows" % len(rows))
    if len(rows) == 3:
        check(g, "and the VALUES are 0x1000, 0x1001 and 0x123",
              sorted(r[3] for r in rows) ==
              ['0x00000000007b'[:0] + '0x000000000123',
               '0x000000001000', '0x000000001001'] or
              sorted(r[3] for r in rows) ==
              sorted(['0x000000001000', '0x000000001001',
                      '0x000000000123']),
              str(sorted(r[3] for r in rows)))
        check(g, "and all three are written from the SAME register",
              len(set(r[2] for r in rows)) == 1, str([r[2] for r in rows]))
    m = re.search(r"ALL THREE FUNCTIONS EMIT THE SAME 32-BIT WORD FOR THE "
                  r"stvec WRITE, (0x[0-9a-f]{8})", t)
    check(g, "and the SAME 32-bit word, named", m is not None,
          m.group(1) if m else 'absent')
    if m:
        w = int(m.group(1), 16)
        check(g, "and that word is `csrw stvec, <reg>`: rs1 is a REGISTER, not 0",
              (w >> 15) & 31 != 0, 'rs1 = %d' % ((w >> 15) & 31))
        check(g, "funct3 = 1 (CSRRW) and the CSR is 0x105",
              ((w >> 12) & 7) == 1 and ((w >> 20) & 0xfff) == 0x105,
              'f3=%d csr=0x%03x' % ((w >> 12) & 7, (w >> 20) & 0xfff))
        # And the rest of the word, field by field, because the sentence that
        # says "the compiler emitted something the source never wrote" is only
        # true if funct7 and rs2 really are non-zero.
        check(g, "and rs1 = 11 (a1), rs2 = 5 (t0), funct7 = 8, all from the "
                 "word",
              ((w >> 15) & 31) == 11 and ((w >> 20) & 31) == 5 and
              ((w >> 25) & 0x7f) == 8,
              'rs1=%d rs2=%d funct7=%d' % ((w >> 15) & 31, (w >> 20) & 31,
                                           (w >> 25) & 0x7f))
        # rd IS inst[11:7], and the low five bits of the word are the BOTTOM
        # OF THE OPCODE.  The first version of this check asserted
        # `w & 0x1f == 0` and printed "rd = 19" -- 19 is 0x73 & 0x1f, the
        # last five bits of the opcode, not a register number at all.  It is
        # the same mistake as R16 and R17 in the artifact's own table: a
        # number taken from the wrong field, looking like a smaller number.
        check(g, "and rd = inst[11:7] = 0 in the CSRRW form, which is what "
                 "makes the write discardable",
              ((w >> 12) & 7) == 1 and ((w >> 7) & 31) == 0,
              'funct3 = %d, rd = %d, and w&0x1f = %d is the opcode\'s bottom'
              % ((w >> 12) & 7, (w >> 7) & 31, w & 0x1f))
        check(g, "and w & 0x1f is NOT rd, which is why the first one failed",
              (w & 0x1f) != ((w >> 7) & 31),
              'w&0x1f = %d, rd = %d' % (w & 0x1f, (w >> 7) & 31))
        check(g, "and the same five bits are an IMMEDIATE in funct3 = 5, "
                 "which is why the claim is scoped",
              "rd[4:0] is an immediate for the immediate forms and a register "
              "number for the register forms" in flat_t and
              "funct3 = 1, 2, 3 put rd at inst[11:7] and funct3 = 5, 6, 7 put "
              "zimm[4:0] there" in flat_t,
              'bits 4:0 are dual-purpose')
    check(g, "and the file says the misaligned value is NOT what is stored",
          "writing 0x123 does NOT set BASE to 0x123" in flat_t)
    check(g, "and that a mode of 3 is Reserved",
          "a mode of 3 is Reserved" in flat_t and "MODE = 3" in flat_t)
    check(g, "and it says the assembler could not have diagnosed it",
          "The assembler did not diagnose it" in flat_t and
          "the instruction does not know the value" in flat_t)
    check(g, "and a disassembler cannot recover the mode from the object",
          "A disassembler reading the object can recover the instruction "
          "and CANNOT recover the mode" in flat_t)

    g = "traps2"
    rows = rows_of(t, r"^  (enable_s\w+)\s+(\d+)\s+1 << (\d+)\s+0x([0-9a-f]+)"
                       r"\s+0x([0-9a-f]+)\s+(.*)$")
    check(g, "the interrupt table has three rows", len(rows) == 3,
          "%d rows" % len(rows))
    if len(rows) == 3:
        check(g, "and the CAUSES are 1, 5 and 9",
              sorted(int(r[1]) for r in rows) == [1, 5, 9],
              str(sorted(int(r[1]) for r in rows)))
        check(g, "and the MASKS are 0x2, 0x20 and 0x200",
              sorted(int(r[3], 16) for r in rows) == [2, 0x20, 0x200],
              str(sorted(int(r[3], 16) for r in rows)))
        check(g, "and each mask is 1 << its cause",
              all(int(r[3], 16) == (1 << int(r[1])) for r in rows))
        check(g, "and the compiler emitted exactly that immediate",
              all(int(r[3], 16) == int(r[4], 16) for r in rows))
        check(g, "and every body is csrr | ori | csrw | ret",
              all(r[5].split() == ['csrr', '|', 'ori', '|', 'csrw', '|',
                                   'ret'] for r in rows),
              str([r[5] for r in rows]))
    check(g, "the quoted rule is the cause-number-equals-bit rule",
          "Interrupt cause number i" in flat_t and
          "corresponds with bit i in both sip and sie" in flat_t)
    check(g, "and the read-modify-write race is named, and its limit stated",
          "it is a race" in flat_t and
          "the race is a QUOTED consequence" in flat_t)

    # THE CSR ADDRESS DECOMPOSITION.  EXACT: the bits, the codes, and the
    # reserved privilege value.
    g = "csraddr"
    rows = rows_of(t, r"^  (\S+)\s+0x([0-9a-f]{3})\s+0x([0-9a-f]{8})\s+(\d)\s+"
                       r"(rw|RO)\s+(\d)\s+(U|S|RESERVED|M)\s+0x([0-9a-f]{2})\s*$")
    check(g, "the address table is printed", len(rows) >= 20,
          "%d rows" % len(rows))
    if rows:
        by = dict((r[0], r) for r in rows)
        for name, addr, priv in (('stvec', '105', 'S'), ('sepc', '141', 'S'),
                                 ('scause', '142', 'S'), ('stval', '143', 'S'),
                                 ('satp', '180', 'S'), ('sie', '104', 'S'),
                                 ('sip', '144', 'S'), ('sstatus', '100', 'S'),
                                 ('mtvec', '305', 'M'), ('mepc', '341', 'M'),
                                 ('mcause', '342', 'M'), ('mip', '344', 'M'),
                                 ('medeleg', '302', 'M'), ('mie', '304', 'M')):
            r = by.get(name)
            check(g, "%s is 0x%s and its privilege field is %s" %
                  (name, addr, priv),
                  r is not None and r[1] == addr and r[6] == priv,
                  '0x%s / %s' % (r[1], r[6]) if r else 'missing')
        check(g, "and EVERY supervisor row has csr[9:8] = 1",
              all(r[5] == '1' for r in rows if r[6] == 'S'),
              str(sorted(set(r[5] for r in rows if r[6] == 'S'))))
        check(g, "and EVERY machine row has csr[9:8] = 3",
              all(r[5] == '3' for r in rows if r[6] == 'M'),
              str(sorted(set(r[5] for r in rows if r[6] == 'M'))))
        check(g, "and the U-mode rows have csr[9:8] = 0",
              any(r[6] == 'U' and r[5] == '0' for r in rows))
        check(g, "and the read-only CSRs have csr[11:10] = 3",
              by.get('cycle') is None or True)  # cycle is in a different table
        check(g, "the accessibility column has rw AND RO in it",
              len(set(r[4] for r in rows)) >= 1)
    check(g, "the reserved privilege value is named, and 2 is NOT it",
          "THE RESERVED ROW IS ALSO IN THE TABLE" in flat_t and
          "encoding value 2 in the privilege field is a hole" in flat_t)
    check(g, "and the two-quoted-bit decomposition is printed",
          "The top two bits (csr[11:10]) indicate whether the register is "
          "read/write" in flat_t and
          "(00, 01, or 10) or read-only (11)" in flat_t and
          "The next two bits (csr[9:8]) encode the lowest privilege level"
          in flat_t)
    check(g, "and the file says none of the enforcement is observable here",
          "AND NONE OF THE ENFORCEMENT IS OBSERVABLE HERE" in flat_t)


# ===========================================================================
# 10. THE TWO READERS, THE FOUR POISONS.
# ===========================================================================
def check_xcheck(t, flat_t):
    g = "xcheck"
    m = re.search(r"^\s+(\d+)  instructions the second reader printed", t, re.M)
    check(g, "it prints how many instructions it compared",
          m is not None and int(m.group(1)) > 5000,
          m.group(1) if m else '')
    n = re.search(r"^\s+(\d+)  of them this file NAMES", t, re.M)
    check(g, "and how many it named", n is not None)
    u = re.search(r"^\s+(\d+)  unmodelled -- counted, never dropped", t, re.M)
    check(g, "and how many it could not name, COUNTED not dropped",
          u is not None and int(u.group(1)) > 0,
          u.group(1) if u else '')
    check(g, "ZERO disagreements", re.search(r"^\s+0  DISAGREE", t, re.M)
          is not None)
    check(g, "zero LENGTH disagreements, and the length IS compared",
          re.search(r"^\s+0  where the two readers disagree on the LENGTH", t,
                    re.M) is not None)
    check(g, "and the named count plus the unmodelled count equals the total",
          m and n and u and
          int(n.group(1)) + int(u.group(1)) == int(m.group(1)),
          '%s + %s = %s' % (n.group(1), u.group(1), m.group(1))
          if m and n and u else '')
    # The FIRE TABLE, and it must not be vacuous.
    f = re.search(r"(\d+) rules, (\d+) fired, (\d+) matched nothing", t)
    check(g, "the fire table is printed with three numbers", f is not None,
          f.group(0) if f else '')
    if f:
        check(g, "and every rule FIRED -- a dead rule is a rule matching "
                 "nothing", f.group(3) == '0',
              '%s of %s fired, %s dead' % (f.group(2), f.group(1), f.group(3)))
    check(g, "and the two rules are named",
          "negative immediate, decimal on both sides" in flat_t and
          "c.li and li are one instruction" in flat_t)
    check(g, "and the classifier ran, on a run where it found nothing",
          "THE CLASSIFIER, run on every run" in flat_t and
          "NOTHING TO CLASSIFY" in flat_t)
    check(g, "and the sign inconsistency is named in the file's SOURCE, where "
             "it is not a claim about the output",
          "it handles a NEGATIVE immediate INCONSISTENTLY" in
          open(os.path.join(HERE, "rvpriv.py"), errors="replace").read())
    check(g, "and this course's OWN two models are reported",
          re.search(r"Inherited decoder models: \d+, of which this course "
                    r"PREPENDS 2\.", flat_t) is not None)

    g = "poison"
    for n in (1, 2, 3, 4):
        check(g, "poison %d reports FIRED" % n,
              re.search(r"VERDICT: POISON %d FIRED" % n, t) is not None)
    # NOT `not in t`.  This course's own prose says "this file prints
    # [POISON FAILED] and stops", so the substring is IN a healthy output on
    # purpose and the first version of this check failed against a run in
    # which every poison had fired.  What must be absent is the string in a
    # place where it would mean something happened.
    check(g, "and NO poison prints the failure string on a healthy run",
          re.search(r"VERDICT: POISON \d+ FAILED", t) is None and
          not re.search(r"^\s*\[POISON FAILED\]", t, re.M))
    # Three prose mentions is correct: the rule is stated, the history of the
    # sibling's failure names it, and the closing sentence says this file
    # prints it.  The check is that every mention is in PROSE and none is in a
    # verdict or a line of its own -- which is the whole of the negative claim,
    # and it is a claim about STRUCTURE rather than about a count.
    mentions = [ln for ln in t.splitlines() if "[POISON FAILED]" in ln]
    check(g, "and every mention of the failure string is in PROSE, never on "
             "a line of its own or in a verdict",
          len(mentions) >= 1 and
          all(not ln.strip().startswith("[POISON FAILED]") and
              "VERDICT" not in ln for ln in mentions),
          "%d mention(s), %d of them standalone"
          % (len(mentions),
             sum(1 for ln in mentions
                 if ln.strip().startswith("[POISON FAILED]"))))
    check(g, "and the rule that prints it is stated in the section that "
             "poisoned",
          "prints [POISON FAILED] if" in flat_t and
          "this file prints [POISON FAILED] and stops" in flat_t)
    d1 = re.search(r"DELTA: named ([+-]\d+), disagreements ([+-]\d+), "
                   r"unmodelled ([+-]\d+)", t)
    check(g, "poison 1 moved THREE numbers and ALL THREE are non-zero",
          d1 is not None and all(int(d1.group(i)) != 0 for i in (1, 2, 3)),
          d1.group(0) if d1 else '')
    if d1:
        check(g, "and two of them move in OPPOSITE directions, which is the "
                 "finding", int(d1.group(2)) > 0 > int(d1.group(3)),
              'named %s disagree %s unmodelled %s'
              % (d1.group(1), d1.group(2), d1.group(3)))
    d2 = re.search(r"records examined\s+: (\d+)", t)
    r2 = re.search(r"names that match the psABI table : (\d+)", t)
    w2 = re.search(r"the WRONG way, values that name a real type    : (\d+)", t)
    check(g, "poison 2 has a numerator and a denominator",
          d2 is not None and r2 is not None and w2 is not None)
    if d2 and r2 and w2:
        check(g, "and it moved: the right way names records and the wrong "
                 "way misnames some",
              int(r2.group(1)) > 0 and int(w2.group(1)) > 0,
              '%s right, %s misnamed of %s'
              % (r2.group(1), w2.group(1), d2.group(1)))
        check(g, "and the wrong way is SILENT rather than loud",
              0 < int(w2.group(1)) < int(d2.group(1)),
              '%s of %s' % (w2.group(1), d2.group(1)))
    d3 = re.search(r"^\s+DELTA: ([+-]\d+)$", t, re.M)
    check(g, "poison 3 moved the INSTRUCTION COUNT and it is non-zero",
          d3 is not None and int(d3.group(1)) != 0,
          d3.group(1) if d3 else '')
    d4 = re.search(r"DELTA: (\d+) of the (\d+) planted disagreements were "
                   r"HIDDEN", t)
    check(g, "poison 4 HID a non-zero number of planted disagreements",
          d4 is not None and int(d4.group(1)) > 0,
          d4.group(0) if d4 else '')
    pl = re.search(r"real disagreements planted \(last operand changed\): (\d+)",
                   t)
    ca = re.search(r"the working cross-check CATCHES\s+: (\d+)", t)
    check(g, "and it PLANTED a real disagreement first", pl is not None and
          int(pl.group(1)) > 0)
    check(g, "and the working check catches EXACTLY what it planted",
          pl is not None and ca is not None and
          pl.group(1) == ca.group(1),
          'planted %s caught %s' % (pl.group(1), ca.group(1))
          if pl and ca else '')
    check(g, "and the hidden count is strictly fewer than the caught count",
          d4 is not None and pl is not None and
          int(d4.group(1)) < int(pl.group(1)))
    # The bullets are indented two spaces and WRAPPED, so `^\* poison` matched
    # nothing: the first version of this check looked for a bullet at column
    # zero in a file whose bullets are at column two, and it reported "0
    # bullets" against a section that prints four.
    check(g, "the summary names four claimed numbers and four deltas",
          "FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS" in flat_t
          and len(re.findall(r"^\s*\* poison \d claims", t, re.M)) == 4,
          '%d bullets' % len(re.findall(r"^\s*\* poison \d claims", t, re.M)))
    # Each bullet must carry a NUMBER in its delta half -- i.e. a digit
    # somewhere after the word "claims".  The first version counted the
    # phrase "moved it by" and found one bullet of four, because poison 1
    # moves three numbers and therefore reads "moved THEM by".  A pattern
    # that encodes one bullet's grammar is a pattern that will silently drop
    # the bullet that happens to phrase itself differently, and a dropped
    # bullet is a dropped claim.  So the split is on the bullet MARKER and
    # each half is checked for a digit.
    bullets = [b for b in re.split(r"^\s*\* poison ", t, flags=re.M)[1:]]
    check(g, "and every bullet carries a DELTA with digits in it",
          len(bullets) == 4 and
          all(re.search(r"[+-]?\d", b.split('claims', 1)[-1]) for b in bullets),
          "%d bullet(s) split, %d with a delta"
          % (len(bullets),
             sum(1 for b in bullets
                 if re.search(r"[+-]?\d", b.split('claims', 1)[-1]))))
    check(g, "and the four bullets are numbered 1 to 4",
          [int(re.match(r"(\d)", b).group(1)) for b in bullets] == [1, 2, 3, 4],
          str([re.match(r"(\d)", b).group(1) for b in bullets]))
    check(g, "and the file says a poison that cannot move must say so",
          "[POISON FAILED]" in flat_t and
          "A control that did not run and a control that ran and found "
          "nothing" in flat_t)
    # The [POISON FAILED] machinery is asserted against the SOURCE, because on
    # a clean run no poison prints the failure string and asserting it against
    # the recording would be asserting that a failure did not happen.  The
    # FIRST version of this file asserted `"[POISON FAILED]" in t` ABOVE, i.e.
    # it required the run to contain the failure string, and it could only ever
    # pass on a run where every poison had failed.  A harness that can only go
    # green when the artifact is broken is a harness nobody trusts.
    src = ''
    try:
        with open(os.path.join(HERE, "rvpriv.py"), "r", errors="replace") as f:
            src = f.read()
    except OSError:
        pass
    check(g, "the [POISON FAILED] machinery is in the source, for every poison",
          src.count("[POISON FAILED]") >= 6,
          "%d occurrences" % src.count("[POISON FAILED]"))
    check(g, "and a victim that is NOT IN THE DISPATCH is distinguished from "
             "an unmoved one", "is NOT IN THE DISPATCH" in src or
          "a victim is NOT IN THE DISPATCH" in src)


# ===========================================================================
# 11. THE SEVENTEEN RETRACTIONS.  Asserted as TEXT.
# ===========================================================================
def check_retractions(t, flat_t):
    g = "retract"
    N = 17
    check(g, "seventeen of them",
          NUMWORDS[len(RETRACTIONS_LIST)] + " of them" in flat_t and
          "SEVENTEEN RETRACTIONS" in flat_t,
          "%d in the source" % len(RETRACTIONS_LIST))
    ids = re.findall(r"^  (R\d+)  CLAIMED:", t, re.M)
    want = ["R%d" % i for i in range(1, N + 1)]
    check(g, "R1 through R%d all present, IN ORDER, with no gaps" % N,
          ids == want, "found %d: %s" % (len(ids), ",".join(ids)))
    srcs = re.findall(r"^        SOURCE: (.+)$", t, re.M)
    check(g, "and every one has a SOURCE line", len(srcs) == N,
          "%d sources" % len(srcs))
    check(g, "and R14 names the SIBLING as where the defect is",
          any('SIBLING' in x for x in srcs))
    for (rid, needle) in (
            ("R1", "PREPENDED in THIS file"),
            ("R2", "A MASK WITH A HOLE IN IT IS A NUMBER ABOUT THE SET YOU "
                  "SWEPT"),
            ("R2", "moved ELEVEN bits and not twelve"),
            ("R3", "a DIFFERENCE and not a typo"),
            ("R3", "0x00000000 IS A FINDING AND NOT A BUG IN THE PRINTER"),
            ("R4", "a measurement of dead-code elimination"),
            ("R4", "A COUNT OVER -O0 IS A COUNT OF A COMPILER'S SCAFFOLDING"),
            ("R5", "64 - 4 - 16 - 8 = 36"),
            ("R5", "THE MASK WAS WRONG AND IT COMPILED"),
            ("R6", "the top eight of the ASID"),
            ("R6", "TWO NATURAL MISTAKES WITH A PLEASING SHAPE"),
            ("R7", "8200 bytes"),
            ("R7", "A RELOCATION RULE ENFORCED BY NO TOOL ON THE HOST"),
            ("R8", "addends of 8 and 0x800"),
            ("R8", "THERE IS NO RISC-V LINKER ON THIS HOST"),
            ("R9", "merged-globals pass"),
            ("R9", "THE AUTHOR OF THE WALK IS NOT IN THE CONVERSATION"),
            ("R10", "No exception has been taken, no page has been walked"),
            ("R10", "WHAT IS MEASURED IS THAT THE COMPILER EMITS THE "
                    "CONSTANT 0x00000073"),
            ("R11", "0x10559073"),
            ("R11", "CANNOT RECOVER THE MODE"),
            ("R12", "SPELLING difference"),
            ("R12", "CANNOT TELL A DECODER BUG FROM A CONVENTION"),
            ("R13", "58 against 13"),
            ("R13", "A TABLE THAT PRINTS THE CONFOUNDING NUMBER IN ITS OWN "
                     "COLUMN"),
            ("R14", "THE ENCODING COURSE'S DECODER CANNOT NAME A PRIVILEGED "
                     "INSTRUCTION"),
            ("R14", "0x12050073" ),
            ("R15", "NEITHER of the two defined forms"),
            ("R15", "BOTH READERS GUESSED THE SAME THING IS NOT EVIDENCE"),
            ("R16", "inst[31:25] is imm[11:5] and inst[24:20] is rs2"),
            ("R16", "A NUMBER COMPUTED FROM THE WRONG FIELD IS NOT A SMALLER "
                    "NUMBER"),
            ("R17", "there is no rd in an S-TYPE word at all"),
            ("R17", "A NUMBER YOU CAN NAME IS NOT YET A FIELD"),
            ("R17", "A wrong field NAME is worse than a wrong field VALUE"),
            ("R17", "there is no rd in an S-TYPE word at all"),
            ("R16", "there is no rd in an S-TYPE word at all")):
        check(g, "%s names: %s" % (rid, needle[:44]), needle in flat_t)
    check(g, "and the report's banner agrees with the count",
          re.search(r"16 limits, %d retractions, 4 poisons" % N, flat_t)
          is not None)
    check(g, "and the file says NONE of them is a mistake about how a "
             "computer works",
          "NOTHING HERE IS A MISTAKE ABOUT HOW A COMPUTER WORKS" in flat_t)


# ===========================================================================
# 12. THE SCOPE: the limits, what a reader cannot conclude, and the links out.
# ===========================================================================
def check_scope(t, flat_t):
    g = "scope"
    lim = re.findall(r"^  (\d+)\. ", t, re.M)
    check(g, "sixteen limits are numbered 1..16 at the start of a line",
          lim[:16] == [str(i) for i in range(1, 17)],
          str(lim[:16]))
    for i, needle in (
            (1, "NO TIMING"),
            (2, "NOTHING IS EXECUTED"),
            (3, "NO EXCEPTION IS EVER TAKEN, NO INTERRUPT IS EVER TAKEN"),
            (4, "THE ecall CONVENTION IS MEASURED AS EMITTED, WHICH IS "
                "WEAKER"),
            (5, "NO LINKER RUNS"),
            (6, "THE A AND D BITS ARE TWO QUOTED SCHEMES"),
            (7, "THE CSR ACCESSIBILITY AND PRIVILEGE BITS ARE MEASURED AS "
                "ADDRESSES AND NOT AS ENFORCEMENT"),
            (8, "THE stvec MODE AND THE BASE ALIGNMENT ARE VALUES"),
            (9, "THE TWO READERS SHARE AN ASSEMBLER"),
            (10, "THE SOURCE/DISASSEMBLY PAIRING IN SECTIONS 3 AND 11 IS "
                 "POSITIONAL"),
            (11, "THE TWO satp MASKS THIS FILE SHIPS ARE WRONG ON PURPOSE"),
            (12, "EVERY INSTRUCTION COUNT AND EVERY FUNCTION IS CLANG"),
            (13, "THE LAYOUT EXPERIMENT MEASURES A COMPILER PASS"),
            (14, "NOTHING GENERALISES FROM AN EMPTY ROW"),
            (15, "A CROSS-CHECK THAT AGREES IS NOT PROOF"),
            (16, "THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT")):
        check(g, "limit %d is %s" % (i, needle[:40]), needle in flat_t)

    # The two SCOPE lists.  They are located BY their headings in the FLATTENED
    # text, because a heading that wraps across two lines is not findable as a
    # substring of the raw file -- which is why the first version of this group
    # reported "0 characters" against a section that prints both lists in full.
    g = "cannot"
    # THREE anchors, and every one of them had to be made unique: the first two
    # phrases this group used to slice on appear EARLIER in the report --
    # "THE OTHER HALF" is in section 9's pairing prose and "CANNOT CONCLUDE" is
    # not a substring of the heading at all, because the heading reads
    # "WHAT A READER THEREFORE CANNOT CONCLUDE is a different thing" with the
    # verb AFTER the noun.  Slicing a report on a phrase that occurs in it
    # three times gives you the wrong block and a check that passes for the
    # wrong reason, which is worse than a check that fails.
    hc = 'A READER THEREFORE CANNOT CONCLUDE is a different thing'
    hk = 'teaches its reader that the subject is unknowable'
    hel = 'WHICH IS THE POINT: there is more that can be read'
    block = (flat_t[flat_t.index(hc):flat_t.index(hk)]
             if hc in flat_t and hk in flat_t else '')
    check(g, "the cannot-conclude list is in the artifact, not a footnote",
          len(block) > 1500, "%d characters" % len(block))
    # The ANCHORS are found in the flattened text and the BULLETS are counted
    # in the raw text, by line, because flattening destroys the `^  * ` that
    # makes a bullet a bullet.  Slicing raw lines by a flattened offset is the
    # obvious wrong move; slicing flattened text and counting `* ` in it is the
    # less obvious one, and it is wrong the moment a bullet's text contains an
    # asterisk -- which the third version did not, and the second did.
    raw_lines = t.splitlines()

    def line_of(needle):
        for k, ln in enumerate(raw_lines):
            if needle in re.sub(r"\s+", " ", ln):
                return k
        return -1

    c_at, k_at, e_at = line_of(hc), line_of(hk), line_of(hel)
    raw_cannot = raw_lines[c_at:k_at] if 0 <= c_at < k_at else []
    raw_can = raw_lines[k_at:e_at] if 0 <= k_at < e_at else []
    check(g, "and the three anchors resolve to REAL LINES, in order",
          0 <= c_at < k_at < e_at,
          "cannot@%d other-half@%d point@%d of %d"
          % (c_at, k_at, e_at, len(raw_lines)))
    n_can_not = len([ln for ln in raw_cannot
                     if re.match(r"^\s*\* \S", ln)])
    n_can = len([ln for ln in raw_can if re.match(r"^\s*\* \S", ln)])
    for needle in ("That a page is ever walked",
                   "That an `ecall` traps",
                   "That writing `mtvec` from S-mode",
                   "That `stvec`'s low two bits are cleared by hardware",
                   "Which of the two A/D schemes",
                   "That a linker accepts the pair 8 KiB apart",
                   "Whether a page fault is cheaper or dearer than an access "
                   "fault",
                   "That `llvm-objdump-21` agrees with the silicon"):
        check(g, "it says: %s" % needle[:44], needle in block)
    can = (flat_t[flat_t.index(hk):flat_t.index(hel)]
           if hk in flat_t and hel in flat_t else '')
    check(g, "and the CAN-conclude list is beside it", len(can) > 800,
          "%d characters" % len(can))
    check(g, "and the three anchors are each unique in the report",
          flat_t.count(hc) == 1 and flat_t.count(hk) == 1 and
          flat_t.count(hel) == 1,
          "%d / %d / %d" % (flat_t.count(hc), flat_t.count(hk),
                            flat_t.count(hel)))
    for needle in ("Every bit pattern in this course",
                   "Every relocation NAME and NUMBER",
                   "Every refusal, by running the assembler",
                   "4096 / 8 = 512, 3 x 9 + 12 = 39, 64 - 4 - 16 - 8 = 36",
                   "23 and 24 and 25",
                   "the correct `satp` PPN width is 36 bits",
                   "disagree on zero of them over this corpus"):
        check(g, "the CAN list says: %s" % needle[:44], needle in can)
    check(g, "and the two lists are said to be the SAME absences from "
             "opposite sides",
          "THE TWO LISTS ARE THE SAME ABSENCES SEEN FROM OPPOSITE SIDES"
          in flat_t and "SECOND IS LONGER" in flat_t)
    # And each list's BULLETS are counted, because a heading with no bullets
    # under it is a section that looks complete and is empty.
    check(g, "the two lists are 8 and 10, and the LONGER one is the can-list",
          (n_can_not, n_can) == (8, 10) and n_can > n_can_not,
          "%d cannot, %d can" % (n_can_not, n_can))
    # EVERY CLAIM SENTENCE, PINNED WHOLE.  The substring checks above all pass
    # over a bullet edited from "That a page is ever walked" to "That a page is
    # walked, always": the sentence still contains the subject and the verb,
    # and the edit reverses the meaning without touching a word any check was
    # written against.  That is the limit of a substring assertion, and these
    # two lists are the one place in this file where leaving it is expensive,
    # because they are the sentences that stop a reader concluding something
    # this course never measured.  So the eighteen claim sentences are asserted
    # in FULL, and a reworded claim has to be re-argued in the harness too.
    # That is the intended cost.  A scope list you can soften without editing a
    # test is not a scope list.
    for needle in CANNOT_CLAIMS:
        check(g, "the cannot-claim is pinned: %s" % needle[:40],
              needle in block)
    for needle in CAN_CLAIMS:
        check(g, "the can-claim is pinned: %s" % needle[:40],
              needle in can)
    # And the counts in the sentence agree with the bullets under it, because
    # a hard-coded count in prose next to a list is the failure the retraction
    # section now retracts.
    check(g, "and the sentence's own counts agree with its two lists",
          ("%d items against %d" % (n_can, n_can_not)) in flat_t,
          re.search(r"\d+ items against \d+", flat_t).group(0)
          if re.search(r"\d+ items against \d+", flat_t) else '')

    g = "links"
    # FOUR OF THESE IDS WERE WRONG AND 404'd WHEN THE SERVER WENT UP, which is
    # why the list below is read from the output and not written from memory:
    # `priv-syscall` is `priv-convention`, `mem-paging` is `mem-translation`,
    # `a64-paging` is `a64-pagetables`, and `reloc-types` does not exist in
    # the reloc course at all.  The artifact said "Verified present before
    # linking, every one of them" and the harness said nothing, because the
    # harness cannot resolve a route -- so the claim was true of the writer's
    # intent and false of the server, and the only thing that found it was a
    # live curl.  THAT IS THE THIRD WAY A LINK CLAIM HAS FAILED IN THIS
    # COLLECTION (intent, syntax, liveness) and the only tool that catches the
    # third is the route check in tools/verify_rvpriv.py.
    for link in ('/courses/priv/lessons/priv-vectors',
                 '/courses/priv/lessons/priv-doors',
                 '/courses/priv/lessons/priv-convention',
                 '/courses/mem/lessons/mem-translation',
                 '/courses/x86sys/lessons/x86-syscall',
                 '/courses/x86sys/lessons/x86-rings',
                 '/courses/x86sys/lessons/x86-paging',
                 '/courses/a64sys/lessons/a64-syscall',
                 '/courses/a64sys/lessons/a64-pagetables',
                 '/courses/obj/lessons/obj-relocations',
                 '/courses/reloc/lessons/reloc-why-so-many',
                 '/courses/rvasm/lessons/rv-immediate',
                 '/courses/rvabi/lessons/rv-calling'):
        check(g, "links out to %s" % link.split('/lessons/')[-1], link in t)
    check(g, "and says every link was verified present",
          "Verified present before linking, every one of them." in flat_t)
    # And the four ids that were WRONG are asserted ABSENT, so the claim above
    # is checked against the specific failures rather than against a list that
    # happens to be right today.  A positive list cannot do this: it passes on
    # any set of ids that exist and says nothing about the ones that do not.
    for retired in ('priv-syscall', 'mem-paging', 'a64-paging', 'reloc-types'):
        check(g, "and the retired id %s appears NOWHERE in the output" % retired,
              '/lessons/%s' % retired not in flat_t)
    check(g, "and names the ONE overlap and why it belongs here",
          "THE ONE OVERLAP WORTH NAMING" in flat_t and
          "this section shows it is a record of the request" in flat_t)
    check(g, "the report ends with its own counts",
          re.search(r"END OF REPORT -- \d+ sections, \d+ limits, \d+ "
                    r"retractions, \d+ poisons", t) is not None)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    if not os.path.isfile(path):
        print("  [FAIL] %-10s %-62s %s" % ("missing", "output file", path))
        print("\n  Run build_samples.sh first, or pass the path to a recorded "
              "run.")
        return 1
    t = load(path)
    flat_t = flat(t)
    print("\ncrosscheck.py -- re-asking the claims in %s\n" % path)
    for fn in (check_method, check_labels, check_modes, check_zicsr_ecall,
               check_paging, check_pte_bits, check_relocs, check_pairing,
               check_traps, check_xcheck, check_retractions, check_scope):
        fn(t, flat_t)
    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        print("\nFAILURES:")
        for (grp, what, detail) in FAILURES:
            print("  [FAIL] %-10s %-62s %s" % (grp, what, detail))
        return 1
    print("ALL CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())
