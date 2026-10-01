#!/usr/bin/env python3
r"""Shared primitives for the roadmap-restructure checks.

Two roadmap documents in this repo were reorganised on 2026-10-01 by the same
operation — flat topic sections regrouped into named planned courses, dropping
nothing — and each has a check that exits non-zero the moment an item moves:

    docs/courses-todo.md   738 items, `- [ ]` bullets, 14 planned courses
    docs/music-plan.md     309 items, `* [ ]` bullets,  8 planned courses

The correctness-critical part of those checks is identical, and it is the part
that is easy to get subtly wrong, so it lives here once and both CLIs drive it:

- **A checkbox token is not an item.** A line is an item only if it *starts*
  with the document's bullet marker followed by `[ ]`/`[x]` and a space.
  `docs/courses-todo.md` has nine prose lines that mention `` `[ ]` `` inside a
  table or a sentence; a naive `grep -c '\[.\]'` overcounts them, and so does a
  naive "does this line contain a checkbox" test. A line that looks like an
  item but is written with the *other* bullet marker is reported as `foreign`
  and fails, because otherwise a newly added line would be invisible to both
  the count and the hash.
- **The comparison is a multiset, not a set.** `docs/courses-todo.md` has 15
  titles on two lines each and `docs/music-plan.md` has 8. Deduplicating would
  let a check pass while a line had been deleted, so duplicates are counted
  with multiplicity and never collapsed.
- **The annotation is not part of the title.** Every line carries
  ``  — `slug`, from <section>, concept `<id>` ``, and the title is everything
  before the separator. Comparing titles and not title-plus-annotation is what
  makes the check survive the annotation being reworded.
"""
import hashlib
import re
from collections import Counter

# The separator between an item title and its annotation, as used by both
# documents ("  — `x86simd`, concept `x86-sse`").
ANNOTATION_SEP = "  — "

# A checkbox token anywhere on a line. Its presence alone never makes a line an
# item -- it is how prose that *talks about* checkboxes is recognised and
# excluded.
CHECKBOX_TOKEN = re.compile(r"\[[ x]\]")

# Any markdown checkbox bullet, whichever marker wrote it.
ANY_BULLET = re.compile(r"^\s*[*-] \[[ x]\]")

# A slug in an annotation, anchored immediately after the separator. Hyphens
# allowed: the systems slugs are single words but the music slugs are not
# (`music-foundations`).
SLUG = re.compile(r"^`([a-z0-9][a-z0-9-]*)`")


def item_re(marker):
    """The strict item-line pattern for one document's bullet marker."""
    return re.compile(rf"^{re.escape(marker)} \[( |x)\] (.*)$")


def loose_re(marker):
    """Any line starting with this marker and a checkbox, well formed or not."""
    return re.compile(rf"^\s*{re.escape(marker)} \[.\]")


def read_items(path, marker, annotation_sep=ANNOTATION_SEP):
    """Return (items, malformed, foreign, stray).

    items    -- [(state, title), ...] in document order, annotation stripped
    malformed-- lines with this document's marker whose state char is not ' '
                or 'x', so they are not silently skipped
    foreign  -- lines written as a checkbox item with the *other* bullet marker
    stray    -- prose lines that merely mention a checkbox token

    A count of `items` alone is what a naive line-based counter gets wrong, so
    the three defect lists are returned rather than folded into it.
    """
    strict = item_re(marker)
    loose = loose_re(marker)
    items, malformed, foreign, stray = [], [], [], []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh.read().split("\n"), 1):
            m = strict.match(line)
            if m:
                title = m.group(2).split(annotation_sep, 1)[0]
                items.append((m.group(1), title))
            elif loose.match(line):
                malformed.append((lineno, line))
            elif ANY_BULLET.match(line):
                foreign.append((lineno, line))
            elif CHECKBOX_TOKEN.search(line):
                stray.append((lineno, line))
    return items, malformed, foreign, stray


def canonical(items):
    """The comparable form of an item set: state and title, sorted.

    Sorting is what makes this a multiset comparison; sorting is also why the
    order the restructure put the lines in cannot affect the result.
    """
    return "\n".join(sorted(f"[{s}] {t}" for s, t in items))


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def items_sha(items):
    """sha256 of the item multiset, state included. The whole-set fingerprint.

    This is the number to quote when comparing two revisions of a document: any
    addition, removal, reword, re-tick or move changes it.
    """
    return sha(canonical(items))


def titles_sha(items):
    """sha256 of the item multiset, state excluded.

    Comparing this against `items_sha` says *which kind* of change happened: a
    title hash that moved with a stable item hash is a re-tick, not a reword.
    """
    return sha("\n".join(sorted(t for _, t in items)))


def checked_sha(checked_titles):
    """sha256 of the sorted titles of the ticked items."""
    return sha("\n".join(sorted(checked_titles)))


def slug_counts(path, marker, annotation_sep=ANNOTATION_SEP):
    """Count annotated unchecked lines per course slug.

    Only lines for this document's marker are considered. An unchecked line
    with no slug in it is returned separately, because an un-annotated line is
    an item that has not been assigned to a course.
    """
    unchecked = re.compile(rf"^\s*{re.escape(marker)} \[ \] ")
    counts = Counter()
    unannotated = []
    with open(path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh.read().split("\n"), 1):
            if not unchecked.match(line):
                continue
            m = SLUG.match(line.split(annotation_sep, 1)[1]) \
                if annotation_sep in line else None
            if m:
                counts[m.group(1)] += 1
            else:
                unannotated.append((lineno, line))
    return counts, unannotated


def diff_revisions(items, other, label, other_label):
    """Multiset-and-state diff between two revisions. Returns note lines.

    Three separate questions, because they fail differently:
      - a title only in A        -> added or dropped
      - a title only in B        -> dropped or added
      - the same title, new state -> re-ticked
    """
    notes = []
    a = Counter(t for _, t in items)
    b = Counter(t for _, t in other)
    for text, _ in sorted((a - b).items()):
        notes.append(f"  ONLY IN {label}: {text}")
    for text, _ in sorted((b - a).items()):
        notes.append(f"  ONLY IN {other_label}: {text}")
    sa = Counter(f"[{s}] {t}" for s, t in items)
    sb = Counter(f"[{s}] {t}" for s, t in other)
    for text, _ in sorted((sa - sb).items()):
        notes.append(f"  STATE CHANGED IN {label}: {text}")
    for text, _ in sorted((sb - sa).items()):
        notes.append(f"  STATE CHANGED IN {other_label}: {text}")
    return notes
