# Course merge plan — 33 courses to fewer, dropping nothing

Requested 2026-10-01: *"we don't want to NOT teach something, but we want to
put more topics into courses... teach less courses, but teach everything
still, NOT miss anything, this way AIs would be able to complete the courses
faster."*

**Invariant: the 392 concepts and their 8,007 minutes do not change. Only the
number of courses they are grouped into.** A merge is a change of *packaging*.
If any merge reduces the concept count or the minute count, that merge is wrong
and must be undone.

## The constraint the founder's own answers create

The founder chose two things on 2026-10-01:

1. **Leave the 12 architecture courses alone** — `x86asm x86abi x86sys
   x86simd a64asm a64abi a64sys a64simd rvasm rvabi rvpriv rvat`.
2. **Merge toward about 14 courses.**

Those are mutually exclusive, and the arithmetic says so. The 20 non-
architecture courses hold **259 concepts**:

| grouping | courses | → | concepts | minutes |
|---|---|---|---|---|
| `elf + pe + macho + coff` | 4 | 1 | 90 | 1502 |
| `wasm + jvm` | 2 | 1 | 31 | 643 |
| `dwarf` | 1 | 1 | 23 | 450 |
| `obj + sym` | 2 | 1 | 30 | 615 |
| `reloc + link + dyn + img` | 4 | 1 | 35 | 790 |
| `isa + exe` | 2 | 1 | 13 | 317 |
| `mem + smp` | 2 | 1 | 15 | 371 |
| `priv + sec + simd` | 3 | 1 | 22 | 557 |
| **non-architecture total** | **20** | **8** | **259** | **5245** |

Plus the 12 architecture courses and `hat`, untouched: **33 → 21**.

**14 is not reachable while the architecture courses stay as they are.** To
reach it, either the architecture courses merge too, or all 259 non-
architecture concepts land in one course. Both were declined or are
indefensible, so 21 is the target and 14 stays as the next one if the
architecture courses are ever reopened.

## Why this grouping and not another

The rule is: **merge courses that are parallel variants of each other, or
consecutive links in one chain.** Do not merge merely because two courses are
both "about computers".

- **The four native formats** are four dialects of one subject. `elf`, `pe`,
  `macho` and `coff` teach the same ideas — header, sections, relocations,
  symbols — in four vocabularies, and `elf` is already the reference every
  other course cites. One course can hold them because the *concepts*
  correspond; a reader who learns ELF can read PE and must be told so, not
  left to work it out.
- **The toolchain is a chain**: object files → symbols → relocations →
  linking → dynamic linking → loading. `obj + sym` is "what is in a file";
  `reloc + link + dyn + img` is "what happens when files are combined".
- **The neutral CPU courses** pair by the question they answer: `isa + exe`
  (what an instruction is and what the machine does with it), `mem + smp`
  (where data lives and who shares it), `priv + sec + simd` (privilege,
  hardening and the wide data path).
- **`wasm + jvm`** are the two formats that are not native images: both are
  *portable* and both are defined by a virtual machine rather than by a
  kernel.
- **`dwarf` stays alone** because it is not a file format for code at all — it
  is debug *data*, consumed by tools rather than loaded, and folding it into
  a format course would repeat a distinction it is in a position to teach.

## What a merge must do, every time

This is the part that goes wrong. A merge is **not** a delete and a rename.

1. **A new `manifest.json`** listing **every** concept of every merged
   course, with its **original id preserved** and the original course id
   recorded on each concept. The concept ids are the stable public API —
   `/courses/X/lessons/Y` — and 3,085 outbound links point at them.
2. **All content render functions** kept, one per concept, unchanged. The
   merge touches packaging, never prose.
3. **A new landing page** that lists every merged course's concepts as its
   own, and **says which course each concept came from** so a reader who
   followed a link from a lesson can still see the provenance.
4. **`render_concept` wired to resolve every merged id**, and the old ids
   **kept working**: a lesson id that used to resolve under the old course id
   must still resolve, because 3,085 links across the collection point at
   lesson URLs. A merge that 404s a single existing link is a broken merge.
5. **The verifiers merged, not discarded.** Each new verifier must check
   every concept of every merged course, including the old course's minutes,
   chain and link checks.
6. **The harnesses merged.** Each merged course's `crosscheck.py` checks
   remain, asserted against the merged recorded output.
7. **`docs/courses-todo.md` and `docs/features-complete.md` updated** so every
   roadmap item is still `[x]` and still traceable to the course that now
   teaches it.
8. **Old course directories kept as thin redirects** — a manifest naming the
   new course, so an old URL does not 404 — until every inbound link has been
   checked, at which point they may be deleted with the deletion recorded.

## Verification gate, per merge

No merge is done until all of these hold, for the whole collection:

- every concept URL that returned 200 before still returns 200
- `python3 tools/verify_<course>.py` → `ALL CONSISTENT` for all courses
- every course landing and every lesson route is 200
- `bracecheck`, `html_balance`, `nesting_check` clear
- `check_quotes` passing for every course
- the concept count and the minute total are **unchanged**

## The same invariant, applied to the un-started roadmap (2026-10-01)

The 2026-10-01 request was a second one, in the same direction and at a
different scale: *"there are too many courses, could you merge some titles, we
don't want to NOT teach something, but we want to put more topics into
courses… we want to teach less courses, but teach everything still, NOT miss
anything, this way AIs would be able to complete the courses faster."*

**It applies only to work that has not been started.** The 60 ticked items and
the 21 courses that teach them were deliberately left alone. Merging them was
already decided above and separately, and this change does not revisit it: the
ticked items sit in `docs/courses-todo.md` Part 1 under the headings they have
always had, with their existing annotations and provenance notes, byte for
byte. Reopening a shipped course to make a checklist look tidier is exactly the
kind of change that has to stay green for no benefit.

What changed is the other half of the document. The 678 un-started items were
flat under 35 topic sections, which read as 35 more courses — or, read one line
at a time, as 678. They are now grouped into **14 planned courses**, each named,
sized, and traceable, with every item annotated `— \`slug\`, from <section>,
concept \`<id>\``. No course directory, manifest, verifier or harness exists for
any of them; the slug and the concept id are what a build is expected to use.

The invariant is the same one that governs a merge, and it is machine-checked
rather than asserted:

```bash
python3 tools/todo_check.py    # exits 0 only if nothing moved
```

It compares the **multiset** of item titles — not the set, because sixteen
titles sit on two roadmap lines each and a set-based check would pass while a
line had been deleted — against a SHA-256 recorded before the restructure, and
additionally verifies the counts (738 / 60 / 678), that all 60 ticked titles are
the same 60, that every un-ticked line carries one of the 14 slugs, and that the
per-slug counts are the ones the summary table claims.

Three rules carried over from a merge to this restructure, because they are the
same operation on different inputs:

1. **Nothing is deleted, summarised, or folded into another bullet.** A merge
   loses courses and keeps concepts; this loses neither. It changes only the
   grouping and adds an annotation.
2. **A course is packaging.** Here the grouping is a proposal. The manifest,
   the concept ids and the module boundaries are decided when the course is
   built, and a build may split a planned course into modules without touching
   this document.
3. **Old identities keep working.** Roadmap item titles are unchanged, so any
   script or link that names a title still finds it; what is new is the
   annotation after the separator, which is why the check strips everything
   after `  — ` before comparing.