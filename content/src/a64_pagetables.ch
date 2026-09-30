// The AArch64 Machine: Modes, Memory and Faults -- Concept 5: four levels,
// three regimes, and the relocations.
//
// This is the hinge of the course and of the section.  The object-file and
// relocation courses already teach ELF and relocations; the neutral memory
// course already teaches a page walk.  What is left -- and what is new -- is
// that a page table is the first object in this course whose requirements are
// a property of its ROLE rather than of its type, and whose address is a
// machine requirement that no relocation in the ELF format can express.  Two
// retractions live here: R11 (the alignment is the half that is silent) and
// R12 (the pair is a masking problem, not a reach problem), and R13 (a 48-bit
// regime cannot use 2 MiB blocks at level 1).
public namespace underlayer_content {

using std::string

using std::string_view

public func render_a64_pagetables() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Four Levels, and Why a Page Needs a Pair of Relocations — Underlayer")
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
            <h1>Four Levels, and Why a Page Needs a Pair of Relocations</h1>
            <div class="lesson-meta">27 min &middot; <a href="/courses/a64sys">The AArch64 Machine: Modes, Memory and Faults</a></div>

            <div class="unit unit-why">
                <h2>Why this matters</h2>
                <p>Here is the hinge of the course, and of the section it belongs to. The chain this collection is built around is <code>lexing → parsing → IR → codegen → object files → linking → executable</code>, and a page table is the sharpest object in the whole chain, because it is the first one whose <strong>requirements are a property of its role and not of its type.</strong></p>
                <p>To a compiler, a level-0 translation table is an array of 512 <code>unsigned long</code>. There is nothing about the type that says "this must be 4&nbsp;KiB aligned" or "this must land at a physical address". Both requirements are real, both are architectural, and <strong>neither is expressible in the C that declares it</strong> — the alignment has to be an attribute, and the physical address has to be something no relocation can say. So an object file has to carry the first and a linker script has to supply the second, and the ELF-side courses already teach you both mechanisms. What this page adds is the measurement: <strong>what the assembler actually emits, and what it says when you get it wrong.</strong></p>
                <div class="formula">
   THE TWO THINGS A PAGE TABLE NEEDS

   1.  ALIGNMENT.  4 KiB for a 4 KiB-granule table,
       2 MiB for a table of 2 MiB blocks.  This is
       a property of the ROLE.  A compiler cannot
       infer it, so the source has to say so with
       __attribute__((aligned(0x200000))) or a
       .balign, and the assembler records it in
       the SECTION HEADER.

   2.  AN ADDRESS THAT IS PHYSICAL.  The CPU reads
       these tables with the MMU off during boot,
       so their addresses are physical, and the
       kernel image has to be mapped IDENTITY so
       that the linker and the tables agree about
       one address.  NO RELOCATION IN THE ELF
       FORMAT CAN EXPRESS THIS.  It is a linker
       script, and it is quoted.

   The first is MEASURED below.  The second is not,
   and the page says so where you would look for it.
                </div>
            </div>

            <div class="unit unit-model">
                <h2>The model: 512 entries, 8 bytes, 4 KiB</h2>
                <p>The arithmetic, and then the four arrays the compiler emitted when asked for them:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 8 | sed -n '/the TABLES, as the symbol/,/^$/p'
  [MEASURED] the table: 512 entries of 8 bytes, and what the compiler emits
     the TABLES, as the symbol table records them:
     l0       value 0x1000      size 4096      4 KiB-aligned
     l1       value 0x2000      size 4096      4 KiB-aligned
     l2       value 0x3000      size 4096      4 KiB-aligned
     l3       value 0x300000    size 4096      4 KiB-aligned
     l2_big   value 0x200000    size 1048576   2 MiB-aligned

     512 x 8 = 4096 bytes, and the four 4 KiB tables are exactly that
                </pre>
                </div>
                <p>512 descriptors of 8 bytes is 4096 bytes exactly, so the index into one table is <strong>nine bits</strong> — bits 47:39 for level 0, 38:30 for level 1, 29:21 for level 2, 20:12 for level 3, and the low twelve are the offset inside the page. Four levels of nine bits is 36 bits of index plus 12 of offset, and <a href="/courses/a64sys/lessons/a64-virtual">that is the 48-bit split of concept 4</a> arriving as a table shape.</p>
                <p>The descriptor itself, quoted field by field, and the two columns are the reason a page table is hard to read in a hex dump:</p>
                <div class="hex-dump">
                <pre>     64-bit little-endian descriptor, at every level:
  bits    name    meaning
  63    -       for a BLOCK at level 1-2: 2 MiB (0) or 32 MiB (1) -- LPA2
  62..55  -      for a BLOCK at level 2: 32 MiB (0) or 512 MiB (1) -- LPA2
  54..53  TXL    translation table level, 0-3, for a TABLE descriptor
  52..12  output address    the physical address, low bits RES0
  11    NG      nestable, 0 for the EL1/EL0 regime
  10    AF      access flag
  9..8   SH      00 non-, 10 outer, 11 inner shareable
  7      AP      EL1 RW, EL0 none, RO, RW
  5..2   AttrIndx  index into MAIR_EL1
  1      -       TABLE at levels 0-2; unused at level 3
  0      V       valid
                </pre>
                </div>
                <div class="formula">
   WHY A HEX DUMP OF A PAGE TABLE IS HARD

   bits[1]      is the TABLE bit at levels 0, 1 and 2
                and is UNUSED at level 3.

   bits[54:53]  carry the LEVEL for a table descriptor
                and are the low half of a huge-block
                SIZE for a block descriptor.

   The same bits, two meanings, and which meaning
   applies is a property of WHERE YOU ARE IN THE
   WALK and not of the word.

   A hex-dump tool that prints one description of a
   64-bit word is printing one of two, and the
   reader has to know which.  And the word is
   LITTLE-ENDIAN, so the low-numbered bits are the
   high-numbered BYTES -- which means a 64-bit hex
   dump prints the descriptor's bits 63 down to 0
   left to right while the numbering in the table
   above is 0 upwards.
                </div>
                <p>And the arithmetic the compiler emits to build one, which is the last compile-time count on this page and is <strong>explicitly not a timing</strong>:</p>
                <div class="hex-dump">
                <pre>     build_walk, -O2 -- 19 instructions to set up a four-level
     walk with two 2 MiB blocks, three pages and one 1 GiB block:
       ldr x8, [x8, :lo12:root_pa]   ... and so on, ORs and ANDs
     19 instructions to build a translation table.
                </pre>
                </div>
                <p>That is small, and the smallness is the point: <strong>building a translation table is a handful of ORs and ANDs per descriptor, and the expensive part of paging is not building the table, it is walking it</strong> — four dependent memory accesses, or one if the TLB has the entry. None of that is measurable on this host and the file says so rather than inventing a number.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The measurement, part one: one integer in a section header</h2>
                <p>Here is the ELF-side half of the subject in a single table, read by two independent parsers — <code>struct.unpack_from</code> in the artifact and <code>llvm-readelf-21 -S</code> on the command line:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 8 | sed -n '/the alignment a LINKER must honour/,/^$/p'
  [MEASURED] the alignment a LINKER must honour, and where it is recorded
     section    reader 1 (struct.unpack)   reader 2 (llvm-readelf)   agree?
     .text      4                      4                     YES
     .bss       2097152                2097152               YES
     .rela.text 8                      8                     YES
     .symtab    8                      8                     YES

  [RESULT]           .bss comes back with alignment 0x200000 from BOTH readers

     the corpus with and without the 2 MiB table -- the whole
     measurement in two lines, because the ONLY difference between
     the two objects is one declaration and the two functions that
     mention it:
     object            reader 1     reader 2
     sys_O2.o          2097152      2097152
     _no2m.o           4096         4096
                </pre>
                </div>
                <p>Read the last two lines carefully, because that is the concept. <strong>Same types, same code, same language, same compiler, same optimisation level. One declaration of the form <code>__attribute__((aligned(0x200000)))</code> on <em>one</em> array of 512&nbsp;×&nbsp;8 bytes, and the entire uninitialised-data section of the object moves from a 4&nbsp;KiB boundary to a 2&nbsp;MiB one.</strong> The corpus has four 4&nbsp;KiB-aligned tables and one 2&nbsp;MiB-aligned table, and they all live in <code>.bss</code>, and the section inherits the <em>strongest</em> alignment requirement of anything in it — so the three tables that are only 4&nbsp;KiB-aligned have been promoted to 2&nbsp;MiB for free, and a table that is only 8-byte aligned would have cost the whole section nothing.</p>
                <div class="formula">
   R11, and the word that matters is ALIGNMENT

   DRAFT      a page table is an ordinary array of
               64-bit words, so nothing in the object
               file distinguishes it.

   MEASURED   its ALIGNMENT does, and the alignment
               is a property of the SECTION, not of
               the object.  One 2 MiB table among four
               4 KiB ones makes the whole of .bss
               2 MiB-aligned, in BOTH readers.  An
               object with no 2 MiB table in it has
               .bss at 4096.

   Same types, same code, one bit of alignment, and
   a linker that ignores it produces a kernel that
   faults on the first exception it takes.

   The section plan called the ELF side "where the
   genuinely new material lives" and was right, and
   did not say that the new material is an
   ALIGNMENT and not a relocation -- and the
   alignment is the half that is SILENT when it is
   wrong.
                </div>
                <p>So: an object file <em>can</em> express requirement 1, and it does, in 21 bits of a section header. Requirement 2 it cannot express at all — <strong>there is no relocation in the ELF format that says "put this at physical 0x80000000"</strong>, because relocations are all relative to a symbol or a section and physical addresses are not symbols. That is quoted, and it is why every real AArch64 kernel has a linker script, and why the script is a hand-written artefact that has to agree with the assembly and with the architecture at the same time.</p>
                <h2>The measurement, part two: the relocation census</h2>
                <p>Eight relocations in a hand-written <code>.s</code> file that names a page table five different ways, read by both readers:</p>
                <div class="hex-dump">
                <pre>$ python3 a64sys.py --section 8 | sed -n '/the RELOCATION census/,/^$/p'
  [MEASURED-ON-BYTES] the RELOCATION census: two readers over every relocation

     offset      reader 1: number name                        symbol   addend
     0x00201040  275      R_AARCH64_ADR_PREL_PG_HI21         l0        0
     0x00201044  277      R_AARCH64_ADD_ABS_LO12_NC          l0        0
     0x0020104c  274      R_AARCH64_ADR_PREL_LO21            odd       0
     0x00201054  275      R_AARCH64_ADR_PREL_PG_HI21         l1        0
     0x00201058  286      R_AARCH64_LDST64_ABS_LO12_NC       l1        0
     0x00201060  275      R_AARCH64_ADR_PREL_PG_HI21         l2        0
     0x00201064  286      R_AARCH64_LDST64_ABS_LO12_NC       l2        0
     0x0020106c  275      R_AARCH64_ADR_PREL_PG_HI21         l2        0

     the reader-2 view, name and number, and the agreement:
     8 of 8 relocations agree on the TYPE NUMBER

     the census, by name:
     R_AARCH64_ADR_PREL_PG_HI21       4
     R_AARCH64_LDST64_ABS_LO12_NC     2
     R_AARCH64_ADD_ABS_LO12_NC        1
     R_AARCH64_ADR_PREL_LO21          1
                </pre>
                </div>
                <p>Four names, four numbers, and <strong>eight of eight agreeing between two readers</strong>. The numbers are the part that gets two readers, because a relocation <em>name</em> is a convention and a relocation <em>number</em> is what goes in the file — and a name/number table written from memory is right about half the time and produces no error when it is wrong. The four are:</p>
                <ul>
                    <li><strong><code>R_AARCH64_ADR_PREL_PG_HI21</code> = 275.</strong> Page-relative, and the name says exactly what the field holds: bits 32:12 of the target. The <code>_PG_HI</code> is the high twenty bits of an address.</li>
                    <li><strong><code>R_AARCH64_ADD_ABS_LO12_NC</code> = 277</strong> and <strong><code>R_AARCH64_LDST64_ABS_LO12_NC</code> = 286.</strong> The same job — restore the low twelve bits — done by an <code>add</code> and by a load or store respectively. Which one you get depends on the <em>second instruction</em>, not on the address.</li>
                    <li><strong><code>R_AARCH64_ADR_PREL_LO21</code> = 274.</strong> Byte-relative, and the single-relocation case: <code>adr</code> puts all 21 bits of the address in the instruction, so there is nothing left to add. The <code>_NC</code> suffix on the other two means "no check" — the assembler has already range-checked them, so the linker does not.</li>
                </ul>
                <h3>And the reason for the pair, which is not the one the plan gave</h3>
                <div class="hex-dump">
                <pre>  [MEASURED] WHY A PAGE TABLE NEEDS A PAIR, and the reason is NOT reach
     Every reference to a 4 KiB-aligned table in rel.s produced an
     ADRP at one offset and a LO12 at offset+4.  All of them:

       0x00201040  R_AARCH64_ADR_PREL_PG_HI21
       0x00201044  R_AARCH64_ADD_ABS_LO12_NC
       0x0020104c  R_AARCH64_ADR_PREL_LO21
       0x00201054  R_AARCH64_ADR_PREL_PG_HI21
       0x00201058  R_AARCH64_LDST64_ABS_LO12_NC
       0x00201060  R_AARCH64_ADR_PREL_PG_HI21
       0x00201064  R_AARCH64_LDST64_ABS_LO12_NC
       0x0020106c  R_AARCH64_ADR_PREL_PG_HI21

  [RESULT]           3 of the 4 ADRP relocations are immediately followed, four
                     bytes later, by a LO12, and 1 are LONE
                </pre>
                </div>
                <p>Three of four, adjacent, four bytes apart. And the fourth is the most interesting row in the table, because it is the counter-example and it is <strong>deliberate</strong>:</p>
                <div class="formula">
   THE LONE ADRP, and it is a compiler optimisation you can see

   In `ref_load_uimm` the source says:

       adrp x5, l2
       ldr x6, [x5, #0]        <- the offset is a LITERAL ZERO

   The low twelve bits of the address are known at
   ASSEMBLY time to be zero, so the second
   instruction does not need a relocation for them,
   and the assembler emits one.  One relocation.

   So the rule is not "every page reference is a
   pair".  It is:

       every page reference whose low TWELVE BITS
       are not statically zero is a pair

   and the exception is visible in an object file.
                </div>
                <p>Now the reason, and it is <strong>not</strong> the one the section plan gave:</p>
                <div class="formula">
   R12, and it is a REASON, which is the hard kind

   DRAFT      a page needs a PAIR of relocations per
               page because the `adrp` reach is +-4 GiB.

   MEASURED   the reach is 4 GiB and is IRRELEVANT.
               The pair exists because ADRP masks off
               the low twelve bits of the target.

   ADRP computes (page(target) - page(pc)) >> 12
   and puts THAT in a 21-bit field.  The low twelve
   bits of the target are not in the instruction at
   all -- they were MASKED OFF.  Something has to add
   them back, and the only instructions that can are
   the ones with a 12-bit immediate: `add`, or a
   load or store with an unscaled 12-bit offset.

   The pair is not a RANGE problem.  It is a
   MASKING problem, and no amount of reach would
   fix it.

   And the evidence that the reach is irrelevant is
   on the same page: the target is FOUR BYTES AWAY.
   A 4 GiB reach is not a constraint anybody hits.

   A reader who believed the wrong reason would
   conclude that a page table further than 4 GiB from
   the code needs a different instruction -- which
   is true, and for a reason that has nothing to do
   with the distance.
                </div>
                <p>And the one reference in the corpus that is not a pair at all, which is the cleanest statement of the rule:</p>
                <div class="hex-dump">
                <pre>     and the ONE reference in rel.s that is not a pair at all:
     0x0020104c  R_AARCH64_ADR_PREL_LO21 against odd
                </pre>
                </div>
                <p><code>adr x0, odd</code> reaches a symbol twelve bytes away and emits a <strong>single</strong> relocation, because <code>ADR</code> puts all 21 bits of the address in the instruction and there is nothing left to add. <a href="/courses/a64sys/lessons/a64-virtual">Concept 4 measured the boundary</a>: <code>ADR</code> reaches 1&nbsp;MiB and the assembler refuses <code>0x100000</code>. So the rule that falls out of the measurement is not about pages at all —</p>
                <div class="formula">
   THE RULE, which is not about pages

   A reference that FITS in ADR is one relocation.
   A reference that does not is two.

   Page tables are the case that does not fit,
   always, and not because they are far away: a page
   is 4 KiB and ADR's reach is 1 MiB, so most page
   tables are within reach -- and even when they are,
   the low twelve bits still have to be restored,
   because ADR's 21 bits are a BYTE offset and a page
   address needs its low twelve separately.

   The exception is `adr` on a symbol that is both
   within 1 MiB AND has its low twelve bits equal to
   zero -- and the assembler will not tell you which
   case you are in until you ask it for the bytes.
                </div>
                <p>One more thing the linker does with the pair, which this host cannot show you: <strong>it is allowed to rewrite <code>adrp</code> + <code>add</code> as <code>adr</code> + <code>nop</code></strong> when the target turns out to be within 1&nbsp;MiB, and this is a real and frequently-taken relaxation. It is quoted, because there is no AArch64 linker on this host. What <em>is</em> measured is the input to the decision: the two relocations, their four-byte spacing, and the symbol they share.</p>

            </div>

            <div class="unit unit-example">
                <h2>Worked: the block sizes, and the arithmetic that says you cannot use them</h2>
                <p>The sizes are quoted; the constraint is arithmetic. Here is the whole table and the whole constraint:</p>
                <div class="hex-dump">
                <pre>     level   page    block (no LPA2)  block (LPA2)   one table covers
     0          -              -              -           2^48
     1          -             2 MiB           2 MiB         2^36
     2          -              -             32 MiB         2^24
     3        4 KiB            -            512 MiB        2^12

     and the arithmetic of a full 48-bit regime:
       one L0 table covers 2^48 bytes = 256 TiB; a 48-bit
         space needs 2^0 of them
       one L1 table covers 2^36 bytes = 64 GiB; a 48-bit
         space needs 2^12 of them
       one L2 table covers 2^24 bytes = 16 MiB; a 48-bit
         space needs 2^24 of them
       one L3 table covers 2^12 bytes = 4 KiB; a 48-bit
         space needs 2^36 of them
       a 2 MiB block at L1 covers 2^21 bytes, so 48 bits needs
         2^27 = 134217728
       of them, which is 2 TiB of descriptors at 8 bytes each.
       a 1 GiB block at L2 needs 2^18 = 262144 of them.
                </pre>
                </div>
                <p>There is a number in that block and it is the retraction. <strong>2<sup>27</sup> entries are needed for 2&nbsp;MiB blocks at level 1, and a table has 512.</strong> 512 is 2<sup>9</sup>. So a 48-bit regime <em>cannot</em> use 2&nbsp;MiB blocks at level 1, by a factor of 2<sup>18</sup>, and no amount of configuration will make it work.</p>
                <div class="formula">
   R13, and it is a MENU that was read as a menu

   DRAFT      the four descriptor levels and the
               block/table/page sizes -- which reads as
               a MENU, and the natural thing to do
               with a menu is pick from it.

   MEASURED   level 1 CAN hold a 2 MiB block, and a
               48-bit regime cannot USE it, because
               2^27 entries are needed and a table
               has 512.  The level at which you can use
               a block is FIXED by the arithmetic of the
               space size.

   The three real AArch64 configurations are 39/39,
   48/48 and 48/52, and the block size FOLLOWS from
   the VA size, not the other way round.

   A reader who took the size table as a menu would
   build a level-1 2 MiB block table, find that 512
   entries cover 1 GiB, and conclude that 48-bit
   virtual memory is impossible -- which it is not,
   and the impossibility is in arithmetic they did
   not do.
                </div>
                <p>Which is the real teaching point of the whole concept, and it generalises well past page tables: <strong>the sizes are not a menu, they are consequences</strong>. Change the address space and the block size changes to compensate, because the number of entries a walk can reach is <code>2<sup>index bits</sup></code> and the index bits are fixed at 9 per level. Four levels of nine bits is 36, plus 12 of offset, is 48. A 39-bit system has three levels of nine bits and 12 of offset, is 39 — and 39 plus 12 of <em>block</em> rather than offset is how a 2&nbsp;MiB block at level 1 covers 2<sup>21</sup> bytes in a walk that only has 27 index bits to spend.</p>
                <h3>What this page cannot show</h3>
                <p>It cannot show a page walk, a translation, a TLB hit or a miss, or the four dependent memory accesses a walk costs when the TLB does not have the entry. <strong>No AArch64 machine, no emulator, no sysroot, and no linker.</strong> The descriptor format, the field positions and the granule encodings are quoted with document and section. The table sizes, the alignment the section header carries, the relocation names and numbers, and their pairing are measured, and the alignment and the relocation numbers are read by two independent parsers that agree. The linker is absent, so the <code>adrp</code>+<code>add</code> → <code>adr</code>+<code>nop</code> relaxation is quoted and the pair it operates on is measured. <strong>That is the closest this host can get to the hinge between this course and the ELF courses</strong>, and it is a closer hinge than most courses on this subject manage.</p>
            </div>

            <div class="unit unit-apply">
                <h2>Apply it</h2>
                <ol>
                    <li><strong>Measure the alignment the way the artifact does, with two readers.</strong> Write a C file with one <code>static unsigned long t[512]</code> and nothing else, compile it, and read the <code>.bss</code> alignment. Then add a second array with <code>__attribute__((aligned(0x200000)))</code> and read it again. <em>(Expect 8, then 2097152. The second number is not about the second array — it is about the <em>section</em>, and every other array in <code>.bss</code> has been promoted to it for free. That is the shape of the R11 measurement and it takes two minutes to reproduce.)</em></li>
                    <li><strong>Count the relocations, then delete one and count again.</strong> Compile a function that returns the address of a 4&nbsp;KiB-aligned table and read <code>llvm-readelf-21 -r</code>. <em>(Expect two, four bytes apart, named <code>R_AARCH64_ADR_PREL_PG_HI21</code> and <code>R_AARCH64_ADD_ABS_LO12_NC</code>. Now change the second instruction to <code>ldr x1, [x0, :lo12:table]</code> and recompile: the second relocation becomes <code>R_AARCH64_LDST64_ABS_LO12_NC</code> and the number changes from 277 to 286. The <em>name</em> depends on the instruction, not on the address — and a reader who has memorised one of the two will not know which to expect.)</em></li>
                    <li><strong>Find the lone <code>adrp</code> on purpose.</strong> Write <code>adrp x0, tbl</code> followed by <code>ldr x1, [x0, #0]</code> and assemble it. <em>(Expect ONE relocation, not two, and then work out why before reading the answer: the offset is a literal zero, so the low twelve bits are known at assembly time and there is nothing to fix up. Now change the <code>#0</code> to <code>#8</code> and expect two. This is the exception to the pair rule, it is a real compiler optimisation, and you can see it in a file on your disk.)</em></li>
                    <li><strong>Bisect the <code>adr</code> reach and then try to use <code>adr</code> on a page table.</strong> Assemble <code>adr x0, sym</code> at increasing distances and find the refusal at 0x100000. Then put a 4&nbsp;KiB table 512&nbsp;KiB away — comfortably inside the reach — and write <code>adr x0, table</code>. <em>(Expect it to assemble, and expect the resulting address to be correct, and then check the low twelve bits: <code>adr</code> encodes a 21-bit <em>byte</em> offset from the current PC, so if the table is page-aligned the low twelve bits of the difference are zero and it works; move the table to be 8-byte aligned instead and the <code>adr</code> now points eight bytes below the table. The pair is not about reach — it is that <code>adrp</code> throws the low twelve bits away, which is the retraction, and you can now see both halves of it.)</em></li>
                    <li><strong>Do the entry arithmetic and watch a configuration die.</strong> For a 48-bit space, compute the entries needed for a 2&nbsp;MiB block at each level: 2<sup>48</sup>/2<sup>21</sup>, 2<sup>48</sup>/2<sup>30</sup>, 2<sup>48</sup>/2<sup>39</sup>. <em>(Expect 2<sup>27</sup>, 2<sup>18</sup> and 2<sup>9</sup> — and 2<sup>9</sup> is 512, which is exactly one table. So a 1&nbsp;GiB block at level 2 is the only one of the three that fits, and the conclusion follows from arithmetic rather than from a manual. Then ask: at what address-space size does a 2&nbsp;MiB block at level 1 work? 512 &times; 2&nbsp;MiB = 1&nbsp;GiB, so 30 bits — and <a href="/courses/a64sys/lessons/a64-virtual">concept 4</a> measured that a 30-bit space does not fit in a five-bit <code>T0SZ</code> at all. The two concepts close on each other, and neither of them could have been written first.)</em></li>
                </ol>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Backwards, one page. <a href="/courses/a64sys/lessons/a64-virtual">Concept 4</a> is the regime this page's tables serve, and the two close on each other: the block size follows from the address-space size, and the address-space size is limited by a five-bit field. Forward within the course, <a href="/courses/a64sys/lessons/a64-evidence">concept 6</a> is the one that says which of the claims on this page are measured and which are quoted — and this page has more of the first than any other in the course, because a page table is the one subject on this machine that a <em>toolchain</em> can show you.</p>
                <p>Sideways, and this is where the course does its real work. <a href="/courses/obj/lessons/obj-relocations">The object-file course owns the relocation record</a> — the 24 bytes of <code>r_offset</code>, <code>r_info</code> and <code>r_addend</code> and why AArch64's is a <em>RELA</em> with an explicit addend while x86-64's is usually implicit. <a href="/courses/reloc/lessons/reloc-arch-contrast">The relocation course owns the taxonomy</a> — absolute, PC-relative, and what "no check" means in a suffix. <a href="/courses/link/lessons/link-script-language">The linker-script concept</a> is <strong>the other half of this page</strong>, because requirement 2 above — an address that is physical — is a linker script and nothing else, and this page can only tell you that the object file does not contain it. <a href="/courses/mem/lessons/mem-translation">The neutral paging course</a> owns the walk; <a href="/courses/x86sys/lessons/x86-paging">the x86-64 paging concept</a> is the sibling reference, where the same five extractions happen against a four-level table with a 9-bit PDE and a 20-bit PTE rather than four uniform 9-bit indices.</p>
                <p>Outward, and the general form is the most transferable thing in the course. <strong>A data structure whose requirements are a property of its role is a data structure an object format has to be told about, and the telling is always a small integer in a header.</strong> The 21 bits of <code>sh_addralign</code> are the entire channel. A backend author has to emit them, a linker has to honour them, and neither has any way to know whether the object <em>should</em> have had them — which is the same shape as the vector table's missing diagnostic in <a href="/courses/a64sys/lessons/a64-interrupts">concept 3</a>, and the same shape as the HINT guard bug in <a href="/courses/a64asm/lessons/a64-verify">the encoding course's cross-check</a>. Three instances in two courses of the same pattern: <em>correct in isolation, undefined in combination, and silent when wrong.</em> Learning to look for that pattern is worth more than any individual number on this page.</p>
                <p>And the honest end. This page is the hinge of the chain <code>codegen → object files → linking</code> and it is the first place in this collection where a <em>kernel</em> becomes a compilation problem. A page table is not code, it is not data in the C sense, and it is not addressable by a relocation — and a toolchain that cannot express "2&nbsp;MiB aligned" and a linker script that cannot express "at physical 0x80000000" will produce a kernel that assembles, links, boots, and then takes its first exception into a table that is not where the MMU is looking. <strong>Nothing in that chain reports an error.</strong> That is the reason this concept exists.</p>
            </div>

            <div class="lesson-footer">
                <span>Previous: <a href="/courses/a64sys/lessons/a64-virtual">T0SZ = 64 - 48, and the Field With a Floor</a></span>
                <span>Next: <a href="/courses/a64sys/lessons/a64-evidence">What Is Measured Here, What Is Quoted, and What You Cannot Conclude</a></span>
            </div>
        </div>

    render_lesson_js(&mut page)
    }

    return page.toString()
}
}
