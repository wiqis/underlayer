// ELF Course — Concept 12: Section vs Segment
// Why sections and segments are different things, and how they relate.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_section_vs_segment() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Section vs Segment — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Section vs Segment</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>This is one of the most common sources of confusion in ELF. Sections and segments are related but fundamentally different concepts. Mixing them up leads to incorrect tool usage and misunderstanding of how ELF works.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <ul>
                    <li><strong>Sections</strong> are for <em>tools</em> (linker, debugger, readelf). They describe logical groupings of data.</li>
                    <li><strong>Segments</strong> are for the <em>runtime loader</em>. They describe how to map the file into memory.</li>
                </ul>
                <p>Think of it this way: a library has books organized by topic (sections), but the library's shipping department groups books into boxes for delivery (segments). One box might contain books from multiple topics.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Key differences:</p>
                <table>
                    <thead>
                        <tr><th>Aspect</th><th>Section</th><th>Segment</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Defined by</td><td>Section header table</td><td>Program header table</td></tr>
                        <tr><td>Used by</td><td>Tools (linker, debugger)</td><td>Runtime loader (kernel)</td></tr>
                        <tr><td>Granularity</td><td>Fine-grained (many sections)</td><td>Coarse-grained (few segments)</td></tr>
                        <tr><td>Overlap</td><td>Sections don't overlap</td><td>Segments can contain multiple sections</td></tr>
                        <tr><td>Permissions</td><td>No permissions</td><td>R/W/X permissions per segment</td></tr>
                        <tr><td>Purpose</td><td>Define what the data is</td><td>Define how to load it</td></tr>
                    </tbody>
                </table>
                <p>A single PT_LOAD segment typically contains multiple sections: .init, .plt, .text, and .rodata might all be in the same read-only, executable segment.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>Segments (program headers):
  LOAD  [0x000000-0x0005e8]  R      → Contains: .interp, .note, .gnu.hash, .dynsym, .dynstr, .gnu.version
  LOAD  [0x001000-0x002a52]  R E    → Contains: .init, .plt, .text
  LOAD  [0x003000-0x003ba0]  R      → Contains: .rodata, .eh_frame
  LOAD  [0x003dc0-0x004020]  RW     → Contains: .data, .bss, .got

Sections:
  .text     → In LOAD segment 2 (R E)
  .data     → In LOAD segment 4 (RW)
  .bss      → In LOAD segment 4 (RW, zero-filled)
  .rodata   → In LOAD segment 3 (R)</pre>
                </div>
                <p>Notice how 4 segments contain 12+ sections. The loader doesn't know about individual sections — it only sees segments.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Can a section exist without being in any segment?</p>
                <div class="quiz" id="quiz-svs-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-svs-1', this, true)">Yes — debugging sections like .symtab are not in any LOAD segment</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-svs-1', this, false)">No — every section must be in a segment</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-svs-1', this, false)">Only .bss can exist without a segment</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>Sections like .symtab, .strtab, and .debug_* are not loaded into memory — they have no corresponding segment.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Congratulations! You've completed the ELF course fundamentals. You now understand bytes, binary representation, file layout, the ELF header, program headers, sections, and the relationship between them.</p>
                <p>Next steps: explore symbols, relocations, and dynamic linking — the advanced topics that make ELF a complete binary format.</p>
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
            if(correct) { btn.classList.add('correct'); feedback.textContent = 'Correct!'; feedback.style.color = '#059669'; }
            else { btn.classList.add('wrong'); feedback.textContent = 'Not quite.'; feedback.style.color = '#dc2626'; }
        }
    }
    return page.toString()
}
}
