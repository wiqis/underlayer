// ELF Course — Concept 3: File Layout
// How an ELF file is organized from start to finish.
using std::string
using std::string_view

public func render_file_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("File Layout — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>File Layout</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>An ELF file isn't just a random pile of bytes. It has a precise layout that the operating system and tools like <code>readelf</code> expect. Understanding this layout is essential for reading ELF files, debugging binaries, and building tools that work with them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of an ELF file like a book. It has:</p>
                <ul>
                    <li><strong>A cover page</strong> (ELF header) — tells you what kind of book this is</li>
                    <li><strong>A table of contents</strong> (program header table) — tells the runtime where to find chapters</li>
                    <li><strong>The actual chapters</strong> (segments and sections) — the code and data</li>
                    <li><strong>A library catalog entry</strong> (section header table) — tells tools where to find specific sections</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>An ELF file has four main parts, in this exact order:</p>
                <table>
                    <thead>
                        <tr><th>Part</th><th>Offset</th><th>Purpose</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>ELF Header</td><td>0x00</td><td>Identifies the file as ELF, states class (32/64), endianness, and points to other tables</td></tr>
                        <tr><td>Program Header Table</td><td>e_phoff</td><td>Describes segments for the runtime loader</td></tr>
                        <tr><td>Sections / Segments</td><td>varies</td><td>The actual code (.text), data (.data), symbols, relocations, etc.</td></tr>
                        <tr><td>Section Header Table</td><td>e_shoff</td><td>Describes sections for tools like readelf, objdump, ld</td></tr>
                    </tbody>
                </table>
                <p>The ELF header is always at byte 0. The program header table comes right after (or at the offset specified by <code>e_phoff</code>). Sections and segments fill the middle. The section header table is at the end (or at <code>e_shoff</code>).</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here's the layout of a real 64-bit ELF executable (<code>bin/ls</code>):</p>
                <div class="hex-dump">
                    <pre>Offset    Size     What
0x000000  0x40     ELF Header (64 bytes for 64-bit)
0x000040  varies   Program Header Table (3 entries, 56 bytes each)
0x000128  varies   .interp (dynamic linker path)
0x000140  varies   .init, .plt, .text (code)
...       ...      ...more sections...
0x003ff0  varies   Section Header Table</pre>
                </div>
                <p>Use <code>readelf -l /bin/ls</code> to see the program headers and their file offsets.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Run these commands on your system:</p>
                <pre><code>$ readelf -h /bin/ls | head -5
  Magic:   7f 45 4c 46 02 01 01 00 ...
  Class:                             ELF64
  Data:                              2's complement, little endian

$ readelf -l /bin/ls | head -10
  Elf file type is DYN (Position-Independent Executable)
  Entry point 0x6810
  There are 9 program headers</code></pre>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what part of an ELF file does the runtime loader use to map segments into memory?</p>
                <div class="quiz" id="quiz-fl-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-1', this, false)">The ELF header</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-1', this, true)">The program header table</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-1', this, false)">The section header table</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Given this information about an ELF file, where does the section header table start?</p>
                <ul>
                    <li>e_shoff = 0x3ff0</li>
                    <li>e_shentsize = 64</li>
                    <li>e_shnum = 27</li>
                </ul>
                <div class="quiz" id="quiz-fl-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-2', this, false)">At byte 0x0040</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-2', this, false)">At byte 0x0001</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-fl-2', this, true)">At byte 0x3ff0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand how an ELF file is laid out. The ELF header (next concept) tells us exactly where each part begins and how big it is.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, sans-serif; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-model { border-color: #059669; background: #ecfdf5; }
        .unit-reality { border-color: #d97706; background: #fffbeb; }
        .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
        .unit-interact { border-color: #ec4899; background: #fdf2f8; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
    }

    #js {
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct!';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. Try again next time.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
