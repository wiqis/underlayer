# AGENTS.md — Underlayer

Read this before touching any code or content. Also load the relevant skill from `.agents/skills/`.

## Golden Rules

1. **Learning is the product.** Every decision must answer: "Does this help someone understand something deeply?"
2. **Courses are permanent artifacts.** They are generated once, then improved for years. Never treat content as disposable.
3. **Verify everything.** AI-generated content is presumed incorrect until verified against authoritative sources (specs, RFCs, source code).
4. **No feature exists because other platforms have it.** Every feature must justify itself against Underlayer's educational purpose.
5. **Depth over volume.** One excellent course beats 100 mediocre ones.
6. **The platform serves the course.** If there's a choice between improving a course and adding a platform feature, the course wins.

## AI Constraint System

Every AI agent working on Underlayer must follow these constraints:

### Content Generation Constraints

1. **Never generate a course in one pass.** Follow the iterative cycle: Research → Generate → Verify → Test → Critique → Improve → Re-verify → Repeat.
2. **Never claim a source says something without consulting it.** No hallucinated citations.
3. **Always distinguish** specification facts, conceptual models, implementation details, and simplifications.
4. **Every technical example must be verifiable.** No invented byte sequences, offsets, or data.
5. **Every exercise must be checked** for correctness, ambiguity, solvability, and consistency.
6. **Identify likely misconceptions** for every important concept and address them proactively.
7. **Teach relationships, not isolated facts.** Every concept must connect to: why it exists, who produces/consumes it, what depends on it, what happens if it's invalid.
8. **Progress from simple models toward reality.** Explicitly mark simplifications as models, then replace them with accurate models later.

### Design Constraints

1. **No passive reading as default.** Every concept must be followed by active use.
2. **No decorative interactivity.** Every interaction must answer: "What does this help the learner understand?"
3. **No meaningless badges, streaks, or leaderboards.** Gamification must serve learning.
4. **Normalize struggle.** Show "This is supposed to be hard" not "You're failing."
5. **Respect energy.** Allow pacing controls. Prevent overactivity-underactivity cycling.
6. **Assume the learner forgets.** Build retrieval into every session. Never punish forgetting.

### Technical Constraints

1. **Chemical language** for all implementation. This is how we find what's missing in Chemical.
2. **Universal components used carefully.** Known bugs exist — use with awareness.
3. **Multi-module architecture** with strict layering (see Architecture section).
4. **No SQL outside repository layer.** No raw HTML outside `#html` blocks.
5. **Auto-deploy on commit.** Code must be correct before merge — no "fix it later."

## Architecture

```
src/main.ch              (wiring only)
   ↓
web/                     (public pages, SSR)
   ↓
content/                 (course content, lesson rendering)
   ↓
learning/                (spaced repetition, retrieval, progress)
   ↓
repository/              (ALL data access lives here)
   ↓
models/                  (plain domain structs)
database/                (SQLite via Turso HTTP)
   ↓
core/                    (config, logging, string utils)
```

A layer may only call layers below it.

## Build / Run / Verify

```bash
# Build
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Run
./lang/compiled/underlayer/build/underlayer.exe

# Verify (smoke test)
curl localhost:9000/api/health
```

## Course File Structure

Each course is a self-contained directory:

```
courses/
  elf/
    chemical.mod
    manifest.json          (metadata, version, dependencies)
    concepts/
      elf-header.ch        (concept definition + lesson content)
      program-headers.ch
      sections.ch
      symbols.ch
      relocations.ch
      dynamic-linking.ch
    exercises/
      identify-elf-header.ch
      parse-hex-dump.ch
      diagnose-malformed.ch
    visualizations/
      file-layout.ch
      segment-mapping.ch
    assets/
      samples/             (real ELF files for exercises)
      images/
```

## Where to Add Things

| Task | Place |
|---|---|
| New course | `courses/<name>/` with `chemical.mod` + `manifest.json` |
| New concept | `courses/<name>/concepts/<concept>.ch` |
| New exercise type | `learning/src/exercise_types/` |
| New visualization | `courses/<name>/visualizations/` or `content/src/visualizations/` |
| New platform feature | Relevant module (`web/`, `learning/`, `repository/`) |
| Schema change | `repository/src/schema.ch` + matching model struct |

## Skills

Load the relevant skill before working on a particular area:

| Skill | Use When |
|---|---|
| `product_architecture` | Understanding the overall system design |
| `learning_design` | Designing how concepts are taught and tested |
| `course_architecture` | Structuring course content and progressions |
| `technical_research` | Researching authoritative sources for course topics |
| `course_generation` | Using AI to generate course content |
| `review_quality` | Reviewing and verifying generated content |
| `deployment` | Android app, auto-deployment, CI/CD |

## Key Documents

| Document | When to Read |
|---|---|
| `docs/course-development-handbook.md` | Before generating any course content — step-by-step 7-phase process |
| `docs/ai-course-writing-constraints.md` | Before any AI generation — 8 constraint methods, negative constraints |
| `docs/ui-ux-design.md` | Before building any UI — colors, typography, components, accessibility |
| `docs/conceptual-model.md` | Before designing data models — Course, Concept, Exercise, LearnerState |
| `docs/teaching-components-catalog.md` | Before building any component — complete catalog of teaching primitives |
| `docs/rendering-pipeline.md` | Before building content rendering — how .ch files become HTML |
| `docs/developable-components.md` | Before AI generates components — what's AI-generatable vs human-engineered |
| `docs/course-design.md` | Before designing lessons — 8-unit structure, 5 exposures, anxiety design |
| `docs/features.md` | Before implementing features — 10 core + 6 advanced feature specs |
| `docs/competitors.md` | Before making design decisions — what others do, what we do better |
| `docs/deployment.md` | Before setting up CI/CD — auto-deploy pipeline, Android app |
| `docs/plan.md` | Before starting work — 6-phase implementation roadmap |
| `docs/learner-profiling.md` | Before designing onboarding or adaptation — IRT, behavioral profiling, CLSI |
| `docs/adaptive-flow-ui.md` | Before designing UI flows — screen-by-screen, anxiety/depression design |
| `docs/correctness-verification.md` | Before verifying course content — 5-layer verification system |

## Gotchas

- **Universal components have known bugs.** Use carefully. Prefer simple HTML where possible.
- **Chemical is young.** Some features may not exist yet. Document gaps, work around them.
- **Courses must be portable.** No platform-specific dependencies inside course content.
- **AI generation is iterative.** Never accept first-pass content as final.
- **Retrieval is not optional.** Every session must include review of previously learned material.
