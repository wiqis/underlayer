// The AArch64 Procedure Call Standard -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64abi_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The AArch64 Procedure Call Standard — Underlayer")
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
        <div class="lesson a64abi-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The AArch64 Procedure Call Standard</h1>
            <div class="lesson-meta">5 concepts &middot; 2 modules &middot; 125 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
            <p><a href="/courses/x86abi">The x86-64 ABI</a> came before this course and it is the exhaustive reference for the same subject on the other machine: which register argument four goes in, what the red zone is for, who saves what, and what a debugger reads when a frame is gone. It also measured things this course cannot, because <strong>this course has no AArch64 machine, no AArch64 emulator and no AArch64 linker on the build host</strong>, so not one instruction in it has been run and there is not a single timing in it.</p>
            <p>That is not a smaller course. It is a course about the parts of an ABI that are <em>contracts</em> rather than <em>behaviour</em> &mdash; and a contract, by definition, is checkable without executing anything. Every number here is a bit pattern, a count of bit patterns, an arithmetic identity over the immediates a compiler emitted, or a refusal from a real assembler. The artifact prints the two absences in its own section 1, <strong>before the first measurement</strong>, because a reader who meets a number and then meets the absence of the thing that would make it a runtime measurement learns a different lesson from one who meets them in the other order.</p>
            <p>What exists elsewhere in this collection is a set of neighbours that each own one edge of this subject and none of which own the middle. <a href="/courses/sec/lessons/sec-canary">The security course's stack-protector concept</a> explains why a canary is in the frame and links to the frame that holds it. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> explains what the loader puts at the bottom of the stack before <code>main</code> is entered. <a href="/courses/a64asm/lessons/a64-encoding">The AArch64 encoding course</a> teaches how to read the four bytes &mdash; and this course <em>imports its decoder</em> rather than rewriting it, adding the six instruction families the procedure call standard needs and that the encoding course had declared out of scope. Not one of them tells you that the stack alignment rule is <strong>16</strong>, and that is a question with a single answer and a great deal of history in it.</p>
            <p>So this course is the exhaustive AArch64 reference for the thing underneath all of those: <strong>the contract that two compilers agree on so that a function compiled by one can be called by code compiled by the other.</strong> It is the only course in this section whose distinctive idea is not about an instruction at all.</p>
            </div>

            <div class="unit unit-model">
                <h2>The idea this course is built on</h2>
            <p>An ABI is not a description. It is a <strong>contract between two compilers</strong>, and a contract between two compilers is the one kind of thing you can check mechanically. The specification says which register argument nine goes in; the compiler emits bytes; the two can be compared. That is not a reading of a manual. It is an <strong>audit</strong>, and this course ships one that runs.</p>
            <p>Here it is, on a corpus of twenty-five functions compiled four different ways, recovering not merely <em>which registers were occupied</em> but <em>which argument was in which register, by name</em>. Every argument has its own <code>volatile</code> global with its own immediate offset, so <code>#24</code> in the disassembly <em>is</em> argument three:</p>
            <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/36 of 36/,/^$/p'
  36 of 36 argument placements agree with C.9, C.13 and C.17, at every level.
                </pre>
            </div>
            <p>That is the shape of the result. The specification is the oracle and the compiler is the test subject, and the two agree at every optimisation level. The audit exists because of a distinction worth making once:</p>
            <div class="formula">
   WHAT AN AUDIT IS, AND WHAT A CENSUS IS NOT

   A census says: eight registers were written before that call.
   An audit says: argument ZERO was in x0, argument SEVEN
   was in x7, and argument EIGHT was at [sp + 0].

   The corpus makes that possible by giving every argument
   its own `volatile` global, so the disassembly names it,
   and by compiling at four optimisation levels, so that a
   claim about the ABI cannot be an artefact of one
   compiler's mood on one afternoon.
            </div>
            <p>And the answer it produces is not the one the plan for this course predicted in either of the two places it made a number: the first stacked argument is at offset <strong>zero</strong>, and the two banks have <strong>two independent counters</strong> rather than one shared sequence.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Two numbers, retracted, and why that is the course's reason for existing</h2>
            <p>The plan this course was scoped from, <code>docs/aarch64-section-plan.md</code>, said two things. Both were numbers rather than shapes, and both were wrong. They are printed here at the top because <strong>a course that leads with its corrections teaches a reader that its uncorrected numbers are probably not worth much either</strong>.</p>
            <ul>
                <li><strong>The AAPCS64 stack alignment rule is 16 bytes, not 128.</strong> The document says <code>SP mod 16 = 0</code> in both &sect;5.2.2.1 and &sect;5.2.2.2, and the SVE variant (<code>ARM_100986_0000_00</code>) says the same in two more places. The plan's <em>reason</em> &mdash; NEON's <code>LDP q0, q1</code> &mdash; is correct and <em>implies 16</em>, because the largest scale anywhere in the A64 load/store family is 16. <strong>A stated reason that does not imply the stated number is a reason invented after the fact.</strong> The 128 is the x86-64 red zone's size, and on AArch64 the number 128 turns up in a completely different place: Apple's platform ABI red zone, a region of memory that the AAPCS64 does not have at all.</li>
                <li><strong>A 32-bit write to an AArch64 register is one bit and not a second register file.</strong> Six <code>w</code>/<code>x</code> pairs of the same instruction, and every single one of them differs by exactly one bit: bit 31. The 32-bit form <strong>ZEROES</strong> the top half, so <code>mov w0, #-1</code> and <code>mov x0, #-1</code> are the same immediate in the same field and mean different things. A decoder that models <code>w0</code>&ndash;<code>w30</code> and <code>x0</code>&ndash;<code>x30</code> as two 32-register banks gets the register <em>numbers</em> right and the <em>semantics</em> wrong, <strong>silently</strong>: every value it computes is a valid value, and the wrong one is exactly what a 32-bit programmer would have got on a machine with two banks.</li>
            </ul>
            <p>Five more retractions, all printed in full by the artifact in section 11 and all <strong>asserted as text</strong> by the harness so they can be neither dropped nor edited into being right: the callee-saved vector registers are <strong>v8&ndash;v15 and not v0&ndash;v7</strong>; there is <strong>no rule</strong> about <code>r18</code> being preserved across a call that uses the stack, and clang uses <code>x18</code> <strong>zero times</strong>; <code>NZCV</code> is <strong>not</strong> a register that has to be saved, because it has no mnemonic at all; and the CFI shape this course was written to find &mdash; a function needing 3 rows at -O0 and 9 at -O2 &mdash; <strong>does not occur</strong>, because no function ever gains a row.</p>
            <p>A course that reports zero retractions on a subject this size has either not looked or has not been reading the documents it cites.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three results that are arithmetic rather than durations</h2>
            <p>This course's measurements are mostly not durations, and where a stopwatch would have given a number, a count gives a fact, and a fact does not move between runs.</p>
            <ul>
                <li><strong>AArch64 has no red zone, and the cost is two instructions.</strong> &sect;5.2.2.1 defines the region below SP as the <em>inactive region</em> and says no thread is permitted to access it, so every function that wants memory has to <em>ask</em>. 25 of 25 functions allocate a frame at -O0 and 14 of 25 at -O1 and above, against x86-64's 7 and then 5 for the same C. Hand-written, the same leaf function with a frame is 11 instructions on AArch64 and 8 on x86-64, and the entire difference is <code>sub sp, sp, #16</code> and <code>add sp, sp, #16</code>.</li>
                <li><strong>The unwind table is a fixed fraction of the code, and it does not shrink when the code does.</strong> <code>.eh_frame</code> is <strong>27.0%</strong> of <code>.text</code> at -O0 and <strong>42.3%</strong> at -O2, because the same 25 functions need the same 25 FDEs whether each is 34 instructions or 13. The cost of the second language is a function of the <em>number of functions</em>, not of the amount of code in them.</li>
                <li><strong>And a count of zero is a result.</strong> There is no mnemonic for "save the flags" on this architecture, so there is nothing to count: <strong>0</strong> <code>mrs</code>/<code>msr</code> of a flag register in the whole corpus, and <strong>0</strong> occurrences of the platform register <code>x18</code>. x86-64's answers are <code>PUSHFQ</code> and a stack discipline, and the previous course counted 271 <code>PUSHFQ</code> in 94 functions. The AArch64 answer is a sentence in a document saying the flags are undefined across a public interface.</li>
            </ul>
            <p>And two checkable impossibilities, which are the hardest kind of result to present. The <strong>first stacked argument is at <code>[sp + 0]</code></strong>, not <code>[sp + 8]</code> as on x86-64, because the return address is in <code>x30</code> and there is nothing on the stack to skip &mdash; which is why every offset in this course is 8 lower than the last one's. And <strong><code>str q0, [sp, #8]</code> is accepted by the assembler and does not become an <code>str</code></strong> &mdash; it becomes a <code>stur</code>, <code>0x3c8083e0</code>, a different encoding in a different bit field, because the scaled form cannot express an address that is not a multiple of 16 and the unscaled form can.</p>
            </div>

            <div class="unit unit-apply">
                <h2>What this course will not claim, and what is deferred</h2>
            <p>Printed in the artifact's own limits block (section 12) rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. The first two rows decide what every other row may say.</p>
            <ul>
                <li><strong>No timings, and none faked.</strong> There is no AArch64 machine, no emulator and no linker on this host, so nothing here is a duration, a fault, a throughput or a portability claim. <a href="/courses/x86abi/lessons/x86-verify">The x86-64 ABI course</a> measured a 4.92x and a 27.65x; this course has no counterpart for either number and does not invent one. The one cross-architecture comparison here &mdash; section 7 of the artifact &mdash; is a <strong>compile-time instruction count</strong> and says so in every table that prints it.</li>
                <li><strong>The alignment fault is not measured, and the page says so where you would expect it.</strong> The AAPCS64 writes "the hardware requires that <code>SP mod 16 = 0</code>". Whether a misaligned access through SP actually <em>traps</em> is decided by <code>SCTLR_ELx.A</code>, and a Linux EL0 process runs with that bit <strong>clear</strong> &mdash; so on this platform the requirement is a <strong>software contract a compiler enforces</strong>, not a hardware trap. The artifact measures the encoding of the instruction that reads the bit (<code>mrs x0, sctlr_el1</code> = <code>0xd5381000</code>) and does not claim the fault. A reader who took "requires" as "will trap" would be wrong about the platform this compiles for.</li>
                <li><strong>The two readers share a source tree.</strong> <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it, both from one LLVM. The cross-check establishes that this decoder and one other piece of software agree on what the bytes mean &mdash; <em>not</em> that either agrees with the silicon. There is no second AArch64 assembler on this host.</li>
                <li><strong>The decoder is a subset of <em>names</em>.</strong> Advanced SIMD and the floating-point conversions are not modelled: 6 words at -O2. They are <em>counted</em> and still contribute exactly four bytes each, which is the one thing a fixed-width encoding gives you for free.</li>
                <li><strong>The architectural reference manual was not consulted.</strong> The register and stack claims are quoted from the AAPCS64 (release 2025Q4, issued 23 January 2026) and the SVE variant with section numbers; the encoding claims are read out of an assembler and cross-read against a disassembler. A claim that would need the manual &mdash; the fault behaviour above &mdash; is marked as not measured rather than argued from memory.</li>
                <li><strong>Twenty-five functions is a sample, not a census.</strong> Every count is a count <em>of this corpus</em> and the tables say so. The register <em>assignment</em> is the specification's and will not change; the frame sizes, the row counts and the instruction counts are the compiler's and will.</li>
            </ul>
            <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 166 checks against the shipped <code>a64abi.out</code> &mdash; which needs no toolchain at all &mdash; then change one guard in <code>a64abi.py</code>, any guard, one bit, and make the poisoned cross-check in section 10 move by name: the named count must fall from 2078 to 1859 and the disagreement count must rise from 0 to 304.</em> A check that has never been seen to fail is a check with no reason to be believed, and this course's cross-check failed <strong>five times for five real reasons</strong> before it reached 0.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
            <p>Before. <a href="/courses/a64asm/lessons/a64-encoding">The AArch64 encoding course</a> is the direct prerequisite, and this course's artifact <strong>imports its decoder</strong> and prepends six models to it, because the procedure call standard needs to name <code>stp q0, q1</code> and a decoder that cannot name it cannot check the alignment rule. <a href="/courses/x86abi/lessons/x86-calling">The x86-64 ABI course</a> is the sibling reference: this one owes the exhaustive AArch64 half and that one owns the exhaustive x86-64 half, and <a href="/courses/sec/lessons/sec-canary">the security course</a> owns the <em>why</em> a frame gets a canary in it. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where the stack is first set up, before any of the rules in this course have a chance to apply.</p>
            <p>Forward, and the practical weight is in a compiler backend. <strong>The two things a backend must get exactly right are the two things nobody thinks about</strong>, because both are invisible in the source: a mixed C call with nine integers and nine doubles allocates sixteen register slots and two stack slots in an order that comes from the parameter list rather than from either bank, and a 32-bit write that was supposed to preserve the top half silently destroys it. Neither mistake produces a diagnostic, and both produce plausible output.</p>
            <p>Outward, and the collection's shape is the argument. <a href="/courses/a64asm/lessons/a64-verify">The encoding course's two-reader cross-check</a> is the same experiment on a decoder, and it retracted its own 100% twice; this course is a third instance of the same idea applied to a <em>compiler</em> rather than to bytes. The next courses in this section are the ones that need silicon, and this one is the last that does not: whether a <code>stp</code>/<code>ldp</code> pair is free, whether a misaligned store traps, whether the branch predictor likes a link &mdash; all of those are somebody else's course, and the artifact's section 12 names every one of them.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/a64abi/lessons/a64-aapcs">The Calling Convention, and the Number That Was 128</a></span>
                <span>End of The AArch64 Procedure Call Standard &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
