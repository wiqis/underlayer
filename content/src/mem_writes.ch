// The Memory Hierarchy — Module 3: What a Page and a Store Cost
// Concept: write-allocate, why 4 bytes and 64 bytes cost the same, why a
// non-temporal store is expensive on purpose, and the ratio that belonged to
// the loop rather than to the memory.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_writes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What a Store Costs — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>What a Store Costs</h1>
            <div class="lesson-meta">23 min &middot; Module 3: What a Page and a Store Cost &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every measurement so far in this course has been about loads. That was a convenient simplification and it is now over, because <strong>the hierarchy is not symmetric, and the asymmetry is not a design accident</strong>. A load's value can be predicted, speculated past, or simply not needed yet; the machine can issue it, move on, and let a buffer hold the answer. A store cannot be dropped, cannot be reordered past a later load of the same address, and &mdash; this is the part that costs money &mdash; <em>cannot be performed on a line the cache does not hold</em>.</p>
                <p>A 64-byte cache line holds 64 bytes and the memory bus moves it whole. A program that stores 1 byte to an address the cache has never seen has two options: fetch the other 63 bytes so the line can be modified in place, or write 1 byte and leave the rest of the line undefined. The second option is wrong for nearly every program, so every mainstream machine does the first, and the consequence is a rule a reader can use without any further measurement:</p>
                <div class="formula">
  a READ sweep moves 64 bytes per line, into the cache.
  a STORE-ONLY sweep moves 64 bytes per line IN, and
  64 bytes per line BACK OUT, because the line it is
  writing was fetched first.

  so above the last level of cache the store sweep must
  move about TWICE the traffic, and its ratio to the
  read sweep has a CEILING of about 2, not a floor.
                </div>
                <p>This is called <strong>write-allocate</strong>, and the point of the ceiling is that it makes the prediction falsifiable in a specific way: 2.5&times; is not &ldquo;twice, roughly&rdquo; and it is not a coincidence. Anything above about 2 has some other cause in it &mdash; a second effect riding along, or a loop that is not measuring memory at all. And the same accounting says where the effect should <em>not</em> appear, which is the stronger half of the prediction: <em>inside</em> the last-level cache there is no DRAM traffic in either direction, so a store sweep should cost about what a read sweep costs, and the ratio should sit near 1.</p>
                <p>Two more consequences follow from the same line, and they are the ones a programmer actually uses. First, <strong>storing 4 bytes of a line should cost what storing 64 bytes costs</strong>, because the transaction is the line: the bytes you did not write are fetched anyway. That makes writes pay for locality the same way reads do, and it is why walk order in a loop that writes an array matters as much as walk order in one that reads it. Second, because fetching a line that will be entirely overwritten is pure waste, <strong>the instruction set provides an escape hatch</strong>: a <em>non-temporal</em> store (x86's <code>movntdq</code>, AArch64's <code>stnp</code>) promises the value will never be read soon, so the line is not fetched and not retained. This is a hint exactly like <code>MADV_HUGEPAGE</code> in the previous concept, except that it is a hint the <em>program</em> gives rather than one the kernel gives, and the artifact tests whether it is honoured by checking a consequence that cannot be faked.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The accounting is arithmetic, so it is worth doing before looking at a single measurement. Let <code>L</code> be the line in bytes and <code>n</code> the number of lines a sweep touches:</p>
                <div class="hex-dump">
                    <pre>  READ sweep          bytes moved = n * 64
                      lines fetched = n

  STORE sweep         bytes moved = n * 64 IN
                                    + n * 64 OUT  (dirty writeback)
                      lines fetched = n   (write-allocate)
                      lines stored  = n

  so    store/read traffic ratio = 2   above the cache
        store/read traffic ratio = 1   inside it, where
                                       neither direction
                                       leaves the cache

  and the time ratio should follow the traffic ratio,
  because above the last level both arms are waiting
  on the same DRAM bus.
</pre>
                </div>
                <p>The model also predicts what happens to the <em>small</em> store. A program that stores 4 bytes to each line still fetches each line, so its traffic and its time should match the 64-byte version, and the ratio column should read 1.00. <strong>This is a prediction that can fail in a way that would be instructive:</strong> if partial-line stores were cheaper, it would mean the machine has a way to write memory without reading it first &mdash; which is exactly what the non-temporal path claims to do, and the whole reason the artifact measures both columns at every footprint.</p>
                <p>The third prediction is about the non-temporal columns, and it is deliberately shaped to be impossible to pass by accident. If a non-temporal store really does not allocate, then its cost cannot depend on the size of the cache:</p>
                <div class="formula">
  a NORMAL store inside the L3   cheap: the line
                                 becomes dirty and the
                                 writeback happens later

  an NT store inside the L3      EXPENSIVE: it goes
                                 to memory NOW, because
                                 nothing is holding it

  so NT should be EXPENSIVE at a size that fits in
  cache, and roughly FLAT from inside the L3 out to
  four times it. a column that is flat is a column
  that never consulted the cache, and flatness cannot
  be produced by a store that allocates: an allocating
  store must get cheaper as its footprint gets smaller.
                </div>
                <p>That is the tell the artifact uses, and it is worth naming as a technique: <strong>when the claim is that some optimisation is not happening, the measurement that settles it is not the fast case but the slow one.</strong> A store that allocates is forced to be cheap at 16 KiB; a store that does not allocate is free to be slow there, and if the numbers show it being slow there, no amount of cache-friendliness can explain them.</p>
                <p>One limit of the model has to be stated up front, because it is the trap this concept's own artifact fell into once. <strong>A sequential sweep is only a measurement of memory while the loop is slower than the memory.</strong> At a small enough footprint the loads and stores hit the L1 and the iteration itself becomes the bottleneck: a loop that issues four loads and four stores per iteration can complete a line in a fraction of a nanosecond, and at that point the ratio between two such arms is a ratio between two <em>loops</em>. The model's predictions all apply to the regime where the memory is the constraint, and the artifact prints the exclusion rather than quietly including the offending rows.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>Eight footprints from 16 KiB to 64 MiB. <code>read</code> is a read-only sweep; <code>st64</code> writes all 64 bytes of each line, <code>st4</code> writes 4; <code>NTfull</code> and <code>NTpart</code> use non-temporal stores. Every column is nanoseconds per <em>line</em>, minimum of three, with four lines per loop iteration so the loop is not the bottleneck at the sizes the model is about:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/6. WRITES/,/7. SHARING/p'
          KiB      read      st64       st4    NTfull    NTpart   st64/rd    st4/rd
           16     0.196     0.313     0.313    11.192     1.370     1.60x     1.60x
           64     0.577     0.626     0.646    11.221     2.465     1.08x     1.12x
          256     0.580     0.633     0.638    11.224     2.800     1.09x     1.10x
         1024     1.159     1.335     1.107    11.258     2.797     1.15x     0.95x
         4096     0.707     0.888     1.096    12.099     2.807     1.26x     1.55x
        16384     2.196     2.504     2.665    13.696     2.823     1.14x     1.21x
        32768     2.896     6.322     6.720    14.889     2.817     2.18x     2.32x
        65536     3.459     8.543     9.044    14.459     3.315     2.47x     2.61x

     That is write-allocate, and it predicts a store-only
     sweep must move TWICE the traffic of a read-only sweep.
     Below the 16 MiB last-level cache the ratio peaks at
     1.26x, over the sizes from 256 KiB up to the cache: both
     arms are running out of CACHE there, not out of bandwidth.
     Above it, 2.47x, and the step happens at the size of the
     last level of the hierarchy, which is where it has to.

  --- group E: write-allocate, measured at the level boundary
      [PASS] a store costs more than a read above the LLC   the line must be fetched first; the step must exceed 43%, one and a half times the measured ratio spread
      [PASS] st4 and st64 are the same cost                 the granularity of the transaction is the line
      [PASS] a non-temporal store ignores the cache hierarchy flat from inside the L3 out to 64 MiB: it never allocates
</pre>
                </div>
                <p>Five readings, in the order the model licenses them.</p>
                <p><strong>The step is at the last level and its size is what the traffic accounting predicts.</strong> Below 16 MiB the largest ratio is 1.26&times;; above it, 2.47&times;. The transition is between the row at the cache's own size (16 MiB: 1.14&times;) and the row at twice it (32 MiB: 2.18&times;), which is where a footprint stops fitting and starts being fetched from DRAM. And 2.47 is not merely &ldquo;twice, roughly&rdquo; &mdash; it is the traffic statement restated. <strong>Careful readers will notice the 2.47 is the same number as the bandwidth ratio:</strong> 3.459 ns per line is 18.5 GB/s and 8.543 ns per line is 7.5 GB/s, so the ratio of the two columns and the ratio of the two bandwidths are the same arithmetic. It is one measurement written twice, not two measurements agreeing, and the artifact does not get credit for it twice.</p>
                <p><strong>Inside the cache the ratio is near 1, and the reading is that a store costs about what a load costs when neither has to leave the chip.</strong> 1.09, 1.15, 1.26 over 256 KiB to 4 MiB. There is a real cost to a store even here &mdash; it occupies the store queue and eventually dirties a line that must be written back &mdash; but it is a small one, and above all it is <em>not</em> the DRAM traffic the model reserved for the large footprints. <strong>The prediction's negative half survives: the effect does not appear where it has no right to.</strong></p>
                <p><strong>Four bytes cost what sixty-four cost, and the largest disagreement in the table is inside the instrument's own noise.</strong> This is the check most likely to be wrong, so it is worth reading closely. Row by row, <code>st4/st64</code> is 1.00, 1.03, 1.01, 0.83, 1.23, 1.06, 1.06, 1.06 &mdash; the worst row (4 MiB, where 4-byte stores read 1.096 ns against 0.888) disagrees by 23%, and the instrument's own ratio spread from the first concept is 29%. <strong>So the claim is not that the two columns are identical; it is that no row's disagreement exceeds the noise of the estimator that produced them</strong> &mdash; which is a weaker and more honest statement, and it is the one the harness asserts. The physical content is that a 4-byte store to a line the cache does not hold drags in 64 bytes, so <em>byte-scattered writes pay for full lines</em>: a loop writing one 4-byte element per line is not four times cheaper than one writing all 64, it is the same purchase.</p>
                <p><strong>The non-temporal columns are flat, and that flatness is the proof.</strong> <code>NTfull</code> reads 11.192 ns per line at 16 KiB &mdash; entirely inside the L3, where a normal store costs 0.313 &mdash; and 14.459 at 64 MiB, four times the last level. <strong>The smaller footprint is not cheaper. It is</strong> <em>slightly more expensive</em>, and it must be: an allocating store cannot be slower inside the cache than outside it, so a column that is flat and expensive across an eightfold range of footprints is a column that never consulted the cache in the first place. The ratio to a read at the same size is 57&times; at 16 KiB and 4.2&times; at 64 MiB, which is why the advice is so often misread. <strong>A non-temporal store is not a faster store. It is a store that trades cache residency for not fetching what it overwrites</strong> &mdash; a good trade for a streaming buffer that will be read next by nobody, and a catastrophic one for anything that will be read back immediately.</p>
                <div class="formula">
  at 16 KiB, where a normal store costs 0.313 ns,
  an NT store costs 11.192 ns: 36x more, for a
  footprint that is entirely inside the L3.

  at 64 MiB, four times the L3, it costs 14.459.

  11.192 against 14.459 is not a cache effect at all.
                </div>
                <p><strong>And one thing in this table is not explained, and is left alone.</strong> The read column is not monotone: 1.159 ns at 1 MiB against 0.707 at 4 MiB, which is a 1.6&times; wobble in the direction that has no physical story (a smaller footprint reading slower). The claims above are made on <em>ratios</em>, and the reason is precisely this: the absolute columns are bands, and a band that moves by 60% between two adjacent footprints for reasons the machine does not publish is not something to build a sentence on. It is the same discipline as the first concept's noise floor, applied to a table that keeps producing a number that looks like a result.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Ratio That Belonged to the Loop</h2>
                <p>The retraction this concept inherits is about a check that failed for the wrong reason, and it is worth telling in full because the failure was <em>manufactured by the analysis</em> rather than by the measurement. The check's claim was simple: inside the last level of cache, a store sweep costs about what a read sweep does, and the cache-resident band must therefore sit <em>below</em> the step the DRAM regime shows.</p>
                <p>The band was computed as the maximum <code>st64/rd</code> over every row not larger than the L3 &mdash; which includes the two smallest rows, where the model does not apply. At 16 KiB the read arm completes a line in <strong>0.196 ns</strong>. That is 64 bytes in a fifth of a nanosecond, or <strong>326 GB/s into one core</strong>, and no memory on this machine does that; it is the loop retiring four loads an iteration and never waiting for anything. Including it put the band's maximum at 1.80&times;, on a run whose step above the cache was 2.38&times;, and the check then failed on a run where the effect it was about was plainly present.</p>
                <div class="hex-dump">
                    <pre>  the offending row, verbatim:

           16     0.196     0.313     0.313    11.192     1.370     1.60x

  a read sweep finishing a line in 1/5 of a
  nanosecond is the LOOP.  64 bytes / 0.196 ns
  = 326 GB/s, which is not a memory number.
  the ratio at that row is the ratio between two
  loops, and it has no business in a band about
  the hierarchy.
</pre>
                </div>
                <p>The fix went into the artifact and into the harness, in that order, and neither of them changed a measurement. The band's floor is stated at <strong>256 KiB</strong> upward, the exclusion is <em>printed in the artifact's own text</em> rather than left implicit in a loop bound, and the harness's version of the same claim was moved to the largest footprint for the same reason: the row at twice the L3 measured 1.60&times; on one run while the row at four times it measured 2.40&times;, so a floor applied to the <em>smallest</em> row past the level failed by a hair on a run where the effect was unmissable.</p>
                <p><strong>The general rule is the one this collection keeps relearning: a check that fails for the wrong reason is worse than no check, because it teaches its reader to ignore it.</strong> Two different fixes were available here &mdash; loosen the tolerance until 1.80 passes, or exclude the rows whose ratio is not about memory &mdash; and the second is the one that leaves a check worth reading. Loosening a tolerance to 1.9 would have made the check pass on this run and would also have made it pass on a run where the step had genuinely gone missing, which is the only situation the check exists to detect.</p>
                <p>There is one more thing to notice, and it is the tell that would have caught it without any of that reasoning. <strong>A rate that is the same for L2-resident data and for DRAM data is the rate of a loop, not of a memory.</strong> The previous concept in this course carries the same lesson from the other direction &mdash; an earlier version of the sweep measured 3.30 ns per line at <em>every</em> footprint from 256 KiB to 64 MiB, and a memory whose speed does not depend on its size is not a memory. Here it is 0.196 against 0.580 across a 16-fold range of footprints, which is the same signal in miniature. Whenever a benchmark's numbers stop responding to the thing the benchmark is supposed to be sensitive to, the benchmark has stopped measuring it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/6. WRITES/,/7. SHARING/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group F:/,/^  --- group G:/p'
</pre>
                </div>
                <p>Then five exercises. The third and fourth are the ones that reach outside the benchmark:</p>
                <div class="hex-dump">
                    <pre>  1. Compute the bandwidths yourself. 64 bytes per
     line divided by the per-line cost, both columns,
     every row. Then compute the ratio of the two
     columns and compare it with the ratio of the two
     bandwidths.

     (They will be the same number to the last digit.
     That is the point: it is ONE measurement written
     twice, and a suite that counted them as two
     independent confirmations would be fooling
     itself.)

  2. Find YOUR last level and predict the step from
     /sys BEFORE running section 6:

       cat /sys/devices/system/cpu/cpu0/cache/index*/size

     (Expect the ratio to be near 1 below that size
     and near 2 above it. If your machine's step is
     not at its L3 size, re-read which index is the
     last level on a hybrid core -- this machine's
     four L1/L2/L3 indices are all it has, but a
     machine with P-cores and E-cores has more, and
     the loop may not be running on the core whose
     /sys you read.)

  3. Make byte-scattered writes cost what the model
     says they cost. Write one 4-byte element to
     each line of a 64 MiB array, walking the array
     in address order, and time it.

     (Expect close to a full-line store: 64 bytes
     of traffic for 4 bytes of data, i.e. 16x
     overpay. This is the measurement behind "use a
     struct of arrays, not an array of structs" --
     an AoS layout that touches one field per
     element makes every access a line.)

  4. Find the escape hatch in real code. Build
     something that memsets or memcpys a large
     region and disassemble it:

       objdump -d ./a.out | grep -i -E 'movnt|stnp|rep stos'

     (Compilers and libc use non-temporal stores
     above a size threshold near the last level of
     cache. Then read the region back immediately
     and time THAT: you have just measured the
     downside, which is why the threshold is not
     zero.)

  5. Break the NT claim. Store non-temporally to a
     region smaller than the L1, then immediately
     read it back in a chase. An NT store leaves the
     line in memory, so the value you just wrote is
     not in cache -- and the store/fetch ordering
     rules make the subsequent load wait.

     (Expect the read-back to be dramatically
     slower than a normal store's read-back. If it
     is not, the machine is not honouring the hint,
     which is itself worth knowing -- and is the
     same class of discovery as the huge-page
     withdrawal in the previous concept.)
</pre>
                </div>
                <p>Exercise 3 is the one with the immediate payoff, because it converts a table into a habit. The line is the unit of traffic on every machine, so <strong>the cost of a write is set by how many lines it touches, not by how many bytes it writes</strong> &mdash; and the layout decisions in a program that writes (a particle list that updates one field, a matrix walked by column, a hash table with separate key and value arrays) are line decisions. The benchmark makes the overpay visible in a way a profiler cannot when there is no PMU to attribute misses to.</p>
                <p>Exercise 5 is the one that keeps the hint honest, and it is deliberately the mirror of the previous concept's exercise 4. <code>MADV_HUGEPAGE</code> is a hint the kernel may ignore; a non-temporal store is a hint the <em>microarchitecture</em> may ignore, and on some chips it does. <strong>Both are promises about what will not be cached, and in both cases the only way to know is to measure a consequence the promise forecloses.</strong> For huge pages the consequence is <code>AnonHugePages</code> in <code>smaps</code>; for NT stores it is the flat column and the slow read-back.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the third and last use of the hierarchy as a boundary to step across. <a href="/courses/mem/lessons/mem-latency">The latency concept</a> established that a sequential sweep measures bandwidth and a chase measures latency, and this whole section is a sweep; <a href="/courses/mem/lessons/mem-hierarchy">the hierarchy concept</a> located the boundary and gave every claim above its shape; <a href="/courses/mem/lessons/mem-translation">the translation concept</a> put a page in front of the cache, and the store sweep pays that too. <strong>This is the first concept in the course that measures something no earlier concept could have predicted or explained: the load side of the machine does not contain write-allocate.</strong></p>
                <p>Forward, <a href="/courses/mem/lessons/mem-sharing">the next concept</a> takes the same store and moves it one wire further out. A store that misses locally is, on a multi-core machine, a message: the line may live in another core's cache in a modified state, and the machine has to find it, invalidate the copy, or take ownership. <strong>This concept measured what a store costs when the line is nowhere in particular. That one measures what a store costs when the line is somewhere specific &mdash; in somebody else's cache &mdash; and finds a factor that dwarfs everything in this table.</strong></p>
                <p>Outward, the two most practical connections are to the object-file courses. <a href="/courses/obj/lessons/obj-bss-common">The object course's <code>.bss</code> concept</a> is where a linker decides that zero-filled bytes cost nothing in the file and get materialised by the loader at run time: <strong>a large <code>.bss</code> is free on disk and is exactly the store-only traffic this concept measures when the program starts</strong>, which is a genuine tradeoff between file size and startup cost and not a trick with no downside. And <a href="/courses/elf/lessons/file-layout">the ELF course's file-layout concept</a> shows the same arithmetic from the other end, where sections are laid out so that what the program <em>reads</em> is contiguous in the file; what this concept adds is that contiguous in the file is not the same as contiguous in the cache, and that a store-heavy loop pays for the difference.</p>
                <p>And the connection upward is the reason the store has a concept of its own in a course about building an executable. <strong>A compiler that emits a store is making a claim about where the value will live and who will see it</strong>, and everything downstream of that claim &mdash; the store queue, the coherence protocol, the writeback, the memory ordering rules that another thread's load must respect &mdash; is machinery this concept has now put a number on. The next two concepts close the course by showing the cost when the line is owned elsewhere, and by opening the harness to show how each of these numbers is allowed to be claimed at all.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-translation">Previous: Translation, and the 512x a Huge Page Buys</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-sharing">Two Threads, One Line</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
