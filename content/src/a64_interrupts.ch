// The AArch64 Machine: Modes, Memory and Faults -- Concept 3: the vector
// table at VBAR_ELx.
//
// The measured part of this concept is small and the ABSENCE is large: the
// table's sixteen offsets, its size and its four-relocation install are all
// things an assembler will tell you, and the requirement that the table be
// 2 KiB aligned is a requirement NOTHING in the toolchain checks.  R8 and R9
// both live here, and R9 is the one worth reading twice: four different
// alignment directives and four times no diagnostic.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_interrupts() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sixteen Entries of 0x80, and Four Times No Diagnostic — Underlayer")
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
            <h1>Sixteen Entries of 0x80, and Four Times No Diagnostic</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Where does the CPU go when something happens? Not "somewhere in the kernel" — at a <strong>computed address</strong>, and the arithmetic is two instructions long: the base register plus the vector number times a fixed stride. That is the whole dispatch mechanism, and it is the reason an AArch64 kernel's first four kilobytes are a table of branches rather than a table of function pointers: the entry is a branch, so a vector can be a <code>b</code> to a shared handler and the four exception types are four branches rather than four indirect jumps.</p>
                <p>And the reason this concept is worth a page of its own rather than a paragraph is the measurement at the end, which is an <strong>absence of a diagnostic</strong>. The table has a hard alignment requirement, the requirement is architectural, and <em>nothing in the toolchain checks it</em>. A misaligned vector table is not an error. It is a jump to the wrong address, discovered by the first exception the system takes, which on a machine that boots is very early and on a machine that has been running for a month is very late.</p>
                <div class="formula">
   THE SHAPE OF THE MEASUREMENT

   Measured:  the table's size, all sixteen offsets,
              the encoding of the read and the write,
              the two relocations of the install, and
              what four different alignment directives
              do.

   Measured by its ABSENCE:  that none of the four
              produces a diagnostic.

   A course with hardware would measure the fault.
   This one measures the silence, and prints the
   silence in the place a reader would expect the
   fault to be justified.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>The model: base plus vector times 0x80</h2>
                <p>The quoted part first, because everything measured on this page is measured <em>against</em> it. The architecture defines a table of <strong>sixteen entries</strong>, each <strong>0x80 bytes</strong>, indexed by a <em>vector number</em> that is built from the exception type and the exception level pair. Sixteen times 0x80 is 0x800 — two kibibytes — and that is not a coincidence: the low eleven bits of <code>VBAR_ELx</code> are <code>RES0</code>, so the base itself must be 2&nbsp;KiB aligned or the architecture cannot represent the address at all.</p>
                <p>Now the measurement, and the reason to print all sixteen rows rather than state the size: a table of offsets is exactly where a real error would show, and the error this method is most likely to have is one entry out by 0x80.</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 6 | sed -n '/the table the assembler BUILT/,/^$/p'
  [MEASURED] the table the assembler BUILT, from vec.s

     vector #   name              symbol value   value &amp; 0x7f   value / 0x80
     0         el0t_sync         0x800       0             16
     1         el0t_irq          0x880       0             17
     2         el0t_fiq          0x900       0             18
     3         el0t_serror       0x980       0             19
     4         el0t_sync_a64     0xa00       0             20
     5         el0t_irq_a64      0xa80       0             21
     6         el0t_fiq_a64      0xb00       0             22
     7         el0t_serror_a64   0xb80       0             23
     8         el0i_sync         0xc00       0             24
     9         el0i_irq          0xc80       0             25
     10        el0i_fiq          0xd00       0             26
     11        el0i_serror       0xd80       0             27
     12        el1t_sync         0xe00       0             28
     13        el1t_irq          0xe80       0             29
     14        el1t_fiq          0xf00       0             30
     15        el1t_serror       0xf80       0             31

     the table symbol: value 0x0, SIZE 2048 bytes (0x800)

  [RESULT]           16 x 0x80 = 0x800, and the assembler MEASURED that as 2048 bytes
                </pre>
                </div>
                <p>All sixteen are multiples of 0x80, all sixteen fall between 0x800 and 0xf80, and the sixteenth is at 0xf80 — so the table spans exactly sixteen slots from 0x800 to 0xfff inclusive. <strong>The size came out of the symbol table, not out of a formula I typed in.</strong> That distinction is the whole method: <code>.size vectors, . - vectors</code> asked the assembler, and the answer was 2048.</p>
                <p>The labels are also the quoted layout, printed by the assembler into a file on this disk: the first four are EL0 arriving with SP0, the next four are EL0 arriving with SP0 in AArch64 state, the next four are EL0 arriving with SP<i>x</i>, and the last four are a lower EL arriving to EL1 in AArch64 state. <strong>EL0 always lands in the first eight</strong> — the machine chooses, and the choice is a consequence of the rule that EL0 cannot set <code>VBAR_ELx</code> at all, because the register only exists at EL1 and above.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement: the encoding, the install, and four cases of silence</h2>
                <p>Writing the table's address into the register is a <em>data</em> instruction. That is the first surprise, and it is measured on bytes:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 6 | sed -n '/reading and writing VBAR/,/^$/p'
  [MEASURED-ON-BYTES] the encoding of reading and writing VBAR
     mrs x0, VBAR_EL1   0xd538c000  L=1  CRn=0xc CRm=0x0 op2=0  mrs      x0, VBAR_EL1
     msr VBAR_EL1, x0   0xd518c000  L=0  CRn=0xc CRm=0x0 op2=0  msr      VBAR_EL1, x0
                </pre>
                </div>
                <p>One bit — bit 21 — separates the read from the write, and the five-field register name is identical in both. <strong>So installing the vector table looks in a disassembly exactly like reading a variable</strong>, and a reader scanning an object file for "where does this program install its exception handlers" is looking for an <code>msr</code> and will find one that looks like a load.</p>
                <p>The full install, five instructions, read out of the symbol table:</p>
                <div class="hex-dump">
                <pre>     install_vbar, at 0xf84, 20 bytes, from the symbol table:
       0x90000000  adrp     x0, +0
       0x91000000  add      x0, x0, #0x0
       0xd518c000  msr      VBAR_EL1, x0
       0xd5033fdf  isb
       0xd65f03c0  ret
                </pre>
                </div>
                <p>And the two relocations that <code>adrp</code> + <code>add</code> cost, which is the same pair <a href="/courses/a64sys/lessons/a64-syscall">concept 1</a> measured for a syscall number loaded from memory:</p>
                <div class="hex-dump">
                <pre>     the relocations the pair emits:
      0x002010c4  R_AARCH64_ADR_PREL_PG_HI21   vectors + 0
      0x002010c8  R_AARCH64_ADD_ABS_LO12_NC    vectors + 0
                </pre>
                </div>
                <p>Two relocations, adjacent, against one symbol, four bytes apart. <strong>On AArch64 there is no encoding of "one relocation that means an address"</strong>, and a 2&nbsp;KiB-aligned table is not a special case of that — it is the ordinary case. <a href="/courses/a64sys/lessons/a64-pagetables">Concept 5</a> measures why, and the reason is not the one the section plan gave.</p>
                <h3>And now the four cases of silence</h3>
                <p>Four alignment directives, four identical object files in shape, four times no diagnostic:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 6 | sed -n '/what the assembler does about/,/^$/p'
  [MEASURED] what the assembler does about the alignment, and what it does NOT
     source                      section align   label value  diagnostic?
     .align 11 (2 KiB)        2048            0x0         NONE
     .align 8 (256 B)         256             0x0         NONE
     no .align at all         4               0x0         NONE
     .align 12 (4 KiB)        4096            0x0         NONE

     . FOUR CASES, FOUR TIMES NO DIAGNOSTIC. The section alignment is
     . whatever the directive says, the table is where the label is, and
     . the assembler has no idea that a 2 KiB-aligned array of branch
     . instructions is going to be handed to a register whose low eleven
     . bits are RES0.
                </pre>
                </div>
                <div class="formula">
   R9, and it is the concept

   DRAFT      "put `.align 11` before the vector
               table and it is valid."

   MEASURED   `.align 11` is NECESSARY and NOT
               SUFFICIENT, and nothing checks it.  The
               assembler honours the alignment, the
               table is 0x800 bytes, and the register
               that consumes the address is written at
               RUNTIME by an `msr` whose only check is
               architectural.

   A kernel that computes the address with adrp +
   add :lo12: and writes it to VBAR with the low
   eleven bits set will fault on the first exception
   it takes -- and no assembler, linker or compiler
   will have said anything.

   This is the difference between a REQUIREMENT and
   a DIAGNOSTIC, and it is the most useful thing a
   toolchain course can teach about a requirement.
                </div>
                <p>Note the third row: <strong>with no <code>.align</code> at all the section comes back with alignment 4</strong>, which is what an <code>x86-64</code>-shaped intuition predicts and which is four hundred times too small. The assembler is not ignoring the requirement — there is no requirement in its input. It is aligning the <em>instruction</em> stream, and four is the alignment of a 32-bit instruction.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the arithmetic of a vector, and the one thing you cannot check</h2>
                <p>Given a base and a vector number, the entry address is <code>base + vector * 0x80</code>. That is the whole dispatch, and it means the table can be relocated as a unit: put it anywhere 2&nbsp;KiB aligned and the arithmetic follows. Which is the property that makes the table <em>relocatable</em> and also the property that makes the <code>:lo12:</code> pair necessary — the linker can move the base and fix the relocation, and if the relocation were a single 21-bit page-relative field there would be nothing left to fix up.</p>
                <div class="hex-dump">
                <pre>     for a 0x800-aligned table at 0xffff8000_00800000:

       vector  0  Sync   0xffff8000_00800000
       vector  1  IRQ    0xffff8000_00800080
       vector  2  FIQ    0xffff8000_00800100
       vector  3  SError 0xffff8000_00800180
       ...
       vector 15  SError 0xffff8000_00800780

     and the LAST valid byte of the table is
       0xffff8000_008007ff
     which is base + 0x7ff -- 0x800 bytes minus one.
                </pre>
                </div>
                <p>Two things to notice in that arithmetic, and the second is the trap.</p>
                <ul>
                    <li><strong>The stride is 0x80 and the <em>entries</em> are 0x80 bytes, so the table is exactly full.</strong> The last entry ends at <code>base + 0x7ff</code> and the byte after it belongs to something else. There is no slack and no alignment padding between entries, which means a handler cannot be longer than 0x80 bytes without either overflowing into the next vector or needing its own trampoline — and trampolines are the standard answer, which is why real vector tables are full of <code>b</code> instructions rather than handlers.</li>
                    <li><strong>The vector number is not a small integer.</strong> It is a <em>packing</em> of the exception type and the exception level pair, and the packing is quoted. So a table written by hand has to get sixteen orderings right, and <strong>getting the order wrong produces a table that works</strong> — every entry is a valid branch, every address is inside the table, and the jump lands in a handler for the wrong exception. Like the alignment case, this is not an error. It is a wrong answer.</li>
                </ul>
                <h3>What this page cannot show</h3>
                <p>It cannot show an interrupt being taken, a vector being entered, a <code>VBAR</code> write being honoured, or a misaligned table faulting. <strong>All four would need an AArch64 machine, an emulator or a linker, and this host has none of the three.</strong> The sixteen entries, the four exception types, the (source EL, target EL) pair that selects the first four, the requirement that the low eleven bits of <code>VBAR</code> be zero, and the fact that EL0 cannot install a table — all of that is quoted. What is measured is the table the assembler built, its size, its sixteen offsets, the four different things the assembler does with an alignment directive, the encoding of the read and the write, and the two relocations of the install. <strong>Six results, and the largest of them is an absence.</strong></p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Build the table and let the assembler tell you the size.</strong> Write a <code>.s</code> file with <code>.align 11</code>, sixteen <code>b label</code> entries, and <code>.size vectors, . - vectors</code>; assemble it and read the size back with <code>llvm-readelf-21 -s</code>. <em>(Expect 2048. Then delete the <code>.align 11</code>, reassemble, and check the size is <em>still</em> 2048 — the size is the same and the <em>alignment</em> is what changed, which is the whole distinction. Now check the section header's alignment in both cases: 2048 and 4.)</em></li>
                    <li><strong>Get the missing diagnostic yourself.</strong> Take the <code>.align 8</code> version — 256-byte alignment, a table 0x800 bytes long — and ask what the low eleven bits of the <code>adrp</code>-computed address are. <em>(Expect that they are not zero, and that the assembler did not object, and that <code>msr vbar_el1, x0</code> assembles just as happily over a misaligned <code>x0</code> as over a good one. The architectural check happens when the <em>write</em> is interpreted, which is the moment you cannot reach from here. That sentence is the concept.)</em></li>
                    <li><strong>Count the relocations, and then break the pairing by hand.</strong> Assemble the <code>adrp</code> + <code>add :lo12:</code> pair and read <code>llvm-readelf-21 -r</code>. <em>(Expect two, four bytes apart, with the names <code>R_AARCH64_ADR_PREL_PG_HI21</code> and <code>R_AARCH64_ADD_ABS_LO12_NC</code>. Then write <code>adrp x0, vectors</code> with no partner and look at the object: one relocation, and an address that is wrong by whatever the low twelve bits happen to be. There is no diagnostic for the missing partner either — the <em>assembler</em> does not know you needed one, because <code>adrp</code> on its own is a legal instruction with a legal meaning.)</em></li>
                    <li><strong>Write a trampoline table and measure it.</strong> Sixteen <code>b</code> instructions, then 0x80 bytes of handler after each, with the <code>.balign 0x80</code> that the layout requires. <em>(Expect the section to grow to 0x4000 and the symbol table to show every handler at a multiple of 0x80. Now delete one <code>.balign</code> and watch the offsets go irregular — and note that the assembler again says nothing, because <code>.balign</code> between handlers is a layout convention the assembler honours and a convention it does not enforce. Three silences on one page, and they are all the same silence: a linker-time and run-time requirement that no compiler checks.)</em></li>
                    <li><strong>Compare with x86-64's IDT and find the asymmetry.</strong> <a href="/courses/isa/lessons/isa-modes">The instruction-set course's interrupt concept</a> gives you the x86-64 picture: an IDT of 256 eight-byte entries, a gate, and a privileged <code>LIDT</code>. Build the AArch64 equivalent from this page and put the two side by side. <em>(Expect x86-64 to have <em>one</em> gate format covering all 256 vectors, and AArch64 to have 16 fixed-size slots with the type packed into the <em>index</em>. The x86-64 design scales to 256 vectors because the gate is a fixed 8 bytes; the AArch64 design is cheaper per vector and tops out at 16 because the stride is a constant. Neither is wrong and they optimise for different things, and the reason a reader should care is that the AArch64 one is the design a compiler backend has to emit a <em>table</em> for and the x86-64 one is the design it has to emit a <em>pointer to</em>.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, and the link is one register. <a href="/courses/a64sys/lessons/a64-exceptions">Concept 2</a> measured <code>mrs x6, ELR_EL1</code> — the address the CPU will return to. This page is the address it goes to <em>first</em>, and the two are written in the same six-instruction prologue of every handler. <a href="/courses/a64sys/lessons/a64-syscall">Concept 1</a> measured the other side of the same register file: the <code>adrp</code> + <code>add</code> pair that computes the table's address is identical whether the thing being named is a string, a syscall number or a vector table, and the two relocations are identical too. <a href="/courses/a64asm/lessons/a64-cond">The encoding course's condition-code chapter</a> is not needed here, but its <code>RET</code> model is: <a href="/courses/a64abi/lessons/a64-registers">the ABI course</a> is where <code>x30</code> and <code>eret</code> meet, and <code>eret</code> is one bit away from <code>drps</code> — both <code>0xd6?f03e0</code>, both with 32 bits and no operands.</p>
                <p>Sideways, the neighbours that own the edges. <a href="/courses/priv/lessons/priv-vectors">The neutral course owns the vector model</a>, and the reason this page can be short is that page: what a vector is, why there are several, and what a dispatcher is. <a href="/courses/smp/lessons/smp-topology">The SMP course's interrupt concept</a> owns what happens when two CPUs take an interrupt at once, and this page owns the per-CPU part of that: <code>VBAR_EL1</code> is per exception level, so a four-core machine has four tables, and the address a given core uses is the one its own register holds. <a href="/courses/dyn/lessons/dyn-order-runtime">The dynamic-linking course</a> is where a frame gets walked for the first time in a real program, and a vector table is the one place in a program where that walk begins before <code>main</code>.</p>
                <p>Outward, and this is the concept the whole course is built around. <strong>A requirement that no tool checks is a requirement you have to check yourself, and the tools will not even tell you that you have not checked it.</strong> Four alignment directives and four times no diagnostic is the same shape as the HINT guard bug in <a href="/courses/a64asm/lessons/a64-verify">the encoding course's cross-check</a> — a model that is right about what it is asked and is never asked about the rest — and it is the same shape as the ADRP pair in concept 5: a thing that is correct in isolation and undefined in combination. A reader who has finished this course should have a reflex for the pattern: <em>where is the requirement stated, who checks it, and what happens if it is violated?</em></p>
                <p>And the honest accounting. Everything quoted on this page is about a machine that does not exist here. Everything measured is about an assembler that does. <a href="/courses/a64sys/lessons/a64-evidence">Concept 6</a> prints the boundary for the whole course, and it is the concept that makes the other five worth reading.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64sys/lessons/a64-exceptions">One Register, Three Fields, and Thirty-Nine Meanings</a></span>
                <span>Next: <a href="/courses/a64sys/lessons/a64-virtual">T0SZ = 64 - 48, and the Field With a Floor</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
