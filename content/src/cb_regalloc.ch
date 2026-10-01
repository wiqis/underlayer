// Compiler Backend: From IR to Machine Code -- concept 3: register
// allocation, three allocators, two deliberate bugs, and the one measurement
// in the whole collection whose machine runs the code it makes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_regalloc() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Register Allocation — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>Register Allocation</h1>
            <div class="lesson-meta">28 min &middot; Concept 3 of 6 &middot; module: three questions about a sequence &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>Naming values, and the question that is not &ldquo;which register is free&rdquo;</h2>
                <p>Selection gave you a sequence of machine operations. Now every value needs a register, and there are far more values than registers. That part is arithmetic. <strong>The hard part is that a register is a name with a lifetime</strong> &mdash; two values whose live ranges overlap cannot share a register, two whose ranges do not overlap can, and deciding which pairs overlap is the entire subject.</p>
                <p>There are three classic answers, all written here, all run on the same IR:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  linear scan     Braun/,/QUOTED A REPRODUCIBLE NUMBER/p'
  linear scan     Braun &amp; Hack, CACM 21(10) 1978.  Sorts intervals by
                  start point and needs NO interference graph -- only
                  the intervals, which can be built in one pass.
  Chaitin colour  Chaitin/Briggs/Panter/Scholz 1979.  Simplify, select,
                  spill, on a graph whose nodes are virtual registers
                  and whose edges are interference.
  colour, iterate  Greedy colour first, spill what will not colour,
                  repeat.  §KEEP§THE THIRD IS NOT IN THE TEXTBOOK AND
                  IT EXISTS HERE BECAUSE THE THREE SPILL COUNTS
                  DISAGREE, AND A COMPARISON THAT QUOTES ONE NUMBER
                  WITHOUT SAYING WHICH POLICY PRODUCED IT HAS NOT
                  QUOTED A REPRODUCIBLE NUMBER AT ALL.
                </pre>
                </div>
                <p>Linear scan needs <strong>no interference graph at all</strong> &mdash; it sorts intervals by start point and never builds the graph, so the graph&rsquo;s size never matters. That is a fact about complexity rather than about quality, and the page comes back to it, because it is the reason production backends use the algorithm that looks worse here.</p>
                <div class="callout callout-note">
                    <p><strong>MEASURED-ON-BYTES.</strong> Nothing in the three tables below was timed and nothing was executed. A register allocation is a <em>naming</em>, and a naming is checked by running the lowered program and reading each value back out of its physical location. The three per-kernel tables are those runs. The one timing section on this page is section 10 of the artifact and it is labelled separately, and it is the only place in this course where a machine runs anything.</p>
                </div>
            </div>

            <div class="unit unit-model">
                <h2>Three allocators, three spill counts, and what the ratio is about</h2>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/^  linear scan           58 spills/,/QUOTED A REPRODUCIBLE NUMBER/p'
  linear scan           58 spills across 36 allocations
  Chaitin colour       166 spills
  colour, iterate       45 spills

  the ratio Chaitin/linear is 2.86, and §KEEP§IT IS NOT A CLAIM
  ABOUT THE ALGORITHMS. §KEEP§IT IS A CLAIM ABOUT THE SPILL HEURISTIC,
  AND THE SAME GRAPH WITH A THIRD POLICY GIVES A THIRD NUMBER. §KEEP§THE
  HONEST SUMMARY IS: WHICH ALLOCATOR IS BETTER IS A PROPERTY OF YOUR
  CORPUS, AND A BACKEND THAT REPORTS "GRAPH COLOURING SPILLS N"
  WITHOUT NAMING THE POLICY HAS REPORTED NOTHING REPRODUCIBLE.
                </pre>
                </div>
                <p><strong>58, 166 and 45.</strong> The same IR, the same interference graph, three spill policies. The ratio between the first two is <strong>2.86</strong>, and the sentence that matters is the one after it:</p>
                <div class="formula">
   2.86 IS A FACT ABOUT THE HEURISTIC, NOT THE ALGORITHM

   Change the SPILL POLICY and you get a third number on
   the SAME GRAPH.  So "graph colouring spills 166"
   names neither a result nor a property of anything --
   it names one author's spill policy.

   The reproducible sentence has a noun in it:
     "our allocator, with the cost heuristic that picks
      the live range with the fewest uses in the loop,
      spills N on this input."

   WHICH ALLOCATOR IS BETTER IS A PROPERTY OF YOUR CORPUS.
                </div>
                <p>That is why the third allocator is here even though it is not in the textbook. <strong>A comparison that quotes one number without saying which policy produced it has not quoted a reproducible number at all</strong> &mdash; and a three-way comparison is the only way to demonstrate that inside one page, because with two allocators a reader cannot tell whether the difference is the algorithm or the heuristic.</p>
                <h3>Every &ldquo;yes&rdquo; is a checksum</h3>
                <p>Each kernel&rsquo;s table ends in a column that says <code>yes</code> nine times, and that word means something specific:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/every "yes" is a CHECKSUM/,/WAS THE THIRD BUG THIS FILE/p' | head -9
    every "yes" is a CHECKSUM, not a count: the program was
    lowered with the spills, run by cbir.step, and every virtual
    register's value read back out of its physical location at its
    last use.  §KEEP§THE READ-BACK IS AT THE LAST USE AND NOT AT
    THE END OF THE PROGRAM, BECAUSE A SPILL SLOT MAY LEGITIMATELY
    BE REUSED. §KEEP§READING IT AT THE END REPORTS AN ERROR IN A
    CORRECT ALLOCATION, AND THAT WAS THE THIRD BUG THIS FILE
    SHIPPED.
                </pre>
                </div>
                <p><strong>The read-back is at the last use, not at the end of the program</strong>, because a spill slot may legitimately be reused by a later value. Reading at the end reports an error in a perfectly correct allocation &mdash; and that was a real bug this artifact shipped, found because the column said <code>no</code> and the count said the allocation was fine.</p>
                <p>So: nine <code>yes</code> means <strong>every spilled value still held the right number in the right place when it was last needed.</strong> That is the only evidence that an allocation is correct, and it is worth noticing that it is a completely different kind of evidence from the spill count on the same row.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Two off-by-ones that fail in opposite directions</h2>
                <p>This collection has been bitten by <code>aligned(64)</code> six times: a boundary that is off by one in the direction that makes an interval look <em>shorter</em>. The register-allocation version is an interference edge built from a half-open live range when the machine&rsquo;s intervals are inclusive.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/    value    closed range/,/LOST 15/p'
    value    closed range    half-open range
    v0       [0, 12]        [0, 11]   &lt;- the loss
    v1       [1, 11]        [1, 10]   &lt;- the loss
    v2       [2,  8]        [2,  7]   &lt;- the loss
    v3       [3,  4]        [3,  3]   &lt;- the loss
    v4       [5, 14]        [5, 13]   &lt;- the loss
    v5       [6,  7]        [6,  6]   &lt;- the loss
    v6       [8,  9]        [8,  8]   &lt;- the loss
    v7       [9, 10]        [9,  9]   &lt;- the loss

    interference edges: closed 50, half-open 35, LOST 15
                </pre>
                </div>
                <p><strong>The direction matters and is not what a reader would guess.</strong> A half-open range is a <em>subset</em> of the correct one, so the buggy graph has <strong>fewer</strong> edges &mdash; which means it is easier to colour and more likely to succeed. And <strong>succeeding is the failure.</strong></p>
                <p>A document that said &ldquo;half-open ranges are wrong&rdquo; without saying which way would have taught its reader nothing, and the first version of <code>cbreg.py</code>&rsquo;s own docstring did exactly that.</p>
                <h3>Where the bug is invisible, and why the sweep goes down to 1</h3>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/    phys   correct alloc   half-open alloc/,/IT RETURNED A NUMBER/p'
    phys   correct alloc   half-open alloc   VERDICT
       1   WRONG           correct           the bug is INVISIBLE here
       2   WRONG           WRONG             the bug CHANGED THE ANSWER
       3   correct         WRONG             the bug CHANGED THE ANSWER
       4   correct         WRONG             the bug CHANGED THE ANSWER
       5   correct         WRONG             the bug CHANGED THE ANSWER
       6   correct         WRONG             the bug CHANGED THE ANSWER
       7   correct         WRONG             the bug CHANGED THE ANSWER
       8   correct         WRONG             the bug CHANGED THE ANSWER
      10   correct         WRONG             the bug CHANGED THE ANSWER
      13   correct         WRONG             the bug CHANGED THE ANSWER
      14   correct         WRONG             the bug CHANGED THE ANSWER

    the half-open allocator produced a WRONG ANSWER at 10 of 11
    pressures.  §KEEP§AND IT DID NOT RAISE, DID NOT CRASH, AND DID NOT
    PRINT ANYTHING ODD. §KEEP§IT RETURNED A NUMBER.
                </pre>
                </div>
                <p><strong>Ten of eleven pressures give a wrong answer. One gives the right one.</strong> And the sweep goes <em>below</em> the pressures the previous table used precisely because pressure 1 is the one at which the bug is invisible &mdash; a sweep that started at three would have reported nine of nine and called it detected.</p>
                <div class="callout callout-note">
                    <p><strong>The shape of a finding includes where it is not, and a finding with no hole in it is not yet a finding.</strong> This is the sentence that changed how this course reports. The number ten-of-eleven is more informative than eleven-of-eleven, and the way to get it was to <em>look for the pressure where the bug does nothing</em> rather than to sweep until it appeared everywhere.</p>
                </div>
                <p>And here is the finding that matters more than the count: the half-open graph has fewer edges, so it colours more easily, so <strong>it spills fewer values</strong>.</p>
                <div class="formula">
   THE SENTENCE THAT SHOULD END EVERY
   ALLOCATION REPORT

   A compiler that reported only the SPILL COUNT would
   be reporting a BETTER NUMBER for a WORSE ALLOCATOR.

   That is why every spill count in this course is held
   together by a checksum.  Not for rigor.  Because the
   count alone points the wrong way.

   AND IT IS ALSO WHY POISON 2 REQUIRES THE SIGN OF THE
   EDGE DELTA AND NOT ONLY THAT SOMETHING MOVED.
                </div>
                <h3>Bug 2: the coalescer, and the opposite direction</h3>
                <p>Coalescing merges a move-related pair when the two intervals do <em>not</em> overlap. With half-open ranges the source of a move at instruction <em>i</em> has a range ending at <em>i</em>&minus;1 and the destination begins at <em>i</em>, so <em>i</em>&minus;1 &lt; <em>i</em> and the merge happens &mdash; while the source is live at <em>i</em>, because the move <em>is</em> its use.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/   pressure   merged(closed)/,/OPPOSITE FAILURES/p'
   pressure   merged(closed)   unsound(closed)   merged(half)   UNSOUND(half)   checksum
          1               0                0              2               2   correct
          2               0                0              2               2   WRONG
          3               0                0              2               2   WRONG
          4               0                0              2               2   WRONG
          5               0                0              2               2   WRONG
          6               0                0              2               2   WRONG
          7               0                0              2               2   WRONG
          8               0                0              2               2   WRONG
         10               0                0              2               2   WRONG
         13               0                0              2               2   WRONG
         14               0                0              2               2   WRONG

  §KEEP§NOTE THE DIRECTION IN THAT TABLE: THE INTERFERENCE-GRAPH BUG
  LOSES EDGES, AND THE COALESCER BUG GAINS A MERGE. §KEEP§BOTH ARE THE
  SAME OFF-BY-ONE AND OPPOSITE FAILURES, AND A READER WHO HAS ONLY SEEN
  ONE OF THEM WILL NOT RECOGNISE THE OTHER.
                </pre>
                </div>
                <p>Read the two tables beside each other. <strong>The interference-graph bug loses edges. The coalescer bug gains a merge.</strong> Both are the same off-by-one, and a reader who has only seen one of them will not recognise the other &mdash; which is the argument for printing both on the same page instead of one per course.</p>
            </div>

            <div class="unit unit-example">
                <h2>The one measurement no other course here could take</h2>
                <p>x86-64 runs on this host. <strong>This is the first course in the collection whose machine executes the code it makes</strong>, and so it is the first that can put a <em>ratio</em> on the cost of a spill. Every other number on this page is a count; this one is a cost.</p>
                <p>Four arms, one function, four values forced through a stack slot. All four compute the same thing and all four must agree:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  arm   spilled   vs arm A   checksum/,/FOUR UNKNOWNS/p'
  arm   spilled   vs arm A   checksum
  A            0   1.00-1.25   5925179420309322629
  B            1   1.00-1.25   5925179420309322629
  C            2   1.00-1.25   5925179420309322629
  D            4   1.25-1.56   5925179420309322629

  ALL FOUR ARMS CARRY THE SAME CHECKSUM, so all four did the work,
  and the comparison is between four programs that compute the
  same number at different costs. §KEEP§A TIMING TABLE WHOSE ARMS
  DISAGREE IS NOT A COMPARISON, IT IS FOUR UNKNOWNS.
                </pre>
                </div>
                <p><strong>Four arms, one checksum, four costs.</strong> That is a comparison. A timing table whose arms disagree is not a comparison &mdash; it is four unknowns, and the section says so in those words.</p>
                <h3>And the cost of a spill is <em>not</em> a number</h3>
                <p>Read the band column again before you do anything else with it. Arms B and C &mdash; one spill and two spills &mdash; sit in <strong>the same band</strong>, and only arm D separates. The artifact does not leave that as a shape in a column; it states the verdict against a named reference and prints why:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  spilled   vs arm A   x arm A/,/THE COMPARISON THE REPORT MAKES/p'
  spilled   vs arm A   x arm A   vs the 1-SPILL arm
        1   1.00-1.25   AT THE REFERENCE
        2   1.00-1.25   INSIDE THE NOISE: not distinguishable from the 1-SPILL cost
        4   1.25-1.56   ABOVE THE NOISE: clearly more than the 1-SPILL cost

  §KEEP§THE VERDICT IS A RATIO AGAINST THE 1-SPILL ARM AND NOT A
  §KEEP§COMPARISON AGAINST THE FLOOR, §KEEP§AND THE FLOOR IS STILL
  §KEEP§PRINTED ABOVE BECAUSE IT IS THE HONEST STATEMENT OF HOW MUCH
  §KEEP§TWO INDEPENDENT ESTIMATES OF ONE ARM DISAGREE. §KEEP§§KEEP§ON
  §KEEP§THIS MACHINE, UNDER LOAD, THE FLOOR AND THE 4-SPILL
  §KEEP§DIFFERENCE OVERLAP, §KEEP§SO "DIFFERENCE &gt; FLOOR" IS NOT A
  §KEEP§QUESTION THIS MACHINE ANSWERS THE SAME WAY TWICE. §KEEP§THE
  §KEEP§4-SPILL ARM AGAINST THE 1-SPILL ARM IS, AND THAT IS THE
  §KEEP§COMPARISON THE REPORT MAKES.
                </pre>
                </div>
                <p><strong>So there is no &ldquo;cost of a spill&rdquo; on this page, and there must not be one anywhere.</strong> One spill and two spills cost the same measurable amount here &mdash; they are indistinguishable from each other &mdash; and going to four costs more than twice what going to one did. <strong>A cost that is not linear is not a cost you can divide by a count.</strong> Any sentence of the form &ldquo;a spill costs X&rdquo; is unsupported by this artifact, and the reason is not pedantry: it is that the machine is <em>hiding</em> the first one or two inside its own scheduler, and the fourth is where it stops hiding it.</p>
                <div class="formula">
   WHAT THE ALLOCATOR'S JOB ACTUALLY IS

   A compiler that spills ONE value is probably not
   worth the stores it burns.  One that spills FOUR is
   spending real machine time on memory traffic it
   chose.

   THE ALLOCATOR'S JOB IS NOT TO AVOID SPILLING,
   IT IS TO FIND THE POINT WHERE SPILLING STOPS
   BEING CHEAP.

   §KEEP§AND THE VERDICT IS TAKEN AGAINST THE 1-SPILL ARM AND NOT
   AGAINST THE FLOOR, BECAUSE ON THIS MACHINE UNDER LOAD THE FLOOR
   AND THE 4-SPILL DIFFERENCE OVERLAP. §KEEP§"DIFFERENCE &gt; FLOOR"
   IS NOT A QUESTION THIS MACHINE ANSWERS THE SAME WAY TWICE.
                </div>
                <h3>Why bands and not ticks</h3>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE LADDER IS GEOMETRIC/,/COULD NOT DISTINGUISH THEM/p'
  THE LADDER IS GEOMETRIC WITH RATIO 5/4, §KEEP§ RUNNING DOWNWARDS AS
  WELL AS UP, §KEEP§§KEEP§AND THAT DOWNWARD HALF IS NOT COSMETIC: §KEEP§A
  LADDER §KEEP§THAT ONLY GOES UP PUTS EVERY VALUE BELOW 1.00 IN THE SAME
  FIRST §KEEP§BAND, §KEEP§SO 0.35 AND 0.88 -- A FACTOR OF TWO AND A HALF,
  THE §KEEP§WHOLE POINT OF THE MEASUREMENT -- CAME BACK AS THE SAME
  ANSWER. §KEEP§A BAND LADDER THAT CANNOT DISTINGUISH THE NUMBERS
  YOU ARE ABOUT TO COMPARE IS NOT A ROUNDING, §KEEP§IT IS A LOSS
  OF THE MEASUREMENT, §KEEP§AND IT FAILS QUIETLY.
                </pre>
                </div>
                <p>The report prints a <strong>band</strong> rather than a number, and the exact ticks live in <code>cbbench.out</code> instead, for a reason that is worth stating plainly because it is the only reason this course&rsquo;s timing can be committed at all:</p>
                <div class="formula">
   WHY THE TICKS ARE IN A DIFFERENT FILE

   compback.out, run1.txt and run2.txt are BYTE-IDENTICAL.
   A report containing a CLOCK READING cannot be
   byte-identical between two runs.

   Those two facts cannot both be true in one file, so the
   report gives up the raw numbers and keeps the BANDS AND
   THE VERDICTS, and the raw numbers go to cbbench.out,
   which is committed and which a reader can re-run on
   their own machine.

   THE EXCEPTION IS WRITTEN DOWN RATHER THAN DISCOVERED BY
   A FAILED `cmp`.
                </div>
                <p>And the clock itself was checked before it was trusted &mdash; measured twice, once busy and once across a 400&nbsp;ms sleep, because a TSC is a fixed-rate counter and a tick is time only if the rate holds:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  TSC rate, busy/,/A DURATION BOUNDS A COUNT/p'
  TSC rate, busy               2.2957 GHz
  TSC rate, across sleep       2.2957 GHz
  the two agree to within      0.01 per cent
  §KEEP§AND A TICK IS TIME AND NOT CYCLES: §KEEP§NO NUMBER IN THIS COURSE
  IS A CYCLE COUNT AND NONE IS CONVERTED INTO ONE.
                </pre>
                </div>
                <p><strong>Two rates, measured two ways, agreeing to within 0.01 per cent.</strong> So a tick is time and not cycles, and <em>no number in this course is a cycle count and none is converted into one</em>. That is a small sentence that prevents an entire class of dishonest arithmetic.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Make the live ranges half-open and watch the spill count IMPROVE.</strong> <em>(Call <code>cbreg.build_interference</code> on <code>kernel_c</code> with closed ranges and then without. Edges go from <strong>50 to 35</strong>. The graph is easier, so it colours more easily, so it spills fewer. Every spill count in the allocator tables will look <em>better</em> with the bug in. Now read the checksum column: it says <code>WRONG</code>. <strong>That pairing is the whole exercise</strong> &mdash; a number that improved and a correctness verdict that got worse, from one character of interval notation.)</em></li>
                    <li><strong>Find the pressure where the bug does nothing.</strong> <em>(Re-run the sweep starting at pressure 1 rather than at 3. Pressure 1 is the one where the half-open allocator is <em>correct</em> while the correct allocator is <em>wrong</em> &mdash; the bug is invisible there. Ask why: with one physical register the graph cannot be mis-coloured, because there is nothing to mis-colour. <strong>A sweep that starts at 3 reports nine of nine and calls the bug detected.</strong> Add the pressure-1 row to your own harness and see whether it catches a different class of mistake.)</em></li>
                    <li><strong>Read the value back at the end of the program instead of at the last use.</strong> <em>(Change the read-back point in <code>cbreg.py</code> and re-run all four kernels. Expect the &ldquo;correct&rdquo; column to go to <code>no</code> while the spill counts stay exactly where they were. A spill slot reused by a later value makes the end-of-program read the wrong number, and the allocation was right all along. This bug shipped in this artifact and it is worth reproducing once, because <strong>a test that is wrong in the safe direction trains you to distrust correct results.</strong>)</em></li>
                    <li><strong>Re-run the timing on your own machine and check the shape of the answer.</strong> <em>(<code>cd courses/compback/assets/samples &amp;&amp; ./build_samples.sh</code>. Read <code>cbbench.out</code> first for the raw ticks and the two floors, then the verdict table in <code>compback.out</code> for the bands. Then check the thing that matters: <strong>are 1-spill and 2-spill separable on your machine?</strong> Here they are not. If they are on yours, the finding is about your machine and not about register pressure, and that is worth reporting rather than quietly accepting. Also look at the schedule comparison &mdash; hand-interleaving four independent chains came out <em>below the comparison floor</em>, and on a wide out-of-order core that is the expected result rather than a disappointment.)</em></li>
                    <li><strong>Add a fourth spill policy and watch the 2.86 move.</strong> <em>(Take <code>cbreg.py</code>&rsquo;s colouring allocator and change only its cost heuristic &mdash; spill the interval with the most uses inside a loop, or the one with the shortest remaining range. Re-run the totals. The number moves, the graph does not, and nothing about the algorithm changed. That is the demonstration behind the sentence &ldquo;which allocator is better is a property of your corpus&rdquo;, and it takes ten minutes.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/compback/lessons/cb-isel"><code>cb-isel</code></a> produced the sequence this pass names values in. The shapes are the same and the trap is the same one pass later: <strong>49 wrong machine forms did not fail, and a spill count that is too low does not fail either.</strong> <a href="/courses/a64abi/lessons/a64-frame"><code>a64-frame</code></a> and <a href="/courses/x86abi/lessons/x86-frame"><code>x86-frame</code></a> teach what a frame is once the allocator has decided there needs to be one &mdash; which is the subject of the next page in this course, because a backend has to know the callee-saved set <em>before</em> it allocates.</p>
                <p>Across architectures, <a href="/courses/exe/lessons/exe-latency"><code>exe-latency</code></a> is where you met that a store and a reload to the same slot is a round trip through the memory hierarchy. This page puts a ratio on it &mdash; and it is the <strong>first</strong> time this collection has done so, which is why the label on the timing table is different from the label on the allocator tables above it.</p>
                <p>Forwards, <a href="/courses/compback/lessons/cb-sched"><code>cb-sched</code></a> reorders what allocation produced and finds a schedule that is faster and wrong. And <a href="/courses/compback/lessons/cb-verify"><code>cb-verify</code></a> reads this pass&rsquo;s decisions back out of the finished bytes with no symbol table &mdash; and finds that it recovers the <em>consequences</em>, not the allocation.</p>
                <p>Outward, three things this page deliberately does not claim. <strong>The complexity numbers are QUOTED and not measured</strong>: linear scan is O(n&nbsp;log&nbsp;n) and the interference graph is quadratic in the worst case, with the papers named, and this course measures <em>neither</em> because both are properties of the input size and this corpus is twelve instructions. <strong>Saying so is cheaper than measuring it and it is true.</strong> And the timing section&rsquo;s own largest limit is the one worth carrying: the harness executes four <em>hand-written bodies</em> whose spill counts were decided elsewhere, so <strong>the number is the cost of the decision and not of a compiler that made it.</strong></p>
                <p>So the reusable lesson is narrow and specific, and it is the second time this collection has had to learn it: <strong>in register allocation, the metric points the wrong way under a whole class of bugs.</strong> Fewer spills means an easier graph, and an easier graph can mean a wrong one. Print the checksum, not just the count &mdash; and print where the bug is invisible, because a detector with no hole in it has not been tested.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback/lessons/cb-isel">Instruction Selection</a></span>
                <span>Next: <a href="/courses/compback/lessons/cb-sched">Instruction Scheduling</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
