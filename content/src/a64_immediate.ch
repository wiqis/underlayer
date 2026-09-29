// AArch64: Encoding From The Ground Up -- Concept 3: the immediates.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_immediate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("A Constant Is a Rotate and a Run Length — Underlayer")
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
            <h1>A Constant Is a Rotate and a Run Length</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/a64asm">AArch64: Encoding From The Ground Up</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/a64asm/lessons/a64-encoding">The last concept</a> ended with a row that reads <code>imm16 &nbsp; 001fffe0 &nbsp; bits[20:5] &nbsp; movz w0, #0x0000</code> and a note that a logical immediate is not a number. This concept is that note, and it is the most interesting encoding in the whole architecture: <strong>a twelve-bit field that is not a twelve-bit number</strong>, and which reaches more distinct constants than any other twelve-bit field in the instruction set.</p>
                <p>The reason a reader needs this is not curiosity. It is that <code>and</code>, <code>orr</code>, <code>eor</code> and <code>bic</code> &mdash; the four operations a compiler reaches for constantly when it is masking, clearing and setting bits &mdash; have no literal immediate at all on this architecture. They have a <em>pattern</em> immediate. Every mask you have ever written in C is either expressible in one instruction or is assembled out of three or four, and which one is a property of the pattern rather than the value.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: one run of ones, repeated, rotated</h2>
                <p>The shape, in full: <strong>the constant is built from ONE run of consecutive ones, repeated to fill the register, and rotated.</strong> That is all. So the encodable constants are exactly the periodic bit patterns, and the set is tiny &mdash; tiny in the way a <em>filter</em> is small, not in the way an <em>optimisation</em> is small.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=7 | sed -n '/=== 7A/,/reach more values/p'
=== 7A. HOW MUCH OF THE CONSTANT SPACE THE ENCODING REACHES

  width    encodable  the whole space           share
  32       1,302     4,294,967,296             3.031e-07
  64       5,334     18,446,744,073,709,551,616 2.892e-16

  1,302 is the count the manual quotes and this file agrees with
  it, which is worth saying plainly: the number is DERIVED here by
  enumerating the encoding -- six element sizes, at most 64 run
  lengths, at most 64 rotations -- and not read out of the manual.
                </pre>
                </div>
                <p>1,302 of 4,294,967,296. That is three parts in ten million. <strong>And it is more values than the add/sub immediate reaches</strong>, which is 4,095 &mdash; so the instruction with the <em>smallest</em> literal field in the architecture reaches more constants than any other twelve-bit field, including the one whose whole job is a number. It reaches them by not being one.</p>
                <h3>What that looks like in the bits</h3>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=7 | sed -n '/=== 7D/,/repeat that element 1 times/p'
=== 7D. WHAT THE SHAPE LOOKS LIKE, DERIVED

  92401000  and      x0, x0, #0x1f
      0x92401000   and      x0, x0, #0x1f
      class field bits[28:25] = 1001  -&gt;  Data Processing -- Immediate
      . N = bit[22] = 1 with sf = 1: the element is 64 bits wide or the top
        half needed filling
      . LOGICAL IMMEDIATE: len = the position of the highest set bit of
        N:NOT(imms) = 0b1111011, so esize = 1 &lt;&lt; 6 = 64 bits
      . LOGICAL IMMEDIATE: S = imms &amp; 0b111111 = 4 is the WIDTH of the run
        of ones (S+1 = 5 of them); R = immr &amp; 0b111111 = 0 is how far RIGHT
        that run is rotated inside the element
      . LOGICAL IMMEDIATE: a run of 5 ones is 0b11111; rotate it right by 0
        within 64 bits and you get 0b11111 = 0x1f
      . LOGICAL IMMEDIATE: repeat that element 1 times: the 64-bit pattern
        is 0x000000000000001f
                </pre>
                </div>
                <p>Three fields and they are <em>not</em> a number:</p>
                <ul>
                    <li><code>imms</code> (6 bits) says how wide the <strong>element</strong> is, and that is read from the position of the highest set bit of <code>N:NOT(imms)</code>. The pattern is peculiar and it is worth doing on paper once: <strong>the bits above the element width in <code>imms</code> are ONES, and the single ZERO marks where the element width is.</strong> A decoder that reads <code>imms</code> as a plain value gets a different element size, which means a different constant, which means it looks plausible and is wrong.</li>
                    <li><code>imms</code>'s low bits are <code>S</code>, and <code>S+1</code> is the width of the run of ones inside the element.</li>
                    <li><code>immr</code> is how far right that run is rotated inside the element, and rotation is the only other degree of freedom.</li>
                </ul>
                <p>That is the entire encoding: <strong>an element width, a run width, and a rotation.</strong> Everything the twelve bits name, they name because of those three numbers.</p>
                <h3>Three ways to be sure, and the third is the one that counts</h3>
                <p><strong>First: this file against itself.</strong> Every encodable 64-bit constant, encoded and decoded back through the field-recovery path, which asks the decoder to recover the element size from the <code>imms</code> FIELD rather than being handed the encoder's answer:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=7 | sed -n '/=== 7B/,/proves only/p'
=== 7B. THE ROUND TRIP, THIS ENCODER TO THIS DECODER

  5334 encodable 64-bit constants; 0 round-trip failures
                </pre>
                </div>
                <p>The first version of this test handed the decoder the encoder's own <code>imms</code>, which made it a tautology &mdash; the encoder chose <code>imms</code>, the decoder was handed <code>imms</code>, and the two agreed about a constant neither had examined. It printed the same line. <strong>A tautological round trip reads exactly like a passing one in the output</strong>, and that is worth internalising before the next two checks.</p>
                <p><strong>Second: the two halves disagree about the field order, which is the whole risk.</strong> The decoder takes <code>(N, imms, immr, width)</code> and the encoder returns <code>(N, immr, imms)</code>. The first version of the round trip passed the encoder's output straight through, so it handed the rotate amount to the decoder's <code>imms</code> &mdash; and 94 of the 5,334 constants came back as something else. The names are now spelled out at the call site so the two orders cannot be confused again, and the count of failures is the evidence that they were.</p>
                <p><strong>Third, and this is the one that is not self-referential: a real assembler.</strong> All 1,302 encodable 32-bit constants, assembled by <code>clang</code> into a real object file, every word read back by this decoder and compared against the disassembler's own name:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=7 | sed -n '/=== 7C/,/disagreements/p'
  asked the assembler for all 1302 encodable 32-bit constants and
  read every word back with THIS decoder:
    agreed:                    1302
    disagreed:                 0
                </pre>
                </div>
                <p><strong>1,302 agreements and 0 disagreements, between two pieces of software written by different people that cannot see each other.</strong> That is the only one of the three checks that could have failed for a reason this file does not control, and it is the reason the other two exist.</p>
            </div>

                <h3>The reserved space, found by asking</h3>
                <p>Now the other half, and it is the half a compiler cares about. Everything above measured what the encoding <em>allows</em>; a mask is a case where the encoding has no room, and the only honest way to find the boundary is to walk into it and see whether the assembler lets you back.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=7 | sed -n '/=== 7E/,/all but the top bit/p'
=== 7E. THE RESERVED SPACE, FOUND BY ASKING

  constant      shape                     verdict    what came back
  0x0           32-bit all zeros          REFUSED    expected compatible register
                                                       or logical immediate
  0xffffffff    32-bit all ones, 32-bit   REFUSED    (same diagnostic)
  0xdeadbeef    32-bit no run of two      REFUSED    (same diagnostic)
  0x12345678    32-bit no period at all   REFUSED    (same diagnostic)
  0x80000001    32-bit ONE bit set        ACCEPTED   andw0,w0,#0x80000001
  0x7           3-bit all ones, 3 bits    ACCEPTED   andw0,w0,#0x7

  And the same constants at 64-bit width, where the answer CHANGES
  for some and not others:

  constant              shape                verdict    what came back
  0xffffffffffffffff    all ones, 64-bit     REFUSED    expected compatible register
                                                       or logical immediate
  0x7fffffffffffffff    all but the top bit  ACCEPTED   andx0,x0,#0x7fffffffffffffff
  0xfffffffffffffffe    all but the bot bit  ACCEPTED
  0xf0f0f0f0f0f0f0f0    a 4-bit run          ACCEPTED
                </pre>
                    <p>Read the first and the last rows together, because they are the two facts that matter.</p>
                <p><strong>One: the all-zeros and the all-ones are not encodable, at either width, and the diagnostic is the same one for all eight logical operations.</strong> The artifact asked <code>and</code>, <code>orr</code>, <code>eor</code>, <code>ands</code>, <code>orn</code>, <code>eon</code>, <code>bic</code> and <code>bics</code> each for <code>#0xffffffff</code> at 32 bits and each refused with the same message, and then each again for the 64-bit all-ones. That is a property of the <strong>shared immediate field</strong> and not of any one operation &mdash; which is why the diagnostic names the field rather than the instruction. And those two constants are exactly the ones a compiler most wants: a mask of &ldquo;all but the low 32 bits&rdquo; is not one instruction.</p>
                <p><strong>Two: the 64-bit all-ones is refused, and one bit short of it is accepted.</strong> This is the retraction, and it reverses the first draft of this page, which said the opposite &mdash; that the all-ones is acceptable at 64 bits and reserved at 32. The boundary is not a <strong>width</strong>. It is the <strong>shape</strong>: one bit short of all-ones is a legal run of 63 ones in an element of size 64, and all-ones is not a run at all. So a decoder that models the immediate as a scaled number gets this wrong in the specific direction of <em>accepting a constant the assembler refuses</em>, which is the more dangerous of the two &mdash; a decoder that invents an instruction produces output that looks right.</p>
                <p>The corollary is a compiler's fact, and it is where the next section starts. A mask of all-ones is <strong><code>mov x0, #-1</code></strong> &mdash; <code>0x92800000</code>, one word &mdash; followed by an <code>and</code>. Not because the logical immediate is small, but because there is a different instruction for the one constant it cannot hold.</p>
            </div>

            <div class="unit unit-reality">
                <h2>And the other two immediates, for contrast</h2>
                <p>AArch64 has three ways to put a constant in an instruction and each has a different reach. This table is the boundaries, found by asking:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=6 | sed -n '/6A. add\/sub/,/6B. move wide/p'
  asked for                     word        verdict   what came back
  add w0, w1, #0                11000020    accepted  add      w0, w1, #0x0
  add w0, w1, #0xfff            113ffc20    accepted  add      w0, w1, #0xfff
  add w0, w1, #0x1000           11400420    accepted  add      w0, w1, #0x1, lsl #12
  add w0, w1, #0x1, lsl #12     11400420    accepted  add      w0, w1, #0x1, lsl #12
  add w0, w1, #0xfff, lsl #12   117ffc20    accepted  add      w0, w1, #0xfff, lsl #12
  add w0, w1, #0x1001           --          REFUSED   expected compatible register,
                                                      symbol or integer in range
  add w0, w1, #0x1000000        --          REFUSED   (same)
  add w0, w1, #0x1234           --          REFUSED   (same)
                </pre>
                </div>
                <p><strong>The reach is three isolated values, not a range.</strong> The field itself, the field shifted left by twelve, and zero. <code>#0x1000</code> is accepted and it is not a wider immediate &mdash; it is the value 1 with the scale field set, which is why concept 1 measured <code>#0x1000</code> and <code>#1, lsl #12</code> as the same 32 bits. <code>#0x1001</code> is refused, because 0x1001 is not reachable as a twelve-bit field in any of the three states the scale admits. <strong>No formula of the form &ldquo;0 to N times a power of four&rdquo; describes it</strong>, and a reader who has internalised the x86-64 <code>imm8-or-imm32</code> rule expects a contiguous range with a scale and gets three isolated values.</p>
                <p>The same shape appears three more times in the architecture, and all four are worth knowing because the trap is always the same: <strong>a scaled field is not a contiguous range.</strong></p>
                <ul>
                    <li>The <strong>pair offset</strong> is a multiple of 8 in [-512, 504], and the assembler says so: <em>&ldquo;index must be a multiple of 8 in range [-512, 504]&rdquo;</em>. The scale is 8 because the two registers of a pair are 64 bits apart at minimum.</li>
                    <li>The <strong>unscaled load offset</strong> is a signed 9-bit field in [-256, 255], while the scaled one is a 12-bit field times the access size. Two groups, two fields, and the first version of the field sweep put them in one row and the mask came out with odd bits in it.</li>
                    <li>The <strong>branch displacement</strong> is a signed field in <em>instructions</em> multiplied by 4, and its two ends are not symmetric: 19 bits signed reaches +0xffffc bytes forward and -0x100000 back. A sign extension is not a magnitude, and the first two drafts of that measurement were wrong in exactly that way &mdash; R5.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what a wide constant costs</h2>
                <p>Section 6 established that a 12-bit immediate reaches three isolated values and section 7 that the logical immediate is not a number at all. So what does a compiler do with a constant like <code>0x123456789abcdef0</code>?</p>
                <p>It builds it out of MOVZ and MOVK. <strong>MOVZ writes one 16-bit field and zeroes the rest; MOVK writes one 16-bit field and leaves the others alone.</strong> Four fields of sixteen bits, so four instructions for a 64-bit constant &mdash; sixteen bytes, four words, for one C literal &mdash; unless a field is zero, in which case it is skipped.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=8 | sed -n '/width  constant/,/why it is/p'
  width  constant             insns  what the assembler chose
  32     0x00001234           1      movz w0, #0x1234
  32     0x12345678           2      movz w0, #0x5678, movk w0, #0x1234, lsl #16
  32     0xffffffff           1      movn w0, #0x0
  64     0x123456789abcdef0   4      movz x0, #0xdef0, movk x0, #0x9abc, lsl #16,
                                    movk x0, #0x5678, lsl #32, movk x0, #0x1234, lsl #48
  64     0x0001000000000001   2      movz x0, #0x1, movk x0, #0x1, lsl #48
  64     0x7fffffffffffffff   4      movz x0, #0xffff, movk ... lsl #16, lsl #32, lsl #48
  64     0xffffffffffffffff   1      movn x0, #0x0
  64     0x123456789abcdef1   4      movz x0, #0xdef1, movk ... (four, again)
                </pre>
                </div>
                <p>Now read the table, because it is <strong>not ordered by size</strong> and the first draft of this page got that wrong in the most instructive way available.</p>
                <ul>
                    <li><strong>Cheap: the value has a zero 16-bit field.</strong> MOVZ writes it and MOVK patches the rest. One instruction for <code>0x1234</code>.</li>
                    <li><strong>Cheapest: the value is all-ones.</strong> One <code>movn x0, #0</code>, because MOVN writes the <em>complement</em> and the complement of all-ones is all-zeros, which is a field MOVZ can write. <strong>That is the entire reason MOVN exists</strong>, and it is also why the 64-bit all-ones is one instruction when no logical immediate reaches it: two different instructions for the same constant, chosen by which one has room.</li>
                    <li><strong>Expensive: no zero field and not all-ones.</strong> All four fields written separately. The largest signed 64-bit value costs the same four as an arbitrary literal, because <code>0x7fffffffffffffff</code> is three fields of ones and one of <code>0x7fff</code> and each has to be written &mdash; it is not all-ones, so MOVN does not reach it either.</li>
                </ul>
                <p>So the rule is not <em>big number</em>. It is <strong>pattern</strong>, which is the same rule section 7A measured from the other side: the cheapest 64-bit constant is the one with no variety in it at all, and the one twelve-bit field that is not a number is the one that reaches the most values. <strong>Both are the same design decision: the encoding pays for reach in bits, and it pays in variety.</strong></p>
                <p>And here is the trap inside the move-wide group, which the artifact found and which R7 is about. <code>movn w0, #0x8000</code> and <code>movn w0, #0xffff</code> are the same mnemonic, and the printer prints different things:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --section=6 | sed -n '/6B. move wide/,/6C. opc/p'
  movn w0, #0xffff     129fffe0   accepted   movn w0, #0xffff
  movn w0, #0x8000     12900000   accepted   mov      w0, #-0x8001
  movn w0, #0          12800000   accepted   mov      w0, #-0x1
  movz w0, #0          52800000   accepted   mov      w0, #0x0
                </pre>
                </div>
                <p><strong>The field holds the MAGNITUDE and the register ends up holding the complement.</strong> Which of the two a printer shows is a choice about what it thinks a reader wants, so the encoding is unambiguous and the mnemonic is not: <code>movn w0, #0x8000</code> prints as <code>mov w0, #-0x8001</code> while <code>movn w0, #0xffff</code> prints as <code>movn w0, #0xffff</code>, by the same tool, on the same instruction group. And <code>mov w0, #0x0</code> and <code>mov w0, #-0x1</code> are the same mnemonic with different immediates and different words &mdash; <code>0x52800000</code> and <code>0x12800000</code>. <strong>One is &ldquo;all zeros in a 32-bit register&rdquo; and the other is &ldquo;all ones&rdquo;, and the difference is invisible in the mnemonic.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Write the encoder yourself and check it against the assembler.</strong> For each element size 2, 4, 8, 16, 32, 64, take each run width 1 to <code>esize-1</code>, take each rotation 0 to <code>esize-1</code>, build the pattern, and ask <code>clang</code> to assemble <code>and w0, w0, #pattern</code>. <em>(Expect 1,302 accepted of the 2,048 candidates at 32 bits, and expect the rejections to cluster on exactly two constants &mdash; all-zeros and all-ones &mdash; plus everything with no period. Then check your count against the artifact's and expect them to agree, because both are enumerating the same thing; the interesting part is that the two excluded constants are the two you wanted.)</em></li>
                    <li><strong>Find the boundary by bisection, not by arithmetic.</strong> Do the same for <code>add w0, w1, #imm</code>. <em>(Expect the accepted set to be three disjoint ranges &mdash; 0; 0 to 4095; and 0, 4096, 8192 up to 0xfff000 &mdash; 8,192 values in all, and expect the largest to be 0xfff000. A reader who computes &ldquo;12 bits times a scale of 4096&rdquo; and concludes the range is 0 to 0xfff000 is right by luck: <code>#0x1001</code> is inside that envelope and is refused.)</em></li>
                    <li><strong>Make the field-order bug happen on purpose.</strong> In <code>a64dec.py</code>, in section 7B's loop, swap the two arguments to <code>decode_bit_masks</code> so the encoder's <code>immr</code> is handed to the decoder's <code>imms</code>. <em>(Expect 94 of the 5,334 constants to come back wrong rather than all 5,334, and expect the 1,302-constant assembler round trip in 7C to still pass. That asymmetry is the lesson: the self-consistent check is the one that broke, and the check against a third party is the one that did not notice &mdash; so neither is sufficient and you need both.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/a64asm/lessons/a64-encoding">concept 2</a> measured <code>imms</code> and <code>immr</code> as bits[15:10] and bits[21:16] and warned that the mask is a lower bound; this page is the reason that warning is not pedantry, because a mask that stopped at bit 14 would still <em>look</em> like a valid imms. <a href="/courses/a64asm/lessons/a64-asm">Concept 1</a> measured the scaled add-immediate as the same 32 bits as <code>#1, lsl #12</code>, and this page is why that is a trap rather than a curiosity.</p>
                <p>Forwards, <a href="/courses/a64asm/lessons/a64-cond">concept 4</a> is about a twelve-bit field that is not a number either &mdash; the condition, and what <code>cset</code> does to it &mdash; and the two pages have the same shape: <strong>an encoding that spends a small field on a restricted set and pays for the restriction in the reader's head rather than in the bits.</strong> <a href="/courses/a64asm/lessons/a64-verify">Concept 5</a> is where normalisation rule 7 &mdash; the sign of an immediate, which three printers disagree about &mdash; is found by the cross-check, and it is nine of the eleven failures.</p>
                <p>Outward, this is the concept a compiler backend is written against. <strong>A backend that assumes a logical immediate is a number will emit masks clang refuses to assemble</strong>, and one that assumes MOVN's field is a value rather than a magnitude will compute complements wrong in a way that only shows on inputs where the value has its top bit set. Both are silent, and neither has a test that finds it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64asm/lessons/a64-encoding">The Class Field Is Four Bits, and the Field Map Is Measured</a></span>
                <span>Next: <a href="/courses/a64asm/lessons/a64-cond">Sixteen Conditions, Four Bits, and the Inversion That Hides</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
