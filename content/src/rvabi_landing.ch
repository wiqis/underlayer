// The RISC-V ABI, and the Register That Isn't There -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rvabi_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The RISC-V ABI, and the Register That Isn't There — Underlayer")
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
        <div class="lesson rvabi-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The RISC-V ABI, and the Register That Isn't There</h1>
            <div class="lesson-meta">4 concepts &middot; 2 modules &middot; 101 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Two architectures in this collection keep a place to put a comparison's result. x86-64 has EFLAGS and AArch64 has NZCV, and on both of them a conditional move is an ordinary instruction with an ordinary name &mdash; <code>CMOVcc</code>, <code>csel</code>. RISC-V has <strong>nothing</strong>. There is no register a comparison writes to and no bits a conditional move can read.</p>
                <p>That absence is usually mentioned in a sentence and then dropped. It is the spine of this course, because it explains three things at once: why AArch64 needs <code>csel</code> at all, why the same compiler emits a <em>branch</em> on one target and a <code>cmov</code> on another, and why the register table on <a href="/courses/rvasm/lessons/rv-encoding">the RISC-V encoding course</a> has no row for &ldquo;the condition&rdquo;.</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/^  riscv64 /,/^$/p'
  riscv64  blt(6), bge(4), c.beqz(5), c.bnez(1), bne(1)     branches                 17
  aarch64  csel(14), cneg(2)                                 conditional moves / sets  16
  x86-64   cmovel(3), cmoveq(3), cmovgel(1), cmovgl(3),
           cmovll(4), cmovsl(2)                               conditional moves        16
                </pre>
                </div>
                <p>Three targets, one file of ordinary C, one compiler, and <strong>three disjoint sets of mnemonics</strong>. Not &ldquo;mostly different&rdquo; &mdash; <strong>disjoint</strong>, and the artifact computes the intersection of every pair and prints it whether or not it is empty. A reader who wanted to be sure should know that the emptiness is a measurement.</p>
                <p>And there is a second half, which is the half almost nobody states, because stating it costs the sentence its punch. <strong>The absence of a flags register is not only a cost.</strong> Because <code>sltu</code> <em>writes a register</em>, the result of a comparison is <em>data</em>, and <code>min</code>, <code>max</code>, <code>clamp</code> and <code>abs</code> are expressible with no conditional move in the picture at all:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | sed -n '/THE CONSTRUCTIVE ROW/,/^$/p' | head -8
  function  bytes  instruction
  sign      4      srliw      a0, a0, 31
  sign      2      c.jr         ra
                </pre>
                </div>
                <p>That is the whole of <code>(x &lt; 0) ? 1 : 0</code> for a signed int, in <strong>one instruction</strong>. On x86-64 the same expression needs <code>SETL</code>, which does not exist; the compiler has to materialise a 0-or-1 in a register and then select on it. <a href="/courses/rvabi/lessons/rv-noflags">Concept 2</a> measures this on eleven functions.</p>
            </div>

            <div class="unit unit-model">
                <h2>What the toolchain can and cannot do here</h2>
                <p>Read this before the first number, because it bounds every number that follows. <strong>There are three absences on this host, and they are printed by the build script before it compiles anything.</strong></p>
                <div class="hex-dump">
                <pre>$ ./build_samples.sh --only | head -12
== 1. the toolchain, printed because a claim about a decoder needs one ==
  assembler:    clang version 21.1.8
  disassembler: Ubuntu LLVM version 21.1.8
  linker:       riscv64-linux-gnu-ld IS NOT INSTALLED
  emulator:     qemu-riscv64 ABSENT
  emulator:     spike ABSENT
                </pre>
                </div>
                <p>So: <strong>no RISC-V machine, no emulator, and not even a RISC-V linker.</strong> Nothing this course produces is ever linked, no <code>auipc</code>+<code>addi</code> pair is ever proved to land on the right address, and <strong>nothing is ever executed</strong>.</p>
                <p>That last one has a consequence this course has to be unusually honest about. <a href="/courses/x86abi/lessons/x86-verify">The x86-64 ABI course</a> measured a <strong>4.92x</strong> and a <strong>27.65x</strong> &mdash; on hardware it could run. This course has <strong>no counterpart for either number and does not invent one</strong>. The honest alternative to a ratio is not a smaller ratio: it is an instruction count and a byte count, plus the sentence that a count does not know whether the instruction is fast. Every cross-architecture table in this course says IT IS NOT A TIMING AND NOT A SPEEDUP in its own caption, because a reader who has just read those two numbers is looking for a ratio and a count is not one.</p>
                <p>What is <em>fully</em> measurable without hardware is the whole point: a compiler&rsquo;s <em>choice</em> is a static property of its output, and the output is bytes. The absence of a flags register, the register assignments, the argument offsets, the size of a spill &mdash; none of these need a CPU to be <em>true</em>, and every one of them needs a decoder to be <em>believed</em>.</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | tail -4
==========================================================================
END OF REPORT -- 12 sections, 12 limits, 12 retractions, 4 poisons.
==========================================================================
                </pre>
                </div>
                <p>And those twelve limits are the artifact&rsquo;s, not the course author&rsquo;s. They are enumerated and numbered, the four poisons are required to <em>move</em> the number each one claims to test or print <code>[POISON FAILED]</code> and stop, and the twelve retractions are asserted <em>as text</em> by a separate harness so that one of them cannot be quietly deleted. <a href="/courses/rvabi/lessons/rv-calling">Concept 1</a> is where the retractions start.</p>
            </div>

            <div class="unit unit-example">
                <h2>What the four concepts measure</h2>
                <p>Each page opens with a claim, runs the compiler, and then says what the measurement cannot show &mdash; and in this section that last part is a large fraction of every page, because the thing being measured is a choice and the thing a reader usually wants is a cost.</p>
                <ul>
                    <li><strong><a href="/courses/rvabi/lessons/rv-calling">The Calling Convention</a></strong> &mdash; 26 min. The contract, quoted from <code>riscv-cc</code> first and then tested: 44 of 44 integer argument placements agree, read out of the <em>relocation</em> each store carries rather than out of a text file. The row no summary gets right is the ninth <code>double</code>, which arrives in <code>a0</code> &mdash; an integer register &mdash; because the floating-point convention falls back to the integer one. And <code>m18</code>, nine integers then nine doubles, is the function that decides whether there is one argument counter or two.</li>
                    <li><strong><a href="/courses/rvabi/lessons/rv-noflags">No Flags Register, No Condition Codes, No CMOV</a></strong> &mdash; 27 min. The spine, the manual&rsquo;s own admission, and the three answers a compiler has when there is no <code>CMOVcc</code>: branch, mask, call. Then the three targets side by side, decoded.</li>
                    <li><strong><a href="/courses/rvabi/lessons/rv-registers">The Register File as Roles, Not Numbers</a></strong> &mdash; 24 min. <code>x0</code> is hardwired to zero, <code>gp</code> and <code>tp</code> are <em>unallocatable</em> and measured at zero writes, and there are two register <em>files</em> that share a spelling up to one character. The census is preceded by its own audit, because the first version of this reader counted 18 writes to <code>gp</code> over a corpus with none.</li>
                    <li><strong><a href="/courses/rvabi/lessons/rv-compressed-cost">What Compression Does to the ABI and to Disassembly</a></strong> &mdash; 24 min. A spill, a hot loop and a call/return pair, before and after the C extension &mdash; and the confound that makes most <code>-march</code> comparisons meaningless. Then the two-bit length rule, which is the whole of what a RISC-V disassembler has to get right.</li>
                </ul>
                <p>Two numbers to carry into the first page, both <strong>MEASURED-ON-BYTES</strong> and both about the specification rather than the compiler:</p>
                <div class="hex-dump">
                <pre>$ python3 rvabi.py --run | grep -E '44 of 44|corrobor|placed'
  44 of 44 integer argument placements agree with riscv-cc's table, at -O2.
                </pre>
                </div>
                <p>Forty-four, and the denominator is arithmetic rather than a convenience: <code>i1</code>&hellip;<code>i8</code> contribute 1+2+&hellip;+8 = 36 register-resident arguments and <code>i9</code> contributes 8 more. The ninth of each function is not in the table because <strong>there is no register for it</strong>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course owes its neighbours</h2>
                <p>A course that re-teaches a principle is a course that makes a reader learn it twice. Every link below was verified present before it was written, and what is borrowed is stated rather than implied.</p>
                <div class="hex-dump">
                <pre>  a contract exists at all, and why a callee saves registers
      /courses/x86abi/lessons/x86-calling   /courses/x86abi/lessons/x86-saved
  what a frame is for, and what a frame pointer is for
      /courses/x86abi/lessons/x86-frame     /courses/a64abi/lessons/a64-frame
  the same contract for AArch64, and the two independent
  argument counters as AArch64 states them
      /courses/a64abi/lessons/a64-aapcs
  the register file as a partitioned namespace elsewhere
      /courses/a64abi/lessons/a64-registers
  the ENCODING side of the C extension -- reserved code points,
  the seven permutations, the four assembler refusals
      /courses/rvasm/lessons/rv-compressed  /courses/rvasm/lessons/rv-encoding
  what an object file IS
      /courses/exe/lessons/exe-frontend
                </pre>
                </div>
                <p>The one thing this course is <em>about</em> and nothing else in the section is: <strong>what the absence of a condition-code register does to a compiler&rsquo;s options, counted.</strong> That is <a href="/courses/rvabi/lessons/rv-noflags">concept 2</a>, and it is the reason this course exists rather than another page of the calling convention.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break the artifact&rsquo;s reader and watch the audit catch it.</strong> <em>(In <code>rvabi.py</code>, find <code>_name_of</code> and delete the line <code>fp = False</code> under <code>is_mem(i) and label == 'rs1'</code> &mdash; the one that says the base of a floating-point load is in the integer file. Re-run <code>python3 rvabi.py --run</code> and look at section 7. Expect the register census to report writes to <code>gp</code> and <code>tp</code> over a corpus that contains none, and expect the audit printed immediately above the table to report a large disagreement count against the inherited decoder&rsquo;s own printed operands. Nothing crashes. Every register name in the output is a real register. <strong>This is the exercise the whole course is built for.</strong>)</em></li>
                    <li><strong>Remove a correction and confirm the poison fires.</strong> <em>(Run <code>python3 rvabi.py --section 10</code> and read the four DELTAs. Then edit the <code>Dec.MODELS32.insert</code> line for <code>m_shift_imm_fixed</code> out of the file, re-run, and expect the cross-check in section 9 to report 36 fewer named instructions and 36 more unmodelled ones. That is poison 1&rsquo;s claim, and it is the same number the file used to <em>retract</em> &mdash; R2 in section 11, which is why both are printed.)</em></li>
                    <li><strong>Write the <code>?:</code> you think needs a <code>cmov</code>, and then read the answer.</strong> <em>(Take <code>int clamp(int x, int lo, int hi)</code> returning <code>x &lt; lo ? lo : (x &gt; hi ? hi : x)</code>, compile it for all three targets, and count. RISC-V gives you <em>five branches</em> and spills for the arguments past <code>a7</code>. The count of branches in a function is not a style statistic &mdash; it is a measure of how much register pressure the machine has, and that is a better use of the number than a style guide is.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a> is where the compressed extension&rsquo;s <strong>second register encoding</strong> is measured &mdash; <code>rd'</code> is three bits at bits[9:7] and its value 0 means x8 &mdash; and <a href="/courses/rvabi/lessons/rv-registers">concept 3</a> is where that same three-bit field nearly produced 18 writes to <code>gp</code> in a register census. The trap is a neighbour&rsquo;s finding, used.</p>
                <p>Across architectures, <a href="/courses/a64abi/lessons/a64-cond">a64-cond</a> is the AArch64 version of <a href="/courses/rvabi/lessons/rv-noflags">concept 2</a> from the other side: there, the condition codes exist and the question is what you can do with them. Here the question is what you can do <em>without</em> them, and the answer turns out to include the single most useful instruction in the corpus.</p>
                <p>Forwards within the chain: this course sits between the <a href="/courses/rvasm">encoding</a> and nothing &mdash; it is the last RISC-V course, and the thing it hands to the next architecture is the shape of the question. <strong>Does this architecture have a place to put a comparison&rsquo;s result?</strong> On x86-64 and AArch64 the answer is yes and the interesting question is what to do with it. On RISC-V the answer is no, and the interesting question is what the compiler does instead &mdash; which is the question this course answers in bytes.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/rvabi/lessons/rv-calling">The Calling Convention</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
