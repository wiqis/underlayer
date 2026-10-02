// AArch64: Encoding From The Ground Up -- Concept 4: the condition codes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_cond() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sixteen Conditions, Four Bits, and the Inversion That Hides — Underlayer")
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
            <h1>Sixteen Conditions, Four Bits, and the Inversion That Hides</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/a64asm">AArch64: Encoding From The Ground Up</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>On x86-64, producing a boolean from a comparison takes a compare, a <code>SETcc</code>, and usually a widening move. On AArch64 it takes <strong>one instruction</strong>: <code>csel w0, w1, w2, eq</code> reads the flags <code>subs</code> wrote and writes one of two registers. There is no branch, no branch-delay slot, and no separate compare. That is the whole argument for the conditional-select group, and it is why a compiler that reaches for it turns a four-instruction sequence into one.</p>
                <p>The reason this gets its own concept rather than a paragraph is that <strong>the encoding has a trap in it that produces correct-looking output when you get it wrong</strong>, and the trap is the kind that survives review: a decoder that models <code>cset</code> as &ldquo;a <code>csinc</code> with both sources zeroed&rdquo; reports every condition in the program <em>inverted</em>, and the result is 0 or 1 either way. Nothing about the output says you are wrong.</p>
            </div>

            <div class="unit unit-model">
                <h2>The condition is four bits, and here are all sixteen</h2>
                <p>Sixteen conditions in a four-bit field, and the table below is built by assembling one <code>csel</code> per value rather than by quoting a list of names:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=10 | sed -n '/10A\./,/Two names exist/p'
  value  bits    name    word        decoded here
  0      0000    eq      1a820020    csel     w0, w1, w2, eq
  1      0001    ne      1a821020    csel     w0, w1, w2, ne
  2      0010    cs      1a822020    csel     w0, w1, w2, cs
  3      0011    cc      1a823020    csel     w0, w1, w2, cc
  4      0100    mi      1a824020    csel     w0, w1, w2, mi
  5      0101    pl      1a825020    csel     w0, w1, w2, pl
  6      0110    vs      1a826020    csel     w0, w1, w2, vs
  7      0111    vc      1a827020    csel     w0, w1, w2, vc
  8      1000    hi      1a828020    csel     w0, w1, w2, hi
  9      1001    ls      1a829020    csel     w0, w1, w2, ls
  10     1010    ge      1a82a020    csel     w0, w1, w2, ge
  11     1011    lt      1a82b020    csel     w0, w1, w2, lt
  12     1100    gt      1a82c020    csel     w0, w1, w2, gt
  13     1101    le      1a82d020    csel     w0, w1, w2, le
  14     1110    al      1a82e020    csel     w0, w1, w2, al
  15     1111    nv      1a82f020    csel     w0, w1, w2, nv
                </pre>
                </div>
                <p>One structural fact is visible in the fourth column and worth stating because it is the cheapest possible way to check the field position: <strong>the sixteen words are identical except for the nibble at bits[15:12].</strong> Everything else &mdash; the destination at bits[4:0], the first source at bits[9:5], the second at bits[20:16], the whole opcode &mdash; is held constant across all sixteen rows. The condition is four bits in the middle of the word and that is the entire claim, and the harness asserts it as a bit pattern rather than as a sentence.</p>
                <p>And there is a naming wrinkle that is a fact about the ISA and a nuisance for a cross-check. <strong>Values 2 and 3 have two names each.</strong> In a select the assembler calls them <code>hs</code> and <code>lo</code>; in a branch it calls them <code>cs</code> and <code>cc</code>. Both were measured: <code>csel w0, w1, w2, cs</code> assembles to <code>0x1a822020</code> and the disassembler calls it <code>hs</code>, while <code>b.cs T</code> assembles to <code>0x54000020</code> and the disassembler calls it <code>cs</code>. <strong>The same four bits, two names, and the printer picks by position.</strong> This page uses the select spelling throughout and <a href="/courses/a64asm/lessons/a64-verify">concept 5</a> normalises the other one &mdash; and says that it does, which is the rule for every normalisation in that section.</p>
                <h3>The 4x4 table, and why <code>op2</code> is not the operation</h3>
                <p>The conditional-select group has more than one field selecting the operation, and getting the relationship wrong is the first thing that goes. Here is the whole table, built as <strong>words</strong> and then asked about:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=10 | sed -n '/bit30 (invert)/,/SAME/p'
  bit30 (invert)  bits[11:10]  word        the oracle calls it       this decoder calls it
  0              00           1a800022    csel    w2, w1, w0, eq    csel    w2, w1, w0, eq
  0              01           1a800422    csinc   w2, w1, w0, eq    csinc   w2, w1, w0, eq
  0              10           1a800822    (blank)                   (undefined)
  0              11           1a800c22    (blank)                   (undefined)
  1              00           5a800022    csinv   w2, w1, w0, eq    csinv   w2, w1, w0, eq
  1              01           5a800422    csneg   w2, w1, w0, eq    csneg   w2, w1, w0, eq
  1              10           5a800822    (blank)                   (undefined)
  1              11           5a800c22    (blank)                   (undefined)
                </pre>
                </div>
                <p>Two facts, and the first one corrects a very natural assumption.</p>
                <p><strong>There are four operations, not sixteen and not eight:</strong> <code>csel</code>, <code>csinc</code>, <code>csinv</code> and <code>csneg</code>, selected by the <em>pair</em> (bit 30, bits[11:10]) = (0,00), (0,01), (1,00) and (1,01). The first version of this decoder read bits[11:10] as the operation and got <code>csinv</code> and <code>csneg</code> wrong in the corpus &mdash; and those two disagreements were in the two instructions the branchless-csel discussion quotes, which is the worst possible place for a bug to land.</p>
                <p><strong>The other four cells of the 4x4 are UNDEFINED.</strong> The oracle prints <code>&lt;unknown&gt;</code> for all four and this decoder raises on all four. The first draft of the file's own comment called two of them &ldquo;the SET forms&rdquo;, which is a plausible-sounding wrong answer that would have taught a reader the group has six operations. (The second version of that table was wrong in a different instructive way: it <em>assembled</em> a line per cell, and since there is no mnemonic for <code>(invert, op2) = (1, 0)</code> the assembler silently produced a <code>csinv</code> for all four of the <code>inv = 1</code> rows and the table printed <code>csinv</code> eight times. <strong>Building the cells as words is the only way a cell with no name can still be measured.</strong>)</p>
                <h3>And the SET forms are not new opcodes</h3>
                <p>Here is where the trap lives, and the table below is the evidence:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=10 | sed -n '/cset w0, eq  /,/cneg w0, w1, ge/p'
    cset w0, eq              1a9f17e0   csinc w0, wzr, wzr, ne   1a9f17e0   SAME
    cset w0, ne              1a9f07e0   csinc w0, wzr, wzr, eq   1a9f07e0   SAME
    csetm w0, eq             5a9f13e0   csinv w0, wzr, wzr, ne   5a9f13e0   SAME
    csetm x0, ne             da9f03e0   csinv x0, xzr, xzr, eq   da9f03e0   SAME
    cinc w0, w1, eq          1a811420   csinc w0, w1, w1, ne     1a811420   SAME
    cinc w1, w2, eq          1a821441   csinc w1, w2, w2, ne     1a821441   SAME
    cneg w0, w1, ge          5a81b420   csneg w0, w1, w1, lt     5a81b420   SAME
    csinc w0, wzr, wzr, al   1a9fe7e0   cset w0, eq              1a9f17e0   DIFFERENT
    csinc w0, wzr, wzr, ne   1a9f17e0   cset w0, eq              1a9f17e0   SAME
    csinc w0, wzr, wzr, nv   1a9ff7e0   cset w0, eq              1a9f17e0   DIFFERENT
    csinv w0, wzr, wzr, al   5a9fe3e0   csetm w0, eq             5a9f13e0   DIFFERENT
                </pre>
                </div>
                <p>Read the first row and then the eighth. <code>cset w0, eq</code> is <code>csinc w0, wzr, wzr, <strong>ne</strong></code> &mdash; <strong>the condition is inverted</strong>, and the two are different 32 bits that differ in the condition field and nowhere else. And the assembly text of <code>csinc w0, wzr, wzr, al</code>, which is the ninth row, is <code>cset w0, <strong>ne</strong></code>: a different word again.</p>
                <p>Why the inversion, in one sentence: <strong>&ldquo;1 if the condition holds, else 0&rdquo; is &ldquo;0 + 0 if it does not hold, else 0 + 1&rdquo;</strong>. Both sources are the zero register, so the <em>sum</em> is the constant, and the constant is 1 in the case where the condition is false. The assembler prints the user's condition and the encoding holds its negation, and both are right about what the instruction does.</p>
                <p>So the shape of the bug is worth stating exactly, because it is the general form:</p>
                <ul>
                    <li>A decoder that models <code>cset</code> as &ldquo;a <code>csinc</code> with Rn = Rm = 31&rdquo; reports <strong>every condition in the program inverted</strong>.</li>
                    <li>The output is 0 or 1 either way, so <strong>nothing about it looks wrong</strong>.</li>
                    <li>No cross-check against <em>yourself</em> finds it, because you would make the same assumption twice. <a href="/courses/a64asm/lessons/a64-verify">Concept 5</a> exists because of this shape specifically.</li>
                </ul>
                <p>And note what a field map cannot show you. <code>CSET</code> reuses the same two field values as <code>CSINC</code>; what is different is that <strong>Rn and Rm are 31, and 31 means the zero register in this group</strong>. Four opcodes plus two register values give a sixth and a seventh instruction, and there is no bit anywhere that says &ldquo;this is a set&rdquo;. That is why the 4x4 table has no <code>cset</code> row and why the model in the artifact has to read the registers to name it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>NZCV, and what a user-mode program cannot do with it</h2>
                <p>Every condition is a function of four flag bits &mdash; Negative, Zero, Carry, Overflow. They are written by the <code>S</code>-suffixed instructions (<code>adds</code>, <code>subs</code>, <code>ands</code>, <code>bics</code>) and by nothing else a user-mode program can reach. There is no <code>PUSHFLAGS</code>, no <code>LAHF</code>, no <code>mov rflags, rax</code>.</p>
                <p><strong>The four bits are written by an operation and read by the next one, and the whole conditional group is one instruction wide from the write to the read.</strong> That is the structural reason <code>csel</code> is one instruction rather than two, and it is also the thing a user-mode program cannot inspect: you cannot read NZCV without consuming an operation's result, and there is no instruction whose sole effect is to put a value in those bits.</p>
                <p>What <strong>cannot</strong> be measured here, and is not claimed anywhere in this course: the latency of the flag write, whether a particular core renames the flags, and whether a select is cheaper than a branch on a branch-free predictor. Those need an AArch64 machine and there is none on the build host. The artifact says so in section 15 in its own words rather than leaving it to a reader's discretion, and the landing page's limits block says it a second time.</p>
            </div>

            <div class="unit unit-model">
                <h2>The same four bits, five of them, in a branch</h2>
                <p>And a <code>B.cond</code> is <code>bits[31:24] = 0b01010100</code>, <code>imm19</code> at bits[23:5], and the condition at <strong>bits[4:0]</strong>:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=10 | sed -n '/10C\./,/A B.cond is/p'
  value  bits    name    word        decoded here
  0      0000    eq      54ffffc0    b.eq     -8
  14     1110    al      54ffffce    b.al     -8
  15     1111    nv      54ffffcf    b.nv     -8
                </pre>
                </div>
                <p><strong>The same four bits are at position 4 here and at position 12 in a <code>csel</code>, and the two fields do not overlap.</strong> A decoder that finds one <code>cond</code> field and uses it for both gets every conditional instruction in the program wrong, in the same direction &mdash; and in this case the error is visible in the output, because <code>b.eq</code> and <code>b.ne</code> are different branches and a program that takes the wrong one misbehaves. That is the good case. The <code>cset</code> case above is the bad one, and it is the one that got its own concept's warning.</p>
                <p>AArch64 does not have a single condition field. That is a cost of the encoding rather than an accident: <strong>two different places, two different widths, one meaning</strong>. Concept 2's field table shows both positions side by side, and this is what the two non-contiguous rows in it are about.</p>
                <h3>How often the compiler reaches for a select</h3>                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=10 | sed -n '/conditional selects:/,/half of/p'
  conditional selects: 56   conditional branches: 49
  and the 45-looking number is not a typo: 23 of the 56 selects are
  the INVERTED forms -- cset, csetm, cinc, cinv, cneg -- which are
  the ones whose condition field is the negation of the one the
  mnemonic names.  A decoder that misses the inversion decodes 23
  instructions in this corpus with the condition backwards, and
  every one of them still produces a correct boolean for half of
  its inputs.
                </pre>
                </div>
                <p>Both are real and both are used, and <strong>23 of the 56 selects are the inverted forms</strong> this page is about. A decoder that missed the inversion would decode 23 of these with the condition backwards, and every one would still produce a correct boolean for half its inputs.</p>
                <p>The family has nine names and the artifact's first version counted them with a <code>startswith</code> test &mdash; which misses <code>csinc</code>, <code>csinv</code> and <code>csneg</code>, because &ldquo;csinc&rdquo; starts with &ldquo;csi&rdquo; and not with &ldquo;cse&rdquo;. That printed 45 where the answer is 56, and the eleven missing instructions were three of the four operations in the group: <strong>the section's own count of its own family was short by exactly the operations whose selection depends on the bit-30/<code>op2</code> pair.</strong> The list is now spelled out and the count printed as a sum of the numbers above it.</p>
                <p>Which one a compiler reaches for is a decision about whether the two sides of the branch are <em>equally likely</em> &mdash; a property of the program, not of the architecture. So that number is a fact about this corpus and a fact about <code>clang</code>, and <a href="/courses/a64asm/lessons/a64-verify">concept 5</a> measures what the choice costs in bytes rather than arguing about it.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Make the inversion bug and then hunt for it.</strong> In <code>a64dec.py</code>, in <code>m_condselect</code>, change <code>cond_text(cond ^ 1)</code> to <code>cond_text(cond)</code> in the <code>cset</code> branch. <em>(Expect the section 12 cross-check to report 14 disagreements &mdash; the 14 <code>cset</code>s in the corpus &mdash; and expect the section 10 table to still print 16 rows of which 8 are now WRONG while looking exactly as it did before. That is the shape of the bug: a table of plausible names, a cross-check that finds it, and a reader who reads the table first and believes it.)</em></li>
                    <li><strong>Prove the field is where the table says it is.</strong> Take the sixteen <code>csel</code> words from the first table and check that the only bits that differ are bits[15:12]. <em>(Expect the words to be <code>0x1a8_?_020</code> with the <code>?</code> running 0 through f in order &mdash; sixteen words, one varying nibble, everything else identical. Then do the same for the sixteen <code>b.cond</code> words and expect the varying nibble to be in a different place entirely, at the bottom of the word. Two groups, one meaning, two positions.)</em></li>
                    <li><strong>Find the reserved cells yourself.</strong> Build <code>0x1a800822</code> and <code>0x1a800c22</code> &mdash; the two <code>op2</code> values the table above calls UNDEFINED &mdash; and ask the assembler to assemble <code>csel w0, w1, w2, eq</code> variants that would land there, or hand them to the decoder. <em>(Expect <code>&lt;unknown&gt;</code> from the disassembler and an explicit UNDEFINED from this decoder, rather than an alias onto <code>csinc</code> or <code>csneg</code>. A decoder that lets a reserved value alias onto a real instruction is worse than one that admits it does not know, because the admission is visible and the alias is not.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86asm/lessons/x86-flags">x86-flags</a> is where the four-instruction-to-boolean sequence comes from, and <a href="/courses/a64asm/lessons/a64-asm">concept 1</a> is where <code>cset</code> appeared as the last row of the alias table with a one-line warning. <a href="/courses/a64asm/lessons/a64-encoding">Concept 2</a> measured the condition field and the two <code>op2</code> rows that are not contiguous.</p>
                <p>Forwards, <a href="/courses/a64asm/lessons/a64-verify">concept 5</a> is the cross-check, and this page is the reason it exists: a bug that inverts a condition produces output that is 0 or 1 either way, and the only instrument that finds it is a second reader that was not written by the same hand. <a href="/courses/a64asm/lessons/a64-encoding">Back to the field map</a> if the <code>op2</code> rows there stopped making sense.</p>
                <p>Outward, and this is the concept a compiler backend is most likely to get wrong. <strong>Every code generator that emits <code>CSET</code> has to know that the field holds the inverted condition</strong>, because a backend that inverts it twice produces a correct program on the inputs where both tests agree and an inverted one everywhere else &mdash; and a boolean inverted is a boolean, so the failure rate looks like a flaky test rather than an encoding bug.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64asm/lessons/a64-immediate">A Constant Is a Rotate and a Run Length</a></span>
                <span>Next: <a href="/courses/a64asm/lessons/a64-verify">Two Readers, and Then One of Them Poisoned</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
