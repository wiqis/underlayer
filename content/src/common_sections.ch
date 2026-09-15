// ELF Course — Concept 11: Common Sections
// .text, .data, .bss, .rodata, .symtab, .strtab — what each section contains.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_common_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Common Sections — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Common Sections</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you run <code>readelf -S</code>, you see dozens of sections. Understanding the most common ones lets you navigate any ELF file and know what you're looking at.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Sections are like labeled boxes in a warehouse:</p>
                <ul>
                    <li><strong>.text</strong> — The code (executable instructions)</li>
                    <li><strong>.data</strong> — Initialized global/static variables</li>
                    <li><strong>.bss</strong> — Uninitialized globals (zero-filled at runtime)</li>
                    <li><strong>.rodata</strong> — Read-only data (string constants, jump tables)</li>
                    <li><strong>.symtab</strong> — Symbol table (for debugging)</li>
                    <li><strong>.strtab</strong> — String table (names for symbols)</li>
                    <li><strong>.dynsym</strong> — Dynamic symbol table (for linking)</li>
                    <li><strong>.dynstr</strong> — Dynamic string table</li>
                    <li><strong>.rela.text</strong> — Relocations for code</li>
                    <li><strong>.debug_*</strong> — DWARF debugging info</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <table>
                    <thead>
                        <tr><th>Section</th><th>Type</th><th>Flags</th><th>Contains</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.text</td><td>SHT_PROGBITS</td><td>SHF_ALLOC + SHF_EXECINSTR</td><td>Machine code</td></tr>
                        <tr><td>.rodata</td><td>SHT_PROGBITS</td><td>SHF_ALLOC</td><td>Read-only constants</td></tr>
                        <tr><td>.data</td><td>SHT_PROGBITS</td><td>SHF_ALLOC + SHF_WRITE</td><td>Initialized global variables</td></tr>
                        <tr><td>.bss</td><td>SHT_NOBITS</td><td>SHF_ALLOC + SHF_WRITE</td><td>Uninitialized globals (zeroed)</td></tr>
                        <tr><td>.symtab</td><td>SHT_SYMTAB</td><td>none</td><td>All symbols (for debugging)</td></tr>
                        <tr><td>.strtab</td><td>SHT_STRTAB</td><td>none</td><td>Symbol names</td></tr>
                        <tr><td>.dynsym</td><td>SHT_DYNSYM</td><td>SHF_ALLOC</td><td>Dynamic symbols (for linking)</td></tr>
                        <tr><td>.dynstr</td><td>SHT_STRTAB</td><td>SHF_ALLOC</td><td>Dynamic symbol names</td></tr>
                        <tr><td>.rela.text</td><td>SHT_RELA</td><td>SHF_ALLOC</td><td>Code relocations</td></tr>
                        <tr><td>.init</td><td>SHT_PROGBITS</td><td>SHF_ALLOC + SHF_EXECINSTR</td><td>Initialization code</td></tr>
                        <tr><td>.fini</td><td>SHT_PROGBITS</td><td>SHF_ALLOC + SHF_EXECINSTR</td><td>Cleanup code</td></tr>
                    </tbody>
                </table>
                <p>Note: .bss has type SHT_NOBITS — it takes no space in the file but is zero-filled in memory.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -S /bin/ls | grep -E '\.(text|data|bss|rodata|symtab|strtab)'
  [11] .text             PROGBITS   0000000000001000  00001000  001a52
  [17] .rodata           PROGBITS   0000000000003000  00003000  000ba0
  [24] .data             PROGBITS   0000000000004dc0  00003dc0  000020
  [25] .bss              NOBITS     0000000000004de0  00003de0  000040
  [26] .symtab           SYMTAB     0000000000000000  00003e28  000c90</pre>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Why does .bss have type SHT_NOBITS?</p>
                <div class="quiz" id="quiz-cs-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-1', this, false)">It contains no data</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-1', this, true)">It takes no space in the file — zeroed at runtime</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-1', this, false)">It's compressed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If .rodata and .text are in the same PT_LOAD segment, what permissions does the kernel set for .rodata?</p>
                <div class="quiz" id="quiz-cs-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-2', this, true)">R (read-only) — same as the segment</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-2', this, false)">RW (read-write) — data sections are writable</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-cs-2', this, false)">RE (read-execute) — it's code</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now know the common sections. But remember — sections and segments are different things. The next concept clarifies this distinction.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Match Code to Output</h2>
                <p>Match each section type to its correct description:</p>
                <div class="match-quiz" id="match-cs-1">
                    <div class="match-row">
                        <span class="match-item">.text</span>
                        <select class="match-select" data-correct="executable machine code">
                            <option value="">Select...</option>
                            <option value="initialized data">initialized data</option>
                            <option value="executable machine code">executable machine code</option>
                            <option value="uninitialized data (zeroed at runtime)">uninitialized data (zeroed at runtime)</option>
                            <option value="read-only data">read-only data</option>
                        </select>
                    </div>
                    <div class="match-row">
                        <span class="match-item">.data</span>
                        <select class="match-select" data-correct="initialized data">
                            <option value="">Select...</option>
                            <option value="initialized data">initialized data</option>
                            <option value="executable machine code">executable machine code</option>
                            <option value="uninitialized data (zeroed at runtime)">uninitialized data (zeroed at runtime)</option>
                            <option value="read-only data">read-only data</option>
                        </select>
                    </div>
                    <div class="match-row">
                        <span class="match-item">.bss</span>
                        <select class="match-select" data-correct="uninitialized data (zeroed at runtime)">
                            <option value="">Select...</option>
                            <option value="initialized data">initialized data</option>
                            <option value="executable machine code">executable machine code</option>
                            <option value="uninitialized data (zeroed at runtime)">uninitialized data (zeroed at runtime)</option>
                            <option value="read-only data">read-only data</option>
                        </select>
                    </div>
                    <div class="match-row">
                        <span class="match-item">.rodata</span>
                        <select class="match-select" data-correct="read-only data">
                            <option value="">Select...</option>
                            <option value="initialized data">initialized data</option>
                            <option value="executable machine code">executable machine code</option>
                            <option value="uninitialized data (zeroed at runtime)">uninitialized data (zeroed at runtime)</option>
                            <option value="read-only data">read-only data</option>
                        </select>
                    </div>
                    <button class="match-check-btn" onclick="checkMatch('match-cs-1')">Check Matches</button>
                    <div class="match-feedback"></div>
                </div>
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
        .match-quiz { margin-top: 1rem; }
        .match-row { display: flex; align-items: center; gap: 1rem; margin-bottom: 0.75rem; }
        .match-item { font-weight: 500; font-family: monospace; min-width: 5rem; }
        .match-select { padding: 0.5rem 0.75rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; font-size: 0.9rem; min-width: 20rem; }
        .match-select:focus { outline: 2px solid #3b82f6; outline-offset: 1px; }
        .match-select.correct { border-color: #059669; background: #ecfdf5; }
        .match-select.wrong { border-color: #dc2626; background: #fef2f2; }
        .match-check-btn { margin-top: 0.75rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; font-size: 0.9rem; }
        .match-check-btn:hover { background: #f9fafb; border-color: #3b82f6; }
        .match-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
        @media (max-width: 640px) {
            .match-row { flex-direction: column; align-items: flex-start; gap: 0.25rem; }
            .match-select { min-width: 100%; }
        }
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
            if(correct) { btn.classList.add('correct'); feedback.textContent = 'Correct!'; feedback.style.color = '#059669'; }
            else { btn.classList.add('wrong'); feedback.textContent = 'Not quite.'; feedback.style.color = '#dc2626'; }
        }

        function checkMatch(quizId) {
            var quiz = document.getElementById(quizId);
            var selects = quiz.querySelectorAll('.match-select');
            var feedback = quiz.querySelector('.match-feedback');
            var allCorrect = true;
            for(var i = 0; i < selects.length; i++) {
                var sel = selects[i];
                var correct = sel.getAttribute('data-correct');
                if(sel.value === correct) {
                    sel.classList.add('correct');
                    sel.classList.remove('wrong');
                } else {
                    sel.classList.add('wrong');
                    sel.classList.remove('correct');
                    allCorrect = false;
                }
                sel.disabled = true;
            }
            if(allCorrect) {
                feedback.textContent = 'All matches correct!';
                feedback.style.color = '#059669';
            } else {
                feedback.textContent = 'Some matches are incorrect. Review the highlighted items.';
                feedback.style.color = '#dc2626';
            }
        }
    }
    return page.toString()
}
}
