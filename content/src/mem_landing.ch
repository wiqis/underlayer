// The Memory Hierarchy — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Memory Hierarchy — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The Memory Hierarchy</h1>
            <div class="lesson-meta">8 concepts &middot; 4 modules &middot; 192 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p><a href="/courses/isa/lessons/isa-decode">The ISA course</a> ended with a decoder that can tell you what any byte sequence means. <a href="/courses/exe/lessons/exe-latency">The CPU-execution course</a> measured what happens after that: a dependent chain costs 2.7&times; an independent operation, a loop's address is worth up to 2.5&times;, and a branch whose direction alternates costs the same as one that is never taken. <strong>Not one of those measurements was about memory.</strong> That course's artifact never loaded an array, never chased a pointer, never missed a cache &mdash; because on a machine with no performance counters, arithmetic timing was the measurement it could finish, and because the thing it turned out to be measuring (an aligned loop is 2.7&times; an unaligned one) lives entirely inside the core.</p>
                <p>This course points the same instrument at the thing that limits almost every real program instead. <strong>Five courses before it point here and none of them answers the question</strong>, and the reason this is the right moment to answer it is that the collection has just finished describing where an executable's bytes go. A word-boundary grep over the ~52 concept files written before this one:</p>
                <div class="formula">
  `prefetch`         0 files     `cache miss`      0 files
  `set associat`     0 files     `write-allocate`  0 files
  `non-temporal`     0 files     `false sharing`   0 files
  `bandwidth`        0 files     `NUMA`            0 files
  `huge page`        0 files     `MADV_HUGEPAGE`   0 files

  `TLB`              1 file      -- a forward reference to
  `page table`       1 file         this course, in the object course
  `memory hierarchy` 3 files    -- all forward references
  `cache line`       4 files    -- 3 in the exe course, where it means
                                    the INSTRUCTION fetch block

  five courses point at this one and none of them answers it.
                </div>
                <p>And one of those references is precise enough to be this course's own opening problem. <a href="/courses/obj/lessons/obj-sections">The object course</a> says a page is 4096 bytes and an L1 cache line is 64, and asks whether a header field that says &ldquo;alignment 4&rdquo; means one or the other. <strong>This course is where those two numbers stop being stated constants and acquire a measured cost</strong> &mdash; and where a third number, the number of pages a working set is spread over, turns out to be worth more than either.</p>
            </div>

            <div class="unit unit-example">
                <h2>The trap this course is built around</h2>
                <p>The first thing to know about a memory benchmark is that the two obvious ways to write one measure <em>different things</em>, and the difference on this machine is about 38&times;:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/pointer chase, random order/,/subtraction/p'
     pointer chase, random order           131.468 ns     0.487 GB/s
     sequential sweep, +64 each time         3.463 ns    18.479 GB/s
     the prefetcher, by subtraction         37.96x
</pre>
                </div>
                <p>Both move the same 64 bytes per line, both touch the same 64 MiB, and both end up at DRAM. They differ in exactly one respect: whether the address of the next access can be <em>computed</em> before the current one has returned. <strong>So a pointer chase measures latency and a sequential sweep measures bandwidth</strong>, and a benchmark that is one and not the other is measuring the wrong one &mdash; with numbers that look exactly as plausible either way.</p>
                <p>The second thing to know is what a number from this machine is worth, and it is decided before any memory is touched. Every figure in this course is a minimum over several attempts, so the quantity that constrains a claim is how much a <em>minimum</em> moves when the whole procedure is repeated:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/14 min-of-3 values/,/the noise floor/p'
       14 min-of-3 values, 1.258 to 1.867 ns, mean 1.685
       spread about the mean:  36.2%   &lt;-- the noise floor
</pre>
                </div>
                <p><strong>36.2%.</strong> For contrast, the forty-two individual runs behind those minima spread by 46.8%, which is <em>larger</em> &mdash; and quoting the larger number is the mistake this course's first concept exists to prevent, because a 47% spread on an absolute time would make every figure here unpublishable while the thing actually being quoted is not the thing any tolerance is applied to. The consequence is stated once and then obeyed for eight concepts: <strong>without a PMU, a measurement of this machine can verify a shape and cannot verify a value</strong>, so every load-bearing number in this course is a ratio, and every check is a shape, an ordering, or an agreement between two of the artifact's own numbers.</p>
            </div>

            <div class="unit unit-example">
                <h2>Four findings, and the machine they came from</h2>
                <p>Up front, because these decide what the course may claim: <strong>AMD Ryzen 5 7430U (Zen 3), 6 cores / 12 threads, in a virtualised guest. TSC 2.2960 GHz, invariant to 0.013% between an idle and a busy interval. Core clock sampled six times inside one section 1111 to 1923 MHz &mdash; a 73% swing. No hardware PMU: a forked child executing <code>RDPMC</code> dies of SIGSEGV. Transparent huge pages in <code>madvise</code> mode, and the collapse is asynchronous.</strong></p>
                <p><strong>Finding one: the hierarchy is a band, not four numbers.</strong> One table, from an eight-line working set to a 256 MiB one:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/2. THE HIERARCHY/,/3. LINE/p' | awk 'NR==6 || $1 ~ /^(512|32768|65536|524288|16777216|268435456)$/'
            bytes      lines         ns   vs L1ref
              512          8      1.660      1.07x
            32768        512      1.732      1.11x
            65536       1024      5.111      3.29x
           524288       8192     10.563      6.80x
         16777216     262144     66.546     42.81x
        268435456    4194304    149.532     96.20x
</pre>
                </div>
                <p>The step lands within a <strong>factor of two</strong> of every size <code>/sys</code> reports, which is the only agreement a cache size can have &mdash; the last line of a level is always a miss. And the plateau is not flat: 1.7 ns at the L1, 5.0 ns across the L2, 24.1 ns across the L3, 116.0 ns at 32 MiB and 149.5 ns at 256 MiB. <strong>A single number called &ldquo;the L3 latency&rdquo; would be wrong by a factor of 5.4 depending on where in the L3 you asked.</strong></p>
                <p><strong>Finding two: associativity can be predicted from <code>/sys</code> and then measured.</strong> The L1d is 8-way with 64 sets, so 8 ways &times; 64 bytes = 512 bytes per set, lines a multiple of 4096 bytes apart share a set, and nine of them cannot coexist. The prediction was written down before the measurement, and the onset is between 8 and 9 lines and nowhere else:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/at exactly 8 lines/,/56 times over/p'
     at exactly 8 lines the aliased layout costs 1.541 ns
     against 1.573 ns for the spread layout, a ratio of 0.98x.
     At 9 lines it costs 7.240 ns against 1.714 ns, a ratio of
     4.22x.  A working set of 576 BYTES is now costing L2
     latency, and it would fit in the L1d 56 times over.
</pre>
                </div>
                <p><strong>A working set of 576 bytes at L2 latency</strong>, on a machine whose L1d could hold it fifty-six times over. And the control is what makes it an experiment rather than an anecdote: both layouts hold the same number of lines, span the same 131 072 bytes, and differ only in which set each line lands in.</p>
                <p><strong>Finding three: what a 2 MiB page buys, and the run where it bought nothing.</strong> Two layouts with the same lines, the same footprint, the same access order and the same L1 set for every line &mdash; differing only in how many <em>pages</em> they cover. The packed control needs 8 translations for its 32 KiB; the spread one needs 512. Measured, the spread layout costs up to 2.80&times; the control, and the same layout on a mapping that had been <code>madvise</code>d with <code>MADV_HUGEPAGE</code> <strong>cost 1.13&times;</strong> on an earlier run, a factor of 2.6 smaller penalty. Twenty minutes later, on the same machine:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/RIGHT NOW/,/exactly like one that did to every/p'
     /proc/self/smaps RIGHT NOW: 0 KiB.  Without that line the
     hugepage column is a claim about a mapping that may or may
     not have collapsed.
     THE MAPPING DID NOT COLLAPSE.  khugepaged is asynchronous
     and a host may disable THP entirely, so the madvised column
     is a SECOND 4 KiB MAPPING and the huge-page claim is NOT MADE
     in this run.  It is reported rather than averaged over,
     because a mapping that did not collapse looks
     exactly like one that did to every other number here.
</pre>
                </div>
                <p><code>MADV_HUGEPAGE</code> is a hint, not a command. <strong>The instrument proves the collapse before making the claim and withdraws the claim when it cannot</strong> &mdash; and the harness asserts the withdrawal, which is the only honest way to ship a result that depends on the host's memory policy. An uncollapsed mapping is indistinguishable from a collapsed one in every other column of that table, which is why the check has to be a read of <code>smaps</code> at the moment of the claim.</p>
                <p><strong>Finding four: two counters in one line cost 71&times; the same two counters in two lines, with nothing shared between them.</strong> Two threads, each incrementing its own counter 5 000 000 times, 8 bytes apart or 64 bytes apart:</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/And over the 7 verified/,/lucky minimum/p'
     And over the 7 verified runs: 30.792 ns versus 0.432 ns,
     a factor of 71.2.  The WORST of the verified runs is 64.0x,
     so the claim does not rest on a lucky minimum.
</pre>
                </div>
                <p>Every row is checked against <code>core_id</code> in <code>/sys</code>, and 7 of 7 landed on two physical cores, so the claim rests on runs that were verified rather than on a lucky minimum &mdash; and across the three runs this course ships the factor ranged from 64&times; to 92&times;, which is why the claim is <strong>at least 60&times;</strong> rather than 71&times;.</p>
            </div>

            <div class="unit unit-example">
                <h2>The artifact, and the numbers it refuses</h2>
                <p>One program, <strong>nine sections</strong>, and it measures itself before it measures anything else. The last section is a verdict, and the verdict has two lists: what the course claims, and what it does not.</p>
                <div class="hex-dump">
                    <pre>$ ./membench 2&gt;&amp;1 | sed -n '/9. THE VERDICT/,$p'
     21 checks, 21 passed, 0 failed.
     What this course claims, all measured above:
       L1 1.7 ns   L2 5.0 ns   L3 24.1 ns   DRAM 149.5 ns
       the L1d holds 8 ways, and 9 lines sharing one set cost
         4.2x the same number of lines spread over distinct sets
       the TLB covers 64 four-kilobyte pages; a 2 MiB page covers
         512 times as much address space for the same walk
       a store to an uncached line costs 2.47x a read to it, and
         only above the last-level cache
       two counters in one line cost 71x the same two counters
         in two lines, with nothing shared between them
     What it does NOT claim, because this machine cannot:
       how many lines were missed, or filled, or walked
       what the replacement policy is -- /sys gives capacity, not
         policy -- and the shape inside the thrashing regime is
         not explained here
       any absolute cycle count at all
       what a 2 MiB page removes: the madvised mapping did NOT
         collapse in this run, so there is no huge-page arm and
         the claim is withdrawn rather than reported
</pre>
                </div>
                <p>Twenty-one checks in the artifact and <strong>109 in the harness that reads its output</strong>, and the interesting thing about the harness is what it is not. <strong>Not one of the 109 asserts a bare number in the sense of a value a machine must reproduce.</strong> Each asserts a shape, an ordering, or an <em>agreement</em> between two of the artifact's own numbers &mdash; an aliasing stride against the line size, a TLB cliff against the set count &mdash; and those agreements are machine-independent even though neither number is:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py membench.out 2&gt;&amp;1 | sed -n '/group A:/,/group B:/p' | grep -E 'L[0-9] |aliasing stride'
  [PASS] A machine   L1 Data: ways*sets*line == size                      8 ways x 64 sets x 64 B = 32768 B vs 32768 B
  [PASS] A machine   L2 Unified: ways*sets*line == size                   8 ways x 1024 sets x 64 B = 524288 B vs 524288 B
  [PASS] A machine   L3 Unified: ways*sets*line == size                   16 ways x 16384 sets x 64 B = 16777216 B vs 16777216 B
  [PASS] A machine   the stated aliasing stride is sets*line              computed 4096, artifact says 4096.0
</pre>
                </div>
                <p>And one group is conditional on a measurement the machine may not provide at all &mdash; the huge-page group, whose assertions <em>change</em> when the mapping does not collapse rather than failing or passing vacuously. That decision is the last concept's subject, and it is the most transferable thing in the course.</p>
            </div>

            <div class="unit unit-example">
                <h2>What was retracted</h2>
                <p><strong>Nine claims about the machine did not survive measurement, and all nine are printed by the artifact itself.</strong> The pattern is worth stating before the list, because it is not &ldquo;the first attempt was wrong&rdquo;: in four of the nine the <em>effect was real and the cause was wrong</em>, which is the most dangerous kind of wrong number, because the reproduction works. A real 5.28&times; slowdown was attributed to the TLB when it was a conflict miss in one set. A real cliff was located at 32 pages when the layout had put every page's line in L1 set 0. A real 64 GB/s was a loop's rate with the wrong units on it. A real 16.4 ns non-temporal store was a load allocating the very line it was supposed to bypass.</p>
                <p><strong>The sharpest one is the least dramatic.</strong> A layout bug added <code>64*(i mod 64)</code> bytes to line <em>i</em>, which is <code>128i</code> for <code>i &lt; 64</code>, so line 32 landed on line 64's address. A &ldquo;256 MiB&rdquo; layout really touched a few megabytes and reported 8 ns per access. <strong>The permutation still visited every <em>index</em>, so every self-check passed and the table was nonsense</strong> &mdash; the only thing that caught it was that a 256 MiB footprint cannot be an 8 ns access. The same bug reappeared as a stray <code>* 64</code> and produced a TLB table whose cost was high for 32 pages and low for 72: the exact inverse of the truth.</p>
                <div class="formula">
  the rule that comes out of it, and it is checked
  by walking the cycle rather than by trusting a count:

    a layout must be COUNTED, not trusted.
    if the table is not monotonic where it must be,
    that is not noise -- it is a signal that the
    layout is not what the caption says it is.
                </div>
                <p>And <strong>three more retractions are about the harness rather than the machine</strong>, which is the same disease the previous course spent a concept on: a check that fails for the wrong reason teaches its reader to ignore it. A huge-page check compared a <em>maximum over five rows</em> against a fixed bound and failed at 1.38&times; against 1.34&times; on a machine where the effect was plainly there. The artifact printed the sentence &ldquo;the useful rate falls monotonically with the stride&rdquo; and it is <em>false</em> &mdash; two runs of four measured stride 8 faster than stride 4. And the write-allocate band took its lower maximum from the 16 KiB row, where a read sweep finishes a line in 0.196 ns: that is the loop, not the memory, and including it made a real 2.38&times; step fail a check about a step.</p>
                <p>The harness had its own casualties, and they are recorded next to the measurement bugs in <code>research.md</code> because a suite of checks is a program too. The worst: a regular expression written as <code>[\d.]+</code> is greedy and ate the full stop that ended a sentence, so <code>float(&quot;64.0.&quot;)</code> raised an uncaught <code>ValueError</code> and the harness died <em>before</em> the eleven retraction checks and the fourteen verdict checks ran at all. <strong>A harness that can crash is a harness whose own bugs are indistinguishable from the claims it is testing.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Start Here</h2>
                <p>If you want the trap first, go to <a href="/courses/mem/lessons/mem-latency">A Chase and a Sweep Are Different Questions</a> &mdash; 38&times; for the same 64 MiB, same machine, same DRAM. If you want to know what the course is allowed to claim, start at <a href="/courses/mem/lessons/mem-instrument">Measure the Instrument, Then the Memory</a>, where a 36% noise floor decides that every number here is a ratio. And if you want the part that is about writing programs rather than measuring them, the three concepts on pages, stores and sharing are where the arithmetic turns into layout decisions.</p>
                <p>Either way, the thing to take away is not a latency. <strong>It is that a memory measurement is a claim about addresses as much as about data</strong>: the same 64 MiB costs 131 ns a line in one order and 3.5 ns in another; the same 576 bytes costs an L1 access in one layout and an L2 access in another; and the same 32 KiB costs 2.8&times; more when it is spread over 512 pages than over 8. Every one of those is a property of <em>where</em> the accesses land, not of how much is read.</p>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./build_samples.sh              # build, run, cross-check, about 40 s
$ python3 crosscheck.py           # 109 checks, 9 groups
$ ./membench                      # the artifact alone, 9 sections
$ ./membench --quick              # fewer repetitions, noisier
</pre>
                </div>
                <p>The completion criterion for the course is in <code>manifest.json</code>: reproduce the 109 checks, and then break the layout on purpose to make the one check that catches it fail <em>by name</em>. <strong>A reader who has seen a check fail for a reason they caused is a reader who will believe it when it fails for a reason they did not.</strong></p>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
