// ELF Course — Concept 7: Program Header Table
// The table that describes how segments are loaded into memory.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_program_header_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Program Header Table — Underlayer")
    page.appendTitle(&title)

    #html {
        <header role="banner">
            <nav role="navigation" aria-label="Main navigation">
                <div class="a11y-controls">
                    <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                    <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                    <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
                </div>
                <div class="cb-controls">
                    <button class="a11y-btn" onclick="setColorBlind('none')" aria-label="Normal vision" id="cb-none">NV</button>
                    <button class="a11y-btn" onclick="setColorBlind('protanopia')" aria-label="Protanopia mode" id="cb-pro">P</button>
                    <button class="a11y-btn" onclick="setColorBlind('deuteranopia')" aria-label="Deuteranopia mode" id="cb-deu">D</button>
                    <button class="a11y-btn" onclick="setColorBlind('tritanopia')" aria-label="Tritanopia mode" id="cb-tri">T</button>
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
            </nav>
            </header>
            <main id="main-content" role="main">
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>Program Header Table</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The kernel doesn't load an ELF file byte-by-byte. It reads the program header table to find which parts of the file map to which memory regions. Without program headers, the loader wouldn't know what to load or where to put it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of program headers as a list of "load this chunk here" instructions. Each program header entry describes one <strong>segment</strong> — a contiguous region of the file that gets mapped into memory.</p>
                <ul>
                    <li><strong>LOAD segments</strong> — actual code and data to map</li>
                    <li><strong>DYNAMIC segment</strong> — dynamic linker info</li>
                    <li><strong>INTERP segment</strong> — path to the dynamic linker</li>
                    <li><strong>NOTE segment</strong> — auxiliary notes (build ID, etc.)</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each 64-bit program header entry is 56 bytes:</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>p_type</td><td>4</td><td>Segment type (PT_LOAD=1, PT_DYNAMIC=2, PT_INTERP=3, ...)</td></tr>
                        <tr><td>p_flags</td><td>4</td><td>Permissions: PF_X=1, PF_W=2, PF_R=4</td></tr>
                        <tr><td>p_offset</td><td>8</td><td>File offset where segment starts</td></tr>
                        <tr><td>p_vaddr</td><td>8</td><td>Virtual address to map to</td></tr>
                        <tr><td>p_paddr</td><td>8</td><td>Physical address (usually same as p_vaddr)</td></tr>
                        <tr><td>p_filesz</td><td>8</td><td>Size of segment in the file</td></tr>
                        <tr><td>p_memsz</td><td>8</td><td>Size of segment in memory (may be larger for .bss)</td></tr>
                        <tr><td>p_align</td><td>8</td><td>Alignment requirement</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>Program Headers:
  Type     Offset   VirtAddr           FileSiz  MemSiz   Flg  Align
  PHDR     0x000040 0x0000000000000040 0x000278 0x000278 R    0x8
  INTERP   0x0002b8 0x00000000000002b8 0x00001c 0x00001c R    0x1
  LOAD     0x000000 0x0000000000000000 0x0005e8 0x0005e8 R    0x1000
  LOAD     0x001000 0x0000000000001000 0x001a52 0x001a52 R E  0x1000
  LOAD     0x003000 0x0000000000003000 0x000ba0 0x000ba0 R    0x1000
  LOAD     0x003dc0 0x0000000000004dc0 0x000260 0x000260 RW   0x1000
  DYNAMIC  0x003e28 0x0000000000004e28 0x0001f0 0x0001f0 RW   0x8
  NOTE     0x0002d8 0x00000000000002d8 0x000030 0x000030 R    0x8</pre>
                </div>
                <p>The first LOAD segment is read-only (code and read-only data). The second LOAD is executable (the .text section). The last LOAD is read-write (data and BSS).</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does a PT_LOAD segment with p_memsz > p_filesz indicate?</p>
                <div class="quiz" id="quiz-pht-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, false)" aria-label="Option: The file is corrupted">The file is corrupted</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, true)" aria-label="Option: Extra memory is zero-initialized (like .bss)">Extra memory is zero-initialized (like .bss)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, false)" aria-label="Option: The segment is compressed">The segment is compressed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If p_vaddr is 0x4000 and p_offset is 0x0, what's the file offset of the first byte in the segment?</p>
                <div class="quiz" id="quiz-pht-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-2', this, true)" aria-label="Option: 0x0 — the byte is at offset 0">0x0 — the byte is at offset 0</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-2', this, false)" aria-label="Option: 0x4000 — same as the virtual address">0x4000 — same as the virtual address</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-2', this, false)" aria-label="Option: It depends on the alignment">It depends on the alignment</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Program headers define segments. But segments and sections are different things — segments are for the loader, sections are for tools. The next concepts explore this distinction.</p>
            </div>

            <nav class="toc" id="toc" aria-label="Table of contents">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
            </main>
            <footer role="contentinfo"><p>Underlayer — Learn Things Deeply</p></footer>
        <svg style="position:absolute;width:0;height:0">
            <defs>
                <filter id="protanopia"><feColorMatrix type="matrix" values="0.567,0.433,0,0,0 0.558,0.442,0,0,0 0,0.242,0.758,0,0 0,0,0,1,0"/></filter>
                <filter id="deuteranopia"><feColorMatrix type="matrix" values="0.625,0.375,0,0,0 0.7,0.3,0,0,0 0,0.3,0.7,0,0 0,0,0,1,0"/></filter>
                <filter id="tritanopia"><feColorMatrix type="matrix" values="0.95,0.05,0,0,0 0,0.433,0.567,0,0 0,0.475,0.525,0,0 0,0,0,1,0"/></filter>
            </defs>
        </svg>
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
        .cb-controls { position: fixed; top: 1rem; left: 5rem; display: flex; gap: 0.35rem; z-index: 60; }
        .cb-controls .a11y-btn { font-size: 0.65rem; }
        .cb-controls .a11y-btn.active { background: #1f2937; color: white; border-color: #1f2937; }
        footer { text-align: center; padding: 2rem 1rem; color: #6b7280; font-size: 0.85rem; border-top: 1px solid #e5e7eb; margin-top: 2rem; }
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

        function setColorBlind(mode) {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            var filters = { 'protanopia': 'url(#protanopia)', 'deuteranopia': 'url(#deuteranopia)', 'tritanopia': 'url(#tritanopia)' };
            lesson.style.filter = filters[mode] || '';
            localStorage.setItem('ulf-color-blind', mode);
            document.querySelectorAll('.cb-controls .a11y-btn').forEach(function(b) { b.classList.remove('active'); });
            var id = mode === 'none' ? 'cb-none' : 'cb-' + mode.substring(0,3);
            var activeBtn = document.getElementById(id);
            if(activeBtn) activeBtn.classList.add('active');
        }
        (function() {
            var cb = localStorage.getItem('ulf-color-blind') || 'none';
            if(cb !== 'none') { setColorBlind(cb); }
            else { var b = document.getElementById('cb-none'); if(b) b.classList.add('active'); }
        })();
    }

    return page.toString()
}
}
