// SIMD and Vector Processing — Concept 4: going back to one scalar
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_reduce() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Going Back to One Scalar — Underlayer")
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
            <h1>Going Back to One Scalar</h1>
            <div class="lesson-meta">28 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The previous concept ended by naming the exception: a <strong>horizontal add</strong> is the one common instruction that reads across lanes rather than within them, and it is the only place in this course where a 4-wide loop loses to a scalar one. This concept is that place, and the number is worse than most people expect.</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/arm  /,/scalar loop, no vector at all/p'
   arm                                             ns per 4 elem  vs arm A  value produced
   4-wide accumulate, reduce ONCE at the very end          1.341     1.00x       1.644919
   4-wide accumulate, TREE horizontal add every group        1.946     1.45x   26948.077729
   4-wide accumulate, EXTRACT 4 lanes every group           1.984     1.48x   26948.077729
   4-wide accumulate, VHADDPD every group                   1.929     1.44x   26948.077729
   scalar loop, no vector at all                            5.349     3.99x       1.644919
  </pre>
                </div>
                <p>Read that carefully. The first row and the last row compute <strong>the same number</strong> &mdash; both 1.644919 &mdash; and the 4-wide one is <strong>3.99&times; faster</strong>. That is the shape to write, and it is the good news.</p>
                <p>The bad news is the three middle rows, and what they say is this: <strong>folding the accumulator back into a scalar on every iteration costs about as much as the vector operation that produced it.</strong> The vector multiply-add is 1.341&nbsp;ns per four elements; adding a tree horizontal add to every iteration takes it to 1.946, and extracting the four lanes into a scalar takes it to 1.984. The fold costs 45% on top of the work it is folding.</p>
                <p>And there is a detail in that table that is worth more than the timings. <strong>The three middle rows do not compute the same number as the first and last.</strong> They produce 26948.077729. They are not broken; they are computing a <em>sum of running totals</em>, which is a different quantity. This is printed in the artifact deliberately, and it is the subject of a retraction later in this concept, because the first version of this section compared four arms that were each summing something different and reported the ratios as though they were costs of the same computation.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three ways to fold four lanes into one</h2>
                <p>Given a register holding <code>a = (a0, a1, a2, a3)</code>, there are three ways to get <code>a0+a1+a2+a3</code> out of it, and they differ in what they cost and in what they assume.</p>
                <div class="formula">
   TREE -- the right way.  Pair the 128-bit halves, then
   pair the two 64-bit lanes of the result.

       h = vaddpd(v, vextractf128(v, 1))
         -> (a0+a2, a1+a3, a2+a0, a3+a1)
       q = vaddpd(low128(h), high128(h))
         -> (sum,  sum,  sum,  sum)
       answer = q.lane0

       two vector adds, one shuffle, one extract.
       DEPTH TWO, which is log2(4).

   EXTRACT -- the obvious way.  Move each lane into a
   scalar register and add them.

       __m128d lo = low128(v), hi = extractf128(v, 1);
       s = lo.lane0 + lo.lane1 + hi.lane0 + hi.lane1;

       four moves to the scalar side of the machine and
       three scalar adds.  Every one of them crosses
       between the vector unit and the scalar unit.

   VHADDPD -- the instruction whose NAME says what you
   want and which does something else.  See below.
                </div>
                <p>And here is the fact that cost this course two bugs and is worth a paragraph on its own, because it is the most dangerous kind of error there is: <strong>an error that is perfectly stable.</strong></p>
                <div class="formula">
   vhaddpd ADDS THE CORRESPONDING LANES OF ITS TWO
   SOURCES, WITHIN EACH 128-BIT HALF.

     vhaddpd(v, v)  is NOT  (a0+a1, a1+a2, a2+a3, a3+a0)
                     it IS  (a0+a0, a1+a1, a2+a2, a3+a3)

   which is to say:  vhaddpd(v, v) DOUBLES v.

   To use it you must first swap the two 128-bit halves,
   so that the two sources of each half are the low pair
   and the high pair:

     permute2f128(v, v, 0x81)  ->  (a2, a3, a0, a1)
     vhaddpd(that, that)        ->  (a0+a2, a1+a3, ...)

   The first version of this section called vhaddpd
   without swapping the halves.  It reported EXACTLY
   TWICE the true sum, to the last bit.  Not nearly
   twice.  Not twice plus rounding.  Twice.
                </div>
                <p>Why that is dangerous, and it is the point of printing it: a wrong answer that is <em>approximately</em> wrong announces itself &mdash; the test fails, the number looks wrong, somebody investigates. An answer that is <strong>exactly</strong> twice the right one looks like a plausible sum of a different set of numbers, and it is <em>stable across every re-run</em>. <strong>You cannot detect this class of error by measuring more carefully. You can only detect it by looking at the answer.</strong></p>
                <p>And there was a second bug hiding behind the first, which is worth stating because they had the same symptom. The first version's <em>tree</em> reduction added the two 128-bit halves of an already-paired register, so both 64-bit lanes already held the total and it was added to itself. Also exactly twice. Two different bugs, one symptom, one line of output &mdash; and the checksum on that line is the only reason either was found.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what a reduction actually costs, and why tree order</h2>
                <p>Now the useful part. The three middle rows of the table differ in how they fold, and they cost almost the same &mdash; 1.45, 1.48 and 1.44 of the fold-once arm &mdash; which is itself a result. <strong>On four lanes the shape barely matters.</strong> It matters enormously on a million, and the reason is that a reduction is a dependency chain.</p>
                <div class="formula">
   WHY TREE ORDER, WHICH THE TABLE CANNOT SHOW AT N=4

   A reduction is a DEPENDENCY CHAIN and the shape of the
   fold IS the depth of that chain.

     sequential fold over N elements
         depth N, and every step waits for the last.
         N = 1,000,000 means a million-long chain.

     pairwise tree over N elements
         depth log2(N).  N = 1,000,000 means depth 20.

   Same number of adds.  A logarithmic chain instead of a
   linear one.  THAT is the whole argument for tree order,
   and it is why `std::reduce`, OpenMP's `reduction(+:x)`
   and every BLAS `dot` are written as a tree.

   At N = 4 the two are 3 adds deep and 2 adds deep, which
   is why the three middle rows above cost the same.
   The table is showing you the case where the idea does
   not matter, and the text is telling you where it does.
                </div>
                <p>And the caveat, which is a correctness statement and not a performance one: <strong>a tree reduction reassociates the additions, and in floating point that gives a different answer.</strong> Summing a million doubles left to right and summing them pairwise do not produce the same number, and neither is &ldquo;wrong&rdquo;. If your answer must be bit-identical to the sequential one &mdash; because a test asserts an exact value, or because a downstream consumer hashes it &mdash; you cannot have a tree, and the chain is the price of the answer.</p>
                <div class="hex-dump">
                <pre>   It also reassociates the additions, which changes the result in floating
   point -- so a tree reduction is a DIFFERENT SUM, and if your answer must be
   bit-identical to the sequential one you cannot have it.
  </pre>
                </div>
                <p>Three rules fall out of the table, and they are the whole concept.</p>
                <ul>
                    <li><strong>Reduce once, at the end.</strong> Four partial accumulators, one horizontal add after the loop. The table's first row against its second is 1.45&times; for one line of code at the bottom of the loop.</li>
                    <li><strong>Never write <code>sum += v[i]</code> over a vector.</strong> That is the EXTRACT row, and it is 1.48&times; &mdash; the worst of the three, because every lane is moved across to the scalar side individually. If you have written that, the fix is to accumulate into a <em>vector</em> and fold at the end.</li>
                    <li><strong>Check the mnemonic, not the name.</strong> <code>vhaddpd</code> was the fastest-looking of the three and it is the one that means something else. The measured cost is nearly identical to the correct tree fold, so <strong>no timing would ever have told you</strong>; only the value did.</li>
                </ul>
                <p>And the general form, which is why this concept is in the course at all: <strong>a horizontal add of four doubles costs about as much as the vector operation that produced them.</strong> There is no formulation of a reduction that avoids paying for the fold &mdash; the fold is the operation. What there is, and what you choose, is <em>how many times</em> you pay it. Once at the end, or once per iteration, and the ratio between those two is the 1.45&times; in the table.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the four shapes, and the one that is not a reduction</h2>
                <p>All five arms sum the squares of the same 65536 doubles. What differs is when the lanes are folded and how. Laid out so the arithmetic is checkable:</p>
                <div class="formula">
   ARM 1  accumulate 4-wide, fold ONCE at the end

       __m256d acc = zero;
       for (g = 0; g < N/4; g++)
           acc = vaddpd(acc, vmulpd(load(S+4g), load(S+4g)));
       return red_tree(acc);        // one fold, total work

   ARM 2  the same, but fold EVERY group by tree

       for (g...) &#123; acc = vaddpd(acc, ...); s += red_tree(acc); &#125;
                                     // 16384 folds, and s is a
                                     // sum of RUNNING TOTALS

   ARM 3  the same, but extract four lanes EVERY group

       for (g...) &#123; acc = vaddpd(acc, ...);
                    s += lo0 + lo1 + hi0 + hi1; &#125;

   ARM 4  the same, but vhaddpd EVERY group

       for (g...) &#123; acc = vaddpd(acc, ...); s += red_hadd(acc); &#125;
                                     // red_hadd() swaps the halves
                                     // FIRST, which is the whole
                                     // difference between this and
                                     // exactly twice the answer

   ARM 5  no vector at all

       double acc = 0;
       for (i = 0; i < N; i++) acc += S[i]*S[i];
                </div>
                <p>Arms 2, 3 and 4 are the same algorithm with three different folds, and they produce the same number as each other &mdash; 26948.077729 &mdash; because they are all summing running totals. Arm 1 and arm 5 produce 1.644919, the actual sum of squares. <strong>That is the retraction, printed in the artifact:</strong> the first version of this section compared all four as though they were four costs of one computation, and three of the four ratios were ratios between different quantities.</p>
                <p>And one more worked case, because the interesting mistake is not in the code but in the question. A <strong>max reduction</strong> &mdash; the largest element of an array &mdash; looks like the same problem and is not. Two differences worth knowing before you write it:</p>
                <ul>
                    <li><strong>There is an <em>empty vector</em> problem.</strong> A sum over zero elements is 0. A maximum over zero elements is not defined, and the identity you accumulate into has to be &minus;infinity, not zero. Getting that wrong returns zero for an all-negative array, and it is the most common max-reduction bug in real code.</li>
                    <li><strong>It is exact, so you do not need a tree.</strong> Unlike a sum, a maximum does not reassociate &mdash; the order cannot change the answer &mdash; so the whole dependency-chain argument from above does not apply, and the cheapest correct implementation is four independent vector accumulators folded at the end. <strong>The tree argument is a property of floating-point addition, not of reductions in general.</strong></li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the table and read the value column before the timing column.</strong> <em>(Expect the first and last rows to agree and the middle three to agree with each other and not with them. If your middle three are the same as your first, something is wrong with the arms rather than with the machine &mdash; check that arms 2 to 4 really do fold every group. The gap between the value column and the timing column is the lesson, and reading only the timings gets you the opposite of it.)</em></li>
                    <li><strong>Write <code>vhaddpd(v,v)</code> and check what it does.</strong> A four-line program: set a register to (1,2,3,4), call the intrinsic, print the lanes. <em>(Expect (2,4,6,8) &mdash; it doubled. Then swap the halves with <code>permute2f128</code> first and expect the pairs. This is thirty seconds of work and it is the single most useful half hour in the course, because the failure mode is a stable wrong answer rather than a crash.)</em></li>
                    <li><strong>Change the reduction's tree depth and watch the dependency chain.</strong> Summing 65536 doubles with 1, 2, 4, 8 and 16 accumulators. <em>(Expect the curve to flatten once you have more accumulators than the machine has add ports, and expect the one-accumulator version to be dramatically worse. Note that this is a DIFFERENT experiment from the table above, which holds the fold count fixed &mdash; the table varies the fold and this varies the parallelism, and they are two different things that are easy to confuse.)</em></li>
                    <li><strong>Find a <code>sum += v[i]</code> in code you did not write.</strong> <em>(Expect to find one, usually in a hand-written inner loop where somebody started from scalar code and added intrinsics one instruction at a time. The fix is a vector accumulator and a single fold at the end, and the measurement above says it is worth about a third. <strong>Write down the before and after</strong> &mdash; a change with no number attached is a change nobody will keep.)</em></li>
                    <li><strong>Decide, for one reduction of yours, whether the answer has to be bit-identical.</strong> <em>(Expect this to be the whole exercise. A checksum over a file does not care about order; a financial total might; a value compared against a golden constant in a test definitely does. If it does not have to be identical, use a tree and say so in a comment. If it does, the chain is the price and the comment should say that instead. <strong>Writing down which of the two you have is worth more than either optimisation.</strong>)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/simd/lessons/simd-shapes">the shapes concept</a> set this up by naming the horizontal add as the one instruction that is not elementwise, and by measuring that four independent accumulators are 4.00&times; one. <strong>Those four accumulators are the subject of this concept</strong> &mdash; the whole table above is about what happens after you have them, and the answer is that the fold costs as much as the work and therefore happens once. <a href="/courses/simd/lessons/simd-compiler">The compiler concept</a> is the other parent: a compiler that cannot prove independence will not produce those four accumulators, and this concept is what it is trying to avoid.</p>
                <p>Forward, <a href="/courses/simd/lessons/simd-boundaries">the boundaries concept</a> asks about the load and the store, which the four-body table in the previous concept showed is the real cost of a vector loop &mdash; and the tail it handles there is the same shape as the fold handled here. <strong>A tail and a reduction are the same problem</strong>: a small number of elements left over after a wide operation, and in both cases the answer on a machine with no mask register is to do them one at a time, which this concept measures as free and that one measures as free independently.</p>
                <p>Outward, the connection to <a href="/courses/exe/lessons/exe-deps">the execution course's dependency concept</a> is the deepest in the course. That concept's central claim &mdash; that a chain is bounded by latency and independent work by throughput &mdash; is <em>exactly</em> the tree-versus-sequential argument above, and this course is the same lesson in a register where the latency is four times shorter. <a href="/courses/smp/lessons/smp-atomic">The multiprocessor course's atomic concept</a> is the other connection worth making and it is a warning: it measured a <code>lock</code> prefix that promises ordering whether you asked for it or not, and the moral was that a guarantee you did not ask for is a cost you pay anyway. <strong>A floating-point sum has the same property.</strong> Reassociation is a freedom the language grants you and that most code silently uses, and the day the order matters &mdash; a test constant, a hash, a bit-for-bit comparison &mdash; the cost of the chain appears with no warning and no diagnostic.</p>
                <p>Outward again, and it is the one that will matter to a code generator: <strong>any code that emits a horizontal reduction has to decide the fold order, and the decision changes the answer.</strong> That is not a performance knob. <a href="/courses/exe/lessons/exe-verify">The execution course's harness</a> is where the general rule for checking a compiler's choice lives &mdash; a claim about what a compiler did is a claim about bytes &mdash; and this course's own harness applies it to exactly one thing: the disassembly of the four loop forms.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-shapes">Elementwise, and Independent</a></span>
                <span>Next: <a href="/courses/simd/lessons/simd-boundaries">Alignment, the Gather, and the Tail</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
