// ELF Course — Concept 2: Binary Representation
// How bytes encode numbers, characters, and data structures.
// Uses #html, #css, #js macros for all markup.

using std::string
using std::string_view

public func render_binary_representation() : string {
    var page = HtmlPage()
    page.default_prepare()
    var title = std::string_view("Binary Representation — Underlayer")
    page.append_title(&title)

    #html {
        <div class="lesson">
            <h1>Binary Representation</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>ELF files store numbers in specific byte orders (little-endian or big-endian). Understanding how bytes encode numbers is essential for reading ELF headers, addresses, and sizes correctly.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a number as a stack of digits. In decimal (base-10), each digit position represents a power of 10. In binary (base-2), each bit represents a power of 2.</p>
                <p>A single byte can store 0-255. Two bytes can store 0-65535. Four bytes can store 0-4 billion.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Computers store numbers in binary. But we read hex dumps in hexadecimal because it maps directly to binary: each hex digit = exactly 4 bits.</p>
                <table>
                    <thead>
                        <tr><th>Binary</th><th>Hex</th><th>Decimal</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0000</td><td>0</td><td>0</td></tr>
                        <tr><td>0001</td><td>1</td><td>1</td></tr>
                        <tr><td>1010</td><td>a</td><td>10</td></tr>
                        <tr><td>1111</td><td>f</td><td>15</td></tr>
                    </tbody>
                </table>
                <p>A byte (8 bits) = two hex digits. So <code>0xff</code> = <code>11111111</code> = 255.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The ELF header stores the entry point address as a 4-byte number. Here's a hex dump of that field:</p>
                <div class="hex-dump">
                    <pre>40 00 40 00</pre>
                </div>
                <p>In little-endian (x86), this is the number <code>0x00400040</code> = 4,194,368 in decimal. That's the memory address where execution begins.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Convert this binary number to decimal:</p>
                <div class="hex-dump">
                    <pre>00001010</pre>
                </div>
                <div class="quiz" id="quiz-bin-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-1', this, false)">2</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-1', this, true)">10</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-1', this, false)">1010</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the decimal value of the hex byte <code>0x1a</code>?</p>
                <div class="quiz" id="quiz-bin-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-2', this, false)">10</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-2', this, false)">26</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-bin-2', this, true)">26</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand how bytes encode numbers. Next, we'll see how bytes are organized into the ELF file structure.</p>
                <p>Every field in the ELF header — magic number, class, data encoding, type, machine — is just bytes interpreted as numbers.</p>
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
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
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
