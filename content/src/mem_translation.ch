// The Memory Hierarchy — Module 3: What a Page and a Store Cost
// Concept: the same lines, the same footprint, the same sets, and a different
// number of PAGES — the first quantity in this course that /sys does not
// publish, and the first claim the artifact withdraws instead of reporting.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_translation() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Translation, and the 512x a Huge Page Buys — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>Translation, and the 512x a Huge Page Buys</h1>
            <div class="lesson-meta">25 min &middot; Module 3: What a Page and a Store Cost &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept ended with a retraction, and this concept is the experiment that retraction made possible. An earlier draft measured 256 lines at a 4096-byte stride and saw a 5.28&times; slowdown; the slowdown was real and the explanation &mdash; &ldquo;256 lines is 256 pages, and the TLB holds 64&rdquo; &mdash; was wrong, because one line per 4096 bytes is also <em>this machine's L1d aliasing stride</em>. Every line landed in set 0. <strong>The number was a conflict miss wearing a translation costume, and the way to tell the two apart is to build two layouts whose sets are identical by construction and whose page counts differ.</strong> That is this concept.</p>
                <p>The thing being measured is the step every load in every program you will ever write takes before it reaches the cache. Your code computes a <em>virtual</em> address. The DRAM chip has never heard of it. In between there is a table per process &mdash; on x86-64, four levels of them, 512 entries each &mdash; and the table's entries are themselves cached, in a structure called the TLB. A TLB is small because it is consulted on every memory access, and small is the whole point: <strong>one cached translation can cover 4096 bytes of program, or it can cover 2 097 152.</strong></p>
                <p>That difference is the reason this concept exists in a course about parsing bytes into a working executable. The number of bytes a single translation covers is not a property of the machine alone and not a property of the program alone &mdash; it is decided by the alignment fields the linker and the compiler wrote into the file, which the loader then honoured. <a href="/courses/elf/lessons/program-header-table">A <code>PT_LOAD</code> row with <code>p_align</code> of <code>0x200000</code></a> is a request for a two-megabyte unit of translation, and nothing downstream can grant it if the request says <code>0x1000</code>. So this is where the format the previous courses parsed meets the machine this course measures, and the meeting point is a number of pages.</p>
                <p>Three things are worth knowing before the table, because all three are surprises:</p>
                <div class="formula">
  the onset is NOT in /sys    page size is published
                              (4096 bytes, and /proc/self/smaps
                              confirms it) but the number of
                              TRANSLATIONS the machine caches is
                              not published anywhere. every number
                              up to now was predicted from /sys
                              and then confirmed. this one is
                              measured or it is guessed.

  the onset is at 64          not 32, not 512 -- and it is a step
                              one row wide, like the associativity
                              onset two concepts ago.

  the claim in the title      was WITHDRAWN on the run this lesson
  was withdrawn               quotes. MADV_HUGEPAGE is a hint, not
                              a command, and the mapping did not
                              collapse. the artifact says so and
                              refuses the claim.
                </div>
                <p><strong>That last line is the reason to read this concept rather than skim it.</strong> A huge-page claim is the easiest thing in this course to fake: ask for huge pages, print &ldquo;with huge pages&rdquo; above a column, and nobody can tell from the numbers whether anything collapsed. The line that makes it honest costs one <code>read()</code> of <code>/proc/self/smaps</code>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Both arms of the experiment hold <strong>512 lines</strong>. That is 32 768 bytes of data, it is fixed across the whole table, and it is deliberately far too small to be a capacity experiment. The distance between consecutive line indices is the only thing that changes:</p>
                <div class="hex-dump">
                    <pre>  PACKED                       SPREAD

  line i at  base + i*64       line i at  base + i*4096

  512 lines *   64 bytes       512 lines * 4096 bytes
  = 32768 bytes                = 2097152 bytes
  = 8 pages of 4096            = 512 pages of 4096

  the SAME 32 KiB of data, spread over 8 page
  tables entries or over 512 of them.
</pre>
                </div>
                <p>If the translation is cached, the two arms must cost the same: same lines, same footprint class, same access order. If it is not cached, only the spread arm can tell. So the prediction is a <em>step</em>: flat while the spread arm's <strong>512</strong> pages still fit wherever translations are kept, and roughly a constant penalty afterwards, because the cost is paid per access and not once.</p>
                <p>The control is the part that took three attempts, so it is worth doing on paper. With no per-index offset the L1 set of line <em>i</em> is <code>(i &times; gap / 64) mod 64</code>, and at a 4096-byte gap that is <strong>set 0 for every line</strong> &mdash; which is exactly the trap the previous concept retracted. A page-count experiment at a 4096-byte gap measures sets, not pages. The fix is the offset the artifact calls <code>off</code>, applied per index in units of one line:</p>
                <div class="hex-dump">
                    <pre>  with off = 0:     set(line i) = (i*gap/64) mod 64

      gap =   64  ->  set i mod 64        spreads over all 64 sets
      gap = 4096  ->  set 0, every line   a conflict, not a page

  with off = 64:    addr(i) = i*gap + 64*(i mod 64)

      gap = 4096  ->  (i*64 + i) mod 64 = i mod 64

  so the packed arm (gap 64, off 0) and the spread arm
  (gap 4096, off 64) put line i in the SAME L1 set, for
  every i, by two different routes. the set distribution
  cancels by arithmetic, and what is left over is pages.
</pre>
                </div>
                <p>That cancellation is the experiment. It is also checkable without trusting the prose: the harness walks each layout and counts distinct addresses (group B's <code>distinct_lines</code> check), and the artifact prints the two layouts' page counts from the same table.</p>
                <p>Two more pieces of the model, and one of them is about what a &ldquo;miss&rdquo; here actually costs. On x86-64 a translation needs four table entries, so a miss could in principle mean four dependent memory accesses &mdash; about four DRAM latencies, or 600 ns. That does not happen, and the reason is that the <em>page table entries</em> are themselves cached: a TLB miss is usually answered by a second, larger translation cache, and only a miss in that one starts a walk. The model therefore predicts a plateau that is <strong>far cheaper than DRAM</strong>, and how far is measurable, because this course already measured DRAM at 150 ns.</p>
                <p>And the huge page, which is the second half of the title. A 2 MiB page is one translation for 512 pages' worth of address space:</p>
                <div class="formula">
  4096 bytes per translation   x 512 = 2097152 bytes
  2097152 bytes per translation

  so the spread arm's 512 translations become ONE.
  the prediction is comparative, never absolute:
  the huge-page arm should pay LESS THAN HALF what
  the 4 KiB spread arm pays, both measured against
  the same packed control in the same row.
                </div>
                <p>Comparative is not a stylistic choice. An absolute prediction (&ldquo;the penalty will be 0.2 ns&rdquo;) would be a statement about a clock, and this course's first concept established that the clock moves. A fraction of the artifact's own measured penalty transfers to a machine whose penalty is 2&times; or 5&times;.</p>
                <p><strong>One portability fact belongs in the model rather than in a footnote.</strong> 4096 and 2 MiB are this machine's, read from <code>/proc/self/smaps</code> and from the page-size constants the kernel was built with. AArch64 runs 4 KiB, 16 KiB or 64 KiB granules and 2 MiB or 1 GiB blocks, and a program that hardcodes 4096 in an experiment like this one gets a different number of pages for the same footprint on a different machine &mdash; which means the whole table moves. <strong>Page size is a constant you read, not one you assume</strong>, and this is the first exercise below.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported</h2>
                <p>Ten page counts, three arms each, minimum of three repetitions. <code>+2M page</code> is the same spread layout on a mapping that was <code>madvise</code>d with <code>MADV_HUGEPAGE</code>:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/5. ADDRESS/,/AnonHugePages/p'
      lines      pages     packed     spread    ratio   +2M page
          8          8      1.375      1.408    1.02x      1.549
         32         32      1.528      1.697    1.11x      1.488
         48         48      1.759      1.668    0.95x      1.522
         56         56      1.300      1.597    1.23x      1.664
         64         64      1.664      1.641    0.99x      1.656
         72         72      1.614      4.492    2.78x      4.722
         96         96      1.710      4.670    2.73x      4.806
        128        128      1.673      4.400    2.63x      4.758
        256        256      1.773      4.769    2.69x      4.767
        512        512      1.618      4.522    2.80x      4.593

     AnonHugePages on the madvised mapping, read from
     /proc/self/smaps RIGHT NOW: 0 KiB.  Without that line the
     hugepage column is a claim about a mapping that may or may
     not have collapsed.
     THE MAPPING DID NOT COLLAPSE.  khugepaged is asynchronous
     and a host may disable THP entirely, so the madvised column
     is a SECOND 4 KiB MAPPING and the huge-page claim is NOT MADE
     in this run.
</pre>
                </div>
                <p>Four readings, and then the withdrawal, which is not a reading.</p>
                <p><strong>Below 64 pages the ratio is a band around 1, and the band is the noise.</strong> 1.02, 1.11, 0.95, 1.23, 0.99 &times; &mdash; five rows that straddle 1.00 with no trend, which is what the artifact's own ratio spread (29% on this run, from the instrument concept) licenses one to say. <strong>Up to 64 pages, spreading 32 KiB of data over 256 KiB of address space costs nothing measurable</strong>, which is only true because the translations are cached: 64 pages is <code>64 &times; 4096 = 262 144 bytes</code>, and that is the reach of the fastest level of translation on this machine. The packed arm never leaves 8 pages and could never have found this.</p>
                <p><strong>The step is one row wide, and one row is one page.</strong> 64 pages reads 0.99&times; and 72 pages reads 2.78&times;; the intervening counts are not in the table because there are none to try &mdash; the row set was <em>bisected</em> (8, 32, 48, 56, 64, 72, 96) once the first version's boundary was suspected. A gradual onset would have shown partial penalties in the fifties; there are none. This is the same shape as the associativity onset: <strong>a hardware limit crossed by one unit, not a curve you drift along.</strong></p>
                <p><strong>The plateau is flat, so the cost is per access, and it is far too cheap to be a page walk.</strong> Past the onset the ratio reads 2.78, 2.73, 2.63, 2.69, 2.80 &mdash; five rows across an eightfold range of page counts, with no growth. The excess over the packed arm is about <code>4.52 - 1.62 = 2.9 ns</code> per access. <strong>Had those accesses been walking the page tables from memory, the excess would have been closer to the 150 ns this course measured for DRAM a concept ago</strong>, because a walk is four dependent memory accesses. It is 2.9 ns instead, which is a second-level translation cache hit and nothing worse. That is an inference from two measured numbers rather than a count, and the count is exactly what the PMU that this machine refuses to expose would have provided &mdash; so it is stated as the strongest explanation the measurement supports, and not as an observation.</p>
                <p><strong>The column that is not a reading: the claim is withdrawn.</strong> The artifact reads <code>AnonHugePages</code> out of its own <code>smaps</code> at the moment it would otherwise make the claim, and on this run the answer is <strong>0 KiB</strong>. <code>MADV_HUGEPAGE</code> is a hint; the collapse is done by <code>khugepaged</code>, asynchronously, when the host's memory is friendly enough. So the <code>+2M page</code> column is a second 4 KiB mapping &mdash; 4.722 against the spread arm's 4.492, 4.806 against 4.670, 4.593 against 4.522 &mdash; and the artifact says <em>the huge-page claim is NOT MADE in this run</em>. Note what makes this checkable at all: an uncollapsed mapping is <strong>indistinguishable</strong> from a collapsed one in every other column, because line counts, footprints and L1 sets are identical by construction. The only thing that can tell them apart is the kernel's own report of which pages it backed with a larger page.</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/group D/,/group E/p'
  --- group D: the translation cost is a translation cost
      [PASS] spreading the same lines over more pages costs more a page is a unit of translation, not of storage
      [PASS] with no collapse the madvised arm is a second 4 KiB arm the madvised arm reads 2.84x packed against the spread arm's 2.80x, so it bought nothing: no collapse happened
      [PASS] the penalty does not vanish again as pages grow it is a per-access cost, not a one-off fault
</pre>
                </div>
                <p>The middle check is the one to read twice, because it is a check whose <em>subject changed when the machine did</em>. Its collapsed branch asserts that the huge-page arm costs less than half the 4 KiB one &mdash; the claim in this concept's title. Its uncollapsed branch asserts the opposite fact instead: that the madvised arm is not distinguishable from a second 4 KiB arm. <strong>A suite whose assertions depend on a measurement the machine may not provide has three options &mdash; fail, pass vacuously, or change the question &mdash; and this one changes the question and prints which question it asked.</strong></p>
                <p>For the record of what the collapsed branch looks like, here is the same instrument on the same machine twenty minutes earlier, from <code>research.md</code>. It is <em>a</em> run, not <em>this</em> run, and the distinction is the point:</p>
                <div class="formula">
  run of 2026-09-27 20:54
    AnonHugePages      786 432 KiB = 384 x 2 MiB
    4 KiB spread arm   2.94x the packed arm
    huge-page arm      1.13x the packed arm
    outcome            the penalty is 2.6x smaller
                </div>
                <p>Two runs twenty minutes apart, one of which can support the claim and one of which cannot. <strong>Nothing about the machine changed that a program could detect; the host's memory did.</strong> That is why the instrument checks rather than remembers, and it is the most transferable habit in this course: a claim about a hint the kernel may ignore has to be re-established on every run, and a benchmark that establishes it once and quotes it forever is not measuring the thing it says it measures.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Table That Ran Backwards</h2>
                <p>The retraction this concept inherits was about a measurement given the wrong cause. This one is worse in a smaller way: <strong>a measurement whose own shape contradicted it, in a table nobody read closely.</strong> The layout function has one line that computes an address, and it takes the per-index offset in bytes. An earlier version passed the offset <em>already multiplied by 64</em>:</p>
                <div class="hex-dump">
                    <pre>  intended:   addr(i) = base + i*4096 + 64*(i mod 64)
              = base + i*4096 + i      for i &lt; 64

  actual:     addr(i) = base + i*4096 + 4096*(i mod 64)
              = base + 4096*(i + i)    for i &lt; 64
              = base + 8192*i

  so asking for 32 "pages" of 4096 really touched
  16 pages, and asking for 72 touched 36 -- and the
  arms' set distributions no longer cancelled, because
  the 4096*(i mod 64) term is a multiple of the
  aliasing stride instead of one line.
</pre>
                </div>
                <p>The table it printed was <strong>high for 32 pages and low for 72</strong> &mdash; the exact inverse of the truth, which is the same failure the offset had caused once before in a different gap size. What makes it worth a section rather than a line is the diagnostic the artifact now carries for it: <strong>a non-monotonic table is not noise. It is a signal that the layout is not what the caption says it is.</strong> Timing noise moves a number; it does not tell you that asking for <em>more</em> translations is <em>cheaper</em>. Any monotone expectation that holds by construction &mdash; more pages, more cost; more lines, more misses; larger footprint, more latency &mdash; is a check you get for free, and a table that violates it is reporting a bug with its own columns.</p>
                <p>And the bug survived because the offset was a plausible number in the wrong units. So the artifact's two remaining rules are both about units, and they are stated in the source next to the only function that computes an address:</p>
                <div class="hex-dump">
                    <pre>     - with off = 0, the L1 set of line i is (i*gap/64) mod 64.
       gap 64 spreads over all 64 sets, gap 4096 and every
       multiple of it collapses to set 0, and gap 4160 spreads
       again.
     - when the point of the layout is to compare two PAGE
       counts, the two arms must have the SAME set distribution,
       and that is what off = 64 buys: line i goes to set i mod 64
       whatever the gap.
</pre>
                </div>
                <p><strong>The general lesson is that this machine's geometry keeps showing up in bugs by accident.</strong> 4096 appears in this course as a page size, as an L1 aliasing stride, and as a plausible-looking offset. 64 appears as a line size, as a set count, as a page count and as a translation count. A number that is right in one unit is wrong in another, and the only defence that has worked, three times now, is to make the program <em>count the addresses it actually touched</em> instead of describing them &mdash; which is why group B's check walks every layout's cycle and counts distinct lines rather than trusting the index count.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./membench 2&gt;&amp;1 | sed -n '/5. ADDRESS/,/6. WRITES/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^  --- group E:/,/^  --- group F:/p'
</pre>
                </div>
                <p>Then five exercises, in increasing order of how much they depend on your machine cooperating:</p>
                <div class="hex-dump">
                    <pre>  1. Read the page size instead of assuming 4096:

       getconf PAGE_SIZE
       grep -E 'AnonHugePages|KernelPageSize' \
            /proc/self/smaps | head

     (On AArch64 expect 4096, 16384 or 65536
     depending on the kernel's granule, and 2 MiB
     and 1 GiB blocks above it. Every page count in
     the table above is PAGE_SIZE-dependent, so a
     table copied between machines is not
     comparable unless the page size matches.)

  2. Find your own onset by bisection, the way the
     row set above was chosen. Two arms, one
     comparison each: start at a count you know is
     fast and one you know is slow, then halve the
     interval. Ten runs will localise a boundary
     that no counter on this machine can report.

     (Expect a power of two, and expect it to be a
     LOWER bound on the translations your machine
     caches: the second-level cache is bigger and
     the step happens when the FIRST level fills.)

  3. Break the control on purpose: run both arms at
     a 4096-byte gap with off = 0 and confirm they
     AGREE -- because both are now all-in-one-set
     conflict machines. Then re-read the 5.28x in
     the previous concept and see how it happens.

     (This is the single most valuable five minutes
     in the module. A plausible experiment, a large
     stable effect, and a caption that is wrong.)

  4. Try to make the huge-page arm real, and accept
     both outcomes:
       cat /sys/kernel/mm/transparent_hugepage/enabled
       # [madvise] means only madvise'd mappings
       # are candidates at all
       # then: mmap 512 MiB, MADV_HUGEPAGE, touch
       # every 4096 bytes, sleep, then read
       # AnonHugePages for that mapping
     MADV_COLLAPSE (Linux 6.1+) asks for a
     SYNCHRONOUS collapse and is the honest way to
     test this; it can still return EINVAL, and on
     the machine this course was written on it does,
     even for a 2 MiB-aligned range.

     (If AnonHugePages stays at 0, the correct
     conclusion is not "huge pages do not help". It
     is "this run cannot answer the question" -- and
     then report that, which is what the artifact
     above does.)

  5. Read your own executable's alignment. Find a
     PT_LOAD row and compare its p_align with the
     page size from exercise 1.

     (A segment aligned to 2 MiB is the thing that
     makes the collapsed arm of this experiment
     possible for a real program's text. A segment
     aligned to 4096 cannot use one, whatever the
     kernel's THP policy says -- the request has to
     be in the file.)
</pre>
                </div>
                <p>Exercise 2 is the one that changes how a reader uses a machine. Every number in the two concepts before this one was <em>predicted</em> from <code>/sys</code> and then confirmed, which is a rare and comfortable position: the machine published its geometry and the measurement agreed. <strong>Here there is no published geometry to agree with, and the substitute is a method</strong> &mdash; bisect a boundary with two-arm comparisons until the interval is one unit wide. It is slower than reading a file, it transfers to every machine, and it is the same method the harness uses to the extent it can.</p>
                <p>Exercise 4 is the one that keeps the reader honest, and it is deliberately built to be able to fail. A hint is a hint; a benchmark that treats it as a command reports the machine it wishes it had. <strong>The correct output of that exercise on a host that refuses to collapse is a sentence saying so.</strong></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the second half of a pair with <a href="/courses/mem/lessons/mem-associativity">the associativity concept</a>. That one ended by observing that <em>a page is 4096 bytes, which is exactly this machine's L1 aliasing stride</em>, and that the fix is arithmetic rather than experimental &mdash; an offset that is neither a multiple of the line nor of the stride. <strong>This concept is what that offset buys</strong>: two arms that differ in pages and in nothing else, and a penalty that therefore belongs to the pages.</p>
                <p>Forward, the number is a store. <a href="/courses/mem/lessons/mem-writes">The next concept</a> asks what happens when the access is a write and the line is not held. The answer requires everything here, because the cost it finds has a floor that is the same translation and a ceiling that is the same DRAM, and because one of its controls &mdash; a non-temporal store &mdash; is a promise about allocation, in the same spirit as <code>MADV_HUGEPAGE</code> is a promise about mapping. <strong>Two hints, two systems that may decline them, and a course that checks both.</strong></p>
                <p>Outward, the connection that matters most is to the file formats. <a href="/courses/elf/lessons/memory-mapping">The ELF course's memory-mapping concept</a> states the rule that a <code>PT_LOAD</code>'s file offset and virtual address must be congruent modulo <code>p_align</code>; <a href="/courses/link/lessons/link-phdrs">the linker script course's program-header concept</a> is where that field is chosen, from an <code>ALIGN</code> in a script; and <a href="/courses/img/lessons/img-place">the image course</a> is where the kernel reads the table and grants it, producing mappings the file never mentioned. <strong>This concept is the number that connects them</strong>: the alignment those three courses pass around as a power of two is, at this end, a unit of translation &mdash; and it is the difference between one cached translation for 32 KiB of code and 512 of them.</p>
                <p>And there is a connection to the shape of the collection itself. This course can measure the memory hierarchy because the courses before it established what an executable is, where its bytes go, and how the loader maps them; and the loader's unit is a page. <strong>Parsing something to produce an executable means choosing a page alignment for the segments you emit, and that choice is a performance decision the machine will make on your behalf and never tell you about.</strong> It is the sort of decision this collection keeps returning to: not a mystery, just an arithmetic consequence of a format, published in a header, invisible in the source.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-associativity">Previous: A Number From /sys, a Number Measured</a></span>
                <span>Next: <a href="/courses/mem/lessons/mem-writes">What a Store Costs</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
