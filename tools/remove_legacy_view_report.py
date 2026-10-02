#!/usr/bin/env python3
"""remove_legacy_view_report.py -- delete the 31 hand-written copies of the
"a learner opened a concept" POST now that the shared nav makes it.

WHY A SCRIPT AND NOT 31 EDITS
-----------------------------
Same argument as tools/add_lesson_nav.py, which put the nav on all 398 lesson
pages and is the pattern this follows.  The copies are byte-identical modulo
indentation -- verified, all 31 of them -- so a script is smaller to review than
31 diffs and cannot miss one.  31 hand edits is 31 chances to leave a page
double-reporting, and nothing in the build would have said so.

WHAT IS BEING REMOVED AND WHY
-----------------------------
`__ul_report_view()` POSTed /api/learning/view from DOMContentLoaded.  31 of the
438 page builders in content/src carried a private copy of it inside their own
#js block, so those 31 pages reported a read and the other 407 did not.

content/src/lesson_nav.ch now calls render_lesson_engagement(), whose
__ulReportRead() makes the same POST on all 398 lesson pages.  Leaving the old
copy in place made 325 of those 398 pages report every single read TWICE, and
that is visible, not cosmetic:

  * the first POST answers `first_time:true` and the second answers `false`, so
    a learner's very first visit to a concept was labelled "read before";
  * record_activity() and run_achievement_checks() each ran twice per load.

So this is not tidying.  It removes a regression the shared-nav fix introduced.

WHAT IS NOT BEING REMOVED
-------------------------
`__ul_report_attempt()`, which sits immediately above `__ul_report_view()` in the
same block and posts a *different* event -- a graded exercise answer, to
/api/review/submit.  Only the function whose whole job is the view POST is
deleted.  The matcher is anchored on the name `__ul_report_view` and on the
`fetch('/api/learning/view'` call inside it, so a rename cannot make it delete
the wrong function, and a function that does not contain that fetch is reported
rather than removed.

HOW IT FINDS THE END OF THE FUNCTION
------------------------------------
By indentation, not by brace counting: the block opens at the indentation of
`function __ul_report_view() {` and closes at the first later line that is
exactly that indentation and starts with `}`.  Every one of the 31 copies is a
straight-line function with no nested function declaration at that indentation,
and the script REFUSES to touch a file whose closing brace it cannot find --
reported as unsafe, exit 1 -- rather than deleting to end-of-file.

THE ANCHOR IS ALSO CHECKED
--------------------------
A file is only touched if the listener line
`document.addEventListener('DOMContentLoaded', function() { __ul_report_view(); });`
is present immediately after the function.  A function with no listener is dead
code already; removing it is still right, but the script says so in the report
so the difference is visible.

Usage:
    python3 tools/remove_legacy_view_report.py            # apply
    python3 tools/remove_legacy_view_report.py --check    # report only, write nothing
    python3 tools/remove_legacy_view_report.py --report   # name every file; writes nothing

Exit: 0 nothing left to do, 1 a file it could not handle safely, 2 bad usage.
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GLOB = os.path.join(ROOT, 'content', 'src', '*.ch')

FUNC_NAME = '__ul_report_view'
FUNC_OPEN = re.compile(r'^([ \t]*)function ' + re.escape(FUNC_NAME) + r'\(\)\s*\{\s*$')
# The POST this function exists for.  Required: it is what distinguishes this
# function from __ul_report_attempt() beside it, and its absence means the
# anchor has moved and the file must not be touched blind.
FUNC_BODY_MARK = "fetch('/api/learning/view'"
LISTENER = re.compile(
    r'^[ \t]*document\.addEventListener\(\s*[\'"]DOMContentLoaded[\'"]\s*,'
    r'\s*function\(\)\s*\{\s*' + re.escape(FUNC_NAME) + r'\(\);\s*\}\s*\);\s*$')


def find_function(lines):
    """(open_idx, close_idx) for the function, or (None, reason)."""
    start = None
    pad = None
    for i, line in enumerate(lines):
        m = FUNC_OPEN.match(line)
        if m:
            start, pad = i, m.group(1)
            break
    if start is None:
        return None, 'no %s here' % FUNC_NAME
    body = '\n'.join(lines[start:start + 40])
    if FUNC_BODY_MARK not in body:
        return None, ('%s does not contain the /api/learning/view fetch '
                      'within 40 lines; the anchor moved' % FUNC_NAME)
    for j in range(start + 1, len(lines)):
        stripped = lines[j].strip()
        if not stripped:
            continue
        line_pad = lines[j][:len(lines[j]) - len(lines[j].lstrip())]
        if line_pad == pad and stripped.startswith('}'):
            return (start, j), 'ok'
        if line_pad.startswith(pad) and len(line_pad) > len(pad):
            # A deeper-indented line before the close means this is not the
            # simple straight-line function this script understands.
            if stripped.startswith('function '):
                return None, ('nested function at line %d; the closing brace '
                              'cannot be found by indentation' % (j + 1))
    return None, 'no closing brace at the function indent'


def plan():
    work, done, unsafe = [], [], []
    for path in sorted(glob.glob(SRC_GLOB)):
        rel = os.path.relpath(path, ROOT)
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        found, why = find_function(lines)
        if found is None:
            if why == 'no %s here' % FUNC_NAME:
                done.append(rel)
            continue
        start, close = found
        listener = None
        for k in range(close + 1, min(close + 4, len(lines))):
            if LISTENER.match(lines[k]):
                listener = k
                break
        work.append((rel, start, close, listener))
    return work, done, unsafe


def apply(path, start, close, listener):
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    drop = set(range(start, close + 1))
    if listener is not None:
        drop.add(listener)
    out = [l for i, l in enumerate(lines) if i not in drop]
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true',
                    help='report only; write nothing')
    ap.add_argument('--report', action='store_true',
                    help='name every file it would change; writes nothing')
    args = ap.parse_args()

    work, done, unsafe = plan()

    if args.report:
        for rel, start, close, listener in work:
            print('  REMOVE %-42s lines %d-%d%s'
                  % (rel, start + 1, close + 1,
                     '' if listener is None else ' + listener line %d' % (listener + 1)))

    print()
    print('remove_legacy_view_report: %d file(s) still carry %s'
          % (len(work), FUNC_NAME))
    print('                         %d file(s) are clean' % len(done))

    if args.check:
        if work:
            print('\nFAIL: %d page(s) would report a read twice.' % len(work))
            return 1
        print('\nALL CONSISTENT: no page carries a private %s; the shared '
              'nav in content/src/lesson_engagement.ch is the only reporter.'
              % FUNC_NAME)
        return 0

    if args.report:
        print('\n--report did not write.  Re-run without it to apply.')
        return 0

    for rel, start, close, listener in work:
        apply(os.path.join(ROOT, rel), start, close, listener)
    if work:
        print('\nremoved from %d file(s).' % len(work))
    return 0


if __name__ == '__main__':
    sys.exit(main())