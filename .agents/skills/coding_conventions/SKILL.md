# Coding Conventions Skill — Underlayer

**Load this BEFORE writing any Chemical code.** Style rules, naming conventions, and patterns extracted from analyzing the actual codebase.

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Functions | `snake_case` | `render_home()`, `parse_i64_from_str()` |
| Variables | `snake_case` | `total_tests`, `vec_destruct_called` |
| Constants | `snake_case` | `ANSI_COLOR_RESET`, `default_open_flags` |
| Struct fields | `snake_case` | `price_pkr`, `seller_name`, `is_featured` |
| Struct names | `PascalCase` | `Vehicle`, `DbClient`, `QueryResult` |
| Enum variants | `PascalCase` | `Option.Some`, `Result.Err`, `JsonValue.String` |
| Module names | `snake_case` | `cars_db`, `cars_core` |
| Namespaces | `snake_case` | `public namespace cars_db { ... }` |
| Generic params | Single uppercase | `T`, `U`, `V`, `K`, `R` |
| Test functions | `test_snake_case()` | `test_vectors()`, `test_strings()` |
| Test names | Lowercase descriptive | `"vector of ints work"` |

---

## String Building Pattern

**Never use `+` for strings.** Use `append_view()` / `append_string()`:

```chemical
// WRONG
var msg = "Hello" + " " + "World"

// CORRECT
var msg = std::string("Hello")
msg.append_view(" ")
msg.append_view("World")
// OR
var msg = std::string("Hello World")

// CORRECT — backtick template
var msg = `Hello ${"World"}`
```

### String Comparison
```chemical
// WRONG
if(s1 == s2) { ... }

// CORRECT
if(s1.equals(&s2)) { ... }
if(s1.equals_view("hello")) { ... }
```

---

## Error Handling Pattern

### Result Extraction
```chemical
// Pattern 1: if + var Err
var result = db.execute(sql)
if(result is Result.Err) {
    var Err(e) = result else unreachable
    printf("Error: %s\n", e.to_string().data())
    return Result.Err(e)
}
var Ok(value) = result else unreachable

// Pattern 2: switch
switch(result) {
    Ok(value) => { /* use value */ }
    Err(error) => { /* handle error */ }
}
```

### Option Extraction
```chemical
// Pattern 1: if + var Some
var opt = get_optional()
if(opt is Option.Some) {
    var Some(value) = opt else unreachable
    // use value
} else {
    // handle None
}

// Pattern 2: switch
switch(opt) {
    Some(value) => { /* use value */ }
    None => { /* handle missing */ }
}

// Pattern 3: take()
var opt = get_optional()
var value = opt.take()  // Extracts value, sets opt to None
```

---

## Struct Patterns

### Plain Data Struct (no constructor)
```chemical
public struct Vehicle {
    var id : i64
    var make : std::string
    var model : std::string
    var year : i32

    // Methods
    public func full_title(&self) : std::string {
        var out = self.make.copy()
        out.append_view(" ")
        out.append_view(self.model.to_view())
        return out
    }
}
```

### Struct with @direct_init
```chemical
@direct_init
public struct Vehicle {
    var id : i64
    var make : std::string
    var model : std::string

    public func create(make_ : std::string, model_ : std::string) : Vehicle {
        return Vehicle {
            id = 0, make = make_, model = model_
        }
    }
}
```

### Struct with @make Constructor
```chemical
@make
public struct AppConfig {
    var port : uint
    var db_url : std::string

    @make
    func make() : AppConfig {
        return AppConfig {
            port = 9000u,
            db_url = std::string("./app.db")
        }
    }
}
```

**Critical:** A struct with `@make` but WITHOUT `@direct_init` **cannot** use `{}` syntax at all. Use `T.make()` instead. With both `@make` + `@direct_init`, both `T{}` and `T.make()` work.

### Struct with Destructor
```chemical
public struct Database {
    private var handle : *mut sqlite3 = null

    @delete
    func delete(&mut self) {
        if(self.handle != null) {
            ffi::sqlite3_close_v2(self.handle)
            self.handle = null
        }
    }
}
```

---

## Function Patterns

### Basic Function
```chemical
public func render_home(db : *DbClient, req : *Request, res : *ResponseWriter) {
    // ...
}
```

### Function with Result Return
```chemical
public func load_course(id : string) : Result<Course, Error> {
    var data = fs::read_entire_file(path)?
    return Result.Ok(course)
}
```

### Function with Default Parameters
```chemical
func get_int_or(&self, name : std::string_view, fallback : i64) : i64 {
    // ...
}
```

### Generic Function
```chemical
func <T = int> create_pair(a : T, b : T) : Pair<T, T> {
    return Pair<T, T> { a : a, b : b }
}
```

---

## Import Patterns

### Module-Level Using
```chemical
using std::string
using std::string_view
using std::vector
using std::Result
```

### Namespace Import (test files only)
```chemical
using namespace std;
```

### Never Do This
- ❌ `using namespace std;` in library code — pollutes namespace
- ❌ Import unused modules — keep imports minimal

---

## Comment Style

```chemical
// Copyright (c) Chemical Language Foundation 2026.

// -------------------------------------------------------
// Module description
// What this module does and how it's used
// -------------------------------------------------------

// Single line comments for explanations
var x = 0  // inline comment (rare)

// Section banners:
// ---------------------------------
// Category Name
// ----------------------------------
```

---

## Route Handler Pattern

```chemical
// Lambda captures: (|(captures)|(params) => { body })

// No captures
srv.router.add("GET", "/health", (req, res) => {
    res.set_header_view("Content-Type", "application/json")
    res.write_view("{\"status\":\"ok\"}")
})

// Capture by reference
srv.router.add("GET", "/", (|&db|(req, res) => {
    cars_web::render_home(&raw db, &req, res)
}))

// Multiple captures
srv.router.add("GET", "/", (|&pool, &db_name|(req, res) => {
    var client = pool.pop()
    // ...
    pool.push(&mut client)
}))
```

---

## Database Pattern

```chemical
// Query
func query(db : *DbClient, sql : *string, out : *mut QueryResult) {
    if(db.is_sqlite) {
        sqlite_query(&raw db.sqlite_conn, sql, out)
    } else {
        turso_query(db, sql, out)
    }
}

// Execute
func exec(db : *DbClient, sql : *string) : ExecResult {
    if(db.is_sqlite) {
        return sqlite_exec(&raw db.sqlite_conn, sql)
    }
    return turso_exec(db, sql)
}

// Usage
var result = db.exec("INSERT INTO learners VALUES (?)")
if(result is Result.Err) {
    var Err(e) = result else unreachable
    printf("[db] error: %s\n", e.to_string().data())
}
```

---

## JSON Serialization Pattern

```chemical
// Manual string building (no #json macro in libs)
func to_json(&self, body : &mut string) {
    body.append_view("{\"id\":\"")
    var escaped = json_escape(self.id.to_view())
    body.append_view(escaped.to_view())
    body.append_view("\",\"name\":\"")
    escaped = json_escape(self.name.to_view())
    body.append_view(escaped.to_view())
    body.append_view("\"}")
}

// JSON escape helper
public func json_escape(view : string_view) : string {
    var out = string()
    for(var i = 0u; i < view.size(); i++) {
        var c = view.get(i)
        if(c == '"') { out.append_view("\\\"") }
        else if(c == '\\') { out.append_view("\\\\") }
        else if(c == '\n') { out.append_view("\\n") }
        else if(c == '\r') { out.append_view("\\r") }
        else if(c == '\t') { out.append_view("\\t") }
        else { out.append(c) }
    }
    return out
}
```

---

## HTML Page Pattern

```chemical
public func render_page(db : *DbClient) : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()        // REQUIRED for components
    page.defaultPrepare()
    page.appendTitle(std::string_view("Page Title — Underlayer"))

    #html {
        <div class="page">
            <h1>Hello World</h1>
            @{if(show_content) {
                #html {
                    <p>Content here</p>
                }
            } else {
                #html {
                    <p>No content</p>
                }
            }}
        </div>
    }

    #css {
        .page { max-width: 800px; margin: 0 auto; }
    }

    return page.toString()
}
```

---

## Test Pattern

```chemical
func test_my_feature() {
    test("descriptive test name", () => {
        var result = my_function()
        return result == expected
    })

    test("another test", () => {
        var v = vector<int>()
        v.push(10)
        return v.size() == 1 && v.get(0) == 10
    })
}
```

---

## Namespace Pattern

```chemical
public namespace my_module {
    // All public declarations go here
    public struct MyStruct { ... }
    public func my_function() { ... }
}
```

---

## Gotchas Checklist

Before writing code, verify:

- [ ] No `+` for strings (use `append_view()`)
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] No `arr[i]` (use `arr.get(i)`)
- [ ] `vector.get(i)` returns COPY — use `get_ptr(i)` for destructible types
- [ ] `string_view` has no ownership — don't store beyond source
- [ ] `defaultUniversalSetup()` before any component usage
- [ ] `Result.Err` extraction: `var Err(e) = result else unreachable`
- [ ] `Option.Some` extraction: `var Some(value) = opt else unreachable`
- [ ] Lambda captures: `(|var|` by value, `(|&var|` by reference
- [ ] Test functions named `test_snake_case()`
- [ ] Namespaces match module name
- [ ] `@delete` for destructors with null check
- [ ] `@make` for constructors (use `T.make()` not `T{}` without `@direct_init`)
- [ ] `using std::string` at module level (not `using namespace`)
