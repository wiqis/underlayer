// ELF Course — Concept 13: Symbol Table
// The .symtab and .dynsym sections — Elf64_Sym entries, string tables, and how symbols are organized.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_symbol_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Table — Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <h1>Symbol Table</h1>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Symbols are how ELF files name their functions and variables. When you call printf(), the linker resolves that name to an address by looking it up in a symbol table. Without symbols, there is no way to reference code or data across compilation units.</p>
                <p>Understanding symbol tables lets you debug linking errors, inspect binary contents with nm, and understand how shared libraries export their interfaces.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A symbol table is a lookup dictionary. Each entry maps a name (like "main" or "printf") to:</p>
                <ul>
                    <li><strong>Value</strong> — An address or offset</li>
                    <li><strong>Size</strong> — How many bytes the symbol occupies</li>
                    <li><strong>Type</strong> — Function, object, section, or file</li>
                    <li><strong>Binding</strong> — Local, global, or weak</li>
                    <li><strong>Section</strong> — Which section it belongs to</li>
                </ul>
                <p>The names themselves live in a separate string table (.strtab). Each symbol entry holds an offset into that string table.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>ELF has two symbol tables:</p>
                <table>
                    <thead>
                        <tr><th>Table</th><th>Section</th><th>Purpose</th><th>Used By</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.symtab</td><td>SHT_SYMTAB</td><td>Full symbol table (all symbols)</td><td>Static linker, debugger</td></tr>
                        <tr><td>.dynsym</td><td>SHT_DYNSYM</td><td>Dynamic symbols (exported/imported only)</td><td>Dynamic linker (ld.so)</td></tr>
                    </tbody>
                </table>
                <p>Each entry is an Elf64_Sym structure (24 bytes on 64-bit):</p>
                <table>
                    <thead>
                        <tr><th>Field</th><th>Type</th><th>Size</th><th>Description</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>st_name</td><td>Elf64_Word</td><td>4 bytes</td><td>Offset into string table</td></tr>
                        <tr><td>st_info</td><td>unsigned char</td><td>1 byte</td><td>Binding (high 4 bits) + Type (low 4 bits)</td></tr>
                        <tr><td>st_other</td><td>unsigned char</td><td>1 byte</td><td>Visibility (low 2 bits)</td></tr>
                        <tr><td>st_shndx</td><td>Elf64_Half</td><td>2 bytes</td><td>Section index (0 = undefined)</td></tr>
                        <tr><td>st_value</td><td>Elf64_Addr</td><td>8 bytes</td><td>Symbol value (address or offset)</td></tr>
                        <tr><td>st_size</td><td>Elf64_Xword</td><td>8 bytes</td><td>Symbol size (0 if unknown)</td></tr>
                    </tbody>
                </table>
                <p>The st_info field packs two values: binding and type. Use ELF64_ST_BIND(info) to extract binding, ELF64_ST_TYPE(info) for type.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <div class="hex-dump">
                    <pre>$ nm -n /bin/ls | head -20
                 w __cxa_finalize
                 w __gmon_start__
                 w _ITM_deregisterTMCloneTable
                 w _ITM_registerTMCloneTable
                 w __cxa_atexit
                 U __errno_location
                 U __fpending
                 U __freading
                 U __malloc_hook
                 U __memcpy_chk
                 U __stack_chk_fail
                 U abort
                 U access
                 U backtrace
                 00000000000030a0 T .annobin_... 
                 0000000000003120 T _start
                 0000000000003150 T .annobin_...
                 0000000000003190 T __do_global_dtors_aux</pre>
                </div>
                <p>nm -n sorts by address. U means "undefined" (imported from another library). T means "in text section" (defined here).</p>
                <p>The .dynsym is a subset — only symbols needed for dynamic linking:</p>
                <div class="hex-dump">
                    <pre>$ readelf -sW /bin/ls | grep FUNC | head -10
     1: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __ctype_b_loc
     2: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __errno_location
     5: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND free
     8: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND malloc
    15: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND printf
    3: 0000000000003120   108 FUNC    GLOBAL DEFAULT   13 _start
    4: 0000000000003190   186 FUNC    GLOBAL DEFAULT   13 __do_global_dtors_aux
    6: 0000000000003260  1162 FUNC    GLOBAL DEFAULT   13 main</pre>
                </div>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <div class="hex-dump"><pre># See all symbols in your program
nm -n ./my_program

# Only defined symbols (not imports)
nm --defined-only ./my_program

# Demangle C++ names
nm -C ./my_program_cpp

# See the raw symbol table structure
readelf -sW ./my_program</pre></div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>What is the difference between .symtab and .dynsym?</p>
                <div class="quiz" id="quiz-st-1">
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, false)">.symtab is for dynamic linking, .dynsym is for static linking</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, true)">.symtab has all symbols, .dynsym has only those needed for dynamic linking</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, false)">They are identical — .dynsym is just a backup</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>If a symbol has st_shndx = SHN_UNDEF (0), what does that mean?</p>
                <div class="quiz" id="quiz-st-2">
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-2', this, false)">The symbol is corrupted</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-2', this, true)">The symbol is defined in another object file or library (it is an import)</button>
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-2', this, false)">The symbol is at address 0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Each symbol has a binding (local, global, weak) and a visibility. These determine how the linker resolves symbols across object files — that is what the next two concepts cover.</p>
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
        .quiz { margin-top: 1rem; }
        .quiz-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .quiz-option:hover { border-color: #3b82f6; }
        .quiz-option.correct { border-color: #059669; background: #ecfdf5; }
        .quiz-option.wrong { border-color: #dc2626; background: #fef2f2; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        ul { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
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
