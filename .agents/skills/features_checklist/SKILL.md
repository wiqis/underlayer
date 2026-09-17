# Features Checklist Skill

## Overview

The Underlayer platform has a master feature checklist at `docs/features-complete.md` (relative to the project root). This is the single source of truth for all platform features. Every feature is a numbered checkbox item — **1883 items across 27 sections**, tagged P0–P3.

**Current progress (verified 2026-09-17): 372 checked, 1511 unchecked.** All P0 and P1 items are done. Only **9 P2 items** remain (list below), then 1502 P3 items.

**The 9 remaining P2 items:** 7.1.14 unread indicator, 7.4.13 responsive visualizations, 7.5.4–7.5.11 input-method support (custom shortcuts, voice input, switch access, external keyboard, game controller, stylus, multi-touch). **Per the priority rule, the next feature to implement is P2 7.1.14.**

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

| # | Section | Items | Notes on current state (2026-09-17) |
|---|---------|-------|------------------------|
| 1 | Learning Engine | FSRS, sessions, interleaving, weakness, health, pacing, patterns | Done (P0/P1) — incl. mistake patterns (`learning/src/mistakes.ch`) |
| 2 | Course Authoring | Structure, concepts, assets, review items, testing | Done through P2 — `scripts/lint-concepts.sh` validates concepts |
| 3 | Course Content & Visualizations | Hex viewer, diagrams, code examples, exercises, rich content | All 24 ELF concepts + landing render from `content/src/`; 4 layout templates |
| 4 | Exercise System | Types, feedback, generation, analytics | Done — 8 exercise types + bulk import/seed/stats |
| 5 | Review & Spaced Repetition | Session types, item types, scheduling, analytics | Done — 10 review modes |
| 6 | Progress & Analytics | Learner progress, analytics, retention, engagement | Done through P1 — export/import, sharing, 12+ analytics endpoints |
| 7 | User Experience | Navigation, components, theming, responsive, keyboard | **Remaining P2s live here (7.1.14, 7.4.13, 7.5.4–7.5.11)** |
| 8 | Social & Community | Profiles, social, community content, mentorship, competitive | P0/P1 parts done — profiles, course reviews, achievements, streaks, certificates |
| 9 | Content Delivery | Static, dynamic, packaging, offline | Static file serving + pre-render flow done |
| 10 | Admin & Management | Courses, users, moderation, configuration | Feedback moderation endpoints exist; rest P3 |
| 11 | API & Integrations | REST, auth, integrations, export/import | Auth done (bearer + auth_sessions); API keys table exists |
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
2. Same for P1, then P2, then P3. **As of 2026-09-17 the first unchecked item is P2 7.1.14.**
3. Implement exactly that one feature
4. Verify (Rule 2), check off (Rule 1), commit
