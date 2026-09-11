# Implementation Plan

## Status

Current phase: **Phase 0 — Planning ✅** (no code written yet)

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

### Phase 1: Foundation (Week 1-2)

**Goal:** Minimal working platform that can serve a static course.

#### 1.1 Project Skeleton
- [ ] Create `chemical.mod` with module structure
  - Imports: `std`, `cstd`, `server`, `http`, `json`, `page`, `html_cbi`, `css_cbi`, `js_cbi`, `components`, `fs`, `net`, `encoding`, `uuid`, `../sqlite3` (or inline Turso client)
- [ ] Create `src/main.ch` — server entry point
  - Initialize config from env vars
  - Initialize database (DbClient)
  - Register HTTP routes
  - Start server on configured port
- [ ] Create `core/` module
  - `core/src/config.ch` — read env vars (PORT, DATABASE_URL, DATABASE_TOKEN)
  - `core/src/logging.ch` — simple printf-based logging
  - `core/src/utils.ch` — string helpers, time formatting

#### 1.2 Database Layer
- [ ] Create `database/` module
  - `database/src/client.ch` — dual-backend DbClient (SQLite local + Turso HTTP remote)
    - Reuse pattern from `lang/compiled/cars/database/src/main.ch`
    - Reuse `lang/compiled/sqlite3/` for local SQLite
    - Reuse `lang/compiled/academic/libturso/` for Turso HTTP
  - `database/src/schema.ch` — table creation (learners, concept_states, review_items, sessions)
  - `database/src/migrations.ch` — schema versioning

#### 1.3 Models
- [ ] Create `models/` module — plain domain structs (no business logic)
  - `models/src/course.ch` — Course, Module, Manifest
  - `models/src/concept.ch` — Concept, LearningUnit, Source
  - `models/src/exercise.ch` — Exercise, Option, ExerciseType
  - `models/src/learner.ch` — Learner, ConceptState, EnergyProfile
  - `models/src/review.ch` — ReviewItem, ReviewType

#### 1.4 Repository
- [ ] Create `repository/` module — ALL SQL lives here
  - `repository/src/schema.ch` — init_schema(), seed_demo_data()
  - `repository/src/courses.ch` — course CRUD (read from manifest.json + concept files)
  - `repository/src/learners.ch` — learner CRUD
  - `repository/src/reviews.ch` — review item CRUD
  - `repository/src/sessions.ch` — session logging

#### 1.5 Minimal Web Platform
- [ ] Create `web/` module with routes
  - `web/src/main.ch` — route registration
  - Health endpoint: `GET /api/health` → `{"status": "ok"}`
  - Course listing: `GET /api/courses` → JSON array of courses
  - Course detail: `GET /api/courses/:id` → JSON course with concepts
  - Lesson viewer: `GET /api/courses/:id/lessons/:concept_id` → pre-rendered HTML page
  - Static file serving: serve `courses/*/output/` directories

#### 1.6 First Course Content
- [ ] Create ELF course directory: `courses/elf/`
  - `courses/elf/chemical.mod` — imports page, html_cbi, css_cbi, js_cbi
  - `courses/elf/manifest.json` — metadata, module sequence, concept list
  - `courses/elf/src/main.ch` — build entry, calls render functions, writes output/
  - `courses/elf/src/bytes.ch` — first concept: Bytes and Binary
    - Uses `#html { }` for JSX-like content
    - Uses `#css { }` for scoped styles
    - Uses `#js { }` for interactivity (quiz, hex viewer)
    - Returns `page.toString()` or `page.writeToDirectory()`
  - `courses/elf/src/binary-representation.ch` — second concept
  - `courses/elf/src/file-layout.ch` — third concept
  - 2 exercises per concept embedded in the .ch files

**Deliverable:** A deployed website showing the first 3 ELF lessons with exercises.

### Phase 2: Learning Engine (Week 3-4)

**Goal:** Spaced repetition, retrieval practice, and progress tracking.

#### 2.1 FSRS Engine
- [ ] Create `learning/` module
  - `learning/src/fsrs.ch` — FSRS algorithm (difficulty, stability, retrievability)
    - `init_params()` — default FSRS parameters
    - `next_interval(item, rating)` — compute next review interval
    - `update_state(item, rating)` — update D, S, R after review
    - `compute_retrievability(item, elapsed_days)` — current recall probability
  - `learning/src/review.ch` — review session management
    - `get_due_items(learner_id, limit)` — fetch items due for review
    - `present_item(item)` — format item for display
    - `record_rating(item_id, rating)` — record learner's rating
  - `learning/src/progress.ch` — progress tracking
    - `update_concept_state(learner_id, concept_id, correct)` — update mastery
    - `get_knowledge_health(learner_id)` — strong/weak/unlearned breakdown
  - `learning/src/weakness.ch` — weakness detection
    - `detect_weakness(learner_id)` — find concepts below accuracy threshold
    - `suggest_repair(weakness)` — recommend prerequisite review

#### 2.2 Learner State
- [ ] Learner state storage via repository layer
- [ ] Concept state tracking (not_started, learning, reviewing, mastered)
- [ ] Session history logging

#### 2.3 Retrieval Practice
- [ ] Review item generation from concepts
- [ ] Free recall questions (no hints)
- [ ] Recognition questions (multiple choice)
- [ ] Application exercises (use the knowledge)

#### 2.4 Interleaved Reviews
- [ ] Daily review queue (pull from all learned concepts)
- [ ] Cumulative quizzes (mix old and new material)

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

These gaps will be documented in `docs/chemical-gaps.md` as we encounter them.
