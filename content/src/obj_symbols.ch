// Object Files — Module 2: Anatomy, Compared
// Concept: three symbol table designs, one of which hides half its records
// inside the others.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_symbols() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Symbol Tables, Compared — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Symbol Tables, Compared</h1>
            <div class="lesson-meta">22 min &middot; Module 2: Anatomy, Compared &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept ended with a lesson about dictionary keys. This one is the other half of it, because <strong>the symbol table is the other place a format hands you something that looks like a record and is not one.</strong></p>
                <p>A symbol table looks like the simplest structure in any of these formats: a flat array of named things. In ELF that is very nearly true. In COFF it is <strong>not true at all</strong>, and a reader that believes it is will read fourteen garbage entries and believe them. That is not a hypothetical: this course's own 1098-byte specimen has 26 records of which only 14 are symbols.</p>
                <p>And underneath that, all three formats answer the same four questions in genuinely different ways. What is my name? Where am I? Am I defined here, or do I want somebody else to define me? How visible am I? <strong>COFF answers the third question with two fields that must agree, and ELF answers it with one field that means something different from what it looks like.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The four questions and the three record layouts. The sizes are from this course's specimens, all 64-bit targets:</p>
                <div class="formula">
  question            ELF              COFF                Mach-O
  ------------------  ---------------  ------------------  ---------------
  what is my name     u32 -> .strtab   8 bytes, inline     u32 -> __stringtab
                                   OR strtab offset
  where am I          u64 value        u32 value           u64 value
  which section       u16, 0=UNDEF     i16, 0=UNDEF        u8, 0=UNDEF
                                           -1=ABS
                                           -2=DEBUG
  am I defined        implied by       StorageClass        u8 nlist flags
                      section != 0    MUST ALSO be read    type bits
  how visible         u8 st_info       StorageClass        u8 n_desc
                      binding + type   (same field!)       (n_type)

  record size         24 bytes         18 bytes            16 bytes
  how many            .symtab          PointerToSymbol-    n_syms
                      sh_size          Table + count       in the header
</div>
                <p>Two structural observations before the details.</p>
                <p><strong>COFF uses one field for two questions.</strong> <code>StorageClass</code> answers both <em>am I defined</em> and <em>how visible am I</em>, which is why those two questions are entangled in every COFF reader ever written. ELF splits them cleanly into <code>st_info</code>'s high and low nibbles. <strong>That is not a simplification, it is a genuine improvement &mdash; and it is also the reason a COFF reader's bug reports are so hard to read, because the field that is wrong is doing two jobs.</strong></p>
                <p>And <strong>Mach-O's record is the smallest at 16 bytes</strong> &mdash; it packs binding, type and visibility into two bit-fields &mdash; and it is the format where a name is an offset into a per-segment <code>__stringtab</code>, so the reader must first find the right segment's string table. <strong>Smallest record, most work per record.</strong> That trade recurs throughout these formats and is worth watching.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All 26 records of <code>demo_coff.o</code>'s symbol table, decoded. The table starts at <code>0x211</code>, the records are 18 bytes each, and the string table follows at <code>0x3e5</code>:</p>
                <div class="hex-dump">
                    <pre>  IDX  NAME                          HOW         VALUE  SECT        CLASS
  [ 0] .text                         inline      0x0     .text(1)     STATIC
  [ 1] &gt;                            --          0x-36fd4e6c  .text(1)  ENDOF_FUNC   &lt;- NOT A SYMBOL
  [ 2] .data                         inline      0x0     .data(2)     STATIC
  [ 3]                              --          0x-206078b  .data(2)  ENDOF_FUNC   &lt;- NOT A SYMBOL
  [ 4] .bss                          inline      0x0     .bss(3)      STATIC
  [ 5]                              --          0x0     .bss(3)      ENDOF_FUNC   &lt;- NOT A SYMBOL
  [ 6] .rdata                        inline      0x0     .rdata(4)    STATIC
  [ 7]                              --          0x672d789d  .rdata(4)  ENDOF_FUNC   &lt;- NOT A SYMBOL
  [ 8] ??_C@_05CJBACGMB@hello?$      strtab+73   0x0     .rdata(4)    EXTERNAL
  [ 9] .rdata                        inline      0x0     .rdata(5)    STATIC
  [10]                              --          0x-d04b58a  .rdata(5)  ENDOF_FUNC   &lt;- NOT A SYMBOL
  [11] .debug$S                      inline      0x0     .debug$S(6)  STATIC
  [12]                              --          0x7831d036  .debug$S(6) ENDOF_FUNC  &lt;- NOT A SYMBOL
  [13] .llvm_addrsig                 strtab+45   0x0     /45(7)       STATIC
  [14] e                             strtab+0    0x0     /45(7)       ENDOF_FUNC  &lt;- NOT A SYMBOL
  [15] @feat.00                      inline      0x0     ABS(-1)      STATIC
  [16] compute                       inline      0x0     .text(1)     EXTERNAL   type=0x20
  [17] global_counter                strtab+18   0x0     .data(2)     EXTERNAL
  [18] uninitialised                 strtab+59   0x0     .bss(3)      EXTERNAL
  [19] call_out                      inline      0x20    .text(1)     EXTERNAL   type=0x20
  [20] external_fn                   strtab+33   0x0     UNDEF(0)     EXTERNAL
  [21] use_data                      inline      0x30    .text(1)     EXTERNAL   type=0x20
  [22] message                       inline      0x8     .data(2)     EXTERNAL
  [23] message_bytes                 strtab+4    0x0     .rdata(4)    EXTERNAL
  [24] .file                         inline      0x0     DEBUG(-2)    103      naux=1
  [25] demo.c                        inline      0x0     UNDEF(0)     0          naux=0
</pre>
                </div>
                <p><strong>Fourteen of those twenty-six records are not symbols.</strong> Records [1], [3], [5], [7], [10], [12] and [14] are auxiliary data belonging to the section symbol above them, and you can see the tell: every one has a garbage <code>Value</code> like <code>0x672d789d</code> and a <code>StorageClass</code> of 0. <strong>A reader that does not honour <code>NumberOfAuxSymbols</code> does not fail loudly. It prints twelve nonsense symbols with nonsense addresses, and the nonsense looks exactly like real data.</strong></p>
                <div class="callout callout-warn">
                    <strong>This is the concept's central trap, and it is nastier than the section-name collision because there is no duplicate key to collide with.</strong> The mechanism is one byte: each section symbol carries <code>naux=1</code>, and the following record is payload. Section symbols need an auxiliary record because a section's size and relocation count are not in the symbol, and COFF's designers put them here rather than in the section header &mdash; where, as the previous concept showed, they also are. <strong>So the same facts are in the file twice in COFF, once in the section header and once in a symbol-table auxiliary record, and a reader that trusts one has no reason to check the other.</strong> Cross-checking them is the cheapest available validation of a COFF reader, and this course's specimen makes it a one-line test: the <code>Value</code> in each aux record should equal the section's <code>rawsize</code>.
                </div>
                <h3>The name field, and both mechanisms in one record</h3>
                <p>The 8-byte name field is a union, and which half is live depends on whether the first four bytes are zero. Both cases appear above:</p>
                <div class="hex-dump">
                    <pre>  inline:   the 8 bytes ARE the name, NUL-padded

      b'.text\x00\x00\x00'              -> ".text"
      b'.debug$S'                      -> ".debug$S"    exactly 8, no NUL
      b'@feat.00'                      -> "@feat.00"
      b'compute'                       -> "compute"

  strtab:  the first 4 bytes are ZERO, the last 4 are a
           DECIMAL offset into the string table at 0x3e5

      strtab+4   -> "message_bytes"
      strtab+18  -> "global_counter"
      strtab+33  -> "external_fn"
      strtab+45  -> ".llvm_addrsig"     (the /45 escape from
                                         the previous concept)
      strtab+59  -> "uninitialised"
      strtab+73  -> "??_C@_05CJBACGMB@hello?$AA@"
</pre>
                </div>
                <p><strong>Eight bytes of inline name is generous compared to ELF's four-byte offset, and COFF still needs the escape.</strong> The reason is visible in record [8]: <code>??_C@_05CJBACGMB@hello?$AA@</code> is 27 characters. It would not fit, so it goes in the string table &mdash; <strong>and that is the same table, at the same offset scheme, that the previous concept found behind the <code>/45</code> section name.</strong> One string table, two uses, and a reader that has already walked it for section names can walk it again for symbol names.</p>
                <p>So COFF's name handling is: <strong>inline if it fits, string table if it does not, and no uniqueness requirement in either case.</strong> ELF is: <strong>always the string table, four bytes, and the name is never in the record at all.</strong> Mach-O is: <strong>always a string table, four bytes, but the table you need depends on which segment the symbol is in</strong> &mdash; so a Mach-O reader needs the section table before it can read a single name.</p>
                <h3>Defined, undefined, absolute, and debug</h3>
                <p>Now the third question, and COFF's answer is the interesting one. Look at the <code>SECT</code> column:</p>
                <div class="hex-dump">
                    <pre>  section  0  = UNDEF   the symbol is wanted, not defined
  section -1  = ABS     the value is not an address at all
  section -2  = DEBUG   a debug-directory pseudo-section
  section >0  = a real section index

  and it is NOT sufficient on its own:

  [20] external_fn   sect=UNDEF(0)  class=EXTERNAL   &lt;- a real want
  [25] demo.c        sect=UNDEF(0)  class=0          &lt;- NOT a want
  [15] @feat.00      sect=ABS(-1)   class=STATIC     &lt;- absolute
  [24] .file         sect=DEBUG(-2) class=103        &lt;- the file name
</pre>
                </div>
                <p><strong>Records [20] and [25] both have section 0 and both are "undefined" by that field alone</strong>, and only the <code>StorageClass</code> distinguishes an actual undefined reference from the file-name record. That is the coupling the model predicted, in a real file. <strong>A COFF reader that asks only "is the section number zero" will treat <code>demo.c</code> as an undefined symbol and try to resolve it.</strong></p>
                <p>And <code>ABS</code> is a genuinely different concept that the other two formats spell differently. An absolute symbol's <code>Value</code> is not an address and not an offset &mdash; it is a constant. <code>@feat.00</code> at <code>ABS</code> with value 0 means "the constant 0". A linker that adds a section address to it produces a pointer, which is not what it meant.</p>
                <h3>ELF, and the same four questions</h3>
                <p>For contrast, ELF's table on the same source. <code>readelf -s</code> reports 12 entries against COFF's 14 real symbols, and the difference is instructive rather than a discrepancy:</p>
                <div class="hex-dump">
                    <pre>  ELF has, that COFF does not:
    one STT_FILE entry naming demo.c        (COFF: .file + aux)
    STT_SECTION entries for .text and
      .rodata.str1.1 ONLY -- not for .data,
      .bss or .rodata, despite .data having
      a relocation against it

  and the reason is demand: a section symbol
  exists because something NAMED that section.
  The .data relocation targets the variable
  "message", so nothing needs a .data section
  symbol and none is emitted.
</pre>
                </div>
                <p><strong>So COFF emitted seven section symbols and ELF emitted two, from the same input.</strong> Not a bug in either, and not a disagreement about the format &mdash; a difference in policy about when a convenience entry is worth 18 bytes. A tool that assumes "every section has a symbol" allocates seven where ELF needs two; a tool that assumes "symbols and sections correspond one to one" breaks on ELF. <strong>Neither assumption is safe, and both directions of mismatch occur in files produced by the two most common toolchains on Earth.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a linker does with all this, and the three jobs that are harder than they look. A symbol table is read four times over the course of a link, and each pass wants something different:</p>
                <div class="formula">
  pass 1  COLLECT     which symbols does this object DEFINE?
                      -- needs: section > 0 (ELF) or
                         section > 0 AND a sane class (COFF)
                      -- COFF: must skip aux records first

  pass 2  WANT        which symbols does it WANT?
                      -- ELF:  section == 0, non-local
                      -- COFF: section == 0 AND the class that
                         means "external reference". Record [25]
                         is section 0 and is NOT one.

  pass 3  RESOLVE     match wants to definitions.
                      -- the whole point. Needs both sides
                         to agree on VISIBILITY, or you get
                         a local that satisfies a global.

  pass 4  RELOCATE    what address does this symbol have?
                      -- ELF/COFF: section address + value
                      -- Mach-O: value IS the address
</div>
                <p>Pass 3 is where COFF's one-field design bites hardest. <strong>A <code>static</code> symbol and an <code>EXTERNAL</code> symbol both have a section number, and only the storage class says which is visible outside the file.</strong> Get it wrong in the permissive direction and a local symbol satisfies a global reference, so two files' private helpers collide and one silently wins. Get it wrong in the strict direction and a legitimate global reference fails to resolve. <strong>Both are silent, and neither shows up until the program misbehaves at run time</strong> &mdash; which is the recurring theme of this entire course.</p>
                <p>Pass 4 is the previous concept's finding restated at the symbol level, and it is where the Mach-O difference bites hardest because it is the one that looks like a unit error and is not. <strong>Mach-O's <code>Value</code> is already an address; ELF's and COFF's are offsets.</strong> Adding a section base to a Mach-O value double-counts. That is the same bug as <code>global_counter</code> reading 0x48 instead of 0, arriving through a different door, and it is why a reader should convert to a common internal shape immediately rather than carrying a format-native value around.</p>
                <div class="callout">
                    <strong>And the honest cost, which is a real design tension rather than a bug in either format.</strong> COFF's 8-byte inline name means a reader can get a name without touching the string table, which is a genuine speed win for a linker that resolves millions of symbols. ELF's always-offset means the section-name and symbol-name tables are independent, so you can walk either without the other, which is a genuine modularity win for a tool that only wants one of them. <strong>Both are optimising for different access patterns, and neither is wrong.</strong> The cost of COFF's choice is the aux-record interleaving, which is pure overhead paid by every reader including the ones that only want names. The cost of ELF's choice is a second string table in the file. <strong>A format is a set of bets about which access pattern is common, and reading one properly means understanding which bet its designers made.</strong>
                </div>
                <p>One more thing worth knowing before you write a reader, because it is the kind of detail that costs an afternoon. <strong>COFF's <code>Type</code> field packs a base type in its high nibble and a derived type in its low one</strong>, and the three functions here all have <code>Type = 0x20</code>. That is <code>0x2 &lt;&lt; 4</code> &mdash; base type 2, which is <em>function</em>. The data symbols have <code>Type = 0</code>. So the field distinguishes code from data, and it is the only place in a COFF object that does so directly &mdash; ELF uses <code>STT_FUNC</code> versus <code>STT_OBJECT</code>, and Mach-O uses an <code>N_TYPE</code> mask. <strong>Three vocabularies for "is this code or data", all answering a question a linker needs to answer when it decides whether a symbol is executable.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf -s demo_elf.o
$ llvm-readobj-21 --symbols demo_coff.o
$ llvm-nm-21 demo_macho.o</code></pre>
                <ul>
                    <li><strong>Write a COFF symbol reader that is wrong, then fix it.</strong> Walk 26 records and print them all. <strong>You will get twelve symbols with values like <code>0x672d789d</code></strong> &mdash; then honour <code>NumberOfAuxSymbols</code> and get 14. Doing the broken version first is the point: it is what a reader that trusts the array shape looks like, and you will recognise the output next time you see it.</li>
                    <li><strong>Cross-check COFF's aux records against its section headers.</strong> Each section symbol's auxiliary record should carry that section's size and relocation count. <strong>Compare them with the 40-byte section headers from the previous concept</strong> &mdash; the same facts twice, and a disagreement means one of your two readers is wrong. This is the cheapest validation of a COFF reader that exists.</li>
                    <li><strong>Decode the 8-byte name union both ways.</strong> Find a record whose first four bytes are zero and follow the last four into the string table; find one whose bytes are the name. <strong>Do it for all 26</strong> and confirm which mechanism each used. Then check that <code>strtab+45</code> is <code>.llvm_addrsig</code> &mdash; the same string the <code>/45</code> section-name escape pointed at.</li>
                    <li><strong>Prove the "section 0 is not enough" claim.</strong> Find <code>external_fn</code> at section 0 and <code>demo.c</code> at section 0. <strong>Show that only the storage class separates them</strong>, then write the two-line predicate that gets it right. This is the exact bug the Apply It question is about, reproduced on a real file.</li>
                    <li><strong>Count section symbols in all three.</strong> COFF 7, ELF 2, Mach-O 0. <strong>Then work out for each of ELF's two what referenced it</strong>, using the relocation records from the second concept. The answer &mdash; only sections something named get a symbol &mdash; is the demand-driven rule, and finding it yourself is worth more than being told.</li>
                    <li><strong>Write the pass-4 bug on purpose.</strong> Build an address for <code>global_counter</code> from all three files using one code path. <strong>ELF and COFF give the same answer; Mach-O gives one that is 0x48 too large.</strong> Then add a conversion at the reader boundary and confirm all three agree. This is the smallest complete demonstration of why a reader should normalise at the edge.</li>
                    <li><strong>Find an <code>ABS</code> symbol and use it wrongly.</strong> <code>@feat.00</code> is at <code>ABS</code> with value 0. <strong>Add its section base and see what number you get</strong>, then argue from the specification why that number is meaningless. An absolute symbol is a constant, and treating it as an address is a category error rather than an arithmetic one.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a COFF reader sees record [20] with <code>SectionNumber = 0</code> and <code>StorageClass = 2</code>, and record [25] with <code>SectionNumber = 0</code> and <code>StorageClass = 0</code>. What is each one, what does the reader get wrong if it tests only the section number, and what is the equivalent single-field test in ELF that avoids the whole problem?</p>
                <div class="quiz" id="quiz-obj-symbols-1">
                    <button class="quiz-option" data-correct="true" data-explain="Record [20] is external_fn, a genuine undefined reference that the linker must try to satisfy, and record [25] is demo.c, the file name that clang emits as metadata. Both have section number zero, so the section number alone cannot tell them apart, and the storage class can: 2 is the external-reference class and 0 is not a class that means anything here. A reader that tests only the section number treats demo.c as an undefined symbol, publishes it in the wants list, and then either fails the link with an unresolved reference to a filename or, worse, satisfies it with some unrelated symbol whose name happens to match. ELF avoids the entanglement because it splits the two questions into different fields: st_shndx answers which section and st_info's binding nibble answers visibility independently, so undefined-ness is one field and visibility is another and neither has to be interpreted in light of the other. That is the real lesson, and it is a design lesson rather than a trivia point: COFF reused a byte because bytes were scarce in 1980, and the cost is that every reader since has to know the pairing. ELF spent four extra bytes per symbol to remove an ambiguity, and that is a good trade for a format designed in 1990 with 64-bit machines in mind." onclick="checkQuiz('obj-symbols-1', this)">Record [20] is <code>external_fn</code>, a real undefined reference, and [25] is <code>demo.c</code>, the source filename emitted as metadata. Testing only the section number puts <code>demo.c</code> into the wants list. ELF avoids it because <code>st_shndx</code> says which section and <code>st_info</code>'s binding nibble says visibility, as two independent fields</button>
                    <button class="quiz-option" data-correct="false" data-explain="The identification of the two records is right, so the disagreement is entirely about the consequence, and getting the consequence wrong here leads to the wrong fix. An undefined reference to a filename does not fail the link and does not get satisfied by a same-named symbol, because the linker matches on the symbol name and nothing in a real link is called demo.c. What actually happens is worse and quieter: the entry sits in the wants list permanently unsatisfied, so a linker that reports unresolved symbols at the end prints a spurious one, and a tool that enumerates what an object needs reports a dependency on a file that is not a dependency at all. Build systems that try to work out an object's inputs from its undefined symbols would then chase demo.c as if it were a library. The conclusion about the fix is unaffected, and it is the part worth keeping: the two questions are entangled in COFF because one byte does both jobs, and a reader must check both fields together rather than either alone." onclick="checkQuiz('obj-symbols-1', this)">Record [20] is <code>external_fn</code> and [25] is <code>demo.c</code>, and a reader testing only the section number will report <code>demo.c</code> as an unresolved symbol and fail the link with a spurious error. ELF avoids the problem because its <code>st_info</code> field is a single byte combining binding and type, so the two questions never need to be asked separately</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing the symbol-collection pass of a linker. It walks each object's symbol table, and for every record with a nonzero section index it publishes the name as a global definition. On ELF and Mach-O it is correct. On COFF it publishes seven section names as if they were global symbols, and two of those names collide with real symbols elsewhere in the link, so a reference to a genuine <code>.data</code> gets bound to a section. The link succeeds and the program reads the wrong address. What is the single defect, and what is the smallest change that fixes it without special-casing COFF by name?</p>
                <div class="quiz" id="quiz-obj-symbols-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is that the code reads the section field as the sole test for definedness, and in COFF the section field is necessary but not sufficient because the storage class independently encodes whether a symbol is file-local. A section symbol has a nonzero section and a local storage class, so it passes a section-only test and is published as a global, and a name like .data is exactly the kind of name another object might also define. The fix that avoids special-casing the format is to stop testing one field and start testing the pair, which means deriving visibility from whatever field carries it in each format: st_info's binding nibble in ELF, the nlist type bits in Mach-O, the storage class in COFF. A reader that computes a single normalised visibility value at the boundary and then applies one shared predicate downstream is format-blind from that point on, which is the same conclusion the previous concept reached about addresses and for the same reason. The alternative of testing the symbol name for a leading dot would work for .text and .data and fail for a section legitimately named by a long-name escape, and it would encode a convention rather than a fact." onclick="checkQuiz('obj-symbols-2', this)">The defect is testing only the section index, and in COFF the storage class independently encodes visibility. Compute a normalised visibility from whichever field carries it per format &mdash; <code>st_info</code>'s binding nibble, Mach-O's <code>n_type</code> bits, COFF's storage class &mdash; then apply one shared predicate downstream, so no format is special-cased by name</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real bug and the report rules it out, because a reader that walked COFF records without honouring the auxiliary count would not produce seven section names at all. It would produce fourteen symbols interleaved with the seven real ones, twelve of which have garbage values and storage class 0, and the resulting link would fail in a far more spectacular way than a name collision. The report describes a clean set of seven section names becoming globals, which is exactly what you get when the auxiliary records are handled correctly and the section symbols are then misclassified. That is a one-field error, not an iteration error. It is also worth noting that the two bugs are not mutually exclusive and a real COFF reader has to survive both, which is why the auxiliary handling belongs in the same chapter as the visibility test rather than being filed as an unrelated parsing detail." onclick="checkQuiz('obj-symbols-2', this)">The reader is not honouring COFF's <code>NumberOfAuxSymbols</code>, so it walks auxiliary records as if they were symbols and publishes their contents as global definitions. It should skip <code>naux</code> records after each symbol, which fixes COFF without affecting ELF or Mach-O</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: normalise at the reader boundary, then let everything downstream be format-blind. One field doing two jobs in the file becomes two clean values in your program, and the special case never reaches the code that matters.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The ELF course's <a href="/courses/elf/lessons/symbol-table">symbol table</a> and <a href="/courses/elf/lessons/binding">symbol binding</a> concepts teach ELF's version of this, and the <a href="/courses/coff">COFF course</a> teaches COFF's. What neither can do is show you both at once, which is what makes the two-field-versus-one-field argument land: <strong>once you have seen a format that needs a <em>pair</em> of fields to answer a question another format answers with one, the ELF design stops looking like obvious simplicity and starts looking like a deliberate four-byte-per-symbol purchase.</strong> That is the recurring lesson of the triangulation method, and this concept is its cleanest example.</p>
                <p>The aux-record trap has a close relative in a format you have already met, and it is worth naming because the shape is identical. <a href="/courses/jvm/lessons/jvm-members">A COFF string table</a> and an <a href="/courses/jvm/lessons/jvm-constant-pool">ELF constant pool</a> both use the same trick of a length field meaning &quot;and here are that many more records&quot; &mdash; and the JVM course's finding 16 is the same species: an annotation value that is a 2-byte index where you expected 4 bytes of inline data, caught only because the parse did not balance. <strong>In every case the failure mode is identical: an array whose length is not in its own shape, so a reader that trusts the shape desynchronises and produces confident garbage.</strong></p>
                <p>Mach-O's leading underscore and its single-letter type vocabulary connect to <a href="/courses/macho/lessons/macho-symtab">the Mach-O symbol table concept</a>, and this concept supplies the <em>why</em> for both. The underscore is there because Mach-O's runtime ABI prefixes C symbols, and the type letter collapse is there because the section table already distinguishes read-only from zero-fill. <strong>Both are consequences of a Mach-O object carrying more structural information than ELF's does</strong> &mdash; which is also why its symbol records are the smallest of the three and its sections the largest. The trade is visible in one comparison and it is not a quality judgement.</p>
                <p>And the pass-4 address bug is the third appearance of the Mach-O-provisional-address finding, which makes it a pattern rather than an incident. It appeared in <a href="/courses/obj/lessons/obj-triangulate">the triangulation concept</a> as a table of numbers, in <a href="/courses/obj/lessons/obj-no-segments">the segments concept</a> as the reason Mach-O objects carry addresses at all, and here it is as a concrete arithmetic error a linker will make. <strong>Three sightings of the same asymmetry, from three directions, and each one made it more concrete than the last.</strong> That is how a fact becomes something a reader gets right rather than something they have heard about.</p>
                <p>One connection forward, because it is where this table is actually used. Everything in this concept serves <strong>symbol resolution</strong> &mdash; matching wants to definitions, and deciding which of several competing definitions wins. That is the whole of the second course in the collapsed linking roadmap, and the fields measured here are its inputs: the <code>StorageClass</code> that COFF entangles, the binding nibble ELF separates, the weak and common cases neither of these specimens contains. <strong>A reader that gets this concept right can already parse every input a resolver needs; it just cannot yet decide anything.</strong> That boundary is the honest place to stop, and the next module is where the fixups that reference these symbols get taken apart.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-sections">Previous: Sections, Compared</a></span>
                <span>Next: Where Names Live</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
