// COFF Course — Module 1: The Relocatable Object
// Concept: the 20-byte IMAGE_FILE_HEADER, field by field, plus machine types.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_file_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The File Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The File Header</h1>
            <div class="lesson-meta">16 min &middot; Module 1: The Relocatable Object &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Seven fields in twenty bytes, and every parser needs all seven before it can read anything else. <code>NumberOfSections</code> says how long the section table is. <code>PointerToSymbolTable</code> says where the symbols are. <code>SizeOfOptionalHeader</code> says whether this file is an object or an image.</p>
                <p>It is a small structure, which means it is easy to get subtly wrong in ways that do not announce themselves. Two of the seven fields are 16-bit and two are 32-bit, the section table starts immediately after, and there is no magic number to catch you.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Read it as three questions, in this order:</p>
                <ol>
                    <li><strong>What am I?</strong> <code>Machine</code> and <code>SizeOfOptionalHeader</code>. The first says which CPU; the second says object or image.</li>
                    <li><strong>What is in the file?</strong> <code>NumberOfSections</code>, <code>PointerToSymbolTable</code>, <code>NumberOfSymbols</code>.</li>
                    <li><strong>When and how was it made?</strong> <code>TimeDateStamp</code> and <code>Characteristics</code>.</li>
                </ol>
                <p>The order matters for one specific reason: <code>SizeOfOptionalHeader</code> is how you know whether the section table starts at offset 20 or at offset <code>20 + SizeOfOptionalHeader</code>. In an object it starts at 20. In a PE image it starts after the optional header. Get this wrong and every section header you read is garbage.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All seven fields, decoded from the bytes of <code>sample_msvc.obj</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Bytes</th><th scope="col">Value</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>2</td><td><code>Machine</code></td><td><code>64 86</code></td><td>0x8664</td><td><code>IMAGE_FILE_MACHINE_AMD64</code></td></tr>
                        <tr><td>0x02</td><td>2</td><td><code>NumberOfSections</code></td><td><code>09 00</code></td><td>9</td><td>section table has 9 records</td></tr>
                        <tr><td>0x04</td><td>4</td><td><code>TimeDateStamp</code></td><td><code>2a a5 b6 6a</code></td><td>0x6AB6A52A</td><td>seconds since the Unix epoch</td></tr>
                        <tr><td>0x08</td><td>4</td><td><code>PointerToSymbolTable</code></td><td><code>48 03 00 00</code></td><td>0x348</td><td>file offset of the symbol table</td></tr>
                        <tr><td>0x0c</td><td>4</td><td><code>NumberOfSymbols</code></td><td><code>1f 00 00 00</code></td><td>31</td><td>18-byte records, aux included</td></tr>
                        <tr><td>0x10</td><td>2</td><td><code>SizeOfOptionalHeader</code></td><td><code>00 00</code></td><td><strong>0</strong></td><td>no optional header: this is an object</td></tr>
                        <tr><td>0x12</td><td>2</td><td><code>Characteristics</code></td><td><code>00 00</code></td><td>0</td><td>none set</td></tr>
                    </tbody>
                </table>
                <p>Every one of those values was decoded independently from the raw bytes and then required to match <code>llvm-readobj --file-headers</code>, which reports <code>SectionCount: 9</code>, <code>PointerToSymbolTable: 0x348</code>, <code>SymbolCount: 31</code> and <code>OptionalHeaderSize: 0</code>. Agreement was required before the table above was written down.</p>
                <p>Three fields deserve more than a table row.</p>
                <p><strong><code>NumberOfSymbols</code> counts aux records.</strong> It is a count of 18-byte <em>slots</em>, not a count of names. A symbol that owns one aux record occupies two slots. Our file has 31 slots and, once you skip past the aux records, far fewer actual names. A parser that treats 31 as "31 symbols" will read 18 bytes of garbage as a symbol and then lose sync. The rule is: read a record, read its <code>NumberOfAuxSymbols</code>, advance by <code>1 + NumberOfAuxSymbols</code> slots.</p>
                <p><strong><code>TimeDateStamp</code> is a Unix timestamp in an otherwise unremarkable little-endian file.</strong> Ours is 0x6AB6A52A. This is not a COFF invention &mdash; it is the same epoch as <a href="/courses/elf/lessons/elf-header-fields">the ELF header</a>, and the same field you saw in the ELF course's own hex dumps. Cross-format consistency is rarer than you would expect, and worth noticing when it happens.</p>
                <p><strong><code>Characteristics</code> is zero here, and that is normal for an object.</strong> This field exists for images, where it carries <code>IMAGE_FILE_EXECUTABLE_IMAGE</code> and <code>IMAGE_FILE_DLL</code>. An object is neither, so it sets none of them. Do not read its emptiness as a missing field.</p>
                <h3>The machine types</h3>
                <p><code>Machine</code> is the field that tells you how wide a pointer is, which changes how you interpret almost everything else. The three targets used in this course:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Name</th><th scope="col">Pointer size</th><th scope="col">Seen in this course</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x014C</td><td><code>IMAGE_FILE_MACHINE_I386</code></td><td>32-bit</td><td><code>sample_m32.obj</code></td></tr>
                        <tr><td>0x8664</td><td><code>IMAGE_FILE_MACHINE_AMD64</code></td><td>64-bit</td><td><code>sample_msvc.obj</code>, <code>sample_gnu.obj</code></td></tr>
                        <tr><td>0xAA64</td><td><code>IMAGE_FILE_MACHINE_ARM64</code></td><td>64-bit</td><td>the PE course's <code>cli-64.exe</code> family</td></tr>
                    </tbody>
                </table>
                <p>Others you will meet in the PE course include 0x01C4 (<code>ARMNT</code>, 32-bit ARM), 0x0200 (<code>IA64</code>, Itanium) and 0xAA64 (<code>ARM64</code>). <code>llvm-readobj</code> prints the address size alongside the machine, which is the quickest sanity check available: a file claiming AMD64 with <code>AddressSize: 32bit</code> is lying to you about something.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Decode the header by hand, then check. Here are the first 20 bytes again, this time with the reading written under each field:</p>
                <div class="hex-dump">
                    <pre>00000000: 6486 0900 2aa5 b66a 4803 0000 1f00 0000
                 |---| |--| |----| |--------| |--------|
                0x8664   9     ts     0x348        31

00000010: 0000 0000
                 |--| |--|
               opt=0  ch=0</pre>
                </div>
                <p>Now the check that proves the field boundaries are right rather than merely plausible. <code>NumberOfSections</code> is 9, so the section table is 9 records of 40 bytes = 360 bytes, running from 0x14 to 0x17C. And 0x17C is exactly where the <code>.text</code> raw data begins, according to the first section header:</p>
                <pre><code>$ xxd -s 0x14 -l 4 sample_msvc.obj
00000014: 2e74 6578                                .tex
$ xxd -s 0x17c -l 8 sample_msvc.obj
0000017c: 50 00 00 00 00 00 00 00                  P.......
$ llvm-readobj --sections sample_msvc.obj | head -8
    Number: 1
    Name: .text (2E 74 65 78 74 00 00 00)
    RawDataSize: 108
    PointerToRawData: 0x17C</code></pre>
                <p>0x14 + 360 = 0x17C. Two independently derived numbers &mdash; the section count times the record size, and the raw data pointer read out of the first section header &mdash; land on the same offset. That is what a correct header looks like.</p>
                <p>Do the same arithmetic for the symbol table: <code>PointerToSymbolTable = 0x348</code> and <code>NumberOfSymbols = 31</code>, so 31 &times; 18 = 558 = 0x22E, putting the end at 0x348 + 0x22E = <strong>0x576</strong>. And 0x576 is where the string table starts &mdash; which is where the <code>file</code> utility's <code>symbol offset=0x348</code> was pointing all along.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ xxd -l 20 sample_msvc.obj
$ llvm-readobj --file-headers sample_msvc.obj
$ file sample_msvc.obj</code></pre>
                <p>Confirm the three cross-checks, because they are the whole habit of this concept:</p>
                <ul>
                    <li><code>0x14 + NumberOfSections &times; 40</code> should equal the <code>PointerToRawData</code> of section 1. For us: 0x14 + 360 = 0x17C.</li>
                    <li><code>PointerToSymbolTable + NumberOfSymbols &times; 18</code> should be where the string table begins. For us: 0x348 + 558 = 0x576.</li>
                    <li><code>SizeOfOptionalHeader</code> should be 0, and byte 0x14 should be the <code>.</code> of <code>.text</code>. If it is not, you are reading the wrong file or the header is corrupt.</li>
                </ul>
                <p>Then see the machine field actually matter:</p>
                <pre><code>$ clang --target=i686-pc-windows-msvc -c sample.c -o sample_m32.obj
$ llvm-readobj --file-headers sample_m32.obj | grep -E 'Machine|AddressSize'</code></pre>
                <p>The same source now reports <code>IMAGE_FILE_MACHINE_I386 (0x14C)</code> and <code>AddressSize: 32bit</code>. Nothing about the container changed; the CPU did.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: <code>NumberOfSymbols</code> is 31 and <code>PointerToSymbolTable</code> is 0x348. Where does the symbol table end, and what begins there?</p>
                <div class="quiz" id="quiz-coff-file-header-1">
                    <button class="quiz-option" data-correct="true" data-explain="31 records of 18 bytes is 558 bytes = 0x22E, so 0x348 + 0x22E = 0x576. The string table follows immediately, and its own first four bytes are its total size, 57, so the file ends exactly at 0x576 + 57 = 1455. Two independent fields agreeing on one boundary is the check." onclick="checkQuiz('quiz-coff-file-header-1', this)">At 0x576, and the string table begins there &mdash; 31 records of 18 bytes is 558, and 0x348 + 558 = 0x576</button>
                    <button class="quiz-option" data-correct="false" data-explain="31 slots is not 31 named symbols, because aux records are counted in NumberOfSymbols too. Dividing by 18 is right, but this answer has not done the arithmetic: 0x348 + 31*18 is 0x576, not 0x336." onclick="checkQuiz('quiz-coff-file-header-1', this)">At 0x336, because NumberOfSymbols counts names and 31 records of 18 bytes is 246 bytes past 0x348</button>
                    <button class="quiz-option" data-correct="false" data-explain="This confuses the symbol table with the section table. NumberOfSections governs the 40-byte section headers, which run from 0x14; PointerToSymbolTable is a completely separate pointer, given explicitly at offset 0x08." onclick="checkQuiz('quiz-coff-file-header-1', this)">There is nothing after the symbol table &mdash; the section table comes next and then the file ends</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a tool that must handle both COFF objects and PE images. You read <code>NumberOfSections = 9</code> and compute that the section table starts at 0x14. On one file that is right; on another every section header is garbage. What is the one field you forgot to consult, and what is the correct rule?</p>
                <div class="quiz" id="quiz-coff-file-header-2">
                    <button class="quiz-option" data-correct="true" data-explain="The section table always follows the optional header, and the optional header's size is exactly what SizeOfOptionalHeader records. For an object that is 20 + 0 = 0x14. For a PE32+ image it is 20 + 240 = 0x104. A tool that hardcodes 0x14 works on every object and fails on every image, which is why it looks correct in testing until someone points it at an exe." onclick="checkQuiz('quiz-coff-file-header-2', this)">SizeOfOptionalHeader. The section table starts at <code>20 + SizeOfOptionalHeader</code>, which is 0x14 for an object but 20 + 240 = 0x104 for a PE32+ image</button>
                    <button class="quiz-option" data-correct="false" data-explain="Machine affects pointer width, so it does change how individual fields are interpreted, but it does not move the section table. The offset of the section table is determined solely by the optional header's size, which is the field that differs between an object and an image." onclick="checkQuiz('quiz-coff-file-header-2', this)">Machine. A 32-bit machine uses 4-byte offsets where a 64-bit machine uses 8, so the section table moves</button>
                    <button class="quiz-option" data-correct="false" data-explain="A large PointerToSymbolTable is normal and does not imply an optional header; the two are independent. In our object the symbol table is at 0x348, well past the section table, and SizeOfOptionalHeader is still 0." onclick="checkQuiz('quiz-coff-file-header-2', this)">PointerToSymbolTable. If it is large, an optional header must be present to push the section table down</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a format that has two variants almost always encodes the discriminator as a size. Prefer computing positions from the file's own numbers over hardcoding them, and the tool works on both variants for free.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <code>IMAGE_FILE_HEADER</code> here is byte-for-byte the structure at offset 0 of a PE executable, which the <a href="/courses/pe/lessons/pe-signature-coff">PE course decodes</a>. Reading the two side by side is the fastest way to see what "PE is COFF plus an optional header" actually means in bytes.</p>
                <p><code>NumberOfSections</code> is a 16-bit field, which is exactly why the format has a second variant, <code>bigobj</code>, for files that would exceed its limits. Module 1 closes with a look at that, and at the one place where a COFF field is more subtle than it appears &mdash; the section characteristics bitfield.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-section-table">The Section Header</a> &mdash; ten fields, forty bytes, and a section that has no bytes in the file at all.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-intro">Previous: Why COFF Exists</a></span>
                <span><a href="/courses/coff/lessons/coff-section-table">Next: The Section Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
