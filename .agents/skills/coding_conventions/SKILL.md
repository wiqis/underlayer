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
| Namespaces | `snake_case` | `public namespace cars_db` |
| Generic params | Single uppercase | `T`, `U`, `V` |
| Test functions | `test_*()` | `test_vectors()` |

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

// Pattern 2: Unwrap with else unreachable
var Ok(mut db) = get_global_db() else unreachable

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

## Gotchas Checklist

Before writing code, verify:

- [ ] No `+` for strings — use `append_view()`
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] `vector.get(i)` returns COPY — use `get_ptr(i)`
- [ ] `string_view` has no ownership
- [ ] `defaultUniversalSetup()` before components
- [ ] `var Err(e) = result else unreachable`
- [ ] Lambda captures: `(|var|` value, `(|&var|` reference
- [ ] Test functions: `test_snake_case()`
- [ ] Feature priorities: P0 first, P3 last
- [ ] File max 250 lines — split if exceeded
- [ ] Private helpers across files → public in `helpers.ch`
- [ ] `path_segments()` — use `size() - 1` for last segment
- [ ] `QueryMap.get()` — returns empty string if missing
- [ ] `string.data()` may not be null-terminated — use `.size()` for SQLite
