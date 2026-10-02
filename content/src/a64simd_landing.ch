// The AArch64 Data Path: NEON, Atomics and Ordering -- landing page.
//
// The fourth and last course of the AArch64 section, and the one that closes
// it.  The three before it were about CONTROL: how a machine gets from one
// instruction to the next, what the registers mean, how a page is found.  This
// one is about DATA -- what a register holds, how wide it is, how an atomic
// is written, and where a barrier ends up not being needed at all.
//
// The distinctive claim of this course is a NEGATIVE one, and it is the first
// in the section to lead with it: there are NO TIMINGS anywhere, the x86-64
// sibling measured 3.89x, 4.92x and 27.65x, and not one of those has a
// counterpart here.  What replaces the ratios is an instruction count, and
// section 5 measures one that points in the OPPOSITE direction to the one a
// reader expects, which is the most useful number in the course.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64simd_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The AArch64 Data Path: NEON, Atomics and Ordering — Underlayer")
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
            <h1>The AArch64 Data Path: NEON, Atomics and Ordering</h1>
            <div class="lesson-meta">127 min total &middot; 5 concepts &middot; 2 modules</div>

            <div class="unit unit-why">
                <h2>Why this course exists</h2>
                <p>The three AArch64 courses before this one were about <strong>control</strong>: what a register means, how an exception gets delivered, how a page is found, how a call unwinds. Between them they answered every question about where a program <em>goes</em>. None of them answered a single question about what a program <em>carries</em> — and that half turns out to be where the encodings are densest and where the interesting traps are.</p>
                <p>So this course is about the data path, and it is built around four things a reader cannot get from a manual and a compiler cannot tell them:</p>
                <ol>
                    <li><strong>Five names, one register.</strong> A vector register has five views and the encoding expresses that in a <em>field position that moves per instruction group</em>. <code>ldr b0</code> and <code>ldr q0</code> differ in exactly one bit, and it is bit 23 — not bit 30, not bit 31.</li>
                    <li><strong>The bit SVE does not have.</strong> One 32-bit instruction word, five vector lengths from 128 to 2048 bits, and not one bit of difference. The measurement is one command and it is the sharpest thing in the course.</li>
                    <li><strong>Acquire and release are access modes, not barriers.</strong> <code>ldar</code> is a load that also acquires. A C11 <code>seq_cst</code> load and a C11 <code>acquire</code> load are <em>the same instruction</em>, and a barrier census over the whole corpus finds three, all in functions whose source asked for a fence.</li>
                    <li><strong>One bit, two meanings.</strong> <code>CASP</code>'s 128-bit-ness is bit 23, and bit 23 is the bit that says "acquire" in the LDADD family. Same word, a few opcodes apart, no overlap.</li>
                </ol>
                <p>And it is the fourth course in a section, which means it is also the course where the method gets tested hardest. The section's standing claim has been that a decoder is a way of finding out what you did not know about a field map. This course took that seriously enough to <strong>retract twenty-seven of its own claims</strong> — seven of them in a single afternoon, and all seven found by one change to a comparison that had quietly stopped comparing.</p>
            </div>

            <div class="unit unit-model">
                <h2>What you will build, in order</h2>
                <div class="card-grid">
                    <div class="card">
                        <div class="card-body">
                            <h3><a href="/courses/a64simd/lessons/a64-neon">1 &middot; Thirty-Two Registers, Four Ways to Read One</a></h3>
                            <p>26 min. Five views of one register, and the bit that separates 64 bits from 128 bits being <em>bit 23</em>. Plus the refusal that names a feature: <code>fadd h0</code> does not assemble until you ask for FP16.</p>
                        </div>
                    </div>
                    <div class="card">
                        <div class="card-body">
                            <h3><a href="/courses/a64simd/lessons/a64-neonspace">2 &middot; The Shared Memory Space</a></h3>
                            <p>25 min. Four extensions in one encoding space, and the bit SVE spends on nothing because it reads its vector length from a register instead. Five compiles, five identical words.</p>
                        </div>
                    </div>
                    <div class="card">
                        <div class="card-body">
                            <h3><a href="/courses/a64simd/lessons/a64-atomic">3 &middot; The Exclusive Monitor, and Why the Retry Is the Instruction</a></h3>
                            <p>26 min. Why a store-exclusive that can always fail must be wrapped in a loop, and how FEAT_LSE replaces four instructions with one — while a 128-bit fetch-add still needs two.</p>
                        </div>
                    </div>
                    <div class="card">
                        <div class="card-body">
                            <h3><a href="/courses/a64simd/lessons/a64-order">4 &middot; Acquire and Release Are Access Modes, Not Barriers</a></h3>
                            <p>26 min. Twelve atomic functions, three barriers, all three in fence functions. <code>dmb</code> has two fields and not one, and the second one is the one everybody forgets.</p>
                        </div>
                    </div>
                    <div class="card">
                        <div class="card-body">
                            <h3><a href="/courses/a64simd/lessons/a64-dataflow">5 &middot; Decode the Data Path</a></h3>
                            <p>24 min. The two-reader cross-check, three poisons, and the retraction list. The concept that makes the other four trustworthy, and the one that has to be last for the same reason it is last everywhere else in this collection.</p>
                        </div>
                    </div>
                </div>
                <h3>The two absences, printed before the first measurement</h3>
                <div class="hex-dump">
                <pre>$ python3 courses/a64simd/assets/samples/a64data.py --section=1 | sed -n '1,12p'
  THE METHOD IS FORCED AND IT IS STATED FIRST:
    there is no AArch64 machine on this host, no AArch64 emulator and
    no AArch64 linker, so NOT ONE INSTRUCTION IN THIS COURSE HAS BEEN
    RUN, and there are NO TIMINGS anywhere in this file or on any of
    its five pages.

  $ ... | sed -n '/ABSENT/p'
    aarch64-linux-gnu-ld       ABSENT  (AArch64 linker)
    qemu-aarch64               ABSENT  (AArch64 emulator)
    aarch64-linux-gnu-as       ABSENT  (a SECOND AArch64 assembler)
    aarch64-linux-gnu-gcc      ABSENT  (an AArch64 GCC)
                </pre>
                </div>
                <p>Four absences and the fourth is the one that constrains everything else: <strong>there is no second AArch64 assembler</strong>. Every refusal in this course is a refusal by <code>clang 21.1.8</code>'s integrated assembler and by nothing else, and both readers of the two-reader check come from one LLVM tree. So the check establishes that this decoder and one other piece of software agree on what the bytes mean — <em>not</em> that either agrees with silicon.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course cannot do, said up front</h2>
                <p>The x86-64 sibling of this course measured <strong>3.89&times;</strong>, <strong>4.92&times;</strong> and <strong>27.65&times;</strong>. The two neutral courses that own the principles measured <strong>3.89&times;</strong> at 2&nbsp;KiB against <strong>1.14&times;</strong> at 24&nbsp;MiB (<code>simd</code>) and an uncontended <code>lock xadd</code> at <strong>2.54&times;</strong> a plain store (<code>smp</code>).</p>
                <p>Not one of those has a counterpart here, and the honest alternative to a number is not a smaller number. Where a page of this course would naturally carry a ratio it carries an <strong>instruction count</strong> and says so — and section 5 measures one that points the wrong way:</p>
                <div class="hex-dump">
                <pre>function      vectorised    scalar      NEON insns (vec)    NEON insns (scalar)
  ------------ ------------ ---------- ------------------ --------------------
  sum_loop     34           12         13                 4
  max_loop     39           12         11                 1
  axpy_loop    9            9          0                  0
  copy_loop    29           7          2                  0
  fsum_loop    37           8          18                 2
  sadd         61           9          8                  0

  [MEASURED]  and for `sum_loop` the vectorised body is LONGER than
  the scalar one: 34 instructions against 12.
                </pre>
                </div>
                <p>The reason is worth more than a number would have been: the vectoriser pays for a vector-length <em>prologue</em> and a scalar <em>epilogue</em> once, and the loop body runs <em>n</em> times. A whole-function instruction count measures code that runs once. And even the loop <em>body</em> count is not a speedup — it is a count, and the only honest use of one is to compare two builds of the same source at the same level.</p>
            </div>

            <div class="unit unit-example">
                <h2>One measurement, end to end</h2>
                <p>Here is the course's central measurement with nothing removed, so you can see what a claim in this course actually looks like on disk. It is the Q bit, and it is one XOR of two words you can hex-dump yourself.</p>
                <div class="hex-dump">
                <pre>$ python3 courses/a64simd/assets/samples/a64data.py --section=2 | sed -n '/ldr b0, \[x0\]/,/^$/p'
instruction       word         binary                                the three size bits
  ---------------- ----------- ------------------------------------ --------------------------
  ldr b0, [x0]     0x3d400000  00111101010000000000000000000000     size=0 Q=0 L=1
  ldr h0, [x0]     0x7d400000  01111101010000000000000000000000     size=1 Q=0 L=1
  ldr s0, [x0]     0xbd400000  10111101010000000000000000000000     size=2 Q=0 L=1
  ldr d0, [x0]     0xfd400000  11111101010000000000000000000000     size=3 Q=0 L=1
  ldr q0, [x0]     0x3dc00000  00111101110000000000000000000000     size=0 Q=1 L=1
  str q0, [x0]     0x3d800000  00111101100000000000000000000000     size=0 Q=1 L=0

  [MEASURED-ON-BYTES]  ldr b0 and ldr q0 differ in EXACTLY ONE BIT.
  ldr b0         xor ldr q0         = 0x00800000  -&gt; bit 23
  [MEASURED-ON-BYTES]  ldr b0 and str b0 differ in EXACTLY ONE BIT.
  ldr b0         xor str b0         = 0x00400000  -&gt; bit 22
                </pre>
                </div>
                <p>Three bits: <code>bits[31:30]</code> is the element size, bit 23 is Q, bit 22 is load-or-store. The access size is therefore <strong>three bits with five allocated values out of eight</strong>, and the bit that separates 64 bits from 128 bits is bit 23 — nowhere near the top of the word, which is where a reader's expectation is.</p>
                <p>And the sentence that makes it a lesson rather than a fact:</p>
                <div class="formula">
   R1, and why a field is not a property of an architecture

   CLAIMED     "the Q bit of a vector load is bit 30, the
                way it is in the Advanced SIMD three-same group"

   MEASURED    in the single load/store form Q is BIT 23
               and the size is bits[31:30] PLUS it

   FOUND BY    ldr b0 and ldr q0 differ in bit 23 and in
               NO OTHER BIT

   WHY         a field is not a property of an ARCHITECTURE,
               it is a property of a GROUP, and the group
               has to be decoded before the field means
               anything

   ASSERTED BY docs/aarch64-section-plan.md, concept 18
                </div>
                <p>Bit 30 <em>is</em> the Q bit in the three-same group, and that group is two pages from here. So the claim was not nonsense — it was a fact about a neighbouring group, carried one instruction too far. That is the shape of a great many encoding bugs, and it is why concept 1 ends by sweeping the same four sizes through four different groups and showing you all four positions side by side.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Before you start</h2>
                <ol>
                    <li><strong>Install nothing.</strong> The whole course runs on <code>clang</code> with <code>--target=aarch64-linux-gnu</code> and <code>llvm-objdump</code>. If <code>clang --target=aarch64-linux-gnu -S -x c /dev/null</code> does not work, the artifact will tell you so in its first section rather than failing mysteriously in the ninth.</li>
                    <li><strong>Run the harness with no toolchain at all.</strong> <code>python3 courses/a64simd/assets/samples/crosscheck.py</code>. <em>(Expect 268/268 checks passed, with no assembler, no emulator and no network. The harness reads the committed <code>a64data.out</code> rather than re-measuring, on purpose: a course whose claims can only be verified by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them, which is the same mistake as quoting a remembered number wearing a different hat.)</em></li>
                    <li><strong>Build the corpus, once.</strong> <code>sh courses/a64simd/assets/samples/build_samples.sh</code>. <em>(Expect <code>samples built: 13 files</code>. Thirteen, and the count is load-bearing: for most of this course's life the exclusive-<em>pair</em> path was built to a <code>.s</code> and never to an <code>.o</code>, so the two-reader pass never saw a <code>ldaxp</code> — and a decoder was free to read one as a <code>caspal</code> for a whole draft. That is retraction R22's hiding place and the build script says so in a comment.)</em></li>
                    <li><strong>Read concept 1 with a hex editor open.</strong> <em>(Expect the five-view table to be checkable in under a minute: five words, and two of them differ from the third by one bit. A claim you can verify yourself is a claim you will remember; a claim you have to take on faith is a claim you will forget, and this course is mostly the second kind whether it likes it or not.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, through the section. <a href="/courses/a64sys/lessons/a64-registers">The machine course's register concept</a> is where the scalar half of the register file is established, and it is the direct parent of concept 1 here: five vector views on top of the same thirty-one integer registers means the file has <em>two</em> naming schemes, and a decoder has to know which one an operand uses. <a href="/courses/a64sys/lessons/a64-evidence">The machine course's evidence concept</a> is where the three labels and the poison come from, and this course's concept 5 is its direct descendant. <a href="/courses/a64asm/lessons/a64-encoding">The encoding course</a> is the grandparent of every field position in this one, and it retracted its own 100% twice before this course was written.</p>
                <p>Sideways, and this is where the section's real argument lives. <a href="/courses/x86simd">The x86-64 SIMD course</a> is the same subject on a machine the neutral <code>simd</code> course can time, and reading it next to concept 5 here is the sharpest contrast in the collection: <em>identical question, two architectures, and the one with hardware can say 3.89&times; while the one without can only count.</em> Neither is the better course. The one with hardware is more useful for a learner who wants a number, and the one without is the only one that can show you <em>where the number came from</em>.</p>
                <p>Outward, and this is the last course of the section, so it is worth saying what the four of them add up to. <strong>Registers, memory, instructions, exceptions, page tables, calls, vectors, atomics and ordering — measured where a host can measure them, quoted where it cannot, and retracted loudly where the two disagreed.</strong> The AArch64 section's contribution to the collection is not that it covers an architecture. It is that it built a method for a course whose subject is unavailable, and then <em>checked the method against itself</em> until it produced twenty-seven retractions and three working poisons. A reader who takes that habit out of here has something that transfers to a machine they <em>can</em> run, where the temptation is different and the discipline is the same.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/a64simd/lessons/a64-neon">Thirty-Two Registers, Four Ways to Read One</a></span>
                <span>The AArch64 Data Path &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
