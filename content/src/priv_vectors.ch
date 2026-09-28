// Exceptions, Privilege and Mode Changes — Concept 2: the vector numbers
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_vectors() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Numbers, and the Ones That Are Not Numbers — Underlayer")
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
            <h1>Numbers, and the Ones That Are Not Numbers</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The previous concept found a table of 4096 slots and could not read any of them. This one asks what the first thirty-two are <em>for</em>, and the answer is more interesting than a list.</p>
                <p>Two reasons to care. First, a number is not a name: vector 13 is <code>#GP</code> and vector 14 is <code>#PF</code>, and the difference between them changes whether your program's memory error is recoverable. Second &mdash; and this is the part that will cost you an afternoon if you do not know it &mdash; <strong>eight of the thirty-two mean different things depending on which company wrote the chip.</strong> Not &ldquo;are spelled differently.&rdquo; Different. One of them is a virtualization exception on Intel and a reserved vector on AMD; another is reserved on Intel and a hypervisor-injection exception on AMD. A kernel that reads the Intel table and runs on an AMD part has a bug that will appear on hardware that is not in the room.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three classes, and why the class matters more than the name</h2>
                <p>Every vector 0&ndash;31 is one of three kinds, and <strong>the kind determines where the saved instruction pointer points</strong>. That single fact is the reason the class exists as a separate column:</p>
                <div class="formula">
   FAULT   the instruction did not complete.
           saved RIP points AT the faulting instruction.
           -> it can be re-executed once the cause is fixed.

   TRAP    the instruction completed.
           saved RIP points AFTER it.
           -> resuming is safe, and a debugger can single-step.

   ABORT   the machine state is unreliable and RIP is
           UNDEFINED.  You cannot resume.

   INTERRUPT   not an exception at all.  It arrived from
                outside, asynchronously.  saved RIP points
                after the interrupted instruction.
                </div>
                <p>So when you read a manual that says &ldquo;divide error&rdquo;, the question you actually need answered is <em>can I retry this?</em> &mdash; and the answer lives in a column most tables put in small type.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/vec   name  cls/,/^   19/p'
   vec   name  cls  errcode  note
   0     #DE   F    no       divide error
   1     #DB   T    no       debug; class depends on the cause
   2     NMI   I    no       not an exception
   3     #BP   T    no       INT3; RIP points at the NEXT instruction
   6     #UD   F    no       invalid opcode; RIP points at the FAULTING instruction
   8     #DF   A    yes      abort; the saved RIP is UNDEFINED
  14     #PF   F    yes      page fault; error code has its OWN format
  16     #MF   F    no       x87; saved RIP is the NEXT DEFERRED point, not the fault
  17     #AC   F    yes      alignment check
  19     #XM   F    no       SIMD FP; AMD calls it #XF
</pre>
                </div>
                <p>Three rows in that extract are worth more attention than the other thirty.</p>
                <p><strong>Vector 1, <code>#DB</code>, has no single class.</strong> A debug register that fires on an <em>instruction fetch</em> is a fault, so you may retry; one that fires on a <em>data</em> access is a trap, so you may not. The class is a function of the cause, and the manual's class column for vector 1 is not a simplification &mdash; it is the honest answer.</p>
                <p><strong>Vector 8, <code>#DF</code>, is the one that is not a number at all in the useful sense.</strong> It is a class of its own, it pushes an error code that is always zero, and its saved RIP is <em>undefined</em> because the double fault means the machine could not even complete the bookkeeping for the first one. Worse, if a second fault occurs <em>while the double fault is being delivered</em>, the processor shuts down. There is no third state. <strong>If your operating system's fault handler is itself faulting, you get exactly two chances and then the machine stops</strong> &mdash; which is the entire reason the architecture has this vector and the entire reason the &ldquo;use a separate stack, via the IST field&rdquo; mechanism exists.</p>
                <p><strong>Vector 16, <code>#MF</code>, is a trap whose saved RIP points somewhere unexpected.</strong> The manual is unusually explicit: the saved RIP is the x87 instruction that was <em>about to be executed when the error condition was generated</em>, <em>which is not the instruction in which the error was detected</em>. The real faulting address is in the FPU's own instruction-pointer register. This is a three-way distinction &mdash; the CPU pushed one address, the fault was in another, and the difference is in a floating-point register &mdash; and it is the clearest example in the whole architecture of a saved RIP that will not mean what you assume it means.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: where the two vendors part company</h2>
                <p>The full table, with the disagreements marked in place:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/vec   name  cls/,/defined on both/p'
   9     -     -    no       coprocessor segment overrun; RESERVED
  15     -     -    no       RESERVED
  20     #VE   F    no       virtualization: Intel DEFINES IT, AMD says RESERVED
  28     -     -    no       RESERVED on Intel; AMD calls it #HV
  29     #VC   F    no       VMM communication; Intel's Table 7-1 wrongly says reserved
  30     #SX   A    no       security; Intel's Table 7-1 wrongly says reserved
  31     -     -    no       RESERVED

      defined on both: 19    Intel only: 1 (#20)    AMD only: 1 (#28)
</pre>
                </div>
                <p>There are three distinct kinds of disagreement here, and treating them as one is how people get this wrong.</p>
                <p><strong>Hard divergence (vector 20).</strong> Intel defines <code>#VE</code>, a virtualization exception raised on an EPT violation when the &ldquo;EPT-violation #VE&rdquo; VM-execution control is set. AMD's table says plainly &ldquo;20 Reserved.&rdquo; Same number, same slot in the IDT, opposite meanings. A program that installs a <code>#VE</code> handler and enables the control will, on AMD hardware, catch something else entirely &mdash; or nothing.</p>
                <p><strong>An AMD-only concept (vector 28).</strong> <code>#HV</code>, hypervisor injection, has no Intel assignment at all. If you are writing to the intersection of the two architectures, vector 28 is available to you. If you are writing to a specific one, it is not.</p>
                <p><strong>An Intel documentation error (vectors 29 and 30).</strong> This one is worth dwelling on because it is a different category again. Intel's own Table 7-1 &mdash; the table every course quotes &mdash; says vectors 22&ndash;31 are reserved. But Intel defines <code>#VC</code> (VMM communication) at 29 and <code>#SX</code> (security) at 30 elsewhere in the same volume, in the hypervisor and trusted-execution chapters, and the Linux kernel has <code>X86_TRAP_VC 29</code> in its own trap-number header. <strong>So the summary table in the authoritative manual contradicts the rest of the manual, and the summary table is the one people read.</strong></p>
                <div class="formula">
   What is safe to rely on, then?

   vectors  0..18   agree between vendors
                     (19 is the same vector, named #XM or #XF)
   vector   19      same meaning, different name
   vector   20      HARD divergence
   vector   28      AMD-only
   vectors  29,30   real on both; Intel's Table 7-1 is wrong
   vector   21      #CP, agrees
   vectors  22..27  reserved on both
   vector   31      reserved on both
                </div>
                <p>And one more piece of documentation unreliability, in the vector that never fires, which is almost charming: <strong>vector 9's class is stated three different ways by the same manual.</strong> The summary table calls it a fault; the reference section calls it an abort; a third table lists it among &ldquo;benign exceptions.&rdquo; It is moot &mdash; vector 9 has not been generated since the 486-era coprocessor, and AMD documents the condition as raising <code>#GP</code> today &mdash; but it is a clean demonstration that <em>citing a table is not the same as citing a fact</em>, and that the right response to a contradiction is to name it rather than pick one.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: raise some of them for real</h2>
                <p>Reading a table is not the same as watching one happen. The artifact raises six of them on the actual CPU:</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/Now raise some of them/,/does NOT fault/p'
   Now raise some of them for real.  These are ACTUAL faults on THIS cpu:
   divq by zero            (#DE 0)    SIGFPE   si_code=1    (0x01)
   idivq by zero           (#DE 0)    SIGFPE   si_code=1    (0x01)
   ud2                     (#UD 6)    SIGILL   si_code=2    (0x02)
   int3                    (#BP 3)    SIGTRAP  si_code=128  (0x80)
   int $0x80               (vector 128) no fault
   int $0x28               (vector 40) SIGSEGV  si_code=128  (0x80)
</pre>
                </div>
                <p>Read the last two rows together, because they are the demonstration and the prose afterwards is the conclusion.</p>
                <p>Vector 128 is inside 32&ndash;255, the user-defined range. This kernel owns vector 128 for the i386 system-call ABI, so <code>int $0x80</code> <strong>succeeded</strong> &mdash; it did not fault, it went to a real handler and came back with an answer. Vector 40 is also in the user-defined range, and this kernel has installed nothing there, so the process <strong>died</strong>.</p>
                <p><strong>The user chose the vector in both cases. The kernel decided what happened.</strong> That is the division of responsibility, and it is the whole reason the DPL check in the previous concept is a check against the <em>kernel's</em> table rather than against the caller's intent. A process may name a door; it may not choose what is behind it.</p>
                <p>And note <code>int3</code> giving <code>si_code</code> 128 rather than something more specific. <code>si_code</code> is the kernel's translation, and a breakpoint is a deliberate event with no fault classification to report. <a href="/courses/priv/lessons/priv-errorcode">The error-code concept</a> is about exactly this gap between what the CPU pushed and what a process can see.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Write a trap handler that retries.</strong> Which of vectors 0&ndash;31 would it be legal to resume from after fixing the cause? <em>(The faults: 0, 5, 6, 7, 10&ndash;14, 16, 17, 19, 20, 21. Not the traps 3 and 4, not the aborts 8 and 18, not the interrupt 2, and vector 9 never fires anyway.)</em> Then say what you would do about <code>#MF</code> specifically, given that its saved RIP is not the faulting instruction.</li>
                    <li><strong>Prove a vector is reserved, by triggering it.</strong> <code>int 0xFF</code> is in the user-defined range so the kernel handles it. But a <em>reserved</em> vector in 0&ndash;31 cannot be reached by <code>int</code> at all &mdash; write down why, in terms of the DPL the kernel would have had to install.</li>
                    <li><strong>Write the portability rule for your own target.</strong> Pick a vector you might use for your own signal-like mechanism. State which of the four portability classes it falls into (agreed / renamed / hard divergence / documentation error) and what you do about it. <em>(For example: on a system with a hypervisor you care about, 20 and 29 are both live, on different vendors, for different reasons.)</em></li>
                    <li><strong>Find a fourth kind of documentation problem.</strong> The course names three here: a hard divergence, a vendor-only addition, and a summary table that contradicts its own volume. Look for a fourth in a manual you have access to &mdash; a number that is stated in two places and differs, or a class column that disagrees with a reference section. <strong>Write down what you would have believed if you had only read the summary.</strong></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-doors">the doors concept</a> uses the fact you just established &mdash; that a process names a vector and the kernel owns it &mdash; to explain why <code>SYSCALL</code> is faster than <code>int $0x80</code>: it skips the table entirely, which is exactly why it also skips the DPL check. <a href="/courses/priv/lessons/priv-errorcode">The error-code concept</a> takes the &ldquo;error code&rdquo; column of this table and finds that it is not one format but three, and that <code>#PF</code>'s is a bitfield with a bit whose name is a trap.</p>
                <p>Backwards, <a href="/courses/priv/lessons/priv-table">the previous concept</a> gave you the table these numbers index into. And the forward-reference chain is worth naming: <a href="/courses/isa/lessons/isa-opcodes">the ISA course's opcode map</a> already told you <code>0F 0B</code> is <code>UD2</code>, a deliberately undefined opcode, and <a href="/courses/mem/lessons/mem-hierarchy">the memory course</a> told you a page fault is the price of a cold access. <strong>Both were naming vector 6 and vector 14 without saying so.</strong> Every course in this chain touches these numbers; none of them needed to teach them until the course whose subject they are.</p>
                <p>Outward: the <a href="/courses/jvm">JVM course</a> teaches a <em>software</em> exception mechanism, and the comparison is exact and instructive. A JVM's exception table is a table of numbers indexed by program counter, and it is a fault/trap distinction in the same shape &mdash; a bytecode handler may resume at the same instruction, a Java handler may not. <strong>The JVM reimplemented the fault/trap distinction in an object model, which is why Java checked exceptions exist and why &ldquo;finally&rdquo; blocks are not optional in the language.</strong> Nothing in the JVM knows this table exists; it had no need to.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-table">A Table You Can Locate and Not Read</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-doors">Four Ways In, and One of Them Is Not a Door</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
