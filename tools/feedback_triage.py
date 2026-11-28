#!/usr/bin/env python3
"""feedback_triage.py -- list pending feedback and mark one fixed (H9).

This is the operator client for the H9 allow-list. It NEVER sends a client-side
operator flag: the server resolves the bearer token to a stable identity and
checks its own UL_OPERATOR_IDS secret. The token is read from
UL_OPERATOR_TOKEN (or --operator-token) and is never printed.

Two-account regression: registers two throwaway learners, files feedback as A,
and proves B gets 403 from the admin routes and cannot read A's report through
the owner-scoped route. Everything is bounded by explicit timeouts, uses only
the standard library, and refuses a non-loopback base unless
--founder-approved is passed. No shell, no eval, no importScripts.

Usage:
    python tools/feedback_triage.py --selftest
    python tools/feedback_triage.py --base http://127.0.0.1:9060 \
        --two-account-regression
    python tools/feedback_triage.py --base http://127.0.0.1:9060 --list
    python tools/feedback_triage.py --base http://127.0.0.1:9060 \
        --mark-fixed <id> --note "verified against spec" --db build/x.db
Exit 0 when every assertion passes, 1 on a failed assertion, 2 on a refused
target.
"""
import argparse
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
import uuid

TIMEOUT = 10.0
PRODUCTION_NAMES = ('underlayer.db', 'wiqis', '/data/', 'production', 'prod.db')


def request(method, url, token=None, body=None, request_id=None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if request_id:
        headers['X-Request-Id'] = request_id
    data = None
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            raw = response.read(2_000_000).decode('utf-8', 'replace')
            return response.getcode(), raw, dict(response.headers)
    except urllib.error.HTTPError as exc:
        raw = exc.read(200_000).decode('utf-8', 'replace')
        return exc.code, raw, dict(exc.headers)


def parse_json(raw):
    try:
        return json.loads(raw)
    except ValueError:
        return None


def guard_base(base, approved):
    if not base:
        print('FAIL: --base is required', file=sys.stderr)
        return False
    host = base.split('//', 1)[-1].split('/', 1)[0].split(':')[0].lower()
    if host not in ('127.0.0.1', 'localhost', '::1'):
        if not approved:
            print('FAIL: refusing non-loopback base %s without --founder-approved'
                  % base, file=sys.stderr)
            return False
        print('NOTE: founder-approved non-loopback target %s' % base)
    return True


def guard_db(path):
    lowered = (path or '').lower()
    if any(name in lowered for name in PRODUCTION_NAMES):
        print('FAIL: refusing production-looking DB %s' % path, file=sys.stderr)
        return False
    return True


def register(base, label):
    email = 'h9-%s-%s@example.invalid' % (label, uuid.uuid4().hex[:10])
    status, raw, _ = request('POST', base + '/api/auth/register',
                             body={'email': email, 'password': 'Throwaway!123',
                                   'name': label})
    payload = parse_json(raw)
    if status != 200 or not payload or not payload.get('session_token'):
        raise AssertionError('register %s failed: %d %s' % (label, status, raw[:200]))
    return payload['session_token'], payload['learner_id']


def owner_scoped(body_text, forbidden_ids, forbidden_marker):
    """True when B's view contains none of A's identity or words."""
    for item in forbidden_ids:
        if item and item in body_text:
            return False
    if forbidden_marker and forbidden_marker in body_text:
        return False
    return True


def two_account_regression(base):
    token_a, id_a = register(base, 'learner-a')
    token_b, id_b = register(base, 'learner-b')
    marker = 'H9-CROSS-LEARNER-' + uuid.uuid4().hex[:12]
    status, raw, _ = request('POST', base + '/api/feedback', token=token_a,
                             body={'concept_id': 'bytes', 'course_id': 'elf',
                                   'feedback_type': 'content', 'message': marker})
    if status != 200:
        raise AssertionError('A could not file feedback: %d %s' % (status, raw[:200]))

    checks = []
    status, raw, _ = request('GET', base + '/api/feedback/admin', token=token_b)
    checks.append(('normal learner 403 on admin list', status == 403, status))
    status, raw, _ = request('GET', base + '/api/feedback/admin/reports', token=token_b)
    checks.append(('normal learner 403 on admin reports', status == 403, status))
    status, raw, _ = request('PUT', base + '/api/feedback/no-such-id/status',
                             token=token_b, body={'status': 'fixed', 'admin_notes': 'x'})
    checks.append(('normal learner 403 on status write', status == 403, status))
    status, raw, _ = request('GET', base + '/api/feedback/admin')
    checks.append(('anonymous 401 on admin list', status == 401, status))

    status, raw, _ = request('GET', base + '/api/feedback/concept/bytes', token=token_b)
    parsed = parse_json(raw)
    checks.append(('B owner-scoped read answers 200', status == 200 and isinstance(parsed, list), status))
    checks.append(('B cannot read A id or A words',
                   owner_scoped(raw, [id_a], marker), 'leak' if not owner_scoped(raw, [id_a], marker) else 'clean'))

    status, raw_a, _ = request('GET', base + '/api/feedback/concept/bytes', token=token_a)
    checks.append(('A can read own report',
                   status == 200 and marker in raw_a and id_a in raw_a, status))
    return checks


def verify_audit(db_path, action_prefix='feedback.admin'):
    con = sqlite3.connect('file:%s?mode=ro' % db_path, uri=True, timeout=5)
    try:
        rows = con.execute(
            "SELECT action, actor, request_id FROM audit_log "
            "WHERE action LIKE ? ORDER BY id DESC LIMIT 20", (action_prefix + '%',)
        ).fetchall()
    finally:
        con.close()
    bad = [r for r in rows if not r[1] or not r[2]]
    return rows, bad


def selftest():
    """Negative plants: the cross-learner detector must fire on a real leak."""
    cases = [
        ('no leak', '{"id":"r1","learner_id":"B"}', ['A'], 'SECRET', True),
        ('leaked other learner id', '{"id":"r1","learner_id":"A"}', ['A'], 'OTHER', False),
        ('leaked other learner words', '{"message":"SECRET"}', ['A'], 'SECRET', False),
    ]
    failures = []
    for label, body, ids, marker, expected in cases:
        got = owner_scoped(body, ids, marker)
        ok = got == expected
        print('%s: %s (detector=%s)' % ('PASS' if ok else 'FAIL', label, got))
        if not ok:
            failures.append(label)
    if failures:
        print('FAIL: feedback_triage selftest plants not detected: %s' % failures,
              file=sys.stderr)
        return 1
    print('PASS: feedback_triage selftest (3 cases, 2 negative plants)')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', help='loopback base URL, e.g. http://127.0.0.1:9060')
    ap.add_argument('--operator-token', default=os.environ.get('UL_OPERATOR_TOKEN'),
                    help='operator bearer token (defaults to UL_OPERATOR_TOKEN)')
    ap.add_argument('--list', action='store_true', help='list pending feedback')
    ap.add_argument('--mark-fixed', help='feedback id to mark fixed')
    ap.add_argument('--note', default='', help='admin_notes for --mark-fixed')
    ap.add_argument('--two-account-regression', action='store_true')
    ap.add_argument('--db', help='disposable SQLite DB to verify audit rows')
    ap.add_argument('--founder-approved', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not guard_base(args.base, args.founder_approved):
        return 2

    failures = []
    if args.two_account_regression:
        for label, ok, detail in two_account_regression(args.base):
            print('%s: %s (%s)' % ('PASS' if ok else 'FAIL', label, detail))
            if not ok:
                failures.append(label)

    if args.list:
        if not args.operator_token:
            print('FAIL: --list needs UL_OPERATOR_TOKEN', file=sys.stderr)
            return 1
        rid = 'triage-list-' + uuid.uuid4().hex[:8]
        for path in ('/api/feedback/admin', '/api/feedback/admin/reports'):
            status, raw, hdrs = request('GET', args.base + path,
                                        token=args.operator_token, request_id=rid)
            parsed = parse_json(raw)
            ok = status == 200 and isinstance(parsed, list)
            print('%s: %s -> %d (%d rows, request_id=%s)'
                  % ('PASS' if ok else 'FAIL', path, status,
                     len(parsed) if isinstance(parsed, list) else -1,
                     hdrs.get('X-Request-Id', '-')))
            if not ok:
                failures.append(path)

    if args.mark_fixed:
        if not args.operator_token:
            print('FAIL: --mark-fixed needs UL_OPERATOR_TOKEN', file=sys.stderr)
            return 1
        rid = 'triage-fix-' + uuid.uuid4().hex[:8]
        status, raw, hdrs = request(
            'PUT', args.base + '/api/feedback/' + args.mark_fixed + '/status',
            token=args.operator_token, request_id=rid,
            body={'status': 'fixed', 'admin_notes': args.note})
        ok = status == 200
        print('%s: mark %s fixed -> %d (%s)'
              % ('PASS' if ok else 'FAIL', args.mark_fixed, status, raw[:160]))
        if not ok:
            failures.append('mark-fixed')

    if args.db:
        if not guard_db(args.db):
            return 2
        rows, bad = verify_audit(args.db)
        ok = bool(rows) and not bad
        print('%s: audit rows with actor+request_id: %d (%d incomplete)'
              % ('PASS' if ok else 'FAIL', len(rows), len(bad)))
        if not ok:
            failures.append('audit-rows')

    if failures:
        print('FAIL: feedback_triage: %s' % ', '.join(failures), file=sys.stderr)
        return 1
    print('PASS: feedback_triage completed with no failed assertions')
    return 0


if __name__ == '__main__':
    sys.exit(main())
