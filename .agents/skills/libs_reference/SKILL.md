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
| SQLite3 | `import "../../sqlite3"` (relative path used by `database/chemical.mod`) | sqlite3 |
| UUID | `import uuid` | uuid |
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
    var title = std::string_view("My Page — Underlayer")
    page.appendTitle(&title)

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
    page.defaultPrepare()
    #html { <div>...</div> }
    #css { ... }
    #js { ... }
    return page.toString()  // Complete HTML page
}
```

**Backend Mode (Server):**
```chemical
// Route handler serves the same HTML
public func handle_lesson(req : &http::Request, res : *mut http::ResponseWriter) {
    var page = HtmlPage()
    page.defaultPrepare()
    #html { <div>...</div> }
    #css { ... }
    #js { ... }
    var html = page.toString()
    var hv = html.to_view()
    res.write_view(&hv)
}
```

Both modes produce identical HTML. The difference is delivery: file system vs HTTP response.

---

## server — HTTP Server

### Import
```chemical
import server
```

### Key Types (verified against web/ + tests/src usage)

**ServerConfig**
```chemical
var cfg = server.ServerConfig()
cfg.addr = std::string("127.0.0.1:19876")   // Listen address (port 9000 in production)
```

**Server**
```chemical
var srv = server.Server(cfg)

// Route registration — no param substitution; extract via path_segments()
srv.router.add("GET", "/api/courses/:courseId", handler)
srv.router.add("GET", "/courses/*", handler)      // Wildcard (static files)

// Start serving
srv.serve()                          // Blocking (production)
srv.serve_async(19876u)              // Non-blocking, port arg — used in tests
srv.shutdown()                       // Graceful shutdown (always pair with serve_async)
```

**Real test-server pattern** (see `testing` skill / `tests/src/health_test.ch`):
```chemical
var cfg = server.ServerConfig()
cfg.addr = string("127.0.0.1:19876")
var srv = server.Server(cfg)
srv.router.add("GET", "/api/health", (req, res) => {
    underlayer_web::handle_health(&req, &raw mut res)
})
srv.serve_async(19876u)
std::concurrent.sleep_ms(200u)
```

> Note: tests call it as `server.ServerConfig()` / `server.Server(cfg)` — namespace-qualified, no `::`.

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

### Request/Response (as used in web/src handlers)
```chemical
// Request
var path = req.path.to_view()                  // URL path
var segments = underlayer_core::path_segments(&path)  // vector<string_view>
req.query.get(&key_sv)                         // QueryMap — takes &string_view key, returns string_view ("" if missing)
var body = json::parse(req.body...)            // POST body → JsonValue

// Response
res.status = 200u                              // Status code (uint)
var ct = std::string_view("application/json")
res.set_header_view(std::string_view("Content-Type"), &ct)   // Set header
var bv = body.to_view()
res.write_view(&bv)                            // Write body
```

Prefer the shared helpers instead of raw response writing: `send_page`, `send_json_str`, `send_error` in `web/src/helpers.ch`.

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
- The router does NOT substitute `:param` — extract by position with `underlayer_core::path_segments()`; e.g. for `/api/courses/:courseId/lessons/:conceptId`, course = segment 1, concept = segment 3
- Lambda captures: `(|var|` by value, `(|&var|` by reference; handlers take `&req` and `&raw mut res`
- `serve_async(port)` + `sleep_ms(200u)` + later `shutdown()` is the established test lifecycle

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
| Component | Purpose | Key Props |
|-----------|---------|-----------|
| `Button` | Clickable button | `variant`, `size`, `onClick` |
| `Card` | Container with border | `size`, `onClick` |
| `CardBody` | Card content area | — |
| `CardTitle` | Card heading | `level` (2,3,4) |
| `CardDescription` | Card subtext | — |
| `CardFooter` | Card actions | — |
| `Input` | Text input | `placeholder`, `value`, `onChange` |
| `Field` | Label + input wrapper | `label`, `error` |
| `Badge` | Status indicator | `variant` (default, secondary, success, error, warning, info, outline-*) |
| `Alert` | Message banner | `variant` |
| `Separator` | Visual divider | — |
| `Typography` | Text with styling | `variant` |
| `Select` | Dropdown selector | `options`, `defaultValue`, `onValueChange`, `placeholder` |
| `Sheet` | Slide-out panel | `open`, `onOpenChange` |
| `Toast` | Notification popup | — |
| `Slider` | Range input | `min`, `max`, `value` |
| `Toggle` | Checkbox/switch/radio | `type`, `checked`, `onCheckedChange` |
| `ToggleGroup` | Group of toggles | `type`, `value`, `onValueChange` |
| `RadioGroup` | Radio button group | `value`, `onValueChange` |
| `Collapsible` | Expandable section | `open` |

### Usage Pattern (Static Pages)
```chemical
public func render_page() : std::string {
    var page = HtmlPage()
    page.default_prepare()

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

    return page.to_string()
}
```

### Writing Custom Universal Components

```chemical
// content/components/ProgressBar.ch
func progress_styles(page : &mut HtmlPage) : *char {
    return #css {
        width: 100%;
        height: 8px;
        background: hsl(var(--muted));
        border-radius: 9999px;
        overflow: hidden;
        .chx-progress-fill {
            height: 100%;
            background: hsl(var(--primary));
            transition: width 0.3s ease;
        }
    }
}

public #universal ProgressBar(props) {
    var value = props.value || 0
    var max = props.max || 100
    var pct = (value * 100) / max
    var fillStyle = "width: " + underlayer_core::int_to_string(pct) + "%"
    return <div class={${progress_styles(page)}}>
        <div class="chx-progress-fill" style={fillStyle}></div>
    </div>
}
```

### Stateful Components

```chemical
public #universal ConceptCard(props) {
    var [expanded, setExpanded] = useState(false)
    var arrowClass = expanded ? "arrow rotated" : "arrow"
    var contentStyle = expanded ? "" : "display: none;"

    return <div class="concept-card">
        <div class="concept-header" onClick={() => setExpanded(!expanded)}>
            <span>{props.title}</span>
            <span class={arrowClass}>▸</span>
        </div>
        <div class="concept-content" style={contentStyle}>
            {props.children}
        </div>
    </div>
}
```

### Component CSS Pattern

CSS goes in a `*_styles` function that returns `#css { }` — emits a hashed class name:

```chemical
func card_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: flex;
        flex-direction: column;
        border-radius: var(--radius-lg);
        border: 1px solid hsl(var(--border));
        background: hsl(var(--card));
        &:hover { border-color: hsl(var(--border)); }
        &[data-variant="sm"] { padding: 0.75rem; }
    }
}
```

### Key Rules
1. **`#universal` keyword** triggers SSR + hydration — component renders on server AND client
2. **CSS in `*_styles` function** — returns `#css { }` for hashed class names
3. **Props via `props.name`** — `props.children` for nested content
4. **State via `useState(init)`** — returns `[value, setter]`
5. **Use `data-*` attributes for state-driven CSS** — not inline `style` (wiped by hydration)
6. **`defaultUniversalSetup()` required** before any component usage in the page

### Gotchas
- `defaultUniversalSetup()` is REQUIRED before any component usage
- Hydration wraps children in an extra `<div>` — style both direct children and one nesting level
- Inline `style` gets wiped by hydration — use `data-*` attributes + CSS selectors for state
- `props.children` is `SsrText` — a lightweight string view, not a full string
- Non-ASCII in JS blobs crashes — keep all runtime JS ASCII-safe
- `createPortal` for overlays — menus/dialogs that escape `overflow: hidden` ancestors
- CSS class names are hashed — use semantic names in source, hashed names in output

---

## sqlite3 — SQLite Bindings (as wrapped by underlayer_db)

### Import (used in database/chemical.mod)
```chemical
import "../../sqlite3"
```

> **Underlayer note:** application code never calls sqlite3 directly — use the dual-backend wrapper in `database/src/main.ch`: `underlayer_db::make_client(url, token)`, `exec_sql`, `query_sql`, `query_sql_single`, `close`, `is_remote_url`. See the `api_reference` skill for the full API and schema. The raw sqlite3 API below is for reference.

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

## Turso HTTP Client (libturso pattern — selected automatically by underlayer_db)

### Import
```chemical
import http
import json
```

When `DATABASE_URL` starts with http(s), `underlayer_db::make_client` routes all `exec_sql`/`query_sql` calls through the Turso HTTP v2 pipeline instead of SQLite. Schema init is skipped for remote URLs.

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
