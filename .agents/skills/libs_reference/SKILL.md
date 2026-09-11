# Libraries Reference Skill — Underlayer

**Load this BEFORE writing any Chemical code.** Complete catalog of available libraries, their APIs, types, and usage patterns. Based on analysis of actual source code.

---

## Quick Reference: What to Import

| Need | Import | Package |
|------|--------|---------|
| Strings, vectors, maps, Option, Result | `import std` | stdlib |
| C standard library | `import cstd` | cstd |
| HTTP server | `import server` | server |
| HTTP client | `import http` | http |
| JSON parse/stringify | `import json` | json |
| File system | `import fs` | fs |
| HTML page builder | `import page` | page |
| Base64/hex/url encoding | `import encoding` | encoding |
| Universal components | `import components` + `import universal_cbi` | components |
| `#html` macro | `import html_cbi` | html_cbi |
| `#css` macro | `import css_cbi` | css_cbi |
| `#js` macro | `import js_cbi` | js_cbi |
| `#md` macro | `import md_cbi` | md_cbi |
| SQLite3 | `import "github.com/chemicallang/sqlite3"` | sqlite3 |
| Turso HTTP | (use http client directly) | libturso |

---

## std — Standard Library

### Import
```chemical
import std
```

### Key Types

**string (SSO 16-byte)**
```chemical
var s = std::string("hello")           // From *char
var s = std::string_view("hello")      // View (no ownership)
var s = other.copy()                   // Deep copy
var s = other.to_view()                // Get view

// String operations
s.append('c')                          // Append char
s.append_view("world")                 // Append view
s.append_string(&other)                // Append string by ref
s.append_integer(42)                   // Append number
s.append_expr(`count: ${n}`)           // Append template
s.size()                               // Length
s.empty()                              // Is empty
s.get(i)                               // Get char at index
s.equals(&other)                       // Compare (pointer)
s.equals_view("hello")                 // Compare with view
s.to_view()                            // Convert to view
s.copy()                               // Deep copy
s.data()                               // *char pointer
```

**vector\<T\>**
```chemical
var v = std::vector<int>()
v.push(10)                             // Add element
v.get(i)                               // Get by index (COPY)
v.get_ptr(i)                           // Get pointer (MUTABLE)
v.get_ref(i)                           // Get reference
v.size()                               // Count
v.empty()                              // Is empty
v.clear()                              // Remove all
v.remove(i)                            // Remove at index
v.data()                               // Raw pointer
```

**Option\<T\>**
```chemical
var o = Option.Some(42)
var o = Option.None<int>()

switch(o) {
    Some(value) => { /* use value */ }
    None => { /* handle missing */ }
}

if(o is Option.Some) { ... }
if(o is Option.None) { ... }
var val = o.take()                     // Extract value
```

**Result\<T,E\>**
```chemical
var r = Result.Ok(42)
var r = Result.Err(Error("failed"))

switch(r) {
    Ok(value) => { /* use value */ }
    Err(error) => { /* handle error */ }
}

if(r is Result.Err) { ... }
var Ok(val) = r else unreachable       // Pattern extract
```

**unordered_map\<K,V\>**
```chemical
var m = std::unordered_map<std::string, int>()
m.insert("key", 42)
var ptr = m.get_ptr("key")             // *mut V or null
if(ptr != null) { /* use ptr */ }
m.contains("key")
m.erase("key")
m.size()
```

**ordered_map\<K,V\>**
Same API as unordered_map but preserves insertion order.

**function\<sig\>**
```chemical
var f : std::function<(int) => int> = (x) => { return x * 2 }
f(5)  // Returns 10
```

### Gotchas
- `vector.get(i)` returns a COPY — use `get_ptr(i)` for destructible types
- `string` is SSO (16 bytes inline) — small strings don't allocate
- `string_view` has no ownership — don't store beyond the source
- No `+` operator for strings — use `append_view()` / `append_string()`
- `0.5` is `double`, not `float` — use `0.5f`

---

## page — HTML Page Builder

### Import
```chemical
import page
```

### Key Types

**HtmlPage**
```chemical
var p = HtmlPage()
p.defaultUniversalSetup()              // Required for universal components
p.defaultPrepare()                     // Set up HTML structure
p.appendTitle(std::string_view("Title"))
p.append_head_view(std::string_view("<meta charset=\"UTF-8\">"))

// Content output
var html = p.toString()                // Get final HTML
p.append_view("text")                  // Append to body
```

### Usage Pattern
```chemical
public func render_page() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()
    page.appendTitle(std::string_view("My Page — Underlayer"))

    #html {
        <div class="content">
            <h1>Hello World</h1>
        </div>
    }

    #css {
        .content { max-width: 800px; margin: 0 auto; }
    }

    return page.toString()
}
```

### Gotchas
- **NEVER use string appends for HTML/CSS/JS** — ALWAYS use `#html`, `#css`, `#js` macros
- `defaultUniversalSetup()` is REQUIRED before any `#html` with components
- `defaultPrepare()` sets up the HTML structure
- CSS goes in `#css { }` blocks, not inline
- JS goes in `#js { }` blocks

### Dual-Mode Pattern

The `page` library enables both static and backend serving:

**Static Mode (GitHub Pages):**
```chemical
// Concept file emits complete HTML
public func render_concept() : std::string {
    var page = HtmlPage()
    page.default_prepare()
    #html { <div>...</div> }
    #css { ... }
    #js { ... }
    return page.to_string()  // Complete HTML page
}
```

**Backend Mode (Server):**
```chemical
// Route handler serves the same HTML
public func handle_lesson(req : &http::Request, res : *mut http::ResponseWriter) {
    var page = HtmlPage()
    page.default_prepare()
    #html { <div>...</div> }
    #css { ... }
    #js { ... }
    var html = page.to_string()
    res.write_view(html.to_view())
}
```

Both modes produce identical HTML. The difference is delivery: file system vs HTTP response.

---

## server — HTTP Server

### Import
```chemical
import server
```

### Key Types

**ServerConfig**
```chemical
var cfg = server::ServerConfig()
cfg.addr = std::string(":9000")        // Listen address
cfg.worker_count = 4u                   // Thread count
cfg.request_timeout_ms = 30000u        // Request timeout
```

**Server**
```chemical
var srv = server::Server(cfg)

// Route registration
srv.router.add("GET", "/path", handler)
srv.router.add("POST", "/path", handler)
srv.router.add("GET", "/path/:param", handler)
srv.router.add("GET", "/path/:param*", handler)  // Wildcard

// Start serving
srv.serve()                             // Blocking
srv.serve_async()                       // Non-blocking
srv.shutdown()                          // Graceful shutdown
```

### Route Handler Pattern
```chemical
// No captures
srv.router.add("GET", "/health", (req, res) => {
    res.set_header_view("Content-Type", "application/json")
    res.write_view("{\"status\":\"ok\"}")
})

// Capture by reference
srv.router.add("GET", "/", (|&db|(req, res) => {
    // Use db here
}))

// Multiple captures
srv.router.add("GET", "/", (|&pool, &db_name|(req, res) => {
    // Use pool and db_name
}))
```

### Request/Response
```chemical
// Request
req.path.to_view()                     // URL path
req.method                             // HTTP method
req.get_header("Content-Type")         // Header
var body_opt = req.body.read_to_string()  // Body (Option)

// Response
res.status = 200u                       // Status code
res.set_header_view("Key", "Value")    // Set header
res.write_view("content")              // Write body
res.send_file(path)                    // Zero-copy file send
```

### Path Parameters
```chemical
var params = std::vector<std::pair<string, string>>()
var pattern = std::string("/course/:courseKey")
var matched = web::match_pattern(&pattern, &req.path, &raw mut params)
if(matched && params.size() > 0u) {
    var key = params.get_ptr(0u).second.copy()
}
```

### Gotchas
- `send_headers` always appends "OK" after status code
- Path params require `web::match_pattern()` — not automatic
- Lambda captures: `(|var|` by value, `(|&var|` by reference

---

## http — HTTP Client

### Import
```chemical
import http
```

### Key Types

**Client**
```chemical
var client = http::Client()

// GET
var res_opt = client.get(url.to_view())
if(var Ok(res) = res_opt) {
    var body_opt = res.body.read_to_string()
    if(var Some(body) = body_opt) {
        // Use body
    }
}

// POST
var res_opt = client.post(url.to_view(), body.to_view(), "application/json")
```

**URL**
```chemical
var url = http::URL::parse("https://example.com/path?query=value")
```

### Gotchas
- Returns `Result<Response, string>` — always check for errors
- Body is lazy — must call `read_to_string()` explicitly

---

## json — JSON Parsing

### Import
```chemical
import json
```

### High-Level API
```chemical
// Parse JSON string
var value = json::parse(json_string.to_view())

// Stringify to JSON
var str = json::stringify(value)
```

### Low-Level API (for complex parsing)
```chemical
var parser = json::JsonParser(65536, 512)
var handler = json::ASTJsonHandler()
var result = parser.parse(data, size, &raw mut handler)
if(result.ok) {
    // Access handler.root as JsonValue
}
```

### JsonValue Variant
```chemical
// Access fields
var ptr = json::json_get(&raw mut value, "key")
if(ptr != null) {
    if(*ptr is JsonValue.String) {
        var String(s) = *ptr else unreachable
        // Use s
    }
}
```

### Gotchas
- `JsonParser` is SAX-style streaming — requires `ASTJsonHandler` to build AST
- `JsonValue` uses `ordered_map` for objects (preserves key order)
- Manual string building for serialization (no `#json` macro in libs)

---

## fs — File System

### Import
```chemical
import fs
```

### Key Functions
```chemical
// Check existence
if(fs::exists(path)) { ... }
if(fs::is_file(path)) { ... }
if(fs::is_dir(path)) { ... }

// Read file
var data = fs::read_entire_file(path)  // Returns vector<u8>
var text = fs::read_entire_text_file(path)  // Returns string

// Write file
fs::write_text_file(path, content)

// Atomic write (safe for concurrent access)
fs::atomic_write(path, content)

// Directory operations
fs::copy_directory(src, dst)
```

### Gotchas
- `read_entire_file` returns `vector<u8>`, not `string`
- All paths are `*char` (null-terminated), not `string_view`
- `..` in paths returns 403
- `atomic_write` is for safe concurrent writes

---

## encoding — Encoding Utilities

### Import
```chemical
import encoding
```

### Key Functions
```chemical
// Base64
var encoded = encoding::base64_encode(data)
var decoded = encoding::base64_decode(encoded)

// Hex
var hex = encoding::hex_encode(data)
var data = encoding::hex_decode(hex)

// URL encoding
var encoded = encoding::url_encode(data)
var decoded = encoding::url_decode(encoded)
```

### Gotchas
- All functions work with `string_view` input
- Returns `string` (heap-allocated)

---

## components — Universal Components

### Import
```chemical
import components
import universal_cbi
```

### Available Components
| Component | Purpose |
|-----------|---------|
| `Button` | Clickable button (variants: default, outline, ghost, destructive) |
| `Card` | Container with border |
| `CardBody` | Card content area |
| `CardTitle` | Card heading |
| `CardDescription` | Card subtext |
| `CardFooter` | Card actions |
| `Input` | Text input |
| `Field` | Label + input wrapper |
| `Badge` | Status indicator (variants: default, secondary, destructive, outline) |
| `Alert` | Message banner |
| `Separator` | Visual divider |
| `Typography` | Text with styling |
| `Select` | Dropdown selector |
| `Sheet` | Slide-out panel |
| `Toast` | Notification popup |
| `Slider` | Range input |

### Usage Pattern
```chemical
public func render_page() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()        // REQUIRED
    page.defaultPrepare()

    #html {
        <div class="dashboard">
            <Card>
                <CardBody>
                    <CardTitle>Welcome</CardTitle>
                    <Button variant="default">Start Learning</Button>
                </CardBody>
            </Card>
        </div>
    }

    #css {
        .dashboard { padding: 2rem; }
    }

    return page.toString()
}
```

### Gotchas
- `defaultUniversalSetup()` is REQUIRED before any component usage
- Course-specific components must NOT depend on platform components
- CSS class names are hashed — use semantic names

---

## sqlite3 — SQLite Bindings

### Import
```chemical
import "github.com/chemicallang/sqlite3"
```

### Key Types

**Database**
```chemical
var db = sqlite::Database.open(path, sqlite::OpenFlag.READWRITE | sqlite::OpenFlag.CREATE)
if(db is Result.Err) {
    var Err(e) = db else unreachable
    // Handle error
}
var Ok(conn) = db else unreachable

// Execute SQL
var res = conn.execute("CREATE TABLE test (id INTEGER PRIMARY KEY)")
if(res is Result.Err) { /* handle */ }

// Prepare statement
var stmt_res = conn.prepare("INSERT INTO test VALUES (?)")
var Ok(stmt) = stmt_res else unreachable

// Bind parameters
stmt.bind_int(1, 42)
stmt.bind_text(2, "hello")

// Step through results
while(stmt.step()?) {
    var id = stmt.column_int(0)
    var name = stmt.column_text(1)
}

// Cleanup (automatic via @delete)
// stmt is destroyed when it goes out of scope
```

**Statement**
```chemical
// Bind parameters
stmt.bind_int(index, value)
stmt.bind_int64(index, value)
stmt.bind_text(index, value)
stmt.bind_null(index)

// Read columns
stmt.column_count()
stmt.column_name(index)
stmt.column_type(index)
stmt.column_int(index)
stmt.column_int64(index)
stmt.column_text(index)
```

### Usage Pattern
```chemical
func init_database(path : string) : Result<sqlite::Database, sqlite::Error> {
    var db = sqlite::Database.open(path, sqlite::OpenFlag.READWRITE | sqlite::OpenFlag.CREATE)?
    db.execute("CREATE TABLE IF NOT EXISTS learners (id TEXT PRIMARY KEY)")?
    db.execute("CREATE TABLE IF NOT EXISTS concept_states (id TEXT PRIMARY KEY)")?
    return Result.Ok(db)
}
```

### Gotchas
- `Database` has `@delete` — automatically closes on scope exit
- `Statement` has `@delete` — automatically finalizes
- `column_text` returns `string_view` — copy if you need to store it
- All errors return `Result<T, sqlite::Error>`

---

## Turso HTTP Client (libturso pattern)

### Import
```chemical
import http
import json
```

### Key Types (from analyzing libturso)

**Value variant**
```chemical
public variant Value {
    Null()
    Text(value : std::string)
    Integer(value : i64)
    Float(value : double)
    BlobBase64(value : std::string)
}

// Convenience constructors
var v = Value.Text(std::string("hello"))
var v = Value.Integer(42i64)
var v = Value.Float(3.14)
```

**Row**
```chemical
var text = row.get_text("column_name")
var int_val = row.get_int("column_name")
var int_val = row.get_int_or("column_name", 0i64)
```

**Client**
```chemical
var client = http::Client()
var endpoint = std::string(base_url)
endpoint.append_view("/v2/pipeline")

// Build request body manually (JSON)
var body = std::string()
body.append_view("{\"statements\":[{\"sql\":\"SELECT 1\"}]}")

var res = client.post(endpoint.to_view(), body.to_view(), "application/json")
```

### Gotchas
- Turso uses HTTP v2 pipeline protocol — requests are JSON arrays
- No high-level API in libs — must build JSON manually
- Use `json::JsonParser` to parse responses

---

## chemical.mod Patterns

### Application Module
```chemical
application my_app
source "src"
import std
import cstd
import http
import page
// ... more imports
```

### Library Module
```chemical
module my_lib
source "src"
import std
import cstd
```

### Conditional Imports
```chemical
import test_env if test
import test if test
```

### Conditional Links
```chemical
link "m" if linux
link "advapi32" if windows
```

### Remote Imports
```chemical
import "github.com/chemicallang/sqlite3"
```

### Internal Module Imports
```chemical
import "./core"
import "../core"
```

---

## Common Patterns

### String Building
```chemical
var out = std::string()
out.append_view("prefix ")
out.append_view(other.to_view())
out.append('c')
out.append_integer(42)
return out
```

### Error Handling
```chemical
var result = some_operation()
if(result is Result.Err) {
    var Err(e) = result else unreachable
    printf("Error: %s\n", e.to_string().data())
    return Result.Err(e)
}
var Ok(value) = result else unreachable
// Use value
```

### JSON Serialization (Manual)
```chemical
func to_json(&self, body : &mut string) {
    body.append_view("{\"id\":\"")
    var escaped = json_escape(self.id.to_view())
    body.append_view(escaped.to_view())
    body.append_view("\",\"name\":\"")
    escaped = json_escape(self.name.to_view())
    body.append_view(escaped.to_view())
    body.append_view("\"}")
}
```

### HTML Response
```chemical
var page = HtmlPage()
page.defaultUniversalSetup()
page.defaultPrepare()

#html {
    <div class="content">
        <h1>{title}</h1>
    </div>
}

res.set_header_view("Content-Type", "text/html; charset=utf-8")
var html = page.toString()
res.write_view(html.to_view())
```

### JSON Response
```chemical
res.set_header_view("Content-Type", "application/json")
var body = std::string("{\"status\":\"ok\"}")
res.write_view(body.to_view())
