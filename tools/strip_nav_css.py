#!/usr/bin/env python3
"""strip_nav_css.py -- remove the seven copies of the navbar stylesheet from web/src.

WHY THIS EXISTS
---------------
content/src/lesson_nav.ch is the one nav component.  It owns its markup, its
styles and its behaviour, and web/src/nav_bar.ch is a two-line delegation to it.
Seven files in web/src nevertheless carried their own copy of the navbar
stylesheet as well -- ~20 rules each, ~280 lines -- and six of those copies
ended in a `@media (max-width: 1300px)` block that set `.nav-links { display:
none }` for a `.hamburger` element that does not exist in the markup and an
`.open` class that no script ever adds.

So on any viewport between 769px and 1300px -- a 1280x800 laptop, the most
common shape there is -- those seven pages rendered the brand and the theme
toggle and nothing else: no way to reach any other page.  tests/src/page_html_
test.ch::test_home_page_has_hamburger_menu passed anyway, because it asserts
the string "hamburger" appears in the body, and it was matching the dead CSS
rule rather than a button.

Keeping a second stylesheet for a component that has one is not a style
preference, it is how those two defects survived a build, a test run and a
review each.  So this deletes the copies and leaves the styling where the
markup is.

WHAT IT REMOVES, EXACTLY
------------------------
Only CSS rules whose selector is a nav selector.  A rule is removed whole
(selector and block), never by line, because several of these files pack two
rules onto one line -- `pages_notes.ch:46` is `.theme-toggle {...}
.theme-toggle:hover {...}` -- and one of them packs a nav rule and a
NON-nav rule onto the same line: `pages_notes.ch:40` is `.skip-link:focus {
top: 0; } :focus-visible { outline: ... }`.  Dropping that line would have
taken the page's only focus ring with it.

A `@media` block left with no rules inside it is removed whole, since an empty
one is noise; a `@media` block that still has rules keeps them.

WHAT IT DOES NOT DO
-------------------
It does not touch content/src/, because the lesson pages get their nav CSS from
the component and never had a copy.  It does not touch `body`, `.container`,
`:focus-visible`, `.btn`, `.hero` or any other rule.  It does not reformat
anything it leaves alone.
"""
import re
import sys

# Selector -> removed.  Every one of these belongs to the nav component and is
# defined there in content/src/lesson_nav_css.ch.
NAV_SELECTORS = [
    "skip-link",
    "navbar",
    "nav-inner",
    "nav-brand",
    "nav-links",
    "nav-link",
    "nav-right",
    "nav-menu",
    "nav-menu-summary",
    "nav-menu-panel",
    "nav-menu-rule",
    "nav-open",
    "nav-toggle",
    "nav-toggle-bars",
    "nav-toggle-text",
    "theme-toggle",
    "theme-icon-light",
    "theme-icon-dark",
    "hamburger",
    "hamburger-line",
]

# A rule BODY.  The selector is whatever text sits between the previous body's
# end and this body's start, which is why this is matched on the body alone:
# several of these files pack four or five rules onto one physical line
# (`pages_achievements.ch:44` holds `body`, `:focus-visible`, `.nav-brand:hover`,
# `.nav-link.active`, `.theme-toggle`, `.theme-icon-dark` and
# `.dark .theme-icon-dark` on one line), so a pattern anchored to a line start
# silently skips everything after the first rule on a line -- which is how the
# first version of this script removed the nav from `home_assets.ch` and left
# all of it behind on `pages_notes.ch`.
#
# `[^{}]*` is safe because no rule body in these files nests braces; the only
# nesting anywhere is `@media`, handled separately below.
BODY = re.compile(r"\{[^{}]*\}")

# State classes that may qualify a nav selector without making it something
# other than a nav selector.
MODIFIERS = {"active", "open", "dark"}


def is_nav_selector(sel: str) -> bool:
    """True when every comma-separated part of `sel` names a nav element."""
    parts = [p.strip() for p in sel.split(",") if p.strip()]
    if not parts:
        return False
    for part in parts:
        # Drop pseudo-classes, pseudo-elements and attribute selectors, then
        # test what is left as a set of class names: every one of them must be a
        # nav element or one of MODIFIERS.  So `.nav-link.active`,
        # `.dark .theme-icon-light` and `.nav-menu[open] .nav-menu-summary::after`
        # all qualify, and `.course-grid` does not.
        bare = re.sub(r"::?[a-zA-Z-]+(\([^)]*\))?", "", part)
        bare = re.sub(r"\[[^\]]*\]", "", bare)
        # Each token is stripped on its own: `".dark .theme-icon-light".split(".")`
        # yields `'dark '` and `' theme-icon-light'`, and comparing those against
        # the sets unstripped is why `.dark .theme-icon-*` survived the first two
        # runs of this script.
        classes = [c.strip() for c in bare.split(".") if c.strip()]
        if not classes:
            return False
        for c in classes:
            if c not in NAV_SELECTORS and c not in MODIFIERS:
                return False
    return True


def split_media(css: str) -> tuple[str, list[tuple[str, str]]]:
    """Replace every `@media` block with a brace-free placeholder token.

    Returns the masked text plus the list of (header, inner) pairs the tokens
    stand for.  Masking first is what makes the rule pass correct: `@media
    (max-width: 1300px) {` opens a brace, so a pattern that scans rule bodies
    left to right treats that brace as the start of the FIRST rule inside the
    block.  Every selector inside a media query is then mis-attributed to
    whatever preceded the `@media`, and the first rule in each block is
    silently skipped -- which is precisely where `.nav-links { display: none; }`
    lived.  A token contains no brace, so a rule either sits outside every media
    query or is handled by that query's own recursion.
    """
    blocks = []
    out = []
    i = 0
    while True:
        m = re.compile(r"@media[^{]*\{").search(css, i)
        if not m:
            out.append(css[i:])
            break
        depth = 1
        j = m.end()
        while j < len(css) and depth:
            if css[j] == "{":
                depth += 1
            elif css[j] == "}":
                depth -= 1
            j += 1
        out.append(css[i:m.start()])
        out.append(f"\x00MEDIA{len(blocks)}\x00")
        # Everything from the start of the line to the `@media`, not just the
        # whitespace in it.  `split_media` hands back `css[m.start():]`, so
        # whatever preceded the keyword -- usually the twelve spaces of
        # indentation -- would otherwise be re-emitted a second time, on top of
        # the `lead +` this function's caller prepends, and the block would come
        # back indented by twice its original column.
        line_start = css.rfind("\n", 0, m.start()) + 1
        lead = css[line_start:m.start()]
        blocks.append((css[m.start():m.end()], css[m.end(): j - 1],
                       lead if not lead.strip() else ""))
        i = j
    return "".join(out), blocks


def strip_rules(css: str) -> tuple[str, int]:
    """Remove nav rules from `css`.  Returns the new text and how many went.

    Media queries are stripped by their own recursion and then substituted back,
    so a rule is judged on its own selector and never on its neighbours'.  A
    block left with no rules inside it is dropped rather than left empty.
    """
    masked, blocks = split_media(css)

    spans = []           # (start, end) to delete, in document order
    removed = 0
    prev_end = 0
    for m in BODY.finditer(masked):
        sel = masked[prev_end:m.start()]
        if is_nav_selector(sel):
            # Where the deletion starts matters for how the file reads
            # afterwards, and the only thing that decides it is `lead` -- the
            # run of whitespace between the end of the previous rule body and
            # the first character of this selector.
            #
            # When the rule began its own line, `lead` is a newline plus
            # indentation, so keeping it leaves the surviving rules in their
            # original column.  When the rule shared a line with the previous
            # one -- and several of these files pack four or five rules per line
            # -- `lead` is a single space, deleting it too is what stops the
            # NEXT rule from ending up indented by one stray space, and the
            # line it was on disappears with it.
            #
            # The start is `prev_end + len(lead)` and nothing else.  The first
            # version of this computed it as `m.start() - len(sel.lstrip())`,
            # which is short by exactly the whitespace between the selector and
            # its `{`: it cut one character into every rule and left the
            # selectors of the mid-line rules behind as orphans, so the files
            # came out with `.nav-brand:hover` and `.nav-right` sitting in the
            # stylesheet attached to nothing.
            lead = sel[: len(sel) - len(sel.lstrip())]
            # The deletion also swallows any spaces and tabs that FOLLOWED the
            # rule body on the same line.  Those spaces belonged to the deleted
            # rule as its separator from whatever came next, so leaving them
            # behind indents the surviving next rule by one column -- the
            # thirteen-space `:focus-visible` in `pages_notes.ch`.  A newline is
            # not consumed, so a rule that had a line to itself keeps it.
            end = m.end()
            while end < len(masked) and masked[end] in " \t":
                end += 1
            spans.append((prev_end + len(lead), end))
            removed += 1
        prev_end = m.end()

    if spans:
        out = []
        cursor = 0
        for start, end in spans:
            out.append(masked[cursor:start])
            cursor = end
        out.append(masked[cursor:])
        masked = "".join(out)

    for idx, (header, inner, lead) in enumerate(blocks):
        cleaned, gone = strip_rules(inner)
        removed += gone
        token = f"\x00MEDIA{idx}\x00"
        if cleaned.strip():
            # Reopen the block on its own line. Squeezing the first rule up
            # against `@media (...) {` saves nothing and makes the block harder
            # to read than it was before the edit.
            #
            # The closing brace is written out here rather than assumed, because
            # `split_media` consumed it: `inner` is the text BETWEEN the block's
            # braces, so a version of this that emitted only `header + body`
            # dropped one `}` per media query and left every stylesheet in these
            # seven files short a brace.
            step = lead + "    "
            # Every line in the block, including the first, goes one step in.
            # `inner` arrives with whatever indentation it had before the edit,
            # and the first line's is the indentation of the rule that used to
            # be first -- which after a deletion at the top of the block belongs
            # to no rule at all.  Re-indenting uniformly is what keeps the
            # block looking hand-written instead of half-reindented.
            body = "\n".join(
                step + ln.strip() for ln in cleaned.strip().split("\n"))
            # `header` alone, with no `lead +` in front of it: `split_media`
            # already left the block's own indentation in `masked`, immediately
            # before the token.  Prepending `lead` as well is what indented
            # every reconstructed media query by twice its original column.
            masked = masked.replace(
                token, header + "\n" + body + "\n" + lead + "}")
        else:
            masked = masked.replace(token, "")

    return masked, removed


def strip_empty_media(css: str) -> tuple[str, int]:
    """Remove @media blocks whose body held only nav rules."""
    removed = 0
    out = []
    i = 0
    while True:
        m = re.compile(r"@media[^{]*\{").search(css, i)
        if not m:
            out.append(css[i:])
            break
        # Walk to the matching close brace.
        depth = 1
        j = m.end()
        while j < len(css) and depth:
            if css[j] == "{":
                depth += 1
            elif css[j] == "}":
                depth -= 1
            j += 1
        body = css[m.end(): j - 1]
        has_rule = re.search(r"\{[^{}]*\}", body) is not None
        out.append(css[i:m.start()])
        if has_rule:
            out.append(css[m.start():j])
        else:
            removed += 1
        i = j
    return "".join(out), removed


def blank_runs(text: str) -> str:
    """Tidy what the deletions left behind.

    Removing a contiguous run of rules leaves a run of empty lines, and a run of
    empty lines inside a `#css` block is noise a reader has to scroll past.
    Whitespace-only lines go entirely; two or more consecutive empty lines
    collapse to one; trailing spaces before a newline go.

    It deliberately does NOT remove a lone blank line between two rules.  A rule
    of thumb that drops "a blank line whose neighbours end in a brace" also
    matches every blank line between two functions in the same file, so it
    reformats the 150 lines of `#js` this tool has no business touching.  One
    leftover blank line is a smaller cost than reindenting a file nobody asked
    about.
    """
    text = "\n".join(line.rstrip() for line in text.split("\n"))
    text = re.sub(r"(?m)^[ \t]+$", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def process(path: str) -> bool:
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    out, n_rules = strip_rules(src)
    out = blank_runs(out)
    if out == src:
        print(f"  {path}: no change")
        return False
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(out)
    before = len(src)
    after = len(out)
    print(f"  {path}: -{n_rules} rules, {before} -> {after} bytes")
    return True


TARGETS = [
    "web/src/home_assets.ch",
    "web/src/dashboard_assets.ch",
    "web/src/pages_analytics.ch",
    "web/src/pages_notes.ch",
    "web/src/pages_achievements.ch",
    "web/src/handlers_review_page.ch",
    "web/src/handlers_progress_page.ch",
]


def main() -> int:
    changed = 0
    for path in TARGETS:
        if process(path):
            changed += 1
    print(f"{changed} of {len(TARGETS)} files changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())