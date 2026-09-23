// PE Course — Module 7: The Resource Directory (.rsrc).
// Three-level tree: Type, Name, Language, verified against cli-64.exe and conpty.dll.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_resources() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Resource Directory — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Resource Directory</h1>
            <div class="lesson-meta">15 min · Module 7: Resources &amp; Runtime Tables · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The icon you see in Explorer, the version string in a file properties dialog, the error dialog text in your language, and the application manifest that asks for per-user privileges all live inside the PE file itself. None of that is loose text — it is a lookup table the operating system reads with FindResource-style APIs.</p>
                <p>The resource directory is also the structure malware analysts, localization tools, and installers touch every day: extract an icon, swap a dialog, read the manifest that decides whether a program runs elevated. If you cannot walk this tree, half of the PE file is unreadable to you.</p>
                <p>Data directory index 2 (the Resource Table) points at this structure. In our 64-bit sample <code>cli-64.exe</code> it holds RVA 0x7000 with size 0x1E0, exactly the <code>.rsrc</code> section.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of resources as a three-level filing cabinet, which is exactly how the PE/COFF specification describes it by convention:</p>
                <ol>
                    <li><strong>Type</strong> — what kind of thing it is: an icon, a version block, a manifest.</li>
                    <li><strong>Name</strong> — which instance of that type: icon 101, dialog MAIN.</li>
                    <li><strong>Language</strong> — which copy: English (United States), German, and so on.</li>
                </ol>
                <p>Each level is a directory: a 16-byte header followed by 8-byte entries. An entry either points one level deeper (a subdirectory) or ends the walk (a leaf) that finally describes the raw bytes.</p>
                <p>The model's missing piece: every level uses the same two structures, and a single high bit inside each entry decides which way it points. Learn one level and you have learned all three.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The specification chapter "The .rsrc Section" pins down every field:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Structure</th><th scope="col">Size</th><th scope="col">Contents</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Resource Directory Table</td><td>16 bytes</td><td>Characteristics, Time/Date Stamp, Major/Minor Version, Number of Name Entries, Number of ID Entries</td></tr>
                        <tr><td>Directory Entry</td><td>8 bytes</td><td>Name Offset or Integer ID (4 bytes), then Data Entry Offset or Subdirectory Offset (4 bytes)</td></tr>
                        <tr><td>Resource Data Entry</td><td>16 bytes</td><td>Data RVA, Size, Codepage, Reserved</td></tr>
                    </tbody>
                </table>
                <p>Three rules from the spec control the whole walk: all Name entries precede all ID entries in every table; entries are sorted in ascending order (names by case-sensitive string, IDs by numeric value); and directory offsets are relative to the address of the resource data directory, not to the start of the file.</p>
                <p>The high bit of the second entry field is the branch: clear means the low 31 bits address a leaf (Resource Data Entry), set means they address the next directory table. Windows preassigns the well-known Type IDs — for example RT_ICON is 3, RT_GROUP_ICON is 14, RT_VERSION is 16, RT_MANIFEST is 24 (Microsoft, "Resource Types").</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> The two offsets in a leaf mean different things. Directory-level offsets are relative to the resource directory start, but the leaf field Data RVA is a full image-relative virtual address — add ImageBase to run it. Mixing them up sends your parser into the wrong half of the address space.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The first 96 bytes of the <code>.rsrc</code> section in <code>cli-64.exe</code> (section file offset 0x3400) contain the entire walk for its one resource. The bytes are shown without the trailing ascii column:</p>
                <div class="hex-dump">
                    <pre>00003400: 0000 0000 0000 0000 0000 0000 0000 0100
00003410: 1800 0000 1800 0080 0000 0000 0000 0000
00003420: 0000 0000 0000 0100 0100 0000 3000 0080
00003430: 0000 0000 0000 0000 0000 0000 0000 0100
00003440: 0904 0000 4800 0000 6070 0000 7d01 0000
00003450: 0000 0000 0000 0000 0000 0000 0000 0000</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>Bytes 0x3400-0x340F: type-level header. Number of Name Entries is 0, Number of ID Entries is 1 (the final <code>0100</code>).</li>
                    <li>Bytes 0x3410-0x3417: the single type entry. ID = 0x18 = 24 = RT_MANIFEST. Second word 0x80000018: high bit set, so a subdirectory sits 0x18 bytes from the directory start — file 0x3418.</li>
                    <li>Bytes 0x3418-0x342F: name-level header with 1 ID entry. Entry <code>0100 0000 3000 0080</code>: Name ID 1, high bit set, subdirectory at 0x30 — file 0x3430.</li>
                    <li>Bytes 0x3430-0x343F: language-level header, 1 ID entry. Bytes 0x3440-0x3447: ID 0x0409 (1033, English United States), offset 0x48 with the high bit clear — a leaf at directory offset 0x48, file 0x3448.</li>
                    <li>Bytes 0x3448-0x3457: the leaf. Data RVA = 0x7060, Size = 0x17D (381 bytes), Codepage = 0, Reserved = 0.</li>
                </ol>
                <p>The bytes at RVA 0x7060 (file 0x3460, because <code>.rsrc</code> sits at RVA 0x7000 / file 0x3400) open with an XML declaration — this binary embeds a Windows application manifest:</p>
                <div class="hex-dump">
                    <pre>00003460: 3c3f 786d 6c20 7665 7273 696f 6e3d 2731</pre>
                </div>
                <p>3c 3f is an opening angle bracket followed by a question mark, and 78 6d 6c spells xml. The second sample, <code>conpty.dll</code>, shows the same tree with more breadth: its type table counts 2 ID entries — 0x10 (RT_VERSION, 16) and 0x18 (RT_MANIFEST, 24) — with leaves of size 0x358 and 0x17D.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Any Windows executable works. On Linux or macOS, find the <code>.rsrc</code> file offset from the section table, then dump it (0x3400 for our sample):</p>
                <pre><code>$ xxd -s 0x3400 -l 96 cli-64.exe
00003400: 0000 0000 0000 0000 0000 0000 0000 0100  ................
00003410: 1800 0000 1800 0080 0000 0000 0000 0000  ................</code></pre>
                <p>Decode by hand: read the last two bytes of the header as a little-endian count, then read each entry as two 32-bit little-endian words. Mask the second word with 0x7FFFFFFF to get the next offset, and test the top bit to learn whether it is a subdirectory or a leaf.</p>
                <p>What to look for: the ID 0x18 should appear immediately, because almost every desktop executable ships a manifest. If you see IDs 3, 14, or 16 instead, you are looking at icons or a version block — the same tree, different Type ID.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: in a three-level resource walk, which level does the value 0x0409 identify?</p>
                <div class="quiz" id="quiz-resources-1">
                    <button class="quiz-option" data-correct="false" data-explain="Type IDs are the small well-known numbers like 3, 14, 16, and 24. 0x0409 = 1033 is far too large for a type." onclick="checkQuiz('quiz-resources-1', this)">The Type level — it selects RT_MANIFEST</button>
                    <button class="quiz-option" data-correct="false" data-explain="Name IDs identify the instance, such as icon 101. 1033 is the Windows language constant, not an instance number." onclick="checkQuiz('quiz-resources-1', this)">The Name level — it selects the instance</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x0409 = 1033 is LCID English (United States). Language IDs form the third level, and this entry pointed at the leaf holding the manifest bytes." onclick="checkQuiz('quiz-resources-1', this)">The Language level — it selects English (United States)</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A directory entry reads <code>1800 0000 1800 0080</code>. Before touching a hex editor again: where does this entry point, and relative to what?</p>
                <div class="quiz" id="quiz-resources-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x80000018 is the raw second word, not the address. Mask off the high bit before using it as an offset." onclick="checkQuiz('quiz-resources-2', this)">To file offset 0x80000018</button>
                    <button class="quiz-option" data-correct="false" data-explain="The high bit marks a subdirectory, not a leaf, so no Resource Data Entry is pointed to yet. The offset must also be relocated." onclick="checkQuiz('quiz-resources-2', this)">To a leaf data entry at offset 0x18</button>
                    <button class="quiz-option" data-correct="true" data-explain="The high bit 0x80000000 is set, so the low 31 bits (0x18) are an offset to the next directory table, measured from the start of the resource directory." onclick="checkQuiz('quiz-resources-2', this)">To the next directory table, 0x18 bytes from the directory start</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: mask the high bit for the offset, use the high bit itself as the branch, and remember the base is the directory — not the file.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Resources are static data a program carries for the loader and the shell. The next table is the opposite: data the loader actively writes into the image while threads are being created.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-tls">Thread-Local Storage</a> — the TLS directory, its per-thread template, and the callback array.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-load-config">Previous: The Load Configuration</a></span>
                <span><a href="/courses/pe/lessons/pe-tls">Next: Thread-Local Storage</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
