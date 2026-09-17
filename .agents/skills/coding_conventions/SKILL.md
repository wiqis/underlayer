# Coding Conventions — Underlayer

Style rules, naming conventions, and **trusted implementation patterns** for the Underlayer platform.

---

## Feature Priority System (MANDATORY)

Every feature in `docs/features-complete.md` has a priority tag. **Always work on the lowest available priority number.**

| Tag | Priority | What It Means | When to Work On |
|-----|----------|---------------|-----------------|
| **P0** | Critical | Must have for MVP | NOW — nothing else matters |
| **P1** | Important | Should have for launch | After all P0 checked |
| **P2** | Nice to have | Enhances experience | After all P1 checked |
| **P3** | Future | Long-term vision | After all P2 checked |

**Rules:**
1. Never implement a P3 feature when P0 or P1 features remain unchecked.
2. When multiple features share the same priority, implement in numerical order.
3. After implementing a feature, check it off (`- [ ]` to `- [x]`) and verify the server builds + runs.

---

## Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Functions | `snake_case` | `render_home()`, `parse_i64_from_str()` |
| Variables | `snake_case` | `total_tests`, `vec_destruct_called` |
| Constants | `snake_case` | `ANSI_COLOR_RESET` |
| Struct fields | `snake_case` | `price_pkr`, `seller_name` |
| Struct names | `PascalCase` | `Vehicle`, `DbClient` |
| Enum variants | `PascalCase` | `Option.Some`, `Result.Err` |
| Module names | `snake_case` | `cars_db`, `cars_core` |
| Namespaces | `snake_case` | `public namespace underlayer_web` |
| Generic params | Single uppercase | `T`, `U`, `V` |
| Test functions | `test_*()` | `test_health_returns_200` |
| Render functions (content) | `render_<concept_id_snake>` | `render_binary_representation()` |
| Handler files | `handlers_<area>.ch` | `handlers_review_page.ch` |
| Concept files | `<concept-id>.ch` (kebab) | `file-layout.ch` |

---

## Multi-File Modules (CRITICAL)

**The Chemical compiler compiles faster when code is split across many small files.** Large single files cause slow compilation. Every module MUST use multiple files.

### Rules

1. **No file over 250 lines.** If a file exceeds 250 lines, split it.
2. **One concern per file.** Each file handles one logical unit (e.g., one handler group, one CRUD entity, one algorithm).
3. **Shared private helpers become public.** When splitting, private helpers used across files must become `public` in a `helpers.ch` file.
4. **`main.ch` is just the root.** It contains either nothing (just a comment listing files) or minimal shared constants.
5. **File naming:** `snake_case.ch` describing the content (e.g., `handlers_review.ch`, `concept_states.ch`, `fsrs.ch`).

### File Structure

Every file in a module follows this pattern:

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
- The namespace name MUST match the directory name.
- Relative imports for sibling modules: `"../core"`, `"../models"`

---

## String Building

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

// Building an error message
var msg = std::string("Failed to load concept '")
msg.append_view(concept_id)
msg.append_view("' in course '")
msg.append_view(course_id)
msg.append_view("'")
```

---

## Error Handling

**No `try/catch`.** Use `Result<T, std::string>` with explicit checks.

```chemical
// Pattern 1: Check and return early
var result = database::query(db, sql.to_view())
if(result is Result.Err) {
    return Result.Err(std::string("Query failed"))
}
var rows = result.value()

// Pattern 2: Unwrap with else unreachable (for values that CANNOT fail)
// NOTE: no get_global_db() exists — db is created in app/main.ch and captured
// into route lambdas as db : &DbClient

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

## Struct Patterns

```chemical
// Plain data
public struct Vehicle {
    var id : i64
    var make : std::string
}

// With @make
@make
public struct AppConfig {
    var port : uint
    @make func make() { return AppConfig { port = 9000u } }
}

// Struct initialization
var learner = underlayer_models::Learner {
    id = id.copy(),
    name = std::string(name),
    email = std::string(email)
}
```

---

## Route Handlers

```chemical
// No captures
srv.router.add("GET", "/health", (req, res) => { ... })

// Capture by reference
srv.router.add("GET", "/", (|&db|(req, res) => { ... }))

// Multiple captures
srv.router.add("POST", "/", (|&db, &config|(req, res) => { ... }))
```

---

## QueryMap Access

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
```

---

## Path Segments

`path_segments()` splits on `/` and **skips empty segments**. For `/api/sessions/12345`:
- Returns: `["api", "sessions", "12345"]` (3 segments)
- NOT: `["", "api", "sessions", "12345"]`

```chemical
var path = req.path()
var segments = path_segments(path)

// Always use segments.size() - 1 for the last segment
if(segments.size() < 1u) {
    send_error(res, 400, "INVALID_REQUEST", "Missing ID")
    return
}
var id = sv_to_string(segments.get(segments.size() - 1u))
```

---

## Vector Iteration

Chemical has no C-style for loop. Use `while` with manual increment.

```chemical
var items = get_items()
var i = 0u
while(i < items.size()) {
    var item = items.get_ptr(i)
    // Use item.field, item.method()
    i = i + 1u
}
```

---

## `if` / `else` Rules

**Every `if` MUST have an `else`.** No inline `if` expressions.

```chemical
// CORRECT
var x : int
if(cond) { x = a } else { x = b }

// CORRECT — empty else
if(cond) { do_something() } @else { }

// WRONG — no else
// if(cond) { x = a }

// WRONG — inline if
// var x = if(cond) a else b
```

---

## Float Literals

`0.5` is `double`. For `float` parameters use `0.5f`.

```chemical
func set_volume(vol : float) { ... }
set_volume(0.5f)    // correct
set_volume(0.5)     // TypeCheck error
```

---

## Verified Patterns From This Codebase (2026-09-17)

These are extracted from the actual Underlayer modules — copy them instead of inventing variants.

### Module → Namespace → Naming

| Directory | Module | Namespace |
|---|---|---|
| `core/` | `underlayer_core` | `public namespace underlayer_core` |
| `models/` | `underlayer_models` | `public namespace underlayer_models` |
| `database/` | `underlayer_db` | `public namespace underlayer_db` |
| `repository/` | `underlayer_repository` | `public namespace underlayer_repository` |
| `learning/` | `underlayer_learning` | `public namespace underlayer_learning` |
| `web/` | `underlayer_web` | `public namespace underlayer_web` |
| `content/` | `underlayer_content` | `public namespace underlayer_content` |

### Page Build Pattern (web/ HTML pages)

```chemical
public func handle_something_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
    var page = HtmlPage()
    page.defaultUniversalSetup()          // hydration runtime
    page.defaultPrepare()                 // charset + viewport
    page.injectDefaultComponentsTheme()   // shadcn theme tokens
    page.appendTitle(std::string_view("Page — Underlayer"))

    #html { /* page markup incl. .navbar shared across pages */ }
    #css  { /* page styles */ }
    #js   { /* vanilla client-side JS; use fetch() against /api/* */ }

    send_page(res, &raw page)             // helper in web/src/helpers.ch
}
```

All three setup calls are required on every page — handlers in this codebase call them in that order.

### Response Helpers (web/src/helpers.ch)

```chemical
send_page(res, &raw page)                    // text/html; charset=utf-8
send_json_str(res, &raw body_string)         // application/json
send_error(res, 404u, &raw err_msg_string)   // sets status + {"error":"..."} JSON
sv_to_string(&raw sv)                        // string_view → owned string (char loop)
```

JSON responses in this codebase are built with `std::string("...")` + `append_view(...)` and integer values via `underlayer_core::int_to_string(...)`.

### JSON Body Parsing (web/src/json_helpers.ch)

```chemical
var parsed = json::parse(req.body.to_view())   // or similar; may be Result
// then, on the root JsonValue:
var name  = json_get_str(&raw root, "name")    // "" if missing
var count = json_get_int(&raw root, "count")   // 0 if missing
```

Same helpers exist in `repository/src/helpers.ch` (`json_i64` additionally).

### Core Utility Functions (underlayer_core)

```chemical
underlayer_core::int_to_string(42)          // i64 → string
underlayer_core::u32_to_string(9000u)       // uint → string
underlayer_core::current_timestamp()        // i64 epoch seconds
underlayer_core::path_segments(&raw sv)     // vector<string_view>, splits on '/'
underlayer_core::json_escape(&raw sv)       // escape for embedding in JSON strings
underlayer_core::make_json_string(&raw sv)  // wrap in quotes + escape
underlayer_core::log_info(&raw sv)
underlayer_core::log_error(&raw sv)
```

### Route Registration (app/main.ch)

Routes live in `app/main.ch`, not in the web module. Pattern for parametrized routes:

```chemical
srv.router.add("GET", "/api/courses/:courseId/lessons/:conceptId", (|&courses_dir|(req, res) => {
    var path = req.path.to_view()
    var segments = underlayer_core::path_segments(&path)
    if(segments.size() >= 4) {
        var course_id = segments.get_ptr(1)
        var concept_id = segments.get_ptr(3)
        underlayer_web::handle_lesson(courses_dir, course_id, concept_id, &req, &raw mut res)
    } else {
        res.status = 400u
        // ... minimal JSON error via write_view
    }
}))
```

Index by segment position (`segments.get_ptr(1)` for `:courseId` in `/api/courses/:courseId`), not by name — the router does not substitute params.

### Handler Signature Conventions

| Kind | Signature |
|---|---|
| Needs DB + dir | `(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter)` |
| Needs DB only | `(db : &DbClient, req : &http::Request, res : *mut http::ResponseWriter)` |
| Static only | `(req : &http::Request, res : *mut http::ResponseWriter)` |
| Request mutation (POST body) | pass `&raw mut req` from the route lambda |

## Gotchas Checklist

Before writing code, verify:

- [ ] No `+` for strings — use `append_view()` / `append_string()`
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] `vector.get(i)` returns COPY — use `get_ptr(i)`
- [ ] `string_view` has no ownership — convert with `sv_to_string` to store
- [ ] `defaultUniversalSetup()` + `defaultPrepare()` + `injectDefaultComponentsTheme()` before `#html`
- [ ] `var Err(e) = result else unreachable`
- [ ] Lambda captures: `(|var|` value, `(|&var|` reference
- [ ] Test functions: `@test` + `test_snake_case(env : &mut TestEnv)`
- [ ] Feature priorities: P0 first, P3 last
- [ ] File max 250 lines — split if exceeded (web/ and repository/ follow this; `models/src/main.ch` at 769 and `app/main.ch` at 1189 are known exceptions)
- [ ] Private helpers across files → public in `helpers.ch`
- [ ] `path_segments()` — use `size() - 1` for last segment; index by position
- [ ] `QueryMap.get()` — returns empty string if missing
- [ ] `string.data()` may not be null-terminated — use `.size()` for SQLite
- [ ] SQL built with string appends — never embed user-controlled values unescaped (passwords/tokens: store hashes only, as `handlers_auth.ch` does)
- [ ] New concept? Register ID in `web/src/helpers.ch::render_concept()`
- [ ] New user-scoped endpoint? Resolve learner via `auth_get_learner_id(db, req)` (bearer token) — see `api_reference`
