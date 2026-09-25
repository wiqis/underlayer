// COFF Course — Module 4: The Link
// Concept: what a linker actually does to a COFF object — the moment a relocation
// stops being a note and becomes an address.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_linking() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("The Link — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>The Link</h1>
            <div class="lesson-meta">23 min &middot; Module 4: The Link &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Everything so far in this course has been about a <em>file</em>: its header, its section table, its symbol table, its relocations. A COFF object is a well-specified container that no program runs. The whole reason it exists is that something comes along afterwards and destroys the information you have spent three modules reading.</p>
                <p>That something is the linker. It takes objects that each have zero real addresses, assigns addresses, applies relocations so those addresses appear in the bytes, resolves which copy of a duplicated symbol wins, and throws away the sections that only mattered during compilation. After it runs, the <code>IMAGE_REL_I386_REL32</code> entry that said "at offset 14, add the distance to <code>_helper</code>" is gone, and in its place is a number.</p>
                <p>This concept runs a real link and watches each of those happen, because a COFF course that stops at the object file has described a format and not a process. Everything here is a comparison of the same bytes before and after.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>An object file, in the terms this course has used: sections whose <code>VirtualAddress</code> is <strong>zero</strong>, a symbol table whose <code>Value</code> is a <strong>section-relative offset</strong>, and a set of fixups saying which four bytes to overwrite and how. The linker does five things, and each is a separate transformation:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Step</th><th scope="col">Changes</th><th scope="col">Observable as</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>1. Place</td><td>Every section gets a real <code>VirtualAddress</code></td><td>The section table's <code>VirtualAddress</code> fields stop being zero</td></tr>
                        <tr><td>2. Absorb</td><td>Sections with the same name from different objects are concatenated</td><td>One output section is larger than any input section</td></tr>
                        <tr><td>3. Relocate</td><td>Each fixup's target is computed and written into the section's bytes</td><td>Zero bytes in the object are non-zero in the image</td></tr>
                        <tr><td>4. Resolve</td><td>Duplicate COMDAT sections are eliminated, one kept</td><td>The output is smaller than the sum of the inputs</td></tr>
                        <tr><td>5. Discard</td><td>Sections flagged removable or discardable are dropped</td><td>Input sections have no output counterpart</td></tr>
                    </tbody>
                </table>
                <p>Two properties of this list are worth noticing before the evidence. Steps 1 and 3 are <strong>inseparable in practice</strong>: you cannot know what to write into a relocation until you know where the sections are, and you cannot know where the sections are until you decide the layout. And step 5 is not a cleanup pass at the end &mdash; it happens <em>before</em> placement, because a discarded section must not consume address space. A linker that discards after placing wastes the space, and a map file that lists discards <em>before</em> placements is showing you the real order of operations.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>Two source files, compiled to COFF objects. Every function in both has a single-expression body, so each one is written on one line; that is why the source is so short and why the machine code is so regular.</p>
                <table>
                    <thead>
                        <tr><th scope="col">File</th><th scope="col">Contents</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>link_prog.c</code></td><td>Declares <code>helper</code>, then <code>entry</code> which returns <code>helper(x) + 1</code>, then <code>main</code> which returns <code>entry(5)</code></td></tr>
                        <tr><td><code>link_lib.c</code></td><td><code>lib_add</code> which returns <code>a + b</code>, and an initialised global <code>lib_val = 11</code></td></tr>
                    </tbody>
                </table>
                <pre><code>$ clang --target=i686-pc-windows-msvc -c link_prog.c -o link_prog.obj
$ clang --target=i686-pc-windows-msvc -c link_lib.c -o link_lib.obj</code></pre>
                <p>That gives three call sites and one data initialiser, which is exactly enough to see placement, absorption, relocation and discarding all happen in one link.</p>
                <h3>Step 3, in isolation: the relocations before</h3>
                <p>The object carries two fixups, both <code>IMAGE_REL_I386_REL32</code>:</p>
                <pre><code>$ llvm-readobj --relocations link_prog.obj
  Section (1) .text
    0xE  IMAGE_REL_I386_REL32  _helper (12)
    0x45 IMAGE_REL_I386_REL32  _entry  (11)</code></pre>
                <p>The tool wraps that in a <code>Relocations [ ]</code> block, and it does the same for every object in the link &mdash; which is worth knowing, because a relocation list that names its own section tells you that a fixup in one section must be applied before the addresses of the next section are final.</p>
                <p>Every section's <code>VirtualAddress</code> is <code>0x0</code>. That is not a placeholder the linker will overwrite later &mdash; it is the <em>truth</em>: the code is not at any address, so it has no address. And the four bytes at offset <code>0xe</code> of <code>.text</code> are <code>00 00 00 00</code>. The relocation is not a note next to the data; the relocation <strong>is</strong> the data, and the zeros are its placeholder.</p>
                <div class="callout">
                    <strong>Why <code>REL32</code> and not a plain address.</strong> <code>IMAGE_REL_I386_REL32</code> does not write an absolute address. It writes <em>the difference between two addresses</em>, which means the instruction it fixes stays correct no matter where either side is loaded. That is the same reason a <code>call</code> instruction has a relative displacement: the CPU computes <code>next_address + displacement</code>. The COFF fixup is the assembler and linker cooperating to keep that property intact &mdash; the object stores the displacement, and the linker resolves it to a displacement, never to an address.
                </div>
                <h3>Steps 1 and 2 together: the image</h3>
                <pre><code>$ ld --oformat pei-i386 -m i386pe link_prog.obj link_lib.obj \
      -o link_prog.exe --entry entry
$ file link_prog.exe
link_prog.exe: PE32 executable for MS Windows 4.00 (console), Intel i386, 4 sections</code></pre>
                <p>The addresses are real now:</p>
                <div class="hex-dump">
                    <pre>Machine:              IMAGE_FILE_MACHINE_I386 (0x14C)
ImageBase:            0x400000
AddressOfEntryPoint:  0x1000
SectionAlignment:     4096
FileAlignment:        512

  .text   VirtualAddress 0x1000   VirtualSize 0x61
  .data   VirtualAddress 0x2000   VirtualSize 0x4
  .rdata  VirtualAddress 0x3000   VirtualSize 0x10
  .idata  VirtualAddress          (import directory)
</pre>
                </div>
                <p>Two things happened at once. The sections were given addresses on a <strong>4096-byte grid</strong>, so <code>.text</code> is at <code>0x1000</code> and <code>.data</code> at <code>0x2000</code> even though <code>.text</code> is only <code>0x61</code> bytes &mdash; the gap exists so that a page can be made writable without making the code page writable. And the <code>ImageBase</code> of <code>0x400000</code> was chosen, which is the preferred base for 32-bit Windows executables. The virtual address <code>0x1000</code> is relative; the address the program actually runs at is <code>0x400000 + 0x1000 = 0x401000</code>.</p>
                <p>So there are three numbers and they are easy to conflate. The section's <code>VirtualAddress</code> is relative to the image base. The <code>ImageBase</code> is the image's preferred load address. The <em>actual</em> address is their sum, and at run time it may be a different sum entirely &mdash; which is the entire reason base relocations exist, and something this linker will not emit, so it is taught in the <a href="/courses/pe/lessons/pe-base-relocations">PE course</a> rather than here.</p>
                <h3>Step 3, in isolation: the relocations after</h3>
                <p>Now the proof. Disassemble the linked image:</p>
                <div class="hex-dump">
                    <pre>00401000 &lt;_entry&gt;:
  401000: 55             pushl  %ebp
  401001: 89 e5          movl   %esp, %ebp
  401003: 50             pushl  %eax
  401004: 8b 45 08       movl   0x8(%ebp), %eax
  401007: 8b 45 08       movl   0x8(%ebp), %eax
  40100a: 89 04 24       movl   %eax, (%esp)
  40100d: e8 0e 00 00 00 calll  0x401020 &lt;_helper&gt;
  401012: 83 c0 01       addl   $0x1, %eax
  401015: 83 c4 04       addl   $0x4, %esp
  401018: 5d             popl   %ebp
  401019: c3             retl
</pre>
                </div>
                <p>Compare the <code>e8</code> opcode's four operand bytes with the zeros in the object:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Where</th><th scope="col">Bytes at the fixup</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>link_prog.obj</code>, <code>.text</code> + <code>0xe</code></td><td><code>00 00 00 00</code></td><td>Nothing. The code is nowhere</td></tr>
                        <tr><td><code>link_prog.exe</code>, <code>0x40100d</code></td><td><code>0e 00 00 00</code></td><td><code>0x0e</code> = 14</td></tr>
                    </tbody>
                </table>
                <p>And 14 is exactly right, and you can check it yourself. The <code>call</code> instruction begins at <code>0x40100d</code> and is five bytes long, so the address of the <em>next</em> instruction is <code>0x401012</code>. The target is <code>_helper</code> at <code>0x401020</code>. The displacement is <code>0x401020 - 0x401012 = 0x0e</code>. The CPU will do that addition itself at run time and arrive at <code>0x401020</code>, without ever knowing that <code>0x400000</code> exists.</p>
                <p><strong>That subtraction is the entire relocation.</strong> Four bytes changed, and the arithmetic that produced them is a two-term difference of addresses &mdash; the same shape as every other relative fixup in every object format. The relocator's real job is not arithmetic; it is knowing which two addresses to subtract.</p>
                <h3>Step 5: the sections that did not survive</h3>
                <p>The object had a <code>.debug$S</code> section and an address-significance section. Neither appears in the image's four sections. Here is the entire evidence, from the linker's own map file:</p>
                <pre><code>Discarded input sections

 .debug$S       0x00000000       0x5c link_prog.obj
 .llvm_addrsig  0x00000000        0x2 link_prog.obj
 .debug$S       0x00000000       0x5c link_lib.obj
 .llvm_addrsig  0x00000000        0x0 link_lib.obj</code></pre>
                <p>That is step 5 observed, and it closes a loop from Module 1. The characteristics flags you decoded there are not descriptive &mdash; they are <em>instructions to the linker</em>. Reading them back out of the object, with the parser shipped with this course:</p>
                <div class="hex-dump">
                    <pre>link_prog.obj
  sec4  .debug$S      rawsize=92  char=0x42300040
        IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_DISCARDABLE | IMAGE_SCN_MEM_READ
  sec5  /4            rawsize=2   char=0x00100800
        IMAGE_SCN_LNK_REMOVE
</pre>
                </div>
                <p>Two different instructions, and the difference is worth holding onto. <code>MEM_DISCARDABLE</code> says "this section's contents may be thrown away &mdash; it exists for a build-time consumer, not for the loader". <code>LNK_REMOVE</code> says the stronger thing: "this section is not part of the program at all, and any content it happens to carry is padding". The compiler sets the first on debug data and the second on the address-significance section, and the linker honours both by not placing either.</p>
                <p>And a small observation about that <code>/4</code>. The section's name in the header is not <code>.llvm_addrsig</code> &mdash; it is the four characters <code>/4</code>, because the name is too long for the eight-byte field and <code>/N</code> means "the real name is in the string table at offset <code>N</code>". This is the string-table indirection from Module 1, doing its job in a place where a reader is not expecting it. The map file prints the resolved name; the object stores the reference. Which means the string table is load-bearing for the <em>linker</em>, not just for your own decoder &mdash; a program that printed section names from the object without resolving them would show you <code>/4</code> and not the section.</p>
                <p>Read the discard sizes as well. <code>.debug$S</code> is <code>0x5c</code> = 92 bytes in <em>both</em> objects &mdash; the same 92 bytes, discarded twice, because both were compiled with the same flags. <code>.llvm_addrsig</code> is <code>0x2</code> bytes in one object and <code>0x0</code> in the other: the second object had an address-significance section of length zero, and a zero-length section is still a section that gets discarded. If you are ever unsure whether a section participated in a link, this list is the authority; the output section table only shows what survived.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Doing step 3 yourself, for the second relocation, to confirm the model transfers. The object says <code>0x45 IMAGE_REL_I386_REL32 _entry</code>, so offset <code>0x45</code> of <code>.text</code> holds a displacement to <code>_entry</code>. In the image, <code>.text</code> starts at <code>0x401000</code>, <code>_entry</code> is at <code>0x401000</code>, and the only <code>call</code> to it is from <code>main</code>:</p>
                <div class="formula">
fixup_offset   = 0x45
field_address  = image_base + .text.VirtualAddress + fixup_offset
               = 0x400000 + 0x1000 + 0x45
               = 0x401045

target_address = image_base + .text.VirtualAddress + _entry.Value
               = 0x400000 + 0x1000 + 0x0
               = 0x401000

displacement   = target_address - (field_address + 4)
               = 0x401000 - 0x401049
               = -0x49
</div>
                <p>And <code>-0x49</code> is <code>ffffffb7</code> in the image. Note the <code>+ 4</code> in the last line: the displacement is measured from the end of the field, not its start, because that is where the CPU resumes after reading the four bytes. Getting that wrong by four produces a link error at build time or a jump to a misaligned address at run time, and it is the single most common bug in a hand-written relocator.</p>
                <p>So the whole relocation algorithm, for the <code>REL32</code> family, is:</p>
                <ol>
                    <li>Find the field: the input section's raw data at the fixup offset.</li>
                    <li>Work out where that field will end up, from the output section's <code>VirtualAddress</code> and the input section's offset within it.</li>
                    <li>Resolve the symbol: a section-relative <code>Value</code> in the object becomes <code>image_base + section.VirtualAddress + Value</code> in the image.</li>
                    <li>Subtract, and write the result in the field's width, sign-extended from the difference &mdash; not truncated.</li>
                </ol>
                <p>Step 4 is the interesting one for a hand-rolled linker and step 3 is where bugs live. Sign extension is the trap: a displacement of <code>-0x49</code> must be stored as <code>ffffffb7</code>, and storing <code>0x000000b7</code> turns a backward call into a jump 184 million bytes forward. The field is four bytes wide, not four bytes of magnitude, and the value is a <em>difference</em>, so it is signed by nature. Every relocation type in this table that ends in a two-digit number is a signed displacement of some width, and the number in the name is that width.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ ld --oformat pei-i386 -m i386pe link_prog.obj link_lib.obj \
      -o link_prog.exe --entry entry -Map link_prog.map
$ llvm-objdump -d --section=.text link_prog.exe
$ llvm-readobj --sections link_prog.exe | head -40</code></pre>
                <ul>
                    <li><strong>Read the map file.</strong> The next concept is about it, but read it now for the ordering: the discards are listed <em>above</em> the placements. That is not formatting, it is the linker's actual sequence &mdash; discard, then place. Finding that in a generated file is worth more than being told it.</li>
                    <li><strong>Change one thing and watch one thing move.</strong> Add a function to <code>link_lib.c</code>, relink, and diff the map. The new function changes <code>.text</code>'s size, which can change nothing else &mdash; but if you add a variable, <code>.data</code> grows and <code>.rdata</code> may move. Watching the grid spacing hold at 4096 while contents change is the clearest demonstration of why alignment is not rounding but allocation.</li>
                    <li><strong>Force a relayout.</strong> Link with a different image base, if your linker accepts one. The <code>VirtualAddress</code>es stay the same and the <code>ImageBase</code> changes, so the fixup displacements should be <em>unchanged</em> &mdash; because they are differences. Any that change are absolute fixups, and finding one is the payoff of the whole relative-vs-absolute distinction.</li>
                    <li><strong>Break a relocation on purpose.</strong> Delete the definition of <code>helper</code> and relink. Read the error message, and note that it is an <em>unresolved external</em> rather than a bad relocation. A missing symbol and a miscomputed displacement are different failures with different evidence, and knowing which one you have saves a long debugging session.</li>
                    <li><strong>Confirm the discard flags are the cause.</strong> The parser shipped with this course prints them. Read <code>.debug$S</code> out of the object and check for <code>IMAGE_SCN_MEM_DISCARDABLE</code>; read the <code>/4</code> section and check for <code>IMAGE_SCN_LNK_REMOVE</code>; then read <code>.text</code> and check that it has neither. Three data points, one rule, and the rule is now observed rather than quoted.</li>
                </ul>
                <p>And a self-check: the displacement you computed by hand was <code>-0x49</code>, and the disassembly should contain <code>e8 b7 ff ff ff</code>. If your linked binary shows a <em>forward</em> call from <code>main</code> to <code>entry</code>, your linker placed <code>main</code> before <code>entry</code> and the sign is wrong &mdash; go back to the <code>+ 4</code>.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a COFF object has <code>.text</code> with <code>VirtualAddress = 0</code>, four zero bytes at offset <code>0xe</code>, and a relocation <code>0xE IMAGE_REL_I386_REL32 _helper</code>. After linking, <code>.text</code> is at <code>0x1000</code>, the image base is <code>0x400000</code>, and <code>_helper</code> is at <code>0x401020</code>. What goes into those four bytes, and what was actually true about the zeros before the link?</p>
                <div class="quiz" id="quiz-coff-linking-1">
                    <button class="quiz-option" data-correct="true" data-explain="The four bytes become 0x0e, because the call instruction's displacement is measured from the address after the instruction, not from the section start. The zeros in the object were not an unresolved value waiting to be filled in; they were the accurate content of a field whose value genuinely was zero, because at object time the code was at no address and no displacement existed. The relocation entry is what carries the information, and the field is its storage. That is the conceptual heart of a relocatable format: the data is a placeholder and the relocation is the statement of what belongs there." onclick="checkQuiz('quiz-coff-linking-1', this)">They become <code>0e 00 00 00</code> &mdash; the displacement <code>0x401020 - (0x40100d + 5)</code>. The zeros were not a wrong value: they were the <em>placeholder</em> for a displacement that did not exist yet, and the relocation entry was the real content of the field</button>
                    <button class="quiz-option" data-correct="false" data-explain="REL32 writes a displacement, not an address, and that is exactly what makes the result survive being loaded at a different base. Writing an absolute address would make the image unloadable anywhere except its preferred base, which is the problem base relocations exist to solve. The bytes you would expect from an absolute encoding would be 20 10 40 00." onclick="checkQuiz('quiz-coff-linking-1', this)">They become the absolute address of <code>_helper</code>, little-endian: <code>20 10 40 00</code>. That is what an absolute relocation would write, and it is why relative fixups exist</button>
                    <button class="quiz-option" data-correct="false" data-explain="That would be the value before applying the image base, and it is off by a factor of the load address. The section's VirtualAddress is relative to the image base, so the address the program runs at is image_base plus VirtualAddress, and a fixup that used only the section's VirtualAddress would produce a displacement of negative 0x30000 — a backward call into unmapped memory." onclick="checkQuiz('quiz-coff-linking-1', this)">They become <code>0x20</code>, the section-relative offset of <code>_helper</code> within <code>.text</code>, since a relocatable object addresses everything relative to its own sections</button>
                    <button class="quiz-option" data-correct="false" data-explain="A REL32 fixup is a signed displacement and a displacement is a difference of two addresses, so it is negative whenever the target precedes the field. Here the call at 0x40100d targets 0x401020, which is forward, giving the small positive value 0x0e. The sign convention matters for the backward call from main to entry, which came out negative." onclick="checkQuiz('quiz-coff-linking-1', this)">They become <code>ff ff ff f2</code>, the signed difference <code>0x401020 - 0x40100e</code> measured from the <em>start</em> of the field rather than from the end of the instruction</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You are writing a COFF linker &mdash; the object side of it &mdash; and it works for most inputs. It fails on exactly one class: any program that calls a function defined in a file that sorts later in the link order. Forward calls are fine; backward calls resolve to a huge positive number and the program jumps into the middle of nowhere. Relocations report no errors, the image is well-formed, and <code>readelf</code>-equivalent tools show the fixups as applied. What is wrong, and how would you confirm it in one run?</p>
                <div class="quiz" id="quiz-coff-linking-2">
                    <button class="quiz-option" data-correct="true" data-explain="A signed overflow on the subtraction is the classic version of this, and it explains the exact pattern: a negative displacement that comes out positive and huge is a 32-bit truncation, not a sign error. A correct linker stores the 64-bit difference and lets the low 32 bits carry the sign, which is what produces 0xffffffb7 for -0x49. The reason it is invisible in the tool output is that the fixup is genuinely marked applied — a value was written, it just was the wrong value — so there is nothing for a relocator reporter to complain about. The one-run confirmation is to disassemble and look at the bytes, because a backward call's operand should be a byte sequence starting with 0xff, and that is visible in the instruction stream without any tool having to make a judgement." onclick="checkQuiz('quiz-coff-linking-2', this)">The displacement is being truncated to 32 bits <em>without sign extension</em> from the 64-bit difference, so a negative result loses its sign. Compute the difference in 64 bits and let the low 32 bits carry the sign. Confirm it by disassembling: a backward call's operand should be a byte sequence beginning <code>ff</code></button>
                    <button class="quiz-option" data-correct="false" data-explain="A 32-bit field is 32 bits wide, and the image base plus any section virtual address are 32-bit values, so the whole computation fits. A 64-bit field for 32-bit addresses is a much rarer misconfiguration, and it would misplace every relocation rather than only backward ones. The pattern of forward working and backward broken points at the sign, not at the width of the arithmetic." onclick="checkQuiz('quiz-coff-linking-2', this)">The field is being written as 64 bits into a 32-bit relocation, so the upper half overwrites the bytes after the instruction and corrupts the following code</button>
                    <button class="quiz-option" data-correct="false" data-explain="This is the off-by-four mistake and it is a real one, but it has the wrong signature. Getting the end-of-field address wrong displaces every call by four bytes, forward and backward alike, and produces a consistent small offset rather than a huge positive number. The reported symptom of a huge value and of working forward calls is a sign problem." onclick="checkQuiz('quiz-coff-linking-2', this)">The displacement is being measured from the start of the fixup field instead of from the end of the instruction, so every call is off by exactly four bytes</button>
                    <button class="quiz-option" data-correct="false" data-explain="This misdiagnoses a relocation that has already been computed and written. A premature base assignment would affect all fixups in the section equally and would show up as uniformly wrong addresses rather than a sign-dependent pattern, and it would not leave the tool's applied-relocation report clean. The distinction between a wrong value and an unapplied fixup is exactly the evidence the report gives you." onclick="checkQuiz('quiz-coff-linking-2', this)">The image base is being added twice, so addresses exceed 32 bits and wrap. The tool cannot show the problem because the relocations genuinely were applied &mdash; just to the wrong values</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a bug that only appears for one sign of a value is almost always a sign-handling bug. Read the failing value in hex and ask what the correct value would be; if the two differ only in their high bits, you have found it.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>Step 3 is the ELF course's relocation machinery, running on a different container. <a href="/courses/elf/lessons/relocation-entries">ELF relocations</a> use a table of records with explicit symbol and addend fields; COFF's <code>IMAGE_REL_I386_REL32</code> is a single 16-bit number and the target is implied by the field. Same arithmetic, much less explicit, and the practical consequence is that a COFF relocation cannot express "this symbol plus this addend" &mdash; the addend is whatever is already in the field. That difference in expressiveness is why COFF objects are smaller and why the two formats' relocation tables do not convert cleanly.</p>
                <p>Step 1 introduces the <code>ImageBase</code>, and the fact that the virtual addresses are relative to it is the setup for the PE course's <a href="/courses/pe/lessons/pe-base-relocations">base relocation</a> concept. When the loader cannot put the image at its preferred base, every absolute address baked into the image is wrong, and the base relocation table is the list of places to patch. This concept stopped short of that deliberately: the linker used here will not emit one, and a claim that could not be checked against a file is not taught here.</p>
                <p>Steps 2 and 5 both point at the next concept, which is the artifact that records all five steps in the order they happen &mdash; and names, in plain text, every input section that was discarded and why.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-map-files">Map Files</a>.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-line-numbers">Previous: Line Numbers</a></span>
                <span><a href="/courses/coff/lessons/coff-map-files">Next: Map Files</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
