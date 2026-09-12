// ELF Course — Concept 8: Segment Types
// PT_LOAD, PT_DYNAMIC, PT_INTERP — what each segment type does.
using std::string
using std::string_view

public func render_segment_types() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Segment Types — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Segment Types</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Not all segments are created equal. Some contain code, some tell the dynamic linker where to find shared libraries, and some carry debugging information. Understanding segment types tells you what each part of the file is for.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of segment types as labels on shipping boxes:</p>
                <ul>
                    <li><strong>PT_LOAD</strong> — "Load this into memory" (code, data, BSS)</li>
                    <li><strong>PT_DYNAMIC</strong> — "This has dynamic linker info"</li>
                    <li><strong>PT_INTERP</strong> — "This is the path to the dynamic linker"</li>
                    <li><strong>PT_NOTE</strong> — "This has metadata/notes"</li>
                    <li><strong>PT_GNU_STACK</strong> — "This controls stack permissions"</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <table>
                    <thead>
                        <tr><th>Type</th><th>Value</th><th>Purpose</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>PT_NULL</td><td>0</td><td>Unused entry</td></tr>
                        <tr><td>PT_LOAD</td><td>1</td><td>Loadable segment — mapped into memory</td></tr>
                        <tr><td>PT_DYNAMIC</td><td>2</td><td>Dynamic linking information</td></tr>
                        <tr><td>PT_INTERP</td><td>3</td><td>Path to interpreter (dynamic linker)</td></tr>
                        <tr><td>PT_NOTE</td><td>4</td><td>Notes (build ID, ABI info)</td></tr>
                        <tr><td>PT_PHDR</td><td>6</td><td>Program header table itself</td></tr>
                        <tr><td>PT_TLS</td><td>7</td><td>Thread-local storage</td></tr>
                        <tr><td>PT_GNU_EH_FRAME</td><td>0x6474e550</td><td>Exception handling frame</td></tr>
                        <tr><td>PT_GNU_STACK</td><td>0x6474e551</td><td>Stack permissions (NX bit)</td></tr>
                        <tr><td>PT_GNU_RELRO</td><td>0x6474e552</td><td>Read-only after relocation</td></tr>
                    </tbody>
                </table>
                <p>A typical executable has 2-4 PT_LOAD segments (read-only, read-execute, read-write) plus PT_DYNAMIC, PT_INTERP, PT_NOTE, and PT_GNU_STACK.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ readelf -l /bin/ls
  Type     Offset   VirtAddr           Flg  What
  PHDR     ...      0x...0040          R    Program headers
  INTERP   ...      0x...02b8          R    /lib64/ld-linux-x86-64.so.2
  LOAD     0x000000 0x0000000000000000 R    Read-only (headers)
  LOAD     0x001000 0x0000000000001000 R E  Executable code
  LOAD     0x003000 0x0000000000003000 R    Read-only data
  LOAD     0x003dc0 0x0000000000004dc0 RW   Read-write data
  DYNAMIC  ...      0x...4e28          RW   Dynamic section
  GNU_STACK ...     0x0000000000000000 RW   Stack (NX enabled)</pre>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Which segment type tells the kernel where the dynamic linker is?</p>
                <div class="quiz" id="quiz-st-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, false)">PT_DYNAMIC</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, true)">PT_INTERP</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, false)">PT_LOAD</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Segments tell the loader what to load. But how does the loader map file offsets to virtual addresses? That's memory mapping (next concept).</p>
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
                feedback.textContent = 'Not quite.';
                feedback.style.color = '#dc2626';
            }
        }
    }

    return page.toString()
}
