// Object Files — Module 2: Anatomy, Compared
// Concept: three strategies for storing a name, and the two string tables ELF
// needs that the others do not.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_strings() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Where Names Live — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>Where Names Live</h1>
            <div class="lesson-meta">17 min &middot; Module 2: Anatomy, Compared &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The two previous concepts kept arriving at the same subject from different directions. <a href="/courses/obj/lessons/obj-sections">Sections</a> compared three ways to store a section name: an offset, an 8-byte field, a 16-byte field. <a href="/courses/obj/lessons/obj-symbols">Symbols</a> compared three ways to store a symbol name: an offset, an 8-byte union, an offset into a per-segment table. <strong>Both tables are about the same design decision, and a linker that gets it wrong cannot read a single name in the file.</strong></p>
                <p>It is also the decision with the widest blast radius. A section name read wrongly merges two sections. A symbol name read wrongly resolves a reference to the wrong target. And in both cases the file still parses, the sizes still add up, and the error surfaces as a program that links and then misbehaves.</p>
                <p>So this concept is short and specific: <strong>three storage strategies, the escape hatch each one needs, and the one question that explains why ELF has two string tables and the others have one.</strong></p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Names appear in a class file in two independent roles, and the strategies differ per role:</p>
                <div class="formula">
  ELF     section name -> u32 OFFSET into the table e_shstrndx names
          symbol  name -> u32 OFFSET into .strtab
          TWO tables, because a section header and a
          symbol are walked at different times by different
          tools and neither may depend on the other.

  COFF    section name -> 8 bytes INLINE
                          ... or "/NNN" meaning decimal
                          offset NNN into the string table
          symbol  name -> 8 bytes, first 4 zero means
                          last 4 are a string-table offset
          ONE table, serving three jobs: long section
          names, long symbol names, and (in the PE world)
          export and import names.

  Mach-O section name -> 16 bytes INLINE
          symbol  name -> u32 OFFSET into the __stringtab
                          OF THE SYMBOL'S OWN SEGMENT
          ONE table per segment, plus a segment lookup
          before you can read a single name.
</div>
                <p><strong>Three strategies, and only one of them is an offset into a table you must find.</strong> That is the summary; the rest of this concept is why each format chose what it chose, and what it costs.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>All measured on this course's three specimens. Starting with COFF, because it uses one table for everything and so shows the escape hatch most clearly.</p>
                <div class="hex-dump">
                    <pre>  COFF, demo_coff.o. Symbol table at 0x211, 26 records
  of 18 bytes, so the string table is at:

      0x211 + 26 * 18  =  0x3e5

  The name field is 8 bytes and it is a UNION:

      first 4 bytes NON-ZERO  ->  the 8 bytes ARE the name
          b'.text\x00\x00\x00'
          b'@feat.00'
          b'compute'
          b'.debug$S'      exactly 8 characters, no NUL

      first 4 bytes ZERO      ->  the last 4 are a DECIMAL
                                  offset into the string table
          strtab+4   -> "message_bytes"
          strtab+18  -> "global_counter"
          strtab+33  -> "external_fn"
          strtab+45  -> ".llvm_addrsig"
          strtab+59  -> "uninitialised"
          strtab+73  -> "??_C@_05CJBACGMB@hello?$AA@"
</pre>
                </div>
                <p><strong>One table, three consumers, and the reuse is the interesting part.</strong> The same string table at <code>0x3e5</code> serves long symbol names <em>and</em> the long section-name escape from the previous concept &mdash; <code>strtab+45</code> is <code>.llvm_addrsig</code>, and section 6's name field is the eight bytes <code>/45</code> pointing at the same string. <strong>A reader that has already walked the string table for section names can walk it again for symbols at no cost.</strong></p>
                <p>And the arithmetic that trips everyone: <strong><code>/45</code> is decimal 45, not <code>0x45</code>.</strong> Decimal 45 is offset <code>0x2d</code> from the table start and gives <code>.llvm_addrsig</code>. Hexadecimal <code>0x45</code> is 69 and lands in the middle of the symbol names, giving garbage. The specification says decimal and the specification is right, because COFF's string-table offsets have always been printed in decimal by every tool that dumps one.</p>
                <h3>Mach-O: an offset, but into which table?</h3>
                <p>Mach-O's symbol names are 4-byte offsets, which looks like ELF until you ask <em>offset into what</em>. The answer is the segment, and that is a real complication:</p>
                <div class="hex-dump">
                    <pre>  Mach-O nlist_64, 16 bytes:

      n_strx   u32   offset into a string table
      n_type   u8    N_STAB | N_TYPE | N_EXT -- the type
      n_sect   u8    section index, 0 = no section
      n_desc   u16   library ordinal, or a visibility
      n_value  u64   the address

  and the string table is PER SEGMENT. In demo_macho.o
  there is one LC_SEGMENT_64 and it is UNNAMED, with
  nsects = 6, and the per-section segname fields say
  __TEXT or __DATA.

  So to read _compute's name you must:
      1. find which SEGMENT the symbol's section is in
      2. find that segment's __stringtab
      3. follow n_strx into it

  a two-step lookup where ELF and COFF are one step.
</pre>
                </div>
                <p><strong>And that is the price of the smallest symbol record in the format.</strong> 16 bytes against ELF's 24, achieved partly by not storing a name and partly by making the name's location derivable rather than declared. <strong>Smaller records, more work per record</strong> &mdash; the same trade the section table made, where Mach-O's 80-byte header bought a name at the cost of sixteen bytes per section for a segment name that is inert in an object file.</p>
                <h3>ELF: one offset, two tables</h3>
                <p>And ELF, which is the simplest per-record and the most complex per-file:</p>
                <div class="hex-dump">
                    <pre>  Elf64_Shdr, 64 bytes:

      sh_name      u32   offset into the table e_shstrndx names
      sh_type      u32   SHT_PROGBITS, SHT_RELA, ...
      sh_flags     u64   SHF_WRITE | SHF_ALLOC | SHF_EXECINSTR
      sh_addr      u64   0 in an object
      sh_offset    u64   where the bytes are
      sh_size      u64   how many
      sh_link      u32   for .rela: the symtab index
      sh_info      u32   for .rela: the target section index
      sh_addralign u64   A BYTE COUNT (16, not 4)
      sh_entsize   u64   24 for Elf64_Rela

  Elf64_Sym, 24 bytes:

      st_name      u32   offset into .strtab
      st_info      u8    binding | type &lt;&lt; 4
      st_other     u8    visibility
      st_shndx     u16   section index, or a reserved value
      st_value     u64   offset -- or an ALIGNMENT, for COMMON
      st_size      u64   size
</pre>
                </div>
                <p><strong>Four bytes for a name, in both tables, and nothing inline.</strong> The cost is that the name lives somewhere other than the record that uses it, so every lookup is a second step &mdash; and ELF has two <em>slots</em> for those second steps, named by <code>e_shstrndx</code> and by a symbol table's <code>sh_link</code>. <strong>They are usually different indexes, and the specimen in this course shows they are not required to be.</strong></p>
                <p>So it is worth measuring rather than repeating, because a claim that is in a great many textbooks turns out not to be what this file says. <code>demo_elf.o</code> has <strong>one</strong> string table, not two. <code>e_shstrndx</code> is 1 and the <code>.symtab</code>'s <code>sh_link</code> is also 1, and section 1 is named <code>.strtab</code> &mdash; there is no <code>.shstrtab</code> section header in the file at all. The single table's contents make the merge obvious: it interleaves section names and symbol names, and nothing in it says which is which. GCC's build of the same 30 lines <em>does</em> have two, with <code>e_shstrndx = 16</code> and <code>sh_link = 15</code>. <strong>Both files are conforming</strong>, because the specification says section names come from the table named by <code>e_shstrndx</code> and never says that table has to be distinct from <code>.strtab</code> or has to be called <code>.shstrtab</code>.</p>
                <p>The reason is ordering. A <a href="/courses/elf/lessons/section-header-table">section header</a> is needed by the linker to lay out the file; a <a href="/courses/elf/lessons/symbol-table">symbol</a> is needed to resolve names. A tool that lists sections should not have to parse the symbol table, and a tool that resolves symbols should not have to read section headers &mdash; some symbol operations, like <code>nm</code> on a stripped object, work fine with no section information at all. <strong>One shared table would make each of those tools depend on the other's data structure, and ELF's designers decided that was the worse trade.</strong> COFF and Mach-O, with their smaller records, made the opposite call &mdash; and Mach-O's per-segment version is that call's logical endpoint.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What each choice costs, in bytes and in complexity, measured against the same three files:</p>
                <div class="formula">
  BYTES PER NAME

    ELF      4 bytes, always. 16 section names + 12 symbol
             names = 112 bytes of pointers, plus two tables
             (217 + ~180 bytes here) whose content is the
             strings plus one leading NUL each.

    COFF     8 bytes, usually with the string inline and no
             table at all. 7 sections + 14 symbols = 168 bytes
             of record space, of which most is the name
             itself. Table only for the overflow.

    Mach-O   16 bytes per SECTION (32 counting the segment
             name), 4 bytes per SYMBOL. The section cost is
             the highest of the three and buys a fixed field
             with no lookup at all.

  THE COMPARISON THAT MATTERS

    a linker resolves every symbol reference in the program.
    That is O(references), and for each one it needs a name.
    So the hot path is: symbol -> name.

    ELF     one memory read into a table, plus a bounds check
    COFF    one branch (inline or not), usually a read of
            8 bytes already in the record
    Mach-O  a segment lookup, then a table read

    COFF's is the fastest and Mach-O's the slowest, for the
    same conceptual work.
</div>
                <p><strong>So the fastest reader is the one with the largest records</strong>, which is the trade in one sentence: COFF spends bytes per record to buy speed per lookup, and Mach-O spends lookups per record to buy bytes. Both are rational, and <strong>the choice is a bet about which resource is scarrier in the workload you care about</strong> &mdash; and about what the format's author thought a linker's bottleneck was.</p>
                <p>That last point is the one worth teaching, because it recurs in every format. <strong>A format's redundant-looking fields are usually a bet about a bottleneck.</strong> <a href="/courses/jvm">COFF keeps 40-byte section headers with 20 bytes of always-zero <code>VirtualAddress</code> because it inherited the layout from an executable format and the 20 bytes cost nothing</a>; ELF's 64-byte header is 24 bytes larger than it needs and buys an architecture plugin point; Mach-O's reserved fields are the residue of a design that once used them. <strong>Reading a format's waste is reading its history</strong>, and this course's whole approach &mdash; measure, then ask why &mdash; is that principle applied.</p>
                <p>One more measured detail that ties the two tables together, because it is the kind of thing that makes the design click. <strong>Every string table begins with a single NUL byte, so offset 0 means the empty string.</strong> That is not a coincidence or a padding convention: it means a zero <code>st_name</code> or <code>sh_name</code> is a legal, meaningful value meaning &quot;no name&quot;, and a reader never has to special-case zero. <strong>The table's first byte is reserved for the one case where the pointer is zero.</strong> It is a tiny piece of engineering that removes a branch from every name lookup in the program, and it is the kind of detail that only shows up when you actually dump the bytes.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ python3 -c "print(open('demo_coff.o','rb').read()[0x3e5:0x3e5+24])"
$ llvm-readobj-21 --string-table demo_macho.o</code></pre>
                <ul>
                    <li><strong>Verify the string-table arithmetic, and get it wrong first.</strong> The table is at <code>0x211 + 26 * 18 = 0x3e5</code>. Section 6's name field says <code>/45</code>. <strong>Read offset 45 decimal, then 0x45, and compare.</strong> The first gives <code>.llvm_addrsig</code> and the second gives binary garbage. Doing it in the wrong order once is the point &mdash; it is why the concept says decimal so loudly.</li>
                    <li><strong>Count the name bytes in all three files.</strong> ELF 4 per name plus two tables, COFF 8 usually inline, Mach-O 16 per section plus 4 per symbol. <strong>Work out the total for each file and compare against the file sizes</strong> &mdash; 1952, 1098, 1224 &mdash; and see which format is actually paying the most for names. The answer is not the one you would guess from record sizes alone.</li>
                    <li><strong>Count the string tables, and find out how many there really are.</strong> Read <code>e_shstrndx</code> from the ELF header of <code>demo_elf.o</code>, then read the <code>.symtab</code> header's <code>sh_link</code>. <strong>They are both 1, and section 1 is named <code>.strtab</code> &mdash; so the file has one table, not two.</strong> Dump those 217 bytes and you will find section names and symbol names interleaved with nothing to tell them apart. <strong>Then do the same two reads on <code>demo_elfgcc.o</code></strong>, where the indexes are 16 and 15 and the tables really are separate, and confirm that every reader accepts both files. <strong>That is the whole lesson: the index is specified, the name is a convention, and only one of the two is safe to rely on.</strong></li>
                    <li><strong>Prove the leading NUL.</strong> Read byte 0 of the string table that <code>demo_elf.o</code>'s <code>e_shstrndx</code> points at. <strong>It is zero, and offset 0 is therefore the empty string</strong> &mdash; which is what makes a zero <code>st_name</code> legal rather than an error. Then find a symbol whose <code>st_name</code> really is 0 and confirm what it means: in this file that is the reserved entry and the two <code>STT_SECTION</code> symbols, whose names readers substitute from the section table rather than read from a string at all.</li>
                    <li><strong>Build the Mach-O two-step lookup.</strong> Write a function that, given a symbol, returns its name: find the section, find the segment, find that segment's <code>__stringtab</code>, follow <code>n_strx</code>. <strong>Then delete the segment lookup and watch it work on ELF and fail on Mach-O</strong> &mdash; which is the clearest demonstration of why that format is harder to read.</li>
                    <li><strong>Time something real.</strong> Write two name-lookup routines, one COFF-style and one Mach-O-style, and run each over every symbol in a large real object file. <strong>The difference is the argument for COFF's larger records</strong>, and measuring it beats asserting it. Then ask whether the difference would still matter inside a linker that is spending most of its time on hashing and I/O &mdash; which is probably the real reason nobody optimised this.</li>
                    <li><strong>Find a format that got this wrong.</strong> Think of a container whose names are inline and hit a length limit, and work out what the producer does when it overflows. <strong>Every such format grows an escape hatch, and COFF's <code>/NNN</code> is one of the oldest and cleanest.</strong> The pattern &mdash; fixed field, overflow escape, shared table &mdash; recurs in nearly every container format and is worth recognising on sight.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a COFF section header's 8-byte name field contains the eight bytes <code>/45\x00\x00\x00\x00\x00</code>. A reader that treats the field as inline text sees the name <code>/45</code>. What is the real name, what is the arithmetic to get it, and why is it a decimal offset rather than a hexadecimal one?</p>
                <div class="quiz" id="quiz-obj-strings-1">
                    <button class="quiz-option" data-correct="true" data-explain="The real name is .llvm_addrsig, reached by treating the digits as a decimal 45 and using them as an offset into the string table, which for this file begins at PointerToSymbolTable plus NumberOfSymbols times 18, that is 0x211 plus 26 times 18, which is 0x3e5. Adding 45 decimal gives 0x412, and the bytes there are .llvm_addrsig. It is decimal because the specification says so, and because the escape syntax is slash followed by digits in the same notation every tool that dumps a COFF string table uses, which has always been decimal. The reason that matters practically is that hexadecimal 0x45 is 69, and offset 69 lands in the middle of the symbol-name region of the table rather than in the long-name area, so you get binary garbage that is a perfectly plausible-looking run of non-printable bytes. A reader that guesses wrong here does not fail cleanly: it produces a name, the name is wrong, and the section it attaches to is the wrong section. The general point is about arithmetic conventions in file formats. A number in a file is meaningless without knowing its radix and its base, and both are stated only in a specification. The cheapest defence is to cross-check against a second source, and here the check is available: llvm-readobj prints the resolved name, so you can compare your decoded name against the tool's and a mismatch is immediate rather than silent." onclick="checkQuiz('obj-strings-1', this)">The name is <code>.llvm_addrsig</code>. The string table is at <code>PointerToSymbolTable + NumberOfSymbols * 18</code> = <code>0x211 + 468</code> = <code>0x3e5</code>, and <strong><code>/45</code> means decimal 45</strong> &mdash; offset <code>0x2d</code> &mdash; giving <code>0x412</code> = <code>.llvm_addrsig</code>. It is decimal because the specification says so and every tool that dumps a COFF string table prints decimal; <code>0x45</code> would be 69 and would land in the binary symbol names</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion about the destination is right, and both halves of the arithmetic being offered are wrong in ways that happen to be self-cancelling, which is why they can look plausible. A string table is not located by a header field, because COFF has no such field: there is no pointer to it anywhere, and that is precisely why the table has to be found by computation. And it is not at the end of the file, because the long-name strings are appended after the string table's own four-byte length field, so the last thing in the file is name data rather than the table's end. The path that actually works is the one in the correct answer: derive the start from the symbol table pointer and the symbol count, then add the decimal offset. The deeper point survives either way and is the one worth keeping: a value in a file has no meaning without its radix and its base, and both live in a specification rather than in the bytes. The escape syntax is slash followed by digits, and the digits are decimal, and a reader that assumes otherwise gets a number rather than an error." onclick="checkQuiz('obj-strings-1', this)">The name is <code>.llvm_addrsig</code>, found by taking <code>0x45</code> as a hexadecimal offset from the end of the symbol table, because COFF string-table offsets are conventionally written in hex by the tools that display them</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a symbol-name lookup for a linker and it must handle all three formats. It is a single function with a <code>switch</code> on the format, and it works on ELF and COFF. On Mach-O it returns a name for about half the symbols and an empty string for the rest, and the link fails with unresolved references to symbols that <code>nm</code> lists. The code reads <code>n_strx</code> and looks it up in the string table it found earlier. What is wrong, and what is the shape of the fix that does not turn the function into three functions?</p>
                <div class="quiz" id="quiz-obj-strings-2">
                    <button class="quiz-option" data-correct="true" data-explain="The bug is that the function assumes one string table per file, and Mach-O has one per segment, so n_strx is an offset into a table that depends on which segment the symbol's section belongs to. Half the symbols land in the segment whose table was found and half do not, which is exactly the reported pattern and is a useful signature: a partial failure across a single format usually means a table-selection bug rather than an offset bug, because an offset bug would fail uniformly. The fix that keeps one function is to resolve the table during the per-format parse rather than during lookup, and store the resolved name on the symbol as you build the table. The reader then has a single shape to hand the rest of the linker and the format switch lives in exactly one place. This is the same normalisation argument the triangulation concept made about addresses, and it is worth noticing that the course has now produced the same advice three times for three different fields: the Mach-O provisional address, the COMMON st_value, and now the string table. All three are cases where a value read from a file is not a value until you have decided what it means, and in all three the fix is to decide at the boundary. The general habit is to resist a reader that returns format-native values, because every consumer downstream then has to know which format it is looking at, and there is always more than one consumer." onclick="checkQuiz('obj-strings-2', this)">The function assumes one string table per file; Mach-O has one per segment, so <code>n_strx</code> must be resolved against the table of the segment containing the symbol's section. Resolve the name during the per-format parse and store it on the symbol, so the lookup itself becomes format-blind and the format switch lives in one place</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real hazard and the failure signature argues against it, because a wrong base would be wrong uniformly rather than for half the symbols. If the table were located incorrectly, every n_strx on that file would miss, and the symptom would be zero names rather than half of them. Partial success is the informative part: it means some lookups hit and some miss, and the only way that happens with a base-address problem is if the wrong base happens to be right for one region, which is not plausible here. Nor is endianness a candidate, since n_strx is a 4-byte field read the same way in every format and an endianness bug would affect ELF and COFF as well. The specific mechanism being proposed, reading one byte too many and truncating, is worth ruling out on its own terms: it would corrupt names rather than return empty ones, because a misread offset usually lands somewhere inside the table and yields a short or garbled string rather than nothing at all. An empty result means the offset was out of range, or the wrong table was used, and the partial pattern points squarely at the second." onclick="checkQuiz('obj-strings-2', this)">The function reads <code>n_strx</code> including its own trailing byte, so the offset is one too large and half the lookups land past the end of the table. It should mask the low byte before using the value, since <code>n_strx</code>'s upper three bytes are reserved</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a value read from a file is not a value until you have decided what it means. Resolve format-dependent context at the parse boundary and store the answer, so every consumer downstream is format-blind &mdash; because there is always more than one consumer.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the shared subject of the two before it, and saying so is the point. <a href="/courses/obj/lessons/obj-sections">Sections Compared</a> found the three name-storage strategies for section headers; <a href="/courses/obj/lessons/obj-symbols">Symbol Tables Compared</a> found them again for symbols, plus COFF's union field and ELF's alignment-repurposing. <strong>Seeing the same three decisions twice, in two unrelated tables, is what turns them from trivia into a design axis</strong> &mdash; and the axis is exactly "inline field versus table offset", which every container format in existence has to place on the spectrum somewhere.</p>
                <p>The ELF two-table decision has a close relative in a format you have met, and it is the same argument. <a href="/courses/jvm/lessons/jvm-constant-pool">The JVM constant pool</a> is a single table that both class names and string literals live in, and it works because a class file is read as a whole by one tool. <strong>ELF's two tables exist because an object file is read by many tools, each wanting a different part</strong> &mdash; a linker, a disassembler, <code>nm</code>, a stripper, a debugger. The more consumers a format has, the more it pays to keep their dependencies separate. That is a real scaling argument, and it explains why a format designed for one tool can afford one table while a format designed for an ecosystem cannot.</p>
                <p>Mach-O's per-segment string table connects to something that is not a name at all. <a href="/courses/macho/lessons/macho-load-commands">Mach-O's load commands</a> are a flat list in which segments and sections are nested, and the string tables hang off that structure. So the segment lookup that costs a Mach-O reader a second indirection is not an extra feature &mdash; <strong>it is a consequence of the format's whole organising principle being a tree of load commands rather than a flat header plus tables.</strong> The same design choice shows up in the name lookup, and that is what makes it worth naming: a format's internal structure determines the cost of its lookups.</p>
                <p>And the "read the waste to read the history" point connects to the <a href="/courses/elf">ELF course's</a> section-header walk and to <a href="/courses/pe">PE's</a> always-zero <code>VirtualAddress</code> fields in object files. In every case a field exists because the format was extended from a simpler form, and in every case the residue tells you which form. <strong>That is a genuinely useful diagnostic when you meet an unfamiliar format</strong>: the fields that seem to serve no purpose are the ones that tell you what the format grew out of, and therefore what other formats it is likely to interoperate with.</p>
                <p>That closes Module 2. The object file is now open: sections, symbols, names, and the storage of uninitialised data &mdash; four concepts on the four structures a linker reads, each one compared across three formats, and each one turning up a case where a field does not mean what its name suggests. <strong>Module 3 goes back to the fixup and takes it apart</strong>: the relocation record field by field, where the addend turns out to live in the bytes rather than the record, position independence turns out to be a choice of relocation set, and forty-four types on one architecture turn out to be a classification rather than a list.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-symbols">Previous: Symbol Tables, Compared</a></span>
                <span>Next: COMMON and the ABI Break</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
