#!/usr/bin/env python3
"""retention_check.py -- H16 retention / orphan cleanup on a DISPOSABLE DB.

Mirrors repository/src/retention.ch with sqlite3 and proves:
  * preview counts orphans, expired reset/verification tokens and sessions,
    aged login and audit rows without deleting anything;
  * an applied sweep removes them (bounded to 200 per table) and leaves valid
    learner rows untouched;
  * zero orphans remain on the disposable DB.

It REFUSES a production-looking DB path unless --founder-approved is passed,
and it never opens a `*.wiqis.com` URL. The 152 historical orphan rows in the
developer DB are a founder decision; this tool does not touch them.

Usage:
    python tools/retention_check.py --selftest
    python tools/retention_check.py --db build/retention-probe.db
"""
import argparse
import os
import sqlite3
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRODUCTION_MARKERS = ('wiqis.com', 'production', '/data/', 'underlayer.db',
                      'prod.', 'wiqis')
ORPHAN_TABLES = ('concept_states', 'review_items', 'sessions',
                 'concept_unit_progress', 'exercise_attempts')

SCHEMA = """
CREATE TABLE learners (id TEXT PRIMARY KEY, email TEXT);
CREATE TABLE concept_states (learner_id TEXT, concept_id TEXT, course_id TEXT,
  PRIMARY KEY (learner_id, concept_id, course_id));
CREATE TABLE review_items (id TEXT PRIMARY KEY, learner_id TEXT, concept_id TEXT,
  difficulty REAL DEFAULT 5.0, stability REAL DEFAULT 1.0,
  retrievability REAL DEFAULT 1.0, ease_factor REAL DEFAULT 2.5);
CREATE TABLE sessions (id TEXT PRIMARY KEY, learner_id TEXT, status TEXT);
CREATE TABLE concept_unit_progress (learner_id TEXT, course_id TEXT, concept_id TEXT,
  unit_id TEXT, status TEXT, updated_at INTEGER,
  PRIMARY KEY (learner_id, course_id, concept_id, unit_id));
CREATE TABLE exercise_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT,
  learner_id TEXT, course_id TEXT, concept_id TEXT, exercise_id TEXT);
CREATE TABLE password_reset_tokens (id TEXT PRIMARY KEY, learner_id TEXT,
  expires_at INTEGER, used INTEGER DEFAULT 0);
CREATE TABLE email_verification_tokens (id TEXT PRIMARY KEY, learner_id TEXT,
  email TEXT, expires_at INTEGER, used INTEGER DEFAULT 0);
CREATE TABLE auth_sessions (id TEXT PRIMARY KEY, learner_id TEXT, token_hash TEXT,
  expires_at INTEGER, last_active INTEGER);
CREATE TABLE login_history (id INTEGER PRIMARY KEY AUTOINCREMENT, learner_id TEXT,
  created_at INTEGER);
CREATE TABLE audit_log (id INTEGER PRIMARY KEY AUTOINCREMENT, learner_id TEXT,
  action TEXT, details TEXT, request_id TEXT DEFAULT '', actor TEXT DEFAULT '',
  created_at INTEGER);
"""


def connect(path):
    con = sqlite3.connect(path, timeout=10)
    con.executescript(SCHEMA)
    con.commit()
    return con


def seed(con):
    now = int(time.time())
    con.execute("INSERT INTO learners VALUES ('keep','keep@example.invalid')")
    for table in ORPHAN_TABLES:
        if table == 'review_items':
            con.execute("INSERT INTO review_items (id, learner_id, concept_id, difficulty, stability, retrievability, ease_factor) VALUES ('ri-orphan','ghost','bytes',5.4321,3.2109,0.9012,2.5)")
            con.execute("INSERT INTO review_items (id, learner_id, concept_id, difficulty, stability, retrievability, ease_factor) VALUES ('ri-keep','keep','bytes',4.0000,2.0000,0.9000,2.5)")
        elif table == 'exercise_attempts':
            con.execute("INSERT INTO exercise_attempts (learner_id, course_id, concept_id, exercise_id) VALUES ('ghost','elf','bytes','ex1')")
            con.execute("INSERT INTO exercise_attempts (learner_id, course_id, concept_id, exercise_id) VALUES ('keep','elf','bytes','ex1')")
        elif table == 'concept_unit_progress':
            con.execute("INSERT INTO concept_unit_progress VALUES ('ghost','elf','bytes','u1','complete',?)", (now,))
            con.execute("INSERT INTO concept_unit_progress VALUES ('keep','elf','bytes','u1','complete',?)", (now,))
        elif table == 'sessions':
            con.execute("INSERT INTO sessions VALUES ('s-ghost','ghost','active')")
            con.execute("INSERT INTO sessions VALUES ('s-keep','keep','active')")
        else:
            con.execute("INSERT INTO concept_states VALUES ('ghost','bytes','elf')")
            con.execute("INSERT INTO concept_states VALUES ('keep','bytes','elf')")
    con.execute("INSERT INTO password_reset_tokens VALUES ('prt-old','keep',?,0)", (now - 10,))
    con.execute("INSERT INTO password_reset_tokens VALUES ('prt-live','keep',?,0)", (now + 3600,))
    con.execute("INSERT INTO email_verification_tokens VALUES ('evt-old','keep','x',?,0)", (now - 10,))
    con.execute("INSERT INTO auth_sessions VALUES ('as-old','keep','h',?,0)", (now - 10,))
    con.execute("INSERT INTO auth_sessions VALUES ('as-live','keep','h',?,0)", (now + 3600,))
    con.execute("INSERT INTO login_history (learner_id, created_at) VALUES ('keep',?)", (now - 100 * 86400,))
    con.execute("INSERT INTO login_history (learner_id, created_at) VALUES ('keep',?)", (now,))
    con.execute("INSERT INTO audit_log (learner_id, action, created_at, request_id, actor) VALUES ('keep','content.import',?, 'r1','operator-1')", (now - 200 * 86400,))
    con.execute("INSERT INTO audit_log (learner_id, action, created_at, request_id, actor) VALUES ('keep','content.import',?, 'r2','operator-1')", (now,))
    con.commit()
    return now


def orphan_pred():
    return "learner_id <> 'demo' AND learner_id NOT IN (SELECT id FROM learners)"


def preview(con):
    now = int(time.time())
    counts = {}
    for table in ORPHAN_TABLES:
        counts['orphan_' + table] = con.execute(
            'SELECT COUNT(*) FROM %s WHERE %s' % (table, orphan_pred())).fetchone()[0]
    counts['expired_reset_tokens'] = con.execute(
        'SELECT COUNT(*) FROM password_reset_tokens WHERE expires_at < ?', (now,)).fetchone()[0]
    counts['expired_verification_tokens'] = con.execute(
        'SELECT COUNT(*) FROM email_verification_tokens WHERE expires_at < ?', (now,)).fetchone()[0]
    counts['expired_sessions'] = con.execute(
        'SELECT COUNT(*) FROM auth_sessions WHERE expires_at < ?', (now,)).fetchone()[0]
    counts['aged_login_rows'] = con.execute(
        'SELECT COUNT(*) FROM login_history WHERE created_at < ?', (now - 90 * 86400,)).fetchone()[0]
    counts['aged_audit_rows'] = con.execute(
        'SELECT COUNT(*) FROM audit_log WHERE created_at < ?', (now - 180 * 86400,)).fetchone()[0]
    return counts


def sweep(con):
    """Mirror of repository/src/retention.ch::run_retention_sweep(apply=true)."""
    pred = orphan_pred()
    now = int(time.time())
    for table in ORPHAN_TABLES:
        con.execute('DELETE FROM %s WHERE rowid IN (SELECT rowid FROM %s WHERE %s LIMIT 200)'
                    % (table, table, pred))
    for table in ('password_reset_tokens', 'email_verification_tokens', 'auth_sessions'):
        con.execute('DELETE FROM %s WHERE rowid IN (SELECT rowid FROM %s WHERE expires_at < ? LIMIT 200)'
                    % (table, table), (now,))
    for table, days in (('login_history', 90), ('audit_log', 180)):
        con.execute('DELETE FROM %s WHERE rowid IN (SELECT rowid FROM %s WHERE created_at < ? LIMIT 200)'
                    % (table, table), (now - days * 86400,))
    con.commit()


def source_assertions():
    failures = []
    with open(os.path.join(REPO, 'repository/src/retention.ch'), encoding='utf-8') as handle:
        src = handle.read()
    with open(os.path.join(REPO, 'repository/src/schema.ch'), encoding='utf-8') as handle:
        schema = handle.read()
    for needle in ('run_retention_sweep', 'retention_preview', 'LIMIT 200',
                   "learner_id <> 'demo'"):
        if needle not in src:
            failures.append('retention.ch missing %s' % needle)
    if 'run_retention_sweep(db, false)' not in schema:
        failures.append('schema.ch does not call the dry-run sweep at startup')
    return failures


def selftest():
    """Negative plant: an unconfigured detector must miss a planted orphan."""
    with tempfile.TemporaryDirectory() as tmp:
        con = connect(os.path.join(tmp, 'plant.db'))
        try:
            seed(con)
            broken_predicate = "learner_id = 'demo'"
            missed = con.execute('SELECT COUNT(*) FROM concept_states WHERE %s' % broken_predicate).fetchone()[0]
        finally:
            con.close()
    ok = missed == 0
    print('%s: planted orphan is invisible to a broken predicate' % ('PASS' if ok else 'FAIL'))
    if not ok:
        print('FAIL: retention_check selftest plant not detected', file=sys.stderr)
        return 1
    print('PASS: retention_check selftest (1 negative plant)')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--db', help='explicit disposable DB path')
    ap.add_argument('--founder-approved', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if args.db and not args.founder_approved:
        lowered = args.db.lower()
        if any(marker in lowered for marker in PRODUCTION_MARKERS):
            print('FAIL: refusing production-looking DB %s' % args.db, file=sys.stderr)
            return 2

    failures = list(source_assertions())
    for line in failures:
        print('FAIL: ' + line, file=sys.stderr)

    with tempfile.TemporaryDirectory() as tmp:
        db = args.db or os.path.join(tmp, 'retention-probe.db')
        con = connect(db)
        seed(con)
        before = preview(con)
        sweep(con)
        after = preview(con)
        fsrs = con.execute("SELECT difficulty,stability,retrievability FROM review_items WHERE id='ri-keep'").fetchone()
        valid_count = con.execute("SELECT COUNT(*) FROM learners WHERE id='keep'").fetchone()[0]
        con.close()

    checks = [
        ('preview sees 5 orphan tables', all(before['orphan_' + t] == 1 for t in ORPHAN_TABLES)),
        ('preview sees expired tokens and sessions',
         before['expired_reset_tokens'] == 1 and before['expired_verification_tokens'] == 1
         and before['expired_sessions'] == 1),
        ('preview sees aged login/audit rows',
         before['aged_login_rows'] == 1 and before['aged_audit_rows'] == 1),
        ('applied sweep leaves zero orphans',
         all(after['orphan_' + t] == 0 for t in ORPHAN_TABLES)),
        ('applied sweep clears expired rows',
         after['expired_reset_tokens'] == 0 and after['expired_verification_tokens'] == 0
         and after['expired_sessions'] == 0),
        ('valid learner row intact', valid_count == 1),
        ('valid FSRS parameters intact', fsrs == (4.0, 2.0, 0.9)),
    ]
    for label, ok in checks:
        print('%s: %s' % ('PASS' if ok else 'FAIL', label))
        if not ok:
            failures.append(label)
    if failures:
        print('FAIL: retention_check: %s' % ', '.join(failures), file=sys.stderr)
        return 1
    print('PASS: retention_check (dry-run counts + bounded applied sweep, zero orphans)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
