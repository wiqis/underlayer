#!/usr/bin/env python3
"""rate_limit_deployed_probe.py -- H2 two-network probe + B7 empty-bucket probe.

H2 -- DEPLOYED, TWO CLIENT NETWORKS (founder action, NOT run by an agent).
Behind Google Frontend every request arrives from the proxy's socket peer.
`web/src/rate_limit.ch` therefore keys anonymous auth buckets by that peer:
caller-controlled X-Forwarded-For is NEVER read. The consequence is that all
anonymous callers may share one 8/5-minute bucket. To measure what the
deployed peer actually resolves to, the founder must run this tool from TWO
distinct client networks (office wifi and a mobile hotspot, NOT two browser
tabs on one machine):

  A: 8 wrong logins  -> 401 x8 then 429 at attempt 9
  B: from the other network, 8 wrong logins -> 401 x8 (NOT 429), then a
     correct login -> 200

If B is also throttled after A, the limiter is keyed on the shared frontend
peer (the expected finding): the fix is an edge limiter (Cloud Armor) or a
trusted proxy hop that OVERWRITES a client-ip header, both founder actions.
Record both network labels, the observed statuses, and the peer values from
Cloud Logging's `remote=` field in docs/deployment.md §5.

This machine cannot produce two networks, so the deployed mode is opt-in via
`--founder-approved` and requires explicit base URLs and network labels. It
was NOT run for this work package; no deployed pass is claimed anywhere.

B7 -- LOCAL EMPTY-BUCKET PROBE (safe on a disposable DB).
`--local` clears the counter table only when given `--reset-db PATH` pointing
at a *disposable* SQLite file (the name must contain verify-/ci-/test-/
disposable/scratch and live in this repo). It then fires nine wrong logins
from localhost and asserts: 401 x8, then 429 on the ninth, with a numeric
Retry-After header in the live 300-second window. The historical deployed
observation was `Retry-After: 120`; the value is a window-position number,
not a constant, so the assertion is on range and presence, and the observed
value is printed for the record.

Usage:
    python3 tools/rate_limit_deployed_probe.py --local --port 9014 \
        --reset-db build/verify-9014.db
    python3 tools/rate_limit_deployed_probe.py --deployed \
        --base-a https://underlayer.wiqis.com --network-a-label office-wifi \
        --base-b https://underlayer.wiqis.com --network-b-label mobile-hotspot \
        --founder-approved

Exit: 0 all assertions held; 1 a probe failed; 2 bad usage / refused / unreachable.
"""
import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request

TIMEOUT = 20
DISPOSABLE = ('verify-', 'ci-', 'test', 'disposable', 'scratch')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def http(base, method, path, body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {'Content-Type': 'application/json', 'User-Agent': 'ul-rate-probe/1'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(base.rstrip('/') + path, data=data,
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status, dict(r.headers.items()), r.read(100000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers.items()), e.read(100000).decode('utf-8', 'replace')
    except Exception as exc:  # noqa: BLE001
        return 0, {}, 'TRANSPORT: %s' % exc


def disposable_db(path):
    """Never let a typo turn a 'reset the counters' probe into a production delete."""
    full = os.path.abspath(os.path.join(ROOT, path))
    if os.path.commonpath((full, ROOT)) != ROOT:
        return False, 'outside this repository'
    name = os.path.basename(full).lower()
    if not any(tag in name for tag in DISPOSABLE):
        return False, 'filename has no disposable marker (%s)' % ', '.join(DISPOSABLE)
    if not (name.startswith('verify-') or 'ci-' in name or 'test' in name or
            name.startswith('scratch')):
        return False, 'filename is not in the recognised disposable set'
    return True, full


def clear_counters(path):
    ok, info = disposable_db(path)
    if not ok:
        print('REFUSED to clear %s: %s' % (path, info))
        return False
    con = sqlite3.connect(info, timeout=10)
    try:
        con.execute('DELETE FROM rate_limits')
        con.commit()
    finally:
        con.close()
    print('cleared rate_limits in disposable DB %s' % info)
    return True


def wrong_logins(base, count, tag):
    codes = []
    retry = None
    for i in range(count):
        st, hdrs, body = http(base, 'POST', '/api/auth/login',
                              {'email': 'no-such-%s-%d@t.com' % (tag, i),
                               'password': 'definitely-wrong'})
        codes.append(st)
        if st == 429:
            value = hdrs.get('Retry-After') or hdrs.get('retry-after')
            if value is not None and retry is None:
                retry = value
            if 'too many attempts' not in body:
                print('WARN %s: 429 body did not say "too many attempts": %s'
                      % (tag, body[:120]))
            break
    return codes, retry


def local_probe(port, reset_db):
    base = 'http://localhost:%d' % port
    if http(base, 'GET', '/api/health')[0] != 200:
        print('local_probe: no server on %s -- NOT a pass' % base)
        return 2
    if reset_db and not clear_counters(reset_db):
        return 2
    codes, retry = wrong_logins(base, 9, 'local')
    print('local empty-bucket statuses: %s' % codes)
    ok = len(codes) == 9 and codes[:8] == [401] * 8 and codes[8] == 429
    print('  401 x8 then 429 on attempt 9: %s' % ('PASS' if ok else 'FAIL'))
    if retry is None:
        print('  Retry-After header: MISSING -- FAIL')
        ok = False
    else:
        try:
            seconds = int(retry)
            in_window = 1 <= seconds <= 300
            print('  Retry-After: %s seconds (within 1..300: %s; deployed '
                  'historical observation was 120)' % (retry, in_window))
            ok = ok and in_window
        except ValueError:
            print('  Retry-After: non-numeric %r -- FAIL' % retry)
            ok = False
    print('local empty-bucket probe: %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


def deployed_probe(base_a, label_a, base_b, label_b):
    print('=' * 72)
    print('DEPLOYED TWO-NETWORK PROBE -- founder action, run from two machines/networks')
    print('  A = %s (%s)' % (label_a, base_a))
    print('  B = %s (%s)' % (label_b, base_b))
    print('This script will send 8 WRONG logins from each configured base. On a')
    print('shared-frontend bucket this can throttle other anonymous callers for')
    print('up to five minutes. Do not run it during learner traffic.')
    print('=' * 72)
    st, _, _ = http(base_a, 'GET', '/api/health')
    if st != 200:
        print('A is not reachable (%d) -- NOT a pass' % st)
        return 2
    codes_a, retry_a = wrong_logins(base_a, 9, 'netA')
    codes_b, _ = wrong_logins(base_b, 8, 'netB')
    print('%s (%s): %s, Retry-After=%s' % (label_a, base_a, codes_a, retry_a))
    print('%s (%s): %s' % (label_b, base_b, codes_b))
    ok = (codes_a[:8] == [401] * 8 and len(codes_a) == 9 and codes_a[8] == 429 and
          codes_b == [401] * 8)
    if not ok:
        print('RESULT: the two networks share a bucket (limiter keyed on the '
              'frontend peer). This is a FINDING, not a script error.')
        print('Founder action: enable an edge limiter (Cloud Armor) or a trusted '
              'proxy hop that overwrites a client-ip header; never trust a '
              'caller-supplied X-Forwarded-For.')
        return 1
    print('RESULT: independent buckets observed from the two networks.')
    print('Record the date, both network labels, and the `remote=` values from')
    print('Cloud Logging in docs/deployment.md §5 before claiming H2 deployed.')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--local', action='store_true')
    ap.add_argument('--port', type=int, default=9014)
    ap.add_argument('--reset-db', default=None)
    ap.add_argument('--deployed', action='store_true')
    ap.add_argument('--base-a')
    ap.add_argument('--network-a-label')
    ap.add_argument('--base-b')
    ap.add_argument('--network-b-label')
    ap.add_argument('--founder-approved', action='store_true')
    args = ap.parse_args()
    if args.local == args.deployed:
        ap.error('choose exactly one of --local or --deployed')
    if args.local:
        return local_probe(args.port, args.reset_db)
    if not args.founder_approved:
        print('Deployed two-network probe NOT RUN. This machine cannot produce two')
        print('client networks and an agent may not throttle the deployed service.')
        print('Founder: run from two distinct networks with --founder-approved,')
        print('capture the outputs and link them from docs/deployment.md §5.')
        return 2
    missing = [n for n in ('base_a', 'network_a_label', 'base_b', 'network_b_label')
               if not getattr(args, n)]
    if missing:
        ap.error('deployed mode needs --base-a, --network-a-label, --base-b, --network-b-label')
    return deployed_probe(args.base_a, args.network_a_label,
                          args.base_b, args.network_b_label)


if __name__ == '__main__':
    sys.exit(main())
