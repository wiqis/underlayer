// Multiprocessor Architecture — Concept 2: three things called contention
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_sharing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Three Things Called Contention — Underlayer")
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
            <h1>Three Things Called Contention</h1>
            <div class="lesson-meta">29 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Rule 5 of this course's artifact, learned the way all six of its rules were learned &mdash; by breaking it:</p>
                <div class="formula">
   5. SEPARATE THE EFFECTS, DO NOT CONFLATE THEM.  True sharing,
      false sharing and "two SMT siblings" are three different
      things with a factor of sixty between them, and the single
      most common error in concurrent programming is to call all
      three "contention".  Section 2 measures them in one table,
      changing exactly one thing per row.
                </div>
                <p>Three things, and the reason they have to be separated is not pedantry. Each one has a different fix, and the fixes are not even the same kind of thing:</p>
                <ul>
                    <li><strong>True sharing</strong> &mdash; two threads updating the same value. The cost is the data structure's. Padding does not help; a lock does not help; only a better algorithm does.</li>
                    <li><strong>False sharing</strong> &mdash; two threads updating values eight bytes apart, in one line. The cost is the line's, and it is pure waste. <strong>The fix is in the source and it is one attribute.</strong></li>
                    <li><strong>Two SMT siblings</strong> &mdash; two threads that happen to be on one physical core. This is not a cheaper version of either of the above. There is only one L1 between them, so there is no second cache to be coherent with and the coherence experiment does not exist.</li>
                </ul>
                <p>Calling all three &ldquo;contention&rdquo; gets you a plausible answer to a question you did not ask, and then you optimise the wrong thing. In this table the cheapest sharing row costs about a twelfth of the dearest, and one of the three &mdash; the SMT row &mdash; turns out to cost <em>nothing measurable at all</em>. That is a factor-of-twelve spread, and the artifact's rule calls it sixty because the memory course's own figure for the same family of effects was 61.9&times;. Either way the spread is the argument: <strong>three effects an order of magnitude apart do not belong under one word.</strong></p>
                <p>There is a fourth trap here that is not about the word at all, and it is the one that ruined the first version of this table. It is in the sentence &ldquo;exactly one thing changed per row&rdquo;, and it deserves its own paragraph because <em>almost every microbenchmark in the world violates it</em>.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: a controlled experiment, and the one it was not</h2>
                <p>One program, four placements, seven rows, and the property that makes the table an experiment rather than three benchmarks:</p>
                <div class="hex-dump">
                <pre>   Rows A, B and C use the IDENTICAL instruction on the IDENTICAL
   machine.  Only the memory address changes.  That is what makes them
   a controlled experiment rather than three benchmarks -- and the
   first version of this table did not have that property: row A used a
   plain store and row B used a locked one, so B/A measured the cost of
   the instruction AND the cost of sharing, and the two could not be
   told apart.  The number looked fine.  It meant nothing.
                </pre>
                </div>
                <p>Read that again slowly, because it is the whole lesson: <strong>the number looked fine.</strong> A plain store against a locked read-modify-write on a shared long is a difference of thirteen times, and any reader would have written &ldquo;sharing costs 13&times;&rdquo; and moved on. In fact that ratio was two ratios multiplied together &mdash; the price of the <code>lock</code> prefix and the price of the sharing &mdash; and there was no way to separate them, because the version that would have separated them had already been deleted.</p>
                <p>The fix was to make rows A, B and C the same body with different addresses:</p>
                <div class="formula">
   A   lock xaddq to g_line[cpu][0]     each worker has
       its own 64-byte line              nothing shared

   B   lock xaddq to g_one[0]            BOTH workers hit
       the SAME long                     the SAME long

   C   lock xaddq to g_near[slot]        the SAME line,
       slot = 0 or 1                     TWO longs 8 bytes apart

   identical instruction.  identical register form.
   identical operands.  identical cores, identical
   iteration count, identical second.  the address is
   the only variable.
                </div>
                <p>And here is the alignment trap, which cost this course two of its own rows. The declaration that gives each worker a private line was, in the first version:</p>
                <div class="hex-dump">
                <pre>  /* WRONG -- and silent */
  static long g_line[MAXCPUS] __attribute__((aligned(64)));

  /* RIGHT */
  static long g_line[MAXCPUS][16] __attribute__((aligned(64)));
                </pre>
                </div>
                <p><strong>An attribute on a one-dimensional array is a statement about the array; a statement about the elements needs a two-dimensional one.</strong> The first version aligns the <em>start</em> of <code>g_line</code> to 64 bytes and then leaves every element eight bytes from its neighbour. Every &ldquo;one private line each&rdquo; row was a false-sharing row wearing a different label &mdash; and worse than that, it cost <em>more</em> than the genuinely shared row did, because two threads bouncing a line beats one line being hammered by both. The sixteen-long second dimension gives a 128-byte stride and guarantees that consecutive workers are on different lines.</p>
                <p>Three details of the model are worth separating from the numbers, because they are the difference between an experiment and a demo:</p>
                <div class="formula">
   PIN AND THEN VERIFY.  Each worker calls
   pthread_setaffinity_np, then immediately reads
   sched_getcpu() and stores it.  After the join, if
   either thread saw anything but the CPU it was asked
   for, the repetition is DISCARDED AND COUNTED, and
   the count is printed under the row.  Applied
   afterwards, the check cannot tell you WHY a thread
   was in the wrong place -- see R6.

   THE BODIES ARE INLINE ASM.  Rule 2 of the
   artifact, and the reason is the worst bug this
   collection has hit three times.  Written in C, a
   store to a variable nothing reads is provably dead
   and the optimiser deletes the whole loop.  An
   `asm volatile` store has no such door.

   INTERLEAVE AND TAKE THE MINIMUM.  Twelve logical
   CPUs are running other things and the machine is a
   virtualised guest.  Five repetitions per row, keep
   the best, and measure the spread of the estimator
   first (82.5% on the recorded run).
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the table, and the one ratio that is the course</h2>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/pinning to cpu2/,/and the one that matters/p'
   pinning to cpu2 and cpu4 (different cores), and to cpu2 and cpu3 (siblings)

  A  one private line each, 2 cores                3.66 ticks/op
  B  ONE shared line,        2 cores              47.76 ticks/op
  C  8 bytes apart, one line, 2 cores             39.98 ticks/op
  D  one private line each, 2 SMT sibs             3.93 ticks/op
  E  one private line each, 1 core                 6.73 ticks/op
  F  each opaque-loads the peer's line             2.33 ticks/op
  G  one private line each, 2 cores                3.00 ticks/op

      B / A   one shared line, true sharing        13.05x
      C / A   8 bytes apart, false sharing        10.92x
      D / A   SMT siblings                        1.07x
      E / A   both threads on one core            1.84x
      F / A   peer's line, no lock at all         0.64x
      G / A   plain store, nothing shared         0.82x

      and the one that matters:  B / C = 1.19x
 </pre>
                </div>
                <p><strong>B is 13.05&times; the floor. C is 10.92&times;. B/C is 1.19.</strong></p>
                <p>True sharing means both threads are updating the <em>same</em> long, so the value genuinely is shared and the algorithm genuinely depends on it. False sharing means they are updating two longs eight bytes apart, and <strong>not one value is read by anybody but its owner</strong> &mdash; the program is a textbook data-race-free parallel program, and it still costs 10.92&times;.</p>
                <p>Expected: B much larger. B contains all of C's cost <em>plus</em> a serialising dependency on the same word. Measured: <strong>they are the same to within a fifth.</strong> Therefore the cost of true sharing is not in the data. It is in the cache line, and every byte of B is a byte that padding could have bought back.</p>
                <div class="formula">
   IF B/C is near 1:   the cost is the LINE.
                      padding buys the whole thing back.
                      per-thread counters get padded, and
                      __attribute__((aligned(64))) is
                      not a micro-optimisation, it is the
                      fix for a measured factor of ten.

   IF B/C is large:   most of B's cost is the data
                      structure's, and padding buys back
                      only C's part.

   The artifact PRINTS which of the two shapes it
   measured rather than asserting one -- because which
   one you get depends on the body, the width and the
   clock, and that is exactly the kind of claim the
   harness refuses to freeze.
                </div>
                <p>And the number does move. Across the three recorded runs B/C came out <strong>0.97, 1.03 and 1.19</strong>. The shape held every time; the value did not. That is why the harness asserts a shape with a band and not a ratio &mdash; and it is the subject of the last concept.</p>
                <h3>Row D: the measurement refused to confirm the obvious story</h3>
                <p>The first draft said SMT costs a modest penalty here, because the shared L1 serialises. Measured, D is <strong>1.07&times; A</strong>. Two SMT siblings running a body that shares nothing cost the same as two cores running it, so <em>the shared L1 is not what SMT charges you for.</em></p>
                <p>What SMT does charge you for is the shared issue ports, and a latency-bound body like this one does not saturate them. So the conclusion the artifact is willing to print is much narrower than the one it started with:</p>
                <div class="hex-dump">
                <pre>   SMT is not free, and THIS EXPERIMENT DOES NOT SHOW
   WHAT IT COSTS.
                </pre>
                </div>
                <p>Row E is the one that does show a cost, and it is the only row here where the two workers were <em>asked</em> to be on the same core rather than merely landing there: <strong>1.84&times;</strong>. E is what D becomes on a machine with SMT switched off. Two threads that find each other on one core pay for it; two threads that are placed there deliberately pay more &mdash; because the scheduler no longer has anywhere to move them.</p>
                <h3>Row F: the row that was supposed to be slow, and is not</h3>
                <p>F is a ping-pong. Each worker stores to its own line and then opaque-loads the line the other one owns: two lines, two owners, a transfer every iteration. Written naively it should be the slowest row in the table. Measured it is <strong>0.64&times; A</strong> &mdash; <em>below</em> the no-sharing floor &mdash; and the reason is the store buffer.</p>
                <div class="hex-dump">
                <pre>   A store does not invalidate the other core's copy WHEN IT
   EXECUTES.  It goes into the store buffer and the other core's
   copy stays valid until the store RETIRES.  Two threads in a
   tight loop with no synchronisation therefore do not take turns:
   each runs ahead, each load often finds the peer's line still
   valid and shared, and the transfers that do happen are spread
   out rather than serialised.

   This is why a data race is hard to find, and it is worth more
   than the number it produced: THE FAST PATH AND THE SLOW PATH
   LOOK THE SAME ON AVERAGE.  A program with a race usually runs
   at full speed and gives the wrong answer once in a million
   times, which is exactly the profile of a heisenbug.
                </pre>
                </div>
                <p>Two things follow, and the second is worth more than the row.</p>
                <p>The first is a limit on the evidence: <strong>the artifact cannot count the transfers</strong>, because there is no PMU on this machine. What it can say is that F is not dramatically above A, and that a measurement which does not reproduce the expected shape is reporting something. F is below A partly because it has no <code>lock</code> and A does, and it is partly noise &mdash; which is exactly why the honest claim is a bound and not a number.</p>
                <p>The second is the sentence that makes this row worth a page of your time: <strong>the fast path and the slow path look the same on average.</strong> A racy program runs at full speed and gives the wrong answer once in a million times. That is not a bug you will find by looking for slowness, and it is the reason the tools that find races are checkers and sanitizers rather than profilers.</p>
                <h3>Row G, and the sentence about noise floors</h3>
                <p>G is row A with the <code>lock</code> removed. In this table they are indistinguishable &mdash; 0.82&times; &mdash; and the next concept shows the same two bodies costing 2.54&times; when nothing else is in the run. That is not a contradiction, and the artifact's explanation is the most useful thing in this table:</p>
                <div class="formula">
   THE COST OF A LOCK IS NOT A PROPERTY OF THE LOCK;
   IT IS A PROPERTY OF THE NOISE FLOOR OF WHICHEVER
   TABLE YOU MEASURED IT IN.
                </div>
                <p>Seven interleaved arms on a busy guest add more between-run noise than the lock costs &mdash; the estimator's own measured spread on this run was 82.5%. So the lock's cost is not in the noise of this table, and the two sections are separate for exactly that reason.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the fix, and the trap that hides the fix</h2>
                <p>The engineering consequence of a B/C of 1.19, 1.03 or 0.97 is a single declaration. A per-thread counter in a shared struct gets its own line:</p>
                <div class="formula">
   /* before: two counters, eight bytes apart, one line.
      a well-defined program with no data race in it,
      running 10.92x the no-sharing floor. */
  struct counters &#123; long c[2]; &#125;;

   /* after: one line each. */
  struct counters &#123;
      long c0 __attribute__((aligned(64)));
      long c1 __attribute__((aligned(64)));
  &#125;;

   /* and the version that is STILL WRONG, which is the
      trap the first draft of this artifact fell into: */
  static long g[2] __attribute__((aligned(64)));
   /*    ^ the array starts on a line boundary.
        g[0] and g[1] are eight bytes apart and share
        one line.  The attribute described the ARRAY. */
                </div>
                <p>That last one deserves the emphasis it gets in the artifact, because it is the same bug as the one in <a href="/courses/exe/lessons/exe-instrument">the execution course</a>, in a different costume: a benchmark function that was not 64-byte aligned measured a different quantity than it claimed to. <strong>There the code did not start where the compiler said it would; here the data does not land where the attribute says it will.</strong> Both are cases of a declaration that promises alignment and delivers it at the wrong granularity, and both are silent.</p>
                <p>And notice what the corrected version costs. It has made the struct sixteen times bigger and has reduced the number of counters that fit in a cache line from eight to one. <strong>Padding is not free and it is not always right</strong> &mdash; it is the right answer when threads write these fields concurrently and the wrong answer when they do not, which is why the fix belongs in a struct named for the job rather than in the general-purpose one.</p>
                <p>One more worked case, because the seven rows are not the only experiment here. The manifest's completion criterion is to take the 128-byte stride out of the private-line rows and watch the placement group of the harness fail <em>by name</em>. Doing that means row A stops being the floor and becomes row C: A, D and E stop being within a small factor of each other, and B/A and C/A stop both being far above it. <strong>The check is written on the shape, which is why the shape catches the edit</strong> &mdash; a harness asserting &ldquo;A is 3.66 ticks/op&rdquo; would just have gone quietly red.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the table and read B/C before you read anything else.</strong> <code>cd courses/smp/assets/samples &amp;&amp; ./build_samples.sh</code> then <code>./smpbench</code>. <em>Expect B and C to be within a small factor of each other and both to be more than three times A. If B/C comes out large &mdash; say five or more &mdash; the course is wrong or your machine is not the machine: check that the stride is 128 bytes, that the two cores are different core_ids, and that the pinned CPUs reported themselves correctly. If B/C comes out at or below 1, you have reproduced the run where C was marginally dearer than B, which is the same finding.)</em></li>
                    <li><strong>Make the fix and measure it.</strong> Change <code>g_line[MAXCPUS][16]</code> to <code>g_line[MAXCPUS][1]</code>. Rebuild. <em>(Expect row A, D, E and G to stop being a cluster and to sit near row C, and the harness's placement group to fail on the shape checks. Then put the stride back. The point of the exercise is not the speed &mdash; it is that the &ldquo;floor&rdquo; row is the one you control, and an experiment whose floor you can move is an experiment whose conclusions are about your alignment.)</em></li>
                    <li><strong>Sweep the distance between two counters instead of guessing where the cliff is.</strong> Two per-thread longs at offsets 0, 8, 16, 24, 32, 40, 48, 56 and 64 bytes, same body, same cores. <em>(Expect the cliff to be exactly at the line size from <code>/sys</code> and nowhere else, and to be a cliff rather than a slope. A gradient means your two addresses are not what the source says they are &mdash; which is the array-versus-element trap again, one level down.)</em></li>
                    <li><strong>Go looking for the stride in code you did not write.</strong> An array of per-thread accumulators indexed by thread id; a ring buffer whose head and tail indices are adjacent members of one struct; a <code>malloc</code>'d block of per-thread slots. <em>(Expect the compiler to be no help whatsoever. Nothing warns, because nothing is wrong: it is a legal, well-defined program that happens to make every access miss, and the only symptom is a number.)</em></li>
                    <li><strong>Reproduce row F's surprise, and then explain it in one sentence you could defend.</strong> Store to your own line, then opaque-load the peer's, in a tight loop, with no synchronisation. <em>(Expect it not to be the slowest row, and expect the explanation to be about the store buffer rather than about the coherence protocol. If your version <em>is</em> dramatically slow, look for a <code>volatile</code> read the compiler could not hoist and a store that is not in a buffer &mdash; and read the artifact's two silent bugs in <code>BODY_PING</code>, which are worth more than the row.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/smp/lessons/smp-topology">the topology concept</a> supplied the only thing that makes this table readable: the identity of the pairs. Every row here is a claim about cpu2 and cpu4, or about cpu2 and cpu3, and the pin is verified from inside each worker with <code>sched_getcpu()</code> and a failed repetition is counted rather than dropped. <strong>Read that concept first if you intend to trust these rows on a machine that is not this one.</strong></p>
                <p>Forward, <a href="/courses/smp/lessons/smp-atomic">the atomic concept</a> takes the same two cores and the same two configurations and removes the other thread from the picture, and finds that the locked instruction still costs 2.54&times; a plain store with nothing to lock against. That is not a contradiction of row G; it is the other half of the sentence about noise floors that ends this one. <a href="/courses/smp/lessons/smp-ordering">The ordering concept</a> then separates the two promises the prefix makes &mdash; atomicity, which is what this whole concept has been about, and ordering, which is the one thing here that cannot be measured from user mode at all.</p>
                <p>Outward, <a href="/courses/mem/lessons/mem-sharing">the memory course's sharing concept</a> is where this table's row C was first measured, at 61.9&times;, and where the term &ldquo;SMT sibling&rdquo; was used to throw rows away without being defined. <strong>It also has the same finding and a different emphasis: that course proved the effect by its size and inferred the mechanism from the price of an L3 transfer; this course proves the mechanism by measuring the case where there is no shared data at all and the cost does not go away.</strong> Together they are the strongest and the weakest forms of the same argument, and it is worth seeing both. <a href="/courses/mem/lessons/mem-verify">The memory course's harness concept</a> then does for its own two numbers what this course's last concept does for these seven, and it is the place to go if you want the general shape of the argument before the specific one.</p>
                <p>And <a href="/courses/exe/lessons/exe-instrument">the execution course's instrument</a> is the direct ancestor of the noise floor quoted here: 82.5% on the recorded run, which is why this table asserts orderings and shapes and the next concept measures the lock on its own with nothing else in the run.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-topology">A Claim About a Pair</a></span>
                <span>Next: <a href="/courses/smp/lessons/smp-atomic">A Lock With Nothing to Lock Against</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
