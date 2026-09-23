// PE Course — Concept 11: Alignment — FileAlignment vs SectionAlignment.
// Two rulers, SizeOfImage/SizeOfHeaders math, and the overlay question.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_alignment() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Alignment: FileAlignment vs SectionAlignment — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Alignment: FileAlignment vs SectionAlignment</h1>
            <div class="lesson-meta">15 min · Module 4: Sections · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Two rulers govern every PE file, and they almost never agree. On disk, section data is padded to FileAlignment — historically 512 bytes, the granularity disks and installers care about. In memory, sections are placed on SectionAlignment boundaries — typically 4096, the page size the MMU maps. The gap between the rulers explains why Sample A is 14336 bytes on disk yet claims a SizeOfImage of 0x9000, why VirtualSize and SizeOfRawData disagree, and why a naive parser that assumes file offset equals RVA reads garbage after byte 0x400.</p>
                <p>Get the two straight and several PE mysteries collapse into arithmetic you can do by hand: header size, image size, padding, and whether a file carries extra trailing bytes at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Hold two rulers against the same content:</p>
                <pre>DISK ruler: FileAlignment = 0x200
  [headers........][.text..........pad][.rdata.....pad][.data][.pdata][.rsrc][.reloc]
   rounded to 0x200   each PointerToRawData multiple of 0x200

MEMORY ruler: SectionAlignment = 0x1000
  [page 0: headers][page 1: .text][gap][page 3: .rdata][gap][.data]...
   each VirtualAddress multiple of 0x1000; SizeOfImage = end rounded to 0x1000</pre>
                <ol>
                    <li><strong>FileAlignment</strong> pads bytes <em>in the file</em>: SizeOfHeaders and every PointerToRawData / SizeOfRawData are multiples of it. Spec: a power of two, 512 to 64K, default 512.</li>
                    <li><strong>SectionAlignment</strong> pads space <em>in memory</em>: every section VirtualAddress and the total SizeOfImage are multiples of it. Spec: at least FileAlignment, default the architecture page size.</li>
                    <li><strong>The trap:</strong> if SectionAlignment is smaller than the page size, the spec forces FileAlignment to match it and requires file offsets to equal RVAs — a special mode, not our samples' mode.</li>
                </ol>
                <p>The model's missing piece: the two summary fields, SizeOfHeaders and SizeOfImage, are just the rulers applied to the header block and to the last section's end.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's definitions: SizeOfImage is <em>"the size of the image, as loaded in memory"</em> and <em>"must be a multiple of SectionAlignment"</em>; SizeOfHeaders is <em>"the combined size of an MS-DOS stub, PE header, and section headers rounded up to a multiple of FileAlignment."</em> Both samples agree with the defaults — SectionAlignment and FileAlignment live at optional-header offsets 32 and 36, i.e. file 0x138 and 0x13C in these files:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Field</th><th scope="col">Sample A (PE32+)</th><th scope="col">Sample B (PE32)</th><th scope="col">How it is computed</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>SectionAlignment</td><td>0x1000</td><td>0x1000</td><td>Read at file 0x138 — the memory ruler</td></tr>
                        <tr><td>FileAlignment</td><td>0x200</td><td>0x200</td><td>Read at file 0x13C — the disk ruler</td></tr>
                        <tr><td>SizeOfHeaders</td><td>0x400</td><td>0x400</td><td>A: headers end 0x2F8, rounded up to 0x200 — B: table at 0x1F8 + 5 rows ends 0x2C0, rounded to 0x400</td></tr>
                        <tr><td>SizeOfImage</td><td>0x9000</td><td>0x7000</td><td>A: 0x8000 + VirtualSize 0x30 = 0x8030, rounded up to 0x1000 — B: 0x6000 + 0x1CC = 0x61CC, rounded to 0x7000</td></tr>
                        <tr><td>File size</td><td>14336 (0x3800)</td><td>11776 (0x2E00)</td><td>Equals last PointerToRawData + SizeOfRawData in both files</td></tr>
                    </tbody>
                </table>
                <p>Where each ruler applies: headers block — DOS stub, signature, COFF, optional header, section table (0x2F8 raw bytes in A) — padded by FileAlignment to 0x400, which is also why the first PointerToRawData is 0x400 and not 0x2F8. Section VAs step by 0x1000: 0x1000, 0x3000, 0x5000, 0x6000, 0x7000, 0x8000. Raw pointers step by FileAlignment multiples: 0x400, 0x1C00, 0x3000, 0x3200, 0x3400, 0x3600.</p>
                <p><strong>The overlay question, computed:</strong> Sample A's last section <code>.reloc</code> has PointerToRawData 0x3600 plus SizeOfRawData 0x200 = 0x3800, and the file is exactly 14336 = 0x3800 bytes — <strong>zero trailing bytes, no overlay</strong>. Sample B: 0x2C00 + 0x200 = 0x2E00 = 11776 = file size, also no overlay. Signed binaries are where tails appear: <code>OpenConsole.exe</code>'s sections end at 0x100E00, the Security directory (a file offset, per the spec) points at 0x100E00 with size 0x3D20, and 0x100E00 + 0x3D20 = 0x104B20 = the file size — a WIN_CERTIFICATE block appended past the sections because the loader never maps it.</p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> Comparing SizeOfImage to file size — A's image claims 0x9000 bytes in memory while the file is 0x3800; headers plus gaps plus rounded ends live only in memory. And assuming raw size equals VirtualSize — A's <code>.text</code> carries 0x44 padding bytes on disk (0x1800 - 0x17BC) while its <code>.data</code> is short by 0x448 (0x648 - 0x200), the zero-fill tail. Both are normal alignment outcomes, not corruption.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>SizeOfHeaders for Sample A, by hand. The section table starts at 0x208; six rows of 40 bytes is 240 (0xF0) bytes, so raw headers end at 0x2F8. Round up to FileAlignment 0x200:</p>
                <pre>0x2F8 = 762 bytes of actual header
round up to multiple of 0x200: 762 / 512 = 1.49 -&gt; 2 sectors
SizeOfHeaders = 2 x 0x200 = 0x400          (matches the header field)</pre>
                <p>SizeOfImage for Sample A, by hand: the last section's memory end is VirtualAddress 0x8000 + VirtualSize 0x30 = 0x8030. Round up to SectionAlignment 0x1000: 0x8030 lies inside the 0x8000 page run, so the image occupies pages through 0x8FFF and SizeOfImage = 0x9000 — exactly what <code>objdump -p</code> prints.</p>
                <pre>last section end: 0x8000 + 0x0030 = 0x8030
round up to 0x1000: ((0x8030 + 0x0FFF) / 0x1000) * 0x1000 = 0x9000</pre>
                <p>And the padding baked into <code>.text</code>: VirtualSize 0x17BC (5564 bytes of code) versus SizeOfRawData 0x1800 (6144 bytes on disk) — a difference of 0x44 = 68 bytes of FileAlignment filler after the last instruction. On disk the section ends at 0x400 + 0x1800 = 0x1C00, which is precisely where <code>.rdata</code>'s PointerToRawData begins: sections butt together on the disk ruler with no gaps, while on the memory ruler each gets its own 0x1000-aligned region.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Verify all three facts — header rounding, image rounding, and overlay — in one script:</p>
                <pre><code>$ python3 -c "
import struct, os
d = open('cli-64.exe','rb').read()
e = struct.unpack_from('&lt;I', d, 0x3C)[0]
o = e + 24
sa = struct.unpack_from('&lt;I', d, o+32)[0]
fa = struct.unpack_from('&lt;I', d, o+36)[0]
soimg = struct.unpack_from('&lt;I', d, o+56)[0]
sohdr = struct.unpack_from('&lt;I', d, o+60)[0]
n = struct.unpack_from('&lt;H', d, e+6)[0]
hdr_end = o + 0xF0 + 40*n
print('align   ', hex(sa), hex(fa))
print('headers ', hex(hdr_end), '-&gt; stored', hex(sohdr))
print('image   ', 'stored', hex(soimg))
last = max(struct.unpack_from('&lt;I', d, o+0xF0+40*i+20)[0] + struct.unpack_from('&lt;I', d, o+0xF0+40*i+16)[0] for i in range(n))
print('file    ', hex(len(d)), 'last raw end', hex(last), 'overlay', len(d)-last)
"
align    0x1000 0x200
headers  0x2f8 -&gt; stored 0x400
image    stored 0x9000
file     0x3800 last raw end 0x3800 overlay 0</code></pre>
                <p>The quick disassembler view of the same numbers:</p>
                <pre><code>$ objdump -p cli-64.exe | grep -E 'SectionAlignment|FileAlignment|SizeOfImage|SizeOfHeaders'
SectionAlignment     00001000
FileAlignment        00000200
SizeOfImage          00009000
SizeOfHeaders        00000400

$ stat -c %s cli-64.exe
14336</code></pre>
                <p>What to look for: SectionAlignment is always the bigger ruler (0x1000 vs 0x200), SizeOfHeaders equals the first section's PointerToRawData when headers are padded normally, and overlay shows up as a positive <code>len(d) - last</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: Sample A's headers (DOS stub through section table) end at file offset 0x2F8, and FileAlignment is 0x200. What must SizeOfHeaders be, and why?</p>
                <div class="quiz" id="quiz-al-1">
                    <button class="quiz-option" data-correct="false" data-explain="0x2F8 is the unrounded truth, but the spec says SizeOfHeaders is the header block rounded up to a multiple of FileAlignment — the field must never be 0x2F8." onclick="checkQuiz('quiz-al-1', this)">0x2F8 — SizeOfHeaders stores the exact end of the section table</button>
                    <button class="quiz-option" data-correct="false" data-explain="SectionAlignment is the memory ruler (0x1000 here). SizeOfHeaders is explicitly rounded to FileAlignment, not SectionAlignment — rounding to 0x1000 would waste a page on disk." onclick="checkQuiz('quiz-al-1', this)">0x1000 — headers are padded with SectionAlignment like other memory</button>
                    <button class="quiz-option" data-correct="true" data-explain="Round 0x2F8 up to the next multiple of FileAlignment 0x200: the next multiple after 0x2F8 is 0x400. That matches the stored field (0x400) and explains why .text PointerToRawData starts at 0x400 — the gap from 0x2F8 to 0x400 is header padding." onclick="checkQuiz('quiz-al-1', this)">0x400 — 0x2F8 rounded up to the next 0x200 boundary</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>Someone claims Sample A has an overlay because SizeOfImage (0x9000) is larger than the file (0x3800). Check the real test: last PointerToRawData 0x3600 + SizeOfRawData 0x200 = 0x3800, file size 14336. Does an overlay exist?</p>
                <div class="quiz" id="quiz-al-2">
                    <button class="quiz-option" data-correct="false" data-explain="SizeOfImage counts memory-only material: FileAlignment gaps, SectionAlignment rounding, and header space mapped at RVA 0. Comparing it to file size always makes files look short — that is not what overlay means." onclick="checkQuiz('quiz-al-2', this)">Yes — 0x9000 minus 0x3800 = 0x5800 bytes must be an overlay</button>
                    <button class="quiz-option" data-correct="false" data-explain="Nothing is appended after .reloc: the raw end and the file size are the same number. Zero overlay bytes either way — but the reasoning must use raw ends, not SizeOfImage." onclick="checkQuiz('quiz-al-2', this)">Yes — the last section ends before SizeOfImage, so trailing bytes exist</button>
                    <button class="quiz-option" data-correct="true" data-explain="Overlay means bytes past the last section's raw data: 0x3600 + 0x200 = 0x3800 = 14336 = the file size, so the file ends exactly where .reloc ends — no overlay. Signed files are the counter-example: OpenConsole.exe appends its certificate table (0x100E00, size 0x3D20) past the sections, ending exactly at EOF 0x104B20." onclick="checkQuiz('quiz-al-2', this)">No — last raw end 0x3800 equals file size, so overlay is zero bytes</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: SizeOfImage answers "how big is this in memory", file size answers "how many bytes are on disk", and the overlay test compares file size to the last PointerToRawData plus SizeOfRawData. Three different questions, three different numbers.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Alignment closes Module 3 and Module 4: you can locate every structure, name every address kind, translate RVA to file offset, and now explain every size field in the optional header. The section table also showed you directory RVAs hiding inside <code>.rdata</code> — import descriptors at 0x3A04, the IAT at 0x3000 — without saying how those tables are shaped.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-imports">The Import Tables</a> — how a PE names the DLLs and functions it needs, and how the loader turns names into callable addresses.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-common-sections">Previous: Common Sections</a></span>
                <span><a href="/courses/pe/lessons/pe-imports">Next: The Import Tables</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
