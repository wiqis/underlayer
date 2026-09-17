// ELF Course — Concept 18: Dynamic Relocations
// .rela.dyn, .rela.plt — how the dynamic linker patches addresses at load time.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dynamic_relocations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Dynamic Relocations — Underlayer")
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
            <h1>Dynamic Relocations</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you link a shared library, the linker can't know where the library will be loaded in memory. Every reference to an external symbol (like calling printf from your library) needs to be patched at load time by the dynamic linker (ld.so).</p>
                <p>Dynamic relocations are the mechanism that makes shared libraries work — they're the "fill in the blanks later" instructions that ld.so processes when loading your program.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of dynamic relocations as a to-do list for ld.so:</p>
                <ol>
                    <li>Load the program and all shared libraries into memory</li>
                    <li>Process .rela.dyn — patch data references (global variables, GOT entries)</li>
                    <li>Process .rela.plt — set up PLT stubs for lazy function binding</li>
                    <li>Jump to the program's entry point</li>
                </ol>
                <p>Most dynamic relocations use <strong>lazy binding</strong> — function addresses are resolved on first call, not at load time. This speeds up program startup.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Dynamic relocations live in two sections:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Purpose</th><th scope="col">Processed By</th><th scope="col">When</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.rela.dyn</td><td>Data references, global offsets</td><td>ld.so (or static linker)</td><td>Load time</td></tr>
                        <tr><td>.rela.plt</td><td>Function calls via PLT</td><td>ld.so (lazy)</td><td>First call</td></tr>
                    </tbody>
                </table>
                <p>The most common dynamic relocation types on x86-64:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Type</th><th scope="col">Value</th><th scope="col">Formula</th><th scope="col">Usage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>R_X86_64_RELATIVE</td><td>8</td><td>B + A</td><td>Base address + addend (PIC data in shared libs)</td></tr>
                        <tr><td>R_X86_64_GLOB_DAT</td><td>6</td><td>S</td><td>Global variable address (GOT entry)</td></tr>
                        <tr><td>R_X86_64_JUMP_SLOT</td><td>7</td><td>S</td><td>Function address (PLT/GOT entry, lazy binding)</td></tr>
                        <tr><td>R_X86_64_64</td><td>1</td><td>S + A</td><td>Absolute 64-bit (non-PIC data)</td></tr>
                    </tbody>
                </table>
                <p>Where:</p>
                <ul>
                    <li><strong>B</strong> = Base address of the shared library (randomized by ASLR)</li>
                    <li><strong>S</strong> = Symbol value (final address of the referenced symbol)</li>
                    <li><strong>A</strong> = Addend</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -rW /usr/lib/x86_64-linux-gnu/libc.so.6 | head -20

Relocation section '.rela.dyn' at offset 0x... contains 450 entries:
  Offset          Info           Type             Sym. Value    Sym. Name + Addend
0000003bc028  000000000008   R_X86_64_RELATIVE                    1a1230
0000003bc030  000000000008   R_X86_64_RELATIVE                    1a11f0
0000003be018  002400000006   R_X86_64_GLOB_DAT  00000000003c2018  __environ
0000003be020  002500000006   R_X86_64_GLOB_DAT  00000000003c2020  __progname

Relocation section '.rela.plt' at offset 0x... contains 30 entries:
  Offset          Info           Type             Sym. Value    Sym. Name + Addend
0000003be0c8  000300000007   R_X86_64_JUMP_SLOT 0000000000123456  read + 0
0000003be0d0  000400000007   R_X86_64_JUMP_SLOT 0000000000123789  write + 0</pre>
                </div>
                <p>The lazy binding mechanism:</p>
                <ol>
                    <li>At load time, ld.so writes the address of a resolver stub into each JUMP_SLOT GOT entry</li>
                    <li>When the program first calls read(), it jumps through the PLT to the GOT entry</li>
                    <li>The GOT entry points to the resolver stub (not the actual function yet)</li>
                    <li>The resolver stub calls ld.so's _dl_runtime_resolve()</li>
                    <li>ld.so finds the real read() address, writes it into the GOT, and jumps to it</li>
                    <li>On subsequent calls, the GOT entry points directly to read() — no resolver overhead</li>
                </ol>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See dynamic relocations in a shared library
readelf -rW /usr/lib/x86_64-linux-gnu/libc.so.6 | head -30

# See dynamic relocations in your own program
gcc -o myprog myprog.c
readelf -rW myprog | grep -E 'JUMP_SLOT|GLOB_DAT'

# Watch lazy binding in action with strace
strace -e trace=open,read,write ./myprog 2&gt;1 | head -20

# Force eager binding (disable lazy)
LD_BIND_NOW=1 ./myprog</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the difference between R_X86_64_GLOB_DAT and R_X86_64_JUMP_SLOT?</p>
                <div class="quiz" id="quiz-dr-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-1', this, false)">GLOB_DAT is for functions, JUMP_SLOT is for data</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-1', this, true)">GLOB_DAT resolves at load time (for data references), JUMP_SLOT uses lazy binding (for function calls)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-1', this, false)">They are identical — just different names</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>What happens if you set LD_BIND_NOW=1?</p>
                <div class="quiz" id="quiz-dr-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-2', this, false)">The program won't start</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-2', this, true)">All function addresses are resolved at load time instead of on first call — slightly slower startup but slightly faster first call</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-dr-2', this, false)">All symbols become hidden</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Dynamic relocations are processed by the dynamic linker. The next module covers dynamic linking in depth — the .dynamic section, shared library dependencies, and how ld.so orchestrates everything.</p>
            </div>
            <div class="unit unit-exercises" id="api-exercises" style="display:none">
                <h2>Practice Exercises</h2>
                <div id="exercise-list"></div>
            </div>
            <div class="swipe-hint">← Swipe to navigate →</div>
            <link rel="prev" href="">
            <link rel="next" href="">
        </div>
        <div class="a11y-toast" id="a11y-toast"></div>

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
        .unit-exercises { border-color: #8b5cf6; background: #f5f3ff; }
        .exercise-card { background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem; margin: 0.75rem 0; }
        .exercise-card h4 { margin: 0 0 0.5rem 0; font-size: 0.95rem; }
        .exercise-option { display: block; width: 100%; padding: 0.6rem 0.9rem; margin: 0.4rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.92rem; }
        .exercise-option:hover { border-color: #8b5cf6; }
        .exercise-option.correct { border-color: #059669; background: #ecfdf5; }
        .exercise-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .exercise-input { padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 6px; margin-right: 0.5rem; }
        .exercise-feedback { margin-top: 0.6rem; padding: 0.6rem 0.8rem; border-radius: 6px; font-size: 0.9rem; display: none; }
        .exercise-feedback.ok { display: block; background: #ecfdf5; border-left: 3px solid #059669; }
        .exercise-feedback.err { display: block; background: #fef2f2; border-left: 3px solid #dc2626; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
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
        .lesson h1 { font-size: clamp(1.3rem, 3vw, 1.8rem); }
        .lesson h2 { font-size: clamp(1rem, 2.5vw, 1.3rem); }
        .lesson p { font-size: clamp(0.9rem, 2vw, 1.05rem); }
        .lesson code { font-size: clamp(0.8rem, 1.8vw, 0.95em); }
        .feedback-rating { display: flex; align-items: center; gap: 0.5rem; margin-top: 0.75rem; padding: 0.5rem 0.75rem; background: #f9fafb; border-radius: 6px; font-size: 0.85rem; }
        .feedback-rating span { color: #6b7280; }
        .feedback-btn { padding: 0.3rem 0.7rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; font-size: 0.85rem; }
        .feedback-btn:hover { background: #f3f4f6; }
        .feedback-btn.selected { background: #1f2937; color: white; border-color: #1f2937; }
        .feedback-thanks { color: #059669; font-size: 0.85rem; display: none; }
        .a11y-toast { position: fixed; bottom: 2rem; left: 50%; transform: translateX(-50%); padding: 0.5rem 1rem; background: #1f2937; color: white; border-radius: 6px; font-size: 0.85rem; z-index: 200; opacity: 0; transition: opacity 0.3s; pointer-events: none; }
        .a11y-toast.show { opacity: 1; }
        .hex-dump, pre { touch-action: manipulation; overflow-x: auto; -webkit-overflow-scrolling: touch; max-width: 100%; }
        table { max-width: 100%; overflow-x: auto; display: block; }
        .tap-feedback { transition: background 0.15s; }
        .tap-feedback:active { background: #e5e7eb !important; }
        .swipe-hint { text-align: center; padding: 0.5rem; color: #9ca3af; font-size: 0.8rem; display: none; }
        @media (pointer: coarse) { .swipe-hint { display: block; } }
        .quiz-option, .tf-option, .recognize-option { -webkit-tap-highlight-color: transparent; }
        .quiz-option:active, .tf-option:active { transform: scale(0.98); transition: transform 0.1s; }
    }
    #js {
        // ---- 4.1.26: server-side exercises, loaded from /api/exercises ----
        function __ul_load_exercises() {
            var ctx = __ul_ctx();
            if (!ctx) { return; }
            var box = document.getElementById('api-exercises');
            var list = document.getElementById('exercise-list');
            if (!box || !list) { return; }
            fetch('/api/exercises/' + encodeURIComponent(ctx.concept))
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if (!data.exercises || data.exercises.length === 0) { return; }
                    box.style.display = '';
                    for (var i = 0; i < data.exercises.length; i++) { list.appendChild(__ul_build_exercise(data.exercises[i])); }
                })
                .catch(function() {});
        }
        function __ul_build_exercise(ex) {
            var card = document.createElement('div');
            card.className = 'exercise-card';
            var h = document.createElement('h4');
            h.textContent = ex.question;
            card.appendChild(h);
            var fb = document.createElement('div');
            fb.className = 'exercise-feedback';
            if (ex.type === 'recognize' && ex.options && ex.options.length > 0) {
                for (var j = 0; j < ex.options.length; j++) {
                    (function(opt) {
                        var b = document.createElement('button');
                        b.className = 'exercise-option';
                        b.textContent = opt;
                        b.onclick = function() { __ul_submit_exercise(ex, opt, b, fb); };
                        card.appendChild(b);
                    })(ex.options[j]);
                }
            } else {
                var wrap = document.createElement('div');
                var inp = document.createElement('input');
                inp.type = 'text';
                inp.className = 'exercise-input';
                inp.placeholder = 'Type your answer';
                var btn = document.createElement('button');
                btn.className = 'fill-check-btn';
                btn.textContent = 'Check';
                btn.onclick = function() { __ul_submit_exercise(ex, inp.value, btn, fb); };
                wrap.appendChild(inp); wrap.appendChild(btn);
                card.appendChild(wrap);
            }
            card.appendChild(fb);
            return card;
        }
        function __ul_submit_exercise(ex, answer, el, fb) {
            var url = '/api/exercises/submit?exercise_id=' + encodeURIComponent(ex.id) + '&answer=' + encodeURIComponent(answer);
            fetch(url, { method: 'POST' })
                .then(function(r) { return r.json(); })
                .then(function(res) {
                    var opts = el.parentNode.querySelectorAll('.exercise-option');
                    for (var k = 0; k < opts.length; k++) { opts[k].disabled = true; }
                    if (res.correct) {
                        if (el.classList) { el.classList.add('correct'); }
                        fb.className = 'exercise-feedback ok';
                    } else {
                        if (el.classList) { el.classList.add('wrong'); }
                        fb.className = 'exercise-feedback err';
                    }
                    var text = (res.correct ? 'Correct! ' : 'Not quite. ') + (res.explanation || '');
                    fb.textContent = text;
                })
                .catch(function() {});
        }
        document.addEventListener('DOMContentLoaded', function() { __ul_load_exercises(); });
        function __ul_ctx() {
            var parts = window.location.pathname.split('/').filter(function(p) { return p.length > 0; });
            if (parts.length >= 4) {
                if (parts[0] === 'courses') {
                    if (parts[2] === 'lessons') {
                        return { course: parts[1], concept: parts[3] };
                    }
                }
            }
            return null;
        }
        function __ul_token() {
            var t = '';
            try { t = localStorage.getItem('session_token') || ''; } catch (e) { t = ''; }
            return t;
        }
        function __ul_report_attempt(correct) {
            var ctx = __ul_ctx();
            if (!ctx) { return; }
            var t = __ul_token();
            if (!t) { return; }
            var rating = 'again';
            if (correct) { rating = 'good'; }
            var url = '/api/review/submit?concept_id=' + encodeURIComponent(ctx.concept) + '&course_id=' + encodeURIComponent(ctx.course) + '&rating=' + rating;
            try { fetch(url, { method: 'POST', headers: { 'Authorization': 'Bearer ' + t } }).catch(function() {}); } catch (e) {}
        }
        function __ul_report_view() {
            var ctx = __ul_ctx();
            if (!ctx) { return; }
            var t = __ul_token();
            if (!t) { return; }
            try {
                fetch('/api/learning/view', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + t },
                    body: JSON.stringify({ course_id: ctx.course, concept_id: ctx.concept })
                }).catch(function() {});
            } catch (e) {}
        }
        document.addEventListener('DOMContentLoaded', function() { __ul_report_view(); });
        document.addEventListener('click', function(ev) {
            var el = ev.target;
            while (el && el !== document && !(el.classList && el.classList.contains('quiz-option'))) { el = el.parentNode; }
            if (!el || el === document) { return; }
            setTimeout(function() { __ul_report_attempt(el.classList.contains('correct')); }, 80);
        }, true);
        document.addEventListener('change', function(ev) {
            var el = ev.target;
            if (!el || !el.classList) { return; }
            var isBlank = el.classList.contains('fill-blank');
            var isSelect = el.classList.contains('app-select');
            if (!isBlank && !isSelect) { return; }
            var ans = el.getAttribute('data-answer');
            if (!ans) { ans = el.getAttribute('data-correct'); }
            if (!ans) { return; }
            var val = '';
            if (el.value) { val = el.value; }
            val = val.trim();
            __ul_report_attempt(val === ans);
        }, true);
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct!';
                feedback.style.color = 'rgb(5,150,105)';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. Try again next time.';
                feedback.style.color = 'rgb(220,38,38)';
            }
        }
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

        function showToast(msg) {
            var t = document.getElementById('a11y-toast');
            if(!t) { t = document.createElement('div'); t.id = 'a11y-toast'; t.className = 'a11y-toast'; document.body.appendChild(t); }
            t.textContent = msg;
            t.classList.add('show');
            setTimeout(function() { t.classList.remove('show'); }, 1500);
        }
        document.addEventListener('keydown', function(e) {
            if(e.altKey && e.key === 'c') { e.preventDefault(); toggleHighContrast(); showToast('High contrast toggled'); }
            if(e.altKey && e.key === 'r') { e.preventDefault(); toggleReducedMotion(); showToast('Reduced motion toggled'); }
            if(e.altKey && e.key === '=') { e.preventDefault(); cycleFontSize(); }
        });
        function cycleFontSize() {
            var sizes = ['small','medium','large'];
            var current = localStorage.getItem('ulf-font-size') || 'medium';
            var idx = (sizes.indexOf(current) + 1) % sizes.length;
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.remove('font-small','font-large');
            if(sizes[idx] === 'small') lesson.classList.add('font-small');
            if(sizes[idx] === 'large') lesson.classList.add('font-large');
            localStorage.setItem('ulf-font-size', sizes[idx]);
            var el = document.getElementById('font-size');
            if(el) el.value = sizes[idx];
            showToast('Font size: ' + sizes[idx]);
        }
        function addFeedbackRatings() {
            var feedbacks = document.querySelectorAll('.quiz-feedback, .tf-feedback, .recognize-feedback, .app-feedback, .match-feedback, .fill-feedback');
            for(var i = 0; i < feedbacks.length; i++) {
                var fb = feedbacks[i];
                if(fb.nextElementSibling && fb.nextElementSibling.classList.contains('feedback-rating')) continue;
                var div = document.createElement('div');
                div.className = 'feedback-rating';
                div.innerHTML = '<span>Was this helpful?</span><button class="feedback-btn" onclick="rateFeedback(this, true)">👍</button><button class="feedback-btn" onclick="rateFeedback(this, false)">👎</button><span class="feedback-thanks">Thanks!</span>';
                fb.parentNode.insertBefore(div, fb.nextSibling);
            }
        }
        function rateFeedback(btn, helpful) {
            var container = btn.parentElement;
            var btns = container.querySelectorAll('.feedback-btn');
            for(var i = 0; i < btns.length; i++) btns[i].disabled = true;
            btn.classList.add('selected');
            container.querySelector('.feedback-thanks').style.display = 'inline';
        }
        addFeedbackRatings();

        (function() {
            var touchStartX = 0;
            var touchStartY = 0;
            var longPressTimer = null;
            document.addEventListener('touchstart', function(e) {
                touchStartX = e.changedTouches[0].screenX;
                touchStartY = e.changedTouches[0].screenY;
                var target = e.target;
                if(target.closest('.quiz-option, .tf-option, .recognize-option')) {
                    longPressTimer = setTimeout(function() { target.style.background = 'rgb(219,234,254)'; }, 500);
                }
            }, { passive: true });
            document.addEventListener('touchend', function(e) {
                clearTimeout(longPressTimer);
                var dx = e.changedTouches[0].screenX - touchStartX;
                var dy = e.changedTouches[0].screenY - touchStartY;
                if(Math.abs(dx) > 80 && Math.abs(dy) < 40) {
                    if(dx > 0) { var prev = document.querySelector('link[rel="prev"]'); if(prev) window.location.href = prev.href; }
                    else { var next = document.querySelector('link[rel="next"]'); if(next) window.location.href = next.href; }
                }
            }, { passive: true });
            var hexBlocks = document.querySelectorAll('.hex-dump, pre');
            for(var i = 0; i < hexBlocks.length; i++) {
                var el = hexBlocks[i];
                el.style.touchAction = 'pinch-zoom';
            }
        })();
        
        
    

        

    }

    return page.toString()
}
}
