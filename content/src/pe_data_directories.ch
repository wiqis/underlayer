// PE Course — Concept 6: The Data Directories.
// The 16 address/size pairs at the end of the optional header.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_data_directories() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Data Directories — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Data Directories</h1>
            <div class="lesson-meta">15 min · Module 3: Addressing &amp; Data Directories · Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The loader already knows where the entry point is, but a modern program also needs relocations so it can be rebased, an import table so it can call KERNEL32, resources for icons and version info, and an exception table so the CPU can unwind stack frames. All of those tables are scattered through the sections. Without an index, finding them would mean scanning the whole image for patterns — slow, ambiguous, and wrong whenever a table sits in the middle of unrelated data.</p>
                <p>The data directories are that index: a fixed, always-in-the-same-place list of address-and-size pairs at the tail of the optional header. Every serious PE consumer reads them — the Windows loader, exception dispatch, debuggers, signature verifiers, <code>dumpbin</code>, <code>objdump -p</code>, Python's <code>pefile</code>. If you can read these 16 pairs, you know what a binary actually contains before you look at a single section.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of a table of contents with sixteen numbered slots. Each slot is exactly 8 bytes: a <strong>VirtualAddress</strong> (really an RVA) telling where the table lives in memory, and a <strong>Size</strong> telling how many bytes it spans.</p>
                <ol>
                    <li><strong>Numbered, not named.</strong> Slot 1 is always imports, slot 5 is always base relocations, slot 12 is always the IAT. The count of valid slots is <code>NumberOfRvaAndSizes</code> — normally 16, but the spec warns it is not fixed, so always read the field before trusting a slot exists.</li>
                    <li><strong>All zeros means absent.</strong> An empty pair does not signal corruption. It means the image simply does not use that feature: no exports in an EXE, no TLS, no delay-loads, no .NET header.</li>
                    <li><strong>One slot lies about its first field.</strong> Slot 4 (Security/Certificate) stores a <em>file offset</em>, not an RVA, because certificates are never mapped into memory.</li>
                </ol>
                <p>The model's missing piece: the directories locate tables; they do not tell you which section holds them. You still need the section table for that — which is the next lesson's job.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec declares each entry as <code>IMAGE_DATA_DIRECTORY</code>: a 4-byte <code>VirtualAddress</code> plus a 4-byte <code>Size</code>. For PE32+ the array begins at optional-header offset 112, immediately after <code>NumberOfRvaAndSizes</code> at offset 108. In Sample A the optional header starts at file 0x118, so <code>NumberOfRvaAndSizes</code> sits at file 0x184 (value 16), the sixteen pairs occupy 0x188 through 0x207, and the section table begins at 0x208.</p>
                <table>
                    <thead>
                        <tr><th scope="col">#</th><th scope="col">Directory</th><th scope="col">PE32+ offset</th><th scope="col">Who consumes it</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>Export</td><td>112</td><td>Loaders and GetProcAddress resolving names this DLL exposes</td></tr>
                        <tr><td>1</td><td>Import</td><td>120</td><td>Loader building the import address table from DLL names</td></tr>
                        <tr><td>2</td><td>Resource</td><td>128</td><td>Explorer and FindResource walking the .rsrc tree</td></tr>
                        <tr><td>3</td><td>Exception</td><td>136</td><td>x64 unwinder reading RUNTIME_FUNCTION entries (.pdata)</td></tr>
                        <tr><td>4</td><td>Security (Certificate)</td><td>144</td><td>Authenticode verifiers — first field is a FILE OFFSET</td></tr>
                        <tr><td>5</td><td>Base Relocation</td><td>152</td><td>Loader rebasing the image when its preferred base is taken</td></tr>
                        <tr><td>6</td><td>Debug</td><td>160</td><td>Debuggers locating CodeView/PDB pointers</td></tr>
                        <tr><td>7</td><td>Architecture</td><td>168</td><td>Reserved, must be zero</td></tr>
                        <tr><td>8</td><td>Global Ptr</td><td>176</td><td>Value for the global pointer register; size must be zero</td></tr>
                        <tr><td>9</td><td>TLS</td><td>184</td><td>Loader setting up thread-local storage templates</td></tr>
                        <tr><td>10</td><td>Load Config</td><td>192</td><td>Security cookie, SEH, Control Flow Guard data</td></tr>
                        <tr><td>11</td><td>Bound Import</td><td>200</td><td>Legacy pre-resolved imports (rarely used now)</td></tr>
                        <tr><td>12</td><td>IAT</td><td>208</td><td>Loader patching function addresses; calls jump through here</td></tr>
                        <tr><td>13</td><td>Delay Import</td><td>216</td><td>Delay-load helper resolving DLLs on first call</td></tr>
                        <tr><td>14</td><td>CLR Runtime Header</td><td>224</td><td>.NET runtime bootstrapping a managed image</td></tr>
                        <tr><td>15</td><td>Reserved</td><td>232</td><td>Must be zero</td></tr>
                    </tbody>
                </table>
                <p>Two rules the spec states plainly: check <code>NumberOfRvaAndSizes</code> and <code>SizeOfOptionalHeader</code> before probing any entry, and <em>"do not assume that the RVAs in this table point to the beginning of a section or that the sections that contain specific tables have specific names."</em></p>
                <div class="callout callout-warn">
                    <strong>Common mistakes.</strong> First, assuming directory number N lives in a section named for it — in Sample A the import directory (RVA 0x3A04) sits in <code>.rdata</code>, and there is no <code>.idata</code> section at all. Second, treating an all-zero entry as damage — nine of Sample A's sixteen entries are zero and the file runs perfectly. Third, reading Security as an RVA and converting it through the section table — the spec says its first field "is a file pointer instead," because certificates are not loaded into memory.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>All sixteen pairs from Sample A (<code>cli-64.exe</code>), read at file 0x188, with the section each RVA actually lands in:</p>
                <table>
                    <thead>
                        <tr><th scope="col">#</th><th scope="col">Directory</th><th scope="col">RVA / file offset</th><th scope="col">Size</th><th scope="col">Lands in</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>Export</td><td>0x00000000</td><td>0x0000</td><td>absent — EXEs export nothing</td></tr>
                        <tr><td>1</td><td>Import</td><td>0x00003A04</td><td>0x00DC</td><td>.rdata, file 0x2604</td></tr>
                        <tr><td>2</td><td>Resource</td><td>0x00007000</td><td>0x01E0</td><td>.rsrc, file 0x3400</td></tr>
                        <tr><td>3</td><td>Exception</td><td>0x00006000</td><td>0x01EC</td><td>.pdata, file 0x3200</td></tr>
                        <tr><td>4</td><td>Security</td><td>0x00000000</td><td>0x0000</td><td>unsigned (OpenConsole.exe: file offset 0x100E00, size 0x3D20)</td></tr>
                        <tr><td>5</td><td>Base Relocation</td><td>0x00008000</td><td>0x0030</td><td>.reloc, file 0x3600</td></tr>
                        <tr><td>6</td><td>Debug</td><td>0x00003510</td><td>0x001C</td><td>.rdata, file 0x2110</td></tr>
                        <tr><td>7</td><td>Architecture</td><td>0x00000000</td><td>0x0000</td><td>reserved, must stay zero</td></tr>
                        <tr><td>8</td><td>Global Ptr</td><td>0x00000000</td><td>0x0000</td><td>absent</td></tr>
                        <tr><td>9</td><td>TLS</td><td>0x00000000</td><td>0x0000</td><td>absent — no thread-local variables</td></tr>
                        <tr><td>10</td><td>Load Config</td><td>0x000033D0</td><td>0x0140</td><td>.rdata, file 0x1FD0</td></tr>
                        <tr><td>11</td><td>Bound Import</td><td>0x00000000</td><td>0x0000</td><td>absent</td></tr>
                        <tr><td>12</td><td>IAT</td><td>0x00003000</td><td>0x0250</td><td>.rdata, file 0x1C00</td></tr>
                        <tr><td>13</td><td>Delay Import</td><td>0x00000000</td><td>0x0000</td><td>absent</td></tr>
                        <tr><td>14</td><td>CLR Runtime Header</td><td>0x00000000</td><td>0x0000</td><td>absent — native image, not .NET</td></tr>
                        <tr><td>15</td><td>Reserved</td><td>0x00000000</td><td>0x0000</td><td>must be zero</td></tr>
                    </tbody>
                </table>
                <p>The raw bytes for the first four slots (entries 0 through 3), little-endian throughout:</p>
                <div class="hex-dump">
                    <pre>00000188: 0000 0000 0000 0000 043a 0000 dc00 0000  .........:......
00000198: 0070 0000 e001 0000 0060 0000 ec01 0000  .p.......`......
000001a8: 0000 0000 0000 0000 0080 0000 3000 0000  ............0...
000001b8: 1035 0000 1c00 0000 0000 0000 0000 0000  .5..............</pre>
                </div>
                <p>Slot 0 is eight zero bytes. Slot 1 reads <code>04 3a 00 00</code> = 0x3A04 then <code>dc 00 00 00</code> = 0xDC — the import directory is 220 bytes long. Slot 4 (at 0x1A8) is zero here; in a signed binary that same position holds a raw file offset you seek to directly.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Dump the array yourself, or let a disassembler decode it:</p>
                <pre><code>$ xxd -s 0x188 -l 128 cli-64.exe
00000188: 0000 0000 0000 0000 043a 0000 dc00 0000  .........:......
...

$ objdump -p cli-64.exe | sed -n '/The Data Directory/,/^There is an import/p'
Entry 1 0000000000003a04 000000dc Import Directory [parts of .idata]
Entry 4 0000000000000000 00000000 Security Directory</code></pre>
                <p>Or decode all sixteen pairs in one line of Python:</p>
                <pre><code>$ python3 -c "import struct; d=open('cli-64.exe','rb').read(); names='EXPORT IMPORT RESOURCE EXCEPTION SECURITY BASERELOC DEBUG ARCH GLOBALPTR TLS LOAD_CONFIG BOUND_IMPORT IAT DELAY CLR RESERVED'.split(); p=struct.unpack_from('&lt;32I', d, 0x188); [print('%2d %-12s 0x%08x 0x%04x' % (i, names[i], p[2*i], p[2*i+1])) for i in range(16)]"
 0 EXPORT      0x00000000 0x0000
 1 IMPORT      0x00003a04 0x00dc
 ...</code></pre>
                <p>What to look for: the pairs are strictly 8 bytes each in index order, so slot N lives at file 0x188 + 8N in this file — no searching, no heuristics.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what does a data-directory entry whose two dwords are both zero mean, and which slot is the exception to the RVA rule?</p>
                <div class="quiz" id="quiz-ddir-1">
                    <button class="quiz-option" data-correct="false" data-explain="A zero pair is not corruption. Sample A runs fine with nine zero entries — the image simply does not use those features." onclick="checkQuiz('quiz-ddir-1', this)">The file is corrupt; every directory must be populated</button>
                    <button class="quiz-option" data-correct="true" data-explain="Zero/zero means the feature is absent, and slot 4 (Security/Certificate) is the exception: its first field is a file offset, not an RVA, because certificates are never mapped into memory." onclick="checkQuiz('quiz-ddir-1', this)">The feature is absent; slot 4 (Security) stores a file offset instead</button>
                    <button class="quiz-option" data-correct="false" data-explain="The loader keeps going when a directory is empty. Only slots 7 and 15 must be zero by specification; the others are optional." onclick="checkQuiz('quiz-ddir-1', this)">The section table must be scanned instead; slot 0 is the exception</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A verifier tool reads the Security directory of <code>OpenConsole.exe</code> and gets VirtualAddress = 0x100E00, Size = 0x3D20 (ImageBase = 0x140000000, .reloc sits at RVA 0x106000). What should the tool do with 0x100E00?</p>
                <div class="quiz" id="quiz-ddir-2">
                    <button class="quiz-option" data-correct="false" data-explain="Adding ImageBase would produce VA 0x140100E00 — but certificates are never loaded into memory, so no such VA exists at runtime." onclick="checkQuiz('quiz-ddir-2', this)">Add ImageBase and read it as a virtual address in memory</button>
                    <button class="quiz-option" data-correct="false" data-explain="Converting through the section table is for RVAs. The spec explicitly says this field is not an RVA, so section lookup is the wrong tool." onclick="checkQuiz('quiz-ddir-2', this)">Convert it with the RVA-to-file-offset algorithm through the sections</button>
                    <button class="quiz-option" data-correct="true" data-explain="The spec states the certificate entry is a file pointer because certificates are not loaded into memory. Seek to byte 0x100E00 and you land on a WIN_CERTIFICATE header: dwLength 0x3D20, revision 0x200, type 0x2 (PKCS signed data), ending exactly at EOF 0x104B20." onclick="checkQuiz('quiz-ddir-2', this)">Seek directly to file offset 0x100E00 — it is already a file pointer</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: every other directory entry is an RVA you convert; this one you seek. Knowing which is which is the difference between a verifier that works and one that reads garbage.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have now met three kinds of number in one lesson: file offsets (the Security slot, and everything <code>xxd</code> shows you), RVAs (the other fifteen slots), and — soon — full virtual addresses once the image is loaded. The next lesson separates those three address spaces cleanly.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-addresses">VA, RVA, and File Offset</a> — the three coordinate systems a PE lives in, and when each one appears.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-optional-header">Previous: The Optional Header</a></span>
                <span><a href="/courses/pe/lessons/pe-addresses">Next: VA, RVA, and File Offset</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
