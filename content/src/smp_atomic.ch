// Multiprocessor Architecture — Concept 3: a lock with nothing to lock against
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_atomic() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Lock With Nothing to Lock Against — Underlayer")
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
            <h1>A Lock With Nothing to Lock Against</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything in the last two concepts was two threads fighting. <strong>This is the only place in the course where the hardware imposes a cost that has nothing to do with another thread.</strong> The machine is the same machine, the cores are the same two cores, and the number of threads that could conceivably contend for the line is zero &mdash; and the locked instruction still costs more than twice what the unlocked one does.</p>
                <p>That result is worth a concept on its own for two reasons. First, it is the single most useful thing a programmer can know about atomics: <strong>the cost of an uncontended atomic is not a rounding error, and it is not zero, and it is charged to a thread that had no reason to pay it.</strong> A code generator that turns every increment into a locked read-modify-write has made a decision with a price, and the price is roughly one and a half extra ticks per operation before a single line is contended.</p>
                <p>Second, it forced this course to retract an explanation it had already written. Here is the retraction, verbatim from the artifact, and it is the sharpest of the six because the <em>number</em> was right and the <em>reason</em> was wrong &mdash; which is much harder to notice than either being wrong:</p>
                <div class="hex-dump">
                <pre>   R4. "An uncontended lock is expensive because of coherence."
       RETRACTED TO THE WRONG REASON.  It is expensive, and the
       measurement in section 3 separates the two, but the cost is NOT
       coherence -- there is no other thread and nothing to be coherent
       with.  It is the barrier the prefix implies, paid by a thread
       that had no reason to pay it.  See R5.
                </pre>
                </div>
                <p>Read that carefully. <em>Retracted to the wrong reason</em> is a distinct category from retracted, and it is the category a measurement is most likely to hide. A wrong number announces itself eventually &mdash; the run disagrees, or the ratio comes out at zero, or the program takes a different path. A wrong <em>reason</em> attached to a right number is perfectly stable, survives re-runs indefinitely, and is believed by everyone who reads it, including the person who wrote it. <strong>You cannot detect this class of error by measuring more carefully. You can only detect it by asking what else could have produced the number.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two configurations, three bodies, one subtraction</h2>
                <p>Same two cores, same bodies, same iteration count. One thing differs between the two tables: whether the two threads write the <em>same</em> line.</p>
                <div class="formula">
  CONFIGURATION 1 -- two threads, TWO SEPARATE lines.
                    Nothing is shared.  No coherence
                    traffic is possible.  This is the
                    instruction's price on its own.

  CONFIGURATION 2 -- the SAME threads, the SAME cores,
                    ONE line.  This is the price when
                    there IS something to be coherent
                    with.

  BODES, in all six arms:

    plain store     movq  %0, %1     one store, no prefix
    lock xadd       lock xaddq       add-and-store, cannot fail
    lock cmpxchg    do &#123; new = old+1; lock cmpxchgq &#125;
    while (new != old)
                    the general form: a compare, and a
                    retry if someone got there first
                </div>
                <p>Two design decisions in that shape are worth naming, because either one quietly turns the experiment into a different one.</p>
                <p><strong>Both configurations use the same <code>measure()</code> machinery but two different worker functions</strong>, and they are kept as separate functions rather than as a flag on one function. &ldquo;The two threads are on different cores&rdquo; and &ldquo;the two threads are on the same line&rdquo; are two different experiments, and the output has to be able to say which is which &mdash; which is exactly the confusion R6 is about. A single worker with a boolean would have produced a table where the two axes are interleaved in the reader's head.</p>
                <p><strong>Both arms still pin and both arms still verify.</strong> The threads in configuration 1 are two separate threads with nothing between them, because the alternative &mdash; measuring one thread &mdash; would not produce the same kind of number and would introduce a comparison across two different estimators. The pin is checked after the join in both, because a thread that migrated into the same core as its partner would turn &ldquo;nothing is shared&rdquo; into &ldquo;the line is contended by a core that also shares the L1 with it&rdquo;, which is configuration 2 wearing configuration 1's label.</p>
                <p>And the CAS loop is in the table for a reason that is easy to miss: <strong>a compare-and-swap is the general form and a fetch-and-add is the special case that cannot fail.</strong> Comparing them in both configurations is not a formality. It is the only way to see which part of the instruction's cost is the arithmetic and which part is the retry structure, and the answer is that you cannot separate them until the line stops being shared.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: 2.54&times; with nothing to lock against</h2>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/two threads, TWO SEPARATE/,/uncontended cost/p'
   two threads, TWO SEPARATE lines -- nothing shared at all:
      plain store            1.04 ticks/op   &lt;- the floor
      lock xadd              2.64 ticks/op     2.54x the plain store
      lock cmpxchg loop      2.99 ticks/op     2.88x the plain store

   the SAME bodies, both threads on ONE line:
      plain store            1.08 ticks/op     1.04x the floor
      lock xadd             22.03 ticks/op    21.20x the floor
      lock cmpxchg loop     22.31 ticks/op    21.47x the floor

   THE MOST IMPORTANT NUMBER IN THIS SECTION, and it is a subtraction:
      lock xadd,   one line     22.03
      lock xadd,   own line       2.64
      the cost of CONTENTION     19.39 ticks  = 7.33x the uncontended cost
 </pre>
                </div>
                <p>Look at the first table, which is the one people do not expect. <strong>A <code>lock</code> prefix with nothing to be locked against costs 2.54&times; a plain store, on a machine with no other thread running.</strong></p>
                <p>It is not a coherence cost. There is no coherence traffic and nothing to be coherent with &mdash; both threads own separate lines in separate caches and neither cares about the other. It is the instruction's own guarantee. On x86 the guarantee is a <em>full</em> memory barrier: loads before it cannot move after it, stores before it cannot be delayed past it, and both are ordered against every other core. <strong>You pay for that whether or not anyone is there.</strong></p>
                <p>That is R4 in one sentence, and it is also the reason the same instruction costs something different on a different architecture. <a href="/courses/smp/lessons/smp-three">On AArch64 the acquire and the release are separate instructions and the barrier is a mode the access itself has</a>, so a relaxed atomic increment is nearly free and a <code>lock</code>-prefixed one does not exist. The expensive thing here is not atomicity. <strong>It is the ordering that x86 attaches to atomicity whether or not you asked for it.</strong></p>
                <p>Now the subtraction, which is the most important number in the section and is not a ratio of anything:</p>
                <div class="formula">
   contended xadd   22.03 ticks/op
   uncontended      2.64 ticks/op
   CONTENTION      19.39 ticks/op  =  7.33x the uncontended cost

   and compare that to the floor:
   19.39 ticks of contention against a 1.04-tick
   plain store.  The contention is about EIGHTEEN
   plain stores.
                </div>
                <p>Reporting 22.03 on its own would tell you almost nothing &mdash; it is a number on a machine whose core clock you do not know. Reporting the <em>ratio</em> to the floor would tell you the wrong thing, because it folds in a cost that has nothing to do with contention. <strong>The subtraction is the only report that isolates the effect, and it is the number a reader should carry away.</strong></p>
                <p>And it is stable in a way the floor is not. Across the three recorded runs the contended <code>lock xadd</code> came out at 22.03, 22.27 and 22.24 ticks/op; the <em>plain-store floor</em> moved between 1.04 and 1.39. The ratio to the floor therefore moved too &mdash; 21.20&times;, 16.07&times; and 21.35&times; &mdash; while the contended cost itself did not move at all. <strong>The stable number is the contended one and the noisy number is the floor, which is the opposite of what people expect and is the whole argument for reporting the difference.</strong> It also means the uncontended <em>ratio</em> is the least trustworthy figure in this section: it reads 2.54&times;, 1.91&times; and 2.54&times; across the three runs, and what moved was the denominator.</p>
                <div class="hex-dump">
                <pre>   A contended atomic is not twice an uncontended one because the
   hardware is twice as busy.  It is expensive because ONE core OWNS
   the line and the other must take it, and the ownership has to move
   back and forth, and each move is a round trip neither side can
   overlap with its own work.  This is why a contended counter is a
   queue and not a fast counter, and why the fix is never a better CPU.
                </pre>
                </div>
                <p>That last sentence is the engineering conclusion and it is worth stating as a rule: <strong>a contended atomic increment is a queue with a very small service time and no queueing discipline, and the only ways to make it faster are to give each thread its own counter or to batch the updates.</strong> Sharding the counter is not an optimisation, it is the algorithm. No amount of clock rate changes the ownership round trip.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the CAS comparison, and the sentence that did not survive it</h2>
                <p>The CAS loop against the <code>xadd</code>, in both configurations, is four numbers and one finding:</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/the CAS loop, against/,/Read those two ratios/p'
   the CAS loop, against the xadd, on the same two configurations:
      separate lines        2.99 against     2.64     1.13x
      one shared line      22.31 against    22.03     1.01x
 </pre>
                </div>
                <p><strong>Read the two ratios against each other rather than separately, because the difference between them is the finding.</strong> On separate lines the retry structure is visible and it costs something: 1.13&times;. On a shared line the two instructions become indistinguishable: 1.01&times;, which is the same as saying the retry structure is free once the line is moving anyway. The transfer dominates everything the instruction does around it.</p>
                <p>That is the general shape of a contended measurement, and the artifact states it as such:</p>
                <div class="hex-dump">
                <pre>   That is the general shape of a contended measurement: the LOWER
   bound on what you are timing is not the thing you meant to time, and
   the only honest report is the two numbers side by side.  A draft of
   this section said the CAS loop 'costs more on a shared line because
   the retry rate is the contention'.  It does not.  It costs the SAME,
   and the sentence was a story about a number that contradicted it.
                </pre>
                </div>
                <p><strong>Note what kind of error that was.</strong> The draft sentence is not a wrong number and not a wrong mechanism exactly &mdash; the retry rate <em>is</em> a form of contention. It is a mechanism that sounds right, is true in general, and predicts a difference in the one place where the measurement found none. Had the CAS loop come out 10% more expensive on the shared line, the sentence would have looked vindicated and the check would have passed.</p>
                <p>The defence is the awkward one: <strong>a story that explains a number you already have is the least reliable kind of explanation, because it costs nothing to generate and it is never falsified by the number that inspired it.</strong> It is falsified only by the next measurement, which is why the artifact prints the two configurations side by side and lets them argue, and why the harness asserts the sentence that says the sentence was wrong.</p>
                <h3>The arithmetic, done once so it can be checked</h3>
                <div class="formula">
   uncontended xadd / plain store     2.64 / 1.04 = 2.54x
   uncontended cas  / plain store     2.99 / 1.04 = 2.88x
   contended   xadd / floor          22.03 / 1.04 = 21.20x
   contention                        22.03 - 2.64 = 19.39
   contention / uncontended          19.39 / 2.64 = 7.33x
   contention / plain store          19.39 / 1.04 = 18.6x

   the harness checks the ORDERING of these, not the
   values: a contended atomic must be more than three
   times an uncontended one, and the contention must
   exceed three plain stores.  It also checks that
   the subtraction was REPORTED as a subtraction --
   a harness that only compared the two rows could
   pass on an artifact that never isolated the effect.
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the uncontended arm and read it before the contended one.</strong> <em>(Expect the locked instruction to cost between roughly 1.5 and 3&times; a plain store, with no other thread touching the line. If it costs about the same, suspect R1 before anything else: write the plain-store arm in C instead of inline asm, let the optimiser delete the loop, and see how quickly the floor collapses. This is the bug that has hit three courses in a row.)</em></li>
                    <li><strong>Move one thread's counter and measure the subtraction both ways.</strong> Take the contended number and the uncontended number, subtract, and then <em>separately</em> measure a loop that touches a shared line with a plain store (1.08 ticks/op). <em>(Expect the plain store on a shared line to be indistinguishable from a plain store on a private line &mdash; the line is shared but nobody writes it exclusively, so nobody has to hand it over. That is the cleanest demonstration in the course that the transfer is bought by the <em>write</em> and not by the sharing, and it is the same fact as row C in the previous concept seen from the other side.)</em></li>
                    <li><strong>Shard the contended counter and watch the subtraction disappear.</strong> Give each thread its own <code>long</code> on its own 64-byte line, sum them at the end. <em>(Expect the result to land near the uncontended 2.64 rather than near 22.03, and expect the summed total to be exactly right. This is the fix the previous concept recommends, expressed as a change of code rather than as padding on a struct, and it is the single most useful thing to carry out of this concept: <em>a contended atomic is a queue; the fix is to stop queueing</em>.)</em></li>
                    <li><strong>Find the same measurement on a machine where the lock prefix is cheap.</strong> Build and run the same three bodies on AArch64 with a relaxed atomic add and with an <code>ldar</code>/<code>stlr</code> pair. <em>(Expect the relaxed arm to be close to a plain store and the acquire/release arm to be different from it &mdash; on a weakly-ordered machine the ordering is something you write down, so it has to cost something, and it does not cost 1.5 ticks for free. If your machine happens to be x86-64 only, read R5 and <a href="/courses/smp/lessons/smp-three">the three-architectures concept</a> instead, and treat it as the same argument without the experiment.)</em></li>
                    <li><strong>Write down every sentence in your code that says &ldquo;contention&rdquo;.</strong> Then for each one, name the fix: true sharing (a better algorithm), false sharing (padding), oversubscription (fewer threads or a better placement), or now-this-one (the barrier you asked for and did not need). <em>(Expect the fourth category to be the one you did not know was there, and expect most of the &ldquo;we are contention-bound&rdquo; comments in real code to be the third.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-sharing">the sharing concept</a> measured row G &mdash; the same body without the <code>lock</code> &mdash; and found the two indistinguishable, because seven interleaved arms on a busy guest add more noise than the lock costs. <strong>This concept is the other half of that sentence</strong>: with nothing else in the run, the lock costs 2.54&times;. Together they produce the rule &ldquo;the cost of a lock is a property of the noise floor of whichever table you measured it in,&rdquo; and the discipline that follows from it, which is to measure a small effect in a table that contains only that effect.</p>
                <p>Forward, <a href="/courses/smp/lessons/smp-ordering">the ordering concept</a> is where the other promise of the prefix gets its own section, and where this course states the largest limit in its own vocabulary: <strong>a duration is not a guarantee, and no timing measurement on any machine can establish that an ordering is correct.</strong> The 2.54&times; in this concept is a cost paid for ordering; the next concept says the price can be measured and the guarantee cannot, and explains why those are different kinds of question.</p>
                <p>Outward, two connections worth making explicitly. <a href="/courses/exe/lessons/exe-instrument">The execution course's instrument concept</a> is why the subtraction is trusted more than the ratio in this section &mdash; it is the same argument that a TSC tick is time rather than cycles, applied to a ratio whose denominator moves. And <a href="/courses/priv/lessons/priv-harness">the privilege course's harness</a> is where the &ldquo;report the subtraction, not the ratio&rdquo; rule is generalised: rule 1 there says structural claims are asserted exactly and timing claims only as orderings, and the contention check here is an instance of it &mdash; the harness asserts that contention costs far more than the prefix itself, not what contention costs.</p>
                <p>One outward-facing consequence, because this is the concept a compiler author will use. On x86-64 <code>fetch_add</code> in C11 <code>memory_order_relaxed</code> and <code>memory_order_seq_cst</code> compile to the <strong>same instruction</strong>, because the prefix already implies a full barrier and the compiler has nothing to add. On AArch64 they compile to two different instruction pairs. <strong>That is R5: a lock-free algorithm written on x86-64 is correct partly by accident</strong>, and this concept is where the accident becomes visible as a line item in a timing table.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-sharing">Three Things Called Contention</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-ordering">A Duration Is Not a Guarantee</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
