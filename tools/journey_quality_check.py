#!/usr/bin/env python3
"""Check the guided lesson journey contract from served HTML only.

Standard library only. Fails loudly (exit 1) on any regression and prints a
pass/fail count. Default: the first lesson of every course returned by
GET /api/courses. Use --all for every concept of every course, or --lessons
for an explicit comma-separated course:concept list.

Examples:
    python tools/journey_quality_check.py
    python tools/journey_quality_check.py http://localhost:9001 --all
    python tools/journey_quality_check.py --lessons elf:bytes,coff:coff-intro
"""

import argparse
import concurrent.futures
import html
import json
import re
import sys
import urllib.error
import urllib.request

NO_FACT = 'No new fact to memorise - this step is about seeing the link'


def fetch(base, path):
    url = base.rstrip('/') + path
    with urllib.request.urlopen(url, timeout=20) as response:
        return response.read().decode('utf-8', 'replace')


def fetch_json(base, path):
    return json.loads(fetch(base, path))


def lesson_set(base, args):
    courses = fetch_json(base, '/api/courses')
    if args.lessons:
        out = []
        for item in args.lessons.split(','):
            item = item.strip()
            if not item:
                continue
            if ':' not in item:
                raise ValueError('lesson must be course:concept, got %r' % item)
            out.append(tuple(item.split(':', 1)))
        return out, courses
    out = []
    for course in courses:
        cid = course.get('id')
        if not cid:
            continue
        if args.all:
            detail = fetch_json(base, '/api/courses/' + cid)
            for concept in detail.get('concepts', []):
                concept_id = concept.get('id')
                if concept_id:
                    out.append((cid, concept_id))
        else:
            first = course.get('first_lesson')
            if first:
                out.append((cid, first))
    return out, courses


def attr(tag, name):
    match = re.search(r'\b' + re.escape(name) + r'="([^"]*)"', tag)
    return html.unescape(match.group(1)) if match else None


def words(value):
    return [w for w in re.split(r'\s+', value.strip()) if w]


def check_lesson(base, course, concept):
    """Return a list of failure strings; empty list means the lesson passed."""
    failures = []
    path = '/courses/%s/lessons/%s' % (course, concept)
    try:
        page = fetch(base, path)
    except (urllib.error.HTTPError, urllib.error.URLError) as exc:
        return ['GET %s failed: %s' % (path, exc)]

    shells = re.findall(r'<div class="journey-shell"[^>]*>', page)
    if len(shells) != 1:
        failures.append('expected exactly one journey-shell element, found %d' % len(shells))
    else:
        shell = shells[0]
        for name in ('course', 'concept', 'minutes', 'difficulty'):
            if not attr(shell, 'data-' + name):
                failures.append('shell is missing data-%s: %s' % (name, shell[:160]))
        if attr(shell, 'data-course') not in (course, None):
            failures.append('shell data-course is %r, expected %r' % (attr(shell, 'data-course'), course))

    # The runtime is the difference between a journey and a dead arrival card.
    # Static output files built before the runtime shipped carry the shell and
    # the hiding CSS but no jqBoot; the learner then sees no lesson at all.
    runtime_markers = (
        'function jqBoot', 'function jqStep', 'function jqUpdateContinue',
        'function jqReveal', 'function jqFinish', 'function jqPause',
        'function jqResume', 'function jqDeep', 'window.__ulJourneyDisplay',
    )
    for marker in runtime_markers:
        if marker not in page:
            failures.append('journey runtime marker missing: %s' % marker)

    # Exactly one step visible: CSS hides every unit without data-jq-current,
    # and jqStep marks only the current one.
    if '.unit:not([data-jq-current])' not in page:
        failures.append('CSS rule hiding non-current units is missing')
    for marker in ("removeAttribute('data-jq-current')", "setAttribute('data-jq-current'"):
        if marker not in page:
            failures.append('one-step runtime marker missing: %s' % marker)
    # The active unit must be moved INTO the stage; otherwise the ribbon,
    # takeaway, recall and controls all render above the teaching text.
    for marker in ('function jqStage', 'stage.appendChild(u)', 'function jqUnstage'):
        if marker not in page:
            failures.append('step staging marker missing: %s' % marker)

    # Arrival card: one aim sentence, time/difficulty/prerequisite, one action.
    if 'id="ul-journey-arrival"' not in page:
        failures.append('arrival card missing')
    if 'id="ul-journey-aim"' not in page or 'id="ul-journey-meta"' not in page:
        failures.append('arrival aim or meta line missing')
    aim = re.search(r'id="ul-journey-aim"[^>]*>(.*?)</p>', page, re.S)
    if not aim or not html.unescape(re.sub(r'<[^>]+>', '', aim.group(1))).strip():
        failures.append('arrival aim is empty')
    if page.count('id="ul-journey-start"') != 1:
        failures.append('arrival must have exactly one Start action')

    # Ribbon: Step N of M, never a percentage or a streak.
    if 'id="ul-journey-count"' not in page:
        failures.append('journey ribbon is missing')
    if "count.textContent = 'Step '" not in page or "+ ' of ' +" not in page:
        failures.append('ribbon does not report Step N of M')

    # Progressive disclosure: explicit label, not a mystery chevron.
    if 'Show the full detail' not in page:
        failures.append('labelled Show the full detail control is missing')

    # Tiny action before Continue; "I am stuck" always unlocks the gate.
    cont = re.search(r'<button[^>]*id="ul-journey-continue"[^>]*>', page)
    if not cont or 'disabled' not in cont.group(0):
        failures.append('Continue must start disabled until the step action is done')
    for marker in ('function jqUpdateContinue', 'function jqMarkAction',
                   "btn.disabled = !ok", "I'm stuck - show me", 'function jqReveal'):
        if marker not in page:
            failures.append('action/gate marker missing: %s' % marker)

    # Mandatory takeaway, <= 25 words, never an arbitrary emphasis fragment.
    unit_tags = re.findall(r'<div class="unit unit-[^"]*"[^>]*>', page)
    if len(unit_tags) < 2:
        failures.append('lesson has fewer than two semantic units')
    for tag in unit_tags:
        unit_id = attr(tag, 'class')
        remember = attr(tag, 'data-remember')
        if remember is None:
            failures.append('unit %s has no data-remember takeaway' % unit_id)
            continue
        if len(words(remember)) > 25:
            failures.append('takeaway over 25 words in %s: %r' % (unit_id, remember[:120]))
        if remember != NO_FACT:
            if len(words(remember)) < 3:
                failures.append('takeaway is a fragment in %s: %r' % (unit_id, remember))
            elif not remember.rstrip().endswith(('.', '?', '!')):
                failures.append('takeaway is not a complete sentence in %s: %r' % (unit_id, remember[:120]))
        recall_q = attr(tag, 'data-recall-q')
        recall_a = attr(tag, 'data-recall-a')
        if not recall_q or not recall_a:
            failures.append('unit %s has no recall question/answer' % unit_id)

    # Retrieval gate must ask about the step just finished, not a stale
    # unit-retrieve from several steps ago.
    if 'function jqRetrieveUnit' in page:
        failures.append('retrieval still selects a stale earlier unit-retrieve step')
    if ("var prev = jqState.units[i - 1];" not in page
            or "prev.getAttribute('data-remember')" not in page):
        failures.append('retrieval does not read the just-finished step takeaway')

    # Pacing, finish and keyboard/mobile support.
    for marker in ('id="ul-journey-pause"', 'id="ul-journey-resume"',
                   'id="ul-journey-finish"', 'id="ul-journey-nextlesson"',
                   'id="ul-journey-deep-finish"', 'What you can now do',
                   "'ul-journey:'", "jqKey('step')", "jqKey('paused')"):
        if marker not in page:
            failures.append('pacing/finish marker missing: %s' % marker)
    if 'journey-stage' not in page:
        failures.append('journey stage is missing')
    if ':focus-visible' not in page:
        failures.append('visible keyboard focus rule is missing')
    if 'addEventListener(\'keydown\'' not in page:
        failures.append('keyboard navigation handler is missing')
    if 'max-width:640px' not in page or 'flex-direction:column' not in page:
        failures.append('mobile layout rules are missing')

    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('base', nargs='?', default='http://localhost:9000',
                        help='base URL of the Underlayer server')
    parser.add_argument('--lessons', help='comma-separated course:concept overrides')
    parser.add_argument('--all', action='store_true',
                        help='check every concept of every course (slow)')
    parser.add_argument('--workers', type=int, default=1,
                        help='parallel served-HTML fetches (default 1)')
    args = parser.parse_args()

    try:
        lessons, courses = lesson_set(args.base, args)
    except (urllib.error.HTTPError, urllib.error.URLError, ValueError) as exc:
        print('FATAL: cannot build lesson set: %s' % exc)
        return 2
    if not lessons:
        print('FATAL: /api/courses returned no lessons to check')
        return 2

    passed = 0
    failed = 0
    print('Journey quality check: %s, %d lesson(s), %d course(s)'
          % (args.base, len(lessons), len(courses)))
    if args.workers > 1:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            results = list(pool.map(
                lambda item: check_lesson(args.base, item[0], item[1]), lessons))
    else:
        results = [check_lesson(args.base, item[0], item[1]) for item in lessons]
    for (course, concept), failures in zip(lessons, results):
        if failures:
            failed += 1
            print('FAIL %s/%s' % (course, concept))
            for line in failures:
                print('     - ' + line)
        else:
            passed += 1
            print('PASS %s/%s' % (course, concept))
    print('RESULT: %d passed, %d failed, %d total' % (passed, failed, passed + failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
