// The AArch64 Data Path: NEON, Atomics and Ordering -- Concept 4:
// Acquire and Release Are Access Modes, Not Barriers.
//
// This is the concept that separates AArch64 from x86-64 IN KIND rather than
// in detail, and the page's number is a zero: twelve functions performing C11
// atomic operations emit THREE barriers, and all three are in functions whose
// source asked for a fence.  The acquire load and the sequentially consistent
// load are the SAME instruction.
//
// The second half is the encoding, and the sharpest fact on it is that DMB,
// DSB and ISB differ in TWO fields rather than one -- and that the second one
// is the one everybody forgets.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_order() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Acquire and Release Are Access Modes, Not Barriers — Underlayer")
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
            <h1>Acquire and Release Are Access Modes, Not Barriers</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/a64simd">The AArch64 Data Path: NEON, Atomics and Ordering</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>x86-64's memory model is strong and mostly implicit: a program is sequentially consistent unless it says otherwise, and the exceptions are three opcodes — <code>MFENCE</code>, <code>LFENCE</code>, <code>SFENCE</code> — which a program sprinkles at the places it wants to be weaker.</p>
                <p>AArch64's model is <strong>weak</strong>, and the only tool for strengthening it is an <strong>access mode written on the access itself</strong>. <code>LDAR</code> is a load that also acquires. <code>STLR</code> is a store that also releases. A C11 acquire load is one of them, rather than a load followed by a barrier.</p>
                <p>So the same correct-looking C11 program needs <strong>different instructions</strong> on the two architectures, and the compiler is what translates. Which means the compiler's choices are the reference material, and they are measurable — and what they measure is not what a reader who has only read the manual expects.</p>
            </div>

            <div class="unit unit-model">
                <h2>The measurement: twelve functions, three barriers</h2>
                <div class="hex-dump">
                <pre>function            the C11 operation         what clang emitted                        barriers
  ------------------ ------------------------ ---------------------------------------- ---------
  load_acq           acquire load             ldar x0, [x0]                            0
  load_seqcst        seq_cst load             ldar x0, [x0]                            0
  store_rel          release store            stlr x1, [x0]                            0
  store_seqcst       seq_cst store            stlr x1, [x0]                            0
  fence_seqcst       seq_cst fence            dmb ish                                  1
  fence_acquire      acquire fence            dmb ishld                                1
  fence_release      release fence            dmb ish                                  1
  fence_relaxed      relaxed fence            (nothing)                                0
  load_then_load     two seq_cst loads        ldar x8, [x0] | ldar x9, [x1] | add x0, x9, x8  0
  store_then_store   two seq_cst stores       stlr x2, [x0] | stlr x3, [x1]            0
  bump               a seq_cst fetch-add      mov x8, x0 | ldaxr x0, [x8] | add x9, x0, #1
                                          | stlxr w10, x9, [x8] | cbnz w10, .LBB23_1  0
  publish            a plain store, then a
                     seq_cst store            mov w8, #1 | str x1, [x0, #8] | stlr x8, [x0]  0

  [MEASURED]  and the number that decides the concept:
     3 barriers in 12 functions that perform C11 atomic operations.
                </pre>
                </div>
                <p>Read the first two rows again. A C11 <strong>acquire</strong> load and a C11 <strong>sequentially consistent</strong> load are <em>the same instruction</em> — one <code>ldar x0, [x0]</code>, <code>0xc8dffc01</code> — and so are a release store and a seq_cst store, both one <code>stlr</code>, <code>0xc89ffc01</code>. There is no <code>dmb ish</code> in either, and there is no wider instruction for the stronger order.</p>
                <p>That is not a compiler shortcut. [QUOTED] On AArch64 the sequentially consistent order on a <em>single access</em> is exactly acquire-or-release: the extra constraint a seq_cst load carries over an acquire load is on its relation to <em>other</em> operations, and it is discharged by the other operations being acquire or release too. (The Architecture Reference Manual's C/C++ mapping appendix, which is a mapping and not a proof.) And the <strong>measured</strong> consequence is the table above: <strong>zero</strong> barriers in every atomic in the corpus.</p>
                <div class="formula">
   R20, and the sentence a reader arriving from x86-64 needs

   CLAIMED     a C11 sequential consistency order needs a
               barrier somewhere

   MEASURED    the whole corpus emits ZERO barriers outside the
               three functions whose source asks for a fence

   FOUND BY    a census over thirteen generated .s files at four
               optimisation levels

   WHY         acquire and release are ACCESS MODES, and a mode
               is not a barrier.  A reader arriving from x86-64
               will look for an mfence and this architecture does
               not have one.
                </div>
                <p>And the asymmetry in the three that <em>do</em> appear is the second finding on this page:</p>
                <div class="hex-dump">
                <pre>     fence_seqcst   dmb ish  | ret
     fence_acquire  dmb ishld | ret
     fence_release  dmb ish   | ret
                </pre>
                </div>
                <p>An <strong>acquire</strong> fence narrows to <code>dmb ishld</code> — the load variant. A <strong>release</strong> fence is a full <code>dmb ish</code> and is <em>not</em> narrowed to <code>dmb ishst</code>. [MEASURED], and the course does not claim it is wrong: a release fence in C11 has to order against later loads as well as later stores, [QUOTED], so the full barrier may be exactly what the mapping requires. What is measured is that the compiler <strong>narrows one and not the other</strong>, and a reader who expected symmetry gets a measurement instead.</p>
            </div>

            <div class="unit unit-reality">
                <h2>DMB, DSB, ISB: two fields, not one</h2>
                <p>[QUOTED] The three barriers: <code>DMB</code> is a data memory barrier and orders the memory accesses either side of it, and does <em>not</em> make the instruction stream see anything new. <code>DSB</code> is as DMB and additionally completes before any instruction after it is executed — so it waits for stores to become <strong>observable</strong>, not merely performed. <code>ISB</code> is an instruction synchronisation barrier: it flushes the pipeline and the instruction-fetch side, it is how a context switch to a different exception level or a different PC is made to take effect, and it has no effect on the data side at all. (ARM DDI 0597, the pseudocode for the three instruction groups, and the "Memory ordering" chapter of the Architecture Reference Manual.)</p>
                <p>They are not interchangeable and the difference is not a matter of degree. A DMB does not stop an instruction fetch; an ISB does not order a load. That is <strong>QUOTED</strong>. What is <strong>MEASURED</strong> is that the encoding expresses the difference in <strong>two separate fields</strong>, and that the second one is the one everybody forgets:</p>
                <div class="hex-dump">
                <pre>option    dmb          dsb          isb          the option field    the id field
  -------- ----------- ----------- ----------- ------------------ --------------
  oshld    0xd50331bf  0xd503319f  REFUSED     CRm = 0001         op2 = 101
  oshst    0xd50332bf  0xd503329f  REFUSED     CRm = 0010         op2 = 101
  osh      0xd50333bf  0xd503339f  REFUSED     CRm = 0011         op2 = 101
  nshld    0xd50335bf  0xd503359f  REFUSED     CRm = 0101         op2 = 101
  nshst    0xd50336bf  0xd503369f  REFUSED     CRm = 0110         op2 = 101
  nsh      0xd50337bf  0xd503379f  REFUSED     CRm = 0111         op2 = 101
  ishld    0xd50339bf  0xd503399f  REFUSED     CRm = 1001         op2 = 101
  ishst    0xd5033abf  0xd5033a9f  REFUSED     CRm = 1010         op2 = 101
  ish      0xd5033bbf  0xd5033b9f  REFUSED     CRm = 1011         op2 = 101
  ld       0xd5033dbf  0xd5033d9f  REFUSED     CRm = 1101         op2 = 101
  st       0xd5033ebf  0xd5033e9f  REFUSED     CRm = 1110         op2 = 101
  sy       0xd5033fbf  0xd5033f9f  0xd5033fdf  CRm = 1111         op2 = 101

  [MEASURED]  DMB and DSB accept 12 of the 12 options, and the
  option field is bits[11:8] -- FOUR bits carrying TWELVE names, so
  four of the sixteen values are unallocated.  ISB accepts ONE.
                </pre>
                </div>
                <p>So "DMB, DSB and ISB differ in one field" is true and is <strong>half the answer</strong>. The identity is a three-bit <code>op2</code> at <code>bits[7:5]</code>:</p>
                <div class="hex-dump">
                <pre>     dmb sy 0xd5033fbf   dsb sy 0xd5033f9f   isb 0xd5033fdf
     dmb xor dsb = 0x00000020 -&gt; bit 5 only
     dmb xor isb = 0x00000060 -&gt; bit 5 and bit 6
     dmb xor clrex = 0x000000e0 -&gt; bits[7:5]

     and the one that is NOT a barrier and shares the group:
     clrex  0xd5033f5f   op2 = 010   Rt = 11111
     MEASURED: 0b010, and none of the three barriers uses it.
                </pre>
                </div>
                <p><code>CLREX</code> is the fourth instruction in that group, at an <code>op2</code> value no barrier uses, and it has no ordering effect at all — it exists to make an LL/SC pair stop being a loop. And note the shape of the last row: <strong>four instructions share <code>bits[31:8]</code> and differ in three bits, and one of the four is not a barrier.</strong> A decoder that reads a group boundary as "these are the barriers" has missed an instruction that belongs to the group.</p>
                <h3>And the option field is not decoration</h3>
                <div class="hex-dump">
                <pre>     dmb osh   CRm = 0011  =  3  -- the domain it orders
     dmb nsh   CRm = 0111  =  7  -- the domain it orders
     dmb ish   CRm = 1011  = 11  -- the domain it orders
     dmb sy    CRm = 1111  = 15  -- the domain it orders
     dmb ishld CRm = 1001  =  9  -- the inner domain, loads only
                </pre>
                </div>
                <p>[QUOTED] <code>osh</code> orders accesses to the outer shareable domain, <code>ish</code> the inner one, <code>sy</code> the whole system. <strong>MEASURED</strong>: the domain bits and the direction bits (<code>ld</code>, <code>st</code>) are the <em>same four bits</em>, so there is no way to say "inner, loads only" without spending a code — and <code>ishld</code> <em>is</em> that code, <code>1001</code>. Twelve names in sixteen codes, allocated as four domains times two directions plus four combinations, and the combinations are the ones you actually want.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the one control you may not name</h2>
                <p>The last measurement in the course is a refusal, and it is the right place to end a page about ordering — because it is a control over the privilege level, it is not an ordering instruction, and the assembler will not spell its name at all.</p>
                <div class="hex-dump">
                <pre>     msr PSTATE.PAN, x1    -&gt; REFUSED: expected writable system
                                        register or pstate
     msr S3_3_C4_C0_2, x1  -&gt; 0xd51b4041
     mrs x0, S3_3_C4_C0_2  -&gt; 0xd53b4040
     msr xor mrs = bit 21
                </pre>
                </div>
                <p>The assembler refuses the architectural <em>name</em> of a register it will accept the <em>encoding</em> of. [QUOTED] <code>PSTATE.PAN</code> — Privileged Access Never — when set, forbids the level below from using <code>SVC</code> and forbids <code>SP_EL0</code>, so that a kernel can hand a pointer to user space knowing user space cannot use it to reach the kernel.</p>
                <p>And note the shared bit: <code>msr</code> and <code>mrs</code> differ in <strong>bit 21</strong> — which is the bit that is a <em>constant across the whole LSE group</em>, measured on the previous page. A bit that means "write" in one group and "nothing at all" in another, in the same 32-bit word format, is a good reminder that a bit position is not a property.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Count the barriers yourself, and then take them away.</strong> Compile the twelve functions at <code>-O2</code>, grep the <code>.s</code> for <code>dmb</code>, <code>dsb</code> and <code>isb</code>. <em>(Expect three, all in fence functions. Then delete the three fence functions and compile again: expect zero. The measurement is not "AArch64 needs no barriers" — it is "these twelve operations needed none", and the difference between those two sentences is the whole discipline of this course.)</em></li>
                    <li><strong>Ask for the twelve options and count what you get.</strong> <code>dmb oshld</code> … <code>dmb sy</code>, all twelve; then <code>isb oshld</code> … <code>isb sy</code>. <em>(Expect twelve and ONE. <code>isb</code> accepts only <code>sy</code>, and <code>isb sy</code> is the same word as bare <code>isb</code> — 0xd5033fdf — so an option field with one live value in one member of its group is a field that is not a field in that member.)</em></li>
                    <li><strong>Find the instruction in the barrier group that is not a barrier.</strong> Look at <code>0xd5033f5f</code> in a hex editor. <em>(Expect <code>clrex</code>, at <code>op2 = 0b010</code>, a value none of the three barriers uses. It shares <code>bits[31:8]</code> with all of them and has no ordering effect: it exists so a program can decide to stop retrying. A group named for what its members do will eventually contain a member that does not do it.)</em></li>
                    <li><strong>Write down what you would need to publish the claim this page cannot.</strong> "DMB orders memory accesses, DSB waits for stores to become observable, ISB flushes the fetch side." Which sentence needs hardware? <em>(Expect all three, and expect the middle one to be the most surprising: "observable" is a statement about what <em>another</em> processor can see, and there is no second processor here. The four option bits are measured; the meaning of the option is quoted; and the page says so at the point where a reader expects a number.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, immediately. <a href="/courses/a64simd/lessons/a64-atomic">The exclusive monitor</a> measured the <em>cost</em> of an ordering mode — one bit on an exclusive, two bits on an LSE operation, and a 128-bit fetch-add that is two instructions because LSE has no pair arithmetic. This page is where the <em>meaning</em> of those bits is, and the two pages together are the argument that ordering on AArch64 is a property of the access and a barrier is the exception.</p>
                <p>Back to the machine course, and this is the connection that makes the section a whole. <a href="/courses/a64sys/lessons/a64-pagetables">Four Levels, and Why a Page Needs a Pair of Relocations</a> established <code>dsb</code> + <code>isb</code> as the sequence that makes a context switch take effect — and it is quoted, because there is no EL1 here and no way to run it. This page measured that <code>isb</code> accepts one option and that <code>clrex</code> is in the same group, which is what turns that quoted sequence from a sentence into two words you can hex-dump.</p>
                <p>Sideways, and it is the contrast the whole section was building toward. <a href="/courses/x86simd">The x86-64 SIMD course</a> measured its atomics — 3.89&times;, 4.92&times;, 27.65&times; — on a machine it could time, and it measured them with <code>mfence</code> in the picture. The two architectures agree that an atomic needs an ordering story and disagree about where the story lives: on x86-64 in a prefix and an explicit fence, on AArch64 in a bit on the access. <strong>Neither is the modern one.</strong> AArch64's is the more expressive design and it is also the one that punishes a reader who arrives expecting the other — which is why this page ends on a register the assembler will not name rather than on a summary.</p>
                <p>Outward, and this is the last idea the section has to give you. <strong>An ordering mode on an access is a declaration about a relationship, and a barrier is a declaration about a point.</strong> That difference is why AArch64 needs fewer barriers for the same program and needs a reader who has internalised it more: the guarantee is distributed across the accesses, so a reader who looks only at the fences sees nothing, and a reader who looks only at one access sees half. The x86-64 reader's habit — find the fence, that is where the ordering is — is not wrong on x86-64 and is actively misleading here, and the cheapest way to notice is to compile a C11 program and look for the instruction that is not there.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64simd/lessons/a64-atomic">The Exclusive Monitor, and Why the Retry Is the Instruction</a></span>
                <span>Next: <a href="/courses/a64simd/lessons/a64-dataflow">Decode the Data Path</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
