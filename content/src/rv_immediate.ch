// RISC-V: The Encoding Spectrum -- Concept 4: the immediates that do not fit.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_immediate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Immediates That Do Not Fit — Underlayer")
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
            <h1>The Immediates That Do Not Fit</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/rvasm">RISC-V: The Encoding Spectrum</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/rvasm/lessons/rv-encoding">Concept 2</a> measured that RISC-V keeps all three register fields at the same bit position in every format, and quoted the price: &ldquo;at the expense of having to move immediate bits across formats.&rdquo; <strong>Moving immediate bits across formats is what a permutation is.</strong> So RISC-V&rsquo;s immediate story is not five independent encodings to memorise. It is one decision &mdash; keep the registers still &mdash; paid for five different ways, and the masks in concept 2 are the receipts.</p>
                <p>There is also a decision hiding inside one of them that nobody will tell you if you only read the field table, and it is the reason two instructions you would expect to be interchangeable are not. <strong>The shift amount in <code>slli</code> is six bits wide in a twelve-bit field.</strong> <code>inst[25]</code> selects SRAI from SRLI and <code>inst[24]</code> is required to be zero, so the amount is not <code>imm[11:0]</code> at all. The only place the number 63 appears is in the assembler&rsquo;s refusal message.</p>
            </div>

            <div class="unit unit-model">
                <h2>The five, and what each one costs</h2>
                <p>Every figure below is <strong>MEASURED</strong> two ways that agree: the field transcribed from the manual&rsquo;s figures, and the reach computed from the encoding and then confirmed by asking a real assembler for the value just inside and just outside it. The agreement is the check on the transcription.</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/format   field     the reach/,/^$/p'
  format   field     the reach        MEASURED by asking    what it says one step past
  I        4096 bits  [-2048, 2047]    [-2048, 2047]        operand must be a symbol with %lo
  S        4096 bits  [-2048, 2047]    [-2048, 2047]        operand must be a symbol with %lo
  B        8191 bits  [-4096, 4094]    [-1048572, 1048578]  fixup value out of range
  U        33554417 bits             a 20-bit field, always shifted left 12  no signed range
  J        2097151 bits  [-1048576, 1048574]  [-1048576, 1048574]  fixup value out of range
                </pre>
                </div>
                <p>Read the first two rows together, because the answer is counter-intuitive and it is the first relief a decoder author gets on this architecture. <strong>The I-type and the S-type immediates are in DIFFERENT bit positions</strong> &mdash; <code>inst[31:20]</code> for one, <code>inst[31:25]</code> with <code>inst[11:7]</code> for the other &mdash; <strong>and the assembler refuses both with the SAME two numbers.</strong> Two permutations, one range, and <strong>the range is a property of the field&rsquo;s WIDTH rather than of its position.</strong> That is a direct consequence of the decision to keep the register fields still, and it is why the S format can split its immediate across the instruction without costing the programmer anything.</p>
                <p>The third refusal is a different kind of measurement and it is more interesting than the first two. <code>slli</code> with an amount of 64 is refused with &ldquo;[0, 63]&rdquo;, and the reason is that the amount is a <strong>six-bit</strong> field:</p>
                <div class="hex-dump">
                <pre>  slli a0, a0, 64 -&gt; immediate must be an integer in the range [0, 63]
                </pre>
                </div>
                <p>So the shift amount is also the thing that collides with the register positions &mdash; <strong>an immediate that has to dodge a register field is an immediate whose width is not obvious from its position</strong>, and the assembler&rsquo;s diagnostic is the only place the number 63 appears. This is a real decoder bug the artifact had: the first version printed the whole <code>inst[31:20]</code> window as the amount, so every <code>srai</code> in the corpus reported a shift amount 1,024 too large. Eight words were wrong and every one of them was a real instruction.</p>
                <h3>The B type, whose bits are not contiguous</h3>
                <p>This is the case the plan called out and it is correct. The encoding:</p>
                <div class="hex-dump">
                <pre>  imm[12]    = inst[31]     the sign, alone in bit 31 of the instruction
  imm[11]    = inst[7]      the HIGHEST bit, in the S format's LOWEST slot
  imm[10:5]  = inst[30:25]
  imm[4:1]   = inst[11:8]
  imm[0]     = 0            a CONSTANT -- not a field
                </pre>
                </div>
                <p>Three things there are worth reading twice. <strong><code>imm[0]</code> is not a field, it is a hard zero</strong>, and it is there because a branch target must be even: IALIGN is 16 after the compressed extension is added and 32 without it, so bit 0 of a branch displacement is always zero and spending a bit on it would waste a bit. The manual&rsquo;s reason is QUOTED and it is a <em>hardware</em> reason, not a tidiness one: &ldquo;By rotating bits in the instruction encoding of B and J immediates instead of using dynamic hardware multiplexers to multiply the immediate by 2, we reduce instruction signal fanout and immediate multiplexer costs by around a factor of 2.&rdquo;</p>
                <p>Second: <strong>the field is NOT contiguous and NOT in one place.</strong> It lives in <code>inst[31]</code>, <code>inst[30:25]</code> and <code>inst[11:7]</code>, and nowhere else. <strong>Thirteen of the thirty-two bits, <code>inst[24:12]</code>, are not part of the displacement at all.</strong> And third, the fact this whole course has been building toward: <strong>the field&rsquo;s top bit is in the position the S format uses for the field&rsquo;s bottom bit</strong> &mdash; the two masks differ by exactly bit 7, and <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> measured it.</p>
                <h3>Reconstructed from the bits, not quoted</h3>
                <p>The transcription is checked against known immediates rather than trusted. Twenty-six offsets assembled and decoded back, and the ends are the rows worth reading:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/asked for   the word/,/^$/p' | tail -8
  2048        0x00b500e3    beq	a0, a1, 0x800 &lt;T+0x800&gt;                     2048
  4094        0x7eb50fe3    beq	a0, a1, 0xffe &lt;T+0xffe&gt;                     4094
  -2048       0x80b500e3    beq	a0, a1, 0xfffffffffffff800 &lt;...&gt;       -2048
  -4096       0x80b50063    beq	a0, a1, 0xfffffffffffff000 &lt;...&gt;       -4096
                </pre>
                </div>
                <p>Now the row that matters, and the arithmetic behind it:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/format    near end/,/^$/p'
  format    near end    far end     symmetry                    scaled
  B         4094        4096        +4094 / 4096  NOT symmetric  x2
  I         2047        2048        +2047 / 2048  NOT symmetric
  J         1048574     1048576     +1048574 / 1048576  NOT symmetric  x2
  S         2047        2048        +2047 / 2048  NOT symmetric
  U         16777200    16777216    +16777200 / 16777216  NOT symmetric
                </pre>
                </div>
                <p><strong>The B-type reach is +4,094 and &minus;4,096.</strong> A 13-bit two&rsquo;s-complement field scaled by two, and <strong>the ends are NOT the same number</strong>. The asymmetry is arithmetic: the field holds [&minus;4,096, +4,095], the low bit is forced to zero, so the positive end is +4,094 and the negative end is &minus;4,096. <strong>A sign extension is not a magnitude, and a field with a forced zero at bit 0 is not symmetric about zero.</strong> The first draft of this artifact computed the range arithmetically and got [&minus;4,096, +4,096], and the AArch64 course retracted the same class of mistake twice in its own section. B and J are not symmetric for this reason; I and S are, because their bit 0 is not forced.</p>
            </div>

            <div class="unit unit-example">
                <h2>The best measurement in the course: what the assembler does instead of refusing</h2>
                <p>The plan said the assembler&rsquo;s diagnostic at the edge of the B-type range would be the best measurement in the concept. It is &mdash; but not for the reason the plan expected, and getting this wrong is the single most useful thing on this page.</p>
                <p>Ask for a branch past the end of the B type&rsquo;s reach. The first version of this artifact was built on the expectation that a diagnostic appears, and a section written around &ldquo;ask the assembler and read the error&rdquo; would have found no error to read:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/beq \.    /,/^$/p'
    beq .    +4096   4 bytes, bne	a0, a1, 0x8 &lt;T+0x8&gt;
    beq .    +8192   4 bytes, bne	a0, a1, 0x8 &lt;T+0x8&gt;
    beq .  +65536   4 bytes, bne	a0, a1, 0x8 &lt;T+0x8&gt;
    beq . +1048576   4 bytes, bne	a0, a1, 0x8 &lt;T+0x8&gt;
    beq . -1048576   REFUSED: fixup value out of range
                </pre>
                </div>
                <p><strong>IT DOES NOT REFUSE. It RELAXES.</strong> <code>beq a0, a1, .+4096</code> is accepted and assembled into TWO instructions: an inverted branch over an unconditional jump, because a B-type cannot reach that far and the assembler has a longer sequence that means the same thing. A reader who writes a branch past the B-type&rsquo;s reach and then <em>decodes</em> the result expecting a branch finds a conditional jump and an unconditional jump, and <strong>the branch they wrote is gone.</strong></p>
                <p>That is a refusal that is not a refusal, and it is dangerous in the specific way this course keeps looking for:</p>
                <ul>
                    <li><strong>Asking for an out-of-range branch does not produce a diagnostic.</strong> It produces <strong>WORKING CODE</strong>, of a different shape, with the semantics the programmer asked for. No test that checks &ldquo;does the program work&rdquo; finds it.</li>
                    <li><strong>A disassembler reading the object file cannot tell</strong> that a two-instruction sequence was a one-instruction request. It sees a branch and a jump.</li>
                    <li><strong>So the branch&rsquo;s reach is a property of the ENCODING</strong>, discoverable only by decoding the instruction word and looking at the displacement. And a decoder that walks a compiler&rsquo;s output will <strong>never</strong> see the boundary, because the compiler never emits one. Only a decoder that is TOLD the boundary, or fed hand-written words, will.</li>
                </ul>
                <p>And the diagnostic <em>does</em> appear eventually, at 1 MiB, where the relaxation itself runs out of room. Note the word: <strong>&ldquo;fixup&rdquo;, not &ldquo;displacement&rdquo;.</strong> It is the assembler telling you the RELAXATION could not be applied, which is a different failure from the encoding being out of range, and a tool that reports only the second would be misleading you about the first. <a href="/courses/reloc">The reloc course</a> is about what a fixup is; this is the first place a reader meets one, and it is in an error message.</p>
                <h3>And the pair the short reach forces into existence</h3>
                <p><strong>The &plusmn;2 KiB B-type range is why <code>auipc</code>+<code>addi</code> pairs exist.</strong> A branch that can only reach 2 KiB cannot reach across a function, let alone across a translation unit, so every far call in a real program is a PAIR of instructions with the address split across them. Measured on the same C, from the same compiler, and the relocations are the point &mdash; they are what makes the pair a pair rather than two instructions that happen to be adjacent:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/THE RELOCATIONS/,/^$/p'
  offset    relocation                  symbol
  0x0002    R_RISCV_HI20                table
  0x0002    R_RISCV_RELAX               *ABS*
  0x0006    R_RISCV_LO12_I              table
  0x0006    R_RISCV_RELAX               *ABS*
  0x0012    R_RISCV_HI20                label
  0x0012    R_RISCV_RELAX               *ABS*
  0x0016    R_RISCV_LO12_I              label
  0x0016    R_RISCV_RELAX               *ABS*
                </pre>
                </div>
                <p>Note that the second half is an <strong>ADD and not a generic immediate add</strong>: the RISC-V encoding has one 12-bit immediate field and the linker has to know which instruction owns it. Compare the AArch64 pair on the same C, for the same two halves:</p>
                <div class="hex-dump">
                <pre>  offset    relocation                        symbol
  0x0000    R_AARCH64_ADR_PREL_PG_HI21        table
  0x0004    R_AARCH64_ADD_ABS_LO12_NC         table
  0x0014    R_AARCH64_ADR_PREL_PG_HI21        label
  0x0018    R_AARCH64_LDST8_ABS_LO12_NC       label
                </pre>
                </div>
                <p>Three differences, all measured, and two of them are design differences rather than notational ones:</p>
                <ul>
                    <li><strong>RISC-V&rsquo;s <code>lui</code> is ABSOLUTE; AArch64&rsquo;s <code>adrp</code> is PC-RELATIVE.</strong> It is visible in the names: RISC-V&rsquo;s are <code>R_RISCV_HI20</code> and <code>R_RISCV_LO12_I</code> with no PC in either, and AArch64&rsquo;s carry <code>_PREL_</code> in both. For position-independent code &mdash; the default on both targets &mdash; the RISC-V compiler has to switch to <code>auipc</code>, which is why the corpus objects contain <code>auipc</code> and not <code>lui</code>.</li>
                    <li><strong>RISC-V&rsquo;s <code>lui</code> and AArch64&rsquo;s <code>adrp</code> are not the same reach.</strong> A U-type carries 20 bits at the top of a 32-bit value; <code>adrp</code> carries 21 bits of a <em>page-aligned</em> address. That is a different pair of halves, and the two architectures solved the same problem with the same <em>shape</em> and different <em>widths</em> &mdash; which is exactly the sort of difference a course that teaches only the shape would miss.</li>
                    <li><strong>The low half is not marked as part of a pair in the ENCODING.</strong> There is no bit anywhere in the <code>addi</code> that says &ldquo;this addi is the second half of an address&rdquo;. The pairing is a property of the RELOCATION TABLE, which means a decoder reading bytes in isolation &mdash; which is what this file&rsquo;s part one does &mdash; <strong>cannot recover the address a program intended.</strong> AArch64 has the same property and solves it the same way.</li>
                </ul>
            </div>

            <div class="unit unit-reality">
                <h2>What this section cannot show</h2>
                <ul>
                    <li><strong>Nothing here is linked, so nothing here is proved correct.</strong> Everything above is a property of a COMPILED OBJECT FILE. There is no linked executable on this host, no resolved address, and no RISC-V linker installed &mdash; <code>riscv64-linux-gnu-ld</code> is absent. What is measured is the two instructions and their two relocations, which is the half of the story that is in the bytes. <strong>The other half &mdash; that the pair lands on the right address &mdash; is not measured here, is not measured anywhere in this course, and would need <a href="/courses/link">the link course</a> and a machine.</strong></li>
                    <li><strong>The reaches are exact; the instruction counts are not.</strong> A field&rsquo;s reach is arithmetic and belongs to the encoding forever. Whether a compiler emits a pair instead of a single instruction is a property of <code>clang</code> at this version on this source, and the <code>auipc</code>-versus-<code>lui</code> choice in particular is a position-independent-code decision that a different link model would change.</li>
                    <li><strong>No timings.</strong> The relaxation is real and its cost is a real code-size cost, and the number of instructions the sequence costs is not the number of cycles it costs, because there is no RISC-V hardware on this host to count anything.</li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Ask the assembler for the boundary you predicted and read what it prints.</strong> <em>(<code>beq a0, a1, .+4094</code> assembles to one instruction. <code>beq a0, a1, .+4096</code> assembles to <strong>two</strong>. Disassemble both. Then write the one-instruction version by hand as <code>.insn 4, 0x&hellip;</code> and confirm the assembler will not take it. That is the boundary, and it is discoverable three ways: arithmetic, a refusal, and the shape of the output.)</em></li>
                    <li><strong>Reconstruct the B immediate by hand for three displacements and check your permutation.</strong> <em>(+2,048 is <code>0x00b500e3</code> and &minus;4,096 is <code>0x80b50063</code>. Get +2,048 wrong in a way that keeps the parity &mdash; for example by putting inst[8] in imm[0], which the artifact&rsquo;s first version did &mdash; and the target comes out <strong>odd</strong>, which is a displacement no RISC-V instruction can encode. That bug cost 26 words of the corpus and every one of them produced a plausible-looking address.)</em></li>
                    <li><strong>Find the six-bit field nobody documented in the field table.</strong> <em>(<code>slli a0, a0, 64</code> is refused with &ldquo;[0, 63]&rdquo;. Ask for <code>slli a0, a0, 32</code> and get the four bytes, then read <code>inst[25:20]</code> and notice that two of the six bits are not part of the amount. A decoder that prints <code>inst[31:20]</code> gets <code>slli</code> right by luck and <code>srai</code> wrong by 1,024, which is what this artifact did for eight words before the cross-check found it.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/rvasm/lessons/rv-encoding">concept 2</a> measured the two masks that differ by one bit, and this page is what that one bit costs in reach. Across, <a href="/courses/a64asm/lessons/a64-immediate">a64-immediate</a> is the same problem with a different answer: AArch64&rsquo;s logical immediate is a rotate and a run length and reaches 1,302 of 4,294,967,296 constants, where RISC-V reaches <em>every</em> 12-bit value and reaches nothing beyond it without a pair. <a href="/courses/exe/lessons/exe-verify">exe-verify</a> is the course that would check that the pair lands on the right address, and this page is the last place before it where the question is open.</p>
                <p>Forwards, <a href="/courses/rvasm/lessons/rv-verify">concept 5</a> is where the <code>fixup value out of range</code> message in this page gets its explanation &mdash; because that word is the first appearance of a relocation in the course, and the verification concept is where relocations stop being an error message and become a thing you can read.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvasm/lessons/rv-compressed">The Extension That Halves Instructions, and the One That Breaks Them</a></span>
                <span>Next: <a href="/courses/rvasm/lessons/rv-verify">Decode It Yourself, Twice, and Poison It</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
