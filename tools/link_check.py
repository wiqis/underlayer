#!/usr/bin/env python3
"""link_check.py -- every internal href in the source must resolve.

WHY THIS EXISTS, in the shape of the defect it exists for.

`/courses` was linked 42 times across 32 files -- every lesson page's
"All courses" back-link, and the course landing nav -- and it returned 404.
It stayed broken because a nav bar that *renders* looks finished whether or not
the URL in it exists, and because 459 distinct internal targets is more than
anybody reads by hand.  tools/todo_check.py and tools/check_quotes.py exist
because the same thing is true of a checklist and a quoted number: a claim
that something is true has to be a machine check, or it is a wish.

So this extracts every `href="..."` from content/src/*.ch and web/src/*.ch,
keeps the ones that are internal (leading `/`, no scheme, no host), asks the
running server for each one, and exits non-zero on anything that is not 200.
The nav on the new pages is a component (web/src/nav_bar.ch) so that a link
cannot be right in one page and wrong in another, and this is what keeps it
right in all of them.

WHAT IT DELIBERATELY DOES NOT DO.

  * It does not accept a non-200 that looks reasonable.  A 301, a 302 and a
    200-with-an-error-body are three different things and none of them is a
    working link.
  * It does not treat an empty `href="#"` as a failure, but it DOES count and
    print them, because a nav item that goes nowhere is how this started.
  * It does not check anchors within a page (`/courses#formats`): it checks
    the page, and a `#fragment` on a page that exists is a different question
    that a different tool should answer.
  * It does not guess.  If the server is not running it says so and exits 2,
    rather than reporting every link as broken -- a checker that reports a
    broken server as 400 broken links is a checker nobody will trust.

Usage:
    python3 tools/link_check.py                     # against localhost:9000
    python3 tools/link_check.py --port 8080
    python3 tools/link_check.py --base http://host  # for a deployed instance
    python3 tools/link_check.py --quiet

Exit: 0 all internal links 200. 1 at least one dead link.
      2 the server is not reachable (NOT a pass).
"""
import argparse
import glob
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SOURCES = ("content/src/*.ch", "web/src/*.ch")

# `href="..."` and `action="..."`: both are URLs a reader is sent to by
# clicking or submitting.  Single and double quotes, because the #html macro
# accepts either and a checker that only reads one of them is a checker that
# misses half the file.
# The lookbehind matters and is not decoration.  A plain `\bhref\s*=` also
# matches JavaScript property assignment, and this collection is full of it:
# `link.href = "/courses/elf/lessons/" + ids[i];` in
# web/src/handlers_progress_page.ch is a fragment of a URL, not a URL, and
# checking it reported `/courses/elf/lessons/` as a dead link -- a false
# positive that would have been indistinguishable from a real defect in the
# output.  An HTML attribute is always preceded by whitespace or `<`; a JS
# property access is preceded by `.`.
ATTR = re.compile(r'(?<![\w.$-])(?:href|action)\s*=\s*(?:"([^"]*)"|\'([^\']*)\')')

# Anything with a scheme, a host, a leading `//`, or a `mailto:`/`tel:`/`#`
# is not this server's problem.
EXTERNAL = re.compile(r'^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|//|#)')

# An anchor with an empty href.  Scoped to `<a ...>` so the prev/next `<link>`
# pairs in lesson pages are not reported -- see the note at the call site.
EMPTY_ANCHOR = re.compile(r'<a\b[^>]*?\bhref\s*=\s*(?:""|\'\')')

# A value carrying JS interpolation or concatenation is a template, not a
# URL: `/courses/` + cid + `, `${link}`, and `{href}`.  These are checked by
# the value they produce at run time, if they produce one, and a checker that
# guessed at them would be guessing.
TEMPLATE = re.compile(r"[\s'+`{}\$\[\]()]")


def extract(path):
    """Every href/action in one file, as (value, line_number).

    Reads the RAW source rather than the served HTML on purpose.  The served
    pages are mostly produced by component functions and `#html` macro
    expansion, so a checker pointed at the output would only ever see the
    links that happen to be written literally -- which is how `/courses` hid:
    it appeared 42 times in source and once in no rendered page that anyone
    looked at.  Checking the source also catches a link that is dead BEFORE it
    ships, which is the only time the information is useful.
    """
    out = []
    with open(path, 'r', encoding='utf-8', errors='replace') as fh:
        for lineno, line in enumerate(fh, 1):
            for m in ATTR.finditer(line):
                value = m.group(1)
                if value is None:
                    value = m.group(2)
                out.append((value, lineno))
    return out


def is_internal(value):
    """True for a literal path this server serves.

    Empty is False (it is counted separately -- an `<a href="">` is a nav item
    that goes nowhere, which is the shape the original /courses defect had).
    External schemes and fragments are False.  A value carrying JS template or
    concatenation syntax is False, because it is not a URL a checker can ask
    the server about.
    """
    if not value:
        return False
    if EXTERNAL.match(value):
        return False
    if TEMPLATE.search(value):
        return False
    return value.startswith('/')


def strip_query_and_fragment(path):
    for sep in ('#', '?'):
        k = path.find(sep)
        if k >= 0:
            path = path[:k]
    return path or '/'


def collect():
    """Returns (targets, occurrences) where targets is sorted+deduped and
    occurrences maps target -> sorted list of "file:line" strings."""
    occurrences = {}
    for pattern in SOURCES:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            rel = os.path.relpath(path, ROOT)
            for value, lineno in extract(path):
                if not is_internal(value):
                    continue
                target = strip_query_and_fragment(value)
                occurrences.setdefault(target, []).append(
                    '%s:%d' % (rel, lineno))
    return (sorted(occurrences),
            {t: sorted(occurrences[t]) for t in occurrences})


def probe(base, target):
    url = base + target
    try:
        with urlopen(url, timeout=20) as resp:
            return target, resp.status, ''
    except HTTPError as exc:
        return target, exc.code, ''
    except URLError as exc:
        return target, 0, str(exc.reason)
    except Exception as exc:                      # noqa: BLE001
        return target, 0, str(exc)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', default=None,
                    help='base URL (default http://localhost:<port>)')
    ap.add_argument('--port', type=int, default=9000)
    ap.add_argument('--workers', type=int, default=16)
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--max-report', type=int, default=25,
                    help='how many dead links to name individually')
    args = ap.parse_args()

    base = args.base or 'http://localhost:%d' % args.port
    base = base.rstrip('/')

    # Reachability FIRST, and separately.  A down server is exit 2 with a
    # message, never "400 links broken".
    try:
        with urlopen(base + '/api/health', timeout=10) as resp:
            health = resp.status
    except Exception as exc:                      # noqa: BLE001
        print('CANNOT REACH %s/api/health (%s)' % (base, exc))
        print('Start the server first. A link checker pointed at a server that')
        print('is not running reports every link broken, which is a lie and')
        print('which is how a checker gets ignored.')
        return 2
    if health != 200:
        print('SERVER UNHEALTHY: /api/health returned %d' % health)
        return 2

    targets, occurrences = collect()
    if not targets:
        print('FAIL: no internal links found in %s' % ', '.join(SOURCES))
        return 1

    total_occurrences = sum(len(v) for v in occurrences.values())
    if not args.quiet:
        print('link_check: %d distinct internal targets, %d occurrences, '
              'in %s' % (len(targets), total_occurrences,
                         ' + '.join(SOURCES)))

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda t: probe(base, t), targets))

    dead = []
    unreachable = []
    for target, status, err in results:
        if status == 200:
            continue
        if status == 0:
            unreachable.append((target, err))
        else:
            dead.append((target, status))

    for target, err in unreachable:
        print('  UNREACHABLE %s (%s)' % (target, err))

    dead.sort()
    for target, status in dead[:args.max_report]:
        refs = occurrences[target]
        shown = ', '.join(refs[:4])
        if len(refs) > 4:
            shown += ', +%d more' % (len(refs) - 4)
        print('  DEAD %d  %s' % (status, target))
        print('        linked from: %s' % shown)
    if len(dead) > args.max_report:
        print('  ... and %d more dead links' % (len(dead) - args.max_report))

    # An `<a href="">` is a nav item that goes nowhere, which is the shape the
    # original /courses defect had, so they are printed rather than passed over
    # in silence.  `<link rel="prev" href="">` is a DIFFERENT thing -- 400+
    # lesson pages carry a prev/next pair whose href the page's own JavaScript
    # fills in, and calling those "empty links" would bury the real ones.  Only
    # anchors are reported.
    empties = 0
    for pattern in SOURCES:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            rel = os.path.relpath(path, ROOT)
            with open(path, 'r', encoding='utf-8', errors='replace') as fh:
                for lineno, line in enumerate(fh, 1):
                    for m in EMPTY_ANCHOR.finditer(line):
                        empties += 1
                        if not args.quiet:
                            print('  EMPTY <a href="">  %s:%d' % (rel, lineno))

    if dead or unreachable:
        print('\nFAIL: %d dead, %d unreachable, out of %d distinct internal '
              'links.' % (len(dead), len(unreachable), len(targets)))
        return 1

    print('ALL CONSISTENT: %d distinct internal links, %d occurrences, all '
          'HTTP 200.%s'
          % (len(targets), total_occurrences,
             ' %d empty href="", printed above.' % empties if empties else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())