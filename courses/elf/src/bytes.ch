import page
import html_cbi
import css_cbi
import js_cbi

public func render() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Bytes and Binary — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Bytes and Binary</h1>
            <div class="lesson-meta">15 min · Core concept · Module 1 of 2</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every file on your computer is made of bytes. The ELF format you are about to learn is just a specific way of organizing bytes. If you understand bytes, you understand the foundation of every binary format.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a byte as a small box that can hold a number between 0 and 255. That is it. Every file, every program, every image — all just boxes with numbers in them, arranged in a specific order.</p>
                <p>We write those numbers in <strong>hexadecimal</strong> (base 16) because one byte equals exactly two hex digits. <code>0x41</code> is the number 65. <code>0xFF</code> is the number 255.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>A byte is 8 bits. Each bit is either 0 or 1. The value of a byte is:</p>
                <p class="code">b7×128 + b6×64 + b5×32 + b4×16 + b3×8 + b2×4 + b1×2 + b0×1</p>
                <p>That means a byte can represent exactly 256 different values (2^8 = 256), from 0 to 255.</p>
                <div class="table-wrapper">
                    <table>
                        <thead>
                            <tr><th>Decimal</th><th>Hex</th><th>Binary</th><th>ASCII</th></tr>
                        </thead>
                        <tbody>
                            <tr><td>0</td><td>0x00</td><td>00000000</td><td>NUL (null)</td></tr>
                            <tr><td>65</td><td>0x41</td><td>01000001</td><td>A</td></tr>
                            <tr><td>97</td><td>0x61</td><td>01100001</td><td>a</td></tr>
                            <tr><td>127</td><td>0x7F</td><td>01111111</td><td>DEL</td></tr>
                            <tr><td>255</td><td>0xFF</td><td>11111111</td><td>(none)</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The ELF magic number starts with these 4 bytes:</p>
                <div class="hex-dump">
                    <pre>7f 45 4c 46</pre>
                </div>
                <p>In decimal: 127, 69, 76, 70. In ASCII: <code>. E L F</code>. The first four bytes literally spell "ELF" if you ignore the first byte.</p>
                <p>You can verify this on any Linux system:</p>
                <div class="code-block">
                    <pre>$ xxd -l 4 /bin/ls
00000000: 7f45 4c46                      .ELF</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Click on each byte to see its decimal, hex, and ASCII values:</p>
                <div class="hex-interactive" id="hex-1">
                    <span class="hex-byte" data-val="127" onclick="selectByte(this)">7f</span>
                    <span class="hex-byte" data-val="69" onclick="selectByte(this)">45</span>
                    <span class="hex-byte" data-val="76" onclick="selectByte(this)">4c</span>
                    <span class="hex-byte" data-val="70" onclick="selectByte(this)">46</span>
                    <div class="hex-info" id="hex-info-1">Click a byte above</div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what decimal value does the hex byte 0x41 represent?</p>
                <div class="quiz" id="quiz-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">32</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, true)">65</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">127</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-1', this, false)">255</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Here is a hex dump of 4 bytes. What ASCII text do they spell?</p>
                <div class="hex-dump">
                    <pre>48 65 6c 6c</pre>
                </div>
                <div class="quiz" id="quiz-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, false)">ELF</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, true)">Hell</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, false)">Help</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-2', this, false)">Hex</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand bytes — the building blocks of every binary format. Next, we will see how bytes are organized into larger structures, and how those structures make up an ELF file.</p>
            </div>
        </div>
    }

    #css {
        .lesson { max-width: 800px; margin: 0 auto; padding: 2rem; font-family: system-ui, -apple-system, sans-serif; line-height: 1.7; color: #111827; }
        .lesson-meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 2rem; }
        .unit { margin-bottom: 2rem; padding: 1.5rem; border-radius: 8px; border-left: 4px solid; }
        .unit-why { border-color: #3b82f6; background: #eff6ff; }
        .unit-model { border-color: #059669; background: #ecfdf5; }
        .unit-reality { border-color: #d97706; background: #fffbeb; }
        .unit-example { border-color: #8b5cf6; background: #f5f3ff; }
        .unit-interact { border-color: #ec4899; background: #fdf2f8; }
        .unit-retrieve { border-color: #06b6d4; background: #ecfeff; }
        .unit-apply { border-color: #f97316; background: #fff7ed; }
        .unit-connect { border-color: #10b981; background: #ecfdf5; }
        h1 { font-size: 1.75rem; margin-bottom: 0.5rem; }
        h2 { font-size: 1.15rem; margin-bottom: 0.75rem; margin-top: 0; }
        p { margin: 0.5rem 0; }
        .code { font-family: ui-monospace, monospace; background: #f5f5f5; padding: 0.5rem 1rem; border-radius: 4px; font-size: 0.9rem; }
        .table-wrapper { overflow-x: auto; margin: 1rem 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 0.5rem 0.75rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 1rem; overflow-x: auto; }
        .hex-dump pre { margin: 0; }
        .code-block { background: #f5f5f5; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.9rem; overflow-x: auto; }
        .code-block pre { margin: 0; }
        .hex-interactive { font-family: ui-monospace, monospace; background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; }
        .hex-byte { display: inline-block; width: 2.5ch; margin-right: 0.75rem; cursor: pointer; border-radius: 2px; padding: 0.25rem; }
        .hex-byte:hover { background: rgba(59, 130, 246, 0.3); }
        .hex-byte.selected { background: rgba(59, 130, 246, 0.5); }
        .hex-info { margin-top: 0.75rem; font-size: 0.85rem; color: #9ca3af; font-family: ui-monospace, monospace; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.95rem; }
        .quiz-option:hover { border-color: #3b82f6; background: #eff6ff; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .quiz-option:disabled { cursor: default; }
        .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.5rem; }
    }

    #js {
        function selectByte(el) {
            var all = el.parentElement.querySelectorAll('.hex-byte');
            for(var i = 0; i < all.length; i++) { all[i].classList.remove('selected'); }
            el.classList.add('selected');
            var val = parseInt(el.getAttribute('data-val'));
            var hex = el.textContent;
            var ascii = (val >= 32 && val < 127) ? String.fromCharCode(val) : '(non-printable)';
            var info = document.getElementById('hex-info-1');
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
                if(quizId === 'quiz-1') {
                    feedback.textContent = 'Not quite. 0x41 = 4*16 + 1 = 65. That is the ASCII code for letter A.';
                } else if(quizId === 'quiz-2') {
                    feedback.textContent = 'Not quite. 0x48=H, 0x65=e, 0x6c=l, 0x6c=l. That spells "Hell".';
                }
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
