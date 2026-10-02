// Exceptions, Privilege and Mode Changes — Concept 6: the error codes
public namespace underlayer_content {

using std::string

using std::string_view

public func render_priv_errorcode() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Three Error Codes and None of Them Visible — Underlayer")
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
            <h1>Three Error Codes and None of Them Visible</h1>
            <div class="lesson-meta">24 min &middot; <a href="/courses/priv">Exceptions, Privilege and Mode Changes</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>When an exception happens, the CPU pushes a 32-bit word on the stack that says <em>why</em>. It is the most information-dense thing in the whole mechanism: one word that distinguishes a not-present page from a protection violation, a read from a write, an instruction fetch from a data access, and a fault in user mode from a fault in the kernel.</p>
                <p>Almost every description of system calls stops at the point where the word is on the stack. The interesting question is what happens to it afterwards &mdash; and the answer, measured below, is that <strong>a process never sees it at all.</strong> Not most of it. None of it. The kernel collapses eight bits into a signal number and one <code>si_code</code>, and what a userspace program can distinguish turns out to be much smaller than anyone would guess from reading the manual.</p>
                <p>This matters for anything that debugs, fuzzes, sandboxes, or reports crashes across a boundary. And it has a second, structural point underneath it: <strong>x86-64 does not have one error-code format. It has three, and they are not related.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>The model: three unrelated formats</h2>
                <p>The <code>#PF</code> format is a bitfield. It is not a selector, and reading it as one is the single most common error in fault-handler code.</p>
                <div class="formula">
   #PF  (page fault) -- a packed bitfield

     bit 0  P      no translation: a present bit was 0
     bit 1  W/R    the access was a WRITE
     bit 2  U/S    a USER-mode access caused it
     bit 3  RSVD   a RESERVED BIT WAS SET IN A PAGING
                    ENTRY -- not in the instruction
     bit 4  I/D    the access was an INSTRUCTION FETCH
     bit 5  PK     a protection key denied it
     bit 6  SS     a shadow-stack access
     bit 7  HLAT   a translation fault in the HLAT path
     bit 15 SGX    an SGX access-control violation

   #GP / #NP / #SS  -- looks like a selector

     bit 0  EXT    the event came from outside the program
     bit 1  IDT    the index names an IDT gate
     bit 2  TI     ...in the LDT, not the GDT
     bit 3..15     the index itself
     bit 16..31    RESERVED, so the stack stays 16-aligned

   #CP  (control protection) -- neither of the above

     bit 0..14  CPEC: 1 NEAR-RET, 2 FAR-RET/IRET,
                3 ENDBRANCH, 4 RSTORSSP, 5 SETSSBSY
     bit 15     ENCL: it happened inside an enclave
                </div>
                <p>Three shapes, one architecture, and the manual flags the divergence twice &mdash; once when describing the general format and once when describing <code>#PF</code>. There is no unified model because there is no unified mechanism: a selector error names a thing in a table, a page fault describes an access, and a control-protection error reports a class of instruction.</p>
                <p><strong>Bit 3 is the trap worth naming.</strong> <code>RSVD</code> does not mean the instruction had a reserved bit in its encoding, and it does not mean the access was of a reserved type. It means, verbatim, that <em>no translation exists because a reserved bit was set in one of the paging-structure entries</em>. It is a statement about a software error in the page tables, it pairs with bit 0 &mdash; bit 0 zero means not-present, bit 3 set means reserved-bit violation &mdash; and <strong>it is a completely different failure mode from every other bit, reached only by a kernel that has corrupted its own tables.</strong></p>
                <p>And the second thing <code>#PF</code> delivers is not an error code at all: it loads the linear address into <code>CR2</code>. The manual warns that a second page fault <strong>overwrites</strong> it, including a fault that happens while an earlier one is still being delivered. So a fault handler must save <code>CR2</code> before doing anything that can fault again &mdash; which is why the double-fault machinery at vector 8 exists, and why the &ldquo;use a separate stack via the IST field&rdquo; mechanism is not optional.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: what a process can actually tell apart</h2>
                <p>Six rows. One address arithmetic, three protections, three directions of access. Every row is a real fault on this machine, and every row's <code>si_addr</code> is exact to the page.</p>
                <div class="hex-dump">
                <pre>$ ./privbench | sed -n '/read  a PROT_READ page/,/exec  a PROT_NONE/p'
   read  a PROT_READ page         no fault
   write a PROT_READ page         si_code=2    SEGV_ACCERR  mapped, access not permitted  addr=0x511000
   exec  a PROT_READ page         si_code=2    SEGV_ACCERR  mapped, access not permitted  addr=0x512000
   read  a PROT_NONE page         si_code=2    SEGV_ACCERR  mapped, access not permitted  addr=0x513000
   write a PROT_NONE page         si_code=2    SEGV_ACCERR  mapped, access not permitted  addr=0x514000
   read  an UNMAPPED page         si_code=1    SEGV_MAPERR  nothing mapped here          addr=0x7bcd0e63f000
</pre>
                </div>
                <p>Two findings, and the second is the course's.</p>
                <p><strong>First:</strong> row 1 does not fault. <code>PROT_READ</code> means readable and the read succeeds. Rows 2 and 3 do fault &mdash; so a page that is readable is neither writable nor executable. <strong>W^X is enforced in hardware, from ring 3, and the address in the signal is exact.</strong> That is the good news, and it is worth having.</p>
                <p><strong>Second, and this is the one to sit with:</strong> rows 2, 3, 4 and 5 are four <em>different</em> events.</p>
                <ul>
                    <li>a write to a read-only page &mdash; <strong>W/R bit set</strong></li>
                    <li>an execute of a non-executable page &mdash; <strong>I/D bit set</strong></li>
                    <li>a read of a <code>PROT_NONE</code> page</li>
                    <li>a write of a <code>PROT_NONE</code> page &mdash; <strong>W/R bit set again</strong></li>
                </ul>
                <p><strong>From ring 3, <code>si_code</code> cannot tell any of them apart. All four are 2.</strong> The one distinction it does make &mdash; 1 against 2 &mdash; is mapped, present but denied, against not mapped at all. Everything finer has been collapsed.</p>
                <p>And those are exactly the two bits a demand-paging system needs. <code>W/R</code> is how the kernel decides whether a not-present page is mapped read-only or read-write, which is the entire mechanism of copy-on-write: a write fault on a page marked read-only means &ldquo;this was a copy-on-write target&rdquo; and the fix is to unmark it. <code>I/D</code> is how it decides whether to map the page executable. <strong>The kernel sees both. A process sees neither.</strong></p>
                <div class="formula">
   A 32-bit word, compressed to:

      one signal number          (which of ~64 things)
      one si_code                (1, 2, or 128)
      one address                (or 0, meaning "there isn't one")

   That is the entire channel.  The other five bits
   are for the kernel.
                </div>
                <p>This is not a criticism of the design &mdash; the boundary is where the kernel is entitled to keep things to itself. It is a statement about what userspace diagnostics can conclude. <strong>A userspace crash reporter that says &ldquo;the access was denied&rdquo; is right. One that says &ldquo;the program wrote to memory it should not have&rdquo; is guessing, and its guess is wrong half the time.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: two failures of the measurement, and what they teach about harnesses</h2>
                <p>Getting this table to mean anything took two corrections, and both are about the harness rather than the hardware.</p>
                <div class="formula">
  1. SIX ROWS AGAINST ONE PAGE.
     The first version mapped a page, ran three faults
     against it, and unmapped it between rows.  A fault
     longjmps straight out of the function, so the
     munmap never ran.  The mapping leaked, and rows two
     through six measured a page in whatever state the
     previous row left it in.

     Every row now gets its own address AND reports
     whether its mmap succeeded.  A fault-row harness
     that does not check the mmap prints six identical
     numbers and means nothing.

  2. THE "UNMAPPED" ROW WAS NOT UNMAPPED.
     It used the constant 0x60000000 -- which is inside
     this process's own PIE image.  So the row reported
     SEGV_ACCERR for an address assumed to be empty, and
     the table quietly lost its only SEGV_MAPERR entry.
     A second attempt parsed /proc/self/maps for a gap and
     found none, because a PIE process has almost no gaps
     below its image.

     The fix is neither a better constant nor a better
     scan: map a page, UNMAP it, and read that.  The
     address that is certainly unmapped is one this
     process has just unmapped.

     And a third bug hid underneath: the row helper
     re-mapped the page before touching it, so of course
     the "unmapped" row was mapped.  The helper needed a
     flag, not a better address.
                </div>
                <p>The pattern across all three is the same, and it is the reason <a href="/courses/priv/lessons/priv-harness">this course's harness concept</a> exists. <strong>A measurement harness that cannot tell you it is broken will confidently print a table, and the table will have a shape.</strong> Row 1 was a legitimate &ldquo;no fault&rdquo; and row 6 was a legitimate &ldquo;permission denied,&rdquo; and the table between them was nonsense that looked entirely reasonable &mdash; six rows, six addresses, a monotonic-looking column.</p>
                <p>So: after any run of this artifact, ask not only &ldquo;did it produce output&rdquo; but &ldquo;does the output have the shape the claim requires.&rdquo; Here that means the table must contain <em>both</em> an <code>si_code</code> of 1 and an <code>si_code</code> of 2. If every row says 2, one of them is wrong and the artifact cannot tell you which.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Decode a real error code.</strong> Find a way to see the raw 32-bit word. Under a hypervisor with a fault-injection tool, or in a kernel module, or with <code>ptrace</code> on a 32-bit child. Print it in binary and identify every bit. <em>(Expect to find that <code>P</code> is 0 for a not-present page and 1 for a protection violation &mdash; the same fault, two different words, and confusing the two is how &ldquo;my page is there but it says not present&rdquo; happens.)</em></li>
                    <li><strong>Write the exhaustive userspace classifier.</strong> Given a <code>siginfo_t</code>, produce a table of every conclusion a program may draw. Include the non-canonical case from <a href="/courses/priv/lessons/priv-canonical">the previous concept</a>. <strong>Then mark every row where the honest answer is &ldquo;cannot tell&rdquo; &mdash; and check that your list has at least one.</strong></li>
                    <li><strong>Find the fourth error-code format.</strong> There are three in this course. Search the SDM for exceptions that push something and see whether a fourth shape exists. <em>(There is at least one more, in the debug-registers and the virtualization paths, and the answer is that the architecture has no unified error model at all &mdash; which is the honest summary.)</em></li>
                    <li><strong>Explain why the reserved bits 31:16 of a <code>#GP</code> error code exist.</strong> Not &ldquo;for alignment&rdquo; &mdash; the manual's reason is worth reading exactly, and it is a stack-alignment requirement on a push, which means it is a <em>performance</em> decision encoded in an <em>error</em> format. <strong>What else in this course is a performance decision wearing a correctness costume?</strong></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Forward, <a href="/courses/priv/lessons/priv-three">the three-architectures concept</a> answers a question this one raises: if the error code is the machine's only record, how do the other two record it? AArch64's answer is three CSRs, which is a <em>richer</em> interface than x86's single word &mdash; and it costs three register reads instead of one stack slot. RISC-V's answer is a cause enum plus an optional value, which is the closest of the three to what you would design if you were starting fresh.</p>
                <p>Backwards, <a href="/courses/priv/lessons/priv-canonical">the previous concept</a> produced two of the <code>si_code</code> values in this table and explained the third, and the reason a non-canonical access has no address is the reason this table's most useful column is not an address. <a href="/courses/priv/lessons/priv-vectors">The vector concept</a> is where the &ldquo;error code: yes/no&rdquo; column of that table came from, and the rows marked &ldquo;yes&rdquo; are the ones with a format on display here.</p>
                <p>Outward, the practical audience is anyone building a sandbox. A seccomp-BPF filter sees the <em>syscall number</em>, not the error code &mdash; it is a different channel, further out. A pointer-masking or shadow-stack system sees the <code>#CP</code> format, which is the third one here, and which exists because those features needed a fault class that neither the selector format nor the page-fault format could express. <strong>Each new hardware feature that needs to report its own failures has added a format, and the count has been three for twenty years, which suggests the design is stable and was never meant to be unified.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/priv/lessons/priv-canonical">The Hole Has No Fixed Address</a></span>
                <span>Next: <a href="/courses/priv/lessons/priv-three">The Same Idea Under Three Architectures</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
