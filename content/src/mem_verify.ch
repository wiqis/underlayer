// The Memory Hierarchy — Module 4: Sharing, and Verification
// Concept: the harness. 109 checks, none of which asserts a bare number, one
// group whose assertions depend on a measurement the machine may not provide,
// and the failure that took the harness itself down.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_mem_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Harness, and the Claim It Refuses to Make — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson mem-lesson">
            <a href="/courses/mem" class="back-link">Back to course</a>
            <h1>The Harness, and the Claim It Refuses to Make</h1>
            <div class="lesson-meta">26 min &middot; Module 4: Sharing and Verification &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>This course has spent seven concepts making claims, and every one of them came out of a program that could have been wrong in ways its own output would not reveal. The retractions scattered through the course are the evidence for that: a 5.28&times; attributed to address translation that was a set conflict; a &ldquo;TLB cliff at 32 pages&rdquo; that vanished when the offsets were fixed; a table that ran backwards because an offset was in the wrong units; a null result from a benchmark that had not finished running. <strong>None of those produced a crash, a warning, or an obviously wrong number. Each of them produced a plausible table.</strong></p>
                <p>So the last two things this course ships are not measurements. They are a program that checks the measurement while it runs, and a second program that reads the first one's output afterwards and checks the claims in it against the numbers printed in it and against the arithmetic the machine's own <code>/sys</code> implies:</p>
                <div class="formula">
  ./membench          21 checks, in-run
                      the preconditions of each measurement
                      (a cycle that closes, a layout that
                      touches the lines it names, a thread
                      on the core it thinks it is on)

  crosscheck.py 109 checks, 9 groups, after the run
                      the SHAPE of each claim, the AGREEMENT
                      between numbers the artifact printed, and
                      the PRESENCE of every retraction
                </div>
                <p>Neither of them is a unit test in the sense of &ldquo;does the code still do what it did yesterday&rdquo;. <strong>Both are arguments, written down in a form that a machine can re-check.</strong> And the reason they need to be arguments rather than expected values is the first concept's result: this course measured its own noise floor at 36% on one run, 25% on another and 11% on a third, which means <em>the noise floor is itself noisy</em> and no tolerance in this course can be a remembered number. A suite that asserted <code>L1 &lt; 2.0 ns</code> would pass on a quiet afternoon and fail on a busy one, and its reader would learn to ignore it &mdash; which is the failure mode the entire artifact is written against.</p>
                <p>And then there is the interesting case, the one this concept is named for. One group of the harness has assertions whose <em>subject</em> depends on a measurement the machine may decline to provide. The huge-page claim in the translation concept cannot be checked when the mapping does not collapse, and the harness has to decide what to do about that. <strong>There are only three options &mdash; fail, pass vacuously, or change the question &mdash; and this suite takes the third and prints which question it asked.</strong> That decision is the most transferable thing in the course.</p>
            </div>

            <div class="unit unit-model">
                <h2>The Rules the Harness Follows</h2>
                <p>Six rules, each of which exists because an earlier version broke it. They are the model; the checks are just instances.</p>
                <div class="formula">
  1. NO BARE NUMBERS.
     every threshold is a RATIO, and the ratio is either
     read back out of the artifact's own output or
     derived from a quantity the artifact printed.

  2. AGREEMENT, NOT MAGNITUDE.
     where a claim compares two of the artifact's own
     numbers -- an aliasing stride against the line size,
     a TLB reach against the set count -- the check is
     that the two AGREE. machine-independent, even
     though neither number is.

  3. SHAPES FOR SHAPES.
     where the claim is a shape, assert the shape, and
     take the tolerance from the artifact's own measured
     spread rather than from a hand-picked percentage.

  4. RETRACTIONS ARE ASSERTED TOO.
     every withdrawn claim must still be present in the
     output as text. a claim that was taken back cannot
     be quietly deleted from the artifact later.

  5. CHECK THE PRECONDITION AND PRINT THE EXCLUSION.
     rows measured with both threads on one physical core
     are marked by the artifact and excluded by both
     programs by the same rule.

  6. CHANGE THE QUESTION, NEVER THE TOLERANCE.
     when a machine makes a claim unmeasurable, assert
     the fact that it was unmeasurable -- and say so.
                </div>
                <p>The nine groups and their sizes, from the run this lesson quotes. The counts are printed by the suite itself and cross-checked against the artifact's own tally, so a truncated transcript cannot be mistaken for a passing run:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py run1.txt | grep '^  --- group'
  --- group A: what the artifact read out of the machine      13 checks
  --- group B: the instrument's own limits                    10 checks
  --- group C: the hierarchy curve                            24 checks
  --- group D: the associativity prediction                    8 checks
  --- group E: address translation                            12 checks
  --- group F: the write path                                  8 checks
  --- group G: false sharing                                   9 checks
  --- group H: every retraction is still present               11 checks
  --- group I: the verdict quotes the tables, not memory       14 checks
                                                              ---------
                                                              109 checks
</pre>
                </div>
                <p>Three of those groups are worth naming before the output, because their <em>kind</em> of assertion differs. <strong>Group H asserts presence, not truth:</strong> it looks for the text of each retraction, including the two bugs that produced a table running backwards and the register that was not a scratch register. It cannot check that a retraction is <em>correct</em>; what it can do is make sure that a claim someone took back does not reappear in the artifact as if it had never been withdrawn. <strong>Group I re-reads the verdict against the tables above it:</strong> every number the artifact claims in its summary must appear in a table, and the count of printed check lines must match the artifact's own tally &mdash; a check on a check. And <strong>group E is the conditional one</strong>, for the reason the rest of this concept is about.</p>
                <p>One limit applies to all nine groups and it should be stated plainly, because it is the difference between what a harness is and what it is not. <strong>These checks can confirm that a number has the shape a mechanism predicts. They cannot confirm the mechanism.</strong> When group G asserts that the two counters' lines matter by a large factor, it is asserting the factor and the precondition (two physical cores, verified against <code>core_id</code>); it is not asserting that a cache line ping-pongs between two cores, because nothing on this machine can observe a ping-pong. <strong>The suite is careful never to dress an inference as an observation</strong>, which is why it asserts &ldquo;the summary rests only on runs verified to be on two cores&rdquo; rather than &ldquo;the threads communicated&rdquo;.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Harness Reported</h2>
                <p>Group E in full, because it is the group whose assertions are conditional and therefore the one worth reading closely:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py run1.txt 2&gt;&amp;1 | sed -n '/^  --- group E:/,/^  --- group F:/p'
  --- group E: address translation
  [PASS] E tlb       the translation table was produced                   10 page counts
  [PASS] E tlb       every line count equals its page count in the spread arm one line per page, as designed
  [PASS] E tlb       the packed arm is a control, not a second experiment 1.30 to 1.77 ns across 10 page counts, a 1.4x absolute spread that is the core clock and not the memory -- which is exactly why every load-bearing check below is a ratio
  [PASS] E tlb       the spread arm is slower somewhere                   up to 2.80x the packed arm
  [PASS] E tlb       the transition is a cliff and not a ramp             fast up to 64 pages, slow from 72 pages
  [PASS] E tlb       the hugepage mapping was probed, not assumed         AnonHugePages = 0.0 KiB
  [PASS] E tlb       the artifact reports that the mapping did not collapse a bare 0 KiB in the log would be a silent failure
  [PASS] E tlb       and it refuses the huge-page claim rather than making it the claim is withdrawn, not averaged over
  [PASS] E tlb       and the madvised arm is not the fast one, as a collapsed one would be madvised 2.84x against the spread arm's 2.80x: the madvised column bought nothing, which is what no collapse means
  [PASS] E tlb       the stated TLB reach is a page count that was measured 64 pages is in the table
  [PASS] E tlb       the reach separates the two sides with no overlap    4 counts below 64 pages reach at most 1.23x; 5 counts above reach at least 2.63x -- no overlap
  [PASS] E tlb       the step at the reach is large                       the smallest ratio above 64 pages is 2.63x
</pre>
                </div>
                <p>Five readings, and then the largest check in the course.</p>
                <p><strong>The separation check is machine-independent, and it is the strongest form of the translation claim.</strong> &ldquo;The reach separates the two sides with no overlap&rdquo; says that every page count at or below 64 pages measured at most 1.23&times; the control, and every count above it measured at least 2.63&times;. <strong>That is a claim about two disjoint sets rather than about a threshold</strong>, so it holds on a machine whose fast arm is 0.8 ns or 4 ns, and it would fail immediately if the effect were a slope instead of a step. Thresholds are where machine-dependent assertions go to die; the separation form is what to copy.</p>
                <p><strong>Three checks are about the artifact's own self-report, not about the numbers.</strong> &ldquo;The hugepage mapping was probed, not assumed&rdquo;; &ldquo;the artifact reports that the mapping did not collapse&rdquo;; &ldquo;and it refuses the huge-page claim rather than making it&rdquo;. A bare <code>0 KiB</code> in a log is what a silent failure looks like from the outside, so the harness requires the artifact to <em>say the number and draw the conclusion from it</em>. <strong>This is the pattern to steal for any measurement whose precondition can silently not hold:</strong> require the report, require the refusal, and only then check the numbers.</p>
                <p><strong>The conditional branch is the whole of the design decision.</strong> On this machine the huge-page claim is unmeasurable, so four of group E's checks that would exist on a collapsed mapping &mdash; the half-of-the-penalty comparison and the rest &mdash; are replaced by four others that assert the withdrawal. <strong>The suite did not fail, and it did not pass by ignoring the question: it changed the question to one the data can answer.</strong> A harness that failed here would be failing on the host's transparent-hugepage policy rather than on the artifact; a harness that passed vacuously would print a green line about a claim nobody made. Both are worse than the thing it does now, which is to assert <em>this run cannot answer that</em>.</p>
                <p><strong>And the whole suite is re-runnable against any captured run, with the same verdict and different numbers.</strong> The three runs stored next to the instrument in <code>assets/samples/</code> are the artifact's output on three occasions, and all three pass every check:</p>
                <div class="hex-dump">
                    <pre>$ for f in run1.txt run2.txt run3.txt; do
&gt;   echo -n "$f: "; python3 crosscheck.py $f | tail -2 | head -1
&gt; done
run1.txt:   crosscheck: 109 checks, 0 failed
run2.txt:   crosscheck: 109 checks, 0 failed
run3.txt:   crosscheck: 109 checks, 0 failed
</pre>
                </div>
                <p>That is what rules 1 to 3 buy, and it is the concrete answer to &ldquo;what does a machine-independent assertion look like&rdquo;. The three runs disagree with each other in almost every absolute value they contain: the TLB penalty is 2.80&times;, 2.66&times; and 2.65&times;; the write ratio above the cache is 2.47&times;, 2.43&times; and 2.49&times;; the false-sharing factor is 71&times;, 90&times; and 92&times;. <strong>A suite that had asserted any of those numbers would have failed on two runs out of three, and the response to that is always the same and always wrong: loosen the tolerance until it passes.</strong> Because the checks were written as shapes, disjoint sets and agreements, all three runs pass, and the fact that a number moved is not treated as a problem.</p>
                <p>One more reading, about the last two lines the suite prints, because they are the artifact's own accounting being checked by something that did not produce it:</p>
                <div class="hex-dump">
                    <pre>  [PASS] I verdict   the printed check lines match the tally
                    21 [PASS] + 0 [FAIL] = 21 lines, tally says 21.0
  [PASS] I verdict   the artifact exited clean                            no failures
</pre>
                </div>
                <p><strong>A check that counts the artifact's own check lines.</strong> If a run is killed halfway through, if a signal truncates the output, or if someone deletes an inconvenient paragraph before publishing the log, the tally and the lines disagree and the suite says so. It cannot tell a doctored log from an honest one, but it does make the artifact's self-report have to agree with itself.</p>
            </div>

            <div class="unit unit-example">
                <h2>The Harness That Took Itself Down</h2>
                <p>Every rule in the model above is a scar, and the worst scar belongs to the harness rather than the artifact. It is worth reading in full because the failure mode is general and the fix is unusual.</p>
                <p>The harness parses numbers out of the artifact's prose with regular expressions, and one of them was written as <code>[\d.]+</code> for a value that ends a sentence:</p>
                <div class="hex-dump">
                    <pre>  the artifact prints:

    ... a factor of 64.0.  The WORST of the verified runs is 65.1x

  the pattern [\d.]+ is GREEDY and '.' is a member of the
  class, so it matched

    64.0.        &lt;- including the full stop that ends
                    the sentence

  and float("64.0.") raises ValueError, which was not
  caught.  the harness died with a traceback BEFORE
  groups H and I had run at all.
</pre>
                </div>
                <p>The consequences were worse than the bug. The suite exited non-zero, so the build script reported a failure; the failure's detail was a Python traceback rather than a failing check; and eleven retraction checks plus fourteen verdict checks never executed. <strong>A harness that can crash is a harness whose own bugs are indistinguishable from the claims it is testing</strong>, and the distinction between &ldquo;the artifact is wrong&rdquo; and &ldquo;my parser is wrong&rdquo; is the only thing a harness is for.</p>
                <p>The second half of the same failure was a search that was not anchored. The phrase &ldquo;a factor of&rdquo; appears <em>three times</em> in the artifact's output &mdash; twice in the sharing section and once in the hierarchy section, where it describes the L3 band. An unanchored search matched the wrong one and compared the sharing factor against 5.4&times;. The fix was to anchor the pattern on the sentence that <em>follows</em> the sharing table, and the comment that records it is worth quoting because it explains why anchoring is not pedantry:</p>
                <div class="hex-dump">
                    <pre>    # Anchored on the sentence that FOLLOWS the sharing table,
    # because "a factor of" appears three times in this output and
    # an unanchored search matched the sentence about the L3 band
    # (5.4x) instead.
</pre>
                </div>
                <p><strong>A parser over a human-readable log is a program with all the usual ways to be wrong, and it is checking the only output the measurement has.</strong> The collection's answer to that, applied here and in the previous course, is to make the artifact print the numbers in a machine-findable form <em>as well as</em> the prose &mdash; but the mem artifact prints a table with fixed columns and the harness parses it, so the parsing risk is real and the rules it follows are: anchor every pattern, never let a match span a sentence, and never let an uncaught exception take the rest of the suite with it.</p>
                <p>There is one more lesson here, and it is about the shape of the whole endeavour rather than about a regex. <strong>The harness was written to catch a future edit that quietly changes a claim, and its first real catch was itself.</strong> That is not a failure of the design; it is the design working on the wrong subject. A suite of checks is a program, it lives in the repository, it is edited by the same hands that edit the artifact, and it is therefore as likely to be wrong as the artifact is &mdash; which is why this course's <code>research.md</code> records the harness bugs alongside the measurement bugs, and why three of the fixes in that file are in <code>crosscheck.py</code> rather than in <code>membench.c</code>.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/mem/assets/samples
$ ./build_samples.sh                 # build, run, and cross-check: ~40 s
$ python3 crosscheck.py run1.txt     # 109 checks against a captured run
</pre>
                </div>
                <p>Then four exercises, and the first two are the ones that make the point:</p>
                <div class="hex-dump">
                    <pre>  1. Break a retraction and watch the suite name it.
     Delete one sentence from a COPY of the log:

       sed '/Sequential reads sustain 64 GB\/s/d' \
           run1.txt &gt; /tmp/doctored.txt
       python3 crosscheck.py /tmp/doctored.txt
       echo "exit=$?"

     (Expect exit 1, and a failure that names the
     retraction -- "retraction present: 64 GB/s
     streaming" -- rather than a diff. This is what
     group H is for: the claim was taken back, and
     the suite refuses to let the withdrawal vanish.)

  2. Break the LAYOUT, not the log, and watch which
     checks fail. In layout_of, replace the per-index
     offset with 0 for the spread arm only, so the two
     arms differ in pages AND in sets.

     (Expect the artifact's own group D to fail --
     and expect the harness to fail too, on the check
     about the cliff, because a set conflict at a
     4096-byte gap produces a step that has nothing to
     do with pages. Two independent readers, one
     mistake: that is the design.)

  3. Write a check of your own, following the rules.
     Pick a claim this course makes that you believe
     -- "the non-temporal column never gets cheaper as
     the footprint shrinks", say -- and assert it as a
     shape with the artifact's own spread as the
     tolerance. Then run it against all three captures.

     (Expect it to pass three times. If it passes only
     on run1, the tolerance is a remembered number and
     the check is a liability.)

  4. Run the whole suite against each capture and
     compare WHAT MOVED:

       for f in run1.txt run2.txt run3.txt; do
         python3 crosscheck.py $f | grep -c PASS
       done

     (Expect 109 every time, and expect the artifact's
     absolute numbers to disagree between runs by
     20-30%. That gap -- same verdict, different
     numbers -- is the entire justification for
     asserting shapes instead of values.)

  5. Finally, find the conditional. Read group E's
     code and list which of its twelve checks exist
     only because AnonHugePages is 0 on your machine.
     Then check /sys/kernel/mm/transparent_hugepage/
     enabled on your own host and work out which
     branch YOUR run would take.

     (Expect [madvise] or [always] here; a host with
     [never] takes the same branch this machine did,
     and a host that collapses the mapping runs four
     checks that have never executed on this one.)
</pre>
                </div>
                <p>Exercise 1 is the quickest route to understanding what a harness is for. There is no assertion about the measurement in it at all: the check is that a sentence is still in the file. <strong>And it is the check that would have caught the single most likely future edit to this course, which is someone deleting a retraction because it makes the artifact look worse.</strong></p>
                <p>Exercise 3 is the one that generalises, and it is worth doing on a claim outside this course. Take any number you have measured, write down whether it is a <em>value</em> or a <em>shape</em> or a <em>relative</em>, and then ask which of the three you could re-derive on a machine you have never used. Everything else is a remembered number, and a remembered number in a check is a check that will fail for the wrong reason. <strong>The manifest for this course states its completion criterion as reproducing the 109 checks and then breaking the layout on purpose to make the one check that catches it fail by name</strong> &mdash; because a reader who has seen a check fail for a reason they caused is a reader who will believe it when it fails for a reason they did not.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the ledger for the six before it. <a href="/courses/mem/lessons/mem-instrument">The instrument concept</a> measured the noise floor that makes rule 1 necessary; <a href="/courses/mem/lessons/mem-associativity">the associativity concept</a> and <a href="/courses/mem/lessons/mem-translation">the translation concept</a> produced the two biggest retractions, both of which group H now refuses to let disappear; <a href="/courses/mem/lessons/mem-sharing">the sharing concept</a> is where the precondition rule came from, because a row measured on one physical core is a different experiment; and <a href="/courses/mem/lessons/mem-writes">the write concept</a> is where a check failed on a threshold that belonged to the loop &mdash; which is now rule 6, in the form of a stated exclusion instead of a loosened bound.</p>
                <p>Forward, the next course in this chain is <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a>, and it has since been written &mdash; which makes the last sentence of this concept a prediction that came true. Everything in the memory course is reachable from user mode with a clock and <code>/sys</code>; <strong>a course about mode changes starts where the permissions to read those files stop</strong>, and its limits block says so in the same form. It also inherited the method rather than a number, and spent its first concept measuring the noise floor of its own estimator exactly as this one did &mdash; on a busier machine, with a worse floor, and a larger fraction of its claims therefore expressed as orderings instead of values. That is the inheritance: <em>the discipline got stricter as the measurements got worse</em>, which is the correct direction.</p>
                <p>Outward, the closest relative is <a href="/courses/exe/lessons/exe-verify">the execution course's own harness concept</a>, and the relationship is one of inheritance rather than similarity: the rules in this concept's model are that course's rules, one course further along. Where that one asserted the alignment of a function and the presence of its five retractions, this one asserts disjoint sets and the withdrawal of a hint &mdash; the same discipline applied to a machine whose answers move by 30% between runs. <strong>And the two together are the answer to a question a course like this is always asked: how do you know?</strong> Not with a remembered number, and not with one program's opinion of itself &mdash; with two programs, one of which did not produce the output it is checking, written so that a machine you have never used can disagree with both.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/mem/lessons/mem-sharing">Previous: Two Threads, One Line</a></span>
                <span>End of The Memory Hierarchy &middot; <a href="/courses/mem">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
