// AArch64: Encoding From The Ground Up -- Concept 1: the surface and the length.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_asm() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Four Bytes, and a Mnemonic That Is Not In There — Underlayer")
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
            <h1>Four Bytes, and a Mnemonic That Is Not In There</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/a64asm">AArch64: Encoding From The Ground Up</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Almost everything written about AArch64 instruction encoding opens by telling you the length is fixed, and then moves on, and the reason to spend a concept on it is that <strong>the fixed length is not a detail of this encoding &mdash; it is what makes the encoding easy to decode and hard to encode.</strong> Every other design decision in the architecture is a consequence of a decision to spend 32 bits on every instruction, and you cannot evaluate any of them until you know what that purchase cost.</p>
                <p>The purchase is not money. It is <em>range</em>: if every instruction is four bytes, then every field has to fit in 32 bits, and there is no escape to a second word. AArch64 therefore has a 12-bit add-immediate where x86-64 has an 8-bit one with a 32-bit escape, a 19-bit conditional branch where x86-64's is 8-bit-and-relative-to-16-bits, and a 21-bit PC-relative address &mdash; and each of those numbers is a consequence, not a choice. The next two concepts are about those fields. This one is about the constant underneath all of them.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: two properties, one of them free</h2>
                <h3>Property one: the length is a constant</h3>
                <p>Five object files, four optimisation levels plus a hand-written corpus, 868 instructions:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=2 | sed -n '/file  /,/VERDICT/p'
  file              section   bytes    %4    insns   bytes/insn  chain
  a64.o             .text     540      0     135     4.0000      EXACTLY
  corpus_O0.o       .text     1352     0     338     4.0000      EXACTLY
  corpus_O1.o       .text     496      0     124     4.0000      EXACTLY
  corpus_O2.o       .text     588      0     147     4.0000      EXACTLY
  corpus_Os.o       .text     496      0     124     4.0000      EXACTLY

  868 instructions over 5 code sections.  Every section is a
  multiple of four, every walk ends exactly on the section end, and
  bytes/insn is 4.0000 in every row including the hand-written one.
  VERDICT: fixed width, on this corpus
                </pre>
                </div>
                <p>Two columns matter more than the rest. The <code>%4</code> column is zero in all five rows, so no section has a ragged tail. And <code>chain closed EXACTLY</code> is the artifact walking each section from its first byte to its last and landing <em>on</em> the end rather than near it &mdash; which is the property that has no analogue in the previous course. A decoder that guesses a length wrong in a variable-length encoding is reading garbage forever after, and there is no resynchronisation point. Here the next instruction starts four bytes on whether or not the previous one made sense.</p>
                <p>So here is what it buys, stated as the negative space rather than the positive claim, because every item is a class of bug this decoder <em>cannot have</em>:</p>
                <ul>
                    <li><strong>Desynchronisation.</strong> A word no model claims is four bytes of somebody else's problem, and the count above is still right.</li>
                    <li><strong>Length arithmetic.</strong> No prefix byte, no escape, no opcode-length table, and therefore no integer that can overflow.</li>
                    <li><strong>A decoded instruction that is not an instruction.</strong> The distinction is available for free, which is not true on x86 and is the entire reason the ISA course's decoder has a declared subset of <em>lengths</em> and this one has a declared subset of <em>names</em>.</li>
                </ul>
                <h3>And what it costs, because the list above is one-sided</h3>
                <p>Four bytes is four bytes for <code>nop</code>, which does nothing. The x86-64 encoding has a one-byte <code>nop</code> and a two-byte <code>ret</code>; this one pays four bytes each. The artifact measured the whole of that and the answer is not &ldquo;AArch64 is worse&rdquo;:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=13 | sed -n '/-O0  a64/,/-Os  a64/p'
    -O0  a64  1352 bytes /  338 insns   x86  1174 bytes /  393 insns   ratio 1.152  AArch64 LARGER
    -O1  a64   496 bytes /  124 insns   x86   610 bytes /  200 insns   ratio 0.813  AArch64 smaller
    -O2  a64   588 bytes /  147 insns   x86   738 bytes /  236 insns   ratio 0.797  AArch64 smaller
    -Os  a64   496 bytes /  124 insns   x86   384 bytes /  151 insns   ratio 1.292  AArch64 LARGER

  THE RESULT, and it is not the one this course was drafted around.
  AArch64 is LARGER at 2 of the 4 levels.
                </pre>
                </div>
                <p><strong>Two of four.</strong> The first draft of this page asserted &ldquo;AArch64 loses on code density&rdquo;, and the measurement retracts it rather than softening it &mdash; the ratio changes sign with the optimisation flag, so it was never a property of the architecture. The defensible sentence is: <em>fixed width costs code size when the code is spill-heavy and saves it when the code is not</em>, and the -O0 row shows why in one line. AArch64 emitted <strong>fewer</strong> instructions than x86-64 (338 against 393) and still produced <strong>more</strong> bytes (1352 against 1174), which can only be true if the instructions it did not emit were cheap on the other side &mdash; and at -O0 they are, because every spilled parameter is a 4-byte store against a 2-or-3-byte one.</p>
                <h3>Property two: the mnemonic is not stored</h3>
                <p>What the encoding stores is an opcode and operands. The name you type is the <em>assembler's</em>, and the two are related by a table the architecture defines. Every row below was measured by assembling both lines and comparing the two 32-bit words &mdash; the only way to say what an alias <strong>actually</strong> stands for rather than what it looks like:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=2 | sed -n '/52824680/,/19 of 22/p'
    52824680  mov w0, #0x1234      == movz w0, #0x1234    MOVZ with hw = 0
    6b01001f  cmp w0, w1           == subs wzr, w0, w1    the flag-writing form, with
                                                       the destination thrown away
    3100041f  cmn w0, #1           == adds wzr, w0, #1    the same, on the other side
    4b0103e0  neg w0, w1           == sub w0, wzr, w1     the zero register as a SOURCE
    2a2103e0  mvn w0, w1           == orn w0, wzr, w1     NOT is OR with all ones -- and
                                                       the ZERO is the FIRST operand
    6a01001f  tst w0, w1           == ands wzr, w0, w1
    2a0103e0  mov w0, w1           == orr w0, wzr, w1     a MOVE IS AN OR with a zero
    9100001f  mov sp, x0           == add sp, x0, #0      register 31 is the STACK POINTER
    910003e0  mov x0, sp           == add x0, sp, #0      in this group
    1b027c20  mul w0, w1, w2       == madd w0, w1, w2, wzr   a MULTIPLY IS a three-source
                                                         with an addend of zero
    93407c20  sxtw x0, w1          == sbfm x0, x1, #0, #31   a sign extend, as a FIELD
    d3407c20  uxtw x0, w1          == ubfm x0, x1, #0, #31
    531d7020  lsl w0, w1, #3       == ubfm w0, w1, #29, #28  a shift is a bitfield whose
                                                            two halves are adjacent
    d65f03c0  ret                  == ret x30             and the link register is 30, so
                                                         it is the DEFAULT
    d503201f  nop                  == hint #0             TWENTY-SEVEN FIXED BITS and a
                                                         5-bit hint number
    11400420  add w0, w1, #0x1000  == add w0, w1, #1, lsl #12   one imm12 field, with a
                                                              SHIFT on it
    1a9f17e0  cset w0, eq          == csinc w0, wzr, wzr, ne   THE TRAP: the condition is
                                                                 INVERTED
    1a9f07e0  cset w0, ne          == csinc w0, wzr, wzr, eq
    5a9f13e0  csetm w0, eq         == csinv w0, wzr, wzr, ne
    1a811420  cinc w0, w1, eq      == csinc w0, w1, w1, ne   Rn == Rm, and again INVERTED
    5a81b420  cneg w0, w1, ge      == csneg w0, w1, w1, lt
    10ffffc0  adr x0, T            != 90000000 adrp x0, T  NOT AN ALIAS, and the row is
                                                          here for that reason

  19 of 22 pairs are the same 32 bits.
                </pre>
                </div>
                <p>Read that for the architecture rather than for the aliases. <strong><code>cmp</code> is a <code>subs</code> with a destination nobody keeps. <code>mvn</code> is an <code>orn</code>. <code>mov</code> is an <code>orr</code>. <code>mul</code> is a <code>madd</code> with a zero addend. <code>lsl</code> is a bitfield whose two halves happen to be adjacent.</strong> Every one of those is a name the architecture added on top of a smaller set of real encodings, and every one of them costs nothing: same four bytes, same decode cost, one more mnemonic for a human.</p>
                <p>That is the general fact, and it runs both ways: <strong>the mnemonic is free and the mnemonic is also where the errors live.</strong> The row for <code>mvn</code> has a trap in it that is worth naming. The correct spelling is <code>orn w0, wzr, w1</code> &mdash; <em>zero first</em> &mdash; and the natural guess <code>orn w0, w1, wzr</code> assembles to <code>2a3f0020</code>, a different word. The two sources are in a fixed order in the encoding and the assembler does not accept the other one, so a reader who has the alias right and the operand order wrong gets a plausible instruction that is not the one they meant.</p>
                <p>And one row is not an alias at all. <code>adr x0, T</code> and <code>adrp x0, T</code> are <strong>one bit</strong> apart &mdash; bit 31, which is <code>sf</code> in every other group in the architecture &mdash; and the difference in reach is 4,096. That is <a href="/courses/a64asm/lessons/a64-encoding">concept 2's</a> subject, and it is the first of three places where bit 31 means something other than what its name suggests.</p>
                <h3>What the two properties buy together</h3>
                <p>Combine them and you get the thing no other 32-bit architecture in this collection has: <strong>an instruction whose length you know before you know what it is.</strong> That is what lets a decoder be a decision tree over a fixed width instead of a length table followed by an opcode table, and it is why this course's artifact is 21 models and the ISA course's decoder has a length arithmetic with a resynchronisation story.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three things that are cheaper to state than to prove</h2>
                <p>This course has a habit the courses before it established, and it is worth showing before the worked example rather than after the last concept. Each of the three was asserted in a draft of this course. Each was measured. Each was retracted in public.</p>
                <ul>
                    <li><strong>The mnemonic is free, and the mnemonic is also where the errors live.</strong> Nineteen of twenty-two alias pairs are the same 32 bits and the twentieth is <code>adr</code> against <code>adrp</code> &mdash; one bit, 4,096 of reach &mdash; and the twenty-first is <code>mvn</code>, whose correct spelling is <code>orn w0, wzr, w1</code> with the <strong>zero first</strong>. The natural guess <code>orn w0, w1, wzr</code> assembles without a diagnostic and means something else. A wrong operand order in an alias is a plausible wrong instruction, not an error.</li>
                    <li><strong>Register 31 is the stack pointer in some slots and the zero register in others, and the field is identical in both.</strong> The mask is bits[4:0] either way, so <em>no field map can express the difference</em> &mdash; and this course's own decoder got it wrong in the logical-immediate group, printing <code>sp</code> where the encoding says zero, until the cross-check found it. A flag with a default is a flag nobody checks.</li>
                    <li><strong>&ldquo;Fixed width&rdquo; is a claim about a constant, and the only way to show a constant is to show what it is constant against.</strong> Same C, both targets, four optimisation levels: 1.152, 0.813, 0.797, 1.292. AArch64 is larger at two of the four. The claim this course was written to make was retracted rather than softened.</li>
                </ul>
                <p>All seventeen retractions are printed in full by the artifact and asserted <em>as text</em> by the harness, so a later edit cannot quietly delete one.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: reading one word, out loud</h2>
                <p>The artifact prints a derivation for every field it reads, which is the part a disassembler cannot do and the reason a disassembler is not evidence:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --why 1204cc00
    0x1204cc00   and      w0, w0, #0xf0f0f0f0
      class field bits[28:25] = 1001  -&gt;  Data Processing -- Immediate
      . N = 0 and opc = 0, so the word spells AND.  There is no invert bit:
        clang emits AND for `bic w0,w0,#0xff` by negating the CONSTANT to
        0xffffff00, and the inversion is arithmetic, not encoding.
      . LOGICAL IMMEDIATE: len = the position of the highest set bit of
        N:NOT(imms) = 0b0001100, so esize = 1 &lt;&lt; 3 = 8 bits
      . LOGICAL IMMEDIATE: S = imms &amp; 0b111 = 3 is the WIDTH of the run of
        ones (S+1 = 4 of them); R = immr &amp; 0b111 = 4 is how far RIGHT that
        run is rotated inside the element
      . LOGICAL IMMEDIATE: a run of 4 ones is 0b1111; rotate it right by 4
        within 8 bits and you get 0b11110000 = 0xf0
      . LOGICAL IMMEDIATE: repeat that element 8 times: the 64-bit pattern
        is 0xf0f0f0f0f0f0f0f0
      . LOGICAL IMMEDIATE: the destination is 32 bits, so the answer is the
        low 32 of that pattern: 0xf0f0f0f0
      . this decode READ 32 of the 32 bits; 0 were not needed to name the
        instruction
                </pre>
                </div>
                <p>Every line is arithmetic on the bits and every line is checkable by hand with the constants beside it. That is the whole difference between a decoder and a disassembler: <code>llvm-objdump-21</code> printed <code>and w0, w0, #0xf0f0f0f0</code> for the same word in one line and cannot tell you how, and the twelve bits it used are not readable in its output at all. <a href="/courses/a64asm/lessons/a64-immediate">Concept 3</a> is entirely about those twelve bits.</p>
                <p>And the derivation is printed by the recorded run, not only by <code>--why</code> on a command line. That is a rule rather than a preference: <code>check_quotes.py</code> reads only <code>a64dec.out</code>, so a figure this page quotes has to be in the file the harness can see. A page that quotes a derivation no harness can find is a page whose numbers are only checkable by the machine that wrote them.</p>
                <p>One more thing this page can now state that the previous course could not. <strong>Register 31 means different things in different groups</strong>, and this is not a subtle point: in <code>add</code> and <code>sub</code> it is the stack pointer, in the logical groups it is the zero register, in a load's data slot it is the zero register while in a load's <em>base</em> slot it is the stack pointer, and in <code>cbz</code>'s register slot it is the zero register. The rows above show <code>mov sp, x0</code> as <code>add sp, x0, #0</code> and <code>mov w0, w1</code> as <code>orr w0, wzr, w1</code> &mdash; both use register 31, and in the first it is the stack pointer and in the second it is zero. <strong>A decoder that decides this once gets a plausible answer in the common case and a wrong one exactly where a compiler is most likely to emit the instruction.</strong> That is retraction R15 and it was found by a cross-check, not by reading a manual.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Count the lengths yourself.</strong> <code>llvm-objdump-21 --triple=aarch64 -d</code> any AArch64 object and count the bytes on each line. <em>(Expect exactly seven distinct instruction lengths on the x86-64 side of the same C and exactly one on the AArch64 side, and expect the x86 distribution to be dominated by one and three bytes. The AArch64 row is a single bar at 100% and that is the whole visual argument for the concept.)</em></li>
                    <li><strong>Break the alias in half and see which half you had.</strong> Assemble <code>mov w0, w1</code> and <code>orr w0, wzr, w1</code>, then <code>orr w0, w1, wzr</code>. <em>(Expect the first pair to be identical bytes and the third to be a different word &mdash; and expect the assembler to accept all three without complaint, because <code>orr w0, w1, wzr</code> is a perfectly good instruction that is not the one you meant. This is the general form of the mvn row on this page: a wrong operand order in an alias is a plausible wrong instruction, not a diagnostic.)</em></li>
                    <li><strong>Make the length lie and see what breaks.</strong> In <code>a64dec.py</code>, change <code>decode_text</code> to advance by 3 instead of 4. <em>(Expect the section 2 table to report <code>chain closed NO</code> and a non-zero <code>%4</code>, the section 12 cross-check to collapse, and the poisoned number to move. This is the completion criterion in miniature: the only claim in this course you can break with a one-character edit, and breaking it is how you learn that the claim was a measurement.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/isa/lessons/isa-length">isa-length</a> derived the variable-length property this page is the negation of, and <a href="/courses/elf/lessons/section-header-table">the ELF course's section-header concept</a> is where the reader that walks these 868 words comes from &mdash; <code>struct.unpack_from</code> at <code>0x28</code> and the section array at <code>0x3a</code>, with no library. <a href="/courses/elf/lessons/section-vs-segment">elf-section-vs-segment</a> is why the artifact finds <code>.text</code> by NAME and by the execute flag rather than by index.</p>
                <p>Forwards, <a href="/courses/a64asm/lessons/a64-encoding">the field map</a> is where bits[28:25] is measured, <a href="/courses/a64asm/lessons/a64-immediate">the immediates</a> is where those twelve unreadable bits are unpacked, <a href="/courses/a64asm/lessons/a64-cond">the conditions</a> is where the <code>cset</code> row at the bottom of the alias table becomes a whole concept, and <a href="/courses/a64asm/lessons/a64-verify">the cross-check</a> is where the register-31 bug from this page is found.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64asm">course home</a></span>
                <span>Next: <a href="/courses/a64asm/lessons/a64-encoding">The Class Field Is Four Bits, and the Field Map Is Measured</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
