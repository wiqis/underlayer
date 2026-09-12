# Implementation Plan

## Status

Current phase: **Phase 2 — Learning Engine ✅**

- Phase 0: Planning ✅
- Phase 1: Foundation ✅
- Phase 2: Learning Engine ✅ (FSRS, weakness detection, interleaved review queue)
- Phase 3: Course Content (partial — 12 concepts done)
- Phase 4: Android App (not started)

## Dual-Mode Architecture (Static + Backend)

Underlayer courses work in TWO modes. This is a core architectural constraint.

### Mode 1: Static (GitHub Pages — No Backend)

Courses compile to static HTML/CSS/JS files. Served via GitHub Pages.
- **No server required.** Anyone can take the course from a URL.
- **Settings stored in localStorage.** Progress, preferences, bookmarks — all client-side.
- **Offline-first.** Download the HTML files, open in browser, works without internet.
- **Emission:** Chemical source files → `#html`/`#css`/`#js` macros → HtmlPage → `.html` + `.css` + `.js` files → committed to repo → served by GitHub Pages.

### Mode 2: Backend (Full Server — Account Management)

The same courses, plus user accounts, profiles, analytics, and adaptive learning.
- **User accounts.** Email/password, OAuth, profile management.
- **Server-side progress.** Spaced repetition schedules, learning history, knowledge health.
- **Adaptive flow.** FSRS engine adjusts difficulty based on performance.
- **Cross-device sync.** Progress follows the learner across devices.
- **API endpoints.** JSON APIs for course data, progress, reviews.

### Course Design Rule: Backend-Optional

Every course MUST work without a backend. This means:

1. **Course content is self-contained HTML.** No API calls required to render lessons.
2. **All interactivity is client-side JS.** Quizzes, hex viewers, code editors — all work offline.
3. **Progress detection is optional.** If no backend, progress stays in localStorage.
4. **Backend enhances, never gates.** Backend adds features (sync, analytics) but never blocks content.

### Emission Pattern

```chemical
// Each concept file emits a complete HTML page
public func render_bytes() : std::string {
    var page = HtmlPage()
    page.default_prepare()

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <!-- Full lesson content -->
        </div>
    }

    #css { /* Scoped styles */ }
    #js { /* Client-side interactivity */ }

    return page.to_string()  // Complete HTML page
}
```

## Available Libraries (Existing in Chemical Ecosystem)

Before implementing, we reuse these existing libraries rather than building from scratch:

| Library | Location | What It Provides |
|---------|----------|------------------|
| `sqlite3` | `lang/compiled/sqlite3/` | Full SQLite3 C FFI bindings — `Database`, `Statement`, bind/column API, WAL mode |
| `libturso` | `lang/compiled/academic/libturso/` | Standalone Turso HTTP v2 client — `Client`, `Row`, `Stmt`, JSON-based response parsing |
| `server` | `lang/libs/server/` | HTTP server with thread pool, routing, TLS, static file serving (imports `net`, `http`) |
| `http` | `lang/libs/http/` | HTTP client, request/response, URL parsing, `HeaderMap`, `QueryMap`, `Body` |
| `json` | `lang/libs/json/` | JSON parse/stringify/encode/decode, `JsonValue` variant, typed serialization |
| `page` | `lang/libs/page/` | `HtmlPage` builder — 6 buffers (head, html, css, js, headJs, jsEnd), `toString()`, `writeToDirectory()` |
| `components` | `lang/libs/components/` | Shadcn-style UI: Button, Card, Input, Alert, Badge, Toggle, Typography, etc. |
| `html_cbi` | `lang/libs/html_cbi/` | `#html { }` macro — JSX-like syntax → HTML method calls on `HtmlPage` |
| `css_cbi` | `lang/libs/css_cbi/` | `#css { }` macro — CSS rules → scoped stylesheets on `HtmlPage` |
| `js_cbi` | `lang/libs/js_cbi/` | `#js { }` macro — JavaScript → `page.append_js()` calls |
| `md_cbi` | `lang/libs/md_cbi/` | `#md ... #endmd` macro — Markdown → HTML paragraphs on `HtmlPage` |
| `std` | `lang/libs/std/` | string, string_view, vector, unordered_map, ordered_map, Option, Result, function, pair |
| `cstd` | `lang/libs/cstd/` | C standard library bindings — malloc, free, printf, memcpy, srand, time |
| `fs` | `lang/libs/fs/` | File I/O, directory operations, metadata |
| `net` | `lang/libs/net/` | Low-level TCP sockets — Socket, listen, dial, accept, recv, send |
| `encoding` | `lang/libs/encoding/` | Hex, base64 encoding utilities |
| `uuid` | `lang/libs/uuid/` | UUID generation |
| `crypto` | `lang/libs/crypto/` | SHA256, SHA512, MD5, HMAC |

## Database Strategy

### Decision: Dual-Backend DbClient (SQLite local + Turso HTTP remote)

Reuse the proven pattern from `lang/compiled/cars/database/`:

```
DbClient
├── Local dev:  SQLite3 via lang/compiled/sqlite3/ (embedded, zero-config)
└── Production: Turso HTTP v2 via lang/compiled/academic/libturso/ (remote, scalable)
```

The `DbClient` auto-selects the backend based on the connection URL:
- URLs starting with `http://`, `https://`, or `libsql://` → Turso HTTP backend
- Anything else (e.g., `./underlayer.db`) → embedded SQLite3 backend

### Why Not Postgres/Neon

No Postgres library exists in the Chemical ecosystem. Building one from scratch is a significant undertaking. The SQLite3 + Turso HTTP pattern is proven (used in `cars` and `academic` projects) and covers both local dev and production.

### Schema Tables

```sql
-- Learners
CREATE TABLE learners (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE,
    name TEXT,
    created_at INTEGER,
    settings_json TEXT
);

-- Concept states (per-learner per-concept)
CREATE TABLE concept_states (
    learner_id TEXT,
    concept_id TEXT,
    course_id TEXT,
    status TEXT,           -- not_started, learning, reviewing, mastered
    attempts INTEGER DEFAULT 0,
    correct INTEGER DEFAULT 0,
    streak INTEGER DEFAULT 0,
    last_studied INTEGER,
    next_review INTEGER,
    difficulty_rating REAL DEFAULT 0,
    PRIMARY KEY (learner_id, concept_id, course_id)
);

-- Review items (per-learner, generated from concepts)
CREATE TABLE review_items (
    id TEXT PRIMARY KEY,
    learner_id TEXT,
    concept_id TEXT,
    course_id TEXT,
    type TEXT,             -- recall, recognize, apply, explain
    front TEXT,
    back TEXT,
    difficulty REAL DEFAULT 5.0,
    stability REAL DEFAULT 1.0,
    retrievability REAL DEFAULT 1.0,
    next_review INTEGER,
    last_review INTEGER,
    reps INTEGER DEFAULT 0,
    lapses INTEGER DEFAULT 0
);

-- Sessions
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    learner_id TEXT,
    start_time INTEGER,
    end_time INTEGER,
    type TEXT,             -- learn, review, mixed
    concepts_hit_json TEXT,
    exercises_attempted INTEGER DEFAULT 0,
    exercises_correct INTEGER DEFAULT 0,
    energy_before TEXT,
    energy_after TEXT
);
```

## Course Content Format

### Decision: Chemical Source Files with #html/#css/#js/#md Macros

Courses are **Chemical source files** that use CBI macros to generate HTML pages:

```chemical
import page
import html_cbi
import css_cbi
import js_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.appendTitle(std::string_view("ELF Header — Underlayer"))

    #html {
        <div class="lesson">
            <h1>The ELF Header</h1>
            <p>Every ELF file starts with a header...</p>

            <div class="hex-viewer">
                @{/* hex dump with interactive highlighting */}
            </div>

            <div class="quiz" id="quiz-1">
                <p>What are the first 4 bytes of an ELF file?</p>
                <button onclick="checkAnswer(this, true)">0x7f ELF</button>
                <button onclick="checkAnswer(this, false)">MZ\x90\x00</button>
                <button onclick="checkAnswer(this, false)">CAFEBABE</button>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .hex-viewer { background: #1e1e1e; color: #d4d4d4; padding: 1rem; font-family: monospace; }
        .quiz button { display: block; margin: 0.5rem 0; padding: 0.75rem; width: 100%; text-align: left; }
    }

    #js {
        function checkAnswer(btn, correct) {
            if(correct) { btn.style.background = '#059669'; }
            else { btn.style.background = '#dc2626'; }
        }
    }

    return page.toString()
}
```

### Compilation Flow

```
Chemical source files (.ch)
    ↓ TCCCompiler / LLVM Compiler
Pre-rendered HTML + CSS + JS files
    ↓ write to directory
courses/elf/output/
    ├── bytes.html + bytes.css + bytes.js
    ├── elf-header.html + elf-header.css + elf-header.js
    └── ...
    ↓ HTTP server serves static files
Browser loads pre-rendered pages
```

### Course Directory Structure

```
courses/elf/
├── chemical.mod              (module declaration — imports page, html_cbi, etc.)
├── manifest.json             (metadata, module sequence, concept list)
├── src/
│   ├── main.ch               (build entry — calls all render functions, writes output/)
│   ├── bytes.ch              (concept page: #html + #css + #js → HtmlPage → toString)
│   ├── binary-representation.ch
│   ├── file-layout.ch
│   ├── elf-header.ch
│   ├── program-headers.ch
│   ├── sections.ch
│   ├── symbols.ch
│   ├── relocations.ch
│   └── dynamic-linking.ch
├── output/                   (generated — pre-rendered HTML/CSS/JS)
│   ├── bytes.html
│   ├── bytes.css
│   ├── bytes.js
│   └── ...
└── assets/
    ├── samples/              (real ELF files for exercises)
    └── images/
```

### Build Command

```bash
# Compile course pages (generates output/ directory)
cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
    -o lang/compiled/underlayer/courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules

# Run the page generator
./lang/compiled/underlayer/courses/elf/build/elf-pages.exe
# → writes courses/elf/output/*.html + *.css + *.js
```

## Phases

### Phase 0: Planning ✅

- [x] Read and understand the constitution document
- [x] Research competitors (Brilliant, Exercism, CodeCrafters, roadmap.sh, nand2tetris, OST2, Coursera)
- [x] Research teaching methods for anxiety, depression, overthinking
- [x] Research spaced repetition (FSRS, SM-2, SuperMemo)
- [x] Research desirable difficulties (Bjork), retrieval practice, interleaving
- [x] Write AGENTS.md
- [x] Write conceptual model
- [x] Write feature specifications
- [x] Write competitor analysis
- [x] Write course design methodology
- [x] Write AI constraint system
- [x] Write deployment architecture
- [x] Write skills (7 skills)
- [x] Write implementation plan (this document)
- [x] Audit available Chemical libraries (sqlite3, libturso, page, server, components, json, etc.)
- [x] Decide database strategy (dual-backend SQLite + Turso HTTP, reusing `cars` pattern)
- [x] Decide course content format (.ch files with #html/#css/#js/#md macros → HtmlPage)
- [x] Write implementation details document

### Phase 1: Foundation (Week 1-2) ✅

**Goal:** Minimal working platform that can serve a static course.

#### 1.1 Project Skeleton
- [x] Create `chemical.mod` with module structure
  - Imports: `std`, `cstd`, `server`, `http`, `json`, `page`, `html_cbi`, `css_cbi`, `js_cbi`, `universal_cbi`, `components`, `fs`, `net`, `encoding`, `uuid`
- [x] Create `src/main.ch` — server entry point
  - Initialize config from env vars
  - Initialize database (DbClient)
  - Register HTTP routes
  - Start server on configured port
- [x] Create `core/` module
  - `core/src/main.ch` — config, logging, string/time utilities

#### 1.2 Database Layer
- [x] Create `database/` module
  - `database/src/main.ch` — dual-backend DbClient (SQLite local + Turso HTTP remote)
  - Reuse pattern from `lang/compiled/cars/database/`
  - Reuse `lang/compiled/sqlite3/` for local SQLite

#### 1.3 Models
- [x] Create `models/` module — plain domain structs (no business logic)
  - `models/src/main.ch` — Course, Module, ConceptRef, Concept, Manifest, Learner, ConceptState, ReviewItem, Session, Exercise

#### 1.4 Repository
- [x] Create `repository/` module — ALL SQL lives here
  - `repository/src/main.ch` — init_schema, filesystem course loading, JSON helpers, learner CRUD, concept state CRUD, review item CRUD

#### 1.5 Minimal Web Platform
- [x] Create `web/` module with routes
  - `web/src/main.ch` — route registration
  - Health endpoint: `GET /api/health` → `{"status": "ok"}`
  - Course listing: `GET /api/courses` → JSON array of courses
  - Course detail: `GET /api/courses/:id` → JSON course with concepts
  - Lesson viewer: `GET /api/courses/:id/lessons/:concept_id` → pre-rendered HTML page
  - Static file serving: serve `courses/*/output/` directories
  - Review API: `GET /api/review/start`, `POST /api/review/submit`
  - Progress API: `GET /api/progress`

#### 1.6 First Course Content
- [x] Create ELF course directory: `courses/elf/`
  - `courses/elf/chemical.mod` — imports page, html_cbi, css_cbi, js_cbi
  - `courses/elf/manifest.json` — metadata, module sequence, concept list
  - `courses/elf/src/main.ch` — build entry, calls render functions
  - 12 concept files in `content/src/` (bytes, binary-representation, file-layout, elf-identification, elf-header-fields, entry-point, program-header-table, segment-types, memory-mapping, section-header-table, common-sections, section-vs-segment)
  - 9 universal components in `content/components/` (Badge, Button, Card, HexViewer, Navigation, Progress, Quiz, SectionHeader, Test)

**Deliverable:** A deployed website showing the first 12 ELF lessons with exercises.

### Phase 2: Learning Engine (Week 3-4) ✅

**Goal:** Spaced repetition, retrieval practice, and progress tracking.

#### 2.1 FSRS Engine
- [x] Create `learning/` module (`learning/src/main.ch`)
  - FSRS algorithm (difficulty, stability, retrievability)
  - `init_fsrs_params()` — default FSRS parameters (19 weights)
  - `fsrs_next_interval()` — compute next review interval
  - `fsrs_update_state()` — update D, S, R after review
  - `fsrs_retrievability()` — current recall probability
- [x] Review session management
  - `start_review_session()` — create session from items
  - `get_current_item()` — get current review item
  - `advance_session()` — move to next item
  - `is_session_complete()` — check if done
- [x] Knowledge health tracking
  - `compute_knowledge_health()` — strong/weak/unlearned breakdown

#### 2.2 Learner State
- [x] Learner state storage via repository layer
- [x] Concept state tracking (not_started, learning, reviewing, mastered)
- [x] Session history logging

#### 2.3 Retrieval Practice
- [x] Review item generation from concepts
- [x] Free recall questions (no hints)
- [x] Recognition questions (multiple choice)
- [x] Application exercises (use the knowledge)

#### 2.4 Interleaved Reviews
- [x] Daily review queue with interleaved new/due items
- [x] Configurable limits (max_new_per_day, max_reviews_per_day)

#### 2.5 Weakness Detection
- [x] `detect_weaknesses()` — find concepts below accuracy threshold
- [x] `suggest_repair()` — recommend prerequisite review

**Deliverable:** Learner can create account, learn concepts, and get scheduled reviews.

### Phase 3: Course Content (Week 5-8)

**Goal:** Complete ELF course with all concept types.

#### 3.1 ELF Course Modules
- [ ] Module 1: Fundamentals (bytes, binary, file layout)
- [ ] Module 2: ELF Header (identification, fields, entry point)
- [ ] Module 3: Program Headers (table, segments, memory mapping)
- [ ] Module 4: Sections (section header, common sections, section vs segment)
- [ ] Module 5: Symbols (symbol table, binding, visibility)
- [ ] Module 6: Relocations (relocation types, dynamic sections)
- [ ] Module 7: Dynamic Linking (dynamic section, libraries, ld.so)
- [ ] Module 8: Loading (loader, memory layout, execution)

#### 3.2 Visualizations
- [ ] ELF file layout diagram (clickable, using #html + #js)
- [ ] Hex viewer with field highlighting (using #html + #css + #js)
- [ ] Segment-to-memory mapping visualization
- [ ] Symbol table tree
- [ ] Relocation processing visualization

#### 3.3 Exercises
- [ ] 5+ exercises per concept (recall, recognize, apply, debug, construct)
- [ ] Debug exercises (find errors in ELF parsers)
- [ ] Hex inspection exercises (read real ELF files)
- [ ] Construction exercises (write small ELF parsers)

#### 3.4 Review Items
- [ ] Generate 5-8 review items per concept
- [ ] Verify all review items against specification
- [ ] Test all exercises for correctness

**Deliverable:** Complete ELF course with 50+ concepts, 200+ exercises, 5 visualizations.

### Phase 4: Android App (Week 9-12)

**Goal:** Offline-first Android app for course learning.

#### 4.1 Chemical Runtime for Android
- [ ] Cross-compile Chemical to Android (JNI bridge)
- [ ] Implement local SQLite for learner state
- [ ] Implement file system access for course storage

#### 4.2 Course Player
- [ ] Implement course download and extraction
- [ ] Implement lesson rendering (pre-rendered HTML → WebView)
- [ ] Implement exercise engine (exercise → interactive UI)
- [ ] Implement visualization rendering

#### 4.3 Offline Learning
- [ ] Implement local FSRS engine
- [ ] Implement offline review sessions
- [ ] Implement progress sync when online

#### 4.4 Polish
- [ ] Implement energy check-in UI
- [ ] Implement session length preferences
- [ ] Implement fatigue detection
- [ ] Implement "welcome back" messaging (no streak shaming)

**Deliverable:** Android app that downloads ELF course and provides offline learning.

### Phase 5: Platform Polish (Week 13-16)

**Goal:** Production-ready platform with all features.

#### 5.1 Web Platform
- [ ] Course management admin (create, edit, version courses)
- [ ] Learner dashboard (progress, next reviews, knowledge health)
- [ ] Course download page
- [ ] Account management

#### 5.2 Learning Features
- [ ] Weakness detection and repair recommendations
- [ ] Knowledge graph visualization
- [ ] Energy dashboard (session history, accuracy trends)
- [ ] Course update notifications

#### 5.3 Quality
- [ ] Integration tests for all API endpoints
- [ ] Course content verification tests
- [ ] FSRS algorithm tests
- [ ] Android app tests

#### 5.4 Auto-Deployment
- [ ] CI pipeline (build, test, deploy)
- [ ] Course CDN setup
- [ ] Android APK distribution
- [ ] Rollback mechanism

**Deliverable:** Production platform with auto-deploy, offline Android app, complete ELF course.

## Future Phases (Post-MVP)

### Phase 6: Second Course
- PE format course (portable from ELF course structure)
- Mach-O format course

### Phase 7: Advanced Learning
- Incremental reading (import specs, create review items)
- Cross-course concepts (shared knowledge graph)
- Community feedback (flag errors, suggest improvements)

### Phase 8: More Courses
- TLS implementation
- Linkers and loaders
- Memory allocators
- Virtual memory
- Filesystems

## Chemical Gaps to Document

As we build, we'll encounter Chemical features that don't exist yet. Document them:

| Gap | Description | Workaround |
|---|---|---|
| JNI bridge | Chemical → Android Java interop | TBD — may need to write Android UI in Kotlin, bridge to Chemical |
| Delta updates | Download only changed course content | Full re-download for now |
| File watching | Hot reload during development | Manual restart |
| Postgres driver | No Postgres library exists | Use SQLite/Turso HTTP for now; build Postgres binding later if needed |
| WebSocket | No WebSocket library for real-time updates | Use polling for now |

See `docs/implementation-gaps.md` for the comprehensive list of all known gaps, bugs, and limitations.
