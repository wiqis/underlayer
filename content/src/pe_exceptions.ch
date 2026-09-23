// PE Course — Module 7: Exception Tables (.pdata / RUNTIME_FUNCTION / UNWIND_INFO).
// Verified against cli-64.exe and conpty.dll plus the x64 exception handling docs.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_exceptions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Exception Tables (.pdata) — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>Exception Tables (.pdata)</h1>
            <div class="lesson-meta">15 min · Module 7: Resources &amp; Runtime Tables · Structures</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>When a 64-bit Windows program faults, something has to rebuild the call stack: which function were we in, which registers were saved where, who called whom. The answer is not in the instructions — x64 code does not record frame pointers. It is in a side table the linker emits for every function that touches the stack or calls anything else.</p>
                <p>That table is what debuggers walk when you hit a crash dump, what the operating system walks when it dispatches an exception, and what C++ uses to find destructors during unwinding. Read it and crash analysis stops being guesswork: you can map a faulting address to a function and see exactly how big its stack frame is.</p>
                <p>Data directory index 3 (Exception Table) points at it. In <code>cli-64.exe</code> it holds RVA 0x6000 with size 0x1EC — the <code>.pdata</code> section.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Think of it as a table of contents for the stack:</p>
                <ol>
                    <li><strong>One entry per function</strong> — a 12-byte RUNTIME_FUNCTION: where the function starts, where it ends, where its unwind recipe lives. All three are RVAs.</li>
                    <li><strong>One recipe per entry</strong> — an UNWIND_INFO record: how many bytes the prolog took, and a short list of operations (push this register, subtract that many bytes from the stack) that an unwinder can run backwards.</li>
                </ol>
                <p>The model's missing piece: lookups are binary searches. The spec requires the entries be sorted by function address before the image is emitted, so the unwinder can find the function containing a faulting instruction in one pass.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The PE/COFF specification, chapter "The .pdata Section", defines the x64 and Itanium entry as three 4-byte fields — Begin Address, End Address, Unwind Information — and states plainly: these are RVAs, and the entries must be sorted according to the function addresses before being emitted into the final image. (The older MIPS format stores VAs instead; the x64 layout is the one that matters on modern machines.)</p>
                <p>Microsoft's x64 exception handling documentation adds the operational rules:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Structure</th><th scope="col">Contents</th><th scope="col">Rule</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>RUNTIME_FUNCTION (12 bytes)</td><td>Function start, function end, unwind info address</td><td>All addresses image-relative; DWORD aligned; entries sorted; stored in .pdata of a PE32+ image</td></tr>
                        <tr><td>UNWIND_INFO</td><td>Version (3 bits), Flags (5 bits), SizeOfProlog, CountOfCodes, FrameRegister and offset, then the unwind codes array</td><td>Version is currently 1; the codes array always holds an even number of entries</td></tr>
                        <tr><td>UNWIND_CODE (2 bytes)</td><td>Offset in prolog, unwind operation (4 bits), operation info (4 bits)</td><td>Array sorted by descending prolog offset</td></tr>
                    </tbody>
                </table>
                <p>The dispatch algorithm is documented too: search for a RUNTIME_FUNCTION covering the faulting RIP; if there is none, the code is a leaf function and the return address is simply at [RSP]; if RIP sits in the prolog or epilog, undo or simulate it; otherwise call the language-specific handler if UNW_FLAG_EHANDLER is set, then unwind frame by frame. JIT-generated code must register its own tables with RtlAddFunctionTable or RtlInstallFunctionTableCallback, or exception handling and debugging become unreliable.</p>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> End Address is exclusive: it is the first byte after the function, not the last byte of it. Padding after a ret instruction belongs to neither side of the boundary — yet a debugger that treats End as inclusive will misattribute exactly those bytes.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Forty-eight bytes from the start of <code>.pdata</code> in <code>cli-64.exe</code> (file offset 0x3200) — three complete entries:</p>
                <div class="hex-dump">
                    <pre>00003200: 1010 0000 3410 0000 c038 0000 4010 0000  ....4....8..@...
00003210: 8510 0000 8038 0000 a010 0000 fc11 0000  .....8..........
00003220: a438 0000 0012 0000 d012 0000 8c38 0000  .8...........8..</pre>
                </div>
                <p>The first entry decodes to Begin 0x1010, End 0x1034, UnwindInfo 0x38C0. Follow it end to end:</p>
                <ol>
                    <li>At image base 0x140000000 the function is 0x140001010 to 0x140001034. It opens with <code>sub rsp, 0x28</code> and the last instruction at 0x140001033 is <code>ret</code> — the byte at 0x140001034 is int3 padding, outside the function, exactly as an exclusive End predicts.</li>
                    <li>Unwind info RVA 0x38C0 lives in <code>.rdata</code> (RVA 0x3000, file 0x1C00), so file offset 0x24C0. First 8 bytes:</li>
                </ol>
                <div class="hex-dump">
                    <pre>000024c0: 0104 0100 0442 0000                      .....B..</pre>
                </div>
                <ol start="3">
                    <li>Byte 0: version 1, flags 0. Byte 1: SizeOfProlog = 4 — matches the 4-byte sub rsp instruction. Byte 2: CountOfCodes = 1. Byte 3: no frame register. Then one UNWIND_CODE: offset 0x04, operation 0x2 (UWOP_ALLOC_SMALL), info 0x4 — and the spec formula for that operation is info * 8 + 8 = 40 bytes = 0x28. The recipe and the machine code agree.</li>
                    <li>The section holds 41 entries (0x1EC / 12), sorted by Begin. <code>conpty.dll</code> has 354 (0x1098 / 12). Its first entry reads Begin 0x10C0, End 0x1105, UnwindInfo 0x14B50 — same layout, bigger program.</li>
                </ol>
                <p>The imports tell you who consumes these tables: <code>cli-64.exe</code> pulls RtlLookupFunctionEntry, RtlVirtualUnwind, and RtlCaptureContext from KERNEL32.dll, and __C_specific_handler from VCRUNTIME140.dll — the very APIs the unwinder and structured exception handling are built on.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Read the first table entry straight from the file (0x3200 is <code>.pdata</code> for our sample):</p>
                <pre><code>$ xxd -s 0x3200 -l 48 cli-64.exe
00003200: 1010 0000 3410 0000 c038 0000 4010 0000  ....4....8..@...
00003210: 8510 0000 8038 0000 a010 0000 fc11 0000  .....8..........
00003220: a438 0000 0012 0000 d012 0000 8c38 0000  .8...........8..</code></pre>
                <p>Then look at the code the first entry covers (command output, operand syntax reformatted for width):</p>
                <pre><code>$ objdump -d --start-address=0x140001010 --stop-address=0x140001036 cli-64.exe
140001010: 48 83 ec 28           sub    rsp, 0x28
14000102a: b8 01 00 00 00        mov    eax, 1
14000102f: 48 83 c4 28           add    rsp, 0x28
140001033: c3                    ret
140001034: cc                    int3</code></pre>
                <p>What to look for: sub and add of the same 0x28 pair up with the single UWOP_ALLOC_SMALL code, and End lands on the first int3 after ret. If those three numbers agree, your parser is reading the table correctly.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a RUNTIME_FUNCTION reads Begin 0x1010 and End 0x1034. Which byte is the last one inside the function?</p>
                <div class="quiz" id="quiz-exceptions-1">
                    <button class="quiz-option" data-correct="false" data-explain="That address is where the function starts (Begin), not where it ends." onclick="checkQuiz('quiz-exceptions-1', this)">0x1010</button>
                    <button class="quiz-option" data-correct="false" data-explain="End is exclusive — the first byte after the function — so treating it as the last byte of the function overlaps whatever comes next." onclick="checkQuiz('quiz-exceptions-1', this)">0x1034</button>
                    <button class="quiz-option" data-correct="true" data-explain="End = 0x1034 is the first byte outside, so the final byte of the function is End minus one = 0x1033, which is exactly where the ret instruction sits." onclick="checkQuiz('quiz-exceptions-1', this)">0x1033</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>An unwind code reads <code>04 42</code>: offset 0x04, operation 0x2, info 0x4. How much stack does the prolog allocate?</p>
                <div class="quiz" id="quiz-exceptions-2">
                    <button class="quiz-option" data-correct="false" data-explain="Info is not a byte count. For UWOP_ALLOC_SMALL the formula is info * 8 + 8, not info itself times anything smaller." onclick="checkQuiz('quiz-exceptions-2', this)">4 bytes</button>
                    <button class="quiz-option" data-correct="true" data-explain="Operation 0x2 is UWOP_ALLOC_SMALL, whose size is info * 8 + 8 = 4 * 8 + 8 = 40 bytes = 0x28 — the same sub rsp, 0x28 seen in the machine code." onclick="checkQuiz('quiz-exceptions-2', this)">40 bytes (0x28)</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x04 is the offset in the prolog where the operation ends, not the allocation size." onclick="checkQuiz('quiz-exceptions-2', this)">4 bytes at prolog offset 0x04 only</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: identify the operation first, then apply its formula — every unwind opcode packs meaning into those four info bits differently.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>You have now met the three runtime tables: resources, TLS, and exceptions. They all describe data the rest of the system consumes. The final module turns to the consumer itself — the loader that turns this file into a running process.</p>
                <p>Next: <a href="/courses/pe/lessons/pe-loader">How the Windows Loader Maps a PE</a> — from MZ probe to mapped sections and bound imports.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-tls">Previous: Thread-Local Storage</a></span>
                <span><a href="/courses/pe/lessons/pe-loader">Next: How the Windows Loader Maps a PE</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
