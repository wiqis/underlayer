#!/usr/bin/env python3
"""nav_consolidate.py -- replace hand-copied navs with the ONE shared nav.

WHY THIS EXISTS.  Thirteen web/ pages each carried their own copy of the
navbar markup, their own copy of the navbar CSS and their own copy of the
theme script.  The copies had drifted: eleven of them had no /search link at
all, and /settings -- a page a learner reaches from the dashboard -- had no
navbar and no link home, so a learner who landed there had nothing to click.
The 398 lesson pages and /courses already call render_nav_bar, which delegates
to content/src/lesson_nav.ch.  This makes the web/ pages call it too, so the
nav is defined once.

WHAT IT EDITS, PER FILE.
  * the skip-link + `<div class="navbar">...</div>` markup  -> `{render_nav_bar(&mut page)}`
  * the CSS lines that only style the nav                  -> deleted (the shared
    component emits a complete nav stylesheet, --nav-* tokens and all)
  * the page's own getTheme/setTheme/toggleTheme           -> deleted (the shared
    nav emits its own; two declarations of `function getTheme` on one page is a
    JavaScript redeclaration error that would kill the page's script)

WHAT IT REFUSES TO DO.  It does not touch a file that already calls
render_nav_bar.  It does not touch a page that has no navbar at all -- adding a
nav to /login, /register, /terms or /privacy is a design decision, not a
defect fix, and those pages already carry a link home.

Usage:
    python3 tools/nav_consolidate.py --check     # report, exit 1 if work remains
    python3 tools/nav_consolidate.py --apply
"""
import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TARGETS = [
    'web/src/pages_analytics.ch',
    'web/src/pages_study_plans.ch',
    'web/src/pages_notes.ch',
    'web/src/handlers_home.ch',
    'web/src/pages_notifications.ch',
    'web/src/handlers_review_page.ch',
    'web/src/pages_bookmarks.ch',
    'web/src/pages_streaks.ch',
    'web/src/handlers_progress_page.ch',
    'web/src/pages_achievements.ch',
    'web/src/handlers_dashboard.ch',
    'web/src/pages_certificates.ch',
    'web/src/pages_learning_path.ch',
]

# CSS selectors that are purely the nav's.  A line is dropped only if every
# rule on it names one of these.  Anything mentioning .container, .page-header,
# .btn, .card and friends stays.
NAV_SELECTORS = [
    'skip-link', 'navbar', 'nav-inner', 'nav-brand', 'nav-links', 'nav-link',
    'nav-right', 'theme-toggle', 'theme-icon-light', 'theme-icon-dark',
    'hamburger', 'hamburger-line',
]


def strip_nav_markup(lines, path):
    """Replace the skip-link + navbar block with the shared call. Returns (lines, n)."""
    out = []
    i = 0
    n = 0
    while i < len(lines):
        line = lines[i]
        if re.search(r'<a href="#main-content" class="skip-link"', line) and \
                any('class="navbar"' in lines[j] for j in range(i, min(i + 4, len(lines)))):
            # consume the skip-link line, then the whole navbar element
            j = i + 1
            while j < len(lines) and 'class="navbar"' not in lines[j]:
                j += 1
            if j >= len(lines):
                out.append(line)
                i += 1
                continue
            depth = 0
            started = False
            k = j
            while k < len(lines):
                # count <div and </div> on this line
                opens = len(re.findall(r'<div\b', lines[k]))
                closes = len(re.findall(r'</div>', lines[k]))
                depth += opens - closes
                if opens:
                    started = True
                k += 1
                if started and depth <= 0:
                    break
            indent = re.match(r'\s*', lines[j]).group(0)
            out.append('%s{render_nav_bar(&mut page)}' % indent)
            n += 1
            i = k
            continue
        out.append(line)
        i += 1
    return out, n


def css_line_is_nav(line):
    if '{' not in line:
        return False
    body = line[line.find('{'):]
    sels = body[:body.find('}')] if '}' in body else body
    parts = [p.strip() for p in sels.split(',')]
    if not parts:
        return False
    for p in parts:
        if not p:
            return False
        if not any(('.' + sel) in p for sel in NAV_SELECTORS):
            return False
    return True


def strip_nav_css(lines):
    out = []
    for line in lines:
        if css_line_is_nav(line):
            continue
        # .nav-links { ... } buried inside a @media line
        if '.nav-links' in line and '.container' not in line and '.page-header' not in line:
            continue
        out.append(line)
    return out


THEME_FN = re.compile(r'function\s+(getTheme|setTheme|toggleTheme)\s*\(')
THEME_CALL = re.compile(r'^\s*setTheme\(getTheme\(\)\);?\s*$')


def strip_theme_js(lines):
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if THEME_FN.search(line):
            depth = 0
            j = i
            while j < len(lines):
                depth += lines[j].count('{') - lines[j].count('}')
                j += 1
                if depth <= 0:
                    break
            i = j
            continue
        if THEME_CALL.match(line):
            i += 1
            continue
        out.append(line)
        i += 1
    return out


def process(path, apply):
    full = os.path.join(REPO, path)
    raw = open(full, newline='').read()
    crlf = '\r\n' in raw
    src = raw.replace('\r\n', '\n')
    if 'render_nav_bar' in src:
        return None
    lines = src.split('\n')
    lines, navs = strip_nav_markup(lines, path)
    if navs == 0:
        return None
    lines = strip_nav_css(lines)
    lines = strip_theme_js(lines)
    new = '\n'.join(lines)
    if not apply:
        return (path, navs, new)
    if crlf:
        new = new.replace('\n', '\r\n')
    open(full, 'w', newline='').write(new)
    return (path, navs, new)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    if not (args.check or args.apply):
        ap.error('pass --check or --apply')

    pending = []
    for path in TARGETS:
        r = process(path, args.apply)
        if r:
            pending.append(r)
    if not pending:
        print('nav_consolidate: nothing to do -- every target already calls render_nav_bar')
        return 0
    for path, navs, _ in pending:
        print('  %-40s %d hand-copied nav(s) %s'
              % (path, navs, 'REPLACED' if args.apply else 'WOULD REPLACE'))
    if args.check:
        print('nav_consolidate: %d file(s) still hand-copy the nav' % len(pending))
        return 1
    print('nav_consolidate: %d file(s) now call render_nav_bar' % len(pending))
    return 0


if __name__ == '__main__':
    sys.exit(main())