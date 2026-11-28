// E6 paid course — concept 2: the header as a map. Values from readelf_h.txt.
public namespace underlayer_content {

using std::string
using std::string_view

public func render_bin_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Header Is a Map — Underlayer")
    page.appendTitle(&title)
    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson binread-lesson">
            <a href="/courses/binread" class="back-link">Back to course</a>
            <h1>The Header Is a Map</h1>
            <div class="lesson-meta">15 min &middot; Module 1: First Look &middot; Intermediate</div>

            <div class="unit unit-why" data-remember="e_phoff and e_shoff are file offsets; multiplying each count by its entry size gives the exact table extent.">
                <h2>Why This Matters</h2>
                <p>A binary is not a stream you read from start to finish. It is a set of tables at declared offsets. The header is the index of those tables. If you can read six fields — two offsets, two entry sizes and two counts — you can jump straight to every structure that matters, without a parser library.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <div class="formula">program headers start at  e_phoff
each entry occupies     e_phentsize bytes
number of entries       e_phnum
so the table occupies   e_phnum * e_phentsize bytes

section headers start at  e_shoff
each entry occupies       e_shentsize bytes
number of entries         e_shnum
so the table occupies     e_shnum * e_shentsize bytes</div>
                <p>The entry sizes are in the header because they can differ between ELF classes. Never assume 56 and 64 from memory: read them from the file you actually have.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Measured, in the File</h2>
                <div class="hex-dump"><pre>$ readelf -h types_O0
  Type:                              DYN (Position-Independent Executable file)
  Machine:                           Advanced Micro Devices X86-64
  Entry point address:               0x1060
  Start of program headers:          64 (bytes into file)
  Start of section headers:          16344 (bytes into file)
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         14
  Size of section headers:           64 (bytes)
  Number of section headers:         37
  Section header string table index: 36</pre></div>
                <p>Apply the model: the program-header table is 14 &times; 56 = 784 bytes starting at file offset 64. The section-header table is 37 &times; 64 = 2368 bytes starting at file offset 16344. Both numbers come from the file, not from a convention.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Worked Read</h2>
                <p><code>e_type</code> is <code>DYN</code> here, so this is a position-independent executable rather than a shared library or a fixed <code>EXEC</code>. Its entry point is <code>0x1060</code>, a virtual address, not a file offset. File offset 64 and virtual address 64 only coincide for the first page in this specimen; do not generalise from that.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p><a href="/courses/elf/lessons/elf-header-fields">ELF Header Fields</a> is the field-by-field reference. The distinction this course adds is the arithmetic: a header field is useful when you turn it into a byte range you can inspect. <a href="/courses/binread/lessons/bin-segments">The next step</a> walks the range the program-header offset points at.</p>
            </div>

            <div class="unit unit-interact">
                <h2>See It</h2>
                <p>With <code>readelf_h.txt</code> open, compute both table extents yourself before reading the program-header dump. Check that 64 + 784 = 848 is well below the first section-header offset of 16344, so the two tables cannot overlap in this specimen.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Do the same six-field read for <code>demo_arm64elf.o</code> in the specimen bundle. The machine field will differ; the method will not. State the program-header table's byte range before looking at anything else.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>In the specimen, how large is the program-header table and where does it start?</p>
                <div class="quiz" id="quiz-bin-header-i1" aria-label="Check your understanding">
                    <button class="quiz-option" data-correct="false" data-explain="64 is e_phoff; 56 is e_phentsize. The table size is their product with the count." onclick="checkQuiz('quiz-bin-header-i1', this)" aria-label="Option: 64 bytes at offset 56">64 bytes at offset 56</button>
                    <button class="quiz-option" data-correct="true" data-explain="14 program headers times 56 bytes each is 784 bytes, starting at file offset 64." onclick="checkQuiz('quiz-bin-header-i1', this)" aria-label="Option: 784 bytes at file offset 64">784 bytes at file offset 64</button>
                    <button class="quiz-option" data-correct="false" data-explain="2368 bytes is 37 section headers times 64 bytes, the section-header table, not the program-header table." onclick="checkQuiz('quiz-bin-header-i1', this)" aria-label="Option: 2368 bytes at file offset 16344">2368 bytes at file offset 16344</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>
        </div>
    }

    render_lesson_js(&mut page)
    return page.toString()
}
}
