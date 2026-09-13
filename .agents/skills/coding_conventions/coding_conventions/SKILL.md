# Coding Conventions — Underlayer

Style rules, naming conventions, and priority system for the Underlayer platform.

## Feature Priority System (MANDATORY)

Every feature in `docs/features-complete.md` has a priority tag. **Always work on the lowest available priority number.**

| Tag | Priority | Description |
|-----|----------|-------------|
| **P0** | Critical | Must have for MVP. Core learning loop, basic API, essential UI. |
| **P1** | Important | Should have for launch. Session management, progress tracking, course rendering. |
| **P2** | Nice to have | Enhances experience. Analytics, recommendations, advanced FSRS. |
| **P3** | Future | Long-term vision. AI/ML, enterprise, social features. |

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

**The Chemical compiler compiles faster when code is split across many small files.** Large single files cause slow compilation.

### Rules

1. **No file over 250 lines.** Split if exceeded.
2. **One concern per file.** One handler group, one CRUD entity, one algorithm.
3. **Shared private helpers → public in `helpers.ch`.** When splitting, private helpers used across files must become `public`.
4. **`main.ch` is just the root.** Contains only constants or a comment listing files.
5. **File naming:** `snake_case.ch` describing content (e.g., `handlers_review.ch`).

---

## String Building

```chemical
// WRONG
var msg = "Hello" + " World"

// CORRECT
var msg = std::string("Hello")
msg.append_view(" World")
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
```

---

## Route Handlers

```chemical
// No captures
srv.router.add("GET", "/health", (req, res) => { ... })

// Capture by reference
srv.router.add("GET", "/", (|&db|(req, res) => { ... }))
```

---

## Gotchas Checklist

- [ ] No `+` for strings
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] `vector.get(i)` returns COPY — use `get_ptr(i)`
- [ ] `string_view` has no ownership
- [ ] `defaultUniversalSetup()` before components
- [ ] `var Err(e) = result else unreachable`
- [ ] Lambda captures: `(|var|` value, `(|&var|` reference
- [ ] Test functions: `test_snake_case()`
- [ ] Feature priorities: P0 first, P3 last
