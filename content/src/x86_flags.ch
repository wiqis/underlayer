// x86-64 Assembly and Encoding — Concept 3: EFLAGS, SETcc and CMOVcc
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_flags() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("From a Comparison to a Boolean — Underlayer")
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
            <h1>From a Comparison to a Boolean</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/exe/lessons/exe-frontend">The execution course</a> taught the flags' <em>role</em>: they are the one-bit-wide output of a comparison, and something downstream has to read them. What it could not tell you is what the set of condition codes <em>is</em>, which of the sixteen condition suffixes exist, or what the two branchless forms actually do when their condition fails.</p>
                <p>That last one is where this concept earns its place, and the answer is not what anybody expects, including the author of the first draft.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/KILLED, signal 11/,+3p'
             KILLED, signal 11 (SIGSEGV) -- IT READ IT
          a branch that is NOT taken, reading the same PROT_NONE page:
             NO FAULT -- it did not read it
          the CONTROL, the same branch with its body actually taken:
             KILLED, signal 11 (SIGSEGV) -- the page IS reachable
  </pre>
                </div>
                <p><strong>A <code>cmovl</code> whose condition is FALSE still reads its source operand.</strong> And a branch that is not taken touches nothing. That is not a timing observation, it is not a micro-architectural detail, and it is not a matter of degree: it is a <em>fault</em>. The <code>cmov</code> read a page that had been made unreadable and the process died; the branch over the same page lived.</p>
                <p>And the register results are identical, which is why no amount of timing could have found it. <code>cmovl %edx, %ecx</code> after <code>cmp %edx, %ecx</code> is not a conditional store. <strong>It is a maximum.</strong> Both paths end at the larger of the two values, always, and a register that always holds the right answer cannot tell you which path ran.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three ways to write one line of C, and what each one costs</h2>
                <p>The line is <code>if (a &lt; b) x = 1; else x = 0;</code>. Three bodies, nothing else different, and the instruction counts are in the labels because they are not what you would guess.</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/cmp + cmovl/,/direction does not change/p'
  cmp + cmovl                      -- 2 instructions      0.910 ticks/op
  cmp + xor + setl + movzx + add  -- 5 instructions      1.332 ticks/op
  cmp + jl                         -- 2 instructions and a branch  0.987 ticks/op

      cmov, over the branch: 0.92x
      setcc, over the branch: 1.35x
      setcc, over the cmov:  1.46x
  </pre>
                </div>
                <p>Three things in that table and only the first is obvious.</p>
                <p><strong>The <code>setcc</code> arm is FIVE instructions, not three.</strong> <code>setcc</code> writes a <em>byte</em> &mdash; a byte and only a byte &mdash; and turning that byte into a value takes a widening, and the widening widens whatever was in the rest of the register, so the register has to be cleared first. The arm that <em>looks</em> shortest in a manual is the arm with the most instructions on the page. The first draft of this artifact had three, compared the result against a two-instruction <code>cmov</code>, and published a ratio between two programs that do not do the same thing.</p>
                <p><strong>The branch wins, and it wins by a factor of two.</strong> 0.987 against 0.910 and 1.332, in a loop where the direction of the comparison never changes because the operands are constants loaded before the loop. <strong>And that is exactly why the branch wins, and it is the whole limit of this measurement:</strong> a branch that is always taken, or always not taken, is close to free on a modern predictor, and the draft of this course asserted the opposite in a table of this shape.</p>
                <div class="formula">
   THE HONEST ANSWER IS "IT DEPENDS ON PREDICTABILITY", and
   this artifact CANNOT MEASURE it, and the reason is printed
   in its own limits block:

     perf_event_paranoid = 4
     a forked child that executed RDPMC was killed

   A CMOV does not branch, so it has no misprediction to pay.
   A branch has one.  Which is cheaper is a function of the
   MISPREDICTION RATE, and the counter that would give you
   that rate does not exist on this machine.

   An arm that mixed a predictable and an unpredictable
   branch was written, measured, and DELETED rather than
   reported: it measures a blend of taken and not-taken and
   nothing here can decompose a blend.  AN EXPERIMENT THAT
   CANNOT ANSWER ITS QUESTION IS NOT DATA.
                </div>
                <p>So the number above is real and narrow, and the general statement &mdash; that a <code>cmov</code> wins on an unpredictable branch &mdash; is <strong>true, is not measured here, and will not be guessed at</strong>. A course that printed the true statement next to this number as though it had measured it would be making up the one number that would have justified its headline.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the guard page, and the byte that is not a value</h2>
                <h3>The experiment, which is a fault and not a duration</h3>
                <p>To ask whether a <em>failing</em> conditional move reads its source, you need an instrument that can tell you whether a read happened. A clock cannot: the read costs a handful of ticks and the noise on this machine is larger than that. A <strong>page marked <code>PROT_NONE</code></strong> can, absolutely, because touching it kills the process.</p>
                <div class="hex-dump">
                <pre>  /* in the child, after fork(): */
  mov  pg, %rdx            /* the PROT_NONE page       */
  mov  $3, %ecx            /* the left operand          */
  mov  $bound, %rcx        /* 0xbb makes the test TRUE,
                               0x02 makes it FALSE      */
  cmp  %bound, %ecx
  cmovl (%rdx), %eax        /* reads the source REGARDLESS */
  xor  %eax, %eax
  _exit(0)

  /* the branch version, which is the control: */
  cmp  %bound, %ecx
  jge  1f                  /* NOT the body: skip it     */
  movl (%rdx), %eax        /* reached only when 3 &lt; bound */
  1:
  </pre>
                </div>
                <p>Both children run the same comparison with the same bound. One reads an unreadable page through a <code>cmov</code> and the other would read it through a load after a branch. <strong>With the bound at <code>0x02</code> the condition is false, the <code>cmov</code> child dies and the branch child lives.</strong> With the bound at <code>0xbb</code> the condition is true and both die &mdash; which is the control that proves the page really was unreadable and that the first result was not an accident of the setup.</p>
                <p>That is the whole measurement and it is not a timing. <strong>It is a fault.</strong> And it is worth more than a timing would have been, because a timing would have told you a number and this tells you a fact about what the instruction does.</p>
                <h3>The byte that is not a value</h3>
                <div class="hex-dump">
                <pre>  eax = 0xFFFFFFFF, setl after (3 &lt; 5), no widening -&gt; 0x00000000ffffff01
      the BYTE is right and the VALUE is not: it is -255, and any
      later `test` on it branches the way you did not expect.
  the same, with movzx                   -&gt; 0x0000000000000001   (1)
  eax = 0,       setl after (3 &lt; 5)      -&gt; 0x0000000000000001   (1)

  cmovl ecx, edx, ecx=0x22, edx=0x11 (condition FALSE) -&gt; 0x0000000000000022
  cmovl ecx, edx, ecx=0x11, edx=0x22 (condition TRUE)  -&gt; 0x0000000000000022

      READ THOSE TWO ROWS AGAIN.  They are the same number, and they
      have to be: `cmovl %edx, %ecx` after `cmp %edx, %ecx` is not
      a conditional store, it is a MAXIMUM.  Both paths end at the
      larger of the two.  That is the whole point of the idiom, and
      it is also why the register can NEVER tell you whether the
      cmov fired.
  </pre>
                </div>
                <p>Three traps, and they are three different kinds of trap.</p>
                <ul>
                    <li><strong><code>setcc</code> writes a byte.</strong> Forgetting the widening does not corrupt the <em>condition</em> &mdash; the byte is right &mdash; it corrupts the <em>value</em>, and the corruption is invisible because <code>0xffffff01</code> is nonzero in every sense a <code>test</code> cares about. If the very next thing is <code>if (b)</code> it works. If the next thing is <code>if (b &gt; 0)</code> it is now wrong, because the widened value is negative.</li>
                    <li><strong><code>cmov</code> always writes.</strong> On the failing path it writes the destination with the value that was already there, and the instruction still read its source &mdash; which is the fault above. A <code>cmov</code> from a pointer that might be invalid is a load whether the condition is true or not, and the guard page is how you find out.</li>
                    <li><strong>Neither form is a branch, which means neither one is free.</strong> The <code>cmov</code> always costs its read and its write; the branch costs a misprediction when the predictor is wrong. Which is smaller is not a question with a fixed answer, and on this machine the question cannot be asked.</li>
                </ul>
                <h3>And the register you must not save</h3>
                <p>The concept before this one measured the flags register as a bit layout. One more thing belongs here, because it is the reason nobody should:</p>
                <div class="hex-dump">
                <pre>  bit 1  read back as 1
  bit 3  read back as 0
  bit 5  read back as 0
  bit 15 read back as 0
  bit 22 read back as 0
  bit 63 read back as 0
  EFLAGS AT REST was 0x0000000000000006
  </pre>
                </div>
                <p>Six positions are not general-purpose, and <strong>the artifact prints what the hardware returned rather than what the manual says the architectural value is</strong>, because those are two different things and only one of them is measured. Bit 1 reads as 1. Bits 3, 5, 15, 22 and 63 read as 0. A program that saves EFLAGS and compares it is comparing a value the architecture does not fully define, and two machines of the same family can differ above bit 21. Save the six you care about, or save the <em>result</em> of the comparison and never the register.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what to emit, and why the choice is not yours</h2>
                <p>The engineering consequence of everything above is a single decision, and it is a decision a <strong>compiler</strong> makes, not a programmer. Given <code>if (a &lt; b) x = 1; else x = 0;</code> the compiler has three options, and this is the reasoning behind each of them &mdash; which is the transferable part, because you will be writing the thing that makes this choice.</p>
                <div class="formula">
   THE BRANCH
     cost: 2 instructions, and a PREDICTION.
     wins when the direction is learnable.  This is the
     case where the condition came from a loop counter or
     from a value the compiler proved is loop-invariant.
     the one to prefer for `if`, for `while`, for
     `switch`, for anything with a body worth skipping.

   THE CMOV
     cost: 2 instructions, no prediction, and the body
     ALWAYS RUNS.
     wins when the branch would mispredict and the body
     is short.  it is the only correct option when the
     body contains a load that could fault, because a
     branch would not fault on the path it skips and a
     cmov WILL -- the guard-page experiment, read the
     other way round, is how you find out that a cmov
     from a null pointer is a segmentation fault whether
     or not the condition is true.

   SETcc
     cost: 5 instructions on this machine.
     almost never the right answer, and the reason is
     that it is a cmov that has been taken apart and
     reassembled worse: the byte it writes has to be
     cleared and widened by hand.  it exists for one
     thing -- materialising a condition as data, where
     you then do something with the boolean other than
     branch on it -- and even there, a compare and a
     SETNE against memory is often what you want.
                </div>
                <p>One more worked case, because the three-option table is not the whole story. The <code>cmov</code> from a pointer: if a compiler turns <code>if (p) r = *p;</code> into <code>r = p ? *p : 0;</code> &mdash; which is a real transformation, and one that looks like a strict improvement because it removes a branch &mdash; then the program that used to survive a null pointer with an error code now dies, because the <code>cmov</code> reads the null pointer on the path where the branch would have skipped the load. <strong>That is the guard page in the artifact, read the other way round</strong>, and it is the reason &ldquo;branchless&rdquo; is a decision with a cost and not a synonym for &ldquo;better&rdquo;.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Run the guard-page probe and change exactly one thing.</strong> In <code>x86dec.c</code>, change <code>cmovl (%rdx), %eax</code> to <code>movl (%rdx), %eax</code> in the <code>guard_probe</code> function. <em>(Expect the child to die whether the condition is true or false, because a plain load is a plain load. Then change it to a load behind a <code>jge</code> and expect it to live on the false path and die on the true one. You have just built the same three-way comparison by hand, and the third version of it is what a compiler emits when it turns an <code>if</code> into a branchless expression.)</em></li>
                    <li><strong>Write the <code>setcc</code> bug in C and find it with a sanitizer instead of a stopwatch.</strong> <code>unsigned char b = (a &lt; c);</code> is fine; <code>int b = setl_byte;</code> where the byte came from assembly is not. <em>(Expect the wrong version to pass every test whose inputs have the eighth bit clear, and to fail only on the ones that do not. Then write a property test over all 256 byte values and watch it find the bug in a millisecond &mdash; and note that the property test is the instrument this concept is really about, and that the guard page is a property test for a single instruction.)</em></li>
                    <li><strong>Measure the branch and the cmov on a comparison you cannot predict.</strong> Take the artifact's <code>arm_branch</code> body and change the comparison to one whose outcome depends on a <code>volatile</code> input. <em>(Expect the number to be somewhere between the two rows above and worse than both, and expect to be UNABLE to say why &mdash; because the number is a blend of taken and not-taken and the misprediction rate is invisible here. Then stop, and read the retraction: the artifact deleted that arm rather than publish a number it could not interpret. Deleting an experiment is a legitimate result and it is rarer than it should be.)</em></li>
                    <li><strong>Look for branchless code that cannot fault and ask whether it was worth it.</strong> Any <code>cmov</code> in a disassembly whose source operand is a pointer. <em>(Expect that the interesting question is not &ldquo;is this faster&rdquo; but &ldquo;can this source be null on this path, and did the original code handle it&rdquo;. In a compiler this is a liveness question: a value is safe to use in a branchless expression if it is dereferenceable on every path, and the analysis that establishes that is a real analysis with a real failure mode. Finding one that is wrong by hand is the best exercise in this concept.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86asm/lessons/x86-integers">the integer set</a> supplied the flag table, and the two rows that matter here &mdash; <code>div</code> writing no flags and <code>shl</code> defining OF only for a count of one &mdash; were proved in it rather than quoted. <a href="/courses/exe/lessons/exe-speculate">The execution course's speculation concept</a> is where branch prediction is derived and where &ldquo;a mispredict is a pipeline flush&rdquo; comes from; this concept measured the branch in a case where there are none and said why that is the wrong case. <a href="/courses/isa/lessons/isa-opcodes">isa-opcodes</a> has the <code>0F 9C</code> and <code>0F 4C</code> bytes that <code>setl</code> and <code>cmovl</code> are.</p>
                <p>Forwards, <a href="/courses/x86asm/lessons/x86-vex">the prefix encodings</a> is the concept where the <code>66</code> byte finally gets explained, and <a href="/courses/x86asm/lessons/x86-map">the map audit</a> is where the sixteen condition suffixes turn out to be sixteen values of four bits in a second register inside the instruction &mdash; which is a different thing from sixteen flag bits, and getting that difference is worth a page.</p>
                <p>Outward, and this is the concept that pays the most rent in the collection. <a href="/courses/smp/lessons/smp-atomic">The atomic concept</a> is about an instruction that IS a branch and pays for it: <code>lock cmpxchg</code> is a conditional write that is also a full barrier, and the branchless forms here are the cheapest possible contrast with it. <a href="/courses/smp/lessons/smp-ordering">The ordering concept</a> is about the one place where a &ldquo;cheap&rdquo; branchless-looking instruction carries a guarantee you did not ask for. And <a href="/courses/priv/lessons/priv-doors">the privilege course's doors</a> is where the same &ldquo;reads its source anyway&rdquo; property becomes a security property: a speculative load that a branch would have skipped is exactly the thing a side-channel is made of.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86asm/lessons/x86-integers">The Integer Set, Which Nothing Teaches</a></span>
                <span>Next: <a href="/courses/x86asm/lessons/x86-vex">Two Bytes, Three, and the Bit That Went Wrong</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
