#!/usr/bin/env python3
"""strip_colorblind_restore.py -- delete the last unguarded localStorage read in
the product: the colour-vision restore IIFE that 9 lesson pages each carried.

WHY THIS EXISTS, SEPARATELY FROM strip_lesson_controls.py
---------------------------------------------------------
`strip_lesson_controls.py` removes `function NAME(...)` DEFINITIONS. This one
removes a bare CALL:

    (function(){var cb = localStorage.getItem('ulf-color-blind') || 'none';
                if(cb !== 'none') { setColorBlind(cb); }
                else { var b = document.getElementById('cb-none');
                       if(b) b.classList.add('active'); }})();

There is no `function` keyword for the definition-oriented tool to match, so the
nine copies survived it. And surviving is not neutral: the behaviour they call
now lives in content/src/lesson_controls_js.ch, where the read is guarded, so
these nine are a second, unguarded restore running after the guarded one. With
site data blocked -- a private window, Firefox on file://, Safari ITP -- the read
THROWS, and because it is a top-level statement the throw aborts the rest of that
page's script.

That is not theoretical. tools/lesson_controls_check.py runs the served script
against a localStorage whose access throws, and reported
`ReferenceError: addFeedbackRatings is not defined` on /courses/elf/lessons/bytes
with this line still in place -- every control on the page dead, in exactly the
situation a reader cannot debug and cannot report clearly.

WHAT IS REMOVED
---------------
The IIFE above, and nothing else. The `setColorBlind` DEFINITION and the four
buttons' `onclick` attributes are left alone; the behaviour they call is in the
shared module now.

HOW IT IS VERIFIED
------------------
  * the IIFE is gone
  * the page's `.lesson` wrapper, its `cb-controls` markup and its
    `id="cb-none"` button all survive, so the shared module still has something
    to act on
  * no unguarded top-level `localStorage` statement remains anywhere in the
    file's served script -- re-derived from the source, not trusted from the
    pattern match

Usage:
    python3 tools/strip_colorblind_restore.py           # apply
    python3 tools/strip_colorblind_restore.py --check   # report only
"""
import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'content', 'src')

# The IIFE, matched on what it does rather than on its exact whitespace.
IIFE = re.compile(
    r'\(function\s*\(\s*\)\s*\{\s*'
    r'var\s+cb\s*=\s*localStorage\.getItem\(\s*[\'"]ulf-color-blind[\'"]\s*\)'
    r'[\s\S]*?\}\)\s*\(\s*\)\s*;?')


def strip_comments(text):
    def blank(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    text = re.sub(r'/\*[\s\S]*?\*/', blank, text)
    return re.sub(r'(?m)//[^\n]*', blank, text)


def unguarded_localstorage(src):
    """Top-level statements that touch localStorage with no try/catch.

    Split on `;` at paren/brace/bracket depth zero, ignoring semicolons inside
    string literals -- a `;` in an HTML string built in JS would otherwise split
    a statement in half and hide the thing this is looking for.
    """
    stmts = []
    depth = 0
    cur = []
    quote = None
    i = 0
    while i < len(src):
        c = src[i]
        if quote:
            cur.append(c)
            if c == '\\':
                cur.append(src[i + 1] if i + 1 < len(src) else '')
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in '"\'`':
            quote = c
            cur.append(c)
            i += 1
            continue
        if c in '({[':
            depth += 1
        elif c in ')}]':
            depth -= 1
        if c == ';' and depth == 0:
            stmts.append(''.join(cur))
            cur = []
        else:
            cur.append(c)
        i += 1
    if cur:
        stmts.append(''.join(cur))

    bad = []
    for st in stmts:
        if 'localStorage' not in st:
            continue
        if 'try' in st and 'catch' in st:
            continue
        bad.append(st.strip()[:160])
    return bad


def verify(original, edited, path):
    problems = []
    if IIFE.search(edited):
        problems.append('the unguarded colour-blind IIFE survived')

    for marker, label in [('class="cb-controls"', 'cb-controls markup'),
                          ('id="cb-none"', 'the cb-none button')]:
        if original.count(marker) != edited.count(marker):
            problems.append(f'lost {label}')

    if original.count('<script') and edited.count('<script') != original.count('<script'):
        problems.append('script block count changed')

    remaining = unguarded_localstorage(strip_comments(edited))
    # A `#js` block's own text is the product's, and the checker in this
    # repository treats unguarded storage as a defect, so any survivor is
    # reported by name.
    if remaining:
        problems.append('unguarded localStorage remains: ' + remaining[0])

    return problems


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
        src = open(path, encoding='utf-8').read()
        if IIFE.search(src):
            targets.append((path, src))

    print(f'strip_colorblind_restore: {len(targets)} file(s) carry the unguarded IIFE')
    changed = 0
    for path, src in targets:
        rel = os.path.relpath(path, ROOT)
        edited, n = IIFE.subn('', src)
        # Tidy the blank line the removal leaves behind.
        edited = re.sub(r'\n{3,}', '\n\n', edited)
        problems = verify(src, edited, path)
        if problems:
            print(f'  SKIP  {rel}')
            for p in problems:
                print(f'          - {p}')
            continue
        if apply:
            open(path, 'w', encoding='utf-8').write(edited)
        changed += 1
        print(f'  {"OK   " if apply else "WOULD"} {rel}: -{n} IIFE, verified')

    verb = 'rewrote' if apply else 'would rewrite'
    print(f'{verb} {changed} of {len(targets)} files')
    return 0


if __name__ == '__main__':
    sys.exit(main())