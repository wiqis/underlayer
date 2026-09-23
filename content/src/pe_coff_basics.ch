// PE Course — Concept 3: The COFF Heritage.
// Why PE carries a Common Object File Format header, and what the 20 bytes mean.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_coff_basics() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The COFF Heritage — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The COFF Heritage</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Straight after the 4-byte PE signature sits a 20-byte structure the specification calls the <strong>COFF file header</strong> — Common Object File Format. This is not a Windows-only invention. The Microsoft PE/COFF specification describes both file kinds in one document, and when it introduces the optional header's standard fields it says outright they are "defined for all implementations of COFF, <em>including UNIX</em>." The object-file lineage is Microsoft's own wording, not folklore.</p>
                <p>It matters because the same 20 bytes open a <code>.obj</code> the linker is about to consume and sit inside every finished <code>.exe</code> the loader will run. If you understand this header once, you understand it in both worlds. It is also where the loader makes its first serious decisions: which CPU, how many sections, is this thing even executable?</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Picture a factory pipeline:</p>
                <ol>
                    <li><strong>Object files (.obj).</strong> The compiler emits a COFF header, section headers, raw code and data, plus COFF relocations and a symbol table — everything the linker still needs to resolve. No DOS stub, no PE signature; <code>SizeOfOptionalHeader</code> should be zero.</li>
                    <li><strong>The linker</strong> merges the objects, applies relocations, picks final addresses, and writes an image: DOS stub, PE signature, <em>the same 20-byte COFF header</em>, now with an optional header attached, then the section table and section data.</li>
                    <li><strong>The image (.exe/.dll).</strong> The COFF header survives the trip unchanged in layout — only the surrounding context and a few field conventions differ (symbols zeroed out, optional header required).</li>
                </ol>
                <p>The model's missing piece: which fields mean what depends on which side of the linker you are on. The bytes are identical; the contract is not.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The COFF file header is 20 bytes, and the specification gives its layout exactly (it begins at file offset 0 in an object file, or right after the PE signature in an image):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Who cares</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>2</td><td>Machine</td><td>Loader: reject wrong CPU; tools: pick a disassembler</td></tr>
                        <tr><td>2</td><td>2</td><td>NumberOfSections</td><td>Everyone: sizes the section table (loader caps it at 96)</td></tr>
                        <tr><td>4</td><td>4</td><td>TimeDateStamp</td><td>Tools, packaging: seconds since 1970-01-01 (C <code>time_t</code>)</td></tr>
                        <tr><td>8</td><td>4</td><td>PointerToSymbolTable</td><td>Object files: file offset of COFF symbols; should be 0 in images</td></tr>
                        <tr><td>12</td><td>4</td><td>NumberOfSymbols</td><td>Object files: symbol count; should be 0 in images</td></tr>
                        <tr><td>16</td><td>2</td><td>SizeOfOptionalHeader</td><td>Everyone: how many bytes follow before the section table</td></tr>
                        <tr><td>18</td><td>2</td><td>Characteristics</td><td>Loader: executable? DLL? 32-bit? large-address-aware?</td></tr>
                    </tbody>
                </table>
                <p><strong>Machine values you will actually meet</strong> (from the specification's Machine Types table):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Constant</th><th scope="col">Target</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x14C</td><td><code>IMAGE_FILE_MACHINE_I386</code></td><td>Intel 386 and compatible (32-bit)</td></tr>
                        <tr><td>0x8664</td><td><code>IMAGE_FILE_MACHINE_AMD64</code></td><td>x64 (64-bit)</td></tr>
                        <tr><td>0xAA64</td><td><code>IMAGE_FILE_MACHINE_ARM64</code></td><td>ARM64 little endian</td></tr>
                    </tbody>
                </table>
                <p><strong>Object versus image conventions.</strong> The specification is explicit: <code>SizeOfOptionalHeader</code> "is required for executable files but not for object files" and should be zero for an object; <code>PointerToSymbolTable</code> and <code>NumberOfSymbols</code> "should be zero for an image because COFF debugging information is deprecated." <code>NumberOfSections</code> still drives everything — but the Windows loader refuses more than 96 sections.</p>
                <p><strong>TimeDateStamp.</strong> The low 32 bits of seconds since 00:00 January 1, 1970 — a C runtime <code>time_t</code>. The specification adds two caveats: a stamp of 0 or 0xFFFFFFFF "does not represent a real or meaningful date/time stamp," and for exceptions it points to <code>IMAGE_DEBUG_TYPE_REPRO</code> in the Debug Type section (the mechanism reproducible-build tooling uses instead of a wall-clock stamp). This file's stamp, 0x646827E4, decodes to 2023-05-20 01:52:36 UTC.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Thinking the COFF header only exists in object files — or that it is a "pre-PE" leftover you can skip. It is not a leftover: it is the live identity block of every image, and it is the exact structure <code>objdump</code>, <code>dumpbin</code>, and the Windows loader itself read immediately after the PE signature. Skipping it means you never learn the CPU, the section count, or whether the file is executable at all.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The same 20 bytes in two real files — <code>cli-64.exe</code> (PE32+) and <code>cli-32.exe</code> (PE32), both starting at file offset 0x104:</p>
                <div class="hex-dump">
                    <pre>00000104: 6486 0600 e427 6864 0000 0000 0000 0000  d....'hd........
00000114: f000 2200                                ..".

00000104: 4c01 0500 da27 6864 0000 0000 0000 0000  L....'hd........
00000114: e000 0201                                ....</pre>
                </div>
                <p>Field-by-field (all multi-byte values little-endian):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">cli-64.exe</th><th scope="col">cli-32.exe</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Machine</td><td>0x8664 — x64</td><td>0x014C — i386</td></tr>
                        <tr><td>NumberOfSections</td><td>6</td><td>5</td></tr>
                        <tr><td>TimeDateStamp</td><td>0x646827E4</td><td>0x646827DA</td></tr>
                        <tr><td>PointerToSymbolTable</td><td>0</td><td>0</td></tr>
                        <tr><td>NumberOfSymbols</td><td>0</td><td>0</td></tr>
                        <tr><td>SizeOfOptionalHeader</td><td>0x00F0 (240 — PE32+)</td><td>0x00E0 (224 — PE32)</td></tr>
                        <tr><td>Characteristics</td><td>0x0022</td><td>0x0102</td></tr>
                    </tbody>
                </table>
                <p>Read the conventions in the data: both symbol fields are zero (COFF debugging deprecated for images), both timestamps land ten seconds apart on 2023-05-20, and <code>SizeOfOptionalHeader</code> already tells you 64-bit versus 32-bit before you ever open the optional header — 240 bytes versus 224. The two files were built by the same linker (both optional headers report 14.36) targeting different machines.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any PE or COFF file works. Dump the 20 bytes yourself, then let <code>objdump</code> decode them:</p>
                <pre><code>$ xxd -s 0x104 -l 20 cli-64.exe
00000104: 6486 0600 e427 6864 0000 0000 0000 0000  d....'hd........
00000114: f000 2200                                ..".

$ objdump -x cli-64.exe | head -8
Characteristics 0x22
	executable
	large address aware

Time/Date		Sat May 20 06:52:36 2023</code></pre>
                <p>What to look for: the first two bytes are the machine in little-endian (<code>64 86</code> = 0x8664 = x64), bytes 16–19 are <code>SizeOfOptionalHeader</code> and <code>Characteristics</code> (<code>f0 00</code> then <code>22 00</code>), and <code>objdump</code>'s "executable / large address aware" lines are exactly the bits of 0x0022 — decoded for you.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which two COFF header fields should be zero in a modern image, and why?</p>
                <div class="quiz" id="quiz-coff-1">
                    <button class="quiz-option" data-correct="true" data-explain="PointerToSymbolTable and NumberOfSymbols. The specification says both should be zero for an image because COFF debugging information is deprecated — symbols moved to separate debug files." onclick="checkQuiz('quiz-coff-1', this)">PointerToSymbolTable and NumberOfSymbols — COFF debugging is deprecated</button>
                    <button class="quiz-option" data-correct="false" data-explain="Machine is never zero — it identifies the CPU and a value of 0 means IMAGE_FILE_MACHINE_UNKNOWN. NumberOfSections must reflect the real section table." onclick="checkQuiz('quiz-coff-1', this)">Machine and NumberOfSections — they are implied by the optional header</button>
                    <button class="quiz-option" data-correct="false" data-explain="SizeOfOptionalHeader is required for images (0xF0 in our sample), and Characteristics tells the loader whether the file is executable — clearing them would break loading." onclick="checkQuiz('quiz-coff-1', this)">SizeOfOptionalHeader and Characteristics — images do not need them</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You dump a PE's COFF header and read the first two bytes as <code>4c 01</code>. What machine is it, and what is NumberOfSections if the next two bytes are <code>05 00</code>?</p>
                <div class="quiz" id="quiz-coff-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x8664 would be bytes 64 86 — that is our 64-bit sample. Bytes 4c 01 decode little-endian to 0x014C, not 0x8664." onclick="checkQuiz('quiz-coff-2', this)">x64 with 5 sections</button>
                    <button class="quiz-option" data-correct="true" data-explain="Little-endian 4c 01 = 0x014C = IMAGE_FILE_MACHINE_I386 (Intel 386). Little-endian 05 00 = 5 sections — exactly cli-32.exe's COFF header." onclick="checkQuiz('quiz-coff-2', this)">i386 with 5 sections</button>
                    <button class="quiz-option" data-correct="false" data-explain="0xAA64 is ARM64 (bytes would be 64 aa), and section count 0x4c01 = 19456 is absurd — the loader caps sections at 96." onclick="checkQuiz('quiz-coff-2', this)">ARM64 with 19456 sections</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: read Machine first to pick the decoder, NumberOfSections to size the table, SizeOfOptionalHeader to find the section table — in that order, every time.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The COFF header is the modern half of the file's dual identity. The other half sits in front of it: a full 64-byte MS-DOS header that still opens every PE, carrying the magic <code>MZ</code> and the pointer that led you here.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-dos-header">The MS-DOS Header</a> — all 64 bytes, field by field, and why a 40-year-old header still gates every Windows executable.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-file-layout">Previous: PE File Layout</a></span>
                <span><a href="/courses/pe/lessons/pe-dos-header">Next: The MS-DOS Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
