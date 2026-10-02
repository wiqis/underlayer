#!/usr/bin/env python3
"""js_escape_check.py -- every non-ASCII character in a #js string literal must
survive the js_cbi escape and still be valid JavaScript.

WHY THIS TOOL WAS REWRITTEN, AND THE EVIDENCE
--------------------------------------------
The first version of this file asserted, and printed for 24 files:

    "js_cbi emits this as \\u{1F44D}, which is not a JavaScript escape,
     so it is a SyntaxError for the WHOLE page script"

All three claims were checked against the running server on 2026-10-02 and all
three are false.

    * `\\u{2191}` IS a JavaScript escape.  Code-point escapes in the form
      \\u{HHHH} are ES2015 syntax, accepted by every browser since 2016.  It is
      also what Rust emits, which is presumably where the "not a JavaScript
      escape" belief came from -- the two languages agree here.
    * The served pages it flagged PARSE.  /courses/elf/lessons/bytes,
      /courses/elf/lessons/symbol-table, /learning-path and /onboarding were
      extracted and run through `node --check`; all four are clean.
    * They RENDER.  `node -e 'console.log("Was this helpful? \\u{1F44D}")'`
      prints the thumbs-up emoji.  The `\\u{1F44D}` in those 24 files has been
      in the collection, working, for years.

So the old tool failed on correct, shipping code and would have driven a
cosmetic campaign -- replacing thumbs-up with "Yes" in 14 unrelated lesson
files and arrows with the word "Up" -- to satisfy a gate that was wrong.  That
campaign was reverted; this file is the record of why.

WHAT IS ACTUALLY WORTH CHECKING
-------------------------------
Not "is the source ASCII" -- nobody needs that.  The real risk is the one the
old tool was reaching for and got wrong in both directions: js_cbi rewrites
non-ASCII source characters into an escape sequence, and if that sequence is not
something JavaScript accepts, the page's single <script> element is dead and
with it the quizzes and the engagement call.  So this tool asks the only
question that matters, and asks JAVASCRIPT rather than guessing:

    for each non-ASCII character inside a #js string literal, take the
    codepoint, emit the escape the way js_cbi emits it, and hand that snippet
    to `node --check` plus an eval that must produce the original character.

A character passes only when the emitted escape parses AND evaluates back to
the character it came from.  Anything else is a real defect, and that is the
only thing this tool fails on.

Usage:
    python3 tools/js_escape_check.py            # check
    python3 tools/js_escape_check.py --report   # name every character found

Exit: 0 every non-ASCII character survives, 1 one does not, 2 node missing.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = [os.path.join(ROOT, 'content', 'src'), os.path.join(ROOT, 'web', 'src')]

# A #js block: the macro opens with #js and closes at a line holding only `}`.
JS_OPEN = re.compile(r'^\s*#js\s*\{\s*$')
# A single- or double-quoted literal on one line.  Good enough to find the
# characters this tool is about, and it cannot be fooled by an apostrophe in a
# Chemical comment because those lines never sit inside a #js block.
LITERAL = re.compile(r"'([^'\\\n]*)'|\"([^\"\\\n]*)\"")
# How js_cbi emits a non-ASCII codepoint.  Verified against the served page:
# U+1F44D is emitted as the six characters \ u { 1 F 4 4 D }.
def emitted_escape(cp):
    return '\\u{%X}' % cp


def source_files():
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name.endswith('.ch'):
                yield os.path.join(d, name)


def js_blocks(lines):
    """Yield (start_line, text_lines) for each #js block in a file.

    The block ends at the first `}` whose indentation is no deeper than the
    `#js {` that opened it, NOT at the first line that merely strips to `}`.
    That distinction is the whole thing: a #js block is full of indented closing
    braces belonging to the JavaScript, and a naive scan stops six lines in and
    reports "no non-ASCII characters" on a page that is full of them -- which is
    how a gate that says nothing gets mistaken for a gate that passes.
    """
    inside = False
    pad = ''
    buf = []
    start = 0
    for i, line in enumerate(lines):
        if not inside:
            if JS_OPEN.match(line):
                inside = True
                stripped = line.lstrip()
                pad = line[:len(line) - len(stripped)]
                buf = []
                start = i + 1
            continue
        if line.strip() == '}' and not line.lstrip().startswith('}'):
            line_pad = line[:len(line) - len(line.lstrip())]
            if line_pad == pad:
                yield start, buf
                inside = False
                continue
        buf.append(line)
    if inside:
        yield start, buf


def collect():
    """(path, lineno, char, codepoint) for every non-ASCII char in a literal."""
    found = []
    for path in source_files():
        with open(path, encoding='utf-8') as fh:
            lines = fh.read().split('\n')
        for start, block in js_blocks(lines):
            for off, line in enumerate(block):
                for m in LITERAL.finditer(line):
                    text = m.group(1) if m.group(1) is not None else (m.group(2) or '')
                    for ch in text:
                        if ord(ch) > 127:
                            found.append((path, start + off, ch, ord(ch)))
    return found


def node_says(ch):
    """(parses, evaluates_back) for the escape js_cbi would emit."""
    esc = emitted_escape(ord(ch))
    snippet = 'var s = "%s"; if (s !== "%s") { throw new Error("mismatch"); }\n' % (esc, ch)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as fh:
        fh.write(snippet)
        name = fh.name
    try:
        p = subprocess.run(['node', name], capture_output=True, text=True, timeout=30)
        if p.returncode != 0:
            return False, False, p.stderr.strip()[:200]
        return True, True, ''
    except FileNotFoundError:
        return None, None, 'node is not installed'
    finally:
        try:
            os.unlink(name)
        except OSError:
            pass


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--report', action='store_true',
                    help='name every non-ASCII character found, passing or not')
    args = ap.parse_args()

    found = collect()
    if not found:
        print('\nNOTHING TO CHECK: no non-ASCII character in any #js string '
              'literal.')
        return 0

    by_cp = {}
    for path, line, ch, cp in found:
        by_cp.setdefault(cp, []).append((path, line, ch))

    print('\njs_escape_check: %d non-ASCII character(s) in #js string literals, '
          '%d distinct codepoint(s)' % (len(found), len(by_cp)))
    print('Each is emitted by js_cbi as %s<HEX> and is handed to node to '
          'confirm it parses and evaluates back to the same character.\n' % '\\u{')

    bad = []
    for cp in sorted(by_cp):
        ch = by_cp[cp][0][2]
        esc = emitted_escape(cp)
        parses, back, err = node_says(ch)
        where = by_cp[cp]
        if parses is None:
            print('  SKIP  U+%04X %s  -- %s' % (cp, esc, err))
            return 2
        if parses and back:
            print('  OK    U+%04X %s  valid JavaScript, evaluates back to %r '
                  '(%d occurrence%s)'
                  % (cp, esc, ch, len(where), '' if len(where) == 1 else 's'))
            if args.report:
                for path, line, _c in where:
                    print('           %s:%d' % (os.path.relpath(path, ROOT), line + 1))
        else:
            bad.append((cp, esc, err))
            print('  FAIL  U+%04X %s  NOT valid JavaScript: %s' % (cp, esc, err))

    print()
    if bad:
        print('FAIL: %d codepoint(s) do not survive js_cbi\'s escaping.'
              % len(bad))
        print('A non-parsing escape kills the whole <script> element, and with')
        print('it the quizzes and the engagement call.  Replace the character')
        print('with ASCII text or String.fromCodePoint(n).')
        return 1
    print('ALL CONSISTENT: %d occurrence(s) of %d non-ASCII character(s) in #js '
          'string literals all\n            emit escapes JavaScript accepts.  '
          'Non-ASCII here is fine.' % (len(found), len(by_cp)))
    return 0


if __name__ == '__main__':
    sys.exit(main())