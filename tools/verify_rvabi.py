#!/usr/bin/env python3
"""verify_rvabi.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves
  * the artifact's own harness still passes against the SHIPPED rvabi.out,
    which means the course's claims are checkable on a machine that never ran
    its assembler
  * the four POISONS all report FIRED and all four DELTAS are non-zero
  * all TWELVE retractions are present by name

Run with the server up on :9000.

Derived from tools/verify_rvasm.py, and COURSE is the only line that had to
change -- the courses are the same shape: a manifest, four concept routes, a
landing page, a prev/next chain, and a committed artifact whose harness reads
a committed recording rather than re-measuring.

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

THIRD, the retraction count is twelve rather than twenty-two, and the ids are
R1 through R12 with no gaps.  The check is on the ids rather than on a count
alone: a course whose retractions were renumbered would still have twelve, and
the gap would be the only thing that shows.

FOURTH, and it is why this course ships a repaired harness: `crosscheck.py`
had ONE unsatisfiable check in it.  The m18 row's third group was `(\\S+)` and
the assertion underneath compared it against the string "0, 8", which contains a
space -- so no output could ever pass it, and the check failed against a
correct measurement.  The group was widened to `(\\S.*?)` and the equality
test was left exactly as it was.  A verifier that re-measures would not have
caught that, because the measurement was right; only running the harness did.
"""

import collections
import html
import json
import os
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "rvabi"

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
# Read the SHIPPED rvabi.out rather than re-running the artifact: a verifier
# that re-measures is a second experiment, and this one is about whether the
# course's COMMITTED claims are still true.
_out = os.path.join('courses', COURSE, 'assets', 'samples', 'rvabi.out')
if not os.path.isfile(_out):
    bad.append('rvabi.out is not committed -- the course\'s claims would be '
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
            bad.append('the label %s never appears in rvabi.out' % lab)
    print('  --  labels: %d MEASURED, %d MEASURED-ON-BYTES, %d QUOTED'
          % (len(re.findall(r'\bMEASURED\b', t)),
             len(re.findall(r'\bMEASURED-ON-BYTES\b', t)),
             len(re.findall(r'\bQUOTED\b', t))))

    # The three-target table must be labelled a compile-time count and not a
    # timing, and it must name BOTH of the x86-64 section's ratios in order to
    # say it has no counterpart for them.  A course that silently omitted the
    # ratios would pass a weaker check; the sentence is the claim.
    if 'IT IS NOT A TIMING AND NOT A SPEEDUP' not in t:
        bad.append('the three-target table is not labelled as a count and not '
                   'a speedup')
    if not ('4.92x' in t and '27.65x' in t and
            'NO COUNTERPART HERE' in t):
        bad.append('the x86-64 section\'s 4.92x and 27.65x are not named and '
                   'explicitly disclaimed')

    # The four poison verdicts.  Plan rule 15: each poison must MOVE the
    # number it claims to test, and a run that printed no verdict at all is
    # not a passing run -- it is a run where the control did not run.
    for n, name in ((1, 'remove both corrections'), (2, 'remove one'),
                    (3, 'supply the length'), (4, 'break the check')):
        if ('POISON %d FIRED' % n) not in t:
            bad.append('poison %d (%s) did not report FIRED in rvabi.out'
                       % (n, name))

    # Each poison's DELTA, in the four spellings this artifact uses.  All four
    # are required to be NON-ZERO, because a control that cannot move is a
    # comment that says the word POISONED.
    p1 = re.search(r'named [+-]\d+, disagreements ([+-]\d+), unmodelled ([+-]\d+)', t)
    p2 = re.search(r'DELTA: named [+-]\d+, disagreements [+-]\d+, '
                   r'unmodelled ([+-]\d+)', t)
    p3 = re.search(r'^\s+DELTA: ([+-]\d+)$', t, re.M)
    p4 = re.search(r'DELTA: (\d+) of the (\d+) planted disagreements were '
                   r'HIDDEN', t)
    for label, mm, grp in (('1 disagreements', p1, 1),
                           ('1 unmodelled', p1, 2),
                           ('2 unmodelled', p2, 1),
                           ('3 length rule', p3, 1),
                           ('4 hidden', p4, 1)):
        if not mm:
            bad.append('no poison %s figure in rvabi.out' % label)
        elif int(mm.group(grp)) == 0:
            bad.append('poison %s reports a delta of ZERO -- the control did '
                       'not move' % label)
    if p1 and p2 and p3 and p4:
        print('\nPOISONS, all four FIRED and all four non-zero:')
        print('  1  remove both      disagreements %s, unmodelled %s'
              % (p1.group(1), p1.group(2)))
        print('  2  remove one       unmodelled   %s' % p2.group(1))
        print('  3  supply the length  %s instructions' % p3.group(1))
        print('  4  break the check    %s of %s real disagreements hidden'
              % (p4.group(1), p4.group(2)))

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

    # The normalisation fire table.  The check is that some rules are DEAD and
    # that the file says why, because the inherited rvasm table carries rules
    # this corpus does not exercise.  A verifier that required "zero dead
    # rules" would be asserting something false about a healthy artifact.
    norm = re.search(r'(\d+) rules, (\d+) fired, (\d+) matched nothing', t)
    if not norm:
        bad.append('no normalisation fire table in rvabi.out')
    elif norm.group(2) == norm.group(1) or norm.group(3) == '0':
        bad.append('normalisation: %s of %s rules fired, %s dead -- this '
                   'corpus is expected to leave some rules unexercised'
                   % (norm.group(2), norm.group(1), norm.group(3)))
    elif 'INVESTIGATE' not in t:
        bad.append('there are dead normalisation rules and the report never '
                   'prints INVESTIGATE, so a rule with no reason is not '
                   'distinguished from one with a reason')
    else:
        print('  --  %s of %s normalisation rules fired, %s dead and each '
              'with a reason' % (norm.group(2), norm.group(1), norm.group(3)))

    # All twelve retractions present by name, with no gaps, because a
    # retraction that is quietly deleted is the one failure no number catches.
    got = re.findall(r'^  (R\d+)  CLAIMED:', t, re.M)
    want = ['R%d' % i for i in range(1, 13)]
    if got != want:
        bad.append('retractions: found %d (%s), expected 12 R1..R12 with no '
                   'gaps' % (len(got), ','.join(got)))
    else:
        print('  --  all 12 retractions present by name, R1..R12, no gaps')

    # The twelve limits, ENUMERATED AND NUMBERED, and the corpus-completeness
    # sentence.  The numbering is checked with the same pattern the harness
    # uses, because the first version of the artifact printed them with a
    # right-aligned `%2d` and no list could find its own numbers.
    lim = re.findall(r'^  (\d+)\. ', t, re.M)
    if len(lim) < 12 or lim[:12] != [str(i) for i in range(1, 13)]:
        bad.append('the limits are not numbered 1..12 at the start of a line '
                   '(found %d)' % len(lim))
    if 'THE CORPUS IS INCOMPLETE' not in t:
        bad.append('the corpus-completeness check does not print its own '
                   'verdict on a complete run, so it can only be exercised on '
                   'a broken artifact')

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
          'labels, four non-zero poison deltas, 12 retractions and 12 '
          'numbered limits verified' % (len(pages), len(real)))
print('=' * 70)
sys.exit(1 if bad else 0)
