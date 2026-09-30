// RISC-V: The Encoding Spectrum -- Concept 2: the six formats and the
// measured field map.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_encoding() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Six Formats and Four Field Positions — Underlayer")
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
            <h1>Six Formats and Four Field Positions</h1>
            <div class="lesson-meta">30 min &middot; <a href="/courses/rvasm">RISC-V: The Encoding Spectrum</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/rvasm/lessons/rv-isa">Concept 1</a> established that the ISA is a set of documents. This concept takes the document that matters most for a decoder &mdash; the base integer set &mdash; apart at the bit level, and it opens with a retraction, because the plan this course was written from got the central prediction <strong>backwards</strong>.</p>
                <p>The plan said: &ldquo;the same register number sits in different bit positions in different formats, and that is why an assembler is not a lookup table.&rdquo; Measured, the first half is <strong>false</strong> and the second half is true for a different reason. Here is the measurement, and then what it costs.</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --fields | sed -n '/^  field  /,/rs2, in the R/p'
  field                         xor mask      vars   the bit positions it moved   what
  rd, in the R format           0x00000f80    20     7,8,9,10,11                 rd
  rs1, in the R format          0x000f8000    20     15,16,17,18,19              rs1
  rs2, in the R format          0x01f00000    20     20,21,22,23,24              rs2
                </pre>
                </div>
                <p>And those same three positions, on the I format, the S format, the B format and the U format: <strong>bits[11:7], bits[19:15], bits[24:20], every time.</strong> The manual says so and says why, and it is QUOTED, section 2.2:</p>
                <div class="hex-dump">
                <pre>&ldquo;The RISC-V ISA keeps the source (rs1 and rs2) and destination (rd)
 registers at the same position in all formats to simplify decoding.&rdquo;

and in the note: &ldquo;Decoding register specifiers is usually on the critical
paths in implementations, and so the instruction format was chosen to keep all
register specifiers at the same position in all formats at the expense of
having to move immediate bits across formats.&rdquo;
                </pre>
                </div>
                <p><strong>The registers stay still and the immediates pay for it.</strong> That is the whole trade, in the specification&rsquo;s own words, and the rest of this concept is the bill.</p>
            </div>

            <div class="unit unit-model">
                <h2>The six formats, and where the manual&rsquo;s four are</h2>
                <p>The count is six and the manual&rsquo;s own count is four, and both are right about different things. <strong>QUOTED</strong>, section 2.2: &ldquo;In the base RV32I ISA, there are four core instruction formats (R/I/S/U)&rdquo;; and then section 2.3: &ldquo;There are a further two variants of the instruction formats (B/J) based on the handling of immediates.&rdquo;</p>
                <p>So: <strong>four core formats plus two immediate variants</strong>, and the six names are the union. A course that said &ldquo;RISC-V has six formats&rdquo; and left it there would be implying the manual counts six, and it does not. The distinction is not pedantic: the four core formats are four <em>field layouts</em>, and the two variants are rearrangements of layouts that already exist. B is S with the immediate moved. J is U with the immediate moved and the two register slots spent on the displacement instead.</p>
                <div class="hex-dump">
                <pre>  format   inst[31:0]                                name       what it is for
  R        funct7|rs2|rs1|funct3|rd|opcode           reg-reg     no immediate at all
  I        imm[11:0]|rs1|funct3|rd|opcode            reg-imm     CONTIGUOUS at inst[31:20]
  S        imm[11:5]|rs2|rs1|funct3|imm[4:0]|opcode  store      no rd, so the imm is split
  B        imm[12|10:5]|rs2|rs1|funct3|imm[4:1|11]|op  branch     target must be EVEN
  U        imm[31:12]|rd|opcode                       upper imm   20 bits already in place
  J        imm[20|10:1|11|19:12]|rd|opcode           jump        no rs1, no rs2, so 20 bits
                                                                     become 21
                </pre>
                </div>
                <p>Read the R row and the S row together, because that pair is the whole of the register-position decision. R has no immediate, so its five register-ish fields use all 32 bits: seven of opcode, three of funct3, seven of funct7, five each of rd, rs1 and rs2. <strong>S has no destination</strong> &mdash; a store writes to memory, not to a register &mdash; and the five bits the destination would have occupied are the low five bits of the immediate instead. That is the whole of the S format and it is why the S immediate is in two places.</p>
                <p>And read the B row against the S row again, because the relationship is stated in the manual and it is the sharpest single fact in the base encoding. <strong>QUOTED</strong>, section 2.3:</p>
                <div class="hex-dump">
                <pre>&ldquo;The only difference between the S and B formats is that the 12-bit
 immediate field is used to encode branch offsets in multiples of 2 in the B
 format. Instead of shifting all bits in the instruction-encoded immediate
 left by one in hardware as is conventionally done, the middle bits (imm[10:1])
 and sign bit stay in fixed positions, while the lowest bit in S format
 (inst[7]) encodes a high-order bit in B format.&rdquo;
                </pre>
                </div>
                <p>Read it twice. <strong>In S, inst[7] is the immediate&rsquo;s bit 0. In B, inst[7] is the immediate&rsquo;s bit 11.</strong> The same bit position, the same instruction width, the same seven-bit funct7 slot above it &mdash; and it is the <em>top</em> of the displacement instead of the bottom. The masks see it exactly:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --fields | sed -n '/the S immediate/,/the B funct3/p'
  the S immediate, via sw       0xfe000e00    11     9,10,11,25,26,27,28,29,30,31  imm
  the B immediate, 17 offsets   0xfe000f80    17     7,8,9,10,11,25,26,27,28,29,30,31  imm
                </pre>
                </div>
                <p>Two masks, ten bits each, and they differ by <strong>exactly bit 7</strong>. One bit, one position, the two ends of a displacement.</p>
            </div>

            <div class="unit unit-example">
                <h2>The masks, and what a mask is not</h2>
                <p>The method: assemble an instruction, change <em>one</em> operand, assemble it again, and OR the XOR over a <strong>sweep</strong> of variants. Every bit that moves belongs to that operand. Three rules make it work, and all three are the results of getting it wrong first.</p>
                <ul>
                    <li><strong>Sweep, do not pair.</strong> A single pair marks the bits where two <em>values</em> differ, which is a subset of the field. <code>addi a1, a1, 0</code> against <code>addi a1, a1, 0x800</code> differs in ONE bit of a twelve-bit field, and the first version of this artifact reported a one-bit <code>imm</code> &mdash; a plausible-looking wrong answer rather than an obvious failure.</li>
                    <li><strong>A mask is a LOWER BOUND.</strong> Every bit in it really does belong to that operand; a bit <em>outside</em> it is a bit this sweep did not happen to move. The file prints the sweep&rsquo;s size next to every row so the two are never confused.</li>
                    <li><strong>Do not run the sweep at an <code>-march</code> that rewrites the format.</strong> The first version ran at <code>-march=rv64gcv</code>, and then <code>lw a0, 8(a1)</code> assembled to a <strong>two-byte</strong> <code>c.lw</code>. The XOR mixed a 2-byte word with 4-byte words and produced a mask with nine bits scattered across both halves of the instruction. <strong>A field map measured through an extension that rewrites the format is a field map of the wrong architecture.</strong> The base sweeps now run at <code>-march=rv64g</code>.</li>
                </ul>
                <p>Here is the base table, and the immediate rows are the interesting half because the registers are the same everywhere:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --fields | sed -n '/^  field  /,/the opcode/p'
  field                         xor mask      vars   the bit positions it moved
  rd, in the R format           0x00000f80    20     7,8,9,10,11
  rs1, in the R format          0x000f8000    20     15,16,17,18,19
  rs2, in the R format          0x01f00000    20     20,21,22,23,24
  funct7+funct3, 9 base R ops   0x42007000    9      12,13,14,25,30
  funct3, the 6 other load sizes  0x00007000   6     12,13,14
  imm[11:0], the I format       0xfff00000    15     20,21,22,23,24,25,26,27,28,29,30,31
  the S immediate, via sw       0xfe000e00    11     9,10,11,25,26,27,28,29,30,31
  the B immediate, 17 offsets   0xfe000f80    17     7,8,9,10,11,25,26,27,28,29,30,31
  the B funct3, 6 branches      0x00007000    5      12,13,14
  the U immediate, 20 bits      0xfffff000    10     12,13,...,31
  the J immediate, 20 offsets   0xfffff000    18     12,13,...,31
                </pre>
                </div>
                <p><strong>A WINDOW AND A FIELD ARE DIFFERENT OBJECTS.</strong> That is the sentence to carry to the next architecture. The U and J masks are <em>identical</em> &mdash; both <code>0xfffff000</code>, twenty contiguous bits at <code>inst[31:12]</code> &mdash; and the two immediates are nothing alike. U is 20 bits at the top of a 32-bit value with twelve zeros below. J is 21 bits scaled by two with a zero at the bottom, spread across <code>inst[19:12]</code> and <code>inst[30:20]</code> in a permuted order. <strong>A mask says two fields occupy the same WINDOW. It does not say they are the same FIELD</strong>, and a decoder that reads the J immediate as a contiguous 20-bit field gets every displacement in [-2048, 2046] right &mdash; which is the small ones &mdash; and every larger one wrong.</p>
                <h3>funct7: the clearest example of a lower bound in the course</h3>
                <p>The <code>funct7+funct3</code> row moved <strong>bits 25 and 30</strong> out of a seven-bit field, and a reader is entitled to ask whether the measurement failed. It did not, and the reason is the field is <em>not</em> seven bits of one thing:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --section 4 | sed -n '/^  source  /,/fclass/p'
  source                      word          inst[31:25]   inst[26:25]  funct3
  add a0, a1, a2              0x00c58533    0000000       00           0
  sub a0, a1, a2              0x40c58533    0100000       00           0
  sll a0, a1, a2              0x00c59533    0000000       00           1
  mul a0, a1, a2              0x02c58533    0000001       01           0
  fadd.s fa0, fa1, fa2        0x00c5f553    0000000       00           7
  fsub.s fa0, fa1, fa2        0x08c5f553    0000100       00           7
  fmin.s fa0, fa1, fa2        0x28c58553    0010100       00           0
  fsqrt.s fa0, fa1            0x5805f553    0101100       00           7
  fcvt.w.s a0, fa0            0xc0057553    1100000       00           7
                </pre>
                </div>
                <p><code>add</code> has funct7 = <code>0b0000000</code> and <code>sub</code> has <code>0b0100000</code>. One bit apart. Those are the only two values the base R format can reach from an add/sub pair, so a sweep over nine base operations moves bit 30 and not the other six &mdash; except that <code>mul</code> has funct7 = <code>0b0000001</code>, which moves bit 25. <strong>To move the REST you have to leave the base ISA, because in the base ISA there is nothing else in funct7.</strong> The F and D extensions fill it, and the table above reaches all seven positions.</p>
                <p>Both numbers are true, they measure different things, and a course that printed only the first would have claimed a two-bit funct7:</p>
                <div class="hex-dump">
                <pre>    The base sweep moved bits 25,30 of funct7's seven positions.
    The table above reaches all seven.  Both numbers are true,
    they measure different things, and a course that printed
    only the first would have claimed a two-bit funct7.
                </pre>
                </div>
                <p>And the reason the manual&rsquo;s <code>funct7</code> column heading is a simplification: <strong>under opcode 0x53 those seven bits are a five-bit operation selector at inst[31:27] and a two-bit width at inst[26:25]</strong>, and there is no way to read them as one seven-bit funct7 at all. <code>fadd.s</code> and <code>fadd.d</code> differ in inst[25] &mdash; <strong>one bit</strong>. The first version of this artifact&rsquo;s <code>r_fp</code> model read a seven-bit funct7 and therefore could not tell them apart, and separately could not tell <code>fsqrt.s</code> from <code>fadd.s</code>, because for the square root the same five bits are the high half of the selector.</p>
                <p>One more thing about funct7 that is a dispatch bug rather than a width bug, and it is the defect that shaped the whole of <a href="/courses/rvasm/lessons/rv-verify">concept 5</a>: <strong>a sub-opcode selector is not self-contained.</strong> <code>fmadd.s</code> is inst[31:27] = <code>0b01101</code> with opcode 0x43. <code>fmin.s</code> is inst[31:27] = <code>0b00101</code> with opcode 0x53. Two different five-bit values, so that is not the sharpest case &mdash; but <code>fadd.s</code> is inst[31:27] = <code>0b00001</code> under opcode 0x53 and <code>add</code> is inst[31:25] = <code>0b0000000</code> under opcode 0x33, and the floating-point one has funct3 = 7 where the integer one has funct3 = 0. <strong>A dispatch that asks models in order without first reading the opcode resolves these by list position, which is not a decoding strategy, it is a coin flip with a plausible-looking output.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The compressed extension&rsquo;s second register encoding</h2>
                <p>Everything above is the base ISA, and everything above is <em>the same in every format</em>. Here is the one place where RISC-V has <strong>a second way to name a register</strong>, and it is the trap this course calls the sharpest:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --fields | sed -n '/C CR: rd/,/C CB: rd/p'
  C CR: rd, five bits           0x00000f80    20     7,8,9,10,11      rd (5 bits)
  C CR: rs2, five bits          0x0000007c    20     2,3,4,5,6        rs2 (5 bits)
  C CI: rd, five bits           0x00000f80    20     7,8,9,10,11      rd (5 bits)
  C CA: rd-prime                0x00000380    8      7,8,9            rd' (3 bits)
  C CA: rs2-prime               0x0000001c    8      2,3,4            rs2' (3 bits)
  C CL: rd-prime                0x0000001c    8      2,3,4            rd' (3 bits)
  C CL: rs1-prime               0x00000380    8      7,8,9            rs1' (3 bits)
                </pre>
                </div>
                <p>Four fields, two positions, two widths. <code>c.mv</code> keeps rd at bits[11:7] and <code>c.mv</code>&rsquo;s rs2 at bits[6:2] &mdash; the base positions, unchanged, which is what the manual means by &ldquo;when the full 5-bit destination register specifier is present, it is in the same place as in the 32-bit RISC-V encoding&rdquo;. And <code>c.add rd', rs2'</code> puts rd' at bits[9:7] and rs2' at bits[4:2]: <strong>three bits each, two positions lower.</strong></p>
                <p>And here is the part the bit positions do not tell you: <strong>the value 0 in rd' does not mean x0. It means x8.</strong> The three-bit field <em>indexes</em> the eight registers x8 to x15. The manual prints the table:</p>
                <div class="hex-dump">
                <pre>  000 x8  001 x9  010 x10  011 x11  100 x12  101 x13  110 x14  111 x15
  s0    s1    a0    a1    a2    a3    a4    a5
                </pre>
                </div>
                <p><strong>A decoder that reads a compressed register with a five-bit lookup reports x0 to x7 where the encoding means x8 to x15. Every register name in the disassembly is seven too small, every operand is a real register, and nothing about the output looks wrong.</strong> That is a decoder bug with no symptom, which is why <a href="/courses/rvasm/lessons/rv-verify">concept 5</a> is worth its twenty minutes.</p>
                <p>And the QUOTED reason those eight are <em>those</em> eight &mdash; because the coupling is the point, and it is between three things no single specification reveals:</p>
                <div class="hex-dump">
                <pre>&ldquo;The RISC-V ABI was changed to make the frequently used registers map to
 registers x8-x15. This simplifies the decompression decoder by having a
 contiguous naturally aligned set of register numbers.&rdquo;
                </pre>
                </div>
                <p>So the compression is not only an encoding decision. <strong>It is a decision that REQUIRES an ABI that puts the eight most-used registers in a contiguous run, and the ABI was changed to make it possible.</strong> A coupling between an instruction encoding, a register file and a calling convention. <a href="/courses/rvasm/lessons/rv-compressed">Concept 3</a> measures what that coupling costs.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Measure the S and B immediates yourself and check the one-bit difference.</strong> <em>(Sweep <code>sw a0, N(a1)</code> over N = 0, 4, 8, &hellip;, 2040 and OR the XOR. Expect mask <code>0xfe000e00</code>, bits[31:25] and bits[11:7], ten positions. Then sweep <code>beq a0, a1, N</code> over even N. Expect <code>0xfe000f80</code> and expect the difference to be bit 7 and nothing else. Then ask the assembler for <code>sw a0, 2048(a1)</code> and read why.)</em></li>
                    <li><strong>Verify the three-bit register trap on purpose.</strong> <em>(In <code>rvdec.py</code>, change <code>creg3</code> from <code>return xreg(8 + (n &amp; 7))</code> to <code>return xreg(n &amp; 7)</code> and re-run. Expect the section 10 cross-check to report a large disagreement count that is entirely <code>c.*</code> words, and expect every one of them to be a register name that is seven too small. Nothing crashes. Nothing looks wrong. <strong>This is the exercise the whole cross-check concept is built for</strong>, and doing it by hand is worth more than reading about it.)</em></li>
                    <li><strong>Find the one bit that separates <code>c.jr</code> from <code>c.jalr</code> and then find the model that gets it wrong.</strong> <em>(It is inst[12], and the artifact&rsquo;s first version dispatched on <code>rs1 == 0</code> instead &mdash; which is not a bit of that cell at all. Expect <code>c.mv</code> to have been unreachable and 33 corpus words to have reported as <code>c.add</code>, and expect <code>c.jalr</code> to have reported as <code>c.jr</code>, which is a decoder that turns every indirect call into an indirect jump. The cross-check found it only because the canonical form for <code>c.jr</code> and <code>c.jalr</code> was written so that conflating them produces a disagreement rather than a silent error.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-isa">concept 1</a> is where the funct7 value that the M extension fills came from, and this page is where the cost of it becomes visible: <a href="/courses/a64asm/lessons/a64-encoding">a64-encoding</a> measured 58 field positions for AArch64 and found the class field four bits wide, because AArch64 has no prefixes and no length arithmetic and so can spend bits on a class. RISC-V has the same <em>goal</em> &mdash; keep the register specifiers still &mdash; and a completely different <em>mechanism</em>, because the C extension&rsquo;s second register encoding means the register position is not uniform after all, only uniform within the base.</p>
                <p>Forwards, <a href="/courses/rvasm/lessons/rv-compressed">concept 3</a> finishes the compressed half: the nine formats, the reserved code points, and the eleven families of displacement that share five bit positions and are assigned <strong>seven different orders</strong>. <a href="/courses/rvasm/lessons/rv-immediate">Concept 4</a> takes the two masks that differ by one bit and finds out what a 13-bit permuted displacement actually reaches.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvasm/lessons/rv-isa">A Set of Documents, Not a List</a></span>
                <span>Next: <a href="/courses/rvasm/lessons/rv-compressed">The Extension That Halves Instructions, and the One That Breaks Them</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
