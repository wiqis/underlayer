# Underlayer — Learn Things Deeply

A learning platform for subjects that are difficult, deep, poorly taught, or require digging through specifications, source code, academic papers, and fragmented documentation.

## What This Is

Underlayer takes things that normally require enormous amounts of scattered research and turns them into structured, interactive, deeply understood knowledge.

Courses:

- **ELF — Executable and Linkable Format** — the technical deep dive the platform started with.
- **HAT — Higher Education Aptitude Test** — preparation for the HEC Higher Education Aptitude Test, written for HAT-1 candidates in engineering, computing and the physical sciences (5 modules, 21 concepts).

## Philosophy

- Courses are long-lived artifacts, improved continuously for years
- Optimizes for understanding and retention, not course completion
- Every interaction has pedagogical purpose
- Mistakes are learning opportunities, not failures
- Difficulty is evidence of learning, not a sign of incompetence

## Who This Is For

Learners who:
- Struggle with anxiety, depression, or overthinking
- Need repetition and slow, consistent pacing
- Want concepts hard-wired into their brains, not surface-level recognition
- Are tired of scattered blog posts, 400-page specs, and 12-hour video courses
- Want to actually understand how things work, not just pass a quiz

## Built With

[Chemical](https://github.com/chemical-lang/chemical) — a systems programming language.

## License

Free and open source. Courses are portable, self-contained artifacts.

## Status

Planning phase. No implementation yet.

## Documentation

### Core
- [`AGENTS.md`](AGENTS.md) — Rules for AI agents working on this project
- [`docs/conceptual-model.md`](docs/conceptual-model.md) — Data model for courses, concepts, learner state
- [`docs/plan.md`](docs/plan.md) — 6-phase implementation roadmap

### Course Development
- [`docs/course-development-handbook.md`](docs/course-development-handbook.md) — Step-by-step 7-phase guide for AI to develop courses
- [`docs/ai-course-writing-constraints.md`](docs/ai-course-writing-constraints.md) — 8 constraint methods for AI generation quality
- [`docs/course-design.md`](docs/course-design.md) — How courses are structured for deep learning
- [`docs/features.md`](docs/features.md) — 10 core features + 6 advanced features

### Teaching Components
- [`docs/teaching-components-catalog.md`](docs/teaching-components-catalog.md) — Complete catalog of all teaching primitives
- [`docs/rendering-pipeline.md`](docs/rendering-pipeline.md) — How .ch files become interactive HTML
- [`docs/developable-components.md`](docs/developable-components.md) — What AI can generate vs what requires engineering

### Design & Research
- [`docs/ui-ux-design.md`](docs/ui-ux-design.md) — Colors, typography, spacing, components, accessibility
- [`docs/competitors.md`](docs/competitors.md) — Brilliant, Exercism, CodeCrafters, roadmap.sh, nand2tetris, OST2, Coursera

### Learner Experience
- [`docs/learner-profiling.md`](docs/learner-profiling.md) — IRT diagnostic, behavioral profiling, adaptation rules
- [`docs/adaptive-flow-ui.md`](docs/adaptive-flow-ui.md) — Screen-by-screen flow, knowledge display, anxiety/depression design

### Technical
- [`docs/correctness-verification.md`](docs/correctness-verification.md) — 5-layer verification system against standards
- [`docs/deployment.md`](docs/deployment.md) — Android app and auto-deployment
- [`.agents/skills/`](.agents/skills/) — 10 AI skills for working on Underlayer
