// ELF Course — Concept 1: Bytes and Binary
// Uses #html, #css, #js macros for all markup.
// Emits a complete HTML page that works in both static and backend modes.

public namespace underlayer_content {

using std::string

using std::string_view

public func render_bytes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Bytes and Binary — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every file on your computer — including executables, images, and documents — is made of bytes. Understanding bytes is the foundation for understanding any binary format, including ELF.</p>
                <p>Without understanding bytes, you can't read hex dumps, debug parsers, or reason about file layouts.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a byte as a small container that holds a number between 0 and 255. That's it. A byte is just a number.</p>
                <p>When you see <code>0x41</code> in a hex dump, that's the number 65 in decimal. It happens to be the ASCII code for the letter 'A'.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A byte is 8 bits. Each bit is either 0 or 1. So a byte can represent 2^8 = 256 different values (0-255).</p>
                <p>We write bytes in hexadecimal (base-16) because it's compact: one byte = exactly two hex digits.</p>
                <table>
                    <thead>
                        <tr><th>Decimal</th><th>Hex</th><th>Binary</th><th>ASCII</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>0x00</td><td>00000000</td><td>NUL</td></tr>
                        <tr><td>65</td><td>0x41</td><td>01000001</td><td>A</td></tr>
                        <tr><td>127</td><td>0x7f</td><td>01111111</td><td>DEL</td></tr>
                        <tr><td>255</td><td>0xff</td><td>11111111</td><td>—</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The ELF magic number starts with these 4 bytes:</p>
                <div class="hex-dump">
                    <pre>7f 45 4c 46</pre>
                </div>
                <p>In decimal: 127, 69, 76, 70. In ASCII: <code>. E L F</code>. That's right — the first four bytes literally spell "ELF".</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Click on each byte to see its decimal, hex, and ASCII values:</p>
                <div class="hex-interactive" id="hex-1">
                    <span class="hex-byte" data-val="127" onclick="selectByte(this)">7f</span>
                    <span class="hex-byte" data-val="69" onclick="selectByte(this)">45</span>
                    <span class="hex-byte" data-val="76" onclick="selectByte(this)">4c</span>
                    <span class="hex-byte" data-val="70" onclick="selectByte(this)">46</span>
                    <div class="hex-info" id="hex-info">Click a byte above</div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what decimal value does the hex byte 0x41 represent?</p>
                <div class="quiz" id="quiz-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">32</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, true)">65</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">127</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Here's a hex dump of 4 bytes. What ASCII text do they spell?</p>
                <div class="hex-dump">
                    <pre>48 65 6c 6c</pre>
                </div>
                <div class="quiz" id="quiz-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, false)">ELF</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, true)">Hell</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, false)">Help</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand bytes — the building blocks of every binary format. Next, we'll see how bytes are organized into larger structures.</p>
                <p>Every ELF header, every section, every symbol table entry — they're all just bytes. The format specification tells us how to interpret them.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Fill in the Blank</h2>
                <p>Complete the code: A byte has <input type="text" class="fill-blank" id="fb-1" data-answer="8" placeholder="?" /> bits, and can represent values from 0 to <input type="text" class="fill-blank" id="fb-2" data-answer="255" placeholder="?" />.</p>
                <button class="fill-check-btn" onclick="checkFillBlanks()">Check Answers</button>
                <div class="fill-feedback" id="fill-feedback"></div>
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
        .hex-dump pre { white-space: pre; margin: 0; }
        .hex-interactive { font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        .hex-byte { display: inline-block; width: 2ch; margin-right: 1rem; cursor: pointer; border-radius: 2px; padding: 0.25rem; }
        .hex-byte:hover { background: rgba(59, 130, 246, 0.3); }
        .hex-byte.selected { background: rgba(59, 130, 246, 0.5); }
        .hex-info { margin-top: 0.5rem; font-size: 0.85rem; color: #9ca3af; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .fill-blank { padding: 0.4rem 0.6rem; border: 1px solid #d1d5db; border-radius: 4px; width: 5rem; font-size: 0.95rem; font-family: monospace; margin: 0 0.25rem; }
        .fill-blank:focus { outline: 2px solid #3b82f6; outline-offset: 1px; }
        .fill-blank.correct { border-color: #059669; background: #ecfdf5; }
        .fill-blank.wrong { border-color: #dc2626; background: #fef2f2; }
        .fill-check-btn { margin-top: 0.75rem; padding: 0.5rem 1rem; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; font-size: 0.9rem; }
        .fill-check-btn:hover { background: #f9fafb; border-color: #3b82f6; }
        .fill-feedback { margin-top: 0.5rem; font-size: 0.9rem; display: none; }
        .fill-feedback.show { display: block; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        code { background: #f3f4f6; padding: 0.15rem 0.4rem; border-radius: 4px; font-size: 0.9em; font-family: monospace; }
        pre { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: monospace; overflow-x: auto; white-space: pre; }
        @media (max-width: 640px) {
            .lesson { padding: 1rem; }
            .unit { padding: 1rem; }
            table { font-size: 0.85rem; }
            th, td { padding: 0.35rem; }
        }
    }

    #js {
        function selectByte(el) {
            var all = el.parentElement.querySelectorAll('.hex-byte');
            for(var i = 0; i < all.length; i++) { all[i].classList.remove('selected'); }
            el.classList.add('selected');
            var val = parseInt(el.getAttribute('data-val'));
            var hex = el.textContent;
            var ascii = (val >= 32 && val < 127) ? String.fromCharCode(val) : '(non-printable)';
            var info = document.getElementById('hex-info');
            info.textContent = 'Decimal: ' + val + ' | Hex: 0x' + hex + ' | ASCII: ' + ascii;
        }

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

        function checkFillBlanks() {
            var blanks = document.querySelectorAll('.fill-blank');
            var allCorrect = true;
            var feedback = document.getElementById('fill-feedback');
            for(var i = 0; i < blanks.length; i++) {
                var el = blanks[i];
                var answer = el.getAttribute('data-answer');
                var val = el.value.trim();
                if(val === answer) {
                    el.classList.add('correct');
                    el.classList.remove('wrong');
                } else {
                    el.classList.add('wrong');
                    el.classList.remove('correct');
                    allCorrect = false;
                }
            }
            feedback.classList.add('show');
            if(allCorrect) {
                feedback.textContent = 'All correct!';
                feedback.style.color = '#059669';
            } else {
                feedback.textContent = 'Check the highlighted fields and try again.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
}
