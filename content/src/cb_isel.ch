// Compiler Backend: From IR to Machine Code -- concept 2: instruction
// selection, the tree walk, and the failure mode nobody names.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_isel() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Instruction Selection — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>Instruction Selection</h1>
            <div class="lesson-meta">27 min &middot; Concept 2 of 6 &middot; module: three questions about a sequence &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>You have an operation and you have an instruction. Choosing between them sounds trivial.</h2>
                <p>It is not, and the reason is not that it is hard. It is that <strong>the mapping is not a function</strong>. One IR operation has several machine forms, and one machine form covers several IR operations, and which form is right depends on what surrounds it. Selecting the wrong one is the first of the three backend questions and the only one whose failure is invisible without a value to compare.</p>
                <p>The selector here is the simplest thing that is not trivially wrong: a tree walk over operand <strong>kinds</strong>. A pattern is a pair of (opcode, kind); a machine form is selected by dispatching on the pair.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE SELECTOR IS A TREE WALK/,/LIMIT IS STATED/p'
  THE SELECTOR IS A TREE WALK over operand KINDS, and it is written in
  cbir.py: a pattern is (opcode, kind), a machine form is selected by
  dispatching on the pair, and the destination may be reused as an input
  because every arithmetic form on x86-64 is two-address.

  THE VOCABULARY IS TWELVE OPERATIONS and it is the same twelve on all
  three targets, which is the entire point of having an IR.  §KEEP§A
  real backend has a hundred more, and the limit is stated in
  cbir.py's docstring rather than left for a reader to discover.
                </pre>
                </div>
                <p><strong>Twelve operations, and the same twelve on all three targets</strong> &mdash; that sentence is the entire argument for having an IR in miniature. The selector is the only place that has to know the vocabulary, and it is the same vocabulary on every target, so a new target is a new set of instruction forms rather than a new front end.</p>
                <p>The limit is stated rather than left for you to discover, and it is worth stating here too: <strong>a real backend has a hundred more operations.</strong> The twelve here are enough to make every finding on this page reproducible and not enough to compile a real program.</p>
            </div>

            <div class="unit unit-model">
                <h2>The misroute column, and it is not a typo</h2>
                <p>Two selectors run over all four kernels. <code>isel_tree</code> dispatches on the pattern as written. <code>isel_kind</code> dispatches on operand kind alone.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  kernel   instructions   isel_tree/,/49/p'
  kernel   instructions   isel_tree   isel_kind   MISROUTED
  kernel_a            12          12          12          10
  kernel_b            17          17          17          12
  kernel_c            16          16          16          13
  kernel_d            16          16          16          14
  TOTAL               61          61          61          49
                </pre>
                </div>
                <p><strong>49 of 61 instructions routed to the wrong machine form.</strong> That is the classic trap and it is not a typo, and here is the mechanism: a selector that dispatches on operand kind alone takes the first pattern with a matching kind. In the table in <code>cbir.py</code> that first pattern is <code>add</code> for every two-operand arithmetic form. So <strong>every <code>sub</code>, <code>xor</code>, <code>shl</code> and <code>mul</code> in the corpus is routed to the instruction for <code>add</code>.</strong></p>
                <p>Here is the first misrouted instruction, printed so the mechanism is not a paragraph:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE FIRST MISROUTED INSTRUCTION/,/NEITHER OF THEM EVER FAILS/p'
    instruction 0 is      v0 = mov 7
    its operand kind is    ri
    isel_tree  emits       mov       &lt;- correct
    isel_kind  emits       add       &lt;- the bug
                </pre>
                </div>
                <p><strong>Both routes have the same operand kind.</strong> <code>mov</code> and <code>add</code> have the same operands, so a dispatch that cannot see the opcode cannot see the difference. And neither of them ever fails.</p>
                <p>That is the sentence worth stopping on. <strong>The result is not a crash. It is a program that computes a different number, and the selector never fails once.</strong> There is no exception, no diagnostic, no warning. The selector did exactly what it was told, correctly, according to a rule that was wrong.</p>
                <div class="formula">
   WHY A COUNT IS NOT A RECEIPT HERE

   A count tells you HOW MANY instructions the selector
   emitted.  Every run emitted 61, because the selector
   emits one machine instruction per IR instruction
   either way.  The count is IDENTICAL on the correct run
   and on the broken one.

   So the receipt has to be a VALUE, and the value has
   to be computed by something that did not go through
   the selector.  A checksum run by cbir.step is that
   something.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The checksum, which is the receipt and not the count</h2>
                <p>Fold the program&rsquo;s values before and after routing one <code>sub</code> to <code>add</code>:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/the correct program folds/,/IT IS A DIFFERENT PROGRAM/p'
  the correct program folds to  193715795505516148
  one sub computed as an add    193715795509322676
  §KEEP§THE TWO NUMBERS DIFFER, AND THAT IS THE ONLY SENTENCE IN THIS
  SECTION THAT MATTERS: §KEEP§A MISROUTED INSTRUCTION IS NOT A BAD
  INSTRUCTION SELECTION, IT IS A DIFFERENT PROGRAM.
                </pre>
                </div>
                <p>Two 18-digit numbers and they differ. <strong>A misrouted instruction is not a bad instruction selection; it is a different program.</strong> Everything else on this page is mechanism. That sentence is the finding.</p>
                <h3>Fusion, and why it is an operand count rather than a scheduling decision</h3>
                <p>A multiply-accumulate is <strong>one instruction on AArch64 and two on x86-64</strong>, and the difference is not about when things run. It is about how many operands fit in the word. So the question is asked of the <em>encoding</em>, and it is measured by building the words by hand rather than assembling them &mdash; because an assembler hides exactly the question being asked.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE ENCODER AGAINST A REAL ASSEMBLER/,/7 of 7 agree/p'
    instruction                      assembler    this file   agree
    madd  x0, x1, x2, x3            9b020c20   9b020c20   yes
    msub  x4, x5, x6, x7            9b069ca4   9b069ca4   yes
    add   x8, x9, x10, lsl #1       8b0a0528   8b0a0528   yes
    add   x11, x12, x13, lsl #2     8b0d098b   8b0d098b   yes
    madd  w0, w1, w2, w3            1b020c20   1b020c20   yes
    add   x0, x1, #0xfff            913ffc20   913ffc20   yes
    movz  w10, #0x6                 528000ca   528000ca   yes

    7 of 7 agree.
                </pre>
                </div>
                <p><strong>MEASURED-ON-BYTES</strong>, and the label matters: this is an encoder against an assembler, not a two-reader cross-check. It is a different kind of evidence and it is labelled as one.</p>
                <p>And it is what caught the bugs. All three of them, none of which raised an error. The sharpest was reading the three-source group selector out of the wrong group, which produced a <code>msub</code> where a <code>madd</code> belonged &mdash; <strong>a plausible word, in a legal opcode space, that means something else entirely</strong>, and the only reason it was found is that the course had asked for a disagreement count and there was nowhere to hide it.</p>
                <div class="callout callout-note">
                    <p><strong>Three bugs, no exceptions, and one comparison table.</strong> That is the general form. An encoder that produces a word for every input cannot fail by raising &mdash; there is nothing to raise <em>from</em>. The only thing standing between a plausible encoding and a wrong one is <strong>a second program that reads the word back and a table that says how many of them agreed.</strong> A field read out of the wrong group and a field read out of the right one differ by bits that are all legal in both cases.</p>
                </div>
                <p>Now the operand count, read out of the words by two programs written for different jobs:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE FUSED FORM, ENCODED HERE/,/3 of 3 agree/p'
    madd x0, x1, x0, x2   = 0x9b000820   4 bytes
    add  x0, x1, x2       = 0x8b020020   4 bytes
    ret                   = 0xd65f03c0   4 bytes

    word         this file's fields   this file's text        the sibling decoder says
    0x9b000820   0,1,0,2            madd x0, x1, x0, x2      madd x0, x1, x0, x2
    0x8b020020   0,1,2,0            add x0, x1, x2           add x0, x1, x2
    0xd65f03c0   0,30,31,0          ret                      ret

    3 of 3 agree.  §KEEP§THE SIBLING DECODER IS rvasm/a64asm'S
    OWN FILE, WRITTEN FOR A DIFFERENT COURSE, AND IT HAS NEVER
    HEARD OF cbenc.py.
                </pre>
                </div>
                <p>The sibling decoder is <code>a64asm</code>&rsquo;s own file, written for a different course, and it has never heard of <code>cbenc.py</code>. <strong>That is what makes the agreement evidence instead of a restatement.</strong></p>
                <p>And now the finding, which is not the obvious one:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -A 6 'AND NOW THE ACTUAL FINDING'
  §KEEP§AND NOW THE ACTUAL FINDING, WHICH IS NOT THE OBVIOUS ONE.
  FOUR FIVE-BIT REGISTER FIELDS ARE TWENTY BITS OF THIRTY-TWO. §KEEP§THE
  REMAINING TWELVE HOLD sf, A TEN-BIT GROUP SELECTOR, THE MADD/MSUB
  BIT AND THE SHIFT AMOUNT. §KEEP§THE THREE-OPERAND FORM IS NOT A
  COMPRESSED FORM AND NOT A COMPROMISE; IT IS THE SAME WIDTH WITH ONE
  FIELD READING 31, WHICH IS HOW THE ENCODING SAYS "NO FOURTH
  OPERAND".
                </pre>
                </div>
                <p><strong>Twenty bits of register numbers, twelve bits of everything else.</strong> A three-operand form is not a compressed form and not a compromise &mdash; it is the same 32 bits with one field reading <code>31</code>, which is how the encoding says <em>no fourth operand</em>. The field is spent. Anyone who wants to extend the multiply to four operands has to find twelve bits somewhere, and there are not twelve bits.</p>
            </div>

            <div class="unit unit-example">
                <h2>The x86-64 half, which is a refusal</h2>
                <p>The same question on the other architecture has the opposite answer, and the shape of the code is the interesting part. x86-64 has no three-operand integer multiply, and the encoder here <strong>refuses rather than approximating</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE x86-64 SIDE/,/THE MODRM BYTE IS WHERE IT/p'
    imul rbx, rcx  -&gt;  48 0f af cb
    add  rbx, rdx  -&gt;  48 01 d3

    enc_x86('imul', 'rax', 'rbx', 'rcx') is the call a
    backend would have to make -- a THREE-OPERAND multiply -- and:
      enc_x86 takes (op, dst, src) and NOTHING ELSE; x86-64 has no three-opera
                </pre>
                </div>
                <p>Two instructions. The multiply first, then the add, and they are not one instruction with a different mnemonic &mdash; <strong>they are a different opcode</strong>. The only way x86-64 fuses <code>a*b+c</code> is to put the add in the ModRM byte of the <code>imul</code>, which is a different encoding entirely.</p>
                <p>Where that lives is the ModRM byte, and the layout is the whole reason: <strong>bits 3 to 5 are the source and the low three are the destination.</strong> So the encoder puts the destination where the base field is and the source where the shifted field is, and there is no room for a third register name because the byte has no third field. Two of the three bits that could have been a third operand are the reg field, which is what distinguishes <code>add</code> from <code>or</code> from <code>adc</code> from <code>sbb</code>. The bits are spoken for.</p>
                <h3>The signature that accepts the wrong call</h3>
                <p>Here is a failure mode worth naming because it is the worst shape a function signature can have, and it happened here:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | grep -A 10 'AND THE FAILURE MODE WORTH NAMING'
  §KEEP§AND THE FAILURE MODE WORTH NAMING: §KEEP§THE SIGNATURE IS
  `enc_x86(op, dst, src, rex_w=True)`, §KEEP§SO A CALL WITH FOUR
  POSITIONAL ARGUMENTS BINDS THE FOURTH TO `rex_w` -- WHICH IS
  A TRUTHY STRING -- §KEEP§AND WITHOUT AN EXPLICIT ARITY CHECK
  IT ENCODED A TWO-OPERAND INSTRUCTION WHEN THE CALLER ASKED
  FOR THREE. §KEEP§A CALL THAT LOOKS LIKE IT IS BEING REJECTED
  AND IS INSTEAD SILENTLY ACCEPTED IS THE WORST SHAPE A
  FUNCTION SIGNATURE CAN HAVE, §KEEP§AND IT PRODUCED A
  PLAUSIBLE ENCODING RATHER THAN AN ERROR.
                </pre>
                </div>
                <p>Read that twice. The signature is <code>enc_x86(op, dst, src, rex_w=True)</code>. A caller asks for a three-operand multiply and passes four positional arguments. The fourth binds to <code>rex_w</code>, which is a <strong>truthy string</strong>. And instead of an arity error the function encodes a two-operand instruction and returns it &mdash; a plausible encoding rather than an error.</p>
                <div class="formula">
   THE GENERAL RULE, AND IT IS ABOUT THE CALLER

   A function that CANNOT express a request should say so
   in its signature:  def encode3(op, a, b, c).  A signature
   with a default parameter it does not own silently accepts
   a call the function cannot honour.

   The default parameter is not the problem.  The problem is
   that the default's NAME means something to the caller and
   means something ELSE to the callee, and neither of them
   checks.

   cbenc.py keeps the four-argument signature because the
   REX.W bit is real and x86-64 genuinely needs it -- and
   that is exactly why the shape is dangerous.  A signature
   with no legitimate fourth argument cannot be misused this
   way.  A signature with a legitimate fourth argument can,
   and will.
                </div>
                <p>What clang actually emitted for the same C, as a third reader, and the AArch64 word it emitted is the same word <code>cbenc.py</code> encoded from four register numbers with no table and no library:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/AND WHAT clang ACTUALLY EMITTED/,/NO TABLE AND NO LIBRARY/p'
    aarch64   0 instructions, 0 bytes
    x86_64    9 instructions, 31 bytes
         0  48 8d 04 77    leaq	(%rdi,%rsi,2), %rax
         4  48 8d 14 52    leaq	(%rdx,%rdx,2), %rdx
         8  48 01 c2       addq	%rax, %rdx
         b  48 8d 04 8a    leaq	(%rdx,%rcx,4), %rax
         f  4b 8d 0c 80    leaq	(%r8,%r8,4), %rcx
        13  48 01 c1       addq	%rax, %rcx
        16  4b 8d 04 49    leaq	(%r9,%r9,2), %rax
        1a  48 8d 04 41    leaq	(%rcx,%rax,2), %rax
        1e  c3             retq

  §KEEP§AND THE AArch64 WORD clang EMITTED IS THE SAME WORD cbenc.py
  ENCODED, WHICH IS THE POINT OF HAVING AN ENCODER: §KEEP§THE SAME
  0x9b000820, FROM FOUR REGISTER NUMBERS, WITH NO TABLE AND NO LIBRARY.
                </pre>
                </div>
                <p>Notice the <code>leaq</code> lines. x86-64 reaches a multiply by three by putting the scaling factor in the <strong>address</strong> rather than in an arithmetic instruction &mdash; <code>leaq (%rdi,%rsi,2)</code> is <code>rdi + rsi*2</code> with no multiply instruction at all, no flags, and one instruction. <strong>That is a selector decision, not an encoding one</strong>, and it is why the instruction count on the two sides of this comparison is 9 against 0: the AArch64 side is one <code>madd</code>, the x86-64 side is nine instructions that do the same job with a different vocabulary.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Ship the kind-only dispatch and watch nothing fail.</strong> <em>(Open <code>cbir.py</code> and find the <code>isel_kind</code> dispatch. Confirm it reaches the pattern table by kind alone, then replace every <code>sub</code> with an <code>add</code> in one kernel and re-run. Expect <strong>no exception, no diagnostic, and a different checksum</strong>: 193715795505516148 becomes 193715795509322676. Then try the same thing and check the <em>instruction count</em> &mdash; it stays at 61, because the selector emits one machine instruction per IR instruction either way. <strong>A count cannot see this bug.</strong> That is the exercise.)</em></li>
                    <li><strong>Read a field out of the wrong group and see that nothing complains.</strong> <em>(In <code>cbenc.py</code>, deliberately read the three-source group selector from the two-source position. Re-run the seven specimens. Expect a <code>msub</code> where a <code>madd</code> belongs, and expect the word to be a <em>perfectly legal</em> AArch64 encoding of the wrong instruction. There is no illegal instruction here, and an assembler would accept it if you asked it to. Only the disagreement count against a real assembler&rsquo;s output finds it &mdash; which is why the comparison table exists.)</em></li>
                    <li><strong>Call <code>enc_x86</code> with four positional arguments.</strong> <em>(<code>enc_x86('imul', 'rax', 'rbx', 'rcx')</code>. Expect a <strong>two-operand encoding</strong> rather than an arity error, because the fourth binds to <code>rex_w</code>. Then add the arity check and watch it refuse. The difference between those two versions of the function is the whole lesson: one returns a plausible encoding of the wrong instruction, the other says no.)</em></li>
                    <li><strong>Compile one <code>a*b+c</code> for all three targets and count the instructions.</strong> <em>(<code>-O2</code>, x86-64, AArch64 and RISC-V. Expect one <code>madd</code>-shaped instruction on AArch64 and something longer on x86-64 &mdash; and expect the x86-64 form to be built from <code>leaq</code>, not from a multiply at all. Then find where the accumulator <em>has</em> to survive: on AArch64 the fourth operand field is a real register, and on x86-64 the accumulator must already be in the destination register before the multiply starts. That constraint &mdash; <strong>which register the accumulator is in before the instruction</strong> &mdash; is a scheduling constraint discovered from an encoding fact, and it is the sort of thing you only find by writing the encoder.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/compback/lessons/cb-ir"><code>cb-ir</code></a> established that the IR is target-independent in its operations and target-dependent in its shapes, and this page is the first place those shapes bite. The <strong>twelve-opcode vocabulary is the same on all three targets</strong> and that is the argument for the IR; the <strong>form each operation takes is not</strong>, and that is the argument for the backend. <a href="/courses/isa/lessons/isa-opcodes"><code>isa-opcodes</code></a> teaches how to read a byte and stops there; this page asks which bytes to emit.</p>
                <p>Across architectures, <a href="/courses/a64asm/lessons/a64-encoding"><code>a64-encoding</code></a> is where the AArch64 data-processing field positions were laid out, and <a href="/courses/x86asm/lessons/x86-integers"><code>x86-integers</code></a> is where <code>imul</code>&rsquo;s three forms were tabulated. This page does not repeat either table. It <strong>re-encodes seven words from register numbers and checks them against a real assembler</strong>, and the reason that is worth a page rather than a reference is that the encoder is a hundred lines and the disagreement count is the only thing that keeps it honest.</p>
                <p>Forwards, <a href="/courses/compback/lessons/cb-regalloc"><code>cb-regalloc</code></a> takes the selector&rsquo;s output and gives every value a name. It has the same shape of trap and the same answer: <strong>49 wrong machine forms did not fail loudly, and a spill count that is too low does not fail loudly either.</strong> And <a href="/courses/compback/lessons/cb-sched"><code>cb-sched</code></a> reorders what selection produced, and finds a schedule that is faster and wrong &mdash; the same shape one pass later.</p>
                <p>Outward, the reusable lesson is not about instruction selection at all. <strong>A pass that cannot fail needs a value to check, not a count to compare.</strong> That is why every number in this course has a checksum beside it, why the timing section prints a checksum for all four arms before it prints any ratio, and why <a href="/courses/compback/lessons/cb-verify">the last concept</a> separates the three things you can count from the one thing you can only read.</p>
                <p>And what this page cannot show, in the artifact&rsquo;s own words: <strong>it cannot show that fusing is faster.</strong> Two instructions that depend on each other cost one more cycle than one that does not &mdash; and the timing for that is on the register-allocation page, where the number is <em>not</em> attributed to fusing alone. A backend author who has read this page knows the encoding argument completely and the timing argument not at all, which is the correct state to be in and a good reason to read the limit rather than skip it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback/lessons/cb-ir">What an IR Is For, and What It Must Not Be</a></span>
                <span>Next: <a href="/courses/compback/lessons/cb-regalloc">Register Allocation</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
