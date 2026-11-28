// E6 paid course — concept 3: reading program headers. Values from readelf_l.txt.
public namespace underlayer_content {

using std::string
using std::string_view

public func render_bin_segments() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What the Loader Actually Maps — Underlayer")
    page.appendTitle(&title)
    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson binread-lesson">
            <a href="/courses/binread" class="back-link">Back to course</a>
            <h1>What the Loader Actually Maps</h1>
            <div class="lesson-meta">18 min &middot; Module 2: The Runtime View &middot; Intermediate</div>

            <div class="unit unit-why" data-remember="PT_INTERP names the loader; PT_LOAD entries describe the mappings; a section absent from every LOAD is not mapped at runtime.">
                <h2>Why This Matters</h2>
                <p>Sections are for linkers. Segments are for the loader. When a program will not start, the section list can look perfect while the mapping is wrong. Reading the program-header table is how you find out what the operating system was actually asked to put in memory.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <div class="formula">PT_PHDR   where the program-header table lives in memory
PT_INTERP path of the interpreter that finishes the load
PT_LOAD   one contiguous mapping: offset, vaddr, filesz, memsz
PT_DYNAMIC runtime linker's own table

p_filesz bytes come from the file
p_memsz - p_filesz extra bytes are zero-filled</div>
                <p>The specimen has fourteen program headers. Four of them are <code>PT_LOAD</code>, which is the mapping the kernel performs. The rest carry instructions or metadata for the loader and the dynamic linker.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in the File</h2>
                <div class="hex-dump"><pre>$ readelf -lW types_O0
There are 14 program headers, starting at offset 64

  Type           Offset   VirtAddr           FileSiz  MemSiz   Flg Align
  PHDR           0x000040 0x0000000000000040 0x000310 0x000310 R   0x8
  INTERP         0x000374 0x0000000000000374 0x00001c 0x00001c R   0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x000000 0x0000000000000000 0x000630 0x000630 R   0x1000
  LOAD           0x001000 0x0000000000001000 0x000241 0x000241 R E 0x1000
  LOAD           0x002000 0x0000000000002000 0x0001b0 0x0001b0 R   0x1000
  LOAD           0x002db8 0x0000000000003db8 0x0002a8 0x0002b0 RW  0x1000
  DYNAMIC        0x002dc8 0x0000000000003dc8 0x0001f0 0x0001f0 RW  0x8</pre></div>
                <p>The last <code>PT_LOAD</code> is the one to study: <code>p_filesz = 0x2a8</code> but <code>p_memsz = 0x2b0</code>. Eight more bytes exist in memory than in the file, and the loader supplies them as zeros. That is the <code>.bss</code> idea expressed as a mapping, not as a section name.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Read</h2>
                <p>The <code>INTERP</code> entry occupies file bytes <code>0x374</code> through <code>0x390</code> (28 bytes). Its contents name <code>/lib64/ld-linux-x86-64.so.2</code>. If that path does not exist on the target system, the kernel can map every <code>PT_LOAD</code> correctly and the program still will not start: the missing interpreter is not a file-format error.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p><a href="/courses/elf/lessons/segment-types">Segment Types</a> explains the constants. <a href="/courses/binread/lessons/bin-symbols">The next step</a> changes question: instead of what the loader maps, it asks what names the linker left in the file.</p>
            </div>

            <div class="unit unit-interact">
                <h2>See It</h2>
                <p>Find the four <code>LOAD</code> rows in <code>readelf_l.txt</code> and group them by flags: <code>R</code>, <code>R E</code>, <code>R</code>, <code>RW</code>. That order is why the first page is readable, the second executable, and the last one writable.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Using only the table above, compute the virtual address of file byte <code>0x1000</code> in the executable mapping. The row says offset <code>0x1000</code> maps to <code>0x1000</code>, so the answer is <code>0x1000</code> — and you got it without running the binary.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Which program header names the program that finishes loading a dynamic executable?</p>
                <div class="quiz" id="quiz-bin-segments-i1" aria-label="Check your understanding">
                    <button class="quiz-option" data-correct="false" data-explain="PT_DYNAMIC is the dynamic linker's own data table; it does not name the interpreter path." onclick="checkQuiz('quiz-bin-segments-i1', this)" aria-label="Option: PT_DYNAMIC">PT_DYNAMIC</button>
                    <button class="quiz-option" data-correct="true" data-explain="PT_INTERP holds the path /lib64/ld-linux-x86-64.so.2 in this specimen, which is the interpreter the kernel starts." onclick="checkQuiz('quiz-bin-segments-i1', this)" aria-label="Option: PT_INTERP">PT_INTERP</button>
                    <button class="quiz-option" data-correct="false" data-explain="PT_PHDR describes where the program-header table itself is mapped; it does not name an interpreter." onclick="checkQuiz('quiz-bin-segments-i1', this)" aria-label="Option: PT_PHDR">PT_PHDR</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>
        </div>
    }

    render_lesson_js(&mut page)
    return page.toString()
}
}
