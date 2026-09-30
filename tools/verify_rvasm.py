#!/usr/bin/env python3
"""verify_rvasm.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves
  * the artifact's own harness still passes against the SHIPPED rvdec.out,
    which means the course's claims are checkable on a machine that never ran
    its assembler

Run with the server up on :9000.

Derived from tools/verify_a64simd.py, and COURSE is the only line that had to
change, because the courses are the same shape: a manifest, five concept
routes, a landing page, a prev/next chain, and a committed artifact whose
harness reads a committed recording rather than re-measuring.

THREE THINGS ARE DIFFERENT FROM THE AArch64 VERIFIERS AND ALL THREE ARE
WORTH WRITING DOWN, because each is a shape the verifier has to know about
rather than guess.

First, the prev/next chain is checked against the MANIFEST's module order and
not against the section plan, for the reason tools/verify_a64simd.py records
and which applies here with an extra twist: render_concept() resolves concept
ids GLOBALLY with no course in the key, so two courses cannot share a name.
`docs/riscv-section-plan.md` gives the id `rv-verify` to BOTH this course and
the privileged-architecture course (`rvpriv`, concept 13), so whichever of the
two is built second has to be named for something else.  This one takes
`rv-verify` because its artifact IS a verification; the note above
`render_rvasm_concept` in web/src/helpers.ch records which one got it and
why.  The verifier therefore checks the chain against the manifest, which is
the single source of truth.

Second, the HARNESS TALLY.  This course's `crosscheck.py` prints "N checks,
M failures" and the AArch64 ones print "N/M checks passed", so both spellings
are accepted below for the same reason verify_a64simd.py accepts both: a
verifier that matches one format rigidly turns a healthy course into a
reported problem, and a check that reports a problem nobody can act on
trains its reader to ignore it.

Third, and this is the one that is specific to RISC-V: the artifact's own
report carries FOUR POISON VERDICTS and this verifier checks that all four
say FIRED.  A harness that reads "0 disagreements" and stops has learned
nothing, because the number that makes 0 meaningful is the four deltas.  This
is plan rule 15 and it is the reason the check is here rather than in the
harness alone -- the harness asserts the delta values, and this asserts that
the run it read them from actually produced verdicts rather than silence.
"""
import collections
import html
import json
import os
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "rvasm"

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
# Read the SHIPPED rvdec.out rather than re-running the artifact: a verifier
# that re-measures is a second experiment, and this one is about whether the
# course's COMMITTED claims are still true.
_out = os.path.join('courses', COURSE, 'assets', 'samples', 'rvdec.out')
if not os.path.isfile(_out):
    bad.append('rvdec.out is not committed -- the course\'s claims would be '
               'checkable only on the machine that produced them')
else:
    t = open(_out, errors='replace').read()

    # The four poison verdicts.  Plan rule 15: each poison must MOVE the
    # number it claims to test, and a run that printed no verdict at all is
    # not a passing run -- it is a run where the control did not run.
    for n, name in ((1, 'remove a model'), (2, 'flip bit 12'),
                    (3, 'replace the length rule'), (4, 'plant and hide')):
        if ('POISON %d FIRED' % n) not in t:
            bad.append('poison %d (%s) did not report FIRED in rvdec.out'
                       % (n, name))

    # Each poison's delta, printed so a reader sees a NUMBER and not a word.
    d1 = re.search(r'VERDICT: POISON 1 FIRED on all (\d+) victims', t)
    d2 = re.search(r'VERDICT: POISON 2 FIRED\.  total movement = (\d+)', t)
    d3 = re.search(r'VERDICT: POISON 3 FIRED\.  delta = (\d+)', t)
    d4 = re.search(r'DELTA: (\d+) of the (\d+) planted disagreements', t)
    for label, mm in (('1 victims', d1), ('2 movement', d2),
                      ('3 delta', d3), ('4 hidden', d4)):
        if not mm:
            bad.append('no %s figure in rvdec.out' % label)
        elif int(mm.group(1)) == 0:
            bad.append('poison %s reports a delta of ZERO -- the control did '
                       'not move' % label)
    if d1 and d2 and d3 and d4:
        print('\nPOISONS, all four FIRED and all four non-zero:')
        print('  1  remove a model    %s victims, deltas above'
              % d1.group(1))
        print('  2  flip bit 12       %s instructions changed format'
              % d2.group(1))
        print('  3  length rule      %s instructions' % d3.group(1))
        print('  4  plant then hide   %s of %s real disagreements hidden'
              % (d4.group(1), d4.group(2)))

    # The cross-check's own headline numbers, and the dead-rule count.
    if not re.search(r'^\s+0  DISAGREE', t, re.M):
        bad.append('the cross-check does not report zero disagreements')
    norm = re.search(r'(\d+) rules, (\d+) fired, (\d+) matched nothing', t)
    if not norm:
        bad.append('no normalisation fire table in rvdec.out')
    elif norm.group(2) != norm.group(1) or norm.group(3) != '0':
        bad.append('normalisation: %s of %s rules fired, %s matched nothing'
                   % (norm.group(2), norm.group(1), norm.group(3)))
    else:
        print('  --  %s of %s normalisation rules fired, %s dead'
              % (norm.group(2), norm.group(1), norm.group(3)))

    # All twenty-two retractions present by name, because a retraction that
    # is quietly deleted is the one failure no number can catch.
    got = re.findall(r'^  (R\d+)  ', t, re.M)
    want = ['R%d' % i for i in range(1, 23)]
    if got != want:
        bad.append('retractions: found %d (%s), expected 22 R1..R22'
                   % (len(got), ','.join(got)))
    else:
        print('  --  all 22 retractions present by name')

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
    print('  ALL CONSISTENT: %d concepts, %d links, chain, minutes, four '
          'poisons and 22 retractions verified' % (len(pages), len(real)))
print('=' * 70)
sys.exit(1 if bad else 0)
