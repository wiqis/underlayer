import page
import html_cbi
import css_cbi
import js_cbi

public func render() : std::string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Binary Representation — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Binary Representation</h1>
            <div class="lesson-meta">15 min · Core concept · Module 1 of 2 · Prerequisite: Bytes and Binary</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>An ELF file is just bytes on disk. But those bytes are not random — they encode numbers, addresses, flags, and identifiers using specific binary representations. If you cannot read binary, you cannot read ELF.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Computers store everything as bits (0 or 1). A byte is 8 bits. Larger values need more bytes:</p>
                <ul>
                    <li><strong>2 bytes (16 bits):</strong> up to 65,535</li>
                    <li><strong>4 bytes (32 bits):</strong> up to ~4.29 billion</li>
                    <li><strong>8 bytes (64 bits):</strong> up to ~18 quintillion</li>
                </ul>
                <p>When we read a multi-byte number from a file, the order matters. Do we read the smallest byte first, or the largest? This is called <strong>endianness</strong>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p><strong>Little-endian</strong> (used by x86 and most Linux systems): the smallest byte comes first.</p>
                <p><strong>Big-endian</strong> (used by some network protocols and older systems): the largest byte comes first.</p>
                <p>The ELF header tells you which one the file uses. Byte 5 of the ELF identification section is the data encoding byte:</p>
                <div class="code-block">
                    <pre>Byte 5 = 0x01 → little-endian (ELFDATA2LSB)
Byte 5 = 0x02 → big-endian (ELFDATA2MSB)</pre>
                </div>
                <p>Example: the 32-bit number 0x01020304 stored in little-endian appears in the file as:</p>
                <div class="hex-dump">
                    <pre>04 03 02 01</pre>
                </div>
                <p>Reading left to right (lowest address first), you see the least significant byte first.</p>

                <h3>Two's complement for signed integers</h3>
                <p>For signed numbers, computers use two's complement. The highest bit indicates sign: 0 = positive, 1 = negative. -1 in a 32-bit integer is stored as <code>0xFFFFFFFF</code> (all bits set).</p>

                <h3>ELF uses these types</h3>
                <div class="table-wrapper">
                    <table>
                        <thead>
                            <tr><th>Type</th><th>Bytes</th><th>Max value (unsigned)</th><th>Used for</th></tr>
                        </thead>
                        <tbody>
                            <tr><td>Elf8 (s8/u8)</td><td>1</td><td>255</td><td>Characters, small flags</td></tr>
                            <tr><td>Elf16 (s16/u16)</td><td>2</td><td>65,535</td><td>Type IDs, version numbers</td></tr>
                            <tr><td>Elf32 (s32/u32)</td><td>4</td><td>4,294,967,295</td><td>Offsets, addresses (32-bit)</td></tr>
                            <tr><td>Elf64 (s64/u64)</td><td>8</td><td>~18 quintillion</td><td>Offsets, addresses (64-bit)</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Let's look at bytes 4-7 of a real ELF file's identification section:</p>
                <div class="hex-dump">
                    <pre>02 01 01 00</pre>
                </div>
                <p>Byte 4 (<code>02</code>): ELF class — 64-bit (ELFCLASS64)</p>
                <p>Byte 5 (<code>01</code>): Data encoding — little-endian (ELFDATA2LSB)</p>
                <p>Byte 6 (<code>01</code>): Version — current (EV_CURRENT)</p>
                <p>Byte 7 (<code>00</code>): OS/ABI — System V (ELFOSABI_NONE)</p>

                <p>If we read bytes 16-17 as a little-endian 16-bit number, we get the ELF type:</p>
                <div class="hex-dump">
                    <pre>03 00</pre>
                </div>
                <p>Little-endian: <code>0x0003</code> = ET_DYN (shared object / PIE executable).</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Here are 4 bytes from a file. What 32-bit little-endian number do they represent?</p>
                <div class="hex-interactive" id="hex-2">
                    <span class="hex-byte" data-val="255" onclick="selectByte2(this)">ff</span>
                    <span class="hex-byte" data-val="254" onclick="selectByte2(this)">fe</span>
                    <span class="hex-byte" data-val="253" onclick="selectByte2(this)">fd</span>
                    <span class="hex-byte" data-val="252" onclick="selectByte2(this)">fc</span>
                    <div class="hex-info" id="hex-info-2">Click a byte above</div>
                </div>
                <p style="margin-top:1rem">As a little-endian 32-bit integer, these bytes represent:</p>
                <div class="code-block">0x____ ____</div>
                <div class="quiz" id="quiz-endian">
                    <button class="quiz-option" onclick="checkEndian(this, false)">0xFCFDFFFE</button>
                    <button class="quiz-option" onclick="checkEndian(this, true)">0xFEFFFFFF</button>
                    <button class="quiz-option" onclick="checkEndian(this, false)">0xFFFEFFFC</button>
                    <button class="quiz-option" onclick="checkEndian(this, false)">0xFEFDFCFD</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: on a little-endian x86 system, what byte comes first in a 4-byte integer — the most significant or the least significant?</p>
                <div class="quiz" id="quiz-3">
                    <button class="quiz-option" onclick="checkQuiz('quiz-3', this, true)">Least significant byte comes first</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-3', this, false)">Most significant byte comes first</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-3', this, false)">It depends on the file format</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You see these bytes at offset 16 in an ELF file: <code>02 00</code>. The file is 64-bit little-endian. What ELF type does this represent?</p>
                <div class="quiz" id="quiz-4">
                    <button class="quiz-option" onclick="checkQuiz('quiz-4', this, false)">ET_EXEC (executable)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-4', this, true)">ET_DYN (shared object/PIE)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-4', this, false)">ET_REL (relocatable)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-4', this, false)">ET_CORE (core dump)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Now you know how bytes encode numbers and how endianness determines byte order. This is essential for reading the ELF header, which is full of multi-byte integers. Next: how those bytes are laid out in a file.</p>
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
        h3 { font-size: 1rem; margin: 1rem 0 0.5rem; color: #374151; }
        p { margin: 0.5rem 0; }
        ul { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin: 0.25rem 0; }
        .code { font-family: ui-monospace, monospace; background: #f5f5f5; padding: 0.15rem 0.4rem; border-radius: 3px; font-size: 0.9rem; }
        .code-block { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.9rem; overflow-x: auto; margin: 1rem 0; }
        .hex-dump { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; font-family: ui-monospace, monospace; font-size: 0.95rem; overflow-x: auto; margin: 1rem 0; }
        .hex-interactive { font-family: ui-monospace, monospace; background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 6px; }
        .hex-byte { display: inline-block; width: 2.5ch; margin-right: 0.75rem; cursor: pointer; border-radius: 2px; padding: 0.25rem; }
        .hex-byte:hover { background: rgba(59, 130, 246, 0.3); }
        .hex-byte.selected { background: rgba(59, 130, 246, 0.5); }
        .hex-info { margin-top: 0.75rem; font-size: 0.85rem; color: #9ca3af; font-family: ui-monospace, monospace; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem 0.75rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; font-size: 0.95rem; }
        .quiz-option:hover { border-color: #3b82f6; background: #eff6ff; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .quiz-option:disabled { cursor: default; }
        .quiz-feedback { margin-top: 0.75rem; font-size: 0.9rem; min-height: 1.5rem; }
    }

    #js {
        function selectByte2(el) {
            var all = el.parentElement.querySelectorAll('.hex-byte');
            for(var i = 0; i < all.length; i++) { all[i].classList.remove('selected'); }
            el.classList.add('selected');
            var val = parseInt(el.getAttribute('data-val'));
            var hex = el.textContent;
            var ascii = (val >= 32 && val < 127) ? String.fromCharCode(val) : '(non-printable)';
            var info = document.getElementById('hex-info-2');
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
                var msg = '';
                if(quizId === 'quiz-3') {
                    msg = 'Not quite. x86 is little-endian, meaning the least significant byte (the smallest part of the number) comes first in memory.';
                } else if(quizId === 'quiz-4') {
                    msg = 'Not quite. 0x0002 in the ELF type field = ET_DYN (shared object / position-independent executable). ET_EXEC would be 0x0002 read as big-endian, but on little-endian the bytes 02 00 = 0x0002.';
                }
                feedback.textContent = msg;
                feedback.style.color = '#dc2626';
            }
        }

        function checkEndian(btn, correct) {
            var quiz = document.getElementById('quiz-endian');
            var options = quiz.querySelectorAll('.quiz-option');
            var feedback = quiz.querySelector('.quiz-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! In little-endian, the bytes are read in reverse order: fc fd fe ff → 0xFEFFFFFF.';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. In little-endian, the least significant byte comes first, so you read the bytes in reverse: the bytes fc fd fe ff represent 0xFEFFFFFF.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
