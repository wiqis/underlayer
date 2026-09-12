// ELF Course — Concept 10: Section Header Table
// The table that describes each section in the ELF file.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_section_header_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Section Header Table — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Section Header Table</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>While program headers are for the loader, section headers are for tools — the linker, debugger, readelf, objdump. They describe the logical structure of the file: where code lives, where symbols are defined, where relocations need to be applied.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of section headers as a detailed index of the file. Each entry describes one section with its name, type, flags, address, offset, and size.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each 64-bit section header entry is 64 bytes:</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>sh_name</td><td>4</td><td>Index into section name string table</td></tr>
                        <tr><td>sh_type</td><td>4</td><td>Section type (SHT_PROGBITS=1, SHT_SYMTAB=2, SHT_STRTAB=3, ...)</td></tr>
                        <tr><td>sh_flags</td><td>8</td><td>SHF_WRITE=1, SHF_ALLOC=2, SHF_EXECINSTR=4</td></tr>
                        <tr><td>sh_addr</td><td>8</td><td>Virtual address (0 if not loaded)</td></tr>
                        <tr><td>sh_offset</td><td>8</td><td>File offset</td></tr>
                        <tr><td>sh_size</td><td>8</td><td>Section size in bytes</td></tr>
                        <tr><td>sh_link</td><td>4</td><td>Link to related section</td></tr>
                        <tr><td>sh_info</td><td>4</td><td>Additional info</td></tr>
                        <tr><td>sh_addralign</td><td>8</td><td>Alignment</td></tr>
                        <tr><td>sh_entsize</td><td>8</td><td>Entry size (for tables)</td></tr>
                    </tbody>
                </table>
                <p>The <code>e_shstrndx</code> field in the ELF header points to the section that contains all section names (typically <code>.shstrtab</code>).</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -S /bin/ls | head -15
Section Headers:
  [Nr] Name              Type             Address          Offset   Size
  [ 0]                   NULL             0000000000000000 00000000 000000
  [ 1] .interp           PROGBITS         00000000000002b8 000002b8 00001c
  [ 2] .note.gnu.property NOTE             00000000000002d8 000002d8 000020
  [ 3] .gnu.hash         GNU_HASH         00000000000002f8 000002f8 0000b0
  [ 4] .dynsym           DYNSYM           00000000000003a8 000003a8 000180
  [ 5] .dynstr           STRTAB           0000000000000528 00000528 0000c0
  [ 6] .gnu.version      VERNEED          00000000000005e8 000005e8 00003c
  [ 7] .gnu.version_r    VERNEED          0000000000000624 00000624 000060</pre>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does the sh_addr field represent?</p>
                <div class="quiz" id="quiz-sht-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, false)">The file offset</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, true)">The virtual address in memory</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-1', this, false)">The section size</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A section has sh_offset=0x1000 and sh_size=0x200. How many bytes of the ELF file does it occupy?</p>
                <div class="quiz" id="quiz-sht-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, true)">0x200 (512 bytes)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, false)">0x1000 (4096 bytes)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-sht-2', this, false)">0x1200</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Section headers describe individual sections. The next concept covers the most common sections you'll encounter.</p>
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
            if(correct) { btn.classList.add('correct'); feedback.textContent = 'Correct!'; feedback.style.color = '#059669'; }
            else { btn.classList.add('wrong'); feedback.textContent = 'Not quite.'; feedback.style.color = '#dc2626'; }
        }
    }
    return page.toString()
}
}
