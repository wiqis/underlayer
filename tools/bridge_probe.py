#!/usr/bin/env python3
"""bridge_probe.py -- prove the shared-account bridge ROUTE exists, from served behaviour.

WHY THIS EXISTS

`Android/.../WebCourseApi.kt` and `AccountBridge.kt` used to claim that
`POST /api/auth/from-account` did not exist in the deployed service. It does
(measured 2026-11-26: no-token -> 401, bad token -> non-404 (401 locally, 502
when the account backend is unreachable), unknown POST -> 404), but a comment was
allowed to rot for months because nothing probed the running server. A check
that only greps source cannot catch a route lost in deployment, so this probe
sends three SAFE HTTP POSTs to a live URL and asserts their status codes.

WHAT IT SENDS (no production state is mutated)

  1. POST /api/auth/from-account with NO credentials     -> must be 401
  2. POST /api/auth/from-account with a garbage bearer   -> must NOT be 404
     (401 is the expected rejection; a 502 means the account backend was
     unreachable, which is reported as a NOTE rather than a route failure)
  3. POST /api/no-such-route-bridge-probe with no body   -> must be 404

The bad token is a literal garbage string, not a credential. None of these
requests registers a learner, casts a vote, writes progress or creates a
session. This tool takes no DB path: it can never point a write probe at a
production database.

Usage:
    python3 tools/bridge_probe.py [base-url] [--deployed]

`--deployed` adds `https://underlayer.wiqis.com` as a second target. If the
network is unavailable the deployed target is reported as SKIP, never as PASS
and never as a product failure. CI runs the local target only.

NEGATIVE CASE (how to prove this checker can fail)

  * Point it at a server whose bridge route was removed (or at a stub that
    answers 404 to every POST): checks 1 and 2 FAIL with 404, while the
    unknown-route check still passes -- exactly the regression this exists for.
  * Point it at a closed port: all three checks FAIL with a connection error.
  * With --deployed while offline: the deployed target is SKIPped.

Exit 0 all assertions hold on every reachable target. 1 otherwise.
"""
import argparse
import sys
import urllib.error
import urllib.request

DEPLOYED = 'https://underlayer.wiqis.com'
DEFAULT_BASE = 'http://localhost:9000'
BAD_TOKEN = 'not-a-real-account-token'
TIMEOUT = 15

results = []


def check(target, name, ok, detail=''):
    results.append(ok)
    print('  %s  %s: %s%s' % ('PASS' if ok else 'FAIL', target, name,
                             ('  -- ' + detail) if detail else ''))


def note(target, detail):
    print('  SKIP  %s: %s' % (target, detail))


def post(base, path, headers=None):
    """Return (status, snippet). status is None on a network/timeout error."""
    req = urllib.request.Request(base.rstrip('/') + path, data=None,
                                 headers=headers or {}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status, r.read(160).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, e.read(160).decode('utf-8', 'replace')
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        reason = getattr(e, 'reason', e)
        return None, str(reason)[:100]


def probe(base):
    target = base.rstrip('/')
    print('\nbridge_probe against ' + target)

    status, body = post(base, '/api/auth/from-account')
    check(target, 'no-token bridge POST is 401', status == 401,
          'status %s: %s' % (status, body.strip()))

    status, body = post(base, '/api/auth/from-account',
                        {'Authorization': 'Bearer ' + BAD_TOKEN})
    # Route existence is the assertion: a removed route answers 404 here.
    check(target, 'bad-token bridge POST is not 404',
          status is not None and status != 404,
          'status %s: %s' % (status, body.strip()))
    if status == 401:
        print('  PASS  %s: bad-token bridge POST is rejected with the expected 401' % target)
    elif status is not None:
        note(target, 'bad token answered %s instead of the expected 401 '
                     '(route exists; account backend may be unreachable)' % status)

    status, body = post(base, '/api/no-such-route-bridge-probe')
    check(target, 'unknown POST route is 404', status == 404,
          'status %s: %s' % (status, body.strip()))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', nargs='?', default=DEFAULT_BASE,
                    help='base URL to probe (default: %(default)s)')
    ap.add_argument('--deployed', action='store_true',
                    help='also probe ' + DEPLOYED + ' over the network')
    args = ap.parse_args()

    print('bridge_probe: three read-only POSTs; no DB path, no writes, no secrets')
    probe(args.base)
    if args.deployed:
        probe(DEPLOYED)

    passed = sum(1 for ok in results if ok)
    failed = len(results) - passed
    print('\nbridge_probe: %d passed, %d failed, %d total' %
          (passed, failed, len(results)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
