// How a CPU Executes Instructions — Module 3: Speculation and Its Limits
// Concept: what the harness asserts, why it asserts shapes rather than values,
// and how to break a checker on purpose.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_exe_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Instrument and the Oracle Loop — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson exe-lesson">
            <a href="/courses/exe" class="back-link">Back to course</a>
            <h1>The Instrument and the Oracle Loop</h1>
            <div class="lesson-meta">27 min &middot; Module 3: Speculation and Its Limits &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Five concepts have produced a set of numbers with a 15% noise floor, a clock that moves, no hardware counters, and a compiler that quietly deletes benchmarks. <strong>Under those conditions, the question is not &ldquo;what did we measure&rdquo; but &ldquo;what may we still claim&rdquo;.</strong> That question has a concrete answer, and it is the harness.</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py 2&gt;&amp;1 | tail -16
  A     1 passed   0 failed
  B     5 passed   0 failed
  C     3 passed   0 failed
  D     7 passed   0 failed
  E     5 passed   0 failed
  F     5 passed   0 failed
  G     4 passed   0 failed
  H     3 passed   0 failed
  I     4 passed   0 failed
  ------------------------------------------------------------------------------
  37/37 checks passed
  ALL CLAIMS HOLD
</pre>
                </div>
                <p>Thirty-seven checks, and the interesting thing about them is what they are <em>not</em>. <strong>Not one of them asserts a number.</strong> There is no check that says &ldquo;the ratio is 2.7&times;&rdquo;, because on a machine with a 15% noise floor and a boost clock, such a check would fail on a good day and pass on a bad one, and a checker that does that is worse than no checker.</p>
                <p>What they assert instead is <em>shape</em>: that a dependent chain grows monotonically with its length, that the marginal cost of a dependency exceeds the marginal cost of an independent operation, that every bench body is 64-byte aligned. <strong>Shapes survive noise. Values do not.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What a claim needs before a harness may assert it, and what happens when it does not have it:</p>
                <div class="formula">
  A CLAIM IS ASSERTABLE if some PROPERTY of it
  survives the noise.

    "the ratio is 2.7x"        -- a VALUE.
        does not survive 15%. cannot be asserted.

    "a dependent chain costs more
     than an independent operation"   -- an ORDERING.
        survives anything. assertable.

    "the dependent series is
     monotonically increasing"  -- a SHAPE.
        survives anything. assertable.

    "every bench body is 64-byte
     aligned"                  -- read out of the ELF.
        not a measurement at all. assertable
        EXACTLY, with no noise term.

  so the harness is built from the third kind
  down to the first, and where a value is
  unavoidable the claim is narrowed until it is
  not.
                </div>
                <p>That last row is the important one and it is worth dwelling on. <strong>The alignment check is the only exact check in the file, and it is exact because it does not read a clock</strong> &mdash; it reads the ELF symbol table and asks whether every bench function&rsquo;s address is a multiple of 64. A measurement with no noise term can be asserted to the digit.</p>
                <p>And the value-claims were narrowed rather than dropped. The headline ratio is printed as a range with its provenance:</p>
                <div class="formula">
  cycbench prints:   "a dependent chain costs 3.87x
                     an independent operation"

  crosscheck asserts:
     the marginal of a dependency is GREATER
       than the marginal of an independent op
     and is at least 1.5x it
     and the published ratio is between 1.5x
       and 20x

  so if a future machine, a future compiler, or
  a noisy neighbour moves the ratio from 3.87 to
  2.1, the harness still passes -- correctly,
  because the CLAIM is about the shape. and if
  it moves to 1.2, the harness fails, because
  the claim is no longer true.

  that is the difference between a checker and
  a snapshot.
                </div>
                <p>And there is a third category, which is the one this course has most of. <strong>Some claims are about the text, not the machine</strong>, and those are asserted by searching the artifact&rsquo;s own output:</p>
                <div class="formula">
  the RETRACTIONS are asserted as text.

    ck('I', 'the 73% noise-floor figure is
            retracted in the output',
       'A RETRACTION' in out and '73%' in out)

    ck('I', 'the two flags explanations are both
            retracted in the output',
       out.count('A RETRACTION') >= 2)

    ck('H', 'and it says WHY the two explanations
            cannot be told apart',
       'cannot be' in out and 'COUNTED' in out.upper())

  a retraction that is not asserted is a
  retraction that quietly comes back the next
  time someone edits the artifact. these three
  checks exist so that cannot happen.
                </div>
                <p>That is the mechanism the whole collection uses, and it is worth stating plainly because it is unusual: <strong>the harness asserts that the course is still honest about what it does not know.</strong> A retraction that is not machine-checked is a promise. A retraction that is machine-checked is a constraint.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What the Checks Are, Group by Group</h2>
                <p>Thirty-seven checks in nine groups, and the grouping is the design:</p>
                <div class="hex-dump">
                    <pre>$ python3 crosscheck.py -v 2&gt;&amp;1 | sed -n '1,40p'
  ok  cycbench runs to completion and prints all seven sections
  ok  the TSC rate was measured and is plausible                2.2959 GHz
  ok  the TSC is invariant, so it is usable as a time base
  ok  the program refuses to call a tick a cycle
  ok  the noise floor is measured and reported                 15.1%
  ok  the noise floor is small enough that ratios are meaningful
  ok  every bench body has a symbol we can check              18 symbols
  ok  EVERY bench body is 64-byte aligned
  ok  the aligned bodies include all seven alignment offsets
  ok  every latency/throughput row was parsed
  ok  the dependent chain GROWS with its length (monotonic)
  ok  the independent set GROWS once it leaves the floor
  ok  1 and 2 independent ops are BOTH at the floor (within 15%)
  ok  a 1-operation body is at or near the floor
  ok  a dependent chain of 8 is at least 4x the floor
  ok  8 independent adds cost FAR less than 8 dependent
  ok  the marginal cost of a dependency was measured
  ok  the marginal cost of an independent op was measured
  ok  a dependency costs MORE than an independent operation
  ok  and by at least a factor of 1.5
  ok  the published ratio is between 1.5x and 20x
</pre>
                </div>
                <p>Group by group, with the reason each exists:</p>
                <div class="formula">
  A  the artifact runs at all            1 check

  B  the INSTRUMENT                     5 checks
     the TSC rate, its invariance, the
     noise floor, and that the output
     itself refuses to call a tick a cycle

  C  ALIGNMENT                          3 checks
     the only EXACT checks in the file --
     read from the ELF, no clock involved

  D  latency/throughput SHAPE           7 checks
     monotonicity, floor relations, and the
     one comparison that matters: 8
     independent costs far less than 8
     dependent

  E  the ratio's BOUNDS                 5 checks
     ordering plus a 1.5x floor and a 20x
     ceiling, so a nonsense value fails

  F  branches                          5 checks
     the claim is NEGATIVE -- no period
     effect -- plus the branchless result
     and the statement that its comparison
     is not clean

  G  the LIMIT                          4 checks
     no penalty observed, called a limit,
     the reason given, and the PMU really
     being absent

  H  the alignment EFFECT              3 checks
     the spread exceeds 1.2x, and the
     output declines to claim a mechanism

  I  the RETRACTIONS                   4 checks
     all three are present in the text, so
     they cannot be quietly dropped
                </div>
                <p>Two of those groups are doing something unusual and they are the ones worth stealing. <strong>Group C asserts an exact value read from the file</strong>, which is possible because alignment is a property of the link rather than of the clock. And <strong>group I asserts the presence of the course&rsquo;s own admissions</strong>, which is a check on the writing rather than on the machine &mdash; and it is the only one that fails if somebody edits a sentence carelessly.</p>
                <p>Group F deserves a note too, because asserting a negative is harder than it looks. The claim is &ldquo;the branch period makes no measurable difference&rdquo;, and the check is a bound on the spread across all periods plus a check that the control falls inside that spread. <strong>A harness cannot assert that nothing happened; it can only assert that nothing happened <em>more than this much</em>.</strong> That is the honest form of a null result, and it is why the number 1.6 is in the code rather than the word &ldquo;none&rdquo;.</p>
            </div>

            <div class="unit unit-example">
                <h2>Breaking the Checker on Purpose</h2>
                <p>The property of a harness this course cares about most is not that it passes. It is that <strong>it has been observed to fail</strong>. A checker that has never failed is not known to work, and the way to find out is to break something deliberately and confirm the right check catches it.</p>
                <div class="formula">
  BREAK THE DATA, then the CHECK, and see which
  one is caught.

  1. remove a bench body's alignment attribute.
     Expect: group C fails, naming the symbol
             and its address. This is the
             EXACT check doing its job -- it
             should fail the instant the thing
             it reads changes.

  2. swap two marginal rows in cycbench's
     printf, so the dependent and independent
     series are reported in each other's order.
     Expect: group E fails on the ordering
             check, and group D fails on
             monotonicity. Two groups, two
             different errors, correctly
             distinguished.

  3. now the important one: change a CHECK, not
     the data.

       sed -i 's/dmid > imid/dmid > imid * 0.1/' crosscheck.py
       python3 crosscheck.py

     Expect: 37/37 still passes, because you
     made the check weaker and nothing about
     the machine changed.

     THIS IS THE POINT. A harness that can be
     weakened without failing has no
     relationship to the artifact at all. Every
     time you lower a threshold you have to be
     able to say which claim you are giving up,
     and the honest way to do that is to change
     the CLAIM -- in research.md and in the
     course -- not the check.

  4. delete a retraction from the artifact's
     output text.
     Expect: group I fails. A retraction that
     can be deleted without consequence was
     documentation, not a constraint.
                </div>
                <p>Step 3 is the one that generalises to everything in this collection, and it has bitten in every course so far. <strong>Six times across two courses, a check failed for a reason that had nothing to do with the thing being checked</strong>: a reference parser read the wrong stream, a section reader was one column out, a regex matched a prose line, a <code>struct</code> key was looked up as an int, a compiler deleted a benchmark, a padding scheme produced an illegal instruction. In every case the fix went into the harness and never into the artifact, because the artifact was right.</p>
                <div class="hex-dump">
                    <pre>$ python3 -c "
    import sys; sys.path.insert(0,'.')
    import crosscheck as C
    out, rows, marg, noise, spread, mispred = C.parse_cycbench()
    print('  marginals parsed:', marg)
    "
    marginals parsed: {'dep': [], 'ind': []}
  # the 'independent' marginals were EMPTY because a PROSE line --
  # "independent ones retire several per cycle" -- matched the
  # data regex and overwrote them with nothing.
  #
  # the fix was the \d+\s+adds anchor. a parser that accepts
  # prose is a parser that will eventually be right by accident.
</pre>
                </div>
                <p>And the last of these was the sharpest, because <strong>it was this course&rsquo;s own mistake in the course about it.</strong> An early version of the harness asserted that the measured noise floor was <em>below 40%</em>. The noise floor is a measurement of a noisy quantity, so it varies &mdash; and one run in five reported 72% on a machine that had not changed.</p>
                <div class="formula">
  a VALUE claim about a NOISY measurement:

     ck(&#39;B&#39;, &#39;the noise floor is below 40%&#39;,
        noise &lt; 40)

  fails about one run in five, on hardware that
  has not changed, for a reason that has nothing
  to do with what is being verified.

  the fix is not a looser threshold. it is to
  stop making the claim:

     ck(&#39;B&#39;, &#39;the noise floor is measured&#39;,
        noise is not None)
     ck(&#39;B&#39;, &#39;and it is finite and positive&#39;,
        0 &lt; noise &lt; 10000)

  and then USE it -- as the tolerance for the
  value-shaped checks, which is what it is for.

  10 consecutive runs afterwards: 37/37, every
  time. a harness that fails one run in five is
  a harness people learn to re-run, and a
  harness people learn to re-run verifies nothing.
                </div>
                <p>The same fix had to be made to the ratio check, for the same reason. <strong>A median of marginal costs can go near zero on a bad run</strong> and produce a ratio of 27&times; &mdash; arithmetically true, physically absurd &mdash; so the factor check was moved onto the <em>totals</em>, which differ by about five times and are far outside any plausible noise.</p>
                <p>And the reason this matters more here than in the earlier courses is the noise. <strong>A harness that fails for the wrong reason is annoying; a harness that fails for the wrong reason on a noisy instrument is corrosive</strong>, because with a 15% noise floor a reader cannot tell a real failure from a harness bug, and the natural conclusion is to ignore it. That is the mechanism by which a verification suite quietly stops verifying, and the only defence is that each check fail loudly, for one reason, in a way that names what it was looking at.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try It Yourself</h2>
                <div class="hex-dump">
                    <pre>$ cd courses/exe/assets/samples
$ python3 crosscheck.py
$ python3 crosscheck.py -v
$ python3 crosscheck.py 2&gt;&amp;1 | sed -n '/^C /,/^D /p'
</pre>
                </div>
                <p>Then break it, which is the exercise:</p>
                <div class="hex-dump">
                    <pre>  1. Break the data and watch the EXACT check
     fire. Remove one alignment attribute:

       sed -i 's/__attribute__((aligned(64)))\n//' cycbench.c

     (or simply delete the attribute from one
     function and rebuild). Expect group C to
     fail naming the symbol and its address.

     This is the one check in the file with no
     noise term, so it must fail the instant the
     thing it reads changes. If it does not, it
     is not reading what it claims to read.)

  2. Break a SHAPE and watch a different group
     fire. Swap the dependent and independent
     marginals in cycbench's printf, rebuild,
     and run. Expect groups D and E to fail and C
     to pass -- three groups, three different
     claims, correctly separated.

  3. Now weaken a CHECK and confirm that
     nothing catches it, which is the finding:

       # change an assertion in crosscheck.py so it
       # is trivially true, and do NOT touch the
       # artifact
       python3 crosscheck.py    # still 37/37

     That is what a check that has been weakened
     looks like from the outside, and it is
     indistinguishable from a passing suite. The
     defence is a review habit, not a tool: every
     threshold change should be a one-line commit
     whose message names the claim it gives up.

  4. Add a check for something the course does
     not claim yet, and see whether you can make
     it pass honestly. Good candidates:

     - that the artifact contains no assertion
       of an absolute cycle count (grep for
       "cycles" outside the refusal sentences)
     - that every number printed is either a
       ratio, a minimum, or explicitly labelled a
       raw tick count
     - that the TSC rate is re-measured rather
       than hard-coded anywhere in the artifact

     (Each of those is a check on the WRITING
     rather than the machine, and they are the
     kind that catches a claim quietly hardening
     from "we did not measure this" to "this is
     about fifteen cycles" during an edit.)

  5. Finally, write a claim for YOUR machine that
     this course could not, and build the check
     for it. The pattern is: measure the
     instrument, state the shape, assert the
     shape, and name the limit. Then read your own
     result the way this course reads its own --
     looking for the measurement that came out
     wrong, because on a machine with a boost
     clock and a 15% noise floor, the first
     result is usually the one that conflated
     two things.
</pre>
                </div>
                <p>Exercise 1 is the one that teaches the difference between checking and asserting. <strong>The alignment check has no noise term, so it is a genuine verification rather than a consistency check</strong> &mdash; it reads a number out of a file and compares it to 64, and the only way it can pass is if the file says what the course claims. Removing the attribute makes it fail immediately and by name, which is the behaviour a reader needs in order to trust it.</p>
                <p>Exercise 3 is uncomfortable and it is the important one. <strong>Weakening a check produces a passing suite that has lost its relationship to the artifact, and nothing in the output distinguishes it from a passing suite that has not.</strong> That is why every threshold in this course&rsquo;s harness has a stated reason next to it, and why the retraction checks exist &mdash; the alternative is a suite that anyone can make green, and a green suite nobody has broken is worth nothing.</p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The connection to <a href="/courses/obj/lessons/obj-verify">the object course&rsquo;s oracle loop</a> is the parent of everything in this concept. That course established the discipline with three independent readers and byte-exact comparison, and asked the question this concept answers: <em>how do you know your reader is right?</em> <strong>Here the answer is different in one specific way and the difference is the lesson.</strong> The object course compared three readers on <em>bytes</em> &mdash; and bytes have no noise, so three-way agreement is nearly proof. This course can only compare on <em>times</em>, which have a 15% spread, so three-way agreement would prove nothing. The response is not a weaker verification; it is a different one: <strong>assert shapes, read values, and check the parts of the claim that are not measurements at all.</strong></p>
                <p>The connection to <a href="/courses/img/lessons/img-walk">the image course&rsquo;s stack walker</a> is the shared shape of the artifact, and it is deliberate. That artifact hands over raw stack bytes and blocks on stdin so that the parent&rsquo;s <code>/proc</code> reads happen while the child&rsquo;s state is live &mdash; a design in which <strong>the measurement is arranged so the two readers can see the same thing at the same time</strong>. This course&rsquo;s artifact arranges the same thing by interleaving: body A, body B, body A, body B, so a frequency ramp perturbs both sides equally. Two courses, two instruments, one principle &mdash; <em>when two things must be compared, make sure they experience the same conditions</em> &mdash; arrived at from opposite ends of the collection.</p>
                <p>Two connections outward, both about the limits this course names. <a href="/courses/exe/lessons/exe-speculate">The speculation concept</a> is this harness&rsquo;s worked example: group G asserts that the output calls the null result a limitation, gives the reason, and confirms the PMU really is absent. <strong>A harness that checks the honesty of a course&rsquo;s prose is unusual and it is the one thing here that could not be done by a machine</strong> &mdash; someone has to decide that a claim deserves to be phrased as a limit, and then the machine can make sure it stays phrased that way. And <a href="/courses/sec/lessons/sec-posture">the hardening course&rsquo;s posture reader</a> made the opposite choice deliberately, emitting no score because hardening properties are only partially ordered; <strong>this course makes the same choice for the same reason, since a noise floor makes a single &ldquo;performance score&rdquo; a category error</strong> &mdash; there is no total order over timings on a machine that boosts, so a number would have to invent a weighting the measurements do not support.</p>
                <p>And the connection forward is the next course in the list, and it is the reason this one ended where it did. <strong>Every measurement here is about a register or an address.</strong> Not one is about memory, and that is a real limit rather than a stylistic one: the artifact never loads an array, never chases a pointer, never misses a cache, because the noise floor and the absence of a PMU make memory timing a much harder measurement than arithmetic timing on this machine. The memory-hierarchy course takes the same instrument and points it at the thing that actually limits most real programs, and it will need everything this course built &mdash; and more of it.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/exe/lessons/exe-speculate">Previous: Speculation, and What Could Not Be Measured</a></span>
                <span>Next: <a href="/courses/reloc/lessons/pie-cost">Back to the chain: Nine Instructions Against Seventeen</a></span>
            </div>
        </div>


    render_lesson_js(&mut page)
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
