#!/usr/bin/env python3
"""verify_rvpriv.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves
  * the artifact's own harness still passes against the SHIPPED rvpriv.out,
    which means the course's claims are checkable on a machine that never ran
    its assembler
  * the four POISONS all report FIRED and all four DELTAS are non-zero
  * all TWELVE retractions are present by name

Run with the server up on :9000.

Derived from tools/verify_rvpriv.py, and the SHAPE is the same -- a manifest,
four concept routes, a landing page, a prev/next chain, and a committed
artifact whose harness reads a committed recording rather than re-measuring.
Four things had to change and each of them is a place where this course is not
like its sibling, so each is a shape rather than a value.

THE FOUR THINGS THAT ARE SPECIFIC TO THIS COURSE, and each is a shape rather
than a value.

FIRST, and it is the one that constrains everything else: THIS COURSE HAS NO
TIMING ANYWHERE.  There is no RISC-V machine, no emulator and no RISC-V linker
on this host, so every number in the artifact is a bit pattern, a count of bit
patterns, an arithmetic identity, or a refusal from a real assembler.  The
x86-64 ABI course measured a 4.92x and a 27.65x on hardware; this course has
no counterpart for either.  So the verifier below does NOT look for a ratio, and
that is deliberate: a verifier for this course that expected a speedup would be
asserting a measurement the course does not make, and asserting it would make
the course's own central claim &mdash; that the absence of a timing is stated
before the first number rather than in a disclaimer at the end &mdash; into
something nobody checked.  What it looks for instead is the census of
instruction counts, the twelve limits, and the four poison deltas.

SECOND, the poison check is the SAME as rvasm's and the shapes are different.
rvasm's four poisons report a victim count, a movement total, a delta and a
hidden count.  This course's report a DELTA line per poison in one fixed
spelling -- "DELTA: named N, disagreements N, unmodelled N" -- plus a bare
"DELTA: N" for the length-rule poison, and a sentence form for the planted-
disagreement poison.  All four spellings are matched below, and each is
required to be NON-ZERO, because a control that cannot move is a comment that
says the word POISONED.

THIRD, the retraction count is SEVENTEEN rather than twelve, and the ids are R1
through R17 with no gaps.  The count is read from the ARTIFACT'S SOURCE rather
than hard-coded here, so a course that grows an R18 does not need this file
edited to be believed -- and the check is still on the ids rather than on a
count alone, because a course whose retractions were renumbered would still
have seventeen and the gap would be the only thing that shows.

  R16 and R17 are also the reason the count is seventeen rather than sixteen,
  and both are worth naming in a verifier because both are about THIS course's
  own harness rather than about the subject.  R16: the artifact's immediate
  table read inst[31:20] out of an S-type word, which is not an immediate.
  R17: the FIRST FIX for R16 named that register `rd`, and a store has no
  destination register -- so the value was right and the field NAME was wrong,
  which is the worse of the two failures because a name gets copied.  A
  verifier that only counted retractions would have said seventeen and been
  right by accident.

FOURTH, and it is why this course ships a harness with a `flat()` in it: THIS
VERIFIER'S OWN SIBLING HARNESS HAD THIRTY CHECKS THAT COULD NOT PASS AGAINST A
CORRECT OUTPUT.  Thirty prose needles were written the way the sentences read in
the source, and prose in a fixed-width report WRAPS -- a sentence that reads as
one phrase in an editor is two lines in the file, and the second line begins in
column 0, so "and the read-modify-write race is named" could never match a line
that ended at "and its".  The fix is not to shorten the needles: it is that
prose assertions run against a whitespace-flattened copy and TABLE-ROW
assertions run against the raw text, because a flattened table row is a lie
about which columns held what.  And the harness's retractions count is now read
from the artifact rather than asserted, for the same reason.

  Three more of this course's checks exist because the FIRST version of them
  passed against output that was wrong, and they are named here because a
  verifier that does not know about them will eventually remove them as
  redundant:

    * the record table's code column is cross-checked against the psABI table
      BY NAME, after stripping the `R_RISCV_` prefix -- changing a record's
      code from 23 to 99 was invisible to the earlier version;
    * the S-type arithmetic is parsed and checked, because renaming `rs2` to
      `rd` in the equation block passed every other check in the file;
    * and eighteen claim sentences in the two scope lists are PINNED WHOLE,
      because a substring check passes over "That a page is ever walked"
      edited to "That a page is walked, always".
"""

import collections
import html
import json
import os
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "rvpriv"

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

# --- the artifact's OWN recorded run, and the four poisons -----------------
# Read the SHIPPED rvpriv.out rather than re-running the artifact: a verifier
# that re-measures is a second experiment, and this one is about whether the
# course's COMMITTED claims are still true.
_out = os.path.join('courses', COURSE, 'assets', 'samples', 'rvpriv.out')
if not os.path.isfile(_out):
    bad.append('rvpriv.out is not committed -- the course\'s claims would be '
               'checkable only on the machine that produced them')
else:
    t = open(_out, errors='replace').read()

    # THE THREE LABELS, and their spelling.  Rule 13, and the check is on the
    # exact strings because "a label rendered two ways is not a label" -- if
    # the artifact grows a second spelling of MEASURED the counts below stop
    # adding up and the provenance table's own summary line stops being
    # checkable.  Each count is printed so a reader can see that the course is
    # actually USING the categories rather than having invented the table.
    for lab in ('MEASURED', 'MEASURED-ON-BYTES', 'QUOTED'):
        n = len(re.findall(r'\b%s\b' % lab, t))
        if n == 0:
            bad.append('the label %s never appears in rvpriv.out' % lab)
    print('  --  labels: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED'
          % (len(re.findall(r'\bMEASURED\b', t)),
             len(re.findall(r'\bMEASURED-ON-BYTES\b', t)),
             len(re.findall(r'\bQUOTED\b', t))))

    # The three-target table must be labelled a compile-time count and not a
    # timing, and it must name BOTH of the x86-64 section's ratios in order to
    # say it has no counterpart for them.  A course that silently omitted the
    # ratios would pass a weaker check; the sentence is the claim.
    # THE RATIO CHECK IS INVERTED AGAINST THE SIBLING.  rvabi labels one table
    # "IT IS NOT A TIMING AND NOT A SPEEDUP"; this course has no cross-
    # architecture table at all, so there is nothing to label and requiring the
    # string would assert a table that does not exist.  What is required
    # instead is the ABSENCE claim, which is the stronger one: not one
    # instruction ran, which is a statement about every number in the file
    # rather than about one caption.
    if 'NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN RUN' not in t:
        bad.append('the artifact does not state that not one instruction has '
                   'been run, so its absence claim is in a caption somewhere '
                   'rather than in its header')
    for phrase in ('NO EXCEPTION IS EVER TAKEN', 'NO PAGE IS EVER WALKED',
                   'NO TLB IS EVER CONSULTED'):
        if phrase not in t:
            bad.append('the artifact never says %r -- and this is the whole '
                       'scope of the course' % phrase)
    if not ('4.92x' in t and '27.65x' in t and
            'NO COUNTERPART HERE' in t):
        bad.append('the x86-64 section\'s 4.92x and 27.65x are not named and '
                   'explicitly disclaimed')

    # The four poison verdicts.  Plan rule 15: each poison must MOVE the
    # number it claims to test, and a run that printed no verdict at all is
    # not a passing run -- it is a run where the control did not run.
    for n, name in ((1, 'remove both prepended models'),
                    (2, 'break half of r_info'),
                    (3, 'defy the length rule'),
                    (4, 'hide the disagreements')):
        if ('POISON %d FIRED' % n) not in t:
            bad.append('poison %d (%s) did not report FIRED in rvpriv.out'
                       % (n, name))

    # Each poison's DELTA, in the four spellings this artifact uses.  All are
    # required to be NON-ZERO, because a control that cannot move is a comment
    # that says the word POISONED.
    #
    # Poison 1 is the interesting one and gets three numbers rather than two,
    # because it is the only poison in the collection that moves two of them
    # in OPPOSITE directions: the unmodelled count FALLS and the disagreement
    # count RISES over the same removal.  A check that only required "non-zero"
    # would pass on a delta of +1 and would not notice that the direction is
    # the finding, so the sign relationship is asserted here too.
    p1 = re.search(r'DELTA: named ([+-]\d+), disagreements ([+-]\d+), '
                   r'unmodelled ([+-]\d+)', t)
    p2r = re.search(r'names that match the psABI table : (\d+)', t)
    p2w = re.search(r'the WRONG way, values that name a real type\s+: (\d+)', t)
    p3 = re.search(r'^\s+DELTA: ([+-]\d+)$', t, re.M)
    p4 = re.search(r'DELTA: (\d+) of the (\d+) planted disagreements were '
                   r'HIDDEN', t)
    for label, mm, grp in (('1 named', p1, 1),
                           ('1 disagreements', p1, 2),
                           ('1 unmodelled', p1, 3),
                           ('3 length rule', p3, 1),
                           ('4 hidden', p4, 1)):
        if not mm:
            bad.append('no poison %s figure in rvpriv.out' % label)
        elif int(mm.group(grp)) == 0:
            bad.append('poison %s reports a delta of ZERO -- the control did '
                       'not move' % label)
    if p1 and p2r and p2w and p3 and p4:
        print('\nPOISONS, all four FIRED and all four non-zero:')
        print('  1  remove both models  named %s, disagreements %s, '
              'unmodelled %s' % p1.groups())
        print('     -- two of those move in OPPOSITE directions, which is the '
              'finding')
        print('  2  break half r_info   %s names lost, %s silently misnamed'
              % (p2r.group(1), p2w.group(1)))
        print('  3  defy the length rule  %s instructions' % p3.group(1))
        print('  4  hide the check      %s of %s real disagreements hidden'
              % (p4.group(1), p4.group(2)))
    if p1 and not (int(p1.group(2)) > 0 > int(p1.group(3))):
        bad.append('poison 1 does not move its disagreement and unmodelled '
                   'counts in OPPOSITE directions -- which is its whole claim')

    # The two-reader cross-check's own headline numbers.
    if not re.search(r'^\s+0  DISAGREE', t, re.M):
        bad.append('the cross-check does not report zero disagreements')
    unmod = re.search(r'^\s+(\d+)  unmodelled -- counted, never dropped', t,
                      re.M)
    if not unmod:
        bad.append('the cross-check does not report an UNMODELLED count, so a '
                   'reader cannot tell a hole from an agreement')
    elif int(unmod.group(1)) == 0:
        bad.append('the cross-check names every instruction and nothing is '
                   'unmodelled -- which would mean the corpus was too easy')

    # The normalisation fire table, and this course INVERTS the sibling's check.
    # rvabi's table is INHERITED and carries rules its corpus does not
    # exercise, so a healthy run there leaves some rules DEAD and the file
    # prints INVESTIGATE beside each.  This course's two rules were both
    # written FOR this corpus and are PRE-SEEDED into the table, so the healthy
    # state is zero dead -- and the sibling's condition inverted here would
    # have required dead rules this artifact does not have.
    norm = re.search(r'(\d+) rules, (\d+) fired, (\d+) matched nothing', t)
    if not norm:
        bad.append('no normalisation fire table in rvpriv.out')
    elif norm.group(3) != '0':
        bad.append('normalisation: %s of %s rules fired and %s are DEAD -- '
                   'this course PRE-SEEDS its rules, so a dead rule is a rule '
                   'nobody tested' % (norm.group(2), norm.group(1),
                                      norm.group(3)))
    elif norm.group(1) != norm.group(2):
        bad.append('normalisation: the fire table prints %s rules but only %s '
                   'fired, and the counts do not add up'
                   % (norm.group(1), norm.group(2)))
    else:
        print('  --  all %s normalisation rules fired, %s dead, and the table '
              'is PRE-SEEDED so a rule that never fires is a row with a zero'
              % (norm.group(1), norm.group(3)))

    # The CLASSIFIER, and the reason it is printed on a run where it found
    # nothing.  rvabi could assert its classifier is present; this artifact
    # goes further and separates "ran and found nothing" from "did not run",
    # which is the distinction R12 is about, so it is checked here too.
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
                             'rvpriv.py'), errors='replace').read()
    _i = _src.find('RETRACTIONS = [')
    _j = _src.find('RET_SOURCES = {', _i)
    declared = re.findall(r"^    \('(R\d+)',", _src[_i:_j], re.M) \
        if _i >= 0 and _j > _i else []
    got = re.findall(r'^  (R\d+)  CLAIMED:', t, re.M)
    n = len(declared)
    want = ['R%d' % k for k in range(1, n + 1)]
    if n < 17:
        bad.append('the artifact declares %d retractions; this verifier was '
                   'written against seventeen and a course that has lost them '
                   'should fail loudly' % n)
    elif got != want:
        bad.append('retractions: found %d (%s) in rvpriv.out, expected %d '
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
    # Each retraction must carry a SOURCE line, and every one of them must say
    # the defect was found by THIS course or its plan rather than in someone
    # else's code -- with the two exceptions the artifact names, R14 (the
    # SIBLING's decoder) and R17 (this course's own correction to R16).
    srcs = re.findall(r'^        SOURCE: (.+)$', t, re.M)
    if len(srcs) != n:
        bad.append('retractions: %d SOURCE lines for %d retractions -- a '
                   'retraction with no source is a course disagreeing with '
                   'itself' % (len(srcs), n))
    if not any('SIBLING' in x for x in srcs):
        bad.append('no retraction names the SIBLING decoder as where R14\'s '
                   'defect lives, so the honest one may have been rewritten')

    # The twelve limits, ENUMERATED AND NUMBERED, and the corpus-completeness
    # sentence.  The numbering is checked with the same pattern the harness
    # uses, because the first version of the artifact printed them with a
    # right-aligned `%2d` and no list could find its own numbers.
    lim = re.findall(r'^  (\d+)\. ', t, re.M)
    if len(lim) < 16 or lim[:16] != [str(i) for i in range(1, 17)]:
        bad.append('the limits are not numbered 1..16 at the start of a line '
                   '(found %d)' % len(lim))
    if 'THE CORPUS IS INCOMPLETE' not in t:
        bad.append('the corpus-completeness check does not print its own '
                   'verdict on a complete run, so it can only be exercised on '
                   'a broken artifact')

    # THE TWO SCOPE LISTS, which the sibling has no equivalent of, because the
    # sibling's absence is a timing and this one's is the SUBJECT.  Eight
    # cannot-conclude items and ten can-conclude items, and the second list
    # being the longer one is the finding, so both the counts and the ORDERING
    # are asserted: a course that quietly inverted the two lists would satisfy
    # a count-only check.
    flat_t = re.sub(r'\s+', ' ', t)
    _hc = 'A READER THEREFORE CANNOT CONCLUDE is a different thing'
    _hk = 'teaches its reader that the subject is unknowable'
    _he = 'WHICH IS THE POINT: there is more that can be read'
    if not all(x in flat_t for x in (_hc, _hk, _he)):
        bad.append('the two scope lists are not both present in rvpriv.out, '
                   'and one of them is missing entirely')
    else:
        _blk = flat_t[flat_t.index(_hc):flat_t.index(_hk)]
        _can = flat_t[flat_t.index(_hk):flat_t.index(_he)]
        _nc = len(re.findall(r'\* ', _blk))
        _ny = len(re.findall(r'\* ', _can))
        if (_nc, _ny) != (8, 10):
            bad.append('the scope lists carry %d cannot and %d can items, '
                       'expected 8 and 10' % (_nc, _ny))
        elif not _ny > _nc:
            bad.append('the can-list is not longer than the cannot-list, and '
                       'that ordering IS the finding')
        else:
            print('  --  scope lists: %d cannot-conclude, %d can-conclude, and '
                  'the second is the longer one' % (_nc, _ny))
    # And the eighteen claim sentences are pinned whole in the HARNESS, not
    # here.  This verifier checks that the harness actually ran and agreed; the
    # pinning is a property of crosscheck.py and duplicating it here would be
    # two places to edit for one claim.

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

print('\n' + '=' * 70)
if bad:
    print('  %d PROBLEMS' % len(bad))
    for b in bad:
        print('   - %s' % b)
else:
    print('  ALL CONSISTENT: %d concepts, %d links, chain, minutes, three '
          'labels, four non-zero poison deltas with poison 1 moving in two '
          'directions, %d retractions with a SOURCE each, %d numbered limits, '
          'and two scope lists of 8 and 10 verified'
          % (len(pages), len(real), n, 16))
print('=' * 70)
sys.exit(1 if bad else 0)
