// The AArch64 Data Path: NEON, Atomics and Ordering -- Concept 1:
// Thirty-Two Registers, Four Ways to Read One.
//
// The page exists to move one idea: a field's POSITION is a property of an
// instruction GROUP, not of an architecture.  `ldr b0` and `ldr q0` differ in
// exactly one bit and it is bit 23, and bit 30 -- which really is the Q bit in
// the three-same group two pages from here -- is not it.  Everything else on
// the page is support for that one claim, including a refusal that names a
// feature and a float suffix the assembler will not accept at all.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_neon() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Thirty-Two Registers, Four Ways to Read One — Underlayer")
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
            <h1>Thirty-Two Registers, Four Ways to Read One</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/a64simd">The AArch64 Data Path: NEON, Atomics and Ordering</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Open a disassembly of AArch64 vector code and you will meet the same five names over and over: <code>b</code>, <code>h</code>, <code>s</code>, <code>d</code>, <code>q</code>. They are not five register files. They are five <strong>views</strong> of the same thirty-two 128-bit registers, and the suffix says which view — which is a reinterpretation, never a conversion.</p>
                <p>[QUOTED] There are 32 vector registers, each 128 bits, and an instruction names a VIEW of one: the same 16 bytes read as 16 bytes, 8 halfwords, 4 words or 2 doublewords. (ARM DDI 0487, "A64 Advanced SIMD", the section on register size.)</p>
                <p>That is the easy half, and it is the half that produces a comfortable wrong model. The comfortable model is <em>"one register, five widths, the suffix picks one"</em> — which is true of the register file and <strong>false of the encoding</strong>. Because the encoding is not obliged to put the width in the same place twice, and Advanced SIMD does not:</p>
                <div class="hex-dump">
                <pre>instruction       word         binary                                the three size bits
  ---------------- ----------- ------------------------------------ --------------------------
  ldr b0, [x0]     0x3d400000  00111101010000000000000000000000     size=0 Q=0 L=1
  ldr h0, [x0]     0x7d400000  01111101010000000000000000000000     size=1 Q=0 L=1
  ldr s0, [x0]     0xbd400000  10111101010000000000000000000000     size=2 Q=0 L=1
  ldr d0, [x0]     0xfd400000  11111101010000000000000000000000     size=3 Q=0 L=1
  ldr q0, [x0]     0x3dc00000  00111101110000000000000000000000     size=0 Q=1 L=1
  str b0, [x0]     0x3d000000  00111101000000000000000000000000     size=0 Q=0 L=0
  str h0, [x0]     0x7d000000  01111101000000000000000000000000     size=1 Q=0 L=0
  str s0, [x0]     0xbd000000  10111101000000000000000000000000     size=2 Q=0 L=0
  str d0, [x0]     0xfd000000  11111101000000000000000000000000     size=3 Q=0 L=0
  str q0, [x0]     0x3d800000  00111101100000000000000000000000     size=0 Q=1 L=0

  [MEASURED-ON-BYTES]  ldr b0 and ldr q0 differ in EXACTLY ONE BIT.
  ldr b0         xor ldr q0         = 0x00800000  -&gt; bit 23
  [MEASURED-ON-BYTES]  ldr b0 and str b0 differ in EXACTLY ONE BIT.
  ldr b0         xor str b0         = 0x00400000  -&gt; bit 22
                </pre>
                </div>
                <p>One bit. <code>ldr b0</code> is 64 bits of access and <code>ldr q0</code> is 128, and the entire difference is <strong>bit 23</strong> — not bit 30, not bit 31, and nowhere near the top of the word where a reader's expectation sits.</p>
                <p>Why this matters beyond one instruction: <strong>a decoder that has one "vector size" field is a decoder that has one measurement and two answers.</strong> Write the field map once, at bit 30, because that is where the three-same group puts it, and every vector load in every object file you will ever read is decoded at the wrong width — silently, because the result is a legal instruction and nothing anywhere complains.</p>
            </div>

            <div class="unit unit-model">
                <h2>The measurement: three bits, five values</h2>
                <p>So for the single load/store form the layout is <code>bits[31:30]</code> = element size, bit 23 = Q, bit 22 = load-or-store. The <strong>access size</strong> is therefore three bits wide with five allocated values out of eight — B, H, S, D from the two-bit size field, plus Q for 128. And the two-bit size field and the Q bit are not adjacent:</p>
                <div class="hex-dump">
                <pre>  bit   31 30 | 29 28 27 26 25 24 | 23 | 22 | 21          10 | 9      5 | 4      0
        size   |      class bits         | Q  | L  |     imm12     |   Rn   |   Rt

  b0:  0 0       0 0 1 1 1 1 0 1         0    1     0 0 0 0 0 0 0 0 0 0  0 0 0 0 0 0  0 0 0 0 0  0 0 0 0 0 0
  q0:  0 0       0 0 1 1 1 1 0 1         1    1     0 0 0 0 0 0 0 0 0 0 0  0 0 0 0 0 0  0 0 0 0 0 0
                </pre>
                </div>
                <p>The <strong>float</strong> groups do the same thing with a two-bit type field, and this is where the comfortable model breaks for the second time. <code>fadd s0, s1, s2</code> and <code>fadd d0, d1, d2</code> differ in bit 22 alone:</p>
                <div class="hex-dump">
                <pre>instruction         word         binary                                bits[23:22]
  ------------------ ----------- ------------------------------------ ----------------
  fadd s0, s1, s2    0x1e222820  00011110001000100010100000100000     0
  fadd d0, d1, d2    0x1e622820  00011110011000100010100000100000     1
  fmov s0, w0        0x1e270000  00011110001001110000000000000000     0
  fmov d0, x0        0x9e670000  10011110011001110000000000000000     1
  umov w0, v0.s[0]   0x0e043c00  00001110000001000011110000000000     0
  umov x0, v0.d[0]   0x4e083c00  01001110000010000011110000000000     0
  fmov s0, wzr       0x1e2703e0  00011110001001110000001111100000     0

  [MEASURED-ON-BYTES]  fadd s0 and fadd d0 differ in bit 22 alone, so
  the floating-point TYPE is bits[23:22] with S = 00 and D = 01.
                </pre>
                </div>
                <p>So the float suffix is a <em>type</em>, and the type is two bits with two of its four values unused by the baseline assembler. Which brings us to the first refusal, and the first time the assembler teaches you something about the architecture.</p>
                <h3>The third type value, hidden by a refusal</h3>
                <div class="hex-dump">
                <pre>     fadd h0, h1, h2                    (baseline)             REFUSED: instruction requires: fullfp16
     fadd h0, h1, h2                    -march=armv8.2-a+fp16  0x1ee22820  fadd h0, h1, h2
     fadd q0, q1, q2                    (baseline)             REFUSED: invalid operand for instruction
     fadd b0, b1, b2                    (baseline)             REFUSED: invalid operand for instruction
     fmov h0, w0                        (baseline)             REFUSED: instruction requires: fullfp16
     fmov h0, w0                        -march=armv8.2-a+fp16  0x1ee70000  fmov h0, w0
     scvtf s0, d0                       (baseline)             REFUSED: instruction requires: fprcvt
     fcvtzs s0, d0                      (baseline)             REFUSED: instruction requires: fprcvt

  `fadd h0, h1, h2` is REFUSED at baseline with a diagnostic that NAMES
  THE FEATURE: "instruction requires: fullfp16".  With
  `-march=armv8.2-a+fp16` it assembles to 0x1ee22820, and
  0x1ee22820 xor 0x1e222820 is 0x00c00000 -- bits 22 AND 23.
                </pre>
                </div>
                <p>So the encoding has a <strong>third</strong> type value, a four-bit window at <code>bits[23:20]</code>, and half of that window is unused by the instructions a baseline assembler will produce. That is the shape of every architectural extension: the encoding is allocated generously and the assembler is stingy, and only the first of the two is checkable with a hex editor.</p>
                <p>Now the refusal that is <em>not</em> about a feature, and it is the one worth reading twice:</p>
                <div class="hex-dump">
                <pre>     fadd q0, q1, q2    -&gt;  REFUSED: invalid operand for instruction
     fadd v0.4s, v1.4s, v2.4s    -&gt;  0x4e22d420
                </pre>
                </div>
                <p><code>fadd q0</code> does not exist, and the reason is the first table on this page. The floating-point groups have a <em>type</em> field, and 128 bits is not a type — it is a <strong>different encoding</strong>, six bits away:</p>
                <div class="formula">
   R2, and the sentence the whole page is for

   CLAIMED     "a NEON instruction is one instruction with
                five widths"

   MEASURED    the FP and Advanced SIMD arithmetic groups have
               a TYPE field of bits[23:22], and the 128-bit
               form is a DIFFERENT ENCODING:
                   fadd s0, s1, s2      0x1e222820
                   fadd v0.4s, v1.4s    0x4e22d420
               six bits apart

   WHY         the suffix reinterprets, but only WITHIN a
               type.  128-bit arithmetic is a different GROUP,
               not a different suffix.
                </div>
                <p>A reader who took "the suffix picks the width" to mean "one instruction, five widths" has the wrong mental model, and <em>it is worth being wrong about exactly here</em> — because the wrong model produces a decoder that reads <code>fadd v0.4s</code> with the float type field, gets a plausible word, and prints a plausible instruction.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this measurement cannot show</h2>
                <p>It cannot show that the five views are the same <strong>bits</strong> at run time. There is no AArch64 machine here, so no value was loaded, no reinterpretation happened and no lane was read. What is measured is that five names are five 32-bit words which differ in a total of two bit positions — which is a fact about the <strong>encoding</strong> and a necessary, not sufficient, condition on the views being one register.</p>
                <p>It cannot show a throughput, a latency, a register-file size in bytes, or whether a particular core has 32 vector registers or fewer. [QUOTED] The architectural register file is 32&nbsp;&times;&nbsp;128 bits; the number of <em>physical</em> registers a particular implementation has is not in the architecture at all.</p>
                <h3>The trap this page is built around</h3>
                <p>Concept 2 sweeps the same four element sizes through four different instruction groups and prints all four field positions side by side. Here is the whole of it, so you can see what the trap looks like before you fall into it:</p>
                <div class="formula">
   THE SAME FOUR SIZES, IN FOUR GROUPS

   `ldr size`      is bits[31:30]    and `ldr Q`    is bit 23
   `add v size`   is bits[23:22]    and `add v Q`  is bit 30
   `ld1 size`     is bits[11:10]    and `ld1 Q`    is bit 30
   `sve size`     is bits[23:22]    and has NO Q bit at all

   So the same four element sizes live at TWO places in the
   32-bit word, and the 128-bit form is a bit in three of the
   four groups and ABSENT from the fourth.
                </div>
                <p>And the fourth row is the one the next concept is about, and the reason SVE has no Q bit is <strong>not an omission</strong>: an SVE vector is not a fixed 128 bits, so a bit that said "128" would be a lie. Concept 2 measures what the instruction says instead, which is nothing.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: reading a field map off an XOR</h2>
                <p>The method is one line long: assemble an instruction, change <em>one</em> operand, assemble it again, and every bit that moved belongs to that operand. A sweep is necessary, not decorative — a single pair marks the bits where two <em>values</em> differ, which is a <strong>subset</strong> of the field.</p>
                <div class="hex-dump">
                <pre>field             xor mask    the positions           base instruction
  ---------------- ---------- ---------------------- ----------------------------
  ldr size         c0000000   bits[31:30]            ldr b0, [x0]
  ldr Q            00800000   bits[23:23]            ldr b0, [x0]
  ldr L            00400000   bits[22:22]            ldr b0, [x0]
  ldr Rt           0000001f   bits[4:0]              ldr q0, [x0]
  ldr Rn           000003e0   bits[9:5]              ldr q0, [x0]
  ldr imm12        003ffc00   bits[21:10]            ldr q0, [x0, #0]
  add v size       00c00000   bits[23:22]            add v0.16b, v1.16b, v2.16b
  add v Q          40000000   bits[30:30]            add v0.8b, v1.8b, v2.8b
  ldr q0, [x0, #0]           the base of the imm12 sweep
  movi imm8        000703e0   bits[5,6,7,8,9,16,17,18]  movi v0.4s, #0
  ld1 size         00000c00   bits[11:10]            ld1 {v0.16b}, [x0]

  45 field positions measured over 47 cases, 2 refusals.
                </pre>
                </div>
                <p>Look at <code>movi imm8</code>. The mask is <strong>not a span</strong> — it is <code>bits[9:5]</code> and <code>bits[18:16]</code> with thirteen bits missing in the middle, because <code>cmode</code> lives there. An eight-bit immediate that is not contiguous is a fact about the <em>design</em> here, and evidence about the <em>measurement</em> everywhere else, and the only way to tell the two apart is to have swept.</p>
                <p>And look at <code>ld1 size</code> = <code>bits[11:10]</code>. That is nowhere near the top of the word, it is in the middle, and it is the <em>element size</em> of a structure load. Same four sizes. Different field. A decoder that has one "vector element size" constant has one measurement and two answers, and it will be wrong on whichever group it did not sweep.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Hex-dump the five words yourself.</strong> Assemble <code>ldr b0,[x0]</code> … <code>ldr q0,[x0]</code> into an object file and XOR the first and the last. <em>(Expect <code>0x00800000</code>, one bit, bit 23. Then XOR <code>ldr b0</code> against <code>str b0</code> and expect <code>0x00400000</code>, bit 22. If you get a different bit, your assembler is not clang 21.1.8 and the rest of this course's numbers will not reproduce — which is worth knowing before you blame the course.)</em></li>
                    <li><strong>Find the Q bit in the wrong place on purpose.</strong> Take <code>0x3d400000</code>, set bit 30, and disassemble. <em>(Expect the second reader to print something that is not <code>ldr q0</code> — and then find out what bit 30 <em>does</em> mean here, which is a question worth ten minutes. The three-same group's Q bit and the load's Q bit are two different bits in two different groups, and being able to say which is which is the page's whole content.)</em></li>
                    <li><strong>Ask the assembler for the three refusals.</strong> <code>fadd q0,q1,q2</code>, <code>fadd b0,b1,b2</code>, <code>fadd h0,h1,h2</code>. <em>(Expect "invalid operand", "invalid operand", and "instruction requires: fullfp16". The first two are a fact about the ENCODING — 128 bits is not a float type — and the third is a fact about the ASSEMBLER'S FEATURE SET. Two different kinds of refusal two lines apart, and telling them apart is the exercise.)</em></li>
                    <li><strong>Sweep one group yourself and find a field the sweep cannot find.</strong> Take <code>add v0.4s, v1.4s, v2.4s</code> and change only the destination register. <em>(Expect bits[4:0]. Then ask: which bit in that word did the sweep <em>not</em> move, that you know must be a field? There is at least one — and a field your sweep never moved is a field you have not measured, however confident the table looks.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, into the machine course. <a href="/courses/a64sys/lessons/a64-registers">The register concept</a> established the thirty-one integer registers and the thirty-two vector registers as two naming schemes over one physical file, and this page is where the <em>encoding</em> of the second scheme goes wrong. <a href="/courses/a64asm/lessons/a64-encoding">The encoding course's field-map concept</a> is the direct parent of the sweep at the bottom of this page, including the lesson that a mask is a lower bound and that the encoding course's own <code>imm16</code> was measured one bit too wide by a sweep with too few steps.</p>
                <p>Forwards, immediately. <a href="/courses/a64simd/lessons/a64-neonspace">The shared memory space</a> takes the "same four sizes, different position" table and follows it into SVE, where a group spends <em>no bits at all</em> on the question every other group spends a bit on. <a href="/courses/a64simd/lessons/a64-dataflow">Decode the data path</a> is where all of this is cross-checked by a second reader, and where the field positions on this page are asserted as exact values by a harness that reads a recorded run rather than re-measuring.</p>
                <p>Outward, and this page's claim generalises past AArch64. <strong>A field's position is a property of an instruction group, and a group boundary is something you learn by sweeping, not by reading the top of the word.</strong> x86-64's VEX prefix has the same property in a different shape: <code>vmovups</code> and <code>vmovupd</code> differ in a prefix bit that is a different bit for every instruction that has one. And the generalisation that costs a learner the most: <strong>an encoding is allocated generously and an assembler is stingy, so "the assembler refuses it" is evidence about the assembler and very weak evidence about the encoding.</strong> Four refusals on this page, two kinds, and telling them apart is the habit worth taking out of it.</p>
            </div>

            <div class="lesson-footer">
                <span>End of The AArch64 Data Path: NEON, Atomics and Ordering &middot; Next: <a href="/courses/a64simd/lessons/a64-neonspace">The Shared Memory Space</a></span>
                <span><a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
