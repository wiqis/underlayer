// Object Files — Module 3: The Fixup
// Concept: the relocation record, field by field, across three formats. The
// four questions every format must answer, and the three incompatible ways
// of packing the answers into a fixed number of bytes.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_relocations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Fixup Record — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Fixup Record</h1>
            <div class="lesson-meta">24 min &middot; Module 3: The Fixup &middot; Advanced</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p><a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> established that a relocatable file is a hole plus a record, and that the record answers four questions. It showed you one record. <strong>It did not show you the record, because the four questions have three completely different physical answers and picking the wrong one is how a reader silently produces plausible nonsense.</strong></p>
                <div class="hex-dump">
                    <pre>  THE FOUR QUESTIONS, and where each format keeps the answer

  ELF64    one 24-byte record, three fields
           r_offset  u64   WHERE
           r_info    u64   WHAT + WHOM, packed together
           r_addend  i64   HOW MUCH      (signed!)

  COFF x64  one 10-byte record, three fields
           VirtualAddress     u32   WHERE
           SymbolTableIndex   u32   WHOM
           Type               u16   WHAT

  Mach-O    one 8-byte record, two fields
           r_address  i32    WHERE      (signed)
           r_info     u32    six things, bit-packed
                     WHOM(24) PCREL(1) LENGTH(2)
                     EXTERN(1) TYPE(4)  = 32 bits exactly
</pre>
                </div>
                <p>Three designs, one job. And the differences are not cosmetic. <strong>A reader that assumes the ELF layout will read a COFF file's symbol index as a relocation type and get a number that is a perfectly valid relocation &mdash; just the wrong one.</strong> That is the failure this concept is about, and it is why the record has to be read from the specification rather than extrapolated from the format you know best.</p>
                <p>The frame throughout is the same one the course has used since <a href="/courses/obj/lessons/obj-the-hole">the second concept</a>: <strong>every field exists because the linker needs it for something specific.</strong> There are no alignment fields here, no reserved fields, no versioning. Every byte is load-bearing, and the interesting part is that the three formats load different things into it.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Before the layouts, the abstraction, because the abstraction is what makes the three layouts comparable. Strip away the encoding and a relocation record is four facts:</p>
                <div class="formula">
  WHERE    which bytes in which section get patched
  WHAT     the arithmetic: what goes in them
  WHOM     which symbol supplies a term
  HOW MUCH the constant part of the value

  ELF, COFF and Mach-O all encode exactly these four and
  nothing else.  The interesting engineering question is
  not WHAT to store -- it is where to put each fact so the
  format does not have to be looked up.
</div>
                <p>Now the design pressure, which is what actually explains the differences. <strong>A record must be findable from the section it patches, and the section must be findable from the record.</strong> Every format solves that linkage differently, and the solution determines the layout:</p>
                <ul>
                    <li><strong>ELF puts relocations in their own section.</strong> An <code>SHT_RELA</code> section is a sibling of the data sections, and the association lives in the relocation section's own header: <code>sh_link</code> is the symbol table, <code>sh_info</code> is the section being patched. <strong>So the offset field only has to be a section-relative offset</strong> &mdash; it does not repeat the section, because the header already said which section.</li>
                    <li><strong>COFF puts relocations immediately after the section's data</strong>, and points at them with <code>PointerToRelocations</code> in the section header. <strong>So the association is positional</strong>: everything between that pointer and the count is this section's relocations. The offset field only has to be an offset, for the same reason ELF's does.</li>
                    <li><strong>Mach-O puts the relocation pointer and count inside the section header</strong> as <code>reloff</code> and <code>nreloc</code>, exactly as COFF does. <strong>But its offset field is a section <em>address</em>, not a section offset</strong> &mdash; because a Mach-O object gives its sections provisional addresses. This is the one case where the same small field means a genuinely different thing, and it is the sharpest cross-format trap in the course.</li>
                </ul>
                <div class="callout callout-warn">
                    <strong>Mark the simplification here, because it is load-bearing.</strong> &ldquo;Four questions&rdquo; describes what a record must express, not what any format stores. <strong>No format has a field called <code>whom</code></strong> &mdash; ELF buries it in the high half of <code>r_info</code>, COFF gives it a field of its own, and Mach-O squeezes it into 24 bits alongside five other facts. The model is about the information; the layouts are three answers to the question of how to lay it out.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The first record of <code>.rela.text</code> in <code>demo_elf.o</code>, which is the call to <code>global_counter</code> at text offset 4. All 24 bytes, from the file at <code>0x240</code>:</p>
                <div class="hex-dump">
                    <pre>  00000240: 0400 0000 0000 0000  0200 0000 0500 0000   ................
  00000250: fcff ffff ffff ffff                          ................

  +0   r_offset    u64   0x0000000000000004    text offset 4
  +8   r_info      u64   0x0000000500000002
                     low  32 bits  = 0x2 = R_X86_64_PC32   WHAT
                     high 32 bits  = 0x5 = symbol index 5    WHOM
  +16  r_addend    i64   0xfffffffffffffffc   = -4          HOW MUCH
</pre>
                </div>
                <p>Three things in those 24 bytes are worth pulling apart, because two of them are the opposite of what the field names suggest.</p>

                <h3>r_info packs two fields, and the halves are not symmetric</h3>
                <p><code>r_info</code> is one 64-bit number holding a symbol index and a type. <strong>The type is in the LOW half and the symbol in the HIGH half</strong> &mdash; so the packing reads <code>r_info = (sym &lt;&lt; 32) | type</code>, and the mnemonic order is the reverse of the arithmetic. Confirm it against <code>readelf</code>, which prints the whole 64-bit value in one column: <code>0000000500000002</code>. The <code>05</code> at the left of that number is the symbol; the <code>02</code> at the right is the type.</p>
                <p>The 32-bit form uses a different split, which is a real trap: <code>Elf32_Rel</code> packs as <code>(sym &lt;&lt; 8) | type</code> &mdash; the same order, but 8 bits of type instead of 32, in a 32-bit word. Here is a real record from <code>demo_i386_nopic.o</code>'s <code>.rel.text</code>:</p>
                <div class="hex-dump">
                    <pre>  08 00 00 00  01 03 00 00

  +0  r_offset  u32  = 0x00000008
  +4  r_info    u32  = 0x00000301
                       low  BYTE  = 0x01 = R_386_32   WHAT
                       high WORD = 0x0003 = symbol 3   WHOM
</pre>
                </div>
                <p><strong>And note what is absent: there is no addend field.</strong> That is the <code>REL</code> versus <code>RELA</code> distinction, and it is the subject of <a href="/courses/obj/lessons/obj-addends">the next concept</a> because the addend's location changes what the section bytes must contain. The record here is 8 bytes, not 12 or 24.</p>

                <h3>r_addend is signed, and -4 is not a mistake</h3>
                <p><code>r_addend</code> is an <em>i</em>64, and here it is <code>0xfffffffffffffffc</code>. Read as unsigned that is 18,446,744,073,709,551,804; read as signed it is <strong>-4</strong>. A reader that treats it as unsigned gets a plausible enormous number and a link error several steps later.</p>
                <p>Why -4: the call at text offset 4 is a five-byte <code>e8 rel32</code> whose displacement field is at offset 5, and <strong>x86-64 measures that displacement from the end of the instruction, not from the displacement field itself.</strong> The linker computes <code>S - P</code> where <code>P</code> is the field's address; the field is four bytes before the instruction's end, so the stored constant must be -4 to make the arithmetic come out right. The four bytes in <code>.text</code> at offset 4 are all zero &mdash; <strong>the whole correction lives in the record.</strong> The next concept takes that apart properly.</p>

                <h3>The COFF record has three separate fields and no addend at all</h3>
                <p>All four <code>.text</code> relocations of <code>demo_coff.o</code>, at <code>0x16a</code>, 10 bytes each:</p>
                <div class="hex-dump">
                    <pre>  0000016a: 0400 0000 1100 0000 0400    ....... ....
  00000174: 0a00 0000 1200 0000 0400    ....... ....
  0000017e: 2100 0000 1400 0000 0400    !..........
  00000188: 3300 0000 1600 0000 0400    3..........
</pre>
                </div>
                <div class="formula">
  +0  VirtualAddress     u32   0x04, 0x0a, 0x21, 0x33   WHERE
  +4  SymbolTableIndex   u32   0x11, 0x12, 0x14, 0x16   WHOM (17,18,20,22)
  +8  Type               u16   0x0004 four times         WHAT
                          IMAGE_REL_AMD64_REL32
</div>
                <p><strong>Ten bytes, and all three fields are unpacked.</strong> No bit twiddling, no shared word, nothing to mask. The cost is size: ELF spends 24 bytes on the same information, and Mach-O spends 8. The benefit is that a COFF reader never has to know how a type number and a symbol index share a word, which is the mistake a reader makes when it assumes ELF's packing.</p>
                <p>And <strong>all four are <code>REL32</code> &mdash; including the call at offset 0x21.</strong> There is no <code>PLT32</code> on this target. Compare <a href="/courses/obj/lessons/obj-reloc-tables">the relocation table</a> concept's finding that ELF distinguishes <code>R_X86_64_PC32</code> from <code>R_X86_64_PLT32</code> purely by a hint. <strong>COFF-x86-64 makes a call and a data reference the same relocation</strong>, so on this target a linker cannot tell them apart from the record and must decide from context. That is not a simplification; it is the whole design, and it is why a linker implements a vocabulary per <em>target</em> rather than per format.</p>

                <h3>The Mach-O record packs six facts into one 32-bit word</h3>
                <p>All four <code>__text</code> relocations of <code>demo_macho.o</code> at <code>0x3b8</code>, 8 bytes each, in the order they appear in the file:</p>
                <div class="hex-dump">
                    <pre>  000003b8: 3700 0000 0300 001d    7.......   addr 0x37
  000003c0: 2600 0000 0700 002d    &amp;......-   addr 0x26
  000003c8: 0e00 0000 0500 001d    .......   addr 0x0e
  000003d0: 0800 0000 0200 001d    .......   addr 0x08
</pre>
                </div>
                <p>Take the first: <code>r_address = 0x37</code>, <code>r_info = 0x1d000003</code>. Decode the word as five bitfields packed into 32 bits, low field first:</p>
                <div class="formula">
  bit  31..28  r_type       = 1   X86_64_RELOC_SIGNED
  bit  27      r_extern     = 1   the target is a SYMBOL, not a section
  bit  26..25  r_length     = 2   the field is 1 shifted left 2 = 4 bytes
  bit  24      r_pcrel      = 1   the value is RELATIVE to the field
  bit  23..0   r_symbolnum  = 3   symbol 3 = _message
</div>
                <p>Verify the arithmetic: <code>1&lt;&lt;28 | 1&lt;&lt;27 | 2&lt;&lt;25 | 1&lt;&lt;24 | 3</code> is <code>0x10000000 + 0x08000000 + 0x04000000 + 0x01000000 + 3</code> = <code>0x1d000003</code>. Exactly the bytes in the file. And <code>llvm-readobj-21</code> prints the same record as <code>0x37 1 2 1 X86_64_RELOC_SIGNED 0 _message</code> &mdash; which is those five fields in a different order, plus the field width, for free.</p>
                <p>Three consequences fall out of that layout, and all three are load-bearing for an implementation.</p>
                <ul>
                    <li><strong>The field width is in the record.</strong> <code>r_length = 2</code> means 4 bytes, and the encoding is logarithmic: <code>1 &lt;&lt; r_length</code>. ELF and COFF instead make the width a property of the <em>type</em>, so the width is implied by which relocation you have. <strong>Mach-O is the only one of the three that can express two different widths for the same type at the same offset</strong> &mdash; which is precisely what you need in order to relocate a variable-width field.</li>
                    <li><strong><code>r_extern</code> is a fourth meaning of a name.</strong> When it is 0, <code>r_symbolnum</code> is not a symbol index at all &mdash; it is a <em>section</em> number. The single <code>.data</code> relocation shows this: <code>addr = 0x08</code>, <code>word = 0x06000003</code>, giving <code>r_extern = 0</code> and <code>r_symbolnum = 3</code> &mdash; and <code>llvm-readobj-21</code> reports its target as the <em>section</em> <code>__cstring</code>, not a symbol. <strong>One field, two namespaces, selected by one bit.</strong> Compare ELF, which solves the same problem with a reserved <code>st_shndx</code> value and a symbol type, and COFF, which has <code>IMAGE_SYM_STATIC</code> versus <code>IMAGE_SYM_EXTERNAL</code>.</li>
                    <li><strong>The offsets are addresses, and they run backwards.</strong> The four <code>__text</code> offsets in file order are <code>0x37, 0x26, 0x0e, 0x08</code> &mdash; <strong>decreasing</strong>. ELF and COFF both store relocations in increasing offset order. This is not an artifact; it is a real Mach-O invariant, because linkers have historically walked relocation entries backwards while laying a section out. <strong>A tool that assumes ascending order across all three formats produces correct-looking output on two of them and silently wrong output on the third.</strong></li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The same four holes in <code>.text</code>, as the three formats record them. The columns are the four questions, and the rows are the three answers:</p>
                <div class="hex-dump">
                    <pre>  text off   ELF            COFF              Mach-O
  --------   ------------   ---------------   ---------------
  0x04       PC32           REL32             SIGNED
             sym 5          sym 17            sym 2  _global_counter
             addend -4      (none)            len 2, pcrel
  0x0a       PC32           REL32             SIGNED
             sym 6          sym 18            sym 5  _uninitialised
             addend -4      (none)            len 2, pcrel
  0x21       PLT32          REL32             BRANCH
             sym 8          sym 20            sym 7  _external_fn
             addend -4      (none)            len 2, pcrel
  0x33       PC32           REL32             SIGNED
             sym 10         sym 22            sym 3  _message
             addend -4      (none)            len 2, pcrel
</pre>
                </div>
                <p>Now read the table as a linker author and the design differences become requirements rather than trivia. Four things had to be decided, and the three formats decided them differently:</p>
                <div class="formula">
  DECISION              ELF              COFF             Mach-O
  -------------------   --------------   --------------   --------------
  where to find the      a separate       inline after    a pointer in
  relocations            SHT_RELA         the section     the section
                         section          header          header
  how to link a reloc    sh_link +        positional,     positional,
  to its section         sh_info          nothing to      nothing to
                                           record          record
  how to pack sym+type   one 64-bit word  two fields      one 32-bit word
                         (sym high)       (32 + 16)       with 5 bitfields
  where the addend is    a field, or in   always in the   in the section
                         the section      section bytes   bytes
</div>
                <p><strong>The fourth row is the one to carry away.</strong> ELF lets the producer choose &mdash; <code>RELA</code> puts the addend in the record, <code>REL</code> puts it in the section bytes &mdash; which is a genuine architectural freedom with a real cost, since a linker must support both. <strong>COFF and Mach-O have no choice to make: the addend is always in the bytes.</strong> And that is exactly why, in <code>demo_coff.o</code>, the four bytes at <code>.text</code> offset 4 are <code>00 00 00 00</code> rather than <code>fc ff ff ff</code>: the bias that ELF stores as an addend of -4, COFF applies from the definition of <code>REL32</code> itself. <a href="/courses/obj/lessons/obj-addends">The next concept</a> proves that by linking the object and watching where the -4 appear.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ cd courses/obj/assets/samples
$ xxd -s 0x240 -l 48 demo_elf.o          # the four .rela.text records
$ xxd -s 0x16a -l 40 demo_coff.o         # the four COFF records
$ xxd -s 0x3b8 -l 32 demo_macho.o        # the four Mach-O records</code></pre>
                <ul>
                    <li><strong>Decode all twelve records by hand and check each against <code>readelf</code>, <code>llvm-readobj-21</code> and <code>llvm-objdump-21</code>.</strong> Start with the Mach-O <code>word</code> values, because they are the only ones with a real bit layout: confirm that <code>0x1d000003</code> unpacks to the five fields listed above. <strong>Then deliberately unpack one bit wrong</strong> &mdash; read <code>r_length</code> as 3 bits instead of 2 &mdash; and see what number you get and why it is not obviously wrong.</li>
                    <li><strong>Prove the ELF packing direction.</strong> Find the record whose type is not 1 or 2 and confirm which half of <code>r_info</code> changes. The <code>PLT32</code> record at offset <code>0x21</code> has <code>r_info = 0x0000000800000004</code>: the symbol is 8 and the type is 4. <strong>Write the formula <code>r_info = (sym &lt;&lt; 32) | type</code> from the evidence, then check it against a 32-bit record from <code>demo_i386_nopic.o</code> where the split is 8 and 24 instead of 32 and 32.</strong></li>
                    <li><strong>Measure the record sizes and account for every byte.</strong> ELF64-RELA is 24, ELF32-REL is 8, COFF-x64 is 10, Mach-O is 8. <strong>For each, write down which of the four questions each field answers and show that no byte is unaccounted for.</strong> Then find the smallest possible encoding of the same four facts &mdash; you will find that 8 bytes is achievable and that two of the formats achieve it, which raises the question of why the third needs 24.</li>
                    <li><strong>Check the Mach-O order claim on a file with more relocations than <code>demo_macho.o</code> has.</strong> Build one that needs eight or ten, then confirm they are still stored in decreasing offset order while the same relocations in the ELF build of the same source are in increasing order. <strong>Also confirm the offsets really are addresses, not section offsets</strong>, by finding a Mach-O object where a data section's relocation offset is larger than the section's size &mdash; it can only be an address.</li>
                    <li><strong>Verify the COFF <code>REL32</code>-for-everything claim against the i386 target.</strong> Build the same source for <code>i386-pc-windows-msvc</code> and look at the types. <strong>On i386 the call and the data references get different relocations</strong>, so &ldquo;COFF has no PLT variant&rdquo; is a statement about x86-64 and not about COFF &mdash; which is a sharper version of the lesson, and worth finding out for yourself.</li>
                    <li><strong>Run the harness.</strong> <code>python3 crosscheck.py</code> decodes these files with a reader written from the specifications and compares the result against <code>readelf</code> and <code>llvm-readobj-21</code> field by field. <strong>It currently reports 95 checks passing.</strong> Break one deliberately &mdash; flip a section's <code>sh_info</code> in a copy of <code>demo_elf.o</code> &mdash; and find which tier catches it. The answer is Tier 3, the file disagreeing with itself, and that is the tier that catches the most.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a Mach-O relocation record is 8 bytes, and 4 of them are a single 32-bit word holding six distinct facts. ELF's equivalent record is 24 bytes holding three fields. What does the Mach-O layout buy, what does it cost, and which of the four questions does ELF answer more clearly than Mach-O does?</p>
                <div class="quiz" id="quiz-obj-relocations-1">
                    <button class="quiz-option" data-correct="true" data-explain="The layout buys two things and costs one, and the trade is genuinely favourable, which is why the design stuck. What it buys is compactness and, more importantly, expressiveness: r_length carries the patch width in the record rather than implying it from the type, so one type can relocate a 1-, 2-, 4- or 8-byte field. That is not a hypothetical -- it is exactly what a format needs in order to relocate a variable-width field such as a LEB128, which is a fixed-width field with a variable-width value and which a type-implies-width layout simply cannot express. r_extern buys a second thing: one field serves both the symbol namespace and the section namespace, selected by a bit, so a relocation against a section costs no extra bytes. What it costs is that the reader must know the bit layout to extract anything, and the arithmetic is unforgiving: 1 shifted left 28, or 27, or 2 shifted left 25, or 1 shifted left 24, or 3, has to come out to exactly 0x1d000003, and an off-by-one in any shift produces a number that is still a plausible relocation. ELF answers 'whom' more clearly than Mach-O does, and this is the part worth noticing, because it is the one that bites. In ELF, r_info's high half is unambiguously the symbol index, so 'which symbol' is one shift and a mask. In Mach-O, 'which symbol' is the low 24 bits of a word whose other 8 bits decide whether that 24-bit value is a symbol at all or a section number. A reader that extracts it without checking r_extern will confidently report a symbol index for a relocation that names a section -- and for demo_macho.o's single .data record, symbol 3, the answer would be _message, when the relocation actually targets the whole __cstring section." onclick="checkQuiz('obj-relocations-1', this)">It buys compactness and one real capability Mach-O has and ELF does not: the patch width is carried in the record, so one relocation type can patch a 1-, 2-, 4- or 8-byte field, and <code>r_extern</code> lets one field name either a symbol or a section. It costs readability, because every fact has to be extracted with a shift and a mask. ELF answers &quot;whom&quot; more clearly &mdash; the high half of <code>r_info</code> is unambiguously the symbol index &mdash; and that is the field most likely to be misread in Mach-O, because the same 24 bits mean a symbol or a section depending on one neighbouring bit</button>
                    <button class="quiz-option" data-correct="false" data-explain="The reasoning is close but has the priorities exactly inverted, and it misidentifies the answer to the final question. The width-in-the-record point is right, but it is the smaller of the two gains, not the headline. The headline is what r_extern does: it collapses two namespaces into one field. In ELF a relocation against a section is expressed by pointing at a symbol of type STT_SECTION, which costs a whole 24-byte symbol table entry to say 'the section, not a name in it'. In Mach-O the same information costs one bit, set to zero, and the 24 bits that follow become a section index. That is the difference between paying a byte-per-section and paying a bit-per-relocation, and it is why a Mach-O object from clang has no section symbols at all where the ELF one has two. The other error is calling r_info the ambiguous field. It is the least ambiguous part of the record: two 32-bit halves, each doing exactly one job, and a reader that wants the symbol index takes the high half and stops. The genuinely ambiguous field in the Mach-O record is the packed word, where five facts of different widths share 32 bits and the reader must know the layout to extract any of them. So the correct answer inverts this one: Mach-O is the more compact and the more expressive design, ELF is the more legible one, and the field to watch in each is the opposite of what this answer says." onclick="checkQuiz('obj-relocations-1', this)">It buys readability, because a 32-bit word with documented bit offsets is easier to read than three separate fields, and it costs expressiveness, because cramming six facts into 32 bits means the type can no longer carry information of its own. ELF answers &quot;what&quot; more clearly than Mach-O does, since <code>r_info</code>'s low half is the type and the high half is the symbol</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the reader for a tool that must open ELF, COFF and Mach-O objects. You have implemented ELF and it works on every file you have tried. Someone hands you a <code>demo_coff.o</code> and your tool reports that the first relocation in <code>.text</code> is of type <code>0x11</code> &mdash; seventeen &mdash; against symbol <code>4</code>, at offset <code>4</code>. Nothing crashes. The output looks like a plausible disassembly with three broken references. What exactly did your ELF assumption do, and what is the general rule that would have caught it before the file was opened?</p>
                <div class="quiz" id="quiz-obj-relocations-2">
                    <button class="quiz-option" data-correct="true" data-explain="Your reader unpacked r_info as (sym shifted left 32) or type, and applied it to COFF's bytes 04 00 00 00 11 00 00 00 04 00. Reading the first eight as one 64-bit little-endian value gives 0x0000001100000004, so the low half 0x00000004 is the 'type' and the high half 0x00000011 is the 'symbol' -- which is exactly the report of type 17 against symbol 4. What actually happened is that your reader consumed the COFF record's VirtualAddress as the low half of the packing and its SymbolTableIndex as the high half, then read the real type field as a trailing byte it had no field for. The reason nothing crashed and the output looked plausible is worth stating plainly: 4 is a valid x86-64 relocation type and 17 is a valid symbol index, so every value you printed was a legal member of the right vocabulary. There is no out-of-range value to catch it, no checksum, and no magic in the middle of a COFF file to tell an ELF-layout reader that it has lost the plot. That is the general rule, and it is the real content of the question: a format has no self-description at the record level, so a reader cannot detect that it is parsing the wrong format by looking harder at the bytes -- it can only be prevented by dispatching on the file's identity before it parses a single record. The container header is the only place that states which format this is, and the moment you are inside records you are trusting a decision you made earlier. Which is why the three facts a record has to convey -- which section, which symbol, which type -- are not self-checking in any of these formats, and why a reader written against one of them will fail against another in a way that requires the container to be right." onclick="checkQuiz('obj-relocations-2', this)">Your reader unpacked <code>r_info</code> as <code>(sym &lt;&lt; 32) | type</code> and applied it to COFF's first eight bytes, so it read COFF's <code>VirtualAddress</code> as the type and its <code>SymbolTableIndex</code> as the symbol, then had no field left for the real type. It stayed silent because 4 is a valid <code>R_X86_64_64</code> and 17 is a valid symbol index, so every value it printed belonged to the right vocabulary. <strong>The general rule: a relocation record has no self-description, so the only defence is to dispatch on the container's magic before parsing any record &mdash; once you are inside records you are trusting a decision you made earlier</strong></button>
                    <button class="quiz-option" data-correct="false" data-explain="The mechanism is wrong in an instructive way, and it is worth being precise about why, because the wrong mechanism is the one a reader is tempted to reach for. The report of 'type 0x11, symbol 4' is not the result of a sign or width problem at all. Your ELF reader consumes the first eight bytes of the record as one 64-bit value; COFF's first eight bytes are VirtualAddress (4 bytes, value 4) followed by SymbolTableIndex (4 bytes, value 0x11), so the 64-bit value is 0x0000001100000004. Unpacking that the ELF way -- low half is the type, high half is the symbol -- yields type 4 and symbol 17, which is the opposite assignment from the one reported. So the diagnosis here inverts the fields and would send a reader looking for an endianness bug when there is none. What is right is the conclusion that nothing crashed because the values are individually legal, and the conclusion that the container header is the only thing that states the format. Both of those are the important half of the answer. But the framing that the bytes are 'a valid record in the wrong format' is misleading, because the record is not valid in any format -- it is a ten-byte COFF record, and your reader consumed only eight of those ten bytes and treated them as a complete ELF field. The general rule that follows is the same one, and it is worth restating because it is the transferable part: records are not self-describing, they are not self-checking, and the only place a format identifies itself is the container header, so identity has to be established before parsing rather than inferred while parsing." onclick="checkQuiz('obj-relocations-2', this)">Your reader is little-endian and COFF's record is big-endian, so the <code>u16</code> type field was read byte-reversed and landed in the wrong half of <code>r_info</code>. The general rule is to validate the byte order against the ELF header before parsing records, and to reject any file whose <code>EI_DATA</code> disagrees with your build</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: identify the format from the container header <em>once</em>, before parsing anything, and never infer it from a record you have already misread. Records in all three of these formats are unaligned, unchecksummed and self-describing only in the sense that a field's width tells you nothing about its meaning.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the deep dive that the two before it were leading to. <a href="/courses/obj/lessons/obj-the-hole">A Hole and a Record</a> introduced the four questions and worked one record. <a href="/courses/obj/lessons/obj-reloc-tables">The Object Relocation Sets</a> then took the third question &mdash; the arithmetic &mdash; and showed that its 44 and 147 entries are seven property flags rather than a list to memorise. <strong>This is the record those flags live in, and the finding is that the record's <em>layout</em> is a separate design axis from its <em>vocabulary</em>.</strong> A linker must get both right, and conflating them is why tools that handle two formats usually get the second one subtly wrong.</p>
                <p>The <code>r_addend</code> field is a thread straight into <a href="/courses/obj/lessons/obj-addends">the next concept</a>, which takes the -4 in this record apart. The important thing established here is only that <strong>in an ELF64-RELA file the -4 lives in the record and the four bytes in <code>.text</code> are zero</strong> &mdash; a claim that surprises most people and that the next concept verifies by building the 32-bit counterpart, where the -4 really is in the bytes, and by linking the COFF object to show the bias appearing from nowhere.</p>
                <p>The <code>r_extern</code> bit connects to <a href="/courses/obj/lessons/obj-symbols">Symbol Tables, Compared</a>, and the connection is the section-symbol question that concept raised. <strong>Mach-O's answer is that section symbols are unnecessary</strong> &mdash; one bit in each relocation says whether the index is a symbol or a section &mdash; whereas ELF spends a 24-byte symbol table entry per section that something needs to name, which is exactly why <code>demo_elf.o</code> has two of them and Mach-O has none. <strong>Three formats, one question, and the cheapest answer is the one that reuses a field that was already there for something else.</strong></p>
                <p>The <code>r_length</code> field has a surprising consequence that belongs to a course you have not reached yet. <strong>A relocation whose width is stated in the record can patch a variable-width field.</strong> That is what <a href="/courses/wasm/lessons/wasm-objects">the WebAssembly course's</a> <code>R_WASM_MEMORY_ADDR_LEB</code> does, and it is strictly harder than a PE base relocation or an ELF <code>PC32</code> because getting the width wrong yields a <em>misaligned instruction stream</em> rather than a wrong address. <strong>The bit that looks like a size optimisation is the thing that makes a whole class of relocation possible, and it is there because the designers had a need for it that we can only see from outside.</strong></p>
                <p>And the section-association choice connects to <a href="/courses/obj/lessons/obj-no-segments">No Segments, and Why</a>. All three formats answer &ldquo;which section does this relocation belong to&rdquo; without a segment table, because an object has no segments. <strong>ELF puts the answer in a section header, COFF and Mach-O put it in a pointer, and all three are answering a question an executable would answer with <code>PT_LOAD</code> or <code>LC_SEGMENT_64</code>.</strong> That is the same fact as the missing segment table, seen from the other end: the object file is not an image with the mapping left out, it is a different kind of file that never had one.</p>
                <p>Next: where the addend lives, which turns out to be a choice ELF makes per file and the other two formats do not make at all.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-strings">Previous: Where Names Live</a></span>
                <span>Next: The Addend Lives in the Bytes</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
