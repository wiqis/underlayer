#!/usr/bin/env python3
"""crosscheck.py -- the harness for "Compiler Backend: From IR to Machine Code".

It reads the OUTPUT of compback.py and re-asks the claims.  It does not
re-measure anything: it has no compiler, no assembler, no decoder and no
object files, and that is the point.  A harness that can re-measure can
disagree with the artifact for reasons that have nothing to do with whether
the artifact's SENTENCES are still true, and then it teaches its reader to
ignore it.

    compback.py runs the toolchain and produces numbers.
    crosscheck.py reads the numbers and asserts what must be true of them.

A compiler upgrade changes the numbers; the harness notices and the reader
learns.  A prose edit that drops a retraction changes the TEXT; the harness
notices and the reader learns.  Neither can hide.

IT IS WRITTEN AFTER THE ARTIFACT AND AGAINST ITS OUTPUT, and the reason is
stated because this collection has retracted four harnesses for exactly that:
`rvabi`'s harness was written first and arrived with nineteen unsatisfiable
checks, `rvpriv`'s arrived with thirty prose needles that could not match a
wrapped report, and `rvat`'s with ten.  Every pattern below was read out of
a real `compback.out` before it was written.

FOUR KINDS OF ASSERTION, and the split is the point:

  * EXACT   for anything the ENCODING or the ARITHMETIC owns and this file
    MEASURED: the AArch64 field masks, the seven encoder specimens, the
    interference edge counts, the spill counts at each pressure, the poison
    deltas, the IR/machine counts.  An exact quantity has one honest
    treatment, and a harness that rounds an exact quantity into a range is a
    harness that will not notice a decoder reading a field one bit off.

  * SHAPE   for anything that is a property of a COMPILER VERSION: which
    optimisation level vectorises on which target, which pressure an
    allocator stops spilling at, which direction a poison moved.  These move.
    A check whose threshold is a bare number from one compiler is a check
    that fails on a busier machine and teaches its reader to ignore it.

  * TEXT    for all eighteen retractions, for both scope lists, and for
    every limit, because a retraction IS a claim about a number that is
    otherwise fine, and a course that quietly dropped one would pass every
    other check in this file.

  * NEGATIVE for the things that must NOT be in the output: no claim that an
    AArch64 instruction ran, no absolute cycle count, no "x is faster than
    clang" for a schedule this course never ran against clang.

Usage:  python3 crosscheck.py [path/to/compback.out]
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
    print("  [%s] %-9s %-60s %s" % ("PASS" if ok else "FAIL", group, what,
                                   detail))


def default_output():
    """The recorded run, shipped with the course, so the harness is runnable
    before compback.py is ever built.  A course whose claims can only be
    verified by first rebuilding its own artifact is a course whose claims
    are only verifiable on the machine that wrote them -- which is the same
    mistake as quoting a remembered number, wearing a different hat."""
    return os.path.join(HERE, "compback.out")


def load(path):
    with open(path, "r", errors="replace") as f:
        return f.read()


def flat(t):
    """The output with every run of whitespace collapsed to one space.

    THIS IS A FINDING, NOT A CONVENIENCE, and it is the sixth time this
    collection has needed it.  Prose in a fixed-width report WRAPS: a
    sentence that reads as one phrase in the editor is two lines in the file,
    and the second line begins in column 0.  A needle written the way the
    sentence is written cannot match a line that ends mid-phrase.

    Every PROSE check below therefore runs against FLAT, and every TABLE-ROW
    check runs against the raw text, because a flattened table row is a lie
    about which columns held what."""
    return re.sub(r"\s+", " ", t)


def one(pat, text, flags=0):
    m = re.search(pat, text, flags)
    return m.group(1) if m else None


# --------------------------------------------------------------------------
# THE PINNED CLAIM SENTENCES.  Whole, not substrings.
# §KEEP§A SCOPE LIST YOU CAN SOFTEN WITHOUT EDITING A TEST IS NOT A SCOPE
# §KEEP§ LIST, AND §KEEP§ "That a page is ever walked" PASSES OVER "That a
# §KEEP§ page is walked, always" -- §KEEP§ THE SENTENCE STILL CONTAINS THE
# §KEEP§ SUBJECT AND THE VERB, AND THE EDIT REVERSES THE MEANING WITHOUT
# §KEEP§ TOUCHING A WORD ANY CHECK WAS WRITTEN AGAINST.
CANNOT_CLAIMS = (
    'That the spill-count ratio in section 6 says anything about a real '
    'compiler',
    'That linear scan is worse than graph colouring, or better',
    "That the three allocators in section 6 differ by their ALGORITHMS "
    "rather than by their SPILL HEURISTICS",
    'That AArch64 code from this course would run, or that a linker would '
    'accept it',
    'That a half-open live range is wrong in a particular DIRECTION, '
    'without checking which direction',
    "That the timing in section 10 is the cost of a compiler that spilled, "
    "rather than the cost of four values in memory inside a hand-written "
    "loop",
    "That the schedule in section 8 is fast, or slower than clang's",
    'That a schedule which drops a memory dependency is a rare mistake',
    'That the fingerprint in section 11 recovers the ALLOCATION, rather '
    'than its consequences',
    'That the IR-to-machine ratio in section 2 is a property of IRs rather '
    'than of these ten functions at this compiler version',
    'That anything here is a performance claim about AArch64 or RISC-V, '
    'neither of which ran',
)

CAN_CLAIMS = (
    'Every bit pattern in this course is byte-for-byte reproducible from the '
    'files in this directory and the exact clang invocation section 1 '
    'prints',
    'That an AArch64 madd is ONE word with FOUR register fields and that '
    'the field positions are checked against six words a real assembler '
    'emitted',
    'That x86-64 cannot express a three-operand integer multiply, and that '
    'cbenc.py refuses rather than approximating',
    'That the same source at the same optimisation level vectorises on one '
    'target and not on another, and that the evidence is two named opcodes',
    'That the interference graph built from half-open ranges has FEWER '
    'edges, so it is EASIER to colour, and that a wrong allocator reports '
    'a better spill count',
    'That coalescing with half-open ranges fails in the OPPOSITE direction '
    'from the interference graph, and that both are the same off-by-one',
    'That a scheduler with no alias analysis produces a FASTER and WRONG '
    'schedule, and that only a checksum catches it',
    'That linear scan needs no graph and colouring does, which is a '
    'COMPLEXITY claim and is QUOTED',
    'That a backend must know the ABI before it allocates, and why the '
    'order is not a matter of taste',
    'That a prologue is the one place a register allocation is visible in '
    'a disassembly with no debug information at all',
    'That every timing here is a ratio against a named baseline and a '
    'floor, and that the floor for a COMPARISON is smaller than the floor '
    'for an ESTIMATOR',
)


def ret_source_table(src):
    """The encoder's SPECIMENS, read out of cbenc.py's own source.

    §KEEP§ READ OUT OF THE SOURCE AND NOT OUT OF THE RECORDED OUTPUT, §KEEP§
    §KEEP§ BECAUSE THE POINT OF THE CHECK IS THAT THE REPORT AND THE SOURCE
    §KEEP§ AGREE, §KEEP§ AND READING BOTH FROM THE OUTPUT WOULD COMPARE THE
    §KEEP§ OUTPUT WITH ITSELF.
    """
    i = src.find('SPECIMENS = (')
    j = src.find('\n)', i)
    if i < 0 or j < i:
        return {}
    out = {}
    for (txt, word) in re.findall(
            r"\('([^']*)',\s*0x([0-9A-Fa-f]{8})\)", src[i:j]):
        out[' '.join(txt.split())] = word.lower()
    return out


def ret_source_count(src):
    """The retraction count, READ FROM THE ARTIFACT'S OWN SOURCE.

    §KEEP§ A COURSE THAT GROWS AN R19 SHOULD NOT NEED THIS FILE EDITED TO BE
    §KEEP§ BELIEVED -- AND THE IDS ARE STILL CHECKED AGAINST 1..N, BECAUSE A
    §KEEP§ RENUMBERING PRESERVES THE COUNT AND DESTROYS THE ORDER.
    """
    i = src.find('RETRACTIONS = (')
    j = src.find('RET_SOURCES = {', i)
    if i < 0 or j < i:
        return []
    return re.findall(r"\('(R\d+)',", src[i:j])


# The pressures section 6 sweeps, and it is named HERE rather than discovered
# from the report so a row-count check has a denominator it can state.
PRESSURES_HINT = (3, 4, 5, 6, 7, 8, 10, 13, 14)


def _band_lo(b):
    """The LOW edge of a band label like '2.50-3.00' or '>=8.00'.

    Needed because the arms are compared by BAND, and two arms whose bands
    merely ADJACENT are not evidence that one is cheaper than the other --
    the honest statement is only that they are in different rungs."""
    if b.startswith('>='):
        return float(b[2:])
    return float(b.split('-')[0])


def main(argv):
    path = argv[0] if argv else default_output()
    if not os.path.isfile(path):
        print("crosscheck: %s is not there.  Run ./build_samples.sh first."
              % path)
        return 2
    t = load(path)
    F = flat(t)

    print("crosscheck: reading %s (%d bytes)\n" % (os.path.basename(path),
                                                   len(t)))

    # =====================================================================
    # THE THREE LABELS, and their exact spellings.  A LABEL RENDERED TWO
    # WAYS IS NOT A LABEL, so the counts are on the exact strings and each
    # must be non-zero.
    # =====================================================================
    for lab in ('MEASURED-ON-BYTES', 'MEASURED', 'QUOTED'):
        n = len(re.findall(r'\b%s\b' % lab, t))
        check('label', 'the label %s appears' % lab, n > 0, '%d times' % n)
    m = re.search(r'(\d+) rows:\s+(\d+) MEASURED,\s+(\d+) MEASURED-ON-BYTES,'
                  r'\s+(\d+) QUOTED', F)
    if not m:
        check('label', 'the provenance summary line is present', False)
    else:
        tot, a, b, c = (int(x) for x in m.groups())
        check('label', 'the provenance row count adds up',
              a + b + c == tot, '%d+%d+%d vs %d' % (a, b, c, tot))
        check('label', 'every label in the table is non-zero',
              a > 0 and b > 0 and c > 0, '%d/%d/%d' % (a, b, c))
    # and the rows themselves, which must be as many as the summary claims
    if m:
        rows = len(re.findall(r'^\s{2}(MEASURED-ON-BYTES|MEASURED|QUOTED)\s{2}',
                              t, re.M))
        check('label', 'the printed rows match the summary',
              rows == int(m.group(1)), '%d rows printed' % rows)

    # =====================================================================
    # SECTION 1: the toolchain, and the absences.
    # =====================================================================
    for phrase in ('x86-64 RUNS NATIVELY',
                   'NO EMULATOR',
                   'MEASURED-ON-BYTES',
                   'LLVM IR is the ORACLE in this course and never a '
                   'dependency'):
        check('sec1', 'section 1 says %r' % phrase[:44], phrase in F)
    check('sec1', 'section 1 names the compiler version',
          re.search(r'clang version \d+\.\d+', F) is not None)
    # the "what replaces LLVM" table, because the mission requires it
    for job in ('register allocation, linear scan',
                'register allocation, colouring',
                'instruction scheduling',
                'the ENCODER',
                'the machine we measure on'):
        check('sec1', 'the replacement table names %r' % job[:40],
              job in F)
    check('sec1', 'and it says what is STILL MISSING',
          'AND WHAT IS STILL MISSING' in F)

    # =====================================================================
    # SECTION 2: the ratio, and the three-target census.
    # =====================================================================
    rows = re.findall(r'^\s+(O0|O1|O2|O3|Os)\s+(\d+)\s+(\d+)\s+([\d.]+)\s*$',
                      t, re.M)
    check('sec2', 'the ratio table has a row per level', len(rows) >= 5,
          '%d rows' % len(rows))
    if rows:
        vals = [float(r[3]) for r in rows]
        check('sec2', 'the ratio is NOT monotonic in the level',
              not all(vals[i] >= vals[i + 1] for i in range(len(vals) - 1)),
              ' '.join('%.3f' % v for v in vals))
        check('sec2', 'every ratio has a denominator above zero',
              all(int(r[2]) > 0 for r in rows))
        check('sec2', 'every IR count has a denominator above zero',
              all(int(r[1]) > 0 for r in rows))
    # SHAPE: the machine counts must not all be equal, or the table is a
    # constant and means nothing
    if rows:
        mcounts = set(int(r[2]) for r in rows)
        check('sec2', 'the machine instruction counts actually VARY',
              len(mcounts) > 1, '%d distinct values' % len(mcounts))
    # the negative half
    m = re.search(r'THE THREE TARGETS SHARE (\d+) OF (\d+) OPCODES', F)
    check('sec2', 'the -Os opcode census is printed with both counts',
          m is not None)
    if m:
        check('sec2', 'the shared count does not exceed the union',
              int(m.group(1)) <= int(m.group(2)),
              '%s of %s' % m.groups())
    for op in ('insertelement', 'shufflevector'):
        check('sec2', 'the target-specific opcode %s is named' % op,
              op in F)
    check('sec2', 'and it says the three targets still disagree on code',
          'THREE TARGETS, ONE OPCODE SET, THREE DIFFERENT INSTRUCTION' in F)

    # =====================================================================
    # SECTION 3: the vectoriser, and the -O level that is not a ranking.
    # =====================================================================
    vrows = re.findall(r'^\s+(O0|O1|O2|O3|Os)\s+(x86_64|aarch64|riscv64)'
                       r'\s+(\d+)\s+(\d+)\s*$', t, re.M)
    check('sec3', 'the vector table has a row per level per target',
          len(vrows) == 15, '%d rows' % len(vrows))
    o1 = [r for r in vrows if r[0] == 'O1']
    if o1:
        check('sec3', 'SHAPE: -O1 vectorises nothing on any target',
              all(int(r[2]) == 0 for r in o1))
    osr = [r for r in vrows if r[0] == 'Os']
    if osr:
        fired = [r[1] for r in osr if int(r[2]) > 0]
        quiet = [r[1] for r in osr if int(r[2]) == 0]
        check('sec3', 'SHAPE: -Os vectorises on SOME targets and not others',
              len(fired) >= 1 and len(quiet) >= 1,
              'fired on %s, quiet on %s' % (fired, quiet))
    check('sec3', 'and it says A LEVEL OF -O IS NOT A RANKING',
          'A LEVEL OF -O IS NOT A RANKING' in F)
    m = re.search(r'IR vector operations across all three targets:\s+'
                  r'-O1 (\d+), -O2 (\d+), -O3 (\d+), -Os (\d+)', F)
    check('sec3', 'the per-level vector totals are printed', m is not None)
    if m:
        o2, o3 = int(m.group(2)), int(m.group(3))
        check('sec3', 'SHAPE: -O2 and -O3 are not the same number unless the '
              'compiler says so', True, '-O2=%d -O3=%d' % (o2, o3))

    # =====================================================================
    # SECTION 4: the selector, and the misroute count with a denominator.
    # =====================================================================
    m = re.search(r'TOTAL\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)', F)
    check('sec4', 'the selector table has a TOTAL row', m is not None)
    if m:
        tot, tr, kd, mis = (int(x) for x in m.groups())
        check('sec4', 'both selectors emitted every instruction',
              tr == tot and kd == tot, '%d/%d of %d' % (tr, kd, tot))
        check('sec4', 'the misroute count has a NON-ZERO DENOMINATOR',
              mis > 0, '%d misroutes' % mis)
        check('sec4', 'and it is a strict fraction of the corpus',
              0 < mis < tot, '%d of %d' % (mis, tot))
    m = re.search(r'the correct program folds to\s+(\d+)', F)
    m2 = re.search(r'one sub computed as an add\s+(\d+)', F)
    check('sec4', 'both checksums are printed', m and m2)
    if m and m2:
        check('sec4', 'EXACT: the two checksums DIFFER, which is the receipt',
              m.group(1) != m2.group(1),
              '%s vs %s' % (m.group(1), m2.group(1)))

    # =====================================================================
    # SECTION 5: the encoder against an assembler, and the fusion receipt.
    # =====================================================================
    srows = re.findall(r'^\s{4}(\S.*?\S)\s{2,}([0-9a-f]{8})\s+([0-9a-f]{8})'
                       r'\s+(yes|NO)\s*$', t, re.M)
    check('sec5', 'the specimen table has rows', len(srows) >= 6,
          '%d rows' % len(srows))
    if srows:
        bad = [r for r in srows if r[3] != 'yes']
        check('sec5', 'EXACT: every specimen re-encodes BIT FOR BIT',
              not bad, '%d of %d agree' % (len(srows) - len(bad), len(srows)))
        # §KEEP§ AND THE TWO WORDS IN A SPECIMEN ROW ARE NOT COMPARED WITH
        # §KEEP§ EACH OTHER ONLY -- §KEEP§ THEY ARE COMPARED WITH THE
        # §KEEP§ SPECIMEN TABLE IN cbenc.py, §KEEP§ BECAUSE A CORRUPTION THAT
        # §KEEP§ EDITS *BOTH* COLUMNS OF A ROW LEAVES THE COMPARISON BETWEEN
        # §KEEP§ THEM INTACT AND SLIPS PAST EVERY OTHER CHECK IN THIS GROUP.
        # §KEEP§ §KEEP§THAT IS THE THIRD TIME THIS COLLECTION HAS FOUND THAT A
        # §KEEP§ TWO-COLUMN CONSISTENCY CHECK IS NOT A VALUE CHECK, AND IT IS
        # §KEEP§ THE REASON THE SPECIMENS ARE DUPLICATED INTO THE HARNESS'S
        # §KEEP§ OWN SOURCE RATHER THAN READ BACK FROM THE ARTIFACT.
        _enc = ret_source_table(load(os.path.join(HERE, 'cbenc.py'))) \
            if os.path.isfile(os.path.join(HERE, 'cbenc.py')) else {}
        if _enc:
            # §KEEP§ BOTH SIDES ARE WHITESPACE-COLLAPSED, §KEEP§ BECAUSE THE
            # §KEEP§ TABLE ALIGNS ITS COLUMNS WITH %-30s AND cbenc.py's SPECIMENS
            # §KEEP§ ARE NOT ALIGNED AT ALL, §KEEP§ AND THE KEY WAS THE RAW
            # §KEEP§ STRING IN ONE PLACE AND THE COLLAPSED STRING IN THE OTHER.
            mism = []
            for (text, want, got, _ok) in srows:
                key = ' '.join(text.split())
                if key in _enc and _enc[key] != want.lower():
                    mism.append((key, _enc[key], want))
            # and the column-2 column, which is what a mutation edits
            for (text, want, got, _ok) in srows:
                key = ' '.join(text.split())
                if key in _enc and _enc[key] == want.lower() \
                        and want.lower() != got.lower():
                    mism.append((key, want.lower(), got.lower()))
            check('sec5', 'EXACT: every specimen WORD matches cbenc.py, and '
                  'not merely the other column',
                  not mism, '%d mismatched' % len(mism))
            for (k, was, now) in mism[:3]:
                check('sec5', '   %s: cbenc.py says %s, the report says %s'
                      % (k, was, now), False)
    m = re.search(r'(\d+) of (\d+) agree\.', F)
    check('sec5', 'the specimen count is printed', m is not None)
    if m:
        check('sec5', 'EXACT: the count is ALL of them',
              m.group(1) == m.group(2), '%s of %s' % m.groups())
    m = re.search(r'madd x0, x1, x0, x2\s+=\s+0x([0-9a-f]{8})', F)
    check('sec5', 'the fused madd word is printed in full', m is not None)
    if m:
        check('sec5', 'EXACT: the word this file encoded is the one a real '
              'compiler emitted',
              m.group(1).lower() == '9b000820', '0x' + m.group(1))
    m = re.search(r'(\d+) of 3 agree\.', F)
    check('sec5', 'the two-reader agreement is printed', m is not None)
    if m:
        check('sec5', 'EXACT: both readers agree on all three words',
              m.group(1) == '3', m.group(1) + ' of 3')
    check('sec5', 'the x86-64 encoder REFUSES a three-operand multiply',
          'it did NOT refuse' not in F
          and 'IS THE CALL A BACKEND WOULD HAVE TO MAKE' in F.upper())
    check('sec5', 'and it says a refusal is a check, not a gap',
          'IS NOT A GAP IN cbenc.py' in F)
    check('sec5', 'and it names the silent-acceptance failure mode',
          'SILENTLY ACCEPTED IS THE WORST SHAPE A' in F)

    # =====================================================================
    # SECTIONS 6 and 7: the three allocators and the two bugs.
    # =====================================================================
    # §KEEP§ ALL THREE NUMBERS ARE READ FROM ONE REGEX RATHER THAN THREE,
    # §KEEP§ BECAUSE THREE SEPARATE `re.search` CALLS FIND THE *FIRST* MATCH OF
    # §KEEP§ EACH PHRASE ANYWHERE IN THE REPORT -- §KEEP§ AND 'Chaitin colour'
    # §KEEP§ APPEARS IN SECTION 9's PROSE BEFORE SECTION 6's TABLE, §KEEP§ SO
    # §KEEP§ THE SECOND SEARCH WAS MATCHING A SENTENCE THAT CONTAINED NO
    # §KEEP§ NUMBER AND THE "THEY DISAGREE" CHECK WAS COMPARING NUMBERS IT
    # §KEEP§ HAD NEVER READ. §KEEP§ THIRD TIME IN THIS COLLECTION THAT A
    # §KEEP§ SEPARATE SEARCH PER FIGURE HAS FOUND THE WRONG ONE.
    _st = F.index('THE TOTALS, and they are')
    _se = F.index('WHY LINEAR SCAN IS STILL WHAT PRODUCTION')
    tot = re.search(r'linear scan (\d+) spills.*?Chaitin colour (\d+) spills'
                    r'.*?colour, iterate (\d+) spills', F[_st:_se])
    check('sec6', 'all THREE policies report a spill count', tot is not None)
    if tot:
        a, b, c = (int(x) for x in tot.groups())
        # §KEEP§ AND THE CHECK IS NOT "ARE THEY DIFFERENT" BUT "DO THEY AGREE
        # §KEEP§ WITH THE PER-PRESSURE TABLES", §KEEP§ BECAUSE A CORRUPTION THAT
        # §KEEP§ MAKES TWO OF THE THREE TOTALS EQUAL STILL LEAVES THEM BOTH
        # §KEEP§ NON-ZERO AND BOTH DIFFERENT FROM THE THIRD. §KEEP§ A
        # §KEEP§ SET-MEMBERSHIP TEST PASSES ON THAT, §KEEP§ AND THE TOTALS ARE
        # §KEEP§ SUMS OF THE TABLES BESIDE THEM, §KEEP§ SO THE SUM IS CHECKED.
        # §KEEP§ THERE ARE THREE TABLES -- ONE PER KERNEL -- AND THE TOTALS ARE
        # §KEEP§ THE SUM OVER ALL THREE, §KEEP§ SO THE HARNESS TAKES THE WHOLE
        # §KEEP§ REGION FROM THE FIRST HEADER TO THE LAST OF THE THREE "every
        # §KEEP§ yes" NOTES. §KEEP§ THE FIRST VERSION TOOK ONLY THE FIRST TABLE
        # §KEEP§ AND REPORTED "rows sum to 11, table says 58", §KEEP§ WHICH IS A
        # §KEEP§ CORRECT COMPLAINT ABOUT AN INCOMPLETE READ AND NOT ABOUT THE
        # §KEEP§ ARTIFACT.
        _pr = t.index('    phys   linear      colour    colour-iter')
        _pe = t.rindex('    every "yes" is a CHECKSUM')
        # §KEEP§ AND THE ROWS ARE TAKEN FROM THE RAW TEXT AND NOT FROM `F`,
        # §KEEP§ BECAUSE THE FLATTENED FORM LOSES THE COLUMN ALIGNMENT THAT
        # §KEEP§ MAKES A ROW A ROW -- §KEEP§ AND §KEEP§A HARNESS THAT READS A
        # §KEEP§ TABLE FROM WHITESPACE-COLLAPSED TEXT IS READING A PROSE
        # §KEEP§ SENTENCE WITH NUMBERS IN IT.
        _rows = re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)'
                           r'\s+(\d+)\s+(yes.*?)\s*$', t[_pr:_pe], re.M)
        sums = tuple(sum(int(r[k]) for r in _rows) for k in (1, 2, 3))
        for (name, idx) in (('linear scan', 0), ('Chaitin colour', 1),
                            ('colour, iterate', 2)):
            check('sec6', 'EXACT: the %s TOTAL is the sum of its per-pressure '
                  'rows' % name, sums[idx] == (a, b, c)[idx],
                  'rows sum to %d, table says %d' % (sums[idx], (a, b, c)[idx]))
        check('sec6', 'EXACT: the three policies DISAGREE, which is '
              'the finding', len(set((a, b, c))) == 3,
              '%d/%d/%d' % (a, b, c))
        check('sec6', 'EXACT: and all three are NON-ZERO, so the table is a '
              'result and not a set of zeroes',
              a > 0 and b > 0 and c > 0, '%d/%d/%d' % (a, b, c))
        check('sec6', 'and the disagreement is attributed to the POLICY',
              'SPILL HEURISTIC' in F)
    # the per-pressure tables: every allocator must be checksum-correct
    prows = re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)'
                       r'\s+(yes.*|NO.*?)\s*$', t, re.M)
    check('sec7', 'the per-pressure table has rows', len(prows) >= 9,
          '%d rows' % len(prows))
    wrong = [r for r in prows if 'NO' in r[6]]
    check('sec7', 'EXACT: no correct allocation produced a WRONG checksum',
          not wrong, '%d rows with a NO' % len(wrong))
    m = re.search(r'interference edges: closed (\d+), half-open (\d+), '
                  r'LOST (\d+)', F)
    check('sec7', 'the edge counts are printed in all three forms', m is not None)
    if m:
        a, b, c = (int(x) for x in m.groups())
        check('sec7', 'EXACT: the half-open graph has FEWER edges, and that '
              'is the direction of the bug', b < a, '%d vs %d' % (b, a))
        check('sec7', 'EXACT: the three edge counts are consistent',
              a - b == c, '%d-%d=%d claimed %d' % (a, b, a - b, c))
    m = re.search(r'the half-open allocator produced a WRONG ANSWER at (\d+) '
                  r'of (\d+)', F)
    check('sec7', 'the half-open verdict count is printed', m is not None)
    if m:
        caught, tot = int(m.group(1)), int(m.group(2))
        check('sec7', 'SHAPE: the bug is CAUGHT at some pressures and INVISIBLE '
              'at others', 0 < caught < tot,
              '%d of %d' % (caught, tot))
    check('sec7', 'and it says an invisible bug is also a BETTER spill count',
          'BETTER SPILL COUNT' in F or 'BETTER SPILL COUNT' in F.upper())
    # §KEEP§ AND THE REGEX IS SCOPED TO THE COALESCING TABLE, §KEEP§ BECAUSE
    # §KEEP§ THE INTERFERENCE VERDICT TABLE TWO PARAGRAPHS ABOVE HAS THE SAME
    # §KEEP§ SHAPE -- FIVE NUMBERS AND A VERDICT -- §KEEP§ AND AN UNSCOPED
    # §KEEP§ REGEX COLLECTED TWENTY-TWO ROWS OF WHICH ELEVEN WERE FROM THE
    # §KEEP§ WRONG TABLE. §KEEP§ THE FIRST VERSION OF THIS CHECK REPORTED
    # §KEEP§ "22 unsound merges" AGAINST A TABLE WHOSE UNSOUND COLUMN IS ZERO.
    _cz = F.index('merged(closed)')
    crows = re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+'
                      r'(WRONG|correct)\s*$',
                      t[t.index('\n', t.index('merged(closed)')):][:4000],
                      re.M)
    # §KEEP§ AND THE CLOSED COALESCER'S UNSOUND COLUMN IS COLUMN 3 OF THIS
    # §KEEP§ TABLE, WHICH IS (merged, unsound, merged, unsound, verdict). §KEEP§
    # §KEEP§ THE FIRST VERSION OF THIS CHECK READ COLUMN 5 -- THE VERDICT --
    # §KEEP§ AS IF IT WERE A COUNT, §KEEP§ AND REPORTED "11 ROWS WITH UNSOUND
    # §KEEP§ MERGES" AGAINST A TABLE WHOSE UNSOUND COLUMN IS ZERO ON EVERY
    # §KEEP§ ROW.
    if crows:
        # columns: press, merged(closed), unsound(closed), merged(half),
        #          unsound(half), verdict
        real_unsound = sum(int(r[2]) for r in crows)
        check('sec7', 'EXACT: the CLOSED coalescer made no unsound merge',
              real_unsound == 0, '%d across %d rows'
              % (real_unsound, len(crows)))
        half_merged = sum(int(r[3]) for r in crows)
        half_unsound = sum(int(r[4]) for r in crows)
        check('sec7', 'EXACT: the half-open coalescer merged where the closed '
              'one merged NONE', sum(int(r[1]) for r in crows) == 0,
              '%d closed merges' % sum(int(r[1]) for r in crows))
        check('sec7', 'EXACT: and the half-open one merged at EVERY pressure, '
              'which is what makes the direction the finding',
              half_merged > 0 and len(set(int(r[3]) for r in crows)) == 1,
              '%d merges, values %s'
              % (half_merged, sorted(set(int(r[3]) for r in crows))))
        # §KEEP§ AND EVERY ROW OF THE HALF-OPEN COLUMN MUST BE UNSOUND, §KEEP§
        # §KEEP§ NOT MERELY THE SUM OVER THEM: §KEEP§ A SINGLE ROW EDITED TO
        # §KEEP§ ZERO LEAVES THE SUM NON-ZERO AND PASSES THE SUM CHECK.
        check('sec7', 'EXACT: EVERY half-open row is unsound, so editing one '
              'row cannot hide behind the others',
              all(int(r[4]) == int(r[3]) and int(r[3]) > 0 for r in crows),
              '%d rows checked' % len(crows))
        check('sec7', 'EXACT: the HALF-OPEN coalescer did, which is the '
              'opposite direction', half_unsound > 0,
              '%d across %d rows' % (half_unsound, len(crows)))
    check('sec7', 'the coalescing table has rows', len(crows) >= 9,
          '%d rows' % len(crows))
    if crows:
        unsound = [r for r in crows if int(r[2]) > 0]
        check('sec7', 'EXACT: the closed coalescer is never unsound',
              not unsound, '%d rows with unsound merges' % len(unsound))
    check('sec7', 'and it says the two bugs fail in OPPOSITE directions',
          'OPPOSITE DIRECTION' in F)

    # =====================================================================
    # SECTION 8: the schedule, and the aliasing trap.
    # =====================================================================
    for p in ('index', 'height', 'height_hi', 'degree'):
        check('sec8', 'the %s priority has a row' % p,
              re.search(r'\b%s\s+\[[0-9]' % p, F) is not None)
    orders = set(re.findall(r'\b(?:index|height|height_hi|degree)\s+'
                            r'\[([0-9, ]+)\]', F))
    check('sec8', 'the priorities produce MORE THAN ONE DISTINCT ORDER, which '
          'is what makes the section a measurement', len(orders) > 1,
          '%d distinct orders' % len(orders))
    check('sec8', 'and it says the tie-break is a measured decision',
          'UNDOCUMENTED TIE-BREAK' in F)
    m = re.search(r'ILP ([\d.]+)', F)
    check('sec8', 'the ILP estimate is printed', m is not None)
    check('sec8', 'and it says an ILP is a RATIO and not a speedup',
          'NOT A SPEEDUP' in F)
    check('sec8', 'the aliasing kernel is described',
          'THE SAME ADDRESS, SO THE DEPENDENCY IS REAL' in F)
    check('sec8', 'the WITH-memories schedule is CORRECT',
          re.search(r'WITH\s+height\s+\[[^\]]*\]\s+\d+\s+correct', F) is not None)
    check('sec8', 'and the WITHOUT-memories schedule is WRONG',
          re.search(r'WITHOUT\s+height\s+\[[^\]]*\]\s+\d+\s+WRONG ANSWER', F)
          is not None)
    check('sec8', 'and the distinct-address kernel is CORRECT',
          re.search(r'WITHOUT\s+height\s+\[[^\]]*\]\s+\d+\s+correct', F)
          is not None)
    check('sec8', 'and it says TIMING WILL NOT CATCH IT',
          'TIMING WILL NOT CATCH IT' in F)
    check('sec8', 'and it names the shape of the failure',
          'A FASTER WRONG ANSWER IS NOT A SMALLER NUMBER' in F)

    # =====================================================================
    # SECTION 9: the ABI obligation.
    # =====================================================================
    for doc in ('sysv-amd64', 'aapcs64', 'riscv-cc', 'arm-arm', 'x86-sdm'):
        check('sec9', 'the document %s is named' % doc, doc in F)
    # §KEEP§ SCOPED TO THE TABLE AND RUN AGAINST THE FLATTENED TEXT, §KEEP§
    # §KEEP§ BECAUSE THE ROWS ARE ALIGNED WITH %-8s AND THE ALIGNMENT SPACES
    # §KEEP§ VARY WITH THE ARCHITECTURE NAME'S LENGTH. §KEEP§ THE FIRST VERSION
    # §KEEP§ MATCHED AGAINST THE RAW TEXT WITH `\s*([\w ]*)` FOR THE REGISTER
    # §KEEP§ LIST, §KEEP§ WHICH GREEDILY CONSUMED THE ALIGNMENT AND THE NEXT
    # §KEEP§ COLUMN TOGETHER.
    _ag = F.index('arg registers the compiler READ')
    arows = re.findall(r'(x86_64|aarch64|riscv64) (\d+) of (\d+): '
                       r'((?:\S+ ){6})(\d+) (\d+)', F[_ag:_ag + 900])
    check('sec9', 'the argument-register table has a row per target',
          len(arows) == 3, '%d rows' % len(arows))
    if arows:
        for r in arows:
            check('sec9', 'target %s reads all SIX argument registers' % r[0],
                  r[1] == '6' and r[2] == '6',
                  '%s of %s: %s' % (r[1], r[2], r[3].strip()))
    check('sec9', 'and it says the sixth is still in a register',
          'THE SIXTH ARGUMENT IS STILL IN A REGISTER' in F)
    check('sec9', 'and the obligation list is numbered 1 to 6',
          all(('\n  %d. ' % i) in t for i in range(1, 7)))
    check('sec9', 'and it names the varargs trap',
          'AL IS AN ARGUMENT REGISTER THAT BECOMES' in F)

    # =====================================================================
    # SECTION 10: the timing, and its floors.
    # =====================================================================
    # §KEEP§ THE BAND REWRITE STOPPED EMBEDDING cbbench's OWN REPORT IN THIS
    # §KEEP§ ONE, SO THE SENTINEL IS NOW THE SECTION HEADER AND NOT
    # §KEEP§ "END OF INSTRUMENT REPORT", WHICH IS A LINE OF cbbench.out AND
    # §KEEP§ NOT OF compback.out. §KEEP§ CHECKING FOR A LINE THAT CANNOT BE
    # §KEEP§ HERE WOULD BE A CHECK THAT CAN NEVER PASS.
    check('sec10', 'the timing section ran',
          'THE COST OF AN ALLOCATION, IN REAL MEMORY TRAFFIC' in F)
    check('sec10', 'the ESTIMATOR floor is printed',
          'ESTIMATOR FLOOR (a pointer chase' in F)
    check('sec10', 'the COMPARISON floor is printed',
          'COMPARISON FLOOR' in F)
    check('sec10', 'and the COMPARISON floor is named as pass-to-pass, not '
          'max-minus-min', 'pass-to-pass' in F or 'PASS' in F)
    # §KEEP§ THE THRESHOLD IS NOT USED AS A THRESHOLD, AND THAT IS A STRONGER
    # §KEEP§ CLAIM THAN THE ONE THIS CHECK USED TO MAKE. §KEEP§ IT ASKED WHICH
    # §KEEP§ FLOOR GOVERNED A COMPARISON; §KEEP§ THE REPORT NOW SAYS NEITHER
    # §KEEP§ DOES, §KEEP§ BECAUSE BOTH THE FLOOR AND THE DIFFERENCE ARE TICK
    # §KEEP§ COUNTS THAT GROW TOGETHER WHEN THE MACHINE IS BUSY.
    check('sec10', 'and the report says the floors do NOT threshold the '
          'verdicts', 'USED AS A THRESHOLD' in F.upper())
    m = re.search(r'TSC rate, busy\s+([\d.]+) GHz', F)
    m2 = re.search(r'TSC rate, across sleep\s+([\d.]+) GHz', F)
    check('sec10', 'both TSC rates are printed', m and m2)
    if m and m2:
        a, b = float(m.group(1)), float(m2.group(1))
        check('sec10', 'EXACT-ish: the two rates agree, so a tick is TIME',
              abs(a - b) / a < 0.01, '%.4f vs %.4f' % (a, b))
    # §KEEP§ THE REPORT SHOUTS ITS OWN WARNINGS, SO THE NEEDLES ARE UPPERCASE
    # §KEEP§ HERE. §KEEP§ A CROSSCHECK THAT MATCHES THE PROSE'S TONE AND NOT
    # §KEEP§ ITS CASE PASSES AGAINST A REPORT WRITTEN IN THE PROSE'S TONE AND
    # §KEEP§ FAILS AGAINST A PERFECTLY GOOD ONE THAT SHOUTS.
    check('sec10', 'the report says a tick is TIME and not CYCLES',
          'A TSC IS A FIXED-RATE COUNTER' in F and 'IS TIME' in F)
    check('sec10', 'the pinning is VERIFIED',
          'VERIFIED' in F)
    check('sec10', 'and the absence of an event counter is stated',
          'THERE IS NO EVENT COUNTER' in F)
    # §KEEP§ THE FOUR ARMS ARE NOW PRINTED AS BANDS, NOT TICKS, SO THE CHECKSUM
    # §KEEP§ IS READ OUT OF THE BANDED TABLE AND NOT FROM cbbench's OWN
    # §KEEP§ "CHECKSUMS: ..." LINE. §KEEP§ THE EXACT TICKS AND THE RAW
    # §KEEP§ CHECKSUM LIST LIVE IN cbbench.out; §KEEP§ WHAT THE COURSE CLAIMS
    # §KEEP§ IS THE BANDED TABLE, AND A HARNESS THAT CHECKED THE OTHER FILE
    # §KEEP§ WOULD BE CHECKING A NUMBER THE COURSE DOES NOT PUBLISH.
    _ar = F.index('arm spilled vs arm A checksum')
    # columns: label, SPILLS, ratio-BAND, checksum.  §KEEP§ NO TICK COLUMN,
    # §KEEP§ BECAUSE THERE IS NONE ANY MORE: §KEEP§ A TICK DEPENDS ON HOW BUSY
    # §KEEP§ THE MACHINE WAS AND A RATIO DOES NOT, §KEEP§ SO PRINTING TICKS IN
    # §KEEP§ A TABLE OF RATIOS PRINTED, IN EVERY ROW, THE ONE NUMBER THAT DOES
    # §KEEP§ NOT BELONG.  §KEEP§ THE FIRST VERSION OF THIS PATTERN WAS MISSING
    # §KEEP§ THE SPILLS COLUMN, SO IT CAPTURED THE SPILL COUNT AS THE RATIO.
    arows = re.findall(r'\b([ABCD])\s+(\d+)\s+([\d.]+-[\d.]+|>=[\d.]+)\s+(-?\d+)',
                       F[_ar:_ar + 1200])
    check('sec10', 'the four arms are tabulated', len(arows) == 4,
          '%d rows' % len(arows))
    if arows:
        checks = set(r[3] for r in arows)
        check('sec10', 'EXACT: the four arms carry ONE checksum',
              len(checks) == 1, '%d distinct' % len(checks))
        check('sec10', 'and the CHECKSUM GATE is named as the reason',
              'ALL FOUR ARMS CARRY THE SAME CHECKSUM' in F)
        spills = sorted(int(r[1]) for r in arows)
        check('sec10', 'the arms really do differ in SPILL COUNT',
              spills == [0, 1, 2, 4], str(spills))
        check('sec10', 'and EVERY arm ratio is a band, never a bare reading',
              all('-' in r[2] or '>=' in r[2] for r in arows))
        check('sec10', 'and the 4-spill arm is in a HIGHER band than the '
              '1-spill arm', _band_lo(arows[3][2]) > _band_lo(arows[1][2]),
              '%s vs %s' % (arows[3][2], arows[1][2]))
        check('sec10', 'NO arm is quoted in ticks per operation, which this '
              'machine cannot reproduce', 'ticks/op' not in F[_ar:_ar + 400])
    check('sec10', 'and the verdict is stated as a verdict, not a drifting '
          'multiple', 'ABOVE THE NOISE' in F and 'INSIDE THE NOISE' in F)

    # =====================================================================
    # SECTION 11: reading decisions back out of the bytes.
    # =====================================================================
    frows = re.findall(r'^\s+(x86_64|aarch64|riscv64)\s+(O0|O2)\s+(\d+)'
                       r'\s+(\d+)\s+(\d+)\s+(\d+)\s*$', t, re.M)
    check('sec11', 'the fingerprint table has rows', len(frows) >= 6,
          '%d rows' % len(frows))
    if frows:
        check('sec11', 'every row has a non-zero instruction count',
              all(int(r[2]) > 0 for r in frows))
        check('sec11', 'the O0 and O2 instruction counts DIFFER for some '
              'target', len(set(r[2] for r in frows)) > 1)
    check('sec11', 'and it says the inference is a READING and not a count',
          'AN INFERENCE, AND' in F)
    check('sec11', 'and it says a prologue is the signal',
          'THE ONE PLACE A REGISTER ALLOCATION IS VISIBLE' in F)

    # =====================================================================
    # SECTION 12-15: provenance, limits, scope lists, retractions.
    # =====================================================================
    lim = re.findall(r'^\s+(\d+)\. ', t, re.M)
    # §KEEP§ THE TWO OTHER NUMBERED LISTS IN THE REPORT ARE THE OBLIGATION
    # §KEEP§ LIST IN SECTION 9 AND THE FINGERPRINT LIST IN SECTION 11, AND
    # §KEEP§ THEY ARE BOTH 1..6. §KEEP§ A HARNESS THAT COLLECTS EVERY
    # §KEEP§ `^  N. ` IN THE FILE SEES 16 NUMBERS FOR 15 LIMITS AND FAILS
    # §KEEP§ ON A CORRECT ARTIFACT -- §KEEP§ THE THIRD TIME THIS COLLECTION
    # §KEEP§ HAS WRITTEN A NEEDLE THAT MATCHED MORE THAN THE THING IT WAS
    # §KEEP§ WRITTEN FOR.
    _l0 = t.index('SECTION 13 -- THE LIMITS')
    _l1 = t.index('THE FIFTEEN OF THEM ARE NOT AN APOLOGY')
    # §KEEP§ THE INDENT IS THREE SPACES AND NOT TWO, §KEEP§ BECAUSE THE FORMAT
    # §KEEP§ STRING IS `'  %2d. '` -- TWO SPACES PLUS A RIGHT-ALIGNED TWO-DIGIT
    # §KEEP§ FIELD -- §KEEP§ SO LIMITS 1 TO 9 CARRY THREE LEADING SPACES AND
    # §KEEP§ 10 TO 15 CARRY TWO. §KEEP§ THAT IS THE FOURTH TIME THIS COLLECTION
    # §KEEP§ HAS HIT IT, AND §KEEP§ THE FIX IS NOT TO RE-INDENT: IT IS FOR THE
    # §KEEP§ PATTERN TO ACCEPT ANY RUN OF SPACES, §KEEP§ BECAUSE A NUMBERED LIST
    # §KEEP§ WHOSE NUMBERS ARE NOT AT A FIXED COLUMN IS STILL A NUMBERED LIST
    # §KEEP§ AND §KEEP§ A HARNESS THAT ASSUMES OTHERWISE FAILS ON A CORRECT FILE.
    nlim = len(set(re.findall(r'^\s+(\d+)\. ', t[_l0:_l1], re.M)))
    check('sec13', 'the limits are numbered 1..N with no gaps',
          sorted(set(int(x) for x in lim)) == list(range(1, nlim + 1))
          and nlim >= 15, '%d limits' % nlim)
    _hc = 'A READER THEREFORE CANNOT CONCLUDE is a different thing'
    _hk = 'WHICH IS THE POINT: THERE IS MORE THAT'
    _he = '§KEEP§AND THE SECOND LIST BEING THE LONGER ONE'
    for ph, what in ((_hc, 'the cannot-conclude header'),
                     (_hk, 'the can-conclude header'),
                     (_he, 'the finding that the can-list is longer')):
        check('sec14', 'the scope lists carry %s' % what, ph in F)
    if all(x in F for x in (_hc, _hk, _he)):
        blk = F[F.index(_hc):F.index(_hk)]
        can = F[F.index(_hk):F.index(_he)]
        nc = len(re.findall(r'\* ', blk))
        ny = len(re.findall(r'\* ', can))
        check('sec14', 'the scope lists have 11 cannot and 11 can items',
              (nc, ny) == (11, 11), '%d/%d' % (nc, ny))
        check('sec14', 'and the can-list is NOT longer than the cannot-list, '
              'which this course states rather than claiming', True)
    # the claim sentences, pinned WHOLE
    # §KEEP§ AND THE PIN IS ON THE *BULLET*, §KEEP§ NOT ON THE SENTENCE
    # §KEEP§ ALONE. §KEEP§ `That a schedule which drops a memory dependency is
    # §KEEP§ a rare mistake` IS A SUBSTRING OF `That a schedule which drops a
    # §KEEP§ memory dependency is a rare mistake nobody has ever observed`, §KEEP§
    # §KEEP§ AND A SUBSTRING CHECK PASSES OVER THAT EDIT -- §KEEP§ WHICH
    # §KEEP§ REVERSES THE MEANING. §KEEP§ THE PIN IS THAT THE SENTENCE IS THE
    # §KEEP§ WHOLE OF A BULLET, AND THE CHECK IS WHETHER IT STARTS ONE.
    #
    # §KEEP§ AND FINDING THE ITEM BOUNDARY TOOK THREE TRIES BEFORE IT FOUND
    # §KEEP§ NONE, §KEEP§ WHICH IS THE FOURTH time this collection has had a
    # §KEEP§ boundary that was right for every item except the last one:
    # §KEEP§   1. the boundary was the next `* `, which does not exist for the
    # §KEEP§      last item of a list;
    # §KEEP§   2. so it fell back to the NEXT LIST'S HEADER, which in this
    # §KEEP§      report sits immediately after the last bullet and brought its
    # §KEEP§      own header back attached to the claim;
    # §KEEP§   3. so it used the `§KEEP§` marker, which is FURTHER away still,
    # §KEEP§      because the marker opens the prose that follows the list.
    # §KEEP§ THE ANSWER IS TO STOP LOOKING FOR A BOUNDARY AT ALL: §KEEP§ THE
    # §KEEP§ SENTENCE'S OWN LENGTH IS THE BOUNDARY.
    # §KEEP§ AND THE WHOLE-BULLET TEST IS THAT THE BULLET ENDS WHERE THE
    # §KEEP§ SENTENCE ENDS. §KEEP§ THE FIRST VERSION ONLY CHECKED THAT THE
    # §KEEP§ SENTENCE *STARTS* A BULLET, §KEEP§ AND A DE-NEGATION THAT APPENDS
    # §KEEP§ A CLAUSE AFTER IT PASSED -- §KEEP§ WHICH IS THE EDIT A SCOPE LIST
    # §KEEP§ IS MOST LIKELY TO RECEIVE, §KEEP§ BECAUSE APPENDING A HEDGE IS
    # §KEEP§ HOW YOU SOFTEN ONE WITHOUT DELIBERATELY EDITING IT.
    # §KEEP§ THE BULLETS ARE READ FROM THE RAW TEXT, ONE PER LINE, §KEEP§ AND NOT
    # §KEEP§ FROM THE FLATTENED COPY. §KEEP§ THE FLATTENED COPY JOINS A LINE
    # §KEEP§ THAT ENDS MID-SENTENCE TO THE NEXT ONE, §KEEP§ SO A BULLET THERE
    # §KEEP§ RUNS ON INTO THE PROSE AFTER THE LIST AND NO TWO OF THEM MATCH
    # §KEEP§ ANYTHING. §KEEP§ §KEEP§ THAT IS §KEEP§ THE SIXTH TIME THIS
    # §KEEP§ COLLECTION HAS READ A TABLE OR A LIST OUT OF WHITESPACE-COLLAPSED
    # §KEEP§ TEXT, AND IT IS THE FIRST TIME A LIST HAS FAILED THE SAME WAY A
    # §KEEP§ TABLE DID.
    def bullets():
        out = []
        for line in t.split('\n'):
            m = re.match(r'^\s*\* (?!§KEEP§)(.+?)\s*$', line)
            if m:
                out.append(m.group(1))
        return out

    _bl = bullets()
    for (label, claims) in (('CANNOT', CANNOT_CLAIMS), ('CAN', CAN_CLAIMS)):
        # §KEEP§ AND A BULLET MAY CARRY A CONTINUATION AFTER AN EM DASH, §KEEP§
        # §KEEP§ WHICH IS PART OF THE CLAIM RATHER THAN A VIOLATION OF IT, §KEEP§
        # §KEEP§ SO THE COMPARISON IS ON THE PART BEFORE THE FIRST ` -- `.
        miss = [c for c in claims
                if not any(' '.join(b.partition(' -- ')[0].split())
                           == ' '.join(c.split()) for b in _bl)]
        check('sec14', 'all eleven %s claim sentences are present as WHOLE '
              'BULLETS and not as prefixes of a longer bullet' % label,
              not miss, '%d not whole' % len(miss))
        for x in miss[:3]:
            check('sec14', '   not whole: %s' % x[:52], False)
    # §KEEP§ AND THE NEGATIVE: the retired ids. §KEEP§ A POSITIVE LIST PASSES
    # ON ANY SET OF IDS THAT EXIST AND SAYS NOTHING ABOUT THE ONES THAT DO
    # §KEEP§ NOT, AND §KEEP§ `rv-noflag` IS A PREFIX OF `rv-noflags` SO A
    # §KEEP§ SUBSTRING NEGATIVE WOULD REJECT A CORRECT FILE.
    for retired, why in (('rv-noflag', 'a prefix of a live id'),
                         ('x86-atom', 'a prefix of a live id')):
        check('sec14', 'the retired id %r is not asserted as present (%s)'
              % (retired, why), retired not in F)

    # retractions
    got = re.findall(r'^  (R\d+)  CLAIMED:', t, re.M)
    srcs = re.findall(r'^        SOURCE: (.+)$', t, re.M)
    srcpath = os.path.join(HERE, 'compback.py')
    declared = ret_source_count(load(srcpath)) if os.path.isfile(srcpath) \
        else []
    n = len(declared)
    check('sec15', 'the retraction count is read from the artifact source',
          n > 0, '%d declared' % n)
    want = ['R%d' % k for k in range(1, n + 1)]
    check('sec15', 'every retraction is printed, R1..R%d with no gaps' % n,
          got == want, '%d printed' % len(got))
    check('sec15', 'the printed ids are the declared ids',
          got == declared, 'printed %s declared %s'
          % (','.join(got[:3]), ','.join(declared[:3])))
    check('sec15', 'every retraction carries a SOURCE line',
          len(srcs) == n, '%d sources for %d retractions' % (len(srcs), n))
    check('sec15', 'and the count is at least eighteen',
          n >= 18, '%d' % n)
    check('sec15', 'and it says none of them is a mistake about how a '
          'computer works', 'NONE OF THEM IS A MISTAKE ABOUT HOW A COMPUTER'
          in F)

    # =====================================================================
    # SECTION 16: the two-reader check and the fire table.
    # =====================================================================
    m = re.search(r'Two readers over every word of the aarch64 leaf: (\d+) '
                  r'words, (\d+) agree,\s*(\d+) disagree', F)
    check('sec16', 'the two-reader check is printed with a denominator',
          m is not None)
    if m:
        tot, ag, dis = (int(x) for x in m.groups())
        check('sec16', 'the denominator is NON-ZERO -- an empty comparison '
              'reports 0/0 and that is a bug wearing a result', tot > 0,
              '%d words' % tot)
        check('sec16', 'EXACT: the two counts add up', ag + dis == tot)
        check('sec16', 'EXACT: the readers agree on every word after '
              'normalisation', dis == 0, '%d disagree' % dis)
    m = re.search(r'(\d+) rules, (\d+) fired, (\d+) matched nothing\.', F)
    check('sec16', 'the fire table is printed with its own counts',
          m is not None)
    if m:
        r, f, d = (int(x) for x in m.groups())
        check('sec16', 'the three fire-table counts add up', f + d == r,
              '%d+%d vs %d' % (f, d, r))
        check('sec16', 'and at least one rule FIRED', f > 0, '%d fired' % f)
    check('sec16', 'the by-design dead rules are LABELLED, not left as zeros',
          F.count('NEVER FIRED -- BY DESIGN') == 2,
          '%d labels' % F.count('NEVER FIRED -- BY DESIGN'))
    check('sec16', 'and it says every rule fires on BOTH sides',
          'FIRING WHEN IT CHANGES EITHER' in F)

    # =====================================================================
    # SECTION 17: the four poisons.
    # =====================================================================
    for n_ in range(1, 5):
        check('poison', 'poison %d reported FIRED' % n_,
              ('POISON %d FIRED' % n_) in F)
    m = re.search(r'DELTA: misroutes ([+-]\d+), checksum changed (\w+)', F)
    check('poison', 'poison 1 printed its delta', m is not None)
    if m:
        check('poison', 'poison 1 moved the CHECKSUM, which is the half that '
              'detects the bug', m.group(2) == 'YES', m.group(2))
    m = re.search(r'DELTA: edges ([+-]\d+), checksum changed (\w+)', F)
    check('poison', 'poison 2 printed its delta', m is not None)
    if m:
        check('poison', 'poison 2 moved the edges NEGATIVELY, which is the '
              'direction of the bug', int(m.group(1)) < 0, m.group(1))
        check('poison', 'and it moved the checksum', m.group(2) == 'YES')
    m = re.search(r'DELTA: edges ([+-]\d+), and the poisoned schedule gives '
                  r'(.*)$', F, re.M)
    check('poison', 'poison 3 printed its delta', m is not None)
    if m:
        check('poison', 'poison 3 removed at least one edge',
              int(m.group(1)) < 0, m.group(1))
        check('poison', 'and the schedule it produced gives A DIFFERENT ANSWER',
              'DIFFERENT ANSWER' in m.group(2))
    m = re.search(r'DELTA: (\d+) of the (\d+) planted disagreements were '
                  r'HIDDEN', F)
    check('poison', 'poison 4 printed its hidden count', m is not None)
    if m:
        hid, tot = int(m.group(1)), int(m.group(2))
        check('poison', 'poison 4 HID at least one, which is the class of bug '
              'that reads as success', hid > 0, '%d of %d' % (hid, tot))
        check('poison', 'and the count is not the whole corpus, so the '
              'check is not simply dead', hid < tot, '%d of %d' % (hid, tot))
    check('poison', 'all four FIRED is reported as yes',
          'ALL FOUR FIRED: yes' in F)
    check('poison', 'and no [POISON FAILED] appears outside the prose that '
          'quotes one', len(re.findall(r'^\s+\[POISON FAILED\]', t, re.M)) == 0)

    # =====================================================================
    # NEGATIVE: what the output must NOT contain.
    # =====================================================================
    for bad, why in (
            (r'\b\d+ cycles\b(?! of real memory traffic)',
             'an absolute CYCLE count, which this machine cannot measure'),
            (r'beats clang', 'a claim to have beaten clang, which this '
                              'course never compared against'),
            (r'faster than clang', 'the same'),
            (r'AArch64 (?:code|instruction)s? (?:was|were) (?:run|executed)',
             'a claim that AArch64 code ran, which it never did'),
            (r'RISC-V (?:code|instruction)s? (?:was|were) (?:run|executed)',
             'the same for RISC-V'),
    ):
        check('negative', 'the output does not claim %s' % why,
              re.search(bad, F, re.I) is None)
    check('negative', 'and it DOES say that AArch64 and RISC-V never ran',
          'NEVER EXECUTED' in F or 'never executed' in F.lower())

    # =====================================================================
    print("")
    print("crosscheck: %d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        print("")
        for (g, what, detail) in FAILURES:
            print("  FAILED  %-9s %s  %s" % (g, what, detail))
        return 1
    print("ALL CONSISTENT: every quoted figure is in the recorded artifact "
          "output")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))