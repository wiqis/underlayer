// ELF Course — Concept 14: Symbol Binding
// STB_LOCAL, STB_GLOBAL, STB_WEAK — how binding controls symbol resolution across objects.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_binding() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Binding — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Symbol Binding</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you compile multiple C files into one program, each file might define its own helper functions. Binding determines which symbols the linker can see across file boundaries — and which are kept private.</p>
                <p>Misunderstanding binding causes common linker errors like "multiple definition of symbol" or unexpected symbol collisions.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of binding as the visibility scope of a symbol:</p>
                <ul>
                    <li><strong>Local</strong> — Private to this object file. Other files can't see it, even if they define the same name.</li>
                    <li><strong>Global</strong> — Visible everywhere. The linker will resolve references to this symbol across all object files and libraries.</li>
                    <li><strong>Weak</strong> — Like global, but can be overridden. If a strong (global) definition exists, the weak one is ignored.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The binding is stored in the high 4 bits of &lt;code&gt;st_info&lt;/code&gt; in the &lt;code&gt;Elf64_Sym&lt;/code&gt; structure:</p>
                <table>
                    <thead>
                        <tr><th>Binding</th><th>Constant</th><th>Value</th><th>Behavior</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Local</td><td>STB_LOCAL</td><td>0</td><td>Not visible outside the object file. Multiple files can have same name.</td></tr>
                        <tr><td>Global</td><td>STB_GLOBAL</td><td>1</td><td>Visible to all object files in the link. Must be unique across entire program.</td></tr>
                        <tr><td>Weak</td><td>STB_WEAK</td><td>2</td><td>Like global, but overridden by any strong global definition.</td></tr>
                    </tbody>
                </table>
                <p>C functions are <strong>global</strong> by default. Static functions (&lt;code&gt;static void foo()&lt;/code&gt;) are <strong>local</strong>. GCC attributes &lt;code&gt;__attribute__((weak))&lt;/code&gt; make symbols <strong>weak</strong>.</p>
                <p>Resolution order during linking:</p>
                <ol>
                    <li>Strong (GLOBAL) definitions override weak ones</li>
                    <li>Multiple strong definitions = error ("multiple definition")</li>
                    <li>Multiple weak definitions = pick any (usually first one found)</li>
                    <li>LOCAL symbols never participate in cross-file resolution</li>
                </ol>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Two source files defining overlapping symbols:</p>
                <p><strong>a.c:</strong> helper (STB_GLOBAL), priv (STB_LOCAL via static), weak_fn (STB_WEAK)</p>
                <p><strong>b.c:</strong> helper (STB_GLOBAL), weak_fn (STB_WEAK, overrides a.c), only_weak (STB_WEAK)</p>
                <p>What &lt;code&gt;nm&lt;/code&gt; shows:</p>
                <div class="hex-dump"><pre>$ nm a.o
0000000000000000 W weak_fn       // W = weak
0000000000000000 T helper        // T = global (text)
0000000000000000 t priv          // t = local (text, lowercase)

$ nm b.o
0000000000000000 W weak_fn
0000000000000000 W only_weak
0000000000000000 T helper</pre></div>
                <p>Notice: &lt;code&gt;priv&lt;/code&gt; is lowercase 't' (local), while &lt;code&gt;helper&lt;/code&gt; is uppercase 'T' (global).</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># Create a local symbol with 'static'
echo 'static int x = 5;' | tee a.c
echo 'int x = 10;' | tee b.c
gcc -c a.c b.c
nm a.o | grep ' x'    # shows lowercase 'd' (local data)
nm b.o | grep ' x'    # shows uppercase 'D' (global data)

# Try linking -- succeeds because a.o's x is local
gcc a.o b.o -o test
nm test | grep ' x'    # shows uppercase 'D' (b.o's x wins)</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What happens if two object files both define a strong (GLOBAL) symbol with the same name?</p>
                <div class="quiz" id="quiz-b-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-1', this, false)">The linker picks the one with the larger value</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-1', this, true)">The linker reports a "multiple definition" error</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-1', this, false)">The first one wins silently</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Why would you use a WEAK symbol instead of a GLOBAL one?</p>
                <div class="quiz" id="quiz-b-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-2', this, false)">Weak symbols are faster at runtime</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-2', this, true)">To provide a default implementation that can be overridden by a strong definition</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-b-2', this, false)">Weak symbols use less memory</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Binding controls <em>which</em> definition the linker picks. But visibility controls whether the dynamic linker can see a symbol at all — that's the next concept.</p>
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
    }

    return page.toString()
}
}
