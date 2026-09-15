// ELF Course — Concept 5: ELF Header Fields
// Every field in the ELF header and what it tells the system.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_elf_header_fields() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("ELF Header Fields — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>ELF Header Fields</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The ELF header is the first thing any tool reads. It tells the linker where sections are, the loader where program headers are, and the debugger what architecture the code targets. Every field has a specific purpose — and understanding them means you can read any ELF file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The ELF header (after the 16-byte e_ident) contains metadata about the file. Think of it as a table of contents:</p>
                <ul>
                    <li><strong>What type is it?</strong> (executable, shared library, relocatable)</li>
                    <li><strong>What architecture?</strong> (x86, ARM, RISC-V)</li>
                    <li><strong>Where does code start?</strong> (entry point address)</li>
                    <li><strong>Where are the program headers?</strong> (for the loader)</li>
                    <li><strong>Where are the section headers?</strong> (for tools)</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Here are all fields in the 64-bit ELF header (52 bytes after e_ident, total 64 bytes):</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Offset</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>e_ident</td><td>0</td><td>16</td><td>Identification array (previous concept)</td></tr>
                        <tr><td>e_type</td><td>16</td><td>2</td><td>ET_EXEC (2), ET_DYN (3), ET_REL (1)</td></tr>
                        <tr><td>e_machine</td><td>18</td><td>2</td><td>Architecture: 0x03=x86, 0x3E=x86-64, 0x28=ARM, 0xF3=RISC-V</td></tr>
                        <tr><td>e_version</td><td>20</td><td>4</td><td>ELF version (always 1)</td></tr>
                        <tr><td>e_entry</td><td>24</td><td>8</td><td>Virtual address of entry point</td></tr>
                        <tr><td>e_phoff</td><td>32</td><td>8</td><td>Program header table offset</td></tr>
                        <tr><td>e_shoff</td><td>40</td><td>8</td><td>Section header table offset</td></tr>
                        <tr><td>e_flags</td><td>48</td><td>4</td><td>Processor-specific flags</td></tr>
                        <tr><td>e_ehsize</td><td>52</td><td>2</td><td>ELF header size (64 for 64-bit)</td></tr>
                        <tr><td>e_phentsize</td><td>54</td><td>2</td><td>Program header entry size (56 for 64-bit)</td></tr>
                        <tr><td>e_phnum</td><td>56</td><td>2</td><td>Number of program header entries</td></tr>
                        <tr><td>e_shentsize</td><td>58</td><td>2</td><td>Section header entry size (64 for 64-bit)</td></tr>
                        <tr><td>e_shnum</td><td>60</td><td>2</td><td>Number of section header entries</td></tr>
                        <tr><td>e_shstrndx</td><td>62</td><td>2</td><td>Section name string table index</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Here's a real ELF header from a 64-bit Linux binary:</p>
                <div class="hex-dump">
                    <pre>ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  Type:                              DYN (Position-Independent Executable)
  Machine:                           Advanced Micro Devices x86-64
  Entry point address:               0x6810
  Start of program headers:          64 (bytes into file)
  Start of section headers:          16400 (bytes into file)
  Flags:                             0x0
  Size of this header:               64 (bytes)
  Size of program header entries:    56 (bytes)
  Number of program headers:         9
  Size of section header entries:    64 (bytes)
  Number of section headers:         27
  Section header string table index: 26</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Use <code>readelf -h</code> on different binaries to compare headers. Try the <code>ls</code>, <code>python3</code>, or any compiled program in bin directories.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What field in the ELF header tells the loader where the program header table begins?</p>
                <div class="quiz" id="quiz-ehf-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, false)">e_shoff</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, true)">e_phoff</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-1', this, false)">e_entry</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If <code>e_phnum = 9</code> and <code>e_phentsize = 56</code>, how many bytes does the program header table occupy?</p>
                <div class="quiz" id="quiz-ehf-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, false)">56 bytes</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, true)">504 bytes</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-ehf-2', this, false)">9 bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>9 entries × 56 bytes each = 504 bytes total.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now understand every field in the ELF header. The entry point field (next concept) deserves special attention — it's where execution begins.</p>
            </div>

            <nav class="toc" id="toc">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">↑ Top</button>
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
        .toc { position: sticky; top: 2rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb; margin-bottom: 1.5rem; }
        .toc-title { font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; margin-bottom: 0.5rem; }
        .toc-list { list-style: none; padding: 0; margin: 0; }
        .toc-list li { margin-bottom: 0.25rem; }
        .toc-list a { color: #374151; text-decoration: none; font-size: 0.85rem; display: block; padding: 0.2rem 0.5rem; border-radius: 4px; }
        .toc-list a:hover { background: #e5e7eb; }
        .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
        .back-to-top.visible { opacity: 1; pointer-events: auto; }
        .back-to-top:hover { background: #111827; }
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

        (function() {
            var btn = document.getElementById('back-to-top');
            window.addEventListener('scroll', function() {
                if(window.scrollY > 300) { btn.classList.add('visible'); }
                else { btn.classList.remove('visible'); }
            });
            var tocList = document.getElementById('toc-list');
            var headings = document.querySelectorAll('.lesson h2');
            for(var i = 0; i < headings.length; i++) {
                var h = headings[i];
                var id = 'section-' + i;
                h.id = id;
                var li = document.createElement('li');
                var a = document.createElement('a');
                a.href = '#' + id;
                a.textContent = h.textContent;
                li.appendChild(a);
                tocList.appendChild(li);
            }
        })();
    }

    return page.toString()
}
}
