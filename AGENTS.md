# AGENTS.md — Underlayer

Read this before touching any code or content. Also load the relevant skill from `.agents/skills/`.

## Golden Rules

1. **Learning is the product.** Every decision must answer: "Does this help someone understand something deeply?"
2. **Courses are permanent artifacts.** They are generated once, then improved for years. Never treat content as disposable.
3. **Verify everything.** AI-generated content is presumed incorrect until verified against authoritative sources (specs, RFCs, source code).
4. **No feature exists because other platforms have it.** Every feature must justify itself against Underlayer's educational purpose.
5. **Depth over volume.** One excellent course beats 100 mediocre ones.
6. **The platform serves the course.** If there's a choice between improving a course and adding a platform feature, the course wins.
7. **NEVER use string appends for HTML/CSS/JS.** ALL HTML must use `#html { }` macro. ALL CSS must use `#css { }` macro. ALL JS must use `#js { }` macro. If the macro has a bug, fix the macro compiler plugin (`html_cbi`, `css_cbi`, `js_cbi`). NEVER work around macro bugs with string concatenation. This is non-negotiable.

## AI Constraint System

Every AI agent working on Underlayer must follow these constraints:

### Content Generation Constraints

1. **Never generate a course in one pass.** Follow the iterative cycle: Research → Generate → Verify → Test → Critique → Improve → Re-verify → Repeat.
2. **Never claim a source says something without consulting it.** No hallucinated citations.
3. **Always distinguish** specification facts, conceptual models, implementation details, and simplifications.
4. **Every technical example must be verifiable.** No invented byte sequences, offsets, or data.
5. **Every exercise must be checked** for correctness, ambiguity, solvability, and consistency.
6. **Identify likely misconceptions** for every important concept and address them proactively.
7. **Teach relationships, not isolated facts.** Every concept must connect to: why it exists, who produces/consumes it, what depends on it, what happens if it's invalid.
8. **Progress from simple models toward reality.** Explicitly mark simplifications as models, then replace them with accurate models later.

### Design Constraints

1. **No passive reading as default.** Every concept must be followed by active use.
2. **No decorative interactivity.** Every interaction must answer: "What does this help the learner understand?"
3. **No meaningless badges, streaks, or leaderboards.** Gamification must serve learning.
4. **Normalize struggle.** Show "This is supposed to be hard" not "You're failing."
5. **Respect energy.** Allow pacing controls. Prevent overactivity-underactivity cycling.
6. **Assume the learner forgets.** Build retrieval into every session. Never punish forgetting.

### Technical Constraints

1. **Chemical language** for all implementation. This is how we find what's missing in Chemical.
2. **Universal components used carefully.** Known bugs exist — use with awareness. Prefer simple HTML for course content.
3. **Multi-module architecture** with strict layering (see Architecture section).
4. **No SQL outside repository layer.** No raw HTML outside `#html` blocks.
5. **Auto-deploy on commit.** Code must be correct before merge — no "fix it later."
6. **Reuse existing libraries.** Don't rebuild SQLite, HTTP server, JSON, or page rendering from scratch. See `docs/plan.md` for available libraries.
7. **MANDATORY: Use macros for all markup.** `#html { }` for HTML, `#css { }` for CSS, `#js { }` for JavaScript. String-based HTML construction (`body.append_view("<div>...")`) is FORBIDDEN. If a macro fails to parse, fix the CBI plugin — never fall back to strings.

## Architecture

```
src/main.ch              (wiring only — route registration, context building)
   ↓
web/                     (public pages, API routes, static file serving, FSRS engine)
   ↓
content/                 (course loading, lesson rendering)
   ↓
repository/              (ALL SQL lives here — schema + CRUD)
   ↓
models/                  (plain domain structs — no business logic)
database/                (dual-backend: SQLite local + Turso HTTP remote)
   ↓
core/                    (config, logging, string+time utils)
```

A layer may only call layers below it. If you are tempted to run SQL inside `web/`, stop — add a repository function instead.

## Dual-Mode Architecture (Static + Backend)

Underlayer courses work in TWO modes. This is a core architectural constraint.

### Mode 1: Static (GitHub Pages — No Backend)

Courses are compiled to static HTML/CSS/JS files. Served via GitHub Pages.
- **No server required.** Anyone can take the course from a URL.
- **Settings stored in localStorage.** Progress, preferences, bookmarks — all client-side.
- **Offline-first.** Download the HTML files, open in browser, works without internet.
- **Emission:** Chemical source files → `#html`/`#css`/`#js` macros → HtmlPage → `.html` + `.css` + `.js` files → committed to repo → served by GitHub Pages.

### Mode 2: Backend (Full Server — Account Management)

The same courses, plus user accounts, profiles, analytics, and adaptive learning.
- **User accounts.** Email/password, OAuth, profile management.
- **Server-side progress.** Spaced repetition schedules, learning history, knowledge health.
- **Adaptive flow.** FSRS engine adjusts difficulty based on performance.
- **Cross-device sync.** Progress follows the learner across devices.
- **API endpoints.** JSON APIs for course data, progress, reviews.

### Course Design Rule: Backend-Optional

Every course MUST work without a backend. This means:

1. **Course content is self-contained HTML.** No API calls required to render lessons.
2. **All interactivity is client-side JS.** Quizzes, hex viewers, code editors — all work offline.
3. **Progress detection is optional.** If no backend, progress stays in localStorage.
4. **Backend enhances, never gates.** Backend adds features (sync, analytics) but never blocks content.

### How Courses Are Built

```
courses/elf/
├── chemical.mod              # Module declaration
├── manifest.json             # Metadata (id, title, modules, concepts)
├── src/
│   ├── main.ch               # Build entry — calls render functions
│   ├── bytes.ch              # Concept: uses #html + #css + #js macros
│   └── ...
└── output/                   # Generated (committed to repo)
    ├── index.html            # Course landing page
    ├── bytes.html            # Concept page
    ├── bytes.css             # Scoped styles
    ├── bytes.js              # Interactive behavior
    └── manifest.json         # Copy of metadata for static serving
```

### Build Commands

```bash
# Compile course to static HTML
cmake-build-debug/TCCCompiler courses/elf/chemical.mod \
    -o courses/elf/build/elf-pages.exe --mode debug_quick
./courses/elf/build/elf-pages.exe
# → writes courses/elf/output/*.html + *.css + *.js

# The output/ directory is committed to repo
# GitHub Pages serves it directly

# The backend server ALSO serves these files
# Plus provides API endpoints for user features
```

### Emission Pattern in Chemical

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
| Email reminders | Background worker |

### Existing Libraries Used

| Module | Reuses | Location |
|--------|--------|----------|
| `database/` | SQLite3 bindings | `lang/compiled/sqlite3/` |
| `database/` | Turso HTTP client | `lang/compiled/academic/libturso/` |
| `web/` | HTTP server + routing | `lang/libs/server/` |
| `web/` | HTTP client (for Turso) | `lang/libs/http/` |
| `web/` | JSON parse/stringify | `lang/libs/json/` |
| `content/` | HtmlPage builder | `lang/libs/page/` |
| `content/` | #html macro | `lang/libs/html_cbi/` |
| `content/` | #css macro | `lang/libs/css_cbi/` |
| `content/` | #js macro | `lang/libs/js_cbi/` |
| `content/` | #md macro | `lang/libs/md_cbi/` |
| `content/` | UI components | `lang/libs/components/` |

## Universal Components

Underlayer uses the `#universal` macro for interactive components with SSR + hydration.

### When to Use Universal Components

| Use Universal | Use Plain HTML |
|---------------|----------------|
| Interactive widgets (quizzes, hex viewers, code editors) | Static lesson content |
| Components with `state` (form inputs, toggles, accordions) | Simple text paragraphs |
| Components reused across multiple concepts | One-off visual elements |
| Components needing client-side interactivity | Server-rendered static layouts |

### Theme Setup (Required)

Always inject the theme before using components:

```chemical
import components
import page
import html_cbi
import css_cbi
import js_cbi

public func render_page() : std::string {
    var page = HtmlPage()
    page.default_prepare()
    page.inject_default_components_theme()

    #html {
        <Container size="lg">
            <Card>
                <CardBody>
                    <!-- component content -->
                </CardBody>
            </Card>
        </Container>
    }

    return page.to_string()
}
```

### Component Patterns

**Quiz with feedback:**
```chemical
#universal QuizWidget(props) {
    state selected = -1
    state answered = false
    var correct = props.correct_index

    #html {
        <Stack direction="column" gap="sm">
            @{var i = 0
            while(i < props.options.size()) {
                var idx = i
                var variant = "outline"
                if(answered && idx == selected) {
                    if(idx == correct) { variant = "success" }
                    else { variant = "destructive" }
                }
                if(answered && idx == correct) { variant = "success" }
                #html {
                    <Button variant={variant} disabled={answered} onClick={...}>
                        {props.options.get(idx)}
                    </Button>
                }
                i = i + 1
            }}
            @{if(answered) {
                #html {
                    <Alert variant={selected == correct ? "success" : "error"}>
                        <AlertBody>{props.explanation}</AlertBody>
                    </Alert>
                }
            }}
        </Stack>
    }
}
```

**Progress tracking:**
```chemical
#universal ProgressTracker(props) {
    var mastered = props.mastered
    var total = props.total
    var pct = if(total > 0) { (mastered * 100) / total } else { 0 }

    #html {
        <Card>
            <CardBody>
                <Stack direction="row" justify="space-between">
                    <Text>Progress</Text>
                    <Caption>{mastered}/{total}</Caption>
                </Stack>
                <Progress value={pct} max={100} variant="success" />
            </CardBody>
        </Card>
    }
}
```

### Component Gotchas

1. **No `if` without `else`**: Chemical requires else for every if block
2. **State only with `state` keyword**: `var` doesn't create reactive signals
3. **Loops use `while` not `for`**: `while(i < n) { ... i = i + 1 }`
4. **No inline if expressions**: Extract to variable: `var x = if(c) { a } else { b }`
5. **Vector access**: Use `.get_ptr(i)` not `.get(i)` for mutable access
6. **String comparison**: Use `.equals()` not `==`
7. **Pointer types**: `&string` vs `*string` — check function signatures
8. **Theme required**: Always call `page.inject_default_components_theme()` first

## Build / Run / Verify

### Platform (Web Server)

```bash
# Build
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o lang/compiled/underlayer/build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Run (blocks terminal — use Start-Process or separate terminal)
./lang/compiled/underlayer/build/underlayer.exe

# Run in background (PowerShell)
Start-Process -FilePath "./lang/compiled/underlayer/build/underlayer.exe" -NoNewWindow

# Verify (smoke test)
curl localhost:9000/api/health
curl localhost:9000/courses/elf/lessons/bytes
```

### Course Pages (Pre-rendered)

```bash
# Build course pages
cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
    -o lang/compiled/underlayer/courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules

# Generate HTML output
./lang/compiled/underlayer/courses/elf/build/elf-pages.exe
# → writes courses/elf/output/*.html + *.css + *.js
```

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `PORT` | Server port | `9000` |
| `DATABASE_URL` | SQLite file path or Turso HTTP URL | `./underlayer.db` |
| `DATABASE_TOKEN` | Turso auth token (empty for local) | (empty) |
| `COURSES_DIR` | Course content directory | `./courses` |

## Course File Structure

Each course is a self-contained directory:

```
courses/
  elf/
    chemical.mod              (module declaration — imports page, html_cbi, etc.)
    manifest.json             (metadata, version, module sequence)
    src/
      main.ch                 (build entry — calls render functions, writes output/)
      bytes.ch                (concept page: #html + #css + #js → HtmlPage)
      binary-representation.ch
      file-layout.ch
      elf-header.ch
      program-headers.ch
      sections.ch
      symbols.ch
      relocations.ch
      dynamic-linking.ch
    output/                   (generated — pre-rendered HTML/CSS/JS)
      bytes.html + bytes.css + bytes.js
      elf-header.html + elf-header.css + elf-header.js
      ...
    assets/
      samples/                (real ELF files for exercises)
      images/
```

### Course Concept File Pattern

Each concept is a Chemical source file that generates an HTML page:

```chemical
import page
import html_cbi
import css_cbi
import js_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    page.appendTitle(std::string_view("Concept Title — Underlayer"))

    #html {
        <div class="lesson">
            <h1>Concept Title</h1>
            <p>Explanation...</p>
            <div class="quiz">...</div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
    }

    #js {
        function checkAnswer(btn, correct) { ... }
    }

    return page.toString()
}
```

## Where to Add Things

| Task | Place |
|---|---|
| New course | `courses/<name>/` with `chemical.mod` + `manifest.json` + `src/` |
| New concept | `courses/<name>/src/<concept>.ch` (uses #html + #css + #js) |
| New exercise type | `learning/src/exercise_types/` |
| New visualization | Inside concept .ch files (using #html + #js) |
| New platform feature | Relevant module (`web/`, `learning/`, `repository/`) |
| Schema change | `database/src/schema.ch` + matching model struct |
| New API endpoint | `web/src/main.ch` (add route) |

## Skills

Load the relevant skill before working on a particular area:

| Skill | Use When |
|---|---|
| `product_architecture` | Understanding the overall system design |
| `learning_design` | Designing how concepts are taught and tested |
| `course_architecture` | Structuring course content and progressions |
| `user_flows` | Designing screens, writing routes, implementing user interactions |
| `micro_interactions` | Adding tooltips, toasts, keyboard shortcuts, bookmarks, notes, dark mode, skeletons |
| `engineering_patterns` | Error handling, logging, security, caching, testing, monitoring, privacy — the "boring but critical" stuff |
| `course_writing` | Practical guide for writing .ch course files: patterns, mistakes, Chemical syntax, exercises |
| `libs_reference` | Complete catalog of available libraries: std, page, server, http, json, fs, encoding, components, sqlite3, Turso |
| `coding_conventions` | Style rules, naming conventions, and patterns extracted from the actual codebase |
| `implementation_gaps` | Writing code, generating content, debugging — documents all known bugs and limitations |
| `technical_research` | Researching authoritative sources for course topics |
| `course_generation` | Using AI to generate course content |
| `review_quality` | Reviewing and verifying generated content |
| `deployment` | Android app, auto-deployment, CI/CD |
| `components` | Using shadcn-style UI components (Card, Button, Alert, Badge, Progress, etc.) |
| `universal_components` | Building interactive universal components with SSR + hydration |

## Key Documents

| Document | When to Read |
|---|---|
| `docs/plan.md` | Before starting work — 6-phase roadmap, available libraries, database strategy |
| `docs/implementation-details.md` | Before writing code — concrete code patterns, library usage, module wiring |
| `docs/implementation-gaps.md` | Before writing code or generating content — known bugs, language limitations, verification patterns |
| `docs/user-flows.md` | Before designing screens or writing routes — every screen, action, and data flow |
| `docs/conceptual-model.md` | Before designing data models — Course, Concept, Exercise, LearnerState |
| `docs/course-development-handbook.md` | Before generating any course content — step-by-step 7-phase process |
| `docs/ai-course-writing-constraints.md` | Before any AI generation — 8 constraint methods, negative constraints |
| `docs/ui-ux-design.md` | Before building any UI — colors, typography, components, accessibility |
| `docs/micro-interactions.md` | Before adding any tiny UI feature — info buttons, shortcuts, toasts, bookmarks, notes, skeletons |
| `docs/implementation-patterns.md` | Before writing any code — blind spots checklist: error handling, logging, security, caching, testing, monitoring, privacy |
| `docs/ai-course-writing-guide.md` | Before writing any course content — 10 mistakes, 10 patterns, Chemical syntax, verification checklist |
| `docs/ai-course-writing-examples.md` | When writing exercises or lessons — concrete good vs bad examples |
| `docs/libs-reference.md` | Before writing code — complete catalog of available libraries and APIs |
| `docs/coding-conventions.md` | Before writing code — style rules, naming, patterns from codebase |
| `docs/teaching-components-catalog.md` | Before building any component — complete catalog of teaching primitives |
| `docs/rendering-pipeline.md` | Before building content rendering — how .ch files become interactive HTML |
| `docs/developable-components.md` | Before AI generates components — what's AI-generatable vs human-engineered |
| `docs/course-design.md` | Before designing lessons — 8-unit structure, 5 exposures, anxiety design |
| `docs/features.md` | Before implementing features — 10 core + 6 advanced feature specs |
| `docs/competitors.md` | Before making design decisions — what others do, what we do better |
| `docs/deployment.md` | Before setting up CI/CD — auto-deploy pipeline, Android app |
| `docs/learner-profiling.md` | Before designing onboarding or adaptation — IRT, behavioral profiling, CLSI |
| `docs/adaptive-flow-ui.md` | Before designing UI flows — screen-by-screen, anxiety/depression design |
| `docs/correctness-verification.md` | Before verifying course content — 5-layer verification system |
| `docs/reusable-components.md` | Before building or using universal components — complete guide with patterns |

## Gotchas

- **Universal components require theme injection.** Always call `page.inject_default_components_theme()` before using components. Components will not render correctly without it.
- **No `if` without `else`.** Chemical requires an else block for every if statement. Use `if(cond) { ... } @else { }` even for empty else blocks.
- **State only with `state` keyword.** Using `var` for reactive state won't create signals. Use `state` for anything that needs to update the UI.
- **Loops use `while`, not `for`.** Chemical doesn't have C-style for loops. Use `while(i < n) { ... i = i + 1 }`.
- **No inline if expressions.** Extract to variable: `var x = if(c) { a } else { b }`.
- **Vector access**: Use `.get_ptr(i)` not `.get(i)` for mutable access. `.get()` returns a copy.
- **String comparison**: Use `.equals()` not `==` for string equality.
- **Pointer types**: `&string` ≠ `*string`. Check function signatures carefully.
- **Chemical is young.** Some features may not exist yet. Document gaps, work around them.
- **Courses must be portable.** No platform-specific dependencies inside course content.
- **AI generation is iterative.** Never accept first-pass content as final.
- **Retrieval is not optional.** Every session must include review of previously learned material.
- **No SQLite in std libs.** Use the existing `lang/compiled/sqlite3/` package or the dual-backend pattern from `lang/compiled/cars/database/`.
- **Course pages are pre-rendered.** The compiler generates static HTML/CSS/JS files. The server serves these files — it does not render pages on every request.
- **Always verify ELF content.** Every hex dump, byte offset, and struct layout must be verified against `readelf` output or the gABI spec. No invented byte sequences.
