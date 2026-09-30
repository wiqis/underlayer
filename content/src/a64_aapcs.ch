// The AArch64 Procedure Call Standard -- Concept 1: the calling convention,
// the argument audit, and the alignment number that was wrong by 8.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_aapcs() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Calling Convention, and the Number That Was 128 — Underlayer")
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
            <h1>The Calling Convention, and the Number That Was 128</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/a64abi">The AArch64 Procedure Call Standard</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>You already know how to read a disassembly. <a href="/courses/a64asm/lessons/a64-encoding">The encoding course</a> measured the field map; this page does not repeat a word of that. What it assumes you can do is look at a four-byte word and understand it. What it asks is the question that <em>nobody ever asks</em>, because there is no diagnostic for it:</p>
                <div class="formula">
   THE QUESTION

   Function A was compiled by one compiler.  Function B calls
   it, and B was compiled by another.  A and B agree about
   which register holds argument number four.

   If they disagree, NOTHING HAPPENS.  No diagnostic, no
   link error, no crash at the call site.  A reads the wrong
   register, gets a plausible number, and computes a
   plausible wrong answer.
                </div>
                <p>That is what a <strong>calling convention</strong> is: a contract that exists only so that a mistake in it is invisible. Every rule on this page is a rule about <em>where a value lives across a boundary nobody can see</em>.</p>
                <p>The AArch64 version of that contract is the <strong>AAPCS64</strong> &mdash; the <em>Procedure Call Standard for the Arm 64-bit Architecture</em>, published by Arm in the <code>ARM-software/abi-aa</code> repository. This course quotes release <strong>2025Q4</strong>, issued <strong>23 January 2026</strong>, and quotes it <em>by section number</em>, because "the standard says" without a section is a sentence a reader cannot check.</p>
                <p>And this concept was written to teach a number. <strong>That number was 128.</strong> It is 16, and finding out why is most of this page.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two counters, two banks, and a stack that starts at zero</h2>
                <p>The whole of the argument-assignment rule, for a simple case, is two sentences. Here they are, quoted:</p>
                <div class="hex-dump">
                <pre>AAPCS64  A.1   the Next General-purpose Register Number (NGRN)
              is set to zero
        A.2   the Next SIMD and Floating-point Register Number
              (NSRN) is set to zero
        A.4   the next stacked argument address (NSAA) is set
              to the current stack-pointer value (SP)

        C.9   If the argument is an Integral or Pointer Type,
              the size of the argument is less than or equal to
              8 bytes and the NGRN is less than 8, the argument
              is copied to the least significant bits in
              x[NGRN]. The NGRN is incremented by one.

        C.1   If the argument is an 8-bit, Half-, Single-,
              Double- or Quad-precision Floating-point or short
              vector type and the NSRN is less than 8, then the
              argument is allocated to the least significant
              bits of register v[NSRN]. The NSRN is
              incremented by one.
                </pre>
                </div>
                <p>Four things to notice, and all four are the whole idea.</p>
                <ul>
                    <li><strong>A.1 and A.2 are TWO counters.</strong> This is the sentence a reader has to see rather than be told. C.1 reads <code>NSRN</code> and C.9 reads <code>NGRN</code>, and <strong>neither sentence mentions the other</strong>. So integers and floating-point values do not queue up in one sequence &mdash; they queue in two, and each has eight places.</li>
                    <li><strong>C.9 is bounded by <em>size</em> as well as by the counter.</strong> "less than or equal to 8 bytes". A 16-byte value is not an integer argument, whatever the programmer wrote. That is the same boundary a64asm measured from the other side, where the <code>q</code> register is 16 bytes wide.</li>
                    <li><strong>A.4 says the first stacked argument is at SP itself.</strong> Not <code>SP + 8</code>. Not <code>SP + 16</code>. <strong>At the current stack-pointer value.</strong> The reason is on the next page in one sentence and it is the single biggest difference between this ABI and the one you already know.</li>
                    <li><strong>When a bank runs out, C.13 and C.16 take over</strong>: <code>C.13 The NGRN is set to 8</code> and <code>C.16 If the size of the argument is less than 8 bytes then the size of the argument is set to 8 bytes</code>. So a <code>char</code> on the stack occupies eight bytes. There is no packed-arguments concept on this ABI, and that is a decision rather than an accident.</li>
                </ul>
                <p>The result registers follow the same sentence the argument registers use, and the specification words it as a rule about arguments on purpose:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/THE RESULT, AND THE INDIRECT/,/^$/p'
  O0   r1     mul x0, x8, x9  add sp, sp, #16  ret
  O0   r1d    fmul d0, d0, d1  add sp, sp, #16  ret
  O2   r1     add x0, x0, x0, lsl #1  ret
  O2   r1d    fmul d0, d0, d1  ret
  O2   rbig    add v2.2d, v0.2d, v2.2d  add v0.2d, v0.2d, v3.2d  ret
                </pre>
                </div>
                <p>An integer result comes back in <code>x0</code> and a double in <code>d0</code> &mdash; <strong>the first argument register, not a dedicated one</strong>. The AAPCS64 puts them there with a sentence: the result is returned in the same registers as would be used for such an argument. There is no <code>rax</code>/<code>xmm0</code> split on this architecture because there is no separate integer and vector return convention to reconcile; the two banks already exist for arguments and the result joins the bank it came from.</p>
                <p>One exception, and it is the exception a backend must get right. <strong>A struct too large for a register comes back through memory the CALLER allocated</strong>, and the callee gets its address in <code>x8</code>:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | grep -B1 -A4 'Indirect Result'
  ... A struct too large for a register is different: the caller
  allocates the memory, the callee gets its ADDRESS in x8, and
  `use_big` at -O2 is `mov x8, sp` followed by `bl rbig`. x8 is
  the Indirect Result Location Register and it is the one argument
  register with a job that is not passing an argument.
                </pre>
                </div>
                <p><code>x8</code> is the <strong>Indirect Result Location Register</strong>. It is worth sitting with that: it is <em>inside the argument-register range</em> (0&ndash;7 are the ordinary ones, so <code>x8</code> is the first register past them) and it is the one whose job is not to pass an argument. A reader who assumes results always come back in <code>x0</code> will misread that prologue completely.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The audit: 36 of 36, by name, at four optimisation levels</h2>
                <p>A census would say &ldquo;eight registers were written before the call.&rdquo; An audit says <em>which argument was in which register</em>. The corpus makes that possible by giving every argument its own <code>volatile</code> global, so the disassembly literally names it &mdash; <code>#24</code> <em>is</em> argument three &mdash; and a volatile access cannot be deleted or moved, so the call survives optimisation.</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/4A\./,/4C\./p'
  4A.  NINE INTEGER ARGUMENTS.  caller `c9`, callee `i9`.
  level register args stacked, and where
  O0    0:x0  1:x1  2:x2  3:x3  4:x4  5:x5  6:x6  7:x7  8:sp+0
  O1    0:x0  1:x1  2:x2  3:x3  4:x4  5:x5  6:x6  7:x7  8:sp+0
  O2    0:x0  1:x1  2:x2  3:x3  4:x4  5:x5  6:x6  7:x7  8:sp+0
  Os    0:x0  1:x1  2:x2  3:x3  4:x4  5:x5  6:x6  7:x7  8:sp+0

  4B.  NINE DOUBLE ARGUMENTS.  caller `cd9`, callee `d9`.
  O0    0:d0  1:d1  2:d2  3:d3  4:d4  5:d5  6:d6  7:d7  8:stack@8
  O2    0:d0  1:d1  2:d2  3:d3  4:d4  5:d5  6:d6  7:d7  8:stack@8
                </pre>
                </div>
                <p>And the mixed case, which is where the two counters stop being an abstraction and become an observation:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/4C\./,/the specification that decides/p'
  O2   cm8  ints: 0-&gt;x0  1-&gt;x1  2-&gt;x2  3-&gt;x3
            fps : 0-&gt;d0  1-&gt;d1  2-&gt;d2  3-&gt;d3   stacked at: none
  O2   cm18 ints: 0-&gt;x0  1-&gt;x1  2-&gt;x2  3-&gt;x3  4-&gt;x4  5-&gt;x5  6-&gt;x6  7-&gt;x7
            fps : 0-&gt;d0  1-&gt;d1  2-&gt;d2  3-&gt;d3  4-&gt;d4  5-&gt;d5  6-&gt;d6  7-&gt;d7   stacked at: [0, 8]
                </pre>
                </div>
                <p>Read <code>cm8</code> first, because <strong>it cannot tell you the answer</strong>, and a corpus designed to prove a point that has no control is not a control. Four integers and four doubles, alternating: the integers went to <code>x0</code>&ndash;<code>x3</code> and the doubles to <code>d0</code>&ndash;<code>d3</code>, in source order, interleaved. Both hypotheses predict that: &ldquo;one sequence across both banks&rdquo; and &ldquo;two independent counters&rdquo; agree on every assignment when nothing overflows.</p>
                <p>So <code>cm18</code> exists, with nine of each so that <strong>both ninths overflow</strong>. And the result is the interesting one: <strong>the 9th integer is at <code>[sp + 0]</code> and the 9th double is at <code>[sp + 8]</code></strong> &mdash; the order they appear in the parameter list, laid down by C.17 processing the list left to right. The two sequences do not share a counter, so a mixed call can have arguments 8 and 9 in <em>different banks at the same stack offset range</em>, and it is the specification that decides which one goes first.</p>
                <p>And then the sentence that is the whole reason this page exists as a page of its own:</p>
                <div class="hex-dump">
                <pre>  [MEASURED]  The 9th argument is at [sp + 0] at the moment of the
  call, which is what A.4 says: "the next stacked argument
  address (NSAA) is set to the current stack-pointer value
  (SP)". There is no return address on the stack to skip
  -- x30 holds it -- so the first stacked argument is at
  offset ZERO and the AAPCS64 says so in one sentence
  instead of in a diagram.
                </pre>
                </div>
                <p><strong>That is a difference in <em>kind</em> from x86-64, not in degree.</strong> <a href="/courses/x86abi/lessons/x86-calling">On x86-64 the return address is pushed</a>, so the first stack argument is at <code>+8(%rsp)</code> and a reader learns the offset <em>and</em> the reason in one diagram. Here the reason is a register &mdash; <code>x30</code> &mdash; which is the subject of <a href="/courses/a64abi/lessons/a64-save">concept 4</a> &mdash; and so the offset is zero. It is also why <strong>every stack offset in this course is 8 lower than the x86-64 course printed</strong>, and a reader with both courses open should expect to subtract eight, repeatedly, for five pages.</p>
                <h3>And the number that was 128</h3>
                <p>Now the alignment rule, in the words of the document, in both the places it appears:</p>
                <div class="hex-dump">
                <pre>AAPCS64  5.2.2.1  Additionally, at any point at which memory is
          accessed via SP, the hardware requires that
          SP mod 16 = 0. The stack must be quad-word aligned.

        5.2.2.2  The stack must also conform to the following
          constraint at a public interface: SP mod 16 = 0.
          The stack must be quad-word aligned.
                </pre>
                </div>
                <p><strong>SIXTEEN. Not 128, not 64, not 8. Sixteen, in both places.</strong> The same rule appears in the SVE variant of the standard (<code>ARM_100986_0000_00</code>) in two more. A rule stated four times is a document telling you it matters four times.</p>
                <p>And the <em>reason</em> is in the encoding, where a64asm measured it and this course can quote it without re-measuring. <strong>The largest scale anywhere in the A64 load/store family is 16, and it is the scale of the 128-bit pair.</strong></p>
                <div class="hex-dump">
                <pre>  word                   scale      imm field  reach
  stp w0, w1, [sp]       x4         imm7 at 21:15 [-256, 252]
  stp d0, d1, [sp]       x8         imm7 at 21:15 [-512, 504]
  stp q0, q1, [sp]       x16        imm7 at 21:15 [-1024, 1008]
  str q0, [sp]           x16        imm12 at 21:10 0 .. 65520
  str d0, [sp]           x8         imm12 at 21:10 0 .. 32760
  stur q0, [sp]          x16        imm9 at 20:12 [-256, 255], BYTES
                </pre>
                </div>
                <p>Those are the assembler's own ranges, read back from the artifact's section 3, and the maximum is 16 and it is the <code>q</code> pair's. <strong>So a 16-byte-aligned SP satisfies every scaled form in the family without exception, and the ABI asks for exactly 16.</strong></p>
                <p>The plan for this course said the rule was 128 bytes and that the reason was NEON's <code>LDP q0, q1</code>. <strong>The reason is right and the number is wrong by a factor of eight, because the reason implies the number.</strong> A <code>stp q0, q1</code> needs 16 bytes of alignment and no more &mdash; which the assembler states in its own diagnostic, verbatim, when you ask for a misaligned one:</p>
                <div class="hex-dump">
                <pre>  stp q0, q1, [sp, #8]    REFUSED  -   index must be a multiple of 16
                                           in range [-1024, 1008].
                </pre>
                </div>
                <p>Where 128 comes from at all: it is the <strong>x86-64 red zone's size</strong>, and the reason the number appears in AArch64 discussions is the <strong>APPLE platform ABI's 128-byte red zone</strong> &mdash; a different quantity, about a different region of memory, belonging to a different ABI. And a course that used the red zone's number for the alignment rule would also have had to conclude that AArch64 <em>has</em> a red zone, which is the opposite of the truth and is the finding <a href="/courses/a64abi/lessons/a64-frame">concept 3</a> is built on. That conflation is retraction R3 and it is printed in full by the artifact.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the check, and the place a measurement is refused</h2>
                <p>The rule is <code>SP mod 16 = 0</code> at a public interface, and a <code>bl</code> <em>is</em> a public interface. So the check is: for every function, walk the SP deltas in order and test the running sum <strong>at every branch</strong>. That is <strong>strictly more</strong> than the specification asks for &mdash; a conditional branch inside a function is not a public interface and does not change SP &mdash; and a check that is stronger than the specification is worth more than one that matches it exactly, because it cannot be defeated by a case the specification does not mention.</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/lvl  function   SP deltas/,/rbig       -32 +32/p'
  lvl  function   SP deltas, in order            sum      mod 16   branches
  O0   i9         -80 +80                        0        0        no branch
  O0   m18        -144 +144                      0        0        no branch
  O0   rbig       -32 +32                        0        0        .LBB6_1@-32,.LBB6_2@-32,.LBB6_3@-32,.LBB6_1@-32
  O0   c9         -32 +32                        0        0        i9@-32
  O0   big_frame  -96 +96                        0        0        .LBB18_1@-96,.LBB18_2@-96,.LBB18_3@-96,...
  O0   many       -128 +128                      0        0        sink@-128,sink@-128,  ... (12 of them)
  O0   va         -320 +320                      0        0        .LBB24_1@-320,.LBB24_2@-320,...

  [MEASURED]  Every SP movement in the corpus at all four levels leaves
  SP a multiple of 16, and 0 of the 151 branches are made with SP not
  a multiple of 16.  That is an arithmetic identity over the immediates
  the compiler emitted, not a measurement of behaviour: nobody ran
  anything, and the sum is the check.
                </pre>
                </div>
                <p>Zero misaligned out of <strong>151</strong>. A fixed-width instruction stream has no length arithmetic to get wrong, so this really is arithmetic over emitted immediates and not a simulation &mdash; which is the one thing this course can offer that a machine would not improve on.</p>
                <p>One trap in that table, and it is the kind that produces a confidently wrong census. <strong>The deallocation is often fused into the last load</strong> &mdash; <code>ldr x0, [sp], #16</code> is one instruction that reads a value <em>and</em> gives the bytes back &mdash; so counting <code>add sp, sp, #N</code> alone undercounts the functions that deallocate that way. The first version of this table counted only the explicit form and reported nine functions with no deallocation at -O2, which was wrong for three of them. <a href="/courses/a64abi/lessons/a64-frame">Concept 3</a> is where all five forms are measured, because the same trap is also a frame-allocation trap.</p>
                <h3>The place a measurement is refused</h3>
                <p>The AAPCS64 says "the hardware <em>requires</em> that <code>SP mod 16 = 0</code>". It does not say "the hardware will <em>fault</em>". Those are different sentences, and on the platform this compiles for they have different answers.</p>
                <p>Whether a misaligned access through SP actually traps is decided by <code>SCTLR_ELx.A</code>, the alignment-check control bit, and a Linux EL0 process runs with that bit <strong>clear</strong>. So on Linux the requirement is a <strong>software contract that a compiler enforces</strong>, not a hardware trap. This course can measure the encoding of the instruction that reads the bit, and does:</p>
                <div class="hex-dump">
                <pre>  source                   word       what the second reader says
  mrs x0, sctlr_el1        0xd5381000  mrs x0, SCTLR_EL1
  msr sctlr_el1, x0        0xd5181000  msr SCTLR_EL1, x0

  [MEASURED-ON-BYTES]  The encoding of the instruction that reads the
  alignment-check bit is 0xd5381000.  The FAULT is not measured, is
  not claimed, and is named here as the boundary of this section
  rather than left for a reader to discover.
                </pre>
                </div>
                <p>Read that block twice, because <strong>a limit printed in the place a reader would have expected a number is worth three limits printed at the end.</strong> The x86-64 ABI course could deliver a real <code>SIGSEGV</code> for its alignment rule; this one cannot, and pretending otherwise would be the exact failure the whole collection exists to name. <a href="/courses/x86abi/lessons/x86-frame">The x86-64 frame concept</a> has the fault, if you want the contrast &mdash; and the contrast is the interesting part: <em>one ABI's rule is enforced by a bit, and the other ABI's rule is enforced by a compiler.</em></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Read the ninth argument off a disassembly yourself.</strong> Compile anything with nine integer parameters at <code>-O0</code> for <code>aarch64-linux-gnu</code> and find the call. <em>(Expect the first two <code>str</code>s to write to <code>[sp, #0]</code> and <code>[sp, #8]</code>, with no return-address slot to skip &mdash; and expect the prologues to look odd next to the x86-64 ones you already know, because every offset is 8 lower.)</em></li>
                    <li><strong>Break the two-counter rule and see what the compiler does.</strong> Write a C function taking a <code>double</code> as argument <em>one</em> and an <code>int</code> as argument <em>two</em>, and check which register each arrives in. <em>(Expect <code>d0</code> and <code>x0</code> &mdash; NOT <code>d0</code> and <code>x1</code>. The counters are independent, so a floating-point first argument does not consume an integer slot. Now write the same function with a leading <code>char</code> and check whether the double still lands in <code>d0</code>: it does, and the <code>char</code> consumes <em>no</em> integer slot either when it is passed in a register under AAPCS64's rules &mdash; which is where a reader should stop and read C.1 and C.9 again.)</em></li>
                    <li><strong>Ask the assembler the question this page answered, and compare the answer to the plan's.</strong> <em>(Expect <code>stp q0, q1, [sp, #8]</code> to be refused with a diagnostic that names 16, and <code>stp q0, q1, [sp, #1008]</code> to be accepted while <code>#1024</code> is not. 1008 is 63 &times; 16; 64 &times; 16 is one step past the end of the field. A scaled field has an UNSYMMETRIC reach, and the assembler prints the asymmetry rather than the maximum.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, and one concept: <a href="/courses/a64asm/lessons/a64-encoding">the field map</a> is where the three scales in the table above were measured, and <a href="/courses/a64asm/lessons/a64-verify">the encoding course's cross-check</a> is what makes those ranges trustworthy rather than remembered. This course's own artifact imports that decoder and prepends six models to it, because <strong>a decoder that cannot name <code>stp q0, q1</code> cannot check the alignment rule, and the alignment rule is what this page is about.</strong> Coverage: 188 further instructions named at -O0, 115 at -O2, purely by adding those six.</p>
                <p>Sideways, and this is the sibling reference: <a href="/courses/x86abi/lessons/x86-calling">The x86-64 calling convention</a> is the same contract with six integer registers instead of eight, one bank instead of two, and a pushed return address instead of a register. Reading the two side by side is the fastest way to stop treating either as &ldquo;the ABI&rdquo; &mdash; there is no <em>the</em> ABI, there is one per architecture, and the differences are the interesting part. <a href="/courses/sec/lessons/sec-canary">The stack canary</a> is a <em>consequence</em> of this page: it is a value that must survive a call, and the only region of memory that is guaranteed to survive a call is the frame.</p>
                <p>Forwards. <a href="/courses/a64abi/lessons/a64-registers">Concept 2</a> is where the question &ldquo;which register&rdquo; stops being a list and becomes a <em>property of the register file</em> &mdash; one register, two names, and the number 31 meaning three different things. Then <a href="/courses/a64abi/lessons/a64-frame">concept 3</a> is the consequence of having no red zone, and <a href="/courses/dyn/lessons/dyn-order-runtime">the dynamic-linking course</a> is where the stack is first set up, before any rule on this page has a chance to apply.</p>
            </div>

            <div class="lesson-footer">
                <span>Start of The AArch64 Procedure Call Standard: <a href="/courses/a64abi">overview</a></span>
                <span>Next: <a href="/courses/a64abi/lessons/a64-registers">One Register, Two Names, and Three Things Called 31</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
