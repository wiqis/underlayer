// Object Files — Module 2: Anatomy, Compared
// Concept: three section models, three ways to store a section name, and two
// incompatible ways to store an alignment.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_sections() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Sections, Compared — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Sections, Compared</h1>
            <div class="lesson-meta">21 min &middot; Module 2: Anatomy, Compared &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A section is the unit of everything. The linker groups sections, decides which to keep, assigns addresses by section, and computes permissions per section-group. <strong>Every interesting behaviour in an object file is a section behaviour wearing a different hat</strong> &mdash; so if you misread the section table, nothing afterwards can be right.</p>
                <p>And the section table is where the three formats disagree most, by a wide margin. They do not merely encode the same facts differently; <strong>they do not even agree on which facts exist.</strong> A COFF section has a <code>VirtualAddress</code> field that is always zero in an object. A Mach-O section has a <code>reserved1</code> and <code>reserved2</code> that are always zero. ELF has neither, and has a <code>sh_flags</code> field where COFF has <code>Characteristics</code> and Mach-O has <code>flags</code> and both are section-type enums rather than attribute sets.</p>
                <p>This concept reads the three section tables out of one file each, byte by byte, because this is the part of the format where a tool author has the most to get wrong and the least excuse when they do.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>What a section has to answer, and then the three ways of answering it:</p>
                <div class="formula">
  a section must be able to say:

    what is it called          a NAME
    what kind of thing is it   a TYPE  (code? data? relocations?)
    where are its bytes        an OFFSET into the file
    how many bytes             a SIZE
    what must its start align  an ALIGNMENT
    what may be done to it     FLAGS  (writable? executable?)

  ELF      64-byte Elf64_Shdr,  name = u32 OFFSET into .shstrtab
  COFF     40-byte,             name = 8 bytes INLINE
  Mach-O   80-byte section_64,  name = 16 bytes INLINE
</div>
                <p><strong>Notice the size spread: 40, 64, 80 bytes for a concept that is the same in all three.</strong> Mach-O's extra 16 bytes are half the space of a whole ELF field, spent on a 16-byte name that will hold <code>__cstring</code> and thirteen zeros. <strong>That is not waste exactly &mdash; it buys a format with no string table for section names at all &mdash; but it is a real cost paid per section, and it is why Mach-O objects are not the smallest of the three.</strong></p>
                <p>Now the alignment, which is the single most dangerous field in the whole concept, because all three store an integer and two of them mean different things by it.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All three section tables, decoded from the specimens. COFF first, because its 40-byte record is the easiest to read and it contains the finding that motivates this concept:</p>
                <div class="hex-dump">
                    <pre>  COFF, 20-byte file header then 7 x 40-byte records
  section headers start at 0x14

  [0] b'.text\x00\x00\x00'    rawsize=62   rawoff=0x12c  reloc=0x16a  n=4
  [1] b'.data\x00\x00\x00'    rawsize=16   rawoff=0x192  reloc=0x1a2  n=1
  [2] b'.bss\x00\x00\x00\x00' rawsize=4    rawoff=0x0    reloc=0x0    n=0
  [3] b'.rdata\x00\x00'       rawsize=6    rawoff=0x1ac  reloc=0x0    n=0
  [4] b'.rdata\x00\x00'       rawsize=3    rawoff=0x1b2  reloc=0x0    n=0
  [5] b'.debug$S'             rawsize=92   rawoff=0x1b5  reloc=0x0    n=0
  [6] b'/45\x00\x00\x00\x00\x00' rawsize=0  rawoff=0x211  reloc=0x0    n=0
</pre>
                </div>
                <p>Every one of those `name_field` values is the <strong>raw 8 bytes</strong> out of the file, and three things fall straight out of the column.</p>
                <h3>Two sections are both named .rdata</h3>
                <p>Records [3] and [4] are separate sections with separate file offsets (<code>0x1ac</code> and <code>0x1b2</code>) and separate sizes (6 and 3). They are the two string literals, <code>"hello"</code> and <code>"hi"</code>. <strong>Section names are not unique in COFF, and this is not a compiler quirk &mdash; it is a direct consequence of storing the name inline where nothing enforces uniqueness.</strong></p>
                <p>The consequences for a linker are concrete. A symbol's section is a <em>number</em>, so a correct linker is unaffected. But anything that builds a name-keyed dictionary loses one of these silently, and the loss is invisible because the dictionary still has an entry called <code>.rdata</code> &mdash; just the wrong one. <strong>And note record [2], <code>.bss</code>: <code>rawsize=4</code> but <code>rawoff=0x0</code>.</strong> Four bytes of uninitialised data, occupying no file bytes at all, because there is nothing to store.</p>
                <h3>Record [6] is /45 -- a long name, escaped</h3>
                <p>Eight bytes are not always enough, and COFF's answer is an escape rather than a longer field. A name beginning with <code>/</code> followed by decimal digits means <strong>that decimal offset into the string table</strong>. This specimen uses it:</p>
                <div class="hex-dump">
                    <pre>  PointerToSymbolTable = 0x211      NumberOfSymbols = 26
  string table starts at  0x211 + 26 * 18  =  0x3e5

  name field says  /45   ->  string table offset 45 decimal
  d[0x3e5 + 45]  =  '.llvm_addrsig\x00'      VERIFIED
</pre>
                </div>
                <p><strong>Decimal, not hexadecimal</strong> &mdash; a detail worth knowing before you spend an afternoon on it, because <code>0x45</code> is 69 and lands in the middle of the symbol names instead. <strong>So COFF has both mechanisms</strong>: an inline field for the common case, and a string-table escape for names that do not fit, which is how <code>.debug$S</code> above fits in 8 bytes and <code>.llvm_addrsig</code> fits in 3. ELF needs no escape because it has no inline field to overflow.</p>
                <h3>Mach-O, and the alignment trap</h3>
                <p>Now Mach-O, 80-byte records inside one <code>LC_SEGMENT_64</code>:</p>
                <div class="hex-dump">
                    <pre>  LC_SEGMENT_64  segname = 16 zero bytes  (UNNAMED)
                   vmaddr=0x0  vmsize=252  nsects=6

  sect        addr    size  offset  align          relocs
  __text      0x00     67     704    4  = 16 bytes  4
  __data      0x48     16     776    3  =  8 bytes  1
  __cstring   0x58      6     792    0  =  1 byte   0
  __const     0x5e      3     798    0  =  1 byte   0
  __common    0xf8      4       0    2  =  4 bytes  0
  __eh_frame  0x68    144     808    3  =  8 bytes  0
</pre>
                </div>
                <p>Now put the ELF alignments next to Mach-O's, because this is the whole concept in one comparison:</p>
                <div class="hex-dump">
                    <pre>                    ELF              Mach-O
  code section       AddressAlignment: 16   align: 4
  data section       AddressAlignment:  8   align: 3

  ELF stores a BYTE COUNT.   Mach-O stores a LOGARITHM.
  16 bytes is 4 in log2.  8 bytes is 3 in log2.

  they describe the same two alignments, and a tool that
  copies one format's field into the other is wrong by a
  factor of 4 and 8 respectively.
</pre>
                </div>
                <p><strong>And both wrong answers are plausible.</strong> 16 and 4 are both powers of two; 8 and 3 are both small integers. Nothing looks wrong. The result is a section placed at an address that satisfies the wrong constraint, which links cleanly and then faults at run time if the code needs the stricter alignment. <strong>This is the single most dangerous field in the object format, and it is dangerous precisely because getting it wrong produces a number that looks like an answer.</strong></p>
                <p>Two more Mach-O details worth having. <strong><code>offset=0</code> on <code>__common</code></strong> &mdash; four bytes of uninitialised data with no file bytes, exactly as COFF's <code>.bss</code> at <code>rawoff=0x0</code>, and for the same reason. And the section <em>flags</em> carry the type as an enum: <code>__cstring</code> has <code>0x00000002</code> and <code>__common</code> has <code>0x00000001</code>, which is how a reader tells a zero-fill section from one with bytes without consulting the offset.</p>
                <h3>Where the section names come from</h3>
                <p>The three strategies, with the raw bytes that prove them:</p>
                <div class="hex-dump">
                    <pre>  ELF     the name is a NUMBER. demo_elf.o's section
          header for .text stores sh_name = 6, and byte 6 of
          .shstrtab is where the string "text" begins. Nothing
          in the section header is a name.

  COFF    8 bytes inline:      b'.text\x00\x00\x00'
                             b'.rdata\x00\x00'
                             b'/45\x00\x00\x00\x00\x00'   -> escape

  Mach-O 16 bytes inline:     b'__text' + 10 zero bytes
                             b'__cstring' + 7 zero bytes
                             and a SECOND 16-byte field for the
                             segment name: __TEXT or __DATA
</pre>
                </div>
                <p><strong>Mach-O stores two names per section, 32 bytes, and uses one of them for something the other two formats have no concept of.</strong> Every Mach-O section declares which segment it belongs to &mdash; <code>__text</code> says <code>__TEXT</code>, <code>__data</code> says <code>__DATA</code> &mdash; and in an object that grouping is inert, because the single segment command is unnamed. In a linked binary it is the whole point. <strong>A Mach-O section header reserves 16 bytes for a fact that is always meaningless in the file type where you are most likely to be reading it.</strong></p>
                <p>And the reason ELF needs a second string table, which is a question everyone asks eventually. <strong>ELF has one table for symbol names (<code>.strtab</code>) and a separate one for section names (<code>.shstrtab</code>)</strong> &mdash; <code>demo_elf.o</code> has both. A section header and a symbol are read at different times by different tools, and making either depend on the other would mean you cannot walk one table without first walking the other. <strong>Two tables, two independent walks, no ordering requirement.</strong> COFF and Mach-O need only one string table each, and pay for it in fixed-size fields and an escape hatch.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a linker actually does with this table, because that is the reason any of the fields exist. Six jobs, and for each one, which field it needs:</p>
                <div class="formula">
  1. GROUP      concatenate same-named sections from every
               input. Needs: the name.
               ELF reads .shstrtab. COFF compares 8 bytes or
               follows /NNN. Mach-O compares 16.

  2. ORDER      place them. Needs: nothing -- the linker
               chooses, using alignment and its own policy.

  3. ALIGN      advance the output cursor to satisfy the
               next section. Needs: the alignment, in the
               right UNITS (this is the trap).

  4. SIZE       know how many bytes to copy. Needs: size.
               Watch for .bss and __common, where a nonzero
               size has offset 0 -- nothing to copy.

  5. RELOCATE   find this section's fixups. Needs: COFF keeps
               a pointer+count in the section header; ELF keeps
               a SEPARATE .rela.* section; Mach-O keeps
               pointer+count in the record.

  6. PERMIT     decide read-only vs writable. Needs: the type
               or flags, and then the linker must put every
               .rodata in the same group -- which only works
               because the name is a reliable key.
</div>
                <p>Job 6 is the subtle one and it is where the two <code>.rdata</code> sections become a genuine hazard rather than a curiosity. <strong>Permissions are decided per section, and the linker sorts sections into permission groups &mdash; which means it groups by name.</strong> If your dictionary is keyed by name and <code>.rdata</code> appears twice, one of the two groups is wrong, and the resulting segment either over- or under-permits a page. One of those is a security bug.</p>
                <p>Job 3 is where the alignment units bite, and the honest statement is that this is not a hypothetical. <strong>A linker that reads Mach-O's <code>align</code> as a byte count places <code>__text</code> at offset 4 instead of 16.</strong> For code that never happens to need 16-byte alignment it works perfectly, which is what makes it survive testing. It fails on a function with a 16-byte-aligned <code>movaps</code>, at run time, on some inputs.</p>
                <div class="callout callout-warn">
                    <strong>The general shape of both traps is the same, and it is worth naming as a habit.</strong> A <code>.rdata</code> collision is <em>identity</em>: the format does not promise names are unique, and a reader that assumes they are will merge two things. An alignment misread is <em>units</em>: the format stores a number and the reader supplies the wrong scale. <strong>In both cases the failure is silent, the output is structurally valid, and the bug surfaces as wrong behaviour at run time rather than as a rejected file.</strong> The defence is the same in each case and it is not defensive programming &mdash; it is <em>reading the specification's field definition rather than inferring it from the values you happen to see</em>. A field's meaning is not evident from its plausible values, and the whole course is built on measurements that keep showing that.
                </div>
                <p>One more practical thing, because it decides how you write a reader. <strong>COFF's <code>VirtualAddress</code> and Mach-O's <code>reserved1</code>/<code>reserved2</code> are always zero in an object file, and that is not a coincidence to be documented &mdash; it is a consequence of the previous concept.</strong> Addresses are not knowable at object time, so a format that inherited the field from its executable form carries a dead field. A reader should skip zero-valued fields rather than validate them, and a writer must not try to fill them in. Compare <a href="/courses/elf">ELF</a>, which has no such field in <code>Elf64_Shdr</code> at all &mdash; not because the designers forgot, but because they were not constrained by an existing layout.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-readobj-21 --sections demo_coff.o
$ readelf -SW demo_elf.o
$ llvm-objdump-21 -h demo_macho.o</code></pre>
                <ul>
                    <li><strong>Dump all three section tables and reconcile the counts.</strong> COFF 7, Mach-O 6, ELF 16 &mdash; and ELF's extra nine are string tables, symbol table, section-name table and the <code>.rela.*</code> sections. <strong>Work out for each of ELF's extras whether it is data or metadata</strong>, because that distinction is exactly why a format ends up with sixteen where another has six.</li>
                    <li><strong>Find the <code>/45</code> escape and verify it yourself.</strong> The string table is at <code>PointerToSymbolTable + NumberOfSymbols * 18</code> = <code>0x211 + 26*18</code> = <code>0x3e5</code>. Offset 45 decimal gives <code>.llvm_addrsig</code>. <strong>Then try offset 45 in hex</strong> (69) and confirm it lands in the symbol names instead. <em>Getting this arithmetic wrong on the first attempt is the normal experience and the reason it is worth doing.</em></li>
                    <li><strong>Prove the alignment trap on paper.</strong> ELF <code>AddressAlignment: 16</code>, Mach-O <code>align: 4</code>. <strong>Write the two lines of code that get it wrong</strong> and then compute what alignment your <code>__text</code> section would actually get. Then find a Mach-O section in some real binary where it matters.</li>
                    <li><strong>Write the name-keyed dictionary and lose a section.</strong> Build a map from section name to record for <code>demo_coff.o</code> and print its size. <strong>It will hold six entries for seven sections</strong>, and printing the surviving <code>.rdata</code>'s offset tells you which literal you kept. This is a five-line bug that a real linker has shipped.</li>
                    <li><strong>Find a <code>.bss</code>-shaped section in all three.</strong> COFF <code>.bss</code> at <code>rawoff=0x0</code> with <code>rawsize=4</code>; Mach-O <code>__common</code> at <code>offset=0</code> with <code>size=4</code>. <strong>Add a third uninitialised variable to <code>demo.c</code>, rebuild, and watch the size change while the offset stays zero.</strong> Then ask your reader what it should copy &mdash; the answer is nothing, and getting that wrong writes four bytes of zeros over something else.</li>
                    <li><strong>Count the bytes a section name costs.</strong> ELF 4, COFF 8, Mach-O 16 (plus 16 more for the segment name). <strong>Multiply by the section count in a large real object</strong> and compare against the file size. The format with the most generous name field is spending a measurable fraction of the file on names, and it is buying the absence of a string-table walk.</li>
                    <li><strong>Walk <code>.shstrtab</code> by hand.</strong> Take the <code>.text</code> entry's <code>sh_name</code> value (6), follow that byte offset into <code>.shstrtab</code>, read to the NUL. <strong>Then do the same for <code>.strtab</code> and a symbol name</strong>, and confirm you needed two different tables. ELF's design only makes sense once you have done both walks separately.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: ELF records <code>AddressAlignment: 16</code> for the code section and Mach-O records <code>align: 4</code> for the same section. A linker reads the Mach-O field and uses it directly as a byte count. What alignment does the section actually get, what is the earliest instruction that would fault because of it, and why is the bug likely to survive a test suite?</p>
                <div class="quiz" id="quiz-obj-sections-1">
                    <button class="quiz-option" data-correct="true" data-explain="The section gets 4-byte alignment where it needs 16, because Mach-O stores a logarithm and ELF stores a byte count. The earliest faulting instruction is any SSE or AVX instruction using a memory operand that requires 16-byte alignment, such as a movaps load or store: it raises a general-protection fault when the address is not 16-byte aligned, and 4-byte alignment does not guarantee that. The reason it survives a test suite is that a linker is very likely to place the section at an address that happens to be 16-byte aligned anyway, since the output cursor advances through preceding sections and page and section boundaries frequently land on 16. So most runs work. The failure appears when a preceding section's size shifts the code section off a 16-byte boundary, which depends on the input, which means it reproduces on some builds and not others and looks like a heisenbug. That is the worst property a bug can have, and it is worth noting that the misread value is small, plausible and a power of two, so nothing about the output looks anomalous. The general habit is that a field's units are part of its definition and not inferable from its values, which is why this concept measures the two side by side rather than trusting either." onclick="checkQuiz('obj-sections-1', this)">The section gets 4-byte alignment instead of 16, and the first thing to fault is an aligned SSE/AVX memory operand such as <code>movaps</code>. It survives testing because the output cursor often lands the section on a 16-byte boundary anyway, so the bug only appears when a preceding section's size shifts it off &mdash; making it input-dependent and hard to see</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about the required alignment is right and the faulting instruction is not, which sends the reader looking in the wrong place entirely. Movaps requires 16-byte alignment and does fault, but it is not the earliest failure in the sequence and it is not what a linker bug of this kind usually produces first. The earlier and much more common symptom is a misaligned access that the hardware tolerates in one mode and traps in another, or a section that lands such that a jump target crosses a cache line or a 32-byte boundary and performance falls off a cliff without anything trapping at all. More decisively, the framing that the misalignment must produce a fault is the thing to push back on. Hardware alignment requirements are checked at run time, not link time, and a large fraction of instructions have no alignment requirement at all, so a section placed at 4-byte alignment runs correctly until it meets the one instruction that cares. That is precisely why the bug is input-dependent rather than immediately obvious, and treating it as guaranteed to fault would predict reliable reproduction, which is the opposite of what happens." onclick="checkQuiz('obj-sections-1', this)">The section is placed with 4-byte alignment where 16 is required, and the earliest fault is a <code>movaps</code> or similar aligned SSE access. It survives a test suite because <code>movaps</code> faults only on some inputs, so the bug looks intermittent rather than deterministic</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the section-gathering pass of a linker. It reads each input's section table into a dictionary keyed by section name, merges entries with equal keys, and emits one output section per key. On a build that mixes clang and gcc it produces an executable that runs. On a build that uses MSVC-style COFF objects it produces one that passes every unit test and then crashes in a data-loading path, and only on Windows. The output has one fewer read-only segment than the inputs appear to justify. What is the defect, and what is the one change that fixes it without giving up name-keyed grouping?</p>
                <div class="quiz" id="quiz-obj-sections-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is that the dictionary assumes name equality implies section identity, and in COFF it does not: two sections can share a name and be entirely unrelated, so the merge silently discards one of them. That is why it reproduces on MSVC-style COFF objects specifically, and why the visible symptom is a missing read-only segment rather than a corrupt code section: the discarded section was a .rdata, so the literals it held were dropped, and the data-loading path that reads those literals is the first thing to notice. The fix is not to abandon name grouping, which is genuinely the right model and the reason permissions work at all. The fix is to make the key a pair of the name and something that identifies the section within its input, and to carry the input's identity through the merge so that two same-named sections from different inputs stay distinct and both get emitted. Name-keyed grouping is correct at the granularity of 'all read-only data goes in one segment'; it is wrong at the granularity of 'these two records are the same section'. Making the key a pair preserves the first and fixes the second, and it is a small change confined to the key construction rather than a redesign. The general habit is to check whether an identifier your format gives you is actually unique in it before you use it as a dictionary key, and this course's COFF specimen is a committed, reproducible counterexample." onclick="checkQuiz('obj-sections-2', this)">The dictionary assumes a section name is a unique key, and in COFF it is not &mdash; two <code>.rdata</code> sections merge and one is silently discarded. Key on the pair (name, input-file identity) instead, so same-named sections from different inputs stay distinct while name-keyed grouping still works for permission grouping</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real hazard and the platform evidence rules it out, because the failure is Windows-only and the format in question is COFF regardless of which compiler produced it. A byte-order problem would follow the target, not the toolchain, and clang targeting Windows would fail the same way gcc targeting Linux succeeds. Nor does the report suggest corruption of a specific section's contents: the diagnostic is a missing read-only segment, which is the signature of a section that was never emitted rather than one emitted wrongly. A 32-bit assumption would also be a strange explanation for a linker pass that has no reason to hold a section's contents in a 32-bit variable, and it would produce garbage literals rather than absent ones. The narrower reading is the right one, and it is also the more interesting bug, because the format explicitly permits the situation and only a reader that consulted the specification would have known to handle it." onclick="checkQuiz('quiz-obj-sections-2', this)">The linker is assuming 32-bit fields because it was written for ELF32 objects, and reading a 64-bit COFF section header as two 32-bit halves shifts every subsequent record. It should read the 40-byte COFF record with its native field widths</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: before using any identifier a format hands you as a dictionary key, check that it is actually unique in that format. This course's COFF specimen is a committed, reproducible counterexample &mdash; two sections, one name.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the ELF course's <a href="/courses/elf/lessons/section-header-table">section header table</a> and the PE course's <a href="/courses/pe/lessons/pe-section-table">section table</a> compared against each other and against a third, which is the only way the accidental parts become visible. The <a href="/courses/coff">COFF course</a> is closest to this material &mdash; its first module is "The Relocatable Object" &mdash; so if you have read it, the job here is the part it cannot do alone: showing that a decision COFF made for its own reasons is a decision, and that two other teams made the opposite one.</p>
                <p>The alignment-units trap has a direct counterpart in the architecture section, and it is the same lesson wearing different clothes. <a href="/courses/obj">The Memory Hierarchy</a> course in the collapsed architecture roadmap is where a page is 4096 bytes and an L1 cache line is 64, and where a field that says &quot;alignment 4&quot; is ambiguous between the two unless the specification says which. <strong>Mach-O's <code>align</code> is a logarithm for the same reason a memory-ordering constant is named for what it prevents rather than what it does: a number in a header needs a unit, and the unit is the specification's job to state.</strong> A field whose meaning depends on a convention outside the file is a field a reader cannot check.</p>
                <p>The two-string-tables decision is the same shape as the JVM course's finding that <code>CONSTANT_Utf8</code> is not UTF-8, and for the same underlying reason: <strong>a named encoding in a format is a claim about the bytes, and the claim can be false or can be one of several things.</strong> Here the claim is &quot;this 4-byte number is a name&quot;, and it is true only because a specification says <code>.shstrtab</code> exists at a known offset. A reader that guesses &quot;the name is inline&quot; because COFF does it that way will read ELF's <code>sh_name = 6</code> as the six bytes of a name and get <code>&quot;\x2e\x74\x65\x78\x74\x00&quot;</code> &mdash; which is <code>.text</code> by accident, for the first section, and then garbage for every one after it.</p>
                <p>And the <code>.bss</code>-shaped sections &mdash; nonzero size, zero offset &mdash; connect to <a href="/courses/elf/lessons/common-sections">ELF's common sections</a> and to the tentative-definition machinery that <code>obj-bss-common</code> covers. The important thing to carry from here is the general form: <strong>a section can have a size and occupy no file bytes</strong>, because the size describes memory and the offset describes the file, and for zero-fill data those are different quantities. A reader that copies <code>size</code> bytes from <code>offset</code> is correct for every section except that one, and the exception is the one that appears in almost every object file ever produced.</p>
                <p>One last connection, and it is the one that matters for the mission. <strong>A code generator chooses section names, and section names are how a linker grants permissions.</strong> Put a writable object in a section a reader expects to be read-only and you have changed the security properties of the output; put code in a section named like data and the linker may place it in a data segment and the program will fault on execution. That is not a hypothetical class of bug &mdash; it is why the <a href="/courses/obj">Position-Independent Code</a> and hardening courses exist, and it is why a compiler author has to understand the section table as a <em>contract with the linker</em> rather than as a filing system.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-no-segments">Previous: No Segments, and Why</a></span>
                <span>Next: Symbol Tables, Compared</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
