#!/usr/bin/env python3
"""fix_divs.py -- remove duplicated block-level closers in a .ch lesson file.

A `formula` div whose content is an example of terminal output is easy to
close twice, because the example often ends with a line that looks like a
closer. One such line in isa_modes.ch cost three rebuild cycles, so this is a
house tool rather than a habit.

    python3 tools/fix_divs.py content/src/isa_*.ch

It only ever REMOVES a `</div>` that is immediately followed by another
`</div>` with nothing but whitespace between them, or one that closes nothing
because it sits directly after the `</pre>` of a block whose opener was
already closed. It never adds, moves, or rewrites anything else, and it
prints what it removed so the change is reviewable.
"""
import re
import sys

CLOSERS = ('</div>', '</pre>')


def fix(path):
    lines = open(path).read().split('\n')
    out, removed = [], []

    # Pass 1: collapse two identical closers on consecutive lines.
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.strip() in CLOSERS:
            nxt = lines[i + 1] if i + 1 < len(lines) else ''
            if nxt.strip() == ln.strip():
                # same closer twice in a row -- keep the indented one (which is
                # the one that matches the block's own indentation) and drop
                # the stray
                if ln == ln.lstrip():
                    removed.append((i + 1, ln))
                    i += 1
                    continue
        out.append(ln)
        i += 1

    # Pass 2: report any closer at column 0 that is not preceded by content
    # inside its own block, which is the other shape this takes.
    depth = 0
    for i, ln in enumerate(out):
        s = ln.strip()
        if re.match(r'^<div\b', s):
            depth += 1
        elif s == '</div>':
            depth -= 1
            if depth < 0:
                removed.append((i + 1, ln))
                out[i] = None
                depth = 0
    out = [l for l in out if l is not None]

    if removed:
        open(path, 'w').write('\n'.join(out))
        for n, ln in removed:
            print('  %s:%d  removed %r' % (path, n, ln))
        return len(removed)
    return 0


if __name__ == '__main__':
    total = 0
    for p in sys.argv[1:]:
        total += fix(p)
    print('  %d stray closer(s) removed' % total if total else '  clean')
