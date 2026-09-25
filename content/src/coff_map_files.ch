// COFF Course — Module 4: The Link
// Concept: the linker's map file — a plain-text transcript of every decision the
// link made, including the ones that removed things.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_map_files() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Map Files — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Map Files</h1>
            <div class="lesson-meta">18 min &middot; Module 4: The Link &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>A linker makes hundreds of decisions that nothing in the output file records. Which object contributed which bytes to <code>.text</code>. How much padding was inserted between two functions, and why. Which of two identical COMDAT copies survived. Which input sections were thrown away. Whether the code grew because you added an instruction or because the linker inserted 200 bytes of alignment filler.</p>
                <p>None of that is recoverable from the image. The output knows <em>what</em> the code is; it does not know <em>where it came from</em>. So a linker that wants to be debuggable writes a map file: a plain-text transcript of the link, in the order the decisions were made.</p>
                <p>This is the highest-value debugging artifact most people never open. Not because it is hard, but because the failure it explains &mdash; "this got 400 bytes bigger and I only added one line" &mdash; looks exactly like a compiler bug, and no amount of reading the disassembly will tell you that 380 of those bytes are filler inserted to satisfy an alignment rule.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>A map file has three parts, and the order is the point:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Part</th><th scope="col">Answers</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Discarded input sections</td><td>What did <em>not</em> make it in, and from which object</td></tr>
                        <tr><td>Memory configuration</td><td>What address space is available to place things in</td></tr>
                        <tr><td>Linker script and memory map</td><td>What was placed where, which input section supplied each run of bytes, and what filler went in between</td></tr>
                    </tbody>
                </table>
                <p>Discards come <strong>first</strong> because discarding is what happens first. A section that will not be placed must not consume address space, so the linker has to know the discard set before it can assign addresses. A map file that listed discards last would be describing a process that does not match the real one, and would imply that a discarded section's size affects the layout. It does not.</p>
                <p>One honest caveat before the evidence, because it affects how you should read the rest of this concept. The map file shipped with this course was produced by <strong>GNU <code>ld</code> in its PE emulation mode</strong>, not by Microsoft's <code>link.exe</code>. The three-part structure, the discard list, the placement rows with per-input-section attribution, and the explicit <code>*fill*</code> rows are all general linker behaviour and all observed below. The exact spelling of the linker-defined symbols and the presence of a linker-script preamble are this linker's dialect. Read the concepts; do not expect Microsoft's word-for-word output to match.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>343 lines for a two-file program. The three parts in order:</p>
                <pre><code>$ ld --oformat pei-i386 -m i386pe link_prog.obj link_lib.obj \
      -o link_prog.exe --entry entry -Map link_prog.map

Discarded input sections

 .debug$S       0x00000000       0x5c link_prog.obj
 .llvm_addrsig  0x00000000        0x2 link_prog.obj
 .debug$S       0x00000000       0x5c link_lib.obj
 .llvm_addrsig  0x00000000        0x0 link_lib.obj
 .reloc         0x00000000        0x0 dll stuff

Memory Configuration

Name             Origin             Length             Attributes
*default*        0x00000000         0xffffffff
</code></pre>
                <p>Each discard row is <em>name, address, size, object</em>. The address is <code>0x00000000</code> for all of them, and that is not a formatting quirk &mdash; it is the proof that these sections were never placed. A section that was placed has a real address; a section that was discarded never got one. The map is stating the outcome in the same four fields the section table uses, and all of them say "nothing happened to this".</p>
                <p>The <code>.reloc</code> row attributed to <code>dll stuff</code> is an artefact of this linker supplying its own synthetic input. It has a zero-length <code>.reloc</code> section, so the row exists and is empty. A map file is a record of what the linker was given, including inputs that contributed nothing.</p>
                <h3>Part two: the address space</h3>
                <p>One region, the entire 32-bit space, marked <code>*default*</code>:</p>
                <div class="hex-dump">
                    <pre>Name             Origin             Length             Attributes
*default*        0x00000000         0xffffffff
</pre>
                </div>
                <p>No attributes means no restriction beyond that one. A link script can carve the space into named regions with permissions &mdash; that is what an embedded linker's script does, and it is why a map file from one looks nothing like a map file from a desktop linker. The desktop case has nothing to say about the address space, so it says nothing.</p>
                <h3>Part three, first: the linker-defined symbols</h3>
                <p>Before any section, the map lists the symbols the linker itself provides. These are the values that end up in the PE optional header:</p>
                <div class="hex-dump">
                    <pre>                0x00400000          __image_base__ = 0x400000
                0x00000000          __dll__ = 0x0
                0x00400000          ___ImageBase = 0x400000
                0x00001000          __section_alignment__ = 0x1000
                0x00000200          __file_alignment__ = 0x200
                0x00000004          __major_os_version__ = 4
                0x00000003          __subsystem__ = 3
                0x00200000          __size_of_stack_reserve__ = 0x200000
                0x00001000          __size_of_stack_commit__ = 0x1000
                0x00100000          __size_of_heap_reserve__ = 0x100000
                0x00001000          __size_of_heap_commit__ = 0x1000
                0x00000000          __loader_flags__ = 0x0
                0x00000000          __dll_characteristics__ = 0x0
</pre>
                </div>
                <p>This block is a free gift for a course about the PE header, because every one of those names is a field you decoded in the <a href="/courses/pe">PE course</a> &mdash; and the map tells you the values <em>before</em> you go looking for them in the binary. <code>__section_alignment__ = 0x1000</code> is the <code>SectionAlignment</code> you read at <code>0x1000</code>; <code>__file_alignment__ = 0x200</code> is the <code>FileAlignment</code>; <code>__subsystem__ = 3</code> is the console subsystem that made <code>file</code> report "console". The names use linker conventions and the fields use PE conventions, which is a small translation step that the map makes unnecessary.</p>
                <p>One detail worth catching: the values on the left of the <code>=</code> are <em>addresses</em> and the values on the right are the constants. <code>__image_base__</code> has address <code>0x400000</code> and value <code>0x400000</code> &mdash; a coincidence, since it sits at the base. <code>__size_of_stack_reserve__</code> has address <code>0x200000</code> and value <code>0x200000</code> &mdash; also a coincidence, and a misleading one. Read the right-hand column. These are not addresses; they are the header fields, and the left column is where the linker recorded them.</p>
                <h3>Part three, second: placement, and the filler you did not write</h3>
                <p>This is where the map earns its keep. The COMDAT example from the next concept, whose map is the most instructive file in this course:</p>
                <div class="hex-dump">
                    <pre>  .text           0x00401000      0x200
   *(SORT_NONE(.init))
   *(.text)
   .text          0x00401000       0x15 comdat_a.obj
                  0x00401000                ?use_a@@YAHXZ
   *fill*         0x00401015        0xb
   .text          0x00401020        0xc comdat_a.obj
                  0x00401020                ?shared@@YAHH@Z
   *fill*         0x0040102c        0x4
   .text          0x00401030       0x15 comdat_b.obj
                  0x00401030                ?use_b@@YAHXZ
</pre>
                </div>
                <p>Read it as a sentence. Output section <code>.text</code> starts at <code>0x401000</code> and is <code>0x200</code> bytes. Here is how it is filled. First <code>comdat_a.obj</code>'s <code>0x15</code> bytes at <code>0x401000</code>, which contain <code>?use_a</code>. Then <strong>11 bytes of filler</strong> at <code>0x401015</code>. Then <code>comdat_a.obj</code>'s <code>0xc</code> bytes at <code>0x401020</code>, which contain <code>?shared</code>. Then <strong>4 bytes of filler</strong> at <code>0x40102c</code>. Then <code>comdat_b.obj</code>'s <code>0x15</code> bytes at <code>0x401030</code>, containing <code>?use_b</code>.</p>
                <p>Now count, and the arithmetic that never appears in the disassembly:</p>
                <div class="formula">
?use_a   in comdat_a.obj   0x15 = 21 bytes
filler to reach 16-byte alignment  0x0b = 11 bytes
?shared  in comdat_a.obj   0x0c = 12 bytes
filler to reach 16-byte alignment  0x04 =  4 bytes
?use_b   in comdat_b.obj   0x15 = 21 bytes
                                 ------
total in the image                 69 bytes
of which you wrote                 54 bytes
of which the linker added          15 bytes
</div>
                <p>Fifteen of sixty-nine bytes &mdash; more than a fifth of the code &mdash; is padding this linker inserted. The alignment rule is the <code>0x10</code> in the characteristics from Module 1: the COMDAT <code>.text</code> carries <code>IMAGE_SCN_ALIGN_16BYTES</code>, so its output address must be a multiple of 16. <code>0x401015</code> is not, so the linker skipped forward to <code>0x401020</code>. The bytes it skipped are <em>not</em> zero &mdash; they are whatever fill pattern the linker chose, and the map records them by name rather than by value.</p>
                <p>And notice what is <strong>missing</strong>. <code>comdat_b.obj</code> contributed <code>?use_b</code> at <code>0x401030</code> and nothing else. Its <code>0xc</code>-byte copy of <code>?shared</code> is not in the placement list, because it was discarded. The map shows you a section that exists in an input file, is not in the output, and is not filler &mdash; and the discard list at the top of the same file names it. The two halves of the map are only readable together.</p>
                <h3>The other kind of filler</h3>
                <p>Compare the output section's declared size with the bytes actually attributed to it. <code>.text</code> is declared <code>0x200</code> = 512 bytes, but the rows above account for 69. The gap is because <code>.text</code> was rounded up to the <code>0x200</code> file alignment as well as the section alignment &mdash; the last section in a segment is padded so the next file position is aligned for reading. <code>llvm-readobj</code> reports <code>.text</code>'s <code>VirtualSize</code> as <code>0x61</code>, which is the real content length. The map's <code>0x200</code> is the allocated size. Three different numbers for one section, all correct, all answering different questions &mdash; which is the single best argument for reading a map file when a size does not match your expectation.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>The question a map file is actually for: <em>why is my binary bigger than my code?</em> Here is the method, and it is worth doing by hand once so the reflex is there.</p>
                <ol>
                    <li><strong>Measure the object.</strong> The sum of the <code>SizeOfRawData</code> of every input section that is <em>not</em> in the discard list is the bytes your program actually contains. From the parser shipped with this course: <code>comdat_a.obj</code> contributes 21 + 12 bytes of <code>.text</code>, <code>comdat_b.obj</code> contributes 21 bytes of <code>.text</code> (its 12-byte COMDAT is discarded). Total 54.</li>
                    <li><strong>Read the placement rows.</strong> Add every <code>*fill*</code> row. 11 + 4 = 15.</li>
                    <li><strong>The difference is alignment.</strong> 54 + 15 = 69 bytes of <code>.text</code> content, against a declared <code>0x200</code>. The remaining 443 is the file-alignment padding on the section's tail.</li>
                    <li><strong>Now you can answer the question.</strong> If the answer is "the code is 54 bytes and the linker made it 512", you know that shrinking your code by 10 bytes will change nothing, and that the only lever is alignment &mdash; either a coarser alignment for that COMDAT, or fewer separately-aligned items.</li>
                </ol>
                <p>Two diagnostics that only a map file supports, both of which look identical from the disassembly:</p>
                <ul>
                    <li><strong>"My global got initialised."</strong> A variable that moved from <code>.bss</code> to <code>.data</code> shows as a <code>SizeOfRawData</code> going from 0 to non-zero. From the disassembly you would see only that a memory access changed from <code>mov</code> to <code>lea</code>-with-immediate. The map names the section it moved to and the object it came from, so you know the next step is to find which object defines it.</li>
                    <li><strong>"My function is at a strange address."</strong> If a function is 21 bytes and the next one starts 32 bytes later, either alignment padding or a discarded COMDAT sits between them. The map tells you which in one line, and the two have completely different causes and fixes.</li>
                </ul>
                <p>And the general reason this artifact exists at all: a link is a many-to-one function. Many objects go in, one image comes out, and the information about which input produced which output is destroyed. Every format that discards information during a transformation and then gets debugged is a format that eventually grows a log. The <code>ar</code> archive's symbol index in <a href="/courses/coff/lessons/coff-archives">Module 3</a> is the same instinct at a smaller scale &mdash; an index that survives the concatenation so the result can still be searched. The map file is the index for a link, and the one artifact you will wish you had when a build produces something you cannot explain.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ ld --oformat pei-i386 -m i386pe comdat_a.obj comdat_b.obj \
      -o comdat_linked.exe --entry use_a -Map comdat_linked.map
$ cat comdat_linked.map
</code></pre>
                <ul>
                    <li><strong>Make the filler your fault.</strong> Change the COMDAT alignment to 1 byte in both objects, relink, and diff the map. The <code>*fill*</code> rows should shrink or vanish, and <code>.text</code> should get smaller by exactly the difference. That is the cleanest demonstration of alignment-as-allocation you can produce, and it takes two flag changes.</li>
                    <li><strong>Delete an object and watch the layout move.</strong> Relink with only <code>comdat_a.obj</code>. Everything after <code>?use_a</code> shifts down, the <code>?use_b</code> row disappears, and the discards list shrinks. Watching a whole placement table reflow is the fastest way to internalise that addresses here are <em>assigned</em>, not discovered.</li>
                    <li><strong>Find the boundary between filler and content.</strong> Dump the raw bytes of <code>.text</code> in the image and locate the 11 bytes at <code>0x401015</code>. Then <code>objdump -d</code> that range. What the disassembler makes of padding is a good lesson in itself, and the fill pattern tells you which linker wrote it.</li>
                    <li><strong>Cross-check every linker-defined symbol against the binary.</strong> Take <code>__section_alignment__</code>, <code>__file_alignment__</code> and <code>__subsystem__</code> from the map and find each one at its known offset in the PE optional header. The PE course taught the offsets; the map gives you the values without a hex editor. Doing both is the check that the two documents describe the same link.</li>
                    <li><strong>Write a map summariser.</strong> Twenty lines of script that totals <code>*fill*</code> bytes per output section and reports the percentage of each section that is not yours. Run it over a real link. It is the highest-leverage twenty lines of tooling you can attach to a build, and it finds alignment problems that no compiler warning will ever mention.</li>
                </ul>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: an output section is declared as <code>0x200</code> bytes, and its placement rows account for a 21-byte input section, 11 bytes of filler, a 12-byte input section, 4 bytes of filler, and a 21-byte input section. What is the section's real content size, how much of the declared size is padding, and which of those two numbers does a disassembler see?</p>
                <div class="quiz" id="quiz-coff-map-files-1">
                    <button class="quiz-option" data-correct="true" data-explain="21 + 12 + 21 is 54 bytes of actual content, 11 + 4 is 15 bytes of linker-inserted filler, and 0x200 minus 69 is 443 bytes of tail padding, so the allocated section is far larger than anything in it. The distinction matters because the three numbers answer different questions and tools report different ones: a disassembler shows you the 54 bytes of code and skips the filler, llvm-readobj's VirtualSize reports the 69, and the map's 0x200 is the allocation rounded to the file alignment. Expecting a section's size to be its code size is the assumption this artifact exists to break." onclick="checkQuiz('quiz-coff-map-files-1', this)">Content is 54 bytes, 15 of the 69 accounted bytes are filler, and 443 of the 512 are tail padding. A disassembler sees only the 54 bytes of code &mdash; it decodes instructions and stops at the filler, so the padding is invisible to it</button>
                    <button class="quiz-option" data-correct="false" data-explain="This counts the filler as if it were content. Filler is bytes the linker inserted to satisfy an alignment rule; no instruction was compiled there and no symbol points at it. Adding it to the content size is exactly the confusion the map file exists to resolve, since the whole point of the fill rows is to separate the two." onclick="checkQuiz('quiz-coff-map-files-1', this)">Content is 69 bytes, because the filler rows are part of the section, and 443 bytes are tail padding. A disassembler sees all 69</button>
                    <button class="quiz-option" data-correct="false" data-explain="A disassembler decodes instructions, and the filler is not instructions. The fill pattern the linker chose is a recognisable fill byte rather than valid x86, so a disassembler runs to it and stops, which is precisely why the padding is invisible in a disassembly and visible only here. Claiming it decodes the filler requires the filler to be code, which nothing in the map says." onclick="checkQuiz('quiz-coff-map-files-1', this)">Content is 512 bytes, the whole declared size, because a section's size in the image includes its padding by definition and the filler is part of it</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>A shared library you maintain is 40&nbsp;KB. After an unrelated dependency bump, it is 78&nbsp;KB, and the release notes from the dependency say nothing about code size. You have the old and new objects and can relink. Walk through how you would use the map file to find the 38&nbsp;KB, naming the specific rows you would look at and what each would tell you. Then say what you would conclude if none of them accounts for it.</p>
                <div class="quiz" id="quiz-coff-map-files-2">
                    <button class="quiz-option" data-correct="true" data-explain="The method is: diff the two maps and let the structure tell you where the bytes went. A large *fill* row appearing or growing in the diff points at alignment, and the fix is a coarser alignment for the affected COMDAT or fewer separately-aligned items. An output section that appears that was not in the old map points at a section kind that was previously discarded, and its size row is the answer. A discard row that vanished means something that used to be dropped is now being kept, which points at a flag change rather than at new code. Output sections whose declared size grew far more than their attributed input bytes are being rounded to alignment, and the gap between the sum of the rows and the declared size is the padding. If none of those account for 38 KB, the honest conclusion is that the size is not in the link at all — the bytes are in an initialized-data section whose content is data rather than code, so the next step is to look at the data, not at the layout. The general habit is to let the map partition the question before you investigate it, because the three parts of the file correspond to three different categories of growth: discards, placement, and filler." onclick="checkQuiz('quiz-coff-map-files-2', this)">Diff the two map files, and read the diff by category. A large <code>*fill*</code> row points at alignment and its fix is a coarser alignment for the affected COMDAT. A new output section that was previously discarded points at a flag change &mdash; check the discard list, which shrank. A section whose declared size grew much more than its attributed input bytes is being rounded to alignment. If the discards, the placement rows, and the filler all account for only a few KB, the remaining growth is in a section that is data rather than code, and you should look at <code>.rdata</code> and <code>.data</code> contents, not at the layout</button>
                    <button class="quiz-option" data-correct="false" data-explain="A diff of the two map files answers this directly and cheaply, and it partitions the 38 KB by cause before you spend any effort. Starting with the disassembly means looking at code that has not changed, when the first question is which regions of the map grew. The map is the artifact that localises the change; starting anywhere else means doing the localisation by hand." onclick="checkQuiz('quiz-coff-map-files-2', this)">Compare the two linker's outputs with <code>objdump -h</code> and find which output section grew, then disassemble that section and look for new code</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a file format that throws information away during a transformation is a file format whose output cannot explain itself. The link destroys provenance, so the map is what puts it back. When a build produces an artefact you cannot account for, find the log first and reason second.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>The <code>*fill*</code> rows are the map file's most surprising content, and they exist because of the alignment flags in <a href="/courses/coff/lessons/coff-section-table">the section table</a>. Those flags were decoded as data in Module 1; here they are observed being spent. A number in a header that changes the size of your binary is a number worth understanding, and this is where the connection closes.</p>
                <p>The linker-defined symbols block connects to the <a href="/courses/pe">PE course</a> directly. <code>__image_base__</code>, <code>__section_alignment__</code>, <code>__file_alignment__</code> and <code>__subsystem__</code> are optional-header fields that the map states as plain named constants. Anyone who has read a PE header by hand and anyone who has read a link map is looking at the same four numbers written in two vocabularies.</p>
                <p>And the one row in this concept that is <em>missing</em> from the placement table is the subject of the next concept. <code>comdat_b.obj</code>'s <code>0xc</code>-byte copy of <code>?shared</code> exists, matches another copy byte for byte, and does not appear in the image. Module 3 taught the mechanism that makes that decision possible. This is what the mechanism does.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-comdat-linking">COMDAT in the Linker</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-linking">Previous: The Link</a></span>
                <span><a href="/courses/coff/lessons/coff-comdat-linking">Next: COMDAT in the Linker</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
