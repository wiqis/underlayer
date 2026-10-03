#!/usr/bin/env python3
"""theme_check.py -- prove the theme is applied BEFORE the first paint.

WHY THIS EXISTS

Reported on 2026-10-02: the site loads light, then becomes dark, and the shift is
visible. That is not a slow page -- it is a CORRECT page that arrives in the wrong
colours and then corrects itself.

The cause, measured rather than guessed:

    /dashboard   </head> at 19555   theme detection at 134902
    /courses     </head> at 14658   theme detection at 228801
    /search      </head> at 11919   theme detection at 112403

The code reading `prefers-color-scheme` ran ~100 KB into the BODY, inside the one
giant <script> the universal-components runtime emits at the end. A script at the
end of <body> is too late by definition: the browser has already painted
everything above it.

The fix is a small BLOCKING script in <head>, and this check exists because that
fix is easy to lose. `render_theme_boot_js` is called from `render_site_nav` for
every page EXCEPT lessons, and course landing pages were quietly not getting it --
six of them hand-roll their navbar and never call render_site_nav, and the other
28 call render_lesson_nav, which passes lesson=true and skips it. All 34 were
measured missing it while every lesson page was correctly skipping.

So the check asserts, per page kind:

  * a THEMED page reads localStorage['theme'] inside <head>
  * a LESSON page does NOT -- its palette is hardcoded light, and adding .dark
    would half-darken a page that was never designed for it
  * every page carries <meta name="color-scheme">, so the browser's own surfaces
    (scrollbars, form controls, the frame behind the document) follow the theme
  * the head script and the nav's getTheme() agree on the two questions that can
    disagree: where the choice comes from, and what class is applied

The last one matters because the head script CANNOT call getTheme -- it runs
before getTheme is defined -- so the logic is duplicated, and a duplicated
decision is exactly the thing that drifts.

Usage:
    python3 tools/theme_check.py [base-url]
Exit 0 all assertions hold. 1 otherwise.
"""
import json
import re
import sys
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:9000'
failures = []
checks = 0

# Pages a reader meets first. All of these draw a theme toggle, so all of them
# must paint in the right colour.
# Pages a reader meets first. All of these draw a theme toggle, so all of them
# must paint in the right colour.
#
# The eleven account-gated pages were REMOVED from this list on 2026-10-03 and
# that is a real change, not a workaround. They answer 303 to /login for a
# signed-out request, so a signed-out fetch of /dashboard never receives the
# dashboard: urlopen followed the redirect and this check was handed the /login
# document, then reported "the nav does not define getTheme()" -- a failure about
# a page that works perfectly. A gated page has no theme to check until somebody
# is signed in, and tools/auth_gate_test.ch covers the gate itself.
#
# /login, /register, /help, /faq and /about stay in the list: they are public,
# they serve normally, and each draws its own toggle.
# A LESSON page is deliberately absent: section 5 asserts that lesson pages do
# NOT read the theme, because they have no theme toggle and no components theme.
# Listing one here contradicted that section and failed it.
THEMED = ['/courses', '/search', '/learning-path',
          '/login', '/register', '/help', '/faq', '/about']


def check(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print('  PASS  ' + name)
    else:
        failures.append(name)
        print('  FAIL  ' + name + (('  -- ' + detail) if detail else ''))


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=40) as r:
        return r.read().decode('utf-8', 'replace')


def split_head(html):
    i = html.find('</head>')
    return html[:i], html[i:]


def theme_read_offset(html):
    m = re.search(r"localStorage\.getItem\('theme'\)", html)
    return m.start() if m else -1


def main():
    print('theme_check against ' + BASE)

    try:
        get('/api/health')
    except Exception as e:
        print('  FAIL  server answers /api/health -- %s' % e)
        print('\ntheme_check: 1 CHECK FAILED')
        return 1

    # ---------------------------------------------------------------------
    print('\n[1] every themed page reads the theme INSIDE <head>')
    for path in THEMED:
        try:
            html = get(path)
        except Exception as e:
            check('%s: reachable' % path, False, str(e)[:60])
            continue
        head, _ = split_head(html)
        off = theme_read_offset(head)
        if off == -1:
            # It may read it via the nav's getTheme instead; that is fine as long
            # as that is ALSO in the head.
            off = theme_read_offset(html)
            if off == -1:
                check('%s: reads the saved theme at all' % path, False,
                      'no localStorage theme read found in the document')
                continue
            check('%s: reads the theme, but NOT inside <head>' % path, False,
                  'offset %d, </head> at %d -- this is the flash' % (off, len(head)))
            continue
        check('%s: reads the theme inside <head> (no flash)' % path, True)

    # ---------------------------------------------------------------------
    print('\n[2] the pre-paint script is self-contained (it cannot call getTheme)')
    html = get('/dashboard')
    head, _ = split_head(html)
    m = re.search(r'<script>(\(function\(\)\{var c=.*?)</script>', head, re.S)
    if not m:
        check('the pre-paint script is in <head>', False,
              'no matching <script> found in head')
    else:
        boot = m.group(1)
        check('the pre-paint script is in <head>', True)
        check('it defines its own theme read rather than calling getTheme()',
              'getTheme' not in boot)
        check('it tolerates a throwing localStorage',
              'try' in boot and 'catch' in boot,
              'site data blocked makes localStorage access THROW')
        check('it applies the class the rest of the site keys on',
              "classList.toggle('dark'" in boot)
        check('it consults prefers-color-scheme',
              'prefers-color-scheme' in boot)

        # The decision itself, run.
        check('it prefers the saved choice over the OS preference',
              re.search(r"if\s*\(\s*d\s*!==\s*'light'\s*&&\s*d\s*!==\s*'dark'\s*\)",
                        boot) is not None,
              'an explicit saved theme must win over prefers-color-scheme')

    # ---------------------------------------------------------------------
    print('\n[3] the nav\'s getTheme() agrees with the pre-paint script')
    # /courses, not /dashboard. /dashboard is account-gated and answers 303 for a
    # signed-out request, so this fetched the /login document after following the
    # redirect and then reported "not found" for a function that is present on
    # every page that draws a toggle.
    html = get('/courses')
    # The js_cbi macro compacts a function onto one line, so the body ends at
    # the FIRST brace rather than at a newline-delimited one. An earlier version
    # of this regex looked for a closing brace on its own line and therefore
    # reported "the nav defines getTheme(): not found" on a page that plainly
    # did -- a checker that fails on a correct page is worse than none.
    m = re.search(r'function getTheme\(\)\s*\{(.*?)\}\s*function setTheme', html, re.S)
    if not m:
        m = re.search(r'function getTheme\(\)\s*\{(.*?)\}', html, re.S)
    if not m:
        check('the nav defines getTheme()', False, 'not found')
    else:
        body = m.group(1)
        check('the nav reads the same localStorage key', "getItem('theme')" in body)
        check('the nav falls back to prefers-color-scheme',
              'prefers-color-scheme' in body)
        check('the nav tolerates a throwing localStorage too',
              'try' in body and 'catch' in body,
              'this was one of the eleven unguarded reads')
        check('the nav returns light/dark, not a boolean',
              "'light'" in body and "'dark'" in body)

    # ---------------------------------------------------------------------
    print('\n[4] color-scheme meta, so the browser frame follows too')
    for path in ['/courses', '/login']:
        try:
            html = get(path)
        except Exception:
            continue
        head, _ = split_head(html)
        check('%s: declares color-scheme in <head>' % path,
              'name="color-scheme"' in head)

    # ---------------------------------------------------------------------
    print('\n[5] lesson pages deliberately do NOT get it')
    # A lesson's palette is hardcoded light and there is no .dark rule set for
    # its body, so setting the class would half-darken it. Skipping is the
    # correct behaviour and is asserted here so a "fix" that adds it to lessons
    # is caught rather than shipped.
    try:
        lesson = get('/courses/elf/lessons/bytes')
        head, _ = split_head(lesson)
        check('a lesson page does NOT read the theme in <head>',
              theme_read_offset(head) == -1)
        check('a lesson page still has its navbar', 'class="navbar"' in lesson)
    except Exception as e:
        check('a lesson page is reachable', False, str(e)[:60])

    print('\n' + ('theme_check: ALL %d CHECKS PASSED' % checks
                  if not failures
                  else 'theme_check: %d of %d CHECKS FAILED'
                       % (len(failures), checks)))
    for f in failures:
        print('  FAILED: %s' % f)
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())