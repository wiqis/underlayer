#!/usr/bin/env python3
"""nesting_check.py -- report REAL div/pre nesting errors in a #html block.

WHY THIS EXISTS, because tools/html_balance.py cannot be trusted alone.

html_balance.py counts `<div` against `</div>` and its `report()` says "ok"
whenever the two numbers are equal.  A page can therefore have balanced
counts and still be structurally wrong, and that is not hypothetical: three
pages in this collection shipped with `unit-model` never closed, so every
unit after it -- unit-reality, unit-example, unit-apply, unit-connect and
the lesson footer -- was a CHILD of unit-model instead of a sibling.  The
count was 32/32, html_balance.py said "ok", and the browser produced a DOM
nobody wrote.

The bug's mechanism is worth recording too, because it is a lesson and not
just a slip.  html_balance.py has a `repair()` mode that runs by DEFAULT
(it is skipped only by `--check`) and it REWRITES the file: when the closer
does not match the innermost open tag it emits the closer it thinks is right
and drops the one that is there.  Repairing a real unclosed `<div>` is
correct.  Repairing it by moving the tag to the end of the block, with no
newline, is what produced the `    </div>render_lesson_js(&mut page)` tail
that gave the count its balance.  So:

  * this tool reports; it never writes.
  * it tracks a STACK, not a count, so nesting order is checked.
  * it prints the line a close belongs to, which is how the swallowed
    unit-model was found -- a count cannot tell you that.
  * it flags a close whose name does not match the innermost open tag, and a
    close with an empty stack, and anything left open at the end.

Run:  python3 tools/nesting_check.py content/src/*.ch
Exit: 0 clean, 1 problems.
"""
import glob
import re
import sys

OPEN = re.compile(r'<(div|pre)\b[^>]*>')
CLOSE = re.compile(r'</(div|pre)>')
TOKEN = re.compile(r'<(div|pre)\b[^>]*>|</(div|pre)>|\n')

# KNOWN EXCEPTIONS, each with the reason it is allowed.  These are NOT the
# bug this tool was written for and they are NOT silently tolerated: they are
# printed every run, so an exception that gets fixed shows up as a stale
# entry, and an exception that spreads shows up as a new filename.
#
#   unit-exercises nested inside unit-connect, in four courses predating the
#   six-unit shape.  The block is `style="display:none"` and carries its own
#   class, so it renders with its own border and background and the visual
#   result is correct; the markup is merely inconsistent with the 400-odd
#   pages that place it as a sibling.  Left alone deliberately: it is in
#   courses outside this change, `api-exercises` is referenced by their
#   exercise JavaScript, and moving a container in four committed pages to
#   satisfy a linter is not a change to smuggle in beside a course build.
#   Follow-up, not an oversight.
KNOWN = {
    'content/src/execution.ch': 'unit-exercises inside unit-connect (legacy)',
    'content/src/ld_so.ch': 'unit-exercises inside unit-connect (legacy)',
    'content/src/loader.ch': 'unit-exercises inside unit-connect (legacy)',
    'content/src/memory_layout.ch': 'unit-exercises inside unit-connect (legacy)',
}


def block_of(src):
    """The text the #html macro owns, which is where the divs live.

    Cut at the first of render_lesson_js / #css { / return page.toString()
    after the #html opener, because the JavaScript and CSS that follow carry
    angle brackets of their own and none of them are page structure.
    """
    if '#html {' not in src:
        return None
    start = src.index('#html {')
    end = len(src)
    for marker in ('render_lesson_js', '#css {', 'return page.toString()'):
        k = src.find(marker, start)
        if k >= 0:
            end = min(end, k)
    return src[start:end]


def check(path):
    src = open(path).read()
    block = block_of(src)
    if block is None:
        return []                      # landing page with no #html: nothing to do
    line = src[:src.index('#html {')].count('\n') + 1
    stack = []
    problems = []
    # the outermost page container, so the reader can see what the last close
    # is actually for
    for tok in TOKEN.finditer(block):
        text = tok.group(0)
        if text == '\n':
            line += 1
            continue
        if tok.group(1):
            stack.append((line, text.strip()))
        else:
            name = tok.group(2)
            if not stack:
                problems.append('%s:%d: stray </%s> with nothing open'
                                % (path, line, name))
                continue
            opened_at, opened = stack.pop()
            if not opened.startswith('<%s' % name):
                problems.append(
                    '%s:%d: </%s> does not match <%s> opened at line %d'
                    % (path, line, name, opened, opened_at))
    for opened_at, opened in stack:
        problems.append('%s:%d: <%s> never closed'
                        % (path, opened_at, opened[1:].split('>')[0]))
    problems.extend(units(path, src, block))
    return problems


def units(path, src, block):
    """Every unit div must be a DIRECT CHILD of `.lesson` -- and nothing else.

    This is the single assertion in the tool, and it is here because a count
    could not catch the bug that made it necessary.  Three pages shipped with
    `unit-model` (and, after a later edit, `unit-reality` and
    `unit-example`) never closed, so the five units after it and the lesson
    footer became CHILDREN of it.  Every other check passed: `class="unit `
    occurred six times, `<div` equalled `</div>`, and the tag stack was
    empty, because the tree was well formed and simply the wrong shape.
    tools/verify_a64sys.py's `units != 6` was also satisfied.

    Two earlier drafts of this function asserted more -- that the six kinds
    appear once each in a fixed order, and that a unit spans fewer than 60
    lines.  Both were wrong and were removed rather than tuned:

      * the collection has 22 legitimate unit shapes.  206 pages use eight
        units including `interact` and `retrieve`; 12 use ten with
        `exercises`; landing pages repeat `unit-example` because the repeated
        element is a grid of cards.  A `unit-model` twice on one page is
        `a64_cond.ch` and is a content choice, not a nesting error.
      * a long unit is a long unit.  `unit-reality` on `a64-pagetables` runs
        185 lines of measured output and closing it sooner would mean cutting
        the measurement, which is the thing the page exists for.

    So the rule is about DEPTH and about nothing else: a unit div at any
    depth other than one below `.lesson` is swallowing its siblings, and the
    report names the opening line so the missing `</div>` is findable.
    """
    problems = []
    line = src[:src.index('#html {')].count('\n') + 1
    stack = []
    lesson_depth = None
    for tok in TOKEN.finditer(block):
        text = tok.group(0)
        if text == '\n':
            line += 1
            continue
        if tok.group(1):
            if text.startswith('<div class="lesson"'):
                lesson_depth = len(stack)
            elif (lesson_depth is not None
                  and re.search(r'class="unit unit-[a-z]+"', text)
                  and len(stack) != lesson_depth + 1):
                kind = re.search(r'class="(unit unit-[a-z]+)"', text).group(1)
                problems.append(
                    '%s:%d: <div class="%s"> sits at depth %d, not %d, so it '
                    'is not a direct child of .lesson and swallows the units '
                    'after it'
                    % (path, line, kind, len(stack), lesson_depth + 1))
            stack.append((line, text.strip()))
        elif stack:
            stack.pop()
    return problems


def skeleton(path):
    """Print where each top-level container opens and closes.

    The point of this is the unit divs: six SIBLINGS of `.lesson`, one of
    each unit kind, in order.  A count of six proves nothing -- a count of
    six with unit-reality never closed is still six.
    """
    src = open(path).read()
    block = block_of(src)
    if block is None:
        return
    line = src[:src.index('#html {')].count('\n') + 1
    stack = []
    print('  %s' % path.split('/')[-1])
    for tok in TOKEN.finditer(block):
        text = tok.group(0)
        if text == '\n':
            line += 1
            continue
        if tok.group(1):
            stack.append((line, text.strip()))
        elif stack:
            opened_at, opened = stack.pop()
            if (opened.startswith('<div class="unit')
                    or opened.startswith('<div class="lesson"')
                    or opened_at > 400):
                print('    %5d closes %5d  %s' % (line, opened_at, opened))


if __name__ == '__main__':
    args = sys.argv[1:]
    verbose = '-v' in args
    args = [a for a in args if a != '-v']
    paths = ([a for a in args if a.endswith('.ch')]
             or sorted(glob.glob('content/src/*.ch')))
    allp = []
    excused = []
    excused_files = 0
    stale = []
    for p in paths:
        probs = check(p)
        if verbose:
            skeleton(p)
        # An allowlist entry that no longer matches a real problem is itself
        # a problem: the exception has been fixed and the note should be
        # deleted, not left behind to excuse the next one.
        if p in KNOWN:
            if probs:
                excused.extend(probs)
                excused_files += 1
            else:
                stale.append(p)
            print('%-38s known exception: %s' % (p.split('/')[-1], KNOWN[p]))
            continue
        if probs:
            allp.extend(probs)
        else:
            print('%-38s clean' % p.split('/')[-1])
    if stale:
        allp.extend('%s: allowlisted but no longer fails -- delete the entry '
                    'from KNOWN in tools/nesting_check.py' % p for p in stale)
    if excused:
        print('\n%d KNOWN EXCEPTION(S), each printed above with its reason:'
              % len(excused))
        for p in excused:
            print('  ' + p)
    if allp:
        print('\n%d NESTING PROBLEM(S):' % len(allp))
        for p in allp:
            print('  ' + p)
        sys.exit(1)
    # The file count is the number ACTUALLY stack-checked.  This printed
    # `len(paths) - len(KNOWN)` before, which subtracted the size of the whole
    # allowlist rather than the number of files that matched an entry in it --
    # so five clean files and four allowlist entries printed "1 files".  A
    # summary that cannot say how much of the corpus it looked at is the same
    # defect this tool exists to catch, one level up.
    print('\nALL CLEAR: %d of %d files stack-checked, no unit div swallows a '
          'sibling (%d allowlisted, %d reported clean)'
          % (len(paths) - excused_files - len(stale), len(paths), excused_files,
             len(paths) - excused_files - len(stale)))
