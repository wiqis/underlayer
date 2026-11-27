#!/usr/bin/env python3
"""H14 — no anonymous route may create or delete a persistent row in RELEASE.

Standard library only.  Disposable servers and disposable SQLite files only.

The check has three layers, all deliberate:

  1. The server under test must answer /api/health with `build_mode == release`.
     Pointing this at a debug binary is a failure, not a pass: debug keeps the
     anonymous writes that `tests.exe` (138 tests) still exercises.
  2. Every POST/PUT/DELETE/PATCH /api/* route in app/main.ch is probed with NO
     credentials and a generously shaped JSON body.  Before and after each
     probe every SQLite table is counted.  Any change in a non-infrastructure
     table is a failure, whatever the HTTP status -- a 4xx that still writes a
     row is exactly the defect this checker exists to catch.
  3. SELFTEST / --plant evaluate synthetic before/after counts with the SAME
     function the live mode uses.  The planted extra row MUST be rejected; if
     it is accepted the checker is vacuous and its live pass means nothing.

WHY THE WHITELIST.  The authentication lifecycle (register, login, the account
bridge, password reset) must be reachable without a session: requiring a
session to obtain a session is impossible.  Those writes are part of the
shipped contract and are documented in docs/deployment.md.  Nothing else is
exempt.  `rate_limits` and `sqlite_sequence` are infrastructure counters, not
learner rows, so they are excluded from the row-count comparison only.

The URL and the DB path are both guarded.  A remote host or a production-looking
DB is refused before any request is sent -- this checker is never a production
probe.

Usage:
    python tools/anonymous_write_check.py --base http://localhost:9040 \
        --db ./tmp_h14_release9040.db
    python tools/anonymous_write_check.py --selftest
    python tools/anonymous_write_check.py --plant tools/anonymous_write_plant.json

Exit: 0 no anonymous persistent writes; 1 at least one write or a bad
environment; 2 the server / DB is not reachable (NOT a pass).
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 15

# Tables that are bookkeeping, not learner data.  Deliberately a short list:
# adding a table here hides a real anonymous write.
INFRA_TABLES = frozenset(('rate_limits', 'sqlite_sequence'))

# Anonymous-by-design entry points.  Every entry is a behaviour, not a loophole:
# a session cannot be required to create the first session.
AUTH_LIFECYCLE = {
    ('POST', '/api/auth/register'): 'creating an account is the first anonymous write',
    ('POST', '/api/auth/login'): 'a successful login mints a session for an anonymous caller',
    ('POST', '/api/auth/from-account'): 'the shared-account bridge exchanges a token for a local session',
    ('POST', '/api/auth/forgot-password'): 'a signed-out learner must be able to request a reset',
    ('POST', '/api/auth/reset-password'): 'the reset link itself is the credential',
    ('POST', '/api/auth/verify-email'): 'the verification link itself is the credential',
    ('POST', '/api/auth/logout'): 'ends a session; must work when the browser still has the cookie',
}

# Sample values for the parameterised routes discovered in app/main.ch.
SAMPLE = {
    'courseId': 'elf', 'requiredId': 'obj', 'conceptId': 'bytes', 'id': 'probe',
    'username': 'demo', 'type': 'notes', 'learnerId': 'demo',
    'exerciseId': 'elf_bytes_0',
}

# One body shape for every write route.  A route that guards with a session
# returns 401 before parsing; one that does not gets enough keys -- including
# the nested arrays /api/progress/import reads -- to actually write a row.
BODY = json.dumps({
    'course_id': 'elf', 'concept_id': 'bytes', 'concept_ids': ['bytes'],
    'learner_id': 'demo', 'session_id': 'probe', 'type': 'notes',
    'title': 'anon-write-probe', 'content': 'anon-write-probe',
    'text': 'anon-write-probe', 'message': 'anon-write-probe',
    'feedback': 'anon-write-probe', 'rating': 3, 'minutes': 10,
    'status': 'open', 'email': 'anonwrite@example.invalid',
    'password': 'Probe1!pass', 'name': 'anon', 'goal': 'probe',
    'exercise_id': 'elf_bytes_0', 'items': [], 'data': {}, 'token': 'probe',
    'category': 'notes', 'label': 'probe', 'value': 'probe',
    'target_date': 1893456000,
    'concept_states': [{'concept_id': 'bytes', 'course_id': 'elf',
                        'status': 'reviewing', 'attempts': 1,
                        'correct': 1, 'streak': 1}],
    'review_items': [],
}).encode('utf-8')

# GET-style parameters are also accepted by several write handlers
# (/api/goals reads target_date from the query, not the body).  Send both so a
# route cannot hide an anonymous write simply because the checker used the
# other channel.
QUERY = '?target_date=1893456000&course_id=elf&concept_id=bytes&type=notes&minutes=10'


def evaluate(path, status, before, after):
    """One classification, shared by live, selftest and --plant.

    Returns None when the probe is accepted, else a failure string.
    """
    changes = []
    for table in sorted(set(before) | set(after)):
        if table in INFRA_TABLES:
            continue
        old = int(before.get(table, 0))
        new = int(after.get(table, 0))
        if new != old:
            changes.append('%s %d->%d' % (table, old, new))
    if changes:
        return ('%s: anonymous request (HTTP %s) changed persistent rows: %s'
                % (path, status, ', '.join(changes)))
    return None


def discover_write_routes(main_ch):
    """Read POST/PUT/DELETE/PATCH /api/* literals out of app/main.ch."""
    with open(main_ch, 'r', encoding='utf-8') as handle:
        source = handle.read()
    pattern = r'srv\.router\.add\(\s*"(POST|PUT|DELETE|PATCH)"\s*,\s*"([^"]+)"'
    routes = []
    seen = set()
    for method, raw in re.findall(pattern, source):
        if not raw.startswith('/api/'):
            continue
        path = raw
        for name, value in SAMPLE.items():
            path = path.replace(':' + name, value)
        if ':' in path:
            continue
        key = (method, path)
        if key not in seen:
            seen.add(key)
            routes.append(key)
    return routes


def counts(db_path):
    """Read-only row counts of every table in the disposable DB."""
    uri = 'file:' + urllib.parse.quote(os.path.abspath(db_path)) + '?mode=ro'
    con = sqlite3.connect(uri, uri=True, timeout=TIMEOUT)
    try:
        names = [row[0] for row in con.execute(
            "select name from sqlite_master where type='table' order by name")]
        result = {}
        for name in names:
            result[name] = con.execute(
                'select count(*) from "' + name.replace('"', '""') + '"'
            ).fetchone()[0]
        return result
    finally:
        con.close()


def fetch(base, path, method):
    req = urllib.request.Request(
        base.rstrip('/') + path + QUERY, data=BODY, method=method,
        headers={'Content-Type': 'application/json', 'Accept': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code
    except (urllib.error.URLError, OSError) as exc:
        raise RuntimeError('probe failed for %s %s: %s' % (method, path, exc))


def build_mode(base):
    req = urllib.request.Request(base.rstrip('/') + '/api/health',
                                 headers={'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
        payload = json.loads(response.read().decode('utf-8', 'replace'))
    return payload.get('build_mode'), payload


def refuse_environment(base, db_path):
    """Refuse a non-loopback host or a production-looking database."""
    host = (urllib.parse.urlsplit(base).hostname or '').lower()
    if host not in ('localhost', '127.0.0.1', '::1'):
        raise ValueError('refusing non-loopback base URL %r' % base)
    if db_path.startswith(('libsql://', 'https://', 'http://', 'file:')):
        raise ValueError('refusing non-local database URL %r' % db_path)
    name = os.path.basename(db_path).lower()
    if name in ('underlayer.db', 'production.db', 'prod.db'):
        raise ValueError('refusing production-looking database %r' % db_path)
    if not any(marker in name for marker in ('tmp_', 'test', 'disposable', 'probe')):
        raise ValueError('DB basename must mark it disposable (tmp_/test/disposable/probe): %r' % db_path)
    if not os.path.isfile(db_path):
        raise ValueError('disposable DB does not exist: %r' % db_path)


def run_selftest():
    """The planted extra row must fail; the three controls must pass."""
    base_counts = {'learners': 0, 'learner_notes': 0, 'rate_limits': 4}
    failures = []
    planted = evaluate('/api/plant/write', 200, base_counts,
                       {'learners': 1, 'learner_notes': 0, 'rate_limits': 5})
    if planted is None:
        failures.append('SELFTEST VACUOUS: a planted extra row was accepted')
    planted_delete = evaluate('/api/plant/delete', 401, base_counts,
                              {'learners': 0, 'rate_limits': 4, 'learner_notes': -1})
    if planted_delete is None:
        failures.append('SELFTEST VACUOUS: a planted deleted row was accepted')
    if evaluate('/api/plant/blocked', 401, base_counts, dict(base_counts)) is not None:
        failures.append('selftest: a blocked write with no row change was rejected')
    if evaluate('/api/plant/harmless', 200, base_counts, dict(base_counts)) is not None:
        failures.append('selftest: a 200 with no row change was rejected')
    # Infrastructure counters alone must not fail the check.
    if evaluate('/api/plant/limiter', 429, base_counts,
                {'learners': 0, 'learner_notes': 0, 'rate_limits': 9}) is not None:
        failures.append('selftest: a rate-limit counter was mistaken for a learner row')
    for item in failures:
        print('FAIL ' + item)
    if failures:
        print('SELFTEST 0/5 — checker cannot fail; do not trust a live run')
        return 1
    print('SELFTEST 5/5 — planted create and delete rejected, three controls accepted')
    return 0


def run_plant(path):
    with open(path, 'r', encoding='utf-8') as handle:
        fixture = json.load(handle)
    fixtures = fixture if isinstance(fixture, list) else [fixture]
    failures = []
    for item in fixtures:
        failure = evaluate(item.get('path', '<plant>'), int(item.get('status', 200)),
                           item.get('before', {}), item.get('after', {}))
        if failure:
            failures.append(failure)
    for failure in failures:
        print('FAIL ' + failure)
    print('PLANT %d/%d rejected' % (len(failures), len(fixtures)))
    return 1 if failures else 0


def run_live(base, db_path, main_ch):
    refuse_environment(base, db_path)
    try:
        mode, health = build_mode(base)
    except (urllib.error.URLError, OSError, ValueError) as exc:
        print('FAIL server not reachable: %s' % exc)
        return 2
    if mode != 'release':
        print('FAIL /api/health build_mode=%r, expected release (debug keeps anonymous writes for tests)' % mode)
        return 1
    print('server build_mode=release; DB=%s' % db_path)
    routes = discover_write_routes(main_ch)
    print('discovered %d write /api/* routes; %d auth-lifecycle exemptions' % (
        len(routes), len(AUTH_LIFECYCLE)))
    failures = []
    probed = 0
    for method, path in routes:
        if (method, path) in AUTH_LIFECYCLE:
            continue
        try:
            before = counts(db_path)
            status = fetch(base, path, method)
            after = counts(db_path)
        except (RuntimeError, sqlite3.Error, ValueError) as exc:
            failures.append('%s %s: probe failed: %s' % (method, path, exc))
            continue
        probed += 1
        failure = evaluate(path, status, before, after)
        if failure:
            failures.append(failure)
    print('probed %d non-exempt write routes' % probed)
    for failure in failures:
        print('FAIL ' + failure)
    print('ANONYMOUS WRITE SURFACE %d failure(s)' % len(failures))
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='http://localhost:9040')
    parser.add_argument('--db', default=os.environ.get('DATABASE_URL', ''),
                        help='disposable SQLite file the server is using')
    parser.add_argument('--main', default='app/main.ch',
                        help='route source, read only (default: app/main.ch)')
    parser.add_argument('--selftest', action='store_true')
    parser.add_argument('--plant', help='JSON fixture with before/after row counts')
    args = parser.parse_args()
    if args.selftest:
        return run_selftest()
    if args.plant:
        return run_plant(args.plant)
    if not os.path.exists(args.main):
        print('FAIL route source not found: ' + args.main)
        return 1
    try:
        return run_live(args.base, args.db, args.main)
    except ValueError as exc:
        print('FAIL environment refused: %s' % exc)
        return 1


if __name__ == '__main__':
    sys.exit(main())
