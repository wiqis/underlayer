# Underlayer — Skills Index

Comprehensive documentation for the `lang/compiled/underlayer` project. Load the relevant skill before working on a particular area.

## Available Skills

| Skill | File | Description |
|-------|------|-------------|
| **Product Architecture** | `product_architecture/SKILL.md` | System design, module structure, data flow, technology decisions |
| **Learning Design** | `learning_design/SKILL.md` | How concepts are taught, FSRS, retrieval practice, interleaving, anxiety-friendly design |
| **Course Architecture** | `course_architecture/SKILL.md` | Course file structure, concept dependencies, lesson format, exercise types |
| **Implementation Gaps** | `implementation_gaps/SKILL.md` | Known bugs, language limitations, component issues, missing infrastructure, verification patterns |
| **Technical Research** | `technical_research/SKILL.md` | How to research authoritative sources, verify claims, handle specifications |
| **Course Generation** | `course_generation/SKILL.md` | How AI generates course content, the iterative cycle, quality gates |
| **Review Quality** | `review_quality/SKILL.md` | How to review and verify generated content, adversarial review, consistency checks |
| **Deployment** | `deployment/SKILL.md` | Auto-deployment pipeline, Android app, course distribution, CI/CD |

## Which Skill to Load

| Task | Load |
|------|------|
| Understanding the overall system | `product_architecture` |
| Designing how a concept is taught | `learning_design` |
| Structuring course content | `course_architecture` |
| Researching a technical topic | `technical_research` |
| Generating course content with AI | `course_generation` |
| Reviewing generated content | `review_quality` |
| Setting up deployment | `deployment` |
| Building or using reusable components | `docs/reusable-components.md` |
| Writing code or generating course content | `implementation_gaps` |
| Debugging universal component issues | `implementation_gaps` |
| Verifying ELF/binary content | `implementation_gaps` |
| Fixing a bug in the platform | `product_architecture`, relevant module skill |
| Adding a new exercise type | `learning_design`, `course_architecture` |
| Verifying a technical claim | `technical_research`, `review_quality` |

## Additional Documentation

| Document | File | Description |
|---|---|---|
| **Implementation Details** | `docs/implementation-details.md` | Concrete code patterns: chemical.mod, module wiring, database, FSRS, web routes, course .ch files, universal components |
| **Reusable Components** | `docs/reusable-components.md` | Guide to building and using universal components: Button, Card, Input, Badge, Typography, course-specific components, theme |
| **Course Development Handbook** | `docs/course-development-handbook.md` | Step-by-step guide for AI to develop courses (7 phases) |
| **UI/UX Design System** | `docs/ui-ux-design.md` | Colors, typography, spacing, components, interactions, accessibility |
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

- **Status:** Planning (no code yet)
- **Language:** Chemical
- **First course:** ELF — Executable and Linkable Format
- **Target platforms:** Web + Android (offline)
- **Database:** Dual-backend SQLite (local) + Turso HTTP (remote)
- **Course format:** Chemical source files with #html/#css/#js/#md macros → pre-rendered HTML/CSS/JS
- **Core features:** Spaced repetition (FSRS), interleaved practice, retrieval-first design, anxiety-friendly pacing
- **Total documents:** 17 docs + 7 skills + 1 AGENTS.md + 1 README
