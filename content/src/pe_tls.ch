// PE Course — Module 7: Thread-Local Storage (.tls / IMAGE_TLS_DIRECTORY).
// TLS directory, template, index, callbacks — verified against conpty.dll.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_tls() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Thread-Local Storage — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Thread-Local Storage</h1>
            <div class="lesson-meta">15 min · Module 7: Resources &amp; Runtime Tables · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A global variable has one copy for the whole process. The moment two threads write it, your program is guessing. Thread-local storage gives every thread its own copy of a variable, declared once and used like a normal static: <code>__declspec (thread) int tlsFlag = 1;</code> — the exact example from the PE/COFF specification.</p>
                <p>The format supports this with a dedicated structure. The loader reads it, hands each thread a private block of memory, seeds it from a template, and (optionally) runs your callback functions at thread start and exit. Compilers, runtimes, and even the operating system lean on it: exception state, locale, random seeds, and C run-time per-thread data all live here.</p>
                <p>Data directory index 9 (TLS Table) points at the TLS directory. An image with no static TLS simply leaves that slot empty — our <code>cli-64.exe</code> does exactly that — while <code>conpty.dll</code> carries a full one.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of TLS as a photocopy machine with a master sheet:</p>
                <ol>
                    <li><strong>The template</strong> — a master block of initial bytes in the image. Every new thread gets a fresh copy of it.</li>
                    <li><strong>The index</strong> — a slot number the loader writes into your image so the code can find which entry of the thread array belongs to this module.</li>
                    <li><strong>The callbacks</strong> — an optional, null-terminated array of functions the loader can call at thread and process attach or detach.</li>
                </ol>
                <p>The model's missing piece: the TLS directory does not use relative addresses. Its pointers are full virtual addresses, which ties the structure to the load address and forces the file to carry base relocations for it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The specification chapter "The .tls Section" gives the six fields (PE32+ sizes):</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Spec rule</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td>8</td><td>Raw Data Start VA</td><td>Start of the template — a VA, not an RVA; there should be a base relocation for it in .reloc</td></tr>
                        <tr><td>8</td><td>8</td><td>Raw Data End VA</td><td>Last byte of the template, also a VA</td></tr>
                        <tr><td>16</td><td>8</td><td>Address of Index</td><td>Location in an ordinary data section where the loader assigns the TLS index</td></tr>
                        <tr><td>24</td><td>8</td><td>Address of Callbacks</td><td>Pointer to a null-terminated array of callback functions; an empty list is valid</td></tr>
                        <tr><td>32</td><td>4</td><td>Size of Zero Fill</td><td>Extra bytes beyond the template, zero-filled for each thread</td></tr>
                        <tr><td>36</td><td>4</td><td>Characteristics</td><td>Bits [23:20] hold IMAGE_SCN_ALIGN_* alignment; the other 28 bits are reserved</td></tr>
                    </tbody>
                </table>
                <p>The spec also spells out how code reaches its per-thread data: the linker places the Address of Index so the runtime can read the index the loader writes there; the loader publishes each thread TLS array through the thread environment block (the spec notes the FS register and the 0x2C offset as Intel x86-specific details); code then indexes that array to find this module's data area for the current thread, and every variable is a fixed offset into that area.</p>
                <p>Callback functions take the same three parameters as a DLL entry-point function — DLL handle, reason, reserved — and the reason values are DLL_PROCESS_DETACH (0), DLL_PROCESS_ATTACH (1), DLL_THREAD_ATTACH (2), and DLL_THREAD_DETACH (3). Multiple callbacks run in array order; a null pointer ends the list, and the spec states it is perfectly valid to have an empty list whose only member is that null pointer.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> The data directory entry for TLS is an RVA of the TLS directory itself, but every address inside the directory is an absolute VA. Parse the outer pointer as an RVA, then treat the six inner pointers as VAs — otherwise your template address is off by ImageBase.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p><code>conpty.dll</code> declares TLS directory index 9 at RVA 0x14180, size 0x28, which lands at file offset 0x12D80 in <code>.rdata</code>. Decoding all six fields:</p>
                <div class="hex-dump">
                    <pre>00012d80: 404b 0180 0100 0000 484b 0180 0100 0000  @K......HK......
00012d90: 888a 0180 0100 0000 7814 0180 0100 0000  ........x.......
00012da0: 0000 0000 0000 3000                      ......0.</pre>
                </div>
                <p>Walk-through:</p>
                <ol>
                    <li>Start VA = 0x180014B40, End VA = 0x180014B48 — an 8-byte template. Those bytes read <code>00 00 00 00 00 00 00 80</code> (file 0x13740), the initial value this module gives each thread block.</li>
                    <li>Address of Index = 0x180018A88, inside <code>.data</code>. That section has VirtualSize 0xC30 but SizeOfRawData only 0x400, and the index sits at offset 0xA88 — beyond the raw bytes. Per the spec, the remainder is zero-filled in memory, so the slot exists at runtime but not on disk, waiting for the loader to write the assigned index.</li>
                    <li>Address of Callbacks = 0x180011478 → file 0x10078 holds eight zero bytes: the null terminator and nothing else. This DLL registers no TLS callbacks, which the spec explicitly allows.</li>
                    <li>Size of Zero Fill = 0. Characteristics = 0x00300000: bits [23:20] equal 3, the IMAGE_SCN_ALIGN_4BYTES value.</li>
                </ol>
                <div class="hex-dump">
                    <pre>00010078: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00013740: 0000 0000 0000 0080                      ........</pre>
                </div>
                <p>The spec also carries a practical warning: before Windows Vista, static TLS was unreliable in DLLs loaded with LoadLibrary; later loaders can allocate TLS slots for such DLLs at load time. If you ship static TLS in a DLL, that history is part of your compatibility story.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>On Windows, dumpbin shows the whole structure and the callback addresses (Microsoft, "dumpbin /TLS"):</p>
                <pre><code>dumpbin /TLS conpty.dll</code></pre>
                <p>On Linux or macOS, dump the directory bytes and decode six little-endian fields (the last two are 32-bit):</p>
                <pre><code>$ xxd -s 0x12d80 -l 40 conpty.dll
00012d80: 404b 0180 0100 0000 484b 0180 0100 0000  @K......HK......
00012d90: 888a 0180 0100 0000 7814 0180 0100 0000  ........x.......
00012da0: 0000 0000 0000 3000                      ......0.</code></pre>
                <p>What to look for: the top byte of each VA is 0x01 — the images live at 0x180000000 and 0x140000000 style bases, so the high byte of a 64-bit little-endian pointer shows up at the far right of its group. And if the last two bytes decode to 0x00300000, you have just read the alignment field.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: whose job is the value stored at Address of Index, and where does it live?</p>
                <div class="quiz" id="quiz-tls-1">
                    <button class="quiz-option" data-correct="false" data-explain="The linker only reserves the slot; the image cannot know its thread-array position until the loader runs." onclick="checkQuiz('quiz-tls-1', this)">The linker writes the final index at link time</button>
                    <button class="quiz-option" data-correct="true" data-explain="The spec says the loader assigns the TLS index to the place indicated by Address of Index. The location sits in an ordinary data section so the program can read it by symbol." onclick="checkQuiz('quiz-tls-1', this)">The loader writes the assigned index there, at load time</button>
                    <button class="quiz-option" data-correct="false" data-explain="Each thread has its own data area; this field is a single process-wide index shared by all threads of the module." onclick="checkQuiz('quiz-tls-1', this)">Each thread writes its own index into that slot</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A TLS directory has Characteristics = 0x00300000. What do bits [23:20] say, according to the spec?</p>
                <div class="quiz" id="quiz-tls-2">
                    <button class="quiz-option" data-correct="false" data-explain="The spec reserves the other 28 bits; this value sits entirely inside bits [23:20], which hold alignment, not a reserved-zero field." onclick="checkQuiz('quiz-tls-2', this)">The field must be zero, so this file is malformed</button>
                    <button class="quiz-option" data-correct="true" data-explain="0x00300000 shifted down by 20 bits is 3, the IMAGE_SCN_ALIGN_4BYTES value. The spec says bits [23:20] carry the IMAGE_SCN_ALIGN_* alignment." onclick="checkQuiz('quiz-tls-2', this)">The value 3 — IMAGE_SCN_ALIGN_4BYTES</button>
                    <button class="quiz-option" data-correct="false" data-explain="Control Flow Guard bits live in DllCharacteristics and the load configuration, not in the TLS directory." onclick="checkQuiz('quiz-tls-2', this)">It enables Control Flow Guard for TLS callbacks</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: mask the four bits, shift them down 20, and match the enum — the same bit-reading habit every PE flag needs.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>TLS describes per-thread data and startup hooks. The next table describes something much less friendly: how the processor is supposed to rebuild a stack that has already crashed.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-exceptions">Exception Tables (.pdata)</a> — RUNTIME_FUNCTION entries that make x64 unwinding work.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-resources">Previous: The Resource Directory</a></span>
                <span><a href="/courses/pe/lessons/pe-exceptions">Next: Exception Tables (.pdata)</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
