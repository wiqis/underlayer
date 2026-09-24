# Product Architecture Skill

Load this skill when understanding or modifying the overall Underlayer system design.

> **Also load `engineering_patterns`** for error handling, logging, security, caching, testing, monitoring, and privacy patterns. This skill covers *what the system is*; `engineering_patterns` covers *how to build it correctly*.

> **Also load `libs_reference`** for the complete catalog of available libraries and APIs. This skill covers *system design*; `libs_reference` covers *what's available to implement it*.

## System Overview

Underlayer is a learning platform for deep technical subjects. It consists of:
1. **Web platform** — course browsing, learner account, course management
2. **Android app** — offline-first course player with spaced repetition
3. **Course format** — self-contained, portable directories with Chemical source files that compile to pre-rendered HTML/CSS/JS

## Module Structure (as implemented — verified 2026-09-17)

```
underlayer/
├── chemical.mod              (application underlayer — source "src" + "app" if !test + "tests" if test;
│                              imports std, cstd, server, http, json, page, CBI macros, components,
│                              fs, net, encoding, uuid + ./core ./database ./models ./repository ./learning ./content ./web)
├── app/main.ch               (server entrypoint, ~1189 lines: config → DB → schema → ALL ~175 routes → serve)
├── tests/src/*.ch            (@test functions — run via scripts/test.sh)
│
├── core/                     (module underlayer_core — src/main.ch only, 247 lines)
│   load_config (PORT/DATABASE_URL/DATABASE_TOKEN/COURSES_DIR), get_env_str, get_env_uint, parse_uint,
│   int_to_string, u32_to_string, log_info, log_error, current_timestamp, path_segments,
│   json_escape, make_json_string
│
├── models/                   (module underlayer_models — src/main.ch only, 769 lines)
│   Course, Module, ConceptRef, Concept, Manifest, Learner, ConceptState, ReviewItem, Session,
│   ExerciseType (+8 factory funcs), Exercise + newer structs: Profile, LearnerSettings,
│   LearningPreferences, Notification, Achievement, StreakData, StudyPlan, Certificate, ...
│
├── database/                 (module underlayer_db — src/main.ch only, 198 lines)
│   DbClient, is_remote_url, make_client, exec_sql, query_sql, query_sql_single, close
│   (auto-selects SQLite or Turso by URL)
│
├── repository/               (module underlayer_repository — ALL SQL lives here)
│   └── src/
│       ├── main.ch, helpers.ch, schema.ch (~35 tables), courses.ch,
│       ├── learners.ch, concept_states.ch, review_items.ch, sessions.ch, session_items.ch,
│       ├── exercises.ch, goals.ch
│       ├── profiles.ch, settings.ch, enrollments.ch, prerequisites.ch
│       ├── notifications.ch, streaks.ch, achievements.ch, certificates.ch
│       ├── bookmarks.ch, notes.ch, study_plan.ch
│       ├── course_reviews.ch, feedback.ch
│       └── analytics_queries.ch (12+ analytics SQL queries)
│
├── learning/                 (module underlayer_learning — pure algorithms, no SQL)
│   └── src/
│       ├── main.ch           (module root — rating constants)
│       ├── fsrs.ch           (FSRS v4: params, retrievability, next_interval, update_state, optimize/reset/export)
│       ├── session.ch        (ReviewSession: start, get_current_item, advance, is_complete)
│       ├── queue.ch          (review queue: build, interleave, adaptive strength)
│       ├── weakness.ch       (detect weaknesses, trends, chains, clusters, repair)
│       ├── mistakes.ch       (mistake pattern classification + personalized feedback)
│       ├── health.ch         (knowledge health: depth, breadth, gaps, trends, projection)
│       └── utils.ch          (f64_to_string)
│
├── web/                      (module underlayer_web — 57 files: handlers, pages, assets, static serving)
│   └── src/
│       ├── main.ch, helpers.ch (send_page, send_json_str, send_error, sv_to_string, render_concept),
│       │   json_helpers.ch, static.ch
│       ├── home_assets.ch    (render_home_css / render_home_js — page assets pattern; home
│       │                      course grid client-renders from GET /api/courses, feature 2.1.25)
│       ├── handlers_auth.ch  (register/login/logout/me, password reset, email verify,
│       │                      auth_get_learner_id — bearer token → learner_id)
│       ├── Core learning: handlers_home, _courses, _lessons, _review, _review_page, _exercises,
│       │   _exercises_bulk, _progress, _progress_page, _dashboard, _learners, _weakness,
│       │   _search, _navigation, _settings (FSRS optimize/reset/export/import)
│       ├── Analytics: handlers_analytics, _analytics_learner, _analytics_pages, _analytics_platform
│       ├── Social: handlers_profiles, _course_reviews, _feedback, _achievements, _streaks,
│       │   _certificates, _bookmarks, _notes, _notifications
│       ├── Paths: handlers_knowledge_health, _learning_path, _learning_path_viz, _study_plan, _learning
│       ├── Settings/onboarding: handlers_settings_api, pages_settings, pages_onboarding, pages_components
│       └── Pages: pages_auth, pages_achievements, pages_analytics, pages_bookmarks, pages_certificates,
│           pages_help, pages_learning_path, pages_legal, pages_notes, pages_notifications,
│           pages_streaks, pages_study_plans
│
├── content/                  (module underlayer_content — 155 source files)
│   └── src/                  ELF (24) + HAT + PE + Mach-O concept renderers, course_landing(+assets),
│                             elf/hat/pe/macho_landing, lesson/hat assets, 4 layout templates
│
├── courses/elf/              (chemical.mod, manifest.json; src/main.ch = build entry that calls
│                              underlayer_content::render_*() and writes output/*.html —
│                              NO duplication of renderers anymore)
│
└── .agents/skills/           (this documentation)
```

**Note:** `courses/elf/src/` no longer mirrors concept renderers — `main.ch` reuses `underlayer_content::render_*()` directly. When adding a concept, add the renderer to `content/src/` AND register the ID→function mapping in `web/src/helpers.ch::render_concept()`.

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

### Auth Flow (as implemented)

```
POST /api/auth/register or /api/auth/login
  ↓
web/handlers_auth validates + hashes password (stored in learners.password_hash)
  ↓
Creates row in auth_sessions: {id, learner_id, token_hash (SHA of 64-hex token),
                               expires_at = now + 30 days}
  ↓
Returns {session_token, learner} — client sends it back as `Authorization: Bearer <token>`
  ↓
Protected handlers call auth_get_learner_id(db, req):
  extracts bearer token → hash → SELECT learner_id FROM auth_sessions
  WHERE token_hash = <hash> AND expires_at > now
  ↓
Empty string = unauthenticated → handler returns an error
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
- `courses/elf/src/main.ch` reuses the same renderers to pre-render static output for GitHub Pages mode

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

Note: current repository code builds SQL with `string` + `append_view`/`append_string` (no parameterized queries). Values inserted into SQL must be trusted or escaped via `underlayer_core::json_escape`/`make_json_string` equivalents — see `api_reference` skill for the schema. Passwords are stored hashed; bearer tokens are stored only as hashes (`auth_sessions.token_hash`).

### 3. Auth Is Bearer-Token (Implemented)

Registration/login issue a 30-day session token (64 random hex chars). Only the SHA hash is stored in `auth_sessions.token_hash`. Protected endpoints resolve the learner via `auth_get_learner_id(db, req)` reading `Authorization: Bearer`. Older endpoints (review, progress, courses) still accept explicit `learner_id` params — new user-scoped endpoints should use the bearer pattern.

### 4. FSRS Over SM-2 — Implemented

FSRS v4 is implemented in `learning/src/fsrs.ch` (not just planned):
- `FSRSParams` with paper-default weights, `fsrs_retrievability`, `fsrs_next_interval`, `fsrs_update_state`
- `optimize_fsrs_params` (prediction-error based), `reset_fsrs_params`, `export_fsrs_params`
- Exposed via `/api/fsrs/optimize`, `/api/fsrs/reset`, `/api/fsrs/export`, `/api/fsrs/import`

FSRS is used instead of SM-2 because:
- 20-30% fewer reviews for same retention
- Better handles difficult items
- Parameters derived from actual forgetting curves

### 5. Chemical for Everything

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
