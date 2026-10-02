// The x86-64 Data Path — Concept 2: AVX, the three operands, and the upper half
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_avx() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("AVX and AVX2: Three Operands, vzeroupper, and the Upper Half — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>AVX and AVX2: Three Operands, vzeroupper, and What the Upper Half Holds</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/x86simd">The x86-64 Data Path</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The previous concept measured what the alignment rule costs: nothing, until it costs everything. This concept is about the two changes the VEX encoding made, and both of them are <strong>about the encoding rather than about the arithmetic</strong> &mdash; which is the shape of most changes to an instruction set, and the reason <a href="/courses/x86asm/lessons/x86-vex">the assembly course's VEX concept</a> is a prerequisite here rather than a link.</p>
                <p>The first change is that a vector instruction can name <em>three</em> registers instead of two. The second is that a 256-bit operation leaves a 128-bit register whose contents depend on <strong>which encoding ran</strong> &mdash; and that second one is where this course's headline finding is. <strong>A legacy SSE instruction preserves a YMM register's upper half. A VEX-128 instruction zeroes it.</strong> That is the opposite of the story everybody tells, and the artifact reads it out of seven bit patterns rather than arguing it from a manual.</p>
            </div>

            <div class="unit unit-model">
                <h2>The three operands, priced at 1.00&times;</h2>
                <p>Two-operand SSE means the destination is also a source, so <code>addps xmm0, xmm1</code> destroys <code>xmm0</code>. If you needed <code>xmm0</code> afterwards you had to copy it first, and the copy is an instruction. The three-operand form lets you write <code>vaddps xmm2, xmm0, xmm1</code> and keep both sources.</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  VEX3 |/,/^  arm 0 over/p'
  VEX3 | SSE 2-operand, dest IS a source           2.0105 ticks/op | value 150001.000000
  VEX3 | SSE 3-operand through a temp              1.9864 ticks/op | value 150001.000000
  VEX3 | SSE 2-operand + an explicit copy          1.9831 ticks/op | value 150001.000000

  THE THREE ARMS MUST COMPUTE THE SAME VALUE, and they AGREE:
    150001.000000, 150001.000000, 150001.000000.  The arms are comparable.
  arm 1 over arm 0: 1.00x    arm 2 over arm 0: 0.99x
  arm 0 over arm 1: 1.01x
                </pre>
                </div>
                <p>All three arms print the same value to six decimals, which is the check that makes the durations comparable, and then the copy is <strong>1.00&times;</strong>. The arm that needs a copy is not slower. <a href="/courses/x86asm/lessons/x86-vex">The assembly course ran the same experiment on a different body and at a different width and got the same answer</a>, and the two agree because the answer is structural: <em>the copy the three-operand form removes is a register move, and a register move the front end can issue for free is not on the critical path</em>.</p>
                <p>So read this as a <strong>negative result</strong>, and then read the second half of it, because that is where the interest is. What the three-operand form buys is a <em>source-level</em> property &mdash; the destination may be a register you still need &mdash; and a source-level property is exactly what an encoding is for. <strong>No duration can price it.</strong> Two instructions that retire in the same cycle cost the same cycle whether one of them was necessary; what changes is whether the program that contains them can be written at all. A latency table cannot see a constraint the source language imposes, and a course that reports &ldquo;free&rdquo; without saying <em>free in what sense</em> has taught the wrong half.</p>
                <p>The third row is the one place a difference <em>could</em> show up &mdash; an explicit copy before a two-operand add, measured with the copy hoisted &mdash; and in the recorded run it is <strong>0.99&times;</strong>, which is to say the copy is if anything marginally cheaper. That row is also the one that moves most between runs, which is why the artifact prints it as a ratio rather than a verdict: <em>a difference this small is a difference you cannot price, and the honest way to present an unpriceable difference is to print the number and decline to interpret it.</em></p>
            </div>

            <div class="unit unit-reality">
                <h2>The upper half, and the finding that inverts the story</h2>
                <p>Here is the experiment. Fill lane 4 of a YMM register with a recognisable pattern, run exactly one instruction, and read lane 4 back. If the upper half is untouched you read your own pattern; if it was zeroed you read zero. Seven rows, each a different instruction:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  DIRTY |/,/TWO vzeroupper/p'
  DIRTY | no instruction (the control)       | upper 128 bits 0x3dcccccd  PRESERVED
  DIRTY | ONE legacy addps   0f 58           | upper 128 bits 0x3dcccccd  PRESERVED
  DIRTY | ONE VEX-128 vaddps c5 f8 58        | upper 128 bits 0x00000000  ZEROED
  DIRTY | ONE legacy movaps  0f 28           | upper 128 bits 0x3dcccccd  PRESERVED
  DIRTY | vzeroupper         c5 f8 77        | upper 128 bits 0x00000000  ZEROED
  DIRTY | TWO legacy addps                   | upper 128 bits 0x3dcccccd  PRESERVED
  DIRTY | TWO vzeroupper                     | upper 128 bits 0x00000000  ZEROED
                </pre>
                </div>
                <p><code>0x3dcccccd</code> is <code>0.1f</code>, the value that was written into lane 4 before every one of these. Every row that says <code>PRESERVED</code> still has it, and every row that says <code>ZEROED</code> is exactly <code>0x00000000</code>. The control row is the one that makes the other six mean something: without it, a <code>PRESERVED</code> reading is indistinguishable from a register that was never written.</p>
                <div class="formula">
   THE USUAL STORY, and it is BACKWARDS.

   USUALLY SAID   "AVX instructions dirty the
                   upper half, which is why you
                   need vzeroupper."

   MEASURED       A LEGACY 0F 58 addps
                   PRESERVES the upper 128 bits.
                   A VEX c5 f8 58 vaddps ZEROES
                   them.

   The dirtying instruction is the
   LEGACY one.  That is what the VEX
   encoding was designed to prevent, and
   it did prevent it.
            </div>
                <p>This inverts the standard account, and the standard account is not wrong so much as <em>confused about which encoding is dangerous</em>. The reason <code>vzeroupper</code> exists is the <strong>AVX&#8211;SSE transition penalty</strong>: a processor that has just executed 256-bit operations has its upper vector lanes in a dirty state, and a following legacy SSE instruction that writes the same physical register pays a penalty to reconcile them. A <em>VEX-128</em> instruction is already in the new state and pays nothing &mdash; which is why the transition penalty applies to legacy encodings specifically and why a compiler that emits VEX everywhere, including for 128-bit work, mostly makes the problem disappear.</p>
                <p>Now the timing. Six arms, interleaved, min-of-N, with the legacy encoding <strong>forced by writing raw bytes in inline <code>asm</code></strong>:</p>
                <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  VZU  |/,/^  D over A/p'
  VZU  | A  AVX 256 only                                1.982 ticks/call
  VZU  | B  LEGACY 0F 58 SSE only                      10.192 ticks/call
  VZU  | C  VEX 128 SSE only                           10.405 ticks/call
  VZU  | D  AVX then LEGACY SSE, no vzeroupper          7.226 ticks/call
  VZU  | E  AVX, vzeroupper, then LEGACY SSE           11.859 ticks/call
  VZU  | F  VEX 128 then LEGACY SSE (the control)      11.119 ticks/call

  D over A 3.65x   E over D 1.64x   F over A 5.61x   B over A 5.14x
                </pre>
                </div>
                <p>Read those as <strong>five separate claims</strong>, because lumping them is precisely how the draft got this wrong.</p>
                <ul>
                    <li><strong>B over A is 5.14&times;, and it is the lane count and nothing else.</strong> The same arithmetic at 128 bits takes five times as long. <a href="/courses/simd/lessons/simd-width">The SIMD course owns the width</a>; it is printed here only so the other rows can be read against a baseline that is not a mystery.</li>
                    <li><strong>B over C is 0.98&times;, and that is the whole cost of the VEX prefix.</strong> A legacy <code>0f 58</code> and a VEX <code>c5 f8 58</code> doing the same sixteen 128-bit adds differ by a couple of percent. A reader who has been told the legacy encoding is catastrophically slow is wrong about that too.</li>
                    <li><strong>E over D is 1.64&times;, and this is the row the section exists for.</strong> The <em>same</em> interleaved loop with one <code>vzeroupper</code> between the two bodies and without one. The instruction is three bytes and retires on a port nothing else is using, and it is still about a third more expensive than not doing it.</li>
                    <li><strong>The widely quoted large transition penalty is NOT SUPPORTED here.</strong> If it were the cost on this part, row D would be several times row A. It is 3.65&times;, and most of that is row B's lane count being averaged in rather than anything a fence did or failed to do. On an AMD Zen 3 part the transition penalty is <strong>NOT OBSERVABLE at this granularity</strong>, and the honest sentence is that <em>this measurement does not show what the quoted figure describes</em>. That is retraction 6, and retracting a number is different from retracting a claim: the quoted figure may be about a different microarchitecture, a different width, or a per-transition cost that a loop amortises into invisibility.</li>
                    <li><strong>F over A is 5.61&times;, and it is the shape the draft would have missed by printing only A and D.</strong> A VEX-128 instruction followed by a legacy one is <em>not</em> penalised the way an AVX-256 followed by a legacy one is &mdash; because a VEX-128 instruction already leaves the register in the state the legacy instruction expects. F is the control that makes D interpretable.</li>
                </ul>
                <p>And the honest caption for all six rows: <strong>MECHANISM: INFERRED.</strong> There is no counter on this machine that can count vector-port occupancy, and the vendor manual has no number for it either. What is measured is that there is no <em>large</em> difference. Every mechanism named in this section is a story attached to a duration, and the limits block says so rather than leaving it to the reader.</p>
            </div>

            <div class="unit unit-example">
                <h2>Why the usual story is backwards, and how to tell</h2>
                <p>The story everybody tells is that AVX instructions <em>dirty</em> the upper half, and that this is why <code>vzeroupper</code> exists. Half of that is right and the half that is wrong is the half that matters, because the wrong half names the wrong instruction as the dangerous one.</p>
                <div class="hex-dump">
                <pre>    WHICH INSTRUCTION DIRTIES THE UPPER HALF?

    legacy  0f 58 addps     NO   -- the upper 128 bits survive
    VEX     c5 f8 58 vaddps YES  -- zeroed
    vzeroupper c5 f8 77     YES  -- zeroed, on purpose

    The dirtying instruction is the LEGACY one.
                </pre>
            </div>
                <p>Read that as a design statement rather than a curiosity. The VEX encoding was introduced to solve a problem, and one of the problems it solved is precisely that a legacy instruction leaves the upper lanes in a state the hardware has to reconcile later. <strong>Every AVX-256 instruction is defined to zero the upper half, precisely so that it never has to be reconciled.</strong> That is the whole of the encoding&rsquo;s second benefit, and it is invisible to anyone who only benchmarks throughput.</p>
                <p>And the way to tell that a story is wrong is the way this course has used for every claim: pick an operation whose effect is <em>observable in a register</em> and read the register. Not a duration &mdash; a <em>bit pattern</em>. The <code>0x3dcccccd</code> in the upper lane is the number you write before the experiment and read back after it, and it makes the answer unambiguous in a way no timing table ever could. <a href="/courses/x86asm/lessons/x86-vex">The assembly course&rsquo;s VEX concept</a> has the encoding side of this; what is new here is that the claim is now a measurement with a number in it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the seven DIRTY rows.</strong> <code>cd courses/x86simd/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 3B. <em>(Expect the legacy rows to say <code>PRESERVED</code> and the VEX and <code>vzeroupper</code> rows to say <code>ZEROED</code>, and expect the control row to be the reason the other six are readable at all. On a part that follows the usual story, the first two rows are the surprise and everything else follows from them.)</em></li>
                    <li><strong>Break the experiment the way it was broken.</strong> Replace the hand-written <code>addps</code> with the intrinsic <code>_mm_add_ps</code> and rerun. <em>(Expect every row to say <code>ZEROED</code>, because gcc compiles the intrinsic to a VEX encoding &mdash; and expect the &ldquo;legacy preserves&rdquo; row to disappear entirely, which is retraction 7. An experiment whose <em>arms</em> are chosen by a compiler is an experiment about the compiler.)</em></li>
                    <li><strong>Find the microarchitecture where the story is the usual one.</strong> This is a Skylake-SP or a Broadwell question, and it is the one place the quoted transition figure comes from. <em>(Expect a measurable per-transition cost there, and expect it to vanish when you put the transition inside a loop &mdash; which is why the quoted figure and this measurement are both right and appear to disagree. A per-transition cost amortised over a hundred iterations is not a cost, it is a rounding error with a story attached.)</em></li>
                    <li><strong>Write a program that depends on the upper half surviving.</strong> Take a 256-bit loop, and between iterations read the upper 128 bits of a register a legacy instruction touched. <em>(Expect it to work, and expect a compiler that decides to use a VEX encoding for the &ldquo;legacy&rdquo; instruction to break it. Which is the real lesson: the upper-half rule is not a rule you can rely on, it is a rule the <em>encoding</em> guarantees, and the encoding is not yours to choose once you are past the assembly.)</em></li>
                    <li><strong>Check whether you should be writing <code>vzeroupper</code> at all.</strong> Build a mixed AVX/SSE program and look at what gcc emits. <em>(Expect it to emit <code>vzeroupper</code> automatically at function boundaries, and expect it not to emit one in the middle of a loop because the penalty is per-transition. Then hand-write the function boundary case and watch the cost appear &mdash; and remember that this is a <a href="/courses/x86asm/lessons/x86-flags">flag-and-encoding question</a> that the ABI course owns, not a vector question.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86simd/lessons/x86-sse">the previous concept</a> measured the alignment rule and found that VEX did not touch it. This one is the other half of what VEX did and the half that is genuinely new: the three-operand form and the upper-half semantics. The pair is worth reading together, because the shape is <em>one popular claim retracted and one popular claim inverted</em> &mdash; which is the honest shape of most of what an encoding does.</p>
                <p>Forwards. The upper half is a register that exists only in the new encoding, and the next concept asks the obvious question: what happens when you make it 512 bits and add thirty-two more registers and eight mask registers? On this machine the answer is that <strong>nothing can be executed at all</strong>, which is a different kind of answer and the reason that concept is the hinge of the course. The three concepts together are the vector story: what the register is, what the encoding changed, and where the claims stop being measurable.</p>
                <p>Outward. The dirty-upper-bits rule is the one piece of this course that leaks into portable code, because a library compiled with AVX and a library compiled without can be linked into the same process, and the transition happens at the call boundary whether or not anyone wrote <code>vzeroupper</code>. That is the <a href="/courses/x86abi/lessons/x86-calling">ABI course's calling convention</a> meeting the vector units, and the reason the <code>vzeroupper</code> question has an answer in the <em>callee</em> rather than in the caller. It is also, not coincidentally, why every x86-64 calling convention has a vector register save area at all.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86simd/lessons/x86-sse">SSE and SSE2: The XMM Register and the Alignment Split</a></span>
                <span>Next: <a href="/courses/x86simd/lessons/x86-avx512">AVX-512: ZMM, k0&#8211;k7, and a Decoder That Needs No Silicon</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
