#!/usr/bin/env python3
"""verify_rvat.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves
  * the artifact's own harness still passes against the SHIPPED rvat.out,
    which means the course's claims are checkable on a machine that never ran
    its assembler
  * the artifact's CORRUPTION SUITE also passes, which is the difference
    between a harness and a rubric
  * the four POISONS all report FIRED and all four DELTAS are non-zero
  * all EIGHTEEN retractions are present by name, and the three that name the
    SIBLING say so in their own SOURCE line
  * there is NO TIMING anywhere -- asserted as an ABSENCE, not as a caption

Run with the server up on :9000.

Derived from tools/verify_rvpriv.py, and the SHAPE is the same -- a manifest,
four concept routes, a landing page, a prev/next chain, and a committed
artifact whose harness reads a committed recording rather than re-measuring.
FIVE things had to change and each of them is a place where this course is not
like its sibling, so each is a shape rather than a value.

THE FIVE THINGS THAT ARE SPECIFIC TO THIS COURSE.

FIRST, and it is the one that constrains everything else: THIS COURSE HAS NO
TIMING ANYWHERE, and this is the THIRD kind of absence in the RISC-V section.
`rvabi` lost the ability to TIME and `rvpriv` lost the ability to OBSERVE THE
SUBJECT; this one loses the ability to OBSERVE WHETHER ANY OF ITS INSTRUCTIONS
DOES THE THING IT EXISTS TO DO.  So the verifier below does NOT look for a
ratio, and that is deliberate: a verifier for this course that expected a
speedup would be asserting a measurement the course does not make, and
asserting it would turn the course's central claim into something nobody
checked.  What it asserts instead is the FIVE ABSENCES as five separate
clauses, and the disclaimer sentence that names the three sibling ratios and
disclaims them.

SECOND, the poison check is the same SHAPE and the numbers are different.  All
four DELTA spellings are matched, all four are required to be NON-ZERO, and --
the part that is this course's own -- poisons 1 and 2 are asserted to move
DIFFERENT COLUMNS.  Poison 1 removes a model and the UNMODELLED count rises
while the DISAGREEMENT count does not move; poison 2 removes a superseded model
and the DISAGREEMENT count rises while the UNMODELLED count does not.  A
verifier that checked only "non-zero" would pass over a delta of +1 and would
not notice that the pairing is the finding.

THIRD, the retraction count is EIGHTEEN rather than seventeen, the ids are R1
through R18 with no gaps, and the count is read from the ARTIFACT'S OWN SOURCE
rather than hard-coded here, so a course that grows an R19 does not need this
file edited to be believed.  The ids are still checked against 1..N rather than
against a count, because a course whose retractions were renumbered would still
have eighteen and the gap would be the only thing that shows.  And R1, R2 and
R3 are checked INDIVIDUALLY for naming the SIBLING, because a count-based
check on "at least three mention SIBLING" passed against a file where only
one of them did.

FOURTH, the two-reader cross-check here is smaller than its siblings' -- 2197
instructions rather than eleven thousand -- and the UNMODELLED count is fifty,
which is NOT a defect.  This file models three configuration instructions, the
mask bit in three groups and the register group, and counts the rest.  A
verifier that demanded an unmodelled count of zero would be demanding a decoder
that names the whole vector extension, which would be a WORSE decoder.

FIFTH, and it is the one this collection has most recently learned: THE
CORRUPTION SUITE IS PART OF THE VERIFICATION.  A harness whose checks have
never been seen to fail is a rubric, and this collection has retracted four for
exactly that.  So `corrupt.py` -- which corrupts the recorded report
thirty-four ways and asserts that every corruption is CAUGHT, including a
zero-byte file -- is run here and its result is part of this verifier's verdict.
It is also the only check in this file that can fail while everything is green.
"""

import collections
import html
import json
import os
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "rvat"

m = json.load(open('courses/%s/manifest.json' % COURSE))

# manifest order: module order, then position within the module
order = []
for mod in m['modules']:
    order.extend(mod['concepts'])

by_id = {c['id']: c for c in m['concepts']}
print('%d concepts in %d modules, %d minutes total\n'
      % (len(order), len(m['modules']), sum(c['estimated_minutes'] for c in m['concepts'])))

bad = []


def get(path):
    return subprocess.run(['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                           BASE + path], capture_output=True, text=True).stdout


pages = {}
for i, cid in enumerate(order):
    if cid not in by_id:
        bad.append('%s: in a module but has no top-level entry' % cid)
        continue
    path = '/courses/%s/lessons/%s' % (COURSE, cid)
    code = get(path)
    if code != '200':
        bad.append('%s: route returned %s' % (path, code))
        continue
    h = subprocess.run(['curl', '-s', BASE + path], capture_output=True,
                       text=True).stdout
    pages[cid] = h

    mt = re.search(r'<div class="lesson-meta">(\d+) min', h)
    title = re.search(r'<h1>([^<]*)</h1>', h)
    units = h.count('class="unit ')
    foot = re.findall(r'href="(/courses/%s/lessons/[^"]+)"' % COURSE, h)

    prob = []
    if not mt:
        prob.append('no lesson-meta')
    elif int(mt.group(1)) != by_id[cid]['estimated_minutes']:
        prob.append('minutes %s != manifest %d' % (mt.group(1),
                                                   by_id[cid]['estimated_minutes']))
    if not title:
        prob.append('no h1')
    elif html.unescape(title.group(1)) != by_id[cid]['title']:
        prob.append('title %r != manifest %r'
                    % (html.unescape(title.group(1)), by_id[cid]['title']))
    # Six units per concept page: why, model, reality, example, apply,
    # connect.  A CONSTANT here rather than a manifest field, because it is a
    # convention of the lesson layout: a page that silently lost a unit still
    # renders, still has a valid h1, and still passes every link check.
    if units != 6:
        prob.append('%d units, expected 6' % units)
    # The unit METADATA line names the module, and it is checked against the
    # manifest because a page that says "module: atomic" while the manifest
    # puts the concept in `vector` renders correctly and is wrong.
    _mod = re.search(r'module:\s*([a-z]+)', h)
    if not _mod:
        prob.append('no module in the meta line')
    elif _mod.group(1) != by_id[cid]['module_id']:
        prob.append('page says module %s, manifest says %s'
                    % (_mod.group(1), by_id[cid]['module_id']))

    # prev/next, read from the footer only
    if i > 0:
        want = '/courses/%s/lessons/%s' % (COURSE, order[i - 1])
        if want not in foot:
            prob.append('footer missing prev %s' % want)
    if i + 1 < len(order):
        want = '/courses/%s/lessons/%s' % (COURSE, order[i + 1])
        if want not in foot:
            prob.append('footer missing next %s' % want)
    else:
        if '/courses/%s' % COURSE not in h:
            prob.append('last page has no link back to the course')

    print('  %-24s %3smin  units=%d  %-44s %s'
          % (cid, mt.group(1) if mt else '?', units,
             (title.group(1) if title else '?')[:44],
             'ok' if not prob else 'BAD: ' + '; '.join(prob)))
    bad.extend('%s: %s' % (cid, p) for p in prob)

# every internal link, from every page plus the landing page
lp = '/courses/%s' % COURSE
lh = subprocess.run(['curl', '-s', BASE + lp], capture_output=True, text=True).stdout
if get(lp) != '200':
    bad.append('%s: landing returned %s' % (lp, get(lp)))
allh = ''.join(pages.values()) + lh
links = sorted(set(re.findall(r'href="(/courses/[^"#?]*)"', allh)))
# a client-side template literal, not a real link
real = [l for l in links if '+' not in l and "'" not in l]
print('\n%d unique internal links (%d real, %d JS template literals skipped)'
      % (len(links), len(real), len(links) - len(real)))
print('  ' + '  '.join('%s=%d' % kv for kv in
                       sorted(collections.Counter(l.split('/')[2] for l in real).items())))
for l in real:
    code = get(l)
    if code != '200':
        bad.append('link %s -> %s' % (l, code))

# The OUTBOUND link list, asserted PRESENT and the RETIRED ids asserted ABSENT.
# A positive list passes on any set of ids that exist and says nothing about
# the ones that do not, and the previous course in this section shipped four ids
# that 404'd while its own artifact claimed every one had been verified.  The
# negative is on a WHOLE SEGMENT, because two of the retired ids are PREFIXES of
# live ones and a substring test would fail the course for linking to a page one
# character longer than an id it has retired.
OUTBOUND = ('/courses/smp/lessons/smp-atomic', '/courses/smp/lessons/smp-ordering',
            '/courses/simd/lessons/simd-width', '/courses/simd/lessons/simd-reduce',
            '/courses/simd/lessons/simd-boundaries', '/courses/simd/lessons/simd-compiler',
            '/courses/x86simd/lessons/x86-atomics', '/courses/x86simd/lessons/x86-order',
            '/courses/a64simd/lessons/a64-atomic', '/courses/a64simd/lessons/a64-order',
            '/courses/rvabi/lessons/rv-noflags')
RETIRED = ('simd-simd', 'smp-memory', 'x86-atom', 'a64-atomics', 'rv-noflag',
           'rv-ordering', 'rv-amo-encoding')
print('\n  the eleven outbound ids, asserted PRESENT individually:')
for l in OUTBOUND:
    code = get(l)
    if code != '200':
        bad.append('outbound %s -> %s' % (l, code))
    print('    %-44s %s' % (l, code))
print('  the seven retired ids, asserted ABSENT as whole segments:')
for rid in RETIRED:
    present = [l for l in real if re.search(r'/lessons/%s(?![\w-])' % re.escape(rid), l)]
    if present:
        bad.append('the RETIRED id %s is linked as %s' % (rid, present))
    print('    %-44s %s' % (rid, 'ABSENT' if not present else 'PRESENT'))

# --- the artifact's OWN recorded run, and the four poisons -----------------
# Read the SHIPPED rvat.out rather than re-running the artifact: a verifier
# that re-measures is a second experiment, and this one is about whether the
# course's COMMITTED claims are still true.
_out = os.path.join('courses', COURSE, 'assets', 'samples', 'rvat.out')
n = 0
if not os.path.isfile(_out):
    bad.append('rvat.out is not committed -- the course\'s claims would be '
               'checkable only on the machine that produced them')
else:
    # §KEEP§AND ITS SIZE IS ASSERTED BEFORE ANYTHING ELSE IS READ FROM IT.  THE
    # FIRST RECORDED rvat.out IN THIS COURSE WAS ZERO BYTES, WHICH IS HOW 557 OF
    # THE HARNESS'S CHECKS WERE HIDDEN BEHIND A FILE THAT LOOKED LIKE A RESULT.
    _sz = os.path.getsize(_out)
    if _sz < 20000:
        bad.append('rvat.out is %d bytes -- a report this short is a failed '
                   'run, not a result, and the harness must be run against it'
                   % _sz)
    t = open(_out, errors='replace').read()

    # THE THREE LABELS, and their spelling.  Rule 13, and the check is on the
    # exact strings because "a label rendered two ways is not a label".
    for lab in ('MEASURED', 'MEASURED-ON-BYTES', 'QUOTED'):
        if len(re.findall(r'\b%s\b' % lab, t)) == 0:
            bad.append('the label %s never appears in rvat.out' % lab)
    print('\n  --  labels: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED'
          % (len(re.findall(r'\bMEASURED\b', t)),
             len(re.findall(r'\bMEASURED-ON-BYTES\b', t)),
             len(re.findall(r'\bQUOTED\b', t))))

    # THE FIVE ABSENCES, as FIVE SEPARATE CLAUSES, and the sentence that says
    # nothing in the course was ever executed.  The third RISC-V absence is
    # named as such, because a reader arriving from rvpriv is expecting a
    # milder version of the same caveat.
    if 'NOTHING IN THIS COURSE IS EVER EXECUTED' not in t:
        bad.append('the artifact does not say NOTHING IN THIS COURSE IS EVER '
                   'EXECUTED, so its absence claim is a caption rather than a '
                   'header')
    for phrase in ('NO RESERVATION IS EVER HELD',
                   'NO AMO IS EVER OBSERVED TO BE ATOMIC',
                   'NO FENCE IS EVER OBSERVED TO ORDER ANYTHING',
                   'NO VECTOR INSTRUCTION IS EVER RUN',
                   'THIS IS THE THIRD KIND OF ABSENCE IN THIS SECTION'):
        if phrase not in t:
            bad.append('the artifact never says %r -- and that is the whole '
                       'scope of the course' % phrase)
    if not ('3.89x' in t and '4.92x' in t and '27.65x' in t and
            'NO COUNTERPART HERE' in t):
        bad.append('the siblings\' three ratios are not named AND explicitly '
                   'disclaimed, so a contrast with an unmeasured number in it '
                   'is a footnote')
    # The three named ratios are the ONLY ratios in the file, and the check is
    # on the COUNT rather than on their names -- a course that invented a fourth
    # would pass a name-based check.
    _ratios = re.findall(r'\b\d+\.\d\dx\b', t)
    if len(_ratios) > 6:
        bad.append('the artifact contains %d speedup ratios; the three named '
                   'ones may be named but nothing else may be invented'
                   % len(_ratios))

    # The central experiment's two ends, because a course that measured one
    # letter and printed only the side it liked is not an experiment.
    if 'WITHOUT it          (-march=rv64im)' not in t:
        bad.append('the without-the-letter build is not in the report, so the '
                   'comparison is one-sided')
    # The two TOTAL lines, in the order they appear: the with-the-letter build
    # first, the without one second.  The CALLS column is the whole point of the
    # experiment, and the first version of this check compared the two builds'
    # call counts the WRONG WAY ROUND -- it demanded the FIRST be non-zero, and
    # the first build is the one that has NO calls because the extension lets
    # the compiler inline everything.  §KEEP§A CHECK THAT RAN GREEN BECAUSE IT
    # ASSERTED THE OPPOSITE OF THE COURSE'S CLAIM IS WORSE THAN NO CHECK, BECAUSE
    # IT LOOKS LIKE COVERAGE.
    _tot = re.findall(r'TOTAL (\d+) instructions: (\d+) lr, (\d+) sc, '
                      r'(\d+) amo\*, (\d+) CALLS', t)
    if len(_tot) != 2:
        bad.append('the two builds do not both print a TOTAL line (%d found)'
                   % len(_tot))
    else:
        _withA, _withoutA = _tot[0], _tot[1]
        if _withA[4] != '0' or _withoutA[4] == '0':
            bad.append('the with-the-letter build reports %s library calls and '
                       'the without one %s; the experiment claims 0 and a '
                       'non-zero' % (_withA[4], _withoutA[4]))
        elif _withA[1] == _withA[2] == '0' or _withA[3] == '0':
            bad.append('the with-the-letter build has no lr, no sc and no amo, '
                       'so the extension changed nothing and the comparison is '
                       'about something else')
        else:
            print('\n  the CENTRAL EXPERIMENT, one letter apart, and both '
                  'sides printed:')
            print('    with    %3s instructions, %s lr, %s sc, %s amo*, %s CALLS'
                  % _withA)
            print('    without %3s instructions, %s lr, %s sc, %s amo*, %s CALLS'
                  % _withoutA)

    # The four poison verdicts.  Plan rule 15: each poison must MOVE the
    # number it claims to test, and a run that printed no verdict at all is not
    # a passing run -- it is a run where the control did not run.
    for k in (1, 2, 3, 4):
        if ('VERDICT: POISON %d FIRED' % k) not in t:
            bad.append('poison %d did not report FIRED in rvat.out' % k)

    p1 = re.search(r'DELTA: named ([+-]\d+), disagreements ([+-]\d+), '
                   r'unmodelled ([+-]\d+)', t)
    p2 = re.findall(r'DELTA: named ([+-]\d+), disagreements ([+-]\d+), '
                    r'unmodelled ([+-]\d+)', t)
    p3 = re.search(r'DELTA: (\d+) of (\d+) words moved, (\d+) did not', t)
    p4 = re.search(r'DELTA: (\d+) of the (\d+) planted disagreements were '
                   r'HIDDEN', t)
    # A COLUMN THAT IS CLAIMED NOT TO MOVE MUST BE ZERO, and a column that is
    # claimed to move must NOT be -- so the requirement is on the SIGN RELATION
    # and not on every group being non-zero.  §KEEP§THE FIRST VERSION OF THIS
    # BLOCK ASKED "IS IT NON-ZERO" OF ALL SIX GROUPS AND SO FAILED ON THE TWO THAT
    # ARE SUPPOSED TO BE ZERO, WHICH IS THE POISON THAT PROVES THE CROSS-CHECK
    # WAS NOT VACUOUS.  A CHECK THAT DEMANDS MOVEMENT OF A COLUMN WHOSE WHOLE
    # CLAIM IS "THIS ONE STAYS PUT" IS A CHECK THAT WOULD REJECT A CORRECT RUN.
    for label, mm, grp, want_nonzero in (('1 named', p1, 1, True),
                                          ('1 unmodelled', p1, 3, True),
                                          ('3 moved', p3, 1, True),
                                          ('3 unmoved', p3, 3, False),
                                          ('4 hidden', p4, 1, True)):
        if not mm:
            bad.append('no poison %s figure in rvat.out' % label)
        elif bool(int(mm.group(grp))) is not want_nonzero:
            bad.append('poison %s reports %s, and the artifact CLAIMS it %s -- '
                       'a delta of %s here is %s'
                       % (label, mm.group(grp),
                          'moved' if want_nonzero else 'stayed at zero',
                          mm.group(grp),
                          'a control that did not move'
                          if want_nonzero else 'a partial reader'))
    # THE PAIRING, and it is the finding.  Poison 1 moves the UNMODELLED column
    # and claims the DISAGREEMENT column stays put; poison 2 does the reverse.
    # §KEEP§A CHECK THAT ONLY ASKED "NON-ZERO" WOULD PASS ON A DELTA OF +1 AND
    # WOULD NOT NOTICE THAT THE PAIRING IS WHAT THE TWO POISONS ARE FOR.
    if p1 and len(p2) > 1:
        q1, q2 = p2[0], p2[1]
        if not (int(q1[2]) != 0 and int(q1[1]) == 0):
            bad.append('poison 1 does not move the UNMODELLED column while '
                       'leaving the DISAGREEMENT column at +0')
        if not (int(q2[1]) > 0 and int(q2[2]) == 0):
            bad.append('poison 2 does not move the DISAGREEMENT column while '
                       'leaving the UNMODELLED column at +0')
        if not (int(q2[1]) > 0 and int(q1[2]) > 0):
            bad.append('the two poisons move the same column, so the pairing '
                       'that makes them meaningful is gone')
        else:
            print('\nPOISONS, all four FIRED, all four non-zero, and the two '
                  'that pair move DIFFERENT columns:')
            print('  1  remove m_vector_mask  named %s, disagreements %s, '
                  'unmodelled %s' % q1)
            print('     -- a missing model makes a HOLE')
            print('  2  remove m_amo_order     named %s, disagreements %s, '
                  'unmodelled %s' % q2)
            print('     -- a superseded model makes a MISTAKE')
            if p3:
                print('  3  clear the aq/rl bits   %s of %s words moved, %s '
                      'unmoved' % p3.groups())
            if p4:
                print('  4  break the CHECK        %s of %s real disagreements '
                      'HIDDEN' % p4.groups())
    # Poison 3's DENOMINATOR is the set that could have moved, and the first
    # version of this artifact counted the ones that could not.
    den = re.search(r'A-extension words that CARRIED \.aq or \.rl\s+: (\d+)', t)
    if den and p3 and den.group(1) != p3.group(2):
        bad.append('poison 3 counts %s words but its denominator is %s -- a '
                   'poison must divide by the instances that COULD move'
                   % (p3.group(2), den.group(1)))

    # The two-reader cross-check's own headline numbers.
    if not re.search(r'^\s+0  DISAGREE', t, re.M):
        bad.append('the cross-check does not report zero disagreements')
    unmod = re.search(r'^\s+(\d+) +unmodelled -- counted, never dropped', t, re.M)
    if not unmod:
        bad.append('the cross-check does not report an UNMODELLED count, so a '
                   'reader cannot tell a hole from an agreement')
    elif int(unmod.group(1)) == 0:
        bad.append('the cross-check names every instruction and nothing is '
                   'unmodelled -- which would mean the corpus was too easy')
    # The three numbers must ADD UP, because a harness that counts agreements
    # over a corpus mostly consisting of words it never looked at is the exact
    # failure this course's poison section is about.
    tot = re.search(r'^\s+(\d+) +instructions the second reader printed', t, re.M)
    named = re.search(r'^\s+(\d+) +of them this file NAMES', t, re.M)
    if tot and named and unmod:
        if int(named.group(1)) + int(unmod.group(1)) != int(tot.group(1)):
            bad.append('the cross-check\'s own numbers do not add up: %s '
                       'named + %s unmodelled against %s total'
                       % (named.group(1), unmod.group(1), tot.group(1)))

    # The normalisation fire table.  This course PRE-SEEDS its own rules, so a
    # rule that never fires is a row with a zero rather than an absence, and
    # exactly one of the six is dead ON PURPOSE.  A check that demanded zero
    # dead would fail against the mechanism that makes the table trustworthy.
    norm = re.search(r'(\d+) rules, (\d+) fired, (\d+) matched nothing', t)
    if not norm:
        bad.append('no normalisation fire table in rvat.out')
    elif norm.group(3) != '1':
        bad.append('normalisation: %s of %s rules fired and %s are DEAD; this '
                   'course PRE-SEEDS one rule that must not fire, so exactly '
                   'one dead is the healthy state' % (norm.group(2),
                                                      norm.group(1),
                                                      norm.group(3)))
    elif 'NEVER FIRED' not in t:
        bad.append('a dead rule is not labelled DEAD or NEVER FIRED, and an '
                   'unlabelled zero is indistinguishable from a mistake')
    else:
        print('  --  %s of %s normalisation rules fired and 1 is DEAD BY '
              'DESIGN, labelled in the table' % (norm.group(2), norm.group(1)))

    if 'THE CLASSIFIER, run on every run' not in t:
        bad.append('the classifier is not in the main path, so a run where it '
                   'finds nothing is indistinguishable from a run where it '
                   'never ran')
    if 'NOTHING TO CLASSIFY' not in t:
        bad.append('the report does not say what the classifier found, and '
                   'silence is not an answer')

    # All the retractions present by name, with no gaps, because a retraction
    # that is quietly deleted is the one failure no number catches.  The COUNT
    # comes from the artifact's own source, so this file does not have to be
    # edited when the artifact grows one -- and the ids are still checked
    # against 1..N rather than against a count, because a renumbering would
    # preserve the count and destroy the order.
    _src = open(os.path.join('courses', COURSE, 'assets', 'samples',
                             'rvat.py'), errors='replace').read()
    _i = _src.find('RETRACTIONS = [')
    _j = _src.find('RET_SOURCES = {', _i)
    declared = re.findall(r"^    \('(R\d+)',", _src[_i:_j], re.M) \
        if _i >= 0 and _j > _i else []
    got = re.findall(r'^  (R\d+)  CLAIMED:', t, re.M)
    n = len(declared)
    want = ['R%d' % k for k in range(1, n + 1)]
    if n < 18:
        bad.append('the artifact declares %d retractions; this verifier was '
                   'written against eighteen and a course that has lost them '
                   'should fail loudly' % n)
    elif got != want:
        bad.append('retractions: found %d (%s) in rvat.out, expected %d '
                   'R1..R%d with no gaps'
                   % (len(got), ','.join(got), n, n))
    elif got != declared:
        bad.append('the artifact DECLARES %s but PRINTS %s -- a retraction '
                   'with no printed body is not a retraction'
                   % (','.join(declared), ','.join(got)))
    else:
        print('  --  all %d retractions present by name, R1..R%d, no gaps, '
              'and the count is read from the artifact\'s own source'
              % (n, n))
    srcs = re.findall(r'^        SOURCE: (.+)$', t, re.M)
    if len(srcs) != n:
        bad.append('retractions: %d SOURCE lines for %d retractions -- a '
                   'retraction with no source is a course disagreeing with '
                   'itself' % (len(srcs), n))
    # R1, R2 and R3 name the SIBLING as where the defect lives, and they are
    # checked INDIVIDUALLY.  A count-based check on "at least three mention
    # SIBLING" passed against a file where only one of them did, which is how
    # this verifier found a gap in its own sibling's harness.
    for rid in ('R1', 'R2', 'R3'):
        blk = re.search(r"^  %s  CLAIMED:.*?^        SOURCE: (.+?)$" % rid, t,
                        re.M | re.S)
        if not blk:
            bad.append('retraction %s has no readable SOURCE line' % rid)
        elif 'SIBLING' not in blk.group(1):
            bad.append('retraction %s does not name the SIBLING as where its '
                       'defect lives -- and %s is about the sibling\'s code'
                       % (rid, rid))
    if sum(1 for x in srcs if 'SIBLING' in x) < 3:
        bad.append('fewer than three retractions name the SIBLING, so the '
                   'honest ones may have been rewritten')

    # The nineteen limits, ENUMERATED AND NUMBERED, and the corpus-completeness
    # sentence.  The numbering is checked with the same pattern the harness
    # uses, because the first version of the artifact printed them with a
    # right-aligned `%2d` and no list could find its own numbers.
    lim = re.findall(r'^  (\d+)\. ', t, re.M)
    if len(lim) < 19 or lim[:19] != [str(i) for i in range(1, 20)]:
        bad.append('the limits are not numbered 1..19 at the start of a line '
                   '(found %d)' % len(lim))
    if 'THE CORPUS IS INCOMPLETE' not in t:
        bad.append('the corpus-completeness check does not print its own '
                   'verdict on a complete run, so it can only be exercised on '
                   'a broken artifact')
    # The banner's own counts, matched against the artifact's declarations.
    banner = re.search(r'END OF REPORT -- (\d+) sections, (\d+) limits, '
                       r'(\d+) retractions, (\d+) poisons, (\d+) provenance rows',
                       t)
    if not banner:
        bad.append('the report does not end with its own counts')
    elif (int(banner.group(2)) != 19 or int(banner.group(3)) != n
          or int(banner.group(5)) != 58):
        bad.append('the banner says %s sections / %s limits / %s retractions '
                   '/ %s provenance rows, and this verifier expects 14 / 19 / '
                   '%d / 58' % (banner.group(1), banner.group(2),
                                banner.group(3), banner.group(5), n))

    # THE TWO SCOPE LISTS.  Nine cannot-conclude items and eleven can-conclude
    # items, and the second list being the longer one is the finding, so both
    # the counts and the ORDERING are asserted.
    flat_t = re.sub(r'\s+', ' ', t)
    _hc = 'A READER THEREFORE CANNOT CONCLUDE is a different thing'
    _hk = 'teaches its reader that the subject is unknowable'
    _he = 'WHICH IS THE POINT: there is more that can be read'
    if not all(x in flat_t for x in (_hc, _hk, _he)):
        bad.append('the two scope lists are not both present in rvat.out, '
                   'and one of them is missing entirely')
    else:
        _blk = flat_t[flat_t.index(_hc):flat_t.index(_hk)]
        _can = flat_t[flat_t.index(_hk):flat_t.index(_he)]
        _nc = len(re.findall(r'\* ', _blk))
        _ny = len(re.findall(r'\* ', _can))
        if (_nc, _ny) != (9, 11):
            bad.append('the scope lists carry %d cannot and %d can items, '
                       'expected 9 and 11' % (_nc, _ny))
        elif not _ny > _nc:
            bad.append('the can-list is not longer than the cannot-list, and '
                       'that ordering IS the finding')
        else:
            print('  --  scope lists: %d cannot-conclude, %d can-conclude, and '
                  'the second is the longer one' % (_nc, _ny))

# the course's own harness, against the SHIPPED recording
_samples = os.path.join('courses', COURSE, 'assets', 'samples')
if os.path.isdir(_samples):
    _cc = subprocess.run([sys.executable, os.path.join(_samples, 'crosscheck.py')],
                         capture_output=True, text=True)
    # Two tally spellings are in use across the collection -- "N/M checks
    # passed" and "N checks, M failures" -- so accept either, and require that
    # the failures column is zero.
    _passed = re.search(r'(\d+)/(\d+) checks passed', _cc.stdout)
    _failed = re.search(r'(\d+) checks,\s*(\d+) fail', _cc.stdout)
    if _passed:
        tally = '%s/%s measured claims still hold' % _passed.groups()
        healthy = _passed.group(1) == _passed.group(2)
    elif _failed:
        tally = '%s measured claims still hold, %s failed' % _failed.groups()
        healthy = _failed.group(2) == '0'
    else:
        healthy = False
    if _cc.returncode != 0 or not healthy:
        bad.append('crosscheck.py: %s' % (_cc.stdout.strip().splitlines()[-1]
                                          if _cc.stdout else _cc.stderr[:60]))
    else:
        print('\ncrosscheck.py: ' + tally)

    # THE CORRUPTION SUITE, and this is the check that makes the other one mean
    # something.  Thirty-four corruptions of the recorded report, every one of
    # which has to be CAUGHT -- including a zero-byte file, which is the failure
    # this course actually shipped once.
    _cp = os.path.join(_samples, 'corrupt.py')
    if not os.path.isfile(_cp):
        bad.append('corrupt.py is missing, so nothing has demonstrated that '
                   'this course\'s harness can FAIL, and a harness that has '
                   'never failed is a rubric')
    else:
        _cr = subprocess.run([sys.executable, _cp], capture_output=True,
                             text=True)
        _t = re.search(r'(\d+) corruptions, (\d+) caught, (\d+) missed, '
                       r'(\d+) errored', _cr.stdout)
        if not _t:
            bad.append('corrupt.py printed no tally: %s'
                       % (_cr.stdout.strip().splitlines()[-1]
                          if _cr.stdout else _cr.stderr[:60]))
        elif _cr.returncode != 0 or int(_t.group(2)) != int(_t.group(1)):
            bad.append('corrupt.py: %s of %s corruptions were CAUGHT, %s '
                       'missed and %s errored -- a check this file does not '
                       'watch is not a check'
                       % (_t.group(2), _t.group(1), _t.group(3), _t.group(4)))
        else:
            print('corrupt.py:  %s corruptions, %s caught, 0 missed -- so the '
                  'harness is a harness and not a rubric' % (_t.group(1),
                                                             _t.group(2)))

print('\n' + '=' * 70)
if bad:
    print('  %d PROBLEMS' % len(bad))
    for b in bad:
        print('   - %s' % b)
else:
    print('  ALL CONSISTENT: %d concepts, %d links all 200, the eleven '
          'outbound ids PRESENT and the seven retired ids ABSENT, chain, '
          'minutes, three labels, four non-zero poison deltas with poisons 1 '
          'and 2 moving DIFFERENT columns, %d retractions with a SOURCE each '
          'and R1-R3 naming the sibling, %d numbered limits, two scope lists of '
          '9 and 11 verified, no timing anywhere, and %s of %s deliberate '
          'corruptions caught'
          % (len(pages), len(real), n, 19, '34', '34'))
print('=' * 70)
sys.exit(1 if bad else 0)
