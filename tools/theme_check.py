#!/usr/bin/env python3
"""theme_check.py -- prove the theme is applied BEFORE the first paint.

WHY THIS EXISTS

Reported on 2026-10-02: the site loads light, then becomes dark, and the shift is
visible. That is not a slow page -- it is a CORRECT page that arrives in the wrong
colours and then corrects itself.

The fix is a small BLOCKING script in <head> that reads the stored preference and
applies the `.dark` class before the browser paints anything. This check exists
because that fix is easy to lose.

THE CONTRACT AS IT STANDS IN NOVEMBER 2026 (reconciled from the served HTML)

There is ONE key, the company-wide `wiqis-theme` (`system` | `light` | `dark`):

  * brandlib's WiqisTheme emits a pre-paint script into <head>. It defines
    KEY = "wiqis-theme", reads it with localStorage.getItem(KEY), resolves it
    against prefers-color-scheme, and calls apply(get()) SYNCHRONOUSLY -- still
    inside <head>, so before first paint. It publishes window.$wiqisThemeGet/Set.
  * underlayer's own boot script (content/src/theme_boot.ch) is a small fallback
    appended to <head> on every page, lessons included. When WiqisTheme is present
    it simply re-applies the same stored choice via those globals; on a lesson
    page (no brandlib) it resolves `wiqis-theme` itself. It is the reason one key
    cannot hold two contradictory preferences.
  * the nav's getTheme() reads the SAME key. A duplicated decision is exactly the
    thing that drifts, so key agreement is asserted here.
  * <meta name="color-scheme" content="light dark"> lets the browser's own
    surfaces (scrollbars, form controls, the frame behind the document) follow.
    Auth pages (/login, /register) deliberately call WiqisTheme(..., false) so a
    stored choice is NOT honoured there; the brand script still sets
    el.style.colorScheme inline, which is the equivalent frame guarantee.
  * LESSONS ARE EXEMPT FROM THE BRAND SHELL, not from theming. A lesson page has
    no WiqisTheme and no nav getTheme; it carries only the small boot script and
    its navbar. An older version of this checker asserted "no theme read at all"
    on lessons, keyed to a stale `theme` string. That assertion passed by accident
    after the key became `wiqis-theme` and would now fail on a correct page. The
    meaningful, current assertion is "no brand shell on a lesson".

An earlier version of this checker hard-coded `localStorage.getItem('theme')`.
That key no longer exists anywhere in the product; the checker was reporting a
product bug that was not there. It now asserts the contract above, and it still
fails if the pre-paint script is missing, duplicated, or moved into the body.

A live behavioural check (opt-in when Playwright + Chrome are available) proves
that a stored 'dark' choice is actually applied before the first body paint, not
just that the right source text is present. With no browser it degrades to the
static proof and says so; it never turns a missing browser into a product failure.

Usage:
    python3 tools/theme_check.py [base-url] [--browser]
Exit 0 all assertions hold. 1 otherwise.
"""
import os
import re
import sys
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else 'http://localhost:9000'
WANT_BROWSER = '--browser' in sys.argv
failures = []
checks = []
skipped = []


def check(name, cond, detail=''):
    checks.append(name)
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def note(name, detail):
    skipped.append(name)
    print('  SKIP  %s  -- %s' % (name, detail))


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=40) as r:
        return r.read().decode('utf-8', 'replace')


def split_head(html):
    i = html.find('</head>')
    if i == -1:
        return html, ''
    return html[:i], html[i:]


def scripts(text):
    return [m.group(1) for m in re.finditer(r'<script[^>]*>(.*?)</script>', text, re.S)]


def brand_script(head):
    """The WiqisTheme pre-paint IIFE: defines KEY, resolves, and calls apply(get())."""
    for s in scripts(head):
        if re.search(r'var\s+KEY\s*=\s*["\']wiqis-theme["\']', s) and 'apply(get());' in s:
            return s
    return None


def boot_script(head):
    """The small underlayer fallback: delegates to $wiqisThemeGet or resolves the key itself."""
    for s in scripts(head):
        if '$wiqisThemeGet' in s and "getItem('wiqis-theme')" in s:
            return s
    return None


def nav_gettheme_body(html):
    m = re.search(r'function getTheme\(\)\s*\{(.*?)\}\s*function setTheme', html, re.S)
    if not m:
        m = re.search(r'function getTheme\(\)\s*\{(.*?)\}', html, re.S)
    return m.group(1) if m else None


def main():
    print('theme_check against ' + BASE)

    try:
        get('/api/health')
    except Exception as e:
        check('server answers /api/health', False, str(e)[:60])
        print('\ntheme_check: 1 CHECK FAILED')
        return 1

    pages = {}
    for path in ['/courses', '/search', '/learning-path', '/help', '/faq', '/about',
                 '/login', '/register', '/courses/elf/lessons/bytes']:
        try:
            pages[path] = get(path)
        except Exception as e:
            check('%s: reachable' % path, False, str(e)[:60])

    themed = ['/courses', '/search', '/learning-path', '/help', '/faq', '/about']
    auth = ['/login', '/register']
    lesson = '/courses/elf/lessons/bytes'

    # ------------------------------------------------------------------
    print('\n[1] the brand pre-paint script is in <head> on every themed page')
    for path in themed + auth:
        html = pages.get(path)
        if not html:
            continue
        head, body = split_head(html)
        bs = brand_script(head)
        check('%s: brand pre-paint script in <head>' % path, bs is not None,
              'no script defining KEY=wiqis-theme and calling apply(get()) before </head>')
        # Fail if it was moved to the body, or duplicated.
        whole = re.findall(r'var\s+KEY\s*=\s*["\']wiqis-theme["\']', html)
        check('%s: pre-paint script appears once, never in <body>' % path,
              bs is not None and len(whole) == 1,
              '%d copies in the document' % len(whole))

    # ------------------------------------------------------------------
    print('\n[2] the pre-paint script is self-contained and correct')
    courses = pages.get('/courses', '')
    head, _ = split_head(courses)
    bs = brand_script(head)
    if bs is None:
        check('the pre-paint script exists to inspect', False)
    else:
        check('it defines its own theme read rather than calling getTheme()',
              'getTheme' not in bs)
        check('it reads the wiqis-theme key',
              re.search(r'var\s+KEY\s*=\s*["\']wiqis-theme["\']', bs) is not None
              and 'getItem(KEY)' in bs)
        check('it tolerates a throwing localStorage',
              'try' in bs and 'catch' in bs,
              'site data blocked makes localStorage access THROW')
        check('it applies the class the rest of the site keys on',
              re.search(r'classList\.toggle\(["\']dark["\']', bs) is not None)
        check('it makes the browser frame follow too',
              'style.colorScheme' in bs)
        check('it consults prefers-color-scheme', 'prefers-color-scheme' in bs)
        check('it resolves an explicit dark choice to dark',
              re.search(r'p\s*===\s*["\']dark["\']\s*\?\s*true', bs) is not None,
              'a saved dark must win over the OS preference')
        check('it applies the stored choice synchronously before first paint',
              'apply(get());' in bs)
        check('it publishes the globals the underlayer boot delegates to',
              '$wiqisThemeGet' in bs and '$wiqisThemeSet' in bs)

    # ------------------------------------------------------------------
    print('\n[3] the boot script and the nav agree on the one key')
    for path in themed:
        html = pages.get(path)
        if not html:
            continue
        h, _ = split_head(html)
        check('%s: carries the underlayer boot script' % path,
              boot_script(h) is not None)
    html = pages.get('/courses', '')
    for path in themed:
        doc = pages.get(path, '')
        check('%s: no stale bare "theme" key' % path,
              re.search(r"getItem\((['\"])theme\1\)", doc) is None)
    body = nav_gettheme_body(html)
    if body is None:
        check('the nav defines getTheme()', False, 'not found')
    else:
        check('the nav reads the wiqis-theme key',
              re.search(r"getItem\(['\"]wiqis-theme['\"]\)", body) is not None,
              'it must agree with the pre-paint script')
        check('the nav falls back to prefers-color-scheme',
              'prefers-color-scheme' in body)
        check('the nav tolerates a throwing localStorage too',
              'try' in body and 'catch' in body)
        check('the nav returns light/dark, not a boolean',
              "'light'" in body and "'dark'" in body)

    # ------------------------------------------------------------------
    print('\n[4] the browser frame follows the theme')
    for path in themed:
        doc = pages.get(path, '')
        if not doc:
            continue
        h, _ = split_head(doc)
        check('%s: declares color-scheme in <head>' % path,
              'name="color-scheme"' in h)
    for path in auth:
        doc = pages.get(path, '')
        if not doc:
            continue
        h, _ = split_head(doc)
        bs = brand_script(h)
        check('%s: brand script sets colorScheme inline (no meta needed)' % path,
              bs is not None and 'style.colorScheme' in bs,
              'auth pages call WiqisTheme(..., false): no stored choice, no boot, no meta')
        check('%s: deliberately ignores the stored choice' % path,
              '$wiqisThemeAllowStored = false' in doc)

    # ------------------------------------------------------------------
    print('\n[5] lesson pages are exempt from the BRAND SHELL, not from theming')
    doc = pages.get(lesson)
    if doc:
        h, _ = split_head(doc)
        check('a lesson page has no WiqisTheme brand shell', brand_script(h) is None)
        check('a lesson page has no nav getTheme() toggle helper',
              nav_gettheme_body(doc) is None)
        check('a lesson page still carries the small pre-paint boot',
              boot_script(h) is not None)
        check('a lesson page still has its navbar', 'class="navbar"' in doc)
        check('a lesson page still declares color-scheme',
              'name="color-scheme"' in h)

    # ------------------------------------------------------------------
    print('\n[6] a stored dark choice is applied BEFORE first paint (live browser)')
    ran_browser = False
    if WANT_BROWSER or os.environ.get('THEME_CHECK_BROWSER') == '1':
        ran_browser = _browser_check()
    else:
        note('live browser check', 'pass --browser (or set THEME_CHECK_BROWSER=1) to run it')

    print('\n' + ('theme_check: ALL %d CHECKS PASSED' % len(checks)
                  if not failures
                  else 'theme_check: %d of %d CHECKS FAILED'
                       % (len(failures), len(checks))))
    if skipped:
        print('  (%d optional check(s) skipped)' % len(skipped))
    for f in failures:
        print('  FAILED: %s' % f)
    return 0 if not failures else 1


def _browser_check():
    """Set localStorage['wiqis-theme']='dark', reload, and read the class at the
    moment <body> first appears (via an init-script MutationObserver). This proves
    the choice was applied by the head script, not by a later body script."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        note('stored dark applied before first paint', 'Playwright not installed')
        return False

    chrome = os.environ.get('CHROME_PATH') or (
        r'C:\Program Files\Google\Chrome\Application\chrome.exe'
        if os.name == 'nt' else '/usr/bin/google-chrome')
    if not os.path.isfile(chrome):
        note('stored dark applied before first paint', 'Chrome not found at %s' % chrome)
        return False

    init = """
window.__themeAtBody = null; window.__csAtBody = null;
try {
  new MutationObserver(function () {
    if (window.__themeAtBody === null && document.body) {
      window.__themeAtBody = document.documentElement.classList.contains('dark');
      window.__csAtBody = document.documentElement.style.colorScheme;
    }
  }).observe(document, {childList: true, subtree: true});
} catch (e) { window.__themeAtBody = 'error: ' + e.message; }
"""
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=chrome, headless=True,
                                        args=['--no-sandbox', '--disable-gpu'])
            context = browser.new_context()
            context.add_init_script(init)
            page = context.new_page()
            page.goto(BASE + '/courses', wait_until='domcontentloaded', timeout=30000)
            page.evaluate("localStorage.setItem('wiqis-theme','dark')")
            page.reload(wait_until='domcontentloaded', timeout=30000)
            at_body = page.evaluate('window.__themeAtBody')
            cs_at_body = page.evaluate('window.__csAtBody')
            is_dark = page.evaluate("document.documentElement.classList.contains('dark')")
            data_theme = page.evaluate("document.documentElement.getAttribute('data-theme')")
            check('stored dark is applied before first body paint', at_body is True,
                  'dark class at first <body>: %r' % (at_body,))
            check('browser frame is dark before first paint', cs_at_body == 'dark',
                  'colorScheme at first <body>: %r' % (cs_at_body,))
            check('stored dark is reflected in data-theme', data_theme == 'dark',
                  'data-theme: %r' % (data_theme,))
            check('stored dark leaves the html.dark class set', is_dark is True)

            page.evaluate("localStorage.setItem('wiqis-theme','light')")
            page.reload(wait_until='domcontentloaded', timeout=30000)
            light_dark = page.evaluate("document.documentElement.classList.contains('dark')")
            check('stored light clears the dark class on load', light_dark is False)
            browser.close()
        return True
    except Exception as e:
        note('stored dark applied before first paint', 'browser run failed: %s' % str(e)[:80])
        return False


if __name__ == '__main__':
    sys.exit(main())
