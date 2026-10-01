#!/usr/bin/env python3
r"""Prove the music-plan.md restructure dropped nothing.

The 2026-10-01 restructure reorganised 309 un-started music curriculum items
out of 15 flat sections into 8 planned courses. The one failure mode that
matters is silent: a reorganisation that merges, rewords, re-ticks, moves or
drops a single line still *looks* fine in a diff. So this check is mechanical
and it exits non-zero the moment anything moves.

It is the same operation, and the same check, as `tools/todo_check.py` runs
against the systems roadmap -- so the correctness-critical parts live in
`tools/todo_check_core.py` and are shared rather than copied. This document
needed a check of its own for two reasons: its items are `* [ ]` bullets, not
`- [ ]`, and its baseline counts are 309/0 rather than 738/60.

Usage:
    python3 tools/music_todo_check.py
    python3 tools/music_todo_check.py --against <other-file>   # diff two revisions
    python3 tools/music_todo_check.py --quiet

Checks (all must pass for exit 0):
    1. total items 309, checked 0, unchecked 309
    2. every item line is well formed: "* [ ] " or "* [x] " + text
    3. the MULTISET of item TITLES, sorted, hashes to BASELINE_TITLES_SHA256
       -- so nothing was added, removed, reworded, or merged into a
       neighbouring bullet
    4. the item states hash to BASELINE_STATES_SHA256, so nothing was
       re-ticked
    5. every unchecked line carries an annotation naming one of the 8 slugs
    6. the per-slug item counts are exactly EXPECTED_COURSE_COUNTS and sum to
       309, which is what the summary table in the document claims

Two traps this check is built around, both already hit in this repo:

  - **A checkbox token is not an item.** `docs/courses-todo.md` has nine prose
    lines that mention `` `[ ]` `` in a table or a sentence. Matching item
    lines on a leading bullet plus `[ ]` plus a space is what keeps prose out
    of the count, and a line that uses the *other* bullet marker is a hard
    failure rather than a silent omission.
  - **The comparison is a multiset, not a set.** Eight titles sit on two lines
    each in this document ("Learn Musical Phrases", "Learn Sonata Form",
    "Learn Suspensions", "Learn Theme and Variations", "Learn Motif
    Development", and "Learn Writing for Orchestra" / "for Piano" / "for
    String Quartet"). A set-based check would pass while one of a pair had been
    deleted. The founder said teach everything, not miss anything, so a
    duplicate is a genuine repeat and is never collapsed. The 8 pairs share
    concept ids and each line says so.

Print the multiset sha256 so a future edit can be compared against it.
"""
import argparse
import sys

from todo_check_core import (
    ANNOTATION_SEP,
    diff_revisions,
    items_sha,
    read_items,
    slug_counts,
    titles_sha,
)

DOC = "docs/music-plan.md"
MARKER = "*"  # this document's items are `* [ ]`, not `- [ ]`

# Recorded from HEAD on 2026-10-01, before the restructure was written.
# Titles only, and states only, kept as two hashes so that a reword and a
# re-tick are distinguishable failures.
BASELINE_TITLES_SHA256 = "e1ef2cc2e34dee1b592133ed406329654afcf279eb7dd58d0a4ecef4bb8f25a2"
BASELINE_STATES_SHA256 = "d354797a3d684b59532d86506e0cc377e4495cfed982d361a1da6761c5c8c03a"
EXPECTED_TOTAL = 309
EXPECTED_CHECKED = 0
EXPECTED_UNCHECKED = 309

# The 8 planned courses and the item count the document claims for each.
EXPECTED_COURSE_COUNTS = {
    "music-foundations": 34,
    "music-harmony": 37,
    "music-form": 38,
    "music-composition": 47,
    "music-genres": 43,
    "music-orchestration": 22,
    "music-drills": 46,
    "music-integrated": 42,
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

    titles_hash = titles_sha(items)
    if titles_hash != BASELINE_TITLES_SHA256:
        failures.append(f"title multiset hash {titles_hash}, expected {BASELINE_TITLES_SHA256}")
    states_hash = items_sha(items)
    if states_hash != BASELINE_STATES_SHA256:
        failures.append(f"item-state hash {states_hash}, expected {BASELINE_STATES_SHA256}")

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
        print(f"  title multiset     sha256 {titles_hash}")
        print(f"  item states        sha256 {states_hash}")
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
