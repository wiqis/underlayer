# Features Checklist Skill

## Overview

The Underlayer platform has a master feature checklist at `docs/features-complete.md` (relative to the project root). This is the single source of truth for all platform features. Every feature is a numbered checkbox item — **1919 items across 27 sections**, tagged P0–P3.

**Current progress (verified 2026-09-24): 385 checked, 1534 unchecked — 0 P0, 15 P1, 17 P2, 1502 P3.**

**Per the priority rule, the next feature to implement is P1 4.1.29** (exercise UI on lesson pages supports all 8 exercise types).

**The 15 remaining P1 items:**
- 4.1.29 Exercise UI on lesson pages supports all 8 exercise types
- 5.1.16 Review page mode selection renders session in-page (`startMode()` currently navigates to the raw JSON endpoint — broken)
- 5.1.17 Review page calls POST /api/review/end on completion (sessions stay "active" forever)
- 5.1.18 Review session controls UI: pause/resume/abort/undo/skip wired to /api/session/* (APIs exist, zero frontend consumers)
- 5.1.19 Remove "demo" learner_id fallback on review submit/start (bearer token only)
- 7.1.16 Prev/next lesson navigation wired to GET /api/navigation/:courseId/:conceptId
- 7.1.17 Site navbar on concept pages (content/src pages are orphaned from site nav)
- 7.1.18 Auth-aware navbar (Login/Register vs profile + Logout)
- 7.1.19 401 handling: redirect to /login on expired session token
- 7.1.20 Onboarding gate: route incomplete-onboarding users to /onboarding
- 7.1.21 Replace hardcoded course_id=elf in review/progress/analytics page fetches
- 7.1.22 Fix analytics page fetch of literal un-substituted '/api/progress/:courseId' URL
- 7.1.23 Course landing Enroll button wired to POST /api/courses/:courseId/enroll
- 11.2.16 Frontend auth session bootstrap: shared JS helper for session_token + Authorization headers
- 11.2.17 Register/login redirect into the onboarding gate

**The 17 remaining P2 items:** 2.4.22 seed review_item_decls from manifest; 4.1.30 progressive-hints UI; 4.2.19 real exercise streak in submit response; 5.1.20 review recommendations UI; 6.2.16 analytics pages consume extended endpoints; 6.2.17 auth bearer token on progress/analytics fetches; 7.1.14 unread indicator; 7.1.24 home "Continue learning" card + due badge; 7.1.25 dashboard login prompt when logged out; 7.4.13 responsive visualizations; 7.5.4, 7.5.6–7.5.11 input-method support (custom shortcuts, voice, switch, external keyboard, game controller, stylus, multi-touch).

## Rules

### Rule 1: Update the checklist after every feature implementation

When you implement a feature, you MUST:

1. Find the corresponding item in `docs/features-complete.md`
2. Change `- [ ]` to `- [x]` for that item
3. If the feature required sub-features not listed, add them as new `- [ ]` items under the same section
4. Commit the checklist update alongside the code change

**Example:**
```diff
-- [ ] 16.3.1 "Forgot password?" link on login page
+- [x] 16.3.1 "Forgot password?" link on login page
```

**Note:** Items carry their priority tag inline: `- [x] P0 1.1.1 Implement FSRS v4 paper algorithm exactly`. When adding new items, keep the same format: `- [ ] P<n> <section>.<subsection>.<num> <description>`.

### Rule 2: After every feature, the executable must work

After implementing ANY feature, you MUST verify:

1. **Build succeeds:** `cmake-build-debug/TCCCompiler chemical.mod --mode debug_quick --no-cache -bm-modules` (from the repo root; the long `lang/compiled/underlayer/...` path applies only when building from the compiler tree)
2. **Server starts:** the built executable runs without crash (or use `./scripts/serve.sh`)
3. **Health endpoint responds:** `curl localhost:9000/api/health` returns 200 with `{"status": "ok", ...}`
4. **ELF course loads:** `curl localhost:9000/courses/elf/lessons/bytes` returns valid HTML
5. **Tests pass:** `./scripts/test.sh` (builds the test exe and runs all `@test` functions)
6. **No regressions:** Existing features still work
7. **Concept lint (when touching course content):** `./scripts/lint-concepts.sh`

One-shot verification: `./scripts/underlayer-build-test.sh` builds, starts the server, curls every major endpoint, and stops the server — it always exits cleanly. PowerShell equivalents (`serve.ps1`, `test.ps1`, `underlayer-build-test.ps1`) exist for Windows.

**If any check fails, fix the issue before moving to the next feature.**

### Rule 3: One feature at a time

Do NOT implement multiple features in a single change. Each feature should be:
- A single, atomic change
- Independently verifiable
- Independently deployable

### Rule 4: Course content must always render

The ELF course (`courses/elf/`) is the reference course. After every change:
- All concept pages must render without errors
- All exercises must be interactive
- All visualizations must work
- All navigation must function

Note: the server renders concept pages via `content/src/*.ch` render functions (30 source files: 24 ELF concepts + landing page + 4 exercise-layout templates). The pre-render flow exists too: `courses/elf/src/main.ch` calls `underlayer_content::render_*()` and writes `courses/elf/output/*.html`.

## How to use this skill

1. Before starting work: Read `docs/features-complete.md` to find the lowest-priority unchecked feature (P0 first, then P1, then P2, then P3)
2. During work: Implement the feature, verify the executable works, run tests
3. After work: Check off the feature in `docs/features-complete.md`, verify ELF course still renders

## Checklist location

`docs/features-complete.md` (project root)

## Sections

| # | Section | Items | Notes on current state (2026-09-24) |
|---|---------|-------|------------------------|
| 1 | Learning Engine | FSRS, sessions, interleaving, weakness, health, pacing, patterns | P0/P1/P2 done — incl. mistake patterns (`learning/src/mistakes.ch`); energy check-in remains P3 |
| 2 | Course Authoring | Structure, concepts, assets, review items, testing | 2.1.25 done (home grid dynamic); only P2 2.4.22 + P3 remain — `scripts/lint-concepts.sh` validates concepts |
| 3 | Course Content & Visualizations | Hex viewer, diagrams, code examples, exercises, rich content | `content/src/` now has 155 files: ELF + HAT + PE + Mach-O renderers, 5 landings, 4 layout templates |
| 4 | Exercise System | Types, feedback, generation, analytics | 8 exercise types + bulk import/seed/stats; **P1 4.1.29 (lesson-page exercise UI) is the next feature** |
| 5 | Review & Spaced Repetition | Session types, item types, scheduling, analytics | 10 review modes; **P1 5.1.16–5.1.19 remain (review page frontend broken/missing)** |
| 6 | Progress & Analytics | Learner progress, analytics, retention, engagement | Export/import, sharing, 12+ analytics endpoints; P2 6.2.16/6.2.17 remain |
| 7 | User Experience | Navigation, components, theming, responsive, keyboard | **7 P1s (7.1.16–7.1.23) + 11 P2s (7.1.14/24/25, 7.4.13, 7.5.x) remain — largest gap** |
| 8 | Social & Community | Profiles, social, community content, mentorship, competitive | Profiles, course reviews, achievements, streaks, certificates done |
| 9 | Content Delivery | Static, dynamic, packaging, offline | Static file serving + pre-render flow done |
| 10 | Admin & Management | Courses, users, moderation, configuration | Feedback moderation endpoints exist; rest P3 |
| 11 | API & Integrations | REST, auth, integrations, export/import | Auth done; **P1 11.2.16/11.2.17 (frontend auth bootstrap + onboarding redirect) remain** |
| 12 | Accessibility | WCAG, visual, motor, cognitive | P2 accessibility items remain (7.5.x); rest P3 |
| 13 | Security & Privacy | Data security, privacy, compliance | Auth + password hashing + audit_log + data export/deletion done; rest P3 |
| 14 | Performance & Scalability | Performance, scalability, reliability | P3 |
| 15 | Developer Experience | Authoring tools, testing, dev tools, CI/CD | Scripts: `test.sh`, `serve.sh`, `underlayer-build-test.sh`, `lint-concepts.sh` (+ .ps1 variants) |
| 16 | Account Management | Registration, login, password reset, email verification, profile, settings, preferences, data, billing, security | Auth + profiles + settings + onboarding done; billing P3 |
| 17 | Notification System | Email, push, in-app, preferences, analytics | In-app notifications done (table + API + page); email/push P3 |
| 18 | Payment & Monetization | Tiers, payment, subscriptions, purchases, revenue, promotions | P3 |
| 19 | Gamification & Motivation | Streaks, XP, badges, leaderboards, challenges, levels, motivation | Streaks + achievements done; XP/leaderboards P3 |
| 20 | Certification & Credentials | Course certs, skill certs, learning paths, verification, portfolio | Certificates + learning-path visualization done; rest P3 |
| 21 | Internationalization | Translation, localization, regional, multilingual | P3 |
| 22 | AI & Machine Learning | Learning, content generation, tutoring, analytics, quality | P3 |
| 23 | Enterprise Features | Teams, SSO, content, analytics, compliance, integration | P3 |
| 24 | Content Management System | Editor, pipeline, quality, analytics, versioning | P3 |
| 25 | Data Pipeline & Warehouse | Events, collection, warehouse, analytics, quality | P3 |
| 26 | Observability & Monitoring | Logging, metrics, tracing, alerting, dashboards, incidents | Basic logging via `underlayer_core::log_info/log_error` |
| 27 | Legal & Compliance | Privacy, security, licensing, accessibility, financial | `/terms` + `/privacy` pages done; rest P3 |

## Priority Workflow (MANDATORY)

1. `grep -n "^- \[ \] P0" docs/features-complete.md` — if any P0 remains, take the first
2. Same for P1, then P2, then P3. **As of 2026-09-24 there are 15 unchecked P1 items; the first (numerical order) is P1 4.1.29.**
3. Implement exactly that one feature
4. Verify (Rule 2), check off (Rule 1), commit
