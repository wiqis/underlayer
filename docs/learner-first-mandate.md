# Learner-First Mandate — governing spec for all Underlayer work (2026-11-24)

**Status: ACTIVE. This document overrides older guidance where they conflict.**
Older docs (`AGENTS.md`, `course-design.md`, `features-complete.md`) are still
authoritative for technical accuracy and platform history. But where they say
"teach every detail on the page at once", this document wins: a reader who is
overloaded learns nothing, however correct the text is.

Set by the founder on 2026-11-24 after reviewing the live platform.

## The problem being fixed

The courses are technically deep and verified, but they were built for the
subject, not the learner. Pages present ~7 dense units at once. An AI-written
lesson compresses a hard idea into a short paragraph and then moves on, so the
reader cannot tell what to remember, what to do next, or whether they understood
it. The result is overload, not learning.

## The product we are building

A **guided journey**: the platform takes the learner by the hand, one idea at a
time, with an action, feedback, and a clear "this is what to remember" before it
moves on. Depth is **preserved in a deep-dive layer** — nothing technical is
deleted or dumbed down. The change is in *pacing, sequencing and presentation*.

## The Lesson Journey Contract (binding on every lesson, every course)

1. **Arrival.** Before any content: one sentence "In this step you will be able
   to ___", the time estimate, difficulty, and a link to the prerequisite if
   there is one. One obvious *Start* action. No wall of links above the fold.
2. **One step at a time.** A lesson is walked as steps, not read as a page.
   Only one step is visible. Each step is one idea. The existing semantic units
   are the steps, in order: `unit-why`, `unit-model`, `unit-reality`,
   `unit-example`, `unit-connect`, `unit-interact`, `unit-apply`,
   `unit-retrieve`, `unit-exercises`. (~3,000 units exist across 469 lessons;
   use them — do not rewrite 469 files by hand.)
3. **Progressive disclosure inside a step.** First paragraph and the single
   working example are visible. Long tables, full hex dumps, exhaustive field
   lists and long code samples sit behind a labelled "Show the full detail"
   control. Explicit labels, not mystery chevrons.
4. **Do something before moving on.** Every step ends with a tiny action:
   predict, choose, fill one blank, inspect one byte, or state the idea in the
   learner's own words. Feedback is immediate, specific and non-judgemental.
   Wrong answers explain why; they never shame.
5. **"Remember this" — mandatory.** Every step ends with a takeaway of at most
   three short lines / ~25 words. It answers exactly: *what must I keep in my
   head to understand the next step?* If a step has no such thing, say so
   plainly ("No new fact to memorise — this step is about seeing the link").
6. **Retrieval is a gate, not a test.** Before advancing, one short question
   from the step just finished, then one from an earlier step on later steps.
   "I'm stuck — show me" reveals the answer and lets the learner continue.
   Forgetting is normal; no red scores, no streaks, no percentages presented
   as verdicts. Progress is expressed as "Step 2 of 7".
7. **Journey ribbon.** Always visible: where I am, why this lesson is in the
   chain, what comes next. Compact, no decorative gamification.
8. **Pacing.** "Pause / take a break" collapses the lesson and saves the exact
   step locally. Returning resumes there. No automated timers that pressure.
9. **Finish.** One-sentence recap of what the learner can now *do*, the next
   lesson link, and a "Deep dive — the full technical reference" expander that
   restores all detail. Depth stays available; it is no longer the default.
10. **Backend-optional.** All of the above works in pre-rendered static pages
    (GitHub Pages / `file://`) from `localStorage`, with no API call. The backend
    only adds sync. If a feature cannot work offline, it is not part of the
    core journey.

## Visual and interaction rules

- Calm, generous spacing; one focal element per screen; readable line length.
- Buttons do one thing. Labels say what will happen ("Show full byte table").
- Keyboard reachable, focus visible, screen-reader labels on every control.
- Respect reduced motion and high-contrast preferences already in the lessons.
- No decorative animation, no confetti, no leaderboards, no "mastery %" on a
  lesson page.
- Never invent byte values, offsets, or spec claims. Verification rules in
  `AGENTS.md` still apply in full.

## HAT course removal (binding)

The HAT course is removed from the platform: delete `courses/hat/` (source,
output, assets, generated banks, tools), remove every reference from the course
catalogue, the three named routes, the orphan note, README, docs, deployment
recipes, tests and build scripts. `/courses/hat` and its lesson URLs must 404.
No HAT concept ids may remain in manifests, exercise declarations or progress
seed data. Verify with a case-sensitive search for word-boundary `hat`/`HAT`
before declaring it done.

## Scope of this work

- **Web (`Web/underlayer`)**: journey shell across all lessons, course landing
  and `/courses` index; HAT removal; mobile-ready APIs for the Android client.
- **Android (`Android/Apps/underlayer-kmp`)**: become a real Underlayer client
  — consume Underlayer's course/lesson/progress APIs, ship a bundled offline
  course pack so a new user with no connection still has something to learn,
  and sync progress when online. The frozen `applicationId`
  `com.wakaztahir.learnpythonapp` must never change.

## Non-negotiables inherited from company rules

- Never push to `origin`. Commits are allowed for this body of work; every
  commit message is exactly two lines (subject + one detail line, no trailers).
- Preserve other people's uncommitted work. In the Android repo there were four
  modified files at the start of this work (offline-safety fix in `CourseApi.kt`
  and two activities, plus `LogApi.kt`) — build on them, never discard them.
- All markup in Chemical goes through `#html` / `#css` / `#js` macros. Never
  work around a macro bug with string concatenation.
- The server must always build and keep serving `/api/health` and
  `/courses/elf/lessons/bytes`. Verify with the endpoint matrix, not a local
  build alone.
- Verify against the running service; report honestly what was not verified.
