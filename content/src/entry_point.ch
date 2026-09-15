// ELF Course — Concept 6: Entry Point
// How e_entry tells the loader where execution begins.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_entry_point() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Entry Point — Underlayer")
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
            <h1>Entry Point</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you run a program, how does the CPU know where to start executing? The answer is the entry point — a virtual address stored in the ELF header. This single field connects the file on disk to the running process.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The entry point is like a "Start Here" sign. When the kernel loads an ELF file, it maps the segments into memory and then jumps to the address stored in <code>e_entry</code>. For most programs, this points to the C runtime startup code, which eventually calls your <code>main()</code> function.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>In a 64-bit ELF, <code>e_entry</code> is an 8-byte field at offset 24. It contains a virtual address (not a file offset). For position-independent executables (PIE), this is usually a small offset like <code>0x1060</code> or <code>0x6810</code>. For non-PIE executables, it might be something like <code>0x401060</code>.</p>
                <p>The entry point is set by the linker based on the <code>_start</code> symbol. If no <code>_start</code> is defined, the linker uses address 0, which would crash.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -h /bin/ls | grep "Entry point"
  Entry point address:               0x6810

$ gdb -batch -ex "info files" /bin/ls 2>&1 | grep entry
  0x0000000000006810 - 0x0000000000006860 is .init</pre>
                </div>
                <p>The entry point 0x6810 falls in the <code>.init</code> section — the initialization code that runs before <code>main()</code>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ readelf -h /bin/ls | grep "Entry point"
$ objdump -d /bin/ls | head -20  # See the disassembly at the entry point</code></pre>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does the entry point address point to?</p>
                <div class="quiz" id="quiz-ep-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, false)">The main() function</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, true)">The _start / initialization code</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, false)">The first instruction of .text</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If you change the entry point to an address inside .text but not at _start, what will happen when the kernel jumps to it?</p>
                <div class="quiz" id="quiz-ep-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-2', this, false)">It will crash immediately</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-2', this, true)">It may run but skip initialization (ctors, libc setup)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-2', this, false)">The kernel will refuse to execute it</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The ELF header tells us where execution begins. But how does the loader know which parts of the file to map into memory? That's what program headers (next module) describe.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>True or False</h2>
                <p>The entry point address always points directly to the main() function.</p>
                <div class="tf-quiz" id="tf-ep-1">
                    <button class="tf-option" onclick="checkTF('tf-ep-1', false, 'The entry point points to _start (libc startup code), which eventually calls main(). Directly jumping to main() would skip critical initialization like setting up the C runtime, global constructors, and argument parsing.')">True</button>
                    <button class="tf-option" onclick="checkTF('tf-ep-1', true, 'The entry point points to _start (libc startup code), which eventually calls main(). Directly jumping to main() would skip critical initialization like setting up the C runtime, global constructors, and argument parsing.')">False</button>
                    <div class="tf-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>True or False</h2>
                <p>For position-independent executables (PIE), the entry point is typically a small offset like 0x1060 rather than a fixed address like 0x401060.</p>
                <div class="tf-quiz" id="tf-ep-2">
                    <button class="tf-option" onclick="checkTF('tf-ep-2', true, 'PIE executables are loaded at a random base address chosen by the kernel. The entry point is a relative offset from that base, so values like 0x1060 are common. Non-PIE executables use fixed virtual addresses like 0x401060.')">True</button>
                    <button class="tf-option" onclick="checkTF('tf-ep-2', false, 'PIE executables are loaded at a random base address chosen by the kernel. The entry point is a relative offset from that base, so values like 0x1060 are common. Non-PIE executables use fixed virtual addresses like 0x401060.')">False</button>
                    <div class="tf-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply: Debug Scenario</h2>
                <p>A developer writes a minimal ELF loader. Their program crashes with SIGSEGV at address 0x0. They check the ELF header and find:</p>
                <div class="hex-dump"><pre>Entry point address: 0x0000000000000000
Type: ET_EXEC (not PIE)
Machine: x86-64</pre></div>
                <p>What went wrong, and how would you fix it?</p>
                <div class="app-quiz" id="app-ep-1">
                    <div class="app-step">
                        <span class="app-step-num">1.</span>
                        <span>The entry point is</span>
                        <select class="app-select" data-correct="zero — the linker had no _start symbol to resolve">
                            <option value="">Select...</option>
                            <option value="too high for the address space">too high for the address space</option>
                            <option value="zero — the linker had no _start symbol to resolve">zero — the linker had no _start symbol to resolve</option>
                            <option value="pointing to a read-only section">pointing to a read-only section</option>
                        </select>
                    </div>
                    <div class="app-step">
                        <span class="app-step-num">2.</span>
                        <span>The fix is to</span>
                        <select class="app-select" data-correct="define a _start function that calls main()">
                            <option value="">Select...</option>
                            <option value="change e_entry manually with a hex editor">change e_entry manually with a hex editor</option>
                            <option value="define a _start function that calls main()">define a _start function that calls main()</option>
                            <option value="disable ASLR">disable ASLR</option>
                        </select>
                    </div>
                    <button class="app-check-btn" onclick="checkApp('app-ep-1')">Check Solution</button>
                    <div class="app-feedback"></div>
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
        .tf-quiz { margin-top: 1rem; display: flex; gap: 0.75rem; }
        .tf-option { padding: 0.6rem 1.5rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; font-weight: 500; }
        .tf-option:hover { border-color: #3b82f6; }
        .tf-option.correct { border-color: #059669; background: #ecfdf5; }
        .tf-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .tf-feedback { margin-top: 0.75rem; padding: 0.75rem 1rem; border-radius: 6px; font-size: 0.9rem; line-height: 1.5; background: #f9fafb; display: none; }
        .tf-feedback.show { display: block; }
        .app-quiz { margin-top: 1rem; }
        .app-step { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.75rem; flex-wrap: wrap; }
        .app-step-num { font-weight: 600; color: #6b7280; }
        .app-select { padding: 0.5rem 0.75rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; font-size: 0.9rem; min-width: 18rem; }
        .app-select:focus { outline: 2px solid #3b82f6; outline-offset: 1px; }
        .app-select.correct { border-color: #059669; background: #ecfdf5; }
        .app-select.wrong { border-color: #dc2626; background: #fef2f2; }
        .app-check-btn { margin-top: 0.75rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; font-size: 0.9rem; }
        .app-check-btn:hover { background: #f9fafb; border-color: #3b82f6; }
        .app-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
        @media (max-width: 640px) {
            .app-step { flex-direction: column; align-items: flex-start; }
            .app-select { min-width: 100%; }
        }
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

        function checkTF(quizId, correct, explanation) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.tf-option');
            var feedback = quiz.querySelector('.tf-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            var clickedBtn = event.target;
            if(correct) {
                clickedBtn.classList.add('correct');
                feedback.textContent = 'Correct! ' + explanation;
                feedback.style.background = '#ecfdf5';
                feedback.style.color = '#059669';
            } else {
                clickedBtn.classList.add('wrong');
                feedback.textContent = 'False. ' + explanation;
                feedback.style.background = '#fef2f2';
                feedback.style.color = '#dc2626';
            }
            feedback.classList.add('show');
        }

        function checkApp(quizId) {
            var quiz = document.getElementById(quizId);
            var selects = quiz.querySelectorAll('.app-select');
            var feedback = quiz.querySelector('.app-feedback');
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
                feedback.textContent = 'Correct diagnosis! The entry point being 0x0 means the linker resolved e_entry from _start, but no _start was defined. The fix is to provide a _start function.';
                feedback.style.color = '#059669';
            } else {
                feedback.textContent = 'Some steps are incorrect. Review the highlighted fields.';
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
            if(fs === 'small') lesson.classList.add('font-small');
            if(fs === 'large') lesson.classList.add('font-large');
            var lh = localStorage.getItem('ulf-line-height') || 'normal';
            if(lh === 'compact') lesson.classList.add('lh-compact');
            if(lh === 'relaxed') lesson.classList.add('lh-relaxed');
            var ls = localStorage.getItem('ulf-letter-spacing') || 'normal';
            if(ls === 'tight') lesson.classList.add('ls-tight');
            if(ls === 'loose') lesson.classList.add('ls-loose');
            var cw = localStorage.getItem('ulf-content-width') || 'normal';
            if(cw === 'narrow') lesson.classList.add('w-narrow');
            if(cw === 'wide') lesson.classList.add('w-wide');
            var fsEl = document.getElementById('font-size');
            var lhEl = document.getElementById('line-height');
            var lsEl = document.getElementById('letter-spacing');
            var cwEl = document.getElementById('content-width');
            if(fsEl) fsEl.value = fs;
            if(lhEl) lhEl.value = lh;
            if(lsEl) lsEl.value = ls;
            if(cwEl) cwEl.value = cw;
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
            if(localStorage.getItem('ulf-high-contrast') === '1') { lesson.classList.add('high-contrast'); var b = document.querySelectorAll('.a11y-btn')[0]; if(b) b.classList.add('active'); }
            if(localStorage.getItem('ulf-reduced-motion') === '1') { lesson.classList.add('reduced-motion'); var b2 = document.querySelectorAll('.a11y-btn')[1]; if(b2) b2.classList.add('active'); }
            else if(window.matchMedia('(prefers-reduced-motion: reduce)').matches) { lesson.classList.add('reduced-motion'); var b3 = document.querySelectorAll('.a11y-btn')[1]; if(b3) b3.classList.add('active'); }
            document.addEventListener('keydown', function(e) { if(e.key === 'Escape') closeShortcuts(); });
        })();
    }

    return page.toString()
}
}
