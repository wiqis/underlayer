#!/usr/bin/env python3
"""I4 — served-HTML quiz parity across every concept of every course.

Checks the artifact the learner receives, not the source tree: every served
lesson must have at least one in-page graded choice, every option must carry a
non-empty lesson-sourced `data-explain` (right or wrong), and a working
`checkQuiz` handler must be present. The lesson set is derived from
GET /api/courses and /api/courses/:id, never hardcoded.

Standard library only. Exit 1 on any failure.

Negative cases (they must make this checker FAIL):
    python tools/quiz_parity_check.py http://localhost:9043 --plant
    python tools/quiz_parity_check.py http://localhost:9043 --plant-no-quiz
Each plant changes one lesson IN MEMORY: the first removes a single
data-explain attribute; the second removes every quiz option. A green run
after either plant would mean the checker is vacuous.
"""

import argparse
import concurrent.futures
import html
import json
import re
import sys
import time
import urllib.request

OPTION = re.compile(r'<button[^>]*\bclass="quiz-option"([^>]*)>(.*?)</button>', re.S)


def fetch(url, timeout=25, attempts=3):
    # The served binary gzips ~120 KiB lessons; under parallel checker load a
    # Windows socket is occasionally reset. Retry instead of crashing the run.
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as response:
                return response.read().decode('utf-8', 'replace')
        except (ConnectionResetError, TimeoutError, OSError):
            if attempt == attempts - 1:
                raise
            time.sleep(0.1 * (attempt + 1))


def fetch_json(base, path):
    return json.loads(fetch(base.rstrip('/') + path))


def attr(tag, name):
    m = re.search(r'\b' + re.escape(name) + r'="([^"]*)"', tag)
    return html.unescape(m.group(1)) if m else None


def lesson_set(base):
    courses = fetch_json(base, '/api/courses')
    lessons = []
    for course in courses:
        cid = course.get('id')
        if not cid:
            continue
        # A paid lesson correctly answers 402 to an anonymous parity crawler.
        if course.get('paid'):
            continue
        detail = fetch_json(base, '/api/courses/' + cid)
        for concept in detail.get('concepts', []):
            if concept.get('id'):
                lessons.append((cid, concept['id']))
    return lessons


def check_lesson(base, cid, concept, plant=None):
    page = fetch(base + '/courses/' + cid + '/lessons/' + concept)
    if plant == 'explain':
        def blank_first(m):
            # Keep the option in the page; only its feedback is removed, so the
            # checker must notice a MISSING EXPLANATION and not a smaller count.
            tag = re.sub(r'\sdata-explain="[^"]*"', ' data-explain=""', m.group(1), count=1)
            return '<button class="quiz-option"' + tag + '>' + m.group(2) + '</button>'
        page = OPTION.sub(blank_first, page, count=1)
    elif plant == 'quiz':
        page = OPTION.sub('', page)
    options = OPTION.findall(page)
    problems = []
    explained = 0
    for tag, _body in options:
        value = attr(tag, 'data-explain')
        if value and value.strip():
            explained += 1
    if not options:
        problems.append('no in-page graded choice')
    if explained == 0:
        problems.append('no option carries a non-empty data-explain')
    if explained != len(options):
        problems.append('%d/%d options have data-explain' % (explained, len(options)))
    markers = [tag for tag, _ in options
               if attr(tag, 'data-correct') == 'true' or ', true)' in tag]
    if not markers:
        problems.append('no option is marked correct')
    if 'function checkQuiz' not in page:
        problems.append('checkQuiz handler missing')
    return cid, concept, len(options), explained, problems


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', nargs='?', default='http://localhost:9043')
    ap.add_argument('--workers', type=int, default=8)
    ap.add_argument('--plant', choices=('explain', 'quiz'),
                    help='seed a negative case IN MEMORY; checker must fail')
    args = ap.parse_args()
    try:
        lessons = lesson_set(args.base)
    except Exception as exc:
        print('FATAL: cannot build lesson set: %s' % exc)
        return 2
    if not lessons:
        print('FATAL: /api/courses returned no lessons')
        return 2
    planted = args.plant
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = []
        for i, (cid, concept) in enumerate(lessons):
            which = planted if (planted and i == 0) else None
            futures.append(pool.submit(check_lesson, args.base, cid, concept, which))
        results = list(futures)
    passed = failed = options = explained = 0
    for future in results:
        cid, concept, n, e, problems = future.result()
        options += n
        explained += e
        if problems:
            failed += 1
            print('FAIL %s/%s: %s' % (cid, concept, '; '.join(problems)))
        else:
            passed += 1
    print('quiz_parity_check: %d passed, %d failed, %d lessons; %d/%d options explained; plant=%s'
          % (passed, failed, len(lessons), explained, options, planted or 'none'))
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
