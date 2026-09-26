// Object Files — Module 1: Why Object Files Exist
// Concept: the pipeline, why a separate format exists between a compiler and a
// linker, and what "relocatable" actually means.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_intro() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Middle of Every Build — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>The Middle of Every Build</h1>
            <div class="lesson-meta">18 min &middot; Module 1: Why Object Files Exist &middot; Foundations</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>You have written a great deal of code and almost certainly never looked at what your compiler actually handed to your linker. That artefact is the subject of this course, and it is stranger than the executable you eventually run.</p>
                <p>An executable has addresses. A file called <code>a.out</code> knows that <code>main</code> lives at <code>0x401126</code>, and that number was chosen by a linker that had to satisfy page alignment, a preferred base address, and a section-ordering request. <strong>An object file knows none of that.</strong> It cannot know, because it is one translation unit out of possibly ten thousand, and the other nine thousand nine hundred and ninety-nine do not exist yet.</p>
                <p>So what does it know? <strong>It knows where the holes are.</strong> Every reference to a symbol it did not define is left as a piece of incorrect bytes, and beside it the file records what belongs there. That is the whole idea, and this course is a detailed study of how three different formats express it &mdash; because a linker author has to implement all three, and the differences are not cosmetic.</p>
                <p>This is also the first course on the path from a compiler to a shipped binary. The goal for this whole collection is a learner who can go from parsing to a working executable without depending on LLVM or any other backend. That requires understanding this file, because whatever you generate has to be something a real linker will accept.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>The build, and the two files it passes between:</p>
                <div class="formula">
  main.c  --cc-->  main.o  --ld-->  a.out
                    ^
                    |
              the ONLY thing the linker
              is given about main.c
</div>
                <p>Two properties define a relocatable object, and they are both consequences of the same fact &mdash; <strong>it is incomplete</strong>:</p>
                <ul>
                    <li><strong>Addresses are not assigned.</strong> A symbol's value is an <em>offset within its own section</em>, not an address. Nobody has decided where <code>.text</code> will live, so nothing in the file can say what lives inside it.</li>
                    <li><strong>References may be unsatisfiable.</strong> The file can name a symbol that does not exist in it, and that is not an error &mdash; it is the normal case, because the definition is expected to arrive from another object at link time.</li>
                </ul>
                <p>Everything else in the format is in service of those two. The section table exists so the linker can group bytes. The symbol table exists so the linker can learn the names. And the relocation records exist because of the second property: <strong>they are the file's list of its own holes.</strong></p>
                <div class="callout">
                    <strong>A useful reframe.</strong> A relocation record is not a patch to be applied. It is a <em>work order</em>: <code>at this offset, this many bytes are wrong, and here is what would make them right</code>. The difference matters the moment you write a linker, because a work order needs a symbol table to be resolvable against, and a patch does not.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Everything in this course is measured from one 30-line C file, compiled three ways on this machine. The whole specimen set, reproducible from the source that ships beside it:</p>
                <div class="hex-dump">
                    <pre>  demo.c  --  30 lines, chosen to exercise every mechanism
                    a linker must see: a call to an undefined symbol,
                    a reference to an external variable, a global
                    definition, a static definition, initialised and
                    uninitialised data, a string literal with and without
                    a relocation, and an inline function.

  $ clang -target x86_64-pc-linux-gnu  -O1 -c -o demo_elf.o      demo.c
  $ gcc                                -O1 -c -o demo_elfgcc.o    demo.c
  $ clang -target x86_64-pc-windows-msvc -O1 -c -o demo_coff.o   demo.c
  $ clang -target x86_64-apple-darwin    -O1 -c -o demo_macho.o  demo.c
  $ clang -target aarch64-linux-gnu      -O1 -c -o demo_arm64elf.o demo.c
</pre>
                </div>
                <p>And the five files, with the format each one actually is:</p>
                <div class="hex-dump">
                    <pre>  demo_elf.o       1952 bytes  7f 45 4c 46   ELF64 x86-64
  demo_elfgcc.o    2136 bytes  7f 45 4c 46   ELF64 x86-64, from gcc
  demo_coff.o      1098 bytes  64 86 07 00   COFF x86-64
  demo_macho.o     1224 bytes  cf fa ed fe   Mach-O 64-bit x86-64
  demo_arm64elf.o  2176 bytes  7f 45 4c 46   ELF64 AArch64
</pre>
                </div>
                <p>Three things about that table are already worth knowing.</p>
                <p><strong>One compiler produced four of the five.</strong> <code>clang -target</code> emits ELF, COFF and Mach-O from the same frontend, which is why the comparison later in this module is as fair as it can be &mdash; the same source, the same optimisation level, the same version, differing only in the target. <code>gcc</code> is there as an independent second opinion on the ELF half, and it earns its place immediately: it disagrees with clang about which section a relocation should live in.</p>
                <p><strong>COFF is the smallest and Mach-O is not far off, while AArch64 ELF is the largest.</strong> That is not because AArch64 programs are more complex. It is because a single reference to an address needs <em>two</em> fixups on AArch64 and one on x86-64, and that fact drives an entire module of this course.</p>
                <p>And <strong>the build is byte-reproducible</strong>, which matters more than it sounds. Every claim in this course is "these exact bytes mean this exact thing", so the specimens are committed and a learner can re-derive them:</p>
                <div class="formula">
  $ clang -target x86_64-pc-linux-gnu -O1 -c -o re_elf.o demo.c
  $ cmp demo_elf.o re_elf.o &amp;&amp; echo identical

  identical
</div>
                <h3>What the linker is actually given</h3>
                <p>Before the concepts start, one look at the whole job, so every later detail has a place to land. A linker takes objects and does, in order:</p>
                <ol>
                    <li><strong>read and validate</strong> each object's headers, sections and symbol tables</li>
                    <li><strong>pull in</strong> archive members, and only those that resolve something still missing</li>
                    <li><strong>resolve</strong> every symbol reference to exactly one definition, or fail</li>
                    <li><strong>select</strong> between competing definitions where the format allows it &mdash; weak symbols, COMDAT groups</li>
                    <li><strong>assign addresses</strong> to sections, honouring alignment and any linker script</li>
                    <li><strong>apply relocations</strong>, which means filling the holes this course is about</li>
                    <li><strong>write out</strong> an executable or a shared library, with segment headers, an entry point, and its own symbol table</li>
                </ol>
                <p><strong>Steps 1 and 6 are this course.</strong> Everything between them is <a href="/courses/obj">the static linking course</a>, and step 7 onward belongs to loading. The object file is the contract between the compiler and all of that &mdash; and it is a contract written in bytes, with no schema and no validation beyond the lengths.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why the format has to exist at all, told as the problem that a single-file executable does not have. Consider what happens when you split one program into two files:</p>
                <div class="formula">
  util.c                            main.c
    int helper(int x)                extern int helper(int)
      -- returns x * 2               int main(void)
                                       -- returns helper(21)

  Compile them separately. util.o has:
      .text   8 bytes    a function named "helper"
      no mention of main

  Compile main.c separately. main.o has:
      .text   12 bytes   a CALL, and the 4 bytes it needs are
                         currently ZERO -- because the address of
                         helper is not known yet
      a relocation saying: offset 4, patch 4 bytes, relative to
                           the symbol "helper", minus 4

  Neither file can be finished. Neither file is broken.
</div>
                <p>And the alternatives are worse. <strong>Compile both files together</strong> and you lose parallelism &mdash; a large C++ project has thousands of translation units, and the whole reason <code>cc -c</code> followed by a separate link exists is that a thousand compilations should happen in parallel and only one cheap step should follow.</p>
                <p><strong>Or let the compiler invent the addresses.</strong> That is the alternative design, and it is what a <em>whole-program</em> compiler does: parse everything, then emit final code. It works, and it is faster at run time because there is no indirection. <strong>It also cannot build a library.</strong> A library has to be produced before its users are known, so its addresses cannot be final, so it has to ship with holes in it. The moment you want to distribute a compiled library, the object format is forced on you.</p>
                <div class="callout callout-warn">
                    <strong>The trap that catches people, and it is a real-world one.</strong> It is natural to assume an object file is "an executable that is not quite finished". It is not, and the difference is not academic. An ELF or COFF object has <strong>every section address equal to zero</strong> and <strong>no program headers at all</strong> &mdash; there is nothing to map, because mapping is a decision made at link time. A Mach-O object, by contrast, <em>does</em> assign addresses to its sections, as though it were already a small image. Same idea, opposite convention, and a tool written for one will silently produce garbage for the other. The next concepts measure this; the fourth is entirely about the missing table.
                </div>
                <p>One more practical consequence, because it is the reason a linker exists as a separate program rather than a library call. <strong>The object file is the only interface between the two halves of a toolchain</strong>, and it is a stable one. A compiler and a linker from different vendors interoperate because they agree on this format and nothing else &mdash; no shared headers, no build system, no library version to match. That is why the format survived every change to compilers and linkers for forty years while everything around it was rewritten: <strong>it is a file, and files do not need to be recompiled together.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang -target x86_64-pc-linux-gnu -O1 -c -o demo.o demo.c
$ llvm-readobj-21 --file-headers --sections demo.o
$ llvm-objdump-21 -r demo.o</code></pre>
                <ul>
                    <li><strong>Make the specimens yourself.</strong> All five commands are above and the source ships with the course. <strong>Confirm the magic numbers and the file sizes</strong> against the table, and then <code>cmp</code> a rebuild to see that clang's output is byte-reproducible. That is worth doing once: every later claim rests on specific bytes.</li>
                    <li><strong>Find the hole by hand.</strong> Take <code>demo_elf.o</code>, locate <code>.text</code>, and look at the four bytes at offset 4 &mdash; the site of the <code>R_X86_64_PC32</code> against <code>global_counter</code>. <strong>They are zero, and they are supposed to be zero</strong>: the file is telling you it does not know yet. That is the entire format in one inspection.</li>
                    <li><strong>Delete a symbol definition and watch the link fail.</strong> <code>gcc -c util.c</code>, rename <code>helper</code> in one file only, then <code>ld</code> the two. <strong>Read the error message as a spec</strong> &mdash; it names an undefined reference and the object it came from, which is the linker's entire view of the problem.</li>
                    <li><strong>Compare the two ELF producers and find the disagreement.</strong> <code>demo_elf.o</code> and <code>demo_elfgcc.o</code> differ in size by 184 bytes and put the data relocation in different sections &mdash; clang uses <code>.data</code>, gcc uses <code>.data.rel.local</code>. <strong>Both are correct ELF.</strong> A tool with a hard-coded list of "the sections an object has" is now wrong for one of the two most common producers in the world, and it will be wrong invisibly.</li>
                    <li><strong>Prove the file is incomplete, not broken.</strong> Try to <code>objdump -d</code> the <em>addresses</em> of <code>demo_elf.o</code> and notice there is nothing sensible to see, because there are no addresses. Then do the same for <code>demo_macho.o</code>, which has them. <strong>Two object formats, two different beliefs about what an object is.</strong></li>
                    <li><strong>Count what a linker must know.</strong> Write down every question you would need answered to link <code>demo_elf.o</code>: which sections exist, what is in them, which symbols are defined here, which are wanted, which holes need filling. <strong>Every answer is a field in the object file</strong> &mdash; and the list of fields is the course outline.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a linker is given <code>demo_elf.o</code> and nothing else. It must decide where <code>.text</code> will sit in the output, and it must turn four zero bytes at <code>.text</code> offset 4 into a correct reference to <code>global_counter</code>. Why can the object file not answer the first question, and what is the minimum information the second one needs that the file does supply?</p>
                <div class="quiz" id="quiz-obj-intro-1">
                    <button class="quiz-option" data-correct="true" data-explain="Both answers come from the same fact: the object is one translation unit of many, and the others do not exist yet. Addresses are not assigned because nobody has decided where .text will live -- the linker must satisfy alignment, a preferred base, and a section ordering, and it cannot know the inputs it has not been given. Every section address in an ELF or COFF object is zero, and a symbol's value is an offset within its own section rather than an address, so the arithmetic cannot even be set up until layout happens. What the file does supply is everything the linker needs to fill the hole once layout is decided: the offset of the wrong bytes, their width, the arithmetic to perform on them, and the name of the symbol to perform it against. The four zero bytes are not damage, they are a placeholder that the file has labelled. The useful way to hold this is that a relocation is a work order rather than a patch -- it needs the symbol table to be resolvable, and that dependency is exactly why the two tables travel together in every one of these formats." onclick="checkQuiz('obj-intro-1', this)">It cannot answer the first because addresses are assigned by the linker, not the compiler &mdash; the file is one translation unit of many, so every section address is zero and a symbol's value is an offset within its own section. For the second it supplies the offset, the width, the arithmetic, and the symbol name, so the hole is a labelled placeholder rather than damage</button>
                    <button class="quiz-option" data-correct="false" data-explain="The conclusion is right and the reasoning has it backwards in a way that matters. A symbol's value being an offset within its section is not a deliberate withholding -- it is that no address exists to record. The compiler cannot compute one because the section's final position depends on the other objects, on the alignment padding between sections, and on whatever a linker script says, none of which exist when this file is written. So zero is not a value the compiler chose to mean unknown; there is literally no number available. Confusing the two leads to the wrong repair: a tool written on this assumption would look for a sentinel and treat zero specially, when in fact every offset in every object file is legitimately small and zero is a perfectly ordinary value. The honest statement is that the quantity is undefined rather than unknown, which is a stronger claim and a more useful one, because it tells you the linker must supply the missing piece rather than look it up." onclick="checkQuiz('obj-intro-1', this)">It cannot answer because the compiler deliberately writes zero as a sentinel meaning 'address not yet assigned', and the second needs only the offset and the symbol name, since the width and the arithmetic are implied by the relocation type the linker looks up itself</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a build tool that reports, for a given object file, which of its symbols are defined here, which are merely referenced, and which are both. On ELF it works. On COFF it reports every function as "referenced only", including <code>compute</code>, which is plainly defined in the file. The file is valid and <code>nm</code> agrees with you. What is different about COFF's symbol table, and what is the general principle for a tool that must read a symbol table it did not write?</p>
                <div class="quiz" id="quiz-obj-intro-2">
                    <button class="quiz-option" data-correct="true" data-explain="COFF distinguishes defined from undefined by a combination of two fields rather than by a section index alone, and the tool is almost certainly testing only one of them. In COFF a symbol is defined when it has a section number greater than zero; the undefined case is section number zero combined with a storage class that still names a type, and that pairing is what makes an undefined reference look like something else. The general principle is the one this course keeps needing: a symbol table is a data structure with a schema written down in a specification, not in the bytes, and the bytes are only the encoding. A tool cannot infer the schema from the values it sees, because a valid value under the wrong reading is indistinguishable from a valid value under the right one. That is why the ELF and COFF symbol tables, though both superficially a list of name-value pairs, have to be read by separate code -- not because the formats are gratuitously different, but because each format's designers encoded the same facts differently. A tool written for one and pointed at the other will not crash. It will confidently answer a question nobody asked, which is worse." onclick="checkQuiz('obj-intro-2', this)">COFF marks a symbol undefined with a section index of zero <em>together with</em> a storage class, rather than by a single field as ELF does, so testing one field is not enough. The principle: a symbol table's schema lives in the specification, not in the bytes, and the bytes alone cannot tell you how to read them</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real class of bug and the evidence points the other way. A mangling scheme affects how names are written, not whether a symbol is defined -- a mangled compute would still sit in .text with a non-zero section index, so a name-matching tool would still find it defined. And clang's COFF backend does not mangle C symbols the way the MSVC C++ backend mangles string literals, which is a separate and real difference but has nothing to do with the defined-versus-undefined distinction the tool is getting wrong. The decisive evidence is that the tool reports every function as referenced-only rather than some of them: a name-matching failure would be partial and would depend on which symbols happened to be mangled, whereas a single misread field in a table where the other fields are fine produces exactly this uniform, total inversion. Uniform wrongness across every entry points at the schema, not at the names." onclick="checkQuiz('obj-intro-2', this)">COFF mangles its symbol names, so the tool is comparing mangled names against the unmangled names in its own list and never matching. It should use the section index alone and ignore name spelling entirely</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a table's schema lives in the specification, not in the values. Before trusting a field, know what distinguishes "absent" from "present and zero" &mdash; because in most of these formats, and in every one of them today, it does not.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The "one file, three formats" method used throughout this course is the same method the collection already uses elsewhere, and it is worth knowing why it works. In the <a href="/courses/elf">ELF</a> and <a href="/courses/macho">Mach-O</a> courses, a single file is read field by field; here the same file is read in three formats at once. <strong>The first approach tells you how a format works. The second tells you which parts of a format are essential and which are accidents of history</strong> &mdash; and that is a strictly more useful thing to know, because the accidents are exactly what you must not copy when you design the fourth one.</p>
                <p>Two examples of that distinction, both measured later in this course. <strong>Alignments are an accident:</strong> ELF stores a byte count, Mach-O stores a logarithm of it, and both describe the same two alignments. Nothing about an alignment requires either choice, which means a linker author has to convert, and a format designer gets to choose. <strong>Section names being unique is an accident of ELF's choice</strong> to store names as offsets into a shared table; COFF uses an inline 8-byte field, permits two sections to share a name, and this course's own 1098-byte specimen has two sections both called <code>.rdata</code>. A linker keyed on section name loses one of them silently.</p>
                <p>Compare that with the things that turn out to be essential, because the same evidence shows them being reinvented. <strong>The relocation record is essential:</strong> all three formats have one, with the same four ingredients &mdash; where, how wide, what arithmetic, which symbol. <strong>COMDAT is essential:</strong> ELF calls it <code>SHT_GROUP</code>, COFF calls it <code>IMAGE_SCN_LNK_COMDAT</code>, Mach-O calls it a <code>linkonce</code> section &mdash; three names, invented independently, because the problem of two translation units defining the same inline function is unavoidable. <strong>Weak symbols are essential</strong> for the same reason. A format designer who does not think of these will reinvent them badly, and this course is partly a catalogue of what happens if you do.</p>
                <p>The pipeline itself connects to courses you have not met. <a href="/courses/elf/lessons/section-vs-segment">ELF's sections-versus-segments</a> is the distinction this course's fourth concept is entirely about: one table or two, and which question each table answers. <a href="/courses/elf/lessons/relocation-entries">ELF's relocation entries</a> and <a href="/courses/coff/lessons/coff-relocations">COFF's relocations</a> are the per-format detail this course assumes you have met; the <a href="/courses/wasm">WebAssembly</a> course's custom sections are the same escape-hatch idea in a different container. And <a href="/courses/dwarf">DWARF</a> is what an object file carries for free &mdash; a compiler emits debug sections into the object, and a linker passes them through, which is why a stripped binary can be unstripped and a debug binary still runs at full speed.</p>
                <p>Next: a hole and a record &mdash; the one mechanism the whole format exists for, taken apart byte by byte.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/elf">Previous course: ELF</a></span>
                <span><a href="/courses/obj/lessons/obj-the-hole">Next: A Hole and a Record</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
