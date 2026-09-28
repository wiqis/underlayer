// SIMD and Vector Processing — Concept 3: elementwise, and independent
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_shapes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Elementwise, and Independent — Underlayer")
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
            <h1>Elementwise, and Independent</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>There is exactly one thing a vector arithmetic instruction does that a scalar one cannot, and it is worth saying in one sentence: <strong>it writes each lane from the same lane of its inputs and reads nothing from any other lane.</strong> Every wide instruction in the x86, NEON and RISC-V V sets obeys this. It is the whole reason a vector loop can be faster, and it is also the reason there is exactly <em>one</em> instruction in the whole family that behaves differently &mdash; and that one is the subject of the next concept.</p>
                <p>So why does this need a concept? Because &ldquo;it is elementwise&rdquo; is not a performance property, and the fastest and slowest vector loops in the world are both perfectly elementwise. Here is the whole of the difference, in one table, with nothing changed but the number of accumulators:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/same arithmetic, different independence/,/^   and the two/p'
   same arithmetic, different independence       ns/iter  speedup   checksum
   ONE accumulator, 4-wide FMA, 16 iterations       28.51     1.00x   15.000000
   FOUR accumulators, 4-wide FMA, 4x4 iterations      7.13     4.00x   12.000000
  </pre>
                </div>
                <p><strong>Same instruction. Same width. Same number of them. One is 4&times; the other.</strong> The only difference is whether the second FMA needs the answer to the first. Nothing about the instruction changed; something about the <em>data</em> changed, and the data is what the compiler cannot see when it decides whether to vectorise.</p>
                <p>That is the sentence the previous concept was reaching for and could not state, and it is the one worth taking into a compiler backend. <strong>Independence is a property of the data, not of the instruction.</strong> Sixteen independent chains hide a 4-cycle multiply latency completely. One chain of sixteen is sixteen dependent 4-cycle latencies, and the wide register does nothing about it.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: what the arithmetic costs and what it does not</h2>
                <p>Four bodies over the same 64 doubles, differing in one arithmetic instruction. The first is a <em>copy</em> &mdash; two loads and a store, no arithmetic at all &mdash; and it is an arm rather than a preamble because &ldquo;what does the arithmetic cost&rdquo; has no answer without it.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/body  /,/FMA, store/p'
   body                                                    ns/iter   vs copy   checksum
   load, store                       (ZERO arithmetic instructions)       7.13     1.00x   32.000000
   load, ADD, store                  (one add)                8.02     1.12x   640016.000000
   load, MUL, store                  (one multiply)           7.63     1.07x   0.000000
   load, FMA, store                  (one multiply-add, one instruction)      11.14     1.56x   32.000000
  </pre>
                </div>
                <p>Read the three arithmetic rows against each other first. <strong>An add and a multiply are within 7% of each other</strong>, and that is the shape of a loop that is not waiting for the arithmetic. Their bodies differ by one instruction and a multiply is no dearer than an add, because both of them hide inside what the two loads and the one store already cost.</p>
                <p>That is the mechanism behind the FMA row in the previous concept's table, seen from this side. FMA halves the arithmetic instruction count from two to one, and the time does not move, because the arithmetic was never the thing being waited for.</p>
                <h3>And the FMA row is not comparable with the two above it</h3>
                <p>This is the trap in the table and it has a name, because it is the same confound that concept 2's arm F exists to remove. <strong>The FMA body reads three arrays and the other two read two.</strong> The row with fewer instructions has <em>more memory operations</em> and costs more. Reading it as &ldquo;FMA costs 1.56&times; a multiply&rdquo; is wrong, and it is a very easy mistake to make because the FMA is genuinely the better instruction.</p>
                <div class="formula">
   TO COMPARE TWO BODIES HONESTLY THEY MUST DO THE SAME LOADS.

     load, ADD, store    2 loads  1 add   1 store    8.02 ns
     load, MUL, store    2 loads  1 mul   1 store    7.63 ns
     load, FMA, store    3 loads  1 fma   1 store   11.14 ns
                                 ^^^ one more

   The extra load is the difference.  The correct comparison of
   mul-then-add against fma is 7.52 + 7.94 against 11.02 --
   two dependent arithmetic instructions against one -- and
   that is the comparison section 2 made with the loads
   held equal, and there FMA was worth nothing at all (1.00x).
                </div>
                <p>And the <strong>checksum column is doing more work than it looks like it is.</strong> The four bodies leave four <em>different</em> numbers: a copy leaves 32, the add leaves 640016 (it is a divergent recurrence), the multiply leaves 0, and the FMA leaves 32 because it is the same fixed point the rest of the artifact uses. That is why the checksums are <em>printed and not asserted equal</em> &mdash; and why an arm that silently computes the wrong thing shows up here as a wrong number rather than as a plausible timing.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: independence, measured, and the one place lanes talk</h2>
                <p>Now the two arms from the top of this concept, and the mechanism they differ by. Both run sixteen 4-wide FMAs per iteration over the same data. One accumulates into a single register; the other into four:</p>
                <div class="formula">
   ONE ACCUMULATOR:

       acc = acc * V[0..3]          <- needs the previous acc
       acc = acc * V[4..7]          <- needs the previous acc
       ... sixteen times

     Every FMA waits for the one before it.  Sixteen
     dependent 4-cycle latencies, and the machine is idle
     for 60 of every 64 cycles.

   FOUR ACCUMULATORS:

       a0 = a0 * V[0..3]            <- needs the previous a0
       a1 = a1 * V[4..7]            <- needs the previous a1
       a2 = a2 * V[8..11]           <- and a2, which is free
       a3 = a3 * V[12..15]
       ... four times, sixteen FMAs in total

     The four chains do not depend on each other, so the
     machine runs them in parallel.  The latency is paid
     once per four instructions instead of once per one.
                </div>
                <p>Measured: <strong>4.00&times;</strong>. And note the second thing in that table &mdash; the two checksums are <em>different</em> (15.0 and 12.0), which is how you can tell at a glance that these are not secretly the same loop. A harness that asserted they must match would have been asserting a bug.</p>
                <p>Three consequences, and the third is the one that reaches into the next concept.</p>
                <ul>
                    <li><strong>The compiler cannot do this for you reliably.</strong> It has to prove the four chains are independent, which means it has to prove the loads do not alias the stores. That is the same aliasing question concept 2 measured at 35&times;, and it is why a loop that the compiler vectorises badly is often a loop it could not prove anything about.</li>
                    <li><strong>Reductions are the one case where you must do it yourself.</strong> A dot product or a sum is a reduction, and a reduction is by definition a chain. <a href="/courses/exe/lessons/exe-deps">The execution course's dependency concept</a> is entirely about this on the scalar side, and the reduction is where the scalar and vector versions of the same lesson finally meet.</li>
                    <li><strong>&ldquo;Elementwise&rdquo; is a restriction, not a power.</strong> It is what makes the width work and it is exactly what you cannot have in a reduction, a prefix sum, a scan, a sort, or anything with a horizontal step. <strong>Every algorithm that does not decompose into independent per-element operations has to be restructured before a vector register can help it, and the restructuring is the hard part.</strong></li>
                </ul>
                <p>And the one instruction that is not elementwise, stated precisely because it is the exception that proves the rule. A <strong>horizontal add</strong> takes one vector register and produces a scalar by adding across its lanes &mdash; that is, lane 0 plus lane 1 plus lane 2 plus lane 3. It is the only common instruction that reads across lanes, and it is the only place in this course where a 4-wide loop is <em>slower</em> than a scalar one. The next concept measures it, and the number is worse than you would guess.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the four rules a vectoriser applies, in order</h2>
                <p>Everything above is one loop, so here is the general case &mdash; the order matters, because each step can fail and a failure at step 3 kills steps 1 and 2.</p>
                <div class="formula">
   1. IS THERE INDEPENDENT WORK?
      The loop body must be decomposable into per-element
      operations.  A[i] = A[i]*B[i] + C[j] qualifies.  A
      running total does not.  A prefix sum does not.
      -> everything below is conditional on this

   2. ARE THE ADDRESSES ALIASED?
      A store to A[j] must not change what B[j+1] holds.
      Named arrays: yes, provable.  double * parameters:
      no, and no amount of -O3 fixes it without restrict.
      -> concept 2, measured at 35x

   3. IS THE TRIP COUNT USABLE?
      A runtime trip count is fine -- it costs a scalar
      epilogue for n mod 4, measured FREE in section 6c.
      A trip count of zero or one is not vectorisable at
      all, whatever the types say.

   4. DOES IT PAY?
      Four elements per instruction against a loop that
      is already memory-bound buys 3.89x in L1 and 1.14x
      at 24 MiB.  If the answer is 1.1, the vectorisation
      is a rewrite for nothing.
                </div>
                <p>Step 4 is the one people skip and it is the one that decides whether a change is worth reviewing. A 1.14&times; speedup is not nothing &mdash; it is worth having &mdash; but it is worth having only if the loop is going to be read and maintained anyway, and the review cost of intrinsics in a codebase that has none is not zero.</p>
                <p>And a worked example of step 1 failing, because it is the interesting failure. Consider a prefix sum, <code>for (i) s[i] = s[i-1] + a[i]</code>. Every element depends on its predecessor, so it is not elementwise and no width helps. The standard fix is not a wide instruction &mdash; it is to <strong>restructure into a scan</strong>, which computes partial sums in a tree so that the work at each level <em>is</em> independent, then combines the levels. That is a real algorithm with a real correctness argument and it is a different program, not a different instruction. <strong>When a loop cannot be vectorised, the fix is almost never a wider register; it is a different loop.</strong></p>
                <p>That is worth contrasting with the reduction, which is <em>also</em> not elementwise and which <em>does</em> have a wide-instruction answer &mdash; because a reduction can be done in parallel across independent partial accumulators and folded at the end. The next concept measures what that fold costs, and the answer is &ldquo;a horizontal add of four doubles costs about as much as the vector operation that produced them&rdquo;, which is why the fold happens once and not per iteration.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the four-body table and read the checksums before the timings.</strong> <em>(Expect an add and a multiply within about 15% of each other, and expect the FMA row dearer than both while doing fewer instructions. The reason is the third load, and if you cannot see it from the table, look at the bodies in <code>simdbench.c</code> and count the arrays each one reads. Then try the honest comparison: time a mul-then-add body against the FMA body with the loads matched, and expect FMA to be worth very little.)</em></li>
                    <li><strong>Make the independence result yourself, with one variable.</strong> Change <code>dep_one</code> to use two accumulators, then four, then eight, and rerun. <em>(Expect 1.00&times;, about 2&times;, 4&times;, then a plateau &mdash; the machine has a fixed number of multiply pipes and once you have more chains than pipes the extra ones queue. Finding the plateau is the exercise: it is the number of arithmetic units, and on this machine it is small enough that four is enough.)</em></li>
                    <li><strong>Look for the one-chain bug in code you did not write.</strong> A reduction into a single accumulator inside a loop that is otherwise vectorised; a <code>sum += a[i] * b[i]</code> where a compiler has vectorised the multiply but not the sum. <em>(Expect the compiler to have handled most of them, and expect the ones it handled badly to be the ones where the accumulator is a <code>double</code> rather than a <code>float</code>, or where the loop is a reduction over a struct field. A one-chain vectorised loop is a loop where the wide register bought the multiply and charged you for the chain.)</em></li>
                    <li><strong>Take a real loop and ask step 1 out loud.</strong> Pick something hot. <em>(Expect the honest answer to be &ldquo;yes, elementwise&rdquo; more often than you expect, because most numerical inner loops are, and to be &ldquo;no&rdquo; for anything involving a scan, a sort, a median, a cumulative quantity, or an early exit. The loops that are &ldquo;no&rdquo; are the interesting ones and they are usually the ones where a library is already better than your code.)</em></li>
                    <li><strong>Write down every place you have written &ldquo;4 lanes, therefore 4&times;&rdquo; and add the missing clause.</strong> <em>(Expect the clause to be either &ldquo;when the data is in L1&rdquo; or &ldquo;if the addresses are consecutive&rdquo;, and expect that in about half the cases you cannot establish either from where you are standing. That inability is the finding, and it is a better use of an afternoon than another intrinsics loop.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/simd/lessons/simd-compiler">the compiler concept</a> asked what a compiler does with a loop it cannot prove anything about, and this concept is the answer to why the question matters: the vectoriser's job is to find independent work, and aliasing is what stops it looking. <a href="/courses/simd/lessons/simd-width">The width concept</a> supplied the register table whose whole content is a division, and this concept is the first place that division stops being enough.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-reduce">the reduction concept</a> is the exception that this concept sets up. Everything here is elementwise, and a reduction is the one operation that is not &mdash; it is the only place the lanes must talk to each other, and the artifact measures what that costs and finds it costs about as much as the vector operation itself. <a href="/courses/simd/lessons/simd-boundaries">The boundaries concept</a> then takes the load and the store, which the four-body table above showed is the real cost, and asks what happens when the addresses stop being nice.</p>
                <p>Outward, this is the concept where the execution course's central lesson is finally stated in its own terms. <a href="/courses/exe/lessons/exe-deps">The dependency concept</a> teaches that a chain of dependent operations is bounded by latency and a set of independent ones by throughput; this concept measures that on a 4-wide register and gets 4.00&times;, which is exactly what &ldquo;independent&rdquo; means when the width is four. <a href="/courses/exe/lessons/exe-latency">The latency concept</a> is where the multiply's latency is measured &mdash; and this course assumes it rather than re-measuring it, because re-measuring it would be a fourth course's job and not a fourth course's lesson. <a href="/courses/mem/lessons/mem-writes">The memory course's writes concept</a> is where three loads and a store per iteration was already a shape; this concept is the table that says what that shape costs and that the arithmetic in it is nearly free.</p>
                <p>And the practical consequence, which is the one to carry out of here: <strong>when a loop does not vectorise, the question to ask is not &ldquo;how do I make the compiler vectorise it&rdquo; but &ldquo;is there independent work in here at all&rdquo;</strong>. A prefix sum has none, and the answer is a different algorithm. A dot product has some &mdash; four partial sums, folded once &mdash; and the answer is intrinsics. Telling those two apart is the skill, and it is a question about the data, not about the compiler.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-compiler">The Compiler, the Intrinsics, and a Control That Lied</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-reduce">Going Back to One Scalar</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
