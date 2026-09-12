# Implementation Details

This document provides concrete code patterns for implementing Underlayer. Read this before writing any code.

## Project chemical.mod

```chemical
application underlayer

source "src"

import std
import cstd
import server
import http
import json
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import fs
import net
import encoding
import uuid

// Database — reuse existing SQLite3 library
import sqlite
```

## Page Library Setup for Universal Components

Every page that uses universal components MUST call these functions in order:

```chemical
import page
import components

public func render_page() : std::string {
    var page = HtmlPage()

    // 1. Initialize universal hydration runtime (JS for client-side interactivity)
    page.defaultUniversalSetup()

    // 2. Add charset + viewport meta tags
    page.defaultPrepare()

    // 3. Inject shadcn-style theme CSS (design tokens: colors, spacing, fonts)
    page.injectDefaultComponentsTheme()

    #html {
        // ... your content using components ...
    }

    return page.toString()
}
```

### Function Reference

| Function | Source | Purpose |
|----------|--------|---------|
| `page.defaultUniversalSetup()` | `lang/libs/page` | Injects hydration runtime JS + CSS for `#universal` components. **Must be called first.** |
| `page.defaultPrepare()` | `lang/libs/page` | Adds `<meta charset="utf-8">` and viewport meta tag. |
| `page.injectDefaultComponentsTheme()` | `lang/libs/components` | Injects shadcn zinc theme CSS custom properties (`:root` + `.dark` class). Required for Card, Button, Badge, Alert, etc. to render correctly. |

### Why All Three Are Needed

1. **`defaultUniversalSetup()`** — Without this, `#universal` components render HTML on the server but have NO client-side hydration. Click handlers, state updates, and re-renders won't work.

2. **`defaultPrepare()`** — Without this, the page may render in quirks mode, causing layout issues.

3. **`injectDefaultComponentsTheme()`** — Without this, components like `<Button>`, `<Card>`, `<Badge>` render with no styling (invisible or broken layout). The theme defines CSS custom properties like `--primary`, `--border`, `--radius` that components reference via `hsl(var(--...))`.

### Common Mistakes

```chemical
// WRONG: Missing defaultUniversalSetup — components won't hydrate
var page = HtmlPage()
page.defaultPrepare()
page.injectDefaultComponentsTheme()
#html { <Button onClick={...}>Click</Button> }  // renders but onClick does nothing

// WRONG: Missing injectDefaultComponentsTheme — components have no styles
var page = HtmlPage()
page.defaultUniversalSetup()
page.defaultPrepare()
#html { <Button>Click</Button> }  // renders as unstyled HTML button

// CORRECT:
var page = HtmlPage()
page.defaultUniversalSetup()
page.defaultPrepare()
page.injectDefaultComponentsTheme()
#html { <Button onClick={...}>Click</Button> }  // styled + interactive
```

## Module 1: core/

### core/src/config.ch

```chemical
package core

import std

public struct Config {
    var port : std::string
    var database_url : std::string
    var database_token : std::string
    var courses_dir : std::string

    @make
    public func make() : Config {
        return Config {
            port = get_env("PORT", "9000"),
            database_url = get_env("DATABASE_URL", "./underlayer.db"),
            database_token = get_env("DATABASE_TOKEN", ""),
            courses_dir = get_env("COURSES_DIR", "./courses")
        }
    }
}

func get_env(name : *char, default_val : *char) : std::string {
    var val_opt = std::get_env(std::string_view(name))
    if(var Some(v) = val_opt) { return v }
    return std::string(default_val)
}
```

### core/src/logging.ch

```chemical
package core

import std

public func log_info(msg : std::string_view) {
    printf("[INFO] %.*s\n", msg.size(), msg.data())
}

public func log_error(msg : std::string_view) {
    printf("[ERROR] %.*s\n", msg.size(), msg.data())
}

public func log_request(method : std::string_view, path : std::string_view, status : int) {
    printf("[%.*s] %.*s → %d\n", method.size(), method.data(), path.size(), path.data(), status)
}
```

## Module 2: models/

### models/src/course.ch

```chemical
package models

import std

public struct Course {
    var id : std::string
    var title : std::string
    var version : int
    var description : std::string
    var modules : std::vector<Module>
    var concepts : std::vector<ConceptRef>
}

public struct Module {
    var id : std::string
    var title : std::string
    var order : int
    var concepts : std::vector<std::string>    // concept IDs
}

public struct ConceptRef {
    var id : std::string
    var title : std::string
    var module_id : std::string
    var prerequisites : std::vector<std::string>
    var estimated_minutes : int
    var importance : std::string     // "core", "important", "supplementary"
    var source_file : std::string    // e.g., "bytes.ch"
}
```

### models/src/learner.ch

```chemical
package models

import std

public struct Learner {
    var id : std::string
    var email : std::string
    var name : std::string
    var created_at : i64
}

public struct ConceptState {
    var learner_id : std::string
    var concept_id : std::string
    var course_id : std::string
    var status : std::string         // "not_started", "learning", "reviewing", "mastered"
    var attempts : int
    var correct : int
    var streak : int
    var last_studied : i64
    var next_review : i64
    var difficulty_rating : float
}
```

### models/src/review.ch

```chemical
package models

import std

public struct ReviewItem {
    var id : std::string
    var learner_id : std::string
    var concept_id : std::string
    var course_id : std::string
    var type : std::string           // "recall", "recognize", "apply", "explain"
    var front : std::string
    var back : std::string
    var difficulty : float           // FSRS difficulty (1-10)
    var stability : float            // FSRS stability (days)
    var retrievability : float       // current recall probability (0-1)
    var next_review : i64            // timestamp
    var last_review : i64
    var reps : int
    var lapses : int
}
```

## Module 3: database/

### database/src/client.ch

This module reuses the dual-backend pattern from `lang/compiled/cars/database/`.

```chemical
package database

import std
import cstd
import sqlite
import http
import json

// DbClient auto-selects SQLite (local) or Turso HTTP (remote)
public struct DbClient {
    var is_remote : bool
    var sqlite_conn : sqlite::Database     // used when is_remote == false
    var turso_endpoint : std::string       // used when is_remote == true
    var turso_token : std::string          // used when is_remote == true
    var cache : std::unordered_map<std::string, CachedResponse>
}

public struct CachedResponse {
    var response : std::string
    var expiry : i64
}

public func make_client(url : std::string, token : std::string) : DbClient {
    var is_remote = url.starts_with("http://") || url.starts_with("https://") || url.starts_with("libsql://")
    if(is_remote) {
        return DbClient {
            is_remote = true,
            turso_endpoint = url.copy(),
            turso_token = token.copy()
        }
    } else {
        var res = sqlite::Database.open(url.to_view(), sqlite::OpenFlag::READWRITE | sqlite::OpenFlag::CREATE)
        var Ok(conn) = res else unreachable
        // Apply WAL mode + pragmas
        conn.execute(std::string_view("PRAGMA journal_mode=WAL"))
        conn.execute(std::string_view("PRAGMA busy_timeout=5000"))
        conn.execute(std::string_view("PRAGMA synchronous=NORMAL"))
        conn.execute(std::string_view("PRAGMA foreign_keys=ON"))
        return DbClient {
            is_remote = false,
            sqlite_conn = conn
        }
    }
}

public func query(db : *mut DbClient, sql : *std::string, out : *mut QueryResult) {
    if(db.is_remote) {
        query_turso(db, sql, out)
    } else {
        query_sqlite(db, sql, out)
    }
}

public func exec(db : *mut DbClient, sql : *std::string) : ExecResult {
    if(db.is_remote) {
        return exec_turso(db, sql)
    } else {
        return exec_sqlite(db, sql)
    }
}
```

### database/src/schema.ch

```chemical
package database

import std

public func init_schema(db : *mut DbClient) {
    var stmts = std.vector<std::string>()
    stmts.push(std::string("CREATE TABLE IF NOT EXISTS learners (id TEXT PRIMARY KEY, email TEXT UNIQUE, name TEXT, created_at INTEGER, settings_json TEXT)"))
    stmts.push(std::string("CREATE TABLE IF NOT EXISTS concept_states (learner_id TEXT, concept_id TEXT, course_id TEXT, status TEXT, attempts INTEGER DEFAULT 0, correct INTEGER DEFAULT 0, streak INTEGER DEFAULT 0, last_studied INTEGER, next_review INTEGER, difficulty_rating REAL DEFAULT 0, PRIMARY KEY (learner_id, concept_id, course_id))"))
    stmts.push(std::string("CREATE TABLE IF NOT EXISTS review_items (id TEXT PRIMARY KEY, learner_id TEXT, concept_id TEXT, course_id TEXT, type TEXT, front TEXT, back TEXT, difficulty REAL DEFAULT 5.0, stability REAL DEFAULT 1.0, retrievability REAL DEFAULT 1.0, next_review INTEGER, last_review INTEGER, reps INTEGER DEFAULT 0, lapses INTEGER DEFAULT 0)"))
    stmts.push(std::string("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, learner_id TEXT, start_time INTEGER, end_time INTEGER, type TEXT, concepts_hit_json TEXT, exercises_attempted INTEGER DEFAULT 0, exercises_correct INTEGER DEFAULT 0, energy_before TEXT, energy_after TEXT)"))

    // Create indexes
    stmts.push(std::string("CREATE INDEX IF NOT EXISTS idx_concept_states_learner ON concept_states(learner_id)"))
    stmts.push(std::string("CREATE INDEX IF NOT EXISTS idx_review_items_learner ON review_items(learner_id)"))
    stmts.push(std::string("CREATE INDEX IF NOT EXISTS idx_review_items_due ON review_items(next_review)"))
    stmts.push(std::string("CREATE INDEX IF NOT EXISTS idx_sessions_learner ON sessions(learner_id)"))

    exec_batch(db, &stmts)
}
```

## Module 4: repository/

### repository/src/courses.ch

```chemical
package repository

import std
import fs
import json
import models

public func load_course(courses_dir : *std::string, course_id : *std::string) : std::Result<models::Course, std::string> {
    // Build path: courses_dir/course_id/manifest.json
    var path = courses_dir.copy()
    path.append_view(std::string_view("/"))
    path.append_string(course_id)
    path.append_view(std::string_view("/manifest.json"))

    var content_res = fs::read_file(path.to_view())
    var Ok(content) = content_res else { return std::Result.Err(std::string("Failed to read manifest")) }

    // Parse JSON
    var json_res = json::parse(content.to_view())
    var Ok(val) = json_res else { return std::Result.Err(std::string("Failed to parse manifest")) }

    // Convert JsonValue to Course struct
    // ... (implementation details depend on json library API)
    return std::Result.Err(std::string("Not implemented"))
}

public func list_courses(courses_dir : *std::string) : std::vector<models::Course> {
    var courses = std::vector<models::Course>()
    // Scan courses_dir for subdirectories with manifest.json
    // ... (implementation)
    return courses
}
```

## Module 5: learning/

### learning/src/fsrs.ch

```chemical
package learning

import std
import models

// FSRS-5 parameters (defaults)
public struct FSRSPrams {
    var w : [21]float     // model weights
}

public func default_params() : FSRSPrams {
    var p = FSRSPrams {}
    // Default weights from FSRS-5 paper
    p.w[0] = 0.4072
    p.w[1] = 1.1870
    p.w[2] = 3.1214
    p.w[3] = 15.4722
    p.w[4] = 7.2112
    p.w[5] = 0.5119
    p.w[6] = 1.0901
    p.w[7] = 0.0064
    p.w[8] = 1.5330
    p.w[9] = 0.1146
    p.w[10] = 1.0174
    p.w[11] = 1.8370
    p.w[12] = 0.1660
    p.w[13] = 0.2004
    p.w[14] = 0.2960
    p.w[15] = 0.7692
    p.w[16] = 1.0125
    p.w[17] = 1.5330
    p.w[18] = 0.3125
    p.w[19] = 0.6823
    p.w[20] = 0.8574
    return p
}

// Rating: Again=1, Hard=2, Good=3, Easy=4
public func next_interval(item : *models::ReviewItem, rating : int, params : *FSRSPrams) : float {
    var d = item.difficulty
    var s = item.stability

    // Compute next stability
    var new_s = next_stability(d, s, rating, params)

    // Compute interval
    var target_r : float = 0.9    // 90% target retention
    var interval = new_s * (9.0 / target_r - 1.0)
    if(interval < 1.0) { interval = 1.0 }

    return interval
}

func next_stability(d : float, s : float, rating : int, params : *FSRSPrams) : float {
    // FSRS stability calculation
    var w = params.w
    if(rating == 1) {
        // Again: reset
        return w[7] * (d ^ (-w[8]))
    }
    // Hard, Good, Easy
    var r = retrievability(s, 0)    // current retrievability
    var gamma = w[14] * (11.0 - d) * (s ^ (-w[15])) * (std::exp(w[16] * (1.0 - r)) - 1.0)
    if(gamma < 0.1) { gamma = 0.1 }
    var new_s = s * (1.0 + gamma * (rating_factor(rating) - 1.0))
    return new_s
}

func rating_factor(rating : int) : float {
    if(rating == 2) { return 1.0 }    // Hard
    if(rating == 3) { return 1.5 }    // Good
    if(rating == 4) { return 2.5 }    // Easy
    return 1.0
}

func retrievability(s : float, days_elapsed : float) : float {
    // R = (1 + t/(9*S))^(-1) (power forgetting curve)
    return 1.0 / (1.0 + days_elapsed / (9.0 * s))
}
```

## Module 6: web/

### web/src/main.ch

```chemical
package web

import std
import server
import core
import repository
import database
import learning
import json

public func main(argc : int, argv : **char) : int {
    var cfg = core::Config::make()
    var port_int = parse_int(cfg.port.to_view())

    var db = database::make_client(cfg.database_url.copy(), cfg.database_token.copy())
    database::init_schema(&raw mut db)

    var srv = server::Server(server::ServerConfig {
        addr = std::string(":") + cfg.port.copy(),
        worker_count = 4u
    })

    // Health check
    srv.router.add("GET", "/api/health", (req, res) => {
        res.set_header_view("Content-Type", std::string_view("application/json"))
        res.write_view(std::string_view("""{"status": "ok"}"""))
    })

    // List courses
    var courses_dir = cfg.courses_dir.copy()
    srv.router.add("GET", "/api/courses", (|&courses_dir|(req, res) => {
        var courses = repository::list_courses(&courses_dir)
        // Serialize to JSON and return
        // ...
    }))

    // Get course detail
    srv.router.add("GET", "/api/courses/:courseId", (|&courses_dir|(req, res) => {
        // Extract courseId from URL params
        // Load course from manifest.json
        // Return JSON
    }))

    // Serve lesson page (pre-rendered HTML)
    var courses_dir2 = cfg.courses_dir.copy()
    srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", (|&courses_dir2|(req, res) => {
        // Extract courseId + conceptId from URL
        // Read courses/{courseId}/output/{conceptId}.html
        // Return HTML file
    }))

    // Static file serving for course assets
    srv.router.add("GET", "/courses/*", (|&courses_dir|(req, res) => {
        // Serve files from courses/*/output/ and courses/*/assets/
    }))

    // Review session endpoints
    srv.router.add("POST", "/api/review/start", (|&db|(req, res) => {
        // Start a review session
        // Return due items
    }))

    srv.router.add("POST", "/api/review/submit", (|&db|(req, res) => {
        // Submit review result
        // Update FSRS state
        // Return next item
    }))

    printf("Underlayer starting on port %d...\n", port_int)
    srv.serve()
    return 0
}

func parse_int(view : std::string_view) : int {
    var val = 0
    for(var i = 0u; i < view.size(); i++) {
        var c = view.get(i)
        if(c >= '0' && c <= '9') { val = val * 10 + (c as int - '0' as int) }
    }
    return val
}
```

## Module 7: content/

### content/src/CourseLoader.ch

```chemical
package content

import std
import fs
import json
import models
import repository

public struct CourseLoader {
    var courses_dir : std::string

    @make
    public func make(courses_dir : std::string) : CourseLoader {
        return CourseLoader { courses_dir = courses_dir.copy() }
    }

    public func load_course(course_id : *std::string) : std::Result<models::Course, std::string> {
        return repository::load_course(&self.courses_dir, course_id)
    }

    public func load_concept_page(course_id : *std::string, concept_id : *std::string) : std::Result<std::string, std::string> {
        // Read pre-rendered HTML from output/ directory
        var path = self.courses_dir.copy()
        path.append_view(std::string_view("/"))
        path.append_string(course_id)
        path.append_view(std::string_view("/output/"))
        path.append_string(concept_id)
        path.append_view(std::string_view(".html"))

        var content_res = fs::read_file(path.to_view())
        var Ok(content) = content_res else { return std::Result.Err(std::string("Concept page not found")) }
        return std::Result.Ok(content)
    }
}
```

## Course File Example: courses/elf/

### courses/elf/chemical.mod

```chemical
application elf_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
```

### courses/elf/src/main.ch

```chemical
import std
import fs
import bytes
import binary_representation
import file_layout

public func main() : int {
    fs::mkdir(std::string_view("output"))

    var bytes_html = bytes::render()
    fs::write_file(std::string_view("output/bytes.html"), bytes_html.to_view())

    var binary_html = binary_representation::render()
    fs::write_file(std::string_view("output/binary-representation.html"), binary_html.to_view())

    var file_layout_html = file_layout::render()
    fs::write_file(std::string_view("output/file-layout.html"), file_layout_html.to_view())

    printf("ELF course pages generated in output/\n")
    return 0
}
```

### courses/elf/src/bytes.ch

```chemical
import page
import html_cbi
import css_cbi
import js_cbi
import components

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // hydration runtime for #universal components
    page.defaultPrepare()            // charset + viewport
    page.injectDefaultComponentsTheme()  // shadcn theme CSS tokens
    page.appendTitle(std::string_view("Bytes and Binary — Underlayer"))

    #html {
        <div class="lesson" data-concept="bytes">
            <header class="lesson-header">
                <h1>Bytes and Binary</h1>
                <div class="lesson-meta">15 min · Core concept</div>
            </header>

            <section class="unit">
                <h2>Why This Matters</h2>
                <p>Every piece of data in a computer — text, images, programs — is stored as bytes.
                   Understanding bytes is the foundation for understanding ELF, PE, or any binary format.</p>
            </section>

            <section class="unit">
                <h2>A Simple Model</h2>
                <p>Think of a byte as a box that can hold one of 256 values (0-255).
                   Each value can be represented as two hexadecimal digits (00-FF).</p>
            </section>

            <section class="unit">
                <h2>The Real Details</h2>
                <p>A byte is 8 bits. Each bit is either 0 or 1.
                   The value of a byte is: b7×128 + b6×64 + ... + b0×1.</p>
                <div class="code-block">
                    <pre>0100 0001 = 65 = 0x41 = 'A'</pre>
                </div>
            </section>

            <section class="unit">
                <h2>Concrete Example</h2>
                <p>The ELF magic number starts with these bytes:</p>
                <div class="hex-dump">
                    <code>7f 45 4c 46 02 01 01 00</code>
                </div>
            </section>

            <section class="unit">
                <h2>Check Your Understanding</h2>
                <div class="quiz" id="quiz-1">
                    <p class="quiz-question">How many distinct values can a single byte represent?</p>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">64</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">128</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, true)">256</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">512</button>
                    <div class="quiz-feedback"></div>
                </div>
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: var(--font-sans); }
        .lesson-header { margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid var(--border); }
        .lesson-meta { color: var(--text-secondary); font-size: 0.875rem; }
        .unit { margin-bottom: 2rem; }
        .unit h2 { font-size: 1.25rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; font-size: 1.1rem; }
        .code-block { background: #f5f5f5; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; }
        .quiz-question { font-weight: 600; margin-bottom: 0.75rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid var(--border); border-radius: 6px; background: var(--surface); cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: var(--primary); background: var(--primary-light); }
        .quiz-option.correct { border-color: var(--success); background: var(--success-light); }
        .quiz-option.wrong { border-color: var(--error); background: var(--error-light); }
    }

    #js {
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) {
                options[i].disabled = true;
                options[i].style.pointerEvents = 'none';
            }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! A byte has 256 possible values (0-255).';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. A byte is 8 bits, and 2^8 = 256.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
```

## Build & Run Commands

```bash
# Build the platform
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Run the platform
./lang/compiled/underlayer/build/underlayer.exe

# Build course pages
cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
    -o lang/compiled/underlayer/courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules

# Generate course HTML
./lang/compiled/underlayer/courses/elf/build/elf-pages.exe

# Verify
curl localhost:9000/api/health
```

## Reusable Components (Universal)

Underlayer builds reusable components using Chemical's `#universal` macro system. These components are shared between the platform pages and course content.

### How Universal Components Work

A universal component has two parts:

1. **CSS style function** — generates scoped CSS via `#css`, returns a hashed class name
2. **`#universal` component** — JSX-like syntax, receives `props`, returns JSX that renders to HTML (SSR) + hydration JS (client)

### Pattern: Defining a Universal Component

```chemical
// components/src/QuizOption.ch

import page
import html_cbi
import css_cbi
import universal_cbi

// Part A: CSS style function
func quiz_option_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: block;
        width: 100%;
        padding: 0.75rem 1rem;
        margin: 0.5rem 0;
        border: 1px solid hsl(var(--border));
        border-radius: 6px;
        background: hsl(var(--surface));
        cursor: pointer;
        text-align: left;
        font-size: 0.95rem;
        transition: all 0.15s;
        &:hover {
            border-color: hsl(var(--primary));
            background: hsl(var(--primary-light));
        }
        &[data-correct="true"] {
            border-color: hsl(var(--success));
            background: hsl(var(--success-light));
        }
        &[data-wrong="true"] {
            border-color: hsl(var(--error));
            background: hsl(var(--error-light));
        }
        &:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
    }
}

// Part B: Universal component
public #universal QuizOption(props) {
    var correct = props.correct || false
    var wrong = props.wrong || false
    var disabled = props.disabled || false
    var classes = (props.className || props.class) || ""

    return <button
        {...props}
        class={classes + " " + ${quiz_option_styles(page)}}
        data-correct={correct ? "true" : "false"}
        data-wrong={wrong ? "true" : "false"}
        disabled={disabled}
        type={props.type || "button"}
        onClick={props.onClick}
    >{props.children}</button>
}
```

### Pattern: Defining a Component Family

Components like Card have multiple sub-components:

```chemical
// components/src/CourseCard.ch

import page
import html_cbi
import css_cbi
import universal_cbi

func course_card_styles(page : &mut HtmlPage) : *char {
    return #css {
        border: 1px solid hsl(var(--border));
        border-radius: 8px;
        overflow: hidden;
        transition: box-shadow 0.2s;
        &:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    }
}

func course_card_body_styles(page : &mut HtmlPage) : *char {
    return #css {
        padding: 1.25rem;
    }
}

func course_card_title_styles(page : &mut HtmlPage) : *char {
    return #css {
        font-size: 1.125rem;
        font-weight: 600;
        margin-bottom: 0.5rem;
        color: hsl(var(--text-primary));
    }
}

func course_card_meta_styles(page : &mut HtmlPage) : *char {
    return #css {
        font-size: 0.875rem;
        color: hsl(var(--text-secondary));
        margin-bottom: 0.75rem;
    }
}

public #universal CourseCard(props) {
    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${course_card_styles(page)}}
    >{props.children}</div>
}

public #universal CourseCardBody(props) {
    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${course_card_body_styles(page)}}
    >{props.children}</div>
}

public #universal CourseCardTitle(props) {
    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${course_card_title_styles(page)}}
    >{props.children}</div>
}

public #universal CourseCardMeta(props) {
    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${course_card_meta_styles(page)}}
    >{props.children}</div>
}
```

### Using Universal Components in Pages

Inside `#html` blocks, reference components by their tag name:

```chemical
import page
import html_cbi
import css_cbi
import components        // imports all universal components
import universal_cbi

public func render_home_page(db : *database::DbClient, courses_dir : *std::string) : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // Initialize universal hydration runtime
    page.defaultPrepare()            // charset + viewport

    #html {
        <div class="container">
            <h1>Underlayer — Learn Things Deeply</h1>

            <div class="grid-3">
                @{/* Loop over courses using Chemical escape */}
                @{var idx : size_t = 0
                var courses = repository::list_courses(courses_dir)
                while(idx < courses.size()) {
                    var course = courses.get_ptr(idx)
                    idx = idx + 1
                    #html {
                        <CourseCard>
                            <CourseCardBody>
                                <CourseCardTitle>{course.title}</CourseCardTitle>
                                <CourseCardMeta>{course.description}</CourseCardMeta>
                                <Button variant="outline" size="sm">
                                    <Link href={std::string("/courses/") + course.id.copy()}>Start Learning</Link>
                                </Button>
                            </CourseCardBody>
                        </CourseCard>
                    }
                }}
            </div>
        </div>
    }

    #css {
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.5rem; }
    }

    return page.toString()
}
```

### Course-Specific Universal Components

Courses can define their own components. Create a `components/` directory in the course:

```
courses/elf/
├── chemical.mod
├── src/
│   ├── main.ch
│   ├── bytes.ch
│   └── components/
│       ├── HexViewer.ch       (interactive hex dump)
│       ├── ElfDiagram.ch     (clickable ELF layout)
│       └── QuizFeedback.ch   (quiz result display)
```

Course chemical.mod imports:

```chemical
application elf_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components          // platform components (Button, Card, etc.)
import "./components"      // course-specific components
```

Example course-specific component:

```chemical
// courses/elf/src/components/HexViewer.ch

import page
import html_cbi
import css_cbi
import universal_cbi

func hex_viewer_styles(page : &mut HtmlPage) : *char {
    return #css {
        background: #1e1e1e;
        color: #d4d4d4;
        padding: 1rem;
        border-radius: 6px;
        font-family: ui-monospace, monospace;
        font-size: 0.95rem;
        line-height: 1.6;
        overflow-x: auto;
        .hex-byte {
            display: inline-block;
            width: 2ch;
            margin-right: 0.5ch;
            cursor: pointer;
            border-radius: 2px;
            &:hover { background: rgba(59, 130, 246, 0.3); }
            &.highlighted { background: rgba(59, 130, 246, 0.5); }
        }
        .hex-label {
            display: block;
            margin-top: 0.5rem;
            font-size: 0.8rem;
            color: #9ca3af;
        }
    }
}

public #universal HexViewer(props) {
    var data = props.data || ""
    var highlights = props.highlights || ""
    var base_address = props.base_address || "0x00000000"

    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${hex_viewer_styles(page)}}
        data-base-address={base_address}
    >{props.children}
        <span class="hex-label">{base_address}</span>
    </div>
}
```

Using the course-specific component:

```chemical
// courses/elf/src/bytes.ch

import page
import html_cbi
import css_cbi
import js_cbi
import components
import "./components/HexViewer"

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()
    page.appendTitle(std::string_view("Bytes and Binary — Underlayer"))

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <p>The ELF magic number:</p>
            <HexViewer data="7f 45 4c 46 02 01 01 00" base_address="0x00000000">
            </HexViewer>
        </div>
    }

    return page.toString()
}
```

## Platform Theme (Shared Layout)

The platform has a shared theme module that provides header, footer, and global styles:

```chemical
// theme/src/main.ch

import page
import html_cbi
import css_cbi
import components

public func apply_theme(page : *mut HtmlPage) {
    #css {
        :root {
            --font-sans: system-ui, -apple-system, 'Segoe UI', sans-serif;
            --font-mono: ui-monospace, 'Cascadia Code', monospace;
            --bg: #ffffff;
            --surface: #f8f9fa;
            --text-primary: #111827;
            --text-secondary: #6b7280;
            --border: #e5e7eb;
            --primary: #2563eb;
            --primary-light: #eff6ff;
            --success: #059669;
            --success-light: #ecfdf5;
            --error: #dc2626;
            --error-light: #fef2f2;
        }
        * { box-sizing: border-box; margin: 0; }
        body { font-family: var(--font-sans); background: var(--bg); color: var(--text-primary); }
        a { color: var(--primary); text-decoration: none; }
        a:hover { text-decoration: underline; }
    }
}

public func render_header(page : *mut HtmlPage, active : *char) {
    #html {
        <header class="site-header">
            <div class="container" style="display:flex;align-items:center;justify-content:space-between;padding:1rem 2rem">
                <Link href="/"><H3>Underlayer</H3></Link>
                <nav>
                    <Link href="/courses">Courses</Link>
                    <Link href="/dashboard">Dashboard</Link>
                </nav>
            </div>
        </header>
    }
}

public func render_footer(page : *mut HtmlPage) {
    #html {
        <footer class="site-footer">
            <div class="container" style="padding:2rem;text-align:center;color:var(--text-secondary)">
                <Separator />
                <Text>Underlayer — Learn Things Deeply</Text>
            </div>
        </footer>
    }
}
```

## Key Implementation Learnings

### 1. `page.defaultUniversalSetup()` Is Required

Every page that uses universal components MUST call `page.defaultUniversalSetup()` before any `#html` blocks. This injects the hydration runtime JS that makes client-side interactivity work.

### 2. `@{}` Escape for Dynamic Content

Inside `#html` blocks, use `@{Chemical code}` to exit JSX and write loops/conditionals. Re-enter JSX with nested `#html { }` blocks:

```chemical
#html {
    <div class="grid">
        @{var idx : size_t = 0
        while(idx < items.size()) {
            var item = items.get_ptr(idx)
            idx = idx + 1
            #html {
                <Card><CardBody>
                    <CardTitle>{item.title}</CardTitle>
                </CardBody></Card>
            }
        }}
    </div>
}
```

### 3. Lambda Capture Syntax for Route Handlers

Route handlers that need database access use the `|&var|` capture syntax:

```chemical
var db = database::make_client(...)
var courses_dir = std::string("./courses")

srv.router.add("GET", "/api/courses", (|&db, &courses_dir|(req, res) => {
    // db and courses_dir are captured by reference
    var courses = repository::list_courses(&courses_dir)
    // ...
}))
```

### 4. CSS Class Name Hashing

The `#css` macro automatically hashes class names to prevent collisions. When you write:

```chemical
func my_styles(page : *mut HtmlPage) : *char {
    return #css {
        .container { max-width: 800px; }
    }
}
```

The macro returns a hashed class name like `"chx-a1b2c3"`. Use it in `#html` via `${my_styles(page)}`:

```chemical
#html {
    <div class={${my_styles(page)}}>
        ...
    </div>
}
```

### 5. Course Pages vs Platform Pages

| Aspect | Course Pages | Platform Pages |
|--------|-------------|----------------|
| **When compiled** | Build time (separate binary) | Runtime (server binary) |
| **Output** | Static HTML/CSS/JS files | Dynamic HTTP responses |
| **Database** | No (content is static) | Yes (learner state, reviews) |
| **Universal components** | Can use platform components | Defines platform components |
| **Interactivity** | Client-side JS only | Client-side JS + server API |

### 6. Module Dependency Direction

```
Platform modules:
  theme/ → components (universal components)
  web/ → theme/, content/, learning/, repository/
  content/ → models/, repository/
  learning/ → models/, repository/
  repository/ → models/, database/
  database/ → sqlite (external)

Course modules:
  courses/elf/src/components/ → page, html_cbi, css_cbi, universal_cbi
  courses/elf/src/*.ch → courses/elf/src/components/, components (platform)
```

### 7. Build Two Binaries

The platform and courses are built separately:

```bash
# Platform binary (server)
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Course page generator (one per course)
cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
    -o courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules
```

The platform binary serves pre-rendered course pages. The course binary generates them.
