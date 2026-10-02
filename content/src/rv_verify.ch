// RISC-V: The Encoding Spectrum -- Concept 5: the decoder, the two-reader
// cross-check, and the poisons.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_verify() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Decode It Yourself, Twice, and Poison It — Underlayer")
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
            <h1>Decode It Yourself, Twice, and Poison It</h1>
            <div class="lesson-meta">20 min &middot; <a href="/courses/rvasm">RISC-V: The Encoding Spectrum</a></div>

            <div class="unit unit-why">
                <h2>Why this concept is the last one</h2>
                <p>The other four concepts make claims. This one is about <strong>which of them you are allowed to believe</strong>, and it is last for a reason: a cross-check is the part that says which of the others are real, and putting it first would mean asking you to trust it before you know what it costs to build one.</p>
                <p>The reason it needs its own concept, rather than a paragraph at the end, is this collection&rsquo;s history. The AArch64 data-path course found its own cross-check reporting <strong>0 disagreements over a corpus where 85 instructions genuinely disagreed</strong> &mdash; and not one of the four bugs printed a wrong word. They all made the comparison <strong>VACUOUS</strong>. A wrong word is visible; a vacuous comparison is <em>believed</em>, and believing it is worse than being wrong.</p>
                <p>So this concept does four things a cross-check which agrees perfectly does not do. It prints <strong>how many</strong> instructions it compared. It prints <strong>how many times each of its 47 normalisation rules fired</strong>, because a rule that matches nothing is the exact shape of that bug. It <strong>classifies</strong> every disagreement it finds by kind. And it runs <strong>four poisons</strong>, each of which must move the number it claims to test.</p>
            </div>

            <div class="unit unit-model">
                <h2>The decoder, and what it uses no tool for</h2>
                <p>The artifact is <code>rvdec.py</code>. <strong>Part one of it imports <code>os</code>, <code>re</code>, <code>struct</code> and <code>sys</code> and nothing else</strong>, and that is a claim a reader can check by reading four lines rather than taking a promise. ELF64 section headers are read by hand with <code>struct.unpack_from</code> &mdash; <code>e_shoff</code> at 0x28, <code>e_shentsize</code>/<code>e_shnum</code>/<code>e_shstrndx</code> at 0x3a, 64 bytes per entry &mdash; and <code>.text</code> is found by NAME.</p>
                <p>The reason is not purity. <strong>A decoder that shells out to a disassembler is a disassembler with a hardcoded path in it.</strong> The reader is a dependency of the claim, not a convenience: if the decoder asked <code>llvm-objdump</code> what a word meant, the cross-check would be comparing <code>llvm-objdump</code> with itself.</p>
                <p>One more check the decoder makes, and it is not decoration. It refuses any file whose <code>e_machine</code> is not 243 (<code>EM_RISCV</code>). <strong>About a quarter of all x86-64 opcodes have <code>bits[1:0] == 0b11</code></strong>, so the length rule would step four bytes at a time through an x86-64 object and produce a stream of entirely plausible wrong lengths. Nothing in the DECODE would look wrong; the WALK would be wrong, and the walk is what every other measurement is taken against.</p>
                <h3>The declared subset, as a number</h3>
                <p>26 instruction models for the 32-bit encodings and one handler for the whole 16-bit space. <strong>The subset is a subset of NAMES</strong>, and &mdash; unlike the AArch64 course and unlike x86-64 &mdash; an unmodelled word here still has a LENGTH, because the length is a two-bit RULE and not a table. A word no model claims is printed and <strong>counted, never dropped</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/Of the 1082/,/^$/p'
    Of the 1082 instructions in the corpus:
      1047  named by a model in this file
         0  UNDEFINED by the architecture (not by this file)
         0  RESERVED compressed code points
         4  HINTs -- DEFINED, and they do nothing
        35  unmodelled: the vector data path, and a few rows
                </pre>
                </div>
                <p>Those are <strong>five DIFFERENT numbers and the cross-check depends on the distinction.</strong> An undefined encoding, a reserved encoding, a hint and an unmodelled word all print something that is not a plain mnemonic, and a two-reader check that reported the last of them as a failure would be reporting its own declared scope as a bug.</p>
            </div>

            <div class="unit unit-example">
                <h2>The cross-check, and the number it started from</h2>
                <p>Every instruction in every corpus object, decoded by this file and by <code>llvm-objdump-21 --triple=riscv64</code>, and the two canonicalised and compared:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/THE CROSS-CHECK, over every/,/^$/p'
  THE CROSS-CHECK, over every corpus object:
      1082  instructions the second reader printed
      1047  of them this file NAMES
        35  of them this file does not model (counted, not dropped)
      1047  AGREE after normalisation
         0  DISAGREE
         0  where the two readers disagree on the LENGTH alone
                </pre>
                </div>
                <p><strong>Zero disagreements, and that is exactly what a broken cross-check looks like.</strong> Which is why the four things after it exist. And the honest sentence is the one about where this came from: the first run of this file reported <strong>354 agree and 701 disagree of 1,055</strong>, and the difference between that and this is not a decoder that got better in the abstract. It is:</p>
                <ul>
                    <li><strong>116 words decoded by the wrong model.</strong> <code>r_mul</code> and <code>r_mulw</code> sit above <code>r_alu</code> and <code>r_shiftw</code> in the dispatch and <strong>neither checked funct7</strong>, so they claimed every opcode-0x33 and 0x3b word before the model that owns them was asked. <code>add</code>, <code>sub</code>, <code>sll</code>, <code>slt</code>, <code>sltu</code>, <code>xor</code>, <code>srl</code>, <code>or</code>, <code>and</code>, <code>addw</code>, <code>sllw</code>, <code>srlw</code> all reported as <code>mul</code>, <code>mulh</code>, <code>div</code>, <code>rem</code> and friends. <strong>Nothing about the output looked wrong: three plausible operands, a real register, a real instruction name.</strong></li>
                    <li><strong>62 words reported UNDEFINED for no reason at all.</strong> <code>i_alu_imm</code> raised <code>Undefined</code> for funct3 = 1 and 5, which belong to <code>i_shift_imm</code>, the model directly below it. <code>Undefined</code> STOPS the dispatch, so <code>slli</code>, <code>srli</code> and <code>srai</code> &mdash; three of the commonest instructions in the corpus &mdash; all reported as undefined by the architecture, when nothing about them was undefined.</li>
                    <li><strong>33 words of an instruction the file could not reach.</strong> <code>c.mv</code> was UNREACHABLE because the compressed CR cell was dispatched on <code>rs1 == 0</code>, which is not a bit of that cell; the bit is <code>inst[12]</code>. And the same mistake reported <code>c.jalr</code> as <code>c.jr</code>, which is a decoder that turns every indirect call into an indirect jump.</li>
                    <li><strong>91 branches that had lost both their register operands</strong>, and 26 branch targets off by exactly one because <code>inst[8]</code> was mapped into <code>imm[0]</code>. A B-type displacement is always even; a decoder that produces an odd target is producing a target no RISC-V instruction can encode, and 26 of them looked like addresses.</li>
                    <li><strong>35 words of a shift amount printed as twelve bits when the field is six</strong> (<a href="/courses/rvasm/lessons/rv-immediate">concept 4</a>), and 8 <code>fcvt</code> rows with the source and destination swapped.</li>
                    <li><strong>And a normaliser whose rules mostly matched nothing</strong> while the cross-check reported its number anyway.</li>
                </ul>
                <p><strong>701 was not one number.</strong> It was seven different things counted together, and the single verdict &mdash; &ldquo;this decoder disagrees with llvm-objdump about 67 per cent of the corpus&rdquo; &mdash; is a statement about a <em>comparison</em>, not about a decoder. The zero above is zero because the seven hundred were fixed one at a time and each fix is a numbered retraction in the artifact. <strong>Retracting a number is not the same as retracting the work: the work is the seven hundred.</strong></p>
                <h3>Why a normaliser must expand and never delete</h3>
                <p>Nearly every disagreement above was a printing convention: the reader says <code>li</code> where this file says <code>addi rd, x0, imm</code>; the reader says <code>mv</code> for a zero immediate; the reader prints the BASE mnemonic for a compressed word; the reader prints <code>0x5</code> where this file prints <code>5</code>. Reconciling them is a normaliser&rsquo;s job, and this one has <strong>47 rules</strong>.</p>
                <p>And the design decision every rule rests on is stated as a rule of the course, because getting it wrong is the bug this collection has already shipped:</p>
                <div class="hex-dump">
                <pre>  EVERY rule EXPANDS.  None of them deletes an operand.

  A normaliser that DELETES an operand makes two readers agree by
  deleting the same operand, and the agreement is then evidence
  about the normaliser rather than about either decoder.

  So `c.add a0, a1` becomes `add x10, x10, x11` and `add a0, a0, a1`
  becomes `add x10, x10, x11` -- both sides GAIN the implicit rd, and a
  decoder that read the wrong register produces a different canonical
  form and is caught.
                </pre>
                </div>
                <p>Four of the 47 rules were <strong>dead</strong> on the first run of the new normaliser, and every one of them was dead for the same reason: the pattern was anchored with <code>^mnemonic</code> and the text has a SPACE there. Forty-one rules, zero substitutions, and a cross-check that reported its number anyway. That is the AArch64 bug reproduced in a new file by a rewrite that had read the lesson and still got it wrong.</p>
                <p>The fix for reporting it is structural and it is worth copying: the counter is <strong>pre-seeded with every rule name at zero</strong>, so a rule that never fires is a ROW WITH A ZERO rather than an absence. The first version of this file created the entries lazily, which is a third instance of the same class &mdash; <strong>the reporting structure could not represent the failure it existed to report.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/rules, .* fired/p'
    47 rules, 47 fired, 0 matched nothing.
                </pre>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The four poisons</h2>
                <p>A control that cannot move the number it measures is a comment that says the word POISONED. Each of these must move its number, and a poison that does not prints <strong>[POISON FAILED]</strong> rather than a verdict.</p>
                <h3>Poison 1 &mdash; remove a model, and watch the agreement move</h3>
                <p>The control is the sharpest of the four, because <strong>the first version of it could not move its own number, and diagnosing why is the most useful thing on this page.</strong> It picked its victim by counting each model&rsquo;s footprint with that model <em>alone</em> in the dispatch table. That measures what the model&rsquo;s guards <em>would</em> claim if nothing above it got there first &mdash; and it is the wrong quantity, because a model is only responsible for the words the dispatch actually gives it:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/The dispatch, as CONFIGURED/,/^$/p'
    The dispatch, as CONFIGURED, attributes the corpus like this.
      rvc             284 named words
      i_alu_imm       188 named words
      i_jalr          101 named words
      b_branch         91 named words
      r_alu            88 named words
      i_load           81 named words
      ...
    i_alu_imm names 472 words ALONE and 188 in the dispatch.
                </pre>
                </div>
                <p>The gap is the compressed extension: 284 of the 1,082 instructions are two bytes and are decoded by the 16-bit handler, which is not in that table at all. So the model that names the most words <em>alone</em> is not the model that owns the most words, and a poison that picks its victim by the wrong number picks a model whose words are somebody else&rsquo;s, removes it, watches nothing move, and reports [POISON FAILED] &mdash; <strong>which is the correct verdict about a control that cannot move and the wrong verdict about this decoder.</strong></p>
                <p>So the victims are now chosen <strong>from the data, by in-dispatch ownership</strong>, and there are three of them rather than one:</p>
                <div class="hex-dump">
                <pre>    VICTIM i_alu_imm      owns 188 corpus words in the dispatch
      BEFORE the poison: 1047 agree, 0 disagree, of 1047 named
      AFTER  the poison: 859 agree, 159 disagree, of 1018 named
      and again, with the model restored:  1047 agree, 0 disagree

    VERDICT: POISON 1 FIRED on all 3 victims.
             deltas: i_alu_imm=188, r_shiftw=6, i_fp_ldst=1
                </pre>
                </div>
                <p>And the 159 is the interesting part: removing <code>i_alu_imm</code> does not make its words <em>unmodelled</em>, it makes them fall through to a <strong>different model that decodes them wrongly</strong>. The delta equals the victim&rsquo;s own footprint exactly, which is what makes it evidence rather than a coincidence &mdash; a model that owns N words and a control that moves N numbers are not two pieces of evidence, they are one number counted twice, and their agreeing is what makes the number mean something.</p>
                <h3>Poison 2 &mdash; flip a bit, and watch the format table move</h3>
                <p>Bit 12, which is the sign bit of every base immediate, the compressed extension&rsquo;s sign bit, and the high bit of a U-type immediate. One flip moves words between formats <em>and</em> changes immediate signs, and a classifier that is not reading the bits cannot survive it. <strong>Total movement: 326 instructions changed format, across 3 format values</strong>, and the same flip takes the cross-check from 1,047 agreements to 1 &mdash; which is the expected result: the words are no longer what the assembler emitted.</p>
                <h3>Poison 3 &mdash; replace the length rule with a guess</h3>
                <p>&ldquo;Four if the offset is a multiple of four, else two&rdquo; &mdash; wrong for every 2-byte instruction that happens to sit at a 4-aligned offset, and there are many. <strong>1,082 instructions become 939.</strong> The guess found FEWER, which is exactly what a desynchronised walk does: it steps four bytes over a two-byte instruction and loses the one in between. <strong>The length rule is load-bearing, the counts in concepts 1 and 2 are real, and a decoder that guesses lengths gets a plausible smaller number.</strong></p>
                <h3>Poison 4 &mdash; plant a real disagreement, then hide it</h3>
                <p>This one is the fourth because it poisons the CHECK rather than the decoder, and a decoder bug is found by reading the output while a check bug is found only by trying to break the check. <strong>The first version of it got the argument backwards</strong>, and the way it got it backwards is worth more than the poison:</p>
                <div class="hex-dump">
                <pre>    STEP 1.  One operand of every `addi` in the corpus is changed
    to x0 -- a real decode difference, planted on purpose, in the
    TEXT the cross-check compares and nowhere else:
      the cross-check with the bug planted: 879 agree, 168 disagree

    CAUGHT.  The check compares operands.

    STEP 2.  The same bug, AND the AArch64 bug: a normaliser rule
    that DELETES the last operand:
      the cross-check with BOTH:  926 agree, 121 disagree

    DELTA: 47 of the 168 planted disagreements DISAPPEARED when the
    normaliser was given the rule that deletes an operand.  That
    is the AArch64 failure reproduced on purpose and MEASURED.
                </pre>
                </div>
                <p>The first version broke the normaliser and asserted the agreement count would then go <em>up</em>. It did not move, and the poison printed [POISON FAILED]. <strong>The [POISON FAILED] was CORRECT and the ASSERTION was wrong:</strong> you cannot raise an agreement count that is already at 100 per cent, because there is nothing left to agree about. The poison was asking the number to move in a direction that was not available to it. The corrected version plants a real disagreement first, so there is something for the bug to hide &mdash; and then shows that <strong>47 of 168 real disagreements vanish</strong> under the AArch64 rule.</p>
                <p>One more trap in writing this poison, and it is the easiest to repeat: <strong>a normaliser is a function of one string, and the first version corrupted it from inside the normaliser</strong> &mdash; which runs on BOTH sides. So it corrupted the reader&rsquo;s text as well as this file&rsquo;s, the two corrupted identically, and the cross-check reported 1,047 agreements with a real disagreement planted in the middle of them. The fix is to corrupt where only one side&rsquo;s text exists.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break a guard and watch the count move.</strong> <em>(In <code>rvdec.py</code>, delete the <code>if bits(i.word, 31, 25) != 0x01: raise Bad()</code> from <code>r_mul</code> and re-run. Expect the section 10 agreement count to fall by roughly 116 and the poison-1 delta for <code>i_alu_imm</code> to change. Then <strong>put it back</strong> and confirm the count returns &mdash; a decoder change you cannot undo is not an experiment.)</em></li>
                    <li><strong>Make one normalisation rule dead and watch the count go UP.</strong> <em>(Take the <code>^mv\s+(\w+),(\w+)$</code> rule and delete the <code>\s+</code>, so the pattern is <code>^mv(\w+),(\w+)$</code> again. Expect the agreement count to fall by 108, and expect the fire table to show <code>mv alias</code> at <strong>zero</strong> rather than absent &mdash; which is the whole reason the counter is pre-seeded. A reader who saw only a fire table that listed what fired would not know the rule was there.)</em></li>
                    <li><strong>Re-run the harness and read what it does NOT check.</strong> <em>(<code>python3 crosscheck.py rvdec.out</code> &mdash; 128 checks, and every one of them re-asks a claim in the recorded output rather than re-measuring it. Note what it asserts as a <em>shape</em> rather than a value: the <code>-march</code> comparison is asserted as &ldquo;rv64i GAINS three and LOSES four&rdquo; rather than as counts, because a count there moves with the compiler and a shape does not. <strong>A check whose threshold is a bare number is a check that fails on a busier machine and teaches its reader to ignore it.</strong>)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, this concept is the check on all four. <a href="/courses/rvasm/lessons/rv-encoding">Concept 2</a>&rsquo;s three-bit <code>rd'</code> trap &mdash; every register seven too small, nothing malformed &mdash; is findable by exactly one of these mechanisms, because it is a bug in the <em>decoding</em> and both readers would have to be wrong in the same way to hide it.</p>
                <p>Across, the same shape appears in <a href="/courses/a64asm/lessons/a64-verify">a64-verify</a> and in <a href="/courses/exe/lessons/exe-verify">exe-verify</a>, and the vocabulary is deliberately identical across all three: a poison, a delta, a <code>[POISON FAILED]</code>. A reader who has learned what a poisoned control is can read the verification section of any course in this collection, and the vocabulary being shared is the point.</p>
                <p>And the limitation belongs here rather than at the end, because it bounds everything above. <strong>The two readers share an assembler.</strong> <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it, so both ultimately depend on one LLVM tree. An independent second <em>assembler</em> does not exist on this host. What this concept establishes is that this decoder and one other piece of software agree on what the bytes mean &mdash; <strong>not that either agrees with silicon, and there is no silicon here to agree with.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvasm/lessons/rv-immediate">The Immediates That Do Not Fit</a></span>
                <span><a href="/courses/rvasm">Back to the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
