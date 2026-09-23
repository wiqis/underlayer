// PE Course — Concept 14: The Export Tables.
// IMAGE_EXPORT_DIRECTORY, the three parallel arrays, ordinals, and forwarders.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_exports() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Export Tables — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Export Tables</h1>
            <div class="lesson-meta">15 min · Module 5: Imports &amp; Exports · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When <code>conpty.dll</code> exports <code>CreatePseudoConsole</code>, some other image's import descriptor will say "DLL name: conpty.dll, symbol: CreatePseudoConsole". The loader already knows the name — now it has to find the actual code inside this file and hand the address back. A string search over the whole DLL would work but would be slow and fragile, so PE packages exports as a small header plus three arrays designed for lookup.</p>
                <p>This is also what <code>GetProcAddress</code> walks at runtime, what <code>dumpbin /exports</code> prints, and what a reverse engineer reads first when asking "what does this DLL actually offer?". Understanding it explains why ordinals break between versions, why some functions appear twice in an export list, and how one DLL can pretend to export code it does not contain.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of the export directory as one header row and three parallel columns:</p>
                <ul>
                    <li><strong>Export address table (EAT)</strong> — an array of 32-bit RVAs, one slot per ordinal. This is where the answer lives.</li>
                    <li><strong>Name pointer table</strong> — an array of RVAs pointing at the exported name strings, <em>sorted lexically</em> so the loader can binary-search it.</li>
                    <li><strong>Ordinal table</strong> — an array of 16-bit <em>unbiased</em> indexes into the EAT, one per name, position-matched with the name table.</li>
                </ul>
                <p>Slot <code>i</code> of the name table and slot <code>i</code> of the ordinal table are the same row: name <code>i</code> maps to EAT index <code>ordinal[i]</code>, and the caller-visible ordinal is that index plus the <strong>Ordinal Base</strong>. A single header (40 bytes) stores the DLL's own name and the RVAs of all three arrays. Data directory index 0 points at it.</p>
                <p>The model's missing piece: there are two lookup routes into the same EAT — by name (search, then translate) and by ordinal (direct index). Names are convenience; ordinals are the real addressing scheme.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The spec's export directory table, one row, 40 bytes total:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">What it says</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>4</td><td>Export Flags</td><td>Reserved, must be 0</td></tr>
                        <tr><td>4</td><td>4</td><td>Time/Date Stamp</td><td>When the export data was created (0 or 0xFFFFFFFF means "not meaningful")</td></tr>
                        <tr><td>8</td><td>2</td><td>Major Version</td><td>User-settable</td></tr>
                        <tr><td>10</td><td>2</td><td>Minor Version</td><td>User-settable</td></tr>
                        <tr><td>12</td><td>4</td><td>Name RVA</td><td>ASCII name of this DLL itself</td></tr>
                        <tr><td>16</td><td>4</td><td>Ordinal Base</td><td>Starting ordinal of the EAT, usually 1</td></tr>
                        <tr><td>20</td><td>4</td><td>Address Table Entries</td><td>Length of the EAT (<code>NumberOfFunctions</code>)</td></tr>
                        <tr><td>24</td><td>4</td><td>Number of Name Pointers</td><td>Length of the name table and of the ordinal table</td></tr>
                        <tr><td>28</td><td>4</td><td>Export Address Table RVA</td><td>Where the RVAs are</td></tr>
                        <tr><td>32</td><td>4</td><td>Name Pointer RVA</td><td>Where the sorted name RVAs are</td></tr>
                        <tr><td>36</td><td>4</td><td>Ordinal Table RVA</td><td>Where the 16-bit indexes are</td></tr>
                    </tbody>
                </table>
                <p>The spec's lookup algorithm for a name: binary-search the name pointer table for a match at index <code>i</code>, read <code>ordinal = OrdinalTable[i]</code>, take <code>rva = ExportAddressTable[ordinal]</code>, and report <code>ordinal + OrdinalBase</code> to the caller. The reverse path subtracts Base first. The EAT entry itself has two meanings: normally an <strong>export RVA</strong> into code or data — but if it falls <em>inside</em> the export directory's own address range, it is a <strong>forwarder RVA</strong>, a pointer to a string like <code>"MYDLL.expfunc"</code> or <code>"MYDLL.#27"</code> naming a symbol in a different DLL. The spec's own example: Windows XP's <code>Kernel32.HeapAlloc</code> forwards to <code>"NTDLL.RtlAllocateHeap"</code>, so applications keep importing only Kernel32.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Treating export ordinals as stable across releases, or assuming every function has a name. The EAT can be longer than the name table (exports with no name), several names can point at the same EAT slot (aliases), and only the name table is sorted — reordering ordinals between DLL versions silently redirects ordinal importers. That is why import-by-name is the default and ordinal import is reserved for frozen interfaces.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The export directory of GitHub Copilot's <code>conpty.dll</code>, at file offset <code>0x150D0</code> (data directory index 0: RVA <code>0x164D0</code>, size <code>0x214</code>):</p>
                <div class="hex-dump">
                    <pre>000150d0: 0000 0000 ffff ffff 0000 0000 8465 0100  .............e..
000150e0: 0100 0000 0e00 0000 0e00 0000 f864 0100  .............d..
000150f0: 3065 0100 6865 0100 205f 0000            0e..he.. _..</pre>
                </div>
                <ol>
                    <li><code>0000 0000</code> — Export Flags, zero as required. Next dword <code>ffffffff</code> — a non-meaningful timestamp per the spec.</li>
                    <li><code>0000 0000</code> — Major/Minor version 0/0.</li>
                    <li><code>8465 0100</code> = <code>0x16584</code> — Name RVA; the string there is <code>conpty.dll</code>.</li>
                    <li><code>0100 0000</code> — Ordinal Base = 1.</li>
                    <li><code>0e00 0000</code> twice — 14 address-table entries and 14 names (every export is named here).</li>
                    <li><code>f864 0100</code> / <code>3065 0100</code> / <code>6865 0100</code> — RVAs of the EAT (<code>0x164F8</code>), name pointer table (<code>0x16530</code>), ordinal table (<code>0x16568</code>), all packed into the 0x214-byte export directory.</li>
                </ol>
                <p>The 14 names, exactly as objdump prints them (ordinal = EAT index + Base):</p>
                <div class="hex-dump">
                    <pre>[   0] +base[   1]  0000 ClearPseudoConsole
[   1] +base[   2]  0001 ClosePseudoConsole
[   4] +base[   5]  0004 ConptyCreatePseudoConsole
[  11] +base[  12]  000b CreatePseudoConsole
[  13] +base[  14]  000d ResizePseudoConsole</pre>
                </div>
                <p>Note the aliasing: EAT slot for ordinal 5 (<code>ConptyCreatePseudoConsole</code>) and slot for ordinal 12 (<code>CreatePseudoConsole</code>) both hold RVA <code>0x05BD0</code> — two names, one function. And no entry in this EAT falls inside the directory range <code>0x164D0</code>-<code>0x166E4</code>, so none of the fourteen exports is a forwarder.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump prints the header and both name/ordinal columns:</p>
                <pre><code>$ objdump -x conpty.dll | sed -n '/Export Tables/,+14p'
The Export Tables (interpreted .rdata section contents)

Export Flags 			0
Time/Date stamp 		ffffffff
Major/Minor 			0/0
Name 				0000000000016584 conpty.dll
Ordinal Base 			1
Number in:
	Export Address Table 		0000000e
	[Name Pointer/Ordinal] Table	0000000e</code></pre>
                <pre><code>$ objdump -x conpty.dll | sed -n '/\[Ordinal\/Name Pointer\]/,+6p'
[Ordinal/Name Pointer] Table -- Ordinal Base 1
	          Ordinal   Hint Name
	[   0] +base[   1]  0000 ClearPseudoConsole
	[   1] +base[   2]  0001 ClosePseudoConsole
	[   2] +base[   3]  0002 ConptyClearPseudoConsole
	[   3] +base[   4]  0003 ConptyClosePseudoConsole</code></pre>
                <p>Decode the header yourself — the directory starts at file <code>0x150D0</code> because .rdata has RVA <code>0x11000</code> at file <code>0xFC00</code> and the export RVA is <code>0x164D0</code>:</p>
                <pre><code>$ python3 -c "import struct;d=open('conpty.dll','rb').read();v=struct.unpack_from('&lt;IIHHIIIIIII',d,0x150d0);print('base',v[5],'funcs',v[6],'names',v[7],hex(v[8]),hex(v[9]),hex(v[10]))"
base 1 funcs 14 names 14 0x164f8 0x16530 0x16568</code></pre>
                <p>What to look for: Address Table Entries versus Number of Name Pointers — if they differ, some exports are ordinal-only. Then spot any EAT value that lies inside the directory's own RVA range: that is a forwarder.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a loader asks <code>conpty.dll</code> for ordinal 12. Which export does it get, and how does it find it?</p>
                <div class="quiz" id="quiz-exports-1">
                    <button class="quiz-option" data-correct="false" data-explain="ConptyCreatePseudoConsole is ordinal 5. Ordinals are EAT indexes plus the Base of 1, not names that happen to look similar." onclick="checkQuiz('quiz-exports-1', this)">ConptyCreatePseudoConsole, by searching the name table</button>
                    <button class="quiz-option" data-correct="true" data-explain="Ordinal 12 minus Base 1 gives EAT index 11, whose RVA is 0x05BD0: CreatePseudoConsole. Importing by ordinal needs no name search at all." onclick="checkQuiz('quiz-exports-1', this)">CreatePseudoConsole, by indexing the address table at 12 minus Base 1</button>
                    <button class="quiz-option" data-correct="false" data-explain="ClosePseudoConsole is ordinal 2. Also, name-table slots and ordinal-table slots are separate arrays joined by position, not by ordinal value." onclick="checkQuiz('quiz-exports-1', this)">ClosePseudoConsole, from slot 12 of the name pointer table</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are auditing an EAT entry whose value is <code>0x16590</code>, and the export directory covers RVAs <code>0x164D0</code> to <code>0x166E4</code>. What have you found?</p>
                <div class="quiz" id="quiz-exports-2">
                    <button class="quiz-option" data-correct="false" data-explain="An exported function lives in .text or .data, outside the export directory. An address inside the directory is not executable code." onclick="checkQuiz('quiz-exports-2', this)">The RVA of a real exported function</button>
                    <button class="quiz-option" data-correct="true" data-explain="The spec says: if the EAT value falls within the export section range, it is a forwarder RVA — a pointer to a string such as MYDLL.expfunc or MYDLL.#27 naming a symbol in another DLL." onclick="checkQuiz('quiz-exports-2', this)">A forwarder RVA pointing at a DLL.Function string</button>
                    <button class="quiz-option" data-correct="false" data-explain="Hints live in hint/name entries referenced by import thunks, not in export address slots." onclick="checkQuiz('quiz-exports-2', this)">A hint index into the import name table</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: read the directory size as a fence. EAT values inside the fence are strings; values outside it are code.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Both tables so far are eager: the loader resolves everything before main runs. But a DLL pulled in for one rare code path still taxes every process start — and if it is missing, the process will not start at all. The next lesson shows the structure that moves that cost and that failure to the first call instead.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-delay-loads">Delay-Load Imports</a> — the second, parallel import machinery and the helper that runs it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-imports">Previous: The Import Tables</a></span>
                <span><a href="/courses/pe/lessons/pe-delay-loads">Next: Delay-Load Imports</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
