// The Memory Hierarchy — Module 2: The Hierarchy
// Concept: a prediction read out of /sys, and the onset it names, measured
// with a control layout that differs only in WHICH SET each line lands in.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_associativity() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Number From /sys, a Number Measured — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>A Number From /sys, a Number Measured</h1>
            <div class="lesson-meta">23 min &middot; Module 2: The Hierarchy &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept measured how many lines fit in each level, and the answer was a curve. <strong>That curve is what a cache does when the accesses are spread over all of its sets</strong>, which is what a random permutation over a large footprint does. Real programs are not random permutations. They index arrays, they walk matrices, they nest structures, and the arithmetic of those addresses decides <em>which set</em> each access lands in &mdash; and a cache is a set of small fully-associative memories, not one big one.</p>
                <p>The consequence is measurable, and it is one of the few places in this course where a prediction can be written down <em>before</em> the measurement and then confirmed by it. On this machine:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/4. ASSOC/,/group C/p'
     /sys says: L1d is 8 ways, 64 sets, 64 B line.
     therefore lines a multiple of 4096 bytes apart share an
     L1d set, and 9 of them cannot coexist in 8 ways.

     PREDICTION, before the measurement: the cost must rise
     between 8 and 9 lines at stride 4096, and must NOT
     rise at stride 4160, which spreads them over distinct sets.

     lines      aliased       spread     ratio
         4        1.661        1.544     1.08x
         6        1.661        1.717     0.97x
         7        1.520        1.564     0.97x
         8        1.541        1.573     0.98x
         9        7.240        1.714     4.22x
        10        6.150        1.593     3.86x
        12        6.327        1.446     4.38x
        16        6.255        1.525     4.10x
        24        6.342        1.392     4.56x
        32        6.218        1.588     3.92x
</pre>
                </div>
                <p><strong>Nine lines &mdash; 576 bytes of working set &mdash; cost 4.22&times; the same nine lines laid out differently, and any one of those lines would fit in the L1d fifty-six times over.</strong> No capacity explanation survives that: the working set is smaller than the previous concept's smallest measured footprint, and the previous concept measured that footprint at L1 speed. The difference is entirely in the addresses within each 16-bit slice of the low bits, and that is what associativity means.</p>
                <p>The second thing to notice is the <em>control</em>, and it is the reason this table is stronger than its numbers look. The two layouts in every row hold the same number of lines and span the same 131 072 bytes. They differ by one thing: <strong>which set each line lands in.</strong> That is what turns a measurement into an experiment, and it is what makes the phrase &ldquo;a conflict miss&rdquo; mean something specific here &mdash; a miss that has nothing to do with capacity and everything to do with the low bits of an address.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The arithmetic is short enough to do in your head, which is why it is worth doing before running anything:</p>
                <div class="formula">
  a cache level is:  sets  x  ways  x  line bytes

  L1d on this machine:  64 x 8 x 64 = 32768 bytes

  the SET of an address is chosen by bits 6..11
  (line index bits) -- i.e. by

      set = (addr / 64) mod 64

  so two addresses that differ by

      64 sets * 64 bytes = 4096 bytes

  land in the SAME SET.  and a set holds `ways`
  lines, so 9 lines 4096 bytes apart cannot coexist
  however empty the rest of the cache is.
                </div>
                <p>The address arithmetic gives a second number, and it is the one the artifact prints because a reader needs it to design a control: <strong>the aliasing stride is <code>sets &times; line</code>, and one set holds <code>ways &times; line</code> bytes</strong> &mdash; 4096 and 512 here. A layout at stride 4096 puts every line in set 0. A layout at stride 4160 &mdash; 4096 plus one line &mdash; advances the set by exactly one per line, so 32 lines cover 32 distinct sets and no set is asked for more than one line. Same footprint, same stride <em>magnitude</em>, same number of lines, opposite result.</p>
                <p>And the model predicts the shape of the onset, not just its existence. This is where a capacity curve and a conflict curve can be told apart:</p>
                <div class="formula">
  LINES ALIASED INTO ONE SET, against the ways:

      n &lt;= ways   no line is evicted, all L1 hits
                  -> cost is flat
      n &gt;  ways   every access to the set is a MISS,
                  and the misses are to the NEXT level
                  -> cost jumps to that level's latency
                  and stays there as n grows

  a STEP, not a ramp -- and the step is one line
  wide, because the ninth line evicts the first.
  this is what the table shows: 0.98x at 8 lines
  and 4.22x at 9, with nothing in between.
                </div>
                <p>Two limits of this model matter for reading the table honestly. <strong>First, it predicts the onset and the plateau, and it does not predict where the plateau sits:</strong> whether the thrashing nine lines land in the L2 or the L3 depends on the replacement policy and on what else is in flight, and neither is in <code>/sys</code>. <strong>Second, &ldquo;cache&rdquo; here means L1d on this machine, and the same arithmetic with different constants applies to the L2 and the L3</strong> &mdash; 1024 sets at 4096 bytes gives an L2 aliasing stride of 65536 bytes, and the L2 is shared between the SMT siblings of a core, which is why its <code>shared_cpu_map</code> line says so.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>The prediction, and then what happened to it:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/at exactly 8 lines/,/group C/p'
     at exactly 8 lines the aliased layout costs 1.541 ns
     against 1.573 ns for the spread layout, a ratio of 0.98x.
     At 9 lines it costs 7.240 ns against 1.714 ns, a ratio of
     4.22x.  A working set of 576 BYTES is now costing L2
     latency, and it would fit in the L1d 56 times over.

     The worst row in the aliased column is 9 lines, at
     7.240 ns -- worse than the 32-line row.  /sys publishes capacity and
     not policy, so the replacement policy cannot be read off
     from it, and the shape INSIDE the thrashing regime is not
     explained here.  That is a limit, not a result.

  --- group C: the associativity predicted from /sys
      [PASS] at `ways` lines the aliased layout is not slow yet a working set that fits the ways costs L1
      [PASS] at ways+1 lines the aliased layout IS slow     the onset is where /sys says it must be
      [PASS] the spread layout never slows down at these counts by construction it never puts two lines in one set
      [PASS] the step is a step, not a ramp                 one extra line is enough; there is no gradual onset
</pre>
                </div>
                <p>Four readings, in the order the numbers support them.</p>
                <p><strong>The onset is at 9, and the table's own justification for that claim is the arithmetic rather than the data.</strong> 8 ways means at most 8 lines per set; 9 aliased lines can only be 7 hits and 2 misses at best, and the measured ratio goes from 0.98&times; to 4.22&times; in one row. A model that predicted a ramp &mdash; progressive eviction, a gradual slope &mdash; is refuted by the fact that the row before the step is at <em>0.98&times;</em>, i.e. indistinguishable from the control. <strong>One line is the difference between &ldquo;as fast as an L1&rdquo; and &ldquo;L2 latency&rdquo;.</strong></p>
                <p><strong>The control is flat, and that is the load-bearing half of the experiment.</strong> The spread layout at 9, 10, 12, 16, 24 and 32 lines never exceeds 1.15&times; the L1 reference, because by construction it never puts two lines in one set. Without it, the 9-line result would be a number; with it, the 9-line result is <em>a difference between two layouts that differ only in their low address bits</em>.</p>
                <p><strong>The plateau is at L2 latency, not L3, and the model does not predict which.</strong> 7.24 ns is the L2 band from the previous concept (4.77&ndash;5.50 ns) plus the loop, not the L3's 19&ndash;25 ns. That is what a set conflict looks like: the lines are evicted from the L1 and land in the next level down, whose own sets are large enough (1024 of them) that 9 lines cannot conflict there.</p>
                <p><strong>And the worst row is 9 lines rather than 32, which the model does not explain and the artifact declines to explain.</strong> A prediction of &ldquo;more lines, more misses&rdquo; would put the peak at 32; measured, the peak is at the onset and the plateau thereafter is slightly <em>lower</em>. The honest reading is the artifact's own: <em>that is a limit, not a result</em>, and the reason it is a limit is that the replacement policy is not in <code>/sys</code> and the miss count is not available without a PMU. What can be said is that the shape inside the thrashing regime is not a simple function of the line count, and that anyone who needs it has to measure it on their own machine.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Wrong Cause, Twice</h2>
                <p>This section's real lesson is a retraction, and it is the most dangerous kind of wrong number in the whole course: <strong>the effect was real, reproducible, and attributed to something else.</strong> An earlier draft of this table measured a 5.28&times; slowdown for &ldquo;256 lines at a 4096-byte stride&rdquo; and reported it as the cost of <em>address translation</em> &mdash; a TLB effect, since 256 lines at one per page is 256 pages and the TLB holds 64.</p>
                <p>The number was real. The interpretation was not, and the giveaway was in the layout function:</p>
                <div class="hex-dump">
                    <pre>  the offending layout put line i at

      base + i*4096 + 64*(i mod 8)

  which is 256 lines spread over 8 SETS of an
  8-way cache -- 32 lines per set, four times
  the ways.  the measurement was a CONFLICT MISS,
  measured one page at a time, and the pages had
  nothing to do with it.

  the same bug in its other form put one line per
  4096-byte page with off = 0, and since one line
  per 4096 bytes IS the aliasing stride, every
  page's line landed in L1 SET 0.  that produced a
  "TLB cliff at 32 pages" which was also a set
  conflict, and which vanished when the offset
  spread the lines over all 64 sets.
</pre>
                </div>
                <p><strong>Two findings had to be withdrawn and the real cliff turned out to be at 64 pages</strong> &mdash; which is a genuine translation limit and is measured properly, with a huge-page control, in <a href="/courses/mem/lessons/mem-translation">the next concept</a>. What makes this retraction worth a section rather than a line is that it was invisible from the output: the numbers were stable, the effect was large, the model was plausible, and the words &ldquo;4096-byte stride&rdquo; were in the caption. <strong>The only thing that ever catches this class of error is a control layout</strong> &mdash; the second column of the table above &mdash; because the control differs in exactly the thing the explanation claims and nothing else.</p>
                <p>And there is an arithmetic tell that would have caught it immediately, which the artifact prints for exactly that reason. <strong>A 4096-byte stride in a 64-set cache with 64-byte lines is the aliasing stride, and that identity is published by the level itself:</strong></p>
                <div class="hex-dump">
                    <pre>     => the L1d aliasing stride is sets x line = 64 x 64 = 4096 bytes
        and one L1d set holds ways x line = 512 bytes
</pre>
                </div>
                <p>Any experiment whose <em>page</em> size coincides with the cache's aliasing stride cannot separate the two, and the fix is arithmetic rather than experimental: use an offset that is not a multiple of the line and not a multiple of the stride. <strong>That is what <code>off = 64*(i mod 64)</code> is for in the next concept</strong>: it puts line <em>i</em> in set <em>i mod 64</em> whatever the stride, so two arms comparing page counts have the same set distribution by construction and the only difference left is the pages.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/4. ASSOC/,/5. ADDRESS/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group D:/,/^  --- group E:/p'
</pre>
                </div>
                <p>Then reproduce it on your own machine, which is the exercise that makes associativity a fact rather than a word:</p>
                <div class="hex-dump">
                    <pre>  1. Read the geometry and compute the stride:

       for i in 0 1 2 3; do
         d=/sys/devices/system/cpu/cpu0/cache/index$i
         cat $d/level $d/type $d/size \
             $d/ways_of_associativity $d/number_of_sets \
             $d/coherency_line_size
       done

     (Expect sets*line to be a power of two, usually
     4096 on x86-64 and often 1024 or 2048 on
     AArch64 -- which means the SAME C code can be
     free of conflicts on one machine and full of
     them on the other. This is the first portability
     fact in the course.)

  2. Build the two layouts and reproduce the step.
     A chase over n lines at stride `sets*line`, and
     the same n at stride `sets*line + line`.

     (Expect a step at ways+1 and a flat control.
     If your step is at a different count, re-read
     the ways value: it is the number that decides.)

  3. Break the control on purpose. Use a stride of
     `sets*line` for BOTH arms and confirm they
     agree -- then wonder how many real benchmarks
     do exactly that by accident.

     (This is the retraction above, in five minutes,
     and it is the most valuable exercise here.)

  4. Do it for the L2 and the L3 as well, and watch
     the stride scale with the set count. The L2's
     aliasing stride on this machine is 65536 bytes.

     (Expect the effect to be SMALLER at the outer
     levels, because a larger level has more ways
     and because it is shared. The size of the
     effect is a property of the level's geometry,
     not of the level's position.)

  5. Finally, look for it in a program you own:
     a matrix transpose, a bucket array, a struct
     of arrays. Compute the stride between two
     elements that land in the same set, and see
     whether your inner loop ever hits it.
</pre>
                </div>
                <p>Exercise 1 is the one that changes how a reader writes code, because the aliasing stride is a <em>number of bytes</em> and most structs and matrices are designed in numbers of elements. <strong>A row of a 1024-wide matrix of 4-byte floats is exactly 4096 bytes</strong> &mdash; which is this machine's L1d aliasing stride, so a column walk of that matrix hits one L1 set 1024 times in a row. That is not a hypothetical: it is the most common accidental conflict miss in numerical code, and it is invisible in a profiler on a machine with a PMU because a conflict miss and a capacity miss are the same event there.</p>
                <p>Exercise 3 is the one that keeps the reader honest, because it is a demonstration that a plausible experiment can be guaranteed to find an effect it is not measuring. <strong>Two arms whose addresses collide produce a large, stable, reproducible difference for a reason the experiment's own caption denies.</strong> Every retraction in this course is a variation on that theme, and the defence is always the same: make the two arms differ in exactly one thing <em>and prove that they do</em> &mdash; which, for addresses, means counting them rather than asserting them.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent is <a href="/courses/mem/lessons/mem-hierarchy">the previous concept</a>, and the relationship is the one the two concepts' own <em>caveats</em> set up. That concept's curve used a random permutation over each footprint, which spreads the accesses over all sets &mdash; so it measured capacity and nothing else, and its author said so. <strong>This concept removes the spreading and finds the other half of &ldquo;cache&rdquo;.</strong> Put together, the two tables are a description of a level: <em>how many lines it holds</em>, and <em>how it decides which of them to keep</em>. The first is in <code>/sys</code> and the second is not.</p>
                <p>The connection to <a href="/courses/exe/lessons/exe-frontend">the previous course's front-end concept</a> is a shared structure rather than a shared number. That concept measured that an instruction loop's performance depends on <em>where its bytes sit</em> within 64-byte blocks, and declined to name a mechanism because three were plausible and none was measurable. <strong>This concept is the same claim in the data side, and it can name its mechanism</strong>, because a set index is arithmetic that <code>/sys</code> publishes while an instruction-cache fetch policy is not published anywhere. Same class of effect, different epistemic status: one is derivable, the other is measurable only.</p>
                <p>Two connections outward, and both are places where a number in this table stops being abstract. <a href="/courses/obj/lessons/obj-sections">The object course</a> measured that alignment is a promise in a header, and this table quantifies what breaking it costs when the promise is about a <em>stride</em> rather than a start. And <a href="/courses/dwarf/lessons/dwarf-address-to-line">the DWARF course's address-to-line mapping</a> is the reverse direction of the same arithmetic: a compiler that emits a line table is recording where code ended up in the address space, and this course is what the machine does with those addresses once code begins to execute.</p>
                <p>And the connection forward is a number that this concept's arithmetic makes possible to isolate. <strong>A page is 4096 bytes</strong> on this machine, which is exactly the L1d aliasing stride, which is why the first attempt to measure translation measured a set conflict instead. The next concept compares two layouts whose sets are identical <em>by construction</em> and whose page counts differ, and what is left over when the sets cancel is the cost of translating an address at all &mdash; a cliff at 64 pages, and 512 times the reach for the same walk when the page is 2 MiB.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-hierarchy">Previous: A Band, Not Four Numbers</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-translation">Translation, and the 512x a Huge Page Buys</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
