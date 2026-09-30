# Underlayer — Complete Feature Specification

**Purpose:** Master feature list for the Underlayer platform. Every feature is a checklist item. AI agents pick a feature, implement it, verify it, move on. This is the platform — courses are built on top of it.

---

## Priority Legend

| Tag | Priority | Description |
|-----|----------|-------------|
| **P0** | Critical | Must have for MVP. Core learning loop, basic API, essential UI, server runs. |
| **P1** | Important | Should have for launch. Session management, progress tracking, course rendering, real-time feedback. |
| **P2** | Nice to have | Enhances experience. Analytics, recommendations, advanced FSRS, settings UI. |
| **P3** | Future | Long-term vision. AI/ML, enterprise, social features, advanced analytics. |


## Table of Contents

1. [Learning Engine](#1-learning-engine)
2. [Course Authoring](#2-course-authoring)
3. [Course Content & Visualizations](#3-course-content--visualizations)
4. [Exercise System](#4-exercise-system)
5. [Review & Spaced Repetition](#5-review--spaced-repetition)
6. [Progress & Analytics](#6-progress--analytics)
7. [User Experience](#7-user-experience)
8. [Social & Community](#8-social--community)
9. [Content Delivery](#9-content-delivery)
10. [Admin & Management](#10-admin--management)
11. [API & Integrations](#11-api--integrations)
12. [Accessibility](#12-accessibility)
13. [Security & Privacy](#13-security--privacy)
14. [Performance & Scalability](#14-performance--scalability)
15. [Developer Experience](#15-developer-experience)
16. [Account Management](#16-account-management)
17. [Notification System](#17-notification-system)
18. [Payment & Monetization](#18-payment--monetization)
19. [Gamification & Motivation](#19-gamification--motivation)
20. [Certification & Credentials](#20-certification--credentials)
21. [Internationalization](#21-internationalization)
22. [AI & Machine Learning](#22-ai--machine-learning)
23. [Enterprise Features](#23-enterprise-features)
24. [Content Management System](#24-content-management-system)
25. [Data Pipeline & Warehouse](#25-data-pipeline--warehouse)
26. [Observability & Monitoring](#26-observability--monitoring)
27. [Legal & Compliance](#27-legal--compliance)

---

## 1. Learning Engine

### 1.1 FSRS Spaced Repetition Algorithm

- [x] P0 1.1.1 Implement FSRS v4 paper algorithm exactly
- [x] P0 1.1.2 Store 19 parameter weights per learner in DB
- [x] P0 1.1.3 Default weights from paper: w=[0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61]
- [x] P0 1.1.4 Allow learner to customize target retention (0.80, 0.85, 0.90, 0.95)
- [x] P0 1.1.5 Default target retention = 0.90
- [x] P0 1.1.6 Compute difficulty D from initial rating (Again=1, Hard=2, Good=3, Easy=4)
- [x] P0 1.1.7 Clamp difficulty to range [1, 10]
- [x] P0 1.1.8 Compute stability S after each review using FSRS formulas
- [x] P0 1.1.9 Compute retrievability R = 1 / (1 + (t/S) * c) where c = -0.5
- [x] P0 1.1.10 Schedule next review when R drops below target retention
- [x] P0 1.1.11 Support maximum interval cap (default 365 days, configurable)
- [x] P0 1.1.12 Support minimum interval (default 1 day)
- [x] P1 1.1.13 Support graduated intervals for new cards (1d, 3d, 7d before first review)
- [x] P1 1.1.14 Support lapse recovery: when R < 0.5, reset stability to 50% of previous
- [x] P1 1.1.15 Support ease factor adjustment on each rating
- [x] P1 1.1.16 Support per-item difficulty drift based on review history
- [x] P1 1.1.17 Support state transitions: New -> Learning -> Review -> Relearning
- [x] P1 1.1.18 Support "Good" on New card advances to next graduation step
- [x] P1 1.1.19 Support "Easy" on New card graduates immediately
- [x] P1 1.1.20 Support "Again" on Review card enters relearning
- [x] P1 1.1.21 Support "Hard" on Review card reduces interval by 20%
- [x] P1 1.1.22 Support "Easy" on Review card increases interval by 1.3x
- [x] P1 1.1.23 Compute next interval: interval = stability * (target_retention^(1/c) - 1)
- [x] P2 1.1.24 Support parameter optimization from review history (minimize RMSE)
- [x] P2 1.1.25 Allow learner to reset all FSRS parameters to defaults
- [x] P2 1.1.26 Allow learner to import FSRS parameters from Anki
- [x] P2 1.1.27 Allow learner to export FSRS parameters
- [x] P2 1.1.28 Log all parameter changes for debugging
- [x] P2 1.1.29 Provide "why this interval?" tooltip showing FSRS calculation

### 1.2 Review Session Management

- [x] P0 1.2.1 Create session from due items + new items
- [x] P0 1.2.2 Track current item index in session
- [x] P0 1.2.3 Track session start time
- [x] P0 1.2.4 Track session end time
- [x] P0 1.2.5 Track items reviewed in session
- [x] P0 1.2.6 Track accuracy per item in session
- [x] P0 1.2.7 Track time spent per item in session
- [x] P0 1.2.8 Compute session statistics: accuracy, avg time, items reviewed
- [x] P1 1.2.9 Allow session pause (save state, resume later)
- [x] P1 1.2.10 Allow session resume from pause point
- [x] P1 1.2.11 Allow session abort (discard progress)
- [x] P1 1.2.12 Allow session undo (go back to previous item)
- [x] P1 1.2.13 Allow session skip (skip current item, return to queue)
- [x] P1 1.2.14 Show progress bar during session (items remaining / total)
- [x] P2 1.2.15 Show estimated time remaining based on avg speed
- [x] P2 1.2.16 Show session accuracy in real-time
- [x] P2 1.2.17 Show current streak (consecutive correct) during session
- [x] P2 1.2.18 Break reminder every N minutes (configurable, default 25)
- [x] P2 1.2.19 Auto-save session state every 30 seconds
- [x] P2 1.2.20 Auto-save on browser close / tab switch
- [x] P2 1.2.21 Session history: store last 100 sessions per learner
- [x] P2 1.2.22 Session history: allow review of past sessions
- [x] P2 1.2.23 Session history: show accuracy trend over time
- [x] P2 1.2.24 Session history: show speed trend over time
- [x] P2 1.2.25 Session recommendations: suggest session type based on due items
- [x] P2 1.2.26 Session recommendations: suggest session length based on energy
- [x] P2 1.2.27 Session recommendations: suggest time of day based on past performance
- [x] P2 1.2.28 Support "lightning mode" -- only new items, no reviews
- [x] P2 1.2.29 Support "review mode" -- only due items, no new
- [x] P0 1.2.30 Support "mixed mode" -- interleave new and due

### 1.3 Interleaved Practice

- [x] P2 1.3.1 Mix items from different modules in review queue
- [x] P2 1.3.2 Mix items from different concept types (recall, recognize, apply)
- [x] P2 1.3.3 Mix items of different difficulty levels
- [x] P2 1.3.4 Randomize interleaving order with deterministic seed
- [x] P2 1.3.5 Allow configurable interleaving strength (low, medium, high)
- [x] P2 1.3.6 Adaptive interleaving: increase when accuracy is high
- [x] P2 1.3.7 Adaptive interleaving: decrease when accuracy is low
- [x] P2 1.3.8 Track interleaving effectiveness (accuracy vs blocked practice)
- [x] P2 1.3.9 Interleave prerequisite concepts with target concepts
- [x] P2 1.3.10 Interleave related concepts (same module, different topics)
- [x] P2 1.3.11 Interleave unrelated concepts (cross-module, random)
- [x] P1 1.3.12 Configurable daily new item limit per module
- [x] P1 1.3.13 Configurable daily review limit per module
- [x] P2 1.3.14 Configurable total daily item limit
- [x] P2 1.3.15 Show interleaving breakdown in session summary

### 1.4 Weakness Detection

- [x] P0 1.4.1 Track per-concept accuracy (rolling 30-day window)
- [x] P0 1.4.2 Track per-concept difficulty rating (FSRS D value)
- [x] P0 1.4.3 Track per-concept review count
- [x] P2 1.4.4 Track per-concept last review date
- [x] P2 1.4.5 Track per-concept streak (consecutive correct)
- [x] P0 1.4.6 Flag concept as weak when accuracy < 60%
- [x] P2 1.4.7 Flag concept as struggling when accuracy 60-75%
- [x] P2 1.4.8 Flag concept as solid when accuracy > 75%
- [x] P2 1.4.9 Check prerequisite graph: if prerequisite is weak, flag dependency
- [x] P2 1.4.10 Show weakness chain: A depends on B depends on C (C is weak)
- [x] P0 1.4.11 Generate repair suggestion: "Review prerequisite X before Y"
- [x] P2 1.4.12 Generate repair suggestion: "Practice more exercises on Z"
- [x] P2 1.4.13 Generate repair suggestion: "This concept has no reviews, try one"
- [x] P2 1.4.14 Track weakness trend: improving, stable, worsening
- [x] P2 1.4.15 Cluster related weak concepts (e.g., "all pointer concepts are weak")
- [x] P2 1.4.16 Predict weakness before failure (accuracy trending down)
- [x] P2 1.4.17 Compute weakness severity score (0-100)
- [x] P2 1.4.18 Schedule weakness repair sessions automatically
- [x] P2 1.4.19 Track weakness resolution (concept moved from weak to solid)
- [x] P2 1.4.20 Show weakness history (when it became weak, when it resolved)
- [x] P2 1.4.21 Weakness dashboard: all weak concepts with severity and trend
- [x] P2 1.4.22 Weakness comparison: anonymous (how do others find this concept?)
- [x] P2 1.4.23 Weakness export: download weakness report
- [x] P2 1.4.24 Weakness alerts: notify when new concept becomes weak

### 1.5 Knowledge Health

- [x] P0 1.5.1 Compute knowledge health score: mastered / total concepts
- [x] P2 1.5.2 Compute knowledge health per module
- [x] P2 1.5.3 Compute knowledge health per course
- [x] P0 1.5.4 Classify concepts: mastered, learning, reviewing, unlearned
- [x] P2 1.5.5 Mastered = accuracy > 80% AND stability > 30 days
- [x] P2 1.5.6 Learning = reviewed at least once, not yet mastered
- [x] P2 1.5.7 Reviewing = mastered but due for review
- [x] P2 1.5.8 Unlearned = never reviewed
- [x] P2 1.5.9 Compute knowledge retention projection (30, 60, 90 days)
- [x] P2 1.5.10 Model knowledge decay using forgetting curves
- [x] P2 1.5.11 Identify knowledge gaps (prerequisites not met)
- [x] P2 1.5.12 Identify knowledge overlap (redundant concepts)
- [x] P2 1.5.13 Compute knowledge depth score (how well concepts are understood)
- [x] P2 1.5.14 Compute knowledge breadth score (how many concepts are covered)
- [x] P2 1.5.15 Track knowledge health trends over time
- [x] P2 1.5.16 Knowledge health comparison (anonymous)
- [x] P2 1.5.17 Knowledge health goals (set target score)
- [x] P2 1.5.18 Knowledge health milestones (50%, 75%, 90% mastered)
- [x] P2 1.5.19 Knowledge health export (JSON, CSV)
- [x] P2 1.5.20 Knowledge health API endpoint

### 1.6 Adaptive Pacing

- [ ] P3 1.6.1 Energy check-in before each session (1-5 scale)
- [ ] P3 1.6.2 Energy check-in optional (can disable in settings)
- [ ] P3 1.6.3 Store energy history per learner
- [ ] P3 1.6.4 Detect fatigue from performance drop (accuracy < 50% for 5+ items)
- [ ] P3 1.6.5 Suggest break when fatigue detected
- [ ] P3 1.6.6 Suggest stopping when fatigue persistent (3+ fatigue signals)
- [ ] P3 1.6.7 Adjust session length based on energy (high=30min, low=10min)
- [ ] P3 1.6.8 Adjust difficulty based on energy (high=hard, low=easy)
- [ ] P3 1.6.9 Adjust new item count based on energy (high=10, low=3)
- [ ] P3 1.6.10 Track session length preferences (learner sets preferred)
- [ ] P3 1.6.11 Track time-of-day performance (morning vs afternoon vs evening)
- [ ] P3 1.6.12 Recommend optimal learning time based on past performance
- [ ] P3 1.6.13 Prevent overactivity: cap at 2x preferred session length
- [ ] P3 1.6.14 Prevent underactivity: remind if no session in 24h
- [ ] P3 1.6.15 No streak shaming: missing a day is normal
- [ ] P3 1.6.16 Show "welcome back" after absence, not "you missed 3 days"
- [ ] P3 1.6.17 80% rule: set activity limits at 80% of perceived capacity
- [ ] P3 1.6.18 Adaptive daily goals based on energy + history
- [ ] P3 1.6.19 Pacing history: show energy patterns over weeks
- [ ] P3 1.6.20 Pacing preferences: save preferred pacing profile

### 1.7 Learning Patterns

- [ ] P3 1.7.1 Detect optimal review time (when accuracy is highest)
- [ ] P3 1.7.2 Cluster learning sessions by time-of-day
- [ ] P3 1.7.3 Predict performance based on time-of-day + energy
- [ ] P3 1.7.4 Detect dropout risk (no sessions in 7+ days)
- [ ] P3 1.7.5 Compute engagement score (sessions per week, items per session)
- [ ] P3 1.7.6 Compute learning velocity (concepts mastered per week)
- [ ] P3 1.7.7 Detect learning plateau (no improvement in 2+ weeks)
- [ ] P3 1.7.8 Detect learning breakthrough (sudden accuracy increase)
- [ ] P3 1.7.9 Infer learning style (visual vs text, fast vs slow)
- [ ] P3 1.7.10 Optimize learning path based on patterns
- [ ] P3 1.7.11 Show learning patterns dashboard
- [ ] P3 1.7.12 Export learning patterns data
- [ ] P3 1.7.13 Learning pattern comparison (anonymous)
- [ ] P3 1.7.14 Learning pattern recommendations
- [ ] P3 1.7.15 Learning pattern alerts (significant changes)

---

## 2. Course Authoring

### 2.1 Course Structure

- [x] P2 2.1.1 Course manifest (manifest.json) with id, title, version, description
- [x] P2 2.1.2 Module organization (group concepts into modules)
- [x] P2 2.1.3 Concept sequencing (ordered list within module)
- [x] P2 2.1.4 Prerequisite declaration (concept A requires B, C)
- [x] P2 2.1.5 Estimated time per concept (minutes)
- [x] P2 2.1.6 Difficulty level per concept (beginner, intermediate, advanced)
- [x] P2 2.1.7 Importance level (core, important, supplementary)
- [x] P2 2.1.8 Course versioning (semver: major.minor.patch)
- [x] P2 2.1.9 Course branching (alternative paths through content)
- [x] P2 2.1.10 Course bundling (multiple courses as one package)
- [x] P2 2.1.11 Course metadata (author, license, tags, language)
- [x] P2 2.1.12 Course dependencies (requires other courses)
- [x] P2 2.1.13 Course compatibility (minimum platform version)
- [x] P2 2.1.14 Course assets declaration (images, samples, etc.)
- [x] P2 2.1.15 Course review items declaration (auto-generated or manual)
- [x] P2 2.1.16 Course exercises declaration (per concept)
- [x] P2 2.1.17 Course visualizations declaration (per concept)
- [x] P2 2.1.18 Course navigation structure (linear vs tree)
- [x] P2 2.1.19 Course completion criteria (all concepts, or minimum score)
- [x] P2 2.1.20 Course certificate template
- [x] P1 2.1.21 Multi-course platform: landing page rendered data-driven from any course's manifest.json (unknown course ids return 404)
- [x] P1 2.1.22 Multi-course exercise seeding at startup: loop all course directories (fs::read_dir scan, reference-capture lambda required)
- [x] P1 2.1.23 Course JSON API includes module descriptions (feeds landing module list)
- [x] P1 2.1.24 html_escape core helper: server-side escaping for course strings interpolated into #html blocks (html_cbi interpolation is raw)
- [x] P1 2.1.25 Home page Available Courses grid loads every on-disk course client-side from GET /api/courses (was hardcoded to ELF + HAT; #html cannot loop; loading/error/noscript states; HTML-escaped titles/descriptions)
- [x] P1 2.1.26 DWARF course: fifth course shipped (manifest.json, chemical.mod, src/main.ch, 2 modules, 8 concepts) — listed automatically by /api/courses; served via render_dwarf_concept() with the same empty-string fall-through contract as HAT/PE/Mach-O
- [x] P1 2.1.27 Concept metadata backfill: all 72 ELF/PE/Mach-O concepts now carry estimated_minutes, difficulty and importance in their manifests (they previously fell through to the parser defaults of 10 min / intermediate / core, so study plans, time budgets and analytics mispriced every one of them). PE/Mach-O durations are read from each page's own lesson-meta line; ELF, whose pages declare no duration, uses a documented per-module rule. Generator: tools/backfill_concept_metadata.py
- [x] P1 2.1.28 HAT timed drills are now scoreable: hat-quant-drill, hat-verbal-drill and hat-analytical-drill were paper-only, so the platform could never record a result and the concept linter failed them (R3). They now use a shared client-side runner — timer, auto-submit on timeout, per-section score, per-miss explanation, localStorage result and retake. Question text and answer keys are GENERATED from the printed paper by tools/hat_drill_extract.py so the runner and the printed key cannot disagree. Runner: content/src/hat_drill_runner.ch + three generated *_bank.ch files. Verified with node --check on the served script plus a stub-DOM run of 18 assertions per drill (all-correct, all-wrong, blanks, timeout auto-submit, progress cleared, result retained, retake clears).
- [x] P1 2.1.29 COFF course: sixth course shipped (manifest.json, chemical.mod, src/main.ch, 2 modules, 8 concepts) — served via render_coff_concept() with the same empty-string fall-through contract as the other courses. Closes the loop the PE course left open: PE is COFF plus an optional header, and this course covers the object half
- [x] P1 2.1.30 COFF course verification harness: real objects for three dialects are produced with clang (--target=x86_64-pc-windows-msvc, x86_64-w64-windows-gnu, i686-pc-windows-msvc) and shipped in courses/coff/assets/samples/ together with coff_parse.py, a parser written from the PE/COFF spec, and crosscheck.py, which compares the two parsers field by field. Currently reports TWO INDEPENDENT PARSERS AGREE ON EVERY FIELD across 5 objects, 3 dialects, ~1200 relocations and 58 aux records. Re-runnable from inside the repo, so every number in the course can be re-checked

### 2.2 Concept Authoring

- [ ] P3 2.2.1 Concept file (.ch) with #html macro for content
- [ ] P3 2.2.2 Concept file with #css macro for styling
- [ ] P3 2.2.3 Concept file with #js macro for interactivity
- [ ] P3 2.2.4 Concept file with #md macro for markdown content
- [x] P3 2.2.5 Concept template: standard lesson layout
- [x] P1 2.2.21 HAT lesson: network routing sets — one-way circuit vs two-way radio, exact intermediary count, shortest path, both-channel proof (hat-network-routing; sample-paper genre: 6 questions shared setup)
- [x] P1 2.2.22 HAT lesson: multi-paragraph reading comprehension — paragraph-job labels, main idea as first+last across the arc, structure stems stay local, two multi-paragraph quizzes + retrieval blanks (official sample has multi-paragraph Jamestown passage; course passages were single-paragraph)
- [x] P2 2.2.23 HAT lesson: clock-face angle between hands — minute 6m, hour 30h+0.5m, smaller angle (official sample: 25 past 2 = 77.5 degrees)
- [x] P2 2.2.24 HAT lesson: similar-triangle area ratio equals square of scale factor — altitudes scale by square root (official sample: areas 9:16 → altitudes 3:4; taught in hat-geometry)
- [x] P2 2.2.25 HAT lesson: AP inverse trick — identify the term given as p-th is q (official sample: (p+q)th term = 0; taught in hat-sequences)
- [x] P3 2.2.26 HAT lesson: logarithms (exponent inverse; official samples: log3 27 = 3, telescoping log chain; taught in hat-exponents-roots)
- [x] P3 2.2.27 HAT lesson: exterior angles of a triangle/polygon — sum always 360 degrees, regular n-gon exterior = 360/n (official sample: sum of exterior angles of any polygon; taught in hat-geometry)
- [x] P3 2.2.28 HAT lesson: degree of a polynomial — max total exponent in one term, multivariable adds within term (official sample: x5yz2+x4y3z2+xyz+10 has degree 9; taught in hat-algebra)
- [x] P3 2.2.29 HAT lesson: functions domain and range — domain excludes zero denominators, range tracks cancelled inputs (official samples: domain of (3x-5)/(2x+6) excludes -3; range of (x²-25)/(x+5) excludes -10; taught in hat-algebra)
- [x] P3 2.2.30 HAT lesson: variance and standard deviation — mean, average squared deviation, sqrt for SD (official sample: variance of 1,3,5,7,9 = 8; taught in hat-data-probability)
- [x] P3 2.2.31 HAT lesson: Cartesian product of sets — ordered pairs, n(A×B)=n(A)×n(B) (official sample: |{1,2,4}×{1,3,4,5,7}|=15; taught in hat-sets-venn; use &#123;/&#125; entities for braces inside #html)
- [x] P3 2.2.32 HAT lesson: rational vs irrational numbers — p/q definition, perfect-square roots only (official samples: 3/4 rational, root 2 irrational; taught in hat-number-properties)
- [x] P3 2.2.6 Concept template: exercise-focused layout
- [x] P3 2.2.7 Concept template: visualization-focused layout
- [x] P3 2.2.8 Concept template: mixed layout
- [ ] P3 2.2.9 Concept inheritance: base concept to specialized
- [ ] P3 2.2.10 Concept composition: combine smaller concepts
- [x] P3 2.2.11 Concept validation: linting for common mistakes
- [x] P3 2.2.12 Concept validation: required sections check
- [x] P3 2.2.13 Concept validation: exercise count check
- [x] P3 2.2.14 Concept validation: asset availability check
- [x] P3 2.2.15 Concept validation: link validity check
- [x] P3 2.2.16 Concept validation: accessibility check
- [ ] P3 2.2.17 Concept preview: render concept without publishing
- [ ] P3 2.2.18 Concept diff: compare two versions of a concept
- [ ] P3 2.2.19 Concept history: view all changes to a concept
- [ ] P3 2.2.20 Concept rollback: revert to previous version
- [x] P1 2.2.33 Concept linter: R1b no longer false-positives on `for (` / `if (` shown inside `<code>` or `<pre>` examples — a lesson that teaches code is not Chemical code. Markup is stripped before the scan, so genuine for-loops in Chemical (macho_dysymtab) are still reported. scripts/lint-concepts.sh
- [x] P1 2.2.34 Concept linter: R3 accepts the client-side drill runner (`hat-drill-root`) as a valid exercise surface, not only inline `quiz-option` buttons — the timed HAT drills render their own options from a generated bank
- [x] P1 2.2.35 Per-option quiz feedback plumbing for the ELF course: all 24 ELF concepts defined a local `checkQuiz(quizId, btn, correct)` that hardcoded its verdict to the strings 'Correct!' and 'Not quite. Try again next time.', so all 144 options in the flagship course gave the same two sentences and never explained why a wrong option was wrong. Rewritten to read `data-explain` off the button, matching PE/Mach-O/HAT/DWARF. Additive: options without an explanation keep today's behaviour. Generator: tools/elf_quiz_feedback.py
- [x] P1 2.2.36 ELF per-option feedback: Module 1 (bytes, binary-representation, file-layout) fully authored — 18 of 144 options now explain the misconception behind every distractor. bytes and binary-representation answers independently re-derived (0x41 = 4*16+1 = 65; 48 65 6c 6c = "Hell"; 0x1a = 26)
- [ ] P1 2.2.37 ELF per-option feedback: remaining 126 options across 21 concepts (elf-identification … execution). Module 1 sets the pattern; each answer must be re-verified against readelf/the gABI before its explanation is written
- [x] P1 2.2.38 Exercise audit: no multiple-choice question in any of the five courses has two options with identical text. Caught one in binary-representation quiz-bin-2 (two options both "26", one marked correct and one not); replaced the duplicate with a distinct, plausible distractor. Re-run the duplicate-text scan after any exercise edit
- [x] P1 2.2.39 COFF course: all 48 quiz options carry data-explain, so every distractor states the misconception behind it (ELF, by contrast, has 18 of 144). The COFF exercises target verified traps: the packed x64 relocation layout that yields type 0 for every record, the alignment bitfield that makes seven bitmask tests pass, the off-by-one aux record that is a symbol slot but not a symbol, and a checksum difference under Selection ANY pointing at a source-level bug
- [x] P1 2.2.40 Documented three places where the COFF specification and the compiler disagree, taught as observed discrepancies rather than smoothed over: (1) the section-definition aux record puts CheckSum at 0x08 and NumberOfLinenumbers at 0x10, the reverse of the documented order — proven independently by the invariant that Number equals the section index across all 58 aux records; (2) the x64 relocation layout the spec documents as packed into the first dword is not what clang emits, it emits the plain DWORD/DWORD/WORD; (3) bigobj is not the classic header with wider fields, the fields move, proven by observing that a two-byte signature patch is rejected by every reader
- [x] P1 2.1.31 DWARF Module 3 shipped: 7 concepts (the DIE tree, DW_AT_type chains, scopes and inlining, location expressions, .eh_frame CFI, split DWARF, and the aranges/pubnames indexes), taking the course to 15 concepts across 3 modules. Registered in the manifest, routed through render_dwarf_concept(), and emitted by the static build
- [x] P1 2.1.32 DWARF verification harness, three independent readers: assets/dwarf_decode.py (written from the specification), assets/dwarf_sections.py (so the decoder does not lean on readelf), and assets/crosscheck.py comparing the decoder against BOTH readelf and llvm-dwarfdump. Compares per file: abbreviation entry counts, every DIE's (depth, offset, abbrev code, tag), every attribute's (DIE, byte offset, name), the .debug_aranges unit headers and tuples, the .eh_frame FDE address ranges, and the CFI opcode sequence. Re-runnable from inside the repo; currently reports ALL READERS AGREE across 5 binaries
- [x] P1 2.1.33 COFF Module 3 shipped: 3 concepts (bigobj, the .lib archive, and line numbers), taking the course to 11 concepts across 3 modules. The archive lesson is backed by a new assets/samples/ar_decode.py, an archive parser written from the format description
- [x] P1 2.2.42 DWARF findings that only an independent decoder could produce, each taught as an observed discrepancy: readelf APPLIES RELOCATIONS to a .o, so its output disagrees with a hex dump (verified: .rela.debug_info says .debug_str+85 where the file holds zeros) which is why every byte-level lesson uses a linked binary; .debug_abbrev holds several tables and reading past the terminator lets the second overwrite the first, which mislabels every DIE while the byte walk stays in step; one .debug_info holds one unit per compilation, so a reader that stops at the first reports half the functions with no error; the .debug_aranges tuple table starts at byte 16 and not 12, decoding the first address as 0x114900000000; an .eh_frame FDE has no version and no augmentation; the .eh_frame CIE pointer is relative to its own field position while .debug_frame's is absolute; DW_EH_PE 0x0b is sdata4 not 8 bytes, and address_range ignores pcrel; in a .dwo, strx resolution needs DW_AT_str_offsets_base from the skeleton, and getting it wrong returns "unsigned int" as the compiler
- [x] P1 2.2.43 COFF Module 3 findings: clang does NOT switch to bigobj at 70,017 symbols; a correctly laid-out bigobj is misidentified by llvm-readobj as a short-import library because 0x0000FFFF is shared and LLVM dispatches on the signature alone; llvm-readobj contains no string "bigobj" at all, so no tool on this machine can validate the format; the ar archive carries TWO symbol indexes both named "/", distinguished by a 0x02 marker, with the plain one big-endian and the extended one little-endian, in different (link vs sorted) orders; the member size field is DECIMAL, and odd-sized members need one pad byte for even alignment
- [x] P1 2.2.44 Both courses now state their own verification boundary explicitly, and the landing pages list the unwritten remainder as planned-but-absent rather than as 404s. DWARF does not teach the .debug_loclists entry encoding because the two readers disagreed and no third was available to break the tie; location EXPRESSIONS, which is what -O0 produces, is taught and fully cross-checked instead. COFF does not teach linker map files, incremental linking or LTCG because there is no COFF linker installed, and courses-todo.md marks those BLOCKED on tooling rather than merely unwritten. **Superseded in part by 2.1.34/2.1.35: every one of those blockers was later found to be false.** .debug_loclists was taught once llvm-dwarfdump supplied the third reader (2.2.46), and GNU ld does link COFF via its i386pe emulation, so map files and the link step are now taught too (2.2.45). The rule this item established — check the tooling before writing "blocked" — is the part that mattered
- [x] P1 2.2.45 Linter rule R5 only scanned /courses/elf/lessons/, so every cross-course link was unvalidated: a link to /courses/pe/lessons/pe-import-directory (a concept that does not exist) passed the linter while 404ing at runtime. R5 now scans any course and resolves the id against that course's own manifest, which covers all six courses and still permits a deliberate cross-course link. Verified by introducing a bad id and confirming it fails
- [x] P1 2.2.41 html_cbi parse-failure modes now established by isolation rather than guesswork: four constructs are proven to break (literal braces, a raw quote inside an attribute value, an entity between two digits, a missing `>` on a closing tag) and four plausible suspects are proven fine (`@` anywhere including inside a mangled COFF symbol name, `C++`, a lone `/` as element text, numeric entities). Two earlier diagnoses were wrong and are recorded as such. Recorded in the implementation_gaps skill, with the isolation recipe
- [x] P1 2.1.34 COFF Module 4 shipped: 3 concepts (the link, map files, and COMDAT in the linker), taking the course to 14 concepts across 4 modules and completing it. The "no COFF linker on this machine" blocker was wrong: GNU ld supports the i386pe emulation, and with --oformat pei-i386 forced it links real COFF objects into a real PE32 image. A real link is now the evidence for the previous module's claims — IMAGE_REL_I386_REL32 goes from 00 00 00 00 to e8 0e 00 00 00 with 0x0e == 0x401020 - (0x40100d + 5), and MEM_DISCARDABLE/LNK_REMOVE sections are observed being dropped
- [x] P1 2.2.57 COFF Module 4 findings: (1) COMDAT deduplication observed working end to end — two byte-identical 12-byte .text sections, both Selection Any (0x2), both checksum 0xF787F24A, one discarded per the map file and one ?shared@@YAHH@Z surviving in the disassembly; (2) a REPRODUCED SILENT MISCOMPILATION — changing one character of an inline body makes the checksum differ (0x3B2D87C1) and GNU ld PE mode discards the differing copy anyway, so use_b() returns 33 where the source says 44, with no diagnostic; (3) the map file's *fill* rows show 15 of 69 bytes of .text is linker-inserted alignment padding, and the map, llvm-readobj's VirtualSize and the disassembly give three different correct sizes for one section
- [x] P1 2.1.35 DWARF Module 4 shipped: 4 concepts (location lists, range lists, portability, and packages), taking the course to 19 concepts across 4 modules and completing it. Every previously blocked item fell: .debug_loclists (llvm-dwarfdump is the third reader that broke the tie), .debug_rnglists, address_size 4 and aarch64 producers (clang --target=i386-linux-gnu / aarch64-linux-gnu), and .dwp packages (llvm-dwp exists)
- [x] P1 2.2.46 DWARF Module 4 findings: (1) the .debug_loclists disagreement is ADJUDICATED — readelf decodes a version-5 DW_LLE stream with a version-4 view-pair grammar and reports "location view pair", while llvm-dwarfdump's offsets are each reachable by consuming the bytes claimed; both readers agree on the DIE-referenced offsets 0x10, 0x24 and 0x47; (2) readelf --debug-dump=rnglists prints nothing for inline_O2.o, a separate gap; (3) a 32-bit and a 64-bit build of the same source have IDENTICAL unit_length (165) because DW_FORM_addrx stores an index, so address width never enters the DIE tree; (4) version 5 inserts unit_type into the header, moving the first DIE from 0xb to 0xc with nothing else in the file to indicate it; (5) .debug_rnglists holds THREE back-to-back lists in one section using two different opcode families, and .debug_cu_index stores both units' 64-bit DWO_ids verbatim
- [x] P1 2.2.47 Both courses checked off in docs/courses-todo.md, and the file reduced to one plain line per course: five duplicate/partial DWARF and COFF entries and all added prose removed, with the rule ("only check and uncheck items") written into the course_generation skill along with a table of where that information belongs instead
- [x] P1 2.1.36 DWARF Module 5 shipped: 4 concepts (DWARF 4 in practice, type units, call sites, and .debug_frame), taking the course to 23 concepts across 5 modules. Every "blocked" item from the Module 4 record was re-tested for producibility before writing, and all four closed: gcc -gdwarf-4 and clang -gdwarf-4 for the pre-restructure version, gcc -fno-asynchronous-unwind-tables for .debug_frame, gcc -fdebug-types-section for type units, and gcc -O2 on a tail-calling file for call sites
- [x] P1 2.2.48 DWARF Module 5 findings: (1) THE TYPE SIGNATURE IS NOT AN OPAQUE HASH — readelf prints only the first 8 of a type signature's 16 bytes, and u32[2] of the full field is the unit's own type_offset (0x1d in the DWARF 4 build, 0x23 in the DWARF 5 build, matching readelf's Type Offset exactly in both), while u32[0] and u32[1] are version-stable and u32[3] differs; so two units printing the same signature are provably not the same field. WHY the offset is in there is recorded as an open question, not answered, because no second implementation reads the low half. (2) Type units live in .debug_types at DWARF 4 and INSIDE .debug_info with unit_type=2 at DWARF 5, verified by section count. (3) A DWARF 4 unit has no .debug_addr, .debug_str_offsets or .debug_line_str because the forms that need them do not exist there — the abbrev tables show v4 using only sec_offset/string/strp against v5's addrx/strx. (4) A tail call verified field by field against three instructions: DW_AT_high_pc 0xe matches the function length, DW_AT_call_tail_call 1 matches a jmp, and DW_AT_call_value DW_OP_lit3 matches the literal 3 in "mov $0x3,%edi". (5) DW_AT_call_origin names the callee and not the kind of call — it points at a definition for the tail call and at a declaration for the ordinary one, so only DW_AT_call_tail_call answers the tail-call question. (6) .debug_frame stores the FDE's CIE reference as an ABSOLUTE section offset where .eh_frame uses a pc-relative one, same four bytes, different meaning — and the sample file is the one case where both readings agree, which is why the concept says so
- [x] P1 2.2.49 The known Chemical #html parse traps cost three build cycles this session and are now written down with their error messages: a bare "<" in element text whenever the next character is not a letter, "/" or "!" (three forms hit: "<=" and "<" in pseudo-code, and a "<--" arrow in a hex dump, all reporting "tag names must start with letters"); a mismatched closing section tag such as </thead> for an opened <tbody>, reported at a column PAST THE END of the line; and a stray </pre> inside a <div class="formula"> block that never had a <pre>. Also confirmed again: a literal brace inside <pre> — which is why C source in this course is shown as a table of what each line does rather than as verbatim code, since no course file has ever contained a brace in a pre block
- [x] P1 2.1.37 COFF Module 5 shipped: 4 concepts (ARM64 relocations, TLS, weak externals, and .drectve), taking the course to 18 concepts across 5 modules. The Module 4 lesson held — clang --target=aarch64-pc-windows-msvc produces ARM64 COFF with no MSVC toolchain, exactly as --target=i686-pc-windows-msvc did for Module 1 — and every candidate gap was tested for producibility before any of it was written
- [x] P1 2.2.50 COFF Module 5 findings: (1) FIVE ARM64 relocation types from a four-function file, and the offsets are the point — three PAIRS four bytes apart naming the same symbol, because an ARM64 address is formed by two instructions; the page-base field is a 21-bit SIGNED page-number delta and the offset field a 12-bit UNSIGNED value within the page, and the A/L suffix is the only difference between the two variants while both compute the same value, so misreading it writes a valid number with the wrong meaning. BRANCH26 additionally divides by four because the field counts instructions, and MUST range-check because 26 bits scaled by four caps at 128 MB. (2) .tls$ has characteristics 0xc0300040, BYTE-IDENTICAL to .data — the name is the only thing marking it as thread-local, and its contents are an initial-value template rather than the variables. (3) Weak externals are storage class 105 with a REQUIRED aux record naming a fallback that is an absolute symbol at value 0, so the address of a missing function is the address of a name; the observable cost is a load/test/branch in the generated code instead of a direct call. (4) .drectve is 23 bytes of free text with characteristics LNK_INFO + LNK_REMOVE, and its discardal is confirmed by controlled comparison — the pragma present shows ".drectve 0x17" in the map discard list, the pragma absent shows no such row, same compiler and flags. (5) Two findings recorded rather than settled: readelf labels WeakExternal Characteristics 0x3 as "Alias" where the specification says 0x3 is ANTI_DEPENDENCY, with no second reader available; and GNU ld PE mode cannot link TLS at all, failing on _tls_index and _tls_array, though its map does show .tls$ renamed to .tls
- [x] P1 2.1.38 WebAssembly course started: seventh course, Module 1 "The Container" with 4 concepts (why a binary format, the eight-byte header, the section framing, and LEB128), 79 minutes. Toolchain checked before any content was written and it is the strongest position of any course here: wabt 1.0.36 (wat2wasm, wasm-objdump, wasm-validate, wasm2c, wast2json), LLVM 21 as a fully independent second implementation, and clang --target=wasm32 as a producer, so three readers agree on every claim. The compiled output of one C file is already a module with no separate object format, which is unique among the formats in this collection
- [x] P1 2.1.39 WebAssembly verification harness: assets/samples/wasm_decode.py written from the specification and deliberately not a validator (the docstring explains why that distinction is itself a teaching point), and assets/samples/crosscheck.py requiring all three readers to agree on every section of every sample. THE HARNESS IS ITSELF TESTED by three injected faults (a section size byte, two swapped section ids, a magic byte), each detected. Two bugs in the harness were found and fixed while writing it, both recorded because they are what a reader of this format gets wrong first: comparing the id offset against wabt's start= which is the payload offset, an off-by-two that looks like a tool disagreement on every section; and custom-section names, which wabt prints quoted and llvm lower-cases
- [x] P1 2.2.51 WebAssembly Module 1 findings: (1) wabt and llvm report DIFFERENT SIZES for the same custom section, verified on four sections across two files — wabt gives the declared size (name included) and llvm the payload after the name, and they coincide for standard sections because those have no name; the trap is that the difference is 1 + name length, which varies per section, so a reader using the wrong number lands inside the section where the next section's small valid id and length make it produce a section that does not exist. (2) wasm-objdump prints i32.const and i64.const operands as UNSIGNED, verified on four real immediates where 7f is shown as 4294967295 and c0 fb 42 as 4293967296, while signed LEB128 recovers the source constants exactly — so it is a presentation choice, and a reader who takes the disassembler's number as the constant is wrong on the values real code uses most. (3) The section ordering rule produces three different tool behaviours on one malformed file: wasm-validate names the rule, llvm-objdump expresses it as a consequence ("out of order section type"), and wasm-objdump prints a section table without complaint. (4) Custom section contents are not validated at all, demonstrated by a malformed custom section that passes wasm-validate and prints a name missing its first character
- [x] P1 2.1.40 WebAssembly course completed: all five modules, 13 concepts, 274 minutes. Module 2 "Declarations" (the type section and why a signature's identity is a position rather than a name, imports and the five independent index spaces, tables/memories and the limits flag that is a length in disguise, globals and the mutability bit). Module 3 "The Body" (the code section and its run-length local declarations, instruction encoding and the reserved top four opcode bits). Module 4 "Data Placement" (all eight element forms, the three data forms, and the datacount section that exists only to let the code section be checked). Module 5 "Objects" (custom sections the core ignores, the five-byte LEB128, and a relocation that patches code). Prev/next chain verified against manifest order, all intra-course and cross-course links resolve, 220 files lint PASS with 0 fails
- [x] P1 2.2.52 Object Files Module 3 finding, and a CORRECTION to an earlier finding: the -4 in a relocation listing is the EXPLICIT addend in Elf64_Rela, NOT an implicit addend in the section bytes. demo_elf.o's .text at offset 4 is `00 00 00 00` and its r_addend is 0xfffffffffffffffc. Proved by building the 32-bit counterpart of the same source, which uses REL and has no addend field, and where `fc ff ff ff` really is in the bytes at the field. COFF has no addend at all and the bytes are zero there too -- its bias comes from the DEFINITION of IMAGE_REL_AMD64_REL32, proved by linking with `ld -m i386pe` and finding `e9 1b 00 00 00` in the output where the object had `e9 00 00 00 00`, with 0x1b = 0x401040 - 0x401025 and the 0x401025 appearing in no input file. Finding 4 of the research record is superseded
- [x] P1 2.2.53 Object Files Module 3 finding: COFF-x86-64 has NO PLT relocation variant -- an object's call and its data references are both IMAGE_REL_AMD64_REL32 -- but COFF-i386 DOES distinguish them (REL32 versus DIR32), so "COFF has no PLT variant" is a statement about the target and not about the format. Reinforces the earlier finding that a linker implements a vocabulary per TARGET
- [x] P1 2.2.54 Object Files Module 4 finding, and a CORRECTION: modern clang does NOT use a Mach-O linkonce section for COMDAT. ca_macho.o has two sections (__text and __eh_frame), no member section and no group; the whole mechanism is n_desc = 0x0080 (N_WEAK_DEF) on an ordinary symbol in an ordinary __text. `grep -i linkonce` over llvm/BinaryFormat/MachO.h returns nothing, so the term is not even part of LLVM's Mach-O definitions. Finding 35's "Mach-O uses a linkonce section type" is superseded, and the replacement is a better lesson: two of the three formats put the answer in a section and the third puts it in a symbol
- [x] P1 2.2.55 Object Files Module 4 finding: the C counterexample that makes the COMDAT rule precise. Measured four spellings of one function: C `inline` produces an UNDEFINED symbol and no group; C `static inline` produces a local symbol and no group; C `inline` plus an `extern` declaration produces a GLOBAL symbol, still NO group, and two such TUs fail with `multiple definition`; C++ `inline` produces a global WEAK symbol plus an SHT_GROUP and links silently. So a group exists only for a symbol with external linkage that more than one translation unit is licensed to define, and C has no mechanism for it at all
- [x] P1 2.2.56 Object Files Module 4 findings: (1) COFF has NO weak flag anywhere -- the whole mechanism is renaming the symbol to `.weak.<name>.default.<referrer>`, and the referrer's name is in there because COFF has no per-symbol COMDAT and needs a name unique per (definition, referrer) pair; the undefined-weak case is `Section = IMAGE_SYM_ABSOLUTE (-1)` with `Value = 0`, which structurally reuses the category that already means "constant". (2) Weak defeat removes the SYMBOL and not the BYTES: merging a weak `maybe` with a strong one leaves the weak body in .text at offset 0 with no symbol pointing at it, 21 + 22 bytes of input becoming a 54-byte merged section. (3) GNU ld's archive resolution is a FIXED-POINT ITERATION, not a backwards scan: an archive in the order l2, l1, l3 defeats a single forward pass (l2 is passed before anything wants level2) AND a single backward pass (l1 is reached while l2 is ahead of the cursor), and the link succeeds anyway
- [x] P1 2.2.58 The `#html` brace trap and bare-`<` trap are FIXED in the Chemical compiler (`html_parser` / `html_cbi`), which unblocks verbatim code in every course. Three distinct changes, and only one of them is a design decision: (1) BUG -- a `}` inside a `#html` block at brace depth 1 was the macro's OWN closing brace, so a stray `}` silently ended the macro and dropped the rest of the file, with the error reported ~250 lines later; (2) BUG/CONFORMANCE -- the lexer entered tag mode on ANY `<`, and now implements the html "tag open" state, so a `<` before anything other than `!`, `/` or an ASCII letter is text (a `<` before a LETTER is still a tag, exactly as in a browser, so `ref.null <heaptype>` still needs `&lt;heaptype>`); (3) DESIGN -- inside `<pre>` a bare `{` and `}` are now literal characters, matching browser behaviour, and the new explicit form `@(expr)` supplies a value there. `@(` was chosen over `${}` (collides with JS/shell/Kotlin/Dart/PHP/C#/Groovy, and the `\${}` escape would corrupt the displayed sample), `{{}}` (collides with Rust `format!("{{}}")` and Python f-strings), `*{}` (collides with `**{` in Python/Ruby and minified CSS `*{`), `<$>` (collides with Perl `<$fh>` and shell `done <$file`), and a `verbatim` attribute (a string compare on every identifier at lexer level, versus a single-char compare for a symbol). `@(` is accepted EVERYWHERE in the macro, not only in `<pre>`, so there is one rule rather than one rule per context, and `@{ ... }` statements and `@if`/`@else` are unchanged. Outside `<pre>` a bare `{` is still the interpolation sigil, so `<code>` in prose still needs `&#123;` / `&#125;`. Verified in the compiler's own suite at 1217/1217, 2229/2229 and 711/711, with 71 new tests across `compiler_plugins/html` and `compiler_plugins/html_runtime`; reverting only the source makes the new tests fail to COMPILE, which is the original symptom. Two pre-existing bugs surfaced while testing and are also fixed: `@Override and @app` lost the space between the two words, and the RUNTIME html parser silently DELETED braces from text (`<div>{ x }</div>` came back as `<div> x </div>`) because the runtime wrapper never implemented the chemical-mode handling that `html_cbi` does. Findings 2.2.41 and 2.2.49 describe the old behaviour and are superseded on the three points named here
- [x] P1 2.2.59 `tools/html_balance.py` re-scoped for the fixed lexer rules, and the implementation_gaps skill's six-point scan list now names it as the implementation of that scan. It no longer flags a brace inside `<pre>` (legal now), no longer flags a `<` before a non-letter (legal now, and `<=` in pseudo-code was being escaped for months on the strength of a rule that no longer exists), and its `<`-before-a-letter check now subtracts the set of real HTML tags so `<code>` inside a `<pre>` is not reported -- the previous shape check reported every nested tag. The whole `obj` course now scans clean. TWO PRE-EXISTING TOOL DEFECTS remain and are recorded rather than fixed: the tool raises on any `content/src/*.ch` with no `#html` block (landing pages and asset modules), and it false-positives on a genuine Chemical expression in an attribute, flagging `onclick="window.scrollTo({top:0,...})"`
- [x] P1 2.1.58 "Symbol Resolution and Symbol Tables" course COMPLETE: 12 concepts in 4 modules, 253 minutes, every claim measured rather than quoted. Module 1 (identity) separates the two questions a linker is asked, and shows that `visibility("hidden")` and `visibility("internal")` DEMOTE the binding to STB_LOCAL and vanish from .dynsym -- so for two of the four visibility values the answer is not in st_other at all, and only PROTECTED stays exported AND un-preemptible. Module 2 (algorithm) traces GNU ld's demand-driven single pass by hand: `MA.a MB.a` links while `MB.a MA.a` fails on `b_data`, and the map file shows libMB.a(mb.o) was NEVER read off the archive. COMMON is shown to be a storage class rather than a weaker definition -- the same three files link and print 5 under -fcommon and fail with "multiple definition" under -fno-common, decided entirely by the section index (COM vs 3). Module 3 (runtime) establishes that `-z now` changes NO CODE: the .plt is 0x30 bytes and instruction-identical in both builds, the only difference being DT_FLAGS BIND_NOW and DT_FLAGS_1 NOW, proved behaviourally with a call that exists in the binary and never executes (lazy never resolves it, -z now does). GLOB_DAT vs COPY is shown to be chosen by the code model of the executable's own translation unit, with the trap that -no-pie at link time alone still yields GLOB_DAT. Module 4 (versioning) decodes verdef from the bytes because readelf's Cnt: does not match what the script listed: vd_cnt counts the node's own name PLUS its parent, and the parent is the LAST verdaux, so a node with a parent always has cnt >= 2; and vd_hash is the plain ELF hash, verified four times including the SONAME. Three versioning traps recorded, two of them silent: a symbol listed in two version nodes yields ONE entry with the FIRST node winning, and a version script can only narrow visibility so -fvisibility=hidden beats its `global:` clause. Also: __start_SEC/__stop_SEC are GLOBAL PROTECTED, which is the one place in the collection where the TOOLCHAIN chooses PROTECTED rather than the author. Finding 20 is new and counter-intuitive: .gnu.hash bucket heads are NOT in dynsym-index order (libc has buckets[0]=2620 and buckets[1]=977), so the array cannot be binary-searched. TWO CLAIMS RETRACTED rather than shipped: a copy-relocation divergence bug, built three ways and never reproduced on x86-64/glibc 2.43, and a "bucket heads are sorted" invariant that real files violate -- both retractions are stated on the course's own landing page. Assets: build_samples.sh regenerates every specimen from scratch and crosscheck.py asserts 84 load-bearing claims, all passing; two of those checks exist because the harness caught an over-broad claim in the course's own text during writing
- [x] P1 2.1.41 WebAssembly Module 2 findings: (1) imports are counted FIRST and in FIVE independent index spaces, so a module importing one function, one table and one global and defining two functions has func[0]/table[0]/global[0] as the imports and the definitions at 1 and 2, while memory[0] is a definition because nothing was imported — verified against wabt's own global numbering, and the value-check in the harness tripped over the same rule before being corrected for the index base. (2) The limits flags byte is a LENGTH not a tag: 0x00 means one count follows and 0x01 means two, so a reader that reads a maximum unconditionally consumes the next section's first byte and desynchronises silently; bit 1 is `shared` and bit 2 is `memory64`, both added to a byte that originally had one meaning. (3) An imported global has no initial value in the file at all, because the host owns it
- [x] P1 2.1.42 WebAssembly Module 3 findings: (1) adjacent local declarations of the same type are MERGED into one run-length group, so `(local i32) (local i32) (local i64) (local f32) (local i32 i32 i32)` is four groups and seven locals rather than six groups, and the groups are deliberately NOT reordered to compress better because group order is local numbering. (2) `call_indirect` has TWO immediates, type index then table index, the second appended by the reference-types proposal, so a reader written against the 2017 specification decodes the table index as the next opcode; `memory.size` and `memory.grow` likewise carry an always-zero memory index. (3) The `align` immediate on a load is a BASE-2 LOGARITHM, so `i32.load` carrying `align 2` means four bytes, confirmed on four real load instructions. (4) A block type is overloaded and disambiguated by a one-byte peek: 0x40 is the empty type, a valtype byte is a single result, anything else is a signed LEB128 type index
- [x] P1 2.1.43 WebAssembly Module 4 findings: (1) the element section has EIGHT segment forms and wabt's writer only emits FOUR of them — writing `(elem (i32.const 0) (ref.func $f0))` produces flags=0, not flags=4, so forms 4 through 7 were verified by hand-assembling the bytes and confirming wasm-validate accepts them and wasm-objdump reads them back with the expected flags= value. All eight are now verified and all three data forms likewise. (2) The elemkind byte's only legal value is 0x00 and it is NOT a valtype — 0x70 is the valtype encoding of funcref, used in forms 5 to 7 — so a reader expecting 0x70 reads the element count from the wrong byte; the byte appears only where the table section cannot supply the element type, which is exactly the passive and declarative modes. (3) datacount is a forward declaration that makes single-pass validation possible, and it is REQUIRED only when the code section names a data segment — a section that is four bytes of overhead for most modules and load-bearing for the rest
- [x] P1 2.1.44 WebAssembly Module 5 findings: (1) EVERY section size in a real LLVM-produced object is a FIVE-BYTE LEB128, verified across all eight sections of externs.o and again at the inner level for a `linking` subsection size — a decoder written against the hand-built samples in this course, which are the only files where the minimal encoding is correct, misaligns on the first section of every real object, and this is the most practically important finding in the course. (2) The `linking` section is version 2 and contains subsections of (id, size, payload), with id 8 the symbol table; wabt reports symbol kinds F/G/D/T, binding, visibility and undefined flags, and segment/offset/size for data symbols. (3) reloc.CODE carries R_WASM_MEMORY_ADDR_LEB, a relocation that patches a VARIABLE-WIDTH LEB128 inside an instruction stream, which is strictly harder than a PE base relocation's fixed-width field because a wrong width yields a misaligned instruction stream rather than a wrong address. (4) The data symbol record's field order was NOT reconciled from one sample: the walk leaves two bytes unaccounted for and then reports subsection ids 2, 4 and 3 where the bytes plainly say 5. Recorded as encountered-not-decoded; the concept teaches the observed desync rather than a guess
- [x] P1 2.1.45 WebAssembly harness extended from framing-only to three levels (structure, counts, values) and each level confirmed to fail when it should. Two findings came from testing the harness rather than trusting it: a count-only check does NOT catch a wrong value, established by deliberately breaking the decoder's i32.const path to read unsigned and finding the sabotage undetected because no sample then had a negative i32 initialiser — globs.wasm was added and the sabotage is now caught; and the value check initially got the index base wrong because wabt numbers globals in the GLOBAL index space, so it tripped over the very rule the wasm-imports concept teaches. Sample set grew from 5 files to 19, all green
- [x] P1 2.1.46 WebAssembly concept finding: a draft of `wasm-types` asserted that the shipped decoder was off by one on type offsets, on the strength of a quick mental count. Checking the arithmetic against a hand count of the sixteen-byte section showed the decoder was RIGHT and the draft was wrong. Corrected, and the episode kept as the concept's lesson, with the three rules that would have caught it: count the bytes yourself, check the total, and believe an unverified tool until the arithmetic says otherwise
- [x] P1 2.1.47 JVM Class File course started: eighth course, Module 1 "The Container" with 4 concepts (why a class file, the header and the fixed order, the constant pool, modified UTF-8), 78 minutes. THE STRONGEST TOOLCHAIN POSITION IN THE COLLECTION and the only course with FOUR independent implementations: javac 26.0.1 as producer, javap -v as reader 2, java.lang.classfile (the JDK's own standard parsing API, added in Java 22) as reader 3, and the JVM verifier itself as a boolean oracle that shares no code with the other three. 21 class files produced by javac on this machine, all read by all three readers with zero disagreements
- [x] P1 2.1.48 JVM verification harness: assets/samples/class_decode.py written from the JVM Specification and deliberately NOT a validator (the docstring explains why that distinction is itself a teaching point — a class file is the rare format where a decoder can be completely correct about the bytes and still be handed a file no JVM will load), assets/samples/Cf.java using the JDK's own public parsing interface, and assets/samples/crosscheck.py. The harness's limits are documented at the bottom of its own source rather than left to be discovered: it compares structure, framing, pool slots and member names, and does NOT compare attribute bodies, constant pool values, or access flag names
- [x] P1 2.1.49 JVM harness fault injection, including a fault it FAILED to catch: five faults tried, three caught immediately. A rename of field `arr` to `arx` passed the crosscheck — and that is correct behaviour, not a gap, because all three readers read the same patched file and all three correctly report the new name; a decoder is allowed to be right about a file that differs by one byte. The instructive one was a SILENT wrong answer: class_decode.py computed "which pool indices are unusable" in dump() and crosscheck.py computed it again in its own reader, so a fault injected into dump()'s copy passed completely, because the harness only exercised its own. Fixed by making it one function, pool_holes(), called by both; the same fault is now caught with a message naming all three readers
- [x] P1 2.1.50 JVM Module 1 findings: (1) The format is BIG-ENDIAN THROUGHOUT, the opposite of ELF, PE, COFF, Mach-O and x86, and the magic 0xCAFEBABE is the rule rather than an exception to it — a little-endian reader sees 0xBEBAFECA. The minor_version is NOT a sub-version: it is 0 for everything except preview features, where it is 0xFFFF, so a two-byte field that is almost always zero carries one bit of meaning. Compatibility is absolute and checked in six bytes, with no partial support. (2) Instruction branch offsets are RELATIVE TO THE BRANCH INSTRUCTION'S OWN OPCODE ADDRESS while exception table offsets are ABSOLUTE — both conventions coexist inside the same attribute of the same method, verified by diffing against javap -c, and the error from getting it wrong is a different amount at every branch because the error IS the instruction's own position. (3) The JDK's own API THROWS ConstantPoolException on a Long/Double hole rather than returning null or a wrong entry, and its ConstantPool.size() is the raw count while iterating yields only usable entries, so the two disagree and that disagreement is the two-slot rule seen from outside
- [x] P1 2.1.51 JVM Module 1 finding: CONSTANT_Utf8 IS NOT UTF-8, and both deviations were confirmed against javac output. A NUL is two bytes (61 c0 80 62) so that no string can contain the byte every C string tool treats as a terminator — and consequently "\u0000" is a compile error in Java source, because the unicode preprocessor runs before parsing and would inject a raw NUL into the token stream, so "\0" is the only way to write it. A supplementary character costs SIX bytes where real UTF-8 uses four (the emoji U+1F389 appears as ed a0 bc ed be 89) because the format stores the UTF-16 SURROGATE PAIR with each surrogate encoded separately — this is CESU-8, reusing the range 0xED 0xA0-0xBF that real UTF-8 reserves for high surrogates. The course's own decoder threw on these bytes until it was fixed, which is the strongest available demonstration that the deviation is real
- [x] P1 2.1.52 JVM Module 2 written: 4 concepts (fields/methods/descriptors, the Code attribute, two offset conventions, the verifier's data), 90 minutes, taking the course to 2 modules / 8 concepts / 168 minutes. New samples: Desc.class (one field of every type, the whole descriptor grammar), Slots.class (ten methods whose max_locals were predicted from the signature before being checked and all ten matched), Wide.class (300 live locals, max_locals 303, 96 wide prefixes), bringing the sample set to 24 files, all three readers agreeing
- [x] P1 2.1.53 JVM Module 2 findings: (1) TWO OFFSET CONVENTIONS COEXIST INSIDE ONE ATTRIBUTE and nothing marks which is which -- instruction branch offsets are RELATIVE to the branch's own opcode address while exception table offsets in the same Code attribute are ABSOLUTE, verified by diffing against javap -c. The tableswitch opcode sits at offset 1 and stores targets 35/37/39/41/43 with default 45; javap prints 36/38/40/42/44/46, each the stored value plus the opcode's own address of 1, landing exactly on the iconst_N/ireturn pairs. The failure is nasty because the error IS the instruction's position, so it is a different amount at every branch -- applying the relative rule to the exception table makes handler 1 report 20 instead of 10 and handler 3 report 54 instead of 27. (2) The `to` field of an exception table entry is EXCLUSIVE and rows are tried in order, so three rows covering [0,5) form a catch chain. (3) The wide prefix 0xC4 appears at exactly index 256, the first value a single byte cannot hold, verified on a 300-local class where the first prefixed instruction is `c4 36 01 00` = wide istore 256 immediately after an unprefixed istore 255. (4) max_locals is sized from the SIGNATURE, not the body -- Shapes.wide has twelve live locals and max_locals 2, while the generated 300-local class has 303, so the field is neither a tight bound nor a constant
- [x] P1 2.1.54 JVM finding: the same 64-bit rule appears in THREE places, now confirmed in all three -- two pool indices (Module 1), two local slots, and two stack slots plus a `TOP` verification type for the unusable half. Verified by predicting all ten of Slots.class's max_locals from the signature before reading them: d(J)V=3, e(JJ)V=5, f(D)V=3, g(IJD)V=6, s(IJD)V=5 static, h(String,int[],Object)=4. A verification script written for this course initially got the last one wrong by treating `[I` as two tokens, since the array's `[` is part of the type rather than a separate thing
- [x] P1 2.1.55 JVM finding: ONE NUMBER CONFIRMING TWO FINDINGS AT ONCE. The tableswitch method's StackMapTable is eight bytes -- six same_frames at offsets 36, 38, 40, 42, 44, 46 computed from `previous + frame_type + 1` -- and the switch's six destinations after the relative adjustment are also 36, 38, 40, 42, 44, 46. Two independent derivations agreeing to the byte, and the agreement is the proof: a relative branch misread as absolute would put the frames at 35/37/39/41/43/45, which are odd numbers landing mid-instruction. It came from the sample by accident, because the switch's only branches ARE its six destinations
- [x] P1 2.1.56 JVM hypothesis formed, tested and DISCARDED, kept because the story was plausible: the trycatch StackMapTable frame types 74/71/72 are 0x4A/0x47/0x48, which are the astore/astore_0/astore_1 opcodes, and the specification does say a same_locals_1_stack_item frame always follows an astore-family instruction whose stored value is the frame's stack item. It is wrong -- the instructions at offsets 10, 18 and 27 are astore_2, astore_2 and astore 4 (0x4D, 0x4D, 0x3A). The frame type is 64 plus an offset delta and nothing else; the astore family merely occupies the same 64-to-127 numeric range. Recorded as a worked example of a plausible story that survives a glance

- [x] P1 2.1.57 Object Files course COMPLETED: ninth course, all five modules, 18 concepts, 362 minutes. It is the only course in the collection that is explicitly CROSS-FORMAT rather than about one format -- ELF, COFF and Mach-O object files side by side, using the same 30-line C source compiled three ways as the teaching device. Depends on elf, coff and macho. Served via render_obj_concept() with the same empty-string fall-through contract as every other course, and pre-rendered to courses/obj/output/ for static mode. Prev/next chain verified against manifest order; all 18 concept routes and the landing return 200
- [x] P1 2.1.58 Object Files Module 3 shipped: obj-relocations (the 24/10/8-byte record in ELF/COFF/Mach-O, why ELF packs sym+type into one word and COFF does not, and why Mach-O's six bitfields are the only layout that can state the patch width), obj-addends (the REL/RELA split, measured side by side on the same source), and the concept chain reordered so the record comes before the type vocabulary
- [x] P1 2.1.59 Object Files Module 4 shipped: obj-comdat-group, obj-archives and obj-weak-undef. Module 3's four selection questions answered by three mechanisms in three different places in the file, and the fixed-point argument for archive resolution proved by a decisive experiment rather than asserted
- [x] P1 2.1.60 Object Files Module 5 shipped, satisfying the mission's from-scratch rule: obj-emit (a 936-byte ELF64 relocatable object written byte by byte with nothing but Python's struct, accepted by GNU ld and producing correct answers when linked and run), obj-arch-table (the x86-64 and AArch64 instruction forms a fixup must patch, including the AArch64 case where the field is a bit range rather than a byte range), and obj-verify (the three-tier oracle loop). This is the course the whole chain was leading to
- [x] P1 2.1.61 Object Files course landing page: content/src/obj_landing.ch, emitted as courses/obj/output/index.html, carrying the course's prerequisite, its verification method and the three corrections the verification produced
- [x] P1 2.1.62 "Relocations, PIC and PIE" course COMPLETE: 9 concepts in 4 modules, 195 minutes. Depends on obj and sym, and is scoped to what those two leave OPEN rather than repeating them -- obj-pic already taught absolute/relative/GOT-relative and the three-build diff, so this course asks the prior question the obj course could not answer: why there is a TYPE field at all. Module 1 (vocabulary) is built on the central finding, that the SAME source needs ONE relocation per datum on x86-64 and TWO on AArch64, checked programmatically: every ADR_PREL_PG_HI21 is followed exactly 4 bytes later by an ABS_LO12_NC, and the AArch64 TYPE encodes the access width (LDST64/LDST32/LDST8 for three widths where x86-64 has one PC32 for all three). The reason is reach -- x86-64's signed 32-bit displacement gives +/-2GB in one instruction, AArch64's ADRP gives +/-4GB, and the 12-bit low field is 2^12 because a page is 4KB. Three of the four tokens in R_X86_64_REX_GOTPCRELX are historical scar tissue: the GOT-operand encoding was originally the CALL opcode, so a REX prefix was added to disambiguate it, which is also why the GOT form is 7 bytes where the RIP-relative form is 6. Module 2 (PIE) measures the 3x3 codegen/link matrix and finds two incoherent cells, both of which link and both of which run: -fno-pie compiled with -pie linked (code says no, file says yes) and the reverse, the latter being the configuration that yields GLOB_DAT instead of COPY and so pays GOT indirection for a fixed-layout EXEC. ASLR is observed over six runs, not inferred from a flag, and the low 12 bits are IDENTICAL in every run (140) because ASLR randomises the base, not the address. The cost is exact: 9 instructions against 17 for eight additions (not 18 -- the scheduler folds one pair), 6 bytes against 10 per reference, and a 96-byte .got for 8 globals. Module 3 (failure) uses the linker diagnostic that names BOTH the relocation type and the fix: "relocation R_X86_64_32 against undefined symbol `ext_data' can not be used when making a shared object; recompile with -fPIC" -- the violation is arithmetic (an ET_DYN has no address to store), not policy, which is why it can be named and why no linker flag can rescue it. Module 4 satisfies the from-scratch rule: courses/reloc/assets/samples/apply_relocs.py is a complete relocation applier with no libelf, which reads a real object, places sections at a chosen base, applies every relocation and RAISES rather than truncating. Its --all-bases sweep finds the 4-byte overflow at exactly base 0x80000000 = 2^31, and the breaker is the ABSOLUTE relocation -- the PC-relative one keeps working at every base in the sweep, which is the direct demonstration of why a relative form exists. Serves 9 concept routes plus the landing, all 200, with 20 internal links resolved, prev/next chain and manifest minutes verified by tools/verify_reloc.py
- [x] P1 2.2.60 The TLS finding was measured once, wrongly, and the wrong version is RETRACTED rather than quietly corrected. The first claim was that `-ftls-model=local-dynamic` and `-ftls-model=initial-exec` "emit IDENTICAL relocation types". It is not true, and TWO independent mistakes pointed the same way: (1) the specimen's thread-locals were all `extern`, and local-dynamic REQUIRES the symbol to be in the same module, so the request was inapplicable and the compiler fell back; (2) the specimen was compiled at -O1, and `static __thread int my_tls = 7;` folded to the constant 7, deleting the only memory access and with it the only TLSLD relocation. The corrected measurement uses TWO specimens and -O0, and separates a monotone four-model ladder: -fPIC emits TLSGD+PLT32 for a cross-module symbol AND TLSLD+PLT32+DTPOFF32 for a module-local one, i.e. it chooses PER SYMBOL rather than per file; -fPIC+local-dynamic drops TLSGD and keeps one call; -fPIC+initial-exec is GOTTPOFF with no call; -fPIC+local-exec is TPOFF32 alone, no GOT and nothing to call. And -ftls-model=local-dynamic WITHOUT -fPIC is silently overridden -- the flag is a REQUEST and PIC-ness is a CONSTRAINT. The landing page and the tls-model concept both state the retraction, and the general lesson is taught explicitly: when two things measure as identical, the first hypothesis is that your optimiser deleted the difference, not that they really are the same
- [x] P1 2.1.63 "Static Linking and Linker Scripts" course COMPLETE: 10 concepts in 4 modules, 221 minutes. Depends on obj, sym and reloc, and is scoped to the one layer none of those three mentioned: the 276-line PROGRAM that places every binary, which ld ships as source and prints on request with `ld --verbose`. Module 1 is the script and its grammar. The headline measurement is a ROUND TRIP -- save the script, feed it back, compare FILES -- and the honest result is narrower than the obvious one: byte-identical ONLY when the command-line flags and the script agree about the code model, because on this PIE-by-default toolchain ld's own default emits ET_DYN while the saved script emits ET_EXEC, differing at byte 16. Rule order is first-match-wins, proven in FOUR CELLS (keep-only, discard-only, keep-first, discard-first -> 1,0,1,0), with the finding that the `.text` rule's six patterns are a deliberate hot/cold partition: with `-ffunction-sections` the object order is cold,hot,main and the linked order is hot,cold,main, because `.text.hot` is matched by an earlier rule while `.text.cold` and `.text.main` share the catch-all and keep OBJECT order. Module 2 is placement. `SEGMENT_START("text-segment", 0xDEADBEEF)` returns 0xDEADBEEF verbatim in all three code models, so on x86-64 Linux the emulation has NO opinion and the second argument IS the answer -- proven inert by putting `CONSTANT(MAXPAGESIZE)` in the same probe and getting a real 0x1000 back. `SIZEOF_HEADERS` measures 0x350, the gap between "where the image is" and "where your code is". One number moved: replacing the 0x400000 literal moves the whole binary to 0x800000 and 0x10000000, and it RUNS at both, so the script is what the CPU jumps to. MEMORY overflow is a real diagnostic ("region `rom' overflowed by 24 bytes"), and PHDRS writes program headers by hand with FLAGS(5) being the literal PF_R|PF_X bits. The most surprising property found in the whole collection: `-T` SUPPRESSES PIE. `-fPIE -pie -T default.ld` and `-fPIE -T default.ld -pie` both emit ET_EXEC at 0x400000; command-line order is irrelevant. Module 3 is selection. `--gc-sections` is REACHABILITY, and the A/B that proves it is the same source at two optimisation levels: at -O1 the collector removes `used` and at -O0 it KEEPS it, because -O1 folded `used(41)` to the constant 42 (visible as `mov $0x2a,%esi`) and the out-of-line copy lost its last caller. Moving the root with `-Wl,-e,used` inverts the survivor set and deletes main. `KEEP (*(.init_array))` is the only reason a constructor nobody calls survives. And with `--orphan-handling=warn` the DEFAULT script turns out to orphan FIVE sections in a trivial hello-world, four from the C runtime, so the shipped script is not complete and does not claim to be. Module 4 is static and the build. `-static` is 52x (15880 -> 825160), removes PT_INTERP, and the first PT_LOAD moves to 0x400000 -- the SCRIPT's number, because -static changed e_type and the script followed. Both builds keep four PT_LOADs, and line 1 of the script says why: `/* Script for -z combreloc -z separate-code */`. Serves 10 concept routes plus the landing, all 200, with 29 internal links resolved across five courses, prev/next chain and manifest minutes verified by tools/verify_link.py; all 12 course landings still 200
- [x] P1 2.2.62 TWO CLAIMS RETRACTED from the linker-script course rather than quietly corrected, and both retractions are on the course's own landing page. (1) "The round trip is byte-identical" -- the first measurement compared SIZES, found them all equal at 15912, and concluded the saved script reproduces ld's output; comparing bytes showed the two PIE builds differ at offset 16, which is e_type. The honest claim is that the round trip is byte-identical exactly when the flags and the script agree about the code model. (2) "/DISCARD/ beats rule order" -- flatly wrong, and the experiment was broken rather than the model: two chained Python `str.replace()` calls, and in the file that produced the wrong answer the FIRST had not applied, so the cell named "keep rule first, discard second" contained no keep rule at all. `str.replace()` returns the text UNCHANGED when the pattern is absent and reports nothing, so a no-op edit is indistinguishable from a linker obeying you. The corrected four-cell experiment gives 1,0,1,0 -- plain first-match-wins, /DISCARD/ not special. The general lesson is now taught in link-order and asserted in the build script: when an experiment about a build tool surprises you, the first hypothesis is that your edit did not apply. A THIRD claim was corrected mid-course: the `MEMORY` region attributes do NOT drive the program-header flags. Measured, `.text` in a (w) region and in an (rx) region produce IDENTICAL `R E` segments with no diagnostic either way; the flags came from the section. The concept shows the measurement and the correction side by side
- [x] P1 2.2.63 `courses/link/assets/samples/linklab.py` -- the course's buildable artifact, shaped around the three things the course established rather than around convenience: a script is a program you can edit (so get the source first and edit a copy), its effect is checkable rather than assumed (every subcommand verifies its own result and prints PASS/FAIL), and the linker will not tell you your edit did nothing (so verify the edit, and report the replacement count, before linking). Five subcommands and 20 checks. Two of its own bugs are recorded because they are instructive rather than embarrassing: it initially asserted the FIRST PT_LOAD was executable, which is wrong -- the first load is the read-only ELF headers -- and it handed a .c file straight to ld, which made ld treat it as a linker script. It also learned the -O1-constant-fold lesson from the TLS retraction: the gc specimen needed a real `main` or the link silently failed and the subcommand printed nothing. `build_samples.sh` and `crosscheck.py` now assert 124 claims, all passing and reproducible from an empty directory, and two of those assertions exist only to catch the class of bug in retraction 2
- [x] P1 2.1.64 "Dynamic Linking and Shared Libraries" course COMPLETE: 10 concepts in 4 modules, 224 minutes. Depends on obj, sym, reloc and link, and is scoped to the one mechanism none of those four covered: the SCOPE -- the ordered list every undefined symbol is answered from. `elf-ld-so` had taught the load sequence and the search PATHS ("where do I look for libfoo.so"); this course teaches the other half ("I found four files, which one wins"), and the second question is where all the behaviour lives. The instrument is unusual and load-bearing: `LD_DEBUG=bindings` makes glibc's loader print every binding it makes and `LD_DEBUG=libs` every library it searches for, in order, so every claim about loader behaviour is a measurement rather than a paraphrase of documentation. Module 1 (the scope) is the centrepiece. INTERPOSITION reaches INSIDE the library: the same program with one definition added to the executable changes `mid_value()` from 11 to 110, because libb.so's OWN call to lib_value was bound to the executable's definition, confirmed by the loader naming `./prog2` as the source. The scope is built BREADTH-FIRST from DT_NEEDED -- libdeep.so loads SECOND rather than fourth, proved from the loader's own find-library order and reproduced independently by the artifact. Module 2 (building) covers what a .so actually is: one exported symbol out of two functions written, no DT_SONAME because nothing set one, and DT_NEEDED recording FILE names as a direct consequence. `-fvisibility=hidden` exports NOTHING and breaks every caller, as does a version script with `local: *`; both are correct and both fail at link time with a message that does not mention the flag. `-Bsymbolic` is ONE instruction (`callq <helper@plt>` versus `callq <helper>`) and .dynsym is IDENTICAL either way, so it is a binding change and not an export change -- and it does NOT affect cross-library references, which is the precise thing its name hides (the first attempt at this measurement used a cross-library call and the flag changed nothing at all). Module 3 (run time) establishes the only observable difference between RTLD_LOCAL and RTLD_GLOBAL (`dlsym(RTLD_DEFAULT)` finds nothing versus finds it), that `dlopen` on an already-loaded library returns the SAME handle and is a reference count, and that `RTLD_LAZY` SUCCEEDS on a library that can never work while `RTLD_NOW` fails naming the symbol. It also REFINES the symbol-resolution course's finding that `-z now` changes no code: the .plt IS byte-identical, but .got.plt DISAPPEARS and .got grows 0x28 -> 0x48, because a slot with one state does not need its own section. Module 4 is the build: dynscope.py rebuilds the scope from the files and resolves symbols with no loader, then cross-checks every answer against LD_DEBUG, so it is tested against the implementation it models. Serves 10 concept routes plus the landing, all 200, with 34 internal links resolved across six courses, prev/next chain and manifest minutes verified by tools/verify_dyn.py; all 13 course landings still 200
- [x] P1 2.2.62 A CLAIM RETRACTED from the dynamic-linking course, and the retraction is on the course's own landing page and in two of the crosscheck's assertions. The first draft of the breadth-first concept said `--as-needed` dropped liba.so from the second build's DT_NEEDED, and told a tidier story about link order than the truth. It did not: liba.so is in BOTH lists. The real mechanism is the direct one and is a better lesson precisely because nothing is hidden -- DT_NEEDED order follows the link line order, and the shim library precedes liba.so in both builds, by THREE POSITIONS in one and by ONE in the other, so moving -la up one place changes which definition wins with identical source and identical flags. The corrected claim is asserted in build_samples.sh, in crosscheck.py (under an explicit RETRACTION comment), and taught in the concept
- [x] P1 2.2.63 Four bugs in `courses/dyn/assets/samples/dynscope.py`, recorded because each is a way of being confidently wrong rather than a typo, and two of them are the class of bug the course teaches about. (1) e_shstrndx was read by unpacking FIVE half-words at offset 58 and assigning the last three; only three header fields live there, so the other two reads ran past the end of the ELF header into the first section header, and every string-table lookup then failed with "subsection not found". (2) Deduplication compared a DT_NEEDED NAME against a list of PATHS, so "liba.so" never matched and libc.so.6 entered the scope four times. (3) resolve_path used an absolute candidate AS the path instead of joining the name to it, so $ORIGIN resolved to a directory and the scope contained directories. (4) THE FIRST VERSION WAS A RECURSIVE DESCENT, producing DEPTH-FIRST order -- which is the exact error the third concept spends twenty minutes warning about, so an artifact demonstrating the mistake is worse than no artifact. Also recorded: the static-TLS surplus threshold was NOT measured, because the attempt (32 dlopen-able libraries each with 256 bytes of __thread state) failed to LINK -- --as-needed dropped every one of them with nothing referencing them. A measurement that requires the thing under test to be present has a failure mode that looks exactly like success, so the number is left unclaimed and the exercise handed to the reader with the failure written down
- [x] P1 2.2.61 `courses/reloc/assets/samples/apply_relocs.py` -- the course's buildable artifact, and the checks that keep it honest. Three bugs found and fixed while writing it, each of which is a trap rather than a typo: the relocation table was keyed by NAME while the file stores a NUMBER (so R_X86_64_32S, type 11, was "unknown"), the overflow message hardcoded "PC32" and so misreported the ABSOLUTE relocation that actually breaks, and the --all-bases sweep used a growing step whose cap put it at ~10MB -- nowhere near the 2GB boundary it claimed to be finding. Verified: PLT32 at field 0x14 yields -0x18, and the bytes `e8 e8 ff ff ff` call -0x18 from 0x18 and land exactly on `pick` at 0x00. The specimen needs `volatile` (or -O1 collapses the file to one constant load from .rodata.cst16) and `noinline` (or `pick` is inlined and the only PC-relative relocation disappears), which is the same -O1-deletes-the-evidence trap as 2.2.60. crosscheck.py now asserts 87 claims, all passing and reproducible from an empty directory
### 2.3 Asset Management

- [ ] P3 2.3.1 Static file serving from courses/name/assets/
- [ ] P3 2.3.2 Asset versioning (cache-busting with hash)
- [ ] P3 2.3.3 Image optimization (resize, compress, format conversion)
- [ ] P3 2.3.4 Asset CDN support (external CDN URLs)
- [ ] P3 2.3.5 Asset lazy loading (load on scroll)
- [ ] P3 2.3.6 Asset placeholder generation (blurhash, skeleton)
- [ ] P3 2.3.7 Asset accessibility (alt text, captions, transcripts)
- [ ] P3 2.3.8 Asset licensing tracking (license metadata per asset)
- [ ] P3 2.3.9 Asset dependency graph (which concepts use which assets)
- [ ] P3 2.3.10 Asset usage analytics (download count, view count)
- [ ] P3 2.3.11 Asset upload interface (drag-and-drop)
- [ ] P3 2.3.12 Asset organization (folders, tags)
- [ ] P3 2.3.13 Asset search (by name, type, tag)
- [ ] P3 2.3.14 Asset preview (inline preview before insert)
- [ ] P3 2.3.15 Asset size limits (per file, per course)
- [ ] P3 2.3.16 Asset format validation (allowed extensions)
- [ ] P3 2.3.17 Asset deduplication (detect identical files)
- [ ] P3 2.3.18 Asset cleanup (remove unused assets)
- [ ] P3 2.3.19 Asset backup (version control for assets)
- [ ] P3 2.3.20 Asset migration (move between courses)

### 2.4 Review Item Generation

- [ ] P3 2.4.1 Auto-generate review items from concept content
- [x] P1 2.4.21 Review item seeding: create per-concept review items on first learner activity (insert_review_item/update_review_item are never called anywhere — the review queue is permanently empty, so /api/review/due always returns [] and FSRS scheduling never engages)
- [ ] P2 2.4.22 Seed review_item_decls from course manifest (decls field exists but is empty and unread by the seed handler)
- [ ] P3 2.4.2 Review item templates: free recall
- [ ] P3 2.4.3 Review item templates: cued recall
- [ ] P3 2.4.4 Review item templates: recognition (multiple choice)
- [ ] P3 2.4.5 Review item templates: application (use the knowledge)
- [ ] P3 2.4.6 Review item templates: explanation (teach it back)
- [ ] P3 2.4.7 Review item templates: connection (relate to other concepts)
- [ ] P3 2.4.8 Review item difficulty calibration (initial difficulty estimation)
- [ ] P3 2.4.9 Review item quality scoring (clarity, accuracy, difficulty)
- [ ] P3 2.4.10 Review item diversity checking (avoid redundancy)
- [ ] P3 2.4.11 Review item verification (correctness check)
- [ ] P3 2.4.12 Review item update on concept change (regenerate affected items)
- [ ] P3 2.4.13 Review item archival (remove from active pool)
- [ ] P3 2.4.14 Review item import (from Anki, CSV, JSON)
- [ ] P3 2.4.15 Review item export (to Anki, CSV, JSON)
- [ ] P3 2.4.16 Review item analytics (accuracy, time, difficulty)
- [ ] P3 2.4.17 Review item A/B testing (compare item variants)
- [ ] P3 2.4.18 Review item explanation (show explanation after answer)
- [ ] P3 2.4.19 Review item hints (progressive hint system)
- [ ] P3 2.4.20 Review item media (images, code blocks, diagrams)

### 2.5 Course Testing

- [ ] P3 2.5.1 Concept rendering test (renders without error)
- [ ] P3 2.5.2 Concept rendering snapshot (visual regression)
- [ ] P3 2.5.3 Exercise correctness test (answers are correct)
- [ ] P3 2.5.4 Exercise solvability test (exercises can be solved)
- [ ] P3 2.5.5 Review item correctness test (items are accurate)
- [ ] P3 2.5.6 Asset availability test (all referenced assets exist)
- [ ] P3 2.5.7 Link validity test (all links resolve)
- [ ] P3 2.5.8 Accessibility test (WCAG 2.1 AA compliance)
- [ ] P3 2.5.9 Performance test (render time < 2 seconds)
- [ ] P3 2.5.10 Mobile responsiveness test (works on 320px-1920px)
- [ ] P3 2.5.11 Cross-browser test (Chrome, Firefox, Safari, Edge)
- [ ] P3 2.5.12 Course completeness test (all required sections present)
- [ ] P3 2.5.13 Prerequisite test (prerequisites exist and are valid)
- [ ] P3 2.5.14 Manifest test (manifest.json is valid)
- [ ] P3 2.5.15 Integration test (course loads end-to-end)
- [ ] P3 2.5.16 Offline test (course works without internet)
- [ ] P3 2.5.17 Print test (course prints correctly)
- [ ] P3 2.5.18 Course test runner (run all tests for a course)
- [ ] P3 2.5.19 Course test report (HTML report of test results)

---

## 3. Course Content & Visualizations

### 3.1 Interactive Visualizations

- [ ] P3 3.1.1 Hex viewer: display binary data in hex + ASCII
- [ ] P3 3.1.2 Hex viewer: click bytes to highlight fields
- [ ] P3 3.1.3 Hex viewer: show decoded values (integers, strings, offsets)
- [ ] P3 3.1.4 Hex viewer: navigate to offset (search, jump)
- [ ] P3 3.1.5 Hex viewer: highlight ELF header fields
- [ ] P3 3.1.6 Hex viewer: highlight program headers
- [ ] P3 3.1.7 Hex viewer: highlight section headers
- [ ] P3 3.1.8 Hex viewer: highlight symbol table entries
- [ ] P3 3.1.9 Hex viewer: highlight relocation entries
- [ ] P3 3.1.10 Hex viewer: highlight dynamic entries
- [ ] P3 3.1.11 Hex viewer: compare two hex dumps side-by-side
- [ ] P3 3.1.12 Hex viewer: export selection as hex string
- [ ] P3 3.1.13 Hex viewer: copy bytes to clipboard
- [ ] P3 3.1.14 Hex viewer: highlight custom ranges
- [ ] P3 3.1.15 Hex viewer: show byte statistics (entropy, distribution)
- [ ] P3 3.1.16 ELF layout diagram: visual representation of file structure
- [ ] P3 3.1.17 ELF layout diagram: click sections to see details
- [ ] P3 3.1.18 ELF layout diagram: drag to rearrange (for learning)
- [ ] P3 3.1.19 ELF layout diagram: show file offsets and sizes
- [ ] P3 3.1.20 ELF layout diagram: show relationships between sections
- [ ] P3 3.1.21 Memory mapping: show segments in virtual memory
- [ ] P3 3.1.22 Memory mapping: show page permissions (R/W/X)
- [ ] P3 3.1.23 Memory mapping: show physical vs virtual addresses
- [ ] P3 3.1.24 Memory mapping: animate loading process
- [ ] P3 3.1.25 State machine: TLS handshake states
- [ ] P3 3.1.26 State machine: click transitions to see messages
- [ ] P3 3.1.27 State machine: step forward/backward
- [ ] P3 3.1.28 State machine: animate transitions
- [ ] P3 3.1.29 Timeline: compilation stages
- [ ] P3 3.1.30 Timeline: scroll through stages
- [ ] P3 3.1.31 Timeline: click for details
- [ ] P3 3.1.32 Timeline: show dependencies between stages
- [ ] P3 3.1.33 Tree: symbol table hierarchy
- [ ] P3 3.1.34 Tree: expand/collapse nodes
- [ ] P3 3.1.35 Tree: search nodes
- [ ] P3 3.1.36 Tree: highlight dependencies
- [ ] P3 3.1.37 Code viewer: show source code
- [ ] P3 3.1.38 Code viewer: show assembly alongside
- [ ] P3 3.1.39 Code viewer: highlight correspondence between lines
- [ ] P3 3.1.40 Code viewer: syntax highlighting
- [ ] P3 3.1.41 Code viewer: copy code to clipboard
- [ ] P3 3.1.42 Code viewer: diff view (before/after optimization)
- [ ] P3 3.1.43 Network packet visualization: show packet structure
- [ ] P3 3.1.44 Network packet visualization: click fields to decode
- [ ] P3 3.1.45 Network packet visualization: show packet sequence

### 3.2 Code Examples

- [ ] P3 3.2.1 Syntax-highlighted code blocks
- [ ] P3 3.2.2 Line-by-line code explanation
- [ ] P3 3.2.3 Code execution playground (run in browser)
- [ ] P3 3.2.4 Code comparison (before/after)
- [ ] P3 3.2.5 Code diff visualization (side-by-side)
- [ ] P3 3.2.6 Code annotation (comments on specific lines)
- [ ] P3 3.2.7 Code quiz (fill in the blank)
- [ ] P3 3.2.8 Code debugging exercises (find the bug)
- [ ] P3 3.2.9 Code refactoring exercises (improve the code)
- [ ] P3 3.2.10 Code optimization exercises (make it faster)
- [ ] P3 3.2.11 Code output prediction (what does this print?)
- [ ] P3 3.2.12 Code memory visualization (show stack/heap)
- [ ] P3 3.2.13 Code step-through (debugger-style)
- [ ] P3 3.2.14 Code explanation (AI explains what code does)
- [ ] P3 3.2.15 Code quiz with hints (progressive reveal)

### 3.3 Interactive Exercises

- [ ] P3 3.3.1 Drag-and-drop ordering (arrange steps in order)
- [ ] P3 3.3.2 Click-to-select diagrams (identify parts)
- [ ] P3 3.3.3 Fill-in-the-blank code (complete the code)
- [ ] P3 3.3.4 Multiple choice with images (visual questions)
- [ ] P3 3.3.5 True/false with explanation
- [ ] P3 3.3.6 Matching exercises (match terms to definitions)
- [ ] P3 3.3.7 Sorting exercises (sort by value, size, date)
- [ ] P3 3.3.8 Drawing/diagramming exercises (label a diagram)
- [ ] P3 3.3.9 Simulation exercises (interact with a system)
- [ ] P3 3.3.10 Debugging exercises (find and fix bugs)
- [ ] P3 3.3.11 Binary analysis exercises (parse a binary)
- [ ] P3 3.3.12 Hex editing exercises (modify bytes)
- [ ] P3 3.3.13 Code completion exercises (write the missing code)
- [ ] P3 3.3.14 Process ordering exercises (arrange steps)
- [ ] P3 3.3.15 Concept mapping exercises (connect concepts)

### 3.4 Rich Content

- [ ] P3 3.4.1 Animated diagrams (CSS/JS animations)
- [ ] P3 3.4.2 Interactive timelines (scroll, click)
- [ ] P3 3.4.3 Zoomable images (pan, zoom)
- [ ] P3 3.4.4 Audio explanations (narrated lessons)
- [ ] P3 3.4.5 Video embeds (YouTube, Vimeo)
- [ ] P3 3.4.6 PDF viewer (embedded PDFs)
- [ ] P3 3.4.7 Data table with sorting/filtering
- [ ] P3 3.4.8 Formula rendering (KaTeX)
- [ ] P3 3.4.9 ASCII art diagrams
- [ ] P3 3.4.10 Mermaid diagrams
- [ ] P3 3.4.11 Interactive quizzes inline
- [ ] P3 3.4.12 Callout boxes (info, warning, tip, danger)
- [ ] P3 3.4.13 Tabs (switch between content views)
- [ ] P3 3.4.14 Accordions (expandable sections)
- [ ] P3 3.4.15 Footnotes and citations

### 3.5 Course Assessments

- [x] P2 3.5.1 HAT baseline diagnostic: full 100-question mock embedded in the hat-diagnostic-test lesson (40 quantitative, 30 verbal, 30 analytical)
- [x] P2 3.5.2 Diagnostic runner: 120-minute countdown, question palette, in-progress resume, auto-submit at time-up
- [x] P2 3.5.3 Diagnostic scoring: sectional correct/wrong/blank breakdown, /100 total, qualifying-line interpretation, next-step links
- [x] P2 3.5.4 Diagnostic score persistence in localStorage (works in static and backend modes)

---

## 4. Exercise System

### 4.1 Exercise Types

- [x] P1 4.1.1 Multiple choice: 4 options, 1 correct
- [x] P1 4.1.2 Multiple choice: N options, 1 correct
- [x] P1 4.1.3 Multiple choice: N options, M correct (multi-select)
- [x] P1 4.1.4 Free recall: text input, no hints
- [x] P1 4.1.5 Cued recall: text input with partial hint
- [x] P2 4.1.6 Recognition: select the correct image/diagram
- [x] P2 4.1.7 Application: solve a problem using the knowledge
- [x] P2 4.1.8 Fill in the blank: complete a sentence
- [x] P2 4.1.9 Fill in the blank: complete a code block
- [x] P2 4.1.10 True/false: with explanation
- [x] P2 4.1.11 True/false: with "why" explanation
- [x] P2 4.1.12 Matching: match terms to definitions
- [x] P2 4.1.13 Matching: match code to output
- [x] P2 4.1.14 Ordering: arrange steps in correct order
- [x] P2 4.1.15 Sorting: sort items by property
- [ ] P3 4.1.16 Code completion: write missing code
- [ ] P3 4.1.17 Code debugging: find the bug
- [ ] P3 4.1.18 Code debugging: fix the bug
- [ ] P3 4.1.19 Hex editing: modify specific bytes
- [ ] P3 4.1.20 Binary analysis: parse a binary file
- [ ] P3 4.1.21 Diagram labeling: label parts of a diagram
- [ ] P3 4.1.22 Process ordering: arrange process steps
- [ ] P3 4.1.23 Concept mapping: connect related concepts
- [ ] P3 4.1.24 Open-ended: explain a concept in your own words
- [ ] P3 4.1.25 Project: build something using the knowledge
- [x] P1 4.1.26 Lesson pages render exercises from GET /api/exercises/:conceptId (no page currently consumes the exercise API — wiring gap)
- [x] P1 4.1.27 Exercise seeding at startup or on first lesson request (DB starts empty; /api/exercises/seed exists but is manual-only)
- [x] P1 4.1.28 Exercise submit updates concept_states and creates/updates review_items via FSRS (currently grades only — results never reach the learning loop)
- [x] P1 4.1.29 Exercise UI on lesson pages supports all 8 exercise types (multiple choice, multi-select, fill-blank, hex-inspect, ordering, matching, labeling, predict)
- [ ] P2 4.1.30 Progressive hints UI wired to GET /api/exercises/hint (API exists, no frontend consumer)

### 4.2 Exercise Feedback

- [x] P1 4.2.1 Immediate correctness feedback (correct/incorrect)
- [x] P1 4.2.2 "Explain why wrong" feedback on every incorrect answer
- [x] P1 4.2.3 "Explain why correct" feedback on every correct answer
- [x] P1 4.2.4 Hint system: 3 progressive hints per exercise
- [x] P1 4.2.5 Hint 1: conceptual hint (what to think about)
- [x] P2 4.2.6 Hint 2: directional hint (where to look)
- [x] P2 4.2.7 Hint 3: almost answer (nearly correct)
- [x] P2 4.2.8 Solution reveal after 3 failed attempts
- [x] P2 4.2.9 Related concept suggestions after incorrect answer
- [x] P2 4.2.10 Difficulty indicator (easy, medium, hard)
- [x] P2 4.2.11 Time spent indicator (how long you took)
- [x] P2 4.2.12 Accuracy trend indicator (are you improving?)
- [x] P2 4.2.13 Streak indicator (consecutive correct)
- [x] P2 4.2.14 Encouragement messages (context-aware)
- [x] P2 4.2.15 "This is supposed to be hard" message for difficult exercises
- [x] P2 4.2.16 Mistake pattern detection (common errors)
- [x] P2 4.2.17 Personalized feedback based on mistake pattern
- [x] P2 4.2.18 Feedback quality rating (was this helpful?)
- [ ] P2 4.2.19 Real exercise streak counter in submit response (currently hardcoded 0 in JSON)

### 4.3 Exercise Generation

- [ ] P3 4.3.1 Template-based generation from exercise templates
- [ ] P3 4.3.2 Variation generation (same concept, different values)
- [ ] P3 4.3.3 Difficulty scaling (easy to medium to hard)
- [ ] P3 4.3.4 Randomized answers (shuffle options)
- [ ] P3 4.3.5 Dynamic code exercises (generate code with random values)
- [ ] P3 4.3.6 Real data exercises (use actual ELF files)
- [ ] P3 4.3.7 Contextual exercises (based on learner history)
- [ ] P3 4.3.8 Adaptive exercises (based on performance)
- [ ] P3 4.3.9 Community-contributed exercises (user submissions)
- [ ] P3 4.3.10 Exercise quality scoring (automated quality check)
- [ ] P3 4.3.11 Exercise difficulty estimation (from learner performance)
- [ ] P3 4.3.12 Exercise popularity tracking (usage count)
- [ ] P3 4.3.13 Exercise improvement suggestions
- [ ] P3 4.3.14 Exercise retirement (too easy/hard/outdated)
- [ ] P3 4.3.15 Exercise A/B testing (compare variants)
- [ ] P3 4.3.16 Exercise explanation generation (AI-generated)
- [ ] P3 4.3.17 Exercise hint generation (AI-generated)
- [ ] P3 4.3.18 Exercise distractor generation (wrong answer generation)
- [ ] P3 4.3.19 Exercise validation (correctness, solvability, clarity)

### 4.4 Exercise Analytics

- [ ] P3 4.4.1 Per-exercise accuracy tracking
- [ ] P3 4.4.2 Per-exercise time tracking
- [ ] P3 4.4.3 Per-exercise attempt tracking
- [ ] P3 4.4.4 Per-exercise hint usage tracking
- [ ] P3 4.4.5 Per-exercise difficulty estimation (from learner data)
- [ ] P3 4.4.6 Per-exercise quality estimation (from learner feedback)
- [ ] P3 4.4.7 Per-exercise popularity tracking
- [ ] P3 4.4.8 Per-exercise improvement suggestions
- [ ] P3 4.4.9 Per-exercise retirement recommendations
- [ ] P3 4.4.10 Per-exercise A/B test results
- [ ] P3 4.4.11 Per-exercise explanation ranking
- [ ] P3 4.4.12 Per-exercise distractor analysis (which wrong answers are chosen)
- [ ] P3 4.4.13 Per-exercise time analysis (which take too long)
- [ ] P3 4.4.14 Per-exercise skip analysis (which are skipped most)
- [ ] P3 4.4.15 Per-exercise satisfaction rating

---

## 5. Review & Spaced Repetition

### 5.1 Review Session Types

- [x] P1 5.1.1 New concept learning: introduce new material
- [x] P1 5.1.2 Due item review: review items past their due date
- [x] P1 5.1.3 Cramming mode: review everything (for exams)
- [x] P1 5.1.4 Targeted review: review specific concepts
- [x] P1 5.1.5 Weakness repair review: focus on weak concepts
- [x] P2 5.1.6 Cumulative review: mix of all types
- [x] P2 5.1.7 Speed review: timed reviews (3 seconds per item)
- [x] P2 5.1.8 Deep review: with explanations and context
- [x] P2 5.1.9 Mixed mode: learn new + review old
- [x] P2 5.1.10 Custom review: user-selected items
- [ ] P3 5.1.11 Prerequisite review: review prerequisites before target
- [ ] P3 5.1.12 Cross-module review: mix concepts from different modules
- [ ] P3 5.1.13 Spaced repetition only: only FSRS-scheduled items
- [ ] P3 5.1.14 Manual review: no FSRS, just review on demand
- [ ] P3 5.1.15 Exam preparation: focus on high-yield items
- [x] P1 5.1.16 Review page mode selection fetches POST-style /api/review/start JSON and renders the session in-page (currently `startMode()` navigates the browser to the raw JSON endpoint — broken flow)
- [x] P1 5.1.17 Review page calls POST /api/review/end on session completion (sessions currently stay "active" forever)
- [x] P1 5.1.18 Review session controls UI: pause/resume/abort/undo/skip buttons wired to /api/session/* (APIs exist, zero frontend consumers)
- [ ] P1 5.1.19 Review submit/start resolve learner via bearer token only — remove "demo" learner_id fallback that lets anonymous ratings pollute data
- [ ] P2 5.1.20 Review recommendations surfaced in UI: /api/review/recommendations and /api/review/time-recommendation have no frontend consumer

### 5.2 Review Item Types

- [ ] P3 5.2.1 Recall: free recall (no hints)
- [ ] P3 5.2.2 Recall: cued recall (partial hint)
- [ ] P3 5.2.3 Recognition: multiple choice
- [ ] P3 5.2.4 Recognition: true/false
- [ ] P3 5.2.5 Application: solve a problem
- [ ] P3 5.2.6 Application: write code
- [ ] P3 5.2.7 Explain: teach it back
- [ ] P3 5.2.8 Connect: relate to other concepts
- [ ] P3 5.2.9 Debug: find errors
- [ ] P3 5.2.10 Construct: build something
- [ ] P3 5.2.11 Analyze: break down
- [ ] P3 5.2.12 Evaluate: judge quality
- [ ] P3 5.2.13 Create: novel application
- [ ] P3 5.2.14 Visual: identify diagram parts
- [ ] P3 5.2.15 Audio: listen and recall

### 5.3 Review Scheduling

- [ ] P3 5.3.1 Daily review queue (auto-generated from FSRS)
- [ ] P3 5.3.2 Weekly review planning (plan the week ahead)
- [ ] P3 5.3.3 Monthly review summary (what was reviewed)
- [ ] P3 5.3.4 Review scheduling preferences (morning/evening/flexible)
- [ ] P3 5.3.5 Review time optimization (schedule at optimal times)
- [ ] P3 5.3.6 Review load balancing (spread reviews evenly)
- [ ] P3 5.3.7 Review deadline support (review before a date)
- [ ] P3 5.3.8 Review reminder notifications (email, push)
- [ ] P3 5.3.9 Review streak tracking (consecutive days reviewed)
- [ ] P3 5.3.10 Review calendar integration (Google Calendar, iCal)
- [ ] P3 5.3.11 Review scheduling API (external scheduling)
- [ ] P3 5.3.12 Review scheduling conflict detection
- [ ] P3 5.3.13 Review scheduling optimization (minimize total time)
- [ ] P3 5.3.14 Review scheduling flexibility (reschedule reviews)
- [ ] P3 5.3.15 Review scheduling analytics (scheduling patterns)

### 5.4 Review Analytics

- [ ] P3 5.4.1 Review accuracy trends (over time)
- [ ] P3 5.4.2 Review speed trends (over time)
- [ ] P3 5.4.3 Review consistency tracking (streaks)
- [ ] P3 5.4.4 Review forecast (upcoming reviews)
- [ ] P3 5.4.5 Review history visualization (calendar, chart)
- [ ] P3 5.4.6 Review performance comparison (vs average)
- [ ] P3 5.4.7 Review efficiency scoring (accuracy / time)
- [ ] P3 5.4.8 Review retention measurement (actual retention rate)
- [ ] P3 5.4.9 Review load analysis (reviews per day/week/month)
- [ ] P3 5.4.10 Review optimization suggestions
- [ ] P3 5.4.11 Review time distribution (when do you review)
- [ ] P3 5.4.12 Review difficulty distribution (easy/hard ratio)
- [ ] P3 5.4.13 Review type distribution (recall/recognize/apply)
- [ ] P3 5.4.14 Review module distribution (which modules reviewed most)
- [ ] P3 5.4.15 Review gap analysis (long gaps between reviews)

---

## 6. Progress & Analytics

### 6.1 Learner Progress

- [x] P1 6.1.1 Concept state tracking (new, learning, reviewing, mastered)
- [x] P1 6.1.2 Knowledge health computation (overall and per module)
- [x] P1 6.1.3 Progress visualization (charts, graphs)
- [x] P1 6.1.4 Progress milestones (25%, 50%, 75%, 100%)
- [x] P1 6.1.5 Progress goals (set target completion date)
- [x] P2 6.1.6 Progress sharing (public profile)
- [x] P2 6.1.7 Progress export (JSON, CSV)
- [x] P2 6.1.8 Progress import (from another account)
- [x] P2 6.1.9 Progress comparison (anonymous, vs average)
- [x] P2 6.1.10 Progress prediction (estimated completion date)
- [ ] P3 6.1.11 Progress history (all changes over time)
- [ ] P3 6.1.12 Progress reset (start over for a course)
- [ ] P3 6.1.13 Progress pause (temporarily stop tracking)
- [ ] P3 6.1.14 Progress resume (continue after pause)
- [ ] P3 6.1.15 Progress breakdown (by module, by concept type)
- [ ] P3 6.1.16 Progress timeline (visual timeline of learning)
- [ ] P3 6.1.17 Progress heatmap (activity by day)
- [ ] P3 6.1.18 Progress streaks (consecutive days)
- [ ] P3 6.1.19 Progress achievements (badges earned)
- [ ] P3 6.1.20 Progress API endpoint

### 6.2 Learning Analytics

- [x] P2 6.2.1 Session analytics (length, accuracy, time)
- [x] P2 6.2.2 Concept analytics (mastery, time, attempts)
- [x] P2 6.2.3 Course analytics (completion, velocity)
- [x] P2 6.2.4 Platform analytics (engagement, retention)
- [x] P2 6.2.5 Cohort analytics (group comparison)
- [x] P2 6.2.6 Temporal analytics (time-of-day, day-of-week)
- [x] P2 6.2.7 Device analytics (mobile vs desktop)
- [x] P2 6.2.8 Difficulty analytics (easy/hard distribution)
- [x] P2 6.2.9 Error analytics (common mistakes)
- [x] P2 6.2.10 Drop-off analytics (where learners quit)
- [x] P2 6.2.11 Funnel analytics (registration to first lesson to completion)
- [x] P2 6.2.12 Retention analytics (return rate)
- [x] P2 6.2.13 Engagement analytics (sessions per week)
- [x] P2 6.2.14 Velocity analytics (concepts per week)
- [x] P2 6.2.15 Comparative analytics (vs other learners)
- [ ] P2 6.2.16 Analytics pages consume the extended analytics endpoints (temporal/retention/dropoff/funnel/platform/cohorts/devices APIs exist — only sessions + overview are fetched by UI)
- [ ] P2 6.2.17 Progress page and analytics pages pass auth bearer token on fetch (learner identity currently ambiguous server-side)

### 6.3 Retention Metrics

- [ ] P3 6.3.1 Forgetting curve measurement (per concept)
- [ ] P3 6.3.2 Retention rate calculation (actual vs expected)
- [ ] P3 6.3.3 Retention projection (future retention)
- [ ] P3 6.3.4 Retention comparison (with/without review)
- [ ] P3 6.3.5 Retention by concept type (recall, recognize, apply)
- [ ] P3 6.3.6 Retention by learner segment (beginner, advanced)
- [ ] P3 6.3.7 Retention over time (weekly, monthly)
- [ ] P3 6.3.8 Retention optimization suggestions
- [ ] P3 6.3.9 Retention goal tracking (target retention rate)
- [ ] P3 6.3.10 Retention benchmarking (vs platform average)

### 6.4 Engagement Metrics

- [ ] P3 6.4.1 Daily active learners
- [ ] P3 6.4.2 Session frequency (sessions per week)
- [ ] P3 6.4.3 Session duration (average, median)
- [ ] P3 6.4.4 Content consumption (pages viewed, time spent)
- [ ] P3 6.4.5 Exercise completion rate
- [ ] P3 6.4.6 Review completion rate
- [ ] P3 6.4.7 Course completion rate
- [ ] P3 6.4.8 Feature adoption rate (which features are used)
- [ ] P3 6.4.9 Return rate (learners who come back)
- [ ] P3 6.4.10 Churn prediction (learners likely to leave)
- [ ] P3 6.4.11 Engagement scoring (composite score)
- [ ] P3 6.4.12 Engagement trends (improving, declining)
- [ ] P3 6.4.13 Engagement comparison (vs average)
- [ ] P3 6.4.14 Engagement by time-of-day
- [ ] P3 6.4.15 Engagement by device type

---

## 7. User Experience

### 7.1 Navigation

- [x] P1 7.1.1 Course catalog browsing (grid/list view)
- [x] P1 7.1.2 Module navigation (sidebar)
- [x] P1 7.1.3 Concept navigation (within module)
- [x] P1 7.1.4 Lesson progression (next/prev buttons)
- [x] P1 7.1.5 Breadcrumb navigation (home > course > module > concept)
- [x] P2 7.1.6 Search functionality (full-text search)
- [x] P2 7.1.7 Filter/sort courses (by topic, difficulty, rating)
- [x] P2 7.1.9 Recent history (last 10 visited concepts)
- [x] P2 7.1.10 Quick jump (keyboard shortcuts, command palette)
- [x] P2 7.1.11 Table of contents (per concept)
- [x] P2 7.1.12 Back to top button
- [x] P2 7.1.13 Progress indicator in navigation
- [ ] P2 7.1.14 Unread indicator (new content)
- [x] P2 7.1.15 Due indicator (review items due)
- [ ] P1 7.1.16 Prev/next lesson navigation on concept pages wired to GET /api/navigation/:courseId/:conceptId (rel links are empty; no consumer of the navigation API)
- [ ] P1 7.1.17 Site navbar on lesson pages — concept pages rendered from content/src are orphaned from site navigation (no navbar, no way back to dashboard)
- [ ] P1 7.1.18 Auth-aware navbar: Login/Register links when logged out, profile + Logout when logged in (POST /api/auth/logout exists, no UI calls it)
- [ ] P1 7.1.19 401 handling in authenticated pages: redirect to /login when session token expired (pages currently render empty states silently)
- [ ] P1 7.1.20 Onboarding gate: logged-in users with incomplete onboarding are routed to /onboarding from home/dashboard (GET /api/onboarding/check exists, never consulted)
- [ ] P1 7.1.21 Course context from URL/state instead of hardcoded course_id=elf in review page, progress page, and analytics page fetches
- [ ] P1 7.1.22 Fix analytics page fetch of literal '/api/progress/:courseId' URL (real bug — requests the un-substituted route string)
- [ ] P1 7.1.23 Course landing page Enroll button wired to POST /api/courses/:courseId/enroll with can-enroll prerequisite feedback (enrollments API has no UI consumer)
- [ ] P2 7.1.24 Home page "Continue learning" card + due-reviews badge for logged-in learners (user-flow requirement; home is currently static)
- [ ] P2 7.1.25 Dashboard shows a login prompt instead of rendering "demo" learner data when logged out

### 7.2 UI Components

- [x] P1 7.2.1 Card component (course card, concept card)
- [x] P1 7.2.2 Button component (primary, secondary, outline, ghost)
- [x] P1 7.2.3 Badge component (status, difficulty, category)
- [x] P2 7.2.4 Progress component (bar, circular, steps)
- [x] P2 7.2.5 Alert component (info, success, warning, error)
- [x] P2 7.2.6 Modal/dialog component
- [x] P2 7.2.7 Tooltip component
- [x] P2 7.2.8 Toast/notification component
- [x] P2 7.2.9 Dropdown/select component
- [x] P2 7.2.10 Tab component
- [x] P2 7.2.11 Accordion/collapsible component
- [x] P2 7.2.12 Table component (sortable, filterable)
- [x] P2 7.2.13 Form components (input, textarea, checkbox, radio)
- [x] P2 7.2.14 Navigation components (sidebar, navbar, breadcrumb)
- [x] P2 7.2.15 Layout components (container, grid, stack)
- [x] P2 7.2.16 Skeleton component (loading placeholder)
- [x] P2 7.2.17 Avatar component (user, course, module)
- [x] P2 7.2.18 Separator/divider component
- [x] P2 7.2.19 Scroll area component
- [x] P2 7.2.20 Resizable panel component

### 7.3 Theming

- [x] P2 7.3.1 Light theme (default)
- [x] P2 7.3.2 Dark theme
- [x] P2 7.3.3 System theme detection (OS preference)
- [x] P2 7.3.4 Custom theme support (CSS variables)
- [x] P2 7.3.5 Theme persistence (localStorage)
- [x] P2 7.3.6 Theme preview (before applying)
- [x] P2 7.3.7 Font size adjustment (small, medium, large)
- [x] P2 7.3.8 Color blind mode (protanopia, deuteranopia, tritanopia)
- [x] P2 7.3.9 High contrast mode
- [x] P2 7.3.10 Reduced motion mode (prefers-reduced-motion)
- [x] P2 7.3.11 Custom font support (upload fonts)
- [x] P2 7.3.12 Line height adjustment
- [x] P2 7.3.13 Letter spacing adjustment
- [x] P2 7.3.14 Content width adjustment (narrow, normal, wide)

### 7.4 Responsive Design

- [x] P2 7.4.1 Mobile layout (< 640px)
- [x] P2 7.4.2 Tablet layout (640px - 1024px)
- [x] P2 7.4.3 Desktop layout (> 1024px)
- [x] P2 7.4.4 Large screen layout (> 1440px)
- [x] P2 7.4.5 Orientation handling (portrait, landscape)
- [x] P2 7.4.6 Touch interactions (tap, swipe, long-press)
- [x] P2 7.4.7 Swipe gestures (prev/next concept)
- [x] P2 7.4.8 Pinch-to-zoom (hex viewer, diagrams)
- [x] P2 7.4.9 Responsive images (srcset, sizes)
- [x] P2 7.4.10 Responsive typography (clamp, fluid)
- [x] P2 7.4.11 Responsive navigation (hamburger menu on mobile)
- [x] P2 7.4.12 Responsive tables (horizontal scroll on mobile)
- [ ] P2 7.4.13 Responsive visualizations (resize on window change)
- [x] P2 7.4.14 Responsive exercises (adapt to screen size)
- [x] P2 7.4.15 Responsive code blocks (horizontal scroll)

### 7.5 Keyboard & Input

- [x] P2 7.5.1 Keyboard navigation (Tab, Enter, Escape)
- [x] P2 7.5.2 Keyboard shortcuts (Ctrl+K for search)
- [x] P2 7.5.3 Keyboard shortcuts list (help dialog)
- [ ] P2 7.5.4 Custom keyboard shortcuts (user-defined)
- [x] P2 7.5.5 Screen reader support (ARIA labels)
- [ ] P2 7.5.6 Voice input support (speech-to-text)
- [ ] P2 7.5.7 Switch access support (external switches)
- [ ] P2 7.5.8 External keyboard support (Bluetooth)
- [ ] P2 7.5.9 Game controller support (navigation)
- [ ] P2 7.5.10 Stylus/pen support (drawing exercises)
- [ ] P2 7.5.11 Multi-touch support (pinch, rotate)
- [x] P2 7.5.12 Accessibility shortcuts (contrast, font size)
- [x] P2 7.5.13 Focus visible indicator (focus ring)
- [x] P2 7.5.14 Skip links (skip to content)
- [x] P2 7.5.15 Landmark regions (navigation, main, footer)

---

## 8. Social & Community

### 8.1 User Profiles

- [ ] P3 8.1.1 Profile creation (during registration)
- [ ] P3 8.1.2 Profile editing (name, bio, avatar)
- [ ] P3 8.1.3 Avatar upload (image crop/resize)
- [ ] P3 8.1.4 Avatar from URL
- [ ] P3 8.1.5 Avatar from generated (initials, identicon)
- [ ] P3 8.1.6 Bio/about section (markdown)
- [ ] P3 8.1.7 Learning goals (public/private)
- [ ] P3 8.1.8 Location (optional, public)
- [ ] P3 8.1.9 Website/social links
- [ ] P3 8.1.10 Profile visibility settings (public/private/anonymous)
- [ ] P3 8.1.11 Profile permalink (/u/username)
- [ ] P3 8.1.12 Profile SEO (meta tags)
- [ ] P3 8.1.13 Profile statistics (courses completed, hours learned)
- [ ] P3 8.1.14 Profile badges (display earned badges)
- [ ] P3 8.1.15 Profile certificates (display earned certificates)
- [ ] P3 8.1.16 Profile activity feed (recent activity)
- [ ] P3 8.1.17 Profile course list (courses in progress, completed)
- [ ] P3 8.1.18 Profile settings (notifications, privacy)
- [ ] P3 8.1.19 Profile deletion
- [ ] P3 8.1.20 Profile data export

### 8.2 Social Features

- [ ] P3 8.2.1 Follow other learners
- [ ] P3 8.2.2 Unfollow learners
- [ ] P3 8.2.3 Activity feed (followed learners' activity)
- [ ] P3 8.2.4 Learning groups (create, join, leave)
- [ ] P3 8.2.5 Group settings (name, description, privacy)
- [ ] P3 8.2.6 Group members (invite, remove, roles)
- [ ] P3 8.2.7 Group progress (shared progress)
- [ ] P3 8.2.8 Group challenges (compete together)
- [ ] P3 8.2.9 Study sessions (synchronized learning)
- [ ] P3 8.2.10 Discussion forums (per course, per concept)
- [ ] P3 8.2.11 Forum threads (create, reply, upvote)
- [ ] P3 8.2.12 Forum moderation (flag, remove, ban)
- [ ] P3 8.2.13 Q&A sections (ask questions, answer)
- [ ] P3 8.2.14 Peer review (review others' explanations)
- [ ] P3 8.2.15 Collaboration exercises (solve together)
- [ ] P3 8.2.16 Shared progress (opt-in)
- [ ] P3 8.2.17 Social challenges (compete with friends)
- [ ] P3 8.2.18 Activity sharing (share to social media)
- [ ] P3 8.2.19 Direct messaging (1:1)
- [ ] P3 8.2.20 Group messaging (group chat)

### 8.3 Community Content

- [ ] P3 8.3.1 User-generated exercises (submit exercises)
- [ ] P3 8.3.2 Exercise ratings (1-5 stars)
- [ ] P3 8.3.3 Exercise comments (discuss exercises)
- [ ] P3 8.3.4 Course reviews (rate and review courses)
- [ ] P3 8.3.5 Course ratings (1-5 stars)
- [ ] P3 8.3.6 Course comments (discuss courses)
- [ ] P3 8.3.7 Explanation contributions (add explanations)
- [ ] P3 8.3.8 Hint contributions (add hints)
- [ ] P3 8.3.9 Translation contributions (translate content)
- [ ] P3 8.3.10 Content moderation (flag, approve, remove)
- [ ] P3 8.3.11 Content reporting (report inappropriate content)
- [ ] P3 8.3.12 Content rewards (earn points for contributions)
- [ ] P3 8.3.13 Content leaderboards (top contributors)
- [ ] P3 8.3.14 Content verification (verify accuracy)
- [ ] P3 8.3.15 Content versioning (edit history)

### 8.4 Mentorship

- [ ] P3 8.4.1 Mentor profiles (expertise, availability)
- [ ] P3 8.4.2 Mentee profiles (goals, current level)
- [ ] P3 8.4.3 Mentor matching (based on expertise, goals)
- [ ] P3 8.4.4 Session scheduling (calendar integration)
- [ ] P3 8.4.5 Session notes (shared notes)
- [ ] P3 8.4.6 Progress sharing with mentor
- [ ] P3 8.4.7 Mentor feedback (text, audio)
- [ ] P3 8.4.8 Mentor rating (rate mentor sessions)
- [ ] P3 8.4.9 Mentor leaderboard (top mentors)
- [ ] P3 8.4.10 Mentor availability (set available times)
- [ ] P3 8.4.11 Mentor pricing (free, paid)
- [ ] P3 8.4.12 Mentor verification (verify expertise)
- [ ] P3 8.4.13 Mentor matching algorithm (AI-based)
- [ ] P3 8.4.14 Mentor matching preferences (language, timezone)
- [ ] P3 8.4.15 Mentor session recording (opt-in)

### 8.5 Competitive Features

- [ ] P3 8.5.1 Leaderboards (opt-in, per course)
- [ ] P3 8.5.2 Leaderboards (global, weekly, monthly)
- [ ] P3 8.5.3 Learning challenges (daily, weekly)
- [ ] P3 8.5.4 Achievement badges (earn badges)
- [ ] P3 8.5.5 Certificates (earn certificates)
- [ ] P3 8.5.6 Streaks (consecutive days)
- [ ] P3 8.5.7 Streak milestones (7, 30, 100, 365 days)
- [ ] P3 8.5.8 Streak sharing (share on social media)
- [ ] P3 8.5.9 Milestones (earn milestones)
- [ ] P3 8.5.10 Progress competitions (compete with friends)
- [ ] P3 8.5.11 Team challenges (compete as teams)
- [ ] P3 8.5.12 Community events (live learning sessions)
- [ ] P3 8.5.13 Live learning sessions (synchronized)
- [ ] P3 8.5.14 Live Q&A sessions (ask experts)
- [ ] P3 8.5.15 Live workshops (hands-on learning)

---

## 9. Content Delivery

### 9.1 Static Delivery

- [x] P3 9.1.1 Pre-rendered HTML/CSS/JS files
- [x] P3 9.1.2 Static file serving (nginx, CDN)
- [ ] P3 9.1.3 CDN distribution (Cloudflare, Fastly)
- [ ] P3 9.1.4 Asset compression (gzip, brotli)
- [ ] P3 9.1.5 Browser caching (Cache-Control headers)
- [ ] P3 9.1.6 CDN caching (edge caching)
- [ ] P3 9.1.7 Cache invalidation (on content update)
- [ ] P3 9.1.8 Lazy loading (images, components)
- [ ] P3 9.1.9 Code splitting (JavaScript chunks)
- [ ] P3 9.1.10 Progressive loading (critical CSS, deferred JS)
- [ ] P3 9.1.11 Service worker caching (offline support)
- [ ] P3 9.1.12 Preloading (preload critical assets)
- [ ] P3 9.1.13 Prefetching (prefetch next page)
- [ ] P3 9.1.14 DNS prefetching (external domains)
- [ ] P3 9.1.15 HTTP/2 server push (push critical assets)

### 9.2 Dynamic Delivery

- [ ] P3 9.2.1 API-based content delivery (JSON)
- [ ] P3 9.2.2 Streaming responses (SSE)
- [ ] P3 9.2.3 Partial content delivery (pagination)
- [ ] P3 9.2.4 Conditional requests (ETags)
- [ ] P3 9.2.5 Range requests (partial download)
- [ ] P3 9.2.6 Content negotiation (Accept header)
- [ ] P3 9.2.7 Compression negotiation (Accept-Encoding)
- [ ] P3 9.2.8 Protocol negotiation (HTTP/2, HTTP/3)
- [ ] P3 9.2.9 WebSocket for real-time (live sessions)
- [ ] P3 9.2.10 Server-Sent Events (progress updates)
- [ ] P3 9.2.11 GraphQL API (flexible queries)
- [ ] P3 9.2.12 Rate limiting (per user, per IP)
- [ ] P3 9.2.13 Caching headers (Cache-Control, ETag)
- [ ] P3 9.2.14 CORS support (cross-origin requests)
- [ ] P3 9.2.15 Content Security Policy headers

### 9.3 Course Packaging

- [ ] P3 9.3.1 Course ZIP export (downloadable course)
- [ ] P3 9.3.2 Course JSON export (structured data)
- [ ] P3 9.3.3 Course HTML export (standalone HTML)
- [ ] P3 9.3.4 Course PDF export (printable)
- [ ] P3 9.3.5 Course import (from ZIP, JSON)
- [ ] P3 9.3.6 Course migration (between instances)
- [ ] P3 9.3.7 Course backup (full backup)
- [ ] P3 9.3.8 Course restore (from backup)
- [ ] P3 9.3.9 Course versioning (version history)
- [ ] P3 9.3.10 Course diffing (compare versions)
- [ ] P3 9.3.11 Course bundling (multiple courses)
- [ ] P3 9.3.12 Course packaging validation
- [ ] P3 9.3.13 Course packaging compression
- [ ] P3 9.3.14 Course packaging encryption (optional)
- [ ] P3 9.3.15 Course packaging signing (integrity)

### 9.4 Offline Support

- [ ] P3 9.4.1 Service worker caching (cache-first strategy)
- [ ] P3 9.4.2 IndexedDB storage (structured data)
- [ ] P3 9.4.3 Background sync (sync when online)
- [ ] P3 9.4.4 Offline queue (queue actions, sync later)
- [ ] P3 9.4.5 Conflict resolution (last-write-wins)
- [ ] P3 9.4.6 Delta updates (only changed content)
- [ ] P3 9.4.7 Course pre-caching (cache entire course)
- [ ] P3 9.4.8 Asset pre-caching (cache all assets)
- [ ] P3 9.4.9 Offline indicators (show offline status)
- [ ] P3 9.4.10 Sync status display (syncing, synced, error)
- [ ] P3 9.4.11 Offline-first design (work without internet)
- [ ] P3 9.4.12 Offline progress tracking (localStorage)
- [ ] P3 9.4.13 Offline review scheduling (FSRS in browser)
- [ ] P3 9.4.14 Offline exercise completion (queue for sync)
- [ ] P3 9.4.15 Offline notifications (queue for delivery)

---

## 10. Admin & Management

### 10.1 Course Management

- [ ] P3 10.1.1 Course creation wizard (step-by-step)
- [ ] P3 10.1.2 Course editor (visual editor)
- [ ] P3 10.1.3 Concept editor (WYSIWYG)
- [ ] P3 10.1.4 Exercise editor (template-based)
- [ ] P3 10.1.5 Review item editor (template-based)
- [ ] P3 10.1.6 Asset manager (upload, organize)
- [ ] P3 10.1.7 Course preview (before publishing)
- [ ] P3 10.1.8 Course publishing (publish/unpublish)
- [ ] P3 10.1.9 Course analytics (views, completions, ratings)
- [ ] P3 10.1.10 Course versioning (version history)
- [ ] P3 10.1.11 Course rollback (revert to previous version)
- [ ] P3 10.1.12 Course cloning (duplicate course)
- [ ] P3 10.1.13 Course archiving (hide without deleting)
- [ ] P3 10.1.14 Course deletion (with confirmation)
- [ ] P3 10.1.15 Course import (from file, URL)
- [ ] P3 10.1.16 Course export (to file, URL)
- [ ] P3 10.1.17 Course scheduling (publish at specific time)
- [ ] P3 10.1.18 Course access control (who can access)
- [ ] P3 10.1.19 Course pricing (free, paid, subscription)
- [ ] P3 10.1.20 Course metadata (title, description, tags)

### 10.2 User Management

- [ ] P3 10.2.1 User listing (all users)
- [ ] P3 10.2.2 User search (by name, email, username)
- [ ] P3 10.2.3 User roles (admin, instructor, learner)
- [ ] P3 10.2.4 User permissions (per role, per course)
- [ ] P3 10.2.5 User suspension (temporary ban)
- [ ] P3 10.2.6 User deletion (with confirmation)
- [ ] P3 10.2.7 User data export (GDPR)
- [ ] P3 10.2.8 User data import (bulk import)
- [ ] P3 10.2.9 User activity log (all actions)
- [ ] P3 10.2.10 User communication (email, in-app)
- [ ] P3 10.2.11 User groups (organize users)
- [ ] P3 10.2.12 User invitations (email, link)
- [ ] P3 10.2.13 User onboarding (welcome flow)
- [ ] P3 10.2.14 User engagement scoring
- [ ] P3 10.2.15 User churn prediction

### 10.3 Content Moderation

- [ ] P3 10.3.1 Exercise review queue (pending exercises)
- [ ] P3 10.3.2 Comment moderation (pending comments)
- [ ] P3 10.3.3 Report handling (user reports)
- [ ] P3 10.3.4 Content flagging (inappropriate content)
- [ ] P3 10.3.5 Spam detection (automated)
- [ ] P3 10.3.6 Quality scoring (automated quality check)
- [ ] P3 10.3.7 Auto-approval rules (trusted users)
- [ ] P3 10.3.8 Manual approval workflow (review queue)
- [ ] P3 10.3.9 Appeal process (contest moderation)
- [ ] P3 10.3.10 Moderation log (all moderation actions)
- [ ] P3 10.3.11 Moderation analytics (queue size, resolution time)
- [ ] P3 10.3.12 Moderation notifications (new items in queue)
- [ ] P3 10.3.13 Moderation assignment (assign to moderator)
- [ ] P3 10.3.14 Moderation escalation (escalate to admin)
- [ ] P3 10.3.15 Moderation guidelines (rules for moderators)

### 10.4 Platform Configuration

- [ ] P3 10.4.1 Feature flags (enable/disable features)
- [ ] P3 10.4.2 Rate limiting configuration
- [ ] P3 10.4.3 Maintenance mode (enable/disable)
- [ ] P3 10.4.4 Announcements (system-wide messages)
- [ ] P3 10.4.5 System health monitoring
- [ ] P3 10.4.6 Error tracking configuration
- [ ] P3 10.4.7 Performance monitoring configuration
- [ ] P3 10.4.8 Security monitoring configuration
- [ ] P3 10.4.9 Compliance reporting configuration
- [ ] P3 10.4.10 Audit logging configuration
- [ ] P3 10.4.11 Email configuration (SMTP)
- [ ] P3 10.4.12 Storage configuration (local, S3, GCS)
- [ ] P3 10.4.13 Database configuration (SQLite, Turso, Postgres)
- [ ] P3 10.4.14 CDN configuration
- [ ] P3 10.4.15 Analytics configuration

---

## 11. API & Integrations

### 11.1 REST API

- [x] P3 11.1.1 GET /api/health (health check)
- [x] P3 11.1.2 GET /api/courses (list courses)
- [x] P3 11.1.3 GET /api/courses/:id (course detail)
- [ ] P3 11.1.4 GET /api/courses/:id/concepts (list concepts)
- [ ] P3 11.1.5 GET /api/concepts/:id (concept detail)
- [x] P3 11.1.6 GET /api/concepts/:id/content (concept content)
- [x] P3 11.1.7 POST /api/review/start (start review session)
- [x] P3 11.1.8 POST /api/review/submit (submit review answer)
- [x] P3 11.1.9 POST /api/review/end (end review session)
- [x] P3 11.1.9 GET /api/review/due (get due items)
- [x] P3 11.1.10 GET /api/progress (get learner progress)
- [x] P3 11.1.11 GET /api/progress/:courseId (course progress)
- [ ] P3 11.1.12 GET /api/health/knowledge (knowledge health)
- [ ] P3 11.1.13 GET /api/analytics/sessions (session analytics)
- [ ] P3 11.1.14 GET /api/analytics/retention (retention metrics)
- [ ] P3 11.1.15 POST /api/user/register (register user)
- [ ] P3 11.1.16 POST /api/user/login (login user)
- [ ] P3 11.1.17 GET /api/user/profile (get profile)
- [ ] P3 11.1.18 PUT /api/user/profile (update profile)
- [ ] P3 11.1.19 GET /api/user/settings (get settings)
- [ ] P3 11.1.20 PUT /api/user/settings (update settings)
- [ ] P3 11.1.21 POST /api/user/logout (logout)
- [ ] P3 11.1.22 POST /api/user/refresh (refresh token)
- [ ] P3 11.1.23 POST /api/user/forgot-password (request reset)
- [ ] P3 11.1.24 POST /api/user/reset-password (reset with token)
- [ ] P3 11.1.25 GET /api/analytics/engagement (engagement metrics)
- [ ] P3 11.1.26 GET /api/analytics/weakness (weakness report)
- [ ] P3 11.1.27 GET /api/reviews/history (review history)
- [ ] P3 11.1.28 GET /api/courses/:id/reviews (course reviews)
- [ ] P3 11.1.29 POST /api/courses/:id/reviews (submit review)
- [ ] P3 11.1.30 GET /api/badges (list badges)

### 11.2 Authentication

- [ ] P3 11.2.1 Email/password authentication
- [ ] P3 11.2.2 OAuth authentication (Google)
- [ ] P3 11.2.3 OAuth authentication (GitHub)
- [ ] P3 11.2.4 OAuth authentication (Apple)
- [ ] P3 11.2.5 OAuth authentication (Microsoft)
- [ ] P3 11.2.6 SSO authentication (SAML)
- [ ] P3 11.2.7 API key authentication
- [ ] P3 11.2.8 JWT token generation
- [ ] P3 11.2.9 JWT token refresh
- [ ] P3 11.2.10 Session management (create, revoke)
- [ ] P3 11.2.11 Password reset (email link)
- [ ] P3 11.2.12 Email verification (email link)
- [ ] P3 11.2.13 Two-factor authentication (TOTP)
- [ ] P3 11.2.14 Backup codes generation
- [ ] P3 11.2.15 Backup codes recovery
- [ ] P1 11.2.16 Frontend auth session bootstrap: shared JS helper to read session_token, attach Authorization headers, and refresh/expire gracefully (each page re-implements token handling; /api/auth/me never called to validate)
- [ ] P1 11.2.17 Register/login flows redirect into the onboarding gate instead of raw home redirect

### 11.3 Third-Party Integrations

- [ ] P3 11.3.1 LMS integration (LTI 1.3)
- [ ] P3 11.3.2 SIS integration (Student Information System)
- [ ] P3 11.3.3 Calendar integration (Google Calendar)
- [ ] P3 11.3.4 Calendar integration (iCal)
- [ ] P3 11.3.5 Notification integration (email)
- [ ] P3 11.3.6 Notification integration (push)
- [ ] P3 11.3.7 Notification integration (Slack)
- [ ] P3 11.3.8 Analytics integration (Google Analytics)
- [ ] P3 11.3.9 Analytics integration (Mixpanel)
- [ ] P3 11.3.10 Payment integration (Stripe)
- [ ] P3 11.3.11 Payment integration (PayPal)
- [ ] P3 11.3.12 CRM integration (HubSpot)
- [ ] P3 11.3.13 Zapier integration
- [ ] P3 11.3.14 Webhook integration (custom)
- [ ] P3 11.3.15 RSS feed integration

### 11.4 Data Export/Import

- [ ] P3 11.4.1 Learner data export (JSON)
- [ ] P3 11.4.2 Learner data export (CSV)
- [ ] P3 11.4.3 Learner data import (JSON)
- [ ] P3 11.4.4 Learner data import (CSV)
- [ ] P3 11.4.5 Course data export (JSON)
- [ ] P3 11.4.6 Course data import (JSON)
- [ ] P3 11.4.7 Analytics data export (JSON, CSV)
- [ ] P3 11.4.8 Progress data export (JSON, CSV)
- [ ] P3 11.4.9 Review data export (JSON, CSV)
- [ ] P3 11.4.10 Bulk operations (bulk import, bulk export)
- [ ] P3 11.4.11 Migration tools (version migration)
- [ ] P3 11.4.12 Backup/restore tools
- [ ] P3 11.4.13 Data transformation (format conversion)
- [ ] P3 11.4.14 Data validation (import validation)
- [ ] P3 11.4.15 Data deduplication (remove duplicates)

---

## 12. Accessibility

### 12.1 WCAG Compliance

- [ ] P3 12.1.1 WCAG 2.1 AA compliance (target)
- [ ] P3 12.1.2 WCAG 2.1 AAA compliance (stretch)
- [ ] P3 12.1.3 Screen reader compatibility (NVDA, VoiceOver, JAWS)
- [ ] P3 12.1.4 Keyboard-only navigation (all features)
- [ ] P3 12.1.5 Focus management (visible focus indicator)
- [ ] P3 12.1.6 Skip links (skip to content, skip to nav)
- [ ] P3 12.1.7 ARIA labels (all interactive elements)
- [ ] P3 12.1.8 ARIA live regions (dynamic content updates)
- [ ] P3 12.1.9 Color contrast (4.5:1 normal, 3:1 large)
- [ ] P3 12.1.10 Text resizing (200% without loss)
- [ ] P3 12.1.11 Reflow (320px without horizontal scroll)
- [ ] P3 12.1.12 Text spacing (adjustable)
- [ ] P3 12.1.13 Content structure (proper headings)
- [ ] P3 12.1.14 Link purpose (clear link text)
- [ ] P3 12.1.15 Image alternatives (alt text)

### 12.2 Visual Accessibility

- [ ] P3 12.2.1 High contrast mode (enhanced contrast)
- [ ] P3 12.2.2 Color blind mode (protanopia)
- [ ] P3 12.2.3 Color blind mode (deuteranopia)
- [ ] P3 12.2.4 Color blind mode (tritanopia)
- [ ] P3 12.2.5 Text-to-speech (screen reader integration)
- [ ] P3 12.2.6 Magnification support (browser zoom)
- [ ] P3 12.2.7 Reduced motion mode (disable animations)
- [ ] P3 12.2.8 Dark mode (reduce eye strain)
- [ ] P3 12.2.9 Custom fonts (dyslexia-friendly)
- [ ] P3 12.2.10 Line spacing adjustment
- [ ] P3 12.2.11 Letter spacing adjustment
- [ ] P3 12.2.12 Cursor customization (size, color)
- [ ] P3 12.2.13 Highlight links (underline, color)
- [ ] P3 12.2.14 Reading guide (follow cursor)
- [ ] P3 12.2.15 Color palette customization

### 12.3 Motor Accessibility

- [ ] P3 12.3.1 Keyboard navigation (all features)
- [ ] P3 12.3.2 Switch access (external switches)
- [ ] P3 12.3.3 Voice control (speech commands)
- [ ] P3 12.3.4 Eye tracking support (gaze interaction)
- [ ] P3 12.3.5 Head tracking support (head movement)
- [ ] P3 12.3.6 Large click targets (minimum 44x44px)
- [ ] P3 12.3.7 Adjustable timing (no time limits)
- [ ] P3 12.3.8 Pause/stop/hide controls (no auto-play)
- [ ] P3 12.3.9 No keyboard traps (always can Tab out)
- [ ] P3 12.3.10 Accessible forms (labels, instructions)
- [ ] P3 12.3.11 Drag-and-drop alternatives (keyboard)
- [ ] P3 12.3.12 Hover alternatives (focus triggers)
- [ ] P3 12.3.13 Touch alternatives (large touch areas)
- [ ] P3 12.3.14 Motion alternatives (keyboard shortcuts)
- [ ] P3 12.3.15 Timing alternatives (extend time limits)

### 12.4 Cognitive Accessibility

- [ ] P3 12.4.1 Clear language (simple, direct)
- [ ] P3 12.4.2 Consistent navigation (same everywhere)
- [ ] P3 12.4.3 Predictable behavior (no surprises)
- [ ] P3 12.4.4 Error prevention (confirm before action)
- [ ] P3 12.4.5 Error recovery (undo, correct)
- [ ] P3 12.4.6 Help system (contextual help)
- [ ] P3 12.4.7 Glossary (technical terms)
- [ ] P3 12.4.8 Progress indicators (show where you are)
- [ ] P3 12.4.9 Time limits (configurable, extendable)
- [ ] P3 12.4.10 Distraction-free mode (minimal UI)
- [ ] P3 12.4.11 Reading level indicator (Flesch-Kincaid)
- [ ] P3 12.4.12 Visual hierarchy (clear structure)
- [ ] P3 12.4.13 Chunking (break content into pieces)
- [ ] P3 12.4.14 Mnemonics (memory aids)
- [ ] P3 12.4.15 Scaffolding (build on previous knowledge)

---

## 13. Security & Privacy

### 13.1 Data Security

- [ ] P3 13.1.1 Data encryption at rest (AES-256)
- [ ] P3 13.1.2 Data encryption in transit (TLS 1.3)
- [ ] P3 13.1.3 Password hashing (bcrypt, cost=12)
- [ ] P3 13.1.4 Input validation (all inputs sanitized)
- [ ] P3 13.1.5 SQL injection prevention (parameterized queries)
- [ ] P3 13.1.6 XSS prevention (output encoding)
- [ ] P3 13.1.7 CSRF protection (tokens)
- [ ] P3 13.1.8 Rate limiting (per user, per IP)
- [ ] P3 13.1.9 DDoS protection (Cloudflare, AWS Shield)
- [ ] P3 13.1.10 Security headers (CSP, HSTS, X-Frame-Options)
- [ ] P3 13.1.11 Content Security Policy (CSP)
- [ ] P3 13.1.12 HTTP Strict Transport Security (HSTS)
- [ ] P3 13.1.13 X-Content-Type-Options (nosniff)
- [ ] P3 13.1.14 X-Frame-Options (DENY)
- [ ] P3 13.1.15 Referrer-Policy (strict-origin-when-cross-origin)

### 13.2 Privacy

- [ ] P3 13.2.1 Privacy policy (clear, readable)
- [ ] P3 13.2.2 Terms of service
- [ ] P3 13.2.3 Cookie policy
- [ ] P3 13.2.4 Cookie consent (opt-in, not opt-out)
- [ ] P3 13.2.5 Data minimization (collect only what is needed)
- [ ] P3 13.2.6 Right to deletion (account deletion)
- [ ] P3 13.2.7 Right to portability (data export)
- [ ] P3 13.2.8 Right to rectification (correct data)
- [ ] P3 13.2.9 Right to object (opt-out of processing)
- [ ] P3 13.2.10 Consent management (granular consent)
- [ ] P3 13.2.11 Data retention policies (auto-delete old data)
- [ ] P3 13.2.12 Data processing agreements (DPA)
- [ ] P3 13.2.13 Privacy by design (default privacy)
- [ ] P3 13.2.14 Privacy impact assessment (PIA)
- [ ] P3 13.2.15 Data breach notification (72-hour rule)

### 13.3 Compliance

- [ ] P3 13.3.1 GDPR compliance (EU)
- [ ] P3 13.3.2 CCPA compliance (California)
- [ ] P3 13.3.3 FERPA compliance (education records)
- [ ] P3 13.3.4 COPPA compliance (children under 13)
- [ ] P3 13.3.5 SOC 2 compliance (Type I, Type II)
- [ ] P3 13.3.6 ISO 27001 compliance
- [ ] P3 13.3.7 HIPAA compliance (if health data)
- [ ] P3 13.3.8 Accessibility compliance (ADA)
- [ ] P3 13.3.9 Data retention policies
- [ ] P3 13.3.10 Audit trail (all actions logged)
- [ ] P3 13.3.11 Compliance reporting (automated)
- [ ] P3 13.3.12 Compliance training (for staff)
- [ ] P3 13.3.13 Compliance monitoring (continuous)
- [ ] P3 13.3.14 Compliance remediation (fix issues)
- [ ] P3 13.3.15 Compliance documentation (policies, procedures)

---

## 14. Performance & Scalability

### 14.1 Performance

- [ ] P3 14.1.1 Page load time < 2 seconds
- [ ] P3 14.1.2 Time to interactive < 3 seconds
- [ ] P3 14.1.3 First contentful paint < 1 second
- [ ] P3 14.1.4 Largest contentful paint < 2.5 seconds
- [ ] P3 14.1.5 Cumulative layout shift < 0.1
- [ ] P3 14.1.6 First input delay < 100ms
- [ ] P3 14.1.7 Time to first byte < 200ms
- [ ] P3 14.1.8 Bundle size optimization (JS < 200KB gzipped)
- [ ] P3 14.1.9 Image optimization (WebP, AVIF formats)
- [ ] P3 14.1.10 Font optimization (subset, preload)
- [ ] P3 14.1.11 Critical CSS inlining
- [ ] P3 14.1.12 JavaScript deferral (non-critical)
- [ ] P3 14.1.13 Resource hints (preload, prefetch, preconnect)
- [ ] P3 14.1.14 HTTP/2 multiplexing
- [ ] P3 14.1.15 HTTP/3 QUIC transport

### 14.2 Scalability

- [ ] P3 14.2.1 Horizontal scaling (add more servers)
- [ ] P3 14.2.2 Database read replicas
- [ ] P3 14.2.3 Database connection pooling
- [ ] P3 14.2.4 Query optimization (indexes, query plans)
- [ ] P3 14.2.5 Caching strategy (Redis, Memcached)
- [ ] P3 14.2.6 CDN utilization (offload static assets)
- [ ] P3 14.2.7 Load balancing (round-robin, least-connections)
- [ ] P3 14.2.8 Auto-scaling (based on CPU, memory, requests)
- [ ] P3 14.2.9 Resource monitoring (CPU, memory, disk, network)
- [ ] P3 14.2.10 Capacity planning (forecast growth)
- [ ] P3 14.2.11 Performance testing (load, stress, soak)
- [ ] P3 14.2.12 Stress testing (find breaking point)
- [ ] P3 14.2.13 Database sharding (horizontal partitioning)
- [ ] P3 14.2.14 Message queue (async processing)
- [ ] P3 14.2.15 Background jobs (email, analytics, reports)

### 14.3 Reliability

- [ ] P3 14.3.1 99.9% uptime SLA
- [ ] P3 14.3.2 Disaster recovery plan
- [ ] P3 14.3.3 Backup strategy (daily, weekly, monthly)
- [ ] P3 14.3.4 Failover mechanism (automatic)
- [ ] P3 14.3.5 Health checks (every 30 seconds)
- [ ] P3 14.3.6 Circuit breakers (prevent cascade failures)
- [ ] P3 14.3.7 Retry logic (exponential backoff)
- [ ] P3 14.3.8 Graceful degradation (fallback functionality)
- [ ] P3 14.3.9 Error recovery (automatic restart)
- [ ] P3 14.3.10 Monitoring alerts (PagerDuty, Slack)
- [ ] P3 14.3.11 Incident response plan
- [ ] P3 14.3.12 Post-mortem process
- [ ] P3 14.3.13 SLA monitoring (track uptime)
- [ ] P3 14.3.14 Error budget (allowable failures)
- [ ] P3 14.3.15 Chaos engineering (test failure modes)

---

## 15. Developer Experience

### 15.1 Course Authoring Tools

- [ ] P3 15.1.1 Course template generator (scaffold new course)
- [ ] P3 15.1.2 Concept template generator (scaffold new concept)
- [ ] P3 15.1.3 Exercise template generator (scaffold new exercise)
- [ ] P3 15.1.4 Review item template generator
- [ ] P3 15.1.5 Course validator (check manifest, structure)
- [ ] P3 15.1.6 Concept validator (check content, exercises)
- [ ] P3 15.1.7 Exercise validator (check answers, hints)
- [ ] P3 15.1.8 Course preview server (local dev server)
- [ ] P3 15.1.9 Hot reload for course development
- [ ] P3 15.1.10 Course debugging tools (console, network)
- [ ] P3 15.1.11 Course profiler (render time analysis)
- [ ] P3 15.1.12 Course linter (style, conventions)
- [ ] P3 15.1.13 Concept linter (content quality)
- [ ] P3 15.1.14 Exercise linter (answer quality)
- [ ] P3 15.1.15 Course scaffolding wizard

### 15.2 Testing Tools

- [ ] P3 15.2.1 Course test runner (run all course tests)
- [ ] P3 15.2.2 Exercise test generator (auto-generate tests)
- [ ] P3 15.2.3 Review item test generator
- [ ] P3 15.2.4 Accessibility test runner (axe-core integration)
- [ ] P3 15.2.5 Performance test runner (Lighthouse)
- [ ] P3 15.2.6 Cross-browser test runner (Playwright)
- [ ] P3 15.2.7 Mobile test runner (device emulation)
- [ ] P3 15.2.8 Integration test runner (end-to-end)
- [ ] P3 15.2.9 Visual regression test runner (screenshot comparison)
- [ ] P3 15.2.10 Load test runner (k6, Artillery)
- [ ] P3 15.2.11 Course test report (HTML report)
- [ ] P3 15.2.12 Course test coverage (what is tested)
- [ ] P3 15.2.13 Course test CI integration (GitHub Actions)
- [ ] P3 15.2.14 Course test parallelization
- [ ] P3 15.2.15 Course test retry (flaky test handling)

### 15.3 Development Tools

- [ ] P3 15.3.1 Code formatter (consistent style)
- [ ] P3 15.3.2 Dependency analyzer (course dependencies)
- [ ] P3 15.3.3 Dead code detector (unused assets, code)
- [ ] P3 15.3.4 Performance profiler (render time, memory)
- [ ] P3 15.3.5 Memory profiler (leak detection)
- [ ] P3 15.3.6 Bundle analyzer (JS/CSS size breakdown)
- [ ] P3 15.3.7 Documentation generator (auto-docs)
- [ ] P3 15.3.8 API documentation generator (OpenAPI)
- [ ] P3 15.3.9 Changelog generator (from commits)
- [ ] P3 15.3.10 Release notes generator

### 15.4 CI/CD

- [ ] P3 15.4.1 Build automation (on commit)
- [ ] P3 15.4.2 Test automation (on PR)
- [ ] P3 15.4.3 Deployment automation (on merge to main)
- [ ] P3 15.4.4 Rollback automation (on failure)
- [ ] P3 15.4.5 Monitoring automation (after deploy)
- [ ] P3 15.4.6 Alerting automation (on error spike)
- [ ] P3 15.4.7 Reporting automation (daily/weekly reports)
- [ ] P3 15.4.8 Release management (version bumping)
- [ ] P3 15.4.9 Version management (semver enforcement)
- [ ] P3 15.4.10 Changelog generation (from PR titles)

---

## 16. Account Management

### 16.1 Registration

- [x] P3 16.1.1 Email/password registration form
- [x] P3 16.1.2 Email validation (format check)
- [x] P3 16.1.3 Email uniqueness check (duplicate detection)
- [x] P3 16.1.4 Password strength requirements (min 8 chars, uppercase, number, symbol)
- [x] P3 16.1.5 Password confirmation field
- [ ] P3 16.1.6 Terms of service acceptance checkbox
- [ ] P3 16.1.7 Privacy policy acceptance checkbox
- [ ] P3 16.1.8 CAPTCHA on registration (anti-bot)
- [ ] P3 16.1.9 Rate limiting (5 registrations per IP per hour)
- [ ] P3 16.1.10 Welcome email on registration
- [ ] P3 16.1.11 Email verification email (verify within 24h)
- [ ] P3 16.1.12 Email verification link expiry (24 hours)
- [ ] P3 16.1.13 Email verification resend (max 3 per day)
- [x] P3 16.1.14 Auto-login after registration
- [ ] P3 16.1.15 Onboarding questionnaire after registration
- [ ] P3 16.1.16 Default avatar generation (initials, identicon)
- [ ] P3 16.1.17 Username generation (fun defaults: learner-42)
- [ ] P3 16.1.18 Referral tracking (who invited you)
- [ ] P3 16.1.19 Registration analytics (conversion tracking)
- [x] P3 16.1.20 Registration error messages (clear, helpful)

### 16.2 Login

- [x] P3 16.2.1 Email/password login form
- [x] P3 16.2.2 Email field (with autocomplete)
- [x] P3 16.2.3 Password field (with show/hide toggle)
- [x] P3 16.2.4 "Remember me" checkbox (persistent session)
- [x] P3 16.2.5 "Forgot password?" link
- [x] P3 16.2.6 "Don't have an account?" link
- [ ] P3 16.2.7 Login rate limiting (5 attempts per 15 minutes)
- [ ] P3 16.2.8 Account lockout after 10 failed attempts
- [ ] P3 16.2.9 Account lockout duration (15 minutes, configurable)
- [ ] P3 16.2.10 Login success logging (IP, user agent, timestamp)
- [ ] P3 16.2.11 Login failure logging (IP, reason, timestamp)
- [ ] P3 16.2.12 Suspicious login detection (new IP, new device)
- [ ] P3 16.2.13 Suspicious login notification (email alert)
- [x] P3 16.2.14 Session token generation (JWT, 24h expiry)
- [x] P3 16.2.15 Session token refresh (sliding window)
- [x] P3 16.2.16 Active session listing (see all logged-in devices)
- [x] P3 16.2.17 Session revocation (log out specific device)
- [x] P3 16.2.18 Revoke all sessions (security breach response)
- [ ] P3 16.2.19 Login analytics (success rate, failure reasons)
- [ ] P3 16.2.20 OAuth login buttons (Google, GitHub, Apple)

### 16.3 Password Reset

- [x] P3 16.3.1 "Forgot password?" link on login page
- [x] P3 16.3.2 Email input form (enter email to reset)
- [x] P3 16.3.3 Reset link generation (unique, time-limited token)
- [ ] P3 16.3.4 Reset link sent to email (within 60 seconds)
- [x] P3 16.3.5 Reset link expiry (1 hour)
- [x] P3 16.3.6 Reset link single-use (invalidate after use)
- [ ] P3 16.3.7 Reset link rate limiting (3 per hour per email)
- [x] P3 16.3.8 Reset page: new password field
- [x] P3 16.3.9 Reset page: confirm password field
- [ ] P3 16.3.10 Reset page: password strength indicator
- [x] P3 16.3.11 Reset success: "password updated" message
- [ ] P3 16.3.12 Reset success: auto-login with new password
- [ ] P3 16.3.13 Reset success: notification email ("password changed")
- [x] P3 16.3.14 Reset success: invalidate all other sessions
- [x] P3 16.3.15 Reset failure: "invalid or expired link" message
- [x] P3 16.3.16 Reset failure: "try again" link
- [ ] P3 16.3.17 Reset analytics (request count, success rate)
- [ ] P3 16.3.18 Reset abuse detection (unusual patterns)
- [ ] P3 16.3.19 Reset IP logging (for security audit)
- [ ] P3 16.3.20 Reset email logging (delivery status)

### 16.4 Email Verification

- [x] P3 16.4.1 Verification email sent on registration
- [x] P3 16.4.2 Verification link in email (unique token)
- [x] P3 16.4.3 Verification link expiry (24 hours)
- [x] P3 16.4.4 Verification link single-use
- [x] P3 16.4.5 Verification page: "email verified" success
- [ ] P3 16.4.6 Verification page: "expired" with resend option
- [ ] P3 16.4.7 Resend verification (max 3 per day)
- [ ] P3 16.4.8 Unverified account limitations (cannot review)
- [ ] P3 16.4.9 Unverified account reminder (daily email for 3 days)
- [ ] P3 16.4.10 Email change re-verification (new email must verify)
- [ ] P3 16.4.11 Verification analytics (delivery rate, verification rate)
- [ ] P3 16.4.12 Verification bounce handling (invalid email detection)
- [ ] P3 16.4.13 Verification spam folder guidance
- [ ] P3 16.4.14 Verification alternative (SMS, if configured)
- [ ] P3 16.4.15 Verification admin override (manual verify)

### 16.5 Profile Management

- [x] P3 16.5.1 Display name field (max 50 characters)
- [x] P3 16.5.2 Username field (3-20 characters, alphanumeric + underscore)
- [x] P3 16.5.3 Username uniqueness check
- [ ] P3 16.5.4 Username change cooldown (30 days)
- [ ] P3 16.5.5 Avatar upload (JPG, PNG, GIF, max 5MB)
- [ ] P3 16.5.6 Avatar crop/resize (200x200px)
- [ ] P3 16.5.7 Avatar from URL (paste image URL)
- [ ] P3 16.5.8 Avatar removal (revert to default)
- [x] P3 16.5.9 Bio field (max 500 characters, markdown)
- [x] P3 16.5.10 Learning goals field (max 200 characters)
- [x] P3 16.5.11 Location field (optional, max 100 characters)
- [x] P3 16.5.12 Website field (URL validation)
- [x] P3 16.5.13 Social links (Twitter, GitHub, LinkedIn)
- [x] P3 16.5.14 Profile visibility toggle (public/private/anonymous)
- [x] P3 16.5.15 Profile permalink (/u/username)
- [ ] P3 16.5.16 Profile SEO (meta tags, Open Graph)
- [ ] P3 16.5.17 Profile statistics display (courses, hours, streak)
- [ ] P3 16.5.18 Profile badges display
- [ ] P3 16.5.19 Profile certificates display
- [ ] P3 16.5.20 Profile activity feed (recent learning activity)

### 16.6 Account Settings

- [ ] P3 16.6.1 Change email (requires password confirmation)
- [ ] P3 16.6.2 Change email verification (new email must verify)
- [x] P3 16.6.3 Change password (requires current password)
- [ ] P3 16.6.4 Change password notification email
- [ ] P3 16.6.5 Change username (requires password confirmation)
- [x] P3 16.6.6 Change display name
- [x] P3 16.6.7 Language preference dropdown
- [x] P3 16.6.8 Timezone selection dropdown
- [x] P3 16.6.9 Date format preference (MM/DD/YYYY, DD/MM/YYYY, YYYY-MM-DD)
- [x] P3 16.6.10 Theme preference (light/dark/system)
- [x] P3 16.6.11 Font size preference (small/medium/large)
- [x] P3 16.6.12 Notification preferences (per-channel toggles)
- [x] P3 16.6.13 Email notification toggle
- [x] P3 16.6.14 Push notification toggle
- [x] P3 16.6.15 In-app notification toggle

### 16.7 Learning Preferences

- [x] P3 16.7.1 Daily learning goal (minutes: 10, 15, 20, 30, 45, 60)
- [x] P3 16.7.2 Daily review goal (items: 5, 10, 20, 30, 50)
- [x] P3 16.7.3 Session length preference (10-60 minutes)
- [x] P3 16.7.4 Break reminder interval (15, 25, 45, 60 minutes)
- [x] P3 16.7.5 Preferred session time (morning/afternoon/evening/flexible)
- [ ] P3 16.7.6 Energy check-in toggle (enable/disable)
- [x] P3 16.7.7 Difficulty preference (easy/normal/hard/auto)
- [ ] P3 16.7.8 Interleaving preference (blocked/interleaved/auto)
- [ ] P3 16.7.9 Review scheduling preference (morning/evening/flexible)
- [x] P3 16.7.10 Show/hide streaks toggle
- [x] P3 16.7.11 Show/hide leaderboards toggle
- [x] P3 16.7.12 Show/hide achievements toggle
- [ ] P3 16.7.13 Auto-play audio toggle
- [ ] P3 16.7.14 Compact mode toggle
- [x] P3 16.7.15 Save preferences (auto-save on change)

### 16.8 Data Management

- [x] P3 16.8.1 Download all data (JSON export)
- [x] P3 16.8.2 Download review history (JSON, CSV)
- [x] P3 16.8.3 Download progress history (JSON, CSV)
- [ ] P3 16.8.4 Download learning analytics (JSON, CSV)
- [ ] P3 16.8.5 Download FSRS parameters (JSON)
- [x] P3 16.8.6 Delete specific data (per-course)
- [x] P3 16.8.7 Delete specific data (per-type: reviews, progress, analytics)
- [x] P3 16.8.8 Delete account (with confirmation)
- [x] P3 16.8.9 Delete account (requires password)
- [ ] P3 16.8.10 Delete account (30-day grace period)
- [ ] P3 16.8.11 Delete account cancellation (within 30 days)
- [x] P3 16.8.12 Account deactivation (temporary, self-serve)
- [x] P3 16.8.13 Account reactivation (login with old credentials)
- [ ] P3 16.8.14 Data portability (GDPR Article 20)
- [ ] P3 16.8.15 Data correction (GDPR Article 16)

### 16.9 Subscription & Billing

- [ ] P3 16.9.1 Subscription tier display (free/pro/team/enterprise)
- [ ] P3 16.9.2 Upgrade flow (plan comparison, checkout)
- [ ] P3 16.9.3 Downgrade flow (with proration)
- [ ] P3 16.9.4 Payment method management (add, remove, update)
- [ ] P3 16.9.5 Credit card input (Stripe Elements)
- [ ] P3 16.9.6 PayPal integration
- [ ] P3 16.9.7 Invoice history (list, download PDF)
- [ ] P3 16.9.8 Receipt download
- [ ] P3 16.9.9 Cancel subscription (with feedback survey)
- [ ] P3 16.9.10 Pause subscription (1-3 months)
- [ ] P3 16.9.11 Resume subscription
- [ ] P3 16.9.12 Refund request (within 30 days)
- [ ] P3 16.9.13 Usage tracking (courses accessed, reviews done)
- [ ] P3 16.9.14 Usage limits display (remaining quota)
- [ ] P3 16.9.15 Upgrade prompts (when hitting limits)

### 16.10 Security

- [x] P3 16.10.1 Login history (IP, device, timestamp)
- [ ] P3 16.10.2 Active devices list (with revoke option)
- [ ] P3 16.10.3 Revoke all sessions button
- [ ] P3 16.10.4 Security alerts (new login notification)
- [ ] P3 16.10.5 Security alerts (password change notification)
- [ ] P3 16.10.6 Security alerts (email change notification)
- [ ] P3 16.10.7 API key management (create, revoke)
- [ ] P3 16.10.8 Personal access tokens
- [ ] P3 16.10.9 Two-factor authentication setup
- [ ] P3 16.10.10 Two-factor authentication recovery codes
- [ ] P3 16.10.11 Two-factor authentication disable (requires password)
- [ ] P3 16.10.12 IP allowlisting (enterprise)
- [ ] P3 16.10.13 SSO configuration (enterprise)
- [ ] P3 16.10.14 Audit log access (all account actions)
- [ ] P3 16.10.15 Security contact email

---

## 17. Notification System

### 17.1 Email Notifications

- [ ] P3 17.1.1 Welcome email (on registration)
- [ ] P3 17.1.2 Email verification email
- [ ] P3 17.1.3 Password reset email
- [ ] P3 17.1.4 Password change confirmation email
- [ ] P3 17.1.5 Daily review reminder (configurable time)
- [ ] P3 17.1.6 Weekly progress summary email
- [ ] P3 17.1.7 Course update notification email
- [ ] P3 17.1.8 Achievement unlocked email
- [ ] P3 17.1.9 New course available email
- [ ] P3 17.1.10 Mentor message email
- [ ] P3 17.1.11 Community reply email
- [ ] P3 17.1.12 Subscription renewal reminder email
- [ ] P3 17.1.13 Subscription payment failed email
- [ ] P3 17.1.14 Inactivity reminder email (no sessions in 7 days)
- [ ] P3 17.1.15 Email delivery tracking (sent, delivered, opened)

### 17.2 Push Notifications

- [ ] P3 17.2.1 Browser push notifications (Web Push API)
- [ ] P3 17.2.2 Review reminders (configurable time)
- [ ] P3 17.2.3 Achievement unlocked notification
- [ ] P3 17.2.4 Streak milestone notification
- [ ] P3 17.2.5 Course update notification
- [ ] P3 17.2.6 New comment notification
- [ ] P3 17.2.7 Daily summary notification
- [ ] P3 17.2.8 Weekly summary notification
- [ ] P3 17.2.9 Custom scheduling (user sets times)
- [ ] P3 17.2.10 Quiet hours (no notifications during set hours)
- [ ] P3 17.2.11 Notification sound toggle
- [ ] P3 17.2.12 Notification vibration toggle
- [ ] P3 17.2.13 Notification badge count
- [ ] P3 17.2.14 Notification action buttons (review now, dismiss)
- [ ] P3 17.2.15 Notification deep linking (open specific page)

### 17.3 In-App Notifications

- [ ] P3 17.3.1 Notification center (bell icon in header)
- [ ] P3 17.3.2 Unread count badge
- [ ] P3 17.3.3 Notification categories (learning, social, system)
- [ ] P3 17.3.4 Mark as read/unread
- [ ] P3 17.3.5 Mark all as read
- [ ] P3 17.3.6 Delete notifications
- [ ] P3 17.3.7 Notification preferences link
- [ ] P3 17.3.8 Notification sound toggle
- [ ] P3 17.3.9 Notification preview (title + body)
- [ ] P3 17.3.10 Notification links (deep link to content)
- [ ] P3 17.3.11 Notification timestamp
- [ ] P3 17.3.12 Notification grouping (by type)
- [ ] P3 17.3.13 Notification pagination (load more)
- [ ] P3 17.3.14 Notification real-time updates (WebSocket)
- [ ] P3 17.3.15 Notification export (download all)

### 17.4 Notification Preferences

- [ ] P3 17.4.1 Per-channel toggle (email/push/in-app)
- [ ] P3 17.4.2 Per-category toggle (learning/social/system)
- [ ] P3 17.4.3 Per-course toggle
- [ ] P3 17.4.4 Quiet hours (no notifications during set hours)
- [ ] P3 17.4.5 Frequency preference (instant/daily/weekly)
- [ ] P3 17.4.6 Digest mode (batch notifications)
- [ ] P3 17.4.7 Unsubscribe all
- [ ] P3 17.4.8 Re-subscribe
- [ ] P3 17.4.9 Preference sync across devices
- [ ] P3 17.4.10 Preference export

### 17.5 Notification Analytics

- [ ] P3 17.5.1 Open rate tracking (email)
- [ ] P3 17.5.2 Click rate tracking (email)
- [ ] P3 17.5.3 Unsubscribe rate
- [ ] P3 17.5.4 Best send time analysis
- [ ] P3 17.5.5 A/B testing subject lines
- [ ] P3 17.5.6 Notification fatigue detection
- [ ] P3 17.5.7 Engagement correlation (notification vs activity)
- [ ] P3 17.5.8 Opt-out reason tracking
- [ ] P3 17.5.9 Win-back campaigns (re-engage inactive)
- [ ] P3 17.5.10 Notification effectiveness scoring

---

## 18. Payment & Monetization

### 18.1 Pricing Tiers

- [ ] P3 18.1.1 Free tier (limited courses, basic features)
- [ ] P3 18.1.2 Pro tier ($15/month: all courses, all features)
- [ ] P3 18.1.3 Team tier ($10/seat/month: multi-seat, admin dashboard)
- [ ] P3 18.1.4 Enterprise tier (custom pricing: SSO, custom content, support)
- [ ] P3 18.1.5 Student discount (50% off with .edu email)
- [ ] P3 18.1.6 Educator discount (free for verified educators)
- [ ] P3 18.1.7 Non-profit discount (40% off)
- [ ] P3 18.1.8 Regional pricing (PPP adjustment)
- [ ] P3 18.1.9 Annual vs monthly billing (20% discount for annual)
- [ ] P3 18.1.10 Lifetime access option (one-time payment)

### 18.2 Payment Processing

- [ ] P3 18.2.1 Stripe integration (credit/debit card)
- [ ] P3 18.2.2 PayPal integration
- [ ] P3 18.2.3 Apple Pay integration
- [ ] P3 18.2.4 Google Pay integration
- [ ] P3 18.2.5 SEPA direct debit (Europe)
- [ ] P3 18.2.6 iDEAL (Netherlands)
- [ ] P3 18.2.7 Alipay (China)
- [ ] P3 18.2.8 Bank transfer (enterprise)
- [ ] P3 18.2.9 Invoice payment (enterprise, net-30)
- [ ] P3 18.2.10 Cryptocurrency (Bitcoin, Ethereum)

### 18.3 Subscription Management

- [ ] P3 18.3.1 Plan comparison page (feature matrix)
- [ ] P3 18.3.2 Upgrade with proration (credit remaining time)
- [ ] P3 18.3.3 Downgrade with credit (apply to next billing)
- [ ] P3 18.3.4 Cancel with feedback survey
- [ ] P3 18.3.5 Pause subscription (1-3 months)
- [ ] P3 18.3.6 Gift subscription (1, 3, 6, 12 months)
- [ ] P3 18.3.7 Team seats management (add, remove, invite)
- [ ] P3 18.3.8 Volume discounts (10+ seats: 15% off, 50+ seats: 25% off)
- [ ] P3 18.3.9 Custom enterprise pricing (sales contact)
- [ ] P3 18.3.10 Price lock for existing users (no price increases)

### 18.4 Course Purchases

- [ ] P3 18.4.1 Individual course purchase ($5-$50 per course)
- [ ] P3 18.4.2 Course bundles (3+ courses, 20% discount)
- [ ] P3 18.4.3 Course subscriptions (monthly access to catalog)
- [ ] P3 18.4.4 Course pre-orders (early access, discounted)
- [ ] P3 18.4.5 Course gift cards (redeemable codes)
- [ ] P3 18.4.6 Course referral credits ($5 per referral)
- [ ] P3 18.4.7 Course waitlist (notify when available)
- [ ] P3 18.4.8 Course beta access (early access for feedback)
- [ ] P3 18.4.9 Course early bird pricing (first 100 buyers)
- [ ] P3 18.4.10 Course loyalty discounts (returning customers)

### 18.5 Revenue Analytics

- [ ] P3 18.5.1 Revenue dashboard (MRR, ARR, churn)
- [ ] P3 18.5.2 MRR (Monthly Recurring Revenue) tracking
- [ ] P3 18.5.3 ARR (Annual Recurring Revenue) tracking
- [ ] P3 18.5.4 Churn rate calculation (monthly, quarterly)
- [ ] P3 18.5.5 LTV (Lifetime Value) calculation
- [ ] P3 18.5.6 CAC (Customer Acquisition Cost) calculation
- [ ] P3 18.5.7 Revenue by course (which courses earn most)
- [ ] P3 18.5.8 Revenue by region (geographic breakdown)
- [ ] P3 18.5.9 Revenue by cohort (sign-up month comparison)
- [ ] P3 18.5.10 Revenue forecast (predict future revenue)

### 18.6 Promotions

- [ ] P3 18.6.1 Discount codes (percentage, fixed amount)
- [ ] P3 18.6.2 Coupon generation (bulk, unique codes)
- [ ] P3 18.6.3 Volume discounts (buy 2 get 1 free)
- [ ] P3 18.6.4 Seasonal sales (Black Friday, Back to School)
- [ ] P3 18.6.5 Flash sales (24-hour limited offers)
- [ ] P3 18.6.6 Referral bonuses (give $5, get $5)
- [ ] P3 18.6.7 Loyalty rewards (earn credits for referrals)
- [ ] P3 18.6.8 Early access pricing (beta testers)
- [ ] P3 18.6.9 Bundle pricing (course + mentoring)
- [ ] P3 18.6.10 A/B test pricing (test different price points)

---

## 19. Gamification & Motivation

### 19.1 Streaks

- [ ] P3 19.1.1 Daily streak counter (consecutive days with activity)
- [ ] P3 19.1.2 Weekly streak counter (consecutive weeks)
- [ ] P3 19.1.3 Monthly streak counter (consecutive months)
- [ ] P3 19.1.4 Streak freeze (protect streak, max 3 per month)
- [ ] P3 19.1.5 Streak recovery (reconnect after break, 1 free recovery)
- [ ] P3 19.1.6 Streak milestones (7, 30, 100, 365 days)
- [ ] P3 19.1.7 Streak sharing (share on social media)
- [ ] P3 19.1.8 Streak leaderboards (opt-in)
- [ ] P3 19.1.9 Streak analytics (consistency patterns)
- [ ] P3 19.1.10 Streak customization (what counts: review, learn, exercise)

### 19.2 Experience Points (XP)

- [ ] P3 19.2.1 XP for completing concepts (10 XP)
- [ ] P3 19.2.2 XP for exercise completion (5 XP per exercise)
- [ ] P3 19.2.3 XP for review sessions (2 XP per item reviewed)
- [ ] P3 19.2.4 XP for streaks (bonus XP at milestones)
- [ ] P3 19.2.5 XP for community contributions (10-50 XP)
- [ ] P3 19.2.6 XP multiplier (perfect score: 2x, speed bonus: 1.5x)
- [ ] P3 19.2.7 XP leaderboard (global, weekly, monthly)
- [ ] P3 19.2.8 XP level system (1-100, XP thresholds per level)
- [ ] P3 19.2.9 XP milestones (every 1000 XP)
- [ ] P3 19.2.10 XP history (track all XP earnings)

### 19.3 Badges & Achievements

- [ ] P3 19.3.1 Badge categories (learning, social, mastery)
- [ ] P3 19.3.2 Badge rarity (common, uncommon, rare, epic, legendary)
- [ ] P3 19.3.3 Badge progress tracking (how close to earning)
- [ ] P3 19.3.4 Badge showcase (display on profile, max 6)
- [ ] P3 19.3.5 Achievement notifications (on earn)
- [ ] P3 19.3.6 Achievement comparison (see friends' badges)
- [ ] P3 19.3.7 Achievement guides (how to earn)
- [ ] P3 19.3.8 Achievement unlock dates
- [ ] P3 19.3.9 Achievement statistics (global earn rate)
- [ ] P3 19.3.10 Achievement custom (course-specific badges)

### 19.4 Leaderboards

- [ ] P3 19.4.1 Global leaderboard (XP, opt-in)
- [ ] P3 19.4.2 Course leaderboard (per course)
- [ ] P3 19.4.3 Module leaderboard (per module)
- [ ] P3 19.4.4 Weekly leaderboard (resets every Monday)
- [ ] P3 19.4.5 Monthly leaderboard (resets every 1st)
- [ ] P3 19.4.6 All-time leaderboard
- [ ] P3 19.4.7 Opt-in leaderboards (must choose to participate)
- [ ] P3 19.4.8 Anonymous leaderboards (hide names)
- [ ] P3 19.4.9 Team leaderboards (compete as groups)
- [ ] P3 19.4.10 Leaderboard history (past results)

### 19.5 Challenges

- [ ] P3 19.5.1 Daily challenges (3 per day, varying difficulty)
- [ ] P3 19.5.2 Weekly challenges (1 per week, harder)
- [ ] P3 19.5.3 Monthly challenges (1 per month, hardest)
- [ ] P3 19.5.4 Course challenges (per-course challenges)
- [ ] P3 19.5.5 Community challenges (everyone works toward goal)
- [ ] P3 19.5.6 Challenge rewards (XP, badges)
- [ ] P3 19.5.7 Challenge progress (track completion)
- [ ] P3 19.5.8 Challenge leaderboards (fastest completion)
- [ ] P3 19.5.9 Challenge completion (celebration animation)
- [ ] P3 19.5.10 Challenge history (past challenges)

### 19.6 Levels & Progression

- [ ] P3 19.6.1 Level system (1-100, XP thresholds)
- [ ] P3 19.6.2 Level-up notifications (animation + message)
- [ ] P3 19.6.3 Level rewards (unlock features, badges)
- [ ] P3 19.6.4 Level milestones (every 10 levels)
- [ ] P3 19.6.5 Level badges (display level on profile)
- [ ] P3 19.6.6 Level requirements (XP thresholds per level)
- [ ] P3 19.6.7 Level history (track level progression)
- [ ] P3 19.6.8 Level comparison (see friends' levels)
- [ ] P3 19.6.9 Level customization (choose title at milestones)
- [ ] P3 19.6.10 Level prestige system (reset for special rewards)

### 19.7 Motivation Design

- [ ] P3 19.7.1 Motivational messages (context-aware, based on performance)
- [ ] P3 19.7.2 Progress celebrations (animation on milestone)
- [ ] P3 19.7.3 Milestone celebrations (confetti on course completion)
- [ ] P3 19.7.4 Encouragement after failure ("keep trying!")
- [ ] P3 19.7.5 Rest reminders ("you have been learning for 30 minutes")
- [ ] P3 19.7.6 Energy check-ins ("how are you feeling?")
- [ ] P3 19.7.7 Positive reinforcement ("great job on that exercise!")
- [ ] P3 19.7.8 No shame design (missing a day is normal)
- [ ] P3 19.7.9 Flexibility emphasis (learn at your own pace)
- [ ] P3 19.7.10 Personal growth focus (compare to yourself, not others)

---

## 20. Certification & Credentials

### 20.1 Course Certificates

- [ ] P3 20.1.1 Certificate of completion (generated on course finish)
- [ ] P3 20.1.2 Certificate with score (shows final score)
- [ ] P3 20.1.3 Certificate with time (shows total time spent)
- [ ] P3 20.1.4 Certificate with badge (shows earned badge)
- [ ] P3 20.1.5 PDF certificate export (downloadable)
- [ ] P3 20.1.6 Certificate verification URL (public link)
- [ ] P3 20.1.7 Certificate share (LinkedIn, Twitter)
- [ ] P3 20.1.8 Certificate template design (professional layout)
- [ ] P3 20.1.9 Certificate numbering (unique ID per certificate)
- [ ] P3 20.1.10 Certificate expiration (optional, configurable)

### 20.2 Skill Certifications

- [ ] P3 20.2.1 Skill assessment tests (proctored, timed)
- [ ] P3 20.2.2 Skill level certification (beginner, intermediate, advanced, expert)
- [ ] P3 20.2.3 Skill verification (AI-graded, human-reviewed)
- [ ] P3 20.2.4 Skill badge (display on profile)
- [ ] P3 20.2.5 Skill portfolio (collection of certifications)
- [ ] P3 20.2.6 Skill comparison (vs industry benchmarks)
- [ ] P3 20.2.7 Skill recommendations (what to learn next)
- [ ] P3 20.2.8 Skill gap analysis (what is missing)
- [ ] P3 20.2.9 Skill trending (in-demand skills)
- [ ] P3 20.2.10 Skill endorsements (peer endorsements)

### 20.3 Learning Paths

- [ ] P3 20.3.1 Predefined learning paths (curated by experts)
- [ ] P3 20.3.2 Custom learning paths (user-created)
- [ ] P3 20.3.3 Path progress tracking (per path)
- [ ] P3 20.3.4 Path completion certificates
- [ ] P3 20.3.5 Path prerequisites (required courses)
- [ ] P3 20.3.6 Path recommendations (AI-suggested)
- [ ] P3 20.3.7 Path sharing (share with others)
- [ ] P3 20.3.8 Path rating (user reviews)
- [ ] P3 20.3.9 Path analytics (completion rate, time)
- [ ] P3 20.3.10 Path updates (new courses added)

### 20.4 Credential Verification

- [ ] P3 20.4.1 Public verification URL (verify a certificate)
- [ ] P3 20.4.2 QR code verification (scan to verify)
- [ ] P3 20.4.3 API verification (programmatic verification)
- [ ] P3 20.4.4 Blockchain verification (immutable proof)
- [ ] P3 20.4.5 Employer verification (employer portal)
- [ ] P3 20.4.6 Education institution recognition
- [ ] P3 20.4.7 Continuing education credits (CEU)
- [ ] P3 20.4.8 Professional development hours (PDH)
- [ ] P3 20.4.9 Credential expiration tracking
- [ ] P3 20.4.10 Credential renewal reminders

### 20.5 Portfolio

- [ ] P3 20.5.1 Learning portfolio page (public profile)
- [ ] P3 20.5.2 Course completions (list with certificates)
- [ ] P3 20.5.3 Skills acquired (with levels)
- [ ] P3 20.5.4 Projects completed (with links)
- [ ] P3 20.5.5 Certificates earned (with verification)
- [ ] P3 20.5.6 Contribution history (exercises, explanations)
- [ ] P3 20.5.7 Portfolio sharing (public URL)
- [ ] P3 20.5.8 Portfolio PDF export (downloadable)
- [ ] P3 20.5.9 Portfolio customization (layout, theme)
- [ ] P3 20.5.10 Portfolio analytics (views, downloads)

---

## 21. Internationalization

### 21.1 Content Translation

- [ ] P3 21.1.1 Course translation framework (per-concept translation)
- [ ] P3 21.1.2 Translation management system (workflow)
- [ ] P3 21.1.3 Translator contribution tools (side-by-side editor)
- [ ] P3 21.1.4 Translation quality review (peer review)
- [ ] P3 21.1.5 Translation memory (reuse previous translations)
- [ ] P3 21.1.6 Translation glossary (consistent terminology)
- [ ] P3 21.1.7 Translation progress tracking (% complete)
- [ ] P3 21.1.8 Translation versioning (track changes)
- [ ] P3 21.1.9 Translation testing (render in target language)
- [ ] P3 21.1.10 Translation analytics (coverage, quality)

### 21.2 UI Localization

- [ ] P3 21.2.1 UI string externalization (all strings in files)
- [ ] P3 21.2.2 Translation files per language (JSON, YAML)
- [ ] P3 21.2.3 RTL (right-to-left) support (Arabic, Hebrew)
- [ ] P3 21.2.4 Language selector (dropdown in settings)
- [ ] P3 21.2.5 Language detection (browser preference)
- [ ] P3 21.2.6 Language persistence (save preference)
- [ ] P3 21.2.7 Fallback languages (fall back to English)
- [ ] P3 21.2.8 Date/time formatting (per locale)
- [ ] P3 21.2.9 Number formatting (per locale)
- [ ] P3 21.2.10 Currency formatting (per locale)

### 21.3 Regional Adaptation

- [ ] P3 21.3.1 Regional pricing (PPP adjustment)
- [ ] P3 21.3.2 Regional content recommendations
- [ ] P3 21.3.3 Regional holidays/events
- [ ] P3 21.3.4 Regional timezone support
- [ ] P3 21.3.5 Regional regulations (GDPR, CCPA)
- [ ] P3 21.3.6 Regional payment methods
- [ ] P3 21.3.7 Regional content restrictions
- [ ] P3 21.3.8 Regional cultural adaptation
- [ ] P3 21.3.9 Regional accessibility requirements
- [ ] P3 21.3.10 Regional legal requirements

### 21.4 Multilingual Support

- [ ] P3 21.4.1 Multi-language courses (same concept, multiple languages)
- [ ] P3 21.4.2 Language switching mid-course
- [ ] P3 21.4.3 Subtitles for video content
- [ ] P3 21.4.4 Audio descriptions
- [ ] P3 21.4.5 Sign language interpretation
- [ ] P3 21.4.6 Text-to-speech per language
- [ ] P3 21.4.7 Voice input per language
- [ ] P3 21.4.8 Keyboard input per language
- [ ] P3 21.4.9 Font support per language
- [ ] P3 21.4.10 Character encoding support (UTF-8)

---

## 22. AI & Machine Learning

### 22.1 AI-Powered Learning

- [ ] P3 22.1.1 Adaptive difficulty (ML model predicts optimal difficulty)
- [ ] P3 22.1.2 Personalized learning paths (AI recommends next concept)
- [ ] P3 22.1.3 Optimal review scheduling (ML-enhanced FSRS)
- [ ] P3 22.1.4 Knowledge gap prediction (predict what learner will struggle with)
- [ ] P3 22.1.5 Learning velocity prediction (estimate time to mastery)
- [ ] P3 22.1.6 Dropout risk prediction (flag at-risk learners)
- [ ] P3 22.1.7 Content recommendation ("learners like you also liked...")
- [ ] P3 22.1.8 Exercise recommendation (targeted practice)
- [ ] P3 22.1.9 Study time optimization (when to study)
- [ ] P3 22.1.10 Learning style detection (visual, textual, kinesthetic)

### 22.2 AI Content Generation

- [ ] P3 22.2.1 Exercise generation (template-based)
- [ ] P3 22.2.2 Exercise generation (ML-based, GPT-powered)
- [ ] P3 22.2.3 Review item generation (auto-generate from content)
- [ ] P3 22.2.4 Explanation generation (AI explains concepts)
- [ ] P3 22.2.5 Hint generation (AI creates progressive hints)
- [ ] P3 22.2.6 Example generation (AI creates examples)
- [ ] P3 22.2.7 Quiz generation (AI creates quizzes)
- [ ] P3 22.2.8 Summary generation (AI summarizes concepts)
- [ ] P3 22.2.9 Translation assistance (AI translates content)
- [ ] P3 22.2.10 Content quality scoring (AI grades content)

### 22.3 AI Tutoring

- [ ] P3 22.3.1 Natural language Q&A (ask questions about concepts)
- [ ] P3 22.3.2 Concept explanation (AI explains in simple terms)
- [ ] P3 22.3.3 Code review assistance (AI reviews code exercises)
- [ ] P3 22.3.4 Debugging assistance (AI helps find bugs)
- [ ] P3 22.3.5 Study planning (AI creates study schedule)
- [ ] P3 22.3.6 Progress analysis (AI analyzes learning patterns)
- [ ] P3 22.3.7 Weakness identification (AI finds knowledge gaps)
- [ ] P3 22.3.8 Motivation coaching (AI encourages and motivates)
- [ ] P3 22.3.9 Concept connection suggestions ("this relates to...")
- [ ] P3 22.3.10 Real-world example suggestions

### 22.4 AI Analytics

- [ ] P3 22.4.1 Learning pattern analysis (ML finds patterns)
- [ ] P3 22.4.2 Content effectiveness analysis (which content works best)
- [ ] P3 22.4.3 Exercise difficulty calibration (ML adjusts difficulty)
- [ ] P3 22.4.4 Concept prerequisite validation (AI checks prerequisites)
- [ ] P3 22.4.5 Course quality scoring (AI grades courses)
- [ ] P3 22.4.6 Learner segmentation (group learners by behavior)
- [ ] P3 22.4.7 Cohort analysis (compare groups)
- [ ] P3 22.4.8 Predictive analytics (forecast outcomes)
- [ ] P3 22.4.9 Anomaly detection (detect unusual behavior)
- [ ] P3 22.4.10 Trend analysis (identify trends)

### 22.5 AI Content Quality

- [ ] P3 22.5.1 Fact verification (check facts against sources)
- [ ] P3 22.5.2 Citation verification (check citations exist)
- [ ] P3 22.5.3 Code correctness checking (verify code compiles/runs)
- [ ] P3 22.5.4 Exercise solvability checking (verify exercises can be solved)
- [ ] P3 22.5.5 Explanation clarity scoring (grade explanation quality)
- [ ] P3 22.5.6 Accessibility scoring (grade accessibility)
- [ ] P3 22.5.7 Bias detection (detect biased content)
- [ ] P3 22.5.8 Plagiarism detection (detect copied content)
- [ ] P3 22.5.9 Originality scoring (grade originality)
- [ ] P3 22.5.10 Quality improvement suggestions (AI suggests improvements)

---

## 23. Enterprise Features

### 23.1 Team Management

- [ ] P3 23.1.1 Team creation (admin creates team)
- [ ] P3 23.1.2 Team roles (admin, instructor, member)
- [ ] P3 23.1.3 Team invitations (email, shareable link)
- [ ] P3 23.1.4 Bulk user import (CSV upload)
- [ ] P3 23.1.5 Team permissions (per role, per course)
- [ ] P3 23.1.6 Team analytics (progress, completion, engagement)
- [ ] P3 23.1.7 Team billing (centralized billing)
- [ ] P3 23.1.8 Team settings (name, description, logo)
- [ ] P3 23.1.9 Team branding (custom logo, colors)
- [ ] P3 23.1.10 Team support (dedicated support channel)

### 23.2 Enterprise SSO

- [ ] P3 23.2.1 SAML 2.0 integration
- [ ] P3 23.2.2 OIDC integration
- [ ] P3 23.2.3 LDAP integration
- [ ] P3 23.2.4 Active Directory integration
- [ ] P3 23.2.5 Google Workspace integration
- [ ] P3 23.2.6 Azure AD integration
- [ ] P3 23.2.7 Okta integration
- [ ] P3 23.2.8 Custom SSO (SAML/OIDC)
- [ ] P3 23.2.9 Just-in-time provisioning (auto-create accounts)
- [ ] P3 23.2.10 SCIM provisioning (automatic user sync)

### 23.3 Enterprise Content

- [ ] P3 23.3.1 Custom course creation (enterprise-only courses)
- [ ] P3 23.3.2 Course import (SCORM, xAPI, LTI)
- [ ] P3 23.3.3 Course authoring tools (enterprise-grade)
- [ ] P3 23.3.4 Content library (shared across teams)
- [ ] P3 23.3.5 Content permissions (per team, per role)
- [ ] P3 23.3.6 Content versioning (enterprise versioning)
- [ ] P3 23.3.7 Content analytics (enterprise analytics)
- [ ] P3 23.3.8 Content compliance (regulatory compliance)
- [ ] P3 23.3.9 Content approval workflows (multi-level approval)
- [ ] P3 23.3.10 Content localization (enterprise i18n)

### 23.4 Enterprise Analytics

- [ ] P3 23.4.1 Team progress dashboards (real-time)
- [ ] P3 23.4.2 Individual progress reports (per learner)
- [ ] P3 23.4.3 Skill gap analysis (per team, per individual)
- [ ] P3 23.4.4 Compliance training tracking (mandatory training)
- [ ] P3 23.4.5 ROI measurement (training investment return)
- [ ] P3 23.4.6 Cost per learner (total cost / active learners)
- [ ] P3 23.4.7 Time to competency (how fast learners reach proficiency)
- [ ] P3 23.4.8 Training effectiveness (pre/post assessment)
- [ ] P3 23.4.9 Custom reports (build your own reports)
- [ ] P3 23.4.10 API analytics (API usage tracking)

### 23.5 Enterprise Compliance

- [ ] P3 23.5.1 Training compliance tracking (mandatory training)
- [ ] P3 23.5.2 Certification management (track certifications)
- [ ] P3 23.5.3 Expiration reminders (renewal notifications)
- [ ] P3 23.5.4 Audit trails (all actions logged)
- [ ] P3 23.5.5 Data residency (choose data location)
- [ ] P3 23.5.6 Data processing agreements (DPA)
- [ ] P3 23.5.7 SOC 2 compliance
- [ ] P3 23.5.8 ISO 27001 compliance
- [ ] P3 23.5.9 Custom SLAs (uptime, support response)
- [ ] P3 23.5.10 Dedicated support (priority support channel)

### 23.6 Enterprise Integration

- [ ] P3 23.6.1 LMS integration (LTI 1.3)
- [ ] P3 23.6.2 HRIS integration (workday, bambooHR)
- [ ] P3 23.6.3 SCIM provisioning (automatic user sync)
- [ ] P3 23.6.4 Webhook events (custom integrations)
- [ ] P3 23.6.5 Custom integrations (API-based)
- [ ] P3 23.6.6 API access (full API access)
- [ ] P3 23.6.7 SFTP access (bulk data transfer)
- [ ] P3 23.6.8 Custom data export (scheduled exports)
- [ ] P3 23.6.9 Dedicated instance (isolated deployment)
- [ ] P3 23.6.10 On-premise deployment (self-hosted)

---

## 24. Content Management System

### 24.1 Course Editor

- [ ] P3 24.1.1 Visual course editor (WYSIWYG)
- [ ] P3 24.1.2 Markdown editor with preview
- [ ] P3 24.1.3 Code editor with syntax highlighting
- [ ] P3 24.1.4 Drag-and-drop content organization
- [ ] P3 24.1.5 Concept reordering (within module)
- [ ] P3 24.1.6 Module management (add, remove, reorder)
- [ ] P3 24.1.7 Prerequisite management (visual graph)
- [ ] P3 24.1.8 Asset management (upload, organize, preview)
- [ ] P3 24.1.9 Version control (git-like history)
- [ ] P3 24.1.10 Collaboration (multi-author, comments)

### 24.2 Content Pipeline

- [ ] P3 24.2.1 Draft -> Review -> Published workflow
- [ ] P3 24.2.2 Content review queue (pending reviews)
- [ ] P3 24.2.3 Reviewer assignment (assign reviewers)
- [ ] P3 24.2.4 Review comments (inline comments)
- [ ] P3 24.2.5 Change requests (request changes)
- [ ] P3 24.2.6 Approval workflow (multi-level approval)
- [ ] P3 24.2.7 Scheduled publishing (publish at specific time)
- [ ] P3 24.2.8 Unpublishing (remove from public)
- [ ] P3 24.2.9 Content archival (hide without deleting)
- [ ] P3 24.2.10 Content restoration (restore archived content)

### 24.3 Content Quality

- [ ] P3 24.3.1 Linting (style, grammar, spelling)
- [ ] P3 24.3.2 Fact checking (verify against sources)
- [ ] P3 24.3.3 Link validation (check all links)
- [ ] P3 24.3.4 Image optimization (compress, resize)
- [ ] P3 24.3.5 Accessibility checking (WCAG compliance)
- [ ] P3 24.3.6 SEO optimization (meta tags, keywords)
- [ ] P3 24.3.7 Performance checking (load time)
- [ ] P3 24.3.8 Mobile responsiveness checking
- [ ] P3 24.3.9 Cross-browser testing
- [ ] P3 24.3.10 Content scoring (overall quality score)

### 24.4 Content Analytics

- [ ] P3 24.4.1 View tracking (page views, unique viewers)
- [ ] P3 24.4.2 Engagement tracking (time on page, interactions)
- [ ] P3 24.4.3 Completion tracking (who completed what)
- [ ] P3 24.4.4 Rating tracking (user ratings)
- [ ] P3 24.4.5 Feedback collection (user comments)
- [ ] P3 24.4.6 A/B testing (test content variants)
- [ ] P3 24.4.7 Heatmaps (where users click)
- [ ] P3 24.4.8 Scroll depth (how far users scroll)
- [ ] P3 24.4.9 Time on page (how long users spend)
- [ ] P3 24.4.10 Drop-off points (where users leave)

### 24.5 Content Versioning

- [ ] P3 24.5.1 Version history (all changes tracked)
- [ ] P3 24.5.2 Version comparison (diff view)
- [ ] P3 24.5.3 Version rollback (revert to previous)
- [ ] P3 24.5.4 Version tagging (mark versions: v1.0, v1.1)
- [ ] P3 24.5.5 Version notes (changelog per version)
- [ ] P3 24.5.6 Version publishing (publish specific version)
- [ ] P3 24.5.7 Version scheduling (schedule version release)
- [ ] P3 24.5.8 Version analytics (performance per version)
- [ ] P3 24.5.9 Version migration (update to new version)
- [ ] P3 24.5.10 Version cleanup (remove old versions)

---

## 25. Data Pipeline & Warehouse

### 25.1 Event Tracking

- [ ] P3 25.1.1 Page view events (URL, timestamp, user)
- [ ] P3 25.1.2 Interaction events (click, scroll, input)
- [ ] P3 25.1.3 Learning events (start concept, complete concept)
- [ ] P3 25.1.4 Exercise events (attempt, correct, incorrect)
- [ ] P3 25.1.5 Review events (start review, submit answer)
- [ ] P3 25.1.6 Social events (follow, comment, share)
- [ ] P3 25.1.7 Commerce events (purchase, upgrade, cancel)
- [ ] P3 25.1.8 System events (error, performance, deploy)
- [ ] P3 25.1.9 Custom events (user-defined)
- [ ] P3 25.1.10 Event validation (schema enforcement)

### 25.2 Data Collection

- [ ] P3 25.2.1 Client-side tracking (browser events)
- [ ] P3 25.2.2 Server-side tracking (API events)
- [ ] P3 25.2.3 Event stream processing (real-time)
- [ ] P3 25.2.4 Data validation (clean, consistent data)
- [ ] P3 25.2.5 Data deduplication (remove duplicates)
- [ ] P3 25.2.6 Data enrichment (add context)
- [ ] P3 25.2.7 Data anonymization (privacy protection)
- [ ] P3 25.2.8 Data retention (auto-delete old data)
- [ ] P3 25.2.9 Data archival (move to cold storage)
- [ ] P3 25.2.10 Data export (to external systems)

### 25.3 Data Warehouse

- [ ] P3 25.3.1 Schema design (star schema, snowflake)
- [ ] P3 25.3.2 ETL pipeline (extract, transform, load)
- [ ] P3 25.3.3 Data modeling (dimensional modeling)
- [ ] P3 25.3.4 Data indexing (fast queries)
- [ ] P3 25.3.5 Data partitioning (by date, region)
- [ ] P3 25.3.6 Data compression (reduce storage)
- [ ] P3 25.3.7 Data backup (daily snapshots)
- [ ] P3 25.3.8 Data restore (point-in-time recovery)
- [ ] P3 25.3.9 Data replication (real-time sync)
- [ ] P3 25.3.10 Data governance (quality, lineage, access)

### 25.4 Analytics & Reporting

- [ ] P3 25.4.1 Real-time dashboards (live metrics)
- [ ] P3 25.4.2 Scheduled reports (daily, weekly, monthly)
- [ ] P3 25.4.3 Ad-hoc queries (SQL editor)
- [ ] P3 25.4.4 Cohort analysis (group comparison)
- [ ] P3 25.4.5 Funnel analysis (conversion funnels)
- [ ] P3 25.4.6 Retention analysis (return rates)
- [ ] P3 25.4.7 Revenue analytics (MRR, churn, LTV)
- [ ] P3 25.4.8 Learning analytics (completion, engagement)
- [ ] P3 25.4.9 Content analytics (views, time, completion)
- [ ] P3 25.4.10 Custom reports (build your own)

### 25.5 Data Quality

- [ ] P3 25.5.1 Data validation rules (schema, range, format)
- [ ] P3 25.5.2 Data completeness checks (no missing fields)
- [ ] P3 25.5.3 Data accuracy checks (correct values)
- [ ] P3 25.5.4 Data consistency checks (cross-field consistency)
- [ ] P3 25.5.5 Data freshness checks (recent data)
- [ ] P3 25.5.6 Data anomaly detection (unusual patterns)
- [ ] P3 25.5.7 Data quality scoring (overall quality metric)
- [ ] P3 25.5.8 Data quality alerts (on quality drop)
- [ ] P3 25.5.9 Data quality dashboards (visualize quality)
- [ ] P3 25.5.10 Data quality remediation (fix issues)

---

## 26. Observability & Monitoring

### 26.1 Logging

- [ ] P3 26.1.1 Structured logging (JSON format)
- [ ] P3 26.1.2 Log levels (debug, info, warn, error, fatal)
- [ ] P3 26.1.3 Request/response logging (HTTP logs)
- [ ] P3 26.1.4 Error logging with stack traces
- [ ] P3 26.1.5 Performance logging (timing, latency)
- [ ] P3 26.1.6 Audit logging (all user actions)
- [ ] P3 26.1.7 Security logging (login, failed attempts)
- [ ] P3 26.1.8 Business logging (purchases, completions)
- [ ] P3 26.1.9 Log aggregation (centralized logging)
- [ ] P3 26.1.10 Log retention (30 days default, configurable)

### 26.2 Metrics

- [ ] P3 26.2.1 Request rate (requests per second)
- [ ] P3 26.2.2 Response time (p50, p95, p99)
- [ ] P3 26.2.3 Error rate (errors per total requests)
- [ ] P3 26.2.4 CPU usage (per server, aggregate)
- [ ] P3 26.2.5 Memory usage (per server, aggregate)
- [ ] P3 26.2.6 Disk usage (per server, aggregate)
- [ ] P3 26.2.7 Network usage (bandwidth, connections)
- [ ] P3 26.2.8 Database connections (active, idle, waiting)
- [ ] P3 26.2.9 Cache hit rate (Redis, CDN)
- [ ] P3 26.2.10 Queue depth (pending jobs)

### 26.3 Distributed Tracing

- [ ] P3 26.3.1 Trace propagation (request through services)
- [ ] P3 26.3.2 Span creation (per operation)
- [ ] P3 26.3.3 Span context (trace ID, span ID)
- [ ] P3 26.3.4 Trace sampling (head-based, tail-based)
- [ ] P3 26.3.5 Trace storage (Jaeger, Zipkin)
- [ ] P3 26.3.6 Trace visualization (flame graph, timeline)
- [ ] P3 26.3.7 Trace search (by trace ID, service, operation)
- [ ] P3 26.3.8 Trace analytics (latency breakdown)
- [ ] P3 26.3.9 Trace alerting (on slow traces)
- [ ] P3 26.3.10 Trace export (to external systems)

### 26.4 Alerting

- [ ] P3 26.4.1 Alert rules (define conditions)
- [ ] P3 26.4.2 Alert thresholds (static, dynamic)
- [ ] P3 26.4.3 Alert channels (email, Slack, PagerDuty)
- [ ] P3 26.4.4 Alert escalation (escalate if not acknowledged)
- [ ] P3 26.4.5 Alert deduplication (suppress repeated alerts)
- [ ] P3 26.4.6 Alert silencing (mute during maintenance)
- [ ] P3 26.4.7 Alert grouping (group related alerts)
- [ ] P3 26.4.8 Alert analytics (alert frequency, resolution time)
- [ ] P3 26.4.9 Alert runbooks (steps to resolve)
- [ ] P3 26.4.10 Alert on-call rotation (who gets paged)

### 26.5 Dashboards

- [ ] P3 26.5.1 System health dashboard (CPU, memory, disk, network)
- [ ] P3 26.5.2 Application performance dashboard (latency, errors, throughput)
- [ ] P3 26.5.3 Business metrics dashboard (users, revenue, completion)
- [ ] P3 26.5.4 Learning analytics dashboard (engagement, retention, completion)
- [ ] P3 26.5.5 Content analytics dashboard (views, time, completion)
- [ ] P3 26.5.6 Revenue dashboard (MRR, churn, LTV, CAC)
- [ ] P3 26.5.7 User engagement dashboard (DAU, sessions, retention)
- [ ] P3 26.5.8 Error tracking dashboard (errors, trends, top errors)
- [ ] P3 26.5.9 Custom dashboards (build your own)
- [ ] P3 26.5.10 Dashboard sharing (share with team)

### 26.6 Incident Management

- [ ] P3 26.6.1 Incident detection (automated from alerts)
- [ ] P3 26.6.2 Incident classification (severity, impact)
- [ ] P3 26.6.3 Incident notification (PagerDuty, Slack, email)
- [ ] P3 26.6.4 Incident response (runbook execution)
- [ ] P3 26.6.5 Incident resolution (fix and verify)
- [ ] P3 26.6.6 Incident postmortem (blameless review)
- [ ] P3 26.6.7 Incident tracking (all incidents logged)
- [ ] P3 26.6.8 Incident reporting (metrics, trends)
- [ ] P3 26.6.9 Incident prevention (proactive fixes)
- [ ] P3 26.6.10 Incident learning (lessons learned)

---

## 27. Legal & Compliance

### 27.1 Privacy

- [ ] P3 27.1.1 Privacy policy (clear, readable, linked in footer)
- [ ] P3 27.1.2 Terms of service (linked in footer)
- [ ] P3 27.1.3 Cookie policy (what cookies are used)
- [ ] P3 27.1.4 Cookie consent (opt-in banner, not opt-out)
- [ ] P3 27.1.5 Data minimization (collect only what is needed)
- [ ] P3 27.1.6 Right to deletion (account deletion, data purge)
- [ ] P3 27.1.7 Right to portability (data export in standard format)
- [ ] P3 27.1.8 Right to rectification (correct inaccurate data)
- [ ] P3 27.1.9 Right to object (opt-out of processing)
- [ ] P3 27.1.10 Consent management (granular consent toggles)
- [ ] P3 27.1.11 Data retention policies (auto-delete old data)
- [ ] P3 27.1.12 Data processing agreements (DPA for B2B)
- [ ] P3 27.1.13 Privacy by design (default privacy settings)
- [ ] P3 27.1.14 Privacy impact assessment (PIA for new features)
- [ ] P3 27.1.15 Data breach notification (72-hour rule, GDPR)

### 27.2 Security Compliance

- [ ] P3 27.2.1 SOC 2 Type I compliance
- [ ] P3 27.2.2 SOC 2 Type II compliance
- [ ] P3 27.2.3 ISO 27001 compliance
- [ ] P3 27.2.4 ISO 27701 compliance (privacy)
- [ ] P3 27.2.5 CSA STAR compliance (cloud security)
- [ ] P3 27.2.6 PCI DSS compliance (payment processing)
- [ ] P3 27.2.7 HIPAA compliance (if health data)
- [ ] P3 27.2.8 FERPA compliance (education records)
- [ ] P3 27.2.9 COPPA compliance (children under 13)
- [ ] P3 27.2.10 GDPR compliance (EU data protection)

### 27.3 Content Licensing

- [ ] P3 27.3.1 Course licensing (CC BY-SA, CC BY-NC, proprietary)
- [ ] P3 27.3.2 Asset licensing (image, audio, video licenses)
- [ ] P3 27.3.3 Third-party content attribution
- [ ] P3 27.3.4 License compatibility checking
- [ ] P3 27.3.5 License compliance tracking
- [ ] P3 27.3.6 License violation detection
- [ ] P3 27.3.7 License renewal tracking
- [ ] P3 27.3.8 License dispute resolution
- [ ] P3 27.3.9 License audit (periodic review)
- [ ] P3 27.3.10 License reporting (for compliance)

### 27.4 Accessibility Compliance

- [ ] P3 27.4.1 WCAG 2.1 AA compliance (target)
- [ ] P3 27.4.2 WCAG 2.1 AAA compliance (stretch)
- [ ] P3 27.4.3 Section 508 compliance (US federal)
- [ ] P3 27.4.4 ADA compliance (US disability)
- [ ] P3 27.4.5 EN 301 549 compliance (EU accessibility)
- [ ] P3 27.4.6 Accessibility statement (public declaration)
- [ ] P3 27.4.7 Accessibility audit (periodic third-party audit)
- [ ] P3 27.4.8 Accessibility remediation (fix issues)
- [ ] P3 27.4.9 Accessibility training (for staff)
- [ ] P3 27.4.10 Accessibility monitoring (continuous testing)

### 27.5 Financial Compliance

- [ ] P3 27.5.1 Tax calculation (per jurisdiction)
- [ ] P3 27.5.2 Tax reporting (1099, VAT, GST)
- [ ] P3 27.5.3 Invoice generation (per transaction)
- [ ] P3 27.5.4 Revenue recognition (accrual accounting)
- [ ] P3 27.5.5 Refund processing (within policy)
- [ ] P3 27.5.6 Chargeback handling (dispute resolution)
- [ ] P3 27.5.7 Anti-money laundering (AML) checks
- [ ] P3 27.5.8 Know your customer (KYC) verification
- [ ] P3 27.5.9 Financial auditing (annual audit)
- [ ] P3 27.5.10 Financial reporting (quarterly, annual)

---

*End of feature specification.*

- [x] P1 2.1.65 "Executable Images and OS Loading" course COMPLETE: 6 concepts in 4 modules, 150 minutes. Depends on obj, sym, reloc, link and dyn, and is scoped to the one layer ALL FIVE of those left untouched: the KERNEL. The scope check is the argument -- `auxv`, `AT_PHDR`, `AT_ENTRY`, `AT_BASE`, `AT_RANDOM`, `vDSO`, `demand paging` and `mmap_min_addr` appear in ZERO of the thirty concept files written before it, and `execve` appears only in the macho course. Five prior courses cover how a FILE is produced; none covers what the kernel does when it is run. The subject is a data structure with no name: the AUXILIARY VECTOR, the third array on the initial stack after argv and envp, 22 entries on this kernel, and not one of them reachable from C because no libc function returns it. It exists because the file cannot contain the answer -- `e_entry = 0x1130` is an OFFSET and the program needs an ADDRESS, and only the kernel knows which base it chose. The load-bearing measurement is the arithmetic `AT_ENTRY - AT_PHDR == e_entry - e_phoff`, both 0x10f0, where the left came from the kernel's stack and the right from 24 bytes of an ELF header the script parsed itself; the base the kernel chose CANCELS, so a test never has to learn it. Two checks close the loop the other way by mapping AT_ENTRY through /proc/<pid>/maps to a file offset and requiring it to equal e_entry -- kernel -> address -> mapping -> file offset -> the number in the file, four hops. Module 1 is the handoff and the two-array trap: the auxv is TWO NULL-terminated arrays past argv, not one, and skipping one reads an environment string's address as a tag, which never terminates and faults rather than returning a wrong value. `%rsp` in main is NOT the initial stack pointer -- libc has pushed frames -- and the kernel's own answer is /proc/self/stat field 28, which must be counted from the LAST ')' because a process name may contain spaces. Module 2 reads the values: the auxv is UNSORTED (33, 51, 16, 6, 17, 3, 4, 5...), every value is one unsigned long with no type tag, and AT_PAGESZ=0x1000 is a SIZE not an address, so the reference implementation needs a static table of which tags may be dereferenced. AT_BASE is a DIFFERENT FILE (ld.so) and both it and the program are ET_DYN, which is why the kernel must report a base for each. The vDSO is a real ELF image with no file: magic 7f454c46, e_type 3, e_machine 62, 6 program headers, 8192 bytes, read from /proc/self/mem, and its maps line has no device, inode or path. Module 3 is the layout: mmap_min_addr is 0x10000, MAP_FIXED below it returns EPERM, and the SAME addresses as a plain HINT succeed at a different address -- a hint is advice, which is the whole mmap contract and the reason MAP_FIXED exists. Demand paging measured at 122 -> 377 -> 377, i.e. +255 for touching 1 MB of .bss page by page and +0 on the rewrite. Module 4 is the artifact: imgdump.c (132 lines) hands over the RAW frame and BLOCKS on stdin so the parent can read maps and cmdline of a process that has executed nothing, and stackwalk.py (430 lines) parses it with struct.unpack_from and no libc, no readelf and no /proc/self. Serves 6 concept routes plus the landing, all 200, with 25 internal links resolved across six courses, prev/next chain and manifest minutes verified by tools/verify_img.py; all 13 prior course landings still 200
- [x] P1 2.2.64 FIVE bugs in `courses/img/`, all recorded rather than quietly fixed, and three of them are the class of bug the course teaches about. (1) The first auxv walk SEGFAULTED: it skipped one NULL-terminated array after argv instead of two, landing inside envp and reading a string pointer as a tag. It never terminates, because a stack address is not zero, so it runs to the end of the mapping -- the failure mode is a fault and not a wrong number, which is why it became the course's central trap. (2) THE VERIFIER CAUGHT THE COURSE'S OWN PARSER: `#%018lx` prints a value of ZERO with no `0x` prefix, only leading zeros, so an auxv regex requiring `0x` silently lost AT_SECURE and AT_FLAGS -- the two entries that confirm the process is not privileged. The harness failed 40/41 and the fix was one character class; this is the strongest argument in the collection for having the harness, because the bug was in the tooling written to check the tooling. (3) `/proc/self/maps` inside a shell pipeline reads the WRONG PROCESS: the first version piped it to awk and cheerfully printed mawk's address space, which looked entirely plausible -- a PIE binary, a heap, a loader, all in the right places. `self` means the process doing the reading, so in a pipeline that is the last stage. The corrected version has a C program print its own maps and then runs the broken awk version alongside it as a demonstration. (4) BOTH hardcoded stack dump windows segfault, in opposite directions: 8 KB truncates the strings on a large environment (AT_EXECFN's string measured 10368 bytes above startstack) and 64 KB reads past the end of the stack mapping on EVERY process. The only correct size comes from the kernel -- read /proc/self/maps, find the mapping containing startstack, dump to its high end -- which measured 11920 bytes, the real size of the kernel's frame. (5) AT_SYSINFO_EHDR was first compared against a vDSO mapping read in a DIFFERENT process, which cannot work because ASLR puts the vDSO somewhere different in each; the fix is to compare within one process, and the general rule is now taught: when verifying something a randomiser perturbs, both observations must come from the same process or you are comparing two samples of a distribution
- [x] P1 2.2.65 `courses/img/assets/samples/stackwalk.py` -- the course's buildable artifact, and the discipline around it is the point. A parser that prints values is a demo; a parser that cross-checks every value against an INDEPENDENT source is a tool. Every check compares two things obtained by different routes, because a check that re-reads the same source verifies nothing: kernel-vs-FILE (AT_PHNUM==e_phnum, AT_PHENT==e_phentsize, the difference identity, and both mapping round-trips), kernel-vs-KERNEL-same-instant (AT_SYSINFO_EHDR vs the [vdso] mapping, AT_EXECFN vs /proc/<pid>/cmdline[0], AT_RANDOM inside the held bytes), and kernel-vs-RUNTIME (AT_PAGESZ vs sysconf, AT_UID vs getuid). The child computes startstack from its own /proc/self/stat and the parent reads the same field from /proc/<pid>/stat: two readers, one number, zero shared state. 18 checks, and THREE of them are deliberately weak regression checks that are labelled as such rather than dressed up -- they would catch a parser reading the wrong array, and a check you understand beats one that merely looks impressive. The artifact never shells out to readelf: it parses the 64-byte ELF header with struct.unpack_from, because the tool is the oracle and the format is the subject, and a crosscheck that used readelf to verify readelf's fields would prove only self-consistency. crosscheck.py re-derives all 41 course claims from a fresh run in 8 groups and RUNS stackwalk.py as a subprocess requiring exit 0, so harness and artifact cannot drift apart. build_samples.sh writes every .c file itself, so four tracked files reproduce everything from an empty directory

- [x] P1 2.1.66 "Executable Security and Hardening" course COMPLETE: 7 concepts in 4 modules, 167 minutes. Depends on obj, sym, reloc, link, dyn and img, and is scoped to the gap the two existing hardening concepts leave: BOTH are lists of FLAG NAMES on non-ELF platforms (macho-hardening: NULL-page/ASLR/PIE; pe-security-flags: the DllCharacteristics ASLR/NX/CFG bits), and neither shows what a flag does to the file. The scope check: `stack-protector`, `canary`, `FORTIFY`, `full/partial RELRO`, `CET`, `IBT`, `SHSTK`, `TEXTREL`, `DT_BIND_NOW`, `DF_BIND_NOW`, `DF_1_NOW` and `stack clash` appear in ZERO of the ~37 prior concept files, and RELRO is mentioned 8 times without the two tiers ever being named. The course moves the subject to x86-64 ELF and down from names to bytes, and its first measurement is the argument: THE SAME SOURCE at -O1 with NO FLAGS gives clang 0 `%fs:0x28` references and gcc 2, and the two drivers then disagree twice more -- gcc passes `-z relro -z now` to ld and clang passes NOTHING, so the gcc binary is FULL RELRO with the GOT sealed and the clang binary is partial with the .got.plt TAIL WRITABLE. That yields the course's three-layer model (CODEGEN / LINKER / DRIVER), and the consequence that a hardening policy that pins layers 1 and 2 says nothing about layer 3, so two teams with the same written policy ship different binaries. Module 2's RELRO measurement is the sharpest: `-z relro` is a NO-OP on this toolchain (no flag and `-z relro` both give memsz 0x208 at 0x403df8..0x404000), so there are two tiers and not three; the RELRO range ALWAYS ends on a page boundary in all three builds, so `-z now` extends it BACKWARDS (0x403df8 -> 0x403dd0) rather than forwards; and .got.plt at 0x403fe8..0x404008 CROSSES that end by 8 bytes, which are the lazy-binding slots the loader still has to write -- so full RELRO is only possible once resolution is done first, and the section's disappearance is the proof the sealing became possible. Module 2 also measures FORTIFY's four levels by their IMPORTS (level 1 -> __strcpy_chk + __read_chk, level 2 -> __vprintf_chk because %n writes) and the mechanism is visible as `mov $0x20,%edx` -- a compile-time-known sizeof passed as an argument so libc can check against it. Module 3 finds TEXTREL COULD NOT BE FORCED even with -z text, and the reason is the finding: a `const char *const` table goes to .data.rel.ro at 0x3e20..0x3e38, which is INSIDE the RELRO range 0x3e10..0x4000, so the loader always had somewhere legal to write. And CET is the concept where the obvious measurement is wrong: `endbr64` appears 5 times in a binary built with `-fcf-protection=none`, all of them from the distro's pre-hardened crt1.o and crti.o, so my functions have 0 while the binary has 5 and the property note (0x10 -> 0x20 bytes, `x86 ISA needed` -> `IBT, SHSTK`) is what the kernel actually reads. Module 4 is the artifact: harden.py parses the ELF header, program headers, section table, dynamic array, string table and the GNU property note with struct.unpack_from and no readelf/objdump/compiler, and every check names its SOURCE because a check that reads the same byte twice agrees with a wrong answer. Its distinguishing output is `covered by RELRO: NO` -- the geometric fact, not the `partial` label the file claims. Serves 7 concept routes plus the landing, all 200, with 29 internal links resolved across seven courses, prev/next chain and manifest minutes verified by tools/verify_sec.py; all 14 course landings still 200
- [x] P1 2.2.66 THREE claims RETRACTED from the hardening course rather than quietly corrected, all three in research.md and all three asserted in the crosscheck so a future compiler that changes the behaviour will fail rather than silently invalidate the text. (1) "A known-size destination gives you __memcpy_chk" -- it does not on clang 21: `char b[4096]; memcpy(b, s, 2048)` emits plain memcpy at _FORTIFY_SOURCE=3. strcpy becomes __strcpy_chk reliably; memcpy did not, and the rule was NOT determined from source and is not claimed. What is claimed instead is the durable version: FORTIFY is a compile-time technique whose visible effect is in the binary's IMPORTS, so you verify it by reading the file. (2) "A global buffer overflow is not caught" -- wrong in a default build, because FORTIFY caught it and the canary did not; the correction turned a single-mechanism concept into the two-mechanism comparison that is now the course's most useful table (canary = a property of WHERE THE CHECK LIVES, the frame; FORTIFY = a property of WHAT THE CODE SAYS, this copy this known size), and it also established that the two are trivially confused because both abort, with the MESSAGE being the only way to tell them apart. (3) "Five endbr64 therefore the binary is CET-enabled" -- wrong, and the counting METHOD was retracted with it
- [x] P1 2.2.67 FIVE bugs in the hardening course's own tooling, each of which produced a FALSE NEGATIVE (a security check that found nothing) rather than a false positive, which is the dangerous direction. (1) `harden.py` HUNG on the first real binary: the GNU property note loop computed its step from psize, and a psize of 0 advances the cursor by nothing, so the loop never terminated -- the symptom was a hang with no output at all, and for a security tool that is the worst available outcome, because no answer looks nothing like a wrong answer and a hanging CI job reads as infrastructure trouble. Fixed with an unconditionally positive step and a comment saying that removing the guard reintroduces the bug. (2) The crosscheck's section reader returned the file OFFSET where it meant the ADDRESS -- readelf -SW prints `Nr Name Type Address Off Size`, one column out -- and four checks then reported TRUE claims as FALSE. A check that fails for the wrong reason is worse than no check, because it teaches you to ignore it; the column is now named ('addr'/'off'/'size') rather than numbered. (3) Two checks searched for driver flags in the wrong STREAM: `gcc -###` prints the command line on stderr, and the helper returned stdout only, so the checks silently found nothing -- and a security check that finds nothing is indistinguishable from a security check that never ran. (4) The build loop took the empty string before the colon, so four `sp_*` specimens overwrote ONE file and three rungs of the stack-protector ladder all measured the last build; caught by the crosscheck, which is the argument for having one. (5) The -O1 optimiser deleted the evidence TWICE, the same lesson as the TLS retraction in 2.2.60: the first H2 specimen's local array was folded away so gcc declined to instrument the function and the canary count was 0 despite the source having a local array, and the second was a read() whose result was unused so the call vanished and read@plt went 2 -> 0, which looked exactly like FORTIFY level 3 "removing" the call. The general rule is now stated in the course: when two things measure as identical, the first hypothesis is that the optimiser deleted the difference
- [x] P1 2.2.68 A latent bug in the SHARED course verifier template, found because this course is the first with an apostrophe in a concept title. The `#html` macro escapes a literal apostrophe to `&#39;` on output, so a rendered `<h1>Reading a Binary's Posture</h1>` appears in the raw markup as `&#39;` and never equalled the manifest string. `jvm/lessons/jvm-stackmaps` has the identical situation ("The Verifier's Data") and has no verifier, so it was never caught. All five verifiers (reloc, link, dyn, img, sec) now compare html.unescape(title) against the manifest, with a comment recording why. Fixed in the tooling rather than worked around in the content, and a second instance of the same lesson as the brace-fix script from the img course: when a house tool is wrong, fix the tool
- [x] P1 2.2.69 `courses/sec/assets/samples/harden.py` -- the course's buildable artifact, and the two design decisions in it are the transferable ones. (1) It never shells out: the ELF header, program headers, section table, dynamic array, string table and GNU property note are all parsed with struct.unpack_from, because a crosscheck that used readelf to verify readelf's fields would only prove self-consistency. (2) Every check NAMES ITS SOURCE, because a check that reads the same byte twice and calls it two checks is worse than no check -- it agrees with a wrong answer and there is no way to tell. That discipline is what makes `covered by RELRO: NO` the report's most valuable line: not the `partial` label the file claims about itself, but the geometric fact that the GOT section does not fit inside the sealed range. The tool deliberately emits NO SCORE, and the reason is a result rather than a preference: hardening properties are only PARTIALLY ORDERED, so a binary can be stronger in one row and weaker in another and "is this at least as hardened" has no total-order answer. A number would have to invent a weighting the properties do not support. Two of the eight features (the stack canary and FORTIFY) leave NO header field at all -- the canary is a byte pattern and FORTIFY is an import name -- so a tool built on the assumption that hardening is a set of flags reports nothing about the two most widely deployed features in the world. 10 checks per binary; crosscheck.py re-derives all 60 course claims in 8 groups and runs harden.py as a subprocess requiring exit 0

- [x] P1 2.1.67 "The Instruction Set Architecture" course COMPLETE: 7 concepts in 4 modules, 167 minutes. Depends on obj, elf and sec, and is scoped to a gap six prior courses were standing on: obj-arch-table asked a linker "how many bytes is the instruction?" and explicitly declined to answer, and `word-boundary` grep over all ~44 prior concept files found `ModRM` 0, `SIB byte` 0, `EVEX`/`VEX` 0, `EFLAGS`/`RFLAGS`/`condition code` 0, `two-byte opcode` 0 and `instruction set architecture` 0, while `opcode` appeared 43 times -- always as "the byte a relocation must not patch". So the bytes were everywhere and the meaning nowhere. The hook is a mode collision: `40 89 e8` is ONE 3-byte instruction in 64-bit mode and TWO instructions (1 byte then 2) in 32-bit, because 0x40-0x4F is INC/DEC in 32-bit and a REX prefix in 64-bit -- the same class of fact as an ELF `e_machine` field, demonstrated with three bytes. A SECOND collision of the same shape was found and is the more interesting one: 0x62 is the AVX-512 EVEX prefix in 64-bit and BOUND in 32-bit, and a disassembler without AVX-512 support REFUSES it and loses the instruction stream from that point on. Module 1 also measured the map: 228 of 256 one-byte values decode to an instruction, 27 are prefixes (16 REX + 11 legacy) and 1 is nothing, and `0F 0B` is UD2 -- a deliberately undefined opcode, which is why a compiler emits it after a noreturn call so a fall-through dies at the next instruction instead of executing whatever bytes follow. Module 2's REX finding is the rule everyone gets wrong: each of R/X/B ADDS 8 to a 3-bit field, so R=1 with reg=000 is r8 and NOT r9; and a REX must be the LAST prefix, so `66 48 8b c0` is one instruction while `48 66 8b c0` is two. The ModRM measurement is exhaustive and is the answer to obj-arch-table's question: ALL 256 values for `8b /r` decode as exactly one instruction once completed with their own trailing bytes, and `mod=11` is exactly 64 of 256 (a clean quarter, the register forms) with the other 192 memory forms -- so `mod` and `rm` together, and only those two fields, decide the length. Module 3's SIB work CORRECTED TWO of the author's own recollections: `index=100` with REX.X=0 means NO INDEX (not rsp) and `index=101` is rbp, which is why `[rbp+rsi*1]` cannot be encoded without a displacement; and the SIB byte comes immediately after the ModRM and BEFORE the displacement, so `8b 84 24 11223344` and `8b 84 1122334424` are two different valid instructions. Underneath is a two-level dependency: base=101 at mod=00 means no base and a 4-byte absolute displacement, so a decoder cannot size the instruction from the ModRM alone -- 32 of the 256 SIB bytes break a ModRM-only length function. The length formula (`prefixes + opcode + modrm + sib + displacement + immediate`) is verified on 14 specimens with 0 mismatches, and the load-bearing result is the CHAIN property: instruction boundaries form a chain, one wrong length desynchronises every boundary after it, and therefore the check that matters is not "the instruction count matches" (a compensating pair of errors can make that agree) but "the chain consumes the section exactly". Module 4 is the artifact: x86dec.py, 1042 lines, no toolchain, parsing the ELF section table with struct.unpack_from and printing the DERIVATION for every field rather than just the answer -- three design positions: length and structure are the contract (364 audited opcodes resolve exactly, and where there is no name it prints `(op 0f 6c)` rather than guessing), no toolchain anywhere, and derivation over result. The two decoders agree on 578/578 instruction boundaries (100%) with every chain closing exactly, across three specimens including an object file where every displacement is a zero awaiting a linker; crosscheck.py re-derives 118 claims in 9 groups including I9, which audits all 364 table entries against the oracle. Serves 7 concept routes plus the landing, all 200, with 35 internal links resolved across ten courses, prev/next chain and manifest minutes verified by tools/verify_isa.py; all 16 course landings still 200
- [x] P1 2.2.68 FIVE claims RETRACTED from the instruction-encoding course rather than quietly corrected, all five in research.md and all five asserted in the crosscheck so a future toolchain that changes the behaviour fails rather than silently invalidating the text. (1) "A known-size destination means index=100 is rsp" -- no: index=100 with REX.X=0 is NO INDEX and index=101 is rbp. (2) "The SIB byte follows the displacement" -- no, it precedes it, and both orders are valid different instructions. (3) "0F F4 is HLT" -- it is PMULUDQ; the one-byte F4 had been copied into the two-byte table. (4) "D3 takes an 8-bit immediate" -- it takes none; D0-D3 are shift-by-1 and shift-by-CL and only C0/C1 have an immediate. (5) "48 C7 /0 has an 8-byte immediate" -- it is 8 bytes TOTAL, because REX.W widens the OPERAND and not the immediate (the imm32 is sign-extended), which is also why 0x00000000FFFFFFFF cannot be loaded in one instruction. That last one was found as a decoder bug and kept as finding F7
- [x] P1 2.2.69 SIX errors in the instruction course's own tooling, kept because they are the lesson, and every one produced a FALSE NEGATIVE or a wrong-looking decoder rather than a clean failure. (1) THREE SEPARATE reference parsers were wrong about objdump's OUTPUT FORMAT, and each time the fault looked like the decoder being wrong: objdump WRAPS long encodings across lines (7 bytes then a continuation with no mnemonic field, so an instruction is not a line and a line-per-instruction parser called a correct 10-byte NOP 7 bytes long), and it sometimes emits an entry with NO MNEMONIC for a byte run it cannot name, which a parser requiring three tab-separated fields dropped silently -- reporting 578/611 agreement when the decoder was right. (2) An over-broad exception list demanded a ModRM byte from 0F 09, 0F 0B and 0F 31, which take none, so the decoder REFUSED three ordinary instructions. (3) THIRTEEN duplicate dict keys in the opcode tables: Python keeps the last, so three of them silently undid fixes applied minutes earlier, and the line-based cleanup that removed them also deleted nine unrelated XCHG entries that merely shared a line with a duplicate. Found by counting keys per table -- a one-line check that should have existed from the start. (4) The operand order was backwards for the ENTIRE ALU family: 0x89 is MOV r/m, r and the rule is that the EVEN base opcode is r/m,r while the ODD one is r,r/m, and the author of the code had it exactly reversed. (5) An immediate was counted twice after an edit, so every instruction with an immediate overran by its own width -- the same family as the zero-step hang in 2.2.67. (6) The file/hex argument ambiguity fed a filename to bytes.fromhex and produced a traceback that looked like a decoder bug. The common thread and the collection's standing rule: a check that fails for the WRONG REASON is worse than no check, because it teaches you to ignore it -- so in every case the fix went into the harness, never into the decoder
- [x] P1 2.2.70 SIX measured limitations of the ORACLE, each of which forced a design decision rather than being worked around. (1) objdump does NOT apply REX.X to the SIB index: `45 8b 04 24` should be `[rsp+r12*1]` and it prints `[rsp]`, while applying REX.R and REX.B correctly -- so the crosscheck compares instruction BOUNDARIES AND LENGTHS, never operand text, because asking a checker a question one of your tools is known to get wrong is how a correct tool gets "fixed" into a broken one. The artifact DOES apply the bit and says so. (2) It wraps long encodings across lines. (3) It emits entries with no mnemonic. (4) It refuses AVX-512 and loses the stream -- `(bad)` at 0x62 then garbage -- so the corpus is built `-march=x86-64`, on the principle that a reader that GIVES UP is not a reader that DISAGREES and the two must not be confused. (5) It cannot decode 0F 38 / 0F 3A without AVX and emits `.byte 0xf`. (6) On `48 66 ...` it RECOVERS by printing a bare `rex.W` and re-reading the 0x66 as a prefix, where architecturally the 0x66 is the opcode (PUSH ES, invalid in 64-bit) and the instruction faults; the artifact refuses, and the course states that both are defensible provided the difference is a decision you made rather than a bug you inherited
- [x] P1 2.2.71 A new house tool, `tools/fix_divs.py`, added because a `formula` div whose content is an example of terminal output is easy to close twice -- the example ends with a line that looks like a closer. Three of the seven concept files had the defect, the second instance cost three rebuild cycles, and the tool only ever REMOVES a duplicated block-level closer, never adds or rewrites, and prints what it removed so the change is reviewable
- [x] P1 2.2.72 `courses/isa/assets/samples/x86dec.py` -- the course's buildable artifact, and its three design positions are the transferable ones. (1) LENGTH AND STRUCTURE ARE THE CONTRACT: 364 audited opcodes resolve the encoding exactly, naming is a bonus, and where there is no name it prints `(op 0f 6c)` rather than guessing, because a guessed mnemonic is a claim nothing checked while a correct length with no name is an honest PARTIAL answer -- and the length is the part a linker needs. (2) NO TOOLCHAIN ANYWHERE: the ELF section table is read with struct.unpack_from, because a crosscheck that used objdump to verify objdump's own fields would prove only self-consistency. (3) DERIVATION OVER RESULT: `--why` prints what each field DECIDED and which byte it came from, not what it is, because a reader given only `mov eax,[rsp+32]` has nowhere to look when they disagree. It deliberately emits no coverage percentage and no score, on the same grounds the hardening reader refused a score: a coverage figure would be a claim about the fraction of instructions in SOME binary, which depends on which binary rather than on the tool. The tool's most valuable output on an unknown binary is a REFUSAL, not a summary, because a refusal localises and a summary does not. crosscheck.py re-derives all 118 course claims in 9 groups and runs the artifact as a subprocess

- [x] P1 2.1.68 "How a CPU Executes Instructions" course COMPLETE: 6 concepts in 3 modules, 150 minutes. Depends on isa, sec and img, and is scoped to a gap that is total rather than thin: `word-boundary` grep over the ~52 prior concept files found `microarchitecture` 0, `pipel` 0, `branch predict` 0, `superscalar` 0, `reorder buffer` 0, `store buffer` 0, `register renaming` 0, `throughput` 0, `IPC` 0, `clock cycle` 0, `4K alias` 0, `false depend` 0 -- and the few hits for `cache`, `fetch`, `decode` and `out-of-order` are unrelated senses (DWARF package caching, symbol hashing, fetching a symbol). The isa course ended at "these bytes spell this instruction" and nothing covered what the hardware does with them. The course's spine is a METHODOLOGICAL result, and it is the most important thing found: the instrument's apparent noise turned out to be the phenomenon under study. The first draft of the benchmark quoted a 73% run-to-run spread, which would have made every number in the course unpublishable -- and it was not the machine. It was two BYTE-IDENTICAL loops in one binary at different addresses, one paying a fixed penalty rediscovered on every run. Once every bench function was marked aligned(64), the numbers became monotonic series for the first time, and that single attribute is the difference between a usable instrument and a random number generator. Measured on an AMD Ryzen 5 7430U (Zen 3) in a VIRTUALISED guest, with `constant_tsc` and `nonstop_tsc` present: the TSC is a FIXED 2.2959 GHz while the core clock moved 2389-3320 MHz within a single run, so a TSC tick is a unit of TIME and not a count of core clocks -- which is why the course quotes NO absolute cycle count anywhere and every figure is a ratio or a minimum, since a ratio has the same clock on both sides and the clock cancels. F3: a dependent chain of `add r8,r8` costs about 2.7x an independent operation (dependent marginal ~0.95 ticks per link, independent ~0.25 per op), and the SHAPE is clearer than the number -- dependent is linear in chain length with a steep slope, independent is nearly flat and then bends, and the bend is where the core runs out of places to start work. F2: alignment is worth up to 2.51x, measured by emitting one byte-identical 12-byte loop at eight offsets mod 64, and the slowest offset is 32 rather than 56 (the one that actually crosses the 64-byte line), so NO mechanism is claimed and three candidates (operation cache, loop stream detector, per-address predictor state) are named as unmeasured. F4: the branch direction period makes NO difference from period 1 to period 65536, and no mispredict penalty was observed at any table depth. F5: the "replace an unpredictable branch with a conditional move" advice measured 2.40x SLOWER here, and the artifact states in its own output that this is NOT a clean comparison -- the branching body performs its conditional work half the time because the branch skips it, so 2.40x is an UPPER BOUND and not a measurement, and the folklore's precondition (a frequently-mispredicted branch) was never met. Serves 6 concept routes plus the landing, all 200, with 22 internal links resolved across eight courses, prev/next chain and manifest minutes verified by tools/verify_exe.py; all 17 course landings still 200
- [x] P1 2.2.73 FIVE claims RETRACTED from the execution course, all five in research.md, three printed by the artifact itself, and four asserted by the crosscheck so a later edit cannot quietly drop them. (1) "The noise floor is 73%" -- it is about 15%; the 73% figure was measured on a MISALIGNED function, so it was the alignment effect of 2.2.74 leaking into the noise estimate, which is the course's own headline methodological finding stated as a self-inflicted error. (2) "The flags register has no rename, so flag-writing instructions serialises" -- wrong: four `TEST`s, which all write the flags, cost 1.45x the floor. (3) "Reading the flags is what costs", the obvious replacement for (2) -- also wrong: four `ROR`+`ADC` pairs measured 1.05x four bare `ROR`s. What survives is narrower: the expensive four-`ROR` row is an ordinary loop-carried chain on one register, so THREE candidate explanations were measured and TWO were wrong and the survivor is the boring one. (4) "A mispredict costs about 15 cycles" is NOT CLAIMED AT ALL: none was observed, there is no hardware PMU in this guest (perf_event_paranoid = 4, no cpu_core event source, `perf stat -e branch-misses` fails), so mispredictions cannot be COUNTED, and the two possible explanations -- the predictor learned a 65536-bit pattern, or the drain cost is hidden by slack -- cannot be told apart. The course states both and names the branch-miss counter as the thing that would settle it. (5) The `branchless is 2.40x` result was published first as a clean finding and then retracted to an UPPER BOUND once the confound was noticed: the two bodies do different amounts of work
- [x] P1 2.2.74 The course's largest single finding, and it is about the INSTRUMENT rather than the hardware: `harden.py`-style noise was the phenomenon under study. Two `static` functions in one binary, INSTRUCTION FOR INSTRUCTION IDENTICAL (verified with objdump), differing only in address -- `0x2c00` 64-byte aligned versus `0x2dc0` 32-byte aligned -- measured 0.79 and 2.13 ticks/iteration, a 2.7x difference. `b_dep1` and `b_ind1` are the same `add $1,%r8; dec %rc; jnz 1b; mov %r8,out` loop and the difference is entirely that one of them lands where its body crosses a 64-byte fetch boundary. The consequences are three and all of them are in the artifact: (1) every bench function is now `__attribute__((aligned(64)))`, asserted EXACTLY by crosscheck group C by reading the ELF SYMBOL TABLE, which is the only check in the file with no noise term; (2) the real noise floor is ~15%, not 73%; (3) the alignment effect is measured as a curve over eight offsets and the slowest is NOT the one that crosses the line, so no mechanism is claimed. This is also where the two ISA courses meet: the padding that produces the effect is the same multi-byte NOP the isa course measured as `0f 1f 00`, and this course measured what it is worth
- [x] P1 2.2.75 SEVEN errors in the execution course's own tooling, each kept because it is the lesson, and the sixth is the sharpest because it is the course's own stated mistake committed inside the course about it. (1) A BENCHMARK THE COMPILER DELETED: the first unpredictable-branch measurement returned 0.0000 ticks because the loop was written in C with a deterministic xorshift and the compiler PROVED the sum was constant. (2) `test $1, $1` does not exist -- x86 has no immediate-to-immediate test -- and a helper function named `floor` collides with the libc builtin. (3) PADDING A BENCHMARK WITH SOMETHING THE CPU WILL NOT DECODE: the alignment experiment padded with 64 bytes of `0x66`, i.e. 64 consecutive operand-size prefixes, and x86-64 permits at most 15 bytes of prefixes before an instruction, so byte 16 is a #GP and the program SEGFAULTED; `0x90` is one byte and one instruction so a run of any length is legal. (4) The noise floor was measured on the phenomenon, covered in 2.2.74. (5) A PROSE LINE MATCHED A DATA REGEX: the crosscheck's marginal-cost pattern also matched the sentence "independent ones retire several per cycle" and overwrote the parsed marginals with an empty list; the `\d+\s+adds` anchor fixed it, because a parser that accepts prose will eventually be right by accident. (6) A STALE KERNEL SAMPLE TREATED AS A LIVE READING: an early version sampled /proc/cpuinfo's `cpu MHz` around every measurement and converted ticks to cycles with it, and the resulting "cycles" were wrong by up to 3x because that value is updated far more slowly than a measurement takes; it is now printed for orientation and explicitly NOT used. (7) THE CROSSCHECK WAS FLAKY, and the fix is the course's own principle: it asserted that the measured noise floor was BELOW 40%, which is a VALUE claim about a NOISY measurement, and it failed about one run in five with a reported spread of 72% on hardware that had not changed. The floor is now reported and USED as the tolerance and never bounded, and the ratio check was moved off the medians of marginals onto the TOTALS, which differ by about 5x and are far outside any plausible noise -- a median of marginals can go near zero on a bad run and produce a ratio of 27x, arithmetically true and physically absurd. After the fix, 10 consecutive runs gave 37/37 every time: a harness that fails one run in five is a harness people learn to re-run, and a harness people learn to re-run verifies nothing
- [x] P1 2.2.76 `courses/exe/assets/samples/cycbench.c` -- the course's buildable artifact, 181 lines of output in seven sections, and its design is the transferable part. (1) The first TWO sections are about the instrument, not the machine: the TSC rate is measured against CLOCK_MONOTONIC at startup, the core clock is sampled and explicitly NOT used, and the noise floor is measured before any claim is made. (2) FIVE RULES are in the file's header comment as a numbered list, each one learned by breaking it: the TSC is time not cycles; RDTSC is not serialising so LFENCE goes before and RDTSCP+LFENCE after (measured at about 42 ticks per call); INTERLEAVE so a frequency ramp cancels in the ratio; take the MINIMUM not the mean because under this much noise the fastest run is the one least disturbed by something else; and the body is what is measured, not the loop, because a loop carries its own `dec -> jnz` dependency. (3) The bodies are in inline asm, which is unchecked and untyped -- the ISA course's decoder hit a macro that pasted a literal into the instruction text, and this course hit an instruction that does not exist. (4) The artifact PRINTS ITS OWN LIMITS, including the two retractions and the statement that the branchless comparison is not clean, because a tool that prints only the headline is what every datasheet and benchmark summary already is. (5) It emits no score and no coverage percentage, for the same reason the hardening reader refused a score: a noise floor means there is no total order over timings, so a single number would have to invent a weighting the measurements do not support. crosscheck.py re-derives 37 claims in 9 groups, and NOT ONE of them asserts a number -- they assert monotonicity, ordering and bounds, plus one exact group read out of the ELF symbol table, plus one group that asserts the course's own retractions are still present in the text
- [x] P1 2.1.69 "The Memory Hierarchy" course COMPLETE: 8 concepts in 4 modules, 192 minutes. Depends on isa, exe, sec, img, obj and elf, and is scoped to a gap that is total rather than thin: a word-boundary grep over the ~60 prior concept files found `prefetch` 0, `cache miss` 0, `set associat` 0, `write-allocate` 0, `non-temporal` 0, `false sharing` 0, `NUMA` 0, `huge page`/`MADV_HUGEPAGE` 0, and `TLB` 1 which is a FORWARD REFERENCE written by the obj course to this one -- so five earlier courses point at this course and none of them answers it. The `obj_sections.ch` reference is the sharpest: it states a page is 4096 bytes and an L1 line is 64 and asks whether "alignment 4" means one or the other, and this course is where that number stops being a stated constant and becomes something with a measured cost attached. F1 is the hook and the most useful number in the course: over the SAME 64 MiB, entirely outside every cache level, in the same binary, a pointer chase costs 132.4 ns/line and a sequential sweep costs 3.49 -- **38x for byte-identical traffic** -- and the 38x IS the prefetcher, which cannot be observed directly without a PMU and can only be subtracted. F2 turns the hierarchy into a BAND rather than four numbers: 1.59 ns at 32 KiB, 4.77 at 64 KiB, 11.64 at 512 KiB, 78.1 at 16 MiB, 149.9 at 256 MiB, with each step landing within a factor of two of the size /sys reports (the only agreement a cache size can have, because the last line of a level is always a miss) and the L3 plateau itself 5.5x wide, so a single number called "the L3 latency" would be wrong by a factor of 5.5 depending on where in the L3 you asked. F3 predicts associativity from /sys BEFORE measuring it (8 ways means 9 lines a multiple of 4096 bytes apart cannot coexist) and finds the onset between 8 and 9 and nowhere else, 7.72 vs 1.56 at 9 lines, with a control layout spanning the same 128 KiB that never slows down at all -- a working set of **576 bytes** costing L2 latency. F4 isolates translation with two layouts of the same line count, footprint, order and L1 set, differing only in page count: fast to 64 pages, slow from 72, a 3.29x cliff, both arms 32 KiB of data so it is a translation cost and not a capacity one. F6 is the sharpest claim in the course and is machine-independent: `st4` and `st64` cost the same at every size (0.99 vs 0.99 at 256 KiB, 8.47 vs 8.91 at 64 MiB) because the transaction is the LINE -- you are charged for fetching all 64 bytes and writing all 64 back whatever you used -- and the non-temporal store is expensive at EVERY footprint and flat (17.2 ns at 16 KiB, 16.6 at 64 MiB), where the flatness is itself the proof of non-allocation because nothing on that path consults the cache. F7 measures false sharing with nothing shared at all: two threads each incrementing their OWN counter, 8 bytes apart versus 64, 61.9x, with every one of 7 runs checked against core_id in /sys so the claim rests on two real cores and not on two SMT siblings. F8 is the methodological result: the quantity the tolerances apply to is the spread of the ESTIMATOR (14 min-of-3 values, 14.3%) and not of the 42 runs behind it (34.0%), and a hypothesis that FAILED is reported -- the paired estimator was worse than the ratio of minima in 4 of 24 runs, so the ordering is a property of how hard the clock was moving and the artifact quotes the widest of the three tolerances rather than naming one. Serves 8 concept routes plus the landing, all 200, with 25 internal links resolved across eight courses, prev/next chain and manifest minutes verified by tools/verify_mem.py; all 17 course landings still 200
- [x] P1 2.2.77 NINE retractions recorded for the memory hierarchy, all nine PRINTED by the artifact in section 8 and all nine ASSERTED AS TEXT by crosscheck.py group H, so a taken-back claim cannot be quietly dropped nor deleted. (1) "256 lines at a 4096-byte stride show a 5.28x TLB cost" -- the 5.28x was real and the INTERPRETATION was wrong, because the layout put those lines at `64*(i mod 8)` so they shared 8 sets of an 8-way cache; it was the associativity effect of F3 measured one page at a time, and a real effect given a false cause is the most dangerous kind of wrong number because the reproduction works. (2) "There is a TLB cliff at 32 pages" -- same cause: one line per page IS the aliasing stride, so every page's line landed in L1 set 0; when the offset spread over all 64 sets the cliff vanished and a BISECTION placed the real one at 64. (3) "Sequential reads sustain 64 GB/s" -- two bugs, both in the units and neither in the memory: the loop did one line per iteration so the measured rate was identical at every footprint from 256 KiB to 64 MiB, and a rate that is the same for L2-resident and for DRAM data is the rate of a LOOP; with four lines per iteration the same sweep reports 91.4 GB/s over an L2-resident region and 16.8 GB/s over DRAM. (4) "An NT store is 16.4 ns per 16 bytes" -- the navigation load and the NT store shared a cache line, so the load allocated the very line the store was supposed to bypass. (5) "False sharing has no effect here" -- the threads were reading ONE counter, and the fix's barriers of count two with one waiter each DEADLOCKED the benchmark; fixed twice, the result is the 61.9x. (6)-(9) are the ones a reader is most likely to hit: three SEGFAULTS from writing past a mapping (including a size loop that computed `reps = MAXL/lines` with `lines > MAXL`, got 0, and walked forward until it faulted); `rdpmc` executed in the parent killed the whole benchmark and now runs in a forked child that reports the signal it died from; a "256 MiB" table reporting 8 ns because the layout added `64*(i mod 64)` and line 32 landed on line 64's address -- THE PERMUTATION STILL VISITED EVERY INDEX so every self-check passed and the table was nonsense, which is why the check that now catches it walks the cycle and counts DISTINCT ADDRESSES, and why the lesson is stated as a rule: a non-monotonic table is not noise, it is a signal that the layout is not what the caption says it is (the same bug then reappeared as a stray `* 64` and produced a TLB table whose cost was HIGH for 32 pages and LOW for 72, the exact inverse of the truth); and a register NAMED in an asm template is not a scratch register, learned in three attempts including an earlyclobber marker that moved the collision instead of removing it, so the rule is that every register a template names must be a declared operand or a declared clobber and there is no third case
- [x] P1 2.2.78 THREE retractions of the HARNESS itself, kept because a check that fails for the wrong reason teaches its reader to ignore it, and the third is the same disease the previous course spent a concept on. (1) A VALUE CLAIM ABOUT A NOISY MEASUREMENT: the huge-page check compared `max(hp/pk)` over five deep rows against `1.0 + 2 x noise` and failed at 1.38x against a bound of 1.34x on a machine where the effect was plainly there, because a maximum of five ratios each carrying the same 17% spread is biased high BY CONSTRUCTION and the winning row happened to divide two arms measured at different moments; fixed by making the claim comparative and about the deepest footprint. (2) "The useful rate falls monotonically with the stride" -- the artifact printed that sentence and it is FALSE: two runs out of four measured stride 8 FASTER than stride 4 (8.05 against 4.71 GB/s) because at the dense end both strides use every byte of every line they fetch, so those rows differ only in the loop's own per-element overhead; the artifact now claims what holds, that the rate COLLAPSES across the range (23x dense to sparse) and that the line rate is the monotonic one WITHIN the dense range. (3) A BAND THAT INCLUDED THE LOOP: the write-allocate check took the below-L3 band maximum from the 16 KiB row where a read sweep completes a line in 0.196 ns -- that is the loop, not the memory -- and including it made a real 2.44x step fail a check about a step; the band's floor is now a STATED EXCLUSION at 256 KiB, "cache-resident but not loop-limited"
- [x] P1 2.2.79 The course's fourth and most important limit is a CLAIM THAT WITHDRAWS ITSELF, and the withdrawal is the lesson: `MADV_HUGEPAGE` is a HINT, khugepaged is asynchronous, and the same madvised mapping measured **786 432 KiB** collapsed (384 x 2 MiB pages, huge-page arm 1.13x packed against 2.94x for the 4 KiB arm) on 2026-09-27 20:54 and **0 KiB** on 2026-09-28 19:16 (2.62x against 2.54x, i.e. no effect at all) on the same machine twenty minutes later. A mapping that did not collapse is INDISTINGUISHABLE from one that did to every other number in the table -- the line counts, footprints and L1 sets are identical by construction -- so the artifact reads /proc/self/smaps at the moment of the claim, reports which of the two happened, and WITHDRAWS the claim rather than averaging over it; crosscheck asserts the withdrawal is present, and BOTH branches were exercised (109/109 on the captured runs where the mapping did collapse). Also three machine facts that bound what the course may claim at all, each proved rather than assumed: there is NO HARDWARE PERFORMANCE COUNTER (a forked child executing RDPMC dies of SIGSEGV, `perf_event_paranoid = 4`), so no miss, fill, page walk or stall can be COUNTED here and every number is a two-sided bound by timing; the TSC is invariant at 2.2960 GHz across a sleep and 2.2957 across a busy loop while the core clock swings 1427-2745 MHz INSIDE ONE RUN, so a TSC tick is time and not cycles and every load-bearing number is a RATIO; and `/sys` reports CAPACITY but not the REPLACEMENT POLICY, so the shape inside the thrashing regime (worst row at 9 lines, not 32) is explicitly not explained. Deliberately not claimed: any absolute cycle count, how many lines were missed/filled/walked, the replacement policy, why the L3 band widens, the bandwidth of an L2-resident region, and -- named here because the roadmap assigns it elsewhere -- cache coherence, NUMA and multiprocessor memory, which is the subject of the *Multiprocessor Architecture* course
- [x] P1 2.1.70 "Exceptions, Privilege and Mode Changes" course COMPLETE: 8 concepts in 4 modules, 204 minutes. Depends on isa, exe, img and sec, and is scoped to a gap that is total rather than thin: a word-boundary grep over the ~68 concept files the two preceding CPU courses left behind found `ring 0`/`ring3` 0, `GDT`/`IDTR` 0, `CR0`/`CR3`/`CR4` 0, `CPL`/`RPL`/`DPL`/`IOPL` 0, `TSS` 0, `EFER`/`RFLAGS` 0, `sysret`/`iret`/`sysenter` 0 and `context switch` 0, while `privilege` appears in 4 files and means something else in three of them (prepositions/idioms, JVM inner classes, Mach-O "unprivileged") and `syscall` in 4 as an ENCODING, a NOUN in the vDSO concept, and a CALL the ELF loader makes. So every word in the course's own title appears zero times -- and five earlier courses POINT at this one and none answers it, the sharpest being img_vdso.ch, which says entering a syscall is expensive to ENTER and leaves the why hanging. F1 is the hook and the whole privilege story in one asymmetry: SIDT returns base 0xffffffff00000000 and limit 65535 (4096 entries) and reading one byte of the table it points at kills a FORKED CHILD with SIGSEGV, so the register is readable and the table is not -- and 4096 is a BOUND set to the largest value a 16-bit limit can hold so that `int 0xNN` with any byte is a bounds check and not a wild read, a security decision wearing a number's clothes. F2 is a silent wrong reading: the 10-byte pseudo-descriptor is BASE-FIRST at offset 0 and limit-second at offset 8, and read the documented way round it returns base 0xffffffffffff0000 and limit 0 with no fault and no impossible value -- a limit of 0 being INDISTINGUISHABLE from a kernel that installed an empty IDT, which makes the wrong reading not merely wrong but UNFALSIFIABLE. F4 is the load-bearing measurement: same function, same argument, same answer, the only difference being whether the CPU changed privilege level, clock_gettime costs 1668.8 ticks through SYSCALL and 60.4 through the vDSO, a 27.65x ratio that IS the cost of a mode change with everything else held constant -- and the first pair (int $0x80 at 4.92x) is a TRAP the artifact explicitly declines to explain, because the I/O port accesses that the i386 ABI uses are executed by the KERNEL'S STUB and not by the INT instruction, so the measurement cannot separate the hardware entry from two different kernel stubs. F5 is a documented vendor disagreement rather than a bug: SYSENTER raises #UD on this AMD part, Intel SDM Vol 2B lists it as VALID in 64-bit mode, AMD64 APM Vol 2 sec 6.1.2 says it is illegal in long mode, BOTH ARE CORRECT, Linux encodes the split in kvm/emulate.c and QEMU commit c046a42c does the same, and no erratum exists against either company. F7 is the course's central result and the one that is both exact and surprising: the first rejected address is 2^47 MINUS (access size MINUS 1), measured as a 12x3 matrix and confirmed by three independent bisections, because the CPU validates the whole byte range of an operand rather than its first byte -- an 8-byte read dies seven bytes early and a 1-byte read gets right up to the line -- which is also WHY a non-canonical access is not a page fault: it never becomes an address, so the kernel reports si_addr = 0 and a handler that reads si_addr before si_code concludes the process dereferenced NULL. F8 measures what the error code costs: four DIFFERENT protection failures (write to a read-only page, execute of a non-executable page, read and write of a PROT_NONE page) are ALL si_code 2 and indistinguishable from ring 3, so bits 1 (W/R) and 4 (I/D) -- exactly the two a demand-paging system needs for copy-on-write and executable mappings -- are invisible, while the one distinction si_code does make, 1 against 2, is mapped-against-not. Serves 8 concept routes plus the landing, all 200, with 19 internal links resolved across seven courses, prev/next chain and manifest minutes verified by tools/verify_priv.py; all 18 course landings still 200
- [x] P1 2.2.81 EIGHT retractions for the privilege course, all eight PRINTED by the artifact in section 8 and all eight ASSERTED AS TEXT by crosscheck.py group H so a taken-back claim can be neither quietly dropped nor deleted, and the second is the sharpest thing in the course because it is a wrong belief that ALMOST produced a right story. (1) "The argument count explains the SYSCALL/int 0x80 gap" was NEVER CLAIMED and the reason is the lesson: the first draft measured the same syscall with 0 and with 6 arguments expecting int 0x80 to get worse, and it cannot, because the port accesses are in the KERNEL'S i386 STUB and the port count is set by the syscall's DECLARED ARITY, which a caller cannot vary at all; the experiment was REMOVED rather than reported, because an experiment that cannot answer its question is not data, and it was replaced by the vDSO arm which holds everything else constant. (2) "SYSENTER from ring 3 raises #GP(0)" is NEVER TRUE on either vendor -- SYSENTER has no CPL check at all, it is unprivileged BY DESIGN, and Intel's only #GP(0) is a null IA32_SYSENTER_CS; the author wrote this into a draft, measured #UD, and nearly published a story in which the two cancelled out, and they did not, because the #UD is AMD having removed the instruction from long mode and has nothing to do with privilege: TWO WRONG BELIEFS PRODUCING A RIGHT OBSERVATION IS NOT EVIDENCE. (3) "4096 entries means 4096 interrupts" -- the limit is a bound. (4) "si_addr is the address the CPU faulted on" -- it is the address the KERNEL chose to report, and for a non-canonical access there is none and it reports 0. (5) The SIDT field order, which does not tell you it is wrong (see 2.1.70). (6) "memset on a struct a signal handler writes is fine" -- memset takes void*, so its writes to a volatile object are not volatile-qualified and the compiler may elide them; the handler's record then held values from a PREVIOUS probe and the bisection converged on a boundary INSIDE A SINGLE PAGE, 0x7ffffffffffc/0x7ffffffffffd, which is impossible, and printed it with total confidence beside a tidy three-row summary, so the wider lesson is that a measurement harness whose intermediate state is not volatile will hand you a plausible wrong answer rather than a warning. (7) "__ehdr_start is the vDSO" -- it is a glibc symbol holding the base of the MAIN EXECUTABLE's header; the artifact read it, printed fourteen program headers and an e_shoff past the end of the text, and reported every one as a vDSO fact, all true and all about the wrong image, and the reason it was so easy is that a PIE main executable and a vDSO are BOTH ET_DYN, BOTH EM_X86_64, and BOTH carry a plausible fourteen-entry program header table, so the section now prints both addresses on adjacent lines. (8) "The canonical boundary is the address 2^47" -- not as a statement about an access; it is 2^47 minus (size - 1)
- [x] P1 2.2.82 FOUR retractions of the privilege course's HARNESS, kept because a check that fails for the wrong reason teaches its reader to ignore it, and the standing instruction attached to them is that NONE WAS FOUND BY READING THE HARNESS -- all four were found by running it. (1) A LINE-BREAK TRAP that failed four checks at once, three of them about RETRACTIONS: the artifact wraps prose at about 78 columns, so "READ FROM THE MANUAL, not measured" is two lines in the file and the harness searched for the sentence; the worst kind of harness failure, because it teaches a reader to distrust a harness that was RIGHT, fixed by matching against a whitespace-normalised copy while the numeric parses still run on the original (collapsing whitespace there would join adjacent table columns). (2) A HEX PARSER THAT COULD NOT HOLD HEX: the extractor returned floats because that is what it had always done, and crashed on the first 0x.. it met. (3) A TRUNCATING EXTRACTOR: the same helper returned only the first capture group, so a check that wanted two hex numbers got one AND COULD NOT FAIL. (4) A PERCENTAGE TREATED AS A FRACTION: the noise floor is printed as 25.5 meaning 25.5%, and a ratio check compared against 1.0 + 25.5 and required a result under 56, a bound so loose the check was incapable of failing. The noise floor itself is 19-57% on this loaded guest, which is why the harness asserts STRUCTURE exactly -- the ten IDT bytes, the 12x3 access-width matrix, the six fault-row outcomes, the eight retractions -- and TIMINGS only as orderings and as ratios that clear a floor the artifact measured and printed itself
- [x] P1 2.1.71 "Multiprocessor Architecture" course COMPLETE: 7 concepts in 4 modules, 179 minutes. Depends on mem, exe, isa and priv, and is scoped to an UNPAID hand-off rather than a thin gap: the memory course measured false sharing at 61.9x and then DISCARDED every row where both threads landed on one physical core, giving as its reason that "two SMT siblings share L1 and L2 and are a different measurement" -- it used the term four times across two files and never once defined it, and its own limits block named "cache coherence, NUMA, and multiprocessor memory" as this course's subject and never returned. A word-boundary grep over the four preceding CPU courses confirms the rest is absent: `MESI` 0, `snoop` 0, `cache coherency` 0, `memory barrier` 0, `total store order` 0, `lock xadd` 0, `cmpxchg` 0, `spinlock` 0, `rseq` 0, `sched_setaffinity` 0, `hyperthreading` 0; all 13 hits for `coherence` are unrelated senses ("a coherent one", "the story would be coherent", "a coherent design") except one forward reference; the `fence` hits in the exe and mem courses are a TIMING TECHNIQUE and never ordering. The course is scoped by F1, the topology, and its cross-check is the model: for every cache level, the artifact parses `shared_cpu_list` and counts how many of the named CPUs the TOPOLOGY subsystem places in one core_id group, because those are two files written by two kernel subsystems and a check that read the same file twice would agree with a wrong answer -- 3 of 3 levels AGREE, and 6 cores x 2 threads = 12 exactly. F2 is the course in one ratio: rows A, B and C use the IDENTICAL instruction on the IDENTICAL machine and only the memory address changes, giving A = the floor, B (one shared line, TRUE sharing) = 13.05x A, C (two longs 8 bytes apart in one line, FALSE sharing) = 10.92x A, and therefore B/C = 1.19x (0.97, 1.03, 1.19 across three recorded runs) -- IF THE COST OF TRUE SHARING WERE IN THE DATA, C WOULD BE NEAR A, AND IT IS NOT, SO THE COST IS IN THE CACHE LINE, which is also why a per-thread counter is padded and why `__attribute__((aligned(64)))` is real engineering. F3 separates the two costs that are constantly conflated: an UNCONTENDED `lock xadd` on a private line costs 2.54x a plain store with no other thread running, and that is NOT coherence because there is nothing to be coherent with -- it is the full barrier the prefix implies, paid by a thread with no reason to pay it -- and the cost of CONTENTION is a subtraction worth more than either number, 22.03 minus 2.64 = 19.39 ticks = 7.33x the uncontended cost. F4 is a row that REFUSED to reproduce its expected shape and is the second-most-quoted result: F writes a worker's own line then opaque-loads the peer's, which naively is a ping-pong with a transfer per iteration, and it measures 0.64x row A, CHEAPER than no sharing at all, because a store does not invalidate the other core's copy when it EXECUTES -- it enters the store buffer and the peer's copy stays valid until the store RETIRES, so two unsynchronised threads do not take turns; the fast path and the slow path look the same on average, which is the profile of a heisenbug and the reason data races are hard to find. F5 makes NUMA measurable by its ABSENCE (one node, `node0 cpulist = 0-11`): coherence is a question between two caches and NUMA is a question between a core and a memory controller, nothing shared and nothing owned, and the artifact names its OWN harness gap on a two-socket machine rather than hiding it. Serves 7 concept routes plus the landing, all 200, with 19 internal links resolved across five courses, prev/next chain and manifest minutes verified by tools/verify_smp.py; all 19 course landings still 200
- [x] P1 2.2.84 SIX retractions for the multiprocessor course, all six printed by the artifact in section 7 and all six asserted as TEXT by crosscheck.py group G. (1) "The plain-store arm measured 1.75 ticks per operation" -- it measured NOTHING: written as a relaxed atomic store to a variable nothing ever read, the compiler proved the whole four-million-iteration loop dead and the result was a plausible number for four million operations that did not happen, which is the THIRD course in a row to hit this in this form, and the general rule is now in the artifact's header: WHEN TWO THINGS MEASURE AS SIMILAR, THE FIRST HYPOTHESIS IS THAT YOUR OPTIMISER DELETED THE DIFFERENCE. (2) "Two threads on unspecified CPUs is a measurement" -- and the difference from the memory course's own filter is that here the check is the MECHANISM, every worker calling sched_getcpu() and the repetition being discarded if either thread is anywhere but where it was pinned. (3) "False sharing is a 61.9x effect" -- the number is the memory course's and is correct THERE; it is not restated as a property of this machine because the ratio depends on the body, the width and the clock, and re-publishing it would be the remembered-number mistake the harness exists to prevent. (4) "An uncontended lock is expensive because of coherence" -- RETRACTED TO THE WRONG REASON: it is expensive and section 3 separates the two costs cleanly, but it is not coherence, there is no other thread and nothing to be coherent with, and the real cost is the barrier the prefix implies. (5) "`lock` is one idea that could have been three" -- the sharpest, because it is a CORRECTNESS finding and not a measurement one: x86-64 ties atomicity AND ordering to one prefix so every atomic is also a full barrier, AArch64 makes them separate instructions and RISC-V makes them a fence with chosen edges, and therefore A LOCK-FREE ALGORITHM WRITTEN ON x86-64 IS CORRECT PARTLY BY ACCIDENT -- it relies on an ordering guarantee it never asked for because the hardware supplied it for free, and porting it to a weakly-ordered machine breaks it in a way the tests that passed will not find. (6) "A placement check is a filter you apply afterwards" -- applied afterwards it cannot tell you WHY a thread was in the wrong place, and on a loaded machine it silently converts every row into a discarded row while the run still looks like it worked
- [x] P1 2.2.85 FOUR retractions of the multiprocessor course's HARNESS, and the standing instruction attached to them is that NONE WAS FOUND BY READING THE HARNESS -- all four were found by running it. (1) A CHECK THAT ASSERTED SOMETHING THE DATA CONTRADICTED, and the sharpest of the four: the first version required the SMT row D and the two-core row A to DIFFER, because the artifact's prose said SMT costs a modest penalty, and measured D/A came out at 1.07, 1.08 and 1.01 on the three recorded runs -- the rows are the same, the check was wrong and the measurement was right, and the consequence was that the prose was WRONG TOO and was rewritten to report the honest and narrower conclusion that this experiment does not show what SMT costs (row E, which puts two threads on one core on purpose, is the one that does show a cost, at 1.84x). (2) AN ORDERING THE MEASUREMENT DID NOT SUPPORT: the check required the plain-store row to be the cheapest in the table, and it was not (0.82x), so the check is now on closeness rather than ordering, because a check that fails whenever the noise is unlucky is worse than no check -- and the underlying measurement is not lost, section 3 measuring the locked-versus-unlocked difference properly with nothing else in the run and getting 2.54x. (3) ONE HELPER, TWO INCOMPATIBLE JOBS: the row extractor returned a single capture group, so a row with a label and a value handed the label to float() and raised -- the same error the previous course's harness committed as a hex extractor returning floats. (4) A COMPARISON THAT UPPERCASED ONLY ONE SIDE: `"IDENTICAL instruction" in FLAT.upper()` can never be true because the search string keeps its lower-case i, and it failed on text that was demonstrably present, which is the failure mode that trains a reader to distrust a harness that was RIGHT. And one more, committed by the harness about itself: the first draft of its COMMENTS transposed the B/C and D/A sequences, and nothing polices a harness's prose, only its output -- which is why the harness concept teaches that as a point rather than fixing it silently
- [x] P1 2.2.86 `courses/smp/assets/samples/smpbench.c` plus `crosscheck.py`, 73 checks in 8 groups, and three design positions are the transferable part. (1) EVERY CLAIM IN THE ARTIFACT IS ABOUT A *PAIR*, and the pin is VERIFIED rather than assumed: each worker calls pthread_setaffinity_np and then reads sched_getcpu() from inside the worker, and a repetition whose two threads are not where they were pinned is DISCARDED AND COUNTED, because a placement check applied afterwards cannot tell you why a thread was in the wrong place and silently converts every row into a discarded row while the run still looks like it worked. (2) THE BODIES ARE INLINE ASM and that is not stylistic: the plain-store arm written in C was optimised to death, the ping-pong arm written as __atomic_load_n was hoisted out of the loop and came out FASTER than the no-sharing floor, and a THIRD instance of the same bug appeared when `static long g_line[MAXCPUS] __attribute__((aligned(64)))` aligned the ARRAY rather than the ELEMENTS, which made the "one private line each" rows false-sharing rows wearing a different label and more expensive than the genuinely shared one -- an attribute on a 1-D array is a statement about the array, and the same trap the execution course measured as a benchmark function 2.7x slower when unaligned. (3) THE CENTRAL CLAIM IS ASSERTED AS A SHAPE, NOT A VALUE: B/C must be near 1 WHILE both B and C must be far above the floor A, which is machine-independent even though neither number is, and the ratio moved 0.97/1.03/1.19 across the three recorded runs, so asserting the value would be a remembered-number check. The limits block is printed rather than footnoted and names the instrument that would settle what is missing: there is NO PMU (perf_event_paranoid = 4), so nothing here is a count of coherence traffic and every number is a DURATION, which bounds a count without measuring it -- a weaker position than the memory course, which could at least bound a miss count from two sides
- [x] P1 2.2.83 `courses/priv/assets/samples/privbench.c` (1302 lines) plus `crosscheck.py` (88 checks in 9 groups), and the three design positions are the transferable part. (1) The artifact's FIRST TWO SECTIONS ARE ABOUT THE INSTRUMENT: it measures the TSC rate busy and across an 80 ms sleep and prints the drift (0.001% on this machine, so a TSC tick is TIME and every cost is a RATIO), it prints /proc/cpuinfo's cpu MHz for ORIENTATION ONLY and never uses it (the execution course converted timings with it and was wrong by up to 3x because the value is refreshed far more slowly than a measurement), and it measures the spread of its OWN ESTIMATOR before any claim. The first version of that floor was a volatile increment loop and reported 81% REPRODUCIBLY, which meant it was not noise at all: an arithmetic loop is bounded by the core clock, the TSC is fixed-rate, and a clock ramp therefore reads as noise that is really the clock -- so the body was changed to a 256 KiB POINTER CHASE, which spends its time waiting on a load and is therefore insensitive to the frequency, and the general lesson is stated in the file: what a benchmark's noise usually is tells you which part of the machine the benchmark is actually measuring. (2) EVERY EXPERIMENT WHOSE EXPECTED OUTCOME IS A FAULT RUNS IN A FORKED CHILD, because an earlier artifact executed RDPMC in the parent and killed every measurement in the run with it. (3) It PRINTS ITS OWN LIMITS AND ITS OWN RETRACTIONS, because a tool that prints only the headline is what every datasheet already is, and the limits name the things that would settle the missing measurements -- the error code the CPU pushed, whether SMEP/SMAP are ON rather than REPORTED, the IA32_STAR/LSTAR/SFMASK values behind a root-only /dev/cpu/0/msr. `crosscheck.py` reads the OUTPUT and deliberately asserts almost no numbers: the docstring gives the reason in the measurement's own terms, a 19-57% floor can verify a SHAPE and cannot verify a VALUE and a bare-number threshold is a check that fails on a busier machine. Group F is the one that asserts the course's central result EXACTLY and as a SHAPE: the access-width matrix must be a clean 1-then-128 staircase in each column with the cut index strictly decreasing as the access widens and at offsets 0, -3 and -7, so a check that asked "is the 8-byte row equal to 128" would be asserting one cell of a rule and would not notice if the other eleven were rewritten. The artifact's own six-row fault table had to be rebuilt twice -- once because a fault longjmps past the munmap and leaked one page into five later rows, and once because the row meant to be UNMAPPED used the constant 0x60000000, which is inside the process's own PIE image, and a second attempt to find a gap in /proc/self/maps found none because a PIE process has almost no gaps; the fix was neither a better constant nor a better scan but to MAP a page, UNMAP it, and read that, since the address that is certainly unmapped is one the process has just unmapped
- [x] P1 2.1.72 "SIMD and Vector Processing" course COMPLETE: 7 concepts in 4 modules, 186 minutes. Depends on mem, exe, isa, priv and smp, and is scoped to an UNPAID hand-off rather than a thin gap: exe_deps.ch says a loop unrolls into "multiples of the SIMD width" and exe_latency.ch says the same work is done "in SIMD", both using the phrase as a known quantity, while a word-boundary grep over the five preceding CPU-architecture courses finds `lane` 0, `XMM`/`YMM`/`ZMM` 0, `NEON` 0, `emmintrin` 0, `vectoriz*` 0, `mask register` 0, `k register` 0, `FMA` 0, `avx2` 0, `float point` 0, `SIMDe` 0, `scatter` 0 and `horizontal add` 0; all 8 hits for `SIMD` are either the vector-19 EXCEPTION in priv_vectors.ch, the spelled-out phrase in two landing pages, or the WebAssembly `simd` PROPOSAL in the wasm course, and ZERO of them teach it; all 6 hits for `AVX`/`AVX-512` are the ISA course and every one is about the `0x62` EVEX prefix versus `BOUND` -- that course taught what byte introduces an AVX-512 instruction and never said what the instruction does; and the two `gather` hits are a reading-comprehension passage about bees gathering nectar and a linker step that collects symbol tables. F1 is the course in one sweep: the same 4-wide arm over the same statement at five working-set sizes gives 3.89x at 2 KiB (inside the 32 KiB L1) and 1.14x at 24 MiB (past the 16 MiB L3) -- THE LANE COUNT DID NOT CHANGE, and the difference is that the VECTOR arm's cost went up 7.25x while the SCALAR arm's went up only 2.13x, so a wide loop does the same work in a quarter of the instructions, which is worth nothing once the bottleneck is bandwidth rather than the instruction rate. F2 is a NULL that is a result: the compiler's auto-vectorised arm of a plain C loop and a hand-written 4-wide intrinsic loop came out at 3.90x and 3.90x -- indistinguishable -- and FMA halves the arithmetic instruction count for 1.00x, because an extra instruction you did not need costs a fetch and a decode slot on a loop that is not short of either. F3 is the same argument at 2.78x, where it is much more expensive: `vpgatherdd` is 2.78x FOUR ORDINARY SCALAR LOADS, because it is one instruction doing four INDEPENDENT loads and independent memory operations cannot be overlapped, which is why the hand-written gather at 2.06x a sequential loop is the portable default AND the faster one on x86. F4 is the place a 4-wide loop LOSES: a horizontal add of four doubles costs about as much as the vector operation that produced them, so reducing once at the end is 1.00x and reducing every group is 1.45-1.48x, and the scalar loop it replaces is 3.99x -- which is why the answer is four accumulators and ONE fold, and why a tree reduction's logarithmic DEPENDENCY CHAIN is the real argument (log2(N) against N) rather than the instruction count. F5 is three costs that are all about the ADDRESSES: an unaligned 32-byte vector load is FREE on this machine at two working-set sizes (all three alignment arms within 6%, one of them faster, and the 2 MiB arm with no consistent direction across three runs) while `_mm256_load_pd` on the same +8 address RAISES SIGSEGV in a forked child, so the requirement is a FAULT requirement and a duration table is the wrong instrument for it; the tail table has the SCALAR remainder at 1.02x, free, the clever OVERLAPPING last iteration at 1.77x and the WORST arm in its own table, and the arm that writes two elements past the end at 1.09x and a bug -- and the two controls turn that from a story into an argument, since a FULL 32-byte overlap is 1.10x and a PARTIAL overlap load is 1.31x, so the cost is the half-overlapping load that cannot be store-forwarded, and the mechanism is marked INFERRED because there is no PMU. Serves 7 concept routes plus the landing, all 200, with 22 internal links resolved across seven courses, prev/next chain and manifest minutes verified by tools/verify_simd.py; all 11 course verifiers still report ALL CONSISTENT
- [x] P1 2.2.87 EIGHT retractions for the SIMD course, all eight printed by the artifact in section 8 and all eight asserted as TEXT by crosscheck.py group H; five of the eight were found by RUNNING the artifact rather than reading it. (1) "The memory-operand arm measured 3.3, so the FMA memory form is broken" -- the ARM was wrong and the CHECKSUM is what said so: the first version used `vfmadd231pd`, which computes B*C+A rather than A*B+C, and the table was entirely readable with a plausible ratio; the general form, which has now recurred four courses in a row, is THAT AN EXPERIMENT THAT CAN SILENTLY COMPUTE THE WRONG THING MUST PRINT WHAT IT COMPUTED. (2) "The absolute nanosecond figures are the result" -- the first version divided ticks by a HARDCODED TSC rate, and even measured, the absolute ns/iter for the same body moved by a factor of 1.7 BETWEEN RUNS on the recorded day while every ratio moved by less than 10%, which is why the harness asserts shapes. (3) "Four lanes is 2.2x, not 4x, because the loop is memory bound" -- the story the course was DRAFTED AROUND, and it did not reproduce: at 1536 bytes the 4-wide arm is 3.89x because 3 loads and 1 store per 4 elements really do get 4x cheaper when the load ports are the bottleneck; the claim turned out to be true of a DIFFERENT WORKLOAD and section 3 is its corrected version, so the lesson survived and the sentence did not. (4) "vhaddpd adds adjacent lanes" -- IT DOES NOT: it adds the CORRESPONDING lanes of its two sources within each 128-bit half, so `vhaddpd(v,v)` DOUBLES v, and the first version reported EXACTLY TWICE the true sum to the last bit; a SECOND BUG WAS HIDDEN BEHIND IT, because the tree reduction added the two 128-bit halves of an already-paired register so both lanes held the total and it was added to itself, also exactly twice -- TWO BUGS, ONE SYMPTOM, ONE LINE OF OUTPUT, and the general danger is that an error which is approximately wrong announces itself while one which is EXACTLY wrong is stable across every re-run and cannot be detected by measuring more carefully. (5) "The reduction table compares four ways of summing" -- three of the five arms were not summing, they were computing a sum of RUNNING TOTALS, and the first version reported ratios between different computations as though they were costs of one. (6) "An unaligned vector load is slow" -- NOT ON THIS MACHINE at two working-set sizes, and the general form is to CHECK WHETHER THE THING FAULTS BEFORE ASKING HOW SLOW IT IS. (7) "The compiler declined to vectorise because the trip count is a runtime variable" -- WRONG, AND IT WAS AN INFERENCE FROM A TIMING: the named-array form vectorises at BOTH trip counts and the pointer form at NEITHER, so the trip count costs a scalar EPILOGUE (free, and the tail table measures it) while the pointers cost the VECTOR LOOP ITSELF, because the compiler cannot prove that a store to A[j] does not change what B[j+4] holds; the same draft also claimed the compiler hoists the loop-invariant loads of B and C, and the disassembly shows them loaded inside the inner loop -- THEY ARE NOT HOISTED -- so the story was wrong twice over, the mechanism is not hoisting, and the mechanism it is usually confused with is not free, since arm F's memory-operand FMA is 1.12x SLOWER than the three-load form. (8) "The control arm came out at 3.91x, so aliasing is not what stopped the compiler" -- THE CONTROL WAS NOT A CONTROL: it was written as `static double *gA = bA, *gB = bB, *gC = bC;`, which is the same three arrays wearing a pointer costume, so gcc folded the static initialisers away, proved the streams distinct again, vectorised the control, and the control measured exactly what the arm it was meant to contradict measured; the fix was to assign the pointers in main() and reach them through noinline accessors, and the general form is THAT A CONTROL THAT CANNOT FAIL IS NOT A CONTROL AND A CHECK THAT PASSES ON AN ARTEFACT THAT WAS NOT BUILT IS WORSE THAN NO CHECK BECAUSE IT IS COUNTED
- [x] P1 2.2.88 `courses/simd/assets/samples/simdbench.c` plus `crosscheck.py`, 131 checks in 9 groups, and four design positions are the transferable part -- of which the THIRD is new to this collection and is why this course is the first one in it to need a harness that reads bytes. (1) EXACT FOR STRUCTURE, SHAPES FOR TIMING, and the exact half is genuinely exact because the lane table is ARITHMETIC rather than a measurement: all twenty-five integers are asserted against a hard-coded table AND the XMM->YMM->ZMM doubling is asserted as its own separate check, so a table that got one cell wrong while keeping the doubling would still be caught and the failure message names the register. Also exact: the five AVX-512 CPUID leaves and their being ZERO (which is what licenses the whole of module 3 to be quoted), the L1 being strictly smaller than the L3, the order of the six arms, and the presence of all eight retractions. The noise floor is measured and PRINTED before any claim is made and it came out 25.1%, 33.5% and 62.5% on the three recorded runs for the same body on the same machine, which is why nothing numeric is asserted. (2) THE CENTRAL CLAIM IS A SHAPE: the 4-wide speedup at L1 must be more than 1.8x the 4-wide speedup past the L3, the L1 row must be the maximum of the five, and even at 24 MiB it must still beat the scalar arm -- and the L1 value came out 3.89x, 3.91x and 3.70x on the three recorded runs, so asserting the value would be a remembered-number check that fails on the course's own evidence. The shape also CATCHES EDITS the value could not: a value check notices a number changed, and the shape check notices that the pointer column came back to 3.9x, which is exactly the manifest's completion criterion. (3) A CLAIM ABOUT WHAT A COMPILER DID IS A CLAIM ABOUT BYTES, AND AN INFERENCE FROM A TIMING IS NOT A MEASUREMENT OF A COMPILER -- the only new clause in the collection, and it exists because this is the first course here whose subject is partly a compiler: build_samples.sh compiles FOUR forms of one statement crossing two variables (named arrays vs three `double *` globals, constant vs runtime trip count) and appends their mnemonics to the recorded output, and the harness asserts the 2x2 rather than any speedup -- NAMED forms VECTORISED at both trip counts, POINTER forms NOT VECTORISED at either, and the trip count's real cost is a scalar EPILOGUE (named_var has one packed-double and one scalar instruction, named_const has one packed-double and no scalar one) which is the tail the artifact separately measures as free. (4) EVERY TABLE ENDS WITH A CHECKSUM, and the checksum is not an afterthought: B=0.5 and C=0.25 make A = A*B + C a FIXED POINT at 0.5 after 53 iterations in exact binary arithmetic, and 64 copies of 0.5 sum exactly, so the check is bit-for-bit rather than a tolerance, and it is the only reason the operand-order bug and the vhaddpd bug were found at all -- neither produced a suspicious timing. The limits block is printed rather than footnoted and names what is missing: perf_event_paranoid is 4 so there is NO PMU and every number in sections 2 to 6 is a DURATION that bounds a count without measuring it, and there is NO AVX-512 (five CPUID leaves, all zero) so every claim about a ZMM or a k0-k7 mask register is a manual claim with a document and NOTHING about a 512-bit register is measured. The manifest's completion criterion is to reproduce the 131 checks and then restore three static initialisers and make group D fail BY NAME
- [x] P1 2.2.89 Four documented failures of the SIMD course's own harness, all found by RUNNING it, and the first three are the same class of error the four preceding courses documented while the fourth is new to this collection. (1) A FLOOR CHECK THAT FAILED ON THE COURSE'S OWN EVIDENCE by 0.03: the check required the no-vectorise floor to be "more than twice as slow as any vector arm", but the 2-wide arm is a 2x speedup by construction, so the floor and the 2-wide arm land within a hair of a factor of two and 45.31 > 2 x 22.67 is false; it is now two checks -- the floor is the SLOWEST arm, and it is at least twice the 4-wide arms -- because a tolerance that tight is a check whose failure is noise, which is the exact failure mode rule 1 exists to prevent. (2) AN EXTRACTOR THAT RETURNED ONLY THE FIRST CAPTURE GROUP, the same class as the hex extractor in the memory course's harness and the row extractor in the multiprocessor one: a helper written for numbers was used on a row with a LABEL and a VALUE, so the label was handed to float() and raised; there are now two extractors, `one()` for numbers and `grab()` for raw strings, with the reason in a comment, plus a third real instance in the section 3 sweep where the table grew from seven columns to nine and every index shifted by one. (3) SUBSTRING CHECKS THAT FAILED ON TEXT THAT WAS DEMONSTRABLY PRESENT because of case: `"INSTRUCTION COUNT is not the cost"` can never match the artifact's `Instruction COUNT is not the cost`, and `"THREE calls in the inner loop"` can never match `THREE CALLS in the inner loop`; every such assertion now runs against a whitespace-normalised copy and in the case that matters, lower-cased. (4) NEW TO THIS COLLECTION, and the one worth keeping: A HARNESS GROUP THAT COULD NOT RUN AT ALL on two of the three recorded runs. The VERIFY block is appended by build_samples.sh rather than by simdbench, so a raw `./simdbench > run1.txt` produced a file with no disassembly and group E failed its four checks for a reason a reader could not see from the failure; the fix was to extract the disassembly into its own `verify_codegen.sh` and have BOTH the recorded run and the two extra runs go through the identical code path, because a course whose extra evidence runs are produced by different code from its first evidence is a course whose extra evidence is not comparable with its first evidence. And one more, committed by the harness about itself and taught rather than fixed: a first draft of the section 3 narrative attributed the compiler's behaviour to the trip count from a speedup, and the harness that shipped with it had no check that could have noticed
- [x] P1 2.2.80 `courses/mem/assets/samples/membench.c` plus `crosscheck.py`, the course's buildable artifact and its 109-check harness, whose design positions are the transferable part. (1) The harness DELIBERATELY asserts almost no numbers: it reads the OUTPUT of membench rather than re-measuring, and the docstring says why in terms of the measurement itself -- an instrument whose estimator spread is 14.3% can verify a SHAPE and cannot verify a VALUE, and a check whose threshold is a bare number is a check that will fail on a busier machine and teach its reader to ignore it. Every threshold is a RATIO read back out of the artifact's own output, or derived from quantities the artifact measured and printed; where a claim compares two of the artifact's own numbers (an aliasing stride against the line size, a TLB cliff against the set count) the check is that the two AGREE, which is machine-independent even though neither number is. (2) Its ONE strict parser refuses any table row whose first column is not an integer, because in the PREVIOUS course a prose sentence matched a data pattern and silently overwrote the parsed values with an empty list -- and the harness then PASSED because it had nothing to check. (3) The artifact's section 0 proves the absence of a PMU rather than assuming it, by forking a child that executes RDPMC and reporting the signal. (4) It prints its own limits and its own retractions rather than footnoting them, because a tool that prints only the headline is what every datasheet and benchmark summary already is. `run1-3.txt` ship three consecutive runs of the artifact as built, all 21/21 and 109/109, so the claims are checkable on a machine that never ran the benchmark; crosscheck resolves its default output path relative to ITSELF rather than the CWD so it runs identically from the samples directory and from the repository root, because tools/verify_mem.py invokes it from there and a harness that only works from one directory is a harness that silently stops being run
- [x] P1 2.1.73 "x86-64 Assembly and Encoding" course COMPLETE: 5 concepts in 2 modules, 127 minutes. Depends on isa, exe, priv, simd and smp, and is the FIRST of the four courses `docs/x86-64-section-plan.md` splits the old 22-concept x86-64 item into, so it is scoped by the section's own rule that the comparison lives in the neutral courses and the depth in the per-arch ones: a word-boundary grep over all 21 shipped courses finds `SUB` `CMP` `MOVZX` `LEAQ` `SHR` `ROL` `SETcc` `CMOVcc` in ZERO files, `AT&T` `Intel syntax` `disassembl` in zero, `addps` `addpd` `movaps` `pxor` in zero, `red zone` `callee-saved` `caller-saved` `GPR` in zero, and `EFLAGS` in only 2 files and both as a ROLE rather than a bit layout -- and the seam is exactly what the plan says it is: the ISA course covered only FOURTEEN `0f xx` opcodes and met VEX and EVEX only as PREFIX BYTES in the `0x62`-is-`BOUND` collision, having taught what byte introduces an AVX-512 instruction and never what the instruction does. F1 is the course in one table, and it is the bottom half of it: eight ADD/SUB in a dependency chain against eight independent ones gives 3.65x and 3.25x, while eight CMP and eight TEST -- eight WRITERS OF THE ONE FLAGS REGISTER -- give 0.86x and 0.78x, SO THE ARCHITECTURAL SERIALISATION BETWEEN FLAG WRITERS COSTS NOTHING HERE, because the flags are renamed, and the two claims are printed separately because the numbers are a measurement and the renaming is a CITATION and no user-mode program is allowed to observe the second; the general form is that the ISA says the six instructions write the same REGISTER, which is a different sentence from the one the first draft asserted. F2 is the sharpest experiment in the collection and it is NOT A TIMING: a `cmovl` whose condition is FALSE, reading a source operand on a page marked PROT_NONE, KILLS THE CHILD WITH SIGSEGV, while a not-taken `jl` over the same page does not, with a taken branch as the control that proves the page was unreadable -- so a failing conditional move still reads its source and a failing branch touches nothing, and the REGISTER results are identical (the idiom computes a maximum, so both paths end at the larger value) which is why no stopwatch could ever have found it and why the artifact asserts the observation rather than the correctness. F3 is a REVERSAL of the course's own draft and the most widely repeated sentence about VEX: the three-byte form is NOT for 256-bit registers, which the two-byte form names perfectly well via bit 2 of byte 1, and the assembler emitted `c5 fc 58 ca` for `vaddps %ymm2,%ymm0,%ymm1` DURING THE RUN THAT PRODUCED THE PAGE; the three-byte form is for FOUR register numbers and for a fourth operand (`vpalignr` is `c4 e3 79 0f ca 0f`), which is the same wall one generation later and the reason EVEX is three bytes. F4 is the second headline and it is a two-column table: 768 opcode slots of the `0f`, `0f 38` and `0f 3a` maps probed by writing REAL PREFIX BYTES into real files and asking binutils to decode them, once legacy and once with a three-byte VEX in front of the same escape, giving `0F` 218 legacy / 101 VEX, `0F38` 28 / 125 and `0F3A` **2 / 54** -- so the two NEWER maps are the EMPTIEST part of the encoding in their legacy form and half full with one byte in front, which is the exact opposite of the drafted story and is what the `mmmmm` FIELD is for. F5 is the standing lesson at x86 width and it is INFERRED for want of a counter: a one-, two- and three-instruction vector add are within a small factor of each other with the ORDER moving between runs, so the copy that the three-operand form removes was FREE on this machine and the encoding is a SOURCE-LEVEL feature that no duration here can price. Serves 5 concept routes plus the landing, all 200, with the prev/next chain and manifest minutes verified by tools/verify_x86asm.py, which also runs the artifact's 155-check harness
- [x] P1 2.2.90 FOURTEEN retractions for the x86-64 assembly course, all fourteen printed by the artifact in section 6 and all fourteen asserted as TEXT by crosscheck.py group H, in numeric order, so a taken-back claim can be neither quietly dropped nor reordered. (1) "The three-byte VEX form exists because the two-byte form cannot name a 256-bit register" -- RETRACTED, `L` is bit 2 of byte 1 and `as` emitted the two-byte form for the 256-bit add, so the sentence is false and it is in a great deal of documentation. (2) "LEA is one instruction doing the work of three, so it is the fast way to compute an address" -- RETRACTED: the two forms measured the same, and the seventh-repetition spread is the real number, because three runs of the SAME artifact produced single-pair ratios of 2.00x, 0.55x and 2.77x for the SAME two arms on the SAME machine. (3) "LEA is the cheap way to multiply" -- NEVER TRUE, and the assembler says so rather than the artifact: `as` refuses `lea 0(%rdi,%rsi,3),%rax` with "expecting scale factor of 1, 2, 4, or 8", a refusal that `build_samples.sh` CAPTURES into `scale3.txt` rather than the prose quoting it, because a captured diagnostic is a measurement and a quoted one is a claim. (4) "The setcc row is the cmov row with one more instruction" -- it is FIVE, because `setcc` writes a BYTE and the byte has to become a value, so the arm that looks shortest in a manual has the most instructions on the page. (5) "The branch is more expensive than the cmov, so prefer cmov" -- RETRACTED TO THE OPPOSITE SIGN (1.77x and 3.08x against the branch), and the general statement is true and is NOT measured because the counter that would settle it does not exist; an arm mixing a predictable and an unpredictable branch was written, measured and DELETED rather than reported, because it measures a blend nothing here can decompose. (6) "The shift-count table shows the variable form is a win" -- the row that makes it look like one is `cl=63` with no clear, which is the BUG being measured, and it came out cheaper, dearer and equal on three runs, so a timing table cannot tell a fast instruction from a deleted one; the bit pattern settles it and `cl=64` is a shift of zero because the count is masked to six bits. (7) "CMP and TEST form a dependency chain because the ISA says they share the flags register" -- see F1. (8) "The eight-nop control is the loop overhead, so a cost is its row minus the control" -- RETRACTED because the subtraction produced NEGATIVE costs beside positive ones in the same typeface, and the artifact now CHECKS the claim by printing which rows came in below the control instead of asserting it. (9) "The map counts are how many instructions x86-64 has" -- they are how many slots binutils 2.46 NAMES, and a name in a decoder is not a guarantee and a hole is not a gap. (10) "The unaligned 32-bit vector load is free" -- NOT A CLAIM OF THIS COURSE: the vector course measured it on this machine and this file neither re-measures it nor restates its number, because re-publishing another course's measurement is the remembered-number mistake this course's harness exists to prevent. (11) "The EFLAGS table is a table of claims" -- it WAS, silently: a later inline-asm block used CLTD, which writes EDX, without saying so in its clobber list, so the compiler trusted the comment, the DIV destroyed an EFLAGS read taken five lines earlier, and the table printed 0x1 -- a carry from another operation -- beside five correct rows with nothing failing. (12) "0F 38 and 0F 3A are nearly full because the designers knew the map would be consumed" -- RETRACTED AND REVERSED, see F4, and the part about intent is marked a STORY rather than a finding. (13) "The three-operand VEX encoding removed a real instruction from a real loop, so it bought a real speed-up" -- RETRACTED and the retraction is the point, because the one-, two- and three-instruction arms are within a small factor with the ORDER moving, and the tell was the CONTROL row sitting at the bottom of a table whose story ran upwards. (14) "The artifact is correct because it runs to completion" -- see 2.2.92
- [x] P1 2.2.91 FIVE documented failures of the x86-64 assembly course's own harness, all found by RUNNING it and none by reading it, which is the sixth course in a row to establish that. (1) A BAND WHOSE WIDTH CAME FROM THE RECORDED RUN: the first version required the no-chain floor to be "within a factor of 2.5 of the chain", which passed on `x86dec.out` and failed on `run1.txt` and `run2.txt` -- the same machine and the same experiment, all three shipped with the course -- and is now the three conditions the machine actually spans (add > 2.5, sub > 2.5, cmp and test inside 0.55 to 2.0, and the two kinds at least 1.6x apart). (2) AN EXTRACTOR THAT TOOK THE FIRST TWO CAPTURE GROUPS of a pattern whose FIRST group was the row key, so every map-table row returned the key and the first number, the seven-column partition arithmetic came out with six values, and THE WHOLE GROUP SILENTLY EMPTIED AND THE HARNESS PASSED because it had nothing to check -- the fifth time in this collection that a helper written for one shape has been used on another, fixed by taking the LAST two groups with a comment saying why. (3) A PARSER THAT SPLIT A TWO-COLUMN FILE ON WHITESPACE, when both columns contain spaces because a decoder prints four operands, so the VEX column was ZERO on every row and the table printed 101/125/54 as if they meant something: a plausible table with a column that is fiction, which is why the delimiter is now a pipe and the source says why. (4) SUBSTRING CHECKS THAT FAILED ON CASE, `"IS ONE DECODE"` against a file that says "is ONE DECODE", and a companion probe that had been following two independent renames in the artifact and was left pointing at text that no longer existed. (5) A QUIET REGRESSION TOO: the artifact's inputs were loaded after section 2 had already printed, so the one line that reports the assembler's x3-scale refusal printed "(the assembler ACCEPTED it)" on a machine where the assembler had refused and said so in a file sitting right there -- a default that is also a plausible result is the worst kind of default, and every input is now read before any section runs
- [x] P1 2.2.92 `courses/x86asm/assets/samples/x86dec.c` plus `crosscheck.py`, 155 checks in 9 groups, and three design positions are the transferable part. (1) A FAULT WHERE A TIMING WOULD HAVE GIVEN A NUMBER, and the only assertion in the collection that is one: a `cmovl` whose condition is false, reading a source on a PROT_NONE page, kills the child, a not-taken `jl` does not, and a taken branch is the control that proves the page was unreadable -- so "a failing conditional move still reads its source" is a fact about the instruction rather than a cost of it, and the third concept's headline rests on a signal number instead of a ratio. (2) THE MAPS ARE READ TWICE AND THE SECOND COLUMN IS THE FINDING: 768 real byte sequences, each in its own file so a slot with a ModRM cannot eat the next slot's bytes, decoded once as a legacy escape and once with a three-byte VEX in front of the same escape, and the harness asserts the four columns as a PARTITION summing to 256 -- which is exact even though the numbers are not, and which is the check that would have caught failure (3) of 2.2.91. (3) AND THE BEST BUG IN THE FILE, which is the one worth porting: every measurement body bound its loop counter with the `"c"` constraint, which puts it in %rcx, and then counted the loop with `dec %rcx` -- so the clobber list named every register the body WROTE and not the one it COUNTED with, the compiler was entitled to believe %rcx still held the counter when the same asm statement executed a second time, `bench` runs a body five times, and so the first repetition counted correctly while every later one started at zero, `dec` wrapped it to 2^64, and the program SPUN for thirty seconds of pure user time on a table whose first two rows had already printed correctly. It is also LATENT: the same source with the surrounding loop bound changed from seven to one ran to completion in 1.7 seconds, because there the compiler unrolled and re-materialised the input, and A BUG THAT DEPENDS ON THE CODECODER'S MOOD IS NOT FOUND BY RUNNING IT ONCE. The fix is one `mov %[c], %rcx` at the top of the body and `rcx` in the clobber list, and the general form is that the clobber list is a CLAIM about what the assembly modifies and a loop counter you decrement in it is the one register you always forget. The limits block is printed rather than footnoted and names the instrument that would settle what is missing: `perf_event_paranoid` is 4 and a forked child that executed RDPMC was killed, so there is NO PMU and every number in sections 2 to 4 is a DURATION that bounds a count without measuring it, and there is NO AVX-512 so every EVEX row is a DECODER result and a FAULT result and never a timing result
- [x] P1 2.1.74 "The x86-64 ABI" course COMPLETE: 6 concepts in 2 modules, 150 minutes. Depends on x86asm, isa, exe, sec, dyn and simd, and is the SECOND of the four courses `docs/x86-64-section-plan.md` splits the old 22-concept x86-64 item into. A word-boundary grep over the 379 concept files of the 22 courses that shipped before it finds `caller-saved`, `psABI` and `MXCSR` in ZERO files and `red zone`, `callee-saved` and `GPR` in zero CONCEPT files -- the only hits are one row of the assembly course's own scan table, which reports the same zero -- so the subject is genuinely new ground; what it does NOT do is re-teach it, and the two neighbours that own its edges are linked rather than repeated: `/courses/sec/lessons/sec-canary` explains why a canary is in the frame and `/courses/dyn/lessons/dyn-order-runtime` covers the loader that builds the stack before any of these rules apply. F1 is the course's reason for existing and it is a RETRACTION of the brief that asked for it: the brief said the fourth argument of a function call goes in `%r10` "because the C ABI gave RCX to the caller's fourth argument and the hardware took RCX for the return RIP", and that sentence is TWO ERRORS WELDED TOGETHER -- measured 16 of 16 callers at -O0/-O1/-O2/-Os put argument four in `%rcx` and recover the mapping BY NAME out of a LINKED executable, and a `call` PUSHES the return RIP onto the stack (read the word at `0(%rsp)` at a callee's first instruction and it is a TEXT address while `%rsp` is a STACK address, both from ONE call because two calls would be two stack depths). What IS true is about a different INSTRUCTION, and it is the course's sharpest measurement: a bare `syscall` writes the address of the following instruction into `%rcx` BIT FOR BIT (the artifact pastes a label immediately after the instruction and compares the two as numbers), `%r11` holds the saved RFLAGS, and `%r10` comes back untouched -- which is why the Linux SYSTEM CALL convention numbers its fourth argument `%r10` and the ordinary FUNCTION CALL convention does not. F2 is a FAULT rather than a timing: one callee, exactly the `gcc -O0` prologue, with a 16-byte vector local at `-16(%rbp)`, and three arms -- `movaps` through a conforming `call` returns 0x3ff8000000000000, `movaps` through the SAME call with the caller's `subq $8,%rsp` deleted dies with SIGSEGV, and `movups` through the same misaligned call returns the same value. So the alignment rule exists because the fault exists and NOT because of a penalty, which is why the vector course's finding that unaligned accesses are free on this machine is a link rather than a repetition. F3 is the two-rules result: a `call` and a tail `jmp` want OPPOSITE adjustments because the first pushes 8 and the second does not, measured 8 and 0, and leaving the adjustment in place on a tail call does not merely misalign -- it kills the process, which is why every PLT stub in libc is `endbr64; jmp *GOT(%rip)` and nothing else. F4 is the red zone's restriction proved rather than asserted: a leaf that writes at -8(%rsp) and -128(%rsp) and never touches `%rsp` keeps both, the same leaf plus ONE `call` loses them, and the artifact reads back what replaced them and finds the callee's own return address -- THE FIRST EIGHT BYTES OF THE RED ZONE ARE THE RETURN-ADDRESS SLOT. F5 is callee-saved established BY EXPERIMENT rather than by a table: a callee that tramples r12 loses the caller's marker and a conforming one that tramples all nine caller-saved registers and pushes rbx does not; a callee that clobbers `%rbp` kills the caller with SIGBUS because `leave` is `movq %rbp,%rsp; popq %rbp`; and the two floating-point control registers point in OPPOSITE directions, with MXCSR's rounding control going 0 -> 3 across a call and the x87 precision control 63 -> 16, measured with the field masks stated because getting them wrong is how the first attempt changed the rounding mode while claiming to change the precision. F6 is the varargs lie: a caller that puts 3.5 and 4.5 in xmm0/xmm1 and then says it used no vector registers gets the PREVIOUS call's 101.25 back BIT FOR BIT -- the arguments were not corrupted in transit, they were never looked at -- and the second slot comes back 0x000000000000000a, a fragment of a pointer; reproduced through glibc's own printf as `al=0: 101.250000 0.000000`, with `al=2` as the control. AND al=1 WORKS, because gcc TESTS `%al` for zero and spills all eight when it is non-zero, so the field is a boolean and the specification's stricter reading is a lie that happens to be harmless. F7 is unwinding as a second language: 33 FDEs with `-fno-asynchronous-unwind-tables` off and 0 with it on, 71 of the directives in the corpus being the single instruction `.cfi_def_cfa_offset`, and `backtrace()` from three nested noinline functions returning SEVEN frames in one build and ONE in the other -- not a wrong answer, no answer, and the return value carries nothing that says so. Serves 6 concept routes plus the landing, all 200, with the prev/next chain and manifest minutes verified by `tools/verify_x86abi.py`, which also runs the artifact's 143-check harness
- [x] P1 2.2.93 TEN retractions for the x86-64 ABI course, all ten printed by the artifact in section 10 and all ten asserted as TEXT by `crosscheck.py` group I, in numeric order, so a taken-back claim can be neither quietly dropped nor reordered. (1) "The fourth argument of a function call goes in `%r10` because the hardware took `%rcx` for the return RIP" -- RETRACTED, see F1, and it is a correction of THIS COURSE'S OWN DRAFT rather than of a rival's, with the correct statement being the DIFFERENCE BETWEEN TWO CONVENTIONS rather than one fact. (2) "The red zone is 128 bytes of free scratch a function can use like any other" -- RETRACTED as stated, see F4. (3) "The red zone costs nothing because it is 128 bytes that were going to be cache lines anyway" -- NOT CLAIMED, the artifact does not time the red zone against a built frame so it does not know, and a plausible story is not a number. (4) "The stack must be 16-byte aligned at every control transfer, including a tail call" -- RETRACTED, see F3, and the retraction is the lesson rather than a footnote. (5) "`%al` holds the number of vector registers used, so a variadic callee reads exactly that many" -- HALF TRUE, and the wrong half is the interesting one, see F6. (6) "glibc keeps `%rsp` 16-byte aligned at 99.2% of its call sites, so the remaining 0.8% is a list of bugs" -- RETRACTED, and the number 775 of 9980 is a fact about the CHECKER rather than about glibc, because `abilint.py` loses track of `%rsp` at `pushfq`, at `enter` and at any write it does not model, and a checker that cannot account for a mismatch is not evidence of a mismatch. (7) "A conforming C program cannot be miscompiled by a wrong calling convention, because the compiler and the ABI were written by the same people" -- NOT A CLAIM AND NOT REFUTED; what section 2 establishes is narrower and is worth having, namely that the emitted code matches a written specification at four optimisation levels, which is a check anybody can now repeat in twenty seconds. (8) "The audit found no violations in a real library, so the library is conformant" -- RETRACTED, see 2.2.95. (9) "A frame description costs about ELEVEN bytes without a frame pointer and about FORTY with one" -- HALF MEASURED, HALF GUESSED, and the guess is RETRACTED: the concept page carried forty bytes before anything had been compiled to check it, and compiling the same 33 functions THREE ways says 358 bytes at `-O2`, 358 again at `-O2 -fomit-frame-pointer` (BYTE-IDENTICAL, because gcc omits frame pointers at `-O2` anyway, so the flag CONFIRMS A DEFAULT rather than changing anything) and 428 at `-O2 -fno-omit-frame-pointer` -- so a frame pointer costs about TWO bytes of table and not thirty, and the estimate was high by a factor of about three. The general form is the argument for the whole collection: a number with no instrument behind it is a claim, and this one was a claim for exactly as long as it took to run the compiler three times. (10) "The other 148 flags are unclassified" -- RETRACTED AS ARITHMETIC rather than as a claim about glibc: `271 - 26 - 97 = 148` is only valid if the two exemptions do not overlap, and a function can be BOTH a leaf and a context restorer (`setjmp` is exactly that), so `abilint.py` now reports the overlap as its own row, `CLAPPERBOTH | 3 | 151 unclassified after both exemptions`, and the true remainder is 151. The two lines of the concept page that subtracted were wrong by three out of 271 in a way NO READER COULD SEE, and would have been accidentally right had the overlap been zero -- which is precisely why the number had to be measured rather than assumed
- [x] P1 2.2.94 The finding that is a VERSION CLAIM rather than a fact, and it is labelled as one. The brief for this course asked for at least one case where the compiler disagrees with the specification, or else a demonstration that it does not on this version. The honest answer is the second and the artifact prints it in that form: on gcc 15.2.0 and binutils 2.46, reading 4,561 functions of `libc.a` and a 16-call-site corpus at four optimisation levels, no non-leaf function writes a callee-saved register without saving it and no emitted argument assignment differs from the specification. The census columns are what make that sentence falsifiable rather than decorative -- 1,670 functions WRITE `%rbx` and the checker examined 1,670 real cases, 2,555 write `%rbp`, 627 write `%r15` -- and a zero in a violation column is only meaningful next to a non-zero in a census column. 271 flags across 94 functions decompose into 26 in LEAF functions, which may clobber a callee-saved register if the compiler knows no caller had a live value there, and 97 in functions whose contract is to install a saved register context and which are therefore REQUIRED to destroy those registers; both exemptions are real and neither is checkable from inside one function, which is the honest limit of an ABI linter. The two are NOT DISJOINT: 3 of the 271 are in functions that are both, so the flags that are neither exemption total 151 and not the 148 a reader gets by subtracting. The linter measures the overlap rather than assuming it, and `crosscheck.py` asserts that R10's printed overlap is the same number section 9 measured rather than a literal typed into prose -- a retraction that restates its own figure cannot notice when the figure moves And the two numbers that DO move are not printed as results: the syscall block's addresses are elided by a `sed` in the quoted command rather than by an author, because this is a position-addressed binary and an address is not a measurement, and the saved `RFLAGS` line is dropped from the quoted block entirely because its bit 2 is the parity of a process id
- [x] P1 2.2.95 `courses/x86abi/assets/samples/abidump.c` plus `abis.S` and `crosscheck.py`, 143 checks in 9 groups, and five design positions are the transferable part. (1) A POSITIVE CONTROL EXISTS BECAUSE THE CHECKER REPORTED A HOLLOW ZERO: the first `abilint.py` reported ZERO violations across 9,255 real functions of libc, libm, ld.so, libcrypto and /bin/ls, and every one of those zeroes was empty -- the register-name normaliser had its ternary the wrong way round, so `"r12"` came back as `"e12"`, nothing was ever recognised as a callee-saved register, and the check compared nothing against anything. `control.s` exists because of that: eight functions, three of them violations on purpose in a named way, two conforming ones that must NOT be flagged, one alignment violation that must be found, and a push/pop census -- and a linter that flags everything is caught as loudly as one that flags nothing. (2) THE CONTROL WAS ITSELF WRITTEN TWICE, IN C, AND THE COMPILER REPAIRED TWO OF ITS THREE VIOLATIONS: gcc pushed `%rbx` around the `movq` on its own and deleted the `leaq` that was supposed to misalign the call, so the control had to be rewritten in assembly. THE COMPILER REPAIRS WHAT IT CAN, so a positive control for an ABI checker has to be written in a language the compiler does not repair. (3) A CHECKSUM SUMMED INTO THE WRONG REGISTER, which is the bug the collection's own history predicted: the red-zone arms computed the xor of both slots into `%rsi` and then returned `%rax`, so the leaf arm reported its own magic constant and the artifact printed a plausible "DESTROYED" for the one arm that had destroyed nothing. The general form is the eighth time in this collection that a hand-written assembly body needs the return value moved into the return register ON PURPOSE. (4) AND A TRANSCRIPTION SLIP THAT REPORTED THE OPPOSITE OF WHAT IT MEASURED: the marker written into `%r12` by the inline assembly was the literal `0x0b0b0b0b0b0b0b0b` (sixteen hex digits) and the constant the C code compared it against was `0x0b0b0b0b0b0b0b` (fourteen), so every arm ran correctly, the verdict said CLOBBERED for a CONFORMING callee, and the printed hex looked right either way because the two agree in their low fourteen digits. THE FIX IS NOT TO BE CAREFUL WITH THE TYPING: each marker is now one macro, the inline assembly pastes the token in with a two-level stringify (`#x` does not expand its argument, so a single-level `STR(M12)` hands the assembler a symbol), and the C code compares against the name. (5) AND THE ARTIFACT BROKE THE VERY RULE ARM 5 TEACHES, IN ITS OWN PROCESS, AND THE SYMPTOM WAS A HANG: `abi_df_dirty()` is a deliberately NON-CONFORMING callee -- it sets `DF` and does not clear it, which is the violation the direction-flag arm exists to measure -- and the first version of `abidump` called it, read the flag, printed the number and moved on. Then the artifact HUNG: twenty-five minutes of user time, no signal, no diagnostic, no output, at section 9, in a program whose every other failure mode in the file is loud. With `DF` set, every `rep`-based string routine in the C library scans BACKWARDS, so the first `strstr` the artifact made after that point never returned; the whole run now takes 1.4 seconds instead of timing out. THE GENERAL FORM, and it is the reason the arm is in the file at all: a callee that leaves `DF` set produces NO COMPILER DIAGNOSTIC, because `DF` is not in any register and there is no callee-saved slot it could have been preserved in -- the ABI's remedy is a sentence in a document -- and a HANG is the worst possible symptom, because a program that stops with no output looks like a slow machine rather than a broken contract. The arm now repairs the flag in inline `asm` rather than by calling `cld()`, because the artifact must not depend on a library call to fix state its own experiment broke, and it re-reads the flag afterwards and prints the result (`DF after the \`cld\`  0x0000000000000246, bit 10 = 0`) so that a failed repair is visible rather than silent. EVERY OTHER ARM IN THIS COLLECTION MEASURES A HYPOTHETICAL CALLEE; this one broke the measurement. The limits block is printed rather than footnoted and names the instruments that would settle what is missing: `perf_event_paranoid` is 4 and a forked child that ran RDPMC was killed, so there is NO event counter and every duration in the file bounds a count without measuring it
- [x] P1 2.1.75 "The x86-64 Machine: Privilege, Memory and Time" course COMPLETE: 9 concepts in 3 modules, 231 minutes. Depends on x86asm, x86abi, isa, exe, mem, priv, smp and simd, and is the THIRD of the four courses `docs/x86-64-section-plan.md` splits the old 22-concept x86-64 item into. It is scoped by the section's own rule that the comparison lives in the neutral courses and the depth in the per-arch ones, so it owes NO principle at all and pays the complete reference for eight roadmap items -- and the thing no neutral course owned is the INVENTORY of what a ring-3 process can and cannot learn about its own machine, which `priv` had established as three isolated data points. F1 is the course in one table and the set is not the one in the manual: fifty instructions, one forked child each, 39 fault and 11 return, and among the eleven are `SIDT`, `SGDT`, `STR`, `SLDT`, `SMSW`, `XGETBV`, `RDFSBASE` and `WRFSBASE` -- so reading the register that decides which instructions you may execute is unprivileged while writing it is not, and `STR` returns while `LTR` does not because the check for writing the task register is a CPL-versus-IOPL comparison and the check for reading it is nothing. Thirty-four of the thirty-nine faults are `si_code 128` with `si_addr 0`, and the five that are not are the `#UD` group, which is why a boundary RULE would have had to pick one of two answers and a boundary TABLE does not have to. F2 is a correction of the sentence the privilege course's own table implies: a ring-3 process cannot read the IDT, and the reason is NOT that the IDT is privileged -- `SIDT` returns base and limit from ring 3, and reading one byte at that base dies with `si_code 1` and an `si_addr` that is EXACTLY the base `SIDT` printed, for the GDT as well as the IDT. That is the shape of a MAPPING failure rather than a `#GP`, and the replacement sentence predicts an address the original one could not. F3 is the syscall census: a marker in each of the thirteen registers a syscall might destroy, one syscall, read back immediately, 24 of 26 arms surviving and the two that did not both being `%r11` -- and the two halves of that result are the course's sharpest harness failures, because the first version asked for fourteen outputs in one `asm` block and died with SIGBUS (gcc was holding the address of an output slot in a register the body had already overwritten) and the version that fixed that but not the clobber list reported ALL FIFTEEN CLOBBERED, a wrong answer that agreed with a story the author had already written down. F4 is the exception table as a reference rather than a list: all 32 vectors with a class, an error-code flag and a SOURCE column, and 6 rows say MEASURED and 26 say QUOTED -- while the class of every row is quoted, including the six, because deciding it needs the saved RIP and a ring-3 process never sees one. The vendor census is asserted as a PARTITION (20 + 1 + 1 + 9 + 1 = 32) after a first version printed 21, 1, 0 by counting row 28 twice and counting #19 as "defined on both" rather than as the renamed row it is. F5 is the canonical boundary re-derived on FIVE access widths where `priv` derived it on three, and the extension earned its place twice over: the 2-byte arm is the one that separates the rule from a constant, and the bisection of the upper half's lower edge found `0xffff800000000000` on all five widths, which RETRACTS the draft's `0xffffffff80000000` -- a number that is 2^31 bytes INSIDE the half and that appears in a great deal of documentation because the kernel's IDT and GDT both sit above it. F6 is the one direct observation of the paging structure any user process can make: an untouched `mmap` region has NO page-table entry at all and `mprotect` alone changes nothing, so the entry is created by the first TOUCH -- demand paging seen from the inside through one kernel interface -- and the only pagemap bit that moves is bit 63, which is PM_PRESENT and not the PTE's no-execute bit, a retraction. F7 is the absence, and it is the course's central correction: CPUID.80000008:EBX bits 6 and 15 say the core and L3 performance monitors ARE PRESENT, in the same breath in which `RDPMC` is a `#GP`, `perf_event_open` is EACCES and `/dev/cpu/0/msr` is root-only, so the draft's "this machine has no PMU" is RETRACTED in favour of a sentence about ACCESS that names the permission to change. That is also the concept's argument for a distinction rather than a number: an absence of HARDWARE is declared by the hardware in a register any process may read, an absence of ACCESS is imposed by software in a file and a bit, and the AVX-512 absence needed no fork at all because it is a feature bit. F8 is the `DR7` mask COMPUTED from the printed formula rather than typed in -- four cases, all eight control fields proven disjoint, `0xdddd06aa` for four 4-byte write breakpoints, `LEN 10 = 8 bytes` and `LEN 11 = 4` -- with two authoritative descriptions of the layout that disagree, and the file's own third piece of evidence settling one of them by arithmetic: bit 10 is architecturally reserved to 1, which is only true in the layout this file prints. Serves 9 concept routes plus the landing, all 200, with the prev/next chain and manifest minutes verified by `tools/verify_x86sys.py`, which also runs the artifact's 214-check harness
- [x] P1 2.2.96 TEN retractions for the x86-64 machine course, all ten printed by the artifact in section 7 and all ten asserted as TEXT by `crosscheck.py` group J, in numeric order, so a taken-back claim can be neither quietly dropped nor reordered. NOT ONE of the ten is a mistake about how a computer works; every one is a mistake about what a NUMBER is, and that is the course's argument for the whole collection. (1) "A ring-3 process cannot read the IDT because the IDT is privileged" -- RETRACTED AND REPLACED by a page-table sentence that predicts the `si_addr`, measured as exactly the base `SIDT` printed. (2) "The 16-byte arm of the canonical sweep measures the canonical boundary" -- it measured an ALIGNMENT requirement, because gcc compiled the `__int128` load to `movdqa` and the sweep reported `si_code 128` at every unaligned offset, which looks like a rule and is not one; written as inline `movdqu` the same sweep gives 2^47-15, and the artifact prints BOTH arms side by side so the retraction has numbers. (3) "One inline-asm block can read all fourteen registers across a syscall" -- it died with SIGBUS, because there are fewer than fourteen allocatable registers once rax and rcx are clobbered and the compiler was holding the ADDRESS of one of the output slots in a register the body had already overwritten; it is now three blocks of six, six and one, and each register a block overwrites is NAMED in that block's clobber list. (4) "`syscall` destroys fifteen registers" -- NEVER TRUE and it WAS THIS FILE'S OWN OUTPUT for one run, because the clobber-list bug from (3) made every unnamed register look destroyed; the wrong answer agreed with a story already written down, which is the kind of error that survives review. (5) "LAM is reported in CPUID leaf 7 subleaf 0" -- it is subleaf 1 EAX bit 26, and the first version read subleaf 0 ECX bit 26, the same number in a different register at a different subleaf, got zero, and reported LAM as unsupported for a reason that had nothing to do with LAM: IT HAPPENED TO BE RIGHT AND IT WAS STILL WRONG. (6) "The canonical boundary is the address 2^47" -- not as a statement about an access; it is 2^47 MINUS (size - 1), re-derived here on five widths where the privilege course derived it on three, and the 2-byte arm is the one that catches a rule stated as a constant. (7) "This machine has no performance monitoring hardware" -- RETRACTED, CPUID.80000008.EBX bits 6 and 15 say the core and L3 PMUs are PRESENT, and the two sentences have different consequences because one says the instrument does not exist and the other names the permission. (8) "`si_addr` is the address the CPU faulted on" -- it is the address the KERNEL chose to report, zero for a `#GP` and zero for a non-canonical access, and the field that tells them apart is `si_code` and nothing else. (9) "Writing a PROT_READ page and touching a PROT_NONE page are distinguishable" -- THEY ARE NOT from ring 3, both are `si_code 2` with an `si_addr`, and the one distinguishable case is distinguished by MAPPED-ness rather than by protection. (10) "The high bit of a pagemap word is the PTE's no-execute bit" -- WRONG, and it reported NX=1 for a page it had never written: bit 63 of PAGEMAP is PM_PRESENT, which is the PTE's present bit, and pagemap exposes no field for NX at all
- [x] P1 2.2.97 The FIVE claims the course makes that are measurements of an ABSENCE rather than of a thing, because an absence is the hardest kind of result to present and the course's own subject is a boundary. Each is proved with a FORK and each names the mechanism, and together they are the argument for a distinction the course turns on: an absence of HARDWARE is declared by the hardware and an absence of ACCESS is imposed by software. (1) There is no counter this process can OPEN, three ways, none of them a statement about the silicon: `RDPMC` in a forked child is killed by signal 11 with `si_code 128`, `perf_event_open` returns EACCES, and `/dev/cpu/0/msr` is DENIED with errno 13 -- and `CPUID.80000008:EBX` bits 6 and 15 say the core and L3 performance monitors ARE PRESENT. (2) There is no AVX-512, which needed no fork: `CPUID.7.0:EBX` AVX512F/DQ/CD/BW/VL are ALL ZERO and XCR0 is 0x207 with the AVX-512 state bits 5, 6 and 7 clear, so the state is not merely unsupported, it is not enabled. (3) The IDT and the GDT are at addresses the process can READ and cannot FOLLOW, and the fault is `si_code 1` with an `si_addr` equal to the base each instruction printed -- which is what makes the boundary a page-table fact rather than a privilege one. (4) An untouched `mmap` region has no page-table entry at all and `mprotect` alone creates none, measured as three within-page XORs of the pagemap word in which bit 63 is the only bit that moves, so demand paging is observable from the one side a user process can reach. (5) The `PS` bit of a real 2 MiB mapping was NOT observed: `MAP_HUGETLB` returned ENOMEM and no transparent huge page collapsed during the run, so the `PS=1` row of the entry table is QUOTED and every number in the concept comes from the 4 KiB path, which is printed in the limits block rather than left for the reader to assume
- [x] P1 2.2.98 `courses/x86sys/assets/samples/sysdump.c` plus `crosscheck.py` and `build_samples.sh`, 214 checks in 10 groups, and five design positions are the transferable part. (1) A RESULT CROSSES THE FORK THROUGH A `MAP_SHARED` PAGE, and the first version used plain globals: the handler ran in the child, wrote the child's copy, and the parent read its own, so ALL FIFTY ROWS OF THE BOUNDARY TABLE PRINTED `si_code 0` -- and 0 is not a neutral wrong answer, it reads as "the kernel reported no code" and is a PUBLISHABLE result about a hardened kernel, when thirty-four of those rows should have been 128. A `used` flag was added on top of the shared page for a second reason: without it the harness cannot tell "the instruction returned" from "the instruction was deleted", and gcc HAD deleted the divide-by-zero experiment (`volatile long z = 0; d / z;` at -O2 is undefined behaviour, so the division vanished and the probe RETURNED), which is the eighth time in this collection that a separate experiment was deleted and the second time a `volatile` local was the wrong half of the fix. (2) THE TABLES ARE ASSERTED TO THE BIT AND THE BOUNDARY IS ASSERTED AS A SET PLUS A PARTITION: every CR0 row, CR3 field, CR4 row, DR7 row, paging index, entry flag and error-code bit is compared exactly, because a bit position is exact; and the boundary is checked as `must_fault <= faulted`, `must_read <= returned` and `faulted & returned == empty`, so a check that can only fail on the ROW it names is impossible. The two DR7 masks are RECOMPUTED from the printed formula rather than compared as constants, so a wrong formula fails even with a right constant. (3) EVERY SUBSTRING ASSERTION RUNS AGAINST A WHITESPACE-NORMALISED COPY, and the needles are normalised too -- and the first draft of this harness failed four checks against text that was demonstrably present because the tables are column-aligned with runs of spaces. The same class of bug appeared three more times in the same file and all four are now the same fix: a column-padded table compared with a needle that carries the padding, a `rows()` helper that returned all capture groups when the caller wanted two, a retraction marker asserted with three spaces of indent when R10 is printed with two because the number is a character longer, and a regex that hard-coded one space after a padded number and matched 34 of 52 rows. (4) THE POSITIVE CONTROL IS A PLAN, NOT A FILE, and it is stated in the manifest's completion criteria: add a fourteenth register to the `syscall` marker block without naming it in that block's clobber list and the artifact dies with SIGBUS instead of a number, which is exactly the bug that produced retraction R4. (5) AND THE HARNESS CAUGHT THE ARTIFACT TWICE, which is the argument for having one: its first version of the pagemap check asserted "only bit 63 moves" and failed on its first honest run, because a second bit moves in the fourth row and the artifact now prints the three within-page XORs and DECLINES TO NAME the second bit, on the grounds that its kernel definition has changed twice; and its vendor-census check was rewritten to assert a PARTITION after the artifact's first version printed 21, 1 and 0. The limits block is printed rather than footnoted and names the instrument that would settle each of its nine entries, four of which are properties of the INSTRUMENT rather than of the subject
- [x] P1 2.1.76 "The x86-64 Data Path: Atomics, Ordering and Vectors" course COMPLETE: 6 concepts in 2 modules, 154 minutes. Depends on x86asm, x86abi, isa, mem, smp and simd, and is the FOURTH and last of the four courses `docs/x86-64-section-plan.md` splits the old 22-concept x86-64 item into, covering the last five roadmap items. It is scoped by the section's own rule -- the comparison lives in the neutral courses and the depth in the per-arch ones -- and it is the one course of the four that DELIBERATELY DOES NOT REPEAT a neutral course's experiment: `simd` already measured that a wider vector is not automatically faster (3.89x at 2 KiB, 1.14x at 24 MiB), so this one measures alignment, the three-operand form and `vzeroupper` instead, and links the width result rather than restating its number. F1 is a SET rather than a number and the set is not the one in the manual: ten vector loads probed one per forked child at +8 bytes, of which five SIGSEGV and four return, and the harness asserts the two sets PARTITION the ten rather than asserting a threshold -- and `vmovdqa load` appears TWICE, once legacy-prefixed and once VEX-prefixed, so a harness that counted NAMES would collapse two probes into one and report nine. F2 is a RETRACTION of the commonest claim about AVX: the VEX prefix did NOT remove the alignment requirement. `vmovaps` and the VEX `vmovdqa` fault on exactly the addresses their legacy twins do, and the SDM's own sentence says the operand "must be aligned on a 16-byte (128-bit version), 32-byte (VEX.256) or 64-byte (EVEX.512) boundary or a #GP will be generated". What AVX actually relaxed is the FUSED memory operand and unaligned STORES, which is a much smaller claim. F3 is a finding that INVERTS the usual story and is read out of BIT PATTERNS rather than durations: a LEGACY SSE instruction PRESERVES a YMM register's upper 128 bits and a VEX-128 instruction ZEROES them, with seven rows against a control and one recognisable value (0x3dcccccd, which is 0.1f) so a PRESERVED reading cannot be confused with a register that was never written. The dirtying instruction is the LEGACY one, and that is what the VEX encoding was designed to prevent. F4 is the atomic set as THREE instruments over 42 arms, and the two results that decide the concept are `lock inc` being EXACT (the draft said it was not, because it read the SDM's list of eighteen instructions that ACCEPT the prefix as a list that guarantees atomicity; the real reason is that INC does not disturb CARRY) and `or $0`, `and $~0`, `xor $0` and `sub $0` with no prefix all LOSING INCREMENTS while looking like no-ops, which only the SECOND instrument can see at all because the first is blind to an operation whose value never changes. F5 is ordering as bytes and as a cost: `MFENCE`/`LFENCE`/`SFENCE` are `0f ae f0`, `0f ae e8`, `0f ae f8` -- ONE opcode, and MFENCE and SFENCE both have reg=7 and are told apart by the ESCAPE, so a decoder that switches on ModRM.reg alone gets them right only by accident -- and the seven-arm ping-pong on two pinned cores shows the two expensive arms are the same-cache-line case and MFENCE, with the plain ping-pong sitting at ~1.04x its own store floor, which is the textbook answer and arrived only after the layout was fixed (see 2.2.99). F6 is the section's one INCOMPLETENESS, handled correctly: this machine cannot execute one instruction in the AVX-512 concept, `CPUID.7.0:EBX` reads F/DQ/CD/BW/VL as five zeros and the three `XCR0` state bits are three more, and every claim there is marked QUOTED against MEASURED on the page itself while the one thing the artifact does with AVX-512 is DECODE ITS BYTES, which needs no silicon -- and the `CR4.OSXSAVE` gate on `XGETBV` is INFERRED rather than read, because a direct `mov %cr4` faults in this environment and a RETURNING `XGETBV` proves the bit is set since the alternative is #UD: a probe that answers the question by using the thing in the question beats one that reads a bit it may not read. Serves 6 concept routes plus the landing, all 200, with 20 internal links resolved across five courses, prev/next chain and manifest minutes verified by `tools/verify_x86simd.py`, which also runs the artifact's 266-check harness; all 15 course verifiers report ALL CONSISTENT and all 25 course landings are 200
- [x] P1 2.2.99 TWENTY-FOUR retractions for the x86-64 data path course, all twenty-four printed by the artifact in section 7 and all twenty-four asserted as TEXT by `crosscheck.py` group J, in numeric order, so a taken-back claim can be neither quietly dropped nor reordered. NOT ONE of the twenty-four is a mistake about how a computer works; six are about what a NUMBER is, SEVEN about what an INSTRUMENT is, three about what an ENCODING is, and the rest about what a BINARY contains or what a SPECIFICATION says. THE TWO THAT MATTER MOST ARE ABOUT THE COURSE'S OWN ARTIFACT AND WERE FOUND BY RUNNING IT, which is the seventh course in a row to establish that. (1) "The direction flag is EFLAGS bit 21" -- RETRACTED, it is BIT 10, and bit 21 is the ID flag whose entire job is to be a bit software can set on a processor that has CPUID and cannot on one that does not; the two have nothing in common and the artifact reads the whole register with PUSHFQ and prints every bit it NAMES rather than the one it remembered. (2) "INC and DEC are NOT atomic even with the LOCK prefix" -- RETRACTED, `lock inc` is EXACT over two threads and two cores, and the encoding exists for a much smaller reason: INC does not disturb the CARRY flag and `add $1, m` does. (3) "A lost-update count is a test for atomicity" -- RETRACTED as a GENERAL instrument, because a lost update is only defined for an operation that moves a value in ONE direction; NOT and NEG are involutions, so an even number of racing applications returns the word to where it started WHETHER OR NOT either was lost, and the first version of the table reported EXACT for all four unprefixed arms. (4) "An operation that did not change the value cannot have lost an update" -- RETRACTED, `or $0` writes back exactly the word it read and the duplicate test still fires, so "the value is unchanged" and "the operation was atomic" are different claims. (5) "The three-operand VEX form removed an instruction and so must be faster" -- RETRACTED and INHERITED from the assembly course, which measured 1.00x; this file ran the OTHER body, the one where the destination IS also a source so the legacy form needs no copy at all, and the copy is still free, because what the three operands bought is a SOURCE-LEVEL property and no duration can price one. (6) "The AVX-SSE transition penalty is what vzeroupper exists for and it will be visible here" -- RETRACTED as a claim about THIS machine, see F3. (7) "The vzeroupper experiment measured nothing because it used intrinsics" -- CONFIRMED, and it is a compiler fact: `gcc -mavx2` compiles `_mm_add_ps` to `c5 f8 58 c1` and a VEX-128 instruction has no transition penalty AT ALL, so every arm came out 1.00x; the arms are now RAW `0F 58` encodings in inline asm and the build script disassembles them. (8) "A static array is a safe place to probe a load" -- RETRACTED, the compiler folded the experiment and the `vmovapd` became a `vmovsd` of a value it had already read, so the probe reported OK for a MISALIGNED load; the buffer is mmap'd now. (9) "A round trip proves the encoder is right" -- RETRACTED, the first encoder round-tripped 28 of 28 against its own decoder and was wrong, having written the two-byte VEX with the THREE-byte field order; a round trip is a tautology and it certified a broken encoder. (10) "In a VEX-encoded instruction ModRM.r/m is the destination" -- RETRACTED for the three-operand form, established by assembling three DISTINCT registers and reading which field each landed in. (11) "A probe that returns must have run" -- RETRACTED, the exit status of a forked child is a SIGNAL and a probe the COMPILER DELETED also returns cleanly; the first alignment probe reported 'returned' for eight instructions, four of which were not in the binary. (12) "Filling a YMM register, running one instruction and reading lane 4 measures the transition" -- RETRACTED as a probe, because the fill and the read were two separate asm blocks and gcc inserted a VEX-128 instruction on `ymm0` between them, which ZEROES the upper half on this part, so the experiment reported 0x00000000 for a transition that never happened. (13) "The three-operand form is a source-level property and no duration can price it" -- NOT RETRACTED, and printed because it is the one NEGATIVE claim in the course and negative claims are the ones that get quietly dropped. (14) "A duplicate-old-value test can decide whether a read-modify-write is atomic" -- RETRACTED after FOUR versions, and all four are written out in the artifact's header: a per-thread hash set reported duplicates for `lock or $0` because a thread that is outrun sees its own value again; a shared set needed synchronisation it did not have, so it was a data race in the instrument while it measured data races; a counted clobber counted its own accumulator; what works is the PAIRED COUNTER, where the observable is a lost-update count that instrument 1 already measures. (15) "THE VEX ENCODING REMOVED THE ALIGNMENT REQUIREMENT" -- RETRACTED, see F2, and the SDM is quoted beside it. (16) "A read-modify-write can be tested by asking whether the OLD value was the one the writer read" -- RETRACTED as an instrument, which is item (14) stated from the other side, and the two are kept apart because the general form is the one that transfers: choosing an observation whose failure is VISIBLE is a separate decision from choosing an operation to observe, and the four failed versions got the second right and the first wrong. (17) "A CMPXCHG loop's accumulator pair is an input" -- RETRACTED, EDX:EAX is an INPUT *AND AN OUTPUT* pair and on a failed compare the CPU writes the memory value back into it, so declared as plain inputs the compiler reloads a stale value every iteration, the compare never succeeds and the counter reads 1; four CNT rows were wrong for this and three printed a number that looked like a result, and the 8- and 16-byte forms need BOTH halves of the new value bound. (18) "An arm is atomic when the total is exactly 2N" -- RETRACTED into a table of THREE exact totals: an arm that moves the value UP ends at 2N, one that moves it DOWN ends at 2^32-2N because the word is 32 bits, and one that TOGGLES a bit ends at 0; a table that expected 2N reported a perfectly atomic `lock dec` as NON-ATOMIC, and the EXPECTATION is the thing that has to be right before a measurement can be called a pass. (19) "A table with twenty perfect rows is evidence" -- RETRACTED, it was the output of an instrument whose probe thread had fallen through to `default` and done NOTHING while the incrementer ran alone, so an instrument that measured nothing reports no losses. (20) "BTS and BTR are atomic when the final word is 1 and 0" -- RETRACTED: they are NOT TESTABLE with this instrument at all, locked or not, because both are IDEMPOTENT and a lost update is invisible; only BTC, which TOGGLES, can be read this way. (21) "A checksum loop over a byte array is safe to let the compiler vectorise" -- RETRACTED, a vectorised 32-byte load at offset 4092 of a 4096-byte buffer is a clean SIGSEGV, and the artifact died there two hundred correct lines into a run; the loops are volatile and the buffers are oversized, and both of those are load-bearing. (22) "MFENCE and SFENCE differ in a single bit position" -- RETRACTED, they differ in TWO, and the more interesting statement is the opposite of the draft's: they SHARE the reg value 7 and are told apart by the escape. (23) "The objdump cross-check agreed with the encoder on 28 of 30 rows" -- RETRACTED, AND IT HAD BEEN BELIEVED, which makes it the worst of the twenty-four: the first run reported 28 DISAGREEMENTS out of 30 and the file reported them as evidence that the encoder was broken, when the encoder was perfect and the READER OF THE DISASSEMBLY was counting objdump's section header as row 0, so every row was compared against its NEIGHBOUR's text and the two rows that still "agreed" did so only because both happen to be `vaddps`. THE LESSON: a cross-check that DISAGREES with almost everything is as SUSPICIOUS as one that agrees with everything, the two failure modes a misaimed check can have look nothing like each other and are equally wrong, and the only reason this one was caught is that the number was checked against what a CORRECT run looks like and not against whether it felt right. (24) "The arm labelled 'store to my line, then load the peer's' is a two-thread ping-pong" -- RETRACTED, and it took THREE attempts: the body took a THREAD ID and never used it, so both threads addressed the same two words; the first fix indexed by id but left `aligned(64)` on a two-element array, WHICH ALIGNS THE ARRAY AND NOT EACH ELEMENT, so the threads' words were still eight bytes apart in one cache line; the fix that worked is a STRIDE of eight words. TWO OF THE THREE PRODUCED NUMBERS THAT LOOKED ENTIRELY REASONABLE, and the tell was visible the whole time -- THE STORE-ONLY FLOOR CAME OUT ABOVE THE THING IT WAS A FLOOR FOR, IN EVERY RUN, which is impossible, and the file PRINTED THE RATIO instead of treating it as a contradiction of its own vocabulary. A row's NAME is a claim about what the row did and a name is not evidence, and the general form is the most useful thing in the course: A NUMBER THAT CANNOT HAVE COME OUT IS THE FRIENDLIEST THING AN EXPERIMENT EVER DOES, and the only way to deserve it is to hold a claim that says the number should have been SMALLER. The layout is now PRINTED above the table and asserted by the harness, because a comment is not a measurement
- [x] P1 2.1.77 "AArch64: Encoding From The Ground Up" course COMPLETE: 5 concepts in 2 modules, 127 minutes. Depends on elf, and is the FIRST of the four courses `docs/aarch64-section-plan.md` splits the old 22-concept ARM64 item into, so it is scoped by the same rule as its x86-64 sibling -- the comparison lives in the neutral courses and the depth in the per-arch ones -- with one difference that the section plan forced and that is the course's whole design: THERE IS NO AARCH64 MACHINE ON THE BUILD HOST AND NO EMULATOR, so not one instruction in the course has been run, and every number is a BIT PATTERN, a COUNT of bit patterns, an ARITHMETIC IDENTITY, or a REFUSAL FROM A REAL ASSEMBLER. The two absences are printed by the artifact in section 1 BEFORE any measurement rather than in a limits block at the end, because a reader who meets a number and meets the absence of the thing that would make it a runtime measurement in a different order learns a different lesson. What is claimed is therefore checkable with a hex editor, which is the point: a byte that means something is the first step of the chain and the only step in it that needs no silicon. A word-boundary scan over the concept files of the 25 shipped courses finds `bits[28:25]`, logical immediate, `N:immr:imms`, `CSEL`, `CSET`, `MOVZ`, `MOVK`, `MOVN`, `ADRP`, `:lo12:`, `LDP`, `STP`, `TBZ` and `CBZ` in ZERO files, and AArch64 in ZERO of them, so the debt is the whole of one architecture's encoding; what it does NOT re-teach is the ELF course's section-header table, which is where the artifact's own reader comes from (`e_shoff` at 0x28, the section array at 0x3a, `struct.unpack_from`, no library -- a decoder that shells out to a disassembler is a disassembler with a hardcoded path in it). F1 is the premise, established as a MEASUREMENT rather than a definition: 868 instructions in five object files, every code section a multiple of four, every walk ending EXACTLY on the section end, 4.0000 bytes/insn in all five rows. That fixes the declared subset as a subset of NAMES rather than of LENGTHS, which is the whole difference from the ISA course's x86dec.py -- an Advanced SIMD word this decoder cannot name still contributes exactly four bytes to the count, so the 9 unmodelled words are COUNTED and not dropped, and a cross-check that reported them as failures would be reporting its own declared scope as a bug. F2 is the field map, MEASURED rather than remembered: 58 field positions by assembling an instruction, changing one operand, and OR-ing the XOR over a SWEEP of variants, written to `fields.txt` and asserted as exact bit patterns by the harness. The method is the contribution and the method's first version was wrong in a way that looked like a result: a single pair marks the bits where two VALUES differ, which is a SUBSET of the field, so `movz w0,#0x1111` against `movz w0,#0x2222` gave an 8-bit `imm16` for a sixteen-bit field and the table looked wrong because the table was. Three rows of the measured map are the course: `Rt2` in the pair form is bits[14:10] and NOT bits[11:10] (the commonest AArch64 decoder bug in existence, hidden by the coincidence that a two-bit field gets `stp x0,x1` right and every other pair wrong), the condition is bits[15:12] in a select and bits[4:0] in a B.cond with the two NOT overlapping, and register 31 is the stack pointer in add/sub and the zero register in the logical groups over an IDENTICAL bits[4:0] -- so no field map can express the difference and only a decoder that says which group it is in can. F3 is the logical immediate, and the number is the most useful one in the file: 1,302 of 4,294,967,296 32-bit constants and 5,334 of 2^64 are encodable, so the SMALLEST literal field in the architecture reaches more values than any other twelve-bit field including the add/sub immediate's 4,095, and it reaches them by not being a number. The three checks on it are deliberately of three different kinds -- a self-consistent round trip over all 5,334 (0 failures, and NECESSARY NOT SUFFICIENT because the first version handed the decoder the encoder's own `imms` and made the test a tautology that printed the same line), and an assembler round trip over all 1,302 32-bit constants (1,302 agreed, 0 disagreed), which is the only one that could have failed for a reason the file does not control. F4 is the reserved space, and it REVERSES the first draft: `and w0,w0,#0xffffffff` is REFUSED and so is `and x0,x0,#0xffffffffffffffff`, with the same diagnostic for all eight logical operations because it is a property of the shared field, and one bit short of all-ones IS accepted -- so the boundary is the SHAPE and not the WIDTH, which is the sharpest single fact in the encoding and the reason a decoder that ignores `sf` gets a wrong CONSTANT rather than a wrong name. F5 is the wide-constant cost, and it is NOT ORDERED BY SIZE: the cheapest 64-bit constant is the one with no variety in it (`movn x0,#0` for all-ones, because MOVN writes the complement and the complement of all-ones is a field MOVZ can write) while an arbitrary literal and the largest signed 64-bit value both cost four -- the first draft predicted "big = expensive" and got all three rows wrong. F6 is the conditional-select trap, which is why the course has a concept for it: `cset w0, eq` is `csinc w0, wzr, wzr, NE`, the condition is INVERTED, the two are different 32 bits that differ in the condition field and nowhere else, and 23 of the 56 selects in the corpus are inverted forms whose output is 0 or 1 either way, so a decoder that misses the inversion reports every condition in the program backwards and NOTHING ABOUT THE OUTPUT SAYS SO. F7 is the density comparison, and it is the result the course was written to make and the measurement retracts: the same C, both targets, four levels gives 1.152 / 0.813 / 0.797 / 1.292, so AArch64 is LARGER at two of four optimisation levels and the claim is retracted and REVERSED at half of them rather than softened, with the -O0 row carrying the explanation in its own two numbers (AArch64 emitted FEWER instructions than x86-64, 338 against 393, and still produced MORE bytes, 1352 against 1174, which can only be true if the instructions it did not emit were cheap on the other side). F8 is the two-reader cross-check and the POISON, which is the transferable part: 868 instructions, 859 named, 100.0000% agreement -- which is exactly what a BROKEN cross-check looks like -- and the model table is then poisoned on purpose and the same loop re-run, and the number moves from 859 to 717 by exactly the 142 words the victim owned, which is the shape a real bug has and not the shape a broken loop has. Serves 5 concept routes plus the landing, all 200, with the prev/next chain and manifest minutes verified by `tools/verify_a64asm.py`, which also runs the artifact's 243-check harness against the SHIPPED `a64dec.out` so the course's claims are checkable on a machine that never ran its assembler
- [x] P1 2.2.100 SEVENTEEN retractions for the AArch64 course, all seventeen printed by the artifact in section 14 and all seventeen asserted as TEXT by `crosscheck.py` group N in numeric order R1 to R17, so a taken-back claim can be neither quietly dropped nor reordered. NOT ONE OF THE SEVENTEEN IS A MISTAKE ABOUT HOW A COMPUTER WORKS, which is now nine courses in a row, and the thing worth recording is that THIS COURSE REACHED IT FROM A NEW DIRECTION: there is no machine, so none of the seventeen is a measurement that came out wrong, and every one is a claim about a BIT PATTERN, a WIDTH, a SIGN, or an INSTRUMENT. (1) "AArch64 loses on code density, because 4 bytes per instruction beats an average of 3" -- RETRACTED AND REVERSED AT HALF THE LEVELS, the ratio changes sign with the optimisation flag, so it was never a property of the architecture. (2) "The class field is 2 bits, and four named classes cover the encoding" -- RETRACTED, it is FOUR bits at position 25 and ELEVEN of sixteen values carry a real instruction; the two-bit rule put `ret` -- 134 of 868, the largest single entry in the distribution -- in the wrong class because bits[28:26] of 0xd65f03c0 is 0b110, and it cannot see 01101 at all, which is where csel, cset, mul and madd live. (3) "A 32-bit logical immediate reaches every 32-bit value, so a compiler can use it for any mask" -- RETRACTED, 1,302 of 2^32, and the two the compiler wants MOST are among the ones that are not. (4) "The add/sub immediate reaches 0 to 4095, or that value shifted left by 12" -- NOT WRONG BUT INCOMPLETE IN A WAY THAT MATTERS, because the true reach is THREE ISOLATED values, so #0x1000 is accepted and #0x1001 is refused, and a scaled field is not a contiguous range in FOUR places in this architecture. (5) "A 26-bit branch field is 26 bits of magnitude" -- RETRACTED TWICE, and the second time is the one that matters: the first draft got the arithmetic wrong and the second draft corrected the arithmetic and then wrote the BOUNDARIES FROM MEMORY, giving b.cond a far end of 0x1ffffc and B a near end of -0x40000000, and the assembler REFUSED BOTH. (6) "`cset` is `csinc` with Rn = Rm = 31" -- RETRACTED, and this is the trap the fourth concept is about: the condition is INVERTED. (7) "MOVN is a signed immediate, like MOVZ with a different sign" -- RETRACTED, the field holds a MAGNITUDE and the register holds its COMPLEMENT, which is why `movn w0,#0x8000` prints as `mov w0,#-0x8001` while `movn w0,#0xffff` prints as `movn w0,#0xffff`, by the same tool, on the same group. (8) "The declared subset is a subset of the instruction set" -- REFINED, because the phrase means two things and this decoder is one of them: a subset of NAMES, not of LENGTHS. (9) "An unmodelled word is an error in the decoder" -- RETRACTED, and the direction of the error is the interesting part: the oracle names all 9 without hesitation, so a cross-check that reported them as failures would be reporting its own declared scope as a bug. (10) "`llvm-objdump -b binary` disassembles a flat file" -- RETRACTED BY THE TOOL, `error: unknown argument '-b'`, and the isa course's harness uses GNU objdump which HAS it, so the technique worked there and does not work here; a cross-check that quietly substituted a different disassembler for a script's convenience would have been a claim about a tool that is not installed. (11) "The width of a register is one bit, so `sf` at bit 31 means the same thing everywhere" -- RETRACTED, and bit 31 is the PAGE bit in ADRP, the INVERT bit in the select family, and the set-to-0/set-to-1 bit in CSET. (12) "A field map is a set of bit ranges, and a non-contiguous span means the measurement is wrong" -- REFINED, and the wrong version was this file's OWN single-pair XOR. (13) "The 4x4 table of conditional selects has sixteen entries" -- CORRECTED, there are FOUR operations and the other twelve cells are UNDEFINED; the first draft called two of them "the SET forms", and the first TABLE assembled a line per cell and printed `csinv` eight times because there is no mnemonic for (invert, op2) = (1,0). (14) "A decoder that agrees with a disassembler is correct" -- REFINED INTO SOMETHING CHECKABLE, and the first version of the POISON WAS A NO-OP: it prepended a model that claims nothing rather than REMOVING one, so the victim still claimed every word it had claimed and the number was 859 before and 859 after, with the word POISONED printed above it. A control that cannot move the number it is measuring is a comment that says the word POISONED. (15) "Register 31 means the stack pointer wherever a 5-bit register field appears" -- RETRACTED, AND FOUND BY THE CROSS-CHECK RATHER THAN BY READING: the logical-immediate model called the register function with its default and printed `orr x9, sp, #0x8000000000000001` for a word the oracle calls `mov x9, #-0x7fffffffffffffff`, and that is not a naming difference because a logical OR against the stack pointer is a different VALUE from a logical OR against zero. A FLAG WITH A DEFAULT IS A FLAG NOBODY CHECKS. (16) "A 64-bit logical immediate can express any 64-bit pattern" -- RETRACTED, the 64-bit ALL-ONES is refused with the same diagnostic as the 32-bit one, which is the REVERSE of the first draft's claim, and one bit short of all-ones is accepted, so the boundary is SHAPE and not WIDTH. (17) "A cross-check that has been normalised until it reports 100% has found no bugs" -- RETRACTED, AND IT IS THE MOST IMPORTANT LINE IN THE FILE: the first run reported 848 of 859 and the eleven were the most useful output in the course, TWO of them a real decoder bug and NINE a normalisation rule written as `^movn([\w,]*),#...` where `[\w,]*` does not match the space between a mnemonic and its operands, so it matched NOTHING, SILENTLY, and the cross-check printed its number anyway
- [x] P1 2.2.101 The AArch64 course's artifact is `courses/a64asm/assets/samples/a64dec.py` (4,000+ lines: a 21-model decoder that uses NO tool to decode anything and reads the ELF64 section table with `struct.unpack_from`, plus a 15-section measurement driver), with `crosscheck.py` at 243 checks in 15 groups, and four design positions are the transferable part. (1) THE DECLARED SUBSET IS A SUBSET OF NAMES, NOT OF LENGTHS, which is the whole difference from `courses/isa/assets/samples/x86dec.py` and it is the only structural difference that matters: because the length is a constant, an unmodelled word still resolves a length, the 9 Advanced SIMD words in the corpus are counted rather than dropped, and the cross-check's agreement figure is over the 859 NAMED words and says so. (2) THE FIELD MAP IS MEASURED BY A SWEEP, not by a pair: a single pair marks the bits where two VALUES differ, which is a SUBSET of the field, so the first version reported an 8-bit `imm16` for a sixteen-bit field; the method ORs the XOR over one variant per single bit of the operand, and the result is explicitly a LOWER BOUND with the not-moved bits listed per row, because rounding a mask up to a span would be asserting a field nobody measured. (3) EVERY PROBE IS ONE CASE PER FILE, and the reason is written at the call site: a batch is a fast path with a correct per-case fallback, because the first version assembled all the field cases into one .s and the single case the assembler rejects took the other fifty-seven with it and printed blanks -- a probe that loses its whole sample to one bad row measures nothing. (4) THE HARNESS ASSERTS EXACT NUMBERS AND EXACTLY ONE SHAPE, and the asymmetry is the point: 242 of the 243 checks are exact (bit patterns, counts, assembler refusals, the reach of a signed field, and the PRESENCE of all seventeen retractions) because those quantities are exact, and the single shape is the density comparison, asserted as "the sign changes between -O0 and -O1" rather than as any of the four ratios, because those four numbers come from one compiler version and a compiler upgrade moves them -- a check whose threshold is a bare number is a check that fails on a busier machine and teaches its reader to ignore it. The harness ALSO asserts that the poison moved the number, because a harness that only ever reads the 100% is the harness this course retracted in R14 and R17, and a harness that has retracted something should not commit the same mistake in its own code
- [x] P1 2.2.102 SEVEN documented failures of the AArch64 course's own HARNESS, all found by RUNNING it and none by reading it, which is the ninth course in a row to establish that and the first whose failures are almost entirely about TEXT it reads rather than about numbers it computes. (1) A HELPER THAT RETURNED THE WRONG COLUMNS: `table_rows(text, prefix)` matched a PREFIX and returned everything after it, so the section-2 table's `r[2]` -- read as "the remainder mod 4" -- was the INSTRUCTION COUNT, and "every section is a multiple of four" compared 135 against 0 and failed on a table where every value was correct; the replacement takes a pattern that matches the whole row and whose capture groups ARE the fields, with the reason written above it. (2) `CHECKS += 1` at module scope followed by a `CHECKS += 1` INSIDE `main`, which makes the name local for the whole function, so the counter was unreadable and the harness CRASHED on its own second line -- a harness that cannot print its own total is a harness whose total nobody reads. (3) AN INDEX INTO A STRING THE HARNESS DID NOT WRITE: `asm.split()[2] == dis.split()[3]` compared the assembler's banner to the disassembler's, and "Ubuntu clang version" and "Ubuntu LLVM version" do not have the word before the number in the same place, so it raised IndexError on the very first real output. (4) `one()` RETURNS GROUP 1 and the caller wanted all three: a line reporting "58 field positions measured, 58 cases, 0 refusals" was parsed with the single-group helper, which returns the STRING "58", and then indexed as if it were a tuple -- so the harness reported 5 of 5,334 constants round-tripped, a spectacularly confident wrong number derived from a correct regex. (5) AN OFF-BY-ONE IN A FIELD WIDTH, which is the same bug the whole course is about: the condition tables' pattern was `0[01]{4}` -- a leading zero and FOUR more, FIVE characters -- which matches "00000" and not "0000", so both sixteen-row tables came back EMPTY and the harness reported sixteen missing rows against two tables that print all sixteen. (6) TWO NORMALISATIONS WITH OPPOSITE CAPTURE GROUPS: the decoder takes `(N, imms, immr, width)` and the encoder returns `(N, immr, imms)`, and the first round trip passed the encoder's output straight through, so it handed the ROTATE AMOUNT to the decoder's `imms` and the run length to its `immr` -- and 94 of the 5,334 constants came back as something else while the self-consistent check still read as a pass. (7) A COLUMN INDEX THAT WAS RIGHT BY ACCIDENT AND THEN WAS NOT: the cross-check unpacked the group-count sentence as `(total, named, unmodelled)` and took group 1, which is the FILE COUNT, so `named + unmodelled == total` compared 859 + 9 against 5 and reported a consistency failure in a table that is perfectly consistent -- the two counts are ADJACENT in the sentence and are not the same number. The standing instruction from the previous eight courses applies unchanged and is written at the top of this file: THE HELPER THAT EXTRACTS IS WHERE THE COURSE'S BUGS ARE, and none of these seven was found by reading a check
- [x] P1 2.1.79 "The AArch64 Machine: Modes, Memory and Faults" course COMPLETE: 6 concepts in 2 modules, 150 minutes. Depends on a64asm, a64abi, elf, sec, obj and reloc, and is the SECOND of the four courses `docs/aarch64-section-plan.md` splits the old 22-concept ARM64 item into. It inherits the no-machine premise from its own section's first course and turns it from a limitation into a METHOD, so the scope is not "what the manual says about privileged mode" but "what can be established about a machine you cannot run, and how a reader tells which is which": the sibling x86-64 course measured a mode change at 27.65x and a syscall at 4.92x, and THIS COURSE HAS NO TIMINGS AT ALL, which is stated as a refusal rather than faked, because a 27.65x cannot be manufactured from a corpus of bit patterns and the honest alternative to the number is not a smaller number. F1 is the SYSCALL field and it is the course's cleanest architectural difference from x86-64: `svc #imm16` puts a SIXTEEN-BIT CONSTANT IN THE INSTRUCTION (bits[20:5], measured) and the Linux number is in `x8` (ABI, quoted, and the two halves are BOTH in the emitted code), where x86-64's `syscall` encodes NO number at all and the kernel reads a register the instruction never mentions. The argument audit is 111 of 111 argument placements landing in the register whose NUMBER is the argument's own at -O1, -O2 and -Os, with the ninth argument never a register, and -O0 spilling everything -- so the register assignment is the specification's and the instruction counts are the compiler's, and the artifact asserts the first and not the second. F2 is the exception syndrome, and the trap is a MASK: `ESR_ELx` is a 64-bit register whose syndrome is EC, IL and ISS, and ISS is bits 24:0 with bits 55:32 holding ISS2, so a reader who masks 32 bits throws half the field away and gets a plausible wrong number with no fault. F3 is the vector table as ARITHMETIC rather than as a diagram: 16 entries of 0x80 = 0x800, and the assembler measured that as 2048 bytes, with the table measured at offsets 0x800 through 0xf80 -- and the finding is an ABSENCE, because four different alignment directives in four separate files produce FOUR OF FOUR ACCEPTED AND ZERO DIAGNOSTICS, and the 2 KiB requirement is enforced by the architecture at the moment an exception is taken, which is a link-time alignment that is not a link-time error. F4 is the translation regime and its floor: T0SZ = 64 - 48 = 16 and T1SZ = 64 - 52 = 12 with LPA2 are arithmetic identities, and the row the section plan does not have is the one that matters, because T0SZ is a FIVE-BIT field so 33 bits is the smallest space expressible (T0SZ = 31) and a 32-bit or 30-bit space is not expressible at all -- a bound from BELOW that only appears if you ask what the field cannot hold. F5 is the hinge into the ELF courses and the reason this course exists where it does: `sh_addralign` returns 0x200000 for `.bss` from BOTH readers when the section holds one 2 MiB-aligned table and 0x1000 when it does not, so ONE declaration of `__attribute__((aligned(0x200000)))` on ONE array promotes every other uninitialised table in the section for free, and the alignment is a property of the SECTION rather than of the object -- while the relocations give 275/277/274/286 read by two parsers that agree 8 of 8 on the TYPE NUMBERS, because a relocation NAME is a convention and a relocation NUMBER is what goes in the file. F6 is the correction of the course's own stated reason for the ADRP+LO12 pair: the section plan and the brief both said the pair exists because the ADRP reach is +-4 GiB, and the reach is real and IRRELEVANT, because ADRP MASKS OFF the low twelve bits of the target and something has to add them back -- 3 of the 4 ADRP relocations are followed four bytes later by a LO12 and exactly 1 is LONE, and the lone one is `ldr x6, [x5, #0]`, where the offset is a literal zero known at ASSEMBLY time so there is nothing to fix up. The pair is a MASKING problem and not a RANGE problem, and no amount of reach would fix it, and the evidence that reach is irrelevant is on the same page: the target is FOUR BYTES AWAY. F7 is the cross-check and the POISON, and the coverage number is the transferable part: 1516 instructions read, 1516 named, 0 disagreements -- and 0 is the number a broken cross-check produces, so the model table is poisoned on purpose and the same loop re-run, and one bit in the `m_sysreg` guard moves the result to 1459 named and 57 disagreements. The coverage is then run three times with three different model sets, which is what turns "100% named" from a boast into a number: 21 models inherited from the encoding course name 1374 of 1516 (90.6%), the ABI course's six add 11, this course's own six add 131, and 1516 is 100% -- AND A COVERAGE NUMBER MEANS NOTHING ON ITS OWN BECAUSE IT IS A NUMBER ABOUT A CORPUS, which is why the same loop is printed three times. The provenance table has 57 rows and 21 are MEASURED, 5 MEASURED-ON-BYTES and 31 QUOTED, and the QUOTED third is larger than the other two together, which is the honest shape of a course about a machine that does not exist here. Serves 6 concept routes plus the landing, all 200, with 31 internal links resolved across twelve courses, prev/next chain and manifest minutes verified by `tools/verify_a64sys.py`, which also runs the artifact's 210-check harness against the SHIPPED `a64sys.out`; all 18 course verifiers report ALL CONSISTENT
- [x] P1 2.2.103 SIXTEEN retractions for the AArch64 machine course, all sixteen printed by the artifact in section 11 with a `SOURCES` MAP beside them and all sixteen asserted as TEXT by `crosscheck.py` so a taken-back claim can be neither quietly dropped nor edited into being right, and the map is the part that is new: thirteen of the sixteen name WHERE the claim was written down BEFORE this course existed -- the section plan, or the written brief -- and the three that do not say so and say "this course's own measurement" instead, because a retraction with no prior source is a course disagreeing with itself. NOT ONE OF THE SIXTEEN IS A MISTAKE ABOUT HOW A COMPUTER WORKS, which is ten courses in a row. (1) "The syndrome is a 32-bit field: EC, IL, ISS" -- RETRACTED, it is 32 bits INSIDE a 64-bit register, bits 55:32 are ISS2, and a 32-bit mask throws it away. (2) "The syscall number is the immediate in the SVC" -- RETRACTED, BOTH are in the emitted code and they are different claims: the field is the ARCHITECTURAL half and `x8` is the LINUX half, and the second is a convention rather than an instruction. (3) "The inherited decoder covers the encoding well enough" -- RETRACTED, it names FIVE words of the SYSTEM class and every instruction in this course is outside those five, and the direction of the error is the interesting part: the decoder is not wrong about the corpus, it is wrong about a CORPUS THAT IS NOT THIS ONE. (4) "NOP, WFI, YIELD and the rest" -- RETRACTED, and this is the only one of the sixteen with no prior source, because it was FOUND by this course's own two-reader loop: the guard is `bits[31:5]`, one bit too narrow, and it matches NOP alone out of the eleven hints the assembler accepts, and a model that is wrong about words the corpus does not contain is indistinguishable from a model that is right. (5) "One relocation per address reference, as SYSCALL does" -- RETRACTED, it is TWO, always, on AArch64, and see 2.1.79 F6 for why the reason is masking and not reach. (6) The `x8` claim, re-derived by assembling 111 argument placements across three optimisation levels rather than quoted, and -O0 spilling everything is the control that shows the other three are the specification's doing. (7) The `ESR` shift, a draft of concept 2 that taught a shift the register does not perform. (8) The vector table's order and its 0x80 stride, quoted and then MEASURED as 16 x 0x80 = 0x800 = 2048 bytes, so the arithmetic is checked even though the order cannot be. (9) "The assembler will tell you if a vector table is misaligned" -- RETRACTED BY THE TOOL, four of four accepted and zero diagnostics. (10) `VBAR` alignment, which is the same absence from the other side. (11) The TCR field positions, quoted with document and section, and the file states the difference between quoting and verifying wherever a claim depends on it. (12) "A 4 KiB table needs a pair of relocations" -- REFINED into the lone-ADRP rule, which is a sharper rule than the one it replaces rather than a correction of a number. (13) The 48/52 split, where all three numbers in the section plan are RIGHT and the retraction is the row the plan does not have: the five-bit field's floor. (14) "This course can compare against x86-64" -- RETRACTED, there are no timings in this course and none can be manufactured from it, which is why the sibling's 27.65x and 4.92x are named and refused rather than restated. (15) "Two independent readers" -- REFINED, they are `struct.unpack_from` and `llvm-readelf-21` and BOTH COME FROM ONE LLVM TREE, which is stated three times in the course because three is the number of places a reader stops reading. (16) "A 30-bit address space is a valid configuration" -- RETRACTED, T0SZ = 34 does not fit in five bits, so the row is removed rather than footnoted
- [x] P1 2.2.104 The AArch64 machine course's artifact is `courses/a64sys/assets/samples/a64sys.py` (3,906 lines, 12 sections) with `crosscheck.py` at 210 checks in 12 groups (A-L), and four design positions are the transferable part. (1) THE ARTIFACT IMPORTS ITS SIBLINGS' DECODERS AND ADDS ITS OWN, walking UP the tree to find them and overridable with an environment variable, so the course owns 6 of its 33 models and BORROWS 27 -- 21 from the encoding course and 6 from the ABI course -- which means the coverage figure in 2.1.79 F7 is a measurement about THREE courses' work rather than one, and a sibling that stops matching is a loud import error rather than a silent wrong number. (2) THE REAL BUG WAS FOUND IN THE SIBLING, NOT FIXED IN IT: the inherited decoder's `m_hint` guard is one bit too narrow, and the corrected model is PREPENDED in this course with the reason at the call site, because editing another course's artifact from inside this one would make the encoding course's own 243-check harness and this one's 210 disagree about which file is authoritative, and two harnesses that both pass and read different code is the failure mode this collection keeps paying for. (3) TWO READERS ARE A FLOOR, NOT A CEILING, and the course says so in the artifact's own LIMITS: both readers come from one LLVM tree and there is no second AArch64 assembler on this host, so every "refusal" in the file is a refusal by ONE assembler at ONE version, and a reader that reads that as a property of the architecture has made the same mistake the file was written to prevent. (4) THE OUTPUT IS COMMITTED AND THE HARNESS READS IT, so the course's claims are checkable on a machine that never ran its assembler; two runs of the artifact were compared BYTE FOR BYTE and are identical at 1,922 lines, and the second position is that a course whose claims can only be verified by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them, which is the same mistake as quoting a remembered number wearing a different hat. The 57-row `PROVENANCE` table with 21 MEASURED / 5 MEASURED-ON-BYTES / 31 QUOTED, the 15-entry `LIMITS` list and the 16-entry `SOURCES` map for the retractions are all STRUCTURES rather than prose, so a claim cannot acquire a label retroactively and a limit cannot be reworded into a strength
- [x] P1 2.2.105 The AArch64 machine course also produced a new tool, `tools/nesting_check.py`, which exists because of a defect in a PAGE rather than in a tool, and the defect is the most transferable thing in this entry. Three pages shipped with a unit div never closed -- `unit-model` on `a64-verify`, then `unit-reality` on `a64-pagetables` and `unit-example` on `a64-evidence` -- so the five units after it and the lesson footer were CHILDREN of it rather than siblings, and the browser built a DOM nobody wrote. EVERY EXISTING CHECK PASSED: `class="unit ` occurred exactly six times, `tools/html_balance.py` reported div 24/24 and "ok", its stack check found nothing because the tree was well formed, `tools/verify_a64sys.py`'s `units != 6` was satisfied, and the course verifier printed ALL CONSISTENT -- and the count cannot see the difference between six siblings and six nested descendants, which is the whole reason the tool exists. The tool reports and NEVER writes (the tool it complements runs a `repair()` that rewrites files by default, and its repair is what produced the `    </div>render_lesson_js(&mut page)` tail that gave the broken pages their false balance), and its single assertion is about DEPTH and nothing else: a unit div at any depth other than one below `.lesson` is swallowing its siblings, and the report names the opening line so the missing `</div>` is findable. Two stronger assertions were written, measured against the collection, and REMOVED rather than tuned: the collection has 22 legitimate unit shapes (206 pages use eight units including `interact` and `retrieve`, 12 use ten with `exercises`, and landing pages repeat `unit-example` because the repeated element is a card grid), and a long unit is a long unit -- `unit-reality` on `a64-pagetables` runs 185 lines of measured output and closing it sooner would mean cutting the measurement, which is what the page exists for. Four pre-existing `unit-exercises`-inside-`unit-connect` cases in courses predating the six-unit shape are allowlisted WITH A REASON and printed every run rather than silently tolerated, so an exception that gets fixed shows up as a stale entry and an exception that spreads shows up as a new filename. The regression is proved rather than asserted: deleting the one `</div>` from a copy of `a64_pagetables.ch` makes the tool name three swallowed divs and exit 1
- [x] P1 2.1.80 "The AArch64 Data Path: NEON, Atomics and Ordering" course COMPLETE: 5 concepts in 2 modules, 127 minutes. Depends on a64sys, and is the FOURTH and LAST of the four courses `docs/aarch64-section-plan.md` splits the old ARM64 item into, so all thirteen ARM64 roadmap items in `docs/courses-todo.md` are now ticked and the section is closed. It inherits the no-machine premise and this time LEADS WITH IT: the x86-64 sibling measured 3.89x, 4.92x and 27.65x and not one of those has a counterpart here, which is stated as a refusal rather than faked, because the honest alternative to a number is not a smaller number. What replaces the ratios is an instruction count, and the course measures one that points in the OPPOSITE direction to the one a reader expects -- the vectorised `sum_loop` is 34 instructions against the scalar 12, because the vectoriser pays for a prologue and an epilogue ONCE while the loop body runs n times, and a whole-function count measures code that runs once. F1 is the register file and the trap the section plan did not name: `ldr b0, [x0]` is 0x3d400000 and `ldr q0, [x0]` is 0x3dc00000, they differ in EXACTLY ONE BIT, and it is BIT 23 -- not bit 30, which really IS the Q bit in the three-same group two pages away -- so the access size is bits[31:30] PLUS bit 23, three bits with five allocated values, and A FIELD'S POSITION IS A PROPERTY OF AN INSTRUCTION GROUP AND NOT OF AN ARCHITECTURE. The same trap twice more in one concept: `fadd s0,s1,s2` and `fadd d0,d1,d2` differ in bit 22 alone so the float suffix is a TYPE at bits[23:22], and `fadd q0,q1,q2` DOES NOT EXIST at all because 128 bits is not a type but a DIFFERENT ENCODING -- `fadd v0.4s` at 0x4e22d420, six bits from the scalar form. And the first refusal that names a feature rather than a spelling rule: `fadd h0,h1,h2` is REFUSED at baseline with "instruction requires: fullfp16" and assembles at 0x1ee22820 with +fp16, TWO bits from the s form, so the encoding allocates four type codes and the baseline assembler will produce two. F2 is the course's cleanest single measurement and it is an ABSENCE: compile `add z0.d, p0/m, z0.d, z1.d` at -msve-vector-bits of 128, 256, 512, 1024 and 2048 and all five words are 0x04c00020 -- a factor of SIXTEEN in vector length and not one bit of difference, because the width is a property of the IMPLEMENTATION and is read at run time from the vector length register. SVE has no Q bit NOT because the field was forgotten but because an SVE vector is not a fixed 128 bits, so a bit that said 128 would be a lie, and that is the design rather than the omission. The field the size DOES live in is two bits at bits[23:22], immediately next to a six-bit operation field at bits[21:16] carrying twelve measured names, and the destination is also the second source because the assembler REFUSES `add z0.d, p0/m, z1.d, z1.d` -- three register fields, not four, and the second reader prints the destination twice. Sharing is done by sharing a CLASS: bits[28:25] is 0b0111 for Advanced SIMD, FP, AES and SHA-2 and 0b0010 for SVE, and the class is shared whether or not every member of the space is present, which is the definition of a shared space and also the reason a decode is a function of the CPU. F3 is why the retry is a LOOP rather than an instruction, and it is structural rather than numeric: the store-exclusive reports SUCCESS OR FAILURE IN A REGISTER, an instruction cannot act on its own output, so the only thing it can do is report, and reporting to a caller who must branch IS the definition of a loop. MEASURED: the acquire/release bit is BIT 15 and it is ONE bit, the same bit in a load and a store and at every width, and the first five XORs of the family all give 0x00008000. F4 is the section's sharpest bit finding and it cost a retraction: FEAT_LSE does NOT use one set of ordering bits for its group. CAS and CASP have acquire at bit 22 and release at bit 15; LDADD and its eight siblings have acquire at bit 23 and release at bit 22; bit 21 is 1 in EVERY word in both halves, so it is a CONSTANT of the group rather than an ordering bit; and CASP's 128-bit-ness is BIT 23 -- the bit that says "acquire" in the other half, so ONE BIT HAS TWO MEANINGS with no overlap, a few opcodes apart, and the question "does this word want a 128-bit atomic or an acquire" has no answer from a field diagram. The first draft of this course said bits 22 and 21 for the whole group and was wrong on both halves of the LDADD family, which is retraction R21 and was found by the CROSS-CHECK printing `ldadd` where the assembler prints `ldaddl` -- a wrong constant and a constant FIELD look identical until you sweep the suffix, and the wrong one promoted a relaxed atomic to a release one in a legal word with nothing wrong in it. F5 is the payoff and the section's cleanest contrast with x86-64: acquire and release are ACCESS MODES, and twelve functions performing C11 atomics emit THREE barriers, all three in functions whose source asks for a fence, at four optimisation levels across thirteen generated .s files. A C11 acquire load and a C11 seq_cst load are the SAME instruction -- one `ldar x0, [x0]`, 0xc8dffc01 -- and a release store and a seq_cst store are the same `stlr`, so the extra constraint a seq_cst load carries is on its relation to OTHER operations and is discharged by those being acquire or release too. Among the three that do appear an ACQUIRE fence narrows to `dmb ishld` and a RELEASE fence stays a full `dmb ish`, which is measured and NOT claimed to be wrong. F6 is the encoding of the barriers, and the finding is that they differ in TWO fields rather than one: a three-bit identity at bits[7:5] and a four-bit option at bits[11:8] carrying twelve names in sixteen codes, with the domain bits and the direction bits being the SAME four bits, so `ishld` is one of the combinations rather than a separate axis -- which means there is no way to say "inner, loads only" without spending a code. ISB accepts ONE option because `isb sy` is the same word as bare `isb`, and CLREX is in the same group at an op2 value no barrier uses, so four instructions share bits[31:8] and one of the four is not a barrier. F7 is `PSTATE.PAN`, where the assembler REFUSES the architectural name of a register it accepts the ENCODING of -- `msr PSTATE.PAN, x1` gives "expected writable system register or pstate" and `msr S3_3_C4_C0_2, x1` is 0xd51b4041 -- and the ID registers that would say whether this machine has LSE, SVE, FP16 or AES are EL1 registers with no EL1 here, so "is this word valid on the machine in front of me" is not a question this host can answer. The provenance table has 62 rows and 33 are MEASURED, 19 MEASURED-ON-BYTES and 10 QUOTED, and at 16% the QUOTED third is much the SMALLEST in the section, which is a direct consequence of what the subject is: an encoding and a compiler choice are exactly what a host without hardware can measure, and the ratio rises the moment a course needs to say what something DOES rather than what it is encoded as. Serves 5 concept routes plus the landing, all 200, with 14 internal links resolved across five courses, prev/next chain and manifest minutes verified by `tools/verify_a64simd.py`, which also runs the artifact's 268-check harness against the SHIPPED `a64data.out`; all 18 course verifiers report ALL CONSISTENT and all 29 course landings return 200
- [x] P1 2.2.106 TWENTY-SEVEN retractions for the AArch64 data path course, the largest list in the collection and the one with the most interesting internal structure, because SEVEN of the twenty-seven were found by ONE change and all seven are about what a COMPARISON is rather than about what an encoding is. Every retraction is printed by the artifact in section 13 with a WHAT WAS FOUND, a WHY, and an ASSERTED BY naming whether the claim predated the course (the section plan, or this course's own first draft); the summary paragraph's five kind-counts are COMPUTED from the list rather than written beside it, because the first version of that paragraph printed the literal string "%d of them" and a retraction list with a wrong summary is the failure the list exists to catch. Fourteen are about an ENCODING (R1 the Q bit is bit 23 not bit 30; R2 128-bit arithmetic is a different encoding six bits away; R3 the element size lives at three positions in three groups; R4 the DUP lane index is bits[19:17] and a three-step sweep reports a field one bit too WIDE; R5 the ld1 after-element offset is FOUR bits so `ld1 {v0.b}[16]` is REFUSED; R12 the barrier scope is a four-bit CRm the sibling's model FIXES to 0b1111; R16 the barriers differ in TWO fields; R18 a structure load's register field is FIVE bits holding the first register and a sweep of even starts only measures four of them; R19 `movi v0.2d, #imm, lsl #n` is REFUSED for all six n because the 64-bit form has no shift; R21 the LSE ordering bits; R23 the scaled imm12 offset is in BYTES and not BITS, so `str s0, [sp, #12]` is 0xbd000fe0 with imm12 = 3 and 3x4 = 12 where the first draft printed 96; R24 in CCMP the NZCV immediate is all five bits of bits[4:0] and the CONDITION is bits[15:12], two adjacent fields swapped; R25 the scalar element copy's index is `imm5 = (esz/8) * (2*index + 1)` and `imm5 >> 1` is right for NO arrangement in the table; R26 the 64-bit MOVI immediate is a BYTE MASK). One is about a COMPARISON and it is the largest single item in the course: R22, "the corpus has no disagreements between the two readers" -- RETRACTED, it has EIGHTY-FIVE, and every one was a real decoder defect hidden behind a normaliser that split operands on a comma without looking at brackets and then discarded the memory operand and every operand after the first. Four are about a COMPILER VERSION (R9 all four C11 orderings are the same four-instruction loop differing in one bit each; R11 an ACQUIRE fence narrows to `dmb ishld` and a RELEASE fence does NOT; R14 a 128-bit FETCH-ADD is two 64-bit `ldaddal` because LSE has no pair arithmetic, so a feature is not a blanket; R15 an instruction count can point in the OPPOSITE direction and here it does). Four are about what an INSTRUMENT is (R6 ld1/ld2/ld3/ld4 name ONE register and the rest are validated and discarded; R8 `casp` takes FIVE operands and the three-operand form's diagnostic points AT THE MEMORY OPERAND, the one that was correct, and a diagnostic that points at the right operand is a diagnostic that will be believed; R17 100% two-reader agreement is evidence the check can RUN and not that the decoder is correct; R27 removing one model poisons ONE of the two numbers and the first version's single poison moved the named count by 61 and the disagreement count by ZERO while the sentence underneath claimed both had moved). Four are about what a SPEC says (R7 SVE does not encode its vector length; R10 a C11 seq_cst load and a C11 acquire load are the same `ldar`; R13 PSTATE.PAN is refused by name and accepted by encoding; R20 a seq_cst order needs no barrier anywhere in this corpus). The two most transferable are R25 and R26, and they are a PAIR: R25 printed lane 6 where the lane is 1 and 6 is inside the legal range for that arrangement, and R23 was off by a factor of EIGHT -- both produced a PLAUSIBLE NUMBER rather than an error, and a plausible number is the one thing nothing downstream can catch, which is the whole argument for a second reader. R26 is subtler still: the first version DECLINED the 64-bit MOVI form and gave a true reason about the wrong field, and a decoder that declines is the safest kind of wrong because it can never print a false number -- which is exactly why it hides, since a table showing `reader 1: (none)` reads like a known gap rather than an unasked question. All 27 are asserted as TEXT by `crosscheck.py` so a taken-back claim can be neither quietly dropped nor edited into being right
- [x] P1 2.2.107 The AArch64 data path course's artifact is `courses/a64simd/assets/samples/a64data.py` (4,100+ lines, 14 sections) with `crosscheck.py` at 268 checks in 16 groups, and five design positions are the transferable part. (1) IT BUILDS ON THE TWO SIBLINGS RATHER THAN REUSING A SECOND DECODER: it walks UP the tree to find `a64asm/assets/samples/a64dec.py` (21 models) and `a64sys/assets/samples/a64sys.py` (6 more), owns 20 models of its own, and EXTENDS rather than edits the siblings -- `m_ldst_reg_corrected` and `m_ldst_fp_regoff_corrected` are new models PREPENDED in this course with the reason at the call site, because editing another course's artifact from inside this one makes the two harnesses disagree about which file is authoritative, and two harnesses that both pass and read different code is the failure mode this collection keeps paying for. (2) THE POISON IS THREE POISONS, ONE PER REPORTED NUMBER, and that is a correction rather than a design: the first version had one, it moved the NAMED count by 61 and the DISAGREEMENT count by 0, and the sentence printed under the numbers claimed that both had moved and that every difference was an exclusive -- so the run now prints [POISON FAILED] and the harness REQUIRES that sentence to be absent when any poison fails to move its own number. POISON B is the one worth understanding: removing `m_lse` changes NO named count and creates FIVE disagreements, and it is the only control in the course that can detect a decoder whose wrong answers happen to match the second reader's wrong answers -- which is what a shared spec error looks like, and no other check in the file would notice it. (3) EVERY NORMALISER RULE IS COUNTED AND A RULE THAT FIRES ZERO TIMES IS AN ERROR, because this file produced FOUR normaliser bugs -- a comma split that ignored brackets, an operand list truncated after its first element, a zero-offset rule written for the one spelling neither reader emits, and a shift-modifier rule for a spelling that does not exist -- and NOT ONE OF THEM PRINTED A WRONG WORD. All four made the file stop COMPARING, which is strictly worse than printing a wrong word because a wrong word shows up as a disagreement and a stopped comparison reports the same number as a working one. That is 2.2.106's R22 and it is the single most useful thing the course found. (4) THE CORPUS IS A NAMED CONSTANT BECAUSE IT WAS WRONG IN THREE PLACES AT ONCE: `CORPUS_OBJECTS` exists because `pair_base.o` was missing, so the exclusive-PAIR path -- the whole point of concept 3 -- was in the disassembly a reader sees and in no object file the cross-check reads, and `m_lse` was reading `0xc87fa009` as `caspal x31` for a whole draft with a 99% coverage figure printed the entire time. A COVERAGE NUMBER IS A NUMBER ABOUT WHAT WAS FED TO IT, and the build script now says so in a comment next to the line that was missing. (5) THE OUTPUT IS COMMITTED AND THE HARNESS READS IT: `a64data.out`, `run1.txt` and `run2.txt` ship with the course, all three are BYTE-IDENTICAL at 1,659 lines and md5 fc6015d0..., and `crosscheck.py` asserts that identity as its own check. The 62-row `PROVENANCE` table (33 MEASURED / 19 MEASURED-ON-BYTES / 10 QUOTED), the 27-entry `RETRACTIONS` list with its five computed kind-counts, and the 14-entry `LIMITS` list are STRUCTURES rather than prose, so a claim cannot acquire a label retroactively and a limit cannot be reworded into a strength; the sixth limit is the one this course had to learn the hard way, and it is `A ZERO FROM A NORMALISER IS NOT A ZERO`
- [x] P1 2.2.108 The AArch64 data path course CLOSED the section and produced two findings about the COLLECTION rather than about the subject, both of which are now in the shared tools. (1) A LABEL RENDERED TWO WAYS IS NOT A LABEL: this course's artifact DEFINED all three of MEASURED, MEASURED-ON-BYTES and QUOTED and then used only two of them in the same form -- `[MEASURED]` and `[MEASURED-ON-BYTES]` as line prefixes, `QUOTED` only inside a sentence as `QUOTED (ARM DDI 0597, ...)` -- so a reader scanning a page for a claim that is NOT measured would find two labels rendered one way and the third another, and would reasonably conclude the third is the odd one out. The artifact's `para()` helper now emits the bracketed `[QUOTED]` tag itself, from the text of the paragraph, and the harness COUNTS how many times each of the three appears in its own form; the count is 28, 12 and 5 in the shipped run. This is a defect in the AArch64 section's own rule 13, found by the rule-13 harness, and it is the reason the other two sections should check their own labels the same way. (2) A CONCEPT ID IS RESOLVED GLOBALLY, AND THREE COURSES WERE ABOUT TO COLLIDE ON IT: this plan gives the artifact concept the id `a64-verify` for all three of the later courses, and `render_concept()` in `web/src/helpers.ch` takes a concept id with NO COURSE IN THE KEY -- so the second course to ask for a name silently serves the first one's page, with no diagnostic from anywhere. The section has now been renamed three times for that reason (`a64-verify` -> `a64-evidence` -> `a64-dataflow`) and this course's ids differ from the plan's in TWO further places, both deliberate and both recorded where the ids are resolved: `a64-crypto-simd` became `a64-neonspace` because a concept id should name what the reader is left HOLDING rather than the topic it covers, and `a64-ldst` was FOLDED into it because `ld1`/`ld2`/`ld3`/`ld4` live in the same opcode space as the rest of the vector file and the concept's entire point is that the structure load's size is bits[11:10] and its Q bit is bit 30 while the single load's size is bits[31:30] PLUS bit 23 -- splitting them across two concepts would have separated the measurement from the comparison that makes it mean anything. All five of this course's ids were checked by grepping every shipped manifest before any of them was used, and `tools/verify_a64simd.py` checks the prev/next chain against the MANIFEST rather than against the plan for the same reason. Section totals after this course: four courses, 21 concepts, 529 minutes, and all thirteen ARM64 roadmap items ticked
- [x] P1 2.1.81 "RISC-V: The Encoding Spectrum" course COMPLETE: 5 concepts in 2 modules, 127 minutes, and it is the FIRST of the four `docs/riscv-section-plan.md` splits the nine RISC-V roadmap items into, so items 1 (ISA), 2 (Assembly) and 3 (Instruction Encoding) are now ticked. It inherits the no-machine premise from the AArch64 section and this time LEADS WITH IT, because on this host the absence is not "no emulator" but "no RISC-V binutils either" -- qemu-riscv64, spike and riscv64-linux-gnu-{gcc,as,ld} are ALL absent, so there is no RISC-V machine, no emulator, and no linker, and every figure in the course is a bit pattern, a count of bit patterns, an arithmetic identity, or a refusal from a real assembler. The x86-64 section's speedup ratios and the AArch64 section's density ratios have NO counterpart here and are not invented to fill the gap; the honest alternative to a number is not a smaller number, it is a byte count, and the course says which it is carrying on every page. F1 is the length rule and it is the whole architecture in two bits: `if bits[1:0] == 0b11` the instruction is 32 bits, else 16 -- a rule that needs two bits of the current position and NOTHING ELSE, so a decoder with no model at all for an instruction still steps over it correctly. MEASURED over 9 code sections of 9 objects: 1,082 instructions and EVERY WALK ENDS EXACTLY ON ITS SECTION END, which is a measurement and not a definition, and the guarantee is what makes a word this decoder cannot name still contribute its own length. The three exemplars are the spectrum in two lines: `add a0, a0, a1` is `0x0000952e`, TWO bytes, and `vsetvli t0, a1, e64, m1, ta, ma` is `0x0d85f2d7`, FOUR. F2 is a retraction of the plan's CENTRAL prediction, and it is the reason this course's first concept had to be written after the measurement rather than before it. The plan said "the same register number sits in different bit positions in different formats, and that is why an assembler is not a lookup table." MEASURED, the register fields do NOT move: rd is bits[11:7], rs1 bits[19:15], rs2 bits[24:20], in EVERY format, and the manual says so and says what pays for it -- "the instruction format was chosen to keep all register specifiers at the same position in all formats at the expense of having to move immediate bits across formats". The immediates are where the variation went, and that is a measurable bill: the S mask is 0xfe000e00 and the B mask is 0xfe000f80 and they differ by EXACTLY BIT 7, which is the S format's imm[0] and the B format's imm[11], one bit being the two ENDS of a displacement. The U and J masks are IDENTICAL (both 0xfffff000, twenty contiguous bits) and the two fields are nothing alike, which is the sentence the course ends concept 2 on: A WINDOW AND A FIELD ARE DIFFERENT OBJECTS. F3 is the one that costs something, and it is in the register file rather than the encoding space: the compressed extension's rd' is a DIFFERENT register encoding -- three bits at bits[9:7], two positions lower -- and its value 0 means x8, so a decoder that reads it with a five-bit lookup reports every register seven too small, every operand is a real register, and nothing about the output looks wrong. The QUOTED reason it is that way is a coupling between three documents no one specification reveals: "The RISC-V ABI was changed to make the frequently used registers map to registers x8-x15. This simplifies the decompression decoder by having a contiguous naturally aligned set of register numbers." F4 is the honest half of the C extension, and the plan had it badly wrong. The plan said "a large fraction of the 16-bit space" and the artifact's first draft measured the assembler REFUSING 16,384 of 65,536 half-words, which is exactly a quarter and exactly `bits[1:0] == 0b11` -- a fact about the LENGTH RULE and not a reservation at all, and the diagnostic says so: "instruction length does not match the encoding". Of the 49,152 REACHABLE patterns, 2,409 are RESERVED, which is 4.90 per cent, and ONE cell (quadrant 0, funct3 = 100) is 2,048 of the 2,409 because the cell held C.FLWSP in the RV32 draft and C.LD needed the slot in RV64 and the merged columns gave the cell up entirely. The exhaustive cross-check against the second reader agrees on 2,408 of 2,409 and the one disagreement is 0x0000, which this file calls RESERVED and the reader prints as `unimp` -- and both are right about their own subject, so it is REPORTED rather than normalised away. The other half of C's cost is a refusal a reader can see: `c.lw t0, 0(a0)` is REFUSED by the assembler and `lw t0, 0(a0)` is four bytes, and the difference is three bits of register field. F5 is the permutation measurement the section plan asked for and the inherited artifact did not have: eleven compressed displacement families share five bit positions and are assigned SEVEN DISTINCT ORDERS, derived rather than asserted by sweeping every reachable value and finding for each bit of the produced value the instruction bit that is 1 in exactly the same offsets. c.lw and c.ld have the IDENTICAL five-bit window 0x00001c60 and different orders -- v[0] is at inst[6] in one and at inst[10] in the other -- which is the proof that a field map, which is what every other architecture in this collection has and what concept 2 measured, is NECESSARY AND NOT SUFFICIENT here. F6 is the best measurement in the course and the plan did not predict it: asking the assembler for a branch past the B-type's reach does NOT produce a diagnostic. `beq a0, a1, .+4096` is accepted and assembled into TWO instructions -- an inverted branch over an unconditional jump -- and the program means what the programmer asked, so no test that checks "does the program work" finds it. The diagnostic appears only at 1 MiB and the word in it is FIXUP rather than displacement, which is a relocation-shaped failure and the first appearance of that word in the course. The reach itself is +4094 and -4096 and the ends are NOT the same magnitude, because a 13-bit two's-complement field with a FORCED ZERO at bit 0 is not symmetric about zero. F7 is the measurement the section exists for and it is an ABOMINATION that turned out to be the content: the artifact's first run reported 354 agree and 701 disagree of 1,055, and the 701 was not one number. It was 116 words decoded by a model with NO funct7 guard sitting above the model that owns them, 62 words reported UNDEFINED because a model that DECLINES raised Undefined instead of Bad and Undefined stops the dispatch, 33 words of a c.mv that was UNREACHABLE because the compressed cell was dispatched on `rs1 == 0` rather than on inst[12], 91 branches that had lost BOTH their register operands, 26 branch targets off by exactly one because inst[8] was mapped into imm[0], 35 words of a shift amount printed as twelve bits when the field is six, 8 fcvt rows with the source and destination swapped, and the rest printing conventions. "A number is evidence when it is a large number" is retraction R22 and the arithmetic that decomposes the 701 is printed in full. The 1,047 that agree now agree because the seven hundred were fixed one at a time, and the course's claim is not that the decoder got better but that RETRACTING A NUMBER IS NOT THE SAME AS RETRACTING THE WORK: THE WORK IS THE SEVEN HUNDRED. Serves 5 concept routes plus the landing, all 200, prev/next chain and manifest minutes verified by `tools/verify_rvasm.py`, which also reads the SHIPPED `rvdec.out` and requires all FOUR poison verdicts to say FIRED with non-zero deltas, all 47 normalisation rules to have fired, and all 22 retractions to be present by name; the artifact's own 128-check harness passes against the shipped recording and `run1.txt` and `run2.txt` are BYTE-IDENTICAL
- [x] P1 2.2.109 The RISC-V course produced SEVEN findings about the COLLECTION rather than about the subject, and four of them are new failure modes this codebase had not seen. (1) A NORMALISER RULE THAT DELETES AN OPERAND MAKES TWO READERS AGREE BY DELETING THE SAME OPERAND, and the way to make a cross-check immune is a design rule rather than a patch: EVERY rule in this course's 47 EXPANDS. `c.add a0, a1` becomes `add x10, x10, x11` and `add a0, a0, a1` becomes the same string -- both sides GAIN the implicit operand, so a decoder that read the wrong register produces a different canonical form and is caught. Every rule is a function from a printed line to a line with the SAME OR MORE information in it, and the harness asserts the property by construction rather than by inspection. (2) A POISON CAN ASK FOR A DIRECTION THE NUMBER CANNOT MOVE IN, and [POISON FAILED] can then be CORRECT while the ASSERTION is wrong. The first version of poison 4 broke the normaliser and asserted the agreement count would go UP; it did not move, and the verdict was correct -- you cannot raise a count that is already at 100 per cent, because there is nothing left to agree about. The corrected version PLANTS a real disagreement (168, by corrupting one operand of every `addi`), confirms the check catches it, and then shows the AArch64 rule makes 47 of those 168 disappear. A control that cannot be made to fail is not a control, and the only way to know whether yours can is to make it fail on purpose. (3) A POISON'S VICTIM MUST BE CHOSEN BY THE MEASUREMENT THAT MATTERS, and the wrong measurement produces a control that cannot move. The first version picked the model with the largest footprint measured ALONE in the dispatch table, which is not a model's footprint: a model owns the words the dispatch ACTUALLY GIVES it, and on this corpus the two differ by a factor of two and a half (i_alu_imm names 472 words alone and 188 in the dispatch) because 284 of the 1,082 instructions are TWO BYTES and are decoded by a handler that is not in the model table at all. The poison reported [POISON FAILED] against a control that could not have moved, and the correct reading of that verdict is about the CHOICE and not about the decoder. The victims are now chosen from the data, in dispatch, three of them rather than one, and each delta EQUALS its victim's own footprint -- a model that owns N words and a control that moves N numbers are one number counted twice, and their agreeing is what makes the number mean something. (4) A REPORTING STRUCTURE THAT CANNOT REPRESENT THE FAILURE IT EXISTS TO REPORT IS THE THIRD INSTANCE OF THE SAME BUG, and this one is the subtlest. The normalisation fire-count was created LAZILY -- a rule's entry appeared the first time it matched -- so a rule that never fired was ABSENT from the table rather than present with a zero, and the dead-rule check iterated over the same dictionary and therefore COULD NOT FAIL. Four of the 47 rules were dead on the first run of the new normaliser, every one for the same reason: the pattern was anchored with `^mnemonic` and the text has a SPACE there, which is the AArch64 bug reproduced in the file that quotes it. The fix is to pre-seed the counter with every rule name at zero, so a dead rule is a ROW WITH A ZERO, and the same reasoning now governs the disagreement classifier -- it prints its nine rows on EVERY run including a clean one, because a table that appears only on failure cannot be checked on the run where it has nothing to say. (5) The section plan's prediction about the register fields is INVERTED, and that is recorded where the ids are resolved: `docs/riscv-section-plan.md` gives the id `rv-verify` to BOTH this course and the privileged-architecture course, and `render_concept()` in `web/src/helpers.ch` resolves concept ids GLOBALLY with no course in the key, so the second course to ask silently serves the first one's page with no diagnostic from anywhere. This course took it because its artifact IS a verification, and the note above `render_rvasm_concept` says so in the place a future author will read. (6) All five ids are `rv-` prefixed and the prefix was checked against all twenty-nine shipped courses by reading `helpers.ch` rather than by assuming, and it is one the section's other three courses can continue. (7) The three paths in AGENTS.md for the server build (`lang/compiled/underlayer/chemical.mod` and `cmake-build-debug/TCCCompiler`) DO NOT EXIST on this checkout: the root `chemical.mod` is the application module and the compiler is at `/home/wakaztahir/work/Chemical/chemical/cmake-build-debug/TCCCompiler`, and every command in AGENTS.md that names the other two is stale. That is a documentation defect in the file every agent reads first, and it is recorded here rather than worked around silently
- [x] P1 2.2.110 The RISC-V course's artifact is `courses/rvasm/assets/samples/rvdec.py`, 7,155 lines, and it is the first artifact in the collection whose OWN HEADER leads with what it cannot do. It opens by printing the two-bit length rule, then `add a0, a0, a1` at two bytes beside `vsetvli` at four, and then says NO TOOL DECODES ANYTHING -- part one imports `os`, `re`, `struct` and `sys` and nothing else, reads the ELF64 section table by hand with `struct.unpack_from`, and finds `.text` by NAME, because a decoder that shells out to a disassembler is a disassembler with a hardcoded path in it. Its corpus is nine objects: the same eleven functions of ordinary C at eight `-march` settings plus a 125-line hand-written assembly file, built by `assets/samples/build_samples.sh`, which PRINTS the toolchain it found and the toolchain it did not (`linker: riscv64-linux-gnu-ld IS NOT INSTALLED`, `emulator: qemu-riscv64 ABSENT`, `emulator: spike ABSENT`) and then says the sentence out loud: NOTHING IN THIS COURSE IS EVER EXECUTED. The object files are NOT committed and `rvdec.out`, `run1.txt` and `run2.txt` ARE, so a reader can check every figure in the course without installing a cross-compiler and a course whose numbers are only checkable on the machine that wrote them is a course whose numbers are claims; `.gitignore` documents the distinction in a comment rather than with a pattern alone. `run1.txt` and `run2.txt` are BYTE-IDENTICAL, which is the determinism check the AArch64 and x86-64 sections established and which is cheap to run and expensive to omit. `crosscheck.py` is 128 checks that re-ask the recorded output and re-measure nothing, and it is deliberately asymmetric: the bit patterns, the field masks, the 2,409 reserved code points and the immediate reaches are asserted as EXACT NUMBERS because exact quantities have no business being ranges, while the `-march` sweep is asserted as a SHAPE -- that rv64i GAINS three mnemonics and LOSES four, and that rv64imafd -> rv64imafdc changes the byte count without changing the instruction count -- because a value there moves with the compiler and a shape does not, and a check whose threshold is a bare number is a check that fails on a busier machine and teaches its reader to ignore it. The harness additionally asserts all twenty-two retractions PRESENT AS TEXT by name, because a retraction that is quietly deleted is the one failure no number can catch, and it asserts the poison machinery against the artifact's SOURCE rather than against its output, since on a clean run no poison prints a failure string and asserting that string against the recording would be asserting that a failure did not happen
- [x] P1 2.1.82 "The RISC-V ABI, and the Register That Isn't There" course COMPLETE: 4 concepts in 2 modules, 101 minutes, and it is the SECOND of the four `docs/riscv-section-plan.md` splits the RISC-V roadmap into, so roadmap item 4 (RISC-V Calling Conventions) is now ticked. It inherits the no-machine premise from its section sibling and this time the subject IS performance, so the temptation to fake a ratio is at its highest and the refusal is stated in the artifact's own header, in section 1, in the caption of every cross-architecture table, and in the first unit of the landing page: THERE ARE NO TIMINGS IN THIS COURSE, the x86-64 ABI course's 4.92x and 27.65x are NAMED AND EXPLICITLY DISCLAIMED rather than quietly omitted, and a module-level comment records that a course which quietly implied a runtime measurement it did not take would be the exact failure this collection exists to name. F1 is the section's spine and it is an ABSENCE, measured in three disjoint sets: the eleven functions of `noflags.c` compiled for three targets yield 17 branches (blt, bge, c.beqz, c.bnez, bne), 16 conditional moves (csel, cneg) and 16 more (six cmov spellings), and the artifact COMPUTES the intersection of every pair and prints it whether or not it is empty -- union 13, sum of the three sets 13, so the disjointness is a measurement and not a paragraph. The first version asserted the word "disjoint" in prose and never computed an intersection, and that is the same failure shape as the zero-disagreement cross-check: a claim with no arithmetic under it. F2 is the CONSTRUCTIVE half, which is the half nobody states and the reason the course is 27 minutes rather than 8: because `sltu` WRITES A REGISTER and sets no flags, `(x < 0) ? 1 : 0` is ONE instruction -- `srliw a0, a0, 0x1f`, 4 bytes -- where x86-64 would need a `SETL` that does not exist, so the absence of a condition-code register is not only a cost but what makes min/max/clamp/abs expressible without a conditional move at all. And the AArch64 side is DECODED rather than named: `csel` is read out of the emitted words by the sibling AArch64 course's `a64dec.py`, the CONDITION is shown at bits[15:12] as a FOUR-BIT field on 0x1a81b000 and 0x5a805400, and the out-of-encodings argument is ARITHMETIC -- three register fields plus a 7-bit immediate in a 32-bit word leaves no room for a 4-bit condition, so `csel` is a different ENCODING and not an instruction with an extra field. The first version of that table matched the disassembly with `\s+` after the instruction word, which consumed the tab along with the padding, captured the first OPERAND instead of the mnemonic, matched nothing, and the section that exists to prove `csel` is an instruction reported no instruction and no error. F3 is the calling convention measured as a CONTRACT rather than quoted: 44 of 44 register-resident integer argument placements agree with riscv-cc at -O2, read out of the RELOCATION each store carries rather than out of a text file, and the denominator is arithmetic (1+2+...+8 from i1..i8 is 36, plus 8 more from i9) rather than a convenience. The row no summary gets right is the ninth DOUBLE: with fa0-fa7 exhausted it is passed "ACCORDING TO THE INTEGER CALLING CONVENTION" and arrives in a0, an INTEGER register, and `f9` reads NO stack argument at any optimisation level. The two independent argument counters are then settled by `m18` -- nine integers then nine doubles -- which is the case that separates the hypotheses and which reads EXACTLY offsets 0 and 8, with the ninth integer in t0 and the ninth double in ft0, so both went through a TEMPORARY and the load that filled it is the only evidence the value came from the stack at all; a register-based audit with no load audit reports a temporary and a reader has no way to know whether it was filled from the stack, from a global, or from nowhere. F4 is the register file as ROLES and the file's own worst bug is in this section. The ABI names roles, `s0` is x8 and also `fp`, `gp` and `tp` are UNALLOCATABLE rather than merely preserved and are measured at 0 writes across the whole corpus, and `li zero, 42` ASSEMBLES to four real bytes while the discard is a property of silicon this host does not have -- which is why the twelfth limit SEPARATES THE ENCODING FROM THE HARDWARE rather than merging them. The trap is that there are TWO REGISTER FILES: `fsd fa0, -24(s0)` has rs2 = bits[24:20] = 10 and rs1 = bits[19:15] = 8, the same five bits and two different registers (10 is a0 in the integer file and fa0 in the floating-point one; 8 is s0 and fs0), and A REGISTER NUMBER IS NOT A REGISTER UNTIL YOU KNOW WHICH FILE IT IS IN. This file answered "which file" ONCE PER INSTRUCTION rather than per field, so the base of every floating-point load was read as floating-point, and the register census reported 18 writes to `gp` and 8 to `tp` over a corpus in which the compiler writes neither -- because a real `a2` read in the wrong file comes out as `fs2`, and `fs2` read as an integer is `x18`, which is `s2`, so a wrong lookup turns one register into another. Nothing in that table looked wrong. The fix is a second reader: the census is preceded by an AUDIT that compares this file's bit-level reading against the inherited decoder's PRINTED OPERANDS instruction by instruction, 5,973 checked and 5,973 agreeing, and that audit took four rounds of real bugs to reach 0 -- the B format's rs2 is at bits[24:20] and not bits[20:15], and `c.srli`'s rd' is at bits[9:7] and not bits[4:2]. F5 is the compression CONSEQUENCE and NOT a repeat of the sibling's encoding page: a spill goes 11 instructions/44 bytes to 11/26, a call/return pair 4/16 to 4/10, and the hot loop's BODY -- the part that runs n times rather than once -- 44 bytes to 28. The methodological result matters more than either: `rv64i` against `rv64gc` is CONFOUNDED because it also removes F and D, so every `double` becomes a soft-float CALL and the -38 it reports for `regs.c` is the library and not the encoding, while the CLEAN pair `rv64imafd` against `rv64imafdc` gives +0, +0 and +6 -- the +6 falsifying "compression never changes the instruction count" as surely as the two zeros falsify the opposite, because the compressed forms can only name x8-x15 and a register allocator that must respect that sometimes reaches for a register the uncompressed encoding would not have needed. And `spilln` goes 43 instructions/172 bytes to 49/124, so the callee that spills eight registers does MORE work compressed in a SMALLER frame, which is retraction R7. The section closes on the boundary problem: 6,048 instructions found by the two-bit rule against 5,012 with the length handed in, and the two counts are NOT equal, which is what proves the rule is load-bearing -- an instruction count and a byte count, explicitly not a speedup. Serves 4 concept routes plus the landing, all 200, prev/next chain and manifest minutes verified by `tools/verify_rvabi.py`, which also reads the SHIPPED `rvabi.out` and requires all FOUR poison verdicts to say FIRED with non-zero deltas, all 12 retractions to be present by name with no gaps, the twelve limits to be NUMBERED 1..12 at the start of a line, and the corpus-completeness check to print its own verdict on a complete run
- [x] P1 2.2.112 The RISC-V ABI course produced THREE findings about the COLLECTION rather than about the subject, and all three are new failure modes this codebase had not seen. (1) A HARNESS CAN CONTAIN A CHECK THAT NO OUTPUT CAN SATISFY, and the only way to find it is to run it against a CORRECT measurement. The m18 row's third group was `(\S+)` and the assertion underneath compared that group against the string `"0, 8"`, which contains a space -- so the check failed against a measurement that was right (m18 does read offsets 0 and 8, exactly as riscv-cc says) and would have failed against every possible output. The repair widened the GROUP to `(\S.*?)` and left the equality test exactly as it was, and it is recorded at the call site rather than in a comment nobody reads: A HARNESS BUG REPAIRED BY LOOSENING WHAT IT ASSERTS IS A DIFFERENT THING FROM THIS, AND THIS IS NOT THAT. This is the ninth course in a row to establish that a harness is found by running it, and the FIRST whose failure is purely about the shape of a string rather than about a number it computes -- and the reason it survived so long is that the artifact underneath it was correct, which is the most comfortable possible place for a check to be wrong. (2) A DECODER READS THE FIELDS ITS RENDERING NEEDS, AND ASKING IT FOR A FIELD BY NAME IS A CONTRACT IT NEVER MADE. The inherited `rvdec.py` emits ONE `field()` line per field it READS, and for `c.sdsp ra, 24(sp)` the CSS format's rs2 is a five-bit field at inst[6:2] whose only job is to be printed, so it explains that field in PROSE and the lookup returned nothing. The consequence was not a crash and not a zero: the store audit reported the eighth integer argument of `m18` as having arrived in `t0` when it arrived in `a7`, and the ninth double as arriving in `zero`. And the second bug was worse, because it is `rvasm`'s own concept-5 finding turned against this file: a COMPRESSED register field is THREE bits whose value 0 means x8, so reading it with the five-bit table reports every register eight too small, and the register census printed 131 writes to `x0` on an architecture where x0 is hardwired to zero and can never be written. A decoder's field report is not an API and asking it for a field it did not emit is indistinguishable from asking for a field that does not exist -- and the fix, which is this course's most transferable design position, is an AUDIT THAT COMPARES THE READER AGAINST A SECOND RENDERING OF THE SAME BITS: this file reads the register fields from its own per-format table and checks all 5,973 of them against the operand list the inherited decoder PRINTED, a different piece of code in a different file choosing its own fields. It found the B format's rs2 (bits[24:20], not bits[20:15] as the table first said), `c.srli`'s rd' (bits[9:7], not bits[4:2]), the implied x2 base of the stack formats, the CA format naming rd and rs1 in the same three bits, and `fmv.d.x` being the one instruction whose destination is `fa` and whose source is `a`. THE ANSWER TO "WHICH FILE IS THIS REGISTER IN" IS PER FIELD AND NOT PER INSTRUCTION, and the file now says so in the docstring of the function that decides it. (3) A NUMBER WITH NO DENOMINATOR BESIDE IT IS INDISTINGUISHABLE FROM A BUG, and this course produced the same failure twice by two different routes. The zero-spelling census asked the decoder for a field named `imm` when the decoder writes that line under the name `immediate`, so the lookup returned None on every instruction and all four counts printed ZERO -- which reads exactly like "the corpus contains no zero-spelling at all", and is a claim a reader would have believed. The census now reads the immediate from the BITS, prints the 260-instruction denominator beside the 18 that have a zero immediate, and the surrounding paragraph says what the denominator is for: A COUNT OF ZERO OUT OF 260 IS A MEASUREMENT AND A COUNT OF ZERO OUT OF ZERO IS A BUG WEARING THE COSTUME OF A RESULT. The second route is the same lesson in a different place: the twelve limits were printed with `'  %2d. '`, which right-aligned the number in two columns and produced THREE leading spaces for limits 1 to 9 and two for 10 to 12, so the list was numbered and no reader, script or harness could find its own numbers -- A NUMBERED LIST WHOSE NUMBERS ARE NOT AT THE START OF THE LINE IS NOT NUMBERED. The harness checks the numbering with a pattern and the verifier checks it a second time, because the same defect is invisible to a count
- [x] P1 2.2.113 The RISC-V ABI course's artifact is `courses/rvabi/assets/samples/rvabi.py`, 4,100+ lines, 12 sections, and three of its structures are STRUCTURES rather than prose so that a claim cannot acquire a label retroactively and a limit cannot be reworded into a strength. (1) THE THREE LABELS ARE DEFINED IN THE ARTIFACT'S OWN HEADER AND COUNTED BY THE HARNESS, and the shipped run has 33 MEASURED, 15 MEASURED-ON-BYTES and 19 QUOTED across the 25-row `PROVENANCE` table, with every QUOTED row naming a document and a section (`riscv-cc` and `rv32-unprivileged` throughout). This is 2.2.108's finding applied to a second section: a label rendered two ways is not a label, so the harness counts all three and the verifier requires each to be non-zero. (2) THE CORPUS IS A NAMED CONSTANT AND ITS COMPLETENESS IS CHECKED ON EVERY RUN, including on a run where it passes: the report prints THE CORPUS IS INCOMPLETE as the NAME of the check with its own verdict, because the check previously lived only in the failure branch of `main()` and the harness asserted the sentence was in the output -- so on a COMPLETE run the sentence was absent and the check failed against a healthy artifact. That is the same shape as the AArch64 fire-table finding and as this course's own corpus-completeness result, and it is the third course in a row to place a check on the success path. (3) `run1.txt` and `run2.txt` ARE BYTE-IDENTICAL and `rvabi.out` ships with the course, so the 171-check harness runs on a machine that never ran the cross-compiler. The four poisons are what make the zero mean something, and their DESIGN is the transferable part: poison 1 removes BOTH corrections this file prepends and claims TWO numbers, poison 2 removes one of them and claims only the UNMODELLED count -- and the reason that split exists is that removing `m_shift_imm_fixed` creates a HOLE and not a disagreement, so the cross-check reports ZERO disagreements on a corpus where it has just lost 36 instructions, which is the exact shape of the AArch64 data-path bug the section exists against and the reason the unmodelled count is a first-class number here rather than a footnote. The deltas are +6 disagreements and +36 unmodelled for poison 1, +36 unmodelled for poison 2, -1,036 instructions for poison 3 (the two-bit length rule against a supplied length) and 4,420 of 5,641 planted disagreements HIDDEN for poison 4 (an AArch64-shaped normaliser that keeps the mnemonic and the first operand). All twelve retractions are asserted as TEXT so a taken-back claim can be neither quietly dropped nor edited into being right, and NONE of the twelve is a mistake about how a computer works -- twelve courses in a row
- [x] P1 2.3.1 THE x86-64 SECTION IS COMPLETE: four courses, 26 concepts, 662 minutes, 778 harness checks, all 18 roadmap items ticked in `docs/courses-todo.md`, all 25 course landings 200 and all 15 course verifiers reporting ALL CONSISTENT. This is the item that closes the section the founder authorised on 2026-09-29, and the thing worth recording is not the count but what the four courses cost each other. (1) THE PLAN GAVE THE LAST CONCEPT OF ALL THREE REMAINING COURSES THE ID `x86-verify`, AND A CONCEPT ID IS RESOLVED **GLOBALLY** by `render_concept()` in `web/src/helpers.ch` with no course in the key, so three courses could not share one: `x86abi` took it, `x86sys` took `x86-boundary` and `x86simd` took `x86-bytes`. THE RULE THAT CAME OUT OF IT is written at the call site and is the transferable part: THE ONLY CONCEPT IDS THAT SURVIVE ARE THE ONES NOBODY THOUGHT OF FIRST -- name a concept for the thing it measures, and `grep -n '"<id>"' web/src/helpers.ch` before planning it rather than after. (2) EVERY COURSE SHIPS ITS RECORDED ARTIFACT OUTPUT, so each harness runs on a machine that never ran its benchmark, which is the property the section plan asked for and the reason `crosscheck.py` takes a path argument and defaults to the recorded file: a course whose claims can only be checked by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them. (3) NOT ONE OF THE 14 + 10 + 10 + 24 = 58 RETRACTIONS ACROSS THE FOUR COURSES IS A MISTAKE ABOUT HOW A COMPUTER WORKS, and the three courses arrived at that from different directions -- a bit number read out of a register instead of remembered, a thread id that was never used, a section header counted as an instruction -- which is the collection's central argument stated three times in three different vocabularies. (4) THE RULES IN `docs/x86-64-section-plan.md` DID NOT GROW A THIRTEENTH, WHICH IS THE RESULT, BUT THREE OF THE TWELVE WERE SHARPENED BY THE FOURTH COURSE IN WAYS THE FIRST THREE COULD NOT HAVE KNOWN: rule 1 (the artifact is not finished when it RUNS -- its cross-check reported 28 failures and was believed) gained a second half about checking the second reader; rule 10 (assert structure exactly and timings as orderings) gained its sharpest illustration, a floor that measured above the thing it floored; and rule 3 (inline asm for anything that must not be optimised away) gained a variant nobody had written down, that a LAYOUT is a claim and belongs above the table rather than in a comment. (5) THE SECTION'S ONE DELIBERATE INCOMPLETENESS IS THE THIRD CONCEPT OF `x86simd`: this machine cannot execute one instruction in it, and the concept is reference plus a bytes-only decoder with every claim marked QUOTED against MEASURED, because A REFERENCE FOR A FEATURE YOU CANNOT RUN IS STILL WORTH WRITING PROVIDED EVERY SENTENCE SAYS WHETHER IT WAS MEASURED -- the alternative leaves a reader with no way to tell a quoted claim from a tested one. Recorded in `docs/x86-64-section-plan.md` under "The section is complete (2026-09-29)"
