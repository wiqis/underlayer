// PE Course — Module 8: How the Windows Loader Maps a PE.
// A model of the documented mapping contract; every step anchored to the PE spec.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_loader() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("How the Windows Loader Maps a PE — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>How the Windows Loader Maps a PE</h1>
            <div class="lesson-meta">15 min · Module 8: Loading &amp; Execution · Runtime</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every file format you have studied so far is inert. The loader is where it stops being inert: the component that reads those headers, allocates memory, copies bytes, patches addresses, and transfers control. Understand it and you understand why ASLR exists, why an import is a memory write, why a signature is checked but never executed, and what malware actually manipulates when it injects or hollows a process.</p>
                <p>You also stop being surprised by load failures. A relocation stripped image cannot move. A certificate is not a section. A section that ends at 0x8030 still occupies pages up to 0x9000. None of that is arbitrary — it falls out of fields you can read.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What follows is a model of the documented contract. The PE specification defines the data the loader consumes; it does not publish the operating system algorithm, and kernel internals are out of scope here. Each step below is anchored to a spec rule or a documented API — treat the sequence as the shape of the contract, not source code.</p>
                <ol>
                    <li><strong>Probe and parse.</strong> Check MZ, follow e_lfanew, check the PE signature, read the COFF and optional headers (magic 0x20B for PE32+).</li>
                    <li><strong>Choose a base.</strong> ImageBase is the preferred address. If it is free, use it. If not and base relocations exist, load elsewhere and fix up pointers; DllCharacteristics DYNAMIC_BASE advertises that the image can be relocated at load time.</li>
                    <li><strong>Map the headers.</strong> SizeOfHeaders — DOS stub plus PE header plus section headers, rounded to FileAlignment — is mapped first.</li>
                    <li><strong>Map the sections.</strong> Each section lands at base plus its VirtualAddress, zero-filling any tail past SizeOfRawData.</li>
                    <li><strong>Apply relocations</strong> if the chosen base differs from ImageBase.</li>
                    <li><strong>Resolve imports.</strong> The import address table entries are overwritten with the actual addresses of the imported symbols — the spec says the loader typically processes the binding.</li>
                    <li><strong>Start TLS.</strong> Write the index, seed each thread from the template, invoke registered callbacks.</li>
                    <li><strong>Apply protections</strong> from section characteristics and DllCharacteristics flags such as NX_COMPAT.</li>
                    <li><strong>Transfer control</strong> to AddressOfEntryPoint — for program images, the spec calls this the starting address. For DLLs the linker default entry is the CRT wrapper _DllMainCRTStartup, which calls DllMain (Microsoft, "/ENTRY").</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Thinking the certificate is mapped like a section. The spec is explicit: attribute certificates and debug information must sit at the very end of the file because the loader does not map these into memory. Signature data is read from the file, never executed from the image.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec rules that pin the model down:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Rule</th><th scope="col">Spec text (condensed)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>ImageBase</td><td>Preferred address of the first byte when loaded; must be a multiple of 64 K</td></tr>
                        <tr><td>SectionAlignment</td><td>Alignment of sections in memory; at least FileAlignment; default is the page size</td></tr>
                        <tr><td>FileAlignment</td><td>Power of 2 between 512 and 64 K; default 512</td></tr>
                        <tr><td>SizeOfImage</td><td>Size of the image including all headers; must be a multiple of SectionAlignment</td></tr>
                        <tr><td>Section placement</td><td>Section VAs are assigned in ascending order and adjacent, each a multiple of SectionAlignment</td></tr>
                        <tr><td>Zero fill</td><td>If SizeOfRawData is less than VirtualSize, the remainder is padded with zeros</td></tr>
                        <tr><td>Relocations stripped</td><td>IMAGE_FILE_RELOCS_STRIPPED: no base relocations; must load at the preferred base or the loader reports an error</td></tr>
                        <tr><td>Certificate table</td><td>The virtual address in that data directory is a file offset to the first certificate entry</td></tr>
                    </tbody>
                </table>
                <p>Two verified files, same rules, different choices:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">cli-64.exe</th><th scope="col">conpty.dll</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>ImageBase</td><td>0x140000000</td><td>0x180000000</td></tr>
                        <tr><td>SectionAlignment / FileAlignment</td><td>0x1000 / 0x200</td><td>0x1000 / 0x200</td></tr>
                        <tr><td>SizeOfHeaders / SizeOfImage</td><td>0x400 / 0x9000</td><td>0x400 / 0x1D000</td></tr>
                        <tr><td>COFF Characteristics</td><td>0x0022 (executable, large-address-aware)</td><td>0x2022 (plus DLL)</td></tr>
                        <tr><td>DllCharacteristics</td><td>0x8160 (HIGH_ENTROPY_VA, DYNAMIC_BASE, NX_COMPAT, TERMINAL_SERVER_AWARE)</td><td>0x4160 (same, with GUARD_CF instead of TERMINAL_SERVER_AWARE)</td></tr>
                        <tr><td>Subsystem</td><td>3 (console)</td><td>2 (Windows GUI)</td></tr>
                    </tbody>
                </table>
                <p>The flag values come straight from the spec table: HIGH_ENTROPY_VA is 0x0020, DYNAMIC_BASE 0x0040, NX_COMPAT 0x0100, GUARD_CF 0x4000, TERMINAL_SERVER_AWARE 0x8000. Mask and add — 0x8160 and 0x4160 decompose exactly as the table says.</p>
                <p>The certificate directory proves the file-offset rule. In <code>conpty.dll</code>, data directory index 4 holds the pair 0x18600, 0x3D20. That is not an RVA: naive RVA conversion would map 0x18600 into <code>.data</code> and show you the wrong bytes. Read it as a file offset instead, and 0x18600 + 0x3D20 equals 0x1C320 — the exact file size, one quadword-aligned WIN_CERTIFICATE entry covering the Authenticode signature. The first bytes confirm the structure: dwLength 0x00003D20, wRevision 0x0200, wCertificateType 0x0002, which the spec defines as WIN_CERT_TYPE_PKCS_SIGNED_DATA.</p>
                <div class="hex-dump">
                    <pre>00018600: 203d 0000 0002 0200 3082 3d10 0609 2a86
00018610: 4886 f70d 0107 02a0 823d 0130 823c fd02</pre>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Run the model against <code>cli-64.exe</code> and watch the numbers close:</p>
                <ol>
                    <li>Headers occupy 0x400 bytes (SizeOfHeaders, rounded to FileAlignment 0x200) at the base, so the first section starts at file offset 0x400 and RVA 0x1000.</li>
                    <li>Six sections, all ascending: .text 0x1000, .rdata 0x3000, .data 0x5000, .pdata 0x6000, .rsrc 0x7000, .reloc 0x8000 — each exactly a multiple of SectionAlignment.</li>
                    <li>The last section ends at 0x8000 + 0x30 = 0x8030. SizeOfImage must be a multiple of 0x1000, so the image rounds up to 0x9000 — the remaining 0xFD0 bytes complete the final page.</li>
                    <li>Relocations are present (.reloc at index 5, RVA 0x8000, and DYNAMIC_BASE set), so this image is free to load away from 0x140000000.</li>
                    <li>Imports are resolved into the IAT at RVA 0x3000 before the entry point runs — that is how the entry we will disassemble in the next lesson can call GetSystemTimeAsFileTime by name at build time and by address at run time.</li>
                </ol>
                <p>Same arithmetic for <code>conpty.dll</code>: its sections end at 0x1C000 + 0x280 = 0x1C280, and SizeOfImage reads 0x1D000 — the next SectionAlignment boundary.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump reports the format, flags, and the computed start address (image base plus entry RVA):</p>
                <pre><code>$ objdump -f cli-64.exe
file format pei-x86-64
architecture: i386:x86-64, flags 0x0000012f:
HAS_RELOC, EXEC_P, HAS_LINENO, HAS_DEBUG, HAS_LOCALS, D_PAGED
start address 0x0000000140001d40</code></pre>
                <p>HAS_RELOC confirms step 2 can rebase, and the start address is ImageBase 0x140000000 plus AddressOfEntryPoint 0x1D40. On Windows, dumpbin /headers prints the same optional-header fields in one place.</p>
                <p>What to look for: whenever start address minus ImageBase does not equal AddressOfEntryPoint, you have misread a header — that single subtraction validates two fields at once.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a PE file carries IMAGE_FILE_RELOCS_STRIPPED and its preferred ImageBase is already taken. What happens?</p>
                <div class="quiz" id="quiz-loader-1">
                    <button class="quiz-option" data-correct="false" data-explain="DYNAMIC_BASE advertises that relocations exist and the image may move; RELOCS_STRIPPED is the opposite claim — there are no relocations to apply." onclick="checkQuiz('quiz-loader-1', this)">The loader relocates it anyway using DYNAMIC_BASE</button>
                    <button class="quiz-option" data-correct="true" data-explain="The spec says a file with relocations stripped must be loaded at its preferred base, and if that address is not available the loader reports an error." onclick="checkQuiz('quiz-loader-1', this)">The load fails — the loader reports an error</button>
                    <button class="quiz-option" data-correct="false" data-explain="Import binding and TLS do not depend on the load address in this way; without relocations, absolute addresses baked in at link time simply cannot be corrected." onclick="checkQuiz('quiz-loader-1', this)">It loads and only the imports break</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A tools reads data directory index 4 of <code>conpty.dll</code> as RVA 0x18600 and converts it through the section table. What went wrong?</p>
                <div class="quiz" id="quiz-loader-2">
                    <button class="quiz-option" data-correct="false" data-explain="The value 0x18600 itself is correct — it is the certificate location the file really carries." onclick="checkQuiz('quiz-loader-2', this)">The directory value is corrupt</button>
                    <button class="quiz-option" data-correct="false" data-explain="Section conversion is right for every normal directory; the certificate entry is simply not one of those." onclick="checkQuiz('quiz-loader-2', this)">The section table should be ignored for all directories</button>
                    <button class="quiz-option" data-correct="true" data-explain="The spec says the Certificate Table virtual address is a file offset to the first entry, not an RVA. Convert it as a file offset — 0x18600 plus size 0x3D20 reaches the end of the file exactly." onclick="checkQuiz('quiz-loader-2', this)">The certificate directory holds a file offset, not an RVA</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every data directory is an RVA except the certificate table, which is a file offset the loader never maps.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The loader has mapped the image. Now that you know the rules, you can picture the result: one contiguous region from ImageBase to ImageBase plus SizeOfImage, with the stack and heap growing beside it.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-memory-layout">Process Memory Layout</a> — ImageBase, sections in memory, heap, and stack.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-exceptions">Previous: Exception Tables (.pdata)</a></span>
                <span><a href="/courses/pe/lessons/pe-memory-layout">Next: Process Memory Layout</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
