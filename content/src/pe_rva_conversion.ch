// PE Course — Concept 8: Converting RVAs to File Offsets.
// The section-span algorithm, worked on real bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_rva_conversion() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Converting RVAs to File Offsets — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Converting RVAs to File Offsets</h1>
            <div class="lesson-meta">15 min · Module 3: Addressing &amp; Data Directories · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every tool that inspects a PE off disk hits the same wall: the headers hand you RVAs, but the bytes live at file offsets. The import directory says 0x3A04; <code>xxd</code> wants a byte position. Dumpbin, debuggers, signature checkers, unpackers, malware analyzers — all of them run this conversion thousands of times per file, and all of them break in the same way when it is wrong: they parse whatever bytes happen to sit at the bad offset and produce confidently bogus tables.</p>
                <p>The conversion is also the moment the section table earns its keep. Without it, the section table is just names and numbers; with it, the table becomes the translation function between memory and disk.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>You might hope for one subtraction: file = RVA - constant. It cannot work, because each section is padded differently between memory and disk. Sample A proves it with three sections:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">VirtualAddress</th><th scope="col">PointerToRawData</th><th scope="col">VA minus raw (the would-be constant)</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>.text</td><td>0x1000</td><td>0x400</td><td>0xC00</td></tr>
                        <tr><td>.rdata</td><td>0x3000</td><td>0x1C00</td><td>0x1400</td></tr>
                        <tr><td>.data</td><td>0x5000</td><td>0x3000</td><td>0x2000</td></tr>
                    </tbody>
                </table>
                <p>Three different deltas in one file. So the model is: <strong>find which section owns the RVA, then apply that section's own delta.</strong></p>
                <ol>
                    <li>Locate the section whose memory span contains the RVA.</li>
                    <li>Compute delta = RVA - that section's VirtualAddress.</li>
                    <li>Add delta to that section's PointerToRawData.</li>
                </ol>
                <p>The model's missing piece: "memory span" must be measured with <code>max(VirtualSize, SizeOfRawData)</code> — and a delta can land in a region that exists in memory but has no bytes on disk.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The algorithm, exactly as a parser should implement it:</p>
                <pre><code>input: RVA
if RVA &lt; first section VirtualAddress (0x1000 in Sample A):
    return RVA            (headers map at file offset equal to RVA)
for each section s:
    span = max(s.VirtualSize, s.SizeOfRawData)
    if s.VirtualAddress &lt;= RVA &lt; s.VirtualAddress + span:
        delta = RVA - s.VirtualAddress
        if delta &gt;= s.SizeOfRawData:
            return NO DISK BYTES   # zero-fill tail, memory only
        return s.PointerToRawData + delta
return ERROR              # RVA not owned by any section</code></pre>
                <p>Why <code>max(VirtualSize, SizeOfRawData)</code> for the span: VirtualSize is the true in-memory size, SizeOfRawData is the FileAlignment-padded size on disk, and <em>either can be larger</em>. Sample A's <code>.text</code> has VirtualSize 0x17BC but 0x1800 bytes on disk — the extra 0x44 bytes are alignment padding, real file bytes inside the section's disk extent. Sample A's <code>.data</code> runs the other way: VirtualSize 0x648, only 0x200 bytes on disk — the remaining 0x448 bytes are the zero-filled tail (uninitialized data) that exists in memory and nowhere in the file. Using VirtualSize alone wrongly rejects padded-but-present bytes; using SizeOfRawData alone wrongly accepts nothing for shrinking sections. The spec puts it directly: SizeOfRawData <em>"is rounded but the VirtualSize field is not, it is possible for SizeOfRawData to be greater than VirtualSize as well."</em></p>
                <p>Worked example, verified byte for byte: the import directory has RVA 0x3A04. It falls in <code>.rdata</code> (VirtualAddress 0x3000, VirtualSize 0x132C, SizeOfRawData 0x1400, PointerToRawData 0x1C00), since 0x3000 &lt;= 0x3A04 &lt; 0x3000 + 0x1400. Delta = 0x3A04 - 0x3000 = 0xA04, which is less than 0x1400, so file offset = 0x1C00 + 0xA04 = <strong>0x2604</strong>.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Subtracting one global constant — fails for every section after the first, as the delta table above shows. Testing membership with VirtualSize only — misses the alignment padding the spec says is normal. And converting the Security directory at all — its field is already a file offset, so it skips this algorithm entirely (directory index 4).
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>At file offset 0x2604 — the conversion result for RVA 0x3A04 — sit the first import descriptors, little-endian RVAs throughout:</p>
                <div class="hex-dump">
                    <pre>00002604: e03a 0000 0000 0000 0000 0000 e23d 0000  .:...........=..
00002614: 0030 0000 a03b 0000 0000 0000 0000 0000  .0...;..........</pre>
                </div>
                <p>Decode: OriginalFirstThunk = 0x3AE0, TimeDateStamp = 0, ForwarderChain = 0, Name = 0x3DE2, FirstThunk = 0x3000 — the descriptor <code>objdump</code> reports as <code>vma: 00003a04 ... 00003ae0 ... 00003de2 00003000</code>. The conversion landed on exactly the right bytes.</p>
                <p>Second conversion, the entry point: RVA 0x1D40 lies in <code>.text</code> (0x1000, raw 0x400, raw size 0x1800). Delta 0xD40 &lt; 0x1800, so file = 0x400 + 0xD40 = 0x1140, where the machine code <code>48 83 ec 28</code> waits. Two sections, two deltas, one algorithm.</p>
                <p>A case with no disk bytes: RVA 0x5700 sits in <code>.data</code> (VirtualAddress 0x5000, VirtualSize 0x648, SizeOfRawData 0x200). Membership holds (delta 0x700 &lt; 0x648), but delta 0x700 is greater than SizeOfRawData 0x200 — there is no file byte at 0x5700; at runtime the loader zero-fills it. A converter that blindly adds PointerToRawData would read 0x3700, which is <code>.reloc</code> bytes — the classic silent misparse.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Run the algorithm on Sample A for any RVA:</p>
                <pre><code>$ python3 -c "
import struct
d = open('cli-64.exe','rb').read()
secs = []
st = 0x208
for i in range(6):
    o = st + 40*i
    vs, va, sr, pr = struct.unpack_from('&lt;IIII', d, o+8)
    secs.append((d[o:o+8].split(b'\x00')[0], vs, va, sr, pr))
def rva2off(rva):
    for name, vs, va, sr, pr in secs:
        if va &lt;= rva &lt; va + max(vs, sr):
            delta = rva - va
            return None if delta &gt;= sr else pr + delta
    return rva
print(hex(rva2off(0x3A04)))   # 0x2604
print(hex(rva2off(0x1D40)))   # 0x1140
"</code></pre>
                <p>Then confirm the bytes by hand — the two checks that never lie:</p>
                <pre><code>$ xxd -s 0x2604 -l 32 cli-64.exe
00002604: e03a 0000 0000 0000 0000 0000 e23d 0000  .:...........=..
$ xxd -s 0x1140 -l 16 cli-64.exe
00001140: 4883 ec28 e8d7 0300 0048 83c4 28e9 72fe  H..(.....H..(.r.</code></pre>
                <p>Or skip the code entirely: <code>objdump -p cli-64.exe</code> prints every directory RVA, and <code>objdump -h</code> prints each section's file off — do one subtraction by hand to feel the delta change between sections.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: why is there no single constant you can subtract from an RVA to get a file offset?</p>
                <div class="quiz" id="quiz-rva-1">
                    <button class="quiz-option" data-correct="false" data-explain="Both fields are multiples of FileAlignment in this file, but alignment does not make the difference constant: .text differs by 0xC00, .rdata by 0x1400, .data by 0x2000." onclick="checkQuiz('quiz-rva-1', this)">Because RVAs are always unaligned while file offsets are FileAlignment multiples</button>
                    <button class="quiz-option" data-correct="true" data-explain="Memory and disk are padded independently per section. VirtualAddress minus PointerToRawData is 0xC00 for .text, 0x1400 for .rdata, 0x2000 for .data in Sample A — the delta is a property of the owning section, so you must look up the section first." onclick="checkQuiz('quiz-rva-1', this)">Each section has its own VA-to-raw delta: 0xC00, 0x1400, 0x2000 in Sample A</button>
                    <button class="quiz-option" data-correct="false" data-explain="The headers do map at file offset equal to RVA, but that only holds below the first section (RVA under 0x1000 here). Section data breaks the identity immediately." onclick="checkQuiz('quiz-rva-1', this)">Because RVAs below 0x1000 use file = RVA while section RVAs do not</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Convert entry point RVA 0x1D40 by hand. From the section table: <code>.text</code> has VirtualAddress 0x1000, VirtualSize 0x17BC, SizeOfRawData 0x1800, PointerToRawData 0x400.</p>
                <div class="quiz" id="quiz-rva-2">
                    <button class="quiz-option" data-correct="false" data-explain="That would mean delta 0xD40 plus raw 0x400 uses the section base 0x0 — but .text starts at RVA 0x1000, not 0. You forgot to subtract VirtualAddress." onclick="checkQuiz('quiz-rva-2', this)">0x1D40 minus nothing: file 0x1D40</button>
                    <button class="quiz-option" data-correct="false" data-explain="Using .rdata is a span-check failure: 0x1D40 is not between 0x3000 and 0x4400, so that section does not own the RVA. Correct span test first, arithmetic second." onclick="checkQuiz('quiz-rva-2', this)">0x2604, by treating it as if .rdata owned the RVA</button>
                    <button class="quiz-option" data-correct="true" data-explain="Span check: 0x1000 &lt;= 0x1D40 &lt; 0x1000 + 0x1800 (raw exceeds VirtualSize 0x17BC, so max is 0x1800) — .text owns it. Delta 0x1D40 - 0x1000 = 0xD40, which is less than SizeOfRawData, so file = 0x400 + 0xD40 = 0x1140, where the bytes 48 83 ec 28 sit." onclick="checkQuiz('quiz-rva-2', this)">0x1140: delta 0xD40, then 0x400 + 0xD40</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: span test with max(), subtract VirtualAddress, reject the zero-fill tail, add PointerToRawData. Four steps, in that order, every time.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The algorithm leaned on four fields per section — VirtualAddress, VirtualSize, SizeOfRawData, PointerToRawData — without saying where they come from. They are four of the ten fields in the 40-byte section header, the structure that starts right after the optional header.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-section-table">The Section Table</a> — the 40-byte record decoded field by field against real bytes, including the eight-character name rule.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-addresses">Previous: VA, RVA, and File Offset</a></span>
                <span><a href="/courses/pe/lessons/pe-section-table">Next: The Section Table</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
