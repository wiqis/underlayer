// The x86-64 Data Path: Atomics, Ordering and Vectors — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86simd_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The x86-64 Data Path: Atomics, Ordering and Vectors — Underlayer")
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
        <div class="lesson x86simd-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The x86-64 Data Path: Atomics, Ordering and Vectors</h1>
            <div class="lesson-meta">6 concepts &middot; 2 modules &middot; 154 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is</h2>
            <p>Two neutral courses already taught the principles. <a href="/courses/simd/lessons/simd-width">The SIMD course</a> measured the width experiment &mdash; that a wider vector is not automatically faster &mdash; and <a href="/courses/smp/lessons/smp-atomic">the multiprocessor course</a> measured what a data race costs and named the store buffer as the mechanism. Both taught x86-64 as the <em>running example</em>. The section plan is explicit about what follows from that: <em>&ldquo;the comparison lives in the neutral courses; the depth lives in the per-arch ones.&rdquo;</em></p>
            <p>So this course re-derives no principle. It is the <strong>exhaustive x86-64 reference</strong> for five roadmap items, and it is built the way the other three x86-64 courses in this section are built: the artifact first, the prose second, and every claim in every page printed by a program that a harness re-checks. There are no exceptions to that rule, including in the places where an exception would be reasonable.</p>
            <p>Here is the whole atomic set, forty-two arms over three instruments, each arm two threads on two pinned cores with a barrier and a reset before every one:</p>
            <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  CNT  |/,/bt  \$0/p'
  CNT  | instruction              | bytes                |       target |          got | verdict
  CNT  | add $1,        no LOCK   | 83 00 01             |       120000 |        78548 | NOT ATOMIC
  CNT  | add $1,        LOCK      | f0 83 00 01          |       120000 |       120000 | ATOMIC
  CNT  | inc,           no LOCK   | ff 00                |       120000 |        63066 | NOT ATOMIC
  CNT  | inc,           LOCK      | f0 ff 00             |       120000 |       120000 | ATOMIC
  CNT  | dec,           no LOCK   | ff 08                |  4294847296 |  4294900952 | NOT ATOMIC
  CNT  | dec,           LOCK      | f0 ff 08             |  4294847296 |  4294847296 | ATOMIC
  CNT  | xadd $1,       NO PREFIX | 0f c1 01             |       120000 |        77812 | NOT ATOMIC
  CNT  | xadd $1,       LOCK      | f0 0f c1 01          |       120000 |       120000 | ATOMIC
  CNT  | load+add+XCHG            | mov;add;87           |       120000 |        80634 | NOT ATOMIC
  CNT  | load+add+LOCK XCHG       | mov;add;f0 87        |       120000 |        83096 | NOT ATOMIC
                </pre>
            </div>
            <p>Two rows of that table are the course. <strong><code>lock inc</code> is exact</strong> &mdash; the draft said it was not, and the reason it is exact is the only interesting reason in the whole instruction set: <code>INC</code> does not disturb the <code>CARRY</code> flag, so it is the one read-modify-write that can carry the prefix without a special case in the silicon. And look at the last two rows, which are the other half: a <code>mov</code>, an <code>add</code> and a bare <code>XCHG</code> with a memory operand <strong>loses updates, and adding <code>lock</code> to that <code>XCHG</code> does not help</strong> &mdash; because by then the damage is in the two instructions before it. The implicit-lock rule is real and the last two rows are the reason it is not the whole story.</p>
            </div>

            <div class="unit unit-model">
                <h2>The idea: a verdict is not a number</h2>
            <p>Almost every table in this course is a <strong>verdict</strong> rather than a measurement, and the distinction is not a stylistic one. A verdict is exact and does not move between runs; a number is neither, and on a machine with twelve logical CPUs and other work on it, a number moves.</p>
            <div class="formula">
   SO THE HARNESS ASSERTS SETS, NOT VALUES,
   and the reason is worth stating once.

   A VERDICT   atomic / not atomic.
               Which of the forty-two arms
               land in each set.  Exact.

   A COUNT     64435 of a possible 120000.
               Moves by thousands between runs
               and is not a claim about anything.

   Forty-two verdicts survive a reboot.
   Forty-two counts do not, and the ones
   that survive are the ones nobody was
   looking at.
            </div>
            <p>That is why the alignment result in the first concept is asserted as a <strong>partition</strong> rather than as a threshold. Ten vector loads, probed one per forked child at an address eight bytes off a cache line, and the ten divide cleanly: five die with <code>SIGSEGV</code> and four return. The claim is not &ldquo;misaligned loads are slower&rdquo;. The claim is <em>these five fault, and these four do not, and that is all of them</em>.</p>
            <div class="formula">
   THE ALIGNED SET, and it is a SET and
   not a rule of thumb.

   FAULT AT +8     return at +8
     vmovapd load    vmovupd load
     vmovapd store   vmovupd store
     vmovdqa load    vmovdqu load
     movaps load     movups load
     vmovaps load
     vmovdqa load    <- the VEX form of
                       the third row above

   Both vmovdqa rows appear, because the
   legacy-prefixed and the VEX-prefixed
   form are two PROBES that share a
   spelling.  That is the point of the
   next paragraph.
            </div>
            <p><strong>VEX did not remove the alignment requirement.</strong> The draft for this course asserted that it did &mdash; it is the commonest claim about AVX &mdash; and the measurement says otherwise: the <code>vmovaps</code> and VEX <code>vmovdqa</code> rows fault exactly like the legacy ones. What AVX actually relaxed is the <em>fused memory operand</em> and the move instructions' handling of unaligned <em>stores</em>, which is a different and much smaller claim than the one everybody quotes.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The correction, and it is the course's reason for existing</h2>
            <p>This course was drafted with a central claim about the direction flag, and the claim was wrong by one bit number in a way that makes it more useful than the right one would have been.</p>
            <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/^  EFLAGS/,/^$/p'
  EFLAGS as read by PUSHFQ      0x0000000000000202
    bit  0 CF                 0
    bit  2 PF                 1
    bit  6 ZF                 0
    bit  9 IF                 1
    bit 10 DF, THE DIRECTION  0
    bit 11 OF                 0
    bit 16 RF                 0
    bit 18 AC                 0
    bit 21 ID, NOT DIRECTION  0
  R1. "The direction flag is EFLAGS bit 21."  RETRACTED.
      Bit 10 is DF.  Bit 21 is the ID flag, whose entire
      job is to be a bit software can set on a processor
      that has CPUID and cannot on one that does not.
            </pre>
            </div>
            <p>The draft said the direction flag is bit 21. It is <strong>bit 10</strong>, and the artifact reads the whole register with <code>PUSHFQ</code> and prints every bit it names rather than asserting the one it remembered. Bit 21 is real and it is the <em>ID</em> flag, and the two have nothing in common. That history is worth a paragraph of its own in the fifth concept, because it explains a gap in the instruction set &mdash; there is no <code>NOID</code> to go with <code>ID</code> &mdash; that most readers have never noticed.</p>
            <p>And the direction flag is not a curiosity, because here is what it costs:</p>
            <div class="hex-dump">
                <pre>$ ./vecdump | sed -n '/bytes |   DF=0/,/^  ---/p'
  bytes |   DF=0  |   DF=1  | ratio  | ticks/byte up | ticks/byte dn
  ------+----------+----------+--------+--------------+--------------
     16 |       23 |      184 |   8.00 |       1.4375 |      11.5000
    256 |       23 |      253 |  11.00 |       0.0898 |       0.9883
   1024 |       46 |      782 |  17.00 |       0.0449 |       0.7637
   4096 |       92 |     2875 |  31.25 |       0.0225 |       0.7019
            </pre>
            </div>
            <p><code>rep movsb</code> running backwards is <strong>8.00&times; slower at sixteen bytes and 31.25&times; slower at four kilobytes</strong>. The ratio is not a constant &mdash; it grows, and the growth is the finding. A fixed overhead would give a constant ratio, so what the growing column measures is a per-byte cost that the downward direction pays and the upward one does not, which is a hardware counter, and the artifact marks the mechanism <strong>INFERRED</strong> because there is no counter on this machine to read.</p>
            <p>There are <strong>twenty-four retractions</strong> in this course. All of them are printed by the artifact in its section 7, all of them are asserted as text by the harness so a taken-back claim can be neither quietly dropped nor edited into being right, and not one of them is a mistake about how a computer works. Every one is a mistake about what a number is, what a field is, or what an instrument does.</p>
            </div>

            <div class="unit unit-example">
                <h2>Three results that could not have been found any other way</h2>
            <ul>
                <li><strong>A round trip agreed with itself and was still wrong.</strong> The encoder in the previous course in this section round-tripped 28 of 28 through a decoder built from the same table and certified itself &mdash; and it had the two-byte VEX field order wrong, so it was emitting legal bytes for a different instruction. That is the worst kind of wrong: no trap catches it and no length surprises you. This course's encoder is cross-checked against <code>objdump</code>, a second reader that was not written from the table, and all thirty rows agree.</li>
                <li><strong>The cross-check itself was wrong, and it was believed for a full run.</strong> The first version of the second reader counted <code>objdump</code>'s section header as the first instruction row, so every row was compared against its <em>neighbour's</em> text. It reported 28 disagreements out of 30 &mdash; exactly the shape a genuinely broken encoder produces &mdash; and the encoder was perfect. That is retraction 23, and the lesson is the one worth keeping: <strong>a cross-check that disagrees with almost everything is as suspicious as one that agrees with everything.</strong> The two failure modes a misaimed check can have look nothing like each other and are equally wrong.</li>
                <li><strong>The store-only floor came out <em>above</em> the thing it was a floor for, in every run.</strong> That is impossible, and the file printed the ratio instead of objecting. The instrument was taking a thread id and ignoring it, so both threads were hammering the same two words; and the first fix &mdash; indexing by id &mdash; was not enough, because <code>aligned(64)</code> aligns the <em>array</em> and not each element, so the two words were still eight bytes apart in one cache line. It took three attempts, and the layout is now printed above the table and asserted by the harness. That is retraction 24, and it is the one a reader should take furthest.</li>
            </ul>
            <p>And one result is a measurement of an <em>absence</em>, which is the hardest kind to present. This machine cannot execute <strong>one instruction</strong> in the third concept: <code>CPUID.7.0:EBX</code> reads F, DQ, CD, BW and VL as five zeros, and the three <code>XCR0</code> state bits are three more. So every claim about a ZMM register is marked <code>QUOTED</code>, and what <em>is</em> measured is that the bytes decode &mdash; which needs no silicon at all.</p>
            </div>

            <div class="unit unit-apply">
                <h2>What this course will not claim, and what is deferred</h2>
            <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. There are <strong>no event counts of any kind</strong>:</p>
            <ul>
                <li><strong>No event counter of any kind.</strong> <code>perf_event_paranoid</code> is 4 on this machine, and the core and L3 performance monitors are both present &mdash; <a href="/courses/x86sys/lessons/x86-pmu">the third x86-64 course measured exactly that</a>. Every duration in this artifact is a <em>duration</em>. A duration bounds a count without measuring it, and every mechanism named anywhere in this course is therefore marked <strong>INFERRED</strong>.</li>
                <li><strong>No AVX-512.</strong> Not a missing feature bit and not a missing measurement: the whole of the third concept is quoted, and the one thing the artifact does with it is decode its bytes. Settling it needs a Skylake-SP or a Zen 4.</li>
                <li><strong>One misalignment, at eight bytes.</strong> That is the case that matters and the case that ran. Nothing here says what a 4-byte-off address does for a 32-byte load, and the reason is a failed experiment rather than a missing one.</li>
                <li><strong>Whether any locked instruction asserted <code>LOCK#</code> on the bus.</strong> The old cache-coherent protocol is gone and the current one has no pin to assert; the course quotes the SDM and measures the atomics, which is the part that is still true.</li>
                <li><strong>The store buffer's depth.</strong> The mechanism is named, the depth is not measured, and the seven-arm ping-pong cannot measure it because it is bounded by the two floors it is printed between.</li>
                <li><strong>Why the downward string direction is slower.</strong> Printed as a limit rather than a mechanism, because the number and the reason are separable and only the number is measured.</li>
                <li><strong>A second run's ratios.</strong> The build script runs the artifact three times and cross-checks a fourth, and it does not average them: three runs of a contended two-core loop are three observations, not one measurement with error bars.</li>
                <li><strong>AArch64, RISC-V, and every other architecture.</strong> Quoted, not run, and deliberately absent. <a href="/courses/simd/lessons/simd-width">The SIMD course</a> and <a href="/courses/smp/lessons/smp-atomic">the SMP course</a> own the comparison; this one is the x86-64 reference.</li>
            </ul>
            <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 266 checks, then break a positive control on purpose. Delete the header-skip in <code>load_dis()</code> so <code>objdump</code>'s section header is counted as row 0 again, and watch group I report 28 disagreements out of 30 for an encoder that is entirely correct.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
            <p>Before. <a href="/courses/simd/lessons/simd-width">The SIMD course's width concept</a> measured that a wider vector is not automatically faster &mdash; and this course deliberately does <em>not</em> repeat that experiment, which is the discipline the section plan asks for. It measures alignment, the three-operand form and <code>vzeroupper</code> instead. <a href="/courses/smp/lessons/smp-atomic">The SMP course's atomic concept</a> owns the principle and the <a href="/courses/smp/lessons/smp-ordering">ordering concept</a> owns TSO as a model; both are measured there on this machine and both are quoted here. <a href="/courses/x86asm/lessons/x86-vex">The assembly course's VEX concept</a> already measured the three-operand form at 1.00&times;, and the second concept here inherits that number and re-measures it rather than re-arguing it.</p>
            <p>Forwards. The two modules are the data path in the order the CPU walks it: first the <strong>vectors</strong> &mdash; what the registers are, what the encoding changed, and what the hardware can execute here &mdash; then <strong>ordering</strong>, which is the same registers used by two cores at once. The third concept is the hinge between them, because it is the only one where a claim had to be demoted from measured to quoted, and knowing <em>which</em> claims those are is the transferable part.</p>
            <p>Outward, and the chain closes. <a href="/courses/x86sys/lessons/x86-boundary">The third x86-64 course's last concept</a> proved that <code>CR4.OSXSAVE</code> cannot be read from ring 3, and this course's first section reads the <em>same</em> bit by inference: <code>XGETBV</code> returns, and <code>XGETBV</code> is <code>#UD</code> without it, so the bit is set &mdash; a measurement of a bit the process may not read, made by using the thing the bit gates. That is the whole of the last concept in the fourth course of the next section too, and it is why the three courses are one course.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/x86simd/lessons/x86-sse">SSE and SSE2: The XMM Register and the Alignment Split</a></span>
                <span>End of The x86-64 Data Path &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
