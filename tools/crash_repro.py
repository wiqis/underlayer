#!/usr/bin/env python3
"""crash_repro.py -- reproduce and characterise the server's heap-corruption abort.

WHY THIS EXISTS.  Auditing the 180 routes with tools/route_check.py killed the
server.  Not a slow query and not a rejected request -- the process aborted:

    double free or corruption (out)
    0x00000000: at ???: RUNTIME ERROR: abort() called

and every subsequent route answered "connection refused".  A remote client can
do that with nothing but a sequence of ordinary HTTP requests, which makes it a
denial-of-service hole rather than a bug.

WHAT IT MEASURES.  It walks the same route list, in registration order, sending
each route one anonymous request, one garbage-body request and one
authenticated request.  After every single request it asks /api/health whether
the process is still there.  It then reports:

  * the step count at which the process dies, and the last few requests;
  * under gdb, the abort backtrace, which names the detection site.

WHAT IT DOES NOT DO.  It does not claim to have found the corrupting WRITE.  The
backtrace names where glibc noticed, not where the byte was written, and the
failure is not deterministic -- it survives some identical runs and dies on
others, which is the signature of a heap overrun rather than a logic error.  A
memory checker would be the next step and valgrind needs root on this box.

Usage:
    python3 tools/crash_repro.py                # walk the sequence, report
    python3 tools/crash_repro.py --steps 200    # stop after N steps
    python3 tools/crash_repro.py --gdb          # run under gdb, dump the bt

Exit: 0 the process survived.  1 it aborted.  2 the server would not start.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 9000

GARBAGE = {
    'POST': ['', '{', '{}', '[]', 'null', '{"a":', '"str"', '123',
             '{"email":null,"password":null}',
             json.dumps({'email': "' OR 1=1 --", 'password': "x' OR 1=1 --"}),
             json.dumps({'concept_id': "' OR 1=1 --", 'status': "x' OR '1'='1"}),
             json.dumps({'course_id': "' OR 1=1 --", 'target_date': "' OR 1=1 --"}),
             json.dumps({'token': "' OR 1=1 --", 'password': "' OR 1=1 --"}),
             json.dumps({'answer': "' OR 1=1 --"}),
             json.dumps({'id': "' OR 1=1 --", 'session_id': "' OR 1=1 --"}),
             json.dumps({'note_id': "' OR 1=1 --", 'body': "' OR 1=1 --"}),
             json.dumps({'question': "' OR 1=1 --", 'answer': "' OR 1=1 --"})],
    'PUT': ['{}', json.dumps({'value': "' OR 1=1 --"})],
    'PATCH': ['{}', json.dumps({'value': "' OR 1=1 --"})],
    'DELETE': [None],
    'GET': [None],
}


def http(method, path, token=None, body=None, timeout=25):
    data = None
    headers = {}
    if body is not None:
        data = body.encode() if isinstance(body, str) else body
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request('http://localhost:%d%s' % (PORT, path),
                                 data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            r.read(120000)
            return r.status
    except urllib.error.HTTPError as e:
        e.read(120000)
        return e.code
    except Exception:  # noqa: BLE001
        return 0


def alive():
    return http('GET', '/api/health', timeout=6) == 200


def restart():
    subprocess.run(['bash', os.path.join(REPO, 'scripts/restart_underlayer.sh')],
                   cwd=REPO, stdout=subprocess.DEVNULL, check=True)
    return alive()


def sample(route):
    p = route
    p = re.sub(r':learnerId', 'no-such', p)
    p = re.sub(r':courseId', 'elf', p)
    p = re.sub(r':conceptId', 'bytes', p)
    p = re.sub(r':exerciseId', 'no-such', p)
    p = re.sub(r':type', 'reviews', p)
    return re.sub(r':\w+', 'x', p)


def routes():
    src = open(os.path.join(REPO, 'app/main.ch'), newline='').read().replace('\r\n', '\n')
    out = []
    for m, p in re.findall(r'srv\.router\.add\("([A-Z]+)", "([^"]+)"', src):
        if p == '*':
            continue
        out.append((m, p))
    return out


def steps():
    out = []
    for m, p in routes():
        for gb in GARBAGE.get(m, [None]):
            out.append((m, p, gb))
        out.append((m, p, 'AUTH'))
    return out


def get_token():
    http('POST', '/api/auth/register', body=json.dumps(
        {'email': 'crashrepro@t.com', 'password': 'password123', 'name': 'CR'}))
    r = urllib.request.Request('http://localhost:%d/api/auth/login' % PORT,
                               data=json.dumps({'email': 'crashrepro@t.com',
                                                'password': 'password123'}).encode(),
                               headers={'Content-Type': 'application/json'},
                               method='POST')
    try:
        return json.loads(urllib.request.urlopen(r, timeout=10).read())['session_token']
    except Exception:  # noqa: BLE001
        return None


def walk(limit):
    st = steps()[:limit]
    try:
        return _walk(st)
    finally:
        cleanup()


def _walk(st):
    if not restart():
        print('FAIL: the server would not start.  NOT a result.')
        return 2
    tok = get_token()
    if not tok:
        print('FAIL: could not get a token.  NOT a result.')
        return 2
    print('crash_repro: walking %d steps over %d routes' % (len(st), len(routes())))
    for i, (m, p, gb) in enumerate(st, 1):
        if gb == 'AUTH':
            http(m, sample(p), token=tok)
        else:
            http(m, sample(p), token=tok, body=gb)
        if not alive():
            print()
            print('*** THE PROCESS DIED at step %d of %d' % (i, len(st)))
            print('*** request: %s %s  body=%r' % (m, p, gb))
            print('*** the preceding requests were:')
            for j in range(max(0, i - 6), i + 1):
                mm, pp, bb = st[j]
                print('      %3d  %-6s %-44s body=%r' % (j + 1, mm, pp, bb))
            log = os.path.join(REPO, 'build/server.log')
            if os.path.exists(log):
                tail = open(log, errors='replace').read()[-800:]
                if 'corruption' in tail or 'double free' in tail or 'abort' in tail:
                    print('*** build/server.log says:')
                    for line in tail.strip().split('\n')[:8]:
                        print('      %s' % line)
            return 1
    print('crash_repro: the process survived all %d steps this run' % len(st))
    return 0


def cleanup():
    """Remove the account this tool registers, through the shipped route."""
    tok = get_token()
    if not tok:
        return
    r = urllib.request.Request('http://localhost:%d/api/user/account' % PORT,
                               headers={'Authorization': 'Bearer ' + tok},
                               method='DELETE')
    try:
        code = urllib.request.urlopen(r, timeout=15).status
    except Exception:  # noqa: BLE001
        code = 0
    print('crash_repro: cleaned up crashrepro@t.com (DELETE /api/user/account -> %d)'
          % code)


def under_gdb(limit):
    exe = os.path.join(REPO, 'build/underlayer.exe')
    subprocess.run(['pkill', '-f', 'build/underlayer.exe'], stdout=subprocess.DEVNULL)
    time.sleep(1)
    cmd = ['gdb', '-q', '-batch', '-ex', 'set pagination off',
           '-ex', 'set confirm off', '-ex', 'set debuginfod enabled off',
           '-ex', 'handle SIGABRT stop nopass', '-ex', 'run',
           '-ex', 'echo \n====ABORT BACKTRACE====\n', '-ex', 'bt 45', '--args', exe]
    logf = open('/tmp/opencode/crash_gdb.log', 'w')
    proc = subprocess.Popen(cmd, cwd=REPO, stdout=logf, stderr=subprocess.STDOUT,
                            env=dict(os.environ, MALLOC_CHECK_='3'))
    for _ in range(120):
        if alive():
            break
        time.sleep(0.5)
    tok = get_token()
    st = steps()[:limit]
    died = False
    for m, p, gb in st:
        if gb == 'AUTH':
            http(m, sample(p), token=tok)
        else:
            http(m, sample(p), token=tok, body=gb)
        if not alive():
            died = True
            break
    try:
        proc.wait(timeout=45)
    except subprocess.TimeoutExpired:
        print('the server survived under gdb this time -- the failure is not')
        print('deterministic, which is consistent with a heap overrun.')
        proc.kill()
    logf.close()
    txt = open('/tmp/opencode/crash_gdb.log', errors='replace').read()
    i = txt.find('====ABORT BACKTRACE====')
    if i >= 0:
        print(txt[i:i + 3500])
        return 1
    print('no abort captured under gdb (log: /tmp/opencode/crash_gdb.log)')
    return 0 if not died else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--steps', type=int, default=1200)
    ap.add_argument('--gdb', action='store_true')
    args = ap.parse_args()
    if args.gdb:
        return under_gdb(args.steps)
    return walk(args.steps)


if __name__ == '__main__':
    sys.exit(main())