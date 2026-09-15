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
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>↑</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
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

            <nav class="toc" id="toc">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
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
        .toc { position: sticky; top: 2rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb; margin-bottom: 1.5rem; }
        .toc-title { font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; margin-bottom: 0.5rem; }
        .toc-list { list-style: none; padding: 0; margin: 0; }
        .toc-list li { margin-bottom: 0.25rem; }
        .toc-list a { color: #374151; text-decoration: none; font-size: 0.85rem; display: block; padding: 0.2rem 0.5rem; border-radius: 4px; }
        .toc-list a:hover { background: #e5e7eb; }
        .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
        .back-to-top.visible { opacity: 1; pointer-events: auto; }
        .back-to-top:hover { background: #111827; }
        .reading-controls { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; padding: 0.75rem 1rem; background: #f3f4f6; border-radius: 8px; font-size: 0.85rem; }
        .reading-controls label { display: flex; align-items: center; gap: 0.35rem; }
        .reading-controls select { padding: 0.25rem 0.5rem; border: 1px solid #d1d5db; border-radius: 4px; font-size: 0.85rem; }
        .lesson.font-small { font-size: 0.9rem; }
        .lesson.font-large { font-size: 1.15rem; }
        .lesson.lh-compact p { line-height: 1.4; }
        .lesson.lh-relaxed p { line-height: 2.0; }
        .lesson.ls-tight { letter-spacing: -0.02em; }
        .lesson.ls-loose { letter-spacing: 0.04em; }
        .lesson.w-narrow { max-width: 640px; margin: 0 auto; }
        .lesson.w-wide { max-width: 1100px; margin: 0 auto; }
        .a11y-controls { position: fixed; top: 1rem; left: 1rem; display: flex; gap: 0.35rem; z-index: 60; }
        .a11y-btn { width: 2rem; height: 2rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; font-size: 0.75rem; font-weight: 600; color: #374151; }
        .a11y-btn:hover { background: #f3f4f6; }
        .a11y-btn.active { background: #1f2937; color: white; border-color: #1f2937; }
        .shortcuts-modal { display: none; position: fixed; inset: 0; z-index: 100; }
        .shortcuts-modal.open { display: flex; align-items: center; justify-content: center; }
        .shortcuts-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); }
        .shortcuts-dialog { position: relative; background: white; border-radius: 8px; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 4px 24px rgba(0,0,0,0.15); }
        .shortcuts-dialog h3 { margin: 0 0 1rem; font-size: 1.1rem; }
        .shortcuts-dialog dl { display: grid; grid-template-columns: auto 1fr; gap: 0.5rem 1rem; }
        .shortcuts-dialog dt { font-family: monospace; }
        .shortcuts-dialog dd { margin: 0; color: #6b7280; }
        .shortcuts-close { margin-top: 1rem; padding: 0.4rem 1rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; }
        kbd { display: inline-block; padding: 0.15rem 0.4rem; border: 1px solid #d1d5db; border-radius: 3px; background: #f9fafb; font-family: monospace; font-size: 0.85em; }
        .lesson.high-contrast { background: #000; color: #fff; }
        .lesson.high-contrast h1, .lesson.high-contrast h2 { color: #ff0; }
        .lesson.high-contrast a { color: #0ff; }
        .lesson.high-contrast code { background: #222; color: #0f0; }
        .lesson.high-contrast .quiz-option { background: #111; color: #fff; border-color: #555; }
        .lesson.reduced-motion *, .lesson.reduced-motion *::before, .lesson.reduced-motion *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
        @media (min-width: 1440px) { .lesson { max-width: 960px; } }
        @media (orientation: portrait) and (max-width: 768px) {
            .lesson { padding: 1rem; }
            .unit { padding: 1rem; }
            h1 { font-size: 1.3rem; }
            .hex-dump { font-size: 0.8rem; padding: 0.75rem; }
            .quiz-option { padding: 0.6rem 0.75rem; font-size: 0.9rem; }
        }
        @media (orientation: landscape) and (max-height: 500px) {
            .lesson { padding: 0.75rem 2rem; }
            .unit { padding: 0.75rem 1rem; margin-bottom: 1rem; }
            h1 { font-size: 1.2rem; margin-bottom: 0.5rem; }
        }
        @media (max-width: 480px) {
            .quiz-option { padding: 0.5rem 0.75rem; font-size: 0.85rem; }
            .tf-quiz { flex-direction: column; }
            .tf-option { width: 100%; }
            .match-row { flex-direction: column; align-items: flex-start; gap: 0.25rem; }
            .match-select { min-width: 100%; }
            .order-item { padding: 0.5rem 0.75rem; }
            .sort-item { padding: 0.5rem 0.75rem; }
        }
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

        (function() {
            var btn = document.getElementById('back-to-top');
            window.addEventListener('scroll', function() {
                if(window.scrollY > 300) { btn.classList.add('visible'); }
                else { btn.classList.remove('visible'); }
            });
            var tocList = document.getElementById('toc-list');
            var headings = document.querySelectorAll('.lesson h2');
            for(var i = 0; i < headings.length; i++) {
                var h = headings[i];
                var id = 'section-' + i;
                h.id = id;
                var li = document.createElement('li');
                var a = document.createElement('a');
                a.href = '#' + id;
                a.textContent = h.textContent;
                li.appendChild(a);
                tocList.appendChild(li);
            }
        })();

        function setFontSize(v) { localStorage.setItem('ulf-font-size', v); applySettings(); }
        function setLineHeight(v) { localStorage.setItem('ulf-line-height', v); applySettings(); }
        function setLetterSpacing(v) { localStorage.setItem('ulf-letter-spacing', v); applySettings(); }
        function setContentWidth(v) { localStorage.setItem('ulf-content-width', v); applySettings(); }
        function applySettings() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.remove('font-small','font-large','lh-compact','lh-relaxed','ls-tight','ls-loose','w-narrow','w-wide');
            var fs = localStorage.getItem('ulf-font-size') || 'medium';
            if(fs === 'small') { lesson.classList.add('font-small'); }
            else if(fs === 'large') { lesson.classList.add('font-large'); }
            else { }
            var lh = localStorage.getItem('ulf-line-height') || 'normal';
            if(lh === 'compact') { lesson.classList.add('lh-compact'); }
            else if(lh === 'relaxed') { lesson.classList.add('lh-relaxed'); }
            else { }
            var ls = localStorage.getItem('ulf-letter-spacing') || 'normal';
            if(ls === 'tight') { lesson.classList.add('ls-tight'); }
            else if(ls === 'loose') { lesson.classList.add('ls-loose'); }
            else { }
            var cw = localStorage.getItem('ulf-content-width') || 'normal';
            if(cw === 'narrow') { lesson.classList.add('w-narrow'); }
            else if(cw === 'wide') { lesson.classList.add('w-wide'); }
            else { }
            var fsEl = document.getElementById('font-size');
            var lhEl = document.getElementById('line-height');
            var lsEl = document.getElementById('letter-spacing');
            var cwEl = document.getElementById('content-width');
            if(fsEl) { fsEl.value = fs; }
            else { }
            if(lhEl) { lhEl.value = lh; }
            else { }
            if(lsEl) { lsEl.value = ls; }
            else { }
            if(cwEl) { cwEl.value = cw; }
            else { }
        }
        applySettings();

        function toggleHighContrast() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.toggle('high-contrast');
            localStorage.setItem('ulf-high-contrast', lesson.classList.contains('high-contrast') ? '1' : '0');
            var btn = document.querySelectorAll('.a11y-btn')[0];
            if(btn) btn.classList.toggle('active', lesson.classList.contains('high-contrast'));
        }
        function toggleReducedMotion() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.toggle('reduced-motion');
            localStorage.setItem('ulf-reduced-motion', lesson.classList.contains('reduced-motion') ? '1' : '0');
            var btn = document.querySelectorAll('.a11y-btn')[1];
            if(btn) btn.classList.toggle('active', lesson.classList.contains('reduced-motion'));
        }
        function openShortcuts() { document.getElementById('shortcuts-modal').classList.add('open'); }
        function closeShortcuts() { document.getElementById('shortcuts-modal').classList.remove('open'); }
        (function() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            if(localStorage.getItem('ulf-high-contrast') === '1') { lesson.classList.add('high-contrast'); var b = document.querySelectorAll('.a11y-btn')[0]; if(b) { b.classList.add('active'); } else { } }
            else { }
            if(localStorage.getItem('ulf-reduced-motion') === '1') { lesson.classList.add('reduced-motion'); var b2 = document.querySelectorAll('.a11y-btn')[1]; if(b2) { b2.classList.add('active'); } else { } }
            else if(window.matchMedia('(prefers-reduced-motion: reduce)').matches) { lesson.classList.add('reduced-motion'); var b3 = document.querySelectorAll('.a11y-btn')[1]; if(b3) { b3.classList.add('active'); } else { } }
            else { }
            document.addEventListener('keydown', function(e) { if(e.key === 'Escape') { closeShortcuts(); } else { } });
        })();
    }
    return page.toString()
}
}
