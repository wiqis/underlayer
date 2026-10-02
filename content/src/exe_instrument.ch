// How a CPU Executes Instructions — Module 1: The Instrument
// Concept: a TSC tick is not a cycle, the fences are not optional, and the
// noise floor decides what may be claimed.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_instrument() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Measure the Instrument First — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>Measure the Instrument First</h1>
            <div class="lesson-meta">25 min &middot; Module 1: The Instrument &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/isa/lessons/isa-decode">The ISA course ended</a> with a decoder that can tell you what any byte sequence means. It is a complete account of the <em>encoding</em>. It says nothing at all about <strong>what the hardware does next</strong> &mdash; and that is the subject of this course and the next five.</p>
                <p>So the first thing this course has to do is build an instrument, and the first thing the instrument has to do is <strong>be measured itself</strong>. That is not a stylistic flourish. Here is what happened when it was skipped:</p>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples &amp;&amp; ./build_samples.sh 2&gt;&amp;1 | sed -n '/E0/,/E1/p'
   this is the machine every number below came from:
    model name	: AMD Ryzen 5 7430U with Radeon Graphics
    logical CPUs: 12   cores per socket: 6
    cache line: 64 bytes
    L1 Data 32K    8    ways, 64 B line
    L1 Instruction 32K    8    ways, 64 B line
    L2 Unified 512K    8    ways, 64 B line
    L3 Unified 16384K 16   ways, 64 B line
    constant_tsc: yes   nonstop_tsc: yes

   and the thing that decides what this course may claim at all:
    perf_event_paranoid = 4
    perf CANNOT read branch-misses in this guest. There is no hardware
    PMU, so mispredictions cannot be COUNTED -- only inferred from
    timing, and the two explanations cannot be told apart.
</pre>
                </div>
                <p>Two facts in that output are not incidental, and each one is a limit on what this course is allowed to claim.</p>
                <p><strong>The first: this machine has no hardware performance counters.</strong> The event sources are `breakpoint`, `kprobe`, `software`, `tracepoint` and the IBM PCs &mdash; all software constructs &mdash; and <code>perf stat -e branch-misses</code> fails. <code>perf_event_paranoid = 4</code> and no <code>cpu_core</code> PMU. So a branch misprediction cannot be <em>counted</em> here. It can only be inferred from a timing difference, and an inference from timing has at least two explanations that no amount of further timing will separate.</p>
                <p><strong>The second: the machine is virtualised and the clock moves.</strong> The core boosted from 2389 MHz to 3216 MHz during the first measurement I took. That is not a detail of this machine; it is true of essentially every modern CPU, and it is why the next concept is about the difference between a tick and a cycle.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three separate things get confused when you time a CPU, and separating them is most of the work:</p>
                <div class="formula">
  1. THE TICK.  What RDTSC returns.

     A counter that increments at a FIXED rate,
     independent of what the core is doing.
     Measured here: 2.2959 GHz, invariant
     (constant_tsc and nonstop_tsc are both set).

  2. THE CLOCK.  What the core actually runs at.

     Variable. Measured 2389-3320 MHz on this
     machine, within one benchmark run.

  3. THE CYCLE.  What a vendor's datasheet means
     by "4-cycle latency".

     A count of core clock edges. You cannot
     read it with RDTSC, because RDTSC counts
     ticks and the two rates differ.

  so:  ticks are TIME.  cycles are a COUNT of a
  clock that does not run at a fixed rate.

  "4 cycles" and "4 ticks" are different claims
  and only one of them is true of a given number.
                </div>
                <p>And the consequence for method is not subtle. <strong>Any quantity that divides by the clock is safe; any quantity that multiplies by it is not.</strong> A <em>ratio</em> of two measurements taken back to back has the same clock on both sides, so the clock cancels exactly. An <em>absolute</em> figure needs the clock, and the clock is moving.</p>
                <p>Which is why this course quotes ratios and minima and quotes no cycle counts at all. That is not modesty. It is what the instrument permits.</p>
                <p>There is a second piece of the instrument that is not optional, and getting it wrong is the classic microbenchmark error:</p>
                <div class="formula">
  RDTSC IS NOT SERIALISING.

  it does not wait for the work around it. the
  compiler and the processor may both move it.

  so you must fence it:

      LFENCE ; RDTSC          ... work ... ;
      RDTSCP ; LFENCE

  LFENCE before: stops the read being hoisted
                 ABOVE the work it should bracket
  RDTSCP:        waits for prior LOADS (not stores)
  LFENCE after:  stops the read being hoisted past
                 the work that follows

  the cost is about 42 ticks per call, measured.
  so a measurement of a short region has to either
  be long compared with that, or subtract it.
                </div>
                <p>Note the asymmetry in the middle instruction, because it is a real trap: <code>RDTSCP</code> waits for prior <em>loads</em> to complete but <strong>not</strong> for prior <em>stores</em> to be visible. A benchmark measuring store traffic needs a stronger fence than one measuring loads, and using the wrong one produces a number that is too small by an amount that depends on the store buffer&rsquo;s state. This course does not measure stores, so the pair above is sufficient &mdash; and the reason it is sufficient is worth stating rather than leaving to habit.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Instrument Reported About Itself</h2>
                <p>The artifact measures its own noise before it measures anything else, and the first number it printed was wrong:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;/amp;1 | sed -n '/1. THE INSTRUMENT/,/3. LATENCY/p'
  1. THE INSTRUMENT
  ----------------
     TSC rate (vs CLOCK_MONOTONIC)   2.2959 GHz
     core clock, sampled from /proc  1719 MHz   (a stale sample,
                                        see rule 1 -- not used to
                                        convert ticks to cycles)
     iterations per body             8000000
     interleaved repetitions         11

     A TSC tick is a unit of TIME. The core clock on this machine
     ranged over 2389-3320 MHz while the TSC stayed at 2.30 GHz,
     so 'cycles' measured with rdtsc is a stopwatch reading.
     Every ratio below divides by the same clock and so survives.

  2. THE NOISE FLOOR, measured before any claim is made
  ------------------------------------------------------
     the SAME body, 8 times, consecutive:
       fastest 1.0562   slowest 1.7230   spread 48.3%
</pre>
                </div>
                <p>There are three things wrong with that output, and finding all three is the concept.</p>
                <p><strong>First, <code>1719 MHz</code> is not the core clock.</strong> It is a <em>kernel-side sample</em>, updated far more slowly than a measurement takes. An earlier version of this program sampled it around every measurement and converted ticks to cycles with it, and the resulting &ldquo;cycles&rdquo; were wrong by up to three times. <strong>The sample is now printed for orientation and explicitly not used</strong>, because a number that looks like a measurement and is not is worse than no number.</p>
                <p><strong>Second, 48% noise is too much to publish anything absolute from</strong>, and the only correct response is to change what is published: ratios, interleaved, minimum of N. That is not a workaround; it is the design, and it is in the artifact&rsquo;s doc comment as one of five numbered rules.</p>
                <p><strong>Third &mdash; and this is the finding &mdash; the 48% was not the machine.</strong> The same measurement, done properly, on a function aligned to 64 bytes:</p>
                <div class="hex-dump">
                    <pre>$ ./noise2
  16 consecutive measurements of TWO byte-identical loops,
  8000000 iterations each, differing ONLY in alignment.

  64-byte aligned body               min 1.0607  max 1.2190  spread 14.9%
  same body at offset 32             min 0.9956  max 1.2104  spread 21.6%

  the true run-to-run spread of ONE ALIGNED body:  14.9%

  =&gt; the course's first draft quoted a 73% noise floor. That
     number was measured on a function that was NOT aligned, so it
     was the alignment penalty leaking into the noise estimate.
</pre>
                </div>
                <p><strong>The instrument&rsquo;s apparent noise was the phenomenon under study.</strong> That is the most useful sentence in this course, and it is not a platitude: it means the first thing to measure is not the thing you came to measure, and that a variance figure is a claim about your setup before it is a claim about your machine.</p>
                <p>So the honest noise floor is <strong>~15%</strong>, and the 73% and 48% figures are retracted in the artifact itself &mdash; printed by the program, asserted by the crosscheck, so neither can quietly return.</p>
            </div>

            <div class="unit unit-example">
                <h2>Reading a Microbenchmark&rsquo;s Claims</h2>
                <p>What the discipline buys, stated as things you can now do that you could not before:</p>
                <div class="formula">
  YOU CAN NOW:

    trust a RATIO between two things measured
    back to back, even at 15% noise, because the
    clock divides out and the noise is common-mode

    recognise a NUMBER that is really a stopwatch
    reading -- anyone quoting "cycles" from rdtsc
    on a boosting CPU has quoted time

    tell a MEASUREMENT from a SAMPLE: /proc/cpuinfo
    says cpu MHz, not "the clock right now"

    spot the compiler having deleted your
    benchmark, which it will do, silently

    tell a CLAIM about alignment from a CLAIM
    about code, by checking whether the two
    functions are byte-identical

  YOU STILL CANNOT:

    quote an absolute cycle count
    count a branch misprediction
    separate "the predictor learned it" from
    "the cost was hidden by slack"
                </div>
                <p>The compiler point deserves its own paragraph, because it is the failure this collection has now hit in three different courses and the pattern is worth naming. <strong>In the ISA course the <code>-O1</code> optimiser deleted the evidence twice</strong>; in the hardening course a reference parser silently dropped real instructions; here, the first unpredictable-branch measurement returned <strong>0.0000 ticks</strong> because the compiler proved a deterministic xorshift sum was constant and deleted the loop.</p>
                <div class="hex-dump">
                    <pre>   A benchmark the compiler rewrites is not measuring what you
   wrote. The fix is to put the work in inline asm, where the
   compiler cannot see it -- the same discipline the ISA course's
   decoder uses, and for the same reason.
</pre>
                </div>
                <p>And the fix has a cost worth stating: <strong>inline asm is unchecked, untyped, and the compiler will not tell you when you got it wrong.</strong> The ISA course&rsquo;s decoder hit a macro that pasted a literal into the instruction text and produced a stray byte; this course&rsquo;s first attempt used <code>test $1, $1</code>, which <strong>does not exist</strong> &mdash; x86 has no immediate-to-immediate <code>test</code> &mdash; and a helper function named <code>floor</code>, which collides with the libc builtin. All three were caught by the assembler or the linker, which is the good case. The bad case is the one the compiler would not catch, and that is the argument for the crosscheck asserting <em>shapes</em> rather than trusting the numbers.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/E0/,/E1/p'
$ ./cycbench 2&gt;&amp;1 | sed -n '/1. THE INSTRUMENT/,/3. LAT/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^B /,/^C /p'
</pre>
                </div>
                <p>Then measure the instrument on your own machine, which is the exercise that matters:</p>
                <div class="hex-dump">
                    <pre>  1. Calibrate your TSC. It may not be what you
     assume, and on some machines it is not constant
     at all -- check for constant_tsc and
     nonstop_tsc in /proc/cpuinfo before trusting
     it:

       grep -o 'constant_tsc\|nonstop_tsc' \
         /proc/cpuinfo | sort -u

     (If nonstop_tsc is ABSENT, the TSC can stop
     during suspend and every measurement you have
     taken across a suspend is wrong. This machine
     has both, which is why it was usable at all.)

  2. Find your noise floor, properly aligned. Write
     a 20-line benchmark with a __attribute__((aligned(64)))
     function, time the SAME body 16 times, and
     report the spread. Then delete the alignment
     attribute and do it again.

       # aligned
       __attribute__((aligned(64)))
       static double body(void) { ... }

     (Expect the unaligned version to have a LARGER
     spread, and not because it is noisier -- because
     it is sitting at a fixed disadvantage that gets
     rediscovered on every run. This is the effect
     this course's next concepts are about, and you
     can see it in a fifteen-line program.)

  3. Now the one that teaches the most: compile the
     SAME loop at every alignment and plot the time
     against the offset. cycbench section 7 does
     this at eight offsets; do it at all 64 and look
     at the shape.

       # pad with 0x90, which is one byte and one
       # instruction -- NOT with 0x66, which is a
       # prefix, and 16 of them faults
       __asm__ __volatile__(".fill %c0, 1, 0x90\n\t"
                            "1:\n\tadd $1, %%r8\n\t..."

     (Expect a non-monotonic, non-periodic-looking
     curve. This course measured a 2.5x spread and
     the SLOWEST offset was not the one that crossed
     the 64-byte line, so no mechanism is claimed.
     Your curve will differ, because your front end
     differs. The METHOD is what transfers.)

  4. Break your own instrument deliberately. Drop one
     of the LFENCEs and re-measure. The numbers get
     SMALLER, not larger, and they get smaller
     unpredictably -- which is the whole danger.
     Try it:

       uint64_t a = __rdtsc();      /* no fence */
       ...work...
       uint64_t b = __rdtsc();

     (Expect a difference that looks like the work
     got cheaper. It did not. The reads drifted past
     the work. This is the cheapest way to publish a
     wrong number and the hardest to notice.)

  5. Finally, check whether YOUR machine has a PMU,
     because it changes what a course like this one
     can claim:

       perf stat -e branch-misses,cycles true 2&gt;&amp;1 | tail -5
       cat /proc/sys/kernel/perf_event_paranoid
       ls /sys/bus/event_source/devices/

     If branch-misses works, you have something this
     course did not: you can COUNT a misprediction,
     which turns the inference in exe-speculate from
     an argument into a measurement. Do that, and
     then work out what the number is.
</pre>
                </div>
                <p>Exercise 2 is the one that makes the habit, because the result is counter-intuitive in a way that generalises. <strong>An unaligned function does not merely run slower; it runs with more <em>variance</em>, because the penalty is fixed and gets re-observed on every run.</strong> That is why the first version of this instrument reported 73% noise and the aligned one reports 15%: the same machine, the same body, the same clock &mdash; and a completely different-looking instrument, for a reason that has nothing to do with the machine.</p>
                <p>Exercise 5 is the one that decides what the rest of this course can say. <strong>If your machine has a PMU, you can do something this one could not</strong>: count mispredictions directly, which converts the argument in <a href="/courses/exe/lessons/exe-speculate">the speculation concept</a> from &ldquo;we infer it from timing and cannot tell the two explanations apart&rdquo; into a fact. That is not a better course; it is a course that can make one more claim, and the honest thing is to say which claims each machine permits.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The direct parent is <a href="/courses/isa/lessons/isa-length">the length concept</a>, and the connection is a single number seen from two sides. That concept measured that <strong>instruction boundaries form a chain and one wrong length desynchronises every boundary after it</strong>, and used the chain&rsquo;s closure as a verification property. This course measures that <strong>a wrong <em>address</em> desynchronises nothing and corrupts everything</strong> &mdash; the decode is still correct, the boundaries still close, and the timing is wrong by 2.5×. Same lesson, different failure: <em>correctness and performance are independent properties, and a check that establishes one tells you nothing about the other.</em></p>
                <p>The connection to <a href="/courses/reloc/lessons/reloc-why-so-many">the relocations course</a> is about the instruction count rather than the time. That course measured a cost in <em>relocations</em> and this one measures a cost in <em>ticks</em>, and both are costs a linker&rsquo;s output imposes on a CPU &mdash; the first static, the second dynamic. A position-independent binary pays more fixups to produce code that costs fewer ticks to execute, which is exactly the kind of trade a linker-script author has to make blind and a profiler author makes with data. <a href="/courses/link/lessons/link-default-script">The default-linker-script concept</a> is where that trade is actually made, and it has never had a timing in it until now.</p>
                <p>Two connections outward, both about the limit rather than the mechanism. <a href="/courses/img/lessons/img-entries">The image-loading course</a> established that the file and the running process are different objects, and measured a <code>MAP_FIXED</code> floor the kernel would not go below; <strong>this course measures the same gap between what a file says and what the machine does</strong>, and finds it in an address rather than a permission. And <a href="/courses/sec/lessons/sec-posture">The posture reader in the hardening course</a> exists because some properties are not in any header field and must be found by searching the bytes; <strong>this course is the same problem in the other direction</strong> &mdash; the properties that matter here are not in the file at all, and a reader cannot find them by reading harder.</p>
                <p>And the connection forward is the next course in the list. <strong>This concept established that a TSC tick is a time and a cycle is a count of a moving clock.</strong> The memory-hierarchy course, which is next in the list, is where that distinction stops being pedantic: memory latency is measured in <em>nanoseconds</em> and cache sizes in <em>bytes</em>, and a 3 GHz core at 1 ns per access is three cycles while the same core at 4 GHz is four. The instrument built here is the one that will be needed to say so, and it was worth building before there was anything to measure with it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/isa/lessons/isa-decode">Previous: Decode It Yourself</a></span>
                <span>Next: <a href="/courses/exe/lessons/exe-latency">Latency and Throughput</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
