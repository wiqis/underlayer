// The Memory Hierarchy — Module 1: The Instrument
// Concept: a chase and a sweep over the same 64 MiB differ by 38x, and the
// difference is the prefetcher, which can only be measured by subtraction.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_latency() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Chase and a Sweep Are Different Questions — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>A Chase and a Sweep Are Different Questions</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Instrument &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Here is one working set, on one machine, through one memory system, measured two ways:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/3. LINE/,/the prefetcher/p'
     A 64 MiB working set, 1,048,576 lines, entirely outside
     every level of the cache:

     pointer chase, random order           131.468 ns     0.487 GB/s
     sequential sweep, +64 each time         3.463 ns    18.479 GB/s
     the prefetcher, by subtraction         37.96x
</pre>
                </div>
                <p><strong>The two differ by 38&times;, and neither is wrong.</strong> Both touch 1 048 576 lines, all 64 bytes of each, spread over the same 64 MiB of address space, and every one of those lines is supplied by the same DRAM. A program that believes &ldquo;DRAM costs 131 ns&rdquo; will make one set of decisions; a program that believes &ldquo;DRAM delivers 18 GB/s&rdquo; will make another; and both beliefs are supportable from this table while neither is the whole story.</p>
                <p>The difference is a single property that is invisible in the numbers: <strong>whether the address of the next access can be computed before the current one has returned.</strong> In the chase it cannot &mdash; the address <em>is</em> the value that was just loaded, so each access waits for the previous one and the sequence is a chain of dependent loads. In the sweep it can, and a hardware prefetcher that recognises the stride issues the fetch for line <em>i+k</em> while the program is still consuming line <em>i</em>. The 38&times; is not the prefetcher's speed; it is the number of accesses that end up <em>in flight at once</em> instead of one at a time.</p>
                <p>This is why the previous concept insisted on the rule before anything else was measured. <strong>Two functions four lines apart, one of which the compiler may even rewrite into the other, produce numbers 38&times; apart that both look like a property of the memory.</strong> Every &ldquo;memory is slow&rdquo; figure in the wild is one of these two measurements, and the advice that follows from the wrong one is worse than useless: latency cannot be fixed by moving fewer bytes, and bandwidth cannot be fixed by reordering the accesses.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two bodies, and the difference between them is one instruction each:</p>
                <div class="hex-dump">
                    <pre>  a chase: the next ADDRESS comes from memory

      mov (%p), %p          /* p = *(void**)p  */
      dec %c
      jnz 1b

  a sweep: the next address comes from arithmetic

      movdqu  0(%p), %xmm0
      movdqu 64(%p), %xmm1
      movdqu 128(%p), %xmm2
      movdqu 192(%p), %xmm3
      add    $256, %p
      dec    %c
      jnz    1b
</pre>
                </div>
                <p>The chase's cost is <strong>latency</strong>: each iteration's load cannot begin until the previous iteration's load has produced its address, so the measured ns-per-hop <em>is</em> the memory latency at that footprint. The sweep's cost is <strong>throughput</strong>: the address is known immediately, so the loop's rate is set by how many bytes the memory system can hand over per unit time once the prefetcher has a stream going. And the model that connects them is the one that makes the 38&times; a number rather than an anecdote:</p>
                <div class="formula">
  LITTLE'S LAW, APPLIED TO MEMORY:

      bandwidth  =  bytes in flight  /  latency

  a chase keeps ONE line in flight, so
      64 B / 131 ns            = 0.49 GB/s   <- measured 0.487

  a sweep that keeps ~40 lines in flight, at the
  same DRAM latency, gets
      40 * 64 B / 131 ns       = 19.5 GB/s   <- measured 18.5

  so the two numbers are not two speeds of one
  memory.  they are ONE latency with two different
  amounts of work in flight, and the ratio between
  them IS the concurrency the prefetcher sustains.
                </div>
                <p>Two consequences fall out of that, and both are testable. <strong>First, the chase's per-hop time is a genuine latency measurement and is the only clean one available here</strong> &mdash; which is why <a href="/courses/mem/lessons/mem-hierarchy">the next concept</a> builds its whole curve out of chases. <strong>Second, the sweep is bounded twice</strong>: by DRAM bandwidth when the data is far away, and by the loop's own throughput when the data is close, and the second bound is easy to mistake for the first. That mistake has its own retraction, below.</p>
                <p>There is a third quantity in the section, and it is the one that takes practice to read. A sweep can be made stride-aware, and the two rates that come out of it are not the same rate:</p>
                <div class="formula">
  stride s, elements accessed at addresses base + k*s:

      USEFUL bytes  = 4 per element   (the int the program
                                       actually wanted)
      LINE bytes    = 64 per element as soon as s &gt;= 64
                      (the cache line the memory system had
                       to move to supply it)

      useful GB/s  =  4 / ns_per_element
      line GB/s    =  (bytes moved) / (ns_per_element * n)

  so the ratio between the columns is exactly the
  line utilisation:

      line / useful  =  s / 4      for a dense walk

  at s = 64 that is 16.  the memory system moved
  16 bytes for every byte the program used, and
  'useful GB/s' is the one that predicts how fast
  the PROGRAM goes while 'line GB/s' is the one
  that predicts what the MEMORY did.
                </div>
                <p>And the trap in the dense end of that table is worth stating before it appears, because it is the same loop-floor trap as the previous course's: <strong>at strides 4 and 8 the walk uses every byte of every line it fetches, so the two rows differ only in the loop's own per-element overhead and their order moves between runs.</strong> A table of nine rows therefore contains two different regimes, and reading a claim off a row without knowing which regime it is in is how the artifact ended up printing a sentence about monotonicity that was false &mdash; see the last section of this concept.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>The 38&times; figure is a ratio, and this is the first place in the course where quoting a ratio rather than two absolute numbers pays off. Across the three runs shipped with the course:</p>
                <div class="hex-dump">
                    <pre>                     chase (ns)   sweep (ns)   ratio
  run 1                  131.468       3.463   37.96x
  run 2                  132.627       3.464   38.28x
  run 3                  133.637       3.469   38.52x

  the chase moves 1.6% across three runs and the
  sweep moves 0.2%, but the RATIO moves 1.5% and is
  the same claim every time.
</pre>
                </div>
                <p>And the full stride table, which is what a program's own access pattern actually looks like. The useful column is what the program wanted; the line column is what the memory system had to move:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/stride     elements/,/16 to 1/p'
       stride     elements     ns/element      useful GB/s      line GB/s
            4      4194304         0.4525             8.84           8.84
            8      2097152         0.5105             7.83          15.67
           16      1048576         0.6418             6.23          24.93
           32       524288         1.0097             3.96          31.69
           64       262144         1.9267             2.08          33.22
          128       131072         2.2488             1.78          28.46
          256        65536         2.3908             1.67          26.77
         1024        16384         4.8121             0.83          13.30
         4096         4096         8.8147             0.45           7.26

     'useful GB/s' counts the 4 bytes each element really
     wanted.  'line GB/s' counts the 64-byte lines the memory
     system had to move to supply them.  At a 4096-byte
     stride the system moved 256 KiB of lines to deliver
     16 KiB of wanted data -- 16 to 1 -- and every one of
     those lines was in a different 4 KiB page as well.
</pre>
                </div>
                <p>Three readings of that table, in increasing order of usefulness:</p>
                <p><strong>The last row is where a page-based access pattern lives.</strong> A stride of 4096 bytes means one 4-byte element per page, and the system moved <strong>256 KiB of lines to deliver 16 KiB the program wanted &mdash; 16 to 1</strong>. The useful rate is 0.45 GB/s and the line rate is 7.26 GB/s, and neither of them is &ldquo;the speed of memory&rdquo;. They are what a program does to its memory system when it walks a page-strided structure, which is exactly what a naive linked list or a column operation on a row-major matrix does.</p>
                <p><strong>The two columns peak in different places, which is the first sign they are different quantities.</strong> The useful column peaks at the densest stride (8.84 GB/s at stride 4) and collapses to 0.45 by the sparsest &mdash; a factor of <strong>19</strong>. The line column peaks in the middle (33.22 GB/s at stride 64) because that is the stride at which each fetched line is used exactly once and no line is fetched twice.</p>
                <p><strong>And a page is a bigger unit than a line, which the next two concepts turn into their subject.</strong> Every line in that last row was in a <em>different 4 KiB page</em>, and this machine's translation cache covers 64 of them. The row is therefore paying two costs at once: 16 to 1 on line traffic, and a translation for every element. <a href="/courses/mem/lessons/mem-translation">Concept 5</a> isolates the second one; this table cannot, and says so.</p>
                <p>Then there is the retraction, which is about what happens when a sweep's <em>loop</em> is the bottleneck. An early version of this table reported a steady 3.30 ns per line at every footprint from 256 KiB to 64 MiB &mdash; and a rate that is the same for L2-resident data and for DRAM data is the rate of a loop, not of a memory:</p>
                <div class="hex-dump">
                    <pre>3. "Sequential reads sustain 64 GB/s."  The units were
   wrong AND the loop was the bottleneck: the first version
   measured 3.30 ns per line at EVERY footprint from 256 KiB
   to 64 MiB, and a rate that is the same for L2-resident and
   for DRAM data is the rate of a loop, not of a memory.
   With four lines per iteration: 0.700 ns per line over a
   4 MiB L2-resident region and 3.800 ns over 64 MiB of DRAM,
   i.e. 91.4 and 16.8 GB/s.  THE SWEEP SATURATES, and this is
   the honest limit of the measurement rather than a property
   worth teaching as one: at 3 ns for four 16-byte loads the
   loop is a real part of the cost, so this instrument cannot
   report the bandwidth of an L2-resident region.  The DRAM
   figure it does report is 16.8 GB/s, and the cache-resident
   figure comes from section 6's smallest row instead.
</pre>
                </div>
                <p><strong>That is the most instructive retraction in the course, because the tell was in the shape rather than in the number.</strong> &ldquo;Same cost at every footprint&rdquo; is not a plausible property of a hierarchy: a two-level memory with a 19&times; latency spread cannot deliver a constant per-line rate unless something else is setting the rate, and the something else was the loop. Unrolling to four lines per iteration removed the loop from the denominator and the curve appeared &mdash; and the honest residue is that the sweep <em>still</em> saturates for L2-resident data, so this instrument reports <strong>16.8 GB/s for DRAM and no bandwidth figure at all for the caches</strong>.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading the Table, and a Claim That Was Wrong</h2>
                <p>The first version of the paragraph that follows the stride table said the useful rate &ldquo;falls monotonically with the stride&rdquo;, and printed the two ends as evidence. It is false, and the way it is false is worth more than the fact:</p>
                <div class="formula">
  running the same code twice, ten minutes apart,
  on an unchanged machine:

     stride    run A useful   run B useful
       4          4.47 GB/s      8.84 GB/s
       8          8.05 GB/s      7.83 GB/s

  at stride 4 and 8 the walk uses EVERY BYTE of
  every line it fetches, so those two rows differ
  only in the loop's own per-element overhead --
  and the stride-4 row moved by a factor of two
  between runs while the machine did not.

  so "falls monotonically" was a claim about the
  CORE CLOCK wearing the costume of a claim about
  memory.  the artifact now says what holds:

    the useful rate COLLAPSES across the range
    (19x, dense to sparse) and is not monotonic
    row by row

    the LINE rate RISES across the dense range
    (3.8x, stride 4 to 64) because each row uses
    more of every line it fetches -- and it is not
    monotonic at every step either, since the peak
    is at stride 32 or 64 depending on the run
                </div>
                <p>The harness was asserting the same false thing, in the form of <code>max(use) &lt;= use[0] * 1.30</code> &mdash; &ldquo;no stride is much more useful than a dense one&rdquo; &mdash; and it failed on exactly the run where stride 8 outran stride 4. Both were fixed, and the fix was not a looser threshold: <strong>the check now asserts that the <em>most useful stride is a dense one</em></strong>, which is true because a sparse stride pays a full line for four useful bytes, and it is a claim about the shape rather than about which of two noisy rows won.</p>
                <p>The lesson generalises past this table. <strong>A column of nine measurements taken at nine different moments contains the clock's drift as well as the memory's behaviour, and a monotonicity claim is the easiest way to mistake one for the other.</strong> The artifact's own diagnostic is the one to steal: if a table is non-monotonic where the arithmetic says it must rise, that is not noise &mdash; it is a signal that either the loop or the layout is doing something the caption does not mention. It is how the layout bug from the previous concept was caught, and it is how this sentence was caught.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/3. LINE/,/4. ASSOC/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group C:/,/^  --- group D:/p'
</pre>
                </div>
                <p>Then write the two bodies yourself, which is twenty lines and teaches more than the table does:</p>
                <div class="hex-dump">
                    <pre>  1. Allocate 64 MiB. Fill it with a permutation
     cycle (the artifact's layout_of does this in
     fifteen lines) and time one lap of

       mov (%p), %p ; dec %c ; jnz

     over 4 million hops. Then time a plain
     `add $64, %p` walk over the same region.

     (Expect a factor of tens. If you get anything
     under 4x, check that the compiler did not
     rewrite your chase: look at the disassembly,
     and put the loop in inline asm if it did.
     A deterministic xorshift sum is a benchmark
     the optimiser will delete outright.)

  2. Now make it a LATENCY curve instead of one
     number. Shrink the working set from 64 MiB to
     64 KiB in steps and watch the chase's per-hop
     time fall in steps.

     (Expect steps, not a slope: a hierarchy is
     made of plateaus with cliffs between them.
     This is the next concept's table, and seeing
     it appear out of a twenty-line program is
     the point.)

  3. Measure the prefetcher by subtraction, which
     is the only way to measure it here. Run a
     sweep over a fixed footprint with one stream,
     then with two interleaved streams 32 MiB
     apart, then four.

     (Expect the per-line rate to fall as the
     streams multiply, because the prefetcher can
     only track so many. The number of streams at
     which it stops helping is a property of the
     machine; the METHOD -- hold the footprint
     fixed, add streams, watch the rate -- is the
     part that transfers.)

  4. Finally, break it: pass `--quick` and then
     compare the two runs' tables. The absolute
     numbers move, the ratios move much less, and
     the ones that move most are the ones taken
     from the loop-limited rows.
</pre>
                </div>
                <p>Exercise 1 is the one that makes the distinction physical. <strong>A chase is the only memory benchmark whose number cannot be flattered by the loop, the compiler, or the prefetcher</strong>, because the chain of dependent loads is the measurement: there is nothing to overlap, nothing to unroll away, and no stride for the prefetcher to learn. That is why this course uses chases for every latency claim it makes and sweeps only for the two throughput claims it is willing to defend.</p>
                <p>Exercise 3 is the one that generalises to real code, because a prefetcher that stops helping at two streams is a reason to think about how many independent arrays a loop is walking, not a reason to rewrite the loop. <strong>The mechanism is not observable here &mdash; no PMU, no counter, no way to see a prefetch request &mdash; so the result is a difference and the explanation is a hypothesis.</strong> Saying so is part of the measurement: the subtraction gives a number, and the number does not name its cause.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent is <a href="/courses/exe/lessons/exe-latency">the previous course's latency concept</a>, and the relationship is a substitution. That concept measured a dependent chain of <code>add r8,r8</code> and found 2.7&times; an independent operation, with a marginal cost of about one tick per link &mdash; a chain in <em>registers</em>, resolved inside the core at one cycle per link. <strong>This concept is the same measurement with the register replaced by memory</strong>: the chain still exists, the dependency is still what costs, and the marginal cost per link has gone from about 1 ns to <strong>131 ns</strong>. The instruction-level parallelism that hid the register chain cannot hide this one, because there is nothing to issue until the address arrives.</p>
                <p>That is also why <a href="/courses/exe/lessons/exe-deps">that course's dependency concept</a> had to end where it did, and this concept picks it up at the exact point: the previous course measured that a dependency is a <em>constraint</em> and not a cost, and that the hardware hides it by finding other work. Here the constraint is 131 ns deep and the hardware's answer is not to hide it but to <em>avoid needing it</em> &mdash; which is what a prefetcher is, and what a programmer should be thinking about when the answer is not available.</p>
                <p>Two connections outward, both about what a page is. <a href="/courses/obj/lessons/obj-sections">The object course</a> measured that a section's alignment is stated in a header and enforced by nothing, and this course's last row is what happens when alignment is taken seriously: one element per 4096-byte page is 16&times; the line traffic the program needed. And <a href="/courses/elf/lessons/program-header-table">the ELF course's program-header table</a> is where the mapping that a page belongs to is written down &mdash; the file's statement of an alignment whose cost this course can now put a number on.</p>
                <p>And the connection forward is the point of the whole module. <strong>This concept established that a chase measures latency and a sweep measures throughput, and 38&times; is the difference.</strong> The next concept takes the chase &mdash; the clean measurement, the one the loop cannot flatter &mdash; and runs it over twenty footprints from 512 bytes to 256 MiB. What comes out is a curve, and the interesting question about a curve is not where its steps are but how wide its plateaus are.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-instrument">Previous: Measure the Instrument, Then the Memory</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-hierarchy">A Band, Not Four Numbers</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
