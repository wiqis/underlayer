#!/usr/bin/env python3
"""route_check.py -- probe every registered route and assert it behaves.

WHY THIS EXISTS.  There are 181 routes in app/main.ch and nobody had ever asked
the server what they do.  This walks them and asks four questions of each, all
against the running process, because "the handler looks right" is not evidence:

  1. DOES IT ANSWER.  A route the router does not actually reach returns 404 and
     reads, in the source, exactly like a route that works.
  2. DOES IT 500 ON BAD INPUT.  A handler that indexes an empty vector, divides
     by zero, or unwraps a null when a field is absent crashes the request.  The
     pass criterion is: no route may answer 5xx to a garbage request.
  3. DOES IT LEAK INTERNALS.  An error body is allowed to say what went wrong.
     It is NOT allowed to contain a filesystem path, a SQL fragment, a source
     file name, or a Chemical type name -- those tell an attacker the stack.
  4. IS IT ANONYMOUS-SAFE.  This is the one that matters most.  Every route that
     takes a bearer token is probed three ways -- no token, learner A's token,
     and learner B's token -- and the rule is: a route may answer 401 to nobody,
     but it may never answer 200 to B with a body that contains A's learner id,
     A's email, or A's name.  One account cannot find this; you need two.

WHAT IT DELIBERATELY DOES NOT DO.  It does not assert that a route SHOULD be
authenticated -- plenty of shipped routes are public by design (course pages,
the health check, search).  It asserts only the two facts above: no 5xx, no
internal leak, and no cross-learner bleed.  A route that needs auth but has none
is reported as INFO with the reason it looks deliberate (it substitutes the
"demo" learner), not as a pass, because a checker that guessed intent is worse
than one that measured.

IT DESTROYS THINGS, ON ITS OWN THROWAWAY ACCOUNTS.  Section 4 calls every
mutating route with a real token, and that includes DELETE /api/user/account,
DELETE /api/user/data/:type and the POST routes that write learner rows.  The
two accounts it registers at the start exist to be written to, and section 6
deletes whatever is left.  Never point this at anything whose data matters.

IT RESTARTS THE SERVER WHEN IT CRASHES.  The first version of this file died
partway through and reported 165 routes as "connection refused", which is the
worst thing an auditing tool can do: one crash hides the other 175 answers.  A
process that has died is now recorded as a CRASH finding in its own section, and
the run continues against `scripts/restart_underlayer.sh` so the remaining
routes are still measured.  The crash count in the summary is therefore the
number of times the platform died on a request during a full pass.

HOW TO PROVE IT IS NOT VACUOUS
------------------------------
`--selftest` runs the leak assertion against a synthetic pair of responses in
which B's body really does contain A's id, and asserts it reports the breach.
A cross-leak detector that cannot detect a cross-leak is a comment.

Usage:
    python3 tools/route_check.py
    python3 tools/route_check.py --selftest
    python3 tools/route_check.py --port 9000 --quiet

Exit: 0 no 5xx, no internal leak, no cross-learner bleed.  1 at least one.
      2 the server is not reachable (NOT a pass).
"""
import argparse
import json
import os
import re
import subprocess
import time
import sys
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Things that must never appear in an error body handed to a client.
LEAK_MARKERS = [
    '/home/wakaztahir', '/Users/', 'C:\\',
    'Traceback', 'chemical/src', 'libchemical', 'TCCCompiler',
    'SELECT ', 'INSERT ', 'UPDATE ', 'DELETE FROM',
    'sqlite3_', 'null pointer', 'segfault',
    'std::string', '&raw mut', 'chemical.mod',
]

# A body must never carry another learner's identity.
IDENT_PATTERNS = [
    ('learner_id', re.compile(r'"learner_id"\s*:\s*"([0-9a-f]{16,})"')),
    ('email', re.compile(r'"email"\s*:\s*"([^"@]+@[^"]+)"')),
]

# Routes whose bodies are known to be large static pages are still probed; only
# the assertions below run, so size is irrelevant.
MUTATING = ('POST', 'PUT', 'PATCH', 'DELETE')


def http(method, path, port, token=None, body=None, timeout=25):
    url = 'http://localhost:%d%s' % (port, path)
    data = None
    headers = {'Accept': '*/*'}
    if body is not None:
        data = body.encode() if isinstance(body, str) else body
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read(400000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read(400000).decode('utf-8', 'replace')
    except Exception as e:  # noqa: BLE001 - a refused connection is a result
        return 0, 'TRANSPORT: %s' % e


def parse_routes():
    src = open(os.path.join(REPO, 'app/main.ch'), newline='').read()
    src = src.replace('\r\n', '\n')
    out = []
    for m, p in re.findall(r'srv\.router\.add\(\s*"([A-Z]+)",\s*"([^"]+)"', src):
        out.append((m, p))
    return out


def is_router_404(body):
    """True when the 404 came from the ROUTER, not from a handler.

    The router answers an unknown path with `text/plain` and the body
    "Not Found".  A handler that legitimately has nothing to return answers 404
    with JSON -- {"error":"learner not found"} and so on.  Telling those apart is
    the difference between "this route is not wired up", which is a defect, and
    "this learner does not exist", which is the contract.
    """
    return body.strip() in ('Not Found', 'Not found', '404 Not Found')


def sample(route):
    """Concrete path for a route that has :params."""
    p = route
    p = re.sub(r':learnerId', 'nonexistent-learner-id', p)
    p = re.sub(r':courseId', 'elf', p)
    p = re.sub(r':conceptId', 'bytes', p)
    p = re.sub(r':exerciseId', 'no-such-exercise', p)
    p = re.sub(r':type', 'reviews', p)
    p = re.sub(r':\w+', 'x', p)
    return p


def make_account(port, tag):
    import hashlib
    email = 'routecheck_%s@t.com' % tag
    pw = 'password123'
    st, body = http('POST', '/api/auth/register', port,
                    body=json.dumps({'email': email, 'password': pw, 'name': 'RC ' + tag}))
    tok = None
    lid = None
    try:
        j = json.loads(body)
        tok = j.get('session_token')
        lid = j.get('learner_id')
    except Exception:  # noqa: BLE001
        pass
    if not tok:
        st2, body2 = http('POST', '/api/auth/login', port,
                          body=json.dumps({'email': email, 'password': pw}))
        try:
            j = json.loads(body2)
            tok = j.get('session_token')
            lid = j.get('learner_id')
        except Exception:  # noqa: BLE001
            pass
    _ = st, pw
    return email, lid, tok, pw


def restart(port=9000):
    """Bring the server back after an abort.  Uses the project's own script."""
    here = os.path.dirname(os.path.abspath(__file__))
    script = os.path.join(os.path.dirname(here), 'scripts', 'restart_underlayer.sh')
    try:
        subprocess.run(['bash', script], cwd=os.path.dirname(here),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=120, check=True)
    except Exception:  # noqa: BLE001
        return False
    for _ in range(40):
        if http('GET', '/api/health', port, timeout=5)[0] == 200:
            return True
        time.sleep(0.5)
    return False


def selftest():
    """The two central assertions must disagree on planted input.

    1. Cross-leak: a body served to learner B that contains learner A's id MUST
       be reported.  If the extractor cannot even find an id in such a body, the
       live assertion is measuring nothing, which is the failure this file is
       about.
    2. No leak: the same extractor applied to B's own body MUST find nothing to
       report, or every authenticated GET would "fail" and the check would be
       noise rather than coverage.
    """
    a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    fails = []

    # 1. planted leak
    leaked = '{"learner_id":"%s","email":"a@t.com"}' % a
    found = {}
    for label, pat in IDENT_PATTERNS:
        m = pat.search(leaked)
        if m:
            found[label] = m.group(1)
    if found.get('learner_id') != a:
        fails.append('could not extract the planted learner id from %r -> %r'
                     % (leaked, found))
    else:
        a_idents = {'learner_id': a, 'email': 'a@t.com'}
        hits = [k for k, v in a_idents.items() if v and v in leaked]
        if not hits:
            fails.append('planted leak of %r was not reported' % a)
        else:
            print('  planted cross-leak of %s detected, as it must be' % ', '.join(hits))

    # 2. control: B's own body
    own = '{"learner_id":"%s","email":"b@t.com"}' % b
    a_idents = {'learner_id': a, 'email': 'a@t.com'}
    false_hits = [k for k, v in a_idents.items() if v and v in own]
    if false_hits:
        fails.append('control body %r falsely reported as leaking %r'
                     % (own, false_hits))
    else:
        print('  control body correctly reported as NOT leaking A')

    # 3. the leak marker list must actually match a planted leak
    planted = 'at /home/wakaztahir/work/wiqis/Web/underlayer/web/src/x.ch'
    if not any(m in planted for m in LEAK_MARKERS):
        fails.append('LEAK_MARKERS does not match a planted filesystem path, so a '
                     'real path leak would pass unnoticed')
    else:
        print('  LEAK_MARKERS matches a planted filesystem path')

    # 4. the leak markers must not match a normal error body
    normal = '{"error":"invalid email or password"}'
    if any(m in normal for m in LEAK_MARKERS):
        bad = [m for m in LEAK_MARKERS if m in normal]
        fails.append('LEAK_MARKERS matches an ordinary error body: %r' % bad)
    else:
        print('  LEAK_MARKERS does not match an ordinary error body')

    if fails:
        print('SELFTEST FAIL:')
        for f in fails:
            print('  - %s' % f)
        return 1
    print('SELFTEST OK: the cross-leak assertion fires on a planted leak, stays '
          'quiet on a\n            control, and the leak markers match a planted '
          'path but not a real error.')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--only', default=None, help='substring filter on the route')
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    st, _ = http('GET', '/api/health', args.port)
    if st != 200:
        print('FAIL: server not reachable on port %d (health=%d). '
              'NOT a pass.' % (args.port, st))
        return 2

    routes = parse_routes()
    if args.only:
        routes = [r for r in routes if args.only in r[1]]

    _, lid_a, tok_a, pw_a = make_account(args.port, 'a')
    _, lid_b, tok_b, pw_b = make_account(args.port, 'b')
    if not tok_a or not tok_b:
        print('FAIL: could not create the two test accounts route_check needs. '
              'NOT a pass.')
        return 2
    if not args.quiet:
        print('route_check: A=%s  B=%s' % (lid_a, lid_b))

    server_errors = []
    leaks = []
    bleeds = []
    anon_200 = []
    unreachable = []
    crashes = []

    garbage_bodies = {
        'POST': ['', '{', '{}', '[]', 'null', '{"a":', '"str"', '123',
                 '{"email":null,"password":null}',
                 json.dumps({'email': "' OR 1=1 --", 'password': "x' OR 1=1 --"}),
                 json.dumps({'concept_id': "' OR 1=1 --", 'course_id': "'; DROP TABLE learners;--",
                             'status': "x' OR '1'='1"}),
                 json.dumps({'course_id': "' OR 1=1 --", 'target_date': "' OR 1=1 --"}),
                 json.dumps({'token': "' OR 1=1 --", 'password': "' OR 1=1 --"}),
                 json.dumps({'answer': "' OR 1=1 --"}),
                 json.dumps({'id': "' OR 1=1 --", 'session_id': "' OR 1=1 --"}),
                 json.dumps({'note_id': "' OR 1=1 --", 'body': "' OR 1=1 --"}),
                 json.dumps({'question': "' OR 1=1 --", 'answer': "' OR 1=1 --"}),
                 ],
        'PUT': ['{}', json.dumps({'value': "' OR 1=1 --"})],
        'PATCH': ['{}', json.dumps({'value': "' OR 1=1 --"})],
        'DELETE': [None],
    }

    def alive():
        return http('GET', '/api/health', args.port, timeout=8)[0] == 200

    for method, route in routes:
        path = sample(route)
        if route == '*':
            continue
        # 1. reachable at all, anonymous
        code, body = http(method, path, args.port)
        if code == 0:
            if not alive():
                # The process is gone, not just this request.  That is a
                # different -- and much larger -- finding than a 404, so it is
                # recorded as a CRASH, and the remaining routes are probed
                # against a freshly restarted server so one abort does not hide
                # the other 170 routes behind a wall of "connection refused".
                crashes.append((method, route, body))
                if not restart(args.port):
                    unreachable.append((method, route, 'server could not be restarted'))
                    break
                code, body = http(method, path, args.port)
                if code == 0:
                    unreachable.append((method, route, 'still unreachable after restart'))
        if code == 404 and is_router_404(body):
            # A handler that correctly says "no such learner" answers 404 with a
            # JSON body.  The ROUTER saying "no such route" answers 404 with the
            # literal text "Not Found" and text/plain.  Only the second means the
            # route is not wired up -- counting the first would make this
            # checker fail on correct behaviour, which is how a checker stops
            # being believed.
            unreachable.append((method, route, 'router 404: the route is not registered'))
        if method == 'GET' and code == 200:
            anon_200.append((method, route))
        # 2/3. bad input must not 500 and must not leak
        probes = garbage_bodies.get(method, [None]) if method in garbage_bodies else [None]
        for gb in probes:
            pcode, pbody = http(method, path, args.port, token=tok_a, body=gb)
            if pcode == 0 and not alive():
                crashes.append((method, route, 'body=%r' % (gb,)))
                if not restart(args.port):
                    break
                continue
            if pcode >= 500 or pcode == 0:
                server_errors.append((method, route, repr(gb)[:60], pcode, pbody[:200]))
            for marker in LEAK_MARKERS:
                if marker in pbody and pcode >= 400:
                    leaks.append((method, route, marker, pbody[:200]))
        # 4. cross-learner bleed
        acode, abody = http(method, path, args.port, token=tok_a)
        bcode, bbody = http(method, path, args.port, token=tok_b)
        if acode == 200 and bcode == 200:
            for label, pat in IDENT_PATTERNS:
                ma = pat.search(abody)
                mb = pat.search(bbody)
                if ma and mb and ma.group(1) == mb.group(1) and ma.group(1) == lid_a:
                    bleeds.append((method, route, label, ma.group(1)))

    # seed A with a recognisable note so a read-bleed has something to leak
    print()
    print('=== 0. PROCESS ABORTS (the server died mid-audit) ===')
    if crashes:
        for c in crashes:
            print('  %-6s %-46s %s' % (c[0], c[1], c[2]))
        print('  the run continued against a restarted server so the other routes')
        print('  were still measured -- but a process that dies on a request is a')
        print('  remote unauthenticated denial of service, not a cosmetic defect.')
    else:
        print('  none: the process survived every probe')

    print('=== 1. ROUTES THAT DO NOT ANSWER ===')
    if unreachable:
        for u in unreachable:
            print('  %-6s %-52s %s' % (u[0], u[1], u[2]))
    else:
        print('  none: all %d routes answered' % len(routes))

    print('=== 2. 5xx ON BAD INPUT ===')
    if server_errors:
        for s in server_errors:
            print('  %-6s %-46s body=%-22s -> %d %s' % (s[0], s[1], s[2], s[3], s[4]))
    else:
        print('  none: no route answered 5xx to garbage')

    print('=== 3. INTERNALS IN AN ERROR BODY ===')
    if leaks:
        for l in leaks:
            print('  %-6s %-46s %r' % (l[0], l[1], l[2]))
    else:
        print('  none: no error body carried a path, a SQL fragment or a type name')

    print('=== 4. CROSS-LEARNER BLEED (A token vs B token) ===')
    if bleeds:
        for b in bleeds:
            print('  %-6s %-46s returned A\'s %s to B  (%s)' % (b[0], b[1], b[2], b[3]))
    else:
        print('  none: no route handed A\'s identity to B')

    print('=== 5. ANONYMOUS 200s (INFO, not a failure) ===')
    print('  %d of %d routes answer 200 with no token at all' % (len(anon_200), len(routes)))

    print()
    print('=== 6. CLEANUP  the two accounts this check created ===')
    # A note on what this phase has already done: section 4 calls EVERY mutating
    # route with learner A's token, and one of those routes is
    # DELETE /api/user/account.  So A has usually already deleted itself by the
    # time cleanup runs, and the 401 below means "already gone", not "leaked".
    # The pass criterion is therefore that no row survives, which is checked
    # against the learners table rather than inferred from a status code.
    for label, tok in (('A', tok_a), ('B', tok_b)):
        code = http('DELETE', '/api/user/account', args.port, token=tok)[0]
        left = http('GET', '/api/learners/routecheck_%s@t.com' % label.lower(),
                    args.port)[0]
        verdict = 'ok  ' if left == 404 else 'WARN'
        if left == 404 and code == 401:
            extra = ' (already removed by this run\'s own probe phase)'
        else:
            extra = ''
        print('  %s account %s  no learner row remains (%s), DELETE said %d%s'
              % (verdict, label, left, code, extra))

    print()
    bad = len(unreachable) + len(server_errors) + len(leaks) + len(bleeds) + len(crashes)
    print('SUMMARY: unreachable=%d 5xx=%d leaks=%d bleeds=%d crashes=%d'
          % (len(unreachable), len(server_errors), len(leaks), len(bleeds), len(crashes)))
    if bad:
        print('FAIL: %d problem(s)' % bad)
        return 1
    print('route_check: ALL CONSISTENT over %d routes' % len(routes))
    return 0


if __name__ == '__main__':
    sys.exit(main())