#!/usr/bin/env python3
"""G13 — safe guest → account progress takeover, end to end on a local server.

Asserts:
  * one-shot token: a replay is refused with 409 and writes nothing;
  * two offline guest lessons appear under the signed-in learner;
  * the per-key updated_at rule is the SAME as /api/progress/sync: a newer
    server row wins over an older guest change;
  * FSRS-authoritative columns are untouched.

Stdlib only, explicit timeouts, no shell. Refuses non-loopback bases without
--allow-remote and a non-throwaway DB path without --db. --selftest plants
wrong outcome records and must reject them.
"""
import argparse
import hashlib
import json
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 20


def fetch(base, path, data=None, method=None, token=None):
    headers = {'User-Agent': 'takeover-check/1'}
    raw = None
    if data is not None:
        headers['Content-Type'] = 'application/json'
        raw = json.dumps(data).encode('utf-8')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base.rstrip('/') + path, data=raw,
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8', 'replace'))
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode('utf-8', 'replace')


def is_local(base):
    return (urllib.parse.urlsplit(base).hostname or '') in ('localhost', '127.0.0.1', '::1')


def evaluate(result, guest_changes, fsrs_before, fsrs_after):
    """Pure outcome check — reused by the live run and by --selftest."""
    problems = []
    if not result.get('applied'):
        problems.append('takeover did not report applied')
    rows = {(r['course_id'], r['concept_id'], r['unit_id']): r
            for r in result.get('changes', [])}
    for change in guest_changes:
        key = (change['course_id'], change['concept_id'], change['unit_id'])
        if key not in rows:
            problems.append('guest key missing from response: %s' % (key,))
    if fsrs_before != fsrs_after:
        problems.append('FSRS-authoritative row changed')
    return problems


def selftest():
    good_change = {'course_id': 'elf', 'concept_id': 'bytes',
                   'unit_id': 'u1', 'status': 'completed',
                   'step_index': 1, 'updated_at': 1000}
    good = {'applied': True, 'changes': [dict(good_change, updated_at=2000)]}
    fsrs = {'stability': 7.25, 'reps': 4, 'next_review': 90000}
    plants = [
        ('not applied', dict(good, applied=False), [good_change], fsrs, fsrs),
        ('guest key missing', good, [dict(good_change, unit_id='u9')], fsrs, fsrs),
        ('FSRS mutated', good, [good_change], fsrs, dict(fsrs, reps=5)),
    ]
    ok = not evaluate(good, [good_change], fsrs, fsrs)
    print(('PASS' if ok else 'FAIL') + ': good takeover outcome accepted')
    for label, result, changes, before, after in plants:
        bad = evaluate(result, changes, before, after)
        ok = ok and bool(bad)
        print(('%s: %s rejected (%s)' % ('PASS' if bad else 'FAIL', label,
                                         '; '.join(bad) or 'none')))
    print('TAKEOVER SELFTEST %s' % ('4/4 — controls accepted, plants rejected'
                                    if ok else 'incomplete'))
    return 0 if ok else 1


def learner_id_for(db_path, token):
    conn = sqlite3.connect(db_path, timeout=10)
    try:
        row = conn.execute('SELECT learner_id FROM auth_sessions WHERE token_hash = ?',
                           (hashlib.sha256(token.encode()).hexdigest(),)).fetchone()
        return row[0] if row else None
    finally:
        conn.close()


def fsrs_row(db_path, learner_id):
    conn = sqlite3.connect(db_path, timeout=10)
    try:
        row = conn.execute(
            'SELECT stability, reps, next_review FROM review_items '
            'WHERE learner_id = ? AND course_id = ? AND concept_id = ? LIMIT 1',
            (learner_id, 'elf', 'bytes')).fetchone()
        return dict(zip(('stability', 'reps', 'next_review'), row)) if row else None
    finally:
        conn.close()


def count_unit_rows(db_path, learner_id):
    conn = sqlite3.connect(db_path, timeout=10)
    try:
        return conn.execute('SELECT COUNT(*) FROM concept_unit_progress WHERE learner_id = ?',
                            (learner_id,)).fetchone()[0]
    finally:
        conn.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--base', default='http://127.0.0.1:9066')
    ap.add_argument('--db', help='throwaway local SQLite file (required for live runs)')
    ap.add_argument('--allow-remote', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    base = args.base.rstrip('/')
    if not is_local(base) and not args.allow_remote:
        print('REFUSED: non-local base (pass --allow-remote)')
        return 2
    db = args.db
    if not db:
        print('FAIL: --db (throwaway local SQLite file) is required')
        return 2
    if not db.endswith('.db') or ('finalbatch' not in db and 'test' not in db):
        print('REFUSED: DB %r does not look throwaway' % db)
        return 2

    suffix = str(int(time.time() * 1000))
    status, body = fetch(base, '/api/auth/register', {
        'email': 'takeover-%s@example.test' % suffix,
        'password': 'takeover-pass-123', 'name': 'Takeover Learner'})
    if status != 200 or not isinstance(body, dict):
        print('FAIL register: %s %s' % (status, body))
        return 1
    token = body.get('session_token')
    lid = learner_id_for(db, token)
    if not lid:
        print('FAIL: could not resolve learner id from throwaway DB')
        return 1

    conn = sqlite3.connect(db, timeout=10)
    now = int(time.time())
    conn.execute(
        'INSERT OR REPLACE INTO review_items (id, learner_id, course_id, concept_id, '
        'stability, reps, next_review, last_review) VALUES (?,?,?,?,?,?,?,?)',
        ('takeover-fsrs-' + suffix, lid, 'elf', 'bytes', 7.25, 4,
         now + 9 * 86400, now))
    conn.commit()
    conn.close()
    fsrs_before = fsrs_row(db, lid)

    # A newer SERVER state for one key: the guest's older write must not win.
    newer = {'course_id': 'elf', 'concept_id': 'bytes', 'unit_id': 'u1',
             'status': 'completed', 'step_index': 4, 'updated_at': now + 10}
    status, _ = fetch(base, '/api/progress/sync',
                      {'client_now': now, 'changes': [newer]}, token=token)
    if status != 200:
        print('FAIL newer server seed: HTTP %s' % status)
        return 1

    guest = [
        {'course_id': 'elf', 'concept_id': 'bytes', 'unit_id': 'u1',
         'status': 'started', 'step_index': 1, 'updated_at': now - 100},
        {'course_id': 'elf', 'concept_id': 'file-layout', 'unit_id': 'u2',
         'status': 'completed', 'step_index': 2, 'updated_at': now - 90},
    ]
    status, tok = fetch(base, '/api/progress/takeover/token', {})
    if status != 200 or not tok.get('token'):
        print('FAIL token: %s %s' % (status, tok))
        return 1
    status, result = fetch(base, '/api/progress/takeover',
                           {'token': tok['token'], 'changes': guest}, token=token)
    print('takeover -> %s' % status)
    if status != 200:
        print('FAIL takeover: %s' % result)
        return 1

    problems = evaluate(result, guest, fsrs_before, fsrs_row(db, lid))
    rows = {(r['course_id'], r['concept_id'], r['unit_id']): r
            for r in result.get('changes', [])}
    u1 = rows.get(('elf', 'bytes', 'u1'), {})
    if u1.get('status') != 'completed' or u1.get('step_index') != 4:
        problems.append('newer server state lost: %r' % u1)
    u2 = rows.get(('elf', 'file-layout', 'u2'), {})
    if u2.get('status') != 'completed':
        problems.append('second guest lesson missing: %r' % u2)

    rows_before_replay = count_unit_rows(db, lid)
    status, replay = fetch(base, '/api/progress/takeover',
                           {'token': tok['token'], 'changes': guest}, token=token)
    print('replay -> %s' % status)
    if status != 409:
        problems.append('replay was not refused: HTTP %s' % status)
    if count_unit_rows(db, lid) != rows_before_replay:
        problems.append('replay wrote rows')

    status, pulled = fetch(base, '/api/progress/sync?since=0', token=token)
    if status != 200:
        problems.append('pull HTTP %s' % status)
    else:
        keys = [(c['course_id'], c['concept_id'], c['unit_id'])
                for c in pulled.get('changes', [])]
        for g in guest:
            if (g['course_id'], g['concept_id'], g['unit_id']) not in keys:
                problems.append('guest key absent from /api/progress/sync')

    for item in problems:
        print('FAIL ' + item)
    print('TAKEOVER CHECK %d failure(s)' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
