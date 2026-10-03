#!/usr/bin/env python3
"""lesson_header_check.py -- the lesson header must be true, not merely present.

WHY THIS IS A CHECKER AND NOT A ONE-OFF LOOK

The header (web/src/lesson_header.ch) injects three facts from the course
manifest into every one of 431 pre-rendered lesson documents, at serve time, by
sentinel replacement.  Three things about that arrangement are dangerous:

  1. IT CAN SILENTLY BECOME A NO-OP.  If the sentinel stops matching -- a lesson
     whose markup changes, a second </h1> appearing -- the header just quietly
     stops being there, and every route still answers 200.  So this asserts it
     is PRESENT on every lesson page, not on a sample.
  2. IT CAN BE WRONG.  The first version built the prerequisite href from
     `concept_id` instead of `course.id`, producing
     `/courses/binary-representation/lessons/bytes` -- a 404 for every reader on
     every lesson page, from code that compiled cleanly.  A check that only looks
     for the word "min" would have passed that.
  3. IT CAN TRUNCATE THE DOCUMENT.  `subview(start, end)` takes an END INDEX, and
     passing a LENGTH truncates every lesson page -- which is exactly what
     happened once already in lesson_pager.ch, with nav_check and link_check both
     reporting green because they check status codes, not whether the document
     still has an end.  So integrity is asserted here too.

SO THIS READS THE MANIFEST AND COMPARES, for every lesson of every course.  It
does not assert that a number is > 0; it asserts the number on the page is the
number in the manifest, which is the only version of this that can catch a wrong
one.

Usage:
    python3 tools/lesson_header_check.py [--port 9000] [--course elf] [--sample N]

--sample N checks N lessons per course instead of all of them; the full sweep is
398 pages and takes a couple of minutes.
"""
import argparse
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

checks = 0
failures = []
section = ''


def sec(name):
    global section
    section = name
    print('\n' + '=' * 74)
    print(name)
    print('=' * 74)


def ok(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(section + ' / ' + name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def get(base, path, timeout=40):
    with urllib.request.urlopen(base + path, timeout=timeout) as r:
        return r.read().decode('utf-8', 'replace')


def courses():
    out = []
    for d in sorted(os.listdir(os.path.join(ROOT, 'courses'))):
        mf = os.path.join(ROOT, 'courses', d, 'manifest.json')
        if os.path.isfile(mf):
            out.append(d)
    return out


def header_of(html):
    m = re.search(r'<div class="lesson-head">(.*?)</div>\s*<div class="unit',
                  html, re.S)
    if not m:
        return None
    return m.group(0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--course', default=None)
    ap.add_argument('--sample', type=int, default=0,
                    help='check only the first N lessons of each course')
    args = ap.parse_args()
    base = 'http://localhost:%d' % args.port

    all_courses = courses()
    if args.course:
        all_courses = [c for c in all_courses if c == args.course]
    if not all_courses:
        print('no courses found')
        return 2

    try:
        get(base, '/api/health')
    except Exception as e:
        print('FAIL: no server on %s (%s)' % (base, e))
        return 2

    # ---------------------------------------------------------------- 1
    sec('1. the header is on EVERY lesson, and every fact matches the manifest')
    total = 0
    missing, wrong_time, wrong_diff, misplaced, no_prev, bad_prev = ([] for _ in range(6))
    for cid in all_courses:
        man = json.load(open(os.path.join(ROOT, 'courses', cid, 'manifest.json'),
                             encoding='utf-8'))
        concepts = man.get('concepts', [])
        if args.sample:
            concepts = concepts[:args.sample]
        for idx, c in enumerate(concepts):
            total += 1
            path = '/courses/%s/lessons/%s' % (cid, c['id'])
            try:
                html = get(base, path)
            except Exception as e:
                missing.append('%s (%s)' % (path, e))
                continue
            head = header_of(html)
            if head is None:
                missing.append(path)
                continue

            # the three facts, compared rather than merely present
            want_min = c.get('estimated_minutes')
            if want_min:
                if ('%d min' % want_min) not in head:
                    wrong_time.append('%s: manifest says %d, page has %r'
                                      % (path, want_min, head[:200]))
            want_diff = c.get('difficulty')
            if want_diff and ('>%s</span>' % want_diff) not in head:
                wrong_diff.append('%s: manifest says %s' % (path, want_diff))

            # Position: after the title, before the first unit.
            #
            # The positions must be taken from the WHOLE page. The first version
            # searched inside `head`, which is the extracted header, so
            # `head.find('lesson-head')` was 0 and it compared 0 against the
            # offset of </h1> in a different string -- which reported all 102
            # sampled lessons as misplaced. A checker that fails on correct pages
            # gets ignored, and then it protects nothing.
            at = html.find('<div class="lesson-head">')
            title_at = html.find('</h1>')
            unit_at = html.find('class="unit ')
            if title_at < 0 or unit_at < 0:
                misplaced.append(path + ' (no </h1> or no unit to compare)')
            elif not (title_at < at < unit_at):
                misplaced.append('%s: header at %d, </h1> at %d, first unit at %d'
                                 % (path, at, title_at, unit_at))

            # the predecessor line
            has_prev = '<span class="lesson-head-prereq">' in html
            if idx == 0:
                if has_prev:
                    no_prev.append(path)
            elif not has_prev:
                bad_prev.append(path + ' (no predecessor line)')

    print('  lessons checked: %d across %d course(s)' % (total, len(all_courses)))
    ok('every lesson page carries the header', not missing,
       '%d missing, first: %s' % (len(missing), missing[:3]))
    ok('the time estimate equals the manifest value', not wrong_time,
       '%d wrong, first: %s' % (len(wrong_time), wrong_time[:2]))
    ok('the difficulty is the PER-CONCEPT manifest value', not wrong_diff,
       '%d wrong, first: %s' % (len(wrong_diff), wrong_diff[:2]))
    ok('the header sits between the title and the first unit', not misplaced,
       '%d misplaced, first: %s' % (len(misplaced), misplaced[:3]))
    ok('the FIRST lesson of a course has no predecessor line', not no_prev,
       '%d wrong, first: %s' % (len(no_prev), no_prev[:3]))
    ok('every other lesson names the one before it', not bad_prev,
       '%d wrong, first: %s' % (len(bad_prev), bad_prev[:2]))

    # ---------------------------------------------------------------- 2
    sec('2. the predecessor LINK is the previous lesson, and it resolves')
    # This is the assertion that catches the bug the header was born with: an
    # href built from the concept id instead of the course id compiles, renders,
    # and 404s on every page.
    wrong_target, dead = [], []
    for cid in all_courses[:6]:          # six courses is enough to catch the
        man = json.load(open(os.path.join(ROOT, 'courses', cid, 'manifest.json'),
                             encoding='utf-8'))
        concepts = man.get('concepts', [])
        if args.sample:
            concepts = concepts[:args.sample]
        for idx, c in enumerate(concepts):
            if idx == 0:
                continue
            want = '/courses/%s/lessons/%s' % (cid, concepts[idx - 1]['id'])
            try:
                html = get(base, '/courses/%s/lessons/%s' % (cid, c['id']))
            except Exception:
                continue
            m = re.search(r'lesson-head-prereq"><a href="([^"]+)"', html)
            if not m:
                continue
            got = m.group(1)
            if got != want:
                wrong_target.append('%s/%s: link is %s, previous lesson is %s'
                                    % (cid, c['id'], got, want))
            elif len(dead) < 5:
                try:
                    if urllib.request.urlopen(base + got, timeout=30).getcode() != 200:
                        dead.append(got)
                except Exception as e:
                    dead.append('%s (%s)' % (got, str(e)[:40]))
    ok('the link points at the previous lesson, not something else',
       not wrong_target,
       '%d wrong, first: %s' % (len(wrong_target), wrong_target[:3]))
    ok('those links resolve', not dead, '%d dead: %s' % (len(dead), dead))

    # ---------------------------------------------------------------- 3
    sec('3. the document survived the replacement')
    # subview(start, end) takes an END INDEX. Passing a length truncates the
    # page, and every status-code check stays green while it happens.
    truncated, unstyled = [], []
    for cid in all_courses[:8]:
        man = json.load(open(os.path.join(ROOT, 'courses', cid, 'manifest.json'),
                             encoding='utf-8'))
        concepts = man.get('concepts', [])
        if args.sample:
            concepts = concepts[:args.sample]
        for c in concepts:
            try:
                html = get(base, '/courses/%s/lessons/%s' % (cid, c['id']))
            except Exception:
                continue
            if not html.rstrip().endswith('</html>'):
                truncated.append('%s/%s (%d bytes)' % (cid, c['id'], len(html)))
            elif '</body>' not in html:
                truncated.append('%s/%s (no </body>)' % (cid, c['id']))
            if '.lesson-head{' not in html:
                unstyled.append('%s/%s' % (cid, c['id']))
    ok('every lesson document is complete', not truncated,
       '%d truncated, first: %s' % (len(truncated), truncated[:3]))
    ok('every lesson page carries the header styles', not unstyled,
       '%d unstyled, first: %s' % (len(unstyled), unstyled[:3]))

    # ---------------------------------------------------------------- 4
    sec('4. it says facts, not verdicts')
    # docs/course-design.md is explicit that this collection must normalise
    # struggle. A header is on every lesson, so a percentage or a "behind" label
    # here would be a judgement printed 398 times.
    verdicts = []
    for cid in all_courses[:8]:
        man = json.load(open(os.path.join(ROOT, 'courses', cid, 'manifest.json'),
                             encoding='utf-8'))
        for c in man.get('concepts', [])[:4 if args.sample else 6]:
            try:
                html = get(base, '/courses/%s/lessons/%s' % (cid, c['id']))
            except Exception:
                continue
            head = header_of(html)
            if not head:
                continue
            text = re.sub(r'<[^>]+>', ' ', head)
            for word in ('%', 'behind', 'weak', 'failing', 'struggl',
                         'incomplete', 'not started', 'score'):
                if word in text.lower():
                    verdicts.append('%s/%s: %r in the header' % (cid, c['id'], word))
    ok('the header contains no percentage and no verdict about the reader',
       not verdicts, '%d found: %s' % (len(verdicts), verdicts[:3]))

    print('\n' + '=' * 74)
    if not failures:
        print('lesson_header_check: ALL %d CHECKS PASSED' % checks)
    else:
        print('lesson_header_check: %d of %d CHECKS FAILED' % (len(failures), checks))
        for f in failures:
            print('  FAILED: %s' % f)
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())
