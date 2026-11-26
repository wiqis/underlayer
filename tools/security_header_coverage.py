#!/usr/bin/env python3
"""security_header_coverage.py -- prove the header contract covers EVERY path.

H3. A live probe in Nov 2026 found /help, /faq, /about, /shortcuts, /privacy,
/terms and the 404 had NO security headers: they are served by `web::App`
through `web::serve_request`, which bypasses the `send_*` helpers that call
`apply_security_headers`. This tool asserts byte-for-byte header parity between
those frozen pages and a handler route (/api/health).

It also resolves the font question: the brand layer links the Inter stylesheet
from fonts.googleapis.com and downloads woff2 from fonts.gstatic.com. A page
that contains that link must be served under a CSP whose style-src names the
stylesheet origin AND whose font-src names the font origin; otherwise the
browser reports a violation on an otherwise ordinary lesson load.

HOW IT PROVES IT IS NOT VACUOUS
-------------------------------
`--selftest` starts a tiny stdlib HTTP server on a loopback port with two
routes: /good (complete contract) and /bad (the negative plant: the five
headers stripped, exactly the defect this tool exists to catch). The checker
MUST pass /good and FAIL /bad. A checker that awards a pass to a headerless
response is decoration.

Usage:
    python3 tools/security_header_coverage.py http://localhost:9014
    python3 tools/security_header_coverage.py --port 9014
    python3 tools/security_header_coverage.py --selftest

Exit: 0 every path has the contract and the self-test agrees; 1 a violation;
      2 bad usage / server unreachable (NOT a pass).
"""
import argparse
import http.server
import re
import sys
import threading
import urllib.error
import urllib.request

TIMEOUT = 10

FIXED = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Strict-Transport-Security': 'max-age=31536000',
}

CSP_TOKENS = (
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline'",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    "img-src 'self' data: https://storage.googleapis.com",
    "form-action 'self'",
    "base-uri 'self'",
    "object-src 'none'",
)

PATHS = [
    '/api/health', '/', '/courses', '/courses/elf/lessons/bytes',
    '/help', '/faq', '/about', '/shortcuts', '/privacy', '/terms',
    '/no-such-page-for-header-check',
]

RID_RE = re.compile(r'^[A-Za-z0-9_.:-]{1,64}$')


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'ul-header-coverage/1'})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status, dict(r.headers.items()), r.read(400000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers.items()), e.read(400000).decode('utf-8', 'replace')
    except Exception as exc:  # noqa: BLE001 - unreachable is a result, not a pass
        return 0, {}, 'TRANSPORT: %s' % exc


def evaluate(status, headers, body, canonical_csp=None):
    """Return (violations, csp). Pure function so the plant can call it directly."""
    bad = []
    if status == 0:
        return ['server unreachable'], None
    lower = {k.lower(): v for k, v in headers.items()}

    for name, want in FIXED.items():
        got = lower.get(name.lower())
        if got != want:
            bad.append('%s expected %r got %r' % (name, want, got))

    csp = lower.get('content-security-policy')
    if not csp:
        bad.append('Content-Security-Policy missing')
    else:
        for token in CSP_TOKENS:
            if token not in csp:
                bad.append('CSP lacks %r' % token)
        if canonical_csp is not None and csp != canonical_csp:
            bad.append('CSP differs from /api/health: %r' % csp[:160])

    rid = lower.get('x-request-id')
    if not rid or not RID_RE.match(rid):
        bad.append('X-Request-Id missing or unsafe: %r' % rid)

    # Font resolution: only require the origins when the served HTML actually
    # links Google Fonts. A page with no such link must not be forced to carry
    # an unnecessary third-party origin.
    if 'fonts.googleapis.com' in body and csp:
        if 'https://fonts.googleapis.com' not in csp:
            bad.append('page links Google Fonts but style-src does not allow it')
        if 'https://fonts.gstatic.com' not in csp:
            bad.append('page links Google Fonts but font-src does not allow it')
    return bad, csp


def check_base(base, verbose=True):
    base = base.rstrip('/')
    st, headers, _ = fetch(base + '/api/health')
    if st != 200:
        print('security_header_coverage: /api/health -> %d, NOT a pass' % st)
        return 2
    _, csp = evaluate(st, headers, '')
    if not csp:
        print('security_header_coverage: /api/health has no CSP; cannot form a baseline')
        return 1

    failures = 0
    for path in PATHS:
        st, hdrs, body = fetch(base + path)
        bad, _ = evaluate(st, hdrs, body, canonical_csp=csp)
        if bad:
            failures += 1
            print('FAIL %-36s status=%s' % (path, st))
            for item in bad:
                print('       %s' % item)
        elif verbose:
            print('PASS %-36s status=%s' % (path, st))
    if failures:
        print('security_header_coverage: %d of %d paths violate the contract'
              % (failures, len(PATHS)))
        return 1
    print('security_header_coverage: ALL %d paths carry the identical header '
          'contract (CSP + HSTS + nosniff + frame + referrer + request id)'
          % len(PATHS))
    return 0


class _PlantHandler(http.server.BaseHTTPRequestHandler):
    """Serves one good and one deliberately headerless response for --selftest."""

    def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler API
        good = FIXED.copy()
        good['Content-Security-Policy'] = '; '.join(CSP_TOKENS)
        good['X-Request-Id'] = 'selftest-ok'
        if self.path == '/good':
            self.send_response(200)
            for k, v in good.items():
                self.send_header(k, v)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body>good</body></html>')
        elif self.path == '/bad':
            # NEGATIVE PLANT: the exact H3 defect -- frozen page, no headers.
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body>no headers</body></html>')
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        pass


def selftest():
    server = http.server.HTTPServer(('127.0.0.1', 0), _PlantHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = 'http://127.0.0.1:%d' % server.server_port
        st, hdrs, body = fetch(base + '/good')
        good_bad, _ = evaluate(st, hdrs, body)
        st2, hdrs2, body2 = fetch(base + '/bad')
        bad_bad, _ = evaluate(st2, hdrs2, body2)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    ok = not good_bad and bool(bad_bad)
    print('selftest control (complete contract): %s' % ('PASS' if not good_bad else good_bad))
    print('selftest negative plant (headers stripped): %s'
          % ('FAIL as required' if bad_bad else 'NO FAILURE -- checker is vacuous'))
    if ok:
        print('security_header_coverage --selftest OK: the check fires on the planted defect.')
        return 0
    return 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('base', nargs='?', default=None)
    ap.add_argument('--port', type=int, default=None)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    base = args.base or ('http://localhost:%d' % args.port if args.port else None)
    if not base:
        ap.error('pass a base URL or --port (or --selftest)')
    return check_base(base)


if __name__ == '__main__':
    sys.exit(main())
