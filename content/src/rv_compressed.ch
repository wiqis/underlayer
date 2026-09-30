// RISC-V: The Encoding Spectrum -- Concept 3: the compressed extension, and
// the honest half of its story.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_compressed() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Extension That Halves Instructions, and the One That Breaks Them — Underlayer")
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
            <h1>The Extension That Halves Instructions, and the One That Breaks Them</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/rvasm">RISC-V: The Encoding Spectrum</a></div>

            <div class="unit unit-why">
                <h2>Why this matters, and why it is two ideas</h2>
                <p>Everyone cites the C extension as the thing that makes RISC-V small. That is half of it, and the half everyone cites is the half that is a <em>compiler&rsquo;s</em> decision rather than a property of the encoding. The same eleven functions, with and without the letter:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/rv64imafd  -&gt; rv64imafdc/,/^$/p'
    rv64imafd  -&gt; rv64imafdc  insns   95 -&gt;   95   bytes   380 -&gt;   246
                </pre>
                </div>
                <p><strong>THE INSTRUCTION COUNT IS THE SAME.</strong> 95 and 95. Adding C did not change what the program does, how many operations it performs, or which operations those are. It changed the number of bytes, and the byte count is the only thing in this concept anyone will quote about compression.</p>
                <p>That is worth stating carefully, because the usual claim goes the other way round &mdash; that compression makes the code &ldquo;smaller&rdquo;, as if the program had less in it. It does not. <strong>The program has the same instructions in it; some of them have a shorter encoding.</strong> And the shorter encoding is not free: it was bought with a reservation of encoding space, and with a register field that cannot name eight of the thirty-two registers. Those are two different costs, they are measured separately, and this page is mostly about them.</p>
            </div>

            <div class="unit unit-model">
                <h2>What the extension reserved, and what it did not</h2>
                <p>The method here is exhaustive and it is cheap. <strong>All 65,536 half-words</strong>, written into a <code>.text</code> section as data, disassembled by the second reader, and classified twice: once by this file&rsquo;s reserved rules and once by whether the reader prints a mnemonic. A two-independent-classification check over an exhaustive set cannot be vacuous &mdash; a vacuous comparison of 49,152 items would have to compare nothing.</p>
                <p>First the boundary, because <strong>it is the thing the plan got wrong</strong>, and the correction is worth stating plainly:</p>
                <div class="hex-dump">
                <pre>  CORRECTION TO THE PLAN, AND IT IS A BIG ONE.  The plan for this
  section said: "the number of reserved 16-bit patterns you can enumerate and
  verify against the assembler".  Measured, the answer is that the assembler
  REFUSES 16,384 of the 65,536 half-word patterns -- exactly a quarter,
  exactly bits[1:0] == 0b11 -- and it refuses them with the diagnostic

      instruction length does not match the encoding

  which is not a reservation message at all.  It is the assembler saying
  "that pattern is a 32-bit instruction, and you asked me for two bytes".
                </pre>
                </div>
                <p>So there are <strong>two different questions and the plan conflated them</strong>:</p>
                <ul>
                    <li>Of the 65,536 half-word patterns, <strong>49,152 have bits[1:0] != 0b11 and are reachable as 16-bit instructions</strong>. 16,384 are not reachable <em>at all</em>, and that is a fact about the <strong>LENGTH RULE</strong> and not about the C extension. This is the number the assembler&rsquo;s refusal is reporting, and reporting it as a reservation cost is how you end up claiming the extension gave up a quarter of the space.</li>
                    <li>Of the 49,152 reachable ones, some are defined, some are HINTs, and some are RESERVED. <strong>That is the number the extension&rsquo;s cost is made of</strong>, and it is 2,409.</li>
                </ul>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --space | sed -n '/quadrant   funct3/,/^$/p'
  quadrant   funct3   code points RESERVED  HINT rules here
  q0         000      8                     -
  q0         100      2048                  -
  q1         001      64                    -
  q1         011      32                    c.lui
  q1         100      128                   c.srli, c.srai
  q2         010      64                    -
  q2         011      64                    -
  q2         100      1                     c.mv, c.add
  TOTAL               2409
                </pre>
                </div>
                <p><strong>2,409 of 49,152, which is 4.90 per cent of the reachable compressed space.</strong> Read that against the quarter the assembler refuses and the plan&rsquo;s framing is not merely wrong but <em>misleading</em>. And the <strong>distribution</strong> is the real finding: one cell &mdash; quadrant 0, funct3 = 100 &mdash; accounts for 2,048 of the 2,409, which is 85 per cent. The QUOTED reason is in the manual&rsquo;s own opcode map, which prints two columns for the RV32 and RV64 variants and marks that cell Reserved in both. The cell held C.FLWSP in the RV32 draft; the RV64 column needed the slot for C.LD; and when the two columns were merged the cell was given up entirely. <strong>2,048 code points &mdash; one twenty-fourth of the whole reachable compressed space &mdash; for one decision about one quadrant.</strong></p>
                <p>And five of the eight reserved cells are one-off rules that kill a cell because of a <em>register value</em> or an <em>immediate value</em>. All the same shape, and the shape is the point:</p>
                <ul>
                    <li><strong>C.ADDI4SPN with nzuimm = 0: 7 code points.</strong> An immediate of zero is reserved because the instruction ADDS something to <code>sp</code>, and adding zero is a different instruction. Not eight: the eighth, <code>0x0002</code>, was given to C.SLLI64 by the RV128 work. <em>One reserved code point is a code point somebody else claimed.</em></li>
                    <li><strong>C.ADDIW with rd = x0: 64.</strong> And in RV32 the same cell is C.JAL, which has no reserved code points. A reserved encoding in one base and a valid instruction in the other, at the same 16 bits &mdash; <strong>the C extension&rsquo;s modularity showing up as a portability hazard.</strong></li>
                    <li><strong>C.LUI with imm = 0: 32</strong>, and C.ADDI16SP with nzimm = 0 is the 33rd and dies with them, because the two share the cell and are told apart by the destination register.</li>
                    <li><strong>C.SUBW/C.ADDW&rsquo;s reserved half: 128.</strong> Sixteen of the thirty-two (inst[12], bits[6:2]) combinations times eight registers, and the reserved ones are exactly the two funct2 values no base assigned.</li>
                    <li><strong>C.LWSP and C.LDSP with rd = x0: 64 each, not 32</strong>, because the CI format&rsquo;s immediate is six bits and a zero register leaves all six free.</li>
                    <li><strong>And ONE code point, <code>0x8002</code></strong> &mdash; rs1 = 0 with rs2 = 0, the single combination that C.JR, C.JALR, C.EBREAK, C.MV and C.ADD all reject. It is the only reserved compressed encoding a person is likely to meet in a hex dump, and it is reserved because five rules each exclude it. Its neighbour <code>0x9002</code> is <strong>C.EBREAK</strong>, one bit away, and a decoder that reads the cell without reading inst[12] reports a legal instruction as reserved.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>The enumeration, and the one word the two readers disagree about</h2>
                <p>Two independent classifications of the same exhaustive set. &ldquo;Mine&rdquo; is what this file&rsquo;s transcribed rules say; &ldquo;oracle&rdquo; is whether the second reader prints a mnemonic:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --space | sed -n '/This file, over all 49,152/,/VERDICT/p'
    This file, over all 49,152 reachable half-words:
       2409  RESERVED by the rules transcribed above
        426  HINT -- defined, and they do nothing
      46317  neither: an instruction this file does not model

    The second reader, over the same 49,152:
      49152  instructions printed
       2408  printed &lt;unknown&gt;, i.e. it could not decode them

    THE CROSS-CHECK, over an exhaustive set:
       2408  this file says RESERVED and the reader says &lt;unknown&gt;
          1  this file says RESERVED and the reader NAMED it
          0  the reader says &lt;unknown&gt; and this file does not

    The 1 words this file calls reserved that the reader names:
      0x0000  unimp
                </pre>
                </div>
                <p><strong>2,408 of 2,409 agree, and the one that does not is <code>0x0000</code>.</strong> It gets its own paragraph rather than a footnote, because it is not a typo.</p>
                <p><code>0x0000</code> is in the C.ADDI4SPN cell with nzuimm = 0, which this file calls RESERVED &mdash; which is what the rule says and what the manual says &mdash; and the second reader prints <code>unimp</code>. <strong>Both are right about their own subject, and the disagreement IS the interesting part.</strong> <code>unimp</code> is not a claim that the encoding is an instruction. It is the second reader&rsquo;s way of saying &ldquo;there is nothing here and I will keep decoding&rdquo;, and it <em>has</em> to say something: a disassembler walks a byte stream carrying no length information, so every half-word in it must print something. The all-zeros pattern is the natural choice for &ldquo;nothing&rdquo; precisely because it is the one pattern no instruction is. The second reader has taken a position on what to <strong>PRINT</strong>; this file took a position on what is <strong>DEFINED</strong>. A check that compared the two would be comparing a table of encodings against a table of output strings.</p>
                <p>Which is why this section is allowed to finish on the word DISAGREE, and why a verification that cannot finish disagreeing is not a verification.</p>
                <h3>Seven permutations over five bit positions</h3>
                <p>The mask table in <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> says something the eye needs help with: <strong><code>c.lw</code> and <code>c.ld</code> have the IDENTICAL mask.</strong> Both are <code>0x00001c60</code>, both move five instruction bits, and they are not the same encoding. A mask records <em>where</em> a value&rsquo;s bits live. A permutation records <em>which</em> instruction bit holds <em>which</em> bit of the value. Those are different questions, and the compressed extension is a case where the first is not enough.</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --section 4 | sed -n '/^  family /,/DISTINCT/p'
  family          variants   status     the permutation, derived
  c.lw  (x4)      32         DERIVED    v[0]=inst[ 6] v[1]=inst[10] v[2]=inst[11] v[3]=inst[12] v[4]=inst[ 5]
  c.ld  (x8)      32         DERIVED    v[0]=inst[10] v[1]=inst[11] v[2]=inst[12] v[3]=inst[ 5] v[4]=inst[ 6]
  c.sw  (x4)      32         DERIVED    v[0]=inst[ 6] v[1]=inst[10] v[2]=inst[11] v[3]=inst[12] v[4]=inst[ 5]
  c.sd  (x8)      32         DERIVED    v[0]=inst[10] v[1]=inst[11] v[2]=inst[12] v[3]=inst[ 5] v[4]=inst[ 6]
  c.fld (x8)      25         DERIVED    v[0]=inst[10] v[1]=inst[11] v[2]=inst[12] v[3]=inst[ 5] v[4]=inst[ 6]
  c.fsd (x8)      25         DERIVED    v[0]=inst[10] v[1]=inst[11] v[2]=inst[12] v[3]=inst[ 5] v[4]=inst[ 6]
  c.lwsp  (x4)    64         DERIVED    v[0]=inst[ 4] v[1]=inst[ 5] v[2]=inst[ 6] v[3]=inst[12] v[4]=inst[ 2] v[5]=inst[ 3]
  c.ldsp  (x8)    64         DERIVED    v[0]=inst[ 5] v[1]=inst[ 6] v[2]=inst[12] v[3]=inst[ 2] v[4]=inst[ 3] v[5]=inst[ 4]
  c.swsp  (x4)    64         DERIVED    v[0]=inst[ 9] v[1]=inst[10] v[2]=inst[11] v[3]=inst[12] v[4]=inst[ 7] v[5]=inst[ 8]
  c.sdsp  (x8)    64         DERIVED    v[0]=inst[10] v[1]=inst[11] v[2]=inst[12] v[3]=inst[ 7] v[4]=inst[ 8] v[5]=inst[ 9]
  c.j             28         DERIVED    v[0]=inst[ 3] v[1]=inst[ 4] v[2]=inst[ 5] v[3]=inst[11] v[4]=inst[ 2] v[5]=inst[ 7] v[6]=inst[ 6] v[7]=inst[ 9] v[8]=inst[10] v[9]=inst[ 8] v[10]=inst[12]

    11 families measured, 7 DISTINCT PERMUTATIONS.
                </pre>
                </div>
                <p><strong>Eleven families, seven distinct orders.</strong> Not a rounding of eleven &mdash; these are the seven the eleven fall into: c.lw with c.sw; c.ld with c.sd, c.fld and c.fsd; and the four sp forms and c.j each alone. Read the first two rows against each other, because they are the pair this section opened with: same five positions, and <strong><code>c.lw</code> puts the offset&rsquo;s bit 0 at inst[6] while <code>c.ld</code> puts it at inst[10]</strong>. Same positions, different order, and the order is the entire difference between a 4-byte-scaled and an 8-byte-scaled displacement.</p>
                <p>So the thing to carry forward is not &ldquo;the compressed immediates are scrambled&rdquo; &mdash; the manual says that and it is obvious. It is that <strong>a decoder for the compressed extension cannot be written by REUSING the base one, by parameterising it, or by deriving it from a table of bit positions.</strong> It needs a per-instruction permutation, and the permutation is a property of the <em>pair</em> (field, instruction), not of the field. A field map &mdash; which is what concept 2 measured, and what every field map in every architecture in this collection is &mdash; is <strong>necessary and not sufficient</strong> here, and the mask table above cannot tell you that and this table can.</p>
                <p>The QUOTED reason, which is the same sentence the base gives, is worth reading because it explains why the specification is willing to pay:</p>
                <div class="hex-dump">
                <pre>&ldquo;The immediate fields are scrambled in the instruction formats instead of
 in sequential order so that as many bits as possible are in the same position
 in every instruction, thereby simplifying implementations.&rdquo;
                </pre>
                </div>
                <p>SAME position is what it got. Same position, seven orders, and an implementation needs seven multiplexers &mdash; which is the trade, stated by the people who made it, and quantified above.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The other cost: the instructions that cannot be shortened</h2>
                <p>2,409 is the <em>encoding-space</em> cost. <strong>This is a different cost, and it is not the reservation fraction.</strong> A set of instructions that cannot be shortened at all, for a reason that has nothing to do with how much space was reserved and everything to do with <a href="/courses/rvasm/lessons/rv-encoding">where the register numbers are</a>. And it is a refusal you can read:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --section 4 | sed -n '/c.mv ra, a0/,/sw t0/p'
    c.mv ra, a0         2 bytes  0x80aa  mv	ra, a0
    c.mv zero, a0       2 bytes  0x802a  c.mv	zero, a0
    c.lw t0, 0(a0)      REFUSED  invalid operand for instruction
    c.lw a0, 0(t0)      REFUSED  invalid operand for instruction
    c.lw s0, 0(a0)      2 bytes  0x4100  lw	s0, 0x0(a0)
    c.sw t0, 0(a0)      REFUSED  invalid operand for instruction
    c.sd sp, 0(a0)      REFUSED  invalid operand for instruction
    c.addw t0, a0       REFUSED  invalid operand for instruction
    sw t0, 0(a0)        4 bytes  0x552023  sw	t0, 0x0(a0)
                </pre>
                </div>
                <p><strong>Four of those nine are REFUSED by a real assembler, and the refusals are the measurement.</strong> <code>c.lw t0, 0(a0)</code> is not encodable in two bytes and <code>lw t0, 0(a0)</code> is four, and the difference is a three-bit register field. <code>t0</code> is x5; the field indexes x8&ndash;x15. A compiler that wants to compress a load from <code>t0</code> cannot, and the four bytes are the honest price.</p>
                <p>And the exception that proves the rule, because it is how a function prologue gets compressed at all:</p>
                <div class="hex-dump">
                <pre>    c.sdsp ra, 8(sp)    2 bytes  0xe406  sd	ra, 0x8(sp)
    sd ra, 8(sp)        2 bytes  0xe406  sd	ra, 0x8(sp)
    c.sdsp t0, 8(sp)    2 bytes  0xe416  sd	t0, 0x8(sp)
    c.swsp ra, 8(sp)    2 bytes  0xc406  sw	ra, 0x8(sp)
                </pre>
                </div>
                <p>Note the second row: <code>sd ra, 8(sp)</code> is <em>also</em> two bytes, because the assembler chose the compressed form for the base instruction too. The reason is in the row above: <strong>C.SDSP is a CSS format with a five-bit rs2 at inst[6:2], and <code>ra</code> is x1 which fits.</strong> C.SD in quadrant 0 is a CS format with a three-bit rs2' at inst[4:2], and x1 does not fit there.</p>
                <p>So the compressed extension CAN save a register it has no compressed form for, and it does so by adding a whole extra family of instructions whose only difference is that the base register is hardwired to x2. <strong>Nine formats became eleven.</strong> That is the mechanism, stated as a measurement, and it is why the compressed fraction in a real corpus is what it is rather than higher.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Enumerate a reserved cell yourself and count it.</strong> <em>(Quadrant 0, funct3 = 100: 2,048 code points, all reserved, because that cell held C.FLWSP in the RV32 draft and C.LD needed the slot in RV64. Write <code>.hword</code> for a handful of them, assemble, and confirm the assembler <em>accepts every one</em> &mdash; a reservation is enforced by the hardware and the disassembler, not by the assembler. See retraction R3.)</em></li>
                    <li><strong>Get the assembler to refuse a compressed load and read the message.</strong> <em>(<code>printf &quot;.text\\nc.lw t0, 0(a0)\\n&quot; &gt; t.s; clang --target=riscv64-linux-gnu -march=rv64gc -c t.s -o t.o</code> &mdash; expect &ldquo;invalid operand for instruction&rdquo;. Then <code>c.lw s0, 0(a0)</code> and expect success, and expect the successful one to be <strong>two</strong> bytes. The difference between the two lines is three bits of register field and nothing else.)</em></li>
                    <li><strong>Break one permutation and watch only the large offsets go wrong.</strong> <em>(In <code>rvdec.py</code>, make <code>c.ld</code> use <code>c.lw</code>&rsquo;s permutation. Expect offsets 0&ndash;124 to decode correctly and everything above to be wrong &mdash; and expect the wrong values to be <strong>multiples of 8, in range, and plausible</strong>. That is the specific failure section 4D exists to describe, and it is why the permutations are measured rather than read out of a figure.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> ended on the three-bit <code>rd'</code> field whose value 0 means x8, and this page is what that costs. Forwards, <a href="/courses/rvasm/lessons/rv-immediate">concept 4</a> is about the base formats&rsquo; immediates and the one that is genuinely permuted &mdash; the B type, whose highest bit lives in the position the S type uses for its lowest. <a href="/courses/rvasm/lessons/rv-verify">Concept 5</a> is where the reservation count is cross-checked against a second reader over all 49,152 reachable patterns, and where the cross-check&rsquo;s own normalisation is poisoned.</p>
                <p>Outside this course: the reserved-space question and <a href="/courses/reloc">the reloc course</a> are neighbours rather than relatives. A reserved encoding is a promise to a <em>linker</em> that the bit patterns it will never emit are free, and that is a relocation-shaped problem.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvasm/lessons/rv-encoding">Six Formats and Four Field Positions</a></span>
                <span>Next: <a href="/courses/rvasm/lessons/rv-immediate">The Immediates That Do Not Fit</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
