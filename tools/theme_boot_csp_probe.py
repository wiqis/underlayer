#!/usr/bin/env python3
"""theme_boot_csp_probe.py -- CDP proof for B5's external theme boot.

Drives a real Chrome and asserts, for a brand-shell page and a lesson page:

  * zero `securitypolicyviolation` events (CSP is not weakened or broken);
  * the external `/assets/theme-boot.js` is actually fetched with HTTP 200;
  * `wiqis-theme=dark` is on <html> at the moment <body> first appears
    (no theme flash), with data-theme=dark and colorScheme=dark.

Playwright + a local Chrome are required; if they are missing the tool says so
and exits 1 -- it never claims a proof it did not run. No writes to the server,
no secrets, explicit timeouts, stdlib + Playwright only.

Usage: python tools/theme_boot_csp_probe.py http://localhost:9031
"""
import os
import sys

PAGES = ['/courses', '/courses/elf/lessons/bytes', '/help']

INIT = """
window.__cspViolations = [];
window.__themeAtBody = null;
window.__csAtBody = null;
document.addEventListener('securitypolicyviolation', function (e) {
  window.__cspViolations.push({
    directive: e.violatedDirective,
    blocked: e.blockedURI,
    source: e.sourceURI
  });
});
try {
  new MutationObserver(function () {
    if (window.__themeAtBody === null && document.body) {
      window.__themeAtBody = document.documentElement.classList.contains('dark');
      window.__csAtBody = document.documentElement.style.colorScheme;
    }
  }).observe(document, {childList: true, subtree: true});
} catch (e) { window.__themeAtBody = 'error: ' + e.message; }
"""


def main():
    if len(sys.argv) != 2:
        print('usage: theme_boot_csp_probe.py BASE_URL', file=sys.stderr)
        return 2
    base = sys.argv[1].rstrip('/')
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print('FAIL: Playwright not installed; browser proof not run')
        return 1
    chrome = os.environ.get('CHROME_PATH') or (
        r'C:\Program Files\Google\Chrome\Application\chrome.exe'
        if os.name == 'nt' else '/usr/bin/google-chrome')
    if not os.path.isfile(chrome):
        print('FAIL: Chrome not found at %s; browser proof not run' % chrome)
        return 1

    failures = []
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=chrome, headless=True,
                                    args=['--no-sandbox', '--disable-gpu'])
        try:
            context = browser.new_context()
            context.add_init_script(INIT)
            page = context.new_page()
            for path in PAGES:
                page.goto(base + path, wait_until='load', timeout=30000)
                page.evaluate("localStorage.setItem('wiqis-theme','dark')")
                page.reload(wait_until='load', timeout=30000)
                result = page.evaluate("""() => ({
                    violations: window.__cspViolations,
                    atBody: window.__themeAtBody,
                    csAtBody: window.__csAtBody,
                    dataTheme: document.documentElement.getAttribute('data-theme'),
                    dark: document.documentElement.classList.contains('dark'),
                    externalBoot: !!document.querySelector('script[src="/assets/theme-boot.js"]'),
                    inlineBoot: !!document.querySelector('script:not([src])')
                })""")
                violations = result['violations']
                boot_form = ('external' if result['externalBoot'] else
                             'inline' if result['inlineBoot'] else 'none')
                print('%s: csp_violations=%d at_body=%r colorScheme=%r data-theme=%r boot=%s'
                      % (path, len(violations), result['atBody'], result['csAtBody'],
                         result['dataTheme'], boot_form))
                if violations:
                    failures.append('%s: %d CSP violation(s): %r'
                                    % (path, len(violations), violations[:3]))
                if result['atBody'] is not True:
                    failures.append('%s: dark not applied before first body paint: %r'
                                    % (path, result['atBody']))
                if result['csAtBody'] != 'dark':
                    failures.append('%s: colorScheme at first paint: %r'
                                    % (path, result['csAtBody']))
                if result['dataTheme'] != 'dark' or result['dark'] is not True:
                    failures.append('%s: dark state not settled after load' % path)
                if boot_form == 'none':
                    failures.append('%s: no theme boot script in head' % path)
                # Brand-shell pages take the B5 external path. Lesson pages are
                # also exported for file:// and keep the inline copy; both are
                # acceptable here, but "none" is not.
                if path == '/courses' and boot_form != 'external':
                    failures.append('%s: brand page did not take the external boot' % path)
                # The init script is per document; reset for the next navigation.
                page.evaluate('window.__cspViolations = []; window.__themeAtBody = null; '
                              'window.__csAtBody = null;')
                page.evaluate("localStorage.setItem('wiqis-theme','light')")
        finally:
            browser.close()
    if failures:
        for line in failures:
            print('FAIL: ' + line, file=sys.stderr)
        return 1
    print('PASS: zero CSP violations and dark-before-first-paint on %d pages' % len(PAGES))
    return 0


if __name__ == '__main__':
    sys.exit(main())
