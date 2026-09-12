// ELF Course — Concept 6: Entry Point
// How e_entry tells the loader where execution begins.
using std::string
using std::string_view

public func render_entry_point() : string {
    var page = HtmlPage()
    page.default_prepare()
    var title = std::string_view("Entry Point — Underlayer")
    page.append_title(&title)

    #html {
        <div class="lesson">
            <h1>Entry Point</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When you run a program, how does the CPU know where to start executing? The answer is the entry point — a virtual address stored in the ELF header. This single field connects the file on disk to the running process.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The entry point is like a "Start Here" sign. When the kernel loads an ELF file, it maps the segments into memory and then jumps to the address stored in <code>e_entry</code>. For most programs, this points to the C runtime startup code, which eventually calls your <code>main()</code> function.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>In a 64-bit ELF, <code>e_entry</code> is an 8-byte field at offset 24. It contains a virtual address (not a file offset). For position-independent executables (PIE), this is usually a small offset like <code>0x1060</code> or <code>0x6810</code>. For non-PIE executables, it might be something like <code>0x401060</code>.</p>
                <p>The entry point is set by the linker based on the <code>_start</code> symbol. If no <code>_start</code> is defined, the linker uses address 0, which would crash.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -h /bin/ls | grep "Entry point"
  Entry point address:               0x6810

$ gdb -batch -ex "info files" /bin/ls 2>&1 | grep entry
  0x0000000000006810 - 0x0000000000006860 is .init</pre>
                </div>
                <p>The entry point 0x6810 falls in the <code>.init</code> section — the initialization code that runs before <code>main()</code>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <pre><code>$ readelf -h /bin/ls | grep "Entry point"
$ objdump -d /bin/ls | head -20  # See the disassembly at the entry point</code></pre>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does the entry point address point to?</p>
                <div class="quiz" id="quiz-ep-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, false)">The main() function</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, true)">The _start / initialization code</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ep-1', this, false)">The first instruction of .text</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The ELF header tells us where execution begins. But how does the loader know which parts of the file to map into memory? That's what program headers (next module) describe.</p>
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
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.5rem; margin-bottom: 1rem; }
        h2 { font-size: 1.1rem; margin-bottom: 0.75rem; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
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

    return page.to_string()
}
