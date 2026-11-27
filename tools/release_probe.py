#!/usr/bin/env python3
"""release_probe.py -- prove a deployed /api/health carries release provenance.

Reads the expected source digest and compiler pin from docs/deployment.md
(overridable with --expect-commit / --expect-compiler), fetches /api/health with
an explicit timeout, and fails when:

  * status/version are not the unchanged client contract ("ok" / "0.1.0");
  * any of commit / compiler_version / build_mode / built_at is missing;
  * build_mode != "release";
  * commit != the digest recorded in the doc;
  * compiler_version != the pin recorded in the doc.

No secrets are read, printed or sent. This is a READ-ONLY GET: it never touches
a database or a write endpoint.

Usage:
    python tools/release_probe.py https://underlayer.wiqis.com
    python tools/release_probe.py http://127.0.0.1:9033 --selftest
Exit 0 only when every assertion passes (or when --selftest's own negative
cases all fail as expected).
"""
import argparse
import json
import re
import sys
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

FIELDS = ('commit', 'compiler_version', 'build_mode', 'built_at')


def fetch_health(base_url: str, timeout: float) -> dict:
    url = base_url.rstrip('/') + '/api/health'
    req = urllib.request.Request(url, headers={'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        raw = response.read(65536).decode('utf-8', 'replace')
    return json.loads(raw)


def read_baseline(doc_path: str):
    with open(doc_path, 'r', encoding='utf-8') as handle:
        text = handle.read()
    digest = re.search(r'^- Build digest:\s*([0-9a-fA-F]{7,40})\s*$', text, re.M)
    pin = re.search(r'^- Compiler pin:\s*(.+?)\s*$', text, re.M)
    return (digest.group(1) if digest else None,
            pin.group(1) if pin else None)


def check(payload, expected_commit=None, expected_pin=None):
    """Return a list of failure strings. Empty list means pass."""
    failures = []
    if not isinstance(payload, dict):
        return ['health payload is not a JSON object']

    # The two old fields are a client contract. Do not let a provenance change
    # quietly alter what existing readers parse.
    if payload.get('status') != 'ok':
        failures.append('status != "ok": %r' % payload.get('status'))
    if payload.get('version') != '0.1.0':
        failures.append('version != "0.1.0": %r' % payload.get('version'))

    for name in FIELDS:
        value = payload.get(name)
        if not isinstance(value, str) or not value.strip():
            failures.append('missing or empty provenance field: %s' % name)

    mode = payload.get('build_mode')
    if mode != 'release':
        failures.append('build_mode != "release": %r' % mode)
    if expected_commit is not None and payload.get('commit') != expected_commit:
        failures.append('commit does not match the doc digest: %r != %r'
                        % (payload.get('commit'), expected_commit))
    if expected_pin is not None and payload.get('compiler_version') != expected_pin:
        failures.append('compiler_version does not match the pin: %r != %r'
                        % (payload.get('compiler_version'), expected_pin))
    return failures


class _StubHandler(BaseHTTPRequestHandler):
    payload = {}

    def do_GET(self):
        body = json.dumps(self.payload).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


def selftest() -> int:
    """Spin a local stub and prove both the positive and negative cases."""
    good = {'status': 'ok', 'version': '0.1.0', 'commit': 'abcdef1234567',
            'compiler_version': 'Chemical v0.6.0', 'build_mode': 'release',
            'built_at': '2026-11-27T00:00:00Z'}
    cases = [
        ('positive: exact release payload', dict(good), [], True),
        ('negative: build_mode=debug', dict(good, build_mode='debug'), ['build_mode'], False),
        ('negative: compiler differs from pin',
         dict(good, compiler_version='Chemical v9.9.9'), ['compiler_version'], False),
        ('negative: missing built_at',
         {k: v for k, v in good.items() if k != 'built_at'}, ['built_at'], False),
        ('negative: changed client contract',
         dict(good, version='9.9.9'), ['version'], False),
    ]
    failures = []
    server = HTTPServer(('127.0.0.1', 0), _StubHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = 'http://127.0.0.1:%d' % server.server_port
        for label, payload, needles, should_pass in cases:
            _StubHandler.payload = payload
            got = fetch_health(base, 5.0)
            failures_found = check(got, good['commit'], good['compiler_version'])
            passed = not failures_found
            ok = passed == should_pass
            if should_pass and not ok:
                failures.append('%s: unexpected failures %s' % (label, failures_found))
            if not should_pass and not ok:
                failures.append('%s: probe did not fail' % label)
            if not any(n in ' '.join(failures_found) for n in needles) and not should_pass:
                failures.append('%s: failure did not name %s' % (label, needles))
            print('%s: %s (%s)' % ('PASS' if ok else 'FAIL', label,
                                   '; '.join(failures_found) or 'no failures'))
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    if failures:
        for line in failures:
            print('FAIL: ' + line, file=sys.stderr)
        return 1
    print('PASS: release_probe selftest (1 positive, 4 negative cases)')
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('url', nargs='?', help='base URL, e.g. https://underlayer.wiqis.com')
    ap.add_argument('--doc', default='docs/deployment.md',
                    help='deployment doc holding the digest and compiler pin')
    ap.add_argument('--expect-commit', help='override the digest from --doc')
    ap.add_argument('--expect-compiler', help='override the compiler pin from --doc')
    ap.add_argument('--timeout', type=float, default=10.0, help='HTTP timeout in seconds')
    ap.add_argument('--selftest', action='store_true', help='run local positive/negative cases')
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if not args.url:
        ap.error('a URL is required unless --selftest is given')

    digest, pin = read_baseline(args.doc)
    expected_commit = args.expect_commit or digest
    expected_pin = args.expect_compiler or pin
    print('release_probe: target %s' % args.url.rstrip('/'))
    print('release_probe: expected commit=%s compiler=%s'
          % (expected_commit or '(not recorded)', expected_pin or '(not recorded)'))
    if expected_commit is None or expected_pin is None:
        print('FAIL: no recorded baseline in %s -- founder must record a build digest '
              'and compiler pin in docs/deployment.md' % args.doc, file=sys.stderr)
        return 1
    try:
        payload = fetch_health(args.url, args.timeout)
    except (urllib.error.URLError, ValueError, OSError) as exc:
        print('FAIL: cannot read /api/health: %s: %s' % (type(exc).__name__, exc),
              file=sys.stderr)
        return 1
    failures = check(payload, expected_commit, expected_pin)
    for name in FIELDS:
        print('  %-17s %s' % (name, payload.get(name)))
    if failures:
        for line in failures:
            print('FAIL: ' + line, file=sys.stderr)
        return 1
    print('PASS: deployed build matches the recorded release baseline')
    return 0


if __name__ == '__main__':
    sys.exit(main())
