// The x86-64 Machine — Concept 1: SYSCALL and its registers
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_syscall() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("SYSCALL and the Four Registers It Touches — Underlayer")
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
            <h1>SYSCALL and the Four Registers It Touches</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>There is exactly one instruction in long mode that a user process can execute to reach the kernel, and it is one byte long. Everything else on the privileged side of the boundary refuses. That asymmetry &mdash; one instruction in, fifty instructions out &mdash; is the shape of the whole machine, and a reference that lists the privileged instructions without measuring that asymmetry is a list and not a reference.</p>
                <p><code>syscall</code> has a small, exact, checkable promise: on entry it writes the address of the following instruction into <code>RCX</code> and the <code>RFLAGS</code> it saved into <code>R11</code>, and the kernel entry path restores the rest on the way back. <strong>Two registers destroyed, and the sentence is worth having only if you know it is two and not fifteen.</strong> The measurement below puts thirteen markers in thirteen registers and reads them back across a real Linux system call.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the convention is two rows long, and the ISA is the only part of it that is architecture</h2>
                <p>Print the convention first, because it is four lines and every one of them is a decision somebody made:</p>
                <div class="formula">
   THE x86-64 SYSTEM CALL CONVENTION

     RAX   the system call NUMBER going in,
           and the RETURN VALUE coming out
     RDI RSI RDX R10 R8 R9
           the six arguments, and the fourth
           one is R10 and not RCX
     RCX   DESTROYED: the address of the
           instruction after the `syscall`
     R11   DESTROYED: the RFLAGS saved on
           the way in
     CF    NOT used on x86-64.  A negative
           value in RAX IS the error.  The
           clear-carry convention is i386 only.

   Of the twelve rows, TWO are the
   architecture.  The other ten are LINUX,
   and `grep "system call number" ` in the
   Intel SDM finds nothing.
                </div>
                <p>That split is the whole of why the fourth argument is <code>R10</code>. <code>RCX</code> is busy holding the return RIP, and the SysV <em>function</em> call convention had already given <code>RCX</code> to the fourth integer argument. The two conventions collided and Linux renumbered around it. <a href="/courses/x86abi/lessons/x86-calling">The ABI course</a> measured the function side &mdash; sixteen of sixteen callers at four optimisation levels put argument four in <code>RCX</code> &mdash; and this course measures the system-call side, so the contrast is two measurements rather than a story.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: thirteen markers, one system call, and the two that had to be put first</h2>
                <p>Here is the whole table. A distinct marker goes into each of the thirteen registers <em>other than</em> <code>RAX</code> and <code>RCX</code>, one <code>syscall</code> executes, and each register is read back in the same inline-assembly block before the compiler has had a chance to touch anything:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  SYSCALL | register/,/^  SYSCALL | r15/p'
  SYSCALL | register | marker in | marker out | verdict
  SYSCALL | rbx | 0xb000000000000010 | 0xb000000000000010 | SURVIVED
  SYSCALL | rdx | 0xb000000000000020 | 0xb000000000000020 | SURVIVED
  SYSCALL | rsi | 0xb000000000000030 | 0xb000000000000030 | SURVIVED
  SYSCALL | rdi | 0xb000000000000040 | 0xb000000000000040 | SURVIVED
  SYSCALL | rbp | 0xb000000000000050 | 0xb000000000000050 | SURVIVED
  SYSCALL | r8  | 0xb000000000000060 | 0xb000000000000060 | SURVIVED
  SYSCALL | r9  | 0xb000000000000070 | 0xb000000000000070 | SURVIVED
  SYSCALL | r10 | 0xb000000000000080 | 0xb000000000000080 | SURVIVED
  SYSCALL | r11 | 0xb000000000000090 | 0x0000000000000202 | CLOBBERED
  SYSCALL | r12 | 0xb0000000000000a0 | 0xb0000000000000a0 | SURVIVED
  SYSCALL | r13 | 0xb0000000000000b0 | 0xb0000000000000b0 | SURVIVED
  SYSCALL | r14 | 0xb0000000000000c0 | 0xb0000000000000c0 | SURVIVED
  SYSCALL | r15 | 0xb0000000000000d0 | 0xb0000000000000d0 | SURVIVED
  SYSCALL | arms 26 | survived 24 | clobbered 2
                </pre>
                </div>
                <p>Two arms of the run, thirteen registers each, and <strong>exactly one register per run came back clobbered: <code>R11</code></strong>, and its value is <code>0x202</code> &mdash; an <code>RFLAGS</code> word with bit 1 set, which is the bit the ISA requires to be set in every <code>RFLAGS</code> and is what makes the saved flags recognisable as flags. (Bit 2 is the parity flag, so the low three digits of this number depend on the parity of the process id that came back in <code>RAX</code> and the two recorded runs differ there. <strong>Quote the relation, not the word.</strong>)</p>
                <ul>
                    <li><strong>Twelve of thirteen survive, across two arms.</strong> That is the ISA's promise and Linux's convention agreeing, and it is a measurement rather than a quotation because the markers are distinct in every digit and the compiler is not allowed to touch the registers the block names in its clobber list.</li>
                    <li><strong><code>RCX</code> is deliberately absent from the table.</strong> The ISA says it holds the return RIP and <a href="/courses/x86abi/lessons/x86-calling">the ABI course measured that bit for bit</a>. A row for <code>RCX</code> here would have said &ldquo;clobbered&rdquo; and taught nothing; a row reading &ldquo;holds the return address&rdquo; would have restated another course's measurement, which is the mistake this collection's harnesses exist to prevent.</li>
                    <li><strong>The markers are pasted into the assembly text, not passed as operands.</strong> A marker passed as an <code>&quot;m&quot;</code> constraint and typed as <code>0x0b00000000000008</code> instead of <code>0x0b000000000000080</code> compiles, runs, and prints a verdict that is right for the wrong number &mdash; the two agree in their low fourteen digits. Two levels of stringification cost nothing.</li>
                </ul>
                <h3>Why there are three blocks and not one</h3>
                <p>The first version of this measurement asked for fourteen <em>outputs</em> in a single <code>asm</code> statement. It cannot be written: once <code>RAX</code> and <code>RCX</code> are clobbered there are fewer than fourteen allocatable registers, so <code>gcc</code> allocated one for a compiler value, and the block died with <strong><code>SIGBUS</code></strong> because it had overwritten the address of one of its own output slots.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/WHY THREE BLOCKS/,/overwritten/p'
  SYSCALL | WHY THREE BLOCKS AND NOT ONE, which is R3 in section 7:
  SYSCALL | there are fewer than fourteen allocatable registers once
  SYSCALL | rax and rcx are clobbered, so a fourteen-output asm block
  SYSCALL | cannot be written at all; the first version asked for one
  SYSCALL | and died with SIGBUS, because the compiler was holding
  SYSCALL | the ADDRESS of one of the fourteen output slots in a
  SYSCALL | register the body had already overwritten.
                </pre>
                </div>
                <p>And that bug produced a <em>wrong answer that was still wrong after the fix was not yet applied</em>, which is the subject of retraction R4: a first table reported all fifteen registers clobbered, because the clobber list named six registers the body touched and said nothing about the other seven. <strong>A wrong result that agrees with a story you have already written down is the hardest kind to catch, and this one did.</strong></p>
                <div class="formula">
   THE GENERAL FORM, and it is the ninth time this
   collection has learned it.

   A clobber list is a CLAIM about what your
   assembly modifies.  A register the COMPILER
   allocated is not one your assembly named.
   Three consequences, in order of how often
   they have cost somebody a day:

     1. A register your body WRITES and does
        not name is a wrong result.
     2. A register your body COUNTS with and
        does not name is a wrong result that
        only appears on the SECOND iteration.
     3. A register gcc allocated to HOLD one
        of your outputs is a SIGBUS, and the
        symptom is a crash in a program whose
        every other failure mode is a number.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the number, the error, and the six arguments that were ignored</h2>
                <p>Three arms, and the middle one is the interesting one because the wrapper is one of the things under test:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/getpid, six arguments/,/caller cannot vary/p'
    getpid, six arguments, RAW         = 1037820
    and getpid() through libc          = 1037820   same ? YES
    syscall number 9999, RAW           = -38, i.e. -ENOSYS
    and the same call through libc     = -1 with errno 38
    A bad number is an ERROR RETURN, not a fault: the kernel
    checked the number at the boundary, returned -ENOSYS in RAX,
    and on x86-64 it did NOT set CF.  The clear-carry-on-error
    convention is the i386 one.  And the SIX arguments were
    accepted and ignored: getpid takes none, the kernel reads the
    number of arguments from the call SITE'S declared arity, and
    this call site is libc's, which is why a caller cannot vary
    the cost of a system call by passing more arguments.
                </pre>
                </div>
                <ul>
                    <li><strong>The raw value and libc's agree</strong>, which is the control that proves the <code>syscall</code> really was a system call and not a <code>nop</code> that happened to leave the markers alone.</li>
                    <li><strong>An unknown number is a return, not a fault.</strong> <code>-38</code> in <code>RAX</code> is <code>-ENOSYS</code>; libc turns that into <code>-1</code> and sets <code>errno</code> to 38. A first version of this file printed libc's <code>-1</code> and wrote a sentence about <code>-ENOSYS</code> beside a number that was not it &mdash; <strong>the same failure as a transcribed hex digit, in a different column.</strong></li>
                    <li><strong>Carry flag: not set.</strong> The clear-carry-on-error convention is the i386 one and it does not apply in long mode, which is one of those facts that is quoted in a great many places and costs one instruction to check.</li>
                    <li><strong>Six arguments to a zero-argument call, accepted.</strong> The kernel reads the number of arguments from the call <em>site's</em> declared arity, and the call site is inside libc, so a caller cannot make a system call dearer by passing more arguments. <a href="/courses/priv/lessons/priv-harness">The privilege course</a> deleted an entire experiment that tried to vary this, and this file says why in a sentence rather than repeating the experiment.</li>
                </ul>
                <h3>What this concept cannot see</h3>
                <p>Three MSRs decide where a system call goes and what is cleared on the way in: <code>IA32_STAR</code>, <code>IA32_LSTAR</code> and <code>IA32_SFMASK</code>. <code>RDMSR</code> is a <code>#GP</code> from ring 3 &mdash; measured, in the third concept &mdash; and <code>/dev/cpu/0/msr</code> is root-only, also measured, in the eighth. So the register convention above is a convention <em>about registers</em>, and the values in the three MSRs are a convention about a memory the process cannot read. The privilege course got the same information from the vDSO's bytes, which is a weaker source and says so.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the table before you read anything else.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 2D. <em>(Expect twelve survivors and one clobbered, and the clobbered one to be <code>r11</code>. If a second register comes back clobbered, do not assume the CPU changed: look at whether your build has a seccomp filter, an audit rule, or a different kernel, because all three can rewrite the register file on the way through.)</em></li>
                    <li><strong>Add a fourteenth register and watch the artifact die.</strong> Take the three <code>asm</code> blocks in <code>sysdump.c</code> and put all thirteen markers into one block, with only the six you name in the clobber list. <em>(Expect a <code>SIGBUS</code>, not a number. Then name all thirteen in the clobber list and the compiler runs out of registers and tells you so. Both failures are the same lesson and the second one is louder.)</em></li>
                    <li><strong>Measure the <code>R11</code> bit that is not parity.</strong> The <code>0x202</code> above has bit 1 set and bit 2 clear. Write the marker for <code>R11</code> as the <em>saved flags</em> and print bit 9, the interrupt-enable flag, instead of the whole word. <em>(Expect bit 9 set, because <code>IF</code> is a caller's flag and the entry path preserves it. Then clear <code>IF</code> before the <code>syscall</code> and confirm the kernel has put it back, which is a different claim and needs a different measurement.)</em></li>
                    <li><strong>Find the collision in code you did not write.</strong> Take any C file with a hand-written assembly callee that makes system calls and check, for each call, what the code assumes about <code>RCX</code> and <code>R11</code>. <em>(Expect to find at least one place that keeps a live value in <code>RCX</code> across a system call because the author was thinking about a function call. The two conventions share five of their six argument registers, which is exactly why the sixth is the interesting one.)</em></li>
                    <li><strong>Count how many system call numbers your program can name.</strong> If you are writing a backend, the question is not &ldquo;can I issue a system call&rdquo; but &ldquo;which numbers, and what does each cost, and does the answer change if the kernel has a vDSO path for it.& <em>Expect the answer to be a table with three columns &mdash; number, arguments, and whether there is a faster path &mdash; and expect the third column to be the one that decides the design.</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/x86abi/lessons/x86-calling">the ABI course's calling-convention concept</a> measured the function side of this same collision, and <a href="/courses/priv/lessons/priv-doors">the privilege course's mode-change concept</a> measured the cost of getting here at all: the same function through a <code>syscall</code> and through the vDSO differed by more than an order of magnitude, and that ratio <em>is</em> the cost of a privilege change with everything else held constant. <a href="/courses/isa/lessons/isa-modes">The ISA course</a> is where the <code>0F 05</code> encoding lives.</p>
                <p>Forwards. The instruction brings you in; the next concept is what happens when the CPU wants to send you back out, and it is a table of thirty-two vectors rather than a convention. And the two registers this page could not see &mdash; <code>STAR</code> and <code>LSTAR</code> &mdash; are MSRs, which is the subject of the fourth concept, and the reading that would settle them is a <code>#GP</code>, which is the subject of the third.</p>
                <p>Outward. The <code>syscall</code> entry path is the one place where a compiler backend's register allocation and the kernel's register convention are the same table, and the collision between them is why the fourth argument is <code>R10</code>. The next course in this section is about the data path rather than the machine, and it inherits the <code>movdqa</code> trap from the eighth concept here as its standing example of a compiler strengthening an instruction you asked for by name.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys">The x86-64 Machine</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-exceptions">All Thirty-Two, As an x86-64 Reference</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
