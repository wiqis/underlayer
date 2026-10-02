// How a CPU Executes Instructions — course landing page
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("How a CPU Executes Instructions — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    // THE PRE-PAINT THEME.  This landing page calls render_lesson_nav, which
    // passes lesson=true and therefore skips the theme script -- correct for a
    // LESSON, whose palette is hardcoded light, but wrong here: this is a
    // course landing page and a reader who chose dark, or whose OS is dark,
    // should not get a flash of light before the page settles.
    //
    // Two lines, and the alternative is to change what these 28 pages call --
    // a layout change across the whole collection that is worth doing on its
    // own and is not what the flash report asked for.
    render_theme_boot_js(&mut page, false)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>How a CPU Executes Instructions</h1>
            <div class="lesson-meta">6 concepts &middot; 3 modules &middot; 150 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p><a href="/courses/isa/lessons/isa-decode">The ISA course ended</a> with a decoder that can tell you what any byte sequence means. It is a complete account of the <em>encoding</em>, and it says nothing at all about what the hardware does next. That is the gap this course fills &mdash; and the <code>word-boundary</code> check says the gap is total, not thin.</p>
                <div class="formula">
  `microarchitecture`  0 files      `pipel`         0 files
  `branch predict`     0 files      `superscalar`   0 files
  `reorder buffer`     0 files      `store buffer`  0 files
  `register renaming`  0 files      `throughput`    0 files
  `IPC`                0 files      `4K alias`      0 files
  `clock cycle`        0 files      `false depend`  0 files

  out of ~52 concept files written before this
  one. the bytes became a language; nothing
  covered the machine that runs them.
                </div>
                <p>And the reason this course is shaped the way it is is a measurement, not a preference. <strong>The instrument&rsquo;s apparent noise turned out to be the phenomenon under study.</strong> The first draft of the benchmark quoted a 73% run-to-run spread, which would have made every number in it unpublishable. It was not the machine: it was two byte-identical loops sitting at different addresses, one of them paying a fixed penalty that got rediscovered on every run.</p>
                <p>Six concepts in three modules, and the order is the argument:</p>
                <div class="formula">
  MODULE 1  The Instrument
            measure the instrument first: a TSC
            tick is TIME, not a cycle, and the
            noise floor decides what may be claimed
            latency and throughput: a dependent
            chain costs 2.7x an independent
            operation, and the ratio is the
            execution width made visible

  MODULE 2  Dependencies and the Front End
            a dependency is a constraint, not a
            cost -- and an ADDRESS is a
            constraint too, worth up to 2.5x
            the front end: a branch repeating with
            period 1, 4, 16 or 64 costs the same
            as one that is never taken

  MODULE 3  Speculation and Its Limits
            no mispredict penalty was observed at
            any pattern period, and without a PMU
            that is a limit rather than a result
            the harness: 37 checks that assert
            shapes rather than values, and the
            retractions asserted as text
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Three findings, and the machine they came from</h2>
                <p>Up front, because two of these rows decide what the course may claim: <strong>AMD Ryzen 5 7430U (Zen 3), 6 cores, in a virtualised guest. TSC 2.2959 GHz invariant. Core clock measured 2389&ndash;3320 MHz during a single run. No hardware PMU.</strong></p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/E0/,/E1/p'
    logical CPUs: 12   cores per socket: 6
    cache line: 64 bytes
    L1 Data 32K    8    ways, 64 B line
    L1 Instruction 32K    8    ways, 64 B line
    L2 Unified 512K    8    ways, 64 B line
    L3 Unified 16384K 16   ways, 64 B line
    constant_tsc: yes   nonstop_tsc: yes
    perf_event_paranoid = 4
    perf CANNOT read branch-misses in this guest.
</pre>
                </div>
                <p><strong>Finding one: a TSC tick is a unit of time, not a count of core clocks.</strong> The TSC is fixed at 2.2959 GHz; the core moved between 2389 and 3320 MHz within one run. So any &ldquo;cycles&rdquo; figure derived from <code>rdtsc</code> alone is a stopwatch reading, and that is why this course quotes <strong>no absolute cycle count anywhere</strong> &mdash; every figure is a ratio or a minimum, because a ratio has the same clock on both sides and the clock cancels.</p>
                <p><strong>Finding two: the address of a loop is worth up to 2.5&times;, and the code does not record it.</strong> The same body emitted at eight offsets within a 64-byte boundary spans 1.00&times; to 2.51&times; of the fastest, and the slowest offset is <em>not</em> the one that crosses the line &mdash; so no mechanism is claimed, and the three candidates are named and left unmeasured.</p>
                <p><strong>Finding three: a dependent chain costs 2.7&times; an independent operation</strong>, and the shape is clearer than the number. Dependent is linear in chain length with a steep slope; independent is nearly flat and then bends, and the bend is where the core runs out of places to start work.</p>
            </div>

            <div class="unit unit-example">
                <h2>The artifact, and the limit it reports about itself</h2>
                <p>One program, seven sections, and the first two sections are about the instrument rather than the machine:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/2. THE NOISE/,/3. LATENCY/p'
  2. THE NOISE FLOOR, measured before any claim is made
  ------------------------------------------------------
     the SAME body, 8 times, consecutive:
       fastest 0.9401   slowest 1.0894   spread 15.1%
     =&gt; a 15% spread means absolute numbers from this machine are
        not publishable. Only ratios measured back-to-back are, and
        that is why every number below is a ratio or a minimum.

     A RETRACTION. The first draft of this program quoted a 73%
     noise floor. That number was measured on a bench function
     that was NOT 64-byte aligned, so it was the alignment
     penalty of section 7 leaking into the noise estimate -- the
     instrument's apparent noise was the phenomenon under study.
     Measured properly, on an aligned body, the spread is roughly
     half that. The 73% figure is not used anywhere in this course.
</pre>
                </div>
                <p>And the last section reports the course&rsquo;s biggest limit, in the artifact&rsquo;s own words rather than in a footnote:</p>
                <div class="hex-dump">
                    <pre>     THIS IS A LIMITATION, NOT A RESULT ABOUT PREDICTORS.
     There are no hardware performance counters in this guest, so
     branch misses cannot be COUNTED here, only inferred from
     timing. Either this CPU's predictor captures patterns that
     long, or the cost is hidden by slack this program did not
     identify, and without a branch-miss counter the two cannot be
     told apart. The course says so rather than inventing a number.
</pre>
                </div>
                <p>And the harness, 37 checks, <strong>none of which asserts a number</strong>. A 15% noise floor cannot verify a value; it can verify a shape. So the checks assert that a dependent chain grows monotonically, that the marginal cost of a dependency exceeds that of an independent operation, that the branch period makes no difference &mdash; and, in one group, that every bench body really is 64-byte aligned, read exactly out of the ELF symbol table with no clock involved at all.</p>
            </div>

            <div class="unit unit-example">
                <h2>What was retracted</h2>
                <p>Five claims did not survive measurement. All are in <code>research.md</code>, three are printed by the artifact itself, and four of the five are asserted by the crosscheck so a future edit cannot quietly drop them.</p>
                <p><strong>&ldquo;The noise floor is 73%.&rdquo;</strong> It is about 15%. The 73% figure was measured on a misaligned function, so it was the alignment effect leaking into the noise estimate. <strong>&ldquo;The flags register has no rename, so flag-writing instructions serialise.&rdquo;</strong> Wrong &mdash; four <code>TEST</code>s cost 1.45&times; the floor. <strong>&ldquo;Reading the flags is what costs.&rdquo;</strong> Also wrong, and it was the obvious replacement for the previous one: four <code>ROR</code>+<code>ADC</code> pairs measured 1.05&times; four bare <code>ROR</code>s. Three candidate explanations, two retracted, and the survivor is an ordinary dependency that the latency concept had already described.</p>
                <p>Plus five errors in the tooling, kept because they are the lesson. <strong>A benchmark the compiler deleted</strong> &mdash; the first unpredictable-branch measurement returned 0.0000 ticks because the compiler proved a deterministic sum was constant. <strong><code>test $1, $1</code> does not exist</strong>, and a helper named <code>floor</code> collides with the libc builtin. <strong>Padding a benchmark with 64 bytes of <code>0x66</code> segfaulted</strong>, because that is 64 prefixes and x86-64 permits 15. <strong>A stale kernel sample was treated as a live clock reading</strong>, making &ldquo;cycles&rdquo; wrong by up to three times. And <strong>a prose sentence matched a data regex</strong>, overwriting the parsed marginals with an empty list.</p>
                <p>The common thread is the collection&rsquo;s standing rule: <strong>a check that fails for the wrong reason is worse than no check, because it teaches you to ignore it</strong> &mdash; so in every case the fix went into the harness and never into the artifact, and every time the artifact was right.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Start Here</h2>
                <p>If you want the surprise first, go to <a href="/courses/exe/lessons/exe-instrument">Measure the Instrument First</a> &mdash; the TSC is not a cycle, and the first number the benchmark printed was wrong in a way that turned out to be the whole course. If you want the payoff, go to <a href="/courses/exe/lessons/exe-verify">The Instrument and the Oracle Loop</a> and break a check on purpose.</p>
                <p>Either way the thing to take away is not a latency. <strong>It is that a measurement on a machine with a moving clock and no performance counters is only as good as the account of its own limits</strong>, and that the account is the deliverable. The next course points the same instrument at memory, which is where most real programs actually stop &mdash; and it will need everything this one had to build first.</p>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
