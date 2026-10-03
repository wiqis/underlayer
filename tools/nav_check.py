#!/usr/bin/env python3
"""nav_check.py -- every page in the baseline must serve a nav that goes somewhere.

WHY THIS EXISTS, in the shape of the defect it exists for.

398 lesson pages had no navbar at all.  A learner deep inside `a64-pagetables`
had exactly one way out: an "All courses" link at the top of the page, which
they had already scrolled past.  There was no nav, no search, no route onward,
and nothing in the build, in the compiler, or in tools/link_check.py said so --
because a page with NO nav raises no link error.  The original /courses defect
was the mirror image: a nav that rendered and pointed nowhere.  Both are
invisible to a checker that only asks "does this href resolve".

So this asks a different question of the same 432 URLs: not "is every link on
the page alive" but "does the page HAVE a nav, and does that nav offer a way
out of the lesson".  Three assertions, all of them falsifiable:

  1. every URL returns 200;
  2. every URL's body contains a nav -- `class="navbar"` -- and not two of
     them, because two navbars is the same defect wearing a different hat;
  3. that nav carries the four routes that make a lesson page navigable:
     `/courses`, `/search`, `/dashboard`, `/progress`.  A nav of two links is
     technically a nav and is still a trap.

IT IS NOT A SUBSTITUTE FOR link_check.py.  That one reads the SOURCE and proves
every internal href in the repository resolves before the page ships.  This one
reads the SERVED page and proves the nav is on it, because the served page is
where the defect was and it is the only place the two can differ: a component
that renders nothing is a component with no hrefs to check.

WHAT IT DELIBERATELY DOES NOT DO.

  * It does not accept a nav that is present but empty.  An empty
    `<div class="navbar"></div>` passes assertion 2 and fails assertion 3.
  * It does not count links in the whole body.  Only the nav region between
    `<div class="navbar">` and its matching close is searched, so a page whose
    lesson body happens to link to /dashboard cannot pass by accident.
  * It does not guess about a down server.  It says so and exits 2, because a
    checker that reports a stopped server as 400 broken pages is a checker
    nobody trusts.

HOW TO PROVE IT IS NOT VACUOUS
------------------------------
`--expect-nav 0` turns the assertion off, which is how the negative control is
run: point it at the same 432 URLs with the requirement relaxed and it exits 0
having proved it can pass.  Point it at a URL that has no nav with the
requirement on and it exits 1 and NAMES the page.  `--url` takes a single URL
so that control costs one command.

Usage:
    python3 tools/nav_check.py                      # all of baseline_urls.txt
    python3 tools/nav_check.py --url /courses/elf/lessons/bytes
    python3 tools/nav_check.py --port 8080
    python3 tools/nav_check.py --quiet

Exit: 0 every page 200 with a usable nav.  1 at least one page without one.
      2 the server is not reachable (NOT a pass).
"""
import argparse
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError, URLError
from urllib.request import urlopen, build_opener, HTTPRedirectHandler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, 'tools', 'baseline_urls.txt')

# The nav element itself.  Matched with the exact class attribute the component
# writes, so a page cannot pass on some other element that happens to be called
# a navbar.
NAVBAR = re.compile(r'<div class="navbar">')

# The routes a lesson page needs to be navigable rather than a dead end.  These
# are the same hrefs web/src/nav_bar.ch -> content/src/lesson_nav.ch emits, so
# this list is a second, independent statement of that requirement: change the
# component and this check fails, which is the point.
REQUIRED = ('/courses', '/search', '/dashboard', '/progress')

# How far past `<div class="navbar">` the nav region may extend.  A nav is a
# few hundred characters of markup; 20000 is far more than any nav here and far
# less than a whole lesson body, so a lesson that links to /dashboard in its
# prose cannot put the requirement out of reach.
NAV_WINDOW = 20000


def urls(args):
    if args.url:
        return list(args.url)
    if not os.path.exists(BASELINE):
        print('missing %s -- the list of pages that must have a nav.' % BASELINE)
        sys.exit(2)
    with open(BASELINE, encoding='utf-8') as fh:
        return [ln.strip() for ln in fh if ln.strip() and not ln.startswith('#')]


def nav_region(body):
    """The markup inside the FIRST navbar, or '' when there is no navbar.

    Deliberately not a tag stack: the nav is a fixed, known shape (a nav-inner
    holding a brand, a link row and a right slot) and the assertion below is
    about which links it holds, not about how it is nested.  A stack parser
    here would be a second thing that can be wrong about a page nobody is
    looking at.
    """
    m = NAVBAR.search(body)
    if m is None:
        return ''
    return body[m.start():m.start() + NAV_WINDOW]


class NoRedirect(HTTPRedirectHandler):
    """Refuse to follow a 3xx, so `probe` sees the status the server sent.

    urllib follows redirects by default. That is right for a browser and wrong
    for this checker: eleven account-gated pages answer 303 to /login, and
    following it handed `probe` the /login document, so it reported "no navbar
    in the served page" for URLs that are working exactly as intended.
    """

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def probe(base, url, expect_nav):
    full = base + url
    # The eleven account-gated pages answer 303 to /login for a signed-out
    # request (web/src/pages_auth_gate.ch, changed 2026-10-03). urlopen FOLLOWS
    # redirects by default, so this function used to receive the /login document
    # and report "no navbar in the served page" for eleven URLs that are working
    # exactly as intended -- the reader never receives those pages at all.
    #
    # So redirects are NOT followed here. A gated page is verified by its status
    # and its Location, which is the assertion that matters; the nav assertion
    # applies to the pages that actually serve a page.
    opener = build_opener(NoRedirect)
    try:
        with opener.open(full, timeout=30) as resp:
            status, body = resp.status, resp.read().decode('utf-8', 'replace')
            location = resp.headers.get('Location', '')
    except HTTPError as exc:
        # A 3xx arrives as an HTTPError once the redirect is not followed.
        if exc.code in (301, 302, 303, 307, 308):
            return url, exc.code, [], '', exc.headers.get('Location', '')
        return url, exc.code, [], 'HTTP %d' % exc.code, ''
    except URLError as exc:
        return url, 0, [], str(exc.reason), ''
    except Exception as exc:                              # noqa: BLE001
        return url, 0, [], str(exc), ''

    if status in (301, 302, 303, 307, 308):
        return url, status, [], '', location
    if status != 200:
        return url, status, [], 'HTTP %d' % status, ''

    navs = len(NAVBAR.findall(body))
    region = nav_region(body)
    if expect_nav:
        if navs == 0:
            return url, status, [], 'no navbar in the served page', ''
        if navs > 1:
            return url, status, [], '%d navbars; exactly one is the point' % navs, ''
        missing = [r for r in REQUIRED if r not in region]
        if missing:
            return url, status, [], ('nav is missing %s' % ', '.join(missing)), ''
    return url, status, navs, '', ''


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default=None)
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--workers', type=int, default=12)
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--url', action='append',
                    help='check this URL instead of the baseline list')
    ap.add_argument('--expect-nav', type=int, default=1, choices=(0, 1),
                    help='0 relaxes the assertion; this is how the negative '
                         'control is run and it must be able to pass')
    args = ap.parse_args()

    base = (args.base or 'http://localhost:%d' % args.port).rstrip('/')
    targets = urls(args)

    try:
        with urlopen(base + '/api/health', timeout=10) as resp:
            health = resp.status
    except Exception as exc:                              # noqa: BLE001
        print('CANNOT REACH %s/api/health (%s)' % (base, exc))
        print('Start the server first.  A checker pointed at a server that is')
        print('not running reports every page broken, which is a lie.')
        return 2
    if health != 200:
        print('SERVER UNHEALTHY: /api/health returned %d' % health)
        return 2

    expect = bool(args.expect_nav)
    if not args.quiet:
        print('nav_check: %d URLs against %s, nav required: %s'
              % (len(targets), base, 'yes' if expect else 'NO (negative control)'))

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda u: probe(base, u, expect), targets))

    # Redirects are verified, not skipped. A gated page that answered 200 with a
    # page of zeroes would be the exact regression this repo has already shipped
    # once, so "it redirects to /login and names its own path" is asserted here
    # rather than assumed.
    redirects = [(u, _s, loc) for u, _s, _n, _w, loc in results if _s in (301, 302, 303, 307, 308)]
    bad_redirects = []
    for url, _status, loc in redirects:
        if not loc.startswith('/login?next='):
            bad_redirects.append((url, 'redirects to %r, not to /login?next=...' % loc))
        elif loc.split('next=', 1)[1] != url:
            bad_redirects.append((url, 'next=%r does not carry the original path' % loc))

    bad = [(u, why) for u, _s, _n, why, _loc in results if why]
    nav_counts = {}
    for _u, _s, navs, _why, _loc in results:
        if _s in (301, 302, 303, 307, 308):
            continue
        key = navs if navs else 0
        nav_counts[key] = nav_counts.get(key, 0) + 1

    for url, why in bad[:40]:
        print('  NO NAV  %-46s %s' % (url, why))
    if len(bad) > 40:
        print('  ... and %d more' % (len(bad) - 40))
    for url, why in bad_redirects[:20]:
        print('  BAD 303 %-45s %s' % (url, why))

    if not args.quiet:
        for navs in sorted(nav_counts):
            label = ('%d navbar' % navs) if navs else 'no navbar (not required)'
            print('  %-24s %d page(s)' % (label, nav_counts[navs]))
        if redirects:
            print('  %-24s %d page(s)  (gated: 303 -> /login?next=)'
                  % ('redirected', len(redirects)))

    total_bad = len(bad) + len(bad_redirects)
    if total_bad:
        print('\nFAIL: %d of %d pages do not serve a usable nav.'
              % (total_bad, len(targets)))
        return 1

    print('\nALL CONSISTENT: %d pages, %s'
          % (len(targets),
             ('%d with HTTP 200 and one nav carrying %s; %d gated with a 303 to '
              '/login?next= carrying their own path.'
              % (len(targets) - len(redirects), ', '.join(REQUIRED), len(redirects)))
             if expect else 'nav presence NOT required (negative control).'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
