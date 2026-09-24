// ELF Course — Concept 24: The Startup Sequence
// From _start to main() — the final piece of the ELF execution puzzle.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_execution() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Startup Sequence — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>The Startup Sequence</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You've written main() a thousand times. But what happens before it? The startup sequence is the bridge between ld.so finishing its work and your code running. Understanding it explains why global constructors run before main, why atexit() works, and how the C runtime is initialized. It's the final piece of the ELF puzzle.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The complete startup sequence for a dynamically-linked program:</p>
                <ol>
                    <li><strong>Kernel loads ld.so</strong> — Maps the program and the dynamic linker</li>
                    <li><strong>ld.so initializes</strong> — Processes .dynamic, maps all DT_NEEDED libraries, applies relocations</li>
                    <li><strong>ld.so calls _start</strong> — The program's true entry point (set by the linker)</li>
                    <li><strong>_start calls __libc_start_main</strong> — The C runtime setup function</li>
                    <li><strong>__libc_start_main</strong>:
                        <ul>
                            <li>Processes environment variables (PATH, LD_*, etc.)</li>
                            <li>Initializes stdio (stdin/stdout/stderr)</li>
                            <li>Calls .init_array constructors</li>
                            <li>Sets up atexit() handler chain</li>
                            <li>Calls main(argc, argv, envp)</li>
                        </ul>
                    </li>
                    <li><strong>main() returns</strong> — Control returns to __libc_start_main</li>
                    <li><strong>Cleanup</strong> — Calls atexit() handlers, .fini_array destructors, calls exit()</li>
                </ol>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The entry point is not main() — it's _start, a small assembly stub:</p>
                <div class="hex-dump"><pre># Simplified _start (x86-64):
# _start:
#   xor %rbp, %rbp          -- Clear frame pointer (marks end of stack)
#   pop %rsi                -- argc (from stack)
#   mov %rsp, %rdx          -- argv (stack pointer)
#   and $-16, %rsp          -- Align stack to 16 bytes (ABI requirement)
#   push %rax               -- Push garbage for alignment
#   push %rsp               -- Push stack pointer (for __libc_start_main)
#   lea __libc_start_main@GOTPCREL(%rip), %rax
#   mov (%rax), %rax        -- Load address of __libc_start_main
#   lea main(%rip), %rdi    -- First arg: pointer to main()
#   call *%rax              -- Call __libc_start_main</pre></div>
                <p>Key observations:</p>
                <ul>
                    <li><strong>_start is assembly, not C</strong> — no stack frame, no function prologue</li>
                    <li><strong>It never returns</strong> — __libc_start_main calls exit(), which terminates the process</li>
                    <li><strong>main() is just a callback</strong> — it's passed to __libc_start_main like any other function</li>
                </ul>
                <p>Global constructors (.init_array) run before main:</p>
                <div class="hex-dump"><pre># Global constructors run before main:
# __attribute__((constructor)) void my_init() -- runs before main
# __attribute__((destructor))  void my_fini() -- runs after main returns</pre></div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ cat startup.c
# startup.c:
#   __attribute__((constructor)) before_main() -- prints "[constructor]"
#   __attribute__((destructor))  after_main()  -- prints "[destructor]"
#   int main() -- prints "[main]"
#   void cleanup() -- prints "[atexit]"
#   __attribute__((constructor)) register_cleanup() -- calls atexit(cleanup)

$ gcc -o startup startup.c
$ ./startup
[constructor] runs before main
[main] argc=1
[atexit] registered cleanup
[destructor] runs after main returns

# Trace the actual calls
LD_DEBUG=all ./startup | grep -E "init|constructor|main"</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See the actual entry point
readelf -e /bin/ls | grep "Entry point"

# Trace the full startup
LD_DEBUG=all ls | tail -30

# See init/fini arrays
readelf -d /bin/ls | grep -E "INIT|FINI"

# Check your program's constructors
gcc -o test test.c; LD_DEBUG=all ./test | grep -i init</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the relationship between _start and main()?</p>
                <div class="quiz" id="quiz-ex-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-1', this, false)">They're the same function</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-1', this, true)">_start is the ELF entry point (assembly stub) that calls __libc_start_main, which then calls main() — main() is a callback, not the entry point</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-1', this, false)">main() calls _start</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You write a program with a constructor that calls printf("init"), but the output appears before "init" is printed. What's happening?</p>
                <div class="quiz" id="quiz-ex-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-2', this, false)">The constructor isn't running</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-2', this, true)">stdout isn't flushed yet — constructors run before main, and stdout is line-buffered; if you don't print a newline, the output stays in the buffer until main runs or the program exits</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ex-2', this, false)">The kernel runs constructors after main</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Congratulations — you've completed the ELF course! You now understand the complete journey from source code to running program: the ELF format, sections, segments, symbols, relocations, dynamic linking, and the startup sequence. This knowledge is the foundation for understanding compilers, linkers, loaders, and system-level debugging.</p>
                <p><strong>Next steps:</strong> Apply this knowledge by debugging real programs with GDB, reading compiler-generated assembly, and exploring how the linker resolves symbols across translation units.</p>
            <div class="unit unit-exercises" id="api-exercises" style="display:none">
                <h2>Practice Exercises</h2>
                <div id="exercise-list"></div>
            </div>
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
        ul, ol { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
    }

    #js {
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
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. Try again next time.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    render_exercise_css(&mut page)
    render_exercise_js(&mut page)
    render_exercise_build_js(&mut page)
    return page.toString()
}
}
