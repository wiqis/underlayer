# Underlayer Frontend Guide

## Universal Components — Quick Reference

Underlayer uses the `components` library (Shadcn-style) with `#universal` for interactive UI. All HTML uses `#html {}`, all CSS uses `#css {}`, all JS uses `#js {}`.

### Page Setup (Required)

Every page MUST call these three methods in order:

```chemical
var page = HtmlPage()
page.defaultUniversalSetup()          // Hydration runtime JS
page.defaultPrepare()                 // Charset + viewport
page.injectDefaultComponentsTheme()   // Shadcn CSS tokens
```

### Available Components

| Category | Components |
|----------|-----------|
| **Layout** | Card, CardHeader, CardTitle, CardDescription, CardContent, CardBody, CardFooter |
| **Typography** | H1, H2, H3, H4, H5, H6, Text, Lead, Caption, Link, CodeText, Blockquote |
| **Button** | Button, ButtonPrimary, ButtonGhost, ButtonOutline, ButtonDanger, ButtonSuccess, ButtonInfo, IconButton, Fab |
| **Badge** | Badge, BadgeAccent, BadgeSuccess, BadgeError, BadgeWarning, BadgeInfo, BadgeOutline, Chip |
| **Alert** | Alert, AlertSuccess, AlertError, AlertWarning, AlertInfo, AlertDestructive |
| **Input** | Input, TextArea, NativeSelect, InputGroup, InputIcon, Field, FieldLabel, FieldHint, FieldError |
| **Toggle** | Checkbox, Radio, Switch, RadioGroup, ToggleGroup |
| **Data** | Progress, Accordion, Tabs, Table, List, Pagination |
| **Overlay** | Dialog, Sheet, Popover, Dropdown, Tooltip, Snackbar, Toast |
| **Surface** | Paper, AppBar, Drawer, Menu, EmptyState, StatCard |
| **Avatar** | Avatar, AvatarBadge, AvatarGroup |

### Component Usage Pattern

```chemical
#html {
    <Card>
        <CardHeader>
            <CardTitle>My Page</CardTitle>
            <CardDescription>Subtitle here</CardDescription>
        </CardHeader>
        <CardBody>
            <Text>Content</Text>
            <Button variant="primary" onClick={() => handle_click()}>
                Click Me
            </Button>
        </CardBody>
    </Card>
}
```

### State Management

```chemical
#universal MyComponent(props) {
    state count = 0
    state loading = false
    state items = []

    return <div>
        <Text>Count: {count}</Text>
        <Button onClick={() => count++}>Increment</Button>
    </div>
}
```

### Hooks

| Hook | Purpose | Example |
|------|---------|---------|
| `state value = init` | Reactive state | `state open = false` |
| `useEffect(() => {}, [deps])` | Side effects | `useEffect(() => { fetch_data() }, [props.id])` |
| `useRef(null)` | DOM ref | `var input = useRef(null)` |
| `createContext("key", val)` | Parent→child context | `const ctx = createContext("theme", "light")` |
| `useContext("key")` | Consume context | `var ctx = useContext("theme")` |
| `createPortal(<jsx />, {modal})` | Render into body | Used by Dialog, Sheet, Popover |

### Portal Components (Dialog, Sheet, Popover, Dropdown)

These render into `document.body` via `createPortal`. Use for overlays/modals:

```chemical
#html {
    <Dialog>
        <DialogTrigger>
            <Button>Open</Button>
        </DialogTrigger>
        <DialogContent>
            <DialogHeader>
                <DialogTitle>Confirm</DialogTitle>
            </DialogHeader>
            <DialogBody>
                <Text>Are you sure?</Text>
            </DialogBody>
            <DialogFooter>
                <Button variant="ghost" onClick={() => close()}>Cancel</Button>
                <Button variant="primary">Confirm</Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
}
```

### Form Pattern

```chemical
#html {
    <form onSubmit={(e) => { e.preventDefault(); submit_form() }}>
        <Field>
            <FieldLabel>Email</FieldLabel>
            <Input type="email" placeholder="you@example.com" />
            <FieldHint>We'll never share your email</FieldHint>
        </Field>
        <Field>
            <FieldLabel>Password</FieldLabel>
            <Input type="password" />
            <FieldError>{password_error}</FieldError>
        </Field>
        <Button type="submit" variant="primary">Submit</Button>
    </form>
}
```

### Conditional Rendering

```chemical
#html {
    <div>
        @{if(isLoading) {
            #html { <div class="spinner">Loading...</div> }
        } else {
            #html {
                <div>
                    @foreach(item in items) {
                        #html { <Card><Text>{item.name}</Text></Card> }
                    }
                </div>
            }
        }}
    </div>
}
```

### CSS Style Functions

Components use server-side CSS functions that return class names:

```chemical
func card_styles(page : &mut HtmlPage) : *char {
    return #css {
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 1rem;
    }
}

// Usage in component:
return <div class={${card_styles(page)}}>...</div>
```

### Theming

The theme uses CSS custom properties (HSL values):

```css
--background: 0 0% 100%;
--foreground: 222.2 84% 4.9%;
--primary: 222.2 47.4% 11.2%;
--primary-foreground: 210 40% 98%;
--secondary: 210 40% 96.1%;
--muted: 210 40% 96.1%;
--accent: 210 40% 96.1%;
--destructive: 0 84.2% 60.2%;
--border: 214.3 31.8% 91.4%;
--radius: 0.5rem;
```

Override with `injectComponentsThemeScope()` for custom themes.

### App Shell / Navbar

Every server page (`web/src/*.ch`) and course landing (`content/src/*.ch`) renders the same
header: `.navbar > .nav-inner > (.nav-brand, .hamburger, .nav-links, .nav-right)`. The CSS is
duplicated per page, so keep these rules identical when editing one of them:

- `.nav-inner` — `max-width: 1400px`, `padding: 0 1.5rem`, plus `flex-wrap: wrap` with
  `row-gap`/`column-gap`, so an over-long row wraps instead of giving the whole document a
  horizontal scrollbar.
- `.nav-links` — `flex-wrap: wrap`, `flex: 0 1 auto`, `min-width: 0`, `gap: 0.25rem 0.5rem`.
- `.nav-link` — `padding: 0.5rem 0.6rem`, `white-space: nowrap`.

The collapse breakpoint depends on how many links a page renders, because that is what
decides when the row stops fitting:

| Links | Pages | Collapse |
|---|---|---|
| 10–12 | `/`, `/dashboard`, `/analytics` | `@media (max-width: 1300px)` |
| ≤6 | everything else | `@media (max-width: 768px)` |

12 links need ~1195px of content box, which is wider than the 1200px container the rest of
the page uses — so on the dense pages the hamburger must appear at 1300px, otherwise the row
wraps onto a second line between ~1200px and 1300px. A page's nav rules must include
`.hamburger { display: block; }` + the `.nav-links` dropdown rules in whichever media query
it collapses in, and the page must render the hamburger button — pages without it simply
lose their navigation below the breakpoint.

### SSR + Hydration Flow

1. **Server**: `#html { <Comp /> }` → SSR renders HTML into page buffer
2. **Server**: Component boundary = `<span id="uN" data-chx-i>...</span>`
3. **Client**: `window.$__uni_dispatch('Comp', element, props)` hydrates
4. **Client**: `$_us(val)` creates reactive signals, `$_ucs(expr)` creates computed values
5. **Client**: State changes trigger re-render of affected components only

### Critical Gotchas

1. **No `if` without `else`** — Chemical requires else for every if
2. **State only with `state` keyword** — `var` doesn't create reactive signals
3. **Loops use `while` not `for`** — `while(i < n) { ... i = i + 1 }`
4. **No inline if expressions** — Extract to variable: `var x = if(c) { a } else { b }`
5. **`.get_ptr(i)` not `.get(i)`** — For mutable vector access
6. **`.equals()` not `==`** — For string comparison
7. **`*string` ≠ `&string`** — Check function signatures carefully
8. **CSS functions are server-only** — Not available in client JS
9. **Portal boundaries** — Dialog/Sheet/Popover render outside component tree

### File Organization

```
src/
  main.ch              — Route registration, server setup
  pages/
    home.ch            — Home page (server-rendered)
    dashboard.ch       — Dashboard with components
  components/
    review_card.ch     — Reusable review card component
    progress_bar.ch    — Progress visualization
```

### Import Pattern for Apps

```chemical
// chemical.mod
import components    // Shadcn UI library
import page          // HtmlPage
import html_cbi      // #html macro
import css_cbi       // #css macro
import js_cbi        // #js macro
```
