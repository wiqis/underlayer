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
                        <tr><th>Section</th><th>Purpose</th><th>Processed By</th><th>When</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.rela.dyn</td><td>Data references, global offsets</td><td>ld.so (or static linker)</td><td>Load time</td></tr>
                        <tr><td>.rela.plt</td><td>Function calls via PLT</td><td>ld.so (lazy)</td><td>First call</td></tr>
                    </tbody>
                </table>
                <p>The most common dynamic relocation types on x86-64:</p>
                <table>
                    <thead>
                        <tr><th>Type</th><th>Value</th><th>Formula</th><th>Usage</th></tr>
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
    }

    return page.toString()
}
}
