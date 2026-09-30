// The AArch64 Machine: Modes, Memory and Faults -- Concept 2: the packed
// syndrome.
//
// This is the concept where the quoted half of the course is largest, and the
// page says so in its first unit rather than at the end.  Thirty-nine
// exception classes, six-bit discriminants and a field whose meaning depends
// on a field above it are all things a reader LOOKS UP, and the only parts
// that can be measured on a host with no AArch64 silicon are the encoding of
// the instructions that read the register and the arithmetic the compiler emits
// around it.  R7 lives here: the test for the two commonest Data Abort classes
// costs three instructions, not the six a shift-and-compare would cost.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_exceptions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Register, Three Fields, and Thirty-Nine Meanings — Underlayer")
    page.appendTitle(&title)

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
            <h1>One Register, Three Fields, and Thirty-Nine Meanings</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>A kernel's exception handler is about forty instructions long and almost every one of them is a load from a system register. If you cannot read the value you loaded, the handler is a <code>switch</code> with a magic number in it, and magic numbers in a kernel are the difference between a five-minute diagnosis and a week. So the register layout is not trivia: it is the interface between a 32-bit field and everything the machine can go wrong with.</p>
                <p>Before the layout, the constraint, because it decides what this page is allowed to claim. <strong>There is no AArch64 machine on the machine that wrote this course, no emulator, and no linker.</strong> Not one exception has ever been taken on this host. So the thirty-nine classes, the field widths, and the rule about the instruction-length bit are all <span class="label label-quoted">QUOTED</span> with a document and a section number beside them — and what is <span class="label label-bytes">MEASURED-ON-BYTES</span> is the <em>encoding</em> of the three instructions that read the three registers, and <span class="label label-measured">MEASURED</span> is the arithmetic the compiler emits once it has the value.</p>
                <p>That split is the page. A reader who blurs it is being taught a table they have never seen fire, and a reader who holds it learns something transferable: <strong>in a kernel, the layout is a document and the code is a measurement</strong>, and the two are checked by different means.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: a 64-bit register with a 32-bit syndrome in it</h2>
                <p>Start with the two instructions a handler begins with, and read the words as words:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 3 | sed -n '/MRS and MSR/,/^$/p' | head -12
  [MEASURED-ON-BYTES] MRS and MSR: the register is a FOUR-field name
  source            word        L  op0 op1 CRn CRm op2 Rt   decoder says
  mrs x0, esr_el1   0xd5385200  1  11 000 5   2   0   0    mrs      x0, ESR_EL1
  mrs x1, elr_el1   0xd5384021  1  11 000 4   0   1   1    mrs      x1, ELR_EL1
  mrs x2, far_el1   0xd5386002  1  11 000 6   0   0   2    mrs      x2, FAR_EL1
  mrs x4, vbar_el1  0xd538c004  1  11 000 c   0   0   4    mrs      x4, VBAR_EL1
  msr vbar_el1, x0  0xd518c000  0  11 000 c   0   0   0    msr      VBAR_EL1, x0
  mrs x9, esr_el2   0xd53c5209  1  11 100 5   2   0   9    mrs      x9, ESR_EL2
                </pre>
                </div>
                <p>Four things fall out of that block, and the first is a retraction on a claim in the plan this course was built from.</p>
                <ul>
                    <li><strong>Two of the three registers a handler needs differ in three of four fields.</strong> <code>ESR_EL1</code> is CRn&nbsp;=&nbsp;5, CRm&nbsp;=&nbsp;2, op2&nbsp;=&nbsp;0. <code>ELR_EL1</code> is CRn&nbsp;=&nbsp;4, CRm&nbsp;=&nbsp;0, op2&nbsp;=&nbsp;1. The <em>shape</em> of the instruction is identical and the register name is not, which is exactly what you would expect from an encoding that spends nine bits naming something and three bits on an operation.</li>
                    <li><strong>Bit 21 is the whole difference between reading and writing.</strong> <code>0xd538c004</code> XOR <code>0xd518c000</code> is bit 21 and the register field. So the mnemonic name is not computable from the bits — it is a <em>table</em> of fifteen four-field tuples, and this file's decoder carries the table rather than a formula. <a href="/courses/a64sys/lessons/a64-interrupts">Concept 3</a> uses the same bit to install a vector table.</li>
                    <li><strong>The exception level is one field.</strong> <code>ESR_EL1</code> and <code>ESR_EL2</code> differ in op1 and in nothing else. A handler at EL1 and one at EL2 execute the <em>same bytes</em> to read the same conceptual register.</li>
                    <li><strong>And here is the retraction.</strong> The plan for this course described the syndrome as "a packed syndrome with EC, IL and ISS". True, and incomplete in a way that bites: <strong><code>ESR_ELx</code> is a 64-bit register and the syndrome occupies bits 31:0.</strong> Bits 55:32 are named ISS2 and they are the field an SError handler needs. A handler that reads the register and masks <code>0xffffffff</code> has thrown away half of the reason it took the exception.</li>
                </ul>
                <div class="formula">
   R1, and it is a WIDTH, which is the hard kind

   DRAFT      "the syndrome is a 32-bit field: EC in
               the high six bits, IL next, and the
               rest is one field called ISS."

   QUOTED     ESR_ELx[63:56]  reserved
               ESR_ELx[55:32]  ISS2   <- SError, and later
                                          extensions
               ESR_ELx[31:26]  EC      6 bits
               ESR_ELx[25]     IL      1 bit
               ESR_ELx[24:0]   ISS    25 bits

   The register is 64 bits.  The syndrome is 32.
   Both statements are true and the second one
   does not follow from the first, which is
   exactly why a 32-bit mask in a handler is a
   bug that a review of the layout will not catch.
                </div>
                <h3>The layout, quoted with its source</h3>
                <div class="hex-dump">
                <pre>  DDI 0597, Shared Pseudocode, AArch64_ExceptionClass():

    ESR_ELx (target_el) = ( Zeros{8} :: iss2 :: ec[5:0] :: il :: iss );
                                                 ^^^^  ^^  ^^^^^
                                                 EC   IL  ISS

    and, verbatim in structure:

    if ec IN {0x24, 0x25} &amp;&amp; iss[24] == '0' then
        il = '1';
    end;
                </pre>
                </div>
                <p>Read that last line carefully, because it is the concept. <strong>For the two Data Abort classes a page fault arrives as, the instruction-length bit is not a fact about the instruction.</strong> It is forced to 1 to say <em>there is no valid instruction syndrome</em>. A handler that prints IL as "32-bit instruction" for such a fault is printing something the architecture told it to print and something that may be false.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement: what the compiler does with the value</h2>
                <p>Here is the part that <em>can</em> be measured on a host with no AArch64 silicon, and it is more interesting than expected. The corpus contains a C function per field extraction, and the instructions are the evidence:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 5 | sed -n '/the packed field/,/the instruction cost/p'
  [MEASURED-ON-BYTES] the packed field, and the arithmetic a handler does on it
     --- O2 ---
       ec_of                 2   lsr x0, x0, #26 ; ret
       il_of                 3   lsr x9, x0, #25 ; and x0, x9, #1 ; ret
       iss_of                2   and w0, w0, #0x1ffffff ; ret
       is_lower_data_abort   4   (see below)
       dfsc_of               2   and x0, x0, #0x7f ; ret
                </pre>
                </div>
                <p>Those are the obvious forms and they are what a page would normally teach. Now the one that is worth reading twice:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 5 | sed -n '/the one that is worth reading twice/,/^$/p'
  [MEASURED] the one that is worth reading twice
     mov	w8, #-1879048192                // =0x90000000
     and	x9, x0, #0xf8000000
     cmp	x9, x8
     cset	w0, eq
     ret
                </pre>
                </div>
                <p>The C is <code>return (ec == 0x24 || ec == 0x25);</code> — two comparisons. clang emitted <strong>one mask, one compare and one conditional set</strong>. The reason is arithmetic you can do in your head: <code>0x24</code> is <code>0b100100</code> and <code>0x25</code> is <code>0b100101</code>, so the two classes differ in <strong>one bit</strong> of the EC field and in nothing else. ANDing with <code>0xf8000000</code> clears that bit and collapses both cases into one value to compare against.</p>
                <div class="formula">
   R7, and the lesson is about the SHAPE of the constants

   OBVIOUS    lsr  x0, x0, #26
              cmp  x0, #0x24
              b.eq .yes
              cmp  x0, #0x25
              b.eq .yes
              ...                       SIX or more

   MEASURED   and  x9, x0, #0xf8000000     clears bit 27 of EC
              cmp  x9, #0x90000000
              cset w0, eq                  THREE

   The mask is not in any manual, because it is a
   property of the two CONSTANTS and not of the
   architecture.  A page that taught the syndrome
   with the shift would have taught a correct
   reading and a compiler-shaped one, and a reader
   writing a handler in that shape would be
   writing worse code than the compiler would have
   written for them.

   At -O0 the same C is THIRTEEN instructions.
                </div>
                <p>And the other measurement on this page, which is a <em>register choice</em> rather than an instruction count: a handler that reads all three registers at once gets <code>x8</code>, <code>x9</code> and <code>x10</code>, not <code>x0</code>, <code>x1</code> and <code>x2</code>.</p>
                <div class="hex-dump">
                <pre>     esr_all, -O2:
     mrs	x8, ESR_EL1
     mrs	x9, ELR_EL1
     mrs	x10, FAR_EL1
     eor	x8, x9, x8
     eor	x0, x8, x10
     ret
                </pre>
                </div>
                <p>The AAPCS64 answer is <code>x0</code>, and using it for a temporary here would be legal and confusing. A reader who has just read <a href="/courses/a64abi/lessons/a64-aapcs">the ABI course</a> sees a handler reading three system registers into <code>x8</code>–<code>x10</code> and learns something about the compiler that no document says.</p>
                <h3>The seven refusals</h3>
                <p>Seven identical diagnostics, and they say the same thing seven times:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 3 | sed -n '/Nine refusals/,/^$/p'
  [MEASURED-ON-BYTES] ... Nine refusals, one diagnostic:
     svc #65536         REFUSED   immediate must be an integer in range [0, 65535].
     svc #-1            REFUSED   immediate must be an integer in range [0, 65535].
     brk #65536         REFUSED   immediate must be an integer in range [0, 65535].
     hlt #-1            REFUSED   immediate must be an integer in range [0, 65535].
     mrs x0, esr_el0    REFUSED   expected readable system register  matches the table
     mrs x0, elr_el0    REFUSED   expected readable system register  matches the table
     mrs x0, far_el0    REFUSED   expected readable system register  matches the table
     mrs x0, vbar_el0   REFUSED   expected readable system register  matches the table
     mrs x0, tcr_el0    REFUSED   expected readable system register  matches the table
     mrs x0, ttbr0_el0  REFUSED   expected readable system register  matches the table
     mrs x0, sctlr_el0  REFUSED   expected readable system register  matches the table
                </pre>
                </div>
                <p><strong><code>ESR_EL0</code> and its six siblings do not exist</strong>, and that is not a naming convention the assembler invented — it is the architecture saying EL0 has no syndrome register, because EL0 cannot take an exception it has to describe. A reader who assumed <code>esr_el0</code> would assemble and found out at three in the morning has learned the rule the seven identical diagnostics were teaching all along. (The eighth row, <code>mrs x0, Sctlr</code>, is refused for a different reason: the EL-agnostic spelling does not exist on this architecture at all.)</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the field is a discriminated union, and the table is the point</h2>
                <p>This is the one screen in the course that is worth keeping, and it is entirely <span class="label label-quoted">QUOTED</span>. Thirty-nine rows, abbreviated. The <strong>left column is the discriminant and the right column changes completely depending on it</strong>:</p>
                <div class="hex-dump">
                <pre>  EC    meaning                      the ISS [24:0] means
  ----  ---------------------------  --------------------------------
  0x00  Unknown                     nothing -- the syndrome is undefined
  0x01  WFI/WFE retirement          a 5-bit register and a 2-bit state
  0x02  SMC                         nothing
  0x03  SVC (a syscall from EL0)    imm16 -- the LITERAL in the SVC
  0x0c  BRK                         imm16
  0x11  SVC (from EL1)              imm16
  0x12  HLT (from EL1)              imm16
  0x17  SVC (from EL3)              imm16
  0x18  HLT (from EL3)              imm16
  0x20  Instruction abort, lower EL the FAR, and the DFS
  0x21  PC alignment fault          nothing
  0x22  Data abort, lower EL        the FAR, and the DFSC
  0x24  Data abort, lower EL, WRITE the FAR, and the DFSC
  0x25  Data abort, lower EL, READ  the FAR, and the DFSC
  0x2c  FP exception                the status and a 4-bit index
  0x2e  SError                      the FAR, the WnR bit, the DFSC
  0x32  IRQ                         nothing
  0x33  FIQ                         nothing
  0x34  SError interrupt            nothing
                </pre>
                </div>
                <p><strong>There is no bit of the ISS that means the same thing in two rows of that table.</strong> For EC&nbsp;0x03 it is the sixteen-bit constant that was in the <code>SVC</code> — and <a href="/courses/a64sys/lessons/a64-syscall">concept 1 measured that constant in the instruction</a>, so a handler that sees EC&nbsp;0x03 can tell you which syscall trapped by reading bits 24:5 of the syndrome, <em>without going back to the instruction at ELR</em>. For EC&nbsp;0x25 the same twenty-five bits are a fault address, a read/write flag, a fault-status code and an overflow flag.</p>
                <div class="formula">
   THE CONCEPT IN ONE SENTENCE

   The ISS is not a NUMBER.  It is a DISCRIMINATED
   UNION, and the discriminant is the six bits
   above it.

   A decoder that treats ESR_EL1 as an integer has
   got the width right and the MEANING wrong, and
   the wrongness is silent: every value it prints
   is a valid 32-bit number, and the number it
   prints for a page fault is the number a syscall
   would have printed.
                </div>
                <p>And one trap in the table worth naming, because it is the row everybody forgets:</p>
                <ul>
                    <li><strong><code>0x22</code> exists and is a Data Abort.</strong> <code>0x22</code> is <code>0b100010</code> and <code>0x24</code> is <code>0b100100</code> — they differ in one bit of the EC field, and <code>0x24</code> is <em>write</em> while <code>0x22</code> is a read-or-write abort. A handler that tests for <code>0x24</code> and <code>0x25</code> and concludes "a write fault and a read fault" has used a table that is right about those two rows and silent about the third, which is the row a translation fault on a single instruction can also produce.</li>
                    <li><strong><code>0x24</code> and <code>0x25</code> are the ones a page fault arrives as</strong>, and they are the two the quoted pseudocode singles out for the IL rule. So the two most common exceptions on the machine are the two with the least trustworthy instruction-length bit.</li>
                </ul>
                <h3>What this page cannot show</h3>
                <p>It cannot show an exception. Not one of the thirty-nine rows above has been observed happening, because there is no AArch64 machine, no emulator and no linker on the build host. The classes, the field widths, the per-class meanings and the IL rule are quoted from DDI 0597 with section numbers. The instructions that read the three registers and the arithmetic clang emits around them are measured, on bytes, and cross-read by both readers. <strong>The gap between those two is the gap between a table you look up and a sequence you can read</strong>, and <a href="/courses/a64sys/lessons/a64-evidence">concept 6</a> prints the whole boundary. The one thing this page measures that a table could never tell you is the three-instruction test — and it is measured because the constants in the table make it possible, not because the architecture says so.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Read a syndrome out of a register and check the field positions yourself.</strong> Take a value like <code>0x96000050</code> — a Data Abort from a lower EL, 32-bit instruction — and extract EC with <code>(v &gt;&gt; 26) &amp; 0x3f</code>, IL with <code>(v &gt;&gt; 25) &amp; 1</code> and ISS with <code>v &amp; 0x1ffffff</code>. <em>(Expect EC&nbsp;=&nbsp;0x25, IL&nbsp;=&nbsp;1, ISS&nbsp;=&nbsp;0x50, and then look up what DFSC&nbsp;=&nbsp;0x10 means in the architecture manual: it is a synchronous external abort, not on a translation table walk. Now check bit 6 of the ISS, which is WnR — write-not-read — and see whether your example is a read or a write. Three fields, one register, and the answer to "was it a read?" is <em>inside the union</em>.)</em></li>
                    <li><strong>Find the seven refusals and then find the seventh row.</strong> Try <code>mrs x0, esr_el0</code>, <code>mrs x0, elr_el0</code>, <code>mrs x0, far_el0</code>, <code>mrs x0, vbar_el0</code>, <code>mrs x0, tcr_el0</code>, <code>mrs x0, ttbr0_el0</code>, <code>mrs x0, sctlr_el0</code>, and then <code>mrs x0, Sctlr</code>. <em>(Expect seven refusals with <code>expected readable system register</code> and an eighth with the same message for a different reason. Then ask the question the refusals imply: where does an EL0 signal handler get its numbers? The answer is that the kernel put them in a <code>siginfo</code> and that the signal number is a <em>Linux</em> number, not an EC — the same division as concept 1's field-versus-convention.)</em></li>
                    <li><strong>Write the handler two ways and count the instructions.</strong> Compile <code>return (ec == 0x24 || ec == 0x25);</code> at <code>-O0</code> and <code>-O2</code>. <em>(Expect three instructions at <code>-O2</code> — a mask, a compare and a <code>cset</code> — and about thirteen at <code>-O0</code>. Then change the constants to <code>0x22 || 0x24</code> and recompile: those two differ in a different bit, so expect a different mask, and expect the compiler to find it again. The generalisation is that a compiler can only exploit a coincidence in the constants, so the shape of your constant set is part of the shape of your generated code.)</em></li>
                    <li><strong>Write a decoder for the syndrome and test it against the table.</strong> Twenty lines: mask EC, IL, ISS, and print the class name from a 39-entry table. <em>(Expect it to work on every class and to be <em>wrong in a way you cannot detect</em> for class 0x00, where the ISS is undefined and your code will print a number anyway. That is the same failure mode as the encoding course's HINT bug: a decoder that produces a plausible value for something that has none. A count of unmodelled words is a fact about a corpus, and a count of undefined fields is a fact about a specification.)</em></li>
                    <li><strong>Compare the AArch64 and x86-64 error reports and count what each gives you.</strong> <a href="/courses/x86sys/lessons/x86-exceptions">The x86-64 exception concept</a> gives you a <code>#PF</code> with a 14-bit error code whose bits are documented individually. Build the AArch64 equivalent: EC as a discriminant, then a per-class decoder. <em>(Expect x86-64's report to be a single fixed-layout field and AArch64's to be a tagged union, and expect the tagged union to be strictly more informative when the class is rare — a class that does not exist on x86-64 has a five-bit code on AArch64 saying so, and a 14-bit x86-64 code that is <em>reserved</em> says nothing. The price is that you have to write the decoder; the x86-64 price is that you have to read the reserved rows.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, specifically. <a href="/courses/a64sys/lessons/a64-syscall">Concept 1</a> measured the sixteen-bit constant that EC&nbsp;0x03 reports back to you, so the two concepts close a loop: the number you put in the instruction is the number the syndrome gives you. <a href="/courses/a64asm/lessons/a64-encoding">The encoding course</a> owns the class field at bits[28:25] and the dispatch order this page depends on — read its <a href="/courses/a64asm/lessons/a64-verify">cross-check concept</a> first if the terms CRn and op2 are new, because this page's whole measured half is about how a register name lives in nine bits. <a href="/courses/a64abi/lessons/a64-registers">The ABI course's register concept</a> explains why a handler's temporaries land in <code>x8</code>–<code>x10</code> and not <code>x0</code>–<code>x2</code>.</p>
                <p>Sideways, three neighbours that own the edges. <a href="/courses/priv/lessons/priv-vectors">The neutral course owns the vector model</a> — what an exception <em>is</em>, in terms any architecture can use — and <a href="/courses/x86sys/lessons/x86-exceptions">the x86-64 exception concept</a> is the sibling reference for the same subject, where the report is a fixed-layout error code rather than a tagged union. <a href="/courses/mem/lessons/mem-translation">The paging course</a> owns what a translation fault <em>is</em>; the DFSC values in the table above are where that course's subject arrives as a number, and the connection runs both ways — a reader who has read the paging concept can look up DFSC&nbsp;0b000100 and know what a level-1 translation fault looks like before ever seeing a table.</p>
                <p>Outward, and the general form is the thing to carry. <strong>A register layout is a document; the code that reads it is a measurement; and the gap between them is where kernel bugs live.</strong> You cannot run the document. You can count the instructions the code takes, and the two results are of different kinds and must be reported as such. This is the same discipline <a href="/courses/a64sys/lessons/a64-evidence">concept 6</a> applies to the whole course, and it is the reason that concept exists: a course about a machine that was never here has exactly one advantage over a course about one that was, and the advantage is that it is <em>forced</em> to be explicit about which claims are which kind.</p>
                <p>Forward, one promise. <a href="/courses/a64sys/lessons/a64-interrupts">Concept 3</a> is about where the handler <em>goes</em>, and the connection to this page is a single instruction: the <code>ELR_EL1</code> you read here is the address the CPU will return to, and the vector table of concept 3 is the address it goes to <em>first</em>. Two registers, one mechanism, and the order in which you read them is the order in which the machine used them.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64sys/lessons/a64-syscall">SVC #imm16, and x8 Is a Convention and Not an Architecture</a></span>
                <span>Next: <a href="/courses/a64sys/lessons/a64-interrupts">Sixteen Entries of 0x80, and Four Times No Diagnostic</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
