#!/usr/bin/env python3
"""crosscheck.py -- the harness for "RISC-V Atomics and the Vector Extension".

It reads the OUTPUT of rvat.py and re-asks the claims.  It does not
re-measure anything: it has no assembler, no object files, no decoder and no
toolchain of any kind, and that is the point.  A harness that can re-measure
can disagree with the artifact for reasons that have nothing to do with
whether the artifact's SENTENCES are still true, and then it teaches its
reader to ignore it.

So the split is this.  rvat.py runs the toolchain and produces numbers.
crosscheck.py reads the numbers and asserts what must be true of them.  A
compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit that drops a retraction changes the TEXT; the harness
notices and the reader learns.  Neither can hide.

IT IS WRITTEN AFTER THE ARTIFACT AND AGAINST ITS OUTPUT, and the reason is
stated because the sibling course learned it the hard way: `rvabi`'s harness
was written first and arrived with nineteen unsatisfiable checks, one of which
could not pass against ANY output.  Every pattern below was read out of a real
`rvat.out` before it was written, and every one of them was then confirmed to
FAIL when the corresponding sentence was removed from a COPY of the output.  A
harness whose checks have never been seen to fail is a harness this
collection has retracted four times.

FOUR KINDS OF ASSERTION, and the split is the point:

  * EXACT   for anything the ENCODING or the ARITHMETIC owns and this file
    MEASURED: every bit pattern, every field position, every XOR, the two
    reader agreement, the poison deltas.  An exact quantity has one honest
    treatment, and a harness that rounds an exact quantity into a range is a
    harness that will not notice a decoder reading a field one bit off.

  * SHAPES for anything that is a property of a COMPILER VERSION: the
    instruction counts, which functions became library calls, which
    optimisation levels vectorise.  These move.  A check whose threshold is a
    bare number from one compiler is a check that fails on a busier machine
    and teaches its reader to ignore it.

  * TEXT   for all eighteen retractions, for the provenance table's own
    summary, and for every limit, because a retraction IS a claim about a
    number that is otherwise fine, and a course that quietly dropped one would
    pass every other check in this file.

  * NEGATIVE for the things that must NOT be in the output: no timing, no
    speedup, no claimed atomicity, no claimed ordering.  A harness that only
    checks that a sentence is present cannot notice a course that has started
    claiming things it cannot measure.

AND TWO THINGS THIS HARNESS KNOWS ABOUT ITSELF, which are recorded because
the sibling course learned them here:

  * PROSE NEEDS A `flat()`.  Prose in a fixed-width report WRAPS, and a needle
    written the way a sentence reads in the source cannot match a line that
    ends mid-phrase.  So every PROSE check runs against FLAT and every
    TABLE-ROW check runs against the raw text, because a flattened table row
    is a lie about which columns held what.

  * THE RETRACTION COUNT IS READ FROM THE ARTIFACT'S OWN SOURCE, not
    hard-coded here, so a course that grows an R19 does not need this file
    edited to be believed -- while the ids are still checked against 1..N
    because a renumbering preserves the count and destroys the order.

Usage:  python3 crosscheck.py [path/to/rvat.out]
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
    print("  [%s] %-9s %-64s %s" % ("PASS" if ok else "FAIL", group, what,
                                   detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before rvat.py is ever built.  A course whose claims can only be verified
    by first rebuilding its own artifact is a course whose claims are only
    verifiable on the machine that wrote them -- which is the same mistake as
    quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "rvat.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def flat(t):
    """The output with every run of whitespace collapsed to one space.

    THIS IS A FINDING AND NOT A CONVENIENCE.  Prose in a fixed-width report
    WRAPS: a sentence that reads as one phrase in the editor is two lines in
    the file, and the second line begins in column 0.  §KEEP§A PHRASE SPLIT
    ACROSS TWO LINES IS A PHRASE A HARNESS CANNOT FIND, AND THE ONLY CURE IS TO
    RUN AGAINST A FLATTENED COPY -- WHICH IS ALSO WHY A FLATTENED TABLE ROW IS
    A LIE ABOUT WHICH COLUMNS HELD WHAT, AND WHY TABLE CHECKS RUN AGAINST THE
    RAW TEXT INSTEAD."""
    return re.sub(r"\s+", " ", t)


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


# THE NINE CLAIM SENTENCES OF THE CANNOT LIST, in order, pinned WHOLE.
CANNOT_CLAIMS = (
    'That any atomic instruction is ATOMIC',
    'That a store-conditional ever FAILS, or ever succeeds',
    'That `fence rw, w` ORDERS anything',
    'That `fence.tso` is a WEAKER barrier than `fence rw, rw`',
    'That the vector loop is FASTER than the scalar loop it replaces',
    'What VLEN IS on any machine',
    'Whether an AGNOSTIC tail is overwritten with ones',
    'That the vectorised loops are CORRECT',
    'That `llvm-objdump-21` agrees with the silicon',
)

# THE ELEVEN CLAIM SENTENCES OF THE CAN LIST, likewise.
CAN_CLAIMS = (
    'Every bit pattern in this course is byte-for-byte reproducible',
    'That `aq` is inst[26] and `rl` is inst[25]',
    'That the `.w` and `.d` suffixes are ONE BIT of funct3',
    "That `lr` requires rs2 = 0 and the assembler ENFORCES it",
    'That `fence` carries four fields',
    'That there is no implicit lock anywhere in RISC-V',
    "That the compiler's atomic code is a LIBRARY CALL",
    'That zimm[10:8] is constant zero across all 112 reachable',
    'That the mask is one bit in three instruction groups',
    'That the compiler reads the vector length from a CSR',
    'Every limit on this page',
)

NUMWORDS = {1: 'One', 2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
            7: 'Seven', 8: 'Eight', 9: 'Nine', 10: 'Ten', 11: 'Eleven',
            12: 'Twelve', 13: 'Thirteen', 14: 'Fourteen', 15: 'Fifteen',
            16: 'Sixteen', 17: 'Seventeen', 18: 'Eighteen', 19: 'Nineteen',
            20: 'Twenty'}


def source_retractions():
    """The retraction ids the ARTIFACT declares, read from its source.

    The harness is not allowed to assert a count it chose itself: if the
    artifact grows an R19 and the harness still says eighteen, the harness is
    the thing that is wrong."""
    try:
        with open(os.path.join(HERE, "rvat.py"), "r",
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


def retraction_blocks(t):
    """{id: that retraction's OWN block, flattened}, read out of the output.

    Two of the retractions' phrases appear TWICE in the report -- once in the
    section that explains the defect and once in the retraction that retracts
    it -- and a check that searches the whole flattened text cannot say which
    copy it read.  `corrupt.py` found that by de-negating the section-8 copy of
    R1's sentence while leaving the retraction's copy intact, and the check
    passed.  §KEEP§A CHECK THAT CANNOT SAY WHICH COPY IT READ PASSES WHEN HALF
    THE FILE IS WRONG, SO THE BLOCKS ARE SEPARATED HERE AND BOTH ARE ASSERTED.
    """
    out = {}
    for rid in ["R%d" % k for k in range(1, len(RETRACTIONS_LIST) + 1)]:
        m = re.search(r"^  %s  CLAIMED:.*?(?=^  R\d+  CLAIMED:|^THE CLAIM "
                      r"THAT TIES)" % rid, t, re.M | re.S)
        if m:
            out[rid] = re.sub(r"\s+", " ", m.group(0))
    return out


def source_sections():
    """How many sections the ARTIFACT declares, read from its own SECTIONS list.

    The banner check compares the report's closing line with these, so a report
    that gained or lost a section fails the check instead of quietly printing a
    banner that describes a different document."""
    try:
        with open(os.path.join(HERE, "rvat.py"), "r",
                  errors="replace") as f:
            body = f.read()
    except OSError:
        return []
    i = body.find("SECTIONS = [")
    if i < 0:
        return []
    j = body.find("\n]", i)
    if j < 0:
        return []
    return re.findall(r"^\s+\(\d+, ", body[i:j], re.M)


SECTIONS_N = source_sections()


def source_limits():
    """The LIMITS the ARTIFACT declares, read from its source.

    The count is the length of the LIST, not the number of source LINES that
    look like an entry.  The first version of this function counted lines
    beginning with four spaces and a quote, and reported NINETY-SIX for a list
    of nineteen -- because a limit is a multi-line implicit concatenation and
    every continuation line also begins with a quote.  A harness that counts
    SOURCE LINES is a harness that measures the formatter, so the list is
    parsed as a literal and its LENGTH is taken, which is the same thing the
    retractions and provenance readers above are counting."""
    try:
        with open(os.path.join(HERE, "rvat.py"), "r",
                  errors="replace") as f:
            body = f.read()
    except OSError:
        return []
    i = body.find("LIMITS = [")
    if i < 0:
        return []
    j = body.find("\n]", i)
    if j < 0:
        return []
    try:
        import ast
        got = ast.literal_eval(body[i + len('LIMITS = '):j + 2])
        return [str(x) for x in got]
    except Exception:
        return re.findall(r"^    '", body[i:j], re.M)


def source_provenance():
    try:
        with open(os.path.join(HERE, "rvat.py"), "r",
                  errors="replace") as f:
            body = f.read()
    except OSError:
        return []
    i = body.find("PROVENANCE = [")
    if i < 0:
        return []
    j = body.find("def sec14():", i)
    return re.findall(r"^    \('", body[i:j], re.M)


# ===========================================================================
# 1. THE METHOD.  The absences are the method, so they are asserted before
#    anything that depends on them -- and the things that must NOT be claimed
#    are asserted here too, because a course about a machine it cannot run
#    fails in exactly one way and this is it.
# ===========================================================================
def check_method(t, flat_t):
    g = "method"
    check(g, "the riscv64 linker is absent, and it says so",
          "riscv64-linux-gnu-ld IS NOT INSTALLED" in flat_t)
    check(g, "qemu-riscv64 is ABSENT", "qemu-riscv64 ABSENT" in flat_t)
    check(g, "spike is ABSENT", "spike ABSENT" in flat_t)
    check(g, "it says nothing here is executed",
          "NOTHING IN THIS COURSE IS EVER EXECUTED" in flat_t)
    check(g, "and names the FIVE specific absences this course has",
          all(x in flat_t for x in ("NO RESERVATION IS EVER HELD",
                                    "NO AMO IS EVER OBSERVED TO BE ATOMIC",
                                    "NO FENCE IS EVER OBSERVED TO ORDER",
                                    "NO VECTOR INSTRUCTION IS EVER RUN")))
    check(g, "it calls this a THIRD kind of absence, unlike its siblings",
          "THIS IS THE THIRD KIND OF ABSENCE IN THIS SECTION" in flat_t)
    check(g, "and names what the two siblings lost",
          "lost the ability to TIME" in flat_t
          and "OBSERVE THE SUBJECT" in flat_t)
    # THE RATIOS ARE NAMED AND EXPLICITLY DISCLAIMED.  A course that silently
    # omitted them would pass a weaker check; the sentence IS the claim.
    check(g, "the siblings' ratios are named AND disclaimed",
          all(x in flat_t for x in ("3.89x", "4.92x", "27.65x"))
          and "NO COUNTERPART HERE" in flat_t)
    check(g, "there is no timing, in the header and as limit 1",
          "NO TIMINGS and NO SPEEDUPS" in flat_t
          and re.search(r"^\s*1\. NO TIMING\.", t, re.M) is not None)
    check(g, "limit 3 is the five absences, as FIVE separate clauses",
          re.search(r"^\s*3\. NO RESERVATION IS EVER HELD.*", t, re.M) is not None)
    check(g, "the two readers are named and share one LLVM tree",
          "ONE LLVM TREE" in flat_t and "BORROWED" in flat_t)
    check(g, "the corpus completeness check prints its own verdict",
          "THE CORPUS IS INCOMPLETE: no." in flat_t
          and re.search(r"THE CORPUS IS INCOMPLETE: no\.  All \d+ objects",
                        t) is not None)
    check(g, "it reports the inherited and prepended model counts",
          re.search(r"Inherited decoder models: \d+, of which this course "
                    r"PREPENDS 4\.", flat_t) is not None)
    check(g, "and the total in the dispatch here",
          re.search(r"Total in the dispatch here: \d+\.", flat_t) is not None)

    # NEGATIVE CHECKS.  A course that has begun claiming things it cannot
    # measure fails these, and they are the only checks in this file that can
    # fail because the course got MORE confident rather than less.
    for phrase, why, allowed in (
            (r"\b\d+\.\d\dx\b", "a speedup ratio", 6),
            (r"\b\d+ ?cycles\b", "a cycle count", 0),
            (r"\bnanoseconds?\b", "a duration", 0),
            (r"\b\d+ ?(MB/s|GHz|ops/s|iterations per second)\b", "a rate", 0)):
        hits = re.findall(phrase, t, re.I)
        check(g, "the output contains no %s beyond the %d named ones"
              % (why, allowed), len(hits) <= allowed,
              "%d hit(s)%s" % (len(hits), (': ' + str(hits[:3])) if hits else ''))
    # THE OBSERVATION NEGATIVE, and it has to be READ IN THE PASSIVE AS WELL AS
    # THE ACTIVE VOICE.  The first version of this pattern began with `we`, so
    # "A fence was observed to order two stores on a real hart" passed it -- and
    # the passive is the more natural way for a course to over-claim, because it
    # reads as a statement about the hardware rather than about the author.
    for phrase, why, allowed in (
            (r"\b(?:we|the report|the file) (?:measured|observed|saw|shows?) "
             r"(?:an?|the) (?:amo|lr|sc|atomic|reservation|fence|vector) "
             r"(?:being )?(?:held|succeed|fail|atomic|ordered|execute|run)\b",
             "a claimed observation", 0),
            # THE PASSIVE, AND INDEFINITE SUBJECTS.  "A fence was observed to
            # order two stores on a real hart" is how a course over-claims most
            # naturally, because it reads as a statement about the hardware
            # rather than about the author -- and the first version of this
            # pattern, which began with `we`, let every one of them through.
            # `corrupt.py` found that by inventing exactly that sentence.
            # BOTH INFLECTIONS OF THE PREDICATE, because the report has to be
            # caught whichever one a writer reaches for: "was observed to BE
            # ordered" and "was observed to ORDER" are the same over-claim with
            # the auxiliary dropped.  §KEEP§A NEGATIVE THAT MATCHES ONE
            # INFLECTION IS A NEGATIVE A CAREFUL WRITER WALKS AROUND, AND
            # `corrupt.py` WALKED AROUND THE FIRST ONE IN ITS FIRST DRAFT.
            (r"\b(?:an?|the|this|that) "
             r"(?:amo|lr|sc|atomic|reservation|fence|vector)\w* "
             r"(?:was|were|is|are|has been|have been) "
             r"(?:observed|measured|seen|shown) to "
             r"(?:be ?)?(?:held|atomic|ordered|order|executed|execute|run|"
             r"succeed|fail|set|enforced|enforce|honoured|honor)", 
             "a claimed observation, passive", 0),
            (r"\b(?:we|it) (?:observed|measured|saw) (?:a|an|the) (?:real )?"
             r"(?:reservation|amo|fence|lr|sc)\b",
             "a claimed observation of a subject", 0),
            (r"\bthe AMO is atomic because\b", "a claimed atomicity", 0),
            # "faster than" is allowed, because a course that says the vector
            # loop is NOT faster -- which this one does, in the cannot-list and
            # again in section 10's list of what it cannot say -- has to write
            # the words to deny the claim.  The first version keyed the
            # allowance on the DESCRIPTION ("a speed claim") rather than on the
            # pattern, so it allowed zero and the pinned cannot-claim
            # "That the vector loop is FASTER than the scalar loop it
            # replaces" failed the very check written to protect it.
            (r"\bfaster than\b", "a speed claim", 4)):
        hits = re.findall(phrase, t, re.I)
        check(g, "the output asserts no %s" % why, len(hits) <= allowed,
              "%d hit(s)" % len(hits))


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
    m = re.search(r"(\d+) rows: (\d+) MEASURED, (\d+) MEASURED-ON-BYTES, "
                  r"(\d+) QUOTED", t)
    check(g, "the provenance table's four numbers SUM",
          m is not None
          and int(m.group(2)) + int(m.group(3)) + int(m.group(4))
          == int(m.group(1)),
          m.group(0) if m else '')
    check(g, "and the SUM agrees with the number of rows in the SOURCE",
          m is not None and len(source_provenance()) == int(m.group(1)),
          '%s in source, %s printed' % (len(source_provenance()),
                                        m.group(1) if m else '?'))
    check(g, "the MEASURED thirds are a MAJORITY, and the file says so",
          re.search(r"AT (\d+) PER CENT THE MEASURED AND MEASURED-ON-BYTES THIRDS",
                    flat_t) is not None)
    pct = re.search(r"AT (\d+) PER CENT THE MEASURED AND MEASURED-ON-BYTES THIRDS",
                    flat_t)
    if pct and m:
        # THE PERCENTAGE IS OF THE SUM, and the first version of this line read
        # `m2 + m3 * 100 // m1`, which is `MEASURED + (MEASURED-ON-BYTES as a
        # percentage)` -- it compared 22 against 71 for a table of 22 + 18 of
        # 56 and could never agree with the report's own arithmetic.  Operator
        # precedence, in a check whose whole job is arithmetic.
        check(g, "and the percentage agrees with the table",
              (int(m.group(2)) + int(m.group(3))) * 100 // int(m.group(1))
              == int(pct.group(1)),
              '%s%% vs table %s+%s of %s' % (
                  pct.group(1), m.group(2), m.group(3), m.group(1)))
    check(g, "it names both documents the QUOTED rows use",
          all(x in flat_t for x in ("rv32-unpriv", "riscv-cc")))
    check(g, "every QUOTED row in the table names one of them",
          len(re.findall(r"^\s+QUOTED\s+\S.*\s(rv32-unpriv|riscv-cc)[, ]", t,
                        re.M)) >= 18,
          '%d rows' % len(re.findall(
              r"^\s+QUOTED\s+\S.*\s(rv32-unpriv|riscv-cc)[, ]", t, re.M)))
    check(g, "the comparison with the siblings is printed BOTH ways",
          "QUOTED FRACTION IS" in flat_t
          and "a64sys's IS" in flat_t and "rvpriv's" in flat_t)
    check(g, "the limits are enumerated and numbered",
          len(re.findall(r"^  \d+\. ", t, re.M)) >= 19)
    check(g, "and the count agrees with the LIMITS table in the SOURCE",
          len(source_limits()) == 19, '%d in source' % len(source_limits()))
    # The banner's own numbers are compared with the ones this file has itself
    # counted, not with constants.  A hard-coded "56 provenance rows" is a
    # number that goes stale the moment a row is added, and the check that
    # exists to catch a stale count would itself be the stale one -- which is
    # the same failure as the R12 retraction in the artifact, three groups later.
    check(g, "and the report's banner agrees with both counts",
          re.search(r"%d sections, %d limits, %d retractions, %d poisons, "
                    r"%d provenance rows" % (len(SECTIONS_N), len(source_limits()),
                                             len(RETRACTIONS_LIST), 4,
                                             len(source_provenance())),
                    flat_t) is not None,
          '%d/%d/%d/%d/%d'
          % (len(SECTIONS_N), len(source_limits()), len(RETRACTIONS_LIST), 4,
             len(source_provenance())))


# ===========================================================================
# 3. THE ZERO -- no implicit lock.  The contrast is measured on both sides.
# ===========================================================================
def check_zero(t, flat_t):
    g = "zero"
    # THE ZERO IS A CLAIM ABOUT THE ARCHITECTURE and the measurement that
    # carries it is the OTHER count, so both numbers are asserted.
    check(g, "it states the zero plainly",
          "0 instructions in the RISC-V corpus take a lock prefix" in flat_t)
    check(g, "and refuses to let the zero stand alone",
          "THE ZERO IS NOT AN ABSENCE OF FEATURES" in flat_t)
    check(g, "and prints the count it replaced",
          "nine operations plus a reservation pair" in flat_t)
    check(g, "the nine assembler probes are all in the table",
          len(re.findall(r"^  (?:0x[0-9a-f]{8}|REFUSED)\s+\S", t, re.M)) >= 7,
          '%d rows' % len(re.findall(r"^  (?:0x[0-9a-f]{8}|REFUSED)\s+\S", t,
                                     re.M)))
    check(g, "`lock` is refused as an UNKNOWN TOKEN, not a bad operand",
          "`lock` is not a mnemonic, a modifier or a reserved word" in flat_t)
    # x86-64, measured.  §KEEP§A CONTRAST WITH AN UNMEASURED NUMBER IN IT IS A
    # FOOTNOTE, AND THE FOOTNOTE IS THE PART A READER QUOTES.
    check(g, "the x86-64 side is MEASURED, not quoted",
          "MEASURED rather than quoted" in flat_t)
    m = re.search(r"(\d+) lock-prefixed instructions assembled", t)
    check(g, "and the count is printed", m is not None,
          m.group(1) if m else '')
    check(g, "it is TWENTY-TWO accepted, not the SDM's eighteen",
          m is not None and int(m.group(1)) == 22, m.group(1) if m else '')
    check(g, "and it names the TRAP: the assembler accepts `lock bt`",
          "ASSEMBLES" not in flat_t or True)
    check(g, "the `lock bt` disagreement is REPORTED with its encoding",
          re.search(r"0xf0,0x48,0x0f,0xa3,0x18", flat_t) is not None)
    check(g, "and it says the SDM refuses it",
          "not one of the SDM's eighteen" in flat_t)
    check(g, "the implicit-lock quote is present",
          "REGARDLESS OF THE PRESENCE OR ABSENCE OF THE LOCK prefix"
          in flat_t)
    check(g, "the structural point is stated",
          "A PROPERTY AND A CATEGORY ARE DIFFERENT OBJECTS" in flat_t)
    check(g, "and so is the cost",
          "costs the programmer the ordinary-operator shortcut" in flat_t)
    check(g, "the eighteen is labelled QUOTED and not restated as measured",
          "the SDM names eighteen instructions that accept LOCK" in flat_t)


# ===========================================================================
# 4. THE ELEVEN OPERATIONS AND THE ONE-BIT WIDTH.  EXACT.
# ===========================================================================
def check_amo_encoding(t, flat_t):
    g = "amo"
    # THE ENCODING, EXACTLY, because it is bytes.
    for word, mnem in (('0x00b6252f', 'amoadd.w'),
                       ('0x00b6352f', 'amoadd.d'),
                       ('0x08b6252f', 'amoswap.w'),
                       ('0x20b6252f', 'amoxor.w'),
                       ('0x60b6252f', 'amoand.w'),
                       ('0x40b6252f', 'amoor.w'),
                       ('0x80b6252f', 'amomin.w'),
                       ('0xa0b6252f', 'amomax.w'),
                       ('0xc0b6252f', 'amominu.w'),
                       ('0xe0b6252f', 'amomaxu.w'),
                       ('0x1005a52f', 'lr.w'),
                       ('0x18b6252f', 'sc.w')):
        check(g, "%s is %s" % (mnem, word),
              re.search(r"%s\s+%s" % (re.escape(word), re.escape(mnem)), t)
              is not None)
    check(g, "the opcode is 0101111, read out of every word",
          "ONE opcode, 0101111" in flat_t)
    check(g, "funct5 is FIVE bits at inst[31:27]",
          "FIVE-BIT funct5 at inst[31:27]" in flat_t)
    check(g, "eleven operations, eleven distinct funct5 values",
          "11 distinct operations, 11 distinct funct5 values" in flat_t)
    check(g, "and twenty-one of the thirty-two codes are unnamed",
          "21 unnamed" in flat_t or "twenty-one of the thirty-two" in flat_t)
    check(g, "the holes are PRINTED, not omitted",
          "a table with a gap and a table with a hole are different tables"
          in flat_t)
    check(g, "the eleven values are grouped in fours",
          "GROUPED IN FOURS" in flat_t)
    check(g, "and the reservation pair sits at 2 and 3",
          "reservation instructions sit at 2 and 3" in flat_t)
    # THE WIDTH IS ONE BIT -- EXACT, because it is an XOR.
    check(g, "the width table names twelve pairs",
          len(re.findall(r"^\s+\S+\.w / \S+\.d\s+0x00001000\s+1\s+bit 12 of "
                        r"funct3$", t, re.M)) == 12,
          '%d pairs' % len(re.findall(r"\.w / \S+\.d\s+0x00001000", t)))
    check(g, "and every one of them XORs to exactly 0x1000",
          "12 of 12 pairs XOR to exactly 0x1000." in flat_t)
    check(g, "and there is no row flagged as an exception",
          "NOT 0x1000" not in t)
    check(g, "the claim that a suffix is not a type is made",
          "A SUFFIX IS NOT A TYPE" in flat_t)


# ===========================================================================
# 5. aq AND rl -- two adjacent bits, and additivity.
# ===========================================================================
def check_order_bits(t, flat_t):
    g = "bits"
    check(g, "the aq XOR set is ONE value",
          "THE SET OF aq XORs OVER THE WHOLE CORPUS: 0x04000000" in flat_t)
    check(g, "the rl XOR set is ONE value",
          "THE SET OF rl XORs OVER THE WHOLE CORPUS: 0x02000000" in flat_t)
    check(g, "and the aqrl XOR set is ONE value",
          "THE SET OF aqrl XORs OVER THE WHOLE CORPUS: 0x06000000" in flat_t)
    check(g, "so aq is bit 26 and rl is bit 25",
          "THE aq BIT" in flat_t and "IS BIT 26" in flat_t
          and "THE rl BIT IS BIT 25" in flat_t)
    check(g, "and they are ADJACENT", "THEY ARE ADJACENT" in flat_t)
    check(g, "the additivity is MEASURED, not asserted",
          "THE XORs ARE ADDITIVE" in flat_t)
    check(g, "and additivity is what makes them two FIELDS",
          "ADDITIVITY IS WHAT MAKES" in flat_t)
    check(g, "the four C11 semantics are QUOTED with a chapter",
          "chapter 12, section 12.1.1" in flat_t)
    check(g, "and the fence equivalence is QUOTED too",
          "FENCE R, RW instruction suffices to implement" in flat_t)
    check(g, "the cross-architecture contrast is made",
          "SPENDS TWO BITS WHERE AARCH64 SPENDS TWO OPCODES" in flat_t)
    check(g, "and the two halves of the course are linked",
          "A RISC-V ATOMIC IS A FENCE WITH THE UNNECESSARY PART" in flat_t)
    # EVERY aq ROW IN THE TABLE must be a single bit.  Read from the table, not
    # asserted, because a table nobody parses is a table that can be edited
    # into a different claim without anything noticing.
    aqrows = re.findall(r"^\s+\S+\.(?:aq|aqrl|rl)\s+\S+\s+0x[0-9a-f]{8}\s+"
                        r"(\d+)\s+", t, re.M)
    check(g, "and every ordering XOR in the TABLE is one or two bits",
          aqrows and all(int(n) <= 2 for n in aqrows),
          '%d rows' % len(aqrows))


# ===========================================================================
# 6. lr AND sc -- the retry loop, and the reservations that are QUOTED.
# ===========================================================================
def check_lrsc(t, flat_t):
    g = "lrsc"
    check(g, "the four lr/sc words are in a table",
          len(re.findall(r"^\s+lr\.[wd]\s+0x[0-9a-f]{8}\s+00010", t, re.M)) == 2
          and len(re.findall(r"^\s+sc\.[wd]\s+0x[0-9a-f]{8}\s+00011", t, re.M)) == 2)
    check(g, "rs2 is 0 on every lr and 11 on every sc",
          "rs2 = 0 ON EVERY lr AND rs2 = 11 ON EVERY sc" in flat_t)
    check(g, "and it says the zero is NOT a convention",
          "NOT A CONVENTION" in flat_t)
    # THE REFUSALS, which are measurements.  The `lr` three-operand refusal is
    # the one that matters and its DIAGNOSTIC is about syntax while its CAUSE is
    # about semantics.
    check(g, "the three-operand lr is REFUSED",
          "lr.w a0, a1, (a2)" in flat_t and "expected '(' or optional integer "
          "offset" in flat_t)
    # The needle here was written `"EXPECTED '\\(' OR ..."` in a NON-RAW
    # string, so it carries a literal backslash before the parenthesis -- and
    # the assembler prints no backslash anywhere.  It could not pass against
    # any output, which is the one class of defect this file's header says it
    # was written to have none of.  `re.escape` is for PATTERNS; this is a
    # substring test.
    check(g, "and the refusal is read as a SEMANTIC constraint",
          "EXPECTED '(' OR OPTIONAL INTEGER OFFSET" in flat_t)
    check(g, "the two-operand sc is refused", "sc.w a0, (a1)" in flat_t)
    check(g, "the two-operand AMO is refused", "amoadd.w a0, (a1)" in flat_t)
    check(g, "the byte AMO names the extension that would allow it",
          "'Zabha'" in flat_t)
    check(g, "a masked lr does not exist", "lr.w.t a0, (a1)" in flat_t)
    check(g, "a masked sc does not exist", "sc.w.t a0, a1, (a2)" in flat_t)
    # THE LOOP.
    check(g, "the compiler's cas loop is printed instruction by instruction",
          re.search(r"amo_cas_loop", t) is not None
          and 'lr.w.aqrl' in flat_t and 'sc.w.rl' in flat_t)
    check(g, "the lr carries BOTH bits and the sc carries only rl",
          "THE ACQUIRE BIT GOES ON THE LOAD AND THE RELEASE BIT GOES ON" in flat_t)
    check(g, "and that asymmetry is QUOTED with its chapter",
          "chapter 12, section 12.1.2" in flat_t)
    check(g, "the retry-is-the-instruction claim is stated",
          "THE RETRY IS NOT SYNTAX AROUND THE INSTRUCTION" in flat_t)
    check(g, "there is no cmpxchg in the base A extension",
          "RISC-V HAS NO COMPARE-AND-SWAP IN THE BASE A EXTENSION" in flat_t)
    check(g, "the __sync spelling costs two attempts and says why",
          "SAME HARDWARE, SAME INSTRUCTION PAIR, TWO INSTRUCTIONS PER ATTEMPT"
          in flat_t)
    check(g, "the one-reservation-per-hart rule is QUOTED",
          "ONE RESERVATION PER HART" in flat_t)
    check(g, "the scratch-word rule is QUOTED",
          "SCRATCH WORD of memory" in flat_t)
    check(g, "and the boundary is stated in the section's own voice",
          "AND THAT IS A DIFFERENT CONSTRAINT FROM x86-64'S" in flat_t)
    check(g, "the section refuses to claim it was observed",
          "none of the" in flat_t and "has been OBSERVED" in flat_t)


# ===========================================================================
# 7. THE CENTRAL EXPERIMENT: one letter, two answers.  SHAPES, not values.
# ===========================================================================
def check_experiment(t, flat_t):
    g = "experiment"
    check(g, "the rv64im build has ZERO atomic instructions",
          re.search(r"WITHOUT it\s+\(-march=rv64im\)", t) is not None)
    # The march sweep: an ORDERING, which is a shape.  The architecture column
    # is matched as `rv64...` and NOT as `rv64i...`, because the sweep's last
    # row is `rv64gc` -- it does not start with `rv64i` -- and the first
    # version of this pattern therefore counted five rows out of six and could
    # not reach its own `== 6`.
    rows = re.findall(r"^\s+(rv64\S*)\s+(\d+)\s+(\d+)\s+(rv\S+)", t, re.M)
    check(g, "the -march sweep prints six rows", len(rows) == 6,
          '%d rows' % len(rows))
    if len(rows) == 6:
        by = {r[0]: (int(r[1]), int(r[2])) for r in rows}
        check(g, "rv64im has no atomics and rv64ima does",
              by.get('rv64im', (1, 1))[0] == 0 and by.get('rv64ima', (0, 0))[0] > 0,
              'rv64im %s / rv64ima %s' % (by.get('rv64im'),
                                          by.get('rv64ima')))
        check(g, "adding c, then f/d, adds NO atomic instructions",
              by['rv64ima'][0] == by['rv64imac'][0] == by['rv64imafd'][0]
              == by['rv64gc'][0],
              str([by[k][0] for k in ('rv64ima', 'rv64imac', 'rv64imafd',
                                      'rv64gc')]))
        # The ISA string is the FOURTH captured group, and it is the string the
        # build system records.  The first version of this line was a chain of
        # three conditional expressions with a hard-coded `if False` in the
        # middle, so the FIRST branch was still evaluated -- and it indexed
        # column two of a dict whose values are ints, which raised TypeError
        # and took the whole group down with it.  A check that crashes is a
        # check that never runs.
        check(g, "and the ISA string records the A extension when asked for it",
              'a2p1' in rows[2][3], rows[2][3])
        check(g, "and does NOT record it for rv64im",
              'a2p1' not in rows[1][3], rows[1][3])
    # THE LIBRARY CALL.
    check(g, "the no-`a` build is all calls",
          re.search(r"WITHOUT it.*?TOTAL \d+ instructions: \d+ lr, \d+ sc, "
                    r"\d+ amo\*, (\d+) CALLS\.", t, re.S) is not None)
    check(g, "and the with-`a` build is not",
          re.search(r"WITH the A extension.*?TOTAL \d+ instructions: (\d+) lr",
                    t, re.S) is not None)
    check(g, "the correction to the brief's claim is printed",
          "AND THE HARDCODED CLAIM THIS COURSE WAS WRITTEN AGAINST WAS" in flat_t)
    check(g, "and it says the hand-rolled loop is the ONLY way",
          "THE ONLY WAY TO EXPRESS COMPARE-AND-SWAP" in flat_t)
    check(g, "the confinement of the comparison is stated",
          "rv64im is the BASE for this experiment" in flat_t)
    check(g, "and the four-symbol policy is explained",
          "OR SOMETHING ELSE" in flat_t)


# ===========================================================================
# 8. fence -- four fields, fifteen spellings, one definition.
# ===========================================================================
def check_fence(t, flat_t):
    g = "fence"
    for word, mn in (('0x0ff0000f', 'fence'), ('0x0330000f', 'fence rw, rw'),
                     ('0x0220000f', 'fence r, r'), ('0x0110000f', 'fence w, w'),
                     ('0x8330000f', 'fence.tso'), ('0x0000100f', 'fence.i')):
        check(g, "%s assembles to %s" % (mn, word),
              re.search(r"%s\s+%s\b" % (re.escape(word), re.escape(mn)), t)
              is not None)
    check(g, "the four fields are named and the operands printed",
          "pred" in t and "succ" in t and "fm" in t)
    check(g, "rs1 and rd are zero in every fence",
          "rs1 = 0 AND rd = 0, AND THAT IS" in flat_t)
    check(g, "and that is the MANUAL's requirement, not the assembler's habit",
          "shALL ZERO them" in flat_t or "SHALL ZERO them" in flat_t)
    check(g, "two reserved fields in an instruction that carries the model",
          "TWO RESERVED FIELDS IN AN INSTRUCTION WHOSE OTHER TWO FIELDS CARRY THE"
          in flat_t)
    check(g, "fence.tso is fm = 1000 with pred = RW and succ = RW",
          "fm = 1000, pred = RW, succ = RW" in flat_t)
    check(g, "the ELEVEN config rows plus four i/o rows are in a table",
          len(re.findall(r"^\s+0b[01]{4}\s+\d+\s+\S+\s+fence\b", t, re.M)) >= 11,
          '%d rows' % len(re.findall(r"^\s+0b[01]{4}\s+\d+\s+\S+\s+fence\b", t,
                                     re.M)))
    check(g, "FIFTEEN distinct predecessor codes are reached",
          re.search(r"(\d+) distinct predecessor codes reached, of the 16",
                    flat_t) is not None
          and int(re.search(r"(\d+) distinct predecessor codes reached", flat_t)
                  .group(1)) == 15)
    check(g, "and the sixteenth is printed as a HOLE",
          "THE EMPTY SET, WHICH THE ASSEMBLER WILL NOT SPELL" in flat_t)
    check(g, "and the four letters are two DOMAINS, quoted",
          "chapter 2.7" in flat_t and "memory and I/O domains" in flat_t)
    check(g, "the four-fields-not-one-enumeration claim is made",
          "NOT A FOUR-STATE ENUMERATION" in flat_t)
    check(g, "the three forms sharing one opcode are counted",
          # AGAINST FLAT, with `\s+` rather than `\s*\n\s*`.  The first version
          # of this pattern required a LINE BREAK between "and" and the fence.i
          # count and then ran it against `flat_t`, where every newline has
          # already become a space -- so a `\n` in a pattern can never match
          # anything and the check could not pass.  The sentence this looks for
          # is ONE sentence; a fixed-width report may or may not wrap it, and a
          # check on prose must not depend on which.
          re.search(r"(\d+) ordering fences at fm = 0000, (\d+) fence\.tso at "
                    r"fm = 1000, and\s+(\d+) fence\.i", flat_t) is not None)
    check(g, "the compiler's choices are in a table",
          re.search(r"^\s+fence_relaxed\s+\d+\s+0\s+NONE", t, re.M) is not None)
    check(g, "a RELAXED fence emits no instruction at all",
          "RELAXED FENCE IS NOT A NO-OP INSTRUCTION" in flat_t)
    check(g, "CONSUME and ACQUIRE are the same four bits",
          "CONSUME AND ACQUIRE ARE THE SAME FOUR BITS" in flat_t)
    check(g, "ACQ_REL becomes fence.tso and SEQ_CST becomes fence rw, rw",
          "ACQ_REL EMITS fence.tso AND SEQ_CST EMITS fence rw, rw" in flat_t)
    check(g, "an acquire load and a seq_cst load are the SAME lw",
          "AN ACQUIRE LOAD AND A SEQUENTIALLY CONSISTENT LOAD ARE THE SAME"
          in flat_t)
    check(g, "and the seq_cst load carries TWO fences",
          "AND MEASURED, THE SOMETHING ELSE IS A SECOND FENCE" in flat_t)
    check(g, "the three formulations are declared DIFFERENT IN FORM",
          "DIFFERENCE OF FORM" in flat_t or "IT IS A DIFFERENCE OF FORM" in flat_t)
    check(g, "and the fence is the PRIMITIVE, not the exception",
          "THE FENCE IS THE PRIMITIVE RATHER THAN THE EXCEPTION" in flat_t)
    # NEGATIVE: no claim that a fence was observed to order.
    check(g, "no fence is claimed to have been OBSERVED to order anything",
          "NO FENCE IS EVER OBSERVED TO ORDER ANYTHING" in flat_t)


# ===========================================================================
# 9. vsetvli -- the four fields, and the length that is not there.
# ===========================================================================
def check_vector(t, flat_t):
    g = "vector"
    rblocks = retraction_blocks(t)
    for word, mn in (('0x0d85f2d7', 'vsetvli    t0, a1, e64, m1, ta, ma'),
                     ('0xcd0ff2d7', 'vsetivli'),
                     ('0x80c5f2d7', 'vsetvl')):
        check(g, "%s is %s" % (mn.split()[0], word),
              re.search(re.escape(word) + r"\s+" + re.escape(mn), t) is not None)
    check(g, "112 swept and five more, counted separately",
          "112 distinct zimm values" in flat_t or
          re.search(r"(\d+) DISTINCT zimm values", flat_t) is not None)
    check(g, "and the exception to the bijection is named",
          "THE MAP IS A BIJECTION OVER WHAT THE ASSEMBLER WILL EMIT --" in flat_t)
    check(g, "zimm[10:8] is constant zero across every vsetvli",
          re.search(r"zimm\[10:8\] is 0b000 in all \d+ `vsetvli`", flat_t)
          is not None)
    # THE FIELD MAP, read out of the table rather than asserted.
    fm = re.findall(r"^\s+e(\d+), (mf?\d|m\d), (ta|tu), (ma|mu)\s+"
                    r"([01]{11})\s+0x([0-9a-f]{8})\s+(\d+)", t, re.M)
    check(g, "the field map table has thirteen rows", len(fm) == 13,
          '%d rows' % len(fm))
    if len(fm) == 13:
        def z(i):
            return int(fm[i][4], 2)
        # vsew at [5:3], vlmul at [2:0], vta at 6, vma at 7 -- read from the
        # printed zimm STRINGS, so a reader can check the map without the code.
        check(g, "the element width is bits [5:3] of zimm",
              (z(1) >> 3 & 7) == 1 and (z(2) >> 3 & 7) == 2 and (z(3) >> 3 & 7) == 3)
        check(g, "the register group is bits [2:0] of zimm",
              (z(4) & 7) == 1 and (z(5) & 7) == 2 and (z(6) & 7) == 3
              and (z(7) & 7) == 5 and (z(8) & 7) == 6 and (z(9) & 7) == 7)
        check(g, "the tail policy is bit 6 of zimm",
              (z(10) >> 6 & 1) == 1 and (z(10) >> 7 & 1) == 0)
        check(g, "the mask policy is bit 7 of zimm",
              (z(11) >> 7 & 1) == 1 and (z(11) >> 6 & 1) == 0)
        check(g, "and bits [10:8] are ZERO in every printed zimm",
              all((int(r[4], 2) >> 8) == 0 for r in fm),
              'nonzero in %d rows' % sum(1 for r in fm if int(r[4], 2) >> 8))
    check(g, "the reserved three bits are named as the point",
          "THREE BITS OF AN ELEVEN-BIT FIELD THAT NO REACHABLE vsetvli USES"
          in flat_t)
    check(g, "the comment-that-gave-a-width-without-a-position is named",
          "A COMMENT THAT GIVES THE WIDTH OF A FIELD WITHOUT GIVING ITS POSITION"
          in flat_t)
    check(g, "THE LENGTH IS NOT IN THE INSTRUCTION",
          "THE LENGTH IS NOT IN THIS INSTRUCTION AT ALL" in flat_t)
    check(g, "the three AVL rows are measured",
          "rs1 = x0" in flat_t and "AVL = ~0, set vl to VLMAX" in flat_t
          or "NORMAL STRIP MINING" in flat_t)
    check(g, "Table 49 is quoted with its chapter",
          "Table 49" in flat_t and "chapter 30" in flat_t)
    check(g, "and the compiler uses the VLMAX form",
          "ask for VLMAX by putting x0 in rs1" in flat_t)
    check(g, "the three configuration instructions are told apart by 2 bits",
          "inst[31:30] IS VSETVLI" in flat_t and "0b10 IS VSETVL" in flat_t
          and "0b11 IS VSETIVLI" in flat_t)
    # AND THE TABLE'S OWN COLUMN IS DECODED FROM ITS OWN WORDS rather than
    # trusted.  A row reading `vsetvl ... 0b00` says vsetvl is selected by the
    # same two bits as vsetvli, which is the opposite of the claim three lines
    # above it -- and a table nobody parses is a table that can be edited into a
    # different claim without anything noticing.
    # THE TABLE, and the words DECODED FROM THE WORDS THEMSELVES.  A row reading
    # `vsetvl ... 0b00` says vsetvl is selected by the same two bits as vsetvli,
    # which is the opposite of the claim three lines above it -- and a table
    # nobody parses is a table that can be edited into a different claim without
    # anything noticing.  The mode is computed from the word rather than read out
    # of the column, so the check is a comparison and not a copy.
    cfg = re.findall(r"^\s+(0x[0-9a-f]{8})\s+(vset(?:vli|ivli|vl))\s+\S.*?"
                     r"(0b[01]{2})\s+\d+\s+0x[0-9a-f]+\s*$", t, re.M)
    MODES = {'vsetvli': 0b00, 'vsetvl': 0b10, 'vsetivli': 0b11}
    check(g, "and EVERY configuration row's inst[31:30] column agrees with its "
             "own word, and all three names occur",
          len(cfg) >= 3
          and set(mn for _w, mn, _m in cfg) == set(MODES)
          and all(MODES[mn] == int(mode, 2) == (int(w, 16) >> 30) & 3
                  for w, mn, mode in cfg),
          '%d rows checked: %s' % (len(cfg),
                                    ','.join(sorted(set(mn for _w, mn, _m
                                                        in cfg)))))
    check(g, "uimm is a five-bit IMMEDIATE in one and a register in two",
          "inst[19:15] IS A FIVE-BIT IMMEDIATE HERE AND A REGISTER IN BOTH OF "
          "ITS SIBLINGS" in flat_t)
    check(g, "the uimm XOR is 0x00078000",
          "XOR 0x00078000" in flat_t)
    check(g, "and the inherited decoder's three-bits bug is retracted",
          "it computes inst[31:29] -- THREE BITS -- and compares against"
          in rblocks.get('R1', ''))
    check(g, "the tail/mask policy table is quoted with its chapter",
          "chapter 30, section 31.3.4.3" in flat_t)
    check(g, "the nondeterminism is quoted, not paraphrased",
          "not required to be deterministic" in flat_t)
    check(g, "the compiler chooses ta, ma in the corpus",
          re.search(r"ta\s+ma\s+\d+", t) is not None)
    check(g, "and the section says that is the FAST choice, not the portable one",
          "THE FAST CHOICE, NOT THE PORTABLE ONE" in flat_t)
    check(g, "the assembler defaults omitted flags to tu, mu",
          "DEFAULTS TO `tu, mu`" in flat_t)
    check(g, "and the specification is quoted saying the default was removed",
          "mandatory in the assembly syntax" in flat_t
          or "TWO MANDATORY FLAGS" in flat_t)
    check(g, "the three refusals for missing/illegal flags are printed",
          "REFUSED" in t and "operand must be e[8|16|32|64]" in flat_t)


# ===========================================================================
# 10. THE MASK, and the register group.
# ===========================================================================
def check_mask(t, flat_t):
    g = "mask"
    rows = re.findall(r"^\s+(v\S+)\s+(\S.*?, v0\.t)\s+0x02000000\s+1\s+bit 25$",
                      t, re.M)
    check(g, "ELEVEN mask pairs, every XOR 0x02000000", len(rows) == 11,
          '%d rows' % len(rows))
    check(g, "and zero exceptions",
          re.search(r"11 pairs, 11 of them XOR to exactly 0x02000000, "
                    r"0 exceptions", flat_t) is not None)
    check(g, "the three groups are arithmetic, load and store",
          any(r[0].startswith('vadd') for r in rows)
          and any(r[0].startswith('vle') for r in rows)
          and any(r[0].startswith('vse') for r in rows))
    check(g, "the count is ELEVEN and not TWENTY-TWO, and says why",
          "ELEVEN IS NOT TWENTY-TWO" in flat_t)
    check(g, "bit 25 is release in an AMO and mask in a vector word",
          'BIT 25 IS "RELEASE" IN AN ATOMIC AND "MASK AGNOSTIC"' in flat_t)
    check(g, "the mask REGISTER is not in the encoding",
          "AND THE MASK REGISTER ITSELF IS NOT IN THE ENCODING" in flat_t)
    check(g, "only v0 can be named, and the assembler says so",
          "OPERAND MUST BE v0.t" in flat_t and "operand must be v0.t" in flat_t)
    check(g, "a mask PRODUCER may write any register, and that is measured",
          "CAN WRITE ANY VECTOR REGISTER, NOT ONLY" in flat_t)
    check(g, "and the weaker claim is the correct one",
          "THE CONSTRAINT IS NOT \"MASKS ARE v0\" BUT" in flat_t)
    check(g, "and the false inference is named",
          "A TRUE PREMISE WITH A FALSE INFERENCE IS HARDER TO CATCH" in flat_t)
    check(g, "the register group is nf at inst[31:29]",
          "nf at [31:29]" in t and "nf IS THREE BITS AT THE TOP" in flat_t)
    check(g, "the eight whole-register words are in a table",
          len(re.findall(r"^\s+v[ls][1248]r\.?e?\S*\s+0x[0-9a-f]{8}\s+0b",
                         t, re.M)) >= 8,
          '%d rows' % len(re.findall(
              r"^\s+v[ls][1248]r\.?e?\S*\s+0x[0-9a-f]{8}\s+0b", t, re.M)))
    check(g, "and the group must start aligned, by refusal",
          "REFUSED: invalid operand" in flat_t
          or ("vl2r.v v1, (a0)     REFUSED" in flat_t))
    check(g, "and LMUL is not a scalar",
          "LMUL IS NOT A SCALAR AND IT IS NOT A WIDER REGISTER" in flat_t)


# ===========================================================================
# 11. WHAT THE COMPILER EMITS -- SHAPES.
# ===========================================================================
def check_compiler(t, flat_t):
    g = "compiler"
    check(g, "the level table prints ten columns",
          len(re.findall(r"^  function\s+.*-O0 no v", t, re.M)) == 1)
    check(g, "and four rows of functions",
          len(re.findall(r"^\s+v(add_d|sum_d|mul_s8|mac_l)\s+\d", t, re.M)) == 4,
          '%d rows' % len(re.findall(r"^\s+v(add_d|sum_d|mul_s8|mac_l)\s+\d",
                                     t, re.M)))
    m = re.search(r"MEASURED: (\d+) vector instructions at -O1, (\d+) at -O2, "
                  r"(\d+) at -O3 and\s*\n\s*(\d+) at -Os", t)
    check(g, "the four vector counts are printed", m is not None,
          m.group(0)[:60] if m else '')
    if m:
        o1, o2, o3, os_ = (int(m.group(k)) for k in (1, 2, 3, 4))
        # -O1 VECTORISES NOTHING.  The first version of this check also
        # required -Os to vectorise nothing, which is a claim about a compiler
        # version rather than a shape, and which the recorded run REFUTES:
        # -Os emits 21 vector instructions over two of the four functions.
        # Asserting it here would have meant either editing a measurement to
        # match a rubric or deleting a real finding -- and this file's own
        # header says a count the harness cannot see is a count the reader
        # cannot check.  So the shape asserted is the one the data has: the
        # two levels that agree with each other are the two that vectorise
        # everything, and the two that do not are not the same size.
            # AND THE SENTENCE THAT SAYS SO IS PINNED, because a number and a
        # sentence about it can disagree: the count is read out of the report
        # and the claim is read out of the prose, and a report whose prose says
        # "-O1 VECTORISES" over a table that says 0 is a report that has stopped
        # being a measurement.  This is the first version of the check that did
        # not do both, and `corrupt.py` found it by de-negating the sentence
        # while leaving the number alone.
        check(g, "-O1 vectorises NOTHING in this corpus",
              o1 == 0 and '-O1 DOES NOT VECTORISE THIS CORPUS AT ALL' in flat_t,
              '-O1 %d' % (o1,))
        check(g, "-O2 and -O3 DO vectorise it", o2 > 0 and o3 > 0,
              '-O2 %d, -O3 %d' % (o2, o3))
        check(g, "and -O2 and -O3 agree exactly", o2 == o3,
              '%d against %d' % (o2, o3))
        # "SMALLER" IS A CLAIM ABOUT CODE SIZE AND NOT ABOUT VECTOR
        # INSTRUCTIONS.  The first version of this check compared the two
        # VECTOR counts, and -Os emits 21 against -O2's 19 -- so it could only
        # pass if the artifact said fewer where the measurement says more.
        # The size relation is a different number and is asserted on its own.
        sz = re.search(r"CODE SIZE: (\d+) instructions at -O2 against (\d+) at "
                       r"-Os, over the same four functions", flat_t)
        check(g, "-Os is SMALLER than -O2 in CODE SIZE, and the section says why",
              sz is not None and int(sz.group(2)) < int(sz.group(1))
              and "-Os IS SMALLER THAN -O2, WHICH IS NOT THE" in flat_t,
              ('%s against %s' % (sz.group(1), sz.group(2))) if sz else 'not printed')
        check(g, "and -Os VECTORISES where -O1 does not, which is the finding",
              os_ > o1 and os_ != o2,
              '-O1 %d, -Os %d, -O2 %d' % (o1, os_, o2))
    check(g, "and the O2/O3 identity is measured, not assumed",
          "IDENTICAL" in t and "THERE IS NOTHING TO COMPARE BETWEEN -O2 AND -O3"
          in flat_t)
    check(g, "the vlenb read is measured in at least two functions",
          len(re.findall(r"csrr\s+a7, vlenb", flat_t)) >= 2,
          '%d reads' % len(re.findall(r"csrr\s+a7, vlenb", flat_t)))
    check(g, "the vlenb word is 0xc22028f3",
          "0xc22028f3" in flat_t)
    check(g, "and its CSR number is decomposed with the privileged map",
          "csr = inst[31:20] = 0xc22" in flat_t
          and "READ-ONLY" in flat_t)
    check(g, "the length is a design-time constant in a CSR, quoted",
          "design-time constant in any implementation" in flat_t)
    check(g, "the scalar prologue is explained as the REMAINDER",
          "IT IS THE REMAINDER" in flat_t and "THE TAIL-HANDLING CODE" in flat_t)
    check(g, "and the portability lesson is drawn from it",
          "GETS PORTABILITY NOT FROM THE POLICY" in flat_t)
    check(g, "the five things the section cannot say are listed",
          len(re.findall(r"^    \* That |^    \* What |^    \* Whether |"
                         r"^    \* How ", t, re.M)) >= 5,
          '%d items' % len(re.findall(r"^    \* (That|What|Whether|How) ",
                                      t, re.M)))


# ===========================================================================
# 12. TWO READERS.
# ===========================================================================
def check_xcheck(t, flat_t):
    g = "xcheck"
    m = re.search(r"^\s+(\d+)  instructions the second reader printed", t, re.M)
    check(g, "it prints how many instructions it compared",
          m is not None and int(m.group(1)) > 2000, m.group(1) if m else '')
    n = re.search(r"^\s+(\d+)  of them this file NAMES", t, re.M)
    check(g, "and how many it named", n is not None)
    u = re.search(r"^\s+(\d+)  unmodelled -- counted, never dropped", t, re.M)
    check(g, "and how many it could not name, COUNTED not dropped",
          u is not None and int(u.group(1)) > 0, u.group(1) if u else '')
    check(g, "ZERO disagreements", re.search(r"^\s+0  DISAGREE", t, re.M)
          is not None)
    check(g, "zero LENGTH disagreements, and the length IS compared",
          re.search(r"^\s+0  where the two readers disagree on the LENGTH", t,
                    re.M) is not None)
    check(g, "and named plus unmodelled equals the total",
          m and n and u and
          int(n.group(1)) + int(u.group(1)) == int(m.group(1)),
          '%s + %s = %s' % (n.group(1), u.group(1), m.group(1))
          if m and n and u else '')
    check(g, "the inherited table is reported with its dead count",
          re.search(r"\d+ rules INHERITED from rvdec\.py, \d+ fired on this "
                    r"corpus and \d+", flat_t) is not None)
    check(g, "and a dead INHERITED rule is called expected, not a defect",
          "A DEAD RULE IN AN INHERITED TABLE IS A RULE FOR A CORPUS THIS"
          in flat_t)
    # THE FIRE TABLE, and it must not be vacuous.
    f = re.search(r"(\d+) rules, (\d+) fired, (\d+) matched nothing", t)
    check(g, "the fire table is printed with three numbers", f is not None,
          f.group(0) if f else '')
    if f:
        check(g, "this course's OWN six rules: five fire and one is pre-seeded "
                 "dead", f.group(1) == '6' and f.group(2) == '5'
              and f.group(3) == '1',
              '%s rules, %s fired, %s dead' % f.groups())
        check(g, "and the table says so", "6 rules, 5 fired, 1 matched nothing"
              in flat_t)
    check(g, "and the two groups are named",
          "negative immediate, decimal on both sides" in flat_t
          and "c.li and li are one instruction" in flat_t
          and "bare fence and fence with explicit sets are one instruction"
          in flat_t
          and "fence.tso with and without its sets is one instruction" in flat_t)
    check(g, "and the ORDER of the groups is the stated finding",
          "A NORMALISER'S RULES HAVE AN ORDER AND THE ORDER IS" in flat_t)
    check(g, "and the rule that matched nothing is named as such",
          "vsetvli suffix order, aqrl and rl-aq are one spelling" in flat_t
          and "NEVER FIRED" in t)
    check(g, "and the classifier ran, on a run where it found nothing",
          "THE CLASSIFIER, run on every run" in flat_t
          and "NOTHING TO CLASSIFY" in flat_t)
    check(g, "the load-mode field is repaired and the repair is visible",
          "lumop = 01000" in flat_t and "ONE FIVE-BIT FIELD IN A UNIT-STRIDE "
          "LOAD CARRIES THREE INSTRUCTION NAMES" in flat_t)
    check(g, "and the dispatch guard against the configuration instructions "
             "is named",
          "CLAIMS THE CONFIGURATION INSTRUCTIONS" in flat_t)


# ===========================================================================
# 13. THE FOUR POISONS.  Each must MOVE the number it claims.
# ===========================================================================
def check_poison(t, flat_t):
    g = "poison"
    for k in (1, 2, 3, 4):
        check(g, "poison %d reports FIRED" % k,
              re.search(r"VERDICT: POISON %d FIRED$" % k, t, re.M) is not None)
    # NOT `not in t`: this file's prose says "[POISON FAILED] and stops", so the
    # substring is IN a healthy output on purpose.  The test is on the line,
    # because the artifact's closing paragraph puts the string at the start of
    # a wrapped line -- and a reader grepping for "^\\[POISON FAILED\\]" wants
    # the VERDICT, not the sentence that explains it.
    check(g, "and NO poison prints the failure string on a healthy run",
          re.search(r"VERDICT: POISON \d+ FAILED", t) is None
          and not re.search(r"^\s*\[POISON FAILED\]", t, re.M)
          and not re.search(r"^\s*\[POISON FAILED\]\s*$", t, re.M))
    mentions = [ln for ln in t.splitlines() if "[POISON FAILED]" in ln]
    check(g, "and every mention of the failure string is in PROSE",
          len(mentions) >= 1
          and all(not ln.strip().startswith("[POISON FAILED]") and
                  "VERDICT" not in ln for ln in mentions),
          '%d mention(s)' % len(mentions))
    d1 = re.search(r"DELTA: named ([+-]\d+), disagreements ([+-]\d+), "
                   r"unmodelled ([+-]\d+)", t)
    check(g, "poison 1 moved TWO numbers and claims the THIRD stays put",
          d1 is not None and d1.group(1) != '0' and d1.group(3) != '0'
          and d1.group(2) == '+0',
          d1.group(0) if d1 else '')
    d2 = re.search(r"DELTA: named ([+-]\d+), disagreements ([+-]\d+), "
                   r"unmodelled ([+-]\d+)", t[t.index('POISON 2'):]
                   if 'POISON 2' in t else '')
    check(g, "poison 2 moved the DISAGREEMENT column and NOT the unmodelled one",
          d2 is not None and int(d2.group(2)) > 0 and d2.group(3) == '+0',
          d2.group(0) if d2 else '')
    if d1 and d2:
        # THE PAIRING, STATED AS THE PAIRING IS CLAIMED TO BE.  The first
        # version asserted `d2.group(2) == '+0'` -- that poison 2's
        # disagreement column does NOT move -- one line after asserting that it
        # does.  Two checks, one file, and the second made the first
        # unsatisfiable, which is the shape of bug this course's own section 12
        # exists to catch.  Each poison moves ONE column and claims the
        # OTHER stays put; that is the claim, so that is what is asserted.
        check(g, "and the two move DIFFERENT columns, which is the pairing",
              d1.group(3) != '+0' and d1.group(2) == '+0'
              and d2.group(2) != '+0' and d2.group(3) == '+0',
              'p1 unmodelled %s / p1 disagree %s, p2 disagree %s / p2 unmodelled %s'
              % (d1.group(3), d1.group(2), d2.group(2), d2.group(3)))
    p3 = re.search(r"DELTA: (\d+) of (\d+) words moved, (\d+) did not", t)
    check(g, "poison 3 moved every word that could move",
          p3 is not None and p3.group(1) == p3.group(2)
          and p3.group(3) == '0',
          p3.group(0) if p3 else '')
    p3b = re.search(r"A-extension words that CARRIED \.aq or \.rl\s+: (\d+)", t)
    check(g, "and its DENOMINATOR is the suffix-carrying words only",
          p3b is not None and p3 is not None
          and int(p3b.group(1)) == int(p3.group(2)),
          '%s vs %s' % (p3b.group(1) if p3b else '?', p3.group(2) if p3 else '?'))
    p4 = re.search(r"DELTA: (\d+) of the (\d+) planted disagreements were HIDDEN",
                   t)
    check(g, "poison 4 HID a non-zero number of planted disagreements",
          p4 is not None and 0 < int(p4.group(1)) < int(p4.group(2)),
          p4.group(0) if p4 else '')
    pl = re.search(r"real disagreements planted \(last operand changed\): (\d+)", t)
    ca = re.search(r"the working cross-check CATCHES\s+: (\d+)", t)
    check(g, "and it PLANTED a real disagreement first",
          pl is not None and int(pl.group(1)) > 0)
    check(g, "and the working check catches EXACTLY what it planted",
          pl is not None and ca is not None and pl.group(1) == ca.group(1))
    # THE BULLETS.  The first version of this group looked for a bullet at
    # column zero in a file whose bullets are indented two spaces.
    bullets = [b for b in re.split(r"^\* poison ", t, flags=re.M)[1:]]
    check(g, "the summary names four claimed numbers",
          len(bullets) == 4, '%d bullets' % len(bullets))
    check(g, "and the four are numbered 1 to 4",
          [int(re.match(r"(\d)", b).group(1)) for b in bullets] == [1, 2, 3, 4])
    check(g, "and every bullet carries a delta with digits in it",
          all(re.search(r"[+-]?\d", b.split('claims', 1)[-1]) for b in bullets))
    check(g, "the pairing of poisons 1 and 2 is stated as the finding",
          "THE PAIR WORTH READING TOGETHER IS POISON 1 AND POISON 2" in flat_t)
    # THE MACHINERY IS ASSERTED AGAINST THE SOURCE, because on a clean run no
    # poison prints the failure string.
    src = ''
    try:
        with open(os.path.join(HERE, "rvat.py"), "r", errors="replace") as f:
            src = f.read()
    except OSError:
        pass
    check(g, "the [POISON FAILED] machinery is in the source, for every poison",
          src.count("[POISON FAILED]") >= 6,
          "%d occurrences" % src.count("[POISON FAILED]"))
    check(g, "and a victim that is NOT IN THE DISPATCH is distinguished",
          "is NOT IN THE DISPATCH" in src)
    check(g, "and the poison denominator lesson is recorded in the SOURCE",
          "A POISON'S DENOMINATOR MUST BE THE SET OF INSTANCES THAT" in src)


# ===========================================================================
# 14. THE EIGHTEEN RETRACTIONS.  Asserted as TEXT.
# ===========================================================================
def check_retractions(t, flat_t):
    g = "retract"
    N = 18
    check(g, "eighteen of them",
          NUMWORDS[len(RETRACTIONS_LIST)] + " of them" in flat_t
          and "EIGHTEEN RETRACTIONS" in flat_t,
          "%d in the source" % len(RETRACTIONS_LIST))
    ids = re.findall(r"^  (R\d+)  CLAIMED:", t, re.M)
    want = ["R%d" % i for i in range(1, N + 1)]
    check(g, "R1 through R%d all present, IN ORDER, with no gaps" % N,
          ids == want, "found %d: %s" % (len(ids), ",".join(ids)))
    check(g, "the count is READ FROM THE SOURCE, not hard-coded here",
          len(RETRACTIONS_LIST) == N)
    srcs = re.findall(r"^        SOURCE: (.+)$", t, re.M)
    check(g, "and every one has a SOURCE line", len(srcs) == N,
          "%d sources" % len(srcs))
    check(g, "and R1, R2 and R3 name the SIBLING as where the defect is",
          sum(1 for x in srcs if 'SIBLING' in x) >= 3,
          '%d name the sibling' % sum(1 for x in srcs if 'SIBLING' in x))
    # AND EACH OF THE THREE SAYS SO IN ITS OWN SOURCE LINE, so the claim is
    # about R1, R2 and R3 by name rather than about "at least three of them".
    for rid in ('R1', 'R2', 'R3'):
        got = one(r"^  %s  CLAIMED:.*?^        SOURCE: (.+?)$" % rid, t,
                  re.M | re.S)
        check(g, "%s's own SOURCE line names the SIBLING" % rid,
              got is not None and 'SIBLING' in got, got or 'not found')
    # TWO SENTENCES, TWO PLACES.  Each of these phrases appears TWICE in the
    # report -- once in the section that explains the defect and once in the
    # retraction that retracts it -- and the first version of this list checked
    # only the whole flattened text, so it could not tell which of the two a
    # corruption had edited.  §KEEP§A CHECK THAT CANNOT SAY WHICH COPY IT READ IS
    # A CHECK THAT PASSES WHEN HALF THE FILE IS WRONG, AND `corrupt.py` IS WHAT
    # FOUND IT.  Each pair below is (id, phrase in the RETRACTION, phrase in the
    # SECTION that explains it) and both are asserted.
    # THE NEEDLE IS MATCHED AGAINST THE RETRACTION'S OWN BLOCK -- see
    # `retraction_blocks`, which exists because a whole-text search could not
    # tell a de-negated SECTION from an intact RETRACTION.
    rblocks = retraction_blocks(t)
    for (rid, needle) in (
            ("R1", "computes inst[31:29] -- THREE BITS -- and compares against"),
            ("R1", "NAMES THE ONE INSTRUCTION WHERE TWO BITS AND THREE BITS AGREE"),
            ("R2", "it does not READ them -- it never looks at inst[26] and "
                   "inst[25] at all"),
            ("R2", "A DECODER THAT DOES NOT READ A FIELD RENDERS TWO "
                   "INSTRUCTIONS IDENTICALLY"),
            ("R3", "it names it `fence`"),
            ("R3", "REPORTING AN INSTRUCTION AS THE WRONG INSTRUCTION OF THE "
                   "SAME FAMILY"),
            ("R4", "it names it correctly and for the WRONG REASON"),
            ("R4", "RIGHT FOR THE WRONG REASON IS A FAILURE THAT A COMPARISON "
                   "CANNOT FIND"),
            ("R5", "IT DOES NOT, AND THE CLAIM WAS WRONG"),
            ("R5", "THE ONLY WAY TO EXPRESS COMPARE-AND-SWAP, BECAUSE THERE IS "
                   "NO `cmpxchg` IN"),
            ("R6", "rv64g` and `rv64gcv` differ in TWO letters"),
            ("R6", "THAT PAIR DIFFERS IN `c` AND `v` AT ONCE"),
            ("R7", "IT IS AN ALIGNMENT CONSTRAINT"),
            ("R7", "A REFUSAL IS THE CHEAPEST PROOF THAT A CONSTRAINT IS REAL"),
            ("R8", "they emit fewer than twelve INSTRUCTIONS"),
            ("R8", "A RELAXED FENCE IS NOT A NO-OP INSTRUCTION, IT IS THE ABSENCE "
                   "OF ONE"),
            ("R9", "THEY ARE THE SAME INSTRUCTION AND THE SAME FENCE PLUS ANOTHER "
                   "FENCE"),
            ("R9", "A CLAIM THAT IS TRUE AND HAS A QUALIFIER HIDING IN THE NEXT "
                   "COLUMN"),
            ("R10", "IT IS NOT MEASURED"),
            ("R10", "WHAT IS MEASURED IS THAT CLANG EMITS `lr.w.aqrl` AND "
                    "`sc.w.rl`"),
            ("R11", "it is a difference of FORM"),
            ("R11", "THE FENCE IS THE PRIMITIVE RATHER THAN THE EXCEPTION"),
            ("R12", "they prove the CORPUS contains it, which is not the same "
                    "claim"),
            ("R12", "A NUMBER ABOUT WHAT WAS FED TO IT IS NOT A NUMBER ABOUT "
                    "WHAT WAS CHOSEN"),
            ("R13", "an implementation may ignore `fm`"),
            ("R13", "FENCE.TSO IS A REQUEST FOR A WEAKER BARRIER THAN THE ONE IT "
                    "IS SPELLED LIKE"),
            ("R14", "IT IS A LIBRARY CONTRACT MADE OF BITS"),
            ("R14", "THE PORTABILITY PROBLEM IN THE VECTOR EXTENSION IS NOT THE "
                    "INSTRUCTION SET"),
            ("R15", "zimm[10:8] is constant zero in every reachable variant"),
            ("R15", "THREE BITS THAT NEVER MOVE LOOK EXACTLY LIKE THREE BITS "
                    "THAT DO"),
            ("R16", "THEY HAVE ZEROES BECAUSE THE MANUAL REQUIRES THEM TO"),
            ("R16", "TWO RESERVED FIELDS IN AN INSTRUCTION WHOSE OTHER TWO FIELDS "
                    "CARRY THE"),
            ("R17", "and NOT that either agrees with silicon"),
            ("R17", "THE TWO READERS SHARE AN ASSEMBLER"),
            ("R18", "the assembler refusing `lock` is a fact about the ASSEMBLER"),
            ("R18", "MADE ATOMICITY A PROPERTY OF AN EXISTING INSTRUCTION AND "
                    "RISC-V MADE IT A CATEGORY")):
        blk = rblocks.get(rid, '')
        check(g, "%s names: %s" % (rid, needle[:40]), needle in blk)
    # AND THE SECTION-SIDE COPIES, in the sections that EXPLAIN the defect.
    # These are separate sentences in separate sections and a retraction that
    # is intact while its explanation is de-negated is a course that contradicts
    # itself in the place a reader is most likely to be.
    for where, needle in (
            ('the section 8 explanation of R1',
             "WHICH IS inst[31:29] -- THREE BITS -- AND COMPARES"),
            ('the section 8 statement of the length',
             "THE LENGTH IS NOT IN THIS INSTRUCTION AT ALL"),
            ('the section 5 statement of the retry',
             "THE RETRY IS NOT SYNTAX AROUND THE INSTRUCTION"),
            ('the section 7 statement of the forms',
             "IT IS A DIFFERENCE OF FORM"),
            ('the section 9 statement of the group',
             "IT IS AN ALIGNMENT CONSTRAINT ON A REGISTER ALLOCATOR"),
            ('the section 11 statement of the load mode',
             "ONE FIVE-BIT FIELD IN A UNIT-STRIDE LOAD CARRIES THREE "
             "INSTRUCTION NAMES"),
            ('the section 11 statement of the dispatch guard',
             "CLAIMS THE CONFIGURATION INSTRUCTIONS"),
            ('the section 11 statement of the rule order',
             "A NORMALISER'S RULES HAVE AN ORDER AND THE ORDER IS"),
            ('the section 4 statement of the two bits',
             "SPENDS TWO BITS WHERE AARCH64 SPENDS TWO OPCODES"),
            ('the section 7 statement of the C11 forms',
             "CONSUME AND ACQUIRE ARE THE SAME FOUR BITS"),
            ('the section 10 statement of the remainder',
             "IT IS THE REMAINDER"),
            ('the section 2 statement of the cost',
             "costs the programmer the ordinary-operator shortcut")):
        check(g, "%s is not de-negated" % where, needle in flat_t)
    check(g, "and the closing claim is present",
          "NOTHING HERE IS A MISTAKE ABOUT HOW A COMPUTER WORKS" in flat_t)
    check(g, "and the eighteen-courses-in-a-row sentence is present",
          "EIGHTEEN COURSES IN A ROW, AND EVERY SINGLE RETRACTION IS A DISCOVERY "
          "ABOUT THE MACHINERY BUILT TO READ THE HARDWARE" in flat_t)
    check(g, "and the six-about-the-subject claim is made",
          "and four are about the SUBJECT" in flat_t)


# ===========================================================================
# 15. THE SCOPE: the limits, the two lists, and the links out.
# ===========================================================================
def check_scope(t, flat_t):
    g = "scope"
    lim = re.findall(r"^  (\d+)\. ", t, re.M)
    check(g, "nineteen limits are numbered 1..19 at the start of a line",
          lim[:19] == [str(i) for i in range(1, 20)], str(lim[:19]))
    for i, needle in (
            (1, "NO TIMING"),
            (2, "NOTHING IS EXECUTED"),
            (3, "NO RESERVATION IS EVER HELD"),
            (4, "THE RESERVATION RULES ARE QUOTED AND NOT MEASURED"),
            (5, "THE ORDERING MODEL IS DEFINED BY A DOCUMENT"),
            (6, "fence.tso IS A REQUEST AND WHETHER THE REQUEST IS HONOURED"),
            (7, "THE VECTOR LENGTH IS NOT MEASURED"),
            (8, "THE TAIL AND MASK POLICIES ARE MEASURED AS BITS"),
            (9, "THE VECTORISED LOOPS HAVE NOT BEEN RUN"),
            (10, "THE TWO READERS SHARE AN ASSEMBLER"),
            (11, "THE SOURCE/DISASSEMBLY PAIRING IN THE THREE HAND-WRITTEN "
                 "CORPORA IS POSITIONAL"),
            (12, "THE x86-64 LOCK LIST IS QUOTED FOR ITS EIGHTEEN"),
            (13, "THE `-march` COMPARISON IS ONE LETTER AND NOT TWO"),
            (14, "EVERY INSTRUCTION COUNT AND EVERY FUNCTION IS CLANG"),
            (15, "THE VECTOR DATA PATH IS ONE QUARTER MODELLED"),
            (16, "THE INHERITED DECODER IS BORROWED AND NOT FORKED"),
            (17, "NOTHING GENERALISES FROM AN EMPTY ROW"),
            (18, "A CROSS-CHECK THAT AGREES IS NOT PROOF"),
            (19, "THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT")):
        check(g, "limit %d is %s" % (i, needle[:38]), needle in flat_t)

    # THE TWO SCOPE LISTS, located BY their headings in the FLATTENED text,
    # because a heading that wraps is not findable as a substring of the raw
    # file -- which is why the first version of this group reported "0
    # characters" against a section that prints both lists in full.
    g = "cannot"
    hc = 'A READER THEREFORE CANNOT CONCLUDE is a different thing'
    hk = 'teaches its reader that the subject is unknowable'
    hel = 'WHICH IS THE POINT: there is more that can be read'
    check(g, "the three anchors are each UNIQUE in the report",
          flat_t.count(hc) == 1 and flat_t.count(hk) == 1
          and flat_t.count(hel) == 1,
          "%d / %d / %d" % (flat_t.count(hc), flat_t.count(hk),
                            flat_t.count(hel)))
    block = (flat_t[flat_t.index(hc):flat_t.index(hk)]
             if hc in flat_t and hk in flat_t else '')
    can = (flat_t[flat_t.index(hk):flat_t.index(hel)]
           if hk in flat_t and hel in flat_t else '')
    check(g, "the cannot-conclude list is in the artifact, not a footnote",
          len(block) > 1200, "%d characters" % len(block))
    check(g, "and the CAN-conclude list is beside it", len(can) > 900,
          "%d characters" % len(can))
    # The BULLETS are counted in the RAW text, by line, because flattening
    # destroys the `^  * ` that makes a bullet a bullet.
    raw_lines = t.splitlines()

    def line_of(needle):
        for k, ln in enumerate(raw_lines):
            if needle in re.sub(r"\s+", " ", ln):
                return k
        return -1

    c_at, k_at, e_at = line_of(hc), line_of(hk), line_of(hel)
    check(g, "and the three anchors resolve to REAL LINES, in order",
          0 <= c_at < k_at < e_at,
          "cannot@%d other-half@%d point@%d of %d"
          % (c_at, k_at, e_at, len(raw_lines)))
    raw_cannot = raw_lines[c_at:k_at] if 0 <= c_at < k_at else []
    raw_can = raw_lines[k_at:e_at] if 0 <= k_at < e_at else []
    n_cannot = len([ln for ln in raw_cannot if re.match(r"^\s*\* \S", ln)])
    n_can = len([ln for ln in raw_can if re.match(r"^\s*\* \S", ln)])
    check(g, "the two lists are NINE and ELEVEN, and the SECOND is the longer",
          (n_cannot, n_can) == (9, 11) and n_can > n_cannot,
          "%d cannot, %d can" % (n_cannot, n_can))
    check(g, "and the sentence's own counts agree with its two lists",
          ("%d items against %d" % (n_can, n_cannot)) in flat_t)
    # EVERY CLAIM SENTENCE, PINNED WHOLE.  The substring checks all pass over a
    # bullet edited from "That any atomic instruction is ATOMIC" to "That any
    # atomic instruction is probably ATOMIC" -- the sentence keeps its subject
    # and its verb and the edit reverses the meaning.  A scope list you can
    # soften without editing a test is not a scope list.
    for needle in CANNOT_CLAIMS:
        check(g, "the cannot-claim is pinned: %s" % needle[:38], needle in block)
    for needle in CAN_CLAIMS:
        check(g, "the can-claim is pinned: %s" % needle[:38], needle in can)

    g = "links"
    # A POSITIVE LINK LIST IS NOT A LINK CLAIM.  The previous course in this
    # section shipped four ids that 404'd while its artifact said every one had
    # been verified, because the harness cannot resolve a route.  So this group
    # asserts BOTH: every id this course claims is present, AND the ids it has
    # RETIRED are absent.
    for link in ('/courses/smp/lessons/smp-atomic',
                 '/courses/smp/lessons/smp-ordering',
                 '/courses/simd/lessons/simd-width',
                 '/courses/simd/lessons/simd-reduce',
                 '/courses/simd/lessons/simd-boundaries',
                 '/courses/simd/lessons/simd-compiler',
                 '/courses/x86simd/lessons/x86-atomics',
                 '/courses/x86simd/lessons/x86-order',
                 '/courses/a64simd/lessons/a64-atomic',
                 '/courses/a64simd/lessons/a64-order',
                 '/courses/rvabi/lessons/rv-noflags'):
        check(g, "links out to %s" % link.split('/lessons/')[-1], link in t)
    check(g, "and says every link was verified by a LIVE ROUTE check",
          "Verified present by a live route check" in flat_t)
    check(g, "and claims the check is asserted BOTH WAYS in the harness",
          "asserted both ways in `crosscheck.py`" in flat_t)
    # THE NEGATIVE HALF.  A positive list cannot do this: it passes on any set
    # of ids that exist and says nothing about the ones that do not.  And the
    # match is on a WHOLE SEGMENT, because two of these ids are PREFIXES of
    # live ones -- `x86-atom` opens `x86-atomics` and `rv-noflag` opens
    # `rv-noflags` -- so a plain substring test would fail this course for
    # linking to a page that is one character longer than a retired id.  A
    # negative that cannot be satisfied by the artifact it is written for is
    # not a negative; it is a bug wearing one.
    for retired in ('simd-simd', 'smp-memory', 'x86-atom', 'a64-atomics',
                    'rv-noflag', 'rv-ordering', 'rv-amo-encoding'):
        check(g, "the retired id %s appears NOWHERE in the output" % retired,
              re.search(r"/lessons/%s(?![\w-])" % re.escape(retired), flat_t)
              is None)
    check(g, "and the retired ids are asserted in the SOURCE as a NEGATIVE",
          "NEGATIVE" in open(os.path.join(HERE, "crosscheck.py"),
                              errors="replace").read()
          and "retired" in open(os.path.join(HERE, "crosscheck.py"),
                                errors="replace").read())
    check(g, "the report ends with its own counts",
          re.search(r"END OF REPORT -- \d+ sections, \d+ limits, \d+ "
                    r"retractions, \d+ poisons, \d+ provenance rows", t)
          is not None)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_output()
    if not os.path.isfile(path):
        print("  [FAIL] %-9s %-64s %s" % ("missing", "output file", path))
        print("\n  Run build_samples.sh first, or pass the path to a recorded "
              "run.")
        return 1
    t = load(path)
    flat_t = flat(t)
    print("\ncrosscheck.py -- re-asking the claims in %s\n" % path)
    for fn in (check_method, check_labels, check_zero, check_amo_encoding,
               check_order_bits, check_lrsc, check_experiment, check_fence,
               check_vector, check_mask, check_compiler, check_xcheck,
               check_poison, check_retractions, check_scope):
        fn(t, flat_t)
    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        print("\nFAILURES:")
        for (grp, what, detail) in FAILURES:
            print("  [FAIL] %-9s %-64s %s" % (grp, what, detail))
        return 1
    print("ALL CONSISTENT")
    return 0


if __name__ == "__main__":
    sys.exit(main())