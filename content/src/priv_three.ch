// Exceptions, Privilege and Mode Changes — Concept 7: three architectures
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_three() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Same Idea Under Three Architectures — Underlayer")
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
            <h1>The Same Idea Under Three Architectures</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="a11y-note" style="display:none">
                <p><strong>A note on this concept's evidence, before anything else.</strong> Everything below is quoted from architecture manuals and from the RISC-V specification source. <em>None of it was measured</em>, because this course was written on x86-64 and there is no AArch64 or RISC-V machine in the room. The artifact prints the same limit in its own limits block. <strong>Read this concept as a shape to look for on hardware you do have, not as a set of facts about hardware you do not.</strong> Every claim carries a document.</p>
            </div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>&ldquo;Ring 0&rdquo; is a vendor spelling. A course that teaches the mechanism and then says &ldquo;x86 calls it ring 0&rdquo; has taught one vendor's vocabulary and left you unable to read the other two manuals, which is a strange thing to do to a reader who will eventually need them.</p>
                <p>The reason this is worth a whole concept rather than a footnote is that the three designs <em>genuinely differ</em>, not just in naming. x86 puts the privilege level in a segment register and compares it against a field in a table. AArch64 puts it in the current exception level and compares it against a per-level vector base. <strong>RISC-V puts it in two bits of a status register and makes the question of who handles a given trap a writable field that firmware sets.</strong> Those are three different answers to the question &ldquo;where does the privilege decision live,&rdquo; and the third one is the interesting one.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the five-part shape, and the three spellings</h2>
                <p>Strip the vocabulary away and every one of these machines has the same five things:</p>
                <div class="formula">
   1. A TABLE the kernel owns and the user cannot read
   2. A per-cause REASON CODE
   3. A rule for WHO handles a given cause
   4. A way to get BACK
   5. A way for the kernel to PROVE the fault came
      from user mode

   Change the numbers.  Keep the five.
                </div>
                <p>Now the three.</p>
                <div class="hex-dump">
                <pre>x86-64
  levels         rings 0..3.  Only 0 and 3 are used by
                 an operating system today; 1 and 2 exist
                 for the historical OS/2 split.
  the table      IDT, 16 bytes per entry, indexed by
                 vector*16.  One for the whole machine.
  the rule       IF gate.DPL &lt; CPL THEN #GP(vector,1,0)
                 The level is a NUMBER in CS, compared
                 against a FIELD in a table.
  the drop       SYSCALL.  No check at all; CPL := 0.
  the return     SYSRET, which is #GP(0) at CPL != 0.
                 SYSEXIT is #GP(0) at CPL != 0.
                 The return has a check and the entry
                 does not -- backwards from intuition.
  user proof     CS.RPL on the saved frame; error-code
                 bit 2 (U/S) on #PF.

AArch64
  levels         EL0..EL3.  MORE levels than x86 has
                 rings, and they are asymmetric in a way
                 rings are not: EL2 is a hypervisor, not
                 "the second OS".
  the table      VBAR_ELx.  ONE PER LEVEL.  A vector
                 table, like the IDT, but the register
                 you read it from depends on where you
                 are.
  the rule       PSTATE.PAN.  With PAN=1, EL1+ may not
                 access EL0 data.  Structurally the same
                 job as SMAP, and reached with a
                 different instruction: STAC/CLAC set
                 and clear the permission, exactly as
                 x86's STAC/CLAC toggle EFLAGS.AC.
  the drop       SVC #imm16 -- an ORDINARY instruction
                 at any EL.  A 16-bit immediate, not a
                 register, so no argument marshalling in
                 the instruction at all.
  the return     ERET.
  the record     THREE CSRs, and this is the big one:
                   ESR_ELx   the syndrome: which exception
                             AND which of its many causes
                   FAR_ELx   the faulting address
                   ELR_ELx   where to return to
                 x86 squeezes the same three things into
                 a stack frame plus CR2.  AArch64 keeps
                 them in registers.
  categories     Four, not three: from a lower EL, from a
                 higher EL, from the current EL with SP0
                 selected, and from the current EL with
                 the process stack.  That last distinction
                 is about WHICH STACK the exception landed
                 on, and it is a fourth thing to get right.

RISC-V
  modes          M, S, U.  And this is the one that
                 differs most.
  the mandatory   M mode is MANDATORY.  Every RISC-V hart
                 implements it.  So there is a mode BELOW
                 user mode by construction, and it is
                 not optional and not virtualised away.
                 Nothing equivalent is true on x86 or
                 AArch64, where the lowest mode is
                 unprivileged.
  the table      mtvec, stvec, utvec.  ONE PER MODE.
  the rule       medeleg and mideleg.  Two registers,
                 one bit per exception CAUSE, saying
                 whether S or U handles it.
                 x86 hardwires the split at CPL 0.
                 AArch64 hardwires it at the EL boundary.
                 RISC-V makes it a FIELD FIRMWARE WRITES.
  the drop       ECALL (and EBREAK for a breakpoint).
  the return     MRET, which restores privilege from
                 mstatus.MPP.
  the record     Three CSRs again, and the naming is
                 better than either of the others:
                   mcause   the reason, an ENUM
                   mtval    the offending value, and
                            OPTIONAL per cause -- the
                            spec says it may be written
                            as zero where there is nothing
                            meaningful to put there
                   mepc     where to come back to
  the one to     mstatus itself.  MPP records the
  not skip       privilege to return to, and the handler
                 must save it before it does anything
                 else at all.  Get that wrong and the
                 return drops to the wrong mode.
</pre>
                </div>
                <p><strong>Two of those are worth a second look, because they are better ideas and they are portable.</strong></p>
                <p><em>RISC-V's <code>mtval</code> being optional per cause</em> is a genuinely better design than x86's, and it is worth copying. x86's <code>#PF</code> error code is a fixed-format bitfield whether or not every bit is meaningful for the event that occurred, and bit 3 means &ldquo;a reserved bit in a paging entry&rdquo; &mdash; which is a completely different kind of thing from every other bit, sharing a field with them. AArch64's syndrome is explicitly a <em>combination</em> of an EC (exception class) and an ISS (instruction-specific syndrome) whose meaning depends on the class, which is the same idea done properly: the low bits are generic, the high bits are interpreted according to what kind of event this was. <strong>Three architectures, one field, and the two newer ones both decided that the meaning of the bits should depend on the class of the event.</strong></p>
                <p><em>RISC-V's delegation as a writable field</em> is the other. It means an implementation can choose where a given trap is handled, and firmware can be changed to match the platform, without an ISA change. x86 and AArch64 fix the boundary in silicon. That is a real trade &mdash; a field firmware writes is a field firmware can get wrong, and a misconfigured delegation is a security bug &mdash; but it is the more flexible of the three designs and it is the direction the industry has been moving.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what the portability rule actually is</h2>
                <p>Strip the three tables down to a single line each, and the portable content is the shape rather than the number:</p>
                <div class="formula">
   x86-64   the level is a NUMBER in a segment register,
            compared against a field in a table

   AArch64  the level is a NUMBER in the current EL,
            compared against a per-level vector base

   RISC-V   the level is a PAIR OF BITS in a status
            register, and which level handles a given
            trap is DELEGATABLE, per cause
                </div>
                <p>And here is what a compiler author actually needs from this, in the order they need it:</p>
                <ol>
                    <li><strong>Which instruction enters the kernel, and does it need a marshalling convention?</strong> x86: <code>SYSCALL</code>, and yes &mdash; a convention exists and it is the operating system's, not the architecture's. AArch64: <code>SVC</code>, and the immediate is a 16-bit constant, so the number is in the instruction and the arguments go in the ordinary registers. RISC-V: <code>ECALL</code>, with the number in <code>a7</code> and arguments in <code>a0</code>&ndash;<code>a5</code> &mdash; and <code>a7</code> is <strong>the seventh</strong> register, chosen so that the first six arguments have the same numbers as x86's. <em>Every ISA arrived at a register-based convention; only x86 had to bend one because the hardware took two registers first.</em></li>
                    <li><strong>Which registers are clobbered?</strong> x86: <code>RCX</code> and <code>R11</code>, chosen by the hardware and impossible to change. AArch64 and RISC-V: none, because the convention does not have to dodge a return address &mdash; you simply keep the return address somewhere else.</li>
                    <li><strong>How does the return happen, and what checks it?</strong> All three have a dedicated return instruction. Only x86's has a privilege check on it (<code>SYSRET</code> is <code>#GP(0)</code> at CPL&nbsp;=&nbsp;0), and that asymmetry is a consequence of the design rather than a decision: because <code>SYSCALL</code> checks nothing, its return cannot rely on the entry having established anything.</li>
                </ol>
                <p><strong>The one-line portability rule that survives all three:</strong> the entry convention is not the architecture's, it is the operating system's, and it will outlive every kernel you have ever heard of. Emit against the ABI your target kernel documents, and treat the architecture manual as a source of constraints on that ABI rather than as a definition of it. <a href="/courses/priv/lessons/priv-convention">The convention concept</a> showed that on x86-64 this means five of the six facts come from Linux; on the other two machines the split is different, and the reason is the same.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the question to ask on a machine you have</h2>
                <p>You have an AArch64 or RISC-V machine, or a cross-compiler and an emulator. Do this, and it takes about twenty minutes.</p>
                <div class="formula">
  AArch64
    1. Read VBAR_EL1 out of /proc or with a debugger.
       Compare it to the IDT base you found in the
       x86 concept.  Both are "where the gates are",
       both are per-mode, and on AArch64 there are four
       of them and you can only read one.

    2. Find the vector table's entry for the exception
       you care about.  It is a pair of 64-bit
       instructions: the branch, and the handler
       address.  Not a 16-byte descriptor with a DPL in
       it -- there is no DPL.  The check is PSTATE.PAN
       plus the EL transition, and it lives in the
       instruction that raises the exception, not in
       a table.

    3. Ask: which stack did it land on, and who chose?

  RISC-V
    1. Read medeleg and mideleg.  They are in the
       machine-mode CSRs and you will need M-mode or a
       debugger to see them, which is itself the
       point: the delegation is a machine-mode
       register and a user-mode process cannot
       influence it.  Compare with x86, where the
       equivalent decision is baked into the gate's
       DPL and a user-mode process at least gets a
       #GP if it guesses wrong.

    2. Read mstatus.MPP in a trap handler.  This is
       the field the x86 course could not show you,
       because x86 has no equivalent: the hardware
       does not record where it came from in a
       register you can read, it records it in CS.

    3. Ask: is M-mode mandatory on this hart, and
       does this platform run an OS at all?  M-mode is
       mandatory even on a hart with no OS on it.
                </div>
                <p>And the question that ties all three together, which is the one worth carrying into the next course in this chain: <strong>in every case, the lowest privilege level is unprivileged, and in one case there is a mode below it that is not optional.</strong> That asymmetry is the difference between a design where the kernel is a guest and a design where the kernel is the ground floor. Both are legitimate; they answer different questions about what you are building on top.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Build the table yourself for a fourth architecture.</strong> A 32-bit ARM (ARMv7-A with the secure extensions) or an older PowerPC. <em>(32-bit ARM is the interesting one: it has banked registers for the modes, so the privilege level determines which register bank you are in, which is a design neither of these three uses.)</em></li>
                    <li><strong>Answer the portability question for your target.</strong> Which of the five parts of the shape is your operating system responsible for, and which is the hardware's? <em>(For x86-64: the table is the kernel's, the reason code is the hardware's, the rule is the hardware's, the return is split, and the user-mode proof is the hardware's but the <em>report</em> is the kernel's. Notice that part 1 and part 5 both leak across the boundary in different ways on different machines.)</em></li>
                    <li><strong>Argue the optional <code>mtval</code> design.</strong> Write two sentences for why &ldquo;this field may be zero depending on the cause&rdquo; is better than a fixed-format bitfield, and two for why it is worse. <em>(Better: a fault that has no meaningful value does not have to invent one, so the zero is honest. Worse: a handler that reads it without checking the cause has no way to tell &ldquo;zero&rdquo; from &ldquo;not applicable,&rdquo; which is the same problem as a <code>NULL</code> return from a function that cannot fail.)</em></li>
                    <li><strong>Find something all three architectures do the same way that is not on the list of five.</strong> <em>(Hint: all three have a defined reset state, all three have a way to enter the highest mode from the lowest, and all three have had at least one documented case where a fault in the handler is itself fatal. The third is the interesting one, and it is why RISC-V mandates that M-mode traps cannot be delegated.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-harness">the harness concept</a> closes the course by asserting which of these claims were measured and which were quoted &mdash; and the fact that this concept is the one where that distinction matters most is the argument for having the harness at all.</p>
                <p>Backwards, this concept reads the other seven as one instance of a design and asks how many other instances there are. <a href="/courses/priv/lessons/priv-vectors">The vector concept's</a> Intel-versus-AMD divergences are one data point: even within one architecture, &ldquo;the manual's number&rdquo; is not always portable. <a href="/courses/priv/lessons/priv-doors">The doors concept's</a> <code>SYSENTER</code> result is a second, and a stronger one, because there the divergence is not a name but an instruction's existence. <a href="/courses/priv/lessons/priv-errorcode">The error-code concept's</a> three formats are a third: <em>the same concept, expressed three ways, with the newest design making the best choice.</em></p>
                <p>Outward, the collection has a gap this concept makes visible. Everything in the last four concepts is about a <em>single</em> processor crossing a boundary. <a href="/courses/mem/lessons/mem-verify">The memory course's limits block</a> named its own exclusion explicitly &mdash; cache coherence, NUMA, and multiprocessor memory are the subject of the <em>Multiprocessor Architecture</em> course, which does not exist yet. And the thing this course has just taught transfers to that one intact: <strong>a table the kernel owns, a reason code per event, and a rule about who handles it are the shape of a cache-coherence protocol too</strong>, and the same discipline applies &mdash; read the second vendor's manual, quote the shape rather than the number, and check the field order.</p>
                <p>And the practical one. If you write a compiler backend, this concept is the one that saves you: the register convention for entering the kernel is not the architecture's, the number is not the architecture's, and the clobbered registers are the architecture's and you cannot change them. <strong>Five of the six facts in the x86-64 system-call ABI are an operating system's decision, and every one of the three architectures here has made a different set of them.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-errorcode">Three Error Codes and None of Them Visible</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-harness">The Harness, and the Eight Things It Refuses to Let Go</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
