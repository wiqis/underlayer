// How a CPU Executes Instructions — Module 3: Speculation and Its Limits
// Concept: no mispredict penalty was observed at any pattern period, and
// without a PMU that is a limit rather than a result.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_speculate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Speculation, and What Could Not Be Measured — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>Speculation, and What Could Not Be Measured</h1>
            <div class="lesson-meta">25 min &middot; Module 3: Speculation and Its Limits &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The obvious centrepiece of a course on how a CPU executes instructions is the cost of a mispredicted branch. Every textbook has a number for it &mdash; fifteen cycles, twenty cycles, &ldquo;one and a half pipelines&rdquo; &mdash; and this course is not going to give you one, because <strong>it could not measure one and the reason is worth more than the number would have been.</strong></p>
                <div class="hex-dump">
                    <pre>$ ./build_samples.sh 2&gt;&amp;1 | sed -n '/perf_event_paranoid/,/perf CANNOT/p'
    perf_event_paranoid = 4
    event sources: amd_iommu_0 breakpoint cpu ibs_fetch ibs_op kprobe msr
                    power power_core software tracepoint uprobe
    perf CANNOT read branch-misses in this guest. There is no hardware
    PMU, so mispredictions cannot be COUNTED -- only inferred from
    timing, and the two explanations cannot be told apart.
</pre>
                </div>
                <p>That is a measurement, not an excuse. <code>perf stat -e branch-misses</code> fails on this machine, <code>perf_event_paranoid</code> is 4, and the event sources are all software constructs &mdash; <code>breakpoint</code>, <code>kprobe</code>, <code>tracepoint</code>, the IBM performance counters. <strong>There is no hardware performance monitoring unit, so a branch misprediction cannot be counted.</strong></p>
                <p>And that removes the only ground truth that would settle the question. Everything else this course has measured &mdash; the 2.7&times; dependency ratio, the 2.04&times; alignment spread, the flat branch table &mdash; is a <em>timing</em>, and a timing has at least two explanations whenever the thing you expect to see does not appear.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What speculation is, in the terms the ISA course already gave you:</p>
                <div class="formula">
  THE FRONT END GUESSES. THE BACK END CHECKS.

    guess:     fetch down the predicted path
    check:     the work proceeds in order, and
               when the branch finally resolves,
               either the guess was right and
               nothing happened, or it was wrong
               and everything after it is wrong.

  the things a wrong guess can have done:
    - read from addresses            (harmless)
    - written to registers          (harmless, the
                                     registers are
                                     renamed)
    - STORED to memory              (NOT harmless --
                                     must be undoable)
    - trapped or done an I/O        (NOT undoable --
                                     so the core does
                                     not speculate those)

  which is the whole design: speculate on
  everything that is reversible, and refuse to
  speculate on everything that is not.
                </div>
                <p>That word &ldquo;renamed&rdquo; is doing more work than it appears to, and it connects directly to <a href="/courses/exe/lessons/exe-deps">the dependency concept</a>. A register that a wrong guess wrote is not a problem because the physical register was never touched &mdash; the execution units were reading a <em>renamed</em> copy, and when the guess turned out wrong the whole set of renames is discarded. So speculation is only safe because renaming already made most of its effects reversible.</p>
                <p>And the cost of being wrong has two parts, which textbooks conflate and which are worth separating because they are paid in different places:</p>
                <div class="formula">
  1. THE WORK ALREADY DONE

     every instruction on the wrong path ran to
     completion, occupied an execution unit, and
     produced a result that is thrown away.

     paid as: throughput. the units were busy.

  2. THE PIPELINE DRAIN

     when the branch resolves, the instructions
     after it are WRONG and must be discarded.
     anything not yet issued is cancelled, and
     the front end restarts fetching from the real
     target. meanwhile there is nothing in the
     machine to do.

     paid as: latency. a dead stall.

  the two together are what a "mispredict
  penalty" means, and they are not a single
  number -- they are a throughput loss and a
  stall, and a workload with slack hides the
  first and suffers the second.
                </div>
                <p><strong>That distinction is the key to understanding this course&rsquo;s null result.</strong> A microbenchmark loop with a tight dependency chain has no slack: there is nothing else to run while the machine drains. So if a mispredict were happening, the drain should be maximally visible. The fact that it is not, is evidence &mdash; but it is not proof, and the two remaining explanations are these.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Two Explanations, and Why the Measurement Cannot Separate Them</h2>
                <p>The experiment was designed to force a mispredict. A table of pseudorandom bits, walked sequentially, branching on each one, for a pattern that repeats only after <em>D</em> branches:</p>
                <div class="hex-dump">
                    <pre>$ ./cycbench 2&gt;&amp;1 | sed -n '/6. LONG-PERIOD/,/7. ALIGN/p'
     Flat from depth 2 to depth 65536. NO mispredict penalty
     was observed, at any pattern period.

     THIS IS A LIMITATION, NOT A RESULT ABOUT PREDICTORS.
     There are no hardware performance counters in this guest:
       perf_event_paranoid = 4, and /sys/bus/event_source/devices
       has no cpu_core PMU -- only breakpoint, kprobe, software,
       tracepoint and the IBM PCs. So branch misses cannot be
       COUNTED here, only inferred from timing.
     Either this CPU's predictor captures patterns that long, or
     the cost is hidden by slack this program did not identify,
     and without a branch-miss counter the two cannot be told
     apart. The course says so rather than inventing a number.
</pre>
                </div>
                <p>And the measurement is a real null result, not a failure to set up the experiment. <strong>65 536 pseudorandom bits is a period far longer than any plausible predictor history</strong>, so if the cost is a function of the pattern period, something should have happened. Nothing did.</p>
                <p>So there are two explanations, and <strong>the honest thing is to write both down rather than pick the flattering one</strong>:</p>
                <div class="formula">
  EXPLANATION 1: the predictor really did learn it.

    a TAGE-class predictor indexes on a long
    global history, so two visits to the same
    branch with the same recent history get the
    same answer -- and a 65536-entry pattern is
    65536 distinct histories. if the history
    register and the tables are that large, the
    pattern is learnable in principle.

    this predicts: no penalty at any depth, which
    is what was seen.

  EXPLANATION 2: the cost is hidden.

    if the branch is not on the critical path --
    if the loop has enough independent work that
    the machine has something else to do while
    the wrong path drains -- then the drain costs
    throughput and not latency, and the timing
    barely moves.

    this ALSO predicts: no visible penalty, and it
    is the more likely of the two for a loop whose
    body is a load and a compare.
                </div>
                <p>Separating them needs one number this machine cannot produce. <strong>Count the misses.</strong> If the miss count is high and the time is flat, the cost is hidden and the predictor is doing nothing. If the miss count is near zero, the predictor learned the pattern. One counter, and the question closes.</p>
                <p>Which is why the course&rsquo;s <a href="/courses/exe/lessons/exe-frontend">front-end concept</a> ends where it does. Its &ldquo;replace an unpredictable branch with a conditional move&rdquo; finding is a <strong>conditional</strong> result: branchless code trades a mispredict for an operation, and this machine never mispredicted, so the trade was never available and the measurement only shows that the operation is not free. <strong>The folklore&rsquo;s precondition &mdash; a branch that mispredicts often &mdash; was never met here, so the folklore was not tested.</strong> That is a narrower claim than the one a reader might want, and it is the one the data supports.</p>
            </div>

            <div class="unit unit-example">
                <h2>What a Limit Looks Like When You Write It Down</h2>
                <p>There is a temptation, when an experiment returns nothing, to write the expected number and attribute it to the general case. This course has refused that six times across two courses, and the shape of the refusal is the same each time:</p>
                <div class="formula">
  NOT:  "a mispredict costs about 15 cycles"
       (measured nowhere, attributed to nobody)

  BUT:  "no mispredict penalty was observed at
        any pattern period from 1 to 65536, on
        this machine, with this instrument.

        there are no hardware performance
        counters in this guest, so a mispredict
        cannot be counted. either the predictor
        learned the pattern, or the cost was
        hidden by slack. a branch-miss counter
        would tell the two apart and is named as
        the thing that would."
                </div>
                <p>The second version is longer, and every word of the extra length is doing work: it says what was measured, on what, and what would change the answer. <strong>A reader who needs the number knows exactly which experiment to run and on what hardware. A reader handed the number has to trust where it came from.</strong></p>
                <p>And the discipline extends to the artifact itself, which is where it is easiest to cheat. The instrument <em>prints its own limit</em>, so anyone running it sees it:</p>
                <div class="hex-dump">
                    <pre>  ============================================================
   no absolute cycle count is claimed anywhere above. every
   figure is a ratio or a minimum, for the reasons in section 1.
  ============================================================
</pre>
                </div>
                <p>That is a design choice with a cost. A tool that prints its own limitations is longer, and a reader looking for the headline number has to read past the caveat. <strong>The alternative is a tool that prints only the number, and that is what every datasheet and every benchmark summary ever produced</strong> &mdash; and the reason this collection&rsquo;s verification sections exist is that those sources are not wrong so much as incomplete, in ways a reader cannot see.</p>
                <p>One more thing the limit buys, which is worth stating because it is easy to miss. <strong>Knowing what you cannot measure is itself a transferable result.</strong> The exercise in <a href="/courses/exe/lessons/exe-frontend#unit-apply">the front-end concept</a> that asks the reader to run <code>perf stat -e branch-misses</code> first is not a warm-up. On a machine with a PMU the reader can complete an experiment this course could not, and they will know precisely which one it is. A course that said &ldquo;mispredicts cost a lot, see a textbook&rdquo; leaves them with nothing to do.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ ./cycbench 2&gt;&amp;1 | sed -n '/6. LONG-PERIOD/,/7. ALIGN/p'
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^G /,/^H /p'
$ perf stat -e branch-misses,branches ./cycbench 2&gt;&amp;1 | tail -4
</pre>
                </div>
                <p>Then go and close the gap this course could not, which is the whole exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Establish whether YOU can count. This gates
     everything else, so do it first and do not
     skip it:

       perf stat -e branch-misses,branches true
       cat /proc/sys/kernel/perf_event_paranoid
       ls /sys/bus/event_source/devices/ | grep -i cpu

     If branch-misses works, you have a ground
     truth this course lacked.

  2. With a counter, do the experiment this course
     could not. Take the table-walk loop and
     measure misses AND time at each depth:

       for (d in 2 4 16 64 256 4096 65536); do
         perf stat -e branch-misses,branches ./walk_$d
       done

     Now the two curves are separate and the
     question is answered rather than posed:
     is the miss count flat (the predictor learned
     it) or is the time flat while the count is
     high (the cost is hidden)?

     That is the experiment, and it is a dozen
     lines plus a PMU. This course's research log
     names it as the thing that would have changed
     the course.

  3. Then test the second explanation directly, by
     REMOVING the slack. Hypothesis 2 says the
     cost is hidden because the loop has
     independent work available. So build a loop
     with NO independent work -- a dependent
     chain ending in a data-dependent branch:

       for (i = 0; i < n; i++) {
         x = x * 3 + (tbl[i & mask] & 1);
         if (x & 0x10000) y++;
       }

     (Careful: the compiler may CMOV the if.
     Check with the ISA course's decoder that a
     conditional JMP is actually in the binary --
     that check has caught a wrong measurement in
     three different courses now.)

     If the mispredict penalty appears here and
     not in the slack version, both explanations
     were partly right and the cost is real but
     workload-dependent.

  4. Now measure the penalty itself, which requires
     both a counter and a workload with no slack.
     Vary the number of mispredicts and the amount
     of independent work independently, and you
     can separate the throughput cost from the
     stall:

       mispredicts: 0, 1 per 4 iters, 1 per iter
       slack:       none, 1 independent op, 4

     Expect the two costs to show up in different
     cells, which is the concrete form of the
     distinction this concept drew in its model
     section and could not measure.

  5. Finally, and this is the exercise worth the
     most: take the claim in the textbooks that a
     mispredict costs "about 15 cycles", find out
     what it is measured on, and reproduce it or
     refute it.

       grep -rn 'mispredict' /usr/share/doc 2>/dev/null
       # then measure it yourself, on your machine,
       # with a counter, in a loop with no slack

     (Expect it to be in the right order of
     magnitude and to depend on the workload, and
     expect the dependence to be the interesting
     part. A number without its conditions is a
     number you cannot use, which is the point
     this concept has been making for six concepts.)
</pre>
                </div>
                <p>Exercise 2 is the experiment this course names as the one that would have changed it, and it is worth doing precisely because the course did not. <strong>Two curves instead of one</strong> &mdash; miss count and time &mdash; and the answer is in whether they are flat together or separately. A reader who produces those two curves has done something the course could not, and the course says so rather than writing a number it does not have.</p>
                <p>Exercise 5 is the one that generalises furthest. <strong>&ldquo;About 15 cycles&rdquo; is a number with no conditions attached, and a number with no conditions is a number you cannot use.</strong> Going back to find what it was measured on &mdash; which core, which workload, whether the counter was available, whether the loop had slack &mdash; and then reproducing it or refuting it is the difference between citing a number and knowing one. It is also, not coincidentally, the entire method of this collection applied to the one claim it could not measure for itself.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/isa/lessons/isa-opcodes">the opcode-map concept</a> is the one that was set up two courses ago and is now closed. That concept measured <code>0F 0B</code> as UD2 &mdash; a deliberately undefined instruction &mdash; and said the reason is that an invalid indirect call should stop at the first instruction it reaches rather than wander through memory. <strong>That is speculation&rsquo;s failure mode stated as an encoding, and this concept supplies the mechanism it protects against:</strong> a mispredicted indirect call fetches down a path that is not code, and the first thing it hits is often padding, a jump table, or the middle of an instruction. UD2 is the architect&rsquo;s statement that this is not a state the machine should be in, and it is why a compiler emits one after every noreturn call.</p>
                <p>The connection to <a href="/courses/sec/lessons/sec-cet">the CET concept in the hardening course</a> is the deepest one in this course, and it is a direct continuation rather than a parallel. That course measured that <code>endbr64</code> appears in binaries built with CET <em>disabled</em>, that all five of them come from the distro&rsquo;s pre-hardened <code>crt1.o</code> and <code>crti.o</code>, and that enforcement comes from a property note the kernel reads rather than from the instructions. <strong>That is speculation&rsquo;s cost being mitigated, and the mitigation is an <em>architectural</em> one</strong>: IBT makes the CPU check that the target of an indirect branch begins with a landing pad, so a mispredicted indirect branch faults instead of executing. CET is not a performance feature that happens to be safe; it is the industry&rsquo;s answer to the fact that this cost is a security problem, and this course is where the cost was measured and found to be unmeasurable on the available hardware.</p>
                <p>Two connections outward, both about the shape of the limit. <a href="/courses/exe/lessons/exe-verify">The final concept</a> is about what the harness does when a claim cannot be measured, and this is its worked example. And <a href="/courses/img/lessons/img-entries">The image-loading course</a> measured that the auxv is read once at startup and never again; <strong>speculation is the other thing a program does once and then never again</strong>, and the branch predictor is a cache in exactly that sense &mdash; it warms up over the first few thousand branches and then it is simply part of the machine. Which means its cost is a <em>startup</em> cost amortised over a whole program, and that is the framing in which a 15-cycle number is either important or irrelevant.</p>
                <p>One limit, and it is the largest in the course. <strong>This concept has no positive finding.</strong> It reports a null result, explains the two reasons a null result can arise, and names the hardware that would distinguish them. That is a legitimate outcome and it is better than a borrowed number &mdash; but a reader should be clear about what they are getting: a set of questions this machine could not answer, arranged so that someone with a PMU can answer them in an afternoon. The next and final concept is about the discipline that made that outcome reportable rather than embarrassing.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-frontend">Previous: The Front End and the Branch Predictor</a></span>
                <span>Next: <a href="/courses/exe/lessons/exe-verify">The Instrument and the Oracle Loop</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
