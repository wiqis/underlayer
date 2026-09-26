# Course Mission

> **Load this before starting any course work.** It is the goal the whole
> collection serves, and it resolves scope questions that no other document can.
> Authoritative statement: `docs/course-mission.md`.

## The one-sentence goal

Teach the complete path from **parsing to a working executable**, so a learner
can then build a compiler that supports **any architecture** and **any OS** and
emits **executables and shared libraries** — **without depending on LLVM or any
other backend**.

LLVM is taught as a thing to understand and eventually replace, never as a
dependency the learner cannot do without.

## Five rules

1. **From scratch, not by delegation.** Anything the learner would get from a
   library is taught, then rebuilt. Using `gcc` to *produce* a specimen is fine
   and encouraged; the learner must then be shown how to read that file without
   it, and the course must say the tool was used to make the specimen.
2. **Every instruction, every architecture.** Not "how a call works" — every
   instruction the architecture defines, with encoding, flags, cost, and the trap
   that bites. AArch64 is taught because someone always needs it, not because the
   team chose it. Where a set is too large, teach it as a complete reference with
   depth where it matters, and **say what is deferred** — silence about coverage
   is the failure mode.
3. **Practical, not textbook.** Work backwards from a real problem. Real files,
   not idealised ones. Name the trap, the workaround, the historical accident.
   End with something the learner could build.
4. **Every single thing in detail.** The default is thorough; conciseness is what
   gets sacrificed. The failure to avoid is *shallowness disguised as clarity* —
   the test is whether someone implementing from the text alone would get it
   right.
5. **Learn by doing, then improve forever.** Now: get something deployed for
   every course. Then: revise each course again and again. A course that has
   never been revised has not been worked on.

## The chain, and where a course sits in it

```
lexing ─▶ parsing ─▶ semantics ─▶ IR ─▶ target instruction sets ─▶ codegen
                                                                 │
                            ┌────────────────────────────────────┘
                            ▼
                     OBJECT FILES   (relocatable, still unresolved)
                            ▼
                     LINKING        (resolve, relocate, lay out)
                            ▼
              EXECUTABLE / SHARED LIBRARY
                            ▼
                     LOADING        (map, relocate, run init)
```

Two failure modes to avoid:

- **Requiring a link the learner has not been given.** If a concept needs the
  linker, and the linker has not been taught, teach the minimum needed or point
  forward explicitly. Do not quietly assume it.
- **Re-teaching a neighbour.** Check what adjacent courses already cover. If
  three courses each cover object files inside their own format, a fourth
  format-specific course is redundant — a course on the *concept*, compared
  across formats, is not.

## Decision checklist

Run this against any concept before writing it.

- [ ] Does it serve the parsing→executable chain, or is it a detour?
- [ ] Does it assume anything the learner has not been taught yet?
- [ ] Does it repeat a neighbouring course? If so, is the comparison new?
- [ ] Could a learner implement from this text alone and get it right?
- [ ] Is every byte claim traceable to a file on disk?
- [ ] Are the two independent readers named, with versions and a date?
- [ ] Is there a runnable exercise?
- [ ] Is the x86-64 bias stated where it applies, and portability given?
- [ ] Is what was **not** verified written down?
- [ ] Is every architecture's term given, even when only one target is used?

## Standards every course in this collection meets

| Must have | Why |
|---|---|
| Byte claims traceable to a real file | AI output is presumed wrong until checked |
| Two independent readers, or one plus a hand-check | Self-consistency proves nothing |
| A specimen set that ships with the course | Makes claims falsifiable and re-checkable |
| Named, dated toolchain | "gcc 15.2, clang 21, 2026-09-26" is a fact; "verified" is not |
| Documented limits | What was not checked is part of the honesty |
| Runnable exercises | Learn by doing |
| A stated place in the chain | Tells it what it may assume |

## What is deliberately not the goal

- Not a replacement for specifications — cite them, make them readable.
- Not a history survey — history only where it explains a decision.
- Not coverage for its own sake — a course that names RISC-V once and calls it
  covered is worse than one that says "not yet".
- Not one architecture's view — every course must say where it speaks from a
  single target and where the concept is portable.

## When a brief is ambiguous

Resolve it in this order:

1. `docs/course-mission.md` — the goal.
2. `docs/courses-todo.md` — what is outstanding, and what is already claimed.
3. The target course's own `research.md` and `manifest.json` — what is verified.
4. **The neighbouring courses' manifests** — before writing any cross-course
   link, check the id actually exists. Inventing concept ids is a recurring
   error and it has produced 404s.
5. Ask the founder if the fork changes 20+ concepts' worth of work.
