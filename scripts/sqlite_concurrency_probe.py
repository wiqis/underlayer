#!/usr/bin/env python3
"""sqlite_concurrency_probe.py -- 40-writer proof for B3 (FULLMUTEX).

Starts the freshly built server against a DISPOSABLE database, fires N
concurrent registrations from N distinct loopback source addresses (so the
8/5-minute auth limiter cannot turn this into a rate-limit test), then reads
the DB directly to count the rows that were actually stored. Also scans the
server log for SQLITE_BUSY / "database is locked" / SQL FAILED.

The tool refuses a production-looking DB path. It never touches a deployed
service: the URL is always 127.0.0.1 on a caller-supplied local port.

Usage:
    py -3 scripts/sqlite_concurrency_probe.py --exe build/underlayer-h5h6h7.exe
Exit 0 when all N writers stored a distinct row with no lock errors.
"""
import argparse
import concurrent.futures
import http.client
import json
import os
import pathlib
import re
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.request

FORBIDDEN_NAMES = {'underlayer.db', 'wiqis.db', 'production.db', 'prod.db'}


def safe_db_path(raw: str) -> pathlib.Path:
    path = pathlib.Path(raw).resolve()
    lowered = str(path).lower()
    if path.name.lower() in FORBIDDEN_NAMES or 'production' in lowered or '\\prod\\' in lowered:
        raise SystemExit('refusing a production-looking DB path: %s' % path)
    return path


def wait_health(port: int, timeout: float) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen('http://127.0.0.1:%d/api/health' % port,
                                        timeout=2.0) as response:
                if response.status == 200:
                    return True
        except Exception:
            time.sleep(0.25)
    return False


def register_one(port: int, index: int, stamp: int):
    """One registration from its own loopback source IP."""
    body = json.dumps({
        'email': 'conc-%d-%d@invalid.test' % (index, stamp),
        'password': 'ProbePass123!',
        'name': 'Concurrency Probe %d' % index,
    }).encode('utf-8')
    source = '127.0.0.%d' % (index + 2)
    conn = None
    try:
        conn = http.client.HTTPConnection('127.0.0.1', port, timeout=25.0,
                                          source_address=(source, 0))
        conn.request('POST', '/api/auth/register', body=body,
                     headers={'Content-Type': 'application/json',
                              'Content-Length': str(len(body))})
        response = conn.getresponse()
        raw = response.read(4096).decode('utf-8', 'replace')
        try:
            parsed = json.loads(raw)
        except ValueError:
            parsed = {'raw': raw[:120]}
        return index, response.status, parsed, source
    except Exception as exc:
        return index, None, {'error': '%s: %s' % (type(exc).__name__, exc)}, source
    finally:
        if conn is not None:
            conn.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--exe', default='build/underlayer-h5h6h7.exe')
    ap.add_argument('--port', type=int, default=9037)
    ap.add_argument('--writers', type=int, default=40)
    ap.add_argument('--db', default='build/b3-concurrent.db')
    ap.add_argument('--courses', default='courses')
    ap.add_argument('--cwd', default='.')
    ap.add_argument('--log', default='build/b3-concurrent.out.log')
    ap.add_argument('--boot-timeout', type=float, default=90.0)
    args = ap.parse_args()

    if args.writers > 250:
        raise SystemExit('--writers must stay within the loopback /24 (<=250)')
    db_path = safe_db_path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()
    for suffix in ('-wal', '-shm'):
        side = pathlib.Path(str(db_path) + suffix)
        if side.exists():
            side.unlink()
    log_path = pathlib.Path(args.log)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    cwd = pathlib.Path(args.cwd).resolve()
    exe = pathlib.Path(args.exe)
    if not exe.is_absolute():
        exe = (cwd / exe).resolve()

    env = os.environ.copy()
    env['PORT'] = str(args.port)
    env['DATABASE_URL'] = str(db_path)
    env['COURSES_DIR'] = str((cwd / args.courses).resolve())
    env['UL_BUILD_COMMIT'] = 'b3-local-probe'
    env['UL_BUILD_COMPILER_VERSION'] = 'Chemical v0.6.0'
    env['UL_BUILD_MODE'] = 'debug'
    env['UL_BUILD_AT'] = '2026-11-27T00:00:00Z'

    print('B3 probe: exe=%s db=%s writers=%d' % (exe, db_path, args.writers))
    with open(str(log_path), 'w', encoding='utf-8') as log_file:
        proc = subprocess.Popen([str(exe)], cwd=str(cwd), env=env,
                                stdout=log_file, stderr=subprocess.STDOUT)
        try:
            if not wait_health(args.port, args.boot_timeout):
                print('FAIL: server did not become healthy in %.1fs' % args.boot_timeout,
                      file=sys.stderr)
                return 1
            # The auth limiter is 8/5min per socket peer. Every loopback source
            # resolves to the same peer here, so a disposable-DB cleaner keeps
            # the bucket empty; this test measures concurrent WRITES, not rate
            # limiting. It never runs against a production DB.
            stop_cleaner = threading.Event()

            def clear_rate_limits():
                conn = sqlite3.connect(str(db_path), timeout=5.0)
                try:
                    while not stop_cleaner.is_set():
                        try:
                            conn.execute("DELETE FROM rate_limits")
                            conn.commit()
                        except sqlite3.Error:
                            pass
                        stop_cleaner.wait(0.02)
                finally:
                    conn.close()

            cleaner = threading.Thread(target=clear_rate_limits, daemon=True)
            cleaner.start()
            stamp = int(time.time())
            started = time.time()
            try:
                with concurrent.futures.ThreadPoolExecutor(max_workers=args.writers) as pool:
                    results = list(pool.map(lambda i: register_one(args.port, i, stamp),
                                            range(args.writers)))
            finally:
                stop_cleaner.set()
                cleaner.join(timeout=5)
            elapsed = time.time() - started
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=10)

    statuses = {}
    for _, status, _, _ in results:
        statuses[status] = statuses.get(status, 0) + 1
    print('B3 probe: HTTP statuses %s in %.2fs' % (statuses, elapsed))
    tokens = sum(1 for _, status, body, _ in results
                 if status == 200 and bool(body.get('session_token')))
    print('B3 probe: registrations returning a session token: %d/%d'
          % (tokens, args.writers))

    con = sqlite3.connect(db_path.as_uri() + '?mode=ro', uri=True, timeout=10)
    try:
        stored = con.execute(
            "SELECT COUNT(*) FROM learners WHERE email LIKE 'conc-%@invalid.test'"
        ).fetchone()[0]
        distinct = con.execute(
            "SELECT COUNT(DISTINCT email) FROM learners WHERE email LIKE 'conc-%@invalid.test'"
        ).fetchone()[0]
        integrity = con.execute('PRAGMA integrity_check').fetchone()[0]
    finally:
        con.close()
    print('B3 probe: stored rows=%d distinct emails=%d integrity_check=%s'
          % (stored, distinct, integrity))

    log_text = log_path.read_text(encoding='utf-8', errors='replace')
    lock_hits = [line for line in log_text.splitlines()
                 if re.search(r'database is locked|SQLITE_BUSY|SQL FAILED|SQL STEP FAILED',
                              line, re.I)]
    print('B3 probe: FULLMUTEX log line present=%s'
          % ('SQLITE_OPEN_FULLMUTEX' in log_text))
    if lock_hits:
        for line in lock_hits[:5]:
            print('  LOCK/FAIL LOG: ' + line[:220])

    ok = (tokens == args.writers and stored == args.writers
          and distinct == args.writers and integrity == 'ok' and not lock_hits
          and 'SQLITE_OPEN_FULLMUTEX' in log_text)
    print('B3 probe: %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
