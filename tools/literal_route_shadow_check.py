#!/usr/bin/env python3
"""literal_route_shadow_check.py -- a literal route must not be shadowed.

WHY THIS EXISTS (I2).  The router in app/main.ch is first-match-wins in
REGISTRATION ORDER.  `GET /api/exercises/hint` was registered after
`GET /api/exercises/:conceptId`, so the parameterised route won and the hint
endpoint answered 200 {"concept_id":"hint","exercises":[],"total":0} instead
of the lesson-sourced progressive hint.  Source-level route lists look fine
either way -- only the ORDER is wrong -- so this checker reads the order.

WHAT IT ASSERTS.  For every literal route (no `:` parameter, no `*` wildcard)
there must be no EARLIER registration of the same HTTP method whose pattern
would match that literal path.  Catch-all/wildcard patterns are counted too,
but a wildcard registered before a literal is always a shadow.  Duplicate
registrations of the identical literal are reported separately by
tools/route_check.py and are not treated as shadows here.

NEGATIVE CASES (no server needed):
    python3 tools/literal_route_shadow_check.py --selftest
  plants a shadow after a clean list and asserts it is reported; also asserts
  the clean list passes, so an always-fail detector cannot pass the selftest.

    python3 tools/literal_route_shadow_check.py --plant
  parses the real route table, plants a shadow into an in-memory copy, and
  asserts the detector fires on the planted pair while the real table stays
  clean.  Exit 0 means the plant was detected.

Usage:
    python3 tools/literal_route_shadow_check.py [--repo PATH]
Exit: 0 no literal route is shadowed.  1 at least one is.  2 input unreadable.
"""
import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROUTE_RE = re.compile(r'srv\.router\.add\(\s*"([A-Z]+)",\s*"([^"]+)"')


def parse_routes(repo):
    src = os.path.join(repo, 'app', 'main.ch')
    with open(src, newline='', encoding='utf-8') as handle:
        text = handle.read().replace('\r\n', '\n')
    return ROUTE_RE.findall(text)


def is_literal(pattern):
    return ':' not in pattern and '*' not in pattern


def pattern_matches(pattern, literal):
    """True when a registered pattern would capture this literal path.

    A `:name` segment matches exactly one segment. A `*` segment (including
    the `:path*` catch-all) matches the rest of the path, including zero
    segments. Literal segments must be byte-equal.
    """
    p = [s for s in pattern.split('/') if s]
    l = [s for s in literal.split('/') if s]
    i = 0
    while i < len(p):
        seg = p[i]
        if seg == '*' or seg.endswith('*'):
            return True
        if i >= len(l):
            return False
        if seg.startswith(':'):
            i += 1
            continue
        if seg != l[i]:
            return False
        i += 1
    return i == len(l)


def find_shadows(routes):
    """Return [(method, earlier_pattern, literal)] in registration order."""
    shadows = []
    seen = []
    for method, pattern in routes:
        if is_literal(pattern):
            for earlier_method, earlier in seen:
                if earlier_method != method:
                    continue
                if earlier == pattern:
                    continue  # exact duplicate: a different checker's job
                if pattern_matches(earlier, pattern):
                    shadows.append((method, earlier, pattern))
        seen.append((method, pattern))
    return shadows


def selftest():
    fails = []
    clean = [('GET', '/api/exercises/stats'),
             ('GET', '/api/exercises/hint'),
             ('GET', '/api/exercises/:conceptId'),
             ('POST', '/api/exercises/submit'),
             ('GET', '/api/courses'),
             ('GET', '/api/courses/:courseId'),
             ('GET', '/:path*')]
    if find_shadows(clean):
        fails.append('clean route list reported as shadowed')

    planted = list(clean)
    planted.insert(0, ('GET', '/api/exercises/:conceptId'))
    planted.insert(1, ('GET', '/api/exercises/hint'))
    found = find_shadows(planted)
    if not any(s == ('GET', '/api/exercises/:conceptId', '/api/exercises/hint')
               for s in found):
        fails.append('planted /api/exercises/hint shadow was not detected: %r'
                     % (found,))

    wildcard = [('GET', '/:path*'), ('GET', '/robots.txt')]
    if not find_shadows(wildcard):
        fails.append('a catch-all registered before a literal was not detected')

    if fails:
        print('SELFTEST FAIL:')
        for f in fails:
            print('  - ' + f)
        return 1
    print('SELFTEST OK: clean list passes; the planted literal shadow and the '
          'planted\n            catch-all shadow are both reported.')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=REPO)
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--plant', action='store_true',
                    help='plant a shadow in memory and assert it is detected')
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    try:
        routes = parse_routes(args.repo)
    except OSError as exc:
        print('FAIL: cannot read app/main.ch: %s' % exc)
        return 2
    if not routes:
        print('FAIL: no routes parsed from app/main.ch -- NOT a pass')
        return 2

    shadows = find_shadows(routes)
    if args.plant:
        planted = list(routes)
        planted.append(('GET', '/api/exercises/:conceptId'))
        planted.append(('GET', '/api/exercises/hint'))
        detected = find_shadows(planted)
        if not any(s[0] == 'GET' and s[1] == '/api/exercises/:conceptId'
                   and s[2] == '/api/exercises/hint' for s in detected):
            print('FAIL: the planted shadow was NOT detected -- the checker is '
                  'vacuous')
            return 1
        print('PLANT OK: planted /api/exercises/hint shadow was detected; the '
              'real table has %d shadow(s).' % len(shadows))
        return 0 if not shadows else 1

    if shadows:
        print('FAIL: %d literal route(s) shadowed by an earlier registration:'
              % len(shadows))
        for method, earlier, literal in shadows:
            print('  %-6s %-44s captures %s' % (method, earlier, literal))
        return 1
    print('literal_route_shadow_check: OK -- %d routes parsed, no literal route '
          'is shadowed.' % len(routes))
    return 0


if __name__ == '__main__':
    sys.exit(main())
