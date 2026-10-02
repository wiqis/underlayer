// The x86-64 ABI — Concept 3: callee-saved and caller-saved
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_saved() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Callee-Saved and Caller-Saved, by Experiment — Underlayer")
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
            <h1>Callee-Saved and Caller-Saved, by Experiment</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/x86abi">The x86-64 ABI</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Sixteen general registers, and a rule that splits them nine and six with one left over. The rule exists for a reason that follows directly from the previous concept: <strong>a caller cannot keep anything live in a caller-saved register across a call</strong>, because the callee is entitled to overwrite it. So anything the caller wants to keep has to live somewhere that survives, and on x86-64 the places that survive are six registers and the stack.</p>
                <p>That is the whole reason the set is the size it is. It is not a design preference. It is the arithmetic of a machine with 16 registers where six are already spoken for by arguments and one more by the return value, leaving exactly the nine that the split describes.</p>
                <p>But &ldquo;the six callee-saved registers are <code>rbx</code>, <code>rbp</code>, <code>r12</code>&ndash;<code>r15</code>&rdquo; is a sentence most people have read and none have checked, and the checking is worth doing, because <strong>the table is not the claim.</strong> The claim is a behaviour: put a value in <code>%r12</code>, call something, and see whether it is still there. That is a five-line experiment, and the next section runs it.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the rule, and why a leaf gets an exemption</h2>
                <p>Here is the whole convention, and it is a rule about <em>who pays</em>:</p>
                <div class="formula">
   CALLEE-SAVED:  rbx  rbp  r12  r13  r14  r15
   CALLER-SAVED:  rax  rcx  rdx  rsi  rdi  r8  r9  r10  r11
   NOT IN THE TABLE AT ALL:  rsp, and rip

   A callee may write any caller-saved register freely and
   must write nothing back.  A callee that writes a
   callee-saved register must save the CALLER's value first
   and put it back before returning:

        pushq %rbx
        movabsq $0x9999999999999999, %rbx
        addq %rbx, %rdi
        popq %rbx

   Six bytes.  That is the entire rule.
                </div>
                <p>Two things in that table are worth stopping on, and neither is usually mentioned.</p>
                <p><strong><code>%rsp</code> is not callee-saved.</strong> It is not in the table because it is not a register the convention allocates: it is the one register whose value is the ABI's own state, and a function that changed it without changing it back would not return. So the nine-and-six split is not &ldquo;the sixteen registers, less one&rdquo;; it is fifteen registers, and the split is nine caller-saved and six callee-saved. That is why the arithmetic in the previous section comes out at nine.</p>
                <p><strong><code>%rbp</code> is a callee-saved general register and nothing else.</strong> There is no frame descriptor on this architecture, and <code>push %rbp; mov %rsp,%rbp</code> is a compiler convention. The direct evidence is that <code>gcc -O2</code> uses <code>%rbp</code> as ordinary scratch, and the corpus this course audits shows it doing exactly that: <code>mx</code> at <code>-O2</code> <code>push</code>es <code>%rbp</code> and then moves <code>%rcx</code> into it &mdash; the third of its four integer arguments &mdash; because <code>%rbp</code> is callee-saved and the value in it belongs to the caller.</p>
                <p>And <strong>the leaf exemption is the interesting part, because it is not in most tables.</strong> A leaf function may clobber a callee-saved register without saving it, <em>provided the compiler knows no caller had a live value there.</em> That is a fact about the callers, not about the function, and it is why a mechanical checker cannot settle the question &mdash; which is the subject of the last section.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the same register, two callees</h2>
                <p>Two callees. The first tramples every callee-saved register it is allowed to and touches nothing else. The second tramples all nine caller-saved registers, uses <code>%rbx</code>, and saves it. The caller puts a distinct marker in <code>%r12</code>, calls, and reads <code>%r12</code> back:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/CALLEE-SAVED, BY EXPERIMENT/,/^6B\./p'
  ARM 1  a callee that tramples rbx r12 r13 r14 r15 and nothing
         else.  The caller put 0x0202020202020202 in %r12.
         the caller's %r12 after the call = 0x2222222222222222   CLOBBERED
         and the callee put 0x2222222222222222 there instead.
  ARM 2  a CONFORMING callee that tramples all nine caller-saved
         registers and uses %rbx.  The caller put 0x0b0b0b0b0b0b0b
         in %r12; after the call %r12 = 0x0b0b0b0b0b0b0b   SURVIVED
  ARM 3  a conforming callee that USES %rbx: pushq, movq, addq, popq
         0x100 + 0x9999999999999999 = 0x9999999999999a99   EXACT
  ARM 4  the same for %r12                             = 0x9999999999999a99   EXACT
  ARM 5  THE DIRECTION FLAG.  %rflags inside a conforming callee
         0x0000000000000000, and bit 10 (DF) = 0
         %rflags left behind by a NON-conforming callee
         0x0000000000000646, and bit 10 (DF) = 1
         The ABI makes DF the CALLER's problem: it must be 0 on
         entry and on exit to any function.  Which is why this
         file CLEARS it again on the very next line.
         DF after the `cld`                0x0000000000000246, bit 10 = 0
  ARM 6  %rbp, the sixth callee-saved register, which is a special
         case: a caller built with a frame pointer ends in `leave`,
         which is `movq %rbp,%rsp; popq %rbp`.
         a callee that clobbered %rbp     -> KILLED by a signal 7  (7 is SIGBUS)
         a conforming callee              -> returned normally
  </pre>
                </div>
                <p>That is the table, established by behaviour. ARM 1 and ARM 2 are the same register, the same caller and the same call instruction, and the only difference is whether the callee pushed.</p>
                <h3>Arm 5 is a different rule, in the opposite direction</h3>
                <p>The direction flag is not a register and its rule is not the register rule. The ABI requires <code>DF</code> to be <strong>0</strong> on entry to and on exit from any function &mdash; and that is a rule the <em>caller</em> keeps, not the callee. A conforming callee clears it on the way out (ARM 5, first line: bit 10 is 0 inside it). A non-conforming one need not, and then the caller finds bit 10 set in its own <code>%rflags</code>, which is what the second line shows. A string instruction in the middle of the caller's loop will then walk backwards through memory instead of forwards, and nothing will say so.</p>
                <p><strong>And this course learned that the hard way, which is why the artifact clears it on the line after measuring it.</strong> The first version of <code>abidump</code> called the non-conforming callee, read the flag, printed the number, and moved on. Then the artifact hung. Not crashed &mdash; <em>hung</em>: twenty-five minutes of user time, no signal, no diagnostic, no output, in a program whose every other failure mode in this file is loud. The non-conforming callee had set <code>DF</code> in the artifact's own process, and with <code>DF</code> set every <code>rep</code>-based string routine in the C library scans <strong>backwards</strong>. The first <code>strstr</code> the artifact made after that point never returned. The whole run now takes 1.4 seconds instead of timing out, and the difference between those two facts is one <code>cld</code> and the awareness that <strong>the caller in ARM 5 was this program</strong>.</p>
                <p>Notice what makes it a nasty bug rather than an interesting one: there is no compiler diagnostic for a callee that leaves <code>DF</code> set, because <code>DF</code> is not in any register and there is no callee-saved slot it could have been preserved in. The ABI's remedy is a sentence in a document. And a hang is the <em>worst</em> possible symptom, because a program that stops with no output looks like a slow machine, not like a broken contract.</p>
                <h3>Arm 6 is why <code>%rbp</code> is worth its own sentence</h3>
                <p>Clobbering <code>%rbx</code> loses a value. Clobbering <code>%rbp</code> kills the caller, because a caller built with a frame pointer ends in <code>leave</code>, which is <code>movq %rbp,%rsp; popq %rbp</code> &mdash; so a corrupted <code>%rbp</code> both restores the stack pointer to nonsense and returns to the word at that nonsense address. The measurement is a signal: <strong>SIGBUS</strong>, which is what a stack access that runs off the end of the mapping gives you, with the conforming callee as the control that returns normally. Note that the caller's side of this arm has to be written in assembly, because <code>gcc</code> refuses to let an inline <code>asm</code> block name <code>%rbp</code> at all.</p>
                <h3>And the two floating-point control registers point the other way</h3>
                <p>The one place the direction reverses, and it is worth a table of its own because nothing else in the ABI does this:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/6B\./,/^  Note the field/p'
6B. WHERE THE DIRECTION IS REVERSED, AND IT IS MEASURED.

      MXCSR before the call   0x00001fa0  rounding control 0
      MXCSR after  the call   0x00006000  rounding control 3
      MXCSR after  a clean one 0x00006000  rounding control 3
      x87 control word before 0x037f  PC 63, RC 0
      x87 control word after  0x0250  PC 16, RC 0

      MXCSR after the CALLER restored it  0x00001fa0  rounding control 0
  </pre>
                </div>
                <p>A callee changed the rounding mode from <em>nearest</em> to <em>toward zero</em> and the precision control from <em>extended</em> to <em>double</em>, and put neither back. <strong>MXCSR's control bits are caller-saved: a callee may change them freely.</strong> The x87 control word goes the other way and is callee-saved, and here the same callee changed it without restoring it either &mdash; the artifact's callee is deliberately non-conforming on both, so the two rows are a controlled comparison rather than two accidents.</p>
                <p>The consequence is the reason this is on a page about a contract. A function that rounds differently from its caller and does not say so is <strong>a wrong answer, not a slow one</strong>, and there is no diagnostic: the arithmetic is perfectly well-defined, just not the arithmetic you asked for. And the cost of the reversal is asymmetric. The compiler pays almost nothing to honour it, because it is three instructions in the prologue. The programmer pays when a function nobody wrote changes the mode and the next value is compared against a tolerance instead of being expected to be exact.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: an ABI linter, and the zero that was hollow</h2>
                <p>A convention is a contract between two compilers, so a contract between two compilers is the one kind of thing you can check mechanically. The artifact ships a checker that reads a real object file and asks, for every function: <em>does this write a callee-saved register without pushing it first?</em></p>
                <p>Run over glibc &mdash; the <strong>static</strong> library, because the check needs each function's extent and a stripped shared library has no symbol sizes:</p>
                <div class="hex-dump">
                <pre>$ ./abidump | sed -n '/^  LIBRARY |/,/^  UNMODELLED/p'
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
  CLAPPERBOTH | 3 | 151 unclassified after both exemptions
  </pre>
                </div>
                <p>Read the <strong>census</strong> column first, because it is the one that makes the flags column mean anything. 1,670 functions <em>write</em> <code>%rbx</code>; 1,598 of them save it first. The checker looked at 1,670 real cases and is silent on 1,598 of them, which is a very different sentence from &ldquo;the checker found nothing.&rdquo;</p>
                <p>Read the <strong>kind</strong> column next, because it is where the interesting result is. 271 flags across 94 functions, and 26 of them are in <em>leaves</em> &mdash; the exemption from the previous section, 26 real instances of it in a real library. And 97 of the 271 are in functions whose entire contract is to install a previously saved register context: <code>longjmp</code>, <code>backtrace</code>, <code>swapcontext</code>. Those functions are <em>required</em> to destroy the callee-saved registers, because restoring a context means writing them. A mechanical rule cannot know that.</p>
                <p><strong>And the two exemptions overlap, which is the arithmetic lesson hiding inside the table.</strong> A function can be a leaf <em>and</em> a context restorer &mdash; <code>setjmp</code> and its relatives are exactly that &mdash; so subtracting one count from the other is only valid if they are disjoint, and nothing in the ABI says they are. Three of the 271 are in both, so the remainder is 151 and not the 148 this page originally printed. The first draft subtracted anyway, got a plausible number, and was wrong by three out of 271 in a way no reader could have seen. The linter now reports the overlap as its own row, and the artifact's tenth retraction is about the arithmetic rather than about the code.</p>
                <div class="formula">
   WHAT THE FLAGS ARE, AND WHAT THEY ARE NOT

   271 register uses in 94 functions, and:
     26  in leaf functions, which may do it if the compiler
         knows no caller had a live value there -- a fact
         about the CALLERS, not about this function
     97  in functions whose contract is to restore a saved
         context, which must do it
      3  in BOTH, because setjmp and its relatives are
         leaves as well as context restorers

   271 - 26 - 97 = 148, and 148 is WRONG, because the two
   exemptions were counted independently and 3 functions
   are in both.  The true remainder is 151.

   Those 151 are unclassified by a rule that cannot see
   intent, and a reader who reports them as bugs is
   reporting the rule, not the library.
                </div>
                <h3>And the first version of this linter reported nothing at all</h3>
                <p>This is the part worth keeping, and it is the reason the course ships a control file. The first version of <code>abilint.py</code> ran over libc, libm, the dynamic loader, libcrypto and <code>/bin/ls</code> &mdash; <strong>9,255 functions</strong> &mdash; and reported <strong>zero violations in every one of them.</strong> Every one of those zeroes was hollow. The function that normalises a register name had its ternary the wrong way round:</p>
                <div class="formula">
   THE BUG, IN ONE EXPRESSION

   return ("e" if m.group(1) == "r" else "r") + m.group(2)

   For the operand "r12" that returns "e12".  Nothing was
   ever recognised as a callee-saved register, so the clobber
   check compared nothing against anything, and reported
   nothing found.  9,255 functions, zero findings, and the
   zero was a fact about the CHECKER and not about glibc.

   THE FIX WAS NOT TO BE CAREFUL.  It was to build
   control.s, a file whose every function is a violation on
   purpose, and require the linter to flag all of them AND
   NOT to flag the two conforming ones.
                </div>
                <p>The control is in the artifact's own output, and it is the number that makes the rest of the section checkable:</p>
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
                <p>Three flags, all three intended, and the two conforming functions absent. <strong>A checker that examines nothing and a checker that finds nothing print the same line</strong>, and only a positive control tells them apart. That is the seventh time in this collection that the same lesson has cost something, and it is now a standing part of every harness in it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Break the control and watch the checker find it.</strong> Delete the <code>pushq %rbx</code> / <code>popq %rbx</code> pair from <code>ct_ok_leaf</code> in <code>control.s</code> and re-run. <em>(Expect group H2 of the harness to fail on the check that names <code>ct_ok_leaf</code> specifically, and the libc flags to go up by one. That is the completion criterion for the course, and it takes one line to do.)</em></li>
                    <li><strong>Add a leaf clobber to your own assembly and see whether it works.</strong> Write a leaf that uses <code>%r12</code> without saving it, link it, call it from C. <em>(Expect it to work, every time, and that is the correct result and the wrong thing to rely on. It works because the compiler can see your C caller and knows it has nothing live in <code>%r12</code> across the call. Change the caller &mdash; put a loop counter in <code>%r12</code> by hand in inline asm, or call the leaf from a function that keeps something there &mdash; and expect a wrong answer rather than a crash, because the symptom of a clobbered callee-saved register is somebody else's value.)</em></li>
                    <li><strong>Set the direction flag in a callee and watch the caller.</strong> <em>(Expect the ARM 5 result: bit 10 clear inside a conforming callee, set after a non-conforming one. Then write a loop that copies a string forwards with <code>rep movsb</code>, call the dirty callee, and confirm the copy runs backwards. Nothing faults. Nothing warns. The array is simply written in the other order, and the failure is a data-corruption bug that looks like a logic bug.)</em></li>
                    <li><strong>Change the rounding mode in a callee.</strong> Use the artifact's <code>abi_fp_dirty</code> as a model, or write <code>ldmxcsr</code> yourself. <em>(Expect the caller's arithmetic to round toward zero afterwards, and expect the caller to be able to fix it in one instruction &mdash; which is the point. <code>MXCSR</code>'s control bits are caller-saved precisely so that a function doing heavy floating-point work can set the mode once instead of restoring it on every return. The cost is that every <em>other</em> function doing floating-point work has to save it too, and the convention says so in a table most people have never read.)</em></li>
                    <li><strong>Run the linter over your own project's assembly, and then over its compiler output.</strong> <em>(Expect the two to come out differently, and expect the difference to be the leaf exemption: a compiler that knows its callers will use registers freely in leaves, and a hand-written function that cannot know anything will save everything. Both are legal. A project with a <code>callee-saved</code> register clobbered in a hand-written leaf that <em>is</em> called from somewhere with a live value is a bug, and the linter will not tell you so &mdash; which is why the last concept is about what a checker can and cannot establish.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86abi/lessons/x86-frame">the stack frame</a> is the argument this concept's whole first half rests on: a caller cannot keep a value in a caller-saved register across a call, and the red zone is not available to a function that calls anything, so the stack is what is left. <a href="/courses/smp/lessons/smp-sharing">The multiprocessor course's sharing concept</a> is where &ldquo;save it somewhere that survives&rdquo; stops being about registers and starts being about which memory is visible to which core, and the callee-saved convention is the register-level shadow of that problem.</p>
                <p>Forwards, one practical consequence. The linter in this concept is a <em>checker</em>, and a checker needs a spec to check against &mdash; which for x86-64 means the CFI that describes a frame to something that was not there when the frame was built. <a href="/courses/x86abi/lessons/x86-unwind">The unwinding concept</a> is about that second description, and it is where a frame pointer stops being a debugging convenience and becomes the only thing a profiler has when a function has no table.</p>
                <p>Outward, the security course owns a claim that is adjacent and different. <a href="/courses/sec/lessons/sec-canary">The stack-protector concept</a> is about protecting the return address, which this course has just established lives at <code>0(%rsp)</code> at a callee's first instruction &mdash; the same eight bytes as the first slot of the red zone. That is not a coincidence to exploit; it is a coincidence to <em>notice</em>, and it is the reason a canary sits between the saved frame pointer and the return address rather than in front of the locals. The two concepts are worth reading together precisely because the same address has two owners depending on whether a call happens.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86abi/lessons/x86-frame">The Stack Frame, the Red Zone, and Two Rules</a></span>
                <span>Next: <a href="/courses/x86abi/lessons/x86-varargs">The One Place the ABI Describes Itself</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
