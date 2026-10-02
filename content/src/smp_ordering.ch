// Multiprocessor Architecture — Concept 4: a duration is not a guarantee
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_ordering() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Duration Is Not a Guarantee — Underlayer")
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
            <h1>A Duration Is Not a Guarantee</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The instruction in the last concept makes two promises. <strong>Atomicity</strong> &mdash; the read-modify-write happens as if no other thread were looking at that location &mdash; is what the last three concepts have been about. <strong>Ordering</strong> &mdash; nothing moves across the instruction that would let another core observe the stores on either side in the wrong sequence &mdash; is the second promise, and on x86-64 it comes attached to the first whether or not anyone wanted it.</p>
                <p>This concept separates them, and its real subject is not the fence. Its subject is <strong>the difference between the two questions you can ask about a fence, and the fact that this course can only ask one of them.</strong> You can ask how long it takes. You cannot ask whether it is correct &mdash; and that is not a limitation of this artifact or of this machine. It is a property of what a timing measurement <em>is</em>, and the argument for it takes about four lines and is worth more than the number.</p>
                <p>There is a reason to care beyond tidiness. Almost everything in concurrent programming that goes wrong is an ordering bug: a lock-free algorithm that reads a half-updated structure, a message that arrives before its payload, a flag that is set before the data it describes. <strong>Those bugs cannot be found by measuring how fast anything runs</strong>, and a course that measures a fence's duration and moves on is quietly implying that the two are connected. They are not. This one is about the gap, and the gap is named in the artifact rather than left in the margins.</p>
                <p>The lesson generalises past concurrency. <em>A duration is not a guarantee</em> applies to every guarantee that is expressed as &ldquo;never happens&rdquo; rather than as a property of an output: that a compiler will not delete a volatile access, that a page will not be freed twice, that an overflow will not wrap. Timing tells you about cost. It tells you nothing about correctness, and where the two are conflated you get a green test suite.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: a store, a flag, and a load</h2>
                <p>The loop is the smallest message-passing pattern there is, and it is deliberately the weakest one:</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/iterations, store data/,/The two loops COMPUTE/p'
   2000000 iterations, store data / store flag / load flag:
      no fence           1.3 ns/iter
      mfence            34.3 ns/iter    25.86x

   for (long i = 0; i &lt; N; i++) &#123;
       g_data = i;
       &#123; with fence: &#125; __asm__ volatile("mfence" ::: "memory");
       g_flag = 1;
       g_sink = g_flag;
       if (g_sink == 12345 || g_data == -1) g_flag = 0;
   &#125;
                </pre>
                </div>
                <p>One thread stores a value, then stores a flag saying the value is there, then loads the flag back. <strong>What the fence orders is the two stores against each other</strong> &mdash; it says a reader that sees the flag set will also see the data. Without a fence on a machine that reorders stores, the reader can see <code>flag&nbsp;=&nbsp;1</code> and then read a stale <code>g_data</code>, which is a torn message: the code says the payload is ready and the payload is not.</p>
                <p>Three details decide whether this loop measures what it claims, and all three are things that have gone wrong in earlier courses:</p>
                <div class="formula">
   g_data, g_flag, g_sink are `volatile`, so the
   COMPILER cannot delete them and cannot merge two
   stores to the same object.

   the asm carries a "memory" clobber, so the
   COMPILER cannot move the volatile store past the
   flag store either.  This is the whole of what the
   loop is testing, and it is why a plain C loop
   would have measured the compiler rather than
   the CPU.

   without the fence the loop has an `asm volatile
   ("" ::: "memory")` in the same place, so both
   arms have the same barrier effect and the ONLY
   difference is the mfence instruction itself.
                </div>
                <p>The third point is the one that makes this a controlled experiment rather than two unrelated loops. <strong>A common version of this measurement puts the fence in one arm and nothing in the other, and the compiler's freedom to move the volatile stores is then a difference between the arms on top of the fence.</strong> Here both arms carry a memory clobber, so the compiler is held still on both sides and the fence is the only variable left.</p>
                <p>And note the timing method: this section uses <code>clock_gettime(CLOCK_MONOTONIC)</code>, not the TSC, and divides by the iteration count to get a nanosecond figure. The result is an absolute time rather than a ratio, which is a deliberate change from the rest of the artifact &mdash; and it is allowed here because the number being claimed is a comparison between two numbers in the same loop, not a comparison with anything on another machine.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: expensive, and irrelevant to the answer</h2>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/The two loops COMPUTE/,/That is why the fence/p'
   The two loops COMPUTE THE SAME ANSWER.  The fence cannot change
   what this program computes on x86-64, and it is not cheap.  That is
   not an argument against the fence: it is an argument for knowing WHY
   you have one.  x86-64's memory model is already strong enough that
   an ordinary store then an ordinary load cannot be reordered past
   each other.  A weaker architecture -- and a compiler that does not
   know which architecture it is generating for -- needs the fence to
   make that true, and the SAME SOURCE needs it on one and not on the
   other.  That is why the fence is in the source and the cost is not.
                </pre>
                </div>
                <p>34.3 ns against 1.3 ns: the fence costs more than <strong>twenty-five times</strong> the loop it sits in, and it changes nothing about what the loop computes. On this machine the memory model is already strong enough that an ordinary store followed by an ordinary load cannot be reordered past each other, so the fence is pure overhead here.</p>
                <p>Read that sentence twice, because the <em>34.3</em> and the <em>twenty-five times</em> are different numbers and only one of them is the finding. <strong>The nanoseconds are stable; the multiple is not.</strong> Across the three recorded runs <code>mfence</code> came out at 34.3, 33.6 and 34.9 ns/iter, while the unfenced loop moved between 1.1 and 1.3 ns/iter &mdash; so the factor moved across a range of about 26 to 31 while the thing being factored did not. That is the same pattern as the atomic section, and it has the same lesson: quote the stable number, and treat any ratio whose denominator is a plain loop on a busy guest as a description of the day you ran it.</p>
                <p>So the fence is not free, and the fence is not wrong. <strong>What is wrong is a course &mdash; or a compiler, or a reviewer &mdash; that reaches either conclusion from the number alone.</strong> The correct reading of this table is: on x86-64 the explicit fence is redundant, and it is expensive; therefore a redundant fence in the source is a performance bug and a missing fence on a weaker target is a correctness bug, and <em>both statements are about a different machine</em>.</p>
                <div class="hex-dump">
                <pre>   That is why the fence is in the source and the cost is not.
                </pre>
                </div>
                <p>Put that the other way round and it is a rule for portable code: <strong>write the fence, and expect the compiler to remove it where the target does not need it.</strong> An explicit <code>atomic_thread_fence(seq_cst)</code> in the source is documentation and insurance; the cost is paid only on the targets where the insurance is required. A hand-rolled <code>asm volatile("mfence")</code> in portable source is not that, because it is a x86 instruction spelled into the middle of a program that may be compiled for something else &mdash; and <a href="/courses/smp/lessons/smp-three">on AArch64 and RISC-V there is no mfence at all</a>, because there the fence is expressed by the access's own mode or by chosen edges.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the four things this section cannot do</h2>
                <p>This is the part of the artifact that is worth more than the part above it, so it is printed as a list rather than a paragraph:</p>
                <div class="formula">
   * That a fence is CORRECT.  Correctness of an ordering
     guarantee is not a duration.  A loop that runs in
     the same number of nanoseconds with and without
     the fence is the OBSERVABLE RESULT of both being
     correct, and it is also what you would see if the
     fence were a no-op.  This measurement cannot tell
     those apart, and neither can any timing
     measurement on any machine.

   * That the compiler did not reorder the stores
     anyway.  The `volatile` and the memory clobber
     above make the question moot here, but a fence in
     C source says nothing to a compiler that is
     compiling for a machine with a weaker model
     unless the fence is an intrinsic with the right
     semantics for THAT target.

   * How many fences were ACTUALLY executed.  A
     compiler is allowed to delete a redundant one,
     and on x86 it usually does.  The number above is
     an upper bound on what the source asked for.

   * The order in which two CORES observed anything.
     That is a property of a program the user cannot
     write, and this course does not attempt it.
                </div>
                <p>Each of those four is a different kind of not-knowing and they are worth separating, because only the first is fundamental.</p>
                <p><strong>The first is a logical impossibility, not a missing instrument.</strong> Consider the two hypotheses: (a) the fence works, and the loop runs in the same time with and without it; (b) the fence was compiled to nothing at all, and the loop runs in the same time with and without it. Both predict the observation. A measurement cannot distinguish two hypotheses that make identical predictions, and buying a performance counter would not help, because the counter measures the same observable. <strong>You could make the fence observable &mdash; by removing it on a weakly-ordered target and watching the program produce wrong answers &mdash; but then you are measuring a different program on a different machine, which is precisely what this course says it is not doing.</strong> Establishing correctness of an ordering requires either a formal model or a bug, not a stopwatch.</p>
                <p><strong>The second is a language problem, not a hardware one.</strong> A fence written as a compiler intrinsic carries the target's semantics. A fence written as an x86 instruction is an x86 instruction, and a compiler targeting AArch64 has no way to know the author meant &ldquo;order my stores&rdquo; rather than &ldquo;emmit <code>mfence</code>, which does not exist here&rdquo;. The volatile and the clobber in this artifact's loop make the question moot because the experiment is single-target by construction; in real portable code the intrinsic is the entire answer.</p>
                <p><strong>The third is an upper bound and the artifact labels it as one.</strong> 34.3 ns/iter is a claim about what the source asked for. It is not a claim about what the CPU executed, because a compiler is permitted to delete a redundant fence and on x86 it usually does. This is a small thing in isolation and a large thing in a course: <strong>a measurement of your own source is a measurement of a proposal, not of the machine.</strong></p>
                <p><strong>The fourth is the interesting refusal.</strong> &ldquo;The order in which two cores observed X&rdquo; is a property of a program that would require pinning an observation onto a specific event in each core's history, with no atomicity on the act of reading the other core's history. <a href="/courses/priv/lessons/priv-doors">The privilege course</a> made the same refusal from the other side &mdash; a ring-3 process cannot see the saved instruction pointer &mdash; and the two refusals are the same shape: <strong>the quantity is real, it is what the hardware actually did, and it is not reachable from user mode.</strong></p>
                <div class="hex-dump">
                <pre>   A course that cannot measure the second most important thing in
   concurrent programming should say so here rather than quoting the
   architecture's ordering table as though it were a result.  The
   ordering table is in the ISA course's future and in the privileged
   specification; it is a CONTRACT, and this is an observation.
                </pre>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the fence measurement, then break the control and see what happens.</strong> Delete the <code>asm volatile("" ::: "memory")</code> from the <em>unfenced</em> arm only, so the compiler is free to reorder the volatile stores there but not in the other arm. <em>(Expect the unfenced arm to get <em>faster</em>, not slower &mdash; you have just measured the compiler, not the CPU. If the two arms come out the same, check the assembly before you conclude anything: the volatile stores are both required to exist and the reordering freedom on this target is small, so the honest expectation is &ldquo;little or no change&rdquo; and the value of the exercise is seeing which.)</em></li>
                    <li><strong>Write down, for one real program of yours, which fences are load-bearing.</strong> For each atomic operation or fence, ask: if this program were compiled for AArch64 with a weak memory model, would removing this break it? <em>(Expect roughly half your answers to be &ldquo;no&rdquo; and the removals to be tempting, because you have just measured that an explicit fence costs twenty-five times the loop it is in. Hold the line: portable source pays for the weak target, the compiler removes the cost on the strong one.)</em></li>
                    <li><strong>Prove the first limit rather than reading it.</strong> Write down hypothesis (a), the fence works and the loop runs the same either way, and hypothesis (b), the fence was optimised away and the loop runs the same either way. Then write down the observation the table actually reports. <em>(Expect to find that you cannot invent any third experiment on this machine whose result distinguishes them. That inability is the finding, and it is the strongest argument in this course for keeping a formal memory model somewhere in a compiler project even when nobody has the hardware to test it on.)</em></li>
                    <li><strong>Find a real fence and disassemble it.</strong> <code>objdump -d</code> a binary that uses <code>std::atomic</code> with <code>seq_cst</code>, on x86-64 and, if you can, on AArch64. <em>(Expect the x86 <code>seq_cst</code> store to be a plain <code>xchg</code> and the relaxed one to be a plain <code>mov</code> &mdash; the same instruction, because the compiler has nothing to choose between. Expect the AArch64 relaxed add to be <code>ldadd</code>-family and the seq_cst one to be surrounded by explicit acquire/release or barrier instructions. This is the concrete form of R5, and seeing it in a disassembly is worth more than reading about it twice.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-atomic">the atomic concept</a> established that the <code>lock</code> prefix costs 2.54&times; a plain store with nothing to lock against, and attributed it to the barrier the prefix implies. <strong>This concept is the reason that attribution is right, and the reason it cannot be verified from a timing table.</strong> Read them together: the previous one measured a price for a guarantee, and this one says the guarantee itself is unmeasurable here. A course that quoted 2.54&times; without this section would be leaving a reader to assume the number was a measurement of correctness. It is not, and it is not.</p>
                <p>Forward, <a href="/courses/smp/lessons/smp-numa">the NUMA concept</a> takes the largest thing this course cannot do &mdash; a second memory domain &mdash; and asks whether the distinction is still worth teaching when the phenomenon is absent. The answer it gives is yes, and the reason is the same one that applies here: <strong>a distinction you cannot measure the second half of is still a distinction, and naming it is not the same as claiming it.</strong> Then <a href="/courses/smp/lessons/smp-three">the three-architectures concept</a> says where the fences actually differ, and <a href="/courses/smp/lessons/smp-harness">the harness concept</a> explains why a check can assert that this section said it cannot do these four things, and cannot assert that it can.</p>
                <p>Outward, two links, one inward-looking and one outward. Inward: <a href="/courses/priv/lessons/priv-harness">the privilege course's harness</a> contains the same rule in its most literal form &mdash; it asserts the presence of the sentence that says the vDSO has no sigreturn trampoline on this kernel, and asserts the reason guessing would have been wrong. <strong>An absence is asserted as an absence, with a reason, and never as a decoder that prints a plausible number.</strong> Outward: this section is the one a compiler author will be asked about in a design review, and the defensible answer is the four-item list above rather than a citation of a benchmark. &ldquo;I can tell you what the fence costs; I cannot tell you it is correct, and neither can anyone with a stopwatch&rdquo; is a complete and correct answer, and it is much rarer than it should be.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-atomic">A Lock With Nothing to Lock Against</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-numa">The Thing This Machine Cannot Do</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
