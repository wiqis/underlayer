// ELF Course ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Concept 13: Symbol Table
// The .symtab and .dynsym sections ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Elf64_Sym entries, string tables, and how symbols are organized.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_symbol_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Table ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Underlayer")
    page.appendTitle(&title)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
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
                    <li><strong>Value</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â An address or offset</li>
                    <li><strong>Size</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â How many bytes the symbol occupies</li>
                    <li><strong>Type</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Function, object, section, or file</li>
                    <li><strong>Binding</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Local, global, or weak</li>
                    <li><strong>Section</strong> ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Which section it belongs to</li>
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
                <p>The .dynsym is a subset ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â only symbols needed for dynamic linking:</p>
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
                    <button class="quiz-option" onclick="checkQuiz('quiz-st-1', this, false)">They are identical ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â .dynsym is just a backup</button>
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
                <p>Each symbol has a binding (local, global, weak) and a visibility. These determine how the linker resolves symbols across object files ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â that is what the next two concepts cover.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Recognize the Output</h2>
                <p>Which type of symbol does this readelf output represent?</p>
                <div class="hex-dump"><pre>    8: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_atexit</pre></div>
                <div class="recognize-quiz" id="rec-st-1">
                    <button class="recognize-option" onclick="checkRecognize('rec-st-1', this, false)">A local function defined in this file</button>
                    <button class="recognize-option" onclick="checkRecognize('rec-st-1', this, true)">An imported function from libc (undefined, weak binding)</button>
                    <button class="recognize-option" onclick="checkRecognize('rec-st-1', this, false)">A global variable in .bss</button>
                    <div class="recognize-feedback"></div>
                </div>
            </div>

            <div class="unit unit-retrieve">
                <h2>Recognize the Output</h2>
                <p>What does this symbol table entry tell you?</p>
                <div class="hex-dump"><pre>   42: 0000000000401130    23 FUNC    GLOBAL DEFAULT  13 main</pre></div>
                <div class="recognize-quiz" id="rec-st-2">
                    <button class="recognize-option" onclick="checkRecognize('rec-st-2', this, false)">Undefined function (import)</button>
                    <button class="recognize-option" onclick="checkRecognize('rec-st-2', this, true)">Defined function: main() at 0x401130, 23 bytes, in section 13 (.text)</button>
                    <button class="recognize-option" onclick="checkRecognize('rec-st-2', this, false)">A 23-byte global variable</button>
                    <div class="recognize-feedback"></div>
                </div>
            </div>

            <nav class="toc" id="toc">
                <div class="toc-title">On this page</div>
                <ul class="toc-list" id="toc-list"></ul>
            </nav>
            <button class="back-to-top" id="back-to-top" onclick="window.scrollTo({top:0,behavior:'smooth'})" aria-label="Back to top">ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬Ëœ Top</button>
            <div class="a11y-toast" id="a11y-toast"></div>
            <div class="swipe-hint">ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Swipe to navigate ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢</div>
            <link rel="prev" href="">
            <link rel="next" href="">
        </div>

        }
    }}
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
        .recognize-quiz { margin-top: 1rem; }
        .recognize-option { display: block; width: 100%; padding: 0.75rem 1rem; margin: 0.5rem 0; border: 1px solid #d1d5db; border-radius: 6px; background: white; cursor: pointer; text-align: left; }
        .recognize-option:hover { border-color: #3b82f6; }
        .recognize-option.correct { border-color: #059669; background: #ecfdf5; }
        .recognize-option.wrong { border-color: #dc2626; background: #fef2f2; }
        .recognize-feedback { margin-top: 0.5rem; font-size: 0.9rem; }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.5rem; border: 1px solid #d1d5db; text-align: left; }
        th { background: #f9fafb; font-weight: 600; }
        ul { margin: 0.5rem 0; padding-left: 1.5rem; }
        li { margin-bottom: 0.25rem; }
        pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
        code { font-family: ui-monospace, monospace; font-size: 0.9em; }
        .toc { position: sticky; top: 2rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb; margin-bottom: 1.5rem; }
        .toc-title { font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #6b7280; margin-bottom: 0.5rem; }
        .toc-list { list-style: none; padding: 0; margin: 0; }
        .toc-list li { margin-bottom: 0.25rem; }
        .toc-list a { color: #374151; text-decoration: none; font-size: 0.85rem; display: block; padding: 0.2rem 0.5rem; border-radius: 4px; }
        .toc-list a:hover { background: #e5e7eb; }
        .back-to-top { position: fixed; bottom: 2rem; right: 2rem; padding: 0.6rem 1rem; background: #1f2937; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 0.85rem; opacity: 0; transition: opacity 0.3s; pointer-events: none; z-index: 50; }
        .back-to-top.visible { opacity: 1; pointer-events: auto; }
        .back-to-top:hover { background: #111827; }
        .reading-controls { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; padding: 0.75rem 1rem; background: #f3f4f6; border-radius: 8px; font-size: 0.85rem; }
        .reading-controls label { display: flex; align-items: center; gap: 0.35rem; }
        .reading-controls select { padding: 0.25rem 0.5rem; border: 1px solid #d1d5db; border-radius: 4px; font-size: 0.85rem; }
        .lesson.font-small { font-size: 0.9rem; }
        .lesson.font-large { font-size: 1.15rem; }
        .lesson.lh-compact p { line-height: 1.4; }
        .lesson.lh-relaxed p { line-height: 2.0; }
        .lesson.ls-tight { letter-spacing: -0.02em; }
        .lesson.ls-loose { letter-spacing: 0.04em; }
        .lesson.w-narrow { max-width: 640px; margin: 0 auto; }
        .lesson.w-wide { max-width: 1100px; margin: 0 auto; }
        .a11y-controls { position: fixed; top: 1rem; left: 1rem; display: flex; gap: 0.35rem; z-index: 60; }
        .a11y-btn { width: 2rem; height: 2rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; font-size: 0.75rem; font-weight: 600; color: #374151; }
        .a11y-btn:hover { background: #f3f4f6; }
        .a11y-btn.active { background: #1f2937; color: white; border-color: #1f2937; }
        .shortcuts-modal { display: none; position: fixed; inset: 0; z-index: 100; }
        .shortcuts-modal.open { display: flex; align-items: center; justify-content: center; }
        .shortcuts-backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); }
        .shortcuts-dialog { position: relative; background: white; border-radius: 8px; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 4px 24px rgba(0,0,0,0.15); }
        .shortcuts-dialog h3 { margin: 0 0 1rem; font-size: 1.1rem; }
        .shortcuts-dialog dl { display: grid; grid-template-columns: auto 1fr; gap: 0.5rem 1rem; }
        .shortcuts-dialog dt { font-family: monospace; }
        .shortcuts-dialog dd { margin: 0; color: #6b7280; }
        .shortcuts-close { margin-top: 1rem; padding: 0.4rem 1rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; }
        kbd { display: inline-block; padding: 0.15rem 0.4rem; border: 1px solid #d1d5db; border-radius: 3px; background: #f9fafb; font-family: monospace; font-size: 0.85em; }
        .lesson.high-contrast { background: #000; color: #fff; }
        .lesson.high-contrast h1, .lesson.high-contrast h2 { color: #ff0; }
        .lesson.high-contrast a { color: #0ff; }
        .lesson.high-contrast code { background: #222; color: #0f0; }
        .lesson.high-contrast .quiz-option { background: #111; color: #fff; border-color: #555; }
        .lesson.reduced-motion *, .lesson.reduced-motion *::before, .lesson.reduced-motion *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
        @media (min-width: 1440px) { .lesson { max-width: 960px; } }
        @media (orientation: portrait) and (max-width: 768px) {
            .lesson { padding: 1rem; }
            .unit { padding: 1rem; }
            h1 { font-size: 1.3rem; }
            .hex-dump { font-size: 0.8rem; padding: 0.75rem; }
            .quiz-option { padding: 0.6rem 0.75rem; font-size: 0.9rem; }

        
        }

        @media (orientation: landscape) and (max-height: 500px) {
            .lesson { padding: 0.75rem 2rem; }
            .unit { padding: 0.75rem 1rem; margin-bottom: 1rem; }
            h1 { font-size: 1.2rem; margin-bottom: 0.5rem; }
        }
        @media (max-width: 480px) {
            .quiz-option { padding: 0.5rem 0.75rem; font-size: 0.85rem; }
            .tf-quiz { flex-direction: column; }
            .tf-option { width: 100%; }
            .match-row { flex-direction: column; align-items: flex-start; gap: 0.25rem; }
            .match-select { min-width: 100%; }
            .order-item { padding: 0.5rem 0.75rem; }
            .sort-item { padding: 0.5rem 0.75rem; }
        }
        .lesson h1 { font-size: clamp(1.3rem, 3vw, 1.8rem); }
        .lesson h2 { font-size: clamp(1rem, 2.5vw, 1.3rem); }
        .lesson p { font-size: clamp(0.9rem, 2vw, 1.05rem); }
        .lesson code { font-size: clamp(0.8rem, 1.8vw, 0.95em); }
        .feedback-rating { display: flex; align-items: center; gap: 0.5rem; margin-top: 0.75rem; padding: 0.5rem 0.75rem; background: #f9fafb; border-radius: 6px; font-size: 0.85rem; }
        .feedback-rating span { color: #6b7280; }
        .feedback-btn { padding: 0.3rem 0.7rem; border: 1px solid #d1d5db; border-radius: 4px; background: white; cursor: pointer; font-size: 0.85rem; }
        .feedback-btn:hover { background: #f3f4f6; }
        .feedback-btn.selected { background: #1f2937; color: white; border-color: #1f2937; }
        .feedback-thanks { color: #059669; font-size: 0.85rem; display: none; }
        .a11y-toast { position: fixed; bottom: 2rem; left: 50%; transform: translateX(-50%); padding: 0.5rem 1rem; background: #1f2937; color: white; border-radius: 6px; font-size: 0.85rem; z-index: 200; opacity: 0; transition: opacity 0.3s; pointer-events: none; }
        .a11y-toast.show { opacity: 1; }
        .hex-dump, pre { touch-action: manipulation; overflow-x: auto; -webkit-overflow-scrolling: touch; max-width: 100%; }
        table { max-width: 100%; overflow-x: auto; display: block; }
        .tap-feedback { transition: background 0.15s; }
        .tap-feedback:active { background: #e5e7eb !important; }
        .swipe-hint { text-align: center; padding: 0.5rem; color: #9ca3af; font-size: 0.8rem; display: none; }
        @media (pointer: coarse) { .swipe-hint { display: block; } }
        .quiz-option, .tf-option, .recognize-option { -webkit-tap-highlight-color: transparent; }
        .quiz-option:active, .tf-option:active { transform: scale(0.98); transition: transform 0.1s; }
        /* 7.3.6: Theme preview */
        .theme-preview-bar { display: flex; gap: 0.5rem; padding: 0.5rem 1rem; background: #f9fafb; border-bottom: 1px solid #e5e7eb; align-items: center; font-size: 0.8rem; }
        .theme-preview-bar label { color: #6b7280; margin-right: 0.25rem; }
        .theme-preview-bar .swatch { width: 20px; height: 20px; border-radius: 4px; border: 2px solid transparent; cursor: pointer; transition: border-color 0.2s; }
        .theme-preview-bar .swatch:hover { border-color: #2563eb; }
        .theme-preview-bar .swatch.active { border-color: #2563eb; box-shadow: 0 0 0 2px rgba(37,99,235,0.3); }
        /* 7.4.13: Responsive visualizations */
        .hex-dump, pre, .elf-dump { max-width: 100%; overflow-x: auto; font-size: 0.85rem; }
        @media (max-width: 640px) { .hex-dump, pre, .elf-dump { font-size: 0.75rem; } }
        @media (max-width: 480px) { .hex-dump, pre, .elf-dump { font-size: 0.7rem; } }
        .vis-container { resize: horizontal; overflow: auto; min-width: 200px; max-width: 100%; border: 1px dashed #d1d5db; padding: 0.5rem; }
        table { font-size: 0.85rem; }
        @media (max-width: 640px) { table { font-size: 0.75rem; } }

        /* 7.1.13-15: Navigation indicators */
        .nav-indicator { position: fixed; top: 0; left: 0; right: 0; z-index: 100; background: white; border-bottom: 1px solid #e5e7eb; padding: 0.5rem 1rem; display: flex; align-items: center; gap: 1rem; font-size: 0.85rem; }
        .nav-progress { flex: 1; height: 4px; background: #e5e7eb; border-radius: 2px; overflow: hidden; }
        .nav-progress-fill { height: 100%; background: #10b981; transition: width 0.3s; border-radius: 2px; }
        .nav-status { display: flex; gap: 0.75rem; align-items: center; }
        .nav-status .indicator { padding: 0.2rem 0.5rem; border-radius: 10px; font-size: 0.75rem; font-weight: 500; }
        .nav-status .mastered { background: #d1fae5; color: #065f46; }
        .nav-status .learning { background: #dbeafe; color: #1e40af; }
        .nav-status .due { background: #fef3c7; color: #92400e; }
        .nav-status .new { background: #e5e7eb; color: #374151; }
        .nav-links { display: flex; gap: 0.5rem; }
        .nav-links a { padding: 0.3rem 0.75rem; border-radius: 4px; text-decoration: none; background: #f3f4f6; color: #374151; font-size: 0.8rem; }
        .nav-links a:hover { background: #e5e7eb; }
        .nav-links a.disabled { opacity: 0.4; pointer-events: none; }
        @media (max-width: 768px) { .nav-indicator { flex-wrap: wrap; } }
            }

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

        function checkRecognize(quizId, btn, correct) {
            var quiz = document.getElementById(quizId);
            var options = quiz.querySelectorAll('.recognize-option');
            var feedback = quiz.querySelector('.recognize-feedback');
            for(var i = 0; i < options.length; i++) { options[i].disabled = true; }
            if(correct) {
                btn.classList.add('correct');
                feedback.textContent = 'Correct! You can read the symbol type, binding, and section from the readelf output.';
                feedback.style.color = '#059669';
            } else {
                btn.classList.add('wrong');
                feedback.textContent = 'Not quite. Look at the FUNC/GLOBAL/DEFAULT fields to determine the type.';
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

        function setFontSize(v) { localStorage.setItem('ulf-font-size', v); applySettings(); }
        function setLineHeight(v) { localStorage.setItem('ulf-line-height', v); applySettings(); }
        function setLetterSpacing(v) { localStorage.setItem('ulf-letter-spacing', v); applySettings(); }
        function setContentWidth(v) { localStorage.setItem('ulf-content-width', v); applySettings(); }
        function applySettings() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.remove('font-small','font-large','lh-compact','lh-relaxed','ls-tight','ls-loose','w-narrow','w-wide');
            var fs = localStorage.getItem('ulf-font-size') || 'medium';
            if(fs === 'small') lesson.classList.add('font-small');
            if(fs === 'large') lesson.classList.add('font-large');
            var lh = localStorage.getItem('ulf-line-height') || 'normal';
            if(lh === 'compact') lesson.classList.add('lh-compact');
            if(lh === 'relaxed') lesson.classList.add('lh-relaxed');
            var ls = localStorage.getItem('ulf-letter-spacing') || 'normal';
            if(ls === 'tight') lesson.classList.add('ls-tight');
            if(ls === 'loose') lesson.classList.add('ls-loose');
            var cw = localStorage.getItem('ulf-content-width') || 'normal';
            if(cw === 'narrow') lesson.classList.add('w-narrow');
            if(cw === 'wide') lesson.classList.add('w-wide');
            var fsEl = document.getElementById('font-size');
            var lhEl = document.getElementById('line-height');
            var lsEl = document.getElementById('letter-spacing');
            var cwEl = document.getElementById('content-width');
            if(fsEl) fsEl.value = fs;
            if(lhEl) lhEl.value = lh;
            if(lsEl) lsEl.value = ls;
            if(cwEl) cwEl.value = cw;
        }
        applySettings();

        function toggleHighContrast() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.toggle('high-contrast');
            localStorage.setItem('ulf-high-contrast', lesson.classList.contains('high-contrast') ? '1' : '0');
            var btn = document.querySelectorAll('.a11y-btn')[0];
            if(btn) btn.classList.toggle('active', lesson.classList.contains('high-contrast'));
        }
        function toggleReducedMotion() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.toggle('reduced-motion');
            localStorage.setItem('ulf-reduced-motion', lesson.classList.contains('reduced-motion') ? '1' : '0');
            var btn = document.querySelectorAll('.a11y-btn')[1];
            if(btn) btn.classList.toggle('active', lesson.classList.contains('reduced-motion'));
        }
        function openShortcuts() { document.getElementById('shortcuts-modal').classList.add('open'); }
        function closeShortcuts() { document.getElementById('shortcuts-modal').classList.remove('open'); }
        (function() {
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            if(localStorage.getItem('ulf-high-contrast') === '1') { lesson.classList.add('high-contrast'); var b = document.querySelectorAll('.a11y-btn')[0]; if(b) b.classList.add('active'); } else { }
            if(localStorage.getItem('ulf-reduced-motion') === '1') { lesson.classList.add('reduced-motion'); var b2 = document.querySelectorAll('.a11y-btn')[1]; if(b2) b2.classList.add('active'); } else { if(window.matchMedia('(prefers-reduced-motion: reduce)').matches) { lesson.classList.add('reduced-motion'); var b3 = document.querySelectorAll('.a11y-btn')[1]; if(b3) b3.classList.add('active'); } else { } }
            document.addEventListener('keydown', function(e) { if(e.key === 'Escape') { closeShortcuts(); } else { } });
        })();

        function showToast(msg) {
            var t = document.getElementById('a11y-toast');
            if(!t) { t = document.createElement('div'); t.id = 'a11y-toast'; t.className = 'a11y-toast'; document.body.appendChild(t); }
            t.textContent = msg;
            t.classList.add('show');
            setTimeout(function() { t.classList.remove('show'); }, 1500);
        }
        document.addEventListener('keydown', function(e) {
            if(e.altKey && e.key === 'c') { e.preventDefault(); toggleHighContrast(); showToast('High contrast toggled'); }
            if(e.altKey && e.key === 'r') { e.preventDefault(); toggleReducedMotion(); showToast('Reduced motion toggled'); }
            if(e.altKey && e.key === '=') { e.preventDefault(); cycleFontSize(); }
        });
        function cycleFontSize() {
            var sizes = ['small','medium','large'];
            var current = localStorage.getItem('ulf-font-size') || 'medium';
            var idx = (sizes.indexOf(current) + 1) % sizes.length;
            var lesson = document.querySelector('.lesson');
            if(!lesson) return;
            lesson.classList.remove('font-small','font-large');
            if(sizes[idx] === 'small') lesson.classList.add('font-small');
            if(sizes[idx] === 'large') lesson.classList.add('font-large');
            localStorage.setItem('ulf-font-size', sizes[idx]);
            var el = document.getElementById('font-size');
            if(el) el.value = sizes[idx];
            showToast('Font size: ' + sizes[idx]);
        }
        function addFeedbackRatings() {
            var feedbacks = document.querySelectorAll('.quiz-feedback, .tf-feedback, .recognize-feedback, .app-feedback, .match-feedback, .fill-feedback');
            for(var i = 0; i < feedbacks.length; i++) {
                var fb = feedbacks[i];
                if(fb.nextElementSibling && fb.nextElementSibling.classList.contains('feedback-rating')) continue;
                var div = document.createElement('div');
                div.className = 'feedback-rating';
                div.innerHTML = '<span>Was this helpful?</span><button class="feedback-btn" onclick="rateFeedback(this, true)">ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ‚Â</button><button class="feedback-btn" onclick="rateFeedback(this, false)">ÃƒÂ°Ã…Â¸Ã¢â‚¬ËœÃ…Â½</button><span class="feedback-thanks">Thanks!</span>';
                fb.parentNode.insertBefore(div, fb.nextSibling);
            }
        }
        function rateFeedback(btn, helpful) {
            var container = btn.parentElement;
            var btns = container.querySelectorAll('.feedback-btn');
            for(var i = 0; i < btns.length; i++) btns[i].disabled = true;
            btn.classList.add('selected');
            container.querySelector('.feedback-thanks').style.display = 'inline';
        }
        addFeedbackRatings();

        (function() {
            var touchStartX = 0;
            var touchStartY = 0;
            var longPressTimer = null;
            document.addEventListener('touchstart', function(e) {
                touchStartX = e.changedTouches[0].screenX;
                touchStartY = e.changedTouches[0].screenY;
                var target = e.target;
                if(target.closest('.quiz-option, .tf-option, .recognize-option')) {
                    longPressTimer = setTimeout(function() { target.style.background = '#dbeafe'; }, 500);
                } else { }
            }, { passive: true });
            document.addEventListener('touchend', function(e) {
                clearTimeout(longPressTimer);
                var dx = e.changedTouches[0].screenX - touchStartX;
                var dy = e.changedTouches[0].screenY - touchStartY;
                if(Math.abs(dx) > 80 && Math.abs(dy) < 40) {
                    if(dx > 0) { var prev = document.querySelector('link[rel="prev"]'); if(prev) { window.location.href = prev.href; } else { } }
                    else { var next = document.querySelector('link[rel="next"]'); if(next) { window.location.href = next.href; } else { } }
                } else { }
            }, { passive: true });
            var hexBlocks = document.querySelectorAll('.hex-dump, pre');
            for(var i = 0; i < hexBlocks.length; i++) {
                var el = hexBlocks[i];
                el.style.touchAction = 'pinch-zoom';
            }
        
        
    

        

        // 7.3.6: Theme preview (live color swatches in top bar)
        (function() {
            var themes = {
                'light': { bg: '#ffffff', text: '#111827', accent: '#2563eb', card: '#f9fafb' },
                'dark': { bg: '#111827', text: '#f9fafb', accent: '#60a5fa', card: '#1f2937' },
                'blue': { bg: '#eff6ff', text: '#1e3a5f', accent: '#3b82f6', card: '#dbeafe' },
                'green': { bg: '#f0fdf4', text: '#14532d', accent: '#22c55e', card: '#dcfce7' }
            };
            var bar = document.createElement('div');
            bar.className = 'theme-preview-bar';
            bar.innerHTML = '<label>Theme:</label>';
            var current = localStorage.getItem('ulf_theme_preview') || 'light';
            var keys = ['light', 'dark', 'blue', 'green'];
            for(var i = 0; i < keys.length; i++) {
                (function(key) {
                    var swatch = document.createElement('div');
                    swatch.className = 'swatch' + (key === current ? ' active' : "");
                    swatch.style.background = themes[key].accent;
                    swatch.title = key;
                    swatch.addEventListener('click', function() {
                        document.querySelectorAll('.theme-preview-bar .swatch').forEach(function(s) { s.classList.remove('active'); });
                        swatch.classList.add('active');
                        localStorage.setItem('ulf_theme_preview', key);
                        applyTheme(key);
                    });
                    bar.appendChild(swatch);
                })(keys[i]);
            }
            document.body.insertBefore(bar, document.body.firstChild);
            function applyTheme(key) {
                var t = themes[key];
                document.documentElement.style.setProperty('--bg', t.bg);
                document.documentElement.style.setProperty('--text', t.text);
                document.documentElement.style.setProperty('--accent', t.accent);
                document.documentElement.style.setProperty('--card', t.card);
                document.body.style.background = t.bg;
                document.body.style.color = t.text;
            }
            applyTheme(current);
        })();

        // 7.4.13: Responsive visualizations (resize hex dumps + tables)
        (function() {
            function makeResponsive() {
                var els = document.querySelectorAll('.hex-dump, pre, table, .elf-dump');
                for(var i = 0; i < els.length; i++) {
                    var el = els[i];
                    if(!el.parentElement || el.parentElement.className.indexOf('vis-container') >= 0) continue;
                    var wrapper = document.createElement('div');
                    wrapper.className = 'vis-container';
                    el.parentNode.insertBefore(wrapper, el);
                    wrapper.appendChild(el);
                }
            }
            if(document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', makeResponsive); }
            else { makeResponsive(); }
            var resizeTimer;
            window.addEventListener('resize', function() {
                clearTimeout(resizeTimer);
                resizeTimer = setTimeout(function() {
                    var els = document.querySelectorAll('.hex-dump, pre');
                    for(var i = 0; i < els.length; i++) {
                        els[i].style.opacity = '0.7';
                        setTimeout(function(el) { el.style.opacity = '1'; }.bind(null, els[i]), 100);
                    }
                }, 250);
            });
        })();

                    }
            var pct = total > 0 ? Math.round((mastered / total) * 100) : 0;
            var status = 'new';
            if(progress[conceptId] && progress[conceptId].status === 'mastered') { status = 'mastered'; }
            else if(progress[conceptId] && progress[conceptId].status === 'learning') { status = 'learning'; }
            else if(dueItems[conceptId]) { status = 'due'; }
            var nav = document.createElement('div');
            nav.className = 'nav-indicator';
            nav.innerHTML = '<div class="nav-progress"><div class="nav-progress-fill" style="width:' + pct + '%"></div></div>' +
                '<div class="nav-status"><span class="indicator ' + status + '">' + status + '</span>' +
                '<span>' + mastered + '/' + total + ' mastered</span></div>' +
                '<div class="nav-links">' +
                (idx > 0 ? '<a href="' + allConcepts[idx-1] + '.html">&larr; Prev</a>' : '<a class="disabled">&larr; Prev</a>') +
                (idx < total - 1 ? '<a href="' + allConcepts[idx+1] + '.html">Next &rarr;</a>' : '<a class="disabled">Next &rarr;</a>') +
                '</div>';
            document.body.insertBefore(nav, document.body.firstChild);
            document.body.style.paddingTop = '50px';
            if(!reviewed[conceptId]) {
                reviewed[conceptId] = Date.now();
                localStorage.setItem('ulf_reviewed', JSON.stringify(reviewed));
            }
            if(!progress[conceptId]) {
                progress[conceptId] = { status: 'learning', firstVisited: Date.now(), lastVisited: Date.now() };
                localStorage.setItem('ulf_progress', JSON.stringify(progress));
            } else {
                progress[conceptId].lastVisited = Date.now();
                localStorage.setItem('ulf_progress', JSON.stringify(progress));
            }
        })();

        // 4.2.16-17: Exercise mistake pattern detection + personalized feedback
        (function() {
            var mistakeLog = JSON.parse(localStorage.getItem('ulf_mistakes') || '{}');
            function logMistake(conceptId, questionText, correctAnswer) {
                if(!mistakeLog[conceptId]) { mistakeLog[conceptId] = []; } else { }
                var exists = false;
                for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                    if(mistakeLog[conceptId][i].q === questionText) { exists = true; break; } else { }
                }
                if(!exists) {
                    mistakeLog[conceptId].push({ q: questionText, a: correctAnswer, count: 1, last: Date.now() });
                } else {
                    for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                        if(mistakeLog[conceptId][i].q === questionText) {
                            mistakeLog[conceptId][i].count++;
                            mistakeLog[conceptId][i].last = Date.now();
                        } else { }
                    }
                }
                localStorage.setItem('ulf_mistakes', JSON.stringify(mistakeLog));
            }
            function getMistakeCount(conceptId, questionText) {
                if(!mistakeLog[conceptId]) { return 0; } else { }
                for(var i = 0; i < mistakeLog[conceptId].length; i++) {
                    if(mistakeLog[conceptId][i].q === questionText) { return mistakeLog[conceptId][i].count; } else { }
                }
                return 0;
            }
            function generateHint(conceptId, questionText, correctAnswer) {
                var count = getMistakeCount(conceptId, questionText);
                if(count >= 3) {
                    return "You have gotten this wrong " + count + " times. Key concept: " + correctAnswer.substring(0, 80) + "...";
                } else if(count >= 2) {
                    return "This is a tricky one. Think about: " + correctAnswer.substring(0, 60);
                } else { return ""; }
            }
            var conceptId = window.location.pathname.split('/').pop().replace('.html', "") || 'unknown';
            document.querySelectorAll('.quiz-option, .tf-option, .recognize-option').forEach(function(btn) {
                btn.addEventListener('click', function() {
                    var isCorrect = btn.dataset.correct === 'true' || btn.classList.contains('correct');
                    var questionEl = btn.closest('.quiz, .true-false, .recognize');
                    if(!isCorrect && questionEl) {
                        var qText = (questionEl.querySelector('h3') || questionEl.querySelector('p') || {}).textContent || "";
                        var correctBtn = questionEl.querySelector('[data-correct="true"], .correct');
                        var correctAns = correctBtn ? correctBtn.textContent : "";
                        logMistake(conceptId, qText, correctAns);
                        var hint = generateHint(conceptId, qText, correctAns);
                        if(hint) {
                            var hintEl = document.createElement('div');
                            hintEl.className = 'mistake-hint';
                            hintEl.style.cssText = 'background:#fef3c7;border:1px solid #f59e0b;padding:0.75rem;border-radius:6px;margin-top:0.5rem;font-size:0.9rem;color:#92400e;';
                            hintEl.textContent = hint;
                            questionEl.appendChild(hintEl);
                        } else { }
                    } else { }
                });
            });
        })()

        // 7.1.10: Quick jump / command palette (Ctrl+K or /)
        (function() {
            var allConcepts = [
                {id:'bytes',title:'Bytes and Binary',module:'Fundamentals'},
                {id:'binary-representation',title:'Binary Representation',module:'Fundamentals'},
                {id:'file-layout',title:'File Layout',module:'Fundamentals'},
                {id:'elf-identification',title:'ELF Identification',module:'ELF Header'},
                {id:'elf-header-fields',title:'ELF Header Fields',module:'ELF Header'},
                {id:'entry-point',title:'Entry Point',module:'ELF Header'},
                {id:'program-header-table',title:'Program Header Table',module:'Program Headers'},
                {id:'segment-types',title:'Segment Types',module:'Program Headers'},
                {id:'memory-mapping',title:'Memory Mapping',module:'Program Headers'},
                {id:'section-header-table',title:'Section Header Table',module:'Sections'},
                {id:'common-sections',title:'Common Sections',module:'Sections'},
                {id:'section-vs-segment',title:'Section vs Segment',module:'Sections'},
                {id:'symbol-table',title:'Symbol Table',module:'Symbols'},
                {id:'binding',title:'Symbol Binding',module:'Symbols'},
                {id:'visibility',title:'Symbol Visibility',module:'Symbols'},
                {id:'relocation-entries',title:'Relocation Entries',module:'Relocations'},
                {id:'relocation-types',title:'Relocation Types',module:'Relocations'},
                {id:'dynamic-relocations',title:'Dynamic Relocations',module:'Relocations'},
                {id:'dynamic-section',title:'Dynamic Section',module:'Dynamic Linking'},
                {id:'shared-libraries',title:'Shared Libraries',module:'Dynamic Linking'}
            ];
            var overlay = document.createElement('div');
            overlay.className = 'quick-jump-overlay';
            overlay.innerHTML = '<div class="quick-jump"><input type="text" placeholder="Jump to concept... (Esc to close)" id="quickJumpInput" /><div class="quick-jump-results" id="quickJumpResults"></div><div class="quick-jump-hint"><kbd>Up/Down</kbd> navigate <kbd>Enter</kbd> go <kbd>Esc</kbd> close</div></div>';
            document.body.appendChild(overlay);
            var input = document.getElementById('quickJumpInput');
            var results = document.getElementById('quickJumpResults');
            var selectedIdx = 0;
            function showResults(query) {
                var q = query.toLowerCase();
                var matches = allConcepts.filter(function(c) { return c.title.toLowerCase().indexOf(q) >= 0 || c.module.toLowerCase().indexOf(q) >= 0 || c.id.indexOf(q) >= 0; });
                results.innerHTML = "";
                selectedIdx = 0;
                for(var i = 0; i < matches.length && i < 8; i++) {
                    var div = document.createElement('div');
                    div.className = 'result' + (i === 0 ? ' selected' : "");
                    div.innerHTML = '<div>' + matches[i].title + '</div><div class="module">' + matches[i].module + '</div>';
                    div.dataset.url = matches[i].id + '.html';
                    div.addEventListener('click', function() { window.location.href = this.dataset.url; });
                    results.appendChild(div);
                }
            }
            function openPalette() { overlay.classList.add('active'); input.value = ""; input.focus(); showResults(""); }
            function closePalette() { overlay.classList.remove('active'); }
            document.addEventListener('keydown', function(e) {
                if((e.ctrlKey && e.key === 'k') || (e.key === '/' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA')) {
                    e.preventDefault(); openPalette();
                }
                if(e.key === 'Escape') { closePalette(); }
                if(overlay.classList.contains('active')) {
                    var items = results.querySelectorAll('.result');
                    if(e.key === 'ArrowDown') { e.preventDefault(); selectedIdx = Math.min(selectedIdx + 1, items.length - 1); items.forEach(function(item, i) { item.classList.toggle('selected', i === selectedIdx); }); }
                    if(e.key === 'ArrowUp') { e.preventDefault(); selectedIdx = Math.max(selectedIdx - 1, 0); items.forEach(function(item, i) { item.classList.toggle('selected', i === selectedIdx); }); }
                    if(e.key === 'Enter' && items[selectedIdx]) { window.location.href = items[selectedIdx].dataset.url; }
                }
            });
            overlay.addEventListener('click', function(e) { if(e.target === overlay) { closePalette(); } });
            input.addEventListener('input', function() { showResults(this.value); });
        })();

        // 7.1.13-15: Navigation indicators (progress, unread, due)
        (function() {
            var allConcepts = ["bytes","binary-representation","file-layout","elf-identification","elf-header-fields","entry-point","program-header-table","segment-types","memory-mapping","section-header-table","common-sections","section-vs-segment","symbol-table","binding","visibility","relocation-entries","relocation-types","dynamic-relocations","dynamic-section","shared-libraries"];
            var conceptId = window.location.pathname.split("/").pop().replace(".html", "") || "bytes";
            var progress = JSON.parse(localStorage.getItem("ulf_progress") || "{}");
            var reviewed = JSON.parse(localStorage.getItem("ulf_reviewed") || "{}");
            var dueItems = JSON.parse(localStorage.getItem("ulf_due") || "{}");
            var idx = allConcepts.indexOf(conceptId);
            var total = allConcepts.length;
            var mastered = 0;
            for(var i = 0; i < total; i++) {
                if(progress[allConcepts[i]] && progress[allConcepts[i]].status === "mastered") { mastered++; }
            }
            var pct = total > 0 ? Math.round((mastered / total) * 100) : 0;
            var status = "new";
            if(progress[conceptId] && progress[conceptId].status === "mastered") { status = "mastered"; }
            else if(progress[conceptId] && progress[conceptId].status === "learning") { status = "learning"; }
            else if(dueItems[conceptId]) { status = "due"; }
            var nav = document.createElement("div");
            nav.className = "nav-indicator";
            nav.innerHTML = "<div class=\"nav-progress\"><div class=\"nav-progress-fill\" style=\"width:" + pct + "%\"></div></div>" +
                "<div class=\"nav-status\"><span class=\"indicator " + status + "\">" + status + "</span>" +
                "<span>" + mastered + "/" + total + " mastered</span></div>" +
                "<div class=\"nav-links\">" +
                (idx > 0 ? "<a href=\"" + allConcepts[idx-1] + ".html\">&larr; Prev</a>" : "<a class=\"disabled\">&larr; Prev</a>") +
                (idx < total - 1 ? "<a href=\"" + allConcepts[idx+1] + ".html\">Next &rarr;</a>" : "<a class=\"disabled\">Next &rarr;</a>") +
                "</div>";
            document.body.insertBefore(nav, document.body.firstChild);
            document.body.style.paddingTop = "50px";
            if(!reviewed[conceptId]) {
                reviewed[conceptId] = Date.now();
                localStorage.setItem("ulf_reviewed", JSON.stringify(reviewed));
            }
            if(!progress[conceptId]) {
                progress[conceptId] = { status: "learning", firstVisited: Date.now(), lastVisited: Date.now() };
                localStorage.setItem("ulf_progress", JSON.stringify(progress));
            } else {
                progress[conceptId].lastVisited = Date.now();
                localStorage.setItem("ulf_progress", JSON.stringify(progress));
            }
        })();
    }

    return page.toString()
}
}