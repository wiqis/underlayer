// Exceptions, Privilege and Mode Changes — Concept 8: the harness
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_harness() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Harness, and the Eight Things It Refuses to Let Go — Underlayer")
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
            <h1>The Harness, and the Eight Things It Refuses to Let Go</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>This course made claims that a reader can check, which is the standard every course in this collection holds itself to. The interesting thing is not that the checks exist. It is <strong>what the checks are willing to assert</strong>, given that this machine&rsquo;s noise floor is between 25% and 50% and its core clock moves inside a single run.</p>
                <p>The noise floor is not a detail. It decides the entire shape of the verification. A harness for a measurement with a 15% spread can assert values with a tolerance. <strong>A harness for a measurement with a 50% spread cannot assert anything numeric, and one that tries will fail on a busy machine and teach its reader to ignore it</strong> &mdash; which is how you end up with a green checkmark that has never once caught anything.</p>
                <p>So this concept is about the rules, and the rules are the transferable part. The two courses before this one each spent a concept on the same subject and each one had to learn it again, expensively.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: five rules, each one learned by breaking it</h2>
                <div class="formula">
  1. EXACT FOR STRUCTURE, SHAPES FOR TIMING.
     The canonical-access matrix, the ten IDT bytes,
     the six fault-row outcomes and the eight
     retractions are asserted EXACTLY, because they
     are exact.  The five timing arms are asserted as
     ORDERINGS and as ratios that must clear the floor
     the artifact itself measured and printed.

  2. AGREEMENT, NOT MAGNITUDE.
     Where a claim compares two of the artifact's own
     numbers, the check is that the two AGREE.  The
     4096 entries must equal limit/16 + 1.  The base
     must be exactly 2^32 below the top of a 48-bit
     space.  Neither number is machine-independent;
     the agreement between them is.

  3. A SHAPE IS ASSERTED AS A SHAPE.
     The access-width matrix is checked as a clean
     1-then-128 staircase in each column, with the
     cut index strictly decreasing as the access
     widens, and at offsets 0, -3 and -7.  A check
     that asked "is the 8-byte row equal to 128" would
     be asserting one cell of a rule and would not
     notice if the other eleven cells were rewritten.

  4. AN ABSENCE IS AN ABSENCE.
     The vDSO has no sigreturn trampoline on this
     kernel.  The harness checks that the artifact
     SAYS SO and that it says why guessing would have
     been wrong -- because the alternative is a
     decoder that prints 15 whenever a 0f 05 is near a
     b8, which is right on some builds and wrong on
     this one and cannot tell the difference.

  5. RETRACTIONS ARE TEXT.
     Eight of them, and the harness asserts that each
     is still present as a string in the artifact's
     output.  Not "the claim is false" -- "the claim
     is still written down".  A retraction nobody can
     see is a retraction that will be re-derived
     eventually.
                </div>
                <p>Rule 5 is the one that costs nothing and is skipped most often, and it is the reason the memory course and the execution course both have a group whose only job is to assert the presence of a sentence. <strong>The most likely future edit to any course in this collection is somebody deleting a retraction because it makes the artifact look worse</strong>, and the retraction groups exist to make that edit fail the build.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what the 88 checks are, group by group</h2>
                <div class="hex-dump">
                <pre>$ cd courses/priv/assets/samples &amp;&amp; ./build_samples.sh
  --- group A: what the artifact measured before it measured anything
  --- group B: the ten bytes SIDT wrote, and the one it did not
  --- group C: the numbers, and the ones that are not numbers
  --- group D: four ways in, and the one that changes no mode
  --- group E: reading the convention out of bytes, not out of a manual
  --- group F: 2^47 minus (access size - 1), as a shape
  --- group G: one address, several accesses, several answers
  --- group H: every retraction is still present
  --- group I: the limits, and the verdict

  crosscheck: 88 checks, 0 failed
</pre>
                </div>
                <p>Three of the checks are worth naming individually, because they are checks about the <em>checking</em>.</p>
                <p><strong>Group A checks that the noise floor was measured before anything was claimed.</strong> Not that it is small &mdash; that it is <em>printed</em>. If a future edit removed the floor measurement, the ratio checks that depend on it would silently compare against a default, and the harness would still go green. So the floor is itself a checked fact.</p>
                <p><strong>Group B checks the wrong reading is still displayed.</strong> The harness asserts that the artifact prints both the correct field order and the incorrect one, and that the incorrect one is visibly wrong. This is the course&rsquo;s most concrete defence against the mistake it documents: the failure mode was a <em>silent</em> misparse, and the only way to keep a silent failure from returning is to keep the correct answer next to it.</p>
                <p><strong>Group H checks that R5 through R8 are present.</strong> Those are the retractions that came from this course&rsquo;s own tooling, and three of them are about code that no longer exists. There is nothing left to diff against, so a text assertion is the only check that survives.</p>
                <h3>The four failures this harness had of its own</h3>
                <p>Worth recording, because they are the same disease the previous two courses documented.</p>
                <div class="formula">
  a. A LINE-BREAK TRAP, and it failed four checks
     at once.  The artifact wraps its prose at about
     78 columns, so "READ FROM THE MANUAL, not
     measured" is two lines in the file.  The harness
     searched for the sentence.  Four checks failed
     about text that was demonstrably present --
     including three about RETRACTIONS.

     This is the worst kind of harness failure: it
     teaches a reader to distrust a harness that was
     right.  Fixed by matching against a
     whitespace-normalised copy.  The numeric parses
     still run on the original, because collapsing
     whitespace there would join adjacent table columns.

  b. A HEX PARSER THAT COULD NOT HOLD HEX.
     The number extractor returned floats, because
     that is what it had always done.  It crashed on
     the first 0x.. it met.  Two extractors now: one
     for numbers, one for raw strings.

  c. A TRUNCATING EXTRACTOR.
     The same helper returned only the first capture
     group, so a check that wanted two hex numbers got
     one and could not fail.  It now returns all
     groups, and says why in a comment.

  d. A PERCENTAGE TREATED AS A FRACTION.
     The noise floor is printed as 25.5, meaning
     25.5%.  A ratio check compared against
     1.0 + 25.5 and required the result to be under
     56 -- a bound so loose that the check could not
     fail.  The formula now divides by 100, and the
     check says what the floor was.
                </div>
                <p>None of those four would have been found by reading the harness. All four were found by running it. <strong>That is the argument for the exercise below, and the argument for not trusting a green build.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: break it on purpose, twice</h2>
                <p>The manifest&rsquo;s completion criterion for this course is not &ldquo;read it&rdquo;. It is: <em>reproduce the 88 checks and then break the pseudo-descriptor read on purpose to make the group that catches it fail by name.</em></p>
                <p><strong>Exercise 1: the one the criterion names.</strong> In <code>privbench.c</code>, find the declaration</p>
                <div class="formula">
   struct pseudo_desc &#123; uint64_t base; uint16_t limit; &#125; __attribute__((packed));
                </div>
                <p>and swap the two fields. Rebuild. Rerun the harness. <strong>Three checks in group B fail, and they name themselves:</strong> the entry count no longer equals <code>limit/16 + 1</code>; the base is no longer 2<sup>32</sup> below the top of a 48-bit space; and the reading that is supposed to be shown as wrong is no longer distinguishable from the right one. Then swap them back and confirm 88 again.</p>
                <p>The value of that exercise is not the failing build. It is that <strong>a check that has never been seen to fail is a check with no reason to be believed</strong>, and this one has three independent ways to notice the same error, which is what makes it a check rather than an assertion.</p>
                <p><strong>Exercise 2: the one that finds a check you did not know was weak.</strong> Delete the sigreturn-absent message from the artifact &mdash; the four lines that say the trampoline is not in this build. Group E fails, which you expect. Now, instead, change the decoder&rsquo;s pattern from the exact eight bytes to &ldquo;a <code>b8</code> within five bytes of any <code>0f 05</code>&rdquo; and make it print a syscall number for every site. <strong>How many group E checks fail now, and how many of the five sites get a number they should not have?</strong> If the answer is &ldquo;one check&rdquo; or &ldquo;none&rdquo;, you have found a gap, and closing it is the right next edit. The check as written asserts that the decoded count matches the number of sites with the exact shape; it does not assert that an undecoded site was left alone, and that is a real omission.</p>
                <p><strong>Exercise 3: the general one.</strong> Take any claim in this course. Write down whether it is a <em>value</em>, a <em>shape</em>, or an <em>agreement</em>, and then ask which of the three you could re-derive on a machine you have never used. Everything else is a remembered number, and a remembered number in a check is a check that will fail for the wrong reason on a busier machine &mdash; which is the same sentence as &ldquo;a harness nobody trusts.&rdquo;</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Do exercise 1 and 2 above, in that order, and write down which checks failed before you predict which would.</strong> <em>(Predicting first is what makes the exercise worth doing; the gap between your prediction and the result is the thing you learn, and it is usually a check you did not know existed.)</em></li>
                    <li><strong>Find the group-E gap and close it.</strong> Add a check asserting that every site the artifact did <em>not</em> decode is also a site that does not have the exact <code>b8 &lt;imm32&gt; 0f 05</code> shape. <strong>Then re-run exercise 2 and confirm the new check fires.</strong> A check added without a demonstrated failure is a check you have not tested, and adding it and leaving it there is the most common way a harness rots.</li>
                    <li><strong>Run the harness on a deliberately busy machine.</strong> Start eight spinning processes and rerun. <em>Expect: groups B, C, E, F, G, H and I all pass unchanged, because they assert structure, and group D may fail because it asserts ratios against a floor the machine itself inflated. That asymmetry is the design working. If instead a large group fails together, the harness has a bare number in it somewhere and you have found it.</em></li>
                    <li><strong>Port the rule set, not the checks, to the next course.</strong> The next course in this chain is <em>Multiprocessor Architecture</em>. Write down which of the five rules it will need most, and why. <em>(The answer is rule 1, and the reason is that a coherence measurement on a machine with twelve hardware threads will have a worse floor than a single-core memory measurement, not a better one. A course about many cores must be <em>more</em> conservative about numbers than a course about one, and that is counter-intuitive enough to be worth writing down in advance.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the ledger for all seven. <a href="/courses/priv/lessons/priv-canonical">The canonical concept</a> produced the only exact result in the course and the three harness corrections that followed from it, including the <code>memset</code>-on-volatile bug that produced a boundary inside a single page. <a href="/courses/priv/lessons/priv-convention">The convention concept</a> produced the absent-sigreturn rule, which is rule 4 here. <a href="/courses/priv/lessons/priv-errorcode">The error-code concept</a> produced the six-row table and the two failures that made it mean something. <a href="/courses/priv/lessons/priv-table">The table concept</a> produced the field-order retraction and the rule about preferring a loud failure to a plausible one. <a href="/courses/priv/lessons/priv-doors">The doors concept</a> produced the claim the artifact refuses to make about the port accesses. <a href="/courses/priv/lessons/priv-vectors">The vector concept</a> produced the three formats' worth of manual disagreements. <a href="/courses/priv/lessons/priv-three">The three-architectures concept</a> is the one where &ldquo;measured&rdquo; and &ldquo;quoted&rdquo; diverge most, and this concept is where that divergence is stated rather than blurred.</p>
                <p>Outward, the two immediately preceding courses own the same rules one level along, and reading the three together is the way to learn them. <a href="/courses/mem/lessons/mem-verify">The memory course's harness concept</a> and <a href="/courses/exe/lessons/exe-verify">the execution course's</a> each have a retraction group, a noise-floor rule, and a paragraph on what their artifact cannot claim. <strong>This course's rules are those rules, one course further along, applied to a machine where the numbers are worse and therefore the discipline has to be stricter.</strong></p>
                <p>And the last word belongs to the thing the course refuses to measure. A user process cannot read the IDT, cannot see a saved instruction pointer, cannot see an error code, and cannot read the CR4 bits. <strong>Six of the eight concepts here are about what a ring-3 program can find out</strong>, and the honest summary of the collection's state on this subject is that a very large amount of the privilege boundary is, by design, visible only from inside. The next course in this chain has to work with less, and knowing precisely what &ldquo;less&rdquo; consists of is the thing this one is for.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-three">The Same Idea Under Three Architectures</a></span>
                <span>End of Exceptions, Privilege and Mode Changes &middot; <a href="/courses/priv">back to the course</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
