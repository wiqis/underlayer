// Multiprocessor Architecture — Concept 7: the harness
public namespace underlayer_content {

using std::string

using std::string_view

public func render_smp_harness() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Harness, and the Six That Refused to Go Quietly — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson">
            <div class="a11y-controls">
                <button class="a11y-btn" onclick="toggleHighContrast()" aria-label="Toggle high contrast">HC</button>
                <button class="a11y-btn" onclick="toggleReducedMotion()" aria-label="Toggle reduced motion">RM</button>
                <button class="a11y-btn" onclick="openShortcuts()" aria-label="Keyboard shortcuts">?</button>
            </div>
            <div class="shortcuts-modal" id="shortcuts-modal">
                <div class="shortcuts-backdrop" onclick="closeShortcuts()"></div>
                <div class="shortcuts-dialog">
                    <h3>Keyboard Shortcuts</h3>
                    <dl>
                        <dt><kbd>Ctrl</kbd>+<kbd>K</kbd></dt><dd>Open search</dd>
                        <dt><kbd>Esc</kbd></dt><dd>Close search / dialog</dd>
                        <dt><kbd>&uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="shortcuts-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>The Harness, and the Six That Refused to Go Quietly</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/smp">Multiprocessor Architecture</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The manifest&rsquo;s completion criterion for this course is not &ldquo;read it&rdquo;. It is: <em>reproduce the 73 checks, then remove the 64-byte stride from the private-line rows and make the placement group fail by name.</em> That sentence is the whole argument for this concept, so it is worth reading it as a piece of engineering rather than as course admin.</p>
                <p>The harness is <code>crosscheck.py</code>, 73 checks in eight groups, and it does not re-measure anything. It reads the recorded output of the artifact and asks whether the claims are still there. <strong>The interesting thing is not that the checks exist but what they are willing to assert</strong>, and that is decided by a single number the artifact prints before it makes any claim at all:</p>
                <div class="hex-dump">
                <pre>$ ./smpbench | sed -n '/estimator =/,/upper bound/p'
   estimator = min-of-3, 11 of them: spread  82.5%

   The body is a volatile increment, so this floor INCLUDES the core
   clock: an arithmetic loop is bounded by the frequency and the TSC
   is fixed-rate.  Every ratio in section 2 has the same clock on both
   sides, so the clock cancels -- but the floor here is an upper bound
                </pre>
                </div>
                <p>82.5%, on the recorded run. Across the three recorded runs the same estimator measured <strong>19.2%, 55.3% and 82.5%</strong> &mdash; the machine&rsquo;s own noise floor is a factor of four apart between one run and the next, on the same body, on the same machine.</p>
                <p>So: <strong>a harness for a measurement with an 18% spread can assert values with a tolerance. A harness for a measurement with an 82% spread cannot assert anything numeric</strong>, and one that tries will fail on a busy machine and teach its reader to ignore it &mdash; which is exactly how the previous three courses&rsquo; harnesses broke, in the previous three courses. The arithmetic of a threshold wide enough to catch a real change is also wide enough to swallow the change, and a check with a bare number in it is a check whose failure is noise.</p>
                <p>There is a second reason this course needs a stricter harness than the memory course did, and the privilege course predicted it. <strong>This is a measurement about many cores.</strong> A course about one core has a quiet machine to itself; a course about six has eleven other logical CPUs to compete with, and the guest it is running on is doing its best to be busy. More cores is a worse floor, not a better one, and the whole shape of what can honestly be asserted follows from that one fact.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: five rules, each one learned by breaking it</h2>
                <div class="formula">
  1. EXACT FOR STRUCTURE, ORDERINGS FOR TIMING.
     Asserted exactly: the online CPU list, the
     sibling pairs, the mutual sibling relation,
     cores x threads-per-core == the CPU count, the
     agreement between the cache's sharing list and
     the topology's sibling list, the L1 set being a
     strict subset of the L3 set, the ORDER of the
     seven placement rows, and the presence of all six
     retractions.
     Asserted as orderings: which row is dearer than
     which.  Never as values.

  2. THE RESULT IS A SHAPE, NOT A NUMBER.
     The claim the course exists to make -- true
     sharing and false sharing cost the SAME -- is
     checked as a PAIR of conditions:

        0.6 &lt;= B/C &lt;= 1.7          near 1
        B/A &gt; 3.0  and  C/A &gt; 3.0    both far
                                         above the
                                         floor

     Either alone is nearly contentless.  Together
     they say "these two are alike and neither is
     cheap", which is the finding, and it survives
     a machine four times quieter than this one.

  3. AN ABSENCE IS AN ABSENCE.
     No PMU (perf_event_paranoid == 4).  No second
     NUMA node.  No count of coherence traffic.
     Each is checked as a STATEMENT plus its
     REASON -- because the alternative is a
     decoder that prints a plausible number in the
     space where the number is unknown.

  4. RETRACTIONS ARE TEXT.
     Six of them, and the harness asserts each is
     still a string in the artifact's output.  Not
     "the claim is false" -- "the claim is still
     written down".  A retraction nobody can see is
     a retraction that gets re-derived eventually,
     usually by the same person.

  5. A CHECK THAT FAILS FOR AN INVISIBLE REASON
     IS WORSE THAN NO CHECK.
     If a reader cannot see why it went red, they
     will learn to ignore it, and an ignored check
     is worse than an absent one because it is
     counted.  The corollary is the G/A check below:
     a check that can never fire is not a check
     either, and both failures look identical from
     the outside -- a green tick.
                </div>
                <p>Rules 1 and 2 are the ones a reader is most likely to think are pedantic, so here is what they cost and what they buy. <strong>Without rule 1 the harness would assert that B/A is 13.05&times;, and it would fail on a machine where the same experiment gives 11.82&times; &mdash; a machine where the course is just as correct.</strong> A check like that does not protect the claim; it protects the author&rsquo;s day. With rule 2, the check passes on all three recorded runs, whose B/C values were 1.19, 1.03 and 0.97, and it would still pass on a machine whose B/C is 0.6 or 1.7.</p>
                <p>And rule 2 has a second job that is easy to miss: <strong>the shape catches edits that the value could never catch.</strong> A value check notices that the number changed. The shape check notices that the rows stopped being a cluster &mdash; which is what happens the moment somebody changes the stride in the private-line declaration, and which is precisely the completion criterion for this course.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: eight groups, and what each one is for</h2>
                <div class="hex-dump">
                <pre>$ cd courses/smp/assets/samples &amp;&amp; python3 crosscheck.py
crosscheck: .../smpbench.out

  --- group A: what was measured before anything was measured
  --- group B: the topology, read twice from two kernel files
  --- group C: seven rows, and the one comparison the course is for
  --- group D: the cost the hardware imposes on one thread
  --- group E: a duration, and the correctness it is not
  --- group F: the distinction, measured by its absence
  --- group G: every retraction is still present
  --- group H: the limits, and the verdict

  crosscheck: 73 checks, 0 failed
                </pre>
                </div>
                <p>Eight groups, and five of them are checks about the <em>checking</em> rather than about the machine. Those are the ones worth naming.</p>
                <p><strong>Group A checks that the noise floor was measured and PRINTED before anything was claimed</strong> &mdash; not that it is small, that it exists. If a future edit removed the floor measurement, every ratio check that depends on it would silently compare against a default and the harness would still go green. So the floor is itself a checked fact, and so is the statement of the consequence: <em>durations are not counts</em>, with the word <code>LOWER BOUND</code> in it.</p>
                <p><strong>Group B checks the two-reader cross-check, and it checks the verdict.</strong> Not merely that both strings appear, but that the artifact printed <code>AGREE</code> or <code>DISAGREE</code> and said which. A harness that only checked for the presence of the comparison would pass on an artifact that compared and silently swallowed the result &mdash; which is a comparison for show. It also checks the sibling table three separate ways, because a sibling table can be wrong in a way that is locally plausible: no CPU is its own sibling, no lookup returned <code>-1</code>, and every relation is mutual.</p>
                <p><strong>Group C is the course in four checks</strong>, and the pair of conditions from rule 2 is two of them:</p>
                <div class="formula">
   A, D and E all within a factor of 4 of each other
       -- the no-sharing rows are a cluster
   B/A &gt; 3 and C/A &gt; 3
       -- both genuinely-shared rows are far above it
   0.6 &lt;= B/C &lt;= 1.7
       -- THE RESULT: true and false sharing cost
          the SAME
   D &lt; C/3 and D &lt; B/3
       -- and the table is not flat
                </div>
                <p>The fourth of those is the one people forget, and it is load-bearing. <strong>Without it, a harness that passed on every row being identical to the floor would satisfy every &ldquo;B and C are far above A&rdquo; condition in the world</strong>, by making A enormous. A shape needs a contrast to be a shape, and D &mdash; a row that shares nothing and shares an L1 &mdash; is the contrast.</p>
                <p><strong>Group E checks that the section did not claim what it could not measure.</strong> The assertions are all negative: that the output contains <em>That a fence is CORRECT</em>, that it contains <em>is also what you would see if the fence were a no-op</em>, that it contains <em>neither can any timing measurement</em>, and that the fence count is called <em>an upper bound</em>. <strong>There is no check in group E that the fence is correct, because there cannot be</strong> &mdash; and the check that it says so is the strongest statement the group makes.</p>
                <p><strong>Group H checks the limits and names the instrument that would settle the missing ones.</strong> Seven limits are asserted as strings, and then one more check asserts that the artifact names the PMU as the thing that would have fixed half of them. A limits section that says &ldquo;we cannot count coherence traffic&rdquo; without saying why is a disclaimer; the same section saying &ldquo;perf_event_paranoid is 4, so no user-space event counter exists&rdquo; is a checked fact.</p>
                <p>And one honest observation about this harness, because the failure mode it is guarding against is present inside it. The comment above the SMT check says <em>Measured, D/A came out at 0.97</em>. In the three recorded runs D/A is 1.07, 1.08 and 1.01, and 0.97 is one of the recorded <em>B/C</em> ratios. <strong>A transposed number in a comment is the same disease the checks exist to catch, and it is in the harness</strong> &mdash; which is the reason to print this rather than quietly fixing it: the checks police the artifact&rsquo;s output and nothing polices the harness&rsquo;s prose, so the prose has to be policed by a reader.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the four failures this harness had of its own</h2>
                <p>They are worth recording because they are the same disease the previous three courses documented, and because every one of them was found by <em>running</em> the harness rather than reading it.</p>
                <div class="formula">
  a. A CHECK THAT ASSERTED A DIFFERENCE THE DATA
     DOES NOT SHOW.
     The first version of the SMT check said D and A
     must DIFFER, because the artifact's prose said
     SMT costs a modest penalty.  The measurement said
     they were the same.  The prose was wrong and the
     check was faithfully defending the prose.

     This is the worst kind of harness bug: the
     check was working exactly as designed, and
     what it was designed to defend turned out to
     be false.  A check written from a claim rather
     than from a measurement is a check that
     launders the claim.

  b. A CHECK THAT WOULD FAIL FOR AN INVISIBLE
     REASON.
     Asserting G &lt; A -- that the plain store is
     cheaper than the locked one -- looks obviously
     right and is exactly the wrong assertion to
     freeze.  A and G are the same body with and
     without a `lock`, in a table of SEVEN
     interleaved arms on a busy guest with a floor
     this artifact itself measured at 82.5%.  The
     check fails whenever the noise is unlucky, and a
     reader cannot see the reason from the failure.

     Replaced by closeness.  Rule 5.

  c. AN EXTRACTOR THAT RETURNED ONLY THE FIRST
     CAPTURE GROUP.
     A helper written for numbers was used on a row
     that has a LABEL and a VALUE, so the label was
     handed to float() and raised.  Same class of
     error as the hex extractor in the previous
     course: one helper, two incompatible jobs, and
     the failure surfaces as a crash rather than as a
     wrong answer, which is the good case.

  d. A SUBSTRING COMPARISON THAT UPPERCASED ONE
     SIDE ONLY.
     Checking for "IDENTICAL INSTRUCTION" against
     an UPPERCASED copy of the text, while checking
     for "Only the memory address changes" against the
     copy as written.  The check then quietly cannot
     match a phrase whose case differs from the
     probe, and it will do so in a way that looks like
     a missing sentence rather than a broken test.

     The fix is one normalised copy for every
     substring assertion -- which also fixed the
     previous course's line-break trap, where the
     artifact's 78-column wrapping hid four
     sentences from the harness, three of them
     retractions.  Numeric parses still run on the
     original, because collapsing whitespace there
     would join adjacent table columns.
                </div>
                <p>Two helpers were also rewritten for the same underlying reason, without having been failures: the CPU-list expander now treats <code>&quot;0-11&quot;</code> as a <em>range</em> rather than splitting on commas, because splitting on commas called a twelve-CPU L3 the same size as a two-CPU L1; and the placement-row parser now returns both the label and the number.</p>
                <p><strong>None of the six would have been found by reading the harness.</strong> Five of them are checks that are perfectly well-formed and that fail, or cannot fail, for reasons a reader cannot see from the failure. Only the crash is loud. <strong>That is the argument for the exercise below, and the argument for not trusting a green build.</strong></p>
                <h3>The six retractions, which are what group G exists for</h3>
                <div class="formula">
  R1  "The plain-store arm measured 1.75 ticks per
       operation."  It MEASURED NOTHING.  Written in C
       as a relaxed atomic store to a variable nothing
       ever read, the compiler proved the whole loop
       dead and removed it, and the result was a
       plausible-looking number for four million
       operations that did not happen.

       THE GENERAL FORM, WHICH RECURS EVERY COURSE:
       WHEN TWO THINGS MEASURE AS SIMILAR, THE FIRST
       HYPOTHESIS IS THAT YOUR OPTIMISER DELETED THE
       DIFFERENCE.

  R2  "Two threads on unspecified CPUs is a
       measurement."  NO.  The check is the MECHANISM,
       not a filter: every worker calls
       sched_getcpu(), and the repetition is discarded
       if either thread is anywhere but where it was
       pinned.  Discarded rows are COUNTED and printed.

  R3  "False sharing is a 61.9x effect."  The number
       is the memory course's and it is correct THERE.
       Not restated as a property of this machine's
       protocol, because the ratio depends on the body,
       the width and the clock -- and re-publishing it
       would be the remembered-number mistake this
       harness exists to prevent.

  R4  "An uncontended lock is expensive because of
       coherence."  RETRACTED TO THE WRONG REASON.

  R5  "`lock` is one idea that could have been three."
       A lock-free algorithm written on x86-64 is
       correct partly BY ACCIDENT.

  R6  "A placement check is a filter you apply
       afterwards."  NO.  Applied afterwards it cannot
       tell you WHY a thread was in the wrong place,
       and on a loaded machine it silently converts
       every row into a discarded row while the run
       still looks like it worked.
                </div>
                <p>Read R1 and R6 together and there is one idea: <strong>a check performed after the fact cannot distinguish &ldquo;the thing did not happen&rdquo; from &ldquo;the thing happened elsewhere&rdquo;.</strong> That is why the placement check happens inside the worker, why discarded rows are counted rather than dropped, and why the plain-store arm is written in assembly rather than in C. All three are the same rule discovered three times.</p>
                <p>And read R3 carefully, because it is the one that protects this course from its own headline number. The memory course measured 61.9&times; and it is right there. <strong>It is not restated here as a property of this machine&rsquo;s coherence protocol</strong>, because the ratio depends on the body, the width and the clock, and re-publishing another course&rsquo;s number as this course&rsquo;s result is precisely what a harness exists to prevent.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Do the manifest&rsquo;s exercise: remove the 64-byte stride and watch group C fail by name.</strong> In <code>smpbench.c</code>, change <code>g_line[MAXCPUS][16]</code> to <code>g_line[MAXCPUS][1]</code>, rebuild, run the artifact, rerun the harness. <em>(Expect group C to fail on the shape checks &mdash; the no-sharing rows stop being a cluster, and B/A and C/A stop both being far above the floor. Write down which checks failed <em>before</em> you predict which would, because the gap between the two is usually a check you did not know existed. Then put the stride back and confirm 73 again.)</em></li>
                    <li><strong>Add a check that cannot fire, and confirm that it cannot fire.</strong> Assert that the recorded <code>package</code> column is 0 for every CPU. <em>(Expect it to pass &mdash; every value is 0 on this machine, because there is one socket. You have just written a check that can only fail on a machine this course does not claim to describe. Now delete the string you are matching on and watch the whole group go red: the fact that it went red proves it reads the artifact, and the fact that it cannot go red on any other machine proves it is not a check. Both of those facts are worth having written down, and this is the only way to learn which of your checks are which.)</em></li>
                    <li><strong>Freeze one number and see what it does.</strong> Add <code>check(g, "B/A is 13.05x", abs(B/A - 13.05) &lt; 0.1)</code> to group C. <em>(Expect it to pass on the recorded output and to fail immediately on <code>run1.txt</code> and <code>run2.txt</code>, where B/A is 12.34 and 11.82. Both of those runs are the same machine and the same experiment, and both are recorded as part of this course. You have just written a check that fails on the course's own evidence, which is the clearest possible demonstration that a remembered number is not a fact.)</em></li>
                    <li><strong>Run it on a deliberately busy machine.</strong> Start eight spinning processes and rerun. <em>(Expect groups A, B, F, G and H to pass unchanged, because they assert structure and text; group C's shape checks should still pass because the shape is robust; and one or two of the tighter bands may fail because the machine got louder. That asymmetry is the design working. If instead a whole group fails together, the harness has a bare number in it somewhere and you have found it.)</em></li>
                    <li><strong>Port the rules, not the checks.</strong> Write down the five rules for your next project &mdash; a compiler, a runtime, a profiler &mdash; and mark which one you are most likely to break. <em>(Expect rule 2. Any project whose output includes timings will eventually be tempted to assert a timing, and the moment it does, the check becomes a statement about the day it was written. The defence is the same one here: decide whether the claim is a value, a shape, or an agreement, and only the last two survive contact with a different machine.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the ledger for the other six. <a href="/courses/smp/lessons/smp-topology">The topology concept</a> produced the exact structural claims that group B asserts &mdash; the online list, the mutual sibling relation, the two-reader cross-check &mdash; and the debt to the memory course that group B also checks is present. <a href="/courses/smp/lessons/smp-sharing">The sharing concept</a> produced the B/C result, and it is the one claim in the course that is asserted as a shape rather than a value; it is also where the stride the completion criterion removes lives. <a href="/courses/smp/lessons/smp-atomic">The atomic concept</a> produced R4 and produced the CAS comparison whose first-draft story the group D checks keep in the record. <a href="/courses/smp/lessons/smp-ordering">The ordering concept</a> produced the four things section 4 cannot do, and group E asserts the artifact <em>said</em> them. <a href="/courses/smp/lessons/smp-numa">The NUMA concept</a> produced the node gap that no group checks &mdash; rule 3 says an absence must be an absence, and this one is named in the output rather than in the harness. <a href="/courses/smp/lessons/smp-three">The three-architectures concept</a> is entirely quoted, and group H&rsquo;s last check is that it says so.</p>
                <p>Outward, the two immediately preceding harnesses own the same rules one course along, and reading all three is how you learn them rather than memorise them. <a href="/courses/mem/lessons/mem-verify">The memory course&rsquo;s harness</a> has a retraction group, a noise-floor rule, and a paragraph on the claim it refuses to make &mdash; which is that a factor was measured and a mechanism inferred, and the harness asserts the factor and the <em>preconditions</em> while asserting nothing about coherence states. <a href="/courses/exe/lessons/exe-verify">The execution course&rsquo;s</a> has the same three and an oracle loop. <a href="/courses/priv/lessons/priv-harness">The privilege course&rsquo;s</a> has four of its own documented failures and the rule that an absent-sigreturn message must be asserted as text. <strong>Three harnesses, four identical failure modes, one shared cause: a check written to defend a claim rather than a measurement.</strong></p>
                <p>And the last word belongs to the thing this course will not measure. <code>perf_event_paranoid</code> is 4. <strong>There is no way, from user mode on this machine, to count an invalidation, a snoop, a line transfer or a fence.</strong> Every number in this course is a duration, and a duration bounds a count without measuring it. That is not a footnote and it is not a limitation of the author&rsquo;s effort: it is a property of the machine, it was proved rather than assumed, and it is asserted by group A so that a future reader cannot quietly forget it. A course that says what it cannot count, prints the instrument that would have let it count, and has a check for both is the standard every course in this collection holds itself to.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/smp/lessons/smp-three">Three Answers to Two Questions</a></span>
                <span>End of Multiprocessor Architecture &middot; <a href="/courses/smp">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
