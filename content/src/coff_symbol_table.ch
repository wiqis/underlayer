// COFF Course — Module 2: Symbols and Relocations
// Concept: the 18-byte symbol, storage classes, and the aux record layout.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_symbol_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Symbol Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The Symbol Table</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Symbols and Relocations &middot; Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Relocations reference symbols by index, not by name. Symbol 23 is the thing relocation 0 wants the address of. So the symbol table is the vocabulary every relocation in the file is written in, and a reader that mis-parses it produces relocations pointing at the wrong thing.</p>
                <p>It is also the only place in a COFF object that records a section's <em>final size in memory</em>, because the section header's memory fields are all zero. That is a strange responsibility for a symbol table, and it is why the section-definition records inside it matter more than they look.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Eighteen bytes per record, six fields, and one of them is a union with the string table:</p>
                <ol>
                    <li><strong><code>Name</code> (8 bytes)</strong> &mdash; inline, or a string-table offset. Resolved in <a href="/courses/coff/lessons/coff-string-table">the previous concept</a>.</li>
                    <li><strong><code>Value</code> (4 bytes)</strong> &mdash; the symbol's offset within its section. This is the one address a compiler <em>can</em> know, because the section is its own private space for now.</li>
                    <li><strong><code>SectionNumber</code> (2 bytes)</strong> &mdash; 1-based index into the section table. 0 means undefined; 0xFFFE means absolute.</li>
                    <li><strong><code>Type</code> (2 bytes)</strong> &mdash; mostly <code>0</code>, with 0x20 for a function and 0x0 for data.</li>
                    <li><strong><code>StorageClass</code> (1 byte)</strong> &mdash; the field that actually carries meaning. In practice almost everything is 2 (external) or 3 (static).</li>
                    <li><strong><code>NumberOfAuxSymbols</code> (1 byte)</strong> &mdash; how many extra 18-byte slots follow.</li>
                </ol>
                <p>That last field is the one that catches people. <code>NumberOfSymbols</code> counts <em>slots</em>, and a symbol with one aux record takes two. A reader that advances by one record per symbol desynchronises at the first aux record and never recovers.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Our file has <code>NumberOfSymbols = 31</code> slots at 0x348. The first three records, raw:</p>
                <div class="hex-dump">
                    <pre>00000348: 2e74 6578 7400 0000 0000 0000 0100 0000  .text...........
00000358: 0301 6c00 0000 0300 0000 bcbb d609 0100  ..l.............
00000368: 0000 0000 2e64 6174 6100 0000 0000 0000  .....data.......
00000378: 0200 0000 0301 3000 0000 0200 0000 27a4  ......0.......'.
00000388: dad5 0200 0000 0000                      ........</pre>
                </div>
                <p>Read the rows as three 18-byte records. Slot 0 is at 0x348, slot 1 at 0x35A, slot 2 at 0x36C:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Slot</th><th scope="col">At</th><th scope="col"><code>Name</code></th><th scope="col"><code>Value</code></th><th scope="col"><code>Section</code></th><th scope="col"><code>Type</code></th><th scope="col"><code>Storage</code></th><th scope="col">Aux</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>0x348</td><td><code>.text</code></td><td>0</td><td>1</td><td>0</td><td>3 STATIC</td><td>1</td></tr>
                        <tr><td>1</td><td>0x35A</td><td colspan="6"><em>the aux record &mdash; not a symbol</em></td><td>0</td></tr>
                        <tr><td>2</td><td>0x36C</td><td><code>.data</code></td><td>0</td><td>2</td><td>0</td><td>3 STATIC</td><td>1</td></tr>
                    </tbody>
                </table>
                <p>Slot 0 field by field, from the bytes:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Bytes</th><th scope="col">Field</th><th scope="col">Value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>+0</td><td><code>2e 74 65 78 74 00 00 00</code></td><td><code>Name</code></td><td><code>.text</code>, inline</td></tr>
                        <tr><td>+8</td><td><code>00 00 00 00</code></td><td><code>Value</code></td><td>0</td></tr>
                        <tr><td>+12</td><td><code>01 00</code></td><td><code>SectionNumber</code></td><td>1</td></tr>
                        <tr><td>+14</td><td><code>00 00</code></td><td><code>Type</code></td><td>0</td></tr>
                        <tr><td>+16</td><td><code>03</code></td><td><code>StorageClass</code></td><td>3 = <code>STATIC</code></td></tr>
                        <tr><td>+17</td><td><code>01</code></td><td><code>NumberOfAuxSymbols</code></td><td>1 &mdash; one record follows</td></tr>
                    </tbody>
                </table>
                <p>Which is <code>llvm-readobj</code>'s: <code>Name: .text, Value: 0, Section: .text (1), StorageClass: Static (0x3), AuxSymbolCount: 1</code>. And the symbol is <em>not</em> at 0x350 &mdash; the next real symbol, <code>.data</code>, is at <strong>0x36C</strong>. The 18 bytes in between are its aux record. This is the arithmetic that trips readers up: slots 0 and 1 are <code>.text</code> and its aux; slot 2 is <code>.data</code>.</p>
                <h3>What the aux record actually contains</h3>
                <p>The section-definition aux record is 18 bytes, and <strong>its field order is not the one the specification documents.</strong> Here are the bytes for <code>.text</code>:</p>
                <div class="hex-dump">
                    <pre>6c 00 00 00 | 03 00 00 00 | bc bb d6 09 | 01 00 | 00 | 00 | 00 00
 Length         Relocations      CheckSum        Number  Sel   rsvd  Lines</pre>
                </div>
                <p>Read in the order the specification gives &mdash; Length, NumberOfRelocations, NumberOfLinenumbers, CheckSum, Number, Selection &mdash; and you get NumberOfLinenumbers = 0x09D6BBBC = 165,067,708. Absurd. Read it the way the compiler actually emits it, and every field is sensible:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col"><code>.text</code></th><th scope="col"><code>llvm-readobj</code></th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>4</td><td><code>Length</code></td><td>108</td><td><code>Length: 108</code></td></tr>
                        <tr><td>0x04</td><td>4</td><td><code>NumberOfRelocations</code></td><td>3</td><td><code>RelocationCount: 3</code></td></tr>
                        <tr><td>0x08</td><td>4</td><td><code>CheckSum</code></td><td>0x09D6BBBC</td><td><code>Checksum: 0x9D6BBBC</code></td></tr>
                        <tr><td>0x0c</td><td>2</td><td><code>Number</code></td><td>1</td><td><code>Number: 1</code></td></tr>
                        <tr><td>0x0e</td><td>1</td><td><code>Selection</code></td><td>0</td><td><code>Selection: 0x0</code></td></tr>
                        <tr><td>0x10</td><td>2</td><td><code>NumberOfLinenumbers</code></td><td>0</td><td><code>LineNumberCount: 0</code></td></tr>
                    </tbody>
                </table>
                <p><strong>There is independent proof of this ordering that does not depend on believing any tool.</strong> The <code>Number</code> field at 0x0c is defined as the section's 1-based index. Check it against the section number in the owning symbol, for every aux record in every sample:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Symbol's section</th><th scope="col"><code>Number</code> at 0x0c</th><th scope="col">Match</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1 (<code>.text</code>)</td><td>1</td><td>yes</td></tr>
                        <tr><td>2 (<code>.data</code>)</td><td>2</td><td>yes</td></tr>
                        <tr><td>3 (<code>.bss</code>)</td><td>3</td><td>yes</td></tr>
                        <tr><td>4 (<code>.xdata</code>)</td><td>4</td><td>yes</td></tr>
                        <tr><td>5 (<code>.rdata</code>)</td><td>5</td><td>yes</td></tr>
                        <tr><td>6 (<code>.rdata</code>, COMDAT)</td><td>6</td><td>yes</td></tr>
                    </tbody>
                </table>
                <p>All 58 aux records across the five sample objects satisfy that invariant. A layout that placed <code>NumberOfLinenumbers</code> at 0x08 could not produce this coincidence 58 times running. This is the strongest form of evidence available when a specification and a compiler disagree: find a field whose value is <em>constrained by something else in the file</em>, and check it.</p>
                <p>And note the field this settles the earlier question: <code>.bss</code>'s aux record says <code>Length = 4</code>, even though its section header says <code>VirtualSize = 0</code> and <code>SizeOfRawData = 4</code>. <strong>The size <code>.bss</code> will occupy in the linked image is recorded here and nowhere else in the object.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Beyond the section symbols, the ones that matter to relocations. These are the indices relocation records actually reference:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Slot</th><th scope="col">Name</th><th scope="col"><code>Value</code></th><th scope="col">Section</th><th scope="col">Storage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td><code>.text</code></td><td>0</td><td>1</td><td>STATIC</td></tr>
                        <tr><td>2</td><td><code>.data</code></td><td>0</td><td>2</td><td>STATIC</td></tr>
                        <tr><td>4</td><td><code>.bss</code></td><td>0</td><td>3</td><td>STATIC</td></tr>
                        <tr><td>6</td><td><code>.xdata</code></td><td>0</td><td>4</td><td>STATIC</td></tr>
                        <tr><td>8</td><td><code>.rdata</code></td><td>0</td><td>5</td><td>STATIC</td></tr>
                        <tr><td>10</td><td><code>.rdata</code> (COMDAT)</td><td>0</td><td>6</td><td>STATIC</td></tr>
                        <tr><td>12</td><td><code>??_C@_03PLHFFLIH@ptr?$AA@</code></td><td>0</td><td>6</td><td>EXTERNAL</td></tr>
                        <tr><td>15</td><td><code>.pdata</code></td><td>0</td><td>8</td><td>STATIC</td></tr>
                    </tbody>
                </table>
                <p>And the named symbols further down, which is where <code>Value</code> starts to mean something:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Name</th><th scope="col"><code>Value</code></th><th scope="col">Section</th><th scope="col"><code>Type</code></th><th scope="col">Storage</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>add</code></td><td>0</td><td>1 <code>.text</code></td><td>0x0020 function</td><td>EXTERNAL</td></tr>
                        <tr><td><code>call_through</code></td><td>32</td><td>1 <code>.text</code></td><td>0x0020 function</td><td>EXTERNAL</td></tr>
                        <tr><td><code>use</code></td><td><strong>80</strong></td><td>1 <code>.text</code></td><td>0x0020 function</td><td>EXTERNAL</td></tr>
                        <tr><td><code>g_data</code></td><td>0</td><td>2 <code>.data</code></td><td>0</td><td>EXTERNAL</td></tr>
                        <tr><td><code>g_addr</code></td><td>16</td><td>2 <code>.data</code></td><td>0</td><td>EXTERNAL</td></tr>
                        <tr><td><code>table</code></td><td><strong>32</strong></td><td>2 <code>.data</code></td><td>0</td><td>EXTERNAL</td></tr>
                        <tr><td><code>g_str</code></td><td>0</td><td>5 <code>.rdata</code></td><td>0</td><td>EXTERNAL</td></tr>
                    </tbody>
                </table>
                <p><code>use</code> at <strong>80</strong> and <code>table</code> at <strong>32</strong> are the two numbers worth pausing on, because they are the whole "known offset, unknown address" idea made concrete. <code>use</code> is 80 bytes into <code>.text</code> &mdash; the compiler knows that exactly, because it laid the section out itself. What it cannot know is what <code>.text</code>'s address will be after the linker concatenates four object files. So the symbol says "80 bytes into section 1", and the relocation says "add the final address of section 1 to this".</p>
                <p><code>call_through</code> at 32 and <code>use</code> at 80 are 48 bytes apart, which is the compiled size of <code>call_through</code> &mdash; you can measure it directly. And <code>add</code> at 0 through 32 is the other half of the 108-byte <code>.text</code>: 32 for <code>add</code>, 48 for <code>call_through</code>, 20 for <code>use</code>, 8 of padding. The symbol table is a map of the section, and the numbers fit.</p>
                <p>Also note <code>s_data</code> is <strong>absent</strong> from the named list. It is <code>static</code>, so it is emitted as a STATIC symbol at the end of the table, and it has no linker-visible name. That is the difference between storage class 2 and 3 doing real work: EXTERNAL symbols are the ones other object files can refer to, STATIC ones are private to this file.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ llvm-readobj --symbols sample_msvc.obj | head -40
$ xxd -s 0x348 -l 72 sample_msvc.obj</code></pre>
                <p>The exercise worth doing is the one that proves the aux record ordering, because it is the kind of check that catches a wrong assumption permanently:</p>
                <ul>
                    <li>For every symbol with <code>AuxSymbolCount: 1</code> and <code>StorageClass: Static</code>, note its <code>Section: .name (N)</code> and its aux <code>Number:</code>. They must be equal. Ours are, for all nine section symbols.</li>
                    <li>Then check the section header's <code>VirtualSize</code> against the aux <code>Length</code>. For <code>.bss</code> the header says 0 and the aux says 4. The aux is the real number.</li>
                    <li>Finally, count slots rather than names. <code>NumberOfSymbols</code> is 31 but there are far fewer names, because of the aux records.</li>
                </ul>
                <p>And to see the three dialect differences in the same table:</p>
                <pre><code>$ llvm-readobj --symbols sample_m32.obj | grep -A2 'Name: add'
    Name: _add          # i386: leading underscore
$ llvm-readobj --symbols sample_msvc.obj | grep -A2 'Name: add'
    Name: add           # x64: no underscore</code></pre>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: you are walking the symbol table and reach slot 1. What is there, and what mistake have you made if you tried to read it as a symbol?</p>
                <div class="quiz" id="quiz-coff-symbol-table-1">
                    <button class="quiz-option" data-correct="true" data-explain="Slot 0 is the .text symbol with NumberOfAuxSymbols = 1, so it owns slot 1. Reading slot 1 as a symbol shows garbage: the first eight bytes look like a name (6c 00 00 00 03 00 00 00) and its SectionNumber comes out as 0x036c, which is not a section. The rule is: read NumberOfAuxSymbols at offset 17 of each record and advance by 1 + that many slots." onclick="checkQuiz('quiz-coff-symbol-table-1', this)">It is the <code>.text</code> symbol&rsquo;s aux record, not a symbol. You must advance by <code>1 + NumberOfAuxSymbols</code> slots, so the next real symbol is slot 2</button>
                    <button class="quiz-option" data-correct="false" data-explain="Slot 1 is a real 18-byte record, it is just not a symbol. Its fields belong to the section-definition aux record: Length 108, Relocations 3, and so on. Reading it as a symbol does not desynchronise the reader, it just produces a nonsense entry." onclick="checkQuiz('quiz-coff-symbol-table-1', this)">It is a second, unnamed symbol for <code>.text</code> &mdash; COFF stores section symbols twice, once with a name and once without</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the inverse of the actual rule. NumberOfAuxSymbols is a count of extra slots that FOLLOW the symbol, so it tells you how far to skip forward, not how many records precede the current one." onclick="checkQuiz('quiz-coff-symbol-table-1', this)">It is the first byte of the aux record, and you have already consumed it as part of <code>.text</code>&rsquo;s NumberOfAuxSymbols field</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Your linker is asked for the size of <code>.bss</code> in the object it is about to place. It reads the section header, finds <code>VirtualSize = 0</code>, and allocates nothing. The program then corrupts memory at startup. What is the correct source for that size, and why is the section header actively misleading here?</p>
                <div class="quiz" id="quiz-coff-symbol-table-2">
                    <button class="quiz-option" data-correct="true" data-explain="In a relocatable object VirtualSize is 0 in every section, because no section has an address or a load-time size yet - that is a property of the container, not of .bss. The size the linker must allocate is the Length in the section's symbol-table aux record, which is 4. A tool that reads object section headers as if they were image section headers will be wrong about every section, not just .bss." onclick="checkQuiz('quiz-coff-symbol-table-2', this)">The section&rsquo;s aux symbol record, where <code>Length = 4</code>. The section header is misleading because <code>VirtualSize</code> is zero in <em>every</em> section of an object, so it is a container fact and not a statement about <code>.bss</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="SizeOfRawData is 4, which is the right number, but it is a file fact: the bytes a section contributes to the object. It happens to equal the memory size here only because .bss has no initialised content. A section with an initialised tail and a zero-filled tail would have a SizeOfRawData smaller than its memory size, so it is not the field that means allocate-this-much." onclick="checkQuiz('quiz-coff-symbol-table-2', this)">SizeOfRawData in the section header, which is 4 &mdash; the same value the aux record carries, so either source works</button>
                    <button class="quiz-option" data-correct="false" data-explain="There is no separate size-of-image table in a COFF object. That concept belongs to a linked PE image; an object carries no memory layout at all, only the contributions it will make to one." onclick="checkQuiz('quiz-coff-symbol-table-2', this)">The linker should compute it from the sum of the section alignments and the largest symbol value in the section</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a field that is zero because of a container-level invariant is not the same as a field that is zero because the thing is empty. Before trusting a size, find out whether the zero is meaningful or merely structural.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>A symbol's <code>Value</code> is an offset within its section, and the section table is what gives that section meaning. That is the same two-step indirection as a DWARF <code>DW_AT_type</code> reference, and the same lesson: <a href="/courses/dwarf/lessons/dwarf-file-tables">the DWARF file tables</a> resolve a number to a name through a table, and COFF resolves an address to a symbol through one.</p>
                <p>The COFF storage classes are the direct ancestor of the ELF ones you already know. <code>STATIC</code> here is <code>STB_LOCAL</code> in ELF, <code>EXTERNAL</code> is <code>STB_GLOBAL</code>, and the <a href="/courses/elf/lessons/visibility">ELF visibility</a> concept covers what happens when they meet at link time.</p>
                <p>Now the table that consumes all of this. A symbol is a name and a place; a relocation is a question about a byte.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-relocations">Relocations</a> &mdash; ten bytes each, and a second place where the specification and the compiler disagree.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-string-table">Previous: The String Table</a></span>
                <span><a href="/courses/coff/lessons/coff-relocations">Next: Relocations</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
