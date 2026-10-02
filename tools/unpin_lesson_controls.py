#!/usr/bin/env python3
"""unpin_lesson_controls.py -- stop the lesson-page a11y controls colliding with the nav.

WHY THIS EXISTS
---------------
Adding the site nav to the 398 lesson pages put a `position: sticky; z-index: 100`
bar across the top of every one of them.  21 of those pages pin a row of
accessibility controls to the top-left corner of the VIEWPORT --
`.a11y-controls { position: fixed; top: 1rem; left: 1rem; z-index: 60 }`, and on
9 of them `.cb-controls` beside it -- so the nav paints straight over them and
the high-contrast, reduced-motion, keyboard-shortcut and colour-blindness
buttons stop being visible AND stop being clickable.

This is a collision, not a preference, and it cannot be fixed with an offset.
The nav's height is not a constant: measured with headless Chrome
(tools/measure_nav.py), it is 58px at 1440px wide, 126px at 1024px and 768px,
and 163px at 390px, because the thirteen nav links wrap onto one, two and three
rows respectively.  Any `top:` chosen here would be right at one width and
wrong at the other two -- which is exactly the "CSS assumption that looks right
in source" trap this collection keeps hitting.

So the controls move instead.  `position: fixed` is dropped and the groups
become ordinary in-flow blocks at the top of the lesson, which is where the
other 79 lesson pages that carry the same buttons have always had them, and
where the font/spacing/width bar on these same pages already sits.  Two
identical CSS declarations in 21 files become two identical declarations, done
by script so the diff is one line per file and is reviewable.

WHAT IT CHANGES, EXACTLY
------------------------
    .a11y-controls { position: fixed; top: 1rem; left: 1rem; display: flex; gap: 0.35rem; z-index: 60; }
        -> .a11y-controls { display: flex; gap: 0.35rem; margin-bottom: 0.5rem; }

    .cb-controls { position: fixed; top: 1rem; left: 5rem; display: flex; gap: 0.35rem; z-index: 60; }
        -> .cb-controls { display: flex; gap: 0.35rem; margin-bottom: 0.5rem; }

`display: flex` and `gap` are kept: without flex the buttons still sit on one
line by accident (they are inline-block), and the row is supposed to be a row.
`z-index` is dropped because z-index does nothing on a static element, and
leaving it would read as a claim the CSS no longer makes.

WHAT IT DOES NOT DO
-------------------
It does not touch the buttons, the handlers, the shortcuts or the markup.  It
does not add a nav to anything.  It refuses to touch a rule that is not one of
the two shapes above, so if someone has already unpinned a page by hand the
script says so rather than rewriting their line.

Usage:
    python3 tools/unpin_lesson_controls.py --check
    python3 tools/unpin_lesson_controls.py --report

Exit: 0 nothing to do, 1 a rule it did not recognise.
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GLOB = os.path.join(ROOT, 'content', 'src', '*.ch')

# The shape this script is allowed to rewrite.  `top` and `left` accept any
# length so that a page which moved the group (bytes.ch puts .cb-controls at
# left: 5rem) is still recognised; what must be there is `position: fixed`,
# because a rule without it is already in flow and must be left alone.
PINNED = re.compile(
    r'^(?P<indent>\s*)\.(?P<cls>a11y-controls|cb-controls)\s*\{\s*'
    r'position:\s*fixed;\s*'
    r'top:\s*[^;]+;\s*'
    r'left:\s*[^;]+;\s*'
    r'(?P<rest>.*?)\}\s*$')

# What the unpinned rule looks like.  Used for the "already done" test.
UNPINNED = re.compile(
    r'^\s*\.(?P<cls>a11y-controls|cb-controls)\s*\{\s*'
    r'display:\s*flex;.*\}\s*$')


def plan():
    todo, done, unknown = [], [], []
    for path in sorted(glob.glob(SRC_GLOB)):
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        hits = 0
        for i, line in enumerate(lines):
            if PINNED.match(line):
                hits += 1
            elif ('a11y-controls {' in line or 'cb-controls {' in line) \
                    and not UNPINNED.match(line):
                unknown.append('%s:%d  %s' % (rel, i + 1, line.strip()))
        if hits:
            todo.append((rel, hits))
        elif UNPINNED.search('\n'.join(lines)):
            done.append(rel)
    return todo, done, unknown


def rewrite(path):
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    out = []
    for line in lines:
        m = PINNED.match(line)
        if m:
            out.append('%s.%s { display: flex; gap: 0.35rem; margin-bottom: 0.5rem; }'
                       % (m.group('indent'), m.group('cls')))
        else:
            out.append(line)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true', help='report only')
    ap.add_argument('--report', action='store_true',
                    help='name every file; writes nothing')
    args = ap.parse_args()

    todo, done, unknown = plan()

    if args.report:
        for rel, n in todo:
            print('  UNPIN  %-40s %d rule(s)' % (rel, n))
        for rel in done:
            print('  DONE   %-40s' % rel)

    for line in unknown:
        print('UNKNOWN %s -- a rule this script did not write and will not '
              'rewrite' % line)

    print()
    print('unpin_lesson_controls: %d rule(s) to unpin across %d file(s); '
          '%d file(s) already unpinned.' % (sum(n for _, n in todo), len(todo), len(done)))

    if unknown:
        print('\nFAIL: %d unrecognised rule(s).  Read them before changing '
              'anything: this script only rewrites the shape it was written '
              'for.' % len(unknown))
        return 1

    if args.check:
        if todo:
            print('\nFAIL: %d rule(s) still pin the controls to the viewport.'
                  % sum(n for _, n in todo))
            return 1
        print('\nALL CONSISTENT: no lesson page pins a control over the nav.')
        return 0

    if args.report:
        print('\n--report did not write.  Re-run without it to apply.')
        return 0

    for rel, _n in todo:
        rewrite(os.path.join(ROOT, rel))
    if todo:
        print('\nunpinned %d rule(s) in %d file(s).' % (sum(n for _, n in todo), len(todo)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
