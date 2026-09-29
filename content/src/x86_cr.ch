// The x86-64 Machine — Concept 4: the control registers
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_cr() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("CR0 to CR4, Every Bit — Underlayer")
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
                        <dt><kbd>uarr;</kbd></dt><dd>Back to top</dd>
                    </dl>
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>CR0 to CR4, Every Bit</h1>
            <div class="lesson-meta">26 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Five registers. Between them they decide whether the processor is in protected mode, whether it is paging, where the page tables are, how wide an address is, whether the timer can read the clock, whether a performance counter can be read, and whether the supervisor can execute a user page. <strong>Every one of those decisions is made by a bit that a user process cannot read.</strong></p>
                <p>That makes this concept the course's purest example of the distinction the whole course is built on. There is no table of CR0's value in this course, because there cannot be one. What there is instead is the complete bit layout, printed as a reference and stamped <code>NOT MEASURED</code>, and then a measurement of what each of the interesting bits <em>does</em> &mdash; which is a consequence, narrows the set of readings, and is not a reading.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three registers with different jobs and one that is a number</h2>
                <p><code>CR0</code> is a mode register, <code>CR2</code> is a mailbox, <code>CR3</code> is a pointer with four address-size fields in it, and <code>CR4</code> is a feature-enable word that has been appended to one bit at a time for thirty years. <code>CR1</code> and <code>CR5</code> through <code>CR7</code> are reserved, and <code>CR8</code> is not a control register at all in the usual sense: it is the task priority register, and it is <em>not</em> privileged on x86-64, which is a genuinely surprising exception.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/1B2\./,/^1B3/p'
1B2. CR3.  THE PAGE-DIRECTORY BASE AND THE ADDRESS-SIZE BITS.

  CR3 | 0-11  | PCID   | address space tag, USED ONLY IF CR4.PCIDE=1
  CR3 | 12    | PWT    | page-table writes are write-through
  CR3 | 13    | PCD    | page-table writes bypass the cache
  CR3 | 14-47 | BASE   | physical address of the PML4, 4 KiB aligned
  CR3 | 48-51 | SEAM   | reserved, and MUST EQUAL bit 47 of BASE:
  CR3 |         |        | this is the sign-extension of the base and
  CR3 |         |        | it is the only thing in CR3 that is not a bit
  CR3 |         |        | you can set to a constant
  CR3 | 52-63 | ZERO   | must be zero in 4-level paging; with CR4.LA57=1

  THE FOUR ADDRESS-SIZE BITS, which is what a compiler backend has to
  get right and what CR0.CR3 and CR4.LA57 select between:
    4-level paging   CR3[63:52] reserved-zero,  CR3[51:48] sign-extend
    5-level paging   CR3[63:58] reserved-zero,  CR3[57:52] sign-extend
  The address bits come from the CPUID, not from CR3, and section 2
  measures which of the two this machine reports.
                </pre>
            </div>
                <p>That <code>SEAM</code> row is the one a backend has to get right. <code>CR3[47:0]</code> is a 4 KiB-aligned <em>physical</em> address, and a physical address has no sign; the field at 51:48 exists so that the register's top bits are a sign extension rather than four independent bits, which means <strong>you cannot write <code>CR3</code> with a mask and an OR</strong>. You have to shift the base left by four, OR the sign, and shift back. It is one instruction in a hand-written loader and it is the difference between booting and faulting before the first byte of the kernel is mapped.</p>
                <p>And the <code>CR0</code> table has a row that is the best single illustration of why architectures accumulate scars:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/CR0 | 4 /,/CR0 | 5 /p'
  CR0 | 4    | ET  | extension type, RESERVED and ALWAYS 1 since the 486
  CR0 | 4    | ET  | extension type, RESERVED and ALWAYS 1 since the 486
                </pre>
                </div>
                <p><strong>A bit with no meaning, no way to read it, and a hardware rule that it must be 1.</strong> On the 386 it selected between the 80287 and the 80387 math coprocessors, software wrote zero to it because it was the reset value, and a 486 was built that faulted on the zero. Three decades later it is a reserved-must-be-1 row in every reference and nobody can say what setting it to zero would do. Compatibility scars are not mistakes; they are the price of a promise somebody kept.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: every access is a fault, and the five bits that decide the most are among them</h2>
                <p>Sixteen attempts &mdash; five registers read, four written, plus the one that is <em>not</em> privileged:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  EDGE \| mov (cr|reg)'
  EDGE | mov cr0 -> reg                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov cr2 -> reg                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov cr3 -> reg                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov cr4 -> reg                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov cr8 -> reg                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov reg -> cr0                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov reg -> cr3                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov reg -> cr4                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov reg -> cr8                 | control registers | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
                </pre>
            </div>
                <p>Nine of nine, all with <code>si_code 128</code> and an address of zero: a #GP with an empty error code, which is why <code>128</code> keeps appearing in this course. <code>CR8</code> is in the table because the surprise is worth measuring rather than asserting: the task priority register is documented as privileged, and it is privileged <em>except on x86-64</em>, where the SDM says &ldquo;in 64-bit mode, <code>CR8</code> is not a privileged register.&rdquo; The measurement is a fault, and it is a fault on this AMD part, so either the exception is vendor-specific or the reading is. This file does not say which, because a disagreement between a manual and a measurement on one part is a <strong>question</strong>, and a question printed is worth more than a confident sentence.</p>
                <h3>The five rows of <code>CR4</code> that decide the most</h3>
                <p>Take the thirty-one <code>CR4</code> rows and ask which ones change what <em>this process</em> can do. Five, and the artifact names them in its own prose:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/FIVE ROWS OF THAT TABLE/,/it cannot read/p'
  FIVE ROWS OF THAT TABLE DECIDE WHETHER THIS PROCESS CAN OBSERVE
  ANYTHING AT ALL, and every one of them is a bit in a register it
  cannot read:  CR4.UMIP decides whether SIDT and SGDT are legal at
  CPL 3.  CR4.PCE decides whether RDPMC is legal at CPL 3.
  CR4.TSD decides whether RDTSC is legal at CPL 3.  CR4.PCIDE and
  CR4.LA57 decide the shape of CR3.  Section 3 measures the
  CONSEQUENCES and section 2 measures what the kernel says the bits
  are.  What it CANNOT do is read CR4, and that is the limit.
                </pre>
            </div>
                <div class="formula">
   AND HERE IS THE TABLE, WITH THE COLUMN
   THAT MAKES IT A REFERENCE RATHER THAN
   A LIST.  Every row of every table in this
   course says which it is.

   CR4.UMIP   11  if 1, SGDT SIDT SLDT
                    SMSW STR are #GP at CPL>0
   CR4.PCE     8  if 1, RDPMC is permitted
                    at any CPL
   CR4.TSD     2  if 1, RDTSC is CPL 0 only
   CR4.PCIDE   17  CR3[11:0] is a PCID and
                    not part of the base
   CR4.LA57   12  five-level paging, 57-bit
                    linear addresses

   Four of the five were MEASURED by their
   consequence in this course:

     TSD=0   because RDTSC and RDTSCP
             returned
     PCE=0   because RDPMC is a #GP
     UMIP=0  because SIDT, SGDT, STR,
             SLDT and SMSW all returned

   The fifth is a report: CPUID.7.0:ECX
   bit 16 says the CPU SUPPORTS five-level
   paging, which is a property of the metal
   and not of CR4.LA57, and reading CR4 is
   a fault.  What is unknown is whether this
   kernel SETS it, and the answer cannot be
   reached from ring 3 at all.
                </div>
                <p>That is a real narrowing and it is worth being precise about what it is worth. Knowing <code>UMIP=0</code> rules out one of two values; it does not tell you who cleared it, when, or whether a kernel upgrade would clear it again. <strong>A consequence is a constraint, not a value</strong> &mdash; and the third concept's field-order result is the same kind of statement, arrived at from the other direction: a measurement that predicted an exact number rather than ruling one out.</p>
                <h3>What a write to a control register would invalidate</h3>
                <p>The second half of the reference is not the bits but what each write costs, because a backend that has to reason about a <code>CR3</code> reload has to know whether the TLB survives:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/WRITING CR0 invalidates/,/instruction and the assertion is one/p'
  WRITING CR0 invalidates:  CR0.PG 0-&gt;1 flushes the TLB completely.
                              CR0.WP and CR0.AM change no TLB entry, so
                              the SDM requires NO invalidation for them
                              and this file has no instrument either.
                </pre>
            </div>
                <p>So the one row in the table that is not a mode and not a feature is <code>CR0.PG</code>, because clearing and setting it is a whole-TLB flush, and a context switch that reloads <code>CR3</code> with a different PCID does not need one. That is the entire argument for the process-context identifier: <strong>a bit in <code>CR3[11:0]</code> that makes the most expensive operation in the MMU unnecessary.</strong> The <a href="/courses/mem/lessons/mem-instrument">memory course</a> measured the cost of the thing being avoided; this is where the mechanism is.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: <code>CR2</code>, the one control register that is a mailbox</h2>
                <p><code>CR2</code> is not a mode. It is where the CPU writes the linear address of a page fault, and it is the only control register with a <em>readable-in-a-handler</em> contract, because the handler runs at CPL 0 by construction. That makes it a debugging aid rather than a control, and it is also a trap: <code>CR2</code> is a 64-bit register on x86-64 in long mode, so a kernel that reads only its low half will work perfectly until a process has a mapping above 4 GiB, at which point it will report a fault address of zero.</p>
                <p>What a ring-3 process gets instead is <code>si_addr</code>, which is <em>not</em> <code>CR2</code>. Section 4 of the artifact measures the difference three ways:</p>
                <ul>
                    <li><strong>Null dereference: <code>si_addr = 0</code>, <code>si_code = 1</code>.</strong> Here they agree, because the linear address really was zero.</li>
                    <li><strong>Write to a read-only page: <code>si_addr</code> is the page, <code>si_code = 2</code>.</strong> Again agreement, and again the number cannot distinguish it from the next case.</li>
                    <li><strong>A non-canonical access: <code>si_addr = 0</code>, <code>si_code = 128</code>.</strong> Here they <em>dis</em>agree, and the disagreement is the whole point: the CPU never made it an address, so <code>CR2</code> was never written, and the kernel's &ldquo;address&rdquo; is a zero it invented.</li>
                </ul>
                <div class="formula">
   SO THE HIERARCHY IS:

     CR2       the CPU's own record, readable
              only at CPL 0, and correct for
              every page fault including the
              ones where the address was
              never an address
     si_code   the kernel's TRANSLATION, with
              ONE of the six bits of the
              error code surviving
     si_addr   the kernel's CHOICE of an
              address, which is CR2 for a real
              fault and ZERO otherwise

   A fault handler that reads si_addr
   before si_code concludes that a #GP
   dereferenced a null pointer, and a
   security tool that treats si_addr as a
   raw pointer is one null-dereference
   report away from a false positive it
   cannot explain.
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Try the one <code>CR8</code> that is supposed to be readable.</strong> Write a ten-line program that does <code>mov %rax, %cr8</code> and runs it. <em>(Expect <code>SIGSEGV</code> on this machine. Then read the SDM sentence about 64-bit mode and decide whether you are looking at an erratum, a vendor difference, or a misreading &mdash; and write down which of the three you think it is before you check, because the answer you write first is the one you will remember.)</em></li>
                    <li><strong>Prove the constraint and not the value.</strong> The table above says <code>CR4.TSD=0</code> because <code>RDTSC</code> returned. Write the complementary test: what would you have to observe to conclude <code>CR4.TSD=1</code>? <em>(Expect: nothing from ring 3. The observation is impossible, which is what makes this a constraint rather than a value &mdash; and it is the difference between the two sentences &ldquo;the bit is clear&rdquo; and &ldquo;the bit does not stop <code>RDTSC</code>.&rdquo;)</em></li>
                    <li><strong>Write a <code>CR3</code> setter that is correct in both paging depths.</strong> Take a base, shift it left by four, sign-extend into bits 63:48, and OR in a PCID. <em>(Expect the 4-level case to be four instructions and the 5-level case to need a different shift, because the sign field moves from four bits to six. That difference is the entire cost of <code>CR4.LA57</code> to a kernel, and it is why a hypervisor that offers both has to present two CR3 formats to the same guest.)</em></li>
                    <li><strong>Count the reserved-must-be-1 bits on this architecture.</strong> Go through the <code>CR0</code> and <code>CR4</code> tables and count the rows that say &ldquo;reserved&rdquo; and the one that says &ldquo;reserved and always 1.&rdquo; <em>(Expect a great many, and expect the count to be a better predictor of architecture age than the instruction set. A field is reserved because something used it, and a field that is reserved-and-one is a scar from a promise somebody had to keep.)</em></li>
                    <li><strong>Decide which bits your own kernel must set and which it may not.</strong> If you are writing an OS, <code>CR4.UMIP</code> is a decision with a security argument on both sides: set it and your own debugging tools lose <code>SGDT</code>; leave it and a user process can read the GDT's address. <em>(Expect there to be no answer that satisfies both, and expect every production kernel to have made the same choice for the same reason. The bit is one row of thirty-one and it decides more than thirty rows of anything else in this course.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, the previous concept measured the consequence of <code>CR4.UMIP</code> without naming it, and this concept names it and says the naming does not help. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness concept</a> is where <code>arch_prctl</code> and the SMEP/SMAP <em>report</em> come from, and the difference between a report and a reading is the difference between the third row of this page and the first. <a href="/courses/mem/lessons/mem-translation">The memory course's translation concept</a> owns the <em>why</em> of a page directory pointer; this page is the reference for what is in the pointer.</p>
                <p>Forwards. The fifth concept is the other set of registers &mdash; <code>DR0</code> to <code>DR7</code> &mdash; and it is the same problem in a smaller register with a nastier answer, because the debug registers have <em>two</em> authoritative layouts and this course cannot tell you which one its own CPU implements. Then the sixth and seventh concepts move from the control registers to what they control: the address space, and the four structures inside it.</p>
                <p>Outward. Everything on this page is a <em>kernel</em> interface. That is the reason this course exists as a separate thing from the privilege course: the privilege course can measure a boundary from outside, and this course has to say &ldquo;here is the complete interface, and here is the part of it you can see, and here is the boundary between those two things.&rdquo; A hypervisor author and an OS author are the two readers this table is for, and they need different halves of it.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-rings">Descriptor Tables and the Privilege Checks</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-debug">DR0 to DR7 and the Mask a Debugger Must Program</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
