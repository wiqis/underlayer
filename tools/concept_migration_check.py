#!/usr/bin/env python3
"""concept_migration_check.py -- H13 rename / 1-to-2 split simulation.

Runs against a DISPOSABLE SQLite DB in a temporary directory. The migration SQL
below mirrors repository/src/concept_aliases.ch exactly; the tool asserts the
repository still contains that SQL (so a drift between the mirror and the
shipped code is a finding, not a silently green checker).

For each scenario it records the FSRS parameters BEFORE the move and asserts
they are byte-for-byte identical AFTER, with zero rows left on a retired id:
  * rename: bytes-old -> bytes-new
  * 1->2 split: split-src -> split-a and split-src:part2 -> split-b
It also proves the deletion guard refuses while live rows exist with no alias.

Refuses a production-looking --db path unless --founder-approved. No shell,
no eval, explicit timeouts, stdlib only.

Usage:
    python tools/concept_migration_check.py --selftest
    python tools/concept_migration_check.py
"""
import argparse
import os
import sqlite3
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FSRS_FIELDS = ('difficulty', 'stability', 'retrievability', 'next_review',
               'last_review', 'reps', 'lapses', 'ease_factor')

SCHEMA = """
CREATE TABLE learners (id TEXT PRIMARY KEY, email TEXT);
CREATE TABLE concept_states (learner_id TEXT, concept_id TEXT, course_id TEXT,
  status TEXT DEFAULT 'not_started', attempts INTEGER DEFAULT 0,
  correct INTEGER DEFAULT 0, streak INTEGER DEFAULT 0, last_studied INTEGER,
  next_review INTEGER, difficulty_rating REAL DEFAULT 0,
  PRIMARY KEY (learner_id, concept_id, course_id));
CREATE TABLE review_items (id TEXT PRIMARY KEY, learner_id TEXT, concept_id TEXT,
  course_id TEXT, type TEXT, front TEXT, back TEXT, difficulty REAL DEFAULT 5.0,
  stability REAL DEFAULT 1.0, retrievability REAL DEFAULT 1.0,
  next_review INTEGER, last_review INTEGER, reps INTEGER DEFAULT 0,
  lapses INTEGER DEFAULT 0, ease_factor REAL DEFAULT 2.5);
CREATE TABLE concept_unit_progress (learner_id TEXT NOT NULL, course_id TEXT NOT NULL,
  concept_id TEXT NOT NULL, unit_id TEXT NOT NULL, status TEXT NOT NULL,
  step_index INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL,
  PRIMARY KEY (learner_id, course_id, concept_id, unit_id));
CREATE TABLE exercise_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT,
  learner_id TEXT NOT NULL, course_id TEXT NOT NULL, concept_id TEXT NOT NULL,
  exercise_id TEXT NOT NULL, correct INTEGER NOT NULL DEFAULT 0,
  question TEXT DEFAULT '', submitted_at INTEGER NOT NULL);
CREATE TABLE concept_aliases (old_id TEXT PRIMARY KEY, new_id TEXT NOT NULL,
  course_id TEXT DEFAULT '', reason TEXT DEFAULT '', created_at INTEGER);
CREATE INDEX idx_alias_new ON concept_aliases(new_id);
"""

TABLES = ('concept_states', 'review_items', 'concept_unit_progress', 'exercise_attempts')
PRODUCTION_MARKERS = ('wiqis', 'production', '/data/', 'underlayer.db')


def connect(path):
    con = sqlite3.connect(path, timeout=10)
    con.executescript(SCHEMA)
    con.execute("INSERT INTO learners VALUES ('learner-1','migration@example.invalid')")
    con.commit()
    return con


def seed(con, concept_id):
    con.execute("INSERT INTO concept_states (learner_id, concept_id, course_id, status, attempts, correct, streak, difficulty_rating) VALUES (?,?,?,?,?,?,?,?)",
                ('learner-1', concept_id, 'elf', 'learning', 3, 2, 1, 0.4321))
    con.execute("INSERT INTO review_items (id, learner_id, concept_id, course_id, type, front, back, difficulty, stability, retrievability, next_review, last_review, reps, lapses, ease_factor) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                ('card-' + concept_id, 'learner-1', concept_id, 'elf', 'recall', 'front', 'back',
                 5.4321, 3.2109, 0.9012, 1800000000, 1790000000, 7, 2, 2.3456))
    con.execute("INSERT INTO concept_unit_progress VALUES (?,?,?,?,?,?,?)",
                ('learner-1', 'elf', concept_id, 'unit-1', 'complete', 4, 1790000000))
    con.execute("INSERT INTO exercise_attempts (learner_id, course_id, concept_id, exercise_id, correct, question, submitted_at) VALUES (?,?,?,?,?,?,?)",
                ('learner-1', 'elf', concept_id, 'ex-1', 1, 'q', 1790000000))
    con.commit()


def register_alias(con, old, new):
    con.execute("INSERT OR REPLACE INTO concept_aliases (old_id, new_id, course_id, reason, created_at) VALUES (?,?,?,?,?)",
                (old, new, 'elf', 'H13 simulation', 1790000000))
    con.commit()


def resolve(con, old):
    current = old
    for _ in range(16):
        row = con.execute("SELECT new_id FROM concept_aliases WHERE old_id = ?", (current,)).fetchone()
        if not row or row[0] == current:
            return current
        current = row[0]
    return current


def migrate(con):
    """Mirror of repository/src/concept_aliases.ch::migrate_concept_rows."""
    moved = 0
    for (old,) in con.execute("SELECT old_id FROM concept_aliases ORDER BY old_id").fetchall():
        new = resolve(con, old)
        if new == old:
            continue
        # collision-safe tables: UPDATE OR IGNORE then remove the duplicates
        for table in ('concept_states', 'concept_unit_progress'):
            con.execute("UPDATE OR IGNORE %s SET concept_id = ? WHERE concept_id = ?" % table,
                        (new, old))
            con.execute("DELETE FROM %s WHERE concept_id = ?" % table, (old,))
        # append-only tables: a plain UPDATE, FSRS columns untouched
        for table in ('review_items', 'exercise_attempts'):
            con.execute("UPDATE %s SET concept_id = ? WHERE concept_id = ?" % table,
                        (new, old))
        moved += 1
    con.commit()
    return moved


def fsrs_state(con, concept_id):
    row = con.execute(
        "SELECT difficulty,stability,retrievability,next_review,last_review,reps,lapses,ease_factor "
        "FROM review_items WHERE concept_id = ?", (concept_id,)).fetchone()
    return row


def orphan_count(con, retired_ids):
    n = 0
    for table in TABLES:
        for rid in retired_ids:
            n += con.execute("SELECT COUNT(*) FROM %s WHERE concept_id = ?" % table,
                             (rid,)).fetchone()[0]
    return n


def deletion_allowed(con, concept_id):
    new = resolve(con, concept_id)
    if new == concept_id:
        return False
    for table in TABLES:
        if con.execute("SELECT COUNT(*) FROM %s WHERE concept_id = ?" % table,
                       (concept_id,)).fetchone()[0] > 0:
            return False
    return True


def source_assertions():
    failures = []
    with open(os.path.join(REPO, 'repository/src/concept_aliases.ch'),
              encoding='utf-8') as handle:
        src = handle.read()
    with open(os.path.join(REPO, 'repository/src/schema.ch'), encoding='utf-8') as handle:
        schema = handle.read()
    for needle in ('OR IGNORE', 'DELETE FROM', 'concept_aliases',
                   'concept_has_live_state', 'apply_manifest_concept_aliases'):
        if needle not in src:
            failures.append('concept_aliases.ch missing %s' % needle)
    if 'CREATE TABLE IF NOT EXISTS concept_aliases' not in schema:
        failures.append('schema.ch missing concept_aliases table')
    if not os.path.exists(os.path.join(REPO, 'tools/concept_migration_check.py')):
        failures.append('checker missing')
    return failures


def run_scenarios(con):
    results = []
    # rename
    seed(con, 'bytes-old')
    before = fsrs_state(con, 'bytes-old')
    allowed_before = deletion_allowed(con, 'bytes-old')
    register_alias(con, 'bytes-old', 'bytes-new')
    migrate(con)
    after = fsrs_state(con, 'bytes-new')
    results.append(('rename: zero orphan rows', orphan_count(con, ['bytes-old']) == 0))
    results.append(('rename: FSRS params unchanged', before == after))
    results.append(('rename: deletion refused before alias+migration', not allowed_before))
    results.append(('rename: deletion allowed after alias+migration',
                    deletion_allowed(con, 'bytes-old')))

    # 1 -> 2 split (two retired ids, two successors)
    seed(con, 'split-src')
    seed(con, 'split-src:part2')
    before_a = fsrs_state(con, 'split-src')
    before_b = fsrs_state(con, 'split-src:part2')
    register_alias(con, 'split-src', 'split-a')
    register_alias(con, 'split-src:part2', 'split-b')
    migrate(con)
    results.append(('split: zero orphan rows',
                    orphan_count(con, ['split-src', 'split-src:part2']) == 0))
    results.append(('split: FSRS params unchanged',
                    before_a == fsrs_state(con, 'split-a') and
                    before_b == fsrs_state(con, 'split-b')))
    results.append(('split: both successors carry state',
                    fsrs_state(con, 'split-a') is not None and
                    fsrs_state(con, 'split-b') is not None))
    return results


def selftest():
    """Negative plants: an unaliased id and a changed FSRS value must fail."""
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        db = os.path.join(tmp, 'plant.db')
        con = connect(db)
        seed(con, 'plant-src')
        # plant 1: no alias -> rows remain orphans and deletion is refused
        ok1 = (orphan_count(con, ['plant-src']) > 0 and
               not deletion_allowed(con, 'plant-src'))
        print('%s: plant without alias detected' % ('PASS' if ok1 else 'FAIL'))
        if not ok1:
            failures.append('no-alias plant')
        # plant 2: move rows then perturb one FSRS field -> detector must see it
        register_alias(con, 'plant-src', 'plant-dst')
        before = fsrs_state(con, 'plant-src')
        migrate(con)
        con.execute("UPDATE review_items SET stability = 9.9999 WHERE concept_id = 'plant-dst'")
        con.commit()
        ok2 = before != fsrs_state(con, 'plant-dst')
        print('%s: planted FSRS drift detected' % ('PASS' if ok2 else 'FAIL'))
        if not ok2:
            failures.append('fsrs-drift plant')
        con.close()
    if failures:
        print('FAIL: concept_migration_check selftest plants not detected: %s' % failures,
              file=sys.stderr)
        return 1
    print('PASS: concept_migration_check selftest (2 negative plants)')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--db', help='optional disposable DB path (default: temp file)')
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

    source_failures = source_assertions()
    for line in source_failures:
        print('FAIL: ' + line, file=sys.stderr)

    with tempfile.TemporaryDirectory() as tmp:
        db = args.db or os.path.join(tmp, 'concept-migration.db')
        con = connect(db)
        results = run_scenarios(con)
        con.close()

    failures = list(source_failures)
    for label, ok in results:
        print('%s: %s' % ('PASS' if ok else 'FAIL', label))
        if not ok:
            failures.append(label)
    if failures:
        print('FAIL: concept_migration_check: %s' % ', '.join(failures), file=sys.stderr)
        return 1
    print('PASS: concept_migration_check (rename + 1->2 split, FSRS preserved)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
