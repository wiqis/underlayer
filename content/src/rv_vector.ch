// RISC-V atomics -- concept 3: vsetvli, the four fields it carries, and the
// length that is not in it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_vector() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("vsetvli and the Four Fields It Carries — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvat-concept">
            <a href="/courses/rvat" class="back-link">RISC-V Atomics and the Vector Extension</a>
            <h1>vsetvli and the Four Fields It Carries</h1>
            <div class="lesson-meta">27 min &middot; Concept 3 of 4 &middot; module: vector &middot; <a href="/courses/rvat">RISC-V Atomics and the Vector Extension</a></div>

            <div class="unit unit-why">
                <h2>A 32-bit word that describes a vector of any length</h2>
                <p>MEASURED-ON-BYTES, and this is the sharpest encoding result in the course. <strong>One fixed 32-bit instruction describes a vector, and the length is not in this instruction at all.</strong></p>
                <p>That sounds like a defect and it is the design. <code>vsetvli</code> carries four things &mdash; the element width, the register-group multiplier, and the tail and mask policies &mdash; and it carries a fifth thing that is not a field but an <strong>absence</strong>: the length. The <em>requested</em> length is an AVL and it arrives in <code>inst[19:15]</code>; the length that comes out lives in a CSR the instruction does not contain. So the instruction is a <strong>description and not a value</strong>: it says what kind of vector to use, and the machine says how many elements that is. That is how one encoding serves a machine with 128-bit vectors and a machine with 1024-bit vectors &mdash; there is nothing in the word to disagree about.</p>
                <div class="callout callout-key">
                    <p><strong>Compare this to the other two designs and the difference is in kind again.</strong> A wider register file puts the length in the hardware and the compiler in the loop. A mask register puts it in a named register. RISC-V puts it in a <em>readable CSR</em>, so a program that guessed wrong finds out at run time instead of reading a number the hardware never told it. <strong>That is a design decision about what to make observable, and it is the reason portable vector code on this architecture is possible at all.</strong></p>
                </div>
                <p>The compiler proves the claim rather than the page asserting it, and it does it in the most ordinary instruction there is:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/PROVES THE LENGTH IS NOT/,/csrr t0/p' | head -7
    -O2  vadd_d   0xc22028f3  csrr a7, vlenb
    -O2  vmac_l   0xc22026f3  csrr a3, vlenb
    -O2  vmul_s8  0xc2202873  csrr a6, vlenb
    -O2  vsum_d   0xc22026f3  csrr a3, vlenb
    -Os  vmac_l   0xc22022f3  csrr t0, vlenb
    -Os  vsum_d   0xc22028f3  csrr a7, vlenb
                </pre>
                </div>
                <p><code>csrr a7, vlenb</code> &mdash; a CSR read, an ordinary Zicsr instruction, the same encoding as <code>csrr a7, cycle</code> with a different number. And the CSR number is measurable, and it lands in the range the privileged course already decomposed:</p>
                <div class="hex-dump">
                <pre>    0xc22028f3  csrr a7, vlenb
      csr = inst[31:20] = 0xc22   funct3 = 2 (CSRRs)   rd = 17
      csr[11:10] = 0b11  accessibility: READ-ONLY
      csr[9:8]   = 0b00  lowest privilege: U
                </pre>
                </div>
                <p>Read-only from user mode, and the manual calls the value a design-time constant in any implementation. <strong>What VLEN is on a machine this course has never seen is therefore not a number this course has, and a VLEN of 128 and a VLEN of 1024 would both produce exactly this assembly.</strong> That is not a gap in the measurement; it is the design working.</p>
            </div>

            <div class="unit unit-model">
                <h2>Four fields, each isolated by an XOR</h2>
                <p>The map of the eleven-bit type field, measured rather than read off a diagram: one variant is the base and each row changes exactly one thing, so the XOR is the field.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE FOUR FIELDS, EACH ISOLATED/,+8p'
  the variant      zimm[10:0]   XOR against e8/m1/tu/mu  bits moved  which
  e8, m1, tu, mu   00000000000  0x00000000               0
  e16, m1, tu, mu  00000001000  0x00800000               1           bit 23
  e32, m1, tu, mu  00000010000  0x01000000               1           bit 24
  e64, m1, tu, mu  00000011000  0x01800000               2           bit 23, bit 24
  e8, m2, tu, mu   00000000001  0x00100000               1           bit 20
  e8, m8, tu, mu   00000000011  0x00300000               2           bit 20, bit 21
  e8, m1, ta, mu   00001000000  0x04000000               1           bit 26
  e8, m1, tu, ma   00010000000  0x08000000               1           bit 27
                </pre>
                </div>
                <p>Six of the twelve probes move a single bit &mdash; one per field &mdash; and the rows that move two or three are the rows changing a three-bit field at once. The field map that falls out is exactly what the specification draws, and it is worth drawing out because of the <em>reserved</em> bits:</p>
                <div class="hex-dump">
                <pre>      vma       zimm[7]      one bit, the MASK policy
      vta       zimm[6]      one bit, the TAIL policy
      vsew[2:0] zimm[5:3]    three bits, the ELEMENT WIDTH
      vlmul[2:0]zimm[2:0]    three bits, the REGISTER GROUP
      RESERVED  zimm[10:8]   THREE BITS THAT NO REACHABLE vsetvli USES

  MEASURED: zimm[10:8] is 0b000 in all 120 `vsetvli` in the corpus
                </pre>
                </div>
                <p>One hundred and twenty reachable configurations in the corpus, four element widths times seven register-group multipliers times two tail policies times two mask policies, and <strong>three bits of the eleven-bit field are constant zero across every one of them</strong>. The manual agrees and says what they are for &mdash; the <code>vill</code> bit sits above them and the whole block is reserved if non-zero.</p>
                <div class="callout callout-note">
                    <p><strong>Three bits that never move look exactly like three bits that do.</strong> A field map measured by sweeping records which bits <em>move</em>; a field map read off a diagram records which bits are <em>set</em> in somebody&rsquo;s example. The sibling <a href="/courses/rvasm/lessons/rv-encoding">encoding course</a> measured <code>vsetvli</code> at four bytes and found the same three bits constant, and this page builds on that rather than repeating it &mdash; but the generalisation is the point: <em>a field map measured by sweep records which bits move, and a field map copied from a table records which bits someone used.</em></p>
                </div>
                <p>And it is not waste. The reserved bits are at the top, with <code>vill</code> above them, so a future extension that wants a field gets the space <strong>without moving any bit anyone already uses</strong> &mdash; which is what a fixed 32-bit encoding has to be designed for and what x86-64 could not do, because its instruction length is variable and its prefixes are not fields at all.</p>
            </div>

            <div class="unit unit-example">
                <h2>Two bits of register identity carrying a three-way choice</h2>
                <p>The length is not the only thing the instruction does not contain. So is the <em>meaning</em> of <code>inst[19:15]</code>, and the same field is a register in two instructions and an immediate in the third:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE THREE CONFIGURATION INSTRUCTIONS/,+4p'
  word        the instruction, as it disassembles  inst[31:30]  inst[19:15]  at
  0x0c55f2d7   vsetvli    t0, a1, e8, mf8, ta, ma  0b00        11          0x0
  0xcd0072d7   vsetivli   t0, 0x0, e32, m1, ta, ma  0b11        0           0x8
  0x80c5f2d7   vsetvl     t0, a1, a2               0b10        11          0x1c
                </pre>
                </div>
                <p>Three instructions, <strong>told apart by two bits and by nothing else</strong>: <code>inst[31:30]</code> of <code>00</code> is <code>vsetvli</code>, <code>10</code> is <code>vsetvl</code>, <code>11</code> is <code>vsetivli</code>. The other twenty-nine bits are laid out the same way in all three. The table&rsquo;s last column is the address in the committed listing, so a reader with a hex editor and no cross-compiler can find the same three lines.</p>
                <p>And the harness checks that column <strong>against the words themselves</strong> &mdash; 129 configuration rows, every one&rsquo;s printed mode compared with the mode decoded from its own word. A row claiming <code>vsetvl</code> at <code>0b00</code> would be a table saying the opposite of the sentence three lines above it, and a table nobody parses is a table that can be edited into a different claim without anything noticing.</p>
                <p>Now the two-bit register argument again, on the AVL side. Chapter 30&rsquo;s Table 49 has three cases, and which one you get is decided by <em>whether two registers are zero</em>:</p>
                <div class="hex-dump">
                <pre>    rd    rs1   AVL value              Effect on vl
    -     !x0   Value in x[rs1]        Normal strip mining
    !x0   x0    ~0                     Set vl to VLMAX
    x0    x0    Value in vl register   Keep existing vl
                </pre>
                </div>
                <p>Three rows, three different meanings, and the mechanism is two bits of <em>register number</em> &mdash; which is the same kind of argument as <code>inst[31:30]</code> choosing the instruction, and it is why no decoder can treat <code>rd</code> and <code>rs1</code> as ordinary operands without reading which instruction it is looking at first. <strong>A register number is normally a name; here it is a switch.</strong></p>
                <p>And the compiler uses the VLMAX row: of the 120 <code>vsetvli</code> in the corpus, <strong>117 name a register and 3 ask for VLMAX by putting <code>x0</code> in <code>rs1</code></strong>. So the shape the compiler prefers is the one where the value is not in the instruction &mdash; which is the whole design again, one instruction deeper.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The tail policy: where portable vector code goes to get hard</h2>
                <p>Two independent bits, four combinations, and the one on the right is &ldquo;agnostic&rdquo; &mdash; which means the hardware may leave the tail alone or may overwrite it with all ones, <strong>at its discretion</strong>. And the manual is explicit that the pattern need not even be repeatable:</p>
                <div class="hex-dump">
                <pre>    rv32-unpriv, chapter 30, section 31.3.4.3:
        vta vma  Tail Elements      Inactive Elements
         0   0    undisturbed       undisturbed
         0   1    undisturbed       agnostic
         1   0    agnostic          undisturbed
         1   1    agnostic          agnostic
                </pre>
                </div>
                <div class="callout callout-key">
                    <p><strong>That is a library contract made of bits, and it is the one place in the vector extension where the answer is &ldquo;the hardware may do either&rdquo;.</strong> The specification says each destination element can be either left undisturbed or overwritten with ones, in any combination, and that the pattern is <em>not required to be deterministic</em> when the instruction is executed with the same inputs. <strong>Portable vector code must therefore choose <code>tu</code>/<code>mu</code> unless it knows the target, and every performance-minded vector loop wants <code>ta</code>/<code>ma</code> &mdash; so the fast version is not the portable one, and the encoding is where that decision becomes visible.</strong></p>
                </div>
                <p>And what the compiler does with it is measured, which is the part that should worry you:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/MEASURED, in the corpus/,+7p'
  tail  mask  how many of the corpus's vsetvli
  ta    ma    31
  ta    mu    29
  tu    ma    28
  tu    mu    32

  31 of 120 are tail-AGNOSTIC and mask-AGNOSTIC.
                </pre>
                </div>
                <p>Thirty-one of a hundred and twenty are the fully agnostic pair. <strong>And that is the fast choice, not the portable one, so the compiler is making a non-portable choice in its default output and the only way a reader learns it is by decoding two bits.</strong> This is why <a href="/courses/simd/lessons/simd-boundaries">the neutral course on vector boundaries</a> spends a page on the remainder problem: on an architecture where the tail policy is unspecified, a tail loop you wrote yourself is a portability decision you made without being asked.</p>
                <p>There is one more piece of the story and it is about the assembler rather than the hardware. The specification used to make the flags optional with a default, then made them <strong>mandatory</strong>, and the artifact prints both the change and the reason it was a good change:</p>
                <div class="callout callout-note">
                    <p><strong>The defaults changed and the change was made by removing the default.</strong> The specification&rsquo;s own suggestion had been that the default should perhaps be the agnostic pair; the assembler disagreed and kept the historical undisturbed default, and then a later version deprecated the omission entirely. <strong>Removing a default is a better answer than changing one</strong>: a program that says nothing now gets a diagnostic, and a program that says <code>tu</code> means it. That is the only way two versions of a specification can disagree without a compiler being unable to tell which is which &mdash; and the three refusals that show it are in the artifact, because a rule you can see refused is a rule you can trust.</p>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Find the bits that never move.</strong> <em>(The artifact swept 112 <code>vsetvli</code> variants and found <code>zimm[10:8]</code> constant. Do it yourself: assemble <code>vsetvli t0, a1, e8, m1, tu, mu</code> and <code>vsetvli t0, a1, e64, m1, tu, mu</code> and XOR the two words. The bits that change are the width. Now ask which bits in the eleven-bit field you have <em>not</em> moved, and what would have to be true of the hardware for them to be reachable at all.)</em></li>
                    <li><strong>Ask the assembler about a field that means two things.</strong> <em>(Assemble <code>vsetvli t0, a1, e8, m1, tu, mu</code> and <code>vsetivli t0, 0x1f, e8, m1, tu, mu</code> and XOR them. The bits that move are in <code>inst[19:15]</code> &mdash; the field the base ISA calls <code>rs1</code>. <strong>Now read the base ISA&rsquo;s field map for <code>inst[19:15]</code> and notice it is right and wrong at the same time, depending on which instruction you are looking at.</strong> A field whose meaning is a function of a neighbour is not a register.)</em></li>
                    <li><strong>Count the agnostic tails in a real build.</strong> <em>(Compile a vectorised loop and grep the disassembly for <code>ta, ma</code> against <code>tu, mu</code>. Then read what the specification says the second one guarantees and the first one does not. <strong>You have just found a portability decision your compiler made for you, and the only way to see it is to decode two bits of an eleven-bit field.</strong> That is the cost of the design, and it is cheap until you move the binary.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>What a vector lane is and what a reduction is &mdash; in neutral terms, with no architecture attached &mdash; is <a href="/courses/simd/lessons/simd-width">simd-width</a> and <a href="/courses/simd/lessons/simd-reduce">simd-reduce</a>. Why a vectorised loop needs a remainder, and why that is hard to do portably, is <a href="/courses/simd/lessons/simd-boundaries">simd-boundaries</a>, and this page is the architecture-specific answer to the question it asks. What the vectoriser does and does not do is <a href="/courses/simd/lessons/simd-compiler">simd-compiler</a>; the same subject on the other two architectures is <a href="/courses/a64simd/lessons/a64-neonspace">a64-neonspace</a>, where the length <em>is</em> in the instruction and the answer is different for a reason you can now state. And the encoding course&rsquo;s <a href="/courses/rvasm/lessons/rv-encoding">rv-encoding</a> is where <code>vsetvli</code> at four bytes with three constant-zero bits was first measured &mdash; this page builds on that and does not repeat it.</p>
                <p>Next: <a href="/courses/rvat/lessons/rv-dataflow">Decode the Data Path</a> &mdash; because a configuration instruction that sets a policy is not much use until you can see what the policy does to a load, and the next page reads the data path a byte at a time.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvat/lessons/rv-fence">fence, and an Ordering Model Defined in Terms of It</a></span>
                <span>Next: <a href="/courses/rvat/lessons/rv-dataflow">Decode the Data Path</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
