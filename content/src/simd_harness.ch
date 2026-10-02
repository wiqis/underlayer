// SIMD and Vector Processing — Concept 7: the harness
public namespace underlayer_content {

using std::string

using std::string_view

public func render_simd_harness() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Harness, and the Eight — Underlayer")
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
            <h1>The Harness, and the Eight</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/simd">SIMD and Vector Processing</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The manifest&rsquo;s completion criterion for this course is not &ldquo;read it&rdquo;. It is: <em>reproduce the 131 checks, then restore the static initialisers on the control arm&rsquo;s three pointers and make group D fail by name.</em> That sentence is the whole argument for this concept, so it is worth reading as engineering rather than as course admin.</p>
                <p>The harness is <code>crosscheck.py</code>, 131 checks in nine groups, and it does not re-measure anything. It reads the recorded output and asks whether the claims are still there. <strong>The interesting thing is not that the checks exist but what they are willing to assert</strong>, and that is decided by one number the artifact prints before it makes any claim at all:</p>
                <div class="hex-dump">
                <pre>$ ./simdbench | sed -n '/estimator =/,/^   The body/p'
   estimator = min-of-3, 11 of them: spread  25.1%  (11.81 ns/iter)
   The body is the section 2 loop.  This number is the reason the
   crosscheck asserts SHAPES and not values: a tolerance that wide can
   verify that 4 lanes beat 1 lane and cannot verify by how much.
  </pre>
                </div>
                <p>25.1% on the recorded run, and 33.5% and 62.5% on the two others &mdash; the same body, the same machine, the same binary, minutes apart. <strong>So a harness for a measurement with a 25% spread cannot assert values with a tolerance, let alone one measured at 62%</strong>, and one that tries will fail on a busy machine and teach its reader to ignore it, which is exactly how the previous three courses&rsquo; harnesses broke. The floor is also the reason the artifact&rsquo;s own prose calls the absolute figures unusable and quotes only ratios &mdash; the ratio moved under 10% across those same three runs while the absolute nanoseconds moved by nearly two.</p>
                <p>There is a second reason this course needed a stricter harness than any of the four before it, and it is the sharpest methodological finding in the whole artifact. <strong>This is a measurement about a compiler.</strong> Every other course in this collection measured hardware. A compiler&rsquo;s behaviour is a fact about a specific program, a specific version and a specific set of flags &mdash; and a timing is not a way of establishing it. So this harness has a <em>third</em> rule the previous four did not need, and it is the reason one of its nine groups reads bytes rather than numbers.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: five rules, each learned by breaking it</h2>
                <div class="formula">
  1. EXACT FOR STRUCTURE, SHAPES FOR TIMING.
     Asserted exactly: the lane table in section 1 -- all
     twenty-five integers, and the XMM->YMM->ZMM doubling
     as its own separate check; the five AVX-512 CPUID
     leaves, and their being ZERO; the L1 being strictly
     smaller than the L3; the ORDER of the six arms; the
     presence of all eight retractions; and the four
     compiler verdicts in the VERIFY block.

     Asserted as orderings: which arm beat which.  Never
     as values.

  2. THE RESULT IS A SHAPE, NOT A NUMBER.
     The claim the course exists to make -- that the
     speedup is set by the memory system and not by the
     lane count -- is checked as a PAIR of conditions:

         4-wide at L1  >  1.8 x  4-wide at 24 MiB
         and the L1 row is the MAXIMUM of the five
         and even at 24 MiB it is still > 1.02x

     Either alone is nearly contentless.  Together they
     say "the same instruction collapses when the data
     stops fitting in a cache", and the L1 value came out
     3.89x, 3.91x and 3.70x on the three recorded runs.

  3. A CLAIM ABOUT A COMPILER IS A CLAIM ABOUT BYTES.
     Section 3 makes three claims about what gcc did.
     build_samples.sh compiles FOUR forms of the same
     loop -- named/constant, named/variable,
     pointer/constant, pointer/variable -- and the
     harness asserts the 2x2: the NAMED forms vectorise
     and the POINTER forms do not, at either trip count.
     This rule was added because the first draft had
     none and got the mechanism wrong twice.  R7.

  4. A CONTROL MUST BE ABLE TO FAIL.
     The manifest's completion criterion is to make
     group D fail by name by restoring three static
     initialisers.  A control that cannot fail is not a
     control, and a check that passes on an artefact
     that was not built is worse than no check, because
     it is COUNTED.  R8.

  5. AN EXPERIMENT THAT CAN SILENTLY COMPUTE THE WRONG
     THING MUST PRINT WHAT IT COMPUTED.
     Every table in the artifact ends with a checksum.
     Two real bugs in this file were caught by exactly
     that line and by nothing else -- an FMA with its
     operands in the wrong order, and a vhaddpd that
     reported exactly twice the true sum.  Neither
     produced a suspicious timing.
                </div>
                <p>Rule 1 is the one a reader is most likely to think is pedantic, so here is what it costs and what it buys. <strong>Without rule 1 the harness would assert that the L1 speedup is 3.89&times;</strong> &mdash; and it would fail on <code>run1.txt</code>, where it is 3.91&times;, and on <code>run2.txt</code>, where it is 3.70&times;. Three of this course&rsquo;s own recorded runs, same machine, same experiment. A check like that does not protect the claim; it protects the author&rsquo;s afternoon. With rule 2 all three pass, and the check would still pass on a machine whose ratio were 2.0 or 6.0.</p>
                <p>And rule 2 has a second job that is easy to miss: <strong>the shape catches edits the value could never catch.</strong> A value check notices the number changed. The shape check notices that the pointer column came back to 3.9&times; &mdash; which is exactly what happens the moment somebody restores the static initialisers, and which is the completion criterion for this course.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: nine groups, and what each one is for</h2>
                <div class="hex-dump">
                <pre>$ cd courses/simd/assets/samples &amp;&amp; python3 crosscheck.py
  --- group A: what the machine says it can do, before anything is claimed
  --- group B: the register, as a table of integers
  --- group C: six arms, one loop, and the two shapes it asserts
  --- group D: the same 4-wide arm at five working-set sizes
  --- group E: a claim about a compiler, checked against the bytes
  --- group F: elementwise, independent, and the price of a reduction
  --- group G: alignment, the fault, the gather and the tail
  --- group H: every retraction is still present
  --- group I: the limits, and the verdict

  crosscheck: 131 checks, 0 failed
  </pre>
                </div>
                <p>Five of the nine groups are checks about the <em>checking</em> rather than about the machine, and those are the ones worth naming.</p>
                <p><strong>Group A checks that the machine&rsquo;s own capabilities were read before anything was claimed</strong> &mdash; not that AVX-512 exists, but that it does <em>not</em>, and that all five leaves were read. That is the assertion that licenses the whole of module 3 to be quoted, and it is checked rather than assumed because a course that quotes a 512-bit register while quietly measuring one would be making a claim about hardware it has not got.</p>
                <p><strong>Group B is the one group in this collection that can tell you which cell you broke.</strong> It asserts each register&rsquo;s lane counts against a hard-coded table, and it asserts the doubling separately &mdash; so a table that got one cell wrong while keeping the doubling would still be caught, and the failure message names the register and prints the five numbers. That is possible because the lane table is arithmetic rather than a measurement, which is the whole reason it is worth having a group for.</p>
                <p><strong>Group C is the course in six checks</strong>, and two of them are shapes rather than values:</p>
                <div class="formula">
   4 lanes beat 2 lanes beat 1 lane      (the ordering)
   4 lanes is worth more than 2x         (not near 1)
   the no-vectorise floor is the SLOWEST arm
   and it is at least twice the 4-wide arms
   FMA adds nothing on top of mul+add     (within 25%)
   the compiler matches the hand-written 4-wide
   the memory-operand arm is NOT faster   <- the surprise
   and all six checksums are 32.000000, bit for bit
                </div>
                <p>That seventh one is the check that would have caught R7, and it is worth a moment. The first version of this course expected the memory-operand arm to be <em>faster</em> &mdash; one fewer load has to be better &mdash; and wrote a check defending that. The measurement said slower, the explanation turned out to be about dependency length rather than operation count, and the check was rewritten to assert the thing the data shows. <strong>A check written from a claim rather than from a measurement is a check that launders the claim.</strong></p>
                <p><strong>Group D is the course in four checks and it has the most interesting member.</strong> The three that assert the collapse are described above. The fourth is the control: the same source reached through <code>double *</code> globals must be far worse than through named arrays, by more than 4&times; at every size. That check is the one the manifest&rsquo;s exercise turns red, and it is red for a reason a reader can see in the output.</p>
                <p><strong>Group E is the group the previous four courses did not need</strong>, and it is four checks over a 2&times;2. The mnemonics are printed, not just a verdict; the compiler version and the flags are recorded beside them; and the aliasing mechanism is asserted as a named string, because a number going the right way is not evidence about bytes. If a future edit restored the pointer form and the artifact stopped being vectorised, this group is the one that notices.</p>
                <p><strong>Groups H and I are about the artifact&rsquo;s honesty.</strong> H asserts all eight retractions are still <em>present as text</em> &mdash; not that the claims are false, but that they are still written down, because a retraction nobody can see is a retraction that gets re-derived eventually, usually by the same person. I asserts seven limits and then one more check that the artifact names the disassembly as the thing that would settle the missing compiler claim. A limits section that says &ldquo;we cannot tell whether the compiler vectorised&rdquo; without saying why is a disclaimer; the same section saying &ldquo;here are the bytes&rdquo; is a checked fact.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the eight retractions, which are what group H exists for</h2>
                <p>All eight are printed by the artifact in section 8 and asserted as text. Five of the eight were found by <em>running</em> the artifact rather than reading it, and that ratio is the argument for the exercise below.</p>
                <div class="formula">
  R1  "The memory-operand arm measured 3.3, so the FMA
       memory form is broken."  THE ARM WAS WRONG, AND
       THE CHECKSUM IS WHAT SAID SO.  vfmadd231pd computes
       B*C+A rather than A*B+C.  Plausible ratio, readable
       table, and the only thing that objected was the
       checksum reading 3.3 where every other arm read
       32.0.

       GENERAL FORM, WHICH HAS NOW RECURRED FOUR COURSES
       IN A ROW: AN EXPERIMENT THAT CAN SILENTLY COMPUTE
       THE WRONG THING MUST PRINT WHAT IT COMPUTED.

  R2  "The absolute nanosecond figures are the result."
       They are not.  The first version divided ticks by a
       HARDCODED TSC rate.  And even measured, the absolute
       ns/iter for the same body moved by a factor of 1.7
       BETWEEN RUNS while every ratio moved less than 10%.

  R3  "Four lanes is 2.2x, not 4x, because the loop is
       memory bound" -- the story this course was drafted
       around.  NOT REPRODUCED.  At 1536 bytes the 4-wide
       arm is 3.89x, because 3 loads and 1 store per 4
       elements really are 4x cheaper when the load ports
       are the bottleneck.  TRUE OF A DIFFERENT WORKLOAD.

  R4  "vhaddpd adds adjacent lanes."  IT DOES NOT.  It
       adds corresponding lanes of its two SOURCES, so
       vhaddpd(v,v) DOUBLES v.  The first version reported
       EXACTLY TWICE the true sum.  A SECOND BUG WAS HIDDEN
       BEHIND IT -- the tree reduction added two 128-bit
       halves of an already-paired register, so both lanes
       held the total and it was added to itself.  Also
       exactly twice.  TWO BUGS, ONE SYMPTOM, ONE LINE OF
       OUTPUT.

  R5  "The reduction table compares four ways of summing."
       Three of the five arms were not summing; they were
       computing a sum of RUNNING TOTALS, and the first
       version reported ratios between different
       computations as though they were costs of one.

  R6  "An unaligned vector load is slow."  NOT ON THIS
       MACHINE, at two working-set sizes.  The requirement
       that is REAL is not a speed requirement at all:
       the aligned form FAULTS.  GENERAL FORM: CHECK
       WHETHER THE THING FAULTS BEFORE ASKING HOW SLOW IT
       IS.

  R7  "The compiler declined to vectorise because the trip
       count is a runtime variable."  WRONG, AND IT WAS AN
       INFERENCE FROM A TIMING.  The named form vectorises
       at BOTH trip counts; the pointer form at NEITHER.
       The trip count costs a SCALAR EPILOGUE, which is
       free.  The pointers cost the VECTOR LOOP ITSELF.
       And the same draft claimed the compiler hoists the
       loop-invariant loads of B and C -- the disassembly
       shows them loaded inside the inner loop.  THEY ARE
       NOT HOISTED.

  R8  "The control arm came out at 3.91x, so aliasing is
       not what stopped the compiler."  THE CONTROL WAS NOT
       A CONTROL.  Written as `static double *gA = bA, ...`
       -- the same three arrays in a pointer costume, which
       gcc folded away.  A CONTROL THAT CANNOT FAIL IS NOT
       A CONTROL, AND A CHECK THAT PASSES ON AN ARTEFACT
       THAT WAS NOT BUILT IS WORSE THAN NO CHECK, BECAUSE
       IT IS COUNTED.
                </div>
                <p>Read R7 and R8 together and there is one idea: <strong>a measurement of a control, and an inference from a timing, are both ways of not looking at the thing.</strong> That is why the disassembly is appended to the recorded output and why the harness reads it, and it is the third clause this course added to the two rules the previous four courses had already learned.</p>
                <p>And read R1 and R4 together, because they are the same lesson from opposite directions. <strong>A wrong answer that is approximately wrong announces itself; one that is exactly wrong does not.</strong> The FMA bug produced a checksum of 3.3 where 32.0 was expected, and the vhaddpd bug produced exactly 2&times; the right answer &mdash; which looks like a perfectly good sum of a different set of numbers, and is stable across every re-run. Neither produced a suspicious timing. <strong>You cannot detect this class of error by measuring more carefully; you can only detect it by looking at the value.</strong> That is why every table in this artifact ends with a checksum and why rule 5 of the header exists.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Do the manifest&rsquo;s exercise: make group D fail by name.</strong> In <code>simdbench.c</code>, change <code>static double *gA, *gB, *gC;</code> to <code>static double *gA = bA, *gB = bB, *gC = bC;</code> and delete the three assignments at the top of <code>sec_ceiling</code>. Rebuild, run, rerun the harness. <em>(Expect the pointer column to come back to about 3.9&times; and group D to fail on the control checks. Write down which checks failed <em>before</em> you predict which would &mdash; the gap between the two is usually a check you did not know existed. Then put the assignments back and confirm 131 again.)</em></li>
                    <li><strong>Add a check that cannot fire, and confirm that it cannot fire.</strong> Assert that the recorded <code>ns per 4 elem</code> of the scalar reduction arm is greater than 100. <em>(Expect it to pass, trivially. You have just written a check that can only fail on a machine this course does not claim to describe. Now delete the string you are matching on and watch the group go red: that it went red proves it reads the artifact, and that it cannot go red on any other machine proves it is not a check. Both facts are worth having written down, and this is the only way to learn which of your checks are which.)</em></li>
                    <li><strong>Freeze one number and see what it does.</strong> Add <code>check(g, "the L1 speedup", abs(g4[0] - 3.89) &lt; 0.01)</code> to group D. <em>(Expect it to pass on <code>simdbench.out</code> and to fail immediately on <code>run1.txt</code> and <code>run2.txt</code>, where it is 3.91 and 3.70. Both are the same machine and the same experiment and both are recorded as part of this course. You have just written a check that fails on the course&rsquo;s own evidence, which is the clearest possible demonstration that a remembered number is not a fact.)</em></li>
                    <li><strong>Break a checksum and see whether the harness notices.</strong> Change <code>arm_memop</code>&rsquo;s <code>vfmadd132pd</code> to <code>vfmadd231pd</code> &mdash; the exact bug that R1 records. <em>(Expect the table to look completely normal and group C to fail on the checksum checks, which is the whole point of rule 5. Notice that <em>no timing check fails</em>: the ratio the broken arm produces is plausible. Now go and find the two other places in your own tools where a wrong-but-plausible value can pass.)</em></li>
                    <li><strong>Port the rules, not the checks.</strong> Write down the five rules for your next project &mdash; a compiler, a runtime, a profiler &mdash; and mark which one you are most likely to break. <em>(Expect rule 3. Any project whose output includes timings will eventually be tempted to assert a timing, and the moment it does, the check becomes a statement about the day it was written. If it also involves a compiler, rule 3 is the one that catches the errors no timing will: a claim about what a compiler did needs the bytes. The defence is the same one here &mdash; decide whether each claim is a value, a shape, an agreement, or a fact about emitted code, and only the last two survive contact with a different machine.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the ledger for the other six. <a href="/courses/simd/lessons/simd-width">The width concept</a> produced the lane table that group B asserts as twenty-five exact integers, and the three-architectures deferral that group B also checks. <a href="/courses/simd/lessons/simd-compiler">The compiler concept</a> produced R7 and R8, and group E is the disassembly check that exists because of them. <a href="/courses/simd/lessons/simd-shapes">The shapes concept</a> produced the add-versus-multiply null and the 4.00&times; independence result, and the &ldquo;these four bodies leave four different numbers&rdquo; check. <a href="/courses/simd/lessons/simd-reduce">The reduction concept</a> produced R4 and R5. <a href="/courses/simd/lessons/simd-boundaries">The boundaries concept</a> produced R6 and the three shapes in group G. <a href="/courses/simd/lessons/simd-three">The three-architectures concept</a> is entirely quoted, and group I&rsquo;s checks are that the artifact says so and nothing more.</p>
                <p>Outward, the four immediately preceding harnesses own the same rules one course along, and reading them together is how you learn them rather than memorise them. <a href="/courses/priv/lessons/priv-harness">The privilege course&rsquo;s harness</a> has the same structure plus four documented failures of its own, and its rule that an absent message must be asserted as text is the same rule as R1 here. <a href="/courses/smp/lessons/smp-harness">The multiprocessor harness</a> is the immediately preceding instance and its first documented failure is <em>this course&rsquo;s</em> first: a check that asserted a difference the data did not show. <a href="/courses/mem/lessons/mem-verify">The memory course&rsquo;s</a> has the retraction group and the noise-floor rule, and it is where the &ldquo;measure the floor before you claim anything&rdquo; discipline was established. <a href="/courses/exe/lessons/exe-verify">The execution course&rsquo;s</a> has the same three and an oracle loop. <strong>Four harnesses, one shared cause: a check written to defend a claim rather than a measurement.</strong> And this course added a fifth rule to them, because it is the first in the collection to make a claim about a compiler, and the failure mode is new even though the discipline is old.</p>
                <p>And the last word belongs to the two things this course will not measure. <code>perf_event_paranoid</code> is 4, so <strong>no instruction, uop, cycle, load, store or cache-line split can be counted here</strong> &mdash; every number in sections 2 to 6 is a duration, and a duration bounds a count without measuring it. And five CPUID leaves are zero, so <strong>no 512-bit register and no mask register was measured at all</strong>; every claim about one is a manual claim with a document. Those are not limitations of effort. They are properties of the machine, they were proved rather than assumed, and both are asserted by group A so that a future reader cannot quietly forget them.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/simd/lessons/simd-three">Three Answers to One Shape</a></span>
                <span>End of SIMD and Vector Processing &middot; <a href="/courses/simd">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
