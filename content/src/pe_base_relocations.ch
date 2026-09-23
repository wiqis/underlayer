// PE Course — Concept 16: Base Relocations.
// .reloc blocks, type/offset words, DIR64 versus HIGHLOW, and what ASLR needs.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_base_relocations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Base Relocations — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Base Relocations</h1>
            <div class="lesson-meta">15 min · Module 6: Relocations &amp; Hardening · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The linker lays out <code>cli-64.exe</code> as if it will live at <code>0x140000000</code>, and bakes that assumption into every absolute address — pointers in <code>.data</code>, jump tables, vtable slots. But another process may already have claimed <code>0x140000000</code>, and Windows would rather load your image somewhere else. If the loader cannot move those baked-in addresses, it cannot randomize your image, and ASLR — the single most basic exploit mitigation on Windows — is off.</p>
                <p>The base relocation table is the repair list. It records, for each absolute address the linker emitted, the page it sits on and how many bits to patch. The loader computes one number — the difference between where the image wanted to be and where it landed — and adds it to every recorded location. Without this table an image must load at its exact preferred base or not at all: the spec says the loader reports an error when the base address is unavailable and the file has no relocations.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The table is a list of pages, and each page holds a list of tiny instructions:</p>
                <ul>
                    <li><strong>Block header</strong> — the page's RVA (4 bytes) plus the block's total size (4 bytes). One block covers one 4K page and must start on a 32-bit boundary.</li>
                    <li><strong>Entries</strong> — packed 16-bit words: the top 4 bits are the <em>type</em> (how to patch), the low 12 bits are the <em>offset</em> from the page start (where to patch).</li>
                </ul>
                <p>To apply: <code>delta = actual base - preferred base</code>, then for each entry, target = <code>page RVA + offset</code>, and patch according to the type. If the image landed exactly at ImageBase, delta is zero and the loader may skip the work entirely — the spec notes the loader is not required to process relocations unless the image cannot load at its preferred base.</p>
                <p>The model's missing piece: type 0 is not a patch at all. <code>IMAGE_REL_BASED_ABSOLUTE</code> means "skip" — padding to align the next block. A table full of type 0 is normal, not corruption.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Base relocation block header (8 bytes), from the spec's "Base Relocation Block":</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>Page RVA</td><td>Image base plus this page RVA, plus each entry's offset, gives the VA to patch</td></tr>
                        <tr><td>4</td><td>4</td><td>Block Size</td><td>Total bytes in the block, including the header and all type/offset words</td></tr>
                        <tr><td>8</td><td>2 each</td><td>Type/Offset entries</td><td>High 4 bits = type, low 12 bits = offset within the page</td></tr>
                    </tbody>
                </table>
                <p>The relocation types you will actually meet, from the spec's "Base Relocation Types" table:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Constant</th><th scope="col">What it patches</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>IMAGE_REL_BASED_ABSOLUTE</td><td>Skipped — used to pad a block</td></tr>
                        <tr><td>1</td><td>IMAGE_REL_BASED_HIGH</td><td>Adds the high 16 bits of delta to a 16-bit field</td></tr>
                        <tr><td>2</td><td>IMAGE_REL_BASED_LOW</td><td>Adds the low 16 bits of delta to a 16-bit field</td></tr>
                        <tr><td>3</td><td>IMAGE_REL_BASED_HIGHLOW</td><td>Adds all 32 bits of delta to a 32-bit field — the PE32 workhorse</td></tr>
                        <tr><td>4</td><td>IMAGE_REL_BASED_HIGHADJ</td><td>High 16 bits plus a following adjustment word (consumes two slots)</td></tr>
                        <tr><td>10</td><td>IMAGE_REL_BASED_DIR64</td><td>Applies delta to a 64-bit field — the PE32+ workhorse</td></tr>
                    </tbody>
                </table>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Assuming every EXE ships relocations, or that <code>DYNAMIC_BASE</code> alone enables ASLR. The spec explicitly notes that the linker's default behavior is to strip base relocations from executable (EXE) files, and COFF Characteristics bit <code>0x0001</code> (<code>IMAGE_FILE_RELOCS_STRIPPED</code>) is the on-disk record of exactly that: no relocations, must load at the preferred base, loader reports an error otherwise. DllCharacteristics <code>0x0040</code> (<code>DYNAMIC_BASE</code>) promises "this image can be relocated at load time" — a promise it cannot keep without this table. Check both fields, and remember type 3 is a 32-bit patch (PE32) while type 10 is a 64-bit patch (PE32+); mixing them up silently corrupts half an address.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The entire <code>.reloc</code> section of <code>cli-64.exe</code> — data directory index 5 says RVA <code>0x8000</code>, size <code>0x30</code>, and the section header puts it at file offset <code>0x3600</code>:</p>
                <div class="hex-dump">
                    <pre>00003600: 0030 0000 3000 0000 50a2 58a2 60a2 68a2  .0..0...P.X.`.h.
00003610: 70a2 80a2 90a2 a8a2 b0a2 a8a3 b0a3 28a4  p.............(.
00003620: 40a4 48a4 d0a4 e8a4 f0a4 f8a4 00a5 08a5  @.H.............</pre>
                </div>
                <ol>
                    <li><code>0030 0000</code> = <code>0x00003000</code> — Page RVA, the <code>.rdata</code> page.</li>
                    <li><code>3000 0000</code> = <code>0x00000030</code> — Block Size 48 bytes. Header is 8, so <code>(0x30 - 8) / 2</code> = <strong>20 entries</strong>, and the section is exactly this one block.</li>
                    <li>First entry <code>50 a2</code> = word <code>0xA250</code>: high nibble <code>0xA</code> = 10 = <code>IMAGE_REL_BASED_DIR64</code>, low 12 bits = <code>0x250</code>. Patch target RVA = <code>0x3000 + 0x250</code> = <code>0x3250</code>.</li>
                    <li>Last entry <code>08 a5</code> = <code>0xA508</code> → DIR64 at offset <code>0x508</code>, RVA <code>0x3508</code>.</li>
                </ol>
                <p>All twenty entries decode as type 10 — this is a 64-bit image patching 64-bit addresses. The COFF Characteristics of this file are <code>0x0022</code> (EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE): bit <code>0x0001</code> is clear, so relocations were kept, and DllCharacteristics <code>0x8160</code> includes <code>DYNAMIC_BASE</code>. The three facts line up: the binary claims it can move, and the repair list to make that true is present.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump decodes the blocks for you — types, offsets, and the resulting RVAs:</p>
                <pre><code>$ objdump -x cli-64.exe | sed -n '/PE File Base Relocations/,+10p'
PE File Base Relocations (interpreted .reloc section contents)

Virtual Address: 00003000 Chunk size 48 (0x30) Number of fixups 20
	reloc    0 offset  250 [3250] DIR64
	reloc    1 offset  258 [3258] DIR64
	reloc    2 offset  260 [3260] DIR64
	reloc    3 offset  268 [3268] DIR64
	reloc    4 offset  270 [3270] DIR64
	reloc    5 offset  280 [3280] DIR64
	reloc    6 offset  290 [3290] DIR64
	reloc    7 offset  2a8 [32a8] DIR64
	reloc    8 offset  2b0 [32b0] DIR64</code></pre>
                <p>Or decode the block yourself:</p>
                <pre><code>$ python3 -c "
import struct
d=open('cli-64.exe','rb').read()
b=d[0x3600:0x3630]
va,sz=struct.unpack('&lt;II',b[:8])
n=(sz-8)//2
ents=struct.unpack('&lt;'+'H'*n, b[8:])
print(hex(va), hex(sz), 'entries', n, 'first', 'type', ents[0]&gt;&gt;12, 'off', hex(ents[0]&amp;0xfff))"
0x3000 0x30 entries 20 first type 10 off 0x250</code></pre>
                <p>What to look for: does every entry's high nibble match the image's bitness, does <code>(SizeOfBlock - 8)</code> divide evenly by 2, and does the sum of all blocks equal the directory size? A mismatch there means you are looking at corrupted or stripped relocation data.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: decode the relocation word <code>0xA250</code>.</p>
                <div class="quiz" id="quiz-relocs-1">
                    <button class="quiz-option" data-correct="false" data-explain="Type lives in the high 4 bits only. 0x5 is IMAGE_REL_BASED_HIGHLOW's cousin for other machines, not what the high nibble 0xA says." onclick="checkQuiz('quiz-relocs-1', this)">Type 5, offset 0xA250</button>
                    <button class="quiz-option" data-correct="true" data-explain="High 4 bits 0xA = 10 = IMAGE_REL_BASED_DIR64, a 64-bit patch. Low 12 bits 0x250 are the offset within the page, so with Page RVA 0x3000 the target is RVA 0x3250." onclick="checkQuiz('quiz-relocs-1', this)">Type 0xA (DIR64), offset 0x250</button>
                    <button class="quiz-option" data-correct="false" data-explain="Type 3 is IMAGE_REL_BASED_HIGHLOW, the 32-bit PE32 patch. This image is PE32+ and its entries carry type 10." onclick="checkQuiz('quiz-relocs-1', this)">Type 3 (HIGHLOW), offset 0xA250</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A relocation block reports <code>Page RVA = 0x9000</code> and <code>SizeOfBlock = 0x18</code>. How many type/offset entries does it contain, and what is the last entry's page offset range?</p>
                <div class="quiz" id="quiz-relocs-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x18 / 2 counts the whole block as entries and forgets the 8-byte header. Counting from zero overstates every table you parse." onclick="checkQuiz('quiz-relocs-2', this)">12 entries, because 0x18 divided by 2 is 12</button>
                    <button class="quiz-option" data-correct="true" data-explain="The header is 8 bytes: (0x18 - 8) / 2 = 8 entries, occupying block bytes 8 through 0x17. Each 16-bit entry covers one offset in the page starting at 0x9000." onclick="checkQuiz('quiz-relocs-2', this)">8 entries — (0x18 minus 8 header bytes) divided by 2</button>
                    <button class="quiz-option" data-correct="false" data-explain="SizeOfBlock counts header plus entries, not entries times 8. 8-byte entries would describe thunk tables, not 16-bit relocation words." onclick="checkQuiz('quiz-relocs-2', this)">0 entries, because SizeOfBlock only counts the header</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: SizeOfBlock always includes its own 8-byte header. Subtract first, then divide — that one subtraction is the difference between a correct parser and one that reads two garbage entries past every block.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Now that the image can move, the hardening questions begin: did the binary opt into ASLR and DEP? Which subsystem runs it? Is it signed? Those answers live in three small header fields — COFF Characteristics, Subsystem, and DllCharacteristics — plus the certificate table at the end of the file.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-security-flags">Security &amp; Subsystem Flags</a> — every bit that decides how (and whether) Windows will run you.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-delay-loads">Previous: Delay-Load Imports</a></span>
                <span><a href="/courses/pe/lessons/pe-security-flags">Next: Security &amp; Subsystem Flags</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
