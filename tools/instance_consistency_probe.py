#!/usr/bin/env python3
"""instance_consistency_probe.py -- H1 two-client single-instance consistency.

A single SQLite file behind one process is the accepted ceiling (B3). Two Cloud
Run instances would each have their own file and silently diverge. This probe
makes that failure visible: two independent session tokens for the SAME learner
read GET /api/auth/me and GET /api/progress N times (default 10) through the
supplied base URL. Every response must be byte-equivalent after JSON
normalisation, across both tokens and across all rounds.

Supply two tokens with --token-a/--token-b (preferred: no writes at all), or
pass --disposable on a NON-production base to create ONE throwaway learner and
log in twice. No progress writes, no other endpoints touched, no secrets in the
output (tokens are never printed, only a short fingerprint).

A *.wiqis.com base is treated as production and REFUSED unless
--founder-approved is given. This tool was NOT run against the deployed
service by the agent that wrote it.

Usage:
    python tools/instance_consistency_probe.py http://127.0.0.1:9032 \
        --token-a TOKEN --token-b TOKEN
    python tools/instance_consistency_probe.py http://127.0.0.1:9032 --disposable
    python tools/instance_consistency_probe.py --selftest
"""
import argparse
import hashlib
import json
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

PROD_HOST = re.compile(r'(^|\.)(wiqis\.com)$', re.I)


def call(base, method, path, token=None, body=None, timeout=10.0):
    url = base.rstrip('/') + path
    data = None
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read(65536).decode('utf-8', 'replace')
    try:
        return json.loads(raw)
    except ValueError:
        return {'raw': raw}


def fingerprint(token):
    return hashlib.sha256(token.encode('utf-8')).hexdigest()[:8]


def is_production(base, forced):
    host = urllib.parse.urlparse(base).hostname or ''
    return forced or bool(PROD_HOST.search(host))


def obtain_tokens(base, args):
    if args.token_a and args.token_b:
        if args.token_a == args.token_b:
            raise AssertionError('two DISTINCT session tokens are required')
        if args.disposable:
            raise AssertionError('--disposable is unnecessary when tokens are supplied')
        return args.token_a, args.token_b, 0
    if not args.disposable:
        raise AssertionError('supply --token-a/--token-b or --disposable')
    if is_production(base, args.production):
        raise AssertionError('--disposable is refused on a production base')
    email = 'h1-probe-%d@invalid.test' % time.time_ns()
    call(base, 'POST', '/api/auth/register', body={
        'email': email, 'password': 'ProbePass123!', 'name': 'H1 Probe'},
        timeout=args.timeout)
    a = call(base, 'POST', '/api/auth/login', body={
        'email': email, 'password': 'ProbePass123!'}, timeout=args.timeout)
    b = call(base, 'POST', '/api/auth/login', body={
        'email': email, 'password': 'ProbePass123!'}, timeout=args.timeout)
    ta, tb = a.get('session_token'), b.get('session_token')
    if not ta or not tb or ta == tb:
        raise AssertionError('two distinct session tokens were not returned')
    return ta, tb, 1


def canonical(payload):
    return json.dumps(payload, sort_keys=True, separators=(',', ':'))


def probe(base, ta, tb, rounds, timeout):
    failures = []
    baseline = {}
    for round_no in range(1, rounds + 1):
        for label, token in (('A', ta), ('B', tb)):
            for endpoint in ('/api/auth/me', '/api/progress'):
                key = (label, endpoint)
                try:
                    payload = call(base, 'GET', endpoint, token=token, timeout=timeout)
                except Exception as exc:
                    failures.append('round %d client %s %s: %s: %s'
                                    % (round_no, label, endpoint,
                                       type(exc).__name__, exc))
                    continue
                value = canonical(payload)
                if key not in baseline:
                    baseline[key] = value
                elif baseline[key] != value:
                    failures.append('round %d client %s %s changed from round 1'
                                    % (round_no, label, endpoint))
                other = ('B' if label == 'A' else 'A', endpoint)
                if other in baseline and baseline[other] != value:
                    failures.append('round %d %s differs between clients A and B'
                                    % (round_no, endpoint))
    return failures


class _Stub(BaseHTTPRequestHandler):
    drift_at = None
    round = 0

    def do_GET(self):
        _Stub.round += 1
        payload = {'learner_id': 'h1-stub', 'version': 1}
        if self.headers.get('Authorization', '').endswith(_Stub.b_token):
            if _Stub.drift_at and _Stub.round >= _Stub.drift_at:
                payload = {'learner_id': 'stale-instance', 'version': 1}
        body = json.dumps(payload).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


def selftest():
    """A stub that diverges on B at round 5 must be caught; a stable one passes."""
    _Stub.b_token = 'b-token'
    server = HTTPServer(('127.0.0.1', 0), _Stub)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = 'http://127.0.0.1:%d' % server.server_port
    try:
        _Stub.drift_at = None
        _Stub.round = 0
        stable = probe(base, 'a-token', 'b-token', 10, 5.0)
        _Stub.drift_at = 5
        _Stub.round = 0
        drifting = probe(base, 'a-token', 'b-token', 10, 5.0)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    if stable:
        print('FAIL: stable stub reported %d finding(s)' % len(stable), file=sys.stderr)
        return 1
    if not any('differs between clients' in f for f in drifting):
        print('FAIL: drifting stub was not detected', file=sys.stderr)
        return 1
    print('PASS: stable stub passes; drift at round 5 is caught (10 rounds)')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', nargs='?', help='supplied base URL of the service')
    ap.add_argument('--token-a', help='session token for client A (never printed)')
    ap.add_argument('--token-b', help='session token for client B (never printed)')
    ap.add_argument('--disposable', action='store_true',
                    help='on a non-production base, create one throwaway learner + two logins')
    ap.add_argument('--rounds', type=int, default=10)
    ap.add_argument('--timeout', type=float, default=10.0)
    ap.add_argument('--production', action='store_true',
                    help='force production classification (refusal still applies)')
    ap.add_argument('--founder-approved', action='store_true',
                    help='required to run this probe against a production base')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not args.base:
        ap.error('a base URL is required unless --selftest is given')
    if args.rounds < 1:
        ap.error('--rounds must be >= 1')
    if is_production(args.base, args.production) and not args.founder_approved:
        print('FAIL: production base refused without --founder-approved. '
              'This probe creates sessions and must not touch the deployed service '
              'by default.', file=sys.stderr)
        return 2
    try:
        ta, tb, registrations = obtain_tokens(args.base, args)
    except AssertionError as exc:
        print('FAIL: %s' % exc, file=sys.stderr)
        return 2
    except Exception as exc:
        print('FAIL: cannot prepare sessions: %s: %s' % (type(exc).__name__, exc),
              file=sys.stderr)
        return 1
    print('instance_consistency_probe: target %s, registrations=%d, '
          'token A fingerprint=%s token B fingerprint=%s'
          % (args.base.rstrip('/'), registrations, fingerprint(ta), fingerprint(tb)))
    failures = probe(args.base, ta, tb, args.rounds, args.timeout)
    for line in failures:
        print('FAIL: ' + line, file=sys.stderr)
    if failures:
        return 1
    print('PASS: %d rounds x 2 clients x (/api/auth/me, /api/progress) identical' % args.rounds)
    return 0


if __name__ == '__main__':
    sys.exit(main())
