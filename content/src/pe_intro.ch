// PE Course — Concept 1: Why the Portable Executable Format Exists.
// The MZ-PE chain and the map of the course.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Why PE Exists — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Why the Portable Executable Format Exists</h1>
            <div class="lesson-meta">15 min · Module 1: Fundamentals · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Double-click <code>notepad.exe</code> and Windows loads it into memory and runs it. But the file on disk is just bytes. How does Windows know that these bytes are executable, which byte is the first instruction to run, where the code ends and the data begins, and which functions it must resolve from <code>KERNEL32.dll</code> before your program can call anything?</p>
                <p>The Portable Executable format answers all of those questions. It is the contract between the linker that builds a Windows program and the Windows loader that runs it. If you have ever wondered what a hex editor sees when it opens an <code>.exe</code>, or how malware injection, code signing, or <code>Dumpbin</code> work under the hood, this format is the whole story.</p>
                <p>Without a defined layout, no program could be loaded — every compiler would invent its own file structure, and the operating system could not run any of them.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a PE file as two documents glued together, front to back:</p>
                <ol>
                    <li><strong>A 1980s MS-DOS program</strong> — a tiny stub that starts with the letters <code>MZ</code>. If you run a modern <code>.exe</code> under MS-DOS it prints <em>"This program cannot be run in DOS mode."</em> This keeps the file loadable by 40-year-old software.</li>
                    <li><strong>The real Windows image</strong> — starting at a pointer hidden inside the DOS header, marked by the signature <code>PE</code>. This part holds the COFF header, the optional header, a table of sections, and the section data itself.</li>
                </ol>
                <p>The model's missing piece: those two documents do not overlap arbitrarily. A single 4-byte field at DOS offset <code>0x3C</code> is the hinge — it tells you exactly where the Windows half begins. Follow that pointer and you are inside the modern format.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The Microsoft PE/COFF specification ("File Headers") describes the on-disk order exactly:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Layer</th><th scope="col">Starts at</th><th scope="col">Size</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>MS-DOS header</td><td>File offset 0</td><td>64 bytes</td><td><code>e_magic = "MZ"</code>; at offset <code>0x3C</code>, <code>e_lfanew</code> points at the PE signature</td></tr>
                        <tr><td>MS-DOS stub</td><td>Offset 64</td><td>Variable</td><td>Prints "This program cannot be run in DOS mode." (customizable with the linker <code>/STUB</code> option)</td></tr>
                        <tr><td>PE signature</td><td>File offset = <code>e_lfanew</code></td><td>4 bytes</td><td><code>"PE\0\0"</code> — letters P, E, then two nulls</td></tr>
                        <tr><td>COFF file header</td><td>Signature + 4</td><td>20 bytes</td><td>Machine, section count, timestamp, size of optional header, characteristics</td></tr>
                        <tr><td>Optional header</td><td>COFF + 20</td><td>224 (PE32) or 240 (PE32+) bytes</td><td>Entry point, image base, alignments, subsystem, 16 data directories</td></tr>
                        <tr><td>Section table</td><td>After optional header</td><td>40 bytes per section</td><td>One header per section: name, virtual size, raw pointer, flags</td></tr>
                        <tr><td>Section data</td><td>Per-section file pointers</td><td>Aligned to <code>FileAlignment</code></td><td>Code and data — <code>.text</code>, <code>.rdata</code>, <code>.data</code>, ...</td></tr>
                    </tbody>
                </table>
                <p>The spec also fixes the vocabulary you will use all course: a <strong>file pointer</strong> is a position on disk; a <strong>virtual address (VA)</strong> is where something lands in memory; a <strong>relative virtual address (RVA)</strong> is that memory address with the image base subtracted. Keep those three apart — most PE bugs are one of them confused for another.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> You might think the PE signature is always at a fixed offset. It is not. It sits wherever <code>e_lfanew</code> points — 0x80, 0x100, or anywhere else the linker chose. Always read offset <code>0x3C</code> first.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>First 64 bytes of a real 64-bit PE executable (setuptools' <code>cli-64.exe</code>, 14336 bytes):</p>
                <div class="hex-dump">
                    <pre>00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
00000010: b800 0000 0000 0000 4000 0000 0000 0000  ........@.......
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0001 0000 0000  ................</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>Bytes 0-1: <code>4d 5a</code> — "MZ", the DOS magic named after Mark Zbikowski.</li>
                    <li>Bytes 0x3C-0x3F: <code>00 01 00 00</code> — little-endian 32-bit value <code>0x00000100</code> = 256. The PE signature lives at file offset 256.</li>
                    <li>And indeed, at offset <code>0x100</code> the file reads <code>50 45 00 00</code> — "PE" plus two nulls, exactly as the spec requires.</li>
                </ol>
                <div class="hex-dump">
                    <pre>00000100: 5045 0000 6486 0600 e427 6864 0000 0000  PE..d....'hd....
00000110: 0000 0000 f000 2200                       ......"....</pre>
                </div>
                <p>That second dump already contains a complete COFF header: machine <code>0x8664</code> (x64), 6 sections, optional-header size <code>0x00F0</code> (240 bytes = PE32+), characteristics <code>0x0022</code>. You will decode every field in the next concepts.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Windows executable works. On Linux or macOS:</p>
                <pre><code>$ file notepad.exe
notepad.exe: PE32+ executable (GUI) x86-64, for MS Windows

$ xxd -l 64 notepad.exe
00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
...</code></pre>
                <p>On Windows, PowerShell gets you the same first bytes:</p>
                <pre><code>&gt; [System.IO.File]::ReadAllBytes(".\notepad.exe")[0..3]
77 90 144 0   # 0x4D 0x5A 0x90 0x00</code></pre>
                <p>What to look for: every PE file begins <code>4d 5a</code>, and <em>every</em> four-byte group you read from a file like this is little-endian — the lowest-address byte is the least significant. That single rule decodes half the format.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what four bytes open every PE file, and where does the PE signature itself live?</p>
                <div class="quiz" id="quiz-intro-1">
                    <button class="quiz-option" data-correct="false" data-explain="7f 45 4c 46 is the ELF magic used on Linux, not Windows." onclick="checkQuiz('quiz-intro-1', this)">7f 45 4c 46 at offset 0</button>
                    <button class="quiz-option" data-correct="true" data-explain="4d 5a spells MZ at offset 0, and the PE signature sits at the file offset stored in e_lfanew (DOS offset 0x3C)." onclick="checkQuiz('quiz-intro-1', this)">4d 5a at offset 0; PE at the offset stored at 0x3C</button>
                    <button class="quiz-option" data-correct="false" data-explain="50 45 is PE itself — but it does not open the file, and it is not at offset 0. The MZ header comes first." onclick="checkQuiz('quiz-intro-1', this)">50 45 at offset 0</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A PE file has <code>00 08 00 00</code> at offset 0x3C. Before opening anything else, at what file offset will you find the bytes <code>50 45 00 00</code>?</p>
                <div class="quiz" id="quiz-intro-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x0000 is where the MZ magic is, not where e_lfanew points." onclick="checkQuiz('quiz-intro-2', this)">At offset 0x0000</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x003C is the address of the e_lfanew field itself — its location, not its value." onclick="checkQuiz('quiz-intro-2', this)">At offset 0x003C</button>
                    <button class="quiz-option" data-correct="true" data-explain="Little-endian 00 08 00 00 = 0x00000800 = 2048. e_lfanew is an absolute file offset, so the PE signature is at byte 2048." onclick="checkQuiz('quiz-intro-2', this)">At offset 0x0800</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: read 4 bytes at 0x3C, swap them to little-endian, and you have the next address in the chain. Every PE parse starts this way.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This course follows the same spine the ELF course did: headers first (what the loader reads), then addressing (how disk maps to memory), then sections and the tables inside them (imports, exports, relocations, resources), and finally the loader itself.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-file-layout">PE File Layout</a> — the full map from byte 0 to the last section, before any individual field is decoded.</p>
            </div>

            <div class="lesson-footer">
                <span></span>
                <span><a href="/courses/pe/lessons/pe-file-layout">Next: PE File Layout</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
