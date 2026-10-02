// Compiler Backend: From IR to Machine Code -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_compback_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Compiler Backend: From IR to Machine Code — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Compiler Backend: From IR to Machine Code</h1>
            <div class="lesson-meta">6 concepts &middot; 3 modules &middot; 150 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>You have reached the part that was missing</h2>
                <p>The chain this collection teaches has a shape, and it is written down in <code>docs/course-mission.md</code>:</p>
                <div class="hex-dump">
                <pre>  lexing ──▶ parsing ──▶ IR ──▶ codegen ──▶ object files
                                                     │
                                       ┌─────────────┴─────────────┐
                                       ▼                           ▼
                              machine code                 relocations, symbols,
                              (this course)                section tables
                                                              │
                                                   linking ──▶ executable
                                                              │
                                                      loading ──▶ alive
                </pre>
                </div>
                <p>Both ends of that chain are taught here in depth. <a href="/courses/elf">The ELF course</a> and the object-format courses take the files apart field by field. <a href="/courses/reloc/lessons/reloc-apply">The relocation course</a> and <a href="/courses/link/lessons/link-write-script">the linking course</a> cover what happens to the pair once the backend has handed one over. The image and dynamic-linking courses cover loading. And three whole architecture sections &mdash; x86-64, AArch64, RISC-V &mdash; take the targets apart instruction by instruction.</p>
                <p><strong>The middle was taught nowhere.</strong> Not thinly &mdash; nowhere. There was no course that took the thing a compiler has in front of it, an intermediate representation, and asked the three questions a backend asks about it: <em>which machine form, which register, which order</em>. And no course that showed you how to read a backend&rsquo;s decisions back out of the bytes afterwards, which is the only way to check your own work without trusting the compiler.</p>
                <p>This course is that hole being filled, and you should know that you have arrived at it rather than at the part you already know.</p>
                <p>And there is a second thing to know before the first number, because it changes what every number on the next five pages is allowed to be. <strong>This is the first course in the collection whose machine runs the code it makes.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>Read this before the first number: three absences, and the one thing that is present</h2>
                <p>The artifact prints the host&rsquo;s limits before it prints a single figure, because a claim about a decoder needs one:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE FOUR THINGS THIS HOST/,/^$/p'
  * x86-64 RUNS NATIVELY.  There is an x86-64 machine, so this course
    can put a RATIO on the cost of a spill and a RATIO on the cost of
    a schedule.  NO OTHER COURSE IN THIS COLLECTION HAS DONE THAT, and
    it is the one measurement that belongs here and nowhere else.
  * aarch64-linux-gnu COMPILES AND CANNOT RUN.
    aarch64-linux-gnu-ld IS NOT INSTALLED: no linker, so nothing this
    course emits for this target is EVER EXECUTED and no
    relocation it emits is EVER RESOLVED.
    NO EMULATOR: qemu-aarch64 and spike are both ABSENT.

  * riscv64-linux-gnu COMPILES AND CANNOT RUN.
    riscv64-linux-gnu-ld IS NOT INSTALLED: no linker, so nothing this
    course emits for this target is EVER EXECUTED and no
    relocation it emits is EVER RESOLVED.
    NO EMULATOR: qemu-riscv64 and spike are both ABSENT.
                </pre>
                </div>
                <p>So there are <strong>exactly three labels</strong> on every page of this course, and there is no fourth:</p>
                <ul>
                    <li><strong>MEASURED</strong> &mdash; about x86-64 code, because it <em>ran</em>.</li>
                    <li><strong>MEASURED-ON-BYTES</strong> &mdash; about an AArch64 or RISC-V instruction, because a word was emitted and read back and <em>nothing more</em>.</li>
                    <li><strong>QUOTED</strong> &mdash; about what a machine would do, with a document named.</li>
                </ul>
                <p>A label rendered two ways is not a label, and that is not a style rule: the provenance table in concept 6 prints a summary line that only adds up if the three spellings are used consistently, so a fourth spelling would break the count and the count is the point.</p>
                <p><strong>LLVM is the oracle here and never the dependency.</strong> The mission says a learner finishing this chain should be able to emit machine code for x86-64, AArch64 and RISC-V without depending on LLVM or any other backend. So clang is <em>read</em> &mdash; what does the best available compiler do with this function at this optimisation level &mdash; and compared against an allocator and a scheduler written here. The artifact prints what replaces each piece of LLVM <strong>by file name</strong>, because that list is the honest shape of the dependency:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/LLVM.s job/,/the machine we measure on/p'
  LLVM's job                        the file here that does it
  ---------------------------------  --------------------------------
  textual IR (parse and print)      cbir.py  (read_llvm_ir, above)
  the IR itself                      cbir.py  (Ins, is_reg, simulate)
  instruction selection              cbir.py  (isel_tree, PATTERNS)
  register allocation, linear scan   cbreg.py  (alloc_linear_scan)
  register allocation, colouring     cbreg.py  (alloc_colour)
  liveness and interference          cbreg.py  (build_interference)
  spill slots and reloads            cbreg.py  (pack_spill_slots)
  coalescing                         cbreg.py  (coalesce)
  instruction scheduling             cbsched.py (build_dag, list_schedule)
  the ENCODER                        cbenc.py  (enc_a64_madd, enc_x86)
  the machine we measure on          cbbench.c  (the timing instrument)
                </pre>
                </div>
                <p>And what is <em>still missing</em> is printed rather than implied, because that is the sentence a reader is most entitled to: <strong>no SSA construction and no PHI placement, no control-flow graph, no dominators, no loop structure, no peepholes, no compressed encodings, no exception frames and no debug information.</strong> The IR is straight-line, and the reason is in <code>cbir.py</code>&rsquo;s own docstring &mdash; instruction selection, allocation and scheduling are three questions about a <em>sequence</em> of operations, and a branch would put a fourth question in the middle of them.</p>
                <p>Say that last part to yourself before you go on, because it is the one that matters. <strong>A learner who copies clang&rsquo;s architecture will not be able to build one.</strong> Reading a good backend tells you what a finished one looks like. It does not tell you how to make one, and the ten files above are short enough to read in an afternoon.</p>
            </div>

            <div class="unit unit-example">
                <h2>What the six concepts measure</h2>
                <ul>
                    <li><strong><a href="/courses/compback/lessons/cb-ir">What an IR Is For, and What It Must Not Be</a></strong> &mdash; 24 min. MEASURED. One source, five levels, three targets. The ratio is the argument for an IR and it has to be read <em>both ways</em>: above 1.0 the backend deleted instructions the IR had, below 1.0 it inserted them. <code>-O0</code> gives <strong>1.106</strong> and <code>-O2</code> gives <strong>0.818</strong>, and the ratio <strong>is not monotonic</strong> &mdash; a number that only falls as the compiler gets better is a story. Then the half nobody states: at <code>-Os</code> RISC-V emits <strong>19 opcodes of which 17 are shared</strong>, and the two that are not are named. And at <code>-O2</code> all three targets agree on every opcode while the machine counts are still <strong>253, 190 and 207</strong>.</li>
                    <li><strong><a href="/courses/compback/lessons/cb-isel">Instruction Selection</a></strong> &mdash; 27 min. MEASURED, then MEASURED-ON-BYTES. A selector that dispatches on operand <em>kind</em> alone routes <strong>49 of 61</strong> instructions to the wrong machine form, and <strong>never fails once</strong> &mdash; it produces a program that computes a different number. So the receipt is a checksum: <strong>193715795505516148</strong> against <strong>193715795509322676</strong>. Then fusion, which is a property of the operand count in the encoding, seven AArch64 words re-encoded bit for bit with <strong>seven of seven</strong> agreeing, and the x86-64 half as a <em>refusal</em> rather than an approximation.</li>
                    <li><strong><a href="/courses/compback/lessons/cb-regalloc">Register Allocation</a></strong> &mdash; 28 min. MEASURED-ON-BYTES, and the centrepiece. Three allocators, three spill <em>policies</em>: <strong>58, 166 and 45</strong> spills. Two deliberate off-by-ones that fail in <strong>opposite directions</strong>. And the one measurement no other course here could take: four arms, four values forced through a stack slot, on a machine that runs. <strong>The cost of a spill is not linear</strong> &mdash; 1 and 2 are indistinguishable, only 4 separates.</li>
                    <li><strong><a href="/courses/compback/lessons/cb-sched">Instruction Scheduling</a></strong> &mdash; 26 min. MEASURED-ON-BYTES. Four legal orders of one 16-instruction DAG, and the only thing separating three of them is a <strong>tie-break</strong>. The kernel is chosen on purpose: a dependency chain gives a scheduler nothing to decide and prints three copies of the input. Then the trap &mdash; a scheduler with no alias analysis is <strong>fast and wrong</strong>, which is the worst combination this course found.</li>
                    <li><strong><a href="/courses/compback/lessons/cb-abi">The Backend and the ABI</a></strong> &mdash; 23 min. Not the convention &mdash; three courses already taught that &mdash; but the <strong>order</strong>: a backend must know the ABI <em>before</em> it allocates a register to anything, and that is not a matter of taste.</li>
                    <li><strong><a href="/courses/compback/lessons/cb-verify">Read a Backend&rsquo;s Decisions Back Out of the Bytes</a></strong> &mdash; 22 min. MEASURED. Four things recoverable from a stripped binary, of which <strong>three are counts and the fourth is an inference</strong> and is labelled as one. Then the boundary: 25 provenance rows with the count printed, 15 limits, 11 cannot-conclude beside 11 can, 18 retractions, four poisons.</li>
                </ul>
                <p>One number to carry into concept 1, and it is the sharpest thing in the course because it is the one number that <em>moves in both directions</em>:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/level   IR insns/,/IT IS NOT/p'
  level   IR insns   machine insns   IR/machine
  O0           260             235        1.106
  O1            99             117        0.846
  O2           207             253        0.818
  O3           207             253        0.818
  Os            99             103        0.961

  the ratio spans 0.818 to 1.106 across five levels, and it is NOT
  MONOTONIC: -O1 gives a SMALLER ratio than -O0 because -O0 emits
  MORE machine instructions than IR and -O1 emits fewer.
                </pre>
                </div>
                <p><code>-O1</code> gives a <em>smaller</em> ratio than <code>-O0</code>. Nobody writes that sentence. It is the whole reason the ratio is a measurement rather than a score.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course owes its neighbours</h2>
                <p>Nothing here is re-taught. The three ABIs are taught by three courses, the object-file and linking contract by four more, the encodings by three architecture courses, and the machine by three. Every id below was <strong>checked present against the served routes</strong> before a page was written &mdash; and the list is printed as text first, so the identical list can sit inside the artifact, where a link the toolchain cannot resolve would be a different claim from a link the server cannot serve.</p>
                <div class="hex-dump">
                <pre>  the three calling conventions, each taught in full by its own course
      /courses/x86abi/lessons/x86-calling
      /courses/a64abi/lessons/a64-aapcs
      /courses/rvabi/lessons/rv-calling
  what a backend's output has to satisfy, and what a linker does with it
      /courses/reloc/lessons/reloc-apply
      /courses/link/lessons/link-write-script
  the encodings this course hands to its encoder
      /courses/x86asm/lessons/x86-integers
      /courses/a64asm/lessons/a64-encoding
      /courses/rvasm/lessons/rv-encoding
  what the machine does with the order you choose, and why order is not
  the only thing that matters
      /courses/exe/lessons/exe-latency
      /courses/exe/lessons/exe-deps
      /courses/exe/lessons/exe-speculate
      /courses/mem/lessons/mem-latency
                </pre>
                </div>
                <p>Anchored, so a route check proves it rather than takes it on trust: <a href="/courses/x86abi/lessons/x86-calling">x86-calling</a>, <a href="/courses/a64abi/lessons/a64-aapcs">a64-aapcs</a>, <a href="/courses/rvabi/lessons/rv-calling">rv-calling</a>, <a href="/courses/reloc/lessons/reloc-apply">reloc-apply</a>, <a href="/courses/link/lessons/link-write-script">link-write-script</a>, <a href="/courses/x86asm/lessons/x86-integers">x86-integers</a>, <a href="/courses/a64asm/lessons/a64-encoding">a64-encoding</a>, <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a>, <a href="/courses/exe/lessons/exe-latency">exe-latency</a>, <a href="/courses/exe/lessons/exe-deps">exe-deps</a>, <a href="/courses/exe/lessons/exe-speculate">exe-speculate</a>, <a href="/courses/mem/lessons/mem-latency">mem-latency</a>.</p>
                <p><strong>The one overlap worth naming</strong> is <a href="/courses/rvasm/lessons/rv-encoding"><code>rv-encoding</code></a> and <a href="/courses/a64asm/lessons/a64-encoding"><code>a64-encoding</code></a>, which ship decoders. This course&rsquo;s encoder is checked <em>against</em> them rather than forked from them: <code>cbenc.py</code> builds AArch64 words from register numbers and a mask table, and then <code>a64asm</code>&rsquo;s own decoder &mdash; written for a different course, never having heard of <code>cbenc.py</code> &mdash; reads them back. Two programs written for different jobs agreeing is <strong>evidence</strong>; the same program agreeing with itself is a restatement. That distinction is worth more than any single word in this course.</p>
                <p>And the third thing this course owes its neighbours is a debt it does not pay: the <code>compiler</code> roadmap in <code>docs/courses-todo.md</code> has <strong>67 items</strong>, and this one ticks six. SSA, control-flow graphs, dominators, data-flow analysis and constant folding are all still open, and they are open for a reason that is printed rather than discovered: <strong>this course&rsquo;s IR is straight-line</strong>, so every live range in it is a straight interval and the loops-through-a-phi case that makes real allocation hard is not here at all.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break the selector and watch it compute a different number.</strong> <em>(Open <code>cbir.py</code>, find the <code>isel_kind</code> dispatch, and confirm that it reaches the pattern table by operand kind alone. Re-run <code>python3 compback.py --run</code> and watch the MISROUTED column: 10, 12, 13, 14, and 49 of 61 in total. Then look at the checksum line. <strong>Nothing crashes. Nothing raises. The program is simply a different program</strong>, and that is why the artifact prints a checksum beside the count and calls the checksum the receipt.)</em></li>
                    <li><strong>Make the live ranges half-open and watch the spill count IMPROVE.</strong> <em>(Call <code>cbreg.build_interference</code> with closed ranges, then without. On <code>kernel_c</code> the edge count goes from <strong>50 to 35</strong>. The graph is now easier to colour, so it spills fewer values, so it looks better. Every pressure at which the bug is invisible is a pressure at which the broken allocator looks GOOD &mdash; which is why the artifact&rsquo;s sweep goes down to pressure 1, the one pressure where nothing changes, and why every spill count in the course is held to a checksum and not to a comparison.)</em></li>
                    <li><strong>Re-run the timing on your own machine.</strong> <em>(<code>cd courses/compback/assets/samples &amp;&amp; ./build_samples.sh</code>. Read <code>cbbench.out</code> first, then section 10 of <code>compback.out</code>. Expect the <em>bands</em>, not the ticks: the exact ticks are in <code>cbbench.out</code> precisely because a report containing a clock reading cannot be byte-identical between two runs, and the file you are about to compare has to be. Then check whether 1-spill and 2-spill separate on your machine. <strong>If they do, the finding is about your machine and not about register pressure, and that is worth reporting.</strong>)</em></li>
                    <li><strong>Strip a real binary and try to read its allocator&rsquo;s decisions out of it.</strong> <em>(Compile something with <code>-O2</code>, strip it, and count the instructions, the memory operations and the distinct registers in one function, then the same function at <code>-O0</code>. The difference between the two builds is the allocator&rsquo;s work and nothing else&rsquo;s. Then read the <code>leaf</code> fingerprint on <a href="/courses/compback/lessons/cb-verify">concept 6</a> and notice which of the four numbers it prints is an inference rather than a count &mdash; and that the inference is the useful one.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86asm/lessons/x86-integers"><code>x86-integers</code></a> is where you already met <code>imul</code> as an opcode with three forms, and <a href="/courses/exe/lessons/exe-latency"><code>exe-latency</code></a> is where you met the idea that a dependency costs you. This course does not repeat either. It asks a different question about the same bytes: <strong>who decided this, and can you tell from the bytes alone?</strong></p>
                <p>Across the chain, the honest statement is that <a href="/courses/reloc/lessons/reloc-apply">the relocation course</a> is the next link and it does not care what you did here &mdash; which is the point of an IR. <a href="/courses/rvabi/lessons/rv-calling"><code>rv-calling</code></a> named the argument registers as a <em>convention</em>; <a href="/courses/compback/lessons/cb-abi">concept 5</a> asks what a compiler must know about them and <em>when</em>, and the answer changes the order of two passes. That is the kind of thing a course about conventions cannot tell you and only a course about backends can.</p>
                <p>Forwards out of this course, the thing to carry is not a technique but a habit: <strong>when a compiler produces a number you did not ask for, find out who decided it and print the decision beside the number.</strong> Section 10 of the artifact is the whole argument in one table &mdash; four programs, one checksum, four costs &mdash; and the reason it prints bands instead of ticks is the same reason this course prints counts beside every percentage. A number without its floor is not a result; it is a reading.</p>
                <p>And the last word belongs to the harness. <code>compback.out</code>, <code>run1.txt</code> and <code>run2.txt</code> are byte-identical, and <code>crosscheck.py</code> re-asks the <strong>171</strong> recorded claims rather than re-measuring them &mdash; because a harness that can re-measure can disagree with the artifact for reasons that have nothing to do with whether the artifact&rsquo;s sentences are still true, and then it teaches its reader to ignore it.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/compback/lessons/cb-ir">What an IR Is For, and What It Must Not Be</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
