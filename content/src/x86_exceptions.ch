// The x86-64 Machine — Concept 2: all thirty-two vectors
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_exceptions() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("All Thirty-Two, As an x86-64 Reference — Underlayer")
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
            <h1>All Thirty-Two, As an x86-64 Reference</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>There are thirty-two vector numbers reserved for the processor's own use and the rest of a byte's range belongs to whoever installs a gate. Every number in the first thirty-two has a name, a class, and a decision about whether it pushes an error code &mdash; and roughly a third of those numbers mean nothing at all on the silicon you are running on.</p>
                <p><a href="/courses/priv/lessons/priv-vectors">The privilege course</a> printed the thirty-two as a list. This concept prints them as a <em>reference</em>, and the difference is a column: every row says whether this course raised the exception on this machine or is quoting a document. <strong>Six rows say <code>MEASURED</code>. Twenty-six say <code>QUOTED</code>.</strong> That ratio is the honest state of the subject from ring 3, and a table without the column would have presented twenty-six quotations with the same authority as six observations.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: class, error code, and why the class is the interesting field</h2>
                <p>Every exception carries three things beyond its number: a mnemonic, a <strong>class</strong>, and whether it pushes a 32-bit error code. The class is the field that matters, because it decides where the saved instruction pointer points when the handler runs &mdash; and that is the only reason the class exists.</p>
                <div class="formula">
   THE FOUR CLASSES, and the class is the ONLY
   reason the saved RIP differs.

   F  fault     saved RIP = the FAULTING
                instruction, which has NOT run
   T  trap      saved RIP = the NEXT
                instruction; this one HAS run
   A  abort     the saved RIP is UNDEFINED;
                the machine state is not
                reliable enough to return from
   I  interrupt not an exception at all: an
                external event, async, and the
                handler returns to the next
                instruction
   -  reserved  nothing is defined

   One vector has two classes.  #DB is a
   TRAP when a data breakpoint fires and a
   FAULT when a task switch with the TSS T
   bit does.  The class is a property of the
   CAUSE, not of the vector.
                </div>
                <p>The error code is a second, separate question, and it has its own shape per exception: the three segment faults and <code>#PF</code> push a selector-and-present word, <code>#DF</code> pushes zero, and <code>#CP</code> pushes a third format that is not the other two. <strong>What a ring-3 process gets instead of all of that is <code>si_code</code>, which is the kernel's translation</strong> &mdash; and section 4 of the artifact measures how much of the original survives the translation. One of six bits.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: the six that can be raised, and what came back</h2>
                <p>Every arm below is a forked child with the signal handlers reset, and the result crosses the fork through a <code>MAP_SHARED</code> page the child's own handler wrote. Nine <code>int $N</code> vectors are in the table too, because the <em>shape</em> of their failure is the point.</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  RAISE | ud2/,/^  RAISE | int \$0x01/p' \
    | sed 's/0x[0-9a-f]\{12\}/&lt;per-run address&gt;/'
  RAISE | ud2                                               | #UD 6   | sig 4  | 2    | 0x&lt;per-run address&gt; | the faulting INSTRUCTION, for SIGILL
  RAISE | int3                                              | #BP 3   | sig 5  | 128  | 0x&lt;per-run address&gt; | the RIP the kernel chose to report, for SIGTRAP
  RAISE | int1                                              | #DB 1   | sig 5  | 1    | 0x&lt;per-run address&gt; | the RIP the kernel chose to report, for SIGTRAP
  RAISE | EFLAGS.TF set, then two more instructions         | #DB 1   | sig 5  | 2    | 0x&lt;per-run address&gt; | the RIP the kernel chose to report, for SIGTRAP
  RAISE | write through a NULL pointer                      | #PF 14  | sig 11 | 1    | 0x&lt;per-run address&gt; | the exact ADDRESS, a mapping failure
  RAISE | write to a PROT_READ page                         | #PF 14  | sig 11 | 2    | 0x&lt;per-run address&gt; | the exact ADDRESS, a protection failure
  RAISE | touch a PROT_NONE page                            | #PF 14  | sig 11 | 2    | 0x&lt;per-run address&gt; | the exact ADDRESS, a protection failure
  RAISE | execute a page mapped RW and not X                | #PF 14  | sig 11 | 2    | 0x&lt;per-run address&gt; | the exact ADDRESS, a protection failure
  RAISE | READ a PROT_READ page, the control                | none    | sig 0  | 0    | 0x&lt;per-run address&gt; | the control: the page WAS readable
  RAISE | int $0x01                                         | #GP 13  | sig 11 | 128  | 0x&lt;per-run address&gt; | nothing: a #GP has no address
  RAISE | int $0x05                                         | #GP 13  | sig 11 | 128  | 0x&lt;per-run address&gt; | nothing: a #GP has no address
  RAISE | int $0x0e                                         | #GP 13  | sig 11 | 128  | 0x&lt;per-run address&gt; | nothing: a #GP has no address
  RAISE | int $0x41                                         | #GP 13  | sig 11 | 128  | 0x&lt;per-run address&gt; | nothing: a #GP has no address
  RAISE | int $0xff                                         | #GP 13  | sig 11 | 128  | 0x&lt;per-run address&gt; | nothing: a #GP has no address
                </pre>
                <p>The addresses are elided by the <code>sed</code> in that command rather than by an author, and the reason is worth stating once for the whole course: <strong>an address is not a measurement.</strong> This is a position-addressed binary with ASLR and a randomised heap, so every run produces different values, and a page that quotes one invites a reader to run the artifact, see a different number, and conclude that something changed when nothing did. What is worth quoting is the shape: <code>si_addr = 0</code> for a #GP and for a null dereference, and a page address for the other three.</p>
                </div>
                <h3>Four things in that table that are not in the textbook</h3>
                <ul>
                    <li><strong><code>int1</code> and the trap flag arrive as the same vector with different <code>si_code</code>.</strong> <code>int1</code> gives <code>1</code> and setting <code>EFLAGS.TF</code> gives <code>2</code>. That is the #DB row's two classes showing up as two signals, and it is the only direct evidence in this course that the class field is a property of the cause rather than of the number.</li>
                    <li><strong>All nine <code>int $N</code> vectors give exactly 128.</strong> Vectors 1, 5, 6 and 14 have descriptor privilege level 0; the unused vectors 32&ndash;255 have no gate at all. A user process does not get to choose where a vector <em>goes</em>, only that the gate's DPL permits entry. Both failures are the same number, and the number is a #GP with no address.</li>
                    <li><strong>Three page faults, two numbers.</strong> The null dereference is <code>1</code>; the read-only write, the <code>PROT_NONE</code> touch and the execute of a non-executable page are all <code>2</code>. The CPU's error code has a write bit and an instruction bit in it and a demand-paging system needs both; ring 3 sees one bit, and it is the present bit.</li>
                    <li><strong>The divide-by-zero arm had to be written in assembly.</strong> The first version was <code>volatile long z = 0; d / z;</code> and at <code>-O2</code> gcc saw a division by a constant zero, removed the division, and the probe <em>returned</em>. The table would have said a divide by zero does not fault on this machine, and it would have been the compiler talking. A <code>volatile</code> on a locally initialised object is not enough; the value has to arrive from somewhere the optimiser cannot see, and the instruction has to be named.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the whole table, and the census that had to be made to add up</h2>
                <p>All thirty-two, with the two columns that make it a reference rather than a list. Abbreviated to the interesting columns &mdash; the full table is in the artifact and the harness asserts all thirty-two rows exactly:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  VEC | num/,/^  VEC | 31/p'
  VEC | num | mnemonic | class | error code | source | note
  VEC | 0   | #DE     | F     | no         | MEASURED | divide error
  VEC | 1   | #DB     | T     | no         | MEASURED | debug; TRAP for a breakpoint, FAULT for a task switch
  VEC | 2   | NMI     | I     | no         | QUOTED   | not an exception
  VEC | 3   | #BP     | T     | no         | MEASURED | INT3; saved RIP is the NEXT instruction
  VEC | 4   | #OF     | T     | no         | QUOTED   | INTO; saved RIP is the NEXT instruction
  VEC | 5   | #BR     | F     | no         | QUOTED   | BOUND; not encodable in 64-bit mode
  VEC | 6   | #UD     | F     | no         | MEASURED | invalid opcode; saved RIP is THIS one
  VEC | 8   | #DF     | A     | yes        | QUOTED   | abort; the saved RIP is UNDEFINED
  VEC | 13  | #GP     | F     | yes        | MEASURED | general protection
  VEC | 14  | #PF     | F     | yes        | MEASURED | page fault; the error code has its OWN format
  VEC | 19  | #XM     | F     | no         | QUOTED   | SIMD FP; AMD calls it #XF
  VEC | 20  | #VE     | F     | no         | QUOTED   | virtualization; Intel defines it, AMD RESERVED
  VEC | 28  | -       | -     | no         | QUOTED   | RESERVED on Intel; AMD calls it #HV
  VEC | 29  | #VC     | F     | no         | QUOTED   | VMM communication; Intel's own table says reserved
  VEC | 30  | #SX     | A     | no         | QUOTED   | security; Intel's own table says reserved
                </pre>
                </div>
                <p>Six rows are measured: <strong>0, 1, 3, 6, 13 and 14</strong>. The rest are quoted, and the reason is not laziness: deciding a class needs the saved RIP, and a ring-3 process never sees one, because the kernel does not put it in the <code>siginfo</code>. So the <em>class</em> column is quoted on all thirty-two rows even where the vector itself was raised, and the <code>MEASURED</code> in the source column means the fault happened and the signal number was read.</p>
                <h3>The vendor census, which is a partition and had to be made to be one</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  VENDOR |' | head -4
  VENDOR | reserved on BOTH 9 | Intel only 1 (#20) | AMD only 1 (#28)
  VENDOR | same number, different name 1 (#19) | defined on both 20
  VENDOR | and the four counts are a PARTITION: 20 + 1 + 1 + 9 + 1 = 32
  VENDOR | Two rows that the second draft got wrong and this one
                </pre>
                </div>
                <p>Four categories, and they add up to thirty-two because a table of vendor differences that does not add up is a table of a typo. The first version printed <code>21, 1 and 0</code>: it read row 28 twice, once as AMD-only and once as reserved, and counted #19 as &ldquo;defined on both&rdquo; rather than as the renamed row it is &mdash; because a number with two names is neither of the categories a three-column table offers. <strong>The harness asserts the partition, not the three numbers, so the class of mistake cannot recur silently.</strong></p>
                <ul>
                    <li><strong>19 is <code>#XM</code> on Intel and <code>#XF</code> on AMD.</strong> Same number, same class, two names. A kernel that logs the mnemonic string has to branch on the vendor to render it.</li>
                    <li><strong>20 is <code>#VE</code> on Intel and reserved on AMD; 28 is <code>#HV</code> on AMD and reserved on Intel.</strong> Two different vectors for two different hypervisor facilities, on two different vendors, and a guest that takes either one unconditionally is broken on one of them.</li>
                    <li><strong>29 and 30 are real on both vendors while Intel's own summary table lists them as reserved.</strong> That is a documentation error, not a hardware difference, and it is the row to distrust first in any table of this kind &mdash; because the two descriptions disagree about a thing that demonstrably exists.</li>
                </ul>
                <p>And the one number here that is measured rather than cited: <strong>9 of the 32 vectors are reserved on this part, and 6 more raised a real fault, so 15 are reachable to a user process and 17 are not.</strong> The gap is not a permissions decision. It is what the silicon implements, and no gate for <code>#VE</code> exists to make because the vector does not.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the table and count the two columns.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then <code>grep -c '| MEASURED' sysdump.out</code>. <em>(Expect 6, and expect the vector numbers to be 0, 1, 3, 6, 13, 14 &mdash; not 0, 1, 3, 6, 14. #GP is measured in the third concept's boundary table, all thirty-nine times, and a table that has not noticed that is a table with a hole in it.)</em></li>
                    <li><strong>Break the partition deliberately.</strong> Change the census in <code>sysdump.c</code> so that row 28 counts as reserved <em>and</em> as AMD-only, which is the original bug. <em>(Expect the harness to fail on the partition check and on nothing else &mdash; the individual counts will still look plausible. A census that fails on the sum but not on the columns is the only kind of check that catches this.)</em></li>
                    <li><strong>Make the divide-by-zero arm lie again.</strong> Change <code>p_div0</code> back to <code>volatile long z = 0; long r = d / z;</code> and rebuild. <em>(Expect the row to read <code>RETURNED</code> and the crosscheck to fail on that row. A probe that stops faulting without a diagnostic is the failure mode that costs a day, and this one has already cost this course one.)</em></li>
                    <li><strong>Add a vector you can actually raise.</strong> Take a program with a floating-point divide by zero and confirm the signal is the same <code>SIGFPE</code> that the integer divide produced. <em>(Expect the same signal and, on this kernel, the same <code>si_code</code> of 1. Then confirm the saved RIP is the <em>faulting</em> divide for the integer case, by looking at where the handler's context points &mdash; which is the class, and the only way to see it.)</em></li>
                    <li><strong>Decide what your kernel does with a reserved number.</strong> Write a handler that logs every vector it receives for an hour of ordinary work. <em>(Expect the interesting answer to be <em>none of them</em> on a well-behaved machine, and expect the interesting variant to be the machine that logs one you have never heard of. That is the argument for a kernel logging numbers rather than names: a name is a claim about a vendor, and a number is a fact.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, the previous concept is the one way <em>in</em> and this one is everything that can come back out. <a href="/courses/priv/lessons/priv-vectors">The privilege course's vector concept</a> is the parent of this page and the difference in the two tables is the source column; <a href="/courses/priv/lessons/priv-errorcode">its error-code concept</a> measured what ring 3 sees of the word the CPU pushed, and the second section of this page re-measures the same three page faults as a table rather than as a paragraph.</p>
                <p>Forwards. The next concept is the table every #GP consults and the three comparisons it can fail, and the connection is <code>si_code 128</code>: a #GP has no error code the process can read, and <code>128</code> is what the kernel reports when there is nothing to report &mdash; <strong>the same 128 a non-canonical address produces</strong>, which is why the two are indistinguishable from ring 3 and why the sixth concept has to bisect for a boundary rather than read a signal. The fourth concept is about the registers that decide which of these gates the CPU will even look at.</p>
                <p>Outward. This table is the one an operating-system port reads, and the one an embedded kernel's vector table is transcribed from. The row that costs the most time in practice is #14: it is the only vector in the table whose error code carries information a demand-paging system needs, and it is the one whose error code reaches userspace with one bit of six intact.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-syscall">SYSCALL and the Four Registers It Touches</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-rings">Descriptor Tables and the Privilege Checks</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
