// The AArch64 Machine: Modes, Memory and Faults -- Concept 6: the
// measured/quoted boundary, the poison, and the retraction list.
//
// This page is the artifact, and the concept that makes the other five
// trustworthy.  Its distinctive claim is a RATIO: 31 QUOTED claims against 21
// MEASURED and 5 MEASURED-ON-BYTES, because the subject of the course is a
// machine and the machine is the one thing this host does not have.  Every
// retraction in the course (sixteen of them) is printed with its source, and
// the poison is the control that gives the 0 in section 9 its meaning.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_evidence() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Is Measured Here, What Is Quoted, and What You Cannot Conclude — Underlayer")
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
            <h1>What Is Measured Here, What Is Quoted, and What You Cannot Conclude</h1>
            <div class="lesson-meta">22 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Everything in the last five concepts carries one of three labels, and on most pages you would be forgiven for not noticing. This page prints all of them, in one table, with the count.</p>
                <p>The reason to do that is not fastidiousness. It is that <strong>this course is about a machine that does not exist on the machine that wrote it</strong>, and a course with that property has exactly one advantage over a course with hardware — it is <em>forced</em> to be explicit about which claims are which kind — and a course that does not take the advantage has thrown away the only thing it had that the x86-64 section did not. So this page is the concept that makes the other five trustworthy, and it is last for the same reason <code>a64-verify</code> is last in the encoding course and <code>a64-unwind</code> is last in the ABI course.</p>
                <div class="formula">
   THE THREE LABELS, and the only honest treatment

   MEASURED            an experiment on the compiler,
                       the assembler, the object file
                       or the bytes.  Reproducible with
                       one command.

   MEASURED-ON-BYTES   a property of the emitted BYTES,
                       read TWICE -- by the decoder in
                       the artifact and by
                       llvm-objdump-21 -- and the two
                       readers are compared word by word.

   QUOTED              a manual claim, with the document
                       and the section printed beside it,
                       and never mixed in with a
                       measurement.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>The table: fifty-seven claims, and the ratio is the finding</h2>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 10 | tail -60
  The whole course, one line per claim, with the label it carries
  and the section that establishes it.  57 claims.

  1 syscall
    MEASURED-ON-BYTES   the syscall number is a 16-bit unsigned field at     sec 3, 4
    MEASURED           the assembler accepts 0..65535 and refuses both     sec 3
    MEASURED           Linux puts the same number in x8, and clang uses    sec 4
    MEASURED           x0-x7 receive the arguments in argument order      sec 4
    MEASURED           the ninth argument is not a register               sec 4
    QUOTED             a Linux syscall takes at most six arguments        sec 2, 4
    QUOTED             __NR_write is 64 and __NR_read is 63                sec 2
    QUOTED             the SVC traps to EL1 and the kernel returns in x0   sec 2
    ...
  6 evidence
    MEASURED           the two readers agree on every word of this corpus  sec 9
    MEASURED           the check detects a poisoned guard                  sec 9B
    MEASURED           the inherited HINT guard is one bit too narrow       sec 3

  21 MEASURED, 5 MEASURED-ON-BYTES, 31 QUOTED, 57 total
  54% of the claims in this course are QUOTED
                </pre>
                </div>
                <p><strong>That ratio is the finding, not a disclaimer.</strong> The subject of this course is a <em>machine</em>, and the machine is the one thing this host does not have, so a majority of the claims about the machine are quotations. What the course can measure — and does, twenty-six times — is the <strong>encoding, the compiler and the object file</strong>, and those are exactly the three things a learner writing a backend has to get right and exactly the three that do not need a CPU.</p>
                <p>The distribution is also not random, and the shape is worth noticing: concept 5 is almost entirely measured, concept 3 is half measured, and concepts 2 and 4 are mostly quoted. That is a direct consequence of what each one is about. A descriptor format is a document; a relocation is a file.</p>
                <h3>The two absences, printed before the first measurement</h3>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 1 | sed -n '1,40p'
  ==========================================================================
  a64sys -- the artifact for "The AArch64 Machine: Modes, Memory and Faults"
  ==========================================================================
  THE METHOD IS FORCED AND IT IS STATED FIRST:
    there is no AArch64 machine on this host, no AArch64 emulator and
    no AArch64 linker, so NOT ONE INSTRUCTION IN THIS COURSE HAS
    BEEN RUN, and there are NO TIMINGS anywhere in this file or on any
    of its six pages.  The x86-64 section measured a 4.92x and a
    27.65x; nothing here has a counterpart and nothing here fakes one.

  ...
     aarch64-linux-gnu-ld     ABSENT  (AArch64 linker)
     qemu-aarch64             ABSENT  (AArch64 emulator)
     aarch64-linux-gnu-as     ABSENT  (a SECOND AArch64 assembler)
     aarch64-linux-gnu-gcc    ABSENT  (an AArch64 GCC)
                </pre>
                </div>
                <p>Four absences, and the fourth is the one that is easy to forget: <strong>there is no second AArch64 assembler</strong>. Every refusal quoted anywhere in this course is a refusal by <code>clang 21.1.8</code>'s integrated assembler and by nothing else, and both readers of the two-reader check come from one LLVM tree. So the check establishes that this decoder and one other piece of software agree on what the bytes mean — <strong>not</strong> that either agrees with silicon.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement that makes the zero mean something: the poison</h2>
                <p>Six files, four optimisation levels, 1,516 instructions, <strong>0 disagreements</strong>. And that number is worthless on its own, which is the entire reason section 9B exists.</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 9 | sed -n '/TOTAL/,/^$/p'
     TOTAL       1516 instructions read, 1516 NAMED by reader 1, 0 DISAGREEMENTS.

  [COVERAGE]         reader 1 names 1516 of 1516 words, so 0 are unmodelled
  [RECONCILED]       the alias rules that fired, each with its count, because
  []                 a normalisation that is not counted is a fudge:
     ldr      -&gt; ldr       320
     adrp     -&gt; adrp      298
     ret      -&gt; ret       208
     ...
     movz     -&gt; mov       46
     mrs      -&gt; mrs        44
     ...
  [DISAGREE]         ZERO true disagreements.
                </pre>
                </div>
                <p>Then one guard, one bit, and the same loop again:</p>
                <div class="hex-dump">
                <pre>  ==========================================================================
    9B  THE POISON: one guard, one bit, and the same loop again
  ==========================================================================

  [CLEAN]            1516 instructions read, 1516 named, 0 DISAGREEMENTS

  [POISONED]         with the poison in: 1459 named, 57 DISAGREEMENTS
     the named count moved from 1516 to 1459 -- 57 instructions
     the disagreement count moved from 0 to 57 -- 57 instructions

     the first few, printed BY NAME so a reader can check them:
     0xd5385208  reader 1: (op 0xd5385208)  reader 2: mrs x8, ESR_EL1
     0xd5384028  reader 1: (op 0xd5384028)  reader 2: mrs x8, ELR_EL1
     0xd5386008  reader 1: (op 0xd5386008)  reader 2: mrs x8, FAR_EL1
     0xd538c008  reader 1: (op 0xd538c008)  reader 2: mrs x8, VBAR_EL1
     0xd518c008  reader 1: (op 0xd518c008)  reader 2: msr VBAR_EL1, x8
                </pre>
                </div>
                <p>1,516 to 1,459 named, 0 to 57 disagreements, and every one of the 57 is an <code>mrs</code> or an <code>msr</code> printed by name. <strong>A check that has never been seen to fail is a check with no reason to be believed</strong>, and this one has now been seen to fail, which is the only property that makes the zero mean anything.</p>
                <p>And the choice of which guard to poison is not arbitrary: <code>mrs</code>/<code>msr</code> is the family this course added, so poisoning it measures <em>this course's</em> contribution rather than the inherited decoder's. Poisoning an inherited guard would produce a larger number and a less informative one, because a reader could not tell how much of the movement was the poison and how much was the twenty-one models that arrived with the file.</p>
                <h3>The bug that made the poison necessary</h3>
                <p>Before the poison there was a retraction, and it is the most valuable thing in the course. The encoding course's decoder has a model whose own claim is <em>"NOP, WFI, YIELD and the rest: 27 fixed bits and a 5-bit hint number"</em>, and whose guard is <code>bits[31:5]</code>:</p>
                <div class="hex-dump">
                <pre>     hint      word        word &gt;&gt; 5   guard matches?
     nop       0xd503201f  0x6a81900   YES
     yield     0xd503203f  0x6a81901   no
     wfe       0xd503205f  0x6a81902   no
     wfi       0xd503207f  0x6a81903   no
     sev       0xd503209f  0x6a81904   no
     sevl      0xd50320bf  0x6a81905   no
     dgh       0xd50320df  0x6a81906   no
     bti       0xd503241f  0x6a81920   no
     bti c     0xd503245f  0x6a81922   no
     bti j     0xd503249f  0x6a81924   no
     bti jc    0xd50324df  0x6a81926   no

     ONE of ELEVEN.
                </pre>
                </div>
                <p>The body of that model is <strong>correct</strong> — it reads the hint number and has the right eleven names — and the guard makes eight of them unreachable. And the reason it survived a whole course is the sentence that generalises further than anything else in this file:</p>
                <div class="formula">
   R4, and the most transferable sentence in the course

   WHY IT SURVIVED

   The encoding course's own corpus, compiled with
   clang, contains no yield, no wfe, no wfi, no sev,
   no sevl, no dgh and no bti.

   A model that is wrong about eight words the corpus
   does not contain is INDISTINGUISHABLE from a model
   that is right, and that course's artifact reports
   its unmodelled words as "9, and the unmodelled ones
   are Advanced SIMD" -- a true sentence about a
   corpus in which the bug cannot appear.

   A count of unmodelled words is a fact about
   A CORPUS and not about A DECODER.

   And the second reader cannot help: `llvm-objdump`
   also prints `(op 0x...)` for a word no rule
   claims.  Two readers that agree because they both
   DECLINE TO ANSWER is not a cross-check; it is a
   shared ignorance with two implementations.
                </div>
                <p>And here is the number that makes the whole thing concrete. The same loop over the same corpus, with three different <em>sets</em> of models:</p>
                <div class="hex-dump">
                <pre>  [MEASURED] what each course's models contribute to THIS corpus

     dispatch                                read  named  coverage
     the encoding course's 21 alone        1516   1374   90.6%
     + the ABI course's 6                 1516   1385   91.4%
     + this course's 6                    1516   1516  100.0%

  [RESULT]           the encoding course names 1374 of 1516 of this corpus
                     (90.6%), and the two later courses add 11 and 131
                </pre>
                </div>
                <p><strong>A coverage number means nothing on its own — it is a number about a corpus.</strong> So the same loop is run three times with three different sets of models, and that is what turns "100% named" from a boast into a number. 1374 of 1516 words of a corpus whose whole subject is the SYSTEM class, and 142 of the 33 models written by the two courses that came after the first.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the retraction list, and the fifteen limits</h2>
                <p>Sixteen retractions, printed in full by the artifact in section 11 with a source for each, and asserted as <em>text</em> by the harness so that a retraction can be neither quietly dropped nor edited into being right. Here they are in one table, with what replaced what:</p>
                <div class="hex-dump">
                <pre>  R1   "the syndrome is a 32-bit field: EC, IL, ISS"
       -&gt; it is 32 bits INSIDE a 64-bit register, bits 55:32
          are ISS2, and a 32-bit mask throws it away

  R2   "the syscall number is the immediate in the SVC"
       -&gt; BOTH are in the emitted code: the field is the
          architectural half and x8 is the Linux half

  R3   the inherited decoder covers the encoding well enough
       -&gt; it names FIVE words of the SYSTEM class, and every
          instruction in this course is outside those five

  R4   "NOP, WFI, YIELD and the rest"
       -&gt; NOP alone: the guard is one bit too narrow, and
          matches 1 of 11 hints the assembler accepts

  R5   one relocation per address reference, as SYSCALL does
       -&gt; TWO, always, for every reference on AArch64

  R6   "x8 is the syscall-number register, so a compiler must
        treat it as reserved"
       -&gt; clang uses it as a scratch in all four functions
          that do not mention it, at all four levels

  R7   the natural test is to shift the syndrome right by 26
       -&gt; clang does not shift, and does not need to: THREE
          instructions, because 0x24 and 0x25 differ in one bit

  R8   the table needs 16 x 0x80 and `.align 11` is the way
       -&gt; the size is right and the DIRECTIVE is only
          necessary; both ends assemble with no diagnostic

  R9   "`.align 11` and it is valid"
       -&gt; necessary and NOT SUFFICIENT, and nothing checks it

  R10  "52-bit" means the high half is 52 bits of address
       -&gt; it means a REGION of 2^52, mapped at the TOP, with
          TTBR1 = 0xffff000000000000

  R11  a page table is an ordinary array, so nothing
       distinguishes it
       -&gt; its ALIGNMENT does, and the alignment is a property
          of the SECTION: 4096 without, 0x200000 with

  R12  a page needs a PAIR because the adrp reach is 4 GiB
       -&gt; the reach is 4 GiB and IRRELEVANT; ADRP MASKS OFF
          the low twelve bits of the target

  R13  the four levels and the block sizes read as a MENU
       -&gt; 2^27 entries are needed for a 2 MiB block at L1
          and a table has 512, so a 48-bit regime cannot use it

  R14  100% two-reader agreement is the strongest evidence
       -&gt; it is not, and section 9B is the demonstration

  R15  the two-reader check establishes the decoder is correct
       -&gt; it establishes AGREEMENT; a corpus chosen to suit
          the decoder is the failure mode this course found

  R16  a 30-bit virtual address space is configurable
       -&gt; T0SZ is FIVE bits and 64-30 = 34 does not fit; the
          floor is 2^33 bytes
                </pre>
                </div>
                <p>Seven of those sixteen were asserted <em>before this course was written</em> — in <code>docs/aarch64-section-plan.md</code> or in the brief this course was built from — and the artifact prints the source next to each one, because a retraction with no prior source is a course disagreeing with itself. Three of the sixteen were found by this course's own measurements against a draft it had already written, and they say so rather than claiming a prior source.</p>
                <div class="hex-dump">
                <pre>  A course that reports ZERO retractions on a subject this
  size has either not looked or has not been reading the
  documents it cites.  16 retractions.
                </pre>
                </div>
                <h3>The limits, in the file's own words</h3>
                <p>Fifteen of them, and the first two decide what every other one may say:</p>
                <ul>
                    <li><strong>NOTHING IS EXECUTED.</strong> No machine, no emulator, no linker. Every figure is a bit pattern, a count of bit patterns, an arithmetic identity, or a refusal from a real assembler. No duration, no fault, no throughput, no portability claim.</li>
                    <li><strong>THERE ARE NO TIMINGS, AND THE x86-64 FIGURES ARE REFUSED BY NAME.</strong> 4.92&times; and 27.65&times; are <em>not reproduced in any form</em>, because there is no AArch64 clock and because faking a counterpart is worse than admitting the absence.</li>
                    <li><strong>NO EXCEPTION IS EVER TAKEN, NO INTERRUPT IS EVER TAKEN, NO MEMORY IS EVER ACCESSED.</strong> Three separate limits for the same reason, and each one names what is quoted and what is measured in its place.</li>
                    <li><strong>NO LINKER RUNS.</strong> So the relocation names and numbers are measured and what a linker <em>does</em> with them — including the <code>adrp</code>+<code>add</code> → <code>adr</code>+<code>nop</code> relaxation — is quoted.</li>
                    <li><strong>THE TWO READERS SHARE A SOURCE TREE.</strong> And there is no second AArch64 assembler, so every "refusal" in the file is a refusal by one assembler at one version.</li>
                    <li><strong>A COUNT OF UNMODELLED WORDS IS A FACT ABOUT A CORPUS.</strong> The R4 lesson, restated as a limit, because it is the one that keeps being forgotten.</li>
                    <li><strong>THE SPECIFICATIONS ARE AN ORACLE, NOT A MEASUREMENT.</strong> Quoting is not verifying, and the difference is printed wherever a claim depends on it.</li>
                    <li><strong>THE ARCHITECTURAL MANUAL WAS NOT CONSULTED ON THIS HOST.</strong> There is no copy of DDI 0597 or DDI 0601 here and the file does not pretend otherwise; the quotations carry document and section so they can be checked, and the absence of the document is a limit rather than a paraphrase.</li>
                    <li><strong>THE COMPILER AND THE ASSEMBLER ARE THE TEST SUBJECT, NOT THE ARCHITECTURE.</strong> Every instruction count and every refusal is a fact about clang 21.1.8. The harness asserts shapes and orderings, never values.</li>
                    <li><strong>A LINK-TIME ALIGNMENT IS NOT A LINK-TIME ERROR.</strong> Four alignment directives and zero diagnostics. <em>An absence does not get safer by being repeated.</em></li>
                </ul>
                <h2>What a reader therefore cannot conclude from this course</h2>
                <p>Printed in the artifact, not in a footnote, because a limit that is a footnote is a limit that gets forgotten. This list is the honest end of the course and it is not a formality:</p>
                <ul>
                    <li>That a syscall on this machine returns anything, because nothing here has been executed.</li>
                    <li>That <code>svc #0</code> traps, or to where, or that <code>x8</code> is read.</li>
                    <li>That the syscall numbers are right — they are quoted from a header file and no return value has confirmed one.</li>
                    <li>That an exception is ever delivered, or that the ESR field layout is right, or that the IL rule fires.</li>
                    <li>That a vector is ever entered, or that <code>VBAR</code> is honoured, or that the sixteen entries are in the quoted order.</li>
                    <li>That a page is ever walked, that a TLB ever hits, or that the descriptor format is right.</li>
                    <li>That any of this is <strong>faster or slower</strong> than anything on any other architecture. There are no timings in this course and none can be manufactured from it.</li>
                    <li>That the linker relaxes or does not relax an <code>ADRP</code>+<code>ADD</code> pair, because there is no AArch64 linker on this host.</li>
                    <li>That <code>llvm-objdump</code> agrees with the silicon. It does not have to: it is a second <em>reader</em>, and both readers come from one LLVM tree.</li>
                </ul>
                <h3>What a reader CAN conclude, and check, with a hex editor</h3>
                <ul>
                    <li>Every bit pattern in this course, in a file on this disk.</li>
                    <li>Every relocation name and number, in a file on this disk.</li>
                    <li>Every section alignment, read by two independent parsers.</li>
                    <li>Every instruction count, in a <code>.s</code> file on this disk.</li>
                    <li>Every refusal, by running the assembler.</li>
                    <li>The arithmetic: 16&nbsp;&times;&nbsp;0x80, 512&nbsp;&times;&nbsp;8, 2<sup>64−T<sub>n</sub>SZ</sup>, 2<sup>27</sup> entries.</li>
                    <li>The sixteen vector entries and the thirty-nine exception classes, which are quoted and carry their documents and their section numbers.</li>
                </ul>
                <p>That is the shape of a course with no hardware: <strong>a small set of claims you can check with a hex editor, and a large set you have to take on the word of a document — and an exact statement of which is which.</strong> A course with hardware would have the second set too, labelled MEASURED, and would be worth more for the parts that need it.</p>

            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Run the harness with no toolchain at all.</strong> <code>python3 courses/a64sys/assets/samples/crosscheck.py</code>. <em>(Expect 210/210 checks passed, with no assembler, no linker, no emulator and no network. The harness reads the committed <code>a64sys.out</code> rather than re-measuring, on purpose: a course whose claims can only be verified by first rebuilding its own artifact is a course whose claims are only verifiable on the machine that wrote them, which is the same mistake as quoting a remembered number wearing a different hat.)</em></li>
                    <li><strong>Do the poison yourself, and break a different guard the second time.</strong> Delete <code>m_sysreg</code> from the dispatch and re-run. <em>(Expect 1,459 named and 57 disagreements, all <code>mrs</code>/<code>msr</code>. Then delete <code>m_hint_family</code> instead and re-run: expect 1,391 named and 125 disagreements, and expect the 125 to include the eight hints from the R4 table. Two runs, two guards, two different numbers, and the difference between them is the seven hundred words those two guards together cover — which is a coverage measurement you made by breaking something rather than by reading a table.)</em></li>
                    <li><strong>Make a claim of your own and label it.</strong> Write down one fact you learned on the previous five pages and put one of the three labels on it, with the document or the command. <em>(Expect about half of them to be QUOTED if you are honest, and the exercise is worth doing because the half you get wrong will be the numbers, not the prose. A reader who mislabels a structural fact as measured has learned nothing wrong yet; a reader who mislabels a measured fact as quoted will go looking for a document that does not say it.)</em></li>
                    <li><strong>Find the corpus-dependent claim and check it against a different corpus.</strong> The coverage table on this page says the inherited decoder names 1,374 of 1,516 words <em>of this corpus</em>. Take a large real-world AArch64 binary, disassemble it, and count how many words this course's decoder names. <em>(Expect a much lower percentage, and expect the unmodelled ones to be Advanced SIMD and the floating-point families — which this course does not model and the <em>next</em> course in the section does. The generalisation is the one R4 is about: a coverage number is a number about a corpus, so the interesting experiment is always to change the corpus and see what moves.)</em></li>
                    <li><strong>Write the paragraph you wish this course had, and mark it UNKNOWN.</strong> Pick one thing this page says cannot be concluded — the page fault behaviour, the ADRP relaxation, the instruction length rule — and write the sentence you would need to publish it, along with the machine you would need. <em>(Expect the answer to be "an AArch64 board and four hours" for most of them, and expect the list of sentences to be shorter than you thought, because the course already measured everything a host without hardware can measure. That is the design: it is a course about a machine you cannot run, built the way a compiler author builds one — from the encoding outward, with the specification as the oracle and the compiler as the witness. The constraint is the subject, not a limitation of the teaching.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, all five, and specifically: <a href="/courses/a64sys/lessons/a64-pagetables">concept 5</a> is the one with the most measured content and therefore the one that most needs this page, because a page that is mostly measurements is exactly the page a reader is most likely to over-trust. <a href="/courses/a64sys/lessons/a64-interrupts">Concept 3</a> contributed the largest <em>absence</em> in the course and this page is where the habit of printing an absence lives. <a href="/courses/a64sys/lessons/a64-syscall">Concept 1</a> is where the two-labels rule was first needed, because a field in an instruction and a value in a register are different kinds of claim and both are in the same line of assembly.</p>
                <p>Sideways, the collection's own method. <a href="/courses/a64asm/lessons/a64-verify">The encoding course's cross-check</a> is the first application of the poison and it retracted its own 100% twice; <a href="/courses/a64abi/lessons/a64-unwind">the ABI course's unwinding concept</a> is the second; this is the third, and R4 — a bug in an inherited artifact that survived a whole course because the corpus did not contain the words it was wrong about — is the first time the method has found a defect in a <em>sibling course's</em> file. <a href="/courses/x86sys/lessons/x86-boundary">The x86-64 course's boundary concept</a> is the same idea applied to a course that <em>did</em> have hardware, and it proves an absence rather than asserting one — which is the harder case and the better precedent.</p>
                <p>Outward, and the general form is the one the whole section has been converging on for six courses. <strong>Every claim in a course should be classifiable as reproducible-by-a-command, readable-in-a-file, or attributable-to-a-paragraph — and a claim that is none of the three is a claim nobody should act on.</strong> That is not a rule about courses without hardware; it is a rule about all of them, and a course with hardware is simply better at the second category and no better at the first or the third. The AArch64 section's contribution is that it has been forced to be explicit, and the reader who takes the habit out of here will apply it to a machine they <em>can</em> run — where the temptation is to treat a duration as a mechanism, and where the discipline costs nothing and saves a week.</p>
                <p>And where this course ends. Sixteen retractions, fifteen limits, and a decoder with six models of its own that found a bug in its predecessor's and printed the arithmetic that killed a row in its own first draft. That is the whole of what a course about a machine you cannot run can honestly claim, and the two courses after this one in the section — the NEON register file and the weak memory model — are the ones where a reader should ask whether the same method would find as much, because the subject changes from <em>control</em> to <em>data</em> and the encodings get denser rather than sparser.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64sys/lessons/a64-pagetables">Four Levels, and Why a Page Needs a Pair of Relocations</a></span>
                <span>End of The AArch64 Machine: Modes, Memory and Faults &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
