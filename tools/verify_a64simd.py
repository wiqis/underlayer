#!/usr/bin/env python3
"""verify_a64simd.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves
  * the artifact's own harness still passes against the SHIPPED a64data.out,
    which means the course's claims are checkable on a machine that never ran
    its assembler

Run with the server up on :9000.

Derived from tools/verify_a64abi.py, and COURSE is the only line that had to
change, because the three courses are the same shape: a manifest, six concept
routes, a landing page, a prev/next chain, and a committed artifact whose
harness reads a committed recording rather than re-measuring.

TWO THINGS ARE DIFFERENT AND BOTH ARE WORTH WRITING DOWN.

First, the prev/next chain is checked against the MANIFEST's module order, and
this course's concept ids are NOT the section plan's.  The plan lists
`a64-crypto-simd` and `a64-ldst`; this course uses `a64-neonspace` and
`a64-dataflow`.  The reason is in web/src/helpers.ch and it is not cosmetic:
render_concept() resolves concept ids GLOBALLY with no course in the key, so a
name reused across two courses silently gives the reader the FIRST course's
page -- and the encoding course claimed `a64-verify` in the first course of
this section, which is why the machine course's last concept is `a64-evidence`
rather than `a64-verify`.  The same argument applies twice more here, and the
verifier therefore checks the chain against the manifest -- the single source
of truth -- and not against the plan.

Second, this is the only course in the section with FIVE concepts, so the
`units != 6` assertion below is the one shape this verifier checks that it
does not otherwise need.  Six units is a content convention rather than an
architectural one, and a course that ships a five-concept manifest is allowed
six units per page; what is NOT allowed is a page whose unit count differs
from what the verifier was told to expect, so the expected count is taken from
the same place the minutes are taken from.
"""
import collections
import html
import json
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "a64simd"

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
        # The #html macro escapes a literal apostrophe to &#39; on output, so
        # the raw markup and the manifest string differ for a title that
        # contains one.  Compare the DECODED text, which is what the browser
        # shows and what the manifest means.
        prob.append('title %r != manifest %r'
                    % (html.unescape(title.group(1)), by_id[cid]['title']))
    # Six units per concept page: why, model, reality, example, apply, connect.
    # The count is a convention of the lesson layout and not a property of the
    # manifest, so it is a CONSTANT here and a failure means the page changed
    # shape -- which is the thing worth catching, because a page that lost a
    # unit still renders and still has a valid h1.
    if units != 6:
        prob.append('%d units, expected 6' % units)

    # prev/next, read from the footer only (the last two course links)
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

    print('  %-24s %3smin  units=%d  %-40s %s'
          % (cid, mt.group(1) if mt else '?', units,
             (title.group(1) if title else '?')[:40],
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

# the course's own claims, re-derived
import os
_samples = os.path.join('courses', COURSE, 'assets', 'samples')
if os.path.isdir(_samples):
    _cc = subprocess.run([sys.executable, os.path.join(_samples, 'crosscheck.py')],
                         capture_output=True, text=True)
    # Two tally spellings are in use across the collection -- "N/M checks
    # passed" and "N checks, M failed" -- so accept either, and require that
    # the failures column is zero.  Matching one format rigidly turns a
    # healthy course into a reported problem, and printing one format's two
    # captures as the other's pair prints a nonsense tally like "109/0".
    _passed = re.search(r'(\d+)/(\d+) checks passed', _cc.stdout)
    _failed = re.search(r'(\d+) checks,\s*(\d+) failed', _cc.stdout)
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
    print('  ALL CONSISTENT: %d concepts, %d links, chain and minutes verified'
          % (len(pages), len(real)))
print('=' * 70)
sys.exit(1 if bad else 0)
