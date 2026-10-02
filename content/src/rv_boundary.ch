// The RISC-V Privileged Architecture -- concept 4: the measured/quoted
// boundary, the sixteen limits, the two scope lists, and the seventeen
// retractions.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_rv_boundary() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What This Course Measured, and What It Refused To — Underlayer")
    page.appendTitle(&title)

    render_lesson_nav(&mut page)
    render_lesson_css(&mut page)

    #html {
        <div class="lesson rvpriv-concept">
            <a href="/courses/rvpriv" class="back-link">The RISC-V Privileged Architecture</a>
            <h1>What This Course Measured, and What It Refused To</h1>
            <div class="lesson-meta">24 min &middot; Concept 4 of 4 &middot; module: where the claim stops &middot; <a href="/courses/rvpriv">The RISC-V Privileged Architecture</a></div>

            <div class="unit unit-why">
                <h2>The ratio is the finding, so it is a table and not a disclaimer</h2>
                <p>Every claim in the first three pages carries one of three labels: <strong>MEASURED</strong> (about the compiler or the bytes, by experiment), <strong>MEASURED-ON-BYTES</strong> (a property of emitted bytes, cross-checked against a second reader), or <strong>QUOTED</strong> (a manual claim, with a document and a section). On most pages you would be forgiven for not noticing. This page prints all forty-four of them in one table, with the count &mdash; and <strong>the count is the finding</strong>.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -E 'rows: |PER CENT THE QUOTED'
  44 rows: 8 MEASURED, 13 MEASURED-ON-BYTES, 23 QUOTED.
  AT 52 PER CENT THE QUOTED THIRD IS A MAJORITY OF THIS COURSE'S CLAIMS
                </pre>
                </div>
                <p>This is the course in the whole collection where the quoted third is largest, and <strong>the reason is structural rather than a matter of care</strong>. A privileged architecture is a <em>document</em>. What a document says is not measurable on a host with no machine, and what <em>is</em> measurable &mdash; the encoding, the CSR address arithmetic, the relocation records, the size arithmetic &mdash; is the part a compiler author needs and the part a page-table writer needs. So the ratio is not an apology. It is a map of the subject.</p>
                <p>And the comparison with the nearest neighbour is printed <strong>both ways</strong>, because the honest number is unflattering to this course:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -A 1 'CUTS BOTH WAYS'
  THIS COURSE'S QUOTED FRACTION IS 52 PER CENT AND a64sys's IS 54 PER CENT,
  SO THE AARCH64 MACHINE COURSE'S QUOTED THIRD IS THE LARGER ONE AND A COURSE
  THAT CLAIMED OTHERWISE WOULD BE MAKING A NUMBER UP.
                </pre>
                </div>
                <p>The reason this course&rsquo;s is smaller is not that it depends less on a document. It is that there was <strong>more to measure</strong>: 21 of the 44 rows here are measured against <code>a64sys</code>&rsquo;s 26 of 57, and the extra measurements are the relocation <em>records</em>, the CSR <em>address</em> arithmetic and the twelve CSR instruction <em>encodings</em> &mdash; none of which <code>a64sys</code> had a reason to touch, because its subject is a descriptor format and a trap register rather than an object file.</p>
                <p>That is why the table is a table and not a percentage in a sentence. <strong>A percentage in a sentence is a number nobody can check.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>Sixteen limits, and the two that decide the other fourteen</h2>
                <p>The limits are printed in the artifact&rsquo;s own words, so that a reader who copies a number out of the file cannot lose the sentence that limits it. The first two decide what everything else is allowed to say, and they are worth reading twice because they are the reason this course is weaker than the two before it and more honest than either.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  1\. NO TIMING/,/^  3\./p'
  1. NO TIMING. No cycle, no latency, no throughput, no speedup, no ratio
     of anything a machine did. There is no RISC-V machine, no emulator and
     no RISC-V linker on this host, so every figure is a bit pattern, a
     count of bit patterns, an arithmetic identity, or a refusal from a
     real assembler. The x86-64 section measured a 4.92x and a 27.65x;
     those have NO COUNTERPART HERE AND ARE NOT INVENTED TO FILL THE GAP.
  2. NOTHING IS EXECUTED. Not one instruction in this course has run. A
     page-table walk in section 9 has never walked a page; it is a function
     that the compiler emitted and a disassembly that named it.
                </pre>
                </div>
                <p>Limit 1 is the one that will be tested. The x86-64 ABI course in this collection measured a <strong>4.92x</strong> and a <strong>27.65x</strong> on hardware it could run, and a reader who has just finished that course is looking for a ratio. The honest alternative to a ratio is not a smaller ratio &mdash; it is an instruction count, a byte count, a field width, and the sentence that a count does not know whether the instruction is fast. <strong>Those two numbers have no counterpart here and are not invented to fill the gap.</strong></p>
                <p>Limit 3 is six absences in one item, and each one is a separate thing this course would otherwise be able to say:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  3\. NO EXCEPTION/,/^  4\./p'
  3. NO EXCEPTION IS EVER TAKEN, NO INTERRUPT IS EVER TAKEN, NO PAGE FAULT
     IS EVER RAISED, NO TLB IS EVER CONSULTED AND NO ACCESS FAULT IS EVER
     RAISED. Six separate absences, and each one is a separate thing this
     course would otherwise be able to say.
                </pre>
                </div>
                <p>And limit 4 is the one that protects concept 3, quoted because it is the sentence a reader is most likely to lose:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  4\. THE ecall/,/^  5\./p'
  4. THE ecall CONVENTION IS MEASURED AS EMITTED, WHICH IS WEAKER. What is
     measured is that clang emits the constant 0x00000073 and that the
     convention's registers are a7 and a0. What is NOT measured is that the
     trap is taken, that it reaches supervisor mode, that a7 is read, that a
     kernel exists, or that anything comes back.
                </pre>
                </div>
                <h3>Eight things you cannot conclude, beside ten that they can</h3>
                <p>A list of limits says what <em>this file</em> declines to do. A list of what a reader <strong>therefore cannot conclude</strong> is a different thing, and it is the one that protects the reader rather than the file &mdash; because those are the sentences that would be <em>false</em> if you carried the sixteen promises in one direction rather than the other. It is printed beside the limits, not in a footnote, because a footnote is where a scope statement goes to be skipped.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/A LIST OF SIXTEEN LIMITS/,/THE OTHER HALF/p' | head -22
  A LIST OF SIXTEEN LIMITS says what this file declines to do.  A LIST OF WHAT A
  READER THEREFORE CANNOT CONCLUDE is a different thing ...

  * That a page is ever walked.  `walk.c` compiles to a function whose body
    is three `auipc`/`ld` pairs and whose name says walk.  No pointer is
    dereferenced, no PPN is translated, and `priv-spec` section 11.1.4 is
    quoted rather than performed.
  * That an `ecall` traps.  What is measured is the constant 0x00000073 and
    the register a7 around it.  Whether the trap is taken, whether control
    reaches supervisor mode, and whether anything returns are four separate
    questions and none of them has been asked of a machine.
  * That writing `mtvec` from S-mode raises an illegal-instruction
    exception.  The privilege bits of the CSR address are measured as
    NUMBERS.  The rule that turns the numbers into an exception is quoted,
    and there is no S-mode here to be refused by.
                </pre>
                </div>
                <p>And here is the other half, because a course that prints only a cannot-list teaches its reader that the subject is unknowable &mdash; which is the opposite of what fourteen sections of measured bits are for:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE OTHER HALF/,/THE POINT/p' | head -20
  * Every bit pattern in this course is byte-for-byte reproducible from the
    files in this directory and the exact clang invocation section 1 prints.
  * Every relocation NAME and NUMBER this course uses appears in the psABI
    table AND in the object files of the corpus.  Names are a convention;
    numbers are a fact, and both were read rather than remembered.
  * Every refusal, by running the assembler.  0x1000, 0x20 and the rest are
    the assembler's own words, quoted verbatim, not this file's summary of
    what it probably said.
  * The size arithmetic, exactly: 4096 / 8 = 512, 3 x 9 + 12 = 39,
    64 - 4 - 16 - 8 = 36, 2048 - 1 = 2047.  Four identities, each one
    load-bearing for a field width, each one checkable with a pencil.
                </pre>
                </div>
                <div class="callout callout-note">
                    <p><strong>Eight against ten, and the second list being the longer one is the point.</strong> There is more that can be read off bytes than there is that can be said about behaviour. A reader who finishes this course able to state the second list precisely and the first list vaguely <strong>has it exactly backwards</strong>.</p>
                </div>
                <p>Both lists are <strong>pinned whole, sentence by sentence, by the harness</strong> &mdash; eighteen needles in all. That is not fussiness. The substring checks that a normal harness would use all pass over a bullet edited from &ldquo;That a page is ever walked&rdquo; to &ldquo;That a page is walked, always&rdquo;: the sentence still contains the subject and the verb, and the edit reverses the meaning without touching a word any check was written against. <strong>A scope list you can soften without editing a test is not a scope list.</strong> The intended cost of pinning is that a reworded claim has to be re-argued in the harness too.</p>
                <h3>Seventeen retractions, and two that are not about the reader</h3>
                <p>Every one of the seventeen was asserted in a draft of this course or in the plan it was written from, measured, and withdrawn. They are printed in full rather than footnoted, and a separate harness asserts their <em>text</em> &mdash; because that is the only mechanism that has ever stopped a retraction being quietly dropped.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/^  R17  CLAIMED/,+3p'
  R17  CLAIMED: the first correction to R16 named that register `rd`
        SOURCE: this course's own first CORRECTION to R16 -- the value was
        right and the field name was not
         there is no rd in an S-TYPE word at all, and the number was right while
                the NAME was wrong. A store has no destination register, so its
                inst[24:20] is rs2 ...
                </pre>
                </div>
                <p>R17 is the one worth reading twice, because it is a retraction <em>of a correction</em>. The first version of the immediate table read <code>inst[31:20]</code> out of an S-type store and printed <code>0x006</code>, where an immediate should be &mdash; a store&rsquo;s immediate is split across <code>inst[31:25]</code> and <code>inst[11:7]</code>. That became R16. Then the first <em>fix</em> explained the <code>0x006</code> as the destination register &mdash; and a store has no destination register. The number was right; the <strong>name</strong> was wrong, and that is worse in one specific way: a wrong value is caught by the next comparison, a wrong field name is not, and it gets copied.</p>
                <div class="callout callout-note">
                    <p><strong>Its lesson generalises past this architecture, which is why it is printed with the rest.</strong> The artifact&rsquo;s sentence for it: <em>a number you can name is not yet a field, and naming it after a field that is not in the word is the same error with a different spelling.</em> The table now prints <code>inst[11:7]</code> and <code>inst[24:20]</code> as two <em>unnamed</em> columns and prints the arithmetic that turns one into the other, so you are shown <strong>which bits</strong> rather than told <strong>which field</strong> they are.</p>
                </div>
                <p>Eleven of the seventeen are about a reader, an instrument or an experiment; six are about a comparison. But two are not about the reader at all, and they are worth naming because a list that is uniformly one thing is a list nobody read:</p>
                <ul>
                    <li><strong>R10:</strong> this course cannot say what a trap, a page fault or a syscall <em>does</em>. That is not a limitation section; it is stated in the file&rsquo;s header, in section 1, at the end of every affected section, and in the table above.</li>
                    <li><strong>R14:</strong> the defect is in a <strong>sibling&rsquo;s</strong> decoder, not in this file&rsquo;s. The inherited decoder <em>declines</em> any SYSTEM word whose <code>rd</code> or <code>rs1</code> is non-zero, because the only two it knew were <code>ecall</code> and <code>ebreak</code> &mdash; so it cannot name <code>SFENCE.VMA</code> at all. The first run of the cross-check reported twelve of them as disagreements, and a reader would have had to work out that a decoder printing <code>(undefined)</code> is claiming the architecture defines no meaning for a word the architecture defines precisely.</li>
                </ul>
                <p><strong>A retraction that admits a whole section is uncleared is not a retraction</strong>, it is a course that has decided it is being careful. And the one that admits the defect is elsewhere is the one that keeps the other courses honest.</p>
                <p>The claim that ties the list together is at the end of it, and it is the most interesting thing on the page:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | grep -B 1 -A 3 'NOTHING HERE IS A MISTAKE'
  NOTHING HERE IS A MISTAKE ABOUT HOW A COMPUTER WORKS.  That is seventeen
  courses in a row, and it is the most interesting thing about the list.  The
  RISC-V privileged architecture did not surprise this course once.  What
  surprised it was a mask two registers wide, a pseudo-instruction whose
  letter does not mean what it says, an assembler that enforces nothing, and
  its own dead-code elimination reported as a calling convention.
                </pre>
                </div>
                <p>Seventeen courses in a row, and not one of the retractions is a discovery about the hardware. <strong>Every single one is a discovery about the machinery built to read the hardware.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>The two readers, and the four poisons</h2>
                <p>The last mechanical question is whether the decoder that produced these numbers is right. It is checked by a second reader &mdash; <code>llvm-objdump-21</code> &mdash; against this file&rsquo;s own decoder, over the whole corpus.</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/instructions the second reader printed/,/DISAGREE/p'
  11214  instructions the second reader printed, and this file compared
  11065  of them this file NAMES
  149  unmodelled -- counted, never dropped
  0  where the two readers disagree on the LENGTH

  0  DISAGREE
                </pre>
                </div>
                <p>Eleven thousand two hundred and fourteen instructions, eleven thousand and sixty-five named, a hundred and forty-nine unmodelled and <em>counted rather than dropped</em>, and <strong>zero disagreements</strong>. The length column is separate and not a subset, because RISC-V&rsquo;s two-byte instructions make it a real question.</p>
                <p>And the unmodelled column is printed beside the disagreement column rather than in a footnote, for a reason the poison table then proves:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/FOUR POISONS, FOUR CLAIMED/,+9p'
  FOUR POISONS, FOUR CLAIMED NUMBERS, FOUR NON-ZERO DELTAS:

  * poison 1 claims the NAMED, the DISAGREE and the UNMODELLED counts, and
            moved them by +146, +141 and -146
  * poison 2 claims the RELOCATION NAME count, and moved it by 104 names lost
    and 5 wrongly named
  * poison 3 claims the INSTRUCTION COUNT,   and moved it by -5281
  * poison 4 claims the VISIBILITY of the check, and hid 639 of 10797
                </pre>
                </div>
                <p>Poison 1 is the one worth reading twice, because it moves <strong>three</strong> numbers and two of them go in <em>opposite directions</em>. Remove the two prepended models and 146 words stop being named, 141 new disagreements appear, and 146 words stop being unmodelled &mdash; the words stopped being holes and became wrong, which is two different failures with one cause. A check that watched only the disagreement count would have seen +141 and called it <strong>progress</strong>. It is the reverse of progress.</p>
                <div class="callout callout-note">
                    <p><strong>Poison 4 is the one that makes the other three meaningful.</strong> The cross-check is planted with 10,797 real disagreements and then asked how many it catches. The working check catches 10,797 of 10,797. A deliberately broken one catches 10,158 and <strong>hides 639</strong> &mdash; which is the number a reader should care about, because 639 is the class of bug that reads as success. <strong>A cross-check that agrees is not proof, and this is the reason: the only way to know whether a cross-check can fail is to make it fail on purpose.</strong></p>
                </div>
                <p>One more discipline is visible in the run, and it is the reason the file prints machinery whether or not it has anything to print. The two normalisation rules are <strong>pre-seeded</strong> into the fire table, so a rule that never fires is a row with a zero rather than an absence, and the disagreement classifier is in the main path rather than in the failure branch, so a run where it finds nothing is visibly a run where it <em>ran</em> and found nothing:</p>
                <div class="hex-dump">
                <pre>$ python3 rvpriv.py --run | sed -n '/THE FIRE TABLE/,/matched nothing/p'
    negative immediate, decimal on both sides fired 314 times
    c.li and li are one instruction fired 44 times

    2 rules, 2 fired, 0 matched nothing
                </pre>
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>What this course owes its neighbours</h2>
                <p>Nothing here is re-taught. Every link was verified present before it was written, and the list is in the artifact in full so a reader can check it.</p>
                <div class="hex-dump">
                <pre>  why privilege exists and what a ring is
      /courses/priv/lessons/priv-vectors  /courses/priv/lessons/priv-doors
  the syscall convention in the neutral terms
      /courses/priv/lessons/priv-convention
  what a page table is and why the levels exist
      /courses/mem/lessons/mem-translation
  the same subject on the two machines this collection can run
      /courses/x86sys/lessons/x86-syscall  /courses/x86sys/lessons/x86-rings
      /courses/x86sys/lessons/x86-paging   /courses/a64sys/lessons/a64-syscall
      /courses/a64sys/lessons/a64-pagetables
  what a relocation record IS, and the two halves of the object-file story
      /courses/obj/lessons/obj-relocations /courses/reloc/lessons/reloc-why-so-many
  the `auipc` immediates, measured by the first RISC-V course
      /courses/rvasm/lessons/rv-immediate
  what a linker does with a pair once it has one
      /courses/rvabi/lessons/rv-calling
                </pre>
                </div>
                <p><strong>The one overlap worth naming</strong> is <a href="/courses/rvasm/lessons/rv-isa"><code>rvasm</code>&rsquo;s <code>rv-isa</code></a>, which measured the <code>Tag_RISCV_arch</code> string across eight <code>-march</code> settings. Concept 1 re-measures it for a different reason &mdash; not &ldquo;what does the string contain&rdquo; but &ldquo;does the toolchain agree with itself&rdquo; &mdash; and the finding is the opposite of that course&rsquo;s. <code>rv-isa</code> showed the string is rich; this course shows it is a record of the request. <strong>Two courses reading the same field and concluding opposite things is a good sign, and it is why both pages exist.</strong></p>
                <p>The other structural thing this course did, and it is a decision worth copying: <strong>the decoder is borrowed, not forked.</strong> It comes from <code>rvasm</code>&rsquo;s <code>rvdec.py</code>, this course prepends exactly two models and edits no sibling. Two harnesses that both pass while reading different code is the failure mode this collection keeps paying for, and the honest cost of the choice is that one of this course&rsquo;s retractions (R14) is about a defect in the other course&rsquo;s code.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Try it</h2>
                <ol>
                    <li><strong>Break the cross-check and watch the delta name itself.</strong> <em>(Find <code>_m_sfence_vma</code> in <code>rvpriv.py</code> and remove it from the dispatch. Re-run. Expect poison 1 to report three moved numbers where two move in opposite directions, and expect the poison&rsquo;s own verdict to be <code>FIRED</code> rather than <code>[POISON FAILED]</code> &mdash; because a poison whose victim has no corpus footprint cannot move a number, and that is a <em>different bug</em> from one that fails to move. Try naming a model that does not exist and watch it say so.)</em></li>
                    <li><strong>Read a retraction as a bug report against a reader.</strong> <em>(Take R12: the two readers&rsquo; disagreement count was being read as a measure of the decoder&rsquo;s correctness, and the kind of disagreement this corpus produced turned out to be a <em>spelling</em> difference &mdash; <code>c.li a2, -1</code> against <code>li a2, -0x1</code>, the same value in two encodings printed two ways. Ten such words were counted as disagreements until two normalisation rules brought both sides to one spelling. Now ask the general question: <strong>in your own cross-checks, how would you tell a spelling difference from a misread?</strong> If the honest answer is &ldquo;I would not&rdquo;, that is the bug.)</em></li>
                    <li><strong>Add a claim to the can-list and then try to soften it.</strong> <em>(Copy one of the ten sentences, change it so it says slightly more than the course measured, and run <code>python3 crosscheck.py</code>. It will fail, on the pinned sentence. That failure is the design working: <strong>a scope claim you can widen without editing a test is not a claim, it is a mood.</strong> Now edit the harness too and notice what you have to write down in order to justify the change.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This page is the course&rsquo;s dependency graph, and there is one thing about it worth saying out loud: <strong>the course that measured the most bytes is the course with the least to say about behaviour</strong>, and the second measurement &mdash; 52 per cent of its claims are quotations &mdash; is not a quality score. It is a fact about the subject. <a href="/courses/a64sys/lessons/a64-evidence"><code>a64-evidence</code></a> is the sibling table with the same shape and a slightly different ratio, and reading the two side by side is the fastest way to understand why that ratio moves with the subject rather than with the author.</p>
                <p>Forwards out of the whole RISC-V section, what this course hands to the next architecture is not an instruction but a habit. <strong>When a specification says a field is reserved, ask what the compiler does with the value, and then ask what the hardware does with the result</strong> &mdash; because on RISC-V the second question has a real answer this host cannot reach, and the gap between the two answers is exactly where privileged code goes wrong. The <code>stvec</code> mode is the smallest complete example: one ordinary instruction, three different functions, and the difference living four instructions earlier where no tool will ever look at it.</p>
                <p>And the harness is the last thing this course hands back. <a href="/courses/rvasm/lessons/rv-verify"><code>rv-verify</code></a> is where the two-reader discipline was built and this course borrowed it; the two models prepended here are why <em>that</em> page&rsquo;s decoder could not name <code>SFENCE.VMA</code> and this one can. A decoder shared across courses and extended per course is a design choice with a cost, and R14 is the invoice &mdash; published rather than quietly patched in a sibling, because a course that edits its neighbour&rsquo;s code to make its own numbers work is a course whose numbers are not measurements any more.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/rvpriv/lessons/rv-traps">ecall, the Five Registers, and Why the Mode Is Not in the Instruction</a></span>
                <span>Next: <a href="/courses/rvpriv">Back to the course</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}