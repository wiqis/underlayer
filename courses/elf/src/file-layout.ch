import page
import html_cbi
import css_cbi
import js_cbi

public func render() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("File Layout — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>File Layout</h1>
            <div class="lesson-meta">15 min · Core concept · Module 1 of 2 · Prerequisite: Binary Representation</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>An ELF file is a sequence of bytes with structure. The file layout tells you where to find each piece: the ELF header, the program headers, the section headers, and the actual code and data. Without understanding the layout, you cannot navigate an ELF file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of an ELF file like a book with a table of contents. The first page (the ELF header) tells you where everything else is: "the program headers start at page 10", "the section headers start at page 100".</p>
                <p>The file is organized in order:</p>
                <ol>
                    <li><strong>ELF header</strong> — at the very beginning (offset 0)</li>
                    <li><strong>Program header table</strong> — location given by the ELF header</li>
                    <li><strong>Sections and segments</strong> — the actual content</li>
                    <li><strong>Section header table</strong> — location given by the ELF header (usually at the end)</li>
                </ol>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The ELF header (64 bytes for ELF64) contains two critical offsets:</p>
                <ul>
                    <li><strong>e_phoff</strong> — file offset to the program header table</li>
                    <li><strong>e_shoff</strong> — file offset to the section header table</li>
                </ul>
                <p>A 64-bit ELF file layout looks like this:</p>
                <div class="code-block">
<pre>Offset 0x0000: ELF header (64 bytes)
Offset 0x0040: Program header table (e_phnum entries × e_phentsize bytes each)
... program data (LOAD segments) ...
Offset given by e_shoff: Section header table (e_shnum entries × e_shentsize bytes each)</pre>
                </div>
                <p>The program header table describes <strong>segments</strong> — how the loader maps the file into memory. The section header table describes <strong>sections</strong> — how the linker and debugger organize the file. These are different concepts, and confusing them is one of the most common mistakes when learning ELF.</p>
                <p>A typical ELF file has:</p>
                <ul>
                    <li>2-4 program header entries (code + data + optional others)</li>
                    <li>10-30 section header entries (.text, .data, .rodata, .symtab, .strtab, etc.)</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Let's examine the beginning of a real ELF file:</p>
                <div class="code-block">
<pre>$ readelf -h /bin/ls
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  ...
  Start of program headers:          64 (0x40)
  Start of section headers:          1930432 (0x1d5000)
  Flags:                             0x0
  Size of program headers:           56 (0x38)
  Number of program headers:         11
  Size of section headers:           64 (0x40)
  Number of section headers:         31
  ...</pre>
                </div>
                <p>Key observations:</p>
                <ul>
                    <li>The program header table starts at offset 64 (right after the 64-byte header)</li>
                    <li>The section header table starts at offset 0x1d5000 (near the end of the file)</li>
                    <li>There are 11 program headers and 31 section headers</li>
                    <li>Each program header is 56 bytes; each section header is 64 bytes</li>
                </ul>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Here is a simplified ELF file layout. Fill in the blanks:</p>
                <div class="code-block">
<pre>Offset 0x0000: ___________________ (always at the beginning)
Offset 0x0040: ___________________ (location given by e_phoff)
...
Offset 0x1d5000: _________________ (location given by e_shoff)</pre>
                </div>
                <div class="quiz" id="quiz-layout">
                    <button class="quiz-option" onclick="checkLayout(this, false)">Code / Data / Symbol Table / String Table</button>
                    <button class="quiz-option" onclick="checkLayout(this, true)">ELF Header / Program Header Table / Section Header Table</button>
                    <button class="quiz-option" onclick="checkLayout(this, false)">Magic Bytes / Section Headers / Program Headers</button>
                    <button class="quiz-option" onclick="checkLayout(this, false)">ELF Header / Section Headers / Program Header Table</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what two fields in the ELF header tell you where the program headers and section headers are located?</p>
                <div class="quiz" id="quiz-offsets">
                    <button class="quiz-option" onclick="checkOffsets(this, false)">e_phnum and e_shnum</button>
                    <button class="quiz-option" onclick="checkOffsets(this, false)">e_phentsize and e_shentsize</button>
                    <button class="quiz-option" onclick="checkOffsets(this, true)">e_phoff and e_shoff</button>
                    <button class="quiz-option" onclick="checkOffsets(this, false)">e_entry and e_phoff</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A 64-bit ELF file has e_phoff = 64, e_phentsize = 56, e_phnum = 11. At what offset does the section header table start if it comes right after the program data, and the last program header ends at offset 0x2000?</p>
                <p class="hint-text">Hint: The section header table doesn't have to start right after the program headers. It's wherever e_shoff says it is.</p>
                <div class="quiz" id="quiz-calc">
                    <button class="quiz-option" onclick="checkCalc(this, false)">0x1040 (64 + 11*56 = 672 bytes)</button>
                    <button class="quiz-option" onclick="checkCalc(this, true)">We cannot know without reading e_shoff</button>
                    <button class="quiz-option" onclick="checkCalc(this, false)">0x2000 (right after the last program header)</button>
                    <button class="quiz-option" onclick="checkCalc(this, false)">0x40 (right after the ELF header)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand how ELF files are laid out. The ELF header is always at offset 0 and points to the program header table and section header table. Next, we will examine what is in the ELF header itself.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; color: #111827; }
        .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-model { border-color: #059669; background: #ecfdf5; }
        .unit-reality { border-color: #d97706; background: #fffbeb; }
        .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
        .unit-interact { border-color: #ec4899; background: #fdf2f8; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
        h2 { font-size: 1.15rem; margin-bottom: 0.75rem; margin-top: 0; }
        h3 { font-size: 1rem; margin: 1rem 0 0.5rem; color: #374151; }
        p { margin: 0.5rem 0; }
        ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin: 0.25rem 0; }
        .code { font-family: ui-monospace, monospace; background: #f5f5f5; padding: 0.15rem 0.4rem; border-radius: 3px; font-size: 0.9rem; }
        .code-block { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.9rem; overflow-x: auto; margin: 1rem 0; }
        .hint-text { font-size: 0.85rem; color: #9ca3af; font-style: italic; margin: 0.5rem 0; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.95rem; }
        .quiz-option:hover { border-color: #3b82f6; background: #eff6ff; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .quiz-option:disabled { cursor: default; }
        .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.5rem; }
    }

    #js {
        function checkLayout(btn, correct) {
            var quiz = document.getElementById('quiz-layout');
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! The ELF header is at offset 0, the program header table follows, and the section header table is at the end (location given by e_shoff).';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. The ELF header is always at offset 0. The program header table location is given by e_phoff. The section header table location is given by e_shoff (usually near the end).';
                feedback.style.color = '#dc2626';
            }
        }

        function checkOffsets(btn, correct) {
            var quiz = document.getElementById('quiz-offsets');
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! e_phoff gives the file offset to the program header table, and e_shoff gives the file offset to the section header table.';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. e_phoff and e_shoff are the two offset fields. e_phnum/e_shnum give the count, and e_phentsize/e_shentsize give the size per entry.';
                feedback.style.color = '#dc2626';
            }
        }

        function checkCalc(btn, correct) {
            var quiz = document.getElementById('quiz-calc');
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! The section header table can be anywhere in the file. You must read e_shoff from the ELF header to know where it is. It is often near the end of the file, but not always.';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. The section header table location is given by e_shoff in the ELF header. It is not necessarily right after the program headers — it is wherever the linker put it.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
