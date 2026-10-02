// The AArch64 Data Path: NEON, Atomics and Ordering -- Concept 5:
// Decode the Data Path.
//
// The concept that makes the other four trustworthy, and the one that is last
// for the same reason it is last in every course in this collection: a page
// that is mostly measurements is exactly the page a reader is most likely to
// over-trust.
//
// Its distinctive content is not a number. It is the discovery that the
// course's own cross-check had silently stopped COMPARING -- eighty-five real
// decoder defects were sitting behind a normaliser that deleted operands, and
// the printed disagreement count was zero the whole time.  That is the most
// useful thing in the section, and it is the reason the artifact runs three
// poisons rather than one.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_dataflow() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Decode the Data Path — Underlayer")
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
            <h1>Decode the Data Path</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/a64simd">The AArch64 Data Path: NEON, Atomics and Ordering</a></div>

            <div class="unit unit-why">
                <h2>Why this page is last</h2>
                <p>Every claim on the previous four pages carries one of three labels, and on most pages you would be forgiven for not noticing. This page prints all of them, in one table, with the count — and then it prints the twenty-seven retractions, the fourteen limits, and the three poisons.</p>
                <p>The reason to do that is not fastidiousness. It is that <strong>this course is about a machine that does not exist on the machine that wrote it</strong>, and a course with that property has exactly one advantage over a course with hardware — it is <em>forced</em> to be explicit about which claims are which kind. A course that does not take the advantage has thrown away the only thing it had that the x86-64 section did not.</p>
                <p>And this course took it further than any of the eleven before it, because the thing the advantage <em>buys</em> is a decoder, and a decoder turns out to be the most productive kind of thing to point a method at. Twenty-seven claims in this course were stated, then measured, then found wrong. Seven of them were found in a single afternoon and all seven by one change to a comparison.</p>
            </div>

            <div class="unit unit-model">
                <h2>The table, and the ratio that is the finding</h2>
                <div class="hex-dump">
                <pre>$ python3 courses/a64simd/assets/samples/a64data.py --run | sed -n '/concept /,/^$/p'
concept       label              the claim                                     section
  ------------ ----------------- -------------------------------------------- --------
  neon         MEASURED-ON-BYTES the access size is bits[31:30] PLUS bit 23  sec 2, 3
  neon         MEASURED          `fadd h0, h1, h2` is REFUSED at baseline    sec 2
  neonspace    MEASURED-ON-BYTES the SVE word is 0x04c00020 at 128..2048 b  sec 4
  atomic       MEASURED-ON-BYTES in CAS acquire is bit 22, release bit 15   sec 7
  atomic       MEASURED-ON-BYTES in LDADD acquire is bit 23, release bit 22 sec 7
  order        MEASURED-ON-BYTES the barrier option field is bits[11:8]     sec 8
  order        MEASURED          zero barriers in every atomic of the corpus  sec 9
  dataflow     MEASURED-ON-BYTES the encoder, decoder and assembler agree    sec 11
  dataflow     MEASURED          a normaliser that deletes an operand hides 85 sec 11
  ...

  33 MEASURED, 19 MEASURED-ON-BYTES, 10 QUOTED, 62 total
  16% of the claims in this course are QUOTED

  neon         10 MEASURED,  5 MEASURED-ON-BYTES,  2 QUOTED  (12% quoted)
  neonspace    4 MEASURED,  3 MEASURED-ON-BYTES,  2 QUOTED  (22% quoted)
  atomic       8 MEASURED,  7 MEASURED-ON-BYTES,  2 QUOTED  (12% quoted)
  order        8 MEASURED,  2 MEASURED-ON-BYTES,  3 QUOTED  (23% quoted)
  dataflow     3 MEASURED,  2 MEASURED-ON-BYTES,  1 QUOTED  (17% quoted)
                </pre>
                </div>
                <p>Sixteen percent quoted, and that is <em>lower</em> than the machine course's fifty-four percent. The distribution is not random: it follows from what each concept is about. Concepts 1, 3 and 4 are about encodings and compilers, which is exactly what a host without hardware <strong>can</strong> measure; concept 2's quoted third is the shared-resource rule, which is a statement about an architecture and not about a byte. The moment a course needs to say what something <em>does</em> rather than what it is <em>encoded</em> as, the quoted fraction goes up — and that is a design constraint on any course in this collection, not a property of the subject.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The number that was zero because the check had stopped working</h2>
                <p>Here is the finding, in the file's own words, because the paraphrase loses the part that matters.</p>
                <div class="hex-dump">
                <pre>  A ZERO FROM A NORMALISER IS NOT A ZERO

  Every number in section 11 is a number about a COMPARISON
  as well as about the decoder, and this file has now produced
  four normaliser bugs that each left the printed disagreement
  count at zero while eighty-five real defects sat behind it:

    a comma split that ignored brackets,
    an operand list truncated after its first element,
    a zero-offset rule written for the one spelling neither
      reader emits,
    and a shift-modifier rule for a spelling that does not exist.

  Not one of them printed a wrong word.  All four made the file
  stop COMPARING, which is worse, because the number is believed.
                </pre>
                </div>
                <p>Not one of them printed a wrong word. Every one of them made the file <strong>stop comparing</strong> — and that is strictly worse than printing a wrong word, because a wrong word would have shown up as a disagreement and a stopped comparison reports the same number as a working one. The encoding course filed the same shape as its R14; this course filed it four times in one file.</p>
                <h3>So the course runs three poisons, not one</h3>
                <div class="hex-dump">
                <pre>     [CLEAN]    1038 instructions read, 1031 NAMED by reader 1, 0 DISAGREEMENTS
     [POISON A] m_exclusive removed: 1038 read,  970 named (-61), 0 disagreements (+0)
     [POISON B] m_lse removed:       1038 read, 1031 named (  +0), 5 disagreements (+5)
                0x4862fc06  reader 1: ldaxp          reader 2: caspal
                0x48227c06  reader 1: stxp           reader 2: casp
                0xf8e10008  reader 1: ldur           reader 2: ldaddal
     [POISON C] bit 0 of every word: 1038 read,  945 named (-86), 837 disagreements (+837)
                the control is LIVE if each poison moved its own
                number: named MOVED, disagreements MOVED.
                </pre>
                </div>
                <p>The first version of this file had <strong>one</strong> poison, and it could not fail. Removing <code>m_exclusive</code> moved the named count by 61 and the disagreement count by 0 — and the sentence printed underneath the numbers claimed that both had moved and that every difference was an exclusive. Both sentences were false, and the false number was printed right beside them. That is retraction R27.</p>
                <p>So there are now three poisons, one per reported number, and <strong>each must move the number it claims to test</strong> or the run prints <code>[POISON FAILED]</code> and the harness fails. Poison B is the one worth understanding: removing <code>m_lse</code> changes <em>no</em> named counts at all and creates five <em>disagreements</em>, which is the only way to find out whether a decoder's wrong answers happen to be the same wrong answers as the second reader's. A decoder with a shared spec error does not move that number, and there is no other check in this file that would notice.</p>
                <h3>The coverage number, and the corpus it is about</h3>
                <div class="hex-dump">
                <pre>dispatch                                  read      named     coverage
  ---------------------------------------- -------- -------- ----------
  the 14 models of THIS course             1038     1031     99.3%
  the 6 the machine course adds            1038     1024     98.7%
  the 21 the encoding course imports       1038      860     82.9%
                </pre>
                </div>
                <p>Three runs, three dispatch sets, because <strong>a coverage number is a number about a corpus</strong> and not about a decoder. And the corpus itself has a lesson attached that cost the course a retraction: for most of this file's life the exclusive-<em>pair</em> path was built to a <code>.s</code> and never to an <code>.o</code>, so the two-reader pass never saw a <code>ldaxp</code> at all — and <code>m_lse</code> was free to read <code>0xc87fa009</code> as <code>caspal x31</code> for a whole draft, with a 99% coverage figure printed the entire time. <strong>A coverage number is a number about what was fed to it</strong>, and the build script now says so in a comment next to the line that was missing.</p>
            </div>

            <div class="unit unit-example">
                <h2>The retractions, grouped by what kind of mistake they are</h2>
                <p>Twenty-seven, every one with the measurement that killed it and the source that asserted it. The five kinds, and the counts are read off the list rather than written beside it — because the first version of this summary printed the literal string <code>"%d of them"</code> and a retraction list with a wrong summary is the failure the list exists to catch.</p>
                <div class="hex-dump">
                <pre>  about what an ENCODING is      14:  R1, R2, R3, R4, R5, R12, R16, R18, R19,
                                      R21, R23, R24, R25, R26
  about what a COMPARISON is      1:  R22
  about a COMPILER VERSION is     4:  R9, R11, R14, R15
  about what an INSTRUMENT is     4:  R6, R8, R17, R27
  about what a SPEC says          4:  R7, R10, R13, R20
                </pre>
                </div>
                <p>Four of the five kinds are about <em>tools</em>. That is the section's real finding across twelve courses, and it is worth stating plainly: <strong>encoding bugs are common, and tool bugs are at least as common, and the tool bugs are the ones that survive review because a tool's output looks authoritative.</strong></p>
                <h3>The seven that one change found</h3>
                <div class="hex-dump">
                <pre>  R22   "the corpus has no disagreements between the two readers"
        -&gt; it has EIGHTY-FIVE, and every one was a real decoder
           defect hidden behind a normaliser

  R23   "the scaled imm12 offset of a vector load is the access size
         in BITS"
        -&gt; BYTES: `str s0, [sp, #12]` is 0xbd000fe0 with imm12 = 3
           and 3 x 4 = 12.  Five sizes at one source offset of 4080
           give imm12 = 4080, 2040, 1020, 510 and 255

  R24   "in CCMP the NZCV immediate is the second register field"
        -&gt; it is ALL FIVE BITS of bits[4:0] and the CONDITION is
           bits[15:12]

  R25   "the lane index of the scalar element copy is `imm5 &gt;&gt; 1`"
        -&gt; imm5 = (esz/8) * (2*index + 1), and the first version was
           right for NO arrangement in the table

  R26   "the 64-bit MOVI immediate is a number the decoder can decline"
        -&gt; it is a BYTE MASK: bit j of the field is byte j of the
           value, 40 probes, 40 agreements

  R27   "removing one model from the dispatch poisons the cross-check"
        -&gt; it poisons ONE of the two numbers
                </pre>
                </div>
                <p>Read R23 and R25 together, because they are the pair worth having. R23 is off by a factor of <strong>eight</strong> — bits instead of bytes — and produced <code>[sp, #96]</code> where the byte offset is 12. R25 printed lane 6 where the lane is 1, and 6 is inside the legal range for that arrangement. <strong>Both produced a plausible number rather than an error</strong>, and a plausible number is the one thing nothing downstream can catch. That is why the second reader is necessary: not because a decoder is bad at arithmetic, but because <em>a wrong number in the legal range is invisible from the inside</em>.</p>
                <p>And R26 is the subtlest. The first version of the model <strong>declined</strong> the 64-bit MOVI form and gave a true reason about the wrong field. A decoder that declines is the safest kind of wrong — it can never print a false number — and that is exactly why it is the kind that hides: a table showing <code>reader 1: (none)</code> reads like a known gap rather than an unasked question.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Run the harness with no toolchain at all.</strong> <code>python3 courses/a64simd/assets/samples/crosscheck.py</code>. <em>(Expect 268/268 checks passed, with no assembler, no emulator and no network. It reads the committed <code>a64data.out</code> rather than re-measuring, on purpose: a course whose claims can only be verified by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them.)</em></li>
                    <li><strong>Break the check and confirm it notices.</strong> Delete one of the corpus files from <code>CORPUS_OBJECTS</code> in <code>a64data.py</code> and re-run. <em>(Expect the coverage row to change and the poison rows to still pass — and then notice that the <em>disagreement</em> count did not move, because a model whose words are simply absent from the corpus cannot disagree with anything. That is the R4 lesson from the machine course, restated for this course's own dispatch: a count of unmodelled words is a fact about a corpus.)</em></li>
                    <li><strong>Write a normaliser rule and then count how often it fires.</strong> Take the reconciliation rules in <code>_norm</code> and add one of your own. <em>(Expect it to fire zero times, and expect the zero to be invisible unless you count it. Every rule in this file is printed with the number of times it applied, and a rule that fires zero times is an error rather than a convenience — that is what the four bugs above were, and not one of them announced itself.)</em></li>
                    <li><strong>Find the claim on one of the previous four pages that is quoted, and write the sentence that would make it measured.</strong> <em>(Expect "an AArch64 board and four hours" for most of them, and expect the list to be shorter than you thought. The four pages measured everything a host without hardware can measure; the rest is a document claim and needs a document. That is the design, not a gap: it is a course about a machine you cannot run, built the way a compiler author builds one — from the encoding outward, with the specification as the oracle, the compiler as the witness, and a label on every sentence that says which of the two is speaking.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, all four. <a href="/courses/a64simd/lessons/a64-order">Acquire and Release Are Access Modes</a> contributed the largest measured content and therefore most needs this page, because a page that is mostly measurements is exactly the page a reader is most likely to over-trust. <a href="/courses/a64simd/lessons/a64-atomic">The exclusive monitor</a> contributed the retraction that made the section's method testable against itself — R21 was found by a cross-check disagreeing with an assembler, not by reading a specification.</p>
                <p>Back into the section's earlier courses. <a href="/courses/a64sys/lessons/a64-evidence">The machine course's evidence concept</a> is where the three labels and the poison come from, and <a href="/courses/a64asm/lessons/a64-verify">the encoding course's cross-check</a> is the first application of the method — it retracted its own 100% twice before this course was written. This course is the fourth application and the first to find that the poison itself was broken.</p>
                <p>Sideways, and the contrast is the point. <a href="/courses/x86sys">The x86-64 machine course</a> had hardware and had to <em>prove</em> its boundary; the neutral <code>smp</code> course had hardware and could measure a lost update. Every course in this collection that had a machine had to work harder to say what it could not conclude, because a number is available and a number looks like an answer. <strong>The AArch64 section's contribution is not that it covers an architecture; it is that it built a method for a course whose subject is unavailable, and then checked the method against itself until it produced twenty-seven retractions and three working poisons.</strong></p>
                <p>Outward, and this is where the section ends. Four courses, four subject areas, one method: registers, memory, instructions, exceptions, page tables, calls, vectors, atomics, ordering. Measured where a host can measure them, quoted where it cannot, and <strong>retracted loudly where the two disagreed</strong>. The reader who takes the habit out of here has something that transfers to a machine they <em>can</em> run, where the temptation is different — to treat a duration as a mechanism, or a coverage figure as a correctness statement, or a zero as evidence — and where the discipline costs nothing and saves a week.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64simd/lessons/a64-order">Acquire and Release Are Access Modes, Not Barriers</a></span>
                <span>End of The AArch64 Data Path: NEON, Atomics and Ordering &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
