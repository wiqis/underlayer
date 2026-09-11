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
page.default_prepare()

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

var html = page.to_string()
res.write_view(html.to_view())
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
    page.default_prepare()

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <!-- Full lesson content -->
        </div>
    }

    #css { /* Scoped styles */ }
    #js { /* Client-side interactivity */ }

    return page.to_string()  // Complete HTML page
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

## Pattern for Route Handlers (Backend Mode)

```chemical
public func handle_page(req : &http::Request, res : *mut http::ResponseWriter) {
    var page = HtmlPage()
    page.default_prepare()
    page.append_title(std::string_view("Page Title - Underlayer"))

    #html {
        <div class="content">
            <h1>Page Title</h1>
            <p>Content here</p>
        </div>
    }

    #css {
        .content { max-width: 800px; margin: 0 auto; }
    }

    #js {
        // Interactive behavior
    }

    var ct = std::string_view("text/html; charset=utf-8")
    res.set_header_view(std::string_view("Content-Type"), &ct)
    var html = page.to_string()
    var hv = html.to_view()
    res.write_view(&hv)
}
```

## Pattern for Static Emission

```chemical
// courses/elf/src/bytes.ch
public func render_bytes() : std::string {
    var page = HtmlPage()
    page.default_prepare()
    page.append_title(std::string_view("Bytes and Binary - Underlayer"))

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <p>Every file is made of bytes...</p>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; }
    }

    #js {
        function selectByte(el) { /* ... */ }
    }

    return page.to_string()
}

// courses/elf/src/main.ch — Build entry
public func main() : int {
    var bytes_html = render_bytes()
    write_output("output/bytes.html", &raw bytes_html)
    return 0
}
```
