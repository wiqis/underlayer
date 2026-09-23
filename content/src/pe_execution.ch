// PE Course — Module 8: The Startup Sequence.
// Verified entry bytes and __security_init_cookie walk from cli-64.exe.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_pe_execution() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Startup Sequence — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson pe-lesson">
            <a href="/courses/pe" class="back-link">Back to course</a>
            <h1>The Startup Sequence</h1>
            <div class="lesson-meta">15 min · Module 8: Loading and Execution · Runtime</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You have followed the PE from bytes on disk to a mapped image. The last hop is the one everybody skips: what actually runs first, and what has to happen before your main function sees a single line. The answer explains a whole class of real behavior — why a global C++ object can run code before main, why smashing a stack buffer can terminate a process instead of returning an error, why exception handlers work at all, and where those first crash addresses in a debugger come from.</p>
                <p>It also completes the contract. The loader jumps to AddressOfEntryPoint and its job is done. Everything after that is code the file itself shipped — the CRT startup, your entry, the exit path. The PE format drew the runway; the program takes off from it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Honest framing first: the PE specification defines the data, not the operating system algorithm, and kernel-to-thread handoff details are out of scope. What follows is a model built only from things you can verify in this file or in Microsoft documentation.</p>
                <ol>
                    <li><strong>The loader jumps to AddressOfEntryPoint</strong> — for program images the spec calls this the starting address. In <code>cli-64.exe</code> that is RVA 0x1D40, VA 0x140001D40.</li>
                    <li><strong>The CRT entry runs first.</strong> The linker default for a console program is mainCRTStartup, which calls main (Microsoft, "/ENTRY"). You never see its name in the symbol table of a stripped binary — you see its bytes.</li>
                    <li><strong>Security cookie setup.</strong> Before anything can overflow, __security_init_cookie reseeds the global cookie from system time, process and thread ids, and a performance counter.</li>
                    <li><strong>CRT initialization.</strong> The startup path initializes the CRT, runs static initializers, then calls main with the standard arguments.</li>
                    <li><strong>Exceptions are wired in.</strong> SetUnhandledExceptionFilter and the unwinder imports (RtlLookupFunctionEntry, RtlVirtualUnwind) show the machinery the CRT installs around your code.</li>
                    <li><strong>Exit flows back.</strong> main returns into the same startup code, which leaves through exit or the other CRT exit paths — TerminateProcess sits in the import table for the hard cases.</li>
                </ol>
                <div class="callout callout-warn">
                    <strong>Common mistake.</strong> Thinking AddressOfEntryPoint points at main. It points at the CRT wrapper. main is called several instructions and several thousand bytes later, after globals are initialized and the cookie is set.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The entry itself, first 32 bytes at file offset 0x1140 (RVA 0x1D40):</p>
                <div class="hex-dump">
                    <pre>00001140: 4883 ec28 e8d7 0300 0048 83c4 28e9 72fe
00001150: ffff cccc 4053 4883 ec20 488b d933 c9ff</pre>
                </div>
                <p>Disassembled, it is four moves — addresses verifiable with objdump:</p>
                <pre><code>140001d40: sub  rsp, 0x28          ; shadow space for the call
140001d44: call 140002120          ; __security_init_cookie
140001d49: add  rsp, 0x28
140001d4d: jmp  140001bc4          ; tail-jump into CRT startup
140001d52: int3                     ; padding
140001d54: rex push rbx             ; next function begins here</code></pre>
                <p>The cookie routine at 0x140002120, verified instruction by instruction (listed in Intel-style operand order, abridged for width):</p>
                <pre><code>140002120: mov  [rsp+0x18], rbx     ; home rbx
140002125: push rbp
140002126: mov  rbp, rsp
140002129: sub  rsp, 0x30
14000212d: mov  rax, [140005008]    ; current cookie slot in .data
140002134: mov  rbx, 0x2b992ddfa232 ; link-time default
14000213e: cmp  rax, rbx
140002141: jne  1400021b7           ; not the sentinel, skip seeding
14000214c: call GetSystemTimeAsFileTime ; seeds [rbp+0x10]
14000215a: call GetCurrentThreadId      ; xor into accumulator
140002166: call GetCurrentProcessId     ; xor into accumulator
140002176: call QueryPerformanceCounter ; fills [rbp+0x18]
140002183: shl  rax, 0x20
140002187: xor  rax, ...            ; mix counter, time, ids, pointer
140002192: mov  rcx, 0xffffffffffff
14000219c: and  rax, rcx            ; keep 48 bits
14000219f: mov  rcx, 0x2b992ddfa233 ; sentinel plus one
1400021ac: cmove rax, rcx           ; never leave the default in place
1400021b0: mov  [140005008], rax    ; store the fresh cookie
1400021bc: not  rax
1400021bf: mov  [140005000], rax    ; complement slot
1400021cb: ret</code></pre>
                <p>Three details worth pinning down. The indirect calls go through the IAT slots we mapped: 0x140003088, 0x140003090, 0x140003098, 0x1400030A0 — the same four imports from the table below. The cmove swaps in sentinel-plus-one if the mix would reproduce the default, so the stored value can never collide with the link-time constant. And a second slot at 0x140005000 receives the bitwise complement — the CRT global __security_cookie_complement, kept beside the cookie so runtime checks can compare against the inverted value.</p>
                <p>The slot it seeds is the eight bytes at file offset 0x3008 in <code>.data</code>:</p>
                <div class="hex-dump">
                    <pre>00003008: 32a2 df2d 992b 0000</pre>
                </div>
                <p>That is 0x00002B992DDFA232 — the exact default the code compares against, confirming this file still carries the link-time sentinel that the first run replaces.</p>
                <p>The tail-jump target 0x140001BC4 opens like classic CRT startup: it saves rbx, rsi, and rdi, passes 1 in the first argument register, calls 0x140001F0C, and branches on the boolean the callee returns — the shape of one-time initialization, though the exact CRT source is outside the PE contract. The documented shape is the same: initialize the CRT, run static initializers, call main, then tear down.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Put the imports next to the sequence and the story closes:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Import</th><th scope="col">IAT slot</th><th scope="col">Used for</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>GetSystemTimeAsFileTime, GetCurrentThreadId, GetCurrentProcessId, QueryPerformanceCounter</td><td>0x3088, 0x3090, 0x3098, 0x30A0</td><td>Seeding the security cookie in __security_init_cookie</td></tr>
                        <tr><td>RtlCaptureContext, RtlLookupFunctionEntry, RtlVirtualUnwind</td><td>0x30B0, 0x3040, 0x3048</td><td>Walking .pdata frames for exceptions and debugging</td></tr>
                        <tr><td>SetUnhandledExceptionFilter, UnhandledExceptionFilter</td><td>0x3058, 0x3050</td><td>Available to the startup path for a last-resort crash handler</td></tr>
                        <tr><td>exit, _exit, _cexit, _c_exit</td><td>0x3180 and neighbors</td><td>Returning from main without returning into the loader</td></tr>
                        <tr><td>TerminateProcess</td><td>0x3068</td><td>The hard stop when orderly shutdown is impossible</td></tr>
                    </tbody>
                </table>
                <p>Every row is a byte you can point at: the cookie seeds come from the entry walk, the unwinder imports match the .pdata section from the previous lesson, and the exit family sits in UCRT waiting for main to come back. The sequence is not folklore — it is the import table telling you what the startup code is allowed to do.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>objdump puts the entry address on the first line of the file report, and -d starts disassembly there (raw output, operands in AT&amp;T order):</p>
                <pre><code>$ objdump -d cli-64.exe --start-address=0x140001d40
140001d40: 48 83 ec 28             sub    $0x28,%rsp
140001d44: e8 d7 03 00 00          call   0x140002120
140001d49: 48 83 c4 28             add    $0x28,%rsp
140001d4d: e9 72 fe ff ff          jmp    0x140001bc4</code></pre>
                <p>On Windows the same view comes from dumpbin /disasm. What to look for: a call or jump in the first five instructions means you are in the CRT wrapper, not in main — search the import table or step until you see argument setup for the program itself.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a PE with AddressOfEntryPoint at RVA 0x1D40 loads and runs. Is 0x1D40 the address of main?</p>
                <div class="quiz" id="quiz-execution-1">
                    <button class="quiz-option" data-correct="false" data-explain="AddressOfEntryPoint is a single value in the optional header; there is no separate field pointing at main." onclick="checkQuiz('quiz-execution-1', this)">Yes — the spec has a separate field for it and both point at main</button>
                    <button class="quiz-option" data-correct="true" data-explain="It is the CRT startup (mainCRTStartup for console programs). The first instructions set up the security cookie and tail-jump deeper; main runs only after CRT initialization." onclick="checkQuiz('quiz-execution-1', this)">No — it is the CRT wrapper; main runs later</button>
                    <button class="quiz-option" data-correct="false" data-explain="TLS callbacks may run first for DLLs that register them, but that does not make AddressOfEntryPoint equal main either." onclick="checkQuiz('quiz-execution-1', this)">No — TLS callbacks run there and main never does</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>The cookie slot in .data reads 0x00002B992DDFA232 and the entry code compares against that same constant. What does it conclude on first run?</p>
                <div class="quiz" id="quiz-execution-2">
                    <button class="quiz-option" data-correct="true" data-explain="An equal comparison means the link-time sentinel is still in place, so the routine mixes time, ids, and a counter into a fresh value and writes it back to the slot." onclick="checkQuiz('quiz-execution-2', this)">The sentinel is untouched — seed a fresh cookie and store it</button>
                    <button class="quiz-option" data-correct="false" data-explain="Equality with the default is the branch that DOES seed; an unequal value means someone already wrote a cookie and the routine skips seeding." onclick="checkQuiz('quiz-execution-2', this)">The cookie is already random — leave it alone</button>
                    <button class="quiz-option" data-correct="false" data-explain="The jne on inequality exits without reseeding; there is no abort path for a default cookie." onclick="checkQuiz('quiz-execution-2', this)">The process aborts — the sentinel indicates corruption</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: the link-time constant is a known value precisely so the loader-side code can tell untouched files from already-running processes.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That closes the arc: bytes, headers, directories, resources, TLS, exceptions, loading, memory, and now the first instructions that ever execute. Every claim above was read out of <code>cli-64.exe</code> or quoted from the spec and Microsoft documentation.</p>
                <p>Back to the <a href="/courses/pe">course index</a> to review the full sequence, or revisit <a href="/courses/pe/lessons/pe-loader">the loader lesson</a> — it is the hinge the whole module turns on.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/pe/lessons/pe-memory-layout">Previous: Process Memory Layout</a></span>
                <span><a href="/courses/pe">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
