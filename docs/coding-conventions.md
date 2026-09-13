# Coding Conventions — Quick Reference

Style rules and naming conventions extracted from the actual codebase. Load `coding_conventions` skill for complete patterns.

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

## Multi-File Modules (CRITICAL)

**The Chemical compiler compiles faster when code is split across many small files.** Large single files cause slow compilation.

### Rules

1. **No file over 250 lines.** Split if exceeded.
2. **One concern per file.** One handler group, one CRUD entity, one algorithm.
3. **Shared private helpers → public in `helpers.ch`.** When splitting, private helpers used across files must become `public`.
4. **`main.ch` is just the root.** Contains only constants or a comment listing files.
5. **File naming:** `snake_case.ch` describing content (e.g., `handlers_review.ch`).

### Example: Splitting a 600-line `main.ch`

```
web/src/
  main.ch                    — Module root (struct only)
  helpers.ch                 — Shared utilities (public)
  json_helpers.ch            — JSON parsing helpers
  handlers_home.ch           — Health + home page
  handlers_courses.ch        — Course listing + detail
  handlers_lessons.ch        — Lesson viewer
  handlers_review.ch         — Review session endpoints
  handlers_progress.ch       — Progress endpoints
  handlers_learners.ch       — Learner CRUD
  static.ch                  — Static file serving
```

### Pattern for Each File

```chemical
// underlayer_web — Description of this file's concern.
using std::string
using std::string_view

public namespace underlayer_web {

    public func some_handler(...) { ... }

}
```

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

## String Building

```chemical
// WRONG
var msg = "Hello" + " World"

// CORRECT
var msg = std::string("Hello")
msg.append_view(" World")
// OR
var msg = `Hello ${"World"}`
```

---

## Error Handling

```chemical
// Result
var result = db.execute(sql)
if(result is Result.Err) {
    var Err(e) = result else unreachable
    printf("Error: %s\n", e.to_string().data())
}
var Ok(value) = result else unreachable

// Option
var opt = get_optional()
if(opt is Option.Some) {
    var Some(value) = opt else unreachable
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

// With @direct_init
@direct_init
public struct Vehicle {
    var id : i64
    public func create(make_ : std::string) : Vehicle { ... }
}

// With @make
@make
public struct AppConfig {
    var port : uint
    @make func make() { return AppConfig { port = 9000u } }
}

// With destructor
public struct Database {
    private var handle : *mut sqlite3 = null
    @delete func delete(&mut self) {
        if(self.handle != null) { ffi::sqlite3_close_v2(self.handle); self.handle = null }
    }
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
srv.router.add("GET", "/", (|&pool, &db_name|(req, res) => { ... }))
```

---

## Database

```chemical
var result = db.exec("INSERT INTO learners VALUES (?)")
if(result is Result.Err) {
    var Err(e) = result else unreachable
    printf("[db] error: %s\n", e.to_string().data())
}
```

---

## JSON Serialization

```chemical
func to_json(&self, body : &mut string) {
    body.append_view("{\"id\":\"")
    var escaped = json_escape(self.id.to_view())
    body.append_view(escaped.to_view())
    body.append_view("\"}")
}
```

---

## HTML Pages

```chemical
var page = HtmlPage()
page.defaultUniversalSetup()  // REQUIRED
page.defaultPrepare()
page.appendTitle(std::string_view("Title"))

#html {
    <div class="page">
        @{if(condition) {
            #html { <p>Yes</p> }
        } else {
            #html { <p>No</p> }
        }}
    </div>
}

#css { .page { max-width: 800px; } }
return page.toString()
```

---

## Tests

```chemical
func test_my_feature() {
    test("descriptive name", () => {
        var result = my_function()
        return result == expected
    })
}
```

---

## Gotchas Checklist

- [ ] No `+` for strings
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] No `arr[i]` (use `arr.get(i)`)
- [ ] `vector.get(i)` returns COPY — use `get_ptr(i)`
- [ ] `string_view` has no ownership
- [ ] `defaultUniversalSetup()` before components
- [ ] `var Err(e) = result else unreachable`
- [ ] Lambda captures: `(|var|` value, `(|&var|` reference
- [ ] Test functions: `test_snake_case()`
