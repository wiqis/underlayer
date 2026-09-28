// SIMD and Vector Processing — Concept 6: three answers to one shape
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_three() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Three Answers to One Shape — Underlayer")
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
            <h1>Three Answers to One Shape</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything measured in this course so far was measured on one machine: an AMD Ryzen 5 7430U, x86-64, with AVX2 and FMA and <strong>no AVX-512 at all</strong> &mdash; five CPUID leaves, all zero, printed in the artifact's section 0. That is a real limit and the artifact's limits block says so in the same words. But &ldquo;this machine is x86-64&rdquo; is not an excuse for the rest of the course being x86-shaped, because a vector loop is the one piece of code that most needs to be portable and is hardest to make so.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/7\. THE SAME SHAPE/,/three architectures in the room/p'
   7. THE SAME SHAPE ON THREE ARCHITECTURES
      QUOTED, NOT MEASURED.  This machine is x86-64 and there is no other
      architecture in the room.  Every claim below is a manual claim with a
      document, and the limits block says so a second time.
  </pre>
                </div>
                <p>So this concept is quoted, and the discipline is worth stating before the quotes: <strong>every claim below is a manual claim with a document, and not one of them is a measurement.</strong> Where this course measured something, it says so and gives the number. Here it does not, and the distinction is the point &mdash; the previous five courses each made a point of it, and this one is no different.</p>
                <p>Why the concept exists at all is that the three architectures make <strong>structurally different choices</strong> about the same two questions, and the differences are not degree-of-support differences. They are the difference between a fixed register width and a chosen one, and between having a gather instruction and not having one. A loop written for one of them and benchmarked on another is not a portable benchmark; it is two different benchmarks wearing one source file.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: five rows, and only three of them are portable</h2>
                <p>Every vector loop, on every machine, answers the same five questions. The questions are the same. <strong>The answers are not.</strong></p>
                <div class="formula">
   THE FIVE ROWS, AND WHERE THEY AGREE

     1. how many elements   the register width, which is
        does one instr.         FIXED on x86-64 and on NEON,
        touch?                 and PROGRAMMABLE on SVE and
                               on RISC-V V            DIFFERS

     2. how are they loaded? a consecutive load; and on
                               x86-64 sometimes a gather,
                               which this course measured at
                               2.78x four scalar loads
                                                            DIFFERS

     3. what does the       ELEMENTWISE and INDEPENDENT,
        operation do?        on all three               THE SAME

     4. how are they        N INDEPENDENT LANES, ONE
        reduced?             INSTRUCTION, WITH A
                               REDUCTION AT THE END    THE SAME

     5. what is the tail?   a mask on two of them, a
                               scalar epilogue on one  DIFFERS
                </div>
                <p><strong>Rows 3 and 4 are the same on all three architectures</strong>, and row 4 is the sentence to take away: <em>N independent lanes, one instruction, with a reduction at the end</em>. That is the portable shape, and it is the same sentence the privilege course and the multiprocessor course each arrived at in their own vocabulary.</p>
                <p>Rows 1, 2 and 5 are where a benchmark stops meaning the same thing. Row 1 because the width is a compile-time constant on one architecture and a runtime property on another. Row 2 because a gather exists on x86-64 and does not exist in NEON at all. Row 5 because predication exists on SVE and RISC-V V and does not exist on the other two.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: three architectures, quoted</h2>
                <h3>x86-64 &mdash; the one that was measured</h3>
                <p>The width is a property of the <strong>encoding</strong>: VEX encodes 128 or 256 bits, EVEX encodes 512 and adds the mask, the broadcast and the embedded-rounding fields. That is why <a href="/courses/isa/lessons/isa-length">the ISA course's length concept</a> is the place to go for the register-width question and not here. AVX2 added <code>vpgatherdd</code> and <code>vpgatherqd</code>, and the previous concept measured them and found them <strong>slower than four ordinary scalar loads</strong>. The mask is <code>k0</code>&ndash;<code>k7</code> with 64 bits each, and it is AVX-512 only &mdash; absent on this machine, proved rather than assumed. And the tail has no answer on a non-AVX-512 part: handle <code>n&nbsp;mod&nbsp;4</code> scalar, which the artifact measured as free.</p>
                <h3>AArch64 NEON &mdash; a fixed 128 bits, and no gather</h3>
                <p>This is the structural difference, and it surprises people who have only written x86 SIMD. <strong>NEON is 128 bits and there is no wider general-purpose SIMD register in the base architecture at all.</strong> A 4-wide double loop is 2-wide, and there is nothing to change that. So the loop this course measured at 3.89&times; does not exist as a single register on AArch64 &mdash; it exists as two 2-wide halves, or as four accumulators, which is <a href="/courses/simd/lessons/simd-shapes">the independence result from module 2</a> arriving early and unasked for.</p>
                <p>Two more differences, and both are absences that turn out to be features:</p>
                <ul>
                    <li><strong>No gather instruction exists in NEON.</strong> An indirect load is a plain <code>ldr</code> into a D register, so a gather costs what four scalar loads cost. <strong>The architecture with no gather instruction is the one where the hand-written gather is not merely better but the only thing there is</strong> &mdash; which is what the previous concept measured as 2.78&times; on x86. The portable code is the hand-written one, and on this machine it is the faster one too.</li>
                    <li><strong>No aligned variant of the SIMD load.</strong> <code>ldr q0, [x0]</code> is unaligned-tolerant by default, so the alignment question the previous concept spent a table on &mdash; <em>is the aligned form faster, and what happens if you get it wrong</em> &mdash; simply does not arise.</li>
                </ul>
                <h3>SVE &mdash; the width is a program property, and the tail is a predicate</h3>
                <p>SVE is the opposite design and it is worth reading as a deliberate answer to the two problems this course measured. The register size is <strong>programmable, up to 2048 bits</strong>, so a loop written once runs at whatever width the implementation chooses &mdash; and the two problems the previous concepts found both have answers here. <strong>Predication:</strong> a sequence of predicated instructions, so a tail is a predicate rather than a branch or a scalar epilogue. That is the answer to the 1.77&times; overlapping-iteration row, and it is not a small answer &mdash; it removes the cost of the entire problem.</p>
                <h3>RISC-V V &mdash; v0 <em>is</em> the mask</h3>
                <p>The V extension has named VLEN-bit register groups, currently VLEN&nbsp;&ge;&nbsp;128, with the width again a property the implementation chooses. Two features are worth naming precisely because they show where AVX-512 was heading. <strong>v0 is the mask register</strong> &mdash; one bit per element, and <code>v0.t4</code> selects four 32-bit lanes &mdash; and it is part of the register file rather than a separate operand. A masked instruction reads <code>vl</code> elements and ignores the rest, so the tail is a change to <code>vl</code> and nothing else: no epilogue, no branch, no scalar code. And <strong>a segment load</strong> &mdash; <code>vlseg</code> &mdash; can fetch a strided run into a vector in one instruction, which is the operation the x86 gather is trying to be, done by a different instruction for a <em>regular</em> pattern rather than an arbitrary index list. <code>vrgather.vv</code> exists for the irregular case, for the same reason x86 has one.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the same loop, three targets, and what changes</h2>
                <p>Take the loop this course has been measuring &mdash; <code>A[i] = A[i]*B[i] + C[i]</code> over 64 doubles, with a reduction at the end &mdash; and ask what each architecture can do with it. <strong>Read this as a table of decisions, not of features.</strong></p>
                <div class="formula">
   STEP                       x86-64        NEON         SVE / RVV
   -----------------------------------------------------------
   register width             32 bytes      16 bytes    VLEN,
   for doubles                (AVX2)        and that     chosen
                                         is ALL       at runtime
   the inner instruction      vfmadd        fmla         fmla + vset
   one register per ...       4 doubles     2 doubles   VLEN/8
   a gather of 4 scattered    YES, and     NO           vrgather.vv
   values                     MEASURED      INSTRUCTION  exists
                              2.78x SLOWER  EXISTS
                              than 4 loads
   the tail                   scalar        scalar       PREDICATE
                              (free,        (free)       (nothing to
                              measured)                  pay)
   the fold                   haddpd, or    addp, or    addv, or
                              extract-tree  extract-tree extract-tree
                </div>
                <p>And the three observations that matter, in order.</p>
                <p><strong>One: the portable loop is the one that is slowest on the machine you develop on.</strong> If you write the hand-gathered version &mdash; four scalar loads assembled into a vector &mdash; it is the only option on NEON, it is <em>2.78&times; faster</em> than the hardware gather on this x86 machine, and it is roughly comparable to a <code>vrgather</code> on RVV. The one implementation that is bad everywhere is the one that uses the widest instruction available at the time of writing, because that instruction is the one that does not exist on the next target.</p>
                <p><strong>Two: the width is a portability hazard, and the fix is to not depend on it.</strong> A loop whose inner trip count is <code>n / 4</code> is written for a 256-bit register. On NEON that silently becomes <code>n / 8</code> and leaves half the data unprocessed unless the code generator knows the target width &mdash; and if the code generator does not, the bug is a <em>wrong answer</em>, not a crash. Code that says &ldquo;process four at a time&rdquo; where four means &ldquo;one register&rdquo; is not portable code; it is x86 code with a generic-looking loop bound.</p>
                <p><strong>Three: the two portable rows are 3 and 4, and they are enough.</strong> Elementwise, independent, one instruction, reduce at the end. That compiles to something reasonable on all three. Everything else in the table &mdash; the width, the gather, the tail &mdash; is where a portable implementation has to give something up, and the interesting engineering question is <em>which</em> something.</p>
                <div class="formula">
   THE PRACTICAL SHAPE, and it is the same on all three:

     four (or N) INDEPENDENT accumulators
     a loop over CONSECUTIVE elements
     ONE fold, at the end

     and the portability work is entirely in:
       - not assuming the width          (row 1)
       - not assuming a gather exists    (row 2)
       - not assuming you can afford a
         clever tail                     (row 5)
                </div>
                <p>Which is a shorter list than it looks, because all three of those are the same mistake: <strong>writing the fast case for the machine you have and calling it portable.</strong> The measure of a portable vector loop is not that it compiles on three architectures; it is that it is <em>correct</em> on all three and that you can say out loud, for each, what you gave up.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Count the lanes in each architecture before you write the loop, not after.</strong> <em>(Expect NEON to be the surprise: 128 bits, so two doubles, and no wider option. If you have been writing &ldquo;four doubles at a time&rdquo; in a portable-looking loop, that loop has been x86 code all along. The exercise is to find those loops in a codebase that claims to be portable and to notice that <code>for (i = 0; i &lt; n; i += 4)</code> is a claim about a register, not about a language.)</em></li>
                    <li><strong>Write the gather three ways and see which one survives translation.</strong> Four scalar loads, <code>vpgatherdd</code>, and a segment load for a strided case. <em>(Expect the scalar version to be the only one that exists everywhere, and to be the fastest of the three on the x86 machine you are sitting at. That double win is rare in systems work and it is worth noticing when it happens &mdash; the portable choice and the fast choice agreeing is not something to expect by default.)</em></li>
                    <li><strong>Find a tail and write it three ways, then ask which is correct on which target.</strong> Scalar epilogue, overlapping iteration, predicated. <em>(Expect the scalar one to be correct everywhere and to cost nothing, and expect the overlapping one to be a performance bug on the two architectures that have no mask. The interesting exercise is the third one: implement predication behind a feature check and measure what it is worth on a machine that has it, because that number is the argument for requiring a newer baseline.)</em></li>
                    <li><strong>Read a man page for an instruction you do not have.</strong> The NEON instruction set page has no gather in it at all, and that absence is the finding. <em>(Expect the page to be organised by register and by data type rather than by operation, which makes it hard to search for &ldquo;is there an instruction that does X&rdquo; and easy to establish that there is not. Reading an ISA manual for a machine you do not own is a skill, and this course has no way to teach it any other way.)</em></li>
                    <li><strong>Write down, for one loop of yours, what you would lose on each of the three.</strong> <em>(Expect the honest answer to be a short list &mdash; the width, a gather, a tail &mdash; and expect that writing it down is what tells you whether the intrinsics were worth it. A loop whose answer is &ldquo;nothing, it is the same everywhere&rdquo; is either genuinely well written or you have not thought about it, and there is no third possibility.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the answer to both questions the last two concepts raised. <a href="/courses/simd/lessons/simd-boundaries">The boundaries concept</a> measured a gather instruction at 2.78&times; four scalar loads and a tail at 1.77&times; for the clever approach; <strong>NEON has no gather and therefore no gather problem</strong>, and SVE and RISC-V V have predication and therefore no tail problem. The measurements were never about the machine &mdash; they were about the shape of the access, and the shape is architecture-independent even when the instruction is not. <a href="/courses/simd/lessons/simd-width">The width concept</a> is where the register table lives, and its third trap &mdash; that a 512-bit register is not four times a 128-bit one in practice &mdash; is the upper-ZMM aliasing, which is an x86-specific artefact of a fixed-width design and does not arise on a machine where the width is chosen.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-harness">the harness concept</a> is the ledger, and the thing it has to be honest about is this one: <strong>every claim in this concept is quoted and none of it is measured</strong>, so the harness's group on the three architectures checks that the artifact says so, and nothing else. That is the correct treatment and it is worth noticing how small that group is next to the group on the working-set sweep.</p>
                <p>Outward, this is the concept where the course's chain becomes visible. <a href="/courses/isa/lessons/isa-length">The ISA course's length concept</a> is where VEX and EVEX are laid out and where the 0x62 prefix that introduces a 512-bit instruction is decoded; this concept says what the instruction is <em>for</em>, which is the half the ISA course deliberately left open. <a href="/courses/priv/lessons/priv-vectors">The privilege course's vector-19 exception</a> is the one place the word SIMD appeared in five courses, and it is an exception table &mdash; a case where the ISA contract has an escape hatch and the hardware agrees. <a href="/courses/wasm/lessons/wasm-instructions">The WebAssembly course's instruction concept</a> defines a 128-bit vector type for machines that do not have one, and this concept is the honest reading of what that buys: <strong>a portable subset of all three row-1 answers, which is the NEON one, because 128 bits is the only width every architecture in this course agrees on.</strong></p>
                <p>And one outward-facing consequence, because this is the concept a backend author will return to. <strong>The portable width is 128 bits and it is portable because it is the smallest, not because it is good.</strong> Every performance result in this course was measured at 256 bits, and every one of them would be different at 128 &mdash; the working-set collapse in module 1 would happen at half the size. Choosing a target width is choosing which ceiling you will hit first, and the choice is a property of the machine rather than of the program. That is the last thing this course has to say about width, and it is a better place to say it than in module 1, because by now you know what the ceiling is made of.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-boundaries">Alignment, the Gather, and the Tail</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-harness">The Harness, and the Eight</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
