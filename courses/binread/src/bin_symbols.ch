// E6 paid course — concept 4: two symbol tables. Values from readelf_s.txt.
public namespace underlayer_content {

using std::string
using std::string_view

public func render_bin_symbols() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Symbol Tables, Two Jobs — Underlayer")
    page.appendTitle(&title)
    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson binread-lesson">
            <a href="/courses/binread" class="back-link">Back to course</a>
            <h1>Two Symbol Tables, Two Jobs</h1>
            <div class="lesson-meta">18 min &middot; Module 2: The Runtime View &middot; Intermediate</div>

            <div class="unit unit-why" data-remember=".dynsym is the runtime lookup table; .symtab is the full static table and can be stripped away.">
                <h2>Why This Matters</h2>
                <p>A stripped executable can still run. That is only possible because the names the dynamic linker needs live in a different table from the names a debugger would like. Confusing the two leads to looking for a function in <code>.dynsym</code> and concluding it does not exist, or assuming <code>.symtab</code> must be present for loading to work.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <div class="formula">.dynsym   consumed by ld.so at runtime; small; may be stripped? NO
.symtab   consumed by linkers and debuggers; full; may be stripped

Each row: name, value (address), size, type, bind, visibility, section index
Binding:  LOCAL / GLOBAL / WEAK
Visibility: DEFAULT / HIDDEN / PROTECTED / INTERNAL
Ndx:      a section number, UND for undefined, ABS for absolute</div>
                <p>The specimen carries both tables, which makes it a good specimen for seeing the difference rather than being told about it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in the File</h2>
                <div class="hex-dump"><pre>$ readelf -sW types_O0
Symbol table '.dynsym' contains 7 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     1: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.34 (2)
     6: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@GLIBC_2.2.5 (4)

Symbol table '.symtab' contains 43 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
    33: 0000000000001060    38 FUNC    GLOBAL DEFAULT   14 _start
    35: 00000000000011c9   105 FUNC    GLOBAL DEFAULT   14 main
    36: 0000000000004060     0 OBJECT  GLOBAL HIDDEN    25 __TMC_END__</pre></div>
                <p>Seven entries oppose forty-three. The <code>.dynsym</code> rows are mostly undefined imports such as <code>__libc_start_main</code>; the <code>.symtab</code> rows include local file markers, <code>_start</code>, <code>main</code>, and a hidden object. <code>main</code> has value <code>0x11c9</code> and size 105 bytes.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Read</h2>
                <p><code>__TMC_END__</code> is <code>GLOBAL</code> but <code>HIDDEN</code>. Those two fields are not contradictions: global binding controls how a symbol is proposed for resolution inside the link, while hidden visibility controls whether it is exported to another shared object. A reader who stops at "&quot;GLOBAL&quot;" has missed half the answer.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p><a href="/courses/elf/lessons/symbol-table">Symbol Table</a> and <a href="/courses/elf/lessons/visibility">Symbol Visibility</a> give the reference treatment. This course stops at the practical question a hand reader asks: which table am I looking at, and what is this row telling me?</p>
            </div>

            <div class="unit unit-interact">
                <h2>See It</h2>
                <p>Open <code>readelf_s.txt</code>. Count the entries in each table before reading the analysis above. Then find <code>main</code> and read across the row: value, size, type, binding, visibility, section index.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Ask which rows in <code>.dynsym</code> have <code>Ndx = UND</code>. In this specimen they are imports: names the file needs from somewhere else. No row in that table is <code>main</code>, which is why looking for <code>main</code> there tells you nothing about whether <code>main</code> exists.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Which table contains the row for <code>main</code> in this specimen?</p>
                <div class="quiz" id="quiz-bin-symbols-i1" aria-label="Check your understanding">
                    <button class="quiz-option" data-correct="false" data-explain=".dynsym has seven entries here, all imports or runtime plumbing; main is not among them." onclick="checkQuiz('quiz-bin-symbols-i1', this)" aria-label="Option: .dynsym">.dynsym</button>
                    <button class="quiz-option" data-correct="true" data-explain="readelf prints main as entry 35 of .symtab, value 0x11c9, size 105, GLOBAL DEFAULT in section 14." onclick="checkQuiz('quiz-bin-symbols-i1', this)" aria-label="Option: .symtab">.symtab</button>
                    <button class="quiz-option" data-correct="false" data-explain="A stripped file loses .symtab, not .dynsym; the table with main is the one that may be stripped." onclick="checkQuiz('quiz-bin-symbols-i1', this)" aria-label="Option: Neither; main is only in a debug file">Neither; main is only in a debug file</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>
        </div>
    }

    render_lesson_js(&mut page)
    return page.toString()
}
}
