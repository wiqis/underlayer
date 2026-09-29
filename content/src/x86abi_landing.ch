// The x86-64 ABI — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86abi_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The x86-64 ABI — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson x86abi-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The x86-64 ABI</h1>
            <div class="lesson-meta">6 concepts &middot; 2 modules &middot; 150 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
            <p>Twenty-two courses came before this one and two more of this shape follow it, and a word-boundary scan over their 379 concept files, taken the morning this course was written, found <code>caller-saved</code> and <code>psABI</code> and <code>MXCSR</code> in <strong>zero files</strong>, and <code>red zone</code> and <code>callee-saved</code> and <code>GPR</code> in zero files but for one row of the assembly course's own scan table, which reports the same zero. Not one concept. Those are not exotic words. They are the words every C programmer uses and no course here had ever defined.</p>
                <p>What exists instead is a set of neighbours that each own one edge of this subject and none of which own the middle. <a href="/courses/sec/lessons/sec-canary">The security course's stack-protector concept</a> explains why a canary is there and links to the frame that holds it. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> explains what the loader puts at the bottom of the stack before <code>main</code> is entered. <a href="/courses/isa/lessons/isa-decode">The ISA course</a> teaches how to read an encoding. <a href="/courses/x86asm/lessons/x86-asm">The assembly course</a> teaches how to read a disassembly. Not one of them tells you which register the <em>fourth</em> integer argument goes in, and that is a question with a single answer and a great deal of history in it.</p>
                <p>So this course is the exhaustive x86-64 reference for the thing underneath all of those: <strong>the contract that two compilers agree on so that a function compiled by one can be called by code compiled by the other.</strong> It is the only course in this section whose distinctive idea is not about an instruction at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>The idea this course is built on</h2>
            <p>An ABI is not a description. It is a <strong>contract between two compilers</strong>, and a contract between two compilers is the one kind of thing you can check mechanically. The specification says which register argument four goes in; the compiler emits bytes; the two can be compared. That is not a reading of a manual. It is an audit, and this course ships one that runs.</p>
            <p>Here is it, on a corpus of sixteen call sites compiled four different ways, recovering not merely <em>which registers were occupied</em> but <em>which argument was in which register, by name</em>:</p>
            <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE AUDIT, PER OPTIMISATION LEVEL/,/^$/p'
  level   callers audited   match the specification   differ
  -O0                 16                       16         0
  -O1                 16                       16         0
  -O2                 16                       16         0
  -Os                 16                       16         0
  </pre>
            </div>
            <p>Sixty-four of sixty-four. The specification is the oracle and the compiler is the test subject, and the two agree at every optimisation level. That is the shape of the result; the numbers are in the last concept, which is where the audit belongs.</p>
            <div class="formula">
   WHAT AN AUDIT IS, AND WHAT A CENSUS IS NOT

   A census says: six registers were written before that call.
   An audit says: argument one was in %rdi, argument two in
   %rsi, argument three in %rdx, and argument FOUR in %rcx.

   The corpus makes that possible by giving every argument
   its own `volatile` global, so the disassembly names it,
   and by compiling at four optimisation levels, so that a
   claim about the ABI cannot be an artefact of one
   compiler's mood on one afternoon.
            </div>
            </div>

            <div class="unit unit-reality">
                <h2>The correction, and it is the course's reason for existing</h2>
            <p>This course was drafted with a central claim, and the claim is wrong, and the way it is wrong is the most useful thing in the course.</p>
            <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/3B\./,/^  SO HERE/p' \
    | grep -v RFLAGS \
    | sed 's/0x0000[0-9a-f]\{12\}/&lt;per-run address&gt;/'
  getpid() through libc                  = 982204
  %rax after the bare `syscall`          = 982204   match ? YES
  the instruction right after it         = &lt;per-run address&gt;
  %rcx BEFORE the syscall                = &lt;per-run address&gt;
  %rcx AFTER  the syscall                = &lt;per-run address&gt;
  %rcx == the address of the NEXT INSTRUCTION ?   YES
  %r10 after it, my own marker              = 0xfeedfacecafebeef  survived ? YES
  </pre>
            </div>
            <p>The draft said: <em>the fourth argument goes in <code>%r10</code>, because the C ABI gave <code>%rcx</code> to the fourth argument and the hardware took <code>%rcx</code> for the return RIP.</em> That sentence is <strong>two errors welded together</strong>, and separating them is the whole of the first concept.</p>
            <p>The one line left out of that block is the <code>%r11</code> one, and it is left out because its value is not stable: the instruction saves the <code>RFLAGS</code> it found, and bit 2 of that word is the parity flag, so the recorded run reads <code>0x202</code> or <code>0x206</code> depending on which number happened to be in <code>%rax</code>. <strong>Quoting an address, or a value that depends on the parity of a process id, and calling it a measurement is the mistake this course exists to avoid</strong> &mdash; so the pages quote the relation and not the address.</p>
            <ul>
                <li><strong>The fourth integer argument of an ordinary function call goes in <code>%rcx</code>.</strong> Measured, by name, sixty-four times out of sixty-four, at four optimisation levels. <code>%r10</code> is not in the argument register list at all; it is a temporary, and the eleventh thing you would reach for.</li>
                <li><strong>The return RIP is not in <code>%rcx</code> for a <code>call</code>.</strong> A <code>call</code> <em>pushes</em> it onto the stack, and the artifact reads the word at <code>0(%rsp)</code> at a callee's first instruction and it is a text-segment address while <code>%rsp</code> is a stack address.</li>
                <li><strong>What is true is about a different instruction.</strong> A bare <code>syscall</code> <em>does</em> write the address of the following instruction into <code>%rcx</code>, bit for bit, as the table above shows. And that is precisely why the Linux <em>system call</em> convention numbers its fourth argument <code>%r10</code>: it has to, because <code>%rcx</code> is busy.</li>
            </ul>
            <p>So the correct statement is not a fact about one register. It is the difference between <strong>two conventions on one machine</strong>, and a reader who has only ever been told one of them has been told half of each.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three results that are faults rather than timings</h2>
            <p>This course's measurements are mostly not durations. Where a stopwatch would have given a number, a fault gives a fact, and a fact does not move between runs.</p>
            <ul>
                <li><strong>A misaligned 16-byte vector store is not slow, it is a <code>SIGSEGV</code>.</strong> One callee, three arms: <code>movaps</code> through a conforming call returns, <code>movaps</code> through the same call with the caller's alignment idiom deleted dies with signal 11, and <code>movups</code> &mdash; the identical store, unaligned-tolerant &mdash; goes through the same misaligned call untouched. The alignment rule exists because the fault exists.</li>
                <li><strong>The red zone's first eight bytes are the return-address slot, and <code>call</code> writes them.</strong> A leaf function that stores a magic word at its own <code>-8(%rsp)</code> and then makes a call finds the word gone, and the artifact reads back what replaced it and finds the callee's own return address. The leaf restriction is not tidiness; it is arithmetic about where a push lands.</li>
                <li><strong>A caller that lies about <code>%al</code> does not get its arguments corrupted; it gets the previous call's arguments back.</strong> The floating-point values are put in <code>%xmm0</code> and <code>%xmm1</code>, the caller says it used no vector registers, and the consumer reads a save area that still holds the last honest call &mdash; bit for bit, and through glibc's <code>printf</code> as well as through its own.</li>
            </ul>
            <p>And one result is the absence of a thing, which is the hardest kind to present: a function compiled with <code>-fno-asynchronous-unwind-tables</code> returns <strong>one</strong> frame from <code>backtrace()</code> where it returns <strong>seven</strong> without the flag. Not a wrong answer. No answer. That is what a profiler does when the second description of a frame is missing, and it is the subject of the fifth concept.</p>
            </div>

            <div class="unit unit-apply">
                <h2>What this course will not claim, and what is deferred</h2>
            <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. <code>perf_event_paranoid</code> is <strong>4</strong> and a forked child that executed <code>RDPMC</code> was killed, so there is no event counter at all:</p>
            <ul>
                <li><strong>No cycle counts.</strong> Every duration in the artifact is a <em>duration</em>, and a duration bounds a count without measuring it. The instrument that would settle it is <code>perf_event_open</code> with a paranoid setting below 4 and a PMU passthrough.</li>
                <li><strong>Why the psABI says 16-byte alignment and not 8.</strong> The 1997 drafts argued from SSE2's 16-byte moves. This course can show you the fault that makes 16 necessary on <em>this</em> machine; it has no instrument for a drafting argument.</li>
                <li><strong>Whether a signal handler on this machine respects the 128-byte red-zone reservation.</strong> That is the psABI's stated reason the red zone exists, and it is a kernel property that a user-mode process cannot observe.</li>
                <li><strong>Windows x64, and every other ABI.</strong> Four integer registers instead of six, a 32-byte <em>shadow space</em> the caller must allocate for register arguments it is not using, and a different return convention. Quoted, not measured: there is no such machine in the room. The next course in this section is about the x86-64 machine rather than about the other two architectures.</li>
                <li><strong>Why glibc does what the checker says it does.</strong> The linter this course ships read 4,561 functions of <code>libc.a</code> and flagged 271 register uses. 97 of those are in functions whose entire contract is to restore a saved register context &mdash; <code>longjmp</code>, <code>backtrace</code>, <code>swapcontext</code> &mdash; and are therefore <em>required</em> to do what they were flagged for. A mechanical rule cannot know that, and neither can a reader of this page. It is the honest limit of an ABI linter and the last concept says so with a number beside it.</li>
            </ul>
            <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 143 checks, then break the positive control on purpose and make the group that catches it fail by name.</em> The control exists because this course's own linter once reported zero violations across 9,255 real functions, and every one of those zeroes was hollow &mdash; a ternary the wrong way round in a register-name normaliser meant it had never once recognised a callee-saved register. A check that has never been seen to fail is a check with no reason to be believed.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
            <p>Before. <a href="/courses/x86asm/lessons/x86-asm">The assembly course's first concept</a> is the prerequisite for the audit: this course's last one reads a disassembly and recovers an argument assignment from it, which is not possible without knowing that <code>addps %xmm1, %xmm0</code> and <code>addps xmm0, xmm1</code> are the same three bytes. <a href="/courses/sec/lessons/sec-canary">The stack-protector concept</a> is where the frame gets a canary in it and is linked rather than repeated: this course owes the exhaustive x86-64 reference and the security course owns the why. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where the stack is first set up, before any of the rules in this course have a chance to apply.</p>
            <p>Forward, and the practical weight is in a compiler backend. <strong>The two things a backend must get exactly right are the two things nobody thinks about</strong>, because both are invisible in the source: a C call with four integer arguments and a C call with four double arguments compile to code that shares no register at all, and a variadic call whose <code>%al</code> is wrong produces numbers that came from somewhere else. Neither mistake produces a diagnostic, and both produce plausible output.</p>
            <p>Outward, two neighbours that own the edges of this one. <a href="/courses/simd/lessons/simd-width">The vector course's width concept</a> measured what an unaligned access costs on this machine and found it free, which is exactly why this course's alignment result has to be a <em>fault</em> and not a slowdown: on this silicon the rule cannot have been written for a penalty. And the third course in this section, on the machine's privileged side, is where <code>%rcx</code> and <code>%r10</code> stop being a convention and start being the <code>syscall</code> instruction this course measured.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/x86abi/lessons/x86-calling">The Calling Convention, and the Register That Wasn't</a></span>
                <span>End of The x86-64 ABI &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
