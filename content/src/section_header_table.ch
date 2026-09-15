// ELF Course ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Concept 10: Section Header Table
// The table that describes each section in the ELF file.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_section_header_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Section Header Table ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Underlayer")
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
                        <dt><kbd>ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ</kbd></dt><dd>Back to top</dd>
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
            <h1>Section Header Table</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>While program headers are for the loader, section headers are for tools ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â the linker, debugger, readelf, objdump. They describe the logical structure of the file: where code lives, where symbols are defined, where relocations need to be applied.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of section headers as a detailed index of the file. Each entry describes one section with its name, type, flags, address, offset, and size.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each 64-bit section header entry is 64 bytes:</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>sh_name</td><td>4</td><td>Index into section name string table</td></tr>
                        <tr><td>sh_type</td><td>4</td><td>Section type (SHT_PROGBITS=1, SHT_SYMTAB=2, SHT_STRTAB=3, ...)</td></tr>
                        <tr><td>sh_flags</td><td>8</td><td>SHF_WRITE=1, SHF_ALLOC=2, SHF_EXECINSTR=4</td></tr>
                        <tr><td>sh_addr</td><td>8</td><td>Virtual address (0 if not loaded)</td></tr>
                        <tr><td>sh_offset</td><td>8</td><td>File offset</td></tr>
                        <tr><td>sh_size</td><td>8</td><td>Section size in bytes</td></tr>
                        <tr><td>sh_link</td><td>4</td><td>Link to related section</td></tr>
                        <tr><td>sh_info</td><td>4</td><td>Additional info</td></tr>
                        <tr><td>sh_addralign</td><td>8</td><td>Alignment</td></tr>
                        <tr><td>sh_entsize</td><td>8</td><td>Entry size (for tables)</td></tr>
                    </tbody>
                </table>
                <p>The <code>e_shstrndx</code> field in the ELF header points to the section that contains all section names (typically <code>.shstrtab</code>).</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -S /bin/ls | head -15
Section Headers:
  [Nr] Name              Type             Address          Offset   Size
  [ 0]                   NULL             0000000000000000 00000000 000000
  [ 1] .interp           PROGBITS         00000000000002b8 000002b8 00001c
  [ 2] .note.gnu.property NOTE             00000000000002d8 000002d8 000020
  [ 3] .gnu.hash         GNU_HASH         00000000000002f8 000002f8 0000b0
  [ 4] .dynsym           DYNSYM           00000000000003a8 000003a8 000180
  [ 5] .dynstr           STRTAB           0000000000000528 00000528 0000c0
  [ 6] .gnu.version      VERNEED          00000000000005e8 000005e8 00003c
  [ 7] .gnu.version_r    VERNEED          0000000000000624 00000624 000060</pre>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does the sh_addr field represent?</p>
                <div class="quiz" id="quiz-sht-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, false)">The file offset</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, true)">The virtual address in memory</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, false)">The section size</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A section has sh_offset=0x1000 and sh_size=0x200. How many bytes of the ELF file does it occupy?</p>
                <div class="quiz" id="quiz-sht-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, true)">0x200 (512 bytes)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, false)">0x1000 (4096 bytes)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, false)">0x1200</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Section headers describe individual sections. The next concept covers the most common sections you'll encounter.</p>
            </div>

            <nav class="toc" id="toc">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ Top</button>
            <div class="a11y-toast" id="a11y-toast"></div>
            <div class="swipe-hint">ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Swipe to navigate ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢</div>
            <link rel="prev" href="">
            <link rel="next" href="">
        </div>

        }
    }}
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
        /* 7.3.6: Theme preview */
        .theme-preview-bar { display: flex; gap: 0.5rem; padding: 0.5rem 1rem; background: #f9fafb; border-bottom: 1px solid #e5e7eb; align-items: center; font-size: 0.8rem; }
        .theme-preview-bar label { color: #6b7280; margin-right: 0.25rem; }
        .theme-preview-bar .swatch { width: 20px; height: 20px; border-radius: 4px; border: 2px solid transparent; cursor: pointer; transition: border-color 0.2s; }
        .theme-preview-bar .swatch:hover { border-color: #2563eb; }
        .theme-preview-bar .swatch.active { border-color: #2563eb; box-shadow: 0 0 0 2px rgba(37,99,235,0.3); }
        /* 7.4.13: Responsive visualizations */
        .hex-dump, pre, .elf-dump { max-width: 100%; overflow-x: auto; font-size: 0.85rem; }
        @media (max-width: 640px) { .hex-dump, pre, .elf-dump { font-size: 0.75rem; } }
        @media (max-width: 480px) { .hex-dump, pre, .elf-dump { font-size: 0.7rem; } }
        .vis-container { resize: horizontal; overflow: auto; min-width: 200px; max-width: 100%; border: 1px dashed #d1d5db; padding: 0.5rem; }
        table { font-size: 0.85rem; }
        @media (max-width: 640px) { table { font-size: 0.75rem; } }

        /* 7.1.13-15: Navigation indicators */
        .nav-indicator { position: fixed; top: 0; left: 0; right: 0; z-index: 100; background: white; border-bottom: 1px solid #e5e7eb; padding: 0.5rem 1rem; display: flex; align-items: center; gap: 1rem; font-size: 0.85rem; }
        .nav-progress { flex: 1; height: 4px; background: #e5e7eb; border-radius: 2px; overflow: hidden; }
        .nav-progress-fill { height: 100%; background: #10b981; transition: width 0.3s; border-radius: 2px; }
        .nav-status { display: flex; gap: 0.75rem; align-items: center; }
        .nav-status .indicator { padding: 0.2rem 0.5rem; border-radius: 10px; font-size: 0.75rem; font-weight: 500; }
        .nav-status .mastered { background: #d1fae5; color: #065f46; }
        .nav-status .learning { background: #dbeafe; color: #1e40af; }
        .nav-status .due { background: #fef3c7; color: #92400e; }
        .nav-status .new { background: #e5e7eb; color: #374151; }
        .nav-links { display: flex; gap: 0.5rem; }
        .nav-links a { padding: 0.3rem 0.75rem; border-radius: 4px; text-decoration: none; background: #f3f4f6; color: #374151; font-size: 0.8rem; }
        .nav-links a:hover { background: #e5e7eb; }
        .nav-links a.disabled { opacity: 0.4; pointer-events: none; }
        @media (max-width: 768px) { .nav-indicator { flex-wrap: wrap; } }
            }

    }
    #js {
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
        function checkQuiz(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) { btn.classList.add('correct'); feedback.textContent = 'Correct!'; feedback.style.color = '#059669'; }
            else { btn.classList.add('wrong'); feedback.textContent = 'Not quite.'; feedback.style.color = '#dc2626'; }
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

        (function() {
            var touchStartX = 0;
            var touchStartY = 0;
            var longPressTimer = null;
            document.addEventListener('touchstart', function(e) {
                touchStartX = e.changedTouches[0].screenX;
                touchStartY = e.changedTouches[0].screenY;
                var target = e.target;
                if(target.closest('.quiz-option, .tf-option, .recognize-option')) {
                    longPressTimer = setTimeout(function() { target.style.background = '#dbeafe'; }, 500);
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
        
        
    

        

        // 7.3.6: Theme preview (live color swatches in top bar)
        (function() {
            var themes = {
                'light': { bg: '#ffffff', text: '#111827', accent: '#2563eb', card: '#f9fafb' },
                'dark': { bg: '#111827', text: '#f9fafb', accent: '#60a5fa', card: '#1f2937' },
                'blue': { bg: '#eff6ff', text: '#1e3a5f', accent: '#3b82f6', card: '#dbeafe' },
                'green': { bg: '#f0fdf4', text: '#14532d', accent: '#22c55e', card: '#dcfce7' }
            };
            var bar = document.createElement('div');
            bar.className = 'theme-preview-bar';
            bar.innerHTML = '<label>Theme:</label>';
            var current = localStorage.getItem('ulf_theme_preview') || 'light';
            var keys = ['light', 'dark', 'blue', 'green'];
            for(var i = 0; i < keys.length; i++) {
                (function(key) {
                    var swatch = document.createElement('div');
                    swatch.className = 'swatch' + (key === current ? ' active' : "");
                    swatch.style.background = themes[key].accent;
                    swatch.title = key;
                    swatch.addEventListener('click', function() {
                        document.querySelectorAll('.theme-preview-bar .swatch').forEach(function(s) { s.classList.remove('active'); });
                        swatch.classList.add('active');
                        localStorage.setItem('ulf_theme_preview', key);
                        applyTheme(key);
                    });
                    bar.appendChild(swatch);
                })(keys[i]);
            }
            document.body.insertBefore(bar, document.body.firstChild);
            function applyTheme(key) {
                var t = themes[key];
                document.documentElement.style.setProperty('--bg', t.bg);
                document.documentElement.style.setProperty('--text', t.text);
                document.documentElement.style.setProperty('--accent', t.accent);
                document.documentElement.style.setProperty('--card', t.card);
                document.body.style.background = t.bg;
                document.body.style.color = t.text;
            }
            applyTheme(current);
        })();

        // 7.4.13: Responsive visualizations (resize hex dumps + tables)
        (function() {
            function makeResponsive() {
                var els = document.querySelectorAll('.hex-dump, pre, table, .elf-dump');
                for(var i = 0; i < els.length; i++) {
                    var el = els[i];
                    if(!el.parentElement || el.parentElement.className.indexOf('vis-container') >= 0) continue;
                    var wrapper = document.createElement('div');
                    wrapper.className = 'vis-container';
                    el.parentNode.insertBefore(wrapper, el);
                    wrapper.appendChild(el);
                }
            }
            if(document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', makeResponsive); }
            else { makeResponsive(); }
            var resizeTimer;
            window.addEventListener('resize', function() {
                clearTimeout(resizeTimer);
                resizeTimer = setTimeout(function() {
                    var els = document.querySelectorAll('.hex-dump, pre');
                    for(var i = 0; i < els.length; i++) {
                        els[i].style.opacity = '0.7';
                        setTimeout(function(el) { el.style.opacity = '1'; }.bind(null, els[i]), 100);
                    }
                }, 250);
            });
        })();

        // 4.2.16-17: Exercise mistake pattern detection + personalized feedback
        (function() {
            var mistakeLog = JSON.parse(localStorage.getItem('ulf_mistakes') || '{}');
            function logMistake(conceptId, questionText, correctAnswer) {
                if(!mistakeLog[conceptId]) { mistakeLog[conceptId] = []; } else { }
                var exists = false;
                for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                    if(mistakeLog[conceptId][i].q === questionText) { exists = true; break; } else { }
                }
                if(!exists) {
                    mistakeLog[conceptId].push({ q: questionText, a: correctAnswer, count: 1, last: Date.now() });
                } else {
                    for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                        if(mistakeLog[conceptId][i].q === questionText) {
                            mistakeLog[conceptId][i].count++;
                            mistakeLog[conceptId][i].last = Date.now();
                        } else { }
                    }
                }
                localStorage.setItem('ulf_mistakes', JSON.stringify(mistakeLog));
            }
            function getMistakeCount(conceptId, questionText) {
                if(!mistakeLog[conceptId]) { return 0; } else { }
                for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                    if(mistakeLog[conceptId][i].q === questionText) { return mistakeLog[conceptId][i].count; } else { }
                }
                return 0;
            }
            function generateHint(conceptId, questionText, correctAnswer) {
                var count = getMistakeCount(conceptId, questionText);
                if(count >= 3) {
                    return "You have gotten this wrong " + count + " times. Key concept: " + correctAnswer.substring(0, 80) + "...";
                } else if(count >= 2) {
                    return "This is a tricky one. Think about: " + correctAnswer.substring(0, 60);
                } else { return ""; }
            }
            var conceptId = window.location.pathname.split('/').pop().replace('.html', "") || 'unknown';
            document.querySelectorAll('.quiz-option, .tf-option, .recognize-option').forEach(function(btn) {
                btn.addEventListener('click', function() {
                    var isCorrect = btn.dataset.correct === 'true' || btn.classList.contains('correct');
                    var questionEl = btn.closest('.quiz, .true-false, .recognize');
                    if(!isCorrect && questionEl) {
                        var qText = (questionEl.querySelector('h3') || questionEl.querySelector('p') || {}).textContent || "";
                        var correctBtn = questionEl.querySelector('[data-correct="true"], .correct');
                        var correctAns = correctBtn ? correctBtn.textContent : "";
                        logMistake(conceptId, qText, correctAns);
                        var hint = generateHint(conceptId, qText, correctAns);
                        if(hint) {
                            var hintEl = document.createElement('div');
                            hintEl.className = 'mistake-hint';
                            hintEl.style.cssText = 'background:#fef3c7;border:1px solid #f59e0b;padding:0.75rem;border-radius:6px;margin-top:0.5rem;font-size:0.9rem;color:#92400e;';
                            hintEl.textContent = hint;
                            questionEl.appendChild(hintEl);
                        } else { }
                    } else { }
                });
            });
        })();

                    }
            var pct = total > 0 ? Math.round((mastered / total) * 100) : 0;
            var status = 'new';
            if(progress[conceptId] && progress[conceptId].status === 'mastered') { status = 'mastered'; }
            else if(progress[conceptId] && progress[conceptId].status === 'learning') { status = 'learning'; }
            else if(dueItems[conceptId]) { status = 'due'; }
            var nav = document.createElement('div');
            nav.className = 'nav-indicator';
            nav.innerHTML = '<div class="nav-progress"><div class="nav-progress-fill" style="width:' + pct + '%"></div></div>' +
                '<div class="nav-status"><span class="indicator ' + status + '">' + status + '</span>' +
                '<span>' + mastered + '/' + total + ' mastered</span></div>' +
                '<div class="nav-links">' +
                (idx > 0 ? '<a href="' + allConcepts[idx-1] + '.html">&larr; Prev</a>' : '<a class="disabled">&larr; Prev</a>') +
                (idx < total - 1 ? '<a href="' + allConcepts[idx+1] + '.html">Next &rarr;</a>' : '<a class="disabled">Next &rarr;</a>') +
                '</div>';
            document.body.insertBefore(nav, document.body.firstChild);
            document.body.style.paddingTop = '50px';
            if(!reviewed[conceptId]) {
                reviewed[conceptId] = Date.now();
                localStorage.setItem('ulf_reviewed', JSON.stringify(reviewed));
            }
            if(!progress[conceptId]) {
                progress[conceptId] = { status: 'learning', firstVisited: Date.now(), lastVisited: Date.now() };
                localStorage.setItem('ulf_progress', JSON.stringify(progress));
            } else {
                progress[conceptId].lastVisited = Date.now();
                localStorage.setItem('ulf_progress', JSON.stringify(progress));
            }
        })()

        // 7.1.10: Quick jump / command palette (Ctrl+K or /)
        (function() {
            var allConcepts = [
                {id:'bytes',title:'Bytes and Binary',module:'Fundamentals'},
                {id:'binary-representation',title:'Binary Representation',module:'Fundamentals'},
                {id:'file-layout',title:'File Layout',module:'Fundamentals'},
                {id:'elf-identification',title:'ELF Identification',module:'ELF Header'},
                {id:'elf-header-fields',title:'ELF Header Fields',module:'ELF Header'},
                {id:'entry-point',title:'Entry Point',module:'ELF Header'},
                {id:'program-header-table',title:'Program Header Table',module:'Program Headers'},
                {id:'segment-types',title:'Segment Types',module:'Program Headers'},
                {id:'memory-mapping',title:'Memory Mapping',module:'Program Headers'},
                {id:'section-header-table',title:'Section Header Table',module:'Sections'},
                {id:'common-sections',title:'Common Sections',module:'Sections'},
                {id:'section-vs-segment',title:'Section vs Segment',module:'Sections'},
                {id:'symbol-table',title:'Symbol Table',module:'Symbols'},
                {id:'binding',title:'Symbol Binding',module:'Symbols'},
                {id:'visibility',title:'Symbol Visibility',module:'Symbols'},
                {id:'relocation-entries',title:'Relocation Entries',module:'Relocations'},
                {id:'relocation-types',title:'Relocation Types',module:'Relocations'},
                {id:'dynamic-relocations',title:'Dynamic Relocations',module:'Relocations'},
                {id:'dynamic-section',title:'Dynamic Section',module:'Dynamic Linking'},
                {id:'shared-libraries',title:'Shared Libraries',module:'Dynamic Linking'}
            ];
            var overlay = document.createElement('div');
            overlay.className = 'quick-jump-overlay';
            overlay.innerHTML = '<div class="quick-jump"><input type="text" placeholder="Jump to concept... (Esc to close)" id="quickJumpInput" /><div class="quick-jump-results" id="quickJumpResults"></div><div class="quick-jump-hint"><kbd>Up/Down</kbd> navigate <kbd>Enter</kbd> go <kbd>Esc</kbd> close</div></div>';
            document.body.appendChild(overlay);
            var input = document.getElementById('quickJumpInput');
            var results = document.getElementById('quickJumpResults');
            var selectedIdx = 0;
            function showResults(query) {
                var q = query.toLowerCase();
                var matches = allConcepts.filter(function(c) { return c.title.toLowerCase().indexOf(q) >= 0 || c.module.toLowerCase().indexOf(q) >= 0 || c.id.indexOf(q) >= 0; });
                results.innerHTML = "";
                selectedIdx = 0;
                for(var i = 0; i < matches.length && i < 8; i++) {
                    var div = document.createElement('div');
                    div.className = 'result' + (i === 0 ? ' selected' : "");
                    div.innerHTML = '<div>' + matches[i].title + '</div><div class="module">' + matches[i].module + '</div>';
                    div.dataset.url = matches[i].id + '.html';
                    div.addEventListener('click', function() { window.location.href = this.dataset.url; });
                    results.appendChild(div);
                }
            }
            function openPalette() { overlay.classList.add('active'); input.value = ""; input.focus(); showResults(""); }
            function closePalette() { overlay.classList.remove('active'); }
            document.addEventListener('keydown', function(e) {
                if((e.ctrlKey && e.key === 'k') || (e.key === '/' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA')) {
                    e.preventDefault(); openPalette();
                }
                if(e.key === 'Escape') { closePalette(); }
                if(overlay.classList.contains('active')) {
                    var items = results.querySelectorAll('.result');
                    if(e.key === 'ArrowDown') { e.preventDefault(); selectedIdx = Math.min(selectedIdx + 1, items.length - 1); items.forEach(function(item, i) { item.classList.toggle('selected', i === selectedIdx); }); }
                    if(e.key === 'ArrowUp') { e.preventDefault(); selectedIdx = Math.max(selectedIdx - 1, 0); items.forEach(function(item, i) { item.classList.toggle('selected', i === selectedIdx); }); }
                    if(e.key === 'Enter' && items[selectedIdx]) { window.location.href = items[selectedIdx].dataset.url; }
                }
            });
            overlay.addEventListener('click', function(e) { if(e.target === overlay) { closePalette(); } });
            input.addEventListener('input', function() { showResults(this.value); });
        })();

        // 7.1.13-15: Navigation indicators (progress, unread, due)
        (function() {
            var allConcepts = ["bytes","binary-representation","file-layout","elf-identification","elf-header-fields","entry-point","program-header-table","segment-types","memory-mapping","section-header-table","common-sections","section-vs-segment","symbol-table","binding","visibility","relocation-entries","relocation-types","dynamic-relocations","dynamic-section","shared-libraries"];
            var conceptId = window.location.pathname.split("/").pop().replace(".html", "") || "bytes";
            var progress = JSON.parse(localStorage.getItem("ulf_progress") || "{}");
            var reviewed = JSON.parse(localStorage.getItem("ulf_reviewed") || "{}");
            var dueItems = JSON.parse(localStorage.getItem("ulf_due") || "{}");
            var idx = allConcepts.indexOf(conceptId);
            var total = allConcepts.length;
            var mastered = 0;
            for(var i = 0; i < total; i++) {
                if(progress[allConcepts[i]] && progress[allConcepts[i]].status === "mastered") { mastered++; }
            }
            var pct = total > 0 ? Math.round((mastered / total) * 100) : 0;
            var status = "new";
            if(progress[conceptId] && progress[conceptId].status === "mastered") { status = "mastered"; }
            else if(progress[conceptId] && progress[conceptId].status === "learning") { status = "learning"; }
            else if(dueItems[conceptId]) { status = "due"; }
            var nav = document.createElement("div");
            nav.className = "nav-indicator";
            nav.innerHTML = "<div class=\"nav-progress\"><div class=\"nav-progress-fill\" style=\"width:" + pct + "%\"></div></div>" +
                "<div class=\"nav-status\"><span class=\"indicator " + status + "\">" + status + "</span>" +
                "<span>" + mastered + "/" + total + " mastered</span></div>" +
                "<div class=\"nav-links\">" +
                (idx > 0 ? "<a href=\"" + allConcepts[idx-1] + ".html\">&larr; Prev</a>" : "<a class=\"disabled\">&larr; Prev</a>") +
                (idx < total - 1 ? "<a href=\"" + allConcepts[idx+1] + ".html\">Next &rarr;</a>" : "<a class=\"disabled\">Next &rarr;</a>") +
                "</div>";
            document.body.insertBefore(nav, document.body.firstChild);
            document.body.style.paddingTop = "50px";
            if(!reviewed[conceptId]) {
                reviewed[conceptId] = Date.now();
                localStorage.setItem("ulf_reviewed", JSON.stringify(reviewed));
            }
            if(!progress[conceptId]) {
                progress[conceptId] = { status: "learning", firstVisited: Date.now(), lastVisited: Date.now() };
                localStorage.setItem("ulf_progress", JSON.stringify(progress));
            } else {
                progress[conceptId].lastVisited = Date.now();
                localStorage.setItem("ulf_progress", JSON.stringify(progress));
            }
        })();
    }

    return page.toString()
}
}