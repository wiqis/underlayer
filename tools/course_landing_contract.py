#!/usr/bin/env python3
"""I14 — served course landings must agree with the course and prerequisite APIs.

Standard library only. No browser is required: every value the checker judges
is server-rendered into the page (the mastery percentage is fetched at runtime
from the same endpoint the enrolment gate uses, so the checker asserts that the
endpoint is named on the page rather than inventing a number).

Checks, per course:
  * `data-total-minutes` equals the SUM of `estimated_minutes` in GET /api/courses/:id
  * `data-dependencies` equals the API `dependencies` AND the
    `required_course_id` set of GET /api/courses/:id/prerequisites
  * the page names the prerequisite endpoint, the "read these first" path and
    an honest enrolment state
  * a course whose concept minutes are all identical is flagged: a uniform
    distribution is a template value, not a per-concept estimate

Examples:
    python tools/course_landing_contract.py --base http://localhost:9038
    python tools/course_landing_contract.py --selftest
    python tools/course_landing_contract.py --allow-uniform pe

NEGATIVE PLANT (how to prove this checker can fail):
    `--selftest` feeds the SAME evaluator a planted landing with a wrong total
    and a missing dependency. Both must be reported and the process must exit 1.
    `--plant FILE` accepts {"course":..., "dependencies":[...], "minutes":[...],
    "html":"..."} so a captured served page can be planted without a rebuild.
"""

import argparse
import json
import re
import sys
import urllib.request

ATTR_TOTAL = re.compile(r'data-total-minutes="(\d+)"')
ATTR_DEPS = re.compile(r'data-dependencies="([^"]*)"')
ATTR_SOURCE = re.compile(r'data-prereq-source="([^"]*)"')


def fetch(base, path):
    with urllib.request.urlopen(base.rstrip('/') + path, timeout=20) as response:
        return response.read().decode('utf-8', 'replace')


def fetch_json(base, path):
    return json.loads(fetch(base, path))


def evaluate(course_id, dependencies, prereq_ids, minutes, html):
    """Return a list of failures for one course. Shared by every mode."""
    failures = []
    total = ATTR_TOTAL.search(html)
    expected = sum(int(m) for m in minutes)
    if not total:
        failures.append('%s: landing has no data-total-minutes' % course_id)
    elif int(total.group(1)) != expected:
        failures.append('%s: total minutes %s != API sum %d' % (
            course_id, total.group(1), expected))

    deps = ATTR_DEPS.search(html)
    page_deps = set()
    if not deps:
        failures.append('%s: landing has no data-dependencies' % course_id)
    else:
        page_deps = set(x for x in deps.group(1).split('|') if x)
    api_deps = set(dependencies)
    if page_deps != api_deps:
        failures.append('%s: landing deps [%s] != API deps [%s]' % (
            course_id, ','.join(sorted(page_deps)), ','.join(sorted(api_deps))))
    if prereq_ids is not None and page_deps != set(prereq_ids):
        failures.append('%s: landing deps [%s] != prerequisite rows [%s]' % (
            course_id, ','.join(sorted(page_deps)), ','.join(sorted(prereq_ids))))

    source = ATTR_SOURCE.search(html)
    want_source = '/api/courses/%s/prerequisites' % course_id
    if not source or source.group(1) != want_source:
        failures.append('%s: landing does not name %s' % (course_id, want_source))
    for marker in ('id="course-prereqs"', 'id="prereq-list"',
                   'id="enrol-state"', 'Read these first', 'Sign in'):
        if marker not in html:
            failures.append('%s: landing is missing %r' % (course_id, marker))
    return failures


def uniform_minutes(course_id, minutes):
    """A uniform distribution across >=3 concepts is a template, not an estimate."""
    if len(minutes) < 3:
        return False
    return len(set(minutes)) == 1


def run_selftest():
    base_html = ('<section id="course-prereqs" data-total-minutes="%d" '
                 'data-dependencies="%s" '
                 'data-prereq-source="/api/courses/%s/prerequisites">'
                 'Read these first. Sign in to check. '
                 '<ol id="prereq-list"></ol><p id="enrol-state"></p></section>')
    good = base_html % (15, 'elf|obj', 'demo')
    good_failures = evaluate('demo', ['elf', 'obj'], ['elf', 'obj'], [10, 5], good)
    bad_total = base_html % (999, 'elf|obj', 'demo')
    bad_deps = base_html % (15, 'elf', 'demo')
    planted_total = evaluate('demo', ['elf', 'obj'], ['elf', 'obj'], [10, 5], bad_total)
    planted_dep = evaluate('demo', ['elf', 'obj'], ['elf', 'obj'], [10, 5], bad_deps)
    uniform = uniform_minutes('demo', [15, 15, 15])

    ok = (not good_failures) and bool(planted_total) and bool(planted_dep) and uniform
    if good_failures:
        for item in good_failures:
            print('FAIL selftest good fixture: ' + item)
    if not planted_total:
        print('FAIL SELFTEST VACUOUS: planted wrong total was accepted')
    if not planted_dep:
        print('FAIL SELFTEST VACUOUS: planted missing dependency was accepted')
    if not uniform:
        print('FAIL SELFTEST VACUOUS: uniform minutes were not flagged')
    if ok:
        print('SELFTEST 4/4 — both negative plants rejected, controls accepted')
        return 0
    print('SELFTEST incomplete — do not trust a live run')
    return 1


def run_plant(path):
    with open(path, 'r', encoding='utf-8') as handle:
        fixture = json.load(handle)
    failures = evaluate(fixture.get('course', '<plant>'),
                        fixture.get('dependencies', []),
                        fixture.get('prereq_ids'),
                        fixture.get('minutes', []),
                        fixture.get('html', ''))
    for item in failures:
        print('FAIL ' + item)
    print('PLANT %d failure(s)' % len(failures))
    return 1 if failures else 0


def run_live(base, allow_uniform):
    courses = fetch_json(base, '/api/courses')
    failures = []
    uniform = []
    parity = 0
    for course in courses:
        cid = course.get('id')
        if not cid:
            continue
        try:
            detail = fetch_json(base, '/api/courses/' + cid)
            prereqs = fetch_json(base, '/api/courses/' + cid + '/prerequisites')
            html = fetch(base, '/courses/' + cid)
        except Exception as exc:  # network/HTTP failures are real findings
            failures.append('%s: fetch failed: %s' % (cid, exc))
            continue
        minutes = [c.get('estimated_minutes', 0) for c in detail.get('concepts', [])]
        deps = detail.get('dependencies', [])
        prereq_ids = [row.get('required_course_id') for row in prereqs]
        page_failures = evaluate(cid, deps, prereq_ids, minutes, html)
        if not page_failures:
            parity += 1
        failures.extend(page_failures)
        if uniform_minutes(cid, minutes) and cid not in allow_uniform:
            uniform.append('%s: all %d concepts have %s minutes' % (
                cid, len(minutes), minutes[0]))

    print('API<->landing parity: %d/%d' % (parity, len(courses)))
    print('uniform minute distributions: %d' % len(uniform))
    for item in uniform:
        print('UNIFORM ' + item)
    for item in failures:
        print('FAIL ' + item)
    if uniform:
        failures.extend(uniform)
    print('COURSE LANDING CONTRACT %d failure(s)' % len(failures))
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='http://localhost:9038')
    parser.add_argument('--selftest', action='store_true')
    parser.add_argument('--plant', help='JSON fixture with a planted landing')
    parser.add_argument('--allow-uniform', default='',
                        help='comma-separated course ids whose uniform minutes are accepted')
    args = parser.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    allow = set(x.strip() for x in args.allow_uniform.split(',') if x.strip())
    return run_live(args.base, allow)


if __name__ == '__main__':
    sys.exit(main())
