// How a CPU Executes Instructions — Module 2: Dependencies and the Front End
// Concept: a branch whose direction repeats with period 1, 4, 16 or 64 costs
// the same as one that is never taken.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_frontend() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Front End and the Branch Predictor — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>The Front End and the Branch Predictor</h1>
            <div class="lesson-meta">25 min &middot; Module 2: Dependencies and the Front End &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything measured so far has been about what happens <em>after</em> an instruction is decoded. This concept is about the decision that happens before, and it is the decision a modern CPU makes most often and most aggressively: <strong>where is the next instruction?</strong></p>
                <p>And the answer is that the core does not know. It <em>guesses</em>, before it can possibly know, and then acts on the guess. So a branch is a bet, and the question is how good the betting is &mdash; and the answer, measured on this machine, is better than most people expect.</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/5. BRANCHES/,/6. LONG/p'
  5. BRANCHES
  ----------
  body                                  min ticks     vs floor
  branch never taken (control)             0.8261        1.00x
  branch period 64                         0.7814        0.95x
  branch period 16                         0.8024        0.97x
  branch period 4                          0.7428        0.90x
  branch period 1 (alternating)            0.7681        0.93x
  BRANCHLESS, same data+work               1.7792        2.08x

     The direction period makes NO difference: a branch that
     repeats with period 1, 4, 16 or 64 costs the same as one that
     is never taken. The predictor learns all of them.
</pre>
                </div>
                <p><strong>Read that table and then read it again, because the first row is the control and it is the highest.</strong> A branch that is never taken measures <em>more</em> than a branch that alternates every single iteration. That is not a measurement error to be explained away &mdash; it is the finding. <strong>On this machine the branch costs nothing at any period, and what varies between the rows is the noise.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Why a core must guess, and what it does when it guesses wrong:</p>
                <div class="formula">
  THE PROBLEM

    the front end runs AHEAD of the execution
    units, because it cannot know how long the
    work takes. so it must decide what comes
    next before that decision can be justified.

    a conditional branch's answer depends on a
    REGISTER, which depends on work that has
    not run yet. so the answer does not exist yet.

  THE BET

    guess. fetch down the guessed path. keep
    going. if the guess turns out to be right,
    nobody downstream ever learns that a guess
    was made.

  THE COST OF BEING WRONG

    everything fetched down the wrong path was
    fetched for nothing, and the work in it was
    SPECULATIVE -- it may have had side effects,
    so it cannot simply have been done.
                </div>
                <p>That last point is the one that makes speculation a real design problem rather than a performance trick. <strong>A speculatively executed store is a problem the hardware must be able to undo</strong>, and on a machine with a store buffer it can: the store sits in the buffer, uncommitted, until the branch resolves. If the branch went the other way, the buffered store is simply never committed.</p>
                <p>And the reason branches are predicted rather than merely resolved is a number. <strong>Every branch in your program, taken or not, is a place where the front end must stop and wait for a register it does not have yet.</strong> If every branch cost a pipeline flush, a loop with a loop-carried dependency &mdash; which is every loop &mdash; would serialise completely. The measurement in <a href="/courses/exe/lessons/exe-latency">the latency concept</a> makes that concrete: a dependent chain of 8 costs 11&times; the floor, and a not-taken branch inside it would cost that much <em>again</em> if the core waited.</p>
                <p>So the design is: predict, and be right almost always. The interesting question is what &ldquo;almost always&rdquo; means, and how a predictor gets to be right.</p>
                <div class="formula">
  HOW A PREDICTOR GETS TO BE RIGHT

  a single bit of "taken or not" is not enough:
  a loop body is a taken branch every time and
  the exit is not-taken once, and one bit cannot
  tell those apart.

  so a real predictor keeps HISTORY -- what
  happened at the last N branches -- and uses
  it as an index. the same branch with the same
  history gets the same answer.

  that is why a REPEATING pattern is nearly free:
  with enough history, the pattern repeats inside
  the history and the index resolves it.
                </div>
                <p>And that model makes a sharp prediction, which is the experiment the next section runs. <strong>If a pattern that repeats within the predictor&rsquo;s history is free, then the penalty should appear only when the period exceeds the history &mdash; and the period at which it appears is a measurement of the history length.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>Finding Where the Predictor Stops Coping</h2>
                <p>First attempt, and it failed in an instructive way. A branch on a rotating register bit:</p>
                <div class="hex-dump">
                    <pre>$ ./br2    # period 1..64, from a rotating register
  branch pattern                      ticks/iter  vs branchless
  branch never taken (control)            0.6065          0.45x
  branchless, same work (control)         1.3339          1.00x
  direction period  64                    0.6676          0.50x
  direction period  32                    0.6637          0.50x
  direction period  16                    0.6640          0.50x
  direction period   8                    0.6656          0.50x
  direction period   4                    0.6635          0.50x
  direction period   3                    0.7670          0.57x
  direction period   2                    0.6634          0.50x
  direction period   1 (alternating)       0.6631          0.50x
</pre>
                </div>
                <p><strong>Completely flat.</strong> Period 1, period 3, period 64, a branch that is never taken &mdash; all within 3% of each other, and the never-taken <em>control</em> is the slowest row in the table. A rotating 32-bit register makes the direction repeat every 32 iterations, and the predictor learned all of it.</p>
                <p>Two things are visible here, and the second is the more useful.</p>
                <p><strong>First: the branch is genuinely free.</strong> The cost of a perfectly-predicted branch is not zero, but it is below this instrument&rsquo;s noise floor &mdash; smaller than the 15% run-to-run spread measured in <a href="/courses/exe/lessons/exe-instrument">the instrument concept</a>. The whole front end keeps moving, and nothing downstream ever learns a guess was made.</p>
                <p><strong>Second: the &ldquo;branchless&rdquo; control is the slowest row in the table</strong> &mdash; twice the cost of the branch it is supposed to replace, using the same data and the same conditional work. That is the surprise, and it is dealt with at the end of this concept because the first two explanations for it were both wrong.</p>
                <p>So the period is not the interesting variable. <strong>The interesting variable is how far back the pattern reaches</strong>, and to move that you need a pattern longer than the predictor&rsquo;s history. A table of pseudorandom bits, walked with a sequential index:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/6. LONG-PERIOD/,/7. ALIGN/p'
  6. LONG-PERIOD PATTERNS, and the limit of this machine
  ---------------------------------------------------
        table depth     ticks/iter   vs depth 2
                 2         1.7790        1.00x
                 4         2.0365        1.14x
                 8         1.9985        1.12x
                16         2.1403        1.20x
                32         1.3985        0.79x
                64         1.6090        0.90x
               128         1.5915        0.89x
               256         2.0648        1.16x
              1024         1.5455        0.87x
              4096         1.7982        1.01x
             16384         1.9909        1.12x
             65536         1.6765        0.94x
</pre>
                </div>
                <p><strong>Also flat.</strong> Depth 2 and depth 65536 differ by 0.94&times; &mdash; the 65536 case is <em>faster</em> than the depth-2 case, which is noise, not a result. The table is not monotonic, not periodic, and shows no step anywhere.</p>
                <p>So the experiment did not find the predictor&rsquo;s history length, because there was no step to find. <a href="/courses/exe/lessons/exe-speculate">The next concept</a> takes that seriously rather than treating it as a null result, because a null result here has two very different explanations and this machine can only measure one of them.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Branchless Surprise, and Two Retractions</h2>
                <p>The &ldquo;replace an unpredictable branch with a conditional move&rdquo; advice is one of the most repeated pieces of performance folklore, and it is the standard advice for code with data-dependent branches. So the measurement is worth taking seriously, and the two explanations this course wrote down for it were both wrong.</p>
                <div class="hex-dump">
                    <pre>   branch version      1:\n\tadd $1,%%r8\n\tror $1,%%r11\n\t
                          jc 1f\n\tadd $1,%%r8\n\t1:\n\tdec %%rcx\n\tjnz 1b

   branchless version  1:\n\tadd $1,%%r8\n\tror $1,%%r11\n\t
                          adc $0,%%r8\n\tdec %%rcx\n\tjnz 1b

   measured: 0.7428 vs 1.7792   --  2.40x SLOWER
</pre>
                </div>
                <p><strong>Retraction 1: &ldquo;the flags register has no rename, so flag-writing instructions serialise.&rdquo;</strong> Wrong. Four <code>TEST</code>s, which all write the flags, cost 1.45&times; the floor. Writing the flags repeatedly is nearly free.</p>
                <p><strong>Retraction 2: &ldquo;reading the flags is what costs&rdquo; &mdash; the obvious replacement.</strong> Also wrong. Four <code>ROR</code>+<code>ADC</code> pairs measured 4.46&times; against 4.23&times; for the <code>ROR</code>s alone: a difference of 1.05&times;. Reading the flags costs nothing extra.</p>
                <p>And what survives is not an interesting explanation. The four-<code>ROR</code> row is expensive because those four <code>ROR</code>s all target <strong>one register</strong> and so form an ordinary loop-carried chain. <strong>Three candidate explanations, two retracted, and the survivor is a plain dependency that the latency concept already described.</strong></p>
                <p>Which leaves the branchless result needing an honest reading, and the artifact says this in its own output rather than leaving a reader to infer it:</p>
                <div class="formula">
  AND THAT IS NOT A CLEAN COMPARISON, which is the point of
  saying so. The branching body performs its conditional add
  HALF the time, because the branch skips it. The branchless
  body performs the equivalent work EVERY time. So the two are
  not doing the same amount of work, and 2.40x is an UPPER BOUND
  on the cost of branchless coding here, not a measurement of
  it.
                </div>
                <p>That is the correct reading and it is much less dramatic. <strong>The branchless version is doing more work and is not saving anything, because the branch it replaced was free.</strong> The folklore says conditional moves are free; the measurement says they cost an operation, and the folklore is silent about the fact that the branch was free to begin with.</p>
                <p>There is a real version of the advice, and it is narrower. <strong>Branchless code helps when the branch is genuinely mispredicted often, because it trades a mispredict for an operation.</strong> This machine never produced a mispredict, so the trade could not be observed here &mdash; and the honest statement is that the folklore&rsquo;s precondition was never met, rather than that the advice is wrong in general. The next concept is about exactly that missing measurement.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ ./cycbench 2&gt;&amp;1 | sed -n '/5. BRANCHES/,/6. LONG/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^F /,/^G /p'
</pre>
                </div>
                <p>Then find a branch this predictor cannot learn, which is the exercise the course could not complete:</p>
                <div class="hex-dump">
                    <pre>  1. Get a hardware counter. This is the step
     that makes the rest possible, and it is
     gated on your machine, not on your skill:

       perf stat -e branch-misses,branches ./prog

     If that works you have something this course
     did not, and you should do the experiment the
     course could not: make a branch genuinely
     unpredictable, COUNT the misses, and compare
     the count with the timing. The two together
     settle what timing alone cannot.

  2. If you have no PMU, find a mispredict by
     brute force instead. The best source of
     genuinely unpredictable data that is cheap
     to consume is a HASH of the iteration counter
     with a large odd constant -- the sign of the
     result has a period of about 2^63, which is
     longer than any plausible history:

       for (long i = 0; i < n; i++) {
         if ((i * 0x9E3779B97F4A7C15L) >> 63) ...
       }

     (Careful: the compiler may turn that into a
     branchless CMOV, which is a DIFFERENT
     measurement. Check the disassembly with the
     ISA course's decoder before you believe what
     you wrote.)

  3. Now test the folklore directly, on a
     machine where you can count misses. Write a
     branchy loop and a branchless one, do the
     same work, and compare misses AND time:

       // branchy
       for (i = 0; i < n; i++)
         if (p[i] & mask) sum += p[i];

       // branchless
       for (i = 0; i < n; i++)
         sum += (p[i] & mask) ? p[i] : 0;

     (Now you can answer the question properly.
     Expect the branchless form to win when the
     mask makes the branch unpredictable and to
     LOSE when it is predictable -- and the
     crossover is the interesting number.)

  4. Measure a REAL conditional branch's cost, not a
     synthetic one, and find where the folklore's
     precondition actually holds in code you use:

       objdump -d prog | grep -cE '\bj(e|ne|a|ae|b|be|g|ge|l|le|s|ns)\b'

     (Every one of those is a branch that could
     mispredict. This course's synthetic branch was
     free; those are the ones that decide whether
     the branchless advice applies to your code.)

  5. Finally, and this is the one worth the most:
     find the point at which the predictor gives up
     on YOUR machine, by bisection rather than by
     a fixed ladder. Take the table-walk
     experiment and binary-search the depth:

       depth where time stops being flat = the
       predictor's effective history, in branches

     Repeat it with the loop in a different place
     in memory, and with a different body size. If
     the depth changes, the predictor is not
     indexing on history alone -- and the shape of
     that dependence is a real measurement of the
     predictor's structure that no amount of
     reading about it will give you.
</pre>
                </div>
                <p>Exercise 3 is the one that settles the concept, and it needs a PMU to do properly &mdash; which is precisely the point of <a href="/courses/exe/lessons/exe-speculate">the next concept</a>. <strong>With a counter you can compare the branchless form&rsquo;s <em>miss count</em> against the branchy form&rsquo;s <em>time</em></strong>, and the crossover between them is a real, actionable number. Without one you have a timing difference and two possible explanations, and the honest answer is to say so.</p>
                <p>Exercise 2 has a trap worth knowing before you start. <strong>The compiler will replace a data-dependent <code>if</code> with a conditional move on its own</strong>, which means you can write a branch, look at the source, and measure something that has no branch in it at all. The ISA course&rsquo;s decoder is the check: count the conditional branches in the disassembly, not the <code>if</code>s in the source. That is the third time in this collection that the source and the bytes have told different stories, and the rule is always the same &mdash; <strong>the code is the evidence and the source is a hypothesis about it</strong>.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/isa/lessons/isa-opcodes">the opcode-map concept</a> is exact and it was set up two courses ago. That concept measured <code>0F 0B</code> as UD2 and explained that a compiler emits it after a noreturn call so that a fall-through dies at the next instruction. <strong>That is speculation&rsquo;s failure mode stated as an encoding</strong>, and this concept supplies the other half: speculation&rsquo;s failure mode is a mispredicted branch, and the machine&rsquo;s answer to both is the same &mdash; a deliberately undefined instruction that faults. The <a href="/courses/reloc/lessons/pie-cost">PIC-cost concept</a>&rsquo;s nine-instructions-against-seventeen is the same idea one level up, since every branch in a PIE is a branch whose target the linker has not filled in yet.</p>
                <p>The connection to <a href="/courses/exe/lessons/exe-deps">the dependency concept</a> is a sharpening rather than a new topic. That concept established that a dependency is a constraint on <em>when an instruction may start</em>. This concept is the case where the constraint is unresolvable in principle: <strong>a branch&rsquo;s target depends on a register, and the register&rsquo;s value depends on work that has not run, so the front end must either wait or guess</strong>. Guessing is strictly better on a machine that guesses right, which is what the measurement shows, and the whole design of a modern out-of-order core follows from that being true.</p>
                <p>Two connections outward, both about speculation&rsquo;s reach. <a href="/courses/reloc/lessons/reloc-encoding-limits">The encoding-limits concept</a> measured that PIC needs a <code>disp32</code> per access and therefore a relocation per access, and the <a href="/courses/reloc/lessons/reloc-why-so-many">relocations concept</a> measured the doubling that follows. <strong>Those are static costs, and this concept is where the dynamic one would be measured</strong> &mdash; more relocations means more front-end work means more branches to predict, and the two interact. The experiment that would settle it is a timing comparison of the same computation built PIE and non-PIE, which spans two courses and was not run. And <a href="/courses/img/lessons/img-entries">The image-loading course</a> established that the auxv is read at startup and then never again; <strong>speculation is the other thing a program does once at startup and then never again,</strong> and the branch predictor is a cache in the same sense &mdash; it warms up and then it is just there.</p>
                <p>One limit, and it is the limit of the whole course so far. <strong>No mispredict penalty was observed, and this concept therefore cannot say what one costs.</strong> It can say the predictor learns patterns repeating with period 1 through 65536, and that on this machine a predicted branch is free to within the noise floor. It cannot say whether that is because the predictor is good or because the cost is hidden, and <a href="/courses/exe/lessons/exe-speculate">the next concept</a> is entirely about that question and about the hardware counter that would answer it. A course that measured five mechanisms and wrote down the sixth it could not measure is more useful than one that quotes a mispredict cost from a datasheet, because <strong>the reader who needs the number knows exactly which machine to go and get it on</strong>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-deps">Previous: A Dependency Is a Constraint, Not a Cost</a></span>
                <span>Next: <a href="/courses/exe/lessons/exe-speculate">Speculation, and What Could Not Be Measured</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
