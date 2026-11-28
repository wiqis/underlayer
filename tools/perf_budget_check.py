#!/usr/bin/env python3
"""perf_budget_check.py -- H15 CWV-aligned performance budget gate.

Drives six page archetypes at 1280px and 420px under 4x CPU / 1.6 Mbps network
throttling with Chrome DevTools Protocol (via Playwright). For each run it
records transferred bytes, TTFB, LCP, INP and CLS, then asserts the budgets:

    p95 LCP < 2500 ms, INP < 200 ms, CLS < 0.1, transferred < 500 KB

INP here is the largest observed event duration from a PerformanceObserver with
a 16 ms threshold after one scripted interaction; it is an approximation of the
field INP metric, and the limitation is recorded in docs/deployment.md.

It also asserts NO render-blocking third-party stylesheet in the head. A brand
shell currently links fonts.googleapis.com CSS without media/onload; the tool
reports that as a FAIL with a named owner rather than hiding it.

No eval/importScripts in this checker (the injected observer uses a literal
script string via Playwright's init-script API, not JS `eval`). Stdlib only for
the checker itself; explicit timeouts; non-loopback bases need approval.

Usage:
    python tools/perf_budget_check.py --selftest
    python tools/perf_budget_check.py --base http://127.0.0.1:9060
"""
import argparse
import json
import math
import os
import re
import sys
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHETYPES = ('/', '/courses', '/courses/elf', '/courses/elf/lessons/bytes',
              '/help', '/login')
WIDTHS = (1280, 420)
BUDGETS = {'lcp_ms': 2500.0, 'inp_ms': 200.0, 'cls': 0.1, 'bytes': 500 * 1024}

OBSERVER_JS = r"""
window.__ulPerf = { lcp: 0, cls: 0, inp: 0 };
try {
  new PerformanceObserver(function (list) {
    var entries = list.getEntries();
    for (var i = 0; i < entries.length; i++) {
      window.__ulPerf.lcp = entries[i].startTime;
    }
  }).observe({ type: 'largest-contentful-paint', buffered: true });
} catch (e) {}
try {
  new PerformanceObserver(function (list) {
    var entries = list.getEntries();
    for (var i = 0; i < entries.length; i++) {
      if (!entries[i].hadRecentInput) { window.__ulPerf.cls += entries[i].value; }
    }
  }).observe({ type: 'layout-shift', buffered: true });
} catch (e) {}
try {
  new PerformanceObserver(function (list) {
    var entries = list.getEntries();
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].duration > window.__ulPerf.inp) {
        window.__ulPerf.inp = entries[i].duration;
      }
    }
  }).observe({ type: 'event', buffered: true, durationThreshold: 16 });
} catch (e) {}
"""


def guard_base(base, approved):
    host = (base or '').split('//', 1)[-1].split('/', 1)[0].split(':')[0].lower()
    if host not in ('127.0.0.1', 'localhost', '::1') and not approved:
        print('FAIL: non-loopback base %s needs --founder-approved' % base, file=sys.stderr)
        return False
    return True


def fetch_html(base, path):
    req = urllib.request.Request(base.rstrip('/') + path,
                                 headers={'Accept': 'text/html'})
    with urllib.request.urlopen(req, timeout=10) as response:
        return response.read(2_000_000).decode('utf-8', 'replace')


def render_blocking_third_party(html, base_host):
    """Return names of external stylesheets that block first paint."""
    heads = re.findall(r'<link\b[^>]*rel="stylesheet"[^>]*>', html, re.I)
    found = []
    for tag in heads:
        href = re.search(r'href\s*=\s*"([^"]+)"', tag)
        if not href:
            continue
        url = href.group(1)
        if url.startswith(('http://', 'https://', '//')):
            host = url.split('//', 1)[-1].split('/', 1)[0].lower()
            if host and host != base_host:
                # media="print" or an onload swap is explicitly non-blocking.
                if 'media=' in tag or 'onload=' in tag:
                    continue
                found.append(host)
    return found


def p95(values):
    if not values:
        return float('inf')
    ordered = sorted(values)
    return ordered[max(0, math.ceil(0.95 * len(ordered)) - 1)]


def budgets_ok(measurements):
    failures = []
    for name in ('lcp_ms', 'inp_ms', 'cls', 'bytes'):
        value = p95([m[name] for m in measurements])
        if not (value < BUDGETS[name]):
            failures.append('%s p95 %.2f >= %.2f' % (name, value, BUDGETS[name]))
    return failures


def selftest():
    """Negative plants: over-budget measurements and a blocking CSS link."""
    good = [{'lcp_ms': 1200.0, 'inp_ms': 60.0, 'cls': 0.02, 'bytes': 180000.0}] * 4
    cases = [
        ('within budget', good, True),
        ('LCP over budget', [dict(good[0], lcp_ms=3000.0)] * 4, False),
        ('INP over budget', [dict(good[0], inp_ms=260.0)] * 4, False),
        ('CLS over budget', [dict(good[0], cls=0.2)] * 4, False),
        ('transfer over budget', [dict(good[0], bytes=600000.0)] * 4, False),
    ]
    failures = []
    for label, data, expected_ok in cases:
        found = budgets_ok(data)
        ok = (not found) == expected_ok
        print('%s: %s (%s)' % ('PASS' if ok else 'FAIL', label,
                              ', '.join(found) or 'no failure'))
        if not ok:
            failures.append(label)
    css_cases = [
        ('same-origin stylesheet accepted',
         '<link rel="stylesheet" href="/assets/app.css">', [], True),
        ('blocking third-party stylesheet rejected',
         '<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet">',
         ['fonts.googleapis.com'], False),
        ('non-blocking third-party stylesheet accepted',
         '<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet" media="print">',
         [], True),
    ]
    for label, html, _expected, expected_ok in css_cases:
        found = render_blocking_third_party(html, '127.0.0.1:9060')
        ok = (not found) == expected_ok
        print('%s: %s (%s)' % ('PASS' if ok else 'FAIL', label, found or 'none'))
        if not ok:
            failures.append(label)
    if failures:
        print('FAIL: perf_budget_check selftest plants not detected: %s' % failures,
              file=sys.stderr)
        return 1
    print('PASS: perf_budget_check selftest (8 cases, 5 negative plants)')
    return 0


def launch_browser(pw):
    """Use a system Chrome when Playwright's pinned shell is not installed."""
    import glob
    candidates = [os.environ.get('CHROME_EXE', ''),
                  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
                  r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe']
    candidates += glob.glob(os.path.join(
        os.environ.get('LOCALAPPDATA', ''), 'ms-playwright', 'chromium-*',
        'chrome-win', 'chrome.exe'))
    for exe in candidates:
        if exe and os.path.isfile(exe):
            return pw.chromium.launch(headless=True, executable_path=exe)
    return pw.chromium.launch(headless=True)


def measure(base, evidence):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        print('FAIL: Playwright unavailable: %s' % exc, file=sys.stderr)
        return None, ['playwright unavailable']
    measurements = []
    with sync_playwright() as pw:
        browser = launch_browser(pw)
        for width in WIDTHS:
            for path in ARCHETYPES:
                context = browser.new_context(viewport={'width': width, 'height': 900})
                page = context.new_page()
                client = context.new_cdp_session(page)
                client.send('Network.enable')
                client.send('Network.emulateNetworkConditions', {
                    'offline': False, 'latency': 150,
                    'downloadThroughput': 200000, 'uploadThroughput': 93750,
                    'connectionType': 'cellular4g'})
                client.send('Emulation.setCPUThrottlingRate', {'rate': 4})
                transferred = []
                client.on('Network.loadingFinished',
                          lambda e: transferred.append(e.get('encodedDataLength', 0)))
                page.add_init_script(script=OBSERVER_JS)
                try:
                    page.goto(base.rstrip('/') + path, wait_until='load', timeout=30000)
                    page.locator('body').click(position={'x': 4, 'y': 4}, timeout=5000)
                    page.wait_for_timeout(400)
                    perf = page.evaluate('window.__ulPerf')
                    nav = page.evaluate(
                        "(() => { var e = performance.getEntriesByType('navigation')[0];"
                        "return e ? (e.responseStart - e.requestStart) : 0; })()")
                    measurements.append({
                        'path': path, 'width': width,
                        'lcp_ms': float(perf.get('lcp', 0) or 0),
                        'inp_ms': float(perf.get('inp', 0) or 0),
                        'cls': float(perf.get('cls', 0) or 0),
                        'ttfb_ms': float(nav or 0),
                        'bytes': float(sum(transferred))})
                except Exception as exc:
                    print('FAIL: could not measure %s @%d: %s' % (path, width, exc),
                          file=sys.stderr)
                    return None, ['measure %s @%d' % (path, width)]
                finally:
                    context.close()
        browser.close()
    if evidence:
        with open(evidence, 'w', encoding='utf-8') as handle:
            json.dump({'base': base, 'runs': measurements}, handle, indent=2)
    return measurements, []


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', help='loopback base URL')
    ap.add_argument('--evidence', help='write the raw run table to this JSON file')
    ap.add_argument('--founder-approved', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not guard_base(args.base, args.founder_approved):
        return 2

    failures = []
    base_host = (args.base or '').split('//', 1)[-1].split('/', 1)[0].lower()
    for path in ARCHETYPES:
        try:
            html = fetch_html(args.base, path)
        except Exception as exc:
            print('FAIL: fetch %s: %s' % (path, exc), file=sys.stderr)
            failures.append('fetch ' + path)
            continue
        blocking = render_blocking_third_party(html, base_host)
        print('%s: %s blocking third-party stylesheet: %s'
              % ('PASS' if not blocking else 'FAIL', path, blocking or 'none'))
        if blocking:
            failures.append('blocking-css ' + path)

    runs, errors = measure(args.base, args.evidence)
    failures.extend(errors)
    if runs:
        for name in ('lcp_ms', 'inp_ms', 'cls', 'bytes', 'ttfb_ms'):
            print('  %-8s p95=%.2f' % (name, p95([r[name] for r in runs])))
        for line in budgets_ok(runs):
            print('FAIL: ' + line, file=sys.stderr)
            failures.append(line)

    if failures:
        print('FAIL: perf_budget_check: %s' % ', '.join(failures), file=sys.stderr)
        return 1
    print('PASS: perf_budget_check (6 archetypes x 2 widths, throttled)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
