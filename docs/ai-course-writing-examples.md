# AI Course Writing Examples — Good vs Bad

Concrete examples of what works and what doesn't when writing Chemical course content.

> **This is a living document.** Add new examples as AIs write courses and discover patterns.

---

## Example 1: Explaining the ELF Header

### Bad Example
```markdown
# The ELF Header

The ELF header is a structure that contains various fields that describe the contents of the ELF file. It is located at the beginning of the file and is read first by the operating system's loader. The ELF header contains information such as the magic number, the class (32-bit or 64-bit), the data encoding (little-endian or big-endian), the version, the OS/ABI, and many other fields. The size of the ELF header depends on the class: 52 bytes for 32-bit and 64 bytes for 64-bit.

The magic number is `7f 45 4c 46` which is the ASCII representation of `.ELF`. This is used to identify the file as an ELF file. The class field indicates whether the file is 32-bit or 64-bit. The data encoding field indicates whether the file uses little-endian or big-endian byte order.

The ELF header also contains offsets to other important structures in the file, such as the program header table and the section header table. These offsets are used by the loader to find the segments and sections in the file.
```

**Problems:**
- Over-explaining (500+ words for a simple concept)
- No WHY (why does this matter?)
- No active learning (no exercises)
- No concrete examples (no hex dump)
- No connection to prerequisites
- Passive reading, not active learning

### Good Example
```markdown
# The ELF Header

## WHY

When you run `readelf -h hello`, how does it know where the program headers are?

The ELF header is at byte 0 and points to everything else. Without it, the OS can't read the file.

## MODEL

The ELF header tells the system:
1. "This is an ELF file" (magic number)
2. "I'm 64-bit" (class)
3. "Here's where the program headers are" (e_phoff)

## REALITY

The ELF header is 64 bytes for 64-bit files, 52 bytes for 32-bit.

## EXAMPLE

Here's a real ELF header (first 64 bytes of `/bin/ls`):

```
00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00  .ELF............
00000010: 03 00 3e 00 01 00 00 00 60 10 40 00 00 00 00 00  ..>.....`.@.....
00000020: 40 00 00 00 00 00 00 00 40 00 00 00 00 00 00 00  @.......@.......
00000030: 00 00 00 00 00 00 00 00 03 00 3e 00 01 00 00 00  ..........>.....
```

The first 4 bytes (`7f 45 4c 46`) are the magic number.
Bytes 4-5 (`02`) indicate 64-bit class.

## INTERACT

Open a terminal and run:

```bash
$ xxd -l 64 /bin/ls
```

Find offset 4. What's the value? (Answer: `02` = 64-bit)

## RETRIEVE

Remember the program headers from the previous concept? The ELF header's `e_phoff` field points to them.

## APPLY

Take a corrupted ELF file and run `readelf -h` on it. What error do you see?

## CONNECT

Next: Program Headers → tell where the code and data segments are.

## EXERCISES

1. What is the ELF magic number? (`7f 45 4c 46`)
2. What does offset 4 indicate? (Class: 32-bit or 64-bit)
3. How many bytes is the 64-bit ELF header? (64 bytes)
```

**Why this works:**
- Starts with WHY (how does `readelf -h` work?)
- Concrete examples (real hex dump)
- Active learning (run `xxd` yourself)
- Connects to prerequisites (program headers)
- Progressive disclosure (simple → complete)
- Exercises test understanding, not memorization

---

## Example 2: Explaining a Concept

### Bad Example
```markdown
# Program Headers

Program headers describe how to create the process image. They are used by the system to map the file into memory. Each program header describes a segment or other information the system needs to prepare the program for execution.

The program header table is an array of program header structures. Each structure describes a segment or other information the system needs to prepare the program for execution. The number of program header entries is given by the ELF header's e_phnum field.

Program headers are meaningful only for executable files and shared objects. They do not appear in relocatable object files.
```

**Problems:**
- Passive reading (no exercises)
- No WHY (why do program headers matter?)
- No concrete examples (no hex dump)
- No connection to ELF header
- Over-explaining

### Good Example
```markdown
# Program Headers

## WHY

When you run `./hello`, the OS needs to know which parts of the file to load into memory. Program headers tell it: "Load bytes 0x1000-0x2000 at address 0x400000."

Without them, the OS can't run the program.

## MODEL

Each program header says:
- "Load this segment" (p_type = PT_LOAD)
- "At this memory address" (p_vaddr)
- "From these bytes in the file" (p_offset, p_filesz)

## REALITY

On a real system, you can see program headers with:

```bash
$ readelf -l /bin/ls
```

## EXAMPLE

Here's what `readelf -l` shows for a simple program:

```
Program Headers:
  Type           Offset             VirtAddr           FileSiz
  LOAD           0x0000000000001000 0x0000000000401000 0x00000000000001e0
  LOAD           0x0000000000002000 0x0000000000402000 0x0000000000000008
```

The first LOAD segment: load from file offset 0x1000, put it at memory address 0x401000.

## INTERACT

Run `readelf -l` on your own program:

```bash
$ gcc -o hello hello.c
$ readelf -l hello
```

How many LOAD segments do you see? (Usually 2: code + data)

## RETRIEVE

Remember the ELF header's `e_phoff` field? It tells the loader where the program header table starts.

## APPLY

If `e_phoff` is wrong, what happens when you try to run the program?

## CONNECT

Next: Section Headers → tell where debug info, symbols, and string tables are.

## EXERCISES

1. What does a PT_LOAD segment do? (Maps file bytes into memory)
2. How many LOAD segments does a simple C program have? (Usually 2)
3. What field in the ELF header points to program headers? (e_phoff)
```

---

## Example 3: Writing an Exercise

### Bad Example
```markdown
## Exercise

What is the magic number?

A. 01 02 03 04
B. 7f 45 4c 46
C. fe ed fa ce
D. de ad be ef
```

**Problems:**
- No context (why does the magic number matter?)
- No feedback (what happens if you get it wrong?)
- No explanation (why is B correct?)
- Memorization, not understanding

### Good Example
```markdown
## Exercise

When you run `readelf -h hello`, the first thing it checks is the magic number. If it's wrong, you get:

```
readelf: Error: Not an ELF file - invalid magic number
```

What is the ELF magic number?

<button class="option" onclick={checkAnswer(this, false)}>01 02 03 04</button>
<button class="option" onclick={checkAnswer(this, true)}>7f 45 4c 46</button>
<button class="option" onclick={checkAnswer(this, false)}>fe ed fa ce</button>
<button class="option" onclick={checkAnswer(this, false)}>de ad be ef</button>

<div class="feedback">
**Correct!** `7f 45 4c 46` is the ASCII representation of `.ELF`. The first byte `7f` is a non-printable character, which prevents the file from being mistaken for a text file.

**If you chose A:** Those are just sequential bytes. The ELF magic is `.ELF` in ASCII.

**If you chose C:** That's the Java class file magic number (`0xCAFEBABE`).

**If you chose D:** That's a common pattern in debugging (`0xDEADBEEF`), but not the ELF magic.
```

**Why this works:**
- Context (why the magic number matters)
- Feedback for ALL options (not just correct)
- Explanation of why each wrong answer is wrong
- Real-world usage (`readelf` error message)

---

## Example 4: Writing a Chemical .ch File

### Bad Example
```chemical
import page
import html_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()

    #html {
        <h1>The ELF Header</h1>
        <p>The ELF header is a structure that contains various fields.</p>
        <p>The magic number is 7f 45 4c 46.</p>
        <p>The class field indicates 32-bit or 64-bit.</p>
    }

    return page.toString()
}
```

**Problems:**
- No #css block (no styling)
- No #js block (no interactivity)
- No exercises
- No WHY unit
- Passive reading
- Incomplete HTML structure

### Good Example
```chemical
import page
import html_cbi
import css_cbi
import js_cbi

public func render_concept() : std::string {
    var page = HtmlPage()
    page.defaultUniversalSetup()
    page.defaultPrepare()
    page.appendTitle(std::string_view("The ELF Header — Underlayer"))

    #html {
        <div class="lesson">
            <h1>The ELF Header</h1>

            <section class="unit why">
                <h2>WHY</h2>
                <p>When you run <code>readelf -h hello</code>, how does it know where the program headers are?</p>
                <p>The ELF header is at byte 0 and points to everything else.</p>
            </section>

            <section class="unit model">
                <h2>MODEL</h2>
                <p>The ELF header tells the system:</p>
                <ol>
                    <li>"This is an ELF file" (magic number)</li>
                    <li>"I'm 64-bit" (class)</li>
                    <li>"Here's where the program headers are" (e_phoff)</li>
                </ol>
            </section>

            <section class="unit example">
                <h2>EXAMPLE</h2>
                <p>Here's a real ELF header (first 64 bytes of <code>/bin/ls</code>):</p>
                <div class="hex-dump">
                    <pre>00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00  .ELF............
00000010: 03 00 3e 00 01 00 00 00 60 10 40 00 00 00 00 00  ..>.....`.@.....</pre>
                </div>
                <p>The first 4 bytes (<code>7f 45 4c 46</code>) are the magic number.</p>
            </section>

            <section class="unit interact">
                <h2>INTERACT</h2>
                <p>Run this on your system:</p>
                <pre><code>$ xxd -l 64 /bin/ls</code></pre>
                <p>Find offset 4. What's the value?</p>
            </section>

            <section class="exercise">
                <h2>EXERCISE</h2>
                <p>What is the ELF magic number?</p>
                <div class="options">
                    <button class="option" onclick={checkAnswer(this, false)}>01 02 03 04</button>
                    <button class="option" onclick={checkAnswer(this, true)}>7f 45 4c 46</button>
                    <button class="option" onclick={checkAnswer(this, false)}>fe ed fa ce</button>
                    <button class="option" onclick={checkAnswer(this, false)}>de ad be ef</button>
                </div>
                <div class="feedback"></div>
            </section>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .unit { margin-bottom: 2rem; }
        .hex-dump { background: var(--bg-muted); padding: 1rem; border-radius: 8px; overflow-x: auto; }
        .hex-dump pre { font-family: 'JetBrains Mono', monospace; font-size: 0.875rem; }
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
                showFeedback(btn.parentElement.nextElementSibling, 'Correct! `7f 45 4c 46` is `.ELF` in ASCII.', 'success');
            } else {
                btn.classList.add('incorrect');
                showFeedback(btn.parentElement.nextElementSibling, 'Not quite. The ELF magic is `.ELF` in ASCII.', 'error');
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

**Why this works:**
- Complete 8-unit structure
- #css with CSS variables
- #js with interactive exercises
- Real hex dump (verified with `readelf`)
- Exercises with feedback
- Proper Chemical syntax

---

## Example 5: Writing a Hex Dump Exercise

### Bad Example
```markdown
Look at this hex dump and answer the question.

```
00000000: 7f 45 4c 46 02 01 01 00
```

What is the magic number?
```

**Problems:**
- No context (why are we looking at this?)
- No instruction (what should the learner do?)
- No feedback (what happens if they get it wrong?)
- Memorization, not understanding

### Good Example
```markdown
## EXERCISE: Identify the Magic Number

When `readelf` opens a file, it first checks the magic number. If it's wrong, you see:

```
readelf: Error: Not an ELF file - invalid magic number
```

Here's the first 16 bytes of an ELF file:

```
00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
          ^^^^^^^^^^^^^^^
          These 4 bytes are the magic number
```

**Task:** Click on the magic number bytes:

<div class="hex-viewer">
  <span class="hex-byte" onclick={selectByte(this, 0)}>7f</span>
  <span class="hex-byte" onclick={selectByte(this, 1)}>45</span>
  <span class="hex-byte" onclick={selectByte(this, 2)}>4c</span>
  <span class="hex-byte" onclick={selectByte(this, 3)}>46</span>
  <span class="hex-byte" onclick={selectByte(this, 4)}>02</span>
  <span class="hex-byte" onclick={selectByte(this, 5)}>01</span>
  <span class="hex-byte" onclick={selectByte(this, 6)}>01</span>
  <span class="hex-byte" onclick={selectByte(this, 7)}>00</span>
</div>

**Feedback:**
- **Correct!** `7f 45 4c 46` = `.ELF` in ASCII.
- **Not quite.** The magic number is always `7f 45 4c 46` (bytes 0-3).
```

---

## Example 6: Writing a Fill-in-the-Blank Exercise

### Bad Example
```markdown
Complete the command:

$ ____ -h hello
```

**Problems:**
- No context (why are we running this command?)
- No feedback (what if they get it wrong?)
- No explanation (why is this the right command?)

### Good Example
```markdown
## EXERCISE: View the ELF Header

To see the ELF header, you use `readelf` with the `-h` flag.

**Complete the command:**

$ <span class="blank" contenteditable="true" data-answer="readelf"></span> -h hello

<button onclick={checkFill(this)}>Check</button>

**Feedback:**
- **Correct!** `readelf -h hello` shows the ELF header.
- **Not quite.** The command is `readelf` (read ELF). The `-h` flag means "print header."

**Try it:**
```bash
$ readelf -h /bin/ls
```
```

---

## Discovered Examples

> **Add new examples as AIs write courses and discover patterns.**

*No examples discovered yet. This section will grow as AIs write courses and learn from experience.*

### Template for New Examples
```markdown
## Example N: [Title]

### What Worked
[Description of successful pattern]

### What Didn't Work
[Description of failed pattern]

### Why
[Explanation of why one worked and the other didn't]
```
