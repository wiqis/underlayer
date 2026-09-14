# Product Architecture Skill

Load this skill when understanding or modifying the overall Underlayer system design.

> **Also load `engineering_patterns`** for error handling, logging, security, caching, testing, monitoring, and privacy patterns. This skill covers *what the system is*; `engineering_patterns` covers *how to build it correctly*.

> **Also load `libs_reference`** for the complete catalog of available libraries and APIs. This skill covers *system design*; `libs_reference` covers *what's available to implement it*.

## System Overview

Underlayer is a learning platform for deep technical subjects. It consists of:
1. **Web platform** — course browsing, learner account, course management
2. **Android app** — offline-first course player with spaced repetition
3. **Course format** — self-contained, portable directories with Chemical source files that compile to pre-rendered HTML/CSS/JS

## Module Structure (as implemented)

```
underlayer/
├── chemical.mod              (project manifest — application underlayer, imports all modules;
│                              source "app" if !test, source "tests" if test)
├── app/main.ch               (server entrypoint: config → DB → schema → routes → serve)
├── tests/src/*.ch            (@test functions — run via scripts/test.sh)
│
├── core/                     (module underlayer_core — src/main.ch only, 188 lines)
│   load_config, get_env_str, get_env_uint, parse_uint,
│   int_to_string, u32_to_string, log_info, log_error,
│   current_timestamp, path_segments, json_escape, make_json_string
│
├── models/                   (module underlayer_models — src/main.ch only, 374 lines)
│   Course, Module, ConceptRef, Concept, Manifest,
│   Learner, ConceptState, ReviewItem, Session,
│   ExerciseType (+8 factory funcs), Exercise
│
├── database/                 (module underlayer_db — src/main.ch only, 198 lines)
│   DbClient, is_remote_url, make_client, exec_sql, query_sql,
│   query_sql_single, close  (auto-selects SQLite or Turso by URL)
│
├── repository/               (module underlayer_repository — ALL SQL lives here)
│   └── src/
│       ├── main.ch           (module root)
│       ├── helpers.ch        (parse_i64, parse_int, parse_f64, json helpers — public)
│       ├── schema.ch         (init_schema — CREATE TABLE IF NOT EXISTS + migrations)
│       ├── courses.ch        (load_course: disk manifest.json → hardcoded ELF fallback)
│       ├── learners.ch       (create_learner, get_learner)
│       ├── concept_states.ch (get/upsert/get_all_concept_state)
│       ├── review_items.ch   (get_due/get_all/update/insert_review_item)
│       ├── sessions.ch       (create/insert/finish/pause/resume/abort/undo/skip)
│       ├── session_items.ch  (record/get items, stats, history)
│       ├── exercises.ch      (get/get_for_concept/insert/count_exercises)
│       └── goals.ch          (get/set/delete_learning_goal)
│
├── learning/                 (module underlayer_learning — pure algorithms, no SQL)
│   └── src/
│       ├── main.ch           (module root — rating constants)
│       ├── fsrs.ch           (FSRS v4: params, retrievability, next_interval, update_state, optimize/reset/export)
│       ├── session.ch        (ReviewSession: start, get_current_item, advance, is_complete)
│       ├── queue.ch          (review queue: build, interleave, adaptive strength)
│       ├── weakness.ch       (detect weaknesses, trends, chains, clusters, repair)
│       ├── health.ch         (knowledge health: depth, breadth, gaps, trends, projection)
│       └── utils.ch          (f64_to_string)
│
├── web/                      (module underlayer_web — handlers, pages, static serving)
│   └── src/
│       ├── main.ch           (module root — WebConfig struct + file listing)
│       ├── helpers.ch        (send_page, send_json_str, send_error, sv_to_string, render_concept)
│       ├── json_helpers.ch   (json_get, json_str, json_get_str, json_int, json_get_int)
│       ├── handlers_home.ch         (handle_health, handle_home)
│       ├── handlers_courses.ch      (list courses, get course, filter)
│       ├── handlers_lessons.ch      (lesson viewer, course landing)
│       ├── handlers_review.ch       (start/submit/end/due + modes + recommendations)
│       ├── handlers_review_page.ch  (GET /review HTML page)
│       ├── handlers_progress.ch     (progress, course progress, export)
│       ├── handlers_progress_page.ch(GET /progress HTML page)
│       ├── handlers_dashboard.ch    (GET /dashboard)
│       ├── handlers_learners.ch     (create/get learner)
│       ├── handlers_exercises.ch    (get/submit/hint)
│       ├── handlers_weakness.ch     (dashboard, export, compare, alerts)
│       ├── handlers_search.ch       (GET /api/search)
│       ├── handlers_navigation.ch   (prev/next concept)
│       ├── handlers_settings.ch     (FSRS settings: optimize/reset/export/import)
│       └── static.ch                (content_type_for_ext, handle_static_file)
│
├── content/                  (module underlayer_content — 24 concept render functions)
│   └── src/
│       ├── bytes.ch, binary-representation.ch, file-layout.ch,
│       ├── elf-identification.ch, elf-header-fields.ch, entry-point.ch,
│       ├── program-header-table.ch, segment-types.ch, memory-mapping.ch,
│       ├── section-header-table.ch, common-sections.ch, section-vs-segment.ch,
│       ├── symbol-table.ch, binding.ch, visibility.ch,
│       ├── relocation-entries.ch, relocation-types.ch, dynamic-relocations.ch,
│       ├── dynamic-section.ch, shared-libraries.ch, ld-so.ch,
│       └── loader.ch, memory-layout.ch, execution.ch
│                              (each exports render_<concept_id>() : string)
│
├── courses/elf/              (course content: chemical.mod, manifest.json, src/ —
│                              4 source files so far: main.ch, bytes.ch,
│                              binary-representation.ch, file-layout.ch)
│
└── .agents/skills/           (this documentation)
```

**Important:** the `courses/elf/src/` files duplicate renderers for the first 3 concepts so the course can be pre-rendered to static output. The server-rendered path uses `content/src/*.ch` via `underlayer_web::render_concept()`. When adding a concept, add the renderer to `content/src/` AND register the ID→function mapping in `web/src/helpers.ch::render_concept()`.

## Dependency Chain (as implemented in chemical.mod files)

```
app/main.ch  (entrypoint — wires everything, registers all routes)
   ↓
web (underlayer_web)         (HTTP handlers, pages, static file serving)
   ↓ imports ../content, ../repository, ../learning is NOT imported by web —
   │  learning is used via repository where needed; keep it that way
content (underlayer_content) (concept renderers — imports core only)
   ↓
repository (underlayer_repository) (ALL SQL lives here — imports core, database, models)
   ↓
learning (underlayer_learning)     (pure algorithms — imports core, models, no SQL)
   ↓
models (underlayer_models)         (plain domain structs — imports std only)
database (underlayer_db)           (SQLite + Turso — imports std, cstd, http, json, core, sqlite3)
   ↓
core (underlayer_core)             (config, env, logging, utils — imports std, cstd)
```

**Rule:** A layer may only call layers below it. If you are tempted to run SQL inside `web/`, stop — add a repository function instead. If `learning/` ever needs SQL, take the data in as parameters instead — it stays pure.

**Namespace rule:** each module's namespace matches its directory: `underlayer_core`, `underlayer_models`, `underlayer_db`, `underlayer_repository`, `underlayer_learning`, `underlayer_web`, `underlayer_content`.

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
web/handlers_lessons reads course ID + concept ID from URL
  ↓
web/helpers.ch::render_concept() maps concept_id → underlayer_content::render_<id>()
  ↓
HtmlPage built with #html/#css/#js, sent via send_page()
  ↓
Returns HTML (rendered server-side at request time — concepts are compiled in)

Static assets (css/js files under courses/elf/) are served by
web/static.ch::handle_static_file via the /courses/* catch-all route.
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

### 1. Concept Pages Are Compiled In, Rendered On Request

Concept render functions live in `content/src/*.ch` and are compiled into the server binary. On request, `web/src/handlers_lessons.ch` calls `underlayer_web::render_concept()` which dispatches by concept ID to the matching `underlayer_content::render_*()` function. This means:
- No file I/O for lesson HTML — render functions build an `HtmlPage` in memory
- Adding a concept = new file in `content/src/` + one mapping line in `web/src/helpers.ch::render_concept()`
- Static assets (`.css`, `.js`, images) still come from disk via `static.ch`
- The `courses/elf/src/` directory mirrors 3 concepts for the pre-render-to-output flow (GitHub Pages mode); keep it in sync with `content/src/`

### 1b. Dual-Mode Architecture (Static + Backend)

Courses work in TWO modes. This is a core architectural constraint.

**Mode 1: Static (GitHub Pages)**
- Courses compile to static HTML/CSS/JS files
- Served via GitHub Pages — no server required
- Settings stored in localStorage — progress, preferences, bookmarks
- Offline-first — download HTML files, open in browser
- Emission: Chemical → `#html`/`#css`/`#js` → HtmlPage → `.html` + `.css` + `.js` → committed to repo

**Mode 2: Backend (Full Server)**
- Same courses, plus user accounts, profiles, analytics, adaptive learning
- Server-side progress — spaced repetition, learning history, knowledge health
- Adaptive flow — FSRS engine adjusts difficulty based on performance
- Cross-device sync — progress follows the learner across devices

**Course Design Rule: Backend-Optional**
Every course MUST work without a backend:
1. Course content is self-contained HTML — no API calls required
2. All interactivity is client-side JS — works offline
3. Progress detection is optional — localStorage if no backend
4. Backend enhances, never gates — adds features but never blocks content

### 2. Database Is Dual-Backend

`underlayer_db::make_client(url, token)` auto-selects based on the connection URL:
- Local file path (e.g., `./underlayer.db`) → SQLite3
- HTTP/HTTPS URL (e.g., `https://xxx.turso.io`) → Turso HTTP

`app/main.ch` skips `init_schema()` for remote URLs (remote DBs are provisioned externally).

Note: current repository code builds SQL with `string` + `append_view`/`append_string` (no parameterized queries). Values inserted into SQL must be trusted or escaped via `underlayer_core::json_escape`/`make_json_string` equivalents — see `api_reference` skill for the schema.

### 3. FSRS Over SM-2 — Implemented

FSRS v4 is implemented in `learning/src/fsrs.ch` (not just planned):
- `FSRSParams` with paper-default weights, `fsrs_retrievability`, `fsrs_next_interval`, `fsrs_update_state`
- `optimize_fsrs_params` (prediction-error based), `reset_fsrs_params`, `export_fsrs_params`
- Exposed via `/api/fsrs/optimize`, `/api/fsrs/reset`, `/api/fsrs/export`, `/api/fsrs/import`

FSRS is used instead of SM-2 because:
- 20-30% fewer reviews for same retention
- Better handles difficult items
- Parameters derived from actual forgetting curves

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
| **String appends for HTML/CSS/JS** | **FORBIDDEN** | **Use `#html`, `#css`, `#js` macros. Fix CBI plugin bugs.** |

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
