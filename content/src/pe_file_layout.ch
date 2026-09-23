// PE Course — Concept 2: PE File Layout.
// The full map from byte 0 to the last section, and how it compares to ELF.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_file_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("PE File Layout — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>PE File Layout</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You learned that a PE file begins with MZ and contains a PE signature somewhere later. That is the entry point into the format — not the format itself. Before decoding any single field, you need the whole map: which layers exist, in what order they sit on disk, and where one ends and the next begins.</p>
                <p>Everyone who touches an executable needs this map. The Windows loader walks it in order — DOS header, PE header, section table — and then maps each section's raw bytes into memory. A debugger or disassembler walks it to find code. A packer, a code-signing tool, or a malware analyst rewrites parts of it. If you misplace even one layer — say, you trust a wrong <code>SizeOfOptionalHeader</code> — every section row after it is garbage and the file will not load.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the file as three zones front to back:</p>
                <ol>
                    <li><strong>The compatibility envelope</strong> — the MS-DOS header and stub, bytes 0 up to the PE signature. It exists so 1980s MS-DOS can still run (or politely refuse) the file, and so the NT loader has a fixed place to look: the 4 bytes at offset <code>0x3C</code>.</li>
                    <li><strong>The instruction block</strong> — PE signature, 20-byte COFF header, optional header, and the section table, all contiguous. This block tells the loader everything: where execution starts, where the image prefers to live, how sections align on disk versus in memory, and one 40-byte row per section.</li>
                    <li><strong>The payload</strong> — raw section data: <code>.text</code>, <code>.rdata</code>, <code>.data</code>, and the rest, each located by its own <code>PointerToRawData</code> and padded to <code>FileAlignment</code>.</li>
                </ol>
                <p>The model's missing piece: nothing in the instruction block stores a single master pointer to "the data." Section data is found only through the section table — one row at a time, each row carrying its own file offset. No table, no payload.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The PE specification fixes this order: MS-DOS stub, PE signature, COFF file header, optional header, section headers, then image pages. Here is the exact byte map of a real 64-bit PE (setuptools' <code>cli-64.exe</code>, 14336 bytes, 6 sections):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Layer</th><th scope="col">File range</th><th scope="col">Size</th><th scope="col">What it is</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>MS-DOS header</td><td>0x0000–0x003F</td><td>64</td><td><code>e_magic = MZ</code>; <code>e_lfanew</code> at 0x3C = 0x100</td></tr>
                        <tr><td>MS-DOS stub</td><td>0x0040–0x00FF</td><td>96</td><td>16-bit stub that prints "This program cannot be run in DOS mode."</td></tr>
                        <tr><td>PE signature</td><td>0x0100–0x0103</td><td>4</td><td><code>50 45 00 00</code> — "PE" plus two nulls</td></tr>
                        <tr><td>COFF header</td><td>0x0104–0x0117</td><td>20</td><td>Machine, section count, timestamp, sizes, characteristics</td></tr>
                        <tr><td>Optional header</td><td>0x0118–0x0207</td><td>240 (0xF0)</td><td>Entry point, image base, alignments, subsystem, 16 data directories</td></tr>
                        <tr><td>Section table</td><td>0x0208–0x02F7</td><td>240 (6 × 40)</td><td>One 40-byte row per section</td></tr>
                        <tr><td>Header padding</td><td>0x02F8–0x03FF</td><td>104</td><td>Zeros out to <code>SizeOfHeaders</code> = 0x400</td></tr>
                        <tr><td>.text raw</td><td>0x0400–0x1BFF</td><td>0x1800</td><td>Code; entry point resolves to file 0x1140</td></tr>
                        <tr><td>.rdata raw</td><td>0x1C00–0x2FFF</td><td>0x1400</td><td>Read-only data (imports live here)</td></tr>
                        <tr><td>.data raw</td><td>0x3000–0x31FF</td><td>0x200</td><td>Initialized data</td></tr>
                        <tr><td>.pdata raw</td><td>0x3200–0x33FF</td><td>0x200</td><td>x64 exception table</td></tr>
                        <tr><td>.rsrc raw</td><td>0x3400–0x35FF</td><td>0x200</td><td>Resources</td></tr>
                        <tr><td>.reloc raw</td><td>0x3600–0x37FF</td><td>0x200</td><td>Base relocations; file ends at 0x3800 = 14336</td></tr>
                    </tbody>
                </table>
                <p>Notice the two alignments at work: <code>FileAlignment</code> = 0x200 pads every raw section start on disk (0x400, 0x1C00, 0x3000…), while <code>SectionAlignment</code> = 0x1000 spaces sections in memory (0x1000, 0x3000, 0x5000…). Headers are zero-padded so the first section begins exactly at the 0x400 <code>SizeOfHeaders</code> boundary.</p>
                <p><strong>Compared with ELF:</strong> both formats put headers first and payload last, but the mechanics differ. ELF always has a fixed-size ELF header at byte 0 and finds its tables through explicit pointers (<code>e_phoff</code>, <code>e_shoff</code>) — the section header table often sits at the <em>end</em> of the file. PE has no operative header at byte 0 (that is the DOS layer), its section table is found by arithmetic, not by a pointer field, and it lives inside the header region — immediately after the optional header — never at the end. ELF also has a separate program-header table describing loadable segments; PE has none: the section table plus the optional header's alignment and size fields are the loader's entire map.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Do not assume the section table is at a fixed offset like 0x208. That offset is the <em>result</em> of <code>e_lfanew</code> (0x100) + 4 (signature) + 20 (COFF) + <code>SizeOfOptionalHeader</code> (0xF0). Change any of those and the section table moves. Compute it; never hardcode it.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The whole header region of <code>cli-64.exe</code>, at the layer boundaries:</p>
                <div class="hex-dump">
                    <pre>00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
00000010: b800 0000 0000 0000 4000 0000 0000 0000  ........@.......
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0001 0000  ................
00000100: 5045 0000 6486 0600 e427 6864 0000 0000  PE..d....'hd....
00000110: 0000 0000 f000 2200                       ......".</pre>
                </div>
                <p>Walk-through of the seams:</p>
                <ol>
                    <li>Bytes 0x00–0x3F: DOS header. Bytes at 0x3C are <code>00 01 00 00</code> — little-endian 0x100 — so the instruction block starts at offset 0x100.</li>
                    <li>Bytes 0x40–0xFF: DOS stub, ending in padding zeros. The instruction block begins exactly at 0x100 with <code>50 45 00 00</code>.</li>
                    <li>The COFF header's last field pair reads <code>f000 2200</code>: <code>SizeOfOptionalHeader</code> = 0xF0, so the optional header spans 0x118 to 0x207, and the section table starts at 0x208 — six rows of 40 bytes end at 0x2F8.</li>
                    <li>The first section row's <code>PointerToRawData</code> is 0x400. Bytes 0x2F8–0x3FF are the zero pad, and the payload begins at 0x400. The last section (.reloc) ends at 0x3800, which is exactly the file size — no trailing data.</li>
                </ol>
                <div class="hex-dump">
                    <pre>00000208: 2e74 6578 7400 0000 bc17 0000 0010 0000  .text...........
00000218: 0018 0000 0004 0000 0000 0000 0000 0000  ................
00000228: 0000 0000 2000 0060                      .... ..`.</pre>
                </div>
                <p>That is the first section row: name <code>.text</code>, VirtualSize 0x17BC, VA 0x1000, SizeOfRawData 0x1800, PointerToRawData 0x400, Characteristics 0x60000020. The map and the table agree — that is the whole contract.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Windows executable works. On Linux or macOS, dump the layer boundaries, then let <code>objdump</code> reconstruct the section table for you:</p>
                <pre><code>$ xxd -s 0x100 -l 24 cli-64.exe
00000100: 5045 0000 6486 0600 e427 6864 0000 0000  PE..d....'hd....
00000110: 0000 0000 f000 2200                       ......".

$ objdump -h cli-64.exe
Sections:
Idx Name          Size      VMA               LMA               File off  Algn
  0 .text         000017bc  0000000140001000  0000000140001000  00000400  2**4
  1 .rdata        0000132c  0000000140003000  0000000140003000  00001c00  2**4
  2 .data         00000200  0000000140005000  0000000140005000  00003000  2**4
...</code></pre>
                <p>What to look for: the <em>File off</em> column is <code>PointerToRawData</code> straight from the section table, and every value is a multiple of 0x200 — <code>FileAlignment</code> made visible. The VMA column shows the same sections at 0x1000-spaced addresses — <code>SectionAlignment</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: in what order do a PE file's layers appear on disk?</p>
                <div class="quiz" id="quiz-layout-1">
                    <button class="quiz-option" data-correct="true" data-explain="Correct order: DOS header, DOS stub, PE signature, COFF header, optional header, section table, then raw section data aligned to FileAlignment." onclick="checkQuiz('quiz-layout-1', this)">DOS header, DOS stub, PE signature, COFF header, optional header, section table, section data</button>
                    <button class="quiz-option" data-correct="false" data-explain="That is the ELF order — ELF header, program headers, sections, with the section header table often at the end. PE keeps its section table right after the optional header, never at the end." onclick="checkQuiz('quiz-layout-1', this)">ELF header, program headers, sections, section header table at the end</button>
                    <button class="quiz-option" data-correct="false" data-explain="The section table is not first and not at the end. It sits immediately after the optional header, before any section data." onclick="checkQuiz('quiz-layout-1', this)">Section table first, then DOS header, then section data</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A PE file has <code>e_lfanew</code> = 0x100, <code>SizeOfOptionalHeader</code> = 0xF0, and 6 sections. Where does the section table start, and where does it end?</p>
                <div class="quiz" id="quiz-layout-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x118 is where the optional header starts (0x100 + 4 + 20). The section table comes after the optional header, not at its beginning." onclick="checkQuiz('quiz-layout-2', this)">Starts at 0x118, ends at 0x208</button>
                    <button class="quiz-option" data-correct="true" data-explain="Section table = e_lfanew + 4 (signature) + 20 (COFF) + SizeOfOptionalHeader = 0x100 + 4 + 20 + 0xF0 = 0x208. Six 40-byte rows = 240 bytes, so it ends at 0x208 + 0xF0 = 0x2F8." onclick="checkQuiz('quiz-layout-2', this)">Starts at 0x208, ends at 0x2F8</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x2F8 is where the section table ends, not where it starts. After 0x2F8 comes zero padding out to SizeOfHeaders at 0x400." onclick="checkQuiz('quiz-layout-2', this)">Starts at 0x2F8, ends at 0x400</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every PE offset you compute chains from e_lfanew forward through sizes. None of them are constants.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You now have the map. The instruction block in the middle of that map has two identities: the 20-byte COFF header that PE inherited from the Common Object File Format — the same header that opens every <code>.obj</code> file — and the optional header that only images carry. The headers themselves come next, layer by layer.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-coff-basics">The COFF Heritage</a> — why a Windows executable carries a Unix-lineage object-file header, and what the linker puts in it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-intro">Previous: Why PE Exists</a></span>
                <span><a href="/courses/pe/lessons/pe-coff-basics">Next: The COFF Heritage</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
