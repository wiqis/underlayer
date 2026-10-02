// RISC-V atomics -- concept 4: the data path, the compiler's output, two
// readers, four poisons, and the measured/quoted boundary.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_dataflow() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Decode the Data Path — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvat-concept">
            <a href="/courses/rvat" class="back-link">RISC-V Atomics and the Vector Extension</a>
            <h1>Decode the Data Path</h1>
            <div class="lesson-meta">22 min &middot; Concept 4 of 4 &middot; module: vector &middot; <a href="/courses/rvat">RISC-V Atomics and the Vector Extension</a></div>

            <div class="unit unit-why">
                <h2>One bit, in three instruction groups</h2>
                <p>A configuration instruction that sets a policy is not much use until you can see what the policy does. So: the mask. And the first result is that <strong>it is one bit at <code>inst[25]</code> in three different instruction groups</strong> &mdash; arithmetic, unit-stride load, unit-stride store &mdash; with every pair XORed and every result printed.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE ELEVEN XORs/,+16p'
  instruction  the masked form    XOR         bits  which
  vadd.vv      v1, v2, v3, v0.t   0x02000000  1     bit 25
  vadd.vi      v1, v2, 0x7, v0.t  0x02000000  1     bit 25
  vadd.vx      v1, v2, a0, v0.t   0x02000000  1     bit 25
  vle8.v       v1, (a0), v0.t     0x02000000  1     bit 25
  vle16.v      v1, (a0), v0.t     0x02000000  1     bit 25
  ... through vse64.v ...

  11 pairs, 11 of them XOR to exactly 0x02000000, 0 exceptions.
                </pre>
                </div>
                <p>Eleven pairs, one value, <strong>zero exceptions</strong>. That is what makes <code>vm</code> a field of the <em>word</em> rather than of one instruction class &mdash; the word is the only thing those three groups share. And the count is eleven and not twenty-two, which is worth a sentence because the first draft of this section claimed twenty-two: it had counted three arithmetic forms at <em>two</em> widths when the corpus has one width per form. <strong>A count that cannot come out the same twice is a count of something else, and the cheapest test is to print the table and count the rows.</strong></p>
                <p>And bit 25 is <strong>&ldquo;release&rdquo; in an atomic and &ldquo;mask agnostic&rdquo; in a vector word</strong>. The two meanings are in different opcodes so they never collide &mdash; and that is a finding about bit positions in general: a bit position is a property of an instruction group, not of an architecture. The AArch64 course reached the same thing from the other direction, where bit 23 is &ldquo;128-bit atomic&rdquo; in one group and &ldquo;acquire&rdquo; in another, and it cost that course a retraction.</p>
            </div>

            <div class="unit unit-model">
                <h2>The mask register is not in the encoding</h2>
                <p><code>vm</code> is a single bit that says &ldquo;use v0&rdquo;, and <strong>v0 is the only mask register the encoding can name</strong>. There is no field for it. The assembler states that property in its own diagnostic, which is a better measurement than a claim:</p>
                <div class="hex-dump">
                <pre>    vadd.vv v1, v2, v3, v0.t         ACCEPTED, 0x002180d7
    vadd.vv v1, v2, v3, v1.t         REFUSED: operand must be v0.t
    vle32.v v1, (a0), v0.t           ACCEPTED, 0x00056087
    vle32.v v1, (a0), v1.t           REFUSED: operand must be v0.t
                </pre>
                </div>
                <p>A diagnostic that states a property of the <em>hardware</em> rather than a rule about spelling, and that cannot be misread as the latter. It is also why a decoder can name twice as many vector instructions as it has operands to print: the space of (instruction, mask register) <em>pairs</em> is not in the word.</p>
                <div class="callout callout-note">
                    <p><strong>And here is the part that is easy to get wrong in the other direction, so it is measured rather than asserted.</strong> A mask <em>producer</em> may write any vector register &mdash; <code>vmsne.vi v1, v2, 0</code> assembles &mdash; and the only one of those that can then be <em>used</em> as a mask is v0. <strong>So the constraint is not &ldquo;masks are v0&rdquo; but &ldquo;masks are v0 and masks are produced by ordinary vector registers&rdquo;</strong>, which is a weaker claim and the correct one. The consequence is for a register allocator: keep v0 out of the general pool &mdash; not because writing it is illegal, but because anything it writes will eventually be used as a mask. <strong>That is a constraint on the allocator and not on the instruction.</strong></p>
                </div>
                <p>The first draft of this section inferred from &ldquo;v0 is the only mask register the encoding can name&rdquo; that an allocator could not treat a mask as a distinct kind of thing. The first half is right and the inference is wrong, and <strong>a true premise with a false inference is harder to catch than a false premise, because the false half is the second half.</strong></p>
                <h3>And the register group is an alignment constraint</h3>
                <p>The other half of what <code>vsetvli</code> buys is the group count: three bits at the top, <code>nf</code>, holding the number of registers minus one. <strong>A group of four is not a wider register &mdash; it is four registers the instruction addresses together</strong>, and the assembler proves it by refusing a group that does not start aligned:</p>
                <div class="hex-dump">
                <pre>    vl2r.v v1, (a0)          REFUSED
    vl2r.v v8, (a0)          ACCEPTED
    vl4r.v v8, (a0)          ACCEPTED
    vs2r.v v1, (a0)          REFUSED
    vs2r.v v8, (a0)          ACCEPTED
                </pre>
                </div>
                <p>So <strong>LMUL is not a scalar and it is not a wider register; it is an alignment constraint on a register allocator, and the encoder enforces it by refusing a word.</strong> A scalar enables loop unrolling with no alignment constraint, so the three-bit <code>nf</code> field is the price of not having a lower bound on what a vector register is. The first draft here called the group a scalar and treated the refusal as a spelling rule; <strong>a refusal is the cheapest proof that a constraint is real, and it is also the proof that the constraint is not about syntax.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>What the compiler emits, and the finding about -Os</h2>
                <p>Here is where a reader who has just come from <a href="/courses/simd/lessons/simd-compiler">the neutral SIMD course</a> will be most disoriented, so the disorientation is named first. <strong>This course has no timing of any kind</strong>, and what replaces a ratio is a count &mdash; which is a weaker thing in a specific way worth stating rather than apologising for: <strong>an instruction count does not know whether the instruction is fast.</strong> It knows what the compiler did, which is a fact, and not what the hardware did with it, which was the other half.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/THE LOOP COUNTS/,+7p'
  function  -O0 no v  -O1 no v  -O2 no v  -O3 no v  -Os no v  -O0 +v  -O1 +v  -O2 +v  -O3 +v  -Os +v
  vadd_d    36        12        12        12        12        37      12      53 +4v  53 +4v  12
  vmac_l    37        13        13        13        13        38      13      47 +7v  47 +7v  29 +12v
  vmul_s8   35        11        11        11        11        36      11      51 +4v  51 +4v  11
  vsum_d    35        13        13        13        12        36      13      40 +4v  40 +4v  29 +9v
                </pre>
                </div>
                <p>Three results, and the first one corrected a claim this course started with.</p>
                <ul>
                    <li><strong>-O1 does not vectorise this corpus at all. -Os vectorises two of the four functions. -O2 and -O3 vectorise all four.</strong> The level of -O names an optimisation goal and not a capability, and the vectoriser is the most capability-sensitive pass in the compiler.</li>
                    <li><strong>-O2 and -O3 produce byte-identical assembly here.</strong> Measured, not expected, and worth saying what follows from it: there is nothing to compare between them on this corpus, and <strong>a reader who reports a difference between -O2 and -O3 has found a different corpus.</strong></li>
                    <li><strong>-Os is smaller than -O2 in code size while emitting MORE vector instructions</strong> &mdash; 191 instructions against 81, and 21 vector instructions against 19. Both are true at once because the vector body replaces a loop, and the size goal and the vectorisation goal disagree in opposite directions on the same four functions.</li>
                </ul>
                <p>That third one is the kind of thing a first draft gets wrong by borrowing a number from a nearby table. <strong>&ldquo;Smaller&rdquo; and &ldquo;fewer vector instructions&rdquo; are two different claims</strong>, and the first version of this paragraph let the second stand in for the first. It is now retraction R-something in the artifact and limit 14 in the harness, and the sentence that carries it is <em>code size is a different number from vector count</em>.</p>
                <h3>The tail, which is where a runtime length becomes code</h3>
                <p>And the scalar prologue is not dead weight &mdash; <strong>it is the remainder</strong>, the loop the vector loop cannot run. The vector loop is straight-line with no branch inside it and no tail check, because the compiler has already computed the trip count as a multiple of the elements per vector:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/AND THE TAIL, which is where/,+9p'
    -O2     vadd_d   53 instr: 47 scalar, 1 vsetvli, 4 vector data
    -O2     vmac_l   47 instr: 37 scalar, 1 vsetvli, 7 vector data
    -O2     vmul_s8  51 instr: 45 scalar, 1 vsetvli, 4 vector data
    -O2     vsum_d   40 instr: 32 scalar, 2 vsetvli, 4 vector data
                </pre>
                </div>
                <p>So the scalar count is not zero even when there are vector instructions, and <strong>that is the tail-handling code</strong> &mdash; beside the vector loop rather than inside it. Which is the answer to the portability question on the previous page, and it is not an answer to it: the tail is handled by arithmetic on the trip count and a scalar loop, which works on <em>every</em> implementation regardless of whether <code>ta</code> or <code>tu</code> was requested. <strong>The compiler gets portability not from the policy bits but from not depending on the tail, and a reader who sees <code>ta, ma</code> in the encoding has learned nothing about which of the two strategies was used.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Two readers, and the count that is not a subset</h2>
                <p>The decoder that produced every number on the previous three pages is checked by a second reader &mdash; <code>llvm-objdump-21</code> &mdash; over the whole corpus. Three numbers matter, and the third is the one that is easy to forget.</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/instructions the second reader printed/,/DISAGREE/p'
    2197  instructions the second reader printed
    2147  of them this file NAMES
      50  unmodelled -- counted, never dropped
       0  where the two readers disagree on the LENGTH

       0  DISAGREE
                </pre>
                </div>
                <p>Zero disagreements, and <strong>fifty words the decoder declines to name, counted rather than dropped</strong>. That third line is the one that matters, and a sibling course in this collection shipped a cross-check that reported zero disagreements over a corpus where eighty-five instructions genuinely disagreed &mdash; because the bug had made the comparison <em>vacuous</em> rather than wrong. Not one of those bugs printed a bad word; they all stopped the comparison happening. <strong>A cross-check that counts agreements and one that counts holes are measuring different things, and printing only one of them is how a decoder loses a model without anybody noticing.</strong></p>
                <p>Fifty is an honest number <em>for this corpus</em>. The vector extension has several hundred encodings and this file names the three configuration instructions, the mask bit in three groups and the register group, then counts the rest. <strong>A decoder that named every vector word and got one wrong would be a worse decoder than one that says which half of the extension it implements</strong> &mdash; and the half it implements is the half these four pages make claims about.</p>
                <h3>Four poisons, and why each one moves a different column</h3>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/FOUR POISONS, FOUR CLAIMED/,+11p'
  FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS:

  * poison 1 claims the NAMED and the UNMODELLED counts, and moved them
              by -47 and +47 -- and it claims the DISAGREEMENT count
              stays at +0, which is a claim as load-bearing as either
              of the two that moved
  * poison 2 claims the DISAGREEMENT count, and moved it by +72 while
              claiming the UNMODELLED count stays at +0
  * poison 3 claims the ORDERING-BIT POSITIONS, and moved 28 of 28 with
              0 unmoved
  * poison 4 claims the VISIBILITY of the check, and hid 1448 of 1933
                </pre>
                </div>
                <p>Read poisons 1 and 2 together, because they are the pairing that makes the other two meaningful. Poison 1 removes a model and the <strong>unmodelled</strong> count rises while the <strong>disagreement</strong> count does not move &mdash; a missing model makes a <em>hole</em>. Poison 2 removes a different model and the disagreement count rises while the unmodelled count does not move &mdash; a superseded model makes a <em>mistake</em>. A cross-check that counts only agreements calls <strong>both</strong> of them a pass, because in both cases the instruction is still &ldquo;compared&rdquo; and the comparison found nothing to say.</p>
                <p>And poison 4 is the one that makes the other three meaningful. The check is planted with 1,933 real disagreements and asked how many it catches: the working check catches all 1,933, and a deliberately broken normaliser &mdash; one that keeps the mnemonic and the first operand and deletes the rest &mdash; <strong>hides 1,448 of them</strong>. That is the number a reader should care about, because 1,448 is the class of bug that reads as success. <strong>A cross-check that agrees is not proof, and this is the reason: the only way to know whether a cross-check can fail is to make it fail on purpose.</strong></p>

                <h2>The boundary: 58 claims, and eighteen of them were retractions</h2>
                <p>And the last mechanical question is the same one every course in this section ends with, and it is the reason the four pages above are checkable at all: <strong>where does the claim stop?</strong> This is that page, and it is a table and a count rather than a paragraph.</p>
                <p>Every claim in the course carries one of three labels &mdash; <strong>MEASURED</strong> (about the compiler or the bytes, by experiment), <strong>MEASURED-ON-BYTES</strong> (a property of emitted bytes, cross-checked against the second reader), or <strong>QUOTED</strong> (a manual claim, with a document and a section) &mdash; and on most pages you would be forgiven for not noticing. The count is the finding:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep 'rows:'
  58 rows: 20 MEASURED, 18 MEASURED-ON-BYTES, 20 QUOTED.
                </pre>
                </div>
                <p>This is the course in the whole RISC-V section with the <strong>smallest quoted third</strong>, and the reason is structural rather than a matter of care. <a href="/courses/rvpriv/lessons/rv-boundary">The privileged course</a> is 52 per cent quoted because its subject is a document; this one&rsquo;s subject is an encoding and a compiler&rsquo;s choice, and there was simply more to measure &mdash; the AMO encodings, the two ordering bits as an XOR, thirteen XOR probes that decompose the vector type field, eleven mask XORs, fifteen fence spellings, the <code>-march</code> experiment and twenty objects of compiler output. <strong>What an encoding is and what a compiler chose are exactly what a host without hardware can measure.</strong> The comparison is printed both ways in the artifact, because the honest number is the unflattering one.</p>
                <h3>Nineteen limits, and the two that decide the other seventeen</h3>
                <p>The limits are printed in the artifact&rsquo;s own words so that a reader who copies a number out of the file cannot lose the sentence that limits it. The first three decide what every other one may say:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | sed -n '/^  1\. NO TIMING/,/^  4\./p'
  1. NO TIMING. No cycle, no latency, no throughput, no speedup, no ratio
     of anything a machine did. There is no RISC-V machine, no emulator and
     no RISC-V linker on this host, so every figure is a bit pattern, a
     count of bit patterns, an arithmetic identity, or a refusal from a
     real assembler. The `simd` and `smp` courses measured speedups on
     hardware, `x86simd` measured a lost-update count, and `a64simd`
     measured 3.89x, 4.92x and 27.65x; those have NO COUNTERPART HERE AND
     ARE NOT INVENTED TO FILL THE GAP.
  2. NOTHING IS EXECUTED. Not one instruction in this course has run. A
     compare-exchange in section 5 has never exchanged; it is four words a
     compiler emitted and a disassembly that named them.
  3. NO RESERVATION IS EVER HELD, NO STORE-CONDITIONAL IS EVER OBSERVED TO
     SUCCEED OR TO FAIL, NO AMO IS EVER OBSERVED TO BE ATOMIC, NO FENCE IS
     EVER OBSERVED TO ORDER ANYTHING AND NO VECTOR INSTRUCTION IS EVER
     EXECUTED. Five separate absences, and each one is a separate thing
     this course would otherwise be able to say.
                </pre>
                </div>
                <p>And beside the limits there are <strong>nine things a reader therefore cannot conclude</strong> and <strong>eleven they can</strong>, printed side by side rather than one in a footnote. The second list being the longer one is the point: there is more that can be read off bytes than there is that can be said about behaviour, and a reader who finishes this course able to state the second list precisely and the first list vaguely <strong>has it exactly backwards</strong>.</p>
                <div class="callout callout-key">
                    <p><strong>Every sentence in both lists is pinned whole, by the harness.</strong> That is not fussiness: a substring check passes over a bullet edited from &ldquo;That any atomic instruction is <strong>atomic</strong>&rdquo; to &ldquo;that any atomic instruction is <em>probably</em> atomic&rdquo;, because the sentence keeps its subject and its verb and the edit reverses the meaning without touching a word any check was written against. <strong>A scope list you can soften without editing a test is not a scope list.</strong> The intended cost is that a reworded claim has to be re-argued in the harness too, which is the price and not a bug.</p>
                </div>
                <h3>Eighteen retractions, and not one of them is about the hardware</h3>
                <p>Every one of the eighteen was asserted in a draft of this course or in the brief it was written from, measured, and withdrawn. They are printed in full rather than footnoted, and the harness asserts their <em>text</em> sentence by sentence &mdash; because that is the only mechanism that has ever stopped a retraction being quietly dropped. Four are worth naming because they change what a reader should expect:</p>
                <ul>
                    <li><strong>R5, the brief&rsquo;s headline claim.</strong> The course was written against a claim that the compiler emits <code>amoswap.w</code> in a loop instead of a hand-rolled compare-exchange. It does not, and the wrongness is instructive: the hand-rolled compare-exchange is not an alternative to be traded away, it is <strong>the only way to express compare-exchange</strong>, because there is no <code>cmpxchg</code> in the base A extension and <code>amoswap</code> is a different operation that does not compare. The compiler emits the one instruction for the one-instruction operation and the loop for the loop-requiring one, and there is no trade to make.</li>
                    <li><strong>R9, a claim that was true and incomplete.</strong> &ldquo;An acquire load and a seq_cst load are the same instruction&rdquo; is true. It is also <strong>the same instruction and the same fence plus another fence</strong>, and the first version of the table read the difference off the load alone. A claim that is true and has a qualifier hiding in the next column is a claim that has been half-written.</li>
                    <li><strong>R13, a good saying that was backwards.</strong> The first draft had <code>fence.tso</code> as a weaker barrier. The manual says the opposite direction: it is correct to ignore <code>fm</code> and implement <code>FENCE.TSO</code> as <code>FENCE RW,RW</code>. So the instruction is a request for a weaker barrier than the one it is spelled like, <em>and</em> an implementation may give the stronger one &mdash; which means &ldquo;emit a <code>fence.tso</code>&rdquo; is not portable advice and also not a weaker barrier.</li>
                    <li><strong>R18, and it is about the sibling.</strong> The lock-prefix count is zero, and the first draft justified the zero by saying the assembler refuses <code>lock</code>. That is a fact about the <em>assembler</em>. The claim needs to be about the architecture, and the measurement that carries it is the other count. <strong>&ldquo;Zero&rdquo; is an absence of features if you print it alone and a design decision if you print it beside the count it replaced.</strong></li>
                </ul>
                <p>And the sentence that ties the list together is the most interesting thing on the page:</p>
                <div class="hex-dump">
                <pre>$ python3 rvat.py --run | grep -A 2 'EIGHTEEN COURSES IN A ROW'
  EIGHTEEN COURSES IN A ROW, AND EVERY SINGLE RETRACTION IS A
  DISCOVERY ABOUT THE MACHINERY BUILT TO READ THE HARDWARE.
                </pre>
                </div>
                <p>The RISC-V atomics, fence and vector extension did not surprise this course once. What surprised it was a two-bit field two of whose four values are invalid on half the instructions that carry it, a decoder that computed three bits where the encoding has two, a bit that is &ldquo;release&rdquo; in one opcode and &ldquo;mask&rdquo; in another, a policy the specification declines to make deterministic, and a tail policy the compiler picks the fast way by default. <strong>Eighteen courses in a row, and not one of the retractions is a mistake about how a computer works.</strong></p>
                <h3>And the harness is a harness, not a rubric</h3>
                <p>A separate script corrupts the recorded report thirty-four ways &mdash; a bit pattern flipped, a field renamed, a claim de-negated, a retraction deleted, a nineteenth invented, a speedup ratio added, a retired link restored, and the whole file truncated to nothing &mdash; and asserts that <strong>every one is caught</strong>. That is the difference between a harness and a rubric, and it is the only part of the build that can fail while everything is green.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break a check and read the message.</strong> <em>(Open the recorded <code>rvat.out</code>, change one bit pattern in one table &mdash; say <code>0x00b6352f</code> to <code>0x00b6353f</code> &mdash; and run <code>python3 crosscheck.py</code>. It fails, and it names the two checks that depended on it. <strong>Now change the sentence that explains the table and see whether it fails too</strong>, which is a different and harder thing to arrange: the first version of this harness could not do it, and the corruption script is what found out.)</em></li>
                    <li><strong>Count a bit position yourself, in two instruction groups.</strong> <em>(In <code>vec_objdump.txt</code>, find an unmasked <code>vadd.vv</code> and the <code>vadd.vv</code> masked with <code>v0.t</code> immediately after it. XOR them. Then do the same for a <code>vle32.v</code> pair. Same number both times. <strong>Now ask what would have to be true of the hardware for the mask to be a property of one instruction group rather than of the word</strong> &mdash; and the answer is what the eleven-row table with zero exceptions is for.)</em></li>
                    <li><strong>Read a retraction as a bug report against a reader.</strong> <em>(Take R9, the true-but-incomplete one. The claim was about a load, and the load really was identical; the fence count beside it was the thing that changed the meaning. <strong>Now ask the general question: in your own comparisons, when is a number a fact about what you fed in rather than about what was chosen?</strong> R12 in this list is the same bug in a different place, and the honest answer to the general question is usually &ldquo;I would not have noticed&rdquo;.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Nothing here is re-taught. The neutral principles are in <a href="/courses/smp/lessons/smp-atomic">smp-atomic</a> and <a href="/courses/simd/lessons/simd-reduce">simd-reduce</a>; the same subject on the two machines this collection can run is <a href="/courses/x86simd/lessons/x86-atomics">x86-atomics</a> and <a href="/courses/a64simd/lessons/a64-neon">a64-neon</a>. The borrowed decoder comes from <a href="/courses/rvasm/lessons/rv-verify">rvasm&rsquo;s rv-verify</a>, and this course prepends four models to it and edits no sibling &mdash; which means <strong>one of this course&rsquo;s retractions is a defect in the other course&rsquo;s code</strong>, published rather than quietly patched, because a course that edits its neighbour to make its own numbers work is a course whose numbers are not measurements any more.</p>
                <p>And the boundary this page draws is the section&rsquo;s last one. The <a href="/courses/rvpriv/lessons/rv-boundary">privileged course</a> drew the same kind of line for a different subject, and reading the two tables side by side is the fastest way to understand why the quoted fraction moves with the <em>subject</em> rather than with the author: 52 per cent quoted when the subject is a document, 35 per cent when the subject is an encoding. <strong>Neither number is a quality score. Both are maps.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvat/lessons/rv-vector">vsetvli and the Four Fields It Carries</a></span>
                <span>Next: <a href="/courses/rvat">Back to the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
