// PE Course — Concept 13: The Import Tables.
// Descriptors, ILT vs IAT, hint/name entries, and how the loader resolves names.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_imports() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Import Tables — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Import Tables</h1>
            <div class="lesson-meta">15 min · Module 5: Imports &amp; Exports · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Your program calls <code>CreateFileA</code>, but no machine code for it exists in your <code>.exe</code>. That function lives inside <code>KERNEL32.dll</code>, and the address where Windows maps that DLL is not decided until the process starts. The file on disk can only record <em>which</em> DLLs it needs and <em>which</em> functions inside them — it cannot record final addresses.</p>
                <p>The import tables are that shopping list. The Windows loader walks them before the first instruction of your entry point runs: it maps each DLL, resolves every name, and patches the call targets. Everything that depends on linking against other modules — <code>dumpbin /imports</code>, Dependency Walker, objdump, malware analysis write-ups of "API hashing", even the error dialog when a DLL is missing — is reading this one structure.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>For each DLL the image uses, there is a small <strong>descriptor</strong> — five 32-bit fields that answer three questions: what is the DLL called, where is the list of names I import from it, and where does the resolved addresses table live?</p>
                <p>Those last two fields point at two parallel arrays:</p>
                <ul>
                    <li><strong>ILT (Import Lookup Table)</strong> — the list of names, read-only. It never changes after linking.</li>
                    <li><strong>IAT (Import Address Table)</strong> — starts out with byte-for-byte the same contents as the ILT, then the loader <em>overwrites</em> it with the real function addresses.</li>
                </ul>
                <p>The descriptor array itself is simply an array terminated by an all-zero descriptor. Data directory index 1 points at it; index 12 points at the IAT alone.</p>
                <p>The model's missing piece: names and addresses are separate. That is the whole design — a read-only list of symbols, plus a writable table the operating system is allowed to fill in.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The Microsoft PE specification ("The .idata Section") fixes the descriptor at exactly 20 bytes:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>Import Lookup Table RVA (a.k.a. Characteristics in winnt.h)</td><td>RVA of the ILT — one entry per imported symbol</td></tr>
                        <tr><td>4</td><td>4</td><td>Time/Date Stamp</td><td>Zero until the image is bound; after binding, the stamp of the DLL</td></tr>
                        <tr><td>8</td><td>4</td><td>Forwarder Chain</td><td>Index of the first forwarder reference</td></tr>
                        <tr><td>12</td><td>4</td><td>Name RVA</td><td>RVA of the ASCII DLL name string</td></tr>
                        <tr><td>16</td><td>4</td><td>Import Address Table RVA (Thunk Table)</td><td>RVA of the IAT; identical to the ILT until the loader binds it</td></tr>
                    </tbody>
                </table>
                <p>Each ILT/IAT entry is 8 bytes in PE32+ (4 in PE32). The spec's bit layout: the top bit (bit 63) is the Ordinal/Name flag, masked as <code>0x8000000000000000</code> for PE32+ and <code>0x80000000</code> for PE32. If it is set, the low 16 bits are an ordinal and the import skips name lookup entirely. If it is clear, the entry holds a 31-bit RVA of a hint/name entry (bits 62-31 must be zero). The table ends with a zero entry.</p>
                <p>A hint/name entry is: 2-byte <strong>Hint</strong>, then the null-terminated ASCII <strong>Name</strong>, then an optional pad byte so the next entry starts on an even boundary. The hint is an index into the exporting DLL's name pointer table — the loader tries that index first and only falls back to a full binary search if it misses. One hint/name table serves the whole import section.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> "The ILT and the IAT are the same table." They are two arrays with identical <em>initial</em> contents. On disk both hold RVAs like <code>0x3D30</code>; in a running process the IAT slots hold resolved virtual addresses such as <code>0x00007FF812345678</code>, and the ILT still holds the RVAs. Reading the file shows you names; reading memory shows you addresses. This is also why the IAT directory (index 12) exists separately — patching tools and hooking detectors target exactly that writable table.
                </div>
                <div class="callout callout-tip">
                    <strong>Spec aside: bound imports.</strong> Because binding is just "write addresses into the IAT", it can be pre-computed: if the Time/Date Stamp and data directory index 11 (Bound Import) are filled in, the loader can reuse those addresses without name lookups. Both sample images leave directory 11 empty, which is the common case today.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>First import descriptor of setuptools' <code>cli-64.exe</code>, at file offset <code>0x2604</code> (data directory index 1 says RVA <code>0x3A04</code>, size <code>0xDC</code>):</p>
                <div class="hex-dump">
                    <pre>00002604: e03a 0000 0000 0000 0000 0000 e23d 0000  .:...........=..
00002614: 0030 0000 a03b 0000                      .0...;..</pre>
                </div>
                <p>Walk-through, five little-endian dwords plus the first dword of the next descriptor:</p>
                <ol>
                    <li><code>e03a 0000</code> = <code>0x00003AE0</code> — ILT RVA. File offset <code>0x26E0</code>.</li>
                    <li><code>0000 0000</code> twice — Time/Date Stamp and Forwarder Chain are zero (not bound).</li>
                    <li><code>e23d 0000</code> = <code>0x00003DE2</code> — Name RVA, which lands on <code>KERNEL32.dll</code> at file <code>0x29E2</code>.</li>
                    <li><code>0030 0000</code> = <code>0x00003000</code> — IAT RVA, matching data directory index 12 (size <code>0x250</code>).</li>
                </ol>
                <p>First ILT entry (file <code>0x26E0</code>) is <code>303d 0000 0000 0000</code> = <code>0x3D30</code> — the top bit is clear, so it is a hint/name RVA. At file <code>0x2930</code>:</p>
                <div class="hex-dump">
                    <pre>00002930: d200 4372 6561 7465 4669 6c65 4100 6b02  ..CreateFileA.k.
00002940: 4765 7446 696e 616c                      GetFinal</pre>
                </div>
                <p>Hint <code>0x00D2</code>, then <code>CreateFileA</code> and its null terminator — no pad byte was needed because the next entry begins immediately after. The IAT at file <code>0x1C00</code> starts with the very same value <code>0x3D30</code>, because nothing has been resolved yet. Ten descriptors follow (directory size <code>0xDC</code> = 11 x 20 bytes: ten DLLs plus the all-zero terminator): <code>KERNEL32.dll</code>, <code>VCRUNTIME140.dll</code>, and eight <code>api-ms-win-crt-*</code> DLLs.</p>
                <p>One more hint/name, packed right after the KERNEL32 string: <code>3e00 6d65 6d73 6574 00</code> at file <code>0x29F0</code> — hint <code>0x003E</code>, name <code>memset</code>, imported from <code>VCRUNTIME140.dll</code>. Hint/name entries are shared across all DLLs; only the descriptor tells you which DLL a thunk belongs to.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump decodes the descriptor array for you (sample A, <code>cli-64.exe</code>):</p>
                <pre><code>$ objdump -x cli-64.exe | sed -n '/The Import Tables/,+16p'
The Import Tables (interpreted .rdata section contents)
 vma:            Hint    Time      Forward  DLL       First
                 Table   Stamp     Chain    Name      Thunk
 00003a04	00003ae0 00000000 00000000 00003de2 00003000

	DLL Name: KERNEL32.dll
	vma:     Ordinal  Hint  Member-Name  Bound-To
	00003000  &lt;none&gt;  00d2  CreateFileA
	00003008  &lt;none&gt;  026b  GetFinalPathNameByHandleA
	00003010  &lt;none&gt;  0610  WaitForSingleObject</code></pre>
                <p>Read the same five fields with one line of Python:</p>
                <pre><code>$ python3 -c "import struct;d=open('cli-64.exe','rb').read();print([hex(x) for x in struct.unpack_from('&lt;5I',d,0x2604)])"
['0x3ae0', '0x0', '0x0', '0x3de2', '0x3000']</code></pre>
                <p>What to look for: a zero Time/Date Stamp means unbound; the Name RVA must resolve inside a section; and the IAT RVA should match data directory index 12.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what lives in a PE32+ thunk entry whose value is <code>0x800000000000002A</code>?</p>
                <div class="quiz" id="quiz-imports-1">
                    <button class="quiz-option" data-correct="false" data-explain="With the top bit clear, the entry would be a hint/name RVA of 0x2A, which is inside the DOS header, not a plausible table. The top bit here is set." onclick="checkQuiz('quiz-imports-1', this)">A hint/name RVA pointing at 0x2A</button>
                    <button class="quiz-option" data-correct="true" data-explain="Bit 63 is set, and the spec masks it as 0x8000000000000000 for PE32+. The low 16 bits, 0x002A = 42, are the ordinal to import from the DLL." onclick="checkQuiz('quiz-imports-1', this)">Import by ordinal: ordinal 42</button>
                    <button class="quiz-option" data-correct="false" data-explain="Thunk tables on disk hold identifiers (RVAs or ordinals), never resolved addresses. The loader writes addresses into the IAT only at load time." onclick="checkQuiz('quiz-imports-1', this)">The already-resolved address of ordinal 42</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>In <code>cli-64.exe</code>, the first KERNEL32 thunk value on disk is <code>0x0000000000003D30</code>. Which statement is true?</p>
                <div class="quiz" id="quiz-imports-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x3D30 would be an ordinal only if the high bit 0x8000000000000000 were set. It is not, so the low bits are not read as an ordinal." onclick="checkQuiz('quiz-imports-2', this)">It imports ordinal 0x3D30</button>
                    <button class="quiz-option" data-correct="true" data-explain="The high bit is clear, so the value is a hint/name RVA. At file 0x2930 it reads d2 00 43 72 65 61 74 65 46 69 6c 65 41 00: hint 0x00D2, name CreateFileA." onclick="checkQuiz('quiz-imports-2', this)">It is a hint/name RVA for CreateFileA with hint 0x00D2</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x3D30 is an RVA into .rdata, not an address. Real addresses only appear in the IAT after the loader has mapped KERNEL32.dll and patched the slot." onclick="checkQuiz('quiz-imports-2', this)">It is the runtime address of CreateFileA</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: decode the top bit first, then either read 16 bits as an ordinal or follow 31 bits as a hint/name RVA. Every import in every PE resolves through that one branch.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Imports only make sense if the exporting side records something to find. The next lesson flips the file around: how <code>conpty.dll</code> publishes fourteen names, how ordinals index them, and how one export can secretly be a string pointing at another DLL.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-exports">The Export Tables</a> — the directory header, the three parallel arrays, and forwarders.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-alignment">Previous: Alignment: FileAlignment vs SectionAlignment</a></span>
                <span><a href="/courses/pe/lessons/pe-exports">Next: The Export Tables</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
