# Underlayer — Skills Index

Comprehensive documentation for the Underlayer project (root `chemical.mod`, modules under `core/`, `database/`, `models/`, `repository/`, `learning/`, `web/`, `content/`). Load the relevant skill before working on a particular area.

## Quick Start: I Need To...

| I need to... | Load this skill | Then this |
|--------------|----------------|-----------|
| Write a .ch course file | `course_writing` | `implementation_gaps` |
| Generate a full concept | `course_generation` | `course_writing` |
| Review someone's content | `review_quality` | `course_writing` |
| Verify a technical claim | `technical_research` | — |
| Fix Chemical syntax errors | `implementation_gaps` | `course_writing` |
| Design how a concept is taught | `learning_design` | `course_generation` |
| Structure a course | `course_architecture` | `course_generation` |
| Build an interactive exercise | `micro_interactions` | `course_writing` |
| Set up deployment | `deployment` | `engineering_patterns` |
| Understand the system | `product_architecture` | — |
| Add/modify an API route | `api_reference` | `web_development` |
| Query or extend the DB | `api_reference` | `coding_conventions` |
| Write a platform test | `testing` | `coding_conventions` |
| Check feature priority | `features_checklist` | — |

## Available Skills

| Skill | File | Description |
|-------|------|-------------|
| **Product Architecture** | `product_architecture/SKILL.md` | System design, module structure, data flow, technology decisions |
| **API Reference** | `api_reference/SKILL.md` | Every HTTP route, DB table, repository function, and handler file — generated from the actual code |
| **Learning Design** | `learning_design/SKILL.md` | How concepts are taught, FSRS, retrieval practice, interleaving, anxiety-friendly design |
| **Course Architecture** | `course_architecture/SKILL.md` | Course file structure, concept dependencies, lesson format, exercise types |
| **User Flows** | `user_flows/SKILL.md` | Every screen, action, and data flow — onboarding, course browsing, learning sessions, review, dashboard, adaptation |
| **Implementation Gaps** | `implementation_gaps/SKILL.md` | Known bugs, language limitations, component issues, missing infrastructure, verification patterns |
| **Technical Research** | `technical_research/SKILL.md` | How to research authoritative sources, verify claims, handle specifications |
| **Course Generation** | `course_generation/SKILL.md` | How AI generates course content, the iterative cycle, quality gates |
| **Review Quality** | `review_quality/SKILL.md` | How to review and verify generated content, adversarial review, consistency checks |
| **Deployment** | `deployment/SKILL.md` | Auto-deployment pipeline, Android app, course distribution, CI/CD |
| **Micro-Interactions** | `micro_interactions/SKILL.md` | 35 tiny UI features: info buttons, keyboard shortcuts, toasts, bookmarks, notes, dark mode, skeleton loading, celebrations |
| **Engineering Patterns** | `engineering_patterns/SKILL.md` | Error handling, logging, config, security, caching, testing, monitoring, privacy — the "boring but critical" stuff |
| **Course Writing** | `course_writing/SKILL.md` | Practical guide for AI agents writing .ch course files: patterns, mistakes, Chemical syntax, exercises |
| **Libraries Reference** | `libs_reference/SKILL.md` | Complete catalog of available libraries: std, page, server, http, json, fs, encoding, components, sqlite3, Turso |
| **Coding Conventions** | `coding_conventions/SKILL.md` | Style rules, naming conventions, and patterns extracted from the actual codebase |
| **Testing** | `testing/SKILL.md` | Test infrastructure: `@test` + TestEnv, `serve_async` HTTP test pattern, test scripts, port allocation |

## Which Skill to Load

### AI Course Development (Core Workflow)

| Task | Load | Why |
|------|------|-----|
| Generate a new course from scratch | `course_generation` | 11-phase iterative cycle |
| Generate a single concept | `course_generation` + `course_writing` | Process + code patterns |
| Write a .ch course file | `course_writing` | Chemical syntax, patterns, exercises |
| Verify technical claims | `technical_research` | Source hierarchy, verification |
| Review generated content | `review_quality` | 5 review types, severity levels |
| Design pedagogical approach | `learning_design` | FSRS, retrieval, interleaving |
| Structure course content | `course_architecture` | File format, dependencies |
| Fix Chemical syntax errors | `implementation_gaps` | Known bugs, workarounds |

### Platform Development

| Task | Load | Why |
|------|------|-----|
| Understanding the overall system | `product_architecture` | System design, module structure |
| Finding an existing route or table | `api_reference` | Routes, schema, repository functions — from real code |
| Adding a route or endpoint | `api_reference` + `web_development` | Route patterns + handler/page patterns |
| Designing screens or user interactions | `user_flows` | Every screen, action, data flow |
| Implementing onboarding or dashboard | `user_flows` | Screen-by-screen flow |
| Adding tooltips, toasts, or micro-animations | `micro_interactions` | 35 tiny UI features |
| Designing keyboard shortcuts | `micro_interactions` | Shortcut patterns |
| Building empty states or loading skeletons | `micro_interactions` | Skeleton patterns |
| Error handling, logging, or security | `engineering_patterns` | Blind spots checklist |
| Database migrations or caching | `engineering_patterns` + `api_reference` | Schema rules + current tables |
| Testing strategy or monitoring | `testing` | `@test` pattern, test scripts |
| Server config or library APIs | `libs_reference` | Server, SQLite3, Turso APIs |

### Chemical Language

| Task | Load | Why |
|------|------|-----|
| Writing Chemical code | `course_writing` | Syntax patterns, pitfalls |
| Finding available APIs | `libs_reference` | Complete library catalog |
| Writing with correct style | `coding_conventions` | Naming, patterns |

## Additional Documentation

| Document | File | Description |
|---|---|---|
| **Implementation Details** | `docs/implementation-details.md` | Concrete code patterns: chemical.mod, module wiring, database, FSRS, web routes, course .ch files, universal components |
| **User Flows** | `docs/user-flows.md` | Every screen, action, and data flow: onboarding, course browsing, learning sessions, review, dashboard, adaptation, settings |
| **Reusable Components** | `docs/reusable-components.md` | Guide to building and using universal components: Button, Card, Input, Badge, Typography, course-specific components, theme |
| **Course Development Handbook** | `docs/course-development-handbook.md` | Step-by-step guide for AI to develop courses (7 phases) |
| **UI/UX Design System** | `docs/ui-ux-design.md` | Colors, typography, spacing, components, interactions, accessibility |
| **Micro-Interactions** | `docs/micro-interactions.md` | 35 tiny UI features with CSS/JS patterns: info buttons, shortcuts, toasts, bookmarks, notes, skeletons, celebrations |
| **Implementation Patterns** | `docs/implementation-patterns.md` | Blind spots checklist: error handling, logging, security, caching, testing, monitoring, privacy, offline sync, performance |
| **AI Course Writing Guide** | `docs/ai-course-writing-guide.md` | Practical patterns for AI course writers: 10 mistakes, 10 patterns, Chemical syntax, verification checklist |
| **AI Course Writing Examples** | `docs/ai-course-writing-examples.md` | Concrete good vs bad examples: explanations, exercises, Chemical .ch files, hex dumps |
| **Libraries Reference** | `docs/libs-reference.md` | Complete catalog of available libraries with APIs, types, and usage patterns |
| **AI Course-Writing Constraints** | `docs/ai-course-writing-constraints.md` | 8 constraint methods: RAG, SCoT, CoVe, rubrics, self-consistency, confidence gating, adversarial, human gate |
| **Teaching Components Catalog** | `docs/teaching-components-catalog.md` | Complete catalog of all teaching primitives (40+ components across 6 families) |
| **Rendering Pipeline** | `docs/rendering-pipeline.md` | How .ch files become interactive HTML (pre-rendered pipeline) |
| **Developable Components** | `docs/developable-components.md` | What AI can generate vs what requires human engineering |
| **Conceptual Model** | `docs/conceptual-model.md` | Data model for courses, concepts, learner state, knowledge graphs, component system |
| **Feature Specs** | `docs/features.md` | 10 core features + 6 advanced features |
| **Competitor Analysis** | `docs/competitors.md` | Brilliant, Exercism, CodeCrafters, roadmap.sh, nand2tetris, OST2, Coursera |
| **Course Design** | `docs/course-design.md` | 8-unit lesson structure, 5 exposures, anxiety/depression design |
| **Deployment** | `docs/deployment.md` | Auto-deploy pipeline, Android app, course distribution |
| **Implementation Plan** | `docs/plan.md` | 6-phase roadmap, available libraries, database strategy, course format |
| **Learner Profiling** | `docs/learner-profiling.md` | IRT diagnostic, behavioral profiling, CLSI, adaptation rules |
| **Adaptive Flow & UI** | `docs/adaptive-flow-ui.md` | Screen-by-screen flow, knowledge display, progressive disclosure, anxiety/depression/overthinking design |
| **Correctness Verification** | `docs/correctness-verification.md` | 5-layer verification: source grounding, automated CI, conformance testing, human review, community |

## Project Stats

- **Status:** Working platform — server builds, runs, and serves the ELF course; 372/1883 checklist items done (all P0 + P1 complete; 9 P2 remain)
- **Language:** Chemical
- **First course:** ELF — Executable and Linkable Format (24 concepts, 8 modules)
- **Target platforms:** Web + Android (offline)
- **Database:** Dual-backend SQLite (local) + Turso HTTP (remote); ~35 tables
- **Course format:** Chemical source files with #html/#css/#js macros → pre-rendered HTML/CSS/JS
- **Core features implemented:** FSRS v4, 10 review modes, exercise engine, weakness detection, knowledge health, mistake patterns, session management, goals, search, navigation, progress export/import/share, auth (bearer + hashed passwords), profiles, settings, onboarding, enrollments, learning paths, notifications, bookmarks, notes, achievements, streaks, certificates, study plans, course reviews, feedback/moderation, 12+ analytics endpoints
- **Total documents:** 28 docs + 20 skills + 1 AGENTS.md + 1 README
- **AI course development:** 4 core skills (course_generation, course_writing, review_quality, technical_research) + 5 supporting docs

## Keeping Skills Accurate

Skills were last reconciled against the code on **2026-09-17**. When you change module structure, routes, schema, or build commands, update the relevant skill in the same commit:

| Changed... | Update... |
|---|---|
| Route added/removed | `api_reference/SKILL.md` |
| Module/file layout | `product_architecture/SKILL.md` |
| DB table or repository function | `api_reference/SKILL.md` |
| Build/run/test commands | `features_checklist/SKILL.md`, `testing/SKILL.md` |
| New convention discovered | `coding_conventions/SKILL.md` |
