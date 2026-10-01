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
#
# The character class was widened on 2026-10-01, and the reason is worth
# recording because the narrow version was not wrong about braces -- it was
# wrong about what an EXPRESSION contains.  It allowed letters, digits, `.`,
# `_`, `(`, `)`, `[`, `]` and spaces, which covers `{esc_title}` and
# `{concept_count}` and nothing else, so a page whose interpolation passes a
# function call -- `{render_all_cards(&catalog, &mut page)}` -- was reported as
# containing two raw braces it does not contain.  A linter that cries wolf on
# correct code is a linter that gets deleted, and this one is worth keeping.
# The pair still has to be complete, and the value may now start with a DIGIT
# as well as a letter: `#universal` components take `max={100.0}` and
# `value={health.health_score * 100}`, and the `*` was missing from the class
# too.  Both spellings are in web/src/handlers_dashboard.ch, a committed file
# that builds, so the tool was reporting six raw braces it did not have.  A
# lone `{` is still reported, which is the case the tool exists for.
INTERP = re.compile(r"\{[A-Za-z_0-9][A-Za-z0-9_.()\[\] &'*:!,.<>/=-]*\}")

# html_cbi statement blocks: `@if(cond) { ... } @else { ... }` and `@}`.
#
# The braces of a statement block are not raw braces and never were: the macro
# lexes `@if(` as a Chemical node and the `{` after it as that statement's
# block, which is the documented form (see the collection's own html_cbi tests
# at lang/tests/compiler_plugins/html/src/to_string.ch, `if_works_1`).  This
# exemption was added on 2026-10-01 for the same reason as INTERP above -- the
# pages that use conditionals inside a block were reported as broken while
# building cleanly.  `@{` is deliberately NOT here: docs/implementation-gaps.md
# records `@{}` as a parse failure, so an `@{` in a block IS the hazard this
# tool exists for and it stays reported.
STMT_IF = re.compile(r"@\s*(?:if|else|while)\s*\([^\n]*?\)\s*\{")
STMT_ELSE = re.compile(r"\}\s*@\s*else\s*\{")

# The "expressive string" form of an interpolated value: a backtick-quoted
# Chemical string with `${}` holes in it, e.g.
# ``href={`/courses/${dep_esc}`}``.  Documented and tested by html_cbi
# (`expressive_strings_work` in lang/tests/compiler_plugins/html/src/
# to_string.ch), so it is legal markup rather than a brace pair that happens to
# be balanced.  Same reasoning as INTERP: the pattern has to be recognised, or
# the tool reports two braces the file does not contain.
TEMPLATE = re.compile(r"\{`[^`]*`\}")


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
        # Statement blocks first: `@if(cond) {` must go before INTERP runs, or
        # the `@` prefix keeps the pair from matching and both braces are then
        # reported.  Order matters here and is the only order that works.
        text = STMT_IF.sub(" @STMT@ ", text)
        text = STMT_ELSE.sub(" @STMT@ ", text)
        text = TEMPLATE.sub(" ", text)
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
