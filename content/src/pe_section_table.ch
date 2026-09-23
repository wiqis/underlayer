// PE Course — Concept 9: The Section Table.
// 40-byte IMAGE_SECTION_HEADER records, decoded field by field.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_section_table() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Section Table — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Section Table</h1>
            <div class="lesson-meta">15 min · Module 4: Sections · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The section table is the only structure that answers the loader's real question: these bytes on disk become those bytes at which memory address, with what permissions? Without it the image is a flat blob — no way to know where code ends, which pages are writable, where relocations live, or how to run the RVA conversion you just learned. The loader reads nothing else to map the file; tools as different as <code>objdump -h</code>, Windows memory-mapping APIs, and packers that rewrite headers all speak this one structure.</p>
                <p>It is also delightfully small: ten fields, 40 bytes per section, one row per section, sitting at a location you can compute from the bytes at offset 0x3C. Everything about PE layout converges here.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Picture a spreadsheet header followed by one row per section — fixed-width columns, no gaps:</p>
                <pre>0x100  "PE\0\0"          4 bytes   signature
0x104  COFF header      20 bytes  NumberOfSections, SizeOfOptionalHeader
0x118  Optional header  0xF0      entry, base, alignments, 16 directories
0x208  Section table    40 x 6    one row each: .text .rdata .data ...
0x2F8  (headers end)    ...       section data begins at each PointerToRawData</pre>
                <ol>
                    <li><strong>Where it starts:</strong> immediately after the optional header. You do not get a pointer to it — you compute it: <code>e_lfanew + 4 + 20 + SizeOfOptionalHeader</code>. In Sample A that is 0x100 + 4 + 20 + 0xF0 = 0x208.</li>
                    <li><strong>How many rows:</strong> <code>NumberOfSections</code> in the COFF header — 6 in Sample A, 5 in Sample B. The loader caps it at 96.</li>
                    <li><strong>What one row means:</strong> name, memory size, memory base, disk size, disk base, and the Characteristics flags.</li>
                </ol>
                <p>The model's missing piece: two sizes per section that are deliberately different — VirtualSize (memory) and SizeOfRawData (disk) — plus a name field that is not guaranteed to be null-terminated.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's <code>IMAGE_SECTION_HEADER</code>, 40 bytes per entry:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>8</td><td>Name</td><td>Null-padded UTF-8. Exactly 8 characters means no terminator; object files use slash-plus-decimal for long names, but images never do — names over 8 characters are truncated at link time</td></tr>
                        <tr><td>8</td><td>4</td><td>VirtualSize</td><td>Total size of the section once loaded — the true in-memory length</td></tr>
                        <tr><td>12</td><td>4</td><td>VirtualAddress</td><td>First byte of the section relative to ImageBase (the section's RVA base)</td></tr>
                        <tr><td>16</td><td>4</td><td>SizeOfRawData</td><td>Bytes present on disk, rounded up to FileAlignment; may exceed or fall below VirtualSize</td></tr>
                        <tr><td>20</td><td>4</td><td>PointerToRawData</td><td>File offset of the section's first byte; a multiple of FileAlignment</td></tr>
                        <tr><td>24</td><td>4</td><td>PointerToRelocations</td><td>Zero in images — COFF relocations belong to object files only</td></tr>
                        <tr><td>28</td><td>4</td><td>PointerToLinenumbers</td><td>Zero in images; COFF line numbers are deprecated</td></tr>
                        <tr><td>32</td><td>2</td><td>NumberOfRelocations</td><td>Zero in images (images use base relocations in .reloc instead)</td></tr>
                        <tr><td>34</td><td>2</td><td>NumberOfLinenumbers</td><td>Zero in images</td></tr>
                        <tr><td>36</td><td>4</td><td>Characteristics</td><td>Section flags: code/data class plus READ/WRITE/EXECUTE/DISCARDABLE</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Assuming Name is always terminated — eight-character names fill the field completely, and the spec says so explicitly; read at most 8 bytes and stop at a null only if you find one. Assuming VirtualSize equals SizeOfRawData — Sample A .text is 0x17BC in memory but 0x1800 on disk (alignment padding), while .data is 0x648 in memory but only 0x200 on disk (zero-filled tail). And reading the four middle fields at all: in an image they are zero by specification.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first row of Sample A's table — all 40 bytes of <code>.text</code> at file 0x208:</p>
                <div class="hex-dump">
                    <pre>00000208: 2e74 6578 7400 0000 bc17 0000 0010 0000  .text...........
00000218: 0018 0000 0004 0000 0000 0000 0000 0000  ................
00000228: 0000 0000 2000 0060                     .... ..`.</pre>
                </div>
                <p>Field by field, little-endian:</p>
                <ol>
                    <li>Bytes 0-7: <code>2e 74 65 78 74 00 00 00</code> — ASCII <code>.text</code> plus three null pads.</li>
                    <li>Bytes 8-11: <code>bc 17 00 00</code> = 0x17BC — VirtualSize.</li>
                    <li>Bytes 12-15: <code>00 10 00 00</code> = 0x1000 — VirtualAddress, the section's RVA base.</li>
                    <li>Bytes 16-19: <code>00 18 00 00</code> = 0x1800 — SizeOfRawData, padded to 0x200.</li>
                    <li>Bytes 20-23: <code>00 04 00 00</code> = 0x400 — PointerToRawData, where code starts in the file.</li>
                    <li>Bytes 24-35: twelve zero bytes — the four deprecated COFF fields, all zero as the spec requires for images.</li>
                    <li>Bytes 36-39: <code>20 00 00 60</code> = 0x60000020 — Characteristics, decoded next lesson.</li>
                </ol>
                <p>All six rows decoded (names, memory sizes, memory bases, disk sizes, disk bases):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Name</th><th scope="col">VirtualSize</th><th scope="col">VirtualAddress</th><th scope="col">SizeOfRawData</th><th scope="col">PointerToRawData</th><th scope="col">Characteristics</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.text</td><td>0x17BC</td><td>0x1000</td><td>0x1800</td><td>0x0400</td><td>0x60000020</td></tr>
                        <tr><td>.rdata</td><td>0x132C</td><td>0x3000</td><td>0x1400</td><td>0x1C00</td><td>0x40000040</td></tr>
                        <tr><td>.data</td><td>0x0648</td><td>0x5000</td><td>0x0200</td><td>0x3000</td><td>0xC0000040</td></tr>
                        <tr><td>.pdata</td><td>0x01EC</td><td>0x6000</td><td>0x0200</td><td>0x3200</td><td>0x40000040</td></tr>
                        <tr><td>.rsrc</td><td>0x01E0</td><td>0x7000</td><td>0x0200</td><td>0x3400</td><td>0x40000040</td></tr>
                        <tr><td>.reloc</td><td>0x0030</td><td>0x8000</td><td>0x0200</td><td>0x3600</td><td>0x42000040</td></tr>
                    </tbody>
                </table>
                <p>Notice the names: seven bytes or fewer each, so every one fits with a null to spare. The name field is metadata for humans and linkers — the loader never dispatches on it.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Six sections times 40 bytes is 240 bytes of table — dump exactly that:</p>
                <pre><code>$ xxd -s 0x208 -l 240 cli-64.exe
00000208: 2e74 6578 7400 0000 bc17 0000 0010 0000  .text...........
00000218: 0018 0000 0004 0000 0000 0000 0000 0000  ................
00000228: 0000 0000 2000 0060 2e72 6461 7461 0000  .... ..`.rdata..
...

$ objdump -h cli-64.exe
Idx Name          Size      VMA               File off
  0 .text         000017bc  0000000140001000  00000400
  1 .rdata        0000132c  0000000140003000  00001c00</code></pre>
                <p>Walk the table programmatically — 40 bytes a row from offset 0x208:</p>
                <pre><code>$ python3 -c "import struct; d=open('cli-64.exe','rb').read(); [print(d[o:o+8].split(b'\x00')[0].decode(), *[hex(x) for x in struct.unpack_from('&lt;IIII', d, o+8)], hex(struct.unpack_from('&lt;I', d, o+36)[0])) for o in (0x208, 0x230, 0x258, 0x280, 0x2A8, 0x2D0)]"
.text 0x17bc 0x1000 0x1800 0x400 0x60000020
.rdata 0x132c 0x3000 0x1400 0x1c00 0x40000040
.data 0x648 0x5000 0x200 0x3000 0xc0000040
.pdata 0x1ec 0x6000 0x200 0x3200 0x40000040
.rsrc 0x1e0 0x7000 0x200 0x3400 0x40000040
.reloc 0x30 0x8000 0x200 0x3600 0x42000040</code></pre>
                <p>Sample B starts its table at 0x1F8 (PE32 optional header is 0xE0, not 0xF0): same 40-byte layout, five rows, <code>xxd -s 0x1F8 -l 200 cli-32.exe</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: how do you compute where the section table begins, and how many rows does Sample A have?</p>
                <div class="quiz" id="quiz-sec-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x3C holds e_lfanew (the PE signature offset, 0x100 here), not the section table. The table sits after the PE signature, COFF header and optional header — 0x208 in this file." onclick="checkQuiz('quiz-sec-1', this)">Read offset 0x3C — the section table is whatever e_lfanew points to</button>
                    <button class="quiz-option" data-correct="true" data-explain="Follow the chain: e_lfanew 0x100 gives the signature, plus 4 for the signature plus 20 for the COFF header gives the optional header at 0x118, plus SizeOfOptionalHeader 0xF0 puts the table at 0x208 — and NumberOfSections in the COFF header says 6 rows of 40 bytes, ending at 0x2F8." onclick="checkQuiz('quiz-sec-1', this)">e_lfanew + 4 + 20 + SizeOfOptionalHeader = 0x208; NumberOfSections = 6</button>
                    <button class="quiz-option" data-correct="false" data-explain="SizeOfHeaders (0x400) is the FileAlignment-rounded total of DOS stub plus PE header plus section table — it covers the table but is not where the table starts." onclick="checkQuiz('quiz-sec-1', this)">It starts at SizeOfHeaders, file 0x400, one row per directory</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Sample A's <code>.text</code> row reads VirtualSize = 0x17BC and SizeOfRawData = 0x1800. A parser is about to trust only one of them. Which statement is correct?</p>
                <div class="quiz" id="quiz-sec-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x17BC - 0x1800 would be negative. VirtualSize smaller than SizeOfRawData is the normal direction for code sections: the on-disk size is rounded up to FileAlignment 0x200 while the memory size is the exact content length." onclick="checkQuiz('quiz-sec-2', this)">The section is truncated on disk; 0x44 bytes of code are missing</button>
                    <button class="quiz-option" data-correct="false" data-explain="They cannot both be the answer: VirtualSize governs memory extent, SizeOfRawData governs disk extent. The difference is exactly why the RVA span check uses max of the two." onclick="checkQuiz('quiz-sec-2', this)">Either field works — they differ only by endianness</button>
                    <button class="quiz-option" data-correct="true" data-explain="VirtualSize 0x17BC is the true code length in memory; SizeOfRawData 0x1800 is that content rounded up to FileAlignment 0x200, so 0x44 padding bytes follow the code on disk — present in the file, zero at runtime beyond VirtualSize. Disk extent for conversion, memory extent for mapping: both fields, different jobs." onclick="checkQuiz('quiz-sec-2', this)">0x17BC bytes of real content in memory; 0x1800 on disk includes 0x44 bytes of alignment padding</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: memory questions use VirtualSize, disk questions use SizeOfRawData, and any span test uses the larger of the two.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Six rows, six names, six Characteristics values — and you have not yet decoded what <code>0x60000020</code> versus <code>0xC0000040</code> actually permits. Those flags are how the loader decides what is executable, what is writable, and what may be thrown away after relocations are applied.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-common-sections">Common Sections</a> — what .text, .rdata, .data, .pdata, .rsrc and .reloc are for, with every flag bit decoded from real binaries.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-rva-conversion">Previous: Converting RVAs to File Offsets</a></span>
                <span><a href="/courses/pe/lessons/pe-common-sections">Next: Common Sections</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
