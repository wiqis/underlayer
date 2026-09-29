// The x86-64 Machine — Concept 7: the four paging entries
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_paging() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Four Entries and Every Flag in One — Underlayer")
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
            <h1>The Four Entries and Every Flag in One</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p><a href="/courses/mem/lessons/mem-translation">The memory course</a> measured the cost of a walk and this concept is the thing being walked. Four levels of nine-bit index, one of twelve bits of offset, and a 64-bit entry whose bits say whether the page is there, who may touch it, and whether the hardware has been here yet. The 64 bits divide into three groups and only one group is the hardware's.</p>
                <p>And there is exactly one measurement in this course that observes a page-table entry directly. <code>/proc/self/pagemap</code> exposes one word per page of the calling process, and what that word contains is a single bit that moves: <strong>an untouched <code>mmap</code> region has no page-table entry at all, and the entry appears at the first touch</strong> &mdash; not at the <code>mmap</code>, not at the <code>mprotect</code>, at the touch. That is demand paging seen from the inside, through one kernel interface, and it is the closest a user process gets to watching the MMU work.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: the index, and the three groups of bits</h2>
                <p>A 48-bit canonical address is cut into five fields and four of them are indexes:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/1B6\./,/^  PTE | 0 /p'
  IDX | PML4 | 9 bits | address bits 47:39
  IDX | PDPT | 9 bits | address bits 38:30
  IDX | PD   | 9 bits | address bits 29:21
  IDX | PT   | 9 bits | address bits 20:12
  IDX | OFF  | 12 bits | address bits 11:0, always added last
  9+9+9+9+12 = 48, and with LA57 there are five levels of 9.
                </pre>
            </div>
                <p>Four indexes of nine bits is 2<sup>36</sup> entries, and every level is itself a 4 KiB page holding 512 eight-byte entries, so a fully-populated 48-bit space would need 2<sup>27</sup> pages of tables and <strong>the whole walk would be four dependent memory accesses</strong>. That arithmetic is the reason the structure has four levels rather than one, and it is also the reason a TLB exists: a four-deep chain of dependent loads is a latency the hardware cannot afford on every access, so the top of it is cached and the bottom of it is the expensive part. <a href="/courses/mem/lessons/mem-translation">The memory course's TLB concept</a> owns that story.</p>
                <p>Now the entry. Sixty-four bits, and the artifact divides them by who writes them:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  PTE | 0 /,/bits 9-11/p'
  PTE | 0    | P       | present; 0 makes the entry INVALID and every
  PTE |      |         | access through it a #PF with error bit 0 clear
  PTE | 1    | RW      | writable; 0 with RW=1 above is the #PF case
  PTE | 2    | US      | accessible at CPL 3; 0 and CPL>0 is a #PF
  PTE | 3    | PWT     | write-through for this page
  PTE | 4    | PCD     | cache disabled for this page
  PTE | 5    | A       | accessed: SET BY HARDWARE on the first touch
  PTE | 6    | D       | dirty: SET BY HARDWARE on the first write
  PTE | 7    | PS      | page size: 0 = 4 KiB, 1 = 2 MiB, PD level ONLY
  PTE | 8    | G       | global: a translation usable by every address space
  PTE | 9-11 | -       | available to the operating system
                </pre>
            </div>
                <div class="formula">
   THE THREE GROUPS, and they are not
   equally interesting.

   WRITTEN BY THE HARDWARE   bits 5 and 6
       A  accessed, set on any touch
       D  dirty, set on any write
       Everything else in the entry is
       written by SOFTWARE, which is why a
       kernel's paging format is a choice
       and not a fact about the processor.

   WRITTEN BY THE KERNEL     bits 0, 1, 2
       P  present
       RW read-write
       US user/supervisor
       ...and the three cache and
       policy bits, 3, 4 and 8.

   AND THE ONE THAT DECIDES
   EVERYTHING ELSE            bit 0

   P = 0 does not mean "no data".  It
   means the 64 bits are not a page.  A
   fault on a non-present entry is a
   DIFFERENT EVENT from a fault on a
   present one with the wrong permissions,
   and the CPU records the difference in
   the error code's bit 0.

   Linux uses that difference for demand
   paging: P = 0 means "nobody has
   touched this yet, go and make it".
   The x86-64 paging structure is not a
   protection mechanism that happens to
   support paging; it is a memory format
   whose protection bits are read by the
   same instruction.
                </div>
                <p>And the rest of the entry, which is where the interesting flags hide:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/^  PTE | 12 /,/the entry is written by software/p'
  PTE | 12   | PAT     | at the PD level, the PAT bit for the whole 2 MiB
  PTE | 13-58 | -      | reserved, except bits 59-62 which hold PKRU
  PTE | 59-62 | PKRU   | protection key; ignored unless CR4.PKE or PKS
  PTE | 63   | NX      | no-execute; needs EFER.NXE, and a #PF without
  PTE |      |         | the instruction bit set if the fetch is denied
  PTE | 4-5 are the ONLY bits the HARDWARE sets.  Everything else in
  PTE | the entry is written by software, which is why a kernel's paging
  PTE | format is a choice and not a fact.
                </pre>
            </div>
                <p><code>PS</code> at bit 7 is the one bit that changes the <em>meaning</em> of every other bit: set at the page-directory level, the entry stops being a pointer and becomes a description of a 2 MiB region, and bits 9 through 20 become physical address bits. <strong>One bit, two entirely different structures, in the same 64-bit word.</strong> And <code>NX</code> at bit 63 is the only protection bit that is on by default in a modern kernel, because it is the one that cannot be got wrong by a missing bit elsewhere: without <code>EFER.NXE</code> it is a reserved bit and every page is executable.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: one bit that moves, and three that a user process cannot see</h2>
                <p>Six <code>mmap</code> regions, read out of <code>/proc/self/pagemap</code> at four points, and the only thing that changes is one bit:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  PAGEMAP |' | head -6
  PAGEMAP | a fresh RW mapping, untouched | 0x0080000000000000 | bit63 0
  PAGEMAP | the same page after ONE write      | 0x8180000000000000 | bit63 1
  PAGEMAP | a PROT_NONE mapping, untouched     | 0x0080000000000000 | bit63 0
  PAGEMAP | PROT_NONE, then mprotect RW      | 0x0080000000000000 | bit63 0
  PAGEMAP | and then ONE write              | 0x8180000000000000 | bit63 1
  PAGEMAP | a PROT_READ page, after ONE read | 0x8080000000000000 | bit63 1
                </pre>
            </div>
                <p>Four results in six rows, and each is a fact about the MMU rather than about a document.</p>
                <ul>
                    <li><strong>An untouched <code>mmap</code> has no entry.</strong> Bit 63 reads zero, which in this interface means the page is not present &mdash; and the mapping is a <code>PROT_READ|PROT_WRITE</code> anonymous mapping that <em>succeeded</em>. The entry is created by the first fault, not by the <code>mmap</code>. <strong>This is demand paging, observed from the one side of it a user process can reach.</strong></li>
                    <li><strong><code>mprotect</code> alone changes nothing.</strong> The third and fourth rows are the same value: after <code>mprotect</code> from <code>PROT_NONE</code> to <code>PROT_READ|PROT_WRITE</code> the entry is still not present, and the fifth row is the first write. A permission change does not populate a page table, and the kernel does not have to do work to make a <code>PROT_NONE</code> region readable &mdash; the first touch is where the work happens.</li>
                    <li><strong>A <code>PROT_READ</code> page is present after a read</strong>, and its word is not the same as the read-write page's: one bit differs and the artifact reports which. <strong>The artifact explicitly declines to name it</strong>, because bit 62 of a pagemap word is a mapping-sharing flag whose kernel definition has changed twice, and a page that names a bit it cannot account for is worse than one that admits it. That refusal is in the artifact's own prose and the harness asserts it.</li>
                    <li><strong>Bit 63 of a pagemap word is the present bit, not the no-execute bit.</strong> This is retraction R10, and the first version of this section got it wrong: it read the word as though it were the page-table entry and reported <code>NX=1</code> for a page it had never written. The two bits share a number and nothing else.</li>
                </ul>
                <div class="formula">
   WHAT A USER PROCESS CANNOT SEE, and it
   is three bits that matter more than the
   one it can.

     bit 1  RW    is this page writable?
     bit 2  US    may a user touch it?
     bit 5  A     of the ENTRY: has it been
                  accessed?  (pagemap's bit
                  55 is the kernel's own
                  reference flag, which is a
                  different thing)
     bit 63 of the ENTRY is NX, and no
                  field of pagemap exposes it

   So a user process cannot tell from
   /proc/self/pagemap whether its own
   memory is executable, and a security
   tool that tries to is measuring the
   interface rather than the memory.
   The instrument that would settle it is
   a kernel-side reader of the real PTE.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the error code, and the one bit of six that survives</h2>
                <p>The page-fault error code is a fifth encoding with its own layout, and it is where the entry's bits become an event:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/The page-fault ERROR CODE/,/neither reaches/p'
  ERR | 0   | P   | 0 = the page was not present
  ERR | 1   | W/R | 1 = the access was a WRITE, 0 = a read or a fetch
  ERR | 2   | U/S | 0 = the access was at CPL 0, 1 = at CPL 3
  ERR | 3   | RSVD| 1 = a reserved bit of the page-table entry was set
  ERR | 4   | I/D | 1 = the access was an INSTRUCTION FETCH
  ERR | 5   | PK  | 1 = a protection-key violation
  ERR | 6-31 | -  | must be zero
  Bits 1 and 4 are exactly the two a demand-paging system needs and
  section 4 shows that ring 3 cannot see either of them.
                </pre>
            </div>
                <p>And here is what ring 3 gets instead, measured three ways, and the third is the one that matters:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep '^  PFC |'
  PFC | write to NULL          si_code 1
  PFC | write to a PROT_READ   si_code 2
  PFC | touch a PROT_NONE     si_code 2
  PFC | the first is a MAPPING failure and the other two are
  PFC | PERMISSION failures, and the two permission failures
  PFC | are the SAME number.  The error code the CPU pushed has
  PFC | a write bit and an instruction bit in it, bits 1 and 4,
  PFC | and a demand-paging system needs both of them, and
  PFC | neither reaches this process.  si_code is the KERNEL's
  PFC | translation of that word and it keeps exactly one bit:
  PFC | present or not.
                </pre>
            </div>
                <p><strong>One bit of six.</strong> And the one it kept is bit 0, the present bit, which means the interesting measurement is not about a protection at all: it is that a user process <em>can</em> distinguish &ldquo;this page is not there&rdquo; from &ldquo;this page is there and you may not do that.&rdquo; That distinction is the whole of copy-on-write's user-visible half, and it is the only part of the error code that a process sees.</p>
                <p>The two bits that are missing have a specific cost, and it is worth being concrete about it. <strong>Bit 1, the write bit</strong>, is what lets a kernel tell a COW read fault from a COW write fault and skip the copy in the first case &mdash; which is why a read of a shared page is fast and a write is not. <strong>Bit 4, the instruction bit</strong>, is what lets a kernel distinguish &ldquo;the page is not executable&rdquo; from &ldquo;the page is not readable&rdquo;, which is the entire difference between a <code>PROT_NONE</code> guard page and an ordinary unmapped hole. Both bits are pushed by the CPU, both are read by the kernel, and neither crosses into user space.</p>
                <h3>And the level that does not exist</h3>
                <p>One row of the entry table is not measured here, and the reason is a failed experiment rather than a missing one:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -A2 'THE PS BIT OF A REAL'
    * THE PS BIT OF A REAL 2 MiB MAPPING.  MAP_HUGETLB was tried and
      returned ENOMEM on this machine, and no transparent huge page
      collapsed during the run, so the PS=1 row of the entry table in
                </pre>
            </div>
                <p>The <code>PS</code> row says <code>0 = 4 KiB, 1 = 2 MiB, PD level ONLY</code> and this course has only ever exercised the zero. <strong>Every number on this page comes from a 4 KiB path</strong>, and the artifact says so in its limits block rather than leaving the reader to assume the huge-page path was measured too. A huge page changes the walk from four accesses to three and moves the <code>RW</code>, <code>US</code> and <code>NX</code> bits from the leaf entry to the directory entry, which is a different structure wearing the same word &mdash; and a reference that quoted a 2 MiB figure it had not measured would be quoting a story.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce the six pagemap rows.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 6D. <em>(Expect bit 63 to be 0, 1, 0, 0, 1, 1 in that order, and expect the <code>mprotect</code> row to be identical to the row before it. On a machine with transparent huge pages the last row may differ, because a 2 MiB mapping collapses and the word changes shape &mdash; which is a result, not a failure, and worth chasing.)</em></li>
                    <li><strong>Break the <code>mprotect</code> row.</strong> Add one read of the page between the <code>mprotect</code> and the pagemap read. <em>(Expect bit 63 to become 1 there and the <code>and then ONE write</code> row to stop changing anything. The experiment is the same and the point is that a demand-paging kernel is lazy in a way that is observable, and the only reason most people never notice is that they never look.)</em></li>
                    <li><strong>Find the <code>A</code> and <code>D</code> bits on a machine that will show you.</strong> This one needs a CPL 0 reader. <em>(Expect <code>A</code> set by a read and <code>D</code> set by a write, and expect a kernel that does not clear them between processes to let a scanner find every page the process has touched &mdash; which is why every hardened kernel clears them and what the cost of clearing is. The bit that costs the most is the one that saves the most.)</em></li>
                    <li><strong>Write the <code>NX</code> check and find out you cannot.</strong> Take a program that wants to know whether a page it owns is executable. <em>(Expect that it cannot, from user mode, with any interface &mdash; and then expect that a page which is <em>not</em> executable is a fact it can establish by jumping to it and catching the fault. The asymmetry is the whole story: you can test a property by violating it, and you cannot test it by inspecting it. That is true of memory and it is true of most of what this course measures.)</em></li>
                    <li><strong>Count the levels your own paging structures have.</strong> If you are writing an OS, decide four or five, and then decide what a <code>CR3</code> reload costs in each. <em>(Expect five to be almost free if you have huge pages, because the walk is already dominated by the TLB miss. Then expect the <code>CR3</code> sign-extension field to move from four bits to six and remember that a hypervisor presenting both depths to the same guest has to present two <code>CR3</code> formats &mdash; which is a cost of the extension that appears in a place nobody looks for it.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/mem/lessons/mem-translation">the memory course's address-translation concept</a> measured what a walk costs and owns the TLB; <a href="/courses/mem/lessons/mem-translation">its TLB concept</a> is where the four dependent loads are cached. This page is the structure those loads are chasing, and the only thing it adds is the flag set and the one direct observation. <a href="/courses/priv/lessons/priv-harness">The privilege course's harness concept</a> is where the three protection failures were first measured as <em>three signals</em>; the second section here is the same three, with the error code that produced them printed beside them.</p>
                <p>Forwards, and the connection is the tightest in the course. The previous concept's hole in the address space is why this structure has four levels rather than one, and the <code>PS</code> bit is why it sometimes has three. The next concept is about the thing that <em>fills</em> this structure when a fault arrives &mdash; and it establishes, by measurement, that the filling cannot be watched from user space even when the reading can.</p>
                <p>Outward. The paging structure is the one place where x86-64's history is visible in the <em>layout</em>: a <code>CR0.PSE</code> bit that does nothing in long mode, a 4 KiB granularity that predates every other architecture's choice, and a global bit that exists because the original design had one address space. Every other architecture in this collection puts the same information in a different shape, and the comparison belongs to the memory course. What this course owes the table for is the <em>bit positions</em>, and the general form is worth keeping: <strong>four of the fourteen bits in a page-table entry are set by the hardware and ten by software, and the two the hardware sets are the two a kernel cannot predict.</strong></p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-virtual">The 48-Bit Split, LA57 and LAM</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-pmu">The Performance Monitoring Architecture</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
