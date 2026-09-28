#!/usr/bin/env python3
"""bracecheck.py -- the one build rule that silently breaks the compiler.

NEVER a raw `{` or `}` inside a `#html { }` block.  The macro's brace counter
sees the C function body and ends the HTML block early, and the failure is not
a clean error: the rest of the page is emitted as text and the page still
returns 200, so the damage shows up as a lesson with a code fragment in the
middle of it rather than as a build failure.

tools/html_balance.py catches the SYMPTOM (a brace outside <pre>).  This
catches the CAUSE, for every #html block in a set of files, and is cheap enough
to run on every edit.

Usage:  python3 tools/bracecheck.py content/src/simd_*.ch
        python3 tools/bracecheck.py            # every concept file
"""
import re
import sys
import glob

# An #html block starts with `#html {` and ends at the next line that is only
# a closing brace, which in this codebase is written indented (`    }`).
BLOCK = re.compile(r"^\s*#html \{$")
CLOSE = re.compile(r"^\s*\}$")
# Anything inside a quoted HTML attribute value.  A JS arrow function inside
# onclick="..." legitimately contains braces, and counting those is the
# difference between a tool that is run on every edit and one that is run once.
ATTR = re.compile(r"=\"[^\"]*\"")
# Chemical interpolation inside a #html block: `{expr}`.  Required, not a bug.
INTERP = re.compile(r"\{[A-Za-z_][A-Za-z0-9_.()\[\] ]*\}")


def check(path):
    bad = []
    inside = False
    in_pre = False
    lineno = 0
    for raw in open(path, "r", errors="replace"):
        lineno += 1
        if not inside:
            if BLOCK.match(raw.rstrip("\n")):
                inside = True
            continue
        # A line that is nothing but a closing brace ends the block.
        if CLOSE.match(raw.rstrip("\n")):
            inside = False
            continue
        # Code inside a <pre> element is CODE, and code has braces.  That is
        # the whole reason the escaping rule exists and those files escaped
        # them; counting them would make the tool useless.  A <pre> that opens
        # and closes on the same line is skipped entirely; one that opens here
        # and closes later turns the skipping on until the </pre>.
        if re.search(r"<pre[\s>].*</pre>", raw):
            continue
        if re.search(r"<pre[\s>]", raw):
            in_pre = True
            continue
        if in_pre:
            if re.search(r"</pre>", raw):
                in_pre = False
            continue
        # Strip HTML attribute values before looking for braces.  A JS arrow
        # function inside onclick="..." legitimately contains them, and
        # counting those is the difference between a tool that is run on every
        # edit and one that is run once.  Then strip Chemical's own
        # interpolation syntax, `{identifier}`, which is how a #html block
        # embeds a value at all and is required rather than accidental.
        text = ATTR.sub(" ", raw)
        text = text.replace("&quot;", " ")
        text = INTERP.sub(" ", text)
        for ch in ("{", "}"):
            if ch in text:
                bad.append((lineno, ch, raw.rstrip("\n")[:70]))
    return bad


def main():
    files = sys.argv[1:] or sorted(
        glob.glob("content/src/*.ch") + glob.glob("courses/*/src/*.ch"))
    problems = 0
    for f in files:
        bad = check(f)
        if bad:
            problems += len(bad)
            print("  %s: %d raw brace(s) inside a #html block" % (f, len(bad)))
            for lineno, ch, text in bad:
                print("      line %-5d %r   %s" % (lineno, ch, text))
        else:
            print("  %-44s ok" % f)
    print("")
    if problems:
        print("PROBLEMS: %d raw brace(s).  Use &#123; and &#125;." % problems)
        return 1
    print("ALL CLEAR: no raw braces inside any #html block")
    return 0


if __name__ == "__main__":
    sys.exit(main())
