// ELF Course — Concept 20: Shared Libraries
// How .so files work, soname versioning, library paths, and the linking model.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_shared_libraries() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Shared Libraries — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
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
                    <li><strong>Real name</strong> — The actual file: libfoo.so.1.2.3</li>
                    <li><strong>Soname</strong> — The compatibility name: libfoo.so.1 (symlink to real name)</li>
                    <li><strong>Linker name</strong> — The development name: libfoo.so (symlink to soname, used at compile time)</li>
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
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-2', this, true)">No — update the libfoo.so.1 symlink to point to 1.2.4, and existing programs will use the new version automatically</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sl-2', this, false)">Only if the ABI changed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Shared libraries are found and loaded by the dynamic linker (ld.so). The next concept covers how ld.so searches for libraries, processes relocations, and sets up the runtime environment.</p>
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
