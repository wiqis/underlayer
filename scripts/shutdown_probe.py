#!/usr/bin/env python3
"""shutdown_probe.py -- H7 graceful-shutdown drill on a DISPOSABLE server.

1. Start the new binary against a throwaway DB/ports.
2. Register one learner, then put logins and a POST /api/progress/sync in
   flight and signal the process while they run.
3. Require the log to show the drain line and "shutdown complete", with no
   "database is locked" / SQL FAILED.
4. Restart on the SAME db and prove health + login + the progress row survive.

Never points at a deployed service. Refuses production-looking DB paths.
Windows: starts a new process group and sends CTRL_BREAK_EVENT, which reaches
the SIGBREAK handler registered in app/main.ch; POSIX uses SIGTERM.
Exit 0 only when every assertion passes.
"""
import argparse
import http.client
import json
import os
import pathlib
import re
import signal
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

FORBIDDEN_NAMES = {'underlayer.db', 'wiqis.db', 'production.db', 'prod.db'}
CHANGE = {'course_id': 'elf', 'concept_id': 'bytes', 'unit_id': 'h7-probe-unit',
          'status': 'completed', 'step_index': 1}


def safe_db_path(raw: str) -> pathlib.Path:
    path = pathlib.Path(raw).resolve()
    lowered = str(path).lower()
    if path.name.lower() in FORBIDDEN_NAMES or 'production' in lowered:
        raise SystemExit('refusing a production-looking DB path: %s' % path)
    return path


def request(method: str, port: int, path: str, payload=None, token=None,
            timeout: float = 10.0):
    body = json.dumps(payload).encode('utf-8') if payload is not None else None
    conn = http.client.HTTPConnection('127.0.0.1', port, timeout=timeout)
    headers = {'Accept': 'application/json'}
    if body is not None:
        headers['Content-Type'] = 'application/json'
        headers['Content-Length'] = str(len(body))
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        conn.request(method, path, body=body, headers=headers)
        response = conn.getresponse()
        raw = response.read(32768).decode('utf-8', 'replace')
        try:
            parsed = json.loads(raw)
        except ValueError:
            parsed = {'raw': raw[:160]}
        return response.status, parsed
    except Exception as exc:
        return None, {'error': '%s: %s' % (type(exc).__name__, exc)}
    finally:
        conn.close()


def wait_health(port: int, timeout: float) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        status, _ = request('GET', port, '/api/health', timeout=2.0)
        if status == 200:
            return True
        time.sleep(0.25)
    return False


def start(exe, env, cwd, log_path):
    flags = 0
    if os.name == 'nt':
        flags = getattr(subprocess, 'CREATE_NEW_PROCESS_GROUP', 0)
    return subprocess.Popen([str(exe)], cwd=str(cwd), env=env,
                            stdout=open(str(log_path), 'w', encoding='utf-8'),
                            stderr=subprocess.STDOUT, creationflags=flags)


def signal_gracefully(proc):
    if os.name == 'nt':
        os.kill(proc.pid, getattr(signal, 'CTRL_BREAK_EVENT', signal.SIGTERM))
    else:
        proc.send_signal(signal.SIGTERM)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--exe', default='build/underlayer-h5h6h7.exe')
    ap.add_argument('--port', type=int, default=9038)
    ap.add_argument('--db', default='build/h7-shutdown.db')
    ap.add_argument('--courses', default='courses')
    ap.add_argument('--cwd', default='.')
    ap.add_argument('--log', default='build/h7-shutdown.out.log')
    ap.add_argument('--boot-timeout', type=float, default=90.0)
    args = ap.parse_args()

    db_path = safe_db_path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    for path in [db_path] + [pathlib.Path(str(db_path) + s) for s in ('-wal', '-shm')]:
        if path.exists():
            path.unlink()
    log_path = pathlib.Path(args.log)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    cwd = pathlib.Path(args.cwd).resolve()
    exe = pathlib.Path(args.exe)
    if not exe.is_absolute():
        exe = (cwd / exe).resolve()
    env = os.environ.copy()
    env.update(PORT=str(args.port), DATABASE_URL=str(db_path),
               COURSES_DIR=str((cwd / args.courses).resolve()),
               UL_BUILD_COMMIT='h7-local-probe',
               UL_BUILD_COMPILER_VERSION='Chemical v0.6.0',
               UL_BUILD_MODE='debug',
               UL_BUILD_AT='2026-11-27T00:00:00Z')

    failures = []
    proc = start(exe, env, cwd, log_path)
    try:
        if not wait_health(args.port, args.boot_timeout):
            print('FAIL: server did not become healthy', file=sys.stderr)
            return 1
        email = 'h7-probe-%d@invalid.test' % int(time.time())
        status, reg = request('POST', args.port, '/api/auth/register',
                              {'email': email, 'password': 'ProbePass123!',
                               'name': 'H7 probe'})
        token = reg.get('session_token') if status == 200 else None
        if not token:
            print('FAIL: registration returned %s %s' % (status, str(reg)[:120]),
                  file=sys.stderr)
            return 1
        stamp = int(time.time())
        change = dict(CHANGE, updated_at=stamp)
        status, sync = request('POST', args.port, '/api/progress/sync',
                               {'client_now': stamp, 'changes': [change]}, token=token)
        if status != 200:
            print('FAIL: sync push returned %s %s' % (status, str(sync)[:120]),
                  file=sys.stderr)
            return 1
        print('H7 probe: pre-shutdown register=%s sync=%s' % (status, status))

        # Put work in flight, then signal while it is running.
        outcomes = []

        def in_flight(login_index):
            st, _ = request('POST', args.port, '/api/auth/login',
                            {'email': email, 'password': 'wrong-password'},
                            timeout=8.0)
            outcomes.append(('login%d' % login_index, st))

        threads = [threading.Thread(target=in_flight, args=(i,), daemon=True)
                   for i in range(4)]
        for thread in threads:
            thread.start()
        time.sleep(0.02)
        stamp2 = int(time.time())
        sync_thread = threading.Thread(
            target=lambda: outcomes.append(
                ('sync', request('POST', args.port, '/api/progress/sync',
                                 {'client_now': stamp2,
                                  'changes': [dict(CHANGE, updated_at=stamp2,
                                                   status='in_progress')]},
                                 token=token, timeout=8.0)[0])),
            daemon=True)
        sync_thread.start()
        time.sleep(0.02)
        signal_gracefully(proc)
        for thread in threads:
            thread.join(timeout=6)
        sync_thread.join(timeout=6)
        print('H7 probe: in-flight outcomes %s' % outcomes)
        try:
            exit_code = proc.wait(timeout=35)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=10)
            exit_code = None
            failures.append('server did not exit within 35s of the signal')
        print('H7 probe: exit_code=%s' % exit_code)
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=10)

    log_text = log_path.read_text(encoding='utf-8', errors='replace')
    for needle in ('shutdown signal received', 'shutdown complete'):
        if needle not in log_text:
            failures.append('missing log line: %s' % needle)
    for line in log_text.splitlines():
        if re.search(r'database is locked|SQLITE_BUSY|SQL FAILED|SQL STEP FAILED',
                     line, re.I):
            failures.append('lock/SQL failure in log: %s' % line[:180])
    print('H7 probe: shutdown lines present=%s'
          % ('shutdown complete' in log_text))

    # Restart on the same file: the DB must be clean and the rows still there.
    proc2 = start(exe, env, cwd, pathlib.Path(str(log_path) + '.restart'))
    try:
        if not wait_health(args.port, args.boot_timeout):
            failures.append('restart did not become healthy')
        else:
            st, body = request('POST', args.port, '/api/auth/login',
                               {'email': email, 'password': 'ProbePass123!'})
            print('H7 probe: restart login status=%s' % st)
            if st != 200 or not body.get('session_token'):
                failures.append('restart login failed: %s %s' % (st, str(body)[:100]))
            else:
                st2, pulled = request('GET', args.port, '/api/progress/sync?since=0',
                                      token=body['session_token'])
                rows = pulled.get('changes', []) if isinstance(pulled, dict) else []
                found = any(r.get('course_id') == CHANGE['course_id']
                            and r.get('concept_id') == CHANGE['concept_id']
                            and r.get('unit_id') == CHANGE['unit_id']
                            for r in rows)
                print('H7 probe: restart sync status=%s progress_row_found=%s'
                      % (st2, found))
                if st2 != 200 or not found:
                    failures.append('restart progress row missing: %s %s'
                                    % (st2, str(pulled)[:140]))
    finally:
        if proc2.poll() is None:
            proc2.terminate()
            try:
                proc2.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc2.kill()
                proc2.wait(timeout=10)

    if failures:
        for line in failures:
            print('FAIL: ' + line, file=sys.stderr)
        return 1
    print('H7 probe: PASS (graceful drain, no lock errors, restart data intact)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
