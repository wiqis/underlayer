// Compiler Backend: From IR to Machine Code -- concept 5: the backend's
// SIDE of the ABI bargain, and why the order of two passes is not a matter
// of taste.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_cb_abi() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Backend and the ABI — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson compback-concept">
            <a href="/courses/compback" class="back-link">Compiler Backend: From IR to Machine Code</a>
            <h1>The Backend and the ABI</h1>
            <div class="lesson-meta">23 min &middot; Concept 5 of 6 &middot; module: the contract, and reading the decisions back out &middot; <a href="/courses/compback">Compiler Backend: From IR to Machine Code</a></div>

            <div class="unit unit-why">
                <h2>The obligation is not the convention</h2>
                <p>Three courses in this collection already taught the three calling conventions, in full, each with its document named: <a href="/courses/x86abi/lessons/x86-calling"><code>x86-calling</code></a>, <a href="/courses/a64abi/lessons/a64-aapcs"><code>a64-aapcs</code></a>, and <a href="/courses/rvabi/lessons/rv-calling"><code>rv-calling</code></a>. This page does not repeat a single table from them. <strong>If you want to know which registers carry arguments on AArch64, you already know, and the right page for that is the one linked above.</strong></p>
                <p>What is left is the other half of the bargain, and it is the half nobody teaches: <strong>what a compiler has to know about the ABI, and when it has to know it.</strong> The convention is a document. The obligation is a scheduling constraint on your own passes, and getting it wrong does not produce a program that disagrees with a spec &mdash; it produces a program that is slower than it needed to be, with nothing in the output to say so.</p>
                <p>So the subject here is an <em>order</em>, and the artifact states the order before it prints a register name:</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE OBLIGATION IS NOT THE CONVENTION/,/IT LOOKED LIKE IT NEEDED NONE/p'
THE OBLIGATION IS NOT THE CONVENTION.  x86abi, a64abi and rvabi each
taught their convention in full.  This section measures the BACKEND'S
SIDE of the bargain, and the order matters:

    a backend that emits a call must ALREADY know the argument
    registers, the return register, the callee-saved set and the stack
    alignment -- and it must know them BEFORE it has allocated a
    register to anything.

  §KEEP§REGISTER ALLOCATION ASSIGNS NAMES TO VALUES AND THE ABI ASSIGNS
  NAMES TO ARGUMENTS, AND THE ORDER IS NOT A MATTER OF TASTE. §KEEP§IF
  THE ALLOCATOR RUNS FIRST AND THE ABI IS CONSULTED SECOND, THE
  ALLOCATOR HAS ALREADY GIVEN `rbx` TO A VALUE AND THE PROLOGUE NOW HAS
  TO SAVE IT -- A PROLOGUE THE BACKEND DID NOT PLAN FOR, AND §KEEP§ON
  x86-64 THAT MEANS A STACK FRAME WHERE THE FUNCTION LOOKED LIKE IT
  NEEDED NONE.
                </pre>
                </div>
                <p>Read the last clause slowly, because it is the sharpest thing on this page. <strong>If the allocator has already given <code>rbx</code> to a value, the function now has to save and restore <code>rbx</code> &mdash; and on x86-64 that means a stack frame.</strong> A function that had no frame now has one, with the push and the pop and the frame pointer arithmetic that goes with them, for the sake of a register the backend chose freely and then discovered it could not keep.</p>
                <div class="callout callout-note">
                    <p><strong>This is the same class of failure as the two pages before, and it is worth naming the class once.</strong> A selector that dispatches on operand kind produced a program that computed a different number and never failed. An allocator built on half-open live ranges reported a <em>better</em> spill count and never failed. A backend that learns the ABI after allocating produces a function with a frame it did not plan for, and never fails either. <strong>In all three cases the output is a plausible program and the damage is in something nobody printed.</strong> That is what a constraint you consulted too late looks like from the inside.</p>
                </div>
            </div>

            <div class="unit unit-model">
                <h2>What is QUOTED, and what was actually measured</h2>
                <p>The register names in the next two blocks are <strong>QUOTED</strong>, with a document and a section for each line, because no register name is something a measurement on this host produces. Read the documents rather than trusting the table, and note that the table is one line per target on purpose.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/THE CONVENTIONS, QUOTED, one line each/,/the a0-a7 argument registers/p'
  THE CONVENTIONS, QUOTED, one line each, with the document:

    x86_64     rdi rsi rdx rcx r8 r9     System V Application Binary Interface, AMD64 Architecture Processor Supplement, "The Function Call Interface", section 3.2.1
    aarch64    x0 x1 x2 x3 x4 x5         Procedure Call Standard for the Arm 64-bit Architecture (AAPCS64), 2025Q1, section 6.1, parameter registers
    riscv64    a0 a1 a2 a3 a4 a5         RISC-V ABIs Specification v1.0, "Integer Calling Convention", the a0-a7 argument registers
                </pre>
                </div>
                <p>The second block is the number the allocator has to <strong>subtract</strong>, and it is the one people forget. The argument registers tell you where values <em>arrive</em>. The reserved registers tell you what the machine will not let you use for your own bookkeeping.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/AND WHAT EACH ONE RESERVES/,/x1 is the return address re/p'
  AND WHAT EACH ONE RESERVES, which is the number the allocator has to
  SUBTRACT, QUOTED from the same documents:

    x86_64     rsp rbp and, for a function that makes a call, rax
              SysV AMD64 supplement 3.2.2: %rsp is the stack pointer; %rbp is th
    aarch64    x29 (fp) x30 (lr) and, when used, x16 x17
              AAPCS64 6.4.1: x29 is the frame record chain, x30 the link registe
    riscv64    x2 (sp) and, for a function that makes a call, x1 (ra)
              riscv-cc "Integer Calling Convention": x1 is the return address re
                </pre>
                </div>
                <p>Notice the conditional in two of the three rows. <code>rax</code> is reserved on x86-64 <em>only for a function that makes a call</em>, and <code>x1</code> only for the same reason on RISC-V. <strong>A backend that reserves them unconditionally is leaving registers on the table in every leaf function, and a backend that never reserves them corrupts the return address of every one that calls.</strong> That is not a detail of the convention; it is a fact about the order of your passes, because whether a function calls is something you learn from the IR and something you need to know before you allocate.</p>
                <h3>The same registers, measured &mdash; by name, then by bits</h3>
                <p>The first measurement counts argument registers <em>by name in the disassembly</em>. This is <strong>MEASURED-ON-BYTES</strong>: words were emitted and read back.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  target   arg registers the compiler READ/,/SO IT IS IN THE LIMITS AND/p'
  target   arg registers the compiler READ    insns   bytes
  x86_64     6 of  6: rdi rsi rdx rcx r8 r9             9     31
  aarch64    6 of  6: x0 x1 x2 x3 x4 x5                 9      9
  riscv64    6 of  6: a0 a1 a2 a3 a4 a5                 9      9

  §KEEP§THE SIXTH ARGUMENT IS STILL IN A REGISTER ON ALL THREE, AND
  THAT IS THE POINT OF THE EXAMPLE. §KEEP§IT IS ALSO WHY THE EXAMPLE
  HAS SIX ARGUMENTS AND NOT SEVEN: §KEEP§THE SEVENTH IS THE ONE THAT
  MOVES TO THE STACK, AND §KEEP§HOW MANY ARGUMENTS SPILL IS A FACT
  ABOUT THE ABI AND NOT ABOUT THE BACKEND, SO IT IS IN THE LIMITS AND
  NOT HERE.
                </pre>
                </div>
                <p><strong>Six of six on all three targets.</strong> And the artifact is explicit about why the example stops at six rather than seven, and the reason is the kind of thing worth internalising: <em>the seventh argument is the one that moves to the stack, and how many arguments spill is a fact about the ABI and not about the backend</em> &mdash; so it belongs in the limits, where a reader has to go looking for it, and not in the table where it would look like a measurement of the compiler.</p>
                <p>Two numbers in that table are doing quiet work. The x86-64 function is <strong>9 instructions and 31 bytes</strong> where the other two are 9 instructions and <strong>9 bytes</strong> &mdash; four bytes each, and one instruction at four bytes apiece. The x86-64 build is spending 22 bytes on something the other two encode in nothing at all, and <a href="/courses/compback/lessons/cb-isel"><code>cb-isel</code></a> already showed you what those bytes are: <code>leaq</code> chains doing arithmetic in the address. The ABI did not get more expensive; the instruction set did.</p>
                <p>The measurement is also a <strong>lower bound, not an upper one</strong>, and the artifact says why in its ninth numbered limit: an operand may be printed twice by a destructive mnemonic, and a memory operand names a register that is not an argument. <strong>Counting register names in disassembly overcounts, so &ldquo;6 of 6&rdquo; is the weakest reading of the number and is still correct.</strong></p>
                <h3>The second reader, and where the section stops counting names</h3>
                <p>Now the same registers read out of the <em>words</em> by a program that has never heard of this course. Eleven of twelve rows disagree, and the disagreements are printed rather than summarised &mdash; because a decoder printing <code>(undefined)</code> is claiming the architecture defines no meaning for a word the architecture defines precisely.</p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  target   word    the artifact.s own reading/,/COULD BE WRONG IN THE SAME WAY AS THE OTHER THREE, SO THE ROWS/p'
  target   word    the artifact's own reading        the sibling decoder says
  aarch64   8b010408  add x8, x0, x1, lsl #1    add x8, x0, x1, lsl, #1   &lt;-- DISAGREES
  aarch64   8b020449  add x9, x2, x2, lsl #1    add x9, x2, x2, lsl, #1   &lt;-- DISAGREES
  aarch64   528000ca  movz w10, #6              movz w10, #0x6   &lt;-- DISAGREES
  aarch64   8b090108  add x8, x8, x9            add x8, x8, x9
  aarch64   8b040889  add x9, x4, x4, lsl #2    add x9, x4, x4, lsl, #2   &lt;-- DISAGREES
  aarch64   8b030908  add x8, x8, x3, lsl #2    add x8, x8, x3, lsl, #2   &lt;-- DISAGREES
  riscv64   20a5a533  add x10, x11, x10         (undefined) (undefined)   &lt;-- DISAGREES
  riscv64   20c625b3  add x11, x12, x12         (undefined) (undefined)   &lt;-- DISAGREES
  riscv64   20e74633  add x12, x14, x14         (undefined) (undefined)   &lt;-- DISAGREES
  riscv64   0000952e  unknown op=0x2e           c.add a0, a1   &lt;-- DISAGREES
  riscv64   20a6c533  add x10, x13, x10         (undefined) (undefined)   &lt;-- DISAGREES
  riscv64   00009532  unknown op=0x32           c.add a0, a2   &lt;-- DISAGREES

  1 of 12 agree.  §KEEP§THE SIBLING DECODERS ARE a64asm'S AND
  rvasm'S OWN FILES, AND NEITHER HAS HEARD OF cbenc.py OR
  cbabi.py. §KEEP§AND THE ARTIFACT'S OWN READING OF A WORD IS
  `_our_render`, WHICH IS A FOURTH RENDERER AND THE ONE THAT
  COULD BE WRONG IN THE SAME WAY AS THE OTHER THREE, SO THE ROWS
  ARE PRINTED RATHER THAN SUMMED.
                </pre>
                </div>
                <p><strong>Eleven of twelve rows disagree and one agrees.</strong> Read what the disagreements actually are before you draw a conclusion, because the naive one is wrong: nine of the eleven are <em>spelling</em> &mdash; <code>lsl, #1</code> against <code>lsl #1</code>, <code>#0x6</code> against <code>#6</code>. The same word, printed two ways by two programs with no agreement on commas or on the base of a hexadecimal literal.</p>
                <p>And <strong>two of the twelve rows are disagreements about the architecture, not about punctuation</strong>: the two this artifact reads as <code>unknown op=0x2e</code> and <code>unknown op=0x32</code>, which the RISC-V decoder from <code>rvasm</code> names <code>c.add a0, a1</code> and <code>c.add a0, a2</code>. Those are the compressed forms, and <strong>a decoder that does not implement C prints <code>unknown</code> for a word the base ISA defines perfectly well.</strong></p>
                <div class="formula">
   THE SENTENCE THIS TABLE EXISTS TO PROVE

   A CROSS-CHECK THAT PRINTS A DISAGREEMENT
   COUNT IS REPORTING SPELLING UNTIL
   SOMETHING READS THE ROWS.

   Nine of eleven here are commas and radixes.
   Two are a missing extension.

   "1 of 12 agree" is TRUE and USELESS on its own.
   A reader who stops at the count concludes the
   decoders are broken; a reader who reads the rows
   concludes what is actually true -- that three
   renderings of the same 32 bits agree on the
   BITS and disagree about PUNCTUATION, and that
   one of them does not implement a third of the
   instruction set.
                </div>
                <p>And the artifact names its own weakest reader rather than only the sibling&rsquo;s. Its reading of a word is <code>_our_render</code>, <strong>which is a fourth renderer and the one that could be wrong in the same way as the other three</strong> &mdash; it shares an author with <code>cbenc.py</code>. Two independent decoders agreeing is evidence; one decoder agreeing with itself is a restatement, which is the same distinction <a href="/courses/compback/lessons/cb-isel"><code>cb-isel</code></a> drew when it checked seven hand-encoded words against a real assembler.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Six things, as a list, because a list is what you can go and look for</h2>
                <p>The artifact ends the section with the obligation enumerated rather than described, and the choice of a list is the content: <strong>every item is a thing a reader can go and look for in a document or in a disassembly, and a paragraph would have made five of them unverifiable.</strong></p>
                <div class="hex-dump">
                <pre>$ python3 compback.py --run | sed -n '/  1. the argument registers, IN ORDER/,/ORDINARY ONE/p'
  1. the argument registers, IN ORDER, with their count
  2. the return value register, and whether there is more than one
  3. which registers are callee-saved, so the prologue knows what to save
  4. the stack alignment the callee must establish, and WHO pays for it
  5. whether varargs exist, because on x86-64 they consume a register AL
  6. the unwind shape, so a debugger can walk the frame

  §KEEP§AND ITEM 5 IS THE ONE THAT BITES, BECAUSE AL IS AN ARGUMENT
  REGISTER THAT BECOMES THE VECTOR-COUNT REGISTER, SO A VARARGS CALL
  CANNOT BE ENCODED BY THE SAME PROLOGUE AS AN ORDINARY ONE.
                </pre>
                </div>
                <p>Two of those six deserve more than the list gives them, because both are the same mistake wearing different clothes.</p>
                <p><strong>Item 4 &mdash; the stack alignment, and who pays for it.</strong> This is a question about <em>who is responsible</em>, not about a number, and it is the item on this list whose answer the artifact names but does not resolve. If the caller must establish the alignment, the callee may assume it. If the callee must establish it, every leaf pays a prologue to fix something it never disturbed. <strong>Which of those two it is has to be read out of the document, because nothing on this host measures it</strong> &mdash; and getting it backwards is the same failure as the <code>rbx</code> clause at the top of the page, arrived at from the other end: a frame in every function, for a condition the function never created.</p>
                <p><strong>Item 5 &mdash; varargs, and the register that changes jobs.</strong> On x86-64, <code>al</code> is an argument register. It is <em>also</em> the vector-count register, and it is where the number of vector arguments goes. So <strong>a varargs call cannot be encoded by the same prologue as an ordinary one</strong>, and a backend whose prologue is a fixed block of instructions has a real problem the moment it selects a call it did not expect.</p>
                <div class="formula">
   A SELECTOR THAT NEEDS A SCRATCH REGISTER
   THE ABI FORBIDS HAS A REAL PROBLEM

   `al` is not a spare register.  It is an argument
   register that a different calling convention overloads
   to mean "how many vector arguments follow".

   So a lowering pass that reaches for a scratch
   register and picks "the 16-bit view of rax" because
   it is unused is holding a register the ABI has
   already given a job to.

   THE ABI IS FIXED BEFORE INSTRUCTION SELECTION
   STARTS, WHICH IS THE WHOLE PAGE.  A selector
   cannot discover this later, because by the time it
   could, the allocator has already spent the
   register on somebody's value.
                </div>
                <p>That is the sentence to carry out of the page. <strong>The ABI is fixed before instruction selection starts.</strong> Not before code generation, not before register allocation &mdash; before <em>selection</em>, which is the very first of the three questions this course asked. A selector that needs a scratch register the ABI forbids does not have a lower-priority problem to solve later. It has a constraint it was never told about, and the evidence of it will be a miscompiled function rather than a diagnostic.</p>
                <div class="callout callout-note">
                    <p><strong>Item 6 is the one that belongs to the next page.</strong> &ldquo;The unwind shape, so a debugger can walk the frame&rdquo; is a whole discipline in its own right, and <a href="/courses/x86abi/lessons/x86-unwind"><code>x86-unwind</code></a> and <a href="/courses/a64abi/lessons/a64-unwind"><code>a64-unwind</code></a> teach it. What a backend must do about it is small and worth stating: emit the prologue in the shape the unwind information describes, and emit the unwind information. A frame you cannot walk is still a frame &mdash; it just costs you your stack traces.</p>
                </div>
            </div>

            <div class="unit unit-example">
                <h2>The three conventions side by side, and what a reader should notice</h2>
                <p>Set the quoted tables beside each other and one structural difference shows up that is not about register numbers at all: <strong>on x86-64 the last argument register is <code>r9</code>, on AArch64 it is <code>x5</code>, and on RISC-V the argument registers are <code>a0</code> through <code>a7</code> &mdash; eight, not six.</strong> That is why this course&rsquo;s example function has six arguments and not seven or eight: it is a number that fits in all three files without a stack argument on any of them, and the artifact says so in the block above.</p>
                <p>Here is the honest summary of what was measured and what was not, because the page&rsquo;s numbers and the page&rsquo;s knowledge come from different places and a reader deserves to know which is which:</p>
                <div class="formula">
   WHAT THIS PAGE CLAIMS, AND FROM WHERE

   QUOTED   the six argument registers on each target,
            and what each reserves.  Three documents,
            named, with sections.

   MEASURED-ON-BYTES   6 of 6 argument registers READ on
            all three targets, 9 instructions each, and
            31 bytes against 9 and 9.

   MEASURED-ON-BYTES   12 words read back by a second
            program, 1 of 12 agreeing, with all 11
            disagreements printed.

   NOT MEASURED HERE  that the call WORKS.  aarch64 and
            riscv64 have no linker and no emulator on
            this host, so nothing emitted for either
            was ever executed and no relocation they
            emit was ever resolved.  x86-64 also never
            ran a call through this page -- it ran
            straight-line code that reads argument
            registers.

   NOT MEASURED HERE  how many arguments spill to the
            stack.  The artifact puts that in the
            limits on purpose: it is a fact about the
            ABI, not about the backend.
                </div>
                <p>That last pair of absences is the reason the section stops at six instructions of <em>reading</em> registers. <strong>The measurement proves that the compiler read six arguments from the six registers the document names. It does not prove that a call to a function written by someone else would arrive correctly</strong> &mdash; and that is a different claim, needing a different experiment, and one this host cannot run for two of the three targets.</p>
                <p>One more thing to notice while the tables are in front of you, because it is the kind of defect that only shows up if you read the block rather than the block&rsquo;s point. <strong>The third column of the reserved table ends mid-word on all three rows</strong> &mdash; <code>%rbp is th</code>, <code>the link registe</code>, <code>the return address re</code>. The sentences are not short; they are <em>clipped</em>, and the full text is in <code>cbabi.py</code>&rsquo;s <code>RESERVED</code> table. Nothing in the recorded output says so, and that is a small failure with a large shadow: <strong>a quotation that ends mid-word cannot be distinguished from a complete one</strong>, so a reader who quotes <code>%rbp is th</code> from this report has quoted a document they have not finished reading.</p>
                <p>Reading the full sentence is worth it, because it turns item 5 from a note into a citation. The untruncated x86-64 reserved-set text reads: <em>&ldquo;%rsp is the stack pointer; %rbp is the frame pointer when used; <strong>%rax holds the number of vector registers used by a variadic call</strong>&rdquo;</em>. So the artifact&rsquo;s own quotation names <code>rax</code> as the register a variadic call is different because of &mdash; which is exactly why item 5 says a varargs call cannot be encoded by the same prologue as an ordinary one, and why the reserved-set row above lists <code>rax</code> as reserved <em>only</em> for a function that makes a call. <strong>The clip hid the sentence that ties the two halves of the section together.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Write the ABI table down first, then write the allocator.</strong> <em>(Before you look at <code>cbreg.py</code>, write down for x86-64: the six argument registers, the reserved set, who establishes stack alignment, and which register varargs overwrites. Then open <code>cbreg.py</code> and find where it would need each of those answers. <strong>Every one of those four places is a place where the answer has to already exist</strong>, and the exercise is not the writing down &mdash; it is discovering that you cannot even express &ldquo;save the registers you were given&rdquo; until you know which registers you were given.)</em></li>
                    <li><strong>Make the example take a seventh argument and see which target changes.</strong> <em>(Change the six-argument function to seven and recompile for all three. Watch x86-64 and AArch64 move the seventh to the stack while RISC-V, which has <code>a6</code> and <code>a7</code> free, keeps it in a register. <strong>That difference is the ABI, not the backend</strong>, and it is why the artifact deliberately stops at six: a table that ran off the end of the register file would have been a measurement of the compiler when it is a fact about three documents.)</em></li>
                    <li><strong>Find the <code>al</code> collision in your own toolchain.</strong> <em>(Compile a variadic function taking a <code>double</code>, and disassemble the caller. On x86-64 the number of vector arguments goes into the low byte of <code>rax</code> before the call &mdash; the register that is also the sixth argument register. <strong>Now find where a naive prologue would put a saved-register copy of <code>rax</code> and check whether it is clobbering the count.</strong> This is a real bug in real hand-written assembly and it is item 5 of the list above, and thirty seconds with a disassembler is enough to see it.)</em></li>
                    <li><strong>Do the reader comparison yourself and classify the disagreements.</strong> <em>(Run <code>rvdec.py</code> over the RISC-V words and <code>a64dec.py</code> over the AArch64 ones, and put the two renderings side by side. Then sort the disagreements into <em>spelling</em>, <em>missing extension</em>, and <em>wrong value</em>. Expect spelling to dominate, expect at least one row to be an extension the decoder does not implement, and <strong>expect your own count of &ldquo;agree&rdquo; to be lower than the cross-check&rsquo;s</strong>, because the cross-check normalises before comparing and you will not. Then write down which category each disagreement belongs to &mdash; a count with no classification is the failure 2.2.114 in this collection found, and it is the reason the artifact prints the rows.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/compback/lessons/cb-regalloc"><code>cb-regalloc</code></a> is the page this one constrains, and the link between them is one sentence: <strong>register allocation assigns names to values, and it needs to know the names it is not allowed to hand out.</strong> That page&rsquo;s finding &mdash; that the metric points the wrong way under a whole class of bugs, because a wrong allocator spills fewer &mdash; has an exact sibling here: a backend that learns the ABI late spends registers it did not have to spend and reports a frame it did not plan. <a href="/courses/a64abi/lessons/a64-frame"><code>a64-frame</code></a> and <a href="/courses/x86abi/lessons/x86-frame"><code>x86-frame</code></a> teach what a frame is once one exists; this page is about the order that decides whether one does.</p>
                <p>Across architectures, this page deliberately teaches no convention. <a href="/courses/x86abi/lessons/x86-calling"><code>x86-calling</code></a>, <a href="/courses/a64abi/lessons/a64-aapcs"><code>a64-aapcs</code></a> and <a href="/courses/rvabi/lessons/rv-calling"><code>rv-calling</code></a> each teach their own in full, and <a href="/courses/rvabi/lessons/rv-noflags"><code>rv-noflags</code></a> is where the RISC-V section showed that a calling convention can be defined by the register that is <em>not</em> there. <strong>What a backend must know before it allocates is the same question on all three targets, and it is the question none of those three pages answers.</strong></p>
                <p>Forwards, <a href="/courses/compback/lessons/cb-verify"><code>cb-verify</code></a> takes every decision this course made &mdash; selection, allocation, scheduling, and the frame this page is about &mdash; and reads them back out of a stripped binary with no symbol table. Its second finding is that <strong>a prologue is visible because it is a frame and not because it saves registers</strong>, which is the direct consequence of the clause at the top of this page: the frame is the observable, the saved registers are the allocator&rsquo;s business, and only the first of the two is recoverable from a disassembly alone.</p>
                <p>Outward, two limits, both printed in the artifact rather than implied. <strong>The argument-register count is a LOWER BOUND</strong>, because a destructive mnemonic can print an operand twice and a memory operand names a register that is not an argument &mdash; so &ldquo;6 of 6&rdquo; is the weakest reading of the number and the correct one. And <strong>nothing about a call was executed</strong>: no <code>aarch64-linux-gnu-ld</code>, no <code>riscv64-linux-gnu-ld</code>, no emulator, so the bytes were emitted and read back and that is all. What this page measures is that the compiler <em>read</em> the registers the documents name &mdash; which is a real thing and a narrower one than &ldquo;the call works&rdquo;, and it is worth being able to say which of the two you have.</p>
                <p>And the reusable lesson, which is the second time this course has needed it in this form: <strong>a constraint you consulted after the pass that depends on it has already run is not a constraint you violated, it is a cost you paid without knowing.</strong> The selector that dispatched on operand kind, the allocator that read half-open ranges, and the backend that learned the ABI second all produced correct-looking output and all cost something nobody printed. Print the frame. Name the policy. State the order. A number without the decision behind it is not a result.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/compback/lessons/cb-sched">Instruction Scheduling</a></span>
                <span>Next: <a href="/courses/compback/lessons/cb-verify">Read a Backend&rsquo;s Decisions Back Out of the Bytes</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
