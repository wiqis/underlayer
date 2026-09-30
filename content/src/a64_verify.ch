// AArch64: Encoding From The Ground Up -- Concept 5: the cross-check, and the
// poison.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Two Readers, and Then One of Them Poisoned — Underlayer")
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
            <h1>Two Readers, and Then One of Them Poisoned</h1>
            <div class="lesson-meta">22 min &middot; <a href="/courses/a64asm">AArch64: Encoding From The Ground Up</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The four concepts before this one made a lot of claims. Some of them were wrong &mdash; <a href="/courses/a64asm/lessons/a64-cond">the class field was two bits</a>, <a href="/courses/a64asm/lessons/a64-immediate">the 64-bit all-ones was encodable</a>, <a href="/courses/a64asm/lessons/a64-cond">the <code>op2</code> cells were SET forms</a> &mdash; and being wrong about a bit pattern is the <em>cheap</em> kind of wrong, because a wrong bit pattern is visibly wrong to anyone who checks it.</p>
                <p>The expensive kind is the one this concept is about. <strong>Claim R15 in this course's own artifact says that the logical-immediate model was printing <code>sp</code> where the encoding says the zero register</strong> &mdash; and the word that a reader would check is a word that does not exist in the instruction. The decoder produced a <em>plausible instruction</em>. Nothing crashed, nothing warned, and the output looked like a disassembly.</p>
                <p>That class of bug cannot be found by reading your own code twice. It is found by a second reader that was not written by the same hand, and &mdash; this is the part that is easy to skip and that this course insists on &mdash; <strong>the second reader is found by poisoning the first.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>Two readers, and what they agree on</h2>
                <p>Every instruction in the corpus is decoded twice: once by the model chain, once by <code>llvm-objdump-21 --triple=aarch64</code>. Both are the same kind of thing and the two were not written by the same person.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=12 | sed -n '/object files/,/agreement/p'
  5 object files, 868 instructions, 859 named by this decoder,
  9 left unmodelled and counted.

    the two readers agree on:   859
    the two readers disagree:    0
    agreement:                   100.0000% of named instructions
                </pre>
                </div>
                <p>Three things to take from those five lines.</p>
                <ul>
                    <li><strong>868 instructions, of which this decoder names 859.</strong> The other 9 are Advanced SIMD, out of the declared subset, and they are <em>counted</em> rather than dropped. The agreement figure is over the 859 &mdash; <strong>named</strong>, not total &mdash; and a cross-check that quietly excluded unmodelled words and reported the exclusion nowhere would be claiming a number about a smaller set than it appeared to.</li>
                    <li><strong>0 disagreements.</strong> Which is correct and which is also exactly what a broken cross-check looks like, and the rest of this page is about the difference.</li>
                    <li><strong>100.0000%</strong> is printed with four decimals because the precision is the point: a number printed to two places would have been 100% with room to hide a disagreement in the rounding.</li>
                </ul>
                <h3>The seven normalisations, and why each one exists</h3>
                <p>The two readers agree on the <em>word</em> and rarely agree on the <em>string</em>, and every reason is a printing decision rather than a decoding decision. All seven are listed in the artifact because <strong>a cross-check that quietly normalises away a real disagreement is worse than no cross-check</strong> &mdash; you cannot tell which of your normalisations is hiding a bug unless you can see all of them.</p>
                <ol>
                    <li>A trailing <code>// =1234</code> comment, which is the disassembler doing arithmetic a byte-level decoder does not do.</li>
                    <li>A tab between mnemonic and operands, and a space after every comma.</li>
                    <li>A symbol annotation <code>// &lt;sym&gt;</code> and a resolved address after a branch, an <code>adr</code> or an <code>adrp</code>. <strong>In a relocatable object that number is a placeholder</strong> and the real value is in an <code>R_AARCH64_*</code> relocation, so both sides are compared as <code>TARGET</code> and the displacement arithmetic is checked by hand in section 11 instead. A placeholder that both readers print identically is not a cross-check of anything.</li>
                    <li>Small immediates printed in decimal by one reader and in hex by the other, so every immediate is folded to one form.</li>
                    <li>A zero offset, which the disassembler prints as a <em>pronoun</em> &mdash; <code>[x1]</code> for <code>[x1, #0]</code> &mdash; and which this decoder always prints, because a decoder that omits a field it read is a decoder whose output cannot be audited.</li>
                    <li><code>add x0, x1, #0x1000</code> against <code>add x0, x1, #0x1, lsl #12</code>, which concept 1 measured to be the same 32 bits, folded onto the value. And told to by a <em>register</em> shift &mdash; <code>add x0, x0, x0, lsl #48</code> &mdash; which looks identical and is not, so the fold applies only where a <code>#</code> precedes the shift.</li>
                    <li><strong>The sign of an immediate, which three printers disagree about.</strong> MOVN prints the register's value (the field's complement); a logical immediate that became a MOV alias prints signed; MOVZ prints unsigned. So every <code>#-0x...</code> is folded onto the unsigned value at the register width.</li>
                </ol>
                <p>Rule 7 is nine of the eleven failures described below, and rule 3 is the one that would have been a lie: comparing a relocation placeholder is not a weaker check, it is <em>no</em> check, and the file says so rather than printing a green tick for it.</p>
                <h3>98.72%, and why that was the most useful output in the file</h3>
                <p>The first run of this comparison reported 848 of 859. The eleven failures were the most valuable lines the artifact ever printed, and they were of <strong>two different kinds</strong>:</p>
                <ul>
                    <li><strong>Two were a real bug in the decoder.</strong> The logical-immediate model called the register-name function with its default permission, so register 31 printed as <code>sp</code> where the encoding says the zero register. <code>orr x9, sp, #0x8000000000000001</code> for a word the disassembler calls <code>mov x9, #-0x7fffffffffffffff</code>. That is not a naming difference: <strong>a logical OR against the stack pointer is a different VALUE from a logical OR against zero.</strong> The decoder wrote down a register that does not exist in that instruction. (A flag with a default is a flag nobody checks. R15.)</li>
                    <li><strong>Nine were a normalisation rule that had been matching nothing.</strong> The MOVN fold was written as <code>^movn([\w,]*),#...</code> and <code>[\w,]*</code> does not match the space between a mnemonic and its operands. <strong>It matched nothing, silently, and the cross-check carried on running and printed its number.</strong> A rewrite that matches nothing is the kind of bug a check cannot report, because a check that reports 11 failures and a check that reports 100% both look like working software.</li>
                </ul>
                <p>So the general form, which is the whole argument of this concept: <strong>100% is what a check that has been normalised until it cannot fail looks like</strong>, and so is a check whose normalisation was quietly broken. The only way to tell the two apart is to look at what the failures <em>were</em>, which is why the history is printed rather than fixed in silence.</p>
                <h3>And a rule 6 that was green while being wrong</h3>
                <p>Worth one paragraph on its own, because it is the purest example in the collection. Rule 6 folds <code>,lsl#12</code> into the preceding value, and the first version applied it to <em>every</em> <code>,lsl#N</code> &mdash; including register shifts. One branch of that fold turned a <strong>register name</strong> into a number, so:</p>
                <div class="hex-dump">
                <pre>    add x0, x0, x0, lsl #48      cross-checked as   add x0, x0, #0x3000000

  The cross-check ran, reported 100% agreement, and was comparing
  a REGISTER against a CONSTANT.
                </pre>
                    <h3>The poison: the control that cannot fail is not a control</h3>
                <p>Agreement to 100% is what a broken cross-check looks like, so the model table is then broken on purpose, the same bytes go through the same loop, and the number is read again.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=12 | sed -n '/largest model/,/control doing its job/p'
  The largest model in the corpus is m_ldst_uimm, and it alone claims 142
  words.  A representative word it claims is 0xb9400820, which is
  `ldr	w0, [x1, #0x8]` -- asked of the oracle, not of this file.

    with the table intact:              ldr      w0, [x1, #8]
    with m_ldst_uimm poisoned:     (op 0xb9400820)  Loads and Stores

    the cross-check BEFORE the poison: 859 agree, 0 disagree, of 859
    the cross-check AFTER  the poison: 717 agree, 0 disagree, of 717

    VERDICT: the number MOVED, by 142 instructions, which is the
    control doing its job.  The unpoisoned agreement was read off
    this decoder and not off something else.
                </pre>
                </div>
                <p>Read the two numbers, because the arithmetic is the evidence. The poison removed one model, so 142 words stopped being named; 859 &minus; 142 = 717, and 717 &minus; 717 = 0. <strong>The cross-check did not disagree about anything &mdash; it agreed about strictly fewer things, and exactly the things the poison touched.</strong> That is the shape a real bug has. A broken <em>loop</em> moves everything or nothing; a real corruption moves a localisable set.</p>
                <p>And the first version of the poison was a <strong>no-op</strong>, which is the most instructive failure in this section. It prepended a model that claims nothing instead of <em>removing</em> one, so the victim was still in the list and still claimed every word it had claimed before. The number was 859 before and 859 after, and the line above it said the word POISONED. <strong>A control that cannot move the number it is measuring is not a control &mdash; it is a comment that says the word POISONED.</strong></p>
                <h3>What the two readers share, which is a real weakness</h3>
                <p>Both readers ultimately come from one LLVM tree, because <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it. <strong>An independent second assembler does not exist on this host and GNU binutils has no AArch64 target installed.</strong> So the cross-check establishes that this decoder and one other piece of software agree on what the bytes mean &mdash; not that either agrees with silicon. Section 15 of the artifact says so again in its own words, and the landing page's limits block says it a third time. Three times is not redundancy; it is the number of places a reader is likely to stop reading.</p>
                <p>There is one more limitation with a name, and it cost this course a whole afternoon: <strong><code>llvm-objdump</code> in this collection has no <code>-b binary</code> option.</strong> <code>--triple=aarch64 -D -b binary f</code> prints <code>error: unknown argument '-b'</code>. The ISA course's harness uses GNU objdump, which does have it, so the technique worked there and does not work here. Every single-word probe in this artifact is therefore assembled into a real object file and asked about in a section the disassembler already knows how to read. A cross-check that quietly substituted a different disassembler for the convenience of a script would have been a claim about a tool that is not installed.</p>
            </div>

            </div>

            <div class="unit unit-reality">
                <h2>Three things that are cheaper to state than to prove</h2>
                <p>Each was asserted in a draft of this course. Each was measured. Each was retracted in public, and the history is printed by the artifact rather than fixed in silence.</p>
                <ul>
                    <li><strong>98.72% was the most useful output in the file.</strong> The eleven disagreements were two real decoder bugs and nine failures of a normalisation rule that had been matching nothing. A check that reports eleven and a check that reports 100% both look like working software; <strong>the difference is a list you can read and a tick you cannot.</strong></li>
                    <li><strong>100% is what a broken cross-check looks like, so the control has to be able to fail.</strong> The first poison prepended a no-op model instead of removing one, the number did not move, and the line above it said POISONED. A control that cannot move the number it is measuring is a comment that says the word POISONED.</li>
                    <li><strong>Both readers come from one LLVM tree.</strong> <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it, GNU binutils has no AArch64 target installed, and there is no second assembler on this host. The cross-check establishes that two programs agree about the bytes &mdash; <em>not</em> that either agrees with the silicon. This is said in three places, which is not redundancy: it is the number of places a reader stops reading.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the harness</h2>
                <p><code>crosscheck.py</code> reads the recorded output and re-asks the claims. It does not re-measure anything: it has no assembler, no object files and no decoder of its own, and that is deliberate. <strong>A harness that can re-measure can disagree with the artifact for reasons that have nothing to do with whether the artifact's sentences are still true</strong>, and then it teaches its reader to ignore it.</p>
                <p>So the split is this. <code>a64dec.py</code> runs the toolchain and produces numbers. <code>crosscheck.py</code> reads the numbers and asserts what must be true of them. A compiler upgrade changes the numbers and the harness notices; a prose edit that drops a retraction changes the text and the harness notices. <strong>Neither can hide.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 crosscheck.py courses/a64asm/assets/samples/a64dec.out
  ... 243 checks in 15 groups
  ========================================================================
  all 243 checks passed
  ========================================================================
                </pre>
                </div>
                <p>Almost everything the artifact prints is <em>exact</em> &mdash; bit patterns, counts, assembler refusals, the reach of a signed displacement field &mdash; so the harness asserts those as exact numbers, and it is not being clever, it is the only honest thing to do with an exact quantity. Three things are worth reading about the harness itself:</p>
                <ul>
                    <li><strong>It asserts all seventeen retractions as text.</strong> A course that quietly dropped one would pass every other check in the file, because the retraction <em>is</em> a claim about a number that is otherwise fine. Presence is asserted, in order, R1 to R17 with no gap.</li>
                    <li><strong>It asserts the density comparison as a SHAPE, not a value.</strong> The four ratios come from one compiler version and a compiler upgrade moves them, so the harness asserts that <em>the sign changes between -O0 and -O1</em> &mdash; which is the finding &mdash; and not what any of the four numbers is. <strong>A check whose threshold is a bare number is a check that fails on a busier machine and teaches its reader to ignore it.</strong></li>
                    <li><strong>It asserts that the poison moved the number.</strong> A harness that only ever reads the 100% is the harness this course retracted in R14 and R17, and a harness that has retracted something should not commit the same mistake in its own code.</li>
                </ul>
                <p>And the reason the harness ships the recorded run: <strong>a course whose claims can only be verified by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them</strong> &mdash; which is the same mistake as quoting a remembered number, wearing a different hat. <code>a64dec.out</code>, <code>fields.txt</code>, <code>run1.txt</code> and <code>run2.txt</code> are all committed, and the two runs are byte-identical.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Break a guard by one bit and watch the poisoned number move.</strong> This is the manifest's completion criterion. In <code>a64dec.py</code>, in <code>m_logical_imm</code>, change <code>reg(rn, sf, allow_sp=False, allow_zr=True)</code> to <code>reg(rn, sf)</code> &mdash; the exact mistake R15 records. <em>(Expect the cross-check to report 2 disagreements, both of the form <code>orr x9, sp, #...</code> against <code>mov x9, #...</code>, and expect the poison verdict to stay green because the poison moved by the same 142 either way. Then change the poison itself: replace the victim replacement with a prepend, and expect the verdict line to read DID NOT MOVE. You have now broken the cross-check and the control in the two ways that matter, and the second one is the one that would have shipped.)</em></li>
                    <li><strong>Break a normalisation rule and notice what you cannot see.</strong> In <code>normalise_objdump</code>, change the MOVN rule's class from <code>[\w,\s]</code> back to <code>[\w,]</code>. <em>(Expect the cross-check to report 0 disagreements, because the broken rule matches nothing and the artifacts both fall through to the same normalisation &mdash; and expect section 12 to keep printing 100.0000%. You have just reproduced the nine failures of the first run, and nothing in the output will tell you. That is why the rules are listed rather than trusted, and why R17 exists.)</em></li>
                    <li><strong>Count the disagreements your own cross-check would miss.</strong> Take the 9 unmodelled words in the corpus and ask what happens to each of them in your pipeline. <em>(Expect nothing to happen: they are counted, they are outside the declared subset, and the agreement figure is over the 859 named ones rather than the 868 total. Now subtract them instead and report 859/859 as 100% &mdash; and notice that a reader of that sentence has been told a different thing from a reader of the real one. The distinction between &ldquo;agrees on everything it models&rdquo; and &ldquo;agrees on everything&rdquo; is four numbers long and it is the whole difference.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, all four concepts, and specifically <a href="/courses/a64asm/lessons/a64-cond">concept 4</a>: the <code>cset</code> inversion produces output that is 0 or 1 either way, and this is the only instrument in the collection that finds it. <a href="/courses/a64asm/lessons/a64-encoding">Concept 2</a> is where the register-31 mistake lived and where the field map that made it visible is measured.</p>
                <p>Outward, and the models here are the ones the rest of this collection is built on. <a href="/courses/x86asm/lessons/x86-map">The x86-64 map audit</a> is the same experiment on a variable-length encoding &mdash; 768 opcode slots read twice, with and without a prefix &mdash; and it has the same structure: a table, a second reader, and a control. <a href="/courses/isa/lessons/isa-decode">The ISA course's decoder</a> is the ancestor of this artifact's, and the difference in their declared subsets is the difference between a subset of lengths and a subset of names. <a href="/courses/exe/lessons/exe-verify">The execution course's harness</a> and <a href="/courses/priv/lessons/priv-harness">the privilege course's</a> are the other two verification models this one is a fourth instance of, and all three were written by a hand that had already broken a harness.</p>
                <p>Forward, and this course ends here &mdash; the next link in the chain is not another AArch64 concept. <strong>Everything on the previous four pages is checkable with a hex editor, which is the design: a bit pattern, a count of bit patterns, an arithmetic identity, and a refusal from a real assembler do not go stale when a compiler changes and do not need a machine to verify.</strong> The parts of the chain that need silicon &mdash; whether a select is cheaper than a branch, whether a load hits, whether a bitfield is one instruction or two &mdash; are somebody else's course, and this one says in section 15 exactly which ones they are.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64asm/lessons/a64-cond">Sixteen Conditions, Four Bits, and the Inversion That Hides</a></span>
                <span>End of AArch64: Encoding From The Ground Up &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
