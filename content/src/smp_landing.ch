// Multiprocessor Architecture — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Multiprocessor Architecture — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson smp-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>Multiprocessor Architecture</h1>
            <div class="lesson-meta">7 concepts &middot; 4 modules &middot; 179 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>The four courses before this one each had a single core in them, and they got away with it. <a href="/courses/isa/lessons/isa-decode">The ISA course</a> gave you the bytes of an instruction. <a href="/courses/exe/lessons/exe-instrument">The execution course</a> followed one through a pipeline. <a href="/courses/mem/lessons/mem-latency">The memory course</a> followed an address down to DRAM and back. <a href="/courses/priv/lessons/priv-doors">The privilege course</a> followed a fault to a table a process may not read. None of those needed a second processor, because a single core is the only processor a single-core question has.</p>
                <p>That is exactly why a term slipped through. A word-boundary count over the eight concept pages of each of the four, taken this morning:</p>
                <div class="formula">
  term                mem  exe  isa  priv
  coherence            2    0    0    3
  NUMA                 1    0    0    2
  false sharing        3    0    0    1
  true sharing         1    0    0    0
  SMT                  2    0    0    0
  atomic               1    0    0    0
  cache line           6    3    0    0

  (number of concept files containing the term at all)

  "cache line" appears in nine files and is always a SIZE
  or an ALIGNMENT -- the hardware's unit of cache
  ownership.  "true sharing" appears in ONE, and "atomic"
  in one, and neither is defined there.
                </div>
                <p>The memory course did measure the one coherence-adjacent effect it could reach: two counters eight bytes apart, and it found a factor of sixty-one and called it false sharing. <strong>It also excluded every row where both threads landed on the same physical core, giving the reason that &ldquo;two SMT siblings share L1 and L2 and are a different measurement&rdquo; &mdash; and it used the term twice in its concept pages without once defining what a sibling is.</strong> The artifact that this course ships records the debt in its own output:</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/THE DEBT/,/core_id group/p'
   THE DEBT THIS COURSE IS PAYING:
   The memory course measured false sharing at 61.9x, and it EXCLUDED
   every row where both threads landed on the same physical core,
   giving as its reason that "two SMT siblings share L1 and L2 and are
   a different measurement".  It used the term four times and never
   once defined it.  The rows above are the definition: the L1 and L2
   shared_cpu_lists contain exactly one pair each, and those pairs are
   exactly the pairs of CPUs the topology calls siblings.
 </pre>
                </div>
                <p><strong>This is that course.</strong> It is about what changes when a second core exists, and its first rule is that <em>every</em> claim it makes is a claim about a <em>pair</em>. A pair means nothing until you can say which pair, so the first concept is a topology, read out of <code>/sys</code> and cross-checked between two kernel files that had better agree. The second is the table the whole thing rests on. And the last thing it does is print its own retractions, because three of the six came from this artifact and one of them retracts a sentence this course wrote about itself.</p>
            </div>

            <div class="unit unit-model">
                <h2>The one measurement that makes the course</h2>
                <p>One program, seven placements, exactly one thing changed per row. Same source, same iteration count, same machine, interleaved.</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/pinning to cpu2/,/the one that matters/p'
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
                <p><strong>Rows A, B and C execute the identical instruction on the identical machine. Only the memory address changes.</strong> A has a private line each. B has both threads updating the <em>same</em> long &mdash; true sharing. C has them updating two longs eight bytes apart, in one line &mdash; false sharing, and not one value is shared by anybody.</p>
                <p>B costs 13.05&times; the floor. C costs 10.92&times;. <strong>And B/C is 1.19.</strong> True sharing is supposed to be expensive because the data structure is shared, and false sharing is supposed to be cheaper because the data is not. Measured here they are the same thing, to within a fifth, and the only difference between the two rows is which <em>long</em> is written. The cost is paid for the <strong>cache line</strong>, not for the data on it.</p>
                <p>That is the whole course in a ratio, and it is why a per-thread counter in a shared struct gets padded, why <code>__attribute__((aligned(64)))</code> appears in real concurrent code, and why the memory course could measure 61.9&times; for a program in which no value was ever shared. <strong>The 1.19 is not frozen either</strong> &mdash; across the three recorded runs it came out 0.97, 1.03 and 1.19. The harness asserts the shape, not the number, and that decision is its own concept.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three numbers that are not what the prose expected</h2>
                <p>A course whose headline result came out cleanly would be less interesting than one whose second, third and fourth results refused to be written in advance. All three of these are in the recorded output.</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/two threads, TWO SEPARATE/,/the SAME bodies/p'
   two threads, TWO SEPARATE lines -- nothing shared at all:
      plain store            1.04 ticks/op   <- the floor
      lock xadd              2.64 ticks/op     2.54x the plain store
      lock cmpxchg loop      2.99 ticks/op     2.88x the plain store
 </pre>
                </div>
                <p><strong>A <code>lock</code> prefix with nothing to lock against costs 2.54&times; a plain store, on a machine where no other thread is running.</strong> That is not coherence traffic &mdash; there is nothing to be coherent with. It is the barrier the prefix implies, paid by a thread with no reason to pay it. The prose in the first draft called it expensive <em>because of coherence</em>, and the measurement says that reason is wrong even though the number was right.</p>
                <p><strong>Row D came out at 1.07&times; &mdash; indistinguishable from row A.</strong> Two SMT siblings running a body that shares nothing cost the same as two cores running it. The draft said SMT charges a modest penalty because the shared L1 serialises. The shared L1 is not what it charges you for. The honest conclusion is narrower: SMT is not free, and <em>this experiment does not show what it costs</em>.</p>
                <p><strong>Row F came out at 0.64&times; &mdash; below the no-sharing floor.</strong> It is the row that was supposed to be the slow one. Written naively it is a ping-pong: two lines, two owners, a transfer every iteration. Measured it is not dramatically above A, because a store goes into the store buffer and does not invalidate the other core's copy until it retires, so two threads in a tight loop do not take turns. <strong>The fast path and the slow path look the same on average</strong> &mdash; which is the exact profile of a heisenbug, and is worth more than the number F produced.</p>
            </div>

            <div class="unit unit-example">
                <h2>What is deferred, and what this artifact will not claim</h2>
                <p>Printed in the artifact's own limits block rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. This machine is a virtualised guest with twelve logical CPUs and other work on it, and <code>perf_event_paranoid</code> is <strong>4</strong>, so there is no PMU at all:</p>
                <ul>
                    <li><strong>No count of coherence traffic.</strong> No miss, no snoop, no line transfer, no directory notification can be counted here. Every number in this course is a <em>duration</em>, and a duration bounds a count without measuring it. That is the difference between this course and <a href="/courses/mem/lessons/mem-verify">the memory course's</a>, which could at least bound a miss count from two sides.</li>
                    <li><strong>Not whether the protocol is MESI.</strong> MESI is what the manuals say and what every profiler's state names imply. No user-space experiment distinguishes MESI from MOESI from a directory protocol, and this artifact does not claim to.</li>
                    <li><strong>Anything about NUMA.</strong> One node, one memory domain. There is a whole concept about why that absence is still a measurement, and about the harness's own gap on a two-socket machine.</li>
                    <li><strong>The memory-ordering rules.</strong> The fence's <em>duration</em> is measured and its <em>correctness</em> explicitly is not, with a stated reason for why no timing measurement anywhere could establish it.</li>
                    <li><strong>The other two architectures.</strong> AArch64 and RISC-V are quoted from manuals with a document, not run. There is no such machine in the room.</li>
                    <li><strong>Anything past two threads.</strong> Every experiment here is a pair, because a pair is the smallest thing that has a coherence cost at all, and a measurement of N&nbsp;&gt;&nbsp;2 on this machine would be a measurement of the other ten threads.</li>
                </ul>
                <p>The roadmap folds four topics into this course: Multiprocessor Architecture, NUMA, CPU Virtualization, and CPU Performance Counters. <strong>Two of the four are visibly absent here</strong> &mdash; the last one by a checked fact (<code>perf_event_paranoid</code> is 4) and the second by a checked fact (one node). CPU Virtualization is not addressed at all and this course does not pretend otherwise. The first is what the next seven concepts are.</p>
                <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 73 checks, then remove the 64-byte stride from the private-line rows and make the placement group fail by name.</em> A check that has never been seen to fail is a check with no reason to be believed, and the whole last concept is about four checks of this harness that were wrong before they were right.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
                <p>Before, and in the order the debt was incurred. <a href="/courses/mem/lessons/mem-sharing">The memory course's sharing concept</a> is where a 64-byte line stopped being an alignment and became a thing two cores fight over, and it is also where &ldquo;true sharing&rdquo; appeared once and was never defined &mdash; both are answered here. <a href="/courses/mem/lessons/mem-instrument">Its instrument concept</a> is the one this course is built on: measure the clock, measure the noise floor, and only then make a claim. <a href="/courses/exe/lessons/exe-instrument">The execution course's instrument</a> is the same discipline one level down, and its store-buffer asymmetry is the reason row F came out the way it did. <a href="/courses/mem/lessons/mem-verify">The memory harness</a> and <a href="/courses/priv/lessons/priv-harness">the privilege harness</a> are the two verification models this course's harness is a third instance of, and both of them were written by a hand that had already broken a harness four times.</p>
                <p><strong>The deferral is discharged.</strong> The memory course's limits block names cache coherence, NUMA and multiprocessor memory as belonging elsewhere, and this course is that elsewhere &mdash; with the debt printed in its own output rather than in a changelog. Of the roadmap's neutral CPU-architecture sequence this is the last of the four that had anything outstanding to say, and after it one item remains, SIMD and Vector Processing, which has a different shape entirely: it is about widening the data path rather than about two processors talking.</p>
                <p>Outward, the practical weight is in a compiler backend and it is one specific line of your source. <code>lock</code> is a prefix on x86-64 and an instruction on AArch64 and a fence with chosen edges on RISC-V, so the same C expression becomes different machine code, and an algorithm that is correct on one of those machines may be correct only <em>by accident</em> on another. <strong>You do not need to know the answer to emit the next object file. You do need to know that the question exists, because the answer changes what the file contains.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/smp/lessons/smp-topology">A Claim About a Pair</a></span>
                <span>End of Multiprocessor Architecture &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
