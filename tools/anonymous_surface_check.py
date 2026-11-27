#!/usr/bin/env python3
"""I9 — anonymous learner-shaped payloads must be honest.

Standard library only. Two modes:

  LIVE (default): read the GET /api/* routes out of app/main.ch (read-only),
  probe each one with NO credentials, and classify the response:

    * 401                                  -> OK (the endpoint is protected)
    * 200 without learner-shaped keys      -> OK (not learner data)
    * 200 with learner-shaped keys         -> must carry "demo": true
    * anything else                        -> OK (not an anonymous 200)

  Every anonymous-200 learner-shaped payload without the marker is a failure.
  The checker also looks for the user-facing sentence "Sign in to see your
  data" on the pages that display learner data; a marked API without that UI
  is still a failure, because a marker in JSON alone is not an honest screen.

  SELF-TEST (`--selftest`): no network. A planted unmarked payload, a planted
  marked payload and a planted 401 are evaluated by the SAME function the live
  mode uses. The unmarked plant MUST fail, otherwise the checker is vacuous.

Examples:
    python tools/anonymous_surface_check.py --base http://localhost:9038
    python tools/anonymous_surface_check.py --selftest
    python tools/anonymous_surface_check.py --plant tools/anonymous_plant.json

NEGATIVE PLANT (how to prove this checker can fail):
    `python tools/anonymous_surface_check.py --selftest` plants
    {"learner_id":"demo","current_streak":0} with no `demo` flag and asserts
    exit 1. `--plant FILE` feeds the same evaluator a JSON object of the form
    {"path": "/api/example", "status": 200, "body": {...}} so a real fixture
    from a running server can be planted without editing source.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

# Keys that make a payload "learner-shaped" rather than merely public metadata.
# Deliberately narrow: course/concept metadata (titles, minutes, ids of lessons)
# is not learner data and must not produce a false positive.
LEARNER_KEYS = (
    'learner_id', 'current_streak', 'longest_streak', 'total_active_days',
    'progress_percentage', 'mastery_percentage', 'concepts_mastered',
    'concepts_started', 'health_score', 'streak', 'due_count', 'due_items',
    'return_rate_pct', 'active_days', 'notes', 'bookmarks', 'review_items',
)

# Pages whose visible text must tell a signed-out reader that the numbers are
# not theirs. Kept as a list (not discovered) because the mapping from an API
# endpoint to the page that paints it is a product decision, not a regex.
DATA_PAGES = ('/dashboard', '/progress', '/analytics', '/streaks')
UI_MARKER = 'Sign in to see your data'

# Sample values for the parameterised routes discovered in app/main.ch.
SAMPLE = {
    'courseId': 'elf', 'requiredId': 'obj', 'conceptId': 'bytes',
    'id': 'elf-bytes-0', 'username': 'demo', 'type': 'notes',
    'learnerId': 'demo', 'exerciseId': 'elf_bytes_0',
}


def learner_keys(payload):
    """Return the learner-shaped keys present anywhere in a JSON payload."""
    found = set()
    if isinstance(payload, dict):
        for key, value in payload.items():
            if key in LEARNER_KEYS:
                found.add(key)
            found.update(learner_keys(value))
    elif isinstance(payload, list):
        for item in payload:
            found.update(learner_keys(item))
    return found


def is_demo_marked(payload):
    """True only when the payload explicitly announces itself as demo data."""
    if isinstance(payload, dict):
        if payload.get('demo') is True:
            return True
        return any(is_demo_marked(v) for v in payload.values())
    if isinstance(payload, list):
        return any(is_demo_marked(v) for v in payload)
    return False


def evaluate(path, status, body_text):
    """One classification. Shared by live, selftest and --plant.

    Returns None when the response is accepted, else a failure string.
    """
    if status == 401:
        return None
    if status != 200:
        return None
    try:
        payload = json.loads(body_text)
    except (ValueError, TypeError):
        return None  # HTML or an empty body: not an anonymous learner payload
    keys = learner_keys(payload)
    if not keys:
        return None
    if is_demo_marked(payload):
        return None
    return '%s: anonymous 200 with learner keys [%s] but no "demo": true' % (
        path, ', '.join(sorted(keys)))


def discover_get_api_routes(main_ch):
    """Read GET /api/* literals out of app/main.ch without executing anything."""
    with open(main_ch, 'r', encoding='utf-8') as handle:
        source = handle.read()
    routes = []
    seen = set()
    for raw in re.findall(r'srv\.router\.add\(\s*"GET"\s*,\s*"([^"]+)"', source):
        if not raw.startswith('/api/'):
            continue
        path = raw
        for name, value in SAMPLE.items():
            path = path.replace(':' + name, value)
        # Unbound parameters cannot be probed meaningfully; skip rather than
        # count a 404 as proof of anything.
        if ':' in path:
            continue
        if path not in seen:
            seen.add(path)
            routes.append(path)
    return routes


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Page gates answer 303; following it would hide the gate behind /login."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch(base, path, follow=True):
    req = urllib.request.Request(base.rstrip('/') + path, headers={'Accept': 'application/json'})
    opener = urllib.request.build_opener() if follow else urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(req, timeout=15) as response:
            return response.status, response.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode('utf-8', 'replace')


def run_selftest():
    """The negative plant must fail; the two positive controls must pass."""
    unmarked = json.dumps({'learner_id': 'demo', 'current_streak': 0,
                           'longest_streak': 0, 'total_active_days': 0})
    failures = []
    check = evaluate('/api/plant/unmarked', 200, unmarked)
    if check is None:
        failures.append('SELFTEST VACUOUS: planted unmarked payload was accepted')
    marked = json.dumps({'learner_id': 'demo', 'demo': True,
                         'current_streak': 0})
    if evaluate('/api/plant/marked', 200, marked) is not None:
        failures.append('selftest: correctly marked payload was rejected')
    if evaluate('/api/plant/protected', 401, 'unauthorized') is not None:
        failures.append('selftest: 401 was rejected')
    non_learner = json.dumps({'courses': [{'id': 'elf', 'estimated_minutes': 12}]})
    if evaluate('/api/plant/catalogue', 200, non_learner) is not None:
        failures.append('selftest: non-learner catalogue was rejected')
    for item in failures:
        print('FAIL ' + item)
    if failures:
        print('SELFTEST 0/4 — checker cannot fail; do not trust a live run')
        return 1
    print('SELFTEST 4/4 — unmarked plant rejected, three controls accepted')
    return 0


def run_plant(path):
    with open(path, 'r', encoding='utf-8') as handle:
        fixture = json.load(handle)
    if isinstance(fixture, list):
        fixtures = fixture
    else:
        fixtures = [fixture]
    failures = []
    for item in fixtures:
        failure = evaluate(item.get('path', '<plant>'), int(item.get('status', 200)),
                           json.dumps(item.get('body', {})))
        if failure:
            failures.append(failure)
    for failure in failures:
        print('FAIL ' + failure)
    print('PLANT %d/%d rejected' % (len(failures), len(fixtures)))
    return 1 if failures else 0


def run_live(base, main_ch, include_ui):
    routes = discover_get_api_routes(main_ch)
    print('discovered %d anonymous GET /api/* routes' % len(routes))
    failures = []
    checked = 0
    unmarked = 0
    for route in routes:
        try:
            status, body = fetch(base, route)
        except (urllib.error.URLError, OSError) as exc:
            failures.append('%s: probe failed: %s' % (route, exc))
            continue
        checked += 1
        failure = evaluate(route, status, body)
        if failure:
            unmarked += 1
            failures.append(failure)
    print('probed %d routes; %d anonymous-200 learner payloads unmarked' % (
        checked, unmarked))
    if include_ui:
        gated = 0
        for page in DATA_PAGES:
            try:
                status, body = fetch(base, page, follow=False)
            except (urllib.error.URLError, OSError) as exc:
                failures.append('%s: probe failed: %s' % (page, exc))
                continue
            # A signed-out visitor redirected to sign-in never sees learner
            # numbers, so no demo UI sentence is required on that screen.
            if 300 <= status < 400 or status == 401:
                gated += 1
                continue
            if status == 200 and UI_MARKER not in body:
                failures.append('%s: serves learner data without the UI sentence %r'
                                % (page, UI_MARKER))
        print('gated learner pages (redirect/401): %d/%d' % (gated, len(DATA_PAGES)))
    for failure in failures:
        print('FAIL ' + failure)
    print('ANONYMOUS SURFACE %d failure(s)' % len(failures))
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='http://localhost:9038')
    parser.add_argument('--main', default='app/main.ch',
                        help='route source, read only (default: app/main.ch)')
    parser.add_argument('--selftest', action='store_true')
    parser.add_argument('--plant', help='JSON fixture with a planted payload')
    parser.add_argument('--no-ui', action='store_true',
                        help='skip the served-page UI-marker assertion')
    args = parser.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    if not os.path.exists(args.main):
        print('FAIL route source not found: ' + args.main)
        return 1
    return run_live(args.base, args.main, not args.no_ui)


if __name__ == '__main__':
    sys.exit(main())
