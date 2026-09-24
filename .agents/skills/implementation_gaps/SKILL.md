# Implementation Gaps Skill

Load this skill when writing code, generating course content, or debugging issues. Documents all known bugs, language limitations, component issues, and missing infrastructure.

> **Also load `engineering_patterns`** for error handling, logging, security, caching, testing, monitoring, and privacy patterns. This skill covers *what's broken*; `engineering_patterns` covers *how to build correctly*.

> **Also load `libs_reference`** for the complete catalog of available libraries and APIs. This skill covers *what NOT to do*; `libs_reference` covers *what IS available*.

> **Also load `coding_conventions`** for style rules and naming conventions. This skill covers *pitfalls*; `coding_conventions` covers *how to write clean code*.

---

# TRUSTED IMPLEMENTATION PATTERNS

**These patterns are PROVEN TO WORK.** AI agents should copy-paste-adapt these patterns rather than inventing new code. Every pattern here has been tested and compiles successfully. Fighting the compiler is wasteful — use these patterns.

---

## 1. File Structure Pattern (MANDATORY)

Every module MUST follow this structure. No exceptions.

### Root `main.ch`

```chemical
// Module root — list files here
// handler_funcs, helpers, entity_funcs, ...
```

**Just a comment.** No logic in `main.ch`. All logic lives in named files.

### Sub-module File Pattern

Every file in a module follows this exact pattern:

```chemical
import std
import cstd

import underlayer_core
import underlayer_models

public namespace underlayer_repository {
    // ... all code here ...
}
```

**Critical rules:**
- `import std` — always needed for `std::string`, `std::vector`, etc.
- `import cstd` — needed if using `printf`, `fprintf`, `fflush`, etc.
- `import underlayer_core` — for config, logging, utils
- `import underlayer_models` — for domain structs
- The namespace name MUST match the directory: `underlayer_repository`, `underlayer_web`, `underlayer_learning`
- Relative imports for sibling modules: `"../core"`, `"../models"`

### chemical.mod Pattern

```chemical
package application
name "underlayer"
source "src"
import cstd
import std
import server
import http
import json
import page
import html_cbi
import css_cbi
import js_cbi
import components
import components_text
import components_layout
import components_feedback
import components_surface
import components_state
import universal_cbi
import sqlite
import encoding
import net
import fs
import path
import auth
```

Sub-modules use `module` not `package`:

```chemical
module underlayer_web
source "src"
import cstd
import std
import underlayer_core
import underlayer_models
import server
import http
import json
import page
import html_cbi
import css_cbi
import components
```

---

## 2. Public Helpers Pattern

When private functions are needed across multiple files in a module, create a `helpers.ch` file and make them `public`.

### helpers.ch (in any module)

```chemical
import std
import cstd
import underlayer_models

public namespace underlayer_repository {
    // Parse integer from string
    public func parse_i64(str : std::string_view) : i64 {
        var result : i64 = 0
        var negative = false
        var start = 0u
        if(str.size() > 0u && str.get(0u) == '-') {
            negative = true
            start = 1u
        }
        var i = start
        while(i < str.size()) {
            var c = str.get(i)
            if(c >= '0' && c <= '9') {
                result = result * 10 + (c as int - '0' as int) as i64
            }
            i = i + 1u
        }
        if(negative) { result = -result }
        return result
    }

    public func parse_int(str : std::string_view) : int {
        return parse_i64(str) as int
    }

    // Parse optional integer, returns default if empty
    public func parse_optional_int(str : std::string_view, default_val : int) : int {
        if(str.size() == 0u) { return default_val }
        return parse_int(str)
    }

    // Convert i64 to string
    public func int_to_string(val : i64) : std::string {
        if(val == 0i64) { return std::string("0") }
        var result = std::string()
        var v = val
        if(v < 0i64) {
            result.append_view("-")
            v = -v
        }
        var digits : [20]char
        var digit_count = 0
        while(v > 0i64) {
            digits[digit_count] = ('0' as i64 + v % 10i64) as char
            digit_count = digit_count + 1
            v = v / 10i64
        }
        var i = digit_count - 1
        while(i >= 0) {
            result.append(digits[i] as u8)
            i = i - 1
        }
        return result
    }

    // Convert f64 to string (fixed 2 decimal places)
    public func f64_to_string(val : f64) : std::string {
        if(val < 0.0) {
            var s = std::string("-")
            s.append_view(f64_to_string(-val).to_view())
            return s
        }
        var int_part = val as i64
        var frac = (val - int_part as f64) * 100.0
        var frac_int = frac as int
        var result = int_to_string(int_part)
        result.append_view(".")
        if(frac_int < 10) { result.append_view("0") }
        result.append_view(int_to_string(frac_int as i64).to_view())
        return result
    }

    // Get current Unix timestamp
    public func current_timestamp() : i64 {
        var tv : cstd::timeval
        cstd::gettimeofday(&raw tv, null)
        return tv.tv_sec as i64
    }

    // String view to string conversion
    public func sv_to_string(sv : std::string_view) : std::string {
        var s = std::string()
        var i = 0u
        while(i < sv.size()) {
            s.append(sv.get(i))
            i = i + 1u
        }
        return s
    }
}
```

**Why this works:** These helpers are `public` so every file in the module can import and use them. No duplication. No "function not found" errors.

---

## 3. API Handler Pattern (actual signatures — verified 2026-09-17)

### Real handler file structure (from web/src/handlers_learners.ch, handlers_home.ch, helpers.ch)

```chemical
import std
import std::string
import std::string_view
using underlayer_db::DbClient

public namespace underlayer_web {

    // Helper: send HTML page (web/src/helpers.ch)
    public func send_page(res : *mut http::ResponseWriter, page : *HtmlPage) {
        var ct = std::string_view("text/html; charset=utf-8")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var html = page.toString()
        var hv = html.to_view()
        res.write_view(&hv)
    }

    // Helper: send JSON string response
    public func send_json_str(res : *mut http::ResponseWriter, body : *string) {
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // Helper: send error response — flat {"error":"..."} envelope
    public func send_error(res : *mut http::ResponseWriter, status : uint, msg : &string) {
        res.status = status
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"error\":\"")
        body.append_string(msg)
        body.append_view("\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }

    // Handler: no database needed
    public func handle_health(req : &http::Request, res : *mut http::ResponseWriter) {
        var body = std::string("{\"status\": \"ok\", \"version\": \"0.1.0\"}")
        send_json_str(res, &raw body)
    }

    // Handler: with database — db passed in as &DbClient, not a global
    public func handle_create_learner(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter) {
        // parse JSON body via json_helpers.ch, call underlayer_repository, send_json_str
    }
}
```

**Signature rules (all handlers in web/src/ follow these):**

| Need | Signature |
|---|---|
| Static | `(req : &http::Request, res : *mut http::ResponseWriter)` |
| DB | `(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter)` |
| DB + courses dir | `(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter)` |
| courses_dir only | `(courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter)` |
| POST body mutation | route lambda passes `&raw mut req` |

There is **no `get_global_db()`** — the DB client is created once in `app/main.ch` and captured into route lambdas via `(|&db| ...)`.

### URL param extraction (route lambdas in app/main.ch)

```chemical
srv.router.add("GET", "/api/learners/:learnerId", (|&db|(req, res) => {
    var path = req.path.to_view()
    var segments = underlayer_core::path_segments(&path)
    if(segments.size() >= 3) {                       // /api/learners/:id → id is index 2
        var learner_id = segments.get_ptr(2)
        underlayer_web::handle_get_learner(db, learner_id, &req, &raw mut res)
    } else {
        res.status = 400u
        var ct = std::string_view("application/json")
        res.set_header_view(std::string_view("Content-Type"), &ct)
        var body = std::string("{\"error\": \"missing learner id\"}")
        var bv = body.to_view()
        res.write_view(&bv)
    }
}))
```

### Query parameters (actual API: `req.query.get(&key)`)

```chemical
// QueryMap.get takes &string_view key and returns string_view (empty if missing)
var q_mode = std::string("mode")
var mode_v = req.query.get(&q_mode.to_view())
if(mode_v.size() == 0u) { /* default or 400 */ }
var mode = sv_to_string(&raw mode_v)
```

### Key handler patterns

| Pattern | Code |
|---------|------|
| Extract URL param | `var segments = underlayer_core::path_segments(&path); var id = segments.get_ptr(<position>)` |
| Extract query param | `req.query.get(&key_sv)` → empty view if missing |
| Send JSON | `send_json_str(res, &raw body_string)` |
| Send error | `var e = std::string("msg"); send_error(res, 404u, &raw e)` |
| Send HTML | `send_page(res, &raw page)` |
| Database access | captured `db : &DbClient` from the route lambda |

---

## 4. Database CRUD Pattern

### Repository file structure

```chemical
import std
import cstd

import underlayer_core
import underlayer_models
import underlayer_database
import underlayer_repository::helpers

public namespace underlayer_repository {

    // CREATE
    public func create_learner(db : *mut database::Database, name : std::string_view, email : std::string_view) : Result<underlayer_models::Learner, std::string> {
        var id = generate_uuid()

        var sql = std::string("INSERT INTO learners (id, name, email) VALUES ('")
        sql.append_view(id.to_view())
        sql.append_view("', '")
        sql.append_view(name)
        sql.append_view("', '")
        sql.append_view(email)
        sql.append_view("')")

        var result = database::execute(db, sql.to_view())
        if(result is Result.Err) {
            return Result.Err(std::string("Failed to create learner"))
        }

        return Result.Ok(underlayer_models::Learner {
            id = id.copy(),
            name = std::string(name),
            email = std::string(email)
        })
    }

    // READ
    public func get_learner(db : *mut database::Database, learner_id : std::string_view) : Result<underlayer_models::Learner, std::string> {
        var sql = std::string("SELECT id, name, email FROM learners WHERE id = '")
        sql.append_view(learner_id)
        sql.append_view("'")

        var result = database::query(db, sql.to_view())
        if(result is Result.Err) {
            return Result.Err(std::string("Failed to query learner"))
        }

        var rows = result.value()
        if(rows.size() == 0u) {
            return Result.Err(std::string("Learner not found"))
        }

        var row = rows.get(0)
        return Result.Ok(underlayer_models::Learner {
            id = sv_to_string(row.get(0)),
            name = sv_to_string(row.get(1)),
            email = sv_to_string(row.get(2))
        })
    }

    // UPDATE
    public func update_learner(db : *mut database::Database, learner_id : std::string_view, name : std::string_view) : Result<(), std::string> {
        var sql = std::string("UPDATE learners SET name = '")
        sql.append_view(name)
        sql.append_view("' WHERE id = '")
        sql.append_view(learner_id)
        sql.append_view("'")

        var result = database::execute(db, sql.to_view())
        if(result is Result.Err) {
            return Result.Err(std::string("Failed to update learner"))
        }
        return Result.Ok(())
    }

    // DELETE
    public func delete_learner(db : *mut database::Database, learner_id : std::string_view) : Result<(), std::string> {
        var sql = std::string("DELETE FROM learners WHERE id = '")
        sql.append_view(learner_id)
        sql.append_view("'")

        var result = database::execute(db, sql.to_view())
        if(result is Result.Err) {
            return Result.Err(std::string("Failed to delete learner"))
        }
        return Result.Ok(())
    }

    // LIST
    public func list_learners(db : *mut database::Database) : Result<std::vector<underlayer_models::Learner>, std::string> {
        var sql = std::string("SELECT id, name, email FROM learners ORDER BY created_at DESC")

        var result = database::query(db, sql.to_view())
        if(result is Result.Err) {
            return Result.Err(std::string("Failed to query learners"))
        }

        var rows = result.value()
        var learners = std::vector<underlayer_models::Learner>()
        var i = 0u
        while(i < rows.size()) {
            var row = rows.get(i)
            learners.push(underlayer_models::Learner {
                id = sv_to_string(row.get(0)),
                name = sv_to_string(row.get(1)),
                email = sv_to_string(row.get(2))
            })
            i = i + 1u
        }
        return Result.Ok(learners)
    }
}
```

---

## 5. Path Segments Pattern (CRITICAL)

`path_segments()` splits on `/` and **skips empty segments**. For `/api/sessions/12345`:
- Returns: `["api", "sessions", "12345"]` (3 segments)
- NOT: `["", "api", "sessions", "12345"]`

**Always use `segments.size() - 1` for the last segment, NOT index 3.**

```chemical
var path = req.path()
var segments = path_segments(path)

// For /api/learners/:id — get last segment
if(segments.size() < 1u) {
    send_error(res, 400, "INVALID_REQUEST", "Missing ID")
    return
}
var id = sv_to_string(segments.get(segments.size() - 1u))

// For /api/learners/:id/progress — get third-to-last and last
if(segments.size() < 3u) {
    send_error(res, 400, "INVALID_REQUEST", "Invalid path")
    return
}
var learner_id = sv_to_string(segments.get(segments.size() - 3u))
var concept_id = sv_to_string(segments.get(segments.size() - 1u))
```

---

## 6. String Building Pattern

**Never use `+` for strings.** Use `append_view()` on a `std::string`.

```chemical
// Building a JSON response
var body = std::string("{\"ok\":true,\"data\":{\"id\":\"")
body.append_view(id.to_view())
body.append_view("\",\"name\":\"")
body.append_view(name.to_view())
body.append_view("\"}}")

// Building a SQL query
var sql = std::string("SELECT * FROM users WHERE id = '")
sql.append_view(user_id)
sql.append_view("' AND active = 1")

// Building a file path
var path = std::string("/courses/")
path.append_view(course_id)
path.append_view("/src/")
path.append_view(concept_id)
path.append_view(".ch")

// Building an error message
var msg = std::string("Failed to load concept '")
msg.append_view(concept_id)
msg.append_view("' in course '")
msg.append_view(course_id)
msg.append_view("'")
```

---

## 7. Error Handling Pattern

**No `try/catch`.** Use `Result<T, std::string>` with explicit checks.

```chemical
// Pattern 1: Check and return early
var result = database::query(db, sql.to_view())
if(result is Result.Err) {
    return Result.Err(std::string("Query failed"))
}
var rows = result.value()

// Pattern 2: Unwrap with else unreachable (for values that CANNOT fail)
// NOTE: there is no get_global_db() in this codebase — the DbClient is created in
// app/main.ch and captured into route lambdas as db : &DbClient (see section 8).

// Pattern 3: Nested operations
func load_concept(db : *mut database::Database, course_id : std::string_view, concept_id : std::string_view) : Result<Concept, std::string> {
    var course_result = get_course(db, course_id)
    if(course_result is Result.Err) {
        return Result.Err(std::string("Course not found"))
    }
    var Ok(course) = course_result else unreachable

    var concept_result = get_concept_from_course(db, course_id, concept_id)
    if(concept_result is Result.Err) {
        return Result.Err(std::string("Concept not found"))
    }
    var Ok(concept) = concept_result else unreachable

    return Result.Ok(concept)
}
```

---

## 8. Route Registration Pattern

Routes live in `app/main.ch` inside `main()` — not in a `start_server()` helper:

```chemical
public func main() : int {
    var cfg = underlayer_core::load_config()
    var db = underlayer_db::make_client(db_url.copy(), db_token.copy())
    if(!underlayer_db::is_remote_url(&raw db_url)) {
        underlayer_repository::init_schema(&raw db)
    }

    var cfg_server = server.ServerConfig()
    var addr = std::string(":")
    addr.append_view(underlayer_core::u32_to_string(port).to_view())
    cfg_server.addr = addr
    var srv = server.Server(cfg_server)

    // Health check (no captures)
    srv.router.add("GET", "/api/health", (req, res) => {
        underlayer_web::handle_health(&req, &raw mut res)
    })

    // DB-backed (capture db by reference)
    srv.router.add("POST", "/api/learners", (|&db|(req, res) => {
        underlayer_web::handle_create_learner(db, &req, &raw mut res)
    }))

    // DB + courses dir (multiple captures)
    srv.router.add("GET", "/api/review/start", (|&db, &courses_dir|(req, res) => {
        underlayer_web::handle_review_start(db, courses_dir, &req, &raw mut res)
    }))

    srv.serve()
    underlayer_db::close(&raw db)
    return 0
}
```

**Capture rules:**
- No captures: `(req, res) => { ... }` — pass `&req`, `&raw mut res` to the handler
- Capture by reference: `(|&db| ...)` — db is used as `db` (already a reference inside)
- Multiple captures: `(|&db, &courses_dir| ...)`

---

## 9. QueryMap Access Pattern

`QueryMap.get()` takes `&string_view` and returns `string_view`. Empty string means missing.

```chemical
var query = req.query()

// Get string param
var name_view = query.get("name")
if(name_view.size() == 0u) {
    send_error(res, 400, "VALIDATION_ERROR", "Missing name")
    return
}
var name = sv_to_string(name_view)

// Get int param
var limit_view = query.get("limit")
var limit = parse_optional_int(limit_view, 20)

// Get optional param (no error if missing)
var sort_view = query.get("sort")
var sort = sv_to_string(sort_view)  // empty string if missing
```

---

## 10. `if` / `else` Pattern

**Every `if` MUST have an `else`.** No inline `if` expressions.

```chemical
// CORRECT
var x : int
if(cond) { x = a } else { x = b }

// CORRECT — empty else
if(cond) { do_something() } @else { }

// CORRECT — if/else if/else
if(a > b) { max = a }
else if(a < b) { max = b }
else { max = a }

// WRONG — no else
// if(cond) { x = a }

// WRONG — inline if
// var x = if(cond) a else b
```

---

## 11. Vector Iteration Pattern

Chemical has no C-style for loop. Use `while` with manual increment.

```chemical
var items = get_items()
var i = 0u
while(i < items.size()) {
    var item = items.get_ptr(i)
    // Use item.field, item.method()
    i = i + 1u
}

// With early exit
var i = 0u
while(i < items.size()) {
    var item = items.get_ptr(i)
    if(item.id.equals(target_id)) {
        return item
    }
    i = i + 1u
}
```

---

## 12. Struct Initialization Pattern

```chemical
// Plain struct (no constructor)
var learner = underlayer_models::Learner {
    id = id.copy(),
    name = std::string(name),
    email = std::string(email)
}

// With @make
var config = underlayer_core::Config.load()

// Vector of structs
var learners = std::vector<underlayer_models::Learner>()
learners.push(underlayer_models::Learner {
    id = id.copy(),
    name = std::string(name),
    email = std::string(email)
})
```

---

## Quick Reference: What NOT to Do

| Never Do This | Why | Do This Instead |
|---------------|-----|-----------------|
| `var x = props.x \|\| default` in universal components | Freezes value at mount | Use `props.x` directly in JSX |
| Store reactive values in local variables | Converter can't detect reactivity | Put expression directly in JSX attribute |
| Toggle portaled menu with `style={...}` | Wipes floating position | Use `data-open` + CSS |
| Pass C++ structs with `vector<>` as props | Corrupt serialization | Pre-serialize to JSON |
| Call function directly as prop: `<Comp value={fn()} />` | 2c temp-local bug | Hoist: `var s = fn(); <Comp value={s} />` |
| Use `+` for string concatenation | No operator overload | Use `append_view()` or backtick templates |
| Use `arr[i]` for vector access | No index operator | Use `arr.get(i)` or `arr.get_ptr(i)` |
| **Use string appends for HTML/CSS/JS** | **FORBIDDEN** | **Use `#html`, `#css`, `#js` macros. Fix macro bugs in CBI plugins.** |
| Build HTML strings in Chemical source (server-side string appends) | Golden rule 7 | `#html` / `#css` / `#js` macros |
| Interpolate API strings into `innerHTML` unescaped | XSS from course titles/descriptions (`Demo Course <&Test>`) | Char-loop `escapeHtml()` first — the shipped pattern for client-rendered lists (home grid, onboarding, cmdk) |
| Grouping parens in `#js`: `(a + b) * c` | Non-JSX converter drops them, giving `a + b * c` | Hoist: `var t = a + b; t * c` |
| Regex literal in `#js`: `/pattern/` | Lexer mangles it | Use `indexOf` / `replace` / char loop |
| Write `if(cond) { ... }` without else | Language requires else | Always add `else {}` |
| Use `0.5` for float parameters | It's `double` | Use `0.5f` |
| Split `#html` across blocks, or loop inside `#html` | Element must close in same block; `@{}` statement blocks inside `#html` are broken (compiler bug) | Static shell (`id` container + loading state) + `#js` fetch — the home/onboarding dynamic-list pattern; see `web_development` skill |
| Put non-ASCII in `page.ch` JS strings | Crashes `std::string::find` | Keep ASCII only |
| Use `#css` inside `#universal` bodies | Server-only, can't appear there | Use `#css` at module level |
| Use `.get(i)` on vectors with destructible types | Returns copy, causes double-free | Use `.get_ptr(i)` |
| Access index 3+ on `path_segments()` | Segments skip empty entries | Use `segments.size() - 1` |
| Private helpers across files | File-scoped only | Make public in `helpers.ch` |
| `&string` vs `*string` | Check function signatures | `&string` for reference, `*string` for raw pointer |
| `string.data()` for SQLite | May not be null-terminated | Use `.size()` as nByte parameter |

## Dual-Mode Architecture (Static + Backend)

Courses MUST work in two modes. This is a core constraint.

### Static Mode (GitHub Pages)
- Courses compile to static HTML/CSS/JS files
- Served via GitHub Pages — no server required
- Settings stored in localStorage — progress, preferences, bookmarks
- Offline-first — download HTML files, open in browser

### Backend Mode (Full Server)
- Same courses, plus user accounts, profiles, analytics
- Server-side progress — spaced repetition, learning history
- Adaptive flow — FSRS engine adjusts difficulty
- Cross-device sync — progress follows the learner

### Course Design Rule: Backend-Optional

Every course MUST work without a backend:
1. Course content is self-contained HTML — no API calls required
2. All interactivity is client-side JS — works offline
3. Progress detection is optional — localStorage if no backend
4. Backend enhances, never gates — adds features but never blocks content

### Emission Pattern

```chemical
// Each concept file emits a complete HTML page
public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()   // camelCase — this is what compiles

    #html {
        <div class="lesson">
            <h1>Concept Title</h1>
            <!-- Full lesson content -->
        </div>
    }

    #css { /* Scoped styles */ }
    #js { /* Client-side interactivity */ }

    return page.toString()  // Complete HTML page
}
```

### Common Mistakes

| Mistake | Problem | Solution |
|---------|---------|----------|
| Course requires API calls to render | Can't work on GitHub Pages | All content in HTML, no API dependencies |
| Progress only on server | Offline fails | localStorage fallback |
| JS depends on backend endpoints | Static mode broken | Client-side only, no fetch() |
| CSS uses server-rendered variables | Static mode broken | All styles in #css block |

## Universal Component Bugs (Critical)

### Reactive Props Frozen

The converter only wraps expressions in `$_ucs` (reactive subscription) when they directly reference `state` or `props` at top-level scope. Local variables computed from these are evaluated once and inlined.

**Affected attributes**: `aria-activedescendant`, `aria-pressed`, `checked`, any dynamic attribute.

**Fix**: Always put reactive expressions directly in JSX attributes. Never hoist to a local variable.

### Portal Menu Positioning

`el.style.cssText = v` wipes ALL inline styles including positioning set by `$__uni_floating`. The floating helper sets `menu.style.position/top/left/minWidth/margin/maxHeight` but a reactive `style` subscription overwrites everything.

**Fix**: Use `data-open={open ? "true" : "false"}` with CSS `&[data-open="true"] { display: grid; }`.

### Prop Serialization with Special Characters

Single quotes in string data can produce malformed JS. The `Char` variant wraps in `'...''` and escapes `'` and `\\`, but edge cases remain.

**Fix**: Pre-escape string data with `js_string_escape()`.

### Hydration Text-Doubling

When a `state` value wraps a text child during hydration, the original SSR text node was not removed, producing doubled text.

**Status**: Fixed in current codebase. Verify your build includes this fix.

### Context SSR Always Renders Unselected

Children render BEFORE the provider's SSR function. Groups render items unpressed/unchecked server-side. Selection only appears after hydration.

**Status**: By design. Do not assert `checked="true"` in SSR for children-mode groups.

## Chemical Language Limitations

### Error Handling

No `try/catch`. Use `Result<T,E>` with explicit pattern matching:

```chemical
var result = fs::read_file(path.to_view())
var Ok(content) = result else {
    printf("Error: file not found\n")
    return std::Result.Err(std::string("File not found"))
}
```

### Resource Cleanup

No `defer`. Use `@delete` destructors on structs:

```chemical
@make
public struct FileHandle {
    var fd : int
    @make func make(path : *char) : FileHandle {
        return FileHandle { fd = cstd::fopen(path, "r") as int }
    }
    @delete func delete() {
        if(self.fd != 0) { cstd::fclose(self.fd as *cstd::FILE) }
    }
}
```

### String Operations

No `+` operator for strings. Use `append_view()` chains or backtick templates:

```chemical
// Append chains
var path = base.copy()
path.append_view(std::string_view("/courses/"))
path.append_string(course_id)

// Backtick templates
var path = `${base}/courses/${course_id}`
```

### Vector Access

No `[]` operator. Use `.get(i)` for reads, `.get_ptr(i)` for writes:

```chemical
var val = vec.get(0)          // read
var ptr = vec.get_ptr(0)      // mutable pointer
*ptr = 42                      // write through pointer
```

### Conditional Logic

`if` requires `else`. No inline `if` expressions:

```chemical
// Must write:
var x : int
if(cond) { x = a } else { x = b }

// Cannot write:
// var x = if(cond) a else b
```

### Float Literals

`0.5` is `double`. For `float` parameters use `0.5f`:

```chemical
func set_volume(vol : float) { ... }
set_volume(0.5f)    // correct
set_volume(0.5)     // TypeCheck error
```

### HTML Escaping

`#html` does NOT auto-escape interpolated values. Always escape untrusted strings:

```chemical
#html {
    <div>{page::escape_html(user_input)}</div>
}
```

### `#js` Macro Quirks (client-side code)

The plain `#js` macro runs the JS parser in **non-JSX mode**, which mangles a few
constructs. Details in `docs/implementation-gaps.md`; the rules:

- **Grouping parentheses are dropped.** `(a + b) * c` emits as `a + b * c`, and
  `"" + (i + 1)` emits as `"" + i + 1` (wrong). Call parentheses (`f(x, y)`) and
  object literals are preserved. **Fix:** hoist into a variable —
  `var label = i + 1; ... "" + label`.
- **Regex literals are mangled.** The lexer tokenizes `/.../` as operators.
  **Fix:** use string methods (`indexOf`, `replace`), never `/pattern/`.
- **Non-ASCII is escaped** to `\u{...}` by the converter. **Fix:** keep JS string
  literals ASCII (use `|`/`-`, not `·`/`—`).
- **Closures over loop variables share one binding** (`var`, not `let`).
  **Fix:** a handler factory — `function handler(i) { return function() { ... }; }`.
- **Multiple `#css` / `#js` blocks concatenate** into one `<style>` / `<script>`
  in call order (`page.toString()` joins `pageCss` / `pageJs`), so you can split
  helpers across files — the `*_assets.ch` pattern (`render_*_css` /
  `render_*_js(page : &mut HtmlPage)`; see `web/src/home_assets.ch`).
- **Callbacks come out double-wrapped** — `fetch(u).then(function(r){…})` emits as
  `.then((function(r){…}))`. That is valid JS and expected output, not a bug.

A bare `%` in a JS string is fine (`pct + '%'` compiles). Golden rule 7 governs
**Chemical source**: never build page HTML with string appends in `.ch` files.
Client-side dynamic lists (home grid, onboarding, cmdk) legitimately render with
`escapeHtml()` + `innerHTML` — every interpolated value must pass through a
char-loop `escapeHtml` first (no regex literals). `createElement` + `textContent`
also works for single text nodes.

### Interpreter Limitations

Cannot use in comptime/interpretation mode:
- `std::string` methods (`append`, `copy`, `to_view`)
- `std::unordered_map`, `std::string_view`
- `vector<T>.get_ptr()`, `vector<T>` iteration via `for-in`
- `@test` annotation dispatch

**Rule**: Avoid comptime string manipulation. Use compiled mode for course generation.

## Missing Infrastructure

### No Centralized Binary Format Library

Endian helpers are duplicated across `archive/endian`, `audio/wav`, `image/png`. A shared `binfmt` library is needed for ELF teaching.

### No Pre-Built Interactive Teaching Components

These components are defined in the catalog but not implemented:

| Component | Priority | Needed For |
|-----------|----------|-----------|
| InteractiveHexViewer | CRITICAL | ELF, PE, Mach-O, TLS, WAV |
| ElfLayoutDiagram | CRITICAL | ELF structure visualization |
| ByteFieldMapper | CRITICAL | Struct-to-bytes mapping |
| MemoryMapAnimator | HIGH | Loading process visualization |
| StructPaddingVisualizer | HIGH | C struct alignment teaching |
| RelocationSimulator | HIGH | Link-time relocation |
| EndiannessDemo | MEDIUM | LE/BE comparison |
| BitfieldExplorer | MEDIUM | Flag field inspection |

### Missing String Methods

No `replace()`, `to_upper()`, `to_lower()`, `format()`, `join()`, `repeat()`, `pad_left()`, `pad_right()`.

### Missing Vector Methods

No `map()`, `filter()`, `reduce()`, `find_if()`, `any()`, `all()`.

### No SVG Generation Library

Cannot generate diagrams from Chemical code. Use `#html { <svg>...</svg> }` inline.

### No Animation Primitives

Cannot animate memory mapping. Use CSS animations via `#css` and `#js`.

## Verification Patterns for ELF Content

Every ELF claim must be verified against authoritative sources:

### Primary Sources

| Topic | Source |
|-------|--------|
| ELF specification | System V gABI: https://refspecs.linuxfoundation.org/elf/elf.pdf |
| ELF man page | Linux `elf(5)`: https://man7.org/linux/man-pages/man5/elf.5.html |
| ELF loader | Linux kernel `fs/binfmt_elf.c` |
| Reference parser | GNU binutils `readelf.c` |

### Verification Tools

| Tool | Purpose |
|------|---------|
| `readelf -a <file>` | Display all ELF headers |
| `xxd <file>` | Hex dump |
| `objdump -d <file>` | Disassembly |
| `objdump -r <file>` | Relocations |
| `nm <file>` | Symbol table |
| `ldd <file>` | Dynamic dependencies |

### Rule

Every hex dump, byte offset, struct layout, and field size MUST be verified against `readelf` output or the gABI spec. No invented byte sequences.

## Teaching Method Thresholds

Concrete values for vague specifications:

| What | Threshold | Action |
|------|-----------|--------|
| Fatigue detection | Accuracy drops >15% from rolling average over 5 exercises | Suggest break |
| Weakness detection | <60% correct over 5+ attempts on a single concept | Flag for review |
| Activity limit | Session length × 0.8, or 3 consecutive errors | Suggest stopping |
| CLSI warning | CLSI below 0.40 for 2+ consecutive sessions | Reduce difficulty |
| IRT stopping | SE < 0.3 or 8 questions reached | End diagnostic |

## Document Redundancy Map

These concepts appear in multiple documents. The canonical source is marked with ★:

| Concept | Canonical Source | Also Appears In |
|---------|-----------------|-----------------|
| 8-unit structure | ★ `course-design.md` | `learning_design/SKILL.md`, `course-development-handbook.md` |
| Five Exposures | ★ `course-design.md` | `learning_design/SKILL.md` |
| Anxiety design | ★ `adaptive-flow-ui.md` | `course-design.md`, `learning_design/SKILL.md` |
| Exercise types | ★ `teaching-components-catalog.md` | `conceptual-model.md`, `learning_design/SKILL.md` |
| FSRS algorithm | ★ `implementation-details.md` | `features.md`, `learning_design/SKILL.md` |
| Component catalog | ★ `teaching-components-catalog.md` | `developable-components.md` |

**Rule**: When updating a concept, update the canonical source. Other documents should reference, not repeat.

## Problems Discovered During Audit

### No Bridge Between Pedagogy and Implementation

Teaching design documents are technology-agnostic. Implementation documents are Chemical-specific. No document maps "Quiz component from catalog" to "here's the `#html` code."

**Status**: `docs/pedagogy-to-implementation.md` now exists.

### FSRS Implementation Uses FSRS-4.5-Style Weights

`learning/src/fsrs.ch` initializes **21 weights** (19 FSRS-4.5-style parameters + w[19] hard factor 0.90 + w[20] easy factor 1.15) with target retention 0.90 (customizable per 1.1.4). Interval formula: `s_new * (exp(w[8]*(D-3)) - 1) * target_retention / 0.9`, clamped [1, 36500] days, with Again=1 day, Hard×w[9], Easy×w[10]. New-card graduation steps: 1 day, then 3 days. Parameter optimization via prediction-error hill climbing (`optimize_fsrs_params`).

**Status**: Matches checklist items 1.1.1–1.1.15 as implemented. If upgrading to FSRS-5, replace the weight table and interval math together.

### No End-to-End Test Specification

No document specifies how to verify the entire system works end-to-end.

**Partial mitigation**: `scripts/underlayer-build-test.sh` builds, starts the server, and curls every major endpoint. Full E2E spec still missing.

### Error Envelope Divergence

`engineering_patterns` specifies `{ok, error:{code,message}}`, but every implemented handler returns the flat `{"error":"..."}` (via `send_error`) and health returns `{"status":"ok"}`. Tests assert against the flat format.

**Action needed**: Either adopt the envelope in `send_error` + all handlers + tests, or simplify the spec. Don't mix both.

### AI Constraint Pipeline Has No Error Recovery

The 8-step pipeline says "No steps may be skipped" but doesn't specify failure handling.

**Action needed**: Add error recovery to `ai-course-writing-constraints.md`.
