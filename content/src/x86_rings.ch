// The x86-64 Machine — Concept 3: descriptor tables and the privilege checks
public namespace underlayer_content {

using std::string

using std::string_view

public func render_x86_rings() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Descriptor Tables and the Privilege Checks — Underlayer")
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
            <h1>Descriptor Tables and the Privilege Checks</h1>
            <div class="lesson-meta">28 min &middot; <a href="/courses/x86sys">The x86-64 Machine</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>The privilege boundary on x86-64 is not a bit. It is a <strong>comparison against a number stored in a table the CPU reads on every mode change</strong>, and the number is a field inside an eight-byte descriptor that also says whether the segment is code or data, readable or writable, present or not, and 32-bit or 64-bit. Five decisions in eight bytes, and the first of them is the one people call &ldquo;privilege&rdquo;.</p>
                <p>What makes this concept worth a full page rather than a paragraph is a measurement that contradicts the sentence almost everybody uses to describe it. The sentence is <em>the descriptor tables are privileged</em>. The measurement is that <code>SIDT</code> and <code>SGDT</code> <strong>both return from ring 3</strong>, and that reading one byte of either table does not, and that the failure is <code>si_code 1</code> with an <code>si_addr</code> equal to the base the instruction just printed.</p>
            </div>

            <div class="unit unit-model">
                <h2>The model: sixteen bits, three fields, and four numbers</h2>
                <p>A segment selector is not an index. It is three fields with different jobs, and the two-bit field at the bottom is the one that is checked:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/1B5\./,/CALL-GATE rule/p'
  SEL | 15:3 | index  | which descriptor in the GDT or LDT
  SEL | 2    | TI     | 0 = GDT, 1 = the LDT
  SEL | 1:0  | RPL    | requested privilege level, 0 to 3
  SEL | 0xffff | a NULL selector: index 8191, TI 1, RPL 3

  The four privilege numbers and the two comparisons:
    CPL   the current privilege level, from CS.RPL in long mode
    RPL   requested, from the low two bits of the selector loaded
    DPL   descriptor privilege level, bits 14:13 of the descriptor
    for a DATA or CODE segment:  max(CPL, RPL) &lt;= DPL   or  #GP
    for a CALL GATE:             max(CPL, RPL) &lt;= DPL   or  #GP(tss)
    for an INTERRUPT gate:       CPL &lt;= DPL             or  #GP(vector)
                </pre>
            </div>
                <p><strong>Three rules, not one, and the difference between the second and the third is the whole of a common mistake.</strong> The first two compare the larger of the current and requested levels against the descriptor's. The third does not, and cannot: an interrupt gate is indexed by a <em>vector number</em>, and a vector number has no RPL field. Every textbook that writes <code>MAX(CPL,RPL) &le; DPL</code> as &ldquo;the rule for gates&rdquo; is quoting the call-gate rule for something that is not a call gate, and a kernel that implements the third check with the first will refuse its own timer.</p>
                <div class="formula">
   THE FOUR NUMBERS, and only one of them
   is a privilege level in the ordinary sense.

   CPL  current privilege level.  In long
        mode it is CS.RPL and there is no
        descriptor behind it, so there is
        nothing to CHECK it against.
   RPL  requested, two bits at the bottom
        of a selector.  "I would like."
   DPL  descriptor privilege level, bits
        14:13 of the descriptor.  "I am."
   IOPL the I/O privilege level, in EFLAGS,
        and the thing that gates IN, OUT and
        STR.  It is not a ring number and no
        descriptor holds it.

   The ring diagram everybody draws has
   four rings.  The machine has three
   numbers it compares and one it does
   not.
                </div>
                <p>And the descriptor itself. A 64-bit system segment descriptor is eight bytes, and the fields that matter for this page are two: the <strong>type byte</strong>, whose low three bits are the access type and whose high bits include <code>P</code> (present) and <code>DPL</code>, and the <strong>flags byte</strong>, whose <code>L</code> bit is what makes a code segment 64-bit. Long mode adds one rule that has no analogue in 32-bit protected mode: <strong>a data selector's base and limit are ignored entirely.</strong> That is why <code>%ds</code> being zero is harmless in a 64-bit program, and it is the fact that surprises people who arrive from 32-bit code.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The reality: both pseudo-descriptors return, and neither table can be read</h2>
                <p>Two instructions, two ten-byte structures, and a field order that is the opposite of what the prose implies:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/the ten bytes SIDT/,/UNFALSIFIABLE/p'
  the ten bytes SIDT actually wrote, in memory order:
    00 00 00 00 ff ff ff ff ff ff
  SIDT | base 0xffffffff00000000 | limit 65535 | entries 4096 of 16 bytes
  SGDT | base 0xfffffffe00000000 | limit 65535 | entries 8192 of 8 bytes

  THE FIELD ORDER, and it is the whole of this sub-section:
    offset 0..7  BASE   first
    offset 8..9  LIMIT  second
  Read the documented-in-prose 'limit first, then base' way and:
    base 0xffffffffffff0000  limit 0
  NO FAULT, and no obviously impossible value either.  A limit of
  0 is INDISTINGUISHABLE from a kernel that installed an empty
  IDT, so the wrong reading is not merely wrong, it is
  UNFALSIFIABLE.  A tool written that way reports a plausible
  base in the middle of nowhere and never tells you.
                </pre>
            </div>
                <p>The ten bytes are printed before they are interpreted, and reading them is how you check the interpretation: <code>00 00 00 00 ff ff ff ff</code> is a base of zero and <code>ff ff</code> is a limit of 65535, and the base-first order is the only reading under which the two halves are individually plausible. A limit of 65535 is the largest a 16-bit field can hold, which is the architectural statement; where the base points is a <strong>kernel choice</strong>, and the two numbers above differ by exactly 2<sup>32</sup> bytes, which is a decision this kernel made and not a rule.</p>
                <h3>Then the asymmetry</h3>
                <div class="hex-dump">
                <pre>$ ./sysdump | sed -n '/6A\./,/PAGE-TABLE fact/p'
  ABSENT | what | si_code | si_addr | si_addr equals
  ABSENT | read one byte of the IDT | 1 | 0xffffffff00000000 | the IDT base SIDT printed
  ABSENT | read one byte of the GDT | 1 | 0xfffffffe00000000 | the GDT base SGDT printed
  ABSENT | both are si_code 1, SEGV_MAPERR, which is the shape of
  ABSENT | a MAPPING failure and not the shape of a #GP.  So the
  ABSENT | register is readable, the address is readable, and the
  ABSENT | table is not, and the reason is that no user mapping
  ABSENT | covers it.  That is a PAGE-TABLE fact, not a privilege
  ABSENT | fact, and it is a better story than 'the IDT is
  ABSENT | privileged' because it predicts the si_addr.
                </pre>
            </div>
                <p>This is the sharpest thing in the concept, and it is a <em>correction</em> rather than a finding. The obvious sentence is &ldquo;a ring-3 process cannot read the IDT because the IDT is privileged.&rdquo; The measurement says something more specific and more useful: the register is readable, the address is readable, and the table is not &mdash; and the failure carries an <code>si_addr</code> that is <strong>exactly the base <code>SIDT</code> printed</strong>. That is a mapping failure, not a general-protection one, and it distinguishes three stories that all sound alike:</p>
                <ul>
                    <li><strong>&ldquo;The IDT is privileged&rdquo;</strong> predicts nothing about the address. Any address is consistent with it.</li>
                    <li><strong>&ldquo;No user mapping covers the IDT&rdquo;</strong> predicts the address <em>exactly</em>, and the measurement confirmed it for both tables. It also predicts that a kernel which <em>did</em> map its IDT into user space would make it readable with no change to any privilege bit at all &mdash; which is true, and is why the fix for a sandbox that cannot read its own traps is never a CPU bit.</li>
                </ul>
                <p>And note the two different <code>si_addr</code> values: <code>0xffffffff00000000</code> for the IDT and <code>0xfffffffe00000000</code> for the GDT. The harness checks each against the base the corresponding instruction printed, so the claim is a comparison and not a coincidence.</p>
                <h3>The other half of the group</h3>
                <p>All five of the &ldquo;store the descriptor table registers&rdquo; instructions are in one bucket, and the bucket is not the one most answers give:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  EDGE \| (lidt|lgdt|ltr|lldt|sidt|sgdt|sldt|str|smsw) '
  EDGE | lidt                           | descriptor tables | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | lgdt                           | descriptor tables | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | ltr                            | descriptor tables | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | lldt                           | descriptor tables | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | sidt                           | descriptor tables | RETURNED | sig 0  | si_code 0   | si_addr 0x000000000000
  EDGE | sgdt                           | descriptor tables | RETURNED | sig 0  | si_code 0   | si_addr 0x000000000000
  EDGE | sldt                           | descriptor tables | RETURNED | sig 0  | si_code 0   | si_addr 0x000000000000
  EDGE | str                            | descriptor tables | RETURNED | sig 0  | si_code 0   | si_addr 0x000000000000
  EDGE | smsw                           | descriptor tables | RETURNED | sig 0  | si_code 0   | si_addr 0x000000000000
                </pre>
                </div>
                <p>Four writes fault and five reads return, and the split is not arbitrary. The writes replace a table the CPU will consult on the next mode change, so they are gated. The reads report where a table <em>is</em>, and that is a diagnostic the architecture deliberately provides &mdash; except that <code>CR4.UMIP</code> can close the door. And <strong>whatever this kernel has <code>UMIP</code> set to, it is not blocking them, which is a measurement of the effect and not a reading of the bit.</strong> <code>STR</code> is the one everybody gets wrong: the check for <em>writing</em> the task register is a CPL-versus-<code>IOPL</code> comparison, and the check for <em>reading</em> it is nothing at all.</p>
                <p>And the privilege check itself, made to fail on purpose by loading a selector whose descriptor is not there:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  EDGE \| mov 0x1234'
  EDGE | mov 0x1234,%ax; mov %ax,%ds    | segments          | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
  EDGE | mov 0x1234,%ax; mov %ax,%ss    | segments          | FAULTED | sig 11 | si_code 128 | si_addr 0x000000000000
                </pre>
            </div>
                <p><code>0x1234</code> is index 0x246 of the GDT, which is past the end of an 8192-entry table, and the CPU raises a #GP with a zero error code &mdash; hence <code>si_code 128</code> and no address. The same instruction with <code>%ds</code> instead of <code>%ss</code> also works, which is the answer to &ldquo;do data selectors get checked differently from stack selectors&rdquo;: in long mode, no, and the reason is that both selectors' privilege checks are the same two-bit comparison against a field that was never consulted for the base.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the two things a segment register still does in 64-bit mode</h2>
                <p>Read the six selectors this process is actually running with, decoded by the three fields:</p>
                <div class="hex-dump">
                <pre>$ ./sysdump | grep -E '^  SEG \|' | head -3
  SEG | cs 0x0033 ss 0x002b ds 0x0000 es 0x0000 fs 0x0000 gs 0x0000
  SEG | decoded as index&lt;&lt;3 | TI&lt;&lt;2 | RPL:
  SEG | cs | selector 0x0033 | index 6 TI 0 RPL 3 | CPL IS THE RPL OF CS IN LONG MODE
  SEG | ss | selector 0x002b | index 5 TI 0 RPL 3 |
  SEG | ds | selector 0x0000 | index 0 TI 0 RPL 0 |
                </pre>
                </div>
                <ul>
                    <li><strong><code>CS = 0x0033</code>: index 6, GDT, RPL 3.</strong> So this process is at CPL 3, and in long mode that is the <em>whole</em> of what CS does &mdash; the index is not checked against anything, because there is no code descriptor behind it. The privilege level <em>is</em> the two low bits.</li>
                    <li><strong><code>SS = 0x002b</code>: index 5, RPL 3, matching.</strong> Linux keeps the kernel's code at index 6 and the user stack at index 5 with a DPL of 3, and the fact that the indices are 6 and 5 rather than 3 and 4 is a consequence of reserving the low ones &mdash; a layout decision, and one you can read out of a running process.</li>
                    <li><strong><code>DS</code>, <code>ES</code>, <code>FS</code> and <code>GS</code> are all <code>0x0000</code>.</strong> A null selector, loaded deliberately and legally. <code>FS</code> and <code>GS</code> are how <code>thread-local storage</code> is addressed, and their <em>bases</em> come from the FS-base and GS-base MSRs rather than from the descriptor &mdash; which is why a 64-bit program can have a thread pointer at <code>0x7ffff7000000</code> and a null selector at the same time. <a href="/courses/x86asm/lessons/x86-flags">The assembly course's flags concept</a> is where the FS-base mechanism itself is a register story; here the point is only that the selector and the base are now unrelated.</li>
                </ul>
                <p>So in long mode a segment register has exactly two jobs left, and both of them are on this page: <strong>the two low bits of <code>CS</code> are the current privilege level, and the two low bits of a data selector are checked against a DPL that nothing else consults.</strong> Everything else about segments &mdash; bases, limits, expand-down, the 32/64-bit flag for data &mdash; is either ignored or moved into a model-specific register. Segmentation survives on x86-64 as a <em>privilege</em> mechanism and nothing else, which is a strange sentence to write about a feature that occupied a chapter in every architecture text for fifteen years.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Reproduce both readings, in that order.</strong> <code>cd courses/x86sys/assets/samples &amp;&amp; ./build_samples.sh</code>, then read section 2B. <em>(Expect the ten raw bytes, the correct base-first reading, and the wrong one with a limit of 0 and no fault. If your kernel's IDT base is not <code>0xffffffff00000000</code> that is fine and it is the point: the placement is a kernel choice, and the artifact prints what it read rather than asserting a number.)</em></li>
                    <li><strong>Check the adjacency claim instead of the placement.</strong> The first draft of this section said the IDT begins exactly where the GDT ends, and computed <code>base + limit + 1</code> and read the answer off a hex string. <em>(Expect it to be wrong: each table is exactly 2<sup>16</sup> bytes and the two bases are 2<sup>32</sup> bytes apart, so the gap is 2<sup>32</sup> minus 2<sup>16</sup> and not zero. The retraction is printed in the artifact with both numbers beside it, because a retraction without the numbers is a rumour.)</em></li>
                    <li><strong>Write the interrupt-gate check and watch it reject your own timer.</strong> Implement the DPL test for gates as <code>max(CPL, RPL) &le; DPL</code> and see what happens when a ring-3 process takes a timer interrupt. <em>(Expect it to work, because RPL is 0 in a vector, and then expect the same code to be wrong the moment your gate has a nonzero RPL field set for some unrelated reason. The bug is real and it is silent, which is the worst combination.)</em></li>
                    <li><strong>Find your own kernel's segment layout from a running process.</strong> Read <code>CS</code> and <code>SS</code> and decode the indices as this page does, then read the GDT base with <code>SGDT</code> and try to read descriptor 5 and 6 yourself. <em>(Expect the read to die with <code>si_code 1</code> and an address equal to the GDT base &mdash; exactly the shape of the IDT result, and for the same reason. If it does not, your kernel maps the GDT into user space on purpose, which some hardened kernels do, and the asymmetry this course measured is not universal.)</em></li>
                    <li><strong>Count the segment instructions your backend emits.</strong> In a compiler that targets long mode, segment overrides and <code>%fs</code> bases are almost the only places segmentation appears. <em>(Expect the answer to be two or three instructions in the entire program, and expect the reason to be that the ABI you have to implement is a <em>register</em> convention. That is the same shape as the argument for the fourth argument being <code>R10</code>, and it is why the machine's segment machinery is now a compatibility feature rather than a mechanism.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, <a href="/courses/priv/lessons/priv-table">the privilege course's gate-table concept</a> is where this page's central measurement was first taken &mdash; <code>SIDT</code> returns and the table does not &mdash; and the difference is that this course also reads the GDT, decodes the selector, and shows that the reason for the asymmetry is a mapping rather than a privilege. <a href="/courses/priv/lessons/priv-convention">Its ring-diagram concept</a> is the <em>why</em> behind the <code>max(CPL,RPL) &le; DPL</code> comparison; this page is the reference for which comparison applies to which gate.</p>
                <p>Forwards. The fourth concept is the five control registers, and the connection is the row that failed: <code>CR4.UMIP</code> is the bit that decides whether the five reads in this concept's table are legal at all, and reading it is a fault. <strong>This concept measured the consequence; the next one names the bit and says it cannot be read.</strong> That pairing is the shape of the whole course and it recurs in every remaining concept.</p>
                <p>Outward. The <code>IA32_STAR</code> MSR holds the two selectors a <code>syscall</code> loads on the way in and the two it restores on the way out, which is the one place where this page's material is still load-bearing in long mode: <code>syscall</code> is defined in terms of the very segment registers whose descriptors stopped existing. <a href="/courses/isa/lessons/isa-modes">The ISA course</a> covers the mode-switch machinery; the eighth concept here is where the MSRs themselves are shown to be unreadable.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/x86sys/lessons/x86-exceptions">All Thirty-Two, As an x86-64 Reference</a></span>
                <span>Next: <a href="/courses/x86sys/lessons/x86-cr">CR0 to CR4, Every Bit</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
