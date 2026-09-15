# Subagent Briefs — Pre-Expansion Readiness (2026-09-15)

> **STATUS: COMPLETE (same day).** All 5 workstreams implemented and verified:
> 104/104 tests pass, linter PASS (0 fails/0 warns), 4 templates render to
> `courses/elf/output/template-*.html`. 15 checklist items checked off
> (P2: 4.2.16, 4.2.17, 7.1.10, 7.1.13, 7.1.15 · P3: 2.2.5–2.2.8, 2.2.11–2.2.16).
> Notes for future sessions: build with the real compiler at
> `D:/Programming/Chemical/chemical/cmake-build-debug/TCCCompiler.exe` (the
> AGENTS.md path is stale); cross-module content calls crash in @test runtime
> (verify content via the templates_preview tool or HTTP routes); `find` on a
> short needle in a long JSON body can crash — use distinctive needles.

Context: all P0/P1 checklist items are done. 26 P2 items remain, then P3. These 5
workstreams were selected because they are either (a) the last P2s in the core
learning loop, (b) essential daily-driver UX for a learner, or (c) the authoring
infrastructure needed before expanding courses.

Every brief follows AGENTS.md rules: one atomic feature per change, build+test
verification, check off `docs/features-complete.md`, no string-appended HTML
(course pages use `#html/#css/#js`; server JSON responses may use strings like
the existing handlers do), files under 250 lines.

---

## WS1 — Mistake Patterns & Personalized Feedback (P2 4.2.16, 4.2.17)

**Goal:** When a learner keeps getting the same concept wrong, tell them *why* —
detect the pattern and give feedback tailored to it.

**Read first:** `learning/src/weakness.ch`, `web/src/handlers_review.ch`
(`handle_review_submit`), `web/src/handlers_weakness.ch`, `tests/src/weakness_test.ch`

**Implement (learning/src/ — new file `mistakes.ch`):**
1. `MistakePattern` struct: `concept_id`, `pattern` (one of
   `"consistent_failure"` (accuracy < 30% with 3+ attempts),
   `"intermittent"` (accuracy 30–60%, 3+ attempts),
   `"streak_reset"` (attempts >= 3 and streak == 0),
   `"no_pattern"`), `occurrences`, `confidence` (0–100: occurrences/attempts).
2. `detect_mistake_patterns(states : *vector<ConceptState>) : vector<MistakePattern>`
   — only concepts with attempts > 0; skip `no_pattern` concepts.
3. `personalized_feedback(pattern : &MistakePattern) : string` — returns teaching
   text per pattern (e.g. consistent_failure → "This concept needs re-teaching,
   not more reps — go back to the lesson and re-read the core model"; include the
   concept id and accuracy in the message).

**Wire up (web/src/):** in `handle_review_submit` response JSON add
`"mistake_pattern"` (pattern string, `"none"` if no pattern) and
`"personalized_feedback"` (text, empty when none) computed from the freshly
updated state (wrap the single state in a vector for `detect_mistake_patterns`).

**Verify:** `./scripts/underlayer-build-test.sh`; add HTTP test in
`tests/src/weakness_test.ch` (new port): POST review submit with rating=again
three times, assert response contains `"mistake_pattern"`; check off 4.2.16 +
4.2.17.

---

## WS2 — Nav Progress + Due Indicators (P2 7.1.13, 7.1.15)

**Goal:** The navigation bar shows a small progress bar and a due-review badge so
learners instantly know where they stand and that reviews are waiting.

**Read first:** `web/src/handlers_navigation.ch`, `web/src/handlers_progress.ch`,
`app/main.ch` (route table), `content/src/elf_landing.ch` (how pages embed nav),
`tests/src/additional_api_test.ch`

**Implement:**
1. **API (web/src/handlers_navigation.ch):** add
   `handle_nav_status(db, res)` →
   `{"concepts_started":N,"concepts_total":24,"progress_pct":P,"due_reviews":D}`
   — concepts from `get_all_concept_states` (learner "demo", course "elf",
   status != "new"), total 24 (the hardcoded concept count), pct rounded down,
   `due_reviews = get_due_review_items(...).size()` (limit 50).
2. **UI (content/src/):** in `elf_landing.ch` nav add a `nav-progress` block:
   a small bar div + a `nav-due-badge` span, styled in the page's `#css` block,
   driven by a `#js` block that `fetch('/api/nav-status')` on load, sets bar
   width to progress_pct and shows the badge only when due_reviews > 0
   (linking to `/review`). Elements must be hidden by default so static mode
   (no backend) still renders clean.

**Verify:** `./scripts/underlayer-build-test.sh`; add HTTP test
(`/api/nav-status` returns all four keys; no-badge case still valid); curl the
landing page and confirm `nav-progress` present; check off 7.1.13 + 7.1.15.

---

## WS3 — Command Palette / Quick Jump (P2 7.1.10)

**Goal:** Press `Ctrl+K` (also `/`) anywhere → fuzzy list of all 24 concepts +
nav pages; Enter/arrow keys jump.

**Read first:** `content/src/elf_landing.ch`, `content/src/bytes.ch` (page
pattern), `docs/micro-interactions.md`

**Implement:**
1. **API (web/src/handlers_navigation.ch):** `handle_nav_search(res)` →
   `{"entries":[{"label":"...","url":"/courses/elf/lessons/<id>","kind":"concept"},
   ...]}` covering all 24 concept IDs listed in `web/src/helpers.ch::render_concept`
   plus `{"Home","/"},{"Dashboard","/dashboard"},{"Review","/review"},
   {"Progress","/progress"}`.
2. **UI (content/src/):** in `elf_landing.ch`: overlay div (`id="cmdk"`,
   hidden), input + results list, `#css` styling consistent with existing pages,
   `#js`: keydown handler (Ctrl+K or `/` toggles unless typing in an input),
   Esc closes, simple substring filter on label, ArrowUp/Down + Enter navigates
   (highlight selected). Fetch `/api/nav-search` lazily on first open.
   No new dependencies.

**Verify:** `./scripts/underlayer-build-test.sh`; HTTP test: `/api/nav-search`
contains `"/courses/elf/lessons/bytes"` and 24+ entries; check off 7.1.10.

---

## WS4 — Concept Templates (P3 2.2.5–2.2.8) — *course expansion readiness*

**Goal:** Four reusable page scaffolds so every new concept written during
expansion starts from a proven layout instead of ad-hoc HTML.

**Read first:** `content/src/bytes.ch` (canonical lesson layout + quiz JS),
`courses/elf/src/bytes.ch` (static-mode twin), `docs/course-design.md`

**Implement (content/src/templates.ch, one public func per template):**
- `template_standard(title, units_html) : string` — 8-unit order:
  why → model → reality → example → interact → retrieve → apply → summary.
- `template_exercise_focus(title, exercises_html)` — retrieval-first.
- `template_visualization(title, viz_html)` — full-width viz unit.
- `template_mixed(title, units_html, viz_html, exercises_html)`.
- Each returns a complete `HtmlPage` via `#html/#css/#js` macros (shared
  `#css` with `.lesson`, `.unit`, `.quiz` classes matching bytes.ch; shared
  `#js` with the `checkQuiz` helper). Private helpers used across files become
  `public` per the module convention. Include a `render_template_demo()` that
  returns the `template_standard` page for verification (not routed).

**Verify:** `./scripts/underlayer-build-test.sh` (module must still compile);
unit test in `tests/src/content_test.ch`: output contains `class="lesson"` and
all 8 unit markers for standard; check off 2.2.5–2.2.8.

---

## WS5 — Concept Validation / Linting (P3 2.2.11–2.2.16) — *quality gate for expansion*

**Goal:** `./scripts/lint-concepts.sh` checks every `content/src/*.ch` for the
six validation rules and fails CI on P0/P1-level problems.

**Read first:** `content/src/*.ch` (real examples of each violation),
`docs/ai-course-writing-constraints.md`, `docs/correctness-verification.md`

**Implement (scripts/lint-concepts.sh, plain bash+grep):**
1. **2.2.11** common mistakes: `append_view("<` (string-appended HTML),
   `for(` in Chemical `#js` blocks, `== ` string comparison against a string
   var, missing `else` after `if(`.
2. **2.2.12** required sections: file defines `render_` function; page HTML
   contains `unit-why` and `unit-retrieve`.
3. **2.2.13** exercise count: at least 1 `quiz-option` per concept page.
4. **2.2.14** assets: any `src="/courses/elf/assets/...` or `href="/courses/elf/assets/...`
   path resolves to an existing file under `courses/elf/assets/`.
5. **2.2.15** link validity: every `href="/courses/elf/...` target matches a
   concept ID in `content/src/` or the known landing/static routes.
6. **2.2.16** accessibility (P0 checks only): every `<img` has `alt=`, interactive
   `onclick` elements carry `onkeypress` or are `<button>`, hex tables have
   `<th scope=` (warn-level).

Output `PASS/FAIL per rule per file + summary`; exit 1 only on FAIL (rule 1,
missing render_, no quiz-option); warnings exit 0. Fix any violations found in
existing content as part of this change (counts toward "verify everything").

**Verify:** run `./scripts/lint-concepts.sh` → all existing content passes;
deliberately break a temp copy to prove each rule fires; check off
2.2.11–2.2.16.

---

## Deliberately NOT selected this round

- 6.2.x platform analytics (cohort/funnel/device) — operator-facing, not
  learner-facing; block nothing.
- 7.1.14 unread indicator — meaningless without accounts/sync.
- 7.2.19/7.2.20, 7.3.x, 7.5.x — cosmetic/edge input methods; no learning value
  pre-expansion.
