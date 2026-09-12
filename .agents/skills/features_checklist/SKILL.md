# Features Checklist Skill

## Overview

The Underlayer platform has a master feature checklist at `docs/features-complete.md`. This is the single source of truth for all platform features. Every feature is a numbered checkbox item (1883 total across 27 sections).

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

### Rule 2: After every feature, the executable must work

After implementing ANY feature, you MUST verify:

1. **Build succeeds:** `cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules`
2. **Server starts:** `./lang/compiled/underlayer/build/underlayer.exe` runs without crash
3. **Health endpoint responds:** `curl localhost:9000/api/health` returns 200
4. **ELF course loads:** `curl localhost:9000/courses/elf/lessons/bytes` returns valid HTML
5. **No regressions:** Existing features still work

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

## How to use this skill

1. Before starting work: Read `docs/features-complete.md` to find the feature you're implementing
2. During work: Implement the feature, verify the executable works
3. After work: Check off the feature in `docs/features-complete.md`, verify ELF course still renders

## Checklist location

`lang/compiled/underlayer/docs/features-complete.md`

## Sections

| # | Section | Items |
|---|---------|-------|
| 1 | Learning Engine | FSRS, sessions, interleaving, weakness, health, pacing, patterns |
| 2 | Course Authoring | Structure, concepts, assets, review items, testing |
| 3 | Course Content & Visualizations | Hex viewer, diagrams, code examples, exercises, rich content |
| 4 | Exercise System | Types, feedback, generation, analytics |
| 5 | Review & Spaced Repetition | Session types, item types, scheduling, analytics |
| 6 | Progress & Analytics | Learner progress, analytics, retention, engagement |
| 7 | User Experience | Navigation, components, theming, responsive, keyboard |
| 8 | Social & Community | Profiles, social, community content, mentorship, competitive |
| 9 | Content Delivery | Static, dynamic, packaging, offline |
| 10 | Admin & Management | Courses, users, moderation, configuration |
| 11 | API & Integrations | REST, auth, integrations, export/import |
| 12 | Accessibility | WCAG, visual, motor, cognitive |
| 13 | Security & Privacy | Data security, privacy, compliance |
| 14 | Performance & Scalability | Performance, scalability, reliability |
| 15 | Developer Experience | Authoring tools, testing, dev tools, CI/CD |
| 16 | Account Management | Registration, login, password reset, email verification, profile, settings, preferences, data, billing, security |
| 17 | Notification System | Email, push, in-app, preferences, analytics |
| 18 | Payment & Monetization | Tiers, payment, subscriptions, purchases, revenue, promotions |
| 19 | Gamification & Motivation | Streaks, XP, badges, leaderboards, challenges, levels, motivation |
| 20 | Certification & Credentials | Course certs, skill certs, learning paths, verification, portfolio |
| 21 | Internationalization | Translation, localization, regional, multilingual |
| 22 | AI & Machine Learning | Learning, content generation, tutoring, analytics, quality |
| 23 | Enterprise Features | Teams, SSO, content, analytics, compliance, integration |
| 24 | Content Management System | Editor, pipeline, quality, analytics, versioning |
| 25 | Data Pipeline & Warehouse | Events, collection, warehouse, analytics, quality |
| 26 | Observability & Monitoring | Logging, metrics, tracing, alerting, dashboards, incidents |
| 27 | Legal & Compliance | Privacy, security, licensing, accessibility, financial |
