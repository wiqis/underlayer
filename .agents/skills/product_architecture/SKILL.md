# Product Architecture Skill

Load this skill when understanding or modifying the overall Underlayer system design.

## System Overview

Underlayer is a learning platform for deep technical subjects. It consists of:
1. **Web platform** — course browsing, learner account, course management
2. **Android app** — offline-first course player with spaced repetition
3. **Course format** — self-contained, portable directories with Chemical source files that compile to pre-rendered HTML/CSS/JS

## Module Structure

```
underlayer/
├── chemical.mod              (project manifest)
├── src/main.ch               (wiring only — route registration, context building)
│
├── core/                     (config, env, logging, string+time utils)
│   └── src/
│       ├── config.ch         (read env vars: PORT, DATABASE_URL, DATABASE_TOKEN)
│       ├── logging.ch        (printf-based logging)
│       └── utils.ch          (string helpers, time formatting)
│
├── models/                   (plain domain structs — no business logic)
│   └── src/
│       ├── course.ch         (Course, Module, Manifest)
│       ├── concept.ch        (Concept, LearningUnit, Source)
│       ├── exercise.ch       (Exercise, Option, ExerciseType)
│       ├── learner.ch        (Learner, ConceptState, EnergyProfile)
│       └── review.ch         (ReviewItem, ReviewType)
│
├── database/                 (dual-backend: SQLite local + Turso HTTP remote)
│   └── src/
│       ├── client.ch         (DbClient — auto-selects SQLite or Turso based on URL)
│       ├── schema.ch         (CREATE TABLE statements)
│       └── migrations.ch     (schema versioning)
│
├── repository/               (ALL SQL lives here — schema + CRUD)
│   └── src/
│       ├── init.ch           (init_schema(), seed_demo_data())
│       ├── courses.ch        (course CRUD — reads manifest.json + concept files)
│       ├── learners.ch       (learner CRUD)
│       ├── reviews.ch        (review item CRUD)
│       └── sessions.ch       (session logging)
│
├── content/                  (course loading, lesson rendering)
│   └── src/
│       ├── CourseLoader.ch   (read manifest.json, load concept .ch files)
│       └── LessonRenderer.ch (render concept → HtmlPage → string)
│
├── learning/                 (FSRS engine, progress tracking, review scheduling)
│   └── src/
│       ├── fsrs.ch           (FSRS algorithm: difficulty, stability, retrievability)
│       ├── review.ch         (review session management, due items)
│       ├── progress.ch       (concept state tracking, knowledge health)
│       └── weakness.ch       (weakness detection, repair suggestions)
│
├── web/                      (public pages, API routes, static file serving)
│   └── src/
│       ├── main.ch           (route registration, server startup)
│       ├── health.ch         (GET /api/health)
│       ├── courses.ch        (GET /api/courses, GET /api/courses/:id)
│       ├── lessons.ch        (GET /api/courses/:id/lessons/:concept_id)
│       └── static.ch         (serve courses/*/output/ directories)
│
├── courses/                  (course content — self-contained directories)
│   └── elf/
│       ├── chemical.mod      (imports page, html_cbi, css_cbi, js_cbi)
│       ├── manifest.json     (metadata, version, module sequence)
│       ├── src/
│       │   ├── main.ch       (build entry — calls render functions, writes output/)
│       │   ├── bytes.ch      (concept page using #html + #css + #js)
│       │   └── ...
│       ├── output/           (generated — pre-rendered HTML/CSS/JS)
│       └── assets/           (sample ELF files, images)
│
└── .agents/skills/           (this documentation)
```

## Dependency Chain

```
src/main.ch
   ↓
web/                         (HTTP routes, static file serving)
   ↓
content/                     (course loading, lesson rendering)
   ↓
learning/                    (FSRS, progress, scheduling)
   ↓
repository/                  (ALL SQL lives here)
   ↓
models/                      (plain domain structs)
database/                    (dual-backend SQLite + Turso HTTP)
   ↓
core/                        (config, env, logging, utils)
```

**Rule:** A layer may only call layers below it. If you are tempted to run SQL inside `web/`, stop — add a repository function instead.

## Data Flow

### Onboarding Flow

```
Request: POST /api/onboarding
  ↓
web/ receives {goal, prior_knowledge, session_minutes, placement_score}
  ↓
repository/ creates LearnerState
  ↓
learning/ determines starting concept based on prior_knowledge
  ↓
Returns {learner_id, starting_concept}
```

### Course Loading (Pre-rendered)

```
Request: GET /api/courses/elf
  ↓
web/courses reads course ID from URL
  ↓
repository/courses reads courses/elf/manifest.json
  ↓
Returns Course struct with concepts, metadata
```

### Lesson Serving

```
Request: GET /api/courses/elf/lessons/elf-header
  ↓
web/lessons reads course ID + concept ID from URL
  ↓
web/lessons reads courses/elf/output/elf-header.html (pre-rendered)
  ↓
Returns HTML file directly (no rendering on request)
```

### Learning Session Flow

```
Request: POST /api/sessions/start
  ↓
web/ receives {course_id, type, energy}
  ↓
repository/ creates Session record
  ↓
learning/ determines first item based on course progress
  ↓
Returns {session_id, first_item}

Request: POST /api/sessions/:id/next
  ↓
web/ receives {concept_id, result}
  ↓
learning/ FSRS computes next interval
  ↓
repository/ updates ConceptState
  ↓
learning/ CLSI computes session load
  ↓
Returns {next_item, progress, break_suggested}

Request: POST /api/sessions/:id/complete
  ↓
web/ receives {energy_after}
  ↓
repository/ updates Session record
  ↓
learning/ computes session summary
  ↓
Returns {summary, next_reviews}
```

### Review Session Flow

```
Request: POST /api/review/start
  ↓
web/ receives {course_id}
  ↓
learning/ gets due items from FSRS scheduler
  ↓
Returns {session_id, items[], estimated_time}

Request: POST /api/review/submit
  ↓
web/ receives {item_id, rating}
  ↓
learning/ FSRS updates difficulty, stability, retrievability
  ↓
repository/ updates ConceptState
  ↓
Returns {next_item, progress}
```

### Dashboard Flow

```
Request: GET /api/dashboard
  ↓
web/ reads learner_id from session
  ↓
repository/ gets LearnerState, ConceptStates, Sessions
  ↓
learning/ computes:
  - current_concept (from LearnerState)
  - course_progress (from ConceptStates)
  - reviews_due (from FSRS scheduler)
  - weekly_activity (from Sessions)
  - knowledge_health (from ConceptStates)
  ↓
Returns {progress, streak, reviews_due, knowledge_health, upcoming}
```

### Adaptation Flow

```
Performance Data Collected (during sessions)
  ↓
CLSI Computed:
  CLSI = (w1 * accuracy + w2 * (1 - error_rate) + w3 * (1 - retry_rate)) / (w1 + w2 + w3)
  ↓
┌─────────────────────────────────────────┐
│ CLSI >= 0.60 → Optimal                  │
│   → Continue standard path              │
│   → Gradually increase difficulty       │
├─────────────────────────────────────────┤
│ CLSI 0.40 - 0.60 → Adequate            │
│   → Continue, monitor                   │
├─────────────────────────────────────────┤
│ CLSI < 0.40 → Overloaded               │
│   → Reduce difficulty                   │
│   → Shorter sessions                    │
│   → Check prerequisites                 │
└─────────────────────────────────────────┘
  ↓
Next Session Adjusted
```

### Course Compilation (Build Time)

```
courses/elf/src/*.ch files
  ↓ TCCCompiler
courses/elf/output/*.html + *.css + *.js (pre-rendered static files)
  ↓
web/static serves these files via HTTP
```

## Key Design Decisions

### 1. Course Pages Are Pre-Rendered

Course concept .ch files compile to static HTML/CSS/JS at build time. The web server serves these pre-rendered files — it does NOT render pages on every request. This means:
- Fast page loads (no server-side rendering)
- Course pages can be served from CDN
- Offline support is trivial (download the output/ directory)
- The `page` library's `HtmlPage.toString()` or `writeToDirectory()` generates the files

### 2. Database Is Dual-Backend

The `DbClient` auto-selects based on connection URL:
- Local file path (e.g., `./underlayer.db`) → SQLite3 via `lang/compiled/sqlite3/`
- HTTP/HTTPS URL (e.g., `https://xxx.turso.io`) → Turso HTTP via `lang/compiled/academic/libturso/`

This matches the pattern from `lang/compiled/cars/database/`.

### 3. FSRS Over SM-2

FSRS (Free Spaced Repetition Scheduler) is used instead of SM-2 because:
- 20-30% fewer reviews for same retention
- Better handles difficult items
- Parameters derived from actual forgetting curves
- Modern algorithm (2023) based on memory research

### 4. Chemical for Everything

All implementation is in Chemical, including the Android bridge. This means:
- We discover Chemical gaps early
- Single language for maintenance
- Native performance for course rendering
- Chemical's memory model suits the domain

## Technology Stack

| Component | Technology | Source |
|---|---|---|
| Language | Chemical | — |
| Build | TCCCompiler / LLVM Compiler | — |
| Web Server | `server::Server` (thread pool, routing) | `lang/libs/server/` |
| HTTP Client | `http::Client` (for Turso HTTP) | `lang/libs/http/` |
| Database (local) | SQLite3 (C FFI bindings) | `lang/compiled/sqlite3/` |
| Database (remote) | Turso HTTP v2 | `lang/compiled/academic/libturso/` |
| JSON | `json::parse()` / `json::stringify()` | `lang/libs/json/` |
| HTML Pages | `HtmlPage` + `#html`/`#css`/`#js`/`#md` macros | `lang/libs/page/` + CBI plugins |
| UI Components | Shadcn-style (Button, Card, Input, etc.) | `lang/libs/components/` |
| File I/O | `fs` library | `lang/libs/fs/` |
| Course Format | Chemical source files → pre-rendered HTML/CSS/JS | — |
| Android | JNI bridge to Chemical runtime | TBD |
| CI/CD | GitHub Actions | — |
| Hosting | Fly.io (single binary) + Tigris S3 (CDN) | — |

## Reusable Component Architecture

Underlayer builds reusable UI components using Chemical's `#universal` macro system. These components are shared between the platform and course content.

### Component Layers

```
lang/libs/components/        ← Platform components (Button, Card, Input, Badge, Typography, etc.)
    ↓ imported by
underlayer/theme/             ← Shared layout (header, footer, global CSS)
    ↓ imported by
underlayer/web/               ← Platform pages (home, dashboard, settings)
    ↓ imported by
underlayer/courses/elf/       ← Course pages (can use platform components)
    ↓ may also define
courses/elf/src/components/   ← Course-specific components (HexViewer, ElfDiagram, etc.)
```

### How Components Flow

1. **Platform defines components** in `lang/libs/components/` — Button, Card, Input, Badge, Typography, Separator, Alert, Toggle, Select
2. **Theme module** imports components and defines shared layout (header, footer, global CSS)
3. **Web pages** import theme + components, use them in `#html` blocks
4. **Course pages** import components directly, use them in `#html` blocks
5. **Course-specific components** live in `courses/<name>/src/components/`, import platform components

### Component Definition Pattern

Every universal component follows this pattern:

```chemical
// Part A: CSS style function (returns hashed class name)
func button_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: inline-flex;
        align-items: center;
        /* ... scoped CSS ... */
    }
}

// Part B: Universal component (JSX → SSR HTML + hydration JS)
public #universal Button(props) {
    return <button
        {...props}
        class={(props.className || props.class) || "" + " " + ${button_styles(page)}}
        data-variant={props.variant || "default"}
        type={props.type || "button"}
    >{props.children}</button>
}
```

### Available Platform Components

| Component | File | Variants | Purpose |
|-----------|------|----------|---------|
| `Button` | `Button.ch` | default, outline, ghost, destructive | Actions, form submits |
| `Card`, `CardBody`, `CardTitle`, `CardMeta` | `Card.ch` | — | Content containers |
| `Input`, `TextArea`, `NativeSelect` | `Input.ch` | — | Form inputs |
| `Field`, `FieldLabel` | `Input.ch` | — | Form field wrappers |
| `Badge` | `Badge.ch` | default, secondary, outline, destructive | Tags, status |
| `H1`–`H6`, `Text`, `Link`, `Heading` | `Typography.ch` | — | Text display |
| `Separator` | `Separator.ch` | — | Horizontal dividers |
| `Alert` | `Alert.ch` | default, destructive | Notifications |
| `Checkbox`, `Radio`, `Switch` | `Toggle.ch` | — | Boolean inputs |
| `Select` | `Select.ch` | — | Dropdown with state |

### Using Components in Pages

```chemical
import page
import html_cbi
import css_cbi
import components

public func render_page() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // REQUIRED for universal components
    page.defaultPrepare()

    #html {
        <div class="container">
            <H1>Welcome</H1>
            <Text>Learn technical subjects deeply.</Text>
            <Button variant="default">Get Started</Button>
            <Button variant="outline">Learn More</Button>

            <Card>
                <CardBody>
                    <CardTitle>Course Title</CardTitle>
                    <CardMeta>15 concepts · 20 hours</CardMeta>
                    <Badge variant="secondary">Beginner</Badge>
                </CardBody>
            </Card>
        </div>
    }

    #css {
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
    }

    return page.toString()
}
```

### Using Components in Course Content

Course concept files can use the same platform components:

```chemical
// courses/elf/src/bytes.ch

import page
import html_cbi
import css_cbi
import js_cbi
import components           // platform components

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()

    #html {
        <div class="lesson">
            <H1>Bytes and Binary</H1>
            <Badge variant="outline">Core concept · 15 min</Badge>

            <Card>
                <CardBody>
                    <Text>Every piece of data in a computer is stored as bytes.</Text>
                </CardBody>
            </Card>

            <Button variant="default" onClick={showInteractive}>
                Try Interactive Explorer
            </Button>
        </div>
    }

    return page.toString()
}
```

### Course-Specific Components

Courses can define their own components in `src/components/`:

```
courses/elf/src/components/
    HexViewer.ch        (interactive hex dump)
    ElfDiagram.ch       (clickable ELF layout)
    QuizFeedback.ch     (quiz result with explanation)
```

These components import from `page`, `html_cbi`, `css_cbi`, `universal_cbi` — they do NOT depend on the platform. This keeps courses portable.

### Component Dependency Rules

1. **Platform components** (`lang/libs/components/`) depend on: `page`, `universal_cbi`, `css_cbi`
2. **Theme** depends on: `components`, `page`, `html_cbi`, `css_cbi`
3. **Web pages** depend on: `theme`, `components`, `page`, `html_cbi`
4. **Course pages** depend on: `components` (optional), `page`, `html_cbi`, `css_cbi`, `js_cbi`
5. **Course-specific components** depend on: `page`, `html_cbi`, `css_cbi`, `universal_cbi` (NOT on platform components — keeps courses portable)

### CSS Class Name Hashing

The `#css` macro automatically hashes class names to prevent collisions. When you write:

```chemical
func my_styles(page : *mut HtmlPage) : *char {
    return #css { .container { max-width: 800px; } }
}
```

The macro returns a hashed class name like `"chx-a1b2c3"`. Use it in `#html` via `${my_styles(page)}`:

```chemical
#html {
    <div class={${my_styles(page)}}>
        Content here
    </div>
}
```

### `page.defaultUniversalSetup()` Requirement

Every page that uses universal components MUST call `page.defaultUniversalSetup()` before any `#html` blocks. This injects the hydration runtime JS that makes client-side interactivity work. Without it, components render static HTML but have no interactivity.

## Gotchas

- **Universal components have known bugs.** Use carefully. Prefer simple HTML for course content. Load `implementation_gaps/SKILL.md` for the full list.
- **Chemical is young.** Some features may not exist. Document gaps.
- **Courses must be portable.** No platform-specific dependencies in course files.
- **Auto-deploy on commit.** Code must be correct before merge.
- **No SQLite in std libs.** Use the existing `lang/compiled/sqlite3/` package.
- **Course pages are pre-rendered.** The server serves static files — it does not render on every request.

## Missing Infrastructure

### Binary Format Library (Needed for ELF Course)

Endian helpers are duplicated across `archive/endian`, `audio/wav`, `image/png`. A shared `binfmt` library is needed:

```chemical
// Proposed: lang/libs/binfmt/
public namespace binfmt {
    func read_u8(data : *u8, offset : size_t) : u8
    func read_u16_le(data : *u8, offset : size_t) : u16
    func read_u16_be(data : *u8, offset : size_t) : u16
    func read_u32_le(data : *u8, offset : size_t) : u32
    func read_u32_be(data : *u8, offset : size_t) : u32
    func read_u64_le(data : *u8, offset : size_t) : u64
    func read_u64_be(data : *u8, offset : size_t) : u64
    struct BitReader { ... }
    func read_bits(reader : *mut BitReader, count : int) : u64
    struct ByteSlice { var data : *u8; var len : size_t }
}
```

### Interactive Teaching Components (Needed for Course Content)

These components are defined in the teaching catalog but not implemented:

| Component | Priority | Used For |
|-----------|----------|---------|
| InteractiveHexViewer | CRITICAL | ELF, PE, Mach-O, TLS, WAV |
| ElfLayoutDiagram | CRITICAL | ELF structure visualization |
| ByteFieldMapper | CRITICAL | Struct-to-bytes mapping |
| MemoryMapAnimator | HIGH | Loading process visualization |
| StructPaddingVisualizer | HIGH | C struct alignment teaching |
| RelocationSimulator | HIGH | Link-time relocation |
| EndiannessDemo | MEDIUM | LE/BE comparison |
| BitfieldExplorer | MEDIUM | Flag field inspection |

### Chemical Language Gaps

| Gap | Impact | Workaround |
|-----|--------|-----------|
| No `try/catch` | No structured error handling | Use `Result<T,E>` everywhere |
| No `defer` | No RAII cleanup | Use `@delete` destructors |
| No string `+` operator | Verbose string building | Use `append_view()` or backtick templates |
| No `vector[]` operator | Verbose array access | Use `.get(i)` / `.get_ptr(i)` |
| `if` requires `else` | Boilerplate | Always add `else {}` |
| No `format()` | No printf-style formatting | Use `cstd::sprintf` or backtick templates |
| No `map()`/`filter()` on vectors | No functional transforms | Write manual loops |
| `#html` no auto-escape | Security risk | Always use `page::escape_html()` |

### Document Redundancy

Multiple documents repeat the same information. Canonical sources:

| Concept | Canonical Source |
|---------|-----------------|
| 8-unit structure | `course-design.md` |
| Five Exposures | `course-design.md` |
| Anxiety design | `adaptive-flow-ui.md` |
| Exercise types | `teaching-components-catalog.md` |
| FSRS algorithm | `implementation-details.md` |
| Component catalog | `teaching-components-catalog.md` |
| Known bugs/gaps | `implementation_gaps/SKILL.md` |

Other documents should reference, not repeat.
