// PE Course — Concept 5: PE Signature and COFF Header.
// Verifying PE\0\0, decoding all 20 COFF bytes of both samples, Characteristics flags.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_signature_coff() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("PE Signature and COFF Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>PE Signature and COFF Header</h1>
            <div class="lesson-meta">15 min · Module 2: Headers · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Follow <code>e_lfanew</code> and the first thing you meet is a 4-byte signature: <code>50 45 00 00</code> — the letters P, E, then two null bytes. The specification fixes it exactly: the signature "is <code>PE\0\0</code>". This is the moment Windows stops seeing a 1980s DOS file and starts seeing a modern image. Right behind it, the 20-byte COFF header answers the loader's first real questions: which CPU, how many sections, executable or DLL, 32-bit machine or not?</p>
                <p>Every PE parser in existence — <code>objdump</code>, <code>dumpbin</code>, debuggers, signature checkers, packers — makes the same two checks in the same order: find MZ, find PE, then decode these 20 bytes. If you can read this layer by hand, you can confirm what any tool claims about a binary.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Picture a checkpoint with two documents:</p>
                <ul>
                    <li><strong>The signature</strong> is a one-line password — <code>PE\0\0</code>, four bytes, no negotiation. Wrong bytes, wrong file type; the loader stops here.</li>
                    <li><strong>The COFF header</strong> is the ID card: Machine says who you are (i386, x64, ARM64), NumberOfSections says how big the section table is, SizeOfOptionalHeader says how many bytes of loader instructions follow, and Characteristics is a bitfield of verdicts — runnable? DLL? 32-bit? large-address-aware?</li>
                </ul>
                <p>Everything else in the header region — optional header, section table — is positioned by arithmetic from these 20 bytes: signature (4) + COFF (20) + <code>SizeOfOptionalHeader</code>. The COFF header stores no pointer to the section table; its size field <em>is</em> the pointer.</p>
                <p>The model's missing piece: Characteristics is not a single meaning but independent flags OR-ed together, and the same hex value means nothing until you decompose it against the specification's flag table.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Both sample files, signature + COFF header, verbatim — Sample A (PE32+ x64, <code>cli-64.exe</code>) and Sample B (PE32 i386, <code>cli-32.exe</code>), each dumped from file offset 0x100:</p>
                <div class="hex-dump">
                    <pre>A: 00000100: 5045 0000 6486 0600 e427 6864 0000 0000  PE..d....'hd....
A: 00000110: 0000 0000 f000 2200                       ......".

B: 00000100: 5045 0000 4c01 0500 da27 6864 0000 0000  PE..L....'hd....
B: 00000110: 0000 0000 e000 0201                       ........</pre>
                </div>
                <p>Full decode — signature at 0x100, then the seven COFF fields at 0x104:</p>
                <table>
                    <thead>
                        <tr><th scope="col">COFF field</th><th scope="col">Off</th><th scope="col">Sample A bytes</th><th scope="col">Sample A value</th><th scope="col">Sample B bytes</th><th scope="col">Sample B value</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Machine</td><td>0x104</td><td><code>64 86</code></td><td>0x8664 — x64</td><td><code>4c 01</code></td><td>0x014C — i386</td></tr>
                        <tr><td>NumberOfSections</td><td>0x106</td><td><code>06 00</code></td><td>6</td><td><code>05 00</code></td><td>5</td></tr>
                        <tr><td>TimeDateStamp</td><td>0x108</td><td><code>e4 27 68 64</code></td><td>0x646827E4</td><td><code>da 27 68 64</code></td><td>0x646827DA</td></tr>
                        <tr><td>PointerToSymbolTable</td><td>0x10C</td><td><code>00 00 00 00</code></td><td>0</td><td><code>00 00 00 00</code></td><td>0</td></tr>
                        <tr><td>NumberOfSymbols</td><td>0x110</td><td><code>00 00 00 00</code></td><td>0</td><td><code>00 00 00 00</code></td><td>0</td></tr>
                        <tr><td>SizeOfOptionalHeader</td><td>0x114</td><td><code>f0 00</code></td><td>0x00F0 (240 — PE32+)</td><td><code>e0 00</code></td><td>0x00E0 (224 — PE32)</td></tr>
                        <tr><td>Characteristics</td><td>0x116</td><td><code>22 00</code></td><td>0x0022</td><td><code>02 01</code></td><td>0x0102</td></tr>
                    </tbody>
                </table>
                <p><strong>Characteristics, decoded against the specification's flag table.</strong> The defined flags near our values: 0x0001 RELOCS_STRIPPED, <strong>0x0002 EXECUTABLE_IMAGE</strong> ("the image file is valid and can be run… if this flag is not set, it indicates a linker error"), <strong>0x0020 LARGE_ADDRESS_AWARE</strong> ("application can handle greater than 2-GB addresses"), <strong>0x0100 32BIT_MACHINE</strong> ("machine is based on a 32-bit-word architecture"), 0x2000 DLL. Now the OR:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Sample</th><th scope="col">Value</th><th scope="col">Decomposition</th><th scope="col">Plain English</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>A (<code>cli-64.exe</code>)</td><td>0x0022</td><td>0x0002 | 0x0020</td><td>Executable image, large-address-aware (x64, so no 32BIT_MACHINE bit)</td></tr>
                        <tr><td>B (<code>cli-32.exe</code>)</td><td>0x0102</td><td>0x0002 | 0x0100</td><td>Executable image, 32-bit-word machine (not large-address-aware)</td></tr>
                    </tbody>
                </table>
                <p>Neither has 0x2000 — both are EXEs, not DLLs. The two files were built ten seconds apart (timestamps 0x646827E4 and 0x646827DA, both 2023-05-20), same linker, same source tree: 64-bit and 32-bit builds of one tool.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Reading 0x0020 as 32BIT_MACHINE — it is not; 32BIT_MACHINE is 0x0100, which appears only in Sample B. 0x0020 is LARGE_ADDRESS_AWARE (addresses beyond 2 GB), and it is neither DLL (0x2000) nor anything to do with the optional header's own flags. Also do not confuse this Characteristics field with <code>DllCharacteristics</code> in the optional header — different header, different table, covered in the next concept.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Hand-decode Sample A's COFF header — the exact bytes <code>objdump</code> agrees with:</p>
                <ol>
                    <li>Signature: <code>50 45 00 00</code> — P, E, null, null. Four bytes, checked before anything else.</li>
                    <li>Machine <code>64 86</code> → little-endian 0x8664 → <code>IMAGE_FILE_MACHINE_AMD64</code>. The loader will now map this only on x64 (or under emulation).</li>
                    <li>NumberOfSections <code>06 00</code> → 6. The section table right after the optional header has exactly six 40-byte rows — the loader reads that many and no more (spec cap: 96).</li>
                    <li>TimeDateStamp <code>e4 27 68 64</code> → 0x646827E4 → 2023-05-20 01:52:36 UTC (a C <code>time_t</code>; <code>objdump</code> prints it in local time).</li>
                    <li>Symbol fields <code>00 00 00 00</code> × 2 → no COFF symbol table, as the spec requires for images.</li>
                    <li>SizeOfOptionalHeader <code>f0 00</code> → 0x00F0 = 240 bytes. Optional header spans 0x118 to 0x207; the section table begins at 0x208.</li>
                    <li>Characteristics <code>22 00</code> → 0x0022 → EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE — a runnable 64-bit image that may address more than 2 GB.</li>
                </ol>
                <p>Run the same steps on Sample B and every answer flips exactly where the format says it should: Machine 0x014C, 5 sections, optional header 0xE0 bytes, Characteristics 0x0102. One layout, two architectures — this is the "portable" in Portable Executable.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Dump the signature+COFF region of both samples (or any PE you have), then compare with <code>objdump</code>'s decode:</p>
                <pre><code>$ xxd -s 0x100 -l 24 cli-64.exe
00000100: 5045 0000 6486 0600 e427 6864 0000 0000  PE..d....'hd....
00000110: 0000 0000 f000 2200                       ......".

$ xxd -s 0x100 -l 24 cli-32.exe
00000100: 5045 0000 4c01 0500 da27 6864 0000 0000  PE..L....'hd....
00000110: 0000 0000 e000 0201                       ........

$ objdump -x cli-32.exe | sed -n '/^Characteristics/,/^$/p'
Characteristics 0x102
	executable
	32 bit words</code></pre>
                <p>What to look for: bytes 0–3 are always <code>50 45 00 00</code>; bytes 4–5 are Machine (<code>64 86</code> vs <code>4c 01</code>); the last four bytes are SizeOfOptionalHeader and Characteristics (<code>f0 00 22 00</code> vs <code>e0 00 02 01</code>). <code>objdump</code>'s "executable / 32 bit words" is precisely 0x0002 | 0x0100, named.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a PE's Characteristics reads 0x0102. Decompose it against the spec table.</p>
                <div class="quiz" id="quiz-sig-1">
                    <button class="quiz-option" data-correct="true" data-explain="0x0102 = 0x0002 (EXECUTABLE_IMAGE: valid, runnable) | 0x0100 (32BIT_MACHINE: 32-bit-word architecture). Exactly Sample B." onclick="checkQuiz('quiz-sig-1', this)">0x0002 EXECUTABLE_IMAGE | 0x0100 32BIT_MACHINE</button>
                    <button class="quiz-option" data-correct="false" data-explain="LARGE_ADDRESS_AWARE is 0x0020, not 0x0100 — that combination (0x0022) is Sample A, the 64-bit file." onclick="checkQuiz('quiz-sig-1', this)">0x0002 EXECUTABLE_IMAGE | 0x0100 LARGE_ADDRESS_AWARE</button>
                    <button class="quiz-option" data-correct="false" data-explain="DLL is 0x2000 — 0x0102 contains no 0x2000 bit, and a value ending in 02 is 0x0002 EXECUTABLE_IMAGE." onclick="checkQuiz('quiz-sig-1', this)">0x0002 EXECUTABLE_IMAGE | 0x0100 DLL</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You find <code>4c 01 05 00</code> at file offset 0x104 of an unknown PE. What machine and section count do you decode before touching anything else?</p>
                <div class="quiz" id="quiz-sig-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x8664 would be bytes 64 86 — this file starts 4c 01, which is i386." onclick="checkQuiz('quiz-sig-2', this)">x64 (0x8664), 0x0105 sections</button>
                    <button class="quiz-option" data-correct="true" data-explain="Little-endian 4c 01 = 0x014C = IMAGE_FILE_MACHINE_I386; 05 00 = 5 sections. The section table will hold five 40-byte rows." onclick="checkQuiz('quiz-sig-2', this)">i386 (0x014C), 5 sections</button>
                    <button class="quiz-option" data-correct="false" data-explain="Values must be read little-endian: 4c 01 is 0x014C, not 0x4C01; and 05 00 is 5, not 0x0500." onclick="checkQuiz('quiz-sig-2', this)">Machine 0x4C01, 1280 sections</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: signature first (4 bytes), Machine second, NumberOfSections third, SizeOfOptionalHeader fourth — and with that last number you can already compute where the section table starts.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The COFF header ends with <code>SizeOfOptionalHeader</code> — a size field that points straight into the next layer. For Sample A it promises 240 bytes of loader instructions; for Sample B, 224. That layer is called "optional" for a historical reason that surprises almost everyone.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-optional-header">The Optional Header</a> — entry point, image base, alignments, subsystem, and a full side-by-side walk of the PE32 and PE32+ layouts.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-dos-header">Previous: The MS-DOS Header</a></span>
                <span><a href="/courses/pe/lessons/pe-optional-header">Next: The Optional Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
