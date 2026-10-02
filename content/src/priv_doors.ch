// Exceptions, Privilege and Mode Changes — Concept 3: the ways in
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_doors() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Four Ways In, and One of Them Is Not a Door — Underlayer")
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
            <h1>Four Ways In, and One of Them Is Not a Door</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>There is a gate table, a DPL on every gate, and a rule that refuses a transition when the DPL is too low. It is very tempting to conclude that <em>every</em> transition into the kernel goes through that check. <strong>It does not. Two of the three instructions people use to enter the kernel never look at the table at all</strong>, and the third is a vendor disagreement rather than a mechanism.</p>
                <p>That is worth understanding for its own sake, because &ldquo;the CPU checks the DPL&rdquo; is the mental model that a hundred explanations of system calls share, and it is wrong in a way that matters. It matters for a compiler author, who needs to know which entry sequences are checked and which are not. It matters for a kernel author, who has to do by hand what the hardware will not do. And it matters for anyone who has assumed that &ldquo;the hardware enforces privilege&rdquo; is a single uniform mechanism &mdash; <strong>because on this particular machine, the most popular fast entry path is a documented divergence between two vendors rather than a mechanism at all.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: what each instruction actually does</h2>
                <p>There is a family of x86 instructions for entering the kernel, and they are not variations on a theme. They differ in <em>where the target comes from</em> and <em>what checks happen on the way</em>.</p>
                <div class="formula">
   INT n / INT3
       where from?   the IDT, at offset n*16
       checked?      YES -- gate.DPL < CPL  ->  #GP
       saves?        CS, RIP, RFLAGS, and an error code
       cost           a full trap: table lookup, DPL check,
                      present check, canonicality check

   SYSCALL
       where from?   IA32_LSTAR, a model-specific register
       checked?      NO.  There is no gate, so there is
                      nothing whose DPL could be checked.
       saves?        RCX (the return RIP) and R11 (RFLAGS)
       cost           read three MSRs, load CS and SS, done

   SYSENTER
       where from?   IA32_SYSENTER_EIP
       checked?      NO, on either vendor
       valid?        Intel: yes.  AMD: NO -- illegal in
                      long mode, raises #UD
       cost           the cheapest of the three, where it exists

   The vDSO
       where from?   no transition at all
       checked?      nothing to check -- no mode change occurs
       cost           a normal function call into a page the
                      kernel mapped into this process
                </div>
                <p>The <code>SYSCALL</code> row is the important one, and it is the one that overturns the mental model. Read Intel's own pseudocode for the instruction: its entire guard clause is</p>
                <div class="formula">
   IF (CS.L != 1) OR (IA32_EFER.LMA != 1) OR (IA32_EFER.SCE != 1)
       THEN #UD;
   FI;
   ...
   CPL := 0;
                </div>
                <p><strong>There is no CPL test in there.</strong> <code>SYSCALL</code> is not a privileged instruction. It does not check who you are; it unconditionally sets the current privilege level to zero, reads three MSRs for the target and the new segment selectors, and goes. Every argument the program supplies is then the kernel's problem to validate, and the kernel must validate all of it, because the hardware did not.</p>
                <p>Compare that with <code>INT n</code>, which does the DPL check in hardware and therefore can trust that only callers the kernel intended got in. <strong>Trade one CPU cycle at the entry against auditing every argument after it.</strong> That is the design decision, and it explains both the speed and the security model.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: four arms, one measurement, and one refusal</h2>
                <p>Five timing arms, interleaved, minimum of nine attempts each, in TSC ticks. Remember rule 1 of the artifact: the TSC is a fixed-rate reference clock, not a count of core cycles, and the core clock moves inside a run. <strong>Only the ratios mean anything.</strong></p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/SYSCALL, getpid/,/vdso-clock/p'
      SYSCALL, getpid               1238.5
      int $0x80, getpid             6095.6
      libc getpid()                 1236.5

      SYSCALL, clock_gettime        1668.8
      vDSO  clock_gettime             60.4

      int80 / syscall                 4.92x
      syscall-clock / vdso-clock     27.65x
</pre>
                </div>
                <h3>The second pair is the result</h3>
                <p><code>clock_gettime</code> twice. Same function, same argument, same result, same process, same binary, same moment. The only difference is whether the CPU changed privilege level on the way. <strong>That 27&times; is the cost of a mode change, isolated.</strong> It is also the number the vDSO exists to eliminate, and it is why reading the clock in a well-written program costs tens of nanoseconds and in a naive one costs hundreds.</p>
                <h3>The first pair is a trap, and the artifact refuses to conclude</h3>
                <p>The obvious story about <code>int $0x80</code> is that the Linux i386 ABI hands arguments to the handler through <em>I/O ports</em>, one port access per argument, and I/O is not something a fast path pipelines. It is a good story. It is also <strong>not a conclusion this measurement can support</strong>, and the artifact says so rather than printing the story:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/What the first pair does NOT prove/,/section 8, R1/p'
   What the first pair does NOT prove, which this file is careful about:
   It is tempting to say `int $0x80 is slower because it does one I/O
   port access per argument`.  That is TRUE of the Linux i386 entry stub
   -- but the port accesses are executed by the KERNEL'S HANDLER, not by
   the INT instruction.  So this measurement cannot separate the cost of
   the hardware entry from the cost of two different kernel stubs.  The
   honest claim is the ordering and the ratio; the mechanism is named as a
   hypothesis and NOT as a finding.
</pre>
                </div>
                <p>This is worth more than the ratio it declines to explain. The first draft of this course tried to isolate the mechanism by timing the same syscall with zero arguments and with six. <strong>It cannot work</strong>, and the reason is instructive: the number of ports is decided by the kernel's knowledge of that syscall's declared arity, which a caller cannot vary at all. The experiment was removed rather than reported. <em>An experiment that cannot answer its question is not data.</em></p>
                <h3>The third instruction: a divergence, not a bug</h3>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/The third instruction/,/Both manuals are correct/p'
   The third instruction:
   sysenter                (the #UD)  SIGILL   si_code=2    (0x02)

   This is the course's sharpest portable result and it is NOT a bug.
   Intel SDM Vol 2B lists SYSENTER as VALID in 64-bit mode: "When
   executed in IA-32e mode, the SYSENTER instruction transitions the
   logical processor to 64-bit mode", with 64-bit-mode exceptions
   "same as in protected mode".  AMD64 APM Vol 2 sec 6.1.2 says the
   opposite: these instructions are ILLEGAL IN LONG MODE and result in
   an invalid opcode exception (#UD).  Both manuals are correct.  They
   disagree.
</pre>
                </div>
                <p>So a program that reaches for <code>SYSENTER</code> as its fast system-call path is <strong>correct on one vendor and takes <code>SIGILL</code> on the other</strong>, and there is no erratum to file against either company, because each is accurately documenting its own silicon. The Linux kernel encodes the split explicitly &mdash; <code>arch/x86/kvm/emulate.c</code> contains a comment that spells out both the 64-bit-mode and the compatibility-mode differences &mdash; and QEMU commit <code>c046a42c</code> does the same thing for the same reason. A build-time CPUID check is the only defence.</p>
                <p>And one correction, because the author of this course got it wrong first. The folklore says &ldquo;<code>SYSENTER</code> from ring 3 raises <code>#GP(0)</code>.&rdquo; <strong>That is false on both vendors.</strong> There is no CPL check anywhere in <code>SYSENTER</code>; it is unprivileged by design, and running it from ring 3 is its entire purpose. Intel's only <code>#GP(0)</code> condition is a null <code>IA32_SYSENTER_CS</code>. The <code>#UD</code> this machine raises has nothing to do with privilege at all &mdash; it is AMD having removed the instruction from long mode. <em>Two wrong beliefs cancelling into a right observation is not evidence,</em> and the draft that nearly published that story is retraction R2 in the artifact.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: what each door costs you, concretely</h2>
                <div class="formula">
  DESIGN COST OF EACH ENTRY, which is not the
  performance cost and is much higher:

  SYSCALL / SYSENTER
    + no argument validation needed from the CPU
    + three registers are clobbered: RCX, R11, and
      the flags.  You must tell your compiler.
    - EVERY argument must be validated by hand.  The
      hardware checked nothing.  A missed check is a
      kernel bug reachable from unprivileged code.
    - you must arrange the stack yourself.  SYSCALL
      does NOT save RSP.  (SYSEXIT is the privileged
      one and it is #GP(0) at CPL != 0, and SYSRET
      is #GP(0) at CPL != 0 -- so the return path has a
      check and the entry path does not, which is
      backwards from what you would guess.)

  INT n
    + the CPU checks DPL, present, and canonicality
    + the CPU pushes the whole frame including an
      error code
    - the frame layout is fixed by the architecture
    - vector numbers are a shared, scarce namespace

  THE vDSO
    + no mode change, so none of the above
    + the kernel can implement it however it likes
    - it is a copy in user memory.  It can be
      OUTDATED relative to the kernel.  A user program
      that trusts a vDSO result about something the
      kernel knows better is trusting a cache.
    - the kernel must keep its ABI stable forever,
      because user binaries outlive kernels.  That is
      a much bigger constraint than a gate table.
                </div>
                <p>The vDSO's cost deserves the emphasis, because it is the one nobody thinks about. <strong>Every operating system pays it and most people never see it:</strong> once the kernel publishes a vDSO with a set of exported functions, it can never change their behaviour in a way a running program would notice, and it can never remove one. That constraint outlives every kernel version decision, and it is why some of the fastest things in Linux have been awkward for twenty years.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Re-derive the 27&times; yourself.</strong> Time <code>clock_gettime</code> through <code>syscall(SYS_clock_gettime, ...)</code> and through the libc wrapper. Then time <code>syscall(SYS_getpid)</code> and <code>getpid()</code>. Compute the four ratios. <em>Expect the two clock ratios to agree closely and the two pid ratios to not, and work out why before you read on.</em> <strong>Which of the four is a measurement of the boundary, and which is a measurement of the boundary plus something else?</strong></li>
                    <li><strong>Find out whether your machine has a vDSO and whether libc is using it.</strong> <code>ldd --version</code> names the mechanism; <code>strace -c -e trace=clock_gettime</code> shows whether the syscall happens at all. On glibc 2.31+ the vDSO is conditional at runtime, so the answer is a property of your kernel and not of your libc. <strong>Now explain why a program built on such a machine and run on one without it must still be correct.</strong></li>
                    <li><strong>Write the argument validation <code>SYSCALL</code> obliges you to do.</strong> Pick one syscall and list every argument the kernel must check, and what it must check it against, before it may dereference it. <em>(Pointer: range, alignment, and the object it names. A pointer the hardware will happily put in a register is a pointer the kernel has not yet agreed is real.)</em></li>
                    <li><strong>Decide what your own project does about SYSENTER.</strong> One of: use <code>SYSCALL</code> always; use <code>SYSENTER</code> behind a CPUID check; never enter the kernel at all. <strong>State which, and state what you will do when the check is wrong.</strong> The third option is not a joke &mdash; the vDSO is how the real answer looks.</li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-convention">the convention concept</a> takes the row labelled &ldquo;syscall number&rdquo; in this model &mdash; the number <code>SYSCALL</code> does <em>not</em> put anywhere &mdash; and reads it out of the kernel's own machine code, because the architecture never mentions it. <a href="/courses/priv/lessons/priv-canonical">The canonical-address concept</a> then finds the other thing that makes ring 3 ring 3.</p>
                <p>Backwards, the dependency is direct. <a href="/courses/priv/lessons/priv-vectors">The vector concept</a> established that a process names a vector and the kernel owns what happens, and this concept is the consequence: an instruction that bypasses the table gets its speed from bypassing the ownership too. <a href="/courses/img/lessons/img-vdso">The executable-images course's vDSO concept</a> already said that entering a syscall is expensive to enter and left it there; that sentence is now a measurement.</p>
                <p>Outward, the portability lesson is the one to carry. <strong>Two companies document the same instruction incompatibly, both correctly, and no erratum exists.</strong> That is not a curiosity about the 1990s; it is the normal condition of a specification written by vendors rather than by a standards body, and it is why <a href="/courses/priv/lessons/priv-three">the three-architecture concept</a> exists at all &mdash; AArch64 has <code>SVC</code> and RISC-V has <code>ECALL</code>, and neither has this particular disagreement, but each has its own. <em>Read the second vendor's manual before you rely on the first vendor's manual.</em> That is the whole transferable rule.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-vectors">Numbers, and the Ones That Are Not Numbers</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-convention">The Convention, in the Kernel's Own Bytes</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
