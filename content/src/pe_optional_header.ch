// PE Course — Concept 6: The Optional Header.
// Why it is "optional", PE32 vs PE32+ side by side, every major field of both samples.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_optional_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Optional Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Optional Header</h1>
            <div class="lesson-meta">15 min · Module 2: Headers · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The COFF header says <em>what</em> the file is. The optional header says <em>how to load it</em>: where execution begins (<code>AddressOfEntryPoint</code>), where the image prefers to live in memory (<code>ImageBase</code>), how sections align on disk versus in RAM (<code>FileAlignment</code> / <code>SectionAlignment</code>), which window subsystem it needs (console or GUI), and — at its tail — the 16 data directories that locate imports, exports, relocations, and resources. Lose this header and the loader has no instructions; it cannot place a single byte.</p>
                <p>It is also where PE32 and PE32+ genuinely diverge: field widths change (ImageBase grows from 4 bytes to 8), one field disappears (<code>BaseOfData</code>), and the total size shifts from 224 to 240 bytes. Reading these two layouts side by side is how you learn to parse any PE regardless of bitness.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the optional header as the loader's instruction sheet, in three parts:</p>
                <ol>
                    <li><strong>Standard fields</strong> (first 24 bytes in PE32+, 28 in PE32) — the part the specification says is "defined for all implementations of COFF, including UNIX": magic, linker version, the three size fields, entry point, base of code (and base of data in PE32).</li>
                    <li><strong>Windows-specific fields</strong> — image base, both alignments, version numbers, image/header sizes, checksum, subsystem, DllCharacteristics, stack and heap sizes, loader flags, and <code>NumberOfRvaAndSizes</code>.</li>
                    <li><strong>Data directories</strong> — 16 address/size pairs (when <code>NumberOfRvaAndSizes</code> = 16) pointing at the import table, export table, relocations, and so on. That is the next concept.</li>
                </ol>
                <p>Why "optional"? The specification answers directly: the header "is optional in the sense that some files (specifically, object files) do not have it. <strong>For image files, this header is required.</strong>" COFF object files skip it — <code>SizeOfOptionalHeader</code> is zero there. Executables and DLLs cannot.</p>
                <p>The model's missing piece: Magic decides which of two layouts you are parsing. 0x10B means PE32, 0x20B means PE32+ — everything after byte 1 depends on it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Every major field, from Magic through NumberOfRvaAndSizes, with both samples' verified values (A = PE32+ <code>cli-64.exe</code> at file 0x118; B = PE32 <code>cli-32.exe</code> at file 0x118):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">Spec offset (PE32/PE32+)</th><th scope="col">Sample A (PE32+)</th><th scope="col">Sample B (PE32)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Magic</td><td>0</td><td>0x20B — PE32+</td><td>0x10B — PE32</td></tr>
                        <tr><td>Major/MinorLinkerVersion</td><td>2 / 3</td><td>14.36</td><td>14.36</td></tr>
                        <tr><td>SizeOfCode</td><td>4</td><td>0x1800</td><td>0x1600</td></tr>
                        <tr><td>SizeOfInitializedData</td><td>8</td><td>0x2200</td><td>0x1600</td></tr>
                        <tr><td>SizeOfUninitializedData</td><td>12</td><td>0</td><td>0</td></tr>
                        <tr><td>AddressOfEntryPoint</td><td>16</td><td>0x1D40</td><td>0x1B87</td></tr>
                        <tr><td>BaseOfCode</td><td>20</td><td>0x1000</td><td>0x1000</td></tr>
                        <tr><td>BaseOfData</td><td>24 (PE32 only)</td><td><em>absent — field does not exist</em></td><td>0x3000</td></tr>
                        <tr><td>ImageBase</td><td>28 / 24 (4 or 8 bytes)</td><td>0x140000000 (8 bytes)</td><td>0x00400000 (4 bytes)</td></tr>
                        <tr><td>SectionAlignment</td><td>32 / 32</td><td>0x1000</td><td>0x1000</td></tr>
                        <tr><td>FileAlignment</td><td>36 / 36</td><td>0x200</td><td>0x200</td></tr>
                        <tr><td>MajorSubsystemVersion</td><td>48 / 48</td><td>6</td><td>6</td></tr>
                        <tr><td>SizeOfImage</td><td>56 / 56</td><td>0x9000</td><td>0x7000</td></tr>
                        <tr><td>SizeOfHeaders</td><td>60 / 60</td><td>0x400</td><td>0x400</td></tr>
                        <tr><td>Subsystem</td><td>68 / 68</td><td>3 — WINDOWS_CUI (console)</td><td>3 — WINDOWS_CUI (console)</td></tr>
                        <tr><td>DllCharacteristics</td><td>70 / 70</td><td>0x8160</td><td>0x8140</td></tr>
                        <tr><td>NumberOfRvaAndSizes</td><td>92 / 108</td><td>16 (file offset 0x184)</td><td>16 (file offset 0x174)</td></tr>
                        <tr><td><strong>Total header size</strong></td><td>—</td><td><strong>0xF0 (240)</strong></td><td><strong>0xE0 (224)</strong></td></tr>
                    </tbody>
                </table>
                <p><strong>Subsystem</strong>, from the spec: 2 = <code>IMAGE_SUBSYSTEM_WINDOWS_GUI</code> (graphical), 3 = <code>IMAGE_SUBSYSTEM_WINDOWS_CUI</code> (character/console). Both our samples are 3 — they are console tools, which is why <code>file</code> reports "(console)".</p>
                <p><strong>DllCharacteristics 0x8160</strong> (Sample A), decomposed against the spec's DLL Characteristics flags:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Bit</th><th scope="col">Flag</th><th scope="col">In A (0x8160)</th><th scope="col">In B (0x8140)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x0020</td><td>HIGH_ENTROPY_VA — high-entropy 64-bit VA space</td><td>yes</td><td>no</td></tr>
                        <tr><td>0x0040</td><td>DYNAMIC_BASE — relocatable at load time (ASLR)</td><td>yes</td><td>yes</td></tr>
                        <tr><td>0x0100</td><td>NX_COMPAT — DEP/NX compatible</td><td>yes</td><td>yes</td></tr>
                        <tr><td>0x8000</td><td>TERMINAL_SERVER_AWARE</td><td>yes</td><td>yes</td></tr>
                    </tbody>
                </table>
                <p>0x0020 | 0x0040 | 0x0100 | 0x8000 = 0x8160 exactly; Sample B drops only HIGH_ENTROPY_VA (0x8140), which makes sense — a PE32 image does not manage a 64-bit high-entropy address space.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Taking "optional" literally for executables. In an image this header is mandatory — the name survives from object files, where COFF really does omit it (<code>SizeOfOptionalHeader</code> = 0). Another trap: reading DllCharacteristics 0x8160 with the COFF Characteristics table from the previous concept. Different field, different flags: 0x0020 here is HIGH_ENTROPY_VA, but in the COFF header 0x0020 was LARGE_ADDRESS_AWARE. Always know which header you are standing in.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Sample A's optional header, first 80 bytes from file offset 0x118:</p>
                <div class="hex-dump">
                    <pre>00000118: 0b02 0e24 0018 0000 0022 0000 0000 0000  ...$....."......
00000128: 401d 0000 0010 0000 0000 0040 0100 0000  @..........@....
00000138: 0010 0000 0002 0000 0600 0000 0000 0000  ................
00000148: 0600 0000 0000 0000 0090 0000 0004 0000  ................
00000158: 0000 0000 0300 6081 0000 1000 0000 0000  ......`.........</pre>
                </div>
                <p>Walk every major field:</p>
                <ol>
                    <li>0x118: <code>0b 02</code> → 0x20B → PE32+. From here on, parse with the 64-bit layout: ImageBase is 8 bytes, no BaseOfData.</li>
                    <li>0x11A: <code>0e 24</code> → linker 14.36. 0x11C: <code>00 18 00 00</code> → SizeOfCode 0x1800 — matches <code>.text</code>'s SizeOfRawData.</li>
                    <li>0x128: <code>40 1d 00 00</code> → AddressOfEntryPoint 0x1D40 (RVA). <code>.text</code> has VA 0x1000 at file 0x400, so file offset = 0x400 + (0x1D40 − 0x1000) = 0x1140 — and the bytes there are <code>48 83 ec 28</code> (sub rsp, 0x28): the first instruction Windows executes.</li>
                    <li>0x130: <code>00 00 00 40 01 00 00 00</code> → 8-byte little-endian ImageBase 0x140000000 — the preferred load address. (Sample B's 4-byte field reads <code>00 00 40 00</code> → 0x00400000, the classic 32-bit default.)</li>
                    <li>0x138: SectionAlignment 0x1000; 0x13C: FileAlignment 0x200 — the two rulers of PE geometry.</li>
                    <li>0x15C: <code>03 00</code> → Subsystem 3 → console. 0x15E: <code>60 81</code> → 0x8160 → the four DllCharacteristics flags decoded above.</li>
                </ol>
                <p>Bytes past the ones above hold stack/heap sizes (each 0x100000 reserve, 0x1000 commit), LoaderFlags = 0, then <code>NumberOfRvaAndSizes</code> = 16 at file offset 0x184 — the gate to the 16 data directories that start at 0x188.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Let <code>objdump</code> read the optional header for you — these are its real lines for Sample A:</p>
                <pre><code>$ objdump -x cli-64.exe | grep -E 'Magic|AddressOfEntry|Subsystem|DllChar|Alignment'
Magic			020b	(PE32+)
AddressOfEntryPoint	0000000000001d40
SectionAlignment	00001000
FileAlignment		00000200
Subsystem		00000003	(Windows CUI)
DllCharacteristics	00008160</code></pre>
                <p>Now hex-dump the raw bytes and find Magic yourself:</p>
                <pre><code>$ xxd -s 0x118 -l 48 cli-64.exe
00000118: 0b02 0e24 0018 0000 0022 0000 0000 0000  ...$....."......
00000128: 401d 0000 0010 0000 0000 0040 0100 0000  @..........@....
00000138: 0010 0000 0002 0000 0600 0000 0000 0000  ................</code></pre>
                <p>What to look for: the first two bytes (<code>0b 02</code> = 0x20B) pick the layout before you read anything else, and every field you just saw in <code>objdump</code> is sitting at its spec offset in that dump — Magic at 0, entry point at 16 (<code>40 1d 00 00</code>), SectionAlignment at 32.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: why is this header called "optional," and when is it actually optional?</p>
                <div class="quiz" id="quiz-opt-1">
                    <button class="quiz-option" data-correct="true" data-explain="The name comes from object files: COFF .obj files do not carry this header (SizeOfOptionalHeader = 0). For images — EXEs and DLLs — the specification says the header is required." onclick="checkQuiz('quiz-opt-1', this)">Because object files omit it; in images it is required</button>
                    <button class="quiz-option" data-correct="false" data-explain="DLLs are images too — they must carry the optional header, entry point or not. Only object files skip it." onclick="checkQuiz('quiz-opt-1', this)">Because DLLs can omit it when they have no entry point</button>
                    <button class="quiz-option" data-correct="false" data-explain="PE32+ images have the header exactly like PE32 — Magic 0x20B vs 0x10B only changes field widths, not presence." onclick="checkQuiz('quiz-opt-1', this)">Because 64-bit PE32+ files do not need it</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Sample A's DllCharacteristics is 0x8160. Which flags are set?</p>
                <div class="quiz" id="quiz-opt-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x8160 contains no 0x0080 bit — FORCE_INTEGRITY is not set. Adding it would give 0x81E0, not 0x8160." onclick="checkQuiz('quiz-opt-2', this)">DYNAMIC_BASE, NX_COMPAT, FORCE_INTEGRITY, TERMINAL_SERVER_AWARE</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x8160 = 0x8000 TERMINAL_SERVER_AWARE | 0x0100 NX_COMPAT | 0x0040 DYNAMIC_BASE | 0x0020 HIGH_ENTROPY_VA. Sum: 0x8000+0x0100+0x0040+0x0020 = 0x8160." onclick="checkQuiz('quiz-opt-2', this)">HIGH_ENTROPY_VA, DYNAMIC_BASE, NX_COMPAT, TERMINAL_SERVER_AWARE</button>
                    <button class="quiz-option" data-correct="false" data-explain="GUARD_CF is 0x4000 — not present in 0x8160. The 0x8000 bit is TERMINAL_SERVER_AWARE, and 0x0020 here is HIGH_ENTROPY_VA (this is DllCharacteristics, not the COFF table)." onclick="checkQuiz('quiz-opt-2', this)">HIGH_ENTROPY_VA, DYNAMIC_BASE, GUARD_CF, TERMINAL_SERVER_AWARE</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: Magic chooses the layout, entry point names the first instruction, alignments rule the geometry, Subsystem picks the window type, DllCharacteristics grades the hardening — and NumberOfRvaAndSizes unlocks the data directories.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The optional header ends by telling you how many data directories follow — 16 in both samples — and each directory is an address/size pair pointing at a table the loader or the OS needs: imports, exports, relocations, resources, and twelve more. That address book is the next layer of the format.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-data-directories">The Data Directories</a> — the 16 slots, what each one locates, and how the loader uses them before your first line of code runs.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-signature-coff">Previous: PE Signature and COFF Header</a></span>
                <span><a href="/courses/pe/lessons/pe-data-directories">Next: The Data Directories</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
