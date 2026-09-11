# AI Course Writing Guide — Practical Patterns

This is the practical guide for AI agents writing Chemical course files. Not theory — patterns, mistakes, and examples from real course writing.

> **This is a living document.** Update the "Discovered Patterns" section as AIs write courses and learn what works.

> **Also load the `course_writing` skill** for the complete reference: end-to-end .ch file template, advanced interactive patterns, and error recovery. This guide covers *the process and patterns*; the skill covers *the code*.

## Quick Reference

Before writing, check this list:

| Rule | Wrong | Right |
|------|-------|-------|
| String concat | `"Hello" + " World"` | `string("Hello "); s.append_view(" World")` |
| If/else | `if(x) { }` | `if(x) { } else { }` |
| Float literal | `var x = 0.5` | `var x = 0.5f` |
| Array access | `arr[0]` | `arr.get(0)` |
| String length | `s.length()` | `s.size()` |
| #html split | `<div>` in one block, `</div>` in another | Complete element in one block |
| Chemical in HTML | `if(x) { <p>text</p> }` | `@{if(x) { #html { <p>text</p> } }}` |

---

## The Writing Process

### Before Writing
1. Read the concept definition (prerequisites, misconceptions, importance)
2. Load the `course_writing` skill
3. Load `implementation_gaps` for Chemical syntax
4. Load `technical_research` for verification
5. Check what prerequisites exist (don't assume knowledge)

### Writing Order
```
1. WHY unit (always first)
2. MODEL unit (simplified model)
3. REALITY unit (how it really works)
4. EXAMPLE unit (real examples)
5. INTERACT unit (hands-on)
6. RETRIEVE unit (recall previous)
7. APPLY unit (use knowledge)
8. CONNECT unit (link to future)
9. Exercises (after all units)
10. Review items (after exercises)
```

### After Writing
1. Verify every hex byte, offset, and struct layout
2. Check Chemical syntax (no `+` for strings, `if` has `else`, etc.)
3. Verify exercises have correct answers
4. Check that prerequisites are referenced
5. Check that misconceptions are addressed
6. Self-critique from beginner perspective

---

## The 10 Common AI Mistakes

### Mistake 1: Over-Explaining
AIs write 500 words when 100 would do.

**Bad:**
> The ELF header is a structure that contains various fields that describe the contents of the ELF file, including but not limited to the magic number, the class, the data encoding, the version, and many other fields that are essential for the proper interpretation of the file by the operating system's loader.

**Good:**
> The ELF header tells the system how to read the file. First field: magic number (`7f 45 4c 46`). Without it, the OS doesn't know this is an ELF.

**Rule:** If your explanation is longer than the code it explains, you're over-explaining.

---

### Mistake 2: Skipping WHY
AIs jump straight to WHAT without explaining WHY it matters.

**Bad:**
> The ELF header is 64 bytes for 64-bit files.

**Good:**
> When you run `readelf -h`, how does it know where the program headers are? The ELF header is at byte 0 and points to everything else.

**Rule:** Every lesson starts with WHY. If you can't explain why it matters, don't teach it.

---

### Mistake 3: Invented Examples
AIs make up hex bytes, offsets, and struct layouts.

**Bad:**
```
00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff
```

**Good:**
```
7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
```

**Rule:** Every hex byte must be verified with `readelf`, `xxd`, or the gABI spec. No exceptions.

---

### Mistake 4: No Active Learning
AIs write passive paragraphs instead of interactive exercises.

**Bad:**
> The ELF header contains the class field at offset 4. This field indicates whether the file is 32-bit or 64-bit.

**Good:**
> Open the hex dump. Find offset 4. What's the value?
> (Answer: `02` = 64-bit, `01` = 32-bit)

**Rule:** Every explanation is followed by an exercise. No exceptions.

---

### Mistake 5: Wrong Difficulty Curve
AIs make things too easy or too hard.

**Bad:** Start with full ELF header struct, then explain magic number.

**Good:** Start with magic number, then class, then build up to full header.

**Rule:** Simple → Complex. Concrete → Abstract. One step at a time.

---

### Mistake 6: Missing Connections
AIs don't link to previous concepts.

**Bad:**
> The ELF header has a field `e_phoff`.

**Good:**
> Remember `e_phoff`? It points to the program headers we learned about in the previous concept.

**Rule:** Reference prerequisites explicitly. Don't assume the learner remembers.

---

### Mistake 7: Inconsistent Terminology
AIs use different words for the same thing.

**Bad:** Use "header", "struct", "descriptor" interchangeably.

**Good:** Always use "ELF header" (not "header struct" or "file descriptor").

**Rule:** Pick one term and use it consistently. Add a glossary if needed.

---

### Mistake 8: No Verification
AIs assume their output is correct.

**Bad:** Assume hex bytes are correct.

**Good:** Run `readelf -h` on a real ELF file and copy the output.

**Rule:** Verify every technical claim. Use `readelf`, `xxd`, `objdump`, or the spec.

---

### Mistake 9: Wrong Chemical Syntax
AIs use patterns that don't work in Chemical.

**Bad:**
```chemical
var msg = "Hello" + " World"
if(condition) { showHint() }
var x = 0.5
```

**Good:**
```chemical
var msg = string("Hello "); msg.append_view(" World")
if(condition) { showHint() } else {}
var x = 0.5f
```

**Rule:** Load `implementation_gaps` before writing Chemical code.

---

### Mistake 10: Forgetting `else`
AIs write `if` without `else`.

**Bad:**
```chemical
if(condition) { showHint() }
```

**Good:**
```chemical
if(condition) { showHint() } else {}
```

**Rule:** Every `if` has an `else`. Language requirement.

---

## The 10 Patterns That Work

### Pattern 1: Concrete Before Abstract
Show the real thing first, then explain it.

**Example:**
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

---

### Pattern 2: Error-Focused Teaching
Show what goes WRONG, not just what's right.

**Example:**
```markdown
## What Happens If the Magic Number Is Wrong?

$ readelf -h corrupted.elf
readelf: Error: Not an ELF file - invalid magic number

The kernel also rejects it:
$ ./corrupted.elf
bash: ./corrupted.elf: cannot execute binary file: Exec format error
```

---

### Pattern 3: Multiple Representations
Show the same data in different formats.

**Example:**
```markdown
## The Magic Number

Hex:    `7f 45 4c 46`
ASCII:  `.ELF`
Binary: `01111111 01000101 01001100 01000110`

All three represent the same 4 bytes.
```

---

### Pattern 4: Spaced Repetition
Reference previous concepts.

**Example:**
```markdown
## PROGRAM HEADERS

Remember the program headers from the previous concept?
The ELF header's `e_phoff` field tells us where they start.
```

---

### Pattern 5: Progressive Disclosure
Start simple, add complexity.

**Example:**
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

---

### Pattern 6: Real Commands
Show actual terminal output.

**Example:**
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

### Pattern 7: The "Build Up" Approach
Start with a minimal version and add fields one by one.

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

### Pattern 8: The "Run It Yourself" Approach
Tell learners to run commands on real files.

**Example:**
```markdown
## TRY IT

$ xxd -l 64 /bin/ls
00000000: 7f45 4c46 0201 0100 0000 0000 0000 0000  .ELF............
00000010: 0300 3e00 0100 0000 6010 4000 0000 0000  ..>.....`.@.....
```

---

### Pattern 9: The "What If It Breaks" Approach
Explain failure modes.

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

---

### Pattern 10: The "Connect the Dots" Approach
Explicitly link concepts together.

**Example:**
```markdown
## HOW THIS CONNECTS

You now know:
- The ELF header (this concept) → tells where program headers are
- Program headers (previous concept) → tell where segments are
- Segments (previous concept) → contain the actual code and data

Next: Section Headers → tell where debug info, symbols, and string tables are.
```

---

## Chemical Syntax Quick Reference

### String Operations
```chemical
// WRONG
var msg = "Hello" + " World"

// CORRECT
var msg = string("Hello ")
msg.append_view(" World")
// OR
var msg = `Hello ${"World"}`
```

### If/Else
```chemical
// WRONG
if(condition) { doSomething() }

// CORRECT
if(condition) { doSomething() } else {}
```

### Float Literals
```chemical
// WRONG
var x = 0.5

// CORRECT
var x = 0.5f
```

### Vector Access
```chemical
// WRONG
var val = arr[0]

// CORRECT
var val = arr.get(0)
```

### #html Blocks
```chemical
// WRONG — split across blocks
#html {
    <div>
}
#html {
    </div>
}

// CORRECT — complete in one block
#html {
    <div>content</div>
}
```

### Chemical Logic in #html
```chemical
// WRONG — Chemical if inside HTML
#html {
    <div>
    if(condition) {
        <p>Show this</p>
    }
    </div>
}

// CORRECT — use @{} escape
#html {
    <div>
    @{if(condition) {
        #html {
            <p>Show this</p>
        }
    }}
    </div>
}
```

---

## Discovered Patterns

> **Update this section as AIs write courses and discover what works.**

### Pattern: The "Concept Sandwich" Structure
**Discovered:** Wrapping a concept between two concrete examples (example → explanation → annotated example) is more effective than explanation alone.
**Works because:** First showing primes attention, explanation provides the model, annotated version confirms understanding.

**Example:**
```markdown
## RAW HEX (show first)

00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00

## EXPLANATION (then explain)

The first 4 bytes are the magic number. Bytes 4-5 indicate class and encoding.

## ANNOTATED (then show with labels)

00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
           |___________| |__| |__|
            magic number  class data encoding
```

### Pattern: The "Error-First" Exercise
**Discovered:** Showing the error message BEFORE the exercise gives context that makes the exercise meaningful.
**Works because:** Learners understand WHY they need to know this, not just THAT they need to know it.

**Example:**
```markdown
## EXERCISE

When you run `readelf -h corrupted.elf`, you see:

readelf: Error: Not an ELF file - invalid magic number

What should the first 4 bytes be?

<button class="option" onclick={checkAnswer(this, false)}>01 02 03 04</button>
<button class="option" onclick={checkAnswer(this, true)}>7f 45 4c 46</button>
<button class="option" onclick={checkAnswer(this, false)}>fe ed fa ce</button>
```

### Pattern: The "Progressive Hint" Exercise
**Discovered:** Exercises with cascading hints teach better than exercises with no hints or immediate answers.
**Works because:** Learners who struggle get guidance; learners who know it don't need hints.

**Example:**
```markdown
<div class="hints">
    <button class="hint-btn" onclick={showHint(this, 0)}>Hint 1: The first byte is non-printable</button>
    <button class="hint-btn" onclick={showHint(this, 1)}>Hint 2: Bytes 1-3 spell "ELF" in ASCII</button>
    <button class="hint-btn" onclick={showHint(this, 2)}>Hint 3: 0x7f is DEL (delete) in ASCII</button>
</div>
```

### Pattern: The "Misconception Title"
**Discovered:** Titled sections like "COMMON MISTAKE: ..." or "YOU MIGHT THINK: ..." grab attention better than inline corrections.
**Works because:** It signals "this is important" before the learner reads the content.

**Example:**
```markdown
## COMMON MISTAKE: "The ELF header is just metadata"

You might think the ELF header is optional metadata you can skip.
Actually, it's parsed FIRST — without it, the loader doesn't know
how to read anything else in the file.
```

### Pattern: The "Verify Yourself" Challenge
**Discovered:** After showing verified content, challenge learners to verify it themselves. This builds verification habits.
**Works because:** Learners who verify content learn to distrust unverified claims.

**Example:**
```markdown
## VERIFY YOURSELF

I claims the ELF magic is `7f 45 4c 46`. Don't trust me — verify it:

$ xxd -l 4 /bin/ls
00000000: 7f45 4c46                    .ELF

The first 4 bytes are indeed `7f 45 4c 46`.
```

### Pattern: The "What Changed?" Comparison
**Discovered:** Showing the same data before and after a change (e.g., corruption) teaches more than showing just the correct version.
**Works because:** Comparison highlights what matters by showing what breaks.

**Example:**
```markdown
## BEFORE (valid)

00000000: 7f 45 4c 46 02 01 01 00
           ^^^^^^^^^^^^
           Valid ELF magic

## AFTER (corrupted)

00000000: 00 00 00 00 02 01 01 00
           ^^^^^^^^^^^^
           Corrupted — readelf rejects this

## What changed?

Bytes 0-3: 7f 45 4c 46 → 00 00 00 00
Result: "invalid magic number" error
```

### Pattern: The "Real-World Connection"
**Discovered:** Connecting abstract concepts to real-world tools (readelf, objdump, strace) makes content stick.
**Works because:** Learners see immediate practical value.

**Example:**
```markdown
## WHY THIS MATTERS

When you run `strace ./hello`, you see:

execve("./hello", ["./hello"], 0x7ffd...) = 0
open("./hello", O_RDONLY)              = 3
read(3, "\177ELF\2\1\1\0\0\0...", 832) = 832

That `"\177ELF"` in the read() call? That's the magic number
being read from the file. The kernel checks it immediately.
```

---

## Related Documents

| Document | When to Read |
|----------|--------------|
| `docs/course-development-handbook.md` | Before starting a new course (8-phase process) |
| `docs/ai-course-writing-constraints.md` | Before any AI generation (8 constraint methods) |
| `docs/implementation-gaps.md` | Before writing Chemical code (syntax pitfalls) |
| `docs/teaching-components-catalog.md` | Before building exercises (component types) |
| `docs/rendering-pipeline.md` | Before writing .ch files (how they compile) |
| `docs/reusable-components.md` | Before using universal components (patterns) |
