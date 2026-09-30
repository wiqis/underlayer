// RISC-V: The Encoding Spectrum -- course landing page.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rvasm_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("RISC-V: The Encoding Spectrum — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvasm-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>RISC-V: The Encoding Spectrum</h1>
            <div class="lesson-meta">5 concepts &middot; 2 modules &middot; 127 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
                <p>Two of the three architectures in this collection have a <strong>constant</strong> instruction length. x86-64 does not &mdash; and that is the subject of <a href="/courses/isa/lessons/isa-length">isa-length</a> and <a href="/courses/isa/lessons/isa-modrm">isa-modrm</a>, which is why an x86 decoder's central problem is <em>how long is the next instruction</em>. AArch64 solved that by making every instruction exactly four bytes, and the consequence of that decision is the whole of <a href="/courses/a64asm/lessons/a64-encoding">a64-encoding</a>: with the length settled, the field map <em>is</em> the curriculum.</p>
                <p>RISC-V is the third case and nobody makes it the third case. <strong>The length is two bytes or four, and the two bits that say which are the two bits that say &ldquo;this is a 32-bit instruction&rdquo;.</strong> That sounds like a small fact. It is not, and here is the consequence stated as a single rule:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py 952e 0d85f2d7
0x0000952e  2 bytes  c.add        a0, a1
0x0d85f2d7  4 bytes  vsetvli    t0, a1, e64, m1, ta, ma
                </pre>
                </div>
                <p>Those are the two words the section plan measured while scoping, and they are the whole argument. <strong>A two-byte word that does an integer addition, and a four-byte word that configures a vector unit.</strong> Read them side by side and &ldquo;RISC-V is smaller&rdquo; stops being a claim about an instruction set and becomes a claim about which instructions a <em>compiler</em> was allowed to shorten &mdash; and the compiler is a separate program with separate decisions.</p>
                <p>But the rule has a second half, and it is the half that matters. The rule needs <strong>two bits of the current position and nothing else</strong>. So a decoder with no model at all for an instruction still steps over it correctly, and the chain cannot desynchronise even when it is completely lost. That is a guarantee the length rule <em>buys</em>, and it is a guarantee you have to check rather than assume:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/THE LENGTH RULE, applied/,/^$/p'
  object                  section   bytes    walked    insns    end
  rv.o                    .text     284      284       99       EXACT
  corpus_rv64i.o          .text     584      584       146      EXACT
  corpus_rv64im.o         .text     456      456       114      EXACT
  corpus_rv64if.o         .text     584      584       146      EXACT
  corpus_rv64imf.o        .text     456      456       114      EXACT
  corpus_rv64imafd.o      .text     380      380       95       EXACT
  corpus_rv64imafdc.o     .text     246      246       95       EXACT
  corpus_rv64gc.o         .text     246      246       95       EXACT
  corpus_rv64gcv.o        .text     524      524       178      EXACT

    9 code sections, 1082 instructions, and EVERY WALK ENDS EXACTLY ON ITS
    SECTION END
                </pre>
                </div>
                <p>That is a <strong>MEASURED</strong> result, not a definition, and the difference is the difference the whole course keeps coming back to. A definition does not need checking. This one was checked against nine real sections that <code>clang</code> emitted, and the checking found nothing &mdash; which is a result, and a result that could have come out otherwise. <a href="/courses/rvasm/lessons/rv-encoding">Concept 2</a> is where that guarantee is poisoned to prove it is load-bearing.</p>
                <p>What the collection <strong>does not</strong> teach anywhere, and what this course owes: the modular-ISA measurement (<a href="/courses/rvasm/lessons/rv-isa">concept 1</a>), the compressed extension's honest cost (<a href="/courses/rvasm/lessons/rv-compressed">concept 3</a>), the immediates that do not fit (<a href="/courses/rvasm/lessons/rv-immediate">concept 4</a>), and the decoder that reads the bytes (<a href="/courses/rvasm/lessons/rv-verify">concept 5</a>). &ldquo;Instruction encoding&rdquo; as a <em>principle</em> belongs to <a href="/courses/isa">the ISA course</a> and this course does not re-teach it. What is here is the exhaustive RISC-V reference, and where the three architectures differ <strong>in kind</strong> rather than in detail, that difference is the concept.</p>
            </div>

            <div class="unit unit-model">
                <h2>What the toolchain can and cannot do here</h2>
                <p>Read this before the first number, because it bounds every number that follows.</p>
                <div class="hex-dump">
                <pre>$ ./build_samples.sh --only | head -14
== 1. the toolchain, printed because a claim about a decoder needs one ==
  assembler:    clang version 21.1.8
  disassembler: Debian LLVM version 21.1.8
  linker:       riscv64-linux-gnu-ld IS NOT INSTALLED
  emulator:     qemu-riscv64 ABSENT
  emulator:     spike ABSENT

  NOTHING IN THIS COURSE IS EVER EXECUTED.  Every figure is a bit
  pattern, a count of bit patterns, an arithmetic identity, or a refusal
  from a real assembler.  The x86-64 section's speedup ratios have NO
  counterpart here and are not invented to fill the gap.
                </pre>
                </div>
                <p><strong>There are no timings in this course.</strong> Not one instruction has been run. Every claim is one of three kinds and every page labels which:</p>
                <ul>
                    <li><strong>MEASURED</strong> &mdash; about the compiler or the bytes, by experiment. Compile the same C at eight <code>-march</code> settings and diff what appears.</li>
                    <li><strong>MEASURED-ON-BYTES</strong> &mdash; a property of emitted bytes, cross-checked against <code>llvm-objdump-21</code> as a second reader. Two readers always: a check that reads the same bytes the same way agrees with a wrong answer.</li>
                    <li><strong>QUOTED</strong> &mdash; a manual claim, with a document and a section.</li>
                </ul>
                <p>And the second reader is not as independent as it looks, which the artifact says in its own words rather than implying otherwise: <code>clang</code> assembled the corpus and <code>llvm-objdump-21</code> disassembled it, so <strong>both readers ultimately depend on one LLVM tree</strong>. An independent second <em>assembler</em> does not exist on this host &mdash; GNU binutils has no RISC-V target installed. What concept 5 establishes is that this decoder and one other piece of software agree on what the bytes mean. Not that either agrees with silicon, and there is no silicon here to agree with.</p>
            </div>

            <div class="unit unit-example">
                <h2>The three results that were not the ones expected</h2>
                <p>First: <strong>M is not additive.</strong> The plan said &ldquo;what did this letter ADD&rdquo; and expected multiply. The same eleven functions, <code>rv64i</code> to <code>rv64im</code>:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --run | sed -n '/rv64i      -> rv64im/,/^$/p'
    rv64i      -> rv64im      insns  146 ->  114   bytes   584 ->   456
        GAINED  3:  divuw(1)  mul(2)  rem(1)
        LOST    4:  j(1)  jr(1)  sext.w(2)  srli(2)
                </pre>
                </div>
                <p>An extension that adds three instructions and <strong>removes four</strong>. The base has no multiply, so the compiler synthesises one out of shifts and adds, and a shift-based multiply is a <em>sequence</em>, and sequences branch. Adding M removed branches. &ldquo;An extension adds instructions&rdquo; is true of the ISA and false of the object, and the object is what a linker sees.</p>
                <p>Second: <strong>the compressed extension reserves 4.90 per cent of the reachable space, not a quarter.</strong> The plan said &ldquo;a large fraction&rdquo; and the artifact's own first draft said the assembler refuses 16,384 of 65,536 half-words, which is exactly a quarter and exactly <code>bits[1:0] == 0b11</code> &mdash; a fact about the <em>length rule</em>, not about the C extension. Of the 49,152 that are reachable, 2,409 are reserved:</p>
                <div class="hex-dump">
                <pre>$ python3 rvdec.py --space | sed -n '/2409 reserved/,/^$/p'
  2409 reserved code points out of 49,152, which is 4.90 per cent of the
  reachable compressed space.
                </pre>
                </div>
                <p>Third, and this one is the course's sharpest: <strong>the base ISA keeps all three register fields in the same bit position in every format</strong>, which is the exact opposite of what the plan predicted, and the manual says so and says what pays for it:</p>
                <div class="hex-dump">
                <pre>  "The RISC-V ISA keeps the source (rs1 and rs2) and destination (rd)
   registers at the same position in all formats to simplify decoding."

  and in the note: "the instruction format was chosen to keep all register
  specifiers at the same position in all formats at the expense of having to
  move immediate bits across formats."
                </pre>
                </div>
                <p>The immediates are where the variation went, and that is what <a href="/courses/rvasm/lessons/rv-immediate">concept 4</a> is about. The variation that is <em>not</em> in the base is the compressed extension's, and it is a <strong>second, three-bit register encoding</strong> whose value 0 means x8 &mdash; <a href="/courses/rvasm/lessons/rv-compressed">concept 3</a>.</p>
            </div>

            <div class="unit unit-reality">
                <h2>What this course cannot tell you</h2>
                <p>Printed here rather than footnoted, because a limit that is a footnote is a limit that gets forgotten, and because a course with no machine has an unusual number of them and they are the subject rather than an embarrassment.</p>
                <ul>
                    <li><strong>Nothing is executed, so nothing is timed.</strong> No speedup, no latency, no throughput, no instruction density in the performance sense. Where a page would carry a ratio it carries a byte count, an instruction count, or a refusal, and says which. The <code>ecall</code> convention is measured as the compiler <em>emits</em> it &mdash; the constant <code>0x00000073</code>, 31 of 32 bits a fixed pattern &mdash; which is weaker and is labelled weaker.</li>
                    <li><strong>The corpus is eleven functions of ordinary C.</strong> Every distribution is a distribution of what <code>clang</code> chose for <em>that</em> code at <em>that</em> version. A corpus with switch tables, atomics in the source, or a hand-written kernel would fill opcode values that are empty here. <strong>Nothing here is generalisable from the empty rows.</strong> What <em>is</em> generalisable is everything about the encoding, because the encoding is not a property of the corpus.</li>
                    <li><strong>The field map is measured from one assembler.</strong> A field map is a property of the encoding, and a different assembler choosing a different encoding for the same text would not be a different encoding &mdash; and it would not show up here. What the measurement establishes is that the guards are <em>consistent with the words a real assembler emits</em>, which is a different and weaker claim than correctness.</li>
                    <li><strong>A mask is a LOWER BOUND.</strong> Every field measurement is what a sweep <em>moved</em>, which is a subset of the field. Section 4B of the artifact is the case where the gap is large &mdash; two bits of a seven-bit <code>funct7</code> &mdash; and the two numbers are printed in the same place so they cannot be confused.</li>
                    <li><strong>No safety claim about any reserved encoding.</strong> What a given implementation <em>does</em> with a reserved encoding is a property of that implementation, and there is no RISC-V hardware on this host to ask.</li>
                </ul>
            </div>

            <div class="unit unit-apply">
                <h2>What you will be able to do afterwards</h2>
                <ol>
                    <li><strong>Read a RISC-V disassembly and find the length first.</strong> Two bits, and every word in a <code>.text</code> can be stepped over without knowing what any of them does. You will be able to say why a decoder cannot desynchronise on this architecture and why that argument does <em>not</em> work for x86-64.</li>
                    <li><strong>Reconstruct all five immediates from the bits</strong> and say which of them are contiguous, which are split, and which are permuted &mdash; and know which ends of the B-type's range are 4,094 and which are 4,096 and why they differ.</li>
                    <li><strong>Tell a field map from a permutation.</strong> The compressed extension's eleven displacement families share five bit positions and are assigned seven different orders, and a table of bit positions &mdash; which is what a field map <em>is</em> &mdash; cannot tell you that.</li>
                    <li><strong>Build a two-reader cross-check that can fail.</strong> Including the part almost nobody does: 47 normalisation rules, every one of which has to have fired, and four poisons that each have to move the number they claim to test.</li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Where the seams are</h2>
                <p>The <a href="/courses/elf">ELF course</a> taught the container; this course reads the bytes inside the <code>.text</code> section it taught you to find. <a href="/courses/isa/lessons/isa-length">isa-length</a> is the contrast case for everything in concept 2 &mdash; a variable-length encoding where the length <em>is</em> the problem, against a rule where the length is a two-bit lookup and the problem is everything else.</p>
                <p>Forward within the course, concept 3 is where the coupling between the three-bit compressed register field and the ABI&rsquo;s choice of x8&ndash;x15 as the most-used registers is introduced &mdash; a coupling between an encoding, a register file and a calling convention that no single specification reveals. Beyond that, the section plan has three more RISC-V courses (<code>rvabi</code>, <code>rvpriv</code>, <code>rvat</code>) that this course does not preempt: the calling convention, the privileged architecture and the atomics and vector extensions.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/rvasm/lessons/rv-isa">A Set of Documents, Not a List</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
