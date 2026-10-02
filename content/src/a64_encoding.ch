// AArch64: Encoding From The Ground Up -- Concept 2: the class field and the
// measured field map.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_encoding() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Class Field Is Four Bits, and the Field Map Is Measured — Underlayer")
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
            <h1>The Class Field Is Four Bits, and the Field Map Is Measured</h1>
            <div class="lesson-meta">30 min &middot; <a href="/courses/a64asm">AArch64: Encoding From The Ground Up</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/a64asm/lessons/a64-asm">The last concept</a> established that the length is a constant, and the immediate consequence is that <strong>everything else has to fit in the remaining 32 bits with no escape.</strong> There is no second word to fall back into. So the field map is not a convenience on this architecture &mdash; it <em>is</em> the curriculum, and a decoder is a decision tree over a fixed width rather than a length table followed by an opcode table.</p>
                <p>Which makes the field map the thing worth being careful about, because it is exactly the thing a person reads out of a manual once and then trusts. This concept measures it instead: 58 field positions, each one obtained by assembling an instruction, changing one operand, and OR-ing the XOR over a <em>sweep</em> of variants. The guards in the artifact are built from that table, and the table is written to <code>fields.txt</code> so you can check it.</p>
                <p>The reason a measurement rather than a reading, in one line: <strong>a field map read out of a manual is a claim, and a claim cannot be debugged.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The class field: four bits, and eleven of sixteen</h2>
                <p>Four bits at position 25 are the first thing a decoder looks at. The class <em>names</em> are quoted from the architecture's reference manual; the class <em>membership</em> is measured, by taking the instructions out of five object files, reading four bits out of each, and asking <code>llvm-objdump-21</code> what that instruction is:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=3 | sed -n '/bits    n /,/Empty here/p'
  bits    n      what landed there, and how often        the QUOTED name
  00100   23     ldp:15 stp:8                            Loads and Stores (pair)
  00101   111    add:40 mov:34 subs:6 cmp:5 neg:4        Data Processing -- Register
  01100   151    ldr:83 str:59 ldur:2 ldrb:2 ldrsw:2     Loads and Stores
  01101   101    csel:22 cset:14 mul:10 madd:10 lsl:5   Data Processing -- Register
  01011   142    ret:134 tbz:4 br:1 blr:1 tbnz:1         Branches, Exception Gen and Sys
  01001   134    mov:45 and:28 movk:19 lsl:9 orr:8      Data Processing -- Immediate
  01000   114    add:41 sub:31 cmp:20 subs:11 mov:4     Data Processing -- Immediate
  01010   84     b:27 bl:10 b.ne:8 b.eq:7 cbz:6          Branches, Exception Gen and Sys
  00110   1      ldp:1                                  Advanced SIMD (pair)
  00111   6      add:3 movi:2 addv:1                     Advanced SIMD
  01111   1      fmov:1                                 Advanced SIMD / FP

  11 of the 16 values carry at least one real instruction in this
  corpus.  Empty here: 00000, 00001, 00010, 00011, 01110.
                </pre>
                </div>
                <p>Two numbers to take from that. <strong>Four bits, not two.</strong> The two-bit rule this decoder first used put <code>ret</code> in &ldquo;Data Processing &mdash; Register&rdquo;, because bits[28:26] of <code>0xd65f03c0</code> is <code>0b110</code>; <code>ret</code> is 134 of the 868, the single largest entry in the distribution. And <strong>01101 is a class a two-bit rule cannot see at all</strong> &mdash; it holds <code>csel</code>, <code>cset</code>, <code>mul</code> and <code>madd</code>, 101 instructions. That is not cosmetic: 01101 and 00101 are different code paths through a decoder, with different guards and different operand layouts.</p>
                <p>And then the honest caveat, which is the part a caption usually leaves out. <strong>Five of the sixteen values are empty <em>in this corpus</em></strong>, and four of those five carry SIMD. That is a fact about 25 functions of ordinary C, not about the architecture. The correct statement is that a decoder may implement 11 of the 16 classes and be correct on every instruction in this corpus &mdash; and the 5 empty values are values whose contents this corpus did not exercise, not "unimplemented classes". A class field is four bits wide whether or not a program uses it.</p>
                <h3>The method, and the mistake that made it necessary</h3>
                <p>One line long: assemble an instruction, change <strong>one</strong> operand, assemble it again, and every bit that moved belongs to that operand.</p>
                <p>The first version of this measurement was wrong in a way that <em>looked</em> like a result, and the mistake is the most useful thing on this page. A single pair marks the bits where the two <strong>values</strong> differ, which is a subset of the field and not the field. Measured with one pair, <code>movz w0, #0x1111</code> against <code>movz w0, #0x2222</code> gives an <strong>8-bit <code>imm16</code></strong> &mdash; because 0x1111 and 0x2222 happen to differ in eight bit positions &mdash; when the field is sixteen bits wide. The table looked wrong because the table was.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=4 | sed -n '/^  field /,/imm16/p'
  field              xor mask    the positions         base instruction
  Rd                 0000000f    bits[3:0]             add w0, w1, w2
  Rn                 000001c0    bits[8:6]             add w0, w1, w2
  Rm                 000f0000    bits[19:16]           add w0, w1, w2
  sf                 80030001    bits[0,16,17,31]      add w0, w1, w2
  op                 40000000    bits[30:30]           add w0, w1, w2
  S                  20000000    bits[29:29]           add w0, w1, w2
  shift amt          0000fc00    bits[15:10]           add x0, x1, x2, lsl #0
  shift type         00e0e000    bits[13,14,15,21,22,23]  add w0, w1, w2, lsl #3
  opc                60000000    bits[30:29]           and w0, w1, w2
  imm12              003ffc00    bits[21:10]           add w0, w1, #0x0
  imm16              001fffe0    bits[20:5]            movz w0, #0x0000
  hw                 00600000    bits[22:21]           movz x0, #0x1111
                </pre>
                </div>
                <p>The fix is to OR the XOR over a <strong>sweep</strong> of variants, one per single bit of the operand, so every position the operand can reach is marked. And the artifact is explicit about what the result is: <strong>a mask is a LOWER BOUND.</strong> Every bit in it really does belong to that operand; a bit <em>not</em> in it is a bit the sweep did not happen to move. The <code>Rn</code> row above is four bits wide and the field is five, because the sweep visited odd register numbers and never moved bit 5 &mdash; and the file prints the not-moved bits per row rather than rounding the mask up to a span.</p>
                <h3>Four rows in that table that are worth reading slowly</h3>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=4 | sed -n '/^  pair Rt2/,/pair scale/p'
  pair Rt            0000001f    bits[4:0]             stp x0, x1, [sp]
  pair Rt2           00007c00    bits[14:10]           stp x0, x1, [sp]
  pair Rn            000003e0    bits[9:5]             stp x0, x1, [sp]
  pair imm           001f8000    bits[20:15]           stp x0, x1, [sp]
  pair mode          01bf0000    bits[16,17,18,19,20,21,23,24]  stp x0, x1, [sp]
  pair L             00400000    bits[22:22]           stp x0, x1, [sp]
  pair scale         84000000    bits[26,31]           stp w0, x1, [sp]
                </pre>
                </div>
                <ul>
                    <li><strong><code>Rt2</code> in the pair form is bits[14:10] and not bits[11:10].</strong> This is the single most common AArch64 decoder bug in existence, and the reason is a coincidence that hides it: a decoder that guesses a two-bit field gets <code>stp x0, x1</code> right, because for <em>that pair</em> the two candidate fields happen to hold the same value. Every other pair in the corpus is wrong. A field measurement that agrees with the first specimen and disagrees with the second is not a measurement &mdash; it is a coincidence with a number in it, which is why the sweep visits six register numbers instead of one.</li>
                    <li><strong>The condition is bits[15:12] in a select and bits[4:0] in a B.cond, and the two do not overlap.</strong> A decoder that finds one <code>cond</code> field and uses it for both gets every conditional instruction in the program wrong, in the same direction, and there is no way to tell from the output. <a href="/courses/a64asm/lessons/a64-cond">Concept 4</a> is this row's consequences.</li>
                    <li><strong>Register 31 is the stack pointer in add/sub and the zero register in the logical-shifted group, and the field is identical in both.</strong> The <code>Rd</code> mask is bits[4:0] in each case. <strong>No field map can express that difference</strong> &mdash; only a decoder that says which group it is in can, which is why the artifact's register function takes a permission flag from the model and never guesses. The mistake the cross-check actually found was the mirror image: the logical-<em>immediate</em> model calling it with the default and printing <code>sp</code> where the encoding says zero. R15.</li>
                    <li><strong><code>imm12</code> is bits[21:10] and the scale on it is a separate two-bit field</strong> that is only read when it is <code>0b01</code>. <code>add w0, w1, #0x1000</code> and <code>add w0, w1, #1, lsl #12</code> are the same 32 bits, which concept 1 measured, and <code>add w0, w1, #0x1001</code> is <strong>refused</strong> &mdash; see <a href="/courses/a64asm/lessons/a64-immediate">concept 3</a>, where the immediate story gets its own page.</li>
                </ul>
                <h3>What a mask is not</h3>
                <p>Two of the rows in that table are not contiguous, and the gaps are not measurement failures. In the conditional-select family bit 30 and bits[11:10] <em>together</em> pick the operation, and the file prints the gap so you can see the difference between "not measured" and "not one field". In the bitfield family the same bits[21:10] window holds <code>immr</code> for a BFXIL and <code>imms</code> for a BFM &mdash; two instructions sharing a field, which is not one operand.</p>
                <p>And a field this method <em>cannot</em> find is a field that is never written: reserved bits, the <code>0b11</code> value of the add/sub scale (the assembler refuses it), and the top bit of a shift amount on a 32-bit register (<code>lsl #32</code> on <code>w</code> registers is refused too). Those are measured in section 9 of the artifact by asking the assembler and printing its diagnostic verbatim.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three things that are cheaper to state than to prove</h2>
                <p>Each of these was asserted in a draft of this course, measured, and retracted. They are here rather than at the end of the course because each one is a place where the <em>obvious</em> thing to write down is wrong, and knowing which three is worth more than knowing the three facts.</p>
                <ul>
                    <li><strong>The class field is four bits, not two.</strong> The two-bit rule put <code>ret</code> in the wrong class &mdash; 134 of 868, the largest single entry in the distribution &mdash; and could not see class 01101 at all, which is where <code>csel</code>, <code>cset</code>, <code>mul</code> and <code>madd</code> live. A two-bit field is what the older documentation says and a four-bit one is what 868 assembled words say.</li>
                    <li><strong>A field map is a LOWER BOUND and a gap is a fact about the sweep.</strong> The first measurement used one pair per field, and one pair marks the bits where two <em>values</em> differ &mdash; a subset of the field. It reported an 8-bit <code>imm16</code> for a sixteen-bit field, and the table looked wrong because the table was. The fix is a sweep; the honesty is to say what a mask is not.</li>
                    <li><strong>A mask is a bit pattern and a MEANING is not.</strong> Register 31 is <code>sp</code> in add/sub and zero in the logical groups, over an identical bits[4:0]. The class names in the table above are QUOTED from the manual; the membership is MEASURED, and the two are printed in separate columns because a course that blurs them cannot say which one a reader is trusting.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the 21-model dispatch</h2>
                <p>Every model checks its own fixed bits first and returns false if they do not match, so the dispatch is a decision tree a reader can follow top to bottom rather than a table of magic numbers. <code>--audit</code> prints it with the guard each model checks, and the harness asserts that the table has 21 rows:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --audit | head -26
  model            the guard it checks                    claim
  m_adr            bits[28:24] = 0b10000, op = bit 31     ADR and ADRP
  m_addsub_imm     bits[28:24] = 0b10001                  ADD/SUB, 12-bit immediate
  m_logical_imm    bits[28:23] = 0b100100                 AND/ORR/EOR/ANDS, rotate+run
  m_movewide       bits[28:23] = 0b100101                 MOVZ/MOVN/MOVK
  m_bitfield       bits[28:23] = 0b100110                 SBFM/UBFM/BFM/BFXIL
  m_extr           bits[28:23] = 0b100111                 EXTR, and ROR as its alias
  m_bcond          bits[31:24] = 0b01010100               B.cond, imm19 at 23:5
  m_b_bl           bits[30:26] = 0b00101                  B and BL, imm26
  m_cbz            bits[30:25] = 0b011010                 CBZ and CBNZ
  m_tbz            bits[30:25] = 0b011011                 TBZ and TBNZ, imm14
  m_br_blr_ret     bits[31:23] = 0b110101100, opc=22:21   BR, BLR, RET
  m_hint           bits[31:5] = 0xd503201f &gt;&gt; 5             NOP, WFI, YIELD
  m_ldst_uimm      bits[29:27]=0b111, bits[26:24]=0b001   LDR/STR, 12-bit scaled
  m_ldst_uimm9     bits[29:27]=0b111, bits[26:24]=0b000   LDUR/STUR, 9-bit unscaled
  m_ldst_pair      bits[29:27] = 0b101                    LDP/STP, Rt2 at 14:10
  m_addsub_shifted bits[28:24] = 0b01011                  ADD/SUB shifted; Rd=31 is sp
  m_logical_shifted bits[28:24] = 0b01010                 AND/ORR shifted; Rn=31 is xzr
  m_condselect     bits[28:21] = 0b11010100               CSEL family
  m_3src           bits[30:24] = 0b0011011                MADD/MSUB/MNEG
  m_2src           bits[30:21] = 0b0011010110             LSLV..RORV, UDIV, SDIV
  m_clz_rev        bits[30:21] = 0b1011010110             CLZ, REV, REV16

  21 models, and 21 claims -- the two numbers are printed
  together because a model with no claim is a model nobody can check.
                </pre>
                </div>
                <p>The order is the dispatch order, and it is not alphabetical and not arbitrary: the two models with the largest fixed patterns (<code>m_adr</code> at five bits and <code>m_hint</code> at twenty-seven) belong near the top, because a cheap-and-specific guard belongs above an expensive general one. <strong>Reordering this list changes what the decoder resolves in the overlap, and that is a design decision rather than a refactor.</strong></p>
                <p>Three guards in that table are worth expanding, because each is a place where a wrong assumption is silent rather than loud:</p>
                <ul>
                    <li><code>m_ldst_uimm9</code> is a <em>separate model</em> from <code>m_ldst_uimm</code>, and that is a fact about the encoding rather than about tidiness. <code>ldr w0, [x1, #8]</code> and <code>ldur w0, [x1, #8]</code> both assemble, and the difference is a scale: the first is a 12-bit field scaled by the access size, the second a 9-bit field <em>unscaled</em> and signed. The first version of the field sweep put both in one row and the mask came out with two odd bits in it, which is a measurement telling you that two things are in the list that are not one field.</li>
                    <li><code>m_hint</code> guards <strong>twenty-seven bits</strong>. <code>bits[31:5] = 0xd503201f &gt;&gt; 5</code> is the most information this decoder ever discards, and the first version guarded <code>bits[31:24] = 0b11010110</code>, which is <code>0xd6</code> and not <code>0xd5</code> &mdash; and so decoded nothing in the family at all. <strong>A one-bit transcription error in a guard is indistinguishable from "this architecture has no hints".</strong></li>
                    <li><code>m_logical_shifted</code> and <code>m_addsub_shifted</code> differ by one bit in the guard (01010 against 01011) and disagree about what register 31 means. One printed <code>cmp w0, w1</code> for an <code>orr</code> and the other printed <code>mvn w0, w1</code> for an <code>orn</code>, and both were right, because the encodings really are that close together.</li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Re-measure one field yourself and compare to <code>fields.txt</code>.</strong> Pick <code>pair imm</code> and write the sweep yourself: <code>stp x0, x1, [sp]</code> against <code>[sp, #8]</code>, <code>[sp, #16]</code>, <code>[sp, #32]</code>, <code>[sp, #64]</code>, <code>[sp, #128]</code>, <code>[sp, #256]</code>. <em>(Expect mask 0x001f8000, bits[20:15], and expect the row to teach you why the reach is &plusmn;512 and not &plusmn;4095: the field is seven bits scaled by eight. Then ask the assembler for <code>[sp, #4]</code> and read the diagnostic &mdash; "index must be a multiple of 8 in range [-512, 504]" &mdash; which is a boundary stated in the words of the thing that enforces it.)</em></li>
                    <li><strong>Reproduce the single-pair mistake on purpose.</strong> In <code>a64dec.py</code>, change the <code>imm16</code> case in <code>FIELD_CASES</code> to a single variant, <code>movz w0, #0x2222</code>. <em>(Expect the mask to come out 0x00066660 &mdash; eight bits &mdash; for a sixteen-bit field, and expect nothing else in the run to notice. That is the point: a measurement that is merely wrong looks exactly like a measurement that is right unless the sweep is part of the method.)</em></li>
                    <li><strong>Break a guard by one bit and watch the corpus.</strong> In <code>m_hint</code>, change the guard from <code>0xd503201f &gt;&gt; 5</code> to <code>0xd603201f &gt;&gt; 5</code>. <em>(Expect the three <code>nop</code>s in the corpus to stop being named and to be counted as unmodelled instead, expect the section 5 bit budget to lose a row, and expect the section 12 cross-check to report fewer NAMED instructions rather than a disagreement &mdash; because an unmodelled word is out of scope, not wrong. A decoder that silently returns fewer instructions is more dangerous than one that returns a wrong name, and this is the case where you can see the difference.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/a64asm/lessons/a64-asm">concept 1</a> is the reason this page has no length arithmetic in it, and <a href="/courses/isa/lessons/isa-modrm">isa-modrm</a> is the contrast case: the ModRM byte exists because x86 needed to name a register-from-memory operand out of a fixed field, and AArch64's load/store pair spends five bits on its second register instead of two.</p>
                <p>Forwards, <a href="/courses/a64asm/lessons/a64-immediate">concept 3</a> takes the <code>imm12</code> row and the <code>imm16</code> row and finds out what the twelve unreadable bits reach, and <a href="/courses/a64asm/lessons/a64-cond">concept 4</a> takes the <code>cond</code> row and the two non-contiguous rows and finds that a fourth of the conditional-select group is UNDEFINED. <a href="/courses/a64asm/lessons/a64-verify">Concept 5</a> is where the register-31 mistake in this page is actually found &mdash; it was not found by reading this table twice.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64asm/lessons/a64-asm">Four Bytes, and a Mnemonic That Is Not In There</a></span>
                <span>Next: <a href="/courses/a64asm/lessons/a64-immediate">A Constant Is a Rotate and a Run Length</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
