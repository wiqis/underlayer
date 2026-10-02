// AArch64: Encoding From The Ground Up -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64asm_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("AArch64: Encoding From The Ground Up — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson a64asm-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>AArch64: Encoding From The Ground Up</h1>
            <div class="lesson-meta">5 concepts &middot; 2 modules &middot; 127 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>The <a href="/courses/elf">ELF course</a> taught you that a file is a table of sections and that a section is a run of bytes with a name. It taught you the container. It did not teach you what is <em>in</em> one of those runs, and neither did anything else in this collection: <a href="/courses/isa/lessons/isa-decode">the ISA course</a> taught how to read a variable-length x86 encoding one byte at a time, and its decoder's central problem &mdash; how long is the next instruction &mdash; is a problem AArch64 does not have.</p>
                <p>So this course starts from the other end. An AArch64 instruction is exactly four bytes, always, which means a decoder that does not know what a word <em>does</em> still knows how long it is. That single property is the whole difference from x86 in one sentence, and every other thing in this course is downstream of it: there are no prefixes to discover, no length arithmetic to get wrong, no integer that can overflow, and no way to desynchronise. What is left is <strong>the field map</strong>, and on this architecture the field map <em>is</em> the curriculum.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --elf corpus_O2.o | head -4
  .text    va=0x0        588 bytes -&gt;  147 instructions, chain closed EXACTLY

  868 instructions over 5 code sections.  Every section is a
  multiple of four, every walk ends exactly on the section end, and
  bytes/insn is 4.0000 in every row including the hand-written one.
  VERDICT: fixed width, on this corpus
                </pre>
                </div>
                <p>That is a <strong>measurement</strong>, not a definition, and the difference is worth one sentence: the artifact decoded 868 real instructions out of five object files that <code>clang</code> emitted, and every section walked to exactly its own end. A definition does not need checking. This one was checked, and the checking is the last concept.</p>
                <p>What the collection <strong>does not</strong> teach, anywhere, and what this course exists to supply: the measured field map (58 positions, <a href="/courses/a64asm/lessons/a64-encoding">concept 2</a>), the immediate story (<a href="/courses/a64asm/lessons/a64-immediate">concept 3</a>), and the conditional-select inversion (<a href="/courses/a64asm/lessons/a64-cond">concept 4</a>) &mdash; each of which is a place where the first draft of this course asserted something false and the measurement said so.</p>
            </div>

            <div class="unit unit-model">
                <h2>The two results that were not the ones expected</h2>
                <p>First: the class field is four bits wide, and a two-bit rule cannot see the class that holds <code>ret</code>.</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --run | sed -n '/bits    n  /,/Empty here/p'
  bits    n      what landed there, and how often        the QUOTED name
  00100   23     ldp:15 stp:8                            Loads and Stores (pair)
  00101   111    add:40 mov:34 subs:6 cmp:5 neg:4        Data Processing -- Register
  01100   151    ldr:83 str:59 ldur:2 ldrb:2 ldrsw:2     Loads and Stores
  01101   101    csel:22 cset:14 mul:10 madd:10 lsl:5   Data Processing -- Register
  01011   142    ret:134 tbz:4 br:1 blr:1 tbnz:1         Branches, Exception Gen and Sys

  11 of the 16 values carry at least one real instruction in this
  corpus.  Empty here: 00000, 00001, 00010, 00011, 01110.
                </pre>
                </div>
                <p><strong>01101 holds <code>ret</code>'s class, and 01011 is where <code>ret</code> actually is.</strong> The two-bit rule this decoder first used put it in &ldquo;Data Processing &mdash; Register&rdquo;, because bits[28:26] of <code>0xd65f03c0</code> is <code>0b110</code>. That is 134 of 868 instructions &mdash; the single largest entry in the whole distribution &mdash; in the wrong bucket, and the bucket is not cosmetic: 01101 and 00101 are different code paths through a decoder with different guards and different operand layouts. <strong>Four bits, not two. Eleven of sixteen, not four of four.</strong></p>
                <p>Second: the class field is not the only field, and the other one is worse. <code>cset w0, eq</code> is <code>csinc w0, wzr, wzr, NE</code> &mdash; the condition is <strong>inverted</strong>, and the two are different 32 bits that differ in the condition field and nowhere else:</p>
                <div class="hex-dump">
                <pre>$ ./a64dec.py --run | sed -n '/cset w0, eq  /,/csinc w0, wzr, wzr, al/p'
    cset w0, eq              1a9f17e0   csinc w0, wzr, wzr, ne   1a9f17e0   SAME
    cset w0, ne              1a9f07e0   csinc w0, wzr, wzr, eq   1a9f07e0   SAME
    csinc w0, wzr, wzr, ne   1a9f17e0   cset w0, eq              1a9f17e0   SAME
    csinc w0, wzr, wzr, al   1a9fe7e0   cset w0, eq              1a9f17e0   DIFFERENT
                </pre>
                </div>
                <p>Read the last row. The assembly text of <code>csinc w0, wzr, wzr, al</code> is <code>cset w0, ne</code> &mdash; a <em>different</em> instruction with a different word. <strong>A decoder that models <code>cset</code> as &ldquo;a CSEL with Rn = Rm = 31&rdquo; reports every condition in the program inverted, and the output is 0 or 1 either way, so nothing about it looks wrong.</strong> That is the shape of the worst decoder bug in this course and it is why <a href="/courses/a64asm/lessons/a64-verify">the last concept</a> exists.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Three things that are cheaper to state than to prove</h2>
                <p>This course has the habit the four before it established, and it is worth showing before the first concept rather than after the last one.</p>
                <ul>
                    <li><strong>A 12-bit logical immediate does not reach every 12-bit value &mdash; it reaches more of them than any other 12-bit field in the architecture.</strong> 1,302 of 4,294,967,296 32-bit constants are encodable. The all-ones and the all-zeros are among the 4.29 billion that are <em>not</em>, and those two are exactly the ones a compiler wants most. <code>and w0, w0, #0xffffffff</code> is <strong>refused by the assembler</strong>, and the 64-bit all-ones is refused too, which reverses the first draft of this page.</li>
                    <li><strong>The cheapest 64-bit constant is the one with no variety in it.</strong> <code>mov x0, #-1</code> is one instruction, because MOVN writes the complement. An arbitrary 64-bit literal costs four. &ldquo;Big number&rdquo; is not the axis; <em>pattern</em> is.</li>
                    <li><strong>AArch64 loses on code density at two optimisation levels and wins at two.</strong> Same C, same compiler, both targets: the ratio is 1.152 at -O0, 0.813 at -O1, 0.797 at -O2, 1.292 at -Os. A ratio that changes sign with the flag was never a property of the architecture, and the claim this course was written to make was retracted rather than softened.</li>
                </ul>
                <p>Each of those was asserted in a draft of this course. Each was measured. Each was retracted in public, and <code>crosscheck.py</code> asserts the <strong>presence of all seventeen retractions as text</strong>, so a later edit cannot quietly delete one.</p>
            </div>

            <div class="unit unit-example">
                <h2>What is deferred, and what this artifact will not claim</h2>
                <p>Printed in the artifact's own limits block (section 15) rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. The first two rows are the ones that shape the whole course:</p>
                <ul>
                    <li><strong>Nothing is executed. There is no AArch64 machine on the build host and no emulator.</strong> Not one instruction in this course has been run. Every number is a bit pattern, a count of bit patterns, an arithmetic identity, or a <em>refusal from a real assembler</em>. Nothing here is a claim about speed, latency, throughput, or what a program does &mdash; and this is not a limitation worked around, it is the design: those four kinds of claim do not go stale when a compiler changes and a reader can check every one of them with a hex editor.</li>
                    <li><strong>The decoder is a subset, and says so.</strong> Advanced SIMD is not modelled. Its words are <em>counted</em> in the length arithmetic and printed as <code>(op 0x&hellip;)</code> rather than named. That is the whole difference from the ISA course's decoder: there, the declared subset is a subset of <em>lengths</em> and a wrong guess desynchronises the stream. Here the subset is a subset of <em>names</em>, and an unnamed word still contributes exactly four bytes.</li>
                    <li><strong>The two readers share a source.</strong> <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it, so the cross-check establishes that this decoder and one other piece of software agree &mdash; not that either agrees with silicon. An independent second assembler does not exist on this host and GNU binutils has no AArch64 target installed.</li>
                    <li><strong>No safety claim.</strong> The architecture defines an UNDEFINED encoding and this decoder raises on some of them. Which encodings are UNDEFINED and what a given core does with one is a property of the specification <em>and</em> of the implementation, and nothing on this host can tell you which core you have.</li>
                    <li><strong>The corpus is ordinary C, which is a choice.</strong> 25 functions of arithmetic, masks, conditionals, a loop, a struct walk and a call. The distribution in concept 2 is a distribution of what <code>clang</code> chose for <em>that</em> code. A corpus with SIMD, floating point or C++ would fill the five empty class values.</li>
                </ul>
                <p>The completion criterion is not &ldquo;read it&rdquo;. It is: <em>reproduce the 239 checks against the shipped <code>a64dec.out</code>, then change one guard in <code>a64dec.py</code> &mdash; any guard, one bit &mdash; and make the poisoned cross-check move by name.</em> A check that has never been seen to fail is a check with no reason to be believed, and the harness in this course has already failed eleven times for two different reasons.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
                <p>Before. <a href="/courses/elf/lessons/section-header-table">The ELF course's section-header concept</a> is where the artifact's own reader comes from: <code>a64dec.py</code> reads <code>e_shoff</code> at <code>0x28</code> and the section-header array with <code>struct.unpack_from</code> and no library, because a decoder that shells out to a disassembler is a disassembler with a hardcoded path in it. <a href="/courses/isa/lessons/isa-length">isa-length</a> is where the variable-length property is derived, and this course quotes the contrast: the x86 decoder's declared subset is a subset of lengths, this one's is a subset of names.</p>
                <p>Forward, and the practical weight is in a compiler backend. <strong>The field map and the immediate story are the two things a backend must get exactly right and the two things nobody thinks about</strong>, because both are invisible in the source: <code>mov w0, w1</code> and <code>orr w0, wzr, w1</code> are the same four bytes, and <code>and x0, x1, #0xffffffffffffffff</code> is not an instruction at all. A backend that emits the wrong one produces code that is correct on most inputs and silently wrong on the rest, and no test reliably finds it.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/a64asm/lessons/a64-asm">Four Bytes, and a Mnemonic That Is Not In There</a></span>
                <span>End of AArch64: Encoding From The Ground Up &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
