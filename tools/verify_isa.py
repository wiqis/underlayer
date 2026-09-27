#!/usr/bin/env python3
"""verify_isa.py -- assert the course is internally consistent:

  * every manifest concept has a live route that renders its own title
  * the page's stated minutes match the manifest
  * the prev/next footer chain matches the manifest module order
  * every internal link on every page resolves

Run with the server up on :9000.
"""
import collections
import html
import json
import re
import subprocess
import sys

BASE = 'http://localhost:9000'
COURSE = "isa"

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
        # contains one. Compare the DECODED text, which is what the browser
        # shows and what the manifest means. jvm/lessons/jvm-stackmaps has
        # this exact situation and no verifier, so it was never caught.
        prob.append('title %r != manifest %r'
                    % (html.unescape(title.group(1)), by_id[cid]['title']))
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

    print('  %-24s %3smin  units=%d  %-36s %s'
          % (cid, mt.group(1) if mt else '?', units,
             (title.group(1) if title else '?')[:36],
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
    _m = re.search(r'(\d+)/(\d+) checks passed', _cc.stdout)
    if _cc.returncode != 0 or not _m or _m.group(1) != _m.group(2):
        bad.append('crosscheck.py: %s' % (_cc.stdout.strip().splitlines()[-1]
                                          if _cc.stdout else _cc.stderr[:60]))
    else:
        print('\ncrosscheck.py: %s/%s measured claims still hold' % _m.groups())

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
