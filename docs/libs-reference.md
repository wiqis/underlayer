# Libraries Reference — Quick Reference

Quick reference for available Chemical libraries. Load `libs_reference` skill for complete API details.

---

## Import Cheatsheet

| Need | Import |
|------|--------|
| Strings, vectors, maps, Option, Result | `import std` |
| C standard library | `import cstd` |
| HTTP server | `import server` |
| HTTP client | `import http` |
| JSON | `import json` |
| File system | `import fs` |
| HTML page builder | `import page` |
| Encoding (base64, hex, url) | `import encoding` |
| Universal components | `import components` + `import universal_cbi` |
| `#html` / `#css` / `#js` / `#md` | `import html_cbi` / `css_cbi` / `js_cbi` / `md_cbi` |
| SQLite3 | `import "github.com/chemicallang/sqlite3"` |
| Turso | Use `http` client directly |

---

## std — Key APIs

### string
```chemical
var s = std::string("hello")
s.append('c')
s.append_view("world")
s.append_string(&other)
s.append_integer(42)
s.size() / s.empty() / s.get(i)
s.equals(&other) / s.equals_view("hello")
s.to_view() / s.copy() / s.data()
```

### vector\<T\>
```chemical
var v = std::vector<int>()
v.push(10)
v.get(i)          // COPY — use get_ptr(i) for destructible types
v.get_ptr(i)      // *mut T
v.size() / v.empty() / v.clear() / v.remove(i)
```

### Option\<T\> / Result\<T,E\>
```chemical
var o = Option.Some(42)
var r = Result.Ok(42)
switch(o) { Some(v) => { ... } None => { ... } }
var Ok(v) = r else unreachable
```

### unordered_map\<K,V\> / ordered_map\<K,V\>
```chemical
var m = std::unordered_map<std::string, int>()
m.insert("key", 42)
m.get_ptr("key")  // *mut V or null
m.contains("key") / m.erase("key")
```

---

## page — HtmlPage

```chemical
var page = HtmlPage()
page.defaultUniversalSetup()  // REQUIRED for components
page.defaultPrepare()
page.appendTitle(std::string_view("Title"))
return page.toString()
```

---

## server — HTTP Server

```chemical
var cfg = server::ServerConfig()
cfg.addr = std::string(":9000")
var srv = server::Server(cfg)

srv.router.add("GET", "/path", (req, res) => { ... })
srv.router.add("GET", "/path/:param", (|&db|(req, res) => { ... }))
srv.serve()
```

### Request/Response
```chemical
req.path.to_view() / req.method / req.get_header("Key")
var body = req.body.read_to_string()
res.status = 200u / res.set_header_view("K", "V") / res.write_view("content")
```

---

## http — HTTP Client

```chemical
var client = http::Client()
var res = client.get(url.to_view())  // Result<Response, string>
var res = client.post(url.to_view(), body.to_view(), "application/json")
var body = res.body.read_to_string()
```

---

## json — JSON

```chemical
var value = json::parse(str.to_view())
var str = json::stringify(value)

// Low-level
var parser = json::JsonParser(65536, 512)
var handler = json::ASTJsonHandler()
parser.parse(data, size, &raw mut handler)
```

---

## fs — File System

```chemical
fs::exists(path) / fs::is_file(path) / fs::is_dir(path)
var data = fs::read_entire_file(path)  // vector<u8>
var text = fs::read_entire_text_file(path)  // string
fs::write_text_file(path, content)
```

---

## encoding — Encoding

```chemical
var encoded = encoding::base64_encode(data)
var decoded = encoding::base64_decode(encoded)
var hex = encoding::hex_encode(data)
var url_encoded = encoding::url_encode(data)
```

---

## sqlite3 — SQLite

```chemical
import "github.com/chemicallang/sqlite3"

var db = sqlite::Database.open(path, sqlite::OpenFlag.READWRITE)?
db.execute("CREATE TABLE ...")?
var stmt = db.prepare("SELECT * FROM ...")?
while(stmt.step()?) {
    var id = stmt.column_int(0)
    var name = stmt.column_text(1)
}
```

---

## Turso HTTP Pattern

```chemical
var client = http::Client()
var endpoint = std::string(base_url)
endpoint.append_view("/v2/pipeline")

var body = std::string("{\"statements\":[{\"sql\":\"SELECT 1\"}]}")
var res = client.post(endpoint.to_view(), body.to_view(), "application/json")
```

---

## Key Gotchas

| Gotcha | Rule |
|--------|------|
| String `+` | Use `append_view()` — no `+` operator |
| `if` without `else` | Language requires `else` — always add `else {}` |
| `0.5` is double | Use `0.5f` for float parameters |
| `arr[i]` | Use `arr.get(i)` — no index operator |
| `vector.get(i)` returns copy | Use `get_ptr(i)` for destructible types |
| `string_view` no ownership | Don't store beyond the source |
| `defaultUniversalSetup()` | REQUIRED before any component usage |
| `Result.Err` extraction | `var Err(e) = result else unreachable` |
| Lambda captures | `(|var|` by value, `(|&var|` by reference |
| Paths are `*char` | Null-terminated, not `string_view` |
