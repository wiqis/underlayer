// The AArch64 Procedure Call Standard -- Concept 2: the register file.
// One register with two names, and the number 31 meaning three different
// things in three different slots.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_registers() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Register, Two Names, and Three Things Called 31 — Underlayer")
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
            <h1>One Register, Two Names, and Three Things Called 31</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64abi">The AArch64 Procedure Call Standard</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/a64abi/lessons/a64-aapcs">The previous concept</a> answered <em>which</em> register argument four goes in, and the answer was a list. This concept is about what happens when you stop treating that list as a set of 31 equally-ordinary things, because <strong>on this architecture the register file has a property that makes several of those answers traps rather than facts</strong>.</p>
                <div class="formula">
   THE SHAPE OF THE TRAP

   x86-64 has THIRTY-TWO 64-bit registers.  Writing 32 bits
   leaves the top half alone, and the 32-bit operations live
   in a SEPARATE file with different names.

   AArch64 has THIRTY-ONE 64-bit registers.  There is no
   second file.  `w0` and `x0` are the SAME 64 bits, and
   writing `w0` DESTROYS the top 32.
                </div>
                <p>Every C programmer on this platform has been told &ldquo;AArch64 is like x86-64 but with 31 registers and the arguments come in <code>x0</code>&ndash;<code>x7</code>.&rdquo; That sentence is the source of a specific, silent, and very hard bug, and this page is the measurement of it. It is a correctness trap, not a curiosity: the wrong behaviour here is not a wrong <em>name</em>, it is a wrong <em>value</em>, and it only shows up on the inputs that need the top half.</p>
                <p>There is a second trap in the same concept and it is about the number 31 &mdash; <code>sp</code>, <code>xzr</code>, and <em>not a general register at all</em>, depending on which of three fields you read it out of. <a href="/courses/a64asm/lessons/a64-encoding">The encoding course measured that the register field is five bits wide</a> and that a field map <strong>cannot express the difference</strong>, because the difference is not in the field. It is in the group.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: one register, one bit, and a rule you already use without knowing</h2>
                <p>Here is the whole experiment. Six instructions, assembled twice each &mdash; once with <code>w</code> and once with <code>x</code> &mdash; and the two words XOR-ed together. Three of the six are arithmetic and three are a move, so the result is a property of the register file and not of two lucky opcodes.</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/the XOR: one bit/,/^$/p'
  the w form             the x form             w word       x word       xor
  mov w0, #1             mov x0, #1             0x52800020   0xd2800020   0x80000000
  add w0, w0, #1         add x0, x0, #1         0x11000400   0x91000400   0x80000000
  sub w0, w0, w1         sub x0, x0, x1         0x4b010000   0xcb010000   0x80000000
  mov w0, w1             mov x0, x1             0x2a0103e0   0xaa0103e0   0x80000000
  mov w0, #-1            mov x0, #-1            0x12800000   0x92800000   0x80000000
  mov w0, wzr            mov x0, xzr            0x2a1f03e0   0xaa1f03e0   0x80000000

  [MEASURED-ON-BYTES]  6 pairs, 1 differing bit in every pair, and it
  is bit 31 -- `sf`, the size field.
                </pre>
                </div>
                <p><strong>Six pairs, one differing bit in every pair, and it is bit 31 every time.</strong> That is the <code>sf</code> field, and it is the only thing that separates the two names. So the model is: there are 31 registers, they are 64 bits wide, and <code>w&lt;n&gt;</code> is not a different register &mdash; it is the same 64 bits with a promise attached that <strong>bits 63:32 are set to zero</strong> on write.</p>
                <p>Now the row that makes it a correctness trap rather than a curiosity, and it is the fifth one:</p>
                <div class="hex-dump">
                <pre>  mov w0, #-1            mov x0, #-1            0x12800000   0x92800000

  the w form leaves x0 = 0x00000000FFFFFFFF
  the x form leaves x0 = 0xFFFFFFFFFFFFFFFF
                </pre>
                </div>
                <p><strong>The same immediate, in the same field, meaning two different things.</strong> The top half of a register has no name of its own, so a 32-bit write to it is a <strong>zero extension</strong> &mdash; and a zero extension is not free here in the way it is on x86-64. On this architecture <strong>it is not even an instruction</strong>: it is what the other bit of the same word does for free. There is no <code>movl %eax, %eax</code> needed, because <code>sf = 0</code> <em>is</em> the zeroing.</p>
                <p>Why this is worth a concept. A decoder that models <code>w0</code>&ndash;<code>w30</code> and <code>x0</code>&ndash;<code>x30</code> as <strong>two 32-register banks</strong> gets the register <em>numbers</em> right and the <em>semantics</em> wrong, and it gets them wrong silently: every value it computes is a valid value, and the wrong one is exactly the value a 32-bit programmer would have got on a machine with two banks. That is retraction R2, it is asserted as text by the harness, and it is the reason a decoder that &ldquo;handles both widths&rdquo; is not automatically right.</p>
                <p>The rule you already use without knowing: <strong>the AAPCS64 says an integer result comes back in <code>x0</code>, and a C <code>int</code> function returning a 64-bit value in the same source works fine</strong> &mdash; because the callee wrote <code>x0</code> with a 64-bit write and the caller read it with a 64-bit read. The trap is the other direction: a callee that writes <code>w0</code> and a caller that reads <code>x0</code> agree only about the bottom 32 bits, and the top half the caller reads is whatever the callee's previous 32-bit write left there. <strong>Which is zero, because the callee zeroed it.</strong> Both sides are correct; the value is not what a reader of the source would predict.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Register number 31 is three different things</h2>
                <p>Same five bits, read out of the same words, in three slots. Here is the table, with the second reader's own name for each row beside ours:</p>
                <div class="hex-dump">
                <pre>$ python3 a64abi.py --run | sed -n '/Register NUMBER 31 IS THREE/,/^$/p'
  source                   word       Rd/Rt    Rn       what the reader calls it
  add sp, sp, #16          0x910043ff 31       31       add  sp, sp, #0x10
  str w0, [sp, #12]        0xb9000fe0 0        31       str  w0, [sp, #0xc]
  cbz w31, T               0x3400001f 31       0        cbz  wzr, 0x0 &lt;.text&gt;
  cbz x31, T               0xb400001f 31       0        cbz  xzr, 0x0 &lt;.text&gt;
  add x1, xzr, x1          0x8b0103e1 1        31       add  x1, xzr, x1
  mov x0, sp               0x910003e0 0        31       mov  x0, sp
  mov x0, xzr              0xaa1f03e0 0        31       mov  x0, xzr
  add wsp, wsp, #16        0x110043ff 31       31       add  wsp, wsp, #0x10
                </pre>
                </div>
                <p>Read the <code>Rd</code> and <code>Rn</code> columns. In <code>add sp, sp, #16</code> the number 31 in <em>both</em> slots means the stack pointer. In <code>str w0, [sp, #12]</code> the 31 in <code>Rn</code> means the stack pointer again &mdash; and that row is the same encoding shape as <code>mov x0, xzr</code>, where the 31 in <code>Rn</code> means <strong>zero</strong>. Same five bits. Same architecture. Two answers, and the difference is <strong>which encoding group the word is in</strong>.</p>
                <p>And the last row of the table is the one that settles what a decoder may do. <code>add wsp, wsp, #16</code> is <code>0x110043ff</code>, and <code>add sp, sp, #16</code> is <code>0x910043ff</code> &mdash; the same register, the same immediate, the same bits, differing only in bit 31. <strong>There is no <code>wsp</code> register.</strong> The name is a spelling the assembler will accept for the same 64-bit thing, and if you think of it as a 32-bit stack pointer you will compute a frame size that is wrong by a factor of two.</p>
                <div class="hex-dump">
                <pre>  str w0, [x31, #12]      REFUSED  -  invalid operand for instruction
                </pre>
                </div>
                <p><strong>The assembler will not let you name it in a base slot at all.</strong> In that slot, 31 is not a general register, and the assembly language does not pretend otherwise. So: a decoder that prints <code>x31</code> in a base slot <strong>is not making a naming choice</strong> &mdash; it is reading a field the encoding has already given a different meaning, and there is no encoding in which that field means <code>x31</code>.</p>
                <p>Two rows deserve a second reading, because they look like one instruction and are not even in the same group:</p>
                <ul>
                    <li><strong><code>mov x0, sp</code> is <code>0x910003e0</code></strong> &mdash; ADD (immediate), with <code>Rn = 31</code> meaning the stack pointer. It is the <em>third</em> operand of an add, with <code>Rd = 0</code>.</li>
                    <li><strong><code>mov x0, xzr</code> is <code>0xaa1f03e0</code></strong> &mdash; ORR (shifted register), with <code>Rn = 31</code> meaning zero. A64asm measured both: <code>mov</code> is an alias, and it is <em>two different aliases</em>.</li>
                </ul>
                <p>Both move a constant into <code>x0</code>. <strong>Same five-bit field, same architecture, two groups, two names, and the assembler prints the two names without the reader ever seeing that the field is shared.</strong> If you have been reading <code>mov</code> as &ldquo;the instruction that loads a constant&rdquo; and <code>add</code> and <code>orr</code> as two other instructions, this is where that model breaks: <code>mov</code> is not an instruction at all, it is a name with two meanings depending on which encoding group the assembler picked.</p>
                <h3>Where the two banks meet</h3>
                <p>One more row worth having, because it connects this concept to <a href="/courses/a64abi/lessons/a64-aapcs">the argument registers</a> and to <a href="/courses/a64abi/lessons/a64-unwind">the unwind table</a>. The AAPCS64 numbers the registers <code>r0</code>&ndash;<code>r30</code> in the specification, and the specification's <em>own</em> convention for 31 is not one register. <code>SP</code> is <strong>callee-saved</strong> (&sect;6.1.1 lists <code>r19-r29 and SP</code>), which is why a callee may move it and must put it back, and the <code>.eh_frame</code> at the top of every AArch64 object says <code>DW_CFA_def_cfa: reg31 +0</code> &mdash; <strong>reg31, in the CFI, is the stack pointer, using the same number as the instruction field that means zero.</strong> That is the hinge between this concept and the last one, and it is why the two pages are adjacent.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: reading the field map, and what it cannot express</h2>
                <p><a href="/courses/a64asm/lessons/a64-encoding">The encoding course measured the field map by assembling a sweep of variants and OR-ing the XOR</a>, and its table has a row for the register number: <code>Rd</code> is <code>bits[4:0]</code>. That is true in every group &mdash; and it is <strong>the same five bits with three different meanings</strong>, which is why a field map <em>cannot</em> express the difference. A field map says which bits hold the number. It has nothing to say about what the number <em>means</em>, because the meaning is a property of the group and not of the field.</p>
                <p>So the practical rule, and it is the one this course's own decoder is built on:</p>
                <div class="formula">
   A REGISTER NAME IS NOT A PROPERTY OF A FIELD

   A field map can tell you  Rd is bits[4:0].
   It cannot tell you  31 in Rd is sp.
   It cannot tell you  31 in Rn is zero in a logical op
                       and 31 in Rn is sp in an add.

   The group decides.  Every model in the decoder therefore
   calls reg(n, ...) WITH the permission its own group has,
   rather than with one default:

       reg(n, allow_sp=True)   add/sub, load/store
       reg(n, allow_sp=False)  logical, data-processing
       and CBZ/CBNZ special-cases 31 to wzr/xzr entirely,
       because a compare has no "stack pointer" form.
                </div>
                <p>That is <strong>retraction R15 from the encoding course, this time as design advice.</strong> A flag with a default is a flag nobody checks: the encoding course's logical-immediate model called the register-name function with its default permission, printed <code>orr x9, sp, #0x8000000000000001</code> for a word the disassembler calls <code>mov x9, #-0x7fffffffffffffff</code>, and every value in the corpus still computed to something valid. <strong>A logical OR against the stack pointer is a different VALUE from a logical OR against zero</strong> &mdash; and the decoder wrote down a register that does not exist in that instruction.</p>
                <p>Now the test that tells you whether you have understood this concept, because it is the one a compiler actually generates and the one nobody checks by hand. In the corpus:</p>
                <div class="hex-dump">
                <pre>$ llvm-objdump-21 --triple=aarch64 -d abi_O2.o | grep -c '\bw0\b\|\bx0\b'
  ... and the same count for wsp, xzr, sp, x31 in every slot
                </pre>
                </div>
                <p><code>x0</code> and <code>w0</code> appear constantly and <em>alternate in the same function</em> &mdash; a 64-bit add followed by a 32-bit compare, a pointer-sized arithmetic followed by an <code>int</code> truncation. <strong>Every one of those alternations is a zeroing of the top half</strong>, and the disassembly never says so, because there is no instruction that says so. A reader who is looking for evidence of truncation in the disassembly will not find it, because <strong>the evidence is the absence of a bit and the absence of a bit is invisible in a listing.</strong> This is the one place in this course where the correct answer to &ldquo;how do I check this?&rdquo; is &ldquo;by the model, not by the bytes.&rdquo;</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the one-bit table, then find the group where it is not one bit.</strong> Assemble <code>mov w0, #1</code> / <code>mov x0, #1</code>, <code>add</code>, <code>sub</code>, <code>mov w0, w1</code>, <code>mov w0, #-1</code> and <code>mov w0, wzr</code> in both widths, and XOR each pair. <em>(Expect six pairs, every XOR exactly <code>0x80000000</code>. Then assemble <code>str w0, [x1]</code> / <code>str x0, [x1]</code> / <code>ldrb</code> / <code>ldrh</code> and read bits[31:30] instead of bit 31: <code>0xb9000020</code>, <code>0xf9000020</code>, <code>0x39400020</code>, <code>0x79400020</code> &mdash; a TWO-bit <code>size</code> field with four values (00 byte, 01 half, 10 word, 11 double), not a one-bit <code>sf</code>. So the width is one bit in the arithmetic and logical groups and two in the load/store groups, which is the same finding as the register-31 table in a different place: a field map marks bits, and the <em>meaning</em> of a field is a property of the group that owns it.)</em></li>
                    <li><strong>Write the bug this concept is about, and watch it not crash.</strong> <em>(Expect: a C function whose parameters are <code>long</code> and whose return type is <code>int</code> works, silently, on a value above 2<sup>31</sup>. Then inspect the disassembly and find the <code>w</code>/<code>x</code> alternation that causes it. The lesson is not &ldquo;AArch64 is broken&rdquo; &mdash; it is that the C language defines the conversion, the compiler obeyed, and <em>the listing has nothing to show you because the zeroing is a bit and not an instruction</em>.)</em></li>
                    <li><strong>Ask the assembler the question the table answers, and note that it refuses to lie.</strong> <em>(Expect <code>str w0, [x31, #12]</code> to be REFUSED with &ldquo;invalid operand for instruction&rdquo; &mdash; the assembler will not name a general register in a slot where 31 is not one. And expect <code>mov x0, sp</code> and <code>mov x0, xzr</code> to be two different words in two different groups. The base register of an <code>x</code>-form or <code>w</code>-form load/store, or the first source of an ADD, is <code>sp</code>; the first source of an ORR is <code>xzr</code>. A decoder that has one table of register names for all five slots is wrong in at least one of them.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, one concept. <a href="/courses/a64abi/lessons/a64-aapcs">The calling convention</a> gave you <code>x0</code>&ndash;<code>x7</code> and <code>d0</code>&ndash;<code>d7</code> as <em>places</em>; this concept is what those places are made of, and it is the reason the AAPCS64 can say &ldquo;the result is returned in the same registers as would be used for such an argument&rdquo; without a second sentence &mdash; because an integer argument and an integer result are the same 64 bits and a <code>w</code>/<code>x</code> mistake in either direction has the same consequence.</p>
                <p>Across the architecture, and this is the closest neighbour: <a href="/courses/a64asm/lessons/a64-encoding">The encoding course's field map</a> is the table this page is a footnote to, and <a href="/courses/a64asm/lessons/a64-cond">the conditional-select inversion</a> is the sharpest place the register-31 rule bites, because <code>csinc x0, xzr, xzr, NE</code> uses 31 in a source slot that must be <em>zero</em> in a group where 31 would otherwise be <code>sp</code>. <a href="/courses/x86asm/lessons/x86-integers">The x86-64 integer concepts</a> are the direct contrast: 32 registers, a separate 32-bit file, and a 32-bit write that leaves the top half alone.</p>
                <p>Forwards. <a href="/courses/a64abi/lessons/a64-frame">Concept 3</a> needs the number 31 as <code>sp</code> and nothing else, and its first question is what a function may do to the region <em>below</em> that number. <a href="/courses/a64abi/lessons/a64-save">Concept 4</a> adds the other sixteen registers &mdash; and the interesting part of that list is that <strong>the callee-saved set is the set whose names the CFI also quotes</strong>, so <code>reg31</code> from this page is the same number as the <code>DW_CFA_def_cfa: reg31</code> in <a href="/courses/a64abi/lessons/a64-unwind">concept 5</a>.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64abi/lessons/a64-aapcs">The Calling Convention, and the Number That Was 128</a></span>
                <span>Next: <a href="/courses/a64abi/lessons/a64-frame">No Red Zone, and the Two Instructions That Is Worth</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
