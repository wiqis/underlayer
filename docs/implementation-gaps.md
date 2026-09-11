# Implementation Gaps

Known bugs, language limitations, component issues, and missing infrastructure. Every AI agent working on Underlayer must read this before writing code or generating content.

## Critical: Universal Component Bugs

These bugs affect course content that uses `#universal` components. Read before using any universal component.

### Bug: Reactive Props Frozen as One-Time Values

**Impact**: Components that depend on state changes won't update.

A local variable computed before `return` is evaluated once at render and inlined as a static attribute. Only attribute expressions that directly read `state` or `props` subscribe to changes.

```chemical
// BROKEN — value freezes at mount time
var activeDesc = ""
if(open) { activeDesc = "chx-select-opt-" + highlight }
<button aria-activedescendant={activeDesc} />

// CORRECT — reactive expression directly in JSX
<button aria-activedescendant={open ? "chx-select-opt-" + highlight : ""} />
```

**Rule**: Never store reactive values in local variables. Always put the expression directly in JSX attributes.

### Bug: `var x = props.x || default` Freezes Value

**Impact**: `aria-activedescendant`, `aria-pressed`, `checked` attributes stop updating.

```chemical
// BROKEN — local variable frozen at mount
var count = props.count || 0
<span>{count}</span>

// CORRECT — use props directly
<span>{props.count || 0}</span>
```

### Bug: Portal Menu Visibility Wiped by Reactive `style`

**Impact**: Portaled menus (Select, Dropdown) lose positioning.

```chemical
// BROKEN — style={open ? "" : "display:none"} wipes floating position
style={isOpen ? "" : "display:none;"}

// CORRECT — use data attributes + CSS
data-open={isOpen ? "true" : "false"}
// CSS: &[data-open="true"] { display: grid; }
```

### Bug: C++ Structs with `vector<>` Produce Corrupt Prop Serialization

**Impact**: Garbage bytes in generated JavaScript; `JSON.parse` error in browser.

**Rule**: Never pass C++ structs with `vector<>` fields as universal component props. Pre-serialize complex data to JSON.

### Bug: Call Expressions as Props Trip 2c Temp-Local Bug

**Impact**: Incorrect code generation.

```chemical
// BROKEN — trips a 2c temp-local bug
<Input value={int_to_string(id)} />

// CORRECT — hoist first
var id_str = int_to_string(id)
<Input value={id_str} />
```

### Bug: CSS Selector Compilation Breaks Toggle Visuals

**Impact**: CSS selectors may not match expected elements.

```chemical
// BROKEN — may compile with unwanted descendant space
.chx-toggle-input[checked] + .chx-checkbox-box { ... }

// CORRECT — nest under base selector
.chx-toggle-input {
    &[checked] + .chx-checkbox-box { ... }
}
```

### Bug: Nested Universal Wrapper Breaks Icon Styling

**Impact**: Icons inside universal components may look off-center.

**Workaround**: Style both the immediate child and one nested descendant level. Verify against generated HTML, not source JSX.

### Bug: Prop Values with Single Quotes Break Generated JS

```chemical
// BROKEN — "O'Brien" produces broken JS
<Comp value={userInput} />

// CORRECT — pre-escape
var safe = js_string_escape(userInput)
<Comp value={safe} />
```

## Critical: Chemical Language Limitations

### No `try/catch`

All errors must be propagated via `Result<T,E>` or `Option<T>` with explicit pattern matching at every call site.

```chemical
// Pattern for error handling
var result = fs::read_file(path.to_view())
var Ok(content) = result else {
    printf("Error reading file\n")
    return 1
}
// Now use content safely
```

### No `defer`

Use `@delete` destructors for RAII-style cleanup. Every resource management struct must have a destructor.

### No String `+` Operator

String concatenation requires `append()`, `append_view()`, `append_string()` chains.

```chemical
// BROKEN
var url = base + "/courses/" + id

// CORRECT
var url = base.copy()
url.append_view(std::string_view("/courses/"))
url.append_string(id)
// OR use backtick templates
var url = `${base}/courses/${id}`
```

### No `vector<T>` Index Operator (`[]`)

Must use `.get(i)` for reads, `.get_ptr(i)` for writes.

```chemical
// BROKEN
var val = arr[0]

// CORRECT
var val = arr.get(0)
// For writes:
var ptr = arr.get_ptr(0)
*ptr = 42
```

### `if` Requires `else`

Every `if` block requires an `else` block. Use empty `else {}` when no action needed.

### `if` Cannot Be Used Inline as Expression

```chemical
// BROKEN
var x = if(cond) a else b

// CORRECT
var x : int
if(cond) { x = a } else { x = b }
```

### `0.5` Is `double`, Not `float`

For `float` parameters, use `0.5f`.

### `#html` Blocks Cannot Be Split

An element opened in one `#html` block must be closed in the same block.

### `#html` Does Not Auto-Escape Values

Always call `page::escape_html(value)` before embedding untrusted strings in HTML.

## Important: Chemical Gaps for Course Development

### Missing String Methods

| Method | Impact | Workaround |
|--------|--------|-----------|
| `replace()` | Cannot do find-replace in strings | Use `erase()` + `append()` |
| `to_upper()` / `to_lower()` | Cannot normalize case | Write manual loop |
| `format()` | Cannot do printf-style formatting | Use `cstd::sprintf` or backtick templates |
| `join()` | Cannot join string arrays | Write manual loop |
| `repeat()` | Cannot repeat strings | Write manual loop |
| `pad_left()` / `pad_right()` | Cannot pad strings | Write manual loop |

### Missing Vector Methods

| Method | Impact | Workaround |
|--------|--------|-----------|
| `map()` | Cannot transform vectors functionally | Write manual `for` loop |
| `filter()` | Cannot filter vectors functionally | Write manual `for` loop |
| `reduce()` | Cannot reduce vectors | Write manual `for` loop |
| `find_if()` | Cannot find first matching element | Write manual `for` loop |
| `any()` / `all()` | Cannot check predicates | Write manual `for` loop |

### Missing File I/O

| Gap | Impact | Workaround |
|-----|--------|-----------|
| No `read_entire_text_file()` | Must convert `vector<u8>` to string | `string_view(bytes.data() as *char, bytes.size())` |
| No `write_string_file()` convenience | Must extract `.data()` and `.size()` | `fs::write_text_file(path, str.data() as *u8, str.size())` |
| Callback-based `read_dir()` | Must use `std::function` for directory iteration | Use callback pattern |

### Interpreter Limitations

The following do NOT work in interpretation mode (comptime):

| Feature | Impact |
|---------|--------|
| `std::string` methods (`append`, `copy`, `to_view`) | Cannot manipulate strings at comptime |
| `std::unordered_map` | Cannot use maps at comptime |
| `std::string_view` | Cannot use string views at comptime |
| `vector<T>.get_ptr()` | Cannot get mutable pointers at comptime |
| `vector<T>` iteration via `for-in` | Cannot iterate vectors at comptime |
| `@test` annotation dispatch | Cannot use test annotations in interpret mode |

**Rule**: Avoid comptime string manipulation. Use compiled mode for course generation.

## Important: Missing Infrastructure

### No Centralized Binary Format Library

Endian helpers are duplicated across `archive/endian`, `audio/wav`, `image/png`. Need a shared `binfmt` library:

```chemical
// Proposed: lang/libs/binfmt/
public namespace binfmt {
    func read_u8(data : *u8, offset : size_t) : u8
    func read_u16_le(data : *u8, offset : size_t) : u16
    func read_u16_be(data : *u8, offset : size_t) : u16
    func read_u32_le(data : *u8, offset : size_t) : u32
    func read_u32_be(data : *u8, offset : size_t) : u32
    func read_u64_le(data : *u8, offset : size_t) : u64
    func read_u64_be(data : *u8, offset : size_t) : u64
    struct BitReader { ... }
    func read_bits(reader : *mut BitReader, count : int) : u64
    struct ByteSlice { var data : *u8; var len : size_t }
}
```

### No Pre-Built Interactive Teaching Components

The catalog defines these but none are implemented:

| Component | Needed For | Priority |
|-----------|-----------|----------|
| InteractiveHexViewer | ELF, PE, Mach-O, TLS, WAV | CRITICAL |
| ElfLayoutDiagram | ELF structure visualization | CRITICAL |
| ByteFieldMapper | Struct-to-bytes mapping | CRITICAL |
| MemoryMapAnimator | Loading process visualization | HIGH |
| StructPaddingVisualizer | C struct alignment teaching | HIGH |
| EndiannessDemo | LE/BE comparison | MEDIUM |
| BitfieldExplorer | Flag field inspection | MEDIUM |
| RelocationSimulator | Link-time relocation | HIGH |

### No SVG Generation Library

Cannot generate diagrams from Chemical code. Use `#html { <svg>...</svg> }` inline.

### No Animation Primitives

Cannot animate memory mapping. Use CSS animations via `#css` and `#js`.

## Important: Teaching Method Gaps

### Vague Thresholds That Need Concrete Numbers

| What | Current Text | Recommended Value |
|------|-------------|-------------------|
| Fatigue detection | "if accuracy drops significantly" | Accuracy drops >15% from rolling average over 5 exercises |
| Weakness detection | "when accuracy drops below 60%" | <60% correct over 5+ attempts on a single concept |
| Activity limit | "80% of perceived capacity" | Session length × 0.8, or 3 consecutive errors |
| IRT stopping criteria | "SE < 0.3" | Standard error of estimate < 0.3 (already concrete) |
| CLSI warning | "CLSI < 0.40" | CLSI below 0.40 for 2+ consecutive sessions |

### Missing State Machine Specification

The session flow has no formal state machine:

```
IDLE → WELCOME_BACK → [REVIEW | LEARN] → LESSON → EXERCISE → REVIEW_SESSION → COMPLETE
                         ↓                                              ↓
                    BREAK_SUGGESTED                              SAVE_PROGRESS → IDLE
```

What happens on: Back button? Browser close? Timeout? Network error?

### Missing API Contract

The UI screens imply server round-trips but no endpoints are specified:

| Action | Endpoint | Request | Response |
|--------|----------|---------|----------|
| Start review | `POST /api/review/start` | `course_id` | `items[]` |
| Submit rating | `POST /api/review/submit` | `item_id, rating` | `next_item` |
| Get course | `GET /api/courses/:id` | — | `Course` |
| Get lesson | `GET /api/courses/:id/lessons/:concept_id` | — | `HTML` |

### Missing Data Migration Strategy

When course content changes (concept renamed, split, merged), learner state has no migration path.

### No Multi-Course Strategy

Shared concepts between courses (e.g., "bytes" appears in ELF and TLS courses) have no cross-course tracking.

## Critical: Verification Patterns for ELF Content

Every ELF-related claim must be verified against authoritative sources:

### Primary Sources

| Topic | Source |
|-------|--------|
| ELF specification | System V gABI: https://refspecs.linuxfoundation.org/elf/elf.pdf |
| ELF man page | Linux `elf(5)`: https://man7.org/linux/man-pages/man5/elf.5.html |
| ELF loader | Linux kernel `fs/binfmt_elf.c` |
| ELF definitions | Linux `include/uapi/linux/elf.h` |
| Reference parser | GNU binutils `readelf.c` |

### Verification Tools

| Tool | Purpose |
|------|---------|
| `readelf -a <file>` | Display all ELF headers |
| `xxd <file>` | Hex dump |
| `objdump -d <file>` | Disassembly |
| `objdump -r <file>` | Relocations |
| `nm <file>` | Symbol table |
| `ldd <file>` | Dynamic dependencies |
| `gdb` + `info files` | Runtime memory layout |

### Verification Rule

Every hex dump, byte offset, struct layout, and field size in course content MUST be verified against `readelf` output or the gABI spec. No invented byte sequences.


