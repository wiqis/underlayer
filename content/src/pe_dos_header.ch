// PE Course — Concept 4: The MS-DOS Header.
// All 64 bytes of IMAGE_DOS_HEADER, why it survives, and which fields Windows still reads.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_dos_header() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The MS-DOS Header — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The MS-DOS Header</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every PE file opens with an MS-DOS header — a 64-byte structure defined in <code>winnt.h</code> as <code>IMAGE_DOS_HEADER</code>. Windows reads it before it reads anything else: first the magic <code>MZ</code>, then one pointer at offset <code>0x3C</code> that jumps the loader years forward in time to the PE header. If either check fails, the file never loads.</p>
                <p>Yet most of the 64 bytes describe a 16-bit MS-DOS program that modern Windows never runs. Learning to tell the two live fields apart from the historical ones is the difference between reading the DOS header and being confused by it. The specification is direct: the region from the MS-DOS header through the stub "is used for MS-DOS compatibility only."</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the DOS header as a business card from 1985 with one modern instruction written on the back:</p>
                <ul>
                    <li><strong>The front (offsets 0x00–0x3B)</strong> is the original MZ envelope: magic, file-size fields, a fake stack pointer, entry point, relocation table address. These existed so MS-DOS could load and run the file as a 16-bit executable. The NT loader ignores them.</li>
                    <li><strong>The back (offset 0x3C)</strong> is <code>e_lfanew</code> — a single 32-bit file offset added when Windows NT came along. It points at the PE signature. This is the hinge between the 1980s half of the file and the modern half.</li>
                    <li><strong>After the header (0x40 onward)</strong> sits the DOS stub: a tiny real program that prints "This program cannot be run in DOS mode." under MS-DOS, and does nothing under Windows.</li>
                </ul>
                <p>The model's missing piece: the header's size is itself stored in the header. Field <code>e_cparhdr</code> gives the header size in 16-byte paragraphs — in our sample it is 4, so 4 × 16 = 64 bytes, which is exactly where the stub begins.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The full field walk of <code>IMAGE_DOS_HEADER</code> (offsets from the <code>winnt.h</code> structure), with Sample A's real values — setuptools' 64-bit <code>cli-64.exe</code>:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Off</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">winnt.h comment</th><th scope="col">Sample A</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>2</td><td><code>e_magic</code></td><td>Magic number</td><td>0x5A4D ("MZ")</td></tr>
                        <tr><td>0x02</td><td>2</td><td><code>e_cblp</code></td><td>Bytes on last page of file</td><td>0x0090 (144)</td></tr>
                        <tr><td>0x04</td><td>2</td><td><code>e_cp</code></td><td>Pages in file</td><td>0x0003</td></tr>
                        <tr><td>0x06</td><td>2</td><td><code>e_crlc</code></td><td>Relocations</td><td>0x0000</td></tr>
                        <tr><td>0x08</td><td>2</td><td><code>e_cparhdr</code></td><td>Size of header in paragraphs</td><td>0x0004 (4 × 16 = 64 bytes)</td></tr>
                        <tr><td>0x0A</td><td>2</td><td><code>e_minalloc</code></td><td>Minimum extra paragraphs needed</td><td>0x0000</td></tr>
                        <tr><td>0x0C</td><td>2</td><td><code>e_maxalloc</code></td><td>Maximum extra paragraphs needed</td><td>0xFFFF</td></tr>
                        <tr><td>0x0E</td><td>2</td><td><code>e_ss</code></td><td>Initial (relative) SS value</td><td>0x0000</td></tr>
                        <tr><td>0x10</td><td>2</td><td><code>e_sp</code></td><td>Initial SP value</td><td>0x00B8 (184)</td></tr>
                        <tr><td>0x12</td><td>2</td><td><code>e_csum</code></td><td>Checksum</td><td>0x0000</td></tr>
                        <tr><td>0x14</td><td>2</td><td><code>e_ip</code></td><td>Initial IP value</td><td>0x0000</td></tr>
                        <tr><td>0x16</td><td>2</td><td><code>e_cs</code></td><td>Initial (relative) CS value</td><td>0x0000</td></tr>
                        <tr><td>0x18</td><td>2</td><td><code>e_lfarlc</code></td><td>File address of relocation table</td><td>0x0040</td></tr>
                        <tr><td>0x1A</td><td>2</td><td><code>e_ovno</code></td><td>Overlay number</td><td>0x0000</td></tr>
                        <tr><td>0x1C</td><td>8</td><td><code>e_res[4]</code></td><td>Reserved words</td><td>all zero</td></tr>
                        <tr><td>0x24</td><td>2</td><td><code>e_oemid</code></td><td>OEM identifier (for e_oeminfo)</td><td>0x0000</td></tr>
                        <tr><td>0x26</td><td>2</td><td><code>e_oeminfo</code></td><td>OEM information; e_oemid specific</td><td>0x0000</td></tr>
                        <tr><td>0x28</td><td>20</td><td><code>e_res2[10]</code></td><td>Reserved words</td><td>all zero</td></tr>
                        <tr><td><strong>0x3C</strong></td><td>4</td><td><code>e_lfanew</code></td><td>File address of new exe header</td><td><strong>0x00000100</strong></td></tr>
                    </tbody>
                </table>
                <p><strong>Why it still exists.</strong> The specification explains it plainly: at location 0x3c the stub stores the file offset to the PE signature, and "this information enables Windows to properly execute the image file, even though it has an MS-DOS stub." The stub itself is a valid MS-DOS application the linker places at the front — replaceable with the <code>/STUB</code> linker option. Tools that expect MZ executables still recognize the file; Windows reads MZ, follows <code>e_lfanew</code>, and never looks back.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Believing all 64 bytes must be valid for Windows to run the file. Matt Pietrek's classic MSDN PE article puts it bluntly: "The only two values of any importance are e_magic and e_lfanew." Fields like <code>e_cblp</code>, <code>e_sp</code>, and <code>e_cs</code> describe the 16-bit stub's view of the world (size, stack, entry) — the NT loader never reads them. Corrupt <code>e_lfanew</code> and the file dies; corrupt <code>e_sp</code> and Windows does not care.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first 64 bytes of <code>cli-64.exe</code>:</p>
                <div class="hex-dump">
                    <pre>00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
00000010: b800 0000 0000 0000 4000 0000 0000 0000  ........@.......
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0001 0000  ................</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>Bytes 0–1: <code>4d 5a</code> — "MZ", the magic named after Mark Zbikowski, an original MS-DOS architect. Any tool checking "is this a DOS or Windows executable?" stops here.</li>
                    <li>Bytes 0x08–0x09: <code>04 00</code> — <code>e_cparhdr</code> = 4 paragraphs = 64 bytes. The DOS stub therefore begins at 0x40.</li>
                    <li>Bytes 0x3C–0x3F: <code>00 01 00 00</code> — little-endian 0x00000100. The PE signature lives at file offset 0x100. This is the only field besides the magic that the NT loader trusts.</li>
                </ol>
                <p>And immediately after the 64-byte header, the stub (file offset 0x40) — real 16-bit code ending in its message string at 0x4E:</p>
                <div class="hex-dump">
                    <pre>00000040: 0e1f ba0e 00b4 09cd 21b8 014c cd21 5468  ........!..L.!Th
00000050: 6973 2070 726f 6772 616d 2063 616e 6e6f  is program canno
00000060: 7420 6265 2072 756e 2069 6e20 444f 5320  t be run in DOS 
00000070: 6d6f 6465 2e0d 0d0a 2400 0000 0000 0000  mode....$.......</pre>
                </div>
                <p>Decode the code: <code>0e 1f</code> push cs / pop ds; <code>ba 0e 00</code> mov dx, 0x000E — the message offset, 0x40 + 0x0E = 0x4E, where "This program…" begins; <code>b4 09 cd 21</code> print string via DOS int 21h AH=9 (terminated by the <code>$</code> at 0x78); <code>b8 01 4c cd 21</code> exit with code 1. The whole compatibility story — runnable under DOS, decisive under Windows — is these 19 bytes.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Dump the header, then isolate the hinge field on any PE file:</p>
                <pre><code>$ xxd -l 64 cli-64.exe
00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
00000010: b800 0000 0000 0000 4000 0000 0000 0000  ........@.......
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0001 0000  ................

$ xxd -s 0x3c -l 4 cli-64.exe
0000003c: 0001 0000                                ....</code></pre>
                <p>On Windows, PowerShell reads the same field without extra tools:</p>
                <pre><code>&gt; $b = [System.IO.File]::ReadAllBytes(".\notepad.exe")
&gt; [System.BitConverter]::ToUInt32($b, 0x3C)
240          # e_lfanew — PE signature is at file offset 240</code></pre>
                <p>What to look for: the first two bytes are always <code>4d 5a</code>, and the four bytes at 0x3C are little-endian — swap them mentally (<code>00 01 00 00</code> → 0x100) and you have the address of the next layer. Try two different executables; the <code>e_lfanew</code> values will often differ.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: which DOS header fields does the NT loader actually depend on, and what does each do?</p>
                <div class="quiz" id="quiz-dos-1">
                    <button class="quiz-option" data-correct="true" data-explain="e_magic must be MZ (0x5A4D) so Windows recognizes an executable at all, and e_lfanew at offset 0x3C holds the file offset of the PE signature — the pointer to everything modern." onclick="checkQuiz('quiz-dos-1', this)">e_magic (confirms MZ) and e_lfanew (points to the PE signature)</button>
                    <button class="quiz-option" data-correct="false" data-explain="e_cblp and e_cp are DOS-era size fields — 'bytes on last page' and 'pages in file'. The NT loader never reads them." onclick="checkQuiz('quiz-dos-1', this)">e_cblp and e_cp (so Windows knows the file size)</button>
                    <button class="quiz-option" data-correct="false" data-explain="e_sp and e_cs are the 16-bit stub's stack pointer and code segment — only meaningful to the real-mode DOS loader, not to NT." onclick="checkQuiz('quiz-dos-1', this)">e_sp and e_cs (so the stub can start executing)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A PE file has <code>e_cparhdr</code> = 4 at offset 0x08. Where does the DOS stub begin, and why?</p>
                <div class="quiz" id="quiz-dos-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x08 is where the e_cparhdr field itself lives, not where the stub begins." onclick="checkQuiz('quiz-dos-2', this)">At offset 0x08, because that is where the field is</button>
                    <button class="quiz-option" data-correct="true" data-explain="e_cparhdr counts header size in 16-byte paragraphs: 4 × 16 = 64 = 0x40. The DOS header occupies 0x00–0x3F, so the stub starts at 0x40 — which is exactly where our sample's int 21h code sits." onclick="checkQuiz('quiz-dos-2', this)">At offset 0x40 — 4 paragraphs × 16 bytes = 64</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x100 is where e_lfanew points — the PE signature, after the whole stub. The stub comes before it." onclick="checkQuiz('quiz-dos-2', this)">At offset 0x100, right before the PE header</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: MZ at 0, e_lfanew at 0x3C, stub at e_cparhdr × 16. Three numbers, and you can navigate the entire DOS layer.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You can now read all 64 bytes — and know that Windows only trusts two of them. Follow <code>e_lfanew</code> and you land on the 4-byte signature that opens the modern format, immediately followed by the 20-byte COFF header you already met from the object-file side.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-signature-coff">PE Signature and COFF Header</a> — verifying <code>PE\0\0</code>, then decoding every COFF field, with both Characteristics flags fully unpacked.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-coff-basics">Previous: The COFF Heritage</a></span>
                <span><a href="/courses/pe/lessons/pe-signature-coff">Next: PE Signature and COFF Header</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
