// PE Course — Concept 10: Common Sections.
// What .text .rdata .data .pdata .rsrc .reloc are for; flags decoded.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_common_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Common Sections — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Common Sections</h1>
            <div class="lesson-meta">15 min · Module 4: Sections · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Open almost any Windows binary and you meet the same cast: <code>.text</code>, <code>.rdata</code>, <code>.data</code>, <code>.pdata</code>, <code>.rsrc</code>, <code>.reloc</code>. Knowing what belongs where turns PE reading from byte-hunting into navigation — import names live in read-only data, mutable globals are the only writable section, exception unwind info sits in its own table the dispatcher can find by directory index rather than by name.</p>
                <p>But the names are conventions chosen by the linker, not rules enforced by the format. The loader never reads them; it reads the Characteristics flags. Learn both: names for orientation, flags for truth.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Sort sections by what they are allowed to do, not by what they are called:</p>
                <ul>
                    <li><strong>Executable, read-only:</strong> <code>.text</code> — machine code. Nothing else may execute (that is DEP/NX doing its job).</li>
                    <li><strong>Read-only data:</strong> <code>.rdata</code> — constants, import name strings, the import address table, debug and load-config structures. Read but never written by the program.</li>
                    <li><strong>Read-write data:</strong> <code>.data</code> — initialized globals, plus a zero-filled tail when VirtualSize exceeds SizeOfRawData.</li>
                    <li><strong>Bookkeeping the OS itself consumes:</strong> <code>.pdata</code> (x64 unwind entries), <code>.rsrc</code> (resource tree), <code>.reloc</code> (base relocations, discardable after loading).</li>
                </ul>
                <p>The model's missing piece: the directory index, not the name, is the contract. Sample A's import table lives in <code>.rdata</code>, and there is no <code>.idata</code> section in either sample — the Import directory (RVA 0x3A04) points wherever the linker put it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's flag bits that matter for images, and what each sample sets:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Mask</th><th scope="col">Flag</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00000020</td><td>IMAGE_SCN_CNT_CODE</td><td>Section contains executable code</td></tr>
                        <tr><td>0x00000040</td><td>IMAGE_SCN_CNT_INITIALIZED_DATA</td><td>Section contains initialized data</td></tr>
                        <tr><td>0x02000000</td><td>IMAGE_SCN_MEM_DISCARDABLE</td><td>May be discarded once the loader is done with it</td></tr>
                        <tr><td>0x20000000</td><td>IMAGE_SCN_MEM_EXECUTE</td><td>Page may be executed</td></tr>
                        <tr><td>0x40000000</td><td>IMAGE_SCN_MEM_READ</td><td>Page may be read</td></tr>
                        <tr><td>0x80000000</td><td>IMAGE_SCN_MEM_WRITE</td><td>Page may be written</td></tr>
                    </tbody>
                </table>
                <p>Both samples, decoded from their real Characteristics fields:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Purpose</th><th scope="col">A / B Characteristics</th><th scope="col">Decode</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.text</td><td>Machine code; entry point lives here</td><td>0x60000020</td><td>CODE | EXECUTE | READ</td></tr>
                        <tr><td>.rdata</td><td>Constants, import names, IAT, load config, debug pointers</td><td>0x40000040</td><td>INITIALIZED_DATA | READ</td></tr>
                        <tr><td>.data</td><td>Mutable globals; zero-fill tail beyond SizeOfRawData</td><td>0xC0000040</td><td>INITIALIZED_DATA | READ | WRITE</td></tr>
                        <tr><td>.pdata</td><td>x64 RUNTIME_FUNCTION entries for the unwinder (directory 3)</td><td>0x40000040</td><td>INITIALIZED_DATA | READ</td></tr>
                        <tr><td>.rsrc</td><td>Resource tree (directory 2): icons, version info, manifests</td><td>0x40000040</td><td>INITIALIZED_DATA | READ</td></tr>
                        <tr><td>.reloc</td><td>Base relocations (directory 5); loader may discard after fixups</td><td>0x42000040</td><td>MEM_DISCARDABLE | INITIALIZED_DATA | READ</td></tr>
                    </tbody>
                </table>
                <p>Sample A has <code>.pdata</code> because it is x64 (exception directory 0x6000/0x1EC points straight at it); Sample B is 32-bit and has no <code>.pdata</code> at all — its exception directory is zero. Sample B also drops <code>.pdata</code> while keeping the same flags on the five sections both files share.</p>
                <p>Linkers do add their own sections beyond the classic six. Verified on binaries in this very environment: <code>OpenConsole.exe</code> carries <code>.didat</code> and a populated Delay Import directory (RVA 0xE8CB8, size 0x40); <code>dbghelp.dll</code> carries <code>.didat</code> and <code>.mrdata</code>; <code>rg.exe</code> carries <code>.fptable</code>; <code>libasyncProfiler.dll</code> carries <code>.idata</code>, <code>.tls</code> and <code>.00cfg</code>. Every one of those was linked by MSVC 14.x — treat unfamiliar names as data-plus-flags to decode, never as assumptions about content.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Expecting an <code>.idata</code> section — modern MSVC folds import descriptors, names and the IAT into <code>.rdata</code> (directory 12, the IAT, starts at RVA 0x3000 = the first byte of <code>.rdata</code> in Sample A). Dispatching on section names in code — the spec only promises the order the linker chose, and says tables need not begin at section starts. And assuming <code>.reloc</code> must stay resident — its MEM_DISCARDABLE bit tells the loader it may unmap those pages after rebasing.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Decode <code>.reloc</code>'s 0x42000040 by peeling bits off, highest first:</p>
                <pre>0x42000040
  0x80000000 MEM_WRITE          not set  -- loader will map it read-only
  0x40000000 MEM_READ           set
  0x20000000 MEM_EXECUTE        not set  -- data, not code
  0x02000000 MEM_DISCARDABLE    set      -- safe to drop after relocations
  0x00000040 CNT_INITIALIZED_DATA set    -- initialized data class
  0x00000020 CNT_CODE           not set
= read-only, discardable, initialized data</pre>
                <p>Then <code>.data</code>'s 0xC0000040 — the only writable row in either sample:</p>
                <pre>0xC0000040 = 0x80000000 (MEM_WRITE) | 0x40000000 (MEM_READ) | 0x00000040 (CNT_INITIALIZED_DATA)</pre>
                <p>The consequences are visible without a debugger: with NX_COMPAT set in both samples (DllCharacteristics 0x8160 for A, 0x8140 for B), <code>.text</code> gets execute-plus-read and no write, <code>.data</code> gets read-plus-write and no execute, and a program that tries to store a variable into <code>.text</code> raises an access violation — the section table said so first.</p>
                <p>Sample A's section table tail, where the flags live (last 8 bytes of each row are two zero dwords plus Characteristics):</p>
                <div class="hex-dump">
                    <pre>00000228: 0000 0000 2000 0060 2e72 6461 7461 0000  .... ..`.rdata..
00000278: 0000 0000 4000 00c0 2e70 6461 7461 0000  ....@....pdata..
000002e8: 0000 0000 0000 0000 0000 0000 4000 0042  ............@..B</pre>
                </div>
                <p>Read them backwards, little-endian: <code>20 00 00 60</code> = 0x60000020, <code>40 00 00 c0</code> = 0xC0000040, <code>40 00 00 42</code> = 0x42000040.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>List the sections, then decode the flags yourself:</p>
                <pre><code>$ objdump -h cli-64.exe
Idx Name          Size      VMA               File off
  0 .text         000017bc  0000000140001000  00000400
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  1 .rdata        0000132c  0000000140003000  00001c00
                  CONTENTS, ALLOC, LOAD, READONLY, DATA
...
  5 .reloc        00000030  0000000140008000  00003600
                  CONTENTS, LOAD, READONLY, DATA</code></pre>
                <p>A bit-decoder for any Characteristics value:</p>
                <pre><code>$ python3 -c "ch=0x42000040; flags=[(0x80000000,'WRITE'),(0x40000000,'READ'),(0x20000000,'EXECUTE'),(0x02000000,'DISCARDABLE'),(0x00000040,'INIT_DATA'),(0x00000020,'CODE')]; print([n for m,n in flags if ch &amp; m])"
['READ', 'DISCARDABLE', 'INIT_DATA']</code></pre>
                <p>Run it on 0x60000020, 0x40000040 and 0xC0000040 — you should get CODE/EXECUTE/READ, READ/INIT_DATA, and WRITE/READ/INIT_DATA respectively. Then try <code>objdump -h cli-32.exe</code> and notice <code>.pdata</code> is missing on the 32-bit build.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: decode 0x42000040 into named flags, and say which section of Sample A carries it.</p>
                <div class="quiz" id="quiz-cs-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x42000040 has no 0x80000000 bit, so it is not writable, and no 0x20000000 bit, so it is not executable. .reloc is read by the loader, mapped read-only, then discarded." onclick="checkQuiz('quiz-cs-1', this)">EXECUTE plus READ plus CODE — it is the .text section</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x40000000 is MEM_READ, 0x02000000 is MEM_DISCARDABLE, 0x00000040 is CNT_INITIALIZED_DATA. That combination belongs to .reloc in both samples: the loader reads the fixups, applies them, and may unmap the pages." onclick="checkQuiz('quiz-cs-1', this)">MEM_READ | MEM_DISCARDABLE | CNT_INITIALIZED_DATA — .reloc</button>
                    <button class="quiz-option" data-correct="false" data-explain="MEM_WRITE would require the top bit 0x80000000, which 0x42000040 does not have. Only .data (0xC0000040) is writable." onclick="checkQuiz('quiz-cs-1', this)">MEM_READ | MEM_WRITE | CNT_INITIALIZED_DATA — .data</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A program needs a global counter that several functions increment. Which section of Sample A will the linker place it in, and how do you know from the flags alone — without reading the name?</p>
                <div class="quiz" id="quiz-cs-2">
                    <button class="quiz-option" data-correct="false" data-explain=".rdata is 0x40000040 — read-only. Storing to it faults at runtime, which is exactly why constants and import names are parked there." onclick="checkQuiz('quiz-cs-2', this)">.rdata, because all data starts in read-only data and is copied later</button>
                    <button class="quiz-option" data-correct="false" data-explain=".text is 0x60000020 — execute plus read, no write. With NX_COMPAT set, writes to it raise an access violation." onclick="checkQuiz('quiz-cs-2', this)">.text, because mutable state belongs next to the code that uses it</button>
                    <button class="quiz-option" data-correct="true" data-explain="Only .data carries 0x80000000 (MEM_WRITE): 0xC0000040 = WRITE | READ | CNT_INITIALIZED_DATA. Every other section in both samples lacks the write bit, so the flag — not the four-character name — is what identifies writable storage." onclick="checkQuiz('quiz-cs-2', this)">.data — it is the only row whose Characteristics include 0x80000000</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: name for humans, flags for the loader, directory index for finding structures. When they disagree, the flags and directories win.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have seen the two sizes per section (0x17BC vs 0x1800) and the two rulers that produce them — content length versus padded disk length. The next lesson makes both rulers explicit: FileAlignment for the disk, SectionAlignment for memory, and the SizeOfImage / SizeOfHeaders arithmetic that ties them together.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-alignment">Alignment: FileAlignment vs SectionAlignment</a> — why the file is 14336 bytes but the image claims 0x9000, and how to prove a file has no overlay.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-section-table">Previous: The Section Table</a></span>
                <span><a href="/courses/pe/lessons/pe-alignment">Next: Alignment: FileAlignment vs SectionAlignment</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
