# Implementation Gaps Skill

Load this skill when writing code, generating course content, or debugging issues. Documents all known bugs, language limitations, component issues, and missing infrastructure.

> **Also load `engineering_patterns`** for error handling, logging, security, caching, testing, monitoring, and privacy patterns. This skill covers *what's broken*; `engineering_patterns` covers *how to build correctly*.

## Quick Reference: What NOT to Do

| Never Do This | Why | Do This Instead |
|---------------|-----|-----------------|
| `var x = props.x \|\| default` in universal components | Freezes value at mount | Use `props.x` directly in JSX |
| Store reactive values in local variables | Converter can't detect reactivity | Put expression directly in JSX attribute |
| Toggle portaled menu with `style={...}` | Wipes floating position | Use `data-open` + CSS |
| Pass C++ structs with `vector<>` as props | Corrupt serialization | Pre-serialize to JSON |
| Call function directly as prop: `<Comp value={fn()} />` | 2c temp-local bug | Hoist: `var s = fn(); <Comp value={s} />` |
| Use `+` for string concatenation | No operator overload | Use `append_view()` or backtick templates |
| Use `arr[i]` for vector access | No index operator | Use `arr.get(i)` or `arr.get_ptr(i)` |
| Write `if(cond) { ... }` without else | Language requires else | Always add `else {}` |
| Use `0.5` for float parameters | It's `double` | Use `0.5f` |
| Split `#html` across blocks | Element must close in same block | Use `@{}` escape for dynamic content |
| Put non-ASCII in `page.ch` JS strings | Crashes `std::string::find` | Keep ASCII only |
| Use `#css` inside `#universal` bodies | Server-only, can't appear there | Use `#css` at module level |
| Use `.get(i)` on vectors with destructible types | Returns copy, causes double-free | Use `.get_ptr(i)` |

## Universal Component Bugs (Critical)

### Reactive Props Frozen

The converter only wraps expressions in `$_ucs` (reactive subscription) when they directly reference `state` or `props` at top-level scope. Local variables computed from these are evaluated once and inlined.

**Affected attributes**: `aria-activedescendant`, `aria-pressed`, `checked`, any dynamic attribute.

**Fix**: Always put reactive expressions directly in JSX attributes. Never hoist to a local variable.

### Portal Menu Positioning

`el.style.cssText = v` wipes ALL inline styles including positioning set by `$__uni_floating`. The floating helper sets `menu.style.position/top/left/minWidth/margin/maxHeight` but a reactive `style` subscription overwrites everything.

**Fix**: Use `data-open={open ? "true" : "false"}` with CSS `&[data-open="true"] { display: grid; }`.

### Prop Serialization with Special Characters

Single quotes in string data can produce malformed JS. The `Char` variant wraps in `'...''` and escapes `'` and `\\`, but edge cases remain.

**Fix**: Pre-escape string data with `js_string_escape()`.

### Hydration Text-Doubling

When a `state` value wraps a text child during hydration, the original SSR text node was not removed, producing doubled text.

**Status**: Fixed in current codebase. Verify your build includes this fix.

### Context SSR Always Renders Unselected

Children render BEFORE the provider's SSR function. Groups render items unpressed/unchecked server-side. Selection only appears after hydration.

**Status**: By design. Do not assert `checked="true"` in SSR for children-mode groups.

## Chemical Language Limitations

### Error Handling

No `try/catch`. Use `Result<T,E>` with explicit pattern matching:

```chemical
var result = fs::read_file(path.to_view())
var Ok(content) = result else {
    printf("Error: file not found\n")
    return std::Result.Err(std::string("File not found"))
}
```

### Resource Cleanup

No `defer`. Use `@delete` destructors on structs:

```chemical
@make
public struct FileHandle {
    var fd : int
    @make func make(path : *char) : FileHandle {
        return FileHandle { fd = cstd::fopen(path, "r") as int }
    }
    @delete func delete() {
        if(self.fd != 0) { cstd::fclose(self.fd as *cstd::FILE) }
    }
}
```

### String Operations

No `+` operator for strings. Use `append_view()` chains or backtick templates:

```chemical
// Append chains
var path = base.copy()
path.append_view(std::string_view("/courses/"))
path.append_string(course_id)

// Backtick templates
var path = `${base}/courses/${course_id}`
```

### Vector Access

No `[]` operator. Use `.get(i)` for reads, `.get_ptr(i)` for writes:

```chemical
var val = vec.get(0)          // read
var ptr = vec.get_ptr(0)      // mutable pointer
*ptr = 42                      // write through pointer
```

### Conditional Logic

`if` requires `else`. No inline `if` expressions:

```chemical
// Must write:
var x : int
if(cond) { x = a } else { x = b }

// Cannot write:
// var x = if(cond) a else b
```

### Float Literals

`0.5` is `double`. For `float` parameters use `0.5f`:

```chemical
func set_volume(vol : float) { ... }
set_volume(0.5f)    // correct
set_volume(0.5)     // TypeCheck error
```

### HTML Escaping

`#html` does NOT auto-escape interpolated values. Always escape untrusted strings:

```chemical
#html {
    <div>{page::escape_html(user_input)}</div>
}
```

### Interpreter Limitations

Cannot use in comptime/interpretation mode:
- `std::string` methods (`append`, `copy`, `to_view`)
- `std::unordered_map`, `std::string_view`
- `vector<T>.get_ptr()`, `vector<T>` iteration via `for-in`
- `@test` annotation dispatch

**Rule**: Avoid comptime string manipulation. Use compiled mode for course generation.

## Missing Infrastructure

### No Centralized Binary Format Library

Endian helpers are duplicated across `archive/endian`, `audio/wav`, `image/png`. A shared `binfmt` library is needed for ELF teaching.

### No Pre-Built Interactive Teaching Components

These components are defined in the catalog but not implemented:

| Component | Priority | Needed For |
|-----------|----------|-----------|
| InteractiveHexViewer | CRITICAL | ELF, PE, Mach-O, TLS, WAV |
| ElfLayoutDiagram | CRITICAL | ELF structure visualization |
| ByteFieldMapper | CRITICAL | Struct-to-bytes mapping |
| MemoryMapAnimator | HIGH | Loading process visualization |
| StructPaddingVisualizer | HIGH | C struct alignment teaching |
| RelocationSimulator | HIGH | Link-time relocation |
| EndiannessDemo | MEDIUM | LE/BE comparison |
| BitfieldExplorer | MEDIUM | Flag field inspection |

### Missing String Methods

No `replace()`, `to_upper()`, `to_lower()`, `format()`, `join()`, `repeat()`, `pad_left()`, `pad_right()`.

### Missing Vector Methods

No `map()`, `filter()`, `reduce()`, `find_if()`, `any()`, `all()`.

### No SVG Generation Library

Cannot generate diagrams from Chemical code. Use `#html { <svg>...</svg> }` inline.

### No Animation Primitives

Cannot animate memory mapping. Use CSS animations via `#css` and `#js`.

## Verification Patterns for ELF Content

Every ELF claim must be verified against authoritative sources:

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
| `readelf -a <file>` | Display all ELF headers |
| `xxd <file>` | Hex dump |
| `objdump -d <file>` | Disassembly |
| `objdump -r <file>` | Relocations |
| `nm <file>` | Symbol table |
| `ldd <file>` | Dynamic dependencies |

### Rule

Every hex dump, byte offset, struct layout, and field size MUST be verified against `readelf` output or the gABI spec. No invented byte sequences.

## Teaching Method Thresholds

Concrete values for vague specifications:

| What | Threshold | Action |
|------|-----------|--------|
| Fatigue detection | Accuracy drops >15% from rolling average over 5 exercises | Suggest break |
| Weakness detection | <60% correct over 5+ attempts on a single concept | Flag for review |
| Activity limit | Session length × 0.8, or 3 consecutive errors | Suggest stopping |
| CLSI warning | CLSI below 0.40 for 2+ consecutive sessions | Reduce difficulty |
| IRT stopping | SE < 0.3 or 8 questions reached | End diagnostic |

## Document Redundancy Map

These concepts appear in multiple documents. The canonical source is marked with ★:

| Concept | Canonical Source | Also Appears In |
|---------|-----------------|-----------------|
| 8-unit structure | ★ `course-design.md` | `learning_design/SKILL.md`, `course-development-handbook.md` |
| Five Exposures | ★ `course-design.md` | `learning_design/SKILL.md` |
| Anxiety design | ★ `adaptive-flow-ui.md` | `course-design.md`, `learning_design/SKILL.md` |
| Exercise types | ★ `teaching-components-catalog.md` | `conceptual-model.md`, `learning_design/SKILL.md` |
| FSRS algorithm | ★ `implementation-details.md` | `features.md`, `learning_design/SKILL.md` |
| Component catalog | ★ `teaching-components-catalog.md` | `developable-components.md` |

**Rule**: When updating a concept, update the canonical source. Other documents should reference, not repeat.

## Problems Discovered During Audit

### No Bridge Between Pedagogy and Implementation

Teaching design documents are technology-agnostic. Implementation documents are Chemical-specific. No document maps "Quiz component from catalog" to "here's the `#html` code."

**Action needed**: Create `docs/pedagogy-to-implementation.md`.

### FSRS Implementation May Not Match Paper

The code uses a simplified formula. The FSRS-5 paper has a more complex model. Parameters may not produce correct scheduling.

**Action needed**: Verify against the FSRS-5 reference implementation before shipping.

### No End-to-End Test Specification

No document specifies how to verify the entire system works end-to-end.

**Action needed**: Create `docs/e2e-test-plan.md`.

### AI Constraint Pipeline Has No Error Recovery

The 8-step pipeline says "No steps may be skipped" but doesn't specify failure handling.

**Action needed**: Add error recovery to `ai-course-writing-constraints.md`.
