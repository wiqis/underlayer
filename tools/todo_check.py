#!/usr/bin/env python3
"""Prove the courses-todo.md restructure dropped nothing.

The 2026-10-01 restructure reorganised 678 un-started roadmap items out of 35
flat sections into 14 planned courses. The one failure mode that matters is
silent: a reorganisation that merges, rewords, re-ticks or drops a single line
still *looks* fine in a diff. So this check is mechanical and it exits non-zero
the moment anything moves.

Usage:
    python3 tools/todo_check.py
    python3 tools/todo_check.py --against <other-file>   # diff two revisions
    python3 tools/todo_check.py --quiet

Checks (all must pass for exit 0):
    1. total items 738, checked 60, unchecked 678
    2. every item line is well formed: "- [ ] " or "- [x] " + text
    3. the MULTISET of item texts, sorted, hashes to BASELINE_ALL_SHA256
       -- so nothing was added, removed, reworded, re-ticked, or merged
       into a neighbouring bullet
    4. the 60 checked texts hash to BASELINE_CHECKED_SHA256
    5. every unchecked line carries an annotation naming one of the 14 slugs
    6. the per-slug item counts are exactly EXPECTED_COURSE_COUNTS and sum
       to 678, which is what the summary table in the document claims

The multiset, not the set: sixteen titles appear on two roadmap lines each, so
a check that deduplicated would pass while a line had been deleted.
"""
import argparse
import hashlib
import os
import re
import sys
from collections import Counter

DOC = "docs/courses-todo.md"

# The separator between an item title and its annotation. It is the separator
# the completed sections already use ("  — `x86simd`, concept `x86-sse`"), so
# the title is everything before it. No item title in the roadmap contains it.
ANNOTATION_SEP = "  — "

# Recorded from HEAD on 2026-10-01, before the restructure was written, over
# item TITLES (annotation stripped).
BASELINE_ALL_SHA256 = "72380c53e5233b4d724fcfd965adb5e61f55335e7a51e6483afa0741539dc836"
BASELINE_CHECKED_SHA256 = "ee4eed31955954ba2ebbcd57cab45f3209488843c9298c316cfeb1edd4cdc484"
EXPECTED_TOTAL = 738
EXPECTED_CHECKED = 60
EXPECTED_UNCHECKED = 678

# The 14 planned courses and the item count the document claims for each.
EXPECTED_COURSE_COUNTS = {
    "os": 64,
    "hwboot": 39,
    "memconc": 60,
    "storage": 44,
    "network": 52,
    "crypto": 53,
    "encodings": 59,
    "compiler": 67,
    "vm": 63,
    "data": 41,
    "graphics": 29,
    "media": 31,
    "debugio": 46,
    "distsys": 30,
}

ITEM_RE = re.compile(r"^- \[( |x)\] (.*)$")
SLUG_RE = re.compile(r"^\s*-\s*\[ \]\s.*?—\s*`([a-z0-9]+)`")


def read_items(path):
    """Return (items, malformed_lines). items = [(state, title), ...].

    The annotation after ANNOTATION_SEP is deliberately NOT part of the title:
    the restructure appends one to every un-started line, and the invariant is
    that the TITLE of every item is unchanged. Stripping it is what makes the
    comparison a comparison of titles and not of titles-plus-annotations.
    """
    items = []
    malformed = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh.read().split("\n"), 1):
            if re.match(r"^- \[.\]", line):
                m = ITEM_RE.match(line)
                if not m:
                    malformed.append((lineno, line))
                else:
                    rest = m.group(2)
                    title = rest.split(ANNOTATION_SEP, 1)[0]
                    items.append((m.group(1), title))
    return items, malformed


def canonical(items):
    return "\n".join(sorted(f"[{s}] {t}" for s, t in items))


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def slug_counts(path):
    """Count annotated unchecked lines per course slug."""
    counts = Counter()
    unannotated = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh.read().split("\n"), 1):
            if not line.startswith("- [ ] "):
                continue
            m = SLUG_RE.match(line)
            if m:
                counts[m.group(1)] += 1
            else:
                unannotated.append((lineno, line))
    return counts, unannotated


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", nargs="?", default=DOC)
    ap.add_argument("--against", help="a second revision to diff item sets against")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    failures = []
    notes = []

    items, malformed = read_items(args.path)
    checked = [t for s, t in items if s == "x"]
    unchecked = [t for s, t in items if s == " "]

    if malformed:
        for lineno, line in malformed:
            failures.append(f"malformed item line {lineno}: {line!r}")

    if len(items) != EXPECTED_TOTAL:
        failures.append(f"total items {len(items)}, expected {EXPECTED_TOTAL}")
    if len(checked) != EXPECTED_CHECKED:
        failures.append(f"checked items {len(checked)}, expected {EXPECTED_CHECKED}")
    if len(unchecked) != EXPECTED_UNCHECKED:
        failures.append(f"unchecked items {len(unchecked)}, expected {EXPECTED_UNCHECKED}")

    all_hash = sha(canonical(items))
    if all_hash != BASELINE_ALL_SHA256:
        failures.append(f"item multiset hash {all_hash}, expected {BASELINE_ALL_SHA256}")

    checked_hash = sha("\n".join(sorted(checked)))
    if checked_hash != BASELINE_CHECKED_SHA256:
        failures.append(f"checked-item hash {checked_hash}, expected {BASELINE_CHECKED_SHA256}")

    counts, unannotated = slug_counts(args.path)
    for lineno, line in unannotated:
        failures.append(f"unchecked line {lineno} has no course slug: {line[:70]!r}")
    unknown = sorted(set(counts) - set(EXPECTED_COURSE_COUNTS))
    if unknown:
        failures.append(f"unknown course slug(s) in annotations: {unknown}")
    for slug, want in EXPECTED_COURSE_COUNTS.items():
        got = counts.get(slug, 0)
        if got != want:
            failures.append(f"course `{slug}`: {got} annotated items, expected {want}")
    if counts and sum(counts.values()) != EXPECTED_UNCHECKED:
        failures.append(f"annotated items total {sum(counts.values())}, "
                        f"expected {EXPECTED_UNCHECKED}")

    if args.against:
        other, other_malformed = read_items(args.against)
        if other_malformed:
            failures.append(f"{args.against}: {len(other_malformed)} malformed item line(s)")
        diff_notes = []
        a, b = Counter(t for _, t in items), Counter(t for _, t in other)
        for text, n in sorted((a - b).items()):
            diff_notes.append(f"  ONLY IN {args.path}: {text}")
        for text, n in sorted((b - a).items()):
            diff_notes.append(f"  ONLY IN {args.against}: {text}")
        sa = Counter(f"[{s}] {t}" for s, t in items)
        sb = Counter(f"[{s}] {t}" for s, t in other)
        for text, n in sorted((sa - sb).items()):
            diff_notes.append(f"  STATE CHANGED IN {args.path}: {text}")
        for text, n in sorted((sb - sa).items()):
            diff_notes.append(f"  STATE CHANGED IN {args.against}: {text}")
        if diff_notes:
            failures.append("item sets differ between revisions:\n" + "\n".join(diff_notes))
        else:
            notes.append(f"item sets identical to {args.against}")

    if not args.quiet:
        print(f"{args.path}: {len(items)} items, {len(checked)} checked, "
              f"{len(unchecked)} unchecked")
        print(f"  item multiset sha256 {all_hash}")
        print(f"  checked items     sha256 {checked_hash}")
        print(f"  {len(counts)} planned courses: "
              + ", ".join(f"`{s}` {counts[s]}" for s in EXPECTED_COURSE_COUNTS))
        for n in notes:
            print("  " + n)

    if failures:
        print("\nFAIL", file=sys.stderr)
        for f in failures:
            print("  - " + f, file=sys.stderr)
        return 1

    if not args.quiet:
        print("OK - nothing moved")
    return 0


if __name__ == "__main__":
    sys.exit(main())