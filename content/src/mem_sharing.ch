// The Memory Hierarchy — Module 4: Sharing, and Verification
// Concept: two threads, two counters, one line — the one coherence-adjacent
// effect this machine can measure without a PMU, plus the retraction of a
// null result that came from a benchmark that was not running.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_sharing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Threads, One Line — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>Two Threads, One Line</h1>
            <div class="lesson-meta">22 min &middot; Module 4: Sharing and Verification &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept measured what a store costs when the line it needs is nowhere in particular. On a machine with more than one core, that is the easy case. <strong>The hard case is a store to a line that lives in somebody else's cache</strong>, because the other core's copy is now wrong, and something has to notice.</p>
                <p>Here is the experiment that isolates it, and the reason it is worth a concept of its own: two threads, each incrementing <em>its own</em> counter five million times. No variable is written by both threads. No byte of memory is read by one and written by the other. Under the language's memory model the program is entirely well-defined, with no data race anywhere in it. But the two counters are eight bytes apart &mdash; inside one 64-byte cache line &mdash; and the same counters laid out 64 bytes apart instead run at a different speed by a factor that has two digits.</p>
                <div class="formula">
  two threads, two counters, 5 000 000 stores each
  nothing shared -- not one byte

  8 bytes apart   (one cache line)    tens of ns
                                        per iteration
  64 bytes apart  (two cache lines)   under half a ns
                                        per iteration
                </div>
                <p>The mechanism has a name &mdash; <strong>false sharing</strong> &mdash; and the adjective is doing real work in it. The sharing is false because it is not in the program: it is in the hardware's choice of a 64-byte line as the unit of cache ownership. A cache does not track what a program reads and writes; it tracks lines. To write a line it must own it exclusively, so if two cores hold the same line and both want to write, the line is passed back and forth, and every access by either core misses. <strong>Two variables that the programmer carefully separated end up sharing a transfer that costs an L3 round trip or worse, once per iteration.</strong></p>
                <p>Three reasons this belongs in a course about producing an executable. First, it is a performance effect with a <em>fix that is entirely in the source</em> &mdash; padding and alignment &mdash; and the fix is invisible unless you know the line size, which is the kind of number the earlier concepts in this course read out of <code>/sys</code>. Second, it is the one coherence effect measurable on a machine with no performance counters, because it does not need to count invalidations: it needs two threads and a clock. And third, it is where a course like this one is most tempted to lie, because the mechanism (a line being invalidated and re-fetched elsewhere) is <em>not observable here</em> &mdash; it is inferred from a factor of seventy. The concept is written to be explicit about which of its statements are which.</p>
                <p>One definitional point before the numbers, because the confusion is common and expensive. <strong>False sharing is not a data race.</strong> A data race is two threads accessing the same object, at least one writing, with no synchronisation, and its consequence is undefined behaviour &mdash; a program that may print anything. False sharing is the opposite: a program whose every access is well-defined and whose <em>cache misses</em> are inflated by a layout choice. Nothing here is fixed by a mutex or an atomic, and adding one would be strictly worse; the fix is to stop putting the two objects in one line.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Both arms of the experiment run the same trained loop, in two threads started together at a barrier, each on its own pointer:</p>
                <div class="hex-dump">
                    <pre>  for (i = 0; i &lt; 5000000; i++) {
      v = v + tgt[0];
      tgt[0] = v;
  }

  each iteration is a LOAD and a STORE of the same
  8-byte word -- a read-modify-write chain that cannot
  be reordered or deleted (the target is volatile, so
  the compiler may not fold it away)

  arm A: thread 0's tgt and thread 1's tgt are 8 BYTES
         apart  ->  the same 64-byte line
  arm B: 64 BYTES apart  ->  adjacent, distinct lines
</pre>
                </div>
                <p>The model's first job is to say why the two arms should differ at all, since the two threads touch disjoint bytes. It is the <em>ownership</em> rule: a write needs the line in a state that no other core holds, and each write by the other thread takes it away. So the two arms are two different machines:</p>
                <div class="formula">
  ARM B (one line each)
    the line is in the local L1 and stays there
    no traffic, no coherence, just a store-forward
    -- and the chain is a few cycles per iteration

  ARM A (one line between them)
    thread 0 writes -> invalidates thread 1's copy
    thread 1 writes -> invalidates thread 0's copy
    every iteration of both threads is a MISS, and
    the fill has to come from wherever the other
    core left the line
                </div>
                <p>The model now makes a prediction that is more specific than &ldquo;slower&rdquo;, and the specificity is what makes it worth writing down. The line is resident in the <strong>last-level cache</strong>, which this machine's own hierarchy concept measured at 16 MiB. A transfer inside that cache should therefore cost something near the L3's own band &mdash; the 19 to 25 ns that concept measured &mdash; and <em>not</em> the 150 ns a DRAM access costs. So:</p>
                <div class="formula">
  if each iteration went to DRAM:     150 / 0.43  ~ 350x
  if each iteration is an L3-to-core
  transfer of a line the cache holds:  25 / 0.43  ~  58x

  measured on this machine:            ~ 71x

  so the prediction to carry into the table is not
  a number but a BOUND: tens of times, and NOT the
  hundreds a memory round trip would produce.
                </div>
                <p>That bound is the honest form of the claim for a reason specific to this machine: with no performance counters, nothing here can observe an invalidation or a transfer. The measurement is a factor and the explanation is a mechanism whose <em>size</em> can be predicted, which is a weaker but still falsifiable position. If the ratio had come out at 350&times; the ping-pong explanation would have been wrong in the direction of the line living in DRAM; at 71&times; it is consistent with a line that never leaves the shared cache.</p>
                <p>Two implementation decisions belong in the model because both are about whether the measurement means what it says. <strong>First, the two threads are not pinned.</strong> The program asks the kernel for logical CPU ids with <code>sched_getcpu()</code>, and reads each one's physical <code>core_id</code> out of <code>/sys/devices/system/cpu/cpuN/topology/</code>, and then <em>marks and excludes</em> the rows where both threads landed on the same physical core: two SMT siblings share L1 and L2 and are a different measurement, not a noisy version of the same one. That check ran on every row of every run quoted below, and it is printed in the artifact rather than done silently. <strong>Second, the exclusion is enforced in two places:</strong> the artifact excludes marked rows when it computes its summary, and the harness parses the marker and excludes the same rows, so the printed number and the asserted number cannot drift apart.</p>
                <p><strong>And one limit that neither of them can fix:</strong> the CPU id is sampled <em>once</em>, before the loop. A thread that migrates mid-run would be mislabelled, and a host whose scheduler is busy will do exactly that. It is a real hole in the evidence, it is stated here rather than discovered later, and the defence is to run the experiment more than once &mdash; which is why three separate runs are quoted below instead of one.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>Seven repetitions of the whole two-thread experiment, minimum of each arm, nanoseconds per iteration, with the logical CPUs the threads were found on:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/7. SHARING/,/group F/p'
        run   8 B apart ns       cpus  64 B apart ns       cpus      ratio
          0         33.879    0,7             0.443    0,6        76.56x
          1         33.630    0,6             0.445    0,7        75.52x
          2         36.544    8,7             0.538    6,10       67.90x
          3         34.839    8,6             0.503   10,2        69.31x
          4         30.792    0,2             0.481    6,0        63.96x
          5         44.713    9,0             0.432   10,0       103.43x
          6         48.064    9,0             0.635    6,0        75.68x

     A row marked * put the two threads on the SAME physical
     core, checked against core_id in /sys.  0 of the 7 rows
     are marked.

     Every run put the two threads on different physical
     cores, so no row needed excluding.

     And over the 7 verified runs: 30.792 ns versus 0.432 ns,
     a factor of 71.2.  The WORST of the verified runs is 64.0x,
     so the claim does not rest on a lucky minimum.

  --- group F: false sharing is not a data race
      [PASS] the two counters' lines matter enormously      no data is shared; only the line is
      [PASS] the summary rests only on runs verified to be on two cores 7 of 7 runs verified against core_id in /sys; the worst of those is 64.0x
</pre>
                </div>
                <p>Five readings, and then the number the three runs give together.</p>
                <p><strong>The effect is not subtle and it is not marginal.</strong> Every one of the seven rows puts the near arm between 30.8 and 48.1 ns per iteration against 0.432 to 0.635 for the far arm. There is no row where the two arms overlap, no row where the effect is a trend rather than a cliff, and nothing in the table that needs a tolerance to be visible. <strong>This is the largest number in the course, and the smallest working set in it</strong> &mdash; sixteen bytes of data between the two threads, against the 64 MiB that the latency concept's chase walked to find a 38&times; difference.</p>
                <p><strong>The size of the ratio is itself evidence, and it is evidence of the kind this course prefers: it is bounded by the numbers already measured here.</strong> 30 to 48 ns per iteration is the L3 band from the hierarchy concept (19 to 25 ns for a chase) plus the loop's own store-and-forward cost. It is nowhere near the 150 ns that concept measured for DRAM. A machine that lost the line to memory on every iteration would have produced a factor near 350&times;, and it produced 71&times;. <strong>So the line is being passed between the two cores inside the shared cache, never leaving the chip</strong> &mdash; which is exactly what the model predicts, and is as far as the measurement can go: the transfer itself was not observed, it was inferred from its price.</p>
                <p><strong>The far arm's absolute value is at the floor of what the instrument can resolve, and this course does not explain it.</strong> 0.432 to 0.635 ns per iteration straddles <code>0.4356 ns</code>, which is one tick of the counter that measured it, reported by the first concept of this course. That is about one to two core cycles for a dependent load-and-store pair, and the honest reading is that the far arm is running at the speed of a store-to-load chain in the local L1 with the loop overlapped around it. <strong>Nothing in this concept depends on that number's explanation, which is precisely why the claim is a ratio:</strong> whatever the fast arm's cost is made of, it is made of the same thing on both arms, and the difference is the line.</p>
                <p><strong>No run needed the same-core exclusion, and the fact that it was checked anyway is the load-bearing part.</strong> Three separate runs of this section, seven rows each, 21 rows in total, and not one put the two threads on a single physical core. That is reported because it establishes the precondition of the measurement, not because it is interesting: had a row been marked, the correct response would have been to exclude it from the summary and still print it, which is what the artifact and the harness both do. <strong>A benchmark that measures the wrong thing does not usually announce it, and an exclusion that is applied silently is indistinguishable from data being dropped because it was inconvenient.</strong></p>
                <p><strong>And the claim is bounded by the worst run, not the best one.</strong> Across the three runs captured for this course the best-row factor was 71.2&times;, 89.5&times; and 91.5&times;, and the <em>worst verified row within each run</em> was 64.0&times;, 67.5&times; and 65.1&times;. The spreads overlap; the ordering of the runs is not stable; and the number that survives all of that is a floor. <strong>The course therefore claims at least 60&times; and does not claim 71&times;</strong>, because 71 was one run's minimum-of-minima and a reader on their own machine has no reason to reproduce it. This is the same discipline that produced the band-not-a-number lesson in the hierarchy concept, applied to a ratio instead of a latency: the run-to-run spread here is 71 to 92, which is 30%, which is the instrument's own noise, and a claim that quotes any single value inside that band is quoting noise.</p>
            </div>

            <div class="unit unit-example">
                <h2>&ldquo;False Sharing Has No Effect Here&rdquo;</h2>
                <p>The retraction this concept carries is the most dangerous kind of wrong result, because it was <em>a null result from an experiment that was not running</em>, and because the null result agreed with a plausible prior. The first version of this section concluded that false sharing did not matter on this machine. Two things were wrong with the benchmark, and neither of them was the measurement:</p>
                <div class="hex-dump">
                    <pre>  BUG 1  both threads were READING one counter.
         a line that is only read is SHARED, not
         invalidated -- so there was no ownership
         traffic to measure, and the run confirmed
         the design rather than the hypothesis.
         the two targets must be written by
         different threads, which is the whole point.

  BUG 2  two pthread_barriers of count 2, with
         one waiter each.  thread 0 waited on
         barrier A, thread 1 on barrier B, and
         each barrier was waiting for the other
         thread.  the benchmark did not finish.  it
         did not fail, either: it stopped, and a
         stopped benchmark produces no output at
         all, which is why the first run's
         "conclusion" was written against no data.
</pre>
                </div>
                <p>Both were fixed, and the fix to the second was not a tweak: <strong>the gate had to be one barrier with both threads waiting on it</strong>, which is what the artifact contains now. The general lesson the collection keeps arriving at applies exactly here: <em>a check that fails for the wrong reason is worse than no check.</em> This was not a failing check, though &mdash; it was worse. <strong>A benchmark that hangs produces a null result, and a null result with a plausible prior explanation is accepted.</strong></p>
                <p>What made the null result plausible is worth stating plainly, because it is the reason this retraction is in the course rather than in a footnote: &ldquo;false sharing is not worth worrying about on modern hardware&rdquo; is a sentence a reader may already believe. <strong>A measurement is most likely to be accepted without scrutiny when it agrees with what its reader already thought</strong>, which is the mechanism by which a deadlocked benchmark became a finding. The defence that caught it was not a counter or a bigger sample; it was noticing that the near arm's cost was also around half a nanosecond, which meant the <em>fast</em> arm and the <em>slow</em> arm were being measured under the same conditions &mdash; and that can only happen if the conditions were not what the code said.</p>
                <p>There is a second, smaller lesson from the same section, and it is about instrumentation rather than measurement. Once the benchmark worked, the question immediately arose of whether the two threads were on different cores &mdash; and the artifact's answer was to check and record rather than to pin. <strong>Pinning to two known cores would have been easier and would have removed the failure mode entirely.</strong> It was rejected because a pinned benchmark answers a narrower question than the one being asked: the interesting claim is about a program that two threads run, and a program that runs them on whichever cores the scheduler chooses. The precondition is therefore <em>verified</em> per row, printed per row, and excluded per row &mdash; three extra pieces of machinery to keep a measurement honest that pinning would have made unnecessary and less true.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/7. SHARING/,/8. WHAT/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group G:/,/^  --- group H:/p'
</pre>
                </div>
                <p>Then five exercises, in the order that makes the mechanism stop being a word:</p>
                <div class="hex-dump">
                    <pre>  1. Reproduce the cliff with your own two
     threads and a single array of counters, and
     sweep the distance between them: 8, 16, 32,
     64, 128 bytes. The cliff is at the line size
     from /sys and nowhere else.

     (Expect the effect to vanish EXACTLY at the
     line size, not gradually. If it is gradual,
     your two targets are not where you think.)

  2. Make the fix and measure it. Pad the
     per-thread counters to 64 bytes:

       struct alignas(64) counter {
           volatile long v; char pad[56];
       };

     (In C++17 the portable constant is
     std::hardware_destructive_interference_size,
     which is the line size as the implementation
     understands it. Accepting the libstdc++
     ABI-warning is cheaper than hardcoding 64.)

  3. Scale it. Put FOUR counters in one line and
     run four threads; then eight.

     (Expect it to get worse, then to get no
     worse -- with more writers the line moves
     more often per unit of work, but the
     per-transfer cost is the same. The place it
     gets no worse is where the line is being
     transferred as fast as the coherence protocol
     will move it.)

  4. Compare against the honest alternative. Run
     the same two-thread loop with an atomic
     increment on a genuinely shared counter, and
     time it.

     (Expect it to be in the same band as the false
     sharing case, because a true atomic increment
     also requires exclusive ownership of the line
     per write. This is the measurement that shows
     the false-sharing penalty is not an
     "overhead": it is the price of the transfer,
     and true sharing pays it too.)

  5. Look for it in real layouts, where the bug is
     a stride and not a struct: an array of
     per-thread accumulators indexed by thread id;
     a queue whose head and tail indices are
     adjacent members; a counter array inside a
     single malloc'd block.

     (Expect the compiler to be no help at all.
     Nothing warns about this, because nothing is
     wrong: it is a legal, well-defined program
     that happens to make every access miss.)
</pre>
                </div>
                <p>Exercise 5 is the one that pays, and its awkwardness is the point. The fix is padding, the padding is invisible in the source, and the bug is <em>a stride in a data structure the programmer already thought about</em>: a per-thread accumulator array indexed by thread id is a correct parallel reduction, and it is 8 bytes per thread wide, so a machine with twelve logical CPUs puts eight counters in one line. <strong>Nothing in the program is wrong, and the fix is to make the data structure bigger on purpose</strong> &mdash; which is exactly the kind of decision that needs a measured number behind it, because the same padding costs space and cache footprint in every case where it is not needed.</p>
                <p>Exercise 4 is the one that reframes the size of the effect. False sharing is often described as a penalty that a programmer incurs by accident, as though true sharing were free. It is not: a genuinely shared counter written by two threads needs the same exclusive ownership, so it pays the same transfer, and the difference between the two cases is that one of them was <em>intended</em>. <strong>The transfer is the hardware's unit of communication between cores, and the line is its size.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept takes the previous concept's store and moves it one wire outward. <a href="/courses/mem/lessons/mem-writes">Write-allocate</a> established that a store to a line you do not hold must fetch it, and priced it at 2.47&times; a read above the last level of cache. <strong>This concept is the same fetch with a second owner</strong>, and the price turns out to be <em>per iteration</em> rather than <em>per line</em>: the earlier concept charged you once for bringing a line in and then let you use it, while this one takes the line away again before the next access. That difference &mdash; once per line against once per access &mdash; is what turns a factor of 2.5 into a factor of 70.</p>
                <p>Forward, <a href="/courses/mem/lessons/mem-verify">the last concept</a> opens the harness. This is the right place to stop making claims and start looking at how they are checked, because this section's claim is the one in the course whose mechanism is <em>least</em> observable: a factor is measured, a mechanism is inferred, and the two checks in group F assert the factor and the precondition of the measurement while asserting nothing about coherence states. <strong>What the harness does with the gap between a measurement and its explanation is the subject of the final concept.</strong></p>
                <p>Outward, the closest neighbours are in the execution course, and they are about the same buffer from two sides. <a href="/courses/exe/lessons/exe-deps">That course's dependency concept</a> established that a chain of dependent operations cannot be widened by adding execution units &mdash; and both arms of this experiment are exactly such a chain, a load and a store of the same address, which is why the far arm sits at one or two cycles per iteration and not at zero. <a href="/courses/exe/lessons/exe-speculate">Its speculation concept</a> is the reason a store is different from a load in the first place: a load's result can be discarded if it was mispredicted, a store cannot, so stores are held and committed in order. <strong>Everything this concept measured is a consequence of that asymmetry, one level further out from the core.</strong></p>
                <p>And the outward connection with the most practical weight is to the number this concept is built on: <strong>the line size, which every earlier course in this collection has used as an alignment while describing it as a format detail.</strong> The ELF courses align sections to it, the object-file courses describe padding to it, and this concept is where that power of two stops being bookkeeping and becomes the unit in which two cores communicate. A program that respects it for I/O and ignores it in its data layout has learned half the fact.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-writes">Previous: What a Store Costs</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-verify">The Harness, and the Claim It Refuses to Make</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
