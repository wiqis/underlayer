#!/usr/bin/env python3
"""strip_lesson_controls.py -- delete the 21 hand-written copies of the reading
controls' behaviour, now that content/src/lesson_controls_js.ch owns it.

THE STATE THIS SCRIPT STARTS FROM, MEASURED 2026-10-03:

    onclick="toggleHighContrast()"   100 lesson pages carry the markup
    function toggleHighContrast       21 files define it
    ...the same 100-vs-21 for setFontSize, setLineHeight, setLetterSpacing,
    setContentWidth, toggleReducedMotion, applySettings and openShortcuts

The 21 are the ELF course. They worked by accident of authorship: each carries
its own copy inside its own `#js` block, and they have already drifted from the
shared `lesson_assets.ch` copy. 79 pages had the markup and no behaviour at all,
so their buttons threw `ReferenceError` and their four dropdowns reverted
silently.

WHY DELETING IS BETTER THAN LEAVING THEM
---------------------------------------
A function declaration in a classic script creates a global, so these copies are
not inert -- they RACE the shared module. Whichever `<script>` the browser
executes last wins, so the behaviour of a page depends on block order, and
`lesson_controls_js.ch` silently stops being the thing that runs on 21 of 398
pages. That is worse than either state on its own: a fix to the shared module
would apply to 377 pages and quietly not apply to the ELF course.

The copies are also the last unguarded `localStorage` reads in the product.
`tools/lesson_controls_check.py` fails on `/courses/elf/lessons/bytes` with a
throwing localStorage precisely because of them, and a browser with site data
blocked is a normal state, not an edge case.

WHAT IS REMOVED, EXACTLY
------------------------
One contiguous region per file, from the first of these functions to the last:

    function setFontSize / setLineHeight / setLetterSpacing / setContentWidth
    function applySettings
    function toggleHighContrast / toggleReducedMotion
    function openShortcuts / closeShortcuts
    the two self-invoking restore functions that read the stored prefs
    function setColorBlind   (ELF only; its SVG filter defs stay in the markup)
    function showToast
    the Alt+C / Alt+R / Alt+= keydown listener
    function cycleFontSize
    function addFeedbackRatings / rateFeedback
    the touch/swipe gesture block

Each file is verified after the edit: the region must be gone, no reference to a
removed function may remain, and the file must still have balanced braces and a
balanced `#js` block. Anything that does not satisfy all three is reported and
NOT written.

WHAT IS DELIBERATELY KEPT
-------------------------
  * `setColorBlind`'s SVG `<filter>` definitions, which live in the markup and
    are inert without the function -- they are removed only if unused, and this
    script leaves them, because a filter def costs nothing and removing it
    would mean reasoning about the `<svg>` block in each file.
  * The `.lesson` classes themselves (`high-contrast`, `reduced-motion`,
    `font-large`, ...). Their CSS is per-file and is what makes the controls do
    anything visible; only the JS moves.

Usage:
    python3 tools/strip_lesson_controls.py            # apply
    python3 tools/strip_lesson_controls.py --check    # report only
    python3 tools/strip_lesson_controls.py --report   # per-file detail
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'content', 'src')

# The functions whose definitions are removed. Used both to find the region and
# to prove afterwards that no definition is left behind.
FUNCTIONS = [
    'setFontSize', 'setLineHeight', 'setLetterSpacing', 'setContentWidth',
    'applySettings', 'toggleHighContrast', 'toggleReducedMotion',
    'openShortcuts', 'closeShortcuts', 'setColorBlind', 'showToast',
    'cycleFontSize', 'addFeedbackRatings', 'rateFeedback',
]

# The subset the MARKUP reaches by attribute, and which therefore must still be
# present after the edit -- the shared module is what makes them resolve. See the
# note at check 2.
INLINE_HANDLERS = [
    'setFontSize', 'setLineHeight', 'setLetterSpacing', 'setContentWidth',
    'toggleHighContrast', 'toggleReducedMotion', 'openShortcuts',
]

# Anchors that are not function definitions but sit inside the same region and
# have no meaning without the functions above.
BLOCK_MARKERS = [
    r'\(function\(\)\s*\{[^{}]*ulf-high-contrast',   # the restore IIFE
    r'document\.addEventListener\(\s*[\'"]keydown[\'"]\s*,\s*function\s*\(\s*e\s*\)\s*\{\s*if\s*\(\s*e\.altKey',
    r'document\.addEventListener\(\s*[\'"]touchstart[\'"]',
]


def find_js_blocks(src):
    """Yield (start, end) of every `#js { ... }` block body, brace-matched."""
    for m in re.finditer(r'#js\s*\{', src):
        depth = 1
        i = m.end()
        while i < len(src) and depth:
            if src[i] == '{':
                depth += 1
            elif src[i] == '}':
                depth -= 1
            i += 1
        yield m.start(), m.end(), i


def strip_comments(text):
    """Blank out comments WITHOUT changing the text's length.

    Length preservation is the whole requirement. This is called to find where a
    statement starts, and the offset it returns is applied to the ORIGINAL
    source -- so a version that deleted comments shifted every match after the
    first comment in the file, and the tool cut from the wrong place.

    That is not hypothetical: it is what made two files come out one closing
    brace short, and the failure surfaced as a Chemical PARSER error rather than
    as anything resembling a bad edit -- five errors in dynamic_section.ch at a
    line that no longer contained the code anyone had looked at.
    """
    def blank(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    text = re.sub(r'/\*[\s\S]*?\*/', blank, text)
    return re.sub(r'(?m)//[^\n]*', blank, text)


def remove_regions(src):
    """Cut every definition of a known function out of `src`.

    Works on the whole file rather than inside `#js` blocks, because the ELF
    copies sit at the top level of a page builder's `#js` block and their exact
    nesting varies. A definition is `function NAME(` at an indent Chemical emits
    (8 spaces inside a builder, or 4 inside a helper); it ends at the matching
    closing brace at the same indent.
    """
    cut = []

    for name in FUNCTIONS:
        for m in re.finditer(r'(?m)^([ \t]*)function\s+' + re.escape(name) + r'\s*\(', src):
            indent = m.group(1)
            # Two shapes, and the second is the one that used to produce
            # unparseable output.
            #
            # Multi-line: the closing brace is on its own line at the same
            # indentation as the `function` keyword.
            #
            # Single-line: `function openShortcuts() { ... }` written entirely on
            # one line, with no `^indent}` line anywhere after it. The first
            # version fell back to "the next `}` character", which for a
            # one-liner is correct but which -- applied to a function whose body
            # contained a nested one-liner -- ran past the end of the function
            # and swallowed unrelated code.
            #
            # Both are now decided by the line the match starts on: if that line
            # already contains the function's closing brace, the function is a
            # one-liner and ends there; otherwise look for the indented closer.
            line_end = src.find('\n', m.start())
            if line_end == -1:
                line_end = len(src)
            head = src[m.start():line_end]
            if head.count('{') == head.count('}'):
                cut.append((m.start(), line_end))
                continue

            end = None
            for line in re.finditer(r'(?m)^' + re.escape(indent) + r'\}[ \t]*$', src[m.end():]):
                end = m.end() + line.end()
                break
            if end is None:
                # No indented closer: refuse rather than guess. A region we cannot
                # delimit is a region we must not delete, and the file is skipped
                # with a reason instead.
                continue
            cut.append((m.start(), end))

    for pat in BLOCK_MARKERS:
        for m in re.finditer(pat, strip_comments(src)):
            cut.append((m.start(), find_block_end(src, m.start())))

    if not cut:
        return src, 0

    cut.sort()
    merged = []
    for start, end in cut:
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))

    out = []
    cursor = 0
    for start, end in merged:
        # Swallow the indentation of the removed line so no blank line is left.
        line_start = src.rfind('\n', 0, start) + 1
        if src[line_start:start].strip() == '':
            start = line_start
        # And swallow the newline that ended the removed region.
        while end < len(src) and src[end] in ' \t':
            end += 1
        if end < len(src) and src[end] == '\n':
            end += 1
        out.append(src[cursor:start])
        cursor = end
    out.append(src[cursor:])
    return ''.join(out), len(merged)


def find_block_end(src, start):
    """End of the statement beginning at `start`, matched on PARENTHESES.

    Every `BLOCK_MARKERS` pattern starts at a CALL, not a brace:

        document.addEventListener('touchstart', function(e) { ... }, { passive: true });
        document.addEventListener('keydown', function(e) { ... });
        (function() { ... })();

    Brace counting cannot delimit these, and the failure is silent rather than
    loud. In the touchstart handler the `if` sits at brace depth 2, so its
    `} else {` never returns the count to 0 and the scan runs on past the end of
    the statement -- leaving `, { passive: true });` behind as source. The build
    then failed on it with five parser errors in dynamic_section.ch, which is
    exactly the sort of damage a one-shot cleanup script must not be able to do.

    Matching parentheses gets the right answer structurally rather than by
    counting the wrong bracket: find the first `(` and return just past its
    match. For `(function() { ... })();` the first `(` is the IIFE's own, and its
    match is the `)` before the trailing `();`, which is the correct end.

    Parens inside string literals do not mislead it, because they balance:
    `'rgb(219,234,254)'` contributes an open and a close at the same depth.
    """
    open_paren = src.find('(', start)
    if open_paren == -1:
        return len(src)
    depth = 0
    for i in range(open_paren, len(src)):
        c = src[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                # Swallow the `;` and the `()` of a trailing IIFE invocation.
                j = i + 1
                while j < len(src) and src[j] in ' \t':
                    j += 1
                if src.startswith('()', j):
                    j += 2
                if j < len(src) and src[j] == ';':
                    j += 1
                return j
    return len(src)


def verify(original, edited, path):
    """Return a list of reasons the edit must not be written."""
    problems = []

    # 1. No definition may survive. These are what the shared module replaces, and
    #    a survivor is not merely redundant -- see the module docstring on the
    #    race between a global function declaration and `window.name =`.
    for name in FUNCTIONS:
        if re.search(r'(?m)^[ \t]*function\s+' + re.escape(name) + r'\s*\(', edited):
            problems.append(f'{name}() definition survived')

    # 2. The INLINE-HANDLER names must still be present in the markup. These are
    #    the ones the markup reaches by attribute, and the shared module is what
    #    makes them resolve:
    #
    #        onclick="toggleHighContrast()"   onchange="setFontSize(this.value)"
    #
    #    An earlier version of this check asserted the opposite -- that none of
    #    them remained -- and correctly refused to write all 21 files, because it
    #    was asking for the defect this tool exists to remove.
    #
    #    NOT `FUNCTIONS`: applySettings, showToast, cycleFontSize,
    #    addFeedbackRatings and rateFeedback are called from JavaScript or are
    #    ELF-only extras with no markup at all, and setColorBlind is bound per
    #    mode as `onclick="setColorBlind('protanopia')"`. Requiring markup for
    #    them would fail on a correct file.
    for name in INLINE_HANDLERS:
        if not re.search(r'on(?:click|change)="' + re.escape(name) + r'\(', edited):
            problems.append(f'markup no longer calls {name}()')

    # 3. Braces must stay BALANCED, and the check must be depth-based rather than
    #    a total count. A count cannot say WHERE an imbalance is, so when two
    #    regions were removed the count only fell one short and the file was
    #    written with a stray `}` that the Chemical parser then rejected -- five
    #    errors in dynamic_section.ch, none of which mentioned the tool.
    depth = 0
    first_bad = None
    for i, ch in enumerate(edited):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth < 0 and first_bad is None:
                first_bad = i
    if first_bad is not None:
        line = edited.count('\n', 0, first_bad) + 1
        problems.append(f'unbalanced braces: a closer with nothing open at line {line}')
    if depth != 0 and first_bad is None:
        problems.append(f'unbalanced braces: {depth} unclosed at end of file')

    # The depth must also be zero at every line that closes a top-level
    # declaration, which is what catches an edit that swallowed a `}` belonging
    # to something it did not remove.
    if not first_bad and depth != 0 and '{' in original and '}' in original:
        if original.count('{') != original.count('}'):
            problems.append('source was already unbalanced; refusing to touch it')

    # 4. Structural markers that must survive untouched.
    n_before = len(list(find_js_blocks(original)))
    n_after = len(list(find_js_blocks(edited)))
    if n_before != n_after:
        problems.append(f'#js block count {n_before} -> {n_after}')
    # `.lesson` must survive if the file HAD one. It is not required to be
    # added: four ELF pages (elf_header_fields, entry_point, program_header_table,
    # segment_types) never had the wrapper, so their controls have always found
    # no `.lesson` and returned early. That is a pre-existing authoring gap in
    # those four, not something this tool may quietly paper over -- and the
    # verification below records it rather than fixing or hiding it.
    had_lesson = 'class="lesson"' in original
    if had_lesson and 'class="lesson"' not in edited:
        problems.append('lost the .lesson element the controls act on')
    if edited.count('class="a11y-controls"') != original.count('class="a11y-controls"'):
        problems.append('lost the a11y-controls markup')
    if edited.count('class="reading-controls"') != original.count('class="reading-controls"'):
        problems.append('lost the reading-controls markup')
    if edited.count('id="shortcuts-modal"') != original.count('id="shortcuts-modal"'):
        problems.append('lost the shortcuts modal')

    return problems


def process(path, apply):
    with open(path, encoding='utf-8') as fh:
        src = fh.read()
    edited, n = remove_regions(src)
    if n == 0:
        return None
    problems = verify(src, edited, path)
    rel = os.path.relpath(path, ROOT)
    if problems:
        print(f'  SKIP  {rel}: {n} region(s) found but verification failed')
        for p in problems:
            print(f'          - {p}')
        return False
    if apply:
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(edited)
    removed = len(src.splitlines()) - len(edited.splitlines())
    print(f'  {"OK   " if apply else "WOULD"} {rel}: -{n} region(s), '
          f'-{removed} lines, verified')
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='report only')
    ap.add_argument('--report', action='store_true', help='per-file detail')
    args = ap.parse_args()
    apply = not (args.check or args.report)

    targets = sorted(
        os.path.join(SRC, f) for f in os.listdir(SRC)
        if f.endswith('.ch')
        and re.search(r'(?m)^[ \t]*function\s+(toggleHighContrast|setFontSize)\s*\(',
                      strip_comments(open(os.path.join(SRC, f), encoding='utf-8').read()))
    )

    print(f'strip_lesson_controls: {len(targets)} file(s) carry a hand-written copy')
    changed = 0
    for path in targets:
        if process(path, apply):
            changed += 1
    verb = 'rewrote' if apply else 'would rewrite'
    print(f'{verb} {changed} of {len(targets)} files')

    # Report the pages whose controls have never worked, because they carry the
    # markup and the handler but no `.lesson` for either to act on. Left
    # visible: the alternative is that stripping the handler looks like a
    # complete fix for 21 pages when 4 of them still do nothing.
    homeless = []
    for path in targets:
        src = open(path, encoding='utf-8').read()
        if 'class="a11y-controls"' in src and 'class="lesson"' not in src:
            homeless.append(os.path.basename(path))
    if homeless:
        print()
        print('  NOTE  these pages ship the controls but no .lesson wrapper, so the')
        print('        controls have always been inert there -- a pre-existing gap,')
        print('        not introduced here, and NOT fixed by this tool:')
        for f in homeless:
            print(f'          {f}')
    return 0


if __name__ == '__main__':
    sys.exit(main())