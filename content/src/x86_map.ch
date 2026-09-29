// x86-64 Assembly and Encoding — Concept 5: the map audit and the harness
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_map() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Audit, and the Reader That Agreed With Itself — Underlayer")
    page.appendTitle(&title)

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
            <h1>The Audit, and the Reader That Agreed With Itself</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/x86asm">x86-64 Assembly and Encoding</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The manifest&rsquo;s completion criterion for this course is not &ldquo;read it&rdquo;. It is: <em>reproduce the 155 checks, then break the decoder&rsquo;s length arithmetic on purpose and make the group that catches it fail by name.</em> That sentence is the argument for this concept, so it is worth reading as engineering rather than as course admin.</p>
                <p>The harness is <code>crosscheck.py</code>, 155 checks in nine groups, and it does not re-measure anything. It reads the recorded output of the artifact and asks whether the claims are still there. <strong>The interesting thing is not that the checks exist but what they are willing to assert</strong>, and that is decided by a single number the artifact prints before it makes any claim at all:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/estimator =/,/WHAT A BENCHMARK/p'
  estimator = min-of-5, 2000000 iterations, two bodies:
     a POINTER CHASE, 64 KiB of nodes, L2-resident    6.994 ticks/op
     an ARITHMETIC increment loop                        0.661 ticks/op
  </pre>
                </div>
                <p>And the two numbers are <strong>a factor of ten apart</strong>, which is not noise: an arithmetic loop is bounded by the core clock and the TSC is fixed-rate, so a clock ramp reads as noise that is really the clock. A pointer chase spends its time <em>waiting on a load</em> and a clock change does not shorten it. <strong>What a benchmark&rsquo;s noise usually is tells you which part of the machine the benchmark is actually measuring</strong>, and the artifact quotes the chase and prints the other one so the gap is on the page.</p>
                <p>So: <strong>a harness for a measurement with a 230 % spread cannot assert values, and one that tries will fail on a busier machine and teach its reader to ignore it</strong> &mdash; which is exactly how the harnesses of the four preceding courses broke. The arithmetic of a threshold wide enough to catch a real change is also wide enough to swallow the change.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: five rules, each one learned by being wrong</h2>
                <div class="formula">
   1. EXACT FOR STRUCTURE, SHAPES FOR TIMING.
      Asserted exactly: the register-name bit patterns
      (0x7fffffff, 0xffffff01, the cl=64 mask, the OF
      bit, the two byte-identical divide rows), the four
      lengths three readers agree on, the four columns of
      the map table SUMING TO 256, the reserved flag bits
      read back individually, the fourteen retractions, and
      their NUMERIC ORDER.
      Asserted as a shape: the ALU result, the LEA spread,
      the map occupancy directions.

   2. THE RESULT IS A SHAPE, NOT A NUMBER.
      The claim the course exists to make -- ADD and SUB
      chain and CMP and TEST do NOT -- is a PAIR of
      conditions:

         add > 2.5x  and  sub > 2.5x
         0.55 < cmp < 2.0  and  0.55 < test < 2.0
         min(add,sub) > 1.6 x max(cmp,test)

      Either half alone is nearly contentless.  Together
      they say "these two chain and those two do not", and
      the four ratios moved to 3.31, 3.95, 1.64 and 1.37
      on the three recorded runs and never crossed.

   3. AN ABSENCE IS AN ABSENCE.
      No PMU.  No AVX-512.  No misprediction rate.  Each
      is checked as a STATEMENT plus its REASON, because
      the alternative is a harness that prints a plausible
      number in the space where the number is unknown.

   4. RETRACTIONS ARE TEXT.
      Fourteen of them, and the harness asserts each is
      still a string in the artifact's output.  Not "the
      claim is false" -- "the claim is still written down".
      A retraction nobody can see is a retraction that
      gets re-derived eventually, usually by the same
      person.

   5. A CHECK THAT FAILS FOR AN INVISIBLE REASON IS
      WORSE THAN NO CHECK.
      The corollary is the two-RATIO-BANDS check: a band
      that is too tight to survive a busy machine is a
      check whose failure is noise, and a band so loose
      that nothing can fire it is not a check either.
      Both look identical from the outside -- a green tick.
                </div>
                <p>Rule 1 is the one a reader is most likely to think is pedantic, so here is what it costs. <strong>Without it the harness would assert that the ADD chain ratio is 3.65&times;, and it would fail on a machine where the same experiment gives 3.31&times; &mdash; a machine where the course is just as correct.</strong> A check like that does not protect the claim; it protects the author&rsquo;s day. With rule 1 the check passes on all three recorded runs and would still pass on a machine whose ADD ratio is 2.6.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: nine groups, and the two that are about the checking</h2>
                <div class="hex-dump">
                <pre>$ python3 crosscheck.py
  --- group A: what was measured before anything was measured
  --- group B: the ALU group, and the result that was not the one expected
  --- group C: the register-name decisions, read out of the machine
  --- group D: SETcc, CMOVcc, and a fault instead of a timing
  --- group E: LEA, and the claim about it that did not survive
  --- group F: four encodings, three readers
  --- group G: the three maps, read twice, and one reader's useless agreement
  --- group H: every retraction is still present
  --- group I: the limits, and the verdict

  crosscheck: 155 checks, 0 failed
  </pre>
                </div>
                <p>Seven of the nine groups check the machine. <strong>The two that check the <em>checking</em> are the ones worth naming</strong>, and they exist because of the experiments in the two previous concepts.</p>
                <p><strong>Group G asserts the two-reader cross-check and then runs the control that proves the cross-check is necessary.</strong> Fifty-one corpus entries are decoded by the artifact&rsquo;s own length function and compared against the bytes the assembler emitted, which objdump independently confirms. All 51 agree and none disagree. But before that, the artifact decodes the corpus <em>twice through the same code path</em>, gets 100 % agreement, and then <strong>poisons its own table and gets 100 % agreement again</strong>:</p>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/CONTROL: decode/,/EVIDENCE/p'
  CONTROL: decode every corpus entry TWICE through the same code path.
     agreement: 51 of 51   -- 100%, and it means nothing at all.
       with the first byte of entry 1 changed, it still agrees with
       itself: 4 and 4, still 100%.  SELF-AGREEMENT IS NOT EVIDENCE.
  </pre>
                </div>
                <p>That is the cheapest demonstration in this collection of why a check that reads its own input twice proves nothing, and it is in the artifact&rsquo;s own output rather than in a principle stated in prose. <strong>Group F is the other one</strong>, and it is the only group that asserts a fault: the guard-page result in the third concept, checked as <em>the cmov died and the branch did not</em>, plus the control that the page really was unreadable. A group that asserted &ldquo;the cmov is correct&rdquo; could not exist, because correctness of a branchless form is a claim about the compiler and not about the instruction; the group asserts the observation instead and names what it cannot say.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the five failures this harness had of its own</h2>
                <p>They are worth recording because they are the same disease the four preceding courses documented, and because <strong>not one of them was found by reading the harness.</strong> All of them were found by running it.</p>
                <div class="formula">
   a. A CHECK THAT FAILED ON THE COURSE'S OWN EVIDENCE
      BY A HANDFUL OF PERCENT.
      The first version required the no-chain floor to be
      "within a factor of 2.5 of the chain", which is a
      band whose width came from the recorded run and not
      from the machine.  It passed on x86dec.out and failed
      on run1.txt and run2.txt, which are the same
      machine and the same experiment.  Split into the
      three conditions it is now written as, and widened
      to the range the three recorded runs actually span.
      A TOLERANCE THAT TIGHT IS A CHECK WHOSE FAILURE IS
      NOISE, which is rule 1's reason for existing.

   b. AN EXTRACTOR THAT RETURNED THE WRONG CAPTURE
      GROUPS.
      The map-table parser took group(1) and group(2) from
      a pattern whose FIRST group was the row key.  So
      every row returned the key and the first number, and
      the seven-column arithmetic table came out with six
      values per row and the whole group silently emptied.
      THE HARNESS THEN PASSED, because it had nothing to
      check.  This is the fifth time in this collection
      that a helper written for one shape has been used on
      another, and the fix -- take the LAST two groups, with
      a comment saying why -- is the whole fix.

   c. A PARSER THAT SILENTLY PRODUCED A COLUMN OF ZEROS.
      The two-column map file was split on WHITESPACE, and
      both readings contain spaces because a decoder
      prints four operands.  So the VEX column was zero on
      every row and the table printed 101, 125 and 54 as
      if they meant something.  Nothing failed.  The table
      was PLAUSIBLE and one of its columns was fiction.
      Fixed by delimiting with a pipe, and the comment in
      the source says why: a parser that guesses gives you
      a plausible table with a column that is silently
      zero, and that is worse than a crash.

   d. SUBSTRING CHECKS THAT FAILED ON CASE.
      "IS ONE DECODE" can never match a file that says "is
      ONE DECODE".  Every such assertion now runs against a
      whitespace-normalised copy and, where the case of the
      probe was a guess, against a lower-cased copy too.

   e. A COMBINATION THAT WAS CORRECT AND FAILED ANYWAY.
      Two separate renames in the artifact -- a diagnostic
      moved from the artifact to a captured file, and the
      divide-control changed from "compare with the row
      above" to "two identical rows" -- each left a harness
      probe pointing at text that no longer existed.  The
      failure message was the probe's name, which told the
      reader nothing.  Now each of those checks asserts the
      REASON the text is there, not the text.
                </div>
                <p>And the two helpers that were rewritten without having been failures &mdash; the row extractor and the map parser &mdash; are documented in the source with the reason, because the fourth time a collection-wide habit repeats is the time a reader stops believing it was an accident.</p>
                <h3>The map table itself, which is the course's other result</h3>
                <div class="hex-dump">
                <pre>$ ./x86dec | sed -n '/map        slots/,/neither/p'
  map        slots   legacy   VEX   legacy only   VEX only   both   neither
  0F           256     218   101           124          7     94        31
  0F38         256      28   125            13        110     15       118
  0F3A         256       2    54             1         53      1       201
  </pre>
                </div>
                <p>768 slots, each written into a real file as real bytes and handed to a real decoder, twice: once with the legacy escape and once with a three-byte VEX in front of the same escape. <strong>0F 3A is named in 2 of its 256 slots with the legacy escape and 54 of them with one byte in front.</strong> The draft of this course said the newer maps were nearly <em>full</em>, because the designers knew a two-byte map would be consumed and put a second escape in front of it. Measured, they are the emptiest part of the whole encoding in their legacy form, and the room is what VEX and then EVEX moved into.</p>
                <p>And the counts are asserted as a <strong>partition</strong>, not as values: legacy-only + both == the legacy count, VEX-only + both == the VEX count, and all four columns sum to 256 for every map. That is the check that would have caught failure (c) above, and it is exact even though the numbers are not.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Do the manifest&rsquo;s exercise: break the decoder and watch group F fail by name.</strong> In <code>x86dec.c</code>, delete the <code>imm_bytes</code> lookup from the VEX branch of <code>decode_len</code>, rebuild, run, re-check. <em>(Expect the <code>vpalignr</code> and <code>vperm2f128</code> rows to report a length one byte short, the section 4 cross-check to print the disagreements by name rather than as a count, and group F to go red on the &ldquo;all modelled entries agree&rdquo; check. Write down which check fired <em>before</em> you predict which would &mdash; the gap between the two is usually a check you did not know existed. Then put it back and confirm 155.)</em></li>
                    <li><strong>Add a check that cannot fire, and confirm that it cannot fire.</strong> Assert that the <code>0F3A</code> legacy count is 256. <em>(Expect it to fail today, which is the point: the machine changed under it. Now write the version that is true &mdash; that <code>0F3A</code> legacy is <em>below</em> 32 and that it is <em>below</em> its own VEX count &mdash; and confirm that it passes on all three recorded runs. You have just written the difference between a check that remembers a number and a check that remembers a property, and the second is the only one that survives contact with a new binutils.)</em></li>
                    <li><strong>Freeze one number and watch it fail on the course&rsquo;s own evidence.</strong> Add <code>check(g, "add chains at 3.65x", abs(A/B - 3.65) &lt; 0.1)</code> to group B. <em>(Expect it to pass on <code>x86dec.out</code> and to fail immediately on <code>run1.txt</code> and <code>run2.txt</code>, where the same ratio is 3.90 and 3.31. All three files are the same machine and the same experiment and all three are shipped with this course. You have just written a check that fails on the course&rsquo;s own evidence, which is the clearest possible demonstration that a remembered number is not a fact.)</em></li>
                    <li><strong>Write the control for your own next check.</strong> Whatever you write next &mdash; a linker, a decoder, a test suite &mdash; find the assertion that reads the same input twice and make it fail on purpose. <em>(Expect the effort to be about five minutes and the result to be uncomfortable: you will find an assertion that has never been able to fail, and you will not be able to remember writing it. A check that has never been seen to fail is a check with no reason to be believed, and the only way to know which of yours are which is to watch each one go red once.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the ledger for the other four. <a href="/courses/x86asm/lessons/x86-asm">The first concept</a> produced the two syntaxes and the <code>lock</code> diagnostic that the corpus exists to hold. <a href="/courses/x86asm/lessons/x86-integers">The integer set</a> produced the ALU shape that group B asserts and the bit patterns group C asserts exactly. <a href="/courses/x86asm/lessons/x86-flags">The flags concept</a> produced the guard-page result, which is the only assertion in the whole harness that is a fault rather than a duration. <a href="/courses/x86asm/lessons/x86-vex">The prefix encodings</a> produced the four encodings group F cross-checks and the 768 slots group G counts.</p>
                <p>Outward, the neighbouring harnesses own the same rules one course along and reading all of them is how you learn them rather than memorise them. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness</a> has four documented failures of its own and the rule that an absent message must be asserted as text. <a href="/courses/smp/lessons/smp-harness">The multiprocessor course's</a> has a retraction group, a noise-floor rule, and the pair of conditions that assert its central result as a shape. <a href="/courses/simd/lessons/simd-harness">The vector course's</a> has a group that could not run at all on two of three runs &mdash; <strong>a course whose extra evidence is produced by different code is a course whose extra evidence is not comparable with its first evidence</strong> &mdash; and this course ships three runs through one code path for exactly that reason.</p>
                <p>And the last word belongs to the thing this course will not measure. <code>perf_event_paranoid</code> is 4, and there is no way from user mode on this machine to count a branch, a misprediction, an instruction or a cycle. <strong>Every number in the measurement sections is a duration, and a duration bounds a count without measuring it.</strong> That is not a footnote and it is not a limitation of the author&rsquo;s effort: it is a property of the machine, it was proved rather than assumed, and it is asserted by group A so that a future reader cannot quietly forget it. The three courses that follow this one in the section &mdash; the ABI, the machine, the data path &mdash; all inherit that position and none of them improves on it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86asm/lessons/x86-vex">Two Bytes, Three, and the Bit That Went Wrong</a></span>
                <span>End of x86-64 Assembly and Encoding &middot; <a href="/courses/x86asm">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
