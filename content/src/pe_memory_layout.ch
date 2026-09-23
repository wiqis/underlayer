// PE Course — Module 8: Process Memory Layout.
// ImageBase to SizeOfImage, section gaps, stack and heap — verified against both samples.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_memory_layout() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Process Memory Layout — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Process Memory Layout</h1>
            <div class="lesson-meta">15 min · Module 8: Loading and Execution · Runtime</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A crash dump shows you addresses like 0x1400061A4. A hex editor shows file offsets like 0x3254. Debuggers, exploit writeups, and disassemblers speak in three dialects — file offset, RVA, and VA — and the memory layout is where they all meet. Get the layout right in your head and every address in every tool becomes the same number seen from a different window.</p>
                <p>It also explains physical behavior: why .reloc can be thrown away after loading (it is marked discardable), why writing to .text faults (NX protection from section flags), and why your stack behaves like a reserve-plus-commit region rather than one giant allocation.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Picture one process address space with three pieces:</p>
                <ol>
                    <li><strong>The image</strong> — one contiguous block from ImageBase up to ImageBase plus SizeOfImage. Headers first, then every section at its VirtualAddress, each padded out to SectionAlignment.</li>
                    <li><strong>The stack</strong> — a region sized by SizeOfStackReserve, of which only SizeOfStackCommit is committed up front; the rest appears one page at a time as the stack grows.</li>
                    <li><strong>The heap</strong> — sized by SizeOfHeapReserve with SizeOfHeapCommit handed out incrementally, the same pattern.</li>
                </ol>
                <p>The model's missing piece: sections are adjacent in the section table but leave small gaps in memory. Those gaps are not wasted — they are the rounding to SectionAlignment, and they are why the last section can end at 0x8030 while the image still occupies a full page more.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec rules that build the map:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">Spec rule</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>ImageBase</td><td>Preferred address of the first byte when loaded; must be a multiple of 64 K</td></tr>
                        <tr><td>Section placement</td><td>Section VAs in ascending order and adjacent, each a multiple of SectionAlignment</td></tr>
                        <tr><td>SizeOfImage</td><td>Size of the image including all headers; must be a multiple of SectionAlignment</td></tr>
                        <tr><td>SizeOfStackReserve / Commit</td><td>Only the commit size is committed; the rest of the reserve is made available one page at a time</td></tr>
                        <tr><td>SizeOfHeapReserve / Commit</td><td>Same reserve-versus-commit pattern for the local heap</td></tr>
                    </tbody>
                </table>
                <p>And the conversion that ties every tool together: VA = ImageBase + RVA, always. File offset is the odd one out — it comes from the section table, per section, and no single formula covers it.</p>
                <p>Section characteristics become memory protection. Our samples decode straight from the spec flag table: <code>.text</code> reads 0x60000020 — IMAGE_SCN_CNT_CODE (0x20), MEM_EXECUTE (0x20000000), MEM_READ (0x40000000). <code>.data</code> reads 0xC0000040 — initialized data, read, and write. <code>.reloc</code> reads 0x42000040 — initialized data, read, and MEM_DISCARDABLE (0x02000000), so the loader may drop it once relocations are done.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Treating the file offset as if it were an RVA plus a constant. Every section has its own PointerToRawData versus VirtualAddress delta: in <code>cli-64.exe</code> that delta is 0xC00 for .text but 0x3C00 for .rsrc. One equation never converts across sections.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The loaded image of <code>cli-64.exe</code>, base 0x140000000 (computed as base plus each VirtualAddress):</p>
                <table>
                    <thead>
                        <tr><th scope="col">VA</th><th scope="col">Section</th><th scope="col">Ends at</th><th scope="col">Holds</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x140000000</td><td>headers</td><td>0x140000400</td><td>DOS stub, PE headers, section table (SizeOfHeaders 0x400)</td></tr>
                        <tr><td>0x140001000</td><td>.text</td><td>0x1400027BC</td><td>Code, including the entry at 0x140001D40</td></tr>
                        <tr><td>0x140003000</td><td>.rdata</td><td>0x14000432C</td><td>Imports, load config, read-only constants</td></tr>
                        <tr><td>0x140005000</td><td>.data</td><td>0x140005648</td><td>Writable globals, including the security cookie slot at 0x140005008</td></tr>
                        <tr><td>0x140006000</td><td>.pdata</td><td>0x1400061EC</td><td>41 RUNTIME_FUNCTION entries</td></tr>
                        <tr><td>0x140007000</td><td>.rsrc</td><td>0x1400071E0</td><td>The manifest resource tree</td></tr>
                        <tr><td>0x140008000</td><td>.reloc</td><td>0x140008030</td><td>Base relocations, discardable</td></tr>
                        <tr><td>0x140009000</td><td>(image end)</td><td>—</td><td>SizeOfImage 0x9000 rounds the last section up to a page boundary</td></tr>
                    </tbody>
                </table>
                <p>Watch the gaps: .text runs out at 0x27BC and .rdata does not start until 0x3000 — 0x844 bytes of padding, exactly the rounding to SectionAlignment. The stack and heap of this process each reserve 0x100000 bytes and commit only 0x1000 up front, read from the optional header we decoded earlier.</p>
                <p><code>conpty.dll</code> shows the same shape at its own base, 0x180000000: .text ends at RVA 0x10674, .rdata waits at 0x11000, and the image closes at SizeOfImage 0x1D000 after .reloc ends at 0x1C280.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Convert RVAs to VAs yourself — the whole trick is one addition:</p>
                <pre><code>$ python3 -c "print(hex(0x140000000 + 0x6000))"
0x140006000

$ python3 -c "print(hex(0x140000000 + 0x1d40))"
0x140001d40</code></pre>
                <p>Then confirm the image end from the section table: add the last VirtualAddress and VirtualSize, round up to SectionAlignment, and compare against SizeOfImage. For our sample: 0x8000 plus 0x30 rounds to 0x9000 — and the header says 0x9000.</p>
                <p>What to look for: the second line is the entry point of the whole program. Every address you will disassemble in the next lesson lives in this map.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: <code>cli-64.exe</code> loads at 0x140000000 and you see a fault at VA 0x140005008. What is its RVA, and which section is it in?</p>
                <div class="quiz" id="quiz-memory-1">
                    <button class="quiz-option" data-correct="false" data-explain="That would be the file offset for part of .rdata — a different address space entirely. Subtract the image base, not a file pointer." onclick="checkQuiz('quiz-memory-1', this)">RVA 0x5008, in the file at offset 0x3008 only by coincidence of section deltas</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x140005008 minus ImageBase 0x140000000 = RVA 0x5008, which falls inside .data at VirtualAddress 0x5000 — the security cookie slot." onclick="checkQuiz('quiz-memory-1', this)">RVA 0x5008, in .data</button>
                    <button class="quiz-option" data-correct="false" data-explain=".text spans 0x1000 to 0x27BC; 0x5008 is two sections past that." onclick="checkQuiz('quiz-memory-1', this)">RVA 0x5008, in .text</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>The last section of a PE32+ image ends at RVA 0x8030, and SectionAlignment is 0x1000. What SizeOfImage does the spec require?</p>
                <div class="quiz" id="quiz-memory-2">
                    <button class="quiz-option" data-correct="false" data-explain="FileAlignment 0x200 governs bytes on disk, not the size of the loaded image. Rounding to it would leave the last page partially outside the declared image." onclick="checkQuiz('quiz-memory-2', this)">0x8100 — round up to FileAlignment</button>
                    <button class="quiz-option" data-correct="false" data-explain="The spec says SizeOfImage must be a multiple of SectionAlignment, so the exact end address is not allowed." onclick="checkQuiz('quiz-memory-2', this)">0x8030 — the exact end of the last section</button>
                    <button class="quiz-option" data-correct="true" data-explain="SizeOfImage must be a multiple of SectionAlignment. The next multiple of 0x1000 after 0x8030 is 0x9000 — which is exactly what cli-64.exe stores." onclick="checkQuiz('quiz-memory-2', this)">0x9000 — the next SectionAlignment boundary</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: memory sizes round to SectionAlignment, file sizes round to FileAlignment — never mix the two rulers.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The stage is set: image mapped, protections applied, stack and heap reserved. Only one address has not fired yet — AddressOfEntryPoint.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-execution">The Startup Sequence</a> — from entry point to CRT initialization to main.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-loader">Previous: How the Windows Loader Maps a PE</a></span>
                <span><a href="/courses/pe/lessons/pe-execution">Next: The Startup Sequence</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
