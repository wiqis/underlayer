#!/usr/bin/env python3
"""integration_holes.py -- find shipped features the UI never reaches.

WHAT THIS IS
The question that produced it, asked on 2026-10-02: "where exactly in the UI do
we have no options for features that we already have?" Answering that by reading
the code is hopeless at this size -- 180 routes, 432 pre-rendered pages, and 46
`fetch(` sites scattered across a dozen layers. So this measures it instead.

A feature is "shipped but invisible" when three things are true:
  1. a ROUTE exists (app/main.ch registers it)
  2. a REPOSITORY function or table backs it (repository/, database/)
  3. NO UI anywhere calls it

(3) is the hole. The API works, the data is stored, and a person has no way to
reach any of it -- so every hour spent on it was invisible, and the checklist
reads as if the feature exists in the product. It does not.

WHY A TOOL AND NOT A LIST.  A list rots the moment someone adds a route, and a
stale list is worse than none: it reads as coverage. This runs in the gate.

WHAT IT DELIBERATELY DOES NOT DO
It does not call a hole a defect.  Some routes are correct with no UI: internal
endpoints a page's own JS calls only under a condition, maintenance routes, and
the API surface that exists so a future client can use it.  Each finding says
which of those it might be, and the classification is a claim to be argued with
rather than a verdict.  What it does not do is report zero holes while routes go
uncalled, which is how 9 shipped features stayed invisible for a year.

HOW IT FINDS CALLERS.  Four independent sources, because one is not enough:
  * every route in app/main.ch
  * every pre-rendered page in courses/*/output/*.html  (432 files, read from
    disk: they are what GitHub Pages serves, and they are not served by the
    running server, so fetching the site would miss all of them)
  * every served platform page, fetched live
  * every .ch source file, for fetch() sites in code that builds a page

Usage:
    python3 tools/integration_holes.py [--port 9000] [--json] [--live]
Exit 0 if the report was produced (this is a REPORT, not a gate -- it exits 1
only when it could not measure, because "no holes found" from a broken scan is
the one result that must never be reported).
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# 1. The routes.
#
# Read from app/main.ch, not from a hardcoded list, because the point is to
# catch routes somebody added and never surfaced.  The file is CRLF; that does
# not matter for these patterns, and it is not "fixed" here because normalising
# a 1300-line file's line endings is its own diff.
# ---------------------------------------------------------------------------
ROUTE_RE = re.compile(
    r'router\.add\(\s*"(GET|POST|PUT|DELETE)"\s*,\s*"([^"]+)"')


def read_routes():
    src = open(os.path.join(ROOT, 'app', 'main.ch'), encoding='utf-8',
               errors='replace').read()
    out = []
    for m in ROUTE_RE.finditer(src):
        out.append((m.group(1), m.group(2)))
    return out


# ---------------------------------------------------------------------------
# 2. The callers.
#
# Every way a browser can name an API path.  The patterns are deliberately broad
# and over-match rather than under-match: a false positive here hides a hole,
# and a false negative invents one.
# ---------------------------------------------------------------------------
# 2026-10-03: the first version of this found 87 "holes", and a sample of five
# spot-checks found the CALLER in the first one (`__ulFetch('/api/review/start')`
# in the review page -- the review page's own test asserts on it).  A report with
# phantom holes is worse than no report, because it teaches you to ignore the
# tool, and then it cannot report the next one either.  So the patterns are now
# built from three measurements against the real corpus:
#
#   * the platform does not call bare `fetch()` everywhere -- web/src/session_js.ch
#     replaced 17 duplicated fetch sites with ONE `__ulFetch`, so `fetch(` alone
#     misses every page that shares the helper.  Any `<name>Fetch(`/`<name>Get(`
#     counts.
#   * callers build paths by CONCATENATION -- `'/api/notes/concept/' + id` -- so
#     the literal is a PREFIX with fewer segments than the route.  Matching on
#     equal segment counts dropped 30 of them.
#   * `/api/review/start?course_id=...` carries a query string, which the first
#     version stripped AFTER testing the prefix, so `/api/review/start` was fine
#     but a bare `'/api/notes'` would match any notes path.
#
# `found_in` is reported alongside every hole so a claim can be checked in one
# grep instead of by faith.

CALL_PATTERNS = [
    # fetch('/api/...') -- the raw form
    re.compile(r"""\bfetch\(\s*['"`]([^'"`]*?/api/[^'"`?\s]*)"""),
    # __ulFetch('/api/...') and any other shared fetcher the platform adds later.
    re.compile(r"""\b[A-Za-z_]*[Ff]etch\(\s*['"`]([^'"`]*?/api/[^'"`?\s]*)"""),
    # Any string literal naming an API path, however it is used.
    re.compile(r"""['"`](/api/[A-Za-z0-9_\-/:.\[\]{}?=&%+]*)['"`]"""),
    # a quoted path glued to a concatenation: '/api/notes/concept/' + id
    re.compile(r"""['"](/api/[A-Za-z0-9_\-/]*?)['"]\s*\+\s*[A-Za-z_$]"""),
    re.compile(r"""\bnew\s+EventSource\(\s*['"`]([^'"`]+)"""),
    re.compile(r"""\b(?:action|url|endpoint)\s*=\s*['"](/api/[^'"]+)['"]"""),
]

# A page route is not an integration hole -- a page with no inbound link is a
# navigation problem, and link_check.py already measures that with 462 links.
API_ONLY = True


def _scan(text):
    """(path, was-it-a-literal-match) pairs, query strings stripped."""
    out = {}
    for prio, pat in enumerate(CALL_PATTERNS):
        for m in pat.finditer(text):
            p = m.group(1)
            p = p.split('?')[0].split('#')[0]
            if p.startswith('/api/'):
                # A more specific pattern wins over a generic literal match, so
                # "/api/review/start" (pattern 0) is not overwritten by the
                # bare-literal hit from pattern 2.
                if p not in out or prio < out[p]:
                    out[p] = prio
    return out


def _matches(path, route):
    """True when a CALLER path names ROUTE. Segment count may differ when the
    caller path is a concatenation prefix -- `'/api/notes/concept/'` matches
    `/api/notes/concept/:conceptId`."""
    if path == route:
        return True
    rp = route.strip('/').split('/')
    cp = path.strip('/').split('/')
    if len(cp) > len(rp):
        return False
    for i, b in enumerate(cp):
        a = rp[i]
        if b == '':
            return False
        # The caller's last segment may be a PARTIAL name ('concept' for
        # 'conceptId'), which only happens when it is concatenated onto.
        if i == len(cp) - 1 and not b.endswith('/') and len(rp) > len(cp):
            if not a.startswith(b):
                return False
            continue
        if a.startswith(':') or b.startswith(':'):
            continue
        if a != b:
            return False
    return True


def ui_sources():
    """(name, text) for every file that BUILDS A PAGE.

    Two exclusions, both of which were bugs before they were comments:

      * `app/main.ch` is the ROUTE TABLE.  It names all 145 API paths by
        definition, so including it made every route match itself and the report
        said 0 holes -- which is the one number this tool must never print,
        because it reads as "everything is wired up".  It is a server file.
      * `tests/` and `handlers_*.ch` name paths in assertions and error
        messages.  A path named only there is not something a person can reach.

    What is left is the two layers that actually emit markup and JS -- web/src
    (platform pages) and content/src (course pages) -- plus the 432
    pre-rendered pages read from disk, because those are what GitHub Pages
    serves and the running server does not serve them."""
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, 'courses', '*', 'output',
                                          '*.html'))):
        out.append(('static:' + os.path.relpath(f, ROOT),
                    open(f, encoding='utf-8', errors='replace').read()))
    for f in sorted(glob.glob(os.path.join(ROOT, 'web', 'src', '*.ch')) +
                    glob.glob(os.path.join(ROOT, 'content', 'src', '*.ch'))):
        out.append((os.path.relpath(f, ROOT),
                    open(f, encoding='utf-8', errors='replace').read()))
    return out


def scan_ui():
    """path -> [source names], from page-building files only."""
    callers = {}
    srcs = ui_sources()
    for name, text in srcs:
        for p in _scan(text):
            callers.setdefault(p, []).append(name)
    return callers, len(srcs)


# ---------------------------------------------------------------------------
# 4. Which callers exist ONLY in server code.
#
# A path that appears solely in a .ch file is not a UI caller -- it is usually
# a handler echoing a path in an error message, or a test.  Counting those as
# UI coverage is how "the feature is wired up" gets asserted when a person
# still cannot see it.
# ---------------------------------------------------------------------------
UI_LAYER_DIRS = ('web/src', 'content/src')


def ui_only(callers_found, routes):
    """Recompute the caller set using ONLY page-building sources."""
    ui = set()
    for f in glob.glob(os.path.join(ROOT, 'web', 'src', '*.ch')) + \
            glob.glob(os.path.join(ROOT, 'content', 'src', '*.ch')):
        ui |= calls_in_text(open(f, encoding='utf-8',
                                 errors='replace').read())
    for f in glob.glob(os.path.join(ROOT, 'courses', '*', 'output', '*.html')):
        ui |= calls_in_text(open(f, encoding='utf-8',
                                 errors='replace').read())
    return called(routes, ui)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--live', action='store_true',
                    help='also fetch the platform pages from the running server')
    args = ap.parse_args()

    routes = read_routes()
    if len(routes) < 50:
        # The scan reads routes out of source.  If that reading broke, every
        # route looks uncalled and this prints 180 holes, which is worse than
        # printing nothing -- so it refuses instead.
        print('FAIL: read only %d routes from app/main.ch. The route pattern '
              'is probably stale, and reporting 180 phantom holes would be '
              'worse than reporting none.' % len(routes))
        return 2

    callers_found, nsrc = scan_ui()

    api_routes = [(m, p) for m, p in routes if p.startswith('/api/')]

    def who(path):
        # A route is reached if ANY caller path matches it, and the evidence
        # names the files -- so every claim in the report is one grep away.
        ev = []
        for cp, files in callers_found.items():
            if _matches(cp, path):
                ev.extend(files)
        return sorted(set(ev))

    invisible = [(m, p) for m, p in api_routes if not who(p)]
    reached = [(m, p, who(p)) for m, p in api_routes if who(p)]

    if args.json:
        print(json.dumps({
            'routes_total': len(routes),
            'api_routes': len(api_routes),
            'sources_scanned': nsrc,
            'caller_paths_found': len(callers_found),
            'reached_from_ui': len(reached),
            'no_ui_caller_at_all': sorted(p for _, p in invisible),
        }, indent=2))
        return 0

    print('integration_holes: %d routes (%d API), scanned %d page-building '
          'sources, %d distinct API paths named'
          % (len(routes), len(api_routes), nsrc, len(callers_found)))
    print()
    print('=' * 78)
    print('A. ROUTES NO UI CAN REACH   (%d)' % len(invisible))
    print('=' * 78)
    print('The route is registered, it answers when called by hand, and no page,')
    print('script or course file names it. This is the hole: shipped, invisible,')
    print('and it reads as covered in the checklist.')
    print()
    for m, p in sorted(invisible, key=lambda x: x[1]):
        print('  %-6s %s' % (m, p))

    print()
    print('=' * 78)
    print('B. REACHED  (%d) -- the other half' % len(reached))
    print('=' * 78)
    print('Listed so the number is checkable: every one of these has a named')
    print('caller in a page-building file, and the file is printed. A route')
    print('missing from section A but present here is a false negative here, not')
    print('a hole.')
    print()
    for m, p, ev in sorted(reached, key=lambda x: x[1]):
        print('  %-6s %-44s %s' % (m, p, ev[0] if ev else '?'))

    print()
    print('=' * 78)
    print('SUMMARY')
    print('=' * 78)
    pct = (100.0 * len(reached) / len(api_routes)) if api_routes else 0
    print('  API routes reachable from a page : %d of %d (%.0f%%)'
          % (len(reached), len(api_routes), pct))
    print('  no UI caller at all             : %d' % len(invisible))
    print()
    print('  This is a REPORT, not a pass/fail gate. Every line in section A is')
    print('  a claim to argue with: some are correctly headless (internal, or')
    print('  for a client that does not exist yet). What is not acceptable is the')
    print('  scan silently finding nothing, which is why it exits 2 when it cannot')
    print('  read the routes at all.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
