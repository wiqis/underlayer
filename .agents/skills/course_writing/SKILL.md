# Course Writing Skill — For AI Agents

**Load this BEFORE writing any course content.** This is the practical, in-the-trenches guide for writing Chemical .ch course files. Not theory — patterns, mistakes, and examples.

> **This is a living document.** As AIs write courses and discover what works, update this skill with new patterns. Every section ends with a "Discovered Patterns" block for this purpose.

---

## The 30-Second Checklist

Before writing ANY .ch file, verify:

- [ ] I have the concept's prerequisites loaded
- [ ] I know what the 8-unit structure requires for this concept
- [ ] I have verified ALL hex bytes, offsets, and struct layouts
- [ ] I know which Chemical syntax pitfalls apply (no `+` for strings, `if` requires `else`, etc.)
- [ ] I have the correct imports for the module
- [ ] I understand the exercise types available

---

## Step-by-Step Writing Process

### Step 1: Read the Concept Definition
```json
{
  "id": "elf-header",
  "title": "The ELF Header",
  "prerequisites": ["bytes", "binary-representation"],
  "importance": "critical",
  "estimated_minutes": 15,
  "misconceptions": [
    "The ELF header is just metadata (it's actually parsed first and determines how to read everything else)",
    "All ELF headers are the same size (varies by class: 32-bit=52 bytes, 64-bit=64 bytes)"
  ]
}
```

**Before writing, you must know:**
- What prerequisites to reference (don't assume they know it)
- What misconceptions to address proactively
- How important this concept is (determines depth)
- Estimated time (don't exceed it)

### Step 2: Write the WHY Unit (First!)
Every lesson MUST start with WHY. Not "The ELF header is..." but "When you run `readelf -h`, how does the system know where the program headers are? The ELF header tells it."

**Template:**
```markdown
## WHY

When you [common action], [what happens]. But how does [system] know [question]?

The [concept] answers this by [one-sentence explanation].

Without it, [what would go wrong].
```

**Anti-patterns:**
- Starting with a definition: "The ELF header is a structure..." (bad)
- Starting with a fact: "The ELF header is 64 bytes..." (bad)
- Starting with a question the learner cares about: "How does readelf -h work?" (good)

### Step 3: Write Each Unit Sequentially
Don't skip units. Don't reorder them. The 8-unit structure is defined in `docs/course-design.md` (Lesson Structure section):
1. WHY → 2. MODEL → 3. REALITY → 4. EXAMPLE → 5. INTERACT → 6. RETRIEVE → 7. APPLY → 8. CONNECT

### Step 4: Write Exercises AFTER All Units
Exercises test the FULL lesson, not individual units. Write them last.

### Step 5: Verify Your Own Output
Run through this checklist before submitting:
- [ ] Every hex byte is real (verified with `readelf` or `xxd`)
- [ ] Every offset is correct (counted from file start)
- [ ] Every struct field name matches the spec
- [ ] Every exercise has exactly one correct answer
- [ ] Every prerequisite is referenced (not assumed)
- [ ] Every misconception is addressed
- [ ] Chemical syntax is valid (no `+` for strings, `if` has `else`, etc.)

---

## Chemical Syntax for Course Files

### CRITICAL: NEVER use string appends for HTML/CSS/JS

**This is non-negotiable. If you write `body.append_view("<div>")` or any string-based HTML, you are wrong.**

- **HTML**: ALWAYS use `#html { }` macro
- **CSS**: ALWAYS use `#css { }` macro  
- **JS**: ALWAYS use `#js { }` macro

If a macro fails to parse, fix the macro compiler plugin (`html_cbi`, `css_cbi`, `js_cbi`). NEVER fall back to string concatenation.

### Course Emission Pattern

Courses are compiled to static HTML/CSS/JS files. This enables:
- **GitHub Pages serving** — no backend required
- **Offline access** — download HTML files, open in browser
- **Backend enhancement** — server adds user features on top

Each concept file emits a complete HTML page:

```chemical
// courses/elf/src/bytes.ch  (also content/src/bytes.ch for the server-rendered path)
public func render_bytes() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()                 // camelCase — this is what compiles
    page.appendTitle(&title)              // title : string_view built beforehand

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <p>Full lesson content here...</p>
        </div>
    }

    #css { .lesson { max-width: 800px; } }
    #js { function selectByte(el) { /* ... */ } }

    return page.toString()  // Complete HTML page
}
```

**Method casing warning:** HtmlPage methods are camelCase in this codebase — `defaultPrepare()`, `defaultUniversalSetup()`, `injectDefaultComponentsTheme()`, `appendTitle(...)`, `toString()`. The snake_case spellings (`default_prepare`, `to_string`, `append_title`) seen in older documents do not compile.

The build entry calls all render functions and writes output:

```chemical
// courses/elf/src/main.ch
public func main() : int {
    var bytes_html = render_bytes()
    write_output("output/bytes.html", &raw bytes_html)
    return 0
}
```

**Output structure:**
```
courses/elf/output/
├── index.html        # Course landing page
├── bytes.html        # Concept page
├── bytes.css         # Scoped styles
├── bytes.js          # Interactive behavior
└── manifest.json     # Metadata for static serving
```

**Key rule:** Every course page must be a complete, standalone HTML file. No external API calls required. All interactivity is client-side JS. Progress stored in localStorage when no backend.

### Using Universal Components in Course Pages

Course pages can use universal components for interactive widgets. Import the component, use it inside `#html`:

```chemical
// courses/elf/src/bytes.ch
import components    // For Card, Button, Badge, etc.
import "../content/components/ProgressBar"   // Custom course components

public func render_bytes() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>

            <!-- Use built-in Card component -->
            <Card>
                <CardTitle>Key Insight</CardTitle>
                <CardBody>
                    <p>A byte is just a number from 0 to 255.</p>
                </CardBody>
            </Card>

            <!-- Use custom ProgressBar component -->
            <ProgressBar value={3} max={12} />

            <!-- Plain HTML for static content -->
            <div class="hex-dump">
                <pre>7f 45 4c 46</pre>
            </div>
        </div>
    }

    #css { .lesson { max-width: 800px; } }
    #js { function selectByte(el) { /* ... */ } }

    return page.toString()
}
```

### When to Use Components in Courses

| Situation | Approach |
|-----------|----------|
| Static lesson content | Plain `#html` — simpler, no hydration overhead |
| Interactive quiz with state | `#universal Quiz` component — SSR + hydration |
| Progress indicator | `#universal ProgressBar` — re-renders on state change |
| Design system elements (buttons, cards) | Built-in `components` — consistent styling |
| Hex viewer / code explorer | Custom `#universal HexViewer` — stateful interaction |

### Component Import Pattern for Courses

```chemical
// courses/elf/chemical.mod
module elf_course
source "src"
import std
import cstd
import page
import html_cbi
import css_cbi
import js_cbi
import components                              // Design system
import "../../content/components/ProgressBar"  // Custom course components
import "../../content/components/Quiz"         // Custom quiz component
```

### The #html Block Pattern
```chemical
#html {
    <div class="lesson">
        <h1>The ELF Header</h1>
        <p>Every ELF file starts with a 64-byte header (for 64-bit).</p>

        @{if(show_hex) {
            #html {
                <div class="hex-dump">
                    <pre>00000000: 7f 45 4c 46 02 01 01 00</pre>
                </div>
            }
        }}
    </div>
}
```

**Rules:**
- `@{}` for Chemical logic (if, for, while)
- `#html { }` for HTML output inside `@{}`
- Never split an HTML element across `#html` blocks
- Use CSS variables, not hardcoded colors

### The #css Block Pattern
```chemical
#css {
    .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
    .hex-dump { background: var(--bg-muted); padding: 1rem; border-radius: 8px; font-family: 'JetBrains Mono', monospace; }
    .hex-byte { display: inline-block; width: 2ch; margin-right: 0.5ch; }
    .hex-byte:hover { background: var(--primary); color: white; cursor: pointer; }
}
```

### The #js Block Pattern
```chemical
#js {
    function checkAnswer(btn, correct) {
        if(correct) {
            btn.classList.add('correct');
            showFeedback('Correct!', 'success');
        } else {
            btn.classList.add('incorrect');
            showFeedback('Not quite. Try again.', 'error');
        }
    }
}
```

**Keep JS minimal.** Only for:
- Quiz answer checking
- Hex viewer interactions
- Toggle visibility
- Simple animations

### Imports Pattern
```chemical
import page
import html_cbi
import css_cbi
import js_cbi
```

For universal components:
```chemical
import components
import universal_cbi
```

---

## Exercise Patterns

### Multiple Choice
```chemical
#html {
    <div class="exercise">
        <h3>What is the ELF magic number?</h3>
        <div class="options">
            <button class="option" onclick="checkAnswer(this, false)">01 02 03 04</button>
            <button class="option" onclick="checkAnswer(this, true)">7f 45 4c 46</button>
            <button class="option" onclick="checkAnswer(this, false)">fe ed fa ce</button>
            <button class="option" onclick="checkAnswer(this, false)">de ad be ef</button>
        </div>
        <div class="feedback"></div>
    </div>
}
```

**Important:** Use `onclick="fn(args)"` (HTML attribute string), NOT `onclick={fn(args)}` (JSX syntax). Chemical's `#html` macro produces standard HTML attributes.

### Fill-in-the-Blank
```chemical
#html {
    <div class="exercise">
        <h3>Complete the command:</h3>
        <p>$ <span class="blank" contenteditable="true"></span> -h hello</p>
        <button onclick="checkFill(this, 'readelf')">Check</button>
    </div>
}
```

### Hex Inspector
```chemical
#html {
    <div class="exercise">
        <h3>Click on the magic number bytes:</h3>
        <div class="hex-viewer">
            <span class="hex-byte" onclick="selectByte(this, 0)">7f</span>
            <span class="hex-byte" onclick="selectByte(this, 1)">45</span>
            <span class="hex-byte" onclick="selectByte(this, 2)">4c</span>
            <span class="hex-byte" onclick="selectByte(this, 3)">46</span>
            <span class="hex-byte" onclick="selectByte(this, 4)">02</span>
        </div>
    </div>
}
```

---

## Common AI Mistakes (And How to Avoid Them)

### Mistake 1: Over-Explaining
**Bad:** "The ELF header is a structure that contains various fields that describe the contents of the ELF file, including but not limited to the magic number, the class, the data encoding, the version, and many other fields that are essential for the proper interpretation of the file."

**Good:** "The ELF header tells the system how to read the file. First field: magic number (`7f 45 4c 46`). Without it, the OS doesn't know this is an ELF."

### Mistake 2: Skipping WHY
**Bad:** "The ELF header is 64 bytes for 64-bit files."

**Good:** "When you run `readelf -h`, how does it know where the program headers are? The ELF header is at byte 0 and points to everything else."

### Mistake 3: Invented Examples
**Bad:** `00 11 22 33 44 55 66 77` (made up)

**Good:** `7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00` (real ELF header bytes)

### Mistake 4: No Active Learning
**Bad:** "The ELF header contains the class field at offset 4."

**Good:** "Open the hex dump. Find offset 4. What's the value? (Answer: `02` = 64-bit)"

### Mistake 5: Wrong Difficulty Curve
**Bad:** Start with full ELF header struct, then explain magic number.

**Good:** Start with magic number, then class, then build up to full header.

### Mistake 6: Missing Connections
**Bad:** "The ELF header has a field `e_phoff`."

**Good:** "Remember `e_phoff`? It points to the program headers we learned about in the previous concept."

### Mistake 7: Inconsistent Terminology
**Bad:** Use "header", "struct", "descriptor" interchangeably.

**Good:** Always use "ELF header" (not "header struct" or "file descriptor").

### Mistake 8: No Verification
**Bad:** Assume hex bytes are correct.

**Good:** Run `readelf -h` on a real ELF file and copy the output.

### Mistake 9: Wrong Chemical Syntax
**Bad:** `var msg = "Hello" + " World"` (no `+` for strings)

**Good:** `var msg = string("Hello "); msg.append_view(" World")`

### Mistake 10: Forgetting `else`
**Bad:** `if(condition) { showHint() }`

**Good:** `if(condition) { showHint() } else {}`

---

## Patterns That Work

### Pattern 1: Concrete Before Abstract
Show the real thing first, then explain it.

```markdown
## EXAMPLE

Here's a real ELF header (first 64 bytes of `/bin/ls`):

00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
00000010: 03 00 3e 00 01 00 00 00 60 10 40 00 00 00 00 00
...

## MODEL

The first 4 bytes (`7f 45 4c 46`) are the magic number.
Bytes 4-5 (`02`) indicate 64-bit class.
```

### Pattern 2: Error-Focused Teaching
Show what goes WRONG, not just what's right.

```markdown
## What Happens If the Magic Number Is Wrong?

$ readelf -h corrupted.elf
readelf: Error: Not an ELF file - invalid magic number

The kernel also rejects it:
$ ./corrupted.elf
bash: ./corrupted.elf: cannot execute binary file: Exec format error
```

### Pattern 3: Multiple Representations
Show the same data in different formats.

```markdown
## The Magic Number

Hex:    `7f 45 4c 46`
ASCII:  `.ELF`
Binary: `01111111 01000101 01001100 01000110`

All three represent the same 4 bytes.
```

### Pattern 4: Spaced Repetition
Reference previous concepts.

```markdown
## PROGRAM HEADERS

Remember the program headers from the previous concept?
The ELF header's `e_phoff` field tells us where they start.
```

### Pattern 5: Progressive Disclosure
Start simple, add complexity.

```markdown
## The ELF Header (Simplified)

The ELF header tells the system:
1. "This is an ELF file" (magic number)
2. "I'm 64-bit" (class)
3. "Here's where the program headers are" (e_phoff)

## The ELF Header (Complete)

| Field | Offset | Size | Description |
|-------|--------|------|-------------|
| e_ident | 0 | 16 | Magic + class + data + OS |
| e_type | 16 | 2 | ET_EXEC, ET_DYN, etc. |
...
```

### Pattern 6: Real Commands
Show actual terminal output.

```markdown
## EXERCISE

Run these commands on a real ELF file:

$ file /bin/ls
/bin/ls: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV)...

$ readelf -h /bin/ls
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
```

---

## Verification Checklist

Before submitting ANY .ch file, verify:

### Content Accuracy
- [ ] Every hex byte matches a real ELF file (run `xxd` or `readelf`)
- [ ] Every offset is counted from byte 0 (not from previous field)
- [ ] Every struct field name matches the gABI spec exactly
- [ ] Every command example works on a real system
- [ ] Every "why" explanation is technically accurate

### Chemical Syntax
- [ ] No `+` for string concatenation (use `append_view()`)
- [ ] Every `if` has an `else`
- [ ] No `0.5` for float (use `0.5f`)
- [ ] No `arr[i]` (use `arr.get(i)`)
- [ ] `#html` blocks are not split across elements
- [ ] `@{}` is used for Chemical logic in `#html`

### Pedagogy
- [ ] WHY unit comes first
- [ ] One concept per lesson (don't bundle)
- [ ] Prerequisites are referenced, not assumed
- [ ] Misconceptions are addressed proactively
- [ ] Exercises test understanding, not memorization
- [ ] Feedback explains WHY, not just "correct/incorrect"

### Completeness
- [ ] All 8 units are present
- [ ] At least 3 exercises per concept
- [ ] Review items are generated
- [ ] Sources are cited (spec section, RFC, etc.)

---

## End-to-End .ch File Template

This is a complete, working template for a concept page. Copy and adapt it.

```chemical
import page
import html_cbi
import css_cbi
import js_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()
    page.appendTitle(std::string_view("Concept Title — Underlayer"))

    #html {
        <div class="lesson">
            <h1>Concept Title</h1>

            <!-- UNIT 1: WHY (always first) -->
            <section class="unit why">
                <h2>WHY</h2>
                <p>When you <code>run some command</code>, how does it know [question]?</p>
                <p>The [concept] answers this by [one-sentence explanation].</p>
                <p>Without it, [what would go wrong].</p>
            </section>

            <!-- UNIT 2: MODEL (simplified, marked as simplified) -->
            <section class="unit model">
                <h2>MODEL</h2>
                <p>For now, think of [concept] as [simple model].</p>
                <div class="callout">
                    <strong>This is simplified.</strong> [What it misses]. We'll fix that next.
                </div>
                <p>The [concept] tells the system:</p>
                <ol>
                    <li>[Point 1]</li>
                    <li>[Point 2]</li>
                    <li>[Point 3]</li>
                </ol>
            </section>

            <!-- UNIT 3: REALITY (actual technical detail) -->
            <section class="unit reality">
                <h2>REALITY</h2>
                <p>The specification says [exact quote with section reference].</p>
                <p>In detail:</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Offset</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>[field]</td><td>[offset]</td><td>[size]</td><td>[description]</td></tr>
                    </tbody>
                </table>
            </section>

            <!-- UNIT 4: EXAMPLE (real, verified hex dump) -->
            <section class="unit example">
                <h2>EXAMPLE</h2>
                <p>Here's a real [thing] (from <code>/bin/ls</code>):</p>
                <div class="hex-dump">
                    <pre>[verified hex dump from readelf/xxd]</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>[Step 1 explanation]</li>
                    <li>[Step 2 explanation]</li>
                </ol>
            </section>

            <!-- UNIT 5: INTERACT (hands-on) -->
            <section class="unit interact">
                <h2>INTERACT</h2>
                <p>Run this on your system:</p>
                <pre><code>$ [command]</code></pre>
                <p>[What to look for]</p>
            </section>

            <!-- UNIT 6: RETRIEVE (free recall, no hints) -->
            <section class="unit retrieve">
                <h2>RETRIEVE</h2>
                <p>Without looking back: [question]?</p>
                <div class="reveal">
                    <button onclick="this.parentElement.classList.toggle('revealed')">Show Answer</button>
                    <div class="answer">[answer]</div>
                </div>
            </section>

            <!-- UNIT 7: APPLY (exercise) -->
            <section class="unit apply">
                <h2>APPLY</h2>
                <p>[Exercise prompt]</p>
                <div class="exercise">
                    <!-- Exercise content here -->
                </div>
            </section>

            <!-- UNIT 8: CONNECT (link to next concept) -->
            <section class="unit connect">
                <h2>CONNECT</h2>
                <p>This connects to [related concept] because [reason].</p>
                <p>Next: [next concept] → [what it teaches].</p>
            </section>

            <!-- EXERCISES (after all units) -->
            <section class="exercises">
                <h2>EXERCISES</h2>
                <!-- Add 3-4 exercises here -->
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .unit { margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid var(--border); }
        .unit:last-child { border-bottom: none; }
        .callout { background: var(--bg-muted); padding: 1rem; border-radius: 8px; border-left: 3px solid var(--primary); margin: 1rem 0; }
        .hex-dump { background: var(--bg-muted); padding: 1rem; border-radius: 8px; overflow-x: auto; }
        .hex-dump pre { font-family: 'JetBrains Mono', monospace; font-size: 0.875rem; margin: 0; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid var(--border); text-align: left; }
        th { background: var(--bg-muted); }
        .reveal .answer { display: none; margin-top: 0.5rem; padding: 1rem; background: var(--bg-muted); border-radius: 8px; }
        .reveal.revealed .answer { display: block; }
        .reveal.revealed button { display: none; }
        .options { display: flex; flex-direction: column; gap: 0.5rem; }
        .option { padding: 0.75rem 1rem; border: 1px solid var(--border); border-radius: 8px; cursor: pointer; text-align: left; }
        .option:hover { background: var(--bg-hover); }
        .option.correct { border-color: #22c55e; background: #22c55e10; }
        .option.incorrect { border-color: #ef4444; background: #ef444410; }
        .feedback { margin-top: 1rem; padding: 1rem; border-radius: 8px; display: none; }
    }

    #js {
        function checkAnswer(btn, correct) {
            var options = btn.parentElement.querySelectorAll('.option');
            options.forEach(function(opt) { opt.disabled = true; });
            if(correct) {
                btn.classList.add('correct');
                showFeedback(btn.parentElement.nextElementSibling, 'Correct!', 'success');
            } else {
                btn.classList.add('incorrect');
                showFeedback(btn.parentElement.nextElementSibling, 'Not quite. [Explanation].', 'error');
            }
        }

        function showFeedback(el, msg, type) {
            el.textContent = msg;
            el.style.display = 'block';
            el.style.background = type === 'success' ? '#22c55e10' : '#ef444410';
            el.style.borderLeft = type === 'success' ? '3px solid #22c55e' : '3px solid #ef4444';
        }
    }

    return page.toString()
}
```

---

## Advanced Patterns

### Pattern: Multi-Section Exercise with Hint Cascade

For exercises that guide learners through difficulty levels:

```chemical
<section class="exercise">
    <h3>Identify the fields in this hex dump:</h3>
    <div class="hex-dump">
        <pre>00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00</pre>
    </div>

    <div class="hints">
        <button class="hint-btn" onclick="showHint(this, 0)">Hint 1: The first 4 bytes are special</button>
        <button class="hint-btn" onclick="showHint(this, 1)">Hint 2: They spell something in ASCII</button>
        <button class="hint-btn" onclick="showHint(this, 2)">Hint 3: .ELF</button>
    </div>
</section>
```

### Pattern: Hex Dump with Clickable Bytes

For exercises where learners identify fields by clicking:

```chemical
<div class="hex-interactive">
    <span class="hex-byte" data-field="magic" onclick="selectByte(this)">7f</span>
    <span class="hex-byte" data-field="magic" onclick="selectByte(this)">45</span>
    <span class="hex-byte" data-field="magic" onclick="selectByte(this)">4c</span>
    <span class="hex-byte" data-field="magic" onclick="selectByte(this)">46</span>
    <span class="hex-byte" data-field="class" onclick="selectByte(this)">02</span>
    <span class="hex-byte" data-field="data" onclick="selectByte(this)">01</span>
</div>
```

### Pattern: Side-by-Side Comparison

For showing before/after or correct/incorrect:

```chemical
<div class="comparison">
    <div class="side correct">
        <h4>Correct</h4>
        <pre>7f 45 4c 46 02 01 01 00</pre>
        <p>This is a valid ELF header start.</p>
    </div>
    <div class="side incorrect">
        <h4>Corrupted</h4>
        <pre>00 00 00 00 02 01 01 00</pre>
        <p>readelf rejects this: "invalid magic number"</p>
    </div>
</div>
```

### Pattern: Progressive Reveal

For building up complexity step by step:

```chemical
<div class="progressive-reveal">
    <div class="step" id="step1">
        <h4>Step 1: Just the magic number</h4>
        <pre>7f 45 4c 46</pre>
        <button onclick="revealNext('step2')">Add class byte</button>
    </div>
    <div class="step hidden" id="step2">
        <h4>Step 2: Add class</h4>
        <pre>7f 45 4c 46 02</pre>
        <button onclick="revealNext('step3')">Add data encoding</button>
    </div>
    <div class="step hidden" id="step3">
        <h4>Step 3: Add data encoding</h4>
        <pre>7f 45 4c 46 02 01</pre>
    </div>
</div>
```

### Pattern: Terminal Exercise

For exercises that simulate running commands:

```chemical
<div class="terminal">
    <div class="terminal-header">
        <span class="dot red"></span>
        <span class="dot yellow"></span>
        <span class="dot green"></span>
        <span class="title">bash</span>
    </div>
    <div class="terminal-body">
        <div class="line">
            <span class="prompt">$</span>
            <span class="command" contenteditable="true" data-answer="readelf -h /bin/ls"></span>
        </div>
        <div class="output" id="terminal-output"></div>
    </div>
</div>
```

### Pattern: Embedded Interactive Assessment (client-side runner)

Use this when a lesson needs a **long, multi-question, scored assessment** — a
baseline diagnostic, a mock exam, a placement test — rather than one inline
quiz. The reference implementation is the HAT course's baseline diagnostic
(`content/src/hat_diagnostic_*.ch`), a 100-question / 120-minute mock.

**Why it must be a client-side runner.** `#html` blocks cannot contain loops
(`@{}` is broken — see `docs/implementation-gaps.md`), so you cannot server-loop
100 questions into markup. The sanctioned pattern is a static shell plus JS that
renders the questions and keeps state in `localStorage`, which also makes it work
in both static and backend modes (golden rule: backend-optional).

**File layout — split into three files (no file over 250 lines):**

| File | Concern |
|------|---------|
| `<concept>.ch` | The lesson page. Static `#html` shell with a root div, plus calls to the two support render functions. |
| `<concept>_bank.ch` | Question data as a `#js` array of objects. One question per line. |
| `<concept>_runner.ch` | `#css` for the test UI + `#js` runner (start, timer, navigation, submit, scoring, report). |

**Shell in the lesson file:**

```chemical
render_hat_lesson_css(&mut page)
render_hat_diagnostic_css(&mut page)

#html {
    <div class="unit unit-diagnostic">
        <h2>Take Your Baseline Diagnostic</h2>
        <p>...instructions...</p>
        <div id="hat-diag-root" class="hat-diag"><p>Loading the diagnostic&hellip;</p></div>
        <noscript><p>The diagnostic needs JavaScript.</p></noscript>
    </div>
}

render_hat_lesson_js(&mut page)
render_hat_diagnostic_bank(&mut page)   // defines HAT_DIAG_QUANT / VERBAL / ANALYTICAL
render_hat_diagnostic_js(&mut page)     // the runner
```

**Question data shape** (one line per question; `p` is an optional passage):

```chemical
#js {
    var HAT_DIAG_QUANT = [
        { q: "What is 15 percent of 240?", o: ["24", "36", "45", "16"], a: 1, e: "10 percent is 24 and 5 percent is 12." },
        { q: "Solve for x: 3x + 7 = 22.", o: ["3", "5", "15", "9.67"], a: 1, e: "3x = 15, so x = 5." }
    ];
}
```

**Runner rules (all verified against the compiler):**

1. **Build DOM with `createElement` + `textContent`, never HTML strings.** Golden
   rule 7 forbids string-built HTML; the JS counterpart is to create nodes, not
   `innerHTML += "<div>..."`.
2. **Multiple `#css` / `#js` blocks concatenate** into one `<style>` / `<script>`
   (`page.toString()` joins `pageCss` / `pageJs`), so one helper function per
   concern is safe — call order is execution order.
3. **No grouping parentheses in expressions.** The `#js` converter drops them in
   non-JSX mode, so `(a + b) * c` emits as `a + b * c` and `"" + (i + 1)` emits
   as `"" + i + 1`. Hoist: `var label = i + 1; ... "" + label`. Call parentheses
   (`f(x, y)`) and object literals are preserved.
4. **No regex literals** — the lexer mangles `/.../`. Use string methods.
5. **Avoid closure-over-loop bugs.** `for` + `var` shares one binding; build a
   handler factory (`function handler(idx) { return function() { ... }; }`).
6. **Keep JS strings ASCII.** The converter escapes non-ASCII to `\u{...}`; use
   `|` or `-` instead of `·`/`—`.
7. **Persist to `localStorage` inside `try/catch`** so `file://` and private mode
   fail silently. Save an in-progress record for resume, and clear it on submit.
8. **Auto-submit on timeout** from the same tick that updates the countdown.

**Scoring / report:** store the correct index (`a`) per question; compute a total
and a per-section `{correct, wrong, blank}` breakdown; render a table and an
interpretation band (e.g. below/above a pass line); persist the result under one
key; offer a retake that clears the key.

**Verify before shipping:**

- Extract the served `<script>` and run `node --check` on it (catches converter
  mangling).
- Drive the runner with a stub DOM in Node: answer every question with the key
  and assert `total === max`; answer none and assert 0; check resume and retake.
- Add a `@test` that fetches the lesson and asserts the bank + runner markers are
  present (see `tests/src/hat_test.ch`).
- The concept linter skips `*_bank.ch` / `*_runner.ch` as support files.

---

## Error Recovery Patterns

### When You Discover Invented Hex Bytes

**Symptom:** You wrote hex bytes without verifying them.

**Fix:**
1. Stop writing immediately
2. Run `readelf -h`, `xxd`, or `objdump` on a real file
3. Copy the actual output
4. Replace all invented bytes with verified bytes
5. Mark the concept as `[NEEDS VERIFICATION]` until confirmed

### When Chemical Code Won't Compile

**Symptom:** The .ch file has syntax errors.

**Checklist:**
- [ ] Every `if` has an `else`
- [ ] No `+` on strings (use `append_view`)
- [ ] Float literals use `f` suffix (0.5f not 0.5)
- [ ] No `arr[i]` (use `arr.get(i)`)
- [ ] `#html` blocks are not split
- [ ] `@{}` used for Chemical logic inside `#html`

### When Exercise Has No Clear Answer

**Symptom:** You can't explain why one answer is correct.

**Fix:**
1. Rewrite the question to be more specific
2. Ensure exactly one answer is correct
3. Write the explanation BEFORE the wrong answers
4. If you can't explain it, the question is bad — rewrite it

### When Feedback Is Just "Wrong"

**Symptom:** Exercise feedback says "Not quite" without explaining why.

**Fix:**
1. For EACH wrong answer, explain what's wrong about it
2. Connect the explanation to what the learner should have remembered
3. Reference the specific unit where this was taught

```chemical
// BAD feedback
showFeedback(el, 'Not quite.', 'error');

// GOOD feedback
showFeedback(el, 'Not quite. The magic number is always 7f 45 4c 46 (bytes 0-3). Bytes 4-5 indicate the class, not the magic. See the EXAMPLE unit above.', 'error');
```

## Discovered Patterns

> **Update this section as AIs write courses and discover what works.**

### Pattern: The "Run It Yourself" Approach
**Discovered:** AIs that tell learners to run commands on real files produce better engagement than AIs that only show static output.
**Works because:** Learners build muscle memory and confidence by doing, not just reading.

**Example:**
```markdown
## TRY IT

$ xxd -l 64 /bin/ls
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0300 3e00 0100 0000 6010 4000 0000 0000  ..>.....`.@.....
```

### Pattern: The "What If It Breaks" Approach
**Discovered:** Explaining failure modes is more memorable than explaining success paths.
**Works because:** Learners remember errors better than correct behavior (negativity bias).

**Example:**
```markdown
## WHAT IF e_ident[EI_DATA] IS WRONG?

If the data encoding byte says big-endian but the file is little-endian:
- All multi-byte fields are read backwards
- e_type becomes garbage
- The kernel rejects the file

$ ./broken-elf
bash: ./broken-elf: cannot execute binary file: Exec format error
```

### Pattern: The "Build Up" Approach
**Discovered:** Starting with a minimal version and adding fields one by one works better than showing the full struct.
**Works because:** Reduces cognitive load — learner sees each piece before the whole.

**Example:**
```markdown
## MINIMAL ELF HEADER

Just the magic number:
7f 45 4c 46

Add the class:
7f 45 4c 46 02

Add the data encoding:
7f 45 4c 46 02 01

Keep going until you have all 64 bytes.
```

### Pattern: Feedback for Every Wrong Answer
**Discovered:** Exercises with feedback only on the correct answer teach less than exercises with feedback on ALL options.
**Works because:** Learners who chose wrong learn WHY they're wrong, not just that they're wrong.

**Example:**
```markdown
**Correct!** The magic number is `7f 45 4c 46` — `.ELF` in ASCII.

**If you chose A:** Those are just sequential bytes, not a recognized magic number.

**If you chose C:** That's the Java class file magic (`0xCAFEBABE`), not ELF.

**If you chose D:** That's `0xDEADBEEF`, a debug pattern, not a file magic number.
```

### Pattern: The "Before You Start" Checklist
**Discovered:** AIs that check prerequisites before writing produce more consistent content.
**Works because:** Prevents introducing concepts before their prerequisites are established.

**Example (from a real generation session):**
```markdown
Before writing "Program Headers", I verified:
- [x] "Bytes" concept exists and covers byte ordering
- [x] "ELF Header" concept exists and teaches e_phoff
- [x] "File Layout" concept exists and explains segments vs sections
- [x] I know the prerequisite order: bytes → binary-representation → file-layout → elf-header → program-headers
```

### Pattern: The "Hex Dump Sandwich"
**Discovered:** A hex dump followed by explanation followed by the SAME hex dump with annotations is more effective than either alone.
**Works because:** First showing primes attention; second showing with annotations provides the payoff.

**Example:**
```markdown
## RAW HEX

00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

## ANNOTATED

00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
           |___________| |__| |__| |_______________________|
            magic number  class data        padding
                           64-bit LE      (ignored)
```

### Pattern: The "Misconception Trap"
**Discovered:** Explicitly stating "You might think X, but actually Y" is more effective than just stating Y.
**Works because:** It catches the misconception before it solidifies.

**Example:**
```markdown
## COMMON MISTAKE

You might think the ELF header is just metadata you can skip.
Actually, it's parsed FIRST — without it, the loader doesn't know
how to read anything else in the file.
```

### Pattern: Assessment as Data + Runner
**Discovered:** A long scored assessment (baseline diagnostic, mock exam) is
cleanest as two support files — a `#js` question bank and a `#js` runner — with
the lesson holding only a static root div. Keeps each file small, keeps the
questions reviewable one-per-line, and works offline via `localStorage`.
**Works because:** `#html` cannot loop, so the list must be rendered client-side
anyway; separating data from behaviour makes both testable. See
"Embedded Interactive Assessment (client-side runner)" above.

**Example (HAT baseline diagnostic):** `content/src/hat_diagnostic_test.ch` (shell)
+ `hat_diagnostic_bank.ch` (100 questions) + `hat_diagnostic_runner.ch` (timed
runner + scoring + report).

---

## Related Skills

| Skill | When to Load |
|-------|--------------|
| `course_generation` | For the 11-phase iterative cycle |
| `course_architecture` | For file structure and module organization |
| `learning_design` | For pedagogical methodology |
| `implementation_gaps` | For Chemical syntax pitfalls |
| `technical_research` | For verifying technical claims |
| `engineering_patterns` | For content validation patterns |
