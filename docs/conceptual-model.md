# Conceptual Model

This document defines the core data concepts for Underlayer. Everything in the system is built from these primitives.

## Overview

```
Course
  └── Module (logical grouping)
        └── Concept (a single idea to understand)
              ├── Lesson (explanation + examples)
              ├── Exercises (active use)
              ├── Visualizations (interactive representations)
              └── Review Items (spaced repetition cards)
                    └── Learner State (per-concept mastery tracking)
```

## Course

A self-contained, portable learning artifact about one subject.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier (e.g., `elf`) |
| `title` | string | Human-readable name |
| `version` | int | Monotonically increasing, incremented on any content change |
| `prerequisites` | string[] | IDs of courses that should be completed first |
| `concepts` | Concept[] | All concepts in this course |
| `manifest` | Manifest | Metadata, dependencies, assets |

A course is a directory. It can be zipped, downloaded, distributed independently of the platform.

## Module

A logical grouping of related concepts. Not a learning unit itself — it organizes concepts.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within course |
| `title` | string | Human-readable name |
| `concepts` | string[] | Concept IDs in this module |
| `order` | int | Display order |

Example for ELF course:
- Module: "File Layout" → Concepts: bytes, binary representation, file structure
- Module: "Headers" → Concepts: ELF header, program headers, section header
- Module: "Linking" → Concepts: symbols, relocations, dynamic linking

## Concept

The atomic unit of knowledge. A concept is a single idea that a learner must understand.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within course |
| `module_id` | string | Parent module |
| `title` | string | Human-readable name |
| `description` | string | One-sentence summary |
| `prerequisites` | string[] | Concept IDs that must be learned first |
| `lesson` | Lesson | The teaching content |
| `exercises` | Exercise[] | Active practice items |
| `visualizations` | Visualization[] | Interactive representations |
| `importance` | enum | `core`, `important`, `supplementary` |
| `estimated_minutes` | int | Expected time to learn |

## Lesson

The explanation of a concept. NOT a wall of text — structured as a sequence of learning units.

| Field | Type | Description |
|---|---|---|
| `units` | LearningUnit[] | Sequence of teaching moments |
| `sources` | Source[] | Authoritative references for this concept |

### Learning Unit

A single teaching moment within a lesson.

| Field | Type | Description |
|---|---|---|
| `type` | enum | `explain`, `example`, `show`, `ask`, `do`, `visualize` |
| `content` | string | The teaching content |
| `purpose` | string | Why this unit exists (for AI review) |

Learning unit types:
- `explain` — Introduce or clarify a concept
- `example` — Show a concrete instance (hex dump, code, diagram)
- `show` — Present a visualization or artifact
- `ask` — A retrieval question (no answer shown yet — the learner must recall)
- `do` — An exercise embedded in the lesson
- `visualize` — Launch an interactive visualization

### Source

An authoritative reference.

| Field | Type | Description |
|---|---|---|
| `type` | enum | `specification`, `rfc`, `book`, `paper`, `code`, `documentation` |
| `title` | string | Name of the source |
| `url` | string | Link to the source |
| `section` | string | Specific section or page |
| `version` | string | Version or edition |
| `accessed` | date | When this was last verified |

## Exercise

An active practice item. Every exercise must have a verifiable correct answer.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within concept |
| `type` | enum | See exercise types below |
| `difficulty` | enum | `easy`, `medium`, `hard` |
| `question` | string | The prompt |
| `options` | Option[] | For multiple-choice types |
| `answer` | string | Correct answer or validation criteria |
| `explanation` | string | Why this is the correct answer |
| `misconception` | string | What wrong answer this targets |
| `time_limit_seconds` | int | Optional time pressure |

### Exercise Types

| Type | Description | Example |
|---|---|---|
| `multiple_choice` | Select one correct answer | "Which field contains the entry point?" |
| `multiple_answer` | Select all that apply | "Which of these are program header types?" |
| `fill_blank` | Complete a statement | "The ELF magic bytes are ____" |
| `hex_inspect` | Read bytes from a hex dump | "Find e_entry in this hex dump" |
| `ordering` | Put items in correct order | "Order these ELF structures by file offset" |
| `matching` | Connect related items | "Match each section to its purpose" |
| `labeling` | Label parts of a diagram | "Label the ELF header fields" |
| `predict` | Predict system behavior | "What happens if e_phoff is invalid?" |
| `debug` | Find and fix an error | "This parser reads the wrong offset. Find the bug." |
| `classify` | Categorize an item | "Is this a segment or a section?" |
| `construct` | Build something | "Write a function that reads the ELF header" |
| `explain` | Explain a concept in your own words | "Explain why program headers exist" |

## Visualization

An interactive representation of a concept.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within concept |
| `type` | enum | `diagram`, `hex_viewer`, `state_machine`, `timeline`, `tree` |
| `interactive` | bool | Whether the learner can manipulate it |
| `description` | string | What the visualization shows |
| `data_source` | string | Where the visualization data comes from |

Visualization types:
- `diagram` — Clickable structural diagram (ELF layout, memory map)
- `hex_viewer` — Byte-level inspection with highlighting
- `state_machine` — Clickable state transitions (TLS handshake, linker states)
- `timeline` — Temporal sequence (loading process, compilation pipeline)
- `tree` — Hierarchical structure (symbol table tree, include dependencies)

## Review Item

A spaced repetition card derived from a concept. Not manually created — generated from concept content.

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique within course |
| `concept_id` | string | Source concept |
| `type` | enum | `recall`, `recognize`, `apply`, `explain` |
| `front` | string | The question or prompt |
| `back` | string | The answer |
| `difficulty` | float | FSRS difficulty parameter (1-10) |
| `stability` | float | FSRS stability parameter (days) |
| `retrievability` | float | Current recall probability (0-1) |
| `next_review` | date | When this item is due |

### Review Item Generation

Review items are generated from concepts using these patterns:

1. **Recall** — "What is X?" (requires free recall, not recognition)
2. **Recognize** — "Which of these is X?" (multiple choice)
3. **Apply** — "Given this hex dump, find X" (use the knowledge)
4. **Explain** — "Explain why X exists" (deep understanding)

Each concept generates 3-8 review items. The AI generates initial items; human review refines them.

## Learner State

Per-learner data tracking what they know and what they need to review.

| Field | Type | Description |
|---|---|---|
| `learner_id` | string | Unique learner identifier |
| `course_id` | string | Which course |
| `concept_states` | Map<string, ConceptState> | Per-concept mastery |
| `review_queue` | ReviewItem[] | Items due for review |
| `session_history` | Session[] | Past learning sessions |
| `energy_profile` | EnergyProfile | Pacing and energy tracking |

### ConceptState

| Field | Type | Description |
|---|---|---|
| `concept_id` | string | Which concept |
| `status` | enum | `not_started`, `learning`, `reviewing`, `mastered` |
| `attempts` | int | Total attempts on exercises |
| `correct` | int | Correct answers |
| `streak` | int | Consecutive correct answers |
| `last_studied` | date | When last practiced |
| `next_review` | date | When due for spaced review |
| `difficulty_rating` | float | Learner's self-reported difficulty (1-5) |

### EnergyProfile

Tracks the learner's energy and pacing to prevent burnout.

| Field | Type | Description |
|---|---|---|
| `preferred_session_minutes` | int | How long the learner wants to study |
| `actual_session_minutes` | int | How long they actually studied |
| `fatigue_signal` | enum | `none`, `mild`, `strong` |
| `anxiety_level` | enum | `none`, `low`, `medium`, `high` |
| `last_session_date` | date | When they last studied |
| `streak_days` | int | Consecutive days studied |
| `rest_days` | int | Days since last rest |

### Session

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique session ID |
| `start_time` | datetime | When session began |
| `end_time` | datetime | When session ended |
| `type` | enum | `learn`, `review`, `mixed` |
| `concepts_hit` | string[] | Concepts encountered |
| `exercises_attempted` | int | Total exercises |
| `exercises_correct` | int | Correct exercises |
| `energy_before` | enum | Self-reported energy at start |
| `energy_after` | enum | Self-reported energy at end |

## Knowledge Graph

The concept dependency graph. Not a separate entity — derived from concept prerequisites.

```
Bytes
  ↓
Binary Representation
  ↓
File Layout
  ↓
ELF Header
  ↓
Program Headers ──→ Segments
  ↓
Sections ──→ Section Types
  ↓
Symbols ──→ Symbol Binding
  ↓
Relocations ──→ Relocation Types
  ↓
Dynamic Linking ──→ Dynamic Section
  ↓
Loading ──→ Memory Mapping
```

The knowledge graph enables:
- **Prerequisite checking** — don't teach relocations before symbols
- **Weakness detection** — if a learner fails relocation exercises, check if symbols are solid
- **Review routing** — if a concept is weak, review its prerequisites first
- **Progress visualization** — show the learner their position in the graph

## Course Versioning

Courses are versioned. When content changes:

| Change Type | Version Bump | Example |
|---|---|---|
| Typo fix | Patch (1.0.x) | Fixed spelling of "endianness" |
| Content correction | Minor (1.x.0) | Fixed incorrect offset in hex example |
| New exercise | Minor (1.x.0) | Added debug exercise for program headers |
| New concept | Major (x.0.0) | Added DWARF debugging format module |
| Restructured prerequisites | Major (x.0.0) | Moved "symbols" before "sections" |

The platform tracks which version a learner completed. When a course updates, the learner sees what changed and what they need to re-learn.

## Portability

A course is a directory containing:
- `manifest.json` — metadata, version, concept list
- `concepts/` — lesson content as Chemical source files
- `exercises/` — exercise definitions
- `visualizations/` — visualization components
- `assets/` — images, sample files, hex dumps
- `reviews/` — generated review items

This directory can be:
- Downloaded to an Android device
- Shared between learners
- Hosted on any server
- Version-controlled with git
- Distributed as a zip file

The platform reads this directory. The course does not depend on the platform.

## Component System

Lessons are built from reusable, self-contained components. Each component is a teaching primitive that can be composed into any lesson.

### Component Types

Six families of components:

| Family | Purpose | Examples |
|---|---|---|
| **Content** | Information delivery | Paragraph, Definition, Callout, Table, Image |
| **Code** | Technical content | CodeBlock, HexDump, MemoryLayout, Terminal |
| **Interactive** | Learner engagement | Quiz, FillInBlank, DragDrop, Ordering, Slider |
| **Assessment** | Evaluation | MultipleChoice, DebuggingExercise, CodeChallenge |
| **Reference** | Lookup | Glossary, CheatSheet, APIReference, SpecReference |
| **Visualization** | Visual learning | Flowchart, MemoryDiagram, AnimatedDemo |

### Component Properties

Every component has:

| Property | Type | Purpose |
|---|---|---|
| `id` | string | Unique identifier |
| `type` | string | Component type name |
| `difficulty` | 1-5 | Cognitive load level |
| `timeEstimate` | number | Seconds to complete |
| `prerequisites` | string[] | Required knowledge |
| `learningObjective` | string | What this teaches |
| `verificationStatus` | enum | verified/unverified/disputed |
| `source` | string? | Authoritative reference |

### Component Composition

Components compose into lessons:

```
Lesson
├── Paragraph (intro)
├── Definition (term)
├── CodeBlock (example)
├── HexDump (visual)
├── Quiz (check)
├── KeyTakeaway (summary)
└── FillInBlank (practice)
```

Components don't reference each other — they're self-contained. This makes them reusable across courses.

### AI-Developable Components

Components AI can generate given context:

| Component | AI Needs | Human Must Verify |
|---|---|---|
| `CodeBlock` | Language, code | Code works |
| `Quiz` | Question, answer | Options plausible |
| `HexDump` | Binary data | Byte offsets correct |
| `Flowchart` | Process steps | Logic matches spec |
| `Glossary` | Terms, definitions | Definitions accurate |

Components requiring human engineering:

| Component | Why |
|---|---|
| `CodeEditor` | Complex state, syntax highlighting |
| `CodeExecution` | Sandboxed execution |
| `Simulation` | Physics/logic engine |
| `InteractiveDemo` | Custom interaction logic |

See `docs/teaching-components-catalog.md` for the complete component catalog.

## Rendering Pipeline

How `.ch` concept files become interactive HTML pages.

### Pipeline Stages

```
Authoring → Parsing → Transform (Offline) → Transform (Per-Request) → Render → Interact
```

1. **Authoring** — Write `.ch` files with component annotations
2. **Parsing** — `.ch` → CourseAST (typed nodes)
3. **Transform (Offline)** — CourseAST → RenderedCourse (cached)
4. **Transform (Per-Request)** — RenderedCourse → PersonalizedLesson (adapted to learner)
5. **Render** — PersonalizedLesson → HTML + CSS + JS
6. **Interact** — Browser executes JS, tracks progress

### Content Format

Chemical `.ch` files with annotations:

```chemical
@concept
@difficulty 2
@prerequisites ["bytes"]
@source "gABI v1.0, Section 4"
public struct ELFHeader {
    @component("paragraph")
    var intro = "Every ELF file starts with a header..."

    @component("hex-dump")
    var identification = HexDump { ... }

    @component("quiz")
    var quiz = Quiz { ... }
}
```

### Caching Strategy

| Layer | What | Duration |
|---|---|---|
| CDN | Static assets | 1 year |
| Redis | RenderedCourse | 1 hour |
| Memory | PersonalizedLesson | 5 min |
| Database | LearnerState | Permanent |

See `docs/rendering-pipeline.md` for the complete pipeline specification.
