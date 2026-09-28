// The Memory Hierarchy — Module 1: The Instrument
// Concept: the noise floor is the spread of the estimator, and at 11-36% on
// this machine it decides that every number here is a ratio.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_instrument() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Measure the Instrument, Then the Memory — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>Measure the Instrument, Then the Memory</h1>
            <div class="lesson-meta">25 min &middot; Module 1: The Instrument &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/exe/lessons/exe-instrument">The previous course ended</a> with an instrument that had been through eleven rounds of fixing and had five numbered rules written into its own source. It measured registers and instruction addresses, it never once loaded an array, and <a href="/courses/exe/lessons/exe-verify">its own harness says so</a>: the arithmetic results are real and almost irrelevant to most programs, because most programs are limited by their loads and their stores.</p>
                <p><strong>Pointing that instrument at memory adds one failure mode an arithmetic benchmark does not have.</strong> There are two obvious ways to write a memory benchmark, they are four lines of code apart, and on this machine they differ by <strong>38&times;</strong>:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/3. LINE/,/prefetcher/p'
     A 64 MiB working set, 1,048,576 lines, entirely outside
     every level of the cache:

     pointer chase, random order           131.468 ns     0.487 GB/s
     sequential sweep, +64 each time         3.463 ns    18.479 GB/s
     the prefetcher, by subtraction         37.96x
</pre>
                </div>
                <p>Both move 64 bytes per line, both touch the same 64 MiB, both end up at DRAM. The only difference is whether the address of the next access <em>can be computed</em> before the current one has returned. <strong>So the first thing this course has to establish is not a latency or a bandwidth: it is which of the two a given table is measuring</strong>, because neither number announces which it is and the wrong reading of either is perfectly self-consistent.</p>
                <p>The second thing is the noise floor, and this course measures it <em>about a different quantity</em> than the previous one did. <a href="/courses/exe/lessons/exe-instrument">That course</a> measured the spread of one run and reported 15%. Here the runs are noisier, the <em>estimator</em> is the thing being characterised, and the difference between the two numbers is a factor of 2&ndash;3:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py run1.txt 2&gt;&amp;1 | sed -n '/^  --- group B:/,/^  --- group C:/p'
  --- group B: the instrument's own limits
  [PASS] B instrument an estimator noise floor was measured                36.2%
  [PASS] B instrument min(B)/min(A) is shown to be the WRONG estimator     the ratio of minima does not cancel clock drift
  [PASS] B instrument the paired estimator is the one used                 divide inside the iteration, then take a minimum
  [PASS] B instrument all four estimators are in the table                 found 4 of 4
  [PASS] B instrument the artifact states the ordering is not stable       paired 19.6% vs ratio-of-minima 28.7% this run; the ordering is a property of the clock during this run, not of the estimator
</pre>
                </div>
                <p>A reader who takes the wrong quantity here gets a number that is too large by a factor of two and then loosens every tolerance in the course by hand to accommodate it, which is a mistake this collection has already made in print.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The five rules are inherited from the previous course, unchanged, because they are properties of the CPU and not of the benchmark. What is new is the sixth, and it is the one this course is organised around.</p>
                <div class="formula">
  1. A TSC TICK IS TIME, NOT A CYCLE.
     Calibrated twice against CLOCK_MONOTONIC --
     across a 200 ms sleep and across a 200 ms busy
     loop -- and if the two disagree the nanos below
     are wrong and you need to know that first.

  2. RDTSC IS NOT SERIALISING.
     LFENCE ; RDTSC ... RDTSCP ; LFENCE
     RDTSCP waits for prior LOADS, not for stores.

  3. INTERLEAVE.  A, B, A, B.
     A frequency ramp then perturbs both arms of
     every ratio equally, and the ratio is what is
     quoted.

  4. MINIMUM, NOT MEAN.
     A minimum converges, a mean measures the
     building's air conditioning.

  5. THE BODY IS WHAT IS MEASURED.

  6. AND HERE, THE BODY IS AN ADDRESS.
     If the next address is `base + i*64` you are
     measuring BANDWIDTH while believing you
     measured LATENCY, and nothing in the output
     says which. This is rule 5 applied to memory,
     and it is 38x.
                </div>
                <p>Rule 1 deserves the emphasis it gets, because this course has one more moving part in it than the last one did. The TSC is invariant at 2.2960 GHz. The <em>core</em> clock is not: sampled six times inside this section alone, it ranged <strong>1111 to 1923 MHz</strong> &mdash; a 73% swing. An L1 hit costs a fixed number of core cycles, so its cost <strong>in nanoseconds moves with that clock</strong>, and a table of absolute nanoseconds is therefore partly a table of what the clock happened to be doing. Ratios measured back to back divide the same clock out of both sides. That is the whole argument for rules 3 and 4, and it is why every table below has a ratio column and none of them has a cycle column.</p>
                <p>And an absolute table is not the only thing that suffers: <em>the noise floor itself moves by a factor of three between runs</em>, which is why the artifact quotes it, uses it, and never asserts it. An estimator whose spread is stable is a much simpler object to build a harness on than one whose spread is not, and the honest response is to make the tolerance a measurement rather than a constant. That is what every check below does.</p>
                <p>The instrument's second job is to build the addresses, and there is exactly one function that does it. The model is worth stating as arithmetic, because two later concepts are pure consequences of it:</p>
                <div class="formula">
  A LAYOUT is a permutation of n line indices, and the
  only place an address is computed:

      addr(i) = base + i*gap + off*(i mod 64)

  `gap` is the byte distance between consecutive line
  INDICES and `off` is an extra per-index displacement.
  The permutation decides the ORDER lines are visited
  in, which is what defeats the stride prefetcher.

  the L1 SET of line i, for off = 0:

      set(i) = (i*gap/64) mod 64

  so:
      gap = 64     spreads over all 64 sets
      gap = 4096   collapses to set 0      <- 4096 is
      gap = 4160   spreads again              sets*line

  4096 bytes is the aliasing stride, and that identity
  is the whole of concept 4.  It is also why the two
  layouts compared in concept 5 both use
  off = 64*(i mod 64): line i then goes to set i mod 64
  whatever the gap, so the two arms have the SAME set
  distribution and the only difference left is pages.
                </div>
                <p>And there is a self-check that has to exist, because the alternative is what this program did in its first version. <strong>A layout whose offsets collide visits fewer distinct addresses than it has indices, and every number derived from it is then wrong &mdash; while every self-check about the permutation still passes.</strong> The only way to see it is to walk the cycle and count distinct addresses:</p>
                <div class="hex-dump">
                    <pre>  long distinct_lines(base, n, gap, off) {
      p = base;
      for (i = 1; i &lt;= n; i++) {
          p = *(void**)p;
          if (p == base) return i;    /* closed on step i */
      }
      return -1;   /* did not close: the layout is broken */
  }

  a correct layout of n lines returns n.  a colliding
  one returns early, and the check that calls this is
  the one that catches the bug in the example below.
</pre>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported About Itself</h2>
                <p>Section 1 of the artifact is the instrument's own measurement, and the number it produces is a property of the <em>estimator</em> rather than of a run. Every figure this course quotes is a minimum over several attempts, so the quantity that a tolerance has to be applied to is how much a <em>minimum</em> moves when the whole procedure is repeated:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/1. THE INSTRUMENT/,/RATIO/p'
     The core clock, sampled from /proc/cpuinfo six times over      this section, ranged 1111 to 1923 MHz -- a 73% swing.
     An L1 hit costs a fixed number of CORE CYCLES, so its cost
     in NANOSECONDS moves with that clock, and the absolute
     spread below is mostly the clock rather than the memory.
     (A SAMPLE, not a live reading -- the previous course lost a
     factor of three by treating it as one.)

     The noise floor is the spread of the ESTIMATOR: the whole
     min-of-3 procedure, repeated 14 times, on the same 64-line
     chase.  This is the quantity every tolerance below is
     applied to, so this is the quantity worth measuring.

       14 min-of-3 values, 1.258 to 1.867 ns, mean 1.685
       spread about the mean:  36.2%   <-- the noise floor

     For contrast, the 42 INDIVIDUAL runs behind those minima
     run from 1.258 to 2.106 ns, a spread of 46.8% -- 1.3x
     worse.  Quoting that larger number is the mistake this
     section exists to correct, and it is a mistake the previous
     course made: it reported 15% for a quantity that is really
     this one, and then had to loosen tolerances by hand.
</pre>
                </div>
                <p>The three runs shipped with this course measured <strong>36.2%</strong>, <strong>25.3%</strong> and <strong>11.0%</strong> for that quantity, on an unchanged machine, within about ten minutes of each other. <strong>The noise floor is itself a noisy quantity</strong>, and that is the most important fact about it: it is measured per run and used as that run's tolerance, and it is never asserted to a value. A check of the form &ldquo;the floor is below 40%&rdquo; would fail one run in five on hardware that had not changed &mdash; which is the mistake <a href="/courses/exe/lessons/exe-verify">the previous course's verify concept</a> spends a section on, and it is a mistake that is much easier to make here because the floor is three times more variable than it was there.</p>
                <p>The second measurement in section 1 is the one that decides which estimator to believe, and the answer is not the one a textbook would predict. Ratios are supposed to cancel common-mode error, so a ratio of two back-to-back measurements ought to be steadier than either of its operands. Measured, it is not always:</p>
                <div class="hex-dump">
                    <pre>       estimator                           low       high   spread
       arm A alone (L1, ns)              1.345      1.786    27.1%
       arm B alone (L2, ns)             19.157     21.770    12.6%
       min(B)/min(A)                    11.543     15.239    28.7%
       min of PAIRED ratios              9.892     12.022    19.6%

     A REFUTED HYPOTHESIS, kept because it is the reason the
     estimator is the one below.  Ratios are supposed to cancel
     common-mode error, so a ratio ought to be steadier than its
     operands.  min(B)/min(A) is not: 28.7% here, against the L1
     arm's own 27.1%, and the gap widens when the clock is moving
     faster -- an earlier run of this same section had a core clock
     swinging 149% and gave 24.0% for the ratio against 17.0% for
     the arm.  The reason is structural, not accidental: one
     minimum is taken at one moment and the other at a different
     one, so the drift between them multiplies into the quotient
     instead of cancelling.

     The PAIRED estimator removes the reason rather than the
     symptom: divide inside the iteration, before the clock has
     moved on, and only then take a minimum.  19.6%, which is
     1.5x steadier than the ratio of minima.

     And HERE THAT WORD IS NOT GUARANTEED.  Across the runs
     this section has been through, the paired estimator was
     steadier about twenty times out of twenty-four, and worse
     the other four.  The ordering is a property of how hard the
     clock happened to be moving during a given run, not of the
     estimator: pairing is right by construction, because the
     division is the only place the two arms' clock drift can
     still cancel, but on a quiet run there is little drift left
     to cancel and the two estimators come out the same.  So a
     harness that asserted the ordering would fail on the quiet
     runs, and one that asserted the opposite would fail on the
     other twenty.  Assert the REASON, not the ordering.

     The tolerances use the WIDEST of the three spreads, 28.7%,
     rather than one of them by name.  This run's three are
     27.1% for the noisier arm, 28.7% for the ratio of minima
     and 19.6% for the paired one; the steadiest of them here
     is the paired one.  Which one that is MOVES between runs
     -- the paired estimator was steadier in about twenty runs
     out of twenty-four and worse in the other four, and that
     is a property of how hard the clock was moving rather
     than of the estimator -- so a sentence naming one of them
     is false on the next run, and a check asserting the
     ordering fails on a quiet clock.  Take the widest, and
     assert the reason rather than the ordering.
</pre>
                </div>
                <p>Two things there are worth naming separately. <strong>First, the ratio of minima came out worse than its noisier operand</strong> &mdash; 28.7% against 27.1% &mdash; and the reason is structural rather than accidental: one minimum is taken at one moment and the other at a different one, so the drift <em>between</em> them multiplies into the quotient instead of cancelling. The paired estimator removes that reason by dividing inside the iteration, before the clock has moved on. <strong>Second, the paired estimator is not reliably the better one either</strong>, which is why the artifact quotes the widest of the three as its tolerance and the harness asserts the reason rather than the ordering. A check that asserted the textbook ordering would fail on about one run in six.</p>
                <p>Section 0 comes first because it establishes the limit the whole course is bounded by. There is no hardware performance counter in this guest, and the artifact <em>proves</em> it rather than assuming it &mdash; by forking a child that executes <code>RDPMC</code> and reporting the signal the child died from:</p>
                <div class="hex-dump">
                    <pre>     no performance counters: a forked child executed RDPMC and
     died of signal 11 (SIGSEGV: the kernel delivers #GP as a fault).
     So no miss, no fill, no walk and no stall can be COUNTED
     here.  Every number below is bounded by timing instead.
</pre>
                </div>
                <p><strong>That sentence is the course's ceiling.</strong> It means a table can show that a footprint became slower at a particular size, and cannot show that a particular line was missed; it means the prefetcher can only be measured by <em>subtraction</em>; and it means the replacement policy cannot be observed at all, only its consequences. Every &ldquo;limit&rdquo; later in this course is a special case of it. Running it in a forked child is not politeness either: the first version of section 0 executed <code>RDPMC</code> in the parent and killed the benchmark, taking every measurement with it.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading a Microbenchmark's Claims</h2>
                <p>What the discipline buys, stated as things you can now do that you could not before:</p>
                <div class="formula">
  YOU CAN NOW:

    tell a LATENCY measurement from a BANDWIDTH
    one by looking at whether the address is
    data-dependent, which is the only difference
    between 131 ns and 3.46 ns of the same traffic

    quote a ratio between two arms measured back to
    back even at a 36% floor, because both sides
    divide by the same clock

    recognise a MEASUREMENT OF A MEASUREMENT: a
    noise floor, a sample of /proc/cpuinfo, a
    perf counter that does not exist

    count the distinct addresses a layout touches,
    instead of trusting a permutation to be a cycle

  YOU STILL CANNOT:

    count a miss, a fill, a page walk or a stall
    say which line was evicted, or why
    report an absolute cycle count
                </div>
                <p>The layout bug deserves its own telling, because it is the sharpest example in the collection of a wrong number that passes every self-check. The function that computes addresses is called <code>layout_of(base, n, gap, off)</code>, and an early version passed <code>off = 64</code> with a stray <code>* 64</code> inside the expression, so the displacement was <code>64*(i mod 64)</code> bytes &mdash; which is <code>128i</code> for <code>i &lt; 64</code>. Line 32 then landed on line 64's address and line 64 on line 128's:</p>
                <div class="hex-dump">
                    <pre>       addr(i) = base + 64*i + 64*(i mod 64)

       for i &lt; 64:   addr(i) = base + 128*i
       so line 32 == line 64, line 64 == line 128, ...

  a "256 MiB" layout really touched a few megabytes,
  and reported 8 ns per access -- which is an L1
  number for a working set that cannot fit in an L1.

  the permutation still visited every INDEX, so every
  self-check about the permutation passed, and the
  table was nonsense.  the only thing that caught it
  was that a 256 MiB footprint cannot be 8 ns.
</pre>
                </div>
                <p>The same bug then reappeared in a different form &mdash; <code>4096*(i mod 64)</code>, the same stray factor in the same expression &mdash; and produced a translation table whose cost was <strong>high for 32 pages and low for 72</strong>, the exact inverse of the truth. That table was in an earlier draft of the translation concept. What caught it was not a check about layouts: it was that the table was <strong>non-monotonic where the arithmetic says it must rise</strong>. The rule that survives is in the artifact's own comment: <em>a non-monotonic table is not noise; it is a signal that the layout is not what the caption says it is.</em></p>
                <p>And the second class of bug is the one that has no self-check at all. The line-granularity walk used a hard-coded register inside an extended-asm template, on the reasoning that a scratch register inside inline asm is a temporary:</p>
                <div class="hex-dump">
                    <pre>       movl (%[p]), %%eax     /* looks like a scratch reg */
       addq $4, %[p]
       dec  %[c]
       jnz  1b

  what the compiler actually emitted:  %rax had
  already been given to the loop counter.

       mov    -0x18(%rbp),%rax      &lt;- the counter, 4194304
       mov    (%rdx),%eax           &lt;- CLOBBERS the counter
       add    $0x4,%rdx
       dec    %rax

  so the walk ran until some 4-byte word in the region
  happened to be zero.  two earlier "fixes" made it
  worse: an earlyclobber marker on p MOVED the
  collision instead of removing it, and a
  literal-immediate stride removed one hazard and left
  this one.  the rule, learned in three attempts:

    every register an asm template NAMES must be
    either a declared operand or a declared clobber,
    and there is no third case.
</pre>
                </div>
                <p>Both bugs have the same shape as the ones <a href="/courses/isa/lessons/isa-decode">the ISA course's decoder</a> hit: <strong>a mechanism with no error path.</strong> A permutation that visits every index looks correct from the outside; a register the assembler accepts looks allocated from the outside. The defence is not care, it is a check that is *about the thing that broke* &mdash; which is <code>distinct_lines()</code>, the function in the model above that counts addresses instead of trusting a count of iterations.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./build_samples.sh              # build, run, cross-check
$ python3 crosscheck.py           # 109 checks, 9 groups
$ ./membench 2&gt;&amp;1 | sed -n '/0. THE MACHINE/,/group A/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group B:/,/^  --- group C:/p'
</pre>
                </div>
                <p>Then measure the instrument on your own machine, which is the exercise that matters:</p>
                <div class="hex-dump">
                    <pre>  1. Find YOUR noise floor, on the estimator and
     not on a run. Write a 60-line program that
     times the same chase 3 times and keeps the
     minimum; do that 14 times; report the spread
     of the 14 minima. Then compute the spread of
     the 42 individual runs and compare.

     (Expect the second number to be LARGER, by
     a factor of one to three. If it is smaller
     something is wrong with the first.)

  2. Now the one that decides the rest of the
     course. In the same program, measure the
     SAME 64 MiB working set two ways: a shuffled
     permutation of line indices, and a plain
     `+64` walk. Compare.

     (Expect a factor of tens. Both are "reading
     64 MiB". Neither number is wrong: one is a
     chain of dependent loads and the other is a
     stream.)

  3. Break the layout deliberately and watch the
     check that exists for it fail. In layout_of(),
     change the permutation write to

       base + c*64 + 64*(c % 64)

     and rebuild.

     (Expect a 256 MiB row at L1 speed, and group
     B's "every layout touches exactly the lines it
     names" to FAIL, naming the count it walked.
     This is the only check in the program that
     would catch it, and it is worth seeing what
     it looks like when it fires.)

  4. Drop one of the LFENCEs from tsc_begin() and
     re-measure. The numbers get SMALLER, not
     larger, and they get smaller unpredictably.
     That is the cheapest way to publish a wrong
     number and the hardest to notice.

  5. Check whether YOUR machine has a PMU, because
     it changes what you can claim:

       cat /proc/sys/kernel/perf_event_paranoid
       ls /sys/bus/event_source/devices/
       perf stat -e cache-misses,cycles true

     If cache-misses works you can COUNT a miss,
     which turns every "bounded by timing" in this
     course into a measurement. Do that, and then
     work out what the number is: a miss count is
     a property of your program as well as your
     machine, and it changes when the layout does.
</pre>
                </div>
                <p>Exercise 3 is the one that makes the habit, because the result is one you can produce at will: <strong>the failure is invisible in the measurement and visible only in a check that counts the thing the measurement assumes.</strong> The table it produces looks like a beautiful hierarchy curve; the only anomaly is a 256 MiB footprint at 8 ns, and a reader who does not know what an L1 hit costs will not notice. That is why the check is in the artifact rather than in the harness: it has to run every time, on the machine, and not only when someone remembers to run a checker.</p>
                <p>Exercise 5 is the one that decides what the rest of this course can say. <strong>If your machine has a PMU, you can finish sentences this course has to leave open</strong> &mdash; how many of the accesses missed, whether the L3 plateau is a miss rate or a queue, whether the prefetcher count is a stream count. The honest form is not to pretend the instrument would still be needed; it is to say which claims each machine permits, and to notice that a miss counter makes the <em>inference</em> in <a href="/courses/mem/lessons/mem-latency">the next concept</a> unnecessary.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent is <a href="/courses/exe/lessons/exe-instrument">the previous course's instrument concept</a>, and the inheritance is literal: five numbered rules, the fence pair, the alignment discipline, and the habit of measuring the instrument before the machine. <strong>What this course adds is the estimator table.</strong> That concept established that a ratio survives a moving clock; this one measures <em>how much</em> a ratio survives it, finds that the answer is &ldquo;less than the textbook says, and not in a fixed order&rdquo;, and reacts by taking the widest of three spreads as the tolerance instead of naming an estimator. That is a refinement of a method rather than a new one, and it is worth separating from the memory material because it transfers to every measurement in the rest of the collection.</p>
                <p><a href="/courses/exe/lessons/exe-verify">The harness concept</a> is the other half of the inheritance, and this course pushes its central idea one step further. That concept's rule was <em>assert shapes, not values</em>, because a 15% floor cannot verify a value. Here the floor is up to 36% and <em>varies by a factor of three between runs</em>, so a shape is all that can be asserted at all &mdash; and one claim in this course turns out to be so dependent on the machine's configuration that the right thing to do is withdraw it and check that the withdrawal happened. That is the subject of <a href="/courses/mem/lessons/mem-verify">the last concept</a>.</p>
                <p>The connection to <a href="/courses/obj/lessons/obj-verify">the object course's oracle loop</a> is a difference worth stating plainly, because it looks like the same idea and is not. That course verified its reader by running <strong>three independent readers on bytes</strong>, and three-way agreement on bytes is nearly proof, because bytes have no noise. <strong>Here there are no bytes to agree on.</strong> The only second opinion available is a different <em>estimator</em> on the same times, and this concept measured that the two estimators disagree about which of them is steadier &mdash; so an &ldquo;agreement&rdquo; between them is a statement about the clock, not about the machine. The discipline that replaces three-way agreement is: measure the instrument, state the shape, assert the shape, and name the limit.</p>
                <p>And the connection forward is the shape of the whole course. <strong>This concept established the two kinds of memory measurement and the arithmetic of the layout function.</strong> The next concept is the first place that distinction pays: the same 64 MiB, the same machine, the same DRAM, measured at 131 ns a line one way and 3.46 ns the other, with the difference attributed to the prefetcher by subtraction because there is no counter to read it from.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-verify">Previous: The Instrument and the Oracle Loop</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-latency">A Chase and a Sweep Are Different Questions</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
