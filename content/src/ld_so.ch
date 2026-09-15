// ELF Course — Concept 21: The Dynamic Linker
// ld.so — library search order, environment variables, lazy binding, and the resolution algorithm.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_ld_so() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Dynamic Linker — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>The Dynamic Linker (ld.so)</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every dynamically-linked program on Linux starts with ld.so, not main(). The dynamic linker loads all shared libraries, processes relocations, and only then hands control to your program. Understanding ld.so explains "library not found" errors, how LD_PRELOAD works, and why some programs crash at startup.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>ld.so is the first thing that runs when you start a dynamically-linked program:</p>
                <ol>
                    <li>The kernel maps the program into memory and jumps to ld.so's entry point (stored in the PT_INTERP segment)</li>
                    <li>ld.so maps all DT_NEEDED shared libraries into memory</li>
                    <li>ld.so processes .rela.dyn (data relocations) and .rela.plt (lazy binding setup)</li>
                    <li>ld.so calls init functions (DT_INIT, .init_array)</li>
                    <li>ld.so jumps to the program's entry point (_start)</li>
                </ol>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The library search order (in order of priority):</p>
                <p>DT_RPATH: embedded in the binary (deprecated, but still works)</p>
                <p>LD_LIBRARY_PATH: environment variable (colon-separated list)</p>
                <p>DT_RUNPATH: embedded in the binary (preferred over DT_RPATH)</p>
                <p>/etc/ld.so.cache: pre-built cache from ldconfig (fast lookup)</p>
                <p>/lib and /usr/lib: default paths</p>
                <p>Key environment variables:</p>
                <table>
                    <thead>
                        <tr><th>Variable</th><th>Purpose</th><th>Example</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>LD_LIBRARY_PATH</td><td>Additional library search paths</td><td>LD_LIBRARY_PATH=/opt/foo/lib ./myprog</td></tr>
                        <tr><td>LD_PRELOAD</td><td>Force-load libraries before all others</td><td>LD_PRELOAD=libmalloc.so ./myprog</td></tr>
                        <tr><td>LD_BIND_NOW</td><td>Disable lazy binding (resolve all symbols at load)</td><td>LD_BIND_NOW=1 ./myprog</td></tr>
                        <tr><td>LD_DEBUG</td><td>Print linker debug info</td><td>LD_DEBUG=libs ./myprog</td></tr>
                        <tr><td>LD_TRACE_LOADED_OBJECTS</td><td>List dependencies and exit (like ldd)</td><td>LD_TRACE_LOADED_OBJECTS=1 ./myprog</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre># Watch ld.so search for libraries
$ LD_DEBUG=libs ./myprog | head -20
     12345:     find library=libc.so.6 [0]; searching
     12345:      search cache=/etc/ld.so.cache
     12345:       trying file=/lib/x86_64-linux-gnu/libc.so.6
     12345:     init: /lib/x86_64-linux-gnu/libc.so.6
     12345:     find library=libfoo.so.1 [0]; searching
     12345:      search cache=/etc/ld.so.cache
     12345:       trying file=/usr/lib/x86_64-linux-gnu/libfoo.so.1
     12345:     init: /usr/lib/x86_64-linux-gnu/libfoo.so.1

# See what ldd actually does
$ ldd /bin/ls
    linux-vdso.so.1 (0x00007ffd...)
    libselinux.so.1 --- /lib/x86_64-linux-gnu/libselinux.so.1
    librt.so.1 --- /lib/x86_64-linux-gnu/librt.so.1
    libc.so.6 --- /lib/x86_64-linux-gnu/libc.so.6</pre>
                </div>
                <p>The LD_DEBUG output shows the exact search sequence — incredibly useful for debugging "library not found" errors.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># Debug library loading
LD_DEBUG=libs ls | head -30

# Trace symbol resolution
LD_DEBUG=bindings ls | head -20

# Force a library to be loaded first (interposition)
LD_PRELOAD=/lib/x86_64-linux-gnu/libc.so.6 ls

# Check what a binary needs without running it
ldd /bin/ls

# Find which package provides a library
dpkg -S /lib/x86_64-linux-gnu/libc.so.6</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the purpose of LD_PRELOAD?</p>
                <div class="quiz" id="quiz-ld-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-1', this, false)">To specify library search paths</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-1', this, true)">To force-load a library before all others, allowing it to override (interpose) symbols in subsequent libraries</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-1', this, false)">To disable lazy binding</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You get "error while loading shared libraries: libfoo.so.3: cannot open shared object file". What are the most likely causes?</p>
                <div class="quiz" id="quiz-ld-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-2', this, false)">The program is corrupted</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-2', this, true)">The library is not installed, or it's installed in a path not in the search order (check LD_LIBRARY_PATH and /etc/ld.so.cache)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ld-2', this, false)">Your CPU doesn't support the instruction set</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand the full dynamic linking pipeline. The final module covers how the OS loader actually runs an ELF program — the kernel-side counterpart to ld.so.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Order the Steps</h2>
                <p>Put the dynamic linker loading steps in the correct order (drag to reorder):</p>
                <div class="order-quiz" id="order-ld-1">
                    <div class="order-item" draggable="true" data-order="3">
                        <span class="order-num">3</span>
                        <span class="order-text">Process DT_NEEDED entries and load each required shared library</span>
                    </div>
                    <div class="order-item" draggable="true" data-order="1">
                        <span class="order-num">1</span>
                        <span class="order-text">Kernel maps ELF into memory and passes control to ld.so</span>
                    </div>
                    <div class="order-item" draggable="true" data-order="4">
                        <span class="order-num">4</span>
                        <span class="order-text">Perform relocations (patch GOT/PLT with resolved addresses)</span>
                    </div>
                    <div class="order-item" draggable="true" data-order="2">
                        <span class="order-num">2</span>
                        <span class="order-text">Parse dynamic section of the executable and libraries</span>
                    </div>
                    <div class="order-item" draggable="true" data-order="5">
                        <span class="order-num">5</span>
                        <span class="order-text">Jump to the entry point (e_entry) to start program execution</span>
                    </div>
                    <button class="order-check-btn" onclick="checkOrder('order-ld-1')">Check Order</button>
                    <div class="order-feedback"></div>
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
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .order-quiz { margin-top: 1rem; }
        .order-item { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; margin-bottom: 0.5rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: grab; user-select: none; }
        .order-item:active { cursor: grabbing; background: #f9fafb; }
        .order-item.dragging { opacity: 0.5; border-style: dashed; }
        .order-num { font-weight: 600; color: #6b7280; min-width: 1.5rem; }
        .order-text { flex: 1; }
        .order-item.correct { border-color: #059669; background: #ecfdf5; }
        .order-item.wrong { border-color: #dc2626; background: #fef2f2; }
        .order-check-btn { margin-top: 0.75rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; font-size: 0.9rem; }
        .order-check-btn:hover { background: #f9fafb; border-color: #3b82f6; }
        .order-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
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

        function checkOrder(quizId) {
            var quiz = document.getElementById(quizId);
            var items = quiz.querySelectorAll('.order-item');
            var feedback = quiz.querySelector('.order-feedback');
            var allCorrect = true;
            for(var i = 0; i < items.length; i++) {
                var expected = i + 1;
                var actual = parseInt(items[i].querySelector('.order-num').textContent);
                if(actual === expected) {
                    items[i].classList.add('correct');
                    items[i].classList.remove('wrong');
                } else {
                    items[i].classList.add('wrong');
                    items[i].classList.remove('correct');
                    allCorrect = false;
                }
                items[i].draggable = false;
            }
            if(allCorrect) {
                feedback.textContent = 'Correct order!';
                feedback.style.color = '#059669';
            } else {
                feedback.textContent = 'Some items are out of order. The correct sequence is shown by the green items.';
                feedback.style.color = '#dc2626';
            }
        }

        var dragSrc = null;
        document.querySelectorAll('.order-item').forEach(function(item) {
            item.addEventListener('dragstart', function(e) {
                dragSrc = this;
                this.classList.add('dragging');
                e.dataTransfer.effectAllowed = 'move';
            });
            item.addEventListener('dragend', function() {
                this.classList.remove('dragging');
            });
            item.addEventListener('dragover', function(e) {
                e.preventDefault();
                e.dataTransfer.dropEffect = 'move';
            });
            item.addEventListener('drop', function(e) {
                e.preventDefault();
                if(dragSrc !== this) {
                    var parent = this.parentNode;
                    var srcNum = dragSrc.querySelector('.order-num');
                    var dstNum = this.querySelector('.order-num');
                    var tmpText = srcNum.textContent;
                    srcNum.textContent = dstNum.textContent;
                    dstNum.textContent = tmpText;
                    var srcIdx = Array.prototype.indexOf.call(parent.children, dragSrc);
                    var dstIdx = Array.prototype.indexOf.call(parent.children, this);
                    if(srcIdx < dstIdx) {
                        parent.insertBefore(dragSrc, this.nextSibling);
                    } else {
                        parent.insertBefore(dragSrc, this);
                    }
                }
            });
        });
    }

    return page.toString()
}
}
