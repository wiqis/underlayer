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

### Step 3: Write Each Unit Sequentially
Don't skip units. Don't reorder them. The 8-unit structure is:
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
            <button class="option" onclick={checkAnswer(this, false)}>01 02 03 04</button>
            <button class="option" onclick={checkAnswer(this, true)}>7f 45 4c 46</button>
            <button class="option" onclick={checkAnswer(this, false)}>fe ed fa ce</button>
            <button class="option" onclick={checkAnswer(this, false)}>de ad be ef</button>
        </div>
        <div class="feedback"></div>
    </div>
}
```

### Fill-in-the-Blank
```chemical
#html {
    <div class="exercise">
        <h3>Complete the command:</h3>
        <p>$ <span class="blank" contenteditable="true"></span> -h hello</p>
        <button onclick={checkFill(this, 'readelf')}>Check</button>
    </div>
}
```

### Hex Inspector
```chemical
#html {
    <div class="exercise">
        <h3>Click on the magic number bytes:</h3>
        <div class="hex-viewer">
            <span class="hex-byte" onclick={selectByte(this, 0)}>7f</span>
            <span class="hex-byte" onclick={selectByte(this, 1)}>45</span>
            <span class="hex-byte" onclick={selectByte(this, 2)}>4c</span>
            <span class="hex-byte" onclick={selectByte(this, 3)}>46</span>
            <span class="hex-byte" onclick={selectByte(this, 4)}>02</span>
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

## Discovered Patterns

> **Update this section as AIs write courses and discover what works.**

### Pattern: The "Run It Yourself" Approach
**Discovered:** AIs that tell learners to run commands on real files produce better engagement than AIs that only show static output.

**Example:**
```markdown
## TRY IT

$ xxd -l 64 /bin/ls
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0300 3e00 0100 0000 6010 4000 0000 0000  ..>.....`.@.....
```

### Pattern: The "What If It Breaks" Approach
**Discovered:** Explaining failure modes is more memorable than explaining success paths.

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
