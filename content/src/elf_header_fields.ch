// ELF Course ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Concept 5: ELF Header Fields
// Every field in the ELF header and what it tells the system.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_elf_header_fields() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ELF Header Fields ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Underlayer")
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
                        <dt><kbd>ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ</kbd></dt><dd>Back to top</dd>
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
            <h1>ELF Header Fields</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The ELF header is the first thing any tool reads. It tells the linker where sections are, the loader where program headers are, and the debugger what architecture the code targets. Every field has a specific purpose ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â and understanding them means you can read any ELF file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The ELF header (after the 16-byte e_ident) contains metadata about the file. Think of it as a table of contents:</p>
                <ul>
                    <li><strong>What type is it?</strong> (executable, shared library, relocatable)</li>
                    <li><strong>What architecture?</strong> (x86, ARM, RISC-V)</li>
                    <li><strong>Where does code start?</strong> (entry point address)</li>
                    <li><strong>Where are the program headers?</strong> (for the loader)</li>
                    <li><strong>Where are the section headers?</strong> (for tools)</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Here are all fields in the 64-bit ELF header (52 bytes after e_ident, total 64 bytes):</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Offset</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>e_ident</td><td>0</td><td>16</td><td>Identification array (previous concept)</td></tr>
                        <tr><td>e_type</td><td>16</td><td>2</td><td>ET_EXEC (2), ET_DYN (3), ET_REL (1)</td></tr>
                        <tr><td>e_machine</td><td>18</td><td>2</td><td>Architecture: 0x03=x86, 0x3E=x86-64, 0x28=ARM, 0xF3=RISC-V</td></tr>
                        <tr><td>e_version</td><td>20</td><td>4</td><td>ELF version (always 1)</td></tr>
                        <tr><td>e_entry</td><td>24</td><td>8</td><td>Virtual address of entry point</td></tr>
                        <tr><td>e_phoff</td><td>32</td><td>8</td><td>Program header table offset</td></tr>
                        <tr><td>e_shoff</td><td>40</td><td>8</td><td>Section header table offset</td></tr>
                        <tr><td>e_flags</td><td>48</td><td>4</td><td>Processor-specific flags</td></tr>
                        <tr><td>e_ehsize</td><td>52</td><td>2</td><td>ELF header size (64 for 64-bit)</td></tr>
                        <tr><td>e_phentsize</td><td>54</td><td>2</td><td>Program header entry size (56 for 64-bit)</td></tr>
                        <tr><td>e_phnum</td><td>56</td><td>2</td><td>Number of program header entries</td></tr>
                        <tr><td>e_shentsize</td><td>58</td><td>2</td><td>Section header entry size (64 for 64-bit)</td></tr>
                        <tr><td>e_shnum</td><td>60</td><td>2</td><td>Number of section header entries</td></tr>
                        <tr><td>e_shstrndx</td><td>62</td><td>2</td><td>Section name string table index</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here's a real ELF header from a 64-bit Linux binary:</p>
                <div class="hex-dump">
                    <pre>ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  Type:                              DYN (Position-Independent Executable)
  Machine:                           Advanced Micro Devices x86-64
  Entry point address:               0x6810
  Start of program headers:          64 (bytes into file)
  Start of section headers:          16400 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program header entries:    56 (bytes)
  Number of program headers:         9
  Size of section header entries:    64 (bytes)
  Number of section headers:         27
  Section header string table index: 26</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Use <code>readelf -h</code> on different binaries to compare headers. Try the <code>ls</code>, <code>python3</code>, or any compiled program in bin directories.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What field in the ELF header tells the loader where the program header table begins?</p>
                <div class="quiz" id="quiz-ehf-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, false)" aria-label="Option: e_shoff">e_shoff</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, true)" aria-label="Option: e_phoff">e_phoff</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, false)" aria-label="Option: e_entry">e_entry</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If <code>e_phnum = 9</code> and <code>e_phentsize = 56</code>, how many bytes does the program header table occupy?</p>
                <div class="quiz" id="quiz-ehf-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, false)" aria-label="Option: 56 bytes">56 bytes</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, true)" aria-label="Option: 504 bytes">504 bytes</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, false)" aria-label="Option: 9 bytes">9 bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>9 entries ÃƒÆ’Ã¢â‚¬â€ 56 bytes each = 504 bytes total.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand every field in the ELF header. The entry point field (next concept) deserves special attention ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â it's where execution begins.</p>
            </div>

            <nav class="toc" id="toc" aria-label="Table of contents">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ Top</button>
            </main>
            <div class="swipe-hint">ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Swipe to navigate ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢</div>
            <link rel="prev" href="">
            <link rel="next" href="">
            <footer role="contentinfo"><p>Underlayer ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Learn Things Deeply</p></footer>
        <svg style="position:absolute;width:0;height:0">
            <defs>
                <filter id="protanopia"><feColorMatrix type="matrix" values="0.567,0.433,0,0,0 0.558,0.442,0,0,0 0,0.242,0.758,0,0 0,0,0,1,0"/></filter>
                <filter id="deuteranopia"><feColorMatrix type="matrix" values="0.625,0.375,0,0,0 0.7,0.3,0,0,0 0,0.3,0.7,0,0 0,0,0,1,0"/></filter>
                <filter id="tritanopia"><feColorMatrix type="matrix" values="0.95,0.05,0,0,0 0,0.433,0.567,0,0 0,0.475,0.525,0,0 0,0,0,1,0"/></filter>
            </defs>
        </svg>
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
            lesson.style.filter = filters[mode] || "";
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
                div.innerHTML = '<span>Was this helpful?</span><button class="feedback-btn" onclick="rateFeedback(this, true)">&#x1f44d;</button><button class="feedback-btn" onclick="rateFeedback(this, false)">&#x1f44e;</button><span class="feedback-thanks">Thanks!</span>';
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
