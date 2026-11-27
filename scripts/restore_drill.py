#!/usr/bin/env python3
"""restore_drill.py -- H6 point-in-time recovery drill on a STAGING copy.

Creates a throwaway source DB, writes one account + one progress row, takes a
verified snapshot with tools/backup_db.py, restores that snapshot into a
separate STAGING path, and verifies health + login + the progress row there.
The production DB path is never opened or written.

Usage:
    py -3 scripts/restore_drill.py --exe build/underlayer-h5h6h7.exe
Prints the measured RPO (snapshot age at restore) and RTO (restart to verified).
"""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from shutdown_probe import request, start, wait_health  # noqa: E402

EMAIL = 'h6-drill@invalid.test'
PASSWORD = 'ProbePass123!'
CHANGE = {'course_id': 'elf', 'concept_id': 'bytes', 'unit_id': 'h6-drill-unit',
          'status': 'completed', 'step_index': 1}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--exe', default='build/underlayer-h5h6h7.exe')
    ap.add_argument('--port', type=int, default=9039)
    ap.add_argument('--cwd', default='.')
    ap.add_argument('--work', default='build/h6')
    args = ap.parse_args()

    cwd = pathlib.Path(args.cwd).resolve()
    work = pathlib.Path(args.work)
    if not work.is_absolute():
        work = cwd / work
    work.mkdir(parents=True, exist_ok=True)
    src_db = work / 'source.db'
    staging_db = work / 'staging.db'
    backup_dir = work / 'snapshots'
    backup_dir.mkdir(parents=True, exist_ok=True)
    for path in [src_db, staging_db] + [pathlib.Path(str(p) + s)
                                        for p in (src_db, staging_db)
                                        for s in ('-wal', '-shm')]:
        if path.exists():
            path.unlink()
    exe = pathlib.Path(args.exe)
    if not exe.is_absolute():
        exe = cwd / exe
    env = os.environ.copy()
    env.update(PORT=str(args.port), DATABASE_URL=str(src_db),
               COURSES_DIR=str(cwd / 'courses'),
               UL_BUILD_COMMIT='h6-local-drill',
               UL_BUILD_COMPILER_VERSION='Chemical v0.6.0',
               UL_BUILD_MODE='debug', UL_BUILD_AT='2026-11-27T00:00:00Z')

    proc = start(exe, env, cwd, work / 'source.out.log')
    try:
        if not wait_health(args.port, 90.0):
            print('FAIL: source server did not become healthy', file=sys.stderr)
            return 1
        st, reg = request('POST', args.port, '/api/auth/register',
                          {'email': EMAIL, 'password': PASSWORD, 'name': 'H6 drill'})
        token = reg.get('session_token') if st == 200 else None
        if not token:
            print('FAIL: source registration %s %s' % (st, str(reg)[:120]),
                  file=sys.stderr)
            return 1
        stamp = int(time.time())
        st, _ = request('POST', args.port, '/api/progress/sync',
                        {'client_now': stamp, 'changes': [dict(CHANGE, updated_at=stamp)]},
                        token=token)
        if st != 200:
            print('FAIL: source sync push %s' % st, file=sys.stderr)
            return 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=10)
    print('H6 drill: source account + progress row written and server stopped')

    backup = subprocess.run(
        [sys.executable, str(cwd / 'tools' / 'backup_db.py'), str(src_db), str(backup_dir)],
        cwd=str(cwd), text=True, capture_output=True, timeout=60)
    print(backup.stdout.strip())
    if backup.returncode != 0:
        print(backup.stderr.strip(), file=sys.stderr)
        return 1
    snapshot = None
    for line in backup.stdout.splitlines():
        if line.startswith('backup_db: dest '):
            snapshot = pathlib.Path(line.split('dest ', 1)[1].strip())
    if snapshot is None or not snapshot.is_file():
        print('FAIL: no snapshot path reported', file=sys.stderr)
        return 1
    digest = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    print('H6 drill: snapshot=%s bytes=%d sha256=%s'
          % (snapshot.name, snapshot.stat().st_size, digest))

    snapshot_at = time.time()
    shutil.copy2(str(snapshot), str(staging_db))
    env['DATABASE_URL'] = str(staging_db)
    restored_at = None
    proc2 = start(exe, env, cwd, work / 'staging.out.log')
    try:
        started = time.time()
        if not wait_health(args.port, 90.0):
            print('FAIL: staging server did not become healthy', file=sys.stderr)
            return 1
        st, body = request('POST', args.port, '/api/auth/login',
                           {'email': EMAIL, 'password': PASSWORD})
        if st != 200 or not body.get('session_token'):
            print('FAIL: staging login %s %s' % (st, str(body)[:120]), file=sys.stderr)
            return 1
        st2, pulled = request('GET', args.port, '/api/progress/sync?since=0',
                              token=body['session_token'])
        rows = pulled.get('changes', []) if isinstance(pulled, dict) else []
        found = any(r.get('unit_id') == CHANGE['unit_id'] for r in rows)
        restored_at = time.time()
        rto = restored_at - started
        print('H6 drill: staging health=200 login=200 sync=%s progress_row_found=%s'
              % (st2, found))
        if st2 != 200 or not found:
            return 1
    finally:
        proc2.terminate()
        try:
            proc2.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc2.kill()
            proc2.wait(timeout=10)

    print('H6 drill: sha256=%s RPO_measured=%.1fs (snapshot age at restore) '
          'RTO_measured=%.1fs (restart-to-verified)' % (digest, restored_at - snapshot_at, rto))
    print('H6 drill: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
