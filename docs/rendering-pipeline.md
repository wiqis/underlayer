# Rendering Pipeline

## Purpose

How `.ch` course files become interactive HTML pages. The complete pipeline from authoring to display.

## The Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  STAGE 1: AUTHORING                                          │
│  Chemical .ch files with annotations                         │
│  + manifest.json (metadata, dependencies, sequence)          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 2: PARSING                                            │
│  .ch file → CourseAST (typed nodes)                          │
│  Validate: syntax, required fields, component types          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 3: TRANSFORM (Offline, Cacheable)                     │
│  CourseAST → RenderedCourse                                  │
│  Resolve: component references, embeds, templates            │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 4: TRANSFORM (Per-Request, Personalized)              │
│  RenderedCourse → PersonalizedLesson                         │
│  Apply: learner state, adaptive path, energy check           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 5: RENDER                                             │
│  PersonalizedLesson → HTML + CSS + JS                        │
│  Generate: component HTML, interactive JS, state management  │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  STAGE 6: INTERACT                                           │
│  Browser executes JS, handles events, tracks progress        │
│  Generate: xAPI statements, learner state updates            │
└─────────────────────────────────────────────────────────────┘
```

## Stage 1: Authoring

### Course File Structure

```
courses/elf/
├── chemical.mod              # Module declaration (imports page, html_cbi, css_cbi, js_cbi)
├── manifest.json             # Course metadata + sequence
├── src/                      # Concept source files
│   ├── main.ch               # Build entry — calls render functions, writes output/
│   ├── bytes.ch              # Concept page using #html + #css + #js
│   ├── binary-representation.ch
│   ├── elf-header.ch
│   └── ...
├── output/                   # Generated — pre-rendered HTML/CSS/JS
│   ├── bytes.html + bytes.css + bytes.js
│   ├── elf-header.html + elf-header.css + elf-header.js
│   └── ...
└── assets/                   # Static files
    ├── samples/             # Real ELF files
    └── images/
```

### Course chemical.mod

```chemical
application elf_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
```

### Concept File Format (.ch)

Each concept is a Chemical source file that generates an HTML page:

```chemical
// src/bytes.ch — Concept: Bytes and Binary

import page
import html_cbi
import css_cbi
import js_cbi

public func render() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.appendTitle(std::string_view("Bytes and Binary — Underlayer"))

    #html {
        <div class="lesson" data-concept="bytes">
            <h1>Bytes and Binary</h1>
            <p>Every piece of data in a computer is stored as bytes.</p>

            <div class="hex-dump">
                <code>7f 45 4c 46 02 01 01 00</code>
            </div>

            <div class="quiz" id="quiz-1">
                <p>How many values can a byte represent?</p>
                <button onclick="checkQuiz('quiz-1', this, false)">64</button>
                <button onclick="checkQuiz('quiz-1', this, true)">256</button>
                <button onclick="checkQuiz('quiz-1', this, false)">128</button>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; font-family: monospace; }
        .quiz button { display: block; margin: 0.5rem 0; padding: 0.75rem; width: 100%; text-align: left; }
    }

    #js {
        function checkQuiz(id, btn, correct) {
            var quiz = document.getElementById(id);
            var feedback = quiz.querySelector('.quiz-feedback');
            if(correct) { btn.style.background = '#059669'; }
            else { btn.style.background = '#dc2626'; }
        }
    }

    return page.toString()
}
```

### Build Entry Point (src/main.ch)

```chemical
import fs
import bytes
import binary_representation
import elf_header

public func main() : int {
    fs::mkdir(std::string_view("output"))

    var bytes_html = bytes::render()
    fs::write_file(std::string_view("output/bytes.html"), bytes_html.to_view())

    var binary_html = binary_representation::render()
    fs::write_file(std::string_view("output/binary-representation.html"), binary_html.to_view())

    var elf_html = elf_header::render()
    fs::write_file(std::string_view("output/elf-header.html"), elf_html.to_view())

    printf("Course pages generated in output/\n")
    return 0
}
```

### manifest.json

```json
{
    "id": "elf",
    "name": "ELF: Executable and Linkable Format",
    "version": "1.0.0",
    "description": "Deep understanding of Linux binary format",
    "modules": [
        {
            "id": "fundamentals",
            "name": "Fundamentals",
            "concepts": ["bytes", "binary-representation", "file-layout"],
            "prerequisites": []
        },
        {
            "id": "headers",
            "name": "ELF Headers",
            "concepts": ["elf-header", "program-headers", "sections"],
            "prerequisites": ["fundamentals"]
        }
    ],
    "concepts": [
        {
            "id": "bytes",
            "title": "Bytes and Binary",
            "module": "fundamentals",
            "prerequisites": [],
            "estimated_minutes": 15,
            "importance": "core",
            "source_file": "bytes.ch"
        }
    ],
    "reviewPolicy": {
        "targetRetention": 0.85,
        "maxNewPerDay": 5,
        "maxReviewsPerDay": 20
    }
}
```

## Stage 2: Compile (Build Time)

### Input
- `.ch` concept files (using `#html`, `#css`, `#js`, `#md` macros)
- `manifest.json`

### Output
- Pre-rendered HTML + CSS + JS files in `output/` directory

### Process

```
1. TCCCompiler compiles each .ch file
2. CBI macros (#html, #css, #js, #md) transform into HtmlPage method calls
3. Each concept's render() function produces a complete HTML page string
4. main.ch writes each page to output/<concept-name>.html
5. Output includes: HTML file + embedded CSS + embedded JS
```

### Validation (Compile-time)

| Rule | Error |
|---|---|
| Missing render() function | Compiler error |
| Invalid #html syntax | Compiler error |
| Undefined variables in #js | Compiler error |
| Import errors | Compiler error |

## Stage 3: Static Files (Build Time)

### Input
- Compiled concept pages (from Stage 2)

### Output
- Pre-rendered HTML + CSS + JS files in `output/` directory

### Process

```
1. Each concept produces: <concept>.html + <concept>.css + <concept>.js
2. CSS is embedded in <style> tag in <head>
3. JS is embedded in <script> tag at end of <body>
4. All files are self-contained (no external dependencies)
5. Files are ready to serve from any HTTP server or CDN
```

### File Structure

```
courses/elf/output/
├── bytes.html          # Complete HTML page with embedded CSS + JS
├── binary-representation.html
├── file-layout.html
├── elf-header.html
├── program-headers.html
├── sections.html
├── symbols.html
├── relocations.html
└── dynamic-linking.html
```

## Stage 4: Personalization (Per-Request, Optional)

### Input
- Pre-rendered HTML page (from Stage 3)
- Learner state (from database)

### Output
- Personalized HTML page (adapted to learner)

### Process

```
1. Load learner state
   - Concept mastery (status, accuracy, streak)
   - Session history (time spent, accuracy)
   - Energy level (self-reported)

2. Apply adaptive path
   - Skip mastered concepts in navigation
   - Highlight concepts due for review
   - Insert reminder banners for forgotten concepts

3. Personalize page
   - Show/hide sections based on mastery
   - Adjust difficulty indicators
   - Add personalized review reminders
```

**Note:** For MVP, personalization is minimal. The pre-rendered page is served directly. Personalization is added via JS that reads learner state from the server.

## Stage 5: Serve

### Input
- Pre-rendered HTML + CSS + JS files (from Stage 3)

### Output
- HTTP response with complete HTML page

### Process

```
1. Request arrives: GET /api/courses/elf/lessons/bytes
2. Router matches to lesson handler
3. Handler reads courses/elf/output/bytes.html (pre-rendered)
4. Handler returns HTML file with Content-Type: text/html
5. Browser receives complete HTML page
```

### HTML Structure (Pre-rendered)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bytes and Binary — Underlayer</title>
    <style>
        /* Embedded CSS from #css { } block */
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        ...
    </style>
</head>
<body>
    <!-- Embedded HTML from #html { } block -->
    <div class="lesson" data-concept="bytes">
        <h1>Bytes and Binary</h1>
        ...
    </div>

    <script>
        /* Embedded JS from #js { } block */
        function checkQuiz(id, btn, correct) { ... }
    </script>
</body>
</html>
```

## Stage 6: Interact

### Browser Execution

```
1. Browser receives HTML page
2. CSS is parsed and applied
3. HTML is rendered
4. JS is executed:
   a. Quiz handlers are bound to buttons
   b. Hex viewer highlights are activated
   c. Interactive demos are initialized
5. User interacts:
   a. Clicks quiz option → checkQuiz() runs → feedback shown
   b. Hovers hex byte → field name highlighted
   c. Types in input → validation runs
6. Progress is tracked:
   a. Quiz results sent to server via fetch()
   b. Session data recorded
   c. Learner state updated
```

## Component Rendering Map

| Component Type | HTML Element | JS Class | Event |
|---|---|---|---|
| `Paragraph` | `<div class="paragraph">` | None (static) | None |
| `CodeBlock` | `<pre><code>` | PrismJS (highlight) | None |
| `HexDump` | `<div class="hex-viewer">` | HexViewer | click, hover |
| `Quiz` | `<div class="quiz">` | QuizComponent | select, submit |
| `FillInBlank` | `<div class="fill-blank">` | FillBlankComponent | input, check |
| `CodeEditor` | `<div class="code-editor">` | CodeMirror | input, run |
| `MemoryLayout` | `<div class="memory-diagram">` | MemoryDiagram | click, hover |
| `Flowchart` | `<svg class="flowchart">` | FlowchartSVG | click, zoom |
| `Simulation` | `<canvas>` or `<div>` | SimulationEngine | input, step |

## Caching Strategy

| Layer | What | Duration | Invalidation |
|---|---|---|---|
| CDN | Static assets (images, CSS, JS) | 1 year | Version hash |
| Redis | RenderedCourse | 1 hour | Course version change |
| Memory | PersonalizedLesson | 5 min | Learner state change |
| Database | LearnerState | Permanent | Every interaction |

## Performance Requirements

| Metric | Target |
|---|---|
| Time to First Byte | < 100ms |
| Time to Interactive | < 500ms |
| Component Render | < 50ms each |
| Total Page Render | < 200ms |
| xAPI Statement | < 100ms to send |
