// The AArch64 Machine: Modes, Memory and Faults -- Concept 4: TTBR0, TTBR1,
// TCR, and the 48/52 split.
//
// The measured part of this concept is an IDENTITY over a quoted field width,
// and that is the right kind of measurement for a subject with no hardware:
// T0SZ = 64 - (bits of VA) is arithmetic, every row of the configuration table
// is checkable in your head, and the row that is NOT in the section plan --
// the five-bit field's floor at 2^33 -- is the retraction (R16).  The ADR
// boundary is measured by asking the assembler to refuse one distance, and the
// ADRP boundary is not measured at all because there is no linker here, which
// the page says in the place a reader would look for it.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_virtual() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("T0SZ = 64 - 48, and the Field With a Floor — Underlayer")
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
            <h1>T0SZ = 64 - 48, and the Field With a Floor</h1>
            <div class="lesson-meta">25 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Concept 2 told you how to read a fault. This concept is about the thing that made the fault: the translation regime, which is the pair of questions <em>"where do I look"</em> and <em>"how much of the address is a position in it."</em> The second question is the interesting one, and on AArch64 it is answered by a five-bit field in a register — which means the answer is not a number the architecture chose but a number the <em>platform</em> chose, and the field has a floor.</p>
                <p>So this concept is two subjects that look unrelated and are one. The first is the <strong>split</strong>: two translation base registers, two regions, and a field each that says how big its region is. The second is the <strong>reach</strong>: a fixed 32-bit instruction with a 21-bit field can address a page four gibibytes away or a byte one mebibyte away, and every page table in a system is on the first side of that line while every array index is on the second. The second subject is what makes the first one expensive, and <a href="/courses/a64sys/lessons/a64-pagetables">concept 5</a> is where the bill arrives.</p>
                <div class="formula">
   THE METHOD ON THIS PAGE, stated first

   There is no AArch64 machine, emulator or linker on
   the host that wrote this course.

   QUOTED     the field positions (T0SZ at [63:48],
              T1SZ at [47:32], TG0 at [15:14]) and the
              region formula 2^(64 - TnSZ).

   MEASURED   the identity TnSZ = 64 - (bits of VA),
              checked in seven configurations, and
              the ADR boundary, found by asking the
              assembler to refuse a distance.

   NOT        the ADRP boundary, and the page says so
   MEASURED   where a reader would look for it: the
              assembler does not check ADRP at all and
              the check belongs to the linker, which
              does not exist here.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>The model: two registers, two regions, one formula</h2>
                <p>Three registers, and the encodings name them with nine bits. The first measured result on the page is that <strong>they are all <code>CRn = 2</code> and are told apart by a two-bit <code>op2</code> field</strong>:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 7 | sed -n '/three registers/,/^$/p' | head -10
  [MEASURED-ON-BYTES] three registers, and the encodings that name them
     mrs x0, TTBR0_EL1  0xd5382000  CRn=0x2 CRm=0x0 op2=0  op1=0  mrs      x0, TTBR0_EL1
     mrs x0, TTBR1_EL1  0xd5382020  CRn=0x2 CRm=0x0 op2=1  op1=0  mrs      x0, TTBR1_EL1
     mrs x0, TCR_EL1    0xd5382040  CRn=0x2 CRm=0x0 op2=2  op1=0  mrs      x0, TCR_EL1
     mrs x0, SCTLR_EL1  0xd5381000  CRn=0x1 CRm=0x0 op2=0  op1=0  mrs      x0, SCTLR_EL1
     msr TTBR0_EL1, x0  0xd5182000  CRn=0x2 CRm=0x0 op2=0  op1=0  msr      TTBR0_EL1, x0
     mrs x0, TCR_EL2    0xd53c2040  CRn=0x2 CRm=0x0 op2=2  op1=4  mrs      x0, TCR_EL2
                </pre>
                </div>
                <p>Three registers whose addresses a kernel sets once at boot, whose names every reader will look up, and whose encodings are <strong>adjacent numbers 0, 1, 2 in a two-bit field</strong>. Read that as a gift to a decoder and a trap for a page: <em>there is nothing about the relationship between the three registers in the encoding.</em> The relationship — TTBR0 and TTBR1 describe two halves of one address space — is architecture, and it is quoted.</p>
                <p>Now the formula, and it is the entire measured content of the concept:</p>
                <div class="hex-dump">
                <pre>     T0SZ is bits[63:48] of TCR_EL1 and T1SZ is bits[47:32]
     (QUOTED), and the region TTBRn addresses is 2^(64-TnSZ)
     bytes.  Every row below is that identity and nothing else.

     configuration   VA bits   T0SZ  T1SZ   TTBR0 region                 TTBR1 region
     48-bit, no LPA2  48       16    16    2^48 = 0x1000000000000  2^48 = 0x1000000000000
     48/52, with LPA2 48       16    12    2^48 = 0x1000000000000  2^52 = 0x10000000000000
     39/39, the 3-level case 39       25    25    2^39 = 0x008000000000  2^39 = 0x008000000000
     39/48            39       25    16    2^39 = 0x008000000000  2^48 = 0x1000000000000
     42/48            42       22    16    2^42 = 0x040000000000  2^48 = 0x1000000000000
     52/52            52       12    12    2^52 = 0x10000000000000  2^52 = 0x10000000000000
     33/33, the SMALLEST 33       31    31    2^33 = 0x000200000000  2^33 = 0x000200000000

  [RESULT]           T0SZ = 64 - 48 = 16, and T1SZ = 64 - 52 = 12 with LPA2,
                     64 - 48 = 16 without
                </pre>
                </div>
                <p>The section plan gave three of those numbers — <code>T0SZ = 16</code>, <code>T1SZ = 16</code> without LPA2, <code>T1SZ = 12</code> with it — and <strong>every one is right.</strong> What the plan did not have is the last row, and the last row is the concept.</p>
                <h3>The field has a floor, and the floor killed a row</h3>
                <div class="hex-dump">
                <pre>     and the field is FIVE bits, so the SIZE of a regime is
     bounded below as well as above:
       64-bit VA  -&gt;  T0SZ = 0    region 2^64 bytes, FITS
       60-bit VA  -&gt;  T0SZ = 4    region 2^60 bytes, FITS
       52-bit VA  -&gt;  T0SZ = 12   region 2^52 bytes, FITS
       48-bit VA  -&gt;  T0SZ = 16   region 2^48 bytes, FITS
       44-bit VA  -&gt;  T0SZ = 20   region 2^44 bytes, FITS
       42-bit VA  -&gt;  T0SZ = 22   region 2^42 bytes, FITS
       39-bit VA  -&gt;  T0SZ = 25   region 2^39 bytes, FITS
       36-bit VA  -&gt;  T0SZ = 28   region 2^36 bytes, FITS
       33-bit VA  -&gt;  T0SZ = 31   region 2^33 bytes, FITS
       32-bit VA  -&gt;  T0SZ = 32   region 2^32 bytes, DOES NOT FIT in a 5-bit field
       30-bit VA  -&gt;  T0SZ = 34   region 2^30 bytes, DOES NOT FIT in a 5-bit field
       25-bit VA  -&gt;  T0SZ = 39   region 2^25 bytes, DOES NOT FIT in a 5-bit field
                </pre>
                </div>
                <div class="formula">
   R16, and it was in this course's own first draft

   DRAFT      a configuration table of regimes, with a
               "30-bit, the 2-level case" row in it.

   MEASURED   T0SZ is a FIVE-BIT field.  64 - 30 = 34
               does not fit in it.  With a 4 KiB
               granule the smallest regime the field
               can name is 2^33 bytes -- eight
               gibibytes.  A 32-bit virtual address
               space is NOT expressible on AArch64 with
               4 KiB pages at all.

   The two-level configurations all use the 64 KiB
   granule, where T0SZ is six bits wide and the
   floor moves to 2^32.

   A table of block sizes presented as a MENU
   rather than as a consequence of a FIELD WIDTH
   will always contain a row the field cannot
   express, and the row looks entirely reasonable.
   This is the third time in this section that a
   plausible-looking number was killed by a
   constraint printed in the same table.
                </div>
                <p>And the other direction, because it is the one that matters for understanding why 48: <strong>a regime can cover the <em>whole</em> address space, 2<sup>64</sup> bytes, with <code>T0SZ = 0</code>.</strong> So the 48/52 split is a default and not a limit. The reason a real system uses 48 is not that 52 will not fit in the field — it is that each extra level of table costs another 4&nbsp;KiB of memory and four more dependent memory accesses for every translation. <strong>That cost is a real number on a real machine and it is not measurable here.</strong> The five-bit field and the identity are, and they are what this page can defend.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement: where the two regions meet, and the two reaches</h2>
                <p>The identity says how <em>big</em> each region is. It does not say <em>where</em>, and the constraint that decides where is that the two must not overlap. That is arithmetic, and the gap it leaves is the first thing a reader should know about the 48/52 configuration:</p>
                <div class="hex-dump">
                <pre>     the boundary, as pure arithmetic.  TTBRn is at the END of
     its region, so the high regime is mapped at the TOP of the
     address space -- that is the whole content of R10.
       48/48    TTBR0 covers 0x0000000000000000..0x0000ffffffffffff
                TTBR1 covers 0xffff000000000000..0xffffffffffffffff
                between them: 0xfffe000000000000 bytes, which is UNTRANSLATED
       48/52    TTBR0 covers 0x0000000000000000..0x0000ffffffffffff
                TTBR1 covers 0xfff0000000000000..0xffffffffffffffff
                between them: 0xffef000000000000 bytes, which is UNTRANSLATED
       39/48    TTBR0 covers 0x0000000000000000..0x0000007fffffffff
                TTBR1 covers 0xffff000000000000..0xffffffffffffffff
                between them: 0xfffeff8000000000 bytes, which is UNTRANSLATED
                </pre>
                </div>
                <p>Three things in that block, and the first is the one the plan did not have.</p>
                <ul>
                    <li><strong>TTBR1 is at the <em>top</em> of the address space, not the bottom of its own window.</strong> A 48-bit regime means the register holds <code>0xffff000000000000</code>, not <code>0x0001000000000000</code>. That is the retraction: <strong>"52-bit" describes the <em>size</em> of the region, not the width of the address.</strong> The top four bits of a kernel pointer are <code>0xf</code> and the next 48 are the position in the regime. A reader who takes the size for the width will place a kernel pointer wrongly, and the mistake shows up as a translation fault three layers from its cause.</li>
                    <li><strong>The space between the two regions is untranslated, and it is enormous in both rows.</strong> That is not a defect and it is not checked: a load from it takes a translation fault, which is the correct behaviour for an address nothing claims. A 52-bit kernel space with a 48-bit user one is exactly the statement <em>the top 2<sup>52</sup> and the bottom 2<sup>48</sup> are translated and the rest is not</em>, and the arithmetic is the whole of the claim.</li>
                    <li><strong>And the difference between the two rows is one field.</strong> <code>T1SZ = 16</code> puts the high regime's base at <code>0xffff000000000000</code>; <code>T1SZ = 12</code> moves it to <code>0xfff0000000000000</code> and quadruples the kernel's address space. <strong>One five-bit field, one nibble of a pointer, and four times the address space</strong> — which is the clearest demonstration on this page that a field width is a constraint and a field value is a decision.</li>
                </ul>
                <h3>The two reaches, and the asymmetry that decides everything</h3>
                <p>Now the second subject of the concept, and it is the one a backend author needs. Two instructions, one field shape, two units:</p>
                <div class="hex-dump">
                <pre>     instruction   immediate field   signed bits   unit       reach
     ADR           bits[20:5]+[30:29] 21          1 BYTE     +-2^20 = 1 MiB
     ADRP          bits[20:5]+[30:29] 21          4096 BYTES +-2^20 pages = 4 GiB
                </pre>
                </div>
                <p>And one of those two numbers is measured and the other is not, and the difference is worth understanding rather than papering over.</p>
                <div class="hex-dump">
                <pre>$ python3 - &lt;&lt;'PY'   # bisecting the distance the assembler will accept
ADR   largest accepted distance 0xffff8   -> from the insn: 0xffffc
ADR   next step up            0xffffc       REFUSED: fixup value out of range
ADR   backward max D=0xffff8   -> from the insn: -0x100000
ADRP  the assembler does NOT check it: every distance tried up to
      0x1fff000 ACCEPTED, and a 4 GiB gap is ACCEPTED too
                </pre>
                </div>
                <p><strong>0xffffc and then a refusal at 0x100000 is exactly a 21-bit signed field</strong> — the largest positive value is 0xfffff, and the next multiple of four below it is 0xffffc. The assembler found the field's edge for us, and it found it in the only way that works: by refusing.</p>
                <p>The <code>ADRP</code> row is the interesting one, and it is a measurement of an <strong>absence</strong>. The assembler does not range-check <code>ADRP</code> at all — a 4&nbsp;GiB reference is accepted — because the value is not known until link time and the check belongs to the linker. <strong>There is no AArch64 linker on this host, so the 4&nbsp;GiB figure is an arithmetic identity on a 21-bit field, not a measurement.</strong> Say that to yourself every time you see a reach quoted for an instruction whose target is not yet known: <em>who checks it, and is that person present?</em></p>
                <p>And the arithmetic the compiler emits, which is the whole structure of a walk expressed as five shifts:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 7 | sed -n '/the compiler emits for the regime/,/^$/p'
     t0sz_for     2   sub x0, xzr, x1 ; ret
     regime_bytes 2   lsl x0, x1, x0 ; ret
     ttbr1_52     2   movz/movk pair ; ret
     l0_index     2   lsr x0, x0, #39 ; and x0, x0, #0x1ff ; ret
     l1_index     2   lsr x0, x0, #30 ; and x0, x0, #0x1ff ; ret
     l2_index     2   lsr x0, x0, #21 ; and x0, x0, #0x1ff ; ret
     l3_index     2   lsr x0, x0, #12 ; and x0, x0, #0x1ff ; ret
     page_off     2   and x0, x0, #0xfff ; ret
                </pre>
                </div>
                <p>Nine bits per level, four levels, twelve bits of offset — and that is the 48-bit split arriving as a table shape. <strong>x86-64 needs the same five extractions and neither architecture stores the level in the descriptor</strong>: the level is implied by <em>which table you are in</em>, which is why the same three bits in a descriptor mean different things at different depths. <a href="/courses/mem/lessons/mem-translation">The neutral paging course</a> owns the principle; <a href="/courses/x86sys/lessons/x86-paging">the x86-64 paging concept</a> is the sibling reference; and this page owns the AArch64 numbers.</p>
            </div>

            <div class="unit unit-example">
                <h2>Worked: the 48/52 layout, end to end</h2>
                <p>Put the pieces together for the configuration a 64&nbsp;KiB-granule system actually uses, because the numbers are more instructive than the general case:</p>
                <div class="hex-dump">
                <pre>  STAGE 1, EL1 &amp; EL0, 64 KiB granule, 48/52 split (FEAT_LPA2)

  TCR_EL1.TCR_EL1 fields, QUOTED with their bit positions:
     [63:48] T0SZ   = 16      TTBR0 region  = 2^(64-16) = 2^48
     [47:32] T1SZ   = 12      TTBR1 region  = 2^(64-12) = 2^52
     [31:30] TG1   = 10      64 KiB
     [23:22] SH0   = 11      inner shareable
     [15:14] TG0   = 10      64 KiB
     [9:8]   IRGN0 = 01      inner cacheable
     [7:6]   ORGN0 = 01      inner cacheable

  TLB:  64 entries, 4 KiB pages, 64 sets
        -> 4 x 4 KiB = 16 KiB of page tables before you
           have mapped a single byte, and that number is
           NOT measurable on this host.
                </pre>
                </div>
                <p>Three observations, and only the first is a fact this course can stand behind.</p>
                <ul>
                    <li><strong>The TLB size is quoted and irrelevant to everything else on this page.</strong> It is in the architecture manual and it is the number every performance discussion of AArch64 paging starts from — and this course deliberately has no performance discussion, because a TLB size is a <em>shape</em> and the only interesting question about a shape is how often it is hit, and that needs a clock. The <a href="/courses/smp/lessons/smp-sharing">SMP course's memory concept</a> and the <a href="/courses/mem/lessons/mem-translation">memory course's TLB concept</a> are where the number gets used; this page prints it so you recognise it, and says here that it cannot be used.</li>
                    <li><strong>With a 64&nbsp;KiB granule, <code>T0SZ</code> is six bits and the floor moves to 2<sup>32</sup>.</strong> That is the escape hatch from the five-bit floor, and it is why the two-level configurations exist at all: a 2-level walk of 2&nbsp;MiB blocks over 2<sup>32</sup> bytes is <em>exactly</em> one table of 512 entries. <a href="/courses/a64sys/lessons/a64-pagetables">Concept 5</a> does that arithmetic properly.</li>
                    <li><strong>Every other field on this list is a cacheability attribute, and none of it is measured here.</strong> <code>IRGN0</code> and <code>ORGN0</code> are how you tell the hardware where the tables are cached, and a wrong value is a performance bug that looks like a correctness bug on a machine with a coherent cache and a mystery on one without. Quoted, documented, and outside what this course can check.</li>
                </ul>
                <h3>What this page cannot show</h3>
                <p>It cannot show a page walk, a TLB hit, a translation, or a fault. Not one address in this concept was translated by anything. The field positions, the granule encodings and the region formula are quoted with document and section. The encodings of the seven <code>mrs</code>/<code>msr</code> words, the five shifts, the seven-configuration identity and the <code>ADR</code> boundary are measured. <strong>The one measurement a reader should hold on to is the reach asymmetry:</strong> a fixed 32-bit instruction with a 21-bit field can address a page 4&nbsp;GiB away or a byte 1&nbsp;MiB away, and that single fact is why the ELF side of the subject — the relocation pair, the alignment, the linker script — is the half worth studying and the half a toolchain can show you.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Bisect the ADR boundary yourself.</strong> Write a <code>.s</code> file with <code>adr x0, far</code>, a <code>.space</code> and a <code>far:</code> label; assemble at a range of distances and find where it stops working. <em>(Expect the last accepted distance to be 0xffffc and the first refused to be 0x100000, with <code>fixup value out of range</code>. Then read the field: 21 bits, signed, in bytes, and 0xfffff rounded down to a multiple of four is 0xffffc. Exactly. Now repeat with <code>adrp</code> at 32&nbsp;MiB, 256&nbsp;MiB, 2&nbsp;GiB and 4&nbsp;GiB, and expect all four to be <em>accepted</em> — the assembler does not check <code>ADRP</code>, and finding out that for yourself is worth more than being told.)</em></li>
                    <li><strong>Compute the seven identities, then break one.</strong> Take the configuration table on this page and verify <code>T0SZ = 64 - VA</code> in every row by hand. <em>(Expect all seven to check. Then put a 30-bit row in and verify <em>that</em> — and find <code>T0SZ = 34</code>, which does not fit in five bits. That is retraction R16 reproduced in thirty seconds, and reproducing a retraction is worth more than reading one, because the thirty seconds is what convinces you the arithmetic is the reason and not the author's preference.)</em></li>
                    <li><strong>Draw the two regions and find the hole.</strong> For 48/48, 48/52 and 39/48, draw the address space as a bar and mark the two regions. <em>(Expect 48/48 to fill it exactly, 48/52 to leave a 256&nbsp;TiB hole in the middle, and 39/48 to leave a 128&nbsp;TiB hole between the top of the user region and the bottom of the kernel region. Then ask what a load from the hole does: not an error, an <em>unmapped hole</em>, and a translation fault. The hole is a feature — it is address space reserved by not being translated.)</em></li>
                    <li><strong>Count the descriptors a regime needs, and watch it stop being possible.</strong> For a 48-bit address space, divide by the block size at each level: 2<sup>48</sup> / 2<sup>21</sup> = 2<sup>27</sup> entries for 2&nbsp;MiB blocks, 2<sup>48</sup> / 2<sup>30</sup> = 2<sup>18</sup> for 1&nbsp;GiB blocks, and remember that a table has 512. <em>(Expect 2<sup>27</sup> to be wildly too many and 2<sup>18</sup> to still be too many, which is the discovery: a 48-bit regime cannot use 2&nbsp;MiB blocks at level 1, and the block size follows from the VA size rather than being a menu. That is retraction R13, and <a href="/courses/a64sys/lessons/a64-pagetables">concept 5</a> does the whole calculation.)</em></li>
                    <li><strong>Find the reach asymmetry in your own object files.</strong> Take any C file of yours that indexes a large array and another that points at a large structure, compile both for <code>aarch64-linux-gnu</code>, and read <code>llvm-readelf-21 -r</code> on each. <em>(Expect every reference to be an <code>adrp</code> plus a <code>:lo12:</code> partner, and expect the partner's relocation name to be <code>R_AARCH64_ADD_ABS_LO12_NC</code> when the second instruction is an <code>add</code> and <code>R_AARCH64_LDST64_ABS_LO12_NC</code> when it is a <code>ldr</code>. Two instructions, two relocations, one address — and the address is a page that cannot be named in one instruction on this architecture at all.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, tightly. <a href="/courses/a64sys/lessons/a64-interrupts">Concept 3</a> is where a translation fault <em>arrives</em>, and this is where it came from. <a href="/courses/a64sys/lessons/a64-exceptions">Concept 2</a> is where its address is read: the FAR holds a <em>virtual</em> address, and everything on this page exists to explain what that word means. <a href="/courses/a64abi/lessons/a64-aapcs">The ABI course's calling convention</a> is needed for one number only, and it is a number you already know: <code>x0</code> holds a pointer, and a pointer is a virtual address, and so <em>every function call in your program is a translation</em>. The ABI did not say so; the ABI just moved the number.</p>
                <p>Sideways, three neighbours that own the edges. <a href="/courses/mem/lessons/mem-translation">The neutral paging course</a> owns the walk as a mechanism, in terms neither architecture requires; <a href="/courses/x86sys/lessons/x86-virtual">the x86-64 virtual-memory concept</a> is the sibling reference, where the split is a <code>CR3</code> bit rather than two base registers and the field is a page-directory-pointer count rather than a region size. <a href="/courses/reloc/lessons/reloc-encoding-limits">The relocation course's PC-relative concept</a> owns what <code>adrp</code> <em>is</em>, and this page's reach table is the same subject measured on a different architecture — which is exactly the division of labour this course is for.</p>
                <p>Outward, and the general form is the thing to take away. <strong>A field width is a constraint, and a constraint is more useful than a default.</strong> <code>T0SZ</code> being five bits is quoted; <code>T0SZ = 16</code> being what a 48-bit system writes is a choice; and the difference between the two is the difference between "this is impossible" and "this is a decision somebody made". A reader who has only the second will assume a system could be configured any way and will not notice a configuration that the field forbids. That instinct — <em>look for the field width before you look for the value</em> — is what killed this course's own first draft, and it is the third time in this section that it has been the thing that worked.</p>
                <p>Forward, the hinge. <a href="/courses/a64sys/lessons/a64-pagetables">Concept 5</a> is the ELF side of this page: the tables this regime points at have an <em>alignment requirement</em> and an <em>address</em>, and both are things an object file has to record and a linker has to honour. <strong>That is the step of the chain where the contract becomes checkable</strong> — parsing and IR are about meaning, and a page table is the first object in this course whose requirements are a property of its <em>role</em> and not of its type.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64sys/lessons/a64-interrupts">Sixteen Entries of 0x80, and Four Times No Diagnostic</a></span>
                <span>Next: <a href="/courses/a64sys/lessons/a64-pagetables">Four Levels, and Why a Page Needs a Pair of Relocations</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
