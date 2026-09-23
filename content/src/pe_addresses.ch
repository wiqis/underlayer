// PE Course — Concept 7: VA, RVA, and File Offset.
// Three address spaces: disk, image-relative, absolute memory.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_addresses() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("VA, RVA, and File Offset — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>VA, RVA, and File Offset</h1>
            <div class="lesson-meta">15 min · Module 3: Addressing &amp; Data Directories · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A PE file has one set of bytes but three different ways to name a position inside it. <code>xxd</code> shows file offsets. The data directories and the entry point store RVAs. Disassemblers, crash dumps, and the CPU itself deal in full virtual addresses. Confusing them is the single most common PE bug: a tool adds ImageBase to something already relative, or treats an RVA as a byte position on disk and reads the wrong row of the section table.</p>
                <p>The three are related by exactly two arithmetic operations — subtract ImageBase to get an RVA, add it to get a VA — plus a per-section translation between RVA and file offset that has no closed form. Get the vocabulary straight here and every later lesson is arithmetic instead of guesswork.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Picture one instruction living in two places at once — its bytes on disk, and its mapped copy in the process — with labels in different coordinate systems:</p>
                <pre>  ON DISK                              IN MEMORY (loaded at 0x140000000)
  +-----------------------------+      +-----------------------------------+
  | file offset 0x1140          | map  | VA 0x140001D40                   |
  | bytes: 48 83 ec 28         | ===&gt; | RVA 0x1D40                       |
  | (sub rsp, 0x28)            |      | bytes: 48 83 ec 28  (same code)  |
  +-----------------------------+      +-----------------------------------+
        ^                                     ^
        | read with xxd                      | executed by the CPU,
        | shown by tools that seek           | VA = ImageBase + RVA
        | the file directly                  |</pre>
                <ul>
                    <li><strong>File offset</strong> — a byte position on disk. Produced by: you, tools, <code>PointerToRawData</code>, <code>e_lfanew</code>, the Security directory.</li>
                    <li><strong>RVA (relative virtual address)</strong> — where something lands in memory once the image base is subtracted. Produced by the linker; stored in almost every structure: directories, entry point, section VirtualAddress, import thunks, relocations.</li>
                    <li><strong>VA (virtual address)</strong> — the runtime address: <code>VA = ImageBase + RVA</code>. Produced by the loader; what registers and crash logs contain.</li>
                </ul>
                <p>The model's missing piece: ImageBase is only a <em>preferred</em> base. Sample A asks for 0x140000000, Sample B for 0x00400000 — and both carry the DYNAMIC_BASE flag, so ASLR may load them somewhere else entirely.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's own definitions, in its words: an RVA is <em>"the address of an item after it is loaded into memory, with the base address of the image file subtracted from it,"</em> and it <em>"almost always differs from its position within the file on disk."</em> A VA is <em>"same as RVA, except that the base address of the image file is not subtracted"</em> — and because <em>"the loader might not load the image at its preferred location,"</em> a VA is unpredictable while an RVA is not.</p>
                <table>
                    <thead>
                        <tr><th scope="col">Address kind</th><th scope="col">Sample A example</th><th scope="col">Stored in</th><th scope="col">Stable under ASLR?</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>File offset</td><td>0x1140</td><td>PointerToRawData, e_lfanew, Security directory, anything <code>xxd</code> prints</td><td>Yes — the file never moves</td></tr>
                        <tr><td>RVA</td><td>0x1D40</td><td>AddressOfEntryPoint, data directories 0-3 and 5-15, section VirtualAddress, import/export/reloc records</td><td>Yes — image-relative</td></tr>
                        <tr><td>VA</td><td>0x140001D40</td><td>CPU registers, objdump VMA column, .pdata BeginAddress/EndAddress, crash dumps</td><td>No — moves when the loader rebases</td></tr>
                    </tbody>
                </table>
                <p>The two samples show the range: Sample A is PE32+ with an 8-byte ImageBase <code>00 00 00 40 01 00 00 00</code> at file 0x130 = 0x140000000, the usual high 64-bit base for EXEs. Sample B is PE32 with a 4-byte ImageBase <code>00 00 40 00</code> at file 0x134 = 0x00400000, the classic 32-bit default the spec documents. Same rule, different field width — PE32+ widened ImageBase to 8 bytes at optional-header offset 24.</p>
                <p>Where each one shows up in practice: data directories hold RVAs (except Security); <code>objdump -h</code> prints VMA = ImageBase + RVA (Sample A .text at 0x140001000) and file off separately; <code>objdump -p</code> prints the entry as an RVA (0x1d40) but the function table as VAs (0x140001401, 0x14000164c, ...).</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> "The VA is fixed because ImageBase is in the header" — no: with DYNAMIC_BASE set (Sample A DllCharacteristics 0x8160, Sample B 0x8140) the loader may place the image elsewhere, and only rebasing via base relocations keeps it correct. And "RVA is just a file offset" — the spec says it <em>almost always differs</em>: Sample A's entry RVA 0x1D40 sits at file 0x1140, a gap of 0xC00 that changes per section.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Take Sample A's entry point. The optional header stores RVA 0x1D40. At runtime, if the image loads at its preferred base, the CPU fetches from VA 0x140001D40. On disk you must translate through <code>.text</code> (VA 0x1000, raw pointer 0x400): file offset = 0x400 + (0x1D40 - 0x1000) = 0x1140. The bytes there are the program's first instructions:</p>
                <div class="hex-dump">
                    <pre>00001140: 4883 ec28 e8d7 0300 0048 83c4 28e9 72fe  H..(.....H..(.r.
00001150: ffff cccc 4053 4883 ec20 488b d933 c9ff  ....@SH.. H..3..</pre>
                </div>
                <p><code>48 83 ec 28</code> is <code>sub rsp, 0x28</code> — a function prologue. Three names for those same four bytes: offset 0x1140 (disk), RVA 0x1D40 (header), VA 0x140001D40 (running process).</p>
                <p>Sample B repeats the trick in 32-bit: entry RVA 0x1B87, ImageBase 0x00400000, so VA = 0x00401B87; <code>.text</code> (VA 0x1000, raw 0x400) gives file 0xF87, where the bytes are <code>e8 c5 03 00 00</code> — a relative <code>call</code>.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Read ImageBase and the entry point, then compute all three coordinates for any PE:</p>
                <pre><code>$ python3 -c "import struct; d=open('cli-64.exe','rb').read(); e=struct.unpack_from('&lt;I',d,0x3C)[0]; o=e+24; ib=struct.unpack_from('&lt;Q',d,o+24)[0]; ep=struct.unpack_from('&lt;I',d,o+16)[0]; print('ImageBase',hex(ib)); print('entry RVA',hex(ep)); print('entry VA ',hex(ib+ep))"
ImageBase 0x140000000
entry RVA 0x1d40
entry VA  0x140001d40

$ xxd -s 0x1140 -l 16 cli-64.exe
00001140: 4883 ec28 e8d7 0300 0048 83c4 28e9 72fe  H..(.....H..(.r.</code></pre>
                <p>Swap in <code>cli-32.exe</code> and change <code>'&lt;Q'</code> to <code>'&lt;I'</code> at offset 28 — PE32 stores ImageBase as 4 bytes after a BaseOfData field that PE32+ dropped.</p>
                <p>What to look for: RVA and VA always differ by exactly ImageBase (when loaded at base), while the file offset differs by a per-section amount that no single formula covers.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which of the three address kinds survives an ASLR rebase unchanged, and which structures keep using it while everything else moves?</p>
                <div class="quiz" id="quiz-addr-1">
                    <button class="quiz-option" data-correct="false" data-explain="VAs are ImageBase plus RVA. When the loader rebases the image, ImageBase changes, so every VA changes with it — that is why .pdata and crash logs must be interpreted against the actual load address." onclick="checkQuiz('quiz-addr-1', this)">The VA — it is the runtime truth, so it must be the stable one</button>
                    <button class="quiz-option" data-correct="true" data-explain="The RVA is relative to the image base, so rebasing shifts base and item together and the difference stays constant. File offsets are also stable, but they describe the disk, not memory — headers, directories and import records all keep RVAs while VAs move." onclick="checkQuiz('quiz-addr-1', this)">The RVA — data directories, entry point and section VirtualAddresses all store it</button>
                    <button class="quiz-option" data-correct="false" data-explain="File offsets are stable too, but they never appear inside memory structures: nothing in a running process is addressed by file offset (the Security directory is the lone exception, and it is not loaded at all)." onclick="checkQuiz('quiz-addr-1', this)">The file offset — the file on disk never rebases</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Sample A's import directory has RVA 0x3A04. One day Windows loads the image at 0x7FF600000000 instead of 0x140000000. What is the import directory's VA then, and what stays the same?</p>
                <div class="quiz" id="quiz-addr-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x7FF600003A04 would require the RVA to change to 0x3A04 plus the rebase delta. RVAs never change — the image is mapped as one block, so the offset from the base is fixed." onclick="checkQuiz('quiz-addr-2', this)">VA 0x7FF600003A04, and the RVA changes to match the new base</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x140003A04 is the preferred-base VA, not the actual one. After a rebase you must use the real load address, which is why tools read the image base from the loader rather than trusting the header." onclick="checkQuiz('quiz-addr-2', this)">VA 0x140003A04, because ImageBase in the header is authoritative</button>
                    <button class="quiz-option" data-correct="true" data-explain="VA = actual base + RVA = 0x7FF600000000 + 0x3A04 = 0x7FF600003A04. The RVA 0x3A04 stays as written in the header, and the file offset (0x2604) is untouched — only the VA follows the loader." onclick="checkQuiz('quiz-addr-2', this)">VA 0x7FF600003A04; the RVA 0x3A04 and file offset 0x2604 stay unchanged</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: convert VA to RVA by subtracting whatever base is actually in use, then use the section table to reach the file. Both steps are reversible; neither is optional.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now name any position three ways. What you cannot yet do mechanically is the middle step — turning an RVA from a directory into the byte offset you feed <code>xxd</code>. That translation is exactly the section table's job, but the algorithm comes first.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-rva-conversion">Converting RVAs to File Offsets</a> — the per-section algorithm, why no constant offset works, and the span check that catches the classic bug.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-data-directories">Previous: The Data Directories</a></span>
                <span><a href="/courses/pe/lessons/pe-rva-conversion">Next: Converting RVAs to File Offsets</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
