# Course Architecture Skill

Load this skill when structuring course content, concept dependencies, or lesson formats.

> **Also load `engineering_patterns`** for content validation patterns (manifest validation, concept file validation, exercise verification). This skill covers *how courses are structured*; `engineering_patterns` covers *how to validate them*.

> **Also load `course_writing`** for the practical guide to writing .ch files: common mistakes, Chemical syntax, exercise patterns. This skill covers *course file structure*; `course_writing` covers *how to write each file*.

## Course File Structure

```
courses/
  elf/
    chemical.mod                    (module declaration)
    manifest.json                   (metadata, version, concept list)
    src/
      main.ch                       (build entry — calls render functions, writes output/)
      bytes.ch                      (concept page: #html + #css + #js → HtmlPage)
      binary-representation.ch
      file-layout.ch
      elf-header.ch
      program-headers.ch
      sections.ch
      symbols.ch
      relocations.ch
      dynamic-linking.ch
    output/                         (generated — pre-rendered HTML/CSS/JS)
      bytes.html + bytes.css + bytes.js
      elf-header.html + elf-header.css + elf-header.js
      ...
    assets/
      samples/
        hello.elf
        libcrypto.so
        malformed.elf
      images/
        elf-layout.svg
        ...
```

## Course chemical.mod

```chemical
application elf_course

source "src"

import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import universal_cbi
import components              // platform universal components (Button, Card, etc.)
import "./components"          // course-specific components (optional)
```

### Import Rules

| Import | When to Use |
|--------|-------------|
| `page` | Always — HtmlPage builder |
| `html_cbi` | Always — `#html` macro for JSX-like HTML |
| `css_cbi` | Always — `#css` macro for scoped styles |
| `js_cbi` | When page has interactivity — `#js` macro |
| `universal_cbi` | When using `#universal` component definitions |
| `components` | When using platform components (Button, Card, Input, etc.) |
| `"./components"` | When course defines its own components |

## Manifest Format

```json
{
  "id": "elf",
  "title": "ELF — Executable and Linkable Format",
  "version": 1,
  "description": "Understand the ELF binary format from first principles",
  "prerequisites": [],
  "estimated_hours": 20,
  "modules": [
    {
      "id": "fundamentals",
      "title": "Fundamentals",
      "order": 1,
      "concepts": ["bytes", "binary-representation", "file-layout"]
    },
    {
      "id": "elf-header",
      "title": "ELF Header",
      "order": 2,
      "concepts": ["identification", "header-fields", "entry-point"]
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
  "assets": [
    "assets/samples/hello.elf",
    "assets/samples/libcrypto.so"
  ]
}
```

## Concept Dependency Graph (ELF)

```
Bytes
  ↓
Binary Representation
  ↓
File Layout
  ↓
ELF Identification
  ↓
ELF Header Fields
  ↓
Entry Point
  ↓
Program Header Table ──→ Segment Types ──→ Memory Mapping
  ↓
Section Header ──→ Common Sections ──→ Section vs Segment
  ↓
Symbol Table ──→ Binding ──→ Visibility
  ↓
Relocation Types
  ↓
Dynamic Section ──→ Libraries ──→ ld.so
  ↓
Loader ──→ Memory Layout ──→ Execution
```

## Concept File Format

Each concept is a Chemical source file that generates an HTML page using CBI macros. Course content can use platform universal components (Button, Card, etc.) or define course-specific components.

### Simple Concept (No Universal Components)

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
            <header class="lesson-header">
                <h1>Bytes and Binary</h1>
                <div class="lesson-meta">15 min · Core concept</div>
            </header>

            <section class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every piece of data in a computer — text, images, programs — is stored as bytes.</p>
            </section>

            <section class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <div class="quiz" id="quiz-1">
                    <p class="quiz-question">How many distinct values can a single byte represent?</p>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">64</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, true)">256</button>
                    <div class="quiz-feedback"></div>
                </div>
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem; margin: 0.5rem 0; }
    }

    #js {
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            options.forEach(function(opt) { opt.disabled = true; });
            if(correct) { btn.classList.add('correct'); }
            else { btn.classList.add('wrong'); }
        }
    }

    return page.toString()
}
```

### Concept With Universal Components

```chemical
// src/elf-header.ch — Concept: ELF Header

import page
import html_cbi
import css_cbi
import js_cbi
import components           // Button, Card, Badge, etc.

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // REQUIRED for universal components
    page.defaultPrepare()
    page.appendTitle(std::string_view("ELF Header — Underlayer"))

    #html {
        <div class="lesson">
            <header class="lesson-header">
                <H1>ELF Header</H1>
                <Badge variant="outline">Core concept</Badge>
            </header>

            <section class="unit">
                <H2>Why This Matters</H2>
                <Text>The ELF header is the first thing a loader reads. It tells the system
                     how to interpret the rest of the file.</Text>
            </section>

            <section class="unit">
                <H2>The ELF Magic Number</H2>
                <Card>
                    <CardBody>
                        <div class="hex-dump">
                            <code>7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00</code>
                        </div>
                    </CardBody>
                </Card>
            </section>

            <section class="unit">
                <H2>Interactive Exploration</H2>
                <Button variant="default" onClick={showHeaderFields}>
                    Show All Fields
                </Button>
                <Button variant="outline" onClick={resetExploration}>
                    Reset
                </Button>
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
    }

    #js {
        function showHeaderFields() { /* ... */ }
        function resetExploration() { /* ... */ }
    }

    return page.toString()
}
```

### Course-Specific Components

Courses can define their own universal components in a `components/` directory:

```
courses/elf/src/components/
    HexViewer.ch        (interactive hex dump viewer)
    ElfDiagram.ch       (clickable ELF layout diagram)
    QuizFeedback.ch     (quiz result display with explanations)
```

Course-specific component example:

```chemical
// courses/elf/src/components/HexViewer.ch

import page
import html_cbi
import css_cbi
import universal_cbi

func hex_viewer_styles(page : &mut HtmlPage) : *char {
    return #css {
        background: #1e1e1e;
        color: #d4d4d4;
        padding: 1rem;
        border-radius: 6px;
        font-family: ui-monospace, monospace;
        font-size: 0.95rem;
        line-height: 1.6;
        .hex-byte {
            display: inline-block;
            width: 2ch;
            margin-right: 0.5ch;
            cursor: pointer;
            border-radius: 2px;
            &:hover { background: rgba(59, 130, 246, 0.3); }
        }
    }
}

public #universal HexViewer(props) {
    var data = props.data || ""
    var base_address = props.base_address || "0x00000000"

    return <div
        {...props}
        class={(props.className || props.class) || "" + " " + ${hex_viewer_styles(page)}}
        data-base-address={base_address}
    >{props.children}
        <span class="hex-label" style="display:block;margin-top:0.5rem;font-size:0.8rem;color:#9ca3af">{base_address}</span>
    </div>
}
```

Using course-specific components in concept files:

```chemical
// courses/elf/src/elf-header.ch

import page
import html_cbi
import css_cbi
import js_cbi
import components
import "./components/HexViewer"

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()

    #html {
        <div class="lesson">
            <H1>ELF Header</H1>
            <HexViewer data="7f 45 4c 46 02 01 01 00" base_address="0x00000000">
            </HexViewer>
        </div>
    }

    return page.toString()
}
```

## Build Entry Point

The `src/main.ch` file calls all render functions and writes output:

```chemical
// src/main.ch — Course build entry point

import std
import fs
import bytes
import binary_representation
import file_layout
import elf_header
import program_headers
import sections
import symbols
import relocations
import dynamic_linking

public func main() : int {
    fs::mkdir(std::string_view("output"))

    var bytes_html = bytes::render()
    fs::write_file(std::string_view("output/bytes.html"), bytes_html.to_view())

    var binary_html = binary_representation::render()
    fs::write_file(std::string_view("output/binary-representation.html"), binary_html.to_view())

    var file_layout_html = file_layout::render()
    fs::write_file(std::string_view("output/file-layout.html"), file_layout_html.to_view())

    var elf_header_html = elf_header::render()
    fs::write_file(std::string_view("output/elf-header.html"), elf_header_html.to_view())

    // ... render all concepts ...

    printf("Course pages generated in output/\n")
    return 0
}
```

### Build Entry Point With Theme

If the course uses the platform theme (header, footer, shared styles), import the theme module:

```chemical
// src/main.ch — Course build entry with theme

import std
import fs
import theme              // shared layout: header, footer, global styles
import bytes
import elf_header

public func main() : int {
    fs::mkdir(std::string_view("output"))

    // Each concept page gets the full theme layout
    var bytes_html = render_with_theme(bytes::render())
    fs::write_file(std::string_view("output/bytes.html"), bytes_html.to_view())

    var elf_header_html = render_with_theme(elf_header::render())
    fs::write_file(std::string_view("output/elf-header.html"), elf_header_html.to_view())

    printf("Course pages generated in output/\n")
    return 0
}

func render_with_theme(content : std::string) : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()

    theme::apply_theme(&raw page)
    theme::render_header(&raw page, null)

    // Inject the concept content into the page
    page.append_raw(content.to_view())

    theme::render_footer(&raw page)

    return page.toString()
}
```

## Learning Unit Types

Every concept follows the 8-unit structure:

| Unit | Purpose | Implementation |
|------|---------|---------------|
| WHY | Why does this exist? | `#html { <section class="unit-why">... }` |
| MODEL | Simplified mental model | `#html { <section class="unit-model">... }` |
| REALITY | Actual technical detail | `#html { <section class="unit-reality">... }` |
| EXAMPLE | Concrete, verifiable example | `#html { <section class="unit-example">... }` |
| INTERACT | Interactive exercise | `#html { <section class="unit-interact">... }` + `#js { }` |
| RETRIEVE | Active recall question | `#html { <section class="unit-retrieve">... }` + `#js { }` |
| APPLY | Exercise using knowledge | `#html { <section class="unit-apply">... }` + `#js { }` |
| CONNECT | How this relates to others | `#html { <section class="unit-connect">... }` |

## Exercise Types

Exercises are embedded in concept .ch files as interactive HTML:

| Type | HTML Pattern | JS Logic |
|------|-------------|----------|
| Multiple choice | `<button onclick="checkQuiz(...)">` | Compare selected answer, show feedback |
| Fill in blank | `<input type="text">` + `<button>` | Compare input against correct answer |
| Hex inspection | `<div class="hex-dump">` with highlighted bytes | Click bytes to reveal field names |
| Ordering | `<div class="drag-item">` elements | Drag-and-drop reordering, check against correct order |
| Debug | Code block with error + explanation | Reveal error on click |

## Visualization Types

| Type | HTML Pattern | JS Logic |
|------|-------------|----------|
| Diagram | `<svg>` or `<div>` with positioned elements | Click elements to show details |
| Hex viewer | `<table>` with byte cells + field highlights | Hover to highlight fields |
| State machine | `<svg>` with states and transitions | Click transitions to step through |
| Timeline | `<div>` with positioned events | Scroll through stages |

## Course Versioning

| Change Type | Version Bump | Example |
|---|---|---|
| Typo fix | Patch (1.0.x) | Fixed spelling |
| Content correction | Minor (1.x.0) | Fixed incorrect offset |
| New exercise | Minor (1.x.0) | Added debug exercise |
| New concept | Major (x.0.0) | Added DWARF module |
| Restructured prerequisites | Major (x.0.0) | Moved "symbols" before "sections" |

## Portability Rules

1. No platform-specific dependencies in course files
2. No database queries in course files
3. All assets are relative paths
4. Course can be opened by any compatible player
5. Course directory can be zipped and shared
6. Output is static HTML/CSS/JS — can be served from any web server or CDN

## ELF-Specific Teaching Components

> **⚠ These components are NOT yet implemented.** They are design specifications only. See `implementation_gaps/SKILL.md` for the full list of missing components. Do not reference them in generated code until they exist. Use plain `#html` + `#css` + `#js` patterns instead.

Courses teaching binary formats need specialized interactive components. These live in `courses/elf/src/components/`.

### InteractiveHexViewer

Click bytes to reveal field names, show decoded values. Used in every ELF concept.

```chemical
// courses/elf/src/components/HexViewer.ch
public #universal HexViewer(props) {
    var data = props.data || ""                              // hex string like "7f 45 4c 46"
    var base_address = props.base_address || "0x00000000"
    var fields = props.fields || ""                          // JSON array of {offset, size, name, color}
    return <div {...props}
        class={(props.className || props.class) || "" + " " + ${hex_viewer_styles(page)}}
        data-base-address={base_address}
        data-fields={fields}
    >{props.children}</div>
}
```

**Props**: `data` (hex string), `baseAddress`, `fields` (JSON: `[{offset, size, name, color, description}]`)
**Behavior**: Click a byte → highlight its field, show decoded value in sidebar

### ElfLayoutDiagram

Clickable SVG showing ELF file structure with byte offsets.

**Props**: `segments` (JSON: `[{type, offset, vaddr, size, name, color}]`)
**Behavior**: Click a segment → show details (type, offset, size, permissions)

### ByteFieldMapper

Bidirectional highlighting between struct fields and hex bytes.

**Props**: `hexBytes`, `structFields` (JSON: `[{name, offset, size, type, value}]`)
**Behavior**: Click struct field → highlight bytes. Click bytes → show field.

### MemoryMapAnimator

Shows segments being loaded from file to virtual memory.

**Props**: `fileLayout`, `memoryLayout`
**Behavior**: Animated arrows showing file→memory mapping with virtual address labels

### StructPaddingVisualizer

Shows memory layout with padding bytes highlighted.

**Props**: `fields` (JSON: `[{name, type, size, offset, alignment}]`)
**Behavior**: Shows padding bytes in red, explains alignment rules

## Verification Patterns for ELF Content

Every ELF-related claim must be verified against authoritative sources.

### Primary Sources

| Topic | Source |
|-------|--------|
| ELF specification | System V gABI: https://refspecs.linuxfoundation.org/elf/elf.pdf |
| ELF man page | Linux `elf(5)`: https://man7.org/linux/man-pages/man5/elf.5.html |
| ELF loader | Linux kernel `fs/binfmt_elf.c` |
| Reference parser | GNU binutils `readelf.c` |

### Verification Tools

| Tool | Purpose |
|------|---------|
| `readelf -a <file>` | Display all ELF headers — verify hex dumps, field sizes, offsets |
| `xxd <file>` | Hex dump — verify byte sequences |
| `objdump -d <file>` | Disassembly — verify code section content |
| `objdump -r <file>` | Relocations — verify relocation entries |
| `nm <file>` | Symbol table — verify symbol entries |
| `ldd <file>` | Dynamic dependencies — verify dynamic section |

### Verification Rule

Every hex dump, byte offset, struct layout, and field size in course content MUST be verified against `readelf` output or the gABI spec. No invented byte sequences.

### Verification Checklist

Before publishing any ELF concept:

- [ ] All hex bytes match `xxd` output for the referenced ELF file
- [ ] All struct field offsets match the gABI specification
- [ ] All enum values match `elf.h` definitions
- [ ] All memory addresses match `readelf` output
- [ ] Interactive exercises produce correct results when verified against `readelf`
- [ ] Code examples compile and run correctly
- [ ] All cross-references to other concepts are accurate

## Reusable Course Components

Courses should build reusable components that other courses can import.

### Component Reusability Rules

1. **Course-specific components** live in `courses/<name>/src/components/`
2. **Platform-reusable components** live in `lang/libs/components/`
3. Course components must NOT depend on platform components (keeps courses portable)
4. Course components depend on: `page`, `html_cbi`, `css_cbi`, `universal_cbi`
5. Every component must have a CSS style function + `#universal` component

### Components Reusable Across Binary Format Courses

> **⚠ These components are design specs, not implemented.** Build them as needed using plain `#html` + `#css` + `#js` patterns until the universal component versions exist.

| Component | Used In |
|-----------|---------|
| HexDump | ELF, PE, Mach-O, TLS, WAV, ZIP, PNG |
| MemoryLayout | ELF loading, stack/heap, pointer arithmetic |
| FileFormatDiagram | ELF, PE, Mach-O, PDF, MP4 |
| ByteToFieldMapper | Any struct-to-bytes mapping |
| EndianToggle | Any multi-endian format |

### Component Documentation Standard

Each component directory should contain:

```
components/
    HexViewer/
        HexViewer.ch      (component implementation)
        README.md         (purpose, props, usage examples)
```

## Known Gotchas for Course Authors

Load `implementation_gaps/SKILL.md` for the complete list. Key gotchas:

1. **Never store reactive values in local variables** — the converter can't detect reactivity
2. **Never toggle portaled menu with `style={...}`** — use `data-*` attributes + CSS
3. **Never pass C++ structs with `vector<>` as props** — corrupt serialization
4. **Never call functions directly as props** — hoist to local variable first
5. **Always use `.get_ptr(i)` for vector iteration** — `.get(i)` returns copy, causes double-free
6. **Always escape untrusted strings** — `#html` does not auto-escape
7. **Always verify hex bytes against `readelf`** — no invented byte sequences
