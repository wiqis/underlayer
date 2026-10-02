#!/usr/bin/env python3
"""add_lesson_nav.py -- put render_lesson_nav() into every page in content/src.

WHY A SCRIPT AND NOT 438 EDITS
------------------------------
The nav was missing from 398 lesson pages.  Adding it by hand is 438 edits, and
438 hand edits is how this goes wrong: one file missed here is one page a
learner is trapped on, and nothing in the build says so.  A script is
auditable (this file is the record of what was done), re-runnable, reviewable
as a diff, and -- the part that matters -- idempotent, so running it twice
changes nothing and a second run after a new course lands is the whole
maintenance cost.

THE ANCHOR, AND WHAT IT IS NOT
------------------------------
The obvious anchor is the call to `render_lesson_css(&mut page)` that 330
content files already make, immediately before their own `#html` block: the nav
has to be emitted before that block so it is the first thing in `<body>`, and
the stylesheet call is the last thing before the markup.

It only reaches 330 of the 438 page builders.  108 more never call it -- the
HAT course and the hand-written ELF pages each carry their own CSS -- and they
are reached by the second anchor instead, `page.defaultPrepare()`, which every
page builder in this directory has exactly once.  Neither anchor is allowed to
fire after the file's first `#html` block: if it did, the nav would be emitted
AFTER the lesson and would appear at the bottom of the page, which is a nav
nobody can use.  That condition is CHECKED, not assumed, and a file that
violates it is reported and left alone rather than silently mangled.

The remaining 12 files in content/src/ are not page builders at all -- they are
the shared asset and drill-bank modules (`lesson_assets.ch`,
`course_landing_assets.ch`, `hat_verbal_drill_bank.ch` and friends).  They have
no `HtmlPage` and therefore no page to put a nav on.  They are named in the
report so that "12 files not touched" is a fact with a reason, not a gap.

WHAT IT DOES NOT DO
-------------------
It does not touch web/src/.  The collection pages there already render the nav
through render_nav_bar, which now delegates to the same component.

It does not add the site nav to a page that already draws a navbar of its own.
Seven content files do -- course_landing.ch and the six course-specific
landings (elf, coff, dwarf, macho, obj, pe) -- and those navs carry things the
site nav does not: a course-scoped "Courses" link, the nav progress bar, the
due-review badge and the Ctrl+K command palette.  Putting the site nav above
them would put two navbars on all 34 course landing pages, which is the same
class of defect as the dead /courses link: a collection that looks finished and
is not.  Those files are named in the report instead.

It does not write a nav into any file.  It writes a CALL to
underlayer_content::render_lesson_nav(), which is one function, so the markup
is written once.

Usage:
    python3 tools/add_lesson_nav.py            # apply
    python3 tools/add_lesson_nav.py --check    # report only, write nothing
    python3 tools/add_lesson_nav.py --report   # per-file detail; writes nothing

Exit: 0 nothing to do, 1 a file it could not handle safely, 2 bad usage.
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GLOB = os.path.join(ROOT, 'content', 'src', '*.ch')

# The call this script inserts.  Matched as a whole token so the idempotence
# check cannot be fooled by the word "nav" appearing in a comment.
CALL = 'render_lesson_nav(&mut page)'
CALL_RE = re.compile(r'^\s*' + re.escape(CALL) + r'\s*$')

# A page builder: it constructs a page.  The 12 shared asset modules do not and
# are reported separately rather than counted as failures.
PAGE_BUILDER = re.compile(r'^\s*var page = HtmlPage\(\)\s*$')
ANCHOR_CSS = re.compile(r'^\s*render_lesson_css\(&mut page\)\s*$')
ANCHOR_PREPARE = re.compile(r'^\s*page\.defaultPrepare\(\)\s*$')
HTML_OPEN = re.compile(r'^\s*#html\s*\{\s*$')
# A file that already draws its own navbar.  The seven landing pages in this
# directory do, and their nav carries the course progress bar, the due badge
# and the command palette, so the site nav is NOT added above them.
OWN_NAVBAR = re.compile(r'<div class="navbar"')


def classify(lines):
    """(anchor_index, kind) for one file, or (None, reason) when there is none.

    The anchor must come BEFORE the file's first `#html` block.  A file whose
    first `#html` opens above the anchor is returned as unsafe rather than
    patched, because inserting there would emit the nav after the lesson body.
    """
    first_html = None
    for i, line in enumerate(lines):
        if HTML_OPEN.match(line):
            first_html = i
            break
    for i, line in enumerate(lines):
        if ANCHOR_CSS.match(line):
            if first_html is not None and first_html < i:
                return None, ('render_lesson_css is below the first #html '
                              '(line %d); the nav would land after the body'
                              % (first_html + 1))
            return i, 'render_lesson_css'
    for i, line in enumerate(lines):
        if ANCHOR_PREPARE.match(line):
            if first_html is not None and first_html < i:
                return None, ('page.defaultPrepare() is below the first #html '
                              '(line %d); the nav would land after the body'
                              % (first_html + 1))
            return i, 'page.defaultPrepare'
    return None, 'no page builder here (shared asset or drill-bank module)'


def plan():
    """Every file, and what would be done to it.  Never writes."""
    work, done, has_own_nav, not_a_page, unsafe = [], [], [], [], []
    for path in sorted(glob.glob(SRC_GLOB)):
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding='utf-8') as fh:
            src = fh.read()
        lines = src.split('\n')
        if any(CALL_RE.match(l) for l in lines):
            done.append(rel)
            continue
        if not any(PAGE_BUILDER.match(l) for l in lines):
            not_a_page.append(rel)
            continue
        if OWN_NAVBAR.search(src):
            has_own_nav.append(rel)
            continue
        anchor, kind = classify(lines)
        if anchor is None:
            unsafe.append((rel, kind))
            continue
        work.append((rel, anchor, kind))
    return work, done, has_own_nav, not_a_page, unsafe


def indent_of(lines, i):
    line = lines[i]
    stripped = line.lstrip()
    return line[:len(line) - len(stripped)]


def apply(path, anchor):
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    pad = indent_of(lines, anchor)
    lines.insert(anchor, pad + CALL)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true',
                    help='report only; write nothing')
    ap.add_argument('--report', action='store_true',
                    help='name every file and the anchor it used; writes nothing')
    args = ap.parse_args()

    work, done, has_own_nav, not_a_page, unsafe = plan()

    if args.report:
        for rel, anchor, kind in work:
            print('  INSERT %-42s line %-4d after %s' % (rel, anchor + 1, kind))
        for rel in done:
            print('  ALREADY %-42s' % rel)

    if unsafe:
        for rel, why in unsafe:
            print('UNSAFE %s: %s' % (rel, why))

    print()
    print('add_lesson_nav: %d to insert (%d via render_lesson_css, %d via '
          'page.defaultPrepare)' % (len(work),
                                    sum(1 for _, _, k in work if k == 'render_lesson_css'),
                                    sum(1 for _, _, k in work if k == 'page.defaultPrepare')))
    print('               %d already carry the call' % len(done))
    print('               %d draw their own navbar, left alone' % len(has_own_nav))
    print('               %d not page builders, left alone' % len(not_a_page))
    if not args.report:
        for rel in has_own_nav:
            print('                 own nav   %s' % rel)
        for rel in not_a_page:
            print('                 no page   %s' % rel)

    if unsafe:
        print('\nFAIL: %d file(s) this script will not touch.  Read the reasons '
              'above; the nav on those pages is a job for a human.' % len(unsafe))
        return 1

    if args.check:
        if work:
            print('\nFAIL: %d page(s) have no nav call.' % len(work))
            return 1
        print('\nALL CONSISTENT: %d page builders call render_lesson_nav(), '
              '%d draw their own navbar and are meant to, %d are shared asset '
              'modules with no page of their own.'
              % (len(done), len(has_own_nav), len(not_a_page)))
        return 0

    # --report is read-only too.  It printed a per-file plan and then applied
    # it, which is the one behaviour a plan-printing flag must never have.
    if args.report:
        print('\n--report did not write.  Re-run without it to apply.')
        return 0

    for rel, anchor, _kind in work:
        apply(os.path.join(ROOT, rel), anchor)
    if work:
        print('\ninserted into %d file(s).' % len(work))
    return 0


if __name__ == '__main__':
    sys.exit(main())
