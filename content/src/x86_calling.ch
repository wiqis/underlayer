// The x86-64 ABI — Concept 1: the calling convention
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_calling() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Calling Convention, and the Register That Wasn't — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>&uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>The Calling Convention, and the Register That Wasn't</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>A function call on x86-64 has no visible ceremony. There is no <code>push</code> of the arguments, no stack frame set up by the callee, no <code>ret</code> address computed. The caller puts six values into six registers and executes <code>call</code>, and that is the entire mechanism. Which six registers is therefore not a detail &mdash; it <em>is</em> the calling convention, and there is nowhere else to look it up.</p>
                <p>And the answer is one of those facts that is easy to get confidently wrong, because a plausible story circulates about it and the story is false in an instructive way. This course was drafted around that story:</p>
                <div class="formula">
   THE DRAFT OF THIS COURSE SAID

   "The fourth argument of a function call goes in %r10,
    because the C ABI gave %rcx to the caller's fourth
    argument and the hardware took %rcx for the return
    RIP."

   That sentence is TWO errors welded together, and
   separating them is the whole of this concept.
                </div>
                <p>The first error is checkable by reading a disassembly, and the audit below checks it sixty-four times. The second is checkable by reading a register, and the measurement in the second half of this page does it. Both halves are needed, because the first half alone leaves you with the fact that the fourth argument is <code>%rcx</code> and no reason to have believed anything else.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the specification as an oracle, the compiler as a test subject</h2>
                <p>The System V AMD64 ABI assigns integer arguments to registers in a fixed order. The <em>numbers</em> are the part nobody memorises and the part a backend cannot guess:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/1B\. THE SPECIFICATION/,/^  the two sequences/p'
1B. THE SPECIFICATION, PRINTED AS THE ORACLE AND NOT MEASURED.
    This is the only table in this file that is quoted.  Every
    other number below came out of this machine.

  integer argument registers   rdi rsi rdx rcx r8 r9
  their register numbers        7   6   2   1   8  9
  SSE argument registers       xmm0 .. xmm7, and NO others
  </pre>
                </div>
                <p>Read the numbers twice. <strong><code>%rcx</code> is register 1 and <code>%rdx</code> is register 2</strong> &mdash; they are not adjacent in the encoding order, and the fourth argument register is the one whose encoding number is the smallest of the six. <code>%r8</code> and <code>%r9</code> are numbers 8 and 9, continuing the physical order, which is why the list looks like it was assembled by taking registers 7, 6, 2, 1 and then starting again at 8.</p>
                <p>That is the specification. Here is the point of the course, which is that it can be <em>checked</em> rather than quoted. A corpus of sixteen call sites is compiled four ways, and a small program reads the disassembly back and recovers which <em>argument</em> went into which <em>register</em>, identified by name, because each argument's source is its own <code>volatile</code> global:</p>
                <div class="hex-dump">
                <pre>$ grep '^CALLER | O2' abi_dis.txt
CALLER | O2 | c_f6 | v11=rdi v12=rsi v13=rdx v14=rcx v15=r8 v16=r9 | v11=rdi v12=rsi v13=rdx v14=rcx v15=r8 v16=r9 | MATCHES THE SPECIFICATION
CALLER | O2 | c_f7 | v11=rdi v12=rsi v13=rdx v14=rcx v15=r8 v16=r9 v17=stack | v11=rdi v12=rsi v13=rdx v14=rcx v15=r8 v16=r9 v17=stack | MATCHES THE SPECIFICATION
CALLER | O2 | c_mx | w1=xmm0 w2=xmm1 w3=xmm2 w4=xmm3 v21=rdi v22=rsi v23=rdx v24=rcx | w1=xmm0 w2=xmm1 w3=xmm2 w4=xmm3 v21=rdi v22=rsi v23=rdx v24=rcx | MATCHES THE SPECIFICATION
  </pre>
                </div>
                <p>That third row is worth pausing on, because it is a belief rather than a fact that it used to be. <code>mx</code> takes four <code>double</code>s and four <code>long</code>s, interleaved, and the doubles go in <code>%xmm0</code> through <code>%xmm3</code> while the longs go in <code>%rdi</code>, <code>%rsi</code>, <code>%rdx</code>, <code>%rcx</code> &mdash; <strong>the integers do not start at <code>%rdi</code> <em>after</em> the doubles; the integers start at <code>%rdi</code> regardless of the doubles</strong>. The two sequences are independent counters. The specification says so, and this row is the measurement.</p>
                <p>And the seventh argument is not in a register at all. The caller's row says <code>v17=stack</code>, and the callee's row says where on the stack:</p>
                <div class="hex-dump">
                <pre>$ grep -E '^CALLEE \| O2 \| f[5-8]' abi_dis.txt
CALLEE | O2 | f5 | rdi rsi rdx rcx r8 | stack=none
CALLEE | O2 | f6 | rdi rsi rdx rcx r8 r9 | stack=none
CALLEE | O2 | f7 | rdi rsi rdx rcx r8 r9 | stack=0x10
CALLEE | O2 | f8 | rdi rsi rdx rcx r8 r9 | stack=0x18
  </pre>
                </div>
                <p><strong>One slot is 8 bytes past the return address, and the second is 8 past that.</strong> Those are the only two numbers in the calling convention that are not a register number, and the next concept is about what they are aligned to.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: where the return address is, and the one instruction that is not on the stack</h2>
                <h3>First, the return address is on the stack</h3>
                <p>The draft's second claim was that the hardware needs <code>%rcx</code> for the return RIP. Here is the word at <code>0(%rsp)</code> at a callee's first instruction, read by the callee itself:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/%rsp at that point/,/^  THE RETURN/p' \
    | sed 's/0x0000[0-9a-f]\{12\}/&lt;per-run address&gt;/'
    %rsp at that point                               &lt;per-run address&gt;  (a STACK address)
    0(%rsp) at that point                             &lt;per-run address&gt;  (a TEXT address)
    and the two are not within a few bytes of each other, which is the
    point: the word AT %rsp is not part of the stack.  It is the
    address `ret` will pop and jump to, and the control is that this
    function returned to its own caller rather than anywhere else.
    BOTH READINGS COME FROM ONE CALL, which is the only way a
    comparison between two readings of a register means anything.
  </pre>
                </div>
                <p><code>%rsp</code> names a stack address. The word sitting at that address is a code address, in a different part of the address space entirely. <strong><code>call</code> pushes the return RIP; <code>ret</code> pops it; no register is involved in either.</strong> The control is the second thing to read: the function returned to its own caller rather than somewhere else, which is what makes the word a return address rather than a coincidence.</p>
                <p>Both readings come from one call on purpose. The first version of this measurement asked for <code>%rsp</code> in one call and for <code>0(%rsp)</code> in another, and the two came from two different stack depths, so the comparison produced a number near 2<sup>64</sup> and printed as an address-looking value that is obviously wrong to a reader and was not caught for a whole build. <strong>A difference between two readings of a register is only meaningful if they are the same reading of the same instant.</strong></p>
                <h3>Second, there is one instruction that does take a register</h3>
                <p>Now the part of the draft that is true, attached to the instruction it is actually true of. A bare <code>syscall</code> writes the address of the following instruction into <code>%rcx</code>:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/getpid() through libc/,/survived/p' \
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
                <p>Read the things that are checked rather than assumed &mdash; and notice that the addresses are elided by the <code>sed</code> in the command above rather than by an author, because <strong>an address is not a measurement</strong>. This is a position-addressed binary, so the text base moves on every run; quoting one would invite the reader to compare it with the recorded output and conclude that something had changed when nothing had.</p>
                <ul>
                    <li><strong><code>%rcx</code> after the instruction equals the address of the instruction that follows it, bit for bit.</strong> The "after" label is right above the code that captured the address, and the program compares the two as numbers and prints the verdict. A memory address in a register and the address of the next instruction are not the same kind of thing to coincide by accident.</li>
                    <li><strong><code>%rax</code> after the instruction equals what libc's <code>getpid()</code> returned.</strong> So the instruction really was a system call and not a <code>nop</code> that happens to leave <code>%rcx</code> alone. The control is a value nobody put there.</li>
                    <li><strong><code>%r11</code> holds the <code>RFLAGS</code> value the instruction saved before entering the kernel</strong> &mdash; <code>0x202</code> or <code>0x206</code> in the recorded runs, the difference being bit 2, the parity flag, which depends on the parity of the process id that came back in <code>%rax</code>. That is the one line the <code>grep</code> in the command above drops, and dropping it is the honest move: a value that depends on the parity of a pid is not a result. Bit 1 is set, which the ISA requires of bit 1 in every <code>RFLAGS</code>, and bit 9 is the interrupt-enable flag, preserved across the call as a caller's value should be.</li>
                    <li><strong><code>%r10</code> came back holding the marker this program put there before the instruction.</strong> The kernel did not touch it, which is the entire reason the system call convention is free to use it.</li>
                </ul>
                <div class="formula">
   SO THE CORRECT STATEMENT IS NOT A FACT.  IT IS A
   COMPARISON BETWEEN TWO CONVENTIONS ON ONE MACHINE.

     an ordinary FUNCTION CALL
       fourth integer argument  %rcx
       return RIP               the stack, pushed by `call`

     a SYSTEM CALL
       fourth argument          %r10
       return RIP               %rcx, written by `syscall`
       also destroyed           %r11, the saved RFLAGS

   Both are the System V ABI.  They are different
   conventions, they disagree about one register, and the
   reason they disagree is one instruction wide.
                </div>
                <p>This is not a curiosity. It means that every time you read about &ldquo;the x86-64 calling convention&rdquo; you should ask <em>which</em> one, and the answer is visible in the disassembly: a call site that ends in <code>call</code> is the first, and one that ends in <code>syscall</code> is the second. They share five of their six argument registers. The sixth is the entire difference, and the fourth argument is where it shows.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the audit, and what it is worth</h2>
                <p>Here is the whole of the audit result, from the recorded run:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE AUDIT, PER OPTIMISATION LEVEL/,/^$/p'
  level   callers audited   match the specification   differ
  -O0                 16                       16         0
  -O1                 16                       16         0
  -O2                 16                       16         0
  -Os                 16                       16         0
  </pre>
                </div>
                <p>Sixty-four call sites audited, sixty-four matches, zero differences, at four optimisation levels. That is the course's distinctive idea stated as a number, and it is worth being precise about what it does and does not establish.</p>
                <p><strong>What it establishes</strong> is that a specification can be transcribed into a checker and the checker can be run against a real compiler's real output, and the two agree. That is a genuinely useful thing to have, because the specification is a document nobody re-reads and the compiler is a program that changes every quarter. A rule that has never been checked is a rule that is a memory.</p>
                <p><strong>What it does not establish</strong> is that the specification is <em>right</em>. The audit compares the emitted code against a transcription. If the transcription is wrong, the audit reports a perfect match with a wrong oracle, and the number 64 of 64 would be exactly as confident and exactly as wrong. The specification is section 1B of the artifact, printed separately from every measurement precisely so that a reader can check the oracle against the document it came from &mdash; <a href="https://gitlab.com/x86-psABIs/x86-64-ABI">the psABI itself</a> &mdash; in one reading, without a compiler in the way.</p>
                <p>And the corpus had to be built to make the question possible, which is where two of this collection's harder-won lessons went. Marking the functions <code>noinline</code> was not enough: at <code>-O2</code> gcc constant-folded every one of them, because the bodies are pure, so the calls <em>vanished</em> and the register assignment was no longer anywhere in the program. The attribute that works is <code>noipa</code>, which forbids interprocedural analysis of any kind. And even then, gcc knows the <em>value</em> of every argument in the caller, so the sources are <code>volatile</code> globals. A corpus that does neither measures the optimiser's mood rather than the ABI.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the audit before you read anything else.</strong> <code>cd courses/x86abi/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 2. <em>(Expect 16 of 16 at all four levels. If a row differs, do not assume the compiler is wrong: <code>grep DIFFERS abi_dis.txt</code> shows the mapping it recovered and the mapping it expected, and the interesting case is a parameter the optimiser deleted rather than a register it chose wrongly. Both readings are in the row, which is the point of printing both.)</em></li>
                    <li><strong>Change one register number in the oracle and watch the audit fail by name.</strong> Edit <code>SPEC["c_f4"]</code> in <code>mkabi.py</code> so that argument four is expected in <code>%rdx</code>, and re-run. <em>(Expect every level to report one difference, and the difference to be <code>c_f4</code> and only <code>c_f4</code>. A checker that fails on everything is not a checker; a checker that fails on exactly the thing you broke is an oracle.)</em></li>
                    <li><strong>Write the syscall arm yourself and watch the register change.</strong> Take the <code>getpid</code> block out of <code>abidump.c</code>, put it in its own file, and add a second <code>movq $marker, %r10</code> before the <code>syscall</code> and read it back after. <em>(Expect <code>%r10</code> to survive and <code>%rcx</code> to be gone. Then move the syscall number into <code>%r10</code> as well and confirm it fails &mdash; the kernel reads the number from <code>%rax</code>, and a system call with the number in the wrong register is <code>-ENOSYS</code> rather than a crash, which is its own small lesson about how much checking happens where.)</em></li>
                    <li><strong>Find the two sequences being confused in code you did not write.</strong> Take any C file with a variadic function or a hand-written assembly callee and ask, for each call site, which register each argument is in. <em>(Expect the answer to be available from the disassembly in one reading, and expect it to be <em>wrong</em> at least once if the code mixes integer and floating-point arguments. A function declared <code>f(double, long, double, long)</code> puts the doubles in <code>%xmm0</code>, <code>%xmm1</code> and the longs in <code>%rdi</code>, <code>%rsi</code> &mdash; not the longs in the two registers after <code>%xmm1</code>, which is not even a thing the hardware has.)</em></li>
                    <li><strong>Count how many of the six argument registers your project's own backend uses.</strong> If you are writing one, the question is not <em>can I pass six arguments in registers</em> but <em>which six, and what happens to the seventh, and does my caller know</em>. <em>(Expect the seventh to be a store to the outgoing argument area at <code>%rsp</code>, and expect the alignment of that area to be the subject of the next concept, where it turns out to be the difference between working and a <code>SIGSEGV</code>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86asm/lessons/x86-asm">the assembly course's syntax concept</a> is a prerequisite rather than a link: the audit in this concept reads a disassembly and recovers a mapping from it, and it cannot do that without knowing that <code>mov rdi,QWORD PTR [rip+0x2b26]</code> is a load whose destination is the operand on the <em>left</em>. <a href="/courses/x86asm/lessons/x86-integers">The integer set</a> is where <code>movabs</code>, the instruction every measurement here uses to plant a 64-bit marker, is taught. <a href="/courses/isa/lessons/isa-rex">isa-rex</a> is where register numbers 8 through 15 come from, which is why <code>%r8</code> is fifth in the argument list rather than being absent.</p>
                <p>Forwards, three things in this concept are the raw material of the next three. The <code>stack=0x10</code> in the table above is the seventh argument, and <strong>what it is aligned to</strong> is the subject of <a href="/courses/x86abi/lessons/x86-frame">the stack frame</a>, where the alignment rule turns out to be a fault rather than a slowdown and to be two rules rather than one. <code>%r8</code> and <code>%r9</code> are the only two of the six that are caller-saved <em>and</em> not used for anything else, which is the observation behind <a href="/courses/x86abi/lessons/x86-saved">the callee-saved concept</a>. And the independent double counter is what makes a variadic function possible at all, which is <a href="/courses/x86abi/lessons/x86-varargs">the varargs concept</a>.</p>
                <p>Outward, the neighbour that owns the other half of this page. The <code>syscall</code> measurement here is a register-level observation and deliberately stops there: <em>why Linux renumbered its argument list rather than saving and restoring <code>%rcx</code> is a decision recorded in the kernel, and this file cannot observe a decision.</em> The third course in this section is about the machine's privileged side, where <code>syscall</code> is not a curiosity but the only way into the kernel, and where the argument registers are the same six minus one.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi">The x86-64 ABI</a></span>
                <span>Next: <a href="/courses/x86abi/lessons/x86-frame">The Stack Frame, the Red Zone, and Two Rules</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
