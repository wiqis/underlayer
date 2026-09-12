// ELF Course — Concept 4: ELF Identification
// The e_ident array — magic number, class, data encoding, OS/ABI.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_elf_identification() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ELF Identification — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>ELF Identification</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Before the system can read any ELF file, it needs to answer basic questions: Is this a 32-bit or 64-bit file? Is it little-endian or big-endian? What operating system does it target? The ELF identification array answers all of these questions in the first 16 bytes.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The first 16 bytes of every ELF file are the <code>e_ident</code> array. Think of it as the file's ID card:</p>
                <ul>
                    <li><strong>Bytes 0-3:</strong> Magic number — <code>7f 45 4c 46</code> (spells ".ELF")</li>
                    <li><strong>Byte 4:</strong> Class — 1 = 32-bit, 2 = 64-bit</li>
                    <li><strong>Byte 5:</strong> Data encoding — 1 = little-endian, 2 = big-endian</li>
                    <li><strong>Byte 6:</strong> ELF version — always 1</li>
                    <li><strong>Byte 7:</strong> OS/ABI — 0 = System V, 3 = Linux, 6 = Solaris, etc.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <table>
                    <thead>
                        <tr><th>Index</th><th>Name</th><th>Values</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>EI_MAG0</td><td>0x7f</td><td>Magic number byte 0</td></tr>
                        <tr><td>1</td><td>EI_MAG1</td><td>0x45 ('E')</td><td>Magic number byte 1</td></tr>
                        <tr><td>2</td><td>EI_MAG2</td><td>0x4c ('L')</td><td>Magic number byte 2</td></tr>
                        <tr><td>3</td><td>EI_MAG3</td><td>0x46 ('F')</td><td>Magic number byte 3</td></tr>
                        <tr><td>4</td><td>EI_CLASS</td><td>1 or 2</td><td>ELFCLASS32 or ELFCLASS64</td></tr>
                        <tr><td>5</td><td>EI_DATA</td><td>1 or 2</td><td>ELFDATA2LSB (little) or ELFDATA2MSB (big)</td></tr>
                        <tr><td>6</td><td>EI_VERSION</td><td>1</td><td>ELF version (always 1)</td></tr>
                        <tr><td>7</td><td>EI_OSABI</td><td>0-18</td><td>Operating system / ABI identifier</td></tr>
                        <tr><td>8-15</td><td>EI_ABIVERSION</td><td>varies</td><td>ABI version + 7 bytes padding</td></tr>
                    </tbody>
                </table>
                <p>The gABI specification defines EI_OSABI values: 0=ELFOSABI_NONE (System V), 1=ELFOSABI_HPUX, 3=ELFOSABI_LINUX, 6=ELFOSABI_SOLARIS, 9=ELFOSABI_FREEBSD.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here's the e_ident of a real 64-bit Linux executable:</p>
                <div class="hex-dump">
                    <pre>00000000: 7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
          ^^ ^^ ^^ ^^ ^  ^  ^  ^  ^^^^^^^^^^^^^^^^^^^^^^^
          Magic "ELF"  64 LE v1 Linux  padding (zeroed)</pre>
                </div>
                <p>Breaking it down: <code>7f 45 4c 46</code> = ELF magic, <code>02</code> = 64-bit, <code>01</code> = little-endian, <code>01</code> = version 1, <code>00</code> = Linux ABI.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Run this to see the ELF identification of any binary:</p>
                <pre><code>$ readelf -h /bin/ls | head -8
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0</code></pre>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What are the first 4 bytes of every ELF file?</p>
                <div class="quiz" id="quiz-ei-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-1', this, false)">01 02 03 04</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-1', this, true)">7f 45 4c 46</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-1', this, false)">ff fe fd fc</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A file starts with <code>7f 45 4c 46 01 02 01 00</code>. What can you tell about it?</p>
                <div class="quiz" id="quiz-ei-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-2', this, false)">64-bit, little-endian</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-2', this, false)">32-bit, little-endian</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ei-2', this, true)">32-bit, big-endian</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>Byte 4 = 01 means 32-bit. Byte 5 = 02 means big-endian.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The ELF identification tells us the file's basic properties. The rest of the ELF header (next concept) tells us about entry points, section locations, and architecture.</p>
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

    return page.toString()
}
}
