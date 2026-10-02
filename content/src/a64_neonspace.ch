// The AArch64 Data Path: NEON, Atomics and Ordering -- Concept 2:
// The Shared Memory Space, and the bit SVE does not have.
//
// The page's whole argument is one command: compile the same SVE instruction
// at five vector lengths and get five identical words.  Everything around it --
// the shared class field, the two register files SVE adds, the twelve names
// the operation field carries -- is the mechanism that makes the absence
// affordable, and the four refusals at the end are the price of sharing.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_neonspace() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Shared Memory Space, and the Bit SVE Does Not Have — Underlayer")
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
            <h1>The Shared Memory Space, and the Bit SVE Does Not Have</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64simd">The AArch64 Data Path: NEON, Atomics and Ordering</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Advanced SIMD, the floating-point extensions, SVE, SVE2 and the cryptographic extensions are <strong>separate architectural extensions that share one instruction encoding space and one set of registers.</strong> [QUOTED] (ARM DDI 0602 for the SVE half; DDI 0487 for the Advanced SIMD half; the FEAT definitions in the Arm Architecture Reference Manual's appendix.)</p>
                <p>The register sharing is the load-bearing part and it is what the shared-resource rule means: an implementation that has SVE also has Advanced SIMD, on the same physical registers, and SVE's <code>Z0</code>'s bottom 128 bits <em>are</em> Advanced SIMD's <code>V0</code>. One file register, two views, and the second view is wider.</p>
                <p>Now the consequence, and it is measurable in one command. If the encoding had to say how wide a vector is, it would need a field, and that field would have to be as wide as the widest vector any implementation might have. SVE's vector length is at most 2048 bits, so a length field would be four bits and every instruction would pay for it. So <strong>SVE does not have one</strong>, and the space it shares is what makes that affordable.</p>
                <p>This is the page where a reader who came from a fixed-width SIMD model has to unlearn something. Advanced SIMD <em>must</em> spend a bit on 128 bits because Advanced SIMD vectors <em>are</em> 128 bits. SVE does not spend a bit, because the width is a property of the <strong>implementation</strong> and is read at run time from the vector length register rather than from the instruction. [QUOTED]</p>
            </div>

            <div class="unit unit-model">
                <h2>The measurement: five compiles, five identical words</h2>
                <div class="hex-dump">
                <pre>$ for b in 128 256 512 1024 2048; do
&gt;   clang --target=aarch64-linux-gnu -march=armv8.2-a+sve \
&gt;         -msve-vector-bits=$b -S -x assembler - -o /dev/null &lt;&lt;EOF
&gt; .text
&gt; add z0.d, p0/m, z0.d, z1.d
&gt; EOF
  done

-msve-vector-bits   the same instruction assembles to
  ------------------ ----------------------------------------
  128    bits        0x04c00020
  256    bits        0x04c00020
  512    bits        0x04c00020
  1024   bits        0x04c00020
  2048   bits        0x04c00020

  [MEASURED-ON-BYTES]  5 of 5 are the SAME WORD, from 128 bits to
  2048 bits -- a factor of SIXTEEN in vector length and NOT ONE BIT
  of difference.  That is the whole claim, and it takes one command.
                </pre>
                </div>
                <p>Same instruction, five vector lengths, one word. <strong>A factor of sixteen in vector length and not one bit of difference.</strong> If you have been reading a manual for a field map, this is the moment to notice that the field you were looking for is not missing from this page's diagram — it is <em>not in the architecture</em>.</p>
                <h3>What the word does carry</h3>
                <div class="hex-dump">
                <pre>  [MEASURED]  the field the size DOES live in, for SVE:
     size = 0  (element  8 bits)  0x04000000  xor 0x00c00020
     size = 1  (element 16 bits)  0x04400000  xor 0x00800020
     size = 2  (element 32 bits)  0x04800000  xor 0x00400020
     size = 3  (element 64 bits)  0x04c00000  xor 0x00000020
     TWO bits at bits[23:22] carry all four element sizes and there
     is no fourth bit anywhere for the vector LENGTH.

  [MEASURED-ON-BYTES]  and the operation is a SIX-BIT field, twelve
  handlers, one assemble each:
     add   0x04c00020  op[21:16] = 000000  class = 00000100
     sub   0x04c10020  op[21:16] = 000001  class = 00000100
     umax  0x04c90020  op[21:16] = 001001  class = 00000100
     smin  0x04ca0020  op[21:16] = 001010  class = 00000100
     umin  0x04cb0020  op[21:16] = 001011  class = 00000100
     mul   0x04d00020  op[21:16] = 010000  class = 00000100
     sdiv  0x04d40020  op[21:16] = 010100  class = 00000100
     udiv  0x04d50020  op[21:16] = 010101  class = 00000100
     orr   0x04d80020  op[21:16] = 011000  class = 00000100
     eor   0x04d90020  op[21:16] = 011001  class = 00000100
     and   0x04da0020  op[21:16] = 011010  class = 00000100
     bic   0x04db0020  op[21:16] = 011011  class = 00000100
                </pre>
                </div>
                <p>Compare that with concept 1's arithmetic groups. There the width was a suffix and a Q bit; here the width is <strong>two bits at <code>bits[23:22]</code></strong> and the operation is <strong>six bits at <code>bits[21:16]</code></strong> — the same size field, immediately next to a name table twelve entries long. A decoder with one "size" constant gets concept 1 right and this page right and still has no idea why, because they are different fields that happen to agree.</p>
                <h3>Two register files, added on top of the same thirty-two</h3>
                <div class="hex-dump">
                <pre>  [MEASURED-ON-BYTES]  and the two register files SVE adds, swept:
     z0   0x04c00000  xor 0x00000020
     z1   0x04c00020  xor 0x00000000
     z15  0x04c001e0  xor 0x000001c0
     z31  0x04c003e0  xor 0x000003c0
     Z0 through Z31 -- five bits, the same width as a scalar
     register field and the same width as an Advanced SIMD V
     field, and NOTHING else in the word for how wide those
     registers are.

  [MEASURED]  and the restriction the assembler adds that the field
  does not: the SVE predicates are FOUR bits wide in the encoding
     whilelo p0.d   0x25e11c00  xor 0x00000000
     whilelo p1.d   0x25e11c01  xor 0x00000001
     whilelo p2.d   0x25e11c02  xor 0x00000002
     whilelo p3.d   0x25e11c03  xor 0x00000003
     whilelo p4.d   0x25e11c04  xor 0x00000004
     add z0.d, p8/m  -&gt; invalid restricted predicate register, expected p0..p7
     so bits[3:0] address SIXTEEN predicates and the arithmetic
     form may use only p0..p7 -- a restriction the ENCODING does not
     express and only the assembler enforces.
                </pre>
                </div>
                <p>Thirty-two Z registers in five bits. Sixteen predicates in <em>four</em> bits — and the arithmetic form may use only eight of them. <strong>An enforcement the encoding does not express is a rule with no bytes behind it.</strong> That last sentence generalises: the assembler is the only enforcement point for a large fraction of what the manual calls "reserved", and a rule enforced only by an assembler is a rule a second assembler is free to get wrong.</p>
                <p>And the destination is <em>also</em> the second source. [MEASURED] The assembler refuses <code>add z0.d, p0/m, z1.d, z1.d</code>, so there are only three register fields here — <code>bits[4:0]</code>, <code>bits[9:5]</code> and the predicate at <code>bits[12:10]</code> — and the second reader prints the destination <strong>twice</strong>. A decoder that "fixes" the repeated operand names a register the word does not contain.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this measurement cannot show</h2>
                <p>It cannot show that a 2048-bit vector actually has 2048 bits, or that <code>Z0</code>'s bottom 128 bits are <code>V0</code>, or that any SVE instruction runs. The claim "the length is not in the instruction" is <strong>MEASURED</strong>; the claim "the length is therefore correct at run time" is <strong>QUOTED</strong> and needs silicon. That is a one-line argument and it is the whole course in miniature.</p>
                <p>It cannot show <em>which</em> extensions an implementation has. The feature registers are readable only at EL1 and there is no EL1 here. The class field is shared whether or not every member of the space is present — which is the definition of a shared space and also the reason the decode is a function of the CPU.</p>
                <h3>The class field, and what sharing costs</h3>
                <div class="hex-dump">
                <pre>family                    word         binary                                class field
  ------------------------ ----------- ------------------------------------ ----------------
  Advanced SIMD, 128-bit   0x4ea28420  01001110101000101000010000100000     bits[28:25] = 0111
  Advanced SIMD, 64-bit    0x0ea28420  00001110101000101000010000100000     bits[28:25] = 0111
  SVE, .d                  0x04c00020  00000100110000000000000000100000     bits[28:25] = 0010
  SVE, .s                  0x04800020  00000100100000000000000000100000     bits[28:25] = 0010
  SVE, .h                  0x04400020  00000100010000000000000000100000     bits[28:25] = 0010
  SVE, .b                  0x04000020  00000100000000000000000000100000     bits[28:25] = 0010
  FP scalar, .d            0x1e622820  00011110011000100010100000100000     bits[28:25] = 1111
  AES (FEAT_AES)           REFUSED     instruction requires: aes            bits[28:25] = ?
  SHA-256 (FEAT_SHA2)      REFUSED     instruction requires: sha2           bits[28:25] = ?
  SVE predicate            0x25e11c00  00100101111000010001110000000000     bits[28:25] = 0010
  SVE load                 0xa5e0a000  10100101111000001010000000000000     bits[28:25] = 0010
  SVE store                0xe5e0e000  11100101111000001110000000000000     bits[28:25] = 0010

  [MEASURED-ON-BYTES]  the class field bits[28:25] is 0b0111 for the
  Advanced SIMD data-processing group, the FP groups, AES and SHA-2,
  and 0b0010 for the SVE data-processing group -- so four extensions
  and two architectures share the space by sharing a class.
                </pre>
                </div>
                <p>So sharing is done by sharing a <em>class</em>: <code>0b0111</code> for the Advanced SIMD / FP / AES / SHA-2 families, <code>0b0010</code> for the SVE data-processing group. That is the cheap way to do it and it is exactly why a decoder needs to know the CPU.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the four refusals, and what they cost</h2>
                <p>The other half of a shared space is an assembler that does not have every member of it. And when it says so, <strong>it says so by name</strong> — and the name is architecture rather than assembler:</p>
                <div class="hex-dump">
                <pre>     aese v0.16b, v1.16b     at baseline -&gt; "instruction requires: aes"
     ldapr w1, [x0]          at 8.1-a    -&gt; "instruction requires: rcpc"
     ldapr w1, [x0]          at 8.3-a    -&gt; accepted, 0xdac0dc01
     cas  w1, w2, [x0]       at baseline -&gt; "instruction requires: lse"
     fadd h0, h1, h2         at baseline -&gt; "instruction requires: fullfp16"
                </pre>
                </div>
                <p>Five refusals, five feature names, and the whole feature-gating story of the architecture in five lines of diagnostic. Note the middle one: <code>ldapr</code> is refused at <code>armv8.1-a</code> and accepted at <code>armv8.3-a</code>, so <strong>FEAT_RCPC is armv8.3-a and not armv8.1-a</strong> — a fact you would otherwise have to look up, obtained here by moving one flag.</p>
                <p>And note what the refusals are <em>not</em>:</p>
                <div class="formula">
   A REFUSAL IS NOT THE ABSENCE OF AN INSTRUCTION

   Two kinds of "no" appear on this page, two lines apart:

     "instruction requires: aes"
        a fact about the ASSEMBLER'S FEATURE SET.  The
        instruction is in the architecture; this clang
        was not told the CPU has the extension.

     "invalid operand for instruction"
        a fact about the ENCODING.  `fadd b0, b1, b2`
        cannot be encoded at all, at any -march, ever.

   The general form is worth more than either:
   a refusal is evidence about the assembler and only
   WEAK evidence about the encoding, and a decoder that
   reports a refusal as though the instruction did not
   exist is making a claim about the architecture out of
   a fact about a program.
                </div>
                <p>This course got that wrong twice and retracted it twice. <code>casp</code> was reported as unencodable because the three-operand form is a spelling rule, and <code>stlxp x14, x9, x8</code> was reported as unencodable because the status register is always <code>w</code>. Both were <strong>refusals that pointed at an operand that was right</strong> — which is the most believable kind of diagnostic there is.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Run the five-vector-length sweep.</strong> It is four lines of shell and it is the strongest single piece of evidence in the course. <em>(Expect five identical words and no diagnostic at any length. Then change one thing — swap <code>z1.d</code> for <code>z2.d</code> — and watch the same sweep produce five <em>different</em> words. The absence is not a property of the sweep; it is a property of the field.)</em></li>
                    <li><strong>Ask for the sixteen predicates and count how many you get.</strong> <code>whilelo p0.d</code> … <code>whilelo p15.d</code> all assemble. <code>add z0.d, p8/m, …</code> does not. <em>(Expect the diagnostic to name a restriction the encoding does not express: "invalid restricted predicate register, expected p0..p7". Four bits address sixteen predicates and the arithmetic form may use eight of them, and the only thing enforcing that is the assembler.)</em></li>
                    <li><strong>Find the boundary between the two class fields.</strong> Take <code>0x4ea28420</code> (Advanced SIMD) and <code>0x04c00020</code> (SVE) and XOR them. <em>(Expect the difference to be exactly the class field plus the size field. Now find the smallest single-bit edit of <code>0x04c00020</code> that makes the second reader print something from a different family — that is the boundary, and it is a bit, and a decoder that does not check the class will happily name the wrong family.)</em></li>
                    <li><strong>Write the sentence you would need to publish the real claim.</strong> "SVE does not encode its vector length." Now write the version that is actually true, and name the machine you would need. <em>(Expect: "SVE does not encode its vector length, so a fixed 32-bit instruction can address a vector whose width the instruction does not state, and the width must therefore be recovered from the vector length register at run time." The first sentence is a fact about an encoding. The second is a fact about a machine, and the difference between them is the whole discipline this course is built on.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards. <a href="/courses/a64simd/lessons/a64-neon">Thirty-Two Registers</a> is the direct parent: the "same four sizes in four groups" table on that page ends with <code>sve size</code> having <em>no Q bit at all</em>, and this page is the measurement behind that row. <a href="/courses/a64sys/lessons/a64-registers">The machine course's register concept</a> is where the shared physical file was established for the scalar case; SVE is the same sharing one level up, and the register-counting question ("how many vector registers does this core have?") is unanswerable in the same way for both.</p>
                <p>Forwards. <a href="/courses/a64simd/lessons/a64-atomic">The exclusive monitor</a> is where the same class-field idea becomes a correctness problem rather than a decoding one: a 128-bit atomic has to name two consecutive register pairs in a 32-bit instruction, and concept 3 measures what the assembler does with that. <a href="/courses/a64simd/lessons/a64-dataflow">Decode the data path</a> is where this page's SVE model is checked by a second reader, and where the mnemonic table above is asserted entry by entry.</p>
                <p>Outward, and this is the page's real subject: <strong>an encoding that omits a field is making a claim about where the information lives.</strong> That is a much rarer design decision than a field position, and it is worth reading the whole collection for the two halves of it. Concept 1 measured a field at bit 23 when the reader expected bit 30. This page measured the <em>absence</em> of a field and the absence turned out to be the design. And in the x86-64 SIMD course the same question has a different answer again, because <code>EVEX</code> encodes a vector length that <code>VEX</code> did not, for exactly the reason SVE omits one — the register file grew and the old prefix stopped being able to say what it meant.</p>
                <p>Which is the connection to carry out of the section. <strong>Where an encoding puts a field, and where it refuses to, is the clearest statement an architecture makes about what it thinks is constant.</strong> Advanced SIMD thinks 128 bits is constant and spends a bit. SVE thinks nothing about a vector is constant and spends zero bits, and reads one register instead. Neither is more modern than the other; one of them is right for its register file.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64simd/lessons/a64-neon">Thirty-Two Registers, Four Ways to Read One</a></span>
                <span>Next: <a href="/courses/a64simd/lessons/a64-atomic">The Exclusive Monitor, and Why the Retry Is the Instruction</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
