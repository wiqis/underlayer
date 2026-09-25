// COFF Course — Module 1: The Relocatable Object
// Concept: the 40-byte section header, and the section that has no bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_section_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Section Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The Section Header</h1>
            <div class="lesson-meta">18 min &middot; Module 1: The Relocatable Object &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every byte of code and data in the object belongs to a section, and the section header is the only thing that says where those bytes are, how many there are, and what the linker is supposed to do with them. Forty bytes per section, ten fields, and two of them are the reason a naive reader produces nonsense.</p>
                <p>The trap: COFF section headers carry <em>both</em> a "size in the file" field and a "size in memory" field, and in a relocatable object the memory one is always zero. A reader that expects the memory field to be meaningful &mdash; because in a PE image it is &mdash; will report every section as empty.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Group the ten fields by the question each answers:</p>
                <ol>
                    <li><strong>What am I called?</strong> <code>Name</code> &mdash; eight bytes, and there is an escape hatch for longer names.</li>
                    <li><strong>Where are my bytes?</strong> <code>SizeOfRawData</code> and <code>PointerToRawData</code>. A file offset and a length.</li>
                    <li><strong>Where will I live?</strong> <code>VirtualSize</code> and <code>VirtualAddress</code>. Both zero here, and that is not a bug.</li>
                    <li><strong>What else belongs to me?</strong> <code>PointerToRelocations</code>, <code>NumberOfRelocations</code>, <code>PointerToLinenumbers</code>, <code>NumberOfLinenumbers</code>.</li>
                    <li><strong>How should I be treated?</strong> <code>Characteristics</code>, which is the next concept.</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>Simplified, and the simplification hides the interesting part.</strong> "A section is a named blob of bytes" is true and useless. In a relocatable object a section is better modelled as <em>a named contribution to a future image, plus the instructions for building it</em> &mdash; which is why the header can describe a section whose bytes are not in the file at all, and why the size that really matters lives somewhere else entirely.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The <code>.text</code> section header, at file offset 0x14, all forty bytes:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Bytes</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>+0</td><td>8</td><td><code>Name</code></td><td><code>2e 74 65 78 74 00 00 00</code></td><td><code>.text</code></td></tr>
                        <tr><td>+8</td><td>4</td><td><code>VirtualSize</code></td><td><code>00 00 00 00</code></td><td><strong>0</strong></td></tr>
                        <tr><td>+12</td><td>4</td><td><code>VirtualAddress</code></td><td><code>00 00 00 00</code></td><td><strong>0</strong></td></tr>
                        <tr><td>+16</td><td>4</td><td><code>SizeOfRawData</code></td><td><code>6c 00 00 00</code></td><td>108</td></tr>
                        <tr><td>+20</td><td>4</td><td><code>PointerToRawData</code></td><td><code>7c 01 00 00</code></td><td>0x17C</td></tr>
                        <tr><td>+24</td><td>4</td><td><code>PointerToRelocations</code></td><td><code>e8 01 00 00</code></td><td>0x1E8</td></tr>
                        <tr><td>+28</td><td>4</td><td><code>PointerToLinenumbers</code></td><td><code>00 00 00 00</code></td><td>0</td></tr>
                        <tr><td>+32</td><td>2</td><td><code>NumberOfRelocations</code></td><td><code>03 00</code></td><td>3</td></tr>
                        <tr><td>+34</td><td>2</td><td><code>NumberOfLinenumbers</code></td><td><code>00 00</code></td><td>0</td></tr>
                        <tr><td>+36</td><td>4</td><td><code>Characteristics</code></td><td><code>20 00 50 60</code></td><td>0x60500020</td></tr>
                    </tbody>
                </table>
                <p>Every value was decoded from the raw bytes and then required to match <code>llvm-readobj --sections</code>, which reports <code>VirtualSize: 0x0</code>, <code>VirtualAddress: 0x0</code>, <code>RawDataSize: 108</code>, <code>PointerToRawData: 0x17C</code>, <code>PointerToRelocations: 0x1E8</code>, <code>RelocationCount: 3</code>, <code>LineNumberCount: 0</code> and <code>Characteristics [ (0x60500020)</code>.</p>
                <p>Now the section that makes the two-size distinction unavoidable. Here are <code>.text</code>, <code>.data</code> and <code>.bss</code> side by side, from <code>llvm-readobj</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col"><code>SizeOfRawData</code></th><th scope="col"><code>PointerToRawData</code></th><th scope="col"><code>VirtualSize</code></th><th scope="col">Bytes in the file?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>.text</code></td><td>108</td><td>0x17C</td><td>0</td><td>yes</td></tr>
                        <tr><td><code>.data</code></td><td>48</td><td>0x206</td><td>0</td><td>yes</td></tr>
                        <tr><td><code>.bss</code></td><td>4</td><td><strong>0x0</strong></td><td>0</td><td><strong>no</strong></td></tr>
                    </tbody>
                </table>
                <p><code>.bss</code> claims four bytes, and its raw data pointer is zero. There is nothing to point at, because there is nothing there: the four bytes are uninitialised global storage that the linker will allocate and zero. The section header is describing a region that will exist in the output image and does not exist in this file.</p>
                <p>And note what <code>.bss</code>'s section header does <em>not</em> tell you: how big the region will finally be. <code>SizeOfRawData = 4</code> is a file fact. The memory size is recorded elsewhere &mdash; in the symbol table's aux record, where <code>.bss</code>'s <code>Length</code> is 4. That is the field to read, and it is the subject of <a href="/courses/coff/lessons/coff-symbol-table">the symbol table concept</a>.</p>
                <h3>Names longer than eight bytes</h3>
                <p><code>Name</code> is eight bytes, which is not enough for <code>.llvm_addrsig</code> or any real mangled C++ symbol. The escape hatch: if the first byte is <code>/</code> (<code>0x2f</code>), the remaining seven bytes hold a <strong>decimal</strong> offset into the string table. Our section 9 stores exactly that:</p>
                <div class="hex-dump">
                    <pre>00000154: 2f31 3700 0000 00                        /17.....</pre>
                </div>
                <p>That is <code>/17</code> &mdash; slash, then the ASCII digits one and seven. Offset 17 in the string table is the string <code>.llvm_addrsig</code>. <code>llvm-readobj</code> confirms it: <code>Name: .llvm_addrsig</code>. Module 2 opens the string table properly; the mechanism is all you need here.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Three section headers, straight out of the file, 0x14 through 0x8B:</p>
                <div class="hex-dump">
                    <pre>00000014: 2e74 6578 7400 0000 0000 0000 0000 0000  .text...........
0000001c: 0000 0000 6c00 0000 7c01 0000 e801 0000  ....l...|.......
0000002c: 0000 0000 0300 0000 2000 5060              ........ .P`

0000003c: 2e64 6174 6100 0000 0000 0000 0000 0000  .data...........
0000004c: 3000 0000 0602 0000 3602 0000 0000 0000  0.......6.......
0000005c: 0200 0000 4000 50c0                      ....@.P.

00000064: 2e62 7373 0000 0000 0000 0000 0000 0000  .bss............
0000006c: 0000 0000 0400 0000 0000 0000 0000 0000  ................
0000007c: 0000 0000 0000 0000 8000 30c0              ..............0.</pre>
                </div>
                <p>Read <code>.bss</code> field by field, because it is the instructive one:</p>
                <ol>
                    <li>Offset 0x64: <code>2e 62 73 73 00 00 00 00</code> &mdash; <code>.bss</code>, padded with zeros to eight bytes.</li>
                    <li>Offsets 0x6c and 0x70: eight zero bytes &mdash; <code>VirtualSize</code> 0 and <code>VirtualAddress</code> 0, as everywhere.</li>
                    <li>Offset 0x74: <code>04 00 00 00</code> &mdash; <code>SizeOfRawData = 4</code>. The section is four bytes wide.</li>
                    <li>Offset 0x78: <code>00 00 00 00</code> &mdash; <code>PointerToRawData = 0</code>. <strong>There is no raw data.</strong> A reader that computes <code>PointerToRawData + SizeOfRawData</code> and seeks there lands on the wrong part of the file; a reader that trusts the pointer will happily read four bytes belonging to something else.</li>
                    <li>Offsets 0x7c to 0x83: all zero &mdash; no relocations, no line numbers.</li>
                    <li>Offset 0x84: <code>80 00 30 c0</code> &mdash; <code>Characteristics = 0xC0300080</code>.</li>
                </ol>
                <p>And <code>.text</code>, for contrast: offset 0x24 is <code>6c 00 00 00</code> = 108 bytes, offset 0x28 is <code>7c 01 00 00</code> = 0x17C, and the first eight bytes at 0x17C are:</p>
                <div class="hex-dump">
                    <pre>0000017c: 50 89 54 24 04 89 0c 24                    P.T$...</pre>
                </div>
                <p><code>50</code> is <code>push rax</code>, then <code>89 54 24 04</code> is <code>mov [rsp+4], rdx</code>. That is not your code &mdash; it is the x64 Windows calling convention storing the second argument into the caller's shadow space. It is the first thing the compiler emits for any function, and it is why a COFF object is not a portable artifact: the bytes are for one CPU and one ABI.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ llvm-readobj --sections sample_msvc.obj | head -30
$ llvm-objdump -h sample_msvc.obj</code></pre>
                <p>Three checks worth making on every file you open:</p>
                <ul>
                    <li><strong>Is <code>VirtualSize</code> zero everywhere?</strong> If some are non-zero you are not looking at an object, or you have mis-parsed. In a PE image the same fields carry real values.</li>
                    <li><strong>Is any <code>PointerToRawData</code> zero while <code>SizeOfRawData</code> is not?</strong> That is <code>.bss</code>, and it is legal. It means the bytes are zeros the linker will allocate.</li>
                    <li><strong>Does <code>SizeOfRawData</code> ever end in 0, 8, 10 or 16 rather than 0 mod 4?</strong> It can &mdash; the <code>.rdata</code> sections here are 5 and 4 bytes &mdash; because an object stores exact bytes, not the padded size a linked image needs.</li>
                </ul>
                <p>To see the same fields with real values, compare against an image. The <a href="/courses/pe/lessons/pe-section-table">PE section table</a> has the identical 40-byte structure with non-zero <code>VirtualAddress</code> and <code>VirtualSize</code>, and that difference is the entire content of this concept.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a section header reports <code>SizeOfRawData = 4</code> and <code>PointerToRawData = 0x0</code>. What does the linker do with this section, and where does it find out how big it will finally be?</p>
                <div class="quiz" id="quiz-coff-section-table-1">
                    <button class="quiz-option" data-correct="true" data-explain="A zero raw data pointer with a non-zero size means the bytes are implicit zeros. The linker allocates the space and zero-fills it, which is the entire point of .bss: uninitialised globals cost nothing in the object file. The final size is in the section's aux symbol record, where .bss's Length is 4 - not in the section header, whose SizeOfRawData is only a file fact." onclick="checkQuiz('quiz-coff-section-table-1', this)">It allocates four zero bytes at link time, because a zero pointer with a non-zero size means &quot;implicit zeros&quot;. The final size comes from the symbol table's aux record for that section, not from the section header</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero PointerToRawData does not mean the section is at the start of the file; it means there is no file data to point at. Reading four bytes from offset 0 would read the Machine field of the file header, which is a real and very confusing failure mode." onclick="checkQuiz('quiz-coff-section-table-1', this)">It treats the section as starting at file offset 0 and reads the first four bytes, which is how a section with a null pointer is defined</button>
                    <button class="quiz-option" data-correct="false" data-explain="VirtualSize is 0 for every section in an object, so it cannot be the source of the size. The value that matters is the Length field in the section's aux record, which is why the symbol table is not optional reading even when all you care about is sizes." onclick="checkQuiz('quiz-coff-section-table-1', this)">It reads the size from VirtualSize in the same header, which is 0 here and therefore means the section is empty</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your tool lists the sections of a COFF object so it can show a user what is inside. On <code>sample_msvc.obj</code> it reports that <code>.bss</code> is 0 bytes, and the user says that is wrong because the C source clearly declares <code>int g_bss;</code>. What is the most likely cause, and what is the smallest correct fix?</p>
                <div class="quiz" id="quiz-coff-section-table-2">
                    <button class="quiz-option" data-correct="true" data-explain="In a relocatable object VirtualSize is 0 in every section, so any tool that sizes sections from it reports every section as empty - not just .bss. The correct size for an object is the aux symbol record's Length, which is 4 for .bss, 108 for .text and 48 for .data. VirtualSize only becomes meaningful in a linked image." onclick="checkQuiz('quiz-coff-section-table-2', this)">The tool is sizing sections from <code>VirtualSize</code>, which is zero in every section of an object. Read the aux symbol record's <code>Length</code> instead, or fall back to it when <code>VirtualSize</code> is zero</button>
                    <button class="quiz-option" data-correct="false" data-explain="A zero raw data pointer is normal for .bss and should not be treated as corruption. The value is not corrupt; the tool is simply reading the wrong field. Validating it away would make the tool refuse files it should handle." onclick="checkQuiz('quiz-coff-section-table-2', this)">The tool treats the null <code>PointerToRawData</code> as corruption and skips the section; it should instead report an error for malformed sections</button>
                    <button class="quiz-option" data-correct="false" data-explain="Clang does emit .bss - it is section 3 with SizeOfRawData 4, right there in the section table. The section is present and well formed; the only thing absent is the file bytes, which is the normal and correct representation of uninitialised storage." onclick="checkQuiz('quiz-coff-section-table-2', this)">The compiler did not emit a .bss section because g_bss is uninitialised, so the tool is correct to report nothing</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: when a tool misreports one section, check whether it is reading a field whose meaning differs between the two variants of the format. Here one field is meaningful in a linked image and always zero in an object, and that is enough to break an entire listing.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This 40-byte structure is identical in COFF objects, PE images and DLLs &mdash; the <a href="/courses/pe/lessons/pe-section-table">PE course decodes the same ten fields</a> with real values. The single difference that matters for this concept is that in an image, <code>VirtualAddress</code> and <code>VirtualSize</code> are the loadable truth, and in an object they are placeholders.</p>
                <p>That leaves the last field of the header, and the one place in COFF where a careless bitmask produces a confident wrong answer: <code>Characteristics</code>. Alignment in particular is not a flag list.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-characteristics">Section Characteristics</a> &mdash; and why a value of 5 in the alignment field makes seven different alignment tests pass at once.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-file-header">Previous: The File Header</a></span>
                <span><a href="/courses/coff/lessons/coff-characteristics">Next: Section Characteristics</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
