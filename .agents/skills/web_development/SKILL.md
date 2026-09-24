# SKILL.md — Web Development in Underlayer

## CRITICAL RULE: NEVER use string appends for HTML/CSS/JS

**This is non-negotiable. If you violate this, you will be corrected.**

### The Rule

- **HTML**: ALWAYS use `#html { }` macro (from `html_cbi`)
- **CSS**: ALWAYS use `#css { }` macro (from `css_cbi`)
- **JS**: ALWAYS use `#js { }` macro (from `js_cbi`)

### What is FORBIDDEN

```chemical
// WRONG - NEVER DO THIS
var body = string("<!DOCTYPE html><html>")
body.append_view("<h1>Hello</h1>")
body.append_view("</html>")
res.write_view(body.to_view())
```

### What is CORRECT

```chemical
// CORRECT - ALWAYS DO THIS
var page = HtmlPage()
page.defaultPrepare()   // camelCase — see method-casing note below

#html {
    <div class="lesson">
        <h1>Hello</h1>
    </div>
}

#css {
    .lesson { max-width: 800px; }
}

#js {
    function handleClick() { ... }
}

var html = page.toString()
var hv = html.to_view()
res.write_view(&hv)

### Method casing (verified against web/src/)

HtmlPage methods are **camelCase**: `defaultPrepare()`, `defaultUniversalSetup()`, `injectDefaultComponentsTheme()`, `appendTitle(std::string_view)`, `toString()`. Response methods: `res.set_header_view(...)`, `res.write_view(...)`. `res.status = 200u` is a field assignment, not a method.
```

### If a macro fails to parse

1. **DO NOT** fall back to string appends
2. **DO** fix the macro compiler plugin:
   - `html_cbi` for `#html { }` issues
   - `css_cbi` for `#css { }` issues
   - `js_cbi` for `#js { }` issues
3. **DO** file an issue or fix the bug in the CBI plugin

### Why this rule exists

1. **Safety**: Macros handle escaping, preventing XSS vulnerabilities
2. **Consistency**: All HTML output follows the same patterns
3. **Maintainability**: Macro-generated HTML is structured and debuggable
4. **Tooling**: The compiler can optimize, transform, and validate macro output
5. **No workarounds**: If a macro is broken, fixing the macro helps everyone

### Module imports

Every file that generates HTML must import:

```chemical
import page
import html_cbi
import css_cbi
import js_cbi
```

## Dual-Mode Architecture

Courses work in TWO modes. This is a core constraint.

### Mode 1: Static (GitHub Pages — No Backend)

Courses compile to static HTML/CSS/JS files. Served via GitHub Pages.
- No server required — anyone can take the course from a URL
- Settings stored in localStorage — progress, preferences, bookmarks
- Offline-first — download HTML files, open in browser, works without internet
- Emission: Chemical → `#html`/`#css`/`#js` → HtmlPage → `.html` + `.css` + `.js` → committed to repo

### Mode 2: Backend (Full Server — Account Management)

Same courses, plus user accounts, profiles, analytics, adaptive learning.
- User accounts — email/password, OAuth, profile management
- Server-side progress — spaced repetition, learning history, knowledge health
- Adaptive flow — FSRS engine adjusts difficulty based on performance
- Cross-device sync — progress follows the learner across devices

### Course Design Rule: Backend-Optional

Every course MUST work without a backend:

1. **Course content is self-contained HTML.** No API calls required to render lessons.
2. **All interactivity is client-side JS.** Quizzes, hex viewers, code editors — all work offline.
3. **Progress detection is optional.** If no backend, progress stays in localStorage.
4. **Backend enhances, never gates.** Backend adds features but never blocks content.

### Emission Pattern

```chemical
// Each concept file emits a complete HTML page
public func render_bytes() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <!-- Full lesson content -->
        </div>
    }

    #css { /* Scoped styles */ }
    #js { /* Client-side interactivity */ }

    return page.toString()  // Complete HTML page
}
```

### Static Mode Features (localStorage)

| Feature | Storage |
|---------|---------|
| Progress tracking | `localStorage.progress` |
| Bookmarks | `localStorage.bookmarks` |
| Notes | `localStorage.notes` |
| Review schedule | `localStorage.fsrs` |
| Settings (theme, font) | `localStorage.settings` |

### Backend Mode Features (Server)

| Feature | Storage |
|---------|---------|
| All static features | localStorage (fallback) |
| User account | `users` table |
| Cross-device sync | `concept_states` table |
| Learning analytics | `sessions` table |
| Adaptive difficulty | `review_items` table |

## Pattern for Route Handlers (Backend Mode) — as used in web/src/

Real example shape from `handlers_review_page.ch` / `handlers_home.ch`:

```chemical
public func handle_review_page(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
    var page = HtmlPage()
    page.defaultUniversalSetup()          // 1. hydration runtime — REQUIRED
    page.defaultPrepare()                 // 2. charset + viewport — REQUIRED
    page.injectDefaultComponentsTheme()   // 3. shadcn theme tokens — REQUIRED
    page.appendTitle(std::string_view("Review — Underlayer"))

    #html {
        <div class="navbar"> ... shared nav across all pages ... </div>
        <div class="container">
            <h1>Review Session</h1>
        </div>
    }

    #css {
        body { font-family: system-ui, sans-serif; ... }
        /* page styles — same .navbar/.container base in every handler */
    }

    #js {
        // Vanilla client-side JS, ASCII only.
        // Talks to the backend via fetch() against /api/* endpoints.
        fetch("/api/review/due?course_id=elf&limit=50")
            .then(function(r) { return r.json(); })
            .then(function(data) { /* render */ });
    }

    send_page(res, &raw page)   // from web/src/helpers.ch — sets text/html header + writes
}
```

### JSON API handlers (no page)

```chemical
public func handle_progress(db : &DbClient, courses_dir : &string, req : &http::Request, res : *mut http::ResponseWriter) {
    // 1. Parse query/body
    var learner_id = sv_to_string(...)            // helpers.ch
    // 2. Call repository (never SQL here)
    var states = underlayer_repository::get_all_concept_states(db, &learner_id, &course_id)
    // 3. Build JSON string
    var body = std::string("{\"learner_id\":\"")
    body.append_string(&learner_id)
    body.append_view("\"}")
    // 4. Send
    send_json_str(res, &raw body)                 // helpers.ch
}
```

### Error responses

```chemical
var err = std::string("Concept not found")
send_error(res, 404u, &raw err)   // status + {"error":"..."}
```

Route lambdas in `app/main.ch` validate segment counts and write a minimal JSON error inline when short:

## Pattern: Dynamic Lists (No Loops Inside `#html`)

`@{}` statement blocks inside `#html` are broken (compiler bug — see `docs/implementation-gaps.md` and the `implementation_gaps` skill), and every element must open+close in the same `#html` block. Chemical therefore **cannot loop over data to emit repeated markup server-side.** The trusted workaround — used by the course landing, onboarding, and the home page course grid (2.1.25) — is a **static shell + client-side fetch**:

```chemical
#html {
    <div class="course-grid" id="course-grid" aria-live="polite">
        <div class="course-loading">Loading courses…</div>
    </div>
    <noscript>
        <p class="course-loading">Enable JavaScript, or open <a href="/api/courses">/api/courses</a>.</p>
    </noscript>
}

// in #js (or a *_assets.ch render function):
function loadHomeCourses() {
    var grid = document.getElementById('course-grid');
    if(!grid) { return; }
    fetch('/api/courses').then(function(r) { return r.json(); }).then(function(courses) {
        if(!courses || courses.length === 0) {
            grid.innerHTML = '<div class="course-loading">No courses available yet.</div>';
            return;
        }
        var html = '';
        var ci = 0;
        while(ci < courses.length) {
            var c = courses[ci];
            var ctitle = escapeHtml(c.title || c.id);
            var cdesc = escapeHtml(c.description || '');
            html += '<div class="course-card">';
            html += '<h3>' + ctitle + '</h3>';
            html += '<p>' + cdesc + '</p>';
            html += '<a href="/courses/' + encodeURIComponent(c.id) + '">…</a>';
            html += '</div>';
            ci = ci + 1;
        }
        grid.innerHTML = html;
    }).catch(function() {
        grid.innerHTML = '<div class="course-loading">Could not load courses. Refresh to retry.</div>';
    });
}
loadHomeCourses();
```

Rules for the loader JS:

1. **Escape every interpolated string** with a char-loop `escapeHtml` (`&`, `<`, `>`, `"`, `'`) — no regex literals in `#js` (lexer mangles them). API data (course titles like `Demo Course <&Test>`) is untrusted markup.
2. **Hoist arithmetic before concatenation** — `#js` drops grouping parens: `"" + (i + 1)` emits as `"" + i + 1`. Call parens are preserved (emitted callbacks look like `.then((function(r){…}))` — that double-wrapping is expected, not a bug).
3. **`while` loops**, not `for`.
4. **Render loading / empty / error states** into the same container; add a `<noscript>` fallback outside it.

References: `web/src/home_assets.ch::render_home_js`, `web/src/pages_onboarding.ch::loadCourses`, `content/src/course_landing.ch` + `course_landing_assets.ch`.

## Pattern: Page Assets File (250-Line Rule)

A page handler that would exceed 250 lines moves its `#css` and `#js` into a sibling `<page>_assets.ch` — same namespace, plain (private) functions taking `page : &mut HtmlPage`:

```chemical
// web/src/home_assets.ch
public namespace underlayer_web {

    func render_home_css(page : &mut HtmlPage) {
        #css { /* all page styles */ }
    }

    func render_home_js(page : &mut HtmlPage) {
        #js { /* all page JS incl. dynamic list loaders */ }
    }
}

// in handlers_home.ch, after the #html block:
render_home_css(&mut page)
render_home_js(&mut page)
send_page(res, &raw page)
```

Multiple `#css` / `#js` blocks concatenate into one `<style>` / `<script>` in call order, so extraction is behavior-preserving. `web/chemical.mod` uses `source "src"` — new files are picked up automatically, no manifest edit. References: `web/src/home_assets.ch` (extracted from `handlers_home.ch`, 309→139 lines), `content/src/course_landing_assets.ch`.

## Pattern for Concept Renderers (content/src/)

Each concept is a render function compiled into the server:

```chemical
// content/src/bytes.ch
public namespace underlayer_content {
    public func render_bytes() : string {
        var page = HtmlPage()
        page.defaultUniversalSetup()
        page.defaultPrepare()
        page.appendTitle(std::string_view("Bytes and Binary — Underlayer"))

        #html { /* lesson markup */ }
        #css  { /* scoped lesson styles */ }
        #js   { /* interactivity, ASCII only */ }

        return page.toString()
    }
}
```

**Registration is manual and required.** Add the concept ID mapping in `web/src/helpers.ch::render_concept()`:

```chemical
var new_id = std::string("my-concept")
if(cid.equals(&new_id)) { return underlayer_content::render_my_concept() }
```

Missing registration = empty page. The mapping currently covers all 24 ELF concepts (`bytes` … `execution`); unknown IDs return an empty string.

## Pattern for Pre-Rendered Static Emission (courses/elf/src/)

The course module mirrors 3 concepts for GitHub-Pages-style static output:

```chemical
// courses/elf/src/bytes.ch — same shape as content/src version
public func render_bytes() : std::string { ... return page.toString() }

// courses/elf/src/main.ch — build entry that writes output files
```

`courses/elf/chemical.mod` imports `"../../content"` and `"../../core"` — reuse the content renderers instead of duplicating markup when possible.

## Universal Components

Universal components provide SSR + hydration. They work inside `#html { }` blocks and render on both server and client.

> **⚠️ Current Status (2026-09-17):** the platform pages use plain HTML inside `#html { }` with scoped `#css` and vanilla JS in `#js { }` — this remains the safe default. No JSX-style component is rendered by any page in this repo yet; if you adopt the `components` library for a widget, check `implementation_gaps` for known `#universal` converter bugs first.

### When to Use Universal Components

| Use Case | Approach |
|----------|----------|
| Static course content (lessons, quizzes) | Plain `#html` + `#js` — simpler, no hydration needed |
| Interactive widgets shared across pages | `#universal` component — SSR + hydration (check `implementation_gaps` bugs first) |
| Stateful UI (toggles, tabs, dialogs) | `#universal` component with `useState` (same caveat) |
| Design system components (Button, Card, Badge) | Plain HTML with CSS — what every current page does |

### Universal Component Pattern

```chemical
// components/src/ProgressBar.ch

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

### Usage in Pages

```chemical
#html {
    <div class="lesson">
        <h1>Your Progress</h1>
        <ProgressBar value={3} max={12} />
    </div>
}
```

### Key Rules

1. **CSS goes in a `*_styles` function** that returns `#css { }` — this emits a hashed class name
2. **Component is `public #universal ComponentName(props)`** — the `#universal` keyword triggers SSR + hydration
3. **Props are accessed via `props.name`** — `props.children` for nested content
4. **Use `data-*` attributes for state-driven CSS** — not inline `style` (which gets wiped by hydration)
5. **Import `components` module** for design system primitives (Button, Card, Badge, etc.)

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

### CSS for Stateful Components

```chemical
#css {
    .concept-card { border: 1px solid hsl(var(--border)); border-radius: 8px; }
    .concept-header { display: flex; justify-content: space-between; padding: 1rem; cursor: pointer; }
    .concept-content { padding: 0 1rem 1rem; }
    .arrow { transition: transform 0.2s; }
    .arrow.rotated { transform: rotate(90deg); }
}
```

### Component File Organization

```
content/
  components/
    ProgressBar.ch        # Reusable progress indicator
    HexViewer.ch          # Interactive hex dump viewer
    Quiz.ch               # Quiz with options and feedback
    ConceptCard.ch        # Expandable concept card
    NavigationBar.ch      # Course navigation (prev/next)
  src/
    bytes.ch              # Uses components from content/components/
    binary_representation.ch
```

### Module Imports for Universal Components

```chemical
// web/chemical.mod (as implemented)
module underlayer_web
source "src"
import std
import cstd
import http
import json
import fs
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components
import "../core"
import "../database"
import "../models"
import "../repository"
import "../content"

// content/chemical.mod (as implemented)
module underlayer_content
source "src"
import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import "../core"
```

### Gotchas

- **Hydration wraps children** in an extra `<div>` — style both direct children and one nesting level
- **Inline `style` gets wiped** by hydration — use `data-*` attributes + CSS selectors for state
- **`props.children` is `SsrText`** — a lightweight string view, not a full string
- **Non-ASCII in JS blobs crashes** — keep all runtime JS ASCII-safe
- **`createPortal` for overlays** — menus/dialogs that escape `overflow: hidden` ancestors
