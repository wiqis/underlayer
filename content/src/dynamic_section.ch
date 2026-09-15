// ELF Course — Concept 19: Dynamic Section
// The .dynamic section — the control structure for dynamic linking.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_dynamic_section() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Dynamic Section — Underlayer")
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
            <h1>The Dynamic Section</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When ld.so loads your program, how does it know which shared libraries you need? Where is the symbol table? Where are the relocations? The answer is the <strong>.dynamic</strong> section — a table of key-value pairs that tells the dynamic linker everything it needs to know.</p>
                <p>The .dynamic section is the "instruction manual" that ld.so reads to set up your program's runtime environment.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of .dynamic as a configuration file embedded in the ELF binary. Each entry is a tag-value pair:</p>
                <ul>
                    <li><strong>DT_NEEDED</strong> — "I need this shared library" (e.g., libc.so.6)</li>
                    <li><strong>DT_SYMTAB</strong> — "The dynamic symbol table is at this offset"</li>
                    <li><strong>DT_STRTAB</strong> — "The string table is at this offset"</li>
                    <li><strong>DT_REL/DT_RELA</strong> — "The relocation table is at this offset"</li>
                    <li><strong>DT_INIT</strong> — "Call this function before main()"</li>
                    <li><strong>DT_FINI</strong> — "Call this function after main() returns"</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each dynamic entry is an <strong>Elf64_Dyn</strong> structure:</p>
                <div class="hex-dump"><pre># Elf64_Dyn structure (16 bytes):
#   d_tag  (Elf64_Sxword)  What this entry describes
#   d_un   (union)         Value: either d_val (integer) or d_ptr (address)</pre></div>
                <p>Key tags:</p>
                <table>
                    <thead>
                        <tr><th>Tag</th><th>Value</th><th>Purpose</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>DT_NEEDED</td><td>1</td><td>Shared library dependency (offset into DT_STRTAB)</td></tr>
                        <tr><td>DT_SYMTAB</td><td>6</td><td>Address of .dynsym section</td></tr>
                        <tr><td>DT_STRTAB</td><td>5</td><td>Address of .dynstr section</td></tr>
                        <tr><td>DT_RELA</td><td>7</td><td>Address of .rela.dyn section</td></tr>
                        <tr><td>DT_RELASZ</td><td>8</td><td>Size of .rela.dyn in bytes</td></tr>
                        <tr><td>DT_JMPREL</td><td>23</td><td>Address of .rela.plt (PLT relocations)</td></tr>
                        <tr><td>DT_INIT</td><td>12</td><td>Initialization function address</td></tr>
                        <tr><td>DT_FINI</td><td>13</td><td>Finalization function address</td></tr>
                        <tr><td>DT_INIT_ARRAY</td><td>25</td><td>Array of init functions</td></tr>
                        <tr><td>DT_NEEDED</td><td>1</td><td>Each occurrence = one library dependency</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -d /bin/ls

Dynamic section at offset 0x3ba0 contains 30 entries:
  Tag        Type                 Name/Value
 0x0000000000000001 (NEEDED)     Shared library: [libc.so.6]
 0x000000000000000c (INIT)       0x3000
 0x000000000000000d (FINI)       0x5c1c
 0x0000000000000019 (INIT_ARRAY) 0x3be8
 0x000000000000001b (INIT_ARRAYSZ) 8 (bytes)
 0x000000000000001a (FINI_ARRAY) 0x3bf0
 0x000000000000001c (FINI_ARRAYSZ) 8 (bytes)
 0x0000000000000005 (STRTAB)     0x2288
 0x0000000000000006 (SYMTAB)     0x1a80
 0x000000000000000a (STRSZ)      568 (bytes)
 0x000000000000000b (SYMENT)     24 (bytes)
 0x0000000000000015 (PLTREL)     RELA
 0x0000000000000002 (PLTGOT)     0x3fe8
 0x0000000000000017 (JMPREL)     0x2918
 0x0000000000000007 (RELA)       0x27e0
 0x0000000000000008 (RELASZ)     312 (bytes)
 0x0000000000000009 (RELAENT)    24 (bytes)</pre>
                </div>
                <p>The DT_NEEDED entries tell you exactly which libraries are required:</p>
                <ul>
                    <li><strong>libc.so.6</strong> — the C standard library (nearly every program needs this)</li>
                </ul>
                <p>A complex program might show dozens of DT_NEEDED entries for different libraries.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See the dynamic section of any ELF
readelf -d /bin/ls

# Count library dependencies
readelf -d /bin/ls | grep NEEDED | wc -l

# See what a typical program links against
readelf -d /usr/bin/python3 | grep NEEDED

# Compare: static vs dynamic binary
gcc -o dynamic hello.c
gcc -static -o static hello.c
readelf -d dynamic    # has .dynamic section
readelf -d static     # no .dynamic section (or empty)</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the purpose of DT_NEEDED entries in the .dynamic section?</p>
                <div class="quiz" id="quiz-ds-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-1', this, false)">They list the exported symbols</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-1', this, true)">They specify which shared libraries the program depends on</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-1', this, false)">They store the program's entry point</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If you see a DT_NEEDED entry for "libfoo.so.3" but the library is installed as "libfoo.so.4", what will happen?</p>
                <div class="quiz" id="quiz-ds-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-2', this, false)">ld.so will use libfoo.so.4 automatically</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-2', this, true)">ld.so will fail to load the program with "libfoo.so.3: cannot open shared object file"</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ds-2', this, false)">The program will crash at runtime</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The .dynamic section lists library dependencies. But how do shared libraries themselves work — how are they built, versioned, and found at runtime? That's the next concept.</p>
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
        ul { margin: 0.5rem 0; padding-left: 1.5rem; }
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
