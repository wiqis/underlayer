# Rendering Pipeline

## Purpose

How `.ch` course files become interactive HTML pages. The complete pipeline from authoring to display.

## The Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  STAGE 1: AUTHORING                                          │
│  Chemical .ch files with annotations                         │
│  + manifest.json (metadata, dependencies, sequence)          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 2: PARSING                                            │
│  .ch file → CourseAST (typed nodes)                          │
│  Validate: syntax, required fields, component types          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 3: TRANSFORM (Offline, Cacheable)                     │
│  CourseAST → RenderedCourse                                  │
│  Resolve: component references, embeds, templates            │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 4: TRANSFORM (Per-Request, Personalized)              │
│  RenderedCourse → PersonalizedLesson                         │
│  Apply: learner state, adaptive path, energy check           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 5: RENDER                                             │
│  PersonalizedLesson → HTML + CSS + JS                        │
│  Generate: component HTML, interactive JS, state management  │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 6: INTERACT                                           │
│  Browser executes JS, handles events, tracks progress        │
│  Generate: xAPI statements, learner state updates            │
└─────────────────────────────────────────────────────────────┘
```

## Stage 1: Authoring

### Course File Structure

```
courses/elf/
├── chemical.mod              # Module declaration
├── manifest.json             # Course metadata + sequence
├── concepts/                 # Individual concepts
│   ├── bytes.ch
│   ├── binary-representation.ch
│   └── elf-header.ch
├── exercises/                # Practice exercises
│   ├── identify-fields.ch
│   └── parse-hex.ch
├── visualizations/           # Interactive diagrams
│   ├── file-layout.ch
│   └── memory-mapping.ch
├── assets/                   # Static files
│   ├── samples/             # Real ELF files
│   └── images/
└── review/                   # Review items
    └── spaced-repetition.ch
```

### Concept File Format (.ch)

```chemical
@concept
@difficulty 2
@prerequisites ["bytes", "binary"]
@authority "gABI v1.0, Section 4"
public struct ELFHeader {
    // Component definitions inline
    @component("heading")
    var title = "The ELF Header"

    @component("paragraph")
    var intro = """
        Every ELF file starts with a header that describes
        the file's structure and contents.
    """

    @component("hex-dump")
    var identification = HexDump {
        data: [0x7f, 0x45, 0x4c, 0x46, ...],
        highlights: [
            { offset: 0, length: 4, label: "Magic", color: "blue" },
            { offset: 4, length: 1, label: "Class", color: "green" }
        ]
    }

    @component("definition")
    var def_ei_class = Definition {
        term: "EI_CLASS",
        definition: "File class. Identifies the word size...",
        source: "gABI v1.0, Section 4.1.1"
    }

    @component("quiz")
    var quiz_magic = Quiz {
        question: "What are the first 4 bytes of an ELF file?",
        options: [
            { text: "0x7f ELF", correct: true },
            { text: "MZ\\x90\\x00", correct: false },
            { text: "CAFEBABE", correct: false }
        ]
    }

    @component("code-block")
    var code_example = CodeBlock {
        language: "c",
        code: """
            struct Elf64_Ehdr {
                unsigned char e_ident[EI_NIDENT];
                uint16_t      e_type;
                uint16_t      e_machine;
                ...
            };
        """,
        title: "ELF Header Structure",
        highlights: [1, 2, 3]
    }
}
```

### manifest.json

```json
{
    "id": "elf",
    "name": "ELF: Executable and Linkable Format",
    "version": "1.0.0",
    "description": "Deep understanding of Linux binary format",
    "modules": [
        {
            "id": "fundamentals",
            "name": "Fundamentals",
            "concepts": ["bytes", "binary", "file-layout"],
            "prerequisites": []
        },
        {
            "id": "headers",
            "name": "ELF Headers",
            "concepts": ["elf-header", "program-headers", "sections"],
            "prerequisites": ["fundamentals"]
        }
    ],
    "reviewPolicy": {
        "targetRetention": 0.85,
        "maxNewPerDay": 5,
        "maxReviewsPerDay": 20
    }
}
```

## Stage 2: Parsing

### Input
- `.ch` concept files
- `manifest.json`

### Output
- `CourseAST` — typed tree of all content and components

### Process

```
1. Parse manifest.json → ModuleSequence[]
2. For each concept file:
   a. Lex .ch file → Token[]
   b. Parse tokens → CourseAST node
   c. Validate: required fields, component types, prerequisites
3. Build dependency graph from prerequisites
4. Validate: no cycles, all prerequisites exist
```

### Validation Rules

| Rule | Error |
|---|---|
| Concept must have `@concept` annotation | "Missing @concept annotation" |
| Prerequisites must exist | "Prerequisite 'X' not found" |
| No circular prerequisites | "Circular dependency detected" |
| Components must have required fields | "Component X missing field Y" |
| Authority must cite a source | "No authority specified" |

## Stage 3: Transform (Offline)

### Input
- `CourseAST`

### Output
- `RenderedCourse` — resolved, ready for per-request personalization

### Process

```
1. Resolve component references
   - Inline components stay as-is
   - External components (images, samples) get URLs

2. Embed assets
   - Images → base64 or CDN URLs
   - Sample files → download URLs
   - Code → syntax-highlighted HTML

3. Build component tree
   - Flat list of components → nested tree
   - Headings create sections
   - Components group into logical units

4. Pre-compute
   - Quiz answers (hashed for verification)
   - Code execution outputs (cached)
   - Visualization initial states

5. Cache
   - Store RenderedCourse in Redis/memory
   - Invalidate on course version change
```

## Stage 4: Transform (Per-Request)

### Input
- `RenderedCourse`
- `LearnerState` (from database)

### Output
- `PersonalizedLesson` — adapted to learner

### Process

```
1. Load learner state
   - Concept mastery (θ, stability, retrievability)
   - Session history (time spent, accuracy)
   - Emotional signals (energy level, fatigue)

2. Apply adaptive path
   - Skip mastered concepts
   - Slow down for struggling concepts
   - Insert review items for forgetting concepts

3. Personalize components
   - Show/hide based on mastery
   - Adjust difficulty based on θ
   - Add/remove hints based on history

4. Build session
   - Welcome back message (no streak shaming)
   - Energy check result → session type
   - Component sequence for this session
```

## Stage 5: Render

### Input
- `PersonalizedLesson`

### Output
- HTML + CSS + JS

### Process

```
1. Map components to HTML
   - Each component type → HTML template
   - Components → <div class="component component-{type}">

2. Generate CSS
   - Base styles (from design system)
   - Component-specific styles
   - Dark mode variants
   - Responsive breakpoints

3. Generate JS
   - Component initialization
   - Event handlers
   - State management
   - xAPI statement generation

4. Assemble page
   - Header (course info, progress)
   - Content (components)
   - Footer (navigation, session controls)

5. Inject state
   - Learner state → JS object
   - Component states → JS object
   - Session config → JS object
```

### HTML Template

```html
<div class="lesson" data-concept-id="{id}">
    <header class="lesson-header">
        <h1>{title}</h1>
        <div class="progress">{progress}%</div>
    </header>

    <div class="lesson-content">
        {#each component}
        <div class="component component-{type}" data-component-id="{id}">
            {rendered HTML}
        </div>
        {/each}
    </div>

    <footer class="lesson-footer">
        <button class="done-today">Done for Today</button>
        <button class="continue">Continue</button>
    </footer>
</div>

<script>
    window.__underlayer = {
        learnerState: {state},
        componentStates: {states},
        sessionConfig: {config}
    };
</script>
```

## Stage 6: Interact

### Browser Execution

```
1. Initialize components
   - Each component type → JS class
   - Component class binds to DOM element
   - Component loads its own state

2. Handle events
   - User clicks → component method
   - Component validates → feedback
   - Component generates xAPI statement

3. Track progress
   - Component completion → update learner state
   - Session completion → update session history
   - xAPI statement → send to LRS

4. Adaptive updates
   - After each interaction → update θ
   - After session → update stability
   - Before next session → compute retrievability
```

## Component Rendering Map

| Component Type | HTML Element | JS Class | Event |
|---|---|---|---|
| `Paragraph` | `<div class="paragraph">` | None (static) | None |
| `CodeBlock` | `<pre><code>` | PrismJS (highlight) | None |
| `HexDump` | `<div class="hex-viewer">` | HexViewer | click, hover |
| `Quiz` | `<div class="quiz">` | QuizComponent | select, submit |
| `FillInBlank` | `<div class="fill-blank">` | FillBlankComponent | input, check |
| `CodeEditor` | `<div class="code-editor">` | CodeMirror | input, run |
| `MemoryLayout` | `<div class="memory-diagram">` | MemoryDiagram | click, hover |
| `Flowchart` | `<svg class="flowchart">` | FlowchartSVG | click, zoom |
| `Simulation` | `<canvas>` or `<div>` | SimulationEngine | input, step |

## Caching Strategy

| Layer | What | Duration | Invalidation |
|---|---|---|---|
| CDN | Static assets (images, CSS, JS) | 1 year | Version hash |
| Redis | RenderedCourse | 1 hour | Course version change |
| Memory | PersonalizedLesson | 5 min | Learner state change |
| Database | LearnerState | Permanent | Every interaction |

## Performance Requirements

| Metric | Target |
|---|---|
| Time to First Byte | < 100ms |
| Time to Interactive | < 500ms |
| Component Render | < 50ms each |
| Total Page Render | < 200ms |
| xAPI Statement | < 100ms to send |
