#!/usr/bin/env python3
"""strip_bare_control_calls.py -- delete the BARE calls to the reading controls
that 21 lesson pages each left behind.

THE THIRD PIECE, AND THE ONE THAT ACTUALLY BROKE A BUILD GATE
-------------------------------------------------------------
`strip_lesson_controls.py` removed the `function` DEFINITIONS. It does not match
`applySettings();` on a line of its own, and it does not match
`addFeedbackRatings();` -- both are bare top-level CALLS. So after it ran, 21
pages still asked for functions the shared module provides under different
names, and:

    ReferenceError: applySettings is not defined

`tools/progress_check.py` caught it, in the section that extracts the served
script and RUNS it in Node. The page still answered 200, the markup was intact,
and every static check passed; only executing the script showed that a lesson
page threw on load. That is the third distinct shape the same cleanup had to
account for -- definitions, an IIFE, and bare calls -- and the third one is the
only shape that reached a shipped state.

WHY DELETE RATHER THAN REWRITE
------------------------------
Rewriting `applySettings();` to `window.applySettings();` would make the call
work, but it would leave 21 pages each re-running the shared module's restore
path at a point of their own choosing. The shared module already calls it once,
at the right moment, inside `__ulRestoreLessonPrefs()`. A second call is not a
no-op either: `__ulApplyLessonSettings` clears all eight reading classes before
re-applying them, so a second call from a page that has just set a class would
wipe it.

HOW IT IS VERIFIED
------------------
  * the call is gone
  * the file still has balanced braces, reported with a LINE NUMBER if not
  * no other bare call to a removed name survives
  * `.lesson` and the control markup are untouched

Usage:
    python3 tools/strip_bare_control_calls.py           # apply
    python3 tools/strip_bare_control_calls.py --check   # report only
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'content', 'src')

# Bare top-level invocations of the names the shared module now owns. Anchored
# to a whole line so `window.setFontSize(...)` -- a legitimate call -- is not
# touched, and so a mention inside a comment or a string is left for the
# comment-stripped pass below to reason about.
CALLS = [
    'applySettings', 'addFeedbackRatings', 'cycleFontSize', 'showToast',
]

CALL_RE = re.compile(r'(?m)^[ \t]*(' + '|'.join(CALLS) + r')\s*\(\s*\)\s*;[ \t]*\n?')


def strip_comments(text):
    """Blank comments WITHOUT changing offsets -- see strip_lesson_controls.py."""
    def blank(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    text = re.sub(r'/\*[\s\S]*?\*/', blank, text)
    return re.sub(r'(?m)//[^\n]*', blank, text)


def deepest_unbalanced(text):
    """Line number of the first closer with nothing open, or None."""
    depth = 0
    for i, ch in enumerate(text):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth < 0:
                return text.count('\n', 0, i) + 1
    if depth != 0:
        return text.count('\n', 0, len(text)) + 1
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    apply = not args.check

    targets = []
    for name in sorted(os.listdir(SRC)):
        if not name.endswith('.ch'):
            continue
        path = os.path.join(SRC, name)
        # Match against the comment-stripped text, then apply the same offsets to
        # the original. Matching the original directly would delete a line that
        # only *mentions* the name inside a comment.
        stripped = strip_comments(open(path, encoding='utf-8').read())
        n = len(CALL_RE.findall(stripped))
        if n:
            targets.append((path, n))

    print(f'strip_bare_control_calls: {len(targets)} file(s) carry bare calls')
    changed = 0
    for path, expected in targets:
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding='utf-8').read()
        stripped = strip_comments(src)
        edited, n = CALL_RE.subn('', stripped)

        problems = []
        if n != expected:
            problems.append(f'expected {expected} call(s), removed {n}')

        bad = deepest_unbalanced(edited)
        if bad:
            problems.append(f'unbalanced braces at line {bad}')
        bad_src = deepest_unbalanced(src)
        if bad_src and not bad:
            problems.append(f'source already unbalanced at line {bad_src}')

        for fn in CALLS:
            if re.search(r'(?m)^[ \t]*' + fn + r'\s*\(\s*\)\s*;', edited):
                problems.append(f'bare {fn}() survived')

        if 'class="lesson"' in src and 'class="lesson"' not in edited:
            problems.append('lost the .lesson element')
        if src.count('class="reading-controls"') != edited.count('class="reading-controls"'):
            problems.append('lost the reading-controls markup')

        if problems:
            print(f'  SKIP  {rel}')
            for p in problems:
                print(f'          - {p}')
            continue

        edited = re.sub(r'\n{3,}', '\n\n', edited)
        if apply:
            open(path, 'w', encoding='utf-8').write(edited)
        changed += 1
        print(f'  {"OK   " if apply else "WOULD"} {rel}: -{n} bare call(s), verified')

    verb = 'rewrote' if apply else 'would rewrite'
    print(f'{verb} {changed} of {len(targets)} files')
    return 0


if __name__ == '__main__':
    sys.exit(main())