// ELF Course ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Concept 20: Shared Libraries
// How .so files work, soname versioning, library paths, and the linking model.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_shared_libraries() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Shared Libraries ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Underlayer")
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
            <h1>Shared Libraries</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Shared libraries are the reason your system doesn't need a separate copy of printf() in every program. Instead, one copy of libc.so lives on disk, and every program shares it at runtime. This saves disk space, memory, and makes updating libraries possible without recompiling every program.</p>
                <p>Understanding shared libraries explains why you see ".so" files, why "library not found" errors happen, and how versioning keeps old programs working.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A shared library is a position-independent ELF executable that can be loaded at any address. It's built with three key concepts:</p>
                <ul>
                    <li><strong>Real name</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â The actual file: libfoo.so.1.2.3</li>
                    <li><strong>Soname</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â The compatibility name: libfoo.so.1 (symlink to real name)</li>
                    <li><strong>Linker name</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â The development name: libfoo.so (symlink to soname, used at compile time)</li>
                </ul>
                <p>This three-level naming lets you update a library (bump 1.2.3 to 1.2.4) without breaking programs linked against soname "libfoo.so.1".</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Building a shared library:</p>
                <div class="hex-dump"><pre># Compile with -fPIC (position-independent code)
gcc -fPIC -c foo.c -o foo.o
gcc -fPIC -c bar.c -o bar.o

# Create the shared library
gcc -shared -o libfoo.so.1.2.3 foo.o bar.o

# Create versioned symlinks
ln -s libfoo.so.1.2.3 libfoo.so.1    # soname
ln -s libfoo.so.1 libfoo.so          # linker name

# The soname is embedded in the library
readelf -d libfoo.so.1.2.3 | grep SONAME
# 0x000000000000000e (SONAME)    Library soname: [libfoo.so.1]</pre></div>
                <p>At compile time, the linker reads the soname from the library and stores it in your program's .dynamic section:</p>
                <div class="hex-dump"><pre>gcc -o myprog myprog.c -L. -lfoo
readelf -d myprog | grep NEEDED
# 0x0000000000000001 (NEEDED)  Shared library: [libfoo.so.1]
# Note: it says libfoo.so.1, NOT libfoo.so.1.2.3</pre></div>
                <p>At runtime, ld.so searches for "libfoo.so.1" and follows the symlink chain to find the actual file.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ ls -la /usr/lib/x86_64-linux-gnu/libc.so*
lrwxrwxrwx 1 root root 14 libc.so.6 symlink libc.so.6

$ readelf -d /usr/lib/x86_64-linux-gnu/libc.so.6 | grep SONAME
 0x000000000000000e (SONAME)  Library soname: [libc.so.6]

# The linker name (for gcc -lc) is a separate file:
$ file /usr/lib/x86_64-linux-gnu/libc.so
/usr/lib/x86_64-linux-gnu/libc.so: ASCII text

$ cat /usr/lib/x86_64-linux-gnu/libc.so
/* GNU ld script */
OUTPUT_FORMAT(elf64-x86-64)
GROUP ( /usr/lib/x86_64-linux-gnu/libc.so.6
        /usr/lib/x86_64-linux-gnu/libc_nonshared.a
        AS_NEEDED ( /usr/lib/x86_64-linux-gnu/libdl.so.2 ) )</pre>
                </div>
                <p>On Debian/Ubuntu, the linker name is actually a text script that specifies which real libraries to link. This is how the linker resolves -lc to the correct libc version.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See the soname of any shared library
readelf -d /usr/lib/x86_64-linux-gnu/libc.so.6 | grep SONAME

# Build your own shared library
# mylib.c: int my_func(int x) returns x * 2
gcc -fPIC -shared -Wl,-soname,libmylib.so.1 -o libmylib.so.1.0 mylib.c
ln -s libmylib.so.1.0 libmylib.so.1
ln -s libmylib.so.1 libmylib.so

# Verify soname
readelf -d libmylib.so.1.0 | grep SONAME

# See library search order
ldconfig -p | head -10</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Why does ELF use a three-level naming scheme (real name, soname, linker name)?</p>
                <div class="quiz" id="quiz-sl-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-1', this, false)">To make the file system faster</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-1', this, true)">To support backward-compatible upgrades: new versions can be installed alongside old ones without breaking existing programs</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-1', this, false)">It's just a convention with no practical benefit</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You upgrade libfoo.so.1.2.3 to libfoo.so.1.2.4. Do you need to recompile programs that use libfoo?</p>
                <div class="quiz" id="quiz-sl-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-2', this, false)">Yes, always recompile</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-2', this, true)">No ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â update the libfoo.so.1 symlink to point to 1.2.4, and existing programs will use the new version automatically</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-2', this, false)">Only if the ABI changed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Shared libraries are found and loaded by the dynamic linker (ld.so). The next concept covers how ld.so searches for libraries, processes relocations, and sets up the runtime environment.</p>
            </div>
            <div class="swipe-hint">ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Swipe to navigate ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢</div>
            <link rel="prev" href="">
            <link rel="next" href="">
        </div>
        <div class="a11y-toast" id="a11y-toast"></div>

        }
    }}
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
                div.innerHTML = '<span>Was this helpful?</span><button class="feedback-btn" onclick="rateFeedback(this, true)">ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â</button><button class="feedback-btn" onclick="rateFeedback(this, false)">ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ…Â½</button><span class="feedback-thanks">Thanks!</span>';
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

        (function() {
            var conceptId = window.location.pathname.split('/').pop().replace('.html', "") || 'bytes';
            var total = allConcepts.length;
            var mastered = 0;
            for(var i = 0; i < total; i++) {
            }
            var nav = document.createElement('div');
                '<div class="nav-status"><span class="indicator ' + status + '">' + status + '</span>' +
                '<span>' + mastered + '/' + total + ' mastered</span></div>' +
                '<div class="nav-links">' +
                (idx > 0 ? '<a href="' + allConcepts[idx-1] + '.html">&larr; Prev</a>' : '<a class="disabled">&larr; Prev</a>') +
                (idx < total - 1 ? '<a href="' + allConcepts[idx+1] + '.html">Next &rarr;</a>' : '<a class="disabled">Next &rarr;</a>') +
                '</div>';
            }
            } else {
            }
        })();

        // 4.2.16-17: Exercise mistake pattern detection + personalized feedback
        (function() {
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
            var nav = document.createElement('div');
                '<div class="nav-status"><span class="indicator ' + status + '">' + status + '</span>' +
                '<span>' + mastered + '/' + total + ' mastered</span></div>' +
                '<div class="nav-links">' +
                (idx > 0 ? '<a href="' + allConcepts[idx-1] + '.html">&larr; Prev</a>' : '<a class="disabled">&larr; Prev</a>') +
                (idx < total - 1 ? '<a href="' + allConcepts[idx+1] + '.html">Next &rarr;</a>' : '<a class="disabled">Next &rarr;</a>') +
                '</div>';
            }
            } else {
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