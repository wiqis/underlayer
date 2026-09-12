# Reusable Components

Guide to building and using reusable UI components in Underlayer.

## Overview

Underlayer uses Chemical's `#universal` macro system to build reusable UI components. These components are shared between the platform and course content. Components render to HTML on the server (SSR) and hydrate on the client for interactivity.

## Component Architecture

```
lang/libs/components/        ← Platform components (Button, Card, Input, etc.)
    ↓ imported by
underlayer/theme/             ← Shared layout (header, footer, global CSS)
    ↓ imported by
underlayer/web/               ← Platform pages
    ↓ imported by
underlayer/courses/elf/       ← Course pages (use platform components)
    ↓ may also define
courses/elf/src/components/   ← Course-specific components
```

### Dependency Rules

1. **Platform components** depend on: `page`, `universal_cbi`, `css_cbi`
2. **Theme** depends on: `components`, `page`, `html_cbi`, `css_cbi`
3. **Web pages** depend on: `theme`, `components`, `page`, `html_cbi`
4. **Course pages** depend on: `components` (optional), `page`, `html_cbi`, `css_cbi`, `js_cbi`
5. **Course-specific components** depend on: `page`, `html_cbi`, `css_cbi`, `universal_cbi` (NOT on platform components — keeps courses portable)

## Defining a Universal Component

Every universal component has two parts:

### Part A: CSS Style Function

A function that returns scoped CSS via `#css` and produces a hashed class name:

```chemical
func button_styles(page : &mut HtmlPage) : *char {
    return #css {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        padding: 0.5rem 1rem;
        border-radius: 6px;
        font-size: 0.875rem;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s;
        border: 1px solid transparent;

        &[data-variant="default"] {
            background: hsl(var(--primary));
            color: white;
            &:hover { opacity: 0.9; }
        }
        &[data-variant="outline"] {
            background: transparent;
            border-color: hsl(var(--border));
            color: hsl(var(--text-primary));
            &:hover { background: hsl(var(--accent)); }
        }
        &[data-variant="ghost"] {
            background: transparent;
            color: hsl(var(--text-primary));
            &:hover { background: hsl(var(--accent)); }
        }
        &[data-size="sm"] {
            height: 2.25rem;
            padding: 0 0.75rem;
            font-size: 0.75rem;
        }
        &[data-size="lg"] {
            height: 2.75rem;
            padding: 0 2rem;
        }
        &:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
    }
}
```

### Part B: Universal Component

A `#universal` component that receives `props` and returns JSX:

```chemical
public #universal Button(props) {
    var loading = props.loading || false
    var classes = (props.className || props.class) || ""

    return <button
        {...props}
        class={classes + " " + ${button_styles(page)}}
        data-variant={props.variant || "default"}
        data-size={props.size}
        type={props.type || "button"}
        disabled={props.disabled || loading}
        aria-disabled={props.disabled || loading}
        aria-busy={loading ? "true" : "false"}
        onClick={props.onClick}
    >{loading ? "Loading..." : props.children}</button>
}
```

### Syntax Reference

| Syntax | Meaning |
|--------|---------|
| `public #universal Name(props)` | Declares a universal component |
| `props.field` | Read a prop passed from the parent |
| `props.children` | Nested content (text or other components) |
| `<div {...props}>` | Spread all props onto an element |
| `<Comp {...props} variant="ghost">` | Pass all props plus override |
| `{expr}` inside JSX | Expression interpolation |
| `${styles(page)}` inside `class={}` | Embeds a `#css`-generated class name |
| `props.variant \|\| "default"` | Default prop values |
| `state count = 0` | Reactive state (client-side only) |

## Component Families

### Button

```chemical
<Button variant="default">Submit</Button>
<Button variant="outline">Cancel</Button>
<Button variant="ghost">Close</Button>
<Button variant="destructive">Delete</Button>
<Button size="sm">Small</Button>
<Button size="lg">Large</Button>
<Button loading={true}>Saving...</Button>
```

### Card

```chemical
<Card>
    <CardBody>
        <CardTitle>Title</CardTitle>
        <CardMeta>Meta info</CardMeta>
        <CardDescription>Description text</CardDescription>
    </CardBody>
</Card>
```

### Input

```chemical
<Field>
    <FieldLabel>Email</FieldLabel>
    <Input type="email" placeholder="you@example.com" />
</Field>

<Field>
    <FieldLabel>Bio</FieldLabel>
    <TextArea placeholder="Tell us about yourself" />
</Field>

<Field>
    <FieldLabel>Country</FieldLabel>
    <NativeSelect options={["US", "UK", "CA"]} />
</Field>
```

### Badge

```chemical
<Badge variant="default">Active</Badge>
<Badge variant="secondary">Draft</Badge>
<Badge variant="outline">Pending</Badge>
<Badge variant="destructive">Error</Badge>
```

### Typography

```chemical
<H1>Page Title</H1>
<H2>Section Title</H2>
<Text>Body text with normal styling.</Text>
<Link href="/about">About page</Link>
<Heading level={3}>Dynamic heading</Heading>
```

### Separator

```chemical
<Separator />
```

### Alert

```chemical
<Alert variant="default" title="Note">Important information.</Alert>
<Alert variant="destructive" title="Error">Something went wrong.</Alert>
```

### Toggle

```chemical
<Checkbox checked={true} onChange={handler} />
<Radio name="option" value="a" />
<Switch checked={false} onChange={handler} />
```

## Using Components in Pages

```chemical
import page
import html_cbi
import css_cbi
import components

public func render_home() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // REQUIRED: hydration runtime for #universal components
    page.defaultPrepare()            // charset + viewport
    page.injectDefaultComponentsTheme()  // REQUIRED: shadcn theme CSS tokens

    #html {
        <div class="container">
            <H1>Underlayer</H1>
            <Text>Learn things deeply.</Text>

            <div class="grid-3">
                @{var idx : size_t = 0
                while(idx < courses.size()) {
                    var course = courses.get_ptr(idx)
                    idx = idx + 1
                    #html {
                        <Card>
                            <CardBody>
                                <CardTitle>{course.title}</CardTitle>
                                <CardMeta>{course.concepts} concepts</CardMeta>
                                <Button variant="outline" size="sm">
                                    <Link href={std::string("/courses/") + course.id.copy()}>Start</Link>
                                </Button>
                            </CardBody>
                        </Card>
                    }
                }}
            </div>
        </div>
    }

    #css {
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.5rem; }
    }

    return page.toString()
}
```

## Using Components in Course Content

Course concept files can use the same platform components:

```chemical
// courses/elf/src/bytes.ch

import page
import html_cbi
import css_cbi
import js_cbi
import components

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()     // hydration runtime
    page.defaultPrepare()            // charset + viewport
    page.injectDefaultComponentsTheme()  // shadcn theme tokens
    page.appendTitle(std::string_view("Bytes and Binary — Underlayer"))

    #html {
        <div class="lesson">
            <header>
                <H1>Bytes and Binary</H1>
                <Badge variant="outline">Core concept · 15 min</Badge>
            </header>

            <section>
                <H2>Why This Matters</H2>
                <Text>Every piece of data in a computer is stored as bytes.</Text>
            </section>

            <section>
                <H2>The ELF Magic Number</H2>
                <Card>
                    <CardBody>
                        <div class="hex-dump">
                            <code>7f 45 4c 46 02 01 01 00</code>
                        </div>
                    </CardBody>
                </Card>
            </section>

            <section>
                <H2>Check Your Understanding</H2>
                <div class="quiz" id="quiz-1">
                    <p>How many distinct values can a single byte represent?</p>
                    <Button variant="outline" onClick={() => checkAnswer(false)}>64</Button>
                    <Button variant="outline" onClick={() => checkAnswer(true)}>256</Button>
                    <Button variant="outline" onClick={() => checkAnswer(false)}>512</Button>
                </div>
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
    }

    #js {
        function checkAnswer(correct) {
            if(correct) { /* show success */ }
            else { /* show feedback */ }
        }
    }

    return page.toString()
}
```

## Course-Specific Components

Courses can define their own components in `src/components/`:

```
courses/elf/src/components/
    HexViewer.ch        (interactive hex dump)
    ElfDiagram.ch       (clickable ELF layout)
    QuizFeedback.ch     (quiz result with explanation)
```

### Example: Course-Specific Component

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
        overflow-x: auto;
        .hex-byte {
            display: inline-block;
            width: 2ch;
            margin-right: 0.5ch;
            cursor: pointer;
            border-radius: 2px;
            &:hover { background: rgba(59, 130, 246, 0.3); }
            &.highlighted { background: rgba(59, 130, 246, 0.5); }
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

### Using Course-Specific Components

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
import universal_cbi
import components          // platform components
import "./components"      // course-specific components
```

## Platform Theme

The theme module provides shared layout (header, footer, global CSS):

```chemical
// theme/src/main.ch

import page
import html_cbi
import css_cbi
import components

public func apply_theme(page : *mut HtmlPage) {
    #css {
        :root {
            --font-sans: system-ui, -apple-system, 'Segoe UI', sans-serif;
            --font-mono: ui-monospace, 'Cascadia Code', monospace;
            --bg: #ffffff;
            --surface: #f8f9fa;
            --text-primary: #111827;
            --text-secondary: #6b7280;
            --border: #e5e7eb;
            --primary: #2563eb;
            --primary-light: #eff6ff;
            --success: #059669;
            --success-light: #ecfdf5;
            --error: #dc2626;
            --error-light: #fef2f2;
        }
        * { box-sizing: border-box; margin: 0; }
        body { font-family: var(--font-sans); background: var(--bg); color: var(--text-primary); }
    }
}

public func render_header(page : *mut HtmlPage, active : *char) {
    #html {
        <header style="display:flex;align-items:center;justify-content:space-between;padding:1rem 2rem;border-bottom:1px solid var(--border)">
            <Link href="/"><H3>Underlayer</H3></Link>
            <nav>
                <Link href="/courses">Courses</Link>
                <Link href="/dashboard">Dashboard</Link>
            </nav>
        </header>
    }
}

public func render_footer(page : *mut HtmlPage) {
    #html {
        <footer style="padding:2rem;text-align:center;color:var(--text-secondary);border-top:1px solid var(--border)">
            <Text>Underlayer — Learn Things Deeply</Text>
        </footer>
    }
}
```

Using the theme in course pages:

```chemical
import page
import html_cbi
import css_cbi
import components
import theme

public func render() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()

    theme::apply_theme(&raw page)
    theme::render_header(&raw page, null)

    #html {
        <div class="lesson">
            <H1>Course Content</H1>
        </div>
    }

    theme::render_footer(&raw page)

    return page.toString()
}
```

## Key Implementation Details

### `page.defaultUniversalSetup()` Is Required

Every page that uses universal components MUST call `page.defaultUniversalSetup()` before any `#html` blocks. This injects the hydration runtime JS that makes client-side interactivity work.

### CSS Class Name Hashing

The `#css` macro automatically hashes class names to prevent collisions. Use `${styles(page)}` in `#html` blocks to embed hashed class names.

### `@{}` Escape for Dynamic Content

Inside `#html` blocks, use `@{Chemical code}` to exit JSX and write loops/conditionals. Re-enter JSX with nested `#html { }` blocks:

```chemical
#html {
    <div class="grid">
        @{var idx : size_t = 0
        while(idx < items.size()) {
            var item = items.get_ptr(idx)
            idx = idx + 1
            #html {
                <Card><CardBody>
                    <CardTitle>{item.title}</CardTitle>
                </CardBody></Card>
            }
        }}
    </div>
}
```

### Lambda Capture for Route Handlers

Route handlers that need database access use the `|&var|` capture syntax:

```chemical
var db = database::make_client(...)
srv.router.add("GET", "/api/courses", (|&db|(req, res) => {
    // db is captured by reference
}))
```

### Build Commands

```bash
# Build platform
cmake-build-debug/TCCCompiler lang/compiled/underlayer/chemical.mod \
    -o build/underlayer.exe --mode debug_quick --no-cache -bm-modules

# Build course pages
cmake-build-debug/TCCCompiler lang/compiled/underlayer/courses/elf/chemical.mod \
    -o courses/elf/build/elf-pages.exe --mode debug_quick --no-cache -bm-modules
```
