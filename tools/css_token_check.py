#!/usr/bin/env python3
"""css_token_check.py -- no `var()` in the product may rely on a fallback.

THE BUG, reproduced not guessed
-------------------------------
css_cbi SILENTLY DROPS the second argument of `var()`.  Verified on served
HTML: a rule authored as

    .ul-advisory-text { color: var(--muted-foreground, hsl(var(--nav-muted))); }

emits as

    .ul-advisory-text { color: var(--muted-foreground); }

The compiler is not silent about this in the repository: the bug is written
down at length in content/src/lesson_nav.ch, lesson_nav_css.ch,
lesson_tools_css.ch and lesson_engagement_css.ch, all of which work around it
by declaring their own `--nav-*` tokens instead of falling back.  Five sites
had it anyway.  `signin_advisory.ch` was the one that shipped broken: only 7 of
the 466 page builders call `injectDefaultComponentsTheme()`, so on all 398
lesson pages `--muted-foreground` was undefined and the advisory inherited the
body colour instead of the muted grey it was written to be.

WHY A CHECKER AND NOT A COMMENT
------------------------------
Because the workaround is invisible once it is written.  A future edit that
writes `var(--x, y)` again compiles, serves, renders at 200, and is wrong on
exactly the pages nobody opened.  Five occurrences is not a one-off; it is a
pattern, and the pattern outlives every individual fix.

WHAT IT CHECKS, AND WHY IT READS BOTH WAYS
------------------------------------------
Source and served output, because they fail differently:

  * source: a `var(--x, y)` inside a `#css { }` block.  Cheap, catches the
    mistake before it ships.
  * served: a `var(--x)` whose `--x` is never assigned on that page.  This is
    the check that would have caught the shipped bug even if the source had
    been rewritten into some other wrong-but-plausible form -- and it catches
    the reverse mistake too, a rule referencing a token the page never defines.

A rule is exempt when the page defines the token, or when the token is a
shadcn theme token on a page that calls `injectDefaultComponentsTheme()`.  A
lesson page defines no theme tokens, so it is held to a stricter bar than a
collection page -- which is the correct asymmetry, because a lesson page is
where the fallback was load-bearing and absent.

USAGE
-----
    python3 tools/css_token_check.py                 # source + a running server
    python3 tools/css_token_check.py --source-only
    python3 tools/css_token_check.py --port 8080

Exit: 0 clean.  1 at least one finding.  2 the server is not reachable
(NOT a pass -- same rule as every other checker in this repository).
"""
import argparse
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Directories whose `#css` blocks become served CSS.
CSS_DIRS = ('content/src', 'web/src')

# Pages that get the shadcn token set from `injectDefaultComponentsTheme()`.
# A `var(--x)` on one of these may legitimately reference a theme token.
THEME_TOKEN = re.compile(
    r'--(background|foreground|card|card-foreground|popover|popover-foreground|'
    r'primary|primary-foreground|secondary|secondary-foreground|muted|'
    r'muted-foreground|accent|accent-foreground|destructive|'
    r'destructive-foreground|success|success-foreground|warning|'
    r'warning-foreground|info|info-foreground|border|input|ring)\s*:')

# Tokens this product declares itself, on :root or .dark, in the nav component.
OWN_TOKEN = re.compile(r'--(nav-[a-z-]+|accent-strong|ring|shadow)\s*:')

checks = 0
failures = []


def ok(name, cond, detail=''):
    global checks
    checks += 1
    if cond:
        print(f'  PASS  {name}')
    else:
        print(f'  FAIL  {name}' + (f'  -- {detail}' if detail else ''))
        failures.append(name)


def sec(title):
    print()
    print('=' * 74)
    print(title)
    print('=' * 74)


def strip_comments(text):
    """Drop comments so a bug described in a comment is not a finding.

    Both styles, because `#css { }` blocks in this repository carry both: `/* */`
    inside the CSS proper and `//` between rules, which css_cbi accepts and
    strips.  The reason it matters here is that the fix for this very bug is to
    write down which token was wrong and what it was, and that write-down names
    the broken `var(--x, y)` form verbatim -- so a checker that read comments
    would report the explanation as the defect, forever.
    """
    text = re.sub(r'/\*[\s\S]*?\*/', '', text)
    return re.sub(r'(?m)//.*$', '', text)


def css_blocks(src):
    """Yield (start_line, body) for each `#css { ... }` block."""
    for m in re.finditer(r'#css\s*\{', src):
        start = src.count('\n', 0, m.end()) + 1
        depth = 1
        i = m.end()
        while i < len(src) and depth:
            if src[i] == '{':
                depth += 1
            elif src[i] == '}':
                depth -= 1
            i += 1
        yield start, src[m.end():i - 1]


def check_source():
    sec('1. no `var()` in any #css block may carry a fallback argument')
    hits = []
    for rel in CSS_DIRS:
        d = os.path.join(ROOT, rel)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith('.ch'):
                continue
            path = os.path.join(d, name)
            src = strip_comments(open(path, encoding='utf-8').read())
            for line_no, body in css_blocks(src):
                for m in re.finditer(r'var\(\s*(--[a-zA-Z0-9-]+)\s*,', body):
                    hits.append(f'{rel}/{name}:{line_no}  {m.group(1)}')
    ok(f'no var(--x, fallback) survives in {len(CSS_DIRS)} css source dirs',
       not hits, '; '.join(hits[:6]))
    return not hits


def fetch(path, port):
    url = f'http://localhost:{port}{path}'
    with urllib.request.urlopen(url, timeout=20) as r:
        return r.read().decode('utf-8', 'replace')


def served_reports(html):
    """Every (token, css_rule) where a `var(--x)` has no assignment in `html`."""
    css = ''.join(re.findall(r'<style[^>]*>([\s\S]*?)</style>', html))
    defined = set()
    for m in re.finditer(r'(--[a-zA-Z0-9-]+)\s*:', css):
        defined.add(m.group(1))
    # `--x: var(--y)` is a legal alias; treat the right-hand side as defined.
    out = []
    for m in re.finditer(r'(--[a-zA-Z0-9-]+)\s*:\s*var\(\s*(--[a-zA-Z0-9-]+)', css):
        defined.add(m.group(2))
    for m in re.finditer(r'\{([^{}]*)\}', css):
        body = m.group(1)
        for v in re.finditer(r'var\(\s*(--[a-zA-Z0-9-]+)\s*\)', body):
            if v.group(1) not in defined and not defined_on_page(css, v.group(1)):
                out.append(v.group(1))
    return out


# Tokens the COMPONENTS LIBRARY sets from JavaScript at runtime, so they are
# legitimately undefined in the static CSS of a page that never renders the
# matching component.  `--chx-collapsible-height` is assigned by the Collapsible
# widget when it opens (lang/libs/components/src/theme.ch:167 reads it; the
# setter is in the component's own #js).  A page that renders no Collapsible
# never assigns it, and no rule that reads it is reachable either.
#
# This list is deliberately tiny and every entry needs a reason.  A token added
# here to silence a finding is the same failure as the bug being checked for.
RUNTIME_TOKENS = {
    '--chx-collapsible-height': 'assigned by the components Collapsible widget at open time',
}


def defined_on_page(css, token):
    if token in RUNTIME_TOKENS:
        return True
    return re.search(re.escape(token) + r'\s*:', css) is not None


PAGES = [
    '/', '/courses', '/courses/elf', '/courses/elf/lessons/bytes',
    '/learning-path', '/search', '/notes', '/progress', '/dashboard',
    '/login', '/help', '/terms', '/streaks', '/bookmarks',
    '/courses/hat/lessons/hat-algebra',
    '/courses/wasm/lessons/wasm-leb128',
    '/courses/coff/lessons/coff-intro',
]


def check_served(port):
    sec(f'2. every var(--x) on a served page resolves to a token that page defines')
    unreachable = []
    pages = []
    for path in PAGES:
        try:
            pages.append((path, fetch(path, port)))
        except (urllib.error.URLError, OSError) as e:
            unreachable.append(f'{path} ({e})')
    if unreachable:
        print(f'  no server on {port}.  NOT a pass.')
        for u in unreachable[:4]:
            print(f'    {u}')
        return None

    bad = []
    for path, html in pages:
        for token in served_reports(html):
            bad.append(f'{path}  {token}')
    ok(f'all {len(pages)} sampled pages: every var(--x) is defined on that page',
       not bad, '; '.join(sorted(set(bad))[:8]))

    # The shipped bug, named, so a regression is recognisable rather than just
    # "something changed".
    lesson = dict(pages)['/courses/elf/lessons/bytes']
    ok('the sign-in advisory resolves its colour on a LESSON page',
       '--muted-foreground);' not in lesson
       and 'hsl(var(--nav-muted))' in lesson,
       'advisory still references an undefined theme token')
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--source-only', action='store_true')
    args = ap.parse_args()

    print('css_token_check: var() fallbacks are dropped by css_cbi')
    src_ok = check_source()
    srv_ok = True
    if not args.source_only:
        result = check_served(args.port)
        if result is None:
            print('\ncss_token_check: server not reachable (NOT a pass)')
            return 2
        srv_ok = result

    total = checks
    bad = total - (total - len(failures))
    print()
    print('=' * 74)
    if failures:
        print(f'css_token_check: {len(failures)} of {total} CHECKS FAILED')
        for f in failures:
            print(f'  FAILED: {f}')
        return 1
    print(f'css_token_check: ALL {total} CHECKS PASSED')
    return 0


if __name__ == '__main__':
    sys.exit(main())