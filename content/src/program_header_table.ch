// ELF Course — Concept 7: Program Header Table
// The table that describes how segments are loaded into memory.
using std::string
using std::string_view

public func render_program_header_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Program Header Table — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Program Header Table</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The kernel doesn't load an ELF file byte-by-byte. It reads the program header table to find which parts of the file map to which memory regions. Without program headers, the loader wouldn't know what to load or where to put it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of program headers as a list of "load this chunk here" instructions. Each program header entry describes one <strong>segment</strong> — a contiguous region of the file that gets mapped into memory.</p>
                <ul>
                    <li><strong>LOAD segments</strong> — actual code and data to map</li>
                    <li><strong>DYNAMIC segment</strong> — dynamic linker info</li>
                    <li><strong>INTERP segment</strong> — path to the dynamic linker</li>
                    <li><strong>NOTE segment</strong> — auxiliary notes (build ID, etc.)</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Each 64-bit program header entry is 56 bytes:</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>p_type</td><td>4</td><td>Segment type (PT_LOAD=1, PT_DYNAMIC=2, PT_INTERP=3, ...)</td></tr>
                        <tr><td>p_flags</td><td>4</td><td>Permissions: PF_X=1, PF_W=2, PF_R=4</td></tr>
                        <tr><td>p_offset</td><td>8</td><td>File offset where segment starts</td></tr>
                        <tr><td>p_vaddr</td><td>8</td><td>Virtual address to map to</td></tr>
                        <tr><td>p_paddr</td><td>8</td><td>Physical address (usually same as p_vaddr)</td></tr>
                        <tr><td>p_filesz</td><td>8</td><td>Size of segment in the file</td></tr>
                        <tr><td>p_memsz</td><td>8</td><td>Size of segment in memory (may be larger for .bss)</td></tr>
                        <tr><td>p_align</td><td>8</td><td>Alignment requirement</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>Program Headers:
  Type     Offset   VirtAddr           FileSiz  MemSiz   Flg  Align
  PHDR     0x000040 0x0000000000000040 0x000278 0x000278 R    0x8
  INTERP   0x0002b8 0x00000000000002b8 0x00001c 0x00001c R    0x1
  LOAD     0x000000 0x0000000000000000 0x0005e8 0x0005e8 R    0x1000
  LOAD     0x001000 0x0000000000001000 0x001a52 0x001a52 R E  0x1000
  LOAD     0x003000 0x0000000000003000 0x000ba0 0x000ba0 R    0x1000
  LOAD     0x003dc0 0x0000000000004dc0 0x000260 0x000260 RW   0x1000
  DYNAMIC  0x003e28 0x0000000000004e28 0x0001f0 0x0001f0 RW   0x8
  NOTE     0x0002d8 0x00000000000002d8 0x000030 0x000030 R    0x8</pre>
                </div>
                <p>The first LOAD segment is read-only (code and read-only data). The second LOAD is executable (the .text section). The last LOAD is read-write (data and BSS).</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What does a PT_LOAD segment with p_memsz > p_filesz indicate?</p>
                <div class="quiz" id="quiz-pht-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, false)">The file is corrupted</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, true)">Extra memory is zero-initialized (like .bss)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-pht-1', this, false)">The segment is compressed</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Program headers define segments. But segments and sections are different things — segments are for the loader, sections are for tools. The next concepts explore this distinction.</p>
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
