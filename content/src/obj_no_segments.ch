// Object Files — Module 1: Why Object Files Exist
// Concept: an object file has one table where an executable has two, and the
// missing table is not an oversight.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_no_segments() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("No Segments, and Why — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>No Segments, and Why</h1>
            <div class="lesson-meta">16 min &middot; Module 1: Why Object Files Exist &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every executable you have run has two tables describing its own contents, and they say different things. A linked ELF has a <strong>section table</strong> grouping bytes by purpose &mdash; <code>.text</code>, <code>.data</code>, <code>.rodata</code> &mdash; and a <strong>program header table</strong> grouping them again by how to map them, with permissions attached.</p>
                <p>An object file has the first and not the second. <code>readelf</code> does not hedge about it:</p>
                <div class="hex-dump">
                    <pre>  $ readelf -lW demo_elf.o

    There are no program headers in this file.
</pre>
                </div>
                <p>That is a strange thing to find, because the two tables are so often taught together that the absence reads like a bug. It is not. <strong>The second table answers a question that an object file cannot yet answer</strong>, and working out which question is worth a concept in its own right &mdash; because it is the cleanest available answer to the question the <a href="/courses/elf">ELF course</a> raises when it contrasts sections and segments, and it generalises to COFF and Mach-O without modification.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Two questions, two tables, and an object file can only answer the first:</p>
                <div class="formula">
  QUESTION 1: what bytes are in this file, and how do they
              group by purpose?

    answered by: the SECTION table
                 .text   .data   .bss   .rodata
    who asks:    you, and a linker deciding what to keep
    in an object: YES


  QUESTION 2: how should a loader map those bytes, with
              what permissions, at what addresses?

    answered by: the SEGMENT table (ELF program headers)
                 LOAD 0x000000  R
                 LOAD 0x001000  R E
                 LOAD 0x002000  R
                 LOAD 0x002e00  RW
    who asks:    the kernel, at exec time
    in an object: NO -- and it CANNOT be answered yet
</div>
                <p>Three things in that second table are worth pausing on, because together they are the whole reason it cannot exist in an object.</p>
                <p><strong>Permissions.</strong> A segment says <code>R</code>, <code>R E</code> or <code>RW</code>. That is a statement to the kernel's page-table code, and deciding it requires knowing <em>which sections ended up adjacent</em> after every object has contributed its own. A compiler compiling one translation unit cannot know whether its <code>.rodata</code> will end up next to another object's <code>.rodata</code> or next to that object's <code>.data</code>.</p>
                <p><strong>Addresses.</strong> A segment carries a virtual address. No address is knowable until layout is done, which is the first concept's point and the reason the object has none.</p>
                <p>And <strong>the page granularity itself.</strong> Segments are page-aligned by construction, so the fourth <code>LOAD</code> below starts at file offset <code>0x2e00</code> but loads at memory address <code>0x3e00</code>. <strong>Those differ by exactly one page of padding</strong>, inserted so the segment can be made writable without a page holding read-only data becoming writable too. You cannot compute that offset until you know every section's final size and every neighbour's alignment.</p>
                <div class="callout">
                    <strong>So the absence is not a simplification &mdash; it is an impossibility.</strong> The segment table is not "the same table, left out for size". It is a table whose every field depends on information that does not exist until link time. <strong>A format that shipped one anyway would be shipping a table full of zeroes that the linker has to rewrite completely</strong>, which is strictly more work than not writing it.
                </div>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The same program, as an object and as a linked executable, side by side. Both produced on this machine:</p>
                <div class="hex-dump">
                    <pre>  $ clang -target x86_64-pc-linux-gnu -O1 -c -o exe.o exe.c
  $ clang -target x86_64-pc-linux-gnu -O1 -c -o other.o other.c
  $ clang -target x86_64-pc-linux-gnu -O1 -o exe exe.o other.o

                     OBJECT              EXECUTABLE
  size               1952 bytes          16136 bytes
  e_type             REL                DYN  (PIE)
  entry point        0x0                0x1040
  sections           16                 31
  program headers    0                  12
</pre>
                </div>
                <p>Four differences, and <strong>only the first is the one this concept is about.</strong></p>
                <p><strong>Zero program headers, then twelve.</strong> And the four that matter for mapping:</p>
                <div class="hex-dump">
                    <pre>  $ readelf -lW exe | grep -A1 LOAD

    LOAD  offset 0x000000  vaddr 0x00000000  filesz 0x5e8   R      0x1000
    LOAD  offset 0x001000  vaddr 0x00001000  filesz 0x181   R E    0x1000
    LOAD  offset 0x002000  vaddr 0x00002000  filesz 0x160   R      0x1000
    LOAD  offset 0x002e00  vaddr 0x00003e00  filesz 0x220   RW     0x1000
                                          ^^^^^^^^
                     the RW segment's file offset and its load
                     address differ by 0x1000 -- one page of padding
</pre>
                </div>
                <p><strong>The first three segments have <code>vaddr == offset</code> and the fourth does not.</strong> The reason is exactly the reason the segment table could not be written by a compiler: the writable data must start on a page boundary in memory, and the bytes before it in the file are not page-aligned, so a page of padding goes in. <strong>That padding is a decision about layout, made during layout, by something that had to see every input.</strong></p>
                <h3>The section count went up, not down</h3>
                <p>Sixteen sections in, <strong>thirty-one out.</strong> That surprises people who expect a linker to be subtractive, and the additions are the interesting part:</p>
                <div class="hex-dump">
                    <pre>  sections the LINKER created, none of which any
  compiler ever emitted:

    .interp        the path to the dynamic linker
    .dynamic       the table the dynamic linker reads
    .got .got.plt  slots for addresses not yet known
    .plt           stubs for functions not yet callable
    .rela.dyn      relocations the LINKER could not resolve
    .rela.plt      and the ones for the PLT
    .init_array    constructors, in the order to run them
    .fini_array    destructors
    .symtab .strtab .shstrtab   the output's own symbol table
</pre>
                </div>
                <p><strong>The linker is not only filling holes; it is generating structure that did not exist.</strong> A <code>.plt</code> is a code sequence the linker invents. A <code>.got</code> is a table the linker allocates. Those are not sections from the object, moved &mdash; they are new artefacts of the linking process itself, and a static linker creates some of them so the <em>dynamic</em> linker will have them later.</p>
                <p>Which is the honest way to state the division of labour, and it corrects a tidy story that is easy to believe:</p>
                <div class="formula">
  the tidy story (wrong):
      compiler produces sections, linker produces segments,
      so segments are "the linker's table"

  what actually happens:
      the compiler produces sections and holes
      the linker produces addresses, segments, AND more
      sections -- including ones that exist only so the
      RUNTIME linker can do its job later
</div>
                <h3>The relocation table changed shape completely</h3>
                <p>Last measurement, and the one that closes the loop. In the object, four relocations against <code>.text</code>, all against symbols this file does not define. In the executable, <strong>zero relocations against <code>external_fn</code></strong>, because <code>other.o</code> supplied it and the linker resolved them. What survives is a different species entirely:</p>
                <div class="hex-dump">
                    <pre>  $ readelf -rW exe | head -6

    0000000000003e00  R_X86_64_RELATIVE      1120
    0000000000003e08  R_X86_64_RELATIVE      10e0
    0000000000004008  R_X86_64_RELATIVE      4008
    0000000000004018  R_X86_64_RELATIVE      2004
    0000000000003fc0  R_X86_64_GLOB_DAT   __libc_start_main@GLIBC_2.34

  none of these name a symbol defined in this file. RELATIVE
  just says "add the load base to the value already here".
  GLOB_DAT says "ask the dynamic linker for this one".
</pre>
                </div>
                <p><strong>Symbol-relative relocations became base-relative ones.</strong> The linker resolved everything it could against the objects it was given, and what survived is only what genuinely cannot be known until run time &mdash; where a shared library will be mapped, and where libc is. <strong>That transition, from "ask the linker" to "add a base", is the entire difference between a relocatable file and a dynamically-linked one</strong>, and it is why the dynamic relocations are a separate subject from the object ones in this course.</p>
                <p>And COFF and Mach-O agree completely on the absence, which is what makes this a fact about object files rather than about ELF. All three specimens, checked:</p>
                <div class="hex-dump">
                    <pre>  demo_elf.o    ELF program headers:  0
  demo_coff.o   COFF: no base relocations, no directories
  demo_macho.o   Mach-O: ONE LC_SEGMENT_64 -- and its
                 segname field is 16 zero bytes. Unnamed.
                 vmaddr 0x0, vmsize 252, holding all 6
                 sections flat.
</pre>
                </div>
                <p>COFF's spelling is different &mdash; a PE has no segment table at all, because a PE is always a mapped image and its sections carry the virtual addresses directly &mdash; and <strong>Mach-O's is the interesting one, because Mach-O objects <em>do</em> carry an <code>LC_SEGMENT_64</code> command and it is still not a mapping plan.</strong> That command exists, its size is 72 bytes, and its <code>segname</code> field is sixteen zero bytes: one unnamed segment holding all six sections flat, with <code>vmaddr 0x0</code> and <code>vmsize 252</code>. The per-section <code>segname</code> fields still say <code>__TEXT</code> and <code>__DATA</code>, so the section table retains the grouping while the segment command declines to express it. <strong>It is a placeholder with the right shape, and a reader must know not to treat it as one.</strong></p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Why this matters to someone building a compiler, which is where <a href="/courses/obj">this course is going</a>. Consider what a code generator must decide at emit time, and which of those decisions are available:</p>
                <div class="formula">
  a code generator emitting an object file must decide:

    section assignment   which section does this go in?
                         ANSWERABLE. .text for code, .rodata
                         for literals, and so on.

    section ordering     where should .rodata go relative
                         to .data in the output?
                         NOT ANSWERABLE. The linker sorts to
                         satisfy alignment and locality, and
                         may merge them.

    section flags        read-only? writable? executable?
                         PARTIALLY. You can say "this is
                         .rodata" and the linker works out the
                         permissions -- but only because whole
                         sections share a fate.

    addresses            where will it be?
                         NOT ANSWERABLE. Emit relocations.

    permissions per      can this function have a page that
    page                 another function can also write?
                         NOT ANSWERABLE, and you must not try.
</div>
                <p><strong>The last row is the one that produces real bugs.</strong> It is tempting for a code generator to emit a segment table anyway, filled in with a guess, because then the file looks like a proper image and tools display it nicely. The result is a file that <code>readelf</code> renders with a plausible segment table and <code>ld</code> then either rejects or silently discards it, depending on the linker.</p>
                <div class="callout callout-warn">
                    <strong>The trap, stated as a rule.</strong> <em>Do not emit a table you cannot fill in correctly.</em> A zero-filled segment table is worse than an absent one, because its absence is unambiguous to every tool and its presence is a claim. This is the same principle as the JVM course's finding that a <code>Record</code> attribute's <em>presence</em> is the declaration while its content is secondary, and as the ELF course's warning about <code>e_shnum == 0</code> being a sentinel rather than a count. <strong>In every one of these formats, the difference between "absent" and "present but meaningless" is a distinction every reader has to implement, and it is always better to be absent.</strong>
                </div>
                <p>Now the part that surprises people, and it is the practical reason the segment table belongs to the linker. <strong>Permissions are granted per segment, which in practice means per section-group, and that only works because the linker sorts sections into permission groups.</strong> Every <code>.rodata</code> from every object ends up on the same page with the same permissions, because they are all read-only. If a compiler emitted a function needing <em>its own</em> writable page, there would be nowhere to record that, and the segment table would need a per-section concept it does not have.</p>
                <p>That is a real architectural decision with a real cost, and the <a href="/courses/pe">PE format</a> makes the same trade in a different place: a PE is always a mapped image, so it has no segment table <em>and</em> inherits the same constraint, with sections carrying <code>IMAGE_SCN_MEM_READ</code> and friends instead. <strong>One format defers the decision to link time and one makes it at compile time; both end up with page-granularity permissions, because that is what the hardware does.</strong></p>
                <p>And why a <em>dynamic</em> executable has segments at all, while a static one could in principle be laid out by a simpler scheme, is the hinge to the loading courses. <strong>A PIE's segments carry addresses that are not the final addresses</strong> &mdash; the loader maps them somewhere else and adds a base, which is exactly what the surviving <code>R_X86_64_RELATIVE</code> relocations are for. The segment table in the object has no base because the object is not mapped; the segment table in the executable has provisional addresses because the executable is mapped <em>somewhere</em>, just not somewhere final. <strong>One table, two reasons for its addresses to be wrong, and a different mechanism for each.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ readelf -lW demo_elf.o
$ readelf -lW exe | grep -A1 LOAD</code></pre>
                <ul>
                    <li><strong>Reproduce the headline measurement.</strong> <code>readelf -l</code> on the object, then on the executable you build from it. <strong>Zero, then twelve.</strong> Do it for COFF and Mach-O too and confirm the absence is a property of object files rather than of ELF.</li>
                    <li><strong>Find the page of padding and account for it.</strong> The <code>RW</code> segment's file offset and load address differ by <code>0x1000</code>. <strong>Work out which section boundary forced the alignment</strong>, then change the size of one <code>.data</code> object and rebuild &mdash; the padding moves, and understanding exactly which input moved it is the exercise.</li>
                    <li><strong>Count the sections the linker added.</strong> Diff the section names in the object against the executable. <strong>Nine or ten of the executable's sections exist in no object file</strong>, and they are all for the dynamic linker. Write down which of them a static link would not produce.</li>
                    <li><strong>Prove the relocation transformation.</strong> Four symbol-relative relocations in the object, zero against <code>external_fn</code> in the executable, replaced by <code>RELATIVE</code> and <code>GLOB_DAT</code>. <strong>Then add a third object and watch which relocations survive</strong> &mdash; the answer teaches you exactly what "unresolvable at link time" means.</li>
                    <li><strong>Emit a segment table anyway and see what happens.</strong> Take <code>demo_elf.o</code>, hand-build twelve program headers with plausible-looking zeroes, fix every offset, and link it. <strong>Then read the linker's diagnostics carefully</strong> &mdash; and confirm that every tool that reads the file treats the table as a claim rather than as data, which is the whole lesson.</li>
                    <li><strong>Answer the five questions for your own compiler.</strong> Take a code generator you have written or plan to write, and for each of the five rows in the model above, write down what you currently emit and whether the answer is knowable. <strong>The rows you cannot answer are the relocations you have to emit, and the row that looks answerable but is not &mdash; per-page permissions &mdash; is the one that will bite you.</strong></li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: the <code>RW</code> <code>LOAD</code> segment of a linked executable has file offset <code>0x2e00</code> and load address <code>0x3e00</code>, while the three segments before it have <code>vaddr == offset</code>. Why does only the last one differ, and why could a compiler not have written that value even if it had wanted to?</p>
                <div class="quiz" id="quiz-obj-no-segments-1">
                    <button class="quiz-option" data-correct="true" data-explain="The difference is exactly one page, and the reason is that the writable segment has to start on a page boundary in memory while the file bytes before it are not page-aligned. If the loader mapped that data at file offset 0x2e00, the page containing it would also contain the tail of the read-only segment before it, and marking the page writable would make read-only data writable too. So the loader inserts a page of padding in the address space, and the file offset and load address diverge by that amount. The first three segments are page-aligned in the file already, which is why they need no adjustment. A compiler cannot write either value: the load address depends on the total size of everything that lands before this segment, which means every object that contributes any section, plus the alignment padding between them. That is a property of the link, not of this translation unit. The segment table's every field has this shape, which is the general reason it cannot appear in a relocatable file at all." onclick="checkQuiz('obj-no-segments-1', this)">Because the writable segment must start on a page boundary in memory, and the file bytes before it are not aligned &mdash; so a page of padding goes into the address space and the two values diverge. A compiler cannot know it because the load address depends on the total size of everything every other object contributes, which is a property of the link</button>
                    <button class="quiz-option" data-correct="false" data-explain="The arithmetic is noticed but the reason is inverted, and the inverted reason produces a fix that would be actively dangerous. The divergence is not a file-format inconsistency to be tidied up; it is the loader deliberately placing the writable data at a page boundary so it can be given write permission without granting write permission to the read-only data that precedes it in the file. If you normalised the two values so that offset and address agreed again, the writable segment would share a page with read-only content and the permission separation the whole table exists to provide would collapse. So the discrepancy is the mechanism working, not a defect. The deeper point is the same either way: neither number is knowable at compile time, because the address depends on the total size of every section every other object contributes. That is why the table is the linker's to write, and it is worth noticing that the conclusion survives the wrong mechanism." onclick="checkQuiz('obj-no-segments-1', this)">The linker zero-pads the file so the writable data lands on a page boundary, and the compiler could not know the value because it depends on the total size of all preceding sections across every input object, so a tool should treat the offset as authoritative and recompute the address</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a static linker and you decide, for convenience, to emit a program header table into the executable as soon as you have laid out the first few sections &mdash; updating it as you go. It works. On inputs with an unusual section ordering it produces an executable that <code>ld</code> accepts, <code>readelf</code> renders with correct-looking segments, and the kernel refuses to run with <code>permission denied</code>. What is the invariant your incremental approach broke, and what is the general rule for a table whose fields depend on each other?</p>
                <div class="quiz" id="quiz-obj-no-segments-2">
                    <button class="quiz-option" data-correct="true" data-explain="The invariant is that every segment's fields are a function of the final layout of every section in the output, so the table can only be computed once, after layout is complete, and it must be recomputed from scratch if anything moves. Updating it incrementally assumes that laying out later sections cannot change the values already written, and that assumption is false for the specific field that matters: a segment's end offset and size depend on what comes after it, and a later section can grow, get padded to a page boundary, or trigger a merge that moves the boundary. The result is a table that is internally inconsistent in a way no single field reveals, which is why readelf renders it plausibly and the kernel refuses. The general rule is about dependency direction: a table whose entries are functions of a shared, still-changing quantity must be emitted after that quantity is final, never maintained alongside it. This is the same shape as the JVM class file's finding that a Record attribute's presence is the declaration and a sealed class's permitted list is checked at load rather than being trusted at read, and the same shape as the constant pool's rule that an entry's index is only valid once the table stops growing. Incrementally maintained metadata that depends on a whole is a bug waiting for a large enough input." onclick="checkQuiz('obj-no-segments-2', this)">The invariant is that every segment field is a function of the <em>final</em> layout, so the table must be computed once after layout is complete and recomputed from scratch if anything moves &mdash; never maintained incrementally. A table whose entries are functions of a shared, still-changing quantity has to be emitted after that quantity is final</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is a real constraint and it is not what the evidence points to, because the report says the kernel refuses with a permission denial, which is about the permission bits and the page alignment rather than about offsets drifting. A gap between file offset and virtual address is completely normal and expected, as the other three segments in the same executable demonstrate, so a tool that treated a gap as an error would reject almost every real binary. The actual failure is subtler: an incrementally maintained table holds values that were correct at the moment they were written and are not correct now, and the field that goes stale is the one that depends on what follows rather than what precedes. Segments grow at their end, so a segment written early gets its size wrong as soon as anything after it changes. The diagnosis worth acting on is staleness, not the offset/address relationship." onclick="checkQuiz('obj-no-segments-2', this)">The kernel requires each LOAD segment's file offset to be congruent to its virtual address modulo the page size, and incremental writes broke that congruence, so the table must be regenerated in one pass after layout rather than patched as sections are placed</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a table whose entries are functions of a shared, still-changing quantity must be emitted after that quantity is final, never maintained alongside it. Incremental metadata that depends on a whole goes stale silently.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the <a href="/courses/elf/lessons/section-vs-segment">ELF course's sections-versus-segments concept</a> seen from the file that has only one of them, and that is the better order &mdash; because once you have seen a file with no segment table, the two-table model stops looking like a design choice and starts looking like two different questions. The ELF course can then answer "what does a segment do" against a file that demonstrates why it cannot exist yet, which is a much stronger footing than a definition.</p>
                <p>Compare the PE, which made the opposite decision and has a genuinely instructive reason for it. A <a href="/courses/pe">PE is always a mapped image</a> &mdash; there is no such thing as a relocatable PE in the ordinary sense, because a PE's sections carry <code>VirtualAddress</code> and the loader honours them directly. So a PE has no program header table at all, and <a href="/courses/pe/lessons/pe-section-table">its section table does the segment table's job</a>. <strong>ELF supports relocatable files and therefore needs two tables; PE does not, and therefore needs one.</strong> That is the cleanest available demonstration that a format's table count follows from its requirements rather than from taste.</p>
                <p>The page-alignment padding connects to something with teeth in the security courses. <a href="/courses/pe/lessons/pe-security-flags">A segment's permissions are a security boundary</a> precisely because the hardware enforces them per page &mdash; and the padding is what makes that boundary land correctly. <strong>An R E segment means "this page is executable and not writable", and W^X is only meaningful because a page is the unit.</strong> Move to a byte-granular architecture and the entire model changes, which is a fact the <em>Memory Hierarchy</em> course in the architecture section will make concrete when it reaches page tables and TLBs.</p>
                <p>The linker-generated sections are the bridge to the rest of the linking half of the chain, and it is worth naming the dependency explicitly. A <code>.plt</code> and a <code>.got</code> exist because a call to a function in a shared library cannot be resolved at link time &mdash; so the linker emits a stub and a table, and the dynamic linker fills them in later. <strong>That is <a href="/courses/elf/lessons/shared-libraries">dynamic linking</a>, and it is the reason the linker is a program rather than a file filter.</strong> An object file is where the dynamic linker begins, and this concept is the last of the four that explains why the object file is shaped the way it is.</p>
                <p>Two smaller connections worth keeping. The surviving <code>R_X86_64_RELATIVE</code> relocations in the executable are the same records with a different question &mdash; <a href="/courses/elf/lessons/dynamic-relocations">the dynamic relocation set</a> is not a new format but a new set of answers to the same four questions from the <a href="/courses/obj/lessons/obj-the-hole">second concept</a>, with "whom" replaced by "the load base". And the <code>e_type</code> field, which reads <code>REL</code> here and <code>DYN</code> in the executable, is a one-value enum whose whole job is to tell a reader which of the two models applies &mdash; which is the same trick as the JVM's <code>ACC_ENUM</code> and the same reminder that a format needs one bit to say which world it is in.</p>
                <p>That closes Module 1. The object file is now a known thing: what it is for, what a hole is, that three formats agree on the mechanism and differ on everything else, and why one of its two tables is necessarily absent. <strong>Module 2 opens the file up &mdash; the section and symbol tables compared field by field, where the three formats disagree most and where a tool author has the most to get wrong.</strong></p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-triangulate">Previous: One Source, Three Formats</a></span>
                <span>Next: Module 2: Anatomy, Compared</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
