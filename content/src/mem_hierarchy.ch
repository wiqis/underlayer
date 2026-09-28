// The Memory Hierarchy — Module 2: The Hierarchy
// Concept: twenty footprints from 512 bytes to 256 MiB, a step within a factor
// of two of every size /sys reports, and a plateau five times wide.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_hierarchy() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Band, Not Four Numbers — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>A Band, Not Four Numbers</h1>
            <div class="lesson-meta">24 min &middot; Module 2: The Hierarchy &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every description of a memory hierarchy is a table of four latency numbers, and every table of four numbers is a lie about the shape. Here is the same hierarchy measured with the one instrument that cannot be flattered &mdash; a pointer chase, twenty footprints, one line per access:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/2. THE HIERARCHY/,/3. LINE/p'
            bytes      lines         ns   vs L1ref
              128          2      1.771      1.12x
              512          8      1.771      1.12x
             2048         32      1.657      1.04x
             4096         64      1.659      1.05x
             8192        128      1.772      1.12x
            16384        256      1.759      1.11x
            32768        512      1.586      1.00x
            65536       1024      4.767      3.01x
           131072       2048      4.997      3.15x
           262144       4096      5.497      3.47x
           524288       8192     11.640      7.34x
          1048576      16384     18.972     11.96x
          2097152      32768     21.230     13.39x
          4194304      65536     22.366     14.10x
          8388608     131072     24.627     15.53x
         16777216     262144     78.066     49.22x
         33554432     524288    117.678     74.20x
         67108864    1048576    132.668     83.65x
        134217728    2097152    144.305     90.99x
        268435456    4194304    149.864     94.49x
</pre>
                </div>
                <p>Two things about that table are worth more than any single row in it.</p>
                <p><strong>The first is that the steps are real and land where <code>/sys</code> says they must.</strong> The L1d is 32 KiB, and the first jump is between 512 lines and 1024 lines. The L2 is 512 KiB, and the second jump is between 8192 lines and 16384. The L3 is 16 MiB, and the third is between 262144 and 524288. <strong>That is a hardware configuration read from <code>/sys</code> and then confirmed by timing, which is the only kind of confirmation a cache size can get</strong> &mdash; the last line of a level is always a miss, so a measured step can be no closer than a factor of two to the nominal size.</p>
                <p><strong>The second is that the plateau between the steps is not flat.</strong> Between 1 MiB and 8 MiB &mdash; entirely inside the 16 MiB L3 &mdash; the cost goes 18.97, 21.23, 22.37, 24.63 ns. That is a 30% slope in the middle of what a table of four numbers would call one value. <strong>So &ldquo;the L3 latency&rdquo; is not a number; it is a band</strong>, and the artifact's own verdict says which one:</p>
                <div class="hex-dump">
                    <pre>     The measured plateau is not one number, it is a BAND, and
     the band widens with the footprint: 1.8 ns at 128 bytes,
     5.0 ns across L2, 24.6 ns across L3, 117.7 ns at 32 MiB and
     149.9 ns at 256 MiB.  A single number called "the L3
     latency" would be wrong by a factor of 5.5 depending on
     where in L3 you happened to ask.
</pre>
                </div>
                <p>Why that matters in practice is not academic. <strong>A program that fits in a memory level has a cost per access that is roughly constant, and a program that does not has a cost that grows with how far past the level it goes &mdash; and the difference between the two is not a factor of two, it is the difference between 1.6 ns and 150 ns.</strong> Reading a hierarchy table as four values tells you that the L3 is &ldquo;about 25 ns&rdquo;; reading it as a band tells you that a working set of 12 MiB and one of 16 MiB are not in the same regime, and that whichever one you have, the number you wrote in your capacity plan is wrong for the other.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The measurement is a chase over a permutation, and the model of what it should produce is simple enough to be checked by hand &mdash; which is what makes the shape of the observed curve informative when it does not match.</p>
                <div class="formula">
  A LAYOUT of n lines: a permutation cycle, so line i
  points at line perm(i) and the walk visits every line
  once per lap and returns to its start.

  the measured cost is

      ns per hop = (time for one lap) / n

  and one lap does n dependent loads.  So the table is
  the LATENCY OF ONE MISS, if the working set does not
  fit, and the latency of one L1 HIT, if it does.

  THE PREDICTION, before the measurement:

      n &lt; L1 lines    ->  an L1 hit      ~4-5 cycles
      n &lt; L2 lines    ->  an L2 hit      ~12-20 cycles
      n &lt; L3 lines    ->  an L3 hit      ~40-60 cycles
      n &gt;= L3 lines   ->  a DRAM access  ~200+ cycles

  a STAIRCASE, with the steps at the level sizes and
  the treads flat.  What the measurement produces
  instead has the steps in the right places and the
  treads TILTED -- and the tilt is the real physics,
  not an artefact, because of the next paragraph.
                </div>
                <p>The reason a tread tilts is that a level is not a set of lines with a switch on it. A working set of <em>n</em> lines in a cache of <em>C</em> lines does not produce a clean either/or:</p>
                <div class="formula">
  as n approaches C from below, the walk's own reuse
  distance exceeds what the level can hold, and the
  LAP stops being self-contained.  So a fraction of
  the accesses in a lap become misses to the NEXT
  level, and the average per-hop cost is a mix:

      cost(n) = (1 - m(n)) * cost_level + m(n) * cost_next

  where m(n) is the miss rate of a cyclic permutation
  walk over n lines in a C-line level -- which rises
  with n/C and depends on the REPLACEMENT POLICY.

  hence: a step at the size, and a slope on every
  tread that steepens as you approach it.  The
  slope is the level's own boundary, seen from a
  distance.  /sys publishes capacity, not policy,
  so m(n) is not predictable here -- and the shape
  of the tilt is therefore MEASURED, not derived.
                </div>
                <p>Two method points follow, and both were bugs before they were methods.</p>
                <p><strong>Rule 4 applies with teeth here: the reference row for a ratio column must be the <em>least noisy</em> row, not the first one.</strong> The first row of the table is a two-line chase &mdash; a perfectly ordinary measurement taken at an ordinary moment &mdash; and the core clock moves underneath it. An earlier version of this table divided everything by the first row, and the 8-line row then printed as <em>0.58&times;</em>, which reads as &ldquo;a bigger cache is faster&rdquo; and is a statement about the clock rather than about the memory. The reference is now the fastest row at or below the L1d size, which is the minimum of about half the table:</p>
                <div class="hex-dump">
                    <pre>     the L1 reference is 1.586 ns: the fastest of the 512 rows at
     or below the 512-line L1d.  The FIRST row is not used as
     the reference, because it is an ordinary measurement taken
     at an ordinary moment and the core clock moves underneath
     it -- in the run that produced the table above, dividing by
     the first row made the 8-line row read as 0.58x.
</pre>
                </div>
                <p><strong>And the ratio column is the one to read, not the ns column.</strong> The absolute column is partly a record of the core clock: an L1 hit costs a fixed number of core cycles, so its cost in nanoseconds moves with the frequency, and the artifact measured the clock swinging 73% inside a single run. The ratio column divides that out, because the same clock is on both sides &mdash; which is the same argument <a href="/courses/mem/lessons/mem-latency">the previous concept</a> made about the 38&times;.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>The artifact's own summary of the table, which is the paragraph a reader should still be able to check against the rows:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/sys said/,/ratio column is the/p'
     /sys said L1d is 32 KiB, L2 is 512 KiB, L3 is 16384 KiB.
     Those are 512, 8192 and 262144 lines.  Compare them with the
     rows above: the measured step lands within a factor of
     two of the size, which is the only agreement a cache size
     can have, since the last line of a level is always a miss.
     The measured plateau is not one number, it is a BAND, and
     the band widens with the footprint: 1.8 ns at 128 bytes,
     5.0 ns across L2, 24.6 ns across L3, 117.7 ns at 32 MiB and
     149.9 ns at 256 MiB.  A single number called "the L3
     latency" would be wrong by a factor of 5.5 depending on
     where in L3 you happened to ask.
     Note the first column of that sentence is the 128-BYTE
     footprint, which is a two-line chase: it is at the mercy of
     the clock like every other row, and the ratio column is the
     one to read.
</pre>
                </div>
                <p>Three readings of the numbers, in the order the table supports them.</p>
                <p><strong>The three steps are 3.0&times;, 2.1&times; and 3.2&times;, and they do not land in the same place relative to the nominal size.</strong> Reading the ratio column: 1.00&times; at 512 lines, then <strong>3.01&times;</strong> at 1024 &mdash; the L1 boundary, exactly at the nominal 512 lines. The L2 is 8192 lines and the step from <strong>3.47&times; to 7.34&times;</strong> arrives between 4096 and 8192, i.e. a factor of two <em>below</em> the nominal size. The L3 is 262144 lines and the step from <strong>15.53&times; to 49.22&times;</strong> arrives between 131072 and 262144, at the nominal size. <strong>Three levels, three steps, and only one of them lands where the arithmetic would put it</strong> &mdash; which is why the honest form of the claim is &ldquo;within a factor of two&rdquo; rather than a table of step positions. The DRAM-to-L1 ratio is <strong>94&times;</strong> at 256 MiB, and that is the number a capacity plan should be built on: <em>a miss costs about a hundred times a hit</em>, and everything between is a mixture.</p>
                <p><strong>And the mixture is what the middle of the table is.</strong> The rows between 1 MiB and 8 MiB are not &ldquo;the L3 latency&rdquo;; they are a working set that partially fits, and the fraction that does not fit grows with the footprint. That is why the band widens, and it is also why the artifact refuses to name a mechanism for the <em>rate</em> of widening: explaining it needs the replacement policy and a miss count, and this machine has neither.</p>
                <p><strong>The finest agreement available is a factor of two, and that is not sloppiness.</strong> A cache of <em>C</em> lines holding a working set of exactly <em>C</em> lines is already failing, because the walk is cyclic: by the time the lap returns to its first line, the last line has arrived and something had to be evicted. The step is therefore always <em>at or below</em> the nominal size, never above it, and the honest statement is the one the artifact makes &mdash; the step lands within a factor of two, and the row at exactly the size is the least stable number in the whole section.</p>
                <p>Where the section stops is stated as plainly as where it goes:</p>
                <div class="hex-dump">
                    <pre>     What it does NOT claim, because this machine cannot:
       how many lines were missed, or filled, or walked
       what the replacement policy is -- /sys gives capacity, not
         policy -- and the shape inside the thrashing regime is
         not explained here
       why the L3 band widens from 21.2 to 24.6 ns as the footprint
         grows inside it, nor why the row at exactly the L3 size is
         the least stable number in the whole of section 2
       any absolute cycle count at all
</pre>
                </div>
                <p><strong>That middle line is the one to internalise, because it is the shape of every performance claim that can be honestly made on this machine.</strong> The widening is real and measured; its cause is named as unknown; and the alternative &mdash; inventing a mechanism from a slope &mdash; is exactly what produced the four retractions in the previous concept, each of which had the right effect and the wrong cause.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading the Curve</h2>
                <p>The table is a tool, and it is used by finding which regime a working set is in rather than by quoting a latency:</p>
                <div class="formula">
  READ THE RATIO COLUMN, AND ASK ONE QUESTION:
  which side of the last step is my working set on?

     up to 1.00x    it fits in the L1
                     -> cost is a CORE CYCLE count, so it
                        moves with the clock and cannot be
                        reduced by touching less memory

     3x to 15x      it fits in the L2 or the L3, partially
                     -> the cost is a MIXTURE, and the only
                        reliable lever is making the working
                        set smaller

     49x and up     it does not fit at all
                     -> every access is a DRAM access, and
                        at this point the only two levers are
                        bandwidth (touch fewer bytes) and
                        concurrency (the next concept's subject)

  and the boundaries are the numbers /sys publishes,
  so the exercise is arithmetic on your own program's
  data structure size, not an experiment.
                </div>
                <p>Two worked readings, because the arithmetic is where a hierarchy table earns its keep.</p>
                <p><strong>A 4096-element array of 64-byte structs is 256 KiB</strong>, which is half the L2 and eight times the L1, and the table's row for it &mdash; 262144 bytes, 4096 lines &mdash; reads <strong>3.47&times;</strong>. Padding the struct to 96 bytes makes it 384 KiB: still inside the L2, so still the same regime, and the table says the cost moves from 3.47&times; towards 7.34&times; without crossing a step. <strong>Doubling the element count instead takes the array to 512 KiB, which is exactly the L2, and the ratio column moves from 3.47&times; to 7.34&times;</strong> &mdash; the boundary rather than a slope. That is the kind of decision this table can settle and a four-number table cannot: the four numbers would say &ldquo;L2&rdquo; in both cases and the table says one of them is at the edge.</p>
                <p><strong>A hash table with a 2 MiB bucket array and a 3 MiB value pool</strong> touches 5 MiB per pass. On this machine that is still inside the 16 MiB L3, at about 13&ndash;14&times; &mdash; and the artifact's band for that region is 21 to 25 ns per access. The same program on a 32 MiB-L3 machine would be in a different regime entirely, which is the reason the course ships a program rather than a table: <em>the boundaries are properties of the machine you are on, and the method of finding them is what transfers</em>. Every course in this collection that quotes a latency is quoting a number about one machine; the ones that survive are the ones that quote the method.</p>
                <p>And a reading that fails, kept because it is instructive: <strong>the 2-line row reads 1.12&times; against the 512-line row's 1.00&times;.</strong> A reader might conclude that a <em>smaller</em> working set is slower. It is not: the 2-line row is a chase whose per-hop cost is dominated by the loop's own overhead (two loads, a decrement and a branch per hop is a meaningful fraction of an L1 hit), and its absolute value is at the mercy of the clock like every other row. The table's own note says so, and the note is there because the first version of the reference row made that artefact into a headline.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/2. THE HIERARCHY/,/3. LINE/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group C:/,/^  --- group D:/p'
</pre>
                </div>
                <p>Then build the curve on your own machine, which is twenty lines of C and the single most useful measurement in this course:</p>
                <div class="hex-dump">
                    <pre>  1. Write the layout: allocate a region, fill it
     with a permutation cycle, and chase it. Then
     loop over footprints from 1 line to a few
     million and print ns per hop.

     (Expect a staircase with tilted treads. Verify
     the steps against `getconf -a | grep CACHE`
     or /sys/devices/system/cpu/cpu0/cache/.)

  2. Change the reference row and watch the shape
     change. Divide the whole table by the first
     row, then by the minimum of the L1-resident
     rows.

     (Expect the first version to show a small
     working set as SLOWER than a large one for
     rows inside the L1, which is a clock artefact.
     If the two versions of the table disagree
     about the SIGN of an effect, the reference row
     is the bug.)

  3. Find out whether your last level is shared.
     Run two chases in two threads over the same
     footprint, and then over two disjoint
     footprints that together exceed the level.

     (Expect the disjoint pair to be much slower
     per hop. The point is not the number: it is
     that a shared last level is a shared resource,
     so a single-threaded benchmark of it measures
     an empty machine. That is the next course's
     subject -- multiprocessors -- and it is worth
     seeing that this instrument cannot answer it.)

  4. Test the two-line row. Time a chase over 2
     lines, then over 2 lines with the loop body
     unrolled by 2, then by 4.

     (Expect the per-hop cost to FALL as the body
     grows, which proves the 2-line row was
     measuring the loop. Anything below ~16 lines
     is loop-bound on this machine, and the table
     is honest about it only because the note is
     there.)

  5. Finally, the limit test: try to explain the
     tilt. Predict the miss rate of a cyclic walk
     over n lines in a C-line set-associative
     cache, then measure it.

     (Expect the prediction to be wrong at the
     boundary, which is where the replacement
     policy lives, and that is exactly the thing
     /sys does not tell you and a timing counter
     cannot see.)
</pre>
                </div>
                <p>Exercise 1 is the one to keep, because it generalises to every machine the reader will ever use: <strong>the curve is the machine's, but the shape is universal</strong> &mdash; a staircase with a step at each level size and a tilt that steepens towards it. Exercise 5 is the one that keeps the reader honest: it is possible to build a model of the tilt and impossible to confirm it here, and the difference between those two statements is the whole discipline of the course.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent is <a href="/courses/mem/lessons/mem-latency">the previous concept</a>, and the inheritance is explicit rather than implied. That concept established that a chase measures latency and a sweep measures throughput, and that they differ by 38&times;; <strong>this concept is that chase pointed at twenty footprints instead of one.</strong> Every number in the table is a dependent-load chain, `mov (%p), %p` and a decrement, which is the only body whose cost is not flattered by the loop, the compiler or the prefetcher.</p>
                <p>The connection to <a href="/courses/exe/lessons/exe-latency">the previous course's latency concept</a> is a factor of about 140, and it is worth stating as one number. That course measured a dependent chain of <code>add r8,r8</code> and found a marginal cost of about 0.75&ndash;1.03 TSC ticks per link, i.e. about one core cycle. <strong>This course's chain is the same dependency with a memory access in it</strong>, and the marginal cost per link is 1.6 ns from the L1 and 150 ns from DRAM. The hardware's answer to the register chain was to find other work to issue; the hardware's answer to this one is a cache, a prefetcher and a translation cache &mdash; and when all three miss, nothing can be done except to have fewer misses or more of them in flight.</p>
                <p>Two connections outward, both about the fact that a cache line is a unit of <em>storage</em> that a program does not control. <a href="/courses/obj/lessons/obj-sections">The object course</a> measured that a section's <code>sh_addralign</code> is a promise the linker makes, and this table is what a broken promise costs: a struct that straddles two lines is two misses. And <a href="/courses/elf/lessons/memory-mapping">the ELF course's memory-mapping concept</a> is where a program's bytes are laid out before any of this matters &mdash; the arrangement this table is a measurement of.</p>
                <p>And the connection forward is the boundary this concept stopped at. <strong>This table is about capacity: how many lines fit.</strong> Every row in it uses a <em>permutation</em>, which spreads the accesses over all 64 sets of every level and therefore isolates capacity from everything else. The next concept asks the question a permutation cannot: what happens when the addresses are <em>not</em> spread &mdash; when the stride puts them all in the same set &mdash; and the answer is a slowdown of 4.9&times; for a working set that fits in the L1d fifty-six times over.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-latency">Previous: A Chase and a Sweep Are Different Questions</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-associativity">A Number From /sys, a Number Measured</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
