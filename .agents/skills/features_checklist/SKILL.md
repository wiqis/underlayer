# Features Checklist Skill

## Overview

The Underlayer platform has a master feature checklist at `docs/features-complete.md` (relative to the project root). This is the single source of truth for all platform features. Every feature is a numbered checkbox item — **1883 items across 27 sections**.

**Current progress: 210 checked, 1673 unchecked.** All core learning-loop P0 items (FSRS, review, exercises, sessions, weakness, health) are done. The next unchecked items are in Section 2 (Course Authoring) and Section 7 (User Experience).

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

1. **Build succeeds:** `cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules`
2. **Server starts:** the built executable runs without crash (or use `./scripts/serve.sh`)
3. **Health endpoint responds:** `curl localhost:9000/api/health` returns 200 with `{"status": "ok", ...}`
4. **ELF course loads:** `curl localhost:9000/courses/elf/lessons/bytes` returns valid HTML
5. **Tests pass:** `./scripts/test.sh` (builds `tests.exe` and runs all `@test` functions)
6. **No regressions:** Existing features still work

One-shot verification: `./scripts/underlayer-build-test.sh` builds, starts the server, curls every major endpoint, and stops the server — it always exits cleanly.

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

Note: the server renders concept pages via `content/src/*.ch` render functions (no `output/` pre-render step is wired for the current 24 concepts; the hardcoded fallback in `repository/src/courses.ch` maps all 24 concept IDs).

## How to use this skill

1. Before starting work: Read `docs/features-complete.md` to find the lowest-priority unchecked feature (P0 first, then P1, then P2, then P3)
2. During work: Implement the feature, verify the executable works, run tests
3. After work: Check off the feature in `docs/features-complete.md`, verify ELF course still renders

## Checklist location

`docs/features-complete.md` (project root — 2439 lines)

## Sections

| # | Section | Items | Notes on current state |
|---|---------|-------|------------------------|
| 1 | Learning Engine | FSRS, sessions, interleaving, weakness, health, pacing, patterns | Largely done (P0/P1) |
| 2 | Course Authoring | Structure, concepts, assets, review items, testing | Next frontier |
| 3 | Course Content & Visualizations | Hex viewer, diagrams, code examples, exercises, rich content | Only 4 of 24 concepts have full content files (`bytes`, `binary-representation`, `file-layout` + landing); rest render from `content/src/` |
| 4 | Exercise System | Types, feedback, generation, analytics | 8 exercise types in models; API done |
| 5 | Review & Spaced Repetition | Session types, item types, scheduling, analytics | 10 review modes done |
| 6 | Progress & Analytics | Learner progress, analytics, retention, engagement | Export + analytics endpoints done |
| 7 | User Experience | Navigation, components, theming, responsive, keyboard | Pages exist: home, dashboard, review, progress, course landing, lesson viewer |
| 8 | Social & Community | Profiles, social, community content, mentorship, competitive | Not started (P2/P3) |
| 9 | Content Delivery | Static, dynamic, packaging, offline | Static file serving done |
| 10 | Admin & Management | Courses, users, moderation, configuration | Not started |
| 11 | API & Integrations | REST, auth, integrations, export/import | No auth yet |
| 12 | Accessibility | WCAG, visual, motor, cognitive | Not started |
| 13 | Security & Privacy | Data security, privacy, compliance | Not started |
| 14 | Performance & Scalability | Performance, scalability, reliability | Not started |
| 15 | Developer Experience | Authoring tools, testing, dev tools, CI/CD | Scripts exist (`test.sh`, `serve.sh`, `underlayer-build-test.sh`) |
| 16 | Account Management | Registration, login, password reset, email verification, profile, settings, preferences, data, billing, security | Only learner CRUD (no auth) |
| 17 | Notification System | Email, push, in-app, preferences, analytics | Not started |
| 18 | Payment & Monetization | Tiers, payment, subscriptions, purchases, revenue, promotions | Not started |
| 19 | Gamification & Motivation | Streaks, XP, badges, leaderboards, challenges, levels, motivation | Not started |
| 20 | Certification & Credentials | Course certs, skill certs, learning paths, verification, portfolio | Not started |
| 21 | Internationalization | Translation, localization, regional, multilingual | Not started |
| 22 | AI & Machine Learning | Learning, content generation, tutoring, analytics, quality | Not started |
| 23 | Enterprise Features | Teams, SSO, content, analytics, compliance, integration | Not started |
| 24 | Content Management System | Editor, pipeline, quality, analytics, versioning | Not started |
| 25 | Data Pipeline & Warehouse | Events, collection, warehouse, analytics, quality | Not started |
| 26 | Observability & Monitoring | Logging, metrics, tracing, alerting, dashboards, incidents | Basic logging via `underlayer_core::log_info/log_error` |
| 27 | Legal & Compliance | Privacy, security, licensing, accessibility, financial | Not started |

## Priority Workflow (MANDATORY)

1. `grep -n "^- \[ \] P0" docs/features-complete.md | head` — find the first unchecked P0
2. If no P0 remains: same for P1, then P2, then P3
3. Implement exactly that one feature
4. Verify (Rule 2), check off (Rule 1), commit
