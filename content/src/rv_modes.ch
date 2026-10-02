// The RISC-V Privileged Architecture -- concept 1: the CSR address and the
// twelve instructions that touch it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_modes() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The CSR Address and the Twelve Instructions That Touch It — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvpriv-concept">
            <a href="/courses/rvpriv" class="back-link">The RISC-V Privileged Architecture</a>
            <h1>The CSR Address and the Twelve Instructions That Touch It</h1>
            <div class="lesson-meta">26 min &middot; Concept 1 of 4 &middot; module: the address, the bits, and the trap &middot; <a href="/courses/rvpriv">The RISC-V Privileged Architecture</a></div>

            <div class="unit unit-why">
                <h2>The whole privilege convention is four bits of an address</h2>
                <p>Start with the number, because the number is where the privilege lives. A CSR address is twelve bits, and the specification splits the top four of them into two pairs with two different jobs: the upper pair says whether the register can be written, and the pair below it says <em>which privilege level is allowed to touch it at all</em>.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 2 'The top two bits'
  The top two bits (csr[11:10]) indicate whether the register is read/write
  (00, 01, or 10) or read-only (11). The next two bits (csr[9:8]) encode the
  lowest privilege level that can access the CSR.
                </pre>
                </div>
                <p>Now put two registers next to each other, which is what makes the convention worth reading twice:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 3 'So `stvec` at 0x105'
  So `stvec` at 0x105 is 00 / 01 / 0x05: read/write, lowest privilege S,
  number 5. `mtvec` at 0x305 is 00 / 11 / 0x05: read/write, lowest privilege
  M, number 5. THE SAME NUMBER, FIVE, IN BOTH, AND THE ONLY DIFFERENCE IS TWO
  BITS OF PRIVILEGE.
                </pre>
                </div>
                <p>Same register number, same access class, two bits apart. A supervisor kernel and a machine kernel both want a trap vector, both call it number 5, and the privilege bits are the entire reason they are different registers. That is what a convention <em>is</em>: not a name, but a number whose parts are assigned.</p>
                <p>And the table in the artifact prints the row you will not find in most summaries. The privilege field has <strong>four encodings and only three meanings</strong> &mdash; U, S, M &mdash; so one of them is a hole:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 2 'THE RESERVED ROW IS ALSO'
  THE RESERVED ROW IS ALSO IN THE TABLE, which is worth having: the
  user-level trap registers at 0x041 to 0x044 have `csr[9:8] = 0`, and 0x105's
  encoding value 2 in the privilege field is a hole that no standard register
  occupies.
                </pre>
                </div>
                <p>And the specification does that by <em>leaving it out of its own table</em>, which is the quietest way a standard can define a hole: there are four encodings of a two-bit field, three privilege levels, and the fourth value simply has no row. A reader who assumed all four values of a two-bit field were meaningful would expect four privilege levels. There are three.</p>
                <p>Printing the hole is not pedantry. A table with a gap and a table with a <em>hole</em> are different tables, and a reader who has only ever seen the filled-in version cannot tell which one they are looking at &mdash; so when they extend the table themselves, they will fill the hole without noticing.</p>
                <p>The accessibility half is measured too, which is the check on it. <code>cycle</code> at <code>0xc00</code> and <code>mvendorid</code> at <code>0xf11</code> both have <code>csr[11:10] = 11</code> and both are read-only; <code>stvec</code> at <code>0x105</code> and <code>satp</code> at <code>0x180</code> both have <code>00</code> and both are read/write. The artifact&rsquo;s sentence about that is the one worth keeping:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 2 'AND THE READ-ONLY CLASS'
  So the bit that says "you cannot write this" is in the address, and the
  SAME instruction with the same five bits in its operand slot is a legal read
  and an illegal write depending on two bits of a constant three instructions
  earlier.
                </pre>
                </div>
                <p>Three instructions earlier. That is the whole difficulty of a privileged architecture in one clause: the permission is not in the instruction, it is in a number the instruction carries, and the number was put there by whatever code computed it.</p>
            </div>

            <div class="unit unit-model">
                <h2>Twelve instructions, and one bit between the two families</h2>
                <p>The CSR address tells you <em>which</em> register. Six instructions tell you what you may do with it, in two source forms, and every one of the twelve words is read out of the object file rather than out of the manual.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE TWELVE INSTRUCTIONS/,/^$/p' | tail -5
  op       register form    word          funct3   immediate form    word          funct3   csr
  CSRRW    csrrw            0xc00312f3    1        csrrwi            0xc002d2f3    5        0xc00
  CSRRS    csrrs            0xc00322f3    2        csrrsi            0xc002e2f3    6        0xc00
  CSRRC    csrrc            0xc00332f3    3        csrrci            0xc002f2f3    7        0xc00
                </pre>
                </div>
                <p>Three operations &mdash; write-and-set, set, write-and-clear &mdash; and two families. Look at the last two columns: the register forms take <code>funct3</code> 1, 2, 3 and the immediate forms take 5, 6, 7. Now do the XOR, which is the entire finding of this section:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE ONE BIT/,/^$/p' | tail -5
  register form    funct3   immediate form     funct3   xor     where
  csrrw            1        csrrwi             5        0x04    bit 2 of funct3
  csrrs            2        csrrsi             6        0x04    bit 2 of funct3
  csrrc            3        csrrci             7        0x04    bit 2 of funct3
                </pre>
                </div>
                <p><strong>1 ^ 5 = 2 ^ 6 = 3 ^ 7 = 4</strong>, and 4 is bit 2 of a three-bit field. Three pairs, three identical deltas, one bit. A register operand and an immediate operand are the same instruction with one bit flipped, and the bit is <em>inside the selector</em> rather than anywhere in the operand fields.</p>
                <p>That is a design decision rather than an accident, and the reason is worth a sentence. A register field and an immediate field are the <strong>same width &mdash; five bits</strong>. A designer who had put them in different places would have had to spend a bit somewhere. RISC-V spends it in the selector instead, where it costs nothing at decode time because the selector is read first, and the reader gets <em>one selector with six values</em> instead of two selectors with three values each.</p>
                <div class="callout callout-note">
                    <p><strong>The alias table is where the mechanism becomes concrete.</strong> A pseudo-instruction is not a separate encoding; it is a three-operand form with <code>x0</code> in one of the two register slots, so <code>csrw cycle, t0</code> and <code>csrrw zero, cycle, t0</code> are the same four bytes. All eight comparisons in the artifact&rsquo;s table are byte-identical.</p>
                </div>
                <p>One of those eight is a mistake worth pre-empting, because it is the mistake this course&rsquo;s own first draft made. <strong><code>csrw</code> is <code>csrrw</code>, not <code>csrs</code></strong> &mdash; you might assume the <code>w</code> stands for &ldquo;write the value in&rdquo; rather than for the instruction&rsquo;s own mnemonic, and if you do, the comparison prints a difference of <code>0x00000000</code>, which is a real difference and not a typo: the two words differ in <code>funct3</code> alone, 1 against 2, a <em>write</em> against a <em>set</em>. That is retraction R3, and the way to tell which kind of difference you are looking at is to look at the XOR itself.</p>
                <h2>How wide is the field? Ask the assembler to refuse</h2>
                <p>Every manual draws the CSR field as twelve bits. The interesting question is not what the diagram says but whether the <em>tool</em> agrees, and the cheapest way to find out is to walk the tool up to its own boundary and read what it says.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  source  /,/^  csrw/p'
  source                  verdict    size      word          the assembler's own words
  csrr t0, 0x7ff          accepted   4 bytes   0x7ff022f3    csrr
  csrr t0, 0x800          accepted   4 bytes   0x800022f3    csrr
  csrr t0, 0xfff          accepted   4 bytes   0xfff022f3    csrr
  csrr t0, 0x1000         REFUSED    -         -             immediate must be an integer in the range [0, 4095]
  csrwi 0xfff, 0x1f       accepted   4 bytes   0xffffd073    csrwi
  csrwi 0xfff, 0x20       REFUSED    -         -             immediate must be an integer in the range [0, 31]
                </pre>
                </div>
                <p>Two boundaries, two fields, one message shape. 2<sup>12</sup>&minus;1 = 4095 and 2<sup>5</sup>&minus;1 = 31, and the field widths are the only difference between them &mdash; which is a check on the quoted &ldquo;twelve bits&rdquo; and the immediate form&rsquo;s five <em>at the same time</em>. Every refusal is quoted in the assembler&rsquo;s own words rather than summarised, because a summarised refusal is a refusal a reader has to trust.</p>
                <p>And there is a second measurement of the same width, which is the one that actually taught this section something. The artifact also <em>sweeps</em> the field: XOR every CSR word against a base and count which bits move.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -B 1 -A 2 'A MASK IS A LOWER BOUND'
  register forms differ in only TWO funct3 values out of the three the field
  can hold, because the base is funct3 = 2 and the sweep moved to 1 and 3. A
  MASK IS A LOWER BOUND AND A SWEEP OF THREE INSTRUCTIONS IN A FOUR-VALUE
  FIELD CANNOT FIND THE FOURTH.
                </pre>
                </div>
                <p>The raw sweep moved 20 bits. The isolated sweep &mdash; over the two-operand <code>csrr</code> words only, so that <code>funct3</code> and <code>rs1</code> are held constant rather than masked away afterwards &mdash; moved the CSR number and nothing else: bits 20 to 31, contiguous, twelve of them.</p>
                <div class="callout callout-warn">
                    <p><strong>And then the isolated sweep got it wrong too.</strong> The first version moved <em>eleven</em> bits, because every CSR number in the corpus happened to have bit 5 clear &mdash; so it reported a field of eleven bits for a field the specification says is twelve, and the missing bit was bit 25. Nothing in the output looked like a gap. <strong>A corpus in which every address has the same bit clear will report a field one bit narrower than it is.</strong></p>
                </div>
                <p>That is why the width here rests on <strong>two</strong> measurements and not one: the sweep says twelve bits moved, and the assembler&rsquo;s refusal at <code>0x1000</code> says twelve bits is all there is. A sweep alone would have said eleven and would have been right about its corpus &mdash; the least comforting kind of right.</p>
            </div>

            <div class="unit unit-example">
                <h3>Zicsr is not in the base ISA, and the ISA string does not notice</h3>
                <p>One fact here is quoted, because it is a fact about a document: the base integer set no longer contains the six CSR instructions, and a hardware implementation that includes the privileged architecture is expected to require them anyway. The base is <code>rv64i</code>; Zicsr is a separate standard extension that used to be folded into it.</p>
                <p>What <em>is</em> measurable is what the toolchain does about that, and the answer is the finding of this section. The corpus contains a file that is <code>csrr t0, cycle</code> and <code>ret</code> and nothing else, so the object cannot contain anything but the extension in question. Same source, three <code>-march</code> settings:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE SAME TWO INSTRUCTIONS, THREE/,/^$/p' | tail -5
  -march                      Tag_RISCV_arch in the object                word 0        claims zicsr?
  rv64i                       rv64i2p1                                    0xc00022f3    NO
  rv64i_zicsr                 rv64i2p1_zicsr2p0                           0xc00022f3    YES
  rv64i_zicsr_zifencei        rv64i2p1_zicsr2p0_zifencei2p0               0xc00022f3    YES
                </pre>
                </div>
                <p>Read the first row again. <code>-march=rv64i</code> &mdash; the base, no Zicsr &mdash; and the object contains <code>0xc00022f3</code>, which is a Zicsr instruction, and the ISA string says <code>rv64i2p1</code> with no <code>zicsr</code> in it.</p>
                <div class="callout callout-note">
                    <p><strong>What this does and does not show.</strong> It shows that the assembler emitted an instruction outside the ISA the object claims to implement, and gave no diagnostic. It does <em>not</em> show a broken toolchain: the privileged architecture is expected to require these instructions anyway, so a linker or loader that sees <code>rv64i2p1</code> and rejects the file would be wrong in the direction that matters. The honest statement is that <strong>the ISA string is a record of the request, not a description of the contents</strong> &mdash; which is a different claim from the one <a href="/courses/rvasm/lessons/rv-isa"><code>rv-isa</code></a> makes about the same string, and the reason both pages exist.</p>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>What was measured here, and what was not</h2>
                <p>Not one instruction on this page has run. That does not weaken the encodings &mdash; a word in an object file is either the encoding or it is not &mdash; but it does bound the privilege claim completely.</p>
                <ul>
                    <li><strong>MEASURED-ON-BYTES:</strong> the twelve instruction words; the three XORs and the one bit they share; all eight alias comparisons and the zero count of differences; the two field boundaries, by the assembler&rsquo;s refusals; the twelve-bit field, by two independent measurements; the three <code>Tag_RISCV_arch</code> strings.</li>
                    <li><strong>MEASURED:</strong> the number of corpus objects present; that the pairing of source lines to words is checked on every run rather than assumed.</li>
                    <li><strong>QUOTED:</strong> that <code>csr[11:10]</code> is accessibility and <code>csr[9:8]</code> is privilege, with the document and section; that Zicsr is outside the base integer set; that encoding 2 in the privilege field is reserved.</li>
                    <li><strong>NOT MEASURED, AND NOT MEASURABLE HERE:</strong> that a write to <code>mtvec</code> from S-mode raises an illegal-instruction exception. The privilege bits are measured as <em>numbers</em>; the rule that turns the numbers into an exception is quoted, and there is no S-mode on this host to be refused by. <strong>Every enforcement claim on this page is a quotation with a section number attached</strong>, and <a href="/courses/rvpriv/lessons/rv-boundary">concept 4</a> is where all of them are listed in one table with their labels.</li>
                </ul>
                <p>Two retractions came out of this page, and both are printed in full in the artifact. <strong>R1</strong> is that the borrowed decoder covers what this course needs of the CSR address space &mdash; it prints the number and stops, and printing the number is not decoding the privilege. The correction is a model <em>prepended</em> in this file, with the sibling untouched. <strong>R2</strong> is the mask sweep above, and its lesson generalises past this architecture: <em>a mask with a hole in it is a number about the set you swept, not about the field.</em></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Find the one bit yourself.</strong> <em>(Take the twelve words in the table above and XOR each register form against its immediate form by hand. Three XORs, three identical values, and one bit. Then ask the design question the answer implies: if <code>rd</code> and <code>zimm</code> are both five bits wide, why does the architecture need a selector bit at all? Write your answer before reading the paragraph above that gave it.)</em></li>
                    <li><strong>Build a corpus with a hole in it and watch the sweep report a smaller field.</strong> <em>(Take <code>csr.s</code>, which deliberately includes two addresses with bit 5 set so that the isolated sweep can find all twelve bits. Delete those two lines, rebuild, and re-run. The sweep will report <strong>eleven</strong> bits moved &mdash; for a field the specification says is twelve &mdash; and there will be nothing in the output that looks like a gap. The assembler&rsquo;s refusal at <code>0x1000</code> will be unchanged, because the assembler knows the real width. That disagreement is the whole lesson of this page.)</em></li>
                    <li><strong>Write a decoder for the CSR address and then write its test.</strong> <em>(Take ten words from <code>csr.o</code>, decode the CSR number, the accessibility pair and the privilege pair, and check your output against the artifact&rsquo;s table. Then extend it with one address whose privilege encoding is 2. Your decoder will happily print &ldquo;RESERVED&rdquo;, which is right &mdash; and you should notice that you got that right by having read the specification rather than by having measured anything.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Back to <a href="/courses/rvasm/lessons/rv-encoding"><code>rv-encoding</code></a>, which is where the base ISA fields this page opens were laid out; the twelve bits here are <code>inst[31:20]</code> of an instruction that <em>reads and writes</em> them, which is the shape of difference that <code>rv-encoding</code> deliberately did not cover. And forward to <a href="/courses/rvpriv/lessons/rv-traps">concept 3</a>, where the same twelve bits decide which of the five trap registers a program may touch and where the same <code>funct3</code> bit decides whether the write is discardable.</p>
                <p>Across the collection, <a href="/courses/a64sys/lessons/a64-syscall"><code>a64-syscall</code></a> and <a href="/courses/x86sys/lessons/x86-syscall"><code>x86-syscall</code></a> ask the same question on machines this collection can run. The difference worth carrying between them is not the answer but the method: those courses could watch a trap happen, and this one cannot, so it had to find something else that a build machine can check. <a href="/courses/rvpriv/lessons/rv-paging">Concept 2</a> is the other half of that answer.</p>
            </div>

            <div class="lesson-footer">
                <span>Next: <a href="/courses/rvpriv/lessons/rv-paging">Sv39, Sv48, Sv57 and satp, Measured on the Compiler's Own Shifts</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}