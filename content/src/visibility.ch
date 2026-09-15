// ELF Course — Concept 15: Symbol Visibility
// STV_DEFAULT, STV_INTERNAL, STV_HIDDEN, STV_PROTECTED — controlling dynamic linking exports.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_visibility() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Visibility — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Symbol Visibility</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you build a shared library (.so), you decide which functions are part of your public API and which are internal implementation details. Symbol visibility is the ELF mechanism for this — it controls what the dynamic linker can see and reference from outside the library.</p>
                <p>Correct visibility prevents symbol collisions between libraries, reduces dynamic linker overhead, and enables better optimization.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of visibility as four levels of "doors" on your library:</p>
                <ul>
                    <li><strong>Default</strong> — The door is open. Anyone can use this symbol.</li>
                    <li><strong>Hidden</strong> — The door is locked. Only code inside this library can use it.</li>
                    <li><strong>Internal</strong> — Like hidden, plus the symbol is specific to this compilation unit.</li>
                    <li><strong>Protected</strong> — The door is open, but the symbol always resolves to this library (never interposed).</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Visibility is stored in the low 2 bits of st_other in the Elf64_Sym structure:</p>
                <table>
                    <thead>
                        <tr><th>Visibility</th><th>Constant</th><th>Value</th><th>Behavior</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Default</td><td>STV_DEFAULT</td><td>0</td><td>Symbol is exported. Dynamic linker can interpose it (LD_PRELOAD).</td></tr>
                        <tr><td>Internal</td><td>STV_INTERNAL</td><td>1</td><td>Symbol is local to the module. Not visible outside. May have special meaning for processor.</td></tr>
                        <tr><td>Hidden</td><td>STV_HIDDEN</td><td>2</td><td>Symbol is not exported. Dynamic linker cannot resolve it from other modules.</td></tr>
                        <tr><td>Protected</td><td>STV_PROTECTED</td><td>3</td><td>Symbol is exported but references within the module resolve to the local definition (no interposition).</td></tr>
                    </tbody>
                </table>
                <p>How to set visibility in C/C++:</p>
                <table>
                    <thead>
                        <tr><th>Visibility</th><th>C/C++ syntax</th><th>Effect</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Default</td><td>void public_api() -- no attribute needed</td><td>Exported, interposable</td></tr>
                        <tr><td>Hidden</td><td>__attribute__((visibility("hidden"))) void internal_fn()</td><td>Not exported</td></tr>
                        <tr><td>Protected</td><td>__attribute__((visibility("protected"))) void stable_api()</td><td>Exported, not interposable</td></tr>
                    </tbody>
                </table>
                <p>Compile with <strong>-fvisibility=hidden</strong> to make all symbols hidden by default.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>A shared library with controlled visibility:</p>
                <div class="hex-dump">
                    <pre># libdemo.c defines 4 functions:
#   exported()     -- default visibility (EXPORTED)
#   hidden_fn()    -- hidden visibility (NOT exported)
#   protected_fn() -- protected visibility (exported, no interposition)
#   default_fn()   -- default visibility, but -fvisibility=hidden makes it HIDDEN

$ gcc -fvisibility=hidden -shared -o libdemo.so libdemo.c

$ readelf -sW libdemo.so | grep -E 'DEFAULT|HIDDEN|PROTECTED'
  1: 0000000000001129     5 FUNC    GLOBAL DEFAULT   13 exported
  2: 0000000000001132     5 FUNC    GLOBAL HIDDEN    13 hidden_fn
  3: 000000000000113b     5 FUNC    GLOBAL PROTECTED 13 protected_fn
  4: 0000000000001144     5 FUNC    GLOBAL HIDDEN    13 default_fn</pre>
                </div>
                <p>Note: default_fn is hidden because we compiled with -fvisibility=hidden. Only exported is truly visible to other libraries.</p>
                <p>Checking what a library actually exports:</p>
                <div class="hex-dump">
                    <pre>$ nm -D --defined-only libdemo.so
0000000000001129 T exported
000000000000113b T protected_fn

# hidden_fn and default_fn don't appear — they're not in .dynsym</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># Create a library with mixed visibility
# vis.c has pub_fn (default) and priv_fn (hidden)

# Build with hidden default
gcc -fvisibility=hidden -shared -o libvis.so vis.c

# See what's exported
nm -D --defined-only libvis.so
# Only pub_fn appears

# See everything
nm --defined-only libvis.so
# Both functions appear</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does HIDDEN visibility mean for a symbol?</p>
                <div class="quiz" id="quiz-v-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-1', this, false)">The symbol is available everywhere but marked as internal</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-1', this, true)">The symbol is not exported — other shared libraries cannot resolve it</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-1', this, false)">The symbol is stripped from the binary</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Why would you use PROTECTED visibility instead of DEFAULT?</p>
                <div class="quiz" id="quiz-v-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-2', this, false)">Protected symbols are smaller in the binary</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-2', this, true)">To prevent interposition — ensure calls within the library always resolve to the local definition, even if LD_PRELOAD defines the same symbol</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-v-2', this, false)">Protected symbols load faster</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Now you understand how ELF symbols are named (symbol table), scoped (binding), and exported (visibility). The next module covers relocations — how the linker patches addresses when combining object files.</p>
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
        .toc { position: sticky; top: 2rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb; margin-bottom: 1.5rem; }
        .toc-title { font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; margin-bottom: 0.5rem; }
        .toc-list { list-style: none; padding: 0; margin: 0; }
        .toc-list li { margin-bottom: 0.25rem; }
        .toc-list a { color: #374151; text-decoration: none; font-size: 0.85rem; display: block; padding: 0.2rem 0.5rem; border-radius: 4px; }
        .toc-list a:hover { background: #e5e7eb; }
        .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
        .back-to-top.visible { opacity: 1; pointer-events: auto; }
        .back-to-top:hover { background: #111827; }
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
    }

    return page.toString()
}
}
