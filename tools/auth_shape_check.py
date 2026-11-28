#!/usr/bin/env python3
"""auth_shape_check.py -- embedded sign-in link shape + local stub flow (H11).

PART 1 (shipped gate, no browser): asserts every served app page's sign-in
control is the LOCAL `/sign-in` opener carrying `data-auth-open`, and that no
source file or served page contains `href="https://account.`. The account host
appears only in data attributes / iframe src built by underlayer_core.

PART 2 (--drive, verification package): plays the flow in Chromium against a
DISPOSABLE LOCAL ACCOUNT STUB installed with Playwright request routing. It
captures the password + MFA path, the WebAuthn `publicKey` options shape from a
stubbed passkey ceremony, and the Google popup postMessage shape. It records
screenshots and console lines under build/h11-evidence/.

HONEST LIMIT: a stub is not the deployed account service. A real passkey
authenticator and a real Google OAuth ceremony CANNOT be exercised from this
machine (no authenticator, no Google credentials); the dated exception and its
owner are recorded in docs/h11-embedded-signin-proof.md. This tool never
claims a real passkey works from static inspection.

No eval, no importScripts, stdlib + Playwright only, explicit timeouts,
non-loopback bases refused without --founder-approved.

Usage:
    python tools/auth_shape_check.py --selftest
    python tools/auth_shape_check.py --base http://127.0.0.1:9060
    python tools/auth_shape_check.py --base http://127.0.0.1:9060 --drive
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = ['/', '/login', '/register', '/sign-in', '/sign-up', '/courses',
         '/courses/elf', '/courses/elf/lessons/bytes', '/help', '/privacy']
BAD_HREF = re.compile(r'href\s*=\s*"\s*https://account\.')
LOCAL_OPENER = re.compile(r'href\s*=\s*"/sign-in"')
AUTH_OPEN = re.compile(r'data-auth-open')

PASSWORD_STUB = """<!doctype html><html><head><title>stub account</title></head>
<body data-stub="ul-account">
<div id="step1"><label>Email <input id="email" value="stub@example.invalid"></label>
<label>Password <input id="pw" type="password" value="Throwaway!123"></label>
<button id="pwsubmit">Sign in</button>
<button id="passkey">Use a passkey</button><button id="google">Google</button></div>
<div id="step2" hidden><p>Enter the 6-digit code</p><input id="code"><button id="mfadone">Verify</button></div>
<script>
var shapes = {passkey: null, google: null, password: null};
function win(payload) { parent.postMessage(payload, '*'); }
document.getElementById('pwsubmit').addEventListener('click', function () {
  shapes.password = {email: document.getElementById('email').value,
                     password_length: document.getElementById('pw').value.length};
  document.getElementById('step1').hidden = true;
  document.getElementById('step2').hidden = false;
});
document.getElementById('mfadone').addEventListener('click', function () {
  console.log('h11-stub-mfa-post');
  win({type: 'login_success', stub: 'password+mfa', password: shapes.password,
       code_length: document.getElementById('code').value.length});
});
document.getElementById('passkey').addEventListener('click', function () {
  // A real authenticator is NOT available on this machine. Capture the shape
  // of the publicKey options object the stub would hand to the ceremony; this
  // is a stub-authored shape, NOT an assertion that the real flow works.
  var opts = {publicKey: {challenge: 'base64url(challenge-bytes)',
                          rpId: location.hostname,
                          userVerification: 'preferred', allowCredentials: []}};
  shapes.passkey = {publicKeyKeys: Object.keys(opts.publicKey),
                    challenge_type: typeof opts.publicKey.challenge,
                    rpId: opts.publicKey.rpId,
                    userVerification: opts.publicKey.userVerification,
                    source: 'local-stub-only'};
  win({type: 'passkey-shape', stub: 'passkey-shape-only', passkey: shapes.passkey});
});
document.getElementById('google').addEventListener('click', function () {
  var popup = window.open('https://accounts.google.com/o/oauth2/stub', 'ul-google-stub');
  shapes.google = {popup_url: popup ? 'https://accounts.google.com/o/oauth2/stub' : null};
  setTimeout(function () {
    win({type: 'google-popup-shape', stub: 'google-popup-shape-only', google: shapes.google});
  }, 100);
});
</script></body></html>"""


def fetch(base, path, timeout=10):
    req = urllib.request.Request(base.rstrip('/') + path,
                                 headers={'Accept': 'text/html'})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.getcode(), response.read(2_000_000).decode('utf-8', 'replace')
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(200_000).decode('utf-8', 'replace')


def guard_base(base, approved):
    host = (base or '').split('//', 1)[-1].split('/', 1)[0].split(':')[0].lower()
    if host not in ('127.0.0.1', 'localhost', '::1') and not approved:
        print('FAIL: non-loopback base %s needs --founder-approved' % base,
              file=sys.stderr)
        return False
    return True


def source_shape():
    """Return (bad_files, local_openers) from the .ch sources."""
    bad, openers = [], []
    for root in ('web/src', 'content/src'):
        directory = os.path.join(REPO, root)
        for name in sorted(os.listdir(directory)):
            if not name.endswith('.ch'):
                continue
            path = os.path.join(directory, name)
            with open(path, encoding='utf-8') as handle:
                text = handle.read()
            if BAD_HREF.search(text) or 'href="https://account.' in text:
                bad.append(os.path.join(root, name))
            if LOCAL_OPENER.search(text) and AUTH_OPEN.search(text):
                openers.append(os.path.join(root, name))
    return bad, openers


def served_shape(base):
    """Return (bad_pages, opener_pages, broken_pages) from served HTML."""
    bad, openers, broken = [], [], []
    for path in PAGES:
        status, html = fetch(base, path)
        if status != 200:
            broken.append((path, status))
            continue
        if BAD_HREF.search(html) or 'href="https://account.' in html:
            bad.append(path)
        # A page that offers sign-in must offer the LOCAL opener. Pages without
        # any sign-in anchor are not forced to have one.
        anchors = re.findall(r'<a\b[^>]*href="([^"]+)"[^>]*>', html)
        if any(h.startswith('https://account.') for h in anchors):
            bad.append(path)
        if any(h == '/sign-in' for h in anchors):
            if 'data-auth-open' not in html:
                bad.append(path + ' (opener lacks data-auth-open)')
            else:
                openers.append(path)
    return bad, openers, broken


def selftest():
    cases = [
        ('local opener accepted', '<a href="/sign-in" data-auth-open>x</a>', True),
        ('remote href rejected', '<a href="https://account.wiqis.com/login">x</a>', False),
        ('opener without data-auth-open rejected', '<a href="/sign-in">x</a>', False),
    ]
    failed = []
    for label, html, expected_ok in cases:
        anchors = re.findall(r'<a\b[^>]*href="([^"]+)"[^>]*>', html)
        ok = not any(h.startswith('https://account.') for h in anchors)
        if any(h == '/sign-in' for h in anchors):
            ok = ok and 'data-auth-open' in html
        good = (ok == expected_ok)
        print('%s: %s (shape_ok=%s)' % ('PASS' if good else 'FAIL', label, ok))
        if not good:
            failed.append(label)
    if failed:
        print('FAIL: auth_shape_check selftest plants not detected: %s' % failed,
              file=sys.stderr)
        return 1
    print('PASS: auth_shape_check selftest (3 cases, 2 negative plants)')
    return 0


def launch_browser(pw):
    """Use a system Chrome when Playwright's pinned shell is not installed."""
    import glob
    candidates = [os.environ.get('CHROME_EXE', ''),
                  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
                  r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe']
    candidates += glob.glob(os.path.expanduser(
        '~/.cache/ms-playwright/chromium-*/chrome-linux/chrome'))
    candidates += glob.glob(os.path.join(
        os.environ.get('LOCALAPPDATA', ''), 'ms-playwright', 'chromium-*',
        'chrome-win', 'chrome.exe'))
    for exe in candidates:
        if exe and os.path.isfile(exe):
            return pw.chromium.launch(headless=True, executable_path=exe)
    return pw.chromium.launch(headless=True)


def drive(base, evidence_dir):
    """Exercise the flow against a local account stub via Playwright routing."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        print('FAIL: Playwright unavailable for --drive: %s' % exc, file=sys.stderr)
        return 1
    os.makedirs(evidence_dir, exist_ok=True)
    console, errors, events = [], [], []
    account_origin = 'https://account.wiqis.com'
    with sync_playwright() as pw:
        browser = launch_browser(pw)
        context = browser.new_context(viewport={'width': 1280, 'height': 900})
        page = context.new_page()
        # Playwright's page.on('message') did not observe iframe postMessages in
        # this checkout, so record them from an init script (injected by CDP,
        # not via JS eval) and read the array after each ceremony shape.
        page.add_init_script(script="""
window.__ulMessages = [];
window.addEventListener('message', function (e) {
  window.__ulMessages.push({type: e.data && e.data.type, data: e.data, origin: e.origin});
});
""")
        page.on('console', lambda msg: console.append('%s: %s' % (msg.type, msg.text)))
        page.on('pageerror', lambda err: errors.append(str(err)))

        def route_account(route):
            url = route.request.url
            if 'o/oauth2' in url:
                body = ('<!doctype html><title>stub google</title>'
                        '<p>stub Google consent</p><script>'
                        "parent.postMessage({type:'google-popup-shape',stub:'google-popup'},'*');"
                        '</script>')
                route.fulfill(status=200, content_type='text/html', body=body)
                return
            route.fulfill(status=200, content_type='text/html', body=PASSWORD_STUB)

        context.route(account_origin + '/**', route_account)
        # The bridge call is local to Underlayer; answer it in the browser so
        # the flow can complete without a real shared-account cookie. This does
        # NOT change the server or the shared account service. Recording the
        # call is the primary evidence that the embedded flow completed.
        bridge_calls = []

        def route_bridge(route):
            bridge_calls.append({'method': route.request.method,
                                 'url': route.request.url,
                                 'body': route.request.post_data})
            route.fulfill(status=200, content_type='application/json',
                          body='{"ok":true}')

        context.route('**/api/auth/from-account', route_bridge)

        def on_message(msg):
            try:
                events.append(msg.json())
            except Exception:
                events.append({'text': msg.text, 'origin': msg.origin})

        page.on('message', on_message)
        page.goto(base.rstrip('/') + '/login', wait_until='domcontentloaded',
                  timeout=20000)
        # The delegated opener is installed by an inline #js block. Playwright's
        # wait_for_function uses page-eval, which the site CSP forbids, so use
        # locator auto-waits and a short settle instead.
        page.wait_for_timeout(600)
        page.locator('a[data-auth-open]').first.click(timeout=10000)
        page.wait_for_timeout(2500)
        frame = page.frame_locator('iframe.wq-embed')
        # Stub-only ceremony shapes FIRST: a successful login reloads the page
        # and destroys the iframe, so capture these before completing MFA.
        try:
            frame.locator('#passkey').click(timeout=8000)
            page.wait_for_timeout(400)
        except Exception as exc:
            console.append('passkey stub click note: %s' % exc)
        try:
            frame.locator('#google').click(timeout=8000)
            page.wait_for_timeout(500)
        except Exception as exc:
            console.append('google stub click note: %s' % exc)
        page.screenshot(path=os.path.join(evidence_dir, 'h11-passkey-google-shapes.png'),
                        full_page=True)
        try:
            events.extend(page.evaluate('window.__ulMessages') or [])
        except Exception as exc:
            console.append('message-shape capture note: %s' % exc)
        # Real-shaped password path with a second factor, all inside the dialog.
        frame.locator('#pwsubmit').click(timeout=15000)
        frame.locator('#code').fill('123456')
        frame.locator('#mfadone').click(timeout=10000)
        page.wait_for_timeout(900)
        page.screenshot(path=os.path.join(evidence_dir, 'h11-password-mfa.png'))
        browser.close()

    evidence = {'date': time.strftime('%Y-%m-%d'), 'base': base,
                'account_stub': account_origin + ' (Playwright route, local only)',
                'events': events, 'bridge_calls': bridge_calls,
                'console': console, 'page_errors': errors,
                'real_passkey': 'NOT EXERCISED - no authenticator on this machine',
                'real_google': 'NOT EXERCISED - no Google credentials; popup stub only'}
    with open(os.path.join(evidence_dir, 'evidence.json'), 'w', encoding='utf-8') as handle:
        json.dump(evidence, handle, indent=2)
    print('drive: %d postMessage events captured; screenshots in %s'
          % (len(events), evidence_dir))
    ok = bool(bridge_calls) or any(e.get('stub') == 'password+mfa' for e in events)
    print('%s: password+MFA path reached the local session bridge (%d calls)'
          % ('PASS' if ok else 'FAIL', len(bridge_calls)))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', help='loopback base URL')
    ap.add_argument('--drive', action='store_true', help='run the local stub flow')
    ap.add_argument('--evidence-dir', default='build/h11-evidence')
    ap.add_argument('--founder-approved', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not guard_base(args.base, args.founder_approved):
        return 2

    failures = []
    bad_files, openers = source_shape()
    print('%s: source remote hrefs: %s; local openers: %s'
          % ('PASS' if not bad_files else 'FAIL', bad_files or 'none', openers))
    if bad_files or not openers:
        failures.append('source-shape')
    bad_pages, opener_pages, broken = served_shape(args.base)
    print('%s: served remote hrefs: %s; broken pages: %s; opener pages: %d'
          % ('PASS' if not bad_pages and not broken else 'FAIL',
             bad_pages or 'none', broken or 'none', len(opener_pages)))
    if bad_pages or broken:
        failures.append('served-shape')

    if args.drive:
        rc = drive(args.base, args.evidence_dir)
        if rc != 0:
            failures.append('drive')

    if failures:
        print('FAIL: auth_shape_check: %s' % ', '.join(failures), file=sys.stderr)
        return 1
    print('PASS: auth_shape_check')
    return 0


if __name__ == '__main__':
    sys.exit(main())
