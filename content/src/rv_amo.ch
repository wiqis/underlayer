// RISC-V Atomics -- concept 1: the zero, the encoding, the two ordering bits,
// and why the retry is the instruction.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_amo() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Reservation, and Why the Retry Is the Instruction — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvat-concept">
            <a href="/courses/rvat" class="back-link">RISC-V Atomics and the Vector Extension</a>
            <h1>The Reservation, and Why the Retry Is the Instruction</h1>
            <div class="lesson-meta">26 min &middot; Concept 1 of 4 &middot; module: atomic &middot; <a href="/courses/rvat">RISC-V Atomics and the Vector Extension</a></div>

            <div class="unit unit-why">
                <h2>The trap, stated before the count</h2>
                <p>On x86-64 the atomicity of an ordinary arithmetic instruction depends on a <strong>prefix that is not part of the instruction</strong>. Eighteen instructions accept <code>LOCK</code>, the memory form of <code>xchg</code> is implicitly locked with or without it, and a programmer who omits it gets <strong>no diagnostic at all</strong> &mdash; the instruction still assembles, still runs, and is simply not atomic. That is the kind of thing a course about the other architecture has to say out loud before it shows you anything, because you are about to read a page full of counts that are all zero and zero is a number that hides.</p>
                <p>RISC-V has no such thing. There is no prefix, there is no flag, and there is no implicit lock on any instruction. The atomics are a third instruction group under their own opcode, and each one is atomic because of what it <em>is</em>.</p>
                <p>Now the part that makes the contrast a measurement rather than a claim, and it is the reason this page exists. &ldquo;Zero against eighteen&rdquo; is a number a reader should be able to check on both sides, so the artifact counts both sides <strong>in the same session, with the same tools</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 1 'THE COUNT:'
  THE COUNT: 0 instructions in the RISC-V corpus take a lock prefix.

$ python3 rvat.py --run | grep 'lock-prefixed instructions assembled'
  22 lock-prefixed instructions assembled, and 0 unprefixed
  line in the file.  The DISTINCT mnemonics among them are 22:
                </pre>
                </div>
                <p>Zero against twenty-two. And notice what was asked: the RISC-V count is nine probes including the literal word <code>lock</code>, and the answer is the assembler&rsquo;s <strong>unknown token</strong> &mdash; not a bad operand, not a warning:</p>
                <div class="hex-dump">
                <pre>  REFUSED     lock add a0, a1, a2              unexpected token
  REFUSED     lock lw a0, 0(a1)                unexpected token

    `lock` is not a mnemonic, a modifier or a reserved word on
    this target.  It is a token the assembler does not know, and
    the diagnostic is `unexpected token`.
                </pre>
                </div>
                <p>That detail is load-bearing, and it is the difference between a claim about an architecture and a claim about a tool. <strong>The assembler refusing <code>lock</code> is a fact about the assembler.</strong> The claim needs to be about the architecture, and the measurement that carries it is the <em>other</em> count: how many instructions are atomic with no prefix at all.</p>
                <div class="callout callout-note">
                    <p><strong>So the zero is not printed alone.</strong> Nine operations plus a reservation pair, at two widths and four orderings, are atomic with no prefix whatsoever. A zero printed beside nothing is an absence of features; a zero printed beside that number is a design decision, and it costs the programmer <strong>the ordinary-operator shortcut</strong> &mdash; because compare-exchange, which is two words of x86 assembly with a <code>lock</code> on it, becomes a <code>lr</code>/<code>sc</code> pair inside a loop, and there is no <code>cmpxchg</code> in the base A extension at all. That is the cost, and a course that only advertises is not a reference.</p>
                </div>
                <p>And the structural reason the two lists differ in length is not the length. It is that <strong>x86-64 made atomicity a property of an existing instruction and RISC-V made it a category of instruction</strong>. A property and a category are different objects, and the difference shows up in what happens when you forget: on x86-64 forgetting is silent, and on RISC-V forgetting is not possible, because there is nothing to forget. The ordinary <code>add</code> is not atomic and never claims to be; the atomic is a different instruction with a different name, visible in a disassembly and checkable in a review.</p>
            </div>

            <div class="unit unit-model">
                <h2>One opcode, eleven names, twenty-one holes</h2>
                <p>MEASURED-ON-BYTES. The A extension is <strong>one opcode, 0101111</strong>, and inside it a five-bit <code>funct5</code> at <code>inst[31:27]</code>. Eleven of the thirty-two values are named. Then a three-bit <code>funct3</code> of which only two are AMO widths &mdash; <code>010</code> is a word, <code>011</code> a doubleword. The word comes before the name in the table, because the word is the thing you have to check:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE ELEVEN OPERATIONS AT BOTH/,+6p'
  operation  word        assembled  funct5  funct3  aq  rl  bytes
  amoadd     0x00b6252f  amoadd.w   00000   2       0   0   4
  amoadd     0x00b6352f  amoadd.d   00000   3       0   0   4
  amoswap    0x08b6252f  amoswap.w  00001   2       0   0   4
  amoswap    0x08b6352f  amoswap.d  00001   3       0   0   4
  amoxor     0x20b6252f  amoxor.w   00100   2       0   0   4
                </pre>
                </div>
                <p>Eleven distinct operations, eleven distinct <code>funct5</code> values, two widths, four bytes each &mdash; and the holes are printed rather than omitted, because <strong>a table with a gap and a table with a hole are different tables</strong> and a reader who has only ever seen one of them cannot tell which they are looking at:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 4 'ELEVEN NAMES AND TWENTY-ONE HOLES'
  11 named of 32, so 21 unnamed, and 2 of the eleven are the
  reservation pair -- which is why the A extension is not "eleven
  atomics" but "nine atomics and a two-instruction construct that no
  single instruction is".
                </pre>
                </div>
                <p>Two things fall out of that count, and neither is a coincidence. First, the eleven values are <strong>not evenly spaced</strong> &mdash; they sit in a stride-4 block, with the four bitwise operations at 0, 4, 8 and 12 and the four ordering comparisons at 16, 20, 24 and 28. A reader who expects eleven evenly spaced values writes a decoder with eleven cases where three would do. Second, the reservation pair sits at 2 and 3, <em>inside</em> the first block, next to the arithmetic pair: <strong>the two instructions that are not atomic operations are the two that implement a construct, and the encoder put them where a construct belongs.</strong></p>
                <h3>The width is one bit, and that is the whole of the width story</h3>
                <p>Here is the next result, and it is a result you can check with a pencil. Take an instruction and its <code>.d</code> twin: same opcode, same operands, same everything except one bit.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE WIDTH IS ONE BIT/,+4p'
  the pair               XOR         bits that moved  reading
  amoadd.w / amoadd.d    0x00001000  1                bit 12 of funct3
  amoswap.w / amoswap.d  0x00001000  1                bit 12 of funct3
  ... and twelve rows in all ...

  12 of 12 pairs XOR to exactly 0x1000.
                </pre>
                </div>
                <p>Twelve pairs, every one <strong>exactly</strong> <code>0x1000</code>, one bit, bit 12 of <code>funct3</code>. The <code>.w</code>/<code>.d</code> suffixes look like a type and they are a single bit, and <strong>a field with two names is not a type &mdash; it is a bit with two spellings</strong>. That is worth knowing for a specific reason: a bit with two names is a bit a decoder can read with one table, and it is the same shape as <code>fadd.s</code> against <code>fadd.d</code> in the AArch64 material, which is also one bit.</p>
                <div class="callout callout-note">
                    <p><strong>The same claim arrives from the other direction on this course&rsquo;s landing page, and the two are the same fact.</strong> When the A extension is absent the compiler falls back to <code>__atomic_compare_exchange_4</code> &mdash; and there the width is a <em>template parameter in a symbol name</em>. One bit in the hardware path, a number in a name in the fallback path. <strong>A type that is a number in one place and a bit in another is two representations of one decision, and the decision is made by the compiler, not by the programmer.</strong></p>
                </div>
                <p>The consequence for the encoding is worth one sentence, because it is the reason a RISC-V atomic is four bytes and an x86-64 locked instruction is one to four plus something the decoder has to recognise <em>before</em> it can know the length: on RISC-V the ordering bits and the width are <strong>ordinary fields of an ordinary word</strong>. A suffix is not a type, a prefix is not a word, and both of those facts are visible in a byte count.</p>
            </div>

            <div class="unit unit-example">
                <h2>aq and rl: two adjacent bits, and the XOR is the proof</h2>
                <p>The next two bits down, <code>inst[26]</code> and <code>inst[25]</code>, are the ordering. The measurement is not a reading of a manual; it is a subtraction. Set <code>aq</code> on an instruction that did not have it, and the difference is a single bit. Do it at both widths, on all three kinds of instruction, and print every result:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep 'THE SET OF'
  THE SET OF aq XORs OVER THE WHOLE CORPUS: 0x04000000
  THE SET OF rl XORs OVER THE WHOLE CORPUS: 0x02000000
  THE SET OF aqrl XORs OVER THE WHOLE CORPUS: 0x06000000
                </pre>
                </div>
                <p>One number for <code>aq</code> across every operation, every width, all three instruction kinds. One for <code>rl</code>. One for the pair. <strong><code>aq</code> is bit 26, <code>rl</code> is bit 25, they are adjacent, and that is the whole encoding.</strong> No prefix, no second instruction, two of thirty-two bits.</p>
                <p>And the three are <strong>additive</strong>, which is the cheapest possible proof that they are two fields rather than one field with three values &mdash; because a decoder can recover a two-bit field by OR-ing two single-bit masks and <em>cannot</em> recover a single field with four values that way. Additivity is not a confirmation of the positions; it is the reason they are fields.</p>
                <p>What the two bits <em>buy</em> is quoted, and the quotation is the point rather than the padding. Chapter 12 gives the four C11 semantics: acquire on <code>aq</code> alone, release on <code>rl</code> alone, sequentially consistent on both. So four semantics, two bits. And the other two architectures in this collection reach the same four by <strong>different mechanisms</strong>: AArch64 spends two <em>opcodes</em> (<code>ldar</code> and <code>stlr</code> are not <code>ldr</code> and <code>str</code>), and x86-64 spends nothing at all. RISC-V spends two bits where AArch64 spends two opcodes and x86-64 spends nothing, and the reason is that it did not want a fourth instruction group.</p>
                <p>And the same four semantics are reachable with a fence instead, which is the thing that makes the model different <em>in kind</em>:</p>
                <div class="callout callout-key">
                    <p><strong>A RISC-V atomic is a fence with the unnecessary part removed, and the two bits are where the removal is recorded.</strong> Chapter 12 says the <code>FENCE R, RW</code> instruction suffices for acquire and <code>FENCE RW, W</code> for release &ldquo;as compared to AMOs with the corresponding aq or rl bit set&rdquo; &mdash; that is, the bits save you the ordering you did not ask for. A reader who only ever reads the fence form will not notice the bits exist; a reader who only ever reads the bits will not know what relation between two sets of operations the fence form is expressing. <strong>Both sides have to be measured, which is why this course has a page for the fence at all.</strong></p>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>lr and sc: the retry is the instruction</h2>
                <p>MEASURED-ON-BYTES for the encodings, QUOTED for the reservation rules, and the division is the boundary of the whole concept rather than a convenience.</p>
                <p>x86-64 has a compare-and-swap. <code>cmpxchg</code> with a <code>lock</code> prefix is one instruction that either swaps or does not, and a loop around it is a performance habit. RISC-V has <strong>no compare-and-swap in the base A extension at all</strong>. What it has is two instructions that must be used in pairs and that report failure <em>in a register</em> &mdash; and a pair that reports failure to a caller who must branch is not a pair, it is a loop. <strong>The retry is not syntax around the instruction; it is what the instruction is.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE LOOP, MEASURED/,+9p'
  word        mnemonic   operands                     bytes
  0x0005869b  sext.w     a3, a1                       4
  0x160525af  lr.w.aqrl  a1, (a0)                     4
  0xfed59ce3  bne        a1, a3, 0x40 &lt;amo_cas_loop&gt;  4
  0x1ac5272f  sc.w.rl    a4, a2, (a0)                 4
  0xfe071ae3  bnez       a4, 0x44 &lt;amo_cas_loop+0x4&gt;  4
  0x00068513  mv         a0, a3                       4
  0x00008067  ret                                     4

  7 instructions: 1 lr, 1 sc, 2 branches, and the rest is the
  comparison of the loaded value against the expected one.
                </pre>
                </div>
                <p>Seven instructions, one <code>lr</code>, one <code>sc</code>, and <strong>the branch after the <code>sc</code> is the retry</strong>. The compiler did not choose a compare-and-swap, because there is not one to choose. The <code>__sync</code> spelling costs the compiler one extra instruction per attempt for a reason that has nothing to do with the hardware &mdash; it takes no expected-out pointer, so the compiler cannot learn the memory word&rsquo;s value from a failed attempt and has to reload it. <strong>Same hardware, same instruction pair, two instructions per attempt against one, and the difference is entirely in the calling convention of the source language.</strong></p>
                <p>And the asymmetry in the suffixes is not a typo. The <code>lr</code> carries <strong>both</strong> bits and the <code>sc</code> carries only <code>rl</code>, and chapter 12 says why: software should not set <code>rl</code> on an <code>LR</code> unless <code>aq</code> is also set, nor <code>aq</code> on an <code>SC</code> unless <code>rl</code> is. So a two-bit field admits four combinations and only three are meaningful on each instruction &mdash; <strong>a field whose validity depends on a neighbour field, which a decoder that reads it without reading which instruction it is on will name as four things that are two.</strong></p>
                <h3>The constraints, and the ones that are quoted</h3>
                <p><code>lr</code> requires <code>rs2 = 0</code> and the assembler <strong>enforces</strong> it. That is a measurement, and the refusal is the cheapest possible proof that a constraint is real:</p>
                <div class="hex-dump">
                <pre>  lr.w a0, a1, (a2)          REFUSED  lr with a THIRD operand
                                  expected '(' or optional integer offset
  sc.w a0, (a1)              REFUSED  sc with only TWO operands
  amoadd.w a0, (a1)          REFUSED  an AMO with only TWO operands
  lr.w.t a0, (a1)            REFUSED  a MASKED lr, which does not exist
  amoadd.b a0, a1, (a2)      REFUSED  a BYTE AMO, which is Zabha
                </pre>
                </div>
                <p><strong>And the diagnostic is about spelling while the cause is about semantics.</strong> The assembler is not saying you wrote the syntax wrong; it is saying the instruction has no <code>rs2</code> to give. That is a general lesson about assemblers and it costs nothing to learn here. The <code>Zabha</code> row is a different kind of good error: the diagnostic <em>names the letter that would make it work</em>, which is a better message than &ldquo;unknown instruction&rdquo; and a reminder that the ISA is a set of documents.</p>
                <h3>What may sit between the halves, and what may not</h3>
                <p>That is quoted, and the rule is what the calling convention has to protect: a hart can hold only <strong>one reservation at a time</strong>, so a second <code>lr</code> invalidates the first, and a function call in the middle of a pair kills it. The mitigation is in the manual too &mdash; a store-conditional to a scratch word, to forcibly invalidate a reservation during a context switch. And the eventuality guarantee is what stops the loop from being an unbounded one: a <em>constrained</em> sequence of LR/SC pairs, with nothing else between the halves, must eventually make progress.</p>
                <div class="callout callout-warning">
                    <p><strong>And none of that has been observed.</strong> No reservation is ever held on this host. There is no hart here to hold one, no other hart to invalidate it, and no scheduler to preempt the thread between the halves. What is measured is that <strong>clang emits</strong> an <code>lr.w.aqrl</code> and an <code>sc.w.rl</code> with a branch between them &mdash; a fact about a compiler, not a fact about an atomic. That line is in the artifact at the end of the section, in the header, and as limit 3, and it is the sentence this whole course is built to keep honest.</p>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>XOR the widths yourself.</strong> <em>(In <code>amo_objdump.txt</code>, take the <code>amoadd.w</code> line and the <code>amoadd.d</code> line and subtract. You should get <code>0x1000</code> and nothing else. Now do the same for <code>amoswap</code> and for <code>lr</code>, and ask what a decoder that hard-coded the XOR instead of reading <code>funct3</code> would do about an instruction pair this course does not contain.)</em></li>
                    <li><strong>Find the constraint the assembler knows and you do not.</strong> <em>(Run <code>llvm-mc-21 --target=riscv64 -assemble</code> on <code>lr.w a0, a1, (a2)</code> and read the diagnostic slowly. It is a syntax message. Now write down what would have to be true of the hardware for that message to be <em>about syntax</em>, and notice that nothing would. Then try <code>amoadd.b</code> and notice the opposite: a diagnostic that tells you the extension you are missing.)</em></li>
                    <li><strong>Write the loop by hand and see what the compiler will not do.</strong> <em>(Put a <code>__atomic_compare_exchange_n</code> in a file, compile it at <code>-march=rv64ima</code> and at <code>-march=rv64im</code>, and diff the two disassemblies. One is four instructions and a branch. The other is a call into a library. Ask what the compiler would have to be able to do to emit a compare-and-swap here &mdash; and then check whether RISC-V has such an instruction.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>What a race is and what &ldquo;atomic&rdquo; has to mean for one is in the <a href="/courses/smp/lessons/smp-atomic">neutral course on SMP</a>, and the ordering half is <a href="/courses/smp/lessons/smp-ordering">smp-ordering</a> &mdash; neither of which is re-taught here. The same subject on the two machines this collection can actually run is <a href="/courses/x86simd/lessons/x86-atomics">x86-atomics</a>, where the prefix is the mechanism and forgetting it is silent, and <a href="/courses/a64simd/lessons/a64-atomic">a64-atomic</a>, where acquire and release are <em>access modes</em> rather than two bits. The section&rsquo;s spine &mdash; why there are no condition codes at all &mdash; is <a href="/courses/rvabi/lessons/rv-noflags">rv-noflags</a>, and it is the reason the <code>sc</code> result had to go into a register: on an architecture with no flags, the only place a result can land is a register somebody has to check.</p>
                <p>Next: <a href="/courses/rvat/lessons/rv-fence">fence, and an Ordering Model Defined in Terms of It</a> &mdash; because the two bits you have just measured are, in the manual's own words, a fence with the unnecessary part removed, and the next page measures the other side of that sentence.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvat">RISC-V Atomics and the Vector Extension</a></span>
                <span>Next: <a href="/courses/rvat/lessons/rv-fence">fence, and an Ordering Model Defined in Terms of It</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
