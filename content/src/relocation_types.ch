// ELF Course — Concept 17: Relocation Types
// R_X86_64_64, R_X86_64_PC32, R_X86_64_PLT32 — the x86-64 relocation types and their formulas.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_relocation_types() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relocation Types — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Relocation Types</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The relocation type determines how the linker computes the value to patch into the binary. Different types produce different addressing modes — absolute addresses, PC-relative offsets, GOT entries, PLT calls. Choosing the wrong type means broken code.</p>
                <p>Understanding relocation types explains why position-independent code (PIC) works differently from non-PIC, and why shared libraries use different call mechanisms than executables.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>There are two fundamental ways to reference a symbol:</p>
                <ul>
                    <li><strong>Absolute</strong> — "The value IS the symbol's address." Used for data references and non-PIE executables.</li>
                    <li><strong>PC-relative</strong> — "The value is the DISTANCE from here to the symbol." Used for code references and PIE/shared libraries.</li>
                </ul>
                <p>PC-relative is the default for modern code because it's position-independent — the code works at any address without patching.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The most common x86-64 relocation types:</p>
                <table>
                    <thead>
                        <tr><th>Type</th><th>Value</th><th>Formula</th><th>Usage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>R_X86_64_64</td><td>1</td><td>S + A</td><td>Absolute 64-bit address (data references)</td></tr>
                        <tr><td>R_X86_64_PC32</td><td>2</td><td>S + A - P</td><td>32-bit PC-relative (call/jmp in non-PIC)</td></tr>
                        <tr><td>R_X86_64_PLT32</td><td>4</td><td>L + A - P</td><td>32-bit PC-relative via PLT (function calls)</td></tr>
                        <tr><td>R_X86_64_GOTPCRELX</td><td>41</td><td>G + GOT + A - P</td><td>PC-relative to GOT entry (optimized PIC)</td></tr>
                        <tr><td>R_X86_64_32</td><td>10</td><td>S + A (truncated)</td><td>32-bit absolute (non-PIE, low memory)</td></tr>
                    </tbody>
                </table>
                <p>Where:</p>
                <ul>
                    <li><strong>S</strong> = Symbol value (final address)</li>
                    <li><strong>A</strong> = Addend (from r_addend)</li>
                    <li><strong>P</strong> = Place (offset being patched, i.e., r_offset + base address)</li>
                    <li><strong>L</strong> = PLT entry address (for PLT32)</li>
                    <li><strong>G</strong> = GOT entry offset (for GOTPCRELX)</li>
                </ul>
                <p>Key differences between R_X86_64_PC32 and R_X86_64_PLT32:</p>
                <ul>
                    <li><strong>PC32</strong>: Uses the symbol's final address directly. Used for non-PLT references (global variables, non-PIC calls).</li>
                    <li><strong>PLT32</strong>: Uses the PLT entry address. Allows lazy binding — the PLT stub jumps through the GOT, which is resolved at first call.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre># Non-PIE executable -- uses R_X86_64_PLT32
# test.c: helper() returns 42, caller() calls helper()
$ gcc -no-pie -c test.c
$ readelf -rW test.o
00000000000a  000300000004  R_X86_64_PLT32  0000000000000000  helper - 4

# PIE executable -- uses R_X86_64_GOTPCRELX (optimized PIC)
$ gcc -pie -c test.c
$ readelf -rW test.o
00000000000a  000300000029  R_X86_64_GOTPCRELX  0000000000000000  helper - 8</pre>
                </div>
                <p>The PLT32 relocation generates a direct <code>call</code> instruction. The GOTPCRELX relocation generates a <code>lea + call *reg</code> sequence that goes through the GOT for lazy binding.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># Compare relocation types: PIE vs non-PIE
# compare.c: calls an external function

# Non-PIE: PLT32
gcc -no-pie -c compare.c
readelf -rW compare.o | grep external

# PIE: GOTPCRELX  
gcc -pie -c compare.c
readelf -rW compare.o | grep external

# See the generated assembly difference
gcc -no-pie -S compare.c -o - | grep call
gcc -pie -S compare.c -o - | grep call</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does R_X86_64_PLT32 compute?</p>
                <div class="quiz" id="quiz-rt-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-1', this, false)">S + A (absolute address)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-1', this, true)">L + A - P (PLT entry address minus current position)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-1', this, false)">G + GOT + A - P (GOT entry address)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Why does PIE code use R_X86_64_GOTPCRELX instead of R_X86_64_PLT32?</p>
                <div class="quiz" id="quiz-rt-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-2', this, false)">GOTPCRELX is faster</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-2', this, true)">GOTPCRELX allows the linker to optimize to direct calls when possible (relaxation), and works with both data and code references</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-rt-2', this, false)">PLT32 doesn't support 64-bit addresses</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Static relocations are resolved at link time. But shared libraries also need dynamic relocations — patches applied by ld.so at load time. That's the next concept.</p>
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
