// The x86-64 ABI — Concept 6: the artifact and the audit
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Read the ABI Out of the Disassembly — Underlayer")
    page.appendTitle(&title)

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
            <h1>Read the ABI Out of the Disassembly</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>This is the concept that decides which of the other five you are allowed to believe, and it is the one that turns the course's argument from a set of claims into a method.</p>
                <p>An ABI is not a description. It is a contract between two compilers, and <strong>a contract between two compilers is the one kind of thing in this whole course that can be checked mechanically.</strong> The specification says which register argument four goes in; the compiler emits bytes; the two can be compared without a human being in the loop. That is worth having for a reason that is easy to miss: the specification is a document nobody re-reads, and the compiler is a program that changes every quarter. A rule that has never been checked is a rule that is a memory.</p>
                <p>And there is a second thing this concept settles, which the previous five could not. Four of them produced a number that somebody could have typed in. The alignment result is a <code>SIGSEGV</code>; the red-zone result is a word read back out of the slot a <code>call</code> overwrote; the varargs result is a bit pattern that is bit-for-bit a different call's argument. <strong>Those do not move between runs and they do not depend on a tolerance.</strong> The audit below is in the same category: 64 of 64 is 64 of 64 on a busier machine and a busier day.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the corpus, and the two things that had to be fixed</h2>
                <p>The audit needs a corpus in which the argument assignment is a fact about the emitted code rather than a fact about the optimiser's mood. Two things had to be arranged, and both were learned by getting them wrong.</p>
                <h3>The optimiser deletes the experiment</h3>
                <p>The first corpus marked its functions <code>noinline</code>, which stops the inliner and nothing else. At <code>-O2</code> the bodies are pure, so gcc constant-folded every one of them: the calls <em>vanished</em>, <code>call_each</code> became a run of <code>mov $0x7, %edi; call abi_sink</code>, and the register assignment was no longer anywhere in the program. A census would still have printed six numbers. The numbers would have been about nothing.</p>
                <p>The attribute that works is <code>noipa</code>, which forbids interprocedural analysis of any kind. That is not a detail of this course's corpus; it is the general shape of the problem, and it is the reason a microbenchmark written as ordinary C so often measures the wrong thing.</p>
                <h3>And the argument has to be identifiable</h3>
                <p>Even with <code>noipa</code>, gcc knows the <em>value</em> of every argument in the caller, so it propagates it and the register each argument lands in becomes an implementation detail of the propagation. So each argument's source is its own <code>volatile</code> global, and the corpus is <em>linked</em> before it is read: in a <code>.o</code> every RIP-relative load reads <code>[rip+0x0]</code> and the identity of the argument is not in the file at all. In a linked executable, objdump prints the symbol in the comment:</p>
                <div class="hex-dump">
                <pre>$ objdump -d --no-show-raw-insn -M intel ./x2 | sed -n '/&lt;c_f7&gt;:/,/^$/p'
0000000000000420 &lt;c_f7&gt;:
  420:	endbr64
  424:	sub    rsp,0x10
  428:	mov    rax,QWORD PTR [rip+0x0]        # 42f &lt;c_f7+0xf&gt;
  42f:	mov    r9,QWORD PTR [rip+0x0]        # 436 &lt;c_f7+0x16&gt;
  436:	mov    r8,QWORD PTR [rip+0x0]        # 43d &lt;c_f7+0x1d&gt;
  43d:	mov    rcx,QWORD PTR [rip+0x0]        # 444 &lt;c_f7+0x24&gt;
  444:	push   rax
  445:	mov    rdx,QWORD PTR [rip+0x0]        # 44c &lt;c_f7+0x2c&gt;
  44c:	mov    rsi,QWORD PTR [rip+0x0]        # 453 &lt;c_f7+0x33&gt;
  453:	mov    rdi,QWORD PTR [rip+0x0]        # 45a &lt;c_f7+0x3a&gt;
  45a:	call   45f &lt;c_f7+0x3f&gt;
  </pre>
                </div>
                <p>That is the linked form. The reader resolves each <code>mov</code> to a symbol and gets a mapping from <em>argument</em> to <em>register</em>, and the seventh argument is visible as a <code>push</code> rather than a register. Recovering that from a <code>.o</code> is not possible, and the first version of the reader produced sixteen rows of <code>(no arguments)</code> on every optimisation level for exactly that reason.</p>
                <h3>One caller per callee, and never count</h3>
                <p>The third fix is smaller and is the seventh time in this collection that a helper written for one shape has been used on another. The first caller was one function with sixteen calls in it, and the reader identified each call site by <em>counting</em> &mdash; because a call to an external function is a relocation and objdump cannot name it. Counting assumed the compiler kept the calls in source order, which is an assumption about the optimiser inside the instrument that is supposed to be auditing the optimiser. One function per call site removes the assumption, and <code>call f4</code> is a call to a symbol objdump <em>can</em> name.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: three results, and one that is a version claim</h2>
                <h3>Result one: the audit passes, everywhere</h3>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE AUDIT, PER OPTIMISATION LEVEL/,/^$/p'
  level   callers audited   match the specification   differ
  -O0                 16                       16         0
  -O1                 16                       16         0
  -O2                 16                       16         0
  -Os                 16                       16         0
  </pre>
                </div>
                <p>Sixty-four of sixty-four, and the harness asserts it as a <em>partition</em> rather than as a number: at every level, matched plus differing must equal audited, and differing must be zero. A partition is the right shape because it is the thing that catches a reader which silently stopped looking &mdash; a reader that returned nothing would report 0 of 16 rather than 16 of 16, and the partition makes that visible.</p>
                <h3>Result two: a real library, and the flags that are not violations</h3>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/^  LIBRARY |/,/^  CLAPPERCONTEXT/p'
  LIBRARY | libc.a | 6238972 bytes
  FUNCTIONS | 4561 functions, and the register census is:
  CENSUS | rbx | 1670 | 1598
  CENSUS | rbp | 2555 | 2503
  CENSUS | r12 | 1242 | 1193
  CENSUS | r13 | 981 | 945
  CENSUS | r14 | 885 | 850
  CENSUS | r15 | 627 | 600
  CLOBBERFLAGS | 271 | 94 functions
  CLOBBERKIND | leaf | 26 | nonleaf | 245
  CLAPPERCONTEXT | 97 | 174
  </pre>
                </div>
                <p>4,561 functions, and the second column of the census is the one that makes the flags column mean anything: 1,670 functions <em>write</em> <code>%rbx</code> and the checker examined 1,670 real cases. A zero in a violation column is only meaningful next to a non-zero in a census column, and that is the single most transferable sentence in this section.</p>
                <p>The flags decompose, and the decomposition is the result. 26 of the 271 are in <em>leaf</em> functions, which may clobber a callee-saved register if the compiler knows no caller had a live value there. 97 are in functions whose contract is to install a saved register context and which are therefore <em>required</em> to destroy those registers. <strong>Both exemptions are real and neither is checkable from inside one function</strong>, which is the honest limit of an ABI linter and the reason a reader who reports all 271 as bugs is reporting the rule.</p>
                <p>And they are <strong>not disjoint</strong>, which is the one piece of arithmetic in this course that was wrong before it was written. Three of the 271 are in functions that are <em>both</em> leaves <em>and</em> context restorers &mdash; <code>setjmp</code> and its relatives are exactly that shape &mdash; so the flags that are neither exemption total <strong>151</strong>, not the 148 that <code>271 &minus; 26 &minus; 97</code> gives. The linter now reports the overlap as its own row so the subtraction cannot be performed by accident, and the artifact's tenth retraction is about this arithmetic rather than about glibc.</p>
                <h3>Result three, and it is a version claim rather than a fact</h3>
                <p>The brief for this course asked for at least one case where the compiler disagrees with the specification, or else a demonstration that it does not on this version. <strong>The honest answer is the second, and it must be labelled as the second.</strong> On gcc 15.2.0 / binutils 2.46, reading 4,561 functions of glibc's static library and a 16-call-site corpus at four optimisation levels, this course found <strong>no case where a non-leaf function writes a callee-saved register without saving it</strong>, and no case where the emitted argument assignment differs from the specification.</p>
                <p>That is a <strong>version claim</strong>, not a law, and the difference is worth being pedantic about. It says what a checker saw on one machine on one day with one compiler. A new compiler version, a different distribution's build flags, or a function compiled by a hand-written assembly file are all outside it. What makes it worth having anyway is that it is <em>cheap to re-run</em>: <code>./build_samples.sh</code> and the claim is re-checked in about twenty seconds, which is the property that a hand-inspection of a specification does not have.</p>
                <div class="formula">
   THE CLAIM, STATED SO IT CAN BE FALSIFIED

   On gcc 15.2.0 and binutils 2.46, the System V AMD64
   argument assignment emitted by this compiler for 16
   call sites at -O0, -O1, -O2 and -Os matches the
   specification in 64 of 64 cases, and no non-leaf
   function among 4,561 in glibc's static library writes
   a callee-saved register without saving it.

   To falsify it: change the compiler, or add a
   hand-written callee that breaks the rule, or run the
   linter over a library built by a different distribution.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the harness, and the retraction that only a harness could catch</h2>
                <p>The harness for this course is 143 checks in nine groups, and it asserts structure exactly and timings as orderings &mdash; which on this machine means it asserts almost no numbers at all, because the results that matter here are faults, bit patterns and words of disassembly, and those do not move between runs.</p>
                <p>It runs against a <strong>fresh</strong> run rather than against the recorded output, so &ldquo;the claims still hold on this machine today&rdquo; is a statement about the machine rather than a tautology about a checked-in file. The recorded output ships anyway, so the claims are checkable on a machine that never ran the benchmark.</p>
                <h3>And here is the retraction, which is the best bug in the course</h3>
                <p>The linter reported <strong>zero violations across 9,255 real functions</strong> of libc, libm, the dynamic loader, libcrypto and <code>/bin/ls</code>. Every one of those zeroes was hollow. The expression that normalises a register name had its ternary the wrong way round, so <code>"r12"</code> came back as <code>"e12"</code>, nothing was ever recognised as a callee-saved register, and the check compared nothing against anything. The number looked perfect because it was empty, and the only reason it was empty was a bug.</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/THE POSITIVE CONTROL/,/flags everything/p'
  THE POSITIVE CONTROL, without which every zero above is hollow:

    FLAGGED   ct_clobber_r12
    FLAGGED   ct_clobber_r13
    FLAGGED   ct_clobber_rbx
    CLOBBERFLAGS | 3 | 3 functions
    ALIGNCALLS | 5 | 1   &lt;- and the one intended alignment violation
    ct_ok_leaf and ct_ok_leaf4 are conforming and are NOT in that
    list, which is the other half of the control: a linter that
    flags everything is caught as loudly as one that flags nothing.
  </pre>
                </div>
                <p><code>control.s</code> exists because of that, and it is the most transferable thing in the course. Its every function is a violation on purpose, in a named way, and the harness requires the linter to flag all three of them <em>and not to flag the two conforming ones</em>. The second half matters as much as the first: a linter that flags everything is caught just as loudly as one that flags nothing, and both look like a working linter on a page of output.</p>
                <p>The control was itself written twice, and the first version is worth recording because it fails in a way nobody expects. Written in C, the compiler <strong>repaired two of the three violations</strong>: it pushed <code>%rbx</code> around the <code>movq</code> on its own, and it deleted the <code>leaq</code> that was supposed to misalign the call. <em>The compiler repairs what it can</em> &mdash; which is the whole point of the file, stated differently, and the reason a positive control for an ABI checker has to be written in a language the compiler does not repair.</p>
                <h3>And the retraction that is about a checker, not about code</h3>
                <p>The linter's second half tracks <code>%rsp</code> and checks the 16-byte alignment at every call site, and it reported 775 of 9,980 call sites misaligned. The first draft of this course was going to print that as a finding: <em>glibc keeps the stack aligned at 92&nbsp;% of its call sites, and the rest is a list of bugs.</em></p>
                <p>That number is a fact about the <strong>checker</strong> and not about glibc, and the artifact says so where it prints it. The tracker loses <code>%rsp</code> at <code>pushfq</code>, at <code>enter</code>, and at any write it does not model, and a checker that cannot account for a mismatch is not evidence of a mismatch. It is the seventh time in this collection that the same lesson has cost something, and the general form is the one worth carrying: <strong>when a checker finds a great many of something, the first question is not how many it found but how many it looked at.</strong> The census column exists precisely so that question has an answer.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the whole thing.</strong> <code>cd courses/x86abi/assets/samples &amp;&amp; ./build_samples.sh</code>. <em>(Expect 143/143, and expect the harness to run against a fresh run so that the result is about your machine. If a group fails, the group name tells you which claim moved: <code>A</code> is the instrument, <code>C</code> is the audit, <code>E</code> is a fault, <code>H</code> is the linter. A failure in <code>A</code> means the machine is too noisy for the floor and everything after it is suspect.)</em></li>
                    <li><strong>Break the oracle and confirm it fails by name.</strong> Change one register in <code>SPEC</code> in <code>mkabi.py</code> and re-run. <em>(Expect one row to report <code>DIFFERS</code> at all four levels, and the row to be the one you broke. Then change the <em>audit</em> rather than the oracle &mdash; make <code>caller_map</code> return nothing &mdash; and expect the partition check to fail rather than the total to fall silently, because matched plus differing must still equal audited.)</em></li>
                    <li><strong>Write a positive control for a checker you already have.</strong> Take any validation script you wrote for a compiler, a linker, a protocol or a parser, and build a file that must be rejected. <em>(Expect the checker to pass on the control immediately, which means it was already right, and expect the experience of the linter's 9,255 hollow zeroes to make you doubt it: how would you know? The answer is a file built to be caught, and a second one built to be passed, and both must be in the repository next to the checker.)</em></li>
                    <li><strong>Add a violation to the linter's corpus and see whether it is one.</strong> Write an assembly function that clobbers <code>%r12</code> without saving it, put it in <code>control.s</code>, and run. <em>(Expect the flag, the function count to rise by one, and the census row for <code>r12</code> to rise by one. Then write the same function as a leaf and note that the flag is the same while the <em>legality</em> is different &mdash; the checker's verdict is about the code in front of it and the exemption is about the code it cannot see.)</em></li>
                    <li><strong>Audit something that is not x86-64.</strong> Take the method, not the rules: choose a specification, transcribe it into a checker, build a corpus where the thing under test cannot be optimised away, and compare. <em>(Expect the interesting part to be entirely in the corpus and the specification &mdash; the two things a course about an ABI teaches that generalise to any interface between two programs. Expect also to hit the limit this course hit: an interface with no independent account of what the output should be cannot be audited the way a register assignment can, and knowing which kind you are holding is the transferable skill.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept consumes all five. The <a href="/courses/x86abi/lessons/x86-calling">calling convention</a> supplied the oracle. The <a href="/courses/x86abi/lessons/x86-frame">stack frame</a> and <a href="/courses/x86abi/lessons/x86-saved">the saved registers</a> supplied the fault experiments and the census the linter reports. The <a href="/courses/x86abi/lessons/x86-varargs">varargs concept</a> supplied the retraction that a self-describing convention is not a checked one. The <a href="/courses/x86abi/lessons/x86-unwind">unwinding concept</a> supplied the limit &mdash; the part of the ABI that cannot be audited this way, and the reason being able to say which part cannot is part of the result.</p>
                <p>Outward, the harness is the seventh instance of a pattern this collection has now established seven times, and the two nearest precedents are the most instructive. <a href="/courses/mem/lessons/mem-verify">The memory course's verification concept</a> is where a check whose threshold came from the recorded run was shown to fail on two other recorded runs of the same experiment on the same machine, and the fix was to assert the shape and not the value. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness concept</a> is where a row was found below its own control and the subtraction that produced a negative cost was retracted rather than kept. Both are the same lesson this course's R6 is about from the other end: a checker that cannot account for a mismatch is not evidence of a mismatch.</p>
                <p>And forward, into the rest of the section. The fourth course in this series is about the machine's privileged side, where the <code>syscall</code> instruction this course measured as a curiosity is the only door in, and where the argument registers are the same six minus one. And the <a href="/courses/x86asm/lessons/x86-asm">assembly course that precedes this one in the section</a> taught the reading this concept depends on: there is no way to recover an argument assignment from a disassembly without knowing that the destination is the operand on the left.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi/lessons/x86-unwind">Unwinding, and the Second Language</a></span>
                <span>End of The x86-64 ABI &middot; <a href="/courses/x86abi">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
