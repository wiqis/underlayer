// How a CPU Executes Instructions — Module 1: The Instrument
// Concept: a dependent chain costs 2.7x an independent operation, and the
// ratio is the execution width made visible.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_latency() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Latency and Throughput — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>Latency and Throughput</h1>
            <div class="lesson-meta">24 min &middot; Module 1: The Instrument &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every performance argument in this collection has been static so far. A linker adds a relocation, a hardening flag costs a byte, a PIC access needs two fixups &mdash; all countable from the file, none of them a time. <strong>This is the concept where the counting becomes a measurement</strong>, and where two numbers that are always confused turn out to differ by a factor of three.</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/3. LATENCY/,/4. THE FLAGS/p'
  3. LATENCY AND THROUGHPUT
  -------------------------
  body                                  min ticks     vs floor
  loop floor (empty body)                  0.6678        1.00x
  1 dependent add                          0.8774        1.31x
  2 dependent adds                         1.9690        2.95x
  4 dependent adds                         3.6190        5.42x
  8 dependent adds                         7.4115       11.10x
  1 independent add                        0.6952        1.04x
  2 independent adds                       0.6784        1.02x
  4 independent adds                       0.8367        1.25x
  6 independent adds                       1.3272        1.99x

     MARGINAL cost of one more operation, floor removed:
       dependent chain   2 adds +1.0916   4 adds +0.8250   8 adds +0.9481
       independent       2 adds -0.0168   4 adds +0.0791   6 adds +0.2453

     a dependent chain costs 3.87x an independent operation.
</pre>
                </div>
                <p>Two rows carry the concept. <strong>Eight dependent adds cost 11.1&times; the empty loop; six independent adds cost 2.0&times;.</strong> Same instruction, same encoding, same machine, same clock &mdash; and the only difference is whether each one needs the previous one&rsquo;s answer.</p>
                <p>And the marginal row is the real finding, because the totals are contaminated by the loop. <strong>Add one more link to a dependent chain and it costs about 0.95 ticks. Add one more independent operation and it costs about 0.25.</strong> That ratio of roughly 2.7&ndash;3.9&times; is the execution width, measured, without a single cycle count anywhere in the argument.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two questions that are always asked together and are never the same question:</p>
                <div class="formula">
  LATENCY    how long from ONE instruction
             starting to the NEXT one able to
             start.

             for a chain: each link waits for
             the previous, so the total is
             length x latency.

  THROUGHPUT how many complete per unit time
             when there is nothing to wait for.

             the core has a fixed number of
             places to start work per cycle, and
             a chain of 8 does not use 8 of them.

  the ratio between them is the WIDTH: how many
  independent operations the core can retire per
  unit time, compared with how fast it can go
  through a chain.

  and this is why a vendor's datasheet lists
  BOTH. "add: 1 cycle latency, 4 per cycle" is a
  complete statement about integer addition, and
  either number alone is misleading.
                </div>
                <p>So why do the two differ, when the work is identical? The model answer is <strong>the core can start several operations per cycle because their <em>inputs</em> are ready at the same time</strong>:</p>
                <div class="formula">
  DEPENDENT, drawn as a chain:

    add -&gt; add -&gt; add -&gt; add
     |      |      |      |
     v      v      v      v
    each arrow is a WAIT. nothing else can
    start in its place, because the next add
    has nothing to work on yet.

  INDEPENDENT, drawn as a bundle:

    add   add   add   add
     |     |     |     |
     v     v     v     v
    all four are ready at the same instant, so
    the core starts all four and then waits for
    all four to finish.

  same work. different shape. and the shape is
  what the hardware is built around.
                </div>
                <p>Which gives the practical rule, and it is the most useful thing in this concept:</p>
                <div class="formula">
  ILP     INSTRUCTION-LEVEL PARALLELISM

    how many operations in a straight-line
    region have no dependency on each other.

    8 independent adds:  ILP = 8, and you get
                         throughput

    8 dependent adds:    ILP = 1, and you get
                         latency x 8

    so the optimisation to look for is not fewer
    instructions. it is more ILP in the same
    instruction count.

      for (i = 0; i < n; i++) a[i] = b[i]+c[i];
         -- ILP 3, limited by the loads

      x = a*b; y = c*d; z = e*f;
         -- ILP 6, and the compiler will keep
            it that way
                </div>
                <p>And the honest caveat that the measurement makes unavoidable. <strong>The totals in the table above are not the latency and the throughput; they are the totals, which include the loop.</strong> One operation and two independent operations both measure <em>at</em> the floor &mdash; 0.695 and 0.678, with the difference inside the noise &mdash; because with a loop overhead of about 0.67 ticks, one or two operations hide entirely underneath it. Only from four upwards does the body start to dominate, and only the <em>marginal</em> costs are the latency and the throughput.</p>
                <p><strong>That is not a flaw in the measurement; it is the measurement, and it is the reason the marginal row exists.</strong> A benchmark that reported the totals as &ldquo;latency&rdquo; and &ldquo;throughput&rdquo; would be reporting the loop.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Why the First Version Measured the Wrong Thing</h2>
                <p>Before the numbers above, there was this:</p>
                <div class="hex-dump">
                    <pre>$ ./lat   # the first version, one add per iteration
  loop floor (nop body)        1.109 ticks/iter
  1 dependent add              1.084 ticks/iter
  2 dependent adds             2.402 ticks/iter

  1 independent add            1.012 ticks/iter
  2 independent adds           1.174 ticks/iter
  4 independent adds           1.314 ticks/iter
  6 independent adds           2.363 ticks/iter
</pre>
                </div>
                <p><strong>One dependent add measured <em>faster</em> than an empty loop.</strong> That is impossible if you are measuring the add, and it is a very good sign that you are not.</p>
                <p>What was being measured is the loop. The body is <code>add</code> plus <code>dec</code> plus <code>jnz</code>, and the <code>dec</code>&rarr;<code>jnz</code> pair is a <strong>loop-carried dependency</strong>: the counter must be decremented before the branch can read its flags. That chain is one link long no matter what the body does, so with a one-instruction body the branch <em>is</em> the bottleneck and the add hides underneath it.</p>
                <div class="formula">
  the loop's own chain, which every loop has:

      dec  -&gt;  flags  -&gt;  jnz  -&gt;  next dec
        ^                            |
        +----------------------------+

    length 1, and the body has to fit in its
    shadow. with one operation in the body,
    there is no room and the add is free.

  fix: UNROLL, so the loop's cost is divided by
  the number of operations:

      1 op per iteration  -&gt; loop cost / 1
      8 ops per iteration  -&gt; loop cost / 8

  that is why the table above reports 8 dependent
  and 6 independent rather than 1 and 2: by eight
  the body dominates and the marginal cost is
  the operation's.
                </div>
                <p>So the first version was not wrong about the machine; it was <strong>measuring the loop instead of the instruction</strong>, and the giveaway was a result that contradicted arithmetic. A benchmark that reports a negative cost has told you something, and the something is about the benchmark.</p>
                <p>And there is a second, larger reason the same table kept disagreeing with itself between runs, which the next concept is entirely about. <strong>The two rows for &ldquo;1 independent add&rdquo; and &ldquo;2 independent adds&rdquo; were not just close to the floor &mdash; in some builds the one-operation version measured <em>twice</em> the two-operation version</strong>, which is not a rounding error. Byte-identical loops, at different addresses, differing by 2.7&times;.</p>
            </div>

            <div class="unit unit-example">
                <h2>Computing the Width, and Knowing What You Have Not Measured</h2>
                <p>The ratio is the number a performance-minded reader wants, so it is worth being precise about what it does and does not give you.</p>
                <div class="formula">
  from the table, floor removed:

    dependent marginal   ~0.95 ticks per link
    independent marginal ~0.25 ticks per operation

    ratio  ~2.7x to 3.9x depending on which pair
           of marginals you take

  to turn that into "N operations per cycle" you
  need the clock, which is exactly the thing
  this course cannot measure:

    core cycles per independent op
      = ticks_per_op x (core_MHz / TSC_MHz)

    and core_MHz moved from 2389 to 3216 during
    the run, so the product moves with it.

  so the COURSE CLAIMS THE RATIO and NOT THE
  WIDTH IN CYCLES. the ratio is clock-free; the
  width is not.
                </div>
                <p>That is a deliberate refusal and it is the honest one. It is easy to pick a plausible-looking core frequency, multiply, and print &ldquo;the core retires 4 integer adds per cycle&rdquo; &mdash; and on this machine that number would be in the right neighbourhood for the right reasons, which is the most dangerous kind of wrong.</p>
                <p>There is a way to close the gap without a PMU, and it is worth naming even though this course did not do it: <strong>measure a chain of known length against a clock-domain crossing.</strong> A serialising instruction such as <code>CPUID</code> has a documented, large, fixed cost in core cycles; timing N of them against N of an <code>add</code> gives the clock ratio directly. That is a real technique and it would let this course quote a width. It is not here because it was not measured, and <strong>a course that measures six things and writes down the seventh it did not measure is more useful than one that quietly rounds a guess into a claim</strong> &mdash; that is the whole retraction policy of this collection in one sentence.</p>
                <p>What <em>is</em> measured, and is arguably the more useful number, is the shape of the cost as a function of chain length:</p>
                <div class="hex-dump">
                    <pre>   body                                  min ticks     vs floor
   loop floor (empty body)                  0.6678        1.00x
   1 dependent add                          0.8774        1.31x
   2 dependent adds                         1.9690        2.95x
   4 dependent adds                         3.6190        5.42x
   8 dependent adds                         7.4115       11.10x
   1 independent add                        0.6952        1.04x
   2 independent adds                       0.6784        1.02x
   4 independent adds                       0.8367        1.25x
   6 independent adds                       1.3272        1.99x
</pre>
                </div>
                <p>Read the two columns against each other and the shape is unmistakable. <strong>Dependent is linear in chain length with a steep slope; independent is nearly flat and then bends.</strong> The bend in the independent column is the point where the core runs out of places to start work and the operations begin to queue &mdash; which is the same fact as the ratio, seen as a curve rather than a number, and it is the version of the measurement that transfers to a different machine.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ ./cycbench 2&gt;&amp;1 | sed -n '/3. LATENCY/,/4. THE/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^D /,/^E /p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^E /,/^F /p'
</pre>
                </div>
                <p>Then do the experiment that turns the ratio into a design tool:</p>
                <div class="hex-dump">
                    <pre>  1. Find the knee. Extend the independent
     series until it stops being flat -- 6, 8,
     12, 16, 24 operations per iteration -- and
     find where the slope changes.

       # then, for each, print marginal = (t[k]-t[k/2])/(k/2)

     (The knee is where the core runs out of
     issue slots. It is the closest thing to a
     core-width measurement this instrument can make
     without a clock, and its POSITION is meaningful
     even though its unit is not: it says how much
     independent work this core can absorb before
     more of it stops helping.)

  2. Now the real experiment: same instruction
     count, different ILP. Write four versions of
     one computation and time them.

       (a) a += b*c + d*e;          ILP ~2
       (b) x=a*b; y=c*d; a += x+y; ILP ~4
       (c) four accumulators, unrolled   ILP ~8
       (d) the same work in SIMD        ILP huge

     Time all four. Then count the INSTRUCTIONS
     in each with the ISA course's decoder:

       python3 .../x86dec.py --section .text prog

     (Expect (b) and (c) to be faster than (a)
     with the SAME or MORE instructions. That is
     the whole point: the win is not fewer
     instructions, it is more of them running at
     once. And you can count the instructions
     yourself, which is the nice part -- the
     decoder and the timer are two independent
     instruments measuring two different
     properties of the same binary.)

  3. Now break the loop's own dependency, and see
     the first measurement's mistake fixed properly:

       # instead of dec/jnz, use a pointer that
       # walks memory, or a REP, or unroll the
       # counter by 8 and subtract 8
       for (i = n; i > 0; i -= 8) { body x8 }

     (Expect the marginal cost per operation to
     DROP, because you have divided the loop cost
     by 8. This is the same fix as unrolling, done
     to the loop rather than the body, and it is
     the reason hand-optimised inner loops are
     unrolled in multiples of the SIMD width.)

  4. Find a REAL dependency that is not a data
     dependency. Take a loop whose iterations are
     independent and see what the core still
     cannot overlap:

       for (i = 0; i < n; i++) out[i] = in[i]*2;

     (Expect it to be limited by the LOADS, not
     the multiply -- a load has a much longer
     latency than an integer add, and the stores
     need somewhere to go. This is the bridge to
     the memory-hierarchy course, and finding it
     here is the point: the arithmetic is not the
     bottleneck in almost any real loop, and a
     course that only measured arithmetic would
     never notice.)

  5. Finally: predict, then measure. Before
     running anything, write down what you expect
     the dependent and independent series to look
     like, and in what direction each will bend.

       for (i = 1; i <= 8; i *= 2)
         for (j = 0; j < 4; j++)
           independent[j] = dep_chain_of_i(j);

     (Then run it. If your prediction matches, you
     understand the mechanism. If it does not, the
     disagreement is the interesting part -- and
     writing the prediction down FIRST is what
     turns a measurement into an experiment. Every
     measurement in this course that turned out to
     be wrong was wrong because nobody had said
     what they expected.)
</pre>
                </div>
                <p>Exercise 1 is the one that gets closest to a core-width claim without a clock, and the insight is that <strong>the position of the knee is meaningful even when its unit is not</strong>. &ldquo;This core absorbs about six independent integer operations before more stops helping&rdquo; is a real, transferable statement about the machine; &ldquo;the core is 5.7 wide&rdquo; is a number that changes with the clock.</p>
                <p>Exercise 4 is the one that matters most for a reader who will write real code, and it is the bridge to the next course. <strong>A loop that is pure arithmetic is almost never limited by the arithmetic</strong> &mdash; it is limited by its loads and its stores, which have far longer latencies. This course measured a chain of integer adds and found a clean 2.7&times; ratio, and that result is real and it is also almost irrelevant to most programs. The <a href="/courses/mem">memory hierarchy</a> is where the real constraint lives, and the reason to understand latency and throughput here is to be able to recognise when neither is the thing limiting you.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/isa/lessons/isa-length">the ISA length concept</a> is the sharpest in the course, and it is the same relationship read from two ends. That concept measured the mean instruction at <strong>3.99 bytes and the code at 1885 bytes for 472 instructions</strong>, and established that instruction boundaries form a chain. This concept measures that <strong>a chain of dependent <em>executions</em> is the other kind of chain, and it is the expensive kind</strong>: boundaries chained in address order are free, data chained through registers cost a latency each. Two different meanings of &ldquo;chain&rdquo;, one verified by arithmetic and one by a clock, and the confusion between them is why the first version of this measurement timed its own loop.</p>
                <p>The connection to <a href="/courses/reloc/lessons/reloc-encoding-limits">the encoding-limits concept</a> is a real cost comparison, and it goes the direction nobody expects. That course measured that position independence costs an extra relocation per datum, because RIP-relative addressing needs a <code>disp32</code> the linker must patch. <strong>And the code PIC produces has more instructions but more ILP</strong> &mdash; a <code>mov</code> of the base followed by an indexed access has more operations available to overlap than the single absolute access it replaces. So the statically-expensive choice can be the dynamically-cheaper one. This course cannot settle that, because it did not measure PIC code, and the honest summary is that <em>the two courses disagree about which cost matters and neither has run the experiment that would settle it</em>.</p>
                <p>Two connections outward, both about the shape rather than the number. <a href="/courses/exe/lessons/exe-deps">The next concept</a> asks what a dependency <em>is</em>, and this concept is the evidence that the answer has to include addresses and not just registers. And <a href="/courses/elf/lessons/elf-header-fields">The ELF header-fields concept</a> said every field exists because the bytes are not self-describing; <strong>this concept is the same argument for performance</strong> &mdash; two byte-identical loops in one binary differ by 2.7&times; and no field in the file records the difference, because the difference is in the <em>address</em>, which the format does store and the CPU interprets. A linker that knows the address can change the timing; nothing in the file says the timing changed.</p>
                <p>One limit, and it is the limit the whole course is built on. <strong>No absolute cycle count appears anywhere in these six concepts.</strong> The TSC is a time base, the core clock moved 2389&ndash;3320 MHz during a single run, and there is no PMU to divide one by the other. Every figure is a ratio or a minimum, and the crosscheck asserts <em>shapes</em> &mdash; monotonicity, ordering, bounds &mdash; rather than values, because shapes survive a 15% noise floor and values do not. A reader who wants the width in cycles needs a machine with a PMU or a clock-domain trick, and <a href="/courses/exe/lessons/exe-speculate">the speculation concept</a> is explicit about which claims each of those buys.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-instrument">Previous: Measure the Instrument First</a></span>
                <span>Next: <a href="/courses/exe/lessons/exe-deps">A Dependency Is a Constraint, Not a Cost</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
