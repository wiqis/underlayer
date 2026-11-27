#!/usr/bin/env python3
"""theme_boot_hash_check.py -- prove B5's external theme asset is byte-consistent.

Three places must carry the SAME SHA-384 of the SAME JavaScript:

  1. content/src/theme_boot.ch  theme_boot_js_source()   (served bytes)
  2. content/src/theme_boot.ch  theme_boot_integrity()   (SRI constant)
  3. content/src/theme_boot.ch  the inline static-page fallback (same JS)
     plus the SRI `integrity` attribute on the external <script> tag

If any of them drift, a browser refuses the SRI script and the reader gets the
theme flash back. The hash is deliberately NOT in the CSP `script-src`: under
CSP3 that would make the browser ignore 'unsafe-inline' and break the macro
emitted inline blocks (measured; see docs/deployment.md §6 item 1). The tool
asserts the CSP is unchanged. This is a SOURCE check by default; pass a base URL
to also fetch /assets/theme-boot.js and compare the served bytes and CSP header.

No writes, no secrets, explicit timeouts, stdlib only.

Usage:
    python tools/theme_boot_hash_check.py
    python tools/theme_boot_hash_check.py http://localhost:9014
    python tools/theme_boot_hash_check.py --selftest
"""
import argparse
import base64
import hashlib
import re
import sys
import urllib.request

BOOT = 'content/src/theme_boot.ch'
RESP = 'web/src/responses.ch'
HASH_RE = re.compile(r'sha384-[A-Za-z0-9+/=]+')


def read(path):
    with open(path, 'r', encoding='utf-8') as handle:
        return handle.read()


def source_js(text):
    match = re.search(r'public func theme_boot_js_source\(\)\s*:\s*string\s*\{'
                      r'\s*return string\("([^"]+)"\)\s*\}', text)
    if not match:
        raise AssertionError('theme_boot_js_source() literal not found')
    return match.group(1)


def inline_js(text):
    match = re.search(r'boot = string\("<script>(.*?)</script>"\)', text, re.S)
    if not match:
        raise AssertionError('inline static-page boot literal not found')
    return match.group(1)


def digest(js):
    return 'sha384-' + base64.b64encode(hashlib.sha384(js.encode('utf-8')).digest()).decode('ascii')


def check_sources():
    failures = []
    boot = read(BOOT)
    responses = read(RESP)
    js = source_js(boot)
    want = digest(js)

    if inline_js(boot) != js:
        failures.append('inline static fallback and external asset source differ')

    boot_hashes = set(HASH_RE.findall(boot))
    if boot_hashes != {want}:
        failures.append('theme_boot.ch hashes %r, expected %s' % (sorted(boot_hashes), want))

    # B5 keeps the load-bearing CSP entries byte-for-byte. In particular the
    # hash must NOT enter script-src (CSP3 would then ignore 'unsafe-inline').
    if HASH_RE.search(responses):
        failures.append('a hash in responses.ch script-src breaks macro inline scripts')
    csp_match = re.search(r'var policy = string\("([^"]+)"\)', responses)
    if not csp_match:
        failures.append('CSP policy literal not found in responses.ch')
    else:
        policy = csp_match.group(1)
        if "script-src 'self' 'unsafe-inline';" not in policy:
            failures.append('script-src changed; B5 must not tighten it yet')
        if "connect-src 'self'" not in policy:
            failures.append('connect-src entry missing (load-bearing)')
        if ('policy.append_view("; frame-src ")' not in responses or
                'policy.append_view(" https://accounts.google.com' not in responses):
            failures.append('frame-src account+Google entry missing (load-bearing)')
        unsafe = sorted(set(re.findall(r"'unsafe-[a-z-]+'", policy)))
        if unsafe != ["'unsafe-inline'"]:
            failures.append('unexpected unsafe-* source(s): %r' % unsafe)
    return js, want, failures


def check_served(base, want, timeout):
    failures = []
    root = base.rstrip('/')
    try:
        with urllib.request.urlopen(root + '/assets/theme-boot.js', timeout=timeout) as response:
            served = response.read(65536).decode('utf-8')
        if served != source_js(read(BOOT)):
            failures.append('served /assets/theme-boot.js differs from source')
    except Exception as exc:
        failures.append('cannot fetch /assets/theme-boot.js: %s: %s' % (type(exc).__name__, exc))
    try:
        req = urllib.request.Request(root + '/api/health', headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            csp = response.headers.get('Content-Security-Policy', '')
        if want in csp:
            failures.append('served CSP carries the theme hash and would ignore unsafe-inline')
        if "connect-src 'self' " not in csp or 'frame-src ' not in csp:
            failures.append('served CSP lost a load-bearing frame-src/connect-src entry')
    except Exception as exc:
        failures.append('cannot read served CSP: %s: %s' % (type(exc).__name__, exc))
    return failures


def selftest():
    """A planted hash mismatch must fail; the clean tree must pass."""
    import tempfile
    import os
    import shutil
    js, want, failures = check_sources()
    if failures:
        print('FAIL: clean tree: %s' % '; '.join(failures), file=sys.stderr)
        return 1
    print('PASS: clean tree source hashes agree (%s, %d bytes)' % (want, len(js)))
    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, 'r')
        os.makedirs(os.path.join(root, 'web', 'src'))
        os.makedirs(os.path.join(root, 'content', 'src'))
        shutil.copyfile(RESP, os.path.join(root, RESP))
        shutil.copyfile(BOOT, os.path.join(root, BOOT))
        victim = os.path.join(root, BOOT)
        planted = read(victim).replace('window.$wiqisThemeGet', 'window.$wiqisThemeGetX', 1)
        with open(victim, 'w', encoding='utf-8') as handle:
            handle.write(planted)
        old = os.getcwd()
        os.chdir(root)
        try:
            _, _, planted_failures = check_sources()
        finally:
            os.chdir(old)
    if not planted_failures:
        print('FAIL: planted source drift was not detected', file=sys.stderr)
        return 1
    print('PASS: planted source drift detected (%d finding(s))' % len(planted_failures))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base', nargs='?', help='optional base URL to check served bytes/CSP')
    ap.add_argument('--timeout', type=float, default=10.0)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    js, want, failures = check_sources()
    print('theme_boot_hash_check: %s (%d bytes)' % (want, len(js)))
    if args.base:
        failures.extend(check_served(args.base, want, args.timeout))
    for line in failures:
        print('FAIL: ' + line, file=sys.stderr)
    if failures:
        return 1
    print('PASS: theme boot source, SRI hash and CSP agree')
    return 0


if __name__ == '__main__':
    sys.exit(main())
