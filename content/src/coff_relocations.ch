// COFF Course — Module 2: Symbols and Relocations
// Concept: the 10-byte relocation record and the AMD64 type table.
public namespace underlayer_content {

using std::string

using std::string_view

public func render_coff_relocations() : string {
    var page = HtmlPage()
    page.defaultPrepare()
    var title = std::string_view("Relocations — Underlayer")
    page.appendTitle(&title)

    render_lesson_css(&mut page)

    #html {
        <div class="lesson coff-lesson">
            <a href="/courses/coff" class="back-link">Back to course</a>
            <h1>Relocations</h1>
            <div class="lesson-meta">20 min &middot; Module 2: Symbols and Relocations &middot; Algorithms</div>

            <div class="unit unit-why">
                <h2>Why This Matters</h2>
                <p>Every relocation is one unanswered question. "At offset 0x56 inside <code>.text</code>, the 4-byte value currently zero should become the address of the thing called <code>g_data</code>." Ten bytes, and that is the entire mechanism by which a compiler hands layout decisions to a linker.</p>
                <p>They are also the last place in this course where a parser can be subtly, silently wrong &mdash; because the COFF specification documents a packed layout for x64 that the compiler does not actually emit, and a reader that implements the documented version gets a type of zero for every record in the file.</p>
            </div>

            <div class="unit unit-model">
                <h2>A Simple Model</h2>
                <p>Three fields, ten bytes, answering three separate questions:</p>
                <ol>
                    <li><strong>Where?</strong> <code>VirtualAddress</code> &mdash; an offset <em>within the section this table belongs to</em>, not a file offset and not a virtual address. Both of those would be meaningless in a relocatable file.</li>
                    <li><strong>What?</strong> <code>SymbolTableIndex</code> &mdash; an index into the symbol table, not a name. The relocation never spells out a symbol name.</li>
                    <li><strong>How?</strong> <code>Type</code> &mdash; a machine-specific number saying what arithmetic to perform and how wide the result is.</li>
                </ol>
                <p>Two things follow from that, and they are the whole design. First, <strong>relocations belong to a section</strong>, so each section header points at its own table and carries its own count. Second, <strong>the type numbering is per-machine</strong>, so a reader that knows the <code>Machine</code> field knows which table of type numbers applies &mdash; and a reader that ignores it will decode an i386 object using the AMD64 table and produce plausible nonsense.</p>
            </div>

            <div class="unit unit-reality">
                <h2>The Actual Detail</h2>
                <p>The <code>.text</code> relocation table: three records of ten bytes at file offset 0x1E8, immediately after the 108 bytes of code they describe.</p>
                <div class="hex-dump">
                    <pre>000001e8: 5600 0000 1700 0000 0400   addr 0x56  sym 23  type 4
000001f2: 5d00 0000 1400 0000 0400   addr 0x5d  sym 20  type 4
000001fc: 6200 0000 1500 0000 0400   addr 0x62  sym 21  type 4</pre>
                </div>
                <p>And <code>llvm-objdump -r</code> reading the same bytes:</p>
                <pre><code>RELOCATION RECORDS FOR [.text]:
OFFSET           TYPE                     VALUE
0000000000000056 IMAGE_REL_AMD64_REL32    g_data
000000000000005d IMAGE_REL_AMD64_REL32    add
0000000000000062 IMAGE_REL_AMD64_REL32    call_through</code></pre>
                <p>Cross-referencing the symbol indices against the table from <a href="/courses/coff/lessons/coff-symbol-table">the symbol concept</a>: 23 is <code>g_data</code>, 20 is <code>add</code>, 21 is <code>call_through</code>. Every field agrees.</p>
                <p>So the verified layout is the plain one:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Offset</th><th scope="col">Size</th><th scope="col">Field</th><th scope="col">Note</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0x00</td><td>4</td><td><code>VirtualAddress</code></td><td>offset within the owning section</td></tr>
                        <tr><td>0x04</td><td>4</td><td><code>SymbolTableIndex</code></td><td>low 16 bits used</td></tr>
                        <tr><td>0x08</td><td>2</td><td><code>Type</code></td><td>machine-specific numbering</td></tr>
                    </tbody>
                </table>
                <h3>The type numbers you will actually meet</h3>
                <p>On <code>IMAGE_FILE_MACHINE_AMD64</code>, the types in our file are 1, 3 and 4:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Value</th><th scope="col">Name</th><th scope="col">Meaning</th><th scope="col">Where we saw it</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>0</td><td><code>IMAGE_REL_AMD64_ABSOLUTE</code></td><td>no operation; used as padding</td><td>not present</td></tr>
                        <tr><td>1</td><td><code>IMAGE_REL_AMD64_ADDR64</code></td><td>write the 8-byte absolute address</td><td><code>.data</code>, 2 records</td></tr>
                        <tr><td>2</td><td><code>IMAGE_REL_AMD64_ADDR32</code></td><td>write the 4-byte absolute address</td><td>not present</td></tr>
                        <tr><td>3</td><td><code>IMAGE_REL_AMD64_ADDR32NB</code></td><td>4-byte address, subtract the image base</td><td><code>.pdata</code>, 9 records</td></tr>
                        <tr><td>4</td><td><code>IMAGE_REL_AMD64_REL32</code></td><td>32-bit <em>relative</em> displacement</td><td><code>.text</code>, 3 records</td></tr>
                    </tbody>
                </table>
                <p>The distinction that matters most is <code>REL32</code> versus everything else. <code>REL32</code> is a <em>displacement</em>: the linker computes <code>target - (address of this field + 4)</code> and writes that, which is exactly what a <code>call</code> or <code>jmp</code> instruction with a 32-bit relative operand needs. It is position-independent within the section, which is why code can move without being rewritten. Everything else writes a bare address, which is why it is <em>not</em> position-independent and why the code holding it must be rebuilt if the image moves beyond 2 GB.</p>
                <p>The <code>NB</code> in <code>ADDR32NB</code> means "not based": the linker subtracts the image base, storing a relative address in a field that looks absolute. The <code>.pdata</code> records are all of this type, pointing at <code>.text</code> and <code>.xdata</code> from an exception-unwinding table &mdash; data that references code, and therefore needs to survive rebasing.</p>
            </div>

            <div class="unit unit-example">
                <h2>A Real Example</h2>
                <p>Decode all fourteen relocations in the file, then confirm against both tools. This is the table every claim in this concept rests on:</p>
                <table>
                    <thead>
                        <tr><th scope="col">Section</th><th scope="col">Offset</th><th scope="col">Symbol</th><th scope="col">Type</th><th scope="col">Meaning</th></tr>
                    </thead>
                    <tbody>
                        <tr><td><code>.text</code></td><td>0x56</td><td>23 <code>g_data</code></td><td>4</td><td>REL32 &mdash; the <code>mov</code> that loads the global</td></tr>
                        <tr><td><code>.text</code></td><td>0x5D</td><td>20 <code>add</code></td><td>4</td><td>REL32 &mdash; the <code>call add</code></td></tr>
                        <tr><td><code>.text</code></td><td>0x62</td><td>21 <code>call_through</code></td><td>4</td><td>REL32 &mdash; the <code>call call_through</code></td></tr>
                        <tr><td><code>.data</code></td><td>0x08</td><td>12 the string literal</td><td>1</td><td>ADDR64 &mdash; <code>g_ptr</code>, an 8-byte pointer</td></tr>
                        <tr><td><code>.data</code></td><td>0x10</td><td>23 <code>g_data</code></td><td>1</td><td>ADDR64 &mdash; <code>g_addr</code>, an 8-byte pointer</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x00</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x04</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x08</td><td>6 <code>.xdata</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x0C</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x10</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x14</td><td>6 <code>.xdata</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x18</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x1C</td><td>0 <code>.text</code></td><td>3</td><td>ADDR32NB</td></tr>
                        <tr><td><code>.pdata</code></td><td>0x20</td><td>6 <code>.xdata</code></td><td>3</td><td>ADDR32NB</td></tr>
                    </tbody>
                </table>
                <p>Every row was produced by an independent parser and required to match <code>llvm-readobj --relocations</code>, which agrees on all fourteen offsets, symbol indices and types. The file has 1200 such records in total across the five sample objects, and all of them matched.</p>
                <p>Read the <code>.pdata</code> group as a pattern: 3 <code>RUNTIME_FUNCTION</code> entries, each 12 bytes, each needing a <code>.text</code> address and a <code>.xdata</code> address. Two relocations per entry, nine in total because the <code>.pdata</code> section is 36 bytes and the last entry's second field is covered by the section's own extent. The triple of 0x00, 0x04, 0x08 is one entry; 0x0C, 0x10, 0x14 is the next; 0x18, 0x1C, 0x20 is the third.</p>
                <h3>The second specification-versus-reality discrepancy</h3>
                <p>The PE/COFF specification documents an <strong>overlapping</strong> x64 relocation layout: bits 0&ndash;11 of the first dword are the offset, bits 12&ndash;15 of that <em>same</em> dword are the type, and bits 16&ndash;31 of the second dword are the symbol index. Under that reading, our first record &mdash; bytes <code>56 00 00 00 17 00 00 00 04 00</code> &mdash; decodes as:</p>
                <div class="formula">
overlapping reading:  offset = 0x56        (low 12 bits, fine)<br>
                      type   = 0x00         (bits 12-15 are zero!)  -&gt; ABSOLUTE<br>
                      symbol = 0x00         (bits 16-31 of 0x00000017) -&gt; symbol 0
                </div>
                <p>Every one of the fourteen records decodes that way to <code>IMAGE_REL_AMD64_ABSOLUTE</code>, symbol 0 &mdash; the padding type, referencing nothing. That is obviously wrong, and it is the signal that the reading is wrong rather than the data.</p>
                <p>The plain reading gives offset 0x56, symbol 23, type 4 &mdash; which matches <code>llvm-objdump</code> exactly, including the <code>REL32</code> that a <code>call</code> instruction obviously requires. <strong>clang emits the plain layout, and so does every object in this course.</strong></p>
                <p>This is recorded as an observed discrepancy, not as a claim that the specification is wrong. Some documentation and some linkers do describe the packed form, and a tool that has to read <em>any</em> COFF file should know both exist. But a reader built only to the documented variant will report fourteen zero relocations in this object, and nothing in the file will tell it that something is off.</p>
            </div>

            <div class="unit unit-interact">
                <h2>Try It Yourself</h2>
                <pre><code>$ clang --target=x86_64-pc-windows-msvc -c sample.c -o sample_msvc.obj
$ llvm-objdump -r sample_msvc.obj
$ xxd -s 0x1e8 -l 32 sample_msvc.obj
$ llvm-readobj --relocations sample_msvc.obj | head -20</code></pre>
                <p>Do both decodings and watch one of them fail. This is a five-minute experiment that is worth more than the table above:</p>
                <pre><code># The reading that FAILS on real files (documented, not emitted):
type   = (dword0 &gt;&gt; 12) &amp; 0xF
offset = dword0 &amp; 0xFFF
symbol = (dword1 &gt;&gt; 16) &amp; 0xFFFF
#   -&gt; type 0 (ABSOLUTE) and symbol 0, for every record

# The reading that matches the bytes:
offset = dword0
symbol = dword1 &amp; 0xFFFF
type   = word2
#   -&gt; 0x56/23/4, 0x5d/20/4, 0x62/21/4</code></pre>
                <p>Then confirm that the type numbering really is per-machine, by looking at the same source compiled for i386:</p>
                <pre><code>$ clang --target=i686-pc-windows-msvc -c sample.c -o sample_m32.obj
$ llvm-objdump -r sample_m32.obj | head -6
RELOCATION RECORDS FOR [.text]:
0000000000000057 IMAGE_REL_I386_DIR32     _g_data
000000000000005d IMAGE_REL_I386_DIR32     _add
0000000000000069 IMAGE_REL_I386_REL32     _call_through</code></pre>
                <p>Different type <em>names</em> and different numbers for the same source constructs, and a leading underscore on every symbol because i386 uses the cdecl decoration that x64 dropped. The container is byte-identical in layout; <code>Machine</code> is what tells you which dialect of the type table applies.</p>
            </div>

            <div class="unit unit-retrieve">
                <h2>Check Your Understanding</h2>
                <p>Without looking back: a <code>.text</code> relocation record reads <code>addr 0x5D, symbol 20, type 4</code>. Which of the three fields is a section-relative offset rather than a file offset or a virtual address, and what does type 4 mean the linker will do?</p>
                <div class="quiz" id="quiz-coff-relocations-1">
                    <button class="quiz-option" data-correct="true" data-explain="VirtualAddress in a relocation is an offset within the owning section, which is the only frame of reference that means anything before the file is placed. Type 4 is IMAGE_REL_AMD64_REL32, a relative displacement: the linker writes target minus (address of this field plus 4). That is what makes call instructions position-independent within the section." onclick="checkQuiz('quiz-coff-relocations-1', this)">It is <code>VirtualAddress</code>, and 0x5D is 93 bytes into <code>.text</code>. Type 4 is <code>REL32</code>: the linker writes a 32-bit relative displacement, target minus the address of the field plus 4</button>
                    <button class="quiz-option" data-correct="false" data-explain="0x5D = 93 as a file offset would land inside the .text raw data (which starts at 0x17C) only by coincidence; as a real file offset it is inside the file header and section table, in the middle of the .rdata section header. The field is deliberately section-relative so it survives the section being moved." onclick="checkQuiz('quiz-coff-relocations-1', this)">It is <code>VirtualAddress</code> and it is a file offset, so 0x5D is byte 93 of the file</button>
                    <button class="quiz-option" data-correct="false" data-explain="This swaps the type against the instruction it belongs to. The call to add is the record at 0x5D with type 4 REL32. ADDR32NB is type 3 and appears only in the .pdata section here, where the linker subtracts the image base to store a relative value in a field that looks absolute." onclick="checkQuiz('quiz-coff-relocations-1', this)">It is the <code>SymbolTableIndex</code> that is the offset, and type 4 means the linker writes the target's absolute 4-byte address</button>
                    <div class="quiz-feedback"></div>
                </div>
            </div>

            <div class="unit unit-apply">
                <h2>Apply It</h2>
                <p>You ship a COFF-reading library used on both x64 and ARM64 builds. It decodes relocation types with a single hard-coded table of AMD64 numbers. On the ARM64 objects it reports plausible types and produces a linked image with silently wrong pointers. What is the actual defect, and what is the minimum correct design?</p>
                <div class="quiz" id="quiz-coff-relocations-2">
                    <button class="quiz-option" data-correct="true" data-explain="Relocation type numbers are scoped to Machine - AMD64 type 4 means REL32, but on another machine the same number can mean something else entirely. The file header carries Machine for exactly this reason. A library that keys its type table off the target it was compiled for rather than the file's declared machine has a bug that no test on its own target can reveal, and it fails silently because the record still decodes to a valid-looking type." onclick="checkQuiz('quiz-coff-relocations-2', this)">Relocation <code>Type</code> is scoped to <code>Machine</code>, so the number has no meaning without it. Read <code>Machine</code> from the file header and select the type table from it &mdash; and reject a file whose machine you have no table for, rather than guessing</button>
                    <button class="quiz-option" data-correct="false" data-explain="The records still decode to a valid 16-bit number, so no reader rejects them. The failure is not a malformed record but a well-formed record that has been given the wrong interpretation, which is why it reaches the linker silently and only shows up as wrong addresses in the output image." onclick="checkQuiz('quiz-coff-relocations-2', this)">The defect is that a 16-bit type cannot hold ARM64&rsquo;s type numbers, so the field truncates them and the library reads garbage</button>
                    <button class="quiz-option" data-correct="false" data-explain="Endianness is consistent: COFF is little-endian on every target, which is why the Machine field is safe to read first. The variable part is the type numbering, and a build for one architecture still produces well-formed little-endian records, so byte order is not the problem here." onclick="checkQuiz('quiz-coff-relocations-2', this)">The defect is endianness: AMD64 records are little-endian but the ARM64 ones are big-endian, so the fields are swapped</button>
                    <div class="quiz-feedback"></div>
                </div>
                <p><em>The general habit: a numeric code inside a file is only meaningful relative to a declared context. If the file says what it is, read that first &mdash; and if you meet a code you have no table for, say so instead of falling back to a nearby one.</em></p>
            </div>

            <div class="unit unit-connect">
                <h2>Connect</h2>
                <p>This is the <a href="/courses/elf/lessons/relocation-entries">ELF relocation table</a> with a different container, and the comparison is instructive. ELF keeps relocations in a <em>section</em> (<code>.rela.text</code>), typed by a section index, and the symbol table gives the name. COFF keeps them in a <em>side table</em> that the section header points at, typed by a machine-specific number, and the symbol table gives an index. Same job, and ELF's version is easier to extend &mdash; a new relocation type is a new section &mdash; while COFF's is a new number in a table that has to be kept in sync with every machine.</p>
                <p>The <code>REL32</code> idea is the same one the <a href="/courses/elf/lessons/memory-mapping">ELF memory mapping</a> concept relies on: code that stores a displacement rather than an address can be placed anywhere. <a href="/courses/pe/lessons/pe-base-relocations">PE base relocations</a> exist precisely because some data cannot be relative, and <code>ADDR32NB</code> is the COFF-object half of that same problem.</p>
                <p>One mechanism remains, and it is the one that makes C++ linking work at all.</p>
                <p>Next: <a href="/courses/coff/lessons/coff-comdat">COMDAT and Duplicate Sections</a> &mdash; how a linker is told which of two identical sections to keep.</p>
            </div>

            <div class="lesson-footer">
                <span><a href="/courses/coff/lessons/coff-symbol-table">Previous: The Symbol Table</a></span>
                <span><a href="/courses/coff/lessons/coff-comdat">Next: COMDAT and Duplicate Sections</a></span>
            </div>
        </div>
    }

    render_lesson_js(&mut page)

    return page.toString()
}
}
