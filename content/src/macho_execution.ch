// Mach-O Course — Concept 24: The Startup Sequence.
// LC_MAIN, the entry arithmetic, what runs before main(), and how the process exits.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_macho_execution() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Startup Sequence — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson macho-lesson">
            <a href="/courses/macho" class="back-link">Back to course</a>
            <h1>The Startup Sequence</h1>
            <div class="lesson-meta">15 min · Module 8: Loading &amp; Execution</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>main() feels like the first instruction your program executes. It is not. Between your shell and main sit the kernel, dyld, and — in a normal binary — a startup stub that builds the argument vector before anyone asked for it. Miss that sequence and whole bug classes are unexplainable: crashes before main, constructors firing in "random" order, argv empty in a debugger that broke at entry, an exit code that does not match your return statement.</p>
                <p>It is also the payoff for the whole course. LC_MAIN is one load command; reading it correctly requires the header, the segments, the slide, and the entry-point arithmetic you have all met. One number, four concepts deep.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The sequence, from the outside in:</p>
                <ol>
                    <li><strong>execve:</strong> the kernel maps the segments declared by LC_SEGMENT_64, reads LC_LOAD_DYLINKER, maps <code>/usr/lib/dyld</code>, and hands over control.</li>
                    <li><strong>dyld's pipeline</strong> runs to completion — closure, fixups, exports, initializers — exactly the seven stages from the previous concept. Your code cannot run "during" any of it.</li>
                    <li><strong>The jump:</strong> dyld computes __TEXT.vmaddr + LC_MAIN.entryoff + slide and jumps there.</li>
                    <li><strong>Startup glue:</strong> the jump target sets up the main thread's stack frame carrying argc, argv, envp — <code>loader.h</code> says of the thread-command tradition that "command arguments and environment variables are copied onto that stack" — and the platform's C runtime initializes before calling main.</li>
                    <li><strong>main runs; its return value becomes the process exit status.</strong> The sequence ends where every shell script reads it: the wait status.</li>
                </ol>
                <p>The model's missing piece — the classic mistake — is stage 4's target. <code>loader.h</code> comments LC_MAIN's entryoff as "file (__TEXT) offset of main()", and our sample takes that comment literally: the offset lands on _main itself, startup stub skipped, because this tiny link contains no CRT. An ordinary clang-linked binary points entryoff at the startup stub in libsystem instead; only after that stub packs argc/argv/envp/apple does main() finally run. Same load command, two linker choices.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The command itself — <code>entry_point_command</code>, "a replacement for thread_command" (the old LC_UNIXTHREAD, which carried the initial stack). Its whole body for <code>prog64.macho</code>:</p>
                <div class="hex-dump">
                    <pre>       cmd LC_MAIN
   cmdsize 24
  entryoff 1104
 stacksize 0</pre>
                </div>
                <p>cmdsize 24, entryoff 1104 (0x450), stacksize 0 meaning "use the default" (the comment: "if not zero, initial stack size"). Now the three-number identity that proves what this value is:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Fact</th><th scope="col">Value</th><th scope="col">Source</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>LC_MAIN.entryoff</td><td>1104 (0x450)</td><td>load command 11 of prog64.macho</td></tr>
                        <tr><td>__TEXT vmaddr / fileoff</td><td>0x100000000 / 0</td><td>LC_SEGMENT_64 — fileoff 0 means offset maps 1:1 onto the base</td></tr>
                        <tr><td>Computed preferred entry</td><td>0x100000000 + 1104 = 0x100000450</td><td>arithmetic</td></tr>
                        <tr><td>nm: _main</td><td>0000000100000450 T _main</td><td>the symbol table — exact match</td></tr>
                    </tbody>
                </table>
                <p>Three independent readings agree to the byte: this binary's entry <em>is</em> main. Notice also where 1104 sits — past the load commands (which end at byte 999), inside __text (file 1040–1156): entryoff addresses code, never metadata. And 0x100000450 is already past __mh_execute_header at 0x100000000 — the image-base marker symbol, Mach-O's sibling of PE's ImageBase.</p>
                <div class="callout callout-warn">
                    <strong>Before main, without main.</strong> Anything in stages 1–4 can fail: an unmapped dependency, a failed fixup, a refusal over an unknown LC_REQ_DYLD command — all reported as dyld errors with your binary's name but none of your code on the stack. "Crashes before main" is a load-time diagnosis, not a debugging session.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Follow one instruction pointer from file bytes to first opcode. The 24 bytes at file offset 0x450 — entryoff itself as a file position:</p>
                <div class="hex-dump">
                    <pre>00000450: 5548 89e5 4883 ec10 c745 fc00 0000 00bf  UH..H....E......
00000460: 0100 0000 be02 0000                      ........</pre>
                </div>
                <p><code>55</code> = push %rbp, <code>48 89 E5</code> = mov %rsp,%rbp, <code>48 83 EC 10</code> = sub $0x10,%rsp — the standard function prologue, <em>main's own</em>, not a startup stub's. There is no CRT shim between dyld's jump and this push, because this link has no CRT to put there. Disassembled with addresses:</p>
                <div class="hex-dump">
                    <pre>100000450: 55                        pushq   %rbp
100000451: 48 89 e5                  movq    %rsp, %rbp
100000454: 48 83 ec 10               subq    $0x10, %rsp
100000458: c7 45 fc 00 00 00 00      movl    $0x0, -0x4(%rbp)
10000045f: bf 01 00 00 00            movl    $0x1, %edi</pre>
                </div>
                <p>The last two lines are our source's <code>main</code> getting ready to call add(1, 2) — the program text you read in prog.c, at the address LC_MAIN predicted. Runtime corollary: with a slide of 0x4000 every one of these bytes lives at 0x100004450 instead; the file never changes, the jump target does.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It</h2>
                <p>Prove the identity on any executable — on macOS the linker tools are <code>otool</code>, <code>nm</code>, <code>objdump</code>; LLVM ships <code>llvm-</code> prefixed versions:</p>
                <pre><code>$ python3 -c "print(hex(0x100000000 + 1104))"
0x100000450

$ llvm-nm prog64.macho | grep -E "_main|__mh"
0000000100000000 T __mh_execute_header
0000000100000450 T _main

$ llvm-objdump -d prog64.macho | grep -A4 "^100000450"
100000450: 55                        pushq   %rbp
100000451: 48 89 e5                  movq    %rsp, %rbp
100000454: 48 83 ec 10               subq    $0x10, %rsp
100000458: c7 45 fc 00 00 00 00      movl    $0x0, -0x4(%rbp)
10000045f: bf 01 00 00 00            movl    $0x1, %edi</code></pre>
                <p>What to look for: python's sum lands on nm's _main address exactly, and the disassembly starts with a function prologue — entry is a callable function, not a table or a trampoline. On your own binaries, read entryoff from otool first: if it lands on a symbol named <code>start</code> rather than <code>main</code>, you are looking at the CRT-era behavior this lesson described.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: what kind of value is LC_MAIN's entryoff — a file position, a load-command index, or a runtime address?</p>
                <div class="quiz" id="quiz-startup-1">
                    <button class="quiz-option" data-correct="false" data-explain="A runtime address would differ every launch — MH_PIE randomizes the base — yet entryoff is a constant written by the linker. dyld computes the runtime target by adding vmaddr and slide at load time." onclick="checkQuiz('quiz-startup-1', this)">A runtime virtual address, already slide-adjusted in the file</button>
                    <button class="quiz-option" data-correct="true" data-explain="loader.h says it directly: the field comment is 'file (__TEXT) offset of main()'. With __TEXT's fileoff at 0 it doubles as the offset from image start; the runtime jump is vmaddr + entryoff + slide." onclick="checkQuiz('quiz-startup-1', this)">A file offset within the __TEXT segment</button>
                    <button class="quiz-option" data-correct="false" data-explain="The load commands themselves end at byte 999 (32 + 968); entryoff 1104 sits well past them inside __text. An index into the command array would also be bounded by ncmds = 14." onclick="checkQuiz('quiz-startup-1', this)">An index or byte offset into the load command area</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>entryoff is 1104, __TEXT's vmaddr is 0x100000000, and at runtime dyld slid the image by 0x4000. At what address does the process jump?</p>
                <div class="quiz" id="quiz-startup-2">
                    <button class="quiz-option" data-correct="false" data-explain="0x100000450 is the preferred address — correct only before the slide. Since MH_PIE is set, the running image sits 0x4000 higher and jumping to the preferred address would land in unmapped space." onclick="checkQuiz('quiz-startup-2', this)">0x100000450 — base plus entryoff, ignoring the slide</button>
                    <button class="quiz-option" data-correct="true" data-explain="Preferred entry 0x100000000 + 1104 = 0x100000450, then the ASLR slide: 0x100000450 + 0x4000 = 0x100004450. That is the whole reason fixups and the jump happen in dyld rather than at link time." onclick="checkQuiz('quiz-startup-2', this)">0x100004450 — vmaddr + entryoff + slide</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x450 is the raw file offset, which at runtime falls inside __PAGEZERO — the NULL guard would fault it instantly. File offsets are never jumped to directly." onclick="checkQuiz('quiz-startup-2', this)">0x450 — the file offset is already the runtime target</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The pattern: entryoff is written once, at link time; the jump target is recomputed every launch — vmaddr + entryoff + slide — and everything before it must succeed first.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>That is the full arc: 32 header bytes that choose the parser, load commands that map, protect, and fix; a signature and UUID that attest; a dSYM that remembers; dyld that performs; a layout that slides; and one offset that fires. The bytes are still on disk exactly as you first read them — every lesson in this course was a different projection of the same file.</p>
                <p>Back to the course: <a href="/courses/macho">all 24 concepts</a>, the samples to practice on, and the spec sections each claim came from.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/macho/lessons/macho-memory-layout">Prev: Process Memory Layout</a></span>
                <span><a href="/courses/macho">Back to course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
