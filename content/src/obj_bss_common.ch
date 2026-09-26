// Object Files — Module 2: Anatomy, Compared
// Concept: COMMON, tentative definitions, three encodings of one C rule, and the
// GCC 9 to 10 break that broke every Linux package.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_obj_bss_common() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("COMMON and the ABI Break — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson obj-lesson">
            <a href="/courses/obj" class="back-link">Back to course</a>
            <h1>COMMON and the ABI Break</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Anatomy, Compared &middot; Intermediate</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>One line of C is about to cost you an afternoon, and it is the shortest declaration in the language:</p>
                <div class="formula">
  int tentative;
</div>
                <p>No initialiser. No <code>extern</code>. No storage class. The C standard says this is a <strong>tentative definition</strong>, and it also says what happens when two translation units both write it: <strong>one definition wins, every reference resolves to it, and all of them are zero-initialised.</strong> The language answers the question. The question is how a file format expresses an answer that says &quot;somebody, somewhere, not necessarily me, is holding four bytes of zeroes, and here is how big they are and how aligned they must be&quot;.</p>
                <p>Three formats answer it three ways, and <strong>the history of one compiler flag changing its default in 2019 broke essentially every prebuilt Linux package in the world.</strong> That is not a metaphor; it is a well-documented incident, and the mechanism behind it is a single bit in a symbol table. This concept is about that bit, and about a field that does not mean what it looks like it means.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>First, the ordinary case, because the interesting case only makes sense against it. There are two different things a declaration can mean:</p>
                <div class="formula">
  int initialised = 5;      a DEFINITION. 4 bytes, value 5,
                            known at compile time, goes in .data

  int tentative;            a TENTATIVE DEFINITION. 4 bytes,
                            value 0, not known to be unique --
                            another file may also define it
</div>
                <p>Both end up as four bytes somewhere. <strong>The difference is not the bytes, it is the promise.</strong> A definition says &quot;this is the one and only copy&quot;. A tentative definition says &quot;if nobody else provides one, I will be it, and we will merge if they do too.&quot;</p>
                <p>A format can express that in three ways, and all three do:</p>
                <ul>
                    <li><strong>Give it a section.</strong> Put it in <code>.bss</code> and mark it global. A real definition in another file is then a <em>duplicate symbol</em> and the link fails &mdash; which is wrong, because C says merge.</li>
                    <li><strong>Give it a special section index and a size.</strong> This is ELF's <code>SHN_COMMON</code>. The symbol is not in a section; it is a standing request for the linker to allocate <code>st_size</code> bytes at <code>st_value</code> alignment.</li>
                    <li><strong>Give it a section that exists only to hold such requests.</strong> This is Mach-O's <code>__common</code>, a <code>ZeroFill</code> section with no file bytes.</li>
                </ul>
                <p>The second is the one with the trap, and it is worth stating the trap before the measurement because <strong>it is a field that does not mean what it means.</strong></p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>One source file, three words, compiled five ways on this machine. The source is:</p>
                <div class="hex-dump">
                    <pre>  int tentative;             /* tentative definition */
  int initialised = 5;       /* real definition       */
  int main(void)      -- returns tentative + initialised
</pre>
                </div>
                <p>And here is every difference between them, measured with <code>readelf -s</code> and <code>llvm-nm</code>:</p>
                <div class="hex-dump">
                    <pre>                    tentative              initialised
  build             Ndx  Val  Size  Type       Ndx  Val  Type
  ----------------  ---  ---  ----  --------  ---  ---  --------
  clang -fno-common   5    0     4  B (.bss)      4    0  D (.data)
  clang -fcommon    COM    4     4  C (COMMON)   4    0  D (.data)
  gcc (default)      5    0     4  B (.bss)      4    0  D (.data)
  COFF               ?    0     4  B            4    0  D
  Mach-O           0x60    -     4  S (__common) 0x1c  -  D
</pre>
                </div>
                <p>Four findings, and the first is the one that will cost you an afternoon.</p>
                <h3>st_value is 4, and it is not an address</h3>
                <p>Look at the COMMON row. <code>Value = 4</code>. <strong>That is not an offset and not an address &mdash; it is the required <em>alignment</em>.</strong> A COMMON symbol has no section and no position, so ELF repurposes the <code>st_value</code> field to hold the alignment the linker must give the allocation, and puts the size in <code>st_size</code>.</p>
                <div class="callout callout-warn">
                    <strong>This is the only symbol in the format whose <code>Value</code> field does not contain a value.</strong> A reader that adds a section base to it, or treats it as an offset into a COMMON section, gets a number that is meaningless. And note what the two rows above it show: for <code>.bss</code> the value is 0, for COMMON it is 4, and <strong>both mean "position 0 of a 4-byte object"</strong> to a human reading the file. The difference is invisible unless you know that one of them is an alignment. This is the same species of bug as the Mach-O provisional-address finding, one level deeper: <strong>a field whose meaning depends on a neighbouring field, which depends on a section index whose meaning is a special case.</strong>
                </div>
                <h3>With -fcommon there is no .bss section at all</h3>
                <p>The section lists are the proof, and they are the whole story of what COMMON buys:</p>
                <div class="hex-dump">
                    <pre>  clang -fno-common:  .strtab .text .rela.text .data .bss
                      .comment .note.GNU-stack .eh_frame
                      .rela.eh_frame .llvm_addrsig .symtab
                                                 ^^^^^ an 11-section file

  clang -fcommon:     .strtab .text .rela.text .data
                      .comment .note.GNU-stack .eh_frame
                      .rela.eh_frame .llvm_addrsig .symtab
                                                .bss is GONE
                      1240 bytes vs 1312. 72 bytes smaller.
</pre>
                </div>
                <p><strong>The file is 72 bytes smaller because the section header that would have described <code>.bss</code> is not emitted at all.</strong> A COMMON symbol needs no section to live in, so no section is created; the linker invents a <code>.bss</code>-shaped region in the output once it has merged every COMMON symbol it collected.</p>
                <p>And that merge is the entire point. The linker's rule is: <strong>collect every COMMON symbol of a given name, allocate the largest requested size at the strictest requested alignment, and point every reference at that one allocation.</strong> A <code>.bss</code>-based tentative definition cannot do that, because it is already inside a section with a fixed size &mdash; so two files each declaring <code>int tentative;</code> produce two symbols in the same <code>.bss</code> and the link fails with a duplicate-symbol error.</p>
                <h3>Mach-O solved it with a real section</h3>
                <p>Mach-O's <code>__common</code> is the third approach and it is the most literal: a real section, of type <code>S_ZEROFILL</code> (<code>flags = 0x1</code>), with <code>size 4</code> and <code>offset 0</code>, at address <code>0x60</code>. The symbol is a normal symbol in a normal section &mdash; <code>nm</code> shows it at <code>0x60</code> &mdash; and the section exists so the symbol has somewhere to point.</p>
                <div class="hex-dump">
                    <pre>  Mach-O tentative definition:

    __common  addr=0x60  size=4  offset=0  align=2  flags=0x00000001

    offset = 0 AND size = 4: four bytes of memory that
    occupy no bytes of file. Same idea as .bss, but reached
    by making a section out of the concept rather than
    putting the concept in a section.
</pre>
                </div>
                <p>So three mechanisms for one C rule, and the honest ranking by how much machinery each needs. <strong>ELF's <code>SHN_COMMON</code> is the cheapest in the file</strong> (no section at all, and the field reuse is a genuine trick) <strong>and the most expensive in the reader</strong>, because it turns <code>st_value</code> into a second thing depending on <code>st_shndx</code>. <strong>Mach-O's <code>__common</code> is the most expensive in the file and the cheapest in the reader</strong>, because a symbol in a section means what it always means. <strong>COFF sits in between</strong>, using a storage class rather than a special section index, and inheriting the same "one field, two jobs" problem as the previous concept found.</p>
                <h3>What -fcommon actually changed in 2019</h3>
                <p>Here is the incident, and it is worth telling precisely because it is the strongest available argument for the mission's "verify, do not assume" rule.</p>
                <div class="formula">
  GCC 9 and earlier:  -fcommon was the DEFAULT
  GCC 10 and later:   -fno-common became the default

  a library built with GCC 9:   lib.a   &lt;- symbols marked COMMON
  an application built with GCC 10:  o.o   &lt;- symbols in .bss

  linking them:
      o.o's .bss tentative definition  vs  lib.a's COMMON
      -> "duplicate symbol" error
      -> the application does not build
</div>
                <p><strong>Every prebuilt C library on a Linux distribution, and every application linking against one, broke.</strong> Distributions fixed it by rebuilding everything with matching flags, and the lasting change was that <code>-fcommon</code> became something you opt into rather than something you inherit.</p>
                <p>Now the interesting part for a format designer. <strong>Neither behaviour is a bug and neither is the standard.</strong> C permits a translation unit to treat a tentative definition as a definition, so <code>-fno-common</code> is conforming; it permits merging, so <code>-fcommon</code> is conforming too. The two disagree about whether two tentative definitions in different files are the same object or a conflict &mdash; <strong>a question the C standard arguably leaves open, and which the two flags answer differently.</strong> So the ABI break was not a compiler bug. It was two toolschains answering an underspecified question differently, and <strong>the file format had no way to make them interoperate because the format faithfully recorded a decision each side made locally.</strong></p>
                <div class="callout">
                    <strong>The general lesson, which is about formats rather than about C.</strong> When two producers of the same format disagree about a <em>semantic</em> question, the format cannot fix it &mdash; it can only record the answer faithfully, and then a consumer has no way to tell that two records mean incompatible things. ELF's answer to that is the <code>.gnu.linkonce</code> and section-group mechanisms, which exist to let a producer say "these definitions may be merged" <em>without</em> adopting the whole COMMON convention. <strong>A format that wants to survive disagreement has to give producers a way to record the disagreement, not just a way to record agreement.</strong> That is a design requirement, and it is the same reason the class file's attribute mechanism exists.
                </div>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>What a linker actually does with each of the three, because the reason COMMON exists is a scheduling problem rather than a semantic one:</p>
                <div class="formula">
  the problem:  file A says  int buf[1000];   file B says int buf[8];
                both tentative. Who allocates what?

  ELF COMMON:   the linker collects every COMMON symbol by name,
                takes the MAX size and the MAX alignment, allocates
                once, and rewrites all references. The output gets
                a .bss-like region sized to the largest request.

  ELF .bss:     each file allocated its own, in its own section.
                A second tentative definition is a DUPLICATE and
                the link fails. Correct, and incompatible.

  Mach-O:       a real __common section exists, so the merge can
                happen the ordinary way -- but the linker still has
                to recognise these as mergeable, so the
                compatibility problem is the same one, hidden
                behind a section that looks like ordinary data.
</div>
                <p><strong>So all three converge on the same linker algorithm, and the difference is purely how much the file has to say about it.</strong> That is the useful way to hold the concept: COMMON is not a different kind of storage, it is <em>deferred</em> storage, and the format's job is to represent "I have not been allocated yet" in a way that survives round-tripping through a file.</p>
                <p>The related trap is worth naming because it catches people building tools rather than linkers. <strong>A <code>.bss</code> section has a nonzero size and occupies zero file bytes</strong> &mdash; measured in the previous concept on both COFF's <code>.bss</code> and Mach-O's <code>__common</code> &mdash; and a reader that copies <code>size</code> bytes from <code>offset</code> writes zeroes over whatever follows. For <code>.bss</code> the offset is 0 and the section is not in the file at all, so the copy reads the ELF header. The rule is simple and worth stating as a check: <strong>a section with a nonzero size and a zero offset contributes nothing to the output file</strong>, and that is a valid, common, load-bearing case rather than a malformed one.</p>
                <p>And the reason this matters to a code generator, which is where <a href="/courses/obj">this course is going</a>. <strong>Emitting a tentative definition is a decision with an interoperability consequence, and the compiler made it for you by default.</strong> A code generator that always emits <code>.bss</code> produces objects that cannot link against libraries built by a <code>-fcommon</code> toolchain. A generator that always emits COMMON produces objects of a kind most modern toolchains do not produce. <strong>Neither is safe by default, and the flag exists because the choice has to be made somewhere &mdash; so it is a decision your backend has to be able to make, and document.</strong></p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang -target x86_64-pc-linux-gnu -O0 -c -o a.o tent.c
$ clang -target x86_64-pc-linux-gnu -O0 -fcommon -c -o b.o tent.c
$ readelf -sW a.o | grep tentative
$ readelf -sW b.o | grep tentative</code></pre>
                <ul>
                    <li><strong>Reproduce the whole table.</strong> Five builds, three formats, and read <code>tentative</code> out of each. <strong>Then confirm the section lists differ</strong> &mdash; that <code>.bss</code> exists in one ELF and not the other &mdash; and that the file is 72 bytes smaller for exactly that reason. The size difference is the cleanest possible evidence that a section header is being skipped.</li>
                    <li><strong>Read <code>st_value = 4</code> and say what it is.</strong> Then read <code>st_value = 0</code> from the <code>.bss</code> build of the same declaration. <strong>Both are "position 0 of a 4-byte object" to a human, and only one is an offset.</strong> Write down the predicate a correct reader needs, and check that it keys on <code>st_shndx</code> rather than on the value.</li>
                    <li><strong>Trigger the duplicate and watch it fail.</strong> Compile <code>tent.c</code> twice with <code>-fno-common</code> into different object names, then link them. <strong>Read the error message as a specification</strong> &mdash; it names the symbol and both objects &mdash; and then compile one with <code>-fcommon</code> and link again to see it succeed. That is the 2019 incident, reproducible in ninety seconds.</li>
                    <li><strong>Build the merge yourself.</strong> Three files, each declaring <code>int shared[N]</code> tentatively with different <em>N</em>. <strong>Link with <code>-fcommon</code> and check the size of the resulting <code>.bss</code></strong> &mdash; it should be the largest request, not the sum. Then work out how a linker would have to compute that, which is the whole algorithm.</li>
                    <li><strong>Find the Mach-O <code>__common</code> section's flags.</strong> <code>flags = 0x00000001</code>, which is <code>S_ZEROFILL</code>. <strong>Compare it against <code>__cstring</code>'s <code>0x00000002</code></strong> and account for the difference. Then ask whether you could tell the two apart from their offsets alone &mdash; both are 0 &mdash; and what that implies for a reader that only looks at offset and size.</li>
                    <li><strong>Write the <code>.bss</code> copy bug on purpose.</strong> Take a reader that copies <code>size</code> bytes from <code>offset</code> and run it on a file with a <code>.bss</code> section. <strong>Confirm it reads from file offset 0</strong> &mdash; the ELF header &mdash; and then add the guard that every correct reader needs: a section with a nonzero size and a zero offset contributes nothing. It is three lines and it prevents writing zeroes over your own headers.</li>
                    <li><strong>Check what your compiler does today.</strong> <code>echo 'int t;' | cc -x c -c -o - - 2&gt;/dev/null | nm</code> &mdash; or the equivalent for your toolchain. <strong>Find out which default you are getting and when it changed</strong>, because the honest answer is that the default is a compatibility decision, not a correctness one, and a code generator author has to make the same decision deliberately.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an ELF symbol has <code>st_shndx = COM</code>, <code>st_value = 4</code> and <code>st_size = 8</code>. Another has <code>st_shndx = 5</code>, <code>st_value = 0</code> and <code>st_size = 8</code>. What does <code>st_value = 4</code> mean in the first, what does it mean in the second, and what does a reader that adds a section base to the first one produce?</p>
                <div class="quiz" id="quiz-obj-bss-common-1">
                    <button class="quiz-option" data-correct="true" data-explain="In the first, st_value is an alignment, because a COMMON symbol is not in any section and so has no position to record; ELF repurposes the field so the linker knows how strictly to align the allocation it will make, with the size in st_size. In the second, st_value is 0 because the symbol is the first four bytes of a real section, index 5, and 0 is a perfectly ordinary offset. So the same field holds two different kinds of quantity and the only thing that tells them apart is st_shndx. A reader that adds a section base to the first one produces a number that means nothing at all, and specifically it produces a plausible address rather than an obviously broken one, which is the dangerous part. The deeper point is about how this kind of field works: its meaning is a function of a neighbouring field, which is itself a function of a section index whose reserved value is the special case. That is a three-level dependency, and it is why the format is cheaper in the file and more expensive in the reader. A linker that mishandles it will usually produce a binary that loads and then reads the wrong memory, because the allocation still happens and the size is still honoured, just at an address derived from a number that never meant an address." onclick="checkQuiz('obj-bss-common-1', this)">In the COMMON case <code>st_value = 4</code> is the required <strong>alignment</strong> &mdash; the symbol is in no section, so the field carries alignment and <code>st_size</code> carries the size. In the <code>.bss</code> case it is an ordinary offset, 0. A reader that adds a section base to the COMMON one produces a plausible-looking address that means nothing, and the only thing that distinguishes the two is <code>st_shndx</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="The identification of the two symbol kinds is right, so the disagreement is about the meaning of the field, and getting that wrong produces a fix that cannot work. If st_value were an address in the COMMON case then COMMON would be a section, and the whole point of the mechanism would be gone: it exists precisely so the file does not have to create a section for a definition that might turn out to be a duplicate. The file that has st_shndx = COM has no .bss section at all, which is measurable and is why the -fcommon build is 72 bytes smaller. So there is no section whose base could be added, and the field cannot be an address into nothing. The other half of this answer is right and worth keeping: the field's meaning depends on st_shndx, and a reader must branch on that. What is wrong is only the claim that both values mean position zero, which would make the two rows indistinguishable and would leave the -fno-common build's alignment information with nowhere to live." onclick="checkQuiz('obj-bss-common-1', this)">Both are offsets: the COMMON symbol is placed at offset 4 of a synthesised common section, and the <code>.bss</code> one at offset 0, so a reader that adds a section base to the first lands 4 bytes past the start of the wrong region</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a code generator, and you have a linker bug report: a program links cleanly but reads the wrong value from a global that its own translation unit declared with no initialiser. Your object puts the symbol in <code>.bss</code> with <code>st_value = 0</code>. A library object in the same link has the same symbol with <code>st_shndx = COM</code> and <code>st_value = 8</code>. The linker's merge output gives your symbol 8 bytes of storage. What did your generator do differently from the library's, and what is the one-line change that makes your objects link against both kinds?</p>
                <div class="quiz" id="quiz-obj-bss-common-2">
                    <button class="quiz-option" data-correct="true" data-explain="The two objects took different branches of the same C question. Yours treated the tentative definition as a definition and allocated it in a real .bss section; the library's recorded a mergeable request with no section at all, where st_value carries alignment rather than a position. The linker's merge allocated 8 bytes because that is the largest size any participant asked for, and then your .bss symbol was expected to live inside that allocation. The fact that it does not is what produces the wrong read: the linker believed both symbols referred to the same storage, and one of them names storage that was never part of the allocation. The fix is to emit the tentative definition as SHN_COMMON with st_size set to the type's size and st_value set to the type's required alignment, which is what the library's object did. One line of intent, and it makes your objects compatible with both conventions rather than only with your own toolchain. The wider point is that a code generator inherits whatever its compiler's default was, and the 2019 break happened because two toolchains inherited different defaults and the format faithfully recorded both. If your generator has to interoperate with objects it did not produce, that default is now your decision to make explicitly and to document, because no flag will make the decision for you." onclick="checkQuiz('obj-bss-common-2', this)">Your generator put the tentative definition in a real <code>.bss</code> section, treating it as a definition; the library recorded a mergeable request with no section. Emit it as <code>SHN_COMMON</code> with <code>st_size</code> set to the type's size and <code>st_value</code> set to its required alignment &mdash; then your objects link against both conventions</button>
                    <button class="quiz-option" data-correct="false" data-explain="The diagnosis is a real hazard and the evidence points away from it, because the report says the link succeeded and the allocation came out at 8 bytes, which is exactly what the merge algorithm should produce from a 4-byte and an 8-byte request. If the storage were static and per-file, the linker would have no reason to honour the larger participant's size at all, and the resulting allocation would be 4 bytes rather than 8. The 8 is evidence that the COMMON path was taken and worked. What went wrong is the mismatch between two conventions rather than a failure of either, and that distinction matters because it decides the fix. A static-storage theory sends you looking for an allocator problem; the correct reading sends you to a symbol-representation problem, which is a one-line change in your emitter rather than a redesign of your memory model. The other half of this answer is right and worth keeping, since the alignment field genuinely is a hazard once the symbol is COMMON, but it is downstream of the decision being asked about here." onclick="checkQuiz('obj-bss-common-2', this)">Your generator allocates tentative definitions in its own static storage per object, while the library's are merged by the linker, so the two disagree about where the four bytes live. Make the generator emit its tentative definitions as COMMON symbols so both go through the same merge</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a code generator inherits whatever its compiler's default was, and defaults are compatibility decisions rather than correctness ones. If your objects must interoperate with objects you did not produce, that decision is now yours to make explicitly &mdash; and to document.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>COMMON is the clearest case in the whole course of <strong>a semantic decision that has to travel through a file</strong>, and the <a href="/courses/elf">ELF course</a> teaches <code>.bss</code> and the common sections as features. What this concept adds is the <em>why they are optional</em> &mdash; that the format has a representation for "not allocated yet" and that using it or not is a choice with observable consequences. That is the difference between learning a format and understanding what it is for.</p>
                <p>The 2019 break connects to something structural about the platform rather than about C. <strong>A distribution ships prebuilt libraries and expects applications to link against them</strong>, which means the libraries' object-file conventions become a published interface whether or not anyone meant them to. The same mechanism appears in the <a href="/courses/pe">PE world</a> with C runtime libraries and in the <a href="/courses/macho">Mach-O world</a> with the C++ standard library's ABI, and it is the reason <a href="/courses/elf/lessons/symbol-table">symbol visibility</a> and weak symbols exist as separate concepts. <strong>A tentative definition is a weak definition in all but name, and both mechanisms exist so that two files can agree to share storage without either having to know the other exists.</strong></p>
                <p>That last point makes COMMON the natural on-ramp to the rest of Module 4, and specifically to weak and undefined-weak symbols. The rule is the same in both: <strong>a symbol may be defined in several places, and exactly one definition wins, and everybody gets it.</strong> The mechanisms differ &mdash; COMMON carries a size and an alignment and is merged by a sum-like rule, while a weak definition carries no size and is simply chosen &mdash; but the intent is identical, and a reader who has internalised the COMMON case has most of what it takes to implement the weak case.</p>
                <p>On the byte-count side, this concept is the third appearance of "nonzero size, zero offset means no file bytes", after COFF's <code>.bss</code> and Mach-O's <code>__common</code> in the sections concept. <strong>Three sightings of one pattern, in three formats, and the rule a reader needs is a single line:</strong> a section with a nonzero size and a zero offset contributes nothing to the output. It keeps coming back because it is the one case where size and offset describe different things &mdash; memory and file &mdash; and a reader that assumes they are the same quantity writes zeroes over the ELF header. That assumption is the kind that looks reasonable in code review and is invisible in testing, which is why it is worth stating as a check rather than a caveat.</p>
                <p>And the meta-lesson, which is the one this course is built to teach. <strong>A format can only record a decision faithfully; it cannot make two producers make the same one.</strong> ELF gave producers two sound ways to say "these definitions merge" &mdash; <code>SHN_COMMON</code> and the <code>.gnu.linkonce</code> section-group mechanism &mdash; and the 2019 break still happened, because nothing in the format says that <code>.bss</code> and COMMON mean incompatible things. <strong>When you design a format, ask what happens when two correct producers disagree, and make sure the answer is not "silently, forever".</strong> That is the same question the JVM course's attribute mechanism answers by letting a new attribute be skipped rather than misread, and it is why <a href="/courses/jvm/lessons/jvm-attributes">skipping unknown attributes</a> is a safety property and not merely a convenience.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/obj/lessons/obj-symbols">Previous: Symbol Tables, Compared</a></span>
                <span>Next: Module 3: The Fixup</span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
