// The AArch64 Machine: Modes, Memory and Faults -- course landing page.
//
// The landing page's job, as in a64abi, is to lead with the CORRECTIONS rather
// than with a summary, because a course that leads with its own corrections
// teaches a reader that its uncorrected numbers are probably not worth much
// either.  Four of the sixteen retractions are quoted here and all sixteen are
// linked.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64sys_landing() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The AArch64 Machine: Modes, Memory and Faults — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson a64sys-landing">
            <a href="/courses" class="back-link">All courses</a>
            <h1>The AArch64 Machine: Modes, Memory and Faults</h1>
            <div class="lesson-meta">6 concepts &middot; 2 modules &middot; 150 min &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>What this course is about</h2>
            <p>The machine underneath <a href="/courses/a64abi">the procedure call standard</a> and <a href="/courses/a64asm">the encoding</a>: how a program at EL0 asks for something, what happens when the machine says no, where it goes when it is interrupted, and how the thing that maps one address onto another reaches the memory system. Five subjects, one constraint that inverts the method of the whole x86-64 section: <strong>there is no AArch64 machine, no AArch64 emulator and no AArch64 linker on the host that wrote this course</strong>, so not one instruction in it has been run and there is not a single timing in it.</p>
            <p>That is not a smaller course. It is a course about the parts of a machine that are <em>contracts</em> rather than <em>behaviour</em> — and a contract, by definition, is checkable without executing anything. Every number here is a bit pattern, a count of bit patterns, an arithmetic identity over a field width, or a refusal from a real assembler, and every one of them carries one of three labels: <span class="label label-measured">MEASURED</span>, <span class="label label-bytes">MEASURED-ON-BYTES</span>, or <span class="label label-quoted">QUOTED</span>. <a href="/courses/a64sys/lessons/a64-evidence">Concept 6</a> prints all fifty-seven claims with their labels, and the ratio is the finding: <strong>31 QUOTED against 26 measured</strong>, because the subject is a machine and the machine is the one thing this host does not have.</p>
            <p>What exists elsewhere in this collection is a set of neighbours that each own one edge of this subject and none of them own the middle. <a href="/courses/priv/lessons/priv-vectors">The neutral course owns the vector model</a> — what an exception <em>is</em> — and <a href="/courses/priv/lessons/priv-doors">its privilege concept</a> owns what EL0 and EL1 mean. <a href="/courses/mem/lessons/mem-translation">The paging course</a> owns the walk as a mechanism. <a href="/courses/x86sys">The x86-64 machine course</a> is the exhaustive reference for the same five subjects on the other architecture, and this course owes the AArch64 half and does not repeat a principle. And <a href="/courses/obj/lessons/obj-relocations">the object-file course</a> plus <a href="/courses/link/lessons/link-script-language">the linker-script concept</a> own the two mechanisms that concept 5 is a hinge between.</p>
            <p>So this course is the exhaustive AArch64 reference for the thing underneath all of those, and it is the one course in the section whose distinctive idea is not about a data path at all: <strong>it is about the instructions that are one bit apart from each other.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The idea this course is built on</h2>
            <p>Fixed-width 32-bit encoding, a privileged register file, a table of branches at a computed address, and an array of 64-bit words that has to live somewhere specific. The first three are <em>control</em> and the fourth is <em>data</em>, and the difference shows up in what can be measured about them: a control structure is a <strong>bit pattern in an instruction you can decode</strong>, and a data structure is a <strong>number in a section header nothing in the toolchain checks</strong>.</p>
            <p>That is the course in one sentence, and here is the shape of the result:</p>
            <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 3 | sed -n '/what each course/,/^$/p'
  [MEASURED] what each course's models contribute to THIS corpus
     dispatch                                read  named  coverage
     the encoding course's 21 alone        1516   1374   90.6%
     + the ABI course's 6                 1516   1385   91.4%
     + this course's 6                    1516   1516  100.0%

  [RESULT]           the encoding course names 1374 of 1516 of this corpus
                     (90.6%), and the two later courses add 11 and 131
                </pre>
            </div>
            <p>A coverage number means nothing on its own — it is a number about a corpus. So the same loop is run three times with three different <em>sets</em> of models, and the differences are printed. That is what turns "100% named" from a boast into a number, and it is the argument for the whole method: <strong>a decoder is a subset of NAMES and not of LENGTHS</strong>, and a course that inherits a decoder inherits a subset without inheriting a measure of it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>Four things this course got wrong first, and why that is the reason to read it</h2>
            <p>The section plan for this course made claims. Some were right, some were right about a fact and wrong about a reason, and one was a bug in a file this course inherited. All four of the ones below are printed at the point on the page where the measurement killed them, and all sixteen retractions are in the artifact's section 11 with a source beside each.</p>
            <ul>
                <li><strong>A page needs a PAIR of relocations per page because the <code>adrp</code> reach is 4&nbsp;GiB.</strong> The reach is 4&nbsp;GiB and it is <em>irrelevant</em>. The pair exists because <code>ADRP</code> computes <code>(page(target) − page(pc)) &gt;&gt; 12</code> into a 21-bit field, so <strong>the low twelve bits of the target are masked off</strong> and a second instruction with its own relocation has to add them back. The evidence that the reach is irrelevant is on the same page: the target is <em>four bytes away</em>. <strong>The pair is a masking problem, not a range problem.</strong> <a href="/courses/a64sys/lessons/a64-pagetables">Concept 5</a> measures all eight relocations in a corpus that names a page table five different ways.</li>
                <li><strong><code>x8</code> is the syscall-number register, so a compiler must treat it as reserved.</strong> clang uses <code>x8</code> as an ordinary scratch register in every one of the four functions that do not mention it, at every one of the four optimisation levels — including inside the same function that later issues <code>svc #0</code>. <strong>The convention is ABI and the compiler has never heard of it</strong>, which is exactly the distinction concept 1 is for. <a href="/courses/a64sys/lessons/a64-syscall">Concept 1</a> audits 111 of 111 argument placements at three levels — and finds that at <code>-O0</code> the contract is not visible in the code at all.</li>
                <li><strong>The syndrome is a 32-bit field with three parts.</strong> True, and incomplete in a way that bites: <code>ESR_ELx</code> is a <em>64-bit</em> register, bits 55:32 are named <code>ISS2</code>, and a handler that masks <code>0xffffffff</code> has thrown away the field an SError handler needs. <a href="/courses/a64sys/lessons/a64-exceptions">Concept 2</a> prints the layout with its document and measures the three-instruction test the compiler emits for the two commonest Data Abort classes.</li>
                <li><strong>And a real bug, in a file this course inherited.</strong> The encoding course's decoder has a model whose claim is "NOP, WFI, YIELD and the rest" and whose guard is one bit too narrow, so it names <strong>one of the eleven hints the assembler accepts</strong>. It survived a whole course because that course's corpus contains no <code>yield</code>, no <code>wfe</code>, no <code>wfi</code> and no <code>sev</code>: <em>a count of unmodelled words is a fact about A CORPUS and not about A DECODER</em>, and the second reader cannot help because <code>llvm-objdump</code> also prints <code>(op 0x...)</code> for a word no rule claims. <a href="/courses/a64sys/lessons/a64-evidence">Concept 6</a> prints the table.</li>
            </ul>
            <p>A course that reports zero retractions on a subject this size has either not looked or has not been reading the documents it cites. <strong>This one reports sixteen</strong>, and the harness asserts the text of all sixteen so that a retraction can be neither quietly dropped nor edited into being right.</p>
            </div>

            <div class="unit unit-example">
                <h2>Five results that are arithmetic rather than durations</h2>
            <p>Where a stopwatch would have given a number, a count gives a fact, and a fact does not move between runs. Every one of these is reproducible with one command and checkable in a file on this disk.</p>
            <ul>
                <li><strong>The vector table is 16 × 0x80 = 0x800, and the assembler measured it.</strong> All sixteen offsets, 0x800 through 0xf80, from the symbol table rather than from a formula I typed in. And the largest result in the concept is an <strong>absence</strong>: four different alignment directives and <em>four times no diagnostic</em>, because a misaligned table is not an error, it is a jump to the wrong address. <a href="/courses/a64sys/lessons/a64-interrupts">Concept 3</a>.</li>
                <li><strong>One 2&nbsp;MiB page table makes the whole of <code>.bss</code> 2&nbsp;MiB-aligned.</strong> 0x200000 from both readers with it, 0x1000 without, and the only difference between the two objects is one <code>__attribute__((aligned(0x200000)))</code> on one array. <strong>Same types, same code, one attribute, and it is the only channel through which a page table tells a linker what it is.</strong> <a href="/courses/a64sys/lessons/a64-pagetables">Concept 5</a>.</li>
                <li><strong><code>T0SZ</code> is a five-bit field, and the floor is 2<sup>33</sup> bytes.</strong> <code>T0SZ = 64 − 48 = 16</code> and <code>64 − 52 = 12</code> are the numbers the section plan gave and all three are right — but the first draft of this course's own regime table had a <em>30-bit configuration row</em> in it, and the same arithmetic on the row below killed it: <code>64 − 30 = 34</code> does not fit in five bits. <a href="/courses/a64sys/lessons/a64-virtual">Concept 4</a>.</li>
                <li><strong><code>ADR</code> reaches 0xffffc bytes and the assembler refuses 0x100000.</strong> Exactly a 21-bit signed field, found by asking the assembler to draw the boundary. <code>ADRP</code> reaches 4&nbsp;GiB and that number is <em>not</em> measured, because the assembler does not check it and the linker does not exist here. <a href="/courses/a64sys/lessons/a64-virtual">Concept 4</a>.</li>
                <li><strong>And a count of zero that is also a rule.</strong> <code>ESR_EL0</code>, <code>ELR_EL0</code>, <code>FAR_EL0</code>, <code>VBAR_EL0</code>, <code>TCR_EL0</code>, <code>TTBR0_EL0</code> and <code>SCTLR_EL0</code> do not exist, and the assembler refuses all seven with one diagnostic. <a href="/courses/a64sys/lessons/a64-exceptions">Concept 2</a>.</li>
            </ul>
            <p>And one thing the course does <em>not</em> claim anywhere: any comparison of speed. <a href="/courses/x86sys">The x86-64 section</a> measured a 4.92&times; and a 27.65&times;, and this course has no counterpart for either number, because there is no AArch64 clock on this host to read one with. <strong>A fabricated ratio is worse than an admitted absence</strong>, and the one cross-architecture comparison here — section 4's instruction and relocation counts — says in that section's own words that it is a compile-time comparison and not a timing one.</p>
            </div>

            <div class="unit unit-apply">
                <h2>What this course will not claim, and what is deferred</h2>
            <p>Printed in the artifact's own limits block — fifteen of them — rather than footnoted, because a limit that is a footnote is a limit that gets forgotten. The first two decide what every other row may say.</p>
            <ul>
                <li><strong>Nothing is executed.</strong> No machine, no emulator, no linker. Every figure is a bit pattern, a count, an identity, or a refusal.</li>
                <li><strong>No timings, and the x86-64 figures are refused by name.</strong> Nothing here is a duration, a fault, a throughput or a portability claim.</li>
                <li><strong>No exception, no interrupt, and no memory access ever happens.</strong> The layouts are quoted with document and section; the encodings, the counts, the alignment and the relocations are measured.</li>
                <li><strong>No linker runs.</strong> Relocation names and numbers are measured; what a linker <em>does</em> with them, including the <code>adrp</code>+<code>add</code> → <code>adr</code>+<code>nop</code> relaxation, is quoted.</li>
                <li><strong>Both readers come from one LLVM tree, and there is no second AArch64 assembler.</strong> Every "refusal" in the course is a refusal by <code>clang 21.1.8</code>'s integrated assembler and by nothing else.</li>
                <li><strong>The architectural manual was not consulted on this host.</strong> There is no copy of DDI 0597 or DDI 0601 here and the artifact does not pretend otherwise; the quotations carry document and section so they can be checked, and the absence of the document is listed as a limit rather than papered over with a paraphrase.</li>
            </ul>
            <p>The completion criterion is not "read it". It is: <em>reproduce the 210 checks against the shipped <code>a64sys.out</code> — which needs no toolchain at all — then change one guard in <code>a64sys.py</code>, any guard, and make the poisoned cross-check in section 9B move by name: the named count must fall from 1516 to 1459 and the disagreement count must rise from 0 to 57.</em> A check that has never been seen to fail is a check with no reason to be believed, and <strong>this course's cross-check found a real bug in the file it inherited</strong> before it found a way to report its own.</p>
            </div>

            <div class="unit unit-connect">
                <h2>What comes before, and what comes next</h2>
            <p>Before. <a href="/courses/a64asm">The AArch64 encoding course</a> is the direct prerequisite, and this course's artifact <strong>imports its decoder</strong> and prepends six models to it, because the SYSTEM class is exactly what the encoding course declared out of scope — and concept 3 is about a bug in that decoder's HINT guard. <a href="/courses/a64abi">The AArch64 ABI course</a> is the second prerequisite, and its six models are imported too rather than rewritten: a course that fixes a sibling's artifact by writing to it produces two artifacts that disagree about the same architecture, and a reader cannot tell which to believe. <a href="/courses/x86sys">The x86-64 machine course</a> is the sibling reference for all five subjects.</p>
            <p>Forward, and the practical weight is in a compiler backend. <strong>The two things a backend must get exactly right on this machine are the two nothing reports.</strong> A page table that is not 2&nbsp;MiB aligned, and a vector table that is not 2&nbsp;KiB aligned: both assemble, both link, both produce an object file whose only warning is the one in the section header, and both fail on the first exception the system takes. Neither produces a diagnostic, and the whole of concept 5's measurement is the shape of that silence.</p>
            <p>Outward, and the collection's shape is the argument. <a href="/courses/a64asm/lessons/a64-verify">The encoding course's two-reader cross-check</a> is the same experiment on a decoder and it retracted its own 100% twice; <a href="/courses/a64abi/lessons/a64-unwind">the ABI course's unwinding concept</a> is the same method applied to a compiler and it retracted a CFI row count its own brief had predicted. This is the third, and the first to find a defect in a <em>sibling course's</em> file. The next course in this section is the NEON register file, where the encodings get <em>denser</em> rather than sparser, and a reader who has finished this one should ask whether the same method will find as much.</p>
            </div>

            <div class="lesson-footer">
                <span>Start: <a href="/courses/a64sys/lessons/a64-syscall">SVC #imm16, and x8 Is a Convention and Not an Architecture</a></span>
                <span>End of The AArch64 Machine: Modes, Memory and Faults &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
