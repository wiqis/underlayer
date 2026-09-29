// The x86-64 Machine — Concept 9: the whole inventory, and what it cannot see
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_boundary() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("What Ring 3 Can See, and What It Cannot — Underlayer")
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
                    <button onclick="closeShortcuts()" class="a11y-close">Close</button>
                </div>
            </div>
            <div class="reading-controls">
                <label>Font: <select id="font-size" onchange="setFontSize(this.value)"><option value="small">Small</option><option value="medium" selected>Medium</option><option value="large">Large</option></select></label>
                <label>Spacing: <select id="line-height" onchange="setLineHeight(this.value)"><option value="compact">Compact</option><option value="normal" selected>Normal</option><option value="relaxed">Relaxed</option></select></label>
                <label>Letters: <select id="letter-spacing" onchange="setLetterSpacing(this.value)"><option value="tight">Tight</option><option value="normal" selected>Normal</option><option value="loose">Loose</option></select></label>
                <label>Width: <select id="content-width" onchange="setContentWidth(this.value)"><option value="narrow">Narrow</option><option value="normal" selected>Normal</option><option value="wide">Wide</option></select></label>
            </div>
            <h1>What Ring 3 Can See, and What It Cannot</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this concept exists</h2>
                <p>Eight concepts of reference, and the reader is left with a set of tables about a machine they are not running on. This concept is the <strong>inventory</strong>, and it has a property none of the others has: <em>every row in it was produced by this process on this machine, and every row is either a bit pattern read out of a register or a signal number that killed a forked child.</em></p>
                <p>That is worth having on its own terms even if you will never read another word about the control registers. A user program that wants to know something about its own machine has a <strong>finite, enumerable list of things it can ask</strong>, and the list is shorter than most people assume, longer than most people guess, and the boundary of it is not where the documentation says.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the harness, and the one bug that made it a different instrument</h2>
                <p>Every fault in this course is a signal, and the parent has to learn the signal's <code>si_code</code> and <code>si_addr</code> from a child. How it learns them is the whole design, and the first version got it wrong in the way that is most expensive to notice.</p>
                <div class="formula">
   THE WRONG VERSION, and its output.

       static int code;               /* a plain global */

       static void handler(int sig, siginfo_t *si, void *uc)
       &#123;
           code = si->si_code;        /* runs in the CHILD */
           _exit(3);
       &#125;

   The parent then reads `code` after
   waitpid().  The handler ran in the
   child's address space.  The parent's
   copy of `code` was never written.

   RESULT: si_code 0 for all fifty rows.

   And 0 is not an arbitrary wrong answer.
   0 is a plausible one.  Every row that
   should have said 128 said 0, and a
   table full of zeroes reads like a
   result -- "the kernel did not report a
   code for any of these" -- and would
   have been published.
                </div>
                <div class="formula">
   THE RIGHT VERSION, which is three lines
   longer and cannot be got wrong by
   accident.

       static rec_t *R;   /* mmap MAP_SHARED */

       static void handler(int sig, siginfo_t *si, void *uc)
       &#123;
           R->sig  = sig;
           R->code = si->si_code;
           R->addr = si->si_addr;
           R->used = 1;
           _exit(3);
       &#125;

   A shared page is the only channel that
   crosses a fork, and `used` is what tells
   the parent the child reached the handler
   at all rather than exiting normally by
   accident.  A harness without a `used`
   flag cannot tell "the instruction
   returned" from "the instruction was
   deleted" -- and the divide-by-zero arm
   of section 4 was deleted by gcc, and
   the first version of this file would
   have reported it as a clean run.
                </div>
                <p>The artifact prints both halves of that story in section 3, next to the table, because <strong>a harness failure is part of the instrument</strong> and a course that reports only its final table has hidden the part of the method that a reader most needs to check.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the inventory</h2>
                <p>First the <strong>can</strong> column. Ten instructions, each in its own forked child, each reported by name:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  EDGEREAD'
  EDGEREAD | sidt                           | si_code 0 | readable
  EDGEREAD | sgdt                           | si_code 0 | readable
  EDGEREAD | sldt                           | si_code 0 | readable
  EDGEREAD | str                            | si_code 0 | readable
  EDGEREAD | smsw                           | si_code 0 | readable
  EDGEREAD | rdtsc                          | si_code 0 | readable
  EDGEREAD | rdtscp                         | si_code 0 | readable
  EDGEREAD | xgetbv                         | si_code 0 | readable
  EDGEREAD | rdfsbase                       | si_code 0 | readable
  EDGEREAD | wrfsbase                       | si_code 0 | readable
                </pre>
            </div>
                <p>And the shape of the <strong>cannot</strong> column, which is the number and one more thing:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  EDGE | rows'
  EDGE | rows 50 | faulted 39 | returned 11 | si_code 128 34 | other 5
                </pre>
            </div>
                <p>Fifty instructions, thirty-nine faults, eleven returns &mdash; and the harness asserts the two sets are <em>disjoint</em>, because a partition is a claim a check can make and a count cannot.</p>
                <ul>
                    <li><strong>Thirty-four of the thirty-nine faults are <code>si_code 128</code> with <code>si_addr 0</code>.</strong> A <code>#GP</code> with an empty error code. The five that are not are the <code>#UD</code> group &mdash; <code>ud2</code>, <code>sysenter</code>, <code>vmcall</code>, <code>mgmt</code> and a raw <code>bound</code> encoding &mdash; and those arrive as <code>SIGILL</code> with an <code>si_addr</code> that is the faulting instruction. <strong>Two different signals for the same boundary</strong>, and the difference is whether the CPU knew what the instruction meant.</li>
                    <li><strong><code>sysret</code> and <code>sysenter</code> are on opposite sides of that line.</strong> <code>sysret</code> from ring 3 is <code>si_code 128</code> and <code>sysenter</code> is <code>si_code 2</code> as a <code>SIGILL</code>. Two instructions whose only similarity is the word SYSCALL, and the <a href="/courses/priv/lessons/priv-doors">privilege course measured the second one</a> and found it was a vendor difference about long mode rather than a privilege rule. A boundary table is worth more than a boundary rule, because a rule would have had to pick one.</li>
                    <li><strong>Loading a selector is in the cannot column and reading one is not.</strong> <code>mov $0x1234,%ax; mov %ax,%ds</code> is a <code>#GP</code>; <code>mov %ds,%ax</code> returns. And <code>str</code> returns while <code>ltr</code> does not. <strong>The boundary is not &ldquo;the machine's tables&rdquo;; it is per-instruction, and the two halves of a register access are on opposite sides of it.</strong></li>
                </ul>
                <h3>Then the three absences, each proved rather than quoted</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/6C\./,/XCR0 = /p'
  6C. THERE IS NO AVX-512, WHICH IS A DIFFERENT KIND OF ABSENCE,
      because it is a FEATURE BIT rather than a permission.

  ABSENT | CPUID.7.0:EBX AVX512F 0 DQ 0 CD 0 BW 0 VL 0 | ALL ZERO
  ABSENT | XCR0 = 0x0000000000000207, and the AVX-512 STATE bits of XCR0
  ABSENT | (5 opmask, 6 zmm_hi256, 7 hi16_zmm) are all 0, so even
  ABSENT | the state is not merely unsupported, it is not enabled.
  ABSENT | A feature bit is a FACT ABOUT THE CPU that any process
  ABSENT | can read with an unprivileged instruction, which is the
  ABSENT | opposite of a permission: the absence of AVX-512 is
  ABSENT | DECLARED BY THE HARDWARE, and the absence of the PMU is
  ABSENT | imposed by software.  Two absences, two different kinds.
                </pre>
            </div>
                <p>That is the concept's whole argument in one paragraph, and it is a distinction rather than a number. <strong>An absence of hardware is declared by the hardware</strong>, in a register any process may read. <strong>An absence of access is imposed by software</strong>, in a file and a bit and a file mode. The first is a fact about the CPU and identical on every machine of that model. The second is a fact about <em>this machine, today, as configured</em>, and it can change without the CPU changing &mdash; which is why the performance-counter absence needed a fork to establish and the AVX-512 absence did not need a fork at all.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the ten retractions, and what each one cost</h2>
                <p>Every one is printed by the artifact and asserted as text by the harness, so a taken-back claim can be neither dropped nor edited into being right. They are worth reading as a list because <strong>the pattern of them is the argument for the whole collection</strong>:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^   R1\./,/^   R3\./p'
   R1. "A ring-3 process cannot read the IDT because the IDT is
       privileged."  RETRACTED AND REPLACED.  The REGISTER is
       readable: SIDT returns base and limit from ring 3, and section
       2 prints them.  What cannot be read is one byte of the TABLE,
       and the reason is not privilege: the fault is si_code 1,
       SEGV_MAPERR, with si_addr EXACTLY the base SIDT printed.  A
       #GP would have been si_code 128 and si_addr 0, which is what
       every privileged instruction in section 3 produced.  The right
       sentence is a PAGE-TABLE sentence, and it predicts the address
       the first sentence could not.

   R2. "The 16-byte arm of the canonical sweep measures the
       canonical boundary."  RETRACTED.  It measured an ALIGNMENT
       requirement, because gcc compiled the __int128 load to
       `movdqa`, and the sweep then reported si_code 128 for every
       unaligned address at every offset, which looks like a rule and
       is not one.  Written in inline `movdqu` the same sweep gives
       2^47 - 15, the value the rule predicts, and section 5 prints
       BOTH arms side by side so that the retraction has numbers.
                </pre>
            </div>
                <p>Two of the ten are not about the machine at all, and they are the two that a reader is most likely to repeat.</p>
                <ul>
                    <li><strong>R4 admits that the artifact's own output was wrong and the harness was the reason.</strong> The first thirteen-register <code>syscall</code> table reported <em>all fifteen clobbered</em>, because the inline-asm block's clobber list named six registers the body wrote and said nothing about seven more. A <code>SIGBUS</code> from a held output address came first; the wrong table came second; and the wrong table <strong>agreed with a story the author had already written down</strong>, which is the kind of error that survives review. The general form is in the first concept and the retraction is here because a course that keeps its harness bugs to itself is teaching that harness bugs are not knowledge.</li>
                    <li><strong>R5 is a right answer for a wrong reason.</strong> LAM is leaf 7 <em>subleaf 1</em>, <code>EAX</code> bit 26. The first version read subleaf 0 <code>ECX</code> bit 26 &mdash; the same number, a different register, a different subleaf &mdash; got zero, and reported LAM as unsupported with total confidence. <strong>It happened to be right and it was still wrong</strong>, and the general form is worse than the error: a check that reads the wrong bit has not been tested at all, and neither has the code around it.</li>
                </ul>
                <p>And the two that are about reading a document correctly, which is where a reference course lives or dies:</p>
                <ul>
                    <li><strong>R2, the <code>movdqa</code> one.</strong> A compiler strengthened an instruction nobody asked it to strengthen, and the measurement acquired a pattern that a reader would take for a machine rule. The two arms are printed side by side in the artifact so that the retraction has <em>numbers</em> rather than an adjective. The general form is in this course's third concept too, and it has now happened here twice: a measurement harness must be read, not trusted, and <code>objdump</code> on the body is the cheapest possible check.</li>
                    <li><strong>R10, the pagemap one.</strong> Bit 63 of a <code>/proc/self/pagemap</code> word is the present bit; bit 63 of the <em>page-table entry</em> is <code>NX</code>. The first version read the first as the second and reported <code>NX=1</code> for a page it had never written. Two different bits, the same number, and a page that confuses them is confidently wrong about a security property. The replacement is the better result anyway &mdash; an untouched mapping has no entry at all, which is demand paging observed from the inside.</li>
                </ul>
                <div class="formula">
   THE SHAPE OF ALL TEN, which is the
   argument for the whole collection and
   the reason the harness asserts them as
   text.

     R1  a claim about PRIVILEGE that was
         really about a MAPPING
     R2  a compiler quietly changed what
         was being measured
     R3  a harness asked for something
         the machine cannot provide
     R4  the harness produced a wrong
         ANSWER that agreed with a story
     R5  the right number read from the
         wrong field
     R6  a constant stated as a boundary
         when it is a function of one
     R7  an absence of ACCESS reported as
         an absence of HARDWARE
     R8  a field the KERNEL fills reported
         as a field the CPU fills
     R9  two different protections
         reported as distinguishable
    R10  two different bits reported as
         one because they share a number

   Not one of them is a mistake about how
   a computer works.  Every single one is
   a mistake about what a NUMBER is.
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the inventory.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 3. <em>(Expect 50 rows, 39 faults, 11 returns, and the two sets disjoint. If a row flips, the most likely causes in order are a seccomp filter, a hardened kernel with <code>CR4.UMIP</code> set, and a different vendor &mdash; and the first of those is worth chasing, because a seccomp filter that returns <code>EPERM</code> instead of a signal would break the harness's assumption that a refusal is a fault.)</em></li>
                    <li><strong>Break the shared-page harness.</strong> Replace the <code>MAP_SHARED</code> allocation with a plain global, exactly as the first version was, and re-run. <em>(Expect every <code>si_code</code> to read 0 and the harness to fail on the <code>#GP</code> checks. Then read what the table now claims: &ldquo;the kernel reported no code for any privileged instruction&rdquo; is a sentence you could publish, and it is the sentence this bug produces. That is why the failure mode of a measurement harness is part of the measurement.)</em></li>
                    <li><strong>Count your own machine's inventory.</strong> Write a program that runs the same fifty instructions and reports which of them fault on <em>your</em> kernel. <em>(Expect the privileged set to be stable across kernels of the same vintage and the <code>SIDT</code>/<code>SGDT</code>/<code>STR</code> set to be the part that varies, because it depends on <code>CR4.UMIP</code> and a policy decision. A list of what a user program can do is a list of a kernel's configuration, and it is a list that changes between distributions.)</em></li>
                    <li><strong>Check whether a claim you are making is a consequence or a reading.</strong> Take the last five technical claims you have written or said and ask, for each, &ldquo;did I observe this, or did I infer it from something I observed?&rdquo; <em>(Expect most of them to be consequences, which is fine and is what most engineering is. Expect one or two to be readings dressed as consequences, and those are the ones that are wrong with a confidence that will not help you.)</em></li>
                    <li><strong>Prove an absence your own toolchain depends on.</strong> Take a tool you use every day and find the machine property it silently requires. <em>(Expect the answer to be a CPUID bit, a <code>/sys</code> file, or a syscall return value &mdash; that is, a fact about the machine that the tool assumes rather than checks. Then check it, and if it is not there, say so. A tool that reports a number derived from a property it never verified is making a claim about the machine and has not said so.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect, and the last thing</h2>
                <p>Backwards, this concept has no single parent; it is the <strong>sum</strong> of the first eight, and the table it prints is the argument that the sum is a list rather than a pile. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness concept</a> is where the one measurement this course builds on &mdash; <code>SIDT</code> returns and the IDT does not &mdash; was taken, and the difference is that this course made that asymmetry into fifty instructions and then into a partition the harness can check.</p>
                <p>Forwards, and there is a course after this one. The fourth course in this section is about the data path, and it inherits a specific debt from the eighth concept here: <strong>the AVX-512 feature bits that read as all zero are the same zero that course has to work around</strong>, and the <code>movdqa</code> trap that retraction R2 caught is the same class of problem as a misaligned vector store being a fault rather than a slowdown. A course that teaches a data path on a machine that lacks half the instructions in it has to be explicit about which half, and this course is where the explicit part lives.</p>
                <p>And the last thing, which is the limits block and which is not a footnote. The artifact prints <strong>nine</strong> things it cannot tell you, each one naming the instrument that would settle it:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  LIMITS/,/second machine/p' | head -40
  LIMITS -- what this artifact cannot tell you, printed not footnoted,
  and each one names the instrument that would settle it:
    * ANY CYCLE COUNT.  There is no counter this process can open:
      RDPMC is a #GP, perf_event_open is EACCES, and the kernel
      reports perf_event_paranoid above.  Every duration in this file
      is a DURATION, and a duration bounds a count without measuring
      it.  Settled by perf_event_open with a paranoid setting below 4
      and a PMU passthrough from the host.
    * WHETHER CR0 TO CR4 HOLD THE VALUES THE KERNEL REPORTS.
      Section 2 prints arch_prctl's SMEP/SMAP/SHSTK bits and section
      3 measures that every read of CR0-CR4 and CR0-CR8 is a fault.
      A consequence is not a reading.  Settled by a CPL 0 program.
                </pre>
            </div>
                <p>Each limit ends in a sentence of the form <em>settled by X</em>, and that is the part worth copying. A limit that says &ldquo;this was not measured&rdquo; is a dead end. A limit that says &ldquo;a twenty-line program at CPL 0 would settle it&rdquo; is a <strong>work item</strong>, and it tells a reader exactly what they are missing in order to do the work themselves. Four of the nine gaps in this course are properties of the instrument rather than of the subject, and the last one &mdash; whether a second machine agrees &mdash; is the one no amount of cleverness on one machine can fix.</p>
                <p>The verdict the artifact prints is the sentence to keep:</p>
                <div class="formula">
   What this artifact can support: an
   inventory of what a ring-3 process can
   and cannot learn about the machine it is
   running on, with every entry of the
   CANNOT column a signal number rather
   than a quotation, and every entry of
   the CAN column a bit pattern read out
   of a register on this CPU.

   What it cannot support: any claim about
   a control register's value, any cycle
   count, any exception's class, and any
   statement about a second machine.  Four
   of those five are properties of the
   instrument, not of the subject.
                </div>
                <p>That last clause is the course's real conclusion and it is worth more than any table here. <strong>Four of the five things this artifact cannot tell you are limitations of a program running at CPL 3, and one of them &mdash; a second machine &mdash; is a limitation of being a program at all.</strong> Every claim in this collection that is marked <code>INFERRED</code>, every mechanism that is named rather than measured, and every <code>QUOTED</code> row in every table is the same fact: the measurement decides what may be claimed, and a course that hides which of its numbers are measurements is teaching a reader to trust the wrong sentences.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-pmu">The Performance Monitoring Architecture</a></span>
                <span>End of The x86-64 Machine &middot; <a href="/courses">all courses</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
