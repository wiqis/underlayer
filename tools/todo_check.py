#!/usr/bin/env python3
r"""Prove the courses-todo.md restructure dropped nothing.

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
    7. no line is a checkbox item written with the wrong bullet marker, which
       would otherwise be invisible to both the count and the hash

The multiset, not the set: fifteen titles appear on two roadmap lines each, so
a check that deduplicated would pass while a line had been deleted.

The parsing and hashing primitives are shared with `tools/music_todo_check.py`
via `tools/todo_check_core.py`, because the same restructure was applied to the
music curriculum on the same day and the two checks must not be able to drift
apart on the part that is easy to get wrong. Only the profile below -- this
document, its marker, its baselines and its 14 slugs -- is specific to it.
"""
import argparse
import sys

from todo_check_core import (
    ANNOTATION_SEP,
    checked_sha,
    diff_revisions,
    items_sha,
    read_items,
    slug_counts,
)

DOC = "docs/courses-todo.md"
MARKER = "-"  # this document's items are `- [ ]`, not `* [ ]`

# The separator between an item title and its annotation. It is the separator
# the completed sections already use ("  — `x86simd`, concept `x86-sse`"), so
# the title is everything before it. No item title in the roadmap contains it.

# Re-baselined 2026-10-02.  The TITLES have not changed since the restructure --
# 738 in, 738 out, no title only-in-old and none only-in-new, and the
# compback commit that ticked six items changed no text at all.  What changed is
# the CHECKED SET: compback taught Compiler Architecture, Instruction Selection,
# Register Allocation, Instruction Scheduling, Compiler ABIs and Compiler Debug
# Information, so checked went 60 -> 66 and `compiler`'s remaining count 67 -> 61.
#
# This tool was left red by that commit, and a checker that is always failing is
# a checker nobody reads -- which is worse than not having one, because it looks
# like coverage. The constants are the re-baseline, and they are the ONLY thing
# that changed; the parsing and hashing below are untouched.
#
# Recorded 2026-10-01 before the restructure, over item TITLES (annotation
# stripped). Kept for provenance: 72380c53... was the pre-restructure value and
# ee4eed31... the pre-compback checked set.
BASELINE_ALL_SHA256 = "7dab74ccaf58741189adf4b98e202f6edbdd6638732846c3a6f62649ca97290b"
BASELINE_CHECKED_SHA256 = "002b83711658c8e07397ef850be45732157df084b039885baebabe75d7b6cbad"
EXPECTED_TOTAL = 738
EXPECTED_CHECKED = 66
EXPECTED_UNCHECKED = 672

# The 14 planned courses and the item count the document claims for each.
EXPECTED_COURSE_COUNTS = {
    "os": 64,
    "hwboot": 39,
    "memconc": 60,
    "storage": 44,
    "network": 52,
    "crypto": 53,
    "encodings": 59,
    "compiler": 61,
    "vm": 63,
    "data": 41,
    "graphics": 29,
    "media": 31,
    "debugio": 46,
    "distsys": 30,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("path", nargs="?", default=DOC)
    ap.add_argument("--against", help="a second revision to diff item sets against")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    failures = []
    notes = []

    items, malformed, foreign, stray = read_items(args.path, MARKER, ANNOTATION_SEP)
    checked = [t for s, t in items if s == "x"]
    unchecked = [t for s, t in items if s == " "]

    for lineno, line in malformed:
        failures.append(f"malformed item line {lineno}: {line!r}")
    for lineno, line in foreign:
        failures.append(
            f"line {lineno} is a checkbox item under the wrong bullet marker "
            f"(expected {MARKER!r}): {line[:70]!r}")

    if len(items) != EXPECTED_TOTAL:
        failures.append(f"total items {len(items)}, expected {EXPECTED_TOTAL}")
    if len(checked) != EXPECTED_CHECKED:
        failures.append(f"checked items {len(checked)}, expected {EXPECTED_CHECKED}")
    if len(unchecked) != EXPECTED_UNCHECKED:
        failures.append(f"unchecked items {len(unchecked)}, expected {EXPECTED_UNCHECKED}")

    all_hash = items_sha(items)
    if all_hash != BASELINE_ALL_SHA256:
        failures.append(f"item multiset hash {all_hash}, expected {BASELINE_ALL_SHA256}")

    checked_hash = checked_sha(checked)
    if checked_hash != BASELINE_CHECKED_SHA256:
        failures.append(f"checked-item hash {checked_hash}, expected {BASELINE_CHECKED_SHA256}")

    counts, unannotated = slug_counts(args.path, MARKER, ANNOTATION_SEP)
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
        other, o_malformed, o_foreign, _ = read_items(args.against, MARKER, ANNOTATION_SEP)
        if o_malformed:
            failures.append(f"{args.against}: {len(o_malformed)} malformed item line(s)")
        if o_foreign:
            failures.append(f"{args.against}: {len(o_foreign)} item line(s) under "
                            f"the wrong bullet marker")
        diff_notes = diff_revisions(items, other, args.path, args.against)
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
        if stray:
            print(f"  {len(stray)} prose line(s) mention a checkbox token and are "
                  f"correctly not counted as items")
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