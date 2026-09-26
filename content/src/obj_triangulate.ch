// Object Files — Module 1: Why Object Files Exist
// Concept: the same source compiled three ways — what stays constant, what
// changes, and which of those differences are essential.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_triangulate() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("One Source, Three Formats — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>One Source, Three Formats</h1>
            <div class="lesson-meta">20 min &middot; Module 1: Why Object Files Exist &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>The previous concept read one format's relocation record. That is the right way to learn a format and the wrong way to learn what a format <em>is</em> &mdash; because every choice you saw in ELF looked like a property of object files rather than a decision ELF's designers made.</p>
                <p>So: one 30-line C file, compiled to ELF, COFF and Mach-O, and every field read three times. <strong>What comes out is a much sharper picture, because the things that are the same across all three are the ones you cannot do without, and the things that differ are the ones you are free to choose.</strong></p>
                <p>This is the most useful single technique in the course, and it is worth being explicit about why it works. Reading one format teaches you <em>how to read ELF</em>. Reading three side by side teaches you <em>what an object file has to contain</em> &mdash; and the second is the thing you need in order to design a fourth one, which is where <a href="/courses/obj">this course is ultimately going</a>.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three files from one source, and the first thing to notice is that they are <em>not</em> translations of each other. They are three answers to the same question, by three different designers, in three different decades:</p>
                <div class="hex-dump">
                    <pre>  demo_elf.o       1952 bytes   ELF64      1990s design, still current
  demo_coff.o      1098 bytes   COFF       1980s design, still current
  demo_macho.o     1224 bytes   Mach-O     1980s design, still current

  1952 / 1098 / 1224 bytes for the SAME 30 lines of C.

  A format is a set of answers to five questions:
    1. how do I name a region of bytes?        -> a section
    2. how do I name a thing?                  -> a symbol
    3. how do I store a name?                  -> three different answers
    4. how do I say "these bytes are wrong"?   -> a relocation
    5. where will it go?                       -> NOWHERE. not answered yet.
</pre>
                </div>
                <p><strong>Four of the five questions get answered. The fifth is the entire point of the format.</strong> Every difference you are about to see is an answer to question 3, or a disagreement about how to phrase questions 1 and 2. None of them is a disagreement about the mechanism, because the mechanism is identical in all three.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The cleanest comparison available: <code>llvm-nm-21</code> on all three files, side by side. Same source, same compiler, same optimisation level.</p>
                <div class="hex-dump">
                    <pre>  SYMBOL            ELF           COFF              Mach-O
  ----------------  ------------  ----------------  ------------------
  compute           00000000 T    00000000 T        00000000 T _compute
  call_out          00000020 T    00000020 T        00000020 T _call_out
  use_data          00000030 T    00000030 T        00000030 T _use_data
  global_counter    00000000 D    00000000 D        00000048 D _global_counter
  message           00000008 D    00000008 D        00000050 D _message
  message_bytes     00000000 R    00000000 R        0000005e S _message_bytes
  uninitialised     00000000 B    00000000 B        000000f8 S _uninitialised
  external_fn       (undefined)   (undefined)       (undefined) U _external_fn
  string literal    --            00000000 R        --
                                 ??_C@_05CJBACGMB@hello?$AA@
  clang marker      --            00000000 a @feat.00  --
</pre>
                </div>
                <p>Five things fall out of that table, and the first is the one that makes the technique worth the trouble.</p>
                <h3>The code offsets are identical. The data offsets are not.</h3>
                <p><code>compute</code> is at 0, <code>call_out</code> at 0x20, <code>use_data</code> at 0x30 &mdash; <strong>byte-for-byte the same in all three files.</strong> That is not a coincidence: <code>.text</code> comes first, nothing precedes it, so every code symbol's offset within its section is the same regardless of format.</p>
                <p>Now the data. ELF and COFF both say <code>global_counter</code> is at offset 0 and <code>message</code> at 8. Mach-O says <strong>0x48 and 0x50</strong> &mdash; real numbers, not offsets into a section, and they are exactly where those sections were placed in the object's address space.</p>
                <div class="hex-dump">
                    <pre>  Mach-O section addresses in demo_macho.o:

      __text      0x00     __cstring   0x58
      __data      0x48     __const     0x5e
                            __common    0xf8

  and the symbol values are those addresses verbatim:
      _global_counter  0x48  = __data + 0
      _message         0x50  = __data + 8
      _message_bytes   0x5e  = __cstring + 0
      _uninitialised   0xf8  = __common + 0

  ELF and COFF have NO addresses. 0 and 8 are offsets within
  their own section, and "which section" is a separate column.
</pre>
                </div>
                <p><strong>So the same fact &mdash; where a variable lives &mdash; is recorded as an offset plus a section index in two formats, and as a single absolute number in the third.</strong> A linker written for the first two will compute nonsense from the third, and it will not crash &mdash; it will place <code>message</code> 0x48 bytes into the output instead of 8, and the program will read the wrong memory. This is the single most important practical difference in the module, and it is invisible unless you look at both.</p>
                <h3>The letter vocabulary changed</h3>
                <p>ELF and COFF both use <code>T</code> for text, <code>D</code> for data, <code>R</code> for read-only, <code>B</code> for uninitialised. Mach-O uses <code>T</code> and <code>D</code> identically and then <strong>uses <code>S</code> for both <code>message_bytes</code> and <code>uninitialised</code></strong> &mdash; two different kinds of storage collapsed into one letter.</p>
                <p>That is a real information loss in the display, and it is worth understanding why it is not a loss in the file. <code>message_bytes</code> is in <code>__cstring</code> with <code>Offset: 792</code> &mdash; real bytes in the file. <code>uninitialised</code> is in <code>__common</code> with <code>Offset: 0</code> &mdash; <strong>no bytes in the file at all.</strong> The distinction is not in the symbol's letter, it is in the section's offset. <strong>Mach-O trusts the section table to carry what the letter cannot, and <code>nm</code> is the thing that loses information.</strong></p>
                <h3>COFF has two symbols nobody asked for</h3>
                <p>ELF and Mach-O list eight symbols. COFF lists ten, and the extras are both instructive:</p>
                <div class="hex-dump">
                    <pre>  ??_C@_05CJBACGMB@hello?$AA@   the string literal "hello"

      MSVC mangles string literals into the symbol name: ?_C@ then
      a length byte, then the characters with '?' for '.', then
      ?$AA@ to mark the end. The literal is a first-class symbol.

  @feat.00                          a clang-internal marker

      clang emits this so its C output can be consumed by a C++
      linker that might otherwise apply C++ mangling. It is a
      compatibility hack between two languages, stored in the
      object file.

  ELF has 12 entries in .symtab rather than 8: the extra four are
  the STT_FILE entry naming demo.c, and STT_SECTION entries for
  .text and .rodata.str1.1 -- and only those two, because only
  those two are named by a relocation.
</pre>
                </div>
                <p><strong>That last fact is the subtlest thing in the table.</strong> A section symbol is a convenience entry meaning "this section, as a whole". ELF emits one for <code>.text</code> and for <code>.rodata.str1.1</code> and for nothing else &mdash; not for <code>.data</code>, even though <code>.data</code> exists and even though <code>.data</code> has a relocation against it. The reason is demand: the relocation against <code>.rodata.str1.1</code> targets the <em>section</em> because that is where a string literal pool lives, while the relocation against <code>.data</code> targets the variable <code>message</code> by name and needs no section symbol.</p>
                <div class="callout callout-warn">
                    <strong>For a linker author this is a trap with a specific failure.</strong> A natural implementation resolves a relocation's symbol by always looking for a section symbol when the referenced thing is a section, and falls back to a name lookup otherwise. That works. The bug is a tool that <em>pre-allocates</em> a section symbol for every section because assuming one always exists is easier &mdash; and then a tool that compares symbol tables against a reference reader finds two extra entries in one and not the other, for a file that is completely valid. <strong>A section symbol is a fact about what something referenced, not a fact about what sections exist.</strong> ELF's own <code>llvm-readobj</code> output shows exactly this: <code>STT_SECTION</code> entries for two sections out of sixteen.
                </div>
                <h3>Sections, side by side</h3>
                <p>The same comparison for the region table, which is where the storage strategies diverge most:</p>
                <div class="hex-dump">
                    <pre>  ELF   16 entries   .text .data .bss .rodata .rodata.str1.1
                              .rela.text .rela.data .rela.data.rel.local
                              .eh_frame .rela.eh_frame .note.GNU-stack
                              .comment .symtab .strtab .shstrtab
                              .llvm_addrsig

  COFF   7 entries    .text .data .bss .rdata .rdata
                              .debug$S .llvm_addrsig
                              -- note: .rdata appears TWICE

  Mach-O 6 entries   __text __data __cstring __const
                              __common __eh_frame
</pre>
                </div>
                <p>Three observations that each cost a linker author something.</p>
                <ul>
                    <li><strong>COFF's two <code>.rdata</code> sections.</strong> One string literal each, because a COFF section name is an 8-byte inline field and nothing enforces uniqueness. <strong>A linker keyed on a dictionary of section names silently loses one of them.</strong> A COFF section is identified by index, full stop.</li>
                    <li><strong>ELF needs two string tables</strong> &mdash; <code>.strtab</code> for symbol names and <code>.shstrtab</code> for section names &mdash; because a section header and a symbol are read at different times by different tools, and neither wants to depend on the other. COFF and Mach-O need one, and pay for it with fixed-size inline fields.</li>
                    <li><strong>Relocations get their own sections in ELF</strong> (<code>.rela.text</code> and friends) and are counted in Mach-O's 16; COFF keeps them in the section header. Same reason as the class file's attribute placement: <strong>you want the bytes contiguous so you can stream them</strong>, and you want the metadata separable so you can skip it.</li>
                </ul>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Sorting the differences into <em>essential</em> and <em>accident</em>, because that distinction is the transferable skill and it is the reason to do this exercise at all.</p>
                <div class="formula">
  ESSENTIAL -- three independent teams all invented these,
  because the problems are unavoidable:

    the section table          group bytes by purpose
    the symbol table           name a thing, or want one named
    the relocation record      say "these bytes are wrong"
    a way to store a name      ... and every format needs one
    64-bit and 32-bit targets  ... and they must coexist

  ACCIDENT -- one team's choice, another did differently,
  and both are correct:

    inline name vs offset      ELF offsets, COFF 8 bytes,
                               Mach-O 16 bytes
    one string table or two    ELF needs two, others one
    sections carry addresses   Mach-O yes, ELF and COFF no
    alignment units            ELF a byte count, Mach-O a log
    a reloc type enum          ELF and COFF enum, Mach-O bits
    how to spell read-only     R in ELF/COFF, S in Mach-O
    what to call a call        PLT32 / REL32 / BRANCH

  the practical consequence: a linker needs an ARCHITECTURE
  plugin (essential, per-arch) and a FORMAT plugin (accident,
  per-format), and those are two different pieces of code with
  two different reasons to exist.
</div>
                <p>The compiler difference is worth separating out, because it is a fourth axis and it is the one that bites in practice. Same source, same flags, two ELF producers:</p>
                <div class="hex-dump">
                    <pre>              clang 21            gcc 15.2
  size          1952 bytes         2136 bytes
  .text holes   0x04 0x0a          0x06 0x10
                0x21 0x33          0x1e 0x2e
  data reloc    in .data           in .data.rel.local
  first func    compute at 0       compute at 0
  last func     use_data at 0x30   use_data at 0x2e
</pre>
                </div>
                <p><strong>gcc emits a section ELF's specification does not require anyone to emit, and puts a relocation in it.</strong> Both files are valid. A tool that hard-codes "the sections a relocatable object has" is wrong for one of the two most common producers on Earth &mdash; and the failure is a missing relocation on a data pointer, which links cleanly and produces a binary that reads the wrong address at run time.</p>
                <div class="callout">
                    <strong>Why gcc does this, and why it is defensible.</strong> <code>.data.rel.local</code> exists so the linker can <em>discard</em> that section once the relocations are applied, for data that is only referenced within the object and becomes dead once linked. Putting such relocations in <code>.data</code> would make them indistinguishable from relocations that must be kept. <strong>The section name is carrying a policy the linker can act on</strong>, which is a good reminder that a section name is not always just a label &mdash; and that an unfamiliar one may encode an optimisation you have not implemented.
                </div>
                <p>And the deepest lesson, which is the one a compiler author needs. <strong>Look again at the relocation counts: 4 on x86-64 ELF, 8 on AArch64 ELF, 4 on COFF, 4 on Mach-O.</strong> The AArch64 doubling is not a format difference at all &mdash; it is an <em>instruction encoding</em> difference, and it arrives in the object file unchanged. The object format did not choose to record two fixups; it had no choice, because the code contains two fields that need filling.</p>
                <p>So the dependency runs <strong>instruction set &rarr; object format &rarr; linker</strong>, and the object format is downstream. That is why this course has a module on encodings, and why an object-file course that skipped the architecture would be teaching a mechanism without knowing why its shape is what it is. A learner who wants to write a code generator needs the encodings first; a learner who only wants to read object files can skip them, and the course marks which is which.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ llvm-nm-21 courses/obj/assets/samples/demo_elf.o   # and coff, and macho
$ llvm-readobj-21 --sections courses/obj/assets/samples/demo_coff.o</code></pre>
                <ul>
                    <li><strong>Run <code>nm</code> on all three and reproduce the table above.</strong> Then <strong>change the C source</strong> &mdash; add a function before <code>compute</code> &mdash; and watch <em>all three</em> code offsets shift together. That is the constant made visible, and it is the part you can rely on.</li>
                    <li><strong>Move a function into <code>.text</code> after the data</strong> and see whether the code offsets still agree. The answer teaches you that offset 0 in <code>.text</code> is a coincidence of ordering, not a property of the format.</li>
                    <li><strong>Find the two <code>.rdata</code> sections in <code>demo_coff.o</code> and prove they are different.</strong> Sizes 6 and 3, and the strings inside are "hello" and "hi". <strong>Then write three lines of code that key a dictionary on section name and watch one section disappear</strong>, which is the bug this finding is about.</li>
                    <li><strong>Count ELF's <code>STT_SECTION</code> symbols and ask why there are two and not sixteen.</strong> The answer &mdash; only sections something actually references get one &mdash; is the kind of demand-driven design that appears throughout these formats, and it is worth noticing as a pattern.</li>
                    <li><strong>Diff the two ELF producers section by section.</strong> <code>readelf -SW</code> on both. <strong>Then find which section gcc uses that clang does not</strong>, and work out what the linker is supposed to do with it. The answer is a legal optimisation you have probably never implemented.</li>
                    <li><strong>Write the Mach-O data-address trap as a failing test.</strong> Take <code>demo_macho.o</code>, take <code>_global_counter</code> at <code>0x48</code>, and treat that 0x48 as an offset into <code>__data</code> the way you would for ELF. <strong>Then look at what <code>ld64</code>-class linkers must do differently</strong> &mdash; and note that <code>ld64.lld</code> is not on this machine, so reason it out rather than running it.</li>
                    <li><strong>Classify ten differences yourself.</strong> Take the table, cover the format names, and sort each difference into essential or accident. <strong>Then check your answers against the list in this concept</strong> &mdash; the ones you get wrong are the ones you have not internalised yet, and that is the exercise's real output.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: <code>llvm-nm</code> reports <code>global_counter</code> at <code>00000000</code> in <code>demo_elf.o</code> and at <code>00000048</code> in <code>demo_macho.o</code>. Meanwhile <code>compute</code> is at <code>00000000</code> in both. Why do the code symbols agree and the data symbols not, and what specifically breaks in a linker that reads both formats with one code path?</p>
                <div class="quiz" id="quiz-obj-triangulate-1">
                    <button class="quiz-option" data-correct="true" data-explain="Two different reasons, and they are worth keeping separate. The code offsets agree because __text and .text are the first thing in the file with nothing before them, so every code symbol's offset within its section is the same number regardless of format; it is a coincidence of ordering that happens to hold for all three files, and it would stop holding the moment something preceded the code. The data offsets differ for a structural reason: an ELF or COFF symbol's value is an offset within its own section, with the section identified separately, so global_counter is at offset 0 in .data and the answer is complete. A Mach-O symbol's value is a single absolute address, and the object's sections already carry provisional addresses, so 0x48 is the object's own address of __data. The linker's bug follows directly. Code that reads 'value, then add the section's assigned output address' is correct for ELF and COFF. Given the same 0x48 for Mach-O, it adds the output base to an address that already contained one, so the variable lands 0x48 bytes past where it should, inside whatever section follows .data. Nothing crashes, the link succeeds, and the program reads the wrong memory at run time. That is the worst shape for a portability bug, which is why it is worth catching with a two-format comparison rather than a test suite." onclick="checkQuiz('obj-triangulate-1', this)">The code symbols agree because <code>.text</code>/<code>__text</code> comes first with nothing before it, so their offsets coincide; the data symbols differ because ELF and COFF store a <em>section offset</em> while Mach-O stores a full <em>address</em>. A linker that adds the section's assigned address to the stored value will place the variable 0x48 bytes too far on Mach-O, and the failure is a clean link followed by reading the wrong memory at run time</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion matches but the mechanism is inverted, and the inversion produces a fix that cannot work. The two formats do not store the same value differently; they store genuinely different quantities. An ELF or COFF symbol value is only meaningful together with its section index, and the two are read from different fields. A Mach-O symbol value is an address on its own and its section is derivable by finding which section range contains it. So there is no unit conversion to insert, and normalising one into the other means deciding which of the two you are going to pretend is canonical -- and you cannot, because the ELF form is undefined without the section and the Mach-O form would lose information if you reduced it to a bare offset. The correct fix is a per-format reader that produces a common internal representation of (section, offset) before any arithmetic happens, which is a different and larger change than a unit conversion. Recognising that a quantity is undefined on its own, rather than merely measured differently, is the distinction that matters here." onclick="checkQuiz('obj-triangulate-1', this)">The code symbols agree because ELF and Mach-O both place code first, while the data symbols differ only in units &mdash; Mach-O reports bytes and ELF reports 16-byte units &mdash; so the linker should normalise Mach-O's value by dividing by the section's alignment before adding the section base</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing an object-file inspector for a build tool that must handle output from any toolchain. It reads a symbol's section and value, adds them, and reports a file-absolute address. It is correct on every ELF object in the project and on every COFF object. On Mach-O objects it reports addresses that are far too large, and downstream code that opens files by computed offset fails. The tool has a single <code>read_symbol</code> function and a <code>format</code> string it switches on in three other places. What is the actual defect, and why is adding a fourth <code>if format == "macho"</code> the wrong fix?</p>
                <div class="quiz" id="quiz-obj-triangulate-2">
                    <button class="quiz-option" data-correct="true" data-explain="The defect is a representation error, not a missing case: the tool assumed that one number means the same thing in every format, when in ELF and COFF it is a section-relative offset and in Mach-O it is a standalone address. Adding a fourth branch treats the symptom and leaves the type lying about itself everywhere else. The reason that branch is the wrong fix is that the addition happens in more than one place -- the symbol reader, the relocation application, the address computation, and anything that formats an address for a human -- and each is a site where the same assumption is re-encoded. A branch added to one of them fixes one path and the other three still produce the wrong number, so the bug survives the fix and comes back on a code path nobody tested. The right change is to give read_symbol a single output shape, a section plus an offset, and make it return that for all three formats by deriving the section from the address range for Mach-O. Then the arithmetic downstream is format-blind and there is nowhere for the assumption to hide. The general pattern here is the one that runs through this course: a value read from a file is not a value until you have decided what it means, and encoding that decision in the type rather than in a branch at each use is what makes a reader correct by construction instead of by testing." onclick="checkQuiz('obj-triangulate-2', this)">The tool treats a section-relative offset and a standalone address as the same quantity, which is a representation error rather than a missing case. Fix it by having <code>read_symbol</code> return a common <em>(section, offset)</em> pair for every format &mdash; deriving the section from the address range for Mach-O &mdash; so the arithmetic downstream is format-blind, instead of branching at each use site</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real hazard and the evidence rules it out. If the bug were about different section layouts, adding the section's output address to a symbol's stored value would still produce something in the right neighbourhood -- a wrong section, perhaps, but not addresses that are far too large. Far too large is the signature of adding a base to a value that already contained one, which is exactly what Mach-O's 0x48 is: an address that already includes the object's provisional layout. Also, the problem statement says the tool is correct on every ELF and COFF object in a real project, which means the layouts it encounters are not the problem; the layouts differ per object and it copes. And the hint about the function is the real clue: if the defect were in how the tool switches on format elsewhere, the reader would already be inconsistent with those other sites before any Mach-O file arrived. A defect inside the value's meaning explains all three observations, and a layout or branching defect explains none of them." onclick="checkQuiz('quiz-obj-triangulate-2', this)">The tool is missing a Mach-O case in its format switch, and because it computes addresses as section base plus symbol value it double-counts on Mach-O, where sections already carry addresses. Adding a fourth branch to subtract the section base on Mach-O output will fix it</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a value read from a file is not a value until you have decided what it means. Encode that decision in the type your reader returns, not in a branch at each place you use it &mdash; then the assumption has nowhere to hide.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This concept is the course's method made explicit, and the method is the same one the collection uses in the <a href="/courses/jvm">JVM class file</a> course, where one 409-byte <code>Hello.class</code> was read field by field and then again as the source of a pool that turned out to be 69% of the file. <strong>In both cases the claim being tested was a number, and in both cases the number came from a file rather than from memory.</strong> The discipline is identical: measure, then teach, and never assert a field's value because it is what the format "should" put there.</p>
                <p>The essential-versus-accident distinction is the same one the <a href="/courses/jvm/lessons/jvm-attributes">JVM attribute mechanism</a> turns on, and it is worth stating as a general reading skill. In ELF a section name is an offset into <code>.shstrtab</code>; in COFF it is 8 bytes inline; in Mach-O it is 16 bytes inline. <strong>All three are accidents, and all three are specified.</strong> But <code>SHT_GROUP</code>, COFF's <code>IMAGE_SCN_LNK_COMDAT</code> and Mach-O's <code>linkonce</code> section are three <em>names for the same essential idea</em>, invented by three teams who all hit the same problem. <strong>When you see one format reinvent something another already has, that is the signal it is essential &mdash; and the signal that your own design will need it too.</strong></p>
                <p>The compiler-divergence finding connects to something with real consequences. <a href="/courses/elf/lessons/common-sections">ELF's common sections</a> teaches <code>.data.rel.local</code> and friends as ELF features, and this concept shows <em>why they exist</em>: they are an optimisation hint the linker acts on, and gcc uses one that clang does not. <strong>A tool that reads section names as opaque labels throws away a policy the producer encoded on purpose</strong>, and the <a href="/courses/elf">ELF</a> course's warning about <code>e_shstrtab</code> being a place a producer can legally lie to you applies here too.</p>
                <p>The instruction-encoding dependency is the hinge to the architecture section, and it is worth being blunt about the direction. <strong>Object-file formats are downstream of instruction sets.</strong> The reason ELF has <code>R_AARCH64_ADR_PREL_PG_HI21</code> as a distinct type is that <code>adrp</code> has a 21-bit field; the reason x86-64 can get by with <code>R_X86_64_PC32</code> is that <code>mov</code> with a RIP-relative operand has a 32-bit displacement. Neither format chose this. <strong>So a code generator cannot be written before the encodings are understood, and a linker cannot be written before the encodings are understood either</strong> &mdash; the linker writes into those fields and must know they are wide enough. That is the argument for the <em>Encoding</em> concept, and it is a structural one rather than a pedagogical preference.</p>
                <p>Two more connections, both about tools rather than formats. <a href="/courses/macho/lessons/macho-symtab">Mach-O's symbol table</a> teaches the leading underscore and the <code>S</code> letter, and this concept shows <em>where they come from</em>: Mach-O prefixes C symbols because its runtime does, and it collapses read-only and uninitialised into one letter because its section table already distinguishes them. <strong>Almost every oddity in a format is a decision made to solve a problem the neighbouring format did not have.</strong> And <a href="/courses/coff">COFF</a> is the format whose object file <em>is</em> the subject of this course &mdash; its first module is "The Relocatable Object" &mdash; so if you have read it, this course's job is the part COFF alone cannot teach: that the same seven questions have seven different answers, and which of those answers you are free to change.</p>
                <p>Next: the table that is <em>not</em> in any of these files, and the reason it cannot be.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-the-hole">Previous: A Hole and a Record</a></span>
                <span>Next: No Segments, and Why</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
